class_name EndUi
extends Control

signal archive_requested(take: EchoTake)
signal restart_requested
signal character_requested
signal seed_retry_requested(seed_value: int)
signal open_log_requested
signal endless_requested
signal boss_rush_requested
signal feedback_requested

var archive_button: Button
var _archive_note: Label
var restart_button: Button
var character_button: Button
var endless_button: Button
var boss_rush_button: Button
var retry_button: Button
var open_log_button: Button
var feedback_button: Button
var candidate_take: EchoTake
var candidate_index := -1
var replacement_pending := false
var previous_button: Button
var next_button: Button
var confirm_button: Button
var cancel_button: Button
var _candidates: Array[EchoTake] = []
var _sim: Sim
var _entry_sim: Sim
var _meta: Meta
var _candidate_ui: ArchiveCandidateUi
var _candidate_count: Label
var _confirmation: Control
var _confirmation_panel: PanelContainer
var _confirmation_rows: Array[ArchiveCandidateUi] = []
var _confirmation_title: Label
var reduced_effects := false
var feedback_available := false

var _title: Label
var _afterword: Label
var _stats: Label
var _seed: Label
var _unlock: Label
var _candidate_row: VBoxContainer
var _no_echo: Label
var _seed_value: int = 0
var _panel: PanelContainer
var _margin: MarginContainer
var _box: VBoxContainer
var _report: Label
var _echo_row: HBoxContainer
var _archive_box: VBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.84)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var panel := _panel
	panel.custom_minimum_size = Vector2(930.0, 0.0)
	var sheet := UiTheme.surface_panel().duplicate() as InkStyleBox
	sheet.shape = InkStyleBox.Shape.PAPER
	sheet.softness = 74.0
	sheet.variant = 16
	panel.add_theme_stylebox_override("panel", sheet)
	center.add_child(panel)
	_margin = MarginContainer.new()
	var margin := _margin
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	var box := _box
	box.add_theme_constant_override("separation", 11)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	_report = UiTheme.label(Loc.t("end.report"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_report)
	_title = UiTheme.label("", 52, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_afterword = UiTheme.label("", 17, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_afterword.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_afterword)
	_stats = UiTheme.label("", 17, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(790.0, 0.0)
	box.add_child(_stats)
	_candidate_row = VBoxContainer.new()
	_candidate_row.add_theme_constant_override("separation", 4)
	var paging := HBoxContainer.new()
	paging.alignment = BoxContainer.ALIGNMENT_CENTER
	previous_button = _small_action()
	previous_button.custom_minimum_size.x = 100.0
	previous_button.text = Loc.t("archive.previous")
	previous_button.pressed.connect(func() -> void: select_candidate(posmod(candidate_index - 1, _candidates.size())))
	paging.add_child(previous_button)
	_candidate_count = UiTheme.label("", 14, UiTheme.ECHO, HORIZONTAL_ALIGNMENT_CENTER)
	_candidate_count.custom_minimum_size.x = 160.0
	paging.add_child(_candidate_count)
	next_button = _small_action()
	next_button.custom_minimum_size.x = 100.0
	next_button.text = Loc.t("archive.next")
	next_button.pressed.connect(func() -> void: select_candidate(posmod(candidate_index + 1, _candidates.size())))
	paging.add_child(next_button)
	_candidate_row.add_child(paging)
	_candidate_ui = ArchiveCandidateUi.new()
	_candidate_row.add_child(_candidate_ui)
	_echo_row = HBoxContainer.new()
	_echo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_echo_row.add_theme_constant_override("separation", 20)
	_echo_row.add_child(_candidate_row)
	_candidate_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_echo_row)
	_archive_box = VBoxContainer.new()
	_archive_box.custom_minimum_size.x = 220.0
	_archive_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_archive_box.add_theme_constant_override("separation", 4)
	_echo_row.add_child(_archive_box)
	archive_button = Button.new()
	archive_button.text = Loc.t("archive.save_selected")
	archive_button.custom_minimum_size = Vector2(200.0, 32.0)
	archive_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	archive_button.pressed.connect(request_archive)
	_archive_box.add_child(archive_button)
	_archive_note = UiTheme.label("", 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_archive_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_archive_box.add_child(_archive_note)
	_no_echo = UiTheme.label(Loc.t("end.no_echo"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_echo_row.add_child(_no_echo)
	_echo_row.move_child(_no_echo, 0)
	_unlock = UiTheme.label("", 18, UiTheme.COIN, HORIZONTAL_ALIGNMENT_CENTER)
	_unlock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_unlock)
	var decisions := HBoxContainer.new()
	decisions.add_theme_constant_override("separation", 20)
	decisions.alignment = BoxContainer.ALIGNMENT_CENTER
	restart_button = Button.new()
	restart_button.custom_minimum_size = Vector2(296.0, 54.0)
	restart_button.pressed.connect(_on_restart)
	UiTheme.stamp_button(restart_button)
	decisions.add_child(restart_button)
	character_button = Button.new()
	character_button.custom_minimum_size = Vector2(204.0, 42.0)
	character_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	character_button.flat = true
	character_button.pressed.connect(_on_character)
	decisions.add_child(character_button)
	box.add_child(decisions)
	var continuations := HBoxContainer.new()
	continuations.alignment = BoxContainer.ALIGNMENT_CENTER
	continuations.add_theme_constant_override("separation", 18)
	endless_button = Button.new()
	endless_button.custom_minimum_size = Vector2(230.0, 34.0)
	endless_button.flat = true
	endless_button.pressed.connect(func() -> void: endless_requested.emit())
	continuations.add_child(endless_button)
	boss_rush_button = Button.new()
	boss_rush_button.custom_minimum_size = Vector2(170.0, 34.0)
	boss_rush_button.flat = true
	boss_rush_button.pressed.connect(func() -> void: boss_rush_requested.emit())
	continuations.add_child(boss_rush_button)
	box.add_child(continuations)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_seed = UiTheme.label("", 12, UiTheme.DIM)
	tools.add_child(_seed)
	retry_button = _small_action()
	retry_button.pressed.connect(_on_retry_seed)
	tools.add_child(retry_button)
	open_log_button = _small_action()
	open_log_button.pressed.connect(func() -> void: open_log_requested.emit())
	tools.add_child(open_log_button)
	feedback_button = _small_action()
	feedback_button.disabled = true
	feedback_button.pressed.connect(func() -> void: feedback_requested.emit())
	tools.add_child(feedback_button)
	box.add_child(tools)
	_build_confirmation()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _small_action() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(156.0, 30.0)
	button.add_theme_font_size_override("font_size", 14)
	button.flat = true
	return button


func show_result(sim: Sim, unlocked_text: String = "", profile: Meta = null) -> void:
	_sim = sim
	_meta = profile
	_entry_sim = Sim.new(1)
	Content.character(sim.character_id).apply(_entry_sim)
	replacement_pending = false
	_confirmation.visible = false
	_candidates.clear()
	for take: EchoTake in sim.bank.takes:
		_candidates.append(take)
	candidate_take = null
	candidate_index = -1
	_apply_layout()
	var won := sim.phase == Sim.Phase.WON
	_afterword.text = Loc.t("end.win_note") if won else Loc.t("end.loss_note")
	if sim.endless:
		_title.text = Loc.t("end.endless_lose", [sim.wave])
		_stats.text = Loc.t("end.endless_run", [sim.wave, sim.kills])
	else:
		_title.text = Loc.t("end.win", [WaveDirector.FINAL_WAVE]) if won else Loc.t("end.lose", [sim.wave])
		_stats.text = Loc.t("end.run", [sim.wave, WaveDirector.FINAL_WAVE, sim.kills])
	_title.add_theme_color_override("font_color", UiTheme.COIN if won else UiTheme.WARN)
	if not won and sim.last_damage_source != &"":
		var cause := Loc.t("enemy.rift") if sim.last_damage_source == &"rift" else Loc.enemy_name(sim.last_damage_source)
		_stats.text += "  ·  " + Loc.t("end.death_cause", [cause])
	_seed_value = sim.run_seed
	_seed.text = Loc.t("end.seed", [sim.run_seed])
	_unlock.text = unlocked_text
	_unlock.visible = unlocked_text != ""
	_archive_note.text = Loc.t("archive.choice_note")
	if sim.daily_modifier != &"" or not EchoArchive.eligible(sim.character_id):
		_archive_note.text = Loc.t("archive.unavailable")
	if int(sim.expedition.get("debt", 0)) > 0:
		_archive_note.text = Loc.t("archive.debt")
	var report := Expedition.status(sim)
	_afterword.text = Loc.t(report.ending) if won else Loc.t("end.loss_note")
	if won and not str(report.get("outcome_key", "")).is_empty():
		_afterword.text += "\n" + Loc.t(report.outcome_key)
	_candidate_row.visible = not _candidates.is_empty()
	_no_echo.visible = _candidates.is_empty()
	previous_button.disabled = _candidates.size() < 2
	next_button.disabled = _candidates.size() < 2
	select_candidate(0)
	restart_button.text = Loc.t("end.restart")
	character_button.text = Loc.t("end.change")
	endless_button.text = Loc.t("end.endless_continue")
	endless_button.visible = won and not sim.endless
	boss_rush_button.text = Loc.t("end.boss_rush")
	boss_rush_button.visible = won and not sim.endless
	retry_button.text = Loc.t("end.retry_seed")
	open_log_button.text = Loc.t("end.open_log")
	feedback_button.text = Loc.t("end.feedback")
	visible = true
	_rebuild_focus_cycle()
	focus_default()
	UiTheme.animate_open(self, reduced_effects)


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	if on:
		UiTheme.animate_open(self, true)



func set_feedback_available(available: bool) -> void:
	feedback_available = available
	if feedback_button == null:
		return
	feedback_button.disabled = not available
	feedback_button.tooltip_text = "" if available else Loc.t("feedback.unavailable")
	feedback_button.accessibility_description = feedback_button.tooltip_text
	if visible:
		_rebuild_focus_cycle()


func focus_default() -> void:
	if replacement_pending:
		cancel_button.grab_focus()
		return
	if restart_button != null:
		restart_button.grab_focus()


func _rebuild_focus_cycle() -> void:
	if replacement_pending:
		UiFocus.cycle([_confirmation_rows[0].detail_button, _confirmation_rows[1].detail_button, cancel_button, confirm_button])
		return
	UiFocus.cycle([previous_button, next_button, _candidate_ui.detail_button, archive_button, retry_button, open_log_button, feedback_button, endless_button,
			boss_rush_button, restart_button, character_button])


func _on_retry_seed() -> void:
	seed_retry_requested.emit(_seed_value)


func _on_restart() -> void:
	restart_requested.emit()


func _on_character() -> void:
	character_requested.emit()


func set_archive_result(ok: bool, error: String = "") -> void:
	_archive_note.text = Loc.t("archive.saved") if ok else Loc.t(error if error != "" else "archive.save_failed")
	archive_button.disabled = ok
	_rebuild_focus_cycle()
	if ok:
		restart_button.grab_focus()


func _canvas_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(1280.0, 720.0)
	var extent := get_viewport_rect().size
	return extent if extent.x > 0.0 and extent.y > 0.0 else Vector2(1280.0, 720.0)


func _compact() -> bool:
	var extent := _canvas_size()
	return extent.x < 1100.0 or extent.y < 640.0


func _apply_layout() -> void:
	if _panel == null:
		return
	var compact := _compact()
	_panel.custom_minimum_size.x = minf(930.0, maxf(0.0, _canvas_size().x - 24.0))
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 8 if compact else 30)
	_box.add_theme_constant_override("separation", 4 if compact else 11)
	_title.add_theme_font_size_override("font_size", 34 if compact else 52)
	_report.add_theme_font_size_override("font_size", 14 if compact else 16)
	_afterword.add_theme_font_size_override("font_size", 16 if compact else 17)
	_stats.add_theme_font_size_override("font_size", 14 if compact else 17)
	_stats.custom_minimum_size.x = 0.0
	_unlock.add_theme_font_size_override("font_size", 14 if compact else 18)
	var actions: Array[Button] = [archive_button, character_button, endless_button, boss_rush_button, retry_button, open_log_button, feedback_button]
	var widths: Array[float] = [200.0, 204.0, 230.0, 170.0, 156.0, 156.0, 156.0]
	for index in actions.size():
		var button := actions[index]
		WorkshopUi.fit_button(button, 14 if compact else 16, 30.0 if compact else 34.0)
		button.custom_minimum_size.x = minf(widths[index], 230.0) if compact else widths[index]
	UiTheme.stamp_button(restart_button)
	restart_button.custom_minimum_size = Vector2(240.0 if compact else 296.0, 40.0 if compact else 54.0)
	restart_button.add_theme_font_size_override("font_size", 17 if compact else 18)
	if compact:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := restart_button.get_theme_stylebox(state).duplicate() as StyleBox
			style.content_margin_top = 2.0
			style.content_margin_bottom = 2.0
			restart_button.add_theme_stylebox_override(state, style)
	if candidate_take != null and _entry_sim != null:
		_candidate_ui.setup(candidate_take, EchoArchive.preview(candidate_take, _entry_sim), compact)
	if _confirmation_panel != null:
		_confirmation_panel.custom_minimum_size.x = minf(880.0, maxf(0.0, _canvas_size().x - 48.0))
		_confirmation_title.add_theme_font_size_override("font_size", 20 if compact else 26)
		if replacement_pending:
			_refresh_confirmation()


func candidate_count() -> int:
	return _candidates.size()


func select_candidate(index: int) -> bool:
	if replacement_pending or index < 0 or index >= _candidates.size():
		archive_button.disabled = candidate_take == null or not _can_archive()
		return false
	candidate_index = index
	candidate_take = _candidates[index]
	_candidate_count.text = Loc.t("archive.candidate", [index + 1, _candidates.size()])
	_candidate_ui.setup(candidate_take, EchoArchive.preview(candidate_take, _entry_sim), _compact())
	previous_button.disabled = _candidates.size() < 2
	next_button.disabled = _candidates.size() < 2
	archive_button.disabled = not _can_archive()
	_rebuild_focus_cycle()
	return true


func _can_archive() -> bool:
	return _sim != null and candidate_take != null and _sim.bank.takes.has(candidate_take) \
		and EchoArchive.eligible(_sim.character_id) and _sim.daily_modifier == &"" \
		and int(_sim.expedition.get("debt", 0)) <= 0 and not EchoArchive.encode(candidate_take).is_empty()


func request_archive() -> void:
	if not _can_archive():
		return
	if _meta != null and EchoArchive.has(_meta, _sim.character_id):
		replacement_pending = true
		_refresh_confirmation()
		_confirmation.visible = true
		UiFocus.cycle([_confirmation_rows[0].detail_button, _confirmation_rows[1].detail_button, cancel_button, confirm_button])
		cancel_button.grab_focus()
		return
	archive_requested.emit(candidate_take)


func confirm_archive() -> void:
	if not replacement_pending or not _can_archive():
		cancel_archive()
		return
	replacement_pending = false
	_confirmation.visible = false
	_rebuild_focus_cycle()
	archive_requested.emit(candidate_take)


func cancel_archive() -> void:
	replacement_pending = false
	_confirmation.visible = false
	_rebuild_focus_cycle()
	archive_button.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and replacement_pending and event.is_action_pressed(&"ui_cancel"):
		cancel_archive()
		get_viewport().set_input_as_handled()


func _build_confirmation() -> void:
	_confirmation = Control.new()
	add_child(_confirmation)
	_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(UiTheme.EDGE, 0.95)
	_confirmation.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_confirmation.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation_panel = PanelContainer.new()
	_confirmation_panel.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	center.add_child(_confirmation_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_confirmation_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	_confirmation_title = UiTheme.label(Loc.t("archive.replace_title"), 26, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_confirmation_title)
	for key in ["archive.current_entry", "archive.chosen_entry"]:
		box.add_child(UiTheme.label(Loc.t(key), 14, UiTheme.ECHO))
		var row := ArchiveCandidateUi.new()
		box.add_child(row)
		_confirmation_rows.append(row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	cancel_button = Button.new()
	cancel_button.text = Loc.t("archive.keep_current")
	cancel_button.custom_minimum_size = Vector2(200.0, 36.0)
	cancel_button.pressed.connect(cancel_archive)
	buttons.add_child(cancel_button)
	confirm_button = Button.new()
	confirm_button.text = Loc.t("archive.replace_confirm")
	confirm_button.custom_minimum_size = Vector2(200.0, 36.0)
	confirm_button.pressed.connect(confirm_archive)
	buttons.add_child(confirm_button)
	_confirmation.visible = false


func _refresh_confirmation() -> void:
	var existing := EchoArchive.peek(_meta, _sim.character_id)
	if existing == null:
		cancel_archive()
		return
	_confirmation_rows[0].setup(existing, EchoArchive.entry_preview(_meta, _sim.character_id, _entry_sim), _compact())
	_confirmation_rows[1].setup(candidate_take, EchoArchive.preview(candidate_take, _entry_sim), _compact())
