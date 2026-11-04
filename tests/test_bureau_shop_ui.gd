extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _sim() -> Sim:
	var sim := Sim.new(1717)
	StoryLedger.seed_known(sim, [&"carbon"])
	sim.start_run()
	sim._end_wave()
	sim.player.materials = 100
	return sim


func _add_take(sim: Sim, condition: float = 70.0) -> EchoTake:
	var take := EchoTake.new()
	take.wave = sim.wave
	take.condition = condition
	take.stats = sim.player.stats.copy()
	take.samples = PackedVector2Array([Vector2(300, 250), Vector2(360, 250)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	sim.bank.add(take)
	return take


func _open(sim: Sim, reduced: bool = true) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.set_reduced_effects(reduced)
	ui.open(sim)
	return ui


func test_confession_real_entry_discloses_actual_repair_and_uses_shop_undo(c: Check) -> void:
	var sim := _sim()
	var take: EchoTake = sim.bank.takes[0]
	take.condition = 99.5
	sim.selected_echo_uid = take.uid
	var uid := take.uid
	var before := RunSnapshot.capture(sim)
	var ui := _open(sim)
	ui.confession_button.pressed.emit()
	c.ok(ui.confession.visible, "real fixed shop entry opens the copy desk")
	c.eq(ui.confession._body.text, "", "the copy desk does not repeat the contract above the choices")
	c.eq(ui.confession.choice_buttons.size(), 2, "both signed alternatives are readable")
	c.ok(ui.confession.choice_buttons[0].accessibility_description.contains(Loc.t("confession.ui.truth_echo", [0.5, uid])), "live partial repair discloses0.5 rather than promise12")
	c.eq(RunSnapshot.capture(sim), before, "reading the copy desk cannot sign or consume a benefit")
	ui.confession.choice_buttons[0].pressed.emit()
	c.near(sim.bank.find_uid(uid).condition, 100.0, 0.0001, "real signed truth repairs only missing condition")
	c.ok(ui.confession.choice_buttons[0].disabled and ui.confession.choice_buttons[1].disabled, "one upcoming act cannot sign twice")
	c.ok(ui.confession.choice_buttons[0].accessibility_description.contains(Loc.t("confession.ui.truth_echo", [0.5, uid])), "signed receipt retains actual awarded amount")
	var signed := RunSnapshot.capture(sim)
	ui.confession.chosen.emit(&"polish")
	c.eq(RunSnapshot.capture(sim), signed, "stale activation cannot sign a second alternative")
	c.ok(ui.confession.error_label.visible, "rejected stale choice has visible feedback")
	ui.confession.return_button.pressed.emit()
	c.eq(_root().gui_get_focus_owner(), ui.confession_button, "return restores the real copy desk entry")
	ui.undo_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "normal shop Undo restores the entire signature and benefit")
	ui.free()


func test_polish_previews_inspection_then_real_money_and_exact_undo(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var before := RunSnapshot.capture(sim)
	var clues := StoryLedger.discovered(sim).duplicate()
	ui.confession_button.pressed.emit()
	c.ok(ui.confession.choice_buttons[1].accessibility_description.contains(Loc.t("confession.ui.polish_effect", [12])), "polish shows exact money and announced warned inspection")
	ui.confession.choice_buttons[1].pressed.emit()
	c.eq(sim.player.materials, 112, "copy desk commits exactly twelve materials through Shop")
	c.eq(StoryLedger.discovered(sim), clues, "draft signature cannot farm permanent story before departure")
	c.ok(ui.transaction_profile().is_empty(), "signing a biography does not falsely animate an Echo merge")
	ui._on_start()
	c.ok(ui.visible and ui.confession.visible, "departure cannot run behind an open decision sheet")
	ui.confession.close()
	ui.undo_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "main Undo removes the inspection promise and returns its money atomically")
	ui.free()


func test_health_alternative_and_cancel_are_capped_and_read_only(c: Check) -> void:
	var sim := _sim()
	sim.bank.takes.clear()
	sim.selected_echo_uid = 0
	sim.player.hp = sim.player.max_hp() - 0.5
	var ui := _open(sim)
	var before := RunSnapshot.capture(sim)
	ui.confession_button.pressed.emit()
	c.ok(ui.confession.choice_buttons[0].accessibility_description.contains(Loc.t("confession.ui.truth_health", [0.5])), "no-copy route discloses capped health repair")
	ui.confession.return_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "closing without signing leaves the run untouched")
	ui.confession_button.pressed.emit()
	ui.confession.choice_buttons[0].pressed.emit()
	c.near(sim.player.hp, sim.player.max_hp(), 0.0001, "truth health never overfills its actual maximum")
	ui.free()


