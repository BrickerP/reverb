extends RefCounted


func _shop_sim(materials: int = 100) -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = materials
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.cooldowns.clear()
	s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.add_weapon(Content.weapon(&"smg"))
	s.player.weapon_levels[1] = 2
	return s


func test_sell_quotes_and_refunds_the_full_resale(c: Check) -> void:
	var s := _shop_sim()
	var before := ShopState.capture(s)
	var w := s.player.weapons[1]
	var refund := Shop.resale_total(w, s.player.level_at(1))
	var quote := s.shop.quote(ShopResult.SELL, s, null, 1)
	c.ok(quote.ok, "selling a second weapon quotes")
	c.eq(quote.cost, -refund, "the quote is a negative cash flow")
	c.ok(ShopState.capture(s).to_dict() == before.to_dict(), "quote leaves state unchanged")
	var changes: Array[WeaponChangeInfo] = []
	s.weapon_changed.connect(func(info: WeaponChangeInfo) -> void: changes.append(info))
	var result := s.shop.apply(ShopResult.SELL, s, null, 1)
	c.ok(result.ok, "sell applies")
	c.eq(s.player.weapons.size(), 1, "one weapon remains")
	c.eq(s.player.materials, 100 + refund, "the refund lands in materials")
	c.eq(changes.size(), 1, "sell emits one weapon change")
	c.eq(changes[0].index, 1, "the removed slot is reported")
	c.eq(changes[0].before_id, &"smg", "the sold id is reported")
	c.eq(changes[0].after_id, &"", "the slot is now empty")
	c.eq(changes[0].reason, ShopResult.SELL, "the reason is sell")
	c.eq(s.player.weapon_levels.size(), 1, "levels stay aligned")
	c.eq(s.player.cooldowns.size(), 1, "cooldowns stay aligned")


func test_sell_undo_restores_the_exact_weapon(c: Check) -> void:
	var s := _shop_sim()
	var w := s.player.weapons[1]
	var level := s.player.level_at(1)
	var changes: Array[WeaponChangeInfo] = []
	s.weapon_changed.connect(func(info: WeaponChangeInfo) -> void: changes.append(info))
	c.ok(s.shop.apply(ShopResult.SELL, s, null, 1).ok, "sell for undo")
	var back := s.shop.undo(s)
	c.ok(back.ok, "undo succeeds")
	c.eq(s.player.weapons.size(), 2, "weapon restored")
	c.eq(s.player.weapons[1], w, "the same weapon definition is restored")
	c.eq(s.player.weapon_levels[1], level, "the upgrade level is restored")
	c.eq(s.player.materials, 100, "materials restored")
	c.eq(changes.size(), 2, "sell and undo each emit one event")
	c.eq(changes[1].index, 1, "undo reports the restored slot")
	c.eq(changes[1].before_id, &"", "undo starts from empty")
	c.eq(changes[1].after_id, &"smg", "undo restores the id")
	c.eq(changes[1].reason, ShopResult.UNDO, "undo reason")


func test_last_weapon_cannot_be_sold(c: Check) -> void:
	var s := _shop_sim()
	c.ok(s.shop.apply(ShopResult.SELL, s, null, 0).ok, "sell down to one weapon")
	var quote := s.shop.quote(ShopResult.SELL, s, null, 0)
	c.ok(not quote.ok, "the last weapon cannot be sold")
	c.eq(quote.reason, &"last", "the reason names the last weapon")
	var before := ShopState.capture(s)
	c.ok(not s.shop.apply(ShopResult.SELL, s, null, 0).ok, "apply refuses the last weapon")
	c.ok(ShopState.capture(s).to_dict() == before.to_dict(), "failed sell leaves state unchanged")
	c.eq(s.shop._undo_stack.size(), 1, "the failed sell adds no snapshot")
