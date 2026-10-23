class_name BuildPanel
extends PanelContainer

signal replace_cancelled

var weapons_label: Label
var items_label: Label
var replacing: bool = false

var _box: VBoxContainer
var _weapons_row: Control
var _items_row: Control
var _slot_buttons: Array[Button] = []


func _init() -> void:
	custom_minimum_size = Vector2(320.0, 0.0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh(sim: Sim, replace_with: String = "", on_choose: Callable = Callable()) -> void:
	UiTheme.clear(_box)
	_slot_buttons.clear()
	replacing = replace_with != ""
	var pl := sim.player
	_box.add_child(UiTheme.label(Loc.t("shop.build"), 22, UiTheme.ACCENT))
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
	else:
		_weapons_row = _weapon_chips(pl)
		_box.add_child(_weapons_row)
	items_label = UiTheme.label(Loc.t("shop.items"), 16, UiTheme.DIM)
	_box.add_child(items_label)
	_items_row = _item_chips(pl)
	_box.add_child(_items_row)
	_box.add_child(UiTheme.label(Loc.t("shop.core"), 16, UiTheme.DIM))
	_box.add_child(_core_grid(pl))


func focus_first_slot() -> bool:
	if _slot_buttons.is_empty():
		return false
	_slot_buttons[0].grab_focus()
	return true


func flash_slots() -> void:
	UiTheme.flash(weapons_label)
	UiTheme.flash(_weapons_row)


func flash_items() -> void:
	UiTheme.flash(items_label)
	UiTheme.flash(_items_row)


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
		b.text = "%s  +%d" % [Loc.weapon_name(w.id), Shop.resale_value(w)]
		b.custom_minimum_size = Vector2(0.0, 34.0)
		b.add_theme_color_override("font_color", w.color)
		b.add_theme_color_override("font_hover_color", w.color.lightened(0.25))
		if on_choose.is_valid():
			b.pressed.connect(on_choose.bind(i))
		flow.add_child(b)
		_slot_buttons.append(b)
	return flow


func _weapon_chips(pl: PlayerState) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var counts: Dictionary = {}
	var first: Array[WeaponDef] = []
	for w in pl.weapons:
		if not counts.has(w.id):
			first.append(w)
		counts[w.id] = int(counts.get(w.id, 0)) + 1
	if first.is_empty():
		grid.add_child(UiTheme.label(Loc.t("shop.none"), 15, UiTheme.DIM))
		return grid
	for w in first:
		grid.add_child(_weapon_card(w, counts[w.id], pl))
	return grid


func _weapon_card(w: WeaponDef, count: int, pl: PlayerState) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(142.0, 54.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UiTheme.box(Color(0.035, 0.045, 0.10), Color(w.color, 0.55), 1, 6)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.add_child(UiTheme.label("■", 13, w.color))
	var name_label := UiTheme.label(_counted(Loc.weapon_name(w.id), count), 13, UiTheme.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	box.add_child(top)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.add_child(UiTheme.label(Loc.weapon_family(w.family), 11, UiTheme.DIM))
	var dps := UiTheme.label("%d DPS" % int(round(OfferCard.weapon_dps(w, pl.stats))), 11, UiTheme.COIN)
	dps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(dps)
	box.add_child(bottom)
	return card


func _item_chips(pl: PlayerState) -> Control:
	var flow := _flow()
	if pl.items.is_empty():
		flow.add_child(UiTheme.label(Loc.t("shop.none"), 16, UiTheme.DIM))
	for id: StringName in pl.items:
		var it := Content.item(id)
		flow.add_child(UiTheme.label(_counted(Loc.item_name(id), pl.items[id]), 16, it.color))
	return flow


# The six numbers that describe this run's identity. The rest live on the cards.
func _core_grid(pl: PlayerState) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 4)
	_add_stat(grid, Loc.t("stat.dps"), "%d" % int(round(OfferCard.total_dps(pl))))
	_add_stat(grid, Loc.stat_name(Stats.MAX_HP), Loc.stat_value(Stats.MAX_HP, pl.max_hp(), false))
	_add_stat(grid, Loc.stat_name(Stats.MOVE_SPEED), Loc.stat_value(Stats.MOVE_SPEED, pl.stats.get_stat(Stats.MOVE_SPEED), false))
	_add_stat(grid, Loc.stat_name(Stats.CRIT_CHANCE), Loc.stat_value(Stats.CRIT_CHANCE, pl.stats.get_stat(Stats.CRIT_CHANCE), false))
	if int(round(pl.stats.get_stat(Stats.ECHO_SLOTS))) > 0:
		_add_stat(grid, Loc.t("hud.echo"), Loc.t("shop.echo_value", [int(round(pl.stats.get_stat(Stats.ECHO_SLOTS))),
				int(round(pl.stats.get_stat(Stats.ECHO_POWER) * 100.0))]))
	_add_stat(grid, Loc.stat_name(Stats.HP_REGEN), Loc.stat_value(Stats.HP_REGEN, pl.stats.get_stat(Stats.HP_REGEN), false))
	return grid


func _add_stat(grid: GridContainer, name: String, value: String) -> void:
	var name_label := UiTheme.label(name, 15, UiTheme.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	grid.add_child(UiTheme.label(value, 15, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT))


func _counted(label: String, n: int) -> String:
	return "%s ×%d" % [label, n] if n > 1 else label
