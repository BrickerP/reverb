class_name WeaponInk
extends RefCounted

# One small GPU batch per real weapon identity. Unknown developer projectiles share
# a neutral ink head; they never allocate an unbounded collection of textures.
const INK := Color("292720")
const PAPER := Color("e5d8b8")
const GOLD := Color("edc66d")
const TRAIL_LIMIT := 160
const MAX_MUZZLE_MARKS := 32
const MAX_HIT_MARKS := 48
const MAX_BLAST_MARKS := 12
const IDS: Array[StringName] = [&"pistol", &"smg", &"shotgun", &"rifle", &"orb",
	&"flechette", &"longbow", &"hex_bolt", &"twin_fangs", &"flak_crown", &"rail_spike", &"nova_core"]

static var _batches: Dictionary = {}
static var _last_render: Dictionary = {"projectiles": 0, "groups": 0, "draw_calls": 0, "trails": 0}
static var _last_feedback: Dictionary = {"muzzles": 0, "hits": 0, "blasts": 0}


static func profile(id: StringName) -> Dictionary:
	var result := {"weapon_id": id, "style": &"sidearm", "color": Color("c5a14d"),
		"length": 12.0, "recoil": 4.0, "evolved": false, "glyph": &"ink",
		"muzzle": &"ink", "impact": &"ink"}
	match id:
		&"pistol":
			result.merge({"glyph": &"staple", "muzzle": &"staple", "impact": &"stitch"}, true)
		&"smg":
			result.merge({"color": Color("82935e"), "length": 9.0, "recoil": 2.5,
				"glyph": &"chad", "muzzle": &"punch", "impact": &"punch"}, true)
		&"shotgun":
			result.merge({"style": &"scatter", "color": Color("c78346"), "length": 15.0,
				"recoil": 6.0, "glyph": &"tape", "muzzle": &"tape", "impact": &"tape"}, true)
		&"rifle":
			result.merge({"style": &"marksman", "color": Color("be5749"), "length": 23.0,
				"recoil": 5.0, "glyph": &"nail", "muzzle": &"nail", "impact": &"nail"}, true)
		&"orb":
			result.merge({"style": &"arcane", "color": Color("8f7a95"), "recoil": 3.0,
				"glyph": &"spool", "muzzle": &"spool", "impact": &"spool"}, true)
		&"flechette":
			result.merge({"style": &"scatter", "color": Color("c78346"), "length": 17.0,
				"recoil": 4.5, "glyph": &"dart", "muzzle": &"fold", "impact": &"fold"}, true)
		&"longbow":
			result.merge({"style": &"marksman", "color": Color("be5749"), "length": 27.0,
				"recoil": 5.5, "glyph": &"ruler", "muzzle": &"ruler", "impact": &"ruler"}, true)
		&"hex_bolt":
			result.merge({"style": &"arcane", "color": Color("8f7a95"), "length": 15.0,
				"recoil": 3.0, "glyph": &"seal", "muzzle": &"seal", "impact": &"seal"}, true)
		&"twin_fangs":
			result.merge({"length": 14.0, "recoil": 3.5, "evolved": true,
				"glyph": &"twin", "muzzle": &"twin", "impact": &"twin"}, true)
		&"flak_crown":
			result.merge({"style": &"scatter", "color": Color("c78346"), "length": 19.0,
				"recoil": 7.0, "evolved": true, "glyph": &"crown", "muzzle": &"crown", "impact": &"crown"}, true)
		&"rail_spike":
			result.merge({"style": &"marksman", "color": Color("be5749"), "length": 31.0,
				"recoil": 7.0, "evolved": true, "glyph": &"barb", "muzzle": &"barb", "impact": &"barb"}, true)
		&"nova_core":
			result.merge({"style": &"arcane", "color": Color("8f7a95"), "length": 18.0,
				"recoil": 4.0, "evolved": true, "glyph": &"nova", "muzzle": &"nova", "impact": &"nova"}, true)
	return result


