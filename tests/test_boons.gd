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
	for id in Boon.ALL:
		c.ok(not Loc.t(Boon.title_key(id)).begins_with("boon."),
				"%s has a localized title" % id)
		c.ok(not Loc.t(Boon.desc_key(id)).begins_with("boon."),
				"%s has a localized description" % id)


func test_endless_boss_offers_and_applies_a_boon(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.WON
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	c.ok(s.begin_endless(), "begin endless")
	s.start_wave(WaveDirector.FINAL_WAVE + 4)
	_run(s, 200)
	c.ok(s.boss != null, "boss spawns")
	s.damage_enemy(s.boss, 1000000.0, Vector2.ZERO, false, -1)
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.SHOP, "boss death returns to shop")
	c.eq(s.pending_boons.size(), 3, "boss offers three boons")
	var before_hp := s.player.hp
	var chosen := s.pending_boons[0]
	c.ok(s.choose_boon(0), "a boon can be chosen")
	c.ok(s.pending_boons.is_empty(), "the choice is cleared")
	c.ok(s.boons_taken.has(chosen), "the chosen boon is recorded")
	c.ok(s.player.hp >= before_hp, "vitality-like boon does not reduce health")


func test_boon_choice_rejects_bad_index(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	c.ok(not s.choose_boon(0), "no boons means no choice")
	s.pending_boons = Boon.roll(s.rng)
	c.ok(not s.choose_boon(-1), "negative index is rejected")
	c.ok(not s.choose_boon(99), "out-of-range index is rejected")
	c.eq(s.pending_boons.size(), 3, "failed choices keep the offer")


func test_boons_never_change_echo_capacity(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.player.stats.values[Stats.ECHO_SLOTS] = 0.0
	for id in Boon.ALL:
		if id == Boon.RESERVOIR:
			c.ok(not Boon.apply(s, id), "reservoir refuses a zero-slot character")
		else:
			c.ok(Boon.apply(s, id), "%s applies on a zero-slot character" % id)
	c.eq(s.echo_capacity(), 0, "no boon breaks the Soloist's zero-slot identity")


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
	var crit := s.player.stats.get_stat(Stats.CRIT_CHANCE)
	c.ok(Boon.apply(s, Boon.PRECISION), "precision boon applies")
	c.near(s.player.stats.get_stat(Stats.CRIT_CHANCE), crit + 0.05, 0.001, "crit increases")
	var move := s.player.stats.get_stat(Stats.MOVE_SPEED)
	c.ok(Boon.apply(s, Boon.SLIPSTREAM), "slipstream boon applies")
	c.near(s.player.stats.get_stat(Stats.MOVE_SPEED), move + 20.0, 0.001, "move speed increases")
	var pickup := s.player.stats.get_stat(Stats.PICKUP_RANGE)
	c.ok(Boon.apply(s, Boon.MAGNET), "magnet boon applies")
	c.near(s.player.stats.get_stat(Stats.PICKUP_RANGE), pickup + 30.0, 0.001,
			"pickup range increases")
	var duration := s.echo_duration()
	c.ok(Boon.apply(s, Boon.ETERNITY), "eternity boon applies")
	c.near(s.echo_duration(), duration + 40.0, 0.001, "eternity adds forty seconds of deployed playback")
	c.ok(Boon.apply(s, Boon.SECOND_WIND), "second wind boon applies")
	c.eq(s.second_wind_charges, 1, "second wind grants one charge")
	var slots := s.echo_capacity()
	c.ok(Boon.apply(s, Boon.RESERVOIR), "reservoir boon applies")
	c.eq(s.echo_capacity(), slots + 1, "reservoir adds an echo slot")


func test_zero_slot_boons_skip_echo_options(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.player.stats.values[Stats.ECHO_SLOTS] = 0.0
	for i in 20:
		var boons := Boon.roll(s.rng, 3, s)
		c.eq(boons.size(), 3, "zero-slot rolls still offer three boons")
		c.ok(not boons.has(Boon.ECHO), "echo power is filtered")
		c.ok(not boons.has(Boon.ETERNITY), "echo duration is filtered")
		c.ok(not boons.has(Boon.RESERVOIR), "echo capacity is filtered")


func test_boon_reroll_spends_increasing_materials(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.pending_boons = Boon.roll(s.rng)
	s.player.materials = 100
	var first_cost := s.boon_reroll_cost()
	c.eq(first_cost, 15, "first reroll costs 15")
	c.ok(s.reroll_boons(), "first reroll applies")
	c.eq(s.player.materials, 100 - first_cost, "first reroll spends materials")
	c.eq(s.boon_rerolls, 1, "reroll count increases")
	c.eq(s.pending_boons.size(), 3, "reroll keeps three choices")
	var second_cost := s.boon_reroll_cost()
	c.eq(second_cost, 25, "second reroll costs more")
	c.ok(s.reroll_boons(), "second reroll applies")
	c.eq(s.player.materials, 100 - first_cost - second_cost, "second reroll spends materials")

	var poor := Sim.new(7)
	poor.start_run()
	poor.phase = Sim.Phase.SHOP
	poor.pending_boons = Boon.roll(poor.rng)
	poor.player.materials = 0
	c.ok(not poor.reroll_boons(), "a poor reroll is rejected")
	c.eq(poor.pending_boons.size(), 3, "failed reroll keeps the offer")
	c.eq(poor.boon_rerolls, 0, "failed reroll does not increase the counter")


func test_second_wind_consumes_one_charge_per_lethal_hit(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	c.eq(s.second_wind_charges, 0, "no starting second wind")
	s.player.hp = 5.0
	s._hurt_player(10.0, &"test", &"contact", s.player.pos, Vector2.RIGHT)
	c.ok(s.player.hp <= 0.0, "without a charge a lethal hit stays lethal")
	s.player.hp = 5.0
	c.ok(Boon.apply(s, Boon.SECOND_WIND), "second wind applies")
	s._hurt_player(10.0, &"test", &"contact", s.player.pos, Vector2.RIGHT)
	c.eq(s.player.hp, 1.0, "the first charge saves the run at 1 HP")
	c.eq(s.second_wind_charges, 0, "the charge is consumed")
	s._hurt_player(10.0, &"test", &"contact", s.player.pos, Vector2.RIGHT)
	c.ok(s.player.hp <= 0.0, "the next lethal hit is not saved")
