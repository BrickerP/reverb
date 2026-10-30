extends RefCounted


func test_landmarks_stay_in_the_edge_band_and_leave_the_center_empty(c: Check) -> void:
	for key: StringName in RecyclingDepot.landmark_rects():
		var rect: Rect2 = RecyclingDepot.landmark_rects()[key]
		c.ok(Sim.ARENA.encloses(rect), "%s stays inside the visible battlefield" % key)
		c.ok(not rect.intersects(RecyclingDepot.QUIET_CENTER), "%s leaves the combat center empty" % key)
		var in_top := rect.end.y <= Sim.ARENA.position.y + RecyclingDepot.EDGE_DEPTH + 2.0
		var in_left := rect.end.x <= Sim.ARENA.position.x + RecyclingDepot.EDGE_DEPTH
		var in_right := rect.position.x >= Sim.ARENA.end.x - RecyclingDepot.EDGE_DEPTH - 4.0
		c.ok(in_top or in_left or in_right, "%s is shallow edge scenery, not a central obstacle" % key)
	c.ok(RecyclingDepot.QUIET_CENTER.size.x >= 860.0 and RecyclingDepot.QUIET_CENTER.size.y >= 320.0,
			"the central fighting area remains quiet negative space")


func test_motion_is_slow_bounded_and_reduced_is_static(c: Check) -> void:
	var moving := false
	var first := RecyclingDepot.motion_profile(0.0, false)
	for i in 120:
		var profile := RecyclingDepot.motion_profile(float(i) * 0.1, false)
		c.ok(float(profile["roller"]) >= 0.0 and float(profile["roller"]) < 10.0,
				"roller tick is bounded")
		c.ok(float(profile["feed"]) >= 0.0 and float(profile["feed"]) < 1.0,
				"paper feed stays inside the belt")
		c.ok(float(profile["press"]) >= 0.0 and float(profile["press"]) <= 1.0,
				"rubber press displacement is bounded")
		moving = moving or profile != first
		c.eq(RecyclingDepot.motion_profile(float(i), true), RecyclingDepot.motion_profile(0.0, true),
				"Reduced holds the exact static edge state")
	c.ok(moving, "normal scenery has restrained actual motion")
	c.eq(RecyclingDepot.motion_profile(-100.0, false), first, "negative clocks start safely at zero")


func test_pause_freezes_the_child_clock_and_rebind_is_not_needed(c: Check) -> void:
	var backdrop := ArenaBackdrop.new()
	backdrop.set_presentation(4.0, false, false)
	var depot: RecyclingDepot = backdrop._depot
	var tick := depot._draw_tick
	backdrop.set_presentation(99.0, false, true)
	c.eq(depot._visual_time, 4.0, "pause refuses incoming time changes")
	c.eq(depot._draw_tick, tick, "pause freezes the quantized redraw clock")
	backdrop.set_presentation(4.1, false, false)
	c.ok(depot._draw_tick > tick, "unpause can resume scenery motion")
	backdrop.set_presentation(4.1, true, false)
	c.eq(depot._draw_tick, 0, "Reduced settles to a static frame")
	c.eq(backdrop.get_child_count(), 1, "repeated updates reuse one scenery child")
	backdrop.free()


func test_presentation_updates_leave_the_simulation_and_rng_untouched(c: Check) -> void:
	var sim := Sim.new(20261029)
	sim.start_run()
	var before_rng := sim.rng.state
	var before_hazard_rng := sim.hazard_rng.state
	var before_pos := sim.player.pos
	var before_time := sim.wave_time
	var backdrop := ArenaBackdrop.new()
	for i in 25:
		backdrop.set_presentation(float(i) * 0.17, i > 12, i > 20)
		RecyclingDepot.motion_profile(float(i), i > 12)
	c.eq(sim.rng.state, before_rng, "depot does not consume simulation RNG")
	c.eq(sim.hazard_rng.state, before_hazard_rng, "depot does not consume hazard RNG")
	c.eq(sim.player.pos, before_pos, "depot does not move real bodies")
	c.eq(sim.wave_time, before_time, "depot does not advance gameplay time")
	backdrop.free()


func test_live_notice_text_is_localized_and_fits(c: Check) -> void:
	var before := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		var keys: Array[String] = ["world.scrap", "world.notice_small", "world.machine.stopped",
			"world.machine.operating", "world.machine.fault", "world.machine.repaired", "world.safe_registry"]
		for act in [1, 2, 3]:
			keys.append("world.act.%d" % act)
			keys.append(RecyclingDepot.SHIFT_SIGN_KEYS[act - 1])
		for key in keys:
			var text := Loc.t(key)
			c.ok(text != key and not text.is_empty(), "%s has %s live copy" % [key, language])
		for act in [1, 2, 3]:
			for key in ["world.act.%d" % act, RecyclingDepot.SHIFT_SIGN_KEYS[act - 1]]:
				var text := Loc.t(key)
				var width := RecyclingDepot.notice_text_rect().size.x
				var size := RecyclingDepot.fitted_font_size(text, width, 16)
				c.ok(UiTheme.title_font(text).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= width,
						"%s %s fits its live paper area" % [language, key])
	Loc.lang = before


func test_atlas_has_the_three_measured_static_regions(c: Check) -> void:
	var atlas := RecyclingDepot.atlas_texture()
	c.ok(atlas != null, "depot production atlas loads")
	for source in [RecyclingDepot.CONVEYOR_SOURCE, RecyclingDepot.WORKSTATION_SOURCE, RecyclingDepot.NOTICE_SOURCE]:
		c.ok(Rect2(Vector2.ZERO, RecyclingDepot.ATLAS_SOURCE_SIZE).encloses(source),
				"measured prop crop remains in the authored image")
		c.ok(source.has_area(), "each prop source is nonempty")