# All silhouettes fit in the actual collision disc. The sprite is never stretched
# into a fictitious piercing beam or a larger damaging area.
static func glyph_outline(id: StringName) -> PackedVector2Array:
	match id:
		&"pistol":
			return PackedVector2Array([Vector2(-0.65, -0.65), Vector2(0.55, -0.65), Vector2(0.55, -0.25), Vector2(-0.2, -0.25), Vector2(-0.2, 0.25), Vector2(0.55, 0.25), Vector2(0.55, 0.65), Vector2(-0.65, 0.65)])
		&"smg":
			return PackedVector2Array([Vector2(-0.6, -0.6), Vector2(0.45, -0.6), Vector2(0.75, -0.3), Vector2(0.75, 0.3), Vector2(0.45, 0.6), Vector2(-0.6, 0.6), Vector2(-0.75, 0.3), Vector2(-0.75, -0.3)])
		&"shotgun":
			return PackedVector2Array([Vector2(-0.75, -0.4), Vector2(0.56, -0.5), Vector2(0.82, -0.17), Vector2(0.65, 0.49), Vector2(-0.68, 0.4), Vector2(-0.84, 0.08)])
		&"rifle":
			return PackedVector2Array([Vector2(0.95, 0), Vector2(-0.55, 0.18), Vector2(-0.55, 0.4), Vector2(-0.85, 0.4), Vector2(-0.85, -0.4), Vector2(-0.55, -0.4), Vector2(-0.55, -0.18)])
		&"flechette":
			return PackedVector2Array([Vector2(0.94, 0), Vector2(-0.68, 0.62), Vector2(-0.42, 0), Vector2(-0.68, -0.62)])
		&"longbow":
			return PackedVector2Array([Vector2(0.94, 0), Vector2(0.22, 0.5), Vector2(0.2, 0.16), Vector2(-0.9, 0.16), Vector2(-0.9, -0.16), Vector2(0.2, -0.16), Vector2(0.22, -0.5)])
		&"hex_bolt":
			return PackedVector2Array([Vector2(0.95, 0), Vector2(0.32, 0.28), Vector2(0.1, 0.9), Vector2(-0.28, 0.32), Vector2(-0.9, 0), Vector2(-0.32, -0.28), Vector2(-0.08, -0.9), Vector2(0.28, -0.32)])
		&"twin_fangs":
			return PackedVector2Array([Vector2(-0.7, -0.57), Vector2(0.6, -0.57), Vector2(0.6, -0.33), Vector2(-0.24, -0.33), Vector2(-0.24, -0.12), Vector2(0.4, -0.12), Vector2(0.4, 0.12), Vector2(-0.24, 0.12), Vector2(-0.24, 0.33), Vector2(0.6, 0.33), Vector2(0.6, 0.57), Vector2(-0.7, 0.57)])
		&"flak_crown":
			return PackedVector2Array([Vector2(-0.8, -0.25), Vector2(-0.45, -0.66), Vector2(-0.1, -0.1), Vector2(0.15, -0.82), Vector2(0.4, -0.18), Vector2(0.75, -0.5), Vector2(0.58, 0.68), Vector2(-0.63, 0.68)])
		&"rail_spike":
			return PackedVector2Array([Vector2(0.96, 0), Vector2(0.25, 0.2), Vector2(0.25, 0.48), Vector2(-0.1, 0.3), Vector2(-0.1, 0.15), Vector2(-0.88, 0.15), Vector2(-0.88, -0.15), Vector2(-0.1, -0.15), Vector2(-0.1, -0.3), Vector2(0.25, -0.48), Vector2(0.25, -0.2)])
	var points := PackedVector2Array()
	var count := 20 if id == &"orb" else (18 if id == &"nova_core" else 12)
	for index in count:
		var radius := 0.88
		if id == &"nova_core" and index % 3 == 1:
			radius = 0.68
		points.append(Vector2.from_angle(TAU * float(index) / float(count)) * radius)
	return points


