extends RefCounted


func _enemy(sim: Sim, kind: StringName, uid: int, pos: Vector2) -> EnemyState:
	var e := EnemyState.new()
	e.uid = uid
	e.def = Content.enemy(kind)
	e.pos = pos
	e.radius = e.def.radius
	e.max_hp = 5.0
	e.hp = 5.0
	sim.enemies.append(e)
	return e


func test_death_is_one_value_snapshot_at_the_actual_kill(c: Check) -> void:
	var sim := Sim.new(7)
	sim.start_run()
	var e := _enemy(sim, &"runner", 711, sim.player.pos + Vector2(80.0, 0.0))
	var events: Array[EnemyDeathInfo] = []
	var already_dead: Array[bool] = []
	var not_compacted: Array[bool] = []
	var weak_sim: WeakRef = weakref(sim)
	sim.enemy_killed.connect(func(info: EnemyDeathInfo) -> void:
		events.append(info)
		already_dead.append(e.dead)
		not_compacted.append((weak_sim.get_ref() as Sim).enemies.has(e)))
	sim.damage_enemy(e, 2.0, Vector2.ZERO, false, 2, Vector2.LEFT, &"longbow")
	c.eq(events.size(), 0, "nonlethal hits never create a corpse")
	sim.damage_enemy(e, 9.0, Vector2.ZERO, true, 2, Vector2.LEFT, &"longbow")
	c.eq(events.size(), 1, "one actual kill creates one snapshot")
	c.eq(already_dead, [true], "death is emitted after the gameplay dead flag")
	c.eq(not_compacted, [true], "the actual kill boundary precedes compaction")
	var event := events[0]
	c.eq(event.target_uid, 711, "snapshot identifies the exact enemy")
	c.eq(event.enemy_id, &"runner", "snapshot preserves the body identity")
	c.eq(event.weapon_id, &"longbow", "snapshot preserves actual damaging weapon")
	c.eq(event.source, 2, "echo source attribution is unchanged")
	c.eq(event.hit_dir, Vector2.LEFT, "knock/death direction comes from the real hit")
	var captured := event.pos
	e.pos += Vector2(100.0, 100.0)
	sim.enemies.clear()
	c.eq(event.pos, captured, "animation cannot chase a mutable or compacted EnemyState")
	c.eq(sim.kills, 1, "presentation snapshot does not duplicate kill accounting")


func test_contact_snapshot_does_not_add_an_attack_delay(c: Check) -> void:
	var sim := Sim.new(9)
	sim.start_run()
	sim._plan.clear()
	var e := _enemy(sim, &"runner", 901, sim.player.pos)
	sim.player.iframes = 0.0
	e.damage = 7.0
	e.speed = 0.0
	var events: Array[PlayerHurtInfo] = []
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: events.append(info))
	var before := sim.player.hp
	sim._move_enemies(0.0)
	c.near(sim.player.hp, before - 7.0, 0.001, "contact damage still happens immediately")
	c.eq(events.size(), 1, "one contact emits one rich hurt event")
	c.eq(events[0].source_uid, 901, "view can animate the exact contact body")
	c.eq(events[0].source, &"runner", "existing death-cause identity is retained")
	c.eq(events[0].effect, &"contact", "contact is not confused with an explosion")


func test_non_actor_hurt_and_death_audio_have_safe_semantics(c: Check) -> void:
	var event := PlayerHurtInfo.new()
	c.eq(event.source_uid, -1, "environmental damage has no invented attacking enemy")
	var pitches: Array[float] = []
	for kind in [&"grunt", &"runner", &"brute", &"silencer", &"bomber", &"warden", &"paradox"]:
		var profile := GameAudio.death_profile(kind)
		c.ok(float(profile["pitch"]) >= 0.5 and float(profile["pitch"]) <= 1.5,
				"paper-junk body voice remains inside the existing playback budget")
		if not pitches.has(float(profile["pitch"])):
			pitches.append(float(profile["pitch"]))
	c.ok(pitches.size() >= 5, "body types have distinct existing-cue cadence")


func test_silence_snapshot_distinguishes_real_contact_from_boss_cast(c: Check) -> void:
	var sim := Sim.new(11)
	sim.start_run()
	sim._plan.clear()
	sim.player.iframes = 0.0
	var bottle := _enemy(sim, &"silencer", 1101, sim.player.pos)
	bottle.damage = 1.0
	bottle.speed = 0.0
	var events: Array[EchoSilenceInfo] = []
	sim.echoes_silenced.connect(func(info: EchoSilenceInfo) -> void: events.append(info))
	var rng_before: int = sim.rng.state
	sim._move_enemies(0.0)
	c.eq(events.size(), 1, "contact silence has one authoritative source event")
	c.eq(events[0].kind, EchoSilenceInfo.CONTACT, "a bottle cannot be misread as a boss roar")
	c.eq(events[0].source_uid, 1101, "the exact silencing body is identified")
	c.eq(events[0].enemy_id, &"silencer", "silence preserves the existing content identity")
	c.near(sim.echo_silenced, bottle.def.silence_time, 0.001, "existing contact duration is unchanged")
	c.eq(sim.rng.state, rng_before, "source metadata consumes no simulation RNG")
	var boss := _enemy(sim, &"paradox", 1102, sim.player.pos + Vector2(200.0, 0.0))
	sim.boss = boss
	sim.boss_shards.append(boss)
	sim._boss_silence_cd = 0.0
	sim._boss_minion_cd = 100.0
	sim._boss_step(0.0)
	c.eq(events.size(), 2, "actual boss cast emits its own event")
	c.eq(events[1].kind, EchoSilenceInfo.BOSS, "roar is tied to the real boss cast")
	c.eq(events[1].source_uid, 1102, "boss cast origin is not guessed from the nearest actor")
	c.near(events[1].duration, Sim.BOSS_SILENCE_TIME, 0.001, "boss duration remains authoritative")
