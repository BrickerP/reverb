class_name BuildPanel
extends PanelContainer

var _box: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(320.0, 0.0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh(sim: Sim) -> void:
	UiTheme.clear(_box)
	var pl := sim.player
	_box.add_child(UiTheme.label(Loc.t("shop.build"), 22, UiTheme.ACCENT))
	_box.add_child(UiTheme.label(Loc.t("shop.weapons", [pl.weapons.size(), Content.MAX_WEAPON_SLOTS]), 16, UiTheme.DIM))
	_box.add_child(_weapon_chips(pl))
	_box.add_child(UiTheme.label(Loc.t("shop.items"), 16, UiTheme.DIM))
	_box.add_child(_item_chips(pl))
	_box.add_child(UiTheme.label(Loc.t("shop.stats"), 16, UiTheme.DIM))
	_box.add_child(_stat_grid(pl))


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


func _stat_grid(pl: PlayerState) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 4)
	for id in Stats.ORDER:
		var echo_stat := String(id).begins_with("echo_")
		var name_label := UiTheme.label(Loc.stat_name(id), 15, UiTheme.ECHO if echo_stat else UiTheme.DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var value := Loc.stat_value(id, pl.stats.get_stat(id), false)
		grid.add_child(UiTheme.label(value, 15, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT))
	return grid


func _counted(label: String, n: int) -> String:
	return "%s ×%d" % [label, n] if n > 1 else label
