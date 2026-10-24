extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _rift_sim() -> Sim:
	var sim := Sim.new(97)
	sim.start_run()
	sim.start_wave(Sim.RIFT_START_WAVE)
	sim.pending.clear()
	sim._rift_cd = 0.0
	sim._step_rifts(0.0)
	return sim


func test_warning_and_active_profiles_are_distinct_and_cover_full_runtime_radius(c: Check) -> void:
	var sim := _rift_sim()
	var rift: TemporalRift = sim.rifts[0]
	var warning := ArenaPainter.rift_profile(rift, sim.wave_time, false)
	var warning_bounds: Rect2 = warning["bounds"]
	c.eq(warning["state"], &"warning", "new rift is presented as a warning")
	c.ok(bool(warning["spokes"]) and float(warning["warning_ring_radius"]) > 0.0,
			"standard warning includes countdown geometry")
	c.ok(Sim.ARENA.encloses(warning_bounds),
			"warning's complete runtime radius stays inside the arena")
	sim._rift_cd = 999.0
	sim._step_rifts(TemporalRift.TELEGRAPH_TIME)
	var active := ArenaPainter.rift_profile(rift, sim.wave_time, false)
	var active_bounds: Rect2 = active["bounds"]
	c.eq(active["state"], &"active", "activated rift switches to active presentation")
	c.ok(float(active["fill_alpha"]) > float(warning["fill_alpha"])
			and float(active["boundary_width"]) > float(warning["boundary_width"]),
			"active hazard reads stronger than its warning")
	c.eq(active["active_arc_count"], 2, "standard active rift retains directional motion")
	c.ok(Sim.ARENA.encloses(active_bounds),
			"active hazard's complete runtime radius stays inside the arena")


func test_reduced_rift_profiles_are_stable_essential_fill_and_boundary(c: Check) -> void:
	var sim := _rift_sim()
	var rift: TemporalRift = sim.rifts[0]
	var warning_a := ArenaPainter.rift_profile(rift, 0.0, true)
	rift.telegraph *= 0.5
	var warning_b := ArenaPainter.rift_profile(rift, 9.0, true)
	c.near(float(warning_a["fill_alpha"]), float(warning_b["fill_alpha"]), 0.0001,
			"reduced warning fill is stable across time")
	c.near(float(warning_a["boundary_alpha"]), float(warning_b["boundary_alpha"]), 0.0001,
			"reduced warning boundary is stable across countdown")
	c.ok(not bool(warning_a["spokes"]) and float(warning_a["warning_ring_radius"]) == 0.0,
			"reduced warning removes spokes and moving inner ring")
	rift.telegraph = 0.0
	rift.active = TemporalRift.ACTIVE_TIME
	var active_a := ArenaPainter.rift_profile(rift, 0.0, true)
	var active_b := ArenaPainter.rift_profile(rift, 9.0, true)
	c.near(float(active_a["fill_alpha"]), float(active_b["fill_alpha"]), 0.0001,
			"reduced active fill does not pulse")
	c.eq(active_a["active_arc_count"], 0, "reduced active rift removes rotating arcs")
	c.ok(float(active_a["boundary_alpha"]) > 0.0 and float(active_a["fill_alpha"]) > 0.0,
			"reduced active rift keeps its essential full boundary and fill")


func test_profile_generation_is_pure_and_does_not_consume_rng_or_state(c: Check) -> void:
	var sim := _rift_sim()
	var rift: TemporalRift = sim.rifts[0]
	var rng_state := sim.hazard_rng.state
	var snapshot := [rift.pos, rift.radius, rift.telegraph, rift.active, rift.tick]
	var first := ArenaPainter.rift_profiles(sim, false)
	var second := ArenaPainter.rift_profiles(sim, true)
	c.eq(first.size(), 1, "standard renderer receives the runtime rift")
	c.eq(second.size(), 1, "reduced renderer receives the same runtime rift")
	c.eq(sim.hazard_rng.state, rng_state, "drawing profiles never consume hazard RNG")
	c.eq([rift.pos, rift.radius, rift.telegraph, rift.active, rift.tick], snapshot,
			"drawing profiles never mutate rift timers or geometry")


func test_pause_wave_reset_and_rebind_leave_no_ghost_hazards(c: Check) -> void:
	var first := _rift_sim()
	var rift: TemporalRift = first.rifts[0]
	var view := ArenaView.new()
	_root().add_child(view)
	view.bind(first)
	view.set_paused(true)
	var snapshot := [rift.telegraph, rift.active, rift.tick]
	view._process(0.5)
	c.eq([rift.telegraph, rift.active, rift.tick], snapshot,
			"paused presentation does not advance hazard state")
	var second := Sim.new(98)
	second.start_run()
	view.bind(second)
	c.ok(ArenaPainter.rift_profiles(view.sim, false).is_empty(),
			"rebind renders only the new simulation's hazards")
	first.start_wave(Sim.RIFT_START_WAVE + 1)
	c.ok(first.rifts.is_empty(), "wave reset clears prior hazards at the source")
	view.unbind()
	c.eq(view.sim, null, "unbind leaves no hazard source attached")
	view.free()


func test_rift_death_cause_is_localized_in_english_and_chinese(c: Check) -> void:
	var sim := _rift_sim()
	sim.phase = Sim.Phase.LOST
	sim.last_damage_source = &"rift"
	var previous := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		var ui := EndUi.new()
		ui.theme = UiTheme.build()
		_root().add_child(ui)
		ui.show_result(sim)
		c.ok(ui._stats.text.contains(Loc.t("enemy.rift")),
				"%s end screen names the rift death cause" % language)
		ui.free()
	Loc.lang = previous
