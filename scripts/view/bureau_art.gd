class_name BureauArt
extends RefCounted

const FACILITIES_PATH := "res://assets/presentation/bureau/facilities.png"
const BINDING_PATH := "res://assets/presentation/bureau/binding.png"
const FACILITY_IDS: Array[StringName] = [&"vending_closed", &"vending_open", &"copier_closed", &"copier_print", &"stamp_raised", &"stamp_down", &"inbox", &"cabinet"]
const GRID := Vector2i(4, 2)


static func facility_texture() -> Texture2D:
	return PresentationAssets.texture(&"bureau_vending_closed")


static func binding_texture() -> Texture2D:
	return PresentationAssets.texture(&"bureau_binding")


static func facility_region(id: StringName) -> Rect2:
	var index := FACILITY_IDS.find(id)
	var texture := facility_texture()
	return _cell(texture, index) if index >= 0 else Rect2()


static func binding_region(frame: int) -> Rect2:
	return PresentationAssets.frame_region(&"bureau_binding", clampi(frame, 0, 7))


static func draw_facility(ci: CanvasItem, id: StringName, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	_draw(ci, facility_texture(), facility_region(id), rect, modulate)


static func draw_binding(ci: CanvasItem, frame: int, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	_draw(ci, binding_texture(), binding_region(frame), rect, modulate)


static func _cell(texture: Texture2D, index: int) -> Rect2:
	if texture == null or index < 0:
		return Rect2()
	var cell := texture.get_size() / Vector2(GRID)
	return Rect2(Vector2(index % GRID.x, int(index / GRID.x)) * cell, cell)


static func _draw(ci: CanvasItem, texture: Texture2D, source: Rect2, rect: Rect2, modulate: Color) -> void:
	if ci == null or texture == null or source.size.x <= 0.0 or source.size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var scale := minf(rect.size.x / source.size.x, rect.size.y / source.size.y)
	var target := Rect2(rect.get_center() - source.size * scale * 0.5, source.size * scale)
	ci.draw_texture_rect_region(texture, target, source, modulate)
