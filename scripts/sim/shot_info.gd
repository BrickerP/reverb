class_name ShotInfo
extends RefCounted

var source: int = -1
var weapon_id: StringName
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var target: Vector2 = Vector2.ZERO
var count: int = 1
var level: int = 0
var sequence: int = 0


func to_dict() -> Dictionary:
	return {
		"source": source,
		"weapon_id": String(weapon_id),
		"origin": [origin.x, origin.y],
		"direction": [direction.x, direction.y],
		"target": [target.x, target.y],
		"count": count,
		"level": level,
		"sequence": sequence,
	}
