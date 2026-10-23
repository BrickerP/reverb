class_name WeaponChangeInfo
extends RefCounted

var index: int = -1
var before_id: StringName
var after_id: StringName
var before_level: int = 0
var after_level: int = 0
var reason: StringName = &""
var ok: bool = false


func to_dict() -> Dictionary:
	return {
		"index": index,
		"before_id": String(before_id),
		"after_id": String(after_id),
		"before_level": before_level,
		"after_level": after_level,
		"reason": String(reason),
		"ok": ok,
	}
