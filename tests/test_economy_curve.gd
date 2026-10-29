extends RefCounted

const Probe := preload("res://tools/expedition_balance_probe.gd")


func test_stage_budgets_leave_real_choices_without_funding_the_entire_equipment_shelf(c: Check) -> void:
	for stage in [1, 5, 10]:
		var grade := 0 if stage == 1 else (1 if stage == 5 else 2)
		for seed_value in [11, 29, 47, 83, 101, 149, 211, 311]:
			var sample := Probe.funding_sample(stage, seed_value, grade)
			c.eq(sample["wallet"], WaveDirector.cash_budget(stage) + Probe.MARKET_RESERVE, "budget envelope never uses a fixture rich wallet")
			c.ok(int(sample["affordable_gear_count"]) > 0, "ordinary income envelope can afford useful goods")
			c.ok(not sample["all_four_gear_affordable"], "one encounter cannot fund all four equipment offers")
			c.ok(sample["gear_plus_paid_order_affordable"], "a gear purchase and one paid order fit the normal budget")
			c.ok(sample["paired_matches"], "same-grade donors are genuinely available at the modeled progression point")
			c.ok(sample["assembly_from_purchased_pair_affordable"], "buying and assembling the offered donor fits the budget")
			c.ok(int(sample["cash_refit_cost"]) > int(sample["paired_plus_combine_cost"]), "deterministic refit pays for avoiding a donor trade")


func test_merge_curve_preserves_most_two_body_firepower_while_freeing_one_slot(c: Check) -> void:
	var weapon := Content.weapon(&"pistol")
	for grade in WeaponDef.MAX_LEVEL:
		var retained := weapon.level_dps(grade + 1) / (2.0 * weapon.level_dps(grade))
		c.ok(retained >= 0.85 and retained <= 1.0, "assembly exchanges limited current firepower for a free weapon slot")
		c.ok(weapon.level_dps(grade + 1) > weapon.level_dps(grade), "the surviving host gains meaningful personal firepower")


func test_evolution_retains_max_grade_and_branch_identity_without_nominal_refund_inflation(c: Check) -> void:
	for base: WeaponDef in Content.weapons().values():
		for target: StringName in base.evolution_options:
			var sim := Sim.new(71)
			sim.start_run()
			sim.phase = Sim.Phase.SHOP
			sim.player.materials = WaveDirector.cash_budget(10) + Probe.MARKET_RESERVE
			sim.player.weapons.clear()
			sim.player.weapon_levels.clear()
			sim.player.weapon_investments.clear()
			sim.player.cooldowns.clear()
			for _i in 3: sim.player.add_weapon(base)
			sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
			var before_power := base.level_dps(WeaponDef.MAX_LEVEL)
			var before_money := sim.player.materials
			var paid_before := sim.player.weapon_investments[0]
			var result := sim.shop.evolve_choice(sim, 0, target)
			c.ok(result.ok, "%s to %s fits an honest late-stage budget" % [base.id, target])
			c.eq(sim.player.level_at(0), WeaponDef.MAX_LEVEL, "branch transformation never discards assembled grade")
			c.eq(sim.player.weapons[0].id, target, "player receives the chosen canonical branch")
			c.eq(sim.player.weapons[0].level_mult(sim.player.level_at(0)), Content.weapon(target).level_mult(WeaponDef.MAX_LEVEL), "branch DPS uses actual maximum-grade multiplier")
			c.eq(sim.player.materials, before_money - result.cost, "evolution spends its stated price")
			c.eq(sim.player.weapon_investments[0], paid_before + result.cost, "only the actual branch fee enters the investment ledger")
			var after_power := sim.player.weapons[0].level_dps(sim.player.level_at(0))
			c.ok(after_power >= before_power or sim.player.weapons[0].role in [&"control", &"support", &"utility"],
					"%s to %s lower raw DPS must explicitly identify utility role" % [base.id, target])


func test_each_role_keeps_affordable_stock_under_the_same_cash_envelope(c: Check) -> void:
	for stage in [1, 5, 10]:
		var grade := 0 if stage == 1 else (1 if stage == 5 else 2)
		for role: StringName in Content.characters():
			for seed_value in [11, 29, 47, 83, 101, 149, 211, 311]:
				var sample := Probe.funding_sample(stage, seed_value, grade, role)
				c.ok(int(sample["affordable_gear_count"]) > 0, "%s keeps an affordable equipment option" % role)
				c.ok(not sample["all_four_gear_affordable"], "%s cannot buy all equipment from one capped encounter" % role)
				c.ok(sample["paired_matches"], "%s can see its actual matching grade regardless of affordability" % role)
