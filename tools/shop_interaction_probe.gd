extends SceneTree
# Real-window, real-input verification for the tactile shop transaction flow.
# This is a presentation fixture, not balance evidence: it stages materials and
# offers, then drives native Control drag/drop and focused ui_accept actions.
# Usage: godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/shop_interaction_probe.gd

const DEADLINE_FRAMES := 2400
const SETTLE_FRAMES := 5

var _main: Node
var _frames := 0
var _failed := false
var _shots_dir := ""
var _metrics := {
	"invalid_drops": 0,
	"weapon_buys": 0,
	"replacements": 0,
	"item_buys": 0,
	"upgrades": 0,
	"keyboard_replacements": 0,
	"undos": 0,
	"rerolls": 0,
	"wave_starts": 0,
}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://shop_interaction_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://shop_interaction_probe_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://shop_interaction_probe_settings.json")
	_clear_fixture_files()
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before probe completed")
	return false


func _run() -> void:
	if not (await _enter_real_shop()):
		return
	var ui: ShopUi = _main.shop_ui
	var sim: Sim = _main.sim
	_stage_offers()
	ui.refresh()
	await _wait_frames(SETTLE_FRAMES)

	if not (await _check_full_layout()):
		return
	_save("full")
	_reset_loadout()
	_stage_offers()
	ui.refresh()
	await _wait_frames(SETTLE_FRAMES)

	# A cancelled drag must neither activate the Button nor mutate the shop.
	var before_cancel := _state()
	var cancel_card := _card_for(&"rifle")
	var cancel_target: ShopDropTarget = ui.build_panel.empty_drop_target
	if not _require(cancel_card != null and cancel_target != null,
			"rifle offer and empty target exist for cancelled drag"):
		return
	var cancel_payload: Variant = ui.drag_payload_for(cancel_card.offer)
	var cancel_quote: ShopResult = ui.quote_drop(cancel_payload,
			cancel_target.target_kind, cancel_target.target_index)
	if not _require(cancel_quote.ok, "cancelled-drag target has a valid quote"):
		return
	var cancel_hint: String = _quote_text(cancel_quote)
	ui.clear_drop_hint()
	if not (await _drag_off_target(cancel_card, cancel_target, cancel_hint,
			Vector2(1240.0, 674.0))):
		return
	if not _require(_state() == before_cancel, "invalid-space drag leaves state unchanged"):
		return
	_metrics.invalid_drops += 1

	# Drop a weapon on the one explicit next-empty target. The release must not
	# also activate the source Button, so materials/history change exactly once.
	var before_buy := _state()
	var buy_card := _card_for(&"rifle")
	var empty_target: ShopDropTarget = ui.build_panel.empty_drop_target
	if not _require(buy_card != null and empty_target != null,
			"weapon offer and next-empty target exist"):
		return
	var buy_payload: Variant = ui.drag_payload_for(buy_card.offer)
	var buy_quote: ShopResult = ui.quote_drop(buy_payload,
			empty_target.target_kind, empty_target.target_index)
	if not _require(buy_quote.ok, "weapon-to-empty quote succeeds"):
		return
	ui.clear_drop_hint()
	if not (await _drag(buy_card, empty_target, Vector2.ZERO, "highlight",
			_quote_text(buy_quote))):
		return
	if not _require(sim.player.weapons.size() == 2, "empty drop appends exactly one weapon"):
		return
	if not _require(sim.player.weapons[1].id == &"rifle", "empty drop equips the offered rifle"):
		return
	if not _require(sim.player.materials == int(before_buy["materials"]) - buy_quote.cost,
			"empty drop spends the quoted cost once"):
		return
	_metrics.weapon_buys += 1
	var after_buy := _state()

	# An occupied slot always means replacement, even before the loadout is full.
	var before_replace := _state()
	var replace_card := _card_for(&"shotgun")
	var slot_zero: ShopDropTarget = ui.build_panel.slot_drop_targets[0]
	if not _require(replace_card != null and slot_zero != null,
			"shotgun offer and occupied slot exist"):
		return
	var replace_payload: Variant = ui.drag_payload_for(replace_card.offer)
	var replace_quote: ShopResult = ui.quote_drop(replace_payload,
			slot_zero.target_kind, slot_zero.target_index)
	if not _require(replace_quote.ok, "weapon-to-occupied quote succeeds before full loadout"):
		return
	ui.clear_drop_hint()
	if not (await _drag(replace_card, slot_zero, Vector2.ZERO, "",
			_quote_text(replace_quote))):
		return
	if not _require(sim.player.weapons.size() == 2, "replacement does not append a weapon"):
		return
	if not _require(sim.player.weapons[0].id == &"shotgun", "occupied slot receives shotgun"):
		return
	if not _require(sim.player.materials == int(before_replace["materials"]) - replace_quote.cost,
			"replacement spends the quoted net cost once"):
		return
	_metrics.replacements += 1
	var after_replace := _state()

	var before_item := _state()
	var item_card := _card_for(&"sharp_edge")
	var item_target: ShopDropTarget = ui.build_panel.items_drop_target
	if not _require(item_card != null and item_target != null,
			"item offer and item target exist"):
		return
	var item_payload: Variant = ui.drag_payload_for(item_card.offer)
	var item_quote: ShopResult = ui.quote_drop(item_payload,
			item_target.target_kind, item_target.target_index)
	if not _require(item_quote.ok, "item-to-items quote succeeds"):
		return
	ui.clear_drop_hint()
	if not (await _drag(item_card, item_target)):
		return
	if not _require(sim.player.item_count(&"sharp_edge") == 1, "item drop adds exactly one item"):
		return
	if not _require(sim.player.materials == int(before_item["materials"]) - item_quote.cost,
			"item drop spends the quoted cost once"):
		return
	_metrics.item_buys += 1
	_save("committed")

	# Undo is exercised through the focused UI control. Each undo rebuilds Offers,
	# so every assertion reads fresh UI/state rather than cached object references.
	if not (await _activate(ui.undo_button)):
		return
	if not _require(_state() == before_item, "first undo restores item purchase snapshot"):
		return
	_metrics.undos += 1
	if not (await _activate(ui.undo_button)):
		return
	if not _require(_state() == before_replace, "second undo restores replacement snapshot"):
		return
	_metrics.undos += 1
	_save("undone")
	if not (await _activate(ui.undo_button)):
		return
	if not _require(_state() == before_buy, "third undo restores weapon purchase snapshot"):
		return
	if not _require(not sim.shop.can_undo() and ui.undo_button.disabled,
			"three actions require exactly three undos"):
		return
	_metrics.undos += 1
	if not _require(after_buy != after_replace, "transaction checkpoints are distinct"):
		return

	# Upgrade through the real focused control before replacing. The next quote
	# and slot label must include the mechanics-owned upgraded trade-in value.
	var before_upgrade := _state()
	if not _require(not ui.build_panel._upgrade_buttons.is_empty(),
			"equipped weapon exposes a focusable upgrade action"):
		return
	var upgrade_cost: int = Shop.upgrade_cost(sim.player.weapons[0], sim.player.level_at(0))
	if not (await _activate(ui.build_panel._upgrade_buttons[0])):
		return
	if not _require(sim.player.level_at(0) == 1, "focused upgrade raises the slot one level"):
		return
	if not _require(sim.player.materials == int(before_upgrade["materials"]) - upgrade_cost,
			"focused upgrade spends its mechanics cost once"):
		return
	if not _require(sim.shop.can_undo(), "focused upgrade records undo history"):
		return
	_metrics.upgrades += 1

	# Keyboard/controller parity: explicitly enter replace mode from the offer,
	# then confirm the destination slot. Entering the chooser must not buy first.
	var before_keyboard_replace := _state()
	var keyboard_card := _card_for(&"shotgun")
	if not _require(keyboard_card != null and keyboard_card.swap_button != null
			and not keyboard_card.swap_button.disabled,
			"unsold weapon exposes a focusable replace action"):
		return
	var keyboard_payload: Variant = ui.drag_payload_for(keyboard_card.offer)
	var keyboard_quote: ShopResult = ui.quote_drop(keyboard_payload, &"weapon_slot", 0)
	if not _require(keyboard_quote.ok, "keyboard replacement has a valid mechanics quote"):
		return
	var expected_trade_in: int = Shop.resale_total(sim.player.weapons[0], sim.player.level_at(0))
	if not _require(keyboard_quote.cost == keyboard_card.offer.price - expected_trade_in,
			"replacement quote refunds the upgraded weapon trade-in"):
		return
	ui.clear_drop_hint()
	if not (await _activate(keyboard_card.swap_button)):
		return
	if not _require(ui.is_replacing(), "focused replace action enters slot selection"):
		return
	if not _require(_state() == before_keyboard_replace,
			"entering slot selection does not buy or mutate state"):
		return
	if not _require(not ui.build_panel._slot_buttons.is_empty(),
			"slot selection exposes a focusable replacement target"):
		return
	var expected_slot_text: String = "%s  +%d" % [
		Loc.weapon_name(sim.player.weapons[0].id), expected_trade_in,
	]
	if not _require(ui.build_panel._slot_buttons[0].text == expected_slot_text,
			"slot selection displays the mechanics upgraded trade-in"):
		return
	if not (await _activate(ui.build_panel._slot_buttons[0])):
		return
	if not _require(not ui.is_replacing(), "slot confirmation exits replacement mode"):
		return
	if not _require(sim.player.weapons.size() == 1 and sim.player.weapons[0].id == &"shotgun",
			"keyboard replacement changes the chosen slot without appending"):
		return
	if not _require(sim.player.materials == int(before_keyboard_replace["materials"])
			- keyboard_quote.cost, "keyboard replacement spends the quoted net cost once"):
		return
	_metrics.keyboard_replacements += 1
	if not _require(sim.shop.can_undo(), "keyboard replacement records undo history"):
		return
	if not (await _activate(ui.undo_button)):
		return
	if not _require(_state() == before_keyboard_replace,
			"UI undo restores the upgraded keyboard replacement snapshot"):
		return
	_metrics.undos += 1
	if not _require(sim.player.level_at(0) == 1 and sim.shop.can_undo(),
			"replacement undo preserves upgraded baseline and its earlier history"):
		return

	# A successful reroll is a history boundary owned by Shop.
	var reroll_buy_card := _card_for(&"rifle")
	if not _require(reroll_buy_card != null and ui.build_panel.empty_drop_target != null,
			"fresh rebuilt offer can be dragged after undo"):
		return
	if not (await _drag(reroll_buy_card, ui.build_panel.empty_drop_target)):
		return
	if not _require(sim.shop.can_undo(), "equipment action creates history before reroll"):
		return
	if not (await _activate(ui.reroll_button)):
		return
	if not _require(not sim.shop.can_undo() and ui.undo_button.disabled,
			"successful reroll locks earlier history"):
		return
	_metrics.rerolls += 1

	# Stage one more equipment action, then start the wave through focused UI.
	_stage_offers()
	ui.refresh()
	await _wait_frames(SETTLE_FRAMES)
	var start_item_card := _card_for(&"sharp_edge")
	if not _require(start_item_card != null and ui.build_panel.items_drop_target != null,
			"item action exists before wave-start history boundary"):
		return
	if not (await _drag(start_item_card, ui.build_panel.items_drop_target)):
		return
	if not _require(sim.shop.can_undo(), "equipment action creates history before wave start"):
		return
	if not (await _activate(ui.start_button)):
		return
	if not _require(sim.phase == Sim.Phase.WAVE and not ui.visible,
			"focused start enters the next wave"):
		return
	if not _require(not sim.shop.can_undo(), "successful wave start locks shop history"):
		return
	_metrics.wave_starts += 1

	_main.audio.stop_all()
	await _wait_frames(8)
	print("shop interaction probe: %s" % JSON.stringify(_metrics))
	print("shop interaction probe: OK")
	quit()


