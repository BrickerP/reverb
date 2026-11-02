class_name PauseUi
extends Control

signal resume_requested
signal settings_requested
signal history_requested
signal codex_requested
signal story_requested
signal mute_requested
signal quit_requested
signal save_requested

var resume_button: Button
var settings_button: Button
var history_button: Button
var codex_button: Button
var story_button: Button
var mute_button: Button
var quit_button: Button
var save_button: Button
var error_label: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.76)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580.0, 0.0)
	var sheet := UiTheme.surface_panel().duplicate() as InkStyleBox
	sheet.shape = InkStyleBox.Shape.PAPER
	sheet.softness = 88.0
	sheet.variant = 28
	panel.add_theme_stylebox_override("panel", sheet)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 19)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("hud.paused_title"), 48, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("pause.aside"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	resume_button = _button(Loc.t("pause.resume"))
	resume_button.custom_minimum_size = Vector2(296.0, 58.0)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	UiTheme.stamp_button(resume_button)
	box.add_child(resume_button)
	var secondary := HBoxContainer.new()
	secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary.add_theme_constant_override("separation", 20)
	settings_button = _button(Loc.t("hud.settings"))
	settings_button.custom_minimum_size = Vector2(120.0, 36.0)
	settings_button.flat = true
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	secondary.add_child(settings_button)
	history_button = _button(Loc.t("select.history"))
	history_button.custom_minimum_size = Vector2(110.0, 36.0)
	history_button.flat = true
	history_button.pressed.connect(func() -> void: history_requested.emit())
	secondary.add_child(history_button)
	codex_button = _button(Loc.t("select.codex"))
	codex_button.custom_minimum_size = Vector2(110.0, 36.0)
	codex_button.flat = true
	codex_button.pressed.connect(func() -> void: codex_requested.emit())
	secondary.add_child(codex_button)
	story_button = _button(Loc.t("select.story"))
	story_button.custom_minimum_size = Vector2(100.0, 36.0)
	story_button.add_theme_font_size_override("font_size", 14)
	story_button.flat = true
	story_button.pressed.connect(func() -> void: story_requested.emit())
	secondary.add_child(story_button)
	box.add_child(secondary)
	mute_button = _button(Loc.t("hud.mute"))
	mute_button.custom_minimum_size = Vector2(220.0, 34.0)
	mute_button.flat = true
	mute_button.pressed.connect(func() -> void: mute_requested.emit())
	box.add_child(mute_button)
	save_button = _button(Loc.t("pause.save_return"))
	save_button.pressed.connect(func() -> void: save_requested.emit())
	box.add_child(save_button)
	error_label = UiTheme.label("", 14, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.custom_minimum_size = Vector2(400.0, 0.0)
	error_label.visible = false
	box.add_child(error_label)
	quit_button = _button(Loc.t("pause.abandon"))
	quit_button.custom_minimum_size = Vector2(280.0, 34.0)
	quit_button.flat = true
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	quit_button.add_theme_color_override("font_color", UiTheme.WARN)
	box.add_child(quit_button)
	var hint := UiTheme.label(Loc.t("hud.help_echo"), 13, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(360.0, 0.0)
	box.add_child(hint)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260.0, 42.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func open(muted: bool = false, letters: bool = false) -> void:
	set_muted(muted)
	story_button.visible = letters
	visible = true
	var cycle: Array[Control] = [resume_button, settings_button, history_button, codex_button, mute_button, save_button, quit_button]
	if letters:
		cycle.insert(4, story_button)
	UiFocus.cycle(cycle)
	resume_button.grab_focus()


func set_muted(muted: bool) -> void:
	if mute_button == null:
		return
	mute_button.text = Loc.t("pause.unmute") if muted else Loc.t("pause.mute")
	mute_button.accessibility_name = mute_button.text


func show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()
	if visible and not message.is_empty():
		save_button.grab_focus()


func close() -> void:
	visible = false
	show_error("")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
