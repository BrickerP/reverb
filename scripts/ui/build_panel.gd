class_name BuildPanel
extends PanelContainer

signal replace_cancelled
signal upgrade_requested(index: int)
signal evolve_requested(index: int)
signal detail_changed(text: String)
signal workshop_requested(index: int)
signal install_requested(kind: StringName, index: int)

var weapons_label: Label
var items_label: Label
var replacing: bool = false
var marked_slot := -1
var slot_drop_targets: Array[ShopDropTarget] = []
var empty_drop_target: ShopDropTarget
var items_drop_target: ShopDropTarget

var _box: VBoxContainer
var _weapons_row: Control
var _slot_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []
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
		surface.content_margin_top = 8.0
		surface.content_margin_bottom = 8.0
		add_theme_stylebox_override("panel", surface)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_box)


func refresh(sim: Sim, replace_with: String = "", on_choose: Callable = Callable(),
		quote_drop: Callable = Callable(), apply_drop: Callable = Callable(),
		clear_drop: Callable = Callable()) -> void:
	reset_feedback()
	_sim = sim
	_on_choose = on_choose
	_quote_drop = quote_drop
	_apply_drop = apply_drop
	_clear_drop = clear_drop
	replacing = replace_with != ""
	var selected_before := _selected
	UiTheme.clear(_box)
	_slot_buttons.clear()
	_upgrade_buttons.clear()
	_cards.clear()
	_card_weapons.clear()
	_card_levels.clear()
	slot_drop_targets.clear()
	empty_drop_target = null
	items_drop_target = null
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	weapons_label = UiTheme.label(Loc.t("shop.weapons", [sim.player.weapons.size(), Content.MAX_WEAPON_SLOTS]), 17)
	weapons_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(weapons_label)
	var details := Button.new()
	details.text = Loc.t("workshop.details")
	details.add_theme_font_size_override("font_size", 14)
	details.pressed.connect(func() -> void: workshop_requested.emit(_selected))
	head.add_child(details)
	_box.add_child(head)
	_weapons_row = _weapon_chips(sim.player, sim)
	_box.add_child(_weapons_row)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	items_label = UiTheme.label(Loc.t("workshop.passives", [sim.player.items.size()]), 14, UiTheme.DIM)
	items_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(items_label)
	items_drop_target = _empty_target(&"items", Loc.t("shop.drop_item"))
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
		WorkshopUi.fit_button(button, 14, 25.0)



func close_session() -> void:
	reset_feedback()
	_sim = null
	_on_choose = Callable()
	UiTheme.clear(_box)
	weapons_label = null
	items_label = null
	replacing = false
	_weapons_row = null
	_slot_buttons.clear()
	_upgrade_buttons.clear()
	_cards.clear()
	_card_weapons.clear()
	_card_levels.clear()
	slot_drop_targets.clear()
	empty_drop_target = null
	items_drop_target = null
	_quote_drop = Callable()
	_apply_drop = Callable()
	_clear_drop = Callable()
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
	if index < 0 or index >= _upgrade_buttons.size():
		return false
	if _upgrade_buttons[index].disabled or not _upgrade_buttons[index].is_visible_in_tree():
		return false
	_upgrade_buttons[index].grab_focus()
	return true


func flash_slots(reduced: bool = false) -> void:
	_reject_section(weapons_label, _weapons_row, reduced)


func flash_items(reduced: bool = false) -> void:
	_reject_section(items_label, items_drop_target, reduced)


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
	for control: Control in [weapons_label, items_label, _weapons_row, items_drop_target]:
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
			var empty := _empty_target(&"empty_weapon", Loc.t("workshop.empty_slot", [i + 1]))
			empty.custom_minimum_size = Vector2(0.0, 52.0)
			grid.add_child(empty)
			if empty_drop_target == null:
				empty_drop_target = empty
	return grid


