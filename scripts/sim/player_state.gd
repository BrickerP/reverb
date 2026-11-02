class_name PlayerState
extends RefCounted

const RADIUS := 12.0
# Default paper is 58px tall and planted on the foot, which sits one radius
# below the collider. The chest is 45% of that height above the foot.
const ART_HEIGHT := 58.0
const CHEST_LIFT := 0.45 * ART_HEIGHT - RADIUS


static func chest(body: Vector2) -> Vector2:
	return body + Vector2(0.0, -CHEST_LIFT)

var pos: Vector2 = Vector2.ZERO
var hp: float = 1.0
var shield: float = 0.0
var stats: Stats = Stats.new()
var weapons: Array[WeaponDef] = []
var weapon_levels: Array[int] = []
var weapon_investments: Array[int] = []
var cooldowns: Array[float] = []
var items: Dictionary = {}
var set_bonus_applied: Dictionary = {}
var materials: int = 0
var iframes: float = 0.0
var facing: Vector2 = Vector2.RIGHT


func max_hp() -> float:
	return stats.get_stat(Stats.MAX_HP)


func max_shield() -> float:
	return maxf(0.0, stats.get_stat(Stats.SHIELD))


func add_weapon(w: WeaponDef) -> void:
	# Tests and the crowd tool clear `weapons` directly; keep the parallel level array aligned.
	while weapon_levels.size() < weapons.size():
		weapon_levels.append(0)
	if weapon_levels.size() > weapons.size():
		weapon_levels.resize(weapons.size())
	while weapon_investments.size() < weapons.size():
		weapon_investments.append(0)
	if weapon_investments.size() > weapons.size():
		weapon_investments.resize(weapons.size())
	weapon_investments.append(0)
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
	_apply_item_sets()


func _apply_item_sets() -> void:
	for set_id: StringName in Content.item_sets():
		if bool(set_bonus_applied.get(set_id, false)):
			continue
		var data: Dictionary = Content.item_sets()[set_id]
		var count := 0
		for member: StringName in data.get("members", []):
			count += item_count(member)
		if count < int(data.get("required", 3)):
			continue
		var mods: Dictionary = data.get("mods", {})
		for stat: StringName in mods:
			var value := float(mods[stat])
			stats.add(stat, value)
			if stat == Stats.MAX_HP:
				hp += value
		set_bonus_applied[set_id] = true
