extends RefCounted


func _sim(duration: float = 120.0) -> Sim:
	var sim := Sim.new(73)
	sim.start_run()
	sim.player.stats.values[Stats.ECHO_DURATION] = duration
	return sim


func _actor(condition: float = 100.0, slot: int = 0, merged: bool = false) -> EchoActor:
	var take := EchoTake.new()
	take.uid = slot + 1
	take.condition = condition
	take.merged = merged
	take.tint_index = slot
	take.samples = PackedVector2Array([Vector2(280, 240), Vector2(320, 240)])
	return EchoActor.new(take, slot)


func test_condition_drives_physical_wear_and_remaining_seconds(c: Check) -> void:
	var sim := _sim()
	var actor := _actor()
	var fresh := EchoInk.profile(actor, sim)
	c.eq(fresh["remaining"], 120.0, "intact recording shows its real combat seconds")
	c.eq(fresh["crease_count"], 0, "fresh paper is uncreased")
	c.ok(not fresh["expiring"] and fresh["visible"], "fresh copy is visibly live")
	actor.take.condition = 50.0
	var middle := EchoInk.profile(actor, sim)
	c.near(middle["wear_ratio"], 0.5, 0.001, "condition determines continuous wear")
	c.eq(middle["remaining"], 60.0, "half condition means half the current duration")
	c.ok(middle["crease_count"] > fresh["crease_count"], "wear changes physical paper marks")
	actor.take.condition = 25.0
	var last := EchoInk.profile(actor, sim)
	c.ok(last["expiring"] and last["tear_count"] > 0, "low condition receives a torn edge warning")
	c.ok(last["alpha"] < fresh["alpha"] and last["alpha"] > 0.5, "old paper stays readable")
	c.ok((last["paper_scale"] as Vector2).y < (fresh["paper_scale"] as Vector2).y,
		"low condition compresses the physical silhouette")
	sim.player.stats.values[Stats.ECHO_DURATION] = 240.0
	actor.take.stats.values[Stats.ECHO_DURATION] = 120.0
	sim.wear_rate_mult = 2.0
	c.eq(EchoInk.profile(actor, sim)["remaining"], 30.0,
		"remaining time uses current duration and role wear, not recorded stats")
	actor.take.condition = 0.0
	var exhausted := EchoInk.profile(actor, sim)
	c.ok(exhausted["expired"] and not exhausted["visible"], "zero condition cannot display a firing copy")
	c.eq(exhausted["alpha"], 0.0, "exhaustion removes the body silhouette")


func test_merge_silence_rewind_and_wear_can_be_read_together(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(20.0, 3)
	actor.take.weapons = [Content.weapon(&"pistol"), Content.weapon(&"pistol")]
	c.eq(EchoInk.profile(actor, sim)["staple_count"], 0, "weapon count does not invent a merge")
	actor.take.merged = true
	actor.rewinding = true
	sim.echo_silenced = 2.0
	var data := EchoInk.profile(actor, sim)
	var geometry := EchoInk.mark_geometry(Rect2(100, 140, 52, 60), data)
	c.eq(data["state_priority"], &"muted", "silence leads without hiding other physical states")
	c.ok(data["muted"] and data["rewinding"] and data["expiring"], "all independent states remain exposed")
	c.eq(geometry["staples"].size(), 1, "merged copy has an actual binding")
	c.eq(geometry["punctures"].size(), 2, "binding has two holes")
	c.eq(geometry["mute"].size(), 2, "silence has a broad crossed seal")
	c.eq(geometry["rewind"].size(), 2, "reverse playback keeps two chevrons")
	c.ok(not geometry["expiry"].is_empty(), "low condition seam remains while silenced")


func test_identity_marks_survive_slot_reordering_with_bounded_detail(c: Check) -> void:
	var sim := _sim()
	for slot in 8:
		sim.echoes.append(_actor(1.0, slot, slot % 2 == 0))
	var signatures: Array[String] = []
	for actor in sim.echoes:
		var data := EchoInk.profile(actor, sim)
		var geometry := EchoInk.mark_geometry(Rect2(200, 230, 50, 58), data)
		c.ok(data["crowded"], "eight copies limit detail")
		c.ok(geometry["creases"].size() <= 2 and geometry["tears"].size() <= 1, "crowding keeps drawing bounded")
		var signature := ""
		for mark: Dictionary in geometry["identity"]:
			signature += "1" if mark["punched"] else "0"
		c.ok(not signatures.has(signature), "physical punch patterns distinguish eight printed copies")
		signatures.append(signature)
		actor.index = 0
		c.eq(EchoInk.profile(actor, sim)["identity_pattern"], data["identity_pattern"],
			"removing another actor cannot replace this copy's print identity")


func test_marks_stay_on_body_and_invalid_bounds_are_safe(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(20.0, 1, true)
	actor.rewinding = true
	sim.echo_silenced = 1.0
	var data := EchoInk.profile(actor, sim)
	var bounds := Rect2(430, 260, 45, 62)
	var geometry := EchoInk.mark_geometry(bounds, data)
	for key in ["creases", "tears", "staples", "mute", "rewind"]:
		for line: PackedVector2Array in geometry[key]:
			for point in line:
				c.ok(bounds.has_point(point), "paper marks stay inside the real sprite crop")
	for bad in [Rect2(), Rect2(0, 0, -1, 20), Rect2(0, 0, 1, 20), Rect2(Vector2(INF, 0), Vector2(50, 50))]:
		var empty := EchoInk.mark_geometry(bad, data)
		c.ok(empty["creases"].is_empty() and empty["expiry"].is_empty(), "invalid art cannot submit invalid geometry")
	c.ok(not EchoInk.profile(null, sim)["valid"], "missing actor has no invented marks")
	c.ok(not EchoInk.profile(actor, null)["valid"], "missing simulation has no invented wear")
	actor.take.condition = -4.0
	c.eq(EchoInk.profile(actor, sim)["condition"], 0.0, "presentation safely clamps invalid condition")
	c.eq(actor.take.condition, -4.0, "rendering never repairs authoritative data")


func test_render_clocks_and_reduced_effects_never_mutate_rules(c: Check) -> void:
	var sim := _sim()
	var actor := _actor(20.0, 0, true)
	actor.rewinding = true
	sim.echo_silenced = 2.0
	var state := sim.rng.state
	var data := EchoInk.profile(actor, sim, 0.0, true)
	var later := EchoInk.profile(actor, sim, 600.0, true)
	c.eq(data, later, "paused render clocks do not change paper wear or state")
	for field in ["condition", "remaining", "merged", "muted", "rewinding", "expiring", "identity_pattern", "state_priority", "body_tint", "paper_scale"]:
		c.eq(data[field], EchoInk.profile(actor, sim, 2.0, false)[field], "reduced effects retain all gameplay information")
	c.eq(sim.rng.state, state, "paper rendering consumes no gameplay randomness")
	c.eq(actor.t, 0.0, "rendering cannot advance playback")
	c.eq(actor.take.condition, 20.0, "rendering cannot spend condition")
