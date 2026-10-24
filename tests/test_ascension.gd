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
	var hard := _grunt(_sim(2))
	c.near(hard.max_hp, normal.max_hp * 1.20, 0.001, "ascension adds 10% HP per level")
	c.near(hard.speed, normal.speed * 1.10, 0.001, "ascension adds 5% speed per level")
	c.near(hard.damage, normal.damage * 1.20, 0.001, "ascension adds 10% damage per level")


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
	c.near(hard.boss.max_hp, normal.boss.max_hp * 1.30, 0.001, "boss HP scales with ascension")
	c.near(hard.boss.damage, normal.boss.damage * 1.30, 0.001, "boss damage scales with ascension")
