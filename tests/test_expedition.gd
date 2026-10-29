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
	c.ok(sim.interact(), "local negotiation recruits the defeated boss")
	c.ok(boss.dead, "recruitment resolves the original enemy exactly once")
	c.eq(sim.support_units.size(), 1, "companion consumes one real support slot")
	c.eq(sim.support_units[0]["kind"], &"recruited_foreman", "recruited boss keeps its actual support identity")
	c.ok(Expedition.order_complete(sim, order), "recruit order tracks its actual result")
	c.ok(not Expedition.is_negotiating(sim), "successful negotiation releases the battle")


func test_negotiation_expires_without_permanent_invulnerability(c: Check) -> void:
	var sim := _sim(3)
	var order := _order(sim, &"recruit")
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = sim.player.pos + Vector2(200.0, 0.0)
	sim._materialize(spawn)
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	Expedition.step(sim, Expedition.NEGOTIATION_TIME + 0.1)
	c.ok(not Expedition.is_negotiating(sim), "the protected choice has a finite deadline")
	c.ok(sim.boss.dead, "declining resolves the defeated boss")
	c.ok(not Expedition.order_complete(sim, order), "letting the recruit leave does not earn the recruit reward")
	c.eq(sim.support_units.size(), 0, "timeout creates no free companion")


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


func test_debt_and_actual_route_actions_select_three_endings(c: Check) -> void:
	for expected in [&"released", &"collective", &"indebted"]:
		var sim := _sim(12)
		if expected == &"collective":
			sim.expedition["solidarity"] = 3
		elif expected == &"indebted":
			sim.expedition["debt"] = 100
		Expedition.finish_wave(sim, false)
		c.eq(sim.expedition["ending"], expected, "actual route/debt state determines its ending")
		c.ok(int(sim.expedition["debt"]) <= 200, "debt stays bounded")


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
			c.ok(float(item["cooldown"]) > repair.wave_duration, "fixed press remains disabled through this encounter")


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
		c.eq(sim.expedition["debt"], 13 if complete else 33, "only the chosen advance creates debt; settlement applies the seven-material installment")


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


func test_three_endings_apply_distinct_once_only_outcomes_and_keep_them_in_endless(c: Check) -> void:
	for ending in [&"released", &"collective", &"indebted"]:
		var sim := _sim(12)
		var take := EchoTake.new()
		take.condition = 20.0
		sim.bank.takes.append(take)
		sim.player.hp = 5.0
		if ending == &"collective":
			sim.expedition["solidarity"] = 3
		elif ending == &"indebted":
			sim.expedition["debt"] = 100
			sim.expedition["credit_taken"] = 3
		var cash_before := sim.player.materials
		Expedition.finish_wave(sim, false)
		var outcome: Dictionary = sim.expedition["ending_outcome"]
		c.eq(outcome["kind"], ending, "actual route chooses its matching applied consequence")
		c.eq(Expedition.status(sim)["outcome_key"], "expedition.outcome." + String(ending), "End UI receives the exact applied outcome localization key")
		match ending:
			&"released":
				c.eq(take.condition, 100.0, "release repairs the actual saved bank copies")
				c.eq(outcome["repaired_copies"], 1, "receipt reports the actual repaired-copy count")
			&"collective":
				c.eq(sim.player.hp, sim.player.max_hp(), "collective ending fully heals the actual player")
				c.eq(sim.support_units.size(), 1, "collective ending recruits a real bounded friendly companion")
			&"indebted":
				c.eq(sim.player.materials, cash_before - 12 + 24, "indebted ending pays its actual bounded dividend after normal repayment")
				c.eq(sim.expedition["debt"], 88, "dividend retains the real outstanding credit obligation")
		var after_cash := sim.player.materials
		var after_units := sim.support_units.size()
		var after_debt := int(sim.expedition["debt"])
		Expedition.finish_wave(sim, false)
		c.ok(not Expedition.apply_ending_outcome(sim), "ending consequence cannot be claimed twice")
		c.eq(sim.player.materials, after_cash, "repeated settlement cannot duplicate dividend or charge another installment")
		c.eq(sim.support_units.size(), after_units, "repeated ending cannot duplicate companions")
		c.eq(sim.expedition["debt"], after_debt, "repeated ending cannot reapply debt changes")
		c.ok(Expedition.validate_state(sim), "applied ending uses the strict snapshot-safe world schema")
		sim.phase = Sim.Phase.WON
		c.ok(sim.begin_endless(), "consequences carry into an actual endless continuation")
		c.eq(sim.expedition["ending_outcome"], outcome, "continuation preserves the applied outcome ledger")


