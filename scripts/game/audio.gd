class_name GameAudio
extends Node

const POOL := 12
const COMMON_POOL := 7
const PROTECTED_POOL := 5
const PRESENTATION_DIR := "res://audio/presentation"
const LEGACY_AUDIO_DIR := "res://audio"
const NAMES: Array[StringName] = [
	&"shoot", &"hit", &"kill", &"pickup", &"buy", &"hurt", &"echo",
	&"wave_start", &"wave_end", &"lose", &"win", &"click", &"boss", &"silence",
]
const FEEDBACK_NAMES: Array[StringName] = [
	&"weapon_pistol", &"weapon_smg", &"weapon_shotgun", &"weapon_rifle",
	&"weapon_orb", &"weapon_flechette", &"weapon_longbow", &"weapon_hex_bolt",
	&"weapon_twin_fangs", &"weapon_flak_crown", &"weapon_rail_spike", &"weapon_nova_core",
	&"hit_crit", &"shield_block", &"weapon_explosion", &"bomber_explosion",
	&"hurt_contact", &"hurt_blast", &"equipment_apply", &"equipment_undo", &"shop_reroll",
]
const ALL_NAMES: Array[StringName] = [
	&"shoot", &"hit", &"kill", &"pickup", &"buy", &"hurt", &"echo",
	&"wave_start", &"wave_end", &"lose", &"win", &"click", &"boss", &"silence",
	&"weapon_pistol", &"weapon_smg", &"weapon_shotgun", &"weapon_rifle",
	&"weapon_orb", &"weapon_flechette", &"weapon_longbow", &"weapon_hex_bolt",
	&"weapon_twin_fangs", &"weapon_flak_crown", &"weapon_rail_spike", &"weapon_nova_core",
	&"hit_crit", &"shield_block", &"weapon_explosion", &"bomber_explosion",
	&"hurt_contact", &"hurt_blast", &"equipment_apply", &"equipment_undo", &"shop_reroll",
]
const WEAPON_PROFILES := {
	&"pistol": {"cue": &"weapon_pistol", "volume": 0.0, "pitch": 1.00},
	&"smg": {"cue": &"weapon_smg", "volume": -3.0, "pitch": 1.08},
	&"shotgun": {"cue": &"weapon_shotgun", "volume": 1.0, "pitch": 0.94},
	&"rifle": {"cue": &"weapon_rifle", "volume": 0.0, "pitch": 1.02},
	&"orb": {"cue": &"weapon_orb", "volume": -1.0, "pitch": 0.92},
	&"flechette": {"cue": &"weapon_flechette", "volume": -2.0, "pitch": 1.10},
	&"longbow": {"cue": &"weapon_longbow", "volume": 0.0, "pitch": 1.00},
	&"hex_bolt": {"cue": &"weapon_hex_bolt", "volume": -1.0, "pitch": 0.96},
	&"twin_fangs": {"cue": &"weapon_twin_fangs", "volume": -2.0, "pitch": 1.06},
	&"flak_crown": {"cue": &"weapon_flak_crown", "volume": 1.0, "pitch": 0.92},
	&"rail_spike": {"cue": &"weapon_rail_spike", "volume": 1.0, "pitch": 0.88},
	&"nova_core": {"cue": &"weapon_nova_core", "volume": 1.0, "pitch": 0.86},
}
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
	&"weapon_pistol": -13.0,
	&"weapon_smg": -15.0,
	&"weapon_shotgun": -10.0,
	&"weapon_rifle": -11.0,
	&"weapon_orb": -13.0,
	&"weapon_flechette": -14.0,
	&"weapon_longbow": -12.0,
	&"weapon_hex_bolt": -13.0,
	&"weapon_twin_fangs": -14.0,
	&"weapon_flak_crown": -9.0,
	&"weapon_rail_spike": -9.0,
	&"weapon_nova_core": -10.0,
	&"hit_crit": -14.0,
	&"shield_block": -13.0,
	&"weapon_explosion": -10.0,
	&"bomber_explosion": -7.0,
	&"hurt_contact": -8.0,
	&"hurt_blast": -6.0,
	&"equipment_apply": -10.0,
	&"equipment_undo": -11.0,
	&"shop_reroll": -14.0,
}
const COOLDOWNS := {
	&"shoot": 0.035,
	&"hit": 0.03,
	&"kill": 0.04,
	&"pickup": 0.045,
	&"echo": 0.14,
	&"weapon_pistol": 0.045,
	&"weapon_smg": 0.035,
	&"weapon_shotgun": 0.09,
	&"weapon_rifle": 0.08,
	&"weapon_orb": 0.10,
	&"weapon_flechette": 0.055,
	&"weapon_longbow": 0.10,
	&"weapon_hex_bolt": 0.08,
	&"weapon_twin_fangs": 0.035,
	&"weapon_flak_crown": 0.10,
	&"weapon_rail_spike": 0.10,
	&"weapon_nova_core": 0.11,
	&"hit_crit": 0.045,
	&"shield_block": 0.06,
	&"weapon_explosion": 0.08,
	&"bomber_explosion": 0.16,
	&"hurt_contact": 0.14,
	&"hurt_blast": 0.18,
}
const PROTECTED_NAMES: Array[StringName] = [
	&"shield_block", &"hurt", &"hurt_contact", &"hurt_blast", &"bomber_explosion",
	&"boss", &"lose", &"win", &"wave_start", &"wave_end", &"silence",
	&"buy", &"click", &"equipment_apply", &"equipment_undo", &"shop_reroll",
]
const PROTECTED_PRIORITIES := {
	&"shield_block": 20,
	&"bomber_explosion": 25,
	&"wave_start": 30,
	&"wave_end": 30,
	&"silence": 35,
	&"hurt": 50,
	&"hurt_contact": 50,
	&"hurt_blast": 55,
	&"boss": 60,
	&"buy": 65,
	&"click": 65,
	&"equipment_apply": 70,
	&"equipment_undo": 70,
	&"shop_reroll": 70,
	&"lose": 80,
	&"win": 80,
}
const PAUSE_ALLOWED_NAMES: Array[StringName] = [
	&"buy", &"click", &"equipment_apply", &"equipment_undo", &"shop_reroll",
]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _common_players: Array[AudioStreamPlayer] = []
var _protected_players: Array[AudioStreamPlayer] = []
var _player_cues: Dictionary = {}
var _player_priorities: Dictionary = {}
var _player_serials: Dictionary = {}
var _play_serial := 0
var _next_common := 0
var _next_protected := 0
var _last: Dictionary = {}
var _plays: Dictionary = {}
var _muted := false
var _paused := false
var _silent := false
var _bound: Sim
var _bound_shop: Shop
var _music: AudioStreamPlayer


