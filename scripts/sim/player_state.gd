class_name PlayerState
extends RefCounted

const RADIUS := 12.0

var pos: Vector2 = Vector2.ZERO
var hp: float = 1.0
var stats: Stats = Stats.new()
var weapons: Array[WeaponDef] = []
var weapon_levels: Array[int] = []
var cooldowns: Array[float] = []
var items: Dictionary = {}
var materials: int = 0
var iframes: float = 0.0
var facing: Vector2 = Vector2.RIGHT


func max_hp() -> float:
	return stats.get_stat(Stats.MAX_HP)


func add_weapon(w: WeaponDef) -> void:
	# Tests and the crowd tool clear `weapons` directly; keep the parallel level array aligned.
	while weapon_levels.size() < weapons.size():
		weapon_levels.append(0)
	if weapon_levels.size() > weapons.size():
		weapon_levels.resize(weapons.size())
	weapons.append(w)
	weapon_levels.append(0)
	cooldowns.append(0.0)


func level_at(index: int) -> int:
	return weapon_levels[index] if index >= 0 and index < weapon_levels.size() else 0


func upgrade_weapon(index: int) -> bool:
	if index < 0 or index >= weapons.size():
		return false
	var level := level_at(index)
	while weapon_levels.size() <= index:
		weapon_levels.append(0)
	if level >= WeaponDef.MAX_LEVEL:
		return false
	weapon_levels[index] = level + 1
	return true


func item_count(id: StringName) -> int:
	return int(items.get(id, 0))


func add_item(it: ItemDef) -> void:
	items[it.id] = item_count(it.id) + 1
	for stat: StringName in it.mods:
		stats.add(stat, float(it.mods[stat]))
	if it.mods.has(Stats.MAX_HP):
		hp += float(it.mods[Stats.MAX_HP])
