extends RefCounted


func test_floating_hud_regions_fit_small_and_tall_keep_aspect_windows(c: Check) -> void:
	var sim := Sim.new(31)
	sim.start_run()
	var hud := Hud.new()
	hud.bind(sim)
	for wave: int in [1, 20]:
		sim.wave = wave
		var regions := hud.layout_regions()
		var health: Rect2 = regions["health"]
		var wave_tag: Rect2 = regions["wave"]
		var materials: Rect2 = regions["materials"]
		c.ok(health.end.x < wave_tag.position.x and wave_tag.end.x < materials.position.x,
				"health scroll, wave tag and material bag leave calm gaps at wave %d" % wave)
		for window: Vector2 in [Vector2(960.0, 540.0), Vector2(1280.0, 720.0), Vector2(1280.0, 800.0)]:
			var scale := minf(window.x / 1280.0, window.y / 720.0)
			var offset := (window - Vector2(1280.0, 720.0) * scale) * 0.5
			var screen := Rect2(Vector2.ZERO, window)
			for region: Rect2 in regions.values():
				var projected := Rect2(offset + region.position * scale, region.size * scale)
				c.ok(screen.encloses(projected), "floating pieces remain inside the actual keep-aspect content area")
		var weapon_area: Rect2 = regions["weapons"]
		for i in Content.MAX_WEAPON_SLOTS:
			c.ok(weapon_area.encloses(hud.weapon_slot_rect(i)), "individual weapon scraps fit the bottom safe band")
	hud.free()


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
