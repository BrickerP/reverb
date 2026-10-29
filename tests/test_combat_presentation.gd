extends RefCounted


func _view(sim: Sim) -> ArenaView:
	var view := ArenaView.new()
	view.bind(sim, &"looper")
	return view


func _shot(id: StringName = &"pistol") -> ShotInfo:
	var info := ShotInfo.new()
	info.weapon_id = id
	info.origin = Vector2(200.0, 220.0)
	info.direction = Vector2(3.0, 4.0).normalized()
	info.target = Vector2(500.0, 620.0)
	info.count = 1
	info.sequence = 7
	return info


func test_rich_events_replace_legacy_connections_without_double_feedback(c: Check) -> void:
	var sim := Sim.new(11)
	sim.start_run()
	var view := _view(sim)
	sim.enemy_hit.emit(Vector2.ONE, 1.0, false, -1)
	c.eq(view.feedback_counts()["hits"], 0, "legacy hit signal is not connected")
	sim.player_hurt.emit(1.0)
	sim.explosion.emit(Vector2.ONE, 20.0, Color.WHITE)
	sim.shot_fired.emit(-1)
	c.eq(view.feedback_counts()["hurts"], 0, "legacy hurt signal is not connected")
	c.eq(view.feedback_counts()["explosions"], 0, "legacy explosion signal is not connected")
	c.eq(view.feedback_counts()["muzzles"], 0, "legacy shot signal is not connected")
	var info := DamageInfo.new()
	info.pos = Vector2(300.0, 300.0)
	info.hit_dir = Vector2.RIGHT
	sim.damage_event.emit(info)
	c.eq(view.feedback_counts()["hits"], 1, "rich damage signal creates one hit cue")
	view._on_hit(Vector2(310.0, 300.0), 2.0, true, -1)
	c.eq(view.feedback_counts()["hits"], 2, "legacy private wrapper remains callable")
	view.free()


func test_rebind_disconnects_old_sim_and_is_idempotent(c: Check) -> void:
	var first := Sim.new(1)
	var second := Sim.new(2)
	first.start_run()
	second.start_run()
	var view := _view(first)
	view.bind(second, &"mirror")
	view.bind(second, &"mirror")
	first.shot_fired_info.emit(_shot())
	c.eq(view.feedback_counts()["muzzles"], 0, "old sim no longer reaches view")
	var shot := _shot()
	second.shot_fired_info.emit(shot)
	c.eq(view.feedback_counts()["muzzles"], 1, "same-sim rebind does not duplicate callbacks")
	c.eq(view._muzzles[0]["pos"], shot.origin + shot.direction * 14.0,
			"muzzle cue starts at the real projectile spawn")
	c.eq(view._muzzles[0]["sequence"], shot.sequence,
			"visual feedback retains authoritative volley order")
	var recoil_before := view.recoil_amount(-1, &"pistol")
	c.ok(recoil_before > 0.0, "authoritative source and weapon ID drive mounted recoil")
	view._process(0.05)
	var recoil_after := view.recoil_amount(-1, &"pistol")
	c.ok(recoil_after > 0.0 and recoil_after < recoil_before, "mounted recoil decays independently")
	c.eq(view.character_id, &"mirror", "rebind retains selected presentation identity")
	view.free()


func test_all_weapon_feedback_profiles_are_explicit(c: Check) -> void:
	var styles := {&"sidearm": &"sidearm", &"scatter": &"scatter",
			&"marksman": &"marksman", &"arcane": &"arcane",
			&"press": &"press", &"salvage": &"salvage"}
	for weapon: WeaponDef in Content.weapons().values():
		var profile := ArenaPainter.weapon_feedback_profile(weapon.id)
		c.eq(profile["weapon_id"], weapon.id, "%s feedback retains weapon ID" % weapon.id)
		c.eq(profile["style"], styles[weapon.family], "%s uses family-readable feedback" % weapon.id)
		c.ok(float(profile["length"]) > 0.0 and float(profile["recoil"]) > 0.0,
				"%s has bounded muzzle and recoil" % weapon.id)
	var longbow := ArenaPainter.weapon_feedback_profile(&"longbow")
	var smg := ArenaPainter.weapon_feedback_profile(&"smg")
	c.ok(float(longbow["length"]) > float(smg["length"]), "marksman reads longer than SMG")
	c.ok(bool(ArenaPainter.weapon_feedback_profile(&"nova_core")["evolved"]),
			"evolved weapon gets an evolved cue")


