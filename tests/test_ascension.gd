extends RefCounted


func _sim(ascension: int = 0) -> Sim:
	var s := Sim.new(7)
	s.ascension = ascension
	s.start_run()
	return s


func _grunt(s: Sim) -> EnemyState:
	var ps := PendingSpawn.new()
	ps.def = Content.enemy(&"grunt")
	ps.pos = s.player.pos + Vector2(100.0, 0.0)
	s._materialize(ps)
	return s.enemies[s.enemies.size() - 1]


func test_ascension_scales_enemies(c: Check) -> void:
	var normal := _grunt(_sim(0))
	var hard := _grunt(_sim(1))
	var later := _grunt(_sim(2))
	c.near(hard.max_hp, normal.max_hp * 1.10, 0.001, "A1 adds 10% HP")
	c.near(hard.speed, normal.speed * 1.05, 0.001, "A1 adds 5% speed")
	c.near(hard.damage, normal.damage * 1.10, 0.001, "A1 adds 10% damage")
	c.near(later.max_hp, hard.max_hp, 0.001, "A2 does not add another stat layer")
	c.near(later.damage, hard.damage, 0.001, "A2 keeps the A1 damage scale")
	c.near(later.speed, hard.speed, 0.001, "A2 keeps the A1 speed scale")


func test_ascension_scales_the_boss(c: Check) -> void:
	var normal := _sim(0)
	normal.wave = WaveDirector.FINAL_WAVE
	var ps := PendingSpawn.new()
	ps.def = Content.enemy(&"paradox")
	ps.pos = normal.player.pos + Vector2(200.0, 0.0)
	normal._materialize(ps)
	var hard := _sim(3)
	hard.wave = WaveDirector.FINAL_WAVE
	var ps2 := PendingSpawn.new()
	ps2.def = Content.enemy(&"paradox")
	ps2.pos = hard.player.pos + Vector2(200.0, 0.0)
	hard._materialize(ps2)
	c.near(hard.boss.max_hp, normal.boss.max_hp * 1.10, 0.001, "boss HP uses the A1 scale")
	c.near(hard.boss.damage, normal.boss.damage * 1.10, 0.001, "boss damage uses the A1 scale")


func test_ascension_two_opens_rifts_early(c: Check) -> void:
	var normal := _sim(0)
	normal.start_wave(10)
	normal._plan.clear()
	normal._plan_idx = 0
	normal.pending.clear()
	normal.enemies.clear()
	for i in 510:
		normal.step(1.0 / 60.0, Vector2.ZERO)
	c.eq(normal.rifts.size(), 0, "A0 has no rift on wave 10")

	var torn := _sim(2)
	torn.start_wave(10)
	torn._plan.clear()
	torn._plan_idx = 0
	torn.pending.clear()
	torn.enemies.clear()
	for i in 510:
		torn.step(1.0 / 60.0, Vector2.ZERO)
	c.eq(torn.rifts.size(), 1, "A2 opens a rift on wave 10")
	c.eq(torn.ascension_rift_interval(), 14.0, "A2 uses the faster rift interval")


func test_ascension_three_adds_a_second_elite(c: Check) -> void:
	var normal := WaveDirector.plan(10, 5)
	var double := WaveDirector.plan(10, 5, 1.0, false, 2)
	var normal_count := 0
	var double_count := 0
	for e in normal:
		if e.elite_kind != &"":
			normal_count += 1
	for e in double:
		if e.elite_kind != &"":
			double_count += 1
	c.eq(normal_count, 1, "A0-A2 keep one elite")
	c.eq(double_count, 2, "A3 adds a second elite")

	var a3 := _sim(3)
	a3.start_wave(10)
	var planned := 0
	for event in a3._plan:
		if event.elite_kind != &"":
			planned += 1
	c.eq(planned, 2, "A3 simulation plans two elites")
