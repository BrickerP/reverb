class_name PathPreview
extends Control

const PREVIEW_SIZE := Vector2(112.0, 56.0)
const STRIDE := 6

var _points: PackedVector2Array = PackedVector2Array()
var _tint: Color = Color.WHITE


func _init() -> void:
	custom_minimum_size = PREVIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(take: EchoTake) -> void:
	_tint = take.tint()
	var k := PREVIEW_SIZE.x / Sim.ARENA.size.x
	_points = PackedVector2Array()
	for i in range(0, take.samples.size(), STRIDE):
		_points.append((take.samples[i] - Sim.ARENA.position) * k)
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, PREVIEW_SIZE)
	draw_rect(frame, Color(0.02, 0.03, 0.08))
	if _points.size() >= 2:
		draw_polyline(_points, Color(_tint, 0.9), 1.5, true)
	if not _points.is_empty():
		draw_circle(_points[0], 3.0, Color.WHITE)
	draw_rect(frame, Color(_tint, 0.7), false, 1.5)
