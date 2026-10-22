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
