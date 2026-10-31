extends RefCounted


func _sim(stage: int = 2, role: StringName = &"looper") -> Sim:
	var sim := Sim.new(17017)
	Content.character(role).apply(sim)
	sim.start_run()
	if stage != 1:
		sim.start_wave(stage)
	sim._plan.clear()
	return sim


func _at(sim: Sim, id: StringName) -> bool:
	for item in sim.interactables:
		if item["id"] == id:
			sim.player.pos = item["pos"]
			return sim.interact()
	return false


func _enemy(sim: Sim, at: Vector2) -> EnemyState:
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"grunt")
	spawn.pos = at
	sim._materialize(spawn)
	var enemy: EnemyState = sim.enemies.back()
	enemy.hp = 10000.0
	enemy.max_hp = enemy.hp
	return enemy


func _take(sim: Sim, condition: float = 100.0) -> EchoTake:
	var take := EchoTake.new()
	take.wave = sim.wave
	take.samples = PackedVector2Array([BureauEvents.SWITCH, BureauEvents.SWITCH])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	take.condition = condition
	sim.bank.add(take)
	return take


func _recruit_for_history(sim: Sim, kind: StringName, choice: StringName, c: Check) -> void:
	var order := AnomalyContract.new()
	order.kind = &"recruit"
	order.accepted = true
	sim.active_contract = order
	Expedition.on_order_purchased(sim, order)
	sim.expedition["mission"]["state"] = &"active"
	sim.expedition["mission"]["wave"] = sim.wave
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(kind)
	spawn.pos = WorldArena.move_body(sim.player.pos + Vector2(200.0, 0.0), Vector2.ZERO, 32.0)
	c.ok(sim._materialize(spawn), "real allocator creates the recruitment body")
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)
	c.ok(sim.choose_negotiation(choice), "explicit real boss terms create the signed colleague")


func test_scheduled_optional_delivery_has_body_clear_targets_and_pure_profile(c: Check) -> void:
	for stage in range(1, 13):
		var sim := _sim(stage)
		var expected := stage in [2, 6, 10]
		c.eq(not sim.expedition["bureau"]["delivery"].is_empty(), expected, "one declared event on the second encounter of each act")
		var before := RunSnapshot.capture(sim)
		BureauEvents.profile(sim)
		BureauEvents.forecast(stage)
		c.eq(RunSnapshot.capture(sim), before, "read-only forecast and art cannot alter the world or RNG")
		c.ok(Expedition.validate_state(sim), "current event graph validates at stage%d" % stage)
	for point in [BureauEvents.PICKUP, BureauEvents.SWITCH, BureauEvents.STAMP, BureauEvents.INBOX]:
		c.ok(WorldArena.body_clear(point, PlayerState.RADIUS), "authored route point is actually walkable")
	var endless := _sim(12)
	endless._end_wave()
	endless.choose_exit(&"takeover")
	endless.begin_endless()
	c.ok(endless.expedition["bureau"]["delivery"].is_empty(), "endless does not accumulate delivery apparatus")


func test_actual_pickup_and_delivery_reward_exactly_once_without_requiring_order(c: Check) -> void:
	var sim := _sim()
	var before := sim.player.materials
	c.ok(not _at(sim, BureauEvents.INBOX_ID), "an empty-handed signature cannot claim delivery reward")
	c.ok(_at(sim, BureauEvents.PICKUP_ID), "real E interaction picks up the document")
	c.eq(sim.expedition["bureau"]["delivery"]["state"], &"carrying", "carrying state survives beyond the prompt")
	c.ok(not _at(sim, BureauEvents.PICKUP_ID), "a picked document cannot be copied by repeated input")
	c.ok(_at(sim, BureauEvents.INBOX_ID), "real E interaction submits the document")
	c.eq(sim.player.materials, before + BureauEvents.REWARD, "submission grants exactly the advertised eight materials")
	_at(sim, BureauEvents.INBOX_ID)
	c.eq(sim.player.materials, before + BureauEvents.REWARD, "repeated E cannot pay a second delivery reward")
	c.ok(not _at(sim, BureauEvents.SWITCH_ID), "closed delivery cannot record useful future work")
	sim._end_wave()
	c.eq(sim.expedition["bureau"]["delivery"]["state"], &"delivered", "shop keeps the real result")
	var restored := RunSnapshot.restore(RunSnapshot.capture(sim))
	c.ok(restored != null, "completed delivery roundtrips with its closed targets: %s" % RunSnapshot.last_error)
	if restored != null:
		c.eq(restored.player.materials, sim.player.materials, "resume cannot add a second reward")


