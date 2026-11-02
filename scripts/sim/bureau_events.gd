class_name BureauEvents
extends RefCounted

const DELIVERY_STAGES := [2, 6, 10]
const PICKUP_ID := &"bureau_dispatch_pickup"
const SWITCH_ID := &"bureau_dispatch_switch"
const INBOX_ID := &"bureau_dispatch_inbox"
const PICKUP := Vector2(420.0, 1020.0)
const SWITCH := Vector2(450.0, 1160.0)
const STAMP := Vector2(625.0, 1020.0)
const INBOX := Vector2(815.0, 1020.0)
const RADIUS := 86.0
const CYCLE := 4.0
const WARNING := 1.1
const IMPACT := 0.24
const SAFE_INTERVAL := 4.0
const REWARD := 8
const MAX_RETIRED := 6
const MAX_WORK := 16
const DELIVERY_KEYS := ["stage", "state", "pickup", "switch", "stamp", "inbox", "clock", "safe_left", "strikes", "rewarded"]
const RETIRED_KEYS := ["uid", "wave", "recorded_wave", "weapon_id", "reason", "work", "condition", "merged"]
const TARGETS := {PICKUP_ID: &"bureau_pickup", SWITCH_ID: &"bureau_switch", INBOX_ID: &"bureau_inbox"}


static func initialize(sim: Sim) -> void:
	sim.expedition["bureau"] = {"delivery": {}, "confessions": [], "retired": [], "work": []}


static func forecast(stage: int, endless: bool = false) -> bool:
	return not endless and DELIVERY_STAGES.has(stage)


static func begin_wave(sim: Sim) -> void:
	var bureau: Dictionary = sim.expedition["bureau"]
	bureau["delivery"] = {}
	var retained: Array = []
	for row: Dictionary in bureau["work"]:
		if sim.bank.find_uid(int(row["uid"])) != null:
			retained.append(row)
	bureau["work"] = retained
	if forecast(sim.wave, sim.endless):
		bureau["delivery"] = {"stage": sim.wave, "state": &"waiting", "pickup": PICKUP,
			"switch": SWITCH, "stamp": STAMP, "inbox": INBOX, "clock": 0.0,
			"safe_left": 0.0, "strikes": 0, "rewarded": false}
		for id: StringName in TARGETS:
			sim.interactables.append(_target(id))
		Expedition._event(sim, &"dispatch_waiting", PICKUP_ID, PICKUP)
	BureauConfession.begin_wave(sim)


static func _target(id: StringName) -> Dictionary:
	var pos := PICKUP if id == PICKUP_ID else (SWITCH if id == SWITCH_ID else INBOX)
	return {"id": id, "kind": TARGETS[id], "pos": pos, "range": Expedition.INTERACTION_RANGE,
		"cost": 0, "warning": 0.0, "active": 0.0, "cooldown": 0.0,
		"used": false, "direction": Vector2.RIGHT}


static func decorate_interaction(sim: Sim, item: Dictionary) -> void:
	if item.get("kind", &"") == &"bureau_inspection":
		BureauConfession.decorate_interaction(sim, item)
		return
	if not TARGETS.has(item.get("id", &"")):
		return
	var delivery: Dictionary = sim.expedition["bureau"]["delivery"]
	var state: StringName = delivery.get("state", &"")
	if item["id"] == PICKUP_ID:
		item["available"] = item["available"] and state == &"waiting"
	elif item["id"] == INBOX_ID:
		item["available"] = item["available"] and state == &"carrying"
	else:
		item["available"] = item["available"] and state in [&"waiting", &"carrying"]
	item["reason_key"] = "bureau.delivery.need_document" if item["id"] == INBOX_ID and state == &"waiting" else ""


