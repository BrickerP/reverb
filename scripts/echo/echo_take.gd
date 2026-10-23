class_name EchoTake
extends RefCounted

const SAMPLE_DT := 1.0 / 30.0
const PALETTE: Array[Color] = [
	Color(0.35, 0.85, 1.0),
	Color(1.0, 0.45, 0.85),
	Color(0.6, 1.0, 0.5),
	Color(1.0, 0.8, 0.35),
	Color(0.7, 0.55, 1.0),
	Color(1.0, 0.55, 0.4),
]

var samples: PackedVector2Array = PackedVector2Array()
var weapons: Array[WeaponDef] = []
var levels: Array[int] = []
var stats: Stats = Stats.new()
var wave: int = 0
var age: int = 0
var tint_index: int = 0
var merged: bool = false


func tint() -> Color:
	return PALETTE[tint_index % PALETTE.size()]


func level_at(index: int) -> int:
	return levels[index] if index >= 0 and index < levels.size() else 0


func duration() -> float:
	return maxf(0.0, float(samples.size() - 1) * SAMPLE_DT)


func playback_time(t: float) -> float:
	var d := duration()
	if d <= 0.0:
		return 0.0
	var tt := fposmod(t, 2.0 * d)
	return tt if tt <= d else 2.0 * d - tt


func is_rewinding(t: float) -> bool:
	var d := duration()
	return d > 0.0 and fposmod(t, 2.0 * d) > d


func position_at(t: float) -> Vector2:
	if samples.is_empty():
		return Vector2.ZERO
	if samples.size() == 1:
		return samples[0]
	var f := playback_time(t) / SAMPLE_DT
	var i := mini(int(floor(f)), samples.size() - 2)
	return samples[i].lerp(samples[i + 1], clampf(f - float(i), 0.0, 1.0))


func power() -> float:
	var total := 0.0
	for i in weapons.size():
		var level := levels[i] if i >= 0 and i < levels.size() else 0
		total += weapons[i].level_dps(level)
	return total * stats.damage_mult() / stats.cooldown_mult()
