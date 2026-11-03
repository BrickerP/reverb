class_name EchoPortrait
extends Control

const EXTENT := Vector2(88, 102)
var condition := 1.0
var merged := false
var reduced_effects := false
var _texture: Texture2D
var _region := Rect2()
var _tint := Color.WHITE
var _route := PackedVector2Array()
var _weapons: Array[Dictionary] = []
var _phase := 0.0
var _intro := 1.0
var _meter_stock: StyleBox


func _init() -> void:
	custom_minimum_size = EXTENT
	_meter_stock = UiTheme.box(UiTheme.SURFACE, UiTheme.INK, 1, 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func setup(take: EchoTake, character: StringName, reduced: bool = false, arriving: bool = false) -> void:
	_intro = 0.0 if arriving and not reduced else 1.0
	condition = clampf(take.condition / 100.0, 0.0, 1.0)
	merged = take.merged
	reduced_effects = reduced
	_tint = take.tint()
	_phase = float(take.uid % 7)
	var key := PresentationAssets.character_key(character)
	_texture = PresentationAssets.texture(key)
	_region = PresentationAssets.idle_region(key)
	_route = _fit_route(take.samples)
	_weapons.clear()
	for weapon: WeaponDef in take.weapons.slice(0, 3):
		var weapon_key := PresentationAssets.weapon_key(weapon)
		_weapons.append({"texture": PresentationAssets.texture(weapon_key),
			"region": PresentationAssets.idle_region(weapon_key)})
	set_process(not reduced)
	queue_redraw()


func is_animating() -> bool:
	return _intro < 1.0


func finish_immediately() -> void:
	_intro = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_phase += delta
		_intro = minf(1.0, _intro + delta / 0.8)
		queue_redraw()


func _draw() -> void:
	var shift := (size - EXTENT) * Vector2(0.5, 0.0)
	draw_set_transform(shift)
	if _route.size() >= 2:
		var count := maxi(2, ceili(_intro * float(_route.size())))
		draw_polyline(_route.slice(0, mini(count, _route.size())), Color(_tint.lerp(UiTheme.INK, 0.5), 0.28), 1.6, true)
		var progress := fposmod(_phase * 0.24, 1.0) if not reduced_effects else 0.65
		var index := mini(_route.size() - 1, int(progress * float(_route.size())))
		draw_circle(_route[index], 2.6, Color(_tint.lerp(UiTheme.INK, 0.35), 0.8))
	if _texture != null and _region.has_area():
		var extent := Vector2(58, 69) * Vector2(1.0, 0.83 + condition * 0.17)
		var scale := minf(extent.x / _region.size.x, extent.y / _region.size.y)
		var fitted := _region.size * scale
		var breath := 0.0 if reduced_effects else sin(_phase * 1.6) * 0.65
		var rect := Rect2(Vector2(44 - fitted.x * 0.5, 73 - fitted.y + breath), fitted)
		draw_texture_rect_region(_texture, Rect2(rect.position + Vector2(2, 0), rect.size),
				_region, Color(_tint, 0.27))
		draw_texture_rect_region(_texture, rect, _region,
				Color.WHITE.lerp(_tint, 0.18).lerp(Color(0.62, 0.58, 0.5), (1.0 - condition) * 0.22))
		if condition < 0.35:
			draw_polyline(PackedVector2Array([Vector2(32, 40), Vector2(43, 45),
				Vector2(37, 53), Vector2(51, 60)]), UiTheme.WARN, 2.0, true)
		if merged:
			_draw_staple(Vector2(54, 28))
	for i in _weapons.size():
		var row: Dictionary = _weapons[i]
		var region: Rect2 = row["region"]
		var texture := row["texture"] as Texture2D
		if texture != null and region.has_area():
			var cell := Rect2(11 + float(i) * 23.0, 69, 22, 16)
			var k := minf(cell.size.x / region.size.x, cell.size.y / region.size.y)
			var extent := region.size * k
			draw_texture_rect_region(texture, Rect2(cell.get_center() - extent * 0.5, extent), region)
	var meter := Rect2(4, 89, 80, 10)
	draw_style_box(_meter_stock, meter)
	if condition > 0.0:
		var fill := Rect2(meter.position + Vector2.ONE * 2.0, Vector2((meter.size.x - 4) * condition, 6))
		draw_rect(fill, UiTheme.WARN if condition < 0.25 else _tint.lerp(UiTheme.ACCENT, 0.5))
	for x: float in [0.25, 0.5, 0.75]:
		draw_line(Vector2(meter.position.x + meter.size.x * x, 91),
			Vector2(meter.position.x + meter.size.x * x, 97), Color(UiTheme.INK, 0.35), 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_staple(at: Vector2) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(0, 5), at, at + Vector2(13, -2),
		at + Vector2(13, 3)]), UiTheme.INK, 2.0, true)


static func _fit_route(samples: PackedVector2Array) -> PackedVector2Array:
	if samples.is_empty():
		return PackedVector2Array()
	var low := samples[0]
	var high := samples[0]
	for point in samples:
		low = low.min(point)
		high = high.max(point)
	var span := high - low
	var scale := minf(72.0 / maxf(1.0, span.x), 58.0 / maxf(1.0, span.y))
	var offset := Vector2(44, 40) - span * scale * 0.5
	var result := PackedVector2Array()
	var stride := maxi(1, ceili(float(samples.size()) / 50.0))
	for index in range(0, samples.size(), stride):
		result.append(offset + (samples[index] - low) * scale)
	return result
