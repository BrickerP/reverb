class_name ThreatInk
extends RefCounted

# These marks explain existing rules. They never schedule a hit or move an actor.
const INK := Color("292720")
const PAPER := Color("e5d8b8")
const DANGER := Color("be5749")
const GLYPH_RADIUS := 7.0

static var _dash_cache: Dictionary = {}


static func elite_color(kind: StringName) -> Color:
	match kind:
		&"overclocked": return Color("bf9e48")
		&"bulwark": return Color("748894")
		&"volatile": return DANGER
		&"splitter": return Color("82935e")
	return Color("8f7a95")


static func art_bounds(id: StringName) -> Vector2:
	match id:
		&"runner": return Vector2(38.0, 38.0)
		&"brute": return Vector2(58.0, 44.0)
		&"silencer": return Vector2(42.0, 50.0)
		&"bomber": return Vector2(40.0, 36.0)
		&"warden": return Vector2(56.0, 46.0)
		&"paradox": return Vector2(88.0, 72.0)
	return Vector2(42.0, 40.0)


static func profile(enemy: EnemyState, target: Vector2, clock: float,
		reduced: bool = false) -> Dictionary:
	var valid := enemy != null and enemy.def != null and enemy.pos.is_finite() \
			and is_finite(enemy.radius) and enemy.radius > 0.0 \
			and is_finite(enemy.def.radius) and enemy.def.radius > 0.0
	var radius := enemy.radius if valid else 0.0
	var position := enemy.pos if valid else Vector2.ZERO
	var kind: StringName = enemy.elite_kind if valid else &""
	var body_color := enemy.def.color if valid else INK
	if valid and enemy.elite:
		body_color = elite_color(kind)
	if valid and enemy.flash > 0.0:
		body_color = Color.WHITE
	var direction := enemy.attack_direction if valid and enemy.def.id == &"warden" \
		else ((target - position).normalized() if target.is_finite() else Vector2.RIGHT)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var time := clock if is_finite(clock) else 0.0
	var pulse := 0.5 if reduced else 0.5 + 0.5 * sin(time * 4.5 + position.x * 0.03)
	var death_pulse := 0.5 if reduced else 0.5 + 0.5 * sin(time * 7.0)
	var shield := _positive(enemy.shield_arc_value()) if valid else 0.0
	shield = minf(shield, 360.0)
	var death_radius := _positive(enemy.death_radius_value()) if valid else 0.0
	var size := art_bounds(enemy.def.id) * radius / maxf(1.0, enemy.def.radius) \
			if valid else Vector2.ZERO
	var glyph_y := minf(-radius - 9.0, radius * 0.72 - size.y - 8.0)
	var anchor := position + Vector2(0.0, glyph_y)
	var margin := GLYPH_RADIUS + 3.0
	if anchor.y < Sim.ARENA.position.y + margin:
		var side := maxf(size.x * 0.5, radius) + margin + 4.0
		anchor = position + Vector2(side, 0.0)
		if anchor.x > Sim.ARENA.end.x - margin:
			anchor.x = position.x - side
	anchor.x = clampf(anchor.x, Sim.ARENA.position.x + margin, Sim.ARENA.end.x - margin)
	anchor.y = clampf(anchor.y, Sim.ARENA.position.y + margin, Sim.ARENA.end.y - margin)
	return {
		"valid": valid, "elite_kind": kind, "body_color": body_color,
		"aura_color": elite_color(kind), "art_size": size,
		"aura_radius": radius + 8.0, "aura_alpha": 0.35 + 0.25 * pulse,
		"aura_segments": 20 if reduced else 28,
		"aura_secondary": valid and enemy.elite and not reduced,
		"secondary_radius": radius + 14.0,
		"secondary_start": 0.0 if reduced else -time * 1.2,
		"secondary_end": (0.0 if reduced else -time * 1.2) + TAU * 0.55,
		"death_radius": death_radius, "death_alpha": 0.10 + 0.10 * death_pulse,
		"death_segments": 24 if reduced else 32,
		"shield_arc": shield, "shield_radius": radius + 6.0,
		"shield_center": direction.angle(),
		"shield_start": direction.angle() - deg_to_rad(shield * 0.5),
		"shield_end": direction.angle() + deg_to_rad(shield * 0.5),
		"glyph": glyph_name(kind), "glyph_segments": glyph_segments(kind),
		"glyph_anchor": anchor,
		"glyph_tilt": (float(posmod(enemy.uid, 5)) - 2.0) * 0.025 if valid else 0.0,
		"latent_blast": death_radius > 0.0,
		"attack": EnemyBrain.attack_profile(enemy) if valid else {},
	}