func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"
	for name in ALL_NAMES:
		var stream := load(stream_path(name))
		if stream != null:
			_streams[name] = stream
	for _i in COMMON_POOL:
		_add_player(_common_players)
	for _i in PROTECTED_POOL:
		_add_player(_protected_players)
	_music = AudioStreamPlayer.new()
	var ambient := load("res://audio/ambient.wav") as AudioStreamWAV
	if ambient != null:
		ambient.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient.loop_begin = 0
		ambient.loop_end = int(ambient.get_length() * float(ambient.mix_rate))
		_music.stream = ambient
		_music.volume_db = -26.0
		add_child(_music)
		if not _silent:
			_music.play()


func _exit_tree() -> void:
	_disconnect_bound()
	stop_all()
	_streams.clear()


func _add_player(pool: Array[AudioStreamPlayer]) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	pool.append(player)
	_players.append(player)


func stop_all() -> void:
	if _music != null:
		_music.stop()
	for player in _players:
		player.stop()


func set_paused(on: bool) -> void:
	_paused = on
	if _music != null:
		_music.stream_paused = on
	if not on:
		return
	for player in _common_players:
		player.stop()
	for player in _protected_players:
		var cue: StringName = _player_cues.get(player, &"")
		if not PAUSE_ALLOWED_NAMES.has(cue):
			player.stop()


func is_paused() -> bool:
	return _paused


func bind(sim: Sim) -> void:
	if sim == null:
		_disconnect_bound()
		_reset_session_state()
		return
	if _bound == sim:
		return
	_disconnect_bound()
	_reset_session_state()
	_bound = sim
	_bound_shop = sim.shop
	sim.shot_fired_info.connect(_on_shot_info)
	sim.damage_event.connect(_on_damage_info)
	sim.explosion_info.connect(_on_explosion_info)
	sim.player_hurt_info.connect(_on_hurt_info)
	sim.enemy_killed.connect(_on_kill)
	sim.material_collected.connect(_on_pickup)
	sim.echo_spawned.connect(_on_echo)
	sim.wave_started.connect(_on_wave_start)
	sim.wave_ended.connect(_on_wave_end)
	sim.purchased.connect(_on_purchase)
	sim.run_lost.connect(_on_lost)
	sim.run_won.connect(_on_won)
	sim.boss_spawned.connect(_on_boss)
	sim.boss_phase_changed.connect(_on_boss_phase)
	sim.boss_enraged.connect(_on_boss_enraged)
	sim.echoes_silenced.connect(_on_silence)
	_bound_shop.shop_action_resolved.connect(_on_shop_action)