static func glyph_svg(id: StringName) -> String:
	var points := glyph_outline(id)
	var outer: Array[String] = []
	var inner: Array[String] = []
	for point in points:
		outer.append("%.3f,%.3f" % [16.0 + point.x * 15.0, 16.0 + point.y * 15.0])
		inner.append("%.3f,%.3f" % [16.0 + point.x * 11.5, 16.0 + point.y * 11.5])
	var detail := ""
	match id:
		&"smg": detail = '<circle cx="15" cy="16" r="3" fill="#292720"/>'
		&"shotgun": detail = '<path d="M13 11L12 21M19 10L18 22" fill="none" stroke="#292720" stroke-width="2"/>'
		&"orb": detail = '<circle cx="16" cy="16" r="7" fill="#292720"/><path d="M13 13C21 11 22 20 15 20" fill="none" stroke="white" stroke-width="2"/>'
		&"longbow": detail = '<path d="M6 13V18M10 13V17M14 13V18" fill="none" stroke="#292720" stroke-width="1.3"/>'
		&"hex_bolt": detail = '<path d="M12 12L20 20M20 12L12 20" stroke="#292720" stroke-width="2.2"/>'
		&"rail_spike": detail = '<path d="M8 14H19M8 18H19" stroke="#292720" stroke-width="1.3"/>'
		&"nova_core": detail = '<path d="M10 17C9 8 25 7 24 17C23 25 10 24 13 15C15 10 21 13 18 18" fill="none" stroke="#292720" stroke-width="2.1"/>'
	return '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><circle cx="16" cy="16" r="15" fill="white" opacity="0.12"/><polygon points="%s" fill="#292720"/><polygon points="%s" fill="white"/>%s</svg>' % [" ".join(outer), " ".join(inner), detail]


static func projectile_color(projectile: Projectile) -> Color:
	return GOLD if projectile.crit else projectile.color.lerp(PAPER, 0.42).lerp(INK, 0.12)


static func trails_enabled(reduced: bool, count: int) -> bool:
	return not reduced and count <= TRAIL_LIMIT


static func valid_projectile(projectile: Projectile) -> bool:
	return projectile != null and not projectile.dead and projectile.pos.is_finite() \
		and projectile.vel.is_finite() and is_finite(projectile.radius) and projectile.radius > 0.0


static func flight_transform(position: Vector2, velocity: Vector2, radius: float) -> Transform2D:
	if not position.is_finite() or not velocity.is_finite() or not is_finite(radius) or radius <= 0.0:
		return Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var direction := velocity.normalized() if velocity.length_squared() > 0.000001 else Vector2.RIGHT
	return Transform2D(direction * radius, Vector2(-direction.y, direction.x) * radius, position)


static func _batch_key(id: StringName) -> StringName:
	return id if IDS.has(id) else &""


static func _batch(id: StringName, count: int) -> Dictionary:
	if not _batches.has(id):
		var image := Image.new()
		if image.load_svg_from_string(glyph_svg(id)) != OK:
			push_error("WeaponInk could not build its projectile glyph: %s" % id)
			return {}
		image.generate_mipmaps()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_2D
		mesh.use_colors = true
		mesh.mesh = quad
		_batches[id] = {"mesh": mesh, "texture": ImageTexture.create_from_image(image), "capacity": 0}
	var batch: Dictionary = _batches[id]
	if count > int(batch["capacity"]):
		var capacity := ceili(float(count) / 64.0) * 64
		(batch["mesh"] as MultiMesh).instance_count = capacity
		batch["capacity"] = capacity
	return batch


