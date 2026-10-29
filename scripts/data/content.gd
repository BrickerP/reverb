class_name Content
extends RefCounted

const MAX_WEAPON_SLOTS := 6
const STARTER_WEAPON := &"pistol"

static var _weapons: Dictionary = {}
static var _items: Dictionary = {}
static var _enemies: Array[EnemyDef] = []
static var _characters: Dictionary = {}

const ITEM_SETS := {
	&"echo": {
		"name": "set.echo",
		"members": [&"spare_deck", &"long_play", &"loud_speaker"],
		"required": 3,
		"mods": {&"echo_power": 0.02},
	},
	&"gunsmith": {
		"name": "set.gunsmith",
		"members": [&"sharp_edge", &"quick_trigger", &"long_barrel", &"lucky_coin"],
		"required": 3,
		"mods": {&"damage_pct": 0.02, &"attack_speed_pct": 0.02},
	},
	&"field": {
		"name": "set.field",
		"members": [&"iron_heart", &"regen_patch", &"sneakers", &"magnet"],
		"required": 3,
		"mods": {&"shield": 8.0},
	},
}


static func weapons() -> Dictionary:
	if _weapons.is_empty():
		_build_weapons()
	return _weapons


static func items() -> Dictionary:
	if _items.is_empty():
		_build_items()
	return _items


static func item_sets() -> Dictionary:
	return ITEM_SETS


static func enemies() -> Array[EnemyDef]:
	if _enemies.is_empty():
		_build_enemies()
	return _enemies


static func characters() -> Dictionary:
	if _characters.is_empty():
		_build_characters()
	return _characters


static func character(id: StringName) -> CharacterDef:
	return characters().get(id) as CharacterDef


static func weapon(id: StringName) -> WeaponDef:
	return weapons().get(id) as WeaponDef


static func item(id: StringName) -> ItemDef:
	return items().get(id) as ItemDef


static func enemy(id: StringName) -> EnemyDef:
	for e in enemies():
		if e.id == id:
			return e
	return null


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


static func _character(id: StringName, props: Dictionary) -> void:
	var ch := CharacterDef.new()
	ch.id = id
	_fill(ch, props)
	_characters[id] = ch


