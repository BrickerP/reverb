class_name EnemyDeathInfo
extends RefCounted

# Immutable-by-convention snapshot emitted at the actual kill boundary. Presentation
# copies these values; it never needs to retain an EnemyState after compaction.
var target_uid: int = -1
var enemy_id: StringName
var pos := Vector2.ZERO
var radius: float = 0.0
var color := Color.WHITE
var elite_kind: StringName
var source: int = -1
var actor_token: int = -1
var source_tint := Color.WHITE
var weapon_id: StringName
var hit_dir := Vector2.ZERO
var facing := Vector2.RIGHT
var effect: StringName = &"hit"
var boss_phase: int = 0
var boss_shard_index: int = -1


func to_dict() -> Dictionary:
	return {"target_uid": target_uid, "enemy_id": String(enemy_id),
		"pos": [pos.x, pos.y], "radius": radius,
		"color": [color.r, color.g, color.b, color.a], "elite_kind": String(elite_kind),
		"source": source, "actor_token": actor_token,
		"source_tint": [source_tint.r, source_tint.g, source_tint.b, source_tint.a],
		"weapon_id": String(weapon_id), "hit_dir": [hit_dir.x, hit_dir.y],
		"facing": [facing.x, facing.y], "effect": String(effect),
		"boss_phase": boss_phase, "boss_shard_index": boss_shard_index}
