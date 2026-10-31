class_name GameAudio
extends Node

const POOL := 12
const COMMON_POOL := 7
const PROTECTED_POOL := 5
const SUPPORT_PRIORITY := 10
const PRESENTATION_DIR := "res://audio/presentation"
const MUSIC_DB := -9.0
const MUSIC_DIR := "res://audio/music"
const MUSIC_MODES: Array[StringName] = [&"menu", &"shop", &"battle", &"pressure", &"boss"]
const MUSIC_SECONDS := 96.0
const MUSIC_FADE_SECONDS := 1.2
const TRANSITION_DUCK_DB := -8.0
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
	&"guard_decoy": {"cue": &"shield_block", "volume": -2.7, "pitch": 0.87, "gate": 0.35},
	&"paper_seed": {"cue": &"weapon_orb", "volume": -3.4, "pitch": 1.18, "gate": 0.5},
	&"repair_kit": {"cue": &"equipment_apply", "volume": -3.2, "pitch": 1.11, "gate": 0.45},
	&"debt_sentry": {"cue": &"weapon_pistol", "volume": -2.3, "pitch": 0.84, "gate": 0.28},
	&"paper_hound": {"cue": &"weapon_hex_bolt", "volume": -3.5, "pitch": 0.81, "gate": 0.42},
	&"binding_atlas": {"cue": &"weapon_nova_core", "volume": -1.4, "pitch": 0.76, "gate": 0.43},
	&"folding_guillotine": {"cue": &"weapon_rail_spike", "volume": 0.4, "pitch": 0.71, "gate": 0.27},
	&"ink_tempest": {"cue": &"weapon_orb", "volume": -1.8, "pitch": 0.59, "gate": 0.38},
	&"surveyor_lance": {"cue": &"weapon_rifle", "volume": 0.2, "pitch": 0.65, "gate": 0.18},
	&"saw_swarm": {"cue": &"weapon_flechette", "volume": -0.5, "pitch": 0.83, "gate": 0.24},
	&"binding_writ": {"cue": &"weapon_pistol", "volume": -0.5, "pitch": 0.67, "gate": 0.14},
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
	&"stapler": {"cue": &"weapon_pistol", "volume": -1.0, "pitch": 0.73, "gate": 0.10},
	&"paper_saw": {"cue": &"weapon_flechette", "volume": 0.0, "pitch": 0.74, "gate": 0.22},
	&"hole_punch": {"cue": &"weapon_rifle", "volume": 0.5, "pitch": 0.72, "gate": 0.16},
	&"ink_bottle": {"cue": &"weapon_orb", "volume": -1.5, "pitch": 0.68, "gate": 0.34},
	&"stamp": {"cue": &"weapon_rail_spike", "volume": 0.0, "pitch": 0.78, "gate": 0.18},
	&"mallet": {"cue": &"weapon_shotgun", "volume": 0.5, "pitch": 0.64, "gate": 0.23},
	&"cutter": {"cue": &"weapon_flechette", "volume": -1.0, "pitch": 1.26, "gate": 0.12},
	&"tape_spool": {"cue": &"weapon_longbow", "volume": -2.0, "pitch": 0.68, "gate": 0.24},
	&"rubber_band": {"cue": &"weapon_longbow", "volume": -1.0, "pitch": 1.31, "gate": 0.16},
	&"paper_plane": {"cue": &"weapon_hex_bolt", "volume": -3.0, "pitch": 1.27, "gate": 0.28},
	&"hydraulic_press": {"cue": &"weapon_rail_spike", "volume": 1.5, "pitch": 0.55, "gate": 0.37},
	&"redaction_engine": {"cue": &"weapon_nova_core", "volume": -0.5, "pitch": 0.64, "gate": 0.44},
}
const VOLUMES := {
	&"shoot": -15.0,
	&"hit": -22.0,
	&"kill": -16.0,
	&"pickup": -21.0,
	&"buy": -13.0,
	&"hurt": -11.0,
	&"echo": -14.0,
	&"wave_start": -14.0,
	&"wave_end": -13.0,
	&"lose": -10.0,
	&"win": -10.0,
	&"click": -18.0,
	&"boss": -11.0,
	&"silence": -12.0,
	&"weapon_pistol": -17.0,
	&"weapon_smg": -20.0,
	&"weapon_shotgun": -15.0,
	&"weapon_rifle": -16.0,
	&"weapon_orb": -18.0,
	&"weapon_flechette": -19.0,
	&"weapon_longbow": -17.0,
	&"weapon_hex_bolt": -18.0,
	&"weapon_twin_fangs": -19.0,
	&"weapon_flak_crown": -14.0,
	&"weapon_rail_spike": -14.0,
	&"weapon_nova_core": -15.0,
	&"hit_crit": -17.0,
	&"shield_block": -16.0,
	&"weapon_explosion": -15.0,
	&"bomber_explosion": -11.0,
	&"hurt_contact": -11.0,
	&"hurt_blast": -10.0,
	&"equipment_apply": -12.0,
	&"equipment_undo": -13.0,
	&"shop_reroll": -16.0,
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
var _music_players: Array[AudioStreamPlayer] = []
var _music_streams: Dictionary = {}
var _music_mode: StringName = &"menu"
var _music_previous: AudioStreamPlayer
var _music_cursor := 0.0
var _music_fade := 0.0
var _music_hold := 0.0
var _music_poll := 0.0
var _music_intensity := 0.0
var _music_enabled := true
var _music_volume := 0.8
var _effects_volume := 1.0
var _voice_base_db: Dictionary = {}
var _voice_left: Dictionary = {}
var _duck_remaining := 0.0


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
	for mode in MUSIC_MODES:
		var stream := load("%s/%s.wav" % [MUSIC_DIR, mode]) as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
			_music_streams[mode] = stream
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)
	_music = _music_players[0]
	_start_music(&"menu", true)


