extends RefCounted

const PATH := "user://test_bureau_reports.json"


func _cleanup() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _finished() -> Sim:
	var sim := Sim.new(1718)
	sim.start_run()
	sim.recorder.record(sim.player.pos + Vector2(20.0, 0.0), 0.1)
	sim._end_wave()
	sim.start_next_wave()
	sim.select_echo(sim.bank.takes[0].uid)
	sim.retire_selected_echo()
	sim.phase = Sim.Phase.LOST
	return sim


func test_actual_retirement_report_is_bounded_persisted_and_detached(c: Check) -> void:
	_cleanup()
	var sim := _finished()
	c.eq(sim.expedition["bureau"]["retired"].size(), 1, "report uses a real consumed copy")
	var meta := Meta.new(PATH)
	c.ok(meta.stage_bureau_report(sim, "verified-run-id"), "actual terminal report stages")
	c.eq(meta.bureau_reports.size(), 1, "one run report")
	c.eq(meta.bureau_reports[0]["retired"].size(), 1, "actual retirement survives staging")
	var stored: Array = meta.bureau_reports[0]["retired"].duplicate(true)
	sim.expedition["bureau"]["retired"].clear()
	c.eq(meta.bureau_reports[0]["retired"], stored, "history owns detached immutable facts")
	meta.record_run(sim)
	var loaded := Meta.new(PATH)
	c.eq(loaded.bureau_reports, meta.bureau_reports, "ordinary profile persistence includes the report exactly")
	for index in 18:
		c.ok(meta.stage_bureau_report(sim, "run_%d" % index), "bounded stage %d" % index)
	c.eq(meta.bureau_reports.size(), Meta.MAX_BUREAU_REPORTS, "oldest reports evicted at a fixed capacity")
	c.eq(meta.bureau_reports[0]["run_id"], "run_6", "keeps latest twelve reports")
	c.ok(meta.stage_bureau_report(sim, "run_10"), "same persisted id can update after continuation")
	c.eq(meta.bureau_reports.size(), Meta.MAX_BUREAU_REPORTS, "same run never creates duplicate history")
	c.eq(meta.bureau_reports[-1]["run_id"], "run_10", "updated run is the most recent report")
	_cleanup()


func test_reports_preserve_existing_permanent_profile_and_reject_bad_optional_history(c: Check) -> void:
	_cleanup()
	var old := {"best_wave": 8, "wins": 2, "inherit_echo": false, "story_clues": ["carbon"], "unlocked": {"mender": true}}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var meta := Meta.new(PATH)
	c.ok(meta.bureau_reports.is_empty(), "old permanent profile starts with empty new history")
	c.eq(meta.best_wave, 8, "old record retained")
	c.ok(meta.is_unlocked(&"mender") and not meta.inherit_echo, "unlocks and inheritance setting retained")
	c.ok(meta.story_clues.has(&"carbon"), "old clues retained")
	var sim := _finished()
	meta.stage_bureau_report(sim, "one")
	var valid := meta.bureau_reports[0].duplicate(true)
	for kind in ["unknown", "bad_gear", "bad_stage", "bad_retirement", "duplicate_id", "too_many"]:
		var bad := valid.duplicate(true)
		match kind:
			"unknown": bad["extra"] = true
			"bad_gear": bad["retired"][0]["weapon_id"] = "not_a_weapon"
			"bad_stage": bad["stage"] = 0
			"bad_retirement": bad["retired"][0]["condition"] = 101.0
		var rows: Array = [bad]
		if kind == "duplicate_id":
			rows.append(bad.duplicate(true))
		if kind == "too_many":
			for index in 12:
				rows.append(bad.duplicate(true))
		var data := old.duplicate(true)
		data["bureau_reports"] = rows
		file = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var loaded := Meta.new(PATH)
		c.ok(loaded.bureau_reports.is_empty(), "malformed optional history rejected: " + kind)
		c.eq(loaded.best_wave, 8, "invalid history never erases profile record")
		c.ok(loaded.is_unlocked(&"mender") and loaded.story_clues.has(&"carbon"), "invalid history never erases unlocks/clues")
	_cleanup()


func test_report_staging_rejects_nonterminal_or_forged_records_without_io(c: Check) -> void:
	_cleanup()
	var sim := _finished()
	var meta := Meta.new(PATH)
	c.ok(not meta.stage_bureau_report(sim, ""), "empty persisted run id rejected")
	sim.phase = Sim.Phase.WAVE
	c.ok(not meta.stage_bureau_report(sim, "run"), "active gameplay cannot invent permanent retirement history")
	sim.phase = Sim.Phase.LOST
	sim.expedition["bureau"]["retired"][0]["work"] = -1
	c.ok(not meta.stage_bureau_report(sim, "run"), "forged work count rejected")
	sim.expedition["bureau"]["retired"] = [null]
	c.ok(not meta.stage_bureau_report(sim, "run"), "invalid retirement row is refused without a script error")
	c.ok(meta.bureau_reports.is_empty() and not FileAccess.file_exists(PATH), "invalid staging changes neither memory nor disk")
	_cleanup()


func test_late_origin_archive_can_retire_in_opening_encounter_and_persist(c: Check) -> void:
	_cleanup()
	var source := EchoTake.new()
	source.wave = 12
	source.samples = PackedVector2Array([WorldArena.BOUNDS.get_center(), WorldArena.BOUNDS.get_center() + Vector2(30.0, 0.0)])
	source.weapons.append(Content.weapon(&"pistol"))
	source.levels.append(3)
	source.stats = Stats.new()
	source.condition = 80.0
	var meta := Meta.new(PATH)
	c.ok(EchoArchive.store(meta, &"looper", source), "real late-encounter archive stores")
	var sim := Sim.new(1719)
	Content.character(&"looper").apply(sim)
	var inherited := EchoArchive.load(meta, &"looper", sim)
	c.ok(inherited != null, "real opening normalization loads archived identity")
	if inherited == null:
		_cleanup()
		return
	sim.bank.add(inherited)
	sim.start_run()
	c.ok(sim.select_echo(inherited.uid), "inherited copy is a normal live actor")
	c.ok(sim.retire_selected_echo(), "actual opening retirement works")
	c.eq(sim.expedition["bureau"]["retired"][0]["recorded_wave"], 12, "original recording stage stays factual")
	c.eq(sim.expedition["bureau"]["retired"][0]["wave"], 1, "retirement is in the new opening encounter")
	var restored := RunSnapshot.restore(RunSnapshot.capture(sim))
	c.ok(restored != null, "different origin/current stages form a valid saved run: " + RunSnapshot.last_error)
	sim.phase = Sim.Phase.LOST
	c.ok(meta.stage_bureau_report(sim, "archived-origin-run"), "history accepts independent origin chronology")
	meta.record_run(sim)
	var loaded := Meta.new(PATH)
	c.eq(loaded.bureau_reports[0]["retired"][0]["recorded_wave"], 12, "permanent report retains original provenance")
	c.eq(loaded.bureau_reports[0]["retired"][0]["wave"], 1, "permanent report retains new retirement stage")
	for invalid in [-1, 100001]:
		sim.expedition["bureau"]["retired"][0]["recorded_wave"] = invalid
		var before := meta.bureau_reports.duplicate(true)
		c.ok(not meta.stage_bureau_report(sim, "invalid-origin"), "out-of-bound provenance rejected")
		c.eq(meta.bureau_reports, before, "invalid origin cannot mutate staged reports")
	_cleanup()
