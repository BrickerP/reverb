class_name BuildPanel
extends PanelContainer

signal replace_cancelled
signal upgrade_requested(index: int)
signal evolve_requested(index: int)
signal sell_requested(index: int)
signal detail_changed(text: String)

var weapons_label: Label
var items_label: Label
var replacing: bool = false
var slot_drop_targets: Array[ShopDropTarget] = []
var empty_drop_target: ShopDropTarget
var items_drop_target: ShopDropTarget

var _box: VBoxContainer
var _weapons_row: Control
var _items_row: Control
var _slot_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []
var _sell_buttons: Array[Button] = []
var _cards: Array[PanelContainer] = []
var _card_weapons: Array[WeaponDef] = []
var _card_levels: Array[int] = []
var _selected := 0
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
	_box.add_theme_constant_override("separation", 9)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	add_child(scroll)


func refresh(sim: Sim, replace_with: String = "", on_choose: Callable = Callable(),
		quote_drop: Callable = Callable(), apply_drop: Callable = Callable(),
		clear_drop: Callable = Callable()) -> void:
	UiTheme.clear(_box)
	_slot_buttons.clear()
	_upgrade_buttons.clear()
	_sell_buttons.clear()
	_cards.clear()
	_card_weapons.clear()
	_card_levels.clear()
	slot_drop_targets.clear()
	empty_drop_target = null
	items_drop_target = null
	_quote_drop = quote_drop
	_apply_drop = apply_drop
	_clear_drop = clear_drop
	replacing = replace_with != ""
	var pl := sim.player
	_box.add_child(UiTheme.section_label(Loc.t("shop.build"), 22))
	weapons_label = UiTheme.label(Loc.t("shop.weapons", [pl.weapons.size(), Content.MAX_WEAPON_SLOTS]), 16, UiTheme.DIM)
	_box.add_child(weapons_label)
	if replacing:
		var hint := UiTheme.label(Loc.t("shop.replace", [replace_with]), 14, UiTheme.ACCENT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(hint)
		_weapons_row = _slot_flow(pl, on_choose)
		_box.add_child(_weapons_row)
		var cancel := Button.new()
		cancel.text = Loc.t("shop.cancel")
		cancel.custom_minimum_size = Vector2(120.0, 32.0)
		cancel.pressed.connect(replace_cancelled.emit)
		_box.add_child(cancel)
		detail_changed.emit("")
	else:
		_weapons_row = _weapon_chips(pl, sim)
		_box.add_child(_weapons_row)
		if pl.weapons.size() < Content.MAX_WEAPON_SLOTS:
			empty_drop_target = _empty_target(&"empty_weapon", Loc.t("shop.drop_weapon"))
			_box.add_child(empty_drop_target)
		_box.add_child(UiTheme.label(Loc.t("shop.family"), 14, UiTheme.DIM))
		_box.add_child(_family_summary(pl))
		_box.add_child(UiTheme.label(Loc.t("combo.heading"), 14, UiTheme.DIM))
		_box.add_child(_combo_summary(pl.weapons))
		_selected = clampi(_selected, 0, maxi(0, _cards.size() - 1))
		_select(_selected)
	items_label = UiTheme.label(Loc.t("shop.items"), 16, UiTheme.DIM)
	_box.add_child(items_label)
	_items_row = _item_chips(pl)
	_box.add_child(_items_row)
	items_drop_target = _empty_target(&"items", Loc.t("shop.drop_item"))
	_box.add_child(items_drop_target)
	var set_summary := _set_summary(pl)
	if set_summary != null:
		_box.add_child(UiTheme.label(Loc.t("shop.sets"), 14, UiTheme.DIM))
		_box.add_child(set_summary)
	_box.add_child(UiTheme.label(Loc.t("shop.core"), 16, UiTheme.DIM))
	_box.add_child(_core_grid(pl, sim))


func close_session() -> void:
	reset_feedback()
	UiTheme.clear(_box)
	weapons_label = null
	items_label = null
	replacing = false
	_weapons_row = null
	_items_row = null
	_slot_buttons.clear()
	_upgrade_buttons.clear()
	_sell_buttons.clear()
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
	_reject_section(items_label, _items_row, reduced)


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
	for control: Control in [weapons_label, items_label, _weapons_row, _items_row]:
		if is_instance_valid(control):
			control.modulate = Color.WHITE


func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 2)
	return flow


func _slot_flow(pl: PlayerState, on_choose: Callable) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	for i in pl.weapons.size():
		var w := pl.weapons[i]
		var b := Button.new()
		b.text = "%s  +%d" % [Loc.weapon_name(w.id), Shop.resale_total(w, pl.level_at(i))]
		b.custom_minimum_size = Vector2(0.0, 34.0)
		b.add_theme_color_override("font_color", UiTheme.INK)
		b.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
		if on_choose.is_valid():
			b.pressed.connect(on_choose.bind(i))
		flow.add_child(b)
		_slot_buttons.append(b)
	return flow


