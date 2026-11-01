extends RefCounted


func test_campaign_wave_one_starts_alone(c: Check) -> void:
	var sim := _looper()
	sim.start_wave(1)
	c.eq(sim.bank.takes.size(), 0, "a campaign opening has no recorded past")
	c.eq(sim.echoes.size(), 0, "wave 1 does not invent an echo")


func test_demo_take_stands_beside_the_player(c: Check) -> void:
	var sim := _looper()
	var origin := Sim.ARENA.get_center()
	var take := EchoArchive.demo_take(origin)
	c.eq(take.condition, EchoArchive.INHERITED_CONDITION, "the demo copy uses the inherited condition")
	c.eq(take.weapons.size(), 1, "one pistol")
	c.eq(take.weapons[0].id, &"pistol", "the pistol is the only gun")
	sim.bank.add(take)
	var opened := take.condition
	var uid := take.uid
	sim.start_wave(1)
	c.eq(sim.echoes.size(), 1, "the opening field has one yesterday")
	c.ok(sim.echoes[0].pos.distance_to(sim.player.pos) > PlayerState.RADIUS,
			"yesterday does not stand inside the player")
	sim.step(1.0, Vector2.ZERO)
	c.ok(sim.echoes[0].take.condition < opened, "playback wears the copy")
	sim.wave_duration = 0.01
	sim.wave_time = sim.wave_duration
	sim._plan.clear()
	sim.enemies.clear()
	sim.pending.clear()
	sim.step(0.05, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.SHOP, "the wave still ends")
	c.eq(sim.bank.takes.size(), 2, "the worn copy stays and the new route is recorded")
	var kept := sim.bank.find_uid(uid)
	c.ok(kept != null and kept.condition < opened, "the demo copy keeps a lower condition")


func test_clip_places_both_bodies_in_the_cross(c: Check) -> void:
	var layout := EchoArchive.clip_layout(Vector2(640.0, 360.0))
	var player: Vector2 = layout.player
	var echo: Vector2 = layout.echo
	var target: Vector2 = layout.target
	c.ok(EnemyBrain.in_cross(player, target, PlayerState.RADIUS), "the player is in the cross")
	c.ok(EnemyBrain.in_cross(echo, target, PlayerState.RADIUS), "yesterday is in the cross")
	c.ok(player.distance_to(echo) > PlayerState.RADIUS, "the two bodies stay apart")


func test_demo_shop_does_not_open_the_next_wave(c: Check) -> void:
	var sim := Sim.new(5)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = 1
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.demo_closed = true
	ui.open(sim)
	c.ok(ui.start_button.disabled, "the demo stops after the first shop")
	c.eq(ui.start_button.text, Loc.t("demo.done"), "the button says the demo is over")
	ui.free()


func _looper() -> Sim:
	var sim := Sim.new(9)
	Content.character(&"looper").apply(sim)
	return sim
