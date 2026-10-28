class_name HistoryUi
extends Control

signal closed
signal replay_requested(seed_value: int, character: StringName, daily_modifier: StringName)

var close_button: Button
var replay_buttons: Array[Button] = []

var _grid: GridContainer
var _empty: Label
var _row_count := 0
var archive_scroll: ScrollContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.surface_panel())
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
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 16)
	archive_scroll = ScrollContainer.new()
	archive_scroll.name = "ArchiveScroll"
	archive_scroll.custom_minimum_size = Vector2(0.0, 380.0)
	archive_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive_scroll.follow_focus = true
	box.add_child(archive_scroll)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_scroll.add_child(_grid)
	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(160.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open(run_log: RunLog) -> void:
	UiTheme.clear(_grid)
	_row_count = 0
	replay_buttons.clear()
	var runs := run_log.recent(8)
	_empty.visible = runs.is_empty()
	_grid.visible = not runs.is_empty()
	archive_scroll.visible = not runs.is_empty()
	if runs.is_empty():
		visible = true
		UiFocus.cycle([close_button])
		close_button.grab_focus()
		return
	_add_cell(Loc.t("history.seed"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.character"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.mode"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.result"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.wave"), UiTheme.DIM, 14)
	_add_cell(Loc.t("history.kills"), UiTheme.DIM, 14)
	_grid.add_child(UiTheme.label("", 14, UiTheme.DIM))
	for run: Dictionary in runs:
		var won := bool(run.get("won", false))
		var char := StringName(str(run.get("character", "?")))
		var seed_value := int(run.get("seed", 0))
		var daily_modifier := StringName(str(run.get("daily_modifier", "")))
		_add_cell(str(seed_value), UiTheme.INK, 16)
		_add_cell(Loc.character_name(char), UiTheme.INK, 16)
		_add_cell(_mode_label(run), UiTheme.DIM, 14)
		_add_cell(Loc.t("history.win") if won else Loc.t("history.loss"),
				UiTheme.COIN if won else UiTheme.WARN, 16)
		_add_cell(str(int(run.get("wave", 0))), UiTheme.INK, 16)
		_add_cell(str(int(run.get("kills", 0))), UiTheme.INK, 16)
		var replay := Button.new()
		replay.text = Loc.t("history.replay")
		if daily_modifier != &"":
			replay.text = Loc.t("history.replay_daily")
		elif bool(run.get("endless", false)):
			replay.text = Loc.t("history.replay_seed")
			replay.tooltip_text = Loc.t("history.replay_seed_hint")
		replay.accessibility_name = "%s · %s · %s" % [
				replay.text, Loc.character_name(char), str(seed_value)]
		replay.custom_minimum_size = Vector2(120.0, 38.0)
		replay.pressed.connect(_on_replay.bind(seed_value, char, daily_modifier))
		_grid.add_child(replay)
		replay_buttons.append(replay)
		_row_count += 1
	visible = true
	var focus_controls: Array[Control] = []
	for replay in replay_buttons:
		focus_controls.append(replay)
	focus_controls.append(close_button)
	UiFocus.cycle(focus_controls)
	focus_default()


func row_count() -> int:
	return _row_count


func focus_default() -> void:
	if not replay_buttons.is_empty():
		replay_buttons[0].grab_focus()
	elif close_button != null:
		close_button.grab_focus()


func _mode_label(run: Dictionary) -> String:
	if bool(run.get("boss_rush", false)):
		return Loc.t("history.mode_boss_rush")
	if bool(run.get("endless", false)):
		return Loc.t("history.mode_endless")
	if str(run.get("daily_modifier", "")) != "":
		return Loc.t("history.mode_daily")
	return Loc.t("history.mode_normal")


func _on_replay(seed_value: int, char: StringName, daily_modifier: StringName) -> void:
	replay_requested.emit(seed_value, char, daily_modifier)


func close() -> void:
	visible = false
	closed.emit()


func _add_cell(text: String, color: Color, size: int) -> void:
	_grid.add_child(UiTheme.label(text, size, color))
