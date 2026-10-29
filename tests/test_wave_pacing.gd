extends RefCounted


func test_three_pushes_keep_middle_breathers_but_reach_the_end(c: Check) -> void:
	for wave in [1, 5, 9, 12, 17]:
		var events := WaveDirector.plan(wave, 42)
		var duration := WaveDirector.duration_for(wave)
		var previous := -INF
		var counts := [0, 0, 0]
		for event in events:
			c.ok(event.time >= previous, "cohorts remain chronologically ordered")
			previous = event.time
			var id: StringName = WaveDirector.phase_profile(event.time, duration)["id"]
			c.ok(id in [&"first_push", &"second_push", &"final_push"], "scheduled arrivals respect actual middle breathers")
			counts[0 if id == &"first_push" else (1 if id == &"second_push" else 2)] += 1
		c.ok(counts.min() > 0, "each encounter has three real pushes")
		c.ok(events.back().time >= duration * 0.85, "final push reaches the last seconds")
		c.ok(events.back().time <= duration - Sim.SPAWN_TELEGRAPH, "final planned enemy can materialize before expiry")
		c.eq(WaveDirector.phase_profile(duration * 0.97, duration)["id"], &"final_push", "no empty automatic cleanup phase replaces the ending")


func test_reward_and_population_curves_are_linear_then_bounded(c: Check) -> void:
	for wave in range(2, 13):
		c.near(WaveDirector.budget_for(wave) - WaveDirector.budget_for(wave - 1), 8.0, 0.001, "normal population budget has linear growth")
		c.eq(WaveDirector.cash_budget(wave) - WaveDirector.cash_budget(wave - 1), 6, "cash allowance has independent linear growth")
	c.ok(WaveDirector.budget_for(10000) <= 360.0, "endless budget stays bounded")


func test_phase_boundaries_and_invalid_clock(c: Check) -> void:
	var starts := [0.0, 0.24, 0.36, 0.60, 0.72, 1.0]
	var ids := [&"first_push", &"first_breather", &"second_push", &"second_breather", &"final_push", &"complete"]
	for index in starts.size():
		c.eq(WaveDirector.phase_profile(starts[index] * 60.0, 60.0)["id"], ids[index], "phase follows shared actual pacing boundary")
	for duration in [0.0, -1.0, INF, NAN]:
		c.eq(WaveDirector.phase_profile(10.0, duration)["id"], &"ready", "invalid clock cannot invent combat pressure")
