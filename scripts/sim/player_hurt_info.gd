class_name PlayerHurtInfo
extends RefCounted

var source: StringName
var amount: float = 0.0
var absorbed: float = 0.0
var pos: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var effect: StringName = &"contact"
var lethal: bool = false


func to_dict() -> Dictionary:
	return {
		"source": String(source),
		"amount": amount,
		"absorbed": absorbed,
		"pos": [pos.x, pos.y],
		"direction": [direction.x, direction.y],
		"effect": String(effect),
		"lethal": lethal,
	}
