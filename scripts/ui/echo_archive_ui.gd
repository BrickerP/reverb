class_name EchoArchiveUi
extends Control

signal closed

var meta: Meta
var selected: StringName = &"looper"
var toggle_button: Button
var history_button: Button
var room: ArchiveRoomUi
var memory: ArchiveMemoryUi
var _body: VBoxContainer
var _note: Label
var _roles: HBoxContainer
var _preview: ArchiveRoutePreview
var _entry: ArchiveCandidateUi
var _entry_sim: Sim
var _description: Label
var _close_button: Button
var _role_buttons: Array[Button] = []
var _paper: PanelContainer
var _heading: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(UiTheme.EDGE, 0.94)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper = PanelContainer.new()
	var paper := _paper
	paper.custom_minimum_size = Vector2(900.0, 0.0)
	paper.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	center.add_child(paper)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	paper.add_child(_body)
	_heading = UiTheme.label(Loc.t("room.title"), 36, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(_heading)
	_note = UiTheme.label(Loc.t("archive.rule"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_note.custom_minimum_size.x = 840.0
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_note)
	room = ArchiveRoomUi.new()
	_roles = room
	room.role_selected.connect(_choose)
	_body.add_child(_roles)
	_entry = ArchiveCandidateUi.new()
	_body.add_child(_entry)
	_preview = _entry.route
	_description = _entry.details
	toggle_button = Button.new()
	toggle_button.toggle_mode = true
	toggle_button.custom_minimum_size = Vector2(340.0, 42.0)
	toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toggle_button.pressed.connect(_toggle)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 14)
	_body.add_child(controls)
	controls.add_child(toggle_button)
	history_button = Button.new()
	history_button.text = Loc.t("room.open_memory")
	history_button.custom_minimum_size = Vector2(210.0, 42.0)
	history_button.pressed.connect(_open_memory)
	controls.add_child(history_button)
	_close_button = Button.new()
	_close_button.text = Loc.t("story.close")
	_close_button.custom_minimum_size = Vector2(180.0, 36.0)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close)
	_body.add_child(_close_button)
	memory = ArchiveMemoryUi.new()
	memory.z_index = 10
	add_child(memory)
	memory.closed.connect(func() -> void:
		if visible:
			history_button.grab_focus())
	get_viewport().size_changed.connect(_on_canvas_resized)
	_apply_layout()


func open(profile: Meta, id: StringName = &"looper") -> void:
	meta = profile
	memory.reset()
	_note.text = Loc.t("archive.rule")
	_apply_layout()
	selected = id if EchoArchive.eligible(id) else &"looper"
	_refresh()
	visible = true
	_rebuild_focus()
	toggle_button.grab_focus()


func _rebuild_focus() -> void:
	var focus_controls: Array[Control] = []
	for button in _role_buttons:
		focus_controls.append(button)
	focus_controls.append(_entry.detail_button)
	focus_controls.append(toggle_button)
	focus_controls.append(history_button)
	focus_controls.append(_close_button)
	UiFocus.cycle(focus_controls)


func _choose(id: StringName) -> void:
	selected = id
	_refresh()


func _toggle() -> void:
	var enabled := toggle_button.button_pressed
	if not EchoArchive.set_enabled(meta, enabled):
		_note.text = Loc.t(meta.last_error if meta.last_error != "" else "archive.save_failed")
	else:
		_note.text = Loc.t("archive.rule")
	_refresh()


func _refresh() -> void:
	if meta == null:
		return
	room.configure(meta, selected, _compact())
	_role_buttons.assign(room.role_frames)
	toggle_button.set_pressed_no_signal(meta.inherit_echo)
	toggle_button.text = Loc.t("archive.enabled" if meta.inherit_echo else "archive.disabled")
	var take := EchoArchive.peek(meta, selected)
	_preview.visible = take != null
	if take == null:
		_entry.preview.clear()
		_entry.detail_button.visible = false
		_description.text = Loc.t("archive.empty", [Loc.character_name(selected)])
		_entry.accessibility_description = _description.text
	else:
		_entry_sim = Sim.new(1)
		Content.character(selected).apply(_entry_sim)
		_entry.setup(take, EchoArchive.entry_preview(meta, selected, _entry_sim), _compact())
	_rebuild_focus()


func _open_memory() -> void:
	if meta != null:
		memory.open(meta)


func close() -> void:
	var was_visible := visible
	visible = false
	if memory != null:
		memory.reset()
	meta = null
	if was_visible:
		closed.emit()


func _canvas_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(1280.0, 720.0)
	var extent := get_viewport_rect().size
	return extent if extent.x > 0.0 and extent.y > 0.0 else Vector2(1280.0, 720.0)


func _compact() -> bool:
	var extent := _canvas_size()
	return extent.x < 1100.0 or extent.y < 640.0


func _on_canvas_resized() -> void:
	_apply_layout()
	if meta != null:
		_refresh()


func _apply_layout() -> void:
	if _paper == null:
		return
	var compact := _compact()
	_paper.custom_minimum_size.x = minf(900.0, maxf(0.0, _canvas_size().x - 32.0))
	_body.add_theme_constant_override("separation", 6 if compact else 10)
	_heading.add_theme_font_size_override("font_size", 30 if compact else 36)
	_note.custom_minimum_size.x = 0.0
	_description.custom_minimum_size.x = 0.0
	for button in _role_buttons:
		button.custom_minimum_size.x = 100.0
	WorkshopUi.fit_button(toggle_button, 16, 36.0 if compact else 42.0)
	WorkshopUi.fit_button(history_button, 16, 36.0 if compact else 42.0)
	WorkshopUi.fit_button(_close_button, 16, 32.0 if compact else 36.0)
