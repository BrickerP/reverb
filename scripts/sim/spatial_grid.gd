class_name SpatialGrid
extends RefCounted

const CELL := 48.0

var _cells: Dictionary = {}


func clear() -> void:
	_cells.clear()


func insert(e: EnemyState) -> void:
	var key := _key(int(floor(e.pos.x / CELL)), int(floor(e.pos.y / CELL)))
	if _cells.has(key):
		(_cells[key] as Array).append(e)
	else:
		_cells[key] = [e]


func query(pos: Vector2, r: float, out: Array) -> void:
	var x0 := int(floor((pos.x - r) / CELL))
	var x1 := int(floor((pos.x + r) / CELL))
	var y0 := int(floor((pos.y - r) / CELL))
	var y1 := int(floor((pos.y + r) / CELL))
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := _key(cx, cy)
			if _cells.has(key):
				out.append_array(_cells[key])


static func _key(cx: int, cy: int) -> int:
	return (cx + 2048) * 8192 + (cy + 2048)
