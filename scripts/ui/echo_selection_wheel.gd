class_name EchoSelectionWheel
extends Control

signal selection_changed(uid: int)
signal cancelled

const PAGE_SIZE := 8
const CENTER := Vector2(640.0, 344.0)
const RADIUS := Vector2(360.0, 184.0)

var reduced_effects := false
var buttons: Array[Button] = []
var _sim: Sim
var _uids: Array[int] = []
var _selected := 0
var _cancelled := false
var _detail: Label
var _heading: Label
var _hint: Label
var _surface: PanelContainer
var _previous: Button
var _next: Button


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heading = UiTheme.label(Loc.t("echo.wheel_title"), 34, UiTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_heading.position = Vector2(290.0, 72.0)
	_heading.size = Vector2(700.0, 50.0)
	add_child(_heading)
	_surface = PanelContainer.new()
	_surface.position = Vector2(448.0, 276.0)
	_surface.custom_minimum_size = Vector2(384.0, 136.0)
	_surface.add_theme_stylebox_override("panel", UiTheme.paper_panel())
	add_child(_surface)
	_detail = UiTheme.label("", 16, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(336.0, 110.0)
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_surface.add_child(_detail)
	_hint = UiTheme.label("", 16, UiTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.position = Vector2(190.0, 601.0)
	_hint.size = Vector2(900.0, 62.0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	_previous = Button.new()
	_previous.text = Loc.t("echo.previous")
	_previous.position = Vector2(290.0, 558.0)
	_previous.size = Vector2(170.0, 36.0)
	_previous.pressed.connect(_change_page.bind(-1))
	add_child(_previous)
	_next = Button.new()
	_next.text = Loc.t("echo.next")
	_next.position = Vector2(820.0, 558.0)
	_next.size = Vector2(170.0, 36.0)
	_next.pressed.connect(_change_page.bind(1))
	add_child(_next)


# Main pauses simulation before opening. This view only highlights a stable UID;
# releasing the held action is committed by Main, never by a button in the wheel.
func open(sim: Sim) -> void:
	_sim = sim
	_cancelled = false
	for button in buttons:
		remove_child(button)
		button.queue_free()
	buttons.clear()
	_uids.clear()
	_selected = 0
	for actor in sim.echoes:
		if actor.take.condition > 0.0:
			_uids.append(actor.take.uid)
	for index in _uids.size():
		if _uids[index] == sim.selected_echo_uid:
			_selected = index
		var actor := _actor(_uids[index])
		var button := Button.new()
		button.name = "Copy_%d" % _uids[index]
		button.custom_minimum_size = Vector2(164.0, 72.0)
		button.size = button.custom_minimum_size
		var page_count := mini(PAGE_SIZE, _uids.size() - (index / PAGE_SIZE) * PAGE_SIZE)
		var angle := -PI * 0.5 + TAU * float(index % PAGE_SIZE) / float(page_count)
		button.position = CENTER + Vector2(cos(angle), sin(angle)) * RADIUS - button.size * 0.5
		button.text = Loc.t("echo.wheel_copy", [actor.take.uid, int(ceil(actor.take.condition))])
		button.accessibility_name = Loc.t("echo.identity", [actor.take.uid, actor.take.wave])
		button.accessibility_description = Loc.echo_profile(EchoSystem.skill_profile(actor.take, sim), true)
		button.add_theme_stylebox_override("normal", UiTheme.paper_panel())
		button.focus_entered.connect(_highlight.bind(index))
		button.mouse_entered.connect(_highlight.bind(index))
		button.pressed.connect(_highlight.bind(index))
		add_child(button)
		buttons.append(button)
	visible = true
	_hint.text = Loc.t("echo.wheel_hint", [Controls.retire_label()])
	_highlight(_selected)
	focus_default()


func selected_uid() -> int:
	return 0 if _cancelled or _uids.is_empty() else _uids[_selected]


func close() -> int:
	var uid := selected_uid()
	visible = false
	_sim = null
	return uid


func cancel() -> void:
	_cancelled = true
	_sim = null
	visible = false
	cancelled.emit()


func focus_default() -> void:
	if not buttons.is_empty():
		buttons[_selected].grab_focus()


func _actor(uid: int) -> EchoActor:
	if _sim != null:
		for actor in _sim.echoes:
			if actor.take.uid == uid:
				return actor
	return null


func _highlight(index: int) -> void:
	_previous.visible = _uids.size() > PAGE_SIZE
	_next.visible = _previous.visible
	if _uids.is_empty():
		_heading.text = Loc.t("echo.wheel_title")
		_detail.text = Loc.t("echo.wheel_empty")
		return
	_selected = posmod(index, _uids.size())
	_heading.text = Loc.t("echo.wheel_title")
	if _uids.size() > PAGE_SIZE:
		_heading.text += " · " + Loc.t("echo.page", [_selected / PAGE_SIZE + 1, ceili(float(_uids.size()) / float(PAGE_SIZE))])
	for i in buttons.size():
		buttons[i].visible = i / PAGE_SIZE == _selected / PAGE_SIZE
		buttons[i].add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PAPER,
				UiTheme.ACCENT if i == _selected else UiTheme.EDGE, 3 if i == _selected else 1, 8))
	var actor := _actor(selected_uid())
	if actor != null:
		_detail.text = Loc.t("echo.identity", [actor.take.uid, actor.take.wave]) + "\n" \
				+ Loc.echo_profile(EchoSystem.skill_profile(actor.take, _sim), true)
	var focus_controls: Array[Control] = []
	focus_controls.append_array(buttons)
	focus_controls.append_array([_previous, _next])
	UiFocus.cycle(focus_controls)
	selection_changed.emit(selected_uid())


func _input(event: InputEvent) -> void:
	if not visible:
		return
	Controls.note_event(event)
	_hint.text = Loc.t("echo.wheel_hint", [Controls.retire_label()])
	if event.is_action_pressed(&"ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	if _uids.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_change_page(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
		return
	var direction := 0
	if event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"ui_down", true) \
			or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_D, KEY_S]):
		direction = 1
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_up", true) \
			or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_A, KEY_W]):
		direction = -1
	if direction != 0:
		_highlight(_selected + direction)
		focus_default()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var stick := Vector2(Input.get_joy_axis(event.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(event.device, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.45:
			var angle := fposmod(stick.angle() + PI * 0.5, TAU)
			var page_start := (_selected / PAGE_SIZE) * PAGE_SIZE
			var count := mini(PAGE_SIZE, _uids.size() - page_start)
			_highlight(page_start + posmod(roundi(angle / TAU * float(count)), count))
			focus_default()
		get_viewport().set_input_as_handled()


func _change_page(direction: int) -> void:
	if _uids.is_empty():
		return
	var pages := ceili(float(_uids.size()) / float(PAGE_SIZE))
	var page := posmod(_selected / PAGE_SIZE + direction, pages)
	_highlight(mini(page * PAGE_SIZE + _selected % PAGE_SIZE, _uids.size() - 1))
	focus_default()
