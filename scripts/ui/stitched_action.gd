class_name StitchedAction
extends Button

# A secondary action carries a small ink stitch even before it is hovered.
# The drawn mark never changes the control's layout or interaction rectangle.
func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	var empty := UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	empty.draw_center = false
	empty.shadow_color = Color(0, 0, 0, 0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var emphasized := not disabled and (has_focus() or is_hovered() or is_pressed())
	var points := marker_points(size, emphasized)
	if points.is_empty():
		return
	var color := get_theme_color("font_disabled_color" if disabled else "font_color")
	color.a *= 0.7 if not emphasized else 1.0
	draw_polyline(points, color, 1.9 if emphasized else 1.3, true)
	var stitch := points[0] + Vector2(4.0, 0.0)
	draw_line(stitch + Vector2(-1.0, -2.0), stitch + Vector2(1.5, 2.0), color, 1.0, true)


static func marker_points(extent: Vector2, emphasized: bool = false) -> PackedVector2Array:
	if not extent.is_finite() or minf(extent.x, extent.y) < 8.0:
		return PackedVector2Array()
	var center := extent.x * 0.5
	var reach := minf(43.0, extent.x * 0.32) if emphasized else minf(19.0, extent.x * 0.17)
	var y := extent.y - 5.0
	return PackedVector2Array([Vector2(center - reach, y + 0.6), Vector2(center - 2.0, y - 0.7),
		Vector2(center + reach, y)])
