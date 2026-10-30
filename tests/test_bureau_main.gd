extends RefCounted

const Fixture := preload("res://tests/test_closeout_main.gd")


func test_actual_inheritance_print_is_read_only_pauses_and_detaches(c: Check) -> void:
	var fixture := Fixture.new()
	var main := fixture._main()
	main.new_run(17001, &"looper")
	var original := fixture._take(main.sim, &"pistol", 1)
	original.wave = 12
	c.ok(EchoArchive.store(main.meta, &"looper", original), "real profile contains a retained original")
	main.new_run(17002, &"looper")
	c.eq(main.sim.bank.takes.size(), 1, "inheritance creates exactly one canonical copy")
	var inherited: EchoTake = main.sim.bank.takes[0]
	c.eq(main.vending_ui.printed_uid, inherited.uid, "Main prints the actual inherited body after its UID exists")
	c.ok(main.vending_ui.visible, "new-run entry exposes the vending beat")
	var before := RunSnapshot.capture(main.sim)
	main._unhandled_input(fixture._key(KEY_P))
	var remaining: float = main.vending_ui.remaining
	main.vending_ui._process(0.4)
	c.eq(main.vending_ui.remaining, remaining, "Main pause freezes printing")
	main.vending_ui.skip()
	c.eq(RunSnapshot.capture(main.sim), before, "pause and skip cannot issue another body or reset wear")
	main.show_select()
	c.ok(not main.vending_ui.visible and main.vending_ui.printed_uid == 0, "returning to title detaches the print")
	main.new_run(17003, &"looper", 0, DailyAnomaly.FORTUNE)
	c.ok(main.sim.bank.takes.is_empty() and not main.vending_ui.visible, "Daily cannot print or inherit an archive")
	fixture._dispose(main)


func test_pending_confession_main_save_undo_and_departure_commit(c: Check) -> void:
	var fixture := Fixture.new()
	var main := fixture._main()
	fixture._shop_after_recording(main)
	var take: EchoTake = main.sim.bank.takes[0]
	take.condition = 70.0
	main.shop_ui.confession_button.pressed.emit()
	c.ok(main.shop_ui.confession.visible, "actual shop entry opens the copier")
	main.shop_ui.confession.choice_buttons[0].pressed.emit()
	c.near(take.condition, 82.0, 0.001, "actual truth control restores the quoted body")
	c.ok(not main.meta.story_clues.has(&"confession_truth"), "reading and signing a reversible record do not discover a permanent clue")
	var signed := RunSnapshot.capture(main.sim)
	main._unhandled_input(fixture._key(KEY_ESCAPE))
	c.ok(not main.shop_ui.confession.visible and not main.paused, "cancel leaves the real shop ready")
	main.toggle_pause()
	c.ok(main.save_and_return(), "Shop pending signature can save and return")
	c.ok(not main.meta.story_clues.has(&"confession_truth"), "saving a pending choice cannot farm permanent testimony")
	c.ok(main.continue_run(), "real Continue restores signed Shop")
	c.eq(RunSnapshot.capture(main.sim), signed, "pending choice and Undo graph restore exactly")
	main.shop_ui.undo_button.pressed.emit()
	c.ok(main.sim.expedition["bureau"]["confessions"].is_empty(), "actual main-Shop Undo removes the pending signature")
	c.near(main.sim.bank.takes[0].condition, 70.0, 0.001, "Undo restores the previous condition")
	main.shop_ui.confession_button.pressed.emit()
	main.shop_ui.confession.choice_buttons[0].pressed.emit()
	main.shop_ui.confession.return_button.pressed.emit()
	main.shop_ui.start_button.pressed.emit()
	c.eq(main.sim.phase, Sim.Phase.WAVE, "real departure commits the selected testimony")
	c.ok(Meta.new(main.meta.path).story_clues.has(&"confession_truth"), "Main persists only the committed clue")
	fixture._dispose(main)


