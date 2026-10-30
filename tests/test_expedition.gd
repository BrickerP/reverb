extends RefCounted


func _sim(wave: int = 1) -> Sim:
	var sim := Sim.new(137)
	sim.start_run()
	sim.start_wave(wave)
	sim.player.weapons.clear()
	sim.player.cooldowns.clear()
	sim.player.weapon_levels.clear()
	sim._plan.clear()
	return sim


func _order(sim: Sim, kind: StringName) -> AnomalyContract:
	var order := AnomalyContract.new()
	order.kind = kind
	order.accepted = true
	sim.active_contract = order
	Expedition.on_order_purchased(sim, order)
	sim.start_wave(sim.wave + 1)
	sim._plan.clear()
	return order


func test_twelve_encounters_have_three_distinct_mandatory_bosses(c: Check) -> void:
	var sim := _sim()
	c.eq(WaveDirector.FINAL_WAVE, 12, "campaign contains three acts of four encounters")
	for wave in range(1, 13):
		sim.start_wave(wave)
		c.eq(sim.is_boss_wave(), wave % 4 == 0, "every act has a real mandatory boss")
		if wave % 4 == 0:
			var expected: StringName = [&"foreman", &"collector", &"paradox"][int(wave / 4) - 1]
			c.eq(Expedition.boss_id(sim), expected, "each act concludes with its own opponent")
			var count := 0
			for event in sim._plan:
				if event.def.is_boss:
					count += 1
					c.eq(event.def.id, expected, "the actual spawn uses the act boss")
			c.eq(count, 1, "mandatory boss is scheduled exactly once")
	sim.endless = true
	c.ok(sim.is_boss_wave(16) and sim.is_boss_wave(20), "endless bosses repeat every four encounters")
	c.ok(not sim.is_boss_wave(15), "ordinary endless encounter does not become a boss")


func test_manual_collection_charges_role_but_automatic_money_does_not(c: Check) -> void:
	var sim := _sim()
	sim.character_energy = 0.0
	var pickup := Pickup.new()
	pickup.pos = sim.player.pos
	pickup.value = 4
	sim.pickups.append(pickup)
	c.ok(sim.collect_pickup(pickup), "player collection uses shared authoritative accounting")
	c.ok(sim.character_energy > 0.0, "manual salvage fuels a usable character ability")
	var charged := sim.character_energy
	c.ok(not sim.collect_pickup(pickup), "the same pickup cannot pay twice")
	var helper_pickup := Pickup.new()
	helper_pickup.value = 5
	sim.pickups.append(helper_pickup)
	c.ok(sim.collect_pickup(helper_pickup, false), "hound can collect cash through the same API")
	c.eq(sim.character_energy, charged, "automatic helper does not manufacture manual energy")
	var end_pickup := Pickup.new()
	end_pickup.value = 6
	sim.pickups.append(end_pickup)
	sim._end_wave()
	c.eq(sim.character_energy, charged, "end payout preserves money without granting manual energy")


func test_work_orders_change_the_actual_next_encounter(c: Check) -> void:
	for kind in Expedition.ORDER_IDS:
		var sim := _sim()
		var plan_size := sim._plan.size()
		var order := AnomalyContract.new()
		order.kind = kind
		Expedition.on_order_purchased(sim, order)
		sim.active_contract = order
		c.eq(sim.expedition["mission"]["state"], &"pending", "purchase prepares the next encounter")
		sim.start_wave(2)
		var mission: Dictionary = sim.expedition["mission"]
		c.eq(mission["state"], &"active", "the purchased objective becomes authoritative at battle start")
		c.ok(order.target > 0, "every work order has a real finite objective")
		c.ok(sim._plan.size() > plan_size, "order encounter has actual opponents")
		if kind in [&"salvage", &"audit", &"repair", &"rescue"]:
			c.ok(sim.interactables.size() > WorldArena.MACHINES.size(), "order creates real local mission targets")
		c.ok(not Expedition.order_complete(sim, order), "new order cannot pay before its objective")


