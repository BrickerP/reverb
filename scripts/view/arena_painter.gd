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
const PLAYER_ART_SIZE := Vector2(44.0, 52.0)

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
		var key: StringName = &"enemy_runner" if e.def.id == &"runner" else &"enemy_grunt"
		var stride := sin(sim.wave_time * (7.5 if e.def.id == &"runner" else 4.5)
				+ e.pos.x * 0.021 + e.pos.y * 0.013)
		var facing := (target - e.pos).normalized()
		if facing == Vector2.ZERO:
			facing = Vector2.RIGHT
		var art_height := maxf(24.0, e.radius * (2.45 if e.def.is_boss else 2.3))
		var art_size := Vector2(art_height * _art_aspect(key, 1.0), art_height)
		art_size *= Vector2(1.0 + absf(stride) * 0.025, 1.0 - absf(stride) * 0.018)
		var art_tint := Color.WHITE if e.flash > 0.0 else e.def.color.lerp(Color.WHITE, 0.58)
		var center := e.pos + Vector2(0.0, -e.radius * 0.2 + stride * minf(1.8, e.radius * 0.08))
		var sway := stride * 0.045 * (-1.0 if facing.x < 0.0 else 1.0)
		_draw_art(ci, key, center, art_size, sway, Color(art_tint, 0.96))
		if e.def.is_boss:
			var spin := sim.wave_time * 0.7
			ci.draw_arc(e.pos, e.radius + 7.0, spin, spin + TAU * 0.75, 40, Color(col, 0.8), 3.0)
			ci.draw_arc(e.pos, e.radius + 13.0, -spin, -spin + TAU * 0.45, 28, Color(col, 0.45), 2.0)
			ci.draw_circle(e.pos, e.radius * 0.4, Color(0.05, 0.02, 0.1, 0.9))
		elif e.def.sides < 3:
			ci.draw_arc(e.pos, e.radius + 2.0, 0.0, TAU, 16, Color(col, 0.35), 2.0)
		if e.radius >= 15.0 and e.hp < e.max_hp:
			var top := e.pos + Vector2(-e.radius, -e.radius - 8.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0, 3.0)), Color(0, 0, 0, 0.6))
			var ratio := clampf(e.hp / e.max_hp, 0.0, 1.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0 * ratio, 3.0)), col)
		if e.def.death_radius > 0.0:
			var pulse := 0.5 + 0.5 * sin(sim.wave_time * 7.0)
			ci.draw_arc(e.pos, e.def.death_radius, 0.0, TAU, 32,
					Color(col, 0.10 + 0.10 * pulse), 1.5)
		if e.def.shield_arc > 0.0:
			var front := (target - e.pos).angle()
			var half := deg_to_rad(e.def.shield_arc * 0.5)
			ci.draw_arc(e.pos, e.radius + 6.0, front - half, front + half, 24,
					Color(col, 0.75), 3.0)


static func echoes(ci: CanvasItem, sim: Sim) -> void:
	var r := PlayerState.RADIUS
	var lifespan := sim.echo_lifespan()
	var segments := maxi(1, lifespan)
	var step := TAU / float(segments)
	var pulse := 0.5 + 0.5 * sin(sim.wave_time * 8.0)
	for a in sim.echoes:
		var c := a.take.tint()
		var remaining := maxi(0, lifespan - a.take.age)
		var muted := sim.echo_silenced > 0.0
		var bob := _motion_bob(sim.wave_time, a.pos, 5.0, 1.5)
		var art_alpha := 0.22 if muted else 0.48
		var breathe := 1.0 + sin(sim.wave_time * 3.0 + a.pos.x * 0.02) * 0.018
		var art_size := PLAYER_ART_SIZE * Vector2(2.0 - breathe, breathe)
		_draw_art(ci, &"player", a.pos + Vector2(0.0, r - PLAYER_ART_SIZE.y * 0.5 + bob),
				art_size, sin(sim.wave_time * 3.0 + a.pos.x * 0.02) * 0.035,
				Color(c.lerp(Color.WHITE, 0.28), art_alpha))
		var weapons: Array[WeaponDef] = a.take.weapons
		if sim.live_echo:
			weapons = sim.player.weapons
		_draw_weapon_loadout(ci, sim, a.pos, weapons, Vector2.RIGHT, bob, art_alpha,
				c, 0.45, 0.82)
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
	var bob := _motion_bob(sim.wave_time, pl.pos, 6.0, 1.6)
	var move_weight := clampf(pl.facing.length(), 0.0, 1.0)
	var sway := sin(sim.wave_time * 5.5 + pl.pos.x * 0.018) * 0.045 * move_weight
	var breathe := 1.0 + sin(sim.wave_time * 3.6 + pl.pos.y * 0.012) * 0.022
	var art_size := PLAYER_ART_SIZE * Vector2(2.0 - breathe, breathe)
	var art_center := pl.pos + Vector2(0.0, r - PLAYER_ART_SIZE.y * 0.5 + bob)
	_draw_art(ci, &"player", art_center, art_size, sway, Color(1.0, 1.0, 1.0, alpha))
	var count := pl.weapons.size()
	# shot_fired only identifies its source actor, not the weapon or target. Keep presentation
	# stable by aiming the mounted loadout at the nearest live enemy, then falling back to facing.
	if count > 0:
		_draw_weapon_loadout(ci, sim, pl.pos, pl.weapons, pl.facing, bob, alpha,
				Color.WHITE, 0.0, 1.0)


