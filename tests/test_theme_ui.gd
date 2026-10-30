extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _shop() -> Sim:
	var sim := Sim.new(1610)
	sim.start_run()
	sim._end_wave()
	sim.player.materials = 13
	sim.expedition["debt"] = 40
	return sim


func test_context_terms_are_read_only_and_errors_stay_inside_active_sheet(c: Check) -> void:
	var sim := Sim.new(1611)
	sim.start_wave(12)
	sim._end_wave()
	var ui := ContextChoiceUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	var before := RunSnapshot.capture(sim)
	ui.open_context("exit.title", "exit.body", Expedition.exit_options(sim), true)
	c.ok(ui.visible and ui.save_button.visible, "resolution offers visible save action")
	c.eq(ui.choice_buttons.size(), 3, "all three explicit exit alternatives remain visible")
	c.eq(RunSnapshot.capture(sim), before, "reading terms cannot choose an ending")
	ui.show_error("A test disk error")
	c.ok(ui._error.visible and ui._error.text == "A test disk error", "save failure appears above choices rather than behind modal")
	var selected: Array[StringName] = []
	ui.chosen.connect(func(id: StringName) -> void: selected.append(id))
	ui.choice_buttons[2].pressed.emit()
	c.eq(selected, [&"takeover"], "choice delegates exactly one id to the authoritative main flow")
	c.ok(ui.visible, "view remains open until main validates the choice")
	c.eq(RunSnapshot.capture(sim), before, "choice view cannot mutate authoritative result")
	var closed: Array[bool] = []
	ui.closed.connect(func() -> void: closed.append(true))
	ui.close()
	c.eq(closed.size(), 1, "return emits one pause-menu navigation signal")
	c.eq(sim.phase, Sim.Phase.RESOLUTION, "return never silently chooses or declines")
	ui.open_context("exit.title", "exit.body", Expedition.exit_options(sim), true)
	c.ok(not ui._error.visible, "new context clears stale save error")
	ui.reset()
	c.eq(closed.size(), 1, "session detach silently resets without navigation")
	ui.free()


func test_debt_ledger_discloses_partial_payment_and_undo_from_real_shop_entry(c: Check) -> void:
	var sim := _shop()
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	var before := RunSnapshot.capture(sim)
	ui.debt_button.pressed.emit()
	c.ok(ui.workshop.visible, "actual shop ledger entry opens terms")
	c.eq(RunSnapshot.capture(sim), before, "opening ledger does not pay or change RNG")
	c.ok(not ui.workshop.choice_buttons[0].disabled, "affordable partial repayment is enabled")
	c.eq(ui.workshop.choice_buttons[0].text, Loc.t("debt.confirm", [13]), "confirmation states exact affordable amount")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(sim.player.materials, 0, "repayment spends stated materials")
	c.eq(sim.expedition["debt"], 27, "repayment reduces actual balance without a fee")
	c.ok(ui.workshop.choice_buttons[0].disabled, "empty wallet cannot make another payment")
	c.eq(ui.workshop.choice_buttons.size(), 1, "ledger never disguises unrelated transaction undo as repayment undo")
	ui.workshop.close()
	c.eq(_root().gui_get_focus_owner(), ui.debt_button, "cancel restores visible ledger focus")
	ui.undo_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "main shop undo restores cash debt world and every shop field")
	ui.free()


func test_no_debt_and_zero_cash_have_clear_bounded_ledger_states(c: Check) -> void:
	var sim := _shop()
	sim.expedition["debt"] = 0
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	ui.debt_button.pressed.emit()
	c.ok(ui.workshop.choice_buttons[0].disabled, "settled ledger cannot charge cash")
	c.eq(sim.player.materials, 13, "clear ledger preserves cash")
	ui.workshop.close()
	sim.expedition["debt"] = 40
	sim.player.materials = 0
	ui.refresh()
	ui.debt_button.pressed.emit()
	c.ok(ui.workshop.choice_buttons[0].disabled, "zero funds explain repayment block")
	c.eq(sim.expedition["debt"], 40, "reading blocked ledger cannot forgive debt")
	ui.free()


func test_real_worker_health_uses_live_world_state_between_cached_art_events(c: Check) -> void:
	var sim := Sim.new(1612)
	sim.start_run()
	var cached := Expedition.world_profile(sim)
	var target: Dictionary = {}
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			target = item
	var worker := Expedition._worker(sim, target["id"])
	worker["hp"] = 9.0
	var profile := ExpeditionInk.target_profile(sim, target, WorldArena.camera_rect(target["pos"]), {}, cached)
	c.near(profile["protected_hp"], 0.2, 0.0001, "danger health bar follows contact damage even without a world event")
	c.eq(cached["workers"][0]["hp"], 45.0, "render lookup leaves cached world art snapshot immutable")