func test_salvage_parts_need_local_interaction_and_never_auto_complete(c: Check) -> void:
	var sim := _sim()
	var order := _order(sim, &"salvage")
	var parts: Array[Dictionary] = []
	for item in sim.interactables:
		if item["kind"] == &"part":
			parts.append(item)
	c.eq(parts.size(), 3, "salvage scatters three bounded objective parts")
	c.ok(not sim.interact(), "a distant part cannot be claimed remotely")
	for item in parts:
		sim.player.pos = item["pos"]
		c.ok(sim.interact(), "nearby mission part has an actual interaction exit")
	c.ok(Expedition.order_complete(sim, order), "collecting all three parts satisfies the order")
	sim._end_wave()
	c.ok(sim.last_contract_success, "actual objective pays through the existing order settlement")
	c.ok(sim.expedition["completed_orders"].has(&"salvage"), "story route records the completed work")
	var failed := _sim()
	_order(failed, &"salvage")
	failed._end_wave()
	c.ok(not failed.last_contract_success, "automatic scrap payout does not collect rare objective parts")


func test_press_has_safe_warning_real_damage_and_recycler_has_real_cost(c: Check) -> void:
	var sim := _sim(3)
	var press: Dictionary = sim.interactables[0]
	press["cooldown"] = 0.0
	sim.player.pos = press["pos"]
	var hp := sim.player.hp
	c.ok(sim.interact(), "local machine can be activated")
	c.ok(float(press["warning"]) > 0.0, "press gives an escape warning before impact")
	Expedition.step(sim, 0.5)
	c.eq(sim.player.hp, hp, "warning does not silently damage the player")
	Expedition.step(sim, 0.7)
	c.ok(sim.player.hp < hp, "standing inside the warned press has a real consequence")
	var recycler: Dictionary = sim.interactables[2]
	recycler["cooldown"] = 0.0
	sim.player.pos = recycler["pos"]
	sim.player.materials = 0
	c.ok(not sim.interact(), "unaffordable recycler cannot grant free energy")
	sim.player.materials = 8
	sim.character_energy = 0.0
	c.ok(sim.interact(), "paying for local recycling grants its actual effect")
	c.eq(sim.player.materials, 0, "recycler consumes the visible material price")
	c.eq(sim.character_energy, 30.0, "machine converts cash into bounded ability energy")
	c.ok(not sim.interact(), "cooldown prevents repeated free effects")


func test_defeated_boss_negotiation_survives_autofire_and_recruits_once(c: Check) -> void:
	var sim := _sim(3)
	var order := _order(sim, &"recruit")
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = WorldArena.move_body(sim.player.pos, Vector2(180.0, 0.0), 48.0)
	sim._materialize(spawn)
	var boss := sim.boss
	sim.damage_enemy(boss, 100000.0, Vector2.ZERO, false)
	c.ok(Expedition.is_negotiating(sim), "lethal victory opens an authored negotiation window")
	c.ok(not boss.dead and boss.brain_state == &"defeated", "defeated body remains available for the choice")
	sim.damage_enemy(boss, 100000.0, Vector2.ZERO, false)
	c.eq(boss.hp, 1.0, "automatic fire cannot erase the negotiation target")
	var hp := sim.player.hp
	sim._hurt_player(100.0, &"grunt", &"hit", sim.player.pos, Vector2.ZERO)
	c.eq(sim.player.hp, hp, "negotiation protects the player long enough to decide")
	sim.player.pos = boss.pos
	c.ok(sim.choose_negotiation(&"stop_press"), "explicit Foreman terms stop the presses and recruit")
	c.ok(boss.dead, "recruitment resolves the original enemy exactly once")
	c.eq(sim.support_units.size(), 1, "companion consumes one real support slot")
	c.eq(sim.support_units[0]["kind"], &"recruited_foreman", "recruited boss keeps its actual support identity")
	c.ok(Expedition.order_complete(sim, order), "recruit order tracks its actual result")
	c.ok(not Expedition.is_negotiating(sim), "successful negotiation releases the battle")


func test_negotiation_pauses_until_explicit_decline_releases_protection(c: Check) -> void:
	var sim := _sim(3)
	var order := _order(sim, &"recruit")
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = sim.player.pos + Vector2(200.0, 0.0)
	sim._materialize(spawn)
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	var time := sim.wave_time
	sim.step(Expedition.NEGOTIATION_TIME + 0.1, Vector2.ZERO)
	c.eq(sim.wave_time, time, "pending explicit choice freezes the simulation clock")
	c.ok(sim.choose_negotiation(&"decline"), "decline explicitly resolves the protected choice")
	c.ok(not Expedition.is_negotiating(sim), "decline ends protection")
	c.ok(sim.boss.dead, "declining resolves the defeated boss")
	c.ok(not Expedition.order_complete(sim, order), "letting the recruit leave does not earn the recruit reward")
	c.eq(sim.support_units.size(), 0, "decline creates no free companion")