static func glyph_name(kind: StringName) -> StringName:
	match kind:
		&"overclocked": return &"double_chevron"
		&"bulwark": return &"clamp_plate"
		&"volatile": return &"burst_warning"
		&"splitter": return &"split_staple"
	return &""


# Disconnected local line pairs are deliberately different in monochrome.
static func glyph_segments(kind: StringName, scale: float = 1.0) -> PackedVector2Array:
	if not is_finite(scale) or scale <= 0.0:
		return PackedVector2Array()
	var points := PackedVector2Array()
	match kind:
		&"overclocked":
			points = PackedVector2Array([Vector2(-6,-5), Vector2(-1,0), Vector2(-1,0), Vector2(-6,5),
				Vector2(1,-5), Vector2(6,0), Vector2(6,0), Vector2(1,5)])
		&"bulwark":
			points = PackedVector2Array([Vector2(-6,-5), Vector2(6,-5), Vector2(-6,-5), Vector2(-6,2),
				Vector2(6,-5), Vector2(6,2), Vector2(-6,2), Vector2(0,6), Vector2(0,6), Vector2(6,2)])
		&"volatile":
			points = PackedVector2Array([Vector2(0,-5), Vector2(0,1), Vector2(-1,5), Vector2(1,5),
				Vector2(-6,-5), Vector2(-4,-3), Vector2(6,-5), Vector2(4,-3),
				Vector2(-6,5), Vector2(-4,3), Vector2(6,5), Vector2(4,3)])
		&"splitter":
			points = PackedVector2Array([Vector2(-6,-5), Vector2(-6,4), Vector2(6,-5), Vector2(6,4),
				Vector2(-6,-5), Vector2(-2,-5), Vector2(2,-5), Vector2(6,-5),
				Vector2(-2,4), Vector2(0,0), Vector2(0,0), Vector2(2,4)])
	for index in points.size():
		points[index] *= scale
	return points


static func draw_enemy_marks(ci: CanvasItem, enemy: EnemyState, target: Vector2,
		clock: float, reduced: bool = false, include_attack: bool = true) -> void:
	if ci == null or enemy == null or enemy.def == null or enemy.dead \
			or not enemy.pos.is_finite() or not is_finite(enemy.radius) or enemy.radius <= 0.0 \
			or not is_finite(enemy.def.radius) or enemy.def.radius <= 0.0:
		return
	if include_attack:
		draw_attack(ci, enemy, reduced)
	var blast_radius := _positive(enemy.death_radius_value())
	var arc := minf(360.0, _positive(enemy.shield_arc_value()))
	if not enemy.elite and blast_radius <= 0.0 and arc <= 0.0:
		# Most crowd members have no special rule: do not allocate a full profile per frame.
		return
	if enemy.elite:
		var p := profile(enemy, target, clock, reduced)
		if not bool(p["valid"]):
			return
		var color := Color(p["aura_color"], float(p["aura_alpha"]))
		# Broken corners frame the actor, while its badge supplies the non-color identity.
		for quarter in 4:
			var start := float(quarter) * TAU / 4.0 + 0.16
			ci.draw_arc(enemy.pos, float(p["aura_radius"]), start, start + 0.65, 6, color, 1.6, true)
		var anchor: Vector2 = p["glyph_anchor"]
		ci.draw_circle(anchor, GLYPH_RADIUS + 2.0, Color(PAPER, 0.94), true, -1.0, true)
		var segments: PackedVector2Array = p["glyph_segments"]
		for index in segments.size():
			segments[index] = segments[index].rotated(float(p["glyph_tilt"])) + anchor
		if not segments.is_empty():
			ci.draw_multiline(segments, INK, 1.8, true)
		if bool(p["aura_secondary"]):
			var tick := Vector2.from_angle(float(p["secondary_start"]))
			ci.draw_line(enemy.pos + tick * (float(p["aura_radius"]) - 2.0),
					enemy.pos + tick * (float(p["aura_radius"]) + 2.0), color, 1.5, true)
	if blast_radius > 0.0:
		# This is a potential death blast, not an already damaging field or a countdown.
		var boundary := dashed_boundary_points(blast_radius)
		ci.draw_set_transform(enemy.pos)
		ci.draw_multiline(boundary, Color(INK, 0.36), 2.8, true)
		ci.draw_multiline(boundary, Color(DANGER, 0.58), 1.3, true)
		ci.draw_set_transform(Vector2.ZERO)
		var marker := enemy.pos + Vector2(0.0, enemy.radius + 7.0)
		ci.draw_line(marker + Vector2(-4.0,0.0), marker + Vector2(4.0,0.0), DANGER, 2.0, true)
	if arc > 0.0:
		var facing := enemy.attack_direction if enemy.def.id == &"warden" \
			else ((target - enemy.pos).normalized() if target.is_finite() else Vector2.RIGHT)
		if facing == Vector2.ZERO:
			facing = Vector2.RIGHT
		var shield_radius := enemy.radius + 6.0
		var shield_start := facing.angle() - deg_to_rad(arc * 0.5)
		var shield_end := facing.angle() + deg_to_rad(arc * 0.5)
		ci.draw_arc(enemy.pos, shield_radius, shield_start, shield_end,
				20, Color(PAPER, 0.94), 5.5, true)
		ci.draw_arc(enemy.pos, shield_radius, shield_start, shield_end,
				20, INK, 2.0, true)
		for angle: float in [shield_start, shield_end]:
			var edge := Vector2.from_angle(angle)
			ci.draw_line(enemy.pos + edge * (shield_radius - 2.5),
					enemy.pos + edge * (shield_radius + 2.5), INK, 2.0, true)


