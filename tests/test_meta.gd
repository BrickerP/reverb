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
	c.ok(not meta.is_unlocked(&"mirror"), "mirror still needs a win")
	var loaded := Meta.new(PATH)
	c.ok(loaded.is_unlocked(&"solo"), "unlock persists")
	c.eq(loaded.runs, 2, "runs persist")
	_cleanup()


func test_daily_best_persists_and_resets(c: Check) -> void:
	_cleanup()
	var meta := Meta.new(PATH)
	var s := Sim.new(1)
	s.start_run()
	s.phase = Sim.Phase.LOST
	s.wave = 8
	meta.record_daily(s, 20261023)
	c.eq(meta.daily_seed, 20261023, "daily seed recorded")
	c.eq(meta.daily_best, 8, "daily best recorded")
	s.wave = 20
	s.phase = Sim.Phase.WON
	meta.record_daily(s, 20261023)
	c.eq(meta.daily_best, 20, "daily best improves")
	c.eq(meta.daily_wins, 1, "daily win counted")
	var loaded := Meta.new(PATH)
	c.eq(loaded.daily_best, 20, "daily best persists")
	s.wave = 3
	s.phase = Sim.Phase.LOST
	meta.record_daily(s, 20261024)
	c.eq(meta.daily_seed, 20261024, "a new day resets the seed")
	c.eq(meta.daily_best, 3, "a new day resets the best")
	_cleanup()


func test_wins_and_corrupt_file(c: Check) -> void:
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
	c.ok(meta.is_unlocked(&"mirror"), "a win unlocks the mirror")
	var loaded := Meta.new(PATH)
	c.eq(loaded.wins, 1, "win persists")
	_cleanup()
