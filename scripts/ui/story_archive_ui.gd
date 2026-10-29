class_name StoryArchiveUi
extends Control

signal closed
var close_button: Button
var archive_scroll: ScrollContainer
var _rows: VBoxContainer
var _empty: Label
var _row_count := 0


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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820.0, 0.0)
	var paper := UiTheme.paper_panel(UiTheme.PAPER)
	paper.shape = InkStyleBox.Shape.PAPER
	paper.variant = 19
	paper.softness = 64.0
	paper.content_margin_left = 24.0
	paper.content_margin_right = 24.0
	paper.content_margin_top = 18.0
	paper.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", paper)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.label(Loc.t("story.title"), 40, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var subtitle := UiTheme.label(Loc.t("story.subtitle"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)
	_empty = UiTheme.label(Loc.t("story.empty"), 18, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(740.0, 100.0)
	box.add_child(_empty)
	archive_scroll = ScrollContainer.new()
	archive_scroll.custom_minimum_size = Vector2(740.0, 340.0)
	archive_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive_scroll.follow_focus = true
	box.add_child(archive_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 14)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_scroll.add_child(_rows)
	close_button = Button.new()
	close_button.text = Loc.t("story.close")
	close_button.custom_minimum_size = Vector2(180.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open(meta: Meta) -> void:
	UiTheme.clear(_rows)
	var entries := StoryLedger.archive(meta)
	_row_count = entries.size()
	_empty.visible = entries.is_empty()
	archive_scroll.visible = not entries.is_empty()
	var controls: Array[Control] = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var sheet := PanelContainer.new()
		sheet.focus_mode = Control.FOCUS_ALL
		sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var paper := UiTheme.paper_panel(UiTheme.CARD)
		paper.shape = InkStyleBox.Shape.TAG
		paper.variant = 20 + i
		paper.content_margin_left = 16.0
		paper.content_margin_right = 16.0
		paper.content_margin_top = 10.0
		paper.content_margin_bottom = 12.0
		sheet.add_theme_stylebox_override("panel", paper)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 6)
		var title := UiTheme.label(Loc.t(entry.name_key), 23, UiTheme.INK)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(title)
		var body := UiTheme.label(Loc.t(entry.body_key), 17, UiTheme.INK)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 680.0
		text.add_child(body)
		sheet.accessibility_name = "%s. %s" % [title.text, body.text]
		sheet.add_child(text)
		_rows.add_child(sheet)
		controls.append(sheet)
	controls.append(close_button)
	UiFocus.cycle(controls)
	visible = true
	close_button.grab_focus()


func row_count() -> int:
	return _row_count


func close() -> void:
	visible = false
	closed.emit()
