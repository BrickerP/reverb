class_name Meta
extends RefCounted

const DEFAULT_PATH := "user://reverb_save.json"

var path: String
var last_error: String = ""
var best_wave: int = 0
var best_endless: int = 0
var best_boss_rush: int = 0
var wins: int = 0
var runs: int = 0
var daily_seed: int = 0
var daily_best: int = 0
var daily_wins: int = 0
var daily_streak: int = 0
var daily_last_win_seed: int = 0
var ascension: int = 0
var unlocked: Dictionary = {}
var story_clues: Array[StringName] = []
var echo_archives: Dictionary = {}
var inherit_echo: bool = true


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	_defaults()
	_load()


func _defaults() -> void:
	best_wave = 0
	best_endless = 0
	best_boss_rush = 0
	wins = 0
	runs = 0
	daily_seed = 0
	daily_best = 0
	daily_wins = 0
	daily_streak = 0
	daily_last_win_seed = 0
	ascension = 0
	unlocked = {}
	story_clues.clear()
	echo_archives.clear()
	inherit_echo = true
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
	best_endless = int(data.get("best_endless", 0))
	best_boss_rush = int(data.get("best_boss_rush", 0))
	wins = int(data.get("wins", 0))
	runs = int(data.get("runs", 0))
	daily_seed = int(data.get("daily_seed", 0))
	daily_best = int(data.get("daily_best", 0))
	daily_wins = int(data.get("daily_wins", 0))
	daily_streak = int(data.get("daily_streak", 0))
	daily_last_win_seed = int(data.get("daily_last_win_seed", 0))
	ascension = clampi(int(data.get("ascension", 0)), 0, max_ascension())
	inherit_echo = bool(data.get("inherit_echo", true))
	var saved_archives: Variant = data.get("echo_archives", {})
	if typeof(saved_archives) == TYPE_DICTIONARY:
		for key: Variant in saved_archives:
			var character_id := StringName(str(key))
			if EchoArchive.eligible(character_id) and EchoArchive.decode(saved_archives[key]) != null:
				echo_archives[String(character_id)] = saved_archives[key].duplicate(true)
	var saved_clues: Variant = data.get("story_clues", [])
	if typeof(saved_clues) == TYPE_ARRAY:
		for value: Variant in saved_clues:
			var clue := StringName(str(value))
			if StoryLedger.ALL.has(clue) and not story_clues.has(clue):
				story_clues.append(clue)
	var saved: Variant = data.get("unlocked", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for key: Variant in (saved as Dictionary):
			var id := StringName(str(key))
			if unlocked.has(id):
				unlocked[id] = bool((saved as Dictionary)[key])

	for def: CharacterDef in Content.characters().values():
		if best_wave >= def.unlock_wave and wins >= def.unlock_wins:
			unlocked[def.id] = true


func save() -> bool:
	last_error = ""
	var absolute := ProjectSettings.globalize_path(path)
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "story.save_failed"
		return false
	var flags := {}
	for id: StringName in unlocked:
		flags[String(id)] = bool(unlocked[id])
	file.store_string(JSON.stringify({
		"best_wave": best_wave,
		"best_endless": best_endless,
		"best_boss_rush": best_boss_rush,
		"wins": wins,
		"runs": runs,
		"daily_seed": daily_seed,
		"daily_best": daily_best,
		"daily_wins": daily_wins,
		"daily_streak": daily_streak,
		"daily_last_win_seed": daily_last_win_seed,
		"ascension": ascension,
		"unlocked": flags,
		"story_clues": story_clues,
		"echo_archives": echo_archives,
		"inherit_echo": inherit_echo,
	}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		last_error = "story.save_failed"
		return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		last_error = "story.save_failed"
		return false
	return true


func is_unlocked(id: StringName) -> bool:
	return bool(unlocked.get(id, false))


func max_ascension() -> int:
	return mini(3, wins)


func set_ascension(value: int) -> void:
	ascension = clampi(value, 0, max_ascension())
	save()


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


func record_endless(sim: Sim) -> void:
	if not sim.endless:
		return
	if sim.boss_rush:
		best_boss_rush = maxi(best_boss_rush, sim.wave)
	else:
		best_endless = maxi(best_endless, sim.wave)
	save()


static func next_calendar_day(previous: int, current: int) -> bool:
	if previous <= 0 or current <= 0:
		return false
	var before := Time.get_unix_time_from_datetime_dict({
		"year": int(previous / 10000),
		"month": int(previous / 100) % 100,
		"day": previous % 100,
	})
	var after := Time.get_unix_time_from_datetime_dict({
		"year": int(current / 10000),
		"month": int(current / 100) % 100,
		"day": current % 100,
	})
	return after - before == 86400


func record_daily(sim: Sim, seed_value: int) -> void:
	if daily_seed != seed_value:
		daily_seed = seed_value
		daily_best = 0
		daily_wins = 0
	daily_best = maxi(daily_best, sim.wave)
	if sim.phase == Sim.Phase.WON:
		daily_wins += 1
		if daily_last_win_seed != seed_value:
			daily_streak = daily_streak + 1 if next_calendar_day(daily_last_win_seed, seed_value) else 1
			daily_last_win_seed = seed_value
	save()


# Archive discoveries immediately; abandoning a run does not erase a clue.
func discover_story(ids: Array[StringName]) -> bool:
	last_error = ""
	var before := story_clues.duplicate()
	var changed := false
	for id: StringName in ids:
		if StoryLedger.ALL.has(id) and not story_clues.has(id):
			story_clues.append(id)
			changed = true
	if changed and not save():
		story_clues = before
		return false
	return changed
