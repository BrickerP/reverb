class_name InspectionPopover
extends Control

signal action_requested(action: StringName)
const FOOTER_CLEARANCE := 56.0
var focus_enabled := false
var pointer_enabled := false
var pinned := false
var sheet: PanelContainer
var definition: PanelContainer
var title_label: Label
var summary_label: Label
var facts_label: Label
var definition_body: Label
var details_button: Button
var rule_buttons: Array[Button] = []
var action_buttons: Array[Button] = []
var _source: Control
var _ignored_source := 0
var _box: VBoxContainer
var _definition_box: VBoxContainer
var _payload: Dictionary = {}
var _generation := 0
var _leave_time := 0.0
var _rule_leave_time := 0.0
var _term_source: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.CARD))
	sheet.custom_minimum_size.x = 310
	add_child(sheet)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	sheet.add_child(_box)
	definition = PanelContainer.new()
	var paper := UiTheme.paper_panel(UiTheme.PAPER)
	paper.shape = InkStyleBox.Shape.TAG
	definition.add_theme_stylebox_override("panel", paper)
	definition.custom_minimum_size.x = 280
	add_child(definition)
	_definition_box = VBoxContainer.new()
	_definition_box.add_theme_constant_override("separation", 6)
	definition.add_child(_definition_box)
	reset()


