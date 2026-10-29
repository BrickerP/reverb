extends SceneTree
# Baseline-compatible gameplay oracle. Copy this exact file to both revisions:
# godot --headless --quiet --path <isolated-project> \
#   --script res://tools/battle_invariants_probe.gd -- --out /absolute/result.json
# Uses fixed simulation steps only; no scenes, presentation code or wall clock.

const DT := 1.0 / 60.0
const NORMAL_STEPS := 7200
const HAZARD_STEPS := 2880
const ECHO_STEPS := 3000
const WEAPON_IDS: Array[StringName] = [&"pistol", &"smg", &"rifle", &"shotgun"]

var _failed := false
var _output_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments():
		quit(1)
		return
	var scenarios: Array[Dictionary] = []
	scenarios.append(_normal_progression())
	if not _failed:
		scenarios.append(_wave_twelve())
	if not _failed:
		scenarios.append(_boss_split())
	if not _failed:
		scenarios.append(_eight_echoes())
	if _failed:
		quit(1)
		return
	var report := {"format": "battle_invariants_v1", "step_seconds": DT,
		"scenarios": scenarios}
	if not _require(scenarios.size() == 4 and _json_safe(report),
			"report must contain four scenarios and only finite JSON values"):
		quit(1)
		return
	# Preserve float precision, and keep 64-bit RNG states as strings below.
	var encoded := JSON.stringify(report, "", true, true)
	var parsed := JSON.new()
	if not _require(parsed.parse(encoded) == OK and parsed.data is Dictionary,
			"serialized report must parse as a JSON object"):
		quit(1)
		return
	if _output_path == "":
		# Godot --quiet suppresses print(), including script output. Write to the
		# stdout device so --quiet can remove the engine banner without the JSON.
		var stdout := FileAccess.open("/dev/stdout", FileAccess.WRITE)
		if not _require(stdout != null, "cannot open stdout; use --out instead"):
			quit(1)
			return
		stdout.store_string(encoded + "\n")
		stdout.flush()
		var stdout_error := stdout.get_error()
		stdout.close()
		if not _require(stdout_error == OK, "failed writing JSON to stdout"):
			quit(1)
			return
	else:
		var file := FileAccess.open(_output_path, FileAccess.WRITE)
		if not _require(file != null, "cannot open output: " + _output_path):
			quit(1)
			return
		file.store_string(encoded + "\n")
		file.flush()
		var write_error := file.get_error()
		file.close()
		if not _require(write_error == OK, "failed writing output: " + _output_path):
			quit(1)
			return
		var stored := JSON.new()
		if not _require(stored.parse(FileAccess.get_file_as_string(_output_path)) == OK,
				"saved output is invalid JSON"):
			quit(1)
			return
	quit(0)


func _arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return true
	if not _require(args.size() == 2 and args[0] == "--out",
			"usage: -- --out /absolute/result.json (or no arguments for stdout)"):
		return false
	_output_path = args[1]
	return _require(_output_path.is_absolute_path(), "--out requires an absolute path")


func _normal_progression() -> Dictionary:
	var sim := Sim.new(14786)
	Content.character(&"looper").apply(sim)
	var bot := Bot.new(&"balanced")
	sim.start_run()
	var result := _scenario("normal_bot_progression", sim, NORMAL_STEPS)
	var shops := 0
	_capture(result, "start", 0, sim, bot)
	for step in range(1, NORMAL_STEPS + 1):
		if sim.phase == Sim.Phase.SHOP:
			_capture(result, "shop_%d_before" % sim.wave, step - 1, sim, bot)
			bot.shop(sim)
			shops += 1
			_capture(result, "shop_%d_after" % sim.wave, step - 1, sim, bot)
			if not _require(sim.can_start_wave(), "Bot must resolve echo overflow before continuing"):
				break
			sim.start_next_wave()
			_capture(result, "wave_%d_start" % sim.wave, step - 1, sim, bot)
		sim.step(DT, bot.move_dir(sim))
		_observe(result, sim)
		result["completed_steps"] = step
		if step % 600 == 0 or sim.phase == Sim.Phase.LOST or sim.phase == Sim.Phase.WON:
			_capture(result, "step_%d" % step, step, sim, bot)
		if sim.phase == Sim.Phase.LOST or sim.phase == Sim.Phase.WON:
			break
	_capture(result, "final", int(result["completed_steps"]), sim, bot)
	result["shop_visits"] = shops
	_require(shops >= 3 and sim.wave >= 4,
			"normal progression must exercise at least three Bot shops and four waves")
	return result


