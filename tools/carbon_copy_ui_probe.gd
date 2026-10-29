extends SceneTree
# Actual-window UI evidence. Run once with REVERB_LANG=en and once with REVERB_LANG=zh.
# Key/joypad events below exercise Godot's real input path; no physical controller is claimed.
# Hover checks briefly move the native pointer inside this game window and restore it on exit.
# godot --path . --fixed-fps 60 --disable-vsync --script res://tools/carbon_copy_ui_probe.gd

var _main: Node
var _started_ms := Time.get_ticks_msec()
var _failed := false
var _shots_dir := ""
var _mouse_target := Vector2.ZERO
var _original_pointer := Vector2.ZERO
var _pointer_saved := false
var _summary: Dictionary = {"screenshots": {}, "navigation": [], "physical_controller": false, "art_direction": "organic hand-drawn ink", "visual_checks": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_carbon_copy_ui_probe_suspend.json")
	var names: Dictionary = {"REVERB_SAVE": "test_carbon_ui_save.json",
		"REVERB_RUN_LOG": "test_carbon_ui_runs.jsonl", "REVERB_SETTINGS": "test_carbon_ui_settings.json",
		"REVERB_FEEDBACK_LOG": "test_carbon_ui_feedback.jsonl"}
	for entry in names:
		var isolated: String = "user://" + str(names[entry])
		OS.set_environment(entry, isolated)
		if FileAccess.file_exists(isolated):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(isolated))
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	if DisplayServer.get_name() == "headless":
		_fail("this probe requires a real rendering window")
		return
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started_ms > 120000 and not _failed:
		_fail("deadline before all UI states were captured")
	return false


