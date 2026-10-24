class_name TemporalRift
extends RefCounted

const TELEGRAPH_TIME := 1.5
const ACTIVE_TIME := 3.0
const RADIUS := 80.0
const TICK_TIME := 0.75

var pos: Vector2 = Vector2.ZERO
var radius: float = RADIUS
var telegraph: float = TELEGRAPH_TIME
var active: float = 0.0
var tick: float = 0.0


func is_warning() -> bool:
	return telegraph > 0.0


func is_active() -> bool:
	return telegraph <= 0.0 and active > 0.0
