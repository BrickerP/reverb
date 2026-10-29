extends RefCounted


func test_camera_tracks_world_without_moving_simulation(c: Check) -> void:
	c.eq(Sim.ARENA, WorldArena.BOUNDS, "simulation uses the larger machine floor")
	c.eq(Sim.VIEWPORT.size, Vector2(1200.0, 600.0), "HUD-safe window keeps its original size")
	for focus in [WorldArena.BOUNDS.position, WorldArena.BOUNDS.get_center(), WorldArena.BOUNDS.end]:
		var camera := WorldArena.camera_rect(focus)
		c.ok(WorldArena.BOUNDS.encloses(camera), "camera never exposes beyond world bounds")
		c.eq(camera.size, WorldArena.VIEWPORT.size, "camera preserves the viewport size")
	var sim := Sim.new(144)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var before := sim.player.pos
	var rng := sim.rng.state
	view.set_cropped(true)
	c.eq(view.position, -WorldArena.camera_rect(before).position, "cropped drawing translates the world parent only")
	view.set_paused(true)
	c.eq(view.position, -WorldArena.camera_rect(before).position, "pause preserves camera position")
	c.eq(sim.player.pos, before, "camera never rewrites world coordinates")
	c.eq(sim.rng.state, rng, "camera never uses the simulation RNG")
	for edge in [WorldArena.BOUNDS.position, WorldArena.BOUNDS.end]:
		sim.player.pos = edge
		for shake in [Vector2(-9.0, -9.0), Vector2(9.0, 9.0)]:
			view._update_camera(shake)
			c.ok(WorldArena.BOUNDS.encloses(view.camera_profile()["world_rect"]),
				"screen shake cannot expose beyond a world boundary")
	view.free()


func test_body_sweeps_cannot_tunnel_through_cover(c: Check) -> void:
	for machine in WorldArena.MACHINES:
		var start := Vector2(machine.position.x - 100.0, machine.get_center().y)
		var stopped := WorldArena.move_body(start, Vector2(400.0, 0.0), 12.0)
		c.ok(stopped.x < machine.position.x - 12.0, "fast body stops before machine side")
		c.ok(WorldArena.body_clear(stopped, 12.0), "resolved body stays outside cover")
		var slide := WorldArena.move_body(stopped, Vector2(40.0, 30.0), 12.0)
		c.ok(slide.y > stopped.y, "body can slide along a machine")
		var inside := WorldArena.move_body(machine.get_center(), Vector2.ZERO, 12.0)
		c.ok(WorldArena.body_clear(inside, 12.0), "restored overlapping body resolves to free floor")
		c.ok(WorldArena.blocks_projectile(machine.get_center(), 1.0), "machine blocks projectile centers")
		c.ok(not WorldArena.blocks_projectile(machine.position - Vector2(30.0, 30.0), 1.0), "free floor does not block projectiles")
		c.ok(not machine.intersects(RecyclingDepot.QUIET_CENTER), "machines leave a clear central lane")
	var edge := WorldArena.move_body(WorldArena.BOUNDS.get_center(), Vector2(10000.0, -10000.0), 12.0)
	c.ok(WorldArena.body_clear(edge, 12.0), "extreme movement stays inside usable world")


func test_spawns_surround_current_view_and_avoid_cover(c: Check) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 241
	for focus in [WorldArena.BOUNDS.position + Vector2(16.0, 16.0),
		WorldArena.BOUNDS.get_center(), WorldArena.BOUNDS.end - Vector2(16.0, 16.0)]:
		var camera := WorldArena.camera_rect(focus)
		for index in 120:
			var spawn := WaveDirector.spawn_position(WorldArena.BOUNDS, focus, rng, 32.0)
			c.ok(WorldArena.body_clear(spawn, 32.0), "spawn clears cover and world boundary")
			c.ok(not camera.has_point(spawn), "spawn stays outside the current camera")
			c.ok(camera.grow(45.0).has_point(spawn), "spawn pressure stays close to current view")
			c.ok(spawn.distance_to(focus) >= WaveDirector.MIN_SPAWN_DISTANCE, "spawn keeps a safe player distance")


func test_offscreen_spawn_warning_is_visible_on_the_current_view_edge(c: Check) -> void:
	var sim := Sim.new(146)
	sim.start_run()
	var camera := WorldArena.camera_rect(sim.player.pos)
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"runner")
	spawn.pos = camera.end + Vector2(44.0, -100.0)
	spawn.delay = Sim.SPAWN_TELEGRAPH
	var warning := ArenaPainter.pending_indicator(sim, spawn)
	c.ok(bool(warning["visible"]), "offscreen materialization has an onscreen warning")
	c.ok(camera.grow(-19.0).has_point(warning["pos"]), "warning stays inside the clipped view")
	c.ok((spawn.pos - Vector2(warning["pos"])).normalized().dot(warning["direction"]) > 0.999,
		"edge warning points at the authoritative materialization position")
	c.eq(float(warning["progress"]), 0.0, "warning starts with the real materialization delay")
	spawn.delay *= 0.5
	c.near(float(ArenaPainter.pending_indicator(sim, spawn)["progress"]), 0.5, 0.0001,
		"visible countdown follows the actual spawn timer")


func test_distance_phase_survives_render_rates_pause_and_teleport(c: Check) -> void:
	var sim := Sim.new(145)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	for frame in 8:
		sim.player.pos += Vector2(5.0, 0.0)
		sim.wave_time += 1.0 / 60.0
		view._physics_process(1.0 / 60.0)
		for redraw in 4:
			view._process(1.0 / 240.0)
	c.near(float(view.motion_stats()["gait_phase"]), PI * 0.5, 0.0001, "forty traveled pixels advance one quarter of gait")
	var phase := float(view.motion_stats()["gait_phase"])
	view.set_paused(true)
	view._process(20.0)
	c.eq(float(view.motion_stats()["gait_phase"]), phase, "pause freezes distance phase")
	view.set_paused(false)
	sim.wave_time += 1.0 / 60.0
	view._physics_process(1.0 / 60.0)
	c.ok(not bool(view.motion_stats()["moving"]), "stationary physics step plants the feet")
	sim.player.pos += Vector2(400.0, 0.0)
	sim.wave_time += 1.0 / 60.0
	view._physics_process(1.0 / 60.0)
	c.eq(float(view.motion_stats()["gait_phase"]), 0.0, "teleport resets planted gait instead of racing through steps")
	view.free()
