extends RefCounted

class WorkSim extends Sim:
	var work_calls: Array[Dictionary] = []
	var target_available := true

	func replay_signature_status(actor: EchoActor, _action: Dictionary) -> Dictionary:
		return {"target_pos": actor.pos + Vector2.RIGHT * 20.0,
			"reason": &"ready" if target_available else &"no_target"}

	func replay_signature(_actor: EchoActor, action: Dictionary) -> bool:
		work_calls.append(action.duplicate(true))
		return target_available


func _action(time: float, kind: StringName = &"signature", target: StringName = &"") -> Dictionary:
	return {"time": time, "kind": kind, "target_id": target,
		"pos": Sim.ARENA.get_center(), "weapon_id": &"pistol" if kind == &"signature" else &"",
		"aim": Vector2.RIGHT if kind == &"signature" else Vector2.ZERO}


func _take(duration: float = 9.0) -> EchoTake:
	var take := EchoTake.new()
	for _index in int(round(duration / EchoTake.SAMPLE_DT)) + 1:
		take.samples.append(Sim.ARENA.get_center())
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.work_actions.append(_action(0.0))
	take.work_actions.append(_action(8.0))
	return take


func _advance(sim: Sim, actor: EchoActor, delta: float) -> void:
	var previous := actor.t
	actor.step(delta)
	EchoWork.step(sim, actor, previous, delta)


func _events(sim: Sim) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	sim.echo_work_performed.connect(func(info: Dictionary) -> void: events.append(info.duplicate(true)))
	return events


func test_recorder_records_actual_elapsed_and_bounds_signature_cadence(c: Check) -> void:
	var recorder := EchoRecorder.new()
	var pos := Sim.ARENA.get_center()
	recorder.begin(pos)
	recorder.record(pos, 0.016)
	c.ok(recorder.record_work(&"signature", &"", pos, &"pistol", Vector2.RIGHT), "first successful shot can become key work")
	c.eq(recorder.work_actions[0].time, 0.016, "event keeps sub-sample elapsed time")
	c.ok(not recorder.record_work(&"signature", &"", pos, &"pistol", Vector2.RIGHT), "same-tick signatures are throttled")
	recorder.record(pos, 7.999)
	c.ok(not recorder.record_work(&"signature", &"", pos, &"pistol", Vector2.RIGHT), "signature below eight-second spacing rejected")
	recorder.record(pos, 0.0011)
	c.ok(recorder.record_work(&"signature", &"", pos, &"pistol", Vector2.RIGHT), "second signature after eight seconds accepted")
	recorder.record(pos, 8.0)
	c.ok(not recorder.record_work(&"signature", &"", pos, &"pistol", Vector2.RIGHT), "third signature cannot enter recording")
	for _index in 4:
		c.ok(recorder.record_work(&"press", &"machine_0", pos), "successful device work fills bounded recording")
	c.ok(not recorder.record_work(&"conveyor", &"machine_1", pos), "seventh action rejected")
	c.eq(recorder.work_actions.size(), EchoWork.MAX_ACTIONS, "six key actions maximum")
	recorder.begin(pos)
	c.eq(recorder.work_actions.size(), 0, "new recording clears previous work")
	c.eq(recorder.get("_elapsed"), 0.0, "new recording resets own clock")


