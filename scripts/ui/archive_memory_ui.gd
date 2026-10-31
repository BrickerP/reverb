class_name ArchiveMemoryUi
extends Control

signal closed

const PAGE_SIZE := 3
const MAX_REPORTS := 12
const MAX_RETIRED := 6

var rows: Array[Dictionary] = []
var row_buttons: Array[Button] = []
var previous_button: Button
var next_button: Button
var close_button: Button
var page := 0
var selected_record: Dictionary = {}
var _paper: PanelContainer
var _content: VBoxContainer
var _heading: Label
var _summary: Label
var _cards: VBoxContainer
var _page_label: Label
var _cabinet: BureauFacilityUi


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.98)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper = PanelContainer.new()
	_paper.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	margin.add_child(_paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_paper.add_child(_content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_content.add_child(header)
	_cabinet = BureauFacilityUi.new()
	_cabinet.custom_minimum_size = Vector2(74, 58)
	header.add_child(_cabinet)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_heading = UiTheme.section_label(Loc.t("room.memory_title"), 28)
	heading.add_child(_heading)
	_summary = UiTheme.label(Loc.t("room.memory_rule"), 14, UiTheme.DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_summary)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_cards)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_content.add_child(footer)
	previous_button = _action()
	previous_button.text = Loc.t("archive.previous")
	previous_button.pressed.connect(func() -> void: show_page(page - 1))
	footer.add_child(previous_button)
	_page_label = UiTheme.label("", 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_page_label)
	next_button = _action()
	next_button.text = Loc.t("archive.next")
	next_button.pressed.connect(func() -> void: show_page(page + 1))
	footer.add_child(next_button)
	close_button = _action()
	close_button.text = Loc.t("room.return_wall")
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	visible = false
	get_viewport().size_changed.connect(_refresh)


func _action() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(128, 34)
	WorkshopUi.fit_button(button, 15, 34.0)
	return button


func open(profile: Meta) -> void:
	rows = report_rows(profile)
	page = 0
	selected_record.clear()
	visible = true
	_refresh()
	close_button.grab_focus()


static func report_rows(profile: Meta) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if profile == null:
		return output
	var reports: Array = profile.bureau_reports
	for index in range(reports.size() - 1, maxi(-1, reports.size() - MAX_REPORTS - 1), -1):
		var report: Dictionary = reports[index]
		var character := StringName(report.get("character_id", &"looper"))
		var stage := int(report.get("stage", 1))
		var ending := StringName(report.get("ending", &""))
		var title := Loc.t("room.run_report", [Loc.character_name(character), stage])
		var outcome := Loc.t("expedition.ending." + String(ending)) if Expedition.EXIT_IDS.has(ending) else Loc.t("room.shift_ended")
		var detail := outcome + "\n" + Loc.t("room.run_facts", [int(report.get("rescued", 0)), int(report.get("repairs", 0))])
		output.append({"kind": &"report", "character_id": character, "title": title, "detail": detail, "uid": 0})
		if int(report.get("staff_uid", 0)) > 0:
			output.append({"kind": &"staff", "character_id": character, "title": Loc.t("room.staff", [int(report["staff_uid"])]),
				"detail": Loc.t("room.staff_rule"), "uid": int(report["staff_uid"])})
		var retired: Array = report.get("retired", [])
		for retired_index in mini(MAX_RETIRED, retired.size()):
			var row: Dictionary = retired[retired_index]
			var reason := StringName(row.get("reason", &"active"))
			var reason_key := "room.retired_exhausted" if reason == &"exhausted" else "room.retired_active"
			var weapon := StringName(row.get("weapon_id", &""))
			var summary := Loc.t(reason_key)
			if weapon != &"":
				summary += " · " + Loc.weapon_name(weapon)
			var successful := int(row.get("work", 0))
			summary += "\n" + Loc.t("room.retired_work", [successful])
			output.append({"kind": &"retired", "character_id": character, "title": Loc.t("room.retired", [Loc.character_name(character), int(row.get("uid", 0)), int(row.get("wave", stage))]),
				"detail": summary, "uid": int(row.get("uid", 0))})
	return output


func page_count() -> int:
	return maxi(1, ceili(float(rows.size()) / float(PAGE_SIZE)))


func show_page(value: int) -> void:
	page = clampi(value, 0, page_count() - 1)
	_refresh()
	if not row_buttons.is_empty():
		row_buttons[0].grab_focus()
	else:
		close_button.grab_focus()


func _refresh() -> void:
	if _cards == null:
		return
	UiTheme.clear(_cards)
	row_buttons.clear()
	var compact := get_viewport_rect().size.x < 1100.0 or get_viewport_rect().size.y < 640.0
	_heading.add_theme_font_size_override("font_size", 24 if compact else 28)
	if rows.is_empty():
		var empty := UiTheme.label(Loc.t("room.memory_empty"), 18, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_cards.add_child(empty)
	for index in range(page * PAGE_SIZE, mini(rows.size(), (page + 1) * PAGE_SIZE)):
		_add_card(rows[index], compact)
	_page_label.text = Loc.t("archive.detail_page", [page + 1, page_count()])
	previous_button.disabled = page <= 0
	next_button.disabled = page >= page_count() - 1
	var controls: Array = []
	controls.append_array(row_buttons)
	controls.append_array([previous_button, next_button, close_button])
	UiFocus.cycle(controls)


func _add_card(row: Dictionary, compact: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 96.0 if compact else 120.0
	button.toggle_mode = true
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.accessibility_name = row["title"]
	button.accessibility_description = row["detail"]
	button.tooltip_text = row["title"] + "\n" + row["detail"]
	button.set_meta(&"record_kind", row["kind"])
	button.set_meta(&"record_uid", row["uid"])
	_cards.add_child(button)
	row_buttons.append(button)
	button.pressed.connect(func() -> void:
		selected_record = row.duplicate(true)
		for other: Button in row_buttons:
			other.set_pressed_no_signal(other == button))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	var portrait := UiTheme.character_icon(row["character_id"], Vector2(48, 64))
	portrait.modulate.a = 0.55 if row["kind"] == &"retired" else 1.0
	content.add_child(portrait)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(words)
	var title := UiTheme.label(row["title"], 17 if compact else 20)
	title.clip_text = true
	words.add_child(title)
	var detail := UiTheme.label(row["detail"], 13 if compact else 15, UiTheme.DIM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(detail)


func close() -> void:
	var was_visible := visible
	visible = false
	if was_visible:
		closed.emit()


func reset() -> void:
	visible = false
	rows.clear()
	selected_record.clear()
	page = 0


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		accept_event()
