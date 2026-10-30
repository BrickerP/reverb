extends RefCounted

const PROFILE := "user://test_bureau_reports.json"


func _shop(role: StringName = &"looper") -> Sim:
	var sim := Sim.new(1717)
	Content.character(role).apply(sim)
	sim.start_run()
	sim._end_wave()
	sim.player.materials = 0
	return sim


func _take(sim: Sim, condition: float = 94.0) -> EchoTake:
	var take := EchoTake.new()
	take.wave = sim.wave
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(10.0, 0.0)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	take.condition = condition
	sim.bank.add(take)
	sim.selected_echo_uid = take.uid
	return take


func _clean_profile() -> void:
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func test_truth_quote_actual_benefit_commit_and_exact_undo(c: Check) -> void:
	var sim := _shop()
	var take := _take(sim, 99.0)
	var before := RunSnapshot.capture(sim)
	var quote := sim.shop.quote(ShopResult.CONFESS, sim, null, -1, &"truth")
	c.ok(quote.ok and quote.cost == 0, "truth is an explicit free shop choice")
	c.near(BureauConfession.profile(sim)["truth_amount"], 1.0, 0.0001, "quote states actual remaining repair")
	c.eq(RunSnapshot.capture(sim), before, "query consumes no money, state or RNG")
	c.ok(sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"truth").ok, "canonical truth action applies")
	c.near(take.condition, 100.0, 0.0001, "repair is capped")
	c.near(BureauConfession.profile(sim)["truth_amount"], 1.0, 0.0001, "signed receipt preserves actual benefit after repair")
	c.ok(not StoryLedger.discovered(sim).has(&"confession_truth"), "reversible choice has no permanent clue yet")
	var staged := RunSnapshot.capture(sim)
	var restored := RunSnapshot.restore(staged)
	c.ok(restored != null, "pending choice and its undo graph resume: " + RunSnapshot.last_error)
	if restored != null:
		c.eq(RunSnapshot.capture(restored), staged, "pending snapshot is exact")
		c.ok(restored.shop.undo(restored).ok, "restored choice can undo")
		c.eq(RunSnapshot.capture(restored), before, "undo restores condition, records, focus target and RNG")
	sim.start_next_wave()
	c.eq(sim.phase, Sim.Phase.WAVE, "depart after signing")
	c.ok(StoryLedger.discovered(sim).has(&"confession_truth"), "departure commits actual testimony")
	c.eq(sim.expedition["bureau"]["confessions"][0]["state"], &"passed", "truth requires no invented inspection")


func test_solo_truth_heals_only_actual_missing_health_and_one_choice_per_act(c: Check) -> void:
	var sim := _shop(&"solo")
	sim.player.hp = sim.player.max_hp() - 2.0
	c.eq(BureauConfession.profile(sim)["truth_kind"], &"health", "Solo has an equally useful health alternative")
	c.near(BureauConfession.profile(sim)["truth_amount"], 2.0, 0.0001, "health quote uses actual missing amount")
	c.ok(sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"truth").ok, "Solo can sign")
	c.near(sim.player.hp, sim.player.max_hp(), 0.0001, "healing is capped")
	var after := RunSnapshot.capture(sim)
	c.ok(not sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish").ok, "cannot collect both choices in one act")
	c.eq(RunSnapshot.capture(sim), after, "second choice is mutation-free")
	c.ok(sim.shop.undo(sim).ok, "single choice remains reversible")
	c.ok(sim.expedition["bureau"]["confessions"].is_empty(), "undo restores availability")
	c.ok(not sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"unknown").ok, "unknown choice rejected")
	sim.endless = true
	c.ok(not BureauConfession.profile(sim)["available"], "Endless does not grow campaign confession records")


