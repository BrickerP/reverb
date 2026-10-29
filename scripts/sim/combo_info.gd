class_name ComboInfo
extends RefCounted

var id: StringName
var source: int = -1
var actor_token: int = -1
var source_tint := Color.WHITE
var weapon_id: StringName
var target_uid: int = 0
var pos := Vector2.ZERO
var affected: int = 0
var bonus_damage: float = 0.0


func to_dict() -> Dictionary:
	return {"id": String(id), "source": source, "actor_token": actor_token,
		"source_tint": [source_tint.r, source_tint.g, source_tint.b, source_tint.a],
		"weapon_id": String(weapon_id), "target_uid": target_uid,
		"pos": [pos.x, pos.y], "affected": affected, "bonus_damage": bonus_damage}
