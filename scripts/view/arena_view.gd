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
var shake_enabled := true
var reduced_effects := false
var _paused := false
var _visual_time := 0.0
var _last_player_pos := Vector2.ZERO
var _motion_amount := 0.0
var _motion_speed := 0.0
var _muzzles: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _explosions: Array[Dictionary] = []
var _hurts: Array[Dictionary] = []
var _weapon_changes: Array[Dictionary] = []
var _last_event: Dictionary = {}
var _noise_counter := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_backdrop = ArenaBackdrop.new()
	_backdrop.show_behind_parent = true
	add_child(_backdrop)


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
	_visual_time = 0.0
	_last_player_pos = sim.player.pos
	_motion_amount = 0.0
	_motion_speed = 0.0
	_paused = false
	_noise_counter = 0
	_clear_feedback()
	sim.enemy_killed.connect(_on_kill)
	sim.shot_fired_info.connect(_on_shot_info)
	sim.damage_event.connect(_on_damage_info)
	sim.player_hurt_info.connect(_on_hurt_info)
	sim.explosion_info.connect(_on_explosion_info)
	sim.weapon_changed.connect(_on_weapon_changed)
	sim.echo_spawned.connect(_on_echo)
	sim.boss_spawned.connect(_on_boss_spawned)
	sim.echoes_silenced.connect(_on_echo_silence)
	sim.wave_started.connect(_on_wave_started)
	sim.wave_ended.connect(_on_wave_phase)
	sim.run_lost.connect(_on_run_lost)
	sim.run_won.connect(_on_run_won)


func unbind() -> void:
	if sim != null:
		_disconnect_sim(sim)
	sim = null
	character_id = &"looper"
	_paths.clear()
	_reveal.clear()
	_sparks.clear()
	_clear_feedback()
	_shake = 0.0
	_beat_take = null
	_beat_time = 0.0
	_victory = false
	_victory_time = 0.0
	_visual_time = 0.0
	_last_player_pos = Vector2.ZERO
	_motion_amount = 0.0
	_motion_speed = 0.0
	_paused = false
	position = Vector2.ZERO
	queue_redraw()


func set_paused(on: bool) -> void:
	_paused = on
	if on:
		position = Vector2.ZERO


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
	if shake_enabled:
		_shake = minf(1.0, _shake + 0.9)
	_victory_origin = s.player.pos
	_victory_color = Color(1.0, 0.75, 1.0)
	if s.boss != null:
		_victory_origin = s.boss.pos
		_victory_color = s.boss.def.color
	for i in 30:
		_spark(_victory_origin, _victory_color, 120.0 + _noise01(i) * 300.0,
				0.5 + _noise01(i + 41) * 0.4)
	var ring := _spark(_victory_origin, _victory_color, 0.0, 0.9)
	if ring != null:
		ring.ring = true
		ring.radius = 30.0
	queue_redraw()


func _process(delta: float) -> void:
	if _paused or sim == null:
		return
	_visual_time += delta
	_shake = maxf(0.0, _shake - delta * 1.8)
	var shake_amount := _shake * _shake * (0.35 if reduced_effects else 1.0)
	position = Vector2(sin(_visual_time * 31.0), sin(_visual_time * 43.0 + 1.7)) * shake_amount * 9.0
	if sim != null:
		var distance := sim.player.pos.distance_to(_last_player_pos)
		_motion_speed = minf(1.0, distance / maxf(1.0, delta * 180.0))
		_motion_amount = move_toward(_motion_amount, _motion_speed, delta * (8.0 if _motion_speed > 0.02 else 5.0))
		_last_player_pos = sim.player.pos
	var keep := 0
	for s in _sparks:
		s.life -= delta
		if s.life > 0.0:
			s.pos += s.vel * delta
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
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	ArenaPainter.pending(self, sim)
	if _beat_take == null:
		ArenaPainter.echo_paths(self, sim, _paths, _reveal)
	else:
		ArenaPainter.record_beat(self, sim, _beat_take, _beat_time / RECORD_BEAT)
	ArenaPainter.pickup_range(self, sim)
	ArenaPainter.pickups(self, sim)
	ArenaPainter.enemies(self, sim)
	ArenaPainter.echoes(self, sim, character_id, _muzzles)
	ArenaPainter.projectiles(self, sim)
	ArenaPainter.player(self, sim, character_id, motion_stats(), _muzzles)
	ArenaPainter.combat_feedback(self, _muzzles, _hits, _explosions, _hurts, _weapon_changes,
			reduced_effects)
	ArenaPainter.sparks(self, _sparks)
	if _victory:
		ArenaPainter.victory(self, _victory_origin, _victory_color, _victory_time / VICTORY_BEAT)