func test_polish_creates_real_announced_inspection_and_no_repeat_cash(c: Check) -> void:
	var sim := _shop()
	c.ok(sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish").ok, "polish signs through shop")
	c.eq(sim.player.materials, 12, "advance paid once exactly")
	sim.start_next_wave()
	c.eq(sim.phase, Sim.Phase.WAVE, "depart with announced inspection")
	c.ok(StoryLedger.discovered(sim).has(&"confession_polish"), "departure commits chosen story")
	var target: Dictionary = {}
	for item: Dictionary in sim.interactables:
		if item["id"] == BureauConfession.TERMINAL_ID:
			target = item
	c.ok(not target.is_empty(), "actual next encounter has E/X terminal")
	if target.is_empty():
		return
	sim.player.pos = target["pos"]
	c.ok(sim.interact(), "real world input registers the inspection")
	c.eq(sim.expedition["bureau"]["confessions"][0]["state"], &"passed", "real choice passes once")
	c.eq(sim.enemy_zones.size(), 1, "registration creates an actual dangerous zone")
	c.near(sim.enemy_zones[0].warning, 1.1, 0.0001, "exact warning precedes hit")
	var after := RunSnapshot.capture(sim)
	c.ok(not BureauConfession.interact(sim, target), "used terminal cannot be repeated")
	c.eq(RunSnapshot.capture(sim), after, "repeat gives no money or hazard")
	var resumed := RunSnapshot.restore(after)
	c.ok(resumed != null, "used terminal/hazard resume strictly: " + RunSnapshot.last_error)
	if resumed != null:
		c.eq(RunSnapshot.capture(resumed), after, "post-inspection snapshot exact")


func test_skipped_inspection_has_no_hidden_debt_or_extra_tax(c: Check) -> void:
	var sim := _shop()
	sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish")
	sim.start_next_wave()
	var funds := sim.player.materials
	var debt := int(sim.expedition["debt"])
	BureauConfession.finish_wave(sim, true)
	c.eq(sim.player.materials, funds, "missed inspection deducts no cash")
	c.eq(sim.expedition["debt"], debt, "missed inspection adds no debt")
	c.eq(sim.expedition["bureau"]["confessions"][0]["state"], &"missed", "record clearly remains unverified")


func test_confession_forbidden_phase_and_forged_schema_reject_without_mutation(c: Check) -> void:
	var sim := _shop()
	var before := RunSnapshot.capture(sim)
	sim.phase = Sim.Phase.WAVE
	c.ok(not BureauConfession.apply(sim, &"polish"), "battle cannot purchase an advance")
	sim.phase = Sim.Phase.SHOP
	c.eq(RunSnapshot.capture(sim), before, "rejected purchase leaves original shop exact")
	sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"truth")
	var valid: Array = sim.expedition["bureau"]["confessions"].duplicate(true)
	for field in ["act", "wave", "uid", "amount", "state", "committed", "extra"]:
		var malformed := valid.duplicate(true)
		match field:
			"act": malformed[0][field] = 4
			"wave": malformed[0][field] = 6
			"uid": malformed[0][field] = -1
			"amount": malformed[0][field] = NAN
			"state": malformed[0][field] = &"invented"
			"committed": malformed[0][field] = true
			_: malformed[0][field] = true
		c.ok(not BureauConfession.validate_rows(malformed, sim), "forged confession " + field + " rejected")
	var duplicate := valid.duplicate(true)
	duplicate.append(valid[0].duplicate(true))
	c.ok(not BureauConfession.validate_rows(duplicate), "one record per act")


func test_inspection_cap_range_and_live_orphan_rows_reject_before_effects(c: Check) -> void:
	var sim := _shop()
	sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish")
	sim.start_next_wave()
	var target: Dictionary = {}
	for item: Dictionary in sim.interactables:
		if item["id"] == BureauConfession.TERMINAL_ID:
			target = item
	if target.is_empty():
		c.ok(false, "inspection target exists")
		return
	var before := RunSnapshot.capture(sim)
	c.ok(not BureauConfession.interact(sim, target), "remote terminal cannot be signed out of range")
	c.eq(RunSnapshot.capture(sim), before, "out-of-range attempt has no consequence")
	sim.player.pos = target["pos"]
	for index in EnemyBrain.MAX_ZONES:
		var zone := EnemyZone.new()
		zone.pos = sim.player.pos
		sim.enemy_zones.append(zone)
	before = RunSnapshot.capture(sim)
	c.ok(not BureauConfession.interact(sim, target), "full hazard capacity blocks registration")
	c.eq(RunSnapshot.capture(sim), before, "capacity failure neither completes nor charges the choice")
	sim.enemy_zones.clear()
	var saved_items := sim.interactables.duplicate(true)
	sim.interactables.erase(target)
	c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "active signed row must retain its real terminal")
	sim.interactables.assign(saved_items)
	sim.expedition["bureau"]["confessions"].clear()
	c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "terminal cannot survive without authoritative signed record")