static func interact(sim: Sim, item: Dictionary) -> bool:
	if sim.phase != Sim.Phase.WAVE:
		return false
	var canonical: Dictionary = {}
	for site in sim.interactables:
		if site["id"] == item.get("id", &""):
			canonical = site
			break
	if canonical.is_empty() or canonical["used"] or float(canonical["cooldown"]) > 0.0 \
			or sim.player.pos.distance_to(canonical["pos"]) > float(canonical["range"]):
		return false
	item = canonical
	if item["kind"] == &"bureau_inspection":
		return BureauConfession.interact(sim, item)
	var delivery: Dictionary = sim.expedition["bureau"]["delivery"]
	if delivery.is_empty() or delivery["state"] not in [&"waiting", &"carrying"]:
		return false
	match item["id"]:
		PICKUP_ID:
			if delivery["state"] != &"waiting":
				return false
			delivery["state"] = &"carrying"
			item["used"] = true
			sim.world_event.emit({"kind": &"dispatch_carried", "subject": PICKUP_ID, "stage": sim.wave, "pos": PICKUP})
		INBOX_ID:
			if delivery["state"] != &"carrying" or delivery["rewarded"]:
				return false
			delivery["state"] = &"delivered"
			delivery["rewarded"] = true
			sim.player.materials += REWARD
			for site in sim.interactables:
				if TARGETS.has(site["id"]):
					site["used"] = true
			Expedition._event(sim, &"dispatch_delivered", INBOX_ID, INBOX)
		SWITCH_ID:
			if not _switch(sim):
				return false
			sim.recorder.record_work(&"press", SWITCH_ID, sim.player.pos)
		_: return false
	return true


static func _switch(sim: Sim) -> bool:
	var delivery: Dictionary = sim.expedition["bureau"]["delivery"]
	if delivery.is_empty() or delivery["state"] not in [&"waiting", &"carrying"] or float(delivery["safe_left"]) > 0.0:
		return false
	delivery["safe_left"] = SAFE_INTERVAL
	delivery["clock"] = 0.0
	for item in sim.interactables:
		if item["id"] == SWITCH_ID:
			item["cooldown"] = SAFE_INTERVAL
	# Repeated apparatus feedback is transient. Persistent history is reserved for
	# decisions and outcomes so a busy stamp cannot erase a colleague's departure.
	sim.world_event.emit({"kind": &"dispatch_safe", "subject": SWITCH_ID, "stage": sim.wave, "pos": SWITCH})
	return true


static func replay_status(sim: Sim, actor: EchoActor) -> Dictionary:
	var delivery: Dictionary = sim.expedition.get("bureau", {}).get("delivery", {})
	var reason := &"ready"
	if actor == null or delivery.is_empty() or delivery.get("state", &"") not in [&"waiting", &"carrying"]:
		reason = &"unavailable"
	elif actor.pos.distance_to(SWITCH) > Expedition.INTERACTION_RANGE:
		reason = &"distant"
	elif float(delivery["safe_left"]) > 0.0:
		reason = &"unavailable"
	return {"target_pos": SWITCH, "reason": reason}


static func replay_switch(sim: Sim, actor: EchoActor) -> bool:
	return sim.phase == Sim.Phase.WAVE and replay_status(sim, actor)["reason"] == &"ready" and _switch(sim)


static func step(sim: Sim, delta: float) -> void:
	if sim.phase != Sim.Phase.WAVE or Expedition.is_negotiating(sim) or not is_finite(delta) or delta <= 0.0:
		return
	var d: Dictionary = sim.expedition["bureau"]["delivery"]
	if d.is_empty() or d["state"] not in [&"waiting", &"carrying"]:
		return
	var safe := float(d["safe_left"])
	d["safe_left"] = maxf(0.0, safe - delta)
	for item in sim.interactables:
		if item["id"] == SWITCH_ID:
			item["cooldown"] = d["safe_left"]
	var elapsed := maxf(0.0, delta - safe)
	if elapsed <= 0.0:
		return
	var previous := float(d["clock"])
	var total := previous + elapsed
	var impacts := int(floor((total - WARNING) / CYCLE)) - int(floor((previous - WARNING) / CYCLE))
	d["clock"] = fposmod(total, CYCLE)
	if impacts > 0:
		# Consume skipped periods without queuing a burst of hits after a long frame.
		d["strikes"] = mini(1000000, int(d["strikes"]) + mini(impacts, 1000000))
		_impact(sim)


static func _impact(sim: Sim) -> void:
	sim.world_event.emit({"kind": &"dispatch_impact", "subject": SWITCH_ID, "stage": sim.wave, "pos": STAMP})
	for unit in sim.support_units.duplicate():
		if (unit["pos"] as Vector2).distance_squared_to(STAMP) <= pow(RADIUS + SupportSystem.UNIT_RADIUS, 2.0):
			SupportSystem.damage(sim, int(unit["uid"]), 20.0)
	for enemy: EnemyState in sim.enemies.duplicate():
		if not enemy.dead and enemy.pos.distance_squared_to(STAMP) <= pow(RADIUS + enemy.radius, 2.0):
			sim.damage_enemy(enemy, 30.0 + sim.wave * 3.0, Vector2.ZERO, false, -1, Vector2.ZERO, &"", &"bureau_stamp")
	if sim.player.iframes <= 0.0 and sim.player.pos.distance_squared_to(STAMP) <= pow(RADIUS + PlayerState.RADIUS, 2.0):
		sim._hurt_player(8.0, &"machine", &"bureau_stamp", sim.player.pos, Vector2.ZERO)


