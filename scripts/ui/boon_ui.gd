class_name BoonUi
extends Control

signal chosen(index: int)
signal reroll_requested

var reroll_button: Button
var choice_buttons: Array[Button] = []

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
	_panel.custom_minimum_size = Vector2(900.0, 0.0)
	_panel.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	margin.add_child(_box)


func open(boons: Array[StringName], sim: Sim = null) -> void:
	if boons.is_empty():
		close()
		return
	UiTheme.clear(_box)
	choice_buttons.clear()
	reroll_button = null
	_box.add_child(UiTheme.label(Loc.t("boon.title"), 34, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_box.add_child(UiTheme.label(Loc.t("boon.subtitle"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in boons.size():
		var id := boons[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(252.0, 208.0)
		b.accessibility_name = Loc.t(Boon.title_key(id))
		b.accessibility_description = Loc.t(Boon.desc_key(id))
		b.add_theme_stylebox_override("normal", UiTheme.paper_panel())
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, 18)
		b.add_child(inset)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 12)
		inset.add_child(content)
		content.add_child(UiTheme.label("%02d" % (i + 1), 30, UiTheme.WARN))
		var title := UiTheme.label(Loc.t(Boon.title_key(id)), 20)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(210.0, 0.0)
		content.add_child(title)
		var detail := UiTheme.label(Loc.t(Boon.desc_key(id)), 15, UiTheme.DIM)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(210.0, 0.0)
		content.add_child(detail)
		b.pressed.connect(_on_chosen.bind(i))
		choice_buttons.append(b)
		row.add_child(b)
	_box.add_child(row)
	if sim != null:
		var cost := sim.boon_reroll_cost()
		reroll_button = Button.new()
		reroll_button.text = Loc.t("boon.reroll", [cost])
		reroll_button.disabled = sim.player.materials < cost
		reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
		_box.add_child(reroll_button)
	visible = true
	var focus_controls: Array[Control] = []
	for choice in choice_buttons:
		focus_controls.append(choice)
	if reroll_button != null:
		focus_controls.append(reroll_button)
	UiFocus.cycle(focus_controls)
	if row.get_child_count() > 0:
		(row.get_child(0) as Button).grab_focus()


func close() -> void:
	visible = false
	reroll_button = null
	choice_buttons.clear()
	UiTheme.clear(_box)


func _on_chosen(index: int) -> void:
	chosen.emit(index)