func test_final_sub_sample_work_survives_finish_copy_and_merge(c: Check) -> void:
	var recorder := EchoRecorder.new()
	var pos := Sim.ARENA.get_center()
	recorder.begin(pos)
	recorder.record(pos, 0.016)
	recorder.record_work(&"signature", &"", pos, &"pistol", Vector2.RIGHT)
	var host := recorder.finish(1, [Content.weapon(&"pistol")], Stats.new(), [0])
	c.ok(host.duration() >= 0.016, "terminal work has a playable route endpoint")
	c.ok(EchoWork.validate_actions(host.work_actions, host.duration()), "finished action fits route duration")
	var copied := host.copy()
	c.eq(copied.work_actions, host.work_actions, "copy retains host work")
	copied.work_actions[0].aim = Vector2.LEFT
	c.eq(host.work_actions[0].aim, Vector2.RIGHT, "copy has detached action rows")
	var donor := _take()
	var bank := EchoBank.new()
	bank.add(host)
	bank.add(donor)
	var next_uid := bank.next_uid()
	var preview := bank.preview_merge(host, donor)
	c.eq(preview.work_actions, host.work_actions, "merge preview retains host key work")
	preview.work_actions[0].time = 0.0
	c.eq(host.work_actions[0].time, 0.016, "preview cannot mutate live host event")
	c.eq(bank.next_uid(), next_uid, "preview allocates no stable owner identity")
	var merged := bank.merge(host, donor)
	c.eq(merged.work_actions, host.work_actions, "committed merge preserves only host events")
	c.eq(merged.work_actions.size(), 1, "donor cannot duplicate extra signatures")
	var sim := WorkSim.new()
	var actor := EchoActor.new(merged, 0)
	_advance(sim, actor, 0.016)
	c.eq(sim.work_calls.size(), 1, "16ms terminal event executes at its exact boundary")
	_advance(sim, actor, 0.001)
	c.eq(sim.work_calls.size(), 1, "same event cannot repeat on next frame")


func test_forward_only_playback_endpoint_and_cycle_wrap(c: Check) -> void:
	var sim := WorkSim.new()
	var take := _take()
	take.work_actions[1].time = take.duration()
	take.uid = 42
	var actor := EchoActor.new(take, 3)
	var events := _events(sim)
	_advance(sim, actor, 0.016)
	c.eq(sim.work_calls.size(), 1, "zero-time work starts on first forward step")
	c.eq(events[0].uid, 42, "presentation event carries stable take UID, not slot")
	c.eq(actor.work_cursor, 1, "first event consumed")
	_advance(sim, actor, take.duration() - actor.t)
	c.eq(sim.work_calls.size(), 2, "turnaround endpoint fires once while moving forward")
	_advance(sim, actor, take.duration() - 0.001)
	c.eq(sim.work_calls.size(), 2, "backward route does not replay critical output")
	_advance(sim, actor, 0.001)
	c.eq(sim.work_calls.size(), 3, "exact cycle wrap performs next zero-time event once")
	c.eq(actor.work_cycle, 1, "cycle increments at wrap")
	c.eq(actor.work_cursor, 1, "new-cycle zero-time event already consumed")
	_advance(sim, actor, 0.016)
	c.eq(sim.work_calls.size(), 3, "wrapped event cannot duplicate next frame")
	c.ok(EchoWork.validate_actor(actor), "cursor and route clock remain coherent")


func test_muted_sealed_and_unavailable_work_is_consumed_without_backlog(c: Check) -> void:
	for reason in [&"muted", &"sealed", &"no_target"]:
		var sim := WorkSim.new()
		var take := _take()
		var actor := EchoActor.new(take, 0)
		var events := _events(sim)
		if reason == &"muted":
			sim.echo_silenced = 3.0
		elif reason == &"sealed":
			var zone := EnemyZone.new()
			zone.pos = actor.pos
			zone.warning = 0.0
			zone.active = 3.0
			sim.enemy_zones.append(zone)
		else:
			sim.target_available = false
		_advance(sim, actor, 0.016)
		c.eq(sim.work_calls.size(), 0, "%s cannot produce output" % reason)
		c.eq(events[0].reason, reason, "visible failure cause %s" % reason)
		c.eq(actor.work_cursor, 1, "failed event is consumed")
		c.eq(take.condition, 100.0, "unsuccessful work spends no condition")
		sim.echo_silenced = 0.0
		sim.enemy_zones.clear()
		sim.target_available = true
		_advance(sim, actor, 0.016)
		c.eq(sim.work_calls.size(), 0, "unblocked actor never flushes queued work")
		_advance(sim, actor, 8.0)
		c.eq(sim.work_calls.size(), 1, "later scheduled work can execute normally")


