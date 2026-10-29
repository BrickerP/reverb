extends RefCounted


func _take(sim: Sim) -> EchoTake:
	var take := EchoTake.new()
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(32.0, 16.0)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(1)
	take.stats = sim.player.stats.copy()
	take.condition = 43.75
	sim.bank.add(take)
	return take


func _battle() -> Sim:
	var sim := Sim.new(9223372036854775806)
	_take(sim)
	sim.start_run()
	sim.step(0.017, Vector2.RIGHT)
	sim.step(0.011, Vector2.DOWN)
	sim.player.hp = 17.125
	sim.player.iframes = 0.123456789
	sim.player.cooldowns[0] = 0.2718281828
	sim.rng.state = -8547302273828374501
	sim.hazard_rng.state = 7223372036854775806
	var enemy := EnemyState.new()
	enemy.uid = 900
	enemy.def = Content.enemy(&"paradox")
	enemy.pos = sim.player.pos + Vector2(600.0, 0.0)
	enemy.hp = 75.0
	enemy.max_hp = 100.0
	enemy.brain_state = &"windup"
	enemy.brain_time = 0.314159265
	enemy.attack_target = sim.player.pos
	enemy.pin_left = 0.4
	sim.enemies.append(enemy)
	sim.boss = enemy
	sim.boss_shards.append(enemy)
	sim.set("_next_uid", 901)
	var shot := Projectile.new()
	shot.pos = sim.player.pos
	shot.vel = Vector2(13.0, -9.0)
	shot.actor_token = 144 # A retired copy whose attack is still in flight.
	shot.weapon_id = &"rubber_band"
	shot.age = 0.17
	shot.return_time = 0.6
	shot.hit_uids = PackedInt32Array([899, 898])
	sim.projectiles.append(shot)
	var field := AttackField.new()
	field.weapon_id = &"mallet"
	field.style = &"slam"
	field.actor_token = 144
	field.pos = enemy.pos
	field.target = enemy.pos
	field.windup = 0.42
	field.life = 0.5
	field.damage = 12.0
	field.radius = 42.0
	sim.attack_fields.append(field)
	var zone := EnemyZone.new()
	zone.source_uid = enemy.uid
	zone.pos = sim.player.pos + Vector2(0.0, 400.0)
	zone.warning = 0.321
	sim.enemy_zones.append(zone)
	sim.story_progress = {"clues": ["carbon"], "receipt": "carbon", "repairs": 1}
	return sim


func _json_roundtrip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data, "", true, true))


func test_battle_roundtrip_preserves_all_state_aliases_and_int64_rng(c: Check) -> void:
	var sim := _battle()
	var before := RunSnapshot.capture(sim)
	c.ok(not before.is_empty(), "battle captured")
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "battle restores: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), before, "all declared gameplay fields roundtrip exactly")
	c.eq(restored.rng.seed, sim.rng.seed, "signed 64-bit RNG seed exact")
	c.eq(restored.rng.state, sim.rng.state, "signed 64-bit RNG state exact")
	c.eq(restored.hazard_rng.state, sim.hazard_rng.state, "hazard RNG state exact")
	c.ok(restored.boss == restored.enemies[0], "boss aliases world enemy")
	c.ok(restored.boss_shards[0] == restored.boss, "shard aliases boss")
	c.ok(restored.echoes[0].take == restored.bank.takes[0], "actor take aliases bank take")
	c.ok(restored.player.weapons[0] == Content.weapon(&"pistol"), "content is canonical")
	c.eq(restored.projectiles[0].actor_token, 144, "retired copy projectile keeps stable UID")
	c.eq(restored.attack_fields[0].actor_token, 144, "retired delayed attack keeps stable UID")
	c.eq(restored.recorder.get("_acc"), sim.recorder.get("_acc"), "recording fractional accumulator exact")
	var found: Array = []
	restored.grid.query(restored.boss.pos, 10.0, found)
	c.ok(found.has(restored.boss), "derived spatial grid rebuilt")
	for i in 5:
		c.eq(restored.rng.randi(), sim.rng.randi(), "continued main RNG %d" % i)
		c.eq(restored.hazard_rng.randi(), sim.hazard_rng.randi(), "continued hazard RNG %d" % i)
	for i in 15:
		sim.step(0.016, Vector2.LEFT)
		restored.step(0.016, Vector2.LEFT)
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "continued battle matches exactly")


