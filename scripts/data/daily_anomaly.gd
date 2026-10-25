class_name DailyAnomaly
extends RefCounted

const ECHO_SURGE := &"echo_surge"
const RIFTFALL := &"riftfall"
const TWIN_HUNT := &"twin_hunt"
const FORTUNE := &"fortune"
const RIFTSTORM := &"riftstorm"
const GLASS_CANNON := &"glass_cannon"
const ALL: Array[StringName] = [
	ECHO_SURGE, RIFTFALL, TWIN_HUNT, FORTUNE, RIFTSTORM, GLASS_CANNON,
]

const ECHO_BONUS := 0.15
const RIFT_WAVE := 8
const RIFT_INTERVAL := 14.0
const FORTUNE_DROP_MULT := 1.5
const RIFTSTORM_INTERVAL := 8.0
const GLASS_DAMAGE_BONUS := 0.30
const GLASS_HP_PENALTY := 0.20


static func for_seed(seed_value: int) -> StringName:
	return ALL[absi(seed_value) % ALL.size()]


static func title_key(id: StringName) -> String:
	match id:
		ECHO_SURGE:
			return "daily.echo_surge"
		RIFTFALL:
			return "daily.riftfall"
		TWIN_HUNT:
			return "daily.twin_hunt"
		FORTUNE:
			return "daily.fortune"
		RIFTSTORM:
			return "daily.riftstorm"
		GLASS_CANNON:
			return "daily.glass_cannon"
		_:
			return "daily.echo_surge"


static func apply_start(sim: Sim) -> void:
	if sim.daily_modifier != GLASS_CANNON:
		return
	var max_hp := sim.player.stats.get_stat(Stats.MAX_HP)
	sim.player.stats.add(Stats.MAX_HP, -max_hp * GLASS_HP_PENALTY)
	sim.player.stats.add(Stats.DAMAGE_PCT, GLASS_DAMAGE_BONUS)
	sim.player.hp = minf(sim.player.hp, sim.player.max_hp())
