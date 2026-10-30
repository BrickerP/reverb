class_name Expedition
extends RefCounted

const ORDER_IDS: Array[StringName] = [&"salvage", &"audit", &"repair", &"rescue", &"recruit", &"credit"]
const INTERACTION_RANGE := 112.0
const NEGOTIATION_TIME := 8.0
const MAX_DEBT := 200
const MAX_HISTORY := 48
const MAX_WITNESSES := 21
const MAX_COPY_WITNESSES := 8
const ORDER_TARGETS := {&"salvage": 3, &"audit": 2, &"repair": 1, &"rescue": 1, &"recruit": 1, &"credit": 8}
const BOSS_IDS: Array[StringName] = [&"foreman", &"collector", &"paradox"]
const EXIT_IDS: Array[StringName] = [&"released", &"collective", &"takeover"]
const STATE_KEYS := ["route", "ending", "debt", "credit_taken", "completed_orders", "failed_orders",
	"recruited_boss", "recruited_bosses", "rescued", "repairs", "audits", "solidarity", "profit",
	"mission", "negotiation", "cash_issued", "tail_clock", "ending_outcome", "world"]
const WORLD_KEYS := ["act_id", "machines", "workers", "roster", "witnesses", "history", "clearance", "settled_wave", "resolution_pending", "staff_uid"]
const MACHINE_KEYS := ["id", "kind", "pos", "status", "repaired_wave", "stopped", "direction"]
const WORKER_KEYS := ["id", "stage", "pos", "hp", "state", "testimony_used", "aid_used"]
const ROSTER_KEYS := ["kind", "hp", "max_hp", "life", "state", "uid"]
const OUTCOME_KEYS := ["kind", "applied", "cost", "repaired_copies", "survivors", "staff_uid"]


static func initialize(sim: Sim) -> void:
	sim.expedition = {"route": &"compliance", "ending": &"", "debt": 0, "credit_taken": 0,
		"completed_orders": [], "failed_orders": [], "recruited_boss": &"", "recruited_bosses": [],
		"rescued": 0, "repairs": 0, "audits": 0, "solidarity": 0, "profit": 0,
		"mission": {}, "negotiation": {}, "cash_issued": 0, "tail_clock": 1.5, "ending_outcome": {},
		"world": {"act_id": 1, "machines": [], "workers": [], "roster": [], "witnesses": [],
			"history": [], "clearance": false, "settled_wave": 0, "resolution_pending": false, "staff_uid": 0}}
	for site in WorldArena.machine_sites():
		sim.expedition["world"]["machines"].append({"id": site["id"], "kind": site["kind"],
			"pos": site["pos"], "status": &"operating", "repaired_wave": 0, "stopped": false, "direction": site["direction"]})


static func ensure(sim: Sim) -> void:
	if sim.expedition.is_empty():
		initialize(sim)


# Deterministic facts, independent of orders, display size and simulation RNG.
static func forecast(sim: Sim, stage: int) -> Dictionary:
	var n := maxi(1, stage)
	var act := 1 + posmod(int((n - 1) / 4), 3)
	var machine_index := posmod(n - 1, 5)
	var sites := WorldArena.machine_sites()
	var machine: Dictionary = sites[machine_index]
	var fault := true
	for saved in sim.expedition.get("world", {}).get("machines", []):
		if saved["id"] == machine["id"]:
			fault = saved["status"] != &"repaired"
	var worker_id := StringName("worker_%d" % n)
	var worker_available := n <= 12
	for worker in sim.expedition.get("world", {}).get("workers", []):
		if worker["id"] == worker_id:
			worker_available = worker["state"] == &"danger"
	var position := WorldArena.move_body(machine["pos"] + Vector2(140.0, 30.0), Vector2.ZERO, 24.0)
	return {"stage": n, "act_id": act, "act_key": "world.act.%d" % act,
		"production_state_key": "world.production.%d" % act, "machine_id": machine["id"],
		"fault": fault, "worker_id": worker_id, "worker_pos": position,
		"worker_available": worker_available, "repair_available": fault or _has_fault(sim)}


static func world_profile(sim: Sim) -> Dictionary:
	var world: Dictionary = sim.expedition.get("world", {})
	var act := int(world.get("act_id", 1))
	return {"act_id": act, "act_key": "world.act.%d" % act,
		"production_state_key": "world.production.%d" % act,
		"machines": world.get("machines", []).duplicate(true), "workers": world.get("workers", []).duplicate(true),
		"roster": world.get("roster", []).duplicate(true), "witnesses": world.get("witnesses", []).duplicate(true),
		"history": world.get("history", []).duplicate(true)}


static func _has_fault(sim: Sim) -> bool:
	for machine in sim.expedition.get("world", {}).get("machines", []):
		if machine["status"] == &"fault":
			return true
	return false


static func offer_ids(sim: Sim) -> Array[StringName]:
	var eligible := ORDER_IDS.duplicate()
	var future := forecast(sim, sim.next_wave_number())
	if not future["repair_available"]:
		eligible.erase(&"repair")
	if not future["worker_available"]:
		eligible.erase(&"rescue")
	if int(sim.expedition.get("debt", 0)) > 0:
		eligible.erase(&"credit")
	return eligible


