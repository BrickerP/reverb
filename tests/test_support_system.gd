extends RefCounted


func _sim() -> Sim:
	var sim := Sim.new(63)
	sim.player.pos = Vector2(300, 200)
	sim.player.stats.values[Stats.CRIT_CHANCE] = 0.0
	return sim


func _echo_owner(sim: Sim, token: int, source: int) -> void:
	var take := EchoTake.new()
	take.uid = token
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos])
	var actor := EchoActor.new(take, source)
	sim.echoes.append(actor)


func _enemy(sim: Sim, pos: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.uid = sim.enemies.size() + 100
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = pos
	enemy.hp = 10000.0
	enemy.max_hp = enemy.hp
	enemy.damage = 5.0
	sim.enemies.append(enemy)
	sim.grid.insert(enemy)
	return enemy


func test_weapon_spawns_a_damageable_pet_with_owner_snapshot(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim, Vector2(360, 200))
	_echo_owner(sim, 891, 3)
	var events: Array[Dictionary] = []
	var hits: Array[DamageInfo] = []
	sim.support_event.connect(func(event: Dictionary) -> void: events.append(event))
	sim.damage_event.connect(func(info: DamageInfo) -> void: hits.append(info))
	c.ok(Combat.fire(sim, sim.player.pos, enemy.pos, Content.weapon(&"paper_hound"), 1,
		1.0, sim.player.stats, 0.4, 3, Color.CORAL, 0, false, 891), "pet weapon actually deploys")
	c.eq(sim.projectiles.size(), 0, "pet uses a body")
	c.eq(sim.support_units.size(), 1, "one body deployed")
	sim.echoes.clear() # The launched body keeps its original owner after retirement.
	var unit: Dictionary = sim.support_units[0]
	for key in ["uid", "kind", "pos", "hp", "max_hp", "life", "cooldown", "actor_token", "weapon_id"]:
		c.ok(unit.has(key), "authoritative support key %s" % key)
	SupportSystem.step(sim, 0.3)
	c.ok(enemy.hp < enemy.max_hp, "hound bites a real enemy")
	c.eq(hits[0].actor_token, 891, "hit preserves departed Echo identity")
	c.eq(hits[0].source, 3, "hit belongs to originating Echo")
	c.eq(hits[0].weapon_id, &"paper_hound", "weapon attribution survives deployment")
	c.eq(hits[0].source_tint, Color.CORAL, "pet damage carries owner tint")
	c.ok(events.size() >= 2, "deployment and action publish feedback")
	c.ok(SupportSystem.damage(sim, int(unit["uid"]), 999.0), "pet is damageable")
	SupportSystem.step(sim, 0.01)
	c.eq(sim.support_units.size(), 0, "destroyed pet removed")


func test_hound_retrieves_scrap_without_manual_ability_energy(c: Check) -> void:
	var sim := _sim()
	c.ok(SupportSystem.spawn(sim, &"hound", sim.player.pos), "hound deployed")
	var pickup := Pickup.new()
	pickup.pos = sim.player.pos + Vector2(12, 0)
	pickup.value = 5
	sim.pickups.append(pickup)
	var before := sim.player.materials
	var energy_before := sim.character_energy
	SupportSystem.step(sim, 0.1)
	c.eq(sim.player.materials, before + 5, "retrieval uses actual pickup accounting")
	c.eq(pickup.value, 0, "scrap cannot be collected twice")
	c.eq(sim.character_energy, energy_before, "automatic retrieval never counts as manual collection")
	var part := Pickup.new()
	part.kind = &"mission_part"
	part.pos = sim.player.pos
	sim.pickups.append(part)
	SupportSystem.step(sim, 0.1)
	c.eq(part.value, 1, "objective parts require deliberate world interaction")


func test_all_companions_have_distinct_real_combat_and_share_one_slot(c: Check) -> void:
	for kind: StringName in SupportSystem.COMPANIONS:
		var sim := _sim()
		var enemy := _enemy(sim, Vector2(340, 200))
		c.ok(SupportSystem.spawn(sim, kind, sim.player.pos), "%s recruits" % kind)
		c.ok(not SupportSystem.spawn(sim, &"recruited_collector", sim.player.pos), "only one recruited companion")
		SupportSystem.step(sim, 0.4)
		c.ok(enemy.hp < enemy.max_hp, "%s attacks" % kind)
		if kind == &"recruited_paradox":
			c.ok(enemy.pin_left > 0.0 and enemy.ink_left > 0.0, "Paradox folds and inks targets")


func test_turret_fires_bounded_bolts_and_debt_has_real_output(c: Check) -> void:
	var sim := _sim()
	_enemy(sim, Vector2(440, 200))
	c.ok(SupportSystem.spawn(sim, &"turret", sim.player.pos), "turret deployed")
	SupportSystem.step(sim, 0.3)
	c.eq(sim.projectiles.size(), 1, "turret actually fires")
	var ordinary := sim.projectiles[0].damage
	sim.expedition["debt"] = 10
	SupportSystem.step(sim, 1.0)
	c.near(sim.projectiles[1].damage, ordinary * 1.25, 0.001, "financed turret uses active debt")
	for index in Combat.MAX_PROJECTILES:
		if sim.projectiles.size() < Combat.MAX_PROJECTILES:
			sim.projectiles.append(Projectile.new())
	SupportSystem.step(sim, 10.0)
	c.eq(sim.projectiles.size(), Combat.MAX_PROJECTILES, "support fire shares global projectile bound")


func test_repair_station_and_tree_have_limited_useful_output(c: Check) -> void:
	var sim := _sim()
	sim.player.hp -= 15.0
	sim.character_energy = 0.0
	var cash := sim.player.materials
	c.ok(SupportSystem.spawn(sim, &"repair_station", sim.player.pos), "repair station deployed")
	c.ok(SupportSystem.spawn(sim, &"paper_tree", sim.player.pos), "paper tree deployed")
	var before := sim.player.hp
	for index in 40:
		SupportSystem.step(sim, 0.4)
	c.ok(sim.player.hp > before, "station actually repairs")
	c.near(sim.player.shield, 8.0, 0.001, "tree is limited to four shield deliveries")
	c.near(sim.character_energy, 12.0, 0.001, "tree has bounded energy production")
	c.eq(sim.player.materials, cash, "production never prints money")
	c.eq(int(sim.support_units[1]["charges"]), 0, "production charges exhausted")
	c.ok(not SupportSystem.spawn(sim, &"paper_tree", sim.player.pos), "autofire cannot refresh tree charges")


func test_enemy_contact_damages_support_and_decoy_changes_target(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim, Vector2(500, 200))
	c.ok(SupportSystem.spawn(sim, &"decoy", enemy.pos), "guard placement creates a real decoy")
	var unit: Dictionary = sim.support_units[0]
	var hp := float(unit["hp"])
	c.eq(SupportSystem.target_position(sim, enemy.pos, sim.player.pos), enemy.pos, "enemy can choose decoy")
	SupportSystem.step(sim, 0.1)
	c.near(float(unit["hp"]), hp - enemy.damage, 0.001, "enemy contact damages support")
	SupportSystem.step(sim, 0.1)
	c.near(float(unit["hp"]), hp - enemy.damage, 0.001, "contact has a real damage cooldown")


func test_support_caps_invalid_values_and_uid_monotonicity(c: Check) -> void:
	var sim := _sim()
	c.ok(not SupportSystem.spawn(sim, &"unknown", sim.player.pos), "unknown unit rejected")
	c.ok(not SupportSystem.spawn(sim, &"hound", Vector2(NAN, 0)), "invalid position rejected")
	for index in Sim.MAX_ECHO_CAPACITY:
		_echo_owner(sim, 100 + index, index)
	for index in 30:
		SupportSystem.spawn(sim, &"hound" if index < 8 else &"turret", sim.player.pos, 100 + index % 8)
	c.eq(sim.support_units.size(), SupportSystem.MAX_UNITS, "all owners share a hard twelve-unit bound")
	c.ok(not SupportSystem.damage(sim, 1, NAN), "invalid damage rejected")
	c.ok(not SupportSystem.damage(sim, 1, -2.0), "negative damage cannot repair")
	var last_uid := int(sim.support_units.back()["uid"])
	SupportSystem.step(sim, INF)
	c.eq(sim.support_units.size(), 12, "invalid tick cannot poison finite state")
	SupportSystem.step(sim, 10000.0)
	c.eq(sim.support_units.size(), 0, "large tick expires bounded support work")
	c.ok(SupportSystem.spawn(sim, &"hound", sim.player.pos), "budget frees after expiry")
	c.ok(int(sim.support_units[0]["uid"]) > last_uid, "unit IDs never alias earlier deaths")
	for value in sim.support_units[0].values():
		if value is float:
			c.ok(is_finite(value), "support snapshot scalars are finite")


func test_support_weapon_deploys_without_requiring_an_enemy(c: Check) -> void:
	var sim := _sim()
	var weapons: Array[WeaponDef] = [Content.weapon(&"repair_kit")]
	var levels: Array[int] = [0]
	var cooldowns: Array[float] = [0.0]
	Combat.step_weapons(sim, sim.player.pos, sim.player.stats, weapons, levels, cooldowns,
		1.0, 0.1, -1, Color.WHITE)
	c.eq(sim.support_units.size(), 1, "defense deploys during a breather")
	c.ok(cooldowns[0] > 0.0, "deployment pays actual weapon cooldown")
	for index in 20:
		cooldowns[0] = 0.0
		Combat.step_weapons(sim, sim.player.pos, sim.player.stats, weapons, levels, cooldowns,
			1.0, 0.1, -1, Color.WHITE)
	c.eq(sim.support_units.size(), 1, "holding fire never adds duplicate stations")


func test_station_repairs_nearby_echo_and_upgrade_improves_actual_utility(c: Check) -> void:
	var sim := _sim()
	var take := EchoTake.new()
	take.uid = 51
	take.condition = 30.0
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos])
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	var weapon := Content.weapon(&"repair_kit")
	c.ok(SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 1.0, -1, -1, Color.WHITE, 2), "upgraded utility station deploys")
	SupportSystem.step(sim, 0.3)
	c.near(take.condition, 32.6, 0.001, "station repairs real Echo condition with level scaling")
	c.ok(float(sim.support_units[0]["max_hp"]) > float(SupportSystem.PROFILES[&"repair_station"]["hp"]), "utility upgrades improve station durability")


