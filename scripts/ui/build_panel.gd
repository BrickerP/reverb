class_name BuildPanel
extends PanelContainer

signal replace_cancelled
signal upgrade_requested(index: int)
signal evolve_requested(index: int)
signal selection_changed
signal workshop_requested(index: int)
signal passives_requested(index: int)
signal stats_requested(index: int)
var show_heading := false
var weapons_label: Label
var replacing: bool = false
var marked_slot := -1
var slot_drop_targets: Array[ShopDropTarget] = []
var empty_drop_target: ShopDropTarget
var items_drop_target: ShopDropTarget

var upgrade_button: Button
var manage_button: Button
var stats_button: Button
var passives_button: Button
var passive_buttons: Array[Button] = []

var _box: VBoxContainer
var _weapons_row: Control
var _slot_buttons: Array[Button] = []
var _replacement_name := ""
var _generation := 0
var _cards: Array[PanelContainer] = []
var _card_weapons: Array[WeaponDef] = []
var _card_levels: Array[int] = []
var _selected := 0
var _sim: Sim
var _on_choose := Callable()
var _quote_drop := Callable()
var _apply_drop := Callable()
var _clear_drop := Callable()
var _section_feedback: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 0.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var surface_source := UiTheme.surface_panel()
	if surface_source != null:
		var surface := surface_source.duplicate() as InkStyleBox
		surface.content_margin_left = 12.0
		surface.content_margin_right = 12.0
		surface.content_margin_top = 6.0
		surface.content_margin_bottom = 6.0
		add_theme_stylebox_override("panel", surface)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_box)


func refresh(sim: Sim, replace_with: String = "", on_choose: Callable = Callable(),
		quote_drop: Callable = Callable(), apply_drop: Callable = Callable(),
		clear_drop: Callable = Callable()) -> void:
	reset_feedback()
	_generation += 1
	_sim = sim
	_on_choose = on_choose
	_quote_drop = quote_drop
	_apply_drop = apply_drop
	_clear_drop = clear_drop
	replacing = replace_with != ""
	_replacement_name = replace_with
	var selected_before := _selected
	UiTheme.clear(_box)
	_slot_buttons.clear()
	upgrade_button = null
	manage_button = null
	stats_button = null
	passives_button = null
	_cards.clear()
	_card_weapons.clear()
	_card_levels.clear()
	slot_drop_targets.clear()
	empty_drop_target = null
	items_drop_target = null
	# The page title already identifies the inventory. Keep statistics on the
	# fixed bottom row instead of spending a second header above six slots.
	weapons_label = null
	if show_heading:
		weapons_label = UiTheme.label(Loc.t("shop.weapons", [sim.player.weapons.size(), Content.MAX_WEAPON_SLOTS]), 17)
		_box.add_child(weapons_label)
	_weapons_row = _weapon_chips(sim.player, sim)
	_box.add_child(_weapons_row)
	_build_actions()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	stats_button = Button.new()
	stats_button.text = Loc.t("shop.build_details")
	stats_button.pressed.connect(func() -> void: stats_requested.emit(_selected))
	actions.add_child(stats_button)
	passive_buttons.clear()
	var limit := 8 if show_heading else 4
	for id: StringName in sim.player.items.keys().slice(0, limit):
		var button := Button.new()
		button.set_meta(&"item_id", id)
		button.accessibility_name = Loc.item_name(id)
		button.accessibility_description = Loc.item_desc(Content.item(id), sim)
		button.custom_minimum_size = Vector2(26, 28)
		var icon := UiTheme.item_icon(Content.item(id), Vector2(24, 24))
		button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		actions.add_child(button)
		passive_buttons.append(button)
	passives_button = Button.new()
	passives_button.text = Loc.t("workshop.passives", [sim.player.items.size()])
	passives_button.pressed.connect(func() -> void: passives_requested.emit(_selected))
	actions.add_child(passives_button)
	items_drop_target = _empty_target(&"items", Loc.t("shop.passive_drop"))
	items_drop_target.custom_minimum_size.y = 26.0
	actions.add_child(items_drop_target)
	if replacing:
		var cancel := Button.new()
		cancel.text = Loc.t("shop.cancel")
		cancel.pressed.connect(replace_cancelled.emit)
		actions.add_child(cancel)
	_box.add_child(actions)
	_selected = clampi(selected_before, 0, maxi(0, sim.player.weapons.size() - 1))
	_select(_selected)
	for button: Button in find_children("*", "Button", true, false):
		if not _slot_buttons.has(button) and not passive_buttons.has(button):
			WorkshopUi.fit_button(button, 13, 28.0)
	for button in _slot_buttons:
		button.custom_minimum_size.y = 112.0 if replacing else 78.0



