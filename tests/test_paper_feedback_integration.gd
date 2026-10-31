extends RefCounted


func _sim(seed_value: int = 1861) -> Sim:
	var sim := Sim.new(seed_value)
	sim.start_run()
	sim._plan.clear()
	return sim


func _audio() -> GameAudio:
	var audio := GameAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	return audio


func test_real_support_events_reach_view_and_audio_and_detach_together(c: Check) -> void:
	var sim := _sim()
	var view := ArenaView.new()
	var audio := _audio()
	view.bind(sim)
	audio.bind(sim)
	c.ok(SupportSystem.spawn(sim, &"repair_station", sim.player.pos), "real support spawns")
	c.eq(view.feedback_counts()["interactions"], 1, "real support signal creates one visual receipt")
	c.eq(audio.play_count(&"echo"), 1, "real support signal creates one quiet feed sound")
	var unit: Dictionary = sim.support_units[0]
	SupportSystem.damage(sim, int(unit["uid"]), 1.0)
	c.eq(audio.play_count(&"hit"), 1, "real support damage has its own material cue")
	var next := _sim(1862)
	view.bind(next)
	audio.bind(next)
	view.bind(next)
	audio.bind(next)
	var hits := audio.play_count(&"hit")
	SupportSystem.damage(sim, int(unit["uid"]), 1.0)
	c.eq(view.feedback_counts()["interactions"], 0, "old support cannot leave ink in a new session")
	c.eq(audio.play_count(&"hit"), hits, "old support cannot sound in a new session")
	c.ok(SupportSystem.spawn(next, &"hound", next.player.pos), "new session has a real helper")
	c.eq(view.feedback_counts()["interactions"], 1, "same-session rebind never doubles support ink")
	view.unbind()
	audio.bind(null)
	c.ok(not next.support_event.is_connected(view._on_support_event), "view support listener detaches")
	c.ok(not next.support_event.is_connected(audio._on_support_event), "audio support listener detaches")
	view.free()
	audio.free()


func test_full_shield_blocks_never_borrow_injury_pose_shake_or_sound(c: Check) -> void:
	var sim := _sim()
	var view := ArenaView.new()
	var audio := _audio()
	view.bind(sim)
	audio.bind(sim)
	sim.player.hp = 20.0
	sim.player.shield = 6.0
	sim._hurt_player(4.0, &"runner", &"contact", sim.player.pos, Vector2.LEFT, true, 91)
	c.eq(view.event_last_data()["kind"], &"block", "full absorption identifies a defensive result")
	c.ok(view._hurts[0]["blocked"], "draw receives the defensive clamp path")
	c.eq(view._hurts[0]["hp_loss"], 0.0, "full block does not claim lost health")
	c.eq(view._shake, 0.0, "a shield block does not add injury shake")
	c.eq(view._director.counts()["contacts"], 1, "the actual attacker still follows through into the block")
	c.eq(audio.play_count(&"shield_block"), 1, "full block plays the defensive cue")
	c.eq(audio.play_count(&"hurt_contact"), 0, "full block plays no body injury cue")
	sim.player.iframes = 0.0
	sim._hurt_player(5.0, &"runner", &"contact", sim.player.pos, Vector2.LEFT, true, 91)
	c.eq(view.event_last_data()["kind"], &"hurt", "partial absorption still reports an injury")
	c.ok(not view._hurts.back()["blocked"], "partial absorption keeps actual body reaction")
	c.eq(view._hurts.back()["hp_loss"], 3.0, "partial block conveys its actual health loss")
	c.eq(audio.play_count(&"hurt_contact"), 1, "actual injury plays once")
	view.free()
	audio.free()


func test_committed_interactions_survive_the_record_beat_but_not_a_new_wave(c: Check) -> void:
	var sim := _sim()
	var view := ArenaView.new()
	view.bind(sim)
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"repair":
			sim.player.pos = item["pos"]
			break
	c.ok(sim.interact(), "real machine repair commits before the phase boundary")
	c.ok(view.feedback_counts()["interactions"] > 0, "committed repair reaches presentation")
	view._on_wave_phase(sim.wave)
	c.ok(view.feedback_counts()["interactions"] > 0, "same-tick phase changes keep the result visible")
	view.set_paused(true)
	view._process(1.0)
	c.ok(view.feedback_counts()["interactions"] > 0, "pause freezes the short result receipt")
	view.set_paused(false)
	view._on_wave_started(sim.wave + 1)
	c.eq(view.feedback_counts()["interactions"], 0, "a new wave cannot inherit old action ink")
	view.free()


