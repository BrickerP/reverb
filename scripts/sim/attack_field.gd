class_name AttackField
extends RefCounted

# Every delayed attack carries a value snapshot of its owner and damage. The
# canonical weapon is looked up only for the burst's projectile shape.
var weapon_id: StringName
var style: StringName
var pos := Vector2.ZERO
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var target := Vector2.ZERO
var damage: float = 0.0
var knockback: float = 0.0
var reach: float = 0.0
var radius: float = 0.0
var width: float = 0.0
var spread: float = 0.0
var windup: float = 0.0
var life: float = 0.0
var age: float = 0.0
var tick_left: float = 0.0
var tick_interval: float = 0.2
var remaining: int = 1
var bonus_pierce: int = 0
var level: int = 0
var source: int = -1
var actor_token: int = -1
var source_tint := Color.WHITE
var color := Color.WHITE
var crit: bool = false
var pin_duration: float = 0.0
var ink_duration: float = 0.0
var mastery: bool = false
var orbit_speed: float = 0.0
var orbit_radius: float = 0.0
var dead: bool = false
