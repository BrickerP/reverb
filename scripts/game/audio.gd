class_name GameAudio
extends Node

const POOL := 12
const NAMES: Array[StringName] = [
	&"shoot", &"hit", &"kill", &"pickup", &"buy", &"hurt", &"echo",
	&"wave_start", &"wave_end", &"lose", &"win", &"click", &"boss", &"silence",
]
const VOLUMES := {
	&"shoot": -15.0,
	&"hit": -20.0,
	&"kill": -13.0,
	&"pickup": -17.0,
	&"buy": -11.0,
	&"hurt": -8.0,
	&"echo": -12.0,
	&"wave_start": -12.0,
	&"wave_end": -12.0,
	&"lose": -7.0,
	&"win": -7.0,
	&"click": -18.0,
	&"boss": -8.0,
	&"silence": -9.0,
}
const COOLDOWNS := {
	&"shoot": 0.035,
	&"hit": 0.03,
	&"kill": 0.04,
	&"pickup": 0.045,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}
var _plays: Dictionary = {}
var _muted := false
var _silent := false
var _bound: Sim
var _music: AudioStreamPlayer


func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"
	for name in NAMES:
		var stream := load("res://audio/%s.wav" % name)
		if stream != null:
			_streams[name] = stream
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	var ambient := load("res://audio/ambient.wav") as AudioStreamWAV
	if ambient != null:
		ambient.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient.loop_begin = 0
		ambient.loop_end = int(ambient.get_length() * float(ambient.mix_rate))
		_music.stream = ambient
		_music.volume_db = -26.0
		add_child(_music)
		if DisplayServer.get_name() != "headless":
			_music.play()


func _exit_tree() -> void:
	stop_all()
	_streams.clear()


func stop_all() -> void:
	if _music != null:
		_music.stop()
	for p in _players:
		p.stop()


func bind(sim: Sim) -> void:
	if sim == null or _bound == sim:
		return
	_bound = sim
	sim.shot_fired.connect(_on_shot)
	sim.enemy_hit.connect(_on_hit)
	sim.enemy_killed.connect(_on_kill)
	sim.material_collected.connect(_on_pickup)
	sim.player_hurt.connect(_on_hurt)
	sim.echo_spawned.connect(_on_echo)
	sim.wave_started.connect(_on_wave_start)
	sim.wave_ended.connect(_on_wave_end)
	sim.purchased.connect(_on_purchase)
	sim.run_lost.connect(_on_lost)
	sim.run_won.connect(_on_won)
	sim.boss_spawned.connect(_on_boss)
	sim.echoes_silenced.connect(_on_silence)


func play(name: StringName, volume_offset: float = 0.0, pitch: float = 1.0) -> bool:
	var stream: AudioStream = _streams.get(name)
	if stream == null or _players.is_empty():
		return false
	var now := Time.get_ticks_msec() * 0.001
	var cooldown := float(COOLDOWNS.get(name, 0.0))
	if now - float(_last.get(name, -100.0)) < cooldown:
		return false
	_last[name] = now
	if _silent:
		_plays[name] = int(_plays.get(name, 0)) + 1
		return true
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = float(VOLUMES.get(name, -14.0)) + volume_offset
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()
	_plays[name] = int(_plays.get(name, 0)) + 1
	return true


func toggle_mute() -> bool:
	_muted = not _muted
	AudioServer.set_bus_mute(0, _muted)
	return _muted


func is_muted() -> bool:
	return _muted


func has_stream(name: StringName) -> bool:
	return _streams.has(name)


func stream_count() -> int:
	return _streams.size()


func play_count(name: StringName) -> int:
	return int(_plays.get(name, 0))


func _on_shot(source: int) -> void:
	var echo := source >= 0
	play(&"shoot", -2.0 if echo else 0.0, 0.93 if echo else 1.0)


func _on_hit(_pos: Vector2, _amount: float, crit: bool, source: int) -> void:
	play(&"hit", -2.0 if source >= 0 else 0.0, 1.18 if crit else 1.0)


func _on_kill(_pos: Vector2, _color: Color, source: int) -> void:
	play(&"kill", -1.0 if source >= 0 else 0.0, 0.95 + randf() * 0.1)


func _on_pickup(amount: int) -> void:
	play(&"pickup", 0.0, 1.0 + minf(0.2, float(amount) * 0.02))


func _on_hurt(_amount: float) -> void:
	play(&"hurt")


func _on_echo(_actor: EchoActor) -> void:
	play(&"echo")


func _on_wave_start(_wave: int) -> void:
	play(&"wave_start")


func _on_wave_end(_wave: int) -> void:
	play(&"wave_end")


func _on_purchase() -> void:
	play(&"buy")


func _on_lost() -> void:
	play(&"lose")


func _on_won() -> void:
	play(&"win")


func _on_boss(_enemy: EnemyState) -> void:
	play(&"boss")


func _on_silence(_duration: float) -> void:
	play(&"silence")
