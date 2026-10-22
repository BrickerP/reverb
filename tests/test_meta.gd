extends RefCounted

const PATH := "user://test_meta_save.json"


func _cleanup() -> void:
	var abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)


func test_defaults_and_unlock_at_wave_ten(c: Check) -> void:
	_cleanup()
	var meta := Meta.new(PATH)
	c.ok(meta.is_unlocked(&"looper"), "looper starts unlocked")
	c.ok(not meta.is_unlocked(&"solo"), "solo starts locked")
	c.eq(meta.best_wave, 0, "fresh best wave")
	var s := Sim.new(1)
	s.start_run()
	s.phase = Sim.Phase.LOST
	s.wave = 9
	var newly := meta.record_run(s)
	c.ok(newly.is_empty(), "wave 9 unlocks nothing")
	c.eq(meta.best_wave, 9, "best wave recorded")
	s.wave = 10
	newly = meta.record_run(s)
	c.eq(newly.size(), 1, "one character unlocked")
	c.ok(meta.is_unlocked(&"solo"), "solo is unlocked at wave 10")
	var loaded := Meta.new(PATH)
	c.ok(loaded.is_unlocked(&"solo"), "unlock persists")
	c.eq(loaded.runs, 2, "runs persist")
	_cleanup()


func test_wins_and_corrupt_file(c: Check) -> void:
	_cleanup()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not json")
	file = null
	var meta := Meta.new(PATH)
	c.ok(meta.is_unlocked(&"looper"), "corrupt save falls back to defaults")
	c.eq(meta.wins, 0, "no wins")
	var s := Sim.new(1)
	s.start_run()
	s.phase = Sim.Phase.WON
	s.wave = 20
	meta.record_run(s)
	c.eq(meta.wins, 1, "win counted")
	var loaded := Meta.new(PATH)
	c.eq(loaded.wins, 1, "win persists")
	_cleanup()
