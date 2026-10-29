class_name Expedition
extends RefCounted

const ORDER_IDS: Array[StringName] = [&"salvage", &"audit", &"repair", &"rescue", &"recruit", &"credit"]
const INTERACTION_RANGE := 112.0
const NEGOTIATION_TIME := 8.0
const MAX_DEBT := 200
const MAX_HISTORY := 48
const ORDER_TARGETS := {&"salvage": 3, &"audit": 2, &"repair": 1, &"rescue": 1, &"recruit": 1, &"credit": 8}
const BOSS_IDS: Array[StringName] = [&"foreman", &"collector", &"paradox"]
const STATE_KEYS := ["route", "ending", "debt", "credit_taken", "completed_orders", "failed_orders",
	"recruited_boss", "recruited_bosses", "rescued", "repairs", "audits", "solidarity", "profit",
	"mission", "negotiation", "cash_issued", "tail_clock", "ending_outcome"]


static func initialize(sim: Sim) -> void:
	sim.expedition = {"route": &"compliance", "ending": &"", "debt": 0, "credit_taken": 0,
		"completed_orders": [], "failed_orders": [], "recruited_boss": &"", "recruited_bosses": [],
		"rescued": 0, "repairs": 0, "audits": 0, "solidarity": 0, "profit": 0,
		"mission": {}, "negotiation": {}, "cash_issued": 0, "tail_clock": 1.5, "ending_outcome": {}}


static func ensure(sim: Sim) -> void:
	if sim.expedition.is_empty():
		initialize(sim)


static func offer_ids(sim: Sim) -> Array[StringName]:
	var eligible := ORDER_IDS.duplicate()
	if int(sim.expedition.get("debt", 0)) > 0:
		eligible.erase(&"credit")
	return eligible


static func boss_id(sim: Sim) -> StringName:
	var act := posmod(int(maxi(0, sim.wave - 1) / 4), 3)
	return BOSS_IDS[act]


static func on_order_purchased(sim: Sim, contract: AnomalyContract) -> void:
	ensure(sim)
	if contract == null or not ORDER_IDS.has(contract.kind):
		return
	var target := int(ORDER_TARGETS[contract.kind])
	contract.target = target
	sim.expedition["mission"] = {"kind": contract.kind, "target": target, "progress": 0,
		"state": &"pending", "wave": sim.next_wave_number(), "protected_hp": 0.0}
	if contract.kind == &"credit":
		sim.player.materials += 30
		sim.expedition["credit_taken"] = int(sim.expedition["credit_taken"]) + 1
		sim.expedition["debt"] = mini(MAX_DEBT, int(sim.expedition["debt"]) + 40)
		sim.expedition["profit"] = int(sim.expedition["profit"]) + 1


static func begin_wave(sim: Sim) -> void:
	ensure(sim)
	sim.expedition["cash_issued"] = 0
	sim.expedition["tail_clock"] = 1.2
	sim.expedition["negotiation"] = {}
	sim.interactables = WorldArena.machine_sites()
	var mission: Dictionary = sim.expedition["mission"]
	if mission.is_empty() or mission.get("state") != &"pending":
		sim.expedition["mission"] = {}
		return
	mission["state"] = &"active"
	mission["wave"] = sim.wave
	match mission["kind"]:
		&"salvage":
			for index in 3:
				_add_target(sim, &"part", index, Vector2(210.0 + index * 85.0, -150.0 + index * 140.0))
			_add_opponents(sim, &"runner", 3)
		&"audit":
			_add_target(sim, &"terminal", 0, Vector2(-260.0, -160.0))
			_add_target(sim, &"terminal", 1, Vector2(300.0, 180.0))
			_add_opponents(sim, &"warden", 2)
		&"repair":
			_add_target(sim, &"repair", 0, Vector2(-240.0, 180.0))
			for item in sim.interactables:
				if item["kind"] == &"press":
					item["cooldown"] = 2.0
		&"rescue":
			_add_target(sim, &"rescue", 0, Vector2(310.0, -160.0))
			mission["protected_hp"] = 45.0
			_add_opponents(sim, &"bomber", 3)
		&"recruit":
			if not sim.is_boss_wave():
				var event := SpawnEvent.new()
				event.def = Content.enemy(boss_id(sim))
				event.time = sim.wave_duration * 0.45
				sim._plan.append(event)
				sim._plan.sort_custom(func(a: SpawnEvent, b: SpawnEvent) -> bool: return a.time < b.time)
		&"credit":
			_add_opponents(sim, &"silencer", 3)


