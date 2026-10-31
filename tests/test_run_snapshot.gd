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
	var order_offer: Offer
	for offer: Offer in sim.shop.offers:
		if offer.is_contract():
			order_offer = offer
			break
	c.ok(order_offer != null and sim.shop.apply(ShopResult.BUY, sim, order_offer).ok, "work order purchases through actual offer")
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "shop restores: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), before, "shop fields and undo history exact")
	c.ok(restored.shop.can_undo(), "history remains undoable")
	c.ok(restored.shop.locked_offer() != null, "offer lock persists")
	if sim.active_contract != null:
		var active_found := false
		for offer: Offer in restored.shop.offers:
			active_found = active_found or offer.contract == restored.active_contract
		c.ok(active_found, "accepted work order aliases its actual offer")
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
	var actual_order: Offer
	for offer: Offer in sim.shop.offers:
		if offer.is_contract():
			actual_order = offer
			break
	c.ok(actual_order != null and sim.shop.apply(ShopResult.BUY, sim, actual_order).ok, "real work order purchased")
	damaged = RunSnapshot.capture(sim)
	for row: Dictionary in damaged.objects:
		if row.type == "AnomalyContract":
			var different := row.duplicate(true)
			damaged.objects[0].fields.active_contract = {"ref": damaged.objects.size()}
			damaged.objects.append(different)
			break
	c.eq(RunSnapshot.restore(damaged), null, "accepted contract must retain its real shop alias")


func _expedition_sim(role: StringName = &"looper", stage: int = 2) -> Sim:
	var sim := Sim.new(8642)
	Content.character(role).apply(sim)
	sim.start_run()
	var take := _take(sim)
	take.wave = 1
	take.inherited_skill = &"arc"
	take.merge_trait = &"skill"
	take.archived = true
	sim.start_wave(stage)
	sim._plan.clear()
	sim.player.materials = 500
	return sim


func _buy_order(sim: Sim, kind: StringName) -> ShopResult:
	# Clinical shop fixtures retain their stated cash/loadout, but settle any
	# ambient work before switching phase just as the real wave exit does.
	BureauEvents.finish_wave(sim, true)
	sim.phase = Sim.Phase.SHOP
	var offer := Offer.new()
	offer.contract = AnomalyContract.create(kind, sim.next_wave_number())
	offer.price = offer.contract.deposit
	sim.shop.offers.clear()
	sim.shop.offers.append(offer)
	return sim.shop.apply(ShopResult.BUY, sim, offer)


func _encoded(value: Variant) -> Variant:
	return RunSnapshot.encode_envelope({"value": value}).d[0][1]


func test_v4_active_role_support_loan_and_echo_metadata_continue_exactly(c: Check) -> void:
	var sim := _expedition_sim(&"conductor")
	c.ok(_buy_order(sim, &"credit").ok, "actual loan order purchases")
	sim.start_wave(3)
	sim._plan.clear()
	c.ok(sim.activate_character_skill(), "actual relay starts before save")
	c.ok(SupportSystem.spawn(sim, &"hound", sim.player.pos, sim.bank.takes[0].uid), "Echo-owned pet uses actual stable source")
	c.ok(SupportSystem.spawn(sim, &"paper_tree", sim.player.pos), "production unit is actual bounded state")
	sim.player.weapon_investments[0] = 27
	var before := RunSnapshot.capture(sim)
	c.eq(before.version, 4, "new schema has a clean version break")
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "role/support/credit state resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), before, "all role/support/Echo/loan fields roundtrip exactly")
	c.eq(restored.character_id, &"conductor", "role identity survives")
	c.eq(restored.character_energy, 0.0, "spent 100 energy is not refunded by resume")
	c.eq(restored.role_effects.relay_pulses, 3, "finite relay budget survives")
	c.eq(restored.support_units[0].actor_token, restored.bank.takes[0].uid, "pet retains stable Echo source")
	c.eq(restored.expedition.debt, 40, "unpaid credit remains real debt")
	c.ok(restored.bank.takes[0].archived, "archive provenance survives")
	c.eq(restored.bank.takes[0].inherited_skill, &"arc", "donor retirement trait survives")
	c.eq(restored.player.weapon_investments, [27], "paid investment survives")
	for _frame in 30:
		sim.step(0.02, Vector2.LEFT)
		restored.step(0.02, Vector2.LEFT)
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "actual resumed relay/pet/production/loan battle remains deterministic")


