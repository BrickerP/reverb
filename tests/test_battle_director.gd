extends RefCounted


func _death(id: StringName = &"runner", uid: int = 1) -> EnemyDeathInfo:
	var info := EnemyDeathInfo.new()
	info.target_uid = uid
	info.enemy_id = id
	info.pos = Vector2(400.0, 300.0)
	info.radius = 16.0
	info.hit_dir = Vector2.RIGHT
	info.facing = Vector2.DOWN
	info.color = Color("be5749")
	return info


func test_shot_pose_is_event_driven_throttled_and_gives_walking_time(c: Check) -> void:
	var director := BattleDirector.new()
	var shot := ShotInfo.new()
	shot.source = -1
	shot.weapon_id = &"mallet"
	var key: StringName = &"character_looper_front"
	c.eq(PresentationAssets.frame_count(key), 8, "player atlas contains authored action and death cells")
	c.eq(director.player_pose(key, 12.0, false, false), 0, "time alone never invents an attack")
	c.ok(director.shot(shot), "actual first shot starts one body action")
	c.eq(director.player_pose(key, 0.0, true, false), 5, "fire starts on the actual impact pose")
	for index in 20:
		c.ok(not director.shot(shot), "same rapid volley cannot continuously restart the body")
	director.step(BattleDirector.SHOT_TIME * 0.6)
	c.eq(director.player_pose(key, 0.1, true, false), 4, "followthrough is a different drawn cell")
	director.step(BattleDirector.SHOT_TIME)
	c.ok(director.player_pose(key, 0.2, true, false) < 3, "walk poses return before the next body action")
	c.ok(not director.shot(shot), "a high-rate weapon still leaves a locomotion gap")
	director.step(BattleDirector.SHOT_INTERVAL)
	c.ok(director.shot(shot), "later volleys can start a fresh action")
	director.player_hurt(-1)
	c.eq(director.player_pose(key, 0.0, true, false), 3, "hurt takes priority over firing")


func test_contact_pose_is_immediate_and_identifies_only_the_actual_attacker(c: Check) -> void:
	var director := BattleDirector.new()
	var key: StringName = &"enemy_runner"
	c.eq(director.enemy_pose(key, 42, 0.0, false, false), 0,
			"being near a player does not manufacture a harmless windup")
	director.player_hurt(42)
	c.eq(director.enemy_pose(key, 42, 0.0, true, false), 5, "contact starts on the bite at the damage event")
	c.ok(director.enemy_pose(key, 43, 0.0, true, false) < 3, "another enemy does not inherit the bite")
	c.ok(director.enemy_pose(&"enemy_bomber", 42, 0.0, true, false) < 6,
			"a live contact bag never borrows either exploded or flattened death drawing")
	director.step(BattleDirector.CONTACT_TIME * 0.65)
	c.eq(director.enemy_pose(key, 42, 0.0, true, false), 4, "the attacker recovers after the bite")
	director.enemy_hit(42)
	c.eq(director.enemy_pose(key, 42, 0.0, true, false), 3, "a real hit can interrupt the contact picture")
	director.step(1.0)
	c.eq(director.counts()["contacts"], 0, "finished contact gestures release their UID entries")


func test_echo_shooting_uses_take_identity_instead_of_reordered_slots(c: Check) -> void:
	var director := BattleDirector.new()
	var shot := ShotInfo.new()
	shot.source = 0
	shot.weapon_id = &"mallet"
	var key: StringName = &"character_mirror_front"
	shot.actor_token = 17001
	c.ok(director.shot(shot), "captured take identity starts its own action")
	c.eq(director.echo_pose(key, 17001, 0.0, false, false), 5, "that copy receives the shot pose")
	c.eq(director.echo_pose(key, 17002, 0.0, false, false), 0,
			"a different take moved into the same slot cannot inherit it")
	shot.actor_token = -1
	c.ok(not director.shot(shot), "an unknown copy identity never falls back onto the player")
	c.eq(director.player_pose(key, 0.0, false, false), 0, "copy actions do not kick the current self")


