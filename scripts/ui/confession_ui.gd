class_name ConfessionUi
extends Control

# Two fixed-layout terms prevent wrapped-label minimums from feeding back into
# a full-screen container after repeated signing/Undo. Shop alone owns mutation.
signal chosen(id: StringName)
signal closed

class CopierArt extends Control:
	var printing := false

	func _draw() -> void:
		BureauArt.draw_facility(self, &"copier_print" if printing else &"copier_closed", Rect2(Vector2.ZERO, size))

var choice_buttons: Array[Button] = []
var return_button: Button
var error_label: Label
var _paper: Panel
var _content: Control
var _title: Label
var _body: Label
var _receipt: Label
var _history: Label
var _choices: Control
var _art: CopierArt
var _option_panels: Array[Panel] = []
var _descriptions: Array[Label] = []
var _reasons: Array[Label] = []
var _last_focus: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.97)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper = Panel.new()
	_paper.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	add_child(_paper)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(_content)
	_title = UiTheme.section_label("", 29)
	_title.clip_text = true
	_content.add_child(_title)
	_body = _wrapped_label(15, UiTheme.DIM)
	_content.add_child(_body)
	_art = CopierArt.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_art)
	_choices = Control.new()
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_choices)
	_receipt = _wrapped_label(15, UiTheme.ACCENT)
	_content.add_child(_receipt)
	_history = _wrapped_label(13, UiTheme.DIM)
	_history.visible = false
	_content.add_child(_history)
	error_label = _wrapped_label(14, UiTheme.WARN)
	error_label.visible = false
	_content.add_child(error_label)
	return_button = Button.new()
	WorkshopUi.fit_button(return_button, 16, 36.0)
	return_button.pressed.connect(close)
	_content.add_child(return_button)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	visible = false


static func _wrapped_label(font_size: int, color: Color) -> Label:
	var label := UiTheme.label("", font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	return label


func open_confession(sim: Sim) -> void:
	if sim == null:
		reset()
		return
	_last_focus = null
	# Assign real widths before changing wrapped text. Labels cannot resize the
	# page or move the primary return control outside the native canvas.
	_apply_layout()
	_title.text = Loc.t("confession.ui.title")
	_title.add_theme_font_override("font", UiTheme.title_font(_title.text))
	_body.text = Loc.t("confession.ui.rule")
	_body.tooltip_text = _body.text
	return_button.text = Loc.t("confession.ui.return")
	error_label.visible = false
	error_label.text = ""
	UiTheme.clear(_choices)
	choice_buttons.clear()
	_option_panels.clear()
	_descriptions.clear()
	_reasons.clear()
	var profile := BureauConfession.profile(sim)
	var selected := StringName(profile.get("chosen", &""))
	_art.printing = selected != &""
	_art.queue_redraw()
	for option: Dictionary in BureauConfession.options(sim):
		_add_option(option, profile)
	if selected != &"":
		var choice_name := Loc.t("confession.truth" if selected == &"truth" else "confession.polish")
		var state_name := _status_text(StringName(profile.get("signed_state", &"unsigned")), selected)
		_receipt.text = Loc.t("confession.ui.signed", [int(profile.get("act", 1)), choice_name, state_name])
	else:
		_receipt.text = Loc.t("confession.ui.unsigned")
	_receipt.tooltip_text = _receipt.text
	var records := PackedStringArray()
	for row: Dictionary in profile.get("history", []):
		if int(row["act"]) == int(profile.get("act", 1)):
			continue
		var name_key := "confession.truth" if row["choice"] == &"truth" else "confession.polish"
		records.append(Loc.t("confession.ui.history_row", [int(row["act"]), Loc.t(name_key), _status_text(row["state"], row["choice"])]))
	_history.text = Loc.t("confession.ui.history", [" · ".join(records)]) if not records.is_empty() else ""
	_history.tooltip_text = _history.text
	_history.visible = not records.is_empty()
	_apply_layout()
	visible = true
	var controls: Array = []
	for button in choice_buttons:
		if not button.disabled:
			controls.append(button)
	controls.append(return_button)
	UiFocus.cycle(controls)
	focus_default()


func _add_option(option: Dictionary, profile: Dictionary) -> void:
	var id := StringName(option.get("id", &""))
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.CARD))
	_choices.add_child(panel)
	_option_panels.append(panel)
	var button := Button.new()
	button.text = Loc.t(str(option.get("name_key", "")))
	button.clip_text = true
	button.disabled = not bool(option.get("available", false))
	button.set_meta(&"confession_id", id)
	button.pressed.connect(func() -> void: chosen.emit(id))
	button.focus_entered.connect(func() -> void: _last_focus = button)
	panel.add_child(button)
	choice_buttons.append(button)
	var detail := ""
	if id == &"truth":
		if profile.get("truth_kind", &"") == &"echo":
			detail = Loc.t("confession.ui.truth_echo", [float(profile.get("truth_amount", 0.0)), int(profile.get("truth_uid", 0))])
		else:
			detail = Loc.t("confession.ui.truth_health", [float(profile.get("truth_amount", 0.0))])
	else:
		detail = Loc.t("confession.ui.polish_effect", [int(profile.get("polish_materials", 12))])
	var description := _wrapped_label(15, UiTheme.INK)
	description.text = detail
	description.tooltip_text = detail
	panel.add_child(description)
	_descriptions.append(description)
	var reason_key := str(option.get("reason_key", ""))
	var reason := Loc.t(reason_key) if reason_key != "" else Loc.t("confession.ui.ready")
	var reason_label := _wrapped_label(14, UiTheme.DIM)
	reason_label.text = reason
	reason_label.tooltip_text = reason
	panel.add_child(reason_label)
	_reasons.append(reason_label)
	button.accessibility_name = button.text
	button.accessibility_description = detail + " · " + Loc.t(str(option.get("description_key", ""))) + " · " + reason
	button.tooltip_text = button.accessibility_description


