class_name ArenaView
extends Node2D

const MAX_SPARKS := 260
const PATH_STRIDE := 3
const REVEAL_TIME := 0.8
const RECORD_BEAT := 0.6
const VICTORY_BEAT := 0.9
const MAX_MUZZLES := 48
const MAX_HITS := 96
const MAX_EXPLOSIONS := 24
const MAX_HURTS := 8
const MAX_WEAPON_CHANGES := 12

var sim: Sim
var character_id: StringName = &"looper"
var _backdrop: ArenaBackdrop
var _paths: Dictionary = {}
var _reveal: Dictionary = {}
var _sparks: Array[Spark] = []
var _shake: float = 0.0
var _beat_take: EchoTake
var _beat_time := 0.0
var _victory := false
var _victory_time := 0.0
var _victory_origin := Vector2.ZERO
var _victory_color := Color.WHITE
var _boss_death_origin := Vector2.ZERO
var shake_enabled := true
var reduced_effects := false
var _paused := false
var _visual_time := 0.0
var _motion_amount := 0.0
var _motion_speed := 0.0
var _actor_motion: Dictionary = {}
var _actor_positions: Dictionary = {}
var _motion_sample_time := -1.0
var _cropped := false
var _muzzles: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _explosions: Array[Dictionary] = []
var _hurts: Array[Dictionary] = []
var _weapon_changes: Array[Dictionary] = []
var _last_event: Dictionary = {}
var _noise_counter := 0
var _director := BattleDirector.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_backdrop = ArenaBackdrop.new()
	_backdrop.show_behind_parent = true
	add_child(_backdrop)
	_sync_backdrop()


func bind(s: Sim, id: StringName = &"looper") -> void:
	if s == null:
		unbind()
		return
	if sim != null:
		_disconnect_sim(sim)
	sim = s
	character_id = id
	_paths.clear()
	_reveal.clear()
	_sparks.clear()
	_shake = 0.0
	_beat_take = null
	_beat_time = 0.0
	_victory = false
	_victory_time = 0.0
	_boss_death_origin = Vector2.ZERO
	_visual_time = 0.0
	_motion_amount = 0.0
	_motion_speed = 0.0
	_paused = false
	_noise_counter = 0
	_clear_feedback()
	_director.clear()
	_reset_motion()
	_update_camera()
	sim.enemy_killed.connect(_on_kill)
	sim.shot_fired_info.connect(_on_shot_info)
	sim.damage_event.connect(_on_damage_info)
	sim.player_hurt_info.connect(_on_hurt_info)
	sim.explosion_info.connect(_on_explosion_info)
	sim.weapon_changed.connect(_on_weapon_changed)
	sim.echo_spawned.connect(_on_echo)
	sim.boss_spawned.connect(_on_boss_spawned)
	sim.boss_phase_changed.connect(_on_boss_phase_changed)
	sim.boss_shard_spawned.connect(_on_boss_shard_spawned)
	sim.boss_shard_defeated.connect(_on_boss_shard_defeated)
	sim.boss_enraged.connect(_on_boss_enraged)
	sim.echoes_silenced.connect(_on_echo_silence)
	sim.wave_started.connect(_on_wave_started)
	sim.wave_ended.connect(_on_wave_phase)
	sim.run_lost.connect(_on_run_lost)
	sim.run_won.connect(_on_run_won)
	for actor in sim.echoes:
		var points := PackedVector2Array()
		for index in range(0, actor.take.samples.size(), PATH_STRIDE):
			points.append(actor.take.samples[index])
		_paths[actor] = points
		_reveal[actor] = 1.0
	_sync_backdrop()


func unbind() -> void:
	if sim != null:
		_disconnect_sim(sim)
	sim = null
	character_id = &"looper"
	_paths.clear()
	_reveal.clear()
	_sparks.clear()
	_clear_feedback()
	_director.clear()
	_actor_motion.clear()
	_actor_positions.clear()
	_motion_sample_time = -1.0
	_shake = 0.0
	_beat_take = null
	_beat_time = 0.0
	_victory = false
	_victory_time = 0.0
	_boss_death_origin = Vector2.ZERO
	_visual_time = 0.0
	_motion_amount = 0.0
	_motion_speed = 0.0
	_paused = false
	position = Vector2.ZERO
	_sync_backdrop()
	queue_redraw()


