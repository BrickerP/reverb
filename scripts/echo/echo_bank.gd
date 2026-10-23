class_name EchoBank
extends RefCounted

const MAX_MERGED_WEAPONS := 8
const BRIDGE_SAMPLES := 12

var takes: Array[EchoTake] = []
var _tint_counter: int = 0


func add(take: EchoTake) -> void:
	take.tint_index = _tint_counter
	_tint_counter += 1
	take.age = 0
	takes.append(take)


# Overdub: two takes become one echo that walks both recorded routes and keeps both loadouts.
func merge(a: EchoTake, b: EchoTake) -> EchoTake:
	if a == null or b == null or a == b:
		return null
	if not takes.has(a) or not takes.has(b):
		return null
	var out := EchoTake.new()
	out.wave = maxi(a.wave, b.wave)
	out.samples = _join(a.samples, b.samples)
	var loadout := _best_loadout(a, b)
	var best_weapons: Array = loadout[0]
	var best_levels: Array = loadout[1]
	for w: Variant in best_weapons:
		out.weapons.append(w as WeaponDef)
	for level: Variant in best_levels:
		out.levels.append(int(level))
	out.stats = (a.stats if a.power() >= b.power() else b.stats).copy()
	var keep_age := maxi(a.age, b.age)
	takes.erase(a)
	takes.erase(b)
	add(out)
	out.age = keep_age
	out.merged = true
	return out


func _join(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	if a.is_empty():
		return b.duplicate()
	if b.is_empty():
		return a.duplicate()
	var out := a.duplicate()
	for i in BRIDGE_SAMPLES:
		out.append(a[a.size() - 1].lerp(b[0], float(i + 1) / float(BRIDGE_SAMPLES)))
	out.append_array(b)
	return out


func _best_loadout(a: EchoTake, b: EchoTake) -> Array:
	var entries: Array[Dictionary] = []
	for i in a.weapons.size():
		entries.append({"weapon": a.weapons[i], "level": a.level_at(i)})
	for i in b.weapons.size():
		entries.append({"weapon": b.weapons[i], "level": b.level_at(i)})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return (x["weapon"] as WeaponDef).level_dps(x["level"]) > (y["weapon"] as WeaponDef).level_dps(y["level"]))
	var weapons: Array[WeaponDef] = []
	var levels: Array[int] = []
	for entry: Dictionary in entries.slice(0, mini(MAX_MERGED_WEAPONS, entries.size())):
		weapons.append(entry["weapon"])
		levels.append(int(entry["level"]))
	return [weapons, levels]


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