static func boss_id(sim: Sim) -> StringName:
	return BOSS_IDS[posmod(int(maxi(0, sim.wave - 1) / 4), 3)]


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
	var world: Dictionary = sim.expedition["world"]
	var prediction := forecast(sim, sim.wave)
	if int(world["act_id"]) != int(prediction["act_id"]):
		world["act_id"] = prediction["act_id"]
		_event(sim, &"act_changed", StringName("act_%d" % int(world["act_id"])), sim.player.pos)
	var fault := _machine(sim, prediction["machine_id"])
	if prediction["fault"] and fault["status"] == &"operating":
		fault["status"] = &"fault"
		_event(sim, &"machine_fault", fault["id"], fault["pos"])
	sim.interactables = WorldArena.machine_sites()
	for item in sim.interactables.duplicate():
		var machine := _machine(sim, item["id"])
		item["direction"] = machine["direction"]
		if machine["status"] == &"repaired" or machine["stopped"]:
			item["active"] = 0.0
		elif int(world["act_id"]) == 2 and item["kind"] == &"conveyor":
			item["active"] = 8.0
		if machine["status"] == &"fault":
			item["cooldown"] = 2.0
			_add_target_at(sim, StringName("repair_" + String(machine["id"])), &"repair", machine["pos"] + Vector2(-70.0, 0.0))
	if prediction["worker_available"]:
		var worker := _worker(sim, prediction["worker_id"])
		if worker.is_empty():
			worker = {"id": prediction["worker_id"], "stage": mini(12, sim.wave), "pos": prediction["worker_pos"],
				"hp": 45.0, "state": &"danger", "testimony_used": false, "aid_used": false}
			world["workers"].append(worker)
			_event(sim, &"worker_endangered", worker["id"], worker["pos"])
		_add_target_at(sim, worker["id"], &"rescue", worker["pos"])
	var mission: Dictionary = sim.expedition["mission"]
	if mission.is_empty() or mission.get("state") != &"pending":
		sim.expedition["mission"] = {}
		return
	mission["state"] = &"active"
	mission["wave"] = sim.wave
	match mission["kind"]:
		&"salvage":
			for index in 3:
				_add_target_at(sim, StringName("mission_%d" % index), &"part", sim.player.pos + Vector2(210.0 + index * 85.0, -150.0 + index * 140.0))
			_add_opponents(sim, &"runner", 3)
		&"audit":
			_add_target_at(sim, &"mission_0", &"terminal", sim.player.pos + Vector2(-260.0, -160.0))
			_add_target_at(sim, &"mission_1", &"terminal", sim.player.pos + Vector2(300.0, 180.0))
			_add_opponents(sim, &"warden", 2)
		&"rescue": mission["protected_hp"] = 45.0
		&"recruit":
			if not sim.is_boss_wave():
				var event := SpawnEvent.new()
				event.def = Content.enemy(boss_id(sim))
				event.time = sim.wave_duration * 0.45
				sim._plan.append(event)
				sim._plan.sort_custom(func(a: SpawnEvent, b: SpawnEvent) -> bool: return a.time < b.time)
		&"credit": _add_opponents(sim, &"silencer", 3)


static func _add_opponents(sim: Sim, id: StringName, count: int) -> void:
	for index in count:
		var event := SpawnEvent.new()
		event.def = Content.enemy(id)
		event.time = 1.0 + float(index) * 2.0
		sim._plan.append(event)
	sim._plan.sort_custom(func(a: SpawnEvent, b: SpawnEvent) -> bool: return a.time < b.time)