static func draw_projectiles(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	for stored: Dictionary in _batches.values():
		(stored["mesh"] as MultiMesh).visible_instance_count = 0
	_last_render = {"projectiles": 0, "groups": 0, "draw_calls": 0, "trails": 0}
	if ci == null or sim == null:
		return
	var counts: Dictionary = {}
	for projectile in sim.projectiles:
		if valid_projectile(projectile):
			var key := _batch_key(projectile.weapon_id)
			counts[key] = int(counts.get(key, 0)) + 1
	var active: Dictionary = {}
	for key: StringName in counts:
		var batch := _batch(key, int(counts[key]))
		if not batch.is_empty():
			(batch["mesh"] as MultiMesh).visible_instance_count = int(counts[key])
			active[key] = batch
	var used: Dictionary = {}
	var trails := trails_enabled(reduced, sim.projectiles.size())
	for projectile in sim.projectiles:
		if not valid_projectile(projectile):
			continue
		var key := _batch_key(projectile.weapon_id)
		if not active.has(key):
			continue
		var mesh := (active[key] as Dictionary)["mesh"] as MultiMesh
		var index := int(used.get(key, 0))
		mesh.set_instance_transform_2d(index, flight_transform(projectile.pos, projectile.vel, projectile.radius))
		var color := projectile_color(projectile)
		mesh.set_instance_color(index, color)
		used[key] = index + 1
		_last_render["projectiles"] = int(_last_render["projectiles"]) + 1
		if trails:
			var direction := projectile.vel.normalized()
			if direction != Vector2.ZERO:
				ci.draw_line(projectile.pos - direction * (projectile.radius * 2.0 + 5.0), projectile.pos,
						Color(color, 0.22), maxf(1.0, projectile.radius * 0.55), true)
				_last_render["trails"] = int(_last_render["trails"]) + 1
	for key: StringName in active:
		var batch: Dictionary = active[key]
		ci.draw_multimesh(batch["mesh"] as MultiMesh, batch["texture"] as Texture2D)
	_last_render["groups"] = active.size()
	_last_render["draw_calls"] = active.size()


static func render_stats() -> Dictionary:
	return _last_render.duplicate(true)


static func owns_explosion(data: Dictionary) -> bool:
	return data.get("kind", ExplosionInfo.WEAPON) == ExplosionInfo.WEAPON \
		and data.get("effect", &"explosion") not in [&"echo_collapse", &"shield_break"]


static func feedback_stats() -> Dictionary:
	return _last_feedback.duplicate(true)


static func _life(data: Dictionary) -> float:
	var maximum := float(data.get("max_life", 0.0))
	if maximum <= 0.0 or not is_finite(maximum):
		return 0.0
	var life := float(data.get("life", 0.0))
	return clampf(life / maximum, 0.0, 1.0) if is_finite(life) else 0.0


static func draw_feedback(ci: CanvasItem, muzzles: Array[Dictionary], hits: Array[Dictionary],
		explosions: Array[Dictionary], reduced: bool = false) -> void:
	_last_feedback = {"muzzles": 0, "hits": 0, "blasts": 0}
	if ci == null:
		return
	var muzzle_limit := 10 if reduced else MAX_MUZZLE_MARKS
	var hit_limit := 16 if reduced else MAX_HIT_MARKS
	for index in range(maxi(0, muzzles.size() - muzzle_limit), muzzles.size()):
		var data: Dictionary = muzzles[index]
		var t := _life(data)
		if t <= 0.02:
			continue
		var p: Dictionary = data.get("profile", {})
		if p.is_empty():
			p = profile(StringName(data.get("weapon_id", &"")))
		var direction: Vector2 = data.get("direction", Vector2.RIGHT)
		if not direction.is_finite() or direction.length_squared() < 0.000001:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		if not pos.is_finite():
			continue
		var length := float(p["length"]) * (1.0 + 0.06 * clampi(int(data.get("level", 0)), 0, WeaponDef.MAX_LEVEL))
		_draw_muzzle(ci, pos, direction, p, length * (0.65 if reduced else 1.0), t, reduced)
		_last_feedback["muzzles"] = int(_last_feedback["muzzles"]) + 1
	for index in range(maxi(0, hits.size() - hit_limit), hits.size()):
		var data: Dictionary = hits[index]
		var t := _life(data)
		if t <= 0.02:
			continue
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		if not pos.is_finite():
			continue
		var direction: Vector2 = data.get("direction", Vector2.ZERO)
		if not direction.is_finite():
			direction = Vector2.ZERO
		_draw_hit(ci, pos, direction.normalized(), profile(StringName(data.get("weapon_id", &""))),
				t, bool(data.get("crit", false)), bool(data.get("reduced", false)), reduced)
		_last_feedback["hits"] = int(_last_feedback["hits"]) + 1
	for index in range(maxi(0, explosions.size() - MAX_BLAST_MARKS), explosions.size()):
		var data: Dictionary = explosions[index]
		if owns_explosion(data) and _draw_blast(ci, data, reduced):
			_last_feedback["blasts"] = int(_last_feedback["blasts"]) + 1


static func _polyline(ci: CanvasItem, center: Vector2, direction: Vector2,
		points: PackedVector2Array, scale: float, color: Color, width: float = 2.0) -> void:
	if scale < 0.75 or not is_finite(scale) or color.a <= 0.01:
		return
	var normal := Vector2(-direction.y, direction.x)
	var absolute := PackedVector2Array()
	for point in points:
		absolute.append(center + (direction * point.x + normal * point.y) * scale)
	ci.draw_polyline(absolute, color, width, true)


static func _draw_muzzle(ci: CanvasItem, pos: Vector2, direction: Vector2, p: Dictionary,
		length: float, t: float, reduced: bool) -> void:
	var color := Color(p["color"], t * 0.85)
	var small := maxf(1.0, length * 0.36 * t)
	var normal := Vector2(-direction.y, direction.x)
	match p["muzzle"]:
		&"staple", &"twin":
			var marks := 2 if p["muzzle"] == &"twin" else 1
			for index in marks:
				var offset := (float(index) - float(marks - 1) * 0.5) * 5.0
				_polyline(ci, pos + normal * offset, direction,
					PackedVector2Array([Vector2(0.4, -0.65), Vector2(-0.5, -0.65), Vector2(-0.5, 0.65), Vector2(0.4, 0.65)]), small, color)
		&"punch":
			ci.draw_circle(pos, 2.0 + t * 2.0, Color(PAPER, t))
			ci.draw_arc(pos, 2.0 + t * 2.0, 0.0, TAU, 12, color, 1.4, true)
			ci.draw_line(pos + normal * 5.0, pos + normal * 5.0 + direction * (length * t), color, 1.5, true)
		&"tape":
			for side: float in [-1.0, 1.0]:
				_polyline(ci, pos, direction,
					PackedVector2Array([Vector2(-0.4, side * 0.8), Vector2(0.4, side * 0.8), Vector2(1.0, side * 0.35)]), small * 1.4, color, 2.7)
		&"nail", &"barb", &"ruler":
			ci.draw_line(pos - direction * (length * 0.35 * t), pos + direction * (length * t), color, 2.0, true)
			var ticks := 3 if p["muzzle"] == &"ruler" else (2 if p["muzzle"] == &"barb" else 1)
			for index in ticks:
				var anchor := pos + direction * (float(index) * 4.0 - 3.0)
				ci.draw_line(anchor - normal * 3.0, anchor + normal * 3.0, color, 1.5, true)
		&"fold":
			_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.7, -0.9), Vector2(0.6, 0), Vector2(-0.7, 0.9)]), small * 1.3, color)
		&"seal":
			_polyline(ci, pos, direction, PackedVector2Array([Vector2(0.8, 0), Vector2(0, 0.65), Vector2(-0.8, 0), Vector2(0, -0.65), Vector2(0.8, 0)]), small, color)
		&"crown":
			_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.7, -0.7), Vector2(0.2, -0.3), Vector2(-0.1, 0), Vector2(0.8, 0.3), Vector2(0, 0.6)]), small * 1.5, color, 2.4)
		&"spool", &"nova":
			var radius := minf(9.0, small)
			ci.draw_arc(pos, radius, direction.angle() - 2.1, direction.angle() + 2.1, 14, color, 2.0, true)
			if p["muzzle"] == &"nova" and not reduced:
				ci.draw_arc(pos, radius * 0.5, direction.angle(), direction.angle() + PI * 1.4, 10, Color(PAPER, t), 1.7, true)
		_:
			ci.draw_line(pos - normal * small * 0.5, pos + normal * small * 0.5, color, 1.5, true)
	# A short reverse stroke acknowledges recoil without assigning a duplicate slot.
	ci.draw_line(pos - direction * 8.0, pos - direction * (8.0 + float(p["recoil"]) * t), Color(INK, t * 0.7), 2.0, true)