func _process(delta: float) -> void:
	if _paused:
		return
	_duck_remaining = maxf(0.0, _duck_remaining - delta)
	_update_effect_envelopes(delta)
	if _music_enabled:
		_music_cursor = fposmod(_music_cursor + delta, MUSIC_SECONDS)
		_music_hold = maxf(0.0, _music_hold - delta)
		_music_poll -= delta
		if _music_poll <= 0.0:
			_music_poll = 0.25
			var state := music_profile(_bound, _music_mode)
			_music_intensity = float(state["intensity"])
			var mode: StringName = state["mode"]
			if mode != _music_mode and (mode not in [&"battle", &"pressure"] or _music_hold <= 0.0) and _music_fade <= 0.0:
				_start_music(mode)
		if _music_fade > 0.0:
			_music_fade = maxf(0.0, _music_fade - delta)
			if _music_fade <= 0.0 and _music_previous != null:
				_music_previous.stop()
				_music_previous = null
	_update_music_levels()


func _duck_room(seconds: float) -> void:
	if _paused:
		return
	_duck_remaining = maxf(_duck_remaining, seconds)
	_update_music_levels()


func _update_music_levels() -> void:
	var level := MUSIC_DB + _gain_db(_music_volume)
	level += TRANSITION_DUCK_DB * minf(1.0, _duck_remaining / 0.16)
	var blend := 1.0 - _music_fade / MUSIC_FADE_SECONDS
	for player in _music_players:
		var gain := blend if player == _music else 1.0 - blend if player == _music_previous else 0.0
		player.volume_db = level + _gain_db(gain)


func _start_music(mode: StringName, immediate: bool = false) -> void:
	if not _music_streams.has(mode) or _music_players.is_empty():
		return
	_music_enabled = true
	if immediate:
		for player in _music_players:
			player.stop()
		_music = _music_players[0]
		_music_previous = null
		_music_fade = 0.0
	else:
		_music_previous = _music
		_music = _music_players[1] if _music == _music_players[0] else _music_players[0]
		_music.stop()
		_music_fade = MUSIC_FADE_SECONDS
	_music_mode = mode
	_music_hold = 3.0 if mode in [&"battle", &"pressure"] else 0.0
	_music.stream = _music_streams[mode]
	_music.stream_paused = _paused
	if not _silent:
		# All arrangements share the complete harmonic map. Start the incoming
		# arrangement at the current audible phrase, never back at its intro.
		var position := _music_previous.get_playback_position() if _music_previous != null else _music_cursor
		_music.play(fposmod(position, MUSIC_SECONDS))
	_update_music_levels()


static func _gain_db(value: float) -> float:
	return linear_to_db(value) if value > 0.0001 else -80.0


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_update_music_levels()


func set_effects_volume(value: float) -> void:
	_effects_volume = clampf(value, 0.0, 1.0)
	_update_effect_envelopes(0.0)


