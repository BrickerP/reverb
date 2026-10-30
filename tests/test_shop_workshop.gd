extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _sim() -> Sim:
	var sim := Sim.new(90174)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 1000
	sim.shop.roll(sim)
	return sim


func _open(sim: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	return ui


func _take(sim: Sim, weapon: StringName, condition: float) -> EchoTake:
	var take := EchoTake.new()
	take.wave = 1
	take.condition = condition
	take.weapons.append(Content.weapon(weapon))
	take.levels.append(0)
	take.samples = PackedVector2Array([Vector2(200, 200), Vector2(400, 250), Vector2(450, 350)])
	sim.bank.add(take)
	return take


func test_combine_actual_slot_entry_requires_result_confirmation_and_undo(c: Check) -> void:
	var sim := _sim()
	sim.player.add_weapon(Content.weapon(sim.player.weapons[0].id))
	var before := ShopState.capture(sim).to_dict()
	var ui := _open(sim)
	ui.build_panel._slot_buttons[0].pressed.emit()
	c.ok(ui.workshop.visible, "slot enters workbench")
	ui.workshop.choice_buttons[1].pressed.emit()
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "host and donor choices only preview")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(sim.player.weapons.size(), 1, "confirmation consumes one donor body")
	c.eq(sim.player.level_at(0), 1, "host gains one level")
	c.ok(not ui.workshop.visible, "one primary decision returns to the shop")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "undo restores exact combined equipment and funds")
	ui.free()


func test_incompatible_combine_and_cancel_leave_inventory_unchanged(c: Check) -> void:
	var sim := _sim()
	sim.player.add_weapon(Content.weapon(&"orb"))
	var before := ShopState.capture(sim).to_dict()
	var ui := _open(sim)
	ui.build_panel._slot_buttons[0].pressed.emit()
	c.ok(ui.workshop.choice_buttons[1].disabled, "unmatched host has no combine action")
	ui.workshop.choice_buttons[1].pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "disabled combine cannot mutate even if signaled")
	ui.workshop.cancel_button.pressed.emit()
	c.ok(not ui.workshop.visible, "cancel returns to the same equipment view")
	c.ok(ui.build_panel._upgrade_buttons[0].has_focus(), "cancel restores the selected slot focus")
	ui.free()


func test_merge_preview_keeps_uid_and_host_route_until_confirmation(c: Check) -> void:
	var sim := _sim()
	var host := _take(sim, &"pistol", 50.0)
	_take(sim, &"orb", 80.0)
	var before := ShopState.capture(sim).to_dict()
	var next_uid := sim.bank.next_uid()
	var ui := _open(sim)
	ui.echo_panel.merge_button.pressed.emit()
	ui.workshop.choice_buttons[0].pressed.emit()
	ui.workshop.choice_buttons[0].pressed.emit()
	ui.workshop.choice_buttons[1].pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "choosing host donor and repair only previews")
	c.eq(sim.bank.next_uid(), next_uid, "preview allocates no UID")
	var previews := ui.workshop.find_children("*", "PathPreview", true, false)
	c.eq(previews.size(), 3, "result sheet draws host donor and result routes")
	c.eq((previews[0] as PathPreview)._points, (previews[2] as PathPreview)._points, "visible result route matches the host")
	c.ok((previews[1] as PathPreview).consumed, "donor body is visibly crossed out")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(sim.bank.takes.size(), 1, "merge consumes one donor")
	c.eq(sim.bank.takes[0].samples, host.samples, "result preserves exact host route")
	c.near(sim.bank.takes[0].condition, 90.0, 0.001, "repair trait uses half donor condition")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "merge undo restores bodies route UID and funds")
	ui.free()


func test_work_order_cards_buy_replace_confirm_and_undo(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var orders: Array[int] = []
	for index in sim.shop.offers.size():
		if sim.shop.offers[index].is_contract():
			orders.append(index)
	c.eq(orders.size(), 2, "goods contain exactly two orders")
	var before_buy := ShopState.capture(sim).to_dict()
	(ui.offers_box.get_child(orders[0]) as OfferCard).pressed.emit()
	c.ok(ui.workshop.visible, "initial order opens forecast and responsibility confirmation")
	c.eq(ShopState.capture(sim).to_dict(), before_buy, "reading initial terms changes no funds or dangers")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.ok(sim.active_contract != null, "confirmed order card purchases through BUY")
	var before_replace := ShopState.capture(sim).to_dict()
	(ui.offers_box.get_child(orders[1]) as OfferCard).pressed.emit()
	c.ok(ui.workshop.visible, "another order requires explicit replacement")
	c.eq(ShopState.capture(sim).to_dict(), before_replace, "opening replacement spends nothing")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.ok(sim.active_contract.kind != StringName(before_replace.active_order.kind), "confirmation changes next objective")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before_replace, "order undo restores objective and funds")
	c.ok(ui.reroll_button.text.contains(str(sim.shop.reroll_cost(sim.wave))) and ui.reroll_button.text.contains(str(sim.shop.next_reroll_cost(sim.wave))), "current and next reroll prices stay visible")
	ui.free()