func _weapon_chips(pl: PlayerState, sim: Sim) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	if pl.weapons.is_empty():
		grid.add_child(UiTheme.label(Loc.t("shop.none"), 15, UiTheme.DIM))
		return grid
	for i in pl.weapons.size():
		grid.add_child(_weapon_card(pl.weapons[i], pl.level_at(i), i, pl, sim))
	return grid


func _weapon_card(w: WeaponDef, level: int, index: int, pl: PlayerState, sim: Sim) -> Control:
	var card := ShopDropTarget.new()
	card.configure(&"weapon_slot", index, _quote_drop, _apply_drop, _clear_drop)
	card.accessibility_name = Loc.weapon_name(w.id)
	card.accessibility_description = _detail_text_for(w, level)
	# Leave room for the vertical scrollbar inside the fixed-width build panel.
	card.custom_minimum_size = Vector2(126.0, 116.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_style(card, w, false)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 4)
	top.add_child(UiTheme.weapon_icon(w, Vector2(34.0, 26.0)))
	var name_label := UiTheme.label(Loc.weapon_name(w.id), 13, UiTheme.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	top.add_child(UiTheme.label(Loc.t("shop.level", [level + 1]), 11, UiTheme.DIM))
	box.add_child(top)
	var middle := HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 4)
	middle.add_child(UiTheme.label(Loc.weapon_family(w.family), 11, UiTheme.DIM))
	var dps := UiTheme.label("%d DPS" % int(round(OfferCard.weapon_dps(w, pl.stats, level,
			Combat.family_damage_mult(pl.weapons, w.family),
			Combat.family_cooldown_mult(pl.weapons, w.family)))), 11, UiTheme.COIN)
	dps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	middle.add_child(dps)
	box.add_child(middle)
	var upgrade := Button.new()
	upgrade.mouse_filter = Control.MOUSE_FILTER_PASS
	upgrade.custom_minimum_size = Vector2(0.0, 28.0)
	upgrade.add_theme_font_size_override("font_size", 12)
	if level >= WeaponDef.MAX_LEVEL:
		if w.evolves_to != &"":
			var family_count := Combat.family_count(pl.weapons, w.family)
			if family_count < Shop.EVOLVE_FAMILY_COUNT:
				upgrade.text = Loc.t("shop.evolve_need", [Shop.EVOLVE_FAMILY_COUNT])
				upgrade.disabled = true
			else:
				upgrade.text = Loc.t("shop.evolve", [Shop.evolution_cost(w)])
				upgrade.pressed.connect(func() -> void: evolve_requested.emit(index))
		else:
			upgrade.text = Loc.t("shop.max_level")
			upgrade.disabled = true
	else:
		upgrade.text = Loc.t("shop.upgrade", [Shop.upgrade_cost(w, level)])
		upgrade.pressed.connect(func() -> void: upgrade_requested.emit(index))
	box.add_child(upgrade)
	_upgrade_buttons.append(upgrade)
	var sell := Button.new()
	sell.custom_minimum_size = Vector2(0.0, 28.0)
	sell.add_theme_font_size_override("font_size", 12)
	var sell_quote := sim.shop.quote(ShopResult.SELL, sim, null, index)
	if not sell_quote.ok:
		sell.text = Loc.t("shop.sell_last")
		sell.tooltip_text = Loc.t("shop.sell_last_reason")
		sell.accessibility_description = Loc.t("shop.sell_last_reason")
		sell.disabled = true
	else:
		sell.text = Loc.t("shop.sell", [absi(sell_quote.cost)])
		sell.tooltip_text = Loc.t("shop.sell_hint")
		sell.accessibility_description = Loc.t("shop.sell_hint")
		sell.pressed.connect(func() -> void: sell_requested.emit(index))
	sell.accessibility_name = sell.text
	box.add_child(sell)
	_sell_buttons.append(sell)
	_cards.append(card)
	_card_weapons.append(w)
	_card_levels.append(level)
	slot_drop_targets.append(card)
	card.mouse_entered.connect(func() -> void: _select(index))
	upgrade.focus_entered.connect(func() -> void: _select(index))
	sell.focus_entered.connect(func() -> void: _select(index))
	return card


func _empty_target(kind: StringName, text: String) -> ShopDropTarget:
	var target := ShopDropTarget.new()
	target.configure(kind, -1, _quote_drop, _apply_drop, _clear_drop)
	target.accessibility_name = text
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
	var text := Loc.t("shop.detail", [Loc.weapon_name(w.id), level + 1,
			Loc.weapon_family(w.family), Loc.weapon_line(w)])
	text += "  ·  " + Loc.weapon_desc(w.id)
	text += "  ·  " + Loc.rarity_name(w.rarity)
	if w.explosion_radius > 0.0:
		text += "  ·  " + Loc.t("weapon.explosion", [int(w.explosion_radius)])
	if w.homing_turn > 0.0:
		text += "  ·  " + Loc.t("weapon.homing")
	if w.evolves_to != &"":
		text += "  ·  " + Loc.t("shop.evolve_detail", [
			Loc.weapon_name(w.evolves_to), Shop.EVOLVE_FAMILY_COUNT, Shop.evolution_cost(w)])
	elif not w.drops:
		text += "  ·  " + Loc.t("shop.evolved_detail")
	return text


