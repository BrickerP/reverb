class_name ArenaView
extends Node2D

const MAX_SPARKS := 400
const PATH_STRIDE := 3
const REVEAL_TIME := 0.8
const RECORD_BEAT := 0.6

var sim: Sim
var _paths: Dictionary = {}
var _reveal: Dictionary = {}
var _sparks: Array[Spark] = []
var _shake: float = 0.0
var _beat_take: EchoTake
var _beat_time := 0.0


func bind(s: Sim) -> void:
	sim = s
	_paths.clear()
	_reveal.clear()
	_sparks.clear()
	_shake = 0.0
	_beat_take = null
	_beat_time = 0.0
	sim.enemy_killed.connect(_on_kill)
	sim.enemy_hit.connect(_on_hit)
	sim.player_hurt.connect(_on_hurt)
	sim.echo_spawned.connect(_on_echo)


# Called by Main between the last frame of a wave and the shop opening.
func play_record_beat(s: Sim) -> void:
	if s.bank.takes.is_empty():
		return
	_beat_take = s.bank.takes[s.bank.takes.size() - 1]
	_beat_time = 0.0
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
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	ArenaPainter.arena(self)
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
