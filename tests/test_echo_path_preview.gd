extends RefCounted

const CLIP := Rect2(40.0, 80.0, 1200.0, 600.0)


func _sim() -> Sim:
	var sim := Sim.new(321)
	sim.phase = Sim.Phase.WAVE
	sim.wear_rate_mult = 0.0
	sim.player.stats.values[Stats.ECHO_DURATION] = 120.0
	return sim


func _actor(sim: Sim, samples: PackedVector2Array, time: float = 0.0) -> EchoActor:
	var take := EchoTake.new()
	take.samples = samples
	sim.bank.add(take)
	var actor := EchoActor.new(take, sim.echoes.size())
	actor.t = time
	actor.pos = take.position_at(time)
	actor.rewinding = take.is_rewinding(time)
	sim.echoes.append(actor)
	return actor


func _straight() -> PackedVector2Array:
	var samples := PackedVector2Array()
	for index in 121:
		samples.append(Vector2(200.0 + float(index) * 4.0, 240.0))
	return samples


func _forecast_at(data: Dictionary, time: float) -> Vector2:
	var points: PackedVector2Array = data["centerline"]
	var times: PackedFloat64Array = data["times"]
	var breaks: PackedInt32Array = data["breaks"]
	for index in range(1, points.size()):
		if times[index] + 0.000001 < time:
			continue
		if breaks.has(index) and time < times[index] - 0.000001:
			return points[index - 1]
		return points[index - 1].lerp(points[index], clampf((time - times[index - 1]) /
				maxf(0.000001, times[index] - times[index - 1]), 0.0, 1.0))
	return points[points.size() - 1]


