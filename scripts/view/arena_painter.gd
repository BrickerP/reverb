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
const WARDEN_AUTHORED_FORWARD := 3.0 * PI / 4.0
const ARENA_FLOOR_PATH := "res://assets/presentation/surfaces/arena_floor.png"
const REDUCED_MOTION_SCALE := 0.3

static var _bullet_mesh: MultiMesh
static var _bullet_texture: ImageTexture
static var _bullet_capacity := 0
static var _arena_floor_texture: Texture2D


static func arena(ci: CanvasItem) -> void:
	var a := Sim.ARENA
	ci.draw_rect(a, FILL)
	var floor_texture := arena_floor_texture()
	if floor_texture != null:
		ci.draw_texture_rect(floor_texture, a, false, Color(0.72, 0.76, 0.86, 0.64))
		ci.draw_rect(a, Color(FILL, 0.24))
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


static func arena_floor_texture() -> Texture2D:
	if _arena_floor_texture == null:
		_arena_floor_texture = load(ARENA_FLOOR_PATH) as Texture2D
	return _arena_floor_texture


static func pending(ci: CanvasItem, sim: Sim) -> void:
	for ps in sim.pending:
		var profile := pending_spawn_profile(ps)
		var base_color: Color = profile["color"]
		var col := Color(base_color, float(profile["alpha"]))
		ci.draw_arc(ps.pos, float(profile["radius"]), 0.0, TAU, 20, col, 2.0)
		ci.draw_circle(ps.pos, 2.5, col)


static func pending_spawn_profile(spawn: PendingSpawn) -> Dictionary:
	var progress := 1.0 - clampf(spawn.delay / Sim.SPAWN_TELEGRAPH, 0.0, 1.0)
	var color := _elite_color(spawn.elite_kind) if spawn.elite_kind != &"" else spawn.def.color
	var body_radius := spawn.def.radius * (Sim.ELITE_RADIUS_MULT if spawn.elite_kind != &"" else 1.0)
	return {
		"elite_kind": spawn.elite_kind,
		"color": color,
		"alpha": 0.25 + 0.6 * progress,
		"body_radius": body_radius,
		"radius": body_radius + 2.0 + 14.0 * (1.0 - progress),
	}


# Wave-end beat: the just-recorded route collapses into the player.
static func record_beat(ci: CanvasItem, sim: Sim, take: EchoTake, t: float,
		reduced: bool = false) -> void:
	if take.samples.is_empty():
		return
	var p := clampf(t, 0.0, 1.0)
	# Stay near the full route, then pull it in at the end.
	var collapse := p * p * (0.25 if reduced else 1.0)
	var target := sim.player.pos
	var pts := PackedVector2Array()
	for i in range(0, take.samples.size(), 3):
		pts.append(take.samples[i].lerp(target, collapse))
	if pts.size() >= 2:
		ci.draw_polyline(pts, Color(take.tint(), (0.4 if reduced else 0.85) * (1.0 - p)),
				2.0 if reduced else 3.0)
	ci.draw_arc(target, 14.0 + 34.0 * collapse, 0.0, TAU, 32,
			Color(take.tint(), (0.35 if reduced else 0.7) * (1.0 - p)), 2.0)


# Boss death: a white impact flash, a vertical beam and three expanding rings.
static func victory(ci: CanvasItem, origin: Vector2, color: Color, t: float,
		reduced: bool = false) -> void:
	var p := clampf(t, 0.0, 1.0)
	var flash := victory_flash_alpha(p, reduced)
	if flash > 0.0:
		ci.draw_rect(Sim.ARENA, Color(1.0, 1.0, 1.0, flash))
	var beam_scale := 0.35 if reduced else 1.0
	ci.draw_line(origin - Vector2(0.0, 320.0), origin + Vector2(0.0, 320.0),
			Color(color, 0.06 * beam_scale * (1.0 - p)), 48.0 * beam_scale)
	ci.draw_line(origin - Vector2(0.0, 320.0), origin + Vector2(0.0, 320.0),
			Color(color, 0.12 * beam_scale * (1.0 - p)), 16.0 * beam_scale)
	var ring_count := 1 if reduced else 3
	var ring_distance := 180.0 if reduced else 540.0
	for k in ring_count:
		var q := clampf(p * 1.55 - 0.16 * float(k), 0.0, 1.0)
		if q <= 0.0:
			continue
		ci.draw_arc(origin, 30.0 + ring_distance * q, 0.0, TAU, 64,
				Color(color, (0.5 if reduced else 0.8) * (1.0 - q)), 3.0)


