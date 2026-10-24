extends RefCounted


func _sim(hp: float) -> Sim:
	var sim := Sim.new(2001)
	sim.start_run()
	sim.start_wave(12)
	sim._plan.clear()
	sim.pending.clear()
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	sim.player.hp = hp
	var rift := TemporalRift.new()
	rift.pos = sim.player.pos
	rift.telegraph = 0.0
	rift.active = 2.0
	rift.tick = 0.001
	sim.rifts.append(rift)
	return sim


func _enemy(sim: Sim, id: StringName, offset: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.uid = 991
	enemy.def = Content.enemy(id)
	enemy.pos = sim.player.pos + offset
	enemy.hp = 1.0
	enemy.max_hp = 1.0
	enemy.radius = enemy.def.radius
	enemy.damage = 5.0
	enemy.speed = 0.0
	sim.enemies.append(enemy)
	return enemy


func test_contact_and_rift_keep_the_first_actual_lethal_source(c: Check) -> void:
	for initial_hp in [4.0, 8.0]:
		var sim := _sim(initial_hp)
		_enemy(sim, &"grunt", Vector2.ZERO)
		var hurts: Array[PlayerHurtInfo] = []
		sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurts.append(info))
		sim.step(1.0 / 60.0, Vector2.ZERO)
		c.eq(hurts.size(), 2, "contact and rift retain both fixed damage events")
		if hurts.size() != 2: continue
		var contact_lethal: bool = initial_hp <= 5.0
		c.eq(hurts[0].lethal, contact_lethal, "contact marks only an actual lethal transition")
		c.eq(hurts[1].lethal, not contact_lethal, "rift is lethal only if contact was survived")
		c.eq(sim.last_damage_source, &"grunt" if contact_lethal else &"rift",
				"result source belongs to the first hit crossing zero")
		c.near(sim.player.hp, initial_hp - hurts[0].amount - hurts[1].amount, 0.001,
				"fixed damage amounts and application order remain unchanged")
		c.eq(sim.phase, Sim.Phase.LOST, "the same tick ends the run")


func test_rift_lethal_source_survives_later_bomber_processing(c: Check) -> void:
	var sim := _sim(4.0)
	var bomber := _enemy(sim, &"bomber", Vector2(45.0, 0.0))
	var shot := Projectile.new()
	shot.pos = bomber.pos
	shot.damage = 10000.0
	shot.life = 1.0
	shot.radius = 3.0
	sim.projectiles.append(shot)
	var hurts: Array[PlayerHurtInfo] = []
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurts.append(info))
	sim.step(1.0 / 60.0, Vector2.ZERO)
	c.eq(hurts.size(), 2, "rift then bomber both retain their damage events")
	if hurts.size() != 2: return
	c.eq(hurts[0].source, &"rift", "rift hit is first")
	c.eq(hurts[1].source, &"bomber", "bomber processing follows")
	c.ok(hurts[0].lethal and not hurts[1].lethal, "only the first lethal transition is flagged")
	c.eq(sim.last_damage_source, &"rift", "later explosion cannot replace the death cause")
	c.near(sim.player.hp, 4.0 - hurts[0].amount - hurts[1].amount, 0.001,
			"death metadata correction must not alter damage")