func test_direction_reduction_explosion_cause_and_lethal_hurt_are_preserved(c: Check) -> void:
	var sim := Sim.new(4)
	sim.start_run()
	var view := _view(sim)
	var damage := DamageInfo.new()
	damage.weapon_id = &"rail_spike"
	damage.pos = Vector2(400.0, 300.0)
	damage.hit_dir = Vector2.LEFT
	damage.crit = true
	damage.reduced = true
	sim.damage_event.emit(damage)
	var last := view.event_last_data()
	c.eq(last["direction"], Vector2.LEFT, "hit direction remains authoritative")
	c.ok(bool(last["crit"]) and bool(last["reduced"]), "crit and shield reduction remain distinct")
	var blast := ExplosionInfo.new()
	blast.kind = ExplosionInfo.WEAPON
	blast.weapon_id = &"flak_crown"
	blast.pos = Vector2(410.0, 310.0)
	blast.radius = 48.0
	sim.explosion_info.emit(blast)
	c.eq(view.event_last_data()["cause"], ExplosionInfo.WEAPON, "weapon explosion cause remains explicit")
	blast = ExplosionInfo.new()
	blast.kind = ExplosionInfo.BOMBER
	blast.pos = Vector2(420.0, 320.0)
	blast.radius = 52.0
	blast.color = Color.ORANGE
	sim.explosion_info.emit(blast)
	c.eq(view.event_last_data()["cause"], ExplosionInfo.BOMBER, "bomber cause remains explicit")
	var hurt := PlayerHurtInfo.new()
	hurt.pos = sim.player.pos
	hurt.direction = Vector2.UP
	hurt.source = &"bomber"
	hurt.lethal = true
	sim.player_hurt_info.emit(hurt)
	last = view.event_last_data()
	c.eq(last["direction"], Vector2.UP, "player hurt keeps source direction")
	c.ok(last["lethal"], "lethal hurt remains explicit")
	view.free()


func test_directionless_aoe_and_overlap_do_not_invent_vectors(c: Check) -> void:
	var sim := Sim.new(41)
	sim.start_run()
	var view := _view(sim)
	var damage := DamageInfo.new()
	damage.weapon_id = &"nova_core"
	damage.pos = Vector2(500.0, 320.0)
	damage.hit_dir = Vector2.ZERO
	damage.effect = &"weapon_explosion"
	sim.damage_event.emit(damage)
	var last := view.event_last_data()
	c.eq(last["direction"], Vector2.ZERO, "directionless AOE remains directionless")
	c.ok(not bool(last["has_direction"]), "AOE exposes symmetric impact contract")
	var hurt := PlayerHurtInfo.new()
	hurt.pos = sim.player.pos
	hurt.direction = Vector2.ZERO
	hurt.effect = &"overlap"
	sim.player_hurt_info.emit(hurt)
	last = view.event_last_data()
	c.eq(last["direction"], Vector2.ZERO, "overlap hurt remains directionless")
	c.ok(not bool(last["has_direction"]), "overlap hurt exposes symmetric cue contract")
	var directional := DamageInfo.new()
	directional.pos = Vector2(520.0, 320.0)
	directional.hit_dir = Vector2(4.0, -3.0)
	sim.damage_event.emit(directional)
	last = view.event_last_data()
	c.eq(last["direction"], Vector2(0.8, -0.6), "normal hit direction is normalized and preserved")
	c.ok(bool(last["has_direction"]), "normal hit remains directional")
	view.free()


