class_name EchoArchiveUi
extends Control

signal closed

var meta: Meta
var selected: StringName = &"looper"
var toggle_button: Button
var _body: VBoxContainer
var _note: Label
var _roles: HBoxContainer
var _preview: PathPreview
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
	_heading = UiTheme.label(Loc.t("archive.title"), 36, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(_heading)
	_note = UiTheme.label(Loc.t("archive.rule"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_note.custom_minimum_size.x = 840.0
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_note)
	_roles = HBoxContainer.new()
	_roles.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(_roles)
	for id: StringName in Content.characters():
		if not EchoArchive.eligible(id):
			continue
		var button := Button.new()
		button.text = Loc.character_name(id)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150.0, 38.0)
		button.pressed.connect(_choose.bind(id))
		_role_buttons.append(button)
		_roles.add_child(button)
	_preview = PathPreview.new()
	_preview.custom_minimum_size = Vector2(280.0, 150.0)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_preview)
	_description = UiTheme.label("", 16, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_description.custom_minimum_size.x = 820.0
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_description)
	toggle_button = Button.new()
	toggle_button.toggle_mode = true
	toggle_button.custom_minimum_size = Vector2(340.0, 42.0)
	toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toggle_button.pressed.connect(_toggle)
	_body.add_child(toggle_button)
	_close_button = Button.new()
	_close_button.text = Loc.t("story.close")
	_close_button.custom_minimum_size = Vector2(180.0, 36.0)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close)
	_body.add_child(_close_button)
	get_viewport().size_changed.connect(_on_canvas_resized)
	_apply_layout()


func open(profile: Meta, id: StringName = &"looper") -> void:
	meta = profile
	_apply_layout()
	selected = id if EchoArchive.eligible(id) else &"looper"
	_refresh()
	visible = true
	var focus_controls: Array[Control] = []
	for button in _role_buttons:
		focus_controls.append(button)
	focus_controls.append(toggle_button)
	focus_controls.append(_close_button)
	UiFocus.cycle(focus_controls)
	toggle_button.grab_focus()


func _choose(id: StringName) -> void:
	selected = id
	_refresh()


func _toggle() -> void:
	var enabled := toggle_button.button_pressed
	if not EchoArchive.set_enabled(meta, enabled):
		_note.text = Loc.t(meta.last_error if meta.last_error != "" else "archive.save_failed")
	_refresh()


func _refresh() -> void:
	if meta == null:
		return
	toggle_button.set_pressed_no_signal(meta.inherit_echo)
	toggle_button.text = Loc.t("archive.enabled" if meta.inherit_echo else "archive.disabled")
	var take := EchoArchive.peek(meta, selected)
	_preview.visible = take != null
	if take == null:
		_description.text = Loc.t("archive.empty", [Loc.character_name(selected)])
	else:
		var extent := Vector2(220.0, 80.0) if _compact() else Vector2(280.0, 120.0)
		_preview.setup(take, true, extent)
		var weapons := PackedStringArray()
		for index in mini(3, take.weapons.size()):
			weapons.append(Loc.weapon_name(take.weapons[index].id))
		if take.weapons.size() > 3:
			weapons.append("+%d" % (take.weapons.size() - 3))
		_description.text = Loc.t("archive.preview", [Loc.character_name(selected), take.wave, ", ".join(weapons)])
	for index in _role_buttons.size():
		_role_buttons[index].button_pressed = _role_buttons[index].text == Loc.character_name(selected)


func close() -> void:
	var was_visible := visible
	visible = false
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
		button.custom_minimum_size.x = 128.0 if compact else 150.0
		WorkshopUi.fit_button(button, 16, 32.0 if compact else 38.0)
	WorkshopUi.fit_button(toggle_button, 16, 36.0 if compact else 42.0)
	WorkshopUi.fit_button(_close_button, 16, 32.0 if compact else 36.0)
