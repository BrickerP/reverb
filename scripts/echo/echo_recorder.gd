class_name EchoRecorder
extends RefCounted

var samples: PackedVector2Array = PackedVector2Array()
var work_actions: Array[Dictionary] = []
var _acc: float = 0.0
var _elapsed: float = 0.0


func begin(start: Vector2) -> void:
	samples = PackedVector2Array([start])
	work_actions.clear()
	_acc = 0.0
	_elapsed = 0.0


func record(pos: Vector2, delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta) or not pos.is_finite():
		return
	_elapsed += delta
	_acc += delta
	while _acc >= EchoTake.SAMPLE_DT:
		_acc -= EchoTake.SAMPLE_DT
		samples.append(pos)


func record_work(kind: StringName, target_id: StringName, pos: Vector2,
		weapon_id: StringName = &"", aim: Vector2 = Vector2.ZERO) -> bool:
	if samples.is_empty() or work_actions.size() >= EchoWork.MAX_ACTIONS:
		return false
	var action := {"time": _elapsed, "kind": kind, "target_id": target_id,
		"pos": pos, "weapon_id": weapon_id, "aim": aim}
	var candidate: Array[Dictionary] = []
	candidate.assign(work_actions)
	candidate.append(action)
	if not EchoWork.validate_actions(candidate, _elapsed):
		return false
	work_actions.append(action)
	return true


func finish(wave: int, weapons: Array[WeaponDef], stats: Stats, levels: Array[int] = []) -> EchoTake:
	var take := EchoTake.new()
	take.samples = samples.duplicate()
	take.work_actions.assign(work_actions.duplicate(true))
	# Work between 30 Hz samples still has its actual time, including the final
	# 16 ms of a short recording. One held endpoint gives that event a route.
	if not work_actions.is_empty() and float(work_actions.back().time) > take.duration():
		take.samples.append(samples[samples.size() - 1])
	take.weapons = weapons.duplicate()
	take.levels = levels.duplicate()
	while take.levels.size() < take.weapons.size():
		take.levels.append(0)
	if take.levels.size() > take.weapons.size():
		take.levels.resize(take.weapons.size())
	take.stats = stats.copy()
	take.wave = wave
	return take
