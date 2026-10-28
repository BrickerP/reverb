class_name ArenaPainter
extends RefCounted

const FILL := Color("777d68")
const PAPER := Color("e5d8b8")
const INK := Color("292720")
const BORDER := INK
const PLAYER := PAPER
const DANGER := Color("be5749")
const MAX_PATH_POINTS := 18
# Above this many bullets, trails are dropped; the heads still carry direction and readability.
const TRAIL_LIMIT := 160
# Above this many bullets, heads are drawn through one MultiMesh instead of one draw call each.
const BATCH_LIMIT := 80
const PLAYER_ART_SIZE := Vector2(50.0, 58.0)
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
		ci.draw_texture_rect(floor_texture, a, false, Color(1.0, 1.0, 1.0, 0.88))
	# A quiet floor and a heavy ink perimeter leave moving silhouettes in charge.
	ci.draw_rect(a, Color(INK, 0.10))
	ci.draw_rect(a.grow(3.0), Color(INK, 0.18), false, 8.0)
	ci.draw_rect(a, INK, false, 3.0)
	for side: float in [-1.0, 1.0]:
		var x := a.get_center().x + side * (a.size.x * 0.5 - 14.0)
		for k in 5:
			var y := a.position.y + 25.0 + float(k) * (a.size.y - 50.0) / 4.0
			ci.draw_line(Vector2(x - 5.0, y - 3.0), Vector2(x + 5.0, y + 3.0), Color(INK, 0.22), 2.0)


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
	var color := _elite_color(spawn.elite_kind) if spawn.elite_kind != &"" else DANGER
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
	var collapse := p * p * (0.25 if reduced else 1.0)
	var target := sim.player.pos
	var stride := maxi(3, ceili(float(take.samples.size()) / 36.0))
	for i in range(0, take.samples.size() - stride, stride * 2):
		var a := take.samples[i].lerp(target, collapse)
		var b := take.samples[i + stride].lerp(target, collapse)
		ci.draw_line(a, b, Color(INK, 0.45 * (1.0 - p)), 2.0)
	# The recording becomes a small tangible paper copy before it enters the shop.
	var paper_pos := target + Vector2(0.0, -18.0 - 28.0 * p)
	var rect := Rect2(paper_pos - Vector2(10.0, 13.0), Vector2(20.0, 26.0))
	ci.draw_rect(rect, Color(PAPER, 1.0 - p))
	ci.draw_rect(rect, Color(INK, 1.0 - p), false, 2.0)
	ci.draw_line(rect.position + Vector2(4.0, 7.0), rect.position + Vector2(15.0, 7.0),
			Color(INK, 1.0 - p), 2.0)


