extends RefCounted


func _take(s: Sim, wave: int = 1) -> EchoTake:
	var t := EchoTake.new()
	t.samples = PackedVector2Array([s.player.pos, s.player.pos + Vector2(24.0, 0.0)])
	t.weapons.append(Content.weapon(&"pistol"))
	t.levels.append(2)
	t.stats = s.player.stats.copy()
	t.stats.add(Stats.DAMAGE_PCT, 0.2)
	t.wave = wave
	t.age = 1
	return t


func _shop_sim() -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	return s


func test_discard_echo_is_exact_undo(c: Check) -> void:
	var s := _shop_sim()
	var keep := _take(s, 1)
	var gone := _take(s, 2)
	s.bank.add(keep)
	s.bank.add(gone)
	gone.age = 1
	var before := ShopState.capture(s)
	var result := s.shop.discard_echo(s, gone)
	c.ok(result.ok, "discard applies")
	c.eq(s.bank.takes.size(), 1, "one take remains")
	c.ok(s.bank.takes.has(keep), "the other take remains")
	c.ok(s.shop.can_undo(), "discard enters history")
	c.ok(s.shop.undo(s).ok, "undo applies")
	c.eq(s.bank.takes.size(), 2, "both takes restored")
	var restored: EchoTake
	for t in s.bank.takes:
		if t.wave == 2:
			restored = t
	c.ok(restored != null, "the discarded take is back")
	c.eq(restored.samples.size(), gone.samples.size(), "route restored")
	c.eq(restored.weapons[0].id, &"pistol", "weapon restored")
	c.eq(restored.level_at(0), 2, "level restored")
	c.near(restored.stats.get_stat(Stats.DAMAGE_PCT), 0.2, 0.001, "stats restored")
	c.eq(restored.age, 1, "age restored")
	c.eq(restored.tint_index, gone.tint_index, "tint restored")
	c.eq(ShopState.capture(s).to_dict(), before.to_dict(), "state restores exactly")


func test_merge_echoes_is_exact_undo(c: Check) -> void:
	var s := _shop_sim()
	var a := _take(s, 1)
	var b := _take(s, 2)
	s.bank.add(a)
	s.bank.add(b)
	var before := ShopState.capture(s)
	var result := s.shop.merge_echoes(s, a, b)
	c.ok(result.ok, "merge applies")
	c.eq(s.bank.takes.size(), 1, "two takes become one")
	c.ok(s.bank.takes[0].merged, "the take is marked merged")
	c.ok(s.shop.undo(s).ok, "undo applies")
	c.eq(s.bank.takes.size(), 2, "both source takes restored")
	c.ok(s.bank.takes[0].samples.size() == a.samples.size(), "route A restored")
	c.ok(s.bank.takes[1].samples.size() == b.samples.size(), "route B restored")
	c.eq(s.bank.takes[0].weapons[0].id, &"pistol", "weapon A restored")
	c.eq(s.bank.takes[1].level_at(0), 2, "level B restored")
	c.eq(ShopState.capture(s).to_dict(), before.to_dict(), "merged state undoes exactly")


func test_existing_echo_compatibility_methods_still_work(c: Check) -> void:
	var s := _shop_sim()
	var t := _take(s)
	s.bank.add(t)
	s.discard_take(t)
	c.eq(s.bank.takes.size(), 0, "direct discard remains compatible")