func _enter_real_shop() -> bool:
	for _i in 180:
		if _main.character_select != null:
			break
		await process_frame
	if not _require(_main.character_select != null, "main reached character selection"):
		return false
	_main.choose_character(&"looper", 20261023)
	var sim: Sim = _main.sim
	sim._plan.clear()
	sim._plan_idx = 0
	sim.wave_duration = 0.001
	for _i in 180:
		if _main.shop_ui.visible:
			return true
		await process_frame
	_fail("real Main never opened the shop after the wave completed")
	return false


func _reset_loadout() -> void:
	var sim: Sim = _main.sim
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.items.clear()
	sim.player.materials = 500
	sim.shop.clear_history()


func _stage_offers() -> void:
	var sim: Sim = _main.sim
	sim.player.materials = 500
	sim.shop.offers.clear()
	sim.shop.offers.append(_weapon_offer(&"rifle", 31))
	sim.shop.offers.append(_weapon_offer(&"shotgun", 37))
	sim.shop.offers.append(_item_offer(&"sharp_edge", 19))
	sim.shop.offers.append(_item_offer(&"long_play", 33))


func _weapon_offer(id: StringName, price: int) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(id)
	offer.price = price
	return offer


func _item_offer(id: StringName, price: int) -> Offer:
	var offer := Offer.new()
	offer.item = Content.item(id)
	offer.price = price
	return offer