func test_evolution_requires_explicit_branch_and_keeps_slot_selected(c: Check) -> void:
	var sim := _sim()
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	for i in 3:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.weapon_levels[1] = WeaponDef.MAX_LEVEL
	var before := ShopState.capture(sim).to_dict()
	var ui := _open(sim)
	ui.build_panel._upgrade_buttons[1].pressed.emit()
	c.eq(ui.workshop.choice_buttons.size(), 2, "both final forms are concrete choices")
	c.eq(ShopState.capture(sim).to_dict(), before, "branch chooser does not auto evolve")
	var target := sim.shop.evolution_choices(sim, 1)[1]
	var preview_text := ui.workshop.choice_buttons[1].text
	ui.workshop.choice_buttons[1].pressed.emit()
	c.eq(sim.player.level_at(1), WeaponDef.MAX_LEVEL, "evolution preserves the advertised maximum grade")
	c.ok(preview_text.contains(Loc.t("shop.take_dps", [int(round(OfferCard.total_dps(sim.player)))])), "branch preview equals actual evolved build DPS")
	c.eq(sim.player.weapons[1].id, target, "chosen branch replaces the selected slot")
	c.eq(ui.build_panel._selected, 1, "evolution preserves selected slot")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "evolution restores exact investment via undo")
	ui.free()


func test_main_preparation_entry_uses_goods_undo_and_real_departure(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.set_physics_process(false)
	main.new_run(91074, &"solo")
	var sim: Sim = main.sim
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 1000
	sim.shop.roll(sim)
	main._open_shop()
	var ui: ShopUi = main.shop_ui
	c.ok(ui.visible, "Main preparation entry opens the real shop")
	c.eq(ui.offers_box.get_child_count(), 6, "Main shows six actionable goods")
	var before := ShopState.capture(sim).to_dict()
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.ok(sim.shop.can_undo(), "real goods action creates transaction history")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "Main shop Undo restores the full transaction")
	ui.start_button.pressed.emit()
	c.eq(sim.phase, Sim.Phase.WAVE, "Main departure signal starts the next encounter")
	c.ok(not ui.visible, "departure closes the actual preparation screen")
	main._detach_presentation_session()
	main.free()


func test_native_small_canvas_has_six_slots_and_pages_without_forced_cleanup(c: Check) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	_root().add_child(viewport)
	var sim := _sim()
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"hydraulic_press"))
	sim.player.stats.add(Stats.ECHO_SLOTS, 6.0)
	for i in 8:
		_take(sim, &"pistol", 60.0)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	viewport.add_child(ui)
	ui.set_reduced_effects(true)
	ui.open(sim)
	c.eq(ui.build_panel._slot_buttons.size(), 6, "all six equipment slots stay in the core view")
	c.eq(ui.echo_panel.page_size, 1, "small native canvas pages copies explicitly")
	c.eq(ui.build_panel.find_children("*", "ScrollContainer", true, false).size(), 0, "equipment has no mandatory vertical scroll")
	c.eq(ui.echo_panel.find_children("*", "ScrollContainer", true, false).size(), 0, "copies have no mandatory nested scroll")
	c.ok(not ui.start_button.disabled, "capacity-eight bank requires no forced discard")
	c.ok((ui.get_child(1) as Control).get_combined_minimum_size().y <= 540.0, "native small canvas minimum height fits without scaling")
	viewport.free()


func test_graded_offer_preview_matches_actual_purchase(c: Check) -> void:
	var sim := _sim()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"pistol")
	offer.weapon_level = 2
	offer.price = 60
	sim.shop.offers[0] = offer
	var expected := OfferCard.dps_with_added(sim.player, offer.weapon, offer.weapon_level)
	var ui := _open(sim)
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(sim.player.level_at(sim.player.weapons.size() - 1), 2, "card purchase equips its quoted grade")
	c.near(OfferCard.total_dps(sim.player), expected, 0.001, "offer preview uses the actual weapon grade")
	ui.free()


func test_stale_purchase_release_after_session_close_is_inert(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var card := ui.offers_box.get_child(0) as OfferCard
	var before := ShopState.capture(sim).to_dict()
	ui.close_session()
	card.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "a queued old release cannot buy after close")
	c.ok(ui.sim == null and not ui.workshop.visible, "closed UI keeps no active transaction context")
	ui.free()


func test_support_offer_explains_utility_before_purchase(c: Check) -> void:
	var sim := _sim()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"paper_seed")
	offer.price = 20
	sim.shop.offers[0] = offer
	var ui := _open(sim)
	var card := ui.offers_box.get_child(0) as OfferCard
	var role_visible := false
	for label: Label in card.find_children("*", "Label", true, false):
		if label.text == Loc.t("role.production") + " · " + Loc.t("carrier.placement"):
			role_visible = true
	c.ok(role_visible, "zero-DPS production weapon explains its actual utility")
	c.ok(card.accessibility_description.contains(Loc.weapon_desc(offer.weapon.id)), "utility offer describes its real effect before buying")
	card.pressed.emit()
	c.eq(sim.player.weapons.back().id, &"paper_seed", "utility card still buys through the canonical transaction")
	ui.free()