func test_cash_budget_is_linear_and_tail_reinforcement_is_bounded(c: Check) -> void:
	c.eq(WaveDirector.cash_budget(12) - WaveDirector.cash_budget(11), 6, "normal reward allowance grows linearly")
	c.ok(WaveDirector.cash_budget(10000) <= 300, "endless economy has a finite reward cap")
	var sim := _sim(7)
	sim.wave_time = sim.wave_duration - 2.0
	sim._step_tail_pressure(2.0)
	c.eq(sim.pending.size(), 1, "clearing late enemies triggers actual last-second pressure")
	for index in 100:
		sim._step_tail_pressure(2.0)
	c.ok(sim.pending.size() <= 8, "late pressure cannot allocate unlimited arrivals")
	var before := sim.pending.size()
	sim.wave_time = sim.wave_duration
	sim._step_tail_pressure(2.0)
	c.eq(sim.pending.size(), before, "finished encounter cannot generate new arrivals")


func test_debt_does_not_choose_an_ending(c: Check) -> void:
	for debt in [0, 100]:
		var sim := _sim(12)
		sim.expedition["debt"] = debt
		sim.expedition["credit_taken"] = 1 if debt > 0 else 0
		sim._end_wave()
		c.eq(sim.phase, Sim.Phase.RESOLUTION, "final settlement waits for intent")
		c.eq(sim.expedition["ending"], &"", "credit balance never chooses an ending")
		c.ok(sim.choose_exit(&"takeover"), "a free explicit exit exists with either balance")
		c.eq(sim.expedition["debt"], debt, "choice preserves the independent balance")


func test_three_boss_warnings_release_distinct_real_attacks(c: Check) -> void:
	for id in [&"foreman", &"collector", &"paradox"]:
		var sim := _sim()
		sim.player.pos = Vector2(1300.0, 700.0)
		var enemy := EnemyState.new()
		enemy.def = Content.enemy(id)
		enemy.pos = Vector2(1100.0, 700.0)
		enemy.damage = 5.0
		enemy.radius = 30.0
		EnemyBrain.step(sim, enemy, 0.01)
		c.eq(enemy.brain_state, &"warn", "boss attack has an actual escape warning")
		var profile := EnemyBrain.attack_profile(enemy)
		var expected: StringName = {&"foreman": &"press", &"collector": &"dash", &"paradox": &"cross"}[id]
		c.eq(profile["kind"], expected, "boss exposes its distinct authored attack geometry")
		var hp := sim.player.hp
		EnemyBrain.step(sim, enemy, 0.5)
		c.eq(sim.player.hp, hp, "boss warning causes no invisible damage")
		EnemyBrain.step(sim, enemy, 0.61)
		if id == &"collector":
			EnemyBrain.step(sim, enemy, 0.4)
		c.ok(sim.player.hp < hp, "remaining in the warned attack has a real consequence")


func test_actual_repeated_drops_cannot_exceed_the_linear_stage_allowance(c: Check) -> void:
	var sim := _sim(7)
	for index in 120:
		var spawn := PendingSpawn.new()
		spawn.def = Content.enemy(&"grunt")
		spawn.pos = sim.player.pos + Vector2(200.0, 0.0)
		sim._materialize(spawn)
		sim.damage_enemy(sim.enemies.back(), 100000.0, Vector2.ZERO, false)
		sim._compact()
	var total := 0
	for pickup in sim.pickups:
		total += pickup.value
	c.eq(total, WaveDirector.cash_budget(7), "actual enemy drops obey the bounded stage allowance")
	c.eq(sim.expedition["cash_issued"], total, "saved accounting matches the real emitted currency")


func test_conveyor_push_is_real_and_never_leaves_world_geometry(c: Check) -> void:
	var sim := _sim()
	var conveyor: Dictionary = sim.interactables[1]
	sim.player.pos = conveyor["pos"]
	var before := sim.player.pos
	Expedition.step(sim, 0.2)
	c.ok(sim.player.pos.distance_to(before) > 1.0, "active conveyor changes actual player position")
	c.ok(WorldArena.body_clear(sim.player.pos, PlayerState.RADIUS), "current respects shared collision geometry")
	conveyor["cooldown"] = 0.0
	sim.player.pos = conveyor["pos"]
	var direction: Vector2 = conveyor["direction"]
	c.ok(sim.interact(), "local interaction reverses the current")
	c.eq(conveyor["direction"], -direction, "reversal changes authoritative movement direction")