func test_v4_shop_graded_offer_assembly_and_two_undos_preserve_economy(c: Check) -> void:
	var sim := _expedition_sim()
	BureauEvents.finish_wave(sim, true)
	sim.phase = Sim.Phase.SHOP
	sim.player.weapon_levels[0] = 2
	sim.player.weapon_investments[0] = 14
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"pistol")
	offer.weapon_level = 2
	offer.price = 35
	sim.shop.offers = [offer]
	c.ok(sim.shop.toggle_lock(sim, offer), "graded offer can be held")
	c.ok(sim.shop.apply(ShopResult.BUY, sim, offer).ok, "graded weapon really purchases")
	c.ok(sim.shop.combine_weapons(sim, 0, 1).ok, "same-grade duplicate really combines")
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "graded assembly shop resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(restored.player.weapon_levels, [3], "assembled level is retained")
	c.eq(restored.shop.offers[0].weapon_level, 2, "offer grade is retained independently")
	for _undo in 2:
		c.ok(sim.shop.undo(sim).ok and restored.shop.undo(restored).ok, "saved assembly and purchase undo")
		c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "undo restores exact graded inventory and paid ledger")
	c.eq(restored.player.materials, 500, "two undos neither mint nor lose purchase cash")
	c.eq(restored.player.weapon_investments, [14], "two undos restore original paid ledger")


func test_v4_loan_purchase_alias_and_full_undo_survive_resume(c: Check) -> void:
	var sim := _expedition_sim()
	c.ok(_buy_order(sim, &"credit").ok, "credit purchases through actual offer transaction")
	c.ok(sim.shop.apply(ShopResult.UPGRADE, sim, null, 0).ok, "equipment purchase follows loan")
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "credit undo history resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.ok(restored.active_contract == restored.shop.offers[0].contract, "active order retains real Offer object alias")
	for _undo in 2:
		c.ok(sim.shop.undo(sim).ok and restored.shop.undo(restored).ok, "saved credit and refit undo")
		c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "credit undo restores exact order alias, debt and cash")
	c.eq(restored.player.materials, 500, "loan cash is removed when purchase is undone")
	c.eq(restored.expedition.debt, 0, "loan debt is removed in the same undo")
	c.eq(restored.expedition.credit_taken, 0, "loan counter is removed in the same undo")
	c.eq(restored.active_contract, null, "loan undo does not leave accepted work behind")


func test_v4_manual_repayment_and_loan_alias_undo_resume_exactly(c: Check) -> void:
	var sim := _expedition_sim()
	c.ok(_buy_order(sim, &"credit").ok, "repayment starts from a real loan order")
	var before_repayment := RunSnapshot.capture(sim)
	c.ok(sim.shop.apply(ShopResult.PAY_DEBT, sim).ok, "voluntary repayment clears borrowed funds")
	c.eq(sim.expedition["debt"], 0, "paid debt is cleared before save")
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "paid loan and undo history resume: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.ok(restored.active_contract == restored.shop.offers[0].contract, "repayment preserves active loan Offer alias")
	c.ok(restored.shop.undo(restored).ok and sim.shop.undo(sim).ok, "one undo reverses repayment on both runs")
	c.eq(RunSnapshot.capture(restored), before_repayment, "resumed undo restores exact prior debt, cash and active work")
	c.eq(RunSnapshot.capture(sim), before_repayment, "live undo restores the same transaction state")
	c.ok(restored.shop.undo(restored).ok and sim.shop.undo(sim).ok, "next undo reverses the original loan")
	c.eq(restored.expedition["debt"], 0, "loan undo does not resurrect repaid debt")
	c.eq(restored.player.materials, 500, "two financial undos restore original cash")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "repayment and loan undo stay identical after restore")


