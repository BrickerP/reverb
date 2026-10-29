extends RefCounted


func _take(wave: int, tint: int, position: Vector2, weapon: WeaponDef) -> EchoTake:
	var take := EchoTake.new()
	take.wave = wave
	take.tint_index = tint
	take.weapons.append(weapon)
	take.levels.append(0)
	take.samples.append(position)
	take.samples.append(position + Vector2(20.0, 0.0))
	return take


func _enemy(sim: Sim, uid: int, position: Vector2) -> EnemyState:
	var e := EnemyState.new()
	e.uid = uid
	e.def = Content.enemy(&"grunt")
	e.pos = position
	e.radius = e.def.radius
	e.max_hp = 5.0
	e.hp = 5.0
	sim.enemies.append(e)
	return e


func test_delayed_shot_keeps_removed_copy_identity_through_direct_and_aoe_kills(c: Check) -> void:
	var sim := Sim.new(31)
	sim.start_run()
	var weapon := WeaponDef.new()
	weapon.id = &"flak_crown"
	weapon.damage = 50.0
	weapon.reach = 400.0
	weapon.projectile_speed = 200.0
	weapon.explosion_radius = 45.0
	weapon.explosion_damage = 1.0
	var a := _take(1, 0, Vector2(400.0, 300.0), weapon)
	var b := _take(2, 1, Vector2(300.0, 400.0), weapon)
	sim.bank.add(a)
	sim.bank.add(b)
	sim.start_wave(3)
	sim._plan.clear()
	sim.enemies.clear()
	var primary := _enemy(sim, 3101, Vector2(650.0, 300.0))
	_enemy(sim, 3102, Vector2(650.0, 325.0))
	var shots: Array[ShotInfo] = []
	var hits: Array[DamageInfo] = []
	var deaths: Array[EnemyDeathInfo] = []
	var blasts: Array[ExplosionInfo] = []
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: shots.append(info))
	sim.damage_event.connect(func(info: DamageInfo) -> void: hits.append(info))
	sim.enemy_killed.connect(func(info: EnemyDeathInfo) -> void: deaths.append(info))
	sim.explosion_info.connect(func(info: ExplosionInfo) -> void: blasts.append(info))
	var token: int = a.get_instance_id()
	var tint := a.tint()
	var weapons: Array[WeaponDef] = [weapon]
	var levels: Array[int] = [0]
	var cooldowns: Array[float] = [0.0]
	Combat.step_weapons(sim, sim.echoes[0].pos, a.stats, weapons, levels, cooldowns,
			1.0, 0.0, 0, tint, 1.0, 1.0, token)
	c.eq(shots.size(), 1, "real firing reports one source snapshot")
	c.eq(shots[0].actor_token, token, "shot identity is captured when firing")
	c.eq(shots[0].source_tint, tint, "shot tint is a value snapshot")
	c.eq(sim.projectiles.size(), 1, "one real delayed projectile is in flight")
	var projectile := sim.projectiles[0]
	c.eq(projectile.actor_token, token, "projectile carries its original take")
	c.ok(sim.collapse_oldest_echo(), "the firing copy is genuinely removed before impact")
	c.eq(sim.echoes.size(), 1, "one copy survives")
	c.eq(sim.echoes[0].take, b, "old slot zero now belongs to a different copy")
	a.tint_index = 4
	hits.clear()
	deaths.clear()
	blasts.clear()
	sim.grid.clear()
	for e in sim.enemies:
		sim.grid.insert(e)
	var flight := (primary.pos.x - projectile.pos.x) / projectile.vel.x
	Combat.step_projectiles(sim, flight)
	c.eq(hits.size(), 2, "actual projectile and splash both hit after reindex")
	c.eq(deaths.size(), 2, "direct and splash deaths both retain causality")
	for hit in hits:
		c.eq(hit.actor_token, token, "impact does not borrow the survivor's slot identity")
		c.eq(hit.source_tint, tint, "impact does not read the take's later mutable tint")
	for death in deaths:
		c.eq(death.actor_token, token, "death snapshot keeps the removed source")
		c.eq(death.source_tint, tint, "death palette remains that of the original firing copy")
		c.eq(death.source, 0, "legacy numeric source statistics are unchanged")
	c.eq(blasts.size(), 1, "one weapon explosion is emitted")
	c.eq(blasts[0].actor_token, token, "explosion carries the same original actor")
	c.eq(blasts[0].source_tint, tint, "explosion source identity is independent of its effect color")
