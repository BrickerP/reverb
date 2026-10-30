class_name ArenaBackdrop
extends Node2D

# The quiet floor stays static. A single child draws shallow edge landmarks at
# a restrained rate instead of redrawing the full floor with every belt tick.

var _depot: RecyclingDepot


func _ready() -> void:
	_ensure_depot()
	queue_redraw()


func _draw() -> void:
	ArenaPainter.arena(self)


func set_presentation(time: float, reduced: bool, paused: bool) -> void:
	_ensure_depot()
	_depot.set_presentation(time, reduced, paused)


func set_world_profile(profile: Dictionary) -> void:
	_ensure_depot()
	_depot.set_world_profile(profile)


func _ensure_depot() -> void:
	if _depot != null:
		return
	_depot = RecyclingDepot.new()
	add_child(_depot)
	_depot.set_presentation(0.0, false, false)
