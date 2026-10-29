extends RefCounted

const HISTORY_PATH := "user://test_organic_archives_runs.jsonl"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(HISTORY_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_history_moves_from_empty_state_to_an_actionable_record(c: Check) -> void:
	_cleanup()
	var history := HistoryUi.new()
	history.theme = UiTheme.build()
	_root().add_child(history)
	var log := RunLog.new(HISTORY_PATH)
	history.open(log)
	c.ok(history._empty.visible and not history.archive_scroll.visible,
			"empty archive gives a clear state instead of an empty table")
	c.ok(history.close_button.has_focus(), "empty archive always has an exit")
	var sim := Sim.new(2211)
	sim.start_run()
	sim.phase = Sim.Phase.LOST
	sim.wave = 9
	sim.daily_modifier = DailyAnomaly.RIFTSTORM
	log.append(sim, &"mirror", 90.0)
	history.open(log)
	c.eq(history.row_count(), 1, "a recorded run appears once")
	c.ok(not history._empty.visible and history.archive_scroll.visible,
			"recorded runs replace the empty illustration")
	c.eq(history.record_panels.size(), history.replay_buttons.size(),
			"each visible record owns a replay action")
	c.ok(history.replay_buttons[0].has_focus(), "the first record is ready for a controller")
	var selected: Array[Dictionary] = []
	history.replay_requested.connect(func(seed_value: int, character: StringName,
			daily: StringName) -> void:
		selected.append({"seed": seed_value, "character": character, "daily": daily}))
	history.replay_buttons[0].pressed.emit()
	c.eq(selected.size(), 1, "record replay emits once")
	if not selected.is_empty():
		c.eq(selected[0]["seed"], 2211, "record keeps its reproducible seed")
		c.eq(selected[0]["character"], &"mirror", "record keeps its character identity")
		c.eq(selected[0]["daily"], DailyAnomaly.RIFTSTORM, "daily replay preserves its historical anomaly")
	history.close()
	c.ok(not history.visible, "close leaves the archive")
	history.free()
	_cleanup()


func test_history_caps_its_records_and_rebuilds_the_focus_loop(c: Check) -> void:
	_cleanup()
	var log := RunLog.new(HISTORY_PATH)
	for seed_value in range(12):
		var sim := Sim.new(seed_value)
		sim.start_run()
		sim.phase = Sim.Phase.LOST
		log.append(sim, &"looper", 10.0)
	var history := HistoryUi.new()
	history.theme = UiTheme.build()
	_root().add_child(history)
	history.open(log)
	c.eq(history.row_count(), 8, "large archives keep the recent-eight contract")
	c.eq(history.replay_buttons.size(), 8, "all retained records remain replayable")
	var first := history.replay_buttons[0]
	c.eq(first.get_node(first.focus_neighbor_top), history.close_button,
			"controller can leave the top record through Close")
	c.eq(history.close_button.get_node(history.close_button.focus_neighbor_bottom), first,
			"Close wraps to the first retained record")
	history.open(log)
	c.eq(history.record_panels.size(), 8, "reopening does not retain duplicate record shapes")
	history.free()
	_cleanup()


func test_catalog_chapters_keep_every_supply_and_a_clear_visual_hierarchy(c: Check) -> void:
	var previous := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		var catalog := CodexUi.new()
		catalog.theme = UiTheme.build()
		_root().add_child(catalog)
		catalog.open()
		c.eq(catalog.card_count(), Content.weapons().size(), "%s keeps every base and evolved supply" % language)
		c.eq(catalog.chapters.size(), CodexUi.FAMILIES.size(), "%s has one readable chapter per family" % language)
		var featured := 0
		for card: PanelContainer in catalog._cards:
			if bool(card.get_meta(&"featured_supply", false)):
				featured += 1
			var icons := card.find_children("*", "TextureRect", true, false)
			c.eq(icons.size(), 1, "%s gives each supply one identifiable drawing" % language)
		c.eq(featured, CodexUi.FAMILIES.size(), "%s has a limited set of strong visual anchors" % language)
		c.ok(catalog.close_button.has_focus(), "%s catalog never hides the return action" % language)
		c.eq(catalog.close_button.get_node(catalog.close_button.focus_neighbor_bottom),
				catalog.close_button, "%s browsing stays inside the modal" % language)
		catalog.close()
		c.ok(not catalog.visible, "%s Close leaves the catalog" % language)
		catalog.free()
	Loc.lang = previous


func test_feedback_ribbon_reflects_real_write_results_without_losing_the_draft(c: Check) -> void:
	var feedback := FeedbackUi.new()
	feedback.theme = UiTheme.build()
	_root().add_child(feedback)
	feedback.open_for_run("organic-feedback-run", true, false)
	c.ok(not feedback.status_ribbon.visible, "fresh feedback has no invented success or failure")
	feedback.note_edit.text = "The copies were clear. 副本可以看清。"
	feedback.set_submission_result({"ok": false, "reason": "write_failed"})
	c.ok(feedback.status_label.visible and feedback.status_ribbon.visible,
			"a failed write reveals the explanatory ink ribbon")
	c.ok(feedback.note_edit.text.contains("副本"), "write failure retains the actual draft")
	c.ok(not feedback.save_button.disabled, "the player can retry after the failure")
	feedback.set_submission_result({"ok": true, "record": {"run_id": "organic-feedback-run"}})
	c.ok(feedback.status_ribbon.visible and feedback.open_log_button.has_focus(),
			"real success leaves a visible receipt and an available action")
	c.ok(feedback.save_button.disabled and not feedback.note_edit.editable,
			"the saved receipt cannot be submitted twice")
	feedback.reset()
	c.ok(not feedback.status_ribbon.visible and feedback.note_edit.text.is_empty(),
			"a fresh run clears the previous receipt and private draft")
	feedback.free()
