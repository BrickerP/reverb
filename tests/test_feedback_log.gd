extends RefCounted

const PATH := "user://test_feedback.jsonl"


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _run(run_id: String = "run-valid-123") -> Dictionary:
	return {
		"schema_version": 2,
		"run_id": run_id,
		"build_commit": "abc123",
		"version": "0.2.0",
		"seed": 27,
		"character": "looper",
		"wave": 4,
		"won": false,
		"source": "fixture",
		"kills": 99,
		"caller_extra": "must-not-leak",
	}


func test_submit_roundtrips_snapshot_and_escaped_note(c: Check) -> void:
	_cleanup()
	var log := FeedbackLog.new(PATH)
	var result := log.submit(_run(), &"combat", &"mixed", "  quoted \"text\"\nand newline  ")
	c.eq(result.get("ok"), true, "valid feedback succeeds")
	c.eq(result.get("reason"), "", "success has no error reason")
	var record: Dictionary = result.get("record", {})
	c.eq(record.get("note"), "quoted \"text\"\nand newline", "note is trimmed without losing escaped text")
	c.eq(record.get("schema_version"), 1, "feedback schema version")
	c.eq(record.get("version"), "0.2.0", "application version is snapshotted")
	c.eq(record.get("seed"), 27, "run seed is snapshotted")
	c.eq(record.get("source"), "fixture", "run source is snapshotted")
	c.ok(not record.has("kills") and not record.has("caller_extra"), "arbitrary run fields are excluded")
	c.ok(str(record.get("submitted_at_utc", "")).ends_with("Z"), "submission time is UTC")
	c.eq(log.has_feedback("run-valid-123"), true, "saved feedback can be found")
	var file := FileAccess.open(PATH, FileAccess.READ)
	var decoded: Variant = JSON.parse_string(file.get_line())
	c.eq(typeof(decoded), TYPE_DICTIONARY, "escaped feedback remains valid JSON")
	c.eq(decoded.get("note", ""), record.get("note", "missing"), "JSON roundtrip preserves note")
	_cleanup()


func test_invalid_inputs_and_duplicate_are_rejected(c: Check) -> void:
	_cleanup()
	var log := FeedbackLog.new(PATH)
	c.eq(log.submit({}, &"combat", &"good", "").get("reason"), "invalid_run", "missing run is rejected")
	var invalid_provenance := _run()
	invalid_provenance["source"] = "human"
	c.eq(log.submit(invalid_provenance, &"combat", &"good", "").get("reason"), "invalid_provenance", "unknown provenance value is rejected")
	c.eq(log.submit(_run(), &"balance", &"good", "").get("reason"), "invalid_category", "unknown category is rejected")
	c.eq(log.submit(_run(), &"combat", &"bad", "").get("reason"), "invalid_rating", "unknown rating is rejected")
	c.eq(log.submit(_run(), &"combat", &"good", "x".repeat(501)).get("reason"), "note_too_long", "long note is rejected")
	var invalid_seed := _run()
	invalid_seed["seed"] = [27]
	c.eq(log.submit(invalid_seed, &"combat", &"good", "").get("reason"), "invalid_run", "non-numeric seed is rejected")
	var invalid_wave := _run()
	invalid_wave["wave"] = NAN
	c.eq(log.submit(invalid_wave, &"combat", &"good", "").get("reason"), "invalid_run", "non-integer wave is rejected")
	var fractional_wave := _run()
	fractional_wave["wave"] = 2.5
	c.eq(log.submit(fractional_wave, &"combat", &"good", "").get("reason"), "invalid_run", "fractional wave is rejected")
	var json_run: Variant = JSON.parse_string(JSON.stringify(_run("run-json-456")))
	c.eq(log.submit(json_run, &"builds", &"mixed", "parsed").get("ok"), true, "integral JSON numbers are accepted")
	c.eq(log.submit(_run(), &"shop", &"good", "first").get("ok"), true, "first feedback succeeds")
	c.eq(log.submit(_run(), &"shop", &"mixed", "second").get("reason"), "duplicate", "second feedback is rejected")
	_cleanup()


func test_corrupt_rows_are_skipped_and_partial_tail_is_separated(c: Check) -> void:
	_cleanup()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_line(JSON.stringify({
		"schema_version": 1,
		"run_id": "run-valid-123",
		"category": "echoes",
		"rating": "frustrating",
	}))
	file.store_string("not-json")
	file.close()
	var log := FeedbackLog.new(PATH)
	c.eq(log.has_feedback("run-valid-123"), false, "malformed and corrupt rows are ignored")
	var result := log.submit(_run(), &"echoes", &"frustrating", "usable")
	c.eq(result.get("ok"), true, "valid feedback appends after corrupt partial tail")
	var read := FileAccess.open(PATH, FileAccess.READ)
	c.ok(read.get_line().contains("run-valid-123"), "malformed input is preserved")
	c.eq(read.get_line(), "not-json", "corrupt input is preserved")
	var parsed: Variant = JSON.parse_string(read.get_line())
	c.eq(typeof(parsed), TYPE_DICTIONARY, "new record starts on its own JSON line")
	c.eq(log.has_feedback("run-valid-123"), true, "valid row after corruption is found")
	c.eq(log.submit(_run(), &"echoes", &"good", "again").get("reason"), "duplicate", "complete row blocks exactly one retry")
	_cleanup()


func test_write_failure_is_reported(c: Check) -> void:
	var log := FeedbackLog.new("res://project.godot/cannot-write.jsonl")
	var result := log.submit(_run(), &"performance", &"mixed", "")
	c.eq(result.get("ok"), false, "failed write is unsuccessful")
	c.eq(result.get("reason"), "write_failed", "failed write has a stable reason")
	c.eq(result.get("record"), {}, "failed write does not claim a saved record")
