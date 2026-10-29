class_name PathPreview
extends Control

const PREVIEW_SIZE := Vector2(45.0, 30.0)
const STRIDE := 6
const TRACE_TIME := 0.8

var _points: PackedVector2Array = PackedVector2Array()
var _tint: Color = Color.WHITE
var _progress: float = 1.0
var consumed := false


func _init() -> void:
	custom_minimum_size = PREVIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(take: EchoTake, animate: bool = false, extent: Vector2 = PREVIEW_SIZE) -> void:
	custom_minimum_size = extent
	_tint = take.tint().lerp(UiTheme.INK, 0.4)
	var k := minf(extent.x / Sim.ARENA.size.x, extent.y / Sim.ARENA.size.y)
	_points = PackedVector2Array()
	var stride := maxi(1, mini(STRIDE, ceili(float(take.samples.size()) / 120.0)))
	for i in range(0, take.samples.size(), stride):
		_points.append(take.samples[i] - Sim.ARENA.position)
	if not take.samples.is_empty() and (_points.is_empty() or _points[-1] != take.samples[-1] - Sim.ARENA.position):
		_points.append(take.samples[-1] - Sim.ARENA.position)
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
	if consumed:
		draw_line(Vector2(5.0, 5.0), size - Vector2(5.0, 5.0), Color(UiTheme.WARN, 0.8), 2.0, true)
		draw_line(Vector2(size.x - 5.0, 5.0), Vector2(5.0, size.y - 5.0), Color(UiTheme.WARN, 0.8), 2.0, true)
