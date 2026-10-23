class_name ShopUi
extends Control

signal start_requested

var sim: Sim
var offers_box: VBoxContainer
var reroll_button: Button
var undo_button: Button
var start_button: Button
var echo_panel: EchoPanel
var build_panel: BuildPanel

var _title: Label
var _materials: Label
var _interest: Label
var _footer: Label
var _warning: Label
var _overlay: Control
var _replacing: Offer
var _replacing_index: int = -1
var _connected_shop: Shop
var _weapon_detail := ""


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.93)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_build_header())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	columns.add_child(_build_left())
	build_panel = BuildPanel.new()
	build_panel.replace_cancelled.connect(_cancel_replace)
	build_panel.upgrade_requested.connect(_on_upgrade_weapon)
	build_panel.evolve_requested.connect(_on_evolve_weapon)
	build_panel.detail_changed.connect(_on_weapon_detail)
	columns.add_child(build_panel)
	echo_panel = EchoPanel.new()
	echo_panel.discard_requested.connect(_on_discard)
	echo_panel.merge_requested.connect(_on_merge)
	columns.add_child(echo_panel)
	root.add_child(_build_footer())
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _exit_tree() -> void:
	_disconnect_shop()


func open(s: Sim) -> void:
	_disconnect_shop()
	sim = s
	_connected_shop = sim.shop
	_connected_shop.shop_history_changed.connect(_on_history_changed)
	visible = true
	_replacing = null
	_replacing_index = -1
	refresh(true)
	_fly_take_token()
	# If the bank is over capacity, the discard is the only legal action: put focus there.
	if sim.bank.overflow(sim.echo_capacity()) > 0 and echo_panel.focus_first_discard():
		return
	_focus_card(0)


func refresh(animate_echo: bool = false) -> void:
	if _replacing != null and (not sim.shop.offers.has(_replacing) or _replacing.sold):
		_replacing = null
		_replacing_index = -1
	_title.text = Loc.t("shop.title", [sim.wave])
	_materials.text = "%s  %d" % [Loc.t("hud.materials"), sim.player.materials]
	_interest.text = Loc.t("shop.economy", [sim.last_wave_earned, sim.last_interest,
			Sim.interest_for(sim.player.materials)])
	UiTheme.clear(offers_box)
	for o in sim.shop.offers:
		var card := OfferCard.new()
		offers_box.add_child(card)
		card.setup(o, sim, o == _replacing, drag_payload_for, clear_drop_hint)
		card.pressed.connect(_on_offer.bind(o, card))
		card.replacement_requested.connect(_begin_replace)
	var cost := sim.shop.reroll_cost(sim.wave)
	reroll_button.text = Loc.t("shop.reroll", [cost])
	reroll_button.disabled = sim.player.materials < cost
	undo_button.text = Loc.t("shop.undo")
	undo_button.disabled = not sim.shop.can_undo()
	start_button.text = Loc.t("shop.start", [sim.wave + 1])
	start_button.disabled = not sim.can_start_wave()
	var over := sim.bank.overflow(sim.echo_capacity())
	_warning.text = Loc.t("shop.over", [over]) if over > 0 else ""
	var replace_with := ""
	var chooser := Callable()
	if _replacing != null:
		replace_with = Loc.weapon_name(_replacing.id())
		chooser = _on_replace_slot
	_footer.text = Loc.t("shop.keys")
	build_panel.refresh(sim, replace_with, chooser, quote_drop, apply_drop, clear_drop_hint)
	echo_panel.refresh(sim, animate_echo)


func _build_footer() -> Control:
	_footer = UiTheme.label(Loc.t("shop.keys"), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return _footer


func _on_weapon_detail(text: String) -> void:
	if _footer == null:
		return
	_weapon_detail = text
	_footer.text = text if text != "" else Loc.t("shop.keys")


func _build_header() -> Control:
	var row := HBoxContainer.new()
	_title = UiTheme.label("", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	_materials = UiTheme.label("", 26, UiTheme.COIN, HORIZONTAL_ALIGNMENT_RIGHT)
	_interest = UiTheme.label("", 12, UiTheme.COIN, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_materials)
	right.add_child(_interest)
	row.add_child(right)
	return row


func _build_left() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(400.0, 0.0)
	column.add_theme_constant_override("separation", 8)
	offers_box = VBoxContainer.new()
	offers_box.add_theme_constant_override("separation", 6)
	column.add_child(offers_box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(126.0, 48.0)
	reroll_button.pressed.connect(_on_reroll)
	buttons.add_child(reroll_button)
	undo_button = Button.new()
	undo_button.custom_minimum_size = Vector2(92.0, 48.0)
	undo_button.tooltip_text = Loc.t("shop.undo_hint")
	undo_button.pressed.connect(_on_undo)
	buttons.add_child(undo_button)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0.0, 48.0)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_on_start)
	buttons.add_child(start_button)
	column.add_child(buttons)
	_warning = UiTheme.label("", 16, UiTheme.WARN)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_warning)
	return column


