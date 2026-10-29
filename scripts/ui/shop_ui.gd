class_name ShopUi
extends Control

signal start_requested
signal receipt_requested

const MAX_PENDING_FEEDBACK := 8
const FEEDBACK_EXPIRY_MSEC := 800
const ON_DARK := Color("dbceab")
const ERROR_ON_DARK := Color("efb08f")

var sim: Sim
var offers_box: GridContainer
var reroll_button: Button
var undo_button: Button
var start_button: Button
var receipt_button: Button
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
var _offers_scroll: ScrollContainer
var _vendor_art: TextureRect
var _vendor_line: Label
var _vendor_tween: Tween
var _vendor_receipt: Control
var vendor_feedback_runs := 0
var last_vendor_reaction: StringName = &"idle"


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.98)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_header())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	columns.add_child(_build_left())
	var dossier := VBoxContainer.new()
	dossier.custom_minimum_size = Vector2(444.0, 0.0)
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.add_theme_constant_override("separation", 14)
	columns.add_child(dossier)
	build_panel = BuildPanel.new()
	build_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_panel.size_flags_stretch_ratio = 1.0
	build_panel.replace_cancelled.connect(_cancel_replace)
	build_panel.upgrade_requested.connect(_on_upgrade_weapon)
	build_panel.evolve_requested.connect(_on_evolve_weapon)
	build_panel.sell_requested.connect(_on_sell_weapon)
	build_panel.detail_changed.connect(_on_weapon_detail)
	dossier.add_child(build_panel)
	echo_panel = EchoPanel.new()
	echo_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	echo_panel.size_flags_stretch_ratio = 1.2
	echo_panel.discard_requested.connect(_on_discard)
	echo_panel.merge_requested.connect(_on_merge)
	echo_panel.repair_requested.connect(_on_repair_echo)
	dossier.add_child(echo_panel)
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
	vendor_feedback_runs = 0
	last_vendor_reaction = &"idle"
	_vendor_line.text = Loc.t("shop.vendor_idle")
	_vendor_line.add_theme_color_override("font_color", ON_DARK)
	last_feedback.clear()
	visible = true
	UiTheme.animate_open(self, reduced_effects)
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
	if receipt_button != null:
		receipt_button.visible = false


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
		card.reduced_effects = reduced_effects
		card.setup(o, sim, o == _replacing, drag_payload_for, clear_drop_hint)
		card.pressed.connect(_on_offer.bind(o, card))
		card.replacement_requested.connect(_begin_replace)
		card.lock_toggled.connect(_on_lock_offer)
	var cost := sim.shop.reroll_cost(sim.wave)
	reroll_button.text = Loc.t("shop.reroll", [cost])
	reroll_button.disabled = sim.player.materials < cost
	undo_button.text = Loc.t("shop.undo")
	undo_button.disabled = not sim.shop.can_undo()
	start_button.text = Loc.t("shop.start", [sim.next_wave_number()])
	start_button.disabled = not sim.can_start_wave()
	var over := sim.bank.overflow(sim.echo_capacity())
	# Give the currently blocking copy decision more room than the equipment archive.
	echo_panel.size_flags_stretch_ratio = 1.6 if over > 0 else 1.15
	build_panel.size_flags_stretch_ratio = 0.8 if over > 0 else 1.0
	var notices: Array[String] = []
	if over > 0:
		notices.append(Loc.t("shop.over", [over]))
	if sim.last_contract_done:
		notices.append(Loc.t("contract.result_success", [sim.last_contract_reward])
				if sim.last_contract_success else Loc.t("contract.result_fail"))
	_warning.text = "\n".join(notices)
	_refresh_contract()
	refresh_receipt()
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
	var tray := PanelContainer.new()
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 12.0
	clear.content_margin_right = 12.0
	clear.content_margin_top = 8.0
	clear.content_margin_bottom = 8.0
	tray.add_theme_stylebox_override("panel", clear)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tray.add_child(box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_warning = UiTheme.label("", 15, ERROR_ON_DARK)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(_warning)
	receipt_button = Button.new()
	receipt_button.custom_minimum_size = Vector2(0.0, 38.0)
	receipt_button.add_theme_font_size_override("font_size", 14)
	receipt_button.pressed.connect(func() -> void: receipt_requested.emit())
	actions.add_child(receipt_button)
	for button: Button in [reroll_button, undo_button, start_button]:
		actions.add_child(button)
	_footer = UiTheme.label(Loc.t("shop.keys"), 13, ON_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.custom_minimum_size = Vector2(0.0, 19.0)
	box.add_child(_footer)
	return tray


func _on_weapon_detail(text: String) -> void:
	if _footer == null:
		return
	_weapon_detail = text
	_footer.text = text if text != "" else Loc.t("shop.keys")


func _build_header() -> Control:
	var panel := PanelContainer.new()
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 12.0
	clear.content_margin_right = 12.0
	clear.content_margin_top = 8.0
	clear.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", clear)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	_title = UiTheme.section_label("", 34, UiTheme.PAPER)
	identity.add_child(_title)
	identity.add_child(UiTheme.label(Loc.t("shop.paper_task"), 13, ON_DARK))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_END
	var paper := UiTheme.paper_panel(UiTheme.PAPER)
	paper.shape = InkStyleBox.Shape.OVAL
	paper.content_margin_left = 22.0
	paper.content_margin_right = 22.0
	paper.content_margin_top = 8.0
	paper.content_margin_bottom = 8.0
	tag.add_theme_stylebox_override("panel", paper)
	_materials = UiTheme.label("", 25, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	tag.add_child(_materials)
	_interest = UiTheme.label("", 13, ON_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(tag)
	right.add_child(_interest)
	row.add_child(right)
	return panel


func _build_left() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(610.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.55
	column.add_theme_constant_override("separation", 10)
	column.add_child(_build_supplier())
	_offers_scroll = ScrollContainer.new()
	_offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_offers_scroll.follow_focus = true
	_offers_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_offers_scroll)
	offers_box = GridContainer.new()
	offers_box.columns = 2
	offers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers_box.add_theme_constant_override("h_separation", 12)
	offers_box.add_theme_constant_override("v_separation", 12)
	_offers_scroll.add_child(offers_box)
	_contract_panel = _build_contract_panel()
	column.add_child(_contract_panel)
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(132.0, 42.0)
	reroll_button.pressed.connect(_on_reroll)
	undo_button = Button.new()
	undo_button.custom_minimum_size = Vector2(104.0, 42.0)
	undo_button.tooltip_text = Loc.t("shop.undo_hint")
	undo_button.pressed.connect(_on_undo)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(206.0, 42.0)
	UiTheme.stamp_button(start_button)
	start_button.pressed.connect(_on_start)
	return column


func _build_supplier() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_vendor_art = UiTheme.art_icon(&"shopkeeper", Vector2(122.0, 110.0))
	_vendor_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_vendor_art)
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)
	words.add_child(UiTheme.section_label(Loc.t("shop.offers"), 20, UiTheme.PAPER))
	_vendor_line = UiTheme.label(Loc.t("shop.vendor_idle"), 15, ON_DARK)
	_vendor_line.custom_minimum_size = Vector2(330.0, 0.0)
	_vendor_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_vendor_line)
	return row


func _build_contract_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.PAPER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_contract_label = UiTheme.label("", 13, UiTheme.INK)
	_contract_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_contract_label)
	_contract_button = Button.new()
	_contract_button.custom_minimum_size = Vector2(68.0, 34.0)
	_contract_button.add_theme_font_size_override("font_size", 12)
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
		AnomalyContract.RETIRE:
			text += Loc.t("contract.retire", [contract.deposit, contract.reward])
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
	_focus_offer_lock(index)


