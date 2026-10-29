class_name StoryLedger
extends RefCounted

# The current receipt and choices are run state; only discovered clue IDs are
# kept in Meta. Reading/dismissing a receipt never alters combat or either RNG.
const ALL: Array[StringName] = [
	&"carbon", &"repair", &"retire", &"exhausted", &"handwriting", &"duplicate",
	&"audit", &"tomorrow", &"signature", &"appeal", &"consent",
]
const WAVES := {2: &"carbon", 4: &"handwriting", 7: &"duplicate", 10: &"audit", 15: &"tomorrow"}


static func on_wave(sim: Sim) -> void:
	var progress := _progress(sim)
	var wave_key := "wave_%d" % sim.wave
	if progress.get(wave_key, false):
		return
	progress[wave_key] = true
	if WAVES.has(sim.wave):
		_discover(sim, WAVES[sim.wave])
	if sim.is_boss_wave() and sim.boss != null and sim.boss_alive_count() == 0:
		_discover(sim, &"signature")
		_discover(sim, &"appeal" if int(progress.get("repairs", 0)) > int(progress.get("retirements", 0)) else &"consent")


static func on_retire(sim: Sim, info: EchoRetirementInfo) -> void:
	if info == null:
		return
	var progress := _progress(sim)
	if info.exhausted or info.reason == EchoRetirementInfo.EXHAUSTED:
		progress["exhaustions"] = int(progress.get("exhaustions", 0)) + 1
		_discover(sim, &"exhausted")
	else:
		progress["retirements"] = int(progress.get("retirements", 0)) + 1
		_discover(sim, &"retire")


static func on_repair(sim: Sim, amount: float = 1.0) -> void:
	if amount <= 0.0:
		return
	var progress := _progress(sim)
	progress["repairs"] = int(progress.get("repairs", 0)) + 1
	_discover(sim, &"repair")


static func receipt(sim: Sim) -> Dictionary:
	if sim == null:
		return {}
	var id := StringName(str(_progress(sim).get("receipt", "")))
	return entry(id)


static func dismiss(sim: Sim) -> void:
	if sim != null:
		_progress(sim)["receipt"] = ""


static func discovered(sim: Sim) -> Array[StringName]:
	var out: Array[StringName] = []
	if sim != null:
		for value: Variant in _progress(sim).get("clues", []):
			var id := StringName(str(value))
			if ALL.has(id) and not out.has(id):
				out.append(id)
	return out


static func archive(meta: Meta) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if meta != null:
		for id: StringName in ALL:
			if meta.story_clues.has(id):
				out.append(entry(id))
	return out


static func entry(id: StringName) -> Dictionary:
	if not ALL.has(id):
		return {}
	return {"id": id, "name_key": "story.%s_name" % id, "body_key": "story.%s_body" % id}


static func _progress(sim: Sim) -> Dictionary:
	return sim.story_progress


static func _discover(sim: Sim, id: StringName) -> void:
	var progress := _progress(sim)
	var clues: Array = progress.get("clues", [])
	if clues.has(String(id)) or clues.has(id):
		return
	clues.append(String(id))
	progress["clues"] = clues
	progress["receipt"] = String(id)