func set_paused(on: bool) -> void:
	_paused = on
	if on:
		_update_camera()
	_sync_backdrop()


# Main clips this node beneath the fixed HUD-safe viewport. Parent translation
# affects drawing only; all samples, attacks and paths retain world positions.
func set_cropped(on: bool) -> void:
	_cropped = on
	_update_camera()


func camera_profile() -> Dictionary:
	var focus := sim.player.pos if sim != null else WorldArena.BOUNDS.get_center()
	var camera := WorldArena.camera_rect(focus)
	if sim != null:
		camera.position = (Vector2.ZERO if _cropped else WorldArena.VIEWPORT.position) - position
	return {"world_rect": camera, "offset": position, "cropped": _cropped}


func _update_camera(shake: Vector2 = Vector2.ZERO) -> void:
	if sim == null:
		position = Vector2.ZERO
		return
	var camera := WorldArena.camera_rect(sim.player.pos)
	var origin := (camera.position - shake).clamp(WorldArena.BOUNDS.position, WorldArena.BOUNDS.end - camera.size)
	position = (Vector2.ZERO if _cropped else WorldArena.VIEWPORT.position) - origin


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	_director.settle(on)
	_sync_backdrop()
	if not on:
		return
	_shake = 0.0
	_update_camera()
	_sparks.clear()
	_muzzles.clear()
	_weapon_changes.clear()
	queue_redraw()


# Called by Main between the last frame of a wave and the shop opening.
func play_record_beat(s: Sim) -> void:
	if s.bank.takes.is_empty():
		return
	_beat_take = s.bank.takes[s.bank.takes.size() - 1]
	_beat_time = 0.0
	queue_redraw()


# Called by Main when the boss dies; the end screen waits for this beat.
func play_victory_beat(s: Sim) -> void:
	_victory = true
	_victory_time = 0.0
	if shake_enabled and not reduced_effects:
		_shake = minf(1.0, _shake + 0.9)
	_victory_origin = s.player.pos
	_victory_color = ArenaPainter.PAPER
	if _boss_death_origin != Vector2.ZERO:
		_victory_origin = _boss_death_origin
	elif s.boss != null:
		_victory_origin = s.boss.pos
		_victory_color = s.boss.def.color
	var spark_count := 10 if reduced_effects else 30
	for i in spark_count:
		_spark(_victory_origin, _victory_color, 120.0 + _noise01(i) * 300.0,
				0.5 + _noise01(i + 41) * 0.4)
	var ring := _spark(_victory_origin, _victory_color, 0.0, 0.9)
	if ring != null:
		ring.ring = true
		ring.radius = 30.0
	queue_redraw()


func clear_victory() -> void:
	_victory = false
	_victory_time = 0.0
	_victory_origin = Vector2.ZERO
	queue_redraw()


func _physics_process(_delta: float) -> void:
	_sample_motion()


func _process(delta: float) -> void:
	if sim == null or _paused:
		return
	var running := sim.phase == Sim.Phase.WAVE
	if running:
		_director.step(delta)
		_visual_time += delta
	else:
		_director.step_terminal(delta)
	_shake = maxf(0.0, _shake - delta * 1.8)
	var shake_amount := _shake * _shake * (0.35 if reduced_effects else 1.0)
	_update_camera(Vector2(sin(_visual_time * 31.0), sin(_visual_time * 43.0 + 1.7)) * shake_amount * 9.0)
	_sample_motion()
	var keep := 0
	for s in _sparks:
		s.life -= delta
		if s.life > 0.0:
			s.pos += s.vel * delta
			s.rotation += s.spin * delta
			s.vel *= exp(-6.0 * delta)
			_sparks[keep] = s
			keep += 1
	_sparks.resize(keep)
	_expire_feedback(_muzzles, delta)
	_expire_feedback(_hits, delta)
	_expire_feedback(_explosions, delta)
	_expire_feedback(_hurts, delta)
	_expire_feedback(_weapon_changes, delta)
	# Fast-forward the recorded route once at wave start, so the echo's position has a visible cause.
	for actor in _reveal.keys():
		_reveal[actor] = minf(1.0, float(_reveal[actor]) + delta / REVEAL_TIME)
	if _beat_take != null:
		_beat_time = minf(RECORD_BEAT, _beat_time + delta)
		if _beat_time >= RECORD_BEAT:
			_beat_take = null
	if _victory:
		_victory_time = minf(VICTORY_BEAT, _victory_time + delta)
		if _victory_time >= VICTORY_BEAT:
			_victory = false
	_sync_backdrop()
	queue_redraw()