func _card_for(id: StringName) -> OfferCard:
	for node in _main.shop_ui.offers_box.get_children():
		var card := node as OfferCard
		if card != null and card.offer != null and card.offer.id() == id:
			return card
	return null


func _drag(source: Control, target: Control = null, invalid_position: Vector2 = Vector2.ZERO,
		screenshot: String = "", expected_hint: String = "") -> bool:
	if not _require(source != null and source.is_visible_in_tree(), "drag source is visible"):
		return false
	var from := source.get_global_rect().get_center()
	var to := invalid_position if target == null else target.get_global_rect().get_center()
	_push_motion(from, Vector2.ZERO, 0)
	await _wait_frames(2)
	_push_button(from, true)
	await _wait_frames(2)
	var first_move := from.lerp(to, 0.35)
	_push_motion(first_move, first_move - from, MOUSE_BUTTON_MASK_LEFT)
	await _wait_frames(2)
	_push_motion(to, to - first_move, MOUSE_BUTTON_MASK_LEFT)
	await _wait_frames(3)
	if not _require(root.gui_is_dragging(), "native viewport drag started"):
		return false
	if target != null:
		var drop_target := target as ShopDropTarget
		if not _require(drop_target != null and drop_target.highlighted,
				"native drag highlights the target"):
			return false
		if not expected_hint.is_empty() and not _require(
				_main.shop_ui._footer.text == expected_hint,
				"highlight shows the exact mechanics quote in the footer"):
			return false
	if not screenshot.is_empty():
		_save(screenshot)
	_push_button(to, false)
	await _wait_frames(SETTLE_FRAMES)
	if not _require(not root.gui_is_dragging(), "native viewport drag ended"):
		return false
	if not expected_hint.is_empty() and not _require(
			_main.shop_ui._footer.text != expected_hint,
			"drag end clears the transient quote"):
		return false
	return true