func _on_kill(pos: Vector2, color: Color, source: int) -> void:
	var tint := kill_color(source, color)
	for i in 8:
		_spark(pos, tint, 90.0 + _noise01(i) * 160.0, 0.35 + _noise01(i + 9) * 0.25)
	if source >= 0:
		var ring := _spark(pos, tint, 0.0, 0.3)
		if ring != null:
			ring.ring = true
			ring.radius = 6.0


func _on_shot_info(info: ShotInfo) -> void:
	var profile := ArenaPainter.weapon_feedback_profile(info.weapon_id)
	# Combat.fire guarantees RIGHT for a zero-length target vector. Rich shot feedback mirrors
	# that projectile contract; damage/hurt events keep ZERO because AOE/overlap can be directionless.
	if reduced_effects:
		profile = profile.duplicate(true)
		profile["recoil"] = float(profile["recoil"]) * 0.5
	if info.source >= 0 and sim != null and info.source < sim.echoes.size():
		profile = profile.duplicate(true)
		var profile_color: Color = profile["color"]
		profile["color"] = profile_color.lerp(sim.echoes[info.source].take.tint(), 0.45)
	var direction := info.direction.normalized() if info.direction != Vector2.ZERO else Vector2.RIGHT
	_push_feedback(_muzzles, {"life": 0.14, "max_life": 0.14, "pos": info.origin + direction * 14.0,
			"origin": info.origin, "direction": direction, "source": info.source,
			"weapon_id": info.weapon_id, "level": info.level, "count": info.count,
			"sequence": info.sequence, "profile": profile}, MAX_MUZZLES)
	_last_event = {"kind": &"shot", "weapon_id": info.weapon_id, "direction": direction,
			"origin": info.origin, "source": info.source, "count": info.count,
			"sequence": info.sequence, "profile": profile}


func _on_damage_info(info: DamageInfo) -> void:
	var has_direction := info.hit_dir != Vector2.ZERO
	var direction := info.hit_dir.normalized() if has_direction else Vector2.ZERO
	var hit_color := Color.WHITE
	if info.source >= 0 and sim != null and info.source < sim.echoes.size():
		hit_color = sim.echoes[info.source].take.tint()
	_push_feedback(_hits, {"life": 0.22 if info.crit else 0.15, "max_life": 0.22 if info.crit else 0.15,
			"pos": info.pos, "direction": direction, "crit": info.crit, "reduced": info.reduced,
			"weapon_id": info.weapon_id, "source": info.source, "effect": info.effect,
			"color": hit_color, "has_direction": has_direction}, MAX_HITS)
	_last_event = {"kind": &"damage", "weapon_id": info.weapon_id, "direction": direction,
			"pos": info.pos, "source": info.source, "crit": info.crit,
			"reduced": info.reduced, "effect": info.effect, "has_direction": has_direction}
	var color := hit_color.lerp(Color(1.0, 1.0, 0.55), 0.8) if info.crit else hit_color
	_spark(info.pos, color, 100.0 if info.crit else 65.0, 0.2 if info.crit else 0.14)


# Echo kills burst in the echo's own colour; player kills keep the enemy colour.
func kill_color(source: int, fallback: Color) -> Color:
	if sim == null or source < 0 or source >= sim.echoes.size():
		return fallback
	return fallback.lerp(sim.echoes[source].take.tint(), 0.85)


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
	var has_direction := info.direction != Vector2.ZERO
	var direction := info.direction.normalized() if has_direction else Vector2.ZERO
	_push_feedback(_hurts, {"life": 0.35 if info.lethal else 0.22, "max_life": 0.35 if info.lethal else 0.22,
			"pos": info.pos, "direction": direction, "lethal": info.lethal, "effect": info.effect,
			"source": info.source, "has_direction": has_direction}, MAX_HURTS)
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