func _reset_motion() -> void:
	_actor_motion.clear()
	_actor_positions.clear()
	_motion_sample_time = sim.wave_time if sim != null else -1.0
	if sim != null:
		_store_actor_motion(-1, sim.player.pos, 0.0, 160.0)
		for actor in sim.echoes:
			_store_actor_motion(actor.take.uid, actor.pos, 0.0, 160.0)
		for enemy in sim.enemies:
			_store_actor_motion(-enemy.uid - 2, enemy.pos, 0.0, clampf(enemy.radius * 8.0, 100.0, 220.0))
	_motion_amount = 0.0
	_motion_speed = 0.0


func _sample_motion() -> void:
	if sim == null or _paused:
		return
	if sim.wave_time < _motion_sample_time:
		_reset_motion()
	if sim.phase != Sim.Phase.WAVE:
		for token in _actor_motion:
			_actor_motion[token]["moving"] = false
			_actor_motion[token]["amount"] = 0.0
		_motion_amount = 0.0
		_motion_speed = 0.0
		return
	if is_equal_approx(sim.wave_time, _motion_sample_time):
		return
	var elapsed := maxf(0.0, sim.wave_time - _motion_sample_time)
	_motion_sample_time = sim.wave_time
	var live: Dictionary = {-1: true}
	_store_actor_motion(-1, sim.player.pos, elapsed, 160.0)
	for actor in sim.echoes:
		live[actor.take.uid] = true
		_store_actor_motion(actor.take.uid, actor.pos, elapsed, 160.0)
	for enemy in sim.enemies:
		if enemy.dead:
			continue
		var token := -enemy.uid - 2
		live[token] = true
		_store_actor_motion(token, enemy.pos, elapsed, clampf(enemy.radius * 8.0, 100.0, 220.0))
	for token in _actor_positions.keys():
		if not live.has(token):
			_actor_positions.erase(token)
			_actor_motion.erase(token)
	var player_motion: Dictionary = _actor_motion[-1]
	_motion_amount = float(player_motion["amount"])
	_motion_speed = float(player_motion["amount"])


func _store_actor_motion(token: int, actor_pos: Vector2, elapsed: float, stride: float) -> void:
	var previous: Vector2 = _actor_positions.get(token, actor_pos)
	var distance := previous.distance_to(actor_pos)
	var phase := float(_actor_motion.get(token, {}).get("phase", 0.0))
	# Repositioning a body or looping a recording starts on a planted foot.
	if distance > 120.0 or not is_finite(distance):
		phase = 0.0
		distance = 0.0
	elif distance > 0.001:
		phase = fposmod(phase + distance * TAU / stride, TAU)
	var moving := distance > 0.001 and elapsed > 0.0
	var amount := clampf(distance / maxf(0.001, elapsed * 180.0), 0.0, 1.0) if moving else 0.0
	_actor_motion[token] = {"phase": phase, "moving": moving, "amount": amount}
	_actor_positions[token] = actor_pos


func _sync_backdrop() -> void:
	if _backdrop != null:
		_backdrop.set_presentation(_visual_time, reduced_effects, _paused)


func _draw() -> void:
	if sim == null:
		return
	ArenaPainter.pending(self, sim)
	if _beat_take == null:
		ArenaPainter.echo_paths(self, sim, _paths, _reveal, reduced_effects)
	else:
		ArenaPainter.record_beat(self, sim, _beat_take, _beat_time / RECORD_BEAT, reduced_effects)
	ArenaPainter.pickup_range(self, sim)
	ThreatInk.draw_enemy_zones(self, sim)
	ArenaPainter.rifts(self, sim, reduced_effects)
	ArenaPainter.pickups(self, sim)
	WeaponInk.draw_fields(self, sim, reduced_effects)
	ArenaPainter.actor_remains(self, _director, reduced_effects)
	ArenaPainter.boss_tear_body(self, _director, reduced_effects)
	ArenaPainter.enemies(self, sim, reduced_effects, _visual_time, _director, _actor_motion)
	ArenaPainter.echoes(self, sim, character_id, _muzzles, reduced_effects, _visual_time, _director, _actor_motion)
	ArenaPainter.boss_tear(self, _director, reduced_effects)
	ArenaPainter.projectiles(self, sim, reduced_effects)
	ArenaPainter.combat_feedback(self, _muzzles, _hits, _explosions, _hurts, _weapon_changes,
			reduced_effects)
	ArenaPainter.sparks(self, _sparks)
	# The original remains legible through decorative debris and routine hit ink.
	ArenaPainter.player(self, sim, character_id, motion_stats(), _muzzles, _director)
	if _victory:
		ArenaPainter.victory(self, _victory_origin, _victory_color,
				_victory_time / VICTORY_BEAT, reduced_effects)


