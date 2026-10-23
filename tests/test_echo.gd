extends RefCounted

const DT := EchoTake.SAMPLE_DT


func _take(points: Array[Vector2]) -> EchoTake:
	var t := EchoTake.new()
	t.samples = PackedVector2Array(points)
	return t


func _weapon_take(weapon_ids: Array[StringName]) -> EchoTake:
	var t := EchoTake.new()
	for id in weapon_ids:
		t.weapons.append(Content.weapon(id))
	return t


func test_position_interpolates(c: Check) -> void:
	var t := _take([Vector2(0, 0), Vector2(30, 0), Vector2(30, 30)])
	c.near(t.duration(), 2.0 * DT, 0.0001, "duration")
	c.eq(t.position_at(0.0), Vector2(0, 0), "start")
	c.near(t.position_at(DT * 0.5).x, 15.0, 0.001, "first segment midpoint x")
	c.near(t.position_at(DT * 1.5).y, 15.0, 0.001, "second segment midpoint y")
	c.near(t.position_at(2.0 * DT).y, 30.0, 0.001, "end point")


func test_playback_rewinds_like_tape(c: Check) -> void:
	var t := _take([Vector2(0, 0), Vector2(30, 0), Vector2(30, 30)])
	var d := t.duration()
	c.near(t.position_at(d + DT).x, 30.0, 0.001, "one sample past the end is rewinding")
	c.near(t.position_at(d + DT).y, 0.0, 0.001, "one sample past the end is rewinding (y)")
	c.eq(t.position_at(2.0 * d), Vector2(0, 0), "full cycle returns to start")
	c.ok(t.is_rewinding(d * 1.5), "rewinding in second half of cycle")
	c.ok(not t.is_rewinding(d * 0.5), "not rewinding in first half")
	c.ok(not t.is_rewinding(d * 2.2), "forward again in the next cycle")


func test_degenerate_takes(c: Check) -> void:
	c.eq(EchoTake.new().position_at(5.0), Vector2.ZERO, "empty take")
	c.near(EchoTake.new().duration(), 0.0, 0.0001, "empty duration")
	var one := _take([Vector2(7, 9)])
	c.eq(one.position_at(3.0), Vector2(7, 9), "single sample take holds still")
	c.ok(not one.is_rewinding(3.0), "single sample never rewinds")


func test_recorder_samples_at_30hz(c: Check) -> void:
	var r := EchoRecorder.new()
	r.begin(Vector2(5, 5))
	for i in 60:
		r.record(Vector2(float(i), 0.0), 1.0 / 60.0)
	c.eq(r.samples.size(), 31, "one second at 60 Hz yields 31 samples")
	c.eq(r.samples[0], Vector2(5, 5), "first sample is the start position")


func test_recorder_finish_snapshots(c: Check) -> void:
	var r := EchoRecorder.new()
	r.begin(Vector2.ZERO)
	r.record(Vector2(1, 1), 0.1)
	var stats := Stats.new()
	var weapons: Array[WeaponDef] = [Content.weapon(&"pistol")]
	var take := r.finish(4, weapons, stats)
	stats.add(Stats.DAMAGE_PCT, 1.0)
	weapons.append(Content.weapon(&"smg"))
	r.begin(Vector2(9, 9))
	c.eq(take.weapons.size(), 1, "weapons are copied")
	c.near(take.stats.get_stat(Stats.DAMAGE_PCT), 0.0, 0.0001, "stats are copied")
	c.eq(take.wave, 4, "wave recorded")
	c.ok(take.samples.size() > 1 and take.samples[0] == Vector2.ZERO, "samples are copied")


func test_take_power_uses_weapon_levels(c: Check) -> void:
	var t := _weapon_take([&"pistol"])
	t.levels.append(2)
	c.near(t.power(), Content.weapon(&"pistol").level_dps(2), 0.001, "level scales echo power")


func test_bank_ages_and_expires(c: Check) -> void:
	var bank := EchoBank.new()
	var t := EchoTake.new()
	bank.add(t)
	c.eq(bank.age_after_wave(3).size(), 0, "wave 1 played, not expired")
	c.eq(bank.age_after_wave(3).size(), 0, "wave 2 played, not expired")
	var expired := bank.age_after_wave(3)
	c.eq(expired.size(), 1, "expires after its third wave")
	c.eq(bank.takes.size(), 0, "expired take removed")


