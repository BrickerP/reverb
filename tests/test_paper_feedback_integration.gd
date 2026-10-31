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
	c.eq(view._director.counts()["contacts"], 0, "full block cannot trigger the body's hurt contact")
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
