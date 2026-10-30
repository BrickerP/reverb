extends RefCounted


func _audio() -> GameAudio:
	var audio := GameAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	return audio


func _shot(id: StringName, sequence: int = 1, source: int = -1) -> ShotInfo:
	var info := ShotInfo.new()
	info.weapon_id = id
	info.sequence = sequence
	info.source = source
	return info


func test_streams_load(c: Check) -> void:
	var audio := _audio()
	c.eq(GameAudio.NAMES.size(), 14, "base event set remains complete")
	c.eq(audio.stream_count(), GameAudio.ALL_NAMES.size(), "one stream per routed cue")
	for name in GameAudio.ALL_NAMES:
		c.ok(audio.has_stream(name), "loaded %s" % name)
	c.eq(audio._players.size(), GameAudio.POOL, "voice pool remains bounded")
	c.eq(audio._common_players.size(), GameAudio.COMMON_POOL, "common voice allocation")
	c.eq(audio._protected_players.size(), GameAudio.PROTECTED_POOL, "protected voice allocation")
	audio.free()


func test_every_stream_uses_one_complete_paperbureau_palette(c: Check) -> void:
	for name: StringName in GameAudio.ALL_NAMES:
		c.eq(
			GameAudio.stream_path(name),
			"res://audio/presentation/%s.wav" % name,
			"presentation cue %s" % name,
		)
	c.eq(GameAudio.ALL_NAMES.size(), 35, "palette keeps its bounded runtime identities")
	c.ok(not ResourceLoader.exists("res://audio/shoot.wav"), "superseded tonal placeholders removed")


func test_all_weapons_have_explicit_distinct_profiles(c: Check) -> void:
	var weapons := Content.weapons()
	c.eq(GameAudio.WEAPON_PROFILES.size(), weapons.size(), "all weapon ids mapped")
	var profiles := {}
	for id: StringName in weapons:
		var profile := GameAudio.weapon_profile(id)
		c.ok(not profile.is_empty(), "profile %s" % id)
		var cue: StringName = profile.get("cue", &"")
		c.ok(GameAudio.FEEDBACK_NAMES.has(cue), "profile stream %s" % id)
		var signature := "%s/%s/%s" % [cue, profile["pitch"], profile.get("gate", 0.0)]
		c.ok(not profiles.has(signature), "distinct material pitch/envelope %s" % id)
		profiles[signature] = true
	c.eq(GameAudio.weapon_profile(&"longbow")["cue"], &"weapon_longbow", "longbow uses its pluck asset")
	c.ok(GameAudio.weapon_profile(&"missing").is_empty(), "unknown weapons use the generic fallback")


