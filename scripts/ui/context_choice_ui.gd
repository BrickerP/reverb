class_name ContextChoiceUi
extends Control

# One sheet serves both boss terms and final discharge. Main owns the simulation
# pause and validates each emitted id; this view never applies world consequences.
signal chosen(id: StringName)
signal save_requested
signal closed

const MAX_CHOICES := 8

var choice_buttons: Array[Button] = []
var save_button: Button
var return_button: Button
var _title: Label
var _body: Label
var _error: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _last_focus: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.97)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	margin.add_child(paper)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	paper.add_child(content)
	_title = UiTheme.section_label("", 30)
	_title.clip_text = true
	content.add_child(_title)
	_body = UiTheme.label("", 15, UiTheme.DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_body)
	_error = UiTheme.label("", 14, UiTheme.WARN)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	content.add_child(_error)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	save_button = Button.new()
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WorkshopUi.fit_button(save_button, 15, 36.0)
	save_button.pressed.connect(func() -> void: save_requested.emit())
	actions.add_child(save_button)
	return_button = Button.new()
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WorkshopUi.fit_button(return_button, 15, 36.0)
	return_button.pressed.connect(close)
	actions.add_child(return_button)
	visible = false


func open_context(title_key: String, body_key: String, choices: Array[Dictionary], allow_save: bool) -> void:
	_title.text = Loc.t(title_key)
	_title.add_theme_font_override("font", UiTheme.title_font(_title.text))
	_body.text = Loc.t(body_key)
	_error.text = ""
	_error.visible = false
	UiTheme.clear(_rows)
	choice_buttons.clear()
	_last_focus = null
	for index in mini(MAX_CHOICES, choices.size()):
		_add_choice(choices[index])
	save_button.text = Loc.t("context.save")
	save_button.accessibility_name = save_button.text
	save_button.visible = allow_save
	return_button.text = Loc.t("context.return")
	return_button.accessibility_name = return_button.text
	visible = true
	var controls: Array = []
	for button in choice_buttons:
		if not button.disabled:
			controls.append(button)
	if allow_save:
		controls.append(save_button)
	controls.append(return_button)
	UiFocus.cycle(controls)
	focus_default()


func show_error(message: String) -> void:
	_error.text = message
	_error.visible = not message.is_empty()
	_error.accessibility_name = message


func _add_choice(row: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.CARD))
	_rows.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	var name_text := Loc.t(str(row.get("name_key", "")))
	var description := Loc.t(str(row.get("description_key", "")))
	var cost := Loc.t("context.cost", [maxi(0, int(row.get("cost", 0)))])
	var reason_key := str(row.get("reason_key", ""))
	var reason := Loc.t(reason_key) if not reason_key.is_empty() else Loc.t("context.available")
	var button := Button.new()
	button.text = name_text
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not bool(row.get("available", false))
	WorkshopUi.fit_button(button, 17, 34.0)
	button.accessibility_name = name_text
	button.accessibility_description = " · ".join([description, cost, reason])
	button.tooltip_text = button.accessibility_description
	button.pressed.connect(func() -> void: chosen.emit(StringName(row.get("id", &""))))
	button.focus_entered.connect(func() -> void: _last_focus = button)
	content.add_child(button)
	choice_buttons.append(button)
	var detail := UiTheme.label(description, 14, UiTheme.DIM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	var terms := UiTheme.label(cost + " · " + reason, 14, UiTheme.WARN if button.disabled else UiTheme.ACCENT)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(terms)


func focus_default() -> void:
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() and not _last_focus.disabled:
		_last_focus.grab_focus()
		return
	for button in choice_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	return_button.grab_focus()


func reset() -> void:
	visible = false
	_last_focus = null


func close() -> void:
	reset()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		accept_event()
