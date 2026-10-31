extends RefCounted


func test_actual_atlases_and_closed_frames_are_registered(c: Check) -> void:
	c.ok(BureauArt.facility_texture() != null, "real generated facility atlas is available")
	c.ok(BureauArt.binding_texture() != null, "real generated binding atlas is available")
	var regions: Array[Rect2] = []
	for id: StringName in BureauArt.FACILITY_IDS:
		var region := BureauArt.facility_region(id)
		c.ok(region.has_area(), "declared facility has pixels: " + String(id))
		c.ok(not regions.has(region), "facility owns a distinct cell")
		regions.append(region)
		c.ok(Rect2(Vector2.ZERO, BureauArt.facility_texture().get_size()).encloses(region), "facility source remains in atlas")
	c.eq(BureauArt.facility_region(&"missing"), Rect2(), "unknown facility never borrows another machine")
	for frame in 8:
		c.ok(BureauArt.binding_region(frame).has_area(), "all eight ceremony poses exist")
	c.eq(BureauArt.binding_region(-1), BureauArt.binding_region(0), "negative presentation frame is bounded")
	c.eq(BureauArt.binding_region(99), BureauArt.binding_region(7), "large presentation frame is bounded")


func test_stamp_view_and_offscreen_goal_read_exact_model_without_mutation(c: Check) -> void:
	var sim := Sim.new(1704)
	sim.start_run()
	sim.start_wave(2)
	sim._plan.clear()
	var before := RunSnapshot.capture(sim)
	var profile := BureauInk.snapshot(sim)
	c.eq(profile["delivery"]["radius"], BureauEvents.RADIUS, "draw radius equals real stamp hit radius")
	c.eq(profile["delivery"]["stamp"], BureauEvents.STAMP, "stamp art uses authored model location")
	var direction := BureauInk.direction_profile(sim)
	c.ok(direction["visible"], "a player at normal start can discover the distant optional event")
	c.ok((profile["bounds"] as Rect2).encloses(direction["label"]), "goal label stays inside battle crop")
	c.ok((profile["bounds"] as Rect2).has_point(direction["point"]), "direction arrow stays outside HUD")
	var compact := BureauInk.direction_profile(sim, WorldArena.display_viewport(Vector2(960, 540)))
	c.ok(WorldArena.camera_rect(sim.player.pos, WorldArena.display_viewport(Vector2(960, 540))).encloses(compact["label"]), "native compact camera retains whole goal label")
	sim.player.pos = BureauEvents.PICKUP
	c.ok(not BureauInk.direction_profile(sim)["visible"], "arriving at pickup removes redundant edge arrow")
	var after_move := RunSnapshot.capture(sim)
	BureauInk.snapshot(sim)
	BureauInk.direction_profile(sim)
	c.eq(RunSnapshot.capture(sim), after_move, "all new presentation queries preserve full state and RNG")
	c.ok(not before.is_empty(), "fixture is snapshot-valid")
	c.ok(not BureauInk.direction_profile(null)["visible"], "detached session has no goal")


func test_cleanup_uses_actual_survivor_and_retirement_counts(c: Check) -> void:
	var depot := RecyclingDepot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(depot)
	var sim := Sim.new(1705)
	sim.start_run()
	var world := Expedition.world_profile(sim)
	world["bureau"] = {"retired": []}
	depot.set_world_profile(world)
	c.eq(depot._retired_count, 0, "empty record cannot invent cleanup remains")
	world["bureau"]["retired"] = [{}, {}, {}, {}, {}, {}, {}, {}]
	depot.set_world_profile(world)
	c.eq(depot._retired_count, 6, "cleanup decorations retain six-record ceiling")
	depot.set_presentation(1.0, false, false)
	depot.set_presentation(20.0, false, true)
	c.eq(depot._visual_time, 1.0, "pause freezes broom motion")
	depot.set_presentation(25.0, true, false)
	c.ok(depot._reduced_effects, "reduced effects use static broom")
	depot.free()


func test_delivery_state_and_phase_labels_follow_actual_model(c: Check) -> void:
	var sim := Sim.new(1706)
	sim.start_run()
	sim.start_wave(2)
	sim._plan.clear()
	var view := WorldArena.camera_rect(BureauEvents.STAMP, WorldArena.display_viewport(Vector2(960, 540)))
	var p: Dictionary = BureauEvents.profile(sim)["delivery"]
	var label := BureauInk.delivery_label_profile(p, view)
	c.eq(label["title_key"], "bureau.delivery.waiting", "waiting state has real objective text")
	c.eq(label["detail_key"], "bureau.delivery.warning", "initial cycle visibly warns before impact")
	c.ok(view.encloses(label["rect"]), "full state/phase label stays inside compact battle crop")
	sim.player.pos = BureauEvents.SWITCH
	c.ok(sim.interact(), "real manual switch holds stamp")
	p = BureauEvents.profile(sim)["delivery"]
	label = BureauInk.delivery_label_profile(p, view)
	c.eq(label["detail_key"], "bureau.delivery.safe", "safe interval shows exact countdown")
	c.eq(label["args"], [BureauEvents.SAFE_INTERVAL], "countdown uses model time")
	sim.player.pos = BureauEvents.PICKUP
	c.ok(sim.interact(), "real pickup takes the outgoing file")
	p = BureauEvents.profile(sim)["delivery"]
	c.eq(BureauInk.delivery_label_profile(p, view)["title_key"], "bureau.delivery.carrying", "carried state uses actual pickup")
	sim.player.pos = BureauEvents.INBOX
	c.ok(sim.interact(), "real inbox submission commits reward")
	label = BureauInk.delivery_label_profile(BureauEvents.profile(sim)["delivery"], view)
	c.eq(label["title_key"], "bureau.delivery.delivered", "completion derives actual submission")
	c.eq(label["detail_key"], "bureau.delivery.reward", "paid reward is clearly visible")
	c.eq(label["args"], [BureauEvents.REWARD], "display reward equals once-only model payout")