func _family_summary(pl: PlayerState) -> Control:
	var flow := VBoxContainer.new()
	flow.add_theme_constant_override("separation", 2)
	var counts: Dictionary = {}
	for w in pl.weapons:
		counts[w.family] = int(counts.get(w.family, 0)) + 1
	for family: StringName in counts:
		var count: int = counts[family]
		var parts := PackedStringArray(["%s ×%d" % [Loc.weapon_family(family), count]])
		if count >= 2:
			parts.append(Loc.t("shop.family_damage"))
		if count >= 4:
			var mastery_key := ""
			match family:
				&"sidearm":
					mastery_key = "shop.family_mastery_sidearm"
				&"scatter":
					mastery_key = "shop.family_mastery_scatter"
				&"marksman":
					mastery_key = "shop.family_mastery_marksman"
				&"arcane":
					mastery_key = "shop.family_mastery_arcane"
				&"press":
					mastery_key = "shop.family_mastery_press"
				&"salvage":
					mastery_key = "shop.family_mastery_salvage"
			if not mastery_key.is_empty():
				parts.append(Loc.t(mastery_key))
		if count >= 6:
			parts.append(Loc.t("shop.family_master"))
		var summary := UiTheme.label(" · ".join(parts), 12, UiTheme.COIN if count >= 2 else UiTheme.DIM)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flow.add_child(summary)
	return flow


func _item_chips(pl: PlayerState) -> Control:
	var flow := _flow()
	if pl.items.is_empty():
		flow.add_child(UiTheme.label(Loc.t("shop.none"), 16, UiTheme.DIM))
	for id: StringName in pl.items:
		var it := Content.item(id)
		var chip := HBoxContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(UiTheme.item_icon(it, Vector2(26.0, 26.0)))
		chip.add_child(UiTheme.label(_counted(Loc.item_name(id), pl.items[id]), 14, UiTheme.INK))
		flow.add_child(chip)
	return flow


func _set_summary(pl: PlayerState) -> Control:
	var entries: Array[String] = []
	for set_id: StringName in Content.item_sets():
		var data: Dictionary = Content.item_sets()[set_id]
		var count := 0
		for member: StringName in data.get("members", []):
			count += pl.item_count(member)
		if count <= 0:
			continue
		var required := int(data.get("required", 3))
		var text := "%s %d/%d" % [Loc.t(str(data.get("name", ""))), mini(count, required), required]
		if count >= required:
			var bonus_key := ""
			match set_id:
				&"echo":
					bonus_key = "set.echo_bonus"
				&"gunsmith":
					bonus_key = "set.gunsmith_bonus"
				&"field":
					bonus_key = "set.field_bonus"
			if not bonus_key.is_empty():
				text += " · " + Loc.t(bonus_key)
		entries.append(text)
	if entries.is_empty():
		return null
	var flow := VBoxContainer.new()
	flow.add_theme_constant_override("separation", 4)
	for text in entries:
		var label := UiTheme.label(text, 13, UiTheme.ECHO if text.contains("·") else UiTheme.DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_child(label)
	return flow


# The six numbers that describe this run's identity. The rest live on the cards.
func _core_grid(pl: PlayerState, sim: Sim) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 4)
	_add_stat(grid, Loc.t("stat.dps"), "%d" % int(round(OfferCard.total_dps(pl))))
	_add_stat(grid, Loc.stat_name(Stats.MAX_HP), Loc.stat_value(Stats.MAX_HP, pl.max_hp(), false))
	_add_stat(grid, Loc.stat_name(Stats.MOVE_SPEED), Loc.stat_value(Stats.MOVE_SPEED, pl.stats.get_stat(Stats.MOVE_SPEED), false))
	_add_stat(grid, Loc.stat_name(Stats.CRIT_CHANCE), Loc.stat_value(Stats.CRIT_CHANCE, pl.stats.get_stat(Stats.CRIT_CHANCE), false))
	if int(round(pl.stats.get_stat(Stats.ECHO_SLOTS))) > 0:
		_add_stat(grid, Loc.t("hud.echo"), Loc.t("shop.echo_value", [int(round(pl.stats.get_stat(Stats.ECHO_SLOTS))),
				int(round(sim.echo_power() * 100.0))]))
	_add_stat(grid, Loc.stat_name(Stats.HP_REGEN), Loc.stat_value(Stats.HP_REGEN, pl.stats.get_stat(Stats.HP_REGEN), false))
	return grid


func _add_stat(grid: GridContainer, name: String, value: String) -> void:
	var name_label := UiTheme.label(name, 15, UiTheme.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	grid.add_child(UiTheme.label(value, 15, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT))


func _counted(label: String, n: int) -> String:
	return "%s ×%d" % [label, n] if n > 1 else label


func _card_variant(id: StringName) -> int:
	return absi(String(id).hash()) % 7


func _combo_summary(weapons: Array[WeaponDef]) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for profile in Combat.combo_profile(weapons):
		var label := UiTheme.label(Loc.combo_line(profile), 12, UiTheme.ACCENT if profile["ready"] else UiTheme.DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	return box
