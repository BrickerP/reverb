extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _shop_sim(materials: int = 100) -> Sim:
	var sim := Sim.new(699)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = materials
	sim.shop.offers.clear()
	return sim


func _offer(sim: Sim, id: StringName, price: int = 10) -> Offer:
	var offer := Offer.new()
	if Content.weapon(id) != null:
		offer.weapon = Content.weapon(id)
	else:
		offer.item = Content.item(id)
	offer.price = price
	sim.shop.offers.append(offer)
	return offer


func _open(sim: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	return ui


func _card(ui: ShopUi, index: int) -> OfferCard:
	return ui.offers_box.get_child(index) as OfferCard


func _lock_count(ui: ShopUi) -> int:
	var count := 0
	for i in ui.offers_box.get_child_count():
		var card := _card(ui, i)
		if card.lock_button != null and card.lock_button.text == Loc.t("shop.unlock"):
			count += 1
	return count


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _nested_center(card: OfferCard, control: Control) -> Vector2:
	var global_center := control.get_global_rect().get_center()
	return card.get_global_transform_with_canvas().affine_inverse() * global_center


func test_nested_lock_click_and_drag_never_purchase_or_replace(c: Check) -> void:
	var sim := _shop_sim()
	var held := _offer(sim, &"smg", 20)
	var ui := _open(sim)
	var old_card := _card(ui, 0)
	var audio := GameAudio.new()
	_root().add_child(audio)
	audio.bind(sim)
	var materials := sim.player.materials
	var weapons := sim.player.weapons.size()
	c.eq(old_card._get_drag_data(_nested_center(old_card, old_card.lock_button)), null,
			"drag beginning over Lock never starts the offer drag")
	old_card.lock_button.pressed.emit()
	old_card.pressed.emit()
	c.eq(sim.player.materials, materials, "nested Lock click spends no materials")
	c.eq(sim.player.weapons.size(), weapons, "nested Lock click buys no weapon")
	c.ok(held.locked and not ui.is_replacing(), "nested Lock changes only held state")
	c.ok(_card(ui, 0).lock_button.has_focus(), "refreshed Lock action retains keyboard focus")
	c.eq(ui.pending_feedback_count(), 0, "free Lock toggle queues no material or equipment feedback")
	c.eq(ui.material_feedback_runs, 0, "free Lock toggle runs no material animation")
	c.eq(audio.play_count(&"buy"), 0, "free Lock toggle plays no purchase cue")
	c.eq(audio.play_count(&"equipment_apply"), 0, "free Lock toggle plays no equipment cue")
	ui.free()
	audio.free()


func test_only_one_visible_hold_moves_then_unlocks(c: Check) -> void:
	var sim := _shop_sim()
	var first := _offer(sim, &"sharp_edge")
	var second := _offer(sim, &"iron_heart")
	_offer(sim, &"sneakers")
	var ui := _open(sim)
	var materials := sim.player.materials
	var weapons := sim.player.weapons.size()
	_card(ui, 0).lock_button.pressed.emit()
	c.ok(first.locked and _lock_count(ui) == 1, "first offer is the only visible hold")
	_card(ui, 1).lock_button.pressed.emit()
	c.ok(not first.locked and second.locked and _lock_count(ui) == 1,
			"holding another offer moves the one visible hold")
	c.ok(_card(ui, 1).lock_button.has_focus(), "moved hold keeps focus on its nested action")
	_card(ui, 1).lock_button.pressed.emit()
	c.ok(not second.locked and _lock_count(ui) == 0, "Unlock removes the visible hold")
	c.ok(_card(ui, 1).lock_button.has_focus(), "Unlock refresh restores nested-action focus")
	c.eq(sim.player.materials, materials, "moving and unlocking the hold remains free")
	c.eq(sim.player.weapons.size(), weapons, "moving and unlocking the hold buys nothing")
	ui.free()


func test_offer_states_keep_lock_boundary_and_full_explanation(c: Check) -> void:
	var empty := _shop_sim()
	_offer(empty, &"sharp_edge", 12)
	var open_ui := _open(empty)
	c.ok(_card(open_ui, 0).lock_button != null and not _card(open_ui, 0).disabled,
			"affordable empty-slot offer can be held or bought")
	c.eq(_card(open_ui, 0).lock_button.text, Loc.t("shop.lock"),
			"empty hold state exposes Lock")
	c.eq(_card(open_ui, 0).lock_button.accessibility_description, Loc.t("shop.lock_hint"),
			"Lock explains persistence and equipment-undo behavior")
	open_ui.free()

	var poor := _shop_sim(0)
	_offer(poor, &"iron_heart", 12)
	var poor_ui := _open(poor)
	c.eq(_card(poor_ui, 0).blocked_reason, &"poor", "poor offer exposes its state")
	c.ok(_card(poor_ui, 0).lock_button != null, "poor offer can still use the free hold")
	_card(poor_ui, 0).lock_button.pressed.emit()
	c.ok(poor.shop.offers[0].locked and poor.player.items.is_empty(),
			"poor offer can be held without buying it")
	poor_ui.free()

	var sold := _shop_sim()
	var sold_offer := _offer(sold, &"sneakers")
	sold_offer.sold = true
	var sold_ui := _open(sold)
	c.ok(_card(sold_ui, 0).disabled and _card(sold_ui, 0).lock_button == null,
			"sold offer is inert and cannot be held")
	sold_ui.free()

	var full := _shop_sim()
	while full.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		full.player.add_weapon(Content.weapon(&"pistol"))
	_offer(full, &"rifle", 20)
	var full_ui := _open(full)
	var full_card := _card(full_ui, 0)
	c.eq(full_card.blocked_reason, &"full", "full-slot weapon exposes replacement state")
	c.ok(_has_label(full_card, str(full_card.offer.price)),
			"full-slot offer keeps its actual price visible")
	c.ok(full_card.lock_button != null, "full-slot offer can be held without replacing")
	c.ok(full_card.accessibility_description.contains(Loc.t("shop.full_reason")),
			"full-slot accessible description explains replacement")
	c.eq(full_card.tooltip_text, Loc.t("shop.full_reason"),
			"full-slot tooltip carries the complete reason behind the short badge")
	c.eq(full_card._get_drag_data(_nested_center(full_card, full_card.swap_button)), null,
			"drag beginning over Replace never starts the offer drag")
	full_card.lock_button.pressed.emit()
	c.ok(not full_ui.is_replacing(), "Lock on a full-slot offer never starts replacement")
	full_ui.free()


func test_stale_offer_after_undo_cannot_drag_lock_or_buy(c: Check) -> void:
	var sim := _shop_sim()
	var original := _offer(sim, &"sharp_edge", 10)
	var ui := _open(sim)
	var old_card := _card(ui, 0)
	old_card.pressed.emit()
	c.ok(original.sold, "fixture purchase consumes the original offer")
	ui.undo_button.pressed.emit()
	c.ok(sim.shop.offers[0] != original, "undo reconstructs the authoritative offer instance")
	var before := ShopState.capture(sim).to_dict()
	c.eq(ui.drag_payload_for(original), null, "stale offer cannot start a drag")
	ui._on_lock_offer(original)
	c.ok(not sim.shop.quote(ShopResult.BUY, sim, original).ok,
			"stale offer cannot re-enter the purchase transaction")
	c.eq(ShopState.capture(sim).to_dict(), before, "stale offer cannot lock, drag or buy after undo")
	ui.free()