func test_failed_optional_delivery_has_no_surprise_penalty_or_departure_block(c: Check) -> void:
	var sim := _sim()
	_at(sim, BureauEvents.PICKUP_ID)
	BureauEvents.finish_wave(sim, false)
	c.eq(sim.expedition["bureau"]["delivery"]["state"], &"missed", "unfinished document has an explicit missed outcome")
	c.eq(sim.player.materials, Sim.START_MATERIALS, "failure creates no debt or tax")
	var state := sim.expedition.duplicate(true)
	BureauEvents.finish_wave(sim, false)
	c.eq(sim.expedition, state, "repeat settlement cannot repeat its event or consequence")
	sim._end_wave()
	c.ok(sim.can_start_wave(), "optional failure cannot trap player in shop")
	c.ok(RunSnapshot.restore(RunSnapshot.capture(sim)) != null, "missed event is a valid save")


func test_stamp_uses_one_shared_hit_circle_and_warning_boundary(c: Check) -> void:
	var sim := _sim()
	sim.player.pos = BureauEvents.STAMP + Vector2(BureauEvents.RADIUS + PlayerState.RADIUS - 0.1, 0.0)
	var enemy := _enemy(sim, BureauEvents.STAMP + Vector2(0.0, BureauEvents.RADIUS + 11.9))
	enemy.pos = BureauEvents.STAMP + Vector2(0.0, BureauEvents.RADIUS + enemy.radius - 0.1)
	var outside := _enemy(sim, BureauEvents.STAMP + Vector2(0.0, BureauEvents.RADIUS + 80.0))
	c.ok(SupportSystem.spawn(sim, &"hound", BureauEvents.STAMP), "actual support participates in stamp geometry")
	var unit: Dictionary = sim.support_units[0]
	var hp := sim.player.hp
	var support_hp := float(unit["hp"])
	BureauEvents.step(sim, 1.09)
	c.eq(sim.player.hp, hp, "warning draws before player damage")
	c.eq(enemy.hp, enemy.max_hp, "warning cannot damage enemies early")
	var p: Dictionary = BureauEvents.profile(sim)["delivery"]
	c.ok(p["warning"] and not p["active"] and p["radius"] == BureauEvents.RADIUS, "rendered warning reads the real collision radius")
	BureauEvents.step(sim, 0.02)
	c.eq(sim.player.hp, hp - 8.0, "actual player body edge is included in impact")
	c.ok(enemy.hp < enemy.max_hp, "same circle hits an enemy body")
	c.eq(outside.hp, outside.max_hp, "outside enemy is safe")
	c.ok(float(unit["hp"]) < support_hp or not sim.support_units.has(unit), "same impact damages actual support")
	sim.player.iframes = 0.0
	BureauEvents.step(sim, 0.02)
	c.eq(sim.player.hp, hp - 8.0, "active drawing is not a repeated free damage tick")


func test_solo_can_hold_the_switch_and_walk_the_real_route_within_safe_interval(c: Check) -> void:
	var sim := _sim(2, &"solo")
	c.ok(_at(sim, BureauEvents.SWITCH_ID), "Solo can independently hold the stamp")
	c.eq(sim.expedition["bureau"]["delivery"]["safe_left"], 4.0, "switch advertises exactly four safe seconds")
	c.ok(not sim.interact(), "held switch has an actual cooldown")
	var current := sim.player.pos
	var travel := 0.0
	for destination in [BureauEvents.PICKUP, BureauEvents.INBOX]:
		while current.distance_to(destination) > 1.0 and travel < 4.0:
			var delta := 1.0 / 60.0
			current = WorldArena.move_body(current, (destination - current).normalized() * 160.0 * delta, PlayerState.RADIUS)
			sim.player.pos = current
			BureauEvents.step(sim, delta)
			travel += delta
		c.ok(current.distance_to(destination) <= 1.0, "real body sweep reaches its target without a special bypass")
		c.ok(sim.interact(), "Solo performs pickup/inbox with the existing interaction entry")
	c.ok(travel < 4.0, "the authored manual solution fits inside actual safety")
	c.eq(sim.player.materials, Sim.START_MATERIALS + 8, "Solo receives the same exact reward")