static func victory_flash_alpha(progress: float, reduced: bool) -> float:
	return 0.0 if reduced else 0.55 * maxf(0.0, 1.0 - clampf(progress, 0.0, 1.0) * 2.4)


static func echo_paths(ci: CanvasItem, sim: Sim, paths: Dictionary, reveal: Dictionary,
		reduced: bool = false) -> void:
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
		if reduced:
			ci.draw_polyline(pts, Color(tint, base_alpha * 0.8), 2.0)
			continue
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


static func rifts(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	for profile: Dictionary in rift_profiles(sim, reduced):
		var color := Color(0.72, 0.45, 1.0)
		var pos: Vector2 = profile["pos"]
		var radius := float(profile["radius"])
		ci.draw_circle(pos, radius, Color(color, float(profile["fill_alpha"])))
		ci.draw_arc(pos, radius, 0.0, TAU, 48, Color(color, float(profile["boundary_alpha"])),
				float(profile["boundary_width"]))
		if float(profile["warning_ring_radius"]) > 0.0:
			ci.draw_arc(pos, float(profile["warning_ring_radius"]), 0.0, TAU, 32,
					Color(color, float(profile["warning_ring_alpha"])), 1.5)
		if bool(profile["spokes"]):
			var spokes := 6
			for k in spokes:
				var angle := TAU * float(k) / float(spokes) + float(profile["spoke_rotation"])
				ci.draw_line(pos, pos + Vector2.from_angle(angle) * radius,
						Color(color, float(profile["spoke_alpha"])), 1.0)
		if int(profile["active_arc_count"]) > 0:
			ci.draw_arc(pos, radius * 0.72, float(profile["outer_arc_start"]),
					float(profile["outer_arc_start"]) + TAU * 0.62, 32, Color(color, 0.45), 1.5)
			ci.draw_arc(pos, radius * 0.45, float(profile["inner_arc_start"]),
					float(profile["inner_arc_start"]) + TAU * 0.45, 24, Color(color, 0.6), 1.5)


static func rift_profiles(sim: Sim, reduced: bool = false) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for rift: TemporalRift in sim.rifts:
		profiles.append(rift_profile(rift, sim.wave_time, reduced))
	return profiles


static func rift_profile(rift: TemporalRift, wave_time: float,
		reduced: bool = false) -> Dictionary:
	var warning := rift.is_warning()
	var progress := 1.0 - clampf(rift.telegraph / TemporalRift.TELEGRAPH_TIME, 0.0, 1.0)
	var pulse := 0.5 if reduced else 0.5 + 0.5 * sin(wave_time * 6.0)
	return {
		"state": &"warning" if warning else &"active",
		"pos": rift.pos,
		"radius": rift.radius,
		"bounds": Rect2(rift.pos - Vector2.ONE * rift.radius, Vector2.ONE * rift.radius * 2.0),
		"fill_alpha": (0.05 if reduced else 0.025 + 0.06 * progress) if warning \
				else (0.105 if reduced else 0.08 + 0.05 * pulse),
		"boundary_alpha": (0.36 if reduced else 0.22 + 0.28 * progress) if warning else 0.55,
		"boundary_width": 2.0 if warning else 2.5,
		"warning_ring_radius": 0.0 if reduced or not warning \
				else rift.radius * (0.18 + 0.82 * progress),
		"warning_ring_alpha": 0.12 + 0.25 * progress,
		"spokes": warning and not reduced,
		"spoke_rotation": wave_time * 0.35,
		"spoke_alpha": 0.08 + 0.08 * progress,
		"active_arc_count": 0 if reduced or warning else 2,
		"outer_arc_start": -wave_time * 1.6,
		"inner_arc_start": wave_time * 2.1,
	}


static func pickups(ci: CanvasItem, sim: Sim) -> void:
	for pk in sim.pickups:
		ci.draw_circle(pk.pos, 6.0, Color(UiTheme.COIN, 0.25))
		ci.draw_circle(pk.pos, 3.2, UiTheme.COIN)


static func enemies(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	var target := sim.player.pos
	var boss_rules: Dictionary = {}
	if sim.boss_phase >= 2 and not sim.boss_shards.is_empty():
		boss_rules = boss_phase_profile(sim, reduced)
	for e in sim.enemies:
		var col := _elite_color(e.elite_kind) if e.elite else e.def.color
		if e.flash > 0.0:
			col = Color.WHITE
		var key := PresentationAssets.enemy_key(e.def)
		var stride := sin(sim.wave_time * (7.5 if e.def.id == &"runner" else 4.5)
				+ e.pos.x * 0.021 + e.pos.y * 0.013) * (REDUCED_MOTION_SCALE if reduced else 1.0)
		var facing := (target - e.pos).normalized()
		if facing == Vector2.ZERO:
			facing = Vector2.RIGHT
		var art_size := _enemy_bounds(e.def.id) * e.radius / maxf(1.0, e.def.radius)
		art_size *= Vector2(1.0 + absf(stride) * 0.025, 1.0 - absf(stride) * 0.018)
		var art_tint := Color.WHITE if e.flash > 0.0 else col.lerp(Color.WHITE, 0.58)
		var foot := e.pos + Vector2(0.0, e.radius * 0.72 + stride * minf(1.8, e.radius * 0.08))
		var rotation := _warden_rotation(facing) if e.def.id == &"warden" else 0.0
		var flip := facing.x > 0.0 and e.def.id != &"warden"
		if e.def.id == &"warden":
			# The shield arc is centered on e.pos. Rotate the authored shield body around the same
			# point; a foot pivot makes its center orbit away from the gameplay-facing arc.
			_draw_art(ci, key, e.pos, art_size, rotation, Color(art_tint, 0.96))
		else:
			_draw_art_foot(ci, key, foot, art_size, rotation, Color(art_tint, 0.96), flip)
		if e.def.is_boss:
			var spin := sim.wave_time * 0.7
			ci.draw_arc(e.pos, e.radius + 7.0, spin, spin + TAU * 0.75, 40, Color(col, 0.8), 3.0)
			ci.draw_arc(e.pos, e.radius + 13.0, -spin, -spin + TAU * 0.45, 28, Color(col, 0.45), 2.0)
			ci.draw_circle(e.pos, e.radius * 0.4, Color(0.05, 0.02, 0.1, 0.9))
			if sim.boss_phase >= 2 and sim.boss_shards.has(e) and not reduced:
				ci.draw_arc(e.pos, e.radius + 19.0, -spin * 1.4, -spin * 1.4 + TAU * 0.6, 32,
						Color(0.65, 0.8, 1.0, 0.55), 2.0)
			if bool(boss_rules.get("survivor_visible", false)) \
					and boss_rules.get("survivor") == e:
				ci.draw_arc(e.pos, float(boss_rules["survivor_radius"]), 0.0, TAU,
						24 if reduced else 32,
						Color(1.0, 0.35, 0.55, float(boss_rules["survivor_alpha"])), 2.5)
		elif e.def.sides < 3:
			ci.draw_arc(e.pos, e.radius + 2.0, 0.0, TAU, 16, Color(col, 0.35), 2.0)
		if e.elite:
			var rules := enemy_rule_profile(e, target, sim.wave_time, reduced)
			var aura: Color = rules["aura_color"]
			ci.draw_arc(e.pos, float(rules["aura_radius"]), 0.0, TAU,
					int(rules["aura_segments"]), Color(aura, float(rules["aura_alpha"])), 2.0)
			if bool(rules["aura_secondary"]):
				ci.draw_arc(e.pos, float(rules["secondary_radius"]),
						float(rules["secondary_start"]), float(rules["secondary_end"]), 24,
						Color(aura, 0.5), 1.5)
		if e.radius >= 15.0 and e.hp < e.max_hp:
			var fitted := _fitted_art_size(key, art_size)
			var art_top := e.pos.y - fitted.y * 0.5 if e.def.id == &"warden" else foot.y - fitted.y
			var top := Vector2(e.pos.x - e.radius, art_top - 6.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0, 3.0)), Color(0, 0, 0, 0.6))
			var ratio := clampf(e.hp / e.max_hp, 0.0, 1.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0 * ratio, 3.0)), col)
		var death_radius := e.death_radius_value()
		if death_radius > 0.0:
			var death_pulse := 0.5 if reduced else 0.5 + 0.5 * sin(sim.wave_time * 7.0)
			ci.draw_arc(e.pos, death_radius, 0.0, TAU, 24 if reduced else 32,
					Color(col, 0.10 + 0.10 * death_pulse), 1.5)
		var shield_arc := e.shield_arc_value()
		if shield_arc > 0.0:
			var front := (target - e.pos).angle()
			var half := deg_to_rad(shield_arc * 0.5)
			ci.draw_arc(e.pos, e.radius + 6.0, front - half, front + half, 24,
					Color(col, 0.75), 3.0)
	if bool(boss_rules.get("link_visible", false)):
		var start: Vector2 = boss_rules["link_start"]
		var end: Vector2 = boss_rules["link_end"]
		var mid: Vector2 = boss_rules["link_mid"]
		var link := Color(0.65, 0.8, 1.0, float(boss_rules["link_alpha"]))
		ci.draw_line(start, mid, link, 2.0)
		ci.draw_line(mid, end, link, 2.0)
		if float(boss_rules["link_node_radius"]) > 0.0:
			ci.draw_circle(mid, float(boss_rules["link_node_radius"]),
					Color(0.75, 0.6, 1.0, 0.5))


