class_name Projectile
extends RefCounted

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var damage: float = 1.0
var radius: float = 4.0
var life: float = 1.0
var pierce_left: int = 0
var knockback: float = 0.0
var color: Color = Color.WHITE
var crit: bool = false
var source: int = -1
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0
var homing_turn: float = 0.0
var hit_uids: PackedInt32Array = PackedInt32Array()
var dead: bool = false
