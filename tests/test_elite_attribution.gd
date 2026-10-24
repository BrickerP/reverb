extends RefCounted


func test_death_explosion_reports_its_actual_enemy_without_changing_effect_routing(c: Check) -> void:
	for id: StringName in [&"grunt", &"warden", &"bomber"]:
		var sim := Sim.new(2101)
		sim.start_run()
		sim.wave = 10
		var pending := PendingSpawn.new()
		pending.def = Content.enemy(id)
		pending.pos = Vector2(400.0, 300.0)
		pending.elite_kind = &"volatile" if id != &"bomber" else &""
		sim._materialize(pending)
		var enemy: EnemyState = sim.enemies.back()
		sim.player.pos = enemy.pos + Vector2(40.0, 0.0)
		sim.player.hp = 1.0
		sim.player.iframes = 0.0
		var hurts: Array[PlayerHurtInfo] = []
		var blasts: Array[ExplosionInfo] = []
		sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurts.append(info))
		sim.explosion_info.connect(func(info: ExplosionInfo) -> void: blasts.append(info))
		sim.damage_enemy(enemy, enemy.hp + 1.0, Vector2.ZERO, false)
		c.eq(hurts.size(), 1, "%s death emits one player hurt" % id)
		c.eq(blasts.size(), 1, "%s death emits one explosion" % id)
		if hurts.is_empty() or blasts.is_empty():
			continue
		c.eq(sim.last_damage_source, id, "%s is the reported death cause" % id)
		c.eq(hurts[0].source, id, "%s remains the rich damage source" % id)
		c.eq(hurts[0].effect, &"bomber_explosion", "existing hurt audio routing remains unchanged")
		c.eq(blasts[0].kind, ExplosionInfo.BOMBER, "existing explosion feedback routing remains unchanged")
		c.eq(blasts[0].effect, &"bomber_explosion", "explosion effect retains its contract")
		c.near(blasts[0].radius, enemy.death_radius_value(), 0.001, "runtime radius reaches presentation")
		var expected_damage := enemy.death_damage_value() * WaveDirector.damage_scale(10)
		c.near(hurts[0].amount, expected_damage, 0.001, "fixed-source damage is unchanged")
		c.near(sim.player.hp, 1.0 - expected_damage, 0.001, "same damage is applied to the player")
		c.ok(hurts[0].lethal, "the recorded hit is lethal")