func test_big_delta_has_six_attempt_budget_and_no_later_burst(c: Check) -> void:
	var sim := WorkSim.new()
	var actor := EchoActor.new(_take(), 0)
	var events := _events(sim)
	_advance(sim, actor, 1800000.5)
	c.eq(sim.work_calls.size(), 6, "hundred-thousand crossed cycles have six-event execution cap")
	c.eq(events.size(), 6, "presentation is also bounded to six events")
	c.eq(actor.take.condition, 76.0, "only six successes charge four condition each")
	c.eq(actor.work_cycle, 100000, "clock skips directly to final cycle")
	c.eq(actor.work_cursor, 1, "already-passed current-cycle action is consumed despite tick cap")
	_advance(sim, actor, 0.016)
	c.eq(sim.work_calls.size(), 6, "next frame cannot replay budget overflow")
	c.ok(EchoWork.validate_actor(actor), "large-delta cursor state validates")


func test_condition_exhaustion_prevents_extra_output_in_same_tick(c: Check) -> void:
	var sim := WorkSim.new()
	var take := _take()
	take.condition = 4.0
	var actor := EchoActor.new(take, 0)
	var events := _events(sim)
	_advance(sim, actor, 90.0)
	c.eq(sim.work_calls.size(), 1, "last four condition buy exactly one successful work")
	c.eq(take.condition, 0.0, "successful work consumes last condition")
	c.eq(events.size(), 6, "remaining due events still consume bounded slots")
	c.eq(events[1].reason, &"condition", "next due event reports exhaustion")
	_advance(sim, actor, 8.0)
	c.eq(sim.work_calls.size(), 1, "exhausted actor cannot produce later output")


func test_anchor_holds_key_work_clock_and_resume_keeps_first_action(c: Check) -> void:
	var sim := WorkSim.new()
	sim.phase = Sim.Phase.WAVE
	sim.wear_rate_mult = 0.0
	var take := _take()
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	sim.role_effects["anchor_uid"] = take.uid
	sim.role_effects["anchor_left"] = 2.0
	EchoSystem.step(sim, 1.0)
	c.eq(actor.t, 0.0, "anchored route clock stays at its actual position")
	c.eq(actor.work_cursor, 0, "holding route does not discard first due work")
	c.eq(sim.work_calls.size(), 0, "anchor cannot repeatedly fire zero-time action")
	sim.role_effects["anchor_left"] = 0.0
	EchoSystem.step(sim, 0.016)
	c.eq(sim.work_calls.size(), 1, "released anchor performs first key action once")
	EchoSystem.step(sim, 0.016)
	c.eq(sim.work_calls.size(), 1, "next frame cannot repeat anchor-release work")
	c.ok(EchoWork.validate_actor(actor), "anchor-release cursor remains serializable")


func test_degenerate_route_executes_zero_time_work_only_once(c: Check) -> void:
	var sim := WorkSim.new()
	var take := _take()
	take.samples = PackedVector2Array([Sim.ARENA.get_center()])
	take.work_actions = [_action(0.0)]
	var actor := EchoActor.new(take, 0)
	_advance(sim, actor, 0.016)
	_advance(sim, actor, 100000.0)
	c.eq(sim.work_calls.size(), 1, "stationary zero-duration route cannot loop free work")
	c.eq(actor.work_cycle, 0, "degenerate route has no fictitious cycle")
	c.ok(EchoWork.validate_actor(actor), "degenerate consumed cursor validates")


