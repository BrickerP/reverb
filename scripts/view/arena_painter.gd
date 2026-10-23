class_name ArenaPainter
extends RefCounted

const FILL := Color(0.05, 0.055, 0.1)
const GRID_COLOR := Color(0.3, 0.4, 0.8, 0.08)
const BORDER := Color(0.4, 0.85, 1.0, 0.85)
const PLAYER := Color(0.6, 1.0, 1.0)
const GRID := 60.0
# Above this many bullets, trails are dropped; the heads still carry direction and readability.
const TRAIL_LIMIT := 160
# Above this many bullets, heads are drawn through one MultiMesh instead of one draw call each.
const BATCH_LIMIT := 80

static var _bullet_mesh: MultiMesh
static var _bullet_texture: ImageTexture
static var _bullet_capacity := 0


static func arena(ci: CanvasItem) -> void:
	var a := Sim.ARENA
	ci.draw_rect(a, FILL)
	var x := a.position.x + GRID
	while x < a.end.x:
		ci.draw_line(Vector2(x, a.position.y), Vector2(x, a.end.y), GRID_COLOR, 1.0)
		x += GRID
	var y := a.position.y + GRID
	while y < a.end.y:
		ci.draw_line(Vector2(a.position.x, y), Vector2(a.end.x, y), GRID_COLOR, 1.0)
		y += GRID
	ci.draw_rect(a.grow(4.0), Color(BORDER, 0.16), false, 8.0)
	ci.draw_rect(a, BORDER, false, 3.0)


static func pending(ci: CanvasItem, sim: Sim) -> void:
	for ps in sim.pending:
		var t := 1.0 - clampf(ps.delay / Sim.SPAWN_TELEGRAPH, 0.0, 1.0)
		var col := Color(ps.def.color, 0.25 + 0.6 * t)
		ci.draw_arc(ps.pos, ps.def.radius + 2.0 + 14.0 * (1.0 - t), 0.0, TAU, 20, col, 2.0)
		ci.draw_circle(ps.pos, 2.5, col)


# Wave-end beat: the just-recorded route collapses into the player.
static func record_beat(ci: CanvasItem, sim: Sim, take: EchoTake, t: float) -> void:
	if take.samples.is_empty():
		return
	var p := clampf(t, 0.0, 1.0)
	# Stay near the full route, then pull it in at the end.
	var collapse := p * p
	var target := sim.player.pos
	var pts := PackedVector2Array()
	for i in range(0, take.samples.size(), 3):
		pts.append(take.samples[i].lerp(target, collapse))
	if pts.size() >= 2:
		ci.draw_polyline(pts, Color(take.tint(), 0.85 * (1.0 - p)), 3.0)
	ci.draw_arc(target, 14.0 + 34.0 * collapse, 0.0, TAU, 32, Color(take.tint(), 0.7 * (1.0 - p)), 2.0)


# Boss death: a white impact flash, a vertical beam and three expanding rings.
static func victory(ci: CanvasItem, origin: Vector2, color: Color, t: float) -> void:
	var p := clampf(t, 0.0, 1.0)
	var flash := 0.55 * maxf(0.0, 1.0 - p * 2.4)
	ci.draw_rect(Sim.ARENA, Color(1.0, 1.0, 1.0, flash))
	ci.draw_line(origin - Vector2(0.0, 320.0), origin + Vector2(0.0, 320.0),
			Color(color, 0.06 * (1.0 - p)), 48.0)
	ci.draw_line(origin - Vector2(0.0, 320.0), origin + Vector2(0.0, 320.0),
			Color(color, 0.12 * (1.0 - p)), 16.0)
	for k in 3:
		var q := clampf(p * 1.55 - 0.16 * float(k), 0.0, 1.0)
		if q <= 0.0:
			continue
		ci.draw_arc(origin, 30.0 + 540.0 * q, 0.0, TAU, 64, Color(color, 0.8 * (1.0 - q)), 3.0)


static func echo_paths(ci: CanvasItem, sim: Sim, paths: Dictionary, reveal: Dictionary) -> void:
	var lifespan := maxi(1, sim.echo_lifespan())
	for a in sim.echoes:
		var pts: PackedVector2Array = paths.get(a, PackedVector2Array())
		if pts.size() < 2:
			continue
		var tint := a.take.tint()
		var remaining := clampi(lifespan - a.take.age, 0, lifespan)
		var base_alpha := 0.07 + 0.15 * float(remaining) / float(lifespan)
		if sim.echo_silenced > 0.0:
			base_alpha *= 0.45
		var progress := float(reveal.get(a, 1.0))
		if progress <= 0.0:
			ci.draw_polyline(pts, Color(tint, base_alpha * 0.6), 2.0)
			continue
		if progress < 1.0:
			# Faint full route, then a bright head running along it.
			ci.draw_polyline(pts, Color(tint, base_alpha * 0.5), 2.0)
			var keep := clampi(int(ceil(progress * float(pts.size() - 1))) + 1, 1, pts.size())
			var shown := pts.slice(0, keep)
			if shown.size() >= 2:
				ci.draw_polyline(shown, Color(tint, 0.6), 3.0)
			var head := shown[shown.size() - 1]
			ci.draw_circle(head, 3.5, Color(tint, 0.95))
		else:
			ci.draw_polyline(pts, Color(tint, base_alpha), 2.5)