static func sparks(ci: CanvasItem, list: Array[Spark]) -> void:
	for s in list:
		var t := s.life / s.max_life
		if s.ring:
			ci.draw_arc(s.pos, s.radius + (1.0 - t) * 46.0, 0.0, TAU, 28, Color(s.color, t), 2.0)
		else:
			ci.draw_circle(s.pos, 1.5 + 2.0 * t, Color(s.color, t))


static func _draw_art(ci: CanvasItem, key: StringName, center: Vector2, size: Vector2,
		rotation: float, tint: Color) -> bool:
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.region(key)
	if tex == null or not source.has_area():
		return false
	var fitted := _contained_size(source.size, size)
	ci.draw_set_transform(center, rotation)
	ci.draw_texture_rect_region(tex, Rect2(-fitted * 0.5, fitted), source, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _contained_size(source: Vector2, bounds: Vector2) -> Vector2:
	if source.x <= 0.0 or source.y <= 0.0 or bounds.x <= 0.0 or bounds.y <= 0.0:
		return Vector2.ZERO
	var scale := minf(bounds.x / source.x, bounds.y / source.y)
	return source * scale


static func _weapon_size(key: StringName) -> Vector2:
	match key:
		&"weapon_shotgun":
			return Vector2(42.0, 20.0)
		&"weapon_orb":
			return Vector2(32.0, 24.0)
		_:
			return Vector2(36.0, 20.0)


static func _draw_weapon_loadout(ci: CanvasItem, sim: Sim, origin: Vector2,
		weapons: Array[WeaponDef], fallback: Vector2, bob: float, alpha: float,
		actor_tint: Color, tint_weight: float, size_mult: float) -> void:
	var count := weapons.size()
	if count <= 0:
		return
	var aim := _aim_direction(sim, origin, fallback)
	var normal := Vector2(-aim.y, aim.x)
	var crowd_scale := 0.78 if count >= 5 else (0.86 if count == 4 else 1.0)
	for i in count:
		var w: WeaponDef = weapons[i]
		var slot := _weapon_slot(i, count)
		var mount := origin + aim * slot.x + normal * slot.y + Vector2(0.0, bob)
		var key := PresentationAssets.weapon_key(w)
		var size := _weapon_size(key) * crowd_scale * size_mult
		var color := w.color.lerp(actor_tint, tint_weight).lerp(Color.WHITE, 0.35)
		_draw_art(ci, key, mount, size, aim.angle(), Color(color, alpha))


static func _weapon_slot(index: int, count: int) -> Vector2:
	var slots: Array[Vector2] = []
	match count:
		1:
			slots = [Vector2(21.0, 0.0)]
		2:
			slots = [Vector2(17.0, -15.0), Vector2(17.0, 15.0)]
		3:
			slots = [Vector2(21.0, 0.0), Vector2(-3.0, -22.0), Vector2(-3.0, 22.0)]
		4:
			slots = [Vector2(18.0, -16.0), Vector2(18.0, 16.0),
					Vector2(-16.0, -16.0), Vector2(-16.0, 16.0)]
		5:
			slots = [Vector2(22.0, 0.0), Vector2(7.0, -23.0), Vector2(7.0, 23.0),
					Vector2(-19.0, -15.0), Vector2(-19.0, 15.0)]
		_:
			slots = [Vector2(20.0, -16.0), Vector2(20.0, 16.0),
					Vector2(0.0, -27.0), Vector2(0.0, 27.0),
					Vector2(-20.0, -16.0), Vector2(-20.0, 16.0)]
	if index < slots.size():
		return slots[index]
	var angle := TAU * float(index) / float(maxi(1, count))
	return Vector2(cos(angle), sin(angle)) * 28.0


static func _art_aspect(key: StringName, fallback: float) -> float:
	var source := PresentationAssets.region(key)
	if not source.has_area() or source.size.y <= 0.0:
		return fallback
	return source.size.x / source.size.y


static func _aim_direction(sim: Sim, origin: Vector2, fallback: Vector2) -> Vector2:
	var closest: EnemyState
	var best_distance := INF
	for enemy in sim.enemies:
		if enemy.dead:
			continue
		var distance := origin.distance_squared_to(enemy.pos)
		if distance < best_distance:
			best_distance = distance
			closest = enemy
	if closest != null:
		var toward := (closest.pos - origin).normalized()
		if toward != Vector2.ZERO:
			return toward
	if fallback != Vector2.ZERO:
		return fallback.normalized()
	return Vector2.RIGHT


static func _motion_bob(wave_time: float, pos: Vector2, speed: float, distance: float) -> float:
	return sin(wave_time * speed + pos.x * 0.017 + pos.y * 0.011) * distance
