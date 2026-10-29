extends RefCounted


func test_floating_hud_regions_fit_native_small_and_tall_windows(c: Check) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	for extent: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1280, 800)]:
		var viewport := SubViewport.new()
		viewport.size = extent
		root.add_child(viewport)
		var sim := Sim.new(31)
		sim.start_run()
		var take := EchoTake.new()
		take.weapons.append(Content.weapon(Content.STARTER_WEAPON))
		take.levels.append(0)
		take.samples = PackedVector2Array([Vector2(400, 300), Vector2(500, 350)])
		sim.bank.add(take)
		var hud := Hud.new()
		viewport.add_child(hud)
		for wave in [1, 4, 12]:
			sim.start_wave(wave)
			hud.bind(sim)
			var before := RunSnapshot.capture(sim)
			var regions := hud.layout_regions()
			var screen := Rect2(Vector2.ZERO, Vector2(extent))
			c.eq(hud.canvas_size(), Vector2(extent), "HUD uses the native logical canvas without projection")
			for region: Rect2 in regions.values():
				c.ok(screen.encloses(region), "every authored HUD region stays within native pixels")
			var health: Rect2 = regions.health
			var wave_tag: Rect2 = regions.wave
			var materials: Rect2 = regions.materials
			c.ok(health.end.x < wave_tag.position.x and wave_tag.end.x < materials.position.x, "health, objective/boss and material regions remain separated")
			var weapon_area: Rect2 = regions.weapons
			for index in Content.MAX_WEAPON_SLOTS:
				c.ok(weapon_area.encloses(hud.weapon_slot_rect(index)), "all six weapon scraps fit their native bottom row")
			var arena := WorldArena.display_viewport(Vector2(extent))
			c.ok(weapon_area.position.y >= arena.end.y and (regions.ability as Rect2).position.y >= arena.end.y, "weapon and ability pieces stay below the actual arena crop")
			if hud.is_compact():
				c.ok((regions.echo_hint as Rect2).position.y > weapon_area.end.y, "compact selected Echo occupies the second bottom row")
				c.ok(not (regions.echo_hint as Rect2).intersects(regions.interaction), "compact world interaction remains visible beside selected Echo")
			c.eq(RunSnapshot.capture(sim), before, "native HUD layout leaves full simulation and both RNGs untouched")
		viewport.free()


func test_low_health_face_wakes_only_for_damage_and_reduced_mode_stays_still(c: Check) -> void:
	var sim := Sim.new(33)
	sim.start_run()
	var hud := Hud.new()
	hud.bind(sim)
	var rng_state := sim.rng.state
	sim.player.hp = sim.player.max_hp() * 0.2
	hud._process(0.05)
	c.ok(hud._critical_poke > 0.0, "actual critical-health damage briefly pokes the sleepy face awake")
	hud._process(0.5)
	c.eq(hud._critical_poke, 0.0, "steady low health does not create permanent shaking")
	hud.set_reduced_effects(true)
	sim.player.hp *= 0.5
	hud._process(0.05)
	c.eq(hud._critical_poke, 0.0, "reduced effects preserve low-health information without moving the face")
	var clock := hud._visual_time
	hud.paused = true
	hud._process(3.0)
	c.eq(hud._visual_time, clock, "organic HUD still freezes its art clock on pause")
	c.eq(sim.rng.state, rng_state, "expressive HUD feedback consumes no simulation randomness")
	hud.free()


func test_material_bag_distinguishes_empty_collection_and_rest(c: Check) -> void:
	var sim := Sim.new(35)
	sim.start_run()
	sim.player.materials = 0
	var hud := Hud.new()
	hud.bind(sim)
	c.eq(hud.material_expression(), &"empty", "zero materials are an empty bag, never a negative or celebratory counter")
	sim.player.materials = 12
	hud._process(0.05)
	c.eq(hud.material_expression(), &"collected", "gaining materials briefly changes the bag expression")
	hud._process(1.0)
	c.eq(hud.material_expression(), &"rest", "collection expression settles without an endless bounce")
	sim.player.materials = 0
	hud._process(0.05)
	c.eq(hud.material_expression(), &"empty", "spending the last material restores the empty expression")
	hud.free()


func test_curved_meter_retains_exact_empty_full_and_partial_values(c: Check) -> void:
	var hud := Hud.new()
	var points := hud._meter_path(&"test_health", Rect2(72.0, 15.0, 265.0, 19.0))
	c.eq(Hud.meter_prefix(points, 0.0).size(), 0, "empty health meter submits no positive fill")
	c.eq(Hud.meter_prefix(points, -1.0).size(), 0, "negative health cannot underflow the curved stroke")
	c.eq(Hud.meter_prefix(points, NAN).size(), 0, "invalid meter data cannot submit nonfinite stroke geometry")
	c.eq(Hud.meter_prefix(points, 1.0), points, "full health covers the entire authored stroke")
	var half := Hud.meter_prefix(points, 0.5)
	c.near(half[half.size() - 1].x, 72.0 + 265.0 * 0.5, 0.001,
			"organic shape still communicates the exact health fraction")
	c.eq(hud._meter_paths.size(), 1, "reusing a meter keeps one cached hand-ink path")
	hud.free()


func test_small_weapon_scraps_share_cached_styles_and_keep_valid_soft_silhouettes(c: Check) -> void:
	var hud := Hud.new()
	var stock := hud._stock(&"test_weapon", ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, 3)
	c.eq(hud._stock(&"test_weapon", ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, 3), stock,
			"a drawn weapon scrap reuses its StyleBox resource between frames")
	for cell: Vector2 in [Vector2(Hud.SLOT_W, Hud.SLOT_H), Vector2(Hud.SLOT_W, Hud.SLOT_H) * 0.75]:
		var outline := stock.outline(Rect2(Vector2.ZERO, cell))
		c.ok(not Geometry2D.triangulate_polygon(outline).is_empty(),
				"even a small-window weapon scrap has a drawable soft closed silhouette")
	c.eq(hud._ink_stocks.size(), 1, "repeat drawing does not allocate a growing set of skin resources")
	hud.free()
