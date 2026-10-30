class_name BureauConfession
extends RefCounted

const CHOICES: Array[StringName] = [&"truth", &"polish"]
const ROW_KEYS := ["act", "choice", "wave", "committed", "state", "pos", "uid", "amount"]
const TERMINAL_ID := &"bureau_inspection"
const TERMINAL_KIND := &"bureau_inspection"
const TERMINAL_POS := Vector2(1670.0, 520.0)
const REPAIR := 12.0
const HEAL := 6.0
const ADVANCE := 12
const WARNING := 1.1


static func _rows(sim: Sim) -> Array:
	return sim.expedition.get("bureau", {}).get("confessions", [])


static func upcoming_act(sim: Sim) -> int:
	return 1 + int((maxi(1, sim.next_wave_number()) - 1) / 4)


static func profile(sim: Sim) -> Dictionary:
	var act := upcoming_act(sim)
	var chosen: StringName = &""
	var signed: Dictionary = {}
	for row: Dictionary in _rows(sim):
		if int(row["act"]) == act:
			chosen = row["choice"]
			signed = row
	var take := _truth_take(sim)
	var result := {"act": act, "available": sim.phase == Sim.Phase.SHOP and not sim.endless and act <= 3 and chosen == &"",
		"chosen": chosen, "truth_kind": &"echo" if take != null else &"health",
		"truth_uid": take.uid if take != null else 0,
		"truth_amount": minf(REPAIR, 100.0 - take.condition) if take != null else minf(HEAL, maxf(0.0, sim.player.max_hp() - sim.player.hp)),
		"polish_materials": ADVANCE, "inspection_pos": TERMINAL_POS,
		"signed_state": signed.get("state", &"unsigned"),
		"pending": not signed.is_empty() and not bool(signed.get("committed", true)),
		"history": _rows(sim).duplicate(true)}
	if chosen == &"truth":
		result["truth_kind"] = &"echo" if int(signed["uid"]) > 0 else &"health"
		result["truth_uid"] = int(signed["uid"])
		result["truth_amount"] = float(signed["amount"])
	return result


static func options(sim: Sim) -> Array[Dictionary]:
	var p := profile(sim)
	var reason := "" if p["available"] else ("confession.reason.used" if p["chosen"] != &"" else "confession.reason.unavailable")
	var result: Array[Dictionary] = []
	for choice: StringName in CHOICES:
		result.append({"id": choice, "name_key": "confession." + String(choice),
			"description_key": "confession." + String(choice) + ".desc", "available": p["available"], "reason_key": reason, "cost": 0})
	return result


static func pending_act(sim: Sim) -> int:
	for row: Dictionary in _rows(sim):
		if not bool(row["committed"]):
			return int(row["act"])
	return 0


static func _truth_take(sim: Sim) -> EchoTake:
	var staff := int(sim.expedition.get("world", {}).get("staff_uid", 0))
	# Shop records are not all live actors. Choose the most worn repairable body
	# directly; its UID is shown before signing, with stable UID ties.
	var target: EchoTake
	for take: EchoTake in sim.bank.takes:
		if take.uid == staff or take.condition <= 0.0 or take.condition >= 100.0:
			continue
		if target == null or take.condition < target.condition \
				or (take.condition == target.condition and take.uid < target.uid):
			target = take
	return target


# Shop owns quote, capture and Undo. There is no independent UI mutation path.
static func apply(sim: Sim, choice: StringName) -> bool:
	if not CHOICES.has(choice) or not profile(sim)["available"]:
		return false
	var p := profile(sim)
	if choice == &"truth":
		var take := _truth_take(sim)
		if take != null:
			take.condition = minf(100.0, take.condition + REPAIR)
		else:
			sim.player.hp = minf(sim.player.max_hp(), sim.player.hp + HEAL)
	else:
		sim.player.materials += ADVANCE
	_rows(sim).append({"act": int(p["act"]), "choice": choice, "wave": sim.next_wave_number(),
		"committed": false, "state": &"pending", "pos": TERMINAL_POS,
		"uid": int(p["truth_uid"]) if choice == &"truth" else 0,
		"amount": float(p["truth_amount"]) if choice == &"truth" else float(ADVANCE)})
	return true


static func begin_wave(sim: Sim) -> void:
	for row: Dictionary in _rows(sim):
		if row["committed"] or int(row["wave"]) != sim.wave:
			continue
		row["committed"] = true
		row["state"] = &"passed" if row["choice"] == &"truth" else &"active"
		StoryLedger.on_confession(sim, row["choice"])
	for item: Dictionary in append_interactions(sim):
		sim.interactables.append(item)


static func append_interactions(sim: Sim) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _rows(sim):
		if int(row["wave"]) == sim.wave and row["committed"] and row["choice"] == &"polish" and row["state"] in [&"active", &"passed"]:
			result.append({"id": TERMINAL_ID, "kind": TERMINAL_KIND, "pos": TERMINAL_POS, "range": 112.0,
				"cost": 0, "warning": 0.0, "active": 0.0, "cooldown": 0.0,
				"used": row["state"] == &"passed", "direction": Vector2.RIGHT})
	return result


