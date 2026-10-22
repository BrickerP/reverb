class_name PlayerState
extends RefCounted

const RADIUS := 12.0

var pos: Vector2 = Vector2.ZERO
var hp: float = 1.0
var stats: Stats = Stats.new()
var weapons: Array[WeaponDef] = []
var cooldowns: Array[float] = []
var items: Dictionary = {}
var materials: int = 0
var iframes: float = 0.0
var facing: Vector2 = Vector2.RIGHT


func max_hp() -> float:
	return stats.get_stat(Stats.MAX_HP)


func add_weapon(w: WeaponDef) -> void:
	weapons.append(w)
	cooldowns.append(0.0)


func item_count(id: StringName) -> int:
	return int(items.get(id, 0))


func add_item(it: ItemDef) -> void:
	items[it.id] = item_count(it.id) + 1
	for stat: StringName in it.mods:
		stats.add(stat, float(it.mods[stat]))
	if it.mods.has(Stats.MAX_HP):
		hp += float(it.mods[Stats.MAX_HP])
