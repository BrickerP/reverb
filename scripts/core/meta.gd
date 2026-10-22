class_name Meta
extends RefCounted

const DEFAULT_PATH := "user://reverb_save.json"

var path: String
var best_wave: int = 0
var wins: int = 0
var runs: int = 0
var daily_seed: int = 0
var daily_best: int = 0
var daily_wins: int = 0
var unlocked: Dictionary = {}


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	_defaults()
	_load()


func _defaults() -> void:
	best_wave = 0
	wins = 0
	runs = 0
	daily_seed = 0
	daily_best = 0
	daily_wins = 0
	unlocked = {}
	for def: CharacterDef in Content.characters().values():
		unlocked[def.id] = def.unlock_wave <= 0 and def.unlock_wins <= 0


func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	best_wave = int(data.get("best_wave", 0))
	wins = int(data.get("wins", 0))
	runs = int(data.get("runs", 0))
	daily_seed = int(data.get("daily_seed", 0))
	daily_best = int(data.get("daily_best", 0))
	daily_wins = int(data.get("daily_wins", 0))
	var saved: Variant = data.get("unlocked", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for key: Variant in (saved as Dictionary):
			var id := StringName(str(key))
			if unlocked.has(id):
				unlocked[id] = bool((saved as Dictionary)[key])


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	var flags := {}
	for id: StringName in unlocked:
		flags[String(id)] = bool(unlocked[id])
	file.store_string(JSON.stringify({
		"best_wave": best_wave,
		"wins": wins,
		"runs": runs,
		"daily_seed": daily_seed,
		"daily_best": daily_best,
		"daily_wins": daily_wins,
		"unlocked": flags,
	}, "\t"))


func is_unlocked(id: StringName) -> bool:
	return bool(unlocked.get(id, false))


# Records one finished run and returns any characters unlocked by it.
func record_run(sim: Sim) -> Array[StringName]:
	runs += 1
	best_wave = maxi(best_wave, sim.wave)
	if sim.phase == Sim.Phase.WON:
		wins += 1
	var newly: Array[StringName] = []
	for def: CharacterDef in Content.characters().values():
		if not is_unlocked(def.id) and best_wave >= def.unlock_wave and wins >= def.unlock_wins:
			unlocked[def.id] = true
			newly.append(def.id)
	save()
	return newly


func record_daily(sim: Sim, seed_value: int) -> void:
	if daily_seed != seed_value:
		daily_seed = seed_value
		daily_best = 0
		daily_wins = 0
	daily_best = maxi(daily_best, sim.wave)
	if sim.phase == Sim.Phase.WON:
		daily_wins += 1
	save()