func test_feedback_queues_are_capped_expire_and_clear_on_phase(c: Check) -> void:
	var sim := Sim.new(5)
	sim.start_run()
	var view := _view(sim)
	for i in ArenaView.MAX_MUZZLES + 9:
		var info := _shot(&"smg")
		info.sequence = i
		sim.shot_fired_info.emit(info)
	c.eq(view.feedback_counts()["muzzles"], ArenaView.MAX_MUZZLES, "muzzle queue is capped")
	for i in ArenaView.MAX_HITS + 3:
		var damage := DamageInfo.new()
		damage.pos = Vector2(300.0 + i, 300.0)
		sim.damage_event.emit(damage)
	c.eq(view.feedback_counts()["hits"], ArenaView.MAX_HITS, "hit queue is capped")
	for i in ArenaView.MAX_EXPLOSIONS + 3:
		var blast := ExplosionInfo.new()
		blast.pos = Vector2(400.0, 300.0)
		blast.radius = 20.0
		sim.explosion_info.emit(blast)
	c.eq(view.feedback_counts()["explosions"], ArenaView.MAX_EXPLOSIONS, "explosion queue is capped")
	for i in ArenaView.MAX_HURTS + 3:
		var hurt := PlayerHurtInfo.new()
		hurt.pos = sim.player.pos
		sim.player_hurt_info.emit(hurt)
	c.eq(view.feedback_counts()["hurts"], ArenaView.MAX_HURTS, "hurt queue is capped")
	view._process(0.5)
	c.eq(view.feedback_counts()["muzzles"], 0, "muzzle cues expire")
	c.eq(view.feedback_counts()["hits"], 0, "hit cues expire")
	c.eq(view.feedback_counts()["explosions"], 0, "explosion cues expire")
	c.eq(view.feedback_counts()["hurts"], 0, "hurt cues expire")
	sim.shot_fired_info.emit(_shot())
	sim.wave_ended.emit(sim.wave)
	c.eq(view.feedback_counts()["muzzles"], 0, "phase boundary clears transients")
	view.free()


func test_wave_start_prunes_old_echo_paths_but_preserves_current_reveal(c: Check) -> void:
	var sim := Sim.new(7)
	var view := _view(sim)
	var old_take := EchoTake.new()
	old_take.samples = PackedVector2Array([Vector2.ZERO, Vector2.ONE])
	var old_actor := EchoActor.new(old_take, 0)
	var current_take := EchoTake.new()
	current_take.samples = PackedVector2Array([Vector2(10.0, 10.0), Vector2(20.0, 20.0)])
	var current_actor := EchoActor.new(current_take, 0)
	sim.echoes.clear()
	sim.echoes.append(current_actor)
	view._paths[old_actor] = old_take.samples
	view._reveal[old_actor] = 0.5
	view._paths[current_actor] = current_take.samples
	view._reveal[current_actor] = -0.12
	view._on_wave_started(2)
	c.ok(not view._paths.has(old_actor) and not view._reveal.has(old_actor),
			"previous-wave actor presentation is pruned")
	c.ok(view._paths.has(current_actor), "current actor path survives wave-start cleanup")
	c.near(float(view._reveal[current_actor]), -0.12, 0.001,
			"current reveal staggering survives wave-start cleanup")
	view.free()


func test_pause_reduced_effects_motion_and_state_are_independent(c: Check) -> void:
	var sim := Sim.new(19)
	sim.start_run()
	var view := _view(sim)
	var rng_state := sim.rng.state
	var wave_time := sim.wave_time
	var hp := sim.player.hp
	var cooldowns := sim.player.cooldowns.duplicate()
	view.reduced_effects = true
	view.set_paused(true)
	sim.shot_fired_info.emit(_shot(&"flak_crown"))
	c.near(view.recoil_amount(-1, &"flak_crown"),
			float(ArenaPainter.weapon_feedback_profile(&"flak_crown")["recoil"]) * 0.5, 0.001,
			"reduced effects halves mounted recoil")
	view._process(1.0)
	c.eq(view.feedback_counts()["muzzles"], 1, "paused visual cue does not age")
	c.ok(bool(view.motion_stats()["paused"]) and bool(view.motion_stats()["reduced"]),
			"probe exposes pause and reduced states")
	view.set_paused(false)
	view._process(0.05)
	c.ok(not view.motion_stats()["moving"], "persistent facing alone does not create movement")
	sim.player.pos += Vector2(12.0, 0.0)
	sim.wave_time += 0.05
	view._process(0.05)
	c.ok(view.motion_stats()["moving"], "actual position delta starts gait")
	for _i in 20:
		sim.wave_time += 0.05
		view._process(0.05)
	c.ok(not view.motion_stats()["moving"], "gait settles after position stops")
	c.eq(sim.rng.state, rng_state, "presentation never advances simulation RNG")
	c.near(sim.wave_time, wave_time + 1.05, 0.0001, "only the explicit simulation ticks advance time")
	c.eq(sim.player.hp, hp, "presentation never changes player health")
	c.eq(sim.player.cooldowns, cooldowns, "presentation never changes weapon cooldowns")
	view.free()
