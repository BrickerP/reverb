extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _shop_sim(materials: int = 300) -> Sim:
	var s := Sim.new(701)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = materials
	s.shop.offers.clear()
	return s


func _weapon_offer(s: Sim, id: StringName, price: int = 20) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(id)
	offer.price = price
	s.shop.offers.append(offer)
	return offer


func _item_offer(s: Sim, id: StringName, price: int = 12) -> Offer:
	var offer := Offer.new()
	offer.item = Content.item(id)
	offer.price = price
	s.shop.offers.append(offer)
	return offer


func _open(s: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(s)
	return ui


func test_drag_weapon_into_next_empty_slot_buys_once(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"smg")
	var ui := _open(s)
	var payload: Variant = ui.drag_payload_for(offer)
	var quote := ui.quote_drop(payload, &"empty_weapon")
	c.ok(quote.ok, "empty weapon target quotes buy")
	c.eq(quote.action, ShopResult.BUY, "empty target uses buy")
	var result := ui.apply_drop(payload, &"empty_weapon")
	c.ok(result.ok, "drop buys")
	c.eq(s.player.weapons.size(), 2, "one weapon appended")
	c.eq(s.player.weapons[1].id, &"smg", "dropped weapon equipped")
	c.eq(s.player.materials, 280, "price charged once")
	c.ok(ui.undo_button != null and not ui.undo_button.disabled, "undo enabled")
	ui.free()


func test_drop_on_occupied_slot_replaces_even_when_build_is_partial(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"shotgun", 24)
	var ui := _open(s)
	var result := ui.apply_drop(ui.drag_payload_for(offer), &"weapon_slot", 0)
	c.ok(result.ok, "occupied slot accepts replace")
	c.eq(result.action, ShopResult.REPLACE, "occupied slot always replaces")
	c.eq(s.player.weapons.size(), 1, "partial build does not append")
	c.eq(s.player.weapons[0].id, &"shotgun", "chosen slot replaced")
	ui.free()


func test_drop_on_full_build_replaces_the_exact_slot(c: Check) -> void:
	var s := _shop_sim()
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var offer := _weapon_offer(s, &"orb", 28)
	var ui := _open(s)
	var result := ui.apply_drop(ui.drag_payload_for(offer), &"weapon_slot", 4)
	c.ok(result.ok, "full build replacement succeeds")
	c.eq(s.player.weapons.size(), Content.MAX_WEAPON_SLOTS, "slot count stays full")
	c.eq(s.player.weapons[4].id, &"orb", "exact slot replaced")
	ui.free()


func test_item_drop_uses_transaction_and_undo(c: Check) -> void:
	var s := _shop_sim()
	var offer := _item_offer(s, &"sharp_edge")
	var ui := _open(s)
	var result := ui.apply_drop(ui.drag_payload_for(offer), &"items")
	c.ok(result.ok, "item drop buys")
	c.eq(result.action, ShopResult.BUY, "item target uses buy")
	c.eq(s.player.item_count(&"sharp_edge"), 1, "item installed")
	ui.undo_button.pressed.emit()
	c.eq(s.player.item_count(&"sharp_edge"), 0, "item purchase undone")
	c.eq(s.player.materials, 300, "item refund restores exact snapshot")
	ui.free()


func test_ui_records_and_replays_multiple_equipment_undos(c: Check) -> void:
	var s := _shop_sim()
	var weapon := _weapon_offer(s, &"smg", 20)
	var item := _item_offer(s, &"sharp_edge", 12)
	var ui := _open(s)
	c.ok(ui.apply_drop(ui.drag_payload_for(weapon), &"empty_weapon").ok, "weapon bought")
	# Refresh rebuilt cards but retained the same unsold item in this batch.
	c.ok(ui.apply_drop(ui.drag_payload_for(item), &"items").ok, "item bought")
	ui._on_upgrade_weapon(1)
	c.eq(s.player.level_at(1), 1, "upgrade applied through Shop.apply")
	c.eq(s.shop._undo_stack.size(), 3, "three UI actions recorded")
	ui.undo_button.pressed.emit()
	c.eq(s.player.level_at(1), 0, "first undo restores level")
	ui.undo_button.pressed.emit()
	c.eq(s.player.item_count(&"sharp_edge"), 0, "second undo removes item")
	ui.undo_button.pressed.emit()
	c.eq(s.player.weapons.size(), 1, "third undo removes weapon")
	c.eq(s.player.materials, 300, "all materials restored")
	c.ok(ui.undo_button.disabled, "undo disables at history start")
	ui.free()


func test_stale_foreign_and_failed_payloads_never_mutate(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"smg", 20)
	var ui := _open(s)
	var old_payload: Variant = ui.drag_payload_for(offer)
	c.ok(ui.apply_drop(old_payload, &"empty_weapon").ok, "initial buy succeeds")
	ui.undo_button.pressed.emit()
	var restored := ShopState.capture(s).to_dict()
	var stale := ui.apply_drop(old_payload, &"empty_weapon")
	c.ok(not stale.ok, "pre-undo offer object rejected")
	c.eq(ShopState.capture(s).to_dict(), restored, "stale drop changes nothing")
	var foreign_ui := ShopUi.new()
	var foreign := {"kind": &"shop_offer", "shop_ui": foreign_ui, "offer": s.shop.offers[0]}
	c.ok(not ui.apply_drop(foreign, &"empty_weapon").ok, "foreign source rejected")
	c.eq(ShopState.capture(s).to_dict(), restored, "foreign drop changes nothing")
	foreign_ui.free()
	s.player.materials = 0
	var current := s.shop.offers[0]
	var before_failed := ShopState.capture(s).to_dict()
	var failed := ui.apply_drop(ui.drag_payload_for(current), &"empty_weapon")
	c.ok(not failed.ok and failed.reason == &"poor", "failed quote is reported")
	c.eq(ShopState.capture(s).to_dict(), before_failed, "failed drop changes nothing")
	ui.free()


func test_reroll_and_start_lock_the_ui_history(c: Check) -> void:
	var s := _shop_sim(500)
	var offer := _weapon_offer(s, &"smg", 20)
	var ui := _open(s)
	c.ok(ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon").ok, "buy records history")
	c.ok(not ui.undo_button.disabled, "undo available before reroll")
	ui.reroll_button.pressed.emit()
	c.ok(not s.shop.can_undo() and ui.undo_button.disabled, "reroll locks history")
	# Use a fresh offer from the new batch, then exercise the real start signal path.
	var fresh: Offer = null
	for candidate: Offer in s.shop.offers:
		if not candidate.is_weapon():
			fresh = candidate
			break
	if fresh == null:
		fresh = _item_offer(s, &"sharp_edge", 1)
	ui.refresh()
	c.ok(ui.apply_drop(ui.drag_payload_for(fresh), &"items").ok, "new batch records history")
	ui.start_requested.connect(s.start_next_wave)
	ui.start_button.pressed.emit()
	c.ok(not s.shop.can_undo(), "successful wave start locks history")
	ui.free()


func test_cancelled_drag_suppresses_release_click_without_mutation(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"smg", 20)
	var ui := _open(s)
	var card := ui.offers_box.get_child(0) as OfferCard
	card.drag_started()
	card.pressed.emit()
	c.eq(s.player.weapons.size(), 1, "cancelled drag release is not a click")
	c.eq(s.player.materials, 300, "cancelled drag spends nothing")
	ui.free()


func test_successful_drag_and_release_commit_only_once(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"smg", 20)
	var ui := _open(s)
	var card := ui.offers_box.get_child(0) as OfferCard
	var payload: Variant = ui.drag_payload_for(offer)
	card.drag_started()
	c.ok(ui.apply_drop(payload, &"empty_weapon").ok, "drag commits purchase")
	# The original card can still receive the release before queue_free completes.
	card.pressed.emit()
	c.eq(s.player.weapons.size(), 2, "release adds no duplicate weapon")
	c.eq(s.player.materials, 280, "release adds no duplicate charge")
	ui.free()


func test_drop_quote_uses_mechanics_cost_and_restores_weapon_detail(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"shotgun", 24)
	var ui := _open(s)
	var detail_before := ui._footer.text
	var payload: Variant = ui.drag_payload_for(offer)
	var buy_quote := ui.quote_drop(payload, &"empty_weapon")
	c.eq(ui._footer.text, Loc.t("shop.quote_buy", [buy_quote.cost]),
			"empty target shows quoted cost")
	ui.clear_drop_hint()
	c.eq(ui._footer.text, detail_before, "leaving target restores weapon detail")
	var replace_quote := ui.quote_drop(payload, &"weapon_slot", 0)
	var expected := Loc.t("shop.quote_refund", [absi(replace_quote.cost)]) if replace_quote.cost < 0 \
			else (Loc.t("shop.quote_replace_free") if replace_quote.cost == 0 \
			else Loc.t("shop.quote_replace", [replace_quote.cost]))
	c.eq(ui._footer.text, expected, "occupied target shows mechanics net cost")
	ui.clear_drop_hint()
	c.eq(ui._footer.text, detail_before, "drag-end cleanup restores detail")
	c.ok(not ui.undo_button.tooltip_text.is_empty(), "undo scope has an accessible tooltip")
	ui.free()


func test_invalid_drop_quote_explains_the_reason(c: Check) -> void:
	var s := _shop_sim(0)
	var offer := _weapon_offer(s, &"smg", 20)
	var ui := _open(s)
	var payload: Variant = ui.drag_payload_for(offer)
	var result := ui.quote_drop(payload, &"empty_weapon")
	c.ok(not result.ok and result.reason == &"poor", "mechanics rejects poor drop")
	c.eq(ui._footer.text, Loc.t("shop.drop_poor"), "footer explains missing materials")
	var item := _item_offer(s, &"sharp_edge", 0)
	ui.refresh()
	result = ui.quote_drop(ui.drag_payload_for(item), &"weapon_slot", 0)
	c.ok(not result.ok and result.reason == &"invalid", "wrong target rejects item")
	c.eq(ui._footer.text, Loc.t("shop.drop_invalid"), "footer explains invalid target")
	ui.free()


func test_partial_build_swap_action_uses_trade_in_before_mutating(c: Check) -> void:
	var s := _shop_sim(20)
	s.player.weapon_investments[0] = 8
	var offer := _weapon_offer(s, &"smg", 24)
	var ui := _open(s)
	var card := ui.offers_box.get_child(0) as OfferCard
	c.eq(card.blocked_reason, &"poor", "direct purchase is unaffordable")
	c.ok(card.swap_button != null and not card.swap_button.disabled,
			"focused swap action remains available")
	var before := ShopState.capture(s).to_dict()
	card.swap_button.pressed.emit()
	c.ok(ui.is_replacing(), "swap action opens keyboard slot choice")
	c.eq(ShopState.capture(s).to_dict(), before, "choosing swap does not mutate state")
	c.ok(ui.build_panel.focus_first_slot(), "replacement slot is focusable")
	ui.build_panel._slot_buttons[0].pressed.emit()
	c.ok(ui.workshop.visible, "slot selection opens an explicit final confirmation")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(s.player.weapons.size(), 1, "swap keeps partial build size")
	c.eq(s.player.weapons[0].id, &"smg", "focused slot receives replacement")
	c.ok(s.player.materials >= 0, "trade-in makes replacement affordable")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(s).to_dict(), before, "undo restores exact pre-swap state")
	# The restored unsold offer is a new object; buying it makes the refreshed card inert.
	var restored_offer := s.shop.offers[0]
	s.player.materials = restored_offer.price
	ui.refresh()
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	var sold_card := ui.offers_box.get_child(0) as OfferCard
	c.ok(sold_card.disabled and sold_card.swap_button == null,
			"sold offer cannot request replacement")
	ui.free()


func test_upgraded_trade_in_quote_commit_and_undo_use_one_mechanics_value(c: Check) -> void:
	var s := _shop_sim(500)
	var offer := _weapon_offer(s, &"smg", 10)
	var ui := _open(s)
	ui._on_upgrade_weapon(0)
	ui._on_upgrade_weapon(0)
	c.eq(s.player.level_at(0), 2, "two UI upgrades are recorded")
	var before_replace := ShopState.capture(s).to_dict()
	var history_before := s.shop._undo_stack.size()
	c.eq(history_before, 2, "upgrade history remains available")
	var resale := Shop.resale_for(s, 0)
	var payload: Variant = ui.drag_payload_for(offer)
	var quote := ui.quote_drop(payload, &"weapon_slot", 0)
	c.ok(quote.ok and quote.cost < 0, "upgraded trade-in quotes a refund")
	c.eq(ui._footer.text, Loc.t("shop.quote_refund", [absi(quote.cost)]),
			"footer displays the exact mechanics refund")
	var card := ui.offers_box.get_child(0) as OfferCard
	card.swap_button.pressed.emit()
	c.ok(ui.is_replacing(), "swap action exposes slot trade-in")
	c.ok(ui.build_panel._slot_buttons[0].text.contains("+%d" % resale),
			"slot displays Shop.resale_total for upgraded weapon")
	ui._cancel_replace()
	var materials_before := s.player.materials
	var result := ui.apply_drop(payload, &"weapon_slot", 0)
	c.ok(result.ok and result.cost == quote.cost, "commit reuses quoted net cost")
	c.eq(s.player.materials, materials_before - quote.cost, "refund applies exactly once")
	c.eq(s.player.weapons[0].id, &"smg", "replacement is equipped")
	c.eq(s.player.level_at(0), 0, "replacement resets slot level")
	ui.undo_button.pressed.emit()
	c.eq(ShopState.capture(s).to_dict(), before_replace,
			"undo restores upgraded slot, materials and offer snapshot")
	c.eq(s.shop._undo_stack.size(), history_before,
			"replacement undo leaves earlier upgrade history intact")
	ui.free()
