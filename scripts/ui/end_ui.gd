class_name EndUi
extends Control

signal restart_requested

var restart_button: Button

var _title: Label
var _stats: Label


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	_title = UiTheme.label("", 44, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_stats = UiTheme.label("", 22, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	restart_button = Button.new()
	restart_button.custom_minimum_size = Vector2(280.0, 56.0)
	restart_button.pressed.connect(_on_restart)
	box.add_child(_title)
	box.add_child(_stats)
	box.add_child(restart_button)


func show_result(sim: Sim) -> void:
	var won := sim.phase == Sim.Phase.WON
	_title.text = Loc.t("end.win", [WaveDirector.FINAL_WAVE]) if won else Loc.t("end.lose", [sim.wave])
	_title.add_theme_color_override("font_color", UiTheme.COIN if won else UiTheme.WARN)
	_stats.text = Loc.t("end.stats", [sim.kills])
	restart_button.text = Loc.t("end.restart")
	visible = true
	restart_button.grab_focus()


func _on_restart() -> void:
	restart_requested.emit()