static func interact(sim: Sim, item: Dictionary) -> bool:
	if sim.phase != Sim.Phase.WAVE or item.get("id", &"") != TERMINAL_ID or item.get("kind", &"") != TERMINAL_KIND \
			or not sim.interactables.has(item) or item.get("pos", Vector2.ZERO) != TERMINAL_POS \
			or sim.player.pos.distance_to(TERMINAL_POS) > 112.0 \
			or bool(item.get("used", true)) or sim.enemy_zones.size() >= EnemyBrain.MAX_ZONES:
		return false
	for row: Dictionary in _rows(sim):
		if int(row["wave"]) != sim.wave or not row["committed"] or row["state"] != &"active" or row["choice"] != &"polish":
			continue
		var zone := EnemyZone.new()
		zone.pos = TERMINAL_POS
		zone.warning = WARNING
		zone.active = 0.22
		zone.damage = 4.0 + sim.wave * 0.4
		sim.enemy_zones.append(zone)
		row["state"] = &"passed"
		item["used"] = true
		StoryLedger.on_inspection(sim)
		sim.world_event.emit({"kind": &"inspection_registered", "subject": TERMINAL_ID, "pos": TERMINAL_POS, "stage": sim.wave})
		return true
	return false


static func finish_wave(sim: Sim, _success: bool) -> void:
	for row: Dictionary in _rows(sim):
		if int(row["wave"]) == sim.wave and row["state"] == &"active":
			row["state"] = &"missed"


static func validate_rows(rows: Variant, sim: Sim = null) -> bool:
	if typeof(rows) != TYPE_ARRAY or rows.size() > 3:
		return false
	var seen := {}
	for value: Variant in rows:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var row: Dictionary = value
		if row.size() != ROW_KEYS.size():
			return false
		for key: Variant in row:
			if typeof(key) != TYPE_STRING or not ROW_KEYS.has(key):
				return false
		if typeof(row["act"]) != TYPE_INT or int(row["act"]) < 1 or int(row["act"]) > 3 or seen.has(row["act"]) \
				or typeof(row["wave"]) != TYPE_INT or int(row["wave"]) < 1 or int(row["wave"]) > WaveDirector.FINAL_WAVE \
				or int(row["act"]) != 1 + int((int(row["wave"]) - 1) / 4) \
				or typeof(row["choice"]) != TYPE_STRING_NAME or not CHOICES.has(row["choice"]) \
				or typeof(row["committed"]) != TYPE_BOOL or typeof(row["state"]) != TYPE_STRING_NAME \
				or row["state"] not in [&"pending", &"active", &"passed", &"missed"] \
				or typeof(row["pos"]) != TYPE_VECTOR2 or row["pos"] != TERMINAL_POS \
				or typeof(row["uid"]) != TYPE_INT or int(row["uid"]) < 0 \
				or typeof(row["amount"]) != TYPE_FLOAT or not is_finite(float(row["amount"])) \
				or float(row["amount"]) < 0.0 or float(row["amount"]) > REPAIR:
			return false
		if bool(row["committed"]) == (row["state"] == &"pending") \
				or (row["choice"] == &"truth" and row["state"] not in [&"pending", &"passed"]):
			return false
		if (row["choice"] == &"polish" and (int(row["uid"]) != 0 or not is_equal_approx(float(row["amount"]), float(ADVANCE)))) \
				or (row["choice"] == &"truth" and int(row["uid"]) == 0 and float(row["amount"]) > HEAL):
			return false
		if sim != null:
			if int(row["uid"]) >= sim.bank.next_uid():
				return false
			if not row["committed"] and (sim.phase != Sim.Phase.SHOP or int(row["wave"]) != sim.next_wave_number()):
				return false
			if row["committed"] and int(row["wave"]) > sim.wave:
				return false
			if row["state"] == &"active" and (sim.phase != Sim.Phase.WAVE or int(row["wave"]) != sim.wave):
				return false
		seen[row["act"]] = true
	if sim != null:
		var expected := append_interactions(sim)
		if not validate_plain(rows, sim.interactables):
			return false
		for item: Dictionary in sim.interactables:
			if item["id"] != TERMINAL_ID:
				continue
			var current := false
			for row: Dictionary in rows:
				current = current or (int(row["wave"]) == sim.wave and row["committed"] and row["choice"] == &"polish")
			if not current:
				return false
		for terminal: Dictionary in expected:
			var found := false
			for item: Dictionary in sim.interactables:
				found = found or (item["id"] == TERMINAL_ID and item["pos"] == TERMINAL_POS and item["used"] == terminal["used"])
			if not found:
				return false
	return true


static func validate_plain(rows: Variant, items: Array) -> bool:
	if not validate_rows(rows):
		return false
	var terminals := 0
	for value: Variant in items:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = value
		if item.get("id", &"") != TERMINAL_ID and item.get("kind", &"") != TERMINAL_KIND:
			continue
		terminals += 1
		if terminals > 1 or item.get("id", &"") != TERMINAL_ID or item.get("kind", &"") != TERMINAL_KIND \
				or item.get("pos", Vector2.ZERO) != TERMINAL_POS:
			return false
		var matching := false
		for row: Dictionary in rows:
			if row["choice"] == &"polish" and row["committed"] and row["state"] in [&"active", &"passed", &"missed"] \
					and bool(item.get("used", false)) == (row["state"] == &"passed"):
				matching = true
		if not matching:
			return false
	return true


static func decorate_interaction(sim: Sim, item: Dictionary) -> void:
	if item.get("kind", &"") != TERMINAL_KIND:
		return
	item["name_key"] = "interaction.bureau_inspection"
	item["description_key"] = "interaction.bureau_inspection.desc"
	item["available"] = bool(item.get("available", false)) and not bool(item.get("used", true)) and sim.enemy_zones.size() < EnemyBrain.MAX_ZONES