# Faint dashed circle: makes pickup range upgrades (and the magnet) legible without text.
static func pickup_range(ci: CanvasItem, sim: Sim) -> void:
	if sim.pickups.is_empty():
		return
	var radius := sim.player.stats.get_stat(Stats.PICKUP_RANGE)
	if radius <= 0.0:
		return
	var segments := 32
	var step := TAU / float(segments)
	for k in segments:
		if k % 2 == 0:
			ci.draw_arc(sim.player.pos, radius, float(k) * step, float(k + 1) * step, 4, Color(0.6, 0.9, 1.0, 0.1), 1.0)


static func pickups(ci: CanvasItem, sim: Sim) -> void:
	for pk in sim.pickups:
		ci.draw_circle(pk.pos, 6.0, Color(UiTheme.COIN, 0.25))
		ci.draw_circle(pk.pos, 3.2, UiTheme.COIN)


static func enemies(ci: CanvasItem, sim: Sim) -> void:
	var target := sim.player.pos
	for e in sim.enemies:
		var col := Color.WHITE if e.flash > 0.0 else e.def.color
		if e.def.is_boss:
			var spin := Time.get_ticks_msec() / 1000.0 * 0.7
			ci.draw_colored_polygon(_ngon(e.pos, e.radius, 8, spin), Color(col, 0.9))
			ci.draw_arc(e.pos, e.radius + 7.0, spin, spin + TAU * 0.75, 40, Color(col, 0.8), 3.0)
			ci.draw_arc(e.pos, e.radius + 13.0, -spin, -spin + TAU * 0.45, 28, Color(col, 0.45), 2.0)
			ci.draw_circle(e.pos, e.radius * 0.4, Color(0.05, 0.02, 0.1, 0.9))
		elif e.def.sides < 3:
			ci.draw_circle(e.pos, e.radius, Color(col, 0.92))
			ci.draw_arc(e.pos, e.radius + 2.0, 0.0, TAU, 16, Color(col, 0.35), 2.0)
		else:
			var rot := (target - e.pos).angle()
			ci.draw_colored_polygon(_ngon(e.pos, e.radius + 2.0, e.def.sides, rot), Color(col, 0.92))
		if e.radius >= 15.0 and e.hp < e.max_hp:
			var top := e.pos + Vector2(-e.radius, -e.radius - 8.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0, 3.0)), Color(0, 0, 0, 0.6))
			var ratio := clampf(e.hp / e.max_hp, 0.0, 1.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0 * ratio, 3.0)), col)
		if e.def.death_radius > 0.0:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
			ci.draw_arc(e.pos, e.def.death_radius, 0.0, TAU, 32,
					Color(col, 0.10 + 0.10 * pulse), 1.5)


static func echoes(ci: CanvasItem, sim: Sim) -> void:
	var r := PlayerState.RADIUS
	var lifespan := sim.echo_lifespan()
	var segments := maxi(1, lifespan)
	var step := TAU / float(segments)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	for a in sim.echoes:
		var c := a.take.tint()
		var remaining := maxi(0, lifespan - a.take.age)
		var muted := sim.echo_silenced > 0.0
		ci.draw_circle(a.pos, r, Color(c, 0.12 if muted else 0.2))
		ci.draw_arc(a.pos, r, 0.0, TAU, 24, Color(c, 0.3 if muted else 0.9), 2.0)
		# One arc per wave of life left, so expiry is visible in the arena, not just in the shop.
		for k in segments:
			var start := -PI * 0.5 + float(k) * step
			var col := Color(c, 0.85) if k < remaining else Color(c, 0.12)
			ci.draw_arc(a.pos, r + 6.0, start, start + step * 0.82, 6, col, 2.0)
		if remaining <= 1:
			ci.draw_arc(a.pos, r + 9.0, 0.0, TAU, 28, Color(UiTheme.WARN, 0.2 + 0.5 * pulse), 1.5)
		if muted:
			ci.draw_line(a.pos + Vector2(-5.0, -5.0), a.pos + Vector2(5.0, 5.0), Color(UiTheme.WARN, 0.9), 2.0)
			ci.draw_line(a.pos + Vector2(5.0, -5.0), a.pos + Vector2(-5.0, 5.0), Color(UiTheme.WARN, 0.9), 2.0)
		elif a.rewinding:
			for dx in [-3.0, 2.0]:
				var tip := a.pos + Vector2(dx - 2.5, 0.0)
				var chevron := PackedVector2Array([tip + Vector2(5.0, -5.0), tip, tip + Vector2(5.0, 5.0)])
				ci.draw_polyline(chevron, Color(c, 0.95), 2.0)
		else:
			ci.draw_circle(a.pos, 3.0, Color(c, 0.9))


