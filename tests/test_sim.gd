extends RefCounted

const DT := 1.0 / 60.0


func _sim(seed_value: int = 1) -> Sim:
	var s := Sim.new(seed_value)
	s.start_run()
	return s


func _spawn(s: Sim, pos: Vector2, hp: float = 10.0) -> EnemyState:
	var e := EnemyState.new()
	e.uid = 9000 + s.enemies.size()
	e.def = Content.enemies()[0]
	e.pos = pos
	e.hp = hp
	e.max_hp = hp
	e.speed = 0.0
	e.damage = 3.0
	e.radius = 11.0
	s.enemies.append(e)
	return e


func _run(s: Sim, steps: int, dir: Vector2 = Vector2.ZERO) -> void:
	for i in steps:
		s.step(DT, dir)


func _immortal(s: Sim) -> void:
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()


func _finish_wave(s: Sim) -> void:
	s.wave_duration = 0.05
	_run(s, 5)


func test_silencer_touch_silences_echoes(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.player.weapons.clear()
	s.player.cooldowns.clear()
	var e := EnemyState.new()
	e.uid = 4242
	e.def = Content.enemy(&"silencer")
	e.pos = s.player.pos
	e.radius = e.def.radius
	e.max_hp = 100.0
	e.hp = 100.0
	e.damage = 0.0
	e.speed = 0.0
	s.enemies.append(e)
	var silences := [0]
	s.echoes_silenced.connect(func(_duration: float) -> void: silences[0] += 1)
	s.step(DT, Vector2.ZERO)
	c.ok(s.echo_silenced >= 2.0, "the touch silences echoes")
	c.eq(silences[0], 1, "the silence signal fires")


func test_player_moves_and_stays_in_arena(c: Check) -> void:
	var s := _sim()
	var start := s.player.pos
	_run(s, 10, Vector2.RIGHT)
	c.near(s.player.pos.x - start.x, 260.0 * 10.0 / 60.0, 0.01, "moves at move_speed")
	_run(s, 400, Vector2(5, 0))
	c.near(s.player.pos.x, Sim.ARENA.end.x - PlayerState.RADIUS, 0.01, "clamped to the right edge")
	_run(s, 400, Vector2(0, -1))
	c.near(s.player.pos.y, Sim.ARENA.position.y + PlayerState.RADIUS, 0.01, "clamped to the top edge")


func test_weapon_fires_only_at_enemies_in_reach(c: Check) -> void:
	var s := _sim()
	_spawn(s, s.player.pos + Vector2(500, 0))
	_run(s, 3)
	c.eq(s.projectiles.size(), 0, "no shot at an enemy out of reach")
	_spawn(s, s.player.pos + Vector2(0, -200))
	_run(s, 1)
	c.eq(s.projectiles.size(), 1, "one shot at the enemy in reach")
	c.ok(s.projectiles[0].vel.y < 0.0 and absf(s.projectiles[0].vel.x) < 0.001, "aimed at the enemy in reach")


func test_weapon_prefers_nearest_enemy(c: Check) -> void:
	var s := _sim()
	_spawn(s, s.player.pos + Vector2(300, 0))
	_spawn(s, s.player.pos + Vector2(-120, 0))
	_run(s, 1)
	c.ok(s.projectiles.size() == 1 and s.projectiles[0].vel.x < 0.0, "shoots the nearer enemy")


func test_projectile_kills_enemy_and_drops_material(c: Check) -> void:
	var s := _sim()
	var e := _spawn(s, s.player.pos + Vector2(120, 0), 5.0)
	_run(s, 60)
	c.ok(e.dead, "enemy died")
	c.eq(s.kills, 1, "kill counted")
	c.eq(s.enemies.size(), 0, "dead enemy removed")
	c.ok(s.pickups.size() + s.player.materials > 0, "material dropped")


func test_piercing_shot_hits_a_line_of_enemies(c: Check) -> void:
	var s := _sim()
	s.player.weapons.clear()
	s.player.cooldowns.clear()
	s.player.add_weapon(Content.weapon(&"rifle"))
	for dx in [120.0, 160.0, 200.0]:
		_spawn(s, s.player.pos + Vector2(dx, 0), 5.0)
	_run(s, 30)
	c.eq(s.kills, 3, "one rifle shot (pierce 2) killed all three")


func test_pickups_magnet_and_collect(c: Check) -> void:
	var s := _sim()
	var before := s.player.materials
	var near_pk := Pickup.new()
	near_pk.pos = s.player.pos + Vector2(60, 0)
	var far_pk := Pickup.new()
	far_pk.pos = s.player.pos + Vector2(300, 0)
	s.pickups.append(near_pk)
	s.pickups.append(far_pk)
	_run(s, 40)
	c.eq(s.player.materials, before + 1, "only the pickup within range was collected")
	c.eq(before, Sim.START_MATERIALS, "a run starts with some materials")
	c.eq(s.pickups.size(), 1, "far pickup stays on the ground")


func test_contact_damage_respects_iframes(c: Check) -> void:
	var s := _sim()
	_spawn(s, s.player.pos)
	var hp0 := s.player.hp
	_run(s, 1)
	c.near(s.player.hp, hp0 - 3.0, 0.001, "first touch hurts")
	_run(s, 20)
	c.near(s.player.hp, hp0 - 3.0, 0.001, "no damage during i-frames")
	_run(s, 20)
	c.near(s.player.hp, hp0 - 6.0, 0.001, "hurt again after i-frames")


func test_death_ends_the_run(c: Check) -> void:
	var s := _sim()
	var fired := [0]
	s.run_lost.connect(func() -> void: fired[0] += 1)
	s.player.hp = 1.0
	_spawn(s, s.player.pos)
	_run(s, 2)
	c.eq(s.phase, Sim.Phase.LOST, "phase is LOST")
	c.eq(fired[0], 1, "run_lost emitted once")
	var wave_time := s.wave_time
	_run(s, 5)
	c.near(s.wave_time, wave_time, 0.0001, "sim stops advancing after the run is lost")


func test_wave_end_opens_shop_and_records_an_echo(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.wave_duration = 4.0
	for i in 400:
		s.step(DT, Vector2.RIGHT if i < 100 else Vector2.ZERO)
		if s.phase != Sim.Phase.WAVE:
			break
	c.eq(s.phase, Sim.Phase.SHOP, "wave 1 ends in the shop")
	c.eq(s.bank.takes.size(), 1, "the wave was recorded as an echo")
	var take := s.bank.takes[0]
	c.ok(absf(float(take.samples.size()) - (4.0 * 30.0 + 1.0)) <= 1.0, "take length matches the wave")
	c.ok(take.samples[0].distance_to(Sim.ARENA.get_center()) < 0.01, "take starts at the arena centre")
	c.ok(take.samples[take.samples.size() - 1].x > take.samples[0].x, "take follows the movement")
	c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "shop stocked")


func test_echo_replays_with_reduced_power(c: Check) -> void:
	var s := Sim.new(1)
	var take := EchoTake.new()
	take.samples = PackedVector2Array([Vector2(300, 300), Vector2(300, 300)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.stats.add(Stats.CRIT_CHANCE, -1.0)
	s.bank.add(take)
	s.start_run()
	s.player.weapons.clear()
	s.player.cooldowns.clear()
	c.eq(s.echoes.size(), 1, "echo spawned for the wave")
	var e := _spawn(s, Vector2(400, 300), 100.0)
	_run(s, 20)
	c.near(e.max_hp - e.hp, 7.0 * s.echo_power(), 0.0001, "echo hit for pistol damage x echo power")
	c.ok(s.echo_power() < 1.0, "echoes hit for less than the player")


func test_echo_overflow_blocks_next_wave_until_discarded(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	_finish_wave(s)
	for i in 2:
		var extra := EchoTake.new()
		extra.weapons.append(Content.weapon(&"smg"))
		s.bank.add(extra)
	c.eq(s.bank.takes.size(), 3, "three takes after the wave")
	c.ok(not s.can_start_wave(), "cannot start while over capacity")
	s.discard_take(s.bank.weakest())
	c.ok(s.can_start_wave(), "can start once a take is discarded")
	s.start_next_wave()
	c.eq(s.phase, Sim.Phase.WAVE, "wave 2 running")
	c.eq(s.wave, 2, "wave counter advanced")
	c.eq(s.echoes.size(), 2, "two echoes replay")


func test_final_wave_wins_the_run(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	var won := [0]
	s.run_won.connect(func() -> void: won[0] += 1)
	s.start_wave(WaveDirector.FINAL_WAVE)
	_run(s, 200)
	c.ok(s.boss != null, "the boss spawned")
	s.damage_enemy(s.boss, 100000.0, Vector2.ZERO, false, -1)
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.WON, "phase is WON")
	c.eq(won[0], 1, "run_won emitted")


func test_boss_silences_the_echoes(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.start_wave(WaveDirector.FINAL_WAVE)
	_run(s, 200)
	c.ok(s.boss != null, "the boss spawned")
	s._boss_silence_cd = 0.01
	_run(s, 2)
	c.ok(s.echo_silenced > 0.0, "echoes are silenced")


func test_enemy_stats_scale_with_wave(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.start_wave(10)
	s.player.weapons.clear()
	s.player.cooldowns.clear()
	_run(s, 180)
	c.ok(s.enemies.size() > 0, "enemies spawned")
	var e := s.enemies[0]
	c.near(e.max_hp, e.def.hp * WaveDirector.hp_scale(10), 0.001, "hp scaled for wave 10")
	c.near(e.damage, e.def.damage * WaveDirector.damage_scale(10), 0.001, "damage scaled for wave 10")


func test_wave_end_pays_interest(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.player.weapons.clear()
	s.player.cooldowns.clear()
	s.enemies.clear()
	s.projectiles.clear()
	s.pickups.clear()
	s.player.materials = 100
	s.wave_start_materials = s.player.materials
	s.wave_duration = 0.01
	s.step(1.0 / 60.0, Vector2.ZERO)
	c.eq(s.phase, Sim.Phase.SHOP, "wave ends into shop")
	c.eq(s.last_wave_earned, 0, "no pickups this wave")
	c.eq(s.last_interest, 2, "two percent interest")
	c.eq(s.player.materials, 102, "interest is added")
	s.player.materials = 1000
	s.start_next_wave()
	s.wave_duration = 0.01
	s.step(1.0 / 60.0, Vector2.ZERO)
	c.eq(s.last_interest, Sim.INTEREST_CAP, "interest is capped")


func test_wave_end_splits_earned_and_interest(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.player.weapons.clear()
	s.player.cooldowns.clear()
	s.enemies.clear()
	s.projectiles.clear()
	s.pickups.clear()
	s.player.materials = 100
	s.wave_start_materials = 100
	var pk := Pickup.new()
	pk.pos = Vector2(900.0, 200.0)
	pk.value = 7
	s.pickups.append(pk)
	s.wave_duration = 0.01
	s.step(1.0 / 60.0, Vector2.ZERO)
	c.eq(s.last_wave_earned, 7, "uncollected pickup counts as earnings")
	c.eq(s.last_interest, 2, "interest is based on total materials")
	c.eq(s.player.materials, 109, "earnings plus interest")


func test_projectile_explosion_hits_neighbors(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.enemies.clear()
	s.projectiles.clear()
	s.pickups.clear()
	var primary := _spawn(s, Vector2(600.0, 400.0), 100.0)
	var neighbor := _spawn(s, Vector2(640.0, 400.0), 100.0)
	s.grid.clear()
	s.grid.insert(primary)
	s.grid.insert(neighbor)
	var p := Projectile.new()
	p.pos = primary.pos
	p.vel = Vector2.ZERO
	p.life = 1.0
	p.damage = 10.0
	p.radius = 4.0
	p.explosion_radius = 48.0
	p.explosion_damage = 0.5
	p.source = -1
	s.projectiles.append(p)
	Combat.step_projectiles(s, DT)
	c.ok(primary.hp <= 90.0, "direct hit lands")
	c.near(neighbor.hp, 95.0, 0.01, "explosion hits the neighbor for half damage")


func test_homing_projectile_turns_toward_enemy(c: Check) -> void:
	var s := _sim()
	_immortal(s)
	s.enemies.clear()
	s.projectiles.clear()
	s.pickups.clear()
	var target := _spawn(s, Vector2(700.0, 400.0), 100.0)
	s.grid.clear()
	s.grid.insert(target)
	var p := Projectile.new()
	p.pos = Vector2(600.0, 400.0)
	p.vel = Vector2(0.0, -100.0)
	p.life = 1.0
	p.radius = 2.0
	p.homing_turn = 3.0
	p.source = -1
	s.projectiles.append(p)
	Combat.step_projectiles(s, DT)
	c.ok(p.vel.x > 0.0, "homing bends toward the target")


func test_bomber_explodes_when_killed_near_player(c: Check) -> void:
	var s := _sim()
	s.player.iframes = 0.0
	s.player.hp = s.player.max_hp()
	var e := EnemyState.new()
	e.uid = 9100
	e.def = Content.enemy(&"bomber")
	e.pos = s.player.pos + Vector2(10.0, 0.0)
	e.radius = e.def.radius
	e.max_hp = 1.0
	e.hp = 1.0
	e.damage = 0.0
	s.enemies.append(e)
	var before := s.player.hp
	s.damage_enemy(e, 99.0, Vector2.ZERO, false, -1)
	c.ok(s.player.hp < before, "death explosion damages the player")
	c.ok(s.player.iframes > 0.0, "explosion grants iframes")


func test_same_seed_same_run(c: Check) -> void:
	var a := _sim(5)
	var b := _sim(5)
	var other := _sim(6)
	for s in [a, b, other]:
		_immortal(s)
		_run(s, 600, Vector2(0.3, 0.2))
	c.eq(a.kills, b.kills, "kills match")
	c.eq(a.enemies.size(), b.enemies.size(), "enemy counts match")
	c.eq(a.player.pos, b.player.pos, "player positions match")
	c.ok(a.enemies.size() > 0 and a.enemies[0].pos == b.enemies[0].pos, "enemy positions match")
	var differs := other.kills != a.kills or other.enemies.size() != a.enemies.size() \
			or (other.enemies.size() > 0 and a.enemies.size() > 0 and other.enemies[0].pos != a.enemies[0].pos)
	c.ok(differs, "a different seed plays out differently")