func _on_offer(o: Offer, card: OfferCard) -> void:
	if card.consume_drag_click():
		return
	var reason := sim.shop.block_reason(sim, o)
	if reason == &"full" and o.is_weapon():
		if _replacing == o:
			_cancel_replace()
		else:
			_begin_replace(o)
		return
	if reason != &"":
		card.reject()
		_flash_block(reason)
		return
	var index := sim.shop.offers.find(o)
	var result := sim.shop.apply(ShopResult.BUY, sim, o)
	if result.ok:
		refresh()
		_focus_card(index)
	else:
		card.reject()
		_flash_block(result.reason)


func is_replacing() -> bool:
	return _replacing != null


func _begin_replace(o: Offer) -> void:
	if sim == null or not visible or o == null or not o.is_weapon() or o.sold \
			or not sim.shop.offers.has(o):
		return
	_replacing = o
	_replacing_index = sim.shop.offers.find(o)
	refresh()
	build_panel.focus_first_slot()


func _cancel_replace() -> void:
	if _replacing == null:
		return
	var at := _replacing_index
	_replacing = null
	_replacing_index = -1
	refresh()
	_focus_card(maxi(0, at))


func _on_replace_slot(index: int) -> void:
	if _replacing == null:
		return
	var result := sim.shop.apply(ShopResult.REPLACE, sim, _replacing, index)
	if not result.ok:
		_flash_block(result.reason)
		return
	_replacing = null
	_replacing_index = -1
	refresh()
	_focus_card(0)


func _on_upgrade_weapon(index: int) -> void:
	var result := sim.shop.apply(ShopResult.UPGRADE, sim, null, index)
	if result.ok:
		refresh()
		build_panel.focus_upgrade(index)
	else:
		_flash_block(result.reason)


func _on_evolve_weapon(index: int) -> void:
	var result := sim.shop.apply(ShopResult.EVOLVE, sim, null, index)
	if result.ok:
		refresh()
		build_panel.focus_upgrade(index)
	else:
		_flash_block(result.reason)


# Blocked clicks point at the resource that is missing, instead of only reading "can't buy".
func _flash_block(reason: StringName) -> void:
	match reason:
		&"poor":
			UiTheme.flash(_materials)
		&"full":
			build_panel.flash_slots()
		&"maxed":
			build_panel.flash_items()


func _on_reroll() -> void:
	_replacing = null
	_replacing_index = -1
	var result := sim.shop.apply(ShopResult.REROLL, sim)
	if result.ok:
		refresh()
		if reroll_button.disabled:
			_focus_card(0)
	else:
		_flash_block(result.reason)


func _on_undo() -> void:
	if sim == null:
		return
	_replacing = null
	_replacing_index = -1
	var result := sim.shop.undo(sim)
	if not result.ok:
		_on_history_changed(false)
		return
	refresh()
	if not undo_button.disabled:
		undo_button.grab_focus()
	else:
		_focus_card(0)


func _on_history_changed(can_undo: bool) -> void:
	if undo_button != null:
		undo_button.disabled = not can_undo


func drag_payload_for(o: Offer) -> Variant:
	if sim == null or not visible or sim.phase != Sim.Phase.SHOP:
		return null
	if o == null or not sim.shop.offers.has(o) or o.sold:
		return null
	return {"kind": &"shop_offer", "shop_ui": self, "offer": o}


func resolve_drag_offer(data: Variant) -> Offer:
	if sim == null or not visible or sim.phase != Sim.Phase.SHOP or not (data is Dictionary):
		return null
	var payload: Dictionary = data
	if payload.get("kind", &"") != &"shop_offer" or payload.get("shop_ui") != self:
		return null
	var candidate := payload.get("offer") as Offer
	if candidate == null or candidate.sold or not sim.shop.offers.has(candidate):
		return null
	return candidate


func quote_drop(data: Variant, target_kind: StringName, index: int = -1) -> ShopResult:
	build_panel.clear_drop_highlights()
	var o := resolve_drag_offer(data)
	if o == null:
		var invalid := ShopResult.failure(&"", &"invalid")
		_show_drop_quote(invalid)
		return invalid
	var result: ShopResult
	match target_kind:
		&"weapon_slot":
			if not o.is_weapon() or index < 0 or index >= sim.player.weapons.size():
				result = ShopResult.failure(ShopResult.REPLACE, &"invalid")
			else:
				result = sim.shop.quote(ShopResult.REPLACE, sim, o, index)
		&"empty_weapon":
			if not o.is_weapon() or sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS:
				result = ShopResult.failure(ShopResult.BUY, &"invalid")
			else:
				result = sim.shop.quote(ShopResult.BUY, sim, o)
		&"items":
			if o.is_weapon():
				result = ShopResult.failure(ShopResult.BUY, &"invalid")
			else:
				result = sim.shop.quote(ShopResult.BUY, sim, o)
		_:
			result = ShopResult.failure(&"", &"invalid")
	_show_drop_quote(result)
	return result