func test_enemy_cap_and_invalid_damage_preserve_authoritative_state(c: Check) -> void:
	var sim := _sim(9)
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"grunt")
	spawn.pos = sim.player.pos + Vector2(200.0, 0.0)
	for index in Sim.MAX_ENEMIES + 20:
		sim._materialize(spawn)
	c.eq(sim.enemies.size(), Sim.MAX_ORDINARY_ENEMIES, "ordinary materialization preserves two mandatory boss slots")
	var target := sim.enemies[0]
	var hp := target.hp
	sim.damage_enemy(target, NAN, Vector2.ZERO, false)
	c.eq(target.hp, hp, "nonfinite damage cannot corrupt saved enemy state")
	var boss_spawn := PendingSpawn.new()
	boss_spawn.def = Content.enemy(&"foreman")
	boss_spawn.pos = spawn.pos
	sim._materialize(boss_spawn)
	c.eq(sim.enemies.size(), Sim.MAX_ORDINARY_ENEMIES + 1, "mandatory boss uses its reserved slot without evicting ordinary enemies")
	c.ok(sim.boss != null, "population cap cannot accidentally omit the mandatory boss")


func test_enemy_ground_fields_can_damage_supports_without_player_overlap(c: Check) -> void:
	var sim := _sim(7)
	var point := WorldArena.move_body(sim.player.pos, Vector2(250.0, 0.0), 24.0)
	c.ok(SupportSystem.spawn(sim, &"turret", point), "support starts inside the real field fixture")
	var unit: Dictionary = sim.support_units[0]
	var hp := float(unit["hp"])
	var zone := EnemyZone.new()
	zone.pos = point
	zone.damage = 5.0
	zone.warning = 0.0
	sim.enemy_zones.append(zone)
	EnemyBrain.step_zones(sim, 0.01)
	c.near(float(unit["hp"]), hp - 5.0, 0.001, "enemy field damage reaches support even when player is safely outside")
	EnemyBrain.step_zones(sim, 0.01)
	c.near(float(unit["hp"]), hp - 5.0, 0.001, "one field tick cannot repeatedly damage support every render frame")


func test_audit_terminals_create_hazards_and_repair_stops_faulty_machines(c: Check) -> void:
	var audit := _sim()
	var audit_order := _order(audit, &"audit")
	for item in audit.interactables:
		if item["kind"] == &"terminal":
			audit.player.pos = item["pos"]
			c.ok(audit.interact(), "audit terminal executes through local interaction")
	c.ok(Expedition.order_complete(audit, audit_order), "both terminal inspections complete the real audit")
	c.eq(audit.enemy_zones.size(), 2, "inspection changes the battle with two escape hazards")
	c.ok(audit.enemy_zones[0].is_warning(), "inspection hazard gives a warning before damaging")
	var repair := _sim()
	var repair_order := _order(repair, &"repair")
	Expedition.step(repair, 2.1)
	c.ok(float(repair.interactables[0]["warning"]) > 0.0, "repair order creates a faulty press even in an early encounter")
	for item in repair.interactables:
		if item["kind"] == &"repair":
			repair.player.pos = item["pos"]
			c.ok(repair.interact(), "repair control has a real interaction exit")
	c.ok(Expedition.order_complete(repair, repair_order), "repairing the controller completes the order")
	for item in repair.interactables:
		if item["kind"] == &"press":
			c.eq(float(item["warning"]), 0.0, "successful repair cancels the pending dangerous press")
			var machine := Expedition._machine(repair, item["id"])
			if machine["status"] == &"repaired":
				c.ok(machine["stopped"], "fixed press remains stopped in the persistent world")


func test_rescue_target_can_be_saved_or_lost_to_real_enemy_contact(c: Check) -> void:
	for save_worker in [true, false]:
		var sim := _sim()
		var order := _order(sim, &"rescue")
		var target: Dictionary = {}
		for item in sim.interactables:
			if item["kind"] == &"rescue":
				target = item
		if save_worker:
			sim.player.pos = target["pos"]
			c.ok(sim.interact(), "reaching the worker safely rescues them")
			c.ok(Expedition.order_complete(sim, order), "rescue success depends on the actual interaction")
		else:
			var enemy := EnemyState.new()
			enemy.def = Content.enemy(&"grunt")
			enemy.pos = target["pos"]
			enemy.radius = 12.0
			enemy.damage = 50.0
			sim.enemies.append(enemy)
			Expedition.step(sim, 1.0)
			c.eq(sim.expedition["mission"]["state"], &"failed", "enemy contact can actually destroy the rescue objective")
			sim.player.pos = target["pos"]
			c.ok(not sim.interact(), "destroyed target cannot be rescued after the fact")
			c.ok(not Expedition.order_complete(sim, order), "failed protection does not grant a rescue reward")


