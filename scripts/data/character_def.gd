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
