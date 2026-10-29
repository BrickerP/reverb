extends SceneTree
# Source-backed economic envelopes plus bounded, unmodified-stat campaign simulations.
# godot --headless --path . --script res://tools/expedition_balance_probe.gd -- [output.json] [seed_count]

const DEFAULT_OUTPUT := "/Users/yupeng/projects/personal/reverb-delivery-expedition-closeout/economy.json"
const DT := 1.0 / 60.0
const MARKET_RESERVE := 10
const MARKET_SAMPLES := 96
const MAX_RUN_STEPS := 90000
const MAX_STAGE_STEPS := 18000
const MAX_RUN_WALL_MS := 20000
const SEEDS: Array[int] = [11, 29, 47, 83]
const ROLES: Array[StringName] = [&"looper", &"solo", &"mender"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else DEFAULT_OUTPUT
	var seed_count := clampi(int(args[1]), 1, SEEDS.size()) if args.size() > 1 else 2
	var temp_dir := "/tmp/reverb-expedition-economy-probe"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	for key: String in ["REVERB_SAVE", "REVERB_RUN_LOG", "REVERB_SETTINGS", "REVERB_FEEDBACK_LOG", "REVERB_SUSPEND"]:
		OS.set_environment(key, temp_dir + "/" + key.to_lower() + ".json")
	await process_frame
	var report := {"schema": 1, "version": ProjectSettings.get_setting("application/config/version", ""),
		"baseline": {"daily": false, "archive": false, "ascension": 0,
			"market_reserve": MARKET_RESERVE, "market_samples_per_stage": MARKET_SAMPLES,
			"market_held_grades": {"1": 0, "5": 1, "10": 2},
			"campaign_starting_cash": Sim.START_MATERIALS,
			"max_run_steps": MAX_RUN_STEPS, "max_stage_steps": MAX_STAGE_STEPS,
			"max_run_wall_ms": MAX_RUN_WALL_MS, "dt": DT},
		"limits": ["Market envelopes spend the stated stage cap plus ten; the cap is not guaranteed actual earnings.",
			"Held grades in market samples are explicit price scenarios, not claims about natural stage progression.",
			"Greedy Bot buys affordable equipment, refits and rerolls; it does not plan orders or replacements.",
			"Assembly policy adds only profitable, affordable full-build assembly plus restocking before the same greedy shopper.",
			"Both policies use identical opportunistic role skills and nearby safe interactions; these are heuristics, not human play.",
			"Expected DPS omits target coverage, hazards and support utility; no balance changes are inferred from wins alone.",
			"Baseline movement ignores attack warnings. Telegraph-aware movement samples collision-safe escape directions from actual boss targets and press warnings; it is a separate diagnostic policy."],
		"source_grade_multipliers": [], "branch_tradeoffs": branch_tradeoffs(), "market": [], "market_by_role": [], "runs": []}
	for grade in WeaponDef.MAX_LEVEL + 1:
		report["source_grade_multipliers"].append(Content.weapon(&"pistol").level_mult(grade))
	for stage in [1, 5, 10]:
		report["market"].append(market_summary(stage, MARKET_SAMPLES))
		for role in Content.characters():
			report["market_by_role"].append(market_summary(stage, MARKET_SAMPLES, role))
	_write(output, report)
	for combat_mode: StringName in [&"baseline", &"telegraph_aware"]:
		for policy: StringName in [&"greedy", &"assembly"]:
			for role in ROLES:
				for i in seed_count:
					var run := play(SEEDS[i], role, policy, combat_mode)
					report["runs"].append(run)
					print("ECONOMY_RUN ", JSON.stringify({"policy": policy, "combat_mode": combat_mode,
						"role": role, "seed": SEEDS[i], "status": run["status"], "stage": run["last_stage"],
						"bosses": run["bosses"], "combines": run["combines"], "wall_ms": run["wall_ms"]}))
					_write(output, report)
					await process_frame
	report["summary"] = summarize_runs(report["runs"])
	_write(output, report)
	print("ECONOMY_REPORT ", output)
	quit(0)


static func branch_tradeoffs() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for base: WeaponDef in Content.weapons().values():
		for target: StringName in base.evolution_options:
			var branch := Content.weapon(target)
			var before := base.level_dps(WeaponDef.MAX_LEVEL)
			var after := branch.level_dps(WeaponDef.MAX_LEVEL)
			rows.append({"base": String(base.id), "branch": String(target), "grade": WeaponDef.MAX_LEVEL,
				"role": String(branch.role), "carrier": String(branch.carrier),
				"base_dps": before, "branch_dps": after, "ratio": after / maxf(0.001, before)})
	return rows


static func funding_sample(stage: int, seed_value: int, held_grade: int = 0,
		role: StringName = &"looper") -> Dictionary:
	var sim := Sim.new(seed_value)
	Content.character(role).apply(sim)
	sim.daily_modifier = &""
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = stage
	sim.player.weapon_levels[0] = held_grade
	sim.player.materials = WaveDirector.cash_budget(stage) + MARKET_RESERVE
	sim.shop.roll(sim)
	var gear_total := 0
	var shelf_total := 0
	var affordable_gear := 0
	var cheapest_gear := 2147483647
	var cheapest_paid_order := 2147483647
	var support_count := 0
	for offer in sim.shop.offers:
		shelf_total += offer.price
		if offer.is_contract():
			if offer.contract.kind != AnomalyContract.CREDIT:
				cheapest_paid_order = mini(cheapest_paid_order, offer.price)
			continue
		gear_total += offer.price
		cheapest_gear = mini(cheapest_gear, offer.price)
		if offer.price <= sim.player.materials:
			affordable_gear += 1
		if offer.is_weapon() and offer.weapon.support_kind != &"":
			support_count += 1
	var paired := sim.shop.offers[0]
	var matches := paired.is_weapon() and paired.id() == sim.player.weapons[0].id \
			and paired.weapon_level == held_grade
	var assembly_fee := Shop.combine_cost(sim.player.weapons[0], held_grade)
	var refit := Shop.upgrade_cost(sim.player.weapons[0], held_grade)
	var initial := sim.player.weapons[0].level_dps(held_grade)
	var assembled := sim.player.weapons[0].level_dps(held_grade + 1)
	return {"seed": seed_value, "stage": stage, "held_grade": held_grade, "role": String(role),
		"wallet": sim.player.materials, "stage_cash_cap": WaveDirector.cash_budget(stage),
		"six_offer_total": shelf_total, "four_gear_total": gear_total,
		"all_four_gear_affordable": gear_total <= sim.player.materials,
		"affordable_gear_count": affordable_gear,
		"gear_plus_paid_order_cost": cheapest_gear + cheapest_paid_order,
		"gear_plus_paid_order_affordable": cheapest_gear + cheapest_paid_order <= sim.player.materials,
		"valid_four_gear_and_one_paid_order_cost": gear_total + cheapest_paid_order,
		"paired_matches": matches, "paired_price": paired.price,
		"paired_plus_combine_cost": paired.price + assembly_fee, "cash_refit_cost": refit,
		"assembly_from_purchased_pair_affordable": paired.price + assembly_fee <= sim.player.materials,
		"refit_affordable": refit <= sim.player.materials,
		"two_body_to_one_dps_retained": assembled / maxf(0.001, 2.0 * initial),
		"host_dps_gain_ratio": assembled / maxf(0.001, initial), "support_stock_count": support_count}


static func quantiles(values: Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {}
	return {"min": ordered[0], "p10": ordered[floori(float(ordered.size() - 1) * 0.1)],
		"p50": ordered[floori(float(ordered.size() - 1) * 0.5)],
		"p90": ordered[floori(float(ordered.size() - 1) * 0.9)], "max": ordered.back()}


static func market_summary(stage: int, count: int, role: StringName = &"looper") -> Dictionary:
	var grade := 0 if stage == 1 else (1 if stage == 5 else 2)
	var result := {"stage": stage, "role": String(role), "held_grade": grade, "wallet": WaveDirector.cash_budget(stage) + MARKET_RESERVE,
		"samples": count, "all_gear_affordable_count": 0, "zero_affordable_gear_count": 0,
		"gear_plus_paid_order_affordable_count": 0, "paired_match_count": 0,
		"assembly_affordable_count": 0, "refit_affordable_count": 0, "support_stock_count": 0,
		"price_distributions": {}, "examples": []}
	var distributions := {}
	for key in ["six_offer_total", "four_gear_total", "valid_four_gear_and_one_paid_order_cost",
			"gear_plus_paid_order_cost", "paired_price", "paired_plus_combine_cost", "cash_refit_cost",
			"two_body_to_one_dps_retained", "host_dps_gain_ratio", "affordable_gear_count"]:
		distributions[key] = []
	for i in count:
		var sample := funding_sample(stage, 1009 + i * 7919, grade, role)
		for key in distributions:
			distributions[key].append(sample[key])
		result["all_gear_affordable_count"] += int(sample["all_four_gear_affordable"])
		result["zero_affordable_gear_count"] += int(int(sample["affordable_gear_count"]) == 0)
		result["gear_plus_paid_order_affordable_count"] += int(sample["gear_plus_paid_order_affordable"])
		result["paired_match_count"] += int(sample["paired_matches"])
		result["assembly_affordable_count"] += int(sample["assembly_from_purchased_pair_affordable"])
		result["refit_affordable_count"] += int(sample["refit_affordable"])
		result["support_stock_count"] += int(sample["support_stock_count"])
		if i < 3:
			result["examples"].append(sample)
	for key in distributions:
		result["price_distributions"][key] = quantiles(distributions[key])
	return result


static func _stage_row(sim: Sim) -> Dictionary:
	return {"stage": sim.wave, "cash_start": sim.player.materials, "stage_cash_cap": WaveDirector.cash_budget(sim.wave),
		"earned": 0, "interest": 0, "shop_wallet": 0, "remaining_wallet": 0, "debt": 0,
		"bought": 0, "refits": 0, "combines": 0, "evolutions": 0, "rerolls": 0, "orders": 0,
		"ability_uses": 0, "interactions": 0, "material_signal_total": 0, "peak_support": 0,
		"support_events": {}, "bosses": [], "actions": [], "completed": false,
		"hurt_events": [], "boss_hp_end": 0.0, "boss_max_hp": 0.0, "gear_end": [],
		"elapsed_sim_seconds": 0.0, "steps": 0, "hp_end": sim.player.hp, "scrap_issued": 0, "earnings_settled": false, "shelf": [],
		"four_gear_quote_total": 0, "all_current_gear_affordable": false}


static func _attach_metrics(sim: Sim, stages: Array[Dictionary]) -> void:
	sim.shop.shop_action_resolved.connect(func(result: ShopResult) -> void:
		if not result.ok or stages.is_empty():
			return
		var row := stages.back() as Dictionary
		var action := result.action
		row["actions"].append({"action": String(action), "cost": result.cost, "id": String(result.offer_id)})
		if action in [ShopResult.BUY, ShopResult.REPLACE]: row["bought"] += 1
		if action == ShopResult.UPGRADE: row["refits"] += 1
		if action == ShopResult.COMBINE: row["combines"] += 1
		if action == ShopResult.EVOLVE: row["evolutions"] += 1
		if action in [ShopResult.BUY, ShopResult.REPLACE_ORDER] and String(result.offer_id).begins_with("order_"): row["orders"] += 1)
	sim.boss_spawned.connect(func(enemy: EnemyState) -> void:
		if not stages.is_empty():
			stages.back()["bosses"].append(String(enemy.def.id)))
	sim.material_collected.connect(func(amount: int) -> void:
		if not stages.is_empty(): stages.back()["material_signal_total"] += amount)
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void:
		if not stages.is_empty():
			stages.back()["hurt_events"].append({"source": String(info.source), "effect": String(info.effect),
				"amount": info.amount, "lethal": info.lethal}))
	sim.support_event.connect(func(info: Dictionary) -> void:
		if stages.is_empty(): return
		var events: Dictionary = stages.back()["support_events"]
		var kind := String(info.get("kind", &""))
		events[kind] = int(events.get(kind, 0)) + 1)


static func _controls(sim: Sim, row: Dictionary) -> void:
	if sim.character_energy >= 100.0 and sim.character_cooldown <= 0.0 \
			and (sim.enemies.size() >= 4 or sim.player.hp < sim.player.max_hp() * 0.65):
		row["ability_uses"] += int(sim.activate_character_skill())
	var interaction := Expedition.interaction(sim)
	if interaction.is_empty() or not bool(interaction.get("available", false)):
		return
	var kind: StringName = interaction.get("kind", &"")
	if kind in [&"part", &"terminal", &"repair", &"rescue", &"negotiate"] \
			or (kind == &"recycler" and sim.player.hp < sim.player.max_hp() * 0.65 and sim.player.materials >= int(interaction.get("cost", 0)) + 10):
		row["interactions"] += int(sim.interact())


static func _boss_state(sim: Sim) -> Dictionary:
	var shards: Array[Dictionary] = []
	for enemy in sim.boss_shards:
		shards.append({"uid": enemy.uid, "id": String(enemy.def.id), "hp": enemy.hp,
			"max_hp": enemy.max_hp, "dead": enemy.dead, "distance_to_player": enemy.pos.distance_to(sim.player.pos)})
	return {"alive": sim.boss_alive_count(), "bodies": shards,
		"player_pos": [sim.player.pos.x, sim.player.pos.y]}


static func _loadout(sim: Sim) -> Array[Dictionary]:
	var loadout: Array[Dictionary] = []
	for index in sim.player.weapons.size():
		loadout.append({"id": String(sim.player.weapons[index].id), "grade": sim.player.level_at(index),
			"paid": sim.player.weapon_investments[index], "role": String(sim.player.weapons[index].role),
			"support_kind": String(sim.player.weapons[index].support_kind)})
	return loadout


static func _move_dir(sim: Sim, bot: Bot, combat_mode: StringName) -> Vector2:
	if combat_mode != &"telegraph_aware":
		return bot.move_dir(sim)
	var hazards: Array[Vector2] = []
	for enemy in sim.enemies:
		if not enemy.dead and enemy.def.is_boss and enemy.brain_state == &"warn":
			var target := enemy.attack_target
			var inside := sim.player.pos.distance_to(target) <= 155.0
			if enemy.def.id == &"collector":
				var axis := enemy.attack_direction.normalized()
				var lateral := absf((sim.player.pos - enemy.pos).cross(axis))
				inside = lateral < 80.0
			elif enemy.def.id == &"paradox":
				var offset := sim.player.pos - target
				inside = (absf(offset.x) < 75.0 and absf(offset.y) < 240.0) or (absf(offset.y) < 75.0 and absf(offset.x) < 240.0)
			if inside:
				hazards.append(target)
	for machine in sim.interactables:
		if machine.get("kind", &"") == &"press" and float(machine.get("warning", 0.0)) > 0.0 				and sim.player.pos.distance_to(machine["pos"]) < 150.0:
			hazards.append(machine["pos"])
	if hazards.is_empty():
		return bot.move_dir(sim)
	var best := Vector2.ZERO
	var best_score := -INF
	var reach := sim.player.stats.get_stat(Stats.MOVE_SPEED) * 0.45
	for index in 16:
		var direction := Vector2.from_angle(TAU * float(index) / 16.0)
		var future := WorldArena.move_body(sim.player.pos, direction * reach, PlayerState.RADIUS)
		var score := INF
		for target in hazards:
			score = minf(score, future.distance_to(target))
		for enemy in sim.enemies:
			if not enemy.dead and future.distance_to(enemy.pos) < enemy.radius + 36.0:
				score -= 100.0
		if score > best_score:
			best_score = score
			best = direction
	return best


static func _profitable_assembly(sim: Sim) -> bool:
	if sim.player.weapons.size() != Content.MAX_WEAPON_SLOTS:
		return false
	var current_dps := OfferCard.total_dps(sim.player)
	var best: Dictionary = {}
	var best_gain := 0.0
	for host in sim.player.weapons.size():
		for donor in sim.player.weapons.size():
			if host == donor:
				continue
			var combine := sim.shop.combine_quote(sim, host, donor)
			for refill in sim.shop.offers:
				if not refill.is_weapon() or refill.sold:
					continue
				var pairing: Offer
				var net := combine.cost
				if not combine.ok:
					if sim.player.level_at(host) >= WeaponDef.MAX_LEVEL:
						continue
					for candidate in sim.shop.offers:
						if candidate != refill and candidate.is_weapon() and not candidate.sold \
								and candidate.id() == sim.player.weapons[host].id \
								and candidate.weapon_level == sim.player.level_at(host):
							pairing = candidate
					if pairing == null:
						continue
					var replace := sim.shop.quote(ShopResult.REPLACE, sim, pairing, donor)
					if not replace.ok:
						continue
					net = replace.cost + Shop.combine_cost(sim.player.weapons[host], sim.player.level_at(host))
				var cost := net + refill.price
				if cost > sim.player.materials:
					continue
				var weapons := sim.player.weapons.duplicate()
				var levels := sim.player.weapon_levels.duplicate()
				levels[host] += 1
				weapons.remove_at(donor)
				levels.remove_at(donor)
				weapons.append(refill.weapon)
				levels.append(refill.weapon_level)
				var gain := OfferCard.list_dps(weapons, levels, sim.player.stats) - current_dps
				if gain <= current_dps * 0.02:
					continue
				var score := gain / float(maxi(1, cost))
				if score > best_gain:
					best_gain = score
					best = {"host": host, "donor": donor, "pairing": pairing, "refill": refill}
	if best.is_empty():
		return false
	var pairing: Offer = best["pairing"]
	if pairing != null and not sim.shop.apply(ShopResult.REPLACE, sim, pairing, int(best["donor"])).ok:
		return false
	if not sim.shop.combine_weapons(sim, int(best["host"]), int(best["donor"])).ok:
		return false
	return sim.shop.apply(ShopResult.BUY, sim, best["refill"]).ok


static func play(seed_value: int, role: StringName, policy: StringName, combat_mode: StringName = &"baseline") -> Dictionary:
	var sim := Sim.new(seed_value)
	Content.character(role).apply(sim)
	sim.daily_modifier = &""
	sim.start_run()
	var bot := Bot.new(&"balanced")
	var stages: Array[Dictionary] = []
	stages.append(_stage_row(sim))
	_attach_metrics(sim, stages)
	var started := Time.get_ticks_msec()
	var steps := 0
	var stage_steps := 0
	var status := "running"
	while sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP]:
		var row := stages.back() as Dictionary
		if sim.phase == Sim.Phase.SHOP:
			row["completed"] = true
			row["earnings_settled"] = true
			row["earned"] = sim.last_wave_earned
			row["interest"] = sim.last_interest
			row["shop_wallet"] = sim.player.materials
			for offer in sim.shop.offers:
				row["shelf"].append({"id": String(offer.id()), "price": offer.price, "grade": offer.weapon_level,
					"kind": "weapon" if offer.is_weapon() else ("order" if offer.is_contract() else "passive")})
				if not offer.is_contract(): row["four_gear_quote_total"] += offer.price
			row["all_current_gear_affordable"] = int(row["four_gear_quote_total"]) <= sim.player.materials
			row["scrap_issued"] = sim.expedition.get("cash_issued", 0)
			if policy == &"assembly":
				_profitable_assembly(sim)
			bot.shop(sim)
			row["rerolls"] = sim.shop.rerolls
			row["remaining_wallet"] = sim.player.materials
			row["gear_end"] = _loadout(sim)
			row["boss_state"] = _boss_state(sim)
			row["debt"] = sim.expedition.get("debt", 0)
			if not sim.can_start_wave():
				status = "shop_blocked"
				break
			sim.start_next_wave()
			stage_steps = 0
			stages.append(_stage_row(sim))
			continue
		if steps >= MAX_RUN_STEPS or stage_steps >= MAX_STAGE_STEPS:
			status = "step_limit"
			break
		if steps % 600 == 0 and Time.get_ticks_msec() - started > MAX_RUN_WALL_MS:
			status = "wall_limit"
			break
		if stage_steps % 12 == 0:
			_controls(sim, row)
		sim.step(DT, _move_dir(sim, bot, combat_mode))
		steps += 1
		stage_steps += 1
		row["steps"] = stage_steps
		row["elapsed_sim_seconds"] = sim.wave_time
		row["hp_end"] = sim.player.hp
		row["peak_support"] = maxi(int(row["peak_support"]), sim.support_units.size())
		if sim.boss != null:
			row["boss_hp_end"] = sim.boss.hp
			row["boss_max_hp"] = sim.boss.max_hp
	if sim.phase == Sim.Phase.WON:
		status = "won"
		stages.back()["completed"] = true
		stages.back()["earnings_settled"] = true
		stages.back()["earned"] = sim.last_wave_earned
		stages.back()["interest"] = sim.last_interest
	elif sim.phase == Sim.Phase.LOST:
		status = "lost"
	var final_row := stages.back() as Dictionary
	if not bool(final_row["completed"]):
		final_row["earned"] = maxi(0, sim.player.materials - int(final_row["cash_start"]))
	final_row["remaining_wallet"] = sim.player.materials
	final_row["gear_end"] = _loadout(sim)
	final_row["boss_state"] = _boss_state(sim)
	final_row["debt"] = sim.expedition.get("debt", 0)
	final_row["scrap_issued"] = sim.expedition.get("cash_issued", 0)
	var bosses: Array = []
	var combines := 0
	var refits := 0
	var bought := 0
	for row in stages:
		bosses.append_array(row["bosses"])
		combines += int(row["combines"])
		refits += int(row["refits"])
		bought += int(row["bought"])
	return {"seed": seed_value, "role": String(role), "policy": String(policy), "status": status,
		"combat_mode": String(combat_mode), "last_stage": sim.wave, "won": sim.phase == Sim.Phase.WON, "steps": steps,
		"death_source": String(sim.last_damage_source) if sim.phase == Sim.Phase.LOST else "",
		"wall_ms": Time.get_ticks_msec() - started, "bosses": bosses,
		"bought": bought, "refits": refits, "combines": combines,
		"wallet": sim.player.materials, "debt": sim.expedition.get("debt", 0),
		"final_weapons": _loadout(sim), "stages": stages, "final_support_count": sim.support_units.size()}