func test_credit_advance_quota_and_debt_are_actual_financial_consequences(c: Check) -> void:
	for complete in [true, false]:
		var sim := _sim()
		var before := sim.player.materials
		var order := _order(sim, &"credit")
		c.eq(sim.player.materials, before + 30, "credit immediately finances the real build currency")
		c.eq(sim.expedition["debt"], 40, "the advance creates a saved repayment obligation")
		sim.wave_kills = 8 if complete else 7
		Expedition.step(sim, 0.01)
		c.eq(Expedition.order_complete(sim, order), complete, "only the actual eight-kill quota earns the credit rebate")
		sim._end_wave()
		c.eq(sim.last_contract_success, complete, "settlement follows the real quota outcome")
		c.eq(sim.expedition["debt"], 20 if complete else 40, "credit rebate is explicit and settlement never automatically taxes cash")


func test_failed_ordinary_orders_never_create_finance_debt(c: Check) -> void:
	for kind in [&"salvage", &"audit", &"repair", &"rescue", &"recruit"]:
		var sim := _sim()
		_order(sim, kind)
		sim._end_wave()
		c.ok(not sim.last_contract_success, "unfinished work order loses its reward")
		c.eq(sim.expedition["debt"], 0, "ordinary work order failure never opts the player into finance debt")
		c.eq(sim.expedition["credit_taken"], 0, "ordinary failure does not fabricate an advance ledger")
		c.ok(Expedition.validate_state(sim), "normal failed-order state remains valid for save and archive")


func test_failed_credit_preserves_only_the_explicit_advance_ledger(c: Check) -> void:
	var sim := _sim()
	_order(sim, &"credit")
	sim.player.materials = 0
	sim._end_wave()
	c.eq(sim.expedition["debt"], 40, "failed credit keeps the original explicit debt when no installment can be paid")
	c.eq(sim.expedition["credit_taken"], 1, "the finance ledger records exactly one chosen advance")
	c.ok(sim.expedition["failed_orders"].has(&"credit"), "failed quota remains visible in the actual work history")
	c.ok(Expedition.validate_state(sim), "unpaid explicit finance state remains a valid save")


func test_world_plain_validation_is_pure_and_rejects_malformed_authoritative_state(c: Check) -> void:
	var sim := _sim()
	var before := sim.expedition.duplicate(true)
	c.ok(Expedition.validate_plain(sim.expedition, sim.interactables), "new campaign dictionaries satisfy the closed schema")
	c.eq(sim.expedition, before, "validation never initializes or mutates caller state")
	for invalid_kind in [&"debt", &"object", &"history", &"mission", &"geometry", &"timer", &"duplicate"]:
		var state := sim.expedition.duplicate(true)
		var items: Array = sim.interactables.duplicate(true)
		match invalid_kind:
			&"debt": state["debt"] = 1
			&"object": state["ending"] = Node.new()
			&"history": state["completed_orders"].resize(Expedition.MAX_HISTORY + 1)
			&"mission": state["mission"] = {"kind": &"salvage", "target": 1, "progress": 9, "state": &"active", "wave": 2, "protected_hp": 0.0}
			&"geometry": items[0]["pos"] = Vector2(INF, 0.0)
			&"timer": items[0]["warning"] = NAN
			&"duplicate": items.append(items[0].duplicate(true))
		c.ok(not Expedition.validate_plain(state, items), "malformed world state cannot enter a save or undo record")
		if invalid_kind == &"object":
			state["ending"].free()


func test_live_negotiation_validation_requires_the_actual_protected_boss(c: Check) -> void:
	var sim := _sim(3)
	_order(sim, &"recruit")
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = sim.player.pos + Vector2(200.0, 0.0)
	sim._materialize(spawn)
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	c.ok(Expedition.validate_state(sim), "real defeated boss plus local protected choice validates")
	var before := sim.expedition.duplicate(true)
	sim.expedition["negotiation"]["uid"] = sim.boss.uid + 1
	c.ok(not Expedition.validate_state(sim), "invented boss reference cannot grant permanent negotiation safety")
	sim.expedition = before
	sim.boss.brain_state = &"approach"
	c.ok(not Expedition.validate_state(sim), "invulnerable negotiation cannot attach to a still-active attacker")


