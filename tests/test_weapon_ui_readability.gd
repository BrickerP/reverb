extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _sim() -> Sim:
	var sim := Sim.new(8817)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.shop.roll(sim)
	sim.player.materials = 500
	return sim


func _open(sim: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.set_reduced_effects(true)
	ui.open(sim)
	return ui


func test_weapon_identity_and_effect_are_visible_without_hover_in_both_languages(c: Check) -> void:
	var language := Loc.lang
	for locale in ["en", "zh"]:
		Loc.lang = locale
		var sim := _sim()
		sim.player.add_weapon(Content.weapon(&"stapler"))
		var before := RunSnapshot.capture(sim)
		var ui := _open(sim)
		ui.build_panel._slot_buttons[1].pressed.emit()
		c.ok(not ui.workshop.visible, "selecting a weapon reads it in place")
		c.eq(ui.build_panel._selected, 1, "selection identifies the real slot")
		c.ok(ui.build_panel.detail_title.text.contains(Loc.weapon_name(&"stapler")), "full weapon name is persistent")
		c.ok(ui.build_panel.detail_title.text.contains(Loc.t("shop.level", [1])), "grade is explicitly labeled")
		c.eq(ui.build_panel.detail_behavior.text, Loc.weapon_desc(&"stapler"), "attack behavior is on the sheet, not only in a tooltip")
		c.ok(ui.build_panel.detail_combo.visible, "a pin weapon shows how to complete its combo")
		var name := ui.build_panel._cards[1].find_child("WeaponName", true, false) as Label
		c.eq(name.text, Loc.weapon_name(&"stapler"), "inventory chips carry real names")
		c.eq(RunSnapshot.capture(sim), before, "inspection does not mutate graph or either RNG")
		ui.free()
	Loc.lang = language


func test_selected_upgrade_quotes_the_result_and_undo_restores_the_exact_purchase(c: Check) -> void:
	var sim := _sim()
	sim.player.add_weapon(Content.weapon(&"rifle"))
	var ui := _open(sim)
	ui.build_panel._slot_buttons[1].pressed.emit()
	var before := ShopState.capture(sim).to_dict()
	var cost := Shop.upgrade_cost(sim.player.weapons[1], 0)
	c.eq(ui.build_panel.upgrade_button.text, Loc.t("shop.upgrade_materials", [2, cost]), "action says grade, cost and currency before spending")
	c.ok(ui.build_panel.detail_upgrade.text.contains(Loc.weapon_upgrade(sim.player.weapons[1], 0)), "upgrade result stays beside its action")
	ui.build_panel.upgrade_button.pressed.emit()
	c.eq(sim.player.level_at(0), 0, "upgrade never silently targets the first weapon")
	c.eq(sim.player.level_at(1), 1, "the inspected weapon upgrades")
	c.eq(sim.player.materials, int(before.materials) - cost, "the displayed quote is charged once")
	c.eq(ui.build_panel._selected, 1, "refresh preserves selection")
	c.ok(ui.build_panel.upgrade_button.has_focus(), "keyboard focus stays on the rebuilt action")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "Undo restores exact equipment and funds")
	ui.free()


func test_support_upgrade_previews_use_real_utility_and_do_not_invent_damage(c: Check) -> void:
	var language := Loc.lang
	for locale in ["en", "zh"]:
		Loc.lang = locale
		var sim := _sim()
		var before := RunSnapshot.capture(sim)
		for id: StringName in [&"repair_kit", &"paper_seed", &"guard_decoy"]:
			var w := Content.weapon(id)
			for level in WeaponDef.MAX_LEVEL:
				var first := SupportSystem.weapon_profile(w, level)
				var second := SupportSystem.weapon_profile(w, level + 1)
				var text := Loc.weapon_upgrade(w, level)
				c.ok(text.contains(Loc.number(first["hp"])) and text.contains(Loc.number(second["hp"])), "utility preview includes actual unit durability")
				c.ok(not text.contains(Loc.t("weapon.upgrade_hit", ["1", "1.8"])), "utility is never sold as a damage increase")
				if id == &"repair_kit":
					c.ok(text.contains(Loc.number(second["heal_hp"])) and text.contains(Loc.number(second["repair_condition"])), "repair result uses deployment's healing and condition values")
				elif id == &"paper_seed":
					c.ok(text.contains(Loc.number(second["shield"])) and text.contains(Loc.number(second["energy"])), "tree result uses actual shield and energy values")
		c.eq(RunSnapshot.capture(sim), before, "preview is pure")
	Loc.lang = language