func clear_drop_hint() -> void:
	if _footer != null:
		_footer.text = _weapon_detail if not _weapon_detail.is_empty() else Loc.t("shop.keys")


func _show_drop_quote(result: ShopResult) -> void:
	if _footer == null or result == null:
		return
	if not result.ok:
		_footer.text = _drop_reason_text(result.reason)
		return
	if result.action == ShopResult.REPLACE:
		if result.cost < 0:
			_footer.text = Loc.t("shop.quote_refund", [absi(result.cost)])
		elif result.cost == 0:
			_footer.text = Loc.t("shop.quote_replace_free")
		else:
			_footer.text = Loc.t("shop.quote_replace", [result.cost])
	else:
		_footer.text = Loc.t("shop.quote_buy", [result.cost])


func _drop_reason_text(reason: StringName) -> String:
	match reason:
		&"poor":
			return Loc.t("shop.drop_poor")
		&"full":
			return Loc.t("shop.full")
		&"maxed":
			return Loc.t("shop.maxed")
		&"sold":
			return Loc.t("shop.sold")
		_:
			return Loc.t("shop.drop_invalid")


func apply_drop(data: Variant, target_kind: StringName, index: int = -1) -> ShopResult:
	var quoted := quote_drop(data, target_kind, index)
	if not quoted.ok:
		_flash_drop_failure(target_kind, index, quoted.reason)
		return quoted
	var o := resolve_drag_offer(data)
	# Re-resolve immediately before applying: undo/reroll reconstructs offers and
	# makes any payload from the previous batch stale.
	if o == null:
		return ShopResult.failure(quoted.action, &"invalid")
	var result := sim.shop.apply(quoted.action, sim, o, index)
	if not result.ok:
		_flash_drop_failure(target_kind, index, result.reason)
		return result
	_replacing = null
	_replacing_index = -1
	refresh()
	if target_kind == &"empty_weapon":
		build_panel.settle_target(&"weapon_slot", sim.player.weapons.size() - 1)
	else:
		build_panel.settle_target(target_kind, index)
	return result


func _flash_drop_failure(target_kind: StringName, index: int, reason: StringName) -> void:
	_flash_block(reason)
	if target_kind == &"weapon_slot" and index >= 0 and index < build_panel.slot_drop_targets.size():
		build_panel.slot_drop_targets[index].reject()
	elif target_kind == &"items" and build_panel.items_drop_target != null:
		build_panel.items_drop_target.reject()
	elif build_panel.empty_drop_target != null:
		build_panel.empty_drop_target.reject()


func _disconnect_shop() -> void:
	if _connected_shop != null and _connected_shop.shop_history_changed.is_connected(_on_history_changed):
		_connected_shop.shop_history_changed.disconnect(_on_history_changed)
	_connected_shop = null


func _on_discard(take: EchoTake) -> void:
	sim.discard_take(take)
	refresh()
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_merge(a: EchoTake, b: EchoTake) -> void:
	var merged := sim.merge_takes(a, b)
	refresh()
	if merged == null:
		return
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_start() -> void:
	if sim.can_start_wave():
		_replacing = null
		_replacing_index = -1
		visible = false
		start_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _replacing != null and event.is_action_pressed(&"ui_cancel"):
		_cancel_replace()
		accept_event()


func _focus_card(from: int) -> void:
	var cards := offers_box.get_children()
	for i in cards.size():
		var card := cards[(from + i) % cards.size()] as OfferCard
		if not card.disabled:
			card.grab_focus()
			return
	for b: Button in [start_button, undo_button, reroll_button]:
		if not b.disabled:
			b.grab_focus()
			return


# A small token flies from the arena centre into the newly recorded take's row: the wave
# is visibly "collected" rather than just appearing in a list.
func _fly_take_token() -> void:
	if not is_inside_tree() or _overlay == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible or sim == null:
		return
	var target := echo_panel.arrival_point()
	if target == Vector2.ZERO:
		return
	var token := ColorRect.new()
	token.color = Color(echo_panel.newest_tint(), 0.95)
	token.size = Vector2(10.0, 10.0)
	token.rotation = PI * 0.25
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.position = Vector2(640.0, 380.0) - token.size * 0.5
	_overlay.add_child(token)
	var tween := token.create_tween()
	tween.tween_property(token, "position", target - token.size * 0.5, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(token, "scale", Vector2(0.6, 0.6), 0.55)
	tween.chain().tween_property(token, "modulate:a", 0.0, 0.12)
	tween.tween_callback(token.queue_free)
