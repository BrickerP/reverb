class_name BuildPanel
extends PanelContainer

var weapons_label: Label
var items_label: Label

var _box: VBoxContainer
var _weapons_row: Control
var _items_row: Control


func _init() -> void:
	custom_minimum_size = Vector2(320.0, 0.0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh(sim: Sim) -> void:
	UiTheme.clear(_box)
	var pl := sim.player
	_box.add_child(UiTheme.label(Loc.t("shop.build"), 22, UiTheme.ACCENT))
	weapons_label = UiTheme.label(Loc.t("shop.weapons", [pl.weapons.size(), Content.MAX_WEAPON_SLOTS]), 16, UiTheme.DIM)
	_box.add_child(weapons_label)
	_weapons_row = _weapon_chips(pl)
	_box.add_child(_weapons_row)
	items_label = UiTheme.label(Loc.t("shop.items"), 16, UiTheme.DIM)
	_box.add_child(items_label)
	_items_row = _item_chips(pl)
	_box.add_child(_items_row)
	_box.add_child(UiTheme.label(Loc.t("shop.core"), 16, UiTheme.DIM))
	_box.add_child(_core_grid(pl))


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


func _weapon_chips(pl: PlayerState) -> Control:
	var flow := _flow()
	var counts: Dictionary = {}
	var first: Array[WeaponDef] = []
	for w in pl.weapons:
		if not counts.has(w.id):
			first.append(w)
		counts[w.id] = int(counts.get(w.id, 0)) + 1
	for w in first:
		flow.add_child(UiTheme.label("■ " + _counted(Loc.weapon_name(w.id), counts[w.id]), 16, w.color))
	return flow


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