func test_unknown_slot_is_visible_as_a_release_but_never_guesses_a_gun(c: Check) -> void:
	var sim := _sim()
	var view := ArenaView.new()
	view.bind(sim)
	var shot := ShotInfo.new()
	shot.weapon_id = &"pistol"
	shot.origin = sim.player.pos
	shot.direction = Vector2.RIGHT
	sim.shot_fired_info.emit(shot)
	c.eq(view.feedback_counts()["muzzles"], 1, "unknown mount still shows the real release position")
	c.eq(view.recoil_amount(-1, &"pistol", 0), 0.0, "unknown slot does not borrow the first duplicate")
	shot = ShotInfo.new()
	shot.weapon_id = &"pistol"
	shot.weapon_slot = 1
	shot.origin = sim.player.pos
	sim.shot_fired_info.emit(shot)
	c.eq(view.recoil_amount(-1, &"pistol", 0), 0.0, "second slot cannot move the first duplicate")
	c.ok(view.recoil_amount(-1, &"pistol", 1) > 0.0, "actual second slot receives its recoil")
	c.eq(view.event_last_data()["weapon_slot"], 1, "diagnostics retain the actual slot")
	view.free()


func test_contact_receipt_keeps_the_actual_body_extent_after_a_target_changes(c: Check) -> void:
	var sim := _sim()
	var view := ArenaView.new()
	view.bind(sim)
	var enemy := EnemyState.new()
	enemy.uid = sim._next_uid
	sim._next_uid += 1
	enemy.def = Content.enemy(&"grunt")
	enemy.radius = enemy.def.radius
	enemy.pos = sim.player.pos + Vector2(100.0, 0.0)
	enemy.hp = 20.0
	enemy.max_hp = 20.0
	sim.enemies.append(enemy)
	var radius := enemy.radius
	var position := enemy.pos
	sim.damage_enemy(enemy, 1.0, Vector2.ZERO, false, -1, Vector2.RIGHT, &"stapler")
	c.eq(view._hits[0]["target_radius"], radius, "hit owns a value snapshot of its actual target extent")
	c.eq(view._hits[0]["pos"], position, "true contact geometry remains unchanged")
	var receipt: Vector2 = position + Vector2(0.0, radius * 0.72 + 6.0)
	c.eq(view._hits[0]["contact_pos"], receipt, "readable paper receipt clears the target face")
	enemy.pos += Vector2(50.0, 0.0)
	enemy.radius *= 2.0
	c.eq(view._hits[0]["contact_pos"], receipt, "a later target cannot move an old contact mark")
	view.free()


func test_automatic_repairs_cannot_crowd_out_player_injury_sound(c: Check) -> void:
	var active: Array[bool] = [true, true, true, true, true]
	var priorities: Array[int] = [GameAudio.SUPPORT_PRIORITY, GameAudio.SUPPORT_PRIORITY,
		GameAudio.priority_for(&"boss"), GameAudio.priority_for(&"lose"), GameAudio.priority_for(&"win")]
	var order: Array[int] = [1, 2, 3, 4, 5]
	var injury := GameAudio.priority_for(&"hurt_contact")
	c.eq(GameAudio.voice_index(active, priorities, order, injury), 0,
		"a real injury can always displace the oldest automatic repair")
	c.eq(GameAudio.voice_index(active, priorities, order, GameAudio.SUPPORT_PRIORITY), 0,
		"another repair can replace its own low-priority voice without taking a critical cue")
	var critical: Array[int] = [injury, injury, injury, injury, injury]
	c.eq(GameAudio.voice_index(active, critical, order, GameAudio.SUPPORT_PRIORITY), -1,
		"automatic patch sounds cannot interrupt five active injury cues")


func test_overlapping_station_repairs_do_not_restart_a_body_mid_recovery(c: Check) -> void:
	var director := BattleDirector.new()
	director.actor_repaired(-1)
	director.step(0.10)
	var settling := director.repair_pose(-1)
	for _station in SupportSystem.MAX_UNITS:
		director.actor_repaired(-1)
	c.eq(director.repair_pose(-1), settling,
		"several true repairs keep the current recovery instead of jittering the body back to frame zero")
	director.step(BattleDirector.REPAIR_TIME)
	c.eq(director.repair_pose(-1), Vector2.ONE, "overlapping helpers still let the body stand straight")
