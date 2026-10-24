class_name ShopUi
extends Control

signal start_requested

const MAX_PENDING_FEEDBACK := 8
const FEEDBACK_EXPIRY_MSEC := 800

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
var _contract_panel: PanelContainer
var _contract_label: Label
var _contract_button: Button
var _overlay: Control
var _replacing: Offer
var _replacing_index: int = -1
var _connected_shop: Shop
var _connected_sim: Sim
var _weapon_detail := ""
var _pending_feedback: Dictionary = {}
var _feedback_epoch := 0
var _refresh_generation := 0
var reduced_effects := false
var last_feedback: Dictionary = {}
var material_feedback_runs := 0
var _material_feedback_tween: Tween


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
	build_panel.sell_requested.connect(_on_sell_weapon)
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
	_connected_shop.shop_action_resolved.connect(_on_shop_action_resolved)
	_connected_sim = sim
	_connected_sim.weapon_changed.connect(_on_weapon_changed)
	material_feedback_runs = 0
	last_feedback.clear()
	visible = true
	_replacing = null
	_replacing_index = -1
	refresh(true)
	_fly_take_token()
	# If the bank is over capacity, the discard is the only legal action: put focus there.
	if sim.bank.overflow(sim.echo_capacity()) > 0 and echo_panel.focus_first_discard():
		return
	_focus_card(0)


func close_session() -> void:
	_disconnect_shop()
	visible = false
	sim = null
	_replacing = null
	_replacing_index = -1
	_weapon_detail = ""
	if offers_box != null:
		UiTheme.clear(offers_box)
	if build_panel != null:
		build_panel.close_session()
	if echo_panel != null:
		echo_panel.close_session()
	if _overlay != null:
		UiTheme.clear(_overlay)
	if _footer != null:
		_footer.text = Loc.t("shop.keys")


func refresh(animate_echo: bool = false) -> void:
	_refresh_generation += 1
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
		card.lock_toggled.connect(_on_lock_offer)
	var cost := sim.shop.reroll_cost(sim.wave)
	reroll_button.text = Loc.t("shop.reroll", [cost])
	reroll_button.disabled = sim.player.materials < cost
	undo_button.text = Loc.t("shop.undo")
	undo_button.disabled = not sim.shop.can_undo()
	start_button.text = Loc.t("shop.start", [sim.wave + 1])
	start_button.disabled = not sim.can_start_wave()
	var over := sim.bank.overflow(sim.echo_capacity())
	var notices: Array[String] = []
	if over > 0:
		notices.append(Loc.t("shop.over", [over]))
	if sim.last_contract_done:
		notices.append(Loc.t("contract.result_success", [sim.last_contract_reward])
				if sim.last_contract_success else Loc.t("contract.result_fail"))
	_warning.text = "\n".join(notices)
	_refresh_contract()
	var replace_with := ""
	var chooser := Callable()
	if _replacing != null:
		replace_with = Loc.weapon_name(_replacing.id())
		chooser = _on_replace_slot
	_footer.text = Loc.t("shop.keys")
	build_panel.refresh(sim, replace_with, chooser, quote_drop, apply_drop, clear_drop_hint)
	echo_panel.refresh(sim, animate_echo and not reduced_effects)
	call_deferred("_flush_feedback_deferred", _feedback_epoch, _refresh_generation)


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
	_contract_panel = _build_contract_panel()
	column.add_child(_contract_panel)
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


func _build_contract_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			UiTheme.box(Color(0.05, 0.07, 0.1, 0.92), Color(UiTheme.ACCENT, 0.35), 1, 5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_contract_label = UiTheme.label("", 11, UiTheme.DIM)
	_contract_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_contract_label)
	_contract_button = Button.new()
	_contract_button.custom_minimum_size = Vector2(64.0, 28.0)
	_contract_button.add_theme_font_size_override("font_size", 10)
	_contract_button.pressed.connect(_on_accept_contract)
	row.add_child(_contract_button)
	panel.visible = false
	return panel