func test_poor_and_maximum_grade_states_explain_the_boundary_visibly(c: Check) -> void:
	var sim := _sim()
	sim.player.materials = 0
	var ui := _open(sim)
	var cost := Shop.upgrade_cost(sim.player.weapons[0], 0)
	c.ok(ui.build_panel.upgrade_button.disabled, "unaffordable upgrade is disabled")
	c.ok(ui.build_panel.detail_reason.visible, "shortfall is visible without hover")
	c.eq(ui.build_panel.detail_reason.text, Loc.t("shop.need_materials", [cost]), "shortfall names the missing currency")
	var before := ShopState.capture(sim).to_dict()
	ui.build_panel.upgrade_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "a signaled disabled action cannot spend")
	sim.player.weapons[0] = Content.weapon(&"guard_decoy")
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	ui.refresh()
	c.ok(ui.build_panel.upgrade_button.disabled, "a maximum support with no evolution has no upgrade")
	c.eq(ui.build_panel.detail_upgrade.text, Loc.t("shop.max_level"), "maximum shows no fictional fifth level")
	ui.free()


func test_offers_show_attack_and_purchase_while_orders_use_words(c: Check) -> void:
	var sim := _sim()
	for w: WeaponDef in Content.weapons().values():
		var offer := Offer.new()
		offer.weapon = w
		offer.price = 20
		var card := OfferCard.new()
		card.setup(offer, sim)
		var behavior := card.find_child("AttackBehavior", true, false) as Label
		var action := card.find_child("PurchaseAction", true, false) as Label
		c.eq(behavior.text, Loc.weapon_desc(w.id), "every weapon has visible attack behavior")
		c.eq(behavior.max_lines_visible, -1, "the shop never hides the end of an attack explanation")
		c.eq(action.text, Loc.t("shop.buy_materials", [20]), "purchase says action and currency")
		c.eq((card.find_child("GradeMark", true, false) as Label).text, Loc.t("shop.level", [1]), "offered grade is labeled")
		card.free()
	var order := Offer.new()
	order.contract = AnomalyContract.create(AnomalyContract.REPAIR, 2)
	order.price = order.contract.deposit
	var card := OfferCard.new()
	card.setup(order, sim)
	c.ok(card.find_child("OrderObjective", true, false) != null, "orders have visible named objectives")
	card.free()


func test_small_equipment_pages_keep_both_inventories_reachable_without_mutation(c: Check) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	_root().add_child(viewport)
	var sim := _sim()
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	viewport.add_child(ui)
	ui.set_reduced_effects(true)
	ui.open(sim)
	var before := RunSnapshot.capture(sim)
	c.ok(ui.build_panel.visible and not ui.echo_panel.visible, "small shop starts on its readable weapon sheet")
	ui.echoes_button.pressed.emit()
	c.ok(not ui.build_panel.visible and ui.echo_panel.visible, "small windows keep a focused copy page")
	c.eq(ui.echo_panel.page_size, 3, "the full copy page shows three rows")
	c.ok(not ui.equipment_button.focus_next.is_empty(), "navigation reaches the other page")
	ui.equipment_button.pressed.emit()
	c.ok(ui.build_panel.visible and not ui.echo_panel.visible, "weapon page can be restored")
	c.eq(RunSnapshot.capture(sim), before, "navigation leaves the entire run unchanged")
	viewport.free()


