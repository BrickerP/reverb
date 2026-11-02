class_name EchoRetirementInfo
extends RefCounted

const ACTIVE := &"active"
const EXHAUSTED := &"exhausted"
const ABSORBED := &"absorbed"

var reason: StringName = ACTIVE
var exhausted: bool = false
var uid: int = 0
var actor_token: int = 0
var source: int = 0
var wave: int = 0
var pos: Vector2 = Vector2.ZERO
var tint: Color = Color.WHITE
var condition: float = 0.0
var kind: StringName = &""
var weapon_id: StringName = &""
var damage: float = 0.0
var radius: float = 0.0
var profile: Dictionary = {}
