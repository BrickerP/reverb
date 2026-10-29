extends RefCounted


func _sim(role: StringName) -> Sim:
	var sim := Sim.new(78)
	Content.character(role).apply(sim)
	sim.start_run()
	sim.enemies.clear()
	sim.pending.clear()
	sim.projectiles.clear()
	sim.attack_fields.clear()
	sim.player.pos = Vector2(300, 300)
	sim.player.facing = Vector2.RIGHT
	return sim


func _echo(sim: Sim) -> EchoActor:
	var take := EchoTake.new()
	take.samples = PackedVector2Array([Vector2(340, 300), Vector2(380, 300)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.wave = 1
	sim.bank.add(take)
	var actor := EchoActor.new(take, sim.echoes.size())
	sim.echoes.append(actor)
	sim.selected_echo_uid = take.uid
	return actor


func _enemy(sim: Sim, position: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.uid = 901
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = position
	enemy.radius = 11.0
	enemy.max_hp = 200.0
	enemy.hp = 200.0
	sim.enemies.append(enemy)
	sim.grid.insert(enemy)
	return enemy


func test_manual_energy_charge_is_bounded_and_automatic_payout_is_not_an_input(c: Check) -> void:
	var sim := _sim(&"solo")
	sim.character_energy = 0.0
	CharacterSkills.on_pickup(sim, 2)
	c.eq(sim.character_energy, 8.0, "manual material pickup charges ability")
	CharacterSkills.on_pickup(sim, 10000)
	c.eq(sim.character_energy, 28.0, "one oversized pickup cannot fill the gauge")
	CharacterSkills.on_pickup(sim, -5)
	c.eq(sim.character_energy, 28.0, "negative pickups cannot drain or mint energy")
	sim.character_energy = 99.0
	CharacterSkills.on_pickup(sim, 1)
	c.eq(sim.character_energy, 100.0, "energy caps at one activation")
	sim.phase = Sim.Phase.SHOP
	sim.character_energy = 0.0
	CharacterSkills.on_pickup(sim, 5)
	c.eq(sim.character_energy, 0.0, "shop and end payouts cannot charge")
	c.ok(not CharacterSkills.activate(sim), "abilities cannot activate in shop")


func test_looper_rewinds_position_echo_time_and_firing_cycle(c: Check) -> void:
	var sim := _sim(&"looper")
	var actor := _echo(sim)
	actor.t = 3.0
	sim.role_effects["rewind_history"] = [Vector2(200, 300), Vector2(300, 300)]
	sim.player.cooldowns[0] = 2.0
	c.ok(CharacterSkills.activate(sim), "rewind activates")
	c.eq(sim.player.pos, Vector2(200, 300), "rewind restores real earlier position")
	c.near(actor.t, 1.0, 0.001, "echo playback rewinds by two seconds")
	c.eq(sim.player.cooldowns[0], 0.0, "rewind restarts firing cycle")
	c.eq(sim.character_energy, 0.0, "ability consumes exactly 100 energy")
	c.ok(not CharacterSkills.activate(sim), "empty gauge cannot repeat")
	sim.character_energy = 100.0
	c.ok(not CharacterSkills.activate(sim), "cooldown prevents repeated full gauge activation")
	CharacterSkills.step(sim, CharacterSkills.COOLDOWN)
	c.eq(sim.character_cooldown, 0.0, "cooldown advances only through actual simulation")
	c.ok(sim.role_effects.rewind_history.size() <= CharacterSkills.HISTORY_SAMPLES, "large delta cannot create unbounded rewind history")


func test_solo_dash_moves_hits_path_and_parries_without_echo(c: Check) -> void:
	var sim := _sim(&"solo")
	var enemy := _enemy(sim, Vector2(400, 300))
	c.ok(CharacterSkills.activate(sim), "solo has an independent active ability")
	c.ok(sim.player.pos.x > 450.0, "dash moves through actual world")
	c.ok(enemy.hp < enemy.max_hp, "dash damages enemy on travelled path")
	c.ok(sim.player.iframes >= 0.8, "paper fold grants a bounded parry window")
	c.ok(sim.bank.takes.is_empty(), "solo ability does not invent an Echo")


func test_mirror_swaps_positions_and_holds_reflection_without_repair(c: Check) -> void:
	var sim := _sim(&"mirror")
	var actor := _echo(sim)
	var origin := sim.player.pos
	var destination := actor.pos
	actor.take.condition = 50.0
	c.ok(CharacterSkills.activate(sim), "mirror activates with a selected copy")
	c.eq(sim.player.pos, destination, "player takes copy's real position")
	c.eq(actor.pos, origin, "copy takes player's real position")
	EchoSystem.step(sim, 0.1)
	c.eq(actor.pos, origin, "reflection remains held during swap window")
	c.ok(actor.take.condition < 50.0, "held copy still wears normally")


func test_conductor_anchors_and_relays_real_damage_without_retiring(c: Check) -> void:
	var sim := _sim(&"conductor")
	var actor := _echo(sim)
	var enemy := _enemy(sim, actor.pos + Vector2(50, 0))
	var origin := actor.pos
	c.ok(CharacterSkills.activate(sim), "relay activates")
	CharacterSkills.step(sim, 0.1)
	EchoSystem.step(sim, 0.1)
	c.eq(actor.pos, origin, "conductor anchors the route")
	c.ok(enemy.hp < enemy.max_hp, "first relay pulse deals actual combat damage")
	c.eq(sim.bank.takes.size(), 1, "relay preserves its source copy")
	c.eq(sim.role_effects.relay_pulses, 2, "relay has a finite pulse budget")


func test_mender_places_finite_repair_station_and_overload_consumes_durability(c: Check) -> void:
	var mender := _sim(&"mender")
	var patient := _echo(mender)
	patient.take.condition = 50.0
	mender.player.hp -= 8.0
	var hp_before := mender.player.hp
	c.ok(CharacterSkills.activate(mender), "mender places an actual support unit")
	c.eq(mender.support_units.size(), 1, "one station is allocated")
	c.eq(mender.support_units[0].kind, &"repair_station", "station has real repair behavior")
	c.ok(float(mender.support_units[0].life) > 0.0, "station lifetime is bounded")
	SupportSystem.step(mender, 0.25)
	c.ok(mender.player.hp > hp_before, "station actually repairs the player")
	c.ok(patient.take.condition > 50.0, "station actually repairs nearby copy condition")
	c.eq(mender.support_units[0].charges, 5, "actual maintenance spends a finite charge")
	var sim := _sim(&"overloader")
	var actor := _echo(sim)
	actor.take.condition = 80.0
	var victim := _enemy(sim, actor.pos + Vector2(35, 0))
	c.ok(CharacterSkills.activate(sim), "overloader detonates selected recording")
	c.eq(sim.bank.takes.size(), 0, "overload consumes recording rather than duplicating it")
	c.eq(sim.echoes.size(), 0, "overload removes the live source actor")
	c.eq(sim.attack_fields.size(), 1, "overload creates an actual delayed impact")
	c.near(sim.attack_fields[0].radius, 210.0, 0.001, "overload has its own impact footprint")
	c.eq(sim.character_energy, 0.0, "successful overload pays energy")
	Combat.tick_fields(sim, 0.31)
	c.ok(victim.hp < victim.max_hp, "overload impact resolves into real enemy damage")


func test_missing_targets_and_support_capacity_preserve_energy(c: Check) -> void:
	for role: StringName in [&"mirror", &"conductor", &"overloader"]:
		var sim := _sim(role)
		c.ok(not CharacterSkills.activate(sim), "%s rejects missing copy" % role)
		c.eq(sim.character_energy, 100.0, "%s rejection preserves energy" % role)
		c.eq(sim.character_cooldown, 0.0, "%s rejection preserves cooldown" % role)
	var solo := _sim(&"solo")
	solo.character_energy = 99.0
	c.ok(not CharacterSkills.activate(solo), "99 energy cannot pay 100")
	c.eq(solo.player.pos, Vector2(300, 300), "insufficient energy never moves the player")
	var mender := _sim(&"mender")
	c.ok(SupportSystem.spawn(mender, &"repair_station", mender.player.pos), "living station occupies role deployment slot")
	c.ok(not CharacterSkills.activate(mender), "mender cannot refresh a living station for free")
	c.eq(mender.character_energy, 100.0, "failed station deployment keeps ability energy")
