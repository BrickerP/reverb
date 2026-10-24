extends RefCounted

const PATH := "user://test_runs.jsonl"


func _cleanup() -> void:
	var abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)


func test_append_writes_one_json_line(c: Check) -> void:
	_cleanup()
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.LOST
	s.wave = 5
	s.kills = 42
	s.last_damage_source = &"warden"
	s.player.add_item(Content.item(&"iron_heart"))
	var log := RunLog.new(PATH)
	var context := log.new_context("fixture")
	var saved := log.append(s, &"looper", 123.4, context)
	log.append(s, &"solo", 2.0)
	c.eq(saved.get("run_id", ""), context.get("run_id", "missing"), "append preserves context run ID")
	c.eq(saved.get("schema_version", 0), 2, "new row schema")
	c.eq(saved.get("source", ""), "fixture", "source provenance")
	c.eq(saved.get("started_at_utc", ""), context.get("started_at_utc", "missing"), "start time is persisted")
	c.ok(str(saved.get("recorded_at_utc", "")).ends_with("Z"), "recording time is UTC")
	var file := FileAccess.open(PATH, FileAccess.READ)
	c.ok(file != null, "log file exists")
	var lines := 0
	var first := {}
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() == "":
			continue
		var data: Variant = JSON.parse_string(line)
		c.eq(typeof(data), TYPE_DICTIONARY, "each line is an object")
		if lines == 0:
			first = data
		lines += 1
	c.eq(lines, 2, "two runs")
	c.eq(int(first.get("seed", 0)), 7, "seed")
	c.eq(str(first.get("character", "")), "looper", "character")
	c.eq(str(first.get("version", "")), "0.7.0", "build version")
	c.eq(int(first.get("wave", 0)), 5, "wave")
	c.eq(bool(first.get("won", true)), false, "loss")
	c.eq(int(first.get("kills", 0)), 42, "kills")
	c.eq(str(first.get("death_cause", "")), "warden", "death cause")
	c.near(float(first.get("seconds", 0.0)), 123.4, 0.01, "duration")
	c.ok((first.get("items", {}) as Dictionary).has("iron_heart"), "items recorded")
	var recent := log.recent(1)
	c.eq(recent.size(), 1, "recent respects the limit")
	c.eq(int(recent[0].get("seed", 0)), 7, "recent keeps the last run")
	_cleanup()


func test_context_uses_unique_crypto_ids_without_touching_sim_rng(c: Check) -> void:
	_cleanup()
	var previous_env := OS.get_environment("REVERB_BUILD_COMMIT")
	OS.set_environment("REVERB_BUILD_COMMIT", "test-commit")
	var configured_commit := str(ProjectSettings.get_setting("application/config/build_commit", "")).strip_edges()
	var sim := Sim.new(91)
	var state_before := sim.rng.state
	var log := RunLog.new(PATH)
	var a := log.new_context("manual")
	var b := log.new_context("not-a-source")
	c.ok(str(a.get("run_id", "")).length() >= 32, "context has a substantial random ID")
	c.ok(a.get("run_id") != b.get("run_id"), "contexts have unique IDs")
	c.eq(a.get("source"), "manual", "valid source is retained")
	c.eq(b.get("source"), "unknown", "invalid source becomes unknown")
	var expected_commit := configured_commit if configured_commit != "" else "test-commit"
	c.eq(a.get("build_commit"), expected_commit, "configured stamp precedes environment fallback")
	c.ok(str(a.get("started_at_utc", "")).ends_with("Z"), "start time is UTC")
	c.eq(sim.rng.state, state_before, "context generation does not consume Sim RNG")
	OS.set_environment("REVERB_BUILD_COMMIT", previous_env)
	_cleanup()


func test_legacy_and_partial_tail_rows_remain_readable(c: Check) -> void:
	_cleanup()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 3, "character": "legacy"}))
	file.close()
	var sim := Sim.new(8)
	sim.start_run()
	var saved := RunLog.new(PATH).append(sim, &"looper", 1.0)
	c.ok(not saved.is_empty(), "append after a partial tail succeeds")
	var rows := RunLog.new(PATH).recent(10)
	c.eq(rows.size(), 2, "missing final newline does not merge JSON rows")
	c.eq(rows[0].get("character"), "legacy", "legacy row remains readable")
	c.eq(rows[1].get("schema_version"), 2, "new row follows legacy row")
	_cleanup()


func test_append_surfaces_write_failure(c: Check) -> void:
	var sim := Sim.new(1)
	sim.start_run()
	var saved := RunLog.new("res://project.godot/cannot-write.jsonl").append(sim, &"looper", 1.0)
	c.eq(saved, {}, "failed file open returns an empty record")
