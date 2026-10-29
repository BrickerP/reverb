extends RefCounted

const DT := 1.0 / 60.0


func _sim(seed_value: int = 7) -> Sim:
	var s := Sim.new(seed_value)
	s.start_run()
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	return s


func _run(s: Sim, seconds: float) -> void:
	var steps := int(ceil(seconds / DT))
	for i in steps:
		s.step(DT, Vector2.ZERO)


func _clear_spawns(s: Sim) -> void:
	s._plan.clear()
	s._plan_idx = 0
	s.pending.clear()
	s.enemies.clear()


func test_rifts_start_at_wave_six(c: Check) -> void:
	var before := _sim()
	before.start_wave(5)
	_clear_spawns(before)
	_run(before, 14.0)
	c.eq(before.rifts.size(), 0, "no rifts before wave 12")

	var s := _sim()
	s.start_wave(6)
	_clear_spawns(s)
	_run(s, 7.8)
	c.eq(s.rifts.size(), 0, "first rift waits for its delay")
	_run(s, 0.3)
	c.eq(s.rifts.size(), 1, "wave 12 spawns a rift")
	c.ok(s.rifts[0].is_warning(), "the new rift telegraphs first")
	var pos := s.rifts[0].pos
	c.ok(Sim.ARENA.has_point(pos), "the rift is inside the arena")

	var final := _sim()
	final.start_wave(WaveDirector.FINAL_WAVE)
	_clear_spawns(final)
	_run(final, 20.0)
	c.eq(final.rifts.size(), 0, "the boss wave has no rifts")

	var endless := _sim()
	endless.endless = true
	endless.start_wave(WaveDirector.FINAL_WAVE + 1)
	_clear_spawns(endless)
	_run(endless, 8.2)
	c.eq(endless.rifts.size(), 1, "endless waves bring the rift back")


func test_rift_warns_then_damages_only_inside(c: Check) -> void:
	var s := _sim()
	s.start_wave(6)
	_clear_spawns(s)
	var spawned := [0]
	var activated := [0]
	var ended := [0]
	s.rift_spawned.connect(func(_rift: TemporalRift) -> void: spawned[0] += 1)
	s.rift_activated.connect(func(_rift: TemporalRift) -> void: activated[0] += 1)
	s.rift_ended.connect(func(_rift: TemporalRift) -> void: ended[0] += 1)
	_run(s, 8.1)
	c.eq(spawned[0], 1, "spawn signal fires")
	var rift: TemporalRift = s.rifts[0]
	var hp := s.player.hp
	_run(s, 1.2)
	c.eq(s.player.hp, hp, "warning does not damage")
	_run(s, 0.4)
	c.eq(activated[0], 1, "activation signal fires")
	c.ok(rift.is_active(), "the rift is active")
	s.player.pos = rift.pos
	s.player.iframes = 0.0
	_run(s, 0.8)
	c.ok(s.player.hp < hp, "the active rift damages a player inside")
	c.eq(s.last_damage_source, &"rift", "rift damage records its source")
	c.eq(s.player.iframes, 0.0, "rift damage does not grant contact iframes")
	var hurt_hp := s.player.hp
	var away := Vector2(Sim.ARENA.position.x + 20.0, Sim.ARENA.position.y + 20.0)
	for corner: Vector2 in [Sim.ARENA.position + Vector2(20.0, 20.0),
			Vector2(Sim.ARENA.end.x - 20.0, Sim.ARENA.position.y + 20.0),
			Sim.ARENA.end - Vector2(20.0, 20.0),
			Vector2(Sim.ARENA.position.x + 20.0, Sim.ARENA.end.y - 20.0)]:
		if corner.distance_to(rift.pos) > away.distance_to(rift.pos):
			away = corner
	s.player.pos = away
	s.player.iframes = 0.0
	_run(s, 0.8)
	c.eq(s.player.hp, hurt_hp, "a player outside the active rift is safe")
	_run(s, 3.5)
	c.eq(ended[0], 1, "rift end signal fires")
	c.eq(s.rifts.size(), 0, "expired rifts compact away")


func test_rift_spawn_is_seeded(c: Check) -> void:
	var a := _sim(41)
	var b := _sim(41)
	a.start_wave(6)
	b.start_wave(6)
	_clear_spawns(a)
	_clear_spawns(b)
	_run(a, 8.1)
	_run(b, 8.1)
	c.eq(a.rifts.size(), 1, "first sim has a rift")
	c.eq(b.rifts.size(), 1, "second sim has a rift")
	c.near(a.rifts[0].pos.x, b.rifts[0].pos.x, 0.001, "same seed gives the same x")
	c.near(a.rifts[0].pos.y, b.rifts[0].pos.y, 0.001, "same seed gives the same y")