func _weapon_card(w: WeaponDef, level: int, index: int, pl: PlayerState, sim: Sim) -> Control:
	var card := ShopDropTarget.new()
	card.configure(&"weapon_slot", index, _quote_drop, _apply_drop, _clear_drop)
	card.accessibility_name = Loc.weapon_name(w.id)
	card.accessibility_description = _detail_text_for(w, level)
	card.custom_minimum_size = Vector2(0.0, 52.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_style(card, w, false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	var select := Button.new()
	select.text = "%d · %s · %s" % [index + 1, Loc.t("shop.level", [level + 1]), Loc.weapon_name(w.id)]
	if replacing:
		select.text = "%d · +%d · %s" % [index + 1, Shop.resale_for(sim, index), Loc.weapon_name(w.id)]
	select.tooltip_text = _detail_text_for(w, level)
	select.clip_text = true
	select.custom_minimum_size = Vector2(0.0, 27.0)
	select.add_theme_font_size_override("font_size", 13)
	select.pressed.connect(func() -> void:
		_select(index)
		if replacing and _on_choose.is_valid():
			_on_choose.call(index)
		else:
			workshop_requested.emit(index))
	box.add_child(select)
	_slot_buttons.append(select)
	if index == marked_slot:
		box.add_child(UiTheme.label(Loc.t("shop.just_equipped"), 12, UiTheme.ACCENT))
	var upgrade := Button.new()
	upgrade.custom_minimum_size = Vector2(0.0, 25.0)
	upgrade.clip_text = true
	upgrade.add_theme_font_size_override("font_size", 12)
	if level >= WeaponDef.MAX_LEVEL:
		upgrade.text = Loc.t("workshop.evolve") if not w.evolution_options.is_empty() else Loc.t("shop.max_level")
		upgrade.disabled = w.evolution_options.is_empty()
		upgrade.pressed.connect(func() -> void: evolve_requested.emit(index))
	else:
		var now := w.damage * w.level_mult(level)
		var nxt := w.damage * w.level_mult(level + 1)
		upgrade.text = Loc.t("shop.upgrade_result", [Shop.upgrade_cost(w, level), Loc.number(now), Loc.number(nxt)])
		upgrade.disabled = not sim.shop.quote(ShopResult.UPGRADE, sim, null, index).ok
		if upgrade.disabled:
			upgrade.text += " · " + Loc.t("shop.drop_poor")
			upgrade.tooltip_text = Loc.t("shop.drop_poor")
		upgrade.pressed.connect(func() -> void: upgrade_requested.emit(index))
	box.add_child(upgrade)
	_upgrade_buttons.append(upgrade)
	_cards.append(card)
	_card_weapons.append(w)
	_card_levels.append(level)
	slot_drop_targets.append(card)
	card.mouse_entered.connect(func() -> void: _select(index))
	select.focus_entered.connect(func() -> void: _select(index))
	upgrade.focus_entered.connect(func() -> void: _select(index))
	return card


func _empty_target(kind: StringName, text: String) -> ShopDropTarget:
	var target := ShopDropTarget.new()
	target.configure(kind, -1, _quote_drop, _apply_drop, _clear_drop)
	target.accessibility_name = text
	target.tooltip_text = Loc.t("shop.pick_offer")
	target.clicked.connect(func() -> void: install_requested.emit(kind, -1))
	target.custom_minimum_size = Vector2(0.0, 36.0)
	var style := UiTheme.box(UiTheme.SURFACE, Color(UiTheme.EDGE, 0.35), 1, 18)
	style.shape = InkStyleBox.Shape.TAG
	target.add_theme_stylebox_override("panel", style)
	var label := UiTheme.label(text, 13, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
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
			UiTheme.ACCENT if selected else Color(UiTheme.EDGE, 0.0), 1 if selected else 0, 20)
	style.shape = InkStyleBox.Shape.PAPER
	style.variant = _card_variant(_w.id)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	card.add_theme_stylebox_override("panel", style)


func _select(index: int) -> void:
	if index < 0 or index >= _cards.size():
		detail_changed.emit("")
		return
	_selected = index
	for i in _cards.size():
		_apply_card_style(_cards[i], _card_weapons[i], i == index)
	detail_changed.emit(_detail_text(index))


func _detail_text(index: int) -> String:
	if index < 0 or index >= _card_weapons.size():
		return ""
	return _detail_text_for(_card_weapons[index], _card_levels[index])


func _detail_text_for(w: WeaponDef, level: int) -> String:
	var spend := str(Shop.upgrade_cost(w, level)) if level < WeaponDef.MAX_LEVEL else Loc.t("shop.max_level")
	return Loc.t("shop.decision", [Loc.weapon_name(w.id), spend, Loc.weapon_line(w, mini(level + 1, WeaponDef.MAX_LEVEL))])


func _card_variant(id: StringName) -> int:
	return absi(String(id).hash()) % 7