static func boss_phase_profile(sim: Sim, reduced: bool = false) -> Dictionary:
	var alive: Array[EnemyState] = []
	for body: EnemyState in sim.boss_shards:
		if not body.dead:
			alive.append(body)
	var pulse := 0.5 if reduced else 0.5 + 0.5 * sin(sim.wave_time * 5.0)
	var start := alive[0].pos if alive.size() == 2 else Vector2.ZERO
	var end := alive[1].pos if alive.size() == 2 else Vector2.ZERO
	var survivor: EnemyState = alive[0] if alive.size() == 1 else null
	return {
		"alive_count": alive.size(),
		"link_visible": alive.size() == 2,
		"link_start": start,
		"link_end": end,
		"link_mid": (start + end) * 0.5,
		"link_alpha": 0.18 + 0.16 * pulse,
		"link_node_radius": 0.0 if reduced else 4.0 + pulse * 2.0,
		"detail_rotates": not reduced,
		"survivor_visible": survivor != null,
		"survivor": survivor,
		"survivor_radius": survivor.radius + 22.0 if survivor != null else 0.0,
		"survivor_alpha": 0.55 if reduced else 0.45 + 0.25 * pulse,
	}


static func enemy_rule_profile(enemy: EnemyState, target: Vector2, wave_time: float,
		reduced: bool = false) -> Dictionary:
	var body_color := _elite_color(enemy.elite_kind) if enemy.elite else enemy.def.color
	if enemy.flash > 0.0:
		body_color = Color.WHITE
	var facing := (target - enemy.pos).normalized()
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	var shield_arc := enemy.shield_arc_value()
	var shield_half := deg_to_rad(shield_arc * 0.5)
	var shield_center := facing.angle()
	var elite_pulse := 0.5 if reduced else 0.5 + 0.5 * sin(
			wave_time * 4.5 + enemy.pos.x * 0.03)
	var death_pulse := 0.5 if reduced else 0.5 + 0.5 * sin(wave_time * 7.0)
	var secondary_start := -wave_time * 1.2
	return {
		"elite_kind": enemy.elite_kind,
		"body_color": body_color,
		"aura_color": _elite_color(enemy.elite_kind),
		"art_size": _enemy_bounds(enemy.def.id) * enemy.radius / maxf(1.0, enemy.def.radius),
		"aura_radius": enemy.radius + 8.0,
		"aura_alpha": 0.35 + 0.25 * elite_pulse,
		"aura_segments": 20 if reduced else 28,
		"aura_secondary": enemy.elite and not reduced,
		"secondary_radius": enemy.radius + 14.0,
		"secondary_start": secondary_start,
		"secondary_end": secondary_start + TAU * 0.55,
		"death_radius": enemy.death_radius_value(),
		"death_alpha": 0.10 + 0.10 * death_pulse,
		"death_segments": 24 if reduced else 32,
		"shield_arc": shield_arc,
		"shield_radius": enemy.radius + 6.0,
		"shield_center": shield_center,
		"shield_start": shield_center - shield_half,
		"shield_end": shield_center + shield_half,
	}