static func attack_bounds(enemy: EnemyState) -> Rect2:
	if enemy == null or enemy.def == null or enemy.dead or not enemy.pos.is_finite() \
			or enemy.brain_state not in [&"warn", &"dash", &"slam"] \
			or enemy.def.id not in [&"runner", &"brute"]:
		return Rect2()
	var attack := EnemyBrain.attack_profile(enemy)
	if attack["kind"] == &"dash":
		var end := WorldArena.move_straight(enemy.pos, enemy.attack_direction * float(attack["reach"]), enemy.radius)
		var minimum := Vector2(minf(enemy.pos.x, end.x), minf(enemy.pos.y, end.y))
		var maximum := Vector2(maxf(enemy.pos.x, end.x), maxf(enemy.pos.y, end.y))
		return Rect2(minimum, maximum - minimum).grow(enemy.radius + 3.0)
	return sector_bounds(enemy.pos, enemy.attack_direction, float(attack["reach"]), float(attack["half_angle"]))


static func sector_bounds(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> Rect2:
	var minimum := origin
	var maximum := origin
	var facing := direction.angle()
	for angle: float in [facing - half_angle, facing + half_angle, 0.0, PI * 0.5, PI, PI * 1.5]:
		if absf(angle_difference(facing, angle)) > half_angle + 0.00001:
			continue
		var point := origin + Vector2.from_angle(angle) * maxf(1.0, reach)
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum).grow(3.0)


static func attack_in_view(enemy: EnemyState, view: Rect2) -> bool:
	var bounds := attack_bounds(enemy)
	return bounds.has_area() and bounds.intersects(view)


static func marks_in_view(enemy: EnemyState, view: Rect2) -> bool:
	if enemy == null or enemy.def == null or enemy.dead:
		return false
	var blast := _positive(enemy.death_radius_value())
	if not enemy.elite and blast <= 0.0 and enemy.shield_arc_value() <= 0.0:
		return false
	var art_extent := art_bounds(enemy.def.id).length() * enemy.radius / maxf(1.0, enemy.def.radius) + 20.0
	var extent := maxf(blast + 3.0, maxf(enemy.radius + 20.0, art_extent))
	return view.grow(extent).has_point(enemy.pos)


static func draw_attack(ci: CanvasItem, enemy: EnemyState, _reduced: bool = false) -> void:
	var attack := EnemyBrain.attack_profile(enemy)
	if not bool(attack["visible"]):
		return
	var origin: Vector2 = attack["origin"]
	var direction: Vector2 = attack["direction"]
	var active := bool(attack["active"])
	var edge := Color(DANGER, 0.9 if active else 0.4 + float(attack["progress"]) * 0.4)
	var fill := Color(DANGER, 0.16 if active else 0.055)
	if attack["kind"] == &"dash":
		var radius := float(attack["radius"])
		var end := WorldArena.move_straight(origin, direction * float(attack["reach"]), radius)
		var normal := Vector2(-direction.y, direction.x) * radius
		if origin.distance_squared_to(end) < 0.25:
			ci.draw_circle(origin, radius, fill, true, -1.0, true)
			ci.draw_arc(origin, radius, 0.0, TAU, 20, edge, 1.8, true)
			return
		var corridor := PackedVector2Array([origin + normal, end + normal, end - normal, origin - normal])
		ci.draw_colored_polygon(corridor, fill)
		ci.draw_line(origin + normal, end + normal, edge, 1.8, true)
		ci.draw_line(origin - normal, end - normal, edge, 1.8, true)
		ci.draw_arc(end, radius, direction.angle() - PI * 0.5, direction.angle() + PI * 0.5,
			12, edge, 1.8, true)
		var arrow := end - direction * 12.0
		ci.draw_polyline(PackedVector2Array([arrow + normal * 0.35, end, arrow - normal * 0.35]), edge, 2.0, true)
	else:
		var reach := float(attack["reach"])
		var half_angle := float(attack["half_angle"])
		var sector := PackedVector2Array([origin])
		for index in 21:
			var angle := direction.angle() - half_angle + half_angle * 2.0 * float(index) / 20.0
			sector.append(origin + Vector2.from_angle(angle) * reach)
		ci.draw_colored_polygon(sector, fill)
		sector.append(origin)
		ci.draw_polyline(sector, edge, 2.0 if active else 1.5, true)
		ci.draw_line(origin + direction * 16.0, origin + direction * (reach - 14.0), Color(edge, 0.4), 1.0, true)


