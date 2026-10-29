class_name EchoSilenceInfo
extends RefCounted

const CONTACT: StringName = &"contact"
const BOSS: StringName = &"boss"
const PHASE: StringName = &"phase"

var duration: float = 0.0
var kind: StringName = CONTACT
var source_uid: int = -1
var enemy_id: StringName
var pos := Vector2.ZERO


func to_dict() -> Dictionary:
	return {"duration": duration, "kind": String(kind), "source_uid": source_uid,
		"enemy_id": String(enemy_id), "pos": [pos.x, pos.y]}