func test_v4_boss_negotiation_resumes_into_actual_recruitment_and_story(c: Check) -> void:
	var sim := _expedition_sim(&"looper", 3)
	c.ok(_buy_order(sim, &"recruit").ok, "recruitment work order purchases")
	sim.start_wave(4)
	sim._plan.clear()
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = WorldArena.move_body(sim.player.pos, Vector2(180, 0), 48.0)
	sim._materialize(spawn)
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	c.ok(Expedition.is_negotiating(sim), "actual lethal victory opens negotiation")
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "defeated boss decision resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), before, "negotiation timer/body/interactable/order aliases are exact")
	for candidate: Sim in [sim, restored]:
		candidate.player.pos = candidate.boss.pos
		c.ok(candidate.choose_negotiation(&"stop_press"), "resumed explicit press-stop choice really recruits boss")
		candidate.step(0.01, Vector2.ZERO)
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "post-negotiation companion/order/story settlement matches")
	c.eq(restored.support_units[0].kind, &"recruited_foreman", "recruited companion remains authoritative")
	c.ok(StoryLedger.discovered(restored).has(&"recruited_foreman"), "actual recruitment yields persistent story clue")
	c.ok(StoryLedger.discovered(restored).has(&"order_recruit"), "actual recruit work order has story consequence")


func test_v4_each_role_effect_can_resume_without_extra_energy_or_bodies(c: Check) -> void:
	for role: StringName in Content.characters():
		var sim := _expedition_sim(role)
		if role == &"solo":
			sim.bank.takes.clear()
			sim.echoes.clear()
			sim.selected_echo_uid = 0
		c.ok(sim.activate_character_skill(), "%s actual role ability activates" % role)
		var before := RunSnapshot.capture(sim)
		var restored := RunSnapshot.restore(_json_roundtrip(before))
		c.ok(restored != null, "%s actual ability state resumes: %s" % [role, RunSnapshot.last_error])
		if restored == null:
			continue
		c.eq(RunSnapshot.capture(restored), before, "%s exact active effect/energy/cooldown" % role)
		for _frame in 10:
			sim.step(0.02, Vector2.RIGHT)
			restored.step(0.02, Vector2.RIGHT)
		c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "%s continued ability matches without duplicating effects" % role)


func test_v4_rejects_bad_roles_units_orders_ledgers_and_new_state_versions(c: Check) -> void:
	var sim := _expedition_sim(&"conductor")
	c.ok(sim.activate_character_skill(), "valid effect fixture activates")
	c.ok(SupportSystem.spawn(sim, &"hound", sim.player.pos), "valid support fixture spawns")
	var before := RunSnapshot.capture(sim)
	var damaged := before.duplicate(true)
	damaged.version = 1
	c.eq(RunSnapshot.restore(damaged), null, "old schema is rejected instead of maintaining legacy state")
	for energy in [-1.0, 101.0]:
		damaged = before.duplicate(true)
		damaged.objects[0].fields.character_energy = _encoded(energy)
		c.eq(RunSnapshot.restore(damaged), null, "out-of-range energy rejected")
	damaged = before.duplicate(true)
	damaged.objects[0].fields.character_id = {"n": "unknown_role"}
	c.eq(RunSnapshot.restore(damaged), null, "unknown character cannot dispatch an ability")
	var effects := sim.role_effects.duplicate(true)
	effects.relay_pulses = 100
	damaged = before.duplicate(true)
	damaged.objects[0].fields.role_effects = _encoded(effects)
	c.eq(RunSnapshot.restore(damaged), null, "relay cannot gain unbounded extra pulses")
	var units := sim.support_units.duplicate(true)
	units[0].kind = &"unknown_support"
	damaged = before.duplicate(true)
	damaged.objects[0].fields.support_units = _encoded(units)
	c.eq(RunSnapshot.restore(damaged), null, "noncanonical support kind rejected")
	units = sim.support_units.duplicate(true)
	units[0].charges = 99
	damaged = before.duplicate(true)
	damaged.objects[0].fields.support_units = _encoded(units)
	c.eq(RunSnapshot.restore(damaged), null, "support production charges cannot be minted")
	var expedition := sim.expedition.duplicate(true)
	expedition.debt = 201
	damaged = before.duplicate(true)
	damaged.objects[0].fields.expedition = _encoded(expedition)
	c.eq(RunSnapshot.restore(damaged), null, "unbounded debt rejected")
	for investments in [[], [-1]]:
		damaged = before.duplicate(true)
		for row: Dictionary in damaged.objects:
			if row.type == "PlayerState":
				row.fields.weapon_investments = _encoded(investments)
		c.eq(RunSnapshot.restore(damaged), null, "misaligned or negative paid ledger rejected")
	var items := sim.interactables.duplicate(true)
	items[0].cost = -100
	damaged = before.duplicate(true)
	damaged.objects[0].fields.interactables = _encoded(items)
	c.eq(RunSnapshot.restore(damaged), null, "world interaction cannot mint cash through negative cost")
	c.eq(RunSnapshot.capture(sim), before, "all malformed restores leave authoritative run untouched")


