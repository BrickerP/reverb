extends RefCounted


func _sim() -> Sim:
	var sim := Sim.new(5151)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 500
	sim.shop.offers.clear()
	return sim


func _open(sim: Sim, familiar: Array[StringName] = [], extent: Vector2i = Vector2i(1280, 720)) -> ShopUi:
	var viewport := SubViewport.new()
	viewport.size = extent
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	viewport.add_child(ui)
	ui.set_familiar_actions(familiar)
	ui.set_reduced_effects(true)
	ui.open(sim)
	return ui


func _release(ui: ShopUi) -> void:
	ui.get_parent().free()


func _offer(sim: Sim, id: StringName) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(id)
	offer.price = 20
	sim.shop.offers.append(offer)
	return offer


func _take(sim: Sim, condition: float) -> EchoTake:
	var take := EchoTake.new()
	take.wave = sim.wave
	take.condition = condition
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.samples = PackedVector2Array([Vector2(200, 200), Vector2(300, 250)])
	sim.bank.add(take)
	return take


func test_mouse_sweep_has_no_sheet_but_deliberate_hover_and_focus_can_read(c: Check) -> void:
	var sim := _sim()
	_offer(sim, &"smg")
	_offer(sim, &"rifle")
	var ui := _open(sim)
	var first := ui.offers_box.get_child(0) as OfferCard
	var second := ui.offers_box.get_child(1) as OfferCard
	first.size = Vector2(250, 90)
	second.size = Vector2(250, 90)
	var before := RunSnapshot.capture(sim)
	ui.inspection.pointer_enabled = true
	ui._inspection_hover(first)
	ui._step_hover(0.08, first.get_global_rect().get_center())
	c.ok(not ui.inspection.visible, "crossing stock does not immediately open prose")
	ui._inspection_hover(second)
	ui._step_hover(0.09, second.get_global_rect().get_center())
	c.ok(not ui.inspection.visible, "new target receives its own intent window")
	ui._step_hover(0.08, second.get_global_rect().get_center())
	c.eq(ui.inspection.title_label.text, Loc.weapon_name(&"rifle"), "stable hover inspects only the intended stock")
	ui.inspection.focus_enabled = true
	ui._inspection_focus(first)
	c.eq(ui.inspection.title_label.text, Loc.weapon_name(&"smg"), "controller focus is immediate")
	ui._request_inspection(first, true)
	ui.inspection.rule_buttons[0].focus_entered.emit()
	ui.inspection.rule_buttons[0].grab_focus()
	ui.inspection._process(30.0)
	c.ok(ui.inspection.pinned and ui.inspection.definition.visible, "reading an active tertiary definition has no timeout")
	c.eq(RunSnapshot.capture(sim), before, "reading cannot mutate the run or RNG")
	_release(ui)


func test_hover_leaving_dragging_and_refresh_cancel_pending_intent(c: Check) -> void:
	var sim := _sim()
	_offer(sim, &"smg")
	var ui := _open(sim)
	var card := ui.offers_box.get_child(0) as OfferCard
	card.size = Vector2(250, 90)
	ui.inspection.pointer_enabled = true
	ui._inspection_hover(card)
	ui._step_hover(0.3, Vector2(-1000, -1000))
	c.ok(not ui.inspection.visible, "leaving before intent cancels the pending sheet")
	ui._inspection_hover(card)
	ui.refresh()
	ui._step_hover(1.0, card.get_global_rect().get_center())
	c.ok(not ui.inspection.visible, "a rebuilt source cannot open stale detail")
	_release(ui)


func test_first_echo_is_visible_in_compact_shop_and_only_seen_result_is_learned(c: Check) -> void:
	var sim := _sim()
	var take := _take(sim, 70)
	var ui := _open(sim, [], Vector2i(960, 540))
	var learned: Array[StringName] = []
	ui.familiarity_confirmed.connect(func(action: StringName) -> void: learned.append(action))
	c.ok(ui.echo_panel.visible and not ui.build_panel.visible, "first handoff reveals the actual new copy instead of an unseen tab")
	c.ok(ui.echo_panel._identity_buttons.has(take.uid), "the presented identity is the committed recording")
	ui.show_equipment_page(0)
	ui._step_first_echo(4.0)
	c.ok(learned.is_empty(), "hidden arrival cannot mark the introduction learned")
	ui.show_equipment_page(1)
	ui._step_first_echo(0.5)
	c.eq(learned, [&"first_echo"], "visible settled arrival confirms familiarity once")
	ui._step_first_echo(4.0)
	c.eq(learned.size(), 1, "same arrival is not learned twice")
	_release(ui)
	ui = _open(sim, [&"first_echo"], Vector2i(960, 540))
	c.ok(ui.build_panel.visible and not ui.echo_panel.visible, "familiar entry preserves ordinary equipment browsing")
	_release(ui)


