class_name ArchiveRoomUi
extends HBoxContainer

# A portrait is a live view of one chosen permanent record, never an extra copy.
signal role_selected(id: StringName)

class FamilyFrame extends Button:
	var role_id: StringName
	var occupied := false
	var condition := 0.0
	var portrait: TextureRect
	var name_label: Label
	var state_label: Label
	var compact := false

	func configure(id: StringName, take: EchoTake, small: bool) -> void:
		role_id = id
		compact = small
		occupied = take != null
		condition = take.condition if occupied else 0.0
		toggle_mode = true
		clip_contents = true
		custom_minimum_size = Vector2(100.0, 92.0 if compact else 116.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if portrait == null:
			portrait = UiTheme.character_icon(id, Vector2(48, 56))
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(portrait)
			name_label = UiTheme.label("", 14, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
			name_label.clip_text = true
			add_child(name_label)
			state_label = UiTheme.label("", 11, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
			state_label.clip_text = true
			add_child(state_label)
		portrait.visible = occupied
		portrait.modulate = Color.WHITE.lerp(UiTheme.SURFACE, (1.0 - condition / 100.0) * 0.45)
		name_label.text = Loc.character_name(id)
		state_label.text = Loc.t("room.filed", [ceili(condition)]) if occupied else Loc.t("room.empty_frame")
		accessibility_name = name_label.text
		accessibility_description = state_label.text
		tooltip_text = name_label.text + " · " + state_label.text
		_layout()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and portrait != null:
			_layout()

	func _layout() -> void:
		if portrait == null:
			return
		var height := 43.0 if compact else 65.0
		portrait.position = Vector2((size.x - 52.0) * 0.5, 7.0)
		portrait.size = Vector2(52.0, height)
		portrait.custom_minimum_size = portrait.size
		name_label.position = Vector2(3.0, height + 9.0)
		name_label.size = Vector2(maxf(0.0, size.x - 6.0), 22.0)
		state_label.position = Vector2(3.0, height + 30.0)
		state_label.size = Vector2(maxf(0.0, size.x - 6.0), 17.0)

	func _draw() -> void:
		var inner := Rect2(Vector2(5, 5), size - Vector2(10, 10))
		draw_rect(inner, Color(UiTheme.INK, 0.06), false, 1.0)
		if not occupied:
			var center := Vector2(size.x * 0.5, (43.0 if compact else 65.0) * 0.5 + 7.0)
			draw_polyline(PackedVector2Array([center + Vector2(5, -12), center + Vector2(-4, -12), center + Vector2(-4, 12), center + Vector2(4, 12), center + Vector2(4, -7), center + Vector2(0, -7), center + Vector2(0, 8)]), UiTheme.DIM, 1.5, true)
		elif condition < 60.0:
			draw_polyline(PackedVector2Array([Vector2(size.x - 6, 13), Vector2(size.x - 14, 23), Vector2(size.x - 8, 28), Vector2(size.x - 18, 39)]), UiTheme.DIM, 1.4, true)

var role_frames: Array[Button] = []


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func configure(profile: Meta, selected: StringName, compact: bool) -> void:
	if role_frames.is_empty():
		for id: StringName in Content.characters():
			if not EchoArchive.eligible(id):
				continue
			var frame := FamilyFrame.new()
			frame.role_id = id
			frame.pressed.connect(func() -> void: role_selected.emit(id))
			add_child(frame)
			role_frames.append(frame)
	for raw: Button in role_frames:
		var frame := raw as FamilyFrame
		var id := frame.role_id
		frame.configure(id, EchoArchive.peek(profile, id), compact)
		frame.set_pressed_no_signal(id == selected)
