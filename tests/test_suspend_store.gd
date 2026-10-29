extends RefCounted

const PATH := "user://test_suspended_run.json"


func _clean() -> void:
	for suffix in ["", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(PATH + suffix)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


func test_save_load_and_overwrite_are_exact(c: Check) -> void:
	var previous := OS.get_environment("REVERB_SUSPEND")
	OS.set_environment("REVERB_SUSPEND", PATH)
	_clean()
	var sim := Sim.new(99)
	sim.start_run()
	sim.step(0.037, Vector2.RIGHT)
	sim.player.hp = 12.25
	var envelope := {"screen": &"battle", "paused": true, "delay": 0.2718281828459, "seed": 9223372036854775806}
	c.ok(SuspendStore.save(sim, envelope), "save succeeds: %s" % SuspendStore.last_error)
	c.ok(SuspendStore.exists(), "suspension exists")
	var loaded := SuspendStore.load()
	c.ok(not loaded.is_empty(), "load succeeds: %s" % SuspendStore.last_error)
	if not loaded.is_empty():
		c.eq(RunSnapshot.capture(loaded.sim), RunSnapshot.capture(sim), "store keeps exact battle")
		c.eq(loaded.envelope, envelope, "Main envelope exact including int64 and float")
	sim.player.hp = 7.5
	c.ok(SuspendStore.save(sim, envelope), "atomic overwrite succeeds")
	loaded = SuspendStore.load()
	if not loaded.is_empty():
		c.eq(loaded.sim.player.hp, 7.5, "replacement contains latest run")
	c.ok(SuspendStore.clear(), "clear succeeds")
	c.ok(not SuspendStore.exists(), "clear removes suspension")
	_clean()
	OS.set_environment("REVERB_SUSPEND", previous)


func test_corrupt_file_and_failed_save_preserve_live_run_and_previous_save(c: Check) -> void:
	var previous := OS.get_environment("REVERB_SUSPEND")
	OS.set_environment("REVERB_SUSPEND", PATH)
	_clean()
	var sim := Sim.new(43)
	sim.start_run()
	sim.step(0.123, Vector2.DOWN)
	var before := RunSnapshot.capture(sim)
	c.ok(SuspendStore.save(sim), "initial save exists")
	var original := FileAccess.get_file_as_string(PATH)
	var bad_envelope := {"object": Node.new()}
	c.ok(not SuspendStore.save(sim, bad_envelope), "unsafe envelope rejected")
	(bad_envelope.object as Node).free()
	c.eq(FileAccess.get_file_as_string(PATH), original, "failed save leaves previous bytes intact")
	OS.set_environment("REVERB_SUSPEND", "user://missing_suspend_folder/run.json")
	c.ok(not SuspendStore.save(sim), "unwritable destination reports failure")
	c.eq(RunSnapshot.capture(sim), before, "save failure preserves live run")
	OS.set_environment("REVERB_SUSPEND", PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	c.ok(SuspendStore.load().is_empty(), "corrupt file rejected")
	c.eq(SuspendStore.last_error, "suspend.corrupt", "corruption exposed to menu")
	c.eq(RunSnapshot.capture(sim), before, "corrupt load preserves live run")
	_clean()
	OS.set_environment("REVERB_SUSPEND", previous)
