class_name EchoActor
extends RefCounted

var take: EchoTake
var index: int = 0
var t: float = 0.0
var pos: Vector2 = Vector2.ZERO
var rewinding: bool = false
var cooldowns: Array[float] = []


func _init(source: EchoTake, slot: int) -> void:
	take = source
	index = slot
	pos = take.position_at(0.0)
	for _w in take.weapons:
		cooldowns.append(0.0)


func step(delta: float) -> void:
	t += delta
	pos = take.position_at(t)
	rewinding = take.is_rewinding(t)