static func projectiles(ci: CanvasItem, sim: Sim) -> void:
	var count := sim.projectiles.size()
	if count > BATCH_LIMIT:
		if count <= TRAIL_LIMIT:
			_bullet_trails(ci, sim)
		_ensure_bullet_resources()
		_ensure_bullet_capacity(count)
		_bullet_mesh.visible_instance_count = count
		for i in count:
			var p := sim.projectiles[i]
			_bullet_mesh.set_instance_transform_2d(i,
					Transform2D(Vector2(p.radius, 0.0), Vector2(0.0, p.radius), p.pos))
			_bullet_mesh.set_instance_color(i, Color(1.0, 1.0, 0.6) if p.crit else p.color)
		ci.draw_multimesh(_bullet_mesh, _bullet_texture)
		return
	for p in sim.projectiles:
		var dir := p.vel.normalized()
		ci.draw_line(p.pos - dir * (p.radius * 2.4 + 6.0), p.pos, Color(p.color, 0.5), p.radius * 1.2)
		ci.draw_circle(p.pos, p.radius, Color(1.0, 1.0, 0.6) if p.crit else p.color)


static func _bullet_trails(ci: CanvasItem, sim: Sim) -> void:
	for p in sim.projectiles:
		var dir := p.vel.normalized()
		ci.draw_line(p.pos - dir * (p.radius * 2.4 + 6.0), p.pos, Color(p.color, 0.5), p.radius * 1.2)


static func _ensure_bullet_resources() -> void:
	if _bullet_mesh != null:
		return
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length()
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(c - d, 0.0, 1.0)))
	_bullet_texture = ImageTexture.create_from_image(image)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_bullet_mesh = MultiMesh.new()
	_bullet_mesh.transform_format = MultiMesh.TRANSFORM_2D
	_bullet_mesh.use_colors = true
	_bullet_mesh.mesh = quad


static func _ensure_bullet_capacity(count: int) -> void:
	if count <= _bullet_capacity:
		return
	_bullet_capacity = ceili(float(count) / 64.0) * 64
	_bullet_mesh.instance_count = _bullet_capacity


static func player(ci: CanvasItem, sim: Sim) -> void:
	var pl := sim.player
	var alpha := 1.0
	if pl.iframes > 0.0 and int(pl.iframes * 24.0) % 2 == 0:
		alpha = 0.35
	var r := PlayerState.RADIUS
	ci.draw_circle(pl.pos, r + 6.0, Color(PLAYER, 0.12 * alpha))
	ci.draw_circle(pl.pos, r, Color(PLAYER, alpha))
	ci.draw_circle(pl.pos, r * 0.45, Color(0.02, 0.05, 0.1, alpha))
	var count := pl.weapons.size()
	for i in count:
		var w := pl.weapons[i]
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(count))
		var base := pl.pos + dir * (r + 3.0)
		var tip := base + dir * 10.0
		var back := Color(0.01, 0.02, 0.05, 0.85 * alpha)
		ci.draw_line(base, tip, back, 7.0)
		ci.draw_line(base, tip, Color(w.color, alpha), 3.0)
		ci.draw_circle(base, 3.8, back)
		ci.draw_circle(base, 2.4, Color(w.color, alpha))
	ci.draw_line(pl.pos + pl.facing * r, pl.pos + pl.facing * (r + 7.0), Color(1, 1, 1, alpha), 3.0)


static func sparks(ci: CanvasItem, list: Array[Spark]) -> void:
	for s in list:
		var t := s.life / s.max_life
		if s.ring:
			ci.draw_arc(s.pos, s.radius + (1.0 - t) * 46.0, 0.0, TAU, 28, Color(s.color, t), 2.0)
		else:
			ci.draw_circle(s.pos, 1.5 + 2.0 * t, Color(s.color, t))


static func _ngon(center: Vector2, radius: float, sides: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(sides)
	for i in sides:
		pts[i] = center + Vector2.from_angle(rot + TAU * float(i) / float(sides)) * radius
	return pts
