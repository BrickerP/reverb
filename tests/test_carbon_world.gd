extends RefCounted


func test_walk_uses_drawn_poses_and_returns_to_idle(c: Check) -> void:
	var key: StringName = &"character_looper_front"
	c.ok(PresentationAssets.frame_count(key) >= 3, "paper protagonist has distinct drawn walk poses")
	var seen: Array[int] = []
	for i in 8:
		var frame := ArenaPainter.actor_frame(key, float(i) * TAU / 8.0, true)
		c.ok(frame >= 0 and frame < PresentationAssets.frame_count(key), "walk pose stays in its atlas")
		if not seen.has(frame):
			seen.append(frame)
	c.ok(seen.size() >= 3, "walking changes the actual source frame, not just the transform")
	c.eq(ArenaPainter.actor_frame(key, 100.0, false), 0, "stopping restores the neutral pose")
	c.eq(ArenaPainter.actor_frame(key, -1.0, true), 0, "negative gait phase starts at neutral")
	c.eq(ArenaPainter.actor_frame(&"weapon_pistol", 2.0, true, true), 0,
			"single-frame equipment never reads beyond its source")


func test_reduced_walk_keeps_the_same_distance_contacts(c: Check) -> void:
	var key: StringName = &"character_looper_front"
	c.eq(ArenaPainter.actor_frame(key, PI * 0.25, true, false, true), 0,
			"reduced motion uses the planted quarter-cycle pose")
	c.ok(ArenaPainter.actor_frame(key, PI * 0.5, true, false, true) > 0,
			"reduced motion preserves the same physical contact phase")
	c.eq(ArenaPainter.actor_frame(key, 0.0, false, true, true),
			mini(3, PresentationAssets.frame_count(key) - 1), "hurt pose remains visible with reduced effects")


func _take() -> EchoTake:
	var take := EchoTake.new()
	for i in 120:
		take.samples.append(Vector2(float(i) * 2.0, 200.0))
	return take


func test_echo_route_is_a_bounded_playback_neighbourhood(c: Check) -> void:
	var actor := EchoActor.new(_take(), 0)
	actor.t = 2.0
	var points := PackedVector2Array()
	for i in 40:
		points.append(Vector2(float(i) * 6.0, 200.0))
	var shown := ArenaPainter.echo_path_window(actor, points)
	c.ok(shown.size() > 1 and shown.size() <= ArenaPainter.MAX_PATH_POINTS,
			"long recordings cannot cover the whole arena with route lines")
	c.ok(shown[shown.size() - 1].distance_to(actor.take.position_at(actor.t)) < 16.0,
			"the visible route remains close to the current playback head")
	actor.t = actor.take.duration() + 1.0
	shown = ArenaPainter.echo_path_window(actor, points)
	c.ok(shown[shown.size() - 1].distance_to(actor.take.position_at(actor.t)) < 16.0,
			"rewind uses reflected playback time, not ever-increasing run time")
	c.eq(ArenaPainter.echo_path_window(actor, PackedVector2Array()).size(), 0,
			"an empty recording has no unsafe line lookup")
	c.eq(ArenaPainter.echo_path_window(actor, PackedVector2Array([Vector2.ZERO])).size(), 0,
			"a single point cannot form a line")


func test_pause_freezes_art_clocks_and_keeps_simulation_untouched(c: Check) -> void:
	var sim := Sim.new(20261028)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	view._process(0.15)
	var before := view.motion_stats()
	var rng_state := sim.rng.state
	var wave_time := sim.wave_time
	var player_pos := sim.player.pos
	view.set_paused(true)
	view._process(3.0)
	c.eq(view.motion_stats()["visual_time"], before["visual_time"], "pause freezes source-frame clock")
	c.eq(view.position, WorldArena.camera_offset(sim.player.pos), "pause removes shake while preserving world framing")
	c.eq(sim.rng.state, rng_state, "art animation never consumes simulation randomness")
	c.eq(sim.wave_time, wave_time, "view animation never advances gameplay time")
	c.eq(sim.player.pos, player_pos, "art animation never moves the collision body")
	var hud := Hud.new()
	hud.bind(sim)
	hud._process(0.15)
	var hud_time := hud._visual_time
	hud.paused = true
	hud._process(3.0)
	c.eq(hud._visual_time, hud_time, "HUD warning and ink pulse clocks pause with gameplay")
	hud.set_reduced_effects(true)
	c.ok(hud.reduced_effects, "HUD accepts the same reduced-effect setting as the world")
	hud.free()
	view.free()


