extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _take(sim: Sim, condition: float = 40.0) -> EchoTake:
	var take := EchoTake.new()
	take.wave = 1
	take.samples = PackedVector2Array([Vector2(700, 600), Vector2(760, 600)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	take.condition = condition
	sim.bank.add(take)
	return take


func _lost() -> Sim:
	var sim := Sim.new(2039)
	sim.start_run()
	_take(sim)
	sim.phase = Sim.Phase.LOST
	return sim


func _resolution() -> Sim:
	var sim := Sim.new(2038)
	sim.start_run()
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			sim.player.pos = item["pos"]
			sim.interact()
			break
	sim.start_wave(WaveDirector.FINAL_WAVE)
	sim._end_wave()
	sim.player.materials = 20
	sim.bank.takes[0].condition = 40.0
	_take(sim, 100.0)
	return sim


func test_exit_preview_is_pure_and_matches_each_committed_result(c: Check) -> void:
	for kind: StringName in Expedition.EXIT_IDS:
		var sim := _resolution()
		var before := RunSnapshot.capture(sim)
		var preview := ExitOutcomePortrait.profile(sim, kind)
		c.ok(not before.is_empty() and not preview.is_empty(), "real resolution has a valid preview")
		c.ok(preview["available"], "fixture's actual quoted exit is available")
		c.eq(RunSnapshot.capture(sim), before, "preview never changes cash people copies story or RNG")
		var context := ContextChoiceUi.new()
		context.theme = UiTheme.build()
		_root().add_child(context)
		context.open_context("context.exit.title", "context.exit.body", Expedition.exit_options(sim), true, sim)
		c.eq(context.outcome_previews.size(), 3, "each real option has its objects on the existing sheet")
		c.eq(RunSnapshot.capture(sim), before, "loading outcome artwork is read-only")
		c.ok(sim.choose_exit(kind), "actual simulation accepts the quoted choice")
		var committed := ExitOutcomePortrait.profile(sim, &"", true)
		for field: String in ["cost", "repaired_copies", "survivors", "staff_uid", "debt"]:
			c.eq(committed[field], preview[field], "committed result equals preview %s" % field)
		c.eq(committed["copies"].size(), preview["copies"].size(), "copy artwork never invents an extra copy")
		c.eq(committed["people"], preview["people"], "survivor artwork names the actual people who leave")
		var end := EndUi.new()
		end.theme = UiTheme.build()
		_root().add_child(end)
		end.set_reduced_effects(true)
		end.show_result(sim)
		c.eq(end._outcome.result, committed, "end report depicts actual committed objects")
		c.ok(end._afterword.text.contains(ExitOutcomePortrait.describe(committed)), "end report states actual counts and liabilities")
		context.free()
		end.free()


func test_exit_preview_has_no_fictional_people_when_choices_are_blocked(c: Check) -> void:
	var sim := Sim.new(2040)
	Content.character(&"solo").apply(sim)
	sim.start_wave(WaveDirector.FINAL_WAVE)
	sim._end_wave()
	sim.player.materials = 0
	var before := RunSnapshot.capture(sim)
	var release := ExitOutcomePortrait.profile(sim, &"released")
	var people := ExitOutcomePortrait.profile(sim, &"collective")
	var staff := ExitOutcomePortrait.profile(sim, &"takeover")
	c.ok(not release["available"] and release["cost"] == 12, "unaffordable discharge shows the real fee")
	c.eq(release["copies"], [], "Solo has no invented copy to repair")
	c.ok(not people["available"], "no rescued person means collective exit is blocked")
	c.eq(people["people"], [], "an empty registry stays visually empty")
	c.eq(staff["staff_uid"], 0, "Solo signs as self without a fictional staff Echo")
	c.eq(RunSnapshot.capture(sim), before, "blocked preview leaves exact authoritative state intact")
	c.eq(ExitOutcomePortrait.profile(sim, &"made_up_exit"), {}, "unknown result has no substitute illustration")
	c.eq(ExitOutcomePortrait.profile(sim, &"", true), {}, "uncommitted state cannot pretend to be an ending")


func test_first_archive_focus_reads_without_writing_and_familiar_restart_is_fast(c: Check) -> void:
	var sim := _lost()
	var before := RunSnapshot.capture(sim)
	var ui := EndUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.set_reduced_effects(true)
	ui.set_familiar_actions([])
	ui.show_result(sim)
	c.ok(ui._candidate_ui.detail_button.visible and ui._candidate_ui.detail_button.has_focus(), "first valid archive begins on a safe reading action")
	var selected: Array[EchoTake] = []
	ui.archive_requested.connect(func(take: EchoTake) -> void: selected.append(take))
	for page in 12:
		ui._candidate_ui.detail_button.pressed.emit()
	c.eq(selected, [], "unlimited detail reading never stores a recording")
	c.eq(RunSnapshot.capture(sim), before, "unlimited detail reading leaves the exact run untouched")
	c.eq(ui._familiar_actions, [], "reading does not mark the archive action as completed")
	ui.set_familiar_actions([&"archive"])
	ui.show_result(sim)
	c.ok(ui.restart_button.has_focus(), "a player who really filed before can restart immediately")
	sim.expedition["debt"] = 40
	sim.expedition["credit_taken"] = 1
	ui.set_familiar_actions([])
	ui.show_result(sim)
	c.ok(ui.restart_button.has_focus() and ui.archive_button.disabled, "blocked novice archive retains a valid default action")
	c.eq(ui._archive_note.text, Loc.t("archive.debt"), "familiarity cannot hide a real debt blocker")
	ui.free()


func test_archive_confirmation_defaults_to_keep_and_session_reset_clears_stale_actions(c: Check) -> void:
	var sim := _lost()
	var meta := Meta.new("user://perception_read_only_profile_missing.json")
	meta.echo_archives["looper"] = EchoArchive.encode(_take(sim, 90.0))
	var original := meta.echo_archives.duplicate(true)
	var ui := EndUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.set_reduced_effects(true)
	ui.show_result(sim, "", meta)
	ui.request_archive()
	c.ok(ui.replacement_pending and ui.cancel_button.has_focus(), "comparison defaults to preserving the existing archive")
	var restarts := [0]
	ui.restart_requested.connect(func() -> void: restarts[0] += 1)
	ui.restart_button.pressed.emit()
	c.eq(restarts[0], 0, "underlying restart cannot bypass a pending replacement decision")
	ui._confirmation_rows[0].detail_button.pressed.emit()
	var page := ui._confirmation_rows[0]._page
	ui._apply_layout()
	c.eq(ui._confirmation_rows[0]._page, page, "layout updates preserve unhurried old/new comparison reading")
	ui.cancel_archive()
	c.eq(meta.echo_archives, original, "keeping current archive does not replace it")
	ui.request_archive()
	ui.reset()
	ui.next_button.pressed.emit()
	ui._candidate_ui.detail_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	ui.restart_button.pressed.emit()
	c.ok(not ui.visible and not ui.replacement_pending, "detach clears every pending end-screen action")
	c.eq(ui.candidate_count(), 0, "new session keeps no old candidates")
	c.ok(ui._sim == null and ui._meta == null and ui._entry_sim == null, "old run and profile references are released")
	c.eq(restarts[0], 0, "stale detached controls cannot restart a new session")
	c.eq(meta.echo_archives, original, "stale controls cannot write the old profile")
	ui.show_result(sim)
	c.ok(not ui._confirmation.visible and ui._candidate_ui._page == 0, "reopening starts on a clean page without a stale comparison")
	c.eq(ui.modulate, Color.WHITE, "reduced repeat entry has no stale opening alpha")
	ui.free()


func test_context_resume_and_loss_clear_prior_result_objects_and_old_buttons(c: Check) -> void:
	var sim := _resolution()
	var context := ContextChoiceUi.new()
	context.theme = UiTheme.build()
	_root().add_child(context)
	var choices: Array[StringName] = []
	context.chosen.connect(func(id: StringName) -> void: choices.append(id))
	context.open_context("context.exit.title", "context.exit.body", Expedition.exit_options(sim), true, sim)
	var old_button := context.choice_buttons[2]
	context.show_error("Old error")
	context.reset()
	old_button.pressed.emit()
	c.eq(choices, [], "detached context cannot commit a stale choice")
	c.ok(context._source == null and context.outcome_previews.is_empty() and not context._error.visible, "detaching clears source result art and old error")
	context.open_context("context.exit.title", "context.exit.body", Expedition.exit_options(sim), true, sim)
	old_button.pressed.emit()
	c.eq(choices, [], "a removed button cannot commit after resume rebuilt the rows")
	c.eq(context.outcome_previews.size(), 3, "resume reconstructs current result objects without another panel")
	sim.choose_exit(&"released")
	var ui := EndUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.show_result(sim)
	c.ok(ui._outcome.visible, "victory depicts committed result")
	ui.show_result(_lost())
	c.ok(not ui._outcome.visible and ui._outcome.result.is_empty(), "next loss cannot retain the previous victory objects")
	context.free()
	ui.free()
