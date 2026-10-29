class_name SuspendStore
extends RefCounted

const DEFAULT_PATH := "user://suspended_run.json"
const MAX_BYTES := 32 * 1024 * 1024
static var last_error: String = ""


static func path() -> String:
	var override := OS.get_environment("REVERB_SUSPEND")
	return override if override != "" else DEFAULT_PATH


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func clear() -> bool:
	last_error = ""
	if not exists():
		return true
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path())) != OK:
		last_error = "suspend.clear_failed"
		return false
	return true


static func save(sim: Sim, envelope: Dictionary = {}) -> bool:
	last_error = ""
	var snapshot := RunSnapshot.capture(sim)
	if snapshot.is_empty():
		last_error = RunSnapshot.last_error
		return false
	var encoded: Variant = RunSnapshot.encode_envelope(envelope)
	if encoded == null:
		last_error = RunSnapshot.last_error
		return false
	var text := JSON.stringify({"snapshot": snapshot, "envelope": encoded}, "", true, true)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "snapshot.too_large"
		return false
	# Decode before touching the old file, including its Main envelope. This also
	# proves a live run can resume before Save and Return closes it.
	if _parse(text).is_empty():
		return false
	var absolute := ProjectSettings.globalize_path(path())
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "suspend.write_failed"
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		last_error = "suspend.write_failed"
		return false
	# Rename replaces the destination atomically in the same directory. A failed
	# rename leaves the previous suspension usable.
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		last_error = "suspend.write_failed"
		return false
	return true


static func load() -> Dictionary:
	last_error = ""
	var file := FileAccess.open(path(), FileAccess.READ)
	if file == null:
		last_error = "suspend.read_failed"
		return {}
	if file.get_length() > MAX_BYTES:
		last_error = "snapshot.too_large"
		return {}
	return _parse(file.get_as_text())


static func _parse(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		last_error = "suspend.corrupt"
		return {}
	var data: Dictionary = parser.data
	if typeof(data.get("snapshot")) != TYPE_DICTIONARY or not data.has("envelope"):
		last_error = "suspend.corrupt"
		return {}
	var sim := RunSnapshot.restore(data.snapshot)
	if sim == null:
		last_error = RunSnapshot.last_error
		return {}
	var envelope := RunSnapshot.decode_envelope(data.envelope)
	if RunSnapshot.last_error != "":
		last_error = RunSnapshot.last_error
		return {}
	return {"sim": sim, "envelope": envelope}
