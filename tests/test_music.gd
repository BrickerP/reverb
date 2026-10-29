extends RefCounted


func _audio() -> GameAudio:
	var audio := GameAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	return audio


func test_score_assets_and_voice_budget(c: Check) -> void:
	var audio := _audio()
	c.eq(audio.music_state()["arrangements"], 5, "five complete score arrangements load")
	c.eq(audio.music_state()["nodes"], 2, "only two score crossfade players")
	c.eq(audio._players.size(), 12, "effect pool stays at twelve")
	c.eq(audio.get_child_count(), 14, "no ambient or per-shot music nodes")
	for mode in GameAudio.MUSIC_MODES:
		var stream: AudioStreamWAV = audio._music_streams[mode]
		c.near(stream.get_length(), 96.0, 0.001, "full-length arrangement %s" % mode)
		c.eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "score loops %s" % mode)
	c.eq(audio.music_state()["active_voices"], 0, "headless does not start audio playback")
	audio.free()


func test_real_phase_threat_attack_and_boss_select_arrangements(c: Check) -> void:
	var sim := Sim.new(12)
	c.eq(GameAudio.music_profile(null)["mode"], &"menu", "detached title score")
	sim.phase = Sim.Phase.SHOP
	c.eq(GameAudio.music_profile(sim)["mode"], &"shop", "actual shop phase")
	sim.phase = Sim.Phase.WAVE
	c.eq(GameAudio.music_profile(sim)["mode"], &"battle", "empty wave uses battle")
	for i in 8:
		var enemy := EnemyState.new()
		enemy.pos = sim.player.pos + Vector2(float(i) * 12.0, 0)
		enemy.brain_state = &"warn" if i < 3 else &"approach"
		sim.enemies.append(enemy)
	var before := sim.rng.state
	c.eq(GameAudio.music_profile(sim)["mode"], &"pressure", "nearby real warnings raise pressure")
	c.eq(GameAudio.music_profile(sim)["attacks"], 3, "only actual warned attacks counted")
	for enemy in sim.enemies:
		enemy.brain_state = &"approach"
	c.eq(GameAudio.music_profile(sim, &"battle")["mode"], &"battle", "ordinary crowd below entry threshold")
	sim.enemies[0].brain_state = &"dash"
	c.eq(GameAudio.music_profile(sim, &"pressure")["mode"], &"pressure", "hysteresis prevents attack-state chatter")
	for enemy in sim.enemies:
		enemy.pos += Vector2(2000.0, 0)
	c.eq(GameAudio.music_profile(sim, &"pressure")["mode"], &"battle", "distant threats cannot hold local pressure")
	sim.boss = EnemyState.new()
	c.eq(GameAudio.music_profile(sim)["mode"], &"boss", "authoritative living boss owns boss treatment")
	sim.boss.dead = true
	c.eq(GameAudio.music_profile(sim)["mode"], &"battle", "dead boss releases its score")
	c.eq(sim.rng.state, before, "mix analysis leaves simulation RNG unchanged")


func test_wave_push_and_breather_contribute_authoritative_pacing(c: Check) -> void:
	var sim := Sim.new(13)
	sim.phase = Sim.Phase.WAVE
	sim.wave_duration = 100.0
	for i in 13:
		var enemy := EnemyState.new()
		enemy.pos = sim.player.pos + Vector2(i * 8.0, 0)
		sim.enemies.append(enemy)
	sim.wave_time = 80.0
	c.eq(GameAudio.music_profile(sim)["mode"], &"pressure", "final push adds density to real local threats")
	c.eq(GameAudio.music_profile(sim)["wave_phase"], &"final_push", "mix reads director phase")
	sim.wave_time = 30.0
	c.eq(GameAudio.music_profile(sim)["mode"], &"battle", "real breather releases optional pressure entry")
	sim.enemies.clear()
	sim.wave_time = 80.0
	c.eq(GameAudio.music_profile(sim)["mode"], &"battle", "pacing alone cannot invent enemy pressure")