func test_real_recorded_switch_replays_later_once_and_costs_condition(c: Check) -> void:
	var sim := _sim()
	sim.player.pos = BureauEvents.SWITCH
	sim.recorder.begin(sim.player.pos)
	sim.recorder.record(sim.player.pos, 0.5)
	c.ok(sim.interact(), "player actually records the new machine switch")
	sim.recorder.record(sim.player.pos, 0.5)
	var take := sim.recorder.finish(2, sim.player.weapons, sim.player.stats, sim.player.weapon_levels)
	c.eq(take.work_actions.size(), 1, "one canonical recorded action")
	c.eq(take.work_actions[0]["target_id"], BureauEvents.SWITCH_ID, "work names the actual switch, not a generic free skill")
	sim.bank.add(take)
	sim.start_wave(6)
	sim._plan.clear()
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(before)
	c.ok(restored != null, "recorded switch has a valid strict snapshot: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	for run: Sim in [sim, restored]:
		EchoSystem.step(run, 0.51)
		c.eq(run.expedition["bureau"]["delivery"]["safe_left"], 4.0, "Echo performs the recorded lever at a later event")
		c.eq(run.expedition["bureau"]["work"], [{"uid": take.uid, "count": 1}], "only successful actual work enters the future retirement receipt")
		c.ok(run.bank.find_uid(take.uid).condition < 96.0, "successful replay pays real additional wear")
		EchoSystem.step(run, 0.1)
		c.eq(run.expedition["bureau"]["work"][0]["count"], 1, "next frame cannot repeat consumed work")
	c.eq(RunSnapshot.capture(sim), RunSnapshot.capture(restored), "restored cursor, condition, event and RNG continue exactly")


func test_huge_tick_consumes_periods_without_hit_burst_and_pure_profile(c: Check) -> void:
	var sim := _sim()
	sim.player.pos = BureauEvents.STAMP
	var hp := sim.player.hp
	BureauEvents.step(sim, 100000.0)
	c.eq(sim.player.hp, hp - 8.0, "one long tick never replays thousands of accumulated hits")
	c.ok(BureauEvents.validate_state(sim), "skipped periods preserve bounded finite state")
	var before := RunSnapshot.capture(sim)
	for value in [0.0, -1.0, INF, NAN]:
		BureauEvents.step(sim, value)
	BureauEvents.profile(sim)
	c.eq(RunSnapshot.capture(sim), before, "invalid deltas and draw queries cannot mutate state")


func test_authoritative_interaction_range_and_switch_cooldown_stay_exact(c: Check) -> void:
	var sim := _sim()
	var before := RunSnapshot.capture(sim)
	c.ok(not BureauEvents.interact(sim, {"id": BureauEvents.PICKUP_ID}), "calling model from far away cannot invent a carried file")
	c.eq(RunSnapshot.capture(sim), before, "failed range preflight is a complete zero mutation")
	c.ok(_at(sim, BureauEvents.SWITCH_ID), "actual lever starts a safety interval")
	BureauEvents.step(sim, 4.0)
	c.ok(BureauEvents.validate_state(sim), "safety and input cooldown remain the same clock after a long step")
	c.ok(sim.interact(), "switch is available exactly when the safety interval expires")
	var restored := RunSnapshot.restore(RunSnapshot.capture(sim))
	c.ok(restored != null, "repeated legal switch use is snapshot-safe")
	if restored != null:
		c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "safe interval and recorded action restore exactly")


func test_real_stamp_death_closes_optional_delivery_without_losing_run_validity(c: Check) -> void:
	var sim := _sim()
	sim.player.pos = BureauEvents.STAMP
	sim.player.hp = 1.0
	sim.step(1.11, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.LOST, "actual shared damage rule can cause a terminal loss")
	c.eq(sim.expedition["bureau"]["delivery"]["state"], &"missed", "death records a missed document exactly once")
	c.ok(RunSnapshot.restore(RunSnapshot.capture(sim)) != null, "dead run retains a valid outcome graph")


