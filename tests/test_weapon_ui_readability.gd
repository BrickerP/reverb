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


func _open(sim: Sim, extent: Vector2i = Vector2i(1280, 720)) -> ShopUi:
	var viewport := SubViewport.new()
	viewport.size = extent
	_root().add_child(viewport)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	viewport.add_child(ui)
	ui.set_reduced_effects(true)
	ui.open(sim)
	return ui


func _release(ui: ShopUi) -> void:
	ui.get_parent().free()


func _take(sim: Sim, condition: float = 60.0) -> EchoTake:
	var take := EchoTake.new()
	take.wave = sim.bank.takes.size() + 1
	take.condition = condition
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.samples = PackedVector2Array([Vector2(100, 100), Vector2(200, 170), Vector2(300, 120)])
	sim.bank.add(take)
	return take


func test_primary_weapon_board_is_visual_and_hover_holds_the_prose(c: Check) -> void:
	var previous := Loc.lang
	for locale in ["en", "zh"]:
		Loc.lang = locale
		var sim := _sim()
		sim.player.add_weapon(Content.weapon(&"stapler"))
		var before := RunSnapshot.capture(sim)
		var ui := _open(sim)
		var tile := ui.build_panel._slot_buttons[1]
		var art := tile.find_child("WeaponArt", true, false) as TextureRect
		c.ok(art != null and art.texture != null, "the primary weapon is actual artwork")
		c.ok(art.custom_minimum_size.x >= 64, "weapon art has a primary visual footprint")
		for label: Label in ui.build_panel.find_children("*", "Label", true, false):
			c.ok(not label.text.contains(Loc.weapon_desc(&"stapler")), "attack prose is not on the primary board")
		c.ok(not ui.inspection.visible, "opening the shop does not open a text sheet")
		ui.inspection.pointer_enabled = true
		tile.size = Vector2(120, 80)
		tile.mouse_entered.emit()
		ui._step_hover(0.17, tile.get_global_rect().get_center())
		c.ok(ui.inspection.visible and not ui.inspection.pinned, "hover opens the secondary sheet")
		c.eq(ui.inspection.title_label.text, Loc.weapon_name(&"stapler"), "hover identifies the actual weapon")
		c.eq(ui.inspection.summary_label.text, Loc.weapon_desc(&"stapler"), "short behavior is available on hover")
		ui.inspection.rule_buttons[0].mouse_entered.emit()
		c.ok(ui.inspection.definition.visible, "hovering a rule opens the tertiary sheet")
		c.ok(ui.inspection.definition_body.text.contains(Loc.weapon_upgrade(Content.weapon(&"stapler"), 0)), "the tertiary sheet has the real upgrade result")
		c.eq(RunSnapshot.capture(sim), before, "all inspection layers preserve the graph and both RNGs")
		_release(ui)
	Loc.lang = previous


func test_selected_upgrade_quotes_the_real_cost_and_undo_restores_it(c: Check) -> void:
	var sim := _sim()
	sim.player.add_weapon(Content.weapon(&"rifle"))
	var ui := _open(sim)
	ui.build_panel._slot_buttons[1].pressed.emit()
	var before := ShopState.capture(sim).to_dict()
	var cost := Shop.upgrade_cost(sim.player.weapons[1], 0)
	c.eq(ui.build_panel.upgrade_button.text, Loc.t("shop.upgrade_materials", [2, cost]), "the primary action keeps an explicit price")
	ui.build_panel.upgrade_button.pressed.emit()
	c.eq(sim.player.level_at(0), 0, "upgrade never targets the wrong slot")
	c.eq(sim.player.level_at(1), 1, "selected weapon upgrades")
	c.eq(sim.player.materials, int(before.materials) - cost, "displayed cost is charged once")
	c.eq(ui.build_panel._selected, 1, "selection survives the rebuild")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "Undo restores exact equipment and funds")
	_release(ui)


func test_support_rules_use_actual_utility_in_both_languages(c: Check) -> void:
	var previous := Loc.lang
	for locale in ["en", "zh"]:
		Loc.lang = locale
		for id: StringName in [&"repair_kit", &"paper_seed", &"guard_decoy"]:
			var w := Content.weapon(id)
			for level in WeaponDef.MAX_LEVEL:
				var first := SupportSystem.weapon_profile(w, level)
				var next := SupportSystem.weapon_profile(w, level + 1)
				var text := Loc.weapon_upgrade(w, level)
				c.ok(text.contains(Loc.number(first["hp"])) and text.contains(Loc.number(next["hp"])), "support rules show actual body durability")
				if id == &"repair_kit":
					c.ok(text.contains(Loc.number(next["heal_hp"])) and text.contains(Loc.number(next["repair_condition"])), "repair rule uses real healing values")
				elif id == &"paper_seed":
					c.ok(text.contains(Loc.number(next["shield"])) and text.contains(Loc.number(next["energy"])), "tree rule uses real shield and energy values")
	Loc.lang = previous