func _update_effect_envelopes(delta: float) -> void:
	for player in _players:
		var gain := 1.0
		if _voice_left.has(player):
			var left := maxf(0.0, float(_voice_left[player]) - delta)
			if left <= 0.0:
				player.stop()
				_voice_left.erase(player)
			else:
				_voice_left[player] = left
				gain = minf(1.0, left / 0.025)
		player.volume_db = float(_voice_base_db.get(player, -80.0)) + _gain_db(_effects_volume * gain)


static func music_profile(sim: Sim, current: StringName = &"battle") -> Dictionary:
	if sim == null or sim.phase in [Sim.Phase.LOST, Sim.Phase.WON]:
		return {"mode": &"menu", "intensity": 0.0, "nearby": 0, "attacks": 0}
	if sim.phase in [Sim.Phase.SHOP, Sim.Phase.RESOLUTION]:
		return {"mode": &"shop", "intensity": 0.0, "nearby": 0, "attacks": 0}
	var nearby := 0
	var attacks := 0
	var boss_active := false
	for enemy in sim.enemies:
		if enemy.dead:
			continue
		if enemy.def != null and enemy.def.id == &"paradox":
			boss_active = true
		if enemy.pos.distance_squared_to(sim.player.pos) <= 420.0 * 420.0:
			nearby += 1
			if enemy.brain_state in [&"warn", &"dash", &"slam", &"seal"]:
				attacks += 1
	boss_active = boss_active or (sim.boss != null and not sim.boss.dead)
	var pacing := WaveDirector.phase_profile(sim.wave_time, sim.wave_duration)
	var intensity := float(nearby) * 0.4 + float(attacks) * 1.2 + float(pacing["intensity"]) * 1.1
	if sim.player.hp < sim.player.max_hp() * 0.3:
		intensity += 1.5
	var pressure := intensity >= (3.5 if current == &"pressure" else 6.0)
	return {"mode": &"boss" if boss_active else &"pressure" if pressure else &"battle",
		"intensity": intensity, "nearby": nearby, "attacks": attacks, "wave_phase": pacing["id"]}


func music_state() -> Dictionary:
	var active := 0
	for player in _music_players:
		if player.playing:
			active += 1
	return {"mode": _music_mode, "intensity": _music_intensity, "cursor": _music_cursor,
		"crossfade_remaining": _music_fade, "nodes": _music_players.size(), "active_voices": active,
		"arrangements": _music_streams.size(), "paused": _paused, "enabled": _music_enabled,
		"music_volume": _music_volume, "effects_volume": _effects_volume}


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
	_duck_remaining = 0.0
	_music_enabled = false
	_music_fade = 0.0
	_music_previous = null
	_update_music_levels()
	for player in _music_players:
		player.stop()
	for player in _players:
		player.stop()
	_voice_left.clear()


func set_paused(on: bool) -> void:
	_paused = on
	for player in _music_players:
		player.stream_paused = on
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
	sim.echo_retired.connect(_on_echo_retired)
	sim.echo_work_performed.connect(_on_echo_work)
	sim.world_event.connect(_on_world_event)
	sim.support_event.connect(_on_support_event)
	sim.wave_started.connect(_on_wave_start)
	sim.wave_ended.connect(_on_wave_end)
	sim.purchased.connect(_on_purchase)
	sim.run_lost.connect(_on_lost)
	sim.run_won.connect(_on_won)
	sim.echoes_silenced.connect(_on_silence)
	_bound_shop.shop_action_resolved.connect(_on_shop_action)
	_start_music(music_profile(sim)["mode"], true)