func test_retirement_receipt_uses_actual_successes_and_is_bounded(c: Check) -> void:
	var sim := _sim()
	for i in 8:
		var take := _take(sim, 100.0)
		var actor := EchoActor.new(take, 0)
		sim.echoes.append(actor)
		BureauEvents.note_work(sim, {"uid": take.uid, "success": false})
		BureauEvents.note_work(sim, {"uid": take.uid, "success": true})
		BureauEvents.note_work(sim, {"uid": take.uid, "success": true})
		EchoSystem._remove(sim, actor, false, {})
		var row: Dictionary = sim.expedition["bureau"]["retired"].back()
		c.eq(row["work"], 2, "receipt counts successes, not attempt markers")
		c.eq(row["uid"], take.uid, "receipt retains the retired stable identity")
		c.eq(row["weapon_id"], &"pistol", "natural/empty presentation profile still resolves actual weapon")
	c.eq(sim.expedition["bureau"]["retired"].size(), 6, "retirement history stays bounded")
	c.ok(sim.expedition["bureau"]["work"].is_empty(), "retired work counters do not accumulate forever")
	c.ok(RunSnapshot.restore(RunSnapshot.capture(sim)) != null, "bounded retirement facts survive strict save")


func test_closed_bureau_and_target_crosslinks_reject_forgery(c: Check) -> void:
	for mode in ["extra", "position", "reward", "missing", "kind", "used", "nan", "retired", "work"]:
		var sim := _sim()
		var b: Dictionary = sim.expedition["bureau"]
		match mode:
			"extra": b["free_money"] = 100
			"position": b["delivery"]["stamp"] += Vector2.ONE
			"reward": b["delivery"]["rewarded"] = true
			"missing": sim.interactables.pop_back()
			"kind": sim.interactables.back()["kind"] = &"press"
			"used": sim.interactables.back()["used"] = true
			"nan": b["delivery"]["clock"] = NAN
			"retired": b["retired"].append({"uid": 99})
			"work": b["work"].append({"uid": 1, "count": -1})
		c.ok(not BureauEvents.validate_state(sim), "strict bureau validation rejects " + mode)


func test_retired_identity_cannot_also_be_a_live_copy_or_work_counter(c: Check) -> void:
	var sim := _sim()
	var take := _take(sim)
	var record := {"uid": take.uid, "wave": sim.wave, "recorded_wave": take.wave,
		"weapon_id": &"pistol", "reason": &"active", "work": 0, "condition": 100.0, "merged": false}
	sim.expedition["bureau"]["retired"].append(record)
	c.ok(not BureauEvents.validate_state(sim), "a retained body cannot be fabricated as retired")
	c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "strict restore rejects the live/retired contradiction")
	sim.bank.discard(take)
	sim.expedition["bureau"]["work"].append({"uid": take.uid, "count": 1})
	c.ok(not BureauEvents.validate_state(sim), "completed obituary consumes its active work counter")
	sim.expedition["bureau"]["work"].clear()
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	c.ok(not BureauEvents.validate_state(sim), "even an orphan actor cannot share a retired identity")


func test_actual_inherited_finale_record_can_retire_in_opening_encounter(c: Check) -> void:
	for exhausted in [false, true]:
		var meta := Meta.new("user://bureau_retirement_unused_profile.json")
		var source := _sim(12)
		var take := _take(source, 70.0)
		meta.echo_archives["looper"] = EchoArchive.encode(take)
		var sim := Sim.new(17018)
		var inherited := EchoArchive.load(meta, &"looper", sim)
		c.ok(inherited != null, "actual archive loader accepts original finale take")
		if inherited == null:
			continue
		sim.bank.add(inherited)
		sim.start_run()
		var actor: EchoActor = sim.echoes[0]
		if exhausted:
			actor.take.condition = 0.0
			EchoSystem.step(sim, 0.01)
		else:
			c.ok(sim.retire_selected_echo(), "actual opening active retirement succeeds")
		var row: Dictionary = sim.expedition["bureau"]["retired"][0]
		c.eq(row["recorded_wave"], 12, "original recording keeps its truthful earlier-run encounter")
		c.eq(row["wave"], 1, "retirement belongs to the current opening encounter")
		var before := RunSnapshot.capture(sim)
		var restored := RunSnapshot.restore(before)
		c.ok(restored != null, "both active and natural inherited retirements remain resumable")
		if restored != null:
			c.eq(RunSnapshot.capture(restored), before, "independent origin/current encounter fields roundtrip exactly")