static func _build_weapons() -> void:
	_weapon(&"pistol", {
		"family": &"sidearm", "rarity": &"common", "drop_weight": 2.5,
		"evolves_to": &"twin_fangs", "attack_style": &"projectile",
		"damage": 7.0, "cooldown": 0.5, "reach": 300.0, "projectile_speed": 720.0,
		"knockback": 80.0, "price": 14, "color": Color(0.45, 0.95, 1.0),
	})
	_weapon(&"smg", {
		"family": &"sidearm", "rarity": &"common", "drop_weight": 2.0,
		"evolves_to": &"twin_fangs", "attack_style": &"burst",
		"damage": 2.5, "cooldown": 0.65, "reach": 260.0, "projectile_speed": 780.0,
		"burst_count": 3, "burst_interval": 0.07, "projectile_radius": 3.5,
		"spread_deg": 8.0, "knockback": 25.0, "price": 24, "color": Color(0.55, 1.0, 0.6),
	})
	_weapon(&"stapler", {
		"family": &"sidearm", "rarity": &"uncommon", "drop_weight": 1.6,
		"evolves_to": &"twin_fangs", "attack_style": &"pin",
		"damage": 7.0, "cooldown": 0.8, "reach": 310.0, "projectile_speed": 680.0,
		"pin_duration": 1.2, "homing_turn": 1.2, "projectile_radius": 5.0, "knockback": 15.0,
		"price": 26, "color": Color(0.45, 0.85, 0.9),
	})
	_weapon(&"shotgun", {
		"family": &"scatter", "rarity": &"uncommon", "drop_weight": 2.0,
		"evolves_to": &"flak_crown", "attack_style": &"cone",
		"damage": 14.0, "cooldown": 0.95, "reach": 170.0,
		"spread_deg": 60.0, "knockback": 110.0,
		"price": 30, "color": Color(1.0, 0.7, 0.3),
	})
	_weapon(&"flechette", {
		"family": &"scatter", "rarity": &"uncommon", "drop_weight": 1.5,
		"evolves_to": &"flak_crown", "attack_style": &"projectile",
		"damage": 4.0, "cooldown": 0.8, "reach": 260.0, "projectile_speed": 800.0,
		"projectile_radius": 3.0, "pellets": 3, "spread_deg": 16.0, "pierce": 1,
		"knockback": 35.0, "price": 28, "color": Color(1.0, 0.8, 0.5),
		"explosion_radius": 24.0, "explosion_damage": 0.35,
	})
	_weapon(&"paper_saw", {
		"family": &"scatter", "rarity": &"rare", "drop_weight": 1.0,
		"evolves_to": &"flak_crown", "attack_style": &"boomerang",
		"damage": 9.0, "cooldown": 1.1, "reach": 240.0, "projectile_speed": 540.0,
		"projectile_radius": 13.0, "pierce": 5, "return_time": 0.35,
		"knockback": 45.0, "price": 34, "color": Color(0.95, 0.75, 0.45),
	})
	_weapon(&"rifle", {
		"family": &"marksman", "rarity": &"uncommon", "drop_weight": 1.5,
		"evolves_to": &"rail_spike", "attack_style": &"projectile",
		"damage": 16.0, "cooldown": 1.05, "reach": 420.0, "projectile_speed": 1000.0,
		"projectile_radius": 4.0, "pierce": 2, "knockback": 120.0, "price": 34,
		"color": Color(1.0, 0.45, 0.6),
	})
	_weapon(&"longbow", {
		"family": &"marksman", "rarity": &"uncommon", "drop_weight": 1.2,
		"evolves_to": &"rail_spike", "attack_style": &"pin",
		"damage": 20.0, "cooldown": 1.4, "reach": 480.0, "projectile_speed": 1100.0,
		"projectile_radius": 3.5, "pierce": 3, "pin_duration": 1.6,
		"knockback": 100.0, "price": 36, "color": Color(1.0, 0.75, 0.55),
	})
	_weapon(&"hole_punch", {
		"family": &"marksman", "rarity": &"rare", "drop_weight": 1.0,
		"evolves_to": &"rail_spike", "attack_style": &"line",
		"damage": 3.0, "cooldown": 1.5, "reach": 400.0, "field_duration": 0.6,
		"tick_interval": 0.12, "line_width": 14.0,
		"knockback": 25.0, "price": 38, "color": Color(0.95, 0.55, 0.65),
	})
	_weapon(&"orb", {
		"family": &"arcane", "rarity": &"rare", "drop_weight": 1.0,
		"evolves_to": &"nova_core", "attack_style": &"orbit",
		"damage": 3.2, "cooldown": 1.5, "reach": 270.0, "field_duration": 1.5,
		"tick_interval": 0.3, "field_radius": 25.0, "orbit_radius": 100.0,
		"orbit_speed": 3.6, "knockback": 20.0, "price": 38,
		"color": Color(0.75, 0.55, 1.0),
	})
	_weapon(&"hex_bolt", {
		"family": &"arcane", "rarity": &"rare", "drop_weight": 1.5,
		"evolves_to": &"nova_core", "attack_style": &"chain",
		"damage": 7.0, "cooldown": 0.9, "reach": 300.0,
		"chain_count": 3, "chain_radius": 100.0,
		"knockback": 20.0, "price": 30, "color": Color(0.65, 0.8, 1.0),
	})
	_weapon(&"ink_bottle", {
		"family": &"arcane", "rarity": &"uncommon", "drop_weight": 1.5,
		"evolves_to": &"nova_core", "attack_style": &"ink",
		"damage": 2.8, "cooldown": 1.6, "reach": 280.0, "field_duration": 2.0,
		"tick_interval": 0.4, "field_radius": 80.0, "ink_duration": 2.0,
		"knockback": 0.0, "price": 28, "color": Color(0.55, 0.5, 0.8),
	})
	_weapon(&"stamp", {
		"family": &"press", "rarity": &"uncommon", "drop_weight": 1.8,
		"evolves_to": &"hydraulic_press", "attack_style": &"slam",
		"damage": 24.0, "cooldown": 1.6, "reach": 180.0,
		"windup": 0.4, "field_radius": 70.0, "knockback": 180.0,
		"price": 30, "color": Color(0.85, 0.35, 0.3),
	})
	_weapon(&"mallet", {
		"family": &"press", "rarity": &"common", "drop_weight": 2.0,
		"evolves_to": &"hydraulic_press", "attack_style": &"slam",
		"damage": 16.0, "cooldown": 1.05, "reach": 125.0,
		"windup": 0.2, "field_radius": 44.0, "knockback": 240.0,
		"price": 22, "color": Color(0.85, 0.5, 0.4),
	})
	_weapon(&"cutter", {
		"family": &"press", "rarity": &"rare", "drop_weight": 1.0,
		"evolves_to": &"hydraulic_press", "attack_style": &"line",
		"damage": 4.0, "cooldown": 0.9, "reach": 190.0, "field_duration": 0.45,
		"tick_interval": 0.15, "line_width": 10.0,
		"knockback": 30.0, "price": 34, "color": Color(0.95, 0.6, 0.5),
	})
	_weapon(&"tape_spool", {
		"family": &"salvage", "rarity": &"uncommon", "drop_weight": 1.8,
		"evolves_to": &"redaction_engine", "attack_style": &"tape",
		"damage": 2.2, "cooldown": 1.8, "reach": 260.0, "field_duration": 2.4,
		"tick_interval": 0.4, "field_radius": 95.0, "pin_duration": 0.28,
		"knockback": 0.0, "price": 26, "color": Color(0.8, 0.75, 0.45),
	})
	_weapon(&"rubber_band", {
		"family": &"salvage", "rarity": &"common", "drop_weight": 2.0,
		"evolves_to": &"redaction_engine", "attack_style": &"boomerang",
		"damage": 6.0, "cooldown": 0.8, "reach": 210.0, "projectile_speed": 630.0,
		"projectile_radius": 8.0, "pierce": 2, "return_time": 0.25,
		"knockback": 65.0, "price": 20, "color": Color(0.9, 0.8, 0.55),
	})
	_weapon(&"paper_plane", {
		"family": &"salvage", "rarity": &"rare", "drop_weight": 1.0,
		"evolves_to": &"redaction_engine", "attack_style": &"boomerang",
		"damage": 10.0, "cooldown": 1.5, "reach": 390.0, "projectile_speed": 650.0,
		"projectile_radius": 6.0, "pierce": 3, "return_time": 0.6,
		"knockback": 40.0, "price": 34, "color": Color(0.75, 0.85, 0.7),
	})
	# Evolution forms are earned from a maxed weapon, never offered as drops.
	_weapon(&"twin_fangs", {
		"family": &"sidearm", "rarity": &"evolved", "drops": false, "drop_weight": 0.0,
		"attack_style": &"burst", "damage": 3.0, "cooldown": 0.5, "reach": 300.0,
		"projectile_speed": 820.0, "projectile_radius": 4.0, "pellets": 2,
		"burst_count": 3, "burst_interval": 0.055, "spread_deg": 6.0, "pierce": 1,
		"knockback": 35.0, "price": 34, "color": Color(0.65, 1.0, 1.0),
	})
	_weapon(&"flak_crown", {
		"family": &"scatter", "rarity": &"evolved", "drops": false, "drop_weight": 0.0,
		"attack_style": &"cone", "damage": 26.0, "cooldown": 0.85, "reach": 220.0,
		"spread_deg": 80.0, "knockback": 160.0,
		"price": 45, "color": Color(1.0, 0.85, 0.4),
	})
	_weapon(&"rail_spike", {
		"family": &"marksman", "rarity": &"evolved", "drops": false, "drop_weight": 0.0,
		"attack_style": &"line", "damage": 4.0, "cooldown": 0.9, "reach": 510.0,
		"field_duration": 0.6, "tick_interval": 0.1, "line_width": 20.0,
		"knockback": 80.0, "price": 48, "color": Color(1.0, 0.55, 0.8),
	})
	_weapon(&"nova_core", {
		"family": &"arcane", "rarity": &"evolved", "drops": false, "drop_weight": 0.0,
		"attack_style": &"chain", "damage": 14.0, "cooldown": 1.1, "reach": 340.0,
		"chain_count": 5, "chain_radius": 150.0, "knockback": 25.0,
		"price": 50, "color": Color(0.9, 0.6, 1.0),
	})
	_weapon(&"hydraulic_press", {
		"family": &"press", "rarity": &"evolved", "drops": false, "drop_weight": 0.0,
		"attack_style": &"slam", "damage": 46.0, "cooldown": 1.6, "reach": 225.0,
		"windup": 0.55, "field_radius": 112.0, "knockback": 280.0,
		"price": 50, "color": Color(0.95, 0.3, 0.25),
	})
	_weapon(&"redaction_engine", {
		"family": &"salvage", "rarity": &"evolved", "drops": false, "drop_weight": 0.0,
		"attack_style": &"orbit", "damage": 4.0, "cooldown": 1.4, "reach": 330.0,
		"field_duration": 2.1, "tick_interval": 0.3, "field_radius": 40.0,
		"orbit_radius": 130.0, "orbit_speed": -5.5, "ink_duration": 0.8,
		"knockback": 40.0, "price": 52, "color": Color(0.6, 0.75, 0.55),
	})


