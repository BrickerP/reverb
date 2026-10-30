class_name BureauFacilityUi
extends Control

var facility: StringName = &"cabinet"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_facility(id: StringName) -> void:
	facility = id
	queue_redraw()


func _draw() -> void:
	BureauArt.draw_facility(self, facility, Rect2(Vector2.ZERO, size))