func test_long_support_combat_keeps_all_allocation_budgets_bounded(c: Check) -> void:
	var sim := _sim()
	for index in Sim.MAX_ECHO_CAPACITY:
		_echo_owner(sim, 100 + index, index)
	for index in 36:
		_enemy(sim, Vector2(390 + (index % 6) * 18, 180 + (index / 6) * 18))
	var elapsed := 0.0
	for tick in 600:
		for index in 15:
			SupportSystem.spawn(sim, &"turret" if index < 8 else &"hound", sim.player.pos + Vector2(0, index * 2), 100 + index % 8)
		SupportSystem.step(sim, 0.05)
		Combat.step_projectiles(sim, 0.05)
		var live: Array[Projectile] = []
		for projectile: Projectile in sim.projectiles:
			if not projectile.dead:
				live.append(projectile)
		sim.projectiles = live
		elapsed += 0.05
	c.ok(elapsed >= 29.0, "sustained deployment and combat exercised")
	c.ok(sim.support_units.size() <= SupportSystem.MAX_UNITS, "sustained autofire stays within twelve units")
	c.ok(sim.projectiles.size() <= Combat.MAX_PROJECTILES, "support attacks never escape shared bolt cap")
	for unit: Dictionary in sim.support_units:
		var pos: Vector2 = unit["pos"]
		c.ok(pos.is_finite() and is_finite(float(unit["life"])) and is_finite(float(unit["hp"])), "long combat retains finite snapshot values")


