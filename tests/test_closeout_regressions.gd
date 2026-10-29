extends RefCounted


func test_credit_debt_does_not_remove_real_work_order_alternatives(c: Check) -> void:
	for seed_value in 32:
		var sim := Sim.new(seed_value)
		sim.start_run()
		sim.phase = Sim.Phase.SHOP
		sim.player.materials = 1000
		sim.expedition["debt"] = 40
		sim.shop.roll(sim)
		var kinds := {}
		for offer: Offer in sim.shop.offers:
			if not offer.is_contract():
				continue
			c.ok(offer.contract.kind != AnomalyContract.CREDIT, "existing credit does not fill a guaranteed slot with blocked stock")
			c.ok(sim.shop.can_buy(sim, offer), "both work-order alternatives have real purchasable paths")
			kinds[offer.contract.kind] = true
		c.eq(kinds.size(), 2, "two distinct eligible work orders remain available")


func test_assembly_preserves_most_invested_firepower_and_opens_a_slot(c: Check) -> void:
	for level in WeaponDef.MAX_LEVEL:
		var sim := Sim.new(1230 + level)
		sim.start_run()
		sim.phase = Sim.Phase.SHOP
		sim.player.materials = 1000
		sim.player.weapons.clear()
		sim.player.weapon_levels.clear()
		sim.player.weapon_investments.clear()
		sim.player.cooldowns.clear()
		var weapon := Content.weapon(&"pistol")
		for _copy in 2:
			sim.player.add_weapon(weapon)
			sim.player.weapon_levels[-1] = level
			sim.player.weapon_investments[-1] = 50
		var old_damage := weapon.level_dps(level) * 2.0
		c.ok(sim.shop.combine_weapons(sim, 0, 1).ok, "same-grade assembly actually commits")
		c.eq(sim.player.weapons.size(), 1, "the donor slot becomes available for a new build choice")
		var retained := weapon.level_dps(sim.player.level_at(0)) / old_damage
		c.ok(retained >= 0.85 and retained <= 1.0, "assembly keeps85-100 percent of the two donors' firepower")
		c.ok(sim.shop.undo(sim).ok, "assembly remains an exact transaction")
		c.eq(sim.player.weapons.size(), 2, "undo restores both actual slots")


func test_fixed_hud_leaves_the_entire_camera_battlefield_visible(c: Check) -> void:
	var hud := Hud.new()
	var rect: Rect2 = hud.retirement_hint_profile().rect
	c.ok(not rect.intersects(WorldArena.VIEWPORT), "selected-copy instructions cannot cover a mission target or enemy")
	c.ok(rect.position.y >= WorldArena.VIEWPORT.end.y and rect.end.y <= 720.0, "readable hints fit the permanent HUD band")
	c.eq(WorldArena.BOUNDS.size, Vector2(2400, 1200), "world remains a large arena")
	c.eq(WorldArena.VIEWPORT.size, Vector2(1200, 600), "larger world preserves the original visible field rather than zooming out")
	hud.free()
