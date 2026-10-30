class_name StoryLedger
extends RefCounted

# The current receipt and choices are run state; only discovered clue IDs are
# kept in Meta. Reading/dismissing a receipt never alters combat or either RNG.
const ALL: Array[StringName] = [
	&"carbon", &"repair", &"retire", &"exhausted", &"handwriting", &"duplicate",
	&"audit", &"tomorrow", &"signature",
	&"route_compliance", &"route_solidarity", &"route_profit",
	&"order_salvage", &"order_audit", &"order_repair", &"order_rescue", &"order_recruit", &"order_credit",
	&"recruited_foreman", &"recruited_collector", &"recruited_paradox",
	&"ending_released", &"ending_collective", &"ending_takeover",
	&"worker_saved", &"machine_repaired", &"witness_used", &"companion_departed", &"worker_aid",
]
const WAVES := {2: &"carbon", 4: &"handwriting", 6: &"duplicate", 8: &"audit", 10: &"tomorrow"}


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
	sync_expedition(sim)


static func sync_expedition(sim: Sim) -> void:
	if sim == null:
		return
	var route := StringName(str(sim.expedition.get("route", "")))
	if route in [&"compliance", &"solidarity", &"profit"]:
		_discover(sim, StringName("route_%s" % route))
	for order: Variant in sim.expedition.get("completed_orders", []):
		var id := StringName("order_%s" % str(order))
		if ALL.has(id):
			_discover(sim, id)
	for boss: Variant in sim.expedition.get("recruited_bosses", []):
		var id := StringName("recruited_%s" % str(boss))
		if ALL.has(id):
			_discover(sim, id)
	var ending := StringName("ending_%s" % str(sim.expedition.get("ending", "")))
	if ALL.has(ending):
		_discover(sim, ending)


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


static func on_world_event(sim: Sim, kind: StringName) -> void:
	if kind in [&"worker_saved", &"machine_repaired", &"witness_used", &"companion_departed", &"worker_aid"]:
		_discover(sim, kind)