func _on_kill(info: EnemyDeathInfo) -> void:
	_director.enemy_died(info, reduced_effects)
	var pos := info.pos
	var color := info.color
	var source := info.source
	_last_event = {"kind": &"kill", "enemy_id": info.enemy_id, "target_uid": info.target_uid,
		"pos": info.pos, "source": info.source, "weapon_id": info.weapon_id,
		"actor_token": info.actor_token, "source_tint": info.source_tint,
		"boss_phase": info.boss_phase, "shard_index": info.boss_shard_index}
	var tint := kill_color(info)
	var spark_count := 4 if reduced_effects else 8
	for i in spark_count:
		_spark(pos, tint, 90.0 + _noise01(i) * 160.0, 0.35 + _noise01(i + 9) * 0.25)
	if source >= 0:
		var ring := _spark(pos, tint, 0.0, 0.3)
		if ring != null:
			ring.ring = true
			ring.radius = 6.0


func _on_shot_info(info: ShotInfo) -> void:
	var actor_token := info.actor_token
	if not BattleDirector.is_copy_token(actor_token) and info.source >= 0:
		actor_token = 0
	if not reduced_effects:
		_director.shot(info)
	var profile := ArenaPainter.weapon_feedback_profile(info.weapon_id)
	# Combat.fire guarantees RIGHT for a zero-length target vector. Rich shot feedback mirrors
	# that projectile contract; damage/hurt events keep ZERO because AOE/overlap can be directionless.
	if reduced_effects:
		profile = profile.duplicate(true)
		profile["recoil"] = float(profile["recoil"]) * 0.5
	if BattleDirector.is_copy_token(info.actor_token):
		profile = profile.duplicate(true)
		var profile_color: Color = profile["color"]
		profile["color"] = profile_color.lerp(info.source_tint, 0.45)
	var direction := info.direction.normalized() if info.direction != Vector2.ZERO else Vector2.RIGHT
	_push_feedback(_muzzles, {"life": 0.14, "max_life": 0.14, "pos": info.origin + direction * 14.0,
			"origin": info.origin, "direction": direction, "source": info.source,
			"actor_token": actor_token, "source_tint": info.source_tint,
			"weapon_id": info.weapon_id, "level": info.level, "count": info.count,
			"sequence": info.sequence, "profile": profile}, MAX_MUZZLES)
	_last_event = {"kind": &"shot", "weapon_id": info.weapon_id, "direction": direction,
			"origin": info.origin, "source": info.source, "count": info.count,
			"actor_token": info.actor_token, "source_tint": info.source_tint,
			"sequence": info.sequence, "profile": profile}


func _on_damage_info(info: DamageInfo) -> void:
	_director.enemy_hit(info.target_uid)
	var has_direction := info.hit_dir != Vector2.ZERO
	var direction := info.hit_dir.normalized() if has_direction else Vector2.ZERO
	var hit_color := Color.WHITE
	if BattleDirector.is_copy_token(info.actor_token):
		hit_color = info.source_tint
	var weapon := Content.weapon(info.weapon_id)
	var heavy := weapon != null and weapon.attack_style in [&"slam", &"line", &"cone"]
	var hit_life := 0.28 if info.crit else (0.24 if heavy else 0.15)
	_push_feedback(_hits, {"life": hit_life, "max_life": hit_life,
			"pos": info.pos, "direction": direction, "crit": info.crit, "reduced": info.reduced,
			"weapon_id": info.weapon_id, "source": info.source, "effect": info.effect,
			"target_uid": info.target_uid, "actor_token": info.actor_token,
			"source_tint": info.source_tint, "color": hit_color, "has_direction": has_direction}, MAX_HITS)
	_last_event = {"kind": &"damage", "weapon_id": info.weapon_id, "direction": direction,
			"pos": info.pos, "source": info.source, "crit": info.crit,
			"actor_token": info.actor_token, "source_tint": info.source_tint,
			"reduced": info.reduced, "effect": info.effect, "has_direction": has_direction}
	var color := hit_color.lerp(Color(1.0, 1.0, 0.55), 0.8) if info.crit else hit_color
	_spark(info.pos, color, 100.0 if info.crit else 65.0, 0.2 if info.crit else 0.14)


