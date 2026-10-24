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