static func draw_enemy_zones(ci: CanvasItem, sim: Sim) -> void:
	for zone in sim.enemy_zones:
		var active := zone.is_active()
		if not active and not zone.is_warning():
			continue
		ci.draw_circle(zone.pos, zone.radius, Color(DANGER, 0.14 if active else 0.16), true, -1.0, true)
		if active:
			ci.draw_arc(zone.pos, zone.radius, 0.0, TAU, 48, Color(PAPER, 0.9), 7.0, true)
			ci.draw_arc(zone.pos, zone.radius, 0.0, TAU, 48, DANGER, 3.5, true)
		else:
			ci.draw_arc(zone.pos, zone.radius, 0.0, TAU, 48, Color(PAPER, 0.92), 8.0, true)
			ci.draw_set_transform(zone.pos)
			ci.draw_multiline(dashed_boundary_points(zone.radius), DANGER, 4.0, true)
			ci.draw_set_transform(Vector2.ZERO)
		var stamp := Rect2(zone.pos - Vector2(22.0, 16.0), Vector2(44.0, 32.0))
		ci.draw_rect(stamp, Color(PAPER, 0.94), true)
		ci.draw_rect(stamp, INK, false, 2.4)
		ci.draw_line(stamp.position + Vector2(6.0, 6.0), stamp.end - Vector2(6.0, 6.0), DANGER, 5.0, true)
		ci.draw_line(stamp.position + Vector2(6.0, stamp.size.y - 6.0),
			stamp.position + Vector2(stamp.size.x - 6.0, 6.0), DANGER, 5.0, true)


static func rift_profile(rift: TemporalRift, clock: float = 0.0,
		reduced: bool = false) -> Dictionary:
	var valid := rift != null and rift.pos.is_finite() and is_finite(rift.radius) \
			and rift.radius > 0.0 and is_finite(rift.telegraph) and is_finite(rift.active)
	var warning := valid and rift.is_warning()
	var active := valid and rift.is_active()
	var progress := 1.0 - clampf(rift.telegraph / TemporalRift.TELEGRAPH_TIME, 0.0, 1.0) \
			if warning else 1.0
	var time := clock if is_finite(clock) else 0.0
	return {"valid": valid, "visible": warning or active, "warning": warning, "active": active,
		"phase": &"sewn_seam" if warning else (&"open_seam" if active else &"ended"),
		"pos": rift.pos if valid else Vector2.ZERO, "radius": rift.radius if valid else 0.0,
		"progress": progress, "boundary_dashed": warning, "boundary_alpha": 0.35 + progress * 0.35 if warning else 0.85,
		"fill_alpha": 0.045 if warning else 0.15, "seam_open": active,
		"wobble": 0.0 if reduced or not active else sin(time * 3.0) * 1.2,
		"tick_remaining": maxf(0.0, rift.tick) if valid and is_finite(rift.tick) else 0.0}


