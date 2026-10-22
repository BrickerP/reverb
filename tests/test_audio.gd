extends RefCounted


func _audio() -> GameAudio:
	var a := GameAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	return a


func test_streams_load(c: Check) -> void:
	var a := _audio()
	c.eq(a.stream_count(), GameAudio.NAMES.size(), "one stream per effect")
	for name in GameAudio.NAMES:
		c.ok(a.has_stream(name), "loaded %s" % name)
	a.free()


func test_play_and_cooldown(c: Check) -> void:
	var a := _audio()
	c.ok(a.play(&"hit"), "the first hit plays")
	c.eq(a.play_count(&"hit"), 1, "counted once")
	c.ok(not a.play(&"hit"), "the cooldown suppresses the next hit")
	c.eq(a.play_count(&"hit"), 1, "still once")
	a.free()


func test_sim_signals_drive_sound(c: Check) -> void:
	var a := _audio()
	var s := Sim.new(3)
	s.start_run()
	a.bind(s)
	s.purchased.emit()
	c.eq(a.play_count(&"buy"), 1, "purchase sound")
	s.material_collected.emit(1)
	c.eq(a.play_count(&"pickup"), 1, "pickup sound")
	s.player_hurt.emit(3.0)
	c.eq(a.play_count(&"hurt"), 1, "hurt sound")
	s.wave_started.emit(2)
	c.eq(a.play_count(&"wave_start"), 1, "wave start sound")
	a.free()


func test_mute_toggles_the_master_bus(c: Check) -> void:
	var a := _audio()
	c.ok(not a.is_muted(), "starts unmuted")
	c.ok(a.toggle_mute(), "mutes")
	c.ok(AudioServer.is_bus_mute(0), "master bus is muted")
	c.ok(not a.toggle_mute(), "unmutes")
	c.ok(not AudioServer.is_bus_mute(0), "master bus is back")
	a.free()
