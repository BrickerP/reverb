class_name CodexUi
extends Control

signal closed

var close_button: Button
var _cards: Array[PanelContainer] = []


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.94)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(
			Color(0.03, 0.04, 0.09, 0.98), Color(0.3, 0.5, 0.9, 0.6), 2, 10))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("codex.title"), 32, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("codex.subtitle"), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var total := 0.0
	for w: WeaponDef in Content.weapons().values():
		if w.drops:
			total += w.drop_weight
	for w: WeaponDef in Content.weapons().values():
		var card := _card(w, total)
		grid.add_child(card)
		_cards.append(card)
	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(160.0, 40.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func _card(w: WeaponDef, total_weight: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(350.0, 122.0)
	var border := UiTheme.ACCENT if not w.drops else w.color
	var style := UiTheme.box(Color(0.035, 0.045, 0.10), Color(border, 0.65), 1, 6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(UiTheme.label("■", 14, w.color))
	var name_label := UiTheme.label(Loc.weapon_name(w.id), 16, UiTheme.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiTheme.label(Loc.rarity_name(w.rarity), 11,
			UiTheme.COIN if w.rarity == &"uncommon" else (UiTheme.ECHO if w.rarity == &"rare" else UiTheme.DIM)))
	box.add_child(top)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 6)
	meta.add_child(UiTheme.label(Loc.weapon_family(w.family), 11, UiTheme.DIM))
	var drop := Loc.t("codex.evolve_only") if not w.drops else Loc.t("codex.drop", [
			int(round(w.drop_weight / maxf(0.01, total_weight) * 100.0))])
	var drop_label := UiTheme.label(drop, 11, UiTheme.COIN if w.drops else UiTheme.ACCENT)
	drop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(drop_label)
	box.add_child(meta)
	var line := Loc.weapon_line(w)
	if w.explosion_radius > 0.0:
		line += " · " + Loc.t("weapon.explosion", [int(w.explosion_radius)])
	if w.homing_turn > 0.0:
		line += " · " + Loc.t("weapon.homing")
	var stats := UiTheme.label(line, 12, UiTheme.DIM)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)
	if w.evolves_to != &"":
		box.add_child(UiTheme.label(Loc.t("codex.evolves", [Loc.weapon_name(w.evolves_to),
				Shop.EVOLVE_FAMILY_COUNT]), 11, UiTheme.ACCENT))
	return card


func open() -> void:
	visible = true
	close_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func card_count() -> int:
	return _cards.size()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