func test_v4_rejects_bad_grade_and_plain_undo_order_metadata(c: Check) -> void:
	var sim := _expedition_sim()
	c.ok(_buy_order(sim, &"credit").ok, "valid work-order undo fixture")
	c.ok(sim.shop.apply(ShopResult.UPGRADE, sim, null, 0).ok, "valid equipment undo fixture")
	var before := RunSnapshot.capture(sim)
	var damaged := before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "Offer":
			row.fields.weapon_level = {"i": "4"}
	c.eq(RunSnapshot.restore(damaged), null, "offer grade cannot exceed authored maximum")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "ShopState":
			row.fields.weapon_investments = _encoded([-3])
	c.eq(RunSnapshot.restore(damaged), null, "undo ledger cannot restore negative investments")
	damaged = before.duplicate(true)
	for row: Dictionary in damaged.objects:
		if row.type == "ShopState":
			row.fields.active_order = _encoded({"kind": "credit", "deposit": 0, "reward": 0, "target": 8, "accepted": false})
	c.eq(RunSnapshot.restore(damaged), null, "undo cannot reactivate unaccepted work order")


func test_v4_missing_echo_levels_keep_existing_level_zero_semantics(c: Check) -> void:
	var sim := _expedition_sim()
	sim.bank.takes[0].levels.clear()
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "manual recording fixture can omit levels: %s" % RunSnapshot.last_error)
	if restored != null:
		c.eq(restored.bank.takes[0].levels.size(), 0, "missing levels remain exact rather than invented")
		c.eq(restored.bank.takes[0].level_at(0), 0, "omitted level retains existing zero fallback")
		c.eq(RunSnapshot.capture(restored), before, "fixture semantics preserve exact serialized state")


func _interact_kind(sim: Sim, kind: StringName) -> bool:
	for item in sim.interactables:
		if item["kind"] == kind and not item["used"]:
			sim.player.pos = item["pos"]
			return sim.interact()
	return false


func _recruit_boss(sim: Sim, stage: int, kind: StringName, choice: StringName) -> bool:
	sim.wave = stage - 1
	if not _buy_order(sim, &"recruit").ok:
		return false
	sim.start_wave(stage)
	sim._plan.clear()
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(kind)
	spawn.pos = WorldArena.move_body(sim.player.pos, Vector2(180, 0), 48.0)
	if not sim._materialize(spawn):
		return false
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	if not sim.choose_negotiation(choice):
		return false
	sim._end_wave()
	return true


