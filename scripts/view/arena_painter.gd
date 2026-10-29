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
const TRAIL_LIMIT := WeaponInk.TRAIL_LIMIT
const PLAYER_ART_SIZE := Vector2(50.0, 58.0)
const WARDEN_AUTHORED_FORWARD := 3.0 * PI / 4.0
const ARENA_FLOOR_PATH := "res://assets/presentation/surfaces/arena_floor.png"
const REDUCED_MOTION_SCALE := 0.3

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
	ThreatInk.draw_rifts(ci, sim, reduced)


static func pickups(ci: CanvasItem, sim: Sim) -> void:
	for pk in sim.pickups:
		var rect := Rect2(pk.pos - Vector2(3.0, 4.0), Vector2(6.0, 8.0))
		ci.draw_rect(rect, PAPER)
		ci.draw_rect(rect, INK, false, 1.0)
		ci.draw_line(rect.position + Vector2(1.5, 3.0), rect.position + Vector2(4.5, 3.0), INK, 1.0)


static func enemies(ci: CanvasItem, sim: Sim, reduced: bool = false, visual_time: float = -1.0,
		director: BattleDirector = null) -> void:
	var target := sim.player.pos
	var clock := sim.wave_time if visual_time < 0.0 else visual_time
	for e in sim.enemies:
		if e.dead or e.def == null:
			continue
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
		if director != null:
			frame = director.enemy_pose(key, e.uid, clock + float(e.uid) * 0.137, e.speed > 0.0, reduced)
		var foot := e.pos + Vector2(0.0, e.radius * 0.72 + stride * minf(1.8, e.radius * 0.08))
		var rotation := _warden_rotation(facing) if e.def.id == &"warden" else 0.0
		var flip := facing.x > 0.0 and e.def.id != &"warden"
		if e.def.is_boss:
			var roaring := director != null and director.is_boss_roaring()
			var boss_art := boss_art_profile(sim.boss_phase, sim.boss_shards.find(e), clock, reduced, roaring)
			frame = int(boss_art["frame"])
			flip = bool(boss_art["flip"])
		if e.def.id == &"warden":
			_draw_art(ci, key, e.pos, art_size, rotation, art_tint, false, frame)
		else:
			_draw_art_foot(ci, key, foot, art_size, rotation, art_tint, flip, frame)
		ThreatInk.draw_enemy_marks(ci, e, target, clock, reduced)
		if e.radius >= 15.0 and e.hp < e.max_hp:
			var fitted := _fitted_art_size(key, art_size)
			var art_top := e.pos.y - fitted.y * 0.5 if e.def.id == &"warden" else foot.y - fitted.y
			var top := Vector2(e.pos.x - e.radius, art_top - 6.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0, 3.0)), Color(0, 0, 0, 0.6))
			var ratio := clampf(e.hp / e.max_hp, 0.0, 1.0)
			ci.draw_rect(Rect2(top, Vector2(e.radius * 2.0 * ratio, 3.0)), col)
	ThreatInk.draw_boss_link(ci, sim, clock, reduced)


static func enemy_rule_profile(enemy: EnemyState, target: Vector2, wave_time: float,
		reduced: bool = false) -> Dictionary:
	return ThreatInk.profile(enemy, target, wave_time, reduced)


