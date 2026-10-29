class_name HistoryUi
extends Control

signal closed
signal replay_requested(seed_value: int, character: StringName, daily_modifier: StringName)

var close_button: Button
var replay_buttons: Array[Button] = []
var archive_scroll: ScrollContainer

var _grid: VBoxContainer
var _empty: Label
var _empty_state: VBoxContainer
var _panel: PanelContainer
var _row_count := 0
var record_panels: Array[PanelContainer] = []


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.88)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1020.0, 0.0)
	var cover := UiTheme.paper_panel(UiTheme.PAPER)
	cover.shape = InkStyleBox.Shape.PAPER
	cover.softness = 72.0
	cover.variant = 7
	_panel.add_theme_stylebox_override("panel", cover)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("history.title"), 50, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("history.subtitle"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_empty_state = VBoxContainer.new()
	_empty_state.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_state.add_theme_constant_override("separation", 16)
	var empty_art := UiTheme.cartridge_icon(Vector2(116.0, 88.0))
	empty_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_state.add_child(empty_art)
	_empty = UiTheme.label(Loc.t("history.empty"), 18, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(540.0, 60.0)
	_empty_state.add_child(_empty)
	box.add_child(_empty_state)
	archive_scroll = ScrollContainer.new()
	archive_scroll.name = "ArchiveScroll"
	archive_scroll.custom_minimum_size = Vector2(0.0, 360.0)
	archive_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive_scroll.follow_focus = true
	box.add_child(archive_scroll)
	_grid = VBoxContainer.new()
	_grid.name = "FiledVersions"
	_grid.add_theme_constant_override("separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_scroll.add_child(_grid)
	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(180.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open(run_log: RunLog) -> void:
	UiTheme.clear(_grid)
	_row_count = 0
	replay_buttons.clear()
	record_panels.clear()
	var runs := run_log.recent(8)
	_empty_state.visible = runs.is_empty()
	_empty.visible = runs.is_empty()
	archive_scroll.visible = not runs.is_empty()
	_panel.custom_minimum_size.x = 760.0 if runs.is_empty() else 1020.0
	for i in runs.size():
		_grid.add_child(_record(runs[i], i))
		_row_count += 1
	visible = true
	var focus_controls: Array[Control] = []
	for replay in replay_buttons:
		focus_controls.append(replay)
	focus_controls.append(close_button)
	UiFocus.cycle(focus_controls)
	focus_default()


func _record(run: Dictionary, index: int) -> Control:
	var won := bool(run.get("won", false))
	var character := StringName(str(run.get("character", "?")))
	var seed_value := int(run.get("seed", 0))
	var daily_modifier := StringName(str(run.get("daily_modifier", "")))
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 22 if index % 2 == 1 else 0)
	inset.add_theme_constant_override("margin_right", 22 if index % 2 == 0 else 0)
	var sheet := PanelContainer.new()
	sheet.name = "Record_%d" % index
	var paper := UiTheme.paper_panel(UiTheme.CARD if won else UiTheme.PAPER)
	paper.shape = InkStyleBox.Shape.TAG
	paper.variant = 11 + index
	paper.draw_center = false
	paper.border_color = Color(UiTheme.EDGE, 0.0)
	paper.content_margin_left = 16.0
	paper.content_margin_right = 18.0
	paper.content_margin_top = 10.0
	paper.content_margin_bottom = 10.0
	sheet.add_theme_stylebox_override("panel", paper)
	inset.add_child(sheet)
	record_panels.append(sheet)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	sheet.add_child(row)
	var portrait := UiTheme.character_icon(character, Vector2(50.0, 60.0))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(130.0, 0.0)
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 4)
	identity.add_child(UiTheme.label(Loc.character_name(character), 20))
	identity.add_child(UiTheme.label(Loc.t("history.batch", [index + 1]), 12, UiTheme.DIM))
	row.add_child(identity)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail.add_theme_constant_override("separation", 3)
	detail.add_child(UiTheme.label(Loc.t("history.metrics", [int(run.get("wave", 0)),
			int(run.get("kills", 0))]), 17))
	detail.add_child(UiTheme.label(_mode_label(run), 14, UiTheme.DIM))
	detail.add_child(UiTheme.label("%s %d" % [Loc.t("history.seed"), seed_value], 12, UiTheme.DIM))
	row.add_child(detail)
	var verdict := UiTheme.label(Loc.t("history.win") if won else Loc.t("history.loss"),
			24, UiTheme.ACCENT if won else UiTheme.WARN)
	verdict.custom_minimum_size = Vector2(64.0, 0.0)
	verdict.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(verdict)
	var replay := Button.new()
	replay.text = Loc.t("history.replay")
	if daily_modifier != &"":
		replay.text = Loc.t("history.replay_daily")
	elif bool(run.get("endless", false)):
		replay.text = Loc.t("history.replay_seed")
		replay.tooltip_text = Loc.t("history.replay_seed_hint")
	replay.accessibility_name = "%s · %s · %s" % [replay.text,
			Loc.character_name(character), str(seed_value)]
	replay.custom_minimum_size = Vector2(148.0, 42.0)
	replay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	replay.pressed.connect(_on_replay.bind(seed_value, character, daily_modifier))
	row.add_child(replay)
	replay_buttons.append(replay)
	return inset


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


func _on_replay(seed_value: int, character: StringName, daily_modifier: StringName) -> void:
	replay_requested.emit(seed_value, character, daily_modifier)


func close() -> void:
	visible = false
	closed.emit()
