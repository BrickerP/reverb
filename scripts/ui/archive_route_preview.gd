class_name ArchiveRoutePreview
extends Control

var _points := PackedVector2Array()
var _world_points := PackedVector2Array()
var view := WorldArena.BOUNDS
var _tint := UiTheme.ECHO
var _scale: Label
var _extent := Vector2(170.0, 100.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale = UiTheme.label("", 11, UiTheme.DIM)
	add_child(_scale)


func setup(take: EchoTake, extent := Vector2(170.0, 100.0)) -> void:
	_extent = extent
	custom_minimum_size = extent
	_world_points = take.samples.duplicate()
	_tint = take.tint().lerp(UiTheme.INK, 0.4)
	if take.samples.is_empty():
		_points.clear()
		_scale.text = ""
		queue_redraw()
		return
	var low := take.samples[0]
	var high := low
	for point in take.samples:
		low = low.min(point)
		high = high.max(point)
	var drawing := Vector2(extent.x, extent.y - 18.0)
	var span := (high - low + Vector2(120.0, 120.0)).max(Vector2(320.0, 160.0))
	var ratio := drawing.x / drawing.y
	span.x = maxf(span.x, span.y * ratio)
	span.y = maxf(span.y, span.x / ratio)
	span = span.min(WorldArena.BOUNDS.size)
	var origin := ((low + high - span) * 0.5).clamp(WorldArena.BOUNDS.position, WorldArena.BOUNDS.end - span)
	view = Rect2(origin, span)
	_points = PackedVector2Array()
	var stride := maxi(1, ceili(float(take.samples.size()) / 160.0))
	for i in range(0, take.samples.size(), stride):
		_points.append(_map(take.samples[i], drawing))
	if _points[-1] != _map(take.samples[-1], drawing):
		_points.append(_map(take.samples[-1], drawing))
	_scale.text = Loc.t("archive.route_scale", [roundi(view.size.x), roundi(view.size.y)])
	_scale.position = Vector2(0.0, extent.y - 16.0)
	queue_redraw()


func _map(point: Vector2, drawing: Vector2) -> Vector2:
	return (point - view.position) / view.size * drawing


func _draw() -> void:
	var drawing := Vector2(_extent.x, _extent.y - 18.0)
	draw_rect(Rect2(Vector2.ZERO, drawing), Color(UiTheme.INK, 0.05))
	for machine: Rect2 in WorldArena.MACHINES:
		var visible_machine := machine.intersection(view)
		if visible_machine.has_area():
			draw_rect(Rect2(_map(visible_machine.position, drawing), visible_machine.size / view.size * drawing), Color(UiTheme.INK, 0.16))
	if _points.size() > 1:
		draw_polyline(_points, _tint, 2.0, true)
	if not _points.is_empty():
		draw_circle(_points[0], 3.5, UiTheme.INK)
		draw_circle(_points[-1], 2.0, UiTheme.COIN)
	# Full-world inset locates the honest local view; a stationary route stays a dot.
	var inset := Rect2(Vector2(_extent.x - 52.0, 3.0), Vector2(48.0, 24.0))
	draw_rect(inset, UiTheme.PAPER)
	draw_rect(inset, Color(UiTheme.INK, 0.5), false)
	var crop := Rect2(inset.position + (view.position - WorldArena.BOUNDS.position) / WorldArena.BOUNDS.size * inset.size,
		view.size / WorldArena.BOUNDS.size * inset.size)
	draw_rect(crop, _tint, false)
