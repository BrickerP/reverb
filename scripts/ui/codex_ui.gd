class_name CodexUi
extends Control

signal closed

var close_button: Button
var _cards: Array[PanelContainer] = []
var archive_scroll: ScrollContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.94)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120.0, 650.0)
	panel.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("codex.title"), 32, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("codex.subtitle"), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	archive_scroll = ScrollContainer.new()
	archive_scroll.name = "ArchiveScroll"
	archive_scroll.custom_minimum_size = Vector2(0.0, 450.0)
	archive_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	archive_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive_scroll.follow_focus = true
	box.add_child(archive_scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_scroll.add_child(grid)
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
	card.custom_minimum_size = Vector2(338.0, 150.0)
	var style := UiTheme.paper_panel(UiTheme.PAPER if not w.drops else UiTheme.CARD)
	style.border_color = UiTheme.ECHO if not w.drops else UiTheme.EDGE
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
	top.add_child(UiTheme.weapon_icon(w, Vector2(66.0, 46.0)))
	var name_label := UiTheme.label(Loc.weapon_name(w.id), 16, UiTheme.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiTheme.label(Loc.rarity_name(w.rarity), 13,
			UiTheme.COIN if w.rarity == &"uncommon" else (UiTheme.ECHO if w.rarity == &"rare" else UiTheme.DIM)))
	box.add_child(top)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 6)
	meta.add_child(UiTheme.label(Loc.weapon_family(w.family), 13, UiTheme.DIM))
	var drop := Loc.t("codex.evolve_only") if not w.drops else Loc.t("codex.drop", [
			int(round(w.drop_weight / maxf(0.01, total_weight) * 100.0))])
	var drop_label := UiTheme.label(drop, 13, UiTheme.COIN if w.drops else UiTheme.ACCENT)
	drop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(drop_label)
	box.add_child(meta)
	var line := Loc.weapon_line(w)
	if w.explosion_radius > 0.0:
		line += " · " + Loc.t("weapon.explosion", [int(w.explosion_radius)])
	if w.homing_turn > 0.0:
		line += " · " + Loc.t("weapon.homing")
	var stats := UiTheme.label(line, 14, UiTheme.DIM)
	stats.custom_minimum_size = Vector2(280.0, 0.0)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)
	if w.evolves_to != &"":
		var evolve := UiTheme.label(Loc.t("codex.evolves", [Loc.weapon_name(w.evolves_to),
				Shop.EVOLVE_FAMILY_COUNT]), 13, UiTheme.ACCENT)
		evolve.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evolve.custom_minimum_size = Vector2(280.0, 0.0)
		box.add_child(evolve)
	return card


func open() -> void:
	visible = true
	UiFocus.cycle([close_button])
	focus_default()


func focus_default() -> void:
	if close_button != null:
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


func _input(event: InputEvent) -> void:
	# Close remains the single focus target; the d-pad browses the archive itself.
	if not visible or archive_scroll == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not is_ancestor_of(focus):
		return
	var direction := 0
	if event.is_action_pressed(&"ui_down", true):
		direction = 1
	elif event.is_action_pressed(&"ui_up", true):
		direction = -1
	if direction != 0:
		archive_scroll.scroll_vertical += direction * 96
		get_viewport().set_input_as_handled()
