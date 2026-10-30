extends RefCounted


func _sim(stage: int = 1) -> Sim:
	var sim := Sim.new(1616)
	sim.start_run()
	if stage != 1:
		sim.start_wave(stage)
	sim._plan.clear()
	return sim


func _target(sim: Sim, kind: StringName) -> Dictionary:
	for item in sim.interactables:
		if item["kind"] == kind and not item["used"]:
			return item
	return {}


func _save_worker(sim: Sim) -> Dictionary:
	var item := _target(sim, &"rescue")
	if item.is_empty():
		return {}
	sim.player.pos = item["pos"]
	sim.interact()
	return Expedition._worker(sim, item["id"])


func _negotiate(sim: Sim, kind: StringName) -> void:
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
	sim._materialize(spawn)
	sim.damage_enemy(sim.boss, 100000.0, Vector2.ZERO, false)


func test_forecast_and_natural_dangers_are_order_independent_and_pure(c: Check) -> void:
	var natural := _sim()
	var ordered := _sim()
	var contract := AnomalyContract.new()
	contract.kind = &"repair"
	Expedition.on_order_purchased(ordered, contract)
	natural.start_wave(2)
	ordered.start_wave(2)
	c.eq(natural.expedition["world"], ordered.expedition["world"], "buying responsibility does not manufacture a fault or worker")
	c.eq(natural.interactables, ordered.interactables, "same natural production targets exist with and without order")
	var before := RunSnapshot.capture(natural)
	for stage in [1, 5, 9, 12]:
		var forecast := Expedition.forecast(natural, stage)
		c.eq(forecast["act_id"], 1 + int((stage - 1) / 4), "forecast gives the actual production act")
		Expedition.world_profile(natural)
		Expedition.crew_options(natural)
		Expedition.negotiation_options(natural)
		Expedition.exit_options(natural)
	c.eq(RunSnapshot.capture(natural), before, "all rendering and quote queries leave complete state and both RNGs unchanged")


func test_ambient_repair_stays_fixed_through_both_later_acts(c: Check) -> void:
	var sim := _sim()
	var target := _target(sim, &"repair")
	sim.player.pos = target["pos"]
	c.ok(sim.interact(), "ambient fault can be repaired without a paid order")
	var id := StringName(String(target["id"]).trim_prefix("repair_"))
	var machine := Expedition._machine(sim, id)
	c.eq(machine["status"], &"repaired", "repair changes the persistent machine record")
	c.eq(sim.player.materials, Sim.START_MATERIALS, "ambient repair has no unannounced cash tax")
	for stage in [5, 9]:
		sim.start_wave(stage)
		sim._plan.clear()
		sim.player.pos = machine["pos"]
		sim.player.iframes = 100.0
		sim.step(0.1, Vector2.ZERO)
		c.eq(Expedition._machine(sim, id)["status"], &"repaired", "new production act retains repair")
		for item in sim.interactables:
			if item["id"] == id:
				c.eq(item["warning"], 0.0, "repaired press cannot restart automatically")
		c.eq(Expedition.world_profile(sim)["act_id"], 1 + int((stage - 1) / 4), "live profile exposes changed act")


func test_saved_person_leaves_danger_remains_safe_and_offers_once_only_aid(c: Check) -> void:
	var sim := _sim()
	var target := _target(sim, &"rescue")
	var danger: Vector2 = target["pos"]
	var worker := _save_worker(sim)
	c.eq(worker["state"], &"safe", "real worker enters safe registry")
	c.ok((worker["pos"] as Vector2).distance_to(danger) > 100.0, "person physically leaves danger")
	c.eq(sim.support_units.size(), 0, "a saved person never becomes cardboard equipment")
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = worker["pos"]
	enemy.damage = 10000.0
	enemy.hp = 10.0
	enemy.max_hp = 10.0
	sim.enemies.append(enemy)
	sim.player.pos = danger
	sim.player.iframes = 100.0
	sim.step(0.1, Vector2.ZERO)
	c.eq(worker["hp"], 45.0, "safe worker is outside enemy contact target processing")
	sim._end_wave()
	sim.player.hp = 1.0
	var aid := StringName("aid_" + String(worker["id"]))
	c.ok(sim.shop.apply(ShopResult.DEPLOY_COMPANION, sim, null, -1, aid).ok, "safe worker aid uses the canonical shop transaction")
	c.eq(sim.player.hp, 7.0, "aid provides exactly six health")
	c.ok(not sim.shop.apply(ShopResult.DEPLOY_COMPANION, sim, null, -1, aid).ok, "same person cannot duplicate aid")
	c.ok(sim.shop.undo(sim).ok, "aid and person state participate in undo")
	c.eq(sim.player.hp, 1.0, "undo restores real pre-aid health")
	c.ok(not Expedition._worker(sim, worker["id"])["aid_used"], "undo restores bounded aid permission")