func test_copy_identity_uses_persistent_positive_take_uids(c: Check) -> void:
	var director := BattleDirector.new()
	var shot := ShotInfo.new()
	shot.source = 0
	shot.weapon_id = &"mallet"
	for token: int in [1, 17001, 17002]:
		director.clear()
		shot.actor_token = token
		c.ok(BattleDirector.is_copy_token(token), "positive saved take UID is a copy")
		c.ok(director.shot(shot), "stable UID drives its own heavy action")
		c.eq(director.echo_pose(&"character_looper_front", token, 0.0, false, false), 5,
			"drawn heavy action matches the captured UID")
		c.eq(director.player_pose(&"character_looper_front", 0.0, false, false), 0,
			"copy action never becomes a player action")
	for token in [-9223371986674121139, -2, -1, 0]:
		shot.actor_token = token
		c.ok(not BattleDirector.is_copy_token(token), "negative and unknown tokens are not saved copy UIDs")
		c.ok(not director.shot(shot), "invalid copy actor token cannot drive a body action")


func test_death_snapshots_are_immutable_bounded_and_have_distinct_exit_shapes(c: Check) -> void:
	var director := BattleDirector.new()
	var info := _death()
	director.enemy_died(info)
	info.pos = Vector2(1.0, 2.0)
	info.enemy_id = &"brute"
	c.eq(director.corpses[0]["pos"], Vector2(400.0, 300.0), "dead actor copies its final position")
	c.eq(director.corpses[0]["enemy_id"], &"runner", "later event mutation cannot change its identity")
	var seen: Array[StringName] = []
	for id: StringName in [&"grunt", &"runner", &"brute", &"silencer", &"bomber", &"warden", &"paradox"]:
		var kind := BattleDirector.death_kind(id)
		c.ok(not seen.has(kind), "%s gets a readable type-specific exit" % id)
		seen.append(kind)
	var bag := _death(&"bomber", 19)
	director.enemy_died(bag)
	c.eq(BattleDirector.corpse_profile(director.corpses[-1])["frame"], 6,
			"the bag's drawn burst appears only after the actual death snapshot")
	for uid in 100:
		director.enemy_died(_death(&"brute", uid + 2))
	c.eq(director.corpses.size(), BattleDirector.MAX_CORPSES, "mass kills never allocate unlimited corpse drawings")
	director.enemy_died(_death(), true)
	c.eq(director.corpses.size(), BattleDirector.REDUCED_CORPSES, "reduced budget also applies when switching mid-burst")
	for corpse in director.corpses:
		var reduced := BattleDirector.corpse_profile(corpse, true)
		c.eq(reduced["offset"], Vector2.ZERO, "reduced death art does not travel across live threats")
		c.eq(reduced["rotation"], 0.0, "reduced death art is not spun")
	director.step(2.0)
	c.eq(director.corpses.size(), 0, "dead snapshots expire and release their data")
	director.enemy_died(_death(&"paradox", 501))
	for uid in 30:
		director.enemy_died(_death(&"grunt", 600 + uid))
	director.settle(true)
	var kept_original := false
	for corpse in director.corpses:
		kept_original = kept_original or corpse["enemy_id"] == &"paradox"
	c.ok(kept_original, "reducing effect detail keeps the important original's death above routine scraps")
	director.clear()
	var invalid := _death()
	invalid.radius = NAN
	director.enemy_died(invalid)
	c.eq(director.corpses.size(), 0, "invalid event geometry cannot reach canvas drawing")


func test_boss_transition_is_separate_from_real_shards_and_death_identity(c: Check) -> void:
	var director := BattleDirector.new()
	director.begin_tear(Vector2(230.0, 330.0))
	c.eq(director.tear["pos"], Vector2(230.0, 330.0), "tear keeps the actual original position")
	var left := _death(&"paradox")
	left.boss_phase = 2
	left.boss_shard_index = 0
	director.enemy_died(left)
	var right := _death(&"paradox", 2)
	right.boss_phase = 2
	right.boss_shard_index = 1
	director.enemy_died(right)
	c.eq(BattleDirector.corpse_profile(director.corpses[0])["frame"], 2, "left half first keeps its authored side")
	c.eq(BattleDirector.corpse_profile(director.corpses[1])["frame"], 3, "right half never becomes a mirrored left")
	director.step(BattleDirector.TEAR_TIME + 0.01)
	c.ok(director.tear.is_empty(), "extra torn print is brief rather than a third living boss")
	c.eq(BattleDirector.corpse_profile(director.corpses[0])["frame"], 7, "both defeated halves end as harmless torn paper")


