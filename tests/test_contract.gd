extends RefCounted


func _shop_sim(materials: int = 100) -> Sim:
	var sim := Sim.new(731)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = materials
	sim.shop.offers.clear()
	return sim


func _order(sim: Sim, kind: StringName) -> Offer:
	var offer := Offer.new()
	offer.contract = AnomalyContract.create(kind, sim.wave + 1)
	offer.price = offer.contract.deposit
	sim.shop.offers.append(offer)
	return offer


func test_six_work_orders_have_exact_data_and_no_legacy_wagers(c: Check) -> void:
	for kind in AnomalyContract.KINDS:
		var order := AnomalyContract.create(kind, 6)
		c.ok(order != null, "each authored order can be created")
		c.eq(AnomalyContract.from_dict(order.to_dict()).to_dict(), order.to_dict(), "order serialization is exact")
		c.eq(order.id(), StringName("order_" + String(kind)), "order id is distinct from equipment")
		c.ok(order.target > 0 and order.deposit >= 0, "order has explicit objective and price")
	c.ok(AnomalyContract.create(&"clean", 6) == null, "old wager kinds are removed")
	c.ok(AnomalyContract.from_dict({"kind": "unknown"}) == null, "unknown order data is refused")


func test_buy_order_quotes_without_mutation_and_undoes_every_effect(c: Check) -> void:
	var sim := _shop_sim()
	var offer := _order(sim, AnomalyContract.SALVAGE)
	var before := ShopState.capture(sim).to_dict()
	var rng_state := sim.rng.state
	var quote := sim.shop.quote(ShopResult.BUY, sim, offer)
	c.ok(quote.ok, "order is ordinary purchasable stock")
	c.eq(quote.cost, offer.price, "order quote includes the full purchase cost")
	c.eq(ShopState.capture(sim).to_dict(), before, "quote is pure")
	c.ok(sim.shop.apply(ShopResult.BUY, sim, offer).ok, "order purchase commits")
	c.eq(sim.player.materials, 100 - offer.price, "purchase charges exactly once")
	c.ok(sim.active_contract == offer.contract and offer.contract.accepted and offer.sold, "sold offer and active order alias")
	c.eq(sim.contracts_accepted, 1, "order counter advances")
	c.eq(sim.expedition["mission"]["kind"], AnomalyContract.SALVAGE, "real expedition receives the purchased order")
	c.eq(sim.expedition["mission"]["state"], &"pending", "mission starts on departure")
	c.ok(not sim.shop.apply(ShopResult.BUY, sim, offer).ok, "same order cannot be charged twice")
	c.ok(sim.shop.undo(sim).ok, "purchase can be undone")
	c.eq(ShopState.capture(sim).to_dict(), before, "funds, accepted state, mission and counters restore atomically")
	c.eq(sim.rng.state, rng_state, "buy and undo do not reroll")


func test_item_then_order_cannot_recover_deposit_while_keeping_order(c: Check) -> void:
	var sim := _shop_sim()
	var item := Offer.new()
	item.item = Content.item(&"iron_heart")
	item.price = 20
	sim.shop.offers.append(item)
	var order := _order(sim, AnomalyContract.AUDIT)
	c.ok(sim.shop.apply(ShopResult.BUY, sim, item).ok, "equipment creates the first undo record")
	c.ok(sim.shop.apply(ShopResult.BUY, sim, order).ok, "work order creates its own undo record")
	c.eq(sim.shop._undo_stack.size(), 2, "order does not bypass transactional history")
	c.ok(sim.shop.undo(sim).ok, "first undo reverses the order")
	c.eq(sim.player.materials, 80, "only the order cost is restored first")
	c.ok(sim.active_contract == null and not sim.shop.offers[1].contract.accepted, "no free accepted order remains")
	c.eq(sim.player.item_count(&"iron_heart"), 1, "previous equipment transaction remains")
	c.ok(sim.shop.undo(sim).ok, "second undo reverses equipment")
	c.eq(sim.player.materials, 100, "all funds restored after both reversals")
	c.eq(sim.contracts_accepted, 0, "order analytics restore with economy")