func test_wide_inventory_is_an_overview_with_content_sized_papers(c: Check) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	_root().add_child(viewport)
	var sim := _sim()
	var take := EchoTake.new()
	take.weapons.append(Content.weapon(&"pistol"))
	sim.bank.add(take)
	var before := RunSnapshot.capture(sim)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	viewport.add_child(ui)
	ui.set_reduced_effects(true)
	ui.open(sim)
	c.ok(ui.build_panel.visible and ui.echo_panel.visible, "weapons and copies are visible together")
	c.ok(not ui.equipment_button.is_visible_in_tree(), "wide overview needs no category switch")
	c.ok(ui.build_panel.show_heading, "the weapon paper owns its section title")
	c.eq(ui.build_panel.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "weapon paper follows its actual content")
	c.eq(ui.echo_panel.size_flags_vertical, Control.SIZE_SHRINK_BEGIN, "copy paper follows its actual content")
	c.eq(RunSnapshot.capture(sim), before, "overview never changes the run")
	viewport.free()


func test_rebuilt_or_closed_upgrade_controls_cannot_spend_again(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var old_button := ui.build_panel.upgrade_button
	ui.refresh()
	var before := RunSnapshot.capture(sim)
	old_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "a queued pre-refresh action cannot buy another upgrade")
	var closing_button := ui.build_panel.upgrade_button
	ui.close_session()
	ui.open(_sim())
	before = RunSnapshot.capture(ui.sim)
	closing_button.pressed.emit()
	c.eq(RunSnapshot.capture(ui.sim), before, "a previous run's action cannot spend the new run's materials")
	ui.free()


func test_passive_effect_numbers_wrap_instead_of_truncating(c: Check) -> void:
	var sim := _sim()
	var offer := Offer.new()
	offer.item = Content.item(&"quick_trigger")
	offer.price = 24
	var card := OfferCard.new()
	card.setup(offer, sim)
	var effect := card.find_child("ItemEffect", true, false) as Label
	c.eq(effect.text, Loc.item_face(offer.item, sim), "the full actual before/after value is on the card")
	c.eq(effect.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "narrow cards wrap the numbers")
	c.ok(not effect.clip_text, "critical item values are never clipped")
	card.free()


func test_trade_in_keeps_grade_refund_and_confirmation_distinct(c: Check) -> void:
	var sim := _sim()
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	sim.player.weapon_investments[0] = 240
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 24
	sim.shop.offers[0] = offer
	var ui := _open(sim)
	var before := RunSnapshot.capture(sim)
	ui._begin_replace(offer)
	var refund := ui.build_panel._cards[0].find_child("TradeInValue", true, false) as Label
	c.eq(refund.text, Loc.t("shop.refund_materials", [Shop.resale_for(sim, 0)]), "trade-in has a named currency value")
	c.eq(refund.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "large refunds wrap inside a slot")
	c.ok(not ui.build_panel.upgrade_button.visible, "trade-in is a choice of slot, not a second purchase action")
	ui.build_panel._slot_buttons[0].pressed.emit()
	c.ok(ui.workshop.visible, "choosing a slot previews the net transaction")
	c.eq(RunSnapshot.capture(sim), before, "reading the replacement changes no resources")
	ui.workshop.cancel_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "cancelling preserves the complete original run")
	ui.free()


func test_new_weapon_opens_its_own_explanation_without_widening_a_slot(c: Check) -> void:
	var sim := _sim()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 24
	sim.shop.offers[0] = offer
	var ui := _open(sim)
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(ui.build_panel._selected, 1, "purchase immediately shows the installed weapon")
	c.ok(ui.build_panel.detail_title.text.contains(Loc.weapon_name(&"smg")), "purchase result explains the new tool")
	c.ok(ui.build_panel.detail_behavior.text.contains(Loc.weapon_desc(&"smg")), "new attack behavior is visible immediately")
	ui.undo_button.pressed.emit()
	c.eq(ui.build_panel.marked_slot, -1, "Undo clears the new-equipment cue")
	ui.free()