func close_session() -> void:
	_generation += 1
	reset_feedback()
	_sim = null
	_on_choose = Callable()
	UiTheme.clear(_box)
	weapons_label = null
	replacing = false
	_replacement_name = ""
	_weapons_row = null
	_slot_buttons.clear()
	upgrade_button = null
	manage_button = null
	stats_button = null
	passives_button = null
	_cards.clear()
	_card_weapons.clear()
	_card_levels.clear()
	slot_drop_targets.clear()
	empty_drop_target = null
	items_drop_target = null
	_quote_drop = Callable()
	_apply_drop = Callable()
	_clear_drop = Callable()
	passive_buttons.clear()
	_selected = 0


func focus_first_slot() -> bool:
	if _slot_buttons.is_empty():
		return false
	_slot_buttons[0].grab_focus()
	return true


func focus_slot(index: int) -> bool:
	if index < 0 or index >= _slot_buttons.size():
		return false
	_slot_buttons[index].grab_focus()
	return true


func focus_upgrade(index: int) -> bool:
	if index < 0 or index >= _cards.size():
		return false
	_select(index)
	if upgrade_button == null or upgrade_button.disabled or not upgrade_button.is_visible_in_tree():
		return false
	upgrade_button.grab_focus()
	return true


func flash_slots(reduced: bool = false) -> void:
	_reject_section(weapons_label, _weapons_row, reduced)


func flash_items(reduced: bool = false) -> void:
	_reject_section(passives_button, items_drop_target, reduced)


func _reject_section(title: Control, contents: Control, reduced: bool) -> void:
	_reset_section_feedback()
	if reduced:
		return
	_section_feedback = create_tween().set_parallel(true)
	for control: Control in [title, contents]:
		if is_instance_valid(control):
			control.modulate = Color(1.0, 0.74, 0.63)
			_section_feedback.tween_property(control, "modulate", Color.WHITE, 0.22)


func _reset_section_feedback() -> void:
	if _section_feedback != null and _section_feedback.is_valid():
		_section_feedback.kill()
	_section_feedback = null
	for control: Control in [weapons_label, passives_button, _weapons_row, items_drop_target]:
		if is_instance_valid(control):
			control.modulate = Color.WHITE


func _weapon_chips(pl: PlayerState, sim: Sim) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for i in Content.MAX_WEAPON_SLOTS:
		if i < pl.weapons.size():
			grid.add_child(_weapon_card(pl.weapons[i], pl.level_at(i), i, pl, sim))
		else:
			var empty := _empty_target(&"empty_weapon", Loc.t("shop.empty_weapon", [i + 1]))
			empty.custom_minimum_size = Vector2(0.0, 44.0)
			grid.add_child(empty)
			if empty_drop_target == null:
				empty_drop_target = empty
	return grid