func test_v4_actual_recorded_machine_work_resumes_without_duplicate_execution(c: Check) -> void:
	var sim := Sim.new(941)
	sim.start_run()
	sim._plan.clear()
	var site: Dictionary = sim.interactables[1]
	sim.player.pos = site["pos"]
	sim.recorder.begin(sim.player.pos)
	sim.recorder.record(sim.player.pos, 6.2)
	site["cooldown"] = 0.0
	c.ok(sim.interact(), "actual player conveyor interaction succeeds")
	c.eq(sim.recorder.work_actions.size(), 1, "actual interaction records one key work event")
	sim._end_wave()
	sim.start_wave(2)
	sim._plan.clear()
	for _frame in 61:
		sim.step(0.1, Vector2.ZERO)
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(_json_roundtrip(before))
	c.ok(restored != null, "battle before recorded key work resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	var events: Array[Dictionary] = []
	restored.echo_work_performed.connect(func(info: Dictionary) -> void: events.append(info.duplicate(true)))
	for _frame in 4:
		sim.step(0.1, Vector2.ZERO)
		restored.step(0.1, Vector2.ZERO)
	c.eq(events.size(), 1, "crossing saved event time emits once")
	if not events.is_empty():
		c.ok(events[0]["success"], "recorded conveyor work operates the real matching machine")
	c.eq(restored.echoes[0].work_cursor, 1, "consumed cursor persists beyond event")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "work cost, world direction, route and clocks continue exactly")
	var after_work := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(restored)))
	c.ok(after_work != null, "consumed event also resumes")
	if after_work != null:
		var repeated: Array[Dictionary] = []
		after_work.echo_work_performed.connect(func(info: Dictionary) -> void: repeated.append(info))
		after_work.step(0.1, Vector2.ZERO)
		c.eq(repeated.size(), 0, "resume cannot repeat an already performed key work event")


func test_v4_world_rescue_repair_and_injury_survive_all_act_transitions(c: Check) -> void:
	var sim := Sim.new(942)
	sim.start_run()
	sim._plan.clear()
	sim.expedition["world"]["workers"][0]["hp"] = 13.0
	c.ok(_interact_kind(sim, &"rescue"), "ambient worker is actually saved without buying an order")
	c.ok(_interact_kind(sim, &"repair"), "ambient fault is actually repaired without buying an order")
	for stage in [5, 9]:
		sim._end_wave()
		sim.start_wave(stage)
		sim._plan.clear()
		var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
		c.ok(restored != null, "world memory resumes in act %d: %s" % [int((stage - 1) / 4) + 1, RunSnapshot.last_error])
		if restored == null:
			return
		c.eq(restored.expedition["world"], sim.expedition["world"], "world history and closed rows retain exact state between acts")
		var world: Dictionary = restored.expedition["world"]
		c.eq(world["machines"][0]["status"], &"repaired", "prior repaired machine never becomes a new paid problem")
		c.eq(world["workers"][0]["state"], &"safe", "real survivor remains safe in later acts")
		c.eq(world["workers"][0]["hp"], 13.0, "injured survivor health is not silently reset by an act transition")
		c.ok(world["witnesses"].has(&"worker_1"), "same living survivor remains a named witness")
		for _frame in 4:
			sim.step(0.02, Vector2.ZERO)
			restored.step(0.02, Vector2.ZERO)
		c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "world continuation stays deterministic across act boundary")