static func echoes(ci: CanvasItem, sim: Sim, character_id: StringName = &"looper",
		recoils: Array[Dictionary] = [], reduced: bool = false) -> void:
	var r := PlayerState.RADIUS
	var lifespan := sim.echo_lifespan()
	var segments := maxi(1, lifespan)
	var step := TAU / float(segments)
	var pulse := 0.5 + 0.5 * sin(sim.wave_time * 8.0)
	for a in sim.echoes:
		var c := a.take.tint()
		var remaining := maxi(0, lifespan - a.take.age)
		var muted := sim.echo_silenced > 0.0
		var motion_scale := REDUCED_MOTION_SCALE if reduced else 1.0
		var bob := _motion_bob(sim.wave_time, a.pos, 5.0, 1.5) * motion_scale
		var art_alpha := 0.22 if muted else 0.48
		var breathe := 1.0 + sin(sim.wave_time * 3.0 + a.pos.x * 0.02) * 0.018 * motion_scale
		var facing := _echo_facing(a)
		var art_size := _character_bounds(character_id) * Vector2(2.0 - breathe, breathe)
		var key := PresentationAssets.character_key(character_id, _uses_back_art(facing))
		var foot := a.pos + Vector2(0.0, r + bob)
		_draw_art_foot(ci, key, foot, art_size,
				sin(sim.wave_time * 3.0 + a.pos.x * 0.02) * 0.035 * motion_scale,
				Color(c.lerp(Color.WHITE, 0.28), art_alpha), _horizontal_flip(facing))
		var weapons: Array[WeaponDef] = a.take.weapons
		if sim.live_echo:
			weapons = sim.player.weapons
		_draw_weapon_loadout(ci, sim, a.pos, weapons, facing, bob, art_alpha,
				c, 0.45, 0.82, a.index, recoils)
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