func test_boss_tear_has_tension_snap_release_and_a_finite_visual_envelope(c: Check) -> void:
	var director := BattleDirector.new()
	c.ok(director.tear_profile().is_empty(), "clock alone cannot create a boss transition")
	director.begin_tear(Vector2(320.0, 280.0))
	c.eq(director.tear_profile()["stage"], &"tension", "the real event starts by pulling paper tight")
	director.step(BattleDirector.TEAR_TENSION_TIME * 0.8)
	var stretched := director.tear_profile()
	c.ok(stretched["stretch"].x > 1.1 and stretched["stretch"].y < 0.93,
			"tension changes the print's silhouette before it breaks")
	c.eq(stretched["half_alpha"], 0.0, "halves do not appear before the seam breaks")
	director.step(BattleDirector.TEAR_TENSION_TIME * 0.2 + 0.001)
	c.eq(director.tear_profile()["stage"], &"snap", "seam break follows tension at the exact boundary")
	c.ok(director.tear_profile()["fragment_alpha"] > 0.8, "one strong bounded paper burst marks the break")
	director.step(BattleDirector.TEAR_SNAP_TIME)
	c.eq(director.tear_profile()["stage"], &"release", "springing afterprints follow the broken seam")
	c.ok(director.tear_profile()["half_alpha"] > 0.5, "the release has a visible paper silhouette")
	for index in 35:
		var profile := director.tear_profile()
		if profile.is_empty():
			break
		c.ok(float(profile["spring"]) >= 0.0 and float(profile["spring"]) <= 49.0,
				"discarded halves stay within a local bounded decorative envelope")
		c.ok(float(profile["seam_width"]) <= 14.0 and absf(float(profile["rotation"])) <= 0.16,
				"a seam is not drawn as an arena-spanning threat")
		director.step(0.01)
	director.step(0.02)
	c.ok(director.tear.is_empty(), "the complete three-beat picture ends within 0.62 seconds")
	director.begin_tear(Vector2(INF, 1.0))
	c.ok(director.tear.is_empty(), "invalid origin cannot allocate a transition")
	director.begin_tear(Vector2.ONE)
	var age: float = director.tear["age"]
	director.step(NAN)
	director.step(-1.0)
	c.eq(director.tear["age"], age, "invalid deltas never advance or poison the tear timeline")


func test_reduced_tear_keeps_a_stationary_broken_seam_without_motion(c: Check) -> void:
	var director := BattleDirector.new()
	director.begin_tear(Vector2(320.0, 280.0))
	director.step(0.10)
	director.settle(true)
	var still := director.tear_profile()
	c.eq(still["stage"], &"settled", "switching effects keeps a readable final tear mark")
	c.ok(still["seam_alpha"] >= 0.8 and still["seam_width"] >= 12.0,
			"reduced effects retain the meaningful contrast and broken shape")
	for index in 4:
		var profile := director.tear_profile(true)
		c.eq(profile["spring"], 0.0, "reduced transition has no flying half prints")
		c.eq(profile["rotation"], 0.0, "reduced transition never spins")
		c.eq(profile["fragment_alpha"], 0.0, "reduced transition has no travelling fragments")
		c.eq(profile["stretch"], Vector2.ONE, "reduced transition has no paper stretching")
		director.step(0.10)
	director.clear()
	c.ok(director.tear_profile().is_empty(), "a new run releases even a reduced transition")
	director.begin_tear(Vector2.ZERO)
	c.eq(director.tear_profile(true)["stage"], &"settled", "already-reduced events start at the stationary final mark")
	director.step_terminal(1.0)
	c.ok(director.tear.is_empty(), "reduced and terminal worlds cannot leave a permanent seam")


func test_foreground_tear_gutters_and_threads_keep_the_live_body_core_clear(c: Check) -> void:
	var director := BattleDirector.new()
	director.begin_tear(Vector2(550.0, 150.0))
	# Native battle review found the first half's face/body core within +/-12px.
	# Test complete stroke envelopes, not only points: thick gutters matter here.
	var core := Rect2(-12.0, -36.0, 24.0, 64.0)
	for reduced in [false, true]:
		director.begin_tear(Vector2(550.0, 150.0))
		for frame in 38:
			var profile := director.tear_profile(reduced)
			if profile.is_empty():
				break
			var geometry := ArenaPainter.boss_tear_edge_geometry(profile)
			for group: String in ["edges", "threads"]:
				var stroke := float(geometry["paper_width"] if group == "edges" else geometry["thread_width"])
				for line: PackedVector2Array in geometry[group]:
					var bounds := Rect2(line[0], Vector2.ZERO)
					for point: Vector2 in line:
						bounds = bounds.expand(point)
					c.ok(not bounds.grow(stroke * 0.5).intersects(core),
							"foreground seam stroke leaves the actual half's central face/body uncovered")
			director.step(1.0 / 60.0)
	c.ok(ArenaPainter.boss_tear_edge_geometry({}).is_empty(), "absent phase has no foreground cut geometry")