static func _add_target_at(sim: Sim, id: StringName, kind: StringName, point: Vector2) -> void:
	sim.interactables.append({"id": id, "kind": kind, "pos": WorldArena.move_body(point, Vector2.ZERO, 24.0),
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
	return {"act": int(state.get("world", {}).get("act_id", 1)), "stage": sim.wave,
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
	var machine := _machine(sim, closest["id"])
	closest["available"] = float(closest.get("cooldown", 0.0)) <= 0.0 and sim.player.materials >= int(closest.get("cost", 0)) \
		and (machine.is_empty() or (machine["status"] != &"repaired" and not machine["stopped"]))
	closest["name_key"] = "interaction." + String(closest["kind"])
	closest["description_key"] = "interaction." + String(closest["kind"]) + ".desc"
	return closest


static func interact(sim: Sim) -> bool:
	if sim.phase != Sim.Phase.WAVE:
		return false
	var choice := interaction(sim)
	if choice.is_empty() or not bool(choice["available"]):
		return false
	for item in sim.interactables:
		if item["id"] != choice["id"]:
			continue
		var mission: Dictionary = sim.expedition["mission"]
		match item["kind"]:
			&"press", &"conveyor":
				if not _operate(sim, item):
					return false
				sim.recorder.record_work(item["kind"], item["id"], sim.player.pos)
			&"recycler":
				sim.player.materials -= int(item["cost"])
				sim.character_energy = minf(100.0, sim.character_energy + 30.0)
				sim.player.hp = minf(sim.player.max_hp(), sim.player.hp + 6.0)
				item["cooldown"] = 12.0
			&"repair":
				var machine := _machine(sim, StringName(String(item["id"]).trim_prefix("repair_")))
				if machine.is_empty() or machine["status"] != &"fault":
					return false
				machine["status"] = &"repaired"
				machine["stopped"] = true
				machine["repaired_wave"] = sim.wave
				for site in sim.interactables:
					if site["id"] == machine["id"]:
						site["warning"] = 0.0
						site["active"] = 0.0
				item["used"] = true
				sim.expedition["repairs"] += 1
				sim.expedition["solidarity"] += 1
				_progress(sim, &"repair")
				_event(sim, &"machine_repaired", machine["id"], item["pos"])
			&"rescue":
				var worker := _worker(sim, item["id"])
				if worker.is_empty() or worker["state"] != &"danger":
					return false
				worker["state"] = &"safe"
				worker["pos"] = WorldArena.safe_worker_position(int(worker["stage"]))
				sim.expedition["world"]["witnesses"].append(worker["id"])
				item["used"] = true
				sim.expedition["rescued"] += 1
				sim.expedition["solidarity"] += 2
				_progress(sim, &"rescue")
				_event(sim, &"worker_saved", worker["id"], worker["pos"])
			&"part", &"terminal":
				if mission.is_empty() or mission.get("state") != &"active":
					return false
				item["used"] = true
				_progress(sim, &"salvage" if item["kind"] == &"part" else &"audit")
				if item["kind"] == &"terminal":
					var zone := EnemyZone.new()
					zone.pos = item["pos"]
					zone.damage = 4.0 + sim.wave * 0.4
					if sim.enemy_zones.size() < EnemyBrain.MAX_ZONES:
						sim.enemy_zones.append(zone)
			&"negotiate":
				return is_negotiating(sim)
			_: return false
		return true
	return false


static func _progress(sim: Sim, kind: StringName) -> void:
	var mission: Dictionary = sim.expedition["mission"]
	if mission.get("kind", &"") == kind and mission.get("state", &"") == &"active":
		mission["progress"] = mini(int(mission["target"]), int(mission["progress"]) + 1)


static func _operate(sim: Sim, item: Dictionary) -> bool:
	var machine := _machine(sim, item["id"])
	if machine.is_empty() or machine["status"] == &"repaired" or machine["stopped"] or float(item["cooldown"]) > 0.0:
		return false
	if item["kind"] == &"press":
		if float(item["warning"]) > 0.0:
			return false
		item["warning"] = 1.1
		item["cooldown"] = 10.0
	else:
		item["direction"] = -(item["direction"] as Vector2)
		machine["direction"] = item["direction"]
		item["active"] = 4.0
		item["cooldown"] = 6.0
	machine["stopped"] = false
	_event(sim, &"machine_operated", machine["id"], machine["pos"])
	return true


static func replay_work_status(sim: Sim, actor: EchoActor, action: Dictionary) -> Dictionary:
	var machine := _machine(sim, action.get("target_id", &""))
	if machine.is_empty() or machine["kind"] != action.get("kind", &""):
		return {"target_pos": actor.pos, "reason": &"unavailable"}
	var reason: StringName = &"ready"
	if machine["status"] == &"repaired":
		reason = &"repaired"
	elif machine["stopped"]:
		reason = &"stopped"
	elif actor.pos.distance_to(machine["pos"]) > INTERACTION_RANGE:
		reason = &"distant"
	else:
		for item in sim.interactables:
			if item["id"] == machine["id"] and (float(item["cooldown"]) > 0.0 or float(item["warning"]) > 0.0):
				reason = &"unavailable"
	return {"target_pos": machine["pos"], "reason": reason}


static func replay_work(sim: Sim, actor: EchoActor, action: Dictionary) -> bool:
	if sim.phase != Sim.Phase.WAVE or action.get("kind", &"") not in [&"press", &"conveyor"] \
			or replay_work_status(sim, actor, action)["reason"] != &"ready":
		return false
	for item in sim.interactables:
		if item["id"] == action["target_id"]:
			return _operate(sim, item)
	return false


static func step(sim: Sim, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	ensure(sim)
	if is_negotiating(sim):
		return
	var world: Dictionary = sim.expedition["world"]
	for item in sim.interactables:
		item["cooldown"] = maxf(0.0, float(item.get("cooldown", 0.0)) - delta)
		var machine := _machine(sim, item["id"])
		if not machine.is_empty() and (machine["stopped"] or machine["status"] == &"repaired"):
			continue
		if item["kind"] == &"press":
			item["active"] = maxf(0.0, float(item["active"]) - delta)
			if float(item["warning"]) > 0.0:
				item["warning"] = maxf(0.0, float(item["warning"]) - delta)
				if float(item["warning"]) <= 0.0:
					_press(sim, item)
			elif float(item["cooldown"]) <= 0.0 and (machine["status"] == &"fault" or int(world["act_id"]) >= 2):
				item["warning"] = 1.1
				item["cooldown"] = 8.0 if int(world["act_id"]) == 3 else 12.0
		elif item["kind"] == &"conveyor":
			item["active"] = maxf(0.0, float(item["active"]) - delta)
			if int(world["act_id"]) == 2 and float(item["active"]) <= 0.0 and float(item["cooldown"]) <= 0.0:
				item["active"] = 4.0
				item["cooldown"] = 8.0
			if float(item["active"]) > 0.0:
				var direction: Vector2 = item["direction"]
				if sim.player.pos.distance_to(item["pos"]) <= 105.0:
					sim.player.pos = WorldArena.move_body(sim.player.pos, direction * 115.0 * delta, PlayerState.RADIUS)
				for enemy in sim.enemies:
					if enemy.pos.distance_to(item["pos"]) <= 105.0:
						enemy.pos = WorldArena.move_body(enemy.pos, direction * 80.0 * delta, enemy.radius)
	for worker in world["workers"]:
		if worker["state"] != &"danger" or int(worker["stage"]) != sim.wave:
			continue
		for enemy in sim.enemies:
			if not enemy.dead and enemy.pos.distance_to(worker["pos"]) < enemy.radius + 28.0:
				worker["hp"] = maxf(0.0, float(worker["hp"]) - enemy.damage * delta)
		var mission: Dictionary = sim.expedition["mission"]
		if mission.get("kind", &"") == &"rescue":
			mission["protected_hp"] = worker["hp"]
		if float(worker["hp"]) <= 0.0:
			worker["state"] = &"missing"
			for item in sim.interactables:
				if item["id"] == worker["id"]:
					item["used"] = true
			if mission.get("kind", &"") == &"rescue":
				mission["state"] = &"failed"
			_event(sim, &"worker_missing", worker["id"], worker["pos"])
	var mission: Dictionary = sim.expedition["mission"]
	if mission.get("kind", &"") == &"credit":
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
			sim.damage_enemy(enemy, 35.0 + sim.wave * 4.0, Vector2.ZERO, false, -1, Vector2.ZERO, &"", &"machine_press")
	if sim.player.pos.distance_to(point) <= 100.0 + PlayerState.RADIUS and sim.player.iframes <= 0.0:
		sim._hurt_player(8.0, &"machine", &"machine_press", sim.player.pos, Vector2.ZERO)


static func try_negotiate(sim: Sim, enemy: EnemyState) -> bool:
	var mission: Dictionary = sim.expedition.get("mission", {})
	if mission.get("kind", &"") != &"recruit" or mission.get("state", &"") != &"active" \
			or not enemy.def.is_boss or sim.boss_alive_count() > 1 or is_negotiating(sim):
		return false
	enemy.hp = 1.0
	enemy.brain_state = &"defeated"
	sim.expedition["negotiation"] = {"uid": enemy.uid, "kind": enemy.def.id, "pos": enemy.pos,
		"remaining": NEGOTIATION_TIME, "choice_pending": true}
	_add_target_at(sim, &"boss_negotiation", &"negotiate", enemy.pos)
	sim.interactables.back()["range"] = 180.0
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


static func _choice(id: StringName, prefix: String, available: bool, reason: String = "", cost: int = 0) -> Dictionary:
	return {"id": id, "name_key": prefix + String(id), "description_key": prefix + String(id) + ".desc",
		"available": available, "reason_key": reason, "cost": cost}


static func negotiation_options(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var negotiation: Dictionary = sim.expedition.get("negotiation", {})
	if negotiation.is_empty():
		return rows
	match negotiation["kind"]:
		&"foreman":
			var stopped := true
			for machine in sim.expedition["world"]["machines"]:
				if machine["kind"] == &"press" and not machine["stopped"]:
					stopped = false
			rows.append(_choice(&"sign", "negotiation.", stopped, "negotiation.reason.press" if not stopped else ""))
			rows.append(_choice(&"stop_press", "negotiation.", true))
		&"collector":
			var cost := int(sim.expedition["debt"])
			rows.append(_choice(&"settle_debt", "negotiation.", sim.player.materials >= cost, "choice.reason.poor" if sim.player.materials < cost else "", cost))
			var available := not _unused_witness(sim).is_empty()
			rows.append(_choice(&"witness_mediation", "negotiation.", available, "negotiation.reason.witness" if not available else ""))
		&"paradox":
			var actor := EchoSystem.selected_actor(sim)
			var witness_id := StringName("copy_%d" % actor.take.uid) if actor != null else &""
			var witnesses: Array = sim.expedition["world"]["witnesses"]
			var copy_count := 0
			for witness in witnesses:
				if String(witness).begins_with("copy_"):
					copy_count += 1
			var witness_room := copy_count < MAX_COPY_WITNESSES or witnesses.has(witness_id)
			rows.append(_choice(&"preserve_copy", "negotiation.", actor != null and witness_room,
				"negotiation.reason.copy" if actor == null else ("negotiation.reason.witness_full" if not witness_room else "")))
			rows.append(_choice(&"retire_copy", "negotiation.", EchoSystem.can_retire(sim), "negotiation.reason.copy" if not EchoSystem.can_retire(sim) else ""))
			if sim.echo_capacity() == 0:
				rows.append(_choice(&"self_witness", "negotiation.", true))
	var has_slot := sim.support_units.size() < SupportSystem.MAX_UNITS
	for unit in sim.support_units:
		has_slot = has_slot or SupportSystem.COMPANIONS.has(unit["kind"])
	var existing := _roster(sim, negotiation["kind"])
	for row in rows:
		if not has_slot:
			row["available"] = false
			row["reason_key"] = "negotiation.reason.full"
		elif not existing.is_empty() and existing["state"] != &"bench":
			row["available"] = false
			row["reason_key"] = "negotiation.reason.signed"
	rows.append(_choice(&"decline", "negotiation.", true))
	return rows


static func choose_negotiation(sim: Sim, choice: StringName) -> bool:
	if sim.phase != Sim.Phase.WAVE or not is_negotiating(sim):
		return false
	var selected: Dictionary = {}
	for row in negotiation_options(sim):
		if row["id"] == choice and row["available"]:
			selected = row
	if selected.is_empty():
		return false
	var negotiation: Dictionary = sim.expedition["negotiation"]
	if choice == &"decline":
		_event(sim, &"companion_declined", negotiation["kind"], negotiation["pos"])
		_resolve_negotiation(sim)
		return true
	match choice:
		&"stop_press":
			for machine in sim.expedition["world"]["machines"]:
				if machine["kind"] == &"press":
					machine["stopped"] = true
			for item in sim.interactables:
				if item["kind"] == &"press":
					item["warning"] = 0.0
					item["active"] = 0.0
		&"settle_debt":
			sim.player.materials -= int(selected["cost"])
			sim.expedition["debt"] = 0
		&"witness_mediation":
			var worker := _unused_witness(sim)
			worker["testimony_used"] = true
			sim.expedition["debt"] = 0
			_event(sim, &"witness_used", worker["id"], worker["pos"])
		&"preserve_copy":
			var actor := EchoSystem.selected_actor(sim)
			var id := StringName("copy_%d" % actor.take.uid)
			if not sim.expedition["world"]["witnesses"].has(id):
				sim.expedition["world"]["witnesses"].append(id)
			_event(sim, &"copy_preserved", id, actor.pos)
		&"retire_copy":
			if not sim.retire_selected_echo():
				return false
		&"self_witness":
			if not sim.expedition["world"]["witnesses"].has(&"self"):
				sim.expedition["world"]["witnesses"].append(&"self")
			_event(sim, &"copy_preserved", &"self", sim.player.pos)
	var kind: StringName = negotiation["kind"]
	var roster := _roster(sim, kind)
	if roster.is_empty():
		var profile: Dictionary = SupportSystem.PROFILES[StringName("recruited_" + String(kind))]
		roster = {"kind": kind, "hp": float(profile["hp"]), "max_hp": float(profile["hp"]),
			"life": float(profile["life"]), "state": &"bench", "uid": 0}
		sim.expedition["world"]["roster"].append(roster)
	_deploy(sim, kind)
	sim.expedition["recruited_boss"] = kind
	if not sim.expedition["recruited_bosses"].has(kind):
		sim.expedition["recruited_bosses"].append(kind)
	sim.expedition["solidarity"] += 2
	_progress(sim, &"recruit")
	_event(sim, &"companion_signed", kind, negotiation["pos"])
	_resolve_negotiation(sim)
	return true


static func _resolve_negotiation(sim: Sim) -> void:
	var uid := int(sim.expedition["negotiation"].get("uid", -1))
	sim.expedition["negotiation"] = {}
	for item in sim.interactables:
		if item["kind"] == &"negotiate":
			item["used"] = true
	for enemy in sim.enemies:
		if enemy.uid == uid:
			enemy.hp = 0.0
			sim._finalize_enemy_death(enemy)
			break


static func crew_options(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var has_slot := sim.support_units.size() < SupportSystem.MAX_UNITS
	for unit in sim.support_units:
		has_slot = has_slot or SupportSystem.COMPANIONS.has(unit["kind"])
	for roster in sim.expedition.get("world", {}).get("roster", []):
		var available: bool = has_slot and sim.phase == Sim.Phase.SHOP and roster["state"] == &"bench" and float(roster["hp"]) > 0.0 and float(roster["life"]) > 0.0
		var row := _choice(roster["kind"], "crew.", available, ("crew.reason.full" if not has_slot else "crew.reason." + String(roster["state"])) if not available else "")
		row["hp"] = roster["hp"]
		row["life"] = roster["life"]
		rows.append(row)
	for worker in sim.expedition.get("world", {}).get("workers", []):
		if worker["state"] != &"safe":
			continue
		var available: bool = sim.phase == Sim.Phase.SHOP and not worker["aid_used"] and sim.player.hp < sim.player.max_hp()
		var row := _choice(StringName("aid_" + String(worker["id"])), "crew.", available, "crew.reason.aid" if not available else "")
		row["name_key"] = "crew.worker"
		row["description_key"] = "crew.worker.desc"
		rows.append(row)
	return rows


static func assign_companion(sim: Sim, kind: StringName) -> bool:
	if sim.phase != Sim.Phase.SHOP:
		return false
	for row in crew_options(sim):
		if row["id"] != kind or not row["available"]:
			continue
		if String(kind).begins_with("aid_"):
			var worker := _worker(sim, StringName(String(kind).trim_prefix("aid_")))
			worker["aid_used"] = true
			sim.player.hp = minf(sim.player.max_hp(), sim.player.hp + 6.0)
			_event(sim, &"worker_aid", worker["id"], worker["pos"])
			return true
		return _deploy(sim, kind)
	return false


static func sync_roster(sim: Sim) -> void:
	for roster in sim.expedition.get("world", {}).get("roster", []):
		if roster["state"] != &"active":
			continue
		var found := false
		for unit in sim.support_units:
			if int(unit["uid"]) != int(roster["uid"]):
				continue
			roster["hp"] = unit["hp"]
			roster["life"] = unit["life"]
			found = true
		if not found:
			roster["hp"] = 0.0
			roster["life"] = 0.0
			roster["state"] = &"fallen"
			_event(sim, &"companion_fallen", roster["kind"], sim.player.pos)


static func _deploy(sim: Sim, kind: StringName) -> bool:
	var target := _roster(sim, kind)
	if target.is_empty() or target["state"] != &"bench" or float(target["hp"]) <= 0.0 or float(target["life"]) <= 0.0:
		return false
	sync_roster(sim)
	var keep: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	for unit in sim.support_units:
		if SupportSystem.COMPANIONS.has(unit["kind"]):
			removed.append(unit)
		else:
			keep.append(unit)
	if keep.size() >= SupportSystem.MAX_UNITS:
		return false
	sim.support_units = keep
	if not SupportSystem.spawn(sim, StringName("recruited_" + String(kind)), sim.player.pos):
		sim.support_units.append_array(removed)
		return false
	for old in sim.expedition["world"]["roster"]:
		if old["state"] == &"active":
			old["state"] = &"bench"
			_event(sim, &"companion_departed", old["kind"], sim.player.pos)
	var unit: Dictionary = sim.support_units.back()
	unit["hp"] = target["hp"]
	unit["life"] = target["life"]
	target["uid"] = unit["uid"]
	target["state"] = &"active"
	return true


static func finish_wave(sim: Sim, success: bool) -> void:
	ensure(sim)
	var world: Dictionary = sim.expedition["world"]
	if int(world["settled_wave"]) >= sim.wave:
		return
	world["settled_wave"] = sim.wave
	sync_roster(sim)
	for worker in world["workers"]:
		if worker["state"] == &"danger" and int(worker["stage"]) == sim.wave:
			worker["state"] = &"missing"
			_event(sim, &"worker_missing", worker["id"], worker["pos"])
	var mission: Dictionary = sim.expedition["mission"]
	if not mission.is_empty() and mission.get("state") in [&"active", &"failed"]:
		var kind: StringName = mission["kind"]
		var completed: bool = success and mission["state"] != &"failed" and int(mission["progress"]) >= int(mission["target"])
		_append_history(sim.expedition["completed_orders"] if completed else sim.expedition["failed_orders"], kind)
		mission["state"] = &"complete" if completed else &"failed"
		if completed:
			match kind:
				&"audit":
					sim.expedition["audits"] += 1
					if int(sim.expedition["audits"]) >= 2 and not world["clearance"]:
						world["clearance"] = true
						sim.expedition["debt"] = 0
						_event(sim, &"clearance_granted", &"audit", sim.player.pos)
				&"credit": sim.expedition["debt"] = maxi(0, int(sim.expedition["debt"]) - 20)
				&"salvage": sim.expedition["profit"] += 1
	sim.expedition["route"] = &"solidarity" if int(sim.expedition["solidarity"]) >= 2 else (&"profit" if int(sim.expedition["profit"]) > 0 else &"compliance")
	# Credit is an explicit liability. There is no automatic cash installment.
	if sim.wave >= WaveDirector.FINAL_WAVE and not sim.endless:
		world["resolution_pending"] = true


static func exit_options(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var world: Dictionary = sim.expedition.get("world", {})
	if sim.phase != Sim.Phase.RESOLUTION or not world.get("resolution_pending", false):
		return rows
	var cost := 0 if world["clearance"] else 12
	rows.append(_choice(&"released", "exit.", sim.player.materials >= cost, "choice.reason.poor" if sim.player.materials < cost else "", cost))
	var people := false
	for worker in world["workers"]:
		people = people or worker["state"] == &"safe"
	for roster in world["roster"]:
		people = people or (float(roster["hp"]) > 0.0 and float(roster["life"]) > 0.0)
	rows.append(_choice(&"collective", "exit.", people, "exit.reason.people" if not people else ""))
	rows.append(_choice(&"takeover", "exit.", true))
	return rows


static func choose_exit(sim: Sim, choice: StringName) -> bool:
	var row: Dictionary = {}
	for option in exit_options(sim):
		if option["id"] == choice and option["available"]:
			row = option
	if row.is_empty() or not sim.expedition["ending_outcome"].is_empty():
		return false
	var world: Dictionary = sim.expedition["world"]
	var outcome := {"kind": choice, "applied": true, "cost": int(row["cost"]),
		"repaired_copies": 0, "survivors": 0, "staff_uid": 0}
	sim.player.materials -= int(row["cost"])
	match choice:
		&"released":
			for take in sim.bank.takes:
				if take.condition < 100.0:
					outcome["repaired_copies"] += 1
				take.condition = 100.0
		&"collective":
			for worker in world["workers"]:
				if worker["state"] == &"safe":
					worker["state"] = &"exited"
					outcome["survivors"] += 1
			sync_roster(sim)
			for roster in world["roster"]:
				if roster["state"] in [&"active", &"bench"] and float(roster["hp"]) > 0.0 and float(roster["life"]) > 0.0:
					roster["state"] = &"exited"
					outcome["survivors"] += 1
			var keep: Array[Dictionary] = []
			for unit in sim.support_units:
				if not SupportSystem.COMPANIONS.has(unit["kind"]):
					keep.append(unit)
			sim.support_units = keep
			sim.player.hp = sim.player.max_hp()
		&"takeover":
			if not sim.bank.takes.is_empty():
				world["staff_uid"] = sim.bank.takes.back().uid
			outcome["staff_uid"] = world["staff_uid"]
	sim.expedition["ending"] = choice
	sim.expedition["ending_outcome"] = outcome
	world["resolution_pending"] = false
	_event(sim, &"exit_chosen", choice, sim.player.pos)
	StoryLedger.sync_expedition(sim)
	return true


static func _machine(sim: Sim, id: StringName) -> Dictionary:
	for machine in sim.expedition.get("world", {}).get("machines", []):
		if machine["id"] == id:
			return machine
	return {}


static func _worker(sim: Sim, id: StringName) -> Dictionary:
	for worker in sim.expedition.get("world", {}).get("workers", []):
		if worker["id"] == id:
			return worker
	return {}


static func _roster(sim: Sim, kind: StringName) -> Dictionary:
	for row in sim.expedition.get("world", {}).get("roster", []):
		if row["kind"] == kind:
			return row
	return {}


static func _unused_witness(sim: Sim) -> Dictionary:
	for worker in sim.expedition.get("world", {}).get("workers", []):
		if worker["state"] == &"safe" and not worker["testimony_used"]:
			return worker
	return {}


static func _event(sim: Sim, kind: StringName, subject: StringName, pos: Vector2) -> void:
	var event := {"kind": kind, "subject": subject, "stage": sim.wave, "pos": pos}
	var history: Array = sim.expedition["world"]["history"]
	history.append(event)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	sim.world_event.emit(event.duplicate(true))
	StoryLedger.on_world_event(sim, kind)


static func _append_history(history: Array, value: StringName) -> void:
	history.append(value)
	while history.size() > MAX_HISTORY:
		history.pop_front()


static func validate_plain(state: Dictionary, items: Array) -> bool:
	if not _keys_exact(state, STATE_KEYS):
		return false
	if not _name_in(state["route"], [&"compliance", &"solidarity", &"profit"]) \
			or not _name_in(state["ending"], [&""] + EXIT_IDS) \
			or not _name_in(state["recruited_boss"], [&""] + BOSS_IDS):
		return false
	for key in ["credit_taken", "rescued", "repairs", "audits", "solidarity", "profit"]:
		if not _integer_between(state[key], 0, 1000000):
			return false
	if not _integer_between(state["debt"], 0, MAX_DEBT) or (int(state["debt"]) > 0 and int(state["credit_taken"]) == 0) \
			or not _integer_between(state["cash_issued"], 0, 300) or not _number_between(state["tail_clock"], -1.2, 1.5):
		return false
	for key in ["completed_orders", "failed_orders", "recruited_bosses"]:
		if typeof(state[key]) != TYPE_ARRAY or state[key].size() > MAX_HISTORY:
			return false
		for entry in state[key]:
			if not _name_in(entry, BOSS_IDS if key == "recruited_bosses" else ORDER_IDS):
				return false
	if typeof(state["world"]) != TYPE_DICTIONARY or not _validate_world(state["world"]):
		return false
	if typeof(state["ending_outcome"]) != TYPE_DICTIONARY:
		return false
	var outcome: Dictionary = state["ending_outcome"]
	if outcome.is_empty():
		if state["ending"] != &"":
			return false
	else:
		if not _keys_exact(outcome, OUTCOME_KEYS) or not _name_in(outcome["kind"], EXIT_IDS) or outcome["kind"] != state["ending"] \
				or typeof(outcome["applied"]) != TYPE_BOOL or not outcome["applied"]:
			return false
		if not _integer_between(outcome["cost"], 0, 12) or int(outcome["cost"]) not in [0, 12] \
				or not _integer_between(outcome["repaired_copies"], 0, Sim.MAX_ECHO_CAPACITY) \
				or not _integer_between(outcome["survivors"], 0, 15) or not _integer_between(outcome["staff_uid"], 0, 2147483647):
			return false
		if (outcome["kind"] != &"released" and (int(outcome["cost"]) > 0 or int(outcome["repaired_copies"]) > 0)) \
				or (outcome["kind"] != &"collective" and int(outcome["survivors"]) > 0) \
				or (outcome["kind"] != &"takeover" and int(outcome["staff_uid"]) > 0):
			return false
	if typeof(state["mission"]) != TYPE_DICTIONARY or typeof(state["negotiation"]) != TYPE_DICTIONARY:
		return false
	var mission: Dictionary = state["mission"]
	if not mission.is_empty():
		if not _keys_exact(mission, ["kind", "target", "progress", "state", "wave", "protected_hp"]) \
				or not _name_in(mission["kind"], ORDER_IDS) or not _name_in(mission["state"], [&"pending", &"active", &"complete", &"failed"]) \
				or not _integer_between(mission["target"], 1, 8) or int(mission["target"]) != int(ORDER_TARGETS[mission["kind"]]) \
				or not _integer_between(mission["progress"], 0, int(mission["target"])) \
				or not _integer_between(mission["wave"], 1, 1000000) or not _number_between(mission["protected_hp"], 0.0, 45.0):
			return false
	var negotiation: Dictionary = state["negotiation"]
	if not negotiation.is_empty():
		if not _keys_exact(negotiation, ["uid", "kind", "pos", "remaining", "choice_pending"]) \
				or not _integer_between(negotiation["uid"], 1, 2147483647) or not _name_in(negotiation["kind"], BOSS_IDS) \
				or not _world_point(negotiation["pos"]) or not _number_between(negotiation["remaining"], 0.01, NEGOTIATION_TIME) \
				or typeof(negotiation["choice_pending"]) != TYPE_BOOL or not negotiation["choice_pending"] \
				or mission.get("kind", &"") != &"recruit" or mission.get("state", &"") != &"active":
			return false
	if items.size() > 16:
		return false
	var identities: Dictionary = {}
	for value in items:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = value
		if not _keys_exact(item, ["id", "kind", "pos", "range", "cost", "warning", "active", "cooldown", "used", "direction"]):
			return false
		if typeof(item["id"]) != TYPE_STRING_NAME or String(item["id"]).length() > 32 or item["id"] == &"" or identities.has(item["id"]) \
				or not _name_in(item["kind"], [&"press", &"conveyor", &"recycler", &"part", &"terminal", &"repair", &"rescue", &"negotiate"]) \
				or not _world_point(item["pos"]) or typeof(item["used"]) != TYPE_BOOL \
				or typeof(item["direction"]) != TYPE_VECTOR2 or item["direction"] not in [Vector2.LEFT, Vector2.RIGHT] \
				or not _number_between(item["range"], 112.0, 180.0) or not _integer_between(item["cost"], 0, 8) \
				or int(item["cost"]) != (8 if item["kind"] == &"recycler" else 0) \
				or not _number_between(item["warning"], 0.0, 1.1) or not _number_between(item["active"], 0.0, 8.0) \
				or not _number_between(item["cooldown"], 0.0, 70.0):
			return false
		identities[item["id"]] = true
	return true


static func _validate_world(world: Dictionary) -> bool:
	if not _keys_exact(world, WORLD_KEYS) or not _integer_between(world["act_id"], 1, 3) \
			or typeof(world["clearance"]) != TYPE_BOOL or typeof(world["resolution_pending"]) != TYPE_BOOL \
			or not _integer_between(world["settled_wave"], 0, 1000000) or not _integer_between(world["staff_uid"], 0, 2147483647):
		return false
	for key in ["machines", "workers", "roster", "witnesses", "history"]:
		if typeof(world[key]) != TYPE_ARRAY:
			return false
	if world["machines"].size() != 5 or world["workers"].size() > 12 or world["roster"].size() > 3 or world["witnesses"].size() > MAX_WITNESSES or world["history"].size() > MAX_HISTORY:
		return false
	var sites := WorldArena.machine_sites()
	for index in 5:
		var machine: Variant = world["machines"][index]
		if typeof(machine) != TYPE_DICTIONARY or not _keys_exact(machine, MACHINE_KEYS):
			return false
		if machine["id"] != sites[index]["id"] or machine["kind"] != sites[index]["kind"] or machine["pos"] != sites[index]["pos"] \
				or not _name_in(machine["status"], [&"operating", &"fault", &"repaired"]) or typeof(machine["stopped"]) != TYPE_BOOL \
				or not _integer_between(machine["repaired_wave"], 0, 1000000) or machine["direction"] not in [Vector2.LEFT, Vector2.RIGHT] \
				or ((machine["status"] == &"repaired") != (int(machine["repaired_wave"]) > 0)) \
				or (machine["status"] == &"repaired" and not machine["stopped"]):
			return false
	var ids: Dictionary = {}
	for worker in world["workers"]:
		if typeof(worker) != TYPE_DICTIONARY or not _keys_exact(worker, WORKER_KEYS):
			return false
		if not _integer_between(worker["stage"], 1, 12) or worker["id"] != StringName("worker_%d" % int(worker["stage"])) \
				or ids.has(worker["id"]) or not _world_point(worker["pos"]) or not _number_between(worker["hp"], 0.0, 45.0) \
				or not _name_in(worker["state"], [&"danger", &"safe", &"missing", &"exited"]) \
				or typeof(worker["testimony_used"]) != TYPE_BOOL or typeof(worker["aid_used"]) != TYPE_BOOL \
				or (worker["state"] in [&"safe", &"exited"] and float(worker["hp"]) <= 0.0):
			return false
		ids[worker["id"]] = true
	ids.clear()
	var active := 0
	for roster in world["roster"]:
		if typeof(roster) != TYPE_DICTIONARY or not _keys_exact(roster, ROSTER_KEYS) or not _name_in(roster["kind"], BOSS_IDS):
			return false
		var hp := float(SupportSystem.PROFILES[StringName("recruited_" + String(roster["kind"]))]["hp"])
		if ids.has(roster["kind"]) or not _number_between(roster["max_hp"], hp, hp) or not _number_between(roster["hp"], 0.0, hp) \
				or not _number_between(roster["life"], 0.0, 600.0) or not _integer_between(roster["uid"], 0, 2147483647) \
				or not _name_in(roster["state"], [&"active", &"bench", &"fallen", &"exited"]):
			return false
		ids[roster["kind"]] = true
		if roster["state"] == &"active":
			active += 1
			if int(roster["uid"]) <= 0 or float(roster["hp"]) <= 0.0 or float(roster["life"]) <= 0.0:
				return false
	if active > 1:
		return false
	ids.clear()
	var copy_witnesses := 0
	for witness in world["witnesses"]:
		if typeof(witness) != TYPE_STRING_NAME or ids.has(witness) or not (witness == &"self" or String(witness).begins_with("worker_") or String(witness).begins_with("copy_")):
			return false
		if String(witness).begins_with("worker_"):
			var found := false
			for worker in world["workers"]:
				found = found or (worker["id"] == witness and worker["state"] in [&"safe", &"exited"])
			if not found:
				return false
		elif witness != &"self":
			copy_witnesses += 1
			var serial := String(witness).trim_prefix("copy_")
			if copy_witnesses > MAX_COPY_WITNESSES or not serial.is_valid_int() or int(serial) <= 0 or int(serial) > 2147483647 or serial != str(int(serial)):
				return false
		ids[witness] = true
	for event in world["history"]:
		if typeof(event) != TYPE_DICTIONARY or not _keys_exact(event, ["kind", "subject", "stage", "pos"]) \
				or typeof(event["kind"]) != TYPE_STRING_NAME or typeof(event["subject"]) != TYPE_STRING_NAME \
				or String(event["kind"]).length() > 32 or String(event["subject"]).length() > 32 \
				or not _integer_between(event["stage"], 0, 1000000) or not _world_point(event["pos"]):
			return false
	return true


static func validate_state(sim: Sim) -> bool:
	if sim == null or not validate_plain(sim.expedition, sim.interactables):
		return false
	var world: Dictionary = sim.expedition["world"]
	if int(sim.expedition["cash_issued"]) > WaveDirector.cash_budget(sim.wave) \
			or (not sim.expedition["ending_outcome"].is_empty() and sim.wave < WaveDirector.FINAL_WAVE) \
			or (world["resolution_pending"] and (sim.phase != Sim.Phase.RESOLUTION or sim.wave != WaveDirector.FINAL_WAVE or sim.endless)) \
			or (sim.phase == Sim.Phase.RESOLUTION and (not world["resolution_pending"] or not sim.expedition["ending_outcome"].is_empty())) \
			or (sim.phase == Sim.Phase.WON and sim.expedition["ending_outcome"].is_empty()):
		return false
	var active_uids: Dictionary = {}
	for roster in world["roster"]:
		if roster["state"] != &"active":
			continue
		var found := false
		for unit in sim.support_units:
			if int(unit["uid"]) == int(roster["uid"]) and unit["kind"] == StringName("recruited_" + String(roster["kind"])):
				found = true
		if not found:
			return false
		active_uids[int(roster["uid"])] = true
	for unit in sim.support_units:
		if SupportSystem.COMPANIONS.has(unit["kind"]) and not active_uids.has(int(unit["uid"])):
			return false
	var staff_uid := int(world["staff_uid"])
	if staff_uid > 0 and sim.bank.find_uid(staff_uid) == null:
		return false
	if staff_uid != int(sim.expedition["ending_outcome"].get("staff_uid", 0)):
		return false
	for actor in sim.echoes:
		if staff_uid > 0 and actor.take.uid == staff_uid:
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
			if enemy.dead or enemy.hp != 1.0 or enemy.brain_state != &"defeated" or enemy.def == null \
					or enemy.def.id != negotiation["kind"] or enemy.pos != negotiation["pos"] or not sim.boss_shards.has(enemy):
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
