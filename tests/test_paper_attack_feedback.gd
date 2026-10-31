extends RefCounted


func _shot(slot: int = 0, token: int = -1) -> ShotInfo:
	var info := ShotInfo.new()
	info.weapon_id = &"stapler"
	info.weapon_slot = slot
	info.actor_token = token
	info.source = 0 if token > 0 else -1
	info.origin = Vector2(600, 360)
	info.direction = Vector2.UP
	return info


func test_six_actions_have_readable_contact_results_for_all_weapon_ids(c: Check) -> void:
	var representatives := {&"pin": &"stapler", &"stamp": &"stamp", &"cut": &"cutter",
		&"ink": &"ink_bottle", &"return": &"paper_saw", &"arc": &"hex_bolt"}
	var shapes: Array[String] = []
	for action: StringName in representatives:
		var p := WeaponInk.profile(representatives[action])
		c.eq(p["action"], action, "representative keeps its real paper action")
		var shape := WeaponInk.contact_geometry(action, 0.5)
		var signature := var_to_str(shape)
		c.ok(not shapes.has(signature), "%s contact is recognizable without color or sound" % action)
		shapes.append(signature)
	var pin := WeaponInk.contact_geometry(&"pin", 0.5)
	c.eq(pin["holes"].size(), 2, "a pin leaves two paper holes joined by a clamp")
	c.ok(not (WeaponInk.contact_geometry(&"stamp", 0.5)["blot"] as PackedVector2Array).is_empty(), "stamp leaves a solid ink imprint")
	c.eq(WeaponInk.contact_geometry(&"cut", 0.5)["pieces"].size(), 2, "cut separates two short paper pieces")
	c.eq(WeaponInk.contact_geometry(&"cut", 0.5, true)["pieces"].size(), 1, "reduced retains a cut result with fewer loose pieces")
	c.ok((WeaponInk.contact_geometry(&"ink", 0.5)["blot"] as PackedVector2Array).size() > 8, "ink settles into a ragged blot")
	c.eq(WeaponInk.contact_geometry(&"return", 0.5)["lines"][0].size(), 9, "return leaves a curved recovery hook")
	c.eq(WeaponInk.contact_geometry(&"arc", 0.5)["lines"].size(), 4, "arc reads as a conductor crossed by three stitches")
	var counts: Dictionary = {}
	for id: StringName in WeaponInk.IDS:
		var p := WeaponInk.profile(id)
		c.ok(representatives.has(p["action"]), "%s belongs to an explicit paper action" % id)
		counts[p["action"]] = int(counts.get(p["action"], 0)) + 1
		c.ok(float(p["muzzle_life"]) <= 0.24 and float(p["hit_life"]) <= 0.34,
			"routine contact clears quickly instead of covering the battlefield")
	c.eq(counts.size(), 6, "all six action languages are used by the shipped weapons")


func test_equal_weapons_react_only_in_the_captured_actor_and_weapon_slot(c: Check) -> void:
	var sim := Sim.new(92101)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	view._on_shot_info(_shot(0, 41))
	c.ok(ArenaPainter._mounted_recoil(view._muzzles, 41, &"stapler", 0) > 0.0, "firing weapon kicks")
	c.eq(ArenaPainter._mounted_recoil(view._muzzles, 41, &"stapler", 1), 0.0, "another equal weapon stays still")
	c.eq(ArenaPainter._mounted_recoil(view._muzzles, 42, &"stapler", 0), 0.0, "another copy cannot inherit the kick")
	c.eq(ArenaPainter._mounted_recoil(view._muzzles, 41, &"pistol", 0), 0.0, "a replaced weapon cannot inherit an old event")
	c.eq(ArenaPainter._mounted_shot(view._muzzles, 41, &"stapler", 0)["direction"], Vector2.UP, "motion keeps actual firing direction")
	view._muzzles.clear()
	view._on_shot_info(_shot(-1, 41))
	for slot in 6:
		c.eq(ArenaPainter._mounted_recoil(view._muzzles, 41, &"stapler", slot), 0.0,
			"unattributed delayed fire never guesses an equal weapon slot")
	view.free()


func test_mount_gestures_settle_and_reduced_motion_preserves_identity(c: Check) -> void:
	var poses: Array[String] = []
	for id: StringName in [&"stapler", &"stamp", &"cutter", &"ink_bottle", &"paper_saw", &"hex_bolt"]:
		var pose := WeaponInk.mount_pose(id, 0.6)
		c.ok(not poses.has(var_to_str(pose)), "six release gestures have different physical silhouettes")
		poses.append(var_to_str(pose))
		var reduced := WeaponInk.mount_pose(id, 0.6, true)
		c.near((reduced["offset"] as Vector2).length(), (pose["offset"] as Vector2).length() * 0.3, 0.0001,
			"reduced lowers motion rather than replacing paper identities")
		var idle := WeaponInk.mount_pose(id, 0.0)
		c.eq(idle["offset"], Vector2.ZERO, "finished shot leaves no mount drift")
		c.eq(idle["rotation"], 0.0, "finished shot leaves no permanent twist")
		c.eq(idle["scale"], Vector2.ONE, "finished shot restores its authored size")
		for bad: float in [NAN, INF, -1.0]:
			c.eq(WeaponInk.mount_pose(id, bad), idle, "invalid event weight cannot deform the puppet")
	var director := BattleDirector.new()
	for index in 60:
		var shot := _shot()
		director.shot(shot)
		c.eq(director.player_pose(&"character_looper_front", PI * 0.5, true, false), 1,
			"repeated pin fire remains on the mount while the body keeps its step")
		director.step(1.0 / 60.0)