func test_snapshot_v4_rejects_forged_pending_choice_inside_undo(c: Check) -> void:
	var sim := _shop()
	sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish")
	var upgrade := Offer.new()
	upgrade.weapon = Content.weapon(&"smg")
	upgrade.price = 0
	sim.shop.offers.clear()
	sim.shop.offers.append(upgrade)
	sim.shop.apply(ShopResult.BUY, sim, upgrade)
	var original := RunSnapshot.capture(sim)
	c.ok(RunSnapshot.restore(original) != null, "valid pending confession survives another equipment undo frame")
	var history: Array = sim.shop.get("_undo_stack")
	var state := history.back() as ShopState
	state.expedition["bureau"]["confessions"][0]["wave"] = 3
	c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "undo cannot schedule the same act choice for a different departure")


func test_truth_quote_finds_repairable_shop_copy_without_a_live_actor(c: Check) -> void:
	var sim := _shop()
	var oldest := _take(sim, 90.0)
	var worn := _take(sim, 40.0)
	sim.selected_echo_uid = 0
	c.eq(BureauConfession.profile(sim)["truth_uid"], worn.uid, "fresh shop records can be repaired without a live selected actor")
	sim.selected_echo_uid = oldest.uid
	c.eq(BureauConfession.profile(sim)["truth_uid"], worn.uid, "battle selection never changes the automatic shop target")
	oldest.condition = 40.0
	c.eq(BureauConfession.profile(sim)["truth_uid"], oldest.uid, "equal wear breaks ties by stable UID")
	sim.expedition["world"]["staff_uid"] = oldest.uid
	c.eq(BureauConfession.profile(sim)["truth_uid"], worn.uid, "staff copy never receives the active repair benefit")
	sim.expedition["world"]["staff_uid"] = 0
	oldest.condition = 100.0
	c.eq(BureauConfession.profile(sim)["truth_uid"], worn.uid, "full selected copy does not hide another repairable copy")
	worn.condition = 100.0
	sim.player.hp = sim.player.max_hp() - 3.0
	c.eq(BureauConfession.profile(sim)["truth_kind"], &"health", "when all copies are full, actual health benefit remains available")
	c.near(BureauConfession.profile(sim)["truth_amount"], 3.0, 0.0001, "health alternative is exact")


func test_undo_cannot_claim_a_retired_copy_while_retaining_its_body(c: Check) -> void:
	for impossible_uid in [false, true]:
		var sim := _shop()
		var take := _take(sim, 75.0)
		sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"truth")
		var history: Array = sim.shop.get("_undo_stack")
		var state := history.back() as ShopState
		state.expedition["bureau"]["retired"] = [{"uid": state.next_echo_uid if impossible_uid else take.uid,
			"wave": state.wave, "recorded_wave": 1, "weapon_id": &"pistol", "reason": &"active", "work": 0,
			"condition": 75.0, "merged": false}]
		c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "undo retirement cannot retain a body or invent a future UID")


func test_pending_signature_locks_reroll_without_spending_or_rng_and_undo_unlocks(c: Check) -> void:
	for choice: StringName in BureauConfession.CHOICES:
		var sim := _shop()
		sim.player.materials = 100
		var before := RunSnapshot.capture(sim)
		c.ok(sim.shop.apply(ShopResult.CONFESS, sim, null, -1, choice).ok, "sign reversible " + String(choice))
		var signed := RunSnapshot.capture(sim)
		c.eq(sim.shop.quote(ShopResult.REROLL, sim).reason, &"pending_confession", "authoritative quote explains fixed stock")
		c.ok(not sim.shop.apply(ShopResult.REROLL, sim).ok, "canonical refresh rejected")
		c.ok(not sim.shop.reroll(sim), "direct stale refresh rejected")
		c.eq(RunSnapshot.capture(sim), signed, "refresh rejection preserves all state, stock, cash and both RNGs")
		c.ok(sim.shop.undo(sim).ok, "signature can still be reversed")
		c.eq(RunSnapshot.capture(sim), before, "sign and undo restore full original state")
		c.ok(sim.shop.quote(ShopResult.REROLL, sim).ok and sim.shop.reroll(sim), "normal refresh available after Undo")
		c.ok(not sim.shop.can_undo(), "ordinary paid refresh retains its established history boundary")