func test_shop_roundtrip_preserves_locks_contract_alias_and_exact_undo(c: Check) -> void:
	var sim := Sim.new(91)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = 7
	var take := _take(sim)
	sim.player.materials = 500
	sim.shop.roll(sim)
	sim.shop.toggle_lock(sim, sim.shop.offers[0])
	sim.shop.repair_echo(sim, take)
	if sim.shop.contract != null:
		sim.shop.accept_contract(sim)
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "shop restores: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), before, "shop fields and undo history exact")
	c.ok(restored.shop.can_undo(), "history remains undoable")
	c.ok(restored.shop.locked_offer() != null, "offer lock persists")
	if sim.active_contract != null:
		c.ok(restored.active_contract == restored.shop.contract, "accepted contract aliases shop contract")
	c.eq(restored.shop.undo(restored).ok, sim.shop.undo(sim).ok, "same undo result")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "undo restores same state")
	sim.shop.reroll(sim)
	restored.shop.reroll(restored)
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "later reroll matches RNG and offers")


func test_invalid_content_types_int64_and_nonfinite_fail_without_mutation(c: Check) -> void:
	var sim := _battle()
	var before := RunSnapshot.capture(sim)
	var damaged := before.duplicate(true)
	damaged.objects[0].fields.run_seed = {"i": "9223372036854775808"}
	c.eq(RunSnapshot.restore(damaged), null, "overflow int64 rejected")
	c.ok(RunSnapshot.last_error != "", "validation failure exposed")
	damaged = before.duplicate(true)
	damaged.objects[0].fields.player = {"ref": 0}
	c.eq(RunSnapshot.restore(damaged), null, "wrong reference type rejected safely")
	damaged = before.duplicate(true)
	damaged.objects[0].fields.player = {"ref": -1}
	c.eq(RunSnapshot.restore(damaged), null, "negative reference rejected")
	damaged = before.duplicate(true)
	damaged.objects[0].type = "res://scripts/game/main.gd"
	c.eq(RunSnapshot.restore(damaged), null, "executable path cannot be restored")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "EnemyState":
			row.fields.def = {"content": ["enemy", "missing_enemy"]}
	c.eq(RunSnapshot.restore(damaged), null, "unknown content rejected")
	c.eq(RunSnapshot.capture(sim), before, "failed restore never touches live run")
	sim.player.hp = NAN
	c.ok(RunSnapshot.capture(sim).is_empty(), "nonfinite live state rejected")


func test_completed_boss_keeps_dead_aliases_after_compaction(c: Check) -> void:
	var sim := _battle()
	sim.boss.dead = true
	sim.enemies.clear()
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "dead boss can exist only in boss aliases")
	if restored != null:
		c.ok(restored.boss == restored.boss_shards[0], "dead boss alias still exact")


func test_typed_field_corruption_is_rejected_without_engine_errors(c: Check) -> void:
	var before := RunSnapshot.capture(_battle())
	# These substitutions previously risked typed setters or array.assign raising
	# runtime errors. Every malformed field must return a visible validation error.
	for type_name in ["PlayerState", "EnemyState", "EchoActor", "Offer"]:
		var damaged := before.duplicate(true)
		for row: Dictionary in damaged.objects:
			if row.type == type_name:
				var field: String = {"PlayerState": "stats", "EnemyState": "def", "EchoActor": "take", "Offer": "weapon"}[type_name]
				row.fields[field] = {"ref": 0}
				c.eq(RunSnapshot.restore(damaged), null, "wrong %s reference type fails safely" % type_name)
				break
	var damaged := before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "Projectile":
			row.fields.hit_uids = {"a": [{"i": "2147483648"}], "t": TYPE_PACKED_INT32_ARRAY}
	c.eq(RunSnapshot.restore(damaged), null, "packed int32 overflow rejected before narrowing")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "Stats":
			row.fields.values = {"d": [[{"n": "max_hp"}, {"ref": 0}]]}
			break
	c.eq(RunSnapshot.restore(damaged), null, "stat dictionary cannot hide an object")
	damaged = before.duplicate(true)
	damaged.objects[0].fields.wave_time = {"f": "000000000000f07f"}
	c.eq(RunSnapshot.restore(damaged), null, "hex infinity rejected")


func test_binary_float_encoding_preserves_negative_zero_and_minimum_int64(c: Check) -> void:
	var sim := Sim.new(-9223372036854775807 - 1)
	sim.start_run()
	# Native JSON full_precision still moves the latter double by one ULP.
	sim.wave_time = 0.9572021790913173
	sim.player.iframes = -0.0
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "minimum int64 seed restores")
	if restored == null:
		return
	c.eq(restored.run_seed, sim.run_seed, "minimum signed int64 exact")
	c.eq(var_to_bytes(restored.wave_time), var_to_bytes(sim.wave_time), "double bits exact beyond decimal JSON parser precision")
	c.eq(var_to_bytes(restored.player.iframes), var_to_bytes(sim.player.iframes), "negative zero sign bit exact")


