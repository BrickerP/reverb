class_name PauseUi
extends Control

signal resume_requested
signal settings_requested
signal history_requested
signal mute_requested
signal quit_requested

var resume_button: Button
var settings_button: Button
var history_button: Button
var mute_button: Button
var quit_button: Button


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(
			Color(0.02, 0.03, 0.08, 0.97), Color(0.35, 0.55, 0.95, 0.55), 2, 10))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("hud.paused_title"), 32, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	resume_button = _button(Loc.t("pause.resume"))
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume_button)
	settings_button = _button(Loc.t("hud.settings"))
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	box.add_child(settings_button)
	history_button = _button(Loc.t("select.history"))
	history_button.pressed.connect(func() -> void: history_requested.emit())
	box.add_child(history_button)
	mute_button = _button(Loc.t("hud.mute"))
	mute_button.pressed.connect(func() -> void: mute_requested.emit())
	box.add_child(mute_button)
	quit_button = _button(Loc.t("hud.quit"))
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit_button)
	var hint := UiTheme.label(Loc.t("hud.help_echo"), 13, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(340.0, 0.0)
	box.add_child(hint)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260.0, 42.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func open() -> void:
	visible = true
	resume_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
