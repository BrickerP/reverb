class_name ExplosionInfo
extends RefCounted

const WEAPON := &"weapon"
const BOMBER := &"bomber"

var kind: StringName = WEAPON
var source: int = -1
var actor_token: int = -1
var source_tint := Color.WHITE
var weapon_id: StringName
var pos: Vector2 = Vector2.ZERO
var radius: float = 0.0
var color: Color = Color.WHITE
var effect: StringName = &"explosion"


func to_dict() -> Dictionary:
	return {
		"kind": String(kind),
		"source": source,
		"actor_token": actor_token,
		"source_tint": [source_tint.r, source_tint.g, source_tint.b, source_tint.a],
		"weapon_id": String(weapon_id),
		"pos": [pos.x, pos.y],
		"radius": radius,
		"color": [color.r, color.g, color.b, color.a],
		"effect": String(effect),
	}
