extends RefCounted


func _take(s: Sim, wave: int = 1) -> EchoTake:
	var t := EchoTake.new()
	t.samples = PackedVector2Array([s.player.pos, s.player.pos + Vector2(20.0, 0.0)])
	t.weapons.append(Content.weapon(&"pistol"))
	t.levels.append(0)
	t.stats = s.player.stats.copy()
	t.wave = wave
	return t


func _sim_with_echoes(count: int = 1) -> Sim:
	var s := Sim.new(7)
	s.start_run()
	for i in count:
		s.bank.add(_take(s, i + 1))
	s.start_wave(2)
	return s


func test_collapse_consumes_the_oldest_echo(c: Check) -> void:
	var s := _sim_with_echoes(2)
	c.eq(s.echoes.size(), 2, "two echoes active")
	var oldest := s.echoes[0]
	var remaining := s.echoes[1]
	c.ok(s.can_collapse_echo(), "collapse is available in a wave with echoes")
	var target := EnemyState.new()
	target.uid = 99
	target.def = Content.enemy(&"grunt")
	target.pos = oldest.pos + Vector2(40.0, 0.0)
	target.hp = 1000.0
	target.max_hp = 1000.0
	target.speed = 0.0
	target.damage = 0.0
	s.enemies.append(target)
	s.player.hp = 10.0
	var before_hp := s.player.hp
	var before_enemy := target.hp
	var collapsed: Array[Vector2] = []
	var blasts: Array[ExplosionInfo] = []
	s.echo_collapsed.connect(func(pos: Vector2, _color: Color, _radius: float) -> void:
		collapsed.append(pos))
	s.explosion_info.connect(func(info: ExplosionInfo) -> void: blasts.append(info))
	c.ok(s.collapse_oldest_echo(), "collapse succeeds")
	c.eq(s.bank.takes.size(), 1, "the take is removed from the bank")
	c.eq(s.echoes.size(), 1, "the actor is removed")
	c.eq(s.echoes[0], remaining, "the newer echo survives")
	c.eq(s.echoes[0].index, 0, "the survivor is reindexed")
	c.eq(s.collapse_used, true, "collapse is marked used")
	c.ok(not s.can_collapse_echo(), "collapse is unavailable again this wave")
	c.ok(not s.collapse_oldest_echo(), "a second collapse is refused")
	c.ok(s.player.hp > before_hp, "collapse heals the player")
	c.ok(target.hp < before_enemy, "collapse damages a nearby enemy")
	c.eq(collapsed.size(), 1, "collapse signal fires once")
	c.near(collapsed[0].distance_to(oldest.pos), 0.0, 0.001, "burst is at the echo position")
	c.eq(blasts.size(), 1, "collapse emits one explosion event")
	c.eq(blasts[0].effect, &"echo_collapse", "the explosion identifies the collapse")


func test_collapse_rejects_empty_or_far_targets(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	c.ok(not s.can_collapse_echo(), "no echoes means no collapse")
	c.ok(not s.collapse_oldest_echo(), "empty collapse is refused")

	var with_echo := _sim_with_echoes(1)
	var far := EnemyState.new()
	far.uid = 100
	far.def = Content.enemy(&"grunt")
	far.pos = with_echo.echoes[0].pos + Vector2(500.0, 0.0)
	far.hp = 100.0
	far.max_hp = 100.0
	with_echo.enemies.append(far)
	var before := far.hp
	c.ok(with_echo.collapse_oldest_echo(), "collapse still consumes the echo")
	c.eq(far.hp, before, "an enemy outside the burst is untouched")


func test_collapse_resets_next_wave(c: Check) -> void:
	var s := _sim_with_echoes(2)
	c.ok(s.collapse_oldest_echo(), "collapse in wave 2")
	c.ok(not s.can_collapse_echo(), "used for the wave")
	s.start_wave(3)
	c.ok(s.can_collapse_echo(), "a new wave restores collapse")
	c.eq(s.echoes.size(), 1, "only the surviving echo starts the next wave")
