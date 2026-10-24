extends SceneTree
# Actual-window, isolated post-run feedback validation. Run once per language:
# REVERB_LANG=en|zh godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/playtest_feedback_probe.gd

const RUN_PATH := "user://playtest_feedback_probe_runs.jsonl"
const FEEDBACK_PATH := "user://playtest_feedback_probe_feedback.jsonl"
const NOTE := "回响路线清楚，商店节奏 mixed — fixture ✓"
const DEADLINE_FRAMES := 900

var _main: Node
var _frames := 0
var _failed := false


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://playtest_feedback_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", RUN_PATH)
	OS.set_environment("REVERB_FEEDBACK_LOG", FEEDBACK_PATH)
	OS.set_environment("REVERB_SETTINGS", "user://playtest_feedback_probe_settings.json")
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	_clear_fixture_files()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded")
	return false


func _run() -> void:
	await _wait_frames(3)
	_main.new_run(4242, &"looper")
	var sim: Sim = _main.sim
	sim.phase = Sim.Phase.LOST
	sim.wave = 5
	sim.kills = 23
	sim.last_damage_source = &"warden"
	# Let Main observe the real phase transition so it records and presents exactly once.
	await _wait_frames(3)
	if not _require(_main.end_ui.visible and not _main.end_ui.feedback_button.disabled,
			"successfully recorded end state exposes feedback action"):
		return
	if not (await _activate(_main.end_ui.feedback_button, "end_to_feedback")):
		return
	var form: FeedbackUi = _main.feedback_ui
	if not _require(form.visible and form.category_option.has_focus(),
			"feedback action opens the focused form"):
		return
	if not _require(_viewport_encloses(form), "localized feedback form fits the 720p viewport"):
		return
	if not (await _assert_tab_cycle(form, 5)):
		return
	if not (await _assert_physical_note_tab(form)):
		return
	var shot_path: String = await _capture_form()
	if shot_path == "":
		return
	form.category_option.select(2)
	form.rating_option.select(1)
	form.note_edit.text = NOTE
	form.note_edit.text_changed.emit()
	if not (await _activate(form.save_button, "save_feedback")):
		return
	if not _require(form.save_button.disabled and form.open_log_button.visible
			and form.category_option.disabled and form.rating_option.disabled
			and not form.note_edit.editable and form.open_log_button.has_focus(),
			"successful save freezes the snapshot and focuses an available action"):
		return
	var rows := _feedback_rows()
	if not _require(rows.size() == 1, "feedback ledger contains exactly one row"):
		return
	var record: Dictionary = rows[0]
	if not _require(record.get("note") == NOTE and record.get("category") == "combat"
			and record.get("rating") == "mixed" and record.get("source") == "fixture"
			and record.get("run_id") == _main._latest_saved_run.get("run_id"),
			"JSON row preserves Unicode text, selections and fixture provenance"):
		return
	form.close()
	if not _require(_main.end_ui.restart_button.has_focus(), "closing restores End focus"):
		return
	if not (await _activate(_main.end_ui.feedback_button, "reopen_duplicate")):
		return
	if not _require(form.visible and form.save_button.disabled and form.status_label.visible
			and form.category_option.disabled and form.rating_option.disabled
			and not form.note_edit.editable and form.open_log_button.has_focus()
			and form.note_edit.text == NOTE
			and form.category_option.get_item_metadata(form.category_option.selected) == &"combat"
			and form.rating_option.get_item_metadata(form.rating_option.selected) == &"mixed",
			"reopened form shows the same read-only snapshot and guards the duplicate run"):
		return
	if not (await _assert_readonly_tab_cycle(form)):
		return
	if not (await _cancel()):
		return
	if not _require(_feedback_rows().size() == 1 and _main.end_ui.restart_button.has_focus(),
			"cancel appends nothing and restores End focus"):
		return
	_main.new_run(4243, &"looper")
	if not _require(not form.visible and form.note_edit.text.is_empty()
			and _main._latest_saved_run.is_empty() and _main._run_context.get("source") == "fixture"
			and _main.end_ui.feedback_button.disabled and not form.category_option.disabled
			and not form.rating_option.disabled and form.note_edit.editable,
			"new run resets modal and saved-run state while creating fixture context"):
		return
	_main.audio.stop_all()
	print("playtest feedback probe: %s" % JSON.stringify({"language": Loc.lang,
			"rows": rows.size(), "source": record.get("source"), "screenshot": shot_path}))
	print("playtest feedback probe: OK")
	quit()


