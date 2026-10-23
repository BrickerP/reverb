class_name ArenaView
extends Node2D

const MAX_SPARKS := 260
const PATH_STRIDE := 3
const REVEAL_TIME := 0.8
const RECORD_BEAT := 0.6
const VICTORY_BEAT := 0.9

var sim: Sim
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


func _ready() -> void:
	_backdrop = ArenaBackdrop.new()
	_backdrop.show_behind_parent = true
	add_child(_backdrop)


func bind(s: Sim) -> void:
	sim = s
	_paths.clear()
	_reveal.clear()
	_sparks.clear()
	_shake = 0.0
	_beat_take = null
	_beat_time = 0.0
	_victory = false
	_victory_time = 0.0
	sim.enemy_killed.connect(_on_kill)
	sim.enemy_hit.connect(_on_hit)
	sim.player_hurt.connect(_on_hurt)
	sim.echo_spawned.connect(_on_echo)
	sim.boss_spawned.connect(_on_boss_spawned)
	sim.echoes_silenced.connect(_on_echo_silence)
	sim.explosion.connect(_on_explosion)


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
		_spark(_victory_origin, _victory_color, 120.0 + randf() * 300.0, 0.5 + randf() * 0.4)
	var ring := _spark(_victory_origin, _victory_color, 0.0, 0.9)
	if ring != null:
		ring.ring = true
		ring.radius = 30.0
	queue_redraw()


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 1.8)
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 9.0
	var keep := 0
	for s in _sparks:
		s.life -= delta
		if s.life > 0.0:
			s.pos += s.vel * delta
			s.vel *= exp(-6.0 * delta)
			_sparks[keep] = s
			keep += 1
	_sparks.resize(keep)
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
	ArenaPainter.echoes(self, sim)
	ArenaPainter.projectiles(self, sim)
	ArenaPainter.player(self, sim)
	ArenaPainter.sparks(self, _sparks)
	if _victory:
		ArenaPainter.victory(self, _victory_origin, _victory_color, _victory_time / VICTORY_BEAT)


func _on_kill(pos: Vector2, color: Color, source: int) -> void:
	var tint := kill_color(source, color)
	for i in 8:
		_spark(pos, tint, 90.0 + randf() * 160.0, 0.35 + randf() * 0.25)
	if source >= 0:
		var ring := _spark(pos, tint, 0.0, 0.3)
		if ring != null:
			ring.ring = true
			ring.radius = 6.0


func _on_hit(pos: Vector2, _amount: float, crit: bool, source: int) -> void:
	var color := Color(1.0, 1.0, 0.6) if crit else Color.WHITE
	if source >= 0 and sim != null and source < sim.echoes.size():
		color = sim.echoes[source].take.tint().lerp(Color.WHITE, 0.2 if crit else 0.0)
	_spark(pos, color, 60.0 + randf() * 80.0, 0.16)


# Echo kills burst in the echo's own colour; player kills keep the enemy colour.
func kill_color(source: int, fallback: Color) -> Color:
	if sim == null or source < 0 or source >= sim.echoes.size():
		return fallback
	return fallback.lerp(sim.echoes[source].take.tint(), 0.85)


func _on_hurt(_amount: float) -> void:
	if shake_enabled:
		_shake = minf(1.0, _shake + 0.5)


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
	var ring := _spark(pos, color, 0.0, 0.35)
	if ring != null:
		ring.ring = true
		ring.radius = maxf(2.0, radius * 0.4)
	for i in 5:
		_spark(pos, color, 60.0 + randf() * 90.0, 0.2 + randf() * 0.15)


func _spark(pos: Vector2, color: Color, speed: float, life: float) -> Spark:
	if _sparks.size() >= MAX_SPARKS:
		return null
	var s := Spark.new()
	s.pos = pos
	s.vel = Vector2.from_angle(randf() * TAU) * speed
	s.color = color
	s.life = life
	s.max_life = life
	_sparks.append(s)
	return s