static func _add_opponents(sim: Sim, id: StringName, count: int) -> void:
	for index in count:
		var event := SpawnEvent.new()
		event.def = Content.enemy(id)
		event.time = 1.0 + float(index) * 2.0
		sim._plan.append(event)
	sim._plan.sort_custom(func(a: SpawnEvent, b: SpawnEvent) -> bool: return a.time < b.time)


static func _add_target(sim: Sim, kind: StringName, index: int, offset: Vector2) -> void:
	var point := WorldArena.move_body(sim.player.pos, offset, 24.0)
	sim.interactables.append({"id": StringName("mission_%d" % index), "kind": kind, "pos": point,
		"range": INTERACTION_RANGE, "cost": 0, "warning": 0.0, "active": 0.0, "cooldown": 0.0,
		"used": false, "direction": Vector2.RIGHT})


static func order_complete(sim: Sim, contract: AnomalyContract) -> bool:
	if contract == null:
		return false
	var mission: Dictionary = sim.expedition.get("mission", {})
	return mission.get("kind", &"") == contract.kind and mission.get("state", &"") != &"failed" \
		and int(mission.get("progress", 0)) >= int(mission.get("target", 1))


static func status(sim: Sim) -> Dictionary:
	var state := sim.expedition
	var mission: Dictionary = state.get("mission", {})
	var ending: StringName = state.get("ending", &"")
	return {"act": mini(3, 1 + int(maxi(0, sim.wave - 1) / 4)), "stage": sim.wave,
		"route": "expedition.route." + String(state.get("route", &"compliance")),
		"objective": "order." + String(mission.get("kind", &"survive")) + ".objective",
		"progress": int(mission.get("progress", 0)), "target": int(mission.get("target", 0)),
		"debt": int(state.get("debt", 0)), "ending": "expedition.ending." + String(ending) if ending != &"" else "",
		"boss_kind": boss_id(sim) if sim.is_boss_wave() else &"", "interaction": interaction(sim),
		"outcome_key": "expedition.outcome." + String(ending) if not state.get("ending_outcome", {}).is_empty() else "",
		"outcome_values": state.get("ending_outcome", {}).duplicate(true)}


static func interaction(sim: Sim) -> Dictionary:
	var closest: Dictionary = {}
	var distance := INF
	for item in sim.interactables:
		if bool(item.get("used", false)):
			continue
		var d := sim.player.pos.distance_to(item["pos"])
		if d <= float(item.get("range", INTERACTION_RANGE)) and d < distance:
			closest = item.duplicate(true)
			distance = d
	if closest.is_empty():
		return closest
	closest["available"] = float(closest.get("cooldown", 0.0)) <= 0.0 and sim.player.materials >= int(closest.get("cost", 0))
	closest["name_key"] = "interaction." + String(closest["kind"])
	closest["description_key"] = "interaction." + String(closest["kind"]) + ".desc"
	return closest