func _focus_offer_lock(index: int) -> bool:
	if index < 0 or index >= offers_box.get_child_count():
		return false
	var card := offers_box.get_child(index) as OfferCard
	if card == null or card.lock_button == null or card.lock_button.disabled:
		return false
	card.lock_button.grab_focus()
	return true


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
			_react_vendor(&"poor")
			_footer.text = Loc.t("shop.drop_poor")
			_reject_materials()
		&"full":
			_footer.text = Loc.t("shop.full_reason")
			build_panel.flash_slots(reduced_effects)
		&"maxed":
			_footer.text = Loc.t("shop.maxed")
			build_panel.flash_items(reduced_effects)
		&"last":
			_footer.text = Loc.t("shop.sell_last_reason")
			build_panel.flash_slots(reduced_effects)


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
	if offers_box != null:
		for child in offers_box.get_children():
			var card := child as OfferCard
			if card != null:
				card.reduced_effects = on
				if on:
					card._release_paper()
	if echo_panel != null:
		echo_panel.set_reduced_effects(on)
	if on:
		UiTheme.animate_open(self, true)
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
	_reset_vendor_motion()
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
	# This is the committed transaction signal, never a pointer-down or drag preview.
	if visible and sim != null and sim == _connected_sim:
		match result.action:
			ShopResult.REROLL: _react_vendor(&"reroll", result)
			ShopResult.UNDO: _react_vendor(&"undo", result)
			ShopResult.SELL: _react_vendor(&"sell", result)
			ShopResult.ECHO_MERGE: _react_vendor(&"merge", result)
			ShopResult.ECHO_DISCARD: _react_vendor(&"discard", result)
			ShopResult.ECHO_REPAIR: _react_vendor(&"repair", result)
			ShopResult.BUY, ShopResult.REPLACE, ShopResult.UPGRADE, ShopResult.EVOLVE:
				_react_vendor(&"buy", result)
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