func test_finished_order_does_not_leave_an_orphan_objective_in_the_next_encounter(c: Check) -> void:
	var sim := _sim()
	_order(sim, &"salvage")
	sim._end_wave()
	c.ok(sim.expedition["failed_orders"].has(&"salvage"), "completed encounter preserves its work history")
	sim.start_next_wave()
	c.ok(sim.expedition["mission"].is_empty(), "next battle does not inherit a settled work objective")
	c.eq(Expedition.status(sim)["objective"], "order.survive.objective", "HUD receives the actual current battle objective")
	c.ok(Expedition.validate_state(sim), "next battle's cleared mission remains snapshot-valid")


func test_status_and_nearby_interaction_are_pure_even_before_campaign_start(c: Check) -> void:
	for started in [false, true]:
		var sim := Sim.new(754)
		if started:
			sim.start_run()
		var state := sim.expedition.duplicate(true)
		var items: Array[Dictionary] = sim.interactables.duplicate(true)
		var rng_state := sim.rng.state
		var hazard_state := sim.hazard_rng.state
		for index in 10:
			var status := Expedition.status(sim)
			c.ok(status.has("objective"), "read-only status has a safe localized objective before initialization")
			Expedition.interaction(sim)
		c.eq(sim.expedition, state, "HUD status never initializes or changes authoritative expedition state")
		c.eq(sim.interactables, items, "nearest interaction never changes world state")
		c.eq(sim.rng.state, rng_state, "HUD status cannot consume gameplay random state")
		c.eq(sim.hazard_rng.state, hazard_state, "HUD status cannot consume hazard random state")


func test_orphaned_defeated_boss_cannot_be_restored_without_negotiation(c: Check) -> void:
	var sim := _sim(3)
	_order(sim, &"recruit")
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = sim.player.pos + Vector2(200.0, 0.0)
	sim._materialize(spawn)
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	sim.expedition["negotiation"] = {}
	c.ok(not Expedition.validate_state(sim), "a detached defeated body cannot become an immortal boss in a restored encounter")


func test_collector_dash_damage_and_remaining_warning_share_the_same_geometry(c: Check) -> void:
	var sim := _sim()
	sim.player.pos = Vector2(1300.0, 748.0)
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"collector")
	enemy.pos = Vector2(1100.0, 700.0)
	enemy.radius = 29.0
	enemy.damage = 5.0
	enemy.attack_direction = Vector2.RIGHT
	enemy.brain_state = &"dash"
	enemy.brain_time = 0.65
	var hp := sim.player.hp
	EnemyBrain.step(sim, enemy, 0.4)
	c.eq(sim.player.hp, hp, "player outside the drawn half-width plus their body radius avoids the real charge")
	var profile := EnemyBrain.attack_profile(enemy)
	c.near(float(profile["radius"]), 34.0, 0.001, "drawn charge half-width equals physical lane half-width")
	c.near(float(profile["reach"]), 580.0 * 0.25, 0.001, "active warning shrinks to the actual remaining charge travel")


func _living_uids(sim: Sim) -> Array[int]:
	var ids: Array[int] = []
	for enemy in sim.enemies:
		if not enemy.dead:
			ids.append(enemy.uid)
	return ids


func test_reserved_boss_and_shard_slots_never_erase_living_enemies(c: Check) -> void:
	var sim := _sim(12)
	var ordinary := PendingSpawn.new()
	ordinary.def = Content.enemy(&"grunt")
	ordinary.pos = sim.player.pos + Vector2(220.0, 0.0)
	for index in Sim.MAX_ENEMIES + 10:
		sim._materialize(ordinary)
	var original := _living_uids(sim)
	c.eq(original.size(), Sim.MAX_ORDINARY_ENEMIES, "ordinary enemies leave two actual reserved slots")
	c.ok(not sim.queue_spawn(ordinary), "ordinary spawn queue respects the same reserved capacity")
	var boss_spawn := PendingSpawn.new()
	boss_spawn.def = Content.enemy(&"paradox")
	boss_spawn.pos = sim.player.pos + Vector2(-220.0, 0.0)
	c.ok(sim._materialize(boss_spawn), "mandatory boss actually appears in its legal reserved slot")
	sim.boss.hp = sim.boss.max_hp * 0.5 + 1.0
	sim.damage_enemy(sim.boss, 2.0, Vector2.ZERO, false)
	c.eq(sim.boss_phase, 2, "Paradox can split using the second reserved slot")
	c.eq(sim.enemies.size(), Sim.MAX_ENEMIES, "ordinary enemies plus both boss bodies share the exact finite budget")
	var after := _living_uids(sim)
	for uid in original:
		c.ok(after.has(uid), "every previously living enemy UID survives boss admission and splitting")
	c.eq(sim.kills, 0, "reserved admission does not bypass kill accounting")
	c.eq(sim.pickups.size(), 0, "reserved admission cannot fabricate drops or silently discard earned ones")


