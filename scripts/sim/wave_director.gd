class_name WaveDirector
extends RefCounted

const FINAL_WAVE := 20
const MIN_SPAWN_DISTANCE := 240.0
const EDGE_INSET := 24.0


static func duration_for(wave: int) -> float:
	return minf(60.0, 20.0 + 2.5 * float(wave - 1))


static func budget_for(wave: int) -> float:
	var w := float(wave)
	return 6.0 + 7.0 * w + 1.0 * w * w


static func hp_scale(wave: int) -> float:
	var k := float(wave - 1)
	return 1.0 + 0.20 * k + 0.06 * k * k


static func damage_scale(wave: int) -> float:
	return 1.0 + 0.10 * float(wave - 1)


static func speed_scale(wave: int) -> float:
	return minf(1.3, 1.0 + 0.015 * float(wave - 1))


static func plan(wave: int, run_seed: int, budget_mult: float = 1.0) -> Array[SpawnEvent]:
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
	var span := duration_for(wave) * 0.85
	for i in picked.size():
		var e := SpawnEvent.new()
		e.def = picked[i]
		e.time = 0.5 + span * (float(i) + rng.randf()) / float(picked.size())
		events.append(e)
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


static func spawn_position(arena: Rect2, player_pos: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var box := arena.grow(-EDGE_INSET)
	var corners: Array[Vector2] = [
		box.position, Vector2(box.end.x, box.position.y),
		box.end, Vector2(box.position.x, box.end.y),
	]
	for _try in 12:
		var p := Vector2.ZERO
		match rng.randi_range(0, 3):
			0: p = Vector2(rng.randf_range(box.position.x, box.end.x), box.position.y)
			1: p = Vector2(rng.randf_range(box.position.x, box.end.x), box.end.y)
			2: p = Vector2(box.position.x, rng.randf_range(box.position.y, box.end.y))
			_: p = Vector2(box.end.x, rng.randf_range(box.position.y, box.end.y))
		if p.distance_to(player_pos) >= MIN_SPAWN_DISTANCE:
			return p
	var best := corners[0]
	for c in corners:
		if c.distance_to(player_pos) > best.distance_to(player_pos):
			best = c
	return best
