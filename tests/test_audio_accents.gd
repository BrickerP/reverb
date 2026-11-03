extends RefCounted


func _audio(sim: Sim = null) -> GameAudio:
	var audio := GameAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	if sim != null:
		audio.bind(sim)
	return audio


func _shot(source: int, token: int) -> ShotInfo:
	var info := ShotInfo.new()
	info.weapon_id = &"pistol"
	info.source = source
	info.actor_token = token
	return info


func _combo(source: int = -1, token: int = -1) -> ComboInfo:
	var info := ComboInfo.new()
	info.id = &"ink_arc"
	info.source = source
	info.actor_token = token
	info.affected = 3
	info.bonus_damage = 10.0
	return info


func test_eight_echo_shots_coalesce_without_muting_the_player(c: Check) -> void:
	var audio := _audio()
	for i in 8:
		audio._on_shot_info(_shot(i, -8 - i))
	c.eq(audio.play_count(&"weapon_pistol"), 1, "copies share one material window, not one voice per uid")
	var copy := audio.feedback_last_data()
	audio._on_shot_info(_shot(-1, -1))
	c.eq(audio.play_count(&"weapon_pistol"), 2, "preceding Echo cannot consume the player's shot window")
	var player := audio.feedback_last_data()
	c.near(float(player["volume_db"]) - float(copy["volume_db"]), 6.0, 0.001, "copy bed is six dB below the same player material")
	c.ok(player["priority"] > copy["priority"], "player can reclaim an ordinary copy voice")
	c.ok(GameAudio.is_copy_source(-1, -77), "negative opaque owner tokens remain copies")
	c.ok(not GameAudio.is_copy_source(-1, -1), "player sentinel stays player")
	c.eq(audio._players.size(), GameAudio.POOL, "multiple copies add no audio nodes")
	audio.free()


func test_priority_owns_lane_and_stronger_events_break_a_merge_window(c: Check) -> void:
	var audio := _audio()
	c.ok(audio._common_players.has(audio._claim_player(&"equipment_apply", GameAudio.SUPPORT_PRIORITY)),
		"support repair borrowing a transaction sample cannot occupy protected voices")
	c.ok(audio._protected_players.has(audio._claim_player(&"weapon_rail_spike", 44)),
		"accepted sacrifice borrowing a weapon sample gets a protected voice")
	var active: Array[bool] = [true, true, true]
	var priorities: Array[int] = [GameAudio.PLAYER_SHOT_PRIORITY, 0, 0]
	var serials: Array[int] = [1, 2, 3]
	c.eq(GameAudio.voice_index(active, priorities, serials, 0), 1, "copy cannot steal the player's routine voice")
	c.ok(audio.play(&"hurt_contact", 0.0, 1.0, 0.2, 50, &"test:hurt", 0.3), "ordinary actual harm starts")
	c.ok(audio.play(&"hurt_contact", 2.0, 0.9, 0.2, 58, &"test:hurt", 0.3), "more severe harm cannot vanish in its merge window")
	c.ok(not audio.play(&"hurt_contact", 0.0, 1.0, 0.2, 50, &"test:hurt", 0.3), "lower-priority repeated harm stays merged")
	audio.free()


func test_real_pin_press_damage_owns_combo_accent_and_rng_stays_read_only(c: Check) -> void:
	var sim := Sim.new(222)
	sim.start_run()
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"grunt")
	enemy.uid = 817
	enemy.hp = 1000.0
	enemy.radius = enemy.def.radius
	enemy.pos = Sim.ARENA.get_center()
	enemy.pin_left = 1.0
	sim.enemies.append(enemy)
	var audio := _audio(sim)
	var rng_before := sim.rng.state
	Combat._hit(sim, enemy, 20.0, Vector2.RIGHT, 0.0, false, -1, -1, Color.WHITE,
		&"stamp", &"stamp", 0.0, 0.0, false)
	c.eq(audio.play_count(&"weapon_rail_spike"), 1, "actual consumed pin interaction has one press accent")
	c.eq(audio.feedback_last_data()["merge_key"], &"accent:combo_pin_press", "damage event cannot impersonate combo success")
	c.ok(audio.feedback_last_data()["priority"] >= GameAudio.PROTECTED_PRIORITY, "real interaction remains audible over routine shots")
	c.ok(audio._duck_remaining > 0.0 and audio._duck_remaining <= 0.12, "combo briefly opens space in music")
	c.eq(sim.rng.state, rng_before, "combat accent consumes no gameplay randomness")
	audio.free()