func test_snapshot_validator_rejects_mutations_without_repairing_state(c: Check) -> void:
	var sim := _sim()
	SupportSystem.spawn(sim, &"paper_tree", sim.player.pos)
	c.ok(SupportSystem.validate_state(sim.support_units, sim._next_support_uid), "canonical live support snapshot validates")
	var before := sim.support_units.duplicate(true)
	for mutation: Dictionary in [{"damage": NAN}, {"charges": 99}, {"kind": &"unknown"},
		{"hp": 9999.0}, {"source": 3}, {"weapon_id": &"pistol"}, {"reach": INF}]:
		var changed := before.duplicate(true)
		changed[0].merge(mutation, true)
		c.ok(not SupportSystem.validate_state(changed, sim._next_support_uid), "invalid support field is rejected")
	c.ok(not SupportSystem.validate_state(before, int(before[0]["uid"])), "allocator must exceed every unit UID")
	var duplicates := before.duplicate(true)
	duplicates.append(before[0].duplicate(true))
	c.ok(not SupportSystem.validate_state(duplicates, sim._next_support_uid), "duplicate units rejected")
	c.eq(sim.support_units, before, "validation never normalizes or mutates authoritative state")


func test_unresolved_echo_owner_is_rejected_before_any_allocation(c: Check) -> void:
	var sim := _sim()
	var before := sim.support_units.duplicate(true)
	var allocator := sim._next_support_uid
	var rng := sim.rng.state
	c.ok(not SupportSystem.spawn(sim, &"hound", sim.player.pos, 999999), "unknown Echo owner cannot create invalid support")
	c.ok(not SupportSystem.spawn(sim, &"hound", sim.player.pos, 0), "zero is not an allocated Echo UID")
	c.eq(sim.support_units, before, "owner rejection changes no live state")
	c.eq(sim._next_support_uid, allocator, "owner rejection consumes no unit identity")
	c.eq(sim.rng.state, rng, "owner rejection does not consume simulation RNG")
	_echo_owner(sim, 51, 2)
	c.ok(SupportSystem.spawn(sim, &"hound", sim.player.pos, 51), "actual active Echo owner resolves")
	c.eq(sim.support_units[0]["source"], 2, "spawn stores actual source slot")
	c.ok(SupportSystem.validate_state(sim.support_units, sim._next_support_uid), "owner-resolved support remains snapshot-valid")
	c.ok(not SupportSystem.spawn_weapon(sim, Content.weapon(&"debt_sentry"), sim.player.pos,
		9.0, 3, 51, Color.WHITE, 0), "mismatched owner slot is rejected")


