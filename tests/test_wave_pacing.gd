extends RefCounted


func test_three_cohorts_keep_the_existing_enemy_budget(c: Check) -> void:
	# Captured before rescheduling: pacing changes when the same budget arrives,
	# without granting or removing enemies or advancing the elite RNG stream.
	var fixtures := [[1, 14, 14.0], [5, 39, 64.0], [10, 96, 175.8],
		[19, 260, 499.3], [20, 289, 544.1], [21, 319, 593.1]]
	for fixture in fixtures:
		var wave: int = fixture[0]
		var events := WaveDirector.plan(wave, 42)
		var cost := 0.0
		for event in events:
			cost += event.def.cost
		c.eq(events.size(), fixture[1], "wave %d retains its original planned body count" % wave)
		c.near(cost, fixture[2], 0.01, "wave %d retains its original planned budget" % wave)


func test_cohorts_are_sorted_and_breathers_have_no_new_spawns(c: Check) -> void:
	for wave in [1, 5, 10, 19, 20, 21]:
		for seed_value in [1, 42, 7341]:
			var events := WaveDirector.plan(wave, seed_value)
			var duration := WaveDirector.duration_for(wave)
			var counts := [0, 0, 0]
			var firsts := [INF, INF, INF]
			var lasts := [-INF, -INF, -INF]
			var previous := -INF
			for event in events:
				c.ok(event.time >= previous, "cohorts retain chronological spawn ordering")
				previous = event.time
				var phase := WaveDirector.phase_profile(event.time, duration)
				c.ok(phase["id"] in [&"first_push", &"second_push", &"final_push"],
					"every planned body arrives in a named push, never a breather")
				var cohort := 0 if phase["id"] == &"first_push" else (1 if phase["id"] == &"second_push" else 2)
				counts[cohort] += 1
				firsts[cohort] = minf(firsts[cohort], event.time)
				lasts[cohort] = maxf(lasts[cohort], event.time)
			for cohort in 3:
				var window: Array = WaveDirector.COHORT_WINDOWS[cohort]
				c.ok(counts[cohort] > 0, "each wave contains three actual cohorts")
				c.ok(abs(counts[cohort] - counts[0]) <= 1, "three pushes share the original count evenly")
				c.ok(firsts[cohort] >= maxf(0.5, float(window[0]) * duration), "push starts inside its own window")
				c.ok(lasts[cohort] < float(window[1]) * duration, "push stops before its real breather")
				if cohort > 0:
					var gap: float = (window[0] - WaveDirector.COHORT_WINDOWS[cohort - 1][1]) * duration
					c.ok(firsts[cohort] - lasts[cohort - 1] >= gap, "breather has a real no-spawn interval")


func test_phase_boundaries_have_exact_shared_names_and_intensities(c: Check) -> void:
	var starts := [0.0, 0.24, 0.36, 0.60, 0.72, 0.90, 1.0]
	var ids := [&"first_push", &"first_breather", &"second_push", &"second_breather", &"final_push", &"clear", &"complete"]
	var intensities := [0.45, 0.12, 0.75, 0.18, 1.0, 0.30, 0.0]
	for duration in [1.0, 20.0, 22.5, 60.0]:
		for index in starts.size():
			var time: float = starts[index] * duration
			var profile := WaveDirector.phase_profile(time, duration)
			c.eq(profile["id"], ids[index], "phase changes at its actual normalized boundary")
			c.eq(profile["name_key"], "wave.phase." + String(ids[index]), "HUD and music share the exact phase identity")
			c.eq(profile["intensity"], intensities[index], "pacing intensity belongs to the real phase")
			if index > 0:
				c.eq(WaveDirector.phase_profile(time - 0.00001, duration)["id"], ids[index - 1],
					"the preceding phase owns the instant immediately before the boundary")
		c.eq(WaveDirector.phase_profile(-5.0, duration)["id"], &"first_push", "negative finite time safely clamps to the opening")
		c.eq(WaveDirector.phase_profile(duration + 1.0, duration)["id"], &"complete", "finished waves stay complete")


func test_missing_or_invalid_duration_does_not_invent_combat_pressure(c: Check) -> void:
	for duration in [0.0, -1.0, INF, NAN]:
		var profile := WaveDirector.phase_profile(10.0, duration)
		c.eq(profile["id"], &"ready", "missing duration has a named neutral phase")
		c.eq(profile["name_key"], "wave.phase.ready", "neutral phase is localizable")
		c.eq(profile["intensity"], 0.0, "invalid duration cannot push music into danger")
	for time in [INF, NAN]:
		c.eq(WaveDirector.phase_profile(time, 20.0)["id"], &"ready", "nonfinite clocks remain neutral")