func _activate(control: Control, stage: String) -> bool:
	if not _require(control != null and control.is_visible_in_tree()
			and control.focus_mode != Control.FOCUS_NONE
			and (not (control is BaseButton) or not (control as BaseButton).disabled),
			"%s target is actionable: %s" % [stage, _focus_diagnostic(control)]):
		return false
	control.grab_focus()
	await _wait_frames(2)
	if not _require(control.has_focus(), "%s target receives focus: %s" % [
			stage, _focus_diagnostic(control)]):
		return false
	return await _action(&"ui_accept")


func _focus_diagnostic(control: Control) -> String:
	var owner: Control = root.gui_get_focus_owner()
	var target_path := "<null>" if control == null else str(control.get_path())
	var target_type := "<null>" if control == null else control.get_class()
	var visible := false if control == null else control.is_visible_in_tree()
	var focus_mode := -1 if control == null else control.focus_mode
	var disabled := false
	if control is BaseButton:
		disabled = (control as BaseButton).disabled
	var owner_path := "<none>" if owner == null else str(owner.get_path())
	var owner_type := "<none>" if owner == null else owner.get_class()
	return "target=%s type=%s visible=%s focus_mode=%s disabled=%s owner=%s type=%s" % [
			target_path, target_type, visible, focus_mode, disabled, owner_path, owner_type]


func _assert_tab_cycle(surface: Control, expected_count: int) -> bool:
	var seen: Dictionary = {}
	_main.feedback_ui.category_option.grab_focus()
	await _wait_frames(2)
	for _i in expected_count:
		var owner: Control = root.gui_get_focus_owner()
		if not _require(owner != null and surface.is_ancestor_of(owner),
				"Tab focus stays inside feedback form"):
			return false
		seen[owner.get_instance_id()] = true
		if not (await _action(&"ui_focus_next")):
			return false
	return _require(seen.size() == expected_count
			and root.gui_get_focus_owner() == _main.feedback_ui.category_option,
			"Tab reaches all five feedback controls and wraps")


func _assert_physical_note_tab(form: FeedbackUi) -> bool:
	var preserved := "Tab keeps 中文 note text"
	form.note_edit.text = preserved
	form.note_edit.grab_focus()
	await _wait_frames(2)
	if not (await _physical_tab(false)):
		return false
	if not _require(form.save_button.has_focus() and form.note_edit.text == preserved,
			"physical Tab moves note focus to Save without changing text"):
		return false
	if not (await _physical_tab(true)):
		return false
	return _require(form.note_edit.has_focus() and form.note_edit.text == preserved,
			"physical Shift+Tab returns to note without changing text")


func _assert_readonly_tab_cycle(form: FeedbackUi) -> bool:
	if not (await _physical_tab(false)):
		return false
	if not _require(form.cancel_button.has_focus(),
			"read-only feedback Tab reaches Close without entering frozen fields"):
		return false
	if not (await _physical_tab(true)):
		return false
	return _require(form.open_log_button.has_focus() and form.note_edit.text == NOTE,
			"read-only feedback Shift+Tab returns to folder without changing the snapshot")


func _cancel() -> bool:
	return await _action(&"ui_cancel")


func _physical_tab(shifted: bool) -> bool:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.shift_pressed = shifted
	event.pressed = true
	root.push_input(event, false)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_TAB
	event.shift_pressed = shifted
	event.pressed = false
	root.push_input(event, false)
	await _wait_frames(4)
	return not _failed


func _action(action: StringName) -> bool:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event, false)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event, false)
	await _wait_frames(4)
	return not _failed


func _viewport_encloses(surface: Control) -> bool:
	var viewport := root.get_visible_rect()
	for node: Node in surface.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and control.get_global_rect().has_area() \
				and not viewport.encloses(control.get_global_rect()):
			return false
	return true


func _capture_form() -> String:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not _require(image != null and not image.is_empty(), "post-draw framebuffer readback succeeds"):
		return ""
	var shots_dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var shot_path := shots_dir.path_join("playtest_feedback_%s.png" % Loc.lang)
	if not _require(image.save_png(shot_path) == OK, "localized post-draw screenshot saves"):
		return ""
	return shot_path


func _feedback_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var absolute := ProjectSettings.globalize_path(FEEDBACK_PATH)
	if not FileAccess.file_exists(absolute):
		return rows
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			rows.append(parsed)
	return rows


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("playtest feedback probe FAILED: %s" % message)
	if _main != null and _main.audio != null:
		_main.audio.stop_all()
	quit(1)


func _clear_fixture_files() -> void:
	for path in ["user://playtest_feedback_probe_save.json", RUN_PATH, FEEDBACK_PATH,
			"user://playtest_feedback_probe_settings.json"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
