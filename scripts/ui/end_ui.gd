class_name EndUi
extends Control

signal restart_requested
signal character_requested
signal seed_retry_requested(seed_value: int)
signal open_log_requested

var restart_button: Button
var character_button: Button
var retry_button: Button
var open_log_button: Button
var best_take: EchoTake

var _title: Label
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
	dim.color = Color(0.01, 0.01, 0.04, 0.82)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(
			Color(0.03, 0.04, 0.09, 0.97), Color(0.3, 0.5, 0.9, 0.6), 2, 10))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	_title = UiTheme.label("", 40, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_stats = UiTheme.label("", 20, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	box.add_child(_stats)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_seed = UiTheme.label("", 12, UiTheme.DIM)
	seed_row.add_child(_seed)
	retry_button = Button.new()
	retry_button.custom_minimum_size = Vector2(150.0, 28.0)
	retry_button.pressed.connect(_on_retry_seed)
	seed_row.add_child(retry_button)
	open_log_button = Button.new()
	open_log_button.custom_minimum_size = Vector2(170.0, 28.0)
	open_log_button.pressed.connect(func() -> void: open_log_requested.emit())
	seed_row.add_child(open_log_button)
	box.add_child(seed_row)
	_unlock = UiTheme.label("", 15, UiTheme.COIN, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_unlock)
	_best_row = HBoxContainer.new()
	_best_row.add_theme_constant_override("separation", 16)
	_best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_best_preview = PathPreview.new()
	_best_row.add_child(_best_preview)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(UiTheme.label(Loc.t("end.best_echo"), 14, UiTheme.ECHO))
	_best_label = UiTheme.label("", 18)
	info.add_child(_best_label)
	_best_row.add_child(info)
	box.add_child(_best_row)
	_no_echo = UiTheme.label(Loc.t("end.no_echo"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_no_echo)
	restart_button = Button.new()
	restart_button.custom_minimum_size = Vector2(220.0, 56.0)
	restart_button.pressed.connect(_on_restart)
	character_button = Button.new()
	character_button.custom_minimum_size = Vector2(220.0, 56.0)
	character_button.pressed.connect(_on_character)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(restart_button)
	buttons.add_child(character_button)
	box.add_child(buttons)


func show_result(sim: Sim, unlocked_text: String = "") -> void:
	var won := sim.phase == Sim.Phase.WON
	_title.text = Loc.t("end.win", [WaveDirector.FINAL_WAVE]) if won else Loc.t("end.lose", [sim.wave])
	_title.add_theme_color_override("font_color", UiTheme.COIN if won else UiTheme.WARN)
	_stats.text = Loc.t("end.run", [sim.wave, WaveDirector.FINAL_WAVE, sim.kills])
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
		_best_preview.setup(best_take, true)
	restart_button.text = Loc.t("end.restart")
	character_button.text = Loc.t("end.change")
	retry_button.text = Loc.t("end.retry_seed")
	open_log_button.text = Loc.t("end.open_log")
	visible = true
	restart_button.grab_focus()


func _on_retry_seed() -> void:
	seed_retry_requested.emit(_seed_value)


func _on_restart() -> void:
	restart_requested.emit()


func _on_character() -> void:
	character_requested.emit()