static func victory(ci: CanvasItem, origin: Vector2, _color: Color, t: float,
		reduced: bool = false) -> void:
	var p := clampf(t, 0.0, 1.0)
	var flash := victory_flash_alpha(p, reduced)
	if flash > 0.0:
		ci.draw_rect(Sim.ARENA, Color(PAPER, flash))
	var alpha := minf(1.0, p * 8.0) * (1.0 - maxf(0.0, p - 0.6) / 0.4)
	var stamp_scale := 1.0 if reduced else 1.0 + maxf(0.0, 1.0 - p * 6.0) * 0.4
	var text := Loc.t("hud.boss_down")
	var width := UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x + 32.0
	ci.draw_set_transform(origin, -0.09 if not reduced else 0.0, Vector2.ONE * stamp_scale)
	var rect := Rect2(-width * 0.5, -28.0, width, 56.0)
	ci.draw_rect(rect, Color(PAPER, alpha * 0.94))
	ci.draw_rect(rect, Color(DANGER, alpha), false, 4.0)
	ci.draw_rect(rect.grow(-7.0), Color(DANGER, alpha * 0.7), false, 1.0)
	ci.draw_string(UiTheme.font(), Vector2(-width * 0.5 + 16.0, 8.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, width - 32.0, 22, Color(DANGER, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func victory_flash_alpha(progress: float, reduced: bool) -> float:
	return 0.0 if reduced else 0.16 * maxf(0.0, 1.0 - clampf(progress, 0.0, 1.0) * 2.4)


static func echo_paths(ci: CanvasItem, sim: Sim, paths: Dictionary, reveal: Dictionary,
		reduced: bool = false) -> void:
	for actor in sim.echoes:
		var pts: PackedVector2Array = paths.get(actor, PackedVector2Array())
		var shown := echo_path_window(actor, pts, float(reveal.get(actor, 1.0)))
		var tint := paper_echo_color(actor.take.tint())
		var alpha := 0.14 if reduced else 0.28
		if sim.echo_silenced > 0.0:
			alpha *= 0.4
		for i in range(0, shown.size() - 1, 2):
			var fade := 0.3 + 0.7 * float(i + 1) / float(maxi(1, shown.size()))
			ci.draw_line(shown[i], shown[i + 1], Color(tint, alpha * fade), 2.0)


# A bounded playback neighbourhood replaces the old full-screen route carpet.


static func echo_path_window(actor: EchoActor, points: PackedVector2Array,
		reveal_progress: float = 1.0) -> PackedVector2Array:
	if points.size() < 2:
		return PackedVector2Array()
	var duration := actor.take.duration()
	var progress := actor.take.playback_time(actor.t) / duration if duration > 0.0 else 0.0
	if reveal_progress < 1.0:
		progress = clampf(reveal_progress, 0.0, 1.0)
	var head := clampi(roundi(progress * float(points.size() - 1)), 0, points.size() - 1)
	var end := mini(points.size(), head + 2)
	return points.slice(maxi(0, end - MAX_PATH_POINTS), end)


static func paper_echo_color(identity: Color) -> Color:
	return identity.lerp(Color("77755f"), 0.55).lerp(PAPER, 0.18)


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
			ci.draw_arc(sim.player.pos, radius, float(k) * step, float(k + 1) * step, 4, Color(PAPER, 0.16), 1.0)


static func rifts(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	for r in sim.rifts:
		var active := r.telegraph <= 0.0
		var progress := 1.0 if active else 1.0 - clampf(r.telegraph / TemporalRift.TELEGRAPH_TIME, 0.0, 1.0)
		ci.draw_circle(r.pos, r.radius, Color(DANGER, 0.15 if active else 0.045))
		# The ink circle always matches the exact simulation radius, including reduced effects.
		ci.draw_arc(r.pos, r.radius, 0.0, TAU, 48, Color(DANGER, 0.85 if active else 0.35 + progress * 0.35), 3.0)
		var marks := 12
		for k in marks:
			if not active and k % 2 == 1:
				continue
			var direction := Vector2.from_angle(TAU * float(k) / float(marks))
			ci.draw_line(r.pos + direction * (r.radius - 8.0), r.pos + direction * r.radius,
					Color(INK if active else DANGER, 0.6), 2.0)
		if active:
			var wobble := 0.0 if reduced else sin(sim.wave_time * 3.0) * 1.2
			var crease := PackedVector2Array([
				r.pos + Vector2(-r.radius * 0.55, -5.0), r.pos + Vector2(-r.radius * 0.15, 7.0 + wobble),
				r.pos + Vector2(r.radius * 0.15, -8.0), r.pos + Vector2(r.radius * 0.55, 4.0),
			])
			ci.draw_polyline(crease, Color(INK, 0.7), 3.0)
		else:
			ci.draw_arc(r.pos, r.radius * progress, 0.0, TAU, 32, Color(DANGER, 0.28), 1.5)


static func pickups(ci: CanvasItem, sim: Sim) -> void:
	for pk in sim.pickups:
		var rect := Rect2(pk.pos - Vector2(3.0, 4.0), Vector2(6.0, 8.0))
		ci.draw_rect(rect, PAPER)
		ci.draw_rect(rect, INK, false, 1.0)
		ci.draw_line(rect.position + Vector2(1.5, 3.0), rect.position + Vector2(4.5, 3.0), INK, 1.0)


static func enemies(ci: CanvasItem, sim: Sim, reduced: bool = false, visual_time: float = -1.0) -> void:
	var target := sim.player.pos
	var clock := sim.wave_time if visual_time < 0.0 else visual_time
	for e in sim.enemies:
		var col := _elite_color(e.elite_kind) if e.elite else DANGER
		if e.flash > 0.0:
			col = Color.WHITE
		var key := PresentationAssets.enemy_key(e.def)
		var stride := sin(clock * (7.5 if e.def.id == &"runner" else 4.5)
				+ e.pos.x * 0.021 + e.pos.y * 0.013) * (REDUCED_MOTION_SCALE if reduced else 1.0)
		var facing := (target - e.pos).normalized()
		if facing == Vector2.ZERO:
			facing = Vector2.RIGHT
		var art_size := _enemy_bounds(e.def.id) * e.radius / maxf(1.0, e.def.radius)
		art_size *= Vector2(1.0 + absf(stride) * 0.025, 1.0 - absf(stride) * 0.018)
		var art_tint := Color(1.0, 0.76, 0.68) if e.flash > 0.0 else Color.WHITE
		var frame := actor_frame(key, clock + float(e.uid) * 0.137, e.speed > 0.0, e.flash > 0.0, reduced)
		var foot := e.pos + Vector2(0.0, e.radius * 0.72 + stride * minf(1.8, e.radius * 0.08))
		var rotation := _warden_rotation(facing) if e.def.id == &"warden" else 0.0
		var flip := facing.x > 0.0 and e.def.id != &"warden"
		if e.def.is_boss:
			var boss_art := boss_art_profile(sim.boss_phase, sim.boss_shards.find(e), clock, reduced)
			frame = int(boss_art["frame"])
			flip = bool(boss_art["flip"])
		if e.def.id == &"warden":
			# The shield arc is centered on e.pos. Rotate the authored shield body around the same
			# point; a foot pivot makes its center orbit away from the gameplay-facing arc.
			_draw_art(ci, key, e.pos, art_size, rotation, art_tint, false, frame)
		else:
			_draw_art_foot(ci, key, foot, art_size, rotation, art_tint, flip, frame)
		if e.def.is_boss:
			# A torn original has an ink footprint, not a luminous mechanical halo.
			ci.draw_arc(e.pos, e.radius + 5.0, 0.0, TAU, 28, Color(INK, 0.65), 2.0)
			if sim.boss_phase >= 2 and sim.boss_shards.has(e):
				var notch := PackedVector2Array([e.pos + Vector2(-8.0, -e.radius - 7.0),
					e.pos + Vector2(0.0, -e.radius), e.pos + Vector2(8.0, -e.radius - 7.0)])
				ci.draw_polyline(notch, DANGER, 3.0)
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
	if sim.boss_phase >= 2:
		var alive: Array[EnemyState] = []
		for boss_shard in sim.boss_shards:
			if not boss_shard.dead:
				alive.append(boss_shard)
		if alive.size() == 2:
			var a := alive[0]
			var b := alive[1]
			var mid := (a.pos + b.pos) * 0.5
			var pulse := 0.5 + 0.5 * sin(sim.wave_time * 5.0)
			var link := Color(INK, 0.3 + 0.12 * pulse)
			ci.draw_line(a.pos, mid, link, 2.0)
			ci.draw_line(mid, b.pos, link, 2.0)
			ci.draw_rect(Rect2(mid - Vector2(5.0, 2.0), Vector2(10.0, 4.0)), PAPER)
			ci.draw_rect(Rect2(mid - Vector2(5.0, 2.0), Vector2(10.0, 4.0)), INK, false, 1.0)


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
		recoils: Array[Dictionary] = [], reduced: bool = false, visual_time: float = -1.0) -> void:
	var r := PlayerState.RADIUS
	var lifespan := maxi(1, sim.echo_lifespan())
	var clock := sim.wave_time if visual_time < 0.0 else visual_time
	for actor in sim.echoes:
		var c := paper_echo_color(actor.take.tint())
		var remaining := maxi(0, lifespan - actor.take.age)
		var muted := sim.echo_silenced > 0.0
		var moving := actor.take.position_at(actor.t + EchoTake.SAMPLE_DT).distance_squared_to(actor.pos) > 0.01
		var motion_scale := REDUCED_MOTION_SCALE if reduced else 1.0
		var bob := _motion_bob(clock, actor.pos, 7.0, 1.0) * motion_scale if moving else 0.0
		var alpha := 0.25 if muted else lerpf(0.48, 0.72, float(remaining) / float(lifespan))
		var facing := _echo_facing(actor)
		var key := PresentationAssets.character_key(character_id, _uses_back_art(facing))
		var frame := actor_frame(key, clock + float(actor.index) * 0.13, moving, false, reduced)
		var foot := actor.pos + Vector2(0.0, r + bob)
		var art_size := _character_bounds(character_id)
		# A misregistered second print is a copy's silhouette, not another gameplay body.
		_draw_art_foot(ci, key, foot + Vector2(2.0, 0.0), art_size, 0.0,
				Color(c, alpha * 0.38), _horizontal_flip(facing), frame)
		_draw_art_foot(ci, key, foot, art_size, 0.0,
				Color(PAPER.lerp(c, 0.22), alpha), _horizontal_flip(facing), frame)
		var weapons: Array[WeaponDef] = sim.player.weapons if sim.live_echo else actor.take.weapons
		_draw_weapon_loadout(ci, sim, actor.pos, weapons, facing, bob, alpha,
				c, 0.45, 0.82, actor.index, recoils)
		var pips := mini(8, lifespan)
		for k in pips:
			var filled := float(k) / float(pips) < float(remaining) / float(lifespan)
			var rect := Rect2(actor.pos + Vector2(-14.0 + float(k) * 28.0 / float(pips), r + 3.0),
					Vector2(28.0 / float(pips) - 1.0, 3.0))
			ci.draw_rect(rect, c if filled else Color(INK, 0.25))
		if remaining <= 1:
			ci.draw_line(foot + Vector2(-12.0, 1.0), foot + Vector2(12.0, 1.0), DANGER, 2.0)
		if muted:
			ci.draw_line(actor.pos + Vector2(-6.0, -6.0), actor.pos + Vector2(6.0, 6.0), DANGER, 3.0)
			ci.draw_line(actor.pos + Vector2(6.0, -6.0), actor.pos + Vector2(-6.0, 6.0), DANGER, 3.0)
		elif actor.rewinding:
			for dx in [-4.0, 2.0]:
				var tip := actor.pos + Vector2(dx - 15.0, -6.0)
				ci.draw_polyline(PackedVector2Array([tip + Vector2(4.0, -3.0), tip,
					tip + Vector2(4.0, 3.0)]), Color(c, 0.8), 2.0)


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
			_bullet_mesh.set_instance_color(i, projectile_color(p))
		ci.draw_multimesh(_bullet_mesh, _bullet_texture)
		return
	for p in sim.projectiles:
		var dir := p.vel.normalized()
		if projectile_trails_enabled(reduced, count):
			ci.draw_line(p.pos - dir * (p.radius * 2.4 + 6.0), p.pos,
					Color(projectile_color(p), 0.38), p.radius * 1.2)
		ci.draw_circle(p.pos, p.radius + 1.0, INK)
		ci.draw_circle(p.pos, p.radius, projectile_color(p))


static func projectile_color(projectile: Projectile) -> Color:
	if projectile.crit:
		return Color("edc66d")
	return projectile.color.lerp(PAPER, 0.42).lerp(INK, 0.12)


static func projectile_trails_enabled(reduced: bool, count: int) -> bool:
	return not reduced and count <= TRAIL_LIMIT


static func _bullet_trails(ci: CanvasItem, sim: Sim) -> void:
	for p in sim.projectiles:
		var dir := p.vel.normalized()
		ci.draw_line(p.pos - dir * (p.radius * 2.4 + 6.0), p.pos, Color(projectile_color(p), 0.38), p.radius * 1.2)


static func _ensure_bullet_resources() -> void:
	if _bullet_mesh != null:
		return
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length()
			var fill := Color(0.18, 0.16, 0.13) if d > c - 3.0 else Color.WHITE
			image.set_pixel(x, y, Color(fill, clampf(c - d, 0.0, 1.0)))
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


# Walk frames share a single asset identity. Squash is a deliberately drawn fourth pose.


static func actor_frame(key: StringName, visual_time: float, moving: bool,
		hurt: bool = false, reduced: bool = false) -> int:
	var count := PresentationAssets.frame_count(key)
	if count <= 1:
		return 0
	if hurt:
		return mini(3, count - 1)
	if not moving:
		return 0
	var phase := posmod(int(floor(maxf(0.0, visual_time) * (5.0 if reduced else 8.0))), 4)
	var sequence: Array[int] = [0, 1, 0, 2]
	return mini(sequence[phase], count - 1)


# Boss cells have authored semantics: original, roar, left half, right half.
# Phase one must never borrow a torn half as a walk or generic hurt pose.
static func boss_art_profile(phase: int, shard_index: int, visual_time: float,
		reduced: bool = false) -> Dictionary:
	var count := maxi(1, PresentationAssets.frame_count(&"enemy_paradox"))
	var frame := 0
	if phase >= 2:
		frame = 2 + posmod(maxi(0, shard_index), 2)
	elif not reduced:
		frame = posmod(int(floor(maxf(0.0, visual_time) * 2.0)), 2)
	# Each tear edge is already drawn on its correct side; mirroring swaps its identity.
	return {"frame": mini(frame, count - 1), "flip": false}


static func player(ci: CanvasItem, sim: Sim, character_id: StringName = &"looper",
		motion: Dictionary = {}, recoils: Array[Dictionary] = []) -> void:
	var pl := sim.player
	var alpha := 1.0
	if pl.iframes > 0.0 and int(pl.iframes * 24.0) % 2 == 0:
		alpha = 0.35
	var r := PlayerState.RADIUS
	ci.draw_circle(pl.pos + Vector2(0.0, 5.0), r + 3.0, Color(INK, 0.22 * alpha))
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
	var frame := actor_frame(key, visual_time, move_weight > 0.05, pl.iframes > 0.22, reduced)
	_draw_art_foot(ci, key, foot, art_size, sway, Color(1.0, 1.0, 1.0, alpha),
			_horizontal_flip(facing), frame)
	var count := pl.weapons.size()
	# shot_fired only identifies its source actor, not the weapon or target. Keep presentation
	# stable by aiming the mounted loadout at the nearest live enemy, then falling back to facing.
	if count > 0:
		_draw_weapon_loadout(ci, sim, pl.pos, pl.weapons, pl.facing, bob, alpha,
				Color.WHITE, 0.0, 1.0, -1, recoils)


static func sparks(ci: CanvasItem, list: Array[Spark]) -> void:
	for s in list:
		var t := clampf(s.life / s.max_life, 0.0, 1.0)
		if s.ring:
			ci.draw_arc(s.pos, s.radius + (1.0 - t) * 46.0, 0.0, TAU, 24,
					Color(paper_echo_color(s.color), t * 0.65), 2.0)
		else:
			var side := 2.0 + t * 2.5
			ci.draw_set_transform(s.pos, s.rotation, Vector2.ONE)
			var rect := Rect2(Vector2(-side, -side * 0.65), Vector2(side * 2.0, side * 1.3))
			ci.draw_rect(rect, Color(PAPER.lerp(paper_echo_color(s.color), 0.2), t))
			ci.draw_rect(rect, Color(INK, t * 0.8), false, 1.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		_ink_burst(ci, pos, length * 0.55 * t, Color(color, t), direction.angle())
		ci.draw_line(origin, origin - direction * float(profile["recoil"]) * t,
				Color(color, 0.45 * t), 2.0)
		if bool(profile["evolved"]):
			ci.draw_arc(pos, 7.0 + 5.0 * (1.0 - t), 0.0, TAU, 14, Color(1.0, 1.0, 1.0, t), 1.5)
	for data in hits:
		var t := float(data["life"]) / float(data["max_life"])
		var pos: Vector2 = data["pos"]
		var direction: Vector2 = data["direction"]
		var normal := Vector2(-direction.y, direction.x)
		_ink_burst(ci, pos, (10.0 if bool(data["crit"]) else 6.0) * t, Color(PAPER, t), direction.angle())
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
		if data["effect"] == &"echo_collapse":
			var paper_size := Vector2(26.0, 32.0) * maxf(0.12, 1.0 - p * 3.0)
			var paper := Rect2(pos - paper_size * 0.5, paper_size)
			ci.draw_rect(paper, Color(PAPER, t))
			ci.draw_rect(paper, Color(INK, t), false, 2.0)
			_ink_burst(ci, pos, radius * p, Color(DANGER, t * 0.8), p * 0.3)
			ci.draw_arc(pos, radius * p, 0.0, TAU, 40, Color(DANGER, t), 3.0)
		elif data["kind"] == ExplosionInfo.BOMBER:
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


static func _ink_burst(ci: CanvasItem, center: Vector2, radius: float,
		color: Color, rotation: float = 0.0) -> void:
	var points := ink_burst_points(radius)
	if points.is_empty() or color.a <= 0.01 or not center.is_finite() or not is_finite(rotation):
		return
	# Triangulate around zero, then place the finished shape. Absolute arena coordinates
	# caused float cancellation in Godot's ear-clipping test as the star faded below a pixel.
	ci.draw_set_transform(center, rotation, Vector2.ONE)
	ci.draw_colored_polygon(points, color)
	points.append(points[0])
	ci.draw_polyline(points, Color(INK, color.a), 1.4)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func ink_burst_points(radius: float) -> PackedVector2Array:
	if not is_finite(radius) or radius < 0.75:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for i in 10:
		var length := radius if i % 2 == 0 else radius * 0.4
		points.append(Vector2.from_angle(TAU * float(i) / 10.0) * length)
	return points


static func weapon_feedback_profile(id: StringName) -> Dictionary:
	var style: StringName = &"sidearm"
	var color := Color("c5a14d")
	var length := 12.0
	var recoil := 4.0
	match id:
		&"shotgun", &"flechette", &"flak_crown":
			style = &"scatter"
			color = Color("c78346")
			length = 15.0
			recoil = 6.0
		&"rifle", &"longbow", &"rail_spike":
			style = &"marksman"
			color = Color("be5749")
			length = 23.0
			recoil = 5.0
		&"orb", &"hex_bolt", &"nova_core":
			style = &"arcane"
			color = Color("8f7a95")
			length = 12.0
			recoil = 3.0
		&"smg":
			length = 9.0
			recoil = 2.5
			color = Color("82935e")
		&"twin_fangs":
			length = 14.0
			recoil = 3.5
	var evolved := id in [&"twin_fangs", &"flak_crown", &"rail_spike", &"nova_core"]
	return {"weapon_id": id, "style": style, "color": color, "length": length,
			"recoil": recoil, "evolved": evolved}


static func _draw_art(ci: CanvasItem, key: StringName, center: Vector2, size: Vector2,
		rotation: float, tint: Color, flip_x: bool = false, frame: int = 0) -> bool:
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.frame_region(key, frame)
	if tex == null or not source.has_area():
		return false
	var fitted := _contained_size(source.size, size)
	ci.draw_set_transform(center, rotation, Vector2(-1.0 if flip_x else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-fitted * 0.5, fitted), source, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _draw_art_foot(ci: CanvasItem, key: StringName, foot: Vector2, bounds: Vector2,
		rotation: float, tint: Color, flip_x: bool = false, frame: int = 0) -> bool:
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.frame_region(key, frame)
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
			return Color("bf9e48")
		&"bulwark":
			return Color("748894")
		&"volatile":
			return DANGER
		&"splitter":
			return Color("82935e")
		_:
			return Color("8f7a95")


static func _enemy_bounds(id: StringName) -> Vector2:
	match id:
		&"runner":
			return Vector2(38.0, 38.0)
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
			return Vector2(42.0, 40.0)


static func _character_bounds(id: StringName) -> Vector2:
	match id:
		&"solo":
			return Vector2(50.0, 62.0)
		&"mirror":
			return Vector2(54.0, 64.0)
		&"conductor":
			return Vector2(58.0, 64.0)
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
		var color := Color.WHITE.lerp(actor_tint, tint_weight * 0.55)
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