static func interact(sim: Sim) -> bool:
	if sim.phase != Sim.Phase.WAVE:
		return false
	var choice := interaction(sim)
	if choice.is_empty() or not bool(choice["available"]):
		return false
	var item: Dictionary = {}
	for candidate in sim.interactables:
		if candidate["id"] == choice["id"]:
			item = candidate
			break
	var mission: Dictionary = sim.expedition["mission"]
	match item["kind"]:
		&"press":
			if float(item["warning"]) > 0.0:
				return false
			item["warning"] = 1.1
			item["cooldown"] = 10.0
		&"conveyor":
			item["direction"] = -(item["direction"] as Vector2)
			item["active"] = 4.0
			item["cooldown"] = 6.0
		&"recycler":
			sim.player.materials -= int(item["cost"])
			sim.character_energy = minf(100.0, sim.character_energy + 30.0)
			sim.player.hp = minf(sim.player.max_hp(), sim.player.hp + 6.0)
			item["cooldown"] = 12.0
		&"part", &"terminal", &"repair", &"rescue":
			if mission.is_empty() or mission.get("state") != &"active":
				return false
			item["used"] = true
			mission["progress"] = mini(int(mission["target"]), int(mission["progress"]) + 1)
			if item["kind"] == &"terminal":
				var zone := EnemyZone.new()
				zone.pos = item["pos"]
				zone.damage = 4.0 + sim.wave * 0.4
				if sim.enemy_zones.size() < EnemyBrain.MAX_ZONES:
					sim.enemy_zones.append(zone)
			elif item["kind"] == &"repair":
				for machine in sim.interactables:
					if machine["kind"] == &"press":
						machine["cooldown"] = sim.wave_duration + 10.0
						machine["warning"] = 0.0
			elif item["kind"] == &"rescue":
				SupportSystem.spawn(sim, &"decoy", item["pos"])
		&"negotiate":
			var negotiation: Dictionary = sim.expedition["negotiation"]
			if negotiation.is_empty():
				return false
			var kind: StringName = negotiation["kind"]
			var previous: Array[Dictionary] = sim.support_units.duplicate(true)
			var keep: Array[Dictionary] = []
			for unit in sim.support_units:
				if not String(unit["kind"]).begins_with("recruited_"):
					keep.append(unit)
			sim.support_units = keep
			if not SupportSystem.spawn(sim, StringName("recruited_" + String(kind)), item["pos"]):
				sim.support_units = previous
				return false
			mission["progress"] = 1
			sim.expedition["recruited_boss"] = kind
			_append_history(sim.expedition["recruited_bosses"], kind)
			sim.expedition["solidarity"] = int(sim.expedition["solidarity"]) + 2
			_resolve_negotiation(sim)
		_:
			return false
	return true