func _drag_off_target(source: Control, target: ShopDropTarget, expected_hint: String,
		invalid_position: Vector2) -> bool:
	if not _require(source != null and source.is_visible_in_tree(),
			"cancelled drag source is visible"):
		return false
	var restored_hint: String = _main.shop_ui._footer.text
	var from := source.get_global_rect().get_center()
	var over := target.get_global_rect().get_center()
	_push_motion(from, Vector2.ZERO, 0)
	await _wait_frames(2)
	_push_button(from, true)
	await _wait_frames(2)
	var first_move := from.lerp(over, 0.35)
	_push_motion(first_move, first_move - from, MOUSE_BUTTON_MASK_LEFT)
	await _wait_frames(2)
	_push_motion(over, over - first_move, MOUSE_BUTTON_MASK_LEFT)
	await _wait_frames(3)
	if not _require(root.gui_is_dragging() and target.highlighted,
			"cancelled native drag first highlights a valid target"):
		return false
	if not _require(_main.shop_ui._footer.text == expected_hint,
			"valid hover shows its exact mechanics quote before cancellation"):
		return false
	_push_motion(invalid_position, invalid_position - over, MOUSE_BUTTON_MASK_LEFT)
	await _wait_frames(3)
	if not _require(not target.highlighted, "moving off target clears its highlight"):
		return false
	if not _require(_main.shop_ui._footer.text == restored_hint,
			"moving off target restores the selected detail or shop keys"):
		return false
	_push_button(invalid_position, false)
	await _wait_frames(SETTLE_FRAMES)
	if not _require(not root.gui_is_dragging(), "cancelled native viewport drag ended"):
		return false
	if not _require(_main.shop_ui._footer.text == restored_hint,
			"cancelled drag leaves no stale quote"):
		return false
	return true