# Identity is captured when the projectile/ability fires. A removed or reordered
# live slot cannot lend another copy's colour to this later kill.
func kill_color(info: EnemyDeathInfo) -> Color:
	if BattleDirector.is_copy_token(info.actor_token):
		return info.color.lerp(info.source_tint, 0.85)
	return info.color


func _on_hurt(_amount: float) -> void:
	var info := PlayerHurtInfo.new()
	info.amount = _amount
	info.pos = sim.player.pos if sim != null else Vector2.ZERO
	_on_hurt_info(info)


func _on_hit(pos: Vector2, amount: float, crit: bool, source: int) -> void:
	var info := DamageInfo.new()
	info.pos = pos
	info.amount = amount
	info.crit = crit
	info.source = source
	_on_damage_info(info)


func _on_hurt_info(info: PlayerHurtInfo) -> void:
	_director.player_hurt(info.source_uid if info.effect == &"contact" else -1)
	var has_direction := info.direction != Vector2.ZERO
	var direction := info.direction.normalized() if has_direction else Vector2.ZERO
	_push_feedback(_hurts, {"life": 0.35 if info.lethal else 0.22, "max_life": 0.35 if info.lethal else 0.22,
			"pos": info.pos, "direction": direction, "lethal": info.lethal, "effect": info.effect,
			"source": info.source, "source_uid": info.source_uid, "has_direction": has_direction}, MAX_HURTS)
	_last_event = {"kind": &"hurt", "direction": direction, "lethal": info.lethal,
			"pos": info.pos, "effect": info.effect, "source": info.source,
			"has_direction": has_direction}
	if shake_enabled and not reduced_effects:
		_shake = minf(1.0, _shake + (0.8 if info.lethal else 0.45))


func _on_echo(actor: EchoActor) -> void:
	var pts := PackedVector2Array()
	for i in range(0, actor.take.samples.size(), PATH_STRIDE):
		pts.append(actor.take.samples[i])
	_paths[actor] = pts
	# Newest first; older echoes start their reveal a beat later so the routes do not overlap in time.
	_reveal[actor] = -0.12 * float(maxi(0, sim.bank.takes.size() - 1 - actor.index))
	var ring := _spark(actor.pos, actor.take.tint(), 0.0, 0.6)
	if ring != null:
		ring.ring = true
		ring.radius = PlayerState.RADIUS


func react_retirement(info: EchoRetirementInfo) -> void:
	if not info.pos.is_finite():
		return
	_last_event = {"kind": &"retirement", "reason": info.reason, "uid": info.uid,
		"actor_token": info.actor_token, "skill": info.kind, "pos": info.pos,
		"source_tint": info.tint, "weapon_id": info.weapon_id}
	var count := 3 if info.exhausted or reduced_effects else 9
	for index in count:
		var tint := ArenaPainter.PAPER if index % 3 == 0 else info.tint
		_spark(info.pos, tint, 25.0 if info.exhausted else 80.0, 0.3)
	_actor_positions.erase(info.uid)
	_actor_motion.erase(info.uid)
	for actor in _paths.keys():
		if actor.take.uid == info.uid:
			_paths.erase(actor)
			_reveal.erase(actor)


func _on_boss_spawned(enemy: EnemyState) -> void:
	var ring := _spark(enemy.pos, enemy.def.color, 0.0, 0.9)
	if ring != null:
		ring.ring = true
		ring.radius = enemy.radius


func _on_boss_phase_changed(phase: int) -> void:
	if sim == null or phase < 2:
		return
	var origin := sim.boss.pos if sim.boss != null else sim.boss_origin()
	_director.begin_tear(origin)
	var ring := _spark(origin, ArenaPainter.PAPER, 0.0, 1.1)
	if ring != null:
		ring.ring = true
		ring.radius = 46.0
	if shake_enabled and not reduced_effects:
		_shake = minf(1.0, _shake + 0.7)


