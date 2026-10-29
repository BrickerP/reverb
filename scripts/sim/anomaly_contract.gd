class_name AnomalyContract
extends RefCounted

const CLEAN := &"clean"
const CLEAR := &"clear"
const HUNT := &"hunt"
const RETIRE := &"retire"

const START_WAVE := 3
const CLEAN_DEPOSIT := 6
const CLEAN_REWARD := 18
const CLEAR_DEPOSIT := 6
const CLEAR_REWARD := 18
const HUNT_DEPOSIT := 8
const HUNT_REWARD := 24
const RETIRE_DEPOSIT := 8
const RETIRE_REWARD := 24

var kind: StringName = CLEAN
var deposit: int = 0
var reward: int = 0
var target: int = 0
var accepted: bool = false


static func make(wave: int, rng: RandomNumberGenerator,
		endless: bool = false, allow_retire: bool = true) -> AnomalyContract:
	if wave < START_WAVE or (wave >= WaveDirector.FINAL_WAVE and not endless):
		return null
	var pool: Array[StringName] = [CLEAN, CLEAR]
	if wave >= WaveDirector.ELITE_START_WAVE:
		pool.append(HUNT)
	if allow_retire:
		pool.append(RETIRE)
	var contract := AnomalyContract.new()
	contract.kind = pool[rng.randi_range(0, pool.size() - 1)]
	match contract.kind:
		CLEAN:
			contract.deposit = CLEAN_DEPOSIT
			contract.reward = CLEAN_REWARD
		CLEAR:
			contract.deposit = CLEAR_DEPOSIT
			contract.reward = CLEAR_REWARD
			contract.target = mini(40, 10 + wave)
		HUNT:
			contract.deposit = HUNT_DEPOSIT
			contract.reward = HUNT_REWARD
		RETIRE:
			contract.deposit = RETIRE_DEPOSIT
			contract.reward = RETIRE_REWARD
	return contract


func is_complete(sim: Sim) -> bool:
	match kind:
		CLEAN:
			return not sim.wave_damage_taken
		CLEAR:
			return sim.wave_kills >= target
		HUNT:
			return sim.wave_elite_kills >= 1
		RETIRE:
			return sim.wave_retirements > 0
		_:
			return false