func test_looper_rewind_preserves_consumed_work_across_short_route_cycles(c: Check) -> void:
	var sim := WorkSim.new()
	sim.phase = Sim.Phase.WAVE
	var take := _take(0.1)
	take.work_actions = [_action(0.0)]
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	_advance(sim, actor, 0.316)
	c.eq(sim.work_calls.size(), 2, "two original forward cycles perform work")
	c.eq(actor.work_cycle, 1, "work high-water mark enters second short cycle")
	sim.character_energy = CharacterSkills.ENERGY_COST
	c.ok(CharacterSkills.activate(sim), "real Looper ability rewinds the Echo route")
	c.eq(actor.t, 0.0, "short Echo route rewinds to its start")
	c.eq(actor.work_cycle, 1, "rewinding route cannot reset consumed work cycle")
	c.ok(EchoWork.validate_actor(actor), "rewound high-water mark validates immediately")
	_advance(sim, actor, 0.016)
	c.eq(sim.work_calls.size(), 2, "zero-time historical work cannot repeat after rewind")
	_advance(sim, actor, 0.2)
	c.eq(sim.work_calls.size(), 2, "catching up through consumed cycle produces no duplicate")
	_advance(sim, actor, 0.2)
	c.eq(sim.work_calls.size(), 3, "next new forward cycle can perform its scheduled work")
	c.ok(EchoWork.validate_actor(actor), "normal work resumes after high-water catch-up")


func test_action_validation_is_closed_finite_sorted_and_bounded(c: Check) -> void:
	var actions: Array[Dictionary] = [_action(0.0), _action(8.0)]
	c.ok(EchoWork.validate_actions(actions, 9.0), "canonical authored actions accepted")
	for field in ["time", "pos", "aim"]:
		var bad: Array[Dictionary] = []
		bad.assign(actions.duplicate(true))
		bad[0][field] = NAN if field == "time" else Vector2(NAN, 0.0)
		c.ok(not EchoWork.validate_actions(bad, 9.0), "nonfinite %s rejected" % field)
	var bad: Array[Dictionary] = []
	bad.assign(actions.duplicate(true))
	bad[0]["future_option"] = true
	c.ok(not EchoWork.validate_actions(bad, 9.0), "unknown row fields rejected")
	bad.assign(actions.duplicate(true))
	bad[1].time = 7.99
	c.ok(not EchoWork.validate_actions(bad, 9.0), "signature spacing cannot bypass recorder on load")
	bad.assign(actions.duplicate(true))
	bad.reverse()
	c.ok(not EchoWork.validate_actions(bad, 9.0), "unsorted times rejected")
	bad = [_action(0.0, &"press", &"machine_0")]
	c.ok(EchoWork.validate_actions(bad, 9.0), "known free machine work accepted")
	bad[0].target_id = &"machine_1"
	c.ok(not EchoWork.validate_actions(bad, 9.0), "machine identity must match operation")
	bad = [_action(0.0, &"recycler", &"machine_2")]
	c.ok(not EchoWork.validate_actions(bad, 9.0), "money-spending recycler input cannot be replayed")
	bad.clear()
	for index in 7:
		bad.append(_action(float(index), &"press", &"machine_0"))
	c.ok(not EchoWork.validate_actions(bad, 9.0), "oversized action list rejected")
	c.ok(not EchoWork.validate_cursor(actions, 9.0, 8.0, 0, 0), "lost cursor behind due actions rejected")
	c.ok(not EchoWork.validate_cursor(actions, 9.0, 1.0, 2, 0), "cursor cannot silently discard future event")
	c.ok(not EchoWork.validate_cursor(actions, 9.0, 19.0, 1, 0), "wrong ping-pong cycle rejected")
	c.ok(not EchoWork.validate_cursor(actions, 9.0, 1.0, 0, 1), "rewind cannot invent an arbitrarily future cycle")
	c.ok(EchoWork.validate_cursor(actions, 9.0, 6.01, 2, 0), "consumed event within actual rewind remains valid")


