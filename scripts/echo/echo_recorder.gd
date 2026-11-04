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
	var elapsed := _elapsed + delta
	var accumulator := _acc + delta
	if accumulator >= float(EchoTake.MAX_SAMPLES) * EchoTake.SAMPLE_DT:
		# A long frame can replace the whole window without allocating its history.
		_acc = fposmod(accumulator, EchoTake.SAMPLE_DT)
		_elapsed = float(EchoTake.MAX_SAMPLES - 1) * EchoTake.SAMPLE_DT + _acc
		work_actions = _rebase_work(work_actions, elapsed - _elapsed)
		samples.resize(EchoTake.MAX_SAMPLES)
		for index in EchoTake.MAX_SAMPLES:
			samples[index] = pos
		return
	_elapsed = elapsed
	_acc = accumulator
	var count := 0
	while _acc >= EchoTake.SAMPLE_DT:
		_acc -= EchoTake.SAMPLE_DT
		count += 1
	var evicted := maxi(0, samples.size() + count - EchoTake.MAX_SAMPLES)
	if evicted > 0:
		samples = samples.slice(evicted)
		var shift := float(evicted) * EchoTake.SAMPLE_DT
		_elapsed -= shift
		work_actions = _rebase_work(work_actions, shift)
	for _index in count:
		samples.append(pos)


static func _rebase_work(actions: Array[Dictionary], shift: float) -> Array[Dictionary]:
	var retained: Array[Dictionary] = []
	for action: Dictionary in actions:
		var time := float(action.time) - shift
		if time < 0.0:
			continue
		var rebased := action.duplicate()
		rebased["time"] = time
		retained.append(rebased)
	return retained


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
		if take.samples.size() == EchoTake.MAX_SAMPLES:
			take.samples = take.samples.slice(1)
			take.work_actions = _rebase_work(take.work_actions, EchoTake.SAMPLE_DT)
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
