class_name InkStyleBox
extends StyleBox

# The control and its text remain still. Only this drawn silhouette is lopsided.
enum Shape { PAPER, TAG, OVAL, BLOB }

@export var bg_color := Color("f5e8c7")
@export var border_color := Color("28261f")
@export var draw_center := true
@export var shape: Shape = Shape.PAPER
@export var variant: int = 0
@export var softness: float = 24.0
@export var shadow_color := Color(0.1, 0.09, 0.07, 0.12)
@export var shadow_offset := Vector2(1.5, 2.0)
@export var shadow_size: float = 0.0
@export var focus_marks := false
@export var sketch := false
@export var grip_mark := false
@export var expand_margin: float = 0.0
@export_storage var stroke_widths := Vector4(2.0, 2.0, 2.0, 2.0)

const STEPS := 7

var _mesh_size := Vector2(-1.0, -1.0)
var _mesh_shape: int = -1
var _mesh_variant: int = 0
var _mesh_softness: float = -1.0
var _mesh_points := PackedVector2Array()
var _mesh_triangles := PackedInt32Array()


func set_border_width_all(width: float) -> void:
	var value := maxf(0.0, width)
	stroke_widths = Vector4(value, value, value, value)


func set_border_width(side: Side, width: float) -> void:
	stroke_widths[int(side)] = maxf(0.0, width)


func get_border_width_min() -> float:
	return minf(minf(stroke_widths.x, stroke_widths.y), minf(stroke_widths.z, stroke_widths.w))


func outline(rect: Rect2) -> PackedVector2Array:
	var points := _local_outline(rect.size)
	if not rect.position.is_finite():
		return PackedVector2Array()
	for index in points.size():
		points[index] += rect.position
	return points


func _get_minimum_size() -> Vector2:
	return Vector2(2.0, 2.0)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var shadow := maxf(absf(shadow_offset.x), absf(shadow_offset.y)) + maxf(0.0, shadow_size)
	return rect.grow(maxf(0.0, expand_margin) + _stroke_width() + shadow)


func _test_mask(point: Vector2, rect: Rect2) -> bool:
	if not rect.has_point(point):
		return false
	if grip_mark:
		return true
	var points := _local_outline(rect.size)
	return points.size() >= 3 and Geometry2D.is_point_in_polygon(point - rect.position, points)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if not to_canvas_item.is_valid() or not rect.position.is_finite():
		return
	if (not draw_center or bg_color.a <= 0.0) and border_color.a <= 0.0:
		return
	var area := visual_rect(rect).grow(expand_margin)
	_update_mesh(area.size)
	if _mesh_points.size() < 3 or _mesh_triangles.is_empty():
		return
	# Ear clipping sees small local coordinates, never a tiny shape at a large UI offset.
	if draw_center and bg_color.a > 0.0:
		if shadow_color.a > 0.0 and shadow_offset.length_squared() > 0.0:
			var shade := _mesh_points
			if shadow_size > 0.0:
				shade = _mesh_points.duplicate()
				var half := area.size * 0.5
				var spread := (area.size + Vector2.ONE * shadow_size * 2.0) / area.size
				for index in shade.size():
					shade[index] = half + (shade[index] - half) * spread
			_draw_fill(to_canvas_item, shade, _mesh_triangles, area.position + shadow_offset, shadow_color)
		_draw_fill(to_canvas_item, _mesh_points, _mesh_triangles, area.position, bg_color)
	if border_color.a <= 0.0 or _stroke_width() <= 0.0:
		return
	if focus_marks:
		_draw_focus(to_canvas_item, area)
		return
	var closed := _offset(_mesh_points, area.position)
	closed.append(closed[0])
	RenderingServer.canvas_item_add_polyline(to_canvas_item, closed,
			PackedColorArray([border_color]), _stroke_width(), true)
	if sketch and area.size.x >= 100.0 and area.size.y >= 70.0:
		_draw_sketch(to_canvas_item, area)


