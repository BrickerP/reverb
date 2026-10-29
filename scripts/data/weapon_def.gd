class_name WeaponDef
extends Resource

@export var id: StringName
@export var family: StringName = &"sidearm"
@export var rarity: StringName = &"common"
@export var drop_weight: float = 1.0
@export var evolves_to: StringName
@export var drops: bool = true
@export var attack_style: StringName = &"projectile"
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
@export var explosion_radius: float = 0.0
@export var explosion_damage: float = 0.0
@export var homing_turn: float = 0.0
@export var burst_count: int = 1
@export var burst_interval: float = 0.07
@export var windup: float = 0.0
@export var field_duration: float = 0.0
@export var tick_interval: float = 0.2
@export var field_radius: float = 0.0
@export var line_width: float = 0.0
@export var pin_duration: float = 0.0
@export var ink_duration: float = 0.0
@export var return_time: float = 0.0
@export var chain_count: int = 0
@export var chain_radius: float = 0.0
@export var orbit_speed: float = 0.0
@export var orbit_radius: float = 0.0

const MAX_LEVEL := 3
const DAMAGE_PER_LEVEL := 0.15


func dps() -> float:
	var hits := float(maxi(1, pellets))
	match attack_style:
		&"burst":
			hits *= float(maxi(1, burst_count))
		&"line", &"ink", &"tape", &"orbit":
			hits = float(maxi(1, floori(field_duration / maxf(0.01, tick_interval))))
		&"boomerang":
			hits = 2.0
		&"cone":
			hits = 1.0
	return damage * hits / maxf(0.01, cooldown)


func level_mult(level: int) -> float:
	return 1.0 + DAMAGE_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL))


func level_dps(level: int) -> float:
	return dps() * level_mult(level)