func test_directional_fold_uses_only_the_actual_target_and_recovers(c: Check) -> void:
	var director := BattleDirector.new()
	director.enemy_hit(12, Vector2.RIGHT)
	var fold := director.enemy_fold(12)
	c.ok((fold["scale"] as Vector2).x < (fold["scale"] as Vector2).y, "rightward contact compresses across the actual strike")
	c.ok(float(fold["rotation"]) > 0.0, "the paper yields in the incoming direction")
	c.eq(director.enemy_fold(13)["scale"], Vector2.ONE, "another enemy is not folded by a neighbor's hit")
	var reduced := director.enemy_fold(12, true)
	c.ok((reduced["scale"] as Vector2).distance_to(Vector2.ONE) < (fold["scale"] as Vector2).distance_to(Vector2.ONE), "reduced retains a smaller body response")
	director.step(BattleDirector.HURT_TIME + 0.01)
	c.eq(director.enemy_fold(12)["scale"], Vector2.ONE, "contact settles without altering a model position")
	c.eq(director.enemy_fold(12)["rotation"], 0.0, "contact leaves no delayed turn")
	director.enemy_hit(15, Vector2(INF, 0))
	c.ok((director.enemy_fold(15)["scale"] as Vector2).is_finite(), "invalid direction never reaches drawing as NaN")


func test_paused_and_reduced_feedback_is_bounded_and_keeps_the_model_unchanged(c: Check) -> void:
	var sim := Sim.new(92102)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var before := RunSnapshot.capture(sim)
	for index in 400:
		view._on_shot_info(_shot(index % 6))
		var hit := DamageInfo.new()
		hit.target_uid = index
		hit.weapon_id = &"cutter"
		hit.hit_dir = Vector2.RIGHT
		hit.amount = 3.0
		view._on_damage_info(hit)
	c.ok(view._muzzles.size() <= ArenaView.MAX_MUZZLES, "rapid fire cannot grow its queue")
	c.ok(view._hits.size() <= ArenaView.MAX_HITS, "dense contacts cannot grow their queue")
	c.ok(int(view._director.counts()["hurt_actors"]) <= BattleDirector.MAX_REACTIONS, "fold snapshots have a fixed actor budget")
	view.set_paused(true)
	var held := view._muzzles.duplicate(true)
	var hit_life := float(view._hits[0]["life"])
	view._process(5.0)
	c.eq(view._muzzles, held, "pause freezes mounted action clocks")
	c.eq(view._hits[0]["life"], hit_life, "pause freezes contact residues")
	view.set_reduced_effects(true)
	c.eq(view._muzzles.size(), 0, "midbattle reduction clears optional muzzle motion")
	c.ok(not WeaponInk.trails_enabled(false, 161) and not WeaponInk.trails_enabled(true, 1), "dense and reduced scenes keep heads while dropping optional tails")
	c.eq(RunSnapshot.capture(sim), before, "visual events leave positions, damage, both RNGs and economy untouched")
	view.set_paused(false)
	view._process(1.0)
	c.eq(view._hits.size(), 0, "confirmed contact residues expire instead of becoming terrain")
	view.free()


func test_return_hook_follows_real_return_state_without_changing_projectile_geometry(c: Check) -> void:
	var shot := Projectile.new()
	shot.weapon_id = &"paper_saw"
	shot.pos = Vector2(880, 430)
	shot.origin = Vector2(600, 360)
	shot.vel = Vector2.LEFT * 200.0
	shot.radius = 4.0
	shot.return_time = 0.6
	c.ok(WeaponInk.return_tail(shot).is_empty(), "outgoing flight does not claim to have returned")
	shot.returning = true
	var before := [shot.pos, shot.origin, shot.vel, shot.radius, shot.age, shot.life, shot.returning]
	var trail := WeaponInk.return_tail(shot)
	c.eq(trail.size(), 3, "return has one compact curved tail")
	c.eq(trail[2], shot.pos, "the tail ends at the actual simulated head")
	for point in trail:
		c.ok(point.distance_to(shot.pos) < 24.0, "a return mark cannot pretend to be a full damaging tether")
	var transform := WeaponInk.flight_transform(shot.pos, shot.vel, shot.radius)
	c.near(transform.x.length(), shot.radius, 0.0001, "contrast and tails never enlarge the contact disc")
	c.eq([shot.pos, shot.origin, shot.vel, shot.radius, shot.age, shot.life, shot.returning], before,
		"reading return feedback does not advance flight or change collision data")
