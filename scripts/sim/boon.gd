class_name Boon
extends RefCounted

const DAMAGE := &"damage"
const HASTE := &"haste"
const VITALITY := &"vitality"
const ECHO := &"echo"
const SHIELD := &"shield"
const FORTUNE := &"fortune"
const PRECISION := &"precision"
const SLIPSTREAM := &"slipstream"
const MAGNET := &"magnet"
const ETERNITY := &"eternity"
const SECOND_WIND := &"second_wind"
const ALL: Array[StringName] = [
	DAMAGE, HASTE, VITALITY, ECHO, SHIELD, FORTUNE,
	PRECISION, SLIPSTREAM, MAGNET, ETERNITY, SECOND_WIND,
]


static func roll(rng: RandomNumberGenerator, count: int = 3,
		sim: Sim = null) -> Array[StringName]:
	var pool := ALL.duplicate()
	if sim != null and sim.echo_capacity() <= 0:
		pool.erase(ECHO)
		pool.erase(ETERNITY)
	var out: Array[StringName] = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


static func title_key(id: StringName) -> String:
	match id:
		DAMAGE:
			return "boon.damage_name"
		HASTE:
			return "boon.haste_name"
		VITALITY:
			return "boon.vitality_name"
		ECHO:
			return "boon.echo_name"
		SHIELD:
			return "boon.shield_name"
		FORTUNE:
			return "boon.fortune_name"
		PRECISION:
			return "boon.precision_name"
		SLIPSTREAM:
			return "boon.slipstream_name"
		MAGNET:
			return "boon.magnet_name"
		ETERNITY:
			return "boon.eternity_name"
		SECOND_WIND:
			return "boon.second_wind_name"
		_:
			return "boon.damage_name"


static func desc_key(id: StringName) -> String:
	match id:
		DAMAGE:
			return "boon.damage_desc"
		HASTE:
			return "boon.haste_desc"
		VITALITY:
			return "boon.vitality_desc"
		ECHO:
			return "boon.echo_desc"
		SHIELD:
			return "boon.shield_desc"
		FORTUNE:
			return "boon.fortune_desc"
		PRECISION:
			return "boon.precision_desc"
		SLIPSTREAM:
			return "boon.slipstream_desc"
		MAGNET:
			return "boon.magnet_desc"
		ETERNITY:
			return "boon.eternity_desc"
		SECOND_WIND:
			return "boon.second_wind_desc"
		_:
			return "boon.damage_desc"


static func apply(sim: Sim, id: StringName) -> bool:
	match id:
		DAMAGE:
			sim.player.stats.add(Stats.DAMAGE_PCT, 0.10)
		HASTE:
			sim.player.stats.add(Stats.ATTACK_SPEED_PCT, 0.10)
		VITALITY:
			sim.player.stats.add(Stats.MAX_HP, 15.0)
			sim.player.hp += 15.0
		ECHO:
			sim.player.stats.add(Stats.ECHO_POWER, 0.10)
		SHIELD:
			sim.player.stats.add(Stats.SHIELD, 5.0)
			sim.player.shield += 5.0
		FORTUNE:
			sim.player.materials += 30
		PRECISION:
			sim.player.stats.add(Stats.CRIT_CHANCE, 0.05)
		SLIPSTREAM:
			sim.player.stats.add(Stats.MOVE_SPEED, 20.0)
		MAGNET:
			sim.player.stats.add(Stats.PICKUP_RANGE, 30.0)
		ETERNITY:
			sim.player.stats.add(Stats.ECHO_LIFESPAN, 1.0)
		SECOND_WIND:
			sim.second_wind_charges += 1
		_:
			return false
	return true