func test_crossfade_pause_mute_stop_and_session_cleanup(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(25)
	sim.start_run()
	audio.bind(sim)
	c.eq(audio.music_state()["mode"], &"battle", "binding joins actual wave phase")
	var before := sim.rng.state
	audio._process(5.0)
	var cursor: float = audio.music_state()["cursor"]
	sim.phase = Sim.Phase.SHOP
	audio._process(0.25)
	c.eq(audio.music_state()["mode"], &"shop", "shop bypasses combat intensity hold")
	c.ok(audio.music_state()["crossfade_remaining"] > 0.0, "state change crossfades")
	c.ok(audio.music_state()["cursor"] > cursor, "score position continues through crossfade")
	audio.set_paused(true)
	var paused := audio.music_state()
	audio._process(40.0)
	c.eq(audio.music_state()["cursor"], paused["cursor"], "pause freezes score transport")
	c.eq(audio.music_state()["crossfade_remaining"], paused["crossfade_remaining"], "pause freezes both envelopes")
	c.ok(audio.music_state()["paused"], "pause owns both crossfade players")
	c.ok(audio.toggle_mute(), "mute works during paused crossfade")
	audio.set_paused(false)
	audio._process(2.0)
	c.eq(audio.music_state()["crossfade_remaining"], 0.0, "crossfade resolves after resume")
	c.eq(sim.rng.state, before, "transport changes no gameplay randomness")
	c.ok(not audio.toggle_mute(), "restore master mute")
	audio.stop_all()
	c.ok(not audio.music_state()["enabled"], "explicit stop cannot restart on next process")
	audio._process(3.0)
	c.ok(not audio.music_state()["enabled"], "stopped score stays stopped")
	audio.bind(null)
	c.eq(audio.music_state()["mode"], &"menu", "detach clears prior session arrangement")
	c.eq(audio.music_state()["cursor"], 0.0, "new session starts a fresh score clock")
	c.eq(audio.music_state()["crossfade_remaining"], 0.0, "no old session fade")
	audio.free()


func test_independent_gains_clamp_and_persist(c: Check) -> void:
	var audio := _audio()
	audio.set_music_volume(0.0)
	c.eq(audio.music_state()["music_volume"], 0.0, "music has independent zero gain")
	c.eq(audio.music_state()["effects_volume"], 1.0, "music gain does not change effects")
	audio.set_effects_volume(-1.0)
	audio.set_music_volume(2.0)
	c.eq(audio.music_state()["effects_volume"], 0.0, "effect gain clamps lower boundary")
	c.eq(audio.music_state()["music_volume"], 1.0, "music gain clamps upper boundary")
	c.ok(audio.play(&"click"), "zero-volume effect still routes without changing gameplay")
	var path := "user://test_music_settings.json"
	var settings := Settings.new(path)
	settings.music_volume = 0.21
	settings.effects_volume = 0.64
	settings.save()
	var restored := Settings.new(path)
	c.near(restored.music_volume, 0.21, 0.0001, "music setting persists")
	c.near(restored.effects_volume, 0.64, 0.0001, "effect setting persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	audio.free()


func test_retirement_kind_and_exhaustion_have_causal_feedback(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(83)
	sim.start_run()
	audio.bind(sim)
	var retired := EchoRetirementInfo.new()
	retired.kind = &"pin"
	audio.play(&"weapon_longbow")
	sim.echo_retired.emit(retired)
	c.eq(audio.play_count(&"weapon_longbow"), 2, "explicit retirement cannot disappear behind a shot cooldown")
	c.eq(audio.play_count(&"weapon_explosion"), 0, "retirement adds no generic explosion")
	c.near(audio._duck_remaining, 0.32, 0.001, "active skill has restrained transition envelope")
	audio._process(1.0)
	var exhausted := EchoRetirementInfo.new()
	exhausted.reason = EchoRetirementInfo.EXHAUSTED
	exhausted.exhausted = true
	sim.echo_retired.emit(exhausted)
	c.eq(audio.play_count(&"echo"), 1, "exhaustion uses quiet feeding-out accent")
	c.eq(audio._duck_remaining, 0.0, "exhaustion has no active skill weight")
	audio.bind(null)
	sim.echo_retired.emit(retired)
	c.eq(audio.play_count(&"weapon_longbow"), 2, "old retirement signal disconnects with session")
	audio.free()