static func step(sim: Sim, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	ensure(sim)
	_fulfill_ending_companion(sim)
	var negotiation: Dictionary = sim.expedition["negotiation"]
	if not negotiation.is_empty():
		negotiation["remaining"] = maxf(0.0, float(negotiation["remaining"]) - delta)
		if float(negotiation["remaining"]) <= 0.0:
			_resolve_negotiation(sim)
		return
	for item in sim.interactables:
		item["cooldown"] = maxf(0.0, float(item.get("cooldown", 0.0)) - delta)
		if item["kind"] == &"press":
			item["active"] = maxf(0.0, float(item["active"]) - delta)
			if float(item["warning"]) > 0.0:
				item["warning"] = maxf(0.0, float(item["warning"]) - delta)
				if float(item["warning"]) <= 0.0:
					_press(sim, item)
			elif float(item["cooldown"]) <= 0.0 and (sim.wave >= 3 or sim.expedition.get("mission", {}).get("kind", &"") == &"repair"):
				item["warning"] = 1.1
				item["cooldown"] = 12.0
		elif item["kind"] == &"conveyor":
			item["active"] = maxf(0.0, float(item["active"]) - delta)
			if float(item["active"]) > 0.0:
				var direction: Vector2 = item["direction"]
				if sim.player.pos.distance_to(item["pos"]) <= 105.0:
					sim.player.pos = WorldArena.move_body(sim.player.pos, direction * 115.0 * delta, PlayerState.RADIUS)
				for enemy in sim.enemies:
					if enemy.pos.distance_to(item["pos"]) <= 105.0:
						enemy.pos = WorldArena.move_body(enemy.pos, direction * 80.0 * delta, enemy.radius)
	var mission: Dictionary = sim.expedition["mission"]
	if not mission.is_empty() and mission.get("kind") == &"rescue" and int(mission["progress"]) == 0:
		for item in sim.interactables:
			if item["kind"] != &"rescue" or bool(item["used"]):
				continue
			for enemy in sim.enemies:
				if not enemy.dead and enemy.pos.distance_to(item["pos"]) < enemy.radius + 28.0:
					mission["protected_hp"] = maxf(0.0, float(mission["protected_hp"]) - enemy.damage * delta)
			if float(mission["protected_hp"]) <= 0.0:
				item["used"] = true
				mission["state"] = &"failed"
	if not mission.is_empty() and mission.get("kind") == &"credit":
		mission["progress"] = mini(int(mission["target"]), sim.wave_kills)


static func _press(sim: Sim, item: Dictionary) -> void:
	var point: Vector2 = item["pos"]
	item["active"] = 0.3
	sim.explosion.emit(point, 100.0, Color(0.72, 0.20, 0.25))
	for unit in sim.support_units.duplicate():
		if (unit["pos"] as Vector2).distance_to(point) <= 113.0:
			SupportSystem.damage(sim, int(unit["uid"]), 25.0)
	for enemy in sim.enemies.duplicate():
		if not enemy.dead and enemy.pos.distance_to(point) <= 100.0 + enemy.radius:
			sim.damage_enemy(enemy, 35.0 + sim.wave * 4.0, Vector2.ZERO, false, -1,
				Vector2.ZERO, &"", &"machine_press")
	if sim.player.pos.distance_to(point) <= 100.0 + PlayerState.RADIUS and sim.player.iframes <= 0.0:
		sim._hurt_player(8.0, &"machine", &"machine_press", sim.player.pos, Vector2.ZERO)


static func try_negotiate(sim: Sim, enemy: EnemyState) -> bool:
	var mission: Dictionary = sim.expedition.get("mission", {})
	if mission.get("kind", &"") != &"recruit" or mission.get("state", &"") != &"active" \
			or not enemy.def.is_boss or sim.boss_alive_count() > 1 or not sim.expedition["negotiation"].is_empty():
		return false
	enemy.hp = 1.0
	enemy.brain_state = &"defeated"
	sim.expedition["negotiation"] = {"uid": enemy.uid, "kind": enemy.def.id, "pos": enemy.pos,
		"remaining": NEGOTIATION_TIME}
	sim.interactables.append({"id": &"boss_negotiation", "kind": &"negotiate", "pos": enemy.pos,
		"range": 180.0, "cost": 0, "warning": 0.0, "active": NEGOTIATION_TIME,
		"cooldown": 0.0, "used": false, "direction": Vector2.RIGHT})
	for other in sim.enemies:
		if other != enemy:
			other.dead = true
	sim.pending.clear()
	sim._plan_idx = sim._plan.size()
	sim.enemy_zones.clear()
	sim.rifts.clear()
	return true


static func is_negotiating(sim: Sim) -> bool:
	return not sim.expedition.get("negotiation", {}).is_empty()


static func _resolve_negotiation(sim: Sim) -> void:
	var negotiation: Dictionary = sim.expedition["negotiation"]
	var uid := int(negotiation.get("uid", -1))
	sim.expedition["negotiation"] = {}
	for item in sim.interactables:
		if item["kind"] == &"negotiate":
			item["used"] = true
	for enemy in sim.enemies:
		if enemy.uid == uid:
			enemy.hp = 0.0
			sim._finalize_enemy_death(enemy)
			break


static func finish_wave(sim: Sim, success: bool) -> void:
	ensure(sim)
	if sim.wave >= WaveDirector.FINAL_WAVE and not sim.endless and not sim.expedition["ending_outcome"].is_empty():
		return
	var mission: Dictionary = sim.expedition["mission"]
	if not mission.is_empty() and mission.get("state") in [&"active", &"failed"]:
		var kind: StringName = mission["kind"]
		_append_history(sim.expedition["completed_orders"] if success else sim.expedition["failed_orders"], kind)
		mission["state"] = &"complete" if success else &"failed"
		if success:
			match kind:
				&"rescue":
					sim.expedition["rescued"] = int(sim.expedition["rescued"]) + 1
					sim.expedition["solidarity"] = int(sim.expedition["solidarity"]) + 2
				&"repair":
					sim.expedition["repairs"] = int(sim.expedition["repairs"]) + 1
					sim.expedition["solidarity"] = int(sim.expedition["solidarity"]) + 1
				&"audit": sim.expedition["audits"] = int(sim.expedition["audits"]) + 1
				&"credit": sim.expedition["debt"] = maxi(0, int(sim.expedition["debt"]) - 20)
				&"salvage": sim.expedition["profit"] = int(sim.expedition["profit"]) + 1
	var solidarity := int(sim.expedition["solidarity"])
	var profit := int(sim.expedition["profit"])
	sim.expedition["route"] = &"solidarity" if solidarity >= 2 else (&"profit" if profit > 0 else &"compliance")
	if int(sim.expedition["debt"]) > 0:
		var payment := mini(sim.player.materials, mini(6 + int(sim.wave / 2), int(sim.expedition["debt"])))
		sim.player.materials -= payment
		sim.expedition["debt"] = maxi(0, int(sim.expedition["debt"]) - payment)
	if sim.wave >= WaveDirector.FINAL_WAVE and not sim.endless:
		if int(sim.expedition["audits"]) >= 2:
			sim.expedition["ending"] = &"released"
			sim.expedition["route"] = &"compliance"
		else:
			sim.expedition["ending"] = &"indebted" if int(sim.expedition["debt"]) > 0 else (&"collective" if solidarity >= 3 else &"released")
		apply_ending_outcome(sim)


static func apply_ending_outcome(sim: Sim) -> bool:
	ensure(sim)
	if sim.wave < WaveDirector.FINAL_WAVE or sim.endless or not sim.expedition["ending_outcome"].is_empty():
		return false
	var ending: StringName = sim.expedition["ending"]
	if ending not in [&"released", &"collective", &"indebted"]:
		return false
	var outcome := {"kind": ending, "applied": true, "cash": 0, "forgiven_debt": 0,
		"repaired_copies": 0, "companion_uid": 0, "companion_restored": false, "companion_pending": false}
	sim.expedition["ending_outcome"] = outcome
	match ending:
		&"released":
			outcome["forgiven_debt"] = int(sim.expedition["debt"])
			sim.expedition["debt"] = 0
			for take in sim.bank.takes:
				if take.condition < 100.0:
					outcome["repaired_copies"] = int(outcome["repaired_copies"]) + 1
				take.condition = 100.0
		&"collective":
			sim.player.hp = sim.player.max_hp()
			outcome["companion_pending"] = true
			_fulfill_ending_companion(sim)
		&"indebted":
			outcome["cash"] = 24
			sim.player.materials += 24
	return true


static func _fulfill_ending_companion(sim: Sim) -> void:
	var outcome: Dictionary = sim.expedition.get("ending_outcome", {})
	if outcome.is_empty() or not bool(outcome.get("companion_pending", false)):
		return
	for unit in sim.support_units:
		if String(unit["kind"]).begins_with("recruited_") and float(unit["hp"]) > 0.0:
			unit["hp"] = float(unit["max_hp"])
			unit["life"] = 600.0
			outcome["companion_uid"] = int(unit["uid"])
			outcome["companion_restored"] = true
			outcome["companion_pending"] = false
			return
	if SupportSystem.spawn(sim, &"recruited_foreman", sim.player.pos):
		outcome["companion_uid"] = int(sim.support_units.back()["uid"])
		outcome["companion_pending"] = false


static func _append_history(history: Array, value: StringName) -> void:
	history.append(value)
	while history.size() > MAX_HISTORY:
		history.pop_front()


# Both live saves and shop undo snapshots use this exact closed plain-data schema.
static func validate_plain(state: Dictionary, items: Array) -> bool:
	if state.size() != STATE_KEYS.size():
		return false
	for key in STATE_KEYS:
		if not state.has(key):
			return false
	if not _name_in(state["route"], [&"compliance", &"solidarity", &"profit"]) \
			or not _name_in(state["ending"], [&"", &"released", &"collective", &"indebted"]) \
			or not _name_in(state["recruited_boss"], [&"", &"foreman", &"collector", &"paradox"]):
		return false
	for key in ["credit_taken", "rescued", "repairs", "audits", "solidarity", "profit"]:
		if not _integer_between(state[key], 0, 1000000):
			return false
	if not _integer_between(state["debt"], 0, MAX_DEBT) \
			or (int(state["debt"]) > 0 and int(state["credit_taken"]) == 0) \
			or not _integer_between(state["cash_issued"], 0, 300) \
			or not _number_between(state["tail_clock"], -1.2, 1.5):
		return false
	for key in ["completed_orders", "failed_orders", "recruited_bosses"]:
		if typeof(state[key]) != TYPE_ARRAY or state[key].size() > MAX_HISTORY:
			return false
		for entry in state[key]:
			if not _name_in(entry, BOSS_IDS if key == "recruited_bosses" else ORDER_IDS):
				return false
	if typeof(state["ending_outcome"]) != TYPE_DICTIONARY:
		return false
	var outcome: Dictionary = state["ending_outcome"]
	if outcome.is_empty():
		if state["ending"] != &"":
			return false
	else:
		if not _keys_exact(outcome, ["kind", "applied", "cash", "forgiven_debt", "repaired_copies", "companion_uid", "companion_restored", "companion_pending"]):
			return false
		if not _name_in(outcome["kind"], [&"released", &"collective", &"indebted"]) or outcome["kind"] != state["ending"] \
				or typeof(outcome["applied"]) != TYPE_BOOL or not outcome["applied"] \
				or not _integer_between(outcome["cash"], 0, 24) \
				or not _integer_between(outcome["forgiven_debt"], 0, MAX_DEBT) \
				or not _integer_between(outcome["repaired_copies"], 0, Sim.MAX_ECHO_CAPACITY) \
				or not _integer_between(outcome["companion_uid"], 0, 2147483647) \
				or typeof(outcome["companion_restored"]) != TYPE_BOOL or typeof(outcome["companion_pending"]) != TYPE_BOOL:
			return false
		match outcome["kind"]:
			&"released":
				if int(outcome["cash"]) != 0 or int(outcome["companion_uid"]) != 0 or outcome["companion_restored"] or outcome["companion_pending"]:
					return false
			&"collective":
				if int(outcome["cash"]) != 0 or int(outcome["forgiven_debt"]) != 0 or int(outcome["repaired_copies"]) != 0 \
						or (outcome["companion_pending"] and (int(outcome["companion_uid"]) != 0 or outcome["companion_restored"])) \
						or (not outcome["companion_pending"] and int(outcome["companion_uid"]) <= 0):
					return false
			&"indebted":
				if int(outcome["cash"]) != 24 or int(outcome["forgiven_debt"]) != 0 or int(outcome["repaired_copies"]) != 0 \
						or int(outcome["companion_uid"]) != 0 or outcome["companion_restored"] or outcome["companion_pending"]:
					return false
	if typeof(state["mission"]) != TYPE_DICTIONARY or typeof(state["negotiation"]) != TYPE_DICTIONARY:
		return false
	var mission: Dictionary = state["mission"]
	if not mission.is_empty():
		if not _keys_exact(mission, ["kind", "target", "progress", "state", "wave", "protected_hp"]):
			return false
		if not _name_in(mission["kind"], ORDER_IDS) \
				or not _name_in(mission["state"], [&"pending", &"active", &"complete", &"failed"]) \
				or not _integer_between(mission["target"], 1, 8) \
				or int(mission["target"]) != int(ORDER_TARGETS[mission["kind"]]) \
				or not _integer_between(mission["progress"], 0, int(mission["target"])) \
				or not _integer_between(mission["wave"], 1, 1000000) \
				or not _number_between(mission["protected_hp"], 0.0, 45.0):
			return false
	var negotiation: Dictionary = state["negotiation"]
	if not negotiation.is_empty():
		if not _keys_exact(negotiation, ["uid", "kind", "pos", "remaining"]):
			return false
		if not _integer_between(negotiation["uid"], 1, 2147483647) \
				or not _name_in(negotiation["kind"], BOSS_IDS) or not _world_point(negotiation["pos"]) \
				or not _number_between(negotiation["remaining"], 0.0, NEGOTIATION_TIME) or float(negotiation["remaining"]) <= 0.0 \
				or mission.is_empty() or mission["kind"] != &"recruit" or mission["state"] != &"active":
			return false
	if items.size() > 9:
		return false
	var identities: Dictionary = {}
	var kinds := [&"press", &"conveyor", &"recycler", &"part", &"terminal", &"repair", &"rescue", &"negotiate"]
	for value in items:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = value
		if not _keys_exact(item, ["id", "kind", "pos", "range", "cost", "warning", "active", "cooldown", "used", "direction"]):
			return false
		if typeof(item["id"]) != TYPE_STRING_NAME or String(item["id"]).length() > 32 \
				or item["id"] == &"" or identities.has(item["id"]) or not _name_in(item["kind"], kinds) \
				or not _world_point(item["pos"]) or typeof(item["used"]) != TYPE_BOOL \
				or typeof(item["direction"]) != TYPE_VECTOR2 or item["direction"] not in [Vector2.LEFT, Vector2.RIGHT] \
				or not _number_between(item["range"], 112.0, 180.0) \
				or not _integer_between(item["cost"], 0, 8) \
				or int(item["cost"]) != (8 if item["kind"] == &"recycler" else 0) \
				or not _number_between(item["warning"], 0.0, 1.1) \
				or not _number_between(item["active"], 0.0, NEGOTIATION_TIME) \
				or not _number_between(item["cooldown"], 0.0, 70.0):
			return false
		identities[item["id"]] = true
	return true


static func validate_state(sim: Sim) -> bool:
	if sim == null or not validate_plain(sim.expedition, sim.interactables):
		return false
	if int(sim.expedition["cash_issued"]) > WaveDirector.cash_budget(sim.wave) or (not sim.expedition["ending_outcome"].is_empty() and sim.wave < WaveDirector.FINAL_WAVE):
		return false
	var negotiation: Dictionary = sim.expedition["negotiation"]
	if negotiation.is_empty():
		for enemy in sim.enemies:
			if not enemy.dead and enemy.brain_state == &"defeated":
				return false
		return true
	if sim.phase != Sim.Phase.WAVE or sim.boss_alive_count() != 1:
		return false
	var found := false
	for enemy in sim.enemies:
		if not enemy.dead and enemy.brain_state == &"defeated" and enemy.uid != int(negotiation["uid"]):
			return false
		if enemy.uid == int(negotiation["uid"]):
			if enemy.dead or enemy.hp != 1.0 or enemy.brain_state != &"defeated" \
					or enemy.def == null or enemy.def.id != negotiation["kind"] \
					or enemy.pos != negotiation["pos"] or not sim.boss_shards.has(enemy):
				return false
			found = true
	var choice := false
	for item in sim.interactables:
		if item["kind"] == &"negotiate" and not item["used"] and item["pos"] == negotiation["pos"]:
			choice = true
	return found and choice


static func _name_in(value: Variant, allowed: Array) -> bool:
	return typeof(value) == TYPE_STRING_NAME and allowed.has(value)


static func _integer_between(value: Variant, low: int, high: int) -> bool:
	return typeof(value) == TYPE_INT and value >= low and value <= high


static func _number_between(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= low and value <= high


static func _world_point(value: Variant) -> bool:
	return typeof(value) == TYPE_VECTOR2 and value.is_finite() and WorldArena.BOUNDS.has_point(value)


static func _keys_exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true
