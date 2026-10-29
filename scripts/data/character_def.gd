class_name CharacterDef
extends Resource

@export var id: StringName
@export var color: Color = Color.WHITE
@export var starting_weapon: StringName = &"pistol"
@export var overrides: Dictionary = {}
@export var mods: Dictionary = {}
@export var unlock_wave: int = 0
@export var unlock_wins: int = 0
@export var live_echo: bool = false
@export var synergy_damage_per_echo: float = 0.0
@export var synergy_haste_per_echo: float = 0.0
@export var repair_discount: float = 0.0
@export var wear_rate_mult: float = 1.0
@export var retirement_mult: float = 1.0
@export var pickup_repair: float = 0.0


func apply(sim: Sim) -> void:
	for stat: StringName in overrides:
		sim.player.stats.values[stat] = float(overrides[stat])
	for stat: StringName in mods:
		sim.player.stats.add(stat, float(mods[stat]))
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	var starter := Content.weapon(starting_weapon)
	if starter == null:
		starter = Content.weapon(Content.STARTER_WEAPON)
	sim.player.add_weapon(starter)
	sim.player.hp = sim.player.max_hp()
	sim.live_echo = live_echo
	sim.synergy_damage_per_echo = synergy_damage_per_echo
	sim.synergy_haste_per_echo = synergy_haste_per_echo
	sim.repair_discount = repair_discount
	sim.wear_rate_mult = wear_rate_mult
	sim.retirement_mult = retirement_mult
	sim.pickup_repair = pickup_repair