func _wave_twelve() -> Dictionary:
	var sim := _durable_sim(120147)
	sim.ascension = 3
	sim.start_wave(12)
	var bot := Bot.new(&"balanced")
	var result := _scenario("wave_12_elites_and_rifts", sim, HAZARD_STEPS)
	_capture(result, "start", 0, sim, bot)
	for step in range(1, HAZARD_STEPS + 1):
		sim.step(DT, bot.move_dir(sim))
		_observe(result, sim)
		result["completed_steps"] = step
		if step % 300 == 0 or step in [480, 540, 600, 660, 1320, 1440, 1500]:
			_capture(result, "step_%d" % step, step, sim, bot)
	_capture(result, "final", HAZARD_STEPS, sim, bot)
	var coverage: Dictionary = result["coverage"]
	_require((coverage["elite_uids"] as Array).size() >= 2,
			"wave 12 must materialize both ascension elites")
	_require(int(coverage["rift_warning_steps"]) > 0 and int(coverage["rift_active_steps"]) > 0,
			"wave 12 must include rift warning and active damage windows")
	return result


func _boss_split() -> Dictionary:
	var sim := _durable_sim(200147)
	sim.start_wave(20)
	var bot := Bot.new(&"balanced")
	var result := _scenario("boss_20_split_enrage_and_defeat", sim, 482)
	_capture(result, "start", 0, sim, bot)
	_step_block(sim, bot, result, 180)
	if not _require(sim.boss != null and sim.boss_phase == 1,
			"wave 20 must materialize the unsplit boss before manual arrangement"):
		return result
	_capture(result, "boss_materialized", 180, sim, bot)
	# Identical explicit arrangement in each revision: cross the 50% threshold
	# without killing the boss, then kill one shard and finally its survivor.
	sim.boss.hp = sim.boss.max_hp * 0.51
	_capture(result, "before_split_damage", 180, sim, bot)
	sim.damage_enemy(sim.boss, sim.boss.max_hp * 0.02, Vector2(30.0, -10.0),
			false, -1, Vector2.RIGHT, &"rifle", &"hit")
	_capture(result, "split", 180, sim, bot)
	if not _require(sim.boss_phase == 2 and sim.boss_alive_count() == 2,
			"threshold damage must split the boss into two living shards"):
		return result
	_step_block(sim, bot, result, 120)
	_capture(result, "split_after_120_steps", 300, sim, bot)
	var first := sim.boss_shards[0]
	first.hp = 1.0
	sim.damage_enemy(first, 10.0, Vector2(-25.0, 15.0), true, 0,
			Vector2.LEFT, &"pistol", &"hit")
	_capture(result, "one_shard_dead", 300, sim, bot)
	if not _require(sim.boss_alive_count() == 1 and sim._boss_enraged,
			"first shard death must enrage the survivor"):
		return result
	_step_block(sim, bot, result, 180)
	_capture(result, "enraged_after_180_steps", 480, sim, bot)
	var survivor := sim.boss_shards[1]
	survivor.hp = 1.0
	sim.damage_enemy(survivor, 10.0, Vector2(20.0, 5.0), false, -1,
			Vector2.DOWN, &"rifle", &"hit")
	_capture(result, "both_shards_dead", 480, sim, bot)
	_step_block(sim, bot, result, 2)
	_capture(result, "final", 482, sim, bot)
	_require(sim.phase == Sim.Phase.WON and sim.boss_alive_count() == 0,
			"boss scenario must finish with both shards defeated and run won")
	return result


func _eight_echoes() -> Dictionary:
	var sim := _durable_sim(800147)
	sim.player.stats.values[Stats.ECHO_SLOTS] = 8.0
	sim.player.stats.values[Stats.ECHO_LIFESPAN] = 12.0
	for i in 9:
		var take := EchoTake.new()
		take.wave = i + 1
		take.stats = sim.player.stats.copy()
		take.stats.add(Stats.DAMAGE_PCT, 0.07 * float(i))
		take.stats.add(Stats.ATTACK_SPEED_PCT, 0.03 * float(i))
		take.weapons.append(Content.weapon(WEAPON_IDS[i % WEAPON_IDS.size()]))
		take.levels.append(i % 4)
		for sample in 121:
			var theta := float(sample) * TAU / 120.0 + float(i) * 0.37
			take.samples.append(Vector2(640.0 + cos(theta) * (150.0 + 15.0 * i),
					380.0 + sin(theta * 2.0) * (90.0 + 8.0 * i)))
		sim.bank.add(take)
		take.age = i % 7
	var merged := sim.bank.merge(sim.bank.takes[0], sim.bank.takes[1])
	if not _require(merged != null and merged.merged and sim.bank.takes.size() == 8,
			"echo fixture must contain eight takes including a real merged route"):
		return {}
	sim.start_wave(12)
	var bot := Bot.new(&"balanced")
	var result := _scenario("eight_echoes_ages_and_merged_route", sim, ECHO_STEPS)
	_capture(result, "start", 0, sim, bot)
	for step in range(1, ECHO_STEPS + 1):
		sim.step(DT, bot.move_dir(sim))
		_observe(result, sim)
		result["completed_steps"] = step
		if step in [60, 180, 300, 420, 720, 1200, 1800, 2400, 2820, 2851, 3000]:
			_capture(result, "step_%d" % step, step, sim, bot)
	_capture(result, "final", ECHO_STEPS, sim, bot)
	var coverage: Dictionary = result["coverage"]
	_require(int(coverage["max_echoes"]) == 8 and int(coverage["rewinding_echo_steps"]) > 0,
			"echo fixture must play all eight actors and exercise reverse playback")
	_require(sim.phase == Sim.Phase.SHOP and sim.bank.takes.size() == 9,
			"echo fixture must finish the wave, age takes, and record one new take")
	return result