func _disconnect_bound() -> void:
	if _bound != null:
		_disconnect_signal(_bound.shot_fired_info, _on_shot_info)
		_disconnect_signal(_bound.damage_event, _on_damage_info)
		_disconnect_signal(_bound.explosion_info, _on_explosion_info)
		_disconnect_signal(_bound.player_hurt_info, _on_hurt_info)
		_disconnect_signal(_bound.enemy_killed, _on_kill)
		_disconnect_signal(_bound.material_collected, _on_pickup)
		_disconnect_signal(_bound.echo_spawned, _on_echo)
		_disconnect_signal(_bound.wave_started, _on_wave_start)
		_disconnect_signal(_bound.wave_ended, _on_wave_end)
		_disconnect_signal(_bound.purchased, _on_purchase)
		_disconnect_signal(_bound.run_lost, _on_lost)
		_disconnect_signal(_bound.run_won, _on_won)
		_disconnect_signal(_bound.boss_spawned, _on_boss)
		_disconnect_signal(_bound.boss_phase_changed, _on_boss_phase)
		_disconnect_signal(_bound.boss_enraged, _on_boss_enraged)
		_disconnect_signal(_bound.echoes_silenced, _on_silence)
	if _bound_shop != null:
		_disconnect_signal(_bound_shop.shop_action_resolved, _on_shop_action)
	_bound = null
	_bound_shop = null


func _reset_session_state() -> void:
	for player in _players:
		player.stop()
	_player_cues.clear()
	_player_priorities.clear()
	_player_serials.clear()
	_last.clear()
	_next_common = 0
	_next_protected = 0
	_play_serial = 0
	_paused = false
	if _music != null:
		_music.stream_paused = false


func _disconnect_signal(signal_value: Signal, handler: Callable) -> void:
	if signal_value.is_connected(handler):
		signal_value.disconnect(handler)


func play(name: StringName, volume_offset: float = 0.0, pitch: float = 1.0) -> bool:
	var stream: AudioStream = _streams.get(name)
	if stream == null or _players.is_empty():
		return false
	if _paused and not PAUSE_ALLOWED_NAMES.has(name):
		return false
	var now := Time.get_ticks_msec() * 0.001
	var cooldown := float(COOLDOWNS.get(name, 0.0))
	if now - float(_last.get(name, -100.0)) < cooldown:
		return false
	_last[name] = now
	if _silent:
		_plays[name] = int(_plays.get(name, 0)) + 1
		return true
	var player := _claim_player(name)
	if player == null:
		return false
	player.stream = stream
	player.volume_db = float(VOLUMES.get(name, -14.0)) + volume_offset
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	_player_cues[player] = name
	player.play()
	_plays[name] = int(_plays.get(name, 0)) + 1
	return true


func _claim_player(name: StringName) -> AudioStreamPlayer:
	var protected_voice := is_protected(name)
	var pool := _protected_players if protected_voice else _common_players
	if pool.is_empty():
		return null
	var cursor := _next_protected if protected_voice else _next_common
	var active: Array[bool] = []
	var priorities: Array[int] = []
	var serials: Array[int] = []
	for player in pool:
		active.append(player.playing)
		priorities.append(int(_player_priorities.get(player, 0)))
		serials.append(int(_player_serials.get(player, 0)))
	var incoming_priority := priority_for(name)
	var chosen := voice_index(active, priorities, serials, incoming_priority, cursor)
	if chosen < 0:
		return null
	if protected_voice:
		_next_protected = (chosen + 1) % pool.size()
	else:
		_next_common = (chosen + 1) % pool.size()
	var selected := pool[chosen]
	_play_serial += 1
	_player_priorities[selected] = incoming_priority
	_player_serials[selected] = _play_serial
	return selected


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


func binding_state() -> Dictionary:
	var active_sfx := 0
	for player in _players:
		if player.playing:
			active_sfx += 1
	return {
		"sim_bound": _bound != null,
		"shop_bound": _bound_shop != null,
		"paused": _paused,
		"active_sfx": active_sfx,
		"cooldowns": _last.size(),
		"routed_voices": _player_cues.size(),
		"ambient_playing": _music != null and _music.playing,
		"ambient_paused": _music != null and _music.stream_paused,
	}


static func stream_path(name: StringName) -> String:
	var preferred := "%s/%s.wav" % [PRESENTATION_DIR, name]
	if ResourceLoader.exists(preferred):
		return preferred
	return "%s/%s.wav" % [LEGACY_AUDIO_DIR, name]