static func summarize_runs(runs: Array) -> Dictionary:
	var policies := {}
	for run: Dictionary in runs:
		var name: String = String(run["combat_mode"]) + "/" + String(run["policy"])
		if not policies.has(name):
			policies[name] = {"runs": 0, "won": 0, "lost": 0, "bounded_out": 0,
				"bought": 0, "refits": 0, "combines": 0, "last_stages": [],
				"shop_count": 0, "all_current_gear_affordable_shops": 0, "one_or_two_gear_buys_shops": 0, "zero_gear_buy_shops": 0}
		var summary: Dictionary = policies[name]
		summary["runs"] += 1
		summary["won"] += int(run["status"] == "won")
		summary["lost"] += int(run["status"] == "lost")
		summary["bounded_out"] += int(run["status"] not in ["won", "lost"])
		for key in ["bought", "refits", "combines"]: summary[key] += int(run[key])
		summary["last_stages"].append(run["last_stage"])
		for row: Dictionary in run["stages"]:
			if not bool(row["completed"]) or int(row["stage"]) >= WaveDirector.FINAL_WAVE:
				continue
			summary["shop_count"] += 1
			summary["all_current_gear_affordable_shops"] += int(row["all_current_gear_affordable"])
			summary["one_or_two_gear_buys_shops"] += int(int(row["bought"]) in [1, 2])
			summary["zero_gear_buy_shops"] += int(int(row["bought"]) == 0)
	return policies


func _write(path: String, report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write economy report: " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