func test_real_boss_phase_event_starts_paper_beats_without_holding_live_shards(c: Check) -> void:
	var sim := Sim.new(713)
	sim.start_run()
	sim.player.stats.add(Stats.MAX_HP, 100000.0)
	sim.player.hp = sim.player.max_hp()
	sim.start_wave(WaveDirector.FINAL_WAVE)
	for index in 200:
		sim.step(1.0 / 60.0, Vector2.ZERO)
	c.ok(sim.boss != null, "real final-wave boss has spawned")
	if sim.boss == null:
		return
	var view := ArenaView.new()
	view.bind(sim)
	var original := sim.boss.pos
	sim.boss.hp = sim.boss.max_hp * 0.51
	sim.damage_enemy(sim.boss, sim.boss.max_hp * 0.02, Vector2.ZERO, false, -1)
	c.eq(sim.boss_phase, 2, "real damage starts the authoritative second phase")
	c.eq(sim.boss_alive_count(), 2, "both real damaging bodies already exist during the first visual beat")
	c.eq(view._director.tear["pos"], original, "visual tension snapshots the real original position")
	c.eq(view._director.tear_profile()["stage"], &"tension", "actual phase event begins the sequence once")
	var first_position := sim.boss_shards[0].pos
	var second_position := sim.boss_shards[1].pos
	var first_hp := sim.boss_shards[0].hp
	var second_hp := sim.boss_shards[1].hp
	var rng := sim.rng.state
	var wave_time := sim.wave_time
	view.set_paused(true)
	view._process(0.30)
	c.eq(view._director.tear["age"], 0.0, "pause freezes the strong tension and seam picture")
	view.set_paused(false)
	view._process(0.18)
	c.eq(view._director.tear_profile()["stage"], &"snap", "visual time alone can advance to the broken seam")
	view._process(0.16)
	c.eq(view._director.tear_profile()["stage"], &"release", "the released paper follows the break")
	c.eq(sim.boss_shards[0].pos, first_position, "visual spring never repositions the first collision body")
	c.eq(sim.boss_shards[1].pos, second_position, "visual spring never repositions the second collision body")
	c.eq(sim.boss_shards[0].hp, first_hp, "first shard keeps its exact real health")
	c.eq(sim.boss_shards[1].hp, second_hp, "second shard keeps its exact real health")
	c.eq(sim.rng.state, rng, "paper fragments do not consume gameplay random draws")
	c.eq(sim.wave_time, wave_time, "the presentation beat neither delays nor advances gameplay time")
	view._process(1.0)
	c.ok(view._director.tear.is_empty(), "afterprints expire while both live shards remain")
	c.eq(sim.boss_alive_count(), 2, "the end of the art is not a fake shard death")
	view.unbind()
	view.free()


func test_paused_view_does_not_advance_actors_and_terminal_pose_finishes_without_sim(c: Check) -> void:
	var sim := Sim.new(171)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	sim.enemy_killed.emit(_death())
	view._director.begin_tear(Vector2(200.0, 210.0))
	var rng := sim.rng.state
	var wave_time := sim.wave_time
	var position := sim.player.pos
	view.set_paused(true)
	view._process(0.2)
	c.eq(view._director.corpses[0]["age"], 0.0, "normal pause freezes actor remains too")
	c.eq(view._director.tear["age"], 0.0, "normal pause freezes a live boss tear overlay too")
	sim.phase = Sim.Phase.LOST
	view._on_run_lost()
	view._process(BattleDirector.PLAYER_DEATH_TIME)
	var key: StringName = &"character_looper_front"
	c.eq(view._director.player_pose(key, 0.0, false, false), 6,
			"explicit pause freezes terminal art as well")
	view.set_paused(false)
	view._process(BattleDirector.PLAYER_DEATH_TIME)
	c.eq(view._director.player_pose(key, 0.0, false, false), 7, "a terminal paper self can settle behind the report")
	c.eq(view.motion_stats()["visual_time"], 0.0, "the paused world's main art clock remains frozen")
	c.eq(sim.rng.state, rng, "death pictures never consume simulation randomness")
	c.eq(sim.wave_time, wave_time, "terminal art does not restart gameplay time")
	c.eq(sim.player.pos, position, "death does not move the collision body")
	view.unbind()
	c.eq(view._director.corpses.size(), 0, "detaching clears corpse snapshots")
	c.ok(view._director.player_death.is_empty() and view._director.tear.is_empty(), "detaching releases terminal pictures")
	view.free()


