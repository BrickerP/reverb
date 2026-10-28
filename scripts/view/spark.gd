class_name Spark
extends RefCounted

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var color: Color = Color.WHITE
var life: float = 0.3
var max_life: float = 0.3
var radius: float = 0.0
var ring: bool = false

# Paper fragments rotate only in the view; no simulation RNG is consumed.
var rotation: float = 0.0
var spin: float = 0.0
