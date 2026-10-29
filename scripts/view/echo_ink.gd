class_name EchoInk
extends RefCounted

# A copy's wear comes from authoritative condition, never elapsed render time. The
# overlay stays readable when paused, silenced, rewinding, or effects are reduced.
const PAPER := Color("e5d8b8")
const INK := Color("292720")
const OLD_INK := Color("77755f")
const MAX_SLOTS := 8
const MAX_CREASES := 3
const MAX_TEARS := 2


static func identity_color(identity: Color) -> Color:
	return identity.lerp(OLD_INK, 0.55).lerp(PAPER, 0.18)


static func profile(actor: EchoActor, sim: Sim, _clock: float = 0.0,
		reduced: bool = false) -> Dictionary:
	var result := {"valid": false, "visible": false, "duration": 120.0, "remaining": 0.0,
		"condition": 0.0, "wear_ratio": 1.0, "expiring": false, "expired": true,
		"merged": false, "muted": false, "rewinding": false, "slot": 0,
		"identity_pattern": 0, "tint": PAPER, "body_tint": PAPER,
		"state_priority": &"expired",
		"alpha": 0.0, "offset_alpha": 0.0, "print_offset": Vector2.ZERO,
		"paper_scale": Vector2.ONE,
		"crease_count": 0, "tear_count": 0, "staple_count": 0,
		"crowded": false, "reduced": reduced}
	if actor == null or actor.take == null or sim == null or not actor.pos.is_finite():
		return result
	var duration := sim.echo_duration()
	var condition := clampf(actor.take.condition, 0.0, 100.0)
	var left := duration * condition / 100.0 / maxf(0.001, sim.wear_rate_mult)
	var wear := 1.0 - condition / 100.0
	var expired := condition <= 0.0
	var expiring := condition > 0.0 and condition <= EchoSystem.LOW_CONDITION
	var muted := sim.echo_silenced > 0.0 or EnemyBrain.echo_is_sealed(sim, actor.pos)
	var crowded := sim.echoes.size() > 4
	var tint := identity_color(actor.take.tint())
	var alpha := lerpf(0.80, 0.67, wear)
	var body := PAPER.lerp(tint, 0.18).lerp(OLD_INK, wear * 0.18)
	var state_priority: StringName = &"worn" if wear > 0.0 else &"fresh"
	if actor.take.merged:
		state_priority = &"merged"
	if expiring:
		# A whole-body value drop and compressed paper survive battlefield scale;
		# surface creases alone disappear when the same artwork is only 40px wide.
		body = body.lerp(OLD_INK, 0.34)
		alpha = 0.67
		state_priority = &"expiring"
	if muted:
		# Silence reads as a dark cancelled print, not as a disappearing body.
		# Its crossed seal is independent of the last-wave tear and binding.
		alpha = 0.76
		body = body.lerp(INK, 0.42)
		state_priority = &"muted"
	if expired:
		alpha = 0.0
		state_priority = &"expired"
	var creases := mini(MAX_CREASES, ceili(wear * 3.0))
	var tears := mini(MAX_TEARS, floori(wear * 2.0))
	if crowded or reduced:
		creases = mini(2, creases)
		tears = mini(1, tears)
	var slot := clampi(actor.index, 0, MAX_SLOTS - 1)
	result.merge({"valid": true, "visible": not expired, "duration": duration,
		"remaining": left, "condition": condition, "wear_ratio": wear, "expiring": expiring,
		"expired": expired, "merged": actor.take.merged, "muted": muted,
		"rewinding": actor.rewinding, "slot": slot, "identity_pattern": posmod(actor.take.tint_index, MAX_SLOTS),
		"tint": tint, "body_tint": body, "alpha": alpha, "state_priority": state_priority,
		"offset_alpha": alpha * (0.12 if muted else (0.20 if reduced else 0.28)),
		"print_offset": Vector2(1.4 + wear * 2.0, 0.45 if slot % 2 else -0.45),
		"paper_scale": Vector2(1.08, 0.84) if expiring else Vector2(1.0 + wear * 0.03, 1.0 - wear * 0.05),
		"crease_count": creases, "tear_count": tears,
		"staple_count": 1 if actor.take.merged else 0, "crowded": crowded}, true)
	return result


