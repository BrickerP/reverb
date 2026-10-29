class_name BoonUi
extends Control

signal chosen(index: int)
signal reroll_requested
signal save_requested

var reroll_button: Button
var save_button: Button
var error_label: Label
var choice_buttons: Array[Button] = []

var _choice_note: Label
var _panel: PanelContainer
var _box: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(980.0, 0.0)
	var carrier := UiTheme.surface_panel().duplicate() as InkStyleBox
	carrier.draw_center = false
	carrier.border_color = Color(0, 0, 0, 0)
	carrier.shadow_color = Color(0, 0, 0, 0)
	carrier.shadow_size = 0
	_panel.add_theme_stylebox_override("panel", carrier)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 22)
	margin.add_child(_box)


func open(boons: Array[StringName], sim: Sim = null) -> void:
	if boons.is_empty():
		close()
		return
	UiTheme.clear(_box)
	choice_buttons.clear()
	reroll_button = null
	_box.add_child(UiTheme.label(Loc.t("boon.title"), 46, UiTheme.CARD, HORIZONTAL_ALIGNMENT_CENTER))
	_box.add_child(UiTheme.label(Loc.t("boon.subtitle"), 15, UiTheme.CARD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	for i in boons.size():
		var id := boons[i]
		var b := Button.new()
		b.custom_minimum_size = [Vector2(236.0, 260.0), Vector2(274.0, 300.0), Vector2(244.0, 270.0)][i % 3]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.accessibility_name = Loc.t(Boon.title_key(id))
		b.accessibility_description = Loc.t(Boon.desc_key(id))
		b.set_meta(&"boon_id", id)
		var shell := UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
		shell.draw_center = false
		shell.shadow_color = Color(0, 0, 0, 0)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, shell)
		var focus := UiTheme.box(Color(0, 0, 0, 0), UiTheme.CARD, 2)
		focus.draw_center = false
		focus.focus_marks = true
		focus.shadow_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override("focus", focus)
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, 26 if i % 3 == 1 else 21)
		b.add_child(inset)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 12)
		inset.add_child(content)
		var relic := PanelContainer.new()
		relic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relic.custom_minimum_size = [Vector2(124.0, 106.0), Vector2(145.0, 130.0), Vector2(132.0, 114.0)][i % 3]
		relic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var blot := UiTheme.paper_panel(UiTheme.PAPER)
		blot.shape = InkStyleBox.Shape.BLOB
		blot.variant = i + 32
		blot.shadow_size = 0
		blot.shadow_color = Color(0, 0, 0, 0)
		blot.set_border_width_all(0)
		relic.add_theme_stylebox_override("panel", blot)
		b.set_meta(&"relic_blot", blot)
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(UiTheme.item_icon(Content.item(_item_for_boon(id)), Vector2(88.0, 88.0)))
		relic.add_child(center)
		content.add_child(relic)
		var title := UiTheme.label(Loc.t(Boon.title_key(id)), 30, UiTheme.CARD, HORIZONTAL_ALIGNMENT_CENTER)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(180.0, 0.0)
		content.add_child(title)
		var detail := UiTheme.label(Loc.t(Boon.desc_key(id)), 15, UiTheme.CARD, HORIZONTAL_ALIGNMENT_CENTER)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(180.0, 0.0)
		content.add_child(detail)
		b.pressed.connect(_on_chosen.bind(i))
		b.focus_entered.connect(_show_choice.bind(id))
		choice_buttons.append(b)
		row.add_child(b)
	_box.add_child(row)
	_choice_note = UiTheme.label(Loc.t("boon.only_one"), 17, UiTheme.CARD, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(_choice_note)
	if sim != null:
		var cost := sim.boon_reroll_cost()
		reroll_button = StitchedAction.new()
		reroll_button.flat = true
		reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reroll_button.custom_minimum_size = Vector2(230.0, 36.0)
		reroll_button.add_theme_color_override("font_pressed_color", UiTheme.CARD)
		reroll_button.add_theme_color_override("font_hover_pressed_color", UiTheme.CARD)
		reroll_button.add_theme_color_override("font_disabled_color", Color(UiTheme.CARD, 0.55))
		reroll_button.add_theme_color_override("font_color", UiTheme.CARD)
		reroll_button.add_theme_color_override("font_focus_color", UiTheme.CARD)
		reroll_button.add_theme_color_override("font_hover_color", UiTheme.CARD)
		reroll_button.text = Loc.t("boon.reroll", [cost])
		reroll_button.disabled = sim.player.materials < cost
		reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
		_box.add_child(reroll_button)
	save_button = StitchedAction.new()
	save_button.text = Loc.t("pause.save_return")
	save_button.custom_minimum_size = Vector2(260.0, 36.0)
	save_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		save_button.add_theme_color_override(state, UiTheme.CARD)
	save_button.add_theme_color_override("font_disabled_color", Color(UiTheme.CARD, 0.55))
	save_button.pressed.connect(func() -> void: save_requested.emit())
	_box.add_child(save_button)
	error_label = UiTheme.label("", 14, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	_box.add_child(error_label)
	visible = true
	var focus_controls: Array[Control] = []
	for choice in choice_buttons:
		focus_controls.append(choice)
	if reroll_button != null:
		focus_controls.append(reroll_button)
	focus_controls.append(save_button)
	UiFocus.cycle(focus_controls)
	if row.get_child_count() > 0:
		(row.get_child(0) as Button).grab_focus()


func show_error(message: String) -> void:
	if error_label != null:
		error_label.text = message
		error_label.visible = not message.is_empty()


func close() -> void:
	visible = false
	save_button = null
	error_label = null
	reroll_button = null
	choice_buttons.clear()
	UiTheme.clear(_box)


func _on_chosen(index: int) -> void:
	if index >= 0 and index < choice_buttons.size():
		chosen.emit(index)


func _show_choice(id: StringName) -> void:
	for choice in choice_buttons:
		var blot := choice.get_meta(&"relic_blot") as InkStyleBox
		blot.bg_color = UiTheme.CARD if choice.has_focus() else UiTheme.PAPER
	if _choice_note != null:
		_choice_note.text = Loc.t("boon.consider", [Loc.t(Boon.title_key(id))])


func _item_for_boon(id: StringName) -> StringName:
	match id:
		Boon.DAMAGE: return &"sharp_edge"
		Boon.HASTE: return &"quick_trigger"
		Boon.VITALITY, Boon.SHIELD, Boon.SECOND_WIND: return &"iron_heart"
		Boon.ECHO: return &"loud_speaker"
		Boon.FORTUNE, Boon.PRECISION: return &"lucky_coin"
		Boon.SLIPSTREAM: return &"sneakers"
		Boon.MAGNET: return &"magnet"
		Boon.ETERNITY: return &"long_play"
		Boon.RESERVOIR: return &"spare_deck"
	return &"iron_heart"