func _quote_text(result: ShopResult) -> String:
	if result.action != ShopResult.REPLACE:
		return Loc.t("shop.quote_buy", [result.cost])
	if result.cost < 0:
		return Loc.t("shop.quote_refund", [absi(result.cost)])
	if result.cost == 0:
		return Loc.t("shop.quote_replace_free")
	return Loc.t("shop.quote_replace", [result.cost])


func _activate(button: Button) -> bool:
	if not _require(button != null and button.is_visible_in_tree() and not button.disabled,
			"focused action button is available"):
		return false
	button.grab_focus()
	await _wait_frames(2)
	if not _require(button.has_focus(), "focused action button owns focus"):
		return false
	_push_action(&"ui_accept", true)
	await process_frame
	_push_action(&"ui_accept", false)
	await _wait_frames(SETTLE_FRAMES)
	return not _failed


func _push_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event, false)


func _push_motion(position: Vector2, relative: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, false)


func _push_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	root.push_input(event, false)


func _state() -> Dictionary:
	var sim: Sim = _main.sim
	var weapons := PackedStringArray()
	for weapon: WeaponDef in sim.player.weapons:
		weapons.append(String(weapon.id))
	var offers: Array[Dictionary] = []
	for offer: Offer in sim.shop.offers:
		offers.append({
			"kind": "weapon" if offer.is_weapon() else "item",
			"id": String(offer.id()),
			"price": offer.price,
			"sold": offer.sold,
		})
	return {
		"materials": sim.player.materials,
		"hp": sim.player.hp,
		"stats": sim.player.stats.values.duplicate(true),
		"weapons": weapons,
		"levels": sim.player.weapon_levels.duplicate(),
		"cooldowns": sim.player.cooldowns.duplicate(),
		"items": sim.player.items.duplicate(true),
		"offers": offers,
		"rerolls": sim.shop.rerolls,
		"phase": int(sim.phase),
		"wave": sim.wave,
	}


func _check_full_layout() -> bool:
	var sim: Sim = _main.sim
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	_main.shop_ui.refresh()
	await _wait_frames(SETTLE_FRAMES)
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var ui: ShopUi = _main.shop_ui
	if not _require(viewport.encloses(ui.undo_button.get_global_rect()),
			"undo control stays inside the 1280x720 viewport"):
		return false
	var scroll := ui.build_panel.get_child(0) as ScrollContainer
	var card_right := scroll.get_global_rect().end.x
	if scroll.get_v_scroll_bar().is_visible_in_tree():
		card_right -= scroll.get_v_scroll_bar().size.x
	for card: ShopDropTarget in ui.build_panel.slot_drop_targets:
		if not _require(card.get_global_rect().end.x <= card_right + 0.5,
				"full-loadout weapon card is not clipped by its scrollbar"):
			return false
	var cards := ui.offers_box.get_children()
	if not _require(cards.size() == Shop.OFFER_COUNT, "fixture renders four offer cards"):
		return false
	var last := cards[cards.size() - 1] as OfferCard
	if not _require(last.get_global_rect().end.y <= ui.reroll_button.global_position.y,
			"four offers do not overlap shop action controls"):
		return false
	return true


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := _shots_dir.path_join("shop_drag_%s.png" % name)
	image.save_png(path)
	print("wrote shots/shop_drag_%s.png" % name)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("shop interaction probe FAILED: %s" % message)
	_main.audio.stop_all()
	quit(1)


func _clear_fixture_files() -> void:
	for name in [
		"shop_interaction_probe_save.json",
		"shop_interaction_probe_runs.jsonl",
		"shop_interaction_probe_settings.json",
	]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