func _react_vendor(kind: StringName, result: ShopResult = null) -> void:
	if not visible or sim == null or _vendor_line == null:
		return
	_reset_vendor_motion()
	last_vendor_reaction = kind
	vendor_feedback_runs += 1
	_vendor_line.text = _vendor_text(kind)
	_vendor_line.add_theme_color_override("font_color", ERROR_ON_DARK if kind == &"poor" else ON_DARK)
	if reduced_effects:
		return
	# Only decorative art and the non-interactive speech react. Hit rectangles stay put.
	_set_vendor_pose(2 if kind == &"poor" else (3 if kind == &"buy" else 1))
	_vendor_art.pivot_offset = _vendor_art.size * 0.5
	_vendor_art.scale = Vector2(0.90, 0.94) if kind == &"poor" else Vector2(1.06, 0.94)
	_vendor_tween = create_tween()
	_vendor_tween.tween_property(_vendor_art, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vendor_tween.tween_interval(0.35)
	_vendor_tween.tween_callback(_set_vendor_pose.bind(0))
	if result != null and result.ok:
		_fly_receipt(result)


func _vendor_text(kind: StringName) -> String:
	match kind:
		&"buy": return Loc.t("shop.vendor_buy")
		&"poor": return Loc.t("shop.vendor_poor")
		&"reroll": return Loc.t("shop.vendor_reroll")
		&"undo": return Loc.t("shop.vendor_undo")
		&"sell": return Loc.t("shop.vendor_sell")
		&"merge": return Loc.t("shop.vendor_merge")
		&"discard": return Loc.t("shop.vendor_discard")
		&"repair": return Loc.t("shop.vendor_repair")
	return Loc.t("shop.vendor_idle")


func _reset_vendor_motion() -> void:
	if _vendor_tween != null and _vendor_tween.is_valid():
		_vendor_tween.kill()
	_vendor_tween = null
	if is_instance_valid(_vendor_art):
		_vendor_art.scale = Vector2.ONE
		_set_vendor_pose(0)
	if is_instance_valid(_vendor_receipt):
		_vendor_receipt.get_parent().remove_child(_vendor_receipt)
		_vendor_receipt.queue_free()
	_vendor_receipt = null


func _set_vendor_pose(index: int) -> void:
	if _vendor_art == null or not (_vendor_art.texture is AtlasTexture):
		return
	var atlas := _vendor_art.texture as AtlasTexture
	atlas.region = PresentationAssets.frame_region(&"shopkeeper", index)


func _fly_receipt(result: ShopResult) -> void:
	if _overlay == null or _vendor_art == null or not is_inside_tree():
		return
	var delta := -result.cost
	if result.before_state != null and result.after_state != null:
		delta = result.after_state.materials - result.before_state.materials
	var reverse := delta > 0
	var from_control: Control = _vendor_art if reverse else _materials
	var to_control: Control = _materials if reverse else _vendor_art
	var object_key: StringName = &""
	if result.action == ShopResult.UNDO and result.before_state != null and result.after_state != null:
		var before := result.before_state
		var after := result.after_state
		if before.echoes != after.echoes:
			object_key = &"recording_cartridge"
			from_control = _vendor_art
			to_control = echo_panel
		elif before.weapons != after.weapons or before.weapon_levels != after.weapon_levels:
			object_key = _changed_weapon_key(before, after)
			var restoring := after.weapons.size() >= before.weapons.size()
			from_control = _vendor_art if restoring else build_panel
			to_control = build_panel if restoring else _vendor_art
		elif before.items != after.items:
			for id: StringName in after.items.keys() + before.items.keys():
				var old_count := int(before.items.get(id, 0))
				var new_count := int(after.items.get(id, 0))
				if old_count != new_count:
					object_key = PresentationAssets.item_key(Content.item(id))
					from_control = _vendor_art if new_count > old_count else build_panel
					to_control = build_panel if new_count > old_count else _vendor_art
					break
		else:
			from_control = _vendor_art if delta > 0 else _materials
			to_control = _materials if delta > 0 else _vendor_art
	if result.action == ShopResult.ECHO_DISCARD or result.action == ShopResult.ECHO_MERGE:
		from_control = echo_panel
	if result.action != ShopResult.UNDO and not reverse and result.offer_id != &"":
		for child in offers_box.get_children():
			var card := child as OfferCard
			if card != null and card.offer != null and card.offer.id() == result.offer_id:
				from_control = card.price_tag
				break
	var convert := _overlay.get_global_transform().affine_inverse()
	var origin := convert * from_control.get_global_rect().get_center()
	var destination := convert * to_control.get_global_rect().get_center()
	var receipt := PanelContainer.new()
	receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.paper_panel(UiTheme.PAPER)
	style.shape = InkStyleBox.Shape.TAG
	style.variant = 4
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	receipt.add_theme_stylebox_override("panel", style)
	if object_key != &"":
		receipt.add_child(UiTheme.art_icon(object_key, Vector2(34.0, 26.0)))
	elif delta != 0:
		var label := UiTheme.label(("+" if delta > 0 else "−") + str(absi(delta)), 19, UiTheme.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		receipt.add_child(label)
	else:
		receipt.add_child(UiTheme.cartridge_icon(Vector2(30.0, 22.0)))
	receipt.position = origin - Vector2(24.0, 16.0)
	receipt.size = Vector2(48.0, 32.0)
	receipt.pivot_offset = receipt.size * 0.5
	_overlay.add_child(receipt)
	receipt.set_meta(&"shop_receipt_source", from_control)
	receipt.set_meta(&"shop_receipt_target", to_control)
	receipt.set_meta(&"shop_receipt_object", object_key)
	_vendor_receipt = receipt
	var travel := receipt.create_tween().set_parallel(true)
	travel.tween_property(receipt, "position", destination - Vector2(24.0, 16.0), 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(receipt, "scale", Vector2(0.25, 0.25), 0.22)
	travel.tween_property(receipt, "modulate:a", 0.0, 0.18).set_delay(0.04)
	travel.chain().tween_callback(receipt.queue_free)


func _changed_weapon_key(before: ShopState, after: ShopState) -> StringName:
	for index in maxi(before.weapons.size(), after.weapons.size()):
		var old_id := before.weapons[index] if index < before.weapons.size() else &""
		var new_id := after.weapons[index] if index < after.weapons.size() else &""
		var old_level := before.weapon_levels[index] if index < before.weapon_levels.size() else -1
		var new_level := after.weapon_levels[index] if index < after.weapon_levels.size() else -1
		if old_id != new_id or old_level != new_level:
			return PresentationAssets.weapon_key(Content.weapon(new_id if new_id != &"" else old_id))
	return &""


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
	if reduced_effects:
		_materials.scale = Vector2.ONE
		_materials.modulate = Color.WHITE
		return
	_materials.pivot_offset = _materials.size * 0.5
	_materials.modulate = Color(0.88, 0.78, 0.92) if reverse else Color(1.0, 0.86, 0.62)
	_materials.scale = Vector2.ONE if reduced_effects else Vector2(0.96, 0.96)
	_material_feedback_tween = create_tween().set_parallel(true)
	_material_feedback_tween.tween_property(_materials, "modulate", Color.WHITE, 0.2)
	if not reduced_effects:
		_material_feedback_tween.tween_property(_materials, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reject_materials() -> void:
	if _material_feedback_tween != null and _material_feedback_tween.is_valid():
		_material_feedback_tween.kill()
	_material_feedback_tween = null
	_materials.modulate = Color.WHITE
	if reduced_effects:
		return
	_materials.modulate = Color(1.0, 0.74, 0.63)
	_material_feedback_tween = create_tween()
	_material_feedback_tween.tween_property(_materials, "modulate", Color.WHITE, 0.2)


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
	var result := sim.shop.discard_echo(sim, take)
	if not result.ok:
		return
	refresh()
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_repair_echo(take: EchoTake) -> void:
	var result := sim.shop.repair_echo(sim, take)
	if not result.ok:
		return
	refresh()
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_merge(a: EchoTake, b: EchoTake) -> void:
	var result := sim.shop.merge_echoes(sim, a, b)
	if not result.ok:
		return
	refresh()
	echo_panel.confirm_merge()
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
	if sim != null and sim.bank.overflow(sim.echo_capacity()) > 0 \
			and echo_panel.focus_first_discard():
		return
	_focus_card(0)


# A small token flies from the arena centre into the newly recorded take's row: the wave
# is visibly "collected" rather than just appearing in a list.
func _fly_take_token() -> void:
	if reduced_effects or not is_inside_tree() or _overlay == null:
		return
	_fly_take_token_after_layout(_feedback_epoch, 2)


func _fly_take_token_after_layout(session_epoch: int, frames: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or reduced_effects \
			or session_epoch != _feedback_epoch or not visible or sim == null:
		return
	if frames > 0:
		var next_frame := _fly_take_token_after_layout.bind(session_epoch, frames - 1)
		if not get_tree().process_frame.is_connected(next_frame):
			get_tree().process_frame.connect(next_frame, CONNECT_ONE_SHOT)
		return
	var arrival := echo_panel.arrival_point()
	if arrival == Vector2.ZERO:
		return
	var target := _overlay.get_global_transform().affine_inverse() * arrival
	var token := UiTheme.cartridge_icon(Vector2(34.0, 27.0))
	token.size = Vector2(34.0, 27.0)
	token.rotation = -0.14
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.position = _arrival_origin() - token.size * 0.5
	_overlay.add_child(token)
	var tween := token.create_tween()
	tween.tween_property(token, "position", target - token.size * 0.5, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(token, "scale", Vector2(0.6, 0.6), 0.55)
	tween.parallel().tween_property(token, "rotation", 0.0, 0.55)
	tween.chain().tween_property(token, "modulate:a", 0.0, 0.12)
	tween.tween_callback(token.queue_free)


func _arrival_origin() -> Vector2:
	# Shop and ArenaView share their canvas, but not necessarily their transforms.
	# Convert the simulated arena centre through the actual scene transforms.
	var ancestor: Node = get_parent()
	while ancestor != null:
		for child in ancestor.get_children():
			if child is ArenaView:
				return _overlay.get_global_transform_with_canvas().affine_inverse() \
						* ((child as ArenaView).get_global_transform_with_canvas() * Sim.ARENA.get_center())
		ancestor = ancestor.get_parent()
	return _overlay.get_global_transform_with_canvas().affine_inverse() \
			* (get_global_transform_with_canvas() * Sim.VIEWPORT.get_center())


func refresh_receipt() -> void:
	if receipt_button == null:
		return
	var receipt := StoryLedger.receipt(sim)
	receipt_button.visible = not receipt.is_empty()
	if receipt.is_empty():
		return
	var title := Loc.t(receipt.name_key)
	var body := Loc.t(receipt.body_key)
	receipt_button.text = Loc.t("story.read_receipt", [title])
	receipt_button.tooltip_text = body
	receipt_button.accessibility_name = title
	receipt_button.accessibility_description = body