func test_bank_overflow_and_trim_removes_weakest(c: Check) -> void:
	var bank := EchoBank.new()
	var weak := _weapon_take([&"pistol"])
	var strong := _weapon_take([&"pistol", &"smg", &"rifle"])
	var mid := _weapon_take([&"pistol", &"smg"])
	bank.add(strong)
	bank.add(weak)
	bank.add(mid)
	c.eq(bank.overflow(2), 1, "one take over capacity")
	c.ok(bank.weakest() == weak, "weakest picked by power")
	var removed := bank.trim_to(2)
	c.eq(removed.size(), 1, "trim removed one")
	c.ok(removed[0] == weak, "trim removed the weakest")
	c.ok(bank.takes.has(strong) and bank.takes.has(mid), "stronger takes kept")
	c.eq(bank.overflow(2), 0, "no overflow after trim")


func test_bank_discard_and_tints(c: Check) -> void:
	var bank := EchoBank.new()
	var a := EchoTake.new()
	var b := EchoTake.new()
	bank.add(a)
	bank.add(b)
	c.ok(a.tint_index != b.tint_index, "each take gets its own tint")
	c.ok(bank.discard(a), "discard returns true when present")
	c.ok(not bank.discard(a), "discard returns false when absent")
	c.eq(bank.takes.size(), 1, "one left")


func test_echo_projectiles_tag_the_kill_source(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	s.enemies.clear()
	s.projectiles.clear()
	s.pickups.clear()
	var def := Content.enemies()[0]
	var e := EnemyState.new()
	e.uid = 99
	e.def = def
	e.pos = Vector2(600.0, 400.0)
	e.radius = def.radius
	e.max_hp = 1.0
	e.hp = 1.0
	s.enemies.append(e)
	var p := Projectile.new()
	p.pos = e.pos - Vector2(8.0, 0.0)
	p.vel = Vector2(120.0, 0.0)
	p.damage = 10.0
	p.radius = 5.0
	p.life = 1.0
	p.source = 2
	s.projectiles.append(p)
	s.grid.clear()
	s.grid.insert(e)
	var seen: Array[int] = []
	s.enemy_killed.connect(func(_pos: Vector2, _color: Color, source: int) -> void: seen.append(source))
	Combat.step_projectiles(s, DT)
	c.ok(e.dead, "the projectile killed the enemy")
	c.eq(seen.size(), 1, "one kill signal")
	c.eq(seen[0], 2, "the echo slot is carried into the kill signal")
	c.eq(s.kills, 1, "kill counted")


func test_merge_two_takes(c: Check) -> void:
	var bank := EchoBank.new()
	var a := _take([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)])
	a.wave = 1
	a.weapons.append(Content.weapon(&"pistol"))
	a.weapons.append(Content.weapon(&"smg"))
	bank.add(a)
	a.age = 1
	var b := _take([Vector2(100, 100), Vector2(120, 120)])
	b.wave = 3
	b.weapons.append(Content.weapon(&"rifle"))
	bank.add(b)
	var m := bank.merge(a, b)
	c.ok(m != null and m.merged, "merged take")
	c.eq(bank.takes.size(), 1, "two takes became one")
	c.eq(m.wave, 3, "newest wave label")
	c.eq(m.age, 1, "the older take's age is kept")
	c.eq(m.weapons.size(), 3, "both loadouts are kept")
	c.eq(m.samples.size(), a.samples.size() + EchoBank.BRIDGE_SAMPLES + b.samples.size(), "routes are joined")
	c.ok(not bank.takes.has(a) and not bank.takes.has(b), "sources are consumed")


func test_take_power_uses_stats(c: Check) -> void:
	var t := _weapon_take([&"pistol"])
	c.near(t.power(), 14.0, 0.001, "pistol power is its dps")
	t.stats.add(Stats.DAMAGE_PCT, 0.5)
	t.stats.add(Stats.ATTACK_SPEED_PCT, 1.0)
	c.near(t.power(), 42.0, 0.001, "damage and attack speed scale power")
