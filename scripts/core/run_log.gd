class_name RunLog
extends RefCounted

const DEFAULT_PATH := "user://runs.jsonl"
const SCHEMA_VERSION := 2
const VALID_SOURCES := [&"manual", &"fixture", &"bot", &"unknown"]

var path: String


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


func folder_path() -> String:
	return ProjectSettings.globalize_path(path.get_base_dir())


func remove_last() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n", false)
	if lines.is_empty():
		return false
	lines.remove_at(lines.size() - 1)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	for line in lines:
		file.store_line(line)
	return true


func new_context(source: String = "unknown") -> Dictionary:
	return {
		"run_id": _new_run_id(),
		"started_at_utc": _utc_now(),
		"source": _valid_source(source),
		"build_commit": _build_commit(),
	}


func recent(limit: int = 8) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var json := JSON.new()
		if json.parse(line) != OK or typeof(json.data) != TYPE_DICTIONARY:
			continue
		out.append(json.data)
		if out.size() > limit:
			out.pop_front()
	return out


# Appends one finished run as a JSON line. Local only; never uploaded.
func append(sim: Sim, character_id: StringName, seconds: float, context: Dictionary = {}) -> Dictionary:
	if sim == null:
		return {}
	var actual_context := context
	if actual_context.is_empty():
		actual_context = new_context()
	var run_id := str(actual_context.get("run_id", ""))
	if not _valid_run_id(run_id):
		run_id = _new_run_id()
	if not _valid_run_id(run_id):
		return {}
	var build_commit := str(actual_context.get("build_commit", "")).strip_edges()
	if build_commit == "":
		build_commit = _build_commit()
	var recorded_at_utc := _utc_now()
	var started_at_utc := str(actual_context.get("started_at_utc", "")).strip_edges()
	if started_at_utc == "":
		started_at_utc = recorded_at_utc
	var weapons := PackedStringArray()
	for w in sim.player.weapons:
		weapons.append(String(w.id))
	var items := {}
	for id: StringName in sim.player.items:
		items[String(id)] = int(sim.player.items[id])
	var merged := 0
	for take: EchoTake in sim.bank.takes:
		if take.merged:
			merged += 1
	var best_wave := 0
	var best_dps := -1.0
	for take: EchoTake in sim.bank.takes:
		var dps := sim.echo_dps(take)
		if dps > best_dps:
			best_dps = dps
			best_wave = take.wave
	if best_dps < 0.0:
		best_dps = 0.0
	var data := {
		"schema_version": SCHEMA_VERSION,
		"run_id": run_id,
		"started_at_utc": started_at_utc,
		"recorded_at_utc": recorded_at_utc,
		"source": _valid_source(str(actual_context.get("source", "unknown"))),
		"build_commit": build_commit,
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"seed": sim.run_seed,
		"character": String(character_id),
		"wave": sim.wave,
		"won": sim.phase == Sim.Phase.WON,
		"endless": sim.endless,
		"ascension": sim.ascension,
		"daily_modifier": String(sim.daily_modifier),
		"kills": sim.kills,
		"seconds": snappedf(seconds, 0.1),
		"weapons": weapons,
		"items": items,
		"echoes": sim.bank.takes.size(),
		"merged": merged,
		"earned": sim.last_wave_earned,
		"interest": sim.last_interest,
		"death_cause": String(sim.last_damage_source),
		"best_echo_wave": best_wave,
		"best_echo_dps": int(round(best_dps)),
	}
	var existed := FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE) if existed else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {}
	if existed:
		file.seek_end()
		var length := file.get_position()
		if length > 0:
			file.seek(length - 1)
			if file.get_8() != 10:
				file.seek_end()
				file.store_8(10)
		file.seek_end()
	file.store_line(JSON.stringify(data))
	file.flush()
	if file.get_error() != OK:
		return {}
	return data


func _build_commit() -> String:
	var stamp := str(ProjectSettings.get_setting("application/config/build_commit", "")).strip_edges()
	if stamp != "":
		return stamp
	stamp = OS.get_environment("REVERB_BUILD_COMMIT").strip_edges()
	return stamp if stamp != "" else "unavailable"


func _valid_source(value: String) -> String:
	var normalized := StringName(value.strip_edges().to_lower())
	return String(normalized) if normalized in VALID_SOURCES else "unknown"


func _new_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	# UUID v4 bits make these OS-random identifiers recognizable across tools.
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


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