func test_worker_danger_fails_from_actual_contact_without_an_order(c: Check) -> void:
	var sim := _sim()
	var target := _target(sim, &"rescue")
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = target["pos"]
	enemy.radius = 20.0
	enemy.damage = 500.0
	enemy.hp = 10.0
	enemy.max_hp = 10.0
	sim.enemies.append(enemy)
	sim.player.iframes = 100.0
	sim.step(0.1, Vector2.ZERO)
	c.eq(Expedition._worker(sim, target["id"])["state"], &"missing", "ambient danger has real failure state")
	c.eq(sim.expedition["rescued"], 0, "failed ambient rescue cannot invent a witness")


func test_negotiation_conditions_pause_and_witness_submission_preserve_the_person(c: Check) -> void:
	var sim := _sim(8)
	var worker := _save_worker(sim)
	sim.expedition["credit_taken"] = 1
	sim.expedition["debt"] = 40
	sim.player.materials = 0
	_negotiate(sim, &"collector")
	c.ok(not sim.choose_negotiation(&"settle_debt"), "insufficient funds cannot pay a debt")
	var before := RunSnapshot.capture(sim)
	sim.step(100.0, Vector2.RIGHT)
	c.eq(RunSnapshot.capture(sim), before, "decision modal freezes every authoritative clock and RNG")
	c.ok(sim.choose_negotiation(&"witness_mediation"), "unused named testimony is a distinct valid term")
	c.eq(worker["state"], &"safe", "submitting testimony never removes the person")
	c.ok(worker["testimony_used"], "testimony records its one use")
	c.eq(sim.expedition["debt"], 0, "mediation settles the real balance")
	c.eq(sim.player.materials, 0, "mediation does not silently spend funds")
	c.ok(not sim.choose_negotiation(&"witness_mediation"), "resolved negotiation is idempotent")


func test_replacing_companion_benches_actual_health_and_service_time(c: Check) -> void:
	var sim := _sim(4)
	_negotiate(sim, &"foreman")
	c.ok(not sim.choose_negotiation(&"sign"), "Foreman rejects running presses")
	c.ok(sim.choose_negotiation(&"stop_press"), "explicit press stop meets identity-specific terms")
	sim.support_units[0]["hp"] = 17.0
	sim.support_units[0]["life"] = 123.0
	sim.start_wave(8)
	sim._plan.clear()
	_negotiate(sim, &"collector")
	c.ok(sim.choose_negotiation(&"settle_debt"), "zero balance explicitly settles without charge")
	var old := Expedition._roster(sim, &"foreman")
	c.eq(old["state"], &"bench", "previous companion remains a person in roster")
	c.eq(old["hp"], 17.0, "bench preserves actual remaining health")
	c.eq(old["life"], 123.0, "bench preserves actual service time")
	c.eq(sim.support_units.size(), 1, "exactly one companion has a combat unit")
	sim.step(0.01, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.SHOP, "actual battle settlement opens shop")
	var before := RunSnapshot.capture(sim)
	c.ok(sim.shop.apply(ShopResult.DEPLOY_COMPANION, sim, null, -1, &"foreman").ok, "shop swap uses canonical transaction")
	c.eq(sim.support_units[0]["hp"], 17.0, "redeployment cannot heal by replacement")
	c.ok(sim.shop.undo(sim).ok, "deployment is atomic and undoable")
	c.eq(RunSnapshot.capture(sim), before, "undo restores roster, active unit, history and every saved field")


func test_every_role_has_an_explicit_free_exit_without_orders(c: Check) -> void:
	for character in Content.characters():
		var sim := _sim(12)
		Content.character(character).apply(sim)
		sim.player.materials = 0
		sim._end_wave()
		c.eq(sim.phase, Sim.Phase.RESOLUTION, "final fight waits for a choice for every role")
		c.ok(not sim.choose_exit(&"released"), "unaffordable papers explain blocked release")
		c.ok(sim.choose_exit(&"takeover"), "no-order role always has a free intentional ending")
		c.eq(sim.phase, Sim.Phase.WON, "only actual selected exit emits a win")