func test_v4_deploy_and_credit_restore_one_atomic_undo_with_real_roster(c: Check) -> void:
	var sim := Sim.new(943)
	sim.start_run()
	sim.player.materials = 500
	c.ok(_recruit_boss(sim, 4, &"foreman", &"stop_press"), "Foreman signs through actual protected negotiation")
	sim.support_units[0]["hp"] = 17.0
	sim.support_units[0]["life"] = 90.0
	c.ok(_recruit_boss(sim, 8, &"collector", &"settle_debt"), "Collector signs and benches previous ally")
	c.eq(sim.support_units.size(), 1, "only current companion has a physical battle unit")
	c.ok(_buy_order(sim, &"credit").ok, "actual credit transaction precedes deployment")
	var before := RunSnapshot.capture(sim)
	var quote := sim.shop.quote(ShopResult.DEPLOY_COMPANION, sim, null, -1, &"foreman")
	c.ok(quote.ok, "canonical deployment quote accepts living benched ally")
	c.eq(RunSnapshot.capture(sim), before, "deployment quote is pure")
	c.ok(sim.shop.apply(ShopResult.DEPLOY_COMPANION, sim, null, -1, &"foreman").ok, "canonical deployment applies")
	c.eq(sim.support_units[0]["kind"], &"recruited_foreman", "actual unit swaps to selected roster member")
	c.eq(sim.support_units[0]["hp"], 17.0, "deployment retains old ally's actual injured health")
	c.eq(sim.support_units[0]["life"], 90.0, "deployment retains old ally's remaining life")
	var restored := RunSnapshot.restore(_json_roundtrip(RunSnapshot.capture(sim)))
	c.ok(restored != null, "deployment and credit undo history resume: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.ok(restored.active_contract == restored.shop.offers[0].contract, "deployment never detaches active credit Offer alias")
	c.ok(restored.shop.undo(restored).ok and sim.shop.undo(sim).ok, "one undo restores the complete deployment transaction")
	c.eq(RunSnapshot.capture(sim), before, "one deployment undo restores funds, roster, support UID, world history and order alias")
	c.eq(RunSnapshot.capture(restored), before, "resumed deployment undo is exact")
	c.ok(restored.shop.undo(restored).ok and sim.shop.undo(sim).ok, "next undo reverses credit independently")
	c.eq(restored.expedition["debt"], 0, "credit debt is removed by its own transaction")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "credit undo after deployment remains exact")


func test_v4_pending_final_resolution_is_exact_and_each_exit_applies_once(c: Check) -> void:
	for choice in [&"released", &"collective", &"takeover"]:
		var sim := Sim.new(944)
		sim.start_run()
		c.ok(_interact_kind(sim, &"rescue"), "actual survivor supports collective exit")
		sim.start_wave(12)
		sim._plan.clear()
		sim.player.materials = 100
		sim._end_wave()
		c.eq(sim.phase, Sim.Phase.RESOLUTION, "final battle waits for an intentional choice")
		var before := RunSnapshot.capture(sim)
		var restored := RunSnapshot.restore(_json_roundtrip(before))
		c.ok(restored != null, "pending final resolution resumes: %s" % RunSnapshot.last_error)
		if restored == null:
			continue
		c.eq(RunSnapshot.capture(restored), before, "unspent choice and all pending outcomes are exact")
		c.eq(Expedition.exit_options(restored), Expedition.exit_options(sim), "resumed costs, availability and reasons agree")
		for candidate: Sim in [sim, restored]:
			c.ok(candidate.choose_exit(choice), "explicit chosen exit applies")
			c.ok(not candidate.choose_exit(choice), "chosen outcome cannot apply twice")
		c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "actual chosen ending and survivor/staff outcomes continue exactly")
		c.eq(restored.expedition["ending"], choice, "receipt stores the actual explicit choice")


func test_v4_rejects_disconnected_crew_and_staff_inside_saved_undo(c: Check) -> void:
	var sim := Sim.new(945)
	sim.start_run()
	sim.player.materials = 500
	c.ok(_recruit_boss(sim, 4, &"foreman", &"stop_press"), "actual signed companion establishes valid roster")
	sim.shop.clear_history()
	sim.shop._push_history(ShopState.capture(sim))
	var before := RunSnapshot.capture(sim)
	c.ok(RunSnapshot.restore(_json_roundtrip(before)) != null, "connected crew undo resumes")
	for corruption in [&"roster_uid", &"no_unit", &"no_roster", &"staff_uid"]:
		var damaged := before.duplicate(true)
		var state := ShopState.capture(sim)
		match corruption:
			&"roster_uid": state.expedition["world"]["roster"][0]["uid"] = 999
			&"no_unit": state.support_units.clear()
			&"no_roster": state.expedition["world"]["roster"].clear()
			&"staff_uid": state.expedition["world"]["staff_uid"] = 999
		for row: Dictionary in damaged["objects"]:
			if row["type"] == "ShopState":
				row["fields"]["expedition"] = _encoded(state.expedition)
				row["fields"]["support_units"] = _encoded(state.support_units)
		c.eq(RunSnapshot.restore(damaged), null, "undo rejects disconnected %s before it can become live" % corruption)
	c.eq(RunSnapshot.capture(sim), before, "invalid undo data cannot mutate authoritative crew")