func test_authoritative_player_work_and_signature_use_old_build_without_recursive_recording(c: Check) -> void:
	var sim := Sim.new(124)
	sim.start_run()
	sim.enemies.clear()
	var site: Dictionary = {}
	for item in sim.interactables:
		if item.id == &"machine_1":
			site = item
			break
	c.ok(not site.is_empty(), "actual conveyor interaction exists")
	if site.is_empty():
		return
	sim.player.pos = site.pos
	site.cooldown = 0.0
	sim.recorder.record(sim.player.pos, 0.016)
	c.ok(sim.interact(), "actual player machine operation succeeds")
	c.eq(sim.recorder.work_actions.size(), 1, "successful input records one machine operation")
	c.eq(sim.recorder.work_actions[0].target_id, &"machine_1", "event names existing machine")
	c.ok(not sim.interact(), "cooling-down machine rejects second input")
	c.eq(sim.recorder.work_actions.size(), 1, "unsuccessful input cannot enter take")
	var take := sim.recorder.finish(1, [Content.weapon(&"pistol")], sim.player.stats, [0])
	take.work_actions = [_action(0.016)]
	take.work_actions[0].pos = sim.player.pos
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	var enemy := EnemyState.new()
	enemy.uid = 123
	enemy.def = Content.enemies()[0]
	enemy.pos = actor.pos + Vector2(90.0, 0.0)
	enemy.radius = enemy.def.radius
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	sim.enemies.append(enemy)
	sim.player.weapons[0] = Content.weapon(&"smg")
	sim.live_echo = true
	var before_actions := sim.recorder.work_actions.duplicate(true)
	var before_funds := sim.player.materials
	_advance(sim, actor, 0.016)
	c.ok(not sim.projectiles.is_empty(), "signature fires at a current valid target")
	if not sim.projectiles.is_empty():
		c.eq(sim.projectiles.back().weapon_id, &"pistol", "signature retains old weapon even for live-loadout character")
		c.eq(sim.projectiles.back().actor_token, take.uid, "signature damage owns positive stable Echo UID")
	c.eq(sim.recorder.work_actions, before_actions, "replayed signature cannot recursively record player work")
	c.eq(sim.player.materials, before_funds, "key work creates no extra cash cost")


func test_existing_machine_replay_is_free_and_failed_work_spends_nothing(c: Check) -> void:
	var sim := Sim.new(191)
	sim.start_run()
	var site: Dictionary = {}
	var machine: Dictionary = {}
	for item in sim.interactables:
		if item.id == &"machine_1":
			site = item
	for item in sim.expedition.world.machines:
		if item.id == &"machine_1":
			machine = item
	c.ok(not site.is_empty() and not machine.is_empty(), "replay shares actual existing world machine")
	if site.is_empty() or machine.is_empty():
		return
	site.cooldown = 0.0
	machine.status = &"operating"
	machine.stopped = false
	var take := _take()
	for index in take.samples.size():
		take.samples[index] = site.pos
	take.work_actions = [_action(0.0, &"conveyor", &"machine_1")]
	take.work_actions[0].pos = site.pos
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	var events := _events(sim)
	var before_direction: Vector2 = site.direction
	var before_money := sim.player.materials
	var before_recorded := sim.recorder.work_actions.duplicate(true)
	_advance(sim, actor, 0.016)
	c.eq(site.direction, -before_direction, "key work performs real conveyor operation")
	c.ok(events[0].success, "real operation reports success")
	c.eq(events[0].target_pos, site.pos, "event points to current real machine")
	c.eq(take.condition, 96.0, "success costs four condition")
	c.eq(sim.player.materials, before_money, "machine replay spends no funds")
	c.eq(sim.recorder.work_actions, before_recorded, "machine replay cannot recursively record player work")
	for reason in [&"repaired", &"stopped", &"distant"]:
		site.cooldown = 0.0
		machine.status = &"repaired" if reason == &"repaired" else &"operating"
		machine.stopped = reason == &"stopped"
		var next_actor := EchoActor.new(take, 0)
		if reason == &"distant":
			for index in take.samples.size():
				take.samples[index] = Sim.ARENA.get_center()
		var condition_before := take.condition
		_advance(sim, next_actor, 0.016)
		c.eq(events.back().reason, reason, "unavailable operation shows %s" % reason)
		c.ok(not events.back().success, "unavailable operation does not execute")
		c.eq(take.condition, condition_before, "failed operation spends no condition")
		c.eq(sim.player.materials, before_money, "failed operation spends no funds")


