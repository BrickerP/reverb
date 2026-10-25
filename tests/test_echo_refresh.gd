extends RefCounted


func _take(s: Sim, wave: int = 1) -> EchoTake:
	var t := EchoTake.new()
	t.samples = PackedVector2Array([s.player.pos, s.player.pos + Vector2(20.0, 0.0)])
	t.weapons.append(Content.weapon(&"pistol"))
	t.levels.append(1)
	t.stats = s.player.stats.copy()
	t.wave = wave
	return t


func _shop_sim() -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	return s


func test_refresh_costs_scale_with_age(c: Check) -> void:
	var s := _shop_sim()
	var t := _take(s)
	c.eq(s.shop.echo_refresh_cost(t), Shop.ECHO_REFRESH_BASE, "a new take has the base cost")
	t.age = 1
	c.eq(s.shop.echo_refresh_cost(t), Shop.ECHO_REFRESH_BASE + Shop.ECHO_REFRESH_PER_AGE,
			"one consumed wave adds the age cost")
	t.age = 2
	c.eq(s.shop.echo_refresh_cost(t), Shop.ECHO_REFRESH_BASE + 2 * Shop.ECHO_REFRESH_PER_AGE,
			"two consumed waves add two age steps")


func test_refresh_spends_materials_and_undoes_exactly(c: Check) -> void:
	var s := _shop_sim()
	var t := _take(s)
	s.bank.add(t)
	t.age = 2
	s.player.materials = 20
	var before := ShopState.capture(s)
	var result := s.shop.refresh_echo(s, t)
	c.ok(result.ok, "refresh applies")
	c.eq(result.action, ShopResult.ECHO_REFRESH, "refresh action")
	c.eq(result.cost, 9, "refresh cost is reported")
	c.eq(s.player.materials, 11, "materials are spent")
	c.eq(t.age, 1, "one wave is restored")
	c.ok(s.shop.can_undo(), "refresh enters history")
	c.ok(s.shop.undo(s).ok, "undo applies")
	c.eq(s.player.materials, 20, "materials restored")
	c.eq(s.bank.takes[0].age, 2, "age restored")
	c.eq(ShopState.capture(s).to_dict(), before.to_dict(), "state restores exactly")


func test_refresh_rejects_new_and_poor_takes(c: Check) -> void:
	var s := _shop_sim()
	var fresh := _take(s)
	s.bank.add(fresh)
	var new_result := s.shop.refresh_echo(s, fresh)
	c.ok(not new_result.ok, "a new take cannot be refreshed")
	c.eq(new_result.reason, &"new", "new reason")
	c.ok(not s.shop.can_undo(), "rejected refresh creates no history")

	var old := _take(s, 2)
	s.bank.add(old)
	old.age = 2
	s.player.materials = 0
	var poor := s.shop.refresh_echo(s, old)
	c.ok(not poor.ok, "a poor refresh is rejected")
	c.eq(poor.reason, &"poor", "poor reason")
	c.eq(old.age, 2, "failed refresh leaves age unchanged")
	c.eq(s.player.materials, 0, "failed refresh spends nothing")

	s.phase = Sim.Phase.WAVE
	s.player.materials = 20
	var invalid := s.shop.refresh_echo(s, old)
	c.ok(not invalid.ok, "refresh is shop-only")
	c.eq(invalid.reason, &"invalid", "invalid reason")


func test_echo_set_reduces_refresh_cost(c: Check) -> void:
	var s := _shop_sim()
	var t := _take(s)
	s.bank.add(t)
	t.age = 1
	var base := s.shop.echo_refresh_cost(t, s)
	for id: StringName in [&"spare_deck", &"long_play", &"loud_speaker"]:
		s.player.add_item(Content.item(id))
	c.ok(bool(s.player.set_bonus_applied.get(&"echo", false)), "echo set completes")
	c.eq(s.shop.echo_refresh_cost(t, s), maxi(1, base - 2),
			"echo set discounts refresh by two")


func test_refresh_label_exists(c: Check) -> void:
	c.ok(not Loc.t("shop.refresh", [7]).begins_with("shop."),
			"refresh action has a localized label")
