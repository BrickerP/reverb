class_name PlayerHurtInfo
extends RefCounted

var source: StringName
var source_uid: int = -1
var amount: float = 0.0
var absorbed: float = 0.0
var hp_loss: float = 0.0
var hp_before: float = 0.0
var hp_after: float = 0.0
var shield_before: float = 0.0
var shield_after: float = 0.0
var pos: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var effect: StringName = &"contact"
var lethal: bool = false


func full_block() -> bool:
	return absorbed > 0.0 and amount <= 0.0


func to_dict() -> Dictionary:
	return {
		"source": String(source),
		"source_uid": source_uid,
		"amount": amount,
		"absorbed": absorbed,
		"hp_loss": hp_loss,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"shield_before": shield_before,
		"shield_after": shield_after,
		"pos": [pos.x, pos.y],
		"direction": [direction.x, direction.y],
		"effect": String(effect),
		"lethal": lethal,
	}
