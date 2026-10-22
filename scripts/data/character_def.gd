class_name CharacterDef
extends Resource

@export var id: StringName
@export var color: Color = Color.WHITE
@export var overrides: Dictionary = {}
@export var mods: Dictionary = {}
@export var unlock_wave: int = 0
@export var unlock_wins: int = 0
@export var live_echo: bool = false


func apply(sim: Sim) -> void:
	for stat: StringName in overrides:
		sim.player.stats.values[stat] = float(overrides[stat])
	for stat: StringName in mods:
		sim.player.stats.add(stat, float(mods[stat]))
	sim.player.hp = sim.player.max_hp()
	sim.live_echo = live_echo