func test_poor_and_maximum_grade_explain_the_boundary_in_inspection(c: Check) -> void:
	var sim := _sim()
	sim.player.materials = 0
	var ui := _open(sim)
	var cost := Shop.upgrade_cost(sim.player.weapons[0], 0)
	c.ok(ui.build_panel.upgrade_button.disabled, "unaffordable upgrade cannot be activated")
	ui._request_inspection(ui.build_panel.upgrade_button, true)
	c.ok(ui.inspection.facts_label.text.contains(Loc.t("shop.need_materials", [cost])), "secondary upgrade view explains the shortfall")
	var before := ShopState.capture(sim).to_dict()
	ui.build_panel.upgrade_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "disabled action cannot spend")
	sim.player.weapons[0] = Content.weapon(&"guard_decoy")
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	ui.refresh()
	c.ok(ui.build_panel.upgrade_button.disabled, "maximum support has no invented level five")
	c.eq(ui.build_panel.upgrade_button.text, Loc.t("shop.max_level"), "maximum is a short primary state")
	_release(ui)


func test_stock_primary_uses_art_name_level_and_price(c: Check) -> void:
	var sim := _sim()
	for w: WeaponDef in Content.weapons().values():
		var offer := Offer.new()
		offer.weapon = w
		offer.price = 20
		var card := OfferCard.new()
		card.setup(offer, sim)
		c.ok(card._art.custom_minimum_size.x >= 80, "stock merchandise is larger than a small text glyph")
		c.eq(card.find_child("AttackBehavior", true, false), null, "stock prose is progressively disclosed")
		c.eq((card.find_child("PurchaseAction", true, false) as Label).text, Loc.t("shop.buy_materials", [20]), "buy action retains its currency")
		c.ok(card.accessibility_description.contains(Loc.weapon_desc(w.id)), "assistive descriptions remain complete")
		card.free()


func test_echo_bank_is_paper_dolls_with_wear_and_hover_actions(c: Check) -> void:
	var sim := _sim()
	for condition in [15.0, 40.0, 60.0, 100.0, 30.0, 70.0, 85.0, 95.0]:
		_take(sim, condition)
	var before := RunSnapshot.capture(sim)
	var ui := _open(sim)
	c.eq(ui.echo_panel.copy_buttons.size(), 8, "all eight legal copies have visual tiles")
	c.eq(ui.echo_panel.page_next, null, "eight copies do not require a text-list pager")
	var tile := ui.echo_panel._identity_buttons[sim.bank.takes[0].uid] as Button
	var doll := tile.find_child("EchoDoll", true, false) as EchoPortrait
	c.ok(doll != null and doll._texture != null, "Echo has the game's actual paper character")
	c.near(doll.condition, 0.15, 0.0001, "visual wear uses the real condition")
	c.eq(doll._weapons.size(), 1, "copy visibly carries its recorded weapon")
	for label: Label in ui.echo_panel.find_children("*", "Label", true, false):
		c.ok(not label.text.contains("DPS"), "primary Echo cards have no DPS prose")
	tile.pressed.emit()
	c.ok(ui.inspection.pinned, "a copy click pins its contextual sheet")
	c.eq(ui.inspection.action_buttons.size(), 2, "repair and discard belong to the contextual layer")
	c.ok(ui.inspection.facts_label.text.contains("15%"), "secondary view provides precise condition")
	c.eq(RunSnapshot.capture(sim), before, "visual inspection does not mutate the copy")
	_release(ui)


func test_contextual_repair_and_discard_use_canonical_transactions_and_undo(c: Check) -> void:
	var sim := _sim()
	var take := _take(sim, 30)
	var ui := _open(sim)
	var before := ShopState.capture(sim).to_dict()
	(ui.echo_panel._identity_buttons[take.uid] as Button).pressed.emit()
	ui.inspection.action_buttons[0].pressed.emit()
	c.near(take.condition, 70, 0.0001, "context repair restores actual condition")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "repair Undo is exact")
	take = sim.bank.takes[0]
	(ui.echo_panel._identity_buttons[take.uid] as Button).pressed.emit()
	ui.inspection.action_buttons[1].pressed.emit()
	c.eq(sim.bank.takes.size(), 0, "context discard removes exactly that copy")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before, "discard Undo is exact")
	_release(ui)


func test_stale_context_buttons_cannot_act_on_a_new_copy(c: Check) -> void:
	var sim := _sim()
	var take := _take(sim, 30)
	var second := _take(sim, 40)
	var ui := _open(sim)
	(ui.echo_panel._identity_buttons[take.uid] as Button).pressed.emit()
	var old := ui.inspection.action_buttons[0]
	ui.inspection.close_inspection()
	(ui.echo_panel._identity_buttons[second.uid] as Button).pressed.emit()
	var before := RunSnapshot.capture(sim)
	old.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "old popup action cannot target the new context")
	_release(ui)


