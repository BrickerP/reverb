class_name Stats
extends RefCounted

const MAX_HP := &"max_hp"
const MOVE_SPEED := &"move_speed"
const DAMAGE_PCT := &"damage_pct"
const ATTACK_SPEED_PCT := &"attack_speed_pct"
const RANGE_PCT := &"range_pct"
const CRIT_CHANCE := &"crit_chance"
const PICKUP_RANGE := &"pickup_range"
const HP_REGEN := &"hp_regen"
const ECHO_SLOTS := &"echo_slots"
const ECHO_LIFESPAN := &"echo_lifespan"
const ECHO_POWER := &"echo_power"

const PERCENT: Array[StringName] = [DAMAGE_PCT, ATTACK_SPEED_PCT, RANGE_PCT, CRIT_CHANCE, ECHO_POWER]
const ORDER: Array[StringName] = [
	MAX_HP, MOVE_SPEED, DAMAGE_PCT, ATTACK_SPEED_PCT, RANGE_PCT, CRIT_CHANCE,
	PICKUP_RANGE, HP_REGEN, ECHO_SLOTS, ECHO_LIFESPAN, ECHO_POWER,
]

const DEFAULTS := {
	MAX_HP: 30.0,
	MOVE_SPEED: 260.0,
	DAMAGE_PCT: 0.0,
	ATTACK_SPEED_PCT: 0.0,
	RANGE_PCT: 0.0,
	CRIT_CHANCE: 0.05,
	PICKUP_RANGE: 90.0,
	HP_REGEN: 0.0,
	ECHO_SLOTS: 2.0,
	ECHO_LIFESPAN: 3.0,
	ECHO_POWER: 0.5,
}

var values: Dictionary = {}


func _init() -> void:
	values = DEFAULTS.duplicate()


func get_stat(id: StringName) -> float:
	return float(values.get(id, 0.0))


func add(id: StringName, amount: float) -> void:
	values[id] = get_stat(id) + amount


func copy() -> Stats:
	var s := Stats.new()
	s.values = values.duplicate()
	return s


func damage_mult() -> float:
	return maxf(0.0, 1.0 + get_stat(DAMAGE_PCT))


func cooldown_mult() -> float:
	return 1.0 / maxf(0.1, 1.0 + get_stat(ATTACK_SPEED_PCT))


func range_mult() -> float:
	return maxf(0.2, 1.0 + get_stat(RANGE_PCT))