func _on_boss_spawned(enemy: EnemyState) -> void:
	var ring := _spark(enemy.pos, enemy.def.color, 0.0, 0.9)
	if ring != null:
		ring.ring = true
		ring.radius = enemy.radius


func _on_echo_silence(_duration: float) -> void:
	if sim == null or sim.boss == null:
		return
	var ring := _spark(sim.boss.pos, Color(1.0, 0.5, 0.9), 0.0, 0.8)
	if ring != null:
		ring.ring = true
		ring.radius = sim.boss.radius


func _on_explosion(pos: Vector2, radius: float, color: Color) -> void:
	var info := ExplosionInfo.new()
	info.pos = pos
	info.radius = radius
	info.color = color
	_on_explosion_info(info)


func _on_explosion_info(info: ExplosionInfo) -> void:
	_push_feedback(_explosions, {"life": 0.42, "max_life": 0.42, "pos": info.pos,
			"radius": info.radius, "color": info.color, "kind": info.kind,
			"weapon_id": info.weapon_id, "effect": info.effect}, MAX_EXPLOSIONS)
	_last_event = {"kind": &"explosion", "cause": info.kind, "weapon_id": info.weapon_id,
			"pos": info.pos, "radius": info.radius, "effect": info.effect}
	var ring := _spark(info.pos, info.color, 0.0, 0.35)
	if ring != null:
		ring.ring = true
		ring.radius = maxf(2.0, info.radius * 0.4)
	for i in 5:
		_spark(info.pos, info.color, 60.0 + _noise01(i + 21) * 90.0, 0.2 + _noise01(i + 31) * 0.15)


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
	s.life = life
	s.max_life = life
	_sparks.append(s)
	return s


func feedback_counts() -> Dictionary:
	return {"muzzles": _muzzles.size(), "hits": _hits.size(), "explosions": _explosions.size(),
			"hurts": _hurts.size(), "recoils": _muzzles.size(),
			"weapon_changes": _weapon_changes.size(), "sparks": _sparks.size()}


func event_last_data() -> Dictionary:
	return _last_event.duplicate(true)


func motion_stats() -> Dictionary:
	return {"moving": _motion_amount > 0.05, "amount": _motion_amount, "speed": _motion_speed,
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
	_sparks.clear()


func _on_wave_started(_wave: int) -> void:
	_clear_feedback()
	_last_player_pos = sim.player.pos if sim != null else Vector2.ZERO
	_motion_amount = 0.0
	_motion_speed = 0.0
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
	# Keep the final directional hurt/explosion long enough to render; discard routine combat cues.
	_muzzles.clear()
	_hits.clear()
	_weapon_changes.clear()
	_sparks.clear()


func _on_run_won() -> void:
	_clear_feedback()
	_sparks.clear()


func _noise01(index: int) -> float:
	return 0.5 + 0.5 * sin(float(index + 1) * 12.9898 + 78.233)


func _disconnect_sim(s: Sim) -> void:
	var pairs: Array = [
		[s.enemy_killed, _on_kill], [s.shot_fired_info, _on_shot_info],
		[s.damage_event, _on_damage_info], [s.player_hurt_info, _on_hurt_info],
		[s.explosion_info, _on_explosion_info], [s.weapon_changed, _on_weapon_changed],
		[s.echo_spawned, _on_echo], [s.boss_spawned, _on_boss_spawned],
		[s.echoes_silenced, _on_echo_silence], [s.wave_started, _on_wave_started],
		[s.wave_ended, _on_wave_phase],
		[s.run_lost, _on_run_lost], [s.run_won, _on_run_won],
	]
	for pair in pairs:
		var signal_value: Signal = pair[0]
		var callable: Callable = pair[1]
		if signal_value.is_connected(callable):
			signal_value.disconnect(callable)