func test_binding_and_unbinding_follow_only_actual_committed_identity_changes(c: Check) -> void:
	var sim := _sim()
	var host: EchoTake = sim.bank.takes[0]
	var donor := _add_take(sim)
	var originals := [host.uid, donor.uid]
	var ui := _open(sim, false)
	c.ok(not sim.shop.merge_echoes(sim, host, host).ok, "same-body merge really fails")
	c.ok(ui.transaction_profile().is_empty(), "failed quote has no invented visible result")
	ui._on_merge(host, donor, &"skill")
	ui.flush_feedback()
	var proof := ui.transaction_profile()
	c.eq(proof["before"].size(), 2, "visible proof has the actual two consumed copies")
	c.eq(proof["after"].size(), 1, "visible proof has the actual one kept copy")
	c.eq([proof["before"][0]["uid"], proof["before"][1]["uid"]], originals, "proof preserves actual consumed identities")
	c.ok(not ui.start_button.disabled, "result never delays departure")
	var merged := RunSnapshot.capture(sim)
	ui.set_paused(true)
	ui._change_visual.step(0.4)
	c.eq(ui._change_visual.elapsed, 0.0, "pause freezes the actual inventory ink")
	ui.set_paused(false)
	ui._change_visual.step(0.5)
	c.eq(RunSnapshot.capture(sim), merged, "render time never executes another transaction")
	ui.undo_button.pressed.emit()
	ui.flush_feedback()
	proof = ui.transaction_profile()
	c.eq(proof["action"], ShopResult.UNDO, "visible direction comes from actual Undo")
	c.eq(proof["before"].size(), 1, "one merged body departs")
	c.eq(proof["after"].size(), 2, "both original bodies return")
	c.eq([proof["after"][0]["uid"], proof["after"][1]["uid"]], originals, "restored proof names the original copies")
	ui.free()


func test_reduced_result_rebind_and_old_emitter_cannot_leak_identity_feedback(c: Check) -> void:
	var sim := _sim()
	var host: EchoTake = sim.bank.takes[0]
	var donor := _add_take(sim)
	var ui := _open(sim)
	ui._on_merge(host, donor, &"repair")
	c.ok(ui.transaction_profile().is_empty(), "full-condition host cannot invent repair success")
	ui._on_merge(host, donor, &"skill")
	ui.flush_feedback()
	c.eq(ui.transaction_profile()["progress"], 1.0, "reduced motion presents static real before and after")
	var old_sim := sim
	var next := _sim()
	ui.open(next)
	c.ok(ui.transaction_profile().is_empty() and not ui.confession.visible, "rebind clears prior results")
	old_sim.shop.undo(old_sim)
	c.ok(ui.transaction_profile().is_empty(), "old shop emitter cannot start stale inventory feedback")
	ui.confession_button.pressed.emit()
	ui.close_session()
	c.ok(not ui.confession.visible and ui.transaction_profile().is_empty(), "detach clears identity-bearing presentation")
	ui.free()


func test_each_binding_trait_uses_actual_distinct_read_only_value_profile(c: Check) -> void:
	for merge_trait: StringName in EchoBank.MERGE_TRAITS:
		var sim := _sim()
		var host: EchoTake = sim.bank.takes[0]
		host.condition = 50.0
		var donor := _add_take(sim, 70.0)
		var ui := _open(sim)
		ui.echo_panel.merge_button.pressed.emit()
		(ui.echo_panel._identity_buttons[donor.uid] as Button).pressed.emit()
		var before_preview := RunSnapshot.capture(sim)
		var button := ui.echo_panel.trait_button(merge_trait)
		button.focus_entered.emit()
		var expected := sim.bank.preview_merge(host, donor, merge_trait)
		var preview := ui.echo_panel._trait_preview.snapshot()
		c.eq(preview["after"][0]["uid"], 0, "read-only preview does not invent a committed identity")
		c.eq(preview["after"][0]["condition"], expected.condition, "preview shows canonical final condition")
		c.eq(preview["after"][0]["levels"], expected.levels, "preview shows canonical final weapon grades")
		c.eq(RunSnapshot.capture(sim), before_preview, "trait focus cannot mutate the model")
		button.pressed.emit()
		ui.flush_feedback()
		var merged: EchoTake = sim.bank.takes[0]
		var profile := ui.transaction_profile()
		c.eq(profile["after"][0]["trait"], merged.merge_trait, "trait follows the actual committed result")
		c.near(profile["after"][0]["condition"], merged.condition, 0.0001, "meter is the actual result")
		c.eq(profile["after"][0]["levels"], merged.levels, "grade pips use the resulting build")
		c.eq(profile["after"][0]["skill"], merged.inherited_skill, "seal uses actual inherited skill")
		var before := RunSnapshot.capture(sim)
		profile["after"][0]["levels"].clear()
		c.eq(RunSnapshot.capture(sim), before, "proof snapshots cannot modify the live build")
		ui.undo_button.pressed.emit()
		ui.flush_feedback()
		profile = ui.transaction_profile()
		c.eq([profile["after"][0]["condition"], profile["after"][1]["condition"]], [50.0, 70.0], "Undo shows the two exact original conditions")
		ui.free()