func test_artificial_saturation_retries_boss_and_split_after_real_deaths(c: Check) -> void:
	var sim := _sim(12)
	for index in Sim.MAX_ENEMIES:
		var enemy := EnemyState.new()
		enemy.def = Content.enemy(&"grunt")
		enemy.uid = sim._next_uid
		sim._next_uid += 1
		enemy.hp = 10.0
		enemy.max_hp = 10.0
		enemy.pos = sim.player.pos + Vector2(220.0, 0.0)
		sim.enemies.append(enemy)
	var original := _living_uids(sim)
	var deaths := [0]
	sim.enemy_killed.connect(func(_info: EnemyDeathInfo) -> void: deaths[0] += 1)
	var boss_spawn := PendingSpawn.new()
	boss_spawn.def = Content.enemy(&"paradox")
	boss_spawn.pos = sim.player.pos + Vector2(-220.0, 0.0)
	c.ok(not sim._materialize(boss_spawn), "artificial saturation rejects immediate boss admission without killing anyone")
	c.eq(_living_uids(sim), original, "every living UID survives the full-capacity rejection")
	c.eq(sim.pending.size(), 1, "mandatory boss retains its original spawn record for retry")
	c.eq(deaths[0], 0, "no silent death event is manufactured to make room")
	var first := sim.enemies[0]
	sim.damage_enemy(first, 1000.0, Vector2.ZERO, false)
	sim._compact()
	sim._spawn_enemies(0.01)
	c.ok(sim.boss != null, "boss appears after a real accounted death frees capacity")
	c.eq(sim.pending.size(), 0, "successful retry consumes its pending record exactly once")
	sim.boss.hp = sim.boss.max_hp * 0.5 + 1.0
	sim.damage_enemy(sim.boss, 2.0, Vector2.ZERO, false)
	var remaining := sim.boss.hp
	c.eq(sim.boss_phase, 1, "full-capacity split safely waits without changing the phase or health allocation")
	var second := sim.enemies[0]
	sim.damage_enemy(second, 1000.0, Vector2.ZERO, false)
	sim._compact()
	sim._boss_step(0.01)
	c.eq(sim.boss_phase, 2, "split retries after a real death frees the shard slot")
	c.near(sim.boss_shards[0].hp + sim.boss_shards[1].hp, remaining, 0.001, "deferred split preserves remaining boss health")
	c.eq(sim.kills, 2, "only the two actual combat deaths increment kills")
	c.eq(deaths[0], 2, "only the two actual combat deaths emit death events")
	c.eq(sim.pickups.size(), 2, "both actual kills retain their normal drops")
	var survivors := _living_uids(sim)
	for uid in original:
		if uid != first.uid and uid != second.uid:
			c.ok(survivors.has(uid), "retry preserves every enemy that the player did not kill")


func test_three_endings_apply_once_and_persist_in_endless(c: Check) -> void:
	for ending in Expedition.EXIT_IDS:
		var sim := _sim(12)
		for item in sim.interactables:
			if item["kind"] == &"rescue":
				sim.player.pos = item["pos"]
				c.ok(sim.interact(), "ambient worker can leave danger without an order")
		sim._end_wave()
		c.eq(sim.phase, Sim.Phase.RESOLUTION, "final fight has an explicit choice phase")
		var before := sim.player.materials
		c.ok(sim.choose_exit(ending), "requested ending is a validated player choice")
		var outcome: Dictionary = sim.expedition["ending_outcome"].duplicate(true)
		c.eq(outcome["kind"], ending, "receipt follows intent")
		c.eq(sim.player.materials, before - int(outcome["cost"]), "only displayed ending price is charged")
		c.ok(not sim.choose_exit(ending), "repeated choice cannot pay or reward twice")
		c.ok(Expedition.validate_state(sim), "chosen ending remains snapshot valid")
		c.ok(sim.begin_endless(), "actual endless continuation starts")
		c.eq(sim.expedition["ending_outcome"], outcome, "endless retains actual ending facts")


