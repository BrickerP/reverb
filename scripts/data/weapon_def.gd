class_name WeaponDef
extends Resource

@export var id: StringName
@export var family: StringName = &"sidearm"
@export var damage: float = 5.0
@export var cooldown: float = 0.6
@export var reach: float = 360.0
@export var projectile_speed: float = 700.0
@export var projectile_radius: float = 4.5
@export var pierce: int = 0
@export var pellets: int = 1
@export var spread_deg: float = 0.0
@export var knockback: float = 60.0
@export var price: int = 20
@export var color: Color = Color.WHITE


func dps() -> float:
	return damage * float(maxi(1, pellets)) / cooldown