static func _draw_hit(ci: CanvasItem, pos: Vector2, direction: Vector2, p: Dictionary,
		t: float, crit: bool, shielded: bool, reduced: bool) -> void:
	var color := Color(GOLD if crit else PAPER, t)
	var size := (8.0 if crit else 5.0) * t
	if direction == Vector2.ZERO:
		ci.draw_arc(pos, maxf(0.75, size * 0.7), 0.0, TAU, 12, color, 1.5, true)
	else:
		match p["impact"]:
			&"stitch", &"twin":
				var count := 2 if p["impact"] == &"twin" else 1
				var normal := Vector2(-direction.y, direction.x)
				for index in count:
					_polyline(ci, pos + normal * (float(index) - 0.5 * (count - 1)) * 4.0, direction,
						PackedVector2Array([Vector2(-0.8, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.8, 0.5)]), size, color)
			&"punch":
				ci.draw_circle(pos, maxf(0.75, size), Color(INK, t))
				ci.draw_arc(pos, maxf(0.75, size), 0.0, TAU, 12, color, 1.7, true)
			&"tape":
				_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.7, -0.6), Vector2(0.5, -0.4), Vector2(0.7, 0.5), Vector2(-0.5, 0.6)]), size, color, 2.5)
			&"nail", &"barb", &"ruler":
				ci.draw_line(pos - direction * (size * 1.5), pos + direction * size * 0.35, color, 2.2, true)
				var normal := Vector2(-direction.y, direction.x)
				ci.draw_line(pos - direction * size - normal * size * 0.55, pos - direction * size + normal * size * 0.55, color, 1.7, true)
				if p["impact"] == &"barb":
					_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.1, -0.7), Vector2(0.2, 0), Vector2(-0.1, 0.7)]), size, Color(p["color"], t), 1.5)
				elif p["impact"] == &"ruler":
					ci.draw_line(pos + normal * size, pos - direction * size * 0.65 + normal * size, color, 1.4, true)
			&"fold", &"crown":
				_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.1, -0.2), Vector2(-0.2, 0.1), Vector2(0.6, 0.7)]), size, color, 2.1)
				if p["impact"] == &"crown" and not reduced:
					_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.8, 0.8), Vector2(0.2, 0), Vector2(0.6, -0.7)]), size, color, 1.6)
			&"seal":
				_polyline(ci, pos, direction, PackedVector2Array([Vector2(-0.7, 0), Vector2(0, -0.7), Vector2(0.7, 0), Vector2(0, 0.7), Vector2(-0.7, 0)]), size, color, 2.0)
			&"spool", &"nova":
				ci.draw_arc(pos, maxf(0.75, size), direction.angle() - PI * 0.75, direction.angle() + PI * 0.75, 12, color, 1.8, true)
				if p["impact"] == &"nova" and not reduced:
					ci.draw_arc(pos, maxf(0.75, size * 0.5), direction.angle(), direction.angle() + PI, 8, Color(p["color"], t), 1.5, true)
			_:
				ci.draw_line(pos - direction * size, pos + direction * size, color, 1.5, true)
	if shielded:
		var angle := direction.angle() if direction != Vector2.ZERO else 0.0
		ci.draw_arc(pos, 10.0, angle - 0.65, angle + 0.65, 12, Color(PAPER, t * 0.9), 2.5, true)


static func _draw_blast(ci: CanvasItem, data: Dictionary, reduced: bool) -> bool:
	var t := _life(data)
	var radius := float(data.get("radius", 0.0))
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	if t <= 0.02 or not is_finite(radius) or radius < 0.75 or not pos.is_finite():
		return false
	var p := profile(StringName(data.get("weapon_id", &"")))
	var color := Color(p["color"], t * 0.7)
	# The thin outer boundary appears at the true radius immediately. It is not
	# an expanding damage front; the simulation has already applied this event.
	ci.draw_arc(pos, radius, 0.0, TAU, 32 if reduced else 48, Color(INK, t * 0.5), 1.4, true)
	var spokes := 4 if reduced else 7
	for index in spokes:
		var direction := Vector2.from_angle(TAU * float(index) / float(spokes))
		var center := pos + direction * radius * (0.15 + 0.65 * (1.0 - t))
		_polyline(ci, center, direction, PackedVector2Array([Vector2(-0.6, -0.4), Vector2(0.4, -0.2), Vector2(0.7, 0.4)]), minf(8.0, radius * 0.12) * t, color, 2.0)
	return true