func test_collective_restores_existing_companion_and_defers_when_support_budget_is_full(c: Check) -> void:
	var existing := _sim(12)
	c.ok(SupportSystem.spawn(existing, &"recruited_collector", existing.player.pos), "fixture recruits one actual companion")
	var companion: Dictionary = existing.support_units[0]
	companion["hp"] = 1.0
	companion["life"] = 2.0
	existing.expedition["solidarity"] = 3
	Expedition.finish_wave(existing, false)
	c.eq(existing.support_units.size(), 1, "collective ending repairs the existing companion without duplicating it")
	c.eq(companion["hp"], companion["max_hp"], "existing companion receives real health restoration")
	c.eq(companion["life"], 600.0, "companion restoration persists into the next battle")
	c.ok(existing.expedition["ending_outcome"]["companion_restored"], "receipt records the actual restored companion outcome")
	var full := _sim(12)
	c.ok(SupportSystem.spawn(full, &"turret", full.player.pos), "full-budget fixture starts from a canonical friendly unit")
	while full.support_units.size() < SupportSystem.MAX_UNITS:
		var unit: Dictionary = full.support_units[0].duplicate(true)
		unit["uid"] = full._next_support_uid
		full._next_support_uid += 1
		full.support_units.append(unit)
	full.expedition["solidarity"] = 3
	Expedition.finish_wave(full, false)
	c.eq(full.support_units.size(), SupportSystem.MAX_UNITS, "ending respects the shared support budget")
	c.ok(full.expedition["ending_outcome"]["companion_pending"], "full support budget preserves a pending companion benefit")
	c.ok(Expedition.validate_plain(full.expedition, full.interactables), "deferred consequence remains plain and snapshot-valid")
	full.endless = true
	SupportSystem.damage(full, int(full.support_units.back()["uid"]), 10000.0)
	SupportSystem.step(full, 0.01)
	Expedition.step(full, 0.01)
	c.eq(full.support_units.size(), SupportSystem.MAX_UNITS, "freed capacity fulfills exactly one pending companion")
	c.ok(not full.expedition["ending_outcome"]["companion_pending"], "successful fulfillment clears the pending benefit")
	var uid := int(full.expedition["ending_outcome"]["companion_uid"])
	Expedition.step(full, 0.01)
	c.eq(full.expedition["ending_outcome"]["companion_uid"], uid, "later ticks cannot repeat the one-shot companion benefit")


func test_ending_outcome_schema_rejects_forged_repeatable_or_cross_route_effects(c: Check) -> void:
	var sim := _sim(12)
	sim.expedition["debt"] = 100
	sim.expedition["credit_taken"] = 3
	Expedition.finish_wave(sim, false)
	for key in ["applied", "cash", "kind", "companion_pending"]:
		var state := sim.expedition.duplicate(true)
		match key:
			"applied": state["ending_outcome"][key] = false
			"cash": state["ending_outcome"][key] = 48
			"kind": state["ending_outcome"][key] = &"collective"
			"companion_pending": state["ending_outcome"][key] = true
		c.ok(not Expedition.validate_plain(state, sim.interactables), "malformed or cross-route ending effect is rejected without normalization")


func test_two_actual_audit_orders_forgive_outstanding_credit_at_release_once(c: Check) -> void:
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
				c.ok(sim.interact(), "audited release uses actual terminal interactions in two different encounters")
		c.ok(Expedition.order_complete(sim, audit), "each audit completes its authoritative objective")
		sim._end_wave()
	c.eq(sim.expedition["audits"], 2, "two completed work orders earn the audited release route")
	c.eq(sim.expedition["debt"], 40, "unpaid chosen credit remains outstanding before the ending")
	sim.start_wave(12)
	sim._plan.clear()
	sim._end_wave()
	c.eq(sim.phase, Sim.Phase.WON, "audited release is applied through the actual campaign settlement")
	c.eq(sim.expedition["ending"], &"released", "completed audit evidence takes priority over the indebted ending")
	c.eq(sim.expedition["debt"], 0, "release actually writes off the outstanding credit")
	c.eq(sim.expedition["ending_outcome"]["forgiven_debt"], 40, "outcome receipt reports the actual nonzero forgiven amount")
	var outcome: Dictionary = sim.expedition["ending_outcome"].duplicate(true)
	Expedition.finish_wave(sim, false)
	c.eq(sim.expedition["ending_outcome"], outcome, "repeated final settlement does not repeat or erase the debt write-off")


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
