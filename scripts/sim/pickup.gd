class_name Pickup
extends RefCounted

const SUPPLY_LIFETIME := 8.0

var pos: Vector2 = Vector2.ZERO
var value: int = 1
var speed: float = 0.0
var magnet: bool = false
var kind: StringName = &"scrap"
var life: float = 0.0
