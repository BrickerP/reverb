class_name Controls
extends RefCounted

static var using_gamepad := false


static func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not (event is InputEventJoypadMotion) or absf(event.axis_value) > 0.3:
			using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		using_gamepad = false


static func retire_label() -> String:
	return action_label(&"retire_echo")


static func skill_label() -> String:
	return action_label(&"character_skill")


static func interact_label() -> String:
	return action_label(&"interact")


static func move_label() -> String:
	if using_gamepad:
		return action_label(&"move_up", true)
	var names := PackedStringArray()
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		names.append(action_label(action))
	return "".join(names) if names[0].length() == 1 and names[1].length() == 1 and names[2].length() == 1 and names[3].length() == 1 else " / ".join(names)


static func pause_label() -> String:
	return action_label(&"pause")


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
	_bind(&"character_skill", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_bind(&"interact", [_key(KEY_E), _button(JOY_BUTTON_X)])
	_bind(&"retire_echo", [_key(KEY_SPACE), _button(JOY_BUTTON_RIGHT_SHOULDER)])


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


static func action_label(action: StringName, movement: bool = false) -> String:
	var events: Array[InputEvent] = []
	if InputMap.has_action(action):
		events = InputMap.action_get_events(action)
	if using_gamepad:
		if movement:
			for event in events:
				if event is InputEventJoypadMotion:
					return "LS" if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "RS"
		var labels := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "MENU",
			JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_DPAD_UP: "DPAD ↑", JOY_BUTTON_DPAD_DOWN: "DPAD ↓",
			JOY_BUTTON_DPAD_LEFT: "DPAD ←", JOY_BUTTON_DPAD_RIGHT: "DPAD →"}
		for event in events:
			if event is InputEventJoypadButton:
				return labels.get(event.button_index, event.as_text())
	else:
		var names := PackedStringArray()
		for event in events:
			if event is InputEventKey:
				var code: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				var label := OS.get_keycode_string(code).to_upper()
				if not names.has(label):
					names.append(label)
				if not movement:
					return label
		if movement and not names.is_empty():
			return " / ".join(names)
	return Loc.t("controls.unbound")