func test_future_starts_at_real_foot_and_ends_two_seconds_ahead(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(sim, _straight(), 0.2)
	var data := EchoPathPreview.snapshot(actor, sim, CLIP)
	var line: PackedVector2Array = data["centerline"]
	c.ok(data["valid"] and data["start_visible"], "a live copy has a visible route start")
	c.eq(data["start"], actor.pos, "the start is the authoritative foot, not the chest or oldest sample")
	c.eq(line[0], actor.pos, "the centerline begins at the current playback position")
	c.near(float(data["horizon"]), 2.0, 0.00001, "normal forecast covers two seconds")
	c.near(line[line.size() - 1].distance_to(actor.take.position_at(actor.t + 2.0)), 0.0, 0.002,
			"the end uses the actual future playback clock")
	for point in line:
		c.ok(point.x >= actor.pos.x - 0.001, "a forward forecast does not include the previous route")
	var colors: PackedColorArray = data["colors"]
	c.ok(not colors.is_empty(), "moving paper has a drawn dashed preview")
	c.eq((data["segments"] as PackedVector2Array).size(), colors.size() * 2, "every cut segment has one draw color")
	if colors.size() >= 2:
		c.ok(colors[colors.size() - 1].a < colors[0].a * 0.2, "the future end fades instead of becoming a second start")
	var selected := EchoPathPreview.snapshot(actor, sim, CLIP, true)
	c.ok(selected["width"] > data["width"], "selected route is wider without an extra command or mode")
	c.ok((selected["colors"] as PackedColorArray)[0].a > colors[0].a, "selected paper has stronger ink")
	c.eq(selected["centerline"], line, "selection never alters the predicted movement")


func test_short_ping_pong_route_keeps_corners_and_reversals(c: Check) -> void:
	var sim := _sim()
	var samples := PackedVector2Array([Vector2(200, 240), Vector2(240, 240), Vector2(240, 280)])
	var actor := _actor(sim, samples, EchoTake.SAMPLE_DT * 0.4)
	var data := EchoPathPreview.snapshot(actor, sim, CLIP)
	var line: PackedVector2Array = data["centerline"]
	var times: PackedFloat64Array = data["times"]
	c.near(float(data["horizon"]), 2.0, 0.00001, "a very short looping route still forecasts two real seconds")
	var corner_seen := false
	var cusp_seen := false
	for point in line:
		corner_seen = corner_seen or point.distance_to(samples[1]) < 0.003
		cusp_seen = cusp_seen or point.distance_to(samples[2]) < 0.003
	c.ok(corner_seen and cusp_seen, "recorded corner and ping-pong cusp remain on the centerline")
	for index in line.size():
		c.near(line[index].distance_to(actor.take.position_at(actor.t + times[index])), 0.0, 0.003,
				"each forecast vertex comes from the real ping-pong function")
	for index in range(1, line.size()):
		var middle := (times[index - 1] + times[index]) * 0.5
		c.near(line[index - 1].lerp(line[index], 0.5).distance_to(actor.take.position_at(actor.t + middle)),
				0.0, 0.01, "a drawn segment cannot cut diagonally across a recorded right-angle turn")
	var rewinding := _actor(sim, _straight(), 4.2)
	var reverse := EchoPathPreview.snapshot(rewinding, sim, CLIP)
	var reverse_line: PackedVector2Array = reverse["centerline"]
	c.ok(reverse_line[reverse_line.size() - 1].x < reverse_line[0].x,
			"an already rewinding copy forecasts its backward movement, not stale forward samples")


func test_conductor_hold_and_release_match_real_physics_order(c: Check) -> void:
	var sim := _sim()
	sim.character_id = &"conductor"
	var actor := _actor(sim, _straight(), 0.47)
	sim.role_effects = {"anchor_uid": actor.take.uid, "anchor_left": 0.243}
	var data := EchoPathPreview.snapshot(actor, sim, CLIP)
	var delta := Engine.time_scale / float(Engine.physics_ticks_per_second)
	var elapsed := 0.0
	for _tick in mini(120, ceili(2.0 / delta)):
		CharacterSkills.step(sim, delta)
		EchoSystem.step(sim, delta)
		elapsed += delta
		if elapsed <= 2.0 + 0.000001:
			c.near(_forecast_at(data, elapsed).distance_to(actor.pos), 0.0, 0.01,
					"forecast respects decrement-before-movement at the real anchor release tick")
	sim.role_effects["anchor_left"] = 4.0
	var held := EchoPathPreview.snapshot(actor, sim, CLIP)
	c.ok((held["segments"] as PackedVector2Array).is_empty(), "a hold lasting the horizon cannot invent a moving route")
	c.ok(held["start_visible"], "a fully held copy retains its stationary floor origin")


func test_mirror_snap_back_is_not_a_fake_walk_and_looper_recomputes(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(sim, _straight(), 0.2)
	actor.pos = Vector2(800, 600)
	sim.role_effects = {"anchor_uid": actor.take.uid, "anchor_left": 0.2}
	var held := EchoPathPreview.snapshot(actor, sim, CLIP)
	c.eq(held["start"], Vector2(800, 600), "swapped copy starts at the actual held foot")
	c.eq((held["breaks"] as PackedInt32Array).size(), 1, "the release snap is an explicit route discontinuity")
	for point: Vector2 in held["segments"]:
		c.near(point.y, 240.0, 0.001, "no cut-paper line bridges the teleport from the held foot")
	sim.role_effects.clear()
	sim.character_id = &"looper"
	actor.t = 3.0
	actor.pos = actor.take.position_at(actor.t)
	var before := EchoPathPreview.snapshot(actor, sim, CLIP)
	c.ok(CharacterSkills.activate(sim), "actual Looper rewind is available")
	var after := EchoPathPreview.snapshot(actor, sim, CLIP)
	c.eq(after["start"], actor.pos, "a skill-rewound route starts at its new actual position")
	c.ok(after["start"] != before["start"], "forecast does not cache a stale pre-rewind route")
	c.near(_forecast_at(after, 2.0).distance_to(actor.take.position_at(actor.t + 2.0)), 0.0, 0.01,
			"post-skill future movement uses the rewound take clock")


func test_camera_clip_and_crowded_eight_copy_budgets_are_bounded(c: Check) -> void:
	var sim := _sim()
	var samples := PackedVector2Array()
	for index in 500:
		samples.append(Vector2(200.0 + float(index % 8) * 80.0, 240.0 + float(index % 3) * 30.0))
	for _slot in 8:
		_actor(sim, samples, 0.01)
	var clip := Rect2(300, 200, 100, 150)
	var total := 0
	for index in sim.echoes.size():
		var actor := sim.echoes[index]
		var data := EchoPathPreview.snapshot(actor, sim, clip, index == 0)
		var segments: PackedVector2Array = data["segments"]
		var colors: PackedColorArray = data["colors"]
		c.ok(data["valid"], "every one of eight live copies receives a forecast")
		c.ok(not data["start_visible"], "an off-camera foot cannot put a marker in the HUD")
		c.ok((data["centerline"] as PackedVector2Array).size() <= EchoPathPreview.MAX_ROUTE_POINTS,
				"future sampling has a hard per-copy point budget")
		c.ok(colors.size() <= EchoPathPreview.MAX_DRAW_SEGMENTS, "paper geometry has a hard per-copy draw budget")
		c.eq(segments.size(), colors.size() * 2, "clipping cannot leave unmatched draw points")
		for point in segments:
			c.ok(clip.has_point(point), "all clipped future ink remains inside the world camera rectangle")
		for color in colors:
			c.ok(color.a <= (0.34 if index == 0 else 0.14), "eight overlapping routes stay below hazard ink contrast")
		total += colors.size()
	c.ok(total <= EchoPathPreview.MAX_ACTORS * EchoPathPreview.MAX_DRAW_SEGMENTS,
			"eight copies cannot grow an unbounded route carpet")


func test_stationary_empty_invalid_and_exhausting_routes_are_safe(c: Check) -> void:
	var sim := _sim()
	var stationary := _actor(sim, PackedVector2Array([Vector2(280, 240)]))
	var still := EchoPathPreview.snapshot(stationary, sim, CLIP)
	c.ok(still["valid"] and still["start_visible"], "one-point route still has its true stationary origin")
	c.ok((still["segments"] as PackedVector2Array).is_empty(), "stationary paper cannot invent a direction")
	var empty := _actor(sim, PackedVector2Array())
	c.ok(not EchoPathPreview.snapshot(empty, sim, CLIP)["valid"], "an empty recording has no invented forecast")
	c.ok(not EchoPathPreview.snapshot(null, sim, CLIP)["valid"], "missing actor has no forecast")
	c.ok(not EchoPathPreview.snapshot(stationary, null, CLIP)["valid"], "missing model cannot invent a forecast")
	for clip in [Rect2(), Rect2(0, 0, -20, 40), Rect2(Vector2(INF, 0), Vector2(80, 80))]:
		c.ok(not EchoPathPreview.snapshot(stationary, sim, clip)["valid"], "invalid camera rectangles reject drawing safely")
	stationary.t = NAN
	c.ok(not EchoPathPreview.snapshot(stationary, sim, CLIP)["valid"], "a non-finite route clock cannot submit geometry")
	var ending := _actor(sim, _straight())
	sim.wear_rate_mult = 1.0
	sim.player.stats.values[Stats.ECHO_DURATION] = 10.0
	ending.take.condition = 5.0
	var last := EchoPathPreview.snapshot(ending, sim, CLIP)
	c.near(float(last["horizon"]), 0.5, 0.00001, "preview stops at known passive exhaustion rather than promising two surviving seconds")
	ending.take.condition = 0.0
	c.ok(not EchoPathPreview.snapshot(ending, sim, CLIP)["valid"], "exhausted paper cannot leave a live route")
	sim.phase = Sim.Phase.SHOP
	c.ok(not EchoPathPreview.snapshot(ending, sim, CLIP)["valid"], "the shop cannot display a moving battle forecast")


func test_short_loop_revisits_cannot_saturate_the_same_floor(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(sim, PackedVector2Array([Vector2(200, 240), Vector2(260, 240)]), 0.01)
	var data := EchoPathPreview.snapshot(actor, sim, CLIP)
	var segments: PackedVector2Array = data["segments"]
	var colors: PackedColorArray = data["colors"]
	c.ok(not colors.is_empty(), "short repeated routes remain present with restrained ink")
	for x in [206.0, 218.0, 230.0, 242.0, 254.0]:
		var point := Vector2(x, 240.0)
		var summed_alpha := 0.0
		for index in colors.size():
			var from := segments[index * 2]
			var to := segments[index * 2 + 1]
			if Geometry2D.get_closest_point_to_segment(point, from, to).distance_to(point) < 0.001:
				summed_alpha += colors[index].a
		c.ok(summed_alpha <= 0.22, "dozens of coincident passes cannot exceed one ordinary route's opacity")
	if colors.size() > 1:
		c.ok(colors[colors.size() - 1].a < colors[0].a,
				"late repeat cuts keep their terminal fade instead of accumulating darker end ink")


func test_preview_is_static_in_reduced_mode_and_never_mutates_the_model(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(sim, _straight(), 0.7)
	sim.role_effects = {"anchor_uid": actor.take.uid, "anchor_left": 0.37}
	var state := {"rng": sim.rng.state, "hazard_rng": sim.hazard_rng.state, "time": actor.t,
		"pos": actor.pos, "condition": actor.take.condition, "samples": actor.take.samples.duplicate(),
		"effects": sim.role_effects.duplicate(true), "cursor": actor.work_cursor, "cycle": actor.work_cycle}
	var normal := EchoPathPreview.snapshot(actor, sim, CLIP, true, false)
	var reduced := EchoPathPreview.snapshot(actor, sim, CLIP, true, true)
	c.eq(normal, reduced, "reduced mode retains the same static future, clipping, cuts and selection")
	c.eq(reduced, EchoPathPreview.snapshot(actor, sim, CLIP, true, true), "paused or repeated draws cannot animate the route by wall time")
	c.eq(sim.rng.state, state["rng"], "paper cuts consume no gameplay RNG")
	c.eq(sim.hazard_rng.state, state["hazard_rng"], "preview cannot advance hazard randomness")
	c.eq(actor.t, state["time"], "forecasting cannot advance playback")
	c.eq(actor.pos, state["pos"], "forecasting cannot move the actual foot")
	c.eq(actor.take.condition, state["condition"], "forecasting cannot spend condition")
	c.eq(actor.take.samples, state["samples"], "source path samples remain untouched")
	c.eq(sim.role_effects, state["effects"], "forecasting cannot decrement the real hold")
	c.eq(actor.work_cursor, state["cursor"], "preview cannot replay key work")
	c.eq(actor.work_cycle, state["cycle"], "preview cannot consume a future work cycle")