static func finish_wave(sim: Sim, success: bool) -> void:
	if not sim.expedition.has("bureau"):
		return
	BureauConfession.finish_wave(sim, success)
	var d: Dictionary = sim.expedition["bureau"]["delivery"]
	if not d.is_empty() and d["state"] in [&"waiting", &"carrying"]:
		d["state"] = &"missed"
		for item in sim.interactables:
			if TARGETS.has(item["id"]):
				item["used"] = true
		Expedition._event(sim, &"dispatch_missed", INBOX_ID, INBOX)


static func note_work(sim: Sim, info: Dictionary) -> void:
	if not info.get("success", false) or not sim.expedition.has("bureau"):
		return
	var uid := int(info.get("uid", 0))
	if sim.bank.find_uid(uid) == null:
		return
	var work: Array = sim.expedition["bureau"]["work"]
	for row in work:
		if row["uid"] == uid:
			row["count"] = mini(1000000, int(row["count"]) + 1)
			return
	if work.size() < MAX_WORK:
		work.append({"uid": uid, "count": 1})


static func record_retirement(sim: Sim, info: EchoRetirementInfo) -> void:
	if info == null or not sim.expedition.has("bureau"):
		return
	var take := sim.bank.find_uid(info.uid)
	if take == null or take.weapons.is_empty():
		return
	var bureau: Dictionary = sim.expedition["bureau"]
	var count := 0
	for row in bureau["work"].duplicate():
		if row["uid"] == info.uid:
			count = int(row["count"])
			bureau["work"].erase(row)
	var profile := EchoSystem.skill_profile(take, sim)
	bureau["retired"].append({"uid": take.uid, "wave": sim.wave, "recorded_wave": take.wave,
		"weapon_id": StringName(profile.get("weapon_id", take.weapons[0].id)), "reason": info.reason,
		"work": count, "condition": info.condition, "merged": take.merged})
	while bureau["retired"].size() > MAX_RETIRED:
		bureau["retired"].pop_front()


static func profile(sim: Sim) -> Dictionary:
	var bureau: Dictionary = sim.expedition.get("bureau", {}) if sim != null else {}
	var d: Dictionary = bureau.get("delivery", {}).duplicate(true)
	if not d.is_empty():
		var live: bool = sim.phase == Sim.Phase.WAVE and d["state"] in [&"waiting", &"carrying"]
		var clock := float(d["clock"])
		var safe := float(d["safe_left"]) > 0.0
		d.merge({"visible": true, "warning": live and not safe and clock < WARNING,
			"active": live and not safe and clock >= WARNING and clock < WARNING + IMPACT,
			"progress": clampf(clock / WARNING, 0.0, 1.0), "radius": RADIUS,
			"safe": safe, "name_key": "bureau.delivery." + String(d["state"])})
	return {"delivery": d, "confessions": bureau.get("confessions", []).duplicate(true),
		"retired": bureau.get("retired", []).duplicate(true), "work": bureau.get("work", []).duplicate(true)}


