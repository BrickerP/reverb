extends RefCounted


func test_key_moments_own_one_bounded_accent(c: Check) -> void:
	var ink := MomentInk.new()
	c.ok(ink.offer(&"combo", Vector2(300, 200)), "real combo takes the local accent")
	for index in 20:
		c.ok(not ink.offer(&"combo", Vector2(index, 0)), "same-tick copies cannot replace or refresh it")
	c.eq(ink.snapshot()["pos"], Vector2(300, 200), "first meaningful result stays visible")
	c.ok(ink.offer(&"hurt", Vector2(400, 200)), "player damage interrupts a routine combo accent")
	c.ok(not ink.offer(&"ready", Vector2.ZERO), "charge readiness cannot cover damage")
	ink.step(0.5)
	c.ok(not ink.active(), "attention returns after the short accent")
	c.ok(ink.offer(&"repair", Vector2.ZERO), "later independent work can be acknowledged")


func test_accent_snapshots_are_detached_and_bad_events_are_rejected(c: Check) -> void:
	var ink := MomentInk.new()
	c.ok(not ink.offer(&"unknown", Vector2.ZERO), "no invented generic accent")
	c.ok(not ink.offer(&"skill", Vector2.INF), "invalid geometry is not drawn")
	ink.offer(&"skill", Vector2(180, 240))
	var snapshot := ink.snapshot()
	snapshot["pos"] = Vector2.ZERO
	c.eq(ink.snapshot()["pos"], Vector2(180, 240), "evidence inspection cannot change the live mark")
	ink.step(-1)
	ink.step(NAN)
	c.near(float(ink.snapshot()["progress"]), 0.0, 0.00001, "invalid time cannot advance the accent")
	ink.clear()
	c.ok(ink.snapshot().is_empty(), "detach drops presentation state")


func test_offscreen_copy_cannot_take_visible_attention(c: Check) -> void:
	var sim := Sim.new(4)
	sim.start_run()
	sim.player.pos = Vector2(400, 400)
	var view := ArenaView.new()
	view.bind(sim)
	var combo := ComboInfo.new()
	combo.affected = 1
	combo.pos = sim.player.pos + Vector2(1800, 0)
	view._on_combo(combo)
	c.ok(not view._moment.active(), "offscreen combo does not own the screen accent")
	c.ok(view._offer_moment(&"ready", sim.player.pos), "visible readiness remains available")
	c.ok(view.moment_visible(), "only visible moments reduce routine drawing")
	sim.player.pos += Vector2(1700, 0)
	c.ok(not view.moment_visible(), "moving away restores routine drawing immediately")
	c.ok(view._offer_moment(&"repair", sim.player.pos), "offscreen old marks cannot block new local work")
	view.free()