func test_all_max_grade_utility_support_roundtrips_canonical_hp_and_rejects_inflation(c: Check) -> void:
	for id: StringName in [&"repair_kit", &"paper_seed", &"guard_decoy"]:
		var sim := _sim()
		sim.start_run()
		var weapon := Content.weapon(id)
		c.ok(SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 1.0,
			-1, -1, Color.WHITE, WeaponDef.MAX_LEVEL), "%s max grade actually deploys" % id)
		var unit: Dictionary = sim.support_units[0]
		var expected := float(SupportSystem.PROFILES[weapon.support_kind]["hp"]) * weapon.level_mult(WeaponDef.MAX_LEVEL)
		c.near(unit["max_hp"], expected, 0.0001, "%s uses actual grade durability" % id)
		c.ok(SupportSystem.validate_state(sim.support_units, sim._next_support_uid), "%s canonical grade HP validates" % id)
		var before := RunSnapshot.capture(sim)
		c.ok(not before.is_empty(), "%s full state capture is nonempty" % id)
		var restored := RunSnapshot.restore(JSON.parse_string(JSON.stringify(before)))
		c.ok(restored != null, "%s max-grade station is reloadable" % id)
		if restored != null:
			c.eq(RunSnapshot.capture(restored), before, "%s complete state roundtrips exactly" % id)
		var allocator := sim._next_support_uid
		c.ok(not SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 1.0,
			-1, 999999, Color.WHITE, WeaponDef.MAX_LEVEL), "unresolved owner remains atomic at max grade")
		c.eq(sim._next_support_uid, allocator, "rejected source consumes no support UID")
		c.eq(RunSnapshot.capture(sim), before, "rejected max-grade deployment changes no full state")
		unit["max_hp"] = expected + 0.25
		c.ok(not SupportSystem.validate_state(sim.support_units, sim._next_support_uid), "even small noncanonical HP inflation is rejected")
		c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "inflated support HP cannot enter a resumed run")
		unit["max_hp"] = expected
		c.eq(RunSnapshot.capture(sim), before, "boundary probe restores every authoritative field")


func test_noncanonical_support_definition_and_private_source_are_rejected_atomically(c: Check) -> void:
	var sim := _sim()
	sim.start_run()
	var before := RunSnapshot.capture(sim)
	var forged := Content.weapon(&"paper_seed").duplicate() as WeaponDef
	c.ok(not SupportSystem.spawn_weapon(sim, forged, sim.player.pos, 1.0, -1, -1, Color.WHITE, 3), "only canonical support definitions may create saved bodies")
	c.ok(not SupportSystem.spawn_weapon(sim, Content.weapon(&"paper_seed"), sim.player.pos, 1.0, -2, -1, Color.WHITE, 3), "public factory cannot save private source sentinel")
	c.eq(RunSnapshot.capture(sim), before, "invalid factory inputs cannot allocate or mutate state")