func test_resolution_resumes_exactly_and_choices_apply_once(c: Check) -> void:
	var sim := _sim(12)
	_save_worker(sim)
	sim.expedition["debt"] = 40
	sim.expedition["credit_taken"] = 1
	sim._end_wave()
	var before := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(before)
	c.ok(restored != null, "pending final choice is a valid resumable state: %s" % RunSnapshot.last_error)
	if restored == null:
		return
	c.eq(RunSnapshot.capture(restored), before, "final fight and pending intent restore exactly")
	var wins := [0]
	restored.run_won.connect(func() -> void: wins[0] += 1)
	for candidate: Sim in [sim, restored]:
		candidate.step(100.0, Vector2.RIGHT)
		c.ok(candidate.choose_exit(&"collective"), "collective remains available after resume")
		c.eq(candidate.expedition["debt"], 40, "solidarity does not relabel or erase a balance")
		c.ok(not candidate.choose_exit(&"takeover"), "later submission cannot replace applied intent")
	c.eq(wins[0], 1, "real win emits once after choice")
	c.eq(RunSnapshot.capture(restored), RunSnapshot.capture(sim), "same ending produces exact continuation")


func test_closed_world_schema_rejects_forged_records_and_cross_phase_resolution(c: Check) -> void:
	var sim := _sim()
	for kind in [&"machine", &"worker", &"roster", &"history", &"witness", &"extra"]:
		var state := sim.expedition.duplicate(true)
		match kind:
			&"machine": state["world"]["machines"][0]["pos"] = Vector2.ZERO
			&"worker": state["world"]["workers"][0]["hp"] = NAN
			&"roster": state["world"]["roster"] = [{"kind": &"imaginary"}]
			&"history": state["world"]["history"].resize(49)
			&"witness": state["world"]["witnesses"] = [&"worker_99"]
			&"extra": state["world"]["unexpected"] = true
		c.ok(not Expedition.validate_plain(state, sim.interactables), "closed world rejects forged %s" % kind)
	sim.expedition["world"]["resolution_pending"] = true
	c.ok(not Expedition.validate_state(sim), "only an actual final resolution can carry pending exit")


func test_collective_releases_living_crew_with_their_actual_remaining_health(c: Check) -> void:
	var sim := _sim(4)
	_negotiate(sim, &"foreman")
	c.ok(sim.choose_negotiation(&"stop_press"), "real identity-specific agreement signs a colleague")
	sim.support_units[0]["hp"] = 17.0
	sim.support_units[0]["life"] = 123.0
	sim.start_wave(12)
	sim._end_wave()
	c.ok(sim.choose_exit(&"collective"), "a living signed companion is a real collective participant")
	var roster := Expedition._roster(sim, &"foreman")
	c.eq(roster["state"], &"exited", "colleague actually leaves the battle roster alive")
	c.eq(roster["hp"], 17.0, "release cannot invent health")
	c.eq(roster["life"], 123.0, "release preserves their remaining service record")
	c.eq(sim.expedition["ending_outcome"]["survivors"], 1, "receipt counts the actual departing person")
	c.eq(sim.support_units.size(), 0, "departed colleague no longer supplies free endless damage")
	c.ok(Expedition.validate_state(sim), "living departure has a closed valid state")
	c.ok(sim.begin_endless(), "player may deliberately return to work after collective exit")
	c.ok(not sim.shop.apply(ShopResult.DEPLOY_COMPANION, sim, null, -1, &"foreman").ok, "departed person cannot be silently summoned back")


func test_takeover_staff_stays_registered_and_cannot_be_discarded_through_sim(c: Check) -> void:
	var sim := _sim(12)
	sim._end_wave()
	c.ok(sim.choose_exit(&"takeover"), "actual final recorded copy can take a staff post")
	var uid := int(sim.expedition["world"]["staff_uid"])
	c.ok(uid > 0, "staff gets the actual current-run copy identity")
	c.ok(sim.begin_endless(), "staff persists into deliberate endless continuation")
	var staff := sim.bank.find_uid(uid)
	var before := RunSnapshot.capture(sim)
	sim.discard_take(staff)
	c.eq(RunSnapshot.capture(sim), before, "simulation entry uses the same protected shop discard path")
	sim.start_next_wave()
	c.ok(sim.bank.find_uid(uid) != null, "staff remains on bureau register")
	for actor in sim.echoes:
		c.ok(actor.take.uid != uid, "staff no longer replays combat")
	c.ok(Expedition.validate_state(sim), "real staff continuation remains snapshot valid")
	sim.bank.takes.erase(staff)
	c.ok(not Expedition.validate_state(sim), "staff identity cannot point at a missing copy")