func test_retirement_has_bounded_identity_fragments_and_expires(c: Check) -> void:
	var sim := Sim.new(42)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var info := EchoRetirementInfo.new()
	info.uid = 7
	info.actor_token = 7
	info.kind = &"pin"
	info.pos = sim.player.pos
	view.react_retirement(info)
	c.eq(view.event_last_data()["skill"], &"pin", "retirement carries the actual weapon-derived skill")
	c.eq(view.event_last_data()["actor_token"], 7, "retirement keeps stable take identity")
	c.eq(view._sparks.size(), 9, "active retirement has a bounded paper fragment budget")
	view._process(1.0)
	c.eq(view._sparks.size(), 0, "retirement fragments expire")
	view.free()


func test_boss_halves_select_distinct_authored_source_frames(c: Check) -> void:
	var key: StringName = &"enemy_paradox"
	var left := ArenaPainter.boss_art_profile(2, 0, 1.0)
	var right := ArenaPainter.boss_art_profile(2, 1, 1.0)
	c.eq(left["frame"], 2, "first shard reads the actual left torn half")
	c.eq(right["frame"], 3, "second shard reads the actual right torn half")
	var left_region := PresentationAssets.frame_region(key, int(left["frame"]))
	var right_region := PresentationAssets.frame_region(key, int(right["frame"]))
	c.ok(left_region.has_area() and right_region.has_area(), "both torn-half regions have source art")
	c.ok(left_region != right_region, "phase two reads distinct image cells, not a mirrored duplicate")
	c.ok(not bool(left["flip"]) and not bool(right["flip"]),
			"authored inner tear edges keep their own facing")
	for clock in [0.0, 0.5, 10.0]:
		var whole := ArenaPainter.boss_art_profile(1, -1, clock)
		c.ok(int(whole["frame"]) < 2, "phase one never exposes a torn-half walk frame")


func test_boss_art_unknown_shard_and_reduced_effects_are_safe(c: Check) -> void:
	var sim := Sim.new(73)
	sim.start_run()
	var rng_state := sim.rng.state
	var wave_time := sim.wave_time
	var position := sim.player.pos
	var unknown := ArenaPainter.boss_art_profile(2, -1, 10.0)
	c.eq(unknown["frame"], 2, "unknown shard safely uses the first half")
	c.eq(ArenaPainter.boss_art_profile(2, 1, 100.0, true)["frame"], 3,
			"reduced effects preserve the right-half identity")
	c.eq(ArenaPainter.boss_art_profile(1, -1, 100.0, true)["frame"], 0,
			"reduced phase-one animation rests on the complete original")
	c.eq(ArenaPainter.boss_art_profile(1, -1, -1.0)["frame"], 0,
			"negative art clock cannot underflow source cells")
	c.eq(sim.rng.state, rng_state, "boss art selection consumes no simulation RNG")
	c.eq(sim.wave_time, wave_time, "boss art selection does not advance gameplay time")
	c.eq(sim.player.pos, position, "boss art selection leaves collision position alone")


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722


