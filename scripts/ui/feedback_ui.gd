class_name FeedbackUi
extends Control

signal submit_requested(category: StringName, rating: StringName, note: String)
signal closed
signal open_log_requested

const MAX_NOTE_LENGTH := 500
const CATEGORIES: Array[StringName] = [
	&"builds", &"shop", &"combat", &"echoes", &"performance", &"other",
]
const RATINGS: Array[StringName] = [&"good", &"mixed", &"frustrating"]
const CATEGORY_LABEL_KEYS: Array[String] = [
	"feedback.category.builds", "feedback.category.shop", "feedback.category.combat",
	"feedback.category.echoes", "feedback.category.performance", "feedback.category.other",
]
const RATING_LABEL_KEYS: Array[String] = [
	"feedback.feeling.good", "feedback.feeling.mixed", "feedback.feeling.frustrating",
]

var category_option: OptionButton
var rating_option: OptionButton
var note_edit: TextEdit
var save_button: Button
var cancel_button: Button
var open_log_button: Button
var status_label: Label
var notice_label: Label

var _run_id := ""
var _can_submit := false
var _submitted := false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.9)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("feedback.title"), 30, UiTheme.INK,
			HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("feedback.subtitle"), 14, UiTheme.DIM,
			HORIZONTAL_ALIGNMENT_CENTER))

	category_option = _option_row(box, "feedback.category", CATEGORIES, CATEGORY_LABEL_KEYS)
	rating_option = _option_row(box, "feedback.feeling", RATINGS, RATING_LABEL_KEYS)
	category_option.select(0)
	rating_option.select(1)

	var note_header := HBoxContainer.new()
	note_header.add_child(UiTheme.label(Loc.t("feedback.note"), 16, UiTheme.DIM))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_header.add_child(spacer)
	var limit := UiTheme.label(Loc.t("feedback.note_limit", [MAX_NOTE_LENGTH]), 12, UiTheme.DIM)
	note_header.add_child(limit)
	box.add_child(note_header)
	note_edit = TextEdit.new()
	note_edit.custom_minimum_size = Vector2(0.0, 116.0)
	note_edit.placeholder_text = Loc.t("feedback.note_hint")
	note_edit.tab_input_mode = false
	note_edit.accessibility_name = Loc.t("feedback.note")
	note_edit.add_theme_stylebox_override("normal",
			UiTheme.box(Color(0.04, 0.055, 0.065), Color(0.25, 0.30, 0.34), 1))
	note_edit.add_theme_stylebox_override("focus",
			UiTheme.box(Color(0.04, 0.055, 0.065), UiTheme.ACCENT, 2))
	note_edit.text_changed.connect(_on_note_changed)
	box.add_child(note_edit)

	notice_label = UiTheme.label(Loc.t("feedback.local_only"), 13, UiTheme.DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(notice_label)
	status_label = UiTheme.label("", 14, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = false
	box.add_child(status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	save_button = _button(Loc.t("feedback.save"))
	save_button.pressed.connect(_submit)
	buttons.add_child(save_button)
	cancel_button = _button(Loc.t("feedback.cancel"))
	cancel_button.pressed.connect(close)
	buttons.add_child(cancel_button)
	open_log_button = _button(Loc.t("feedback.open_folder"))
	open_log_button.pressed.connect(func() -> void: open_log_requested.emit())
	open_log_button.visible = false
	buttons.add_child(open_log_button)
	box.add_child(buttons)


func open_for_run(run_id: String, can_submit: bool, already_submitted: bool) -> void:
	if run_id != _run_id:
		reset()
	_run_id = run_id
	_can_submit = can_submit
	_submitted = already_submitted
	open_log_button.visible = already_submitted
	_set_form_editable(can_submit and not already_submitted)
	if not can_submit:
		_show_status(Loc.t("feedback.unavailable"), false)
	elif already_submitted:
		_show_status(Loc.t("feedback.already_saved"), true)
	else:
		_show_status("", false)
	visible = true
	_rebuild_focus_cycle()
	if note_edit.editable:
		category_option.grab_focus()
	elif open_log_button.visible:
		open_log_button.grab_focus()
	else:
		cancel_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func reset() -> void:
	_run_id = ""
	_can_submit = false
	_submitted = false
	if category_option != null:
		category_option.select(0)
	if rating_option != null:
		rating_option.select(1)
	if note_edit != null:
		note_edit.text = ""
	if category_option != null:
		_set_form_editable(true)
	if open_log_button != null:
		open_log_button.visible = false
	if status_label != null:
		_show_status("", false)
	visible = false
	_update_save_state()


func set_submission_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_submitted = true
		open_log_button.visible = true
		_set_form_editable(false)
		_show_status(Loc.t("feedback.saved"), true)
		_rebuild_focus_cycle()
		open_log_button.grab_focus()
		return
	var reason := str(result.get("reason", "write_failed"))
	_show_status(_error_text(reason), false)
	_update_save_state()


func _option_row(box: VBoxContainer, key: String, ids: Array[StringName],
		label_keys: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := UiTheme.label(Loc.t(key), 16, UiTheme.DIM)
	label.custom_minimum_size = Vector2(128.0, 0.0)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.accessibility_name = Loc.t(key)
	for i in ids.size():
		var id: StringName = ids[i]
		option.add_item(Loc.t(label_keys[i]))
		option.set_item_metadata(option.item_count - 1, id)
	row.add_child(option)
	box.add_child(row)
	return option


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 42.0)
	return button


func _submit() -> void:
	if save_button.disabled:
		return
	var category := StringName(category_option.get_item_metadata(category_option.selected))
	var rating := StringName(rating_option.get_item_metadata(rating_option.selected))
	submit_requested.emit(category, rating, note_edit.text)


func _on_note_changed() -> void:
	if note_edit.text.length() > MAX_NOTE_LENGTH:
		_show_status(Loc.t("feedback.error_note_too_long", [MAX_NOTE_LENGTH]), false)
	elif status_label.visible and not _submitted:
		_show_status("", false)
	_update_save_state()


func _error_text(reason: String) -> String:
	match reason:
		"duplicate":
			return Loc.t("feedback.error_duplicate")
		"invalid_run":
			return Loc.t("feedback.error_invalid_run")
		"invalid_provenance":
			return Loc.t("feedback.error_invalid_provenance")
		"invalid_category":
			return Loc.t("feedback.error_invalid_category")
		"invalid_rating":
			return Loc.t("feedback.error_invalid_rating")
		"note_too_long":
			return Loc.t("feedback.error_note_too_long", [MAX_NOTE_LENGTH])
		_:
			return Loc.t("feedback.error_write_failed")


func _update_save_state() -> void:
	if save_button == null:
		return
	save_button.disabled = not _can_submit or _submitted \
			or note_edit == null or note_edit.text.length() > MAX_NOTE_LENGTH


func _set_form_editable(editable: bool) -> void:
	category_option.disabled = not editable
	rating_option.disabled = not editable
	note_edit.editable = editable
	cancel_button.text = Loc.t("feedback.cancel") if editable else Loc.t("feedback.close")


func _show_status(text: String, success: bool) -> void:
	status_label.text = text
	status_label.visible = text != ""
	status_label.add_theme_color_override("font_color", UiTheme.ACCENT if success else UiTheme.WARN)
	_update_save_state()


func _rebuild_focus_cycle() -> void:
	var controls: Array[Control] = []
	if note_edit.editable:
		controls.append(category_option)
		controls.append(rating_option)
		controls.append(note_edit)
		controls.append(save_button)
	controls.append(cancel_button)
	if open_log_button.visible:
		controls.append(open_log_button)
	UiFocus.cycle(controls)
	# Keep TextEdit's arrows available for caret movement; Tab still follows the modal cycle.
	note_edit.focus_neighbor_left = NodePath()
	note_edit.focus_neighbor_right = NodePath()
	note_edit.focus_neighbor_top = NodePath()
	note_edit.focus_neighbor_bottom = NodePath()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