func _ordinary_goods_action(sim: Sim, buy: bool) -> bool:
	if not buy:
		return sim.shop.apply(ShopResult.SELL, sim, null, sim.player.weapons.size() - 1).ok
	# A fixed stock fixture isolates the bounded history rule from refresh RNG.
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 2
	sim.shop.offers.clear()
	sim.shop.offers.append(offer)
	return sim.shop.apply(ShopResult.BUY, sim, offer).ok


func test_history_ring_keeps_last_presign_snapshot_after_older_history_is_evicted(c: Check) -> void:
	var sim := _shop()
	sim.player.materials = 1000
	for index in 40:
		c.ok(_ordinary_goods_action(sim, index % 2 == 0), "ordinary old-history action %d" % index)
	c.eq(sim.shop.get("_undo_stack").size(), Shop.MAX_UNDO, "ordinary history still has its bounded ring")
	var before := ShopState.capture(sim).to_dict()
	c.ok(sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish").ok, "signature after preexisting full history")
	for index in 31:
		c.ok(_ordinary_goods_action(sim, index % 2 == 0), "ordinary post-sign action %d remains available" % index)
	c.eq(sim.shop.get("_undo_stack").size(), Shop.MAX_UNDO, "anchor plus thirty-one following actions fill the ring")
	var frozen := RunSnapshot.capture(sim)
	c.eq(sim.shop.quote(ShopResult.SELL, sim, null, sim.player.weapons.size() - 1).reason, &"history_full", "next push cannot evict signature's only anchor")
	c.ok(not sim.shop.apply(ShopResult.SELL, sim, null, sim.player.weapons.size() - 1).ok, "blocked push does not mutate")
	c.eq(RunSnapshot.capture(sim), frozen, "capacity rejection preserves complete live history")
	var restored := RunSnapshot.restore(frozen)
	c.ok(restored != null, "protected full history survives save/resume: " + RunSnapshot.last_error)
	if restored == null:
		return
	for index in 32:
		c.ok(restored.shop.undo(restored).ok, "Undo reaches signature after bounded actions %d" % index)
	c.eq(BureauConfession.pending_act(restored), 0, "final Undo clears signature")
	c.eq(ShopState.capture(restored).to_dict(), before, "full sequence restores original money, stock and bureau state")
	c.ok(restored.shop.reroll(restored), "refresh works again after signature is reversed")


func test_pending_signature_cannot_resume_without_any_presign_undo_anchor(c: Check) -> void:
	var sim := _shop()
	sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish")
	c.ok(RunSnapshot.restore(RunSnapshot.capture(sim)) != null, "real canonical signature is resumable")
	sim.shop.clear_history()
	c.eq(RunSnapshot.restore(RunSnapshot.capture(sim)), null, "forged pending signature with destroyed history cannot load")


func test_confession_profile_retains_pending_passed_and_missed_past_act_facts(c: Check) -> void:
	var sim := _shop()
	sim.shop.apply(ShopResult.CONFESS, sim, null, -1, &"polish")
	c.eq(BureauConfession.profile(sim)["signed_state"], &"pending", "signed sheet says pending before departure")
	c.ok(BureauConfession.profile(sim)["pending"], "pending status is explicit")
	sim.start_next_wave()
	c.eq(BureauConfession.profile(sim)["signed_state"], &"active", "live inspection is awaiting registration")
	sim._end_wave()
	c.eq(BureauConfession.profile(sim)["signed_state"], &"missed", "returning shop shows missed instead of generic signed")
	var report := BureauConfession.profile(sim)
	report["history"][0]["state"] = &"passed"
	c.eq(BureauConfession.profile(sim)["signed_state"], &"missed", "view history is detached and cannot change facts")
	sim.start_wave(4)
	sim._end_wave()
	var next_act := BureauConfession.profile(sim)
	c.eq(next_act["signed_state"], &"unsigned", "new upcoming act is independent")
	c.eq(next_act["history"][0]["state"], &"missed", "past act remains inspectable with true unverified status")
