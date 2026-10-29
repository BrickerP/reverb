extends RefCounted


func _sim(lifetime: int = 3) -> Sim:
	var sim := Sim.new(73)
	sim.start_run()
	sim.player.stats.values[Stats.ECHO_LIFESPAN] = float(lifetime)
	return sim


func _actor(age: int = 0, slot: int = 0, merged: bool = false) -> EchoActor:
	var take := EchoTake.new()
	take.age = age
	take.merged = merged
	take.tint_index = slot
	take.samples = PackedVector2Array([Vector2(280.0, 240.0), Vector2(320.0, 240.0)])
	return EchoActor.new(take, slot)


func test_wear_uses_current_effective_lifetime_and_reaches_expiry(c: Check) -> void:
	var sim := _sim()
	var actor := _actor()
	var fresh := EchoInk.profile(actor, sim)
	c.eq(fresh["remaining"], 3, "new recording has all of its effective waves")
	c.eq(fresh["crease_count"], 0, "fresh paper is not already creased")
	c.ok(not fresh["expiring"] and fresh["visible"], "fresh copy is visibly live")
	actor.take.age = 1
	var middle := EchoInk.profile(actor, sim)
	c.near(middle["age_ratio"], 0.5, 0.001, "wear normalizes age against the last playable age")
	c.ok(middle["crease_count"] > fresh["crease_count"], "one old wave changes actual paper marks")
	actor.take.age = 2
	var last := EchoInk.profile(actor, sim)
	c.eq(last["remaining"], 1, "last-wave warning comes from the true remaining life")
	c.ok(last["expiring"] and last["tear_count"] > 0, "last-wave copy has torn-edge treatment")
	c.ok(last["alpha"] < fresh["alpha"] and last["alpha"] > 0.5,
			"old copies fade without disappearing among other actors")
	c.ok((last["paper_scale"] as Vector2).y < (fresh["paper_scale"] as Vector2).y,
			"old paper visibly compresses rather than changing only its color")
	actor.take.age = 3
	var expired := EchoInk.profile(actor, sim)
	c.ok(expired["expired"] and not expired["visible"], "stale actor cannot pretend to retain a wave")
	c.eq(expired["alpha"], 0.0, "expired paper cannot keep a visible firing silhouette")
	# Echo lifespan is a current player rule, not the take's historical snapshot.
	sim.player.stats.values[Stats.ECHO_LIFESPAN] = 11.0
	actor.take.age = 5
	actor.take.stats.values[Stats.ECHO_LIFESPAN] = 3.0
	var extended := EchoInk.profile(actor, sim)
	c.eq(extended["lifespan"], 11, "boons and current life upgrades drive the visible rule")
	c.eq(extended["remaining"], 6, "long-lived recordings are not falsely stamped expired")
	c.eq(extended["state_priority"], &"worn", "long-lived copies retain the worn state instead of a false final-wave warning")