func _durable_sim(seed_value: int) -> Sim:
	var sim := Sim.new(seed_value)
	Content.character(&"looper").apply(sim)
	sim.player.stats.values[Stats.MAX_HP] = 100000.0
	sim.player.hp = sim.player.max_hp()
	sim.player.add_weapon(Content.weapon(&"rifle"))
	sim.player.add_weapon(Content.weapon(&"smg"))
	return sim


func _scenario(id: String, sim: Sim, planned_steps: int) -> Dictionary:
	return {"id": id, "seed": sim.run_seed, "planned_steps": planned_steps,
		"completed_steps": 0, "snapshots": [], "coverage": {
			"elite_uids": [], "elite_kinds": [], "rift_warning_steps": 0,
			"rift_active_steps": 0, "max_enemies": 0, "max_projectiles": 0,
			"max_echoes": 0, "rewinding_echo_steps": 0}}


func _step_block(sim: Sim, bot: Bot, result: Dictionary, count: int) -> void:
	for _step in count:
		sim.step(DT, bot.move_dir(sim))
		_observe(result, sim)
		result["completed_steps"] = int(result["completed_steps"]) + 1


func _observe(result: Dictionary, sim: Sim) -> void:
	var coverage: Dictionary = result["coverage"]
	coverage["max_enemies"] = maxi(int(coverage["max_enemies"]), sim.enemies.size())
	coverage["max_projectiles"] = maxi(int(coverage["max_projectiles"]), sim.projectiles.size())
	coverage["max_echoes"] = maxi(int(coverage["max_echoes"]), sim.echoes.size())
	for enemy in sim.enemies:
		if enemy.elite:
			if not (coverage["elite_uids"] as Array).has(enemy.uid):
				(coverage["elite_uids"] as Array).append(enemy.uid)
			if not (coverage["elite_kinds"] as Array).has(String(enemy.elite_kind)):
				(coverage["elite_kinds"] as Array).append(String(enemy.elite_kind))
	for rift in sim.rifts:
		if rift.is_warning():
			coverage["rift_warning_steps"] = int(coverage["rift_warning_steps"]) + 1
		if rift.is_active():
			coverage["rift_active_steps"] = int(coverage["rift_active_steps"]) + 1
	for actor in sim.echoes:
		if actor.rewinding:
			coverage["rewinding_echo_steps"] = int(coverage["rewinding_echo_steps"]) + 1


func _capture(result: Dictionary, label: String, step: int, sim: Sim, bot: Bot) -> void:
	(result["snapshots"] as Array).append({"label": label, "step": step,
		"bot": {"style": String(bot.style), "upgrades": bot.upgrades, "evolutions": bot.evolutions},
		"state": _snapshot(sim)})