func test_collective_exits_the_actual_worker_without_fabricating_a_companion(c: Check) -> void:
	var sim := _sim(12)
	for item in sim.interactables:
		if item["kind"] == &"rescue":
			sim.player.pos = item["pos"]
			c.ok(sim.interact(), "worker genuinely leaves danger")
	c.eq(sim.support_units.size(), 0, "saved worker is never a decoy")
	sim._end_wave()
	c.ok(sim.choose_exit(&"collective"), "saved worker unlocks a collective choice")
	c.eq(sim.expedition["ending_outcome"]["survivors"], 1, "receipt counts the actual person")
	c.eq(sim.expedition["world"]["workers"].back()["state"], &"exited", "person exits alive")
	c.eq(sim.support_units.size(), 0, "ending cannot invent a friendly unit")


func test_ending_outcome_schema_rejects_forged_repeatable_or_cross_route_effects(c: Check) -> void:
	var sim := _sim(12)
	sim._end_wave()
	c.ok(sim.choose_exit(&"released"), "explicit release applies")
	for key in ["applied", "cash", "kind", "companion_pending"]:
		var state := sim.expedition.duplicate(true)
		match key:
			"applied": state["ending_outcome"][key] = false
			"cash": state["ending_outcome"][key] = 48
			"kind": state["ending_outcome"][key] = &"collective"
			"companion_pending": state["ending_outcome"][key] = true
		c.ok(not Expedition.validate_plain(state, sim.interactables), "forged or cross-route ending effects are rejected")


func test_two_actual_audits_grant_clearance_without_selecting_an_ending(c: Check) -> void:
	var sim := _sim(9)
	sim.phase = Sim.Phase.SHOP
	var credit := AnomalyContract.new()
	credit.kind = &"credit"
	Expedition.on_order_purchased(sim, credit)
	sim.player.materials = 0
	for index in 2:
		var audit := _order(sim, &"audit")
		for item in sim.interactables:
			if item["kind"] == &"terminal":
				sim.player.pos = item["pos"]
				c.ok(sim.interact(), "audits use actual terminal interactions")
		c.ok(Expedition.order_complete(sim, audit), "actual audit objective completes")
		sim._end_wave()
	c.eq(sim.expedition["debt"], 0, "second audit independently clears the balance")
	c.ok(sim.expedition["world"]["clearance"], "clearance is an independent fact")
	sim.start_wave(12)
	sim._plan.clear()
	sim._end_wave()
	c.eq(sim.phase, Sim.Phase.RESOLUTION, "clearance cannot auto-select an ending")
	c.eq(sim.expedition["ending"], &"", "audit does not override player intent")
	c.ok(sim.choose_exit(&"takeover"), "audited player can deliberately choose a different future")
	c.eq(sim.expedition["ending"], &"takeover", "choice wins over automatic moral scoring")


func test_reserved_slots_apply_to_elite_children_and_boss_minions(c: Check) -> void:
	var sim := _sim(12)
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"grunt")
	spawn.pos = sim.player.pos + Vector2(220.0, 0.0)
	for index in Sim.MAX_ORDINARY_ENEMIES:
		sim._materialize(spawn)
	var elite := sim.enemies[0]
	elite.elite = true
	elite.elite_kind = &"splitter"
	sim._split_elite(elite)
	c.eq(sim.enemies.size(), Sim.MAX_ORDINARY_ENEMIES, "elite children cannot consume mandatory boss reservation")
	var boss_spawn := PendingSpawn.new()
	boss_spawn.def = Content.enemy(&"paradox")
	boss_spawn.pos = sim.player.pos + Vector2(-220.0, 0.0)
	sim._materialize(boss_spawn)
	sim._boss_minion_cd = 0.0
	sim._boss_step(0.01)
	c.eq(sim.pending.size(), 0, "boss minion queue cannot consume the reserved shard slot")
	c.eq(_living_uids(sim).size(), Sim.MAX_ORDINARY_ENEMIES + 1, "blocked ordinary admissions preserve every current living body")


func test_boss_impact_geometry_respects_actual_support_body_radius(c: Check) -> void:
	for id in [&"foreman", &"paradox"]:
		var sim := _sim()
		var point := sim.player.pos
		var offset := Vector2(130.0, 0.0) if id == &"foreman" else Vector2(220.0, 0.0)
		c.ok(SupportSystem.spawn(sim, &"turret", point + offset), "support starts just outside the warned shape plus its actual body")
		var unit: Dictionary = sim.support_units[0]
		var hp := float(unit["hp"])
		var enemy := EnemyState.new()
		enemy.def = Content.enemy(id)
		enemy.attack_target = point
		enemy.damage = 5.0
		EnemyBrain._boss_impact(sim, enemy)
		c.eq(float(unit["hp"]), hp, "boss impact does not damage supports outside physical warning geometry")