func test_copy_recoil_survives_slot_reordering_without_jumping_to_another_take(c: Check) -> void:
	var sim := Sim.new(184)
	sim.start_run()
	var first := EchoTake.new()
	first.uid = 1
	first.samples = PackedVector2Array([Vector2(100.0, 100.0), Vector2(110.0, 100.0)])
	var second := EchoTake.new()
	second.uid = 2
	second.samples = first.samples
	sim.echoes.append(EchoActor.new(first, 0))
	sim.echoes.append(EchoActor.new(second, 1))
	var view := ArenaView.new()
	view.bind(sim)
	var shot := ShotInfo.new()
	shot.source = 1
	shot.actor_token = second.uid
	shot.source_tint = second.tint()
	shot.weapon_id = &"pistol"
	shot.weapon_slot = 0
	view._on_shot_info(shot)
	c.eq(view._muzzles[0]["source"], 1, "shot packet keeps its original authoritative slot")
	c.eq(view._muzzles[0]["actor_token"], second.uid, "drawing separately keeps the take identity")
	sim.echoes.remove_at(0)
	sim.echoes[0].index = 0
	c.ok(ArenaPainter._mounted_recoil(view._muzzles, second.uid, &"pistol", 0) > 0.0,
			"the same paper copy keeps its recoil after another copy retires")
	c.eq(ArenaPainter._mounted_recoil(view._muzzles, first.uid, &"pistol", 0), 0.0,
			"removed/reused slots cannot steal a different copy's shot reaction")
	view.free()


func test_delayed_feedback_reads_captured_colour_and_unknown_actor_is_neutral(c: Check) -> void:
	var sim := Sim.new(185)
	sim.start_run()
	var take := EchoTake.new()
	take.uid = 3
	take.samples = PackedVector2Array([Vector2.ONE, Vector2(2.0, 1.0)])
	sim.echoes.append(EchoActor.new(take, 0))
	var view := ArenaView.new()
	view.bind(sim)
	var hit := DamageInfo.new()
	hit.source = 0
	hit.actor_token = take.uid
	hit.source_tint = Color("ad6e54")
	hit.weapon_id = &"pistol"
	take.tint_index = 4
	sim.echoes.clear()
	view._on_damage_info(hit)
	c.eq(view._hits[-1]["color"], Color("ad6e54"), "late impact preserves the fired colour after its owner is gone")
	hit.actor_token = -1
	view._on_damage_info(hit)
	c.eq(view._hits[-1]["color"], Color.WHITE, "unknown copy impact never guesses an identity from a slot")
	var shot := ShotInfo.new()
	shot.source = 0
	shot.weapon_id = &"pistol"
	view._on_shot_info(shot)
	c.eq(view._muzzles[-1]["actor_token"], 0, "unknown copy shot has a neutral drawing token distinct from the player")
	c.eq(view._director.player_pose(&"character_looper_front", 0.0, false, false), 0,
			"unknown copy source cannot kick the player's firing pose")
	var consumed := _death()
	consumed.source = -1
	consumed.actor_token = take.uid
	consumed.source_tint = Color("ad6e54")
	c.ok(view.kill_color(consumed) != consumed.color,
			"retirement preserves its consumed copy identity even when the legacy statistics source is player")
	view.free()


