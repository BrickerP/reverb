class_name EndUi
extends Control

signal restart_requested
signal character_requested
signal seed_retry_requested(seed_value: int)
signal open_log_requested
signal endless_requested
signal boss_rush_requested
signal feedback_requested

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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(930.0, 0.0)
	var sheet := UiTheme.surface_panel().duplicate() as InkStyleBox
	sheet.shape = InkStyleBox.Shape.PAPER
	sheet.softness = 74.0
	sheet.variant = 16
	panel.add_theme_stylebox_override("panel", sheet)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 11)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("end.report"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_title = UiTheme.label("", 52, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_afterword = UiTheme.label("", 17, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
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
	box.add_child(_best_row)
	_no_echo = UiTheme.label(Loc.t("end.no_echo"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_no_echo)
	_unlock = UiTheme.label("", 18, UiTheme.COIN, HORIZONTAL_ALIGNMENT_CENTER)
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


func _small_action() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(156.0, 30.0)
	button.add_theme_font_size_override("font_size", 14)
	button.flat = true
	return button


func show_result(sim: Sim, unlocked_text: String = "") -> void:
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
	_best_row.visible = best_take != null
	_no_echo.visible = best_take == null
	if best_take != null:
		_best_label.text = Loc.t("end.echo_stats", [best_take.wave, int(round(sim.echo_dps(best_take)))])
		_best_preview.setup(best_take, not reduced_effects)
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
	UiFocus.cycle([retry_button, open_log_button, feedback_button, endless_button,
			boss_rush_button, restart_button, character_button])


func _on_retry_seed() -> void:
	seed_retry_requested.emit(_seed_value)


func _on_restart() -> void:
	restart_requested.emit()


func _on_character() -> void:
	character_requested.emit()