static func echoes(ci: CanvasItem, sim: Sim, character_id: StringName = &"looper",
		recoils: Array[Dictionary] = [], reduced: bool = false, visual_time: float = -1.0,
		director: BattleDirector = null) -> void:
	var r := PlayerState.RADIUS
	var clock := sim.wave_time if visual_time < 0.0 else visual_time
	for actor in sim.echoes:
		var profile := EchoInk.profile(actor, sim, clock, reduced)
		var c: Color = profile["tint"]
		var moving := sim.phase == Sim.Phase.WAVE and actor.take.position_at(actor.t + EchoTake.SAMPLE_DT).distance_squared_to(actor.pos) > 0.01
		var motion_scale := REDUCED_MOTION_SCALE if reduced else 1.0
		var bob := _motion_bob(clock, actor.pos, 7.0, 1.0) * motion_scale if moving else 0.0
		var alpha := float(profile["alpha"])
		var facing := _echo_facing(actor)
		var key := PresentationAssets.character_key(character_id, _uses_back_art(facing))
		var frame := actor_frame(key, clock + float(actor.index) * 0.13, moving, false, reduced)
		if director != null:
			frame = director.echo_pose(key, actor.take.get_instance_id(), clock + float(actor.index) * 0.13, moving, reduced)
		var foot := actor.pos + Vector2(0.0, r + bob)
		var paper_scale: Vector2 = profile["paper_scale"]
		var art_size := _character_bounds(character_id) * paper_scale
		var print_offset: Vector2 = profile["print_offset"]
		_draw_art_foot(ci, key, foot + print_offset, art_size, 0.0,
				Color(c, float(profile["offset_alpha"])), _horizontal_flip(facing), frame)
		var body_tint: Color = profile["body_tint"]
		_draw_art_foot(ci, key, foot, art_size, 0.0,
				Color(body_tint, alpha), _horizontal_flip(facing), frame)
		var weapons: Array[WeaponDef] = sim.player.weapons if sim.live_echo else actor.take.weapons
		_draw_weapon_loadout(ci, sim, actor.pos, weapons, facing, bob, alpha,
				c, 0.45, 0.82, actor.take.get_instance_id(), recoils)
		var fitted := _fitted_art_size(key, art_size)
		var art_rect := Rect2(Vector2(foot.x - fitted.x * 0.5, foot.y - fitted.y), fitted)
		EchoInk.draw_marks(ci, actor, art_rect, profile, reduced)


static func projectiles(ci: CanvasItem, sim: Sim, reduced: bool = false) -> void:
	WeaponInk.draw_projectiles(ci, sim, reduced)


static func projectile_color(projectile: Projectile) -> Color:
	return WeaponInk.projectile_color(projectile)


static func projectile_trails_enabled(reduced: bool, count: int) -> bool:
	return WeaponInk.trails_enabled(reduced, count)


static func actor_frame(key: StringName, visual_time: float, moving: bool,
		hurt: bool = false, reduced: bool = false) -> int:
	var count := PresentationAssets.frame_count(key)
	if count <= 1:
		return 0
	if hurt:
		return mini(3, count - 1)
	return BattleDirector.walk_pose(key, visual_time, moving, reduced)


# Boss cells have authored semantics: original, roar, left half, right half.
# Phase one must never borrow a torn half as a walk or generic hurt pose.
static func boss_art_profile(phase: int, shard_index: int, _visual_time: float,
		reduced: bool = false, roaring: bool = false) -> Dictionary:
	var count := maxi(1, PresentationAssets.frame_count(&"enemy_paradox"))
	var frame := 0
	if phase >= 2:
		frame = 2 + posmod(maxi(0, shard_index), 2)
	elif roaring and not reduced:
		frame = 1
	# Each tear edge is already drawn on its correct side; mirroring swaps its identity.
	return {"frame": mini(frame, count - 1), "flip": false}


static func player(ci: CanvasItem, sim: Sim, character_id: StringName = &"looper",
		motion: Dictionary = {}, recoils: Array[Dictionary] = [],
		director: BattleDirector = null) -> void:
	var pl := sim.player
	var alpha := 1.0
	if pl.hp > 0.0 and pl.iframes > 0.0 and int(pl.iframes * 24.0) % 2 == 0:
		alpha = 0.74
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
	if director != null:
		frame = director.player_pose(key, visual_time, move_weight > 0.05, reduced)
	if pl.hp <= 0.0:
		bob = 0.0
		sway = 0.0
		art_size = _character_bounds(character_id)
		foot = pl.pos + Vector2(0.0, r)
	_draw_art_foot(ci, key, foot, art_size, sway, Color(1.0, 1.0, 1.0, alpha),
			_horizontal_flip(facing), frame)
	var count := pl.weapons.size()
	# Mounts track the nearest living target between shot events. ShotInfo has no
	# weapon slot, so duplicate IDs deliberately share one actor's recoil group.
	if count > 0 and pl.hp > 0.0:
		_draw_weapon_loadout(ci, sim, pl.pos, pl.weapons, pl.facing, bob, alpha,
				Color.WHITE, 0.0, 1.0, -1, recoils)
	if pl.hp > 0.0:
		var fitted := _fitted_art_size(key, art_size)
		var body := Rect2(Vector2(foot.x - fitted.x * 0.5, foot.y - fitted.y), fitted)
		_draw_player_focus(ci, player_focus_profile(sim, body))