func test_only_successful_player_shot_enters_recorder(c: Check) -> void:
	var sim := Sim.new(141)
	sim.start_run()
	var enemy := EnemyState.new()
	enemy.uid = 991
	enemy.def = Content.enemies()[0]
	enemy.pos = sim.player.pos + Vector2(90.0, 0.0)
	enemy.radius = enemy.def.radius
	enemy.hp = 100.0
	sim.enemies = [enemy]
	sim.recorder.record(sim.player.pos, 0.016)
	sim.projectiles.resize(Combat.MAX_PROJECTILES)
	Combat.step_weapons(sim, sim.player.pos, sim.player.stats, sim.player.weapons,
		sim.player.weapon_levels, sim.player.cooldowns, 1.0, 0.016, -1, Color.WHITE)
	c.eq(sim.recorder.work_actions.size(), 0, "failed output at projectile cap records no signature")
	sim.projectiles.clear()
	sim.player.cooldowns[0] = 0.0
	Combat.step_weapons(sim, sim.player.pos, sim.player.stats, sim.player.weapons,
		sim.player.weapon_levels, sim.player.cooldowns, 1.0, 0.016, -1, Color.WHITE)
	c.eq(sim.recorder.work_actions.size(), 1, "successful authoritative player shot records signature")
	c.eq(sim.recorder.work_actions[0].time, 0.016, "recorded shot uses recorder clock")
	c.eq(sim.recorder.work_actions[0].weapon_id, &"pistol", "recorded shot carries actual weapon identity")
	var echo_info := ShotInfo.new()
	echo_info.source = 0
	echo_info.actor_token = 99
	echo_info.weapon_id = &"pistol"
	echo_info.origin = sim.player.pos
	sim.recorder.record(sim.player.pos, 8.0)
	sim.shot_fired_info.emit(echo_info)
	c.eq(sim.recorder.work_actions.size(), 1, "Echo ShotInfo cannot recursively add player signature")


func test_signature_aim_intent_selects_current_live_target(c: Check) -> void:
	var sim := Sim.new(142)
	sim.start_run()
	var take := _take()
	var actor := EchoActor.new(take, 0)
	var left := EnemyState.new()
	left.uid = 992
	left.def = Content.enemies()[0]
	left.pos = actor.pos + Vector2.LEFT * 10.0
	left.radius = left.def.radius
	left.hp = 100.0
	var right := EnemyState.new()
	right.uid = 993
	right.def = left.def
	right.pos = actor.pos + Vector2.RIGHT * 60.0
	right.radius = right.def.radius
	right.hp = 100.0
	sim.enemies = [left, right]
	c.eq(sim.signature_target(actor, take.work_actions[0]), right, "old rightward intent prefers current rightward target")
	right.dead = true
	c.eq(sim.signature_target(actor, take.work_actions[0]), left, "historical intent still adapts to live available target")
	left.dead = true
	c.eq(sim.replay_signature_status(actor, take.work_actions[0]).reason, &"no_target", "no valid current target has visible reason")