func _refresh_contract() -> void:
	if _contract_panel == null:
		return
	var contract := sim.shop.contract
	if contract == null:
		_contract_panel.visible = false
		return
	var text := Loc.t("contract.title") + " · "
	match contract.kind:
		AnomalyContract.CLEAN:
			text += Loc.t("contract.clean", [contract.deposit, contract.reward])
		AnomalyContract.CLEAR:
			text += Loc.t("contract.clear", [contract.target, contract.deposit, contract.reward])
		AnomalyContract.HUNT:
			text += Loc.t("contract.hunt", [contract.deposit, contract.reward])
	var active := contract.accepted or sim.active_contract == contract
	if active:
		text += " · " + Loc.t("contract.active")
	_contract_label.text = text
	_contract_panel.visible = true
	if active:
		_contract_button.text = Loc.t("contract.active")
		_contract_button.disabled = true
	elif sim.player.materials < contract.deposit:
		_contract_button.text = Loc.t("contract.poor", [contract.deposit])
		_contract_button.disabled = true
	else:
		_contract_button.text = Loc.t("contract.accept")
		_contract_button.disabled = false


func _on_accept_contract() -> void:
	if sim == null or not sim.shop.accept_contract(sim):
		return
	refresh()
	_focus_card(0)


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
		card.reject(reduced_effects)
		_flash_block(reason)
		return
	var index := sim.shop.offers.find(o)
	var result := sim.shop.apply(ShopResult.BUY, sim, o)
	if result.ok:
		refresh()
		_focus_card(index)
	else:
		card.reject(reduced_effects)
		_flash_block(result.reason)


func _on_lock_offer(o: Offer) -> void:
	if sim == null or not sim.shop.toggle_lock(sim, o):
		return
	var index := maxi(0, sim.shop.offers.find(o))
	refresh()
	_focus_card(index)


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
		if not build_panel.focus_upgrade(index):
			undo_button.grab_focus()
	else:
		_flash_block(result.reason)


func _on_evolve_weapon(index: int) -> void:
	var result := sim.shop.apply(ShopResult.EVOLVE, sim, null, index)
	if result.ok:
		refresh()
		if not build_panel.focus_upgrade(index):
			undo_button.grab_focus()
	else:
		_flash_block(result.reason)


func _on_sell_weapon(index: int) -> void:
	var result := sim.shop.apply(ShopResult.SELL, sim, null, index)
	if result.ok:
		var next := mini(index, sim.player.weapons.size() - 1)
		refresh()
		if not build_panel.focus_upgrade(next):
			undo_button.grab_focus()
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
		&"last":
			build_panel.flash_slots()


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


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	if echo_panel != null:
		echo_panel.set_reduced_effects(on)
	if on:
		reset_feedback()
		if _overlay != null:
			UiTheme.clear(_overlay)


func pending_feedback_count() -> int:
	return _pending_feedback.size()


func flush_feedback() -> void:
	_flush_feedback_deferred(_feedback_epoch, _refresh_generation)


func reset_feedback() -> void:
	_pending_feedback.clear()
	last_feedback.clear()
	if build_panel != null:
		build_panel.reset_feedback()
	if _material_feedback_tween != null and _material_feedback_tween.is_valid():
		_material_feedback_tween.kill()
	_material_feedback_tween = null
	if _materials != null:
		_materials.scale = Vector2.ONE
		_materials.modulate = Color.WHITE


func _on_weapon_changed(info: WeaponChangeInfo) -> void:
	if info == null or not info.ok:
		return
	var removed := info.before_id != &"" and info.after_id == &""
	var key := StringName("removed_%d" % info.index) if removed \
			else StringName("slot_%d" % info.index)
	_queue_feedback(key, {
		"kind": &"weapon_removed" if removed else &"weapon", "index": info.index,
		"reverse": info.reason == ShopResult.UNDO, "action": info.reason,
		"before_id": info.before_id, "after_id": info.after_id,
	})


func _on_shop_action_resolved(result: ShopResult) -> void:
	if result == null or not result.ok:
		return
	var reverse := result.action == ShopResult.UNDO
	if result.before_state != null and result.after_state != null:
		if result.before_state.items != result.after_state.items:
			_queue_feedback(&"items", {
				"kind": &"items", "index": -1, "reverse": reverse,
				"action": result.action,
			})
		if result.before_state.materials != result.after_state.materials:
			_queue_feedback(&"materials", {
				"kind": &"materials", "index": -1, "reverse": reverse,
				"action": result.action,
				"refund": result.action == ShopResult.SELL and result.cost < 0,
			})
	elif result.action == ShopResult.REROLL and result.cost != 0:
		_queue_feedback(&"materials", {
			"kind": &"materials", "index": -1, "reverse": false,
			"action": result.action,
		})


