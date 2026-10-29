class_name EchoInk
extends RefCounted

# A copy's wear comes from the simulation's age, not elapsed render time. The
# overlay stays readable when paused, silenced, rewinding, or effects are reduced.
const PAPER := Color("e5d8b8")
const INK := Color("292720")
const OLD_INK := Color("77755f")
const DANGER := Color("be5749")
const MAX_PIPS := 8
const MAX_CREASES := 3
const MAX_TEARS := 2


static func identity_color(identity: Color) -> Color:
	return identity.lerp(OLD_INK, 0.55).lerp(PAPER, 0.18)


static func profile(actor: EchoActor, sim: Sim, _clock: float = 0.0,
		reduced: bool = false) -> Dictionary:
	var result := {"valid": false, "visible": false, "lifespan": 1, "remaining": 0,
		"age": 0, "age_ratio": 0.0, "expiring": false, "expired": true,
		"merged": false, "muted": false, "rewinding": false, "slot": 0,
		"identity_pattern": 0, "tint": PAPER, "body_tint": PAPER,
		"alpha": 0.0, "offset_alpha": 0.0, "print_offset": Vector2.ZERO,
		"paper_scale": Vector2.ONE,
		"crease_count": 0, "tear_count": 0, "staple_count": 0, "pip_count": 0,
		"crowded": false, "reduced": reduced}
	if actor == null or actor.take == null or sim == null or not actor.pos.is_finite():
		return result
	var lifetime := maxi(1, sim.echo_lifespan())
	var age := maxi(0, actor.take.age)
	var left := maxi(0, lifetime - age)
	var wear := clampf(float(age) / float(maxi(1, lifetime - 1)), 0.0, 1.0)
	var expired := left == 0
	var muted := sim.echo_silenced > 0.0
	var crowded := sim.echoes.size() > 4
	var tint := identity_color(actor.take.tint())
	var alpha := lerpf(0.78, 0.61, wear)
	var body := PAPER.lerp(tint, 0.18 + wear * 0.12)
	if muted:
		# A closed mouth and ink seam carry silence; opacity never makes a live copy
		# disappear among other bodies merely because it cannot currently fire.
		alpha = 0.54
		body = body.lerp(OLD_INK, 0.20)
	if expired:
		alpha = 0.0
	var creases := mini(MAX_CREASES, ceili(wear * 3.0))
	var tears := mini(MAX_TEARS, floori(wear * 2.0))
	if crowded or reduced:
		creases = mini(2, creases)
		tears = mini(1, tears)
	var slot := clampi(actor.index, 0, MAX_PIPS - 1)
	result.merge({"valid": true, "visible": not expired, "lifespan": lifetime,
		"remaining": left, "age": age, "age_ratio": wear, "expiring": left == 1,
		"expired": expired, "merged": actor.take.merged, "muted": muted,
		"rewinding": actor.rewinding, "slot": slot, "identity_pattern": slot,
		"tint": tint, "body_tint": body, "alpha": alpha,
		"offset_alpha": alpha * (0.22 if reduced else 0.34),
		"print_offset": Vector2(1.4 + wear * 2.0, 0.45 if slot % 2 else -0.45),
		"paper_scale": Vector2(1.0 + wear * 0.04, 1.0 - wear * 0.07),
		"crease_count": creases, "tear_count": tears,
		"staple_count": 1 if actor.take.merged else 0,
		"pip_count": mini(MAX_PIPS, lifetime), "crowded": crowded}, true)
	return result


