extends RefCounted


func _shop_sim(materials: int = 100) -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = materials
	s.shop.offers.clear()
	return s


func _weapon_offer(s: Sim, id: StringName, price: int) -> Offer:
	var o := Offer.new()
	o.weapon = Content.weapon(id)
	o.price = price
	s.shop.offers.append(o)
	return o


func _item_offer(s: Sim, id: StringName, price: int) -> Offer:
	var o := Offer.new()
	o.item = Content.item(id)
	o.price = price
	s.shop.offers.append(o)
	return o


func test_two_step_undo(c: Check) -> void:
	var s := _shop_sim(100)
	var offer := _weapon_offer(s, &"smg", 20)
	c.ok(s.shop.apply(ShopResult.BUY, s, offer).ok, "buy first")
	c.eq(s.player.weapons.size(), 2, "second weapon present")
	c.ok(s.shop.apply(ShopResult.UPGRADE, s, null, 1).ok, "upgrade second weapon")
	c.eq(s.player.level_at(1), 1, "second weapon upgraded")
	c.eq(s.shop._undo_stack.size(), 2, "two snapshots")
	s.shop.undo(s)
	c.eq(s.player.level_at(1), 0, "first undo removes upgrade")
	c.eq(s.player.weapons.size(), 2, "bought weapon still present")
	s.shop.undo(s)
	c.eq(s.player.weapons.size(), 1, "second undo removes purchase")
	c.eq(s.player.materials, 100, "materials fully restored")
	c.ok(not s.shop.offers[0].sold, "offer restored")
	c.ok(not s.shop.can_undo(), "history empty")


func test_weapon_change_events(c: Check) -> void:
	var s := _shop_sim(100)
	var offer := _weapon_offer(s, &"smg", 20)
	var changes: Array[WeaponChangeInfo] = []
	s.weapon_changed.connect(func(info: WeaponChangeInfo) -> void: changes.append(info))
	c.ok(s.shop.apply(ShopResult.BUY, s, offer).ok, "buy for event")
	c.eq(changes.size(), 1, "purchase emits weapon change")
	c.eq(changes[0].after_id, &"smg", "new weapon id")
	c.eq(changes[0].reason, ShopResult.BUY, "purchase reason")
	s.shop.undo(s)
	c.eq(changes.size(), 2, "undo emits weapon change")
	c.eq(changes[1].index, 1, "undo removes the bought slot")
	c.eq(changes[1].before_id, &"smg", "undo before id")
	c.eq(changes[1].after_id, &"", "undo clears the slot")
	c.eq(changes[1].reason, ShopResult.UNDO, "undo reason")


func test_quote_does_not_mutate_state(c: Check) -> void:
	var s := _shop_sim(100)
	var offer := _weapon_offer(s, &"smg", 20)
	var before := ShopState.capture(s)
	var quote := s.shop.quote(ShopResult.BUY, s, offer)
	c.ok(quote.ok, "affordable quote succeeds")
	c.eq(quote.cost, 20, "quote reports price")
	c.eq(quote.offer_id, &"smg", "quote identifies offer")
	var after := ShopState.capture(s)
	c.eq(after.materials, before.materials, "quote leaves materials")
	c.eq(after.weapons.size(), before.weapons.size(), "quote leaves weapons")
	c.ok(not offer.sold, "quote leaves offer unsold")


