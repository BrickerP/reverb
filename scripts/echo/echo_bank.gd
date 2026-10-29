class_name EchoBank
extends RefCounted

const MERGE_TRAITS: Array[StringName] = [&"skill", &"repair", &"power"]
const POWER_CONDITION_COST := 15.0

var takes: Array[EchoTake] = []
var _tint_counter: int = 0
var _next_uid: int = 1


func add(take: EchoTake) -> void:
	if take == null or takes.has(take):
		return
	take.uid = _next_uid
	_next_uid += 1
	take.tint_index = _tint_counter
	_tint_counter += 1
	takes.append(take)


func set_tint_counter(value: int) -> void:
	_tint_counter = maxi(0, value)


func tint_counter() -> int:
	return _tint_counter


func next_uid() -> int:
	return _next_uid


func set_next_uid(value: int) -> void:
	_next_uid = maxi(1, value)
	for take in takes:
		_next_uid = maxi(_next_uid, take.uid + 1)


func find_uid(uid: int) -> EchoTake:
	for take in takes:
		if take.uid == uid:
			return take
	return null


# The host keeps its complete route and build. The donor buys exactly one donor_trait.
# Preview is a detached value: neither identity counters nor the inputs are touched.
func preview_merge(a: EchoTake, b: EchoTake, donor_trait: StringName = &"skill") -> EchoTake:
	if a == null or b == null or a == b or not MERGE_TRAITS.has(donor_trait):
		return null
	if not takes.has(a) or not takes.has(b) or a.weapons.is_empty() or b.weapons.is_empty():
		return null
	if not is_finite(a.condition) or not is_finite(b.condition) or a.condition <= 0.0 or b.condition <= 0.0:
		return null
	var out := a.copy()
	out.tint_index = _tint_counter
	out.merged = true
	out.merge_trait = donor_trait
	match donor_trait:
		&"skill":
			out.inherited_skill = b.retirement_kind()
			out.condition = minf(a.condition, b.condition)
		&"repair":
			if a.condition >= 100.0:
				return null
			out.condition = minf(100.0, a.condition + b.condition * 0.5)
		&"power":
			if minf(a.condition, b.condition) <= POWER_CONDITION_COST:
				return null
			var index := -1
			var strongest := -1.0
			for i in out.weapons.size():
				if out.level_at(i) < WeaponDef.MAX_LEVEL and out.weapons[i].level_dps(out.level_at(i)) > strongest:
					index = i
					strongest = out.weapons[i].level_dps(out.level_at(i))
			if index < 0:
				return null
			while out.levels.size() < out.weapons.size():
				out.levels.append(0)
			out.levels[index] += 1
			out.condition = minf(a.condition, b.condition) - POWER_CONDITION_COST
	return out


func merge(a: EchoTake, b: EchoTake, donor_trait: StringName = &"skill") -> EchoTake:
	var out := preview_merge(a, b, donor_trait)
	if out == null:
		return null
	takes.erase(a)
	takes.erase(b)
	add(out)
	return out


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