func present(source: Control, payload: Dictionary, pin: bool = false) -> void:
	if not is_instance_valid(source) or not source.is_visible_in_tree():
		return
	if pinned and not pin:
		return
	if visible and _source == source and not pin:
		return
	if not pin and _ignored_source == source.get_instance_id():
		return
	_generation += 1
	var generation := _generation
	if _ignored_source != source.get_instance_id():
		_ignored_source = 0
	_source = source
	_payload = payload
	pinned = pin
	_leave_time = 0.0
	UiTheme.clear(_box)
	rule_buttons.clear()
	action_buttons.clear()
	definition.hide()
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	identity.add_child(UiTheme.art_icon(StringName(payload["art"]), Vector2(70, 60)))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(words)
	title_label = _text(str(payload["title"]), 18)
	words.add_child(title_label)
	var subtitle := str(payload.get("subtitle", ""))
	if subtitle != "":
		words.add_child(_text(subtitle, 12, UiTheme.DIM))
	_box.add_child(identity)
	summary_label = _text(str(payload.get("summary", "")), 14)
	_box.add_child(summary_label)
	facts_label = _text(str(payload.get("facts", "")), 13, UiTheme.COIN)
	_box.add_child(facts_label)
	var change: Dictionary = payload.get("change", {})
	if not change.is_empty():
		var visual := WorkshopUi.ChangeVisual.new()
		visual.custom_minimum_size.y = 72.0
		visual.setup(change, true)
		_box.add_child(visual)
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation", 8)
	_box.add_child(rules)
	var definitions: Array = payload.get("rules", [])
	for index in definitions.size():
		var button := StitchedAction.new()
		button.text = str(definitions[index]["title"])
		button.add_theme_font_size_override("font_size", 13)
		button.mouse_entered.connect(reveal_rule.bind(index, button))
		button.focus_entered.connect(reveal_rule.bind(index, button))
		button.pressed.connect(reveal_rule.bind(index, button))
		rules.add_child(button)
		rule_buttons.append(button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	_box.add_child(actions)
	details_button = Button.new()
	details_button.text = Loc.t("inspection.details")
	details_button.pressed.connect(_emit_action.bind(&"details", generation))
	actions.add_child(details_button)
	for entry: Dictionary in payload.get("actions", []):
		var button := Button.new()
		button.text = str(entry["text"])
		button.disabled = bool(entry.get("disabled", false))
		if not button.disabled:
			button.pressed.connect(_emit_action.bind(StringName(entry["action"]), generation))
		actions.add_child(button)
		action_buttons.append(button)
	var close := Button.new()
	close.text = Loc.t("inspection.close")
	close.pressed.connect(close_inspection)
	actions.add_child(close)
	for button: Button in [details_button, close] + action_buttons:
		WorkshopUi.fit_button(button, 13, 28)
	_box.add_child(_text(Loc.t("inspection.pad_hint" if Controls.using_gamepad else "inspection.pointer_hint"), 11, UiTheme.DIM))
	visible = true
	sheet.show()
	sheet.reset_size()
	_place()
	if pin:
		var focus: Array = [details_button]
		focus.append_array(rule_buttons)
		focus.append_array(action_buttons)
		focus.append(close)
		UiFocus.cycle(focus)
		for i in focus.size():
			var current := focus[i] as Control
			current.focus_neighbor_left = current.get_path_to(focus[(i - 1 + focus.size()) % focus.size()])
			current.focus_neighbor_right = current.get_path_to(focus[(i + 1) % focus.size()])
		details_button.grab_focus()


func reveal_rule(index: int, source: Control) -> void:
	if not is_instance_valid(source) or not is_ancestor_of(source):
		return
	var rules: Array = _payload.get("rules", [])
	if index < 0 or index >= rules.size():
		return
	UiTheme.clear(_definition_box)
	_definition_box.add_child(_text(str(rules[index]["title"]), 17))
	definition_body = _text(str(rules[index]["body"]), 14)
	_definition_box.add_child(definition_body)
	_term_source = source
	_rule_leave_time = 0.0
	definition.show()
	definition.reset_size()
	_place()


func _emit_action(action: StringName, generation: int) -> void:
	if visible and generation == _generation:
		action_requested.emit(action)


func source_left(source: Control) -> void:
	if is_instance_valid(source) and _ignored_source == source.get_instance_id():
		_ignored_source = 0


func close_inspection() -> void:
	var source := _source
	if is_instance_valid(source):
		_ignored_source = source.get_instance_id()
	reset(false)
	if is_instance_valid(source) and source.is_visible_in_tree():
		source.grab_focus()


func reset(clear_ignore: bool = true) -> void:
	_generation += 1
	pinned = false
	_source = null
	_payload.clear()
	_leave_time = 0.0
	if clear_ignore:
		_ignored_source = 0
	hide()
	if sheet != null:
		sheet.hide()
		definition.hide()


func _process(delta: float) -> void:
	if not visible:
		return
	if get_viewport().gui_is_dragging():
		reset()
		return
	if not is_instance_valid(_source) or not _source.is_visible_in_tree():
		reset()
		return
	_place()
	var point := get_global_mouse_position()
	if definition.visible:
		var over_rule := is_instance_valid(_term_source) and _term_source.get_global_rect().has_point(point)
		var rule_focus := focus_enabled and get_viewport().gui_get_focus_owner() == _term_source
		_rule_leave_time = 0.0 if over_rule or rule_focus or definition.get_global_rect().has_point(point) else _rule_leave_time + delta
		if _rule_leave_time > 0.2:
			definition.hide()
	if pinned:
		return
	var over := _source.get_global_rect().has_point(point) or sheet.get_global_rect().has_point(point) \
			or (definition.visible and definition.get_global_rect().has_point(point))
	var keyboard := focus_enabled and get_viewport().gui_get_focus_owner() == _source
	_leave_time = 0.0 if over or keyboard else _leave_time + delta
	if _leave_time > 0.2:
		reset()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if definition.visible:
		definition.hide()
	else:
		close_inspection()
	accept_event()


func _place() -> void:
	if not is_instance_valid(_source):
		return
	var extent := get_viewport_rect().size
	var origin := _source.get_global_rect()
	var desired := sheet.get_combined_minimum_size()
	sheet.size = Vector2(minf(310, extent.x - 24), desired.y)
	var x := origin.end.x + 8
	if x + sheet.size.x > extent.x - 12:
		x = origin.position.x - sheet.size.x - 8
	sheet.position = Vector2(clampf(x, 12, maxf(12, extent.x - sheet.size.x - 12)),
		clampf(origin.position.y, 12, maxf(12, extent.y - sheet.size.y - FOOTER_CLEARANCE)))
	if definition.visible:
		definition.size = Vector2(280, definition.get_combined_minimum_size().y)
		var next_x := sheet.position.x - definition.size.x - 6
		if next_x < 12:
			next_x = sheet.position.x + sheet.size.x + 6
		var y := _term_source.global_position.y if is_instance_valid(_term_source) else sheet.position.y
		definition.position = Vector2(clampf(next_x, 12, maxf(12, extent.x - definition.size.x - 12)),
			clampf(y, 12, maxf(12, extent.y - definition.size.y - FOOTER_CLEARANCE)))


static func _text(value: String, font_size: int, color: Color = UiTheme.INK) -> Label:
	var label := UiTheme.label(value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
