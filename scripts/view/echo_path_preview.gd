class_name EchoPathPreview
extends RefCounted

const HORIZON := 2.0
const MAX_ACTORS := 8
const MAX_PHYSICS_STEPS := 240
const MAX_ROUTE_POINTS := 128
const MAX_DRAW_SEGMENTS := 192
const MAX_DASHES := 24
const PAPER := Color("d4cbb3")
const EPSILON := 0.000001


# A forecast of the current playback rule, never a route command. The start is
# the actor's authoritative foot; the caller draws this beneath threat ink and
# inside the battle viewport. Colors and cut lengths have no render-time clock.
static func snapshot(actor: EchoActor, sim: Sim, clip_rect: Rect2,
		selected: bool = false, _reduced: bool = false) -> Dictionary:
	var data := {"valid": false, "uid": 0, "selected": selected,
		"start": Vector2.ZERO, "start_visible": false, "start_color": Color.TRANSPARENT,
		"centerline": PackedVector2Array(), "times": PackedFloat64Array(),
		"breaks": PackedInt32Array(), "segments": PackedVector2Array(),
		"colors": PackedColorArray(), "width": 1.0, "horizon": 0.0}
	if actor == null or actor.take == null or sim == null or sim.phase != Sim.Phase.WAVE \
			or not actor.pos.is_finite() or not is_finite(actor.t) or actor.t < 0.0 \
			or actor.take.samples.is_empty() or not is_finite(actor.take.condition) \
			or actor.take.condition <= 0.0 or not _valid_rect(clip_rect):
		return data
	var hold := float(sim.role_effects.get("anchor_left", 0.0)) \
			if int(sim.role_effects.get("anchor_uid", 0)) == actor.take.uid else 0.0
	if not is_finite(hold):
		return data
	var horizon := HORIZON
	var wear := maxf(0.0, sim.wear_rate_mult) * 100.0 / sim.echo_duration()
	if not is_finite(wear):
		return data
	if wear > 0.0:
		horizon = minf(horizon, actor.take.condition / wear)
	var physics_delta := Engine.time_scale / float(maxi(1, Engine.physics_ticks_per_second))
	if not is_finite(physics_delta) or physics_delta <= 0.0:
		return data
	# The limit bounds unusual engine tick rates as well as the normal 60 Hz game.
	# We shorten the horizon rather than inventing unprocessed future movement.
	horizon = minf(horizon, physics_delta * float(MAX_PHYSICS_STEPS))
	var route := _route(actor, horizon, maxf(0.0, hold), physics_delta)
	if not bool(route["valid"]):
		return data
	var crowded := sim.echoes.size() > 4
	var alpha := (0.34 if crowded else 0.46) if selected else (0.14 if crowded else 0.22)
	# A short ping-pong tape may revisit the same floor dozens of times in two
	# seconds. Cap its aggregate ink, rather than letting translucent visits pile
	# up into an opaque route merely because the recording is short.
	alpha /= float(route["traversals"])
	var width := 1.65 if selected else 1.10
	var color := PAPER.lerp(EchoInk.identity_color(actor.take.tint()), 0.22)
	var safe := clip_rect.grow(-width * 0.5 - 0.35)
	var dashes := _dashes(route, safe, color, alpha, crowded, actor.take.uid)
	data.merge({"valid": true, "uid": actor.take.uid, "start": actor.pos,
		"start_visible": clip_rect.grow(-4.0).has_point(actor.pos),
		"start_color": Color(color, 0.76 if selected else 0.48),
		"centerline": route["points"], "times": route["times"], "breaks": route["breaks"],
		"segments": dashes["segments"], "colors": dashes["colors"],
		"width": width, "horizon": route["horizon"]}, true)
	# Reduced uses the same static ink. It does not conceal a future turn or hold.
	return data


static func draw(ci: CanvasItem, data: Dictionary) -> void:
	if ci == null or not bool(data.get("valid", false)):
		return
	var segments: PackedVector2Array = data["segments"]
	if not segments.is_empty():
		ci.draw_multiline_colors(segments, data["colors"], float(data["width"]), true)
	if bool(data["start_visible"]):
		var start: Vector2 = data["start"]
		# A small cut-paper diamond sits on the floor, not a danger-radius ring.
		ci.draw_colored_polygon(PackedVector2Array([start + Vector2(-3.0, 0.0),
			start + Vector2(0.0, -2.0), start + Vector2(3.0, 0.0),
			start + Vector2(0.0, 3.0)]), data["start_color"])


