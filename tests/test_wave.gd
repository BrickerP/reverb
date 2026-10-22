extends RefCounted


func test_plan_is_deterministic(c: Check) -> void:
	var a := WaveDirector.plan(7, 42)
	var b := WaveDirector.plan(7, 42)
	c.eq(a.size(), b.size(), "same size")
	var same := true
	for i in a.size():
		if a[i].def.id != b[i].def.id or not is_equal_approx(a[i].time, b[i].time):
			same = false
	c.ok(same, "same seed and wave give an identical plan")
	var other := WaveDirector.plan(7, 43)
	var differs := other.size() != a.size()
	for i in mini(a.size(), other.size()):
		if not is_equal_approx(a[i].time, other[i].time):
			differs = true
	c.ok(differs, "different seed gives a different plan")


func test_plan_sorted_inside_window_and_within_budget(c: Check) -> void:
	for wave in range(1, WaveDirector.FINAL_WAVE + 1):
		var events := WaveDirector.plan(wave, 3)
		var cost := 0.0
		var sorted := true
		for i in events.size():
			cost += events[i].def.cost
			if i > 0 and events[i].time < events[i - 1].time:
				sorted = false
		c.ok(sorted, "wave %d sorted by time" % wave)
		c.ok(cost <= WaveDirector.budget_for(wave) + 0.001, "wave %d within budget" % wave)
		c.ok(events[0].time >= 0.5, "wave %d first spawn after 0.5s" % wave)
		c.ok(events[events.size() - 1].time <= WaveDirector.duration_for(wave), "wave %d spawns before the end" % wave)


func test_enemy_types_unlock_by_wave(c: Check) -> void:
	for e in WaveDirector.plan(1, 5):
		c.eq(e.def.id, &"grunt", "wave 1 only has grunts")
	for e in WaveDirector.plan(4, 5):
		c.ok(e.def.id != &"brute", "no brutes before wave 5")
	var brutes := 0
	for s in range(1, 6):
		for e in WaveDirector.plan(12, s):
			if e.def.id == &"brute":
				brutes += 1
	c.ok(brutes > 0, "brutes appear in later waves")


func test_scaling_curves(c: Check) -> void:
	c.near(WaveDirector.duration_for(1), 20.0, 0.001, "wave 1 lasts 20s")
	c.near(WaveDirector.duration_for(WaveDirector.FINAL_WAVE), 60.0, 0.001, "duration capped at 60s")
	c.near(WaveDirector.hp_scale(1), 1.0, 0.0001, "no hp scaling on wave 1")
	c.ok(WaveDirector.speed_scale(100) <= 1.3, "speed scaling is capped")
	for w in range(2, 21):
		c.ok(WaveDirector.budget_for(w) > WaveDirector.budget_for(w - 1), "budget grows at wave %d" % w)
		c.ok(WaveDirector.hp_scale(w) > WaveDirector.hp_scale(w - 1), "hp grows at wave %d" % w)


func test_spawn_position_inside_arena_and_away_from_player(c: Check) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var arena := Sim.ARENA
	var all_inside := true
	var all_far := true
	for i in 300:
		var player := Vector2(
				rng.randf_range(arena.position.x, arena.end.x),
				rng.randf_range(arena.position.y, arena.end.y))
		var p := WaveDirector.spawn_position(arena, player, rng)
		if not arena.has_point(p):
			all_inside = false
		if p.distance_to(player) < WaveDirector.MIN_SPAWN_DISTANCE:
			all_far = false
	c.ok(all_inside, "spawn points are inside the arena")
	c.ok(all_far, "spawn points keep their distance from the player")
