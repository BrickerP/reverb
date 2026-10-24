class_name Boon
extends RefCounted

const DAMAGE := &"damage"
const HASTE := &"haste"
const VITALITY := &"vitality"
const ECHO := &"echo"
const SHIELD := &"shield"
const FORTUNE := &"fortune"
const ALL: Array[StringName] = [DAMAGE, HASTE, VITALITY, ECHO, SHIELD, FORTUNE]


static func roll(rng: RandomNumberGenerator, count: int = 3) -> Array[StringName]:
	var pool := ALL.duplicate()
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
		_:
			return false
	return true
