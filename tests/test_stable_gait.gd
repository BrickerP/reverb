extends RefCounted

const PLAYER_KEY := &"character_looper_front"
const STRIDE_DISTANCE := 160.0


func test_distance_phase_survives_render_sampling_and_long_session_time(c: Check) -> void:
	var reference := _sample_path(60, 0.0, Vector2.RIGHT)
	for hz in [30, 60, 120, 144]:
		for lead_time in [0.0, 60.0, 1200.0]:
			var result := _sample_path(hz, lead_time, Vector2.RIGHT)
			c.near(float(result["phase"]), float(result["expected"]), 0.005,
					"%d Hz at %.0fs advances one cycle per actual stride distance" % [hz, lead_time])
			c.near(float(result["phase"]), float(reference["phase"]), 0.005,
					"zero-displacement render frames and elapsed session time cannot alter cadence")
			c.ok(result["read_only"], "gait sampling leaves simulation clocks and RNG unchanged")
	for direction: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var result := _sample_path(120, 600.0, direction)
		c.near(float(result["phase"]), float(reference["phase"]), 0.005,
				"equal travel distance has equal gait cadence in every direction")


func test_frame_lift_and_lean_share_one_distance_phase(c: Check) -> void:
	var frames := [0, 1, 0, 2]
	for quarter in 4:
		var phase := float(quarter) * TAU / 4.0
		var normal := BattleDirector.gait_profile(phase, 1.0, true, false)
		var reduced := BattleDirector.gait_profile(phase, 1.0, true, true)
		c.eq(BattleDirector.walk_pose(PLAYER_KEY, phase, true), frames[quarter],
				"foot contact and step drawings follow the full left/right cycle")
		c.eq(BattleDirector.walk_pose(PLAYER_KEY, phase, true, true), frames[quarter],
				"Reduced keeps the same physical step phase")
		if quarter % 2 == 0:
			c.near(float(normal["bob"]), 0.0, 0.0001, "contact poses are planted")
		else:
			c.ok(float(normal["bob"]) < -0.8, "raised step pose owns the small synchronized lift")
		c.near(float(reduced["bob"]), float(normal["bob"]) * 0.3, 0.0001,
				"Reduced changes amplitude rather than inventing another clock")
	for phase in [0.0, 0.7, PI, 1000.0, INF, NAN]:
		var idle := BattleDirector.gait_profile(phase, 1.0, false)
		c.eq(idle["bob"], 0.0, "idle has no foot translation even with residual motion weight")
		c.eq(idle["lean"], 0.0, "idle has no whole-body rotation")
		c.eq(idle["scale"], Vector2.ONE, "locomotion settles at idle")
		c.eq(BattleDirector.walk_pose(PLAYER_KEY, phase, false), 0, "idle selects the neutral drawing")


func test_light_fire_cannot_take_over_the_body_or_reset_a_stride(c: Check) -> void:
	var director := BattleDirector.new()
	var shot := ShotInfo.new()
	shot.weapon_id = &"smg"
	shot.actor_token = -1
	for index in 90:
		c.ok(not director.shot(shot), "rapid light fire stays on the mounted weapon")
		director.step(1.0 / 60.0)
		c.eq(director.player_pose(PLAYER_KEY, PI / 2.0, true, false), 1,
				"light volleys do not replace a moving paper leg")
	shot.weapon_id = &"mallet"
	c.ok(director.shot(shot), "a real heavy slam earns one body action")
	c.eq(director.player_pose(PLAYER_KEY, PI / 2.0, true, false), 5, "heavy action starts on impact")
	for index in 30:
		c.ok(not director.shot(shot), "the heavy body action cannot restart every render tick")
	director.step(BattleDirector.SHOT_TIME + 0.01)
	c.eq(director.player_pose(PLAYER_KEY, PI / 2.0, true, false), 1,
			"heavy recovery returns to the held distance phase, not elapsed-time animation")
	c.eq(director.player_pose(PLAYER_KEY, PI / 2.0, true, true), 1,
			"Reduced keeps the leg pose while omitting the body kick")


func test_persistent_copy_uids_do_not_accept_enemy_or_unknown_tokens(c: Check) -> void:
	var director := BattleDirector.new()
	var shot := ShotInfo.new()
	shot.weapon_id = &"mallet"
	for token in [0, -2, -900, -9223371986674121139]:
		shot.actor_token = token
		c.ok(not BattleDirector.is_copy_token(token), "negative presentation keys never identify a saved copy")
		c.ok(not director.shot(shot), "unknown and enemy keys cannot allocate copy shot actions")
	shot.actor_token = 42
	shot.source = 0
	c.ok(BattleDirector.is_copy_token(42), "positive persistent take UID identifies its copy")
	c.ok(director.shot(shot), "a deployed positive UID can perform its heavy action")
	c.eq(director.echo_pose(PLAYER_KEY, 42, PI / 2.0, true, false), 5, "body action belongs to that UID")
	c.eq(director.echo_pose(PLAYER_KEY, 43, PI / 2.0, true, false), 1, "another copy keeps walking")
	director.clear()
	c.eq(director.echo_pose(PLAYER_KEY, 42, PI / 2.0, true, false), 1, "new-run clearing discards old body actions")


func test_pause_freezes_the_new_gait_phase(c: Check) -> void:
	var sim := Sim.new(7104)
	sim.start_run()
	sim.phase = Sim.Phase.WAVE
	var view := ArenaView.new()
	view.bind(sim)
	sim.player.pos += Vector2(20.0, 0.0)
	sim.wave_time += 1.0 / 60.0
	view._process(1.0 / 60.0)
	var phase: float = view.motion_stats()["gait_phase"]
	view.set_paused(true)
	view._process(9.0)
	c.eq(view.motion_stats()["gait_phase"], phase, "pause cannot advance the distance phase")
	view.unbind()
	c.eq(view.motion_stats()["gait_phase"], 0.0, "detaching resets gait for the next run")
	view.free()


func _sample_path(render_hz: int, lead_time: float, direction: Vector2) -> Dictionary:
	var sim := Sim.new(7103)
	sim.start_run()
	sim.phase = Sim.Phase.WAVE
	var view := ArenaView.new()
	view.bind(sim)
	view._visual_time = lead_time
	var physics_step := 1.0 / 60.0
	var next_tick := physics_step
	var distance := 0.0
	var read_only := true
	for frame in render_hz * 2 + 1:
		var time := float(frame) / float(render_hz)
		while next_tick <= time + 0.000001:
			var before := sim.player.pos
			sim.player.pos += direction * 260.0 * physics_step
			distance += before.distance_to(sim.player.pos)
			sim.wave_time += physics_step
			next_tick += physics_step
		var state := [sim.rng.state, sim.hazard_rng.state, sim.wave_time, sim.player.pos]
		view._process(1.0 / float(render_hz))
		read_only = read_only and state == [sim.rng.state, sim.hazard_rng.state, sim.wave_time, sim.player.pos]
	var phase: float = view.motion_stats()["gait_phase"]
	view.free()
	return {"phase": phase, "expected": fposmod(distance / STRIDE_DISTANCE * TAU, TAU), "read_only": read_only}
