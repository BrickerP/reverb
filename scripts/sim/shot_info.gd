class_name ShotInfo
extends RefCounted

var source: int = -1
var actor_token: int = -1
var source_tint := Color.WHITE
var weapon_id: StringName
# Only the triggering loadout slot is captured by the release event. Delayed burst
# state has no slot in snapshot v4; delayed/support output stays -1 rather than
# guessing among duplicate IDs or losing cosmetic attribution after resume.
var weapon_slot: int = -1
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var target: Vector2 = Vector2.ZERO
var count: int = 1
var level: int = 0
var sequence: int = 0


func to_dict() -> Dictionary:
	return {
		"source": source,
		"actor_token": actor_token,
		"source_tint": [source_tint.r, source_tint.g, source_tint.b, source_tint.a],
		"weapon_id": String(weapon_id),
		"weapon_slot": weapon_slot,
		"origin": [origin.x, origin.y],
		"direction": [direction.x, direction.y],
		"target": [target.x, target.y],
		"count": count,
		"level": level,
		"sequence": sequence,
	}
