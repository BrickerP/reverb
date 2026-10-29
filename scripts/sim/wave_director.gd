class_name WaveDirector
extends RefCounted

const FINAL_WAVE := 12
const ELITE_START_WAVE := 6
const ELITE_KINDS := [&"overclocked", &"bulwark", &"volatile", &"splitter"]
const MIN_SPAWN_DISTANCE := 240.0
const EDGE_INSET := 24.0
const COHORT_WINDOWS := [[0.0, 0.24], [0.36, 0.60], [0.72, 1.0]]


static func duration_for(wave: int) -> float:
	return minf(60.0, 24.0 + 3.0 * float(wave - 1))


static func budget_for(wave: int) -> float:
	var w := float(wave)
	return minf(360.0, 10.0 + 8.0 * w)


static func cash_budget(wave: int) -> int:
	return mini(300, 24 + 6 * maxi(1, wave))


static func hp_scale(wave: int) -> float:
	var k := float(wave - 1)
	return 1.0 + 0.16 * k + 0.015 * k * k


static func damage_scale(wave: int) -> float:
	return 1.0 + 0.10 * float(wave - 1)


static func speed_scale(wave: int) -> float:
	return minf(1.3, 1.0 + 0.015 * float(wave - 1))


static func phase_profile(wave_time: float, duration: float) -> Dictionary:
	if not is_finite(duration) or duration <= 0.0 or not is_finite(wave_time):
		return _phase(&"ready", 0.0)
	var time := maxf(0.0, wave_time)
	if time >= duration:
		return _phase(&"complete", 0.0)
	if time < duration * COHORT_WINDOWS[0][1]:
		return _phase(&"first_push", 0.45)
	if time < duration * COHORT_WINDOWS[1][0]:
		return _phase(&"first_breather", 0.12)
	if time < duration * COHORT_WINDOWS[1][1]:
		return _phase(&"second_push", 0.75)
	if time < duration * COHORT_WINDOWS[2][0]:
		return _phase(&"second_breather", 0.18)
	return _phase(&"final_push", 1.0)


static func _phase(id: StringName, intensity: float) -> Dictionary:
	return {"id": id, "name_key": "wave.phase." + String(id), "intensity": intensity}


static func plan(wave: int, run_seed: int, budget_mult: float = 1.0,
		endless: bool = false, elite_count: int = 1) -> Array[SpawnEvent]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + wave * 104729
	var pool: Array[EnemyDef] = []
	for d in Content.enemies():
		if d.min_wave <= wave and not d.is_boss:
			pool.append(d)
	var picked: Array[EnemyDef] = []
	var budget := budget_for(wave) * budget_mult
	while budget > 0.0:
		var d := _pick(pool, rng)
		if d.cost > budget and not picked.is_empty():
			break
		budget -= d.cost
		picked.append(d)
	var events: Array[SpawnEvent] = []
	var duration := duration_for(wave)
	for i in picked.size():
		var e := SpawnEvent.new()
		e.def = picked[i]
		var cohort := mini(COHORT_WINDOWS.size() - 1, int(float(i * 3) / float(picked.size())))
		var first := ceili(float(cohort * picked.size()) / 3.0)
		var end := ceili(float((cohort + 1) * picked.size()) / 3.0)
		var local_progress := (float(i - first) + rng.randf()) / float(end - first)
		var window: Array = COHORT_WINDOWS[cohort]
		var start := maxf(0.5, duration * float(window[0]))
		var finish := duration * float(window[1])
		if cohort == 2:
			finish = maxf(start, duration - Sim.SPAWN_TELEGRAPH)
		e.time = lerpf(start, finish, local_progress)
		events.append(e)
	# An elite upgrades an existing budget slot in late ordinary encounters;
	# it never adds spawn cost or consumes an extra RNG stream for the rest of the plan.
	if wave >= ELITE_START_WAVE and wave % 4 != 0 and (wave < FINAL_WAVE or (endless and wave > FINAL_WAVE)) and not events.is_empty():
		var available: Array[int] = []
		for i in events.size():
			available.append(i)
		for _elite in mini(elite_count, available.size()):
			var pick := rng.randi_range(0, available.size() - 1)
			var elite_index: int = available.pop_at(pick)
			var kind_index := rng.randi_range(0, ELITE_KINDS.size() - 1)
			events[elite_index].elite_kind = ELITE_KINDS[kind_index]
	return events


static func _pick(pool: Array[EnemyDef], rng: RandomNumberGenerator) -> EnemyDef:
	var total := 0.0
	for d in pool:
		total += d.weight
	var roll := rng.randf() * total
	for d in pool:
		roll -= d.weight
		if roll <= 0.0:
			return d
	return pool[pool.size() - 1]


static func spawn_position(arena: Rect2, player_pos: Vector2, rng: RandomNumberGenerator,
		radius: float = 28.0) -> Vector2:
	var box := arena.grow(-maxf(EDGE_INSET, radius + 2.0))
	var neighborhood := WorldArena.camera_rect(player_pos).grow(44.0)
	for _try in 32:
		var p := _edge_point(neighborhood, rng.randi_range(0, 3), rng.randf())
		if box.has_point(p) and p.distance_to(player_pos) >= MIN_SPAWN_DISTANCE \
				and WorldArena.body_clear(p, radius):
			return p
	# At a world corner, only two camera edges have space outside them. Search
	# those edges evenly instead of clamping hidden spawns onto a distant wall.
	for edge in 4:
		for index in 17:
			var p := _edge_point(neighborhood, edge, float(index) / 16.0)
			if box.has_point(p) and p.distance_to(player_pos) >= MIN_SPAWN_DISTANCE \
					and WorldArena.body_clear(p, radius):
				return p
	var corners: Array[Vector2] = [
		box.position, Vector2(box.end.x, box.position.y),
		box.end, Vector2(box.position.x, box.end.y),
	]
	var best := corners[0]
	for c in corners:
		if c.distance_to(player_pos) > best.distance_to(player_pos):
			best = c
	return best


static func _edge_point(box: Rect2, edge: int, weight: float) -> Vector2:
	match edge:
		0: return Vector2(lerpf(box.position.x, box.end.x, weight), box.position.y)
		1: return Vector2(lerpf(box.position.x, box.end.x, weight), box.end.y)
		2: return Vector2(box.position.x, lerpf(box.position.y, box.end.y, weight))
	return Vector2(box.end.x, lerpf(box.position.y, box.end.y, weight))