func test_world_visuals_and_work_cues_are_bounded_read_only_and_reset_on_detach(c: Check) -> void:
	var sim := Sim.new(1613)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var before := RunSnapshot.capture(sim)
	for index in 30:
		view._on_echo_work({"uid": 1 + index % 10, "kind": &"press", "pos": sim.player.pos,
			"target_pos": sim.player.pos + Vector2(10, 0), "success": index % 2 == 0, "reason": &"unavailable"})
	c.eq(view._work_marks.size(), ArenaView.MAX_WORK_MARKS, "many echoes cannot exceed eight active notes")
	view._on_echo_work({"uid": 10, "kind": &"signature", "pos": sim.player.pos,
		"target_pos": sim.player.pos + Vector2.RIGHT, "success": true, "reason": &"performed"})
	var same_owner := 0
	for mark: Dictionary in view._work_marks:
		if mark["uid"] == 10:
			same_owner += 1
	c.eq(same_owner, 1, "same worker replaces its old note instead of hiding the arena under labels")
	var depot := RecyclingDepot.new()
	depot.set_world_profile(Expedition.world_profile(sim))
	c.eq(depot.world_presentation()["act_id"], 1, "arrival visuals use real first act")
	c.ok(RecyclingDepot.production_profile(1)["loose_forms"], "arrival exposes loose forms")
	c.ok(RecyclingDepot.production_profile(2)["sorted_stacks"], "processing exposes sorted stacks")
	c.ok(RecyclingDepot.production_profile(3)["shredder_open"], "disposal exposes open shredder")
	c.eq(RunSnapshot.capture(sim), before, "preparing world and Echo art cannot alter gameplay or randomness")
	view.unbind()
	c.ok(view._work_marks.is_empty() and view._world_profile.is_empty(), "detach clears all old run notes and world memory")
	view.free()
	depot.free()


func test_order_terms_can_be_declined_without_mutation_and_restore_offer_focus(c: Check) -> void:
	var sim := _shop()
	var offer := Offer.new()
	offer.contract = AnomalyContract.create(AnomalyContract.SALVAGE, sim.next_wave_number())
	offer.price = offer.contract.deposit
	sim.shop.offers[0] = offer
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	var before := RunSnapshot.capture(sim)
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.ok(ui.workshop.visible, "order purchase requires concrete terms to be read first")
	ui.workshop.cancel_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "canceling responsibility cannot create a fault spend funds or change RNG")
	c.eq(_root().gui_get_focus_owner(), ui.offers_box.get_child(0), "canceling terms returns to its actual offer")
	ui.free()


func test_safe_worker_roster_action_uses_real_aid_and_undo(c: Check) -> void:
	var sim := Sim.new(1614)
	sim.start_run()
	var rescue: Dictionary = {}
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			rescue = item
	sim.player.pos = rescue["pos"]
	c.ok(sim.interact(), "fixture saves a real endangered worker")
	sim._end_wave()
	sim.player.hp = 1.0
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	ui.crew_button.pressed.emit()
	var before := RunSnapshot.capture(sim)
	c.eq(ui.crew.action_buttons.size(), 1, "unsigned bosses have no fake deployment action; saved worker is present")
	ui.crew.action_buttons[0].pressed.emit()
	c.eq(sim.player.hp, 7.0, "real roster entry grants exactly the stated first-aid benefit")
	c.ok(ui.crew.action_buttons[0].disabled, "same worker cannot repeat a consumed first-aid visit")
	ui.crew.undo_button.pressed.emit()
	c.eq(RunSnapshot.capture(sim), before, "roster undo restores person aid health story and history exactly")
	ui.crew.close()
	c.eq(_root().gui_get_focus_owner(), ui.crew_button, "return restores the accessible roster entry")
	ui.free()


func test_roster_records_real_worker_copy_and_self_witnesses_without_inventing_aid(c: Check) -> void:
	var sim := Sim.new(1615)
	sim.start_run()
	var worker: Dictionary = sim.expedition["world"]["workers"][0]
	sim.player.pos = worker["pos"]
	c.ok(sim.interact(), "real worker fixture is rescued")
	sim._end_wave()
	worker["testimony_used"] = true
	var uid := sim.bank.takes[0].uid
	sim.expedition["world"]["witnesses"].append(StringName("copy_%d" % uid))
	sim.expedition["world"]["witnesses"].append(&"self")
	var before := RunSnapshot.capture(sim)
	var crew := CrewUi.new()
	crew.theme = UiTheme.build()
	_root().add_child(crew)
	crew.open_crew(sim)
	c.eq(crew.witness_labels.size(), 3, "one real worker one copy and self all have visible records")
	c.ok(crew.witness_labels[0].text.contains(Loc.t("crew.testimony_used")), "worker record states actual consumed testimony")
	c.eq(crew.witness_labels[1].get_meta(&"witness_id"), StringName("copy_%d" % uid), "copy registry keeps its actual stable UID")
	c.ok(crew.witness_labels[1].text.contains(Loc.t("crew.witness_copy_condition", [ceili(sim.bank.takes[0].condition)])), "stored copy record displays actual condition")
	c.eq(crew.witness_labels[2].get_meta(&"witness_id"), &"self", "personal witness is a distinct record")
	c.eq(crew.witness_labels[2].focus_mode, Control.FOCUS_ALL, "controller can navigate informational registry to the end")
	c.eq(RunSnapshot.capture(sim), before, "roster reading cannot consume witnesses or mutate game state")
	sim.bank.takes.clear()
	crew.open_crew(sim)
	c.ok(crew.witness_labels[1].text.contains(Loc.t("crew.witness_copy_retained")), "retired copy leaves its identity record without pretending the body still plays")
	crew.free()