static func player_focus_profile(sim: Sim, body: Rect2) -> Dictionary:
	var nearby := 0
	if sim == null or not body.has_area() or sim.player.hp <= 0.0:
		return {"visible": false, "nearby": 0, "contours": []}
	# Actual body overlap, not a global enemy-count trigger. No enemy is made
	# transparent: silhouettes and shield/blast geometry retain their meaning.
	for enemy in sim.enemies:
		if not enemy.dead and enemy.def != null:
			var radius := maxf(enemy.radius, 25.0)
			if body.grow(radius).has_point(enemy.pos):
				nearby += 1
	for actor in sim.echoes:
		if body.grow(24.0).has_point(actor.pos):
			nearby += 1
	var contours: Array[PackedVector2Array] = []
	if nearby > 0:
		# Bowed paper edges hug the live silhouette. They leave head and feet open,
		# rather than putting another boxed label above a crowded combatant.
		for side: float in [-1.0, 1.0]:
			var x := body.get_center().x + side * (body.size.x * 0.5 + 3.0)
			contours.append(PackedVector2Array([
				Vector2(x - side * 3.0, body.position.y + 8.0),
				Vector2(x + side * 1.0, body.position.y + body.size.y * 0.31),
				Vector2(x + side * 2.0, body.position.y + body.size.y * 0.60),
				Vector2(x, body.end.y - 5.0),
				Vector2(x - side * 4.0, body.end.y - 1.0)]))
	return {"visible": nearby > 0, "nearby": nearby, "contours": contours}


static func _draw_player_focus(ci: CanvasItem, profile: Dictionary) -> void:
	if not bool(profile["visible"]):
		return
	for contour: PackedVector2Array in profile["contours"]:
		ci.draw_polyline(contour, Color("f3e8cc"), 6.0, true)
		ci.draw_polyline(contour, INK, 2.0, true)


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


# Dead actors have no collision body. Their finite snapshots sit below living threats.
static func actor_remains(ci: CanvasItem, director: BattleDirector, reduced: bool = false) -> void:
	for corpse in director.corpses:
		var profile := BattleDirector.corpse_profile(corpse, reduced)
		var id: StringName = corpse["enemy_id"]
		var definition := Content.enemy(id)
		if definition == null:
			continue
		var key := PresentationAssets.enemy_key(definition)
		var radius := float(corpse["radius"])
		var size := _enemy_bounds(id) * radius / maxf(1.0, definition.radius)
		var scale: Vector2 = profile["scale"]
		size *= scale
		var offset: Vector2 = profile["offset"]
		var pos: Vector2 = corpse["pos"]
		pos += offset
		var alpha := float(profile["alpha"])
		var facing: Vector2 = corpse["facing"]
		var rotation := float(profile["rotation"])
		var tint := Color(PAPER.lerp(corpse["color"], 0.10), alpha)
		var frame := int(profile["frame"])
		if id == &"silencer":
			ci.draw_set_transform(pos + Vector2(0.0, radius * 0.3), 0.0, Vector2(1.0, 0.28))
			ci.draw_circle(Vector2.ZERO, radius * (0.8 + float(profile["progress"]) * 0.4), Color(INK, alpha * 0.25))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if id == &"warden":
			_draw_art(ci, key, pos, size, _warden_rotation(facing) + rotation, tint, false, frame)
		else:
			var foot := pos + Vector2(0.0, radius * 0.72)
			_draw_art_foot(ci, key, foot, size, rotation, tint, facing.x > 0.0 and id != &"paradox", frame)
		if not reduced and id == &"brute":
			var progress := float(profile["progress"])
			for index in 4:
				var x := float(index) - 1.5
				var piece := pos + Vector2(x * 13.0 * progress, -12.0 - sin(progress * PI) * (24.0 + x * 3.0))
				ci.draw_rect(Rect2(piece, Vector2(4.0, 6.0)), Color(PAPER, alpha))
				ci.draw_line(piece, piece + Vector2(3.0, 4.0), Color(INK, alpha), 1.0)