func test_rich_combat_signals_replace_legacy_duplicates(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(3)
	sim.start_run()
	audio.bind(sim)

	sim.shot_fired.emit(-1)
	sim.shot_fired_info.emit(_shot(&"pistol"))
	c.eq(audio.play_count(&"shoot"), 0, "legacy shot is not double-bound")
	c.eq(audio.play_count(&"weapon_pistol"), 1, "rich shot selects weapon profile")

	sim.enemy_hit.emit(Vector2.ZERO, 2.0, false, -1)
	var hit := DamageInfo.new()
	sim.damage_event.emit(hit)
	c.eq(audio.play_count(&"hit"), 1, "rich normal damage plays once")
	hit = DamageInfo.new()
	hit.crit = true
	sim.damage_event.emit(hit)
	c.eq(audio.play_count(&"hit_crit"), 1, "critical damage has a strong cue")
	hit = DamageInfo.new()
	hit.reduced = true
	sim.damage_event.emit(hit)
	c.eq(audio.play_count(&"shield_block"), 1, "shield reduction has a distinct cue")

	var blast := ExplosionInfo.new()
	sim.explosion_info.emit(blast)
	c.eq(audio.play_count(&"weapon_explosion"), 1, "weapon blast cue")
	blast = ExplosionInfo.new()
	blast.kind = ExplosionInfo.BOMBER
	sim.explosion_info.emit(blast)
	c.eq(audio.play_count(&"bomber_explosion"), 1, "bomber blast cue")

	sim.player_hurt.emit(3.0)
	var hurt := PlayerHurtInfo.new()
	sim.player_hurt_info.emit(hurt)
	c.eq(audio.play_count(&"hurt"), 0, "legacy hurt is not double-bound")
	c.eq(audio.play_count(&"hurt_contact"), 1, "rich contact hurt cue")
	hurt = PlayerHurtInfo.new()
	hurt.effect = &"bomber_explosion"
	sim.player_hurt_info.emit(hurt)
	c.eq(audio.play_count(&"hurt_blast"), 1, "rich explosive hurt cue")
	audio.free()


func test_remaining_existing_events_stay_bound(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(4)
	sim.start_run()
	audio.bind(sim)
	sim.enemy_killed.emit(EnemyDeathInfo.new())
	sim.material_collected.emit(2)
	var take := EchoTake.new()
	take.samples.append(Vector2.ZERO)
	sim.echo_spawned.emit(EchoActor.new(take, 0))
	sim.wave_started.emit(2)
	sim.wave_ended.emit(2)
	sim.run_lost.emit()
	sim.run_won.emit()
	sim.boss_spawned.emit(EnemyState.new())
	var silence := EchoSilenceInfo.new()
	silence.kind = EchoSilenceInfo.BOSS
	silence.duration = 2.0
	sim.echoes_silenced.emit(silence)
	c.ok(audio.play(&"click"), "UI click stays public")
	c.eq(audio.play_count(&"kill"), 1, "kill cue")
	c.eq(audio.play_count(&"pickup"), 1, "pickup cue")
	c.eq(audio.play_count(&"echo"), 1, "echo cue")
	c.eq(audio.play_count(&"wave_start"), 1, "wave start cue")
	c.eq(audio.play_count(&"wave_end"), 1, "wave end cue")
	c.eq(audio.play_count(&"lose"), 1, "loss cue")
	c.eq(audio.play_count(&"win"), 1, "win cue")
	c.eq(audio.play_count(&"boss"), 0, "boss arrival does not borrow the phase tear cue")
	c.eq(audio.play_count(&"silence"), 1, "silence cue")
	c.eq(audio.play_count(&"click"), 1, "click cue")
	audio.free()


func test_purchase_apply_once_and_shop_actions_are_distinct(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(7)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 500
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 20
	sim.shop.offers.clear()
	sim.shop.offers.append(offer)
	audio.bind(sim)
	c.ok(sim.shop.apply(ShopResult.BUY, sim, offer).ok, "buy succeeds")
	c.eq(audio.play_count(&"equipment_apply"), 1, "purchased is the sole apply cue")
	c.eq(audio.play_count(&"equipment_undo"), 0, "buy result adds no duplicate cue")
	c.ok(sim.shop.apply(ShopResult.UPGRADE, sim, null, 1).ok, "first upgrade succeeds")
	c.ok(sim.shop.apply(ShopResult.UPGRADE, sim, null, 1).ok, "second upgrade succeeds")
	c.eq(audio.play_count(&"equipment_apply"), 3, "rapid applies are each accepted")
	c.ok(sim.shop.undo(sim).ok, "first undo succeeds")
	c.ok(sim.shop.undo(sim).ok, "second undo succeeds")
	c.eq(audio.play_count(&"equipment_undo"), 2, "rapid undos are each accepted")
	sim.player.materials = 500
	c.ok(sim.shop.apply(ShopResult.REROLL, sim).ok, "first reroll succeeds")
	c.ok(sim.shop.apply(ShopResult.REROLL, sim).ok, "second reroll succeeds")
	c.eq(audio.play_count(&"shop_reroll"), 2, "rapid rerolls are each accepted")
	audio.free()


func test_bind_is_idempotent_and_rebind_disconnects_old_sim_and_shop(c: Check) -> void:
	var audio := _audio()
	var first := Sim.new(1)
	var second := Sim.new(2)
	first.start_run()
	second.start_run()
	audio.bind(first)
	audio.bind(first)
	first.wave_started.emit(2)
	c.eq(audio.play_count(&"wave_start"), 1, "same sim does not connect twice")
	audio.bind(second)
	first.wave_started.emit(3)
	first.shop.shop_action_resolved.emit(ShopResult.success(ShopResult.UNDO, 0))
	c.eq(audio.play_count(&"wave_start"), 1, "old sim disconnected")
	c.eq(audio.play_count(&"equipment_undo"), 0, "old shop disconnected")
	second.wave_started.emit(3)
	second.shop.shop_action_resolved.emit(ShopResult.success(ShopResult.UNDO, 0))
	c.eq(audio.play_count(&"wave_start"), 2, "new sim connected")
	c.eq(audio.play_count(&"equipment_undo"), 1, "new shop connected")

	audio._player_cues[audio._players[0]] = &"weapon_pistol"
	audio.bind(null)
	var state := audio.binding_state()
	c.ok(not state["sim_bound"] and not state["shop_bound"], "detach releases both emitters")
	c.ok(not state["paused"], "detach clears pause state")
	c.eq(state["active_sfx"], 0, "detach stops SFX")
	c.eq(state["cooldowns"], 0, "detach clears cooldown routing")
	c.eq(state["routed_voices"], 0, "detach clears voice routing")
	second.wave_started.emit(4)
	c.eq(audio.play_count(&"wave_start"), 2, "bind null disconnects and preserves diagnostics")
	audio.free()


func test_echo_device_work_uses_bounded_palette_without_duplicate_signature_or_stale_binding(c: Check) -> void:
	var audio := _audio()
	var first := Sim.new(1616)
	var next := Sim.new(1617)
	first.start_run()
	next.start_run()
	audio.bind(first)
	first.echo_work_performed.emit({"kind": &"press", "success": true})
	c.eq(audio.play_count(&"weapon_rail_spike"), 1, "successful press has a dry machine accent")
	first.echo_work_performed.emit({"kind": &"conveyor", "success": true})
	c.eq(audio.play_count(&"click"), 1, "successful conveyor work has its own bounded cue")
	first.echo_work_performed.emit({"kind": &"press", "success": false})
	first.echo_work_performed.emit({"kind": &"signature", "success": true})
	c.eq(audio.play_count(&"weapon_rail_spike"), 1, "failure and signature marker do not duplicate attack audio")
	c.eq(audio._players.size(), GameAudio.POOL, "work uses existing voice limit")
	audio.bind(next)
	first.echo_work_performed.emit({"kind": &"conveyor", "success": true})
	c.eq(audio.play_count(&"click"), 1, "old simulation cannot play work after rebind")
	audio.bind(null)
	next.echo_work_performed.emit({"kind": &"conveyor", "success": true})
	c.eq(audio.play_count(&"click"), 1, "detached session cannot leak work audio")
	audio.free()


func test_pause_keeps_ui_feedback_and_blocks_combat(c: Check) -> void:
	var audio := _audio()
	c.ok(not audio._music.playing, "headless ambient never starts")
	audio.set_paused(true)
	c.ok(audio.is_paused(), "pause state recorded")
	c.ok(not audio.play(&"weapon_pistol"), "combat cue blocked while paused")
	c.ok(audio.play(&"click"), "UI click remains available")
	c.eq(audio.play_count(&"weapon_pistol"), 0, "blocked combat is not counted")
	c.eq(audio.play_count(&"click"), 1, "pause UI click counted")
	c.ok(audio.toggle_mute(), "mute remains available while paused")
	audio.set_paused(false)
	c.ok(not audio.is_paused(), "pause state clears")
	c.ok(not audio._music.playing, "unpausing does not start ambient in headless mode")
	c.ok(audio.is_muted(), "unpausing does not change mute")
	c.ok(audio.play(&"weapon_pistol"), "combat cue resumes")
	c.ok(not audio.toggle_mute(), "restore master bus")
	audio.free()


func test_headless_counts_without_playback_and_priority_isolated(c: Check) -> void:
	var audio := _audio()
	c.ok(audio._silent, "test runner uses headless audio mode")
	c.ok(GameAudio.is_protected(&"hurt_contact"), "hurt has protected voices")
	c.ok(GameAudio.is_protected(&"boss"), "boss has protected voices")
	c.ok(GameAudio.is_protected(&"click"), "UI stinger has protected voices")
	c.ok(GameAudio.is_protected(&"shield_block"), "shield impact has protected voices")
	c.ok(not GameAudio.is_protected(&"weapon_smg"), "dense shots use common voices")
	c.eq(GameAudio.COMMON_POOL + GameAudio.PROTECTED_POOL, GameAudio.POOL,
			"priority policy stays inside the bounded pool")
	var common := audio._claim_player(&"weapon_smg")
	var protected_player := audio._claim_player(&"shield_block")
	c.ok(audio._common_players.has(common), "common cue claims only common voices")
	c.ok(not audio._protected_players.has(common), "common cannot steal a protected voice")
	c.ok(audio._protected_players.has(protected_player), "important cue claims a protected voice")
	var common_active: Array[bool] = [true, true, true, true, true, true, true]
	var common_priorities: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	var common_serials: Array[int] = [1, 2, 3, 4, 5, 6, 7]
	c.eq(GameAudio.voice_index(common_active, common_priorities, common_serials, 0), 0,
			"saturated shots reclaim only the common lane")
	var active: Array[bool] = [true, true, true, true, true]
	var serials: Array[int] = [1, 2, 3, 4, 5]
	var protected_priorities: Array[int] = [20, 50, 60, 70, 80]
	c.eq(GameAudio.voice_index(active, protected_priorities, serials,
			GameAudio.priority_for(&"shield_block")), 0,
			"shield can only reclaim the equal low-priority voice")
	protected_priorities = [50, 55, 60, 70, 80]
	c.eq(GameAudio.voice_index(active, protected_priorities, serials,
			GameAudio.priority_for(&"shield_block")), -1,
			"shield spam cannot steal hurt boss UI or win")
	c.eq(GameAudio.voice_index(active, protected_priorities, serials,
			GameAudio.priority_for(&"win")), 0,
			"critical stinger can reclaim the lowest protected voice")
	c.ok(audio.play(&"weapon_smg"), "headless play is accepted")
	for player in audio._players:
		c.ok(not player.playing, "headless never starts a voice")
	audio.free()


func test_audio_variation_does_not_consume_sim_rng(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(99)
	sim.start_run()
	audio.bind(sim)
	var before := sim.rng.state
	sim.shot_fired_info.emit(_shot(&"orb", 17, 1))
	var hit := DamageInfo.new()
	hit.weapon_id = &"orb"
	hit.crit = true
	hit.source = 1
	sim.damage_event.emit(hit)
	c.eq(sim.rng.state, before, "audio pitch variation leaves Sim RNG untouched")
	audio.free()


func test_play_and_cooldown(c: Check) -> void:
	var audio := _audio()
	c.ok(audio.play(&"hit"), "the first hit plays")
	c.eq(audio.play_count(&"hit"), 1, "counted once")
	c.ok(not audio.play(&"hit"), "the cooldown suppresses the next hit")
	c.eq(audio.play_count(&"hit"), 1, "still once")
	audio.free()


func test_mute_toggles_the_master_bus(c: Check) -> void:
	var audio := _audio()
	c.ok(not audio.is_muted(), "starts unmuted")
	c.ok(audio.toggle_mute(), "mutes")
	c.ok(AudioServer.is_bus_mute(0), "master bus is muted")
	c.ok(not audio.toggle_mute(), "unmutes")
	c.ok(not AudioServer.is_bus_mute(0), "master bus is back")
	audio.free()


func test_phase_tear_and_global_silence_have_separate_causal_cues(c: Check) -> void:
	var audio := _audio()
	var sim := Sim.new(18)
	sim.start_run()
	audio.bind(sim)
	sim.boss_spawned.emit(EnemyState.new())
	c.eq(audio.play_count(&"boss"), 0, "arrival cannot play a seam snap without a tear")
	c.eq(audio._duck_remaining, 0.0, "arrival uses the existing wave entry mix")
	var contact := EchoSilenceInfo.new()
	contact.kind = EchoSilenceInfo.CONTACT
	sim.echoes_silenced.emit(contact)
	c.eq(audio.play_count(&"silence"), 0, "local seal cannot manufacture global silence audio")
	c.eq(audio.play_count(&"boss"), 0, "contact cannot manufacture a boss tear")
	c.eq(audio._duck_remaining, 0.0, "contact silence does not create a major transition duck")
	var cast := EchoSilenceInfo.new()
	cast.kind = EchoSilenceInfo.BOSS
	sim.echoes_silenced.emit(cast)
	c.eq(audio.play_count(&"silence"), 1, "boss cast owns the global silence cue")
	c.eq(audio.play_count(&"boss"), 0, "boss cast is distinct from phase tearing")
	c.eq(audio._duck_remaining, 0.0, "boss cast does not duck the transition mix")
	var phase := EchoSilenceInfo.new()
	phase.kind = EchoSilenceInfo.PHASE
	sim.echoes_silenced.emit(phase)
	c.eq(audio.play_count(&"boss"), 1, "actual phase event selects the tension and tear recording")
	c.eq(audio.play_count(&"silence"), 1, "phase does not add another ambiguous silence sound")
	c.ok(audio._duck_remaining >= 0.8, "phase gives its seam snap room in the ambience")
	var state := sim.rng.state
	audio._process(0.7)
	c.ok(audio._music.volume_db < (GameAudio.MUSIC_DB + linear_to_db(0.8)), "short release remains after the snap")
	audio._process(0.2)
	c.near(audio._music.volume_db, (GameAudio.MUSIC_DB + linear_to_db(0.8)), 0.0001, "score returns to its mix level")
	c.eq(sim.rng.state, state, "transition mix changes no simulation RNG")
	audio.bind(null)
	sim.echoes_silenced.emit(phase)
	c.eq(audio.play_count(&"boss"), 1, "detached old phase signal is silent")
	audio.free()


func test_ambient_duck_freezes_on_pause_and_clears_on_rebind(c: Check) -> void:
	var audio := _audio()
	audio._on_lost()
	c.eq(audio._duck_remaining, 0.82, "death crumple owns a bounded bed duck")
	c.near(audio._music.volume_db, (GameAudio.MUSIC_DB + linear_to_db(0.8)) + GameAudio.TRANSITION_DUCK_DB, 0.0001,
			"dramatic cue ducks the quiet room rather than adding a new voice")
	audio.set_paused(true)
	audio._process(20.0)
	c.eq(audio._duck_remaining, 0.82, "pause freezes the presentation envelope")
	var sim := Sim.new(42)
	sim.start_run()
	audio.bind(sim)
	c.eq(audio._duck_remaining, 0.0, "new session cannot inherit an old death duck")
	c.near(audio._music.volume_db, (GameAudio.MUSIC_DB + linear_to_db(0.8)), 0.0001, "rebind restores the score")
	audio.set_paused(true)
	var phase := EchoSilenceInfo.new()
	phase.kind = EchoSilenceInfo.PHASE
	sim.echoes_silenced.emit(phase)
	c.eq(audio.play_count(&"boss"), 0, "paused combat transition cannot play")
	c.eq(audio._duck_remaining, 0.0, "blocked transition does not alter the bed")
	c.ok(audio.play(&"click"), "UI keeps its physical paper click while paused")
	audio.free()
