class_name EchoRecorder
extends RefCounted

var samples: PackedVector2Array = PackedVector2Array()
var _acc: float = 0.0


func begin(start: Vector2) -> void:
	samples = PackedVector2Array([start])
	_acc = 0.0


func record(pos: Vector2, delta: float) -> void:
	_acc += delta
	while _acc >= EchoTake.SAMPLE_DT:
		_acc -= EchoTake.SAMPLE_DT
		samples.append(pos)


func finish(wave: int, weapons: Array[WeaponDef], stats: Stats) -> EchoTake:
	var take := EchoTake.new()
	take.samples = samples.duplicate()
	take.weapons = weapons.duplicate()
	take.stats = stats.copy()
	take.wave = wave
	return take
