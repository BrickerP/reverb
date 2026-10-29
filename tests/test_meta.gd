extends RefCounted

const PATH := "user://test_meta_save.json"


func _cleanup() -> void:
	var abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)


func test_defaults_and_character_unlock_wave_boundaries(c: Check) -> void:
	for role: StringName in [&"mender", &"solo", &"overloader", &"conductor"]:
		_cleanup()
		var meta := Meta.new(PATH)
		c.ok(meta.is_unlocked(&"looper"), "looper starts unlocked")
		c.ok(not meta.is_unlocked(role), "%s starts locked" % role)
		var threshold := Content.character(role).unlock_wave
		c.ok(threshold > 0 and threshold <= WaveDirector.FINAL_WAVE, "unlock fits complete campaign")
		var sim := Sim.new(1)
		sim.phase = Sim.Phase.LOST
		sim.wave = threshold - 1
		meta.record_run(sim)
		c.ok(not meta.is_unlocked(role), "%s stays locked before authored stage" % role)
		sim.wave = threshold
		meta.record_run(sim)
		c.ok(meta.is_unlocked(role), "%s unlocks at authored stage" % role)
		var loaded := Meta.new(PATH)
		c.ok(loaded.is_unlocked(role), "%s unlock persists" % role)
		c.eq(loaded.best_wave, threshold, "best stage persists")
		c.ok(not loaded.is_unlocked(&"mirror"), "mirror still requires a win")
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


func test_daily_streak_counts_consecutive_wins(c: Check) -> void:
	_cleanup()
	c.ok(Meta.next_calendar_day(20261024, 20261025), "consecutive dates")
	c.ok(not Meta.next_calendar_day(20261024, 20261026), "a skipped day is not consecutive")
	var meta := Meta.new(PATH)
	var s := Sim.new(1)
	s.start_run()
	s.phase = Sim.Phase.WON
	s.wave = 20
	meta.record_daily(s, 20261024)
	c.eq(meta.daily_streak, 1, "first daily win starts a streak")
	meta.record_daily(s, 20261024)
	c.eq(meta.daily_streak, 1, "the same day does not add a streak")
	meta.record_daily(s, 20261025)
	c.eq(meta.daily_streak, 2, "the next day extends the streak")
	meta.record_daily(s, 20261027)
	c.eq(meta.daily_streak, 1, "a skipped day resets the streak")
	var loaded := Meta.new(PATH)
	c.eq(loaded.daily_streak, 1, "streak persists")
	c.eq(loaded.daily_last_win_seed, 20261027, "last win day persists")
	_cleanup()


func test_endless_and_boss_rush_bests_persist(c: Check) -> void:
	_cleanup()
	var meta := Meta.new(PATH)
	var s := Sim.new(1)
	s.start_run()
	c.eq(meta.best_endless, 0, "fresh endless best")
	c.eq(meta.best_boss_rush, 0, "fresh boss rush best")
	s.endless = true
	s.wave = 33
	meta.record_endless(s)
	c.eq(meta.best_endless, 33, "endless best recorded")
	s.boss_rush = true
	s.wave = 40
	meta.record_endless(s)
	c.eq(meta.best_boss_rush, 40, "boss rush best recorded")
	c.eq(meta.best_endless, 33, "boss rush does not overwrite endless best")
	var loaded := Meta.new(PATH)
	c.eq(loaded.best_endless, 33, "endless best persists")
	c.eq(loaded.best_boss_rush, 40, "boss rush best persists")
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


func test_ascension_unlocks_with_wins_and_persists(c: Check) -> void:
	_cleanup()
	var meta := Meta.new(PATH)
	c.eq(meta.max_ascension(), 0, "a fresh profile has no ascension")
	meta.set_ascension(2)
	c.eq(meta.ascension, 0, "ascension is clamped to the unlocked maximum")
	var s := Sim.new(1)
	s.start_run()
	s.phase = Sim.Phase.WON
	s.wave = 20
	meta.record_run(s)
	c.eq(meta.max_ascension(), 1, "one win unlocks level 1")
	meta.set_ascension(1)
	c.eq(meta.ascension, 1, "level 1 can be selected")
	var loaded := Meta.new(PATH)
	c.eq(loaded.ascension, 1, "ascension persists")
	meta.record_run(s)
	meta.set_ascension(3)
	c.eq(meta.ascension, 2, "three wins unlock two levels, not three")
	meta.record_run(s)
	meta.set_ascension(3)
	c.eq(meta.ascension, 3, "three wins unlock level 3")
	_cleanup()
