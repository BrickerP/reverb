class_name WeaponDef
extends Resource

@export var id: StringName
@export var family: StringName = &"sidearm"
@export var rarity: StringName = &"common"
@export var drop_weight: float = 1.0
@export var evolution_options: Array[StringName] = []
@export var carrier: StringName = &"hand"
@export var role: StringName = &"damage"
@export var cost: StringName = &"scrap"
@export var school: StringName = &"ranged"
@export var target_mode: StringName = &"single"
@export var support_kind: StringName = &""
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
const GRADE_MULTIPLIERS := [1.0, 1.8, 3.2, 5.5]
const STAMP_RADII := [70.0, 84.0, 98.0, 112.0]


func dps() -> float:
	# Support output is limited by one living unit per owner/kind. Production
	# and repair are utility, never fictional damage added to the build score.
	if support_kind in [&"repair_station", &"paper_tree", &"decoy"]:
		return 0.0
	if support_kind != &"":
		return damage / (0.7 if support_kind == &"hound" else 1.0)
	var hits := float(maxi(1, pellets))
	match attack_style:
		&"burst":
			hits *= float(maxi(1, burst_count))
		&"line", &"ink", &"tape", &"orbit":
			hits = float(maxi(1, floori(field_duration / maxf(0.01, tick_interval))))
		&"boomerang":
			hits *= 2.0
		&"cone":
			hits = 1.0
	return damage * hits / maxf(0.01, cooldown)


func level_mult(level: int) -> float:
	return GRADE_MULTIPLIERS[clampi(level, 0, MAX_LEVEL)]


# Grade enlarges the stamp. Evolution replaces the tool, so only the base seal
# grows through these four radii.
func mark_radius(level: int) -> float:
	if id == &"stamp":
		return STAMP_RADII[clampi(level, 0, MAX_LEVEL)]
	return field_radius


func level_dps(level: int) -> float:
	return dps() * level_mult(level)