func _on_boss_shard_spawned(enemy: EnemyState) -> void:
	var ring := _spark(enemy.pos, ArenaPainter.PAPER, 0.0, 0.8)
	if ring != null:
		ring.ring = true
		ring.radius = enemy.radius
	for i in 8:
		_spark(enemy.pos, Color("8f7a95"), 80.0 + _noise01(i) * 180.0, 0.35)


func _on_boss_shard_defeated(enemy: EnemyState, remaining: int) -> void:
	_boss_death_origin = enemy.pos
	var count := 6 if reduced_effects else 16
	for i in count:
		_spark(enemy.pos, ArenaPainter.PAPER, 90.0 + _noise01(i) * 240.0, 0.4)
	var ring := _spark(enemy.pos, ArenaPainter.PAPER, 0.0, 0.55)
	if ring != null:
		ring.ring = true
		ring.radius = enemy.radius + 10.0
	if remaining > 0 and shake_enabled and not reduced_effects:
		_shake = minf(1.0, _shake + 0.45)


func _on_boss_enraged(enemy: EnemyState) -> void:
	var ring := _spark(enemy.pos, ArenaPainter.DANGER, 0.0, 0.8)
	if ring != null:
		ring.ring = true
		ring.radius = enemy.radius + 18.0
	if shake_enabled and not reduced_effects:
		_shake = minf(1.0, _shake + 0.5)


func _on_echo_silence(info: EchoSilenceInfo) -> void:
	if sim == null:
		return
	if info.kind == EchoSilenceInfo.CONTACT:
		if not _director.enemy_action(info.source_uid):
			return
	elif info.kind == EchoSilenceInfo.BOSS:
		_director.boss_roar()
	else:
		# Phase transition already has a tear snapshot. It is not another roar.
		return
	var definition := Content.enemy(info.enemy_id)
	var ring := _spark(info.pos, Color("77755f"), 0.0, 0.36)
	if ring != null:
		ring.ring = true
		ring.radius = definition.radius if definition != null else 12.0


func _on_explosion(pos: Vector2, radius: float, color: Color) -> void:
	var info := ExplosionInfo.new()
	info.pos = pos
	info.radius = radius
	info.color = color
	_on_explosion_info(info)


func _on_explosion_info(info: ExplosionInfo) -> void:
	_push_feedback(_explosions, {"life": 0.42, "max_life": 0.42, "pos": info.pos,
			"radius": info.radius, "color": info.color, "kind": info.kind,
			"weapon_id": info.weapon_id, "actor_token": info.actor_token,
			"source_tint": info.source_tint, "effect": info.effect}, MAX_EXPLOSIONS)
	_last_event = {"kind": &"explosion", "cause": info.kind, "weapon_id": info.weapon_id,
			"actor_token": info.actor_token, "source_tint": info.source_tint,
			"pos": info.pos, "radius": info.radius, "effect": info.effect}
	var ring := _spark(info.pos, info.color, 0.0, 0.35)
	if ring != null:
		ring.ring = true
		ring.radius = maxf(2.0, info.radius * 0.4)
	var spark_count := 2 if reduced_effects else 5
	for i in spark_count:
		_spark(info.pos, info.color, 60.0 + _noise01(i + 21) * 90.0,
				0.2 + _noise01(i + 31) * 0.15)


func _on_weapon_changed(info: WeaponChangeInfo) -> void:
	_push_feedback(_weapon_changes, {"life": 0.35, "max_life": 0.35, "index": info.index,
			"before_id": info.before_id, "after_id": info.after_id, "reason": info.reason,
			"pos": sim.player.pos if sim != null else Vector2.ZERO}, MAX_WEAPON_CHANGES)
	_last_event = {"kind": &"weapon_change", "index": info.index, "before_id": info.before_id,
			"after_id": info.after_id, "reason": info.reason}


func _spark(pos: Vector2, color: Color, speed: float, life: float) -> Spark:
	if _sparks.size() >= MAX_SPARKS:
		return null
	var s := Spark.new()
	s.pos = pos
	s.vel = Vector2.from_angle(TAU * _noise01(_noise_counter)) * speed
	_noise_counter += 1
	s.color = color
	s.rotation = TAU * _noise01(_noise_counter + 2)
	s.spin = (_noise01(_noise_counter + 3) - 0.5) * 14.0
	s.life = life
	s.max_life = life
	_sparks.append(s)
	return s