# Geometry is exposed so the actual drawn marks, their budgets and safe placement
# can be checked without replacing the renderer with an implementation mirror.
static func mark_geometry(bounds: Rect2, data: Dictionary) -> Dictionary:
	var result := {"creases": [], "tears": [], "staples": [], "punctures": [],
		"identity": [], "mute": [], "rewind": [], "expiry": PackedVector2Array(),
		"pip_rects": [], "pip_filled": []}
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
		staples.append(_map(PackedVector2Array([Vector2(0.29, 0.23), Vector2(0.29, 0.065),
			Vector2(0.72, 0.065), Vector2(0.72, 0.23)]), bounds))
		punctures.append(_point(Vector2(0.29, 0.23), bounds))
		punctures.append(_point(Vector2(0.72, 0.23), bounds))
	# Three physical punch positions identify the eight current slots even if two
	# palette entries repeat. These are slot marks, not a claim of permanent identity.
	var identity: Array[Dictionary] = []
	var pattern := clampi(int(data.get("identity_pattern", 0)), 0, MAX_PIPS - 1)
	for bit in 3:
		identity.append({"pos": _point(Vector2(0.17 + float(bit) * 0.075, 0.08), bounds),
			"punched": (pattern & (1 << bit)) != 0})
	var mute: Array[PackedVector2Array] = []
	if bool(data.get("muted", false)):
		mute.append(_map(PackedVector2Array([Vector2(0.66, 0.25), Vector2(0.85, 0.25)]), bounds))
		for k in 3:
			var x := 0.69 + float(k) * 0.06
			mute.append(_map(PackedVector2Array([Vector2(x - 0.015, 0.21), Vector2(x + 0.015, 0.29)]), bounds))
	var rewind: Array[PackedVector2Array] = []
	if bool(data.get("rewinding", false)):
		for index in 2:
			var x := 0.86 - float(index) * 0.09
			rewind.append(_map(PackedVector2Array([Vector2(x, 0.42), Vector2(x - 0.065, 0.47),
				Vector2(x, 0.52)]), bounds))
	var expiry := PackedVector2Array()
	if bool(data.get("expiring", false)):
		expiry = _map(PackedVector2Array([Vector2(0.22, 0.96), Vector2(0.35, 0.92),
			Vector2(0.47, 0.97), Vector2(0.59, 0.93), Vector2(0.76, 0.96)]), bounds)
	var pips: Array[Rect2] = []
	var filled: Array[bool] = []
	var count := mini(int(data.get("pip_count", 0)), mini(MAX_PIPS, floori(bounds.size.x / 3.0)))
	var meter_width := minf(30.0, bounds.size.x * 0.72)
	if count > 0:
		var step := meter_width / float(count)
		var left := bounds.get_center().x - meter_width * 0.5
		for index in count:
			pips.append(Rect2(Vector2(left + float(index) * step, bounds.end.y + 3.0),
				Vector2(maxf(0.6, step - 1.0), 2.5)))
			filled.append(float(index) / float(count) < float(data.get("remaining", 0)) / float(maxi(1, int(data.get("lifespan", 1)))))
	result.merge({"creases": creases, "tears": tears, "staples": staples,
		"punctures": punctures, "identity": identity, "mute": mute,
		"rewind": rewind, "expiry": expiry, "pip_rects": pips, "pip_filled": filled}, true)
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
		ci.draw_polyline(line, Color(PAPER, alpha), 5.0, true)
		ci.draw_polyline(line, Color(INK, alpha), 2.7, true)
	for point: Vector2 in geometry["punctures"]:
		ci.draw_circle(point, 1.7, Color(INK, alpha))
	for mark: Dictionary in geometry["identity"]:
		var point: Vector2 = mark["pos"]
		if bool(mark["punched"]):
			ci.draw_circle(point, 0.95, Color(INK, alpha * 0.9), true, -1.0, true)
		else:
			ci.draw_circle(point, 0.95, Color(INK, alpha * 0.9), false, 0.8, true)
	for line: PackedVector2Array in geometry["mute"]:
		ci.draw_polyline(line, Color(PAPER, alpha), 3.4, true)
		ci.draw_polyline(line, Color(DANGER, alpha), 1.8, true)
	for line: PackedVector2Array in geometry["rewind"]:
		ci.draw_polyline(line, Color(INK, alpha), 1.8, true)
	var expiry: PackedVector2Array = geometry["expiry"]
	if not expiry.is_empty():
		ci.draw_polyline(expiry, Color(INK, alpha), 1.8, true)
	var pips: Array = geometry["pip_rects"]
	var filled: Array = geometry["pip_filled"]
	var tint: Color = data.get("tint", PAPER)
	for index in pips.size():
		ci.draw_rect(pips[index], tint if bool(filled[index]) else Color(INK, 0.24))


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