func visual_rect(rect: Rect2) -> Rect2:
	if not grip_mark or not rect.size.is_finite() or minf(rect.size.x, rect.size.y) <= 0.0:
		return rect
	var size: Vector2
	if rect.size.y >= rect.size.x:
		size = Vector2(minf(11.0, rect.size.x * 0.75), minf(27.0, rect.size.y * 0.9))
	else:
		size = Vector2(minf(27.0, rect.size.x * 0.9), minf(11.0, rect.size.y * 0.75))
	return Rect2(rect.get_center() - size * 0.5, size)


func _draw_fill(canvas: RID, points: PackedVector2Array, triangles: PackedInt32Array,
		offset: Vector2, color: Color) -> void:
	RenderingServer.canvas_item_add_triangle_array(canvas, triangles, _offset(points, offset),
			PackedColorArray([color]))


func _draw_focus(canvas: RID, rect: Rect2) -> void:
	var reach := minf(11.0, rect.size.y * 0.23)
	var midpoint := rect.position.y + rect.size.y * 0.5
	var left := rect.position.x + 1.0
	var right := rect.end.x - 1.0
	for side in 2:
		var x := left if side == 0 else right
		var inward := 1.0 if side == 0 else -1.0
		var bracket := PackedVector2Array([
			Vector2(x + inward * 5.0, midpoint - reach),
			Vector2(x + inward, midpoint - reach * 0.65),
			Vector2(x, midpoint),
			Vector2(x + inward * 1.5, midpoint + reach * 0.75),
			Vector2(x + inward * 5.5, midpoint + reach),
		])
		RenderingServer.canvas_item_add_polyline(canvas, bracket,
				PackedColorArray([border_color]), _stroke_width(), true)
	# Small ink ticks are recognisable even when a mouse hover is also present.
	var tick := PackedVector2Array([Vector2(left - 2.0, midpoint - 2.0),
		Vector2(left - 5.0, midpoint + 1.0)])
	RenderingServer.canvas_item_add_polyline(canvas, tick,
			PackedColorArray([border_color]), maxf(1.0, _stroke_width() - 1.0), true)


func _draw_sketch(canvas: RID, rect: Rect2) -> void:
	var color := Color(border_color, border_color.a * 0.22)
	# A second short pen pass is deliberately incomplete; interiors stay quiet.
	var loose := PackedVector2Array()
	for index in range(2, mini(15, _mesh_points.size())):
		loose.append(rect.position + _mesh_points[index]
				+ Vector2(sin(float(index) * 0.71 + float(variant)) * 0.6, 1.4))
	if loose.size() >= 2:
		RenderingServer.canvas_item_add_polyline(canvas, loose,
				PackedColorArray([color]), 1.0, true)
	var corner := Vector2(rect.position.x + minf(softness, rect.size.x * 0.18), rect.end.y - 8.0)
	for index in 2:
		var start := corner + Vector2(float(index) * 5.0, -float(index % 2))
		RenderingServer.canvas_item_add_line(canvas, start, start + Vector2(5.0, -4.0), color, 0.9, true)


func _stroke_width() -> float:
	return (stroke_widths.x + stroke_widths.y + stroke_widths.z + stroke_widths.w) * 0.25


func _update_mesh(size: Vector2) -> void:
	if size == _mesh_size and int(shape) == _mesh_shape and variant == _mesh_variant \
			and softness == _mesh_softness:
		return
	_mesh_size = size
	_mesh_shape = int(shape)
	_mesh_variant = variant
	_mesh_softness = softness
	_mesh_points = _local_outline(size)
	_mesh_triangles = Geometry2D.triangulate_polygon(_mesh_points) if _mesh_points.size() >= 3 \
			else PackedInt32Array()


func _offset(points: PackedVector2Array, amount: Vector2) -> PackedVector2Array:
	var result := points.duplicate()
	for index in result.size():
		result[index] += amount
	return result


