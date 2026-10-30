extends SceneTree
# Headless CPU comparison for the same legal population used by the native
# presentation probe. Timings exclude snapshot encoding and event serialization.
# Usage: godot --headless --path . --script res://tools/theme_performance_probe.gd -- output.json

const LOADOUT: Array[StringName] = [&"smg", &"smg", &"smg", &"flechette", &"stapler", &"paper_plane"]
const WARMUP := 120
const MEASURE := 360
var _events: Array = []


func _initialize() -> void:
	var sim := _build()
	if sim == null:
		quit(1)
		return
	sim.damage_event.connect(func(info: DamageInfo) -> void:
		_events.append(["damage", info.target_uid, info.amount, info.source, info.actor_token,
			str(info.weapon_id), str(info.effect), info.crit, info.pos.x, info.pos.y]))
	sim.support_event.connect(func(info: Dictionary) -> void: _events.append(["support", info.duplicate(true)]))
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void:
		_events.append(["shot", info.sequence, info.source, info.actor_token, str(info.weapon_id),
			info.origin.x, info.origin.y, info.target.x, info.target.y, info.count, info.level]))
	var times: Array[int] = []
	var peak_projectiles := 0
	var checkpoints: Array[String] = []
	for frame in WARMUP + MEASURE:
		var start := Time.get_ticks_usec()
		sim.step(1.0 / 60.0, Vector2.ZERO)
		var elapsed := Time.get_ticks_usec() - start
		if frame >= WARMUP:
			times.append(elapsed)
			peak_projectiles = maxi(peak_projectiles, sim.projectiles.size())
		if frame % 60 == 59:
			checkpoints.append(JSON.stringify(RunSnapshot.capture(sim)).sha256_text())
	var total := 0
	for time in times:
		total += time
	times.sort()
	var result := {"fixture": "96 enemies / 8 Echoes / 12 owned supports; unchanged legal native pressure fixture",
		"warmup_steps": WARMUP, "measured_steps": MEASURE,
		"cpu_avg_ms": float(total) / float(times.size()) / 1000.0,
		"cpu_p99_ms": float(times[mini(times.size() - 1, int(times.size() * 0.99))]) / 1000.0,
		"cpu_max_ms": float(times.back()) / 1000.0, "peak_projectiles": peak_projectiles,
		"event_count": _events.size(), "event_sha256": JSON.stringify(_events).sha256_text(),
		"checkpoint_sha256": checkpoints, "final_snapshot_sha256": JSON.stringify(RunSnapshot.capture(sim)).sha256_text(),
		"rng_state": str(sim.rng.state), "hazard_rng_state": str(sim.hazard_rng.state),
		"last_enemies": sim.enemies.size(), "last_echoes": sim.echoes.size(), "last_supports": sim.support_units.size()}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var output := FileAccess.open(args[0], FileAccess.WRITE)
		if output == null:
			printerr("Could not write CPU comparison result")
			quit(1)
			return
		output.store_string(JSON.stringify(result, "  ") + "\n")
	print("theme CPU probe: " + JSON.stringify(result))
	quit()


func _build() -> Sim:
	var sim := Sim.new(20261023)
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for id in LOADOUT:
		sim.player.add_weapon(Content.weapon(id))
	sim.player.pos = Vector2(1240.0, 200.0)
	sim.player.stats.values[Stats.RANGE_PCT] = 2.0
	sim.player.stats.values[Stats.ATTACK_SPEED_PCT] = 2.0
	sim.player.stats.values[Stats.ECHO_SLOTS] = 8.0
	sim.player.stats.values[Stats.ECHO_DURATION] = 600.0
	sim.bank.takes.clear()
	for index in 8:
		var take := EchoTake.new()
		take.wave = index + 1
		for id in LOADOUT:
			take.weapons.append(Content.weapon(id))
			take.levels.append(0)
		take.stats = sim.player.stats.copy()
		for sample in 240:
			take.samples.append(Vector2(1240.0, 200.0 + (float(index) - 3.5) * 3.0))
		sim.bank.add(take)
		take.condition = 15.0 + float(index) * 10.0
		take.merged = index % 3 == 0
	var order := AnomalyContract.new()
	order.kind = &"audit"
	order.accepted = true
	order.deposit = 0
	sim.active_contract = order
	sim.contracts_accepted = 1
	Expedition.on_order_purchased(sim, order)
	sim.start_wave(12)
	sim.wave_duration = 60.0
	sim.activate_character_skill()
	sim._plan.clear()
	sim._plan_idx = 0
	var definitions: Array[EnemyDef] = []
	for definition in Content.enemies():
		if not definition.is_boss:
			definitions.append(definition)
	for index in Sim.MAX_ORDINARY_ENEMIES:
		var arrival := PendingSpawn.new()
		arrival.def = definitions[index % definitions.size()]
		arrival.pos = Vector2(1740.0 + float(index % 8) * 4.0, 170.0 + float(index % 13) * 5.0)
		if not sim._materialize(arrival):
			return null
		var enemy: EnemyState = sim.enemies.back()
		enemy.max_hp = 1.0e9
		enemy.hp = enemy.max_hp
		enemy.damage = 0.0
		enemy.pin_left = 120.0
	var arrival := PendingSpawn.new()
	arrival.def = Content.enemy(&"paradox")
	arrival.pos = Vector2(1740.0, 250.0)
	if not sim._materialize(arrival):
		return null
	sim.boss.max_hp = 1.0e9
	sim.boss.hp = 4.9e8
	sim.boss_original_max_hp = 1.0e9
	sim._begin_boss_phase2()
	for boss: EnemyState in sim.boss_shards:
		boss.damage = 0.0
		boss.pin_left = 120.0
	sim.echo_silenced = 0.0
	sim._boss_silence_cd = 100.0
	sim._boss_minion_cd = 100.0
	var kinds: Array[StringName] = [&"hound", &"turret", &"repair_station", &"paper_tree", &"decoy",
		&"turret", &"hound", &"turret", &"repair_station", &"paper_tree", &"decoy", &"turret"]
	for index in kinds.size():
		var owner: EchoActor = sim.echoes[index % sim.echoes.size()]
		var offset := Vector2(140.0 + float(index % 6) * 9.0, 35.0 + float(index / 6) * 35.0)
		if kinds[index] in [&"repair_station", &"paper_tree"]:
			offset = Vector2(45.0 + float(index % 3) * 12.0, 35.0 + float(index / 6) * 25.0)
		var position := WorldArena.move_body(sim.player.pos, offset, SupportSystem.UNIT_RADIUS)
		if not SupportSystem.spawn(sim, kinds[index], position, owner.take.uid):
			return null
	if sim.enemies.size() != 96 or sim.echoes.size() != 8 or sim.support_units.size() != 12:
		return null
	var snapshot := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(snapshot)
	if snapshot.is_empty() or restored == null or RunSnapshot.capture(restored) != snapshot:
		printerr("Legal CPU fixture failed exact snapshot roundtrip")
		return null
	return sim
