class_name WorldArena
extends RefCounted

const BOUNDS := Rect2(40.0, 80.0, 2400.0, 1200.0)
const VIEWPORT := Rect2(40.0, 80.0, 1200.0, 600.0)
const MACHINES: Array[Rect2] = [
	Rect2(486.0, 350.0, 148.0, 92.0),
	Rect2(872.0, 924.0, 180.0, 94.0),
	Rect2(1466.0, 312.0, 156.0, 108.0),
	Rect2(1816.0, 850.0, 192.0, 96.0),
	Rect2(2112.0, 384.0, 108.0, 124.0),
]


static func display_viewport(canvas_size: Vector2) -> Rect2:
	var size := canvas_size if canvas_size.is_finite() and canvas_size.x >= 640.0 and canvas_size.y >= 480.0 else Vector2(1280.0, 720.0)
	var compact := size.x < 1100.0 or size.y < 640.0
	var bottom := 88.0 if compact else 40.0
	return Rect2(40.0, 80.0, size.x - 80.0, size.y - 80.0 - bottom)


static func camera_rect(focus: Vector2, viewport: Rect2 = VIEWPORT) -> Rect2:
	var size := viewport.size.min(BOUNDS.size)
	var center := focus if focus.is_finite() else BOUNDS.get_center()
	var origin := (center - size * 0.5).clamp(BOUNDS.position, BOUNDS.end - size)
	return Rect2(origin, size)


static func camera_offset(focus: Vector2) -> Vector2:
	return VIEWPORT.position - camera_rect(focus).position


static func body_clear(pos: Vector2, radius: float) -> bool:
	if not pos.is_finite() or not is_finite(radius):
		return false
	var pad := maxf(0.0, radius)
	var box := BOUNDS.grow(-pad)
	if pos.x < box.position.x or pos.y < box.position.y or pos.x > box.end.x or pos.y > box.end.y:
		return false
	for machine in MACHINES:
		if machine.grow(pad).has_point(pos):
			return false
	return true


static func blocks_projectile(pos: Vector2, radius: float = 0.0) -> bool:
	if not pos.is_finite() or not is_finite(radius):
		return true
	var pad := maxf(0.0, radius)
	for machine in MACHINES:
		var nearest := pos.clamp(machine.position, machine.end)
		if pos.distance_squared_to(nearest) <= pad * pad:
			return true
	return false


# Axis sweeps stop at the first machine, including fast dashes and knockback.
# Sliding uses the same fixed geometry for the player and every enemy.
static func move_body(pos: Vector2, delta: Vector2, radius: float) -> Vector2:
	var pad := clampf(radius, 0.0, 240.0) if is_finite(radius) else 0.0
	var box := BOUNDS.grow(-pad)
	var current := pos.clamp(box.position, box.end) if pos.is_finite() else BOUNDS.get_center()
	current = _unembed(current, pad, box)
	if not delta.is_finite():
		return current
	var movement := delta.clamp(-BOUNDS.size, BOUNDS.size)
	var steps := maxi(1, ceili(movement.length() / 10.0))
	var portion := movement / float(steps)
	for _index in steps:
		current = _move_step(current, portion, pad, box)
	return current


static func _move_step(current: Vector2, delta: Vector2, pad: float, box: Rect2) -> Vector2:
	var next_x := clampf(current.x + delta.x, box.position.x, box.end.x)
	for machine in MACHINES:
		var obstacle := machine.grow(pad)
		if current.y < obstacle.position.y or current.y > obstacle.end.y:
			continue
		if delta.x > 0.0 and current.x <= obstacle.position.x and next_x >= obstacle.position.x:
			next_x = minf(next_x, obstacle.position.x - 0.01)
		elif delta.x < 0.0 and current.x >= obstacle.end.x and next_x <= obstacle.end.x:
			next_x = maxf(next_x, obstacle.end.x + 0.01)
	current.x = next_x
	var next_y := clampf(current.y + delta.y, box.position.y, box.end.y)
	for machine in MACHINES:
		var obstacle := machine.grow(pad)
		if current.x < obstacle.position.x or current.x > obstacle.end.x:
			continue
		if delta.y > 0.0 and current.y <= obstacle.position.y and next_y >= obstacle.position.y:
			next_y = minf(next_y, obstacle.position.y - 0.01)
		elif delta.y < 0.0 and current.y >= obstacle.end.y and next_y <= obstacle.end.y:
			next_y = maxf(next_y, obstacle.end.y + 0.01)
	current.y = next_y
	return current