# Discarded whole/half prints sit below the actual live boss bodies.
static func boss_tear_body(ci: CanvasItem, director: BattleDirector, reduced: bool = false) -> void:
	var profile := director.tear_profile(reduced)
	if profile.is_empty():
		return
	var origin: Vector2 = director.tear["pos"]
	var whole_alpha := float(profile["whole_alpha"])
	if whole_alpha > 0.01:
		var stretch: Vector2 = profile["stretch"]
		_draw_art(ci, &"enemy_paradox", origin, Vector2(104.0, 94.0) * stretch,
				0.0, Color(PAPER, whole_alpha), false, int(profile["frame"]))
	var half_alpha := float(profile["half_alpha"])
	if half_alpha > 0.01:
		for side in 2:
			var sign_x := -1.0 if side == 0 else 1.0
			var p := float(profile["stage_progress"])
			var offset := Vector2(sign_x * float(profile["spring"]), -sin(p * PI) * 7.0)
			# Transparent discarded prints spring locally; the actual dangerous bodies
			# are always drawn afterwards at their own authoritative positions.
			_draw_art(ci, &"enemy_paradox", origin + offset, Vector2(100.0, 90.0),
					sign_x * float(profile["rotation"]), Color(PAPER, half_alpha), false, 2 + side)


# The cut sits above the art, along its torn outer edge. Keep the face/body core
# clear: a centered pair of heavy zigzags would read as a censor bar over it.
static func boss_tear(ci: CanvasItem, director: BattleDirector, reduced: bool = false) -> void:
	var profile := director.tear_profile(reduced)
	if profile.is_empty():
		return
	var origin: Vector2 = director.tear["pos"]
	var stage: StringName = profile["stage"]
	var alpha := float(profile["seam_alpha"])
	var geometry := boss_tear_edge_geometry(profile)
	ci.draw_set_transform(origin, 0.0, Vector2.ONE)
	for edge: PackedVector2Array in geometry["edges"]:
		ci.draw_polyline(edge, Color(PAPER, alpha), float(geometry["paper_width"]), true)
		ci.draw_polyline(edge, Color(INK, alpha), float(geometry["ink_width"]), true)
	for thread: PackedVector2Array in geometry["threads"]:
		ci.draw_polyline(thread, Color(PAPER, alpha), float(geometry["thread_width"]), true)
		ci.draw_polyline(thread, Color(INK, alpha), 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if stage == &"tension":
		var pull := 7.0 + float(profile["stage_progress"]) * 9.0
		for side in 2:
			var sign_x := -1.0 if side == 0 else 1.0
			for index in 3:
				var start := origin + Vector2(sign_x * 40.0, -26.0 + float(index) * 22.0)
				var end := start + Vector2(sign_x * pull, -2.0)
				ci.draw_line(start, end, Color(PAPER, alpha), 5.0, true)
				ci.draw_line(start, end, Color(INK, alpha), 2.2, true)
	var fragment_alpha := float(profile["fragment_alpha"])
	if fragment_alpha > 0.01:
		var travel := float(profile["fragment_travel"])
		for index in 8:
			var sign_x := -1.0 if index % 2 == 0 else 1.0
			var row := floorf(float(index) * 0.5)
			var strip := origin + Vector2(sign_x * (20.0 + travel * (0.65 + row * 0.18)),
					-38.0 + row * 22.0 - travel * 0.18)
			var end := strip + Vector2(sign_x * (7.0 + row), 3.0)
			ci.draw_line(strip, end, Color(PAPER, fragment_alpha), 5.5, true)
			ci.draw_line(strip, end, Color(INK, fragment_alpha), 1.6, true)


static func boss_tear_edge_geometry(profile: Dictionary) -> Dictionary:
	if profile.is_empty():
		return {}
	var width := float(profile["seam_width"])
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	# The fixed authored edge is just beyond the first half's +X silhouette. Only
	# the discarded right edge opens out; neither gutter traverses the live face.
	var edge_x := 22.0
	for index in 9:
		var tooth := -2.5 if index % 2 == 0 else 2.5
		var y := -36.0 + float(index) * 8.0
		left.append(Vector2(edge_x + tooth, y))
		right.append(Vector2(edge_x + tooth + width, y))
	var threads: Array[PackedVector2Array] = []
	var stage: StringName = profile["stage"]
	for index in 4:
		var y := -28.0 + float(index) * 16.0
		if stage == &"tension":
			threads.append(PackedVector2Array([Vector2(edge_x - 4.0, y - 3.0),
					Vector2(edge_x + width + 4.0, y + 3.0)]))
		elif stage == &"snap":
			var p := float(profile["stage_progress"])
			threads.append(PackedVector2Array([Vector2(edge_x - 1.0, y),
					Vector2(edge_x - 4.0, y - 5.0 - p * 4.0)]))
			threads.append(PackedVector2Array([Vector2(edge_x + width + 2.0, y),
					Vector2(edge_x + width + 7.0 + p * 11.0, y + 5.0)]))
	return {"edges": [left, right], "threads": threads, "paper_width": 6.5,
		"ink_width": 2.8, "thread_width": 6.0}


static func combat_feedback(ci: CanvasItem, muzzles: Array[Dictionary], hits: Array[Dictionary],
		explosions: Array[Dictionary], hurts: Array[Dictionary], weapon_changes: Array[Dictionary],
		reduced: bool) -> void:
	WeaponInk.draw_feedback(ci, muzzles, hits, explosions, reduced)
	for data in explosions:
		if WeaponInk.owns_explosion(data):
			continue
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
	return WeaponInk.profile(id)


static func _draw_art(ci: CanvasItem, key: StringName, center: Vector2, size: Vector2,
		rotation: float, tint: Color, flip_x: bool = false, frame: int = 0) -> bool:
	if not center.is_finite() or not is_finite(rotation):
		return false
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.frame_region(key, frame)
	if tex == null or not source.has_area():
		return false
	var idle := PresentationAssets.idle_region(key)
	if not idle.has_area():
		return false
	var factor := art_pixel_scale(key, size)
	if factor <= 0.0:
		return false
	var neutral_center := idle.get_center() - PresentationAssets.region(key).position
	# Frame baselines may differ in authored sheets. Keep the neutral centre fixed
	# while compensating that drift; the Warden still rotates exactly around e.pos.
	neutral_center += PresentationAssets.frame_pivot(key, frame) - PresentationAssets.frame_pivot(key, 0)
	ci.draw_set_transform(center, rotation, Vector2(-1.0 if flip_x else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-neutral_center * factor, source.size * factor), source, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _draw_art_foot(ci: CanvasItem, key: StringName, foot: Vector2, bounds: Vector2,
		rotation: float, tint: Color, flip_x: bool = false, frame: int = 0) -> bool:
	if not foot.is_finite() or not is_finite(rotation):
		return false
	var tex := PresentationAssets.texture(key)
	var source := PresentationAssets.frame_region(key, frame)
	if tex == null or not source.has_area():
		return false
	var idle := PresentationAssets.idle_region(key)
	if not idle.has_area():
		return false
	var factor := art_pixel_scale(key, bounds)
	if factor <= 0.0:
		return false
	var pivot := PresentationAssets.frame_pivot(key, frame)
	ci.draw_set_transform(foot, rotation, Vector2(-1.0 if flip_x else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-pivot * factor, source.size * factor), source, tint)
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
	return PresentationAssets.idle_region(key).size * art_pixel_scale(key, bounds)


static func art_pixel_scale(key: StringName, bounds: Vector2) -> float:
	var reference := PresentationAssets.idle_region(key)
	if not reference.has_area() or not bounds.is_finite() or bounds.x <= 0.0 or bounds.y <= 0.0:
		return 0.0
	return minf(bounds.x / reference.size.x, bounds.y / reference.size.y)


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
	return ThreatInk.elite_color(kind)


static func _enemy_bounds(id: StringName) -> Vector2:
	return ThreatInk.art_bounds(id)


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
		actor_tint: Color, tint_weight: float, size_mult: float, actor_token: int = -1,
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
		var recoil := _mounted_recoil(recoils, actor_token, w.id)
		var mount := origin + aim * (slot.x - recoil) + normal * slot.y + Vector2(0.0, bob)
		var key := PresentationAssets.weapon_key(w)
		var size := _weapon_size(key) * crowd_scale * size_mult
		var color := Color.WHITE.lerp(actor_tint, tint_weight * 0.55)
		_draw_art(ci, key, mount, size, aim.angle(), Color(color, alpha))


static func _mounted_recoil(recoils: Array[Dictionary], actor_token: int, weapon_id: StringName) -> float:
	# ShotInfo has no slot. Duplicates kick together per take identity and weapon ID;
	# collapsing another copy must not transfer this reaction to a reused index.
	var amount := 0.0
	for data in recoils:
		if int(data["actor_token"]) != actor_token or data["weapon_id"] != weapon_id:
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
