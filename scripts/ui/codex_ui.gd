class_name CodexUi
extends Control

signal closed

const FAMILIES: Array[StringName] = [&"sidearm", &"scatter", &"marksman", &"arcane"]

var close_button: Button
var _cards: Array[PanelContainer] = []
var archive_scroll: ScrollContainer
var chapters: Array[VBoxContainer] = []


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
	panel.custom_minimum_size = Vector2(1120.0, 646.0)
	var cover := UiTheme.paper_panel(UiTheme.PAPER)
	cover.shape = InkStyleBox.Shape.PAPER
	cover.variant = 19
	panel.add_theme_stylebox_override("panel", cover)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("codex.title"), 46, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("codex.subtitle"), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	archive_scroll = ScrollContainer.new()
	archive_scroll.name = "ArchiveScroll"
	archive_scroll.custom_minimum_size = Vector2(0.0, 404.0)
	archive_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	archive_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive_scroll.follow_focus = true
	box.add_child(archive_scroll)
	var book := VBoxContainer.new()
	book.name = "SupplyChapters"
	book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book.add_theme_constant_override("separation", 26)
	archive_scroll.add_child(book)
	var total_weight := 0.0
	for weapon: WeaponDef in Content.weapons().values():
		if weapon.drops:
			total_weight += weapon.drop_weight
	for i in FAMILIES.size():
		var family: StringName = FAMILIES[i]
		var weapons: Array[WeaponDef] = []
		for weapon: WeaponDef in Content.weapons().values():
			if weapon.family == family:
				weapons.append(weapon)
		if not weapons.is_empty():
			book.add_child(_chapter(family, weapons, total_weight, i))
	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(180.0, 42.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func _chapter(family: StringName, weapons: Array[WeaponDef], total_weight: float,
		index: int) -> VBoxContainer:
	var chapter := VBoxContainer.new()
	chapter.name = "Family_%s" % family
	chapter.add_theme_constant_override("separation", 10)
	chapters.append(chapter)
	chapter.add_child(UiTheme.section_label(Loc.t("codex.chapter", [index + 1,
			Loc.weapon_family(family)]), 32, UiTheme.INK))
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 22)
	chapter.add_child(spread)
	var feature_column := VBoxContainer.new()
	feature_column.add_theme_constant_override("separation", 12)
	feature_column.custom_minimum_size = Vector2(382.0, 0.0)
	feature_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(feature_column)
	var featured := _card(weapons[0], total_weight, true)
	feature_column.add_child(featured)
	_cards.append(featured)
	var feature_stats := UiTheme.label(_stats_line(weapons[0]), 15, UiTheme.DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	feature_stats.custom_minimum_size = Vector2(320.0, 0.0)
	feature_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_column.add_child(feature_stats)
	var drop := Loc.t("codex.evolve_only") if not weapons[0].drops else Loc.t("codex.drop", [
			int(round(weapons[0].drop_weight / maxf(0.01, total_weight) * 100.0))])
	feature_column.add_child(UiTheme.label(drop, 14, UiTheme.COIN, HORIZONTAL_ALIGNMENT_CENTER))
	if weapons[0].evolves_to != &"":
		var evolve := _evolution(weapons[0], 320.0)
		evolve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feature_column.add_child(evolve)
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_top", 14 if index % 2 == 0 else 0)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(inset)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 14)
	inset.add_child(notes)
	for i in range(1, weapons.size()):
		var card := _card(weapons[i], total_weight, false)
		notes.add_child(card)
		_cards.append(card)
	return chapter


func _card(weapon: WeaponDef, total_weight: float, featured: bool = false) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(382.0, 224.0) if featured else Vector2(520.0, 122.0)
	card.set_meta(&"featured_supply", featured)
	var paper := UiTheme.paper_panel(UiTheme.INK if featured else UiTheme.PAPER)
	paper.shape = InkStyleBox.Shape.BLOB if featured else InkStyleBox.Shape.TAG
	paper.variant = int(weapon.id.hash() % 19)
	paper.border_color = UiTheme.INK if featured else Color(UiTheme.EDGE, 0.0)
	paper.draw_center = featured
	paper.content_margin_left = 28.0 if featured else 10.0
	paper.content_margin_right = 28.0 if featured else 10.0
	paper.content_margin_top = 24.0 if featured else 8.0
	paper.content_margin_bottom = 24.0 if featured else 8.0
	card.add_theme_stylebox_override("panel", paper)
	if featured:
		var figure := VBoxContainer.new()
		figure.alignment = BoxContainer.ALIGNMENT_CENTER
		figure.add_theme_constant_override("separation", 5)
		card.add_child(figure)
		var icon := UiTheme.weapon_icon(weapon, Vector2(126.0, 100.0))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		figure.add_child(icon)
		var name_label := _name(weapon, 32, 260.0)
		name_label.add_theme_color_override("font_color", UiTheme.CARD)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		figure.add_child(name_label)
		figure.add_child(UiTheme.label(Loc.rarity_name(weapon.rarity), 14, UiTheme.PAPER,
				HORIZONTAL_ALIGNMENT_CENTER))
		return card
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	card.add_child(body)
	var icon := UiTheme.weapon_icon(weapon, Vector2(72.0, 78.0))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(icon)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 6)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(details)
	details.add_child(_name(weapon, 20, 350.0))
	var drop := Loc.t("codex.evolve_only") if not weapon.drops else Loc.t("codex.drop", [
			int(round(weapon.drop_weight / maxf(0.01, total_weight) * 100.0))])
	details.add_child(UiTheme.label("%s  ·  %s" % [Loc.rarity_name(weapon.rarity), drop],
			13, UiTheme.ECHO if not weapon.drops else UiTheme.DIM))
	var stats := UiTheme.label(_stats_line(weapon), 14, UiTheme.DIM)
	stats.custom_minimum_size = Vector2(350.0, 0.0)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(stats)
	if weapon.evolves_to != &"":
		details.add_child(_evolution(weapon, 350.0))
	return card


func _stats_line(weapon: WeaponDef) -> String:
	var line := Loc.weapon_line(weapon)
	if weapon.explosion_radius > 0.0:
		line += " · " + Loc.t("weapon.explosion", [int(weapon.explosion_radius)])
	if weapon.homing_turn > 0.0:
		line += " · " + Loc.t("weapon.homing")
	return line


func _evolution(weapon: WeaponDef, width: float) -> Label:
	var label := UiTheme.label(Loc.t("codex.evolves", [Loc.weapon_name(weapon.evolves_to),
			Shop.EVOLVE_FAMILY_COUNT]), 14, UiTheme.ACCENT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	return label


func _name(weapon: WeaponDef, size: int, width: float) -> Label:
	var name_label := UiTheme.label(Loc.weapon_name(weapon.id), size, UiTheme.INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(width, 0.0)
	return name_label


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