func test_combo_success_echo_merging_and_detach(c: Check) -> void:
	var sim := Sim.new(223)
	sim.start_run()
	var audio := _audio(sim)
	sim.combo_triggered.emit(ComboInfo.new())
	c.eq(audio.play_count(&"weapon_hex_bolt"), 0, "empty projected interaction cannot play a success")
	for i in 8:
		sim.combo_triggered.emit(_combo(i, -20 - i))
	c.eq(audio.play_count(&"weapon_hex_bolt"), 1, "same-type Echo interactions share one restrained accent")
	c.eq(audio._duck_remaining, 0.0, "copy successes cannot pump the music bed")
	sim.combo_triggered.emit(_combo())
	c.eq(audio.play_count(&"weapon_hex_bolt"), 2, "player interaction has an independent window")
	var event := audio.feedback_last_data()
	event["priority"] = -100
	c.eq(audio.feedback_last_data()["priority"], 36, "feedback diagnostics return detached values")
	audio.bind(null)
	sim.combo_triggered.emit(_combo())
	c.eq(audio.play_count(&"weapon_hex_bolt"), 2, "old combat success is disconnected")
	c.ok(audio.feedback_last_data().is_empty(), "new session cannot retain old cue identity")
	audio.free()


func test_actual_hp_loss_and_absorption_have_different_feedback(c: Check) -> void:
	var audio := _audio()
	var block := PlayerHurtInfo.new()
	block.absorbed = 6.0
	audio._on_hurt_info(block)
	c.eq(audio.play_count(&"shield_block"), 1, "full absorption has a clamp, not body crumple")
	c.eq(audio.play_count(&"hurt_contact"), 0, "shield absorption cannot claim HP harm")
	var hurt := PlayerHurtInfo.new()
	hurt.amount = 8.0
	hurt.absorbed = 2.0
	hurt.hp_loss = 6.0
	hurt.hp_before = 30.0
	audio._on_hurt_info(hurt)
	c.eq(audio.play_count(&"hurt_contact"), 1, "actual partial-block HP loss has one body cue")
	c.eq(audio.play_count(&"shield_block"), 1, "partial block adds no simultaneous second impact")
	hurt.hp_loss = 0.0
	audio._on_hurt_info(hurt)
	c.eq(audio.play_count(&"hurt_contact"), 1, "outer event with nested loss already accounted cannot replay body damage")
	audio._process(1.0)
	audio.set_effects_volume(0.0)
	audio._last.erase(&"player:block")
	audio._on_hurt_info(block)
	c.eq(audio._duck_remaining, 0.0, "disabled effects cannot silently pump the music")
	audio.free()


func test_active_sacrifice_is_distinct_from_quiet_group_exhaustion(c: Check) -> void:
	var audio := _audio()
	var exhausted := EchoRetirementInfo.new()
	exhausted.reason = EchoRetirementInfo.EXHAUSTED
	exhausted.exhausted = true
	for i in 8:
		audio._on_echo_retired(exhausted)
	c.eq(audio.play_count(&"echo"), 1, "simultaneous worn-out copies feed out once")
	c.eq(audio._duck_remaining, 0.0, "natural wear cannot claim a dramatic sacrifice")
	var quiet := audio.feedback_last_data()
	var active := EchoRetirementInfo.new()
	active.kind = &"stamp"
	for i in 8:
		audio._on_echo_retired(active)
	c.eq(audio.play_count(&"weapon_rail_spike"), 1, "same-frame overload sacrifices form one real accent")
	c.ok(audio.feedback_last_data()["priority"] > quiet["priority"], "deliberate sacrifice owns protected space")
	c.near(audio._duck_remaining, 0.32, 0.001, "active sacrifice retains its short beat")
	c.eq(audio.play_count(&"weapon_explosion"), 0, "retirement does not become a generic blast")
	audio.free()


