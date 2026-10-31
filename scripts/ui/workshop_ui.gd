class_name WorkshopUi
extends Control

signal closed

var choice_buttons: Array[Button] = []
var cancel_button: Button
var _content: VBoxContainer
var _select := Callable()
var _last_focus: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.96)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.PAPER))
	margin.add_child(paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	paper.add_child(_content)
	visible = false


# Every decision replaces the same sheet. Cancel always returns to the shop.
func show_choices(title: String, body: String, choices: Array[Dictionary], select: Callable) -> void:
	_select = select
	_last_focus = null
	UiTheme.clear(_content)
	choice_buttons.clear()
	_content.add_child(UiTheme.section_label(title, 29))
	var description := UiTheme.label(body, 16, UiTheme.DIM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(description)
	var grid := GridContainer.new()
	grid.columns = 2 if choices.size() > 2 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for choice in choices:
		var button := Button.new()
		var hint := str(choice.get("hint", ""))
		button.text = str(choice.get("text", ""))
		button.tooltip_text = hint
		button.accessibility_description = hint if hint != "" else button.text
		button.disabled = bool(choice.get("disabled", false))
		if button.disabled and hint != "":
			button.text += "\n" + hint
			button.clip_text = false
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(0.0, 64.0)
		else:
			button.clip_text = true
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		if not button.disabled:
			button.pressed.connect(_choose.bind(choice.get("value")))
		grid.add_child(button)
		choice_buttons.append(button)
		button.focus_entered.connect(_remember_focus.bind(button))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	cancel_button = Button.new()
	cancel_button.text = Loc.t("shop.cancel")
	cancel_button.custom_minimum_size.y = 38.0
	cancel_button.pressed.connect(close)
	_content.add_child(cancel_button)
	visible = true
	var controls: Array = []
	for button in choice_buttons:
		if not button.disabled:
			controls.append(button)
	controls.append(cancel_button)
	UiFocus.cycle(controls)
	for i in controls.size():
		var current := controls[i] as Control
		current.focus_neighbor_left = current.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		current.focus_neighbor_right = current.get_path_to(controls[(i + 1) % controls.size()])
	focus_default()


func _choose(value: Variant) -> void:
	if _select.is_valid():
		_select.call(value)


func focus_default() -> void:
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() and not _last_focus.disabled:
		_last_focus.grab_focus()
		return
	for button in choice_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	if cancel_button != null:
		cancel_button.grab_focus()


func reset() -> void:
	visible = false
	_select = Callable()
	_last_focus = null
	choice_buttons.clear()
	cancel_button = null
	if _content != null:
		UiTheme.clear(_content)


func close() -> void:
	reset()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		accept_event()


# Local padding keeps native 540p readable without changing the canvas scale.
static func fit_button(button: Button, font_size: int = 14, height: float = 28.0) -> void:
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, UiTheme.INK)
	button.add_theme_color_override("font_disabled_color", UiTheme.DIM)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UiTheme.paper_panel(UiTheme.SURFACE if state == "disabled" else UiTheme.CARD)
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
		button.add_theme_stylebox_override(state, style)


func add_result_visual(control: Control) -> void:
	_content.add_child(control)
	_content.move_child(control, 2)


func _remember_focus(button: Button) -> void:
	_last_focus = button
