extends RefCounted

const DT := 1.0 / 60.0


func _run(s: Sim, steps: int) -> void:
	for i in steps:
		s.step(DT, Vector2.ZERO)


func test_boon_roll_has_three_distinct_choices(c: Check) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var boons := Boon.roll(rng)
	c.eq(boons.size(), 3, "three boons are offered")
	var unique := {}
	for id in boons:
		c.ok(id in Boon.ALL, "known boon id")
		unique[id] = true
	c.eq(unique.size(), 3, "boon choices are distinct")


func test_endless_boss_offers_and_applies_a_boon(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.WON
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	c.ok(s.begin_endless(), "begin endless")
	s.start_wave(25)
	_run(s, 200)
	c.ok(s.boss != null, "boss spawns")
	s.damage_enemy(s.boss, 1000000.0, Vector2.ZERO, false, -1)
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.SHOP, "boss death returns to shop")
	c.eq(s.pending_boons.size(), 3, "boss offers three boons")
	var before_hp := s.player.hp
	c.ok(s.choose_boon(0), "a boon can be chosen")
	c.ok(s.pending_boons.is_empty(), "the choice is cleared")
	c.ok(s.player.hp >= before_hp, "vitality-like boon does not reduce health")


func test_boon_choice_rejects_bad_index(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	c.ok(not s.choose_boon(0), "no boons means no choice")
	s.pending_boons = Boon.roll(s.rng)
	c.ok(not s.choose_boon(-1), "negative index is rejected")
	c.ok(not s.choose_boon(99), "out-of-range index is rejected")
	c.eq(s.pending_boons.size(), 3, "failed choices keep the offer")


func test_each_boon_applies(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	var damage := s.player.stats.get_stat(Stats.DAMAGE_PCT)
	c.ok(Boon.apply(s, Boon.DAMAGE), "damage boon applies")
	c.near(s.player.stats.get_stat(Stats.DAMAGE_PCT), damage + 0.10, 0.001, "damage increases")
	var haste := s.player.stats.get_stat(Stats.ATTACK_SPEED_PCT)
	c.ok(Boon.apply(s, Boon.HASTE), "haste boon applies")
	c.near(s.player.stats.get_stat(Stats.ATTACK_SPEED_PCT), haste + 0.10, 0.001, "haste increases")
	var max_hp := s.player.max_hp()
	var hp := s.player.hp
	c.ok(Boon.apply(s, Boon.VITALITY), "vitality boon applies")
	c.near(s.player.max_hp(), max_hp + 15.0, 0.001, "max HP increases")
	c.near(s.player.hp, hp + 15.0, 0.001, "current HP increases")
	var echo := s.player.stats.get_stat(Stats.ECHO_POWER)
	c.ok(Boon.apply(s, Boon.ECHO), "echo boon applies")
	c.near(s.player.stats.get_stat(Stats.ECHO_POWER), echo + 0.10, 0.001, "echo power increases")
	var shield := s.player.stats.get_stat(Stats.SHIELD)
	c.ok(Boon.apply(s, Boon.SHIELD), "shield boon applies")
	c.near(s.player.stats.get_stat(Stats.SHIELD), shield + 5.0, 0.001, "shield cap increases")
	c.near(s.player.shield, shield + 5.0, 0.001, "current shield increases")
	var materials := s.player.materials
	c.ok(Boon.apply(s, Boon.FORTUNE), "fortune boon applies")
	c.eq(s.player.materials, materials + 30, "materials increase")