func test_machine_and_rescue_use_single_canonical_success_events(c: Check) -> void:
	var sim := Sim.new(224)
	sim.start_run()
	var audio := _audio(sim)
	var snapshot := RunSnapshot.capture(sim)
	sim.world_event.emit({"kind": &"machine_repaired"})
	var machine := audio.feedback_last_data()
	sim.world_event.emit({"kind": &"interaction_result", "target_kind": &"repair", "ok": true})
	c.eq(audio.play_count(&"equipment_apply"), 1, "interaction wrapper does not duplicate machine success")
	sim.world_event.emit({"kind": &"worker_saved"})
	var rescue := audio.feedback_last_data()
	sim.world_event.emit({"kind": &"interaction_result", "target_kind": &"rescue", "ok": true})
	c.eq(audio.play_count(&"echo"), 1, "interaction wrapper does not duplicate rescued worker")
	c.ok(machine["cue"] != rescue["cue"] and machine["pitch"] != rescue["pitch"], "mechanical closure and living-person release have different materials")
	c.eq(RunSnapshot.capture(sim), snapshot, "mix never changes interaction outcomes or RNG")
	audio.set_paused(true)
	sim.world_event.emit({"kind": &"machine_repaired"})
	c.eq(audio.play_count(&"equipment_apply"), 1, "UI recording reuse cannot bypass paused gameplay")
	c.ok(audio.play(&"click"), "paused real UI remains available")
	audio.free()


func test_charge_only_accents_a_real_recharged_edge(c: Check) -> void:
	var sim := Sim.new(225)
	sim.start_run()
	var audio := _audio(sim)
	audio._observe_charge()
	c.eq(audio.play_count(&"click"), 0, "full starting charge does not invent a recovery beat")
	sim.character_energy = 99.0
	audio._observe_charge()
	sim.character_energy = 100.0
	sim.character_cooldown = 1.0
	audio._observe_charge()
	c.eq(audio.play_count(&"click"), 0, "full energy still cooling down is not charged")
	sim.character_cooldown = 0.0
	audio._observe_charge()
	c.eq(audio.play_count(&"click"), 1, "actual readiness edge owns one short up-click")
	audio._observe_charge()
	c.eq(audio.play_count(&"click"), 1, "held full charge does not repeat")
	sim.character_energy = 0.0
	audio._observe_charge()
	audio.set_paused(true)
	sim.character_energy = 100.0
	audio._observe_charge()
	c.eq(audio.play_count(&"click"), 1, "readiness cannot borrow paused UI click permission")
	audio.set_paused(false)
	sim.wave_started.emit(2)
	audio._observe_charge()
	c.eq(audio.play_count(&"click"), 1, "new wave seeds charge rather than replaying an old edge")
	audio.free()


func test_pacing_accents_observed_entries_without_startup_or_boss_false_tear(c: Check) -> void:
	var sim := Sim.new(226)
	sim.start_run()
	var audio := _audio(sim)
	audio._observe_emphasis({"mode": &"battle", "wave_phase": &"first_push"})
	c.eq(audio.play_count(&"wave_start"), 0, "first cohort already has the real wave-start cue")
	audio._observe_emphasis({"mode": &"battle", "wave_phase": &"second_push"})
	c.eq(audio.play_count(&"wave_start"), 1, "new finite second cohort has one restrained pulse")
	audio._observe_emphasis({"mode": &"battle", "wave_phase": &"second_push"})
	c.eq(audio.play_count(&"wave_start"), 1, "held push cannot repeat")
	audio._observe_emphasis({"mode": &"boss", "wave_phase": &"final_push"})
	c.eq(audio.play_count(&"wave_start"), 1, "boss pacing cannot masquerade as a new ordinary cohort")
	c.eq(audio.play_count(&"boss"), 0, "ordinary phase never fabricates the Boss seam sound")
	audio.free()