func test_early_inherited_retirement_persists_one_report_and_nested_memory_focus(c: Check) -> void:
	var fixture := Fixture.new()
	var main := fixture._main()
	main.new_run(17004, &"looper")
	var original := fixture._take(main.sim, &"pistol", 1)
	original.wave = 12
	c.ok(EchoArchive.store(main.meta, &"looper", original), "archive original keeps its original encounter")
	main.new_run(17005, &"looper")
	main._unhandled_input(fixture._key(KEY_SPACE))
	var release := fixture._key(KEY_SPACE)
	release.pressed = false
	main._input(release)
	c.eq(main.sim.expedition["bureau"]["retired"].size(), 1, "actual retirement input records the issued identity")
	c.ok(RunSnapshot.restore(RunSnapshot.capture(main.sim)) != null, "cross-run original stage does not invalidate the current run")
	fixture._lose(main)
	var profile := Meta.new(main.meta.path)
	c.eq(profile.bureau_reports.size(), 1, "Main records one terminal shift report")
	if not profile.bureau_reports.is_empty():
		c.eq(profile.bureau_reports[0]["retired"][0]["recorded_wave"], 12, "report retains original recording chronology")
		c.eq(profile.bureau_reports[0]["retired"][0]["wave"], 1, "report retains actual retirement chronology")
	main._record_run()
	c.eq(Meta.new(main.meta.path).bureau_reports.size(), 1, "duplicate completion cannot create another report")
	main.show_select()
	main.open_echo_archive()
	main.echo_archive_ui.history_button.pressed.emit()
	c.ok(main.echo_archive_ui.memory.visible, "title archive reaches the persisted report drawer")
	main._unhandled_input(fixture._key(KEY_ESCAPE))
	c.ok(main.echo_archive_ui.visible and not main.echo_archive_ui.memory.visible, "first cancel returns to the family wall")
	c.ok(main.echo_archive_ui.history_button.has_focus(), "nested cancel restores its entry focus")
	main._unhandled_input(fixture._key(KEY_ESCAPE))
	c.ok(main.character_select.visible and not main.echo_archive_ui.visible, "second cancel returns to title")
	fixture._dispose(main)


func test_real_delivery_input_has_one_confirmation_and_preserves_old_machine_cue(c: Check) -> void:
	var fixture := Fixture.new()
	var main := fixture._main()
	main.new_run(17006, &"solo")
	main.sim.start_wave(2)
	main.sim._plan.clear()
	var count: int = main.audio.play_count(&"equipment_apply")
	var delivered := [0]
	main.sim.world_event.connect(func(info: Dictionary) -> void:
		if info.get("kind") == &"dispatch_delivered": delivered[0] += 1)
	main.sim.player.pos = BureauEvents.PICKUP
	main._unhandled_input(fixture._key(KEY_E))
	c.eq(main.sim.expedition["bureau"]["delivery"]["state"], &"carrying", "real E picks up the document")
	main.sim.player.pos = BureauEvents.INBOX
	main._unhandled_input(fixture._key(KEY_E))
	c.eq(main.sim.expedition["bureau"]["delivery"]["state"], &"delivered", "real E commits the delivery")
	c.eq(main.audio.play_count(&"equipment_apply"), count + 1, "model event owns exactly one delivery confirmation")
	main._unhandled_input(fixture._key(KEY_E))
	c.eq(delivered[0], 1, "contextual repeat cannot emit another delivery success")
	var before_machine: int = main.audio.play_count(&"equipment_apply")
	var recycler: Dictionary = {}
	for item: Dictionary in main.sim.interactables:
		if item["kind"] == &"recycler":
			recycler = item
	if not recycler.is_empty():
		recycler["cooldown"] = 0.0
		main.sim.player.pos = recycler["pos"]
		main._unhandled_input(fixture._key(KEY_E))
		c.eq(main.audio.play_count(&"equipment_apply"), before_machine + 1, "existing machine interaction retains its one generic cue")
	fixture._dispose(main)
