class_name ArenaBackdrop
extends Node2D

# Static parts of the arena (fill, grid, border). Drawn once and left alone; ArenaView only
# redraws the moving actors on top of it.


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	ArenaPainter.arena(self)
