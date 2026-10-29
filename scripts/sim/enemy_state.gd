class_name EnemyState
extends RefCounted

var uid: int = 0
var def: EnemyDef
var pos: Vector2 = Vector2.ZERO
var hp: float = 1.0
var max_hp: float = 1.0
var speed: float = 100.0
var damage: float = 1.0
var radius: float = 10.0
var knock: Vector2 = Vector2.ZERO
var flash: float = 0.0
var dead: bool = false
var elite: bool = false
var elite_kind: StringName = &""
var shield_arc_override: float = -1.0
var shield_reduction_override: float = -1.0
var death_radius_override: float = -1.0
var death_damage_override: float = -1.0
var drop_mult: int = 1
var brain_state: StringName = &"approach"
var brain_time: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var attack_target: Vector2 = Vector2.ZERO
var attack_tick: float = 0.0
var pin_left: float = 0.0
var ink_left: float = 0.0
var stun_left: float = 0.0


func shield_arc_value() -> float:
	if shield_arc_override >= 0.0:
		return shield_arc_override
	return def.shield_arc if def != null else 0.0


func shield_reduction_value() -> float:
	if shield_reduction_override >= 0.0:
		return shield_reduction_override
	return def.shield_reduction if def != null else 0.0


func death_radius_value() -> float:
	if death_radius_override >= 0.0:
		return death_radius_override
	return def.death_radius if def != null else 0.0


func death_damage_value() -> float:
	if death_damage_override >= 0.0:
		return death_damage_override
	return def.death_damage if def != null else 0.0
