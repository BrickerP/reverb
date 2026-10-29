extends RefCounted

const DT := 1.0 / 60.0


func _sim(seed_value: int = 1) -> Sim:
	var s := Sim.new(seed_value)
	s.start_run()
	return s


func _immortal(s: Sim) -> void:
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()


func _run(s: Sim, steps: int, dir: Vector2 = Vector2.ZERO) -> void:
	for i in steps:
		s.step(DT, dir)


func _boss_sim(seed_value: int = 1) -> Sim:
	var s := _sim(seed_value)
	_immortal(s)
	s.start_wave(WaveDirector.FINAL_WAVE)
	_run(s, 200)
	return s


func _total_hp(s: Sim) -> float:
	var total := 0.0
	for e in s.boss_shards:
		if not e.dead:
			total += e.hp
	return total


func test_boss_splits_at_half_health(c: Check) -> void:
	var s := _boss_sim()
	c.ok(s.boss != null, "the boss spawned")
	c.eq(s.boss_phase, 1, "phase starts at one")
	c.eq(s.boss_total_count(), 1, "phase one has one body")
	var phase_changes := [0]
	var shard_spawns := [0]
	s.boss_phase_changed.connect(func(_phase: int) -> void: phase_changes[0] += 1)
	s.boss_shard_spawned.connect(func(_enemy: EnemyState) -> void: shard_spawns[0] += 1)
	var original_max := s.boss.max_hp
	s.boss.hp = original_max * 0.51
	var remaining := s.boss.hp - original_max * 0.02
	s.damage_enemy(s.boss, original_max * 0.02, Vector2.ZERO, false, -1)
	c.eq(phase_changes[0], 1, "phase change fires once")
	c.eq(shard_spawns[0], 1, "the new shard is announced")
	c.eq(s.boss_phase, 2, "phase two starts")
	c.eq(s.boss_total_count(), 2, "phase two has two bodies")
	c.eq(s.boss_alive_count(), 2, "both bodies are alive")
	c.near(_total_hp(s), remaining, 0.001, "splitting preserves the remaining health")
	c.near(s.boss_health_ratio(), remaining / original_max, 0.001, "the bar uses combined health")
	c.ok(s.echo_silenced >= Sim.BOSS_PHASE2_SILENCE, "the split has a silence beat")
	var shard: EnemyState = s.boss_shards[1]
	c.ok(s.enemies.has(shard), "the shard joins the enemy list")
	c.ok(Sim.ARENA.has_point(shard.pos), "the shard is inside the arena")
	c.ok(shard.pos.distance_to(s.boss.pos) > 1.0, "the shard does not overlap the original")
	c.near(s.boss.max_hp, shard.max_hp, 0.001, "both bodies show the same local health scale")
	c.near(s.boss.hp / s.boss.max_hp, 1.0, 0.001, "the original body starts the phase full")
	c.near(shard.hp / shard.max_hp, 1.0, 0.001, "the new body starts the phase full")
	c.ok(s.boss_origin().distance_to(s.boss.pos) <= 0.01, "the first living body is the origin")
	# A second threshold hit must not spawn a third body or re-emit phase two.
	s.damage_enemy(shard, 10.0, Vector2.ZERO, false, -1)
	c.eq(s.boss_total_count(), 2, "phase two does not split again")
	c.eq(phase_changes[0], 1, "the transition is one-shot")


func test_split_preserves_fractional_health(c: Check) -> void:
	for remaining in [10.0, 0.25]:
		var s := _boss_sim()
		s.boss.hp = remaining + 0.5
		s.damage_enemy(s.boss, 0.5, Vector2.ZERO, false, -1)
		c.eq(s.boss_phase, 2, "a nonlethal hit leaving %s HP still splits" % remaining)
		c.near(_total_hp(s), remaining, 0.0001, "%s HP is conserved across the split" % remaining)
		c.near(s.boss_health_ratio(), remaining / s.boss_original_max_hp, 0.000001,
				"the combined bar reads %s HP" % remaining)