static func draw_rifts(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	if ci == null or sim == null:
		return
	for rift in sim.rifts:
		var p := rift_profile(rift, sim.wave_time, reduced)
		if not bool(p["visible"]):
			continue
		var pos: Vector2 = p["pos"]
		var radius := float(p["radius"])
		var active := bool(p["active"])
		ci.draw_circle(pos, radius, Color(DANGER, float(p["fill_alpha"])), true, -1.0, true)
		if active:
			ci.draw_arc(pos, radius, 0.0, TAU, 48, Color(PAPER, 0.72), 5.0, true)
			ci.draw_arc(pos, radius, 0.0, TAU, 48, Color(DANGER, float(p["boundary_alpha"])), 3.0, true)
		else:
			ci.draw_set_transform(pos)
			ci.draw_multiline(dashed_boundary_points(radius), Color(DANGER, float(p["boundary_alpha"])), 2.0, true)
			ci.draw_set_transform(Vector2.ZERO)
		if radius < 3.0:
			continue
		var seam := _seam_points(pos, radius, float(p["wobble"]))
		ci.draw_polyline(seam, Color(INK, 0.85 if active else 0.55), 3.0 if active else 1.6, true)
		if active:
			# Paper teeth remain inside the real damaging boundary.
			for index in 5:
				var x := -0.4 + float(index) * 0.2
				var tooth := PackedVector2Array([pos + Vector2(x * radius, -radius * 0.075),
					pos + Vector2((x + 0.045) * radius, radius * 0.04),
					pos + Vector2((x + 0.09) * radius, -radius * 0.075)])
				ci.draw_polyline(tooth, Color(PAPER, 0.88), 2.0, true)
		else:
			for index in 5:
				var x := (-0.4 + float(index) * 0.2) * radius
				ci.draw_line(pos + Vector2(x - radius * 0.035, -radius * 0.08),
						pos + Vector2(x + radius * 0.035, radius * 0.08), Color(INK, 0.55), 1.5, true)


static func boss_link_profile(sim: Sim, clock: float = 0.0, reduced: bool = false) -> Dictionary:
	var ends := PackedVector2Array()
	if sim != null and sim.boss_phase >= 2:
		for shard in sim.boss_shards:
			if shard != null and not shard.dead and shard.pos.is_finite():
				ends.append(shard.pos)
	var visible := ends.size() == 2 and ends[0].distance_squared_to(ends[1]) > 1.0
	var center := (ends[0] + ends[1]) * 0.5 if visible else Vector2.ZERO
	var time := clock if is_finite(clock) else 0.0
	return {"visible": visible, "ends": ends, "center": center, "dangerous": false,
		"alpha": 0.38 if reduced else 0.34 + 0.06 * (0.5 + 0.5 * sin(time * 2.0)),
		"staple_size": Vector2(12.0, 7.0)}


static func draw_boss_link(ci: CanvasItem, sim: Sim, clock: float,
		reduced: bool = false) -> void:
	if ci == null:
		return
	var p := boss_link_profile(sim, clock, reduced)
	if not bool(p["visible"]):
		return
	var ends: PackedVector2Array = p["ends"]
	var direction := (ends[1] - ends[0]).normalized()
	var distance := ends[0].distance_to(ends[1])
	var dashes := mini(32, maxi(1, int(ceil(distance / 24.0))))
	for index in dashes:
		var from := float(index) / float(dashes)
		var to := minf(1.0, from + 0.5 / float(dashes))
		ci.draw_line(ends[0].lerp(ends[1], from), ends[0].lerp(ends[1], to),
				Color(INK, float(p["alpha"])), 1.5, true)
	var center: Vector2 = p["center"]
	var normal := Vector2(-direction.y, direction.x)
	var staple := PackedVector2Array([center - direction * 6.0 + normal * 2.5,
		center - direction * 6.0 - normal * 2.5, center + direction * 6.0 - normal * 2.5,
		center + direction * 6.0 + normal * 2.5])
	ci.draw_polyline(staple, PAPER, 4.0, true)
	ci.draw_polyline(staple, INK, 1.5, true)


static func _seam_points(pos: Vector2, radius: float, wobble: float) -> PackedVector2Array:
	var bend := minf(radius * 0.08, 7.0)
	return PackedVector2Array([pos + Vector2(-radius * 0.55, -bend * 0.5),
		pos + Vector2(-radius * 0.15, bend + wobble),
		pos + Vector2(radius * 0.15, -bend), pos + Vector2(radius * 0.55, bend * 0.5)])


static func dashed_boundary_points(radius: float) -> PackedVector2Array:
	if not is_finite(radius) or radius <= 0.0:
		return PackedVector2Array()
	if _dash_cache.has(radius):
		return _dash_cache[radius]
	var points := PackedVector2Array()
	for dash in 8:
		var start := float(dash) * TAU / 8.0
		for segment in 3:
			var from := start + float(segment) * TAU / 36.0
			var to := start + float(segment + 1) * TAU / 36.0
			points.append(Vector2.from_angle(from) * radius)
			points.append(Vector2.from_angle(to) * radius)
	if _dash_cache.size() >= 8:
		_dash_cache.clear()
	_dash_cache[radius] = points
	return points


static func _positive(value: float) -> float:
	return maxf(0.0, value) if is_finite(value) else 0.0
