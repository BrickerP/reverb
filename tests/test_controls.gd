extends RefCounted


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


func test_gamepad_ui_uses_standard_buttons(c: Check) -> void:
	Controls.register()
	c.ok(_has_button(&"ui_accept", JOY_BUTTON_A), "A activates")
	c.ok(_has_button(&"ui_cancel", JOY_BUTTON_B), "B cancels")
	c.ok(_has_button(&"ui_up", JOY_BUTTON_DPAD_UP), "d-pad up")
	c.ok(_has_button(&"ui_down", JOY_BUTTON_DPAD_DOWN), "d-pad down")
	c.ok(_has_button(&"ui_left", JOY_BUTTON_DPAD_LEFT), "d-pad left")
	c.ok(_has_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT), "d-pad right")
	c.ok(_has_button(&"debug", JOY_BUTTON_BACK), "View toggles debug")