func test_buy_and_fast_undo_show_only_the_final_real_transaction(c: Check) -> void:
	var sim := _sim()
	var offer := _offer(sim, &"smg")
	var ui := _open(sim)
	var learned: Array[StringName] = []
	ui.familiarity_confirmed.connect(func(action: StringName) -> void: learned.append(action))
	var before := ShopState.capture(sim).to_dict()
	ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon")
	ui.flush_feedback()
	var proof := ui.transaction_profile()
	c.eq(proof["before"].size(), 0, "purchase creates no imaginary previous weapon")
	c.eq(proof["after"][0]["id"], &"smg", "purchase points to the actual installed weapon")
	c.ok(learned.is_empty(), "commit alone is not evidence that its presentation was seen")
	ui._on_undo()
	ui.flush_feedback()
	c.eq(ShopState.capture(sim).to_dict(), before, "Undo remains immediate during feedback")
	proof = ui.transaction_profile()
	c.eq(proof["action"], ShopResult.UNDO, "Undo replaces the earlier visual rather than queueing behind it")
	c.eq(proof["before"][0]["id"], &"smg", "reverse proof removes the actual bought weapon")
	c.eq(proof["after"].size(), 0, "reverse proof leaves the actual empty slot")
	if is_instance_valid(ui._change_visual):
		ui._change_visual.step(2.0)
	c.ok(not learned.has(&"buy"), "cancelled purchase presentation cannot teach buy")
	_release(ui)