func test_signature_holds_reroll_stock_without_blocking_purchase_departure_or_undo(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var before := RunSnapshot.capture(sim)
	ui.confession_button.pressed.emit()
	ui.confession.choice_buttons[1].pressed.emit()
	c.ok(ui.confession._receipt.text.contains(Loc.t("confession.ui.state_pending")), "signed receipt names its reversible pending state")
	ui.confession.close()
	c.ok(ui.reroll_button.disabled, "actual quote holds paid reroll while its signature is reversible")
	c.eq(ui.reroll_button.tooltip_text, Loc.t("reason.pending_confession"), "held stock explains how to unlock it")
	var signed := RunSnapshot.capture(sim)
	ui._on_reroll()
	c.eq(RunSnapshot.capture(sim), signed, "stale refresh intent cannot destroy the confession undo anchor")
	c.ok(not ui.start_button.disabled, "signed choice does not block departure")
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(sim.player.weapons.size(), 2, "ordinary real purchase remains available while stock is held")
	ui.undo_button.pressed.emit()
	c.ok(ui.reroll_button.disabled, "undoing the later purchase preserves the signed choice")
	ui.undo_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "second main Undo withdraws the signature and its advance")
	c.ok(not ui.reroll_button.disabled, "stock refresh unlocks after actual signature withdrawal")
	ui.free()


func test_actual_inspection_outcomes_and_earlier_act_records_are_visible_and_read_only(c: Check) -> void:
	for registered in [false, true]:
		var sim := _sim()
		var ui := _open(sim)
		ui.confession_button.pressed.emit()
		ui.confession.choice_buttons[1].pressed.emit()
		ui.confession.close()
		ui.start_requested.connect(sim.start_next_wave)
		ui.start_button.pressed.emit()
		c.eq(sim.phase, Sim.Phase.WAVE, "real shop departure commits its inspection")
		if registered:
			sim.player.pos = BureauConfession.TERMINAL_POS
			c.ok(sim.interact(), "actual world terminal registers the copy")
		sim._end_wave()
		ui.open(sim)
		var before := RunSnapshot.capture(sim)
		ui.confession_button.pressed.emit()
		var label := Loc.t("confession.ui.state_verified" if registered else "confession.ui.state_missed")
		c.ok(ui.confession._receipt.text.contains(label), "same-act receipt exposes the real verified or unverified result")
		c.eq(RunSnapshot.capture(sim), before, "reading a completed result cannot verify it or charge money")
		ui.confession.close()
		# Canonical stage skip shortens only setup; the earlier actual choice stays.
		sim.start_wave(4)
		sim._end_wave()
		ui.open(sim)
		before = RunSnapshot.capture(sim)
		ui.confession_button.pressed.emit()
		c.ok(ui.confession._history.visible and ui.confession._history.text.contains(label), "next-act desk keeps previous inspection result visible")
		c.eq(RunSnapshot.capture(sim), before, "past-act history remains a pure model read")
		ui.free()


func test_optional_delivery_is_announced_at_real_shop_entry_without_opening_a_work_order(c: Check) -> void:
	var sim := _sim()
	var before := RunSnapshot.capture(sim)
	var ui := _open(sim)
	c.ok(not ui.workshop.visible and not ui.confession.visible, "ordinary shop opens without any optional terms modal")
	c.ok(ui._prep_status.text.begins_with(Loc.t("bureau.delivery.next_short")), "next delivery is a leading visible header announcement")
	var terms := Loc.t("bureau.delivery.forecast", [BureauEvents.REWARD])
	c.eq(ui.start_button.tooltip_text, terms, "departure button exposes exact eight-material reward and no-failure-fee terms")
	c.eq(ui.start_button.accessibility_description, terms, "keyboard and controller accessibility can read the same event terms")
	c.eq(RunSnapshot.capture(sim), before, "forecast reads no new state or RNG")
	sim.start_wave(2)
	sim._end_wave()
	ui.open(sim)
	c.ok(not ui._prep_status.text.begins_with(Loc.t("bureau.delivery.next_short")), "ordinary next encounter does not keep a stale event prefix")
	c.eq(ui.start_button.tooltip_text, "", "ordinary departure clears the old event terms")
	ui.free()
