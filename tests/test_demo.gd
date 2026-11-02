extends RefCounted


func test_campaign_wave_one_starts_alone(c: Check) -> void:
	var sim := _looper()
	sim.start_wave(1)
	c.eq(sim.bank.takes.size(), 0, "a campaign opening has no recorded past")
	c.eq(sim.echoes.size(), 0, "wave 1 does not invent an echo")


func test_demo_second_wave_is_the_walked_route(c: Check) -> void:
	var sim := _looper()
	sim.start_run()
	sim.start_wave(1)
	sim._plan.clear()
	c.eq(sim.echoes.size(), 0, "the demo does not invent a yesterday")
	sim.step(0.4, Vector2.RIGHT)
	sim.wave_duration = 0.01
	sim.wave_time = sim.wave_duration
	sim._plan.clear()
	sim.enemies.clear()
	sim.pending.clear()
	sim.step(0.05, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.SHOP, "wave 1 still reaches the shop")
	c.eq(sim.bank.takes.size(), 1, "the shop holds the route just walked")
	c.eq(sim.bank.takes[0].wave, 1, "that route is this run, not a built-in sample")
	c.ok(sim.bank.takes[0].samples.size() > 2, "the route has the walk in it")
	sim.start_wave(2)
	c.eq(sim.echoes.size(), 1, "wave 2 deploys the walked route")
	c.eq(sim.echoes[0].take.wave, 1, "the body on the field is the recording")
	var enemy := EnemyState.new()
	enemy.uid = 7
	enemy.def = Content.enemies()[0]
	enemy.pos = sim.echoes[0].pos + Vector2(70.0, 0.0)
	enemy.hp = 40.0
	enemy.max_hp = 40.0
	enemy.speed = 0.0
	enemy.damage = 1.0
	enemy.radius = 11.0
	sim.enemies.append(enemy)
	sim.step(0.2, Vector2.ZERO)
	c.ok(not sim.projectiles.is_empty() or enemy.hp < enemy.max_hp, "the replay spends a shot")


func test_clip_places_both_bodies_in_the_cross(c: Check) -> void:
	var layout := EchoArchive.clip_layout(Vector2(640.0, 360.0))
	var player: Vector2 = layout.player
	var echo: Vector2 = layout.echo
	var target: Vector2 = layout.target
	c.ok(EnemyBrain.in_cross(player, target, PlayerState.RADIUS), "the player is in the cross")
	c.ok(EnemyBrain.in_cross(echo, target, PlayerState.RADIUS), "yesterday is in the cross")
	c.ok(player.distance_to(echo) > PlayerState.RADIUS, "the two bodies stay apart")


func test_demo_shop_closes_after_the_replay(c: Check) -> void:
	var sim := Sim.new(5)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = 1
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.demo_closed = true
	ui.open(sim)
	c.ok(not ui.start_button.disabled, "the first shop still starts the recorded route")
	sim.wave = 2
	ui.refresh()
	c.ok(ui.start_button.disabled, "the demo stops after the route has been on the field")
	c.eq(ui.start_button.text, Loc.t("demo.done"), "the button says the demo is over")
	ui.free()


func test_daily_does_not_keep_a_demo(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.demo_run = true
	main.start_daily()
	c.ok(not main.demo_run, "daily clears the demo flag")
	c.ok(not main.shop_ui.demo_closed, "the daily shop is not a demo shop")
	for take: EchoTake in main.sim.bank.takes:
		c.ok(take.wave != 0, "daily does not receive the demo sample")
	main.free()


func _looper() -> Sim:
	var sim := Sim.new(9)
	Content.character(&"looper").apply(sim)
	return sim