func show_error(message: String) -> void:
	error_label.text = message
	error_label.tooltip_text = message
	error_label.visible = message != ""
	_apply_layout()


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


func _apply_layout() -> void:
	if _content == null:
		return
	var extent := get_viewport_rect().size
	var compact := extent.x < 1100.0 or extent.y < 640.0
	_paper.position = Vector2(28, 18)
	_paper.size = Vector2(maxf(0.0, extent.x - 56.0), maxf(0.0, extent.y - 36.0))
	_content.position = Vector2(16, 12)
	_content.size = Vector2(maxf(0.0, _paper.size.x - 32.0), maxf(0.0, _paper.size.y - 24.0))
	var width := _content.size.x
	var height := _content.size.y
	_title.position = Vector2.ZERO
	_title.size = Vector2(width, 32 if compact else 38)
	_title.add_theme_font_size_override("font_size", 25 if compact else 29)
	_body.position = Vector2(0, 34 if compact else 42)
	_body.size = Vector2(width, 42 if compact else 48)
	_body.add_theme_font_size_override("font_size", 14 if compact else 15)
	var return_height := 32.0 if compact else 36.0
	WorkshopUi.fit_button(return_button, 15 if compact else 16, return_height)
	return_button.position = Vector2(0, maxf(0.0, height - return_height))
	return_button.size = Vector2(width, return_height)
	var error_height := 36.0 if error_label.visible else 0.0
	error_label.position = Vector2(0, return_button.position.y - error_height - 5.0)
	error_label.size = Vector2(width, error_height)
	var history_height := 38.0 if _history.visible else 0.0
	_history.position = Vector2(0, error_label.position.y - history_height - (4.0 if _history.visible else 0.0))
	_history.size = Vector2(width, history_height)
	_receipt.position = Vector2(0, _history.position.y - 44.0)
	_receipt.size = Vector2(width, 40.0)
	_receipt.add_theme_font_size_override("font_size", 14 if compact else 15)
	var top := 82.0 if compact else 96.0
	var available := maxf(0.0, _receipt.position.y - top - 6.0)
	var art_width := 126.0 if compact else 220.0
	_art.position = Vector2(0, top + maxf(0.0, (available - 230.0) * 0.5))
	_art.size = Vector2(art_width, minf(230.0, available))
	_choices.position = Vector2(art_width + 18.0, top)
	_choices.size = Vector2(maxf(0.0, width - art_width - 18.0), available)
	var option_height := minf(164.0, maxf(0.0, (available - 8.0) * 0.5))
	for index in _option_panels.size():
		var panel := _option_panels[index]
		panel.position = Vector2(0, float(index) * (option_height + 8.0))
		panel.size = Vector2(_choices.size.x, option_height)
		var inner := maxf(0.0, panel.size.x - 16.0)
		var button := choice_buttons[index]
		WorkshopUi.fit_button(button, 15 if compact else 17, 30.0 if compact else 34.0)
		button.position = Vector2(8, 5)
		button.size = Vector2(inner, 30 if compact else 34)
		var reason_height := 22.0
		_reasons[index].position = Vector2(8, maxf(0.0, option_height - reason_height - 4.0))
		_reasons[index].size = Vector2(inner, reason_height)
		_reasons[index].add_theme_font_size_override("font_size", 13 if compact else 14)
		_descriptions[index].position = Vector2(8, 39 if compact else 43)
		_descriptions[index].size = Vector2(inner, maxf(0.0, _reasons[index].position.y - _descriptions[index].position.y - 3.0))
		_descriptions[index].add_theme_font_size_override("font_size", 14 if compact else 15)


static func _status_text(state: StringName, choice: StringName) -> String:
	match state:
		&"pending": return Loc.t("confession.ui.state_pending")
		&"active": return Loc.t("confession.ui.state_active")
		&"passed": return Loc.t("confession.ui.state_recorded" if choice == &"truth" else "confession.ui.state_verified")
		&"missed": return Loc.t("confession.ui.state_missed")
	return Loc.t("confession.ui.state_unsigned")