func test_utility_signature_needs_no_enemy_and_uses_normal_owned_output_events(c: Check) -> void:
	var sim := Sim.new(143)
	sim.start_run()
	sim.enemies.clear()
	var take := _take()
	take.weapons = [Content.weapon(&"repair_kit")]
	take.levels = [0]
	for action in take.work_actions:
		action.weapon_id = &"repair_kit"
		action.aim = Vector2.LEFT
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	var shots: Array[ShotInfo] = []
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: shots.append(info))
	var events := _events(sim)
	var before_recording := sim.recorder.work_actions.duplicate(true)
	c.eq(sim.replay_signature_status(actor, take.work_actions[0]).reason, &"ready", "utility work remains available without live enemies")
	_advance(sim, actor, 0.016)
	c.eq(sim.support_units.size(), 1, "targetless work deploys actual repair station")
	if not sim.support_units.is_empty():
		var unit: Dictionary = sim.support_units[0]
		c.eq(unit.kind, &"repair_station", "historical utility identity is retained")
		c.eq(unit.actor_token, take.uid, "utility belongs to the stable Echo owner")
		c.eq(unit.level, 0, "utility uses actual recorded grade")
		c.ok((unit.pos as Vector2).x < actor.pos.x, "targetless placement respects old leftward aim")
	c.eq(take.condition, 96.0, "successful targetless operation pays key-work wear")
	c.eq(shots.size(), 1, "successful signature emits exactly one normal rich attack event")
	if not shots.is_empty():
		c.eq(shots[0].actor_token, take.uid, "attack pose and sound use stable Echo UID")
		c.eq(shots[0].weapon_id, &"repair_kit", "rich event keeps historical weapon identity")
	c.eq(sim.recorder.work_actions, before_recording, "utility output cannot recursively record itself")
	_advance(sim, actor, 8.0)
	c.eq(sim.support_units.size(), 1, "living station cannot be refreshed by next key event")
	c.eq(shots.size(), 1, "failed duplicate deployment has no false attack event")
	c.eq(events.back().reason, &"unavailable", "duplicate deployment exposes a failed operation")
	c.eq(take.condition, 96.0, "failed duplicate station spends no key-work wear")
	c.eq(actor.work_cursor, 2, "failed second deployment is consumed without a backlog")


func test_exact_snapshot_resume_has_no_duplicate_or_lost_work(c: Check) -> void:
	var sim := Sim.new(1616)
	var take := _take()
	sim.bank.add(take)
	sim.start_run()
	sim.wear_rate_mult = 0.0
	var actor: EchoActor = sim.echoes[0]
	var events := _events(sim)
	_advance(sim, actor, 0.016)
	c.eq(events.size(), 1, "first due event consumed before save")
	var captured := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(JSON.parse_string(JSON.stringify(captured, "", true, true)))
	c.ok(restored != null, "work snapshot resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), captured, "work rows clocks and cursors restore exactly")
	var resumed_events := _events(restored)
	_advance(sim, actor, 0.016)
	_advance(restored, restored.echoes[0], 0.016)
	c.eq(resumed_events.size(), 0, "resume after event boundary cannot duplicate first work")
	_advance(sim, actor, 8.0)
	_advance(restored, restored.echoes[0], 8.0)
	c.eq(resumed_events.size(), 1, "resume preserves next scheduled event")
	c.eq(resumed_events[0], events.back(), "resumed event has identical target and cause")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "continued work snapshots remain bit-exact")


func test_snapshot_immediately_after_looper_rewind_keeps_high_water_work(c: Check) -> void:
	var sim := Sim.new(1717)
	var take := _take()
	sim.bank.add(take)
	sim.start_run()
	sim.wear_rate_mult = 0.0
	var actor: EchoActor = sim.echoes[0]
	var events := _events(sim)
	_advance(sim, actor, 8.016)
	c.eq(events.size(), 2, "both key actions consumed before ability")
	sim.character_energy = CharacterSkills.ENERGY_COST
	c.ok(CharacterSkills.activate(sim), "actual Looper rewind is available")
	c.ok(EchoWork.validate_actor(actor), "post-ability actor has a valid high-water cursor")
	var captured := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(JSON.parse_string(JSON.stringify(captured, "", true, true)))
	c.ok(restored != null, "post-rewind snapshot resumes: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), captured, "route rewind and consumed event marker restore exactly")
	var resumed_events := _events(restored)
	_advance(sim, actor, 2.0)
	_advance(restored, restored.echoes[0], 2.0)
	c.eq(events.size(), 2, "catch-up through already performed work does not replay it")
	c.eq(resumed_events.size(), 0, "restored route also skips already performed work")
	_advance(sim, actor, 10.0)
	_advance(restored, restored.echoes[0], 10.0)
	c.eq(resumed_events.size(), 1, "next forward cycle has one fresh scheduled event")
	c.eq(resumed_events[0], events.back(), "resumed fresh-cycle event is identical")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "post-rewind continuation remains bit-exact")