func _weapon_card(w: WeaponDef, level: int, index: int, _pl: PlayerState, sim: Sim) -> Control:
	var card := ShopDropTarget.new()
	card.configure(&"weapon_slot", index, _quote_drop, _apply_drop, _clear_drop)
	card.accessibility_name = Loc.weapon_name(w.id)
	card.accessibility_description = _detail_text_for(w, level)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_style(card, w, false)
	var select := Button.new()
	select.custom_minimum_size.y = 112.0 if replacing else 78.0
	select.accessibility_name = Loc.weapon_name(w.id) + " · " + Loc.t("shop.level", [level + 1])
	for state in ["normal", "hover", "pressed", "disabled"]:
		select.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var face := VBoxContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_constant_override("separation", 2)
	var art_row := HBoxContainer.new()
	art_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_row.add_theme_constant_override("separation", 1)
	var icon := UiTheme.weapon_icon(w, Vector2(64, 48))
	icon.name = "WeaponArt"
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_row.add_child(icon)
	var grade := UiTheme.label(Loc.t("shop.level", [level + 1]), 11, UiTheme.ACCENT)
	grade.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	art_row.add_child(grade)
	face.add_child(art_row)
	var title := UiTheme.label(Loc.weapon_name(w.id), 13, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	if index == 0 and weapons_label == null:
		weapons_label = title
	title.name = "WeaponName"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	face.add_child(title)
	if index == marked_slot:
		card.accessibility_description += " · " + Loc.t("shop.just_equipped")
	if replacing:
		var refund := UiTheme.label(Loc.t("shop.refund_materials", [Shop.resale_for(sim, index)]), 12, UiTheme.COIN)
		refund.name = "TradeInValue"
		refund.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		face.add_child(refund)
	select.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 3
	face.offset_right = -3
	face.offset_top = 3
	face.offset_bottom = -3
	card.add_child(select)
	select.pressed.connect(func() -> void:
		_select(index)
		if replacing and _on_choose.is_valid():
			_on_choose.call(index))
	select.focus_entered.connect(func() -> void: _select(index))
	_slot_buttons.append(select)
	_cards.append(card)
	_card_weapons.append(w)
	_card_levels.append(level)
	slot_drop_targets.append(card)
	return card


func _build_actions() -> void:
	var generation := _generation
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_box.add_child(actions)
	upgrade_button = Button.new()
	upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_button.disabled = true
	upgrade_button.pressed.connect(func() -> void:
		if _sim == null or generation != _generation or replacing or upgrade_button.disabled:
			return
		if _card_levels[_selected] >= WeaponDef.MAX_LEVEL:
			evolve_requested.emit(_selected)
		else:
			upgrade_requested.emit(_selected))
	actions.add_child(upgrade_button)
	manage_button = Button.new()
	manage_button.text = Loc.t("shop.manage")
	manage_button.disabled = _cards.is_empty()
	manage_button.pressed.connect(func() -> void: workshop_requested.emit(_selected))
	actions.add_child(manage_button)


func _empty_target(kind: StringName, text: String) -> ShopDropTarget:
	var target := ShopDropTarget.new()
	target.configure(kind, -1, _quote_drop, _apply_drop, _clear_drop)
	target.accessibility_name = text
	target.tooltip_text = text
	target.custom_minimum_size = Vector2(0.0, 36.0)
	var style := UiTheme.box(UiTheme.SURFACE, Color(UiTheme.EDGE, 0.35), 1, 18)
	style.shape = InkStyleBox.Shape.TAG
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	target.add_theme_stylebox_override("panel", style)
	var label := UiTheme.label(text, 12, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target.add_child(label)
	return target


func settle_target(kind: StringName, index: int = -1) -> void:
	if kind == &"weapon_slot" and index >= 0 and index < slot_drop_targets.size():
		slot_drop_targets[index].settle()
	elif kind == &"items" and items_drop_target != null:
		items_drop_target.settle()
	elif empty_drop_target != null:
		empty_drop_target.settle()


func pulse_weapon_slot(index: int, reverse: bool = false, reduced: bool = false) -> bool:
	if index >= 0 and index < slot_drop_targets.size():
		slot_drop_targets[index].feedback(reverse, reduced)
		return true
	if empty_drop_target != null:
		empty_drop_target.feedback(reverse, reduced)
		return true
	return false


func pulse_removed_weapon(reverse: bool = false, reduced: bool = false) -> bool:
	if empty_drop_target == null:
		return false
	empty_drop_target.feedback(reverse, reduced)
	return true


func pulse_items(reverse: bool = false, reduced: bool = false) -> bool:
	if items_drop_target == null:
		return false
	items_drop_target.feedback(reverse, reduced)
	return true


func reset_feedback() -> void:
	_reset_section_feedback()
	for target in slot_drop_targets:
		target.reset_feedback()
	if empty_drop_target != null:
		empty_drop_target.reset_feedback()
	if items_drop_target != null:
		items_drop_target.reset_feedback()


func clear_drop_highlights() -> void:
	for target in slot_drop_targets:
		target.clear_highlight()
	if empty_drop_target != null:
		empty_drop_target.clear_highlight()
	if items_drop_target != null:
		items_drop_target.clear_highlight()


func _apply_card_style(card: PanelContainer, _w: WeaponDef, selected: bool) -> void:
	var style := UiTheme.box(UiTheme.PAPER if selected else Color(UiTheme.CARD, 0.55),
			UiTheme.ACCENT if selected else Color(UiTheme.EDGE, 0.0), 3 if selected else 0, 20)
	style.shape = InkStyleBox.Shape.PAPER
	style.variant = _card_variant(_w.id)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)


func _select(index: int) -> void:
	if _sim == null or index < 0 or index >= _cards.size() or upgrade_button == null:
		return
	_selected = index
	for i in _cards.size():
		_apply_card_style(_cards[i], _card_weapons[i], i == index)
	var w := _card_weapons[index]
	var level := _card_levels[index]
	if level >= WeaponDef.MAX_LEVEL:
		upgrade_button.text = Loc.t("workshop.evolve") if not w.evolution_options.is_empty() else Loc.t("shop.max_level")
		upgrade_button.disabled = w.evolution_options.is_empty()
	else:
		var cost := Shop.upgrade_cost(w, level)
		upgrade_button.text = Loc.t("shop.upgrade_materials", [level + 2, cost])
		upgrade_button.disabled = not _sim.shop.quote(ShopResult.UPGRADE, _sim, null, index).ok
	upgrade_button.visible = not replacing
	manage_button.visible = not replacing
	upgrade_button.accessibility_name = upgrade_button.text
	upgrade_button.accessibility_description = Loc.weapon_upgrade(w, level)
	selection_changed.emit()


func _detail_text_for(w: WeaponDef, level: int) -> String:
	return "%s · %s\n%s\n%s\n%s" % [Loc.weapon_name(w.id), Loc.t("shop.level", [level + 1]),
		Loc.weapon_desc(w.id), Loc.weapon_line(w, level), Loc.weapon_upgrade(w, level)]


func _card_variant(id: StringName) -> int:
	return absi(String(id).hash()) % 7