func _snapshot(sim: Sim) -> Dictionary:
	var out := _fields(sim, ["run_seed", "endless", "boss_rush", "ascension", "daily_modifier",
		"phase", "wave", "wave_time", "wave_duration", "kills", "wave_kills", "wave_elite_kills",
		"wave_damage_taken", "pending_boons", "boons_taken", "boon_rerolls", "boss_rush_bonus_boon",
		"echo_refreshes", "last_contract_done", "last_contract_success", "last_contract_reward",
		"contracts_accepted", "contracts_completed", "contracts_failed", "collapse_used", "boss_phase",
		"boss_original_max_hp", "echo_silenced", "live_echo", "synergy_damage_per_echo",
		"synergy_haste_per_echo", "second_wind_charges", "last_interest", "last_wave_earned",
		"wave_start_materials", "last_damage_source", "shot_sequence", "player_shots", "_plan_idx",
		"_next_uid", "_boss_silence_cd", "_boss_minion_cd", "_boss_enraged", "_rift_cd"])
	out["rng"] = {"seed": str(sim.rng.seed), "state": str(sim.rng.state)}
	out["hazard_rng"] = {"seed": str(sim.hazard_rng.seed), "state": str(sim.hazard_rng.state)}
	out["player"] = _fields(sim.player, ["pos", "hp", "shield", "weapon_levels", "cooldowns",
		"items", "set_bonus_applied", "materials", "iframes", "facing"])
	out["player"]["stats"] = _json_value(sim.player.stats.values)
	out["player"]["weapons"] = _weapons(sim.player.weapons)
	out["enemies"] = []
	for enemy in sim.enemies:
		(out["enemies"] as Array).append(_enemy(enemy))
	out["projectiles"] = []
	for projectile in sim.projectiles:
		(out["projectiles"] as Array).append(_fields(projectile, ["pos", "vel", "damage", "radius",
			"life", "pierce_left", "knockback", "crit", "source", "weapon_id", "effect",
			"explosion_radius", "explosion_damage", "homing_turn", "hit_uids", "dead"]))
	out["pickups"] = []
	for pickup in sim.pickups:
		(out["pickups"] as Array).append(_fields(pickup, ["pos", "value", "speed", "magnet"]))
	out["pending"] = []
	for pending in sim.pending:
		var entry := _fields(pending, ["pos", "delay", "elite_kind"])
		entry["enemy_id"] = String(pending.def.id)
		(out["pending"] as Array).append(entry)
	out["spawn_plan"] = []
	for event in sim._plan:
		(out["spawn_plan"] as Array).append({"time": event.time,
			"enemy_id": String(event.def.id), "elite_kind": String(event.elite_kind)})
	out["bank"] = []
	for take in sim.bank.takes:
		(out["bank"] as Array).append(_take(take))
	out["echoes"] = []
	for actor in sim.echoes:
		var entry := _fields(actor, ["index", "t", "pos", "rewinding", "cooldowns"])
		entry["bank_index"] = sim.bank.takes.find(actor.take)
		entry["take"] = _take(actor.take)
		(out["echoes"] as Array).append(entry)
	out["recorder"] = _fields(sim.recorder, ["samples", "_acc"])
	out["rifts"] = []
	for rift in sim.rifts:
		(out["rifts"] as Array).append(_fields(rift, ["pos", "radius", "telegraph", "active", "tick"]))
	out["active_contract"] = _contract(sim.active_contract)
	out["shop"] = {"rerolls": sim.shop.rerolls, "contract": _contract(sim.shop.contract),
		"can_undo": sim.shop.can_undo(), "offers": []}
	for offer in sim.shop.offers:
		(out["shop"]["offers"] as Array).append({"id": String(offer.id()),
			"is_weapon": offer.is_weapon(), "price": offer.price, "sold": offer.sold, "locked": offer.locked})
	out["boss"] = _enemy(sim.boss) if sim.boss != null else null
	out["boss_shards"] = []
	for shard in sim.boss_shards:
		(out["boss_shards"] as Array).append(_enemy(shard))
	out["boss_alive_count"] = sim.boss_alive_count()
	out["boss_total_count"] = sim.boss_total_count()
	out["boss_health_ratio"] = sim.boss_health_ratio()
	return out


func _enemy(enemy: EnemyState) -> Dictionary:
	var entry := _fields(enemy, ["uid", "pos", "hp", "max_hp", "speed", "damage", "radius", "knock",
		"dead", "elite", "elite_kind", "shield_arc_override", "shield_reduction_override",
		"death_radius_override", "death_damage_override", "drop_mult"])
	entry["id"] = String(enemy.def.id)
	return entry


func _take(take: EchoTake) -> Dictionary:
	return {"wave": take.wave, "age": take.age, "merged": take.merged,
		"samples": _json_value(take.samples), "weapons": _weapons(take.weapons),
		"levels": _json_value(take.levels), "stats": _json_value(take.stats.values)}


func _contract(contract: AnomalyContract) -> Variant:
	return null if contract == null else _fields(contract, ["kind", "deposit", "reward", "target", "accepted"])


func _weapons(weapons: Array[WeaponDef]) -> Array:
	var out: Array = []
	for weapon in weapons:
		out.append(_fields(weapon, ["id", "family", "rarity", "drop_weight", "evolves_to", "drops",
			"damage", "cooldown", "reach", "projectile_speed", "projectile_radius", "pierce",
			"pellets", "spread_deg", "knockback", "price", "explosion_radius", "explosion_damage", "homing_turn"]))
	return out


func _fields(object: Object, names: Array) -> Dictionary:
	var out: Dictionary = {}
	for field: String in names:
		out[field] = _json_value(object.get(field))
	return out


func _json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var out: Array = []
			for entry: Variant in value:
				out.append(_json_value(entry))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[String(key)] = _json_value(value[key])
			return out
		_:
			return value


func _json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for entry: Variant in value:
				if not _json_safe(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _json_safe(value[key]):
					return false
			return true
		_:
			return false


func _require(condition: bool, message: String) -> bool:
	if not condition:
		_failed = true
		printerr("battle invariants probe FAILED: " + message)
	return condition
