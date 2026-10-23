extends RefCounted


func _sim(wave: int = 10) -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.wave = wave
	return s


func _materialize(s: Sim, kind: StringName, def_id: StringName = &"grunt") -> EnemyState:
	var ps := PendingSpawn.new()
	ps.def = Content.enemy(def_id)
	ps.pos = Vector2(300.0, 300.0)
	ps.elite_kind = kind
	s._materialize(ps)
	return s.enemies[s.enemies.size() - 1]


func test_elite_base_stats_and_reward(c: Check) -> void:
	var s := _sim()
	var e := _materialize(s, &"overclocked")
	c.ok(e.elite, "the enemy is marked elite")
	c.eq(e.elite_kind, &"overclocked", "the modifier is stored")
	c.near(e.max_hp, e.def.hp * WaveDirector.hp_scale(10) * Sim.ELITE_HP_MULT, 0.001,
			"elite hp is scaled")
	c.near(e.speed, e.def.speed * WaveDirector.speed_scale(10) * Sim.ELITE_SPEED_MULT * Sim.ELITE_OVERCLOCK_SPEED,
			0.001, "overclocked speed is scaled")
	c.near(e.damage, e.def.damage * WaveDirector.damage_scale(10) * Sim.ELITE_DAMAGE_MULT * Sim.ELITE_OVERCLOCK_DAMAGE,
			0.001, "overclocked damage is scaled")
	c.eq(e.drop_mult, Sim.ELITE_DROP_MULT, "elites carry a larger drop")
	e.hp = 1.0
	s.damage_enemy(e, 10.0, Vector2.ZERO, false, -1)
	var pickup: Pickup = s.pickups[s.pickups.size() - 1]
	c.eq(pickup.value, e.def.drop * Sim.ELITE_DROP_MULT, "the increased drop reaches the pickup")


func test_bulwark_elite_uses_runtime_shield(c: Check) -> void:
	var s := _sim()
	var e := _materialize(s, &"bulwark")
	c.eq(e.shield_arc_value(), Sim.ELITE_BULWARK_ARC, "bulwark gets its shield arc")
	c.eq(e.shield_reduction_value(), Sim.ELITE_BULWARK_REDUCTION, "bulwark gets its reduction")
	s.player.pos = e.pos + Vector2(-100.0, 0.0)
	var front_hp := e.hp
	s.damage_enemy(e, 100.0, Vector2.ZERO, false, -1, Vector2.RIGHT)
	c.near(front_hp - e.hp, 100.0 * (1.0 - Sim.ELITE_BULWARK_REDUCTION), 0.001,
			"front hits are reduced")
	var back_hp := e.hp
	s.damage_enemy(e, 100.0, Vector2.ZERO, false, -1, Vector2.LEFT)
	c.near(back_hp - e.hp, 100.0, 0.001, "back hits ignore the shield")


func test_volatile_elite_explodes_with_a_runtime_radius(c: Check) -> void:
	var s := _sim()
	var e := _materialize(s, &"volatile")
	var blasts: Array[ExplosionInfo] = []
	s.explosion_info.connect(func(info: ExplosionInfo) -> void: blasts.append(info))
	s.player.pos = e.pos + Vector2(30.0, 0.0)
	s.player.iframes = 0.0
	e.hp = 1.0
	var hp_before := s.player.hp
	s.damage_enemy(e, 10.0, Vector2.ZERO, false, -1)
	c.eq(blasts.size(), 1, "the elite death emits one blast")
	c.near(blasts[0].radius, Sim.ELITE_VOLATILE_RADIUS, 0.001, "the blast uses the elite radius")
	c.ok(s.player.hp < hp_before, "the blast hurts a nearby player")
