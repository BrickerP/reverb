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
var best_take: EchoTake
var reduced_effects := false
var feedback_available := false

var _title: Label
var _afterword: Label
var _stats: Label
var _seed: Label
var _unlock: Label
var _best_row: HBoxContainer
var _best_preview: PathPreview
var _best_label: Label
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
	_best_row = HBoxContainer.new()
	_best_row.add_theme_constant_override("separation", 16)
	_best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_best_preview = PathPreview.new()
	_best_row.add_child(_best_preview)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(UiTheme.label(Loc.t("end.best_echo"), 15, UiTheme.ECHO))
	_best_label = UiTheme.label("", 18)
	info.add_child(_best_label)
	_best_row.add_child(info)
	_echo_row = HBoxContainer.new()
	_echo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_echo_row.add_theme_constant_override("separation", 20)
	_echo_row.add_child(_best_row)
	box.add_child(_echo_row)
	_archive_box = VBoxContainer.new()
	_archive_box.custom_minimum_size.x = 350.0
	_archive_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_archive_box.add_theme_constant_override("separation", 4)
	_echo_row.add_child(_archive_box)
	archive_button = Button.new()
	archive_button.text = Loc.t("archive.save_best")
	archive_button.custom_minimum_size = Vector2(280.0, 32.0)
	archive_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	archive_button.pressed.connect(func() -> void: archive_requested.emit(best_take))
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
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _small_action() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(156.0, 30.0)
	button.add_theme_font_size_override("font_size", 14)
	button.flat = true
	return button


func show_result(sim: Sim, unlocked_text: String = "") -> void:
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
	best_take = null
	for take: EchoTake in sim.bank.takes:
		if best_take == null or sim.echo_dps(take) > sim.echo_dps(best_take):
			best_take = take
	archive_button.disabled = best_take == null or not EchoArchive.eligible(sim.character_id) or sim.daily_modifier != &"" or int(sim.expedition.get("debt", 0)) > 0
	_archive_note.text = Loc.t("archive.eligible_note") if not archive_button.disabled else Loc.t("archive.unavailable")
	if int(sim.expedition.get("debt", 0)) > 0:
		_archive_note.text = Loc.t("archive.debt")
	var report := Expedition.status(sim)
	_afterword.text = Loc.t(report.ending) if won else Loc.t("end.loss_note")
	if won and not str(report.get("outcome_key", "")).is_empty():
		_afterword.text += "\n" + Loc.t(report.outcome_key)
	_best_row.visible = best_take != null
	_no_echo.visible = best_take == null
	if best_take != null:
		_best_label.text = Loc.t("end.echo_stats", [best_take.wave, int(round(sim.echo_dps(best_take)))])
		_best_preview.setup(best_take, not reduced_effects, _preview_extent())
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
	if on and _best_preview != null:
		_best_preview.finish_immediately()


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
	if restart_button != null:
		restart_button.grab_focus()


func _rebuild_focus_cycle() -> void:
	UiFocus.cycle([archive_button, retry_button, open_log_button, feedback_button, endless_button,
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


func _preview_extent() -> Vector2:
	return Vector2(88.0, 48.0) if _compact() else Vector2(110.0, 60.0)


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
	var widths: Array[float] = [280.0, 204.0, 230.0, 170.0, 156.0, 156.0, 156.0]
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
	if best_take != null:
		_best_preview.setup(best_take, false, _preview_extent())
