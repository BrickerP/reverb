class_name DamageInfo
extends RefCounted

var source: int = -1
var actor_token: int = -1
var source_tint := Color.WHITE
var weapon_id: StringName
var target_uid: int = -1
var target_radius: float = 0.0
var pos: Vector2 = Vector2.ZERO
var amount: float = 0.0
var crit: bool = false
var reduced: bool = false
var hit_dir: Vector2 = Vector2.ZERO
var effect: StringName = &"hit"


func to_dict() -> Dictionary:
	return {
		"source": source,
		"actor_token": actor_token,
		"source_tint": [source_tint.r, source_tint.g, source_tint.b, source_tint.a],
		"weapon_id": String(weapon_id),
		"target_uid": target_uid,
		"target_radius": target_radius,
		"pos": [pos.x, pos.y],
		"amount": amount,
		"crit": crit,
		"reduced": reduced,
		"hit_dir": [hit_dir.x, hit_dir.y],
		"effect": String(effect),
	}