func test_buy_apply_and_undo(c: Check) -> void:
	var s := _shop_sim(100)
	var offer := _weapon_offer(s, &"smg", 20)
	var results: Array[ShopResult] = []
	s.shop.shop_action_resolved.connect(func(r: ShopResult) -> void: results.append(r))
	var result := s.shop.apply(ShopResult.BUY, s, offer)
	c.ok(result.ok, "buy applies")
	c.eq(s.player.weapons.size(), 2, "weapon added")
	c.eq(s.player.materials, 80, "materials spent")
	c.ok(offer.sold, "offer sold")
	c.ok(s.shop.can_undo(), "history exists")
	var back := s.shop.undo(s)
	c.ok(back.ok, "undo succeeds")
	c.eq(s.player.weapons.size(), 1, "weapon removed")
	c.eq(s.player.materials, 100, "materials restored")
	c.ok(not s.shop.offers[0].sold, "sale restored")
	c.ok(not s.shop.can_undo(), "history empty")
	c.eq(results.size(), 2, "resolve events emitted for apply and undo")
	c.eq(results[0].action, ShopResult.BUY, "apply event action")
	c.eq(results[1].action, ShopResult.UNDO, "undo event action")


func test_upgrade_and_evolution_undo(c: Check) -> void:
	var s := _shop_sim(500)
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.cooldowns.clear()
	for i in 3:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.shop.offers.clear()
	var upgrade := s.shop.apply(ShopResult.UPGRADE, s, null, 0)
	c.ok(upgrade.ok, "upgrade applies")
	c.eq(s.player.level_at(0), 1, "level moved")
	s.shop.undo(s)
	c.eq(s.player.level_at(0), 0, "upgrade undo restores level")

	s.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	var evolve := s.shop.apply(ShopResult.EVOLVE, s, null, 0)
	c.ok(evolve.ok, "evolution applies")
	c.eq(s.player.weapons[0].id, &"twin_fangs", "evolved weapon")
	s.shop.undo(s)
	c.eq(s.player.weapons[0].id, &"pistol", "evolution undo restores weapon")
	c.eq(s.player.level_at(0), WeaponDef.MAX_LEVEL, "evolution undo restores level")


func test_replace_and_failed_action(c: Check) -> void:
	var s := _shop_sim(100)
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.cooldowns.clear()
	for i in Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var offer := _weapon_offer(s, &"smg", 20)
	var before := ShopState.capture(s)
	var result := s.shop.apply(ShopResult.REPLACE, s, offer, 0)
	c.ok(result.ok, "replace applies")
	c.eq(s.player.weapons[0].id, &"smg", "slot replaced")
	s.shop.undo(s)
	c.eq(s.player.weapons[0].id, &"pistol", "replace undo restores weapon")
	c.eq(s.player.materials, before.materials, "replace undo restores materials")

	s.player.materials = 0
	var failed := s.shop.apply(ShopResult.UPGRADE, s, null, 0)
	c.ok(not failed.ok, "failed action refuses")
	c.eq(failed.reason, &"poor", "failure reason")
	c.ok(not s.shop.can_undo(), "failure does not add history")


func test_reroll_and_wave_start_lock_history(c: Check) -> void:
	var s := _shop_sim(200)
	var offer := _weapon_offer(s, &"smg", 20)
	c.ok(s.shop.apply(ShopResult.BUY, s, offer).ok, "buy creates history")
	c.ok(s.shop.apply(ShopResult.REROLL, s).ok, "reroll succeeds")
	c.ok(not s.shop.can_undo(), "reroll locks history")

	var second_offer := _weapon_offer(s, &"shotgun", 10)
	c.ok(s.shop.apply(ShopResult.BUY, s, second_offer).ok, "new batch creates history")
	s.start_next_wave()
	c.ok(not s.shop.can_undo(), "wave start locks history")


func test_undo_does_not_advance_rng(c: Check) -> void:
	var s := _shop_sim(100)
	var offer := _weapon_offer(s, &"smg", 20)
	var before := s.rng.state
	c.ok(s.shop.apply(ShopResult.BUY, s, offer).ok, "buy applies")
	s.shop.undo(s)
	c.eq(s.rng.state, before, "undo does not consume randomness")


func test_undo_without_history_is_safe(c: Check) -> void:
	var s := _shop_sim(100)
	var result := s.shop.undo(s)
	c.ok(not result.ok, "nothing to undo")
	c.eq(result.reason, &"empty", "empty history reason")