static func _build_items() -> void:
	var warm := Color(1.0, 0.9, 0.5)
	var echo := Color(1.0, 0.45, 0.9)
	_item(&"iron_heart", {"mods": {Stats.MAX_HP: 10.0}, "price": 14, "color": warm})
	_item(&"sneakers", {"mods": {Stats.MOVE_SPEED: 28.0}, "price": 12, "max_stack": 6, "color": warm})
	_item(&"sharp_edge", {"mods": {Stats.DAMAGE_PCT: 0.10}, "price": 16, "color": warm})
	_item(&"quick_trigger", {"mods": {Stats.ATTACK_SPEED_PCT: 0.12}, "price": 16, "color": warm})
	_item(&"long_barrel", {"mods": {Stats.RANGE_PCT: 0.12}, "price": 12, "max_stack": 5, "color": warm})
	_item(&"lucky_coin", {"mods": {Stats.CRIT_CHANCE: 0.06}, "price": 14, "max_stack": 8, "color": warm})
	_item(&"magnet", {"mods": {Stats.PICKUP_RANGE: 50.0}, "price": 10, "max_stack": 4, "color": warm})
	_item(&"regen_patch", {"mods": {Stats.HP_REGEN: 0.65}, "price": 18, "max_stack": 6, "color": warm})
	_item(&"spare_deck", {
		"mods": {Stats.ECHO_SLOTS: 1.0}, "price": 40, "max_stack": 2, "color": echo, "echo_item": true,
	})
	_item(&"long_play", {
		"mods": {Stats.ECHO_DURATION: 40.0}, "price": 28, "max_stack": 3, "color": echo, "echo_item": true,
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
	_enemy(&"silencer", {
		"hp": 18.0, "speed": 115.0, "damage": 3.0, "radius": 12.0, "cost": 2.0, "min_wave": 8,
		"weight": 1.2, "drop": 1, "color": Color(0.65, 0.8, 1.0), "sides": 5, "silence_time": 2.0,
	})
	_enemy(&"bomber", {
		"hp": 24.0, "speed": 95.0, "damage": 3.0, "radius": 12.0, "cost": 2.2, "min_wave": 6,
		"weight": 0.9, "drop": 2, "color": Color(1.0, 0.45, 0.2), "sides": 4,
		"death_radius": 52.0, "death_damage": 6.0,
	})
	_enemy(&"warden", {
		"hp": 28.0, "speed": 58.0, "damage": 4.0, "radius": 17.0, "cost": 3.0, "min_wave": 8,
		"weight": 0.6, "drop": 3, "color": Color(0.55, 0.75, 1.0), "sides": 6,
		"shield_arc": 90.0, "shield_reduction": 0.2,
	})
	_enemy(&"paradox", {
		"hp": 5200.0, "speed": 55.0, "damage": 8.0, "radius": 30.0, "cost": 0.0, "min_wave": 20,
		"weight": 0.0, "drop": 40, "color": Color(0.8, 0.5, 1.0), "sides": 8, "is_boss": true,
	})


static func _build_characters() -> void:
	_character(&"looper", {
		"color": Color(1.0, 0.55, 0.9),
		"overrides": {Stats.ECHO_SLOTS: 3.0, Stats.ECHO_POWER: 0.4},
		"mods": {Stats.MAX_HP: 5.0},
		"unlock_wave": 0,
	})
	_character(&"solo", {
		"color": Color(0.5, 0.95, 1.0),
		"starting_weapon": &"hex_bolt",
		"overrides": {Stats.ECHO_SLOTS: 0.0},
		"mods": {
			Stats.DAMAGE_PCT: 0.6,
			Stats.MAX_HP: 25.0,
			Stats.MOVE_SPEED: 20.0,
			Stats.ATTACK_SPEED_PCT: 0.25,
			Stats.CRIT_CHANCE: 0.05,
		},
		"unlock_wave": 10,
	})
	_character(&"mirror", {
		"color": Color(1.0, 0.8, 0.4),
		"starting_weapon": &"longbow",
		"overrides": {Stats.ECHO_SLOTS: 2.0, Stats.ECHO_POWER: 0.4},
		"mods": {Stats.MAX_HP: 5.0},
		"live_echo": true,
		"unlock_wins": 1,
	})
	_character(&"conductor", {
		"color": Color(0.55, 0.95, 0.85),
		"starting_weapon": &"pistol",
		"overrides": {Stats.ECHO_SLOTS: 4.0, Stats.ECHO_POWER: 0.22},
		"mods": {Stats.MAX_HP: 5.0},
		"synergy_damage_per_echo": 0.045,
		"synergy_haste_per_echo": 0.025,
		"unlock_wave": 15,
	})
	_character(&"mender", {
		"color": Color(0.9, 0.8, 0.55),
		"starting_weapon": &"tape_spool",
		"overrides": {Stats.ECHO_SLOTS: 3.0, Stats.ECHO_POWER: 0.4},
		"mods": {Stats.MAX_HP: 5.0},
		"repair_discount": 0.25,
		"pickup_repair": 0.6,
		"unlock_wave": 5,
	})
	_character(&"overloader", {
		"color": Color(0.95, 0.45, 0.35),
		"starting_weapon": &"stamp",
		"mods": {Stats.MAX_HP: 5.0},
		"wear_rate_mult": 1.35,
		"retirement_mult": 1.5,
		"unlock_wave": 12,
	})
