extends RefCounted

const DT := 1.0 / 60.0


func _run(s: Sim, steps: int) -> void:
	for i in steps:
		s.step(DT, Vector2.ZERO)


func test_begin_endless_only_after_a_win(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	c.ok(not s.begin_endless(), "cannot begin endless during a wave")
	s.phase = Sim.Phase.WON
	c.ok(s.begin_endless(), "begin endless after winning")
	c.ok(s.endless, "endless is flagged")
	c.eq(s.phase, Sim.Phase.SHOP, "endless starts in a shop")
	c.eq(s.wave, WaveDirector.FINAL_WAVE, "the shop follows wave 20")
	c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "endless shop is stocked")
	c.ok(not s.begin_endless(), "endless cannot be started twice")


func test_boss_rush_skips_normal_waves(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	c.ok(not s.begin_boss_rush(), "boss rush requires a victory")
	s.phase = Sim.Phase.WON
	c.ok(s.begin_boss_rush(), "boss rush starts after a victory")
	c.ok(s.endless, "boss rush is an endless run")
	c.ok(s.boss_rush, "boss rush is flagged")
	c.eq(s.phase, Sim.Phase.SHOP, "boss rush starts in a shop")
	c.eq(s.wave, WaveDirector.FINAL_WAVE, "the victory wave is retained for the shop")
	c.eq(s.pending_boons.size(), 3, "boss rush opens with a boon choice")
	c.ok(s.choose_boon(0), "boss rush starting boon can be chosen")
	c.eq(s.pending_boons.size(), 0, "starting boon is consumed before the shop")
	c.eq(s.next_wave_number(), 16, "the first boss rush wave is 16")
	s.start_next_wave()
	c.eq(s.wave, 16, "boss rush starts at wave 16")
	c.ok(s.is_boss_wave(16), "wave 16 is a boss wave")
	c.eq(s.next_wave_number(), 20, "the next shop targets wave 20")


func test_boss_rush_zero_slot_build_gets_a_shield(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.player.stats.values[Stats.ECHO_SLOTS] = 0.0
	s.phase = Sim.Phase.WON
	c.ok(s.begin_boss_rush(), "enter boss rush with zero slots")
	c.near(s.player.max_shield(), Sim.BOSS_RUSH_SOLO_SHIELD, 0.001,
			"zero-slot boss rush gains a shield cap")
	c.near(s.player.shield, Sim.BOSS_RUSH_SOLO_SHIELD, 0.001,
			"the shield starts filled")
	c.eq(s.pending_boons.size(), 3, "zero-slot boss rush opens with a boon")
	c.ok(s.choose_boon(0), "choose the first bonus boon")
	c.eq(s.pending_boons.size(), 3, "zero-slot boss rush offers a second boon")
	c.ok(s.choose_boon(0), "choose the second bonus boon")
	c.eq(s.pending_boons.size(), 0, "both starting boons are consumed")


func test_boss_rush_boss_returns_to_shop_and_targets_wave_20(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	s.phase = Sim.Phase.WON
	c.ok(s.begin_boss_rush(), "begin boss rush")
	c.ok(s.choose_boon(0), "choose the starting boon")
	s.start_next_wave()
	_run(s, 200)
	c.ok(s.boss != null, "boss rush spawns Paradox")
	s.damage_enemy(s.boss, 1000000.0, Vector2.ZERO, false, -1)
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.SHOP, "boss rush boss returns to shop")
	c.eq(s.wave, 16, "boss rush keeps the boss wave number")
	c.eq(s.next_wave_number(), 20, "the next boss rush wave skips to 20")
	c.eq(s.pending_boons.size(), 3, "boss rush offers the endless boon choice")


func test_endless_wave_has_no_boss_and_returns_to_shop(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.WON
	c.ok(s.begin_endless(), "begin endless")
	s.start_next_wave()
	c.eq(s.wave, WaveDirector.FINAL_WAVE + 1, "wave 21 starts")
	c.eq(s.phase, Sim.Phase.WAVE, "wave 21 is live")
	c.ok(s.boss == null, "no boss in endless")
	s.wave_duration = 0.05
	_run(s, 5)
	c.eq(s.phase, Sim.Phase.SHOP, "endless wave returns to the shop")
	c.eq(s.wave, WaveDirector.FINAL_WAVE + 1, "the endless wave number is retained")
	c.ok(s.shop.offers.size() == Shop.OFFER_COUNT, "the next endless shop is stocked")


func test_endless_death_is_a_loss_not_a_second_win(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.WON
	c.ok(s.begin_endless(), "begin endless")
	s.start_next_wave()
	s.player.hp = 0.0
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.LOST, "endless death ends in LOST")
	c.ok(s.endless, "the run is still marked endless")


func test_endless_boss_returns_every_four_waves(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.WON
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	c.ok(s.begin_endless(), "begin endless")
	c.ok(s.is_boss_wave(16), "wave 16 is an endless boss wave")
	c.ok(not s.is_boss_wave(15), "wave 15 is not a boss wave")
	s.start_wave(16)
	_run(s, 200)
	c.ok(s.boss != null, "the endless boss spawns")
	c.near(s.boss.max_hp, Content.enemy(&"foreman").hp * 1.8, 0.001,
			"endless boss health scales with the wave")
	var wins := [0]
	s.run_won.connect(func() -> void: wins[0] += 1)
	s.damage_enemy(s.boss, 1000000.0, Vector2.ZERO, false, -1)
	_run(s, 1)
	c.eq(s.phase, Sim.Phase.SHOP, "killing an endless boss returns to the shop")
	c.eq(s.wave, 16, "the endless wave number remains")
	c.eq(wins[0], 0, "an endless boss does not emit run_won")