func _run() -> void:
	await _wait(5)
	_original_pointer = root.get_mouse_position()
	_pointer_saved = true
	_shots_dir = ProjectSettings.globalize_path("res://shots/carbon-copy-ui/" + Loc.lang)
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_summary["language"] = Loc.lang
	_summary["viewport"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	_summary["window"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	if not _check(_contrast(UiTheme.INK, UiTheme.CARD) >= 4.5, "paper body text contrast >= 4.5:1"):
		return
	if not _check(_contrast(UiTheme.DIM, UiTheme.CARD) >= 4.5, "secondary paper text contrast >= 4.5:1"):
		return
	_summary["contrast"] = {"body": _contrast(UiTheme.INK, UiTheme.CARD),
		"secondary": _contrast(UiTheme.DIM, UiTheme.CARD),
		"primary_button": _contrast(UiTheme.CARD, UiTheme.ACCENT)}
	if not (await _select_and_archives()):
		return
	if not (await _pause_and_settings()):
		return
	if not (await _results_feedback_and_boons()):
		return
	_main.audio.stop_all()
	_main.queue_free()
	await _wait(2)
	var file := FileAccess.open(_shots_dir.path_join("summary.json"), FileAccess.WRITE)
	if not _check(file != null, "summary output is writable"):
		return
	file.store_string(JSON.stringify(_summary, "\t"))
	file.close()
	print("carbon copy UI probe: OK, %s, %d states; injected keyboard + mouse + joypad events, no physical controller" % [
		Loc.lang, (_summary["screenshots"] as Dictionary).size()])
	_restore_pointer()
	quit()


func _select_and_archives() -> bool:
	var select: CharacterSelectUi = _main.character_select
	if not _check(select.visible and select._cards.size() == 4, "boot reaches real four-character selection"):
		return false
	if not (await _capture("select_locked", select)):
		return false
	for id: StringName in _main.meta.unlocked:
		_main.meta.unlocked[id] = true
	select.refresh(_main.meta, _main.today_seed(), 0)
	if not _check(select._selection_note.text.contains(Loc.character_name(&"solo")), "unlock reaction names a newly available character"):
		return false
	if not (await _capture("select_unlock_notice", select)):
		return false
	if not (await _navigate(select, 9)) or not (await _capture("select_unlocked", select)):
		return false
	select._cards[0].grab_focus()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	if not _check(select._cards[2].has_focus() and select._detail.text == Loc.character_desc(&"mirror"), "d-pad changes the actual stage identity and tradeoff"):
		return false
	if not (await _capture("select_alternate", select)):
		return false
	select._cards[0].grab_focus()
	await _move_pointer(select._cards[2].get_global_rect().get_center())
	_mouse_diagnostic("role_hover", select, &"mirror")
	if not _check(select._cards[0].has_focus() and select._detail.text == Loc.character_desc(&"mirror")
			and _main.sim == null, "real mouse motion previews without changing keyboard choice or starting"):
		return false
	if not (await _capture("select_mouse_hover", select)):
		return false
	await _move_pointer(Vector2(20.0, 20.0))
	if not _check(select._detail.text == Loc.character_desc(&"looper"), "pointer exit restores the keyboard preview"):
		return false
	select.seed_edit.grab_focus()
	await _move_pointer(select._cards[1].get_global_rect().get_center())
	_mouse_diagnostic("seed_hover", select, &"solo")
	if not _check(select.seed_edit.has_focus() and select._detail.text == Loc.character_desc(&"solo")
			and _main.sim == null, "hover during seed editing neither steals focus nor starts a run"):
		return false
	await _move_pointer(Vector2(20.0, 20.0))
	if not _check(select._detail.text == Loc.character_desc(&"looper"), "leaving hover while editing retains the recent role"):
		return false
	_summary["mouse_preview"] = {"event": "InputEventMouseMotion", "focus_preserved": true, "run_started": false}
	if not (await _activate(_button(select, "select.codex"))):
		return false
	var codex: CodexUi = _main.codex_ui
	if not (await _capture("catalog", codex)):
		return false
	for i in 4:
		await _joy(JOY_BUTTON_DPAD_DOWN)
	if not _check(codex.archive_scroll.scroll_vertical > 0, "d-pad reaches the lower catalog rows"):
		return false
	if not (await _capture("catalog_scrolled", codex)):
		return false
	await _joy(JOY_BUTTON_B)
	if not _check(not codex.visible and _card_focused(), "catalog Back restores selection focus"):
		return false
	if not (await _activate(_button(select, "select.settings"))):
		return false
	if not (await _navigate(_main.settings_ui, 6)) or not (await _capture("settings", _main.settings_ui)):
		return false
	if not (await _activate(_main.settings_ui.language_option)):
		return false
	var language_popup: PopupMenu = _main.settings_ui.language_option.get_popup()
	if not (await _capture_language_popup(language_popup)):
		return false
	language_popup.hide()
	_main.settings_ui.volume_slider.grab_focus()
	await _joy(JOY_BUTTON_B)
	if not _check(not _main.settings_ui.visible and _card_focused(), "settings Back restores selection focus"):
		return false
	if not (await _activate(_button(select, "select.history"))):
		return false
	if not (await _capture("history_empty", _main.history_ui)):
		return false
	await _joy(JOY_BUTTON_B)
	for i in 10:
		var sim := Sim.new(11000 + i)
		Content.character(&"looper").apply(sim)
		sim.wave = i + 1
		sim.kills = i * 7
		sim.phase = Sim.Phase.WON if i % 3 == 0 else Sim.Phase.LOST
		_main.run_log.append(sim, &"looper", 50.0 + float(i))
	if not (await _activate(_button(select, "select.history"))):
		return false
	if not (await _navigate(_main.history_ui, 9)) or not (await _capture("history_full", _main.history_ui)):
		return false
	await _joy(JOY_BUTTON_B)
	return _check(not _main.history_ui.visible and _card_focused(), "history Back restores selection focus")


func _pause_and_settings() -> bool:
	_main.character_select._cards[0].grab_focus()
	await _key(KEY_ENTER)
	if not _check(_main.sim != null, "keyboard starts the selected real character"):
		return false
	await _key(KEY_P)
	if not _check(_main.pause_ui.visible and _main.pause_ui.resume_button.has_focus(), "keyboard opens the pause menu"):
		return false
	if not (await _navigate(_main.pause_ui, 5)) or not (await _capture("pause", _main.pause_ui)):
		return false
	if not (await _activate(_main.pause_ui.settings_button)):
		return false
	if not _check(_main.settings_ui.language_option.disabled, "active run locks language reload"):
		return false
	if not (await _capture("settings_in_run", _main.settings_ui)):
		return false
	await _joy(JOY_BUTTON_B)
	if not _check(_main.pause_ui.resume_button.has_focus(), "nested settings returns to pause focus"):
		return false
	await _joy(JOY_BUTTON_B)
	return _check(not _main.pause_ui.visible, "joypad Back resumes gameplay")


func _results_feedback_and_boons() -> bool:
	_main.paused = true
	_main.shop_ui.close_session()
	_main.hud.visible = false
	var sim: Sim = _main.sim
	sim.phase = Sim.Phase.LOST
	sim.wave = 12
	sim.kills = 246
	sim.last_damage_source = &"bomber"
	sim.bank.takes.clear()
	_main.end_ui.set_reduced_effects(false)
	_main.end_ui.set_feedback_available(true)
	_main.end_ui.show_result(sim)
	if not (await _navigate(_main.end_ui, 5)) or not (await _capture("result_loss", _main.end_ui)):
		return false
	var take := EchoTake.new()
	take.wave = 11
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	for i in 80:
		var phase := float(i) * 0.09
		take.samples.append(Sim.ARENA.get_center() + Vector2(cos(phase) * 130.0, sin(phase * 1.7) * 75.0))
	sim.bank.add(take)
	sim.phase = Sim.Phase.WON
	sim.wave = WaveDirector.FINAL_WAVE
	_main.end_ui.set_reduced_effects(true)
	_main.end_ui.show_result(sim, Loc.t("end.unlocked", [Loc.character_name(&"conductor")]))
	_summary["result_reduced_effects"] = _main.end_ui.reduced_effects
	if not (await _navigate(_main.end_ui, 7)) or not (await _capture("result_win", _main.end_ui)):
		return false
	_main.feedback_ui.open_for_run("fixture-paper-ui", true, false)
	if not (await _navigate(_main.feedback_ui, 5)) or not (await _capture("feedback", _main.feedback_ui)):
		return false
	await _joy(JOY_BUTTON_B)
	if not _check(not _main.feedback_ui.visible and _main.end_ui.restart_button.has_focus(),
			"feedback Back restores result focus"):
		return false
	_main.feedback_ui.open_for_run("fixture-paper-ui", false, true)
	if not (await _capture("feedback_read_only", _main.feedback_ui)):
		return false
	await _joy(JOY_BUTTON_B)
	_main.end_ui.visible = false
	sim.player.materials = 100
	var grants: Array[StringName] = [Boon.DAMAGE, Boon.HASTE, Boon.FORTUNE]
	_main.boon_ui.open(grants, sim)
	if not (await _navigate(_main.boon_ui, 4)) or not (await _capture("salvage_choices", _main.boon_ui)):
		return false
	_main.boon_ui.close()
	var empty: Array[StringName] = []
	_main.boon_ui.open(empty, sim)
	return _check(not _main.boon_ui.visible, "empty salvage input never traps the player")


func _button(surface: Control, key: String) -> Button:
	for raw in surface.find_children("*", "Button", true, false):
		var button := raw as Button
		if button.text == Loc.t(key):
			return button
	return null


func _activate(button: Button) -> bool:
	if not _check(button != null and not button.disabled, "real UI action exists and is enabled"):
		return false
	button.grab_focus()
	await _joy(JOY_BUTTON_A)
	return true


func _navigate(surface: Control, count: int) -> bool:
	for i in count:
		await _key(KEY_TAB)
		var focus := root.gui_get_focus_owner()
		if not _check(focus != null and surface.is_ancestor_of(focus), "keyboard focus remains within modal"):
			return false
	await _joy(JOY_BUTTON_DPAD_DOWN)
	var joy_focus := root.gui_get_focus_owner()
	if not _check(joy_focus != null and surface.is_ancestor_of(joy_focus), "joypad focus remains within modal"):
		return false
	(_summary["navigation"] as Array).append({"surface": surface.get_class(), "tabs": count,
		"keyboard_event": "InputEventKey", "joypad_event": "InputEventJoypadButton"})
	return true


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(2)


func _joy(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(2)


func _card_focused() -> bool:
	for card in _main.character_select._cards:
		if card.has_focus():
			return true
	return false


func _capture(state: String, surface: Control) -> bool:
	await _wait(20)
	if not _geometry(surface, state):
		return false
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if not _check(image != null and not image.is_empty(), state + " has actual rendered pixels"):
		return false
	var path := _shots_dir.path_join(state + ".png")
	if not _check(image.save_png(path) == OK, state + " screenshot saves"):
		return false
	if not _record_visual_checks(state, surface, image):
		return false
	_summary["screenshots"][state] = path
	print("carbon copy UI state: " + Loc.lang + " / " + state)
	return true


func _geometry(surface: Control, state: String) -> bool:
	if not _check(surface.visible, state + " is visible"):
		return false
	var viewport := root.get_visible_rect().grow(0.5)
	var focus := root.gui_get_focus_owner()
	if not _check(focus != null and surface.is_ancestor_of(focus), state + " owns focus"):
		return false
	for raw in surface.find_children("*", "Control", true, false):
		var control := raw as Control
		if not control.is_visible_in_tree():
			continue
		var bounds := control.get_global_rect()
		var parent := control.get_parent()
		while parent != null:
			if parent is Control and (parent.clip_contents or parent is ScrollContainer):
				bounds = bounds.intersection(parent.get_global_rect())
			parent = parent.get_parent()
		if bounds.has_area() and not _check(viewport.encloses(bounds),
				"%s: %s overflows viewport: %s" % [state, control.get_class(), bounds]):
			return false
	return true


func _linear(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition


func _fail(message: String) -> void:
	_restore_pointer()
	_failed = true
	printerr("carbon copy UI probe: FAILED: " + message)
	quit(1)


func _record_visual_checks(state: String, surface: Control, image: Image) -> bool:
	# Pixel distribution guards against blank renders; shape profiles record the visual
	# composition separately from interaction rectangles for the reviewer to inspect.
	var samples := 0
	var dark := 0
	var paper := 0
	for y in range(0, image.get_height(), 6):
		for x in range(0, image.get_width(), 6):
			var pixel := image.get_pixel(x, y)
			samples += 1
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.30:
				dark += 1
			if Vector3(pixel.r - UiTheme.PAPER.r, pixel.g - UiTheme.PAPER.g,
					pixel.b - UiTheme.PAPER.b).length() < 0.12:
				paper += 1
	var profile: Dictionary = {"dark_ink_fraction": float(dark) / maxf(1.0, samples),
		"paper_fraction": float(paper) / maxf(1.0, samples)}
	if surface == _main.character_select:
		var cast: CharacterSelectUi = _main.character_select
		var rises: Array[float] = []
		var physical_portraits: Array = []
		for card in cast._cards:
			var blank := card.get_theme_stylebox("normal") as InkStyleBox
			if not _check(blank != null and not blank.draw_center and blank.border_color.a == 0.0,
					"cast is drawn without four filled card frames"):
				return false
			var portrait := card.get("portrait") as TextureRect
			physical_portraits.append([portrait.size.x * image.get_width() / root.get_visible_rect().size.x,
				portrait.size.y * image.get_height() / root.get_visible_rect().size.y])
			var rise := float(card.get("rise"))
			if not rises.has(rise):
				rises.append(rise)
		if not _check(rises.size() >= 3 and dark > samples * 0.003 and paper > samples * 0.25,
				"stage contains distinct baselines, actual ink and open paper space"):
			return false
		profile["cast_baselines"] = rises
		profile["portrait_pixels"] = physical_portraits
		profile["filled_character_cards"] = 0
		var previewed := 0
		for card in cast._cards:
			if bool(card.get("previewed")):
				previewed += 1
		if not _check(previewed == 1, "exactly one current role remains visible while browsing controls"):
			return false
		profile["current_role_count"] = previewed
	if surface == _main.boon_ui:
		for choice in _main.boon_ui.choice_buttons:
			var shell := choice.get_theme_stylebox("normal") as InkStyleBox
			if not _check(not shell.draw_center and shell.border_color.a == 0.0, "salvage uses floating objects instead of framed cards"):
				return false
		profile["filled_choice_cards"] = 0
	_summary["visual_checks"][state] = profile
	return true


func _move_pointer(position: Vector2) -> void:
	_mouse_target = position
	# GUI hover is refreshed from the OS pointer between frames. Keep the native
	# pointer at the tested position instead of fighting that refresh with a fake one.
	root.warp_mouse(position)
	await _wait(2)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	# Forwarding a pointer uses the viewport lifecycle as well as viewport-local coordinates.
	root.notify_mouse_entered()
	root.push_input(motion, true)
	await _wait(3)


func _restore_pointer() -> void:
	if _pointer_saved and is_instance_valid(root):
		root.warp_mouse(_original_pointer)
		_pointer_saved = false


func _finalize() -> void:
	_restore_pointer()


func _capture_language_popup(popup: PopupMenu) -> bool:
	await _wait(6)
	if not _check(popup.visible, "language option opens its real popup"):
		return false
	# This is the popup's viewport, including when it is an independent OS window.
	# Do not change the production subwindow/embedding policy to obtain a screenshot.
	RenderingServer.force_draw()
	var image := popup.get_texture().get_image()
	if not _check(image != null and not image.is_empty(), "language popup has rendered pixels"):
		return false
	var path := _shots_dir.path_join("language_popup.png")
	if not _check(image.save_png(path) == OK, "language popup screenshot saves"):
		return false
	_summary["screenshots"]["language_popup"] = path
	_summary["language_popup"] = {"capture": "PopupMenu viewport", "items": popup.item_count,
		"width": image.get_width(), "height": image.get_height()}
	print("carbon copy UI state: " + Loc.lang + " / language_popup")
	return true


func _mouse_diagnostic(state: String, select: CharacterSelectUi, expected: StringName) -> void:
	var focus := root.gui_get_focus_owner()
	var hovered := root.gui_get_hovered_control()
	var expected_index := 2 if expected == &"mirror" else 1
	var target: Control = select._cards[expected_index]
	var mouse := root.get_mouse_position()
	var data := {"state": state, "focus_path": str(focus.get_path()) if focus != null else "null",
		"focus_ok": select._cards[0].has_focus() if state == "role_hover" else select.seed_edit.has_focus(),
		"detail_actual": select._detail.text, "detail_expected": Loc.character_desc(expected),
		"detail_ok": select._detail.text == Loc.character_desc(expected), "sim_ok": _main.sim == null,
		"hover_path": str(hovered.get_path()) if hovered != null else "null",
		"mouse": [mouse.x, mouse.y], "injected": [_mouse_target.x, _mouse_target.y],
		"target_rect": str(target.get_global_rect()),
		"canvas_point": str(target.get_global_transform_with_canvas() * (target.size * 0.5)),
		"screen_point": str(target.get_screen_transform() * (target.size * 0.5)),
		"stretch": str(root.get_stretch_transform()), "final_transform": str(root.get_final_transform()),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"viewport": str(root.get_visible_rect()), "window_has_focus": root.has_focus()}
	if not _summary.has("mouse_diagnostics"):
		_summary["mouse_diagnostics"] = []
	(_summary["mouse_diagnostics"] as Array).append(data)
	print("carbon copy mouse diagnostics: " + JSON.stringify(data))