func test_merge_silence_rewind_and_expiry_can_be_read_together(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(2, 3)
	# The real overdub flag, never weapon count or path length, chooses the staple.
	actor.take.weapons = [Content.weapon(&"pistol"), Content.weapon(&"pistol")]
	var ordinary := EchoInk.profile(actor, sim)
	c.eq(ordinary["staple_count"], 0, "two weapons do not invent an overdub")
	actor.take.merged = true
	actor.rewinding = true
	sim.echo_silenced = 2.0
	var marked := EchoInk.profile(actor, sim)
	var geometry := EchoInk.mark_geometry(Rect2(100.0, 140.0, 52.0, 60.0), marked)
	c.eq(marked["staple_count"], 1, "actual overdub produces one physical binding")
	c.ok(marked["muted"] and marked["rewinding"] and marked["expiring"],
			"simultaneous states are not hidden by an else-if chain")
	c.eq(marked["state_priority"], &"muted", "silence leads the state hierarchy without removing other physical marks")
	c.eq(geometry["staples"].size(), 1, "a merged copy has an actual drawn staple")
	c.eq(geometry["punctures"].size(), 2, "binding has two physical holes")
	c.ok(not geometry["mute"].is_empty(), "silence remains a sealed mark on front or back")
	c.eq(geometry["rewind"].size(), 2, "reverse playback retains its double chevron")
	c.ok(not geometry["expiry"].is_empty(), "last-wave seam still exists while silenced")
	c.ok(marked["alpha"] >= 0.5, "silence does not make the copy unreadably transparent")


func test_eight_copies_keep_distinct_non_color_slot_marks_with_bounded_detail(c: Check) -> void:
	var sim := _sim(9999)
	for slot in 8:
		sim.echoes.append(_actor(9998, slot, slot % 2 == 0))
	var signatures: Array[String] = []
	for actor in sim.echoes:
		var profile := EchoInk.profile(actor, sim)
		var geometry := EchoInk.mark_geometry(Rect2(200.0, 230.0, 50.0, 58.0), profile)
		c.ok(profile["crowded"], "eight-copy mode applies the visible detail budget")
		c.ok(geometry["creases"].size() <= 2 and geometry["tears"].size() <= 1,
				"crowding limits ink work without dropping state marks")
		c.eq(geometry["identity"].size(), 3, "lifespan cannot add tiny floating marks to crowded bodies")
		var signature := ""
		for mark: Dictionary in geometry["identity"]:
			signature += "1" if mark["punched"] else "0"
		c.ok(not signatures.has(signature), "slot identity survives grayscale rendering")
		signatures.append(signature)
	c.eq(signatures.size(), 8, "all eight slots have a distinct physical punch pattern")


func test_marks_stay_in_the_body_and_small_or_invalid_bounds_are_safe(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(2, 1, true)
	actor.rewinding = true
	sim.echo_silenced = 1.0
	var profile := EchoInk.profile(actor, sim)
	var bounds := Rect2(430.0, 260.0, 45.0, 62.0)
	var geometry := EchoInk.mark_geometry(bounds, profile)
	for name in ["creases", "tears", "staples", "mute", "rewind"]:
		for line: PackedVector2Array in geometry[name]:
			for point in line:
				c.ok(bounds.encloses(Rect2(point - Vector2(0.001, 0.001), Vector2(0.002, 0.002))),
						"paper surface marks never escape the actual fitted sprite crop")
	for name in ["expiry", "mute_contour"]:
		for point: Vector2 in geometry[name]:
			c.ok(bounds.has_point(point), "important state contours remain attached to the actual paper body")
	for bad in [Rect2(), Rect2(0, 0, -1, 20), Rect2(0, 0, 1, 20), Rect2(Vector2(INF, 0), Vector2(50, 50))]:
		var empty := EchoInk.mark_geometry(bad, profile)
		c.ok(empty["creases"].is_empty() and empty["expiry"].is_empty() and empty["mute_contour"].is_empty(),
				"missing, tiny and non-finite art never submit invalid draw geometry")
	c.ok(not EchoInk.profile(null, sim)["valid"], "missing actor cannot produce invented marks")
	c.ok(not EchoInk.profile(actor, null)["valid"], "missing simulation cannot invent a lifespan")
	actor.take.age = -4
	c.eq(EchoInk.profile(actor, sim)["age"], 0, "invalid negative age is only clamped in presentation")
	c.eq(actor.take.age, -4, "presentation does not repair or mutate simulation data")


func test_reduced_and_paused_clocks_keep_rules_and_do_not_consume_rng(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(2, 0, true)
	actor.rewinding = true
	sim.echo_silenced = 2.0
	var state: int = sim.rng.state
	var old_t := actor.t
	var old_age := actor.take.age
	var a := EchoInk.profile(actor, sim, 0.0, true)
	var b := EchoInk.profile(actor, sim, 120.0, true)
	var bounds := Rect2(150.0, 160.0, 48.0, 58.0)
	c.eq(EchoInk.mark_geometry(bounds, a), EchoInk.mark_geometry(bounds, b),
			"reduced ink has no clock-driven flashing or moving safety signs")
	for field in ["remaining", "merged", "muted", "rewinding", "expiring", "identity_pattern", "state_priority", "body_tint", "paper_scale"]:
		c.eq(a[field], EchoInk.profile(actor, sim, 2.0, false)[field],
				"reduced effects keep every gameplay identity and state")
	c.eq(sim.rng.state, state, "paper wear never consumes gameplay randomness")
	c.eq(actor.t, old_t, "drawing profile cannot advance playback time")
	c.eq(actor.take.age, old_age, "drawing profile cannot spend remaining life")


func _extent(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func test_critical_states_have_body_scale_shapes_at_native_battlefield_size(c: Check) -> void:
	var sim := _sim(3)
	var actor := _actor(2, 0, true)
	sim.echo_silenced = 1.0
	var data := EchoInk.profile(actor, sim)
	# Approximate original-screen paper dimensions, not an enlarged art-board crop.
	var body := Rect2(320.0, 240.0, 40.0, 52.0)
	var geometry := EchoInk.mark_geometry(body, data)
	var binding := _extent(geometry["staples"][0])
	var silence := _extent(geometry["mute_contour"])
	var expiry := _extent(geometry["expiry"])
	c.ok(binding.size.x >= 27.0 and binding.size.y >= 10.0,
			"the binding occupies most of a real-size copy rather than a tiny head detail")
	c.ok(silence.size.x >= 30.0 and silence.size.y >= 14.0,
			"silence has a closed body-scale contour at 1280x720")
	c.eq(geometry["mute"].size(), 2, "a broad crossed seal also identifies silence without color")
	c.ok(expiry.size.x >= 32.0 and expiry.size.y >= 8.0,
			"the final-wave jagged tear spans the body with visibly deep teeth")
	sim.echo_silenced = 0.0
	var fresh := EchoInk.profile(_actor(0), sim)
	var final_wave := EchoInk.profile(actor, sim)
	var fresh_value := _luminance(fresh["body_tint"])
	c.ok(fresh_value - _luminance(final_wave["body_tint"]) >= 0.12,
			"final-wave paper changes whole-body value without depending on its tint")
	c.ok(fresh_value - _luminance(data["body_tint"]) >= 0.25,
			"silence visibly darkens the entire copy instead of making it transparent")
	c.ok((final_wave["paper_scale"] as Vector2).y <= 0.86,
			"final-wave paper has a distinct compressed silhouette")
	c.ok(data["alpha"] <= 0.80 and fresh["alpha"] <= 0.80,
			"state treatment never promotes a copy to the opaque player's visual weight")


func test_final_wave_threshold_and_state_precedence_remain_independent(c: Check) -> void:
	var sim := _sim(12)
	var actor := _actor(10, 0, true)
	var before := EchoInk.profile(actor, sim)
	c.eq(before["remaining"], 2, "one wave before the boundary still has two playable waves")
	c.ok(not before["expiring"], "an old copy is not marked final merely by being the oldest slot")
	c.eq(before["state_priority"], &"merged", "binding is the leading state before the final-wave threshold")
	actor.take.age = 11
	var last := EchoInk.profile(actor, sim)
	c.eq(last["state_priority"], &"expiring", "the true final wave outranks merged state")
	c.ok(last["merged"], "final-wave priority does not discard the physical binding")
	sim.echo_silenced = 0.01
	var silenced := EchoInk.profile(actor, sim)
	c.eq(silenced["state_priority"], &"muted", "any real active silence leads the visible hierarchy")
	c.ok(silenced["expiring"] and silenced["merged"], "silence keeps final-wave and merged marks")
	sim.echo_silenced = 0.0
	c.eq(EchoInk.profile(actor, sim)["state_priority"], &"expiring", "ending silence restores final-wave priority immediately")
	actor.take.age = 12
	var gone := EchoInk.profile(actor, sim)
	c.eq(gone["state_priority"], &"expired", "expiry removes even a bound or silenced body")
	c.ok(not gone["visible"], "expired copies cannot leave state marks that look like a live threat")
	var empty := EchoInk.mark_geometry(Rect2(0, 0, 40, 52), gone)
	c.ok(empty["staples"].is_empty() and empty["expiry"].is_empty(), "an expired binding is not drawn alone")
	sim.player.stats.values[Stats.ECHO_LIFESPAN] = 0.0
	actor.take.age = 0
	var shortest := EchoInk.profile(actor, sim)
	c.eq(shortest["lifespan"], 1, "the model's minimum effective lifespan is respected")
	c.ok(shortest["expiring"] and shortest["visible"], "one-wave life is final and visible from its first wave")
