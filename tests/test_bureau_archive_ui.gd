extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _take() -> EchoTake:
	var take := EchoTake.new()
	take.wave = 3
	take.condition = 82.0
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(2)
	take.samples = PackedVector2Array([Vector2(200, 300), Vector2(250, 340)])
	return take


func _profile() -> Meta:
	var profile := Meta.new("user://bureau_archive_ui_missing/profile.json")
	profile.echo_archives["looper"] = EchoArchive.encode(_take())
	return profile


func test_family_wall_selects_actual_archives_and_empty_frames_without_mutation(c: Check) -> void:
	var profile := _profile()
	var before := profile.echo_archives.duplicate(true)
	var ui := EchoArchiveUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(profile)
	c.eq(ui.room.role_frames.size(), 5, "the wall has one frame per eligible archive role")
	c.eq(ui._role_buttons, ui.room.role_frames, "existing navigation controls are the actual portrait frames")
	var first := ui.room.role_frames[0] as ArchiveRoomUi.FamilyFrame
	c.ok(first.occupied, "stored archive supplies an actual body in the frame")
	c.eq(first.condition, 82.0, "wall condition describes the stored original")
	c.eq(ui._entry.preview.condition, 60.0, "entry preview still describes actual normalized condition")
	c.ok(ui.toggle_button.has_focus(), "opening retains useful controller inheritance focus")
	var empty: ArchiveRoomUi.FamilyFrame
	for raw: Button in ui.room.role_frames:
		var frame := raw as ArchiveRoomUi.FamilyFrame
		if frame.role_id == &"mirror":
			empty = frame
	if empty != null:
		empty.pressed.emit()
		c.eq(ui.selected, &"mirror", "portrait selection controls the real archive role")
		c.ok(not empty.occupied and not empty.portrait.visible, "empty identity is a clip without a fabricated copy")
		c.ok(ui._entry.preview.is_empty() and not ui._preview.visible, "empty selection cannot retain the prior role's preview")
	c.eq(profile.echo_archives, before, "opening and selecting frames never edits permanent files")
	ui.history_button.pressed.emit()
	c.ok(ui.memory.visible and ui.memory.rows.is_empty(), "history entry exposes actual empty drawer state")
	ui.memory.close_button.pressed.emit()
	c.ok(not ui.memory.visible and ui.history_button.has_focus(), "drawer returns focus to its wall entry")
	ui.close()
	c.ok(not ui.memory.visible and not ui.visible, "session close clears both layers")
	ui.free()


func test_retirement_drawer_is_bounded_factual_paged_and_read_only(c: Check) -> void:
	var profile := _profile()
	for run in 12:
		var retired: Array[Dictionary] = []
		for index in 6:
			retired.append({"uid": index + 1, "wave": 7, "recorded_wave": 2, "weapon_id": "pistol", "reason": "exhausted", "work": index,
				"condition": 0.0, "merged": false})
		profile.bureau_reports.append({"run_id": "archive_ui_%d" % run, "character_id": "looper", "stage": 12, "ending": "takeover", "rescued": 2,
			"repairs": 1, "staff_uid": 17, "retired": retired})
	var before := profile.bureau_reports.duplicate(true)
	var ui := ArchiveMemoryUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(profile)
	c.eq(ui.rows.size(), 96, "twelve shifts retain at most one report, staff entry and six retired identities each")
	c.eq(ui.row_buttons.size(), 3, "only three actual records occupy each page")
	c.eq(ui.page_count(), 32, "every retained bounded record has a reachable page")
	c.eq(ui.rows[1]["kind"], &"staff", "staff signature remains distinct from retired copies")
	c.eq(ui.rows[2]["kind"], &"retired", "actual exhaustion is labeled as retirement")
	c.ok(ui.rows[2]["detail"].contains(Loc.t("room.retired_work", [0])), "successful key-work count comes from the model")
	c.ok(ui.close_button.has_focus(), "full drawer always exposes an exit")
	ui.row_buttons[2].pressed.emit()
	c.eq(ui.selected_record["kind"], &"retired", "opening a record selects its actual retained identity")
	c.ok(ui.row_buttons[2].button_pressed and not ui.row_buttons[0].button_pressed, "read selection has one visible focus marker")
	ui.show_page(31)
	c.eq(ui.row_buttons.size(), 3, "last page has actual records, no placeholder achievements")
	c.ok(ui.next_button.disabled and not ui.previous_button.disabled, "last page reports its navigation boundary")
	ui.show_page(1000)
	c.eq(ui.page, 31, "page overflow clamps instead of losing records")
	ui.show_page(-1000)
	c.eq(ui.page, 0, "negative page clamps to first actual record")
	c.eq(profile.bureau_reports, before, "reading and paging retain all permanent data exactly")
	ui.reset()
	c.ok(not ui.visible and ui.rows.is_empty(), "detaching the profile removes stale identities")
	ui.free()


func test_vending_prints_only_actual_inherited_body_once_and_never_changes_state(c: Check) -> void:
	var sim := Sim.new(1717)
	var take := _take()
	take.archived = true
	take.condition = 60.0
	sim.bank.add(take)
	sim.start_run()
	var ui := VendingReceiptUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	var before := RunSnapshot.capture(sim)
	c.ok(ui.show_take(take, sim), "actual inherited bank take gets one printed receipt")
	c.eq(ui.printed_uid, take.uid, "receipt carries actual allocated identity")
	c.eq(ui.remaining, 0.7, "printing cannot impose a long presentation delay")
	c.eq(ui.mouse_filter, Control.MOUSE_FILTER_IGNORE, "receipt never captures battle clicks")
	c.ok(not ui.show_take(take, sim), "repeated hookup cannot print the same issued body again")
	ui.set_paused(true)
	ui._process(1.0)
	c.eq(ui.remaining, 0.7, "pause freezes the visual receipt")
	ui.set_paused(false)
	ui.set_reduced_effects(true)
	ui._process(0.2)
	c.eq(ui.modulate.a, 1.0, "reduced effects use a still fully readable receipt")
	ui.skip()
	c.ok(not ui.visible and ui.remaining == 0.0, "skip only closes the presentation")
	c.eq(RunSnapshot.capture(sim), before, "printing, pause and skip never create bodies, restore wear or consume RNG")
	var invalid := _take()
	c.ok(not ui.show_take(invalid, sim), "ordinary unissued record cannot borrow vending identity")
	var daily := Sim.new(1718)
	daily.daily_modifier = DailyAnomaly.FORTUNE
	daily.bank.add(take)
	c.ok(not ui.show_take(take, daily), "Daily cannot announce inherited archive rewards")
	ui.reset()
	c.eq(ui.printed_uid, 0, "new session clears visible receipt identity")
	ui.free()


func test_recorded_work_names_only_canonical_machines_and_stamp_switch(c: Check) -> void:
	c.eq(ArchiveCandidateUi.work_target_name(BureauEvents.SWITCH_ID), Loc.t("interaction.bureau_switch"), "new recorded switch names the actual stamp apparatus")
	c.eq(ArchiveCandidateUi.work_target_name(&"machine_3"), Loc.t("archive.machine", [4]), "ordinary canonical machine keeps its actual index")
	c.eq(ArchiveCandidateUi.work_target_name(&"not_a_machine"), Loc.t("archive.work_target_missing"), "unknown target cannot fabricate Machine1")