static func validate_plain(bureau: Variant, items: Array) -> bool:
	if typeof(bureau) != TYPE_DICTIONARY or not Expedition._keys_exact(bureau, ["delivery", "confessions", "retired", "work"]):
		return false
	for item in items:
		if typeof(item) != TYPE_DICTIONARY or not item.has("id") or not item.has("kind") or not item.has("pos") or not item.has("used"):
			return false
	if typeof(bureau["delivery"]) != TYPE_DICTIONARY or not BureauConfession.validate_plain(bureau["confessions"], items):
		return false
	var d: Dictionary = bureau["delivery"]
	if not d.is_empty():
		if not Expedition._keys_exact(d, DELIVERY_KEYS) or not Expedition._integer_between(d["stage"], 1, 12) or not DELIVERY_STAGES.has(int(d["stage"])) \
				or not Expedition._name_in(d["state"], [&"waiting", &"carrying", &"delivered", &"missed"]) \
				or not Expedition._number_between(d["clock"], 0.0, CYCLE) or float(d["clock"]) >= CYCLE \
				or not Expedition._number_between(d["safe_left"], 0.0, SAFE_INTERVAL) or not Expedition._integer_between(d["strikes"], 0, 1000000) \
				or typeof(d["rewarded"]) != TYPE_BOOL or d["rewarded"] != (d["state"] == &"delivered"):
			return false
		for pair in [["pickup", PICKUP], ["switch", SWITCH], ["stamp", STAMP], ["inbox", INBOX]]:
			if typeof(d[pair[0]]) != TYPE_VECTOR2 or d[pair[0]] != pair[1] or not WorldArena.body_clear(d[pair[0]], PlayerState.RADIUS):
				return false
	var found: Dictionary = {}
	for item in items:
		if not TARGETS.has(item["id"]):
			if String(item["kind"]).begins_with("bureau_") and item["kind"] != &"bureau_inspection":
				return false
			continue
		if d.is_empty() or found.has(item["id"]):
			return false
		var canonical := _target(item["id"])
		if item["kind"] != canonical["kind"] or item["pos"] != canonical["pos"]:
			return false
		for key in ["range", "cost", "warning", "active", "direction"]:
			if item[key] != canonical[key]:
				return false
		if item["cooldown"] != (d["safe_left"] if item["id"] == SWITCH_ID else 0.0):
			return false
		var used: bool = d["state"] in [&"delivered", &"missed"] or (item["id"] == PICKUP_ID and d["state"] == &"carrying")
		if item["used"] != used:
			return false
		found[item["id"]] = true
	if (not d.is_empty() and found.size() != TARGETS.size()):
		return false
	if typeof(bureau["retired"]) != TYPE_ARRAY or bureau["retired"].size() > MAX_RETIRED \
			or typeof(bureau["work"]) != TYPE_ARRAY or bureau["work"].size() > MAX_WORK:
		return false
	var ids: Dictionary = {}
	for row in bureau["retired"]:
		if typeof(row) != TYPE_DICTIONARY or not Expedition._keys_exact(row, RETIRED_KEYS) \
				or not Expedition._integer_between(row["uid"], 1, 2147483647) or ids.has(row["uid"]) \
				or not Expedition._integer_between(row["wave"], 1, 1000000) or not Expedition._integer_between(row["recorded_wave"], 0, 100000) \
				or typeof(row["weapon_id"]) != TYPE_STRING_NAME or Content.weapon(row["weapon_id"]) == null \
				or not Expedition._name_in(row["reason"], [EchoRetirementInfo.ACTIVE, EchoRetirementInfo.EXHAUSTED, EchoRetirementInfo.ABSORBED]) \
				or not Expedition._integer_between(row["work"], 0, 1000000) or not Expedition._number_between(row["condition"], 0.0, 100.0) \
				or typeof(row["merged"]) != TYPE_BOOL or (row["reason"] == EchoRetirementInfo.EXHAUSTED and float(row["condition"]) != 0.0):
			return false
		ids[row["uid"]] = true
	var retired_ids := ids.duplicate()
	ids.clear()
	for row in bureau["work"]:
		if typeof(row) != TYPE_DICTIONARY or not Expedition._keys_exact(row, ["uid", "count"]) \
				or not Expedition._integer_between(row["uid"], 1, 2147483647) or ids.has(row["uid"]) or retired_ids.has(row["uid"]) \
				or not Expedition._integer_between(row["count"], 1, 1000000):
			return false
		ids[row["uid"]] = true
	return true


static func validate_state(sim: Sim) -> bool:
	if not validate_plain(sim.expedition.get("bureau"), sim.interactables) or not BureauConfession.validate_rows(sim.expedition["bureau"]["confessions"], sim):
		return false
	var bureau: Dictionary = sim.expedition["bureau"]
	var d: Dictionary = bureau["delivery"]
	if not d.is_empty() and (int(d["stage"]) != sim.wave or sim.endless \
			or (d["state"] in [&"waiting", &"carrying"] and sim.phase != Sim.Phase.WAVE)):
		return false
	for row in bureau["retired"]:
		if int(row["wave"]) > sim.wave or int(row["uid"]) >= sim.bank.next_uid() or sim.bank.find_uid(int(row["uid"])) != null:
			return false
		for actor in sim.echoes:
			if actor.take.uid == int(row["uid"]):
				return false
	for row in bureau["work"]:
		if int(row["uid"]) >= sim.bank.next_uid():
			return false
	return true
