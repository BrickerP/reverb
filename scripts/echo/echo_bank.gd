class_name EchoBank
extends RefCounted

var takes: Array[EchoTake] = []
var _tint_counter: int = 0


func add(take: EchoTake) -> void:
	take.tint_index = _tint_counter
	_tint_counter += 1
	take.age = 0
	takes.append(take)


func age_after_wave(lifespan: int) -> Array[EchoTake]:
	var expired: Array[EchoTake] = []
	var kept: Array[EchoTake] = []
	for t in takes:
		t.age += 1
		if t.age >= lifespan:
			expired.append(t)
		else:
			kept.append(t)
	takes = kept
	return expired


func overflow(capacity: int) -> int:
	return maxi(0, takes.size() - capacity)


func discard(take: EchoTake) -> bool:
	var i := takes.find(take)
	if i < 0:
		return false
	takes.remove_at(i)
	return true


func weakest() -> EchoTake:
	var best: EchoTake = null
	for t in takes:
		if best == null or t.power() < best.power():
			best = t
	return best


func trim_to(capacity: int) -> Array[EchoTake]:
	var removed: Array[EchoTake] = []
	while takes.size() > capacity and not takes.is_empty():
		var w := weakest()
		takes.erase(w)
		removed.append(w)
	return removed