func _queue_feedback(key: StringName, data: Dictionary) -> void:
	data["queued_at_msec"] = Time.get_ticks_msec()
	if not _pending_feedback.has(key) and _pending_feedback.size() >= MAX_PENDING_FEEDBACK:
		_pending_feedback.erase(_pending_feedback.keys()[0])
	_pending_feedback[key] = data


func _flush_feedback_deferred(epoch: int, generation: int) -> void:
	if epoch != _feedback_epoch or generation != _refresh_generation:
		return
	if not is_inside_tree() or not visible or sim == null or sim != _connected_sim:
		_pending_feedback.clear()
		return
	var now := Time.get_ticks_msec()
	var pending: Array = _pending_feedback.values()
	_pending_feedback.clear()
	for raw: Variant in pending:
		var data: Dictionary = raw
		if now - int(data.get("queued_at_msec", now)) > FEEDBACK_EXPIRY_MSEC:
			continue
		last_feedback = data.duplicate()
		match data.get("kind", &""):
			&"weapon":
				build_panel.pulse_weapon_slot(int(data.get("index", -1)),
						bool(data.get("reverse", false)), reduced_effects)
			&"weapon_removed":
				build_panel.pulse_removed_weapon(bool(data.get("reverse", false)), reduced_effects)
			&"items":
				build_panel.pulse_items(bool(data.get("reverse", false)), reduced_effects)
			&"materials":
				_pulse_materials(bool(data.get("reverse", false)))


func _pulse_materials(reverse: bool) -> void:
	if _materials == null:
		return
	if _material_feedback_tween != null and _material_feedback_tween.is_valid():
		_material_feedback_tween.kill()
	material_feedback_runs += 1
	_materials.pivot_offset = _materials.size * 0.5
	_materials.modulate = Color(1.0, 0.65, 0.9) if reverse else UiTheme.COIN
	_materials.scale = Vector2.ONE if reduced_effects else Vector2(0.96, 0.96)
	_material_feedback_tween = create_tween().set_parallel(true)
	_material_feedback_tween.tween_property(_materials, "modulate", Color.WHITE, 0.2)
	if not reduced_effects:
		_material_feedback_tween.tween_property(_materials, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	return result


func _flash_drop_failure(target_kind: StringName, index: int, reason: StringName) -> void:
	_flash_block(reason)
	if target_kind == &"weapon_slot" and index >= 0 and index < build_panel.slot_drop_targets.size():
		build_panel.slot_drop_targets[index].reject(reduced_effects)
	elif target_kind == &"items" and build_panel.items_drop_target != null:
		build_panel.items_drop_target.reject(reduced_effects)
	elif build_panel.empty_drop_target != null:
		build_panel.empty_drop_target.reject(reduced_effects)


func _disconnect_shop() -> void:
	if _connected_shop != null and _connected_shop.shop_history_changed.is_connected(_on_history_changed):
		_connected_shop.shop_history_changed.disconnect(_on_history_changed)
	if _connected_shop != null and _connected_shop.shop_action_resolved.is_connected(_on_shop_action_resolved):
		_connected_shop.shop_action_resolved.disconnect(_on_shop_action_resolved)
	if _connected_sim != null and _connected_sim.weapon_changed.is_connected(_on_weapon_changed):
		_connected_sim.weapon_changed.disconnect(_on_weapon_changed)
	_connected_shop = null
	_connected_sim = null
	_feedback_epoch += 1
	reset_feedback()


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
	elif echo_panel != null and echo_panel.is_merging() and event.is_action_pressed(&"ui_cancel"):
		echo_panel.cancel_merge()
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


func focus_default() -> void:
	_focus_card(0)


# A small token flies from the arena centre into the newly recorded take's row: the wave
# is visibly "collected" rather than just appearing in a list.
func _fly_take_token() -> void:
	if reduced_effects or not is_inside_tree() or _overlay == null:
		return
	var session_epoch := _feedback_epoch
	await get_tree().process_frame
	await get_tree().process_frame
	if reduced_effects or session_epoch != _feedback_epoch or not visible or sim == null:
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
