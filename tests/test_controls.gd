extends RefCounted


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


func _has_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
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
	c.ok(_has_key(&"retire_echo", KEY_SPACE), "Space retires the selected copy")
	c.ok(_has_button(&"retire_echo", JOY_BUTTON_RIGHT_SHOULDER), "right shoulder retires the selected copy")


func test_display_labels_follow_the_actual_registered_bindings(c: Check) -> void:
	Controls.register()
	var original := InputMap.action_get_events(&"character_skill")
	var old_device := Controls.using_gamepad
	InputMap.action_erase_events(&"character_skill")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event(&"character_skill", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"character_skill", pad)
	Controls.using_gamepad = false
	c.eq(Controls.skill_label(), "F", "keyboard hint follows a changed physical binding")
	Controls.using_gamepad = true
	c.eq(Controls.skill_label(), "Y", "gamepad hint follows its real button binding")
	InputMap.action_erase_events(&"character_skill")
	c.eq(Controls.skill_label(), Loc.t("controls.unbound"), "missing binding has a localized explicit state")
	for event in original:
		InputMap.action_add_event(&"character_skill", event)
	Controls.using_gamepad = old_device


func test_an_unregistered_action_has_a_safe_localized_label(c: Check) -> void:
	var missing := &"_closeout_missing_input"
	c.ok(not InputMap.has_action(missing), "the boundary action genuinely does not exist")
	var old_device := Controls.using_gamepad
	for gamepad in [false, true]:
		Controls.using_gamepad = gamepad
		c.eq(Controls.action_label(missing), Loc.t("controls.unbound"), "absent mappings return a typed safe fallback for either device")
	Controls.using_gamepad = old_device