func _local_outline(size: Vector2) -> PackedVector2Array:
	if not size.is_finite() or minf(size.x, size.y) < 0.75:
		return PackedVector2Array()
	if shape == Shape.OVAL or shape == Shape.BLOB:
		return _oval(size)
	return _paper(size)


func _oval(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half := size * 0.5
	var seed := float(posmod(variant, 19)) * 0.41
	var uneven := 0.035 if shape == Shape.BLOB else 0.009
	for index in 56:
		var angle := TAU * float(index) / 56.0
		var wave := 1.0 + sin(angle * 3.0 + seed) * uneven + cos(angle * 5.0 - seed) * uneven * 0.45
		var point := half + Vector2(cos(angle), sin(angle)) * (half * 0.91) * wave
		points.append(point)
	return points


func _paper(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inset := minf(1.5, minf(size.x, size.y) * 0.035)
	var left := inset
	var top := inset
	var right := size.x - inset
	var bottom := size.y - inset
	var height := bottom - top
	var width := right - left
	var radius := minf(softness, minf(width, height) * 0.38)
	if shape == Shape.TAG:
		radius = minf(width, height) * 0.46
	var seed := float(posmod(variant, 23)) * 0.37
	var bulge := minf(2.8, minf(width, height) * 0.055)
	var tilt := sin(seed + 0.7) * bulge * 0.45
	var r0 := radius * (0.93 + sin(seed + 0.3) * 0.07)
	var r1 := radius * (0.93 + cos(seed + 1.1) * 0.07)
	var r2 := radius * (0.93 + sin(seed + 2.2) * 0.07)
	var r3 := radius * (0.93 + cos(seed + 3.1) * 0.07)
	var anchors := PackedVector2Array([
		Vector2(left + r0, top + tilt), Vector2(right - r1, top - tilt),
		Vector2(right, top + r1), Vector2(right, bottom - r2),
		Vector2(right - r2, bottom - tilt), Vector2(left + r3, bottom + tilt),
		Vector2(left, bottom - r3), Vector2(left, top + r0),
	])
	var controls: Array[Vector2] = [
		anchors[0] + Vector2((anchors[1].x - anchors[0].x) / 3.0, -bulge),
		anchors[1] - Vector2((anchors[1].x - anchors[0].x) / 3.0, bulge * 0.4),
		anchors[1] + Vector2(r1 * 0.67, 0.0), anchors[2] - Vector2(0.0, r1 * 0.67),
		anchors[2] + Vector2(bulge * 0.45, (anchors[3].y - anchors[2].y) / 3.0),
		anchors[3] - Vector2(-bulge * 0.65, (anchors[3].y - anchors[2].y) / 3.0),
		anchors[3] + Vector2(0.0, r2 * 0.67), anchors[4] + Vector2(r2 * 0.67, 0.0),
		anchors[4] - Vector2((anchors[4].x - anchors[5].x) / 3.0, -bulge * 0.5),
		anchors[5] + Vector2((anchors[4].x - anchors[5].x) / 3.0, bulge * 0.6),
		anchors[5] - Vector2(r3 * 0.67, 0.0), anchors[6] + Vector2(0.0, r3 * 0.67),
		anchors[6] - Vector2(bulge * 0.6, (anchors[6].y - anchors[7].y) / 3.0),
		anchors[7] + Vector2(-bulge * 0.35, (anchors[6].y - anchors[7].y) / 3.0),
		anchors[7] - Vector2(0.0, r0 * 0.67), anchors[0] - Vector2(r0 * 0.67, 0.0),
	]
	for segment in 8:
		for step in STEPS:
			var t := float(step) / float(STEPS)
			var one := 1.0 - t
			points.append(anchors[segment] * one * one * one
				+ controls[segment * 2] * (3.0 * one * one * t)
				+ controls[segment * 2 + 1] * (3.0 * one * t * t)
				+ anchors[(segment + 1) % 8] * t * t * t)
	return points