static func weapon_profile(id: StringName) -> Dictionary:
	return WEAPON_PROFILES.get(id, {})


static func is_protected(name: StringName) -> bool:
	return PROTECTED_NAMES.has(name)


static func priority_for(name: StringName) -> int:
	return int(PROTECTED_PRIORITIES.get(name, 0))


static func voice_index(active: Array[bool], priorities: Array[int], serials: Array[int],
		incoming_priority: int, cursor: int = 0) -> int:
	if active.is_empty() or active.size() != priorities.size() or active.size() != serials.size():
		return -1
	for offset in active.size():
		var index := (cursor + offset) % active.size()
		if not active[index]:
			return index
	var chosen := -1
	var chosen_priority := 2147483647
	var chosen_serial := 9223372036854775807
	for index in active.size():
		var current_priority := priorities[index]
		var current_serial := serials[index]
		if current_priority > incoming_priority:
			continue
		if current_priority < chosen_priority \
				or (current_priority == chosen_priority and current_serial < chosen_serial):
			chosen = index
			chosen_priority = current_priority
			chosen_serial = current_serial
	return chosen


func _on_shot_info(info: ShotInfo) -> void:
	var profile := weapon_profile(info.weapon_id)
	if profile.is_empty():
		play(&"shoot", -2.0 if info.source >= 0 else 0.0, 0.93 if info.source >= 0 else 1.0)
		return
	var cue: StringName = profile["cue"]
	var volume := float(profile["volume"]) - (3.0 if info.source >= 0 else 0.0)
	var variation := float(posmod(info.sequence, 3) - 1) * 0.015
	var pitch := float(profile["pitch"]) + variation - (0.04 if info.source >= 0 else 0.0)
	play(cue, volume, pitch)


func _on_damage_info(info: DamageInfo) -> void:
	var cue := &"hit"
	var pitch := 1.0
	if info.reduced:
		cue = &"shield_block"
		pitch = 0.96
	elif info.crit:
		cue = &"hit_crit"
		pitch = 1.04
	play(cue, -2.0 if info.source >= 0 else 0.0, pitch)


func _on_explosion_info(info: ExplosionInfo) -> void:
	var cue := &"bomber_explosion" if info.kind == ExplosionInfo.BOMBER else &"weapon_explosion"
	play(cue, -2.0 if info.source >= 0 else 0.0, 1.0)


func _on_hurt_info(info: PlayerHurtInfo) -> void:
	var blast := info.effect == &"bomber_explosion"
	play(&"hurt_blast" if blast else &"hurt_contact", 2.0 if info.lethal else 0.0,
			0.90 if info.lethal else 1.0)


# Compatibility handlers remain callable for older tools, but bind() deliberately
# consumes rich combat signals so the legacy+rich pair emitted by Sim plays once.
func _on_shot(source: int) -> void:
	play(&"shoot", -2.0 if source >= 0 else 0.0, 0.93 if source >= 0 else 1.0)


func _on_hit(_pos: Vector2, _amount: float, crit: bool, source: int) -> void:
	play(&"hit", -2.0 if source >= 0 else 0.0, 1.18 if crit else 1.0)


func _on_hurt(_amount: float) -> void:
	play(&"hurt")


func _on_kill(_pos: Vector2, _color: Color, source: int) -> void:
	play(&"kill", -1.0 if source >= 0 else 0.0, 0.96 if source >= 0 else 1.0)


func _on_pickup(amount: int) -> void:
	play(&"pickup", 0.0, 1.0 + minf(0.2, float(amount) * 0.02))


func _on_echo(_actor: EchoActor) -> void:
	play(&"echo")


func _on_wave_start(_wave: int) -> void:
	play(&"wave_start")


func _on_wave_end(_wave: int) -> void:
	play(&"wave_end")


func _on_purchase() -> void:
	# Sim.purchased is the sole apply cue for buy/replace/upgrade/evolve.
	play(&"equipment_apply")


func _on_shop_action(result: ShopResult) -> void:
	if not result.ok:
		return
	match result.action:
		ShopResult.SELL:
			play(&"buy")
		ShopResult.UNDO:
			play(&"equipment_undo")
		ShopResult.REROLL:
			play(&"shop_reroll")


func _on_lost() -> void:
	play(&"lose")


func _on_won() -> void:
	play(&"win")


func _on_boss(_enemy: EnemyState) -> void:
	play(&"boss")


func _on_boss_phase(phase: int) -> void:
	if phase == 2:
		play(&"boss", -2.0, 0.82)


func _on_boss_enraged(_enemy: EnemyState) -> void:
	play(&"boss", -1.0, 1.25)


func _on_silence(_duration: float) -> void:
	play(&"silence")