func test_repeated_apparatus_signals_preserve_real_departure_across_three_acts(c: Check) -> void:
	var sim := _sim(1)
	_recruit_for_history(sim, &"foreman", &"stop_press", c)
	sim._end_wave()
	sim.start_wave(2)
	sim._plan.clear()
	_recruit_for_history(sim, &"collector", &"settle_debt", c)
	var departure: Dictionary = {}
	for event: Dictionary in sim.expedition["world"]["history"]:
		if event["kind"] == &"companion_departed":
			departure = event.duplicate(true)
	c.ok(not departure.is_empty(), "canonical replacement actually generated a colleague departure")
	var signals: Array[Dictionary] = []
	sim.world_event.connect(func(info: Dictionary) -> void:
		if info["kind"] in [&"dispatch_carried", &"dispatch_safe", &"dispatch_impact"]:
			signals.append(info.duplicate(true)))
	var expected: Array[Dictionary] = []
	for stage in [2, 6, 10]:
		if stage != 2:
			sim._end_wave()
			sim.start_wave(stage)
			sim._plan.clear()
		c.ok(_at(sim, BureauEvents.PICKUP_ID), "each declared apparatus has a real collected document")
		expected.append({"kind": &"dispatch_carried", "subject": BureauEvents.PICKUP_ID,
			"stage": stage, "pos": BureauEvents.PICKUP})
		var before: Array = sim.expedition["world"]["history"].duplicate(true)
		var rng_before := sim.rng.state
		var hazard_before := sim.hazard_rng.state
		# Extend only the apparatus timeline as a clinical retention stress. No
		# extra encounter income, spawn planning or companion life is simulated.
		for _cycle in 12:
			c.ok(_at(sim, BureauEvents.SWITCH_ID), "actual switch continues to emit its safety response")
			expected.append({"kind": &"dispatch_safe", "subject": BureauEvents.SWITCH_ID,
				"stage": stage, "pos": BureauEvents.SWITCH})
			BureauEvents.step(sim, BureauEvents.SAFE_INTERVAL + BureauEvents.WARNING + 0.01)
			expected.append({"kind": &"dispatch_impact", "subject": BureauEvents.SWITCH_ID,
				"stage": stage, "pos": BureauEvents.STAMP})
		c.eq(signals, expected, "audio and drawing receive exactly the same event values and count")
		c.eq(sim.rng.state, rng_before, "apparatus feedback never consumes combat randomness")
		c.eq(sim.hazard_rng.state, hazard_before, "apparatus feedback never consumes hazard randomness")
		c.eq(sim.expedition["world"]["history"], before, "repeated safety/impact feedback never occupies persistent decision history")
		c.ok(sim.expedition["world"]["history"].has(departure), "the actual departed colleague remains in the visible memory")
		c.ok(_at(sim, BureauEvents.INBOX_ID), "meaningful delivery outcome still commits normally")
		c.eq(sim.expedition["world"]["history"].back()["kind"], &"dispatch_delivered", "completed document remains a persistent world fact")
	c.eq(signals.size(), 75, "all three apparatus timelines retain their transient feedback")
	for event: Dictionary in sim.expedition["world"]["history"]:
		c.ok(event["kind"] not in [&"dispatch_carried", &"dispatch_safe", &"dispatch_impact"], "temporary apparatus progress is absent from the permanent history")
	c.ok(sim.expedition["world"]["history"].size() < Expedition.MAX_HISTORY, "preservation does not increase the existing history cap")
	c.ok(Expedition.validate_state(sim), "final event and retained colleague graph remains valid")
