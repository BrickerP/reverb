extends RefCounted


func _finite_sim() -> Sim:
	var sim := Sim.new(42)
	sim.start_run()
	sim.start_wave(2)
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	sim._plan.clear()
	for time: float in [0.5, 1.0, 12.0, 13.0, 24.0, 25.0]:
		var event := SpawnEvent.new()
		event.def = Content.enemy(&"grunt")
		event.time = time
		sim._plan.append(event)
	sim.wave_duration = 40.0
	return sim


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


func test_cleared_cohort_advances_only_its_remaining_budget_after_a_breather(c: Check) -> void:
	var sim := _finite_sim()
	sim._plan_idx = 2
	sim.wave_time = 2.0
	var rng_state := sim.rng.state
	var hazard_state := sim.hazard_rng.state
	c.eq(sim.encounter_profile()["id"], &"first_breather", "clearing the first real cohort opens its breather")
	sim._step_cleared_cohort(0.5)
	c.near(sim._plan[2].time, 12.0, 0.001, "clearing never skips the short recovery beat")
	sim._step_cleared_cohort(0.71)
	c.near(sim._plan[2].time, 2.0, 0.001, "the next finite cohort can arrive early")
	c.near(sim._plan[3].time, 3.0, 0.001, "its internal spacing is preserved")
	c.near(sim._plan[4].time, 24.0, 0.001, "later cohorts retain their own schedule")
	c.eq(sim._plan.size(), 6, "advancing cannot invent replacement enemies")
	c.near(sim.wave_time, 2.0, 0.001, "advancing a cohort does not fast-forward combat")
	c.eq(sim.rng.state, rng_state, "schedule changes do not consume gameplay RNG")
	c.eq(sim.hazard_rng.state, hazard_state, "schedule changes do not consume hazard RNG")
	sim._spawn_enemies(0.01)
	c.eq(sim._plan_idx, 3, "the accelerated enemy enters the real spawn queue")
	c.eq(sim.encounter_profile()["id"], &"second_push", "presentation follows the accelerated cohort instead of the old clock")
	c.near(sim.encounter_profile()["intensity"], 0.75, 0.001, "audio and HUD share the second push intensity")


func test_unfinished_cohort_or_telegraph_prevents_acceleration(c: Check) -> void:
	var sim := _finite_sim()
	sim._plan_idx = 1
	sim.wave_time = 0.7
	sim._step_cleared_cohort(2.0)
	c.near(sim._plan[1].time, 1.0, 0.001, "unissued enemies still belong to the current cohort")
	sim._plan_idx = 2
	var pending := PendingSpawn.new()
	pending.def = Content.enemy(&"grunt")
	pending.delay = 0.4
	sim.pending.append(pending)
	sim._step_cleared_cohort(2.0)
	c.near(sim._plan[2].time, 12.0, 0.001, "a visible telegraph remains unfinished pressure")
	c.eq(sim.encounter_profile()["id"], &"first_push", "the next cohort is not announced before the current one clears")
	sim.pending.clear()
	sim.wave_time = 12.01
	sim._spawn_enemies(0.01)
	c.eq(sim._plan_idx, 3, "the original schedule still proceeds if a slow clear misses early advancement")


func test_capacity_cannot_erase_planned_or_telegraphed_ordinary_enemies(c: Check) -> void:
	var sim := _finite_sim()
	sim.wave_time = 0.6
	for index in Sim.MAX_ENEMIES:
		var enemy := EnemyState.new()
		enemy.def = Content.enemy(&"grunt")
		enemy.uid = index + 1
		sim.enemies.append(enemy)
	sim._spawn_enemies(0.01)
	c.eq(sim._plan_idx, 0, "a saturated population leaves the finite event unspent")
	c.eq(sim.pending.size(), 0, "a rejected admission cannot create an untracked arrival")
	sim.enemies.clear()
	sim._spawn_enemies(0.01)
	c.eq(sim._plan_idx, 1, "the same budget event is retried once capacity opens")
	var arrival := sim.pending[0]
	arrival.delay = 0.0
	for index in Sim.MAX_ENEMIES:
		var enemy := EnemyState.new()
		enemy.def = Content.enemy(&"grunt")
		enemy.uid = index + 1
		sim.enemies.append(enemy)
	sim._spawn_enemies(0.01)
	c.ok(sim.pending.has(arrival), "capacity loss after telegraph also retains the original arrival")
	sim.enemies.clear()
	sim._spawn_enemies(0.01)
	c.eq(sim.enemies.size(), 1, "the retained arrival eventually materializes once")
	c.ok(not sim.pending.has(arrival), "successful materialization consumes the pending arrival")


func test_boss_profile_and_completion_remain_kill_driven(c: Check) -> void:
	var sim := _finite_sim()
	sim.start_wave(4)
	sim.wave_time = sim.wave_duration + 5.0
	c.eq(sim.encounter_profile(), WaveDirector.phase_profile(sim.wave_time, sim.wave_duration), "boss presentation keeps its existing clock profile")
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"foreman")
	spawn.pos = sim.player.pos + Vector2(250.0, 0.0)
	sim._materialize(spawn)
	sim._plan_idx = sim._plan.size()
	sim.step(0.01, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.WAVE, "a living mandatory boss outlasts the survival clock")
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	sim.step(0.01, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.SHOP, "killing the mandatory boss ends its encounter")