static func move_straight(pos: Vector2, delta: Vector2, radius: float) -> Vector2:
	var origin := move_body(pos, Vector2.ZERO, radius)
	if not delta.is_finite() or delta.length_squared() <= 0.000001:
		return origin
	var pad := maxf(0.0, radius)
	var bounds := BOUNDS.grow(-pad)
	var fraction := 1.0
	for axis in 2:
		if delta[axis] > 0.0:
			fraction = minf(fraction, (bounds.end[axis] - origin[axis]) / delta[axis])
		elif delta[axis] < 0.0:
			fraction = minf(fraction, (bounds.position[axis] - origin[axis]) / delta[axis])
	for machine in MACHINES:
		fraction = minf(fraction, _entry_fraction(origin, delta, machine.grow(pad)))
	var clearance := 0.01 / delta.length() if fraction < 1.0 else 0.0
	return origin + delta * maxf(0.0, fraction - clearance)


static func _entry_fraction(origin: Vector2, delta: Vector2, obstacle: Rect2) -> float:
	var entry := 0.0
	var exit := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.000001:
			if origin[axis] < obstacle.position[axis] or origin[axis] > obstacle.end[axis]:
				return 1.0
			continue
		var near := (obstacle.position[axis] - origin[axis]) / delta[axis]
		var far := (obstacle.end[axis] - origin[axis]) / delta[axis]
		entry = maxf(entry, minf(near, far))
		exit = minf(exit, maxf(near, far))
		if entry > exit:
			return 1.0
	return entry if entry >= 0.0 and entry <= 1.0 and exit >= 0.0 else 1.0


static func _unembed(pos: Vector2, pad: float, bounds: Rect2) -> Vector2:
	for machine in MACHINES:
		var obstacle := machine.grow(pad)
		if not obstacle.has_point(pos):
			continue
		var gaps: Array[float] = [pos.x - obstacle.position.x, obstacle.end.x - pos.x,
			pos.y - obstacle.position.y, obstacle.end.y - pos.y]
		var nearest := 0
		for index in range(1, gaps.size()):
			if gaps[index] < gaps[nearest]:
				nearest = index
		match nearest:
			0: pos.x = obstacle.position.x - 0.01
			1: pos.x = obstacle.end.x + 0.01
			2: pos.y = obstacle.position.y - 0.01
			3: pos.y = obstacle.end.y + 0.01
	return pos.clamp(bounds.position, bounds.end)


# Service pads sit in front of solid cover, so interaction never requires entering it.
static func machine_sites() -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	var kinds: Array[StringName] = [&"press", &"conveyor", &"recycler", &"press", &"conveyor"]
	for index in MACHINES.size():
		var machine := MACHINES[index]
		var point := move_body(machine.get_center() + Vector2(0.0, machine.size.y * 0.5 + 60.0), Vector2.ZERO, 24.0)
		sites.append({"id": StringName("machine_%d" % index), "kind": kinds[index], "pos": point,
			"range": 112.0, "cost": 8 if kinds[index] == &"recycler" else 0, "warning": 0.0,
			"active": 4.0 if kinds[index] == &"conveyor" else 0.0, "cooldown": 0.0,
			"used": false, "direction": Vector2.RIGHT if index % 2 == 0 else Vector2.LEFT})
	return sites


# Saved workers wait beyond the production lanes; they never become targetable decoys.
static func safe_worker_position(stage: int) -> Vector2:
	return Vector2(180.0 + float(posmod(stage - 1, 6)) * 48.0, 1170.0 + float(int((stage - 1) / 6)) * 42.0)