func _disconnect_bound() -> void:
	if _bound != null:
		_disconnect_signal(_bound.shot_fired_info, _on_shot_info)
		_disconnect_signal(_bound.damage_event, _on_damage_info)
		_disconnect_signal(_bound.explosion_info, _on_explosion_info)
		_disconnect_signal(_bound.player_hurt_info, _on_hurt_info)
		_disconnect_signal(_bound.enemy_killed, _on_kill)
		_disconnect_signal(_bound.material_collected, _on_pickup)
		_disconnect_signal(_bound.echo_spawned, _on_echo)
		_disconnect_signal(_bound.echo_retired, _on_echo_retired)
		_disconnect_signal(_bound.echo_work_performed, _on_echo_work)
		_disconnect_signal(_bound.world_event, _on_world_event)
		_disconnect_signal(_bound.support_event, _on_support_event)
		_disconnect_signal(_bound.wave_started, _on_wave_start)
		_disconnect_signal(_bound.wave_ended, _on_wave_end)
		_disconnect_signal(_bound.purchased, _on_purchase)
		_disconnect_signal(_bound.run_lost, _on_lost)
		_disconnect_signal(_bound.run_won, _on_won)
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
	_duck_remaining = 0.0
	_voice_left.clear()
	_voice_base_db.clear()
	_music_cursor = 0.0
	_music_hold = 0.0
	_music_poll = 0.0
	_music_intensity = 0.0
	for player in _music_players:
		player.stream_paused = false
	_start_music(&"menu", true)


func _disconnect_signal(signal_value: Signal, handler: Callable) -> void:
	if signal_value.is_connected(handler):
		signal_value.disconnect(handler)


func play(name: StringName, volume_offset: float = 0.0, pitch: float = 1.0, gate: float = 0.0,
		voice_priority: int = -1) -> bool:
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
	var player := _claim_player(name, voice_priority)
	if player == null:
		return false
	player.stream = stream
	_voice_base_db[player] = float(VOLUMES.get(name, -14.0)) + volume_offset
	_voice_left.erase(player)
	if gate > 0.0:
		_voice_left[player] = maxf(0.04, gate)
	player.volume_db = float(_voice_base_db[player]) + _gain_db(_effects_volume)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	_player_cues[player] = name
	player.play()
	_plays[name] = int(_plays.get(name, 0)) + 1
	return true


func _claim_player(name: StringName, voice_priority: int = -1) -> AudioStreamPlayer:
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
	var incoming_priority := priority_for(name) if voice_priority < 0 else voice_priority
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
		"music_playing": _music != null and _music.playing,
		"music_paused": _music != null and _music.stream_paused,
		"music_volume_db": _music.volume_db if _music != null else MUSIC_DB,
		"duck_remaining": _duck_remaining,
	}


static func stream_path(name: StringName) -> String:
	return "%s/%s.wav" % [PRESENTATION_DIR, name]


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
	play(cue, volume, pitch, float(profile.get("gate", 0.0)))


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
	if info.full_block():
		play(&"shield_block", -1.0, 0.91)
		return
	if info.amount <= 0.0:
		return
	var blast := info.effect == &"bomber_explosion"
	play(&"hurt_blast" if blast else &"hurt_contact", 2.0 if info.lethal else 0.0,
			0.90 if info.lethal else 1.0)


func _on_kill(info: EnemyDeathInfo) -> void:
	var profile := death_profile(info.enemy_id)
	play(&"kill", float(profile["volume"]) + (-1.0 if info.source >= 0 else 0.0),
			float(profile["pitch"]) * (0.96 if info.source >= 0 else 1.0))


static func death_profile(enemy_id: StringName) -> Dictionary:
	# Same bounded voice/cooldown path, with a different paper-junk cadence per body.
	match enemy_id:
		&"runner": return {"pitch": 1.32, "volume": -1.5}
		&"brute": return {"pitch": 0.76, "volume": 1.0}
		&"silencer": return {"pitch": 0.86, "volume": -0.5}
		&"bomber": return {"pitch": 1.14, "volume": -1.0}
		&"warden": return {"pitch": 0.88, "volume": 0.5}
		&"paradox": return {"pitch": 0.68, "volume": 1.0}
	return {"pitch": 1.0, "volume": 0.0}


func _on_pickup(amount: int) -> void:
	play(&"pickup", 0.0, 1.0 + minf(0.2, float(amount) * 0.02))


func _on_echo(actor: EchoActor) -> void:
	var pitch := 1.03 if actor.take.merged else lerpf(0.74, 0.98, clampf(actor.take.condition / 100.0, 0.0, 1.0))
	play(&"echo", 0.5 if actor.take.merged else 0.0, pitch)


