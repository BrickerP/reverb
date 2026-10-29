class_name EnemyZone
extends RefCounted

const WARNING_TIME := 0.7
const ACTIVE_TIME := 2.4
const HIT_INTERVAL := 0.65
const RADIUS := 92.0

var source_uid: int = 0
var pos := Vector2.ZERO
var radius := RADIUS
var warning := WARNING_TIME
var active := ACTIVE_TIME
var tick := 0.0
var damage := 0.0


func is_warning() -> bool:
	return warning > 0.0 and active > 0.0


func is_active() -> bool:
	return warning <= 0.0 and active > 0.0


func contains(point: Vector2, body_radius: float = 0.0) -> bool:
	return is_active() and pos.distance_squared_to(point) <= pow(radius + body_radius, 2.0)
