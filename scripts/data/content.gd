class_name Content
extends RefCounted

const MAX_WEAPON_SLOTS := 6
const STARTER_WEAPON := &"pistol"

static var _weapons: Dictionary = {}
static var _items: Dictionary = {}
static var _enemies: Array[EnemyDef] = []


static func weapons() -> Dictionary:
	if _weapons.is_empty():
		_build_weapons()
	return _weapons


static func items() -> Dictionary:
	if _items.is_empty():
		_build_items()
	return _items


static func enemies() -> Array[EnemyDef]:
	if _enemies.is_empty():
		_build_enemies()
	return _enemies


static func weapon(id: StringName) -> WeaponDef:
	return weapons().get(id) as WeaponDef


static func item(id: StringName) -> ItemDef:
	return items().get(id) as ItemDef


static func _fill(obj: Object, props: Dictionary) -> void:
	for key: String in props:
		if not (key in obj):
			push_error("Content: unknown property '%s' on %s" % [key, obj])
			continue
		obj.set(key, props[key])


static func _weapon(id: StringName, props: Dictionary) -> void:
	var w := WeaponDef.new()
	w.id = id
	_fill(w, props)
	_weapons[id] = w


static func _item(id: StringName, props: Dictionary) -> void:
	var it := ItemDef.new()
	it.id = id
	_fill(it, props)
	_items[id] = it


static func _enemy(id: StringName, props: Dictionary) -> void:
	var e := EnemyDef.new()
	e.id = id
	_fill(e, props)
	_enemies.append(e)


static func _build_weapons() -> void:
	_weapon(&"pistol", {
		"damage": 7.0, "cooldown": 0.5, "reach": 300.0, "projectile_speed": 720.0,
		"knockback": 80.0, "price": 14, "color": Color(0.45, 0.95, 1.0),
	})
	_weapon(&"smg", {
		"damage": 3.2, "cooldown": 0.16, "reach": 240.0, "projectile_speed": 780.0,
		"projectile_radius": 3.5, "spread_deg": 8.0, "knockback": 25.0, "price": 24,
		"color": Color(0.55, 1.0, 0.6),
	})
	_weapon(&"shotgun", {
		"damage": 3.5, "cooldown": 1.0, "reach": 200.0, "projectile_speed": 650.0,
		"projectile_radius": 3.5, "pellets": 5, "spread_deg": 30.0, "knockback": 70.0,
		"price": 30, "color": Color(1.0, 0.7, 0.3),
	})
	_weapon(&"rifle", {
		"damage": 16.0, "cooldown": 1.05, "reach": 420.0, "projectile_speed": 1000.0,
		"projectile_radius": 4.0, "pierce": 2, "knockback": 120.0, "price": 34,
		"color": Color(1.0, 0.45, 0.6),
	})
	_weapon(&"orb", {
		"damage": 9.0, "cooldown": 1.3, "reach": 270.0, "projectile_speed": 240.0,
		"projectile_radius": 11.0, "pierce": 99, "knockback": 20.0, "price": 38,
		"color": Color(0.75, 0.55, 1.0),
	})


static func _build_items() -> void:
	var warm := Color(1.0, 0.9, 0.5)
	var echo := Color(1.0, 0.45, 0.9)
	_item(&"iron_heart", {"mods": {Stats.MAX_HP: 8.0}, "price": 14, "color": warm})
	_item(&"sneakers", {"mods": {Stats.MOVE_SPEED: 24.0}, "price": 12, "max_stack": 6, "color": warm})
	_item(&"sharp_edge", {"mods": {Stats.DAMAGE_PCT: 0.10}, "price": 16, "color": warm})
	_item(&"quick_trigger", {"mods": {Stats.ATTACK_SPEED_PCT: 0.12}, "price": 16, "color": warm})
	_item(&"long_barrel", {"mods": {Stats.RANGE_PCT: 0.12}, "price": 12, "max_stack": 5, "color": warm})
	_item(&"lucky_coin", {"mods": {Stats.CRIT_CHANCE: 0.06}, "price": 14, "max_stack": 8, "color": warm})
	_item(&"magnet", {"mods": {Stats.PICKUP_RANGE: 50.0}, "price": 10, "max_stack": 4, "color": warm})
	_item(&"regen_patch", {"mods": {Stats.HP_REGEN: 0.5}, "price": 18, "max_stack": 6, "color": warm})
	_item(&"spare_deck", {
		"mods": {Stats.ECHO_SLOTS: 1.0}, "price": 40, "max_stack": 2, "color": echo, "echo_item": true,
	})
	_item(&"long_play", {
		"mods": {Stats.ECHO_LIFESPAN: 1.0}, "price": 28, "max_stack": 3, "color": echo, "echo_item": true,
	})
	_item(&"loud_speaker", {
		"mods": {Stats.ECHO_POWER: 0.25}, "price": 26, "max_stack": 4, "color": echo, "echo_item": true,
	})


static func _build_enemies() -> void:
	_enemy(&"grunt", {
		"hp": 10.0, "speed": 105.0, "damage": 3.0, "radius": 11.0, "cost": 1.0, "min_wave": 1,
		"weight": 5.0, "drop": 1, "color": Color(1.0, 0.35, 0.5), "sides": 0,
	})
	_enemy(&"runner", {
		"hp": 6.0, "speed": 175.0, "damage": 2.0, "radius": 8.0, "cost": 1.5, "min_wave": 3,
		"weight": 3.0, "drop": 1, "color": Color(1.0, 0.8, 0.3), "sides": 3,
	})
	_enemy(&"brute", {
		"hp": 42.0, "speed": 62.0, "damage": 6.0, "radius": 19.0, "cost": 4.5, "min_wave": 5,
		"weight": 2.0, "drop": 3, "color": Color(0.8, 0.4, 1.0), "sides": 6,
	})