func test_order_replacement_requires_explicit_quote_and_refunds_unconsumed_order(c: Check) -> void:
	var sim := _shop_sim()
	var salvage := _order(sim, AnomalyContract.SALVAGE)
	var rescue := _order(sim, AnomalyContract.RESCUE)
	c.ok(sim.shop.apply(ShopResult.BUY, sim, salvage).ok, "first order commits")
	var before := ShopState.capture(sim).to_dict()
	var blocked := sim.shop.quote(ShopResult.BUY, sim, rescue)
	c.ok(not blocked.ok and blocked.reason == &"order_active", "ordinary buy cannot silently replace a mission")
	var quote := sim.shop.quote(ShopResult.REPLACE_ORDER, sim, rescue)
	c.ok(quote.ok, "explicit order exchange quotes")
	c.eq(quote.cost, rescue.price - salvage.price, "exchange returns the entire unused order price")
	c.ok(sim.shop.apply(ShopResult.REPLACE_ORDER, sim, rescue).ok, "exchange commits")
	c.eq(sim.player.materials, 100 - rescue.price, "only the selected pending order remains paid")
	c.ok(not salvage.sold and not salvage.contract.accepted, "replaced order returns to stock")
	c.ok(sim.active_contract == rescue.contract, "new order replaces the active alias")
	c.ok(sim.shop.undo(sim).ok, "exchange undoes")
	c.eq(ShopState.capture(sim).to_dict(), before, "exchange restores exact former mission and funds")
	c.ok(sim.active_contract == sim.shop.offers[0].contract, "restored active order aliases the restored sold card")


func test_poor_and_out_of_phase_orders_never_change_state(c: Check) -> void:
	var sim := _shop_sim(0)
	var offer := _order(sim, AnomalyContract.RECRUIT)
	var before := ShopState.capture(sim).to_dict()
	var result := sim.shop.apply(ShopResult.BUY, sim, offer)
	c.ok(not result.ok and result.reason == &"poor", "cash required for a paid order")
	c.eq(ShopState.capture(sim).to_dict(), before, "failed purchase is atomic")
	sim.player.materials = 100
	sim.phase = Sim.Phase.WAVE
	c.ok(not sim.shop.apply(ShopResult.BUY, sim, offer).ok, "cannot rewrite mission during an encounter")
	c.ok(not sim.shop.can_undo(), "failed attempts add no history")


func test_credit_advance_and_debt_undo_together_and_cannot_be_reissued(c: Check) -> void:
	var sim := _shop_sim(0)
	var credit := _order(sim, AnomalyContract.CREDIT)
	var salvage := _order(sim, AnomalyContract.SALVAGE)
	var before := ShopState.capture(sim).to_dict()
	c.ok(sim.shop.apply(ShopResult.BUY, sim, credit).ok, "credit can be chosen with an empty wallet")
	c.eq(sim.player.materials, 30, "advance gives its explicit purchasing power")
	c.eq(sim.expedition["debt"], 40, "advance carries its full future liability")
	c.ok(sim.shop.undo(sim).ok, "credit can be undone")
	c.eq(ShopState.capture(sim).to_dict(), before, "undo cannot retain advance or debt")
	credit = sim.shop.offers[0]
	salvage = sim.shop.offers[1]
	c.ok(sim.shop.apply(ShopResult.BUY, sim, credit).ok, "credit can be selected again after a true reversal")
	c.ok(sim.shop.apply(ShopResult.REPLACE_ORDER, sim, salvage).ok, "credit mission may be consciously exchanged")
	var after_exchange := ShopState.capture(sim).to_dict()
	var repeat := sim.shop.apply(ShopResult.REPLACE_ORDER, sim, credit)
	c.ok(not repeat.ok and repeat.reason == &"debt", "switching orders cannot mint repeated advances against existing debt")
	c.eq(ShopState.capture(sim).to_dict(), after_exchange, "rejected repeated advance changes nothing")