func test_completed_buy_is_familiar_and_repeated_failure_is_not(c: Check) -> void:
	var sim := _sim()
	var offer := _offer(sim, &"smg")
	var ui := _open(sim)
	var learned: Array[StringName] = []
	ui.familiarity_confirmed.connect(func(action: StringName) -> void: learned.append(action))
	ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon")
	ui.flush_feedback()
	ui._change_visual.size = Vector2(120, 80)
	ui._change_visual.step(1.0)
	c.eq(learned, [&"buy"], "completed visible inventory change confirms the action")
	ui._on_undo()
	ui.flush_feedback()
	c.eq(ui.drag_payload_for(offer), null, "Undo invalidates the old offer object rather than accepting a stale transaction")
	var restored_offer: Offer = (ui.offers_box.get_child(0) as OfferCard).offer
	c.ok(ui.apply_drop(ui.drag_payload_for(restored_offer), &"empty_weapon").ok, "the current restored stock is bought again")
	ui.flush_feedback()
	c.eq(ui.transaction_profile()["action"], ShopResult.BUY, "familiarity is measured on the new purchase, not the preceding Undo")
	c.near(ui._change_visual.duration, 0.12, 0.0001, "familiar reduced feedback is a brief static confirmation")
	ui._change_visual.size = Vector2(120, 80)
	ui._change_visual.step(1.0)
	c.eq(learned.size(), 1, "familiar operations do not emit repeated teaching")
	_release(ui)
	sim = _sim()
	sim.player.materials = 0
	_offer(sim, &"smg")
	ui = _open(sim)
	var before := RunSnapshot.capture(sim)
	for _press in 3:
		(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(ui.vendor_feedback_runs, 1, "same blocked state merges repeated merchant reactions")
	c.eq(ui._footer.text, Loc.t("shop.drop_poor"), "literal resource reason remains readable")
	c.ok(ui.transaction_profile().is_empty(), "failure creates no before-after success ink")
	c.eq(RunSnapshot.capture(sim), before, "spam cannot mutate state")
	_release(ui)


func test_combine_preview_cancel_and_both_donor_orders_use_exact_values(c: Check) -> void:
	for host_index in [0, 1]:
		var sim := _sim()
		sim.player.add_weapon(Content.weapon(&"pistol"))
		var ui := _open(sim)
		var before := ShopState.capture(sim).to_dict()
		ui._open_combine_donors(host_index)
		c.eq(ui.workshop.choice_preview.proof["before"].size(), 2, "preview shows both real weapon bodies")
		c.eq(ui.workshop.choice_preview.proof["after"][0]["level"], 1, "preview uses actual next grade")
		ui.workshop.cancel_button.pressed.emit()
		c.eq(ShopState.capture(sim).to_dict(), before, "cancelling a visible preview is read-only")
		ui._open_combine_donors(host_index)
		ui.workshop.choice_buttons[0].pressed.emit()
		ui.workshop.choice_buttons[0].pressed.emit()
		ui.flush_feedback()
		var proof := ui.transaction_profile()
		c.eq(proof["before"].size(), 2, "committed merge consumes exactly two old-grade bodies")
		c.eq(proof["after"].size(), 1, "committed merge leaves exactly one result")
		c.eq(proof["after"][0]["level"], sim.player.level_at(0), "visible grade comes from committed state")
		c.eq(proof["index"], 0, "donor before host cannot shift feedback onto the wrong slot")
		ui._on_undo()
		ui.flush_feedback()
		c.eq(ShopState.capture(sim).to_dict(), before, "Undo restores both original slot orders and investments")
		c.eq(ui.transaction_profile()["after"].size(), 2, "Undo presents both restored bodies")
		_release(ui)


func test_evolution_preview_uses_selected_branch_and_failed_action_cannot_teach(c: Check) -> void:
	var sim := _sim()
	for _copy in 3:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	var ui := _open(sim)
	var before := ShopState.capture(sim).to_dict()
	ui._on_evolve_weapon(0)
	var targets := sim.shop.evolution_choices(sim, 0)
	c.ok(not targets.is_empty(), "real authored branch is available")
	c.eq(ui.workshop.choice_preview.proof["after"][0]["id"], targets[0], "preview shows the actual branch")
	c.eq(ShopState.capture(sim).to_dict(), before, "branch preview never commits")
	ui.workshop.choice_buttons[0].pressed.emit()
	ui.flush_feedback()
	c.eq(ui.transaction_profile()["after"][0]["id"], sim.player.weapons[0].id, "evolution uses committed new artwork identity")
	ui._on_undo()
	ui.flush_feedback()
	c.eq(ShopState.capture(sim).to_dict(), before, "fast Undo restores original authored weapon")
	ui._clear_change()
	sim.player.materials = 0
	ui.refresh()
	ui._on_evolve_weapon(0)
	c.ok(ui.workshop.choice_buttons[0].disabled, "unaffordable evolution stays a disabled choice")
	c.ok(ui.transaction_profile().is_empty(), "failed evolution cannot produce success feedback")
	_release(ui)


func test_reroll_departure_and_rebind_discard_old_presentation_without_learning(c: Check) -> void:
	var sim := _sim()
	var offer := _offer(sim, &"smg")
	var ui := _open(sim)
	var learned: Array[StringName] = []
	ui.familiarity_confirmed.connect(func(action: StringName) -> void: learned.append(action))
	ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon")
	ui.flush_feedback()
	ui._on_reroll()
	c.ok(ui.transaction_profile().is_empty(), "new stock supersedes the old inventory animation")
	ui._on_upgrade_weapon(0)
	ui.flush_feedback()
	ui._on_start()
	c.ok(ui.transaction_profile().is_empty(), "departure never leaves a delayed transaction in battle")
	c.ok(learned.is_empty(), "unseen interrupted effects do not mark learning")
	var next := _sim()
	ui.open(next)
	sim.shop.undo(sim)
	c.ok(ui.transaction_profile().is_empty(), "old emitter is detached from the new shop")
	_release(ui)


func test_buy_then_undo_before_any_flush_has_one_reverse_slot_feedback(c: Check) -> void:
	var sim := _sim()
	var offer := _offer(sim, &"smg")
	var ui := _open(sim)
	var before := ShopState.capture(sim).to_dict()
	ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon")
	ui._on_undo()
	c.eq(ShopState.capture(sim).to_dict(), before, "same-frame Undo restores the model before any visual flush")
	ui.flush_feedback()
	c.eq(ui.build_panel.empty_drop_target.feedback_runs, 1, "superseded installation cannot flash before the final reverse")
	c.ok(ui.build_panel.empty_drop_target.last_feedback_reverse, "only the final actual direction remains")
	c.eq(ui.transaction_profile()["action"], ShopResult.UNDO, "causal ink also shows only the final state")
	_release(ui)


func test_settled_transaction_remains_available_in_existing_hover(c: Check) -> void:
	var sim := _sim()
	var offer := _offer(sim, &"smg")
	var ui := _open(sim)
	ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon")
	ui.flush_feedback()
	ui._change_visual.size = Vector2(120, 80)
	ui._change_visual.step(1.0)
	ui._request_inspection(ui.build_panel._slot_buttons[1], true)
	c.eq(ui.inspection._payload["change"]["after"][0]["id"], &"smg", "a missed short effect is recoverable at its actual item")
	var before := RunSnapshot.capture(sim)
	ui.inspection._payload["change"]["after"][0]["level"] = 99
	c.eq(RunSnapshot.capture(sim), before, "revisiting proof has no mutable model reference")
	_release(ui)


func test_signature_entry_follows_introduction_but_keeps_existing_receipts_reachable(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	c.ok(not BureauConfession.profile(sim)["introduced"], "ordinary first shop has no introduced signature")
	c.ok(not ui.confession_button.visible, "unintroduced signature has no premature entry")
	ui._open_confession()
	c.ok(not ui.confession.visible, "direct opening cannot create an empty choices page")
	StoryLedger.seed_known(sim, [&"carbon"])
	ui.refresh()
	c.ok(ui.confession_button.visible, "known carbon introduces the actual entry")
	ui.confession_button.pressed.emit()
	c.ok(ui.confession.visible and ui.confession.choice_buttons.size() == 2, "introduced entry has actual choices")
	ui.confession.choice_buttons[1].pressed.emit()
	c.ok(not BureauConfession.profile(sim)["available"], "canonical signature consumes this act's choice")
	ui.confession.close()
	ui._open_confession()
	c.ok(ui.confession.visible and ui.confession_button.visible, "existing receipt stays reachable even when new signing is unavailable")
	_release(ui)


func test_960_blocked_evolution_preserves_cancel_and_read_only_details(c: Check) -> void:
	var previous := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		for poor in [false, true]:
			var sim := _sim()
			if poor:
				for _copy in 2:
					sim.player.add_weapon(Content.weapon(&"pistol"))
				sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
				sim.player.materials = 0
			var ui := _open(sim, [], Vector2i(960, 540))
			var before := RunSnapshot.capture(sim)
			ui.build_panel._slot_buttons[0].pressed.emit()
			ui.inspection.details_button.pressed.emit()
			ui.workshop.choice_buttons[2].pressed.emit()
			ui.workshop._fit_preview_budget()
			c.ok(ui.workshop.choice_buttons.all(func(button: Button) -> bool: return button.disabled), "both canonical branches expose the real blocking condition")
			c.ok(ui.workshop.choice_preview.custom_minimum_size.y <= 88.0, "blocked diagrams reserve the compact action budget")
			var paper := ui.workshop._content.get_parent() as PanelContainer
			var required: float = ui.workshop._content.get_combined_minimum_size().y + paper.get_theme_stylebox("panel").get_minimum_size().y + 48.0
			c.ok(required <= 540.0, "blocked branches and Cancel fit the actual 540p sheet minimum")
			c.ok(ui.workshop.cancel_button.custom_minimum_size.y >= 38.0, "Cancel keeps its full action target")
			var target: StringName = sim.shop.evolution_choices(sim, 0)[0]
			c.ok(ui.workshop.choice_buttons[0].accessibility_description.contains(Loc.weapon_desc(target)), "compact primary choices retain complete mechanics on inspection")
			c.eq(RunSnapshot.capture(sim), before, "blocked evolution entry never changes the run")
			ui.workshop.cancel_button.pressed.emit()
			while sim.player.weapons.size() < 3:
				sim.player.add_weapon(Content.weapon(&"pistol"))
			sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
			sim.player.materials = 500
			ui.refresh()
			ui._on_evolve_weapon(0)
			ui.workshop._fit_preview_budget()
			c.ok(ui.workshop.choice_buttons.all(func(button: Button) -> bool: return not button.disabled), "meeting the real requirements makes both branches available")
			c.near(ui.workshop.choice_preview.custom_minimum_size.y, 168.0, 0.001, "a new affordable sheet restores its large diagram instead of inheriting the blocked limit")
			_release(ui)
	Loc.lang = previous