func test_retirement_selection_has_opaque_contrast_in_both_languages(c: Check) -> void:
	var hud := Hud.new()
	var old_lang := Loc.lang
	for lang: String in ["en", "zh"]:
		Loc.lang = lang
		var profile := hud.retirement_hint_profile()
		var foreground: Color = profile["foreground"]
		var background: Color = profile["background"]
		var light := maxf(_luminance(foreground), _luminance(background))
		var dark := minf(_luminance(foreground), _luminance(background))
		c.ok((light + 0.05) / (dark + 0.05) >= 7.0,
				"%s selected copy label exceeds readable contrast on its actual drawing stock" % lang)
		c.eq(background.a, 1.0, "%s hint does not inherit the dark floor through transparency" % lang)
		var rect: Rect2 = profile["rect"]
		c.ok(rect.end.x < WorldArena.VIEWPORT.end.x and rect.end.y <= WorldArena.VIEWPORT.end.y,
				"%s full key and translated caption remain in the existing bottom hint band" % lang)
		c.ok(rect.position.y >= 590.0 and rect.size.y <= 88.0,
				"%s selection and predicted skill stay inside the lower fighting-safe band" % lang)
	Loc.lang = old_lang
	hud.free()


func test_retirement_preserves_identity_tint_and_exhaustion_is_quiet(c: Check) -> void:
	var sim := Sim.new(91)
	sim.start_run()
	var source_color := Color(0.2, 0.95, 1.0)
	for exhausted in [false, true]:
		for reduced in [false, true]:
			var view := ArenaView.new()
			view.bind(sim)
			view.set_reduced_effects(reduced)
			var info := EchoRetirementInfo.new()
			info.pos = sim.player.pos
			info.tint = source_color
			info.exhausted = exhausted
			view.react_retirement(info)
			c.eq(view.event_last_data()["source_tint"], source_color, "retirement retains its original copy color")
			c.eq(info.tint, source_color, "presentation leaves the authoritative event unchanged")
			c.eq(view._sparks.size(), 3 if exhausted or reduced else 9, "exhaustion and Reduced use quiet fragment budgets")
			for spark in view._sparks:
				c.ok(spark.color in [ArenaPainter.PAPER, source_color], "paper fragments preserve copy identity")
			view.free()


func test_fading_hit_star_skips_the_exact_large_coordinate_triangulation_failure(c: Check) -> void:
	# This actual arena coordinate/radius/angle failed Godot's triangulator before the fix.
	var center := Vector2(500.0, 300.0)
	var radius := 0.1041
	var rotation := 0.052
	var old_points := PackedVector2Array()
	for i in 10:
		var length := radius if i % 2 == 0 else radius * 0.4
		old_points.append(center + Vector2.from_angle(rotation + TAU * float(i) / 10.0) * length)
	c.eq(Geometry2D.triangulate_polygon(old_points).size(), 0,
			"original absolute-coordinate subpixel hit reproduces the renderer triangulation failure")
	c.eq(ArenaPainter.ink_burst_points(radius).size(), 0,
			"expired subpixel hit never supplies an invalid polygon to the renderer")
	# A null canvas is intentional: invalid/invisible cases must return before drawing anything.
	for invalid: float in [-1.0, 0.0, 0.000001, radius, INF, NAN]:
		ArenaPainter._ink_burst(null, center, invalid, Color.WHITE, rotation)
	ArenaPainter._ink_burst(null, center, 6.0, Color(1.0, 1.0, 1.0, 0.0), rotation)
	c.ok(true, "negative, zero, subpixel, nonfinite and invisible hits do not submit canvas operations")


func test_visible_hit_stars_triangulate_locally_before_large_position_transforms(c: Check) -> void:
	for radius: float in [0.75, 1.0, 6.0, 10.0, 180.0]:
		var points := ArenaPainter.ink_burst_points(radius)
		var triangles := Geometry2D.triangulate_polygon(points)
		c.eq(triangles.size(), 24, "visible concave ink star triangulates into eight valid triangles")
		var bounded := true
		for point: Vector2 in points:
			if not point.is_finite() or point.length() > radius * 1.001:
				bounded = false
		c.ok(bounded, "triangulator receives stable origin-local vertices instead of absolute arena positions")
		# Placement happens after triangulation, so a far world origin cannot poison its area test.
		var placed := Transform2D(0.052, Vector2(1000000.0, 1000000.0)) * points
		c.eq(placed.size(), points.size(), "large-coordinate draw transform preserves the validated source mesh")