func test_active_order_alias_survives_a_shop_snapshot_and_consumption(c: Check) -> void:
	var sim := _shop_sim()
	var offer := _order(sim, AnomalyContract.AUDIT)
	c.ok(sim.shop.apply(ShopResult.BUY, sim, offer).ok, "purchase for alias snapshot")
	var snapshot := ShopState.capture(sim)
	snapshot.restore(sim)
	c.ok(sim.active_contract == sim.shop.offers[0].contract, "active reference is the restored card object")
	c.ok(sim.active_contract.accepted, "accepted state survives restore")
	sim.shop.reroll(sim)
	var after_reroll := ShopState.capture(sim)
	after_reroll.restore(sim)
	c.ok(sim.active_contract != null and sim.active_contract.accepted, "consumed order survives independently when its card is rerolled away")
	c.eq(sim.active_contract.kind, AnomalyContract.AUDIT, "active order keeps exact kind")


func test_order_completion_delegates_to_actual_mission_progress(c: Check) -> void:
	var sim := _shop_sim()
	var offer := _order(sim, AnomalyContract.SALVAGE)
	sim.shop.apply(ShopResult.BUY, sim, offer)
	c.ok(not offer.contract.is_complete(sim), "paying alone never completes an order")
	sim.expedition["mission"]["progress"] = offer.contract.target
	c.ok(offer.contract.is_complete(sim), "authored mission progress completes matching order")
	sim.expedition["mission"]["kind"] = AnomalyContract.AUDIT
	c.ok(not offer.contract.is_complete(sim), "different mission cannot satisfy stale order")


func test_exchanging_a_consumed_held_order_never_restores_a_second_live_hold(c: Check) -> void:
	var sim := _shop_sim()
	var held_order := _order(sim, AnomalyContract.SALVAGE)
	var replacement := _order(sim, AnomalyContract.REPAIR)
	var item := Offer.new()
	item.item = Content.item(&"iron_heart")
	item.price = 14
	sim.shop.offers.append(item)
	c.ok(sim.shop.toggle_lock(sim, held_order), "first order is held")
	c.ok(sim.shop.apply(ShopResult.BUY, sim, held_order).ok, "held order is consumed")
	c.ok(not held_order.locked, "consumption clears the spent hold")
	c.ok(sim.shop.toggle_lock(sim, item), "another live quote becomes the sole hold")
	c.ok(sim.shop.apply(ShopResult.REPLACE_ORDER, sim, replacement).ok, "previous order returns to stock")
	var live_holds := 0
	for offer in sim.shop.offers:
		if offer.locked and not offer.sold:
			live_holds += 1
	c.eq(live_holds, 1, "returning an exchanged order cannot recreate an old hold")
	c.ok(sim.shop.locked_offer() == item, "the player's current hold remains authoritative")
	c.ok(sim.shop.undo(sim).ok, "exchange reverses without breaking the hold invariant")
	c.ok(sim.shop.locked_offer() == sim.shop.offers[2], "undo restores the current held item")


func test_paid_order_to_credit_exchange_refund_advance_and_liability_are_one_undo(c: Check) -> void:
	var sim := _shop_sim()
	var repair := _order(sim, AnomalyContract.REPAIR)
	var credit := _order(sim, AnomalyContract.CREDIT)
	c.ok(sim.shop.apply(ShopResult.BUY, sim, repair).ok, "paid order exists before choosing finance")
	var before := ShopState.capture(sim).to_dict()
	var quote := sim.shop.quote(ShopResult.REPLACE_ORDER, sim, credit)
	c.ok(quote.ok and quote.cost == -repair.price, "free credit order explicitly refunds the old unused order")
	c.ok(sim.shop.apply(ShopResult.REPLACE_ORDER, sim, credit).ok, "exchange commits as one transaction")
	c.eq(sim.player.materials, 130, "old payment returns once and the separate thirty advance arrives once")
	c.eq(sim.expedition["debt"], 40, "the financial power carries its advertised liability")
	c.eq(sim.contracts_accepted, 2, "exchange creates exactly one new accepted order")
	c.ok(sim.active_contract == credit.contract and credit.sold and not repair.sold, "new order and returned stock have consistent aliases")
	c.ok(sim.shop.undo(sim).ok, "undo restores the previous paid order")
	c.eq(ShopState.capture(sim).to_dict(), before, "refund, advance, debt, counters and accepted aliases reverse atomically")