# Geometry is exposed so the actual drawn marks, their budgets and safe placement
# can be checked without replacing the renderer with an implementation mirror.
static func mark_geometry(bounds: Rect2, data: Dictionary) -> Dictionary:
	var result := {"creases": [], "tears": [], "staples": [], "punctures": [],
		"identity": [], "mute": [], "mute_contour": PackedVector2Array(),
		"rewind": [], "expiry": PackedVector2Array()}
	if not bool(data.get("visible", false)) or not _valid_bounds(bounds):
		return result
	var creases: Array[PackedVector2Array] = []
	var templates: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0.20, 0.63), Vector2(0.46, 0.66), Vector2(0.37, 0.70), Vector2(0.73, 0.73)]),
		PackedVector2Array([Vector2(0.24, 0.22), Vector2(0.48, 0.18), Vector2(0.43, 0.24), Vector2(0.68, 0.21)]),
		PackedVector2Array([Vector2(0.26, 0.82), Vector2(0.48, 0.85), Vector2(0.57, 0.80), Vector2(0.77, 0.84)]),
	]
	for index in mini(int(data.get("crease_count", 0)), MAX_CREASES):
		creases.append(_map(templates[index], bounds))
	var tears: Array[PackedVector2Array] = []
	for index in mini(int(data.get("tear_count", 0)), MAX_TEARS):
		var x := 0.15 if index == 0 else 0.74
		tears.append(_map(PackedVector2Array([Vector2(x, 0.91), Vector2(x + 0.045, 0.83),
			Vector2(x + 0.085, 0.94), Vector2(x + 0.12, 0.87)]), bounds))
	var staples: Array[PackedVector2Array] = []
	var punctures: Array[Vector2] = []
	if bool(data.get("merged", false)):
		staples.append(_map(PackedVector2Array([Vector2(0.14, 0.35), Vector2(0.14, 0.13),
			Vector2(0.84, 0.15), Vector2(0.86, 0.35)]), bounds))
		punctures.append(_point(Vector2(0.14, 0.35), bounds))
		punctures.append(_point(Vector2(0.86, 0.35), bounds))
	# Three punch positions follow the take's immutable print tint, so selecting
	# or removing another copy cannot change this copy's physical identity.
	var identity: Array[Dictionary] = []
	var pattern := clampi(int(data.get("identity_pattern", 0)), 0, MAX_SLOTS - 1)
	for bit in 3:
		identity.append({"pos": _point(Vector2(0.17 + float(bit) * 0.075, 0.08), bounds),
			"punched": (pattern & (1 << bit)) != 0})
	var mute: Array[PackedVector2Array] = []
	var mute_contour := PackedVector2Array()
	if bool(data.get("muted", false)):
		mute_contour = _map(PackedVector2Array([Vector2(0.15, 0.39), Vector2(0.08, 0.47),
			Vector2(0.12, 0.69), Vector2(0.84, 0.70), Vector2(0.92, 0.61),
			Vector2(0.88, 0.40), Vector2(0.15, 0.39)]), bounds)
		mute.append(_map(PackedVector2Array([Vector2(0.28, 0.42), Vector2(0.73, 0.67)]), bounds))
		mute.append(_map(PackedVector2Array([Vector2(0.73, 0.42), Vector2(0.28, 0.67)]), bounds))
	var rewind: Array[PackedVector2Array] = []
	if bool(data.get("rewinding", false)):
		for index in 2:
			var x := 0.86 - float(index) * 0.09
			rewind.append(_map(PackedVector2Array([Vector2(x, 0.42), Vector2(x - 0.065, 0.47),
				Vector2(x, 0.52)]), bounds))
	var expiry := PackedVector2Array()
	if bool(data.get("expiring", false)):
		expiry = _map(PackedVector2Array([Vector2(0.08, 0.77), Vector2(0.13, 0.95),
			Vector2(0.27, 0.78), Vector2(0.40, 0.96), Vector2(0.54, 0.77),
			Vector2(0.69, 0.95), Vector2(0.81, 0.78), Vector2(0.92, 0.91)]), bounds)
	result.merge({"creases": creases, "tears": tears, "staples": staples,
		"punctures": punctures, "identity": identity, "mute": mute, "mute_contour": mute_contour,
		"rewind": rewind, "expiry": expiry}, true)
	return result


static func draw_marks(ci: CanvasItem, _actor: EchoActor, art_bounds: Rect2,
		data: Dictionary, reduced: bool = false) -> void:
	if ci == null:
		return
	var geometry := mark_geometry(art_bounds, data)
	var alpha := float(data.get("alpha", 0.0))
	if alpha <= 0.0:
		return
	var ink := Color(INK, alpha * 0.80)
	var width := 1.15 if reduced else 1.35
	for line: PackedVector2Array in geometry["creases"]:
		ci.draw_polyline(line, Color(PAPER, alpha * 0.7), width + 1.5, true)
		ci.draw_polyline(line, ink, width, true)
	for line: PackedVector2Array in geometry["tears"]:
		ci.draw_polyline(line, ink, width + 0.3, true)
	for line: PackedVector2Array in geometry["staples"]:
		ci.draw_polyline(line, Color(PAPER, 0.90), 6.5, true)
		ci.draw_polyline(line, Color(INK, 0.90), 3.0, true)
	for point: Vector2 in geometry["punctures"]:
		ci.draw_circle(point, 2.0, Color(INK, 0.90))
	for mark: Dictionary in geometry["identity"]:
		var point: Vector2 = mark["pos"]
		if bool(mark["punched"]):
			ci.draw_circle(point, 0.95, Color(INK, alpha * 0.9), true, -1.0, true)
		else:
			ci.draw_circle(point, 0.95, Color(INK, alpha * 0.9), false, 0.8, true)
	var mute_contour: PackedVector2Array = geometry["mute_contour"]
	if not mute_contour.is_empty():
		ci.draw_polyline(mute_contour, Color(PAPER, 0.78), 5.0, true)
		ci.draw_polyline(mute_contour, Color(INK, 0.92), 2.7, true)
	for line: PackedVector2Array in geometry["mute"]:
		ci.draw_polyline(line, Color(PAPER, 0.78), 5.0, true)
		ci.draw_polyline(line, Color(INK, 0.92), 2.7, true)
	for line: PackedVector2Array in geometry["rewind"]:
		ci.draw_polyline(line, Color(INK, alpha), 1.8, true)
	var expiry: PackedVector2Array = geometry["expiry"]
	if not expiry.is_empty():
		ci.draw_polyline(expiry, Color(PAPER, 0.83), 5.7, true)
		ci.draw_polyline(expiry, Color(INK, 0.93), 2.9, true)


static func _valid_bounds(bounds: Rect2) -> bool:
	return bounds.position.is_finite() and bounds.size.is_finite() \
		and bounds.end.is_finite() and bounds.size.x >= 4.0 and bounds.size.y >= 4.0


static func _point(unit: Vector2, bounds: Rect2) -> Vector2:
	return bounds.position + unit * bounds.size


static func _map(points: PackedVector2Array, bounds: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(_point(point, bounds))
	return result
