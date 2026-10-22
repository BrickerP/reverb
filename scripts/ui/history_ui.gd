class_name HistoryUi
extends Control

signal closed
signal replay_requested(seed_value: int, character: StringName)

var close_button: Button

var _grid: GridContainer
var _empty: Label
var _row_count := 0


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(840.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(
			Color(0.03, 0.04, 0.09, 0.98), Color(0.3, 0.5, 0.9, 0.6), 2, 10))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("history.title"), 34, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_empty = UiTheme.label(Loc.t("history.empty"), 18, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_empty)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(160.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open(run_log: RunLog) -> void:
	UiTheme.clear(_grid)
	_row_count = 0
	var runs := run_log.recent(8)
	_empty.visible = runs.is_empty()
	_grid.visible = not runs.is_empty()
	if runs.is_empty():
		visible = true
		close_button.grab_focus()
		return
	_add_cell(Loc.t("history.seed"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.character"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.result"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.wave"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.kills"), UiTheme.DIM, 14)
	_grid.add_child(UiTheme.label("", 14, UiTheme.DIM))
	for run: Dictionary in runs:
		var won := bool(run.get("won", false))
		var char := StringName(str(run.get("character", "?")))
		var seed_value := int(run.get("seed", 0))
		_add_cell(str(seed_value), UiTheme.INK, 16)
		_add_cell(Loc.character_name(char), UiTheme.INK, 16)
		_add_cell(Loc.t("history.win") if won else Loc.t("history.loss"),
				UiTheme.COIN if won else UiTheme.WARN, 16)
		_add_cell(str(int(run.get("wave", 0))), UiTheme.INK, 16)
		_add_cell(str(int(run.get("kills", 0))), UiTheme.INK, 16)
		var replay := Button.new()
		replay.text = Loc.t("history.replay")
		replay.custom_minimum_size = Vector2(86.0, 30.0)
		replay.pressed.connect(_on_replay.bind(seed_value, char))
		_grid.add_child(replay)
		_row_count += 1
	visible = true
	close_button.grab_focus()


func row_count() -> int:
	return _row_count


func _on_replay(seed_value: int, char: StringName) -> void:
	replay_requested.emit(seed_value, char)


func close() -> void:
	visible = false
	closed.emit()


func _add_cell(text: String, color: Color, size: int) -> void:
	_grid.add_child(UiTheme.label(text, size, color))
