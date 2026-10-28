class_name PathPreview
extends Control

const PREVIEW_SIZE := Vector2(76.0, 48.0)
const STRIDE := 6
const TRACE_TIME := 0.8

var _points: PackedVector2Array = PackedVector2Array()
var _tint: Color = Color.WHITE
var _progress: float = 1.0


func _init() -> void:
	custom_minimum_size = PREVIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(take: EchoTake, animate: bool = false) -> void:
	_tint = take.tint().lerp(UiTheme.INK, 0.4)
	var k := PREVIEW_SIZE.x / Sim.ARENA.size.x
	_points = PackedVector2Array()
	for i in range(0, take.samples.size(), STRIDE):
		_points.append(take.samples[i] - Sim.ARENA.position)
	for i in _points.size():
		_points[i] = _points[i] * k
	_progress = 0.0 if animate else 1.0
	set_process(animate)
	queue_redraw()


func is_animating() -> bool:
	return _progress < 1.0


func finish_immediately() -> void:
	_progress = 1.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_progress = minf(1.0, _progress + delta / TRACE_TIME)
	if _progress >= 1.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, PREVIEW_SIZE)
	draw_rect(frame, UiTheme.PAPER)
	if _points.size() >= 2:
		if _progress < 1.0:
			# Faint full route, then the tape draws itself in.
			draw_polyline(_points, Color(_tint, 0.14), 1.0, true)
			var keep := clampi(int(ceil(_progress * float(_points.size() - 1))) + 1, 1, _points.size())
			var shown := _points.slice(0, keep)
			if shown.size() >= 2:
				draw_polyline(shown, Color(_tint, 0.95), 1.5, true)
			draw_circle(shown[shown.size() - 1], 2.5, Color(_tint, 1.0))
		else:
			draw_polyline(_points, Color(_tint, 0.9), 1.5, true)
	if not _points.is_empty():
		draw_circle(_points[0], 3.0, UiTheme.INK)
	draw_rect(frame, UiTheme.EDGE, false, 2.0)
