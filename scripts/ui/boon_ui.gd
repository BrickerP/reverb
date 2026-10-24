class_name BoonUi
extends Control

signal chosen(index: int)

var _panel: PanelContainer
var _box: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.86)
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


func open(boons: Array[StringName]) -> void:
	UiTheme.clear(_box)
	_box.add_child(UiTheme.label(Loc.t("boon.title"), 34, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_box.add_child(UiTheme.label(Loc.t("boon.subtitle"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in boons.size():
		var id := boons[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(252.0, 150.0)
		b.text = "%s\n\n%s" % [Loc.t(Boon.title_key(id)), Loc.t(Boon.desc_key(id))]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_chosen.bind(i))
		row.add_child(b)
	_box.add_child(row)
	visible = true
	if row.get_child_count() > 0:
		(row.get_child(0) as Button).grab_focus()


func close() -> void:
	visible = false
	UiTheme.clear(_box)


func _on_chosen(index: int) -> void:
	chosen.emit(index)