func feedback_counts() -> Dictionary:
	return {"muzzles": _muzzles.size(), "hits": _hits.size(), "explosions": _explosions.size(),
			"hurts": _hurts.size(), "recoils": _muzzles.size(),
			"weapon_changes": _weapon_changes.size(), "sparks": _sparks.size(),
			"corpses": _director.corpses.size(), "actor_actions": int(_director.counts()["shots"])}


func event_last_data() -> Dictionary:
	return _last_event.duplicate(true)


func motion_stats() -> Dictionary:
	return {"moving": _motion_amount > 0.05, "amount": _motion_amount, "speed": _motion_speed,
			"gait_phase": float(_actor_motion.get(-1, {}).get("phase", 0.0)),
			"visual_time": _visual_time, "paused": _paused, "reduced": reduced_effects,
			"max_recoil": recoil_amount()}


func recoil_amount(source: int = -999, weapon_id: StringName = &"") -> float:
	var amount := 0.0
	for data in _muzzles:
		if source != -999 and int(data["source"]) != source:
			continue
		if weapon_id != &"" and data["weapon_id"] != weapon_id:
			continue
		var profile: Dictionary = data["profile"]
		amount = maxf(amount, float(profile["recoil"]) * float(data["life"]) / float(data["max_life"]))
	return amount


func _push_feedback(queue: Array[Dictionary], data: Dictionary, cap: int) -> void:
	if queue.size() >= cap:
		queue.pop_front()
	queue.append(data)


func _expire_feedback(queue: Array[Dictionary], delta: float) -> void:
	var keep := 0
	for item in queue:
		item["life"] = float(item.get("life", 0.0)) - delta
		if float(item["life"]) > 0.0:
			queue[keep] = item
			keep += 1
	queue.resize(keep)


func _clear_feedback() -> void:
	_muzzles.clear()
	_hits.clear()
	_explosions.clear()
	_hurts.clear()
	_weapon_changes.clear()
	_last_event.clear()


func _on_wave_phase(_wave: int) -> void:
	_clear_feedback()
	_director.end_actions()
	_sparks.clear()


func _on_wave_started(_wave: int) -> void:
	_clear_feedback()
	_director.clear()
	_motion_amount = 0.0
	_motion_speed = 0.0
	_reset_motion()
	_update_camera()
	if sim == null:
		_paths.clear()
		_reveal.clear()
		return
	for actor in _paths.keys():
		if not sim.echoes.has(actor):
			_paths.erase(actor)
	for actor in _reveal.keys():
		if not sim.echoes.has(actor):
			_reveal.erase(actor)


func _on_run_lost() -> void:
	if sim != null:
		_director.lose_player(sim.player.pos, sim.player.facing, character_id)
	# Keep the final directional hurt/explosion long enough to render; discard routine combat cues.
	_muzzles.clear()
	_hits.clear()
	_weapon_changes.clear()
	_sparks.clear()


func _on_run_won() -> void:
	_clear_feedback()
	_director.end_actions()
	_sparks.clear()


func _noise01(index: int) -> float:
	return 0.5 + 0.5 * sin(float(index + 1) * 12.9898 + 78.233)


func _disconnect_sim(s: Sim) -> void:
	var pairs: Array = [
		[s.enemy_killed, _on_kill], [s.shot_fired_info, _on_shot_info],
		[s.damage_event, _on_damage_info], [s.player_hurt_info, _on_hurt_info],
		[s.explosion_info, _on_explosion_info], [s.weapon_changed, _on_weapon_changed],
		[s.echo_spawned, _on_echo], [s.boss_spawned, _on_boss_spawned],
		[s.boss_phase_changed, _on_boss_phase_changed],
		[s.boss_shard_spawned, _on_boss_shard_spawned],
		[s.boss_shard_defeated, _on_boss_shard_defeated],
		[s.boss_enraged, _on_boss_enraged],
		[s.echoes_silenced, _on_echo_silence], [s.wave_started, _on_wave_started],
		[s.wave_ended, _on_wave_phase],
		[s.run_lost, _on_run_lost], [s.run_won, _on_run_won],
	]
	for pair in pairs:
		var signal_value: Signal = pair[0]
		var callable: Callable = pair[1]
		if signal_value.is_connected(callable):
			signal_value.disconnect(callable)