func _on_echo_retired(info: EchoRetirementInfo) -> void:
	if info.exhausted or info.reason == EchoRetirementInfo.EXHAUSTED:
		play(&"echo", -5.0, 0.58, 0.18)
		return
	# The recorded skill determines its material accent. There is no universal
	# explosion sound, and exhaustion cannot borrow the active skill's weight.
	var cue := &"echo"
	var pitch := 0.86
	match info.kind:
		&"pin": cue = &"weapon_longbow"; pitch = 0.81
		&"stamp": cue = &"weapon_rail_spike"; pitch = 0.71
		&"cut": cue = &"weapon_flechette"; pitch = 0.69
		&"ink": cue = &"weapon_orb"; pitch = 0.70
		&"arc": cue = &"weapon_nova_core"; pitch = 0.76
	# This explicit player action must not disappear behind the same weapon's
	# preceding shot cooldown. It still uses the existing bounded common pool.
	_last.erase(cue)
	play(cue, 1.0, pitch, 0.32)
	_duck_room(0.32)


func _on_echo_work(info: Dictionary) -> void:
	if not bool(info.get("success", false)):
		return
	if info.get("target_id", &"") == BureauEvents.SWITCH_ID:
		return
	# Signature attacks already emit their own weapon cue. Devices use the same
	# bounded dry palette and cooldowns as the rest of the bureau.
	match info.get("kind", &""):
		&"press": play(&"weapon_rail_spike", -4.0, 0.65, 0.18)
		&"conveyor": play(&"click", -5.0, 0.82, 0.12)


func _on_wave_start(_wave: int) -> void:
	play(&"wave_start")


func _on_world_event(info: Dictionary) -> void:
	match info.get("kind", &""):
		&"dispatch_impact": play(&"weapon_rail_spike", -1.0, 0.62, 0.18)
		&"dispatch_safe": play(&"click", -3.0, 0.92, 0.10)
		&"dispatch_delivered": play(&"equipment_apply", -3.0, 1.05, 0.16)
		&"dispatch_carried", &"inspection_registered": play(&"click", -3.0, 1.0, 0.12)
		&"interaction_result":
			if not bool(info.get("ok", false)):
				play(&"click", -5.0, 0.62, 0.08)
				return
			match info.get("target_kind", &""):
				&"repair", &"rescue", &"recycler": play(&"equipment_apply", -4.0, 1.12, 0.18)
				&"press": play(&"weapon_rail_spike", -5.0, 0.71, 0.16)
				&"conveyor": play(&"click", -4.0, 0.83, 0.12)
		&"character_skill":
			if not bool(info.get("ok", false)):
				return
			match info.get("ability", &""):
				&"looper": play(&"echo", -3.0, 0.72, 0.24)
				&"mirror": play(&"echo", -3.0, 1.12, 0.24)
				&"solo": play(&"weapon_longbow", -3.0, 0.64, 0.20)
				&"conductor": play(&"weapon_nova_core", -4.0, 0.86, 0.22)
				# Mender's real support spawn and Overloader's real retirement own
				# their sounds; a successful key press cannot play those twice.
		&"companion_signed": play(&"equipment_apply", -2.0, 0.78, 0.24)


func _on_support_event(info: Dictionary) -> void:
	# Support attacks are not ShotInfo events. They have their own finite bodies,
	# and cannot animate or replay the deploying character's weapon.
	match info.get("kind", &""):
		&"spawn": play(&"echo", -8.0, 1.08, 0.14)
		&"repair": play(&"equipment_apply", -5.0, 1.12, 0.20, SUPPORT_PRIORITY)
		&"produce": play(&"click", -7.0, 1.16, 0.10, SUPPORT_PRIORITY)
		&"retrieve": play(&"pickup", -7.0, 1.08, 0.09)
		&"damage": play(&"hit", -4.0, 0.77, 0.10)
		&"destroy": play(&"kill", -3.0, 0.70, 0.24)
		&"expire": play(&"echo", -9.0, 0.60, 0.18)
		&"attack":
			var profile := weapon_profile(StringName(info.get("weapon_id", &"")))
			if not profile.is_empty():
				play(profile["cue"], float(profile["volume"]) - 6.0,
					float(profile["pitch"]), minf(0.16, float(profile.get("gate", 0.16))))


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
	_duck_room(0.82)


func _on_won() -> void:
	play(&"win")
	_duck_room(0.88)


func _on_silence(info: EchoSilenceInfo) -> void:
	if info.kind == EchoSilenceInfo.PHASE:
		# One authoritative PHASE event owns the synchronized .18s seam snap.
		play(&"boss", 1.5, 1.0)
		_duck_room(0.8)
		return
	if info.kind == EchoSilenceInfo.BOSS:
		play(&"silence")