func test_neutral_scale_stays_independent_of_wide_action_and_dead_cells(c: Check) -> void:
	var key: StringName = &"character_looper_front"
	var idle := PresentationAssets.idle_region(key)
	var scale := ArenaPainter.art_pixel_scale(key, ArenaPainter.PLAYER_ART_SIZE)
	var fitted := idle.size * scale
	c.ok(fitted.x <= ArenaPainter.PLAYER_ART_SIZE.x + 0.001 and fitted.y <= ArenaPainter.PLAYER_ART_SIZE.y + 0.001,
			"living identity is calibrated against its idle art rather than a sprawled corpse")
	for frame in PresentationAssets.frame_count(key):
		var pivot := PresentationAssets.frame_pivot(key, frame)
		c.ok(pivot.is_finite(), "each authored row has a finite measured foot anchor")
	c.eq(ArenaPainter.art_pixel_scale(key, Vector2.ZERO), 0.0, "zero destination has no pixel scale")
	c.eq(ArenaPainter.art_pixel_scale(key, Vector2(INF, 10.0)), 0.0, "nonfinite destination cannot become a draw transform")
	c.ok(not ArenaPainter._draw_art_foot(null, key, Vector2.ZERO, Vector2.ZERO, 0.0, Color.WHITE),
			"empty actor drawing returns before touching a canvas")


func test_view_consumes_real_contact_hit_and_death_identities_once(c: Check) -> void:
	var sim := Sim.new(191)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var contact := PlayerHurtInfo.new()
	contact.amount = 1.0
	contact.hp_loss = 1.0
	contact.source = &"runner"
	contact.source_uid = 21
	contact.effect = &"contact"
	sim.player_hurt_info.emit(contact)
	c.eq(view._director.enemy_pose(&"enemy_runner", 21, 0.0, true, false), 5,
			"actual typed contact drives only that enemy's drawn bite")
	c.eq(view._hurts[0]["source_uid"], 21, "directional hurt retains the exact damaging actor")
	var hit := DamageInfo.new()
	hit.target_uid = 21
	hit.weapon_id = &"pistol"
	sim.damage_event.emit(hit)
	c.eq(view._hits[0]["target_uid"], 21, "rich hit does not drop the target UID")
	c.eq(view._director.enemy_pose(&"enemy_runner", 21, 0.0, true, false), 3,
			"actual hit briefly interrupts the bite drawing")
	var dead := _death(&"runner", 21)
	sim.enemy_killed.emit(dead)
	c.eq(view.feedback_counts()["corpses"], 1, "one kill snapshot creates one corpse")
	c.eq(view.event_last_data()["enemy_id"], &"runner", "death feedback keeps type rather than guessing by position")
	c.eq(view._director.counts()["hurt_actors"], 0, "death releases the hit reaction entry")
	var next := Sim.new(192)
	next.start_run()
	view.bind(next)
	sim.enemy_killed.emit(_death(&"brute", 22))
	c.eq(view.feedback_counts()["corpses"], 0, "an old simulation cannot leave corpses in a new run")
	view.free()


func test_boss_roar_picture_requires_the_real_silence_event(c: Check) -> void:
	var sim := Sim.new(193)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	c.eq(ArenaPainter.boss_art_profile(1, -1, 100.0)["frame"], 0,
			"a periodic clock cannot pretend the boss is preparing a new attack")
	var boss := EnemyState.new()
	boss.def = Content.enemy(&"paradox")
	boss.radius = boss.def.radius
	sim.boss = boss
	sim.boss_shards.append(boss)
	var silence := EchoSilenceInfo.new()
	silence.kind = EchoSilenceInfo.BOSS
	silence.duration = 3.0
	silence.enemy_id = &"paradox"
	sim.echoes_silenced.emit(silence)
	c.ok(view._director.is_boss_roaring(), "real silence opens the original's drawn mouth")
	c.eq(ArenaPainter.boss_art_profile(1, -1, 0.0, false, true)["frame"], 1,
			"actual event selects the authored roar cell")
	view._process(0.5)
	c.ok(not view._director.is_boss_roaring(), "roar picture returns to calm instead of looping forever")
	silence.kind = EchoSilenceInfo.CONTACT
	silence.source_uid = 91
	silence.enemy_id = &"silencer"
	sim.echoes_silenced.emit(silence)
	c.ok(not view._director.is_boss_roaring(), "a bottle touching the player cannot make a nearby boss roar")
	c.eq(view._director.enemy_pose(&"enemy_silencer", 91, 0.0, false, false), 5,
			"the actual bottle responds to its own jamming event")
	silence.kind = EchoSilenceInfo.PHASE
	sim.echoes_silenced.emit(silence)
	c.ok(not view._director.is_boss_roaring(), "tearing silence is distinct from an actual boss cast")
	view.free()