func test_real_departed_copy_burst_continues_with_original_uid_after_resume(c: Check) -> void:
	var sim := Sim.new(203)
	sim.start_run()
	var first := _take(sim)
	first.weapons[0] = Content.weapon(&"smg")
	first.samples = PackedVector2Array([Vector2(900.0, 900.0)])
	var survivor := _take(sim)
	survivor.samples = PackedVector2Array([Vector2(300.0, 300.0)])
	sim.start_wave(3)
	sim.set("_plan", [] as Array[SpawnEvent])
	var enemy := EnemyState.new()
	enemy.uid = 901
	sim.set("_next_uid", 902)
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = Vector2(1050.0, 900.0)
	enemy.hp = 10000.0
	enemy.max_hp = enemy.hp
	sim.enemies.append(enemy)
	sim.grid.insert(enemy)
	Combat.fire(sim, sim.echoes[0].pos, enemy.pos, Content.weapon(&"smg"), 0,
		1.0, first.stats, 1.0, 0, first.tint(), 0, false, first.uid)
	c.eq(sim.projectiles.size(), 1, "real burst has an in-flight projectile")
	c.eq(sim.attack_fields.size(), 1, "real burst has delayed releases")
	sim.echoes[0].pos = Vector2(300.0, 300.0)
	c.ok(sim.select_echo(first.uid) and sim.retire_selected_echo(), "firing copy genuinely retires")
	c.eq(sim.echoes[0].take.uid, survivor.uid, "old source slot now belongs to another take")
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "departed-copy attack resumes")
	if restored == null:
		return
	var hits: Array[DamageInfo] = []
	restored.damage_event.connect(func(info: DamageInfo) -> void: hits.append(info))
	for i in 60:
		Combat.tick_fields(sim, 0.01)
		Combat.tick_fields(restored, 0.01)
		Combat.step_projectiles(sim, 0.01)
		Combat.step_projectiles(restored, 0.01)
	c.eq(hits.size(), 3, "all three real burst rounds hit after resume")
	for hit: DamageInfo in hits:
		c.eq(hit.actor_token, first.uid, "actual delayed hit belongs to departed UID")
		c.eq(hit.source_tint, first.tint(), "actual delayed hit keeps departed tint")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "retired burst continuation remains exact")


func test_semantic_corruption_and_disconnected_graph_rejected_before_resume(c: Check) -> void:
	var before := RunSnapshot.capture(_battle())
	for bad_index in [-1, 99999]:
		var damaged := before.duplicate(true)
		damaged.objects[0].fields._plan_idx = {"i": str(bad_index)}
		c.eq(RunSnapshot.restore(damaged), null, "invalid spawn cursor cannot become live")
	var damaged := before.duplicate(true)
	damaged.objects[0].fields._next_uid = {"i": "1"}
	c.eq(RunSnapshot.restore(damaged), null, "stale enemy UID counter rejected")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "Stats":
			row.fields.values.d.pop_back()
			break
	c.eq(RunSnapshot.restore(damaged), null, "missing stat cannot silently become zero")
	damaged = before.duplicate(true)
	damaged.objects.append(damaged.objects[0].duplicate(true))
	c.eq(RunSnapshot.restore(damaged), null, "second Sim rejected before object allocation")
	damaged = before.duplicate(true)
	damaged.objects.append({"type": "Pickup", "fields": {"pos": {"v": [{"f": "0000000000000000"}, {"f": "0000000000000000"}]},
		"value": {"i": "1"}, "speed": {"f": "0000000000000000"}, "magnet": false}})
	c.eq(RunSnapshot.restore(damaged), null, "unreachable object rejected")


func test_corrupt_contract_economics_and_undo_phase_cannot_change_live_state(c: Check) -> void:
	var sim := Sim.new(317)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = 5
	sim.player.materials = 500
	sim.shop.roll(sim)
	var take := _take(sim)
	sim.shop.repair_echo(sim, take)
	var before := RunSnapshot.capture(sim)
	var damaged := before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "ShopState":
			row.fields.phase = {"i": "99"}
	c.eq(RunSnapshot.restore(damaged), null, "invalid undo phase is rejected before Undo can install it")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "AnomalyContract":
			row.fields.deposit = {"i": "-100"}
	c.eq(RunSnapshot.restore(damaged), null, "negative deposit cannot mint materials after resume")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "AnomalyContract":
			row.fields.kind = {"n": "unknown_contract"}
	c.eq(RunSnapshot.restore(damaged), null, "unknown contract ID rejected")
	damaged = before.duplicate(true)
	damaged.objects[0].fields.daily_modifier = {"n": "unknown_anomaly"}
	c.eq(RunSnapshot.restore(damaged), null, "unknown daily anomaly rejected")
	c.ok(sim.shop.accept_contract(sim), "real contract accepted")
	damaged = RunSnapshot.capture(sim)
	for row: Dictionary in damaged.objects:
		if row.type == "AnomalyContract":
			var different := row.duplicate(true)
			damaged.objects[0].fields.active_contract = {"ref": damaged.objects.size()}
			damaged.objects.append(different)
			break
	c.eq(RunSnapshot.restore(damaged), null, "accepted contract must retain its real shop alias")
