class_name ArenaView
extends Node2D

const MAX_SPARKS := 400
const PATH_STRIDE := 3

var sim: Sim
var _paths: Dictionary = {}
var _sparks: Array[Spark] = []
var _shake: float = 0.0


func bind(s: Sim) -> void:
	sim = s
	_paths.clear()
	_sparks.clear()
	_shake = 0.0
	sim.enemy_killed.connect(_on_kill)
	sim.enemy_hit.connect(_on_hit)
	sim.player_hurt.connect(_on_hurt)
	sim.echo_spawned.connect(_on_echo)


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
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	ArenaPainter.arena(self)
	ArenaPainter.pending(self, sim)
	ArenaPainter.echo_paths(self, sim, _paths)
	ArenaPainter.pickup_range(self, sim)
	ArenaPainter.pickups(self, sim)
	ArenaPainter.enemies(self, sim)
	ArenaPainter.echoes(self, sim)
	ArenaPainter.projectiles(self, sim)
	ArenaPainter.player(self, sim)
	ArenaPainter.sparks(self, _sparks)


func _on_kill(pos: Vector2, color: Color) -> void:
	for i in 8:
		_spark(pos, color, 90.0 + randf() * 160.0, 0.35 + randf() * 0.25)


func _on_hit(pos: Vector2, _amount: float, crit: bool) -> void:
	_spark(pos, Color(1.0, 1.0, 0.6) if crit else Color.WHITE, 60.0 + randf() * 80.0, 0.16)


func _on_hurt(_amount: float) -> void:
	_shake = minf(1.0, _shake + 0.5)


func _on_echo(actor: EchoActor) -> void:
	var pts := PackedVector2Array()
	for i in range(0, actor.take.samples.size(), PATH_STRIDE):
		pts.append(actor.take.samples[i])
	_paths[actor] = pts
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