func test_live_roster_has_reciprocal_unit_links_and_bounded_witness_choices(c: Check) -> void:
	var orphan := _sim()
	c.ok(SupportSystem.spawn(orphan, &"recruited_foreman", orphan.player.pos), "artificial orphan unit exists")
	c.ok(not Expedition.validate_state(orphan), "a recruited combat unit requires a signed active roster identity")
	var sim := _sim(12)
	var take := EchoTake.new()
	take.samples = PackedVector2Array([sim.player.pos])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	sim.bank.add(take)
	sim.start_wave(12)
	sim._plan.clear()
	_negotiate(sim, &"paradox")
	for index in Expedition.MAX_COPY_WITNESSES:
		sim.expedition["world"]["witnesses"].append(StringName("copy_%d" % (100 + index)))
	c.ok(not sim.choose_negotiation(&"preserve_copy"), "a new identity cannot overflow the witness register in endless")
	c.eq(sim.expedition["world"]["witnesses"].size(), Expedition.MAX_COPY_WITNESSES, "rejected witness leaves every prior identity intact")
	c.ok(sim.choose_negotiation(&"decline"), "bounded register always leaves an explicit free resolution")


func test_signed_press_stop_is_permanent_for_player_and_replay(c: Check) -> void:
	var sim := _sim(4)
	_negotiate(sim, &"foreman")
	c.ok(sim.choose_negotiation(&"stop_press"), "Foreman term actually stops both presses")
	for item in sim.interactables:
		if item["kind"] != &"press":
			continue
		item["cooldown"] = 0.0
		sim.player.pos = item["pos"]
		c.ok(not bool(Expedition.interaction(sim)["available"]), "stopped press interaction explains its disabled state")
		c.ok(not sim.interact(), "player cannot accidentally reactivate a permanently stopped press")
		c.eq(item["warning"], 0.0, "disabled press cannot queue another strike")


func test_full_support_grid_rejects_all_signing_terms_without_spending_anything(c: Check) -> void:
	var sim := _sim(8)
	_save_worker(sim)
	sim.expedition["credit_taken"] = 1
	sim.expedition["debt"] = 40
	sim.player.materials = 100
	for index in 2:
		var take := EchoTake.new()
		take.samples = PackedVector2Array([sim.player.pos])
		take.weapons.append(Content.weapon(&"pistol"))
		take.levels.append(0)
		sim.bank.add(take)
	sim.start_wave(8)
	for owner in [-1, sim.bank.takes[0].uid, sim.bank.takes[1].uid]:
		for kind: StringName in [&"hound", &"turret", &"repair_station", &"paper_tree"]:
			c.ok(SupportSystem.spawn(sim, kind, sim.player.pos, owner), "distinct live owner and kind actually occupies a slot")
	_negotiate(sim, &"collector")
	var before := RunSnapshot.capture(sim)
	c.ok(not sim.choose_negotiation(&"settle_debt"), "full grid cannot accept payment for an undeployable colleague")
	c.ok(not sim.choose_negotiation(&"witness_mediation"), "full grid cannot consume a witness for an undeployable colleague")
	c.eq(RunSnapshot.capture(sim), before, "failed signing preserves cash, debt, testimony, roster, story and RNG")
	for row in Expedition.negotiation_options(sim):
		if row["id"] != &"decline":
			c.eq(row["reason_key"], "negotiation.reason.full", "every signing term explains the real capacity block")
	c.ok(sim.choose_negotiation(&"decline"), "explicit free decline always resolves a full-grid encounter")


func test_solo_self_witness_is_a_persistent_named_fact(c: Check) -> void:
	var sim := _sim(12)
	Content.character(&"solo").apply(sim)
	_negotiate(sim, &"paradox")
	c.ok(sim.choose_negotiation(&"self_witness"), "Solo signs in person without inventing an Echo")
	c.ok(sim.expedition["world"]["witnesses"].has(&"self"), "self identity has a persistent witness entry")
	for index in Expedition.MAX_HISTORY + 1:
		Expedition._event(sim, &"machine_operated", &"machine_1", sim.player.pos)
	c.ok(sim.expedition["world"]["witnesses"].has(&"self"), "bounded history eviction cannot erase a registered witness")
	c.ok(Expedition.validate_state(sim), "canonical named self witness is snapshot valid")
