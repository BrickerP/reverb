class_name RunLog
extends RefCounted

const DEFAULT_PATH := "user://runs.jsonl"

var path: String


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


func folder_path() -> String:
	return ProjectSettings.globalize_path(path.get_base_dir())


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
func append(sim: Sim, character_id: StringName, seconds: float) -> void:
	if sim == null:
		return
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
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"seed": sim.run_seed,
		"character": String(character_id),
		"wave": sim.wave,
		"won": sim.phase == Sim.Phase.WON,
		"kills": sim.kills,
		"seconds": snappedf(seconds, 0.1),
		"weapons": weapons,
		"items": items,
		"echoes": sim.bank.takes.size(),
		"merged": merged,
		"earned": sim.last_wave_earned,
		"interest": sim.last_interest,
		"best_echo_wave": best_wave,
		"best_echo_dps": int(round(best_dps)),
	}
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(data))
