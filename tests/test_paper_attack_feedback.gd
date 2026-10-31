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


func test_shield_contact_animates_only_the_attacker_without_injuring_the_defender(c: Check) -> void:
	var director := BattleDirector.new()
	var phase := PI * 0.5
	c.ok(not director.enemy_contact(-1), "a directionless blast cannot invent a contact attacker")
	c.eq(director.counts()["contacts"], 0, "missing identity leaves no attack pose")
	c.ok(director.enemy_contact(42), "a real shield contact still has an attacking body")
	c.eq(director.enemy_pose(&"enemy_runner", 42, phase, true, false), 5, "the actual attacker starts on impact, without a false windup")
	c.eq(director.enemy_pose(&"enemy_runner", 43, phase, true, false), 1, "a neighboring enemy keeps its own step")
	c.eq(director.player_pose(&"character_looper_front", phase, true, false), 1, "full absorption leaves the defender walking rather than hurt")
	c.eq(director.player_pose(&"character_looper_front", phase, true, true), 1, "Reduced keeps the same uninjured defender")
	c.ok(not director.enemy_contact(42), "the same contact cannot restart its pose every frame")
	director.step(BattleDirector.CONTACT_TIME * 0.65)
	c.eq(director.enemy_pose(&"enemy_runner", 42, phase, true, false), 4, "shield impact follows through into recovery")
	c.eq(director.player_pose(&"character_looper_front", phase, true, false), 1, "attacker recovery never becomes defender pain")
	director.step(BattleDirector.CONTACT_TIME)
	c.eq(director.enemy_pose(&"enemy_runner", 42, phase, true, false), 1, "contact returns to the held gait phase")
	director.player_hurt(43)
	c.eq(director.enemy_pose(&"enemy_runner", 43, phase, true, false), 5, "actual HP injury reuses the same immediate contact action")
	c.eq(director.player_pose(&"character_looper_front", phase, true, false), 3, "actual HP injury still has the defender's separate hurt pose")


func test_repaired_bodies_compress_straighten_and_keep_their_own_gait(c: Check) -> void:
	var director := BattleDirector.new()
	director.actor_repaired(-1)
	director.actor_repaired(41)
	c.ok(director.repair_pose(-1).y < 1.0, "a real repair starts with a small planted-foot compression")
	c.eq(director.repair_pose(42), Vector2.ONE, "an unhealed copy cannot borrow its neighbor's repair")
	c.eq(director.repair_pose(41, true), Vector2.ONE, "Reduced leaves the patch without optional body motion")
	c.eq(director.player_pose(&"character_looper_front", PI * 0.5, true, false), 1,
		"repair extent never replaces or resets the held walking drawing")
	director.step(BattleDirector.REPAIR_TIME * 0.32)
	c.ok(director.repair_pose(-1).y > 1.0, "the patched paper stands slightly straighter before settling")
	c.ok(director.repair_pose(41).y > 1.0, "the actual repaired Echo has the same small recovery")
	director.step(BattleDirector.REPAIR_TIME)
	c.eq(director.repair_pose(-1), Vector2.ONE, "the original settles to authored size within .32 seconds")
	c.eq(director.repair_pose(41), Vector2.ONE, "the Echo also leaves no permanent body stretch")
	for token in [0, -2, -300]:
		director.actor_repaired(token)
		c.eq(director.repair_pose(token), Vector2.ONE, "enemy and unknown tokens cannot enter the repair lane")
	for token in 100:
		director.actor_repaired(token + 1)
	c.ok(director._repairs.size() <= BattleDirector.MAX_SHOT_ACTORS, "repair reactions have at most one original plus eight copy slots")
	director.end_actions()
	c.ok(director._repairs.size() > 0, "an actual last-tick repair survives into the short record beat")
	director.step_terminal(BattleDirector.REPAIR_TIME + 0.01)
	c.eq(director._repairs.size(), 0, "terminal presentation finishes the recovery without advancing the model")
	director.actor_repaired(-1)
	director.clear()
	c.eq(director._repairs.size(), 0, "a new run discards the previous body's repair")


func test_repair_body_clock_freezes_on_pause_and_never_touches_model_or_rng(c: Check) -> void:
	var sim := Sim.new(92103)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	view._director.actor_repaired(-1)
	var before := RunSnapshot.capture(sim)
	var pose := view._director.repair_pose(-1)
	var gait: float = view.motion_stats()["gait_phase"]
	view.set_paused(true)
	view._process(0.2)
	c.eq(view._director.repair_pose(-1), pose, "pause holds the patch compression clock")
	view.set_paused(false)
	view._process(0.1)
	c.ok(view._director.repair_pose(-1).y > 1.0, "resume continues the same finite recovery")
	c.eq(view.motion_stats()["gait_phase"], gait, "recovery does not consume a stride")
	c.eq(RunSnapshot.capture(sim), before, "recovery cannot heal again, shift feet, consume energy or change either RNG")
	view.unbind()
	c.eq(view._director._repairs.size(), 0, "detaching cannot lend a repair to a later run")
	view.free()


func test_pin_and_stamp_leave_readable_floor_results_below_the_body(c: Check) -> void:
	var pin := WeaponInk.contact_geometry(&"pin", 0.4)
	var pin_size := WeaponInk.hit_mark_size(WeaponInk.profile(&"stapler")["impact"], 1.0)
	var holes: Array = pin["holes"]
	c.ok((holes[0] as Vector2).distance_to(holes[1]) * pin_size >= 9.0,
		"two native paper holes have room for separate ink cores and paper rims")
	c.ok(float(WeaponInk.profile(&"stapler")["hit_life"]) >= 0.3,
		"the pin's identifying clamp outlasts a generic brief hurt pose")
	var stamp: PackedVector2Array = WeaponInk.contact_geometry(&"stamp", 0.4)["blot"]
	for point in stamp:
		c.ok(point.y > 0.0, "solid stamp ink stays below the captured foot instead of covering the face")
	var field := AttackField.new()
	field.weapon_id = &"stamp"
	field.style = &"slam"
	field.pos = Vector2(640, 380)
	field.radius = 70.0
	field.windup = 0.03
	var at := field.pos
	var radius := field.radius
	for reduced in [false, true]:
		var projection := WeaponInk.press_projection(field, reduced)
		c.ok((projection["center"] as Vector2).y + float(projection["height"]) * 0.5 < field.pos.y - field.radius,
			"the raised tool never enters the target's face before impact")
	c.eq(field.pos, at, "moving raised artwork cannot move the actual slam")
	c.eq(field.radius, radius, "native legibility never changes the damage radius")


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
