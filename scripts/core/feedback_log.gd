class_name FeedbackLog
extends RefCounted

const DEFAULT_PATH := "user://feedback.jsonl"
const CATEGORIES := [&"builds", &"shop", &"combat", &"echoes", &"performance", &"other"]
const RATINGS := [&"good", &"mixed", &"frustrating"]
const SOURCES := [&"manual", &"fixture", &"bot", &"unknown"]
const MAX_NOTE_LENGTH := 500

var path: String


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


func has_feedback(run_id: String) -> bool:
	if not _valid_run_id(run_id) or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var json := JSON.new()
		if json.parse(line) != OK or typeof(json.data) != TYPE_DICTIONARY:
			continue
		var parsed: Dictionary = json.data
		if _is_feedback_record(parsed) and str(parsed.get("run_id", "")) == run_id:
			return true
	return false


func submit(run_record: Dictionary, category: StringName, rating: StringName, note: String) -> Dictionary:
	var invalid := _validate_run(run_record)
	if invalid != "":
		return _result(false, invalid)
	if category not in CATEGORIES:
		return _result(false, "invalid_category")
	if rating not in RATINGS:
		return _result(false, "invalid_rating")
	var clean_note := note.strip_edges()
	if clean_note.length() > MAX_NOTE_LENGTH:
		return _result(false, "note_too_long")
	var run_id := str(run_record["run_id"])
	if has_feedback(run_id):
		return _result(false, "duplicate")
	var record := {
		"schema_version": 1,
		"run_id": run_id,
		"category": String(category),
		"rating": String(rating),
		"note": clean_note,
		"submitted_at_utc": _utc_now(),
		"version": str(run_record["version"]),
		"build_commit": str(run_record["build_commit"]),
		"seed": int(run_record["seed"]),
		"character": str(run_record["character"]),
		"wave": int(run_record["wave"]),
		"won": bool(run_record["won"]),
		"source": str(run_record["source"]),
	}
	if not _append_record(record):
		return _result(false, "write_failed")
	return {"ok": true, "reason": "", "record": record}


func _validate_run(run_record: Dictionary) -> String:
	var version_type := typeof(run_record.get("version"))
	var character_type := typeof(run_record.get("character"))
	var source_type := typeof(run_record.get("source"))
	var commit_type := typeof(run_record.get("build_commit"))
	var run_id := str(run_record.get("run_id", ""))
	if not _valid_run_id(run_id):
		return "invalid_run"
	var source := StringName(str(run_record.get("source", "")))
	if source not in SOURCES:
		return "invalid_provenance"
	if str(run_record.get("build_commit", "")).strip_edges() == "":
		return "invalid_provenance"
	if not run_record.has("version") or not run_record.has("seed") \
			or not run_record.has("character") or not run_record.has("wave") \
			or not run_record.has("won"):
		return "invalid_run"
	if version_type not in [TYPE_STRING, TYPE_STRING_NAME] \
			or character_type not in [TYPE_STRING, TYPE_STRING_NAME] \
			or source_type not in [TYPE_STRING, TYPE_STRING_NAME] \
			or commit_type not in [TYPE_STRING, TYPE_STRING_NAME] \
			or str(run_record.get("version", "")).strip_edges() == "" \
			or str(run_record.get("character", "")).strip_edges() == "" \
			or not _integral_number(run_record.get("seed")) \
			or not _integral_number(run_record.get("wave")) \
			or typeof(run_record.get("won")) != TYPE_BOOL:
		return "invalid_run"
	return ""


func _append_record(record: Dictionary) -> bool:
	var existed := FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE) if existed else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	if existed:
		file.seek_end()
		var length := file.get_position()
		if length > 0:
			file.seek(length - 1)
			if file.get_8() != 10:
				file.seek_end()
				file.store_8(10)
		file.seek_end()
	file.store_line(JSON.stringify(record))
	file.flush()
	return file.get_error() == OK


func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason, "record": {}}


func _is_feedback_record(value: Dictionary) -> bool:
	if not _integral_number(value.get("schema_version")) \
			or int(value.get("schema_version")) != 1 \
			or _validate_run(value) != "":
		return false
	var category_type := typeof(value.get("category"))
	var rating_type := typeof(value.get("rating"))
	var note_type := typeof(value.get("note"))
	var submitted_type := typeof(value.get("submitted_at_utc"))
	return category_type in [TYPE_STRING, TYPE_STRING_NAME] \
			and rating_type in [TYPE_STRING, TYPE_STRING_NAME] \
			and note_type in [TYPE_STRING, TYPE_STRING_NAME] \
			and submitted_type in [TYPE_STRING, TYPE_STRING_NAME] \
			and StringName(str(value.get("category"))) in CATEGORIES \
			and StringName(str(value.get("rating"))) in RATINGS \
			and str(value.get("note")).length() <= MAX_NOTE_LENGTH \
			and str(value.get("submitted_at_utc")).strip_edges() != ""


func _integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and floorf(number) == number


func _valid_run_id(value: String) -> bool:
	if value.length() < 8 or value.length() > 128:
		return false
	for i in value.length():
		var code := value.unicode_at(i)
		var valid := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or code in [45, 46, 58, 95]
		if not valid:
			return false
	return true


func _utc_now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