func test_v4_rejects_old_runs_unknown_world_rows_caps_and_forged_work_cursors(c: Check) -> void:
	var sim := _expedition_sim()
	var before := RunSnapshot.capture(sim)
	for version in [1, 2, 3, 5]:
		var damaged := before.duplicate(true)
		damaged["version"] = version
		c.eq(RunSnapshot.restore(damaged), null, "only the direct current v4 runtime shape is loaded")
	for corruption in [&"unknown", &"workers", &"roster", &"history", &"pending"]:
		var state := sim.expedition.duplicate(true)
		match corruption:
			&"unknown": state["world"]["unknown"] = 1
			&"workers": state["world"]["workers"].resize(13)
			&"roster": state["world"]["roster"].resize(4)
			&"history": state["world"]["history"].resize(49)
			&"pending": state["world"]["resolution_pending"] = true
		var damaged := before.duplicate(true)
		damaged["objects"][0]["fields"]["expedition"] = _encoded(state)
		c.eq(RunSnapshot.restore(damaged), null, "closed world type/cap/phase validation rejects %s" % corruption)
	for field in ["work_cursor", "work_cycle"]:
		var damaged := before.duplicate(true)
		for row: Dictionary in damaged["objects"]:
			if row["type"] == "EchoActor":
				row["fields"][field] = _encoded(99)
		c.eq(RunSnapshot.restore(damaged), null, "forged replay cursor cannot replay old work after resume")
	var valid_work := {"time": 0.0, "kind": &"press", "target_id": &"machine_0", "pos": sim.player.pos, "weapon_id": &"", "aim": Vector2.ZERO}
	var too_many: Array = []
	for _index in 7:
		too_many.append(valid_work.duplicate(true))
	for work in [[{"time": 0.0, "kind": &"recycler", "target_id": &"machine_2", "pos": sim.player.pos, "weapon_id": &"", "aim": Vector2.ZERO}], too_many]:
		var damaged := before.duplicate(true)
		for row: Dictionary in damaged["objects"]:
			if row["type"] == "EchoTake":
				row["fields"]["work_actions"] = _encoded(work)
		c.eq(RunSnapshot.restore(damaged), null, "work cannot spend recycler currency or exceed its bounded action budget")
	c.eq(RunSnapshot.capture(sim), before, "all invalid snapshots leave the authoritative run untouched")


func test_presentation_cues_stay_out_of_snapshot_v4(c: Check) -> void:
	var sim := Sim.new(7)
	sim.start_run()
	sim.wave_travel = 90.0
	sim.cue_slot = 2
	sim.action_notice_key = &"hud.rescue_done"
	sim.action_notice_text = "rescued"
	sim.action_notice_until = 4.0
	var restored := RunSnapshot.restore(RunSnapshot.capture(sim))
	c.ok(restored != null, "a run with live cues still restores: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(restored.wave_travel, 0.0, "wave travel is not saved")
	c.eq(restored.cue_slot, -1, "the slot cue is not saved")
	c.eq(String(restored.action_notice_key), "", "the action notice is not saved")
	c.eq(restored.action_notice_text, "", "the action sentence is not saved")
	c.eq(restored.action_notice_until, 0.0, "the action hold is not saved")
