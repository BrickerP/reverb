extends RefCounted


func test_fixed_crop_preserves_world_coordinates_and_shake(c: Check) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.new_run(83, &"looper")
	var crop: Control = main._arena_clip
	c.eq(Rect2(crop.position, crop.size), Sim.ARENA, "battle crop equals authoritative arena")
	c.ok(crop.clip_contents, "crop clips descendant draw commands")
	c.eq(crop.mouse_filter, Control.MOUSE_FILTER_IGNORE, "crop cannot eat game or menu input")
	var origin: Node2D = main._view.get_parent()
	c.eq(origin.position, -Sim.ARENA.position, "neutral origin preserves world coordinates")
	c.eq(main._view.global_position, Vector2.ZERO, "unshaken view retains global origin")
	var bounds := crop.get_global_rect()
	main._view._shake = 1.0
	main._view._process(0.025)
	c.ok(main._view.position.length() > 0.0, "actual view shakes inside crop")
	c.eq(crop.get_global_rect(), bounds, "shake cannot move world drawing into HUD")
	main._view.set_paused(true)
	c.eq(main._view.position, Vector2.ZERO, "pause resets shake without changing origin")
	c.eq(crop.get_global_rect(), bounds, "pause keeps the same drawing boundary")
	main.show_select()
	c.eq(main._view.sim, null, "select detaches clipped world normally")
	main.free()


func test_player_edges_react_to_local_overlap_and_leave_danger_intact(c: Check) -> void:
	var sim := Sim.new(84)
	sim.start_run()
	sim.enemies.clear()
	var body := Rect2(sim.player.pos - Vector2(24.0, 44.0), Vector2(48.0, 58.0))
	var quiet := ArenaPainter.player_focus_profile(sim, body)
	c.ok(not quiet["visible"], "empty field has no extra player framing")
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"brute")
	enemy.pos = sim.player.pos
	enemy.radius = enemy.def.radius
	sim.enemies.append(enemy)
	var take := EchoTake.new()
	var actor := EchoActor.new(take, 0)
	actor.pos = sim.player.pos
	sim.echoes.append(actor)
	var rng := sim.rng.state
	var hp := sim.player.hp
	var pos := enemy.pos
	var crowded := ArenaPainter.player_focus_profile(sim, body)
	c.ok(crowded["visible"], "body overlap reveals paper edge separation")
	c.eq(crowded["nearby"], 2, "real overlapping enemy and copy both count")
	c.eq(crowded["contours"].size(), 2, "crowded focus stays two bounded side edges")
	for contour: PackedVector2Array in crowded["contours"]:
		c.eq(contour.size(), 5, "side edge has a fixed five-point budget")
		for point in contour:
			c.ok(body.grow(6.0).has_point(point), "focus hugs real body instead of distant threat")
	c.eq(sim.rng.state, rng, "focus does not consume simulation RNG")
	c.eq(sim.player.hp, hp, "focus leaves health unchanged")
	c.eq(enemy.pos, pos, "focus never repositions a harmful body")
	enemy.dead = true
	actor.pos += Vector2(400.0, 0.0)
	c.ok(not ArenaPainter.player_focus_profile(sim, body)["visible"], "dead or distant bodies do not trigger frame")
	sim.player.hp = 0.0
	c.ok(not ArenaPainter.player_focus_profile(sim, body)["visible"], "terminal paper remains unframed")