func test_one_survivor_enrages(c: Check) -> void:
	var s := _boss_sim()
	s.boss.hp = s.boss.max_hp * 0.5 + 1.0
	s.damage_enemy(s.boss, 2.0, Vector2.ZERO, false, -1)
	c.eq(s.boss_phase, 2, "the split happened")
	var shard: EnemyState = s.boss_shards[1]
	var survivor: EnemyState = s.boss
	var prior_speed := survivor.speed
	var prior_damage := survivor.damage
	var defeated := [0]
	var enrages := [0]
	s.boss_shard_defeated.connect(func(_enemy: EnemyState, _remaining: int) -> void:
		defeated[0] += 1)
	s.boss_enraged.connect(func(_enemy: EnemyState) -> void: enrages[0] += 1)
	s.damage_enemy(shard, 1000000.0, Vector2.ZERO, false, -1)
	c.eq(defeated[0], 1, "the first shard death is reported")
	c.eq(enrages[0], 1, "the survivor enrages once")
	c.eq(s.boss_alive_count(), 1, "one body remains")
	c.eq(s.boss_phase, 2, "the fight stays in phase two")
	c.near(survivor.speed, prior_speed * Sim.BOSS_ENRAGE_SPEED, 0.001, "the survivor speeds up")
	c.near(survivor.damage, prior_damage * Sim.BOSS_ENRAGE_DAMAGE, 0.001, "the survivor hits harder")
	c.ok(s.boss_health_ratio() > 0.0, "the bar still shows the survivor")
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.WAVE, "one dead shard does not end the run")


func test_both_shards_must_die(c: Check) -> void:
	var s := _boss_sim()
	s.boss.hp = s.boss.max_hp * 0.5 + 1.0
	s.damage_enemy(s.boss, 2.0, Vector2.ZERO, false, -1)
	var defeated := [0]
	var enrages := [0]
	var won := [0]
	s.boss_shard_defeated.connect(func(_enemy: EnemyState, _remaining: int) -> void:
		defeated[0] += 1)
	s.boss_enraged.connect(func(_enemy: EnemyState) -> void: enrages[0] += 1)
	s.run_won.connect(func() -> void: won[0] += 1)
	s.damage_enemy(s.boss_shards[1], 1000000.0, Vector2.ZERO, false, -1)
	s.damage_enemy(s.boss_shards[0], 1000000.0, Vector2.ZERO, false, -1)
	c.eq(defeated[0], 2, "both shard deaths are reported")
	c.eq(enrages[0], 1, "enrage fires when only one body remains")
	c.eq(s.boss_alive_count(), 0, "no boss bodies remain")
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.WON, "both deaths win the run")
	c.eq(won[0], 1, "win is emitted once")


func test_lethal_hit_can_skip_phase_two(c: Check) -> void:
	var s := _boss_sim()
	var changes := [0]
	s.boss_phase_changed.connect(func(_phase: int) -> void: changes[0] += 1)
	s.damage_enemy(s.boss, 1000000.0, Vector2.ZERO, false, -1)
	c.eq(changes[0], 0, "a lethal hit does not split")
	c.eq(s.boss_phase, 1, "phase remains one")
	c.eq(s.boss_total_count(), 1, "no shard is spawned")
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.WON, "the lethal hit still wins")


func test_phase_two_keeps_the_silence_cadence(c: Check) -> void:
	var s := _boss_sim()
	s.boss.hp = s.boss.max_hp * 0.5 + 1.0
	s.damage_enemy(s.boss, 2.0, Vector2.ZERO, false, -1)
	var silences := [0]
	s.echoes_silenced.connect(func(_info: EchoSilenceInfo) -> void: silences[0] += 1)
	s.echo_silenced = 0.0
	s._boss_silence_cd = 0.01
	_run(s, 2)
	c.eq(silences[0], 1, "the split does not double the silence signal")
	c.ok(s.echo_silenced > 0.0, "the boss can still silence in phase two")