func test_small_pages_and_wide_overview_preserve_the_entire_run(c: Check) -> void:
	for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
		var sim := _sim()
		for i in 8:
			_take(sim)
		var before := RunSnapshot.capture(sim)
		var ui := _open(sim, extent)
		c.eq(ui.echo_panel.page_size, 8, "visual bank uses a bounded eight-card page")
		if extent.x == 1280:
			c.ok(ui.build_panel.visible and ui.echo_panel.visible, "wide board shows equipment and copies")
		else:
			ui.echoes_button.pressed.emit()
			c.ok(ui.echo_panel.visible and not ui.build_panel.visible, "small window has a dedicated visual bank")
			ui.equipment_button.pressed.emit()
			c.ok(ui.build_panel.visible, "small weapon board remains reachable")
		c.eq(RunSnapshot.capture(sim), before, "navigation preserves data and both RNGs")
		_release(ui)


func test_trade_in_keeps_refund_currency_and_confirmation(c: Check) -> void:
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
	c.eq(refund.text, Loc.t("shop.refund_materials", [Shop.resale_for(sim, 0)]), "trade-in shows its actual refund")
	c.ok(not ui.build_panel.upgrade_button.visible, "trade-in is not an upgrade action")
	ui.build_panel._slot_buttons[0].pressed.emit()
	c.ok(ui.workshop.visible, "slot choice previews the net transaction")
	c.eq(RunSnapshot.capture(sim), before, "preview changes no resources")
	ui.workshop.cancel_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "cancellation preserves the run")
	_release(ui)


func test_new_weapon_is_selected_and_old_upgrade_controls_are_inert(c: Check) -> void:
	var sim := _sim()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 24
	sim.shop.offers[0] = offer
	var ui := _open(sim)
	var old := ui.build_panel.upgrade_button
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(ui.build_panel._selected, 1, "new merchandise is selected visually")
	var before := RunSnapshot.capture(sim)
	old.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "a pre-rebuild upgrade cannot spend again")
	ui.undo_button.pressed.emit()
	c.eq(ui.build_panel.marked_slot, -1, "Undo clears the purchase cue")
	_release(ui)


func test_inspection_reopens_after_leaving_and_nested_rules_collapse(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var source := ui.build_panel._slot_buttons[0]
	source.pressed.emit()
	ui.inspection.rule_buttons[0].focus_entered.emit()
	c.ok(ui.inspection.definition.visible, "nested rule can be revealed")
	ui.inspection.focus_enabled = false
	ui.inspection.details_button.grab_focus()
	ui.inspection._process(0.3)
	c.ok(not ui.inspection.definition.visible and ui.inspection.pinned, "leaving a rule collapses only the third layer")
	ui.inspection.close_inspection()
	c.ok(not ui.inspection.visible, "close returns to the visual primary layer")
	source.focus_exited.emit()
	ui.inspection.focus_enabled = true
	source.focus_entered.emit()
	c.ok(ui.inspection.visible, "returning to a source can inspect it again")
	_release(ui)


func test_merge_inspection_cannot_discard_its_pending_participants(c: Check) -> void:
	var sim := _sim()
	_take(sim, 30)
	_take(sim, 60)
	var ui := _open(sim)
	ui.echo_panel.merge_button.pressed.emit()
	var before := RunSnapshot.capture(sim)
	ui._request_inspection(ui.echo_panel.copy_buttons[0], true)
	c.eq(ui.inspection.action_buttons.size(), 0, "merge inspection has no competing repair or discard transaction")
	c.eq(RunSnapshot.capture(sim), before, "opening merge inspection preserves both participants")
	_release(ui)


func test_shop_card_has_one_grouped_price_action_and_no_detached_tag(c: Check) -> void:
	var sim := _sim()
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	var ui := _open(sim)
	var card := ui.offers_box.get_child(0) as OfferCard
	c.ok(card.find_child("MerchandiseRow", true, false) is HBoxContainer, "art and information form one horizontal reading line")
	var group := card.find_child("MerchandiseInfo", true, false)
	c.ok(group.is_ancestor_of(card.price_tag), "price belongs to the identity group")
	c.eq(card.find_children("PurchaseAction", "", true, false).size(), 1, "each card has one price/action presentation")
	_release(ui)


func test_equipment_global_actions_and_drop_hint_are_converged(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	c.ok(not ui.build_panel._drop_label.visible, "drop instructions are absent until dragging")
	ui.build_panel.show_item_drop(true)
	c.ok(ui.build_panel._drop_label.visible, "dragging reveals the real item drop target")
	ui.build_panel.show_item_drop(false)
	c.ok(not ui.build_panel._drop_label.visible, "drop guidance folds away again")
	ui.build_panel.loadout_button.pressed.emit()
	c.eq(ui.workshop.choice_buttons.size(), 2, "one loadout entry owns global stats and passives")
	ui.workshop.cancel_button.pressed.emit()
	ui.build_panel._slot_buttons[0].pressed.emit()
	ui.inspection.details_button.pressed.emit()
	c.eq(ui.workshop.choice_buttons.size(), 4, "weapon context owns only upgrade, combine, evolve and sell")
	_release(ui)