static func projectiles(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	var count := sim.projectiles.size()
	if count > BATCH_LIMIT:
		if projectile_trails_enabled(reduced, count):
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
		if projectile_trails_enabled(reduced, count):
			ci.draw_line(p.pos - dir * (p.radius * 2.4 + 6.0), p.pos,
					Color(p.color, 0.5), p.radius * 1.2)
		ci.draw_circle(p.pos, p.radius, Color(1.0, 1.0, 0.6) if p.crit else p.color)


static func projectile_trails_enabled(reduced: bool, count: int) -> bool:
	return not reduced and count <= TRAIL_LIMIT


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


static func player(ci: CanvasItem, sim: Sim, character_id: StringName = &"looper",
		motion: Dictionary = {}, recoils: Array[Dictionary] = []) -> void:
	var pl := sim.player
	var alpha := 1.0
	if pl.iframes > 0.0 and int(pl.iframes * 24.0) % 2 == 0:
		alpha = 0.35
	var r := PlayerState.RADIUS
	ci.draw_circle(pl.pos, r + 6.0, Color(PLAYER, 0.12 * alpha))
	var visual_time := float(motion.get("visual_time", sim.wave_time))
	var move_weight := clampf(float(motion.get("amount", 0.0)), 0.0, 1.0)
	var reduced := bool(motion.get("reduced", false))
	var motion_scale := REDUCED_MOTION_SCALE if reduced else 1.0
	var gait := visual_time * lerpf(3.2, 8.5, move_weight) + pl.pos.x * 0.012
	var bob := sin(gait * 2.0) * lerpf(0.45, 1.8, move_weight) * motion_scale
	var sway := sin(gait) * lerpf(0.012, 0.055, move_weight) * motion_scale
	var breathe := 1.0 + sin(visual_time * 3.1 + pl.pos.y * 0.012) * lerpf(0.018, 0.01, move_weight) * motion_scale
	var facing := pl.facing if pl.facing != Vector2.ZERO else Vector2.RIGHT
	var art_size := _character_bounds(character_id) * Vector2(2.0 - breathe, breathe)
	var key := PresentationAssets.character_key(character_id, _uses_back_art(facing))
	var foot := pl.pos + Vector2(0.0, r + bob)
	_draw_art_foot(ci, key, foot, art_size, sway, Color(1.0, 1.0, 1.0, alpha),
			_horizontal_flip(facing))
	var count := pl.weapons.size()
	# shot_fired only identifies its source actor, not the weapon or target. Keep presentation
	# stable by aiming the mounted loadout at the nearest live enemy, then falling back to facing.
	if count > 0:
		_draw_weapon_loadout(ci, sim, pl.pos, pl.weapons, pl.facing, bob, alpha,
				Color.WHITE, 0.0, 1.0, -1, recoils)


static func sparks(ci: CanvasItem, list: Array[Spark]) -> void:
	for s in list:
		var t := s.life / s.max_life
		if s.ring:
			ci.draw_arc(s.pos, s.radius + (1.0 - t) * 46.0, 0.0, TAU, 28, Color(s.color, t), 2.0)
		else:
			ci.draw_circle(s.pos, 1.5 + 2.0 * t, Color(s.color, t))


static func combat_feedback(ci: CanvasItem, muzzles: Array[Dictionary], hits: Array[Dictionary],
		explosions: Array[Dictionary], hurts: Array[Dictionary], weapon_changes: Array[Dictionary],
		reduced: bool) -> void:
	for data in muzzles:
		var t := float(data["life"]) / float(data["max_life"])
		var pos: Vector2 = data["pos"]
		var direction: Vector2 = data["direction"]
		var profile: Dictionary = data["profile"]
		var color: Color = profile["color"]
		var level_scale := 1.0 + 0.06 * float(clampi(int(data["level"]), 0, WeaponDef.MAX_LEVEL))
		var length := float(profile["length"]) * level_scale * (0.65 if reduced else 1.0)
		match profile["style"]:
			&"scatter":
				for angle in [-0.2, 0.0, 0.2]:
					ci.draw_line(pos, pos + direction.rotated(angle) * length, Color(color, 0.7 * t), 2.0)
			&"arcane":
				ci.draw_arc(pos, 4.0 + (1.0 - t) * 8.0, 0.0, TAU, 16, Color(color, 0.8 * t), 2.0)
			&"marksman":
				ci.draw_line(pos - direction * 4.0, pos + direction * length, Color(color, 0.9 * t), 2.5)
			_:
				ci.draw_line(pos, pos + direction * length, Color(color, 0.85 * t), 2.0)
		# Event origin and direction are authoritative; this short reverse stroke is visual recoil,
		# not a claim about which duplicate weapon slot fired.
		var origin: Vector2 = data["origin"]
		ci.draw_line(origin, origin - direction * float(profile["recoil"]) * t,
				Color(color, 0.45 * t), 2.0)
		if bool(profile["evolved"]):
			ci.draw_arc(pos, 7.0 + 5.0 * (1.0 - t), 0.0, TAU, 14, Color(1.0, 1.0, 1.0, t), 1.5)
	for data in hits:
		var t := float(data["life"]) / float(data["max_life"])
		var pos: Vector2 = data["pos"]
		var direction: Vector2 = data["direction"]
		var normal := Vector2(-direction.y, direction.x)
		var base_color: Color = data["color"]
		var color := base_color.lerp(Color(1.0, 1.0, 0.45), 0.8) if bool(data["crit"]) else base_color
		if bool(data["has_direction"]):
			ci.draw_line(pos - direction * 8.0, pos + direction * 3.0, Color(color, 0.9 * t), 2.0)
			ci.draw_line(pos - normal * (6.0 if bool(data["crit"]) else 3.0),
					pos + normal * (6.0 if bool(data["crit"]) else 3.0), Color(color, 0.8 * t), 2.0)
		else:
			ci.draw_arc(pos, 4.0 + (1.0 - t) * 7.0, 0.0, TAU, 16, Color(color, 0.85 * t), 2.0)
			if bool(data["crit"]):
				ci.draw_line(pos + Vector2(-6.0, 0.0), pos + Vector2(6.0, 0.0), Color(color, t), 2.0)
				ci.draw_line(pos + Vector2(0.0, -6.0), pos + Vector2(0.0, 6.0), Color(color, t), 2.0)
		if bool(data["reduced"]):
			if bool(data["has_direction"]):
				ci.draw_arc(pos, 10.0, direction.angle() - 0.65, direction.angle() + 0.65, 12,
						Color(0.55, 0.8, 1.0, 0.9 * t), 2.5)
			else:
				ci.draw_arc(pos, 10.0, 0.0, TAU, 20, Color(0.55, 0.8, 1.0, 0.9 * t), 2.5)
	for data in explosions:
		var t := float(data["life"]) / float(data["max_life"])
		var p := 1.0 - t
		var radius := float(data["radius"])
		var color: Color = data["color"]
		var pos: Vector2 = data["pos"]
		if data["kind"] == ExplosionInfo.BOMBER:
			ci.draw_arc(pos, radius * (0.35 + 0.65 * p), 0.0, TAU, 28,
					Color(UiTheme.WARN, 0.85 * t), 3.0)
		else:
			ci.draw_arc(pos, radius * (0.25 + 0.75 * p), 0.0, TAU, 32,
					Color(color, 0.75 * t), 2.0)
			ci.draw_circle(pos, maxf(2.0, radius * 0.12 * t), Color(color, 0.25 * t))
	for data in hurts:
		var t := float(data["life"]) / float(data["max_life"])
		var direction: Vector2 = data["direction"]
		var pos: Vector2 = data["pos"]
		if bool(data["has_direction"]):
			ci.draw_arc(pos, 20.0 + (1.0 - t) * 8.0, direction.angle() - 0.8,
					direction.angle() + 0.8, 16, Color(UiTheme.WARN, 0.85 * t), 3.0)
		else:
			ci.draw_arc(pos, 20.0 + (1.0 - t) * 8.0, 0.0, TAU, 24,
					Color(UiTheme.WARN, 0.7 * t), 2.5)
		if bool(data["lethal"]):
			ci.draw_arc(pos, 28.0 + (1.0 - t) * 20.0, 0.0, TAU, 28, Color(1.0, 0.2, 0.3, t), 3.0)
	for data in weapon_changes:
		var t := float(data["life"]) / float(data["max_life"])
		var pos: Vector2 = data["pos"]
		ci.draw_arc(pos, 15.0 + 12.0 * (1.0 - t),
				0.0, TAU, 12, Color(UiTheme.ACCENT, 0.65 * t), 1.5)


static func weapon_feedback_profile(id: StringName) -> Dictionary:
	var style: StringName = &"sidearm"
	var color := Color(0.55, 0.95, 1.0)
	var length := 12.0
	var recoil := 4.0
	match id:
		&"shotgun", &"flechette", &"flak_crown":
			style = &"scatter"
			color = Color(1.0, 0.68, 0.3)
			length = 15.0
			recoil = 6.0
		&"rifle", &"longbow", &"rail_spike":
			style = &"marksman"
			color = Color(1.0, 0.5, 0.7)
			length = 23.0
			recoil = 5.0
		&"orb", &"hex_bolt", &"nova_core":
			style = &"arcane"
			color = Color(0.75, 0.55, 1.0)
			length = 12.0
			recoil = 3.0
		&"smg":
			length = 9.0
			recoil = 2.5
			color = Color(0.55, 1.0, 0.6)
		&"twin_fangs":
			length = 14.0
			recoil = 3.5
	var evolved := id in [&"twin_fangs", &"flak_crown", &"rail_spike", &"nova_core"]
	return {"weapon_id": id, "style": style, "color": color, "length": length,
			"recoil": recoil, "evolved": evolved}


static func _draw_art(ci: CanvasItem, key: StringName, center: Vector2, size: Vector2,
		rotation: float, tint: Color, flip_x: bool = false) -> bool:
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.region(key)
	if tex == null or not source.has_area():
		return false
	var fitted := _contained_size(source.size, size)
	ci.draw_set_transform(center, rotation, Vector2(-1.0 if flip_x else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-fitted * 0.5, fitted), source, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _draw_art_foot(ci: CanvasItem, key: StringName, foot: Vector2, bounds: Vector2,
		rotation: float, tint: Color, flip_x: bool = false) -> bool:
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.region(key)
	if tex == null or not source.has_area():
		return false
	var fitted := _contained_size(source.size, bounds)
	var local_center := _foot_center(Vector2.ZERO, fitted)
	ci.draw_set_transform(foot, rotation, Vector2(-1.0 if flip_x else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(local_center - fitted * 0.5, fitted), source, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _contained_size(source: Vector2, bounds: Vector2) -> Vector2:
	if source.x <= 0.0 or source.y <= 0.0 or bounds.x <= 0.0 or bounds.y <= 0.0:
		return Vector2.ZERO
	var scale := minf(bounds.x / source.x, bounds.y / source.y)
	return source * scale


static func _foot_center(foot: Vector2, fitted_size: Vector2) -> Vector2:
	return foot - Vector2(0.0, fitted_size.y * 0.5)


static func _fitted_art_size(key: StringName, bounds: Vector2) -> Vector2:
	var source := PresentationAssets.region(key)
	return _contained_size(source.size, bounds) if source.has_area() else Vector2.ZERO


static func _weapon_size(key: StringName) -> Vector2:
	match key:
		&"weapon_longbow":
			return Vector2(30.0, 46.0)
		&"weapon_rifle", &"weapon_rail_spike":
			return Vector2(48.0, 17.0)
		&"weapon_smg":
			return Vector2(40.0, 19.0)
		&"weapon_shotgun":
			return Vector2(44.0, 20.0)
		&"weapon_flechette", &"weapon_hex_bolt", &"weapon_twin_fangs":
			return Vector2(40.0, 22.0)
		&"weapon_flak_crown", &"weapon_nova_core":
			return Vector2(44.0, 22.0)
		&"weapon_orb":
			return Vector2(38.0, 24.0)
		_:
			return Vector2(38.0, 21.0)


static func _elite_color(kind: StringName) -> Color:
	match kind:
		&"overclocked":
			return Color(0.35, 0.9, 1.0)
		&"bulwark":
			return Color(0.55, 0.7, 1.0)
		&"volatile":
			return Color(1.0, 0.55, 0.25)
		_:
			return Color(0.8, 0.5, 1.0)


static func _enemy_bounds(id: StringName) -> Vector2:
	match id:
		&"runner":
			return Vector2(30.0, 30.0)
		&"brute":
			return Vector2(58.0, 44.0)
		&"silencer":
			return Vector2(42.0, 50.0)
		&"bomber":
			return Vector2(40.0, 36.0)
		&"warden":
			return Vector2(56.0, 46.0)
		&"paradox":
			return Vector2(88.0, 72.0)
		_:
			return Vector2(36.0, 30.0)


static func _character_bounds(id: StringName) -> Vector2:
	match id:
		&"solo":
			return Vector2(44.0, 56.0)
		&"mirror":
			return Vector2(48.0, 58.0)
		&"conductor":
			return Vector2(50.0, 56.0)
		_:
			return PLAYER_ART_SIZE


static func _uses_back_art(facing: Vector2) -> bool:
	return facing.y < -0.15


static func _horizontal_flip(facing: Vector2) -> bool:
	return facing.x < -0.05


static func _warden_rotation(facing: Vector2) -> float:
	if facing == Vector2.ZERO:
		return 0.0
	return facing.angle() - WARDEN_AUTHORED_FORWARD


static func _echo_facing(actor: EchoActor) -> Vector2:
	var next := actor.take.position_at(actor.t + EchoTake.SAMPLE_DT)
	var direction := next - actor.pos
	if direction == Vector2.ZERO:
		var previous := actor.take.position_at(maxf(0.0, actor.t - EchoTake.SAMPLE_DT))
		direction = actor.pos - previous
	return direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT


static func _draw_weapon_loadout(ci: CanvasItem, sim: Sim, origin: Vector2,
		weapons: Array[WeaponDef], fallback: Vector2, bob: float, alpha: float,
		actor_tint: Color, tint_weight: float, size_mult: float, source: int = -1,
		recoils: Array[Dictionary] = []) -> void:
	var count := weapons.size()
	if count <= 0:
		return
	var aim := _aim_direction(sim, origin, fallback)
	var normal := Vector2(-aim.y, aim.x)
	var crowd_scale := 0.78 if count >= 5 else (0.86 if count == 4 else 1.0)
	for i in count:
		var w: WeaponDef = weapons[i]
		var slot := _weapon_slot(i, count)
		var recoil := _mounted_recoil(recoils, source, w.id)
		var mount := origin + aim * (slot.x - recoil) + normal * slot.y + Vector2(0.0, bob)
		var key := PresentationAssets.weapon_key(w)
		var size := _weapon_size(key) * crowd_scale * size_mult
		var color := w.color.lerp(actor_tint, tint_weight).lerp(Color.WHITE, 0.35)
		_draw_art(ci, key, mount, size, aim.angle(), Color(color, alpha))


static func _mounted_recoil(recoils: Array[Dictionary], source: int, weapon_id: StringName) -> float:
	# ShotInfo has no slot. Matching duplicates deliberately kick as one source+ID visual group.
	var amount := 0.0
	for data in recoils:
		if int(data["source"]) != source or data["weapon_id"] != weapon_id:
			continue
		var profile: Dictionary = data["profile"]
		amount = maxf(amount, float(profile["recoil"]) * float(data["life"]) / float(data["max_life"]))
	return amount


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
