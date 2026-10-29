extends SceneTree

var failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	await process_frame
	var audio := GameAudio.new()
	root.add_child(audio)
	# The headless Dummy driver exercises the real playback objects, with no
	# speaker output; the normal headless suite deliberately only counts cues.
	audio._silent = false
	var sim := Sim.new(81)
	sim.start_run()
	audio.bind(sim)
	var rng_before := sim.rng.state
	await create_timer(0.12).timeout
	_check(audio._music.playing, "real Dummy stream starts")
	_check(audio._music.get_playback_position() > 0.0, "real score cursor advances")
	sim.phase = Sim.Phase.SHOP
	await create_timer(0.35).timeout
	_check(audio.music_state()["mode"] == &"shop", "real phase changes arrangement")
	_check(audio.music_state()["active_voices"] == 2, "crossfade has exactly two voices")
	var positions: Array[float] = []
	audio.set_paused(true)
	for player in audio._music_players:
		_check(player.stream_paused, "both actual streams pause")
		positions.append(player.get_playback_position())
	var cursor: float = audio.music_state()["cursor"]
	await create_timer(0.16).timeout
	_check(audio.music_state()["cursor"] == cursor, "paused transport stays still")
	for i in audio._music_players.size():
		_check(absf(audio._music_players[i].get_playback_position() - positions[i]) < 0.04,
				"paused stream position stays still")
	audio.set_paused(false)
	await create_timer(1.4).timeout
	_check(audio.music_state()["active_voices"] == 1, "old arrangement stops after fade")
	audio._music.seek(95.92)
	await create_timer(0.24).timeout
	_check(audio._music.playing and audio._music.get_playback_position() < 1.0,
			"full 96-second score loops through the actual sample endpoint")
	audio.toggle_mute()
	await create_timer(0.08).timeout
	_check(audio.music_state()["cursor"] > cursor, "muting preserves transport")
	audio.toggle_mute()
	audio.set_music_volume(0.0)
	_check(audio._music.volume_db <= -80.0, "music slider zero silences only score")
	_check(audio.music_state()["effects_volume"] == 1.0, "effects remain independent")
	audio.play(&"weapon_pistol", 0.0, 0.73, 0.10)
	await create_timer(0.15).timeout
	_check(audio.binding_state()["active_sfx"] == 0, "actual gate releases bounded weapon voice")
	_check(sim.rng.state == rng_before, "actual playback consumes no simulation RNG")
	audio.stop_all()
	_check(audio.music_state()["active_voices"] == 0, "stop removes both music voices")
	audio.free()
	sim = null
	# Let the audio mix thread release its final playback resource before quit.
	await create_timer(0.20).timeout
	print(JSON.stringify({"probe": "music_lifecycle", "failures": failures,
		"music_voice_limit": 2, "effect_voice_limit": 12}))
	quit(0 if failures.is_empty() else 1)