static func _route(actor: EchoActor, horizon: float, hold: float, delta: float) -> Dictionary:
	var points := PackedVector2Array([actor.pos])
	var times := PackedFloat64Array([0.0])
	var breaks := PackedInt32Array()
	var clock := actor.t
	var elapsed := 0.0
	# Mirror's held swap can put the foot away from its recorded route. Its
	# eventual snap back is a discontinuity, never a dotted walk across the room.
	var detached := actor.pos.distance_squared_to(actor.take.position_at(clock)) > 0.0001
	for _step in MAX_PHYSICS_STEPS:
		if elapsed >= horizon - EPSILON:
			break
		var dt := minf(delta, horizon - elapsed)
		hold = maxf(0.0, hold - dt)
		var next := clock + dt if hold <= 0.0 else clock
		if next > clock:
			if detached:
				breaks.append(points.size())
				var position := actor.take.position_at(next)
				if not position.is_finite():
					return {"valid": false}
				_append(points, times, position, elapsed + dt, breaks)
				detached = false
			else:
				# Include every recorded vertex and ping-pong cusp between physics
				# samples, so the forecast cannot cut across a sharp recorded turn.
				var vertex: float = (floor(clock / EchoTake.SAMPLE_DT) + 1.0) * EchoTake.SAMPLE_DT
				for _vertex in MAX_ROUTE_POINTS:
					if vertex > next + EPSILON:
						break
					var position := actor.take.position_at(minf(vertex, next))
					if not position.is_finite():
						return {"valid": false}
					_append(points, times, position, elapsed + minf(vertex - clock, dt), breaks)
					vertex += EchoTake.SAMPLE_DT
				var position := actor.take.position_at(next)
				if not position.is_finite():
					return {"valid": false}
				_append(points, times, position, elapsed + dt, breaks)
		else:
			_append(points, times, points[points.size() - 1], elapsed + dt, breaks)
		clock = next
		elapsed += dt
		if points.size() >= MAX_ROUTE_POINTS:
			break
	var duration := actor.take.duration()
	var traversals := maxi(1, floori(clock / duration) - floori(actor.t / duration) + 1) \
			if duration > 0.0 else 1
	return {"valid": true, "points": points, "times": times, "breaks": breaks,
		"horizon": times[times.size() - 1], "traversals": traversals}


static func _append(points: PackedVector2Array, times: PackedFloat64Array,
		point: Vector2, time: float, breaks: PackedInt32Array) -> void:
	if points.size() >= MAX_ROUTE_POINTS:
		return
	var last := points.size() - 1
	if time <= times[last] + EPSILON:
		return
	# Collapse only constant-velocity samples. Corners, speed changes, holds and
	# discontinuities keep their actual time and location.
	if last >= 1 and not breaks.has(last) and not breaks.has(last + 1):
		var span := time - times[last - 1]
		var fraction := (times[last] - times[last - 1]) / span
		if points[last].distance_squared_to(points[last - 1].lerp(point, fraction)) < 0.000001:
			points.remove_at(last)
			times.remove_at(last)
	points.append(point)
	times.append(time)


static func _dashes(route: Dictionary, clip: Rect2, color: Color, alpha: float,
		crowded: bool, uid: int) -> Dictionary:
	var segments := PackedVector2Array()
	var colors := PackedColorArray()
	var points: PackedVector2Array = route["points"]
	var times: PackedFloat64Array = route["times"]
	var breaks: PackedInt32Array = route["breaks"]
	var total := 0.0
	for index in range(1, points.size()):
		if not breaks.has(index):
			total += points[index - 1].distance_to(points[index])
	var dash_count := 16 if crowded else MAX_DASHES
	var unit := maxf(15.0, total / float(dash_count))
	var traveled := 0.0
	var cut := 0
	var cycle_start := 0.0
	var cycle_end := unit * _cut_fraction(uid, cut)
	for index in range(1, points.size()):
		if breaks.has(index):
			continue
		var from := points[index - 1]
		var to := points[index]
		var length := from.distance_to(to)
		if length <= EPSILON:
			continue
		var finish := traveled + length
		for _piece in MAX_DASHES + 2:
			if cycle_start >= finish - EPSILON:
				break
			var a := maxf(traveled, cycle_start)
			var b := minf(finish, cycle_end)
			if b > a + EPSILON and colors.size() < MAX_DRAW_SEGMENTS:
				var start_fraction := (a - traveled) / length
				var end_fraction := (b - traveled) / length
				var clipped := _clip_segment(from.lerp(to, start_fraction), from.lerp(to, end_fraction), clip)
				if not clipped.is_empty():
					var future := lerpf(times[index - 1], times[index], (start_fraction + end_fraction) * 0.5)
					var fade := maxf(0.0, 1.0 - future / maxf(EPSILON, float(route["horizon"])))
					segments.append_array(clipped)
					colors.append(Color(color, alpha * fade))
			if cycle_end >= finish - EPSILON:
				break
			cut += 1
			cycle_start = float(cut) * unit
			cycle_end = cycle_start + unit * _cut_fraction(uid, cut)
		traveled = finish
	return {"segments": segments, "colors": colors}


static func _cut_fraction(uid: int, index: int) -> float:
	# Unequal scissor cuts stay deterministic and on the true route centerline.
	return 0.48 + float(posmod(posmod(uid, 7) + index * 3, 7)) * 0.018


static func _clip_segment(from: Vector2, to: Vector2, clip: Rect2) -> PackedVector2Array:
	var direction := to - from
	var near := 0.0
	var far := 1.0
	for axis in 2:
		if absf(direction[axis]) <= EPSILON:
			if from[axis] < clip.position[axis] or from[axis] > clip.end[axis]:
				return PackedVector2Array()
			continue
		var enter := (clip.position[axis] - from[axis]) / direction[axis]
		var leave := (clip.end[axis] - from[axis]) / direction[axis]
		near = maxf(near, minf(enter, leave))
		far = minf(far, maxf(enter, leave))
		if near >= far:
			return PackedVector2Array()
	return PackedVector2Array([from + direction * near, from + direction * far])


static func _valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() \
		and rect.size.x > 8.0 and rect.size.y > 8.0
