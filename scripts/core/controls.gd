class_name Controls
extends RefCounted


static func register() -> void:
	_gamepad_ui()
	_bind(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)])
	_bind(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)])
	_bind(&"move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)])
	_bind(&"move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)])
	_bind(&"pause", [_key(KEY_P), _key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_bind(&"restart", [_key(KEY_R)])
	_bind(&"retry", [_key(KEY_S)])
	_bind(&"quit_run", [_key(KEY_Q)])
	_bind(&"settings", [_key(KEY_O)])
	_bind(&"history", [_key(KEY_H)])
	_bind(&"character", [_key(KEY_C)])
	_bind(&"mute", [_key(KEY_M)])
	_bind(&"debug", [_key(KEY_F3), _button(JOY_BUTTON_BACK)])


# Godot's built-in UI actions are keyboard-only by default. Steam Deck and a standard
# controller need A/B + d-pad to focus and activate the shop, select, settings and end screens.
static func _gamepad_ui() -> void:
	_add_event(&"ui_accept", _button(JOY_BUTTON_A))
	_add_event(&"ui_cancel", _button(JOY_BUTTON_B))
	_add_event(&"ui_up", _button(JOY_BUTTON_DPAD_UP))
	_add_event(&"ui_down", _button(JOY_BUTTON_DPAD_DOWN))
	_add_event(&"ui_left", _button(JOY_BUTTON_DPAD_LEFT))
	_add_event(&"ui_right", _button(JOY_BUTTON_DPAD_RIGHT))


static func _add_event(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for current in InputMap.action_get_events(action):
		if current.is_match(event):
			return
	InputMap.action_add_event(action, event)


static func _bind(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


static func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = index
	return ev
