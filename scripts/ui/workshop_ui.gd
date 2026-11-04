class_name WorkshopUi
extends Control

signal closed

var choice_buttons: Array[Button] = []
var cancel_button: Button
var _content: VBoxContainer
var _select := Callable()
var _last_focus: Button
var choice_preview: ChangeVisual


class ChangeVisual:
	extends Control

	signal settled
	var proof: Dictionary = {}
	var elapsed := 0.0
	var duration := 0.9
	var preview := true
	var reduced := false
	var paused := false
	var _reported := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 88)
		clip_contents = true

	func setup(data: Dictionary, as_preview: bool = true, familiar: bool = false, reduced_motion: bool = false) -> void:
		proof = data.duplicate(true)
		preview = as_preview
		reduced = reduced_motion
		duration = (0.32 if familiar else 0.9) if not reduced else (0.12 if familiar else 0.45)
		elapsed = 0.0
		_reported = false
		queue_redraw()

	func step(delta: float) -> void:
		if preview or paused or _reported or not is_visible_in_tree() or size.x < 12.0 or size.y < 12.0 \
				or delta <= 0.0 or not is_finite(delta):
			return
		elapsed = minf(duration, elapsed + delta)
		queue_redraw()
		if elapsed >= duration:
			_reported = true
			settled.emit()

	func _process(delta: float) -> void:
		step(delta)

	func snapshot() -> Dictionary:
		var out := proof.duplicate(true)
		out["progress"] = 1.0 if reduced else clampf(elapsed / duration, 0.0, 1.0)
		out["preview"] = preview
		return out

	func _draw() -> void:
		if proof.is_empty() or size.x < 12.0 or size.y < 12.0:
			return
		var before: Array = proof.get("before", [])
		var after: Array = proof.get("after", [])
		var vertical := size.x < 100.0
		var middle := size * 0.5
		var first := Vector2(middle.x, size.y * 0.20) if vertical else Vector2(size.x * 0.25, middle.y - 8)
		var last := Vector2(middle.x, size.y * 0.65) if vertical else Vector2(size.x * 0.75, middle.y - 8)
		var progress := 1.0 if reduced else clampf(elapsed / duration, 0.0, 1.0)
		var close := smoothstep(0.1, 0.65, progress)
		var extent := minf(42.0, minf(size.y * (0.25 if vertical else 0.55), size.x / 2.6))
		if preview or reduced:
			_group(before, first, extent, 1.0)
			_group(after, last, extent, 1.0)
		else:
			var landing := middle - Vector2(0, 8)
			var travel := Vector2(minf(16.0, size.x * 0.12), 0)
			_group(before, landing - travel * close, extent, 1.0 - close)
			_group(after, landing + travel * (1.0 - close), extent, close)
		var direction := Vector2.DOWN if vertical else Vector2.RIGHT
		var side := direction.orthogonal()
		var alpha := 0.8 if preview or reduced else (1.0 - close)
		var color := Color(UiTheme.INK, alpha)
		draw_line(middle - direction * 9.0, middle + direction * 8.0, color, 1.8, true)
		draw_polyline(PackedVector2Array([middle + direction * 3.0 + side * 4.0,
			middle + direction * 8.0, middle + direction * 3.0 - side * 4.0]), color, 1.8, true)

	func _group(rows: Array, center: Vector2, extent: float, alpha: float) -> void:
		if alpha <= 0.01:
			return
		if rows.is_empty():
			draw_rect(Rect2(center - Vector2.ONE * extent * 0.26, Vector2.ONE * extent * 0.52), Color(UiTheme.DIM, alpha * 0.55), false, 1.0)
			return
		var width := minf(extent, size.x / float(maxi(1, rows.size())) * 0.44)
		for index in mini(2, rows.size()):
			var at := center + Vector2((float(index) - float(mini(2, rows.size()) - 1) * 0.5) * (width + 5.0), 0)
			_token(rows[index], at, width, alpha)

	func _token(row: Dictionary, center: Vector2, extent: float, alpha: float) -> void:
		var key := StringName(row.get("art", &""))
		var texture := PresentationAssets.texture(key)
		var region := PresentationAssets.idle_region(key)
		if texture != null and region.has_area():
			var fitted := region.size * minf(extent / region.size.x, extent / region.size.y)
			draw_texture_rect_region(texture, Rect2(center - fitted * 0.5, fitted), region, Color(1, 1, 1, alpha))
		var label := ""
		if row.has("uid"):
			label = "#%d" % int(row["uid"]) if int(row["uid"]) > 0 else ""
			var bar := Rect2(center + Vector2(-extent * 0.5, extent * 0.5 + 3), Vector2(extent, 4))
			draw_rect(bar, Color(UiTheme.INK, alpha * 0.18))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(row.get("condition", 0)) / 100.0, 0, 1), 4)), Color(UiTheme.ACCENT, alpha))
			var levels: Array = row.get("levels", [])
			for index in mini(6, levels.size()):
				for grade in mini(4, int(levels[index]) + 1):
					draw_circle(center + Vector2(-extent * 0.5 + float(index) * 5.0, -extent * 0.5 - 5.0 - float(grade) * 2.0), 0.8, Color(UiTheme.INK, alpha))
			var skill := StringName(row.get("skill", &""))
			if skill != &"":
				EchoPortrait.draw_skill(self, center + Vector2(extent * 0.5, -extent * 0.25), skill, Color(UiTheme.ACCENT, alpha), 0.55)
		elif row.has("level"):
			label = Loc.t("shop.level", [int(row["level"]) + 1])
		elif row.has("count"):
			label = "×%d" % int(row["count"])
		if label != "" and extent >= 16.0:
			draw_string(UiTheme.font(), center + Vector2(-extent, extent * 0.5 + 16), label,
				HORIZONTAL_ALIGNMENT_CENTER, extent * 2.0, 10, Color(UiTheme.INK, alpha))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.96)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.PAPER))
	margin.add_child(paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	paper.add_child(_content)
	visible = false


# Every decision replaces the same sheet. Cancel always returns to the shop.
func show_choices(title: String, body: String, choices: Array[Dictionary], select: Callable) -> void:
	_select = select
	_last_focus = null
	UiTheme.clear(_content)
	choice_preview = null
	choice_buttons.clear()
	_content.add_child(UiTheme.section_label(title, 29))
	var description := UiTheme.label(body, 16, UiTheme.DIM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(description)
	var grid := GridContainer.new()
	grid.columns = 2 if choices.size() > 2 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for choice in choices:
		var button := Button.new()
		var hint := str(choice.get("hint", ""))
		button.text = str(choice.get("text", ""))
		button.tooltip_text = hint
		button.accessibility_description = hint if hint != "" else button.text
		button.disabled = bool(choice.get("disabled", false))
		if button.disabled and hint != "":
			button.text += "\n" + hint
			button.clip_text = false
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(0.0, 64.0)
		else:
			button.clip_text = true
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		if not button.disabled:
			button.pressed.connect(_choose.bind(choice.get("value")))
		grid.add_child(button)
		choice_buttons.append(button)
		button.focus_entered.connect(_remember_focus.bind(button))
		var preview_data: Dictionary = choice.get("preview", {})
		if not preview_data.is_empty():
			button.mouse_entered.connect(show_choice_preview.bind(preview_data))
			button.focus_entered.connect(show_choice_preview.bind(preview_data))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	cancel_button = Button.new()
	cancel_button.text = Loc.t("shop.cancel")
	cancel_button.custom_minimum_size.y = 38.0
	cancel_button.pressed.connect(close)
	_content.add_child(cancel_button)
	visible = true
	for choice: Dictionary in choices:
		var preview_data: Dictionary = choice.get("preview", {})
		if not preview_data.is_empty():
			show_choice_preview(preview_data)
			break
	var controls: Array = []
	for button in choice_buttons:
		if not button.disabled:
			controls.append(button)
	controls.append(cancel_button)
	UiFocus.cycle(controls)
	for i in controls.size():
		var current := controls[i] as Control
		current.focus_neighbor_left = current.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		current.focus_neighbor_right = current.get_path_to(controls[(i + 1) % controls.size()])
	focus_default()


func _choose(value: Variant) -> void:
	if _select.is_valid():
		_select.call(value)


func focus_default() -> void:
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() and not _last_focus.disabled:
		_last_focus.grab_focus()
		return
	for button in choice_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	if cancel_button != null:
		cancel_button.grab_focus()


func reset() -> void:
	visible = false
	_select = Callable()
	_last_focus = null
	choice_preview = null
	choice_buttons.clear()
	cancel_button = null
	if _content != null:
		UiTheme.clear(_content)


func close() -> void:
	reset()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		accept_event()


# Local padding keeps native 540p readable without changing the canvas scale.
static func fit_button(button: Button, font_size: int = 14, height: float = 28.0) -> void:
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, UiTheme.INK)
	button.add_theme_color_override("font_disabled_color", UiTheme.DIM)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UiTheme.paper_panel(UiTheme.SURFACE if state == "disabled" else UiTheme.CARD)
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
		button.add_theme_stylebox_override(state, style)


func add_result_visual(control: Control) -> void:
	_content.add_child(control)
	_content.move_child(control, 2)


func show_choice_preview(data: Dictionary) -> void:
	if not is_instance_valid(choice_preview):
		choice_preview = ChangeVisual.new()
		add_result_visual(choice_preview)
	choice_preview.setup(data, true)


func _remember_focus(button: Button) -> void:
	_last_focus = button
