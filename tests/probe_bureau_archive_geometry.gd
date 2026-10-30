extends SceneTree

var _output := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.is_empty():
		DirAccess.make_dir_recursive_absolute(_output)
	await process_frame
	var check := Check.new()
	for language in ["en", "zh"]:
		Loc.lang = language
		for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = extent
			root.content_scale_size = extent
			check.begin("bureau_archive_%s_%d" % [language, extent.x])
			await _case(check, extent)
	print("Results: %d passed, %d failed" % [check.passed, check.failed])
	quit(1 if check.failed > 0 else 0)


func _settle() -> void:
	for _frame in 4:
		await process_frame


func _bounds(check: Check, surface: Control, extent: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(extent)).grow(1.0)
	for node: Control in surface.find_children("*", "Control", true, false):
		if node.is_visible_in_tree() and (node is Label or node is BaseButton or node is TextureRect):
			check.ok(bounds.encloses(node.get_global_rect()), "%s stays inside %s" % [node.get_class(), extent])


func _capture(name_value: String, check: Check, extent: Vector2i) -> void:
	if _output.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	var capture := root.get_texture().get_image()
	check.eq(capture.get_size(), extent, "capture uses the actual native canvas")
	check.eq(capture.save_png(_output.path_join("%s-%s-%d.png" % [name_value, Loc.lang, extent.x])), OK, "rendered archive surface saves")


func _case(check: Check, extent: Vector2i) -> void:
	var profile := Meta.new("user://bureau_geometry_missing/profile.json")
	var take := EchoTake.new()
	take.condition = 42.0
	take.wave = 3
	take.weapons.append(Content.weapon(&"repair_kit"))
	take.levels.append(3)
	take.samples = PackedVector2Array([Vector2(200, 200), Vector2(210, 210), Vector2(250, 300)])
	profile.echo_archives["looper"] = EchoArchive.encode(take)
	for index in 12:
		profile.bureau_reports.append({"run_id": "geometry_%d" % index, "character_id": "looper", "stage": 12,
			"ending": "takeover", "rescued": 12, "repairs": 5, "staff_uid": 18,
			"retired": [{"uid": 17, "wave": 9, "recorded_wave": 5, "weapon_id": "paper_seed", "reason": "exhausted", "work": 3, "condition": 0.0, "merged": true}]})
	var before := profile.bureau_reports.duplicate(true)
	var archive := EchoArchiveUi.new()
	archive.theme = UiTheme.build()
	root.add_child(archive)
	archive.open(profile)
	await _settle()
	check.ok(archive._paper.get_combined_minimum_size().y <= float(extent.y), "family wall and actual entry preview fit native height")
	_bounds(check, archive, extent)
	for button: Button in archive.room.role_frames:
		button.grab_focus()
		button.pressed.emit()
		await _settle()
		check.ok(Rect2(Vector2.ZERO, Vector2(extent)).encloses(button.get_global_rect()), "every archived or empty portrait is reachable")
	archive.room.role_frames[0].pressed.emit()
	await _settle()
	await _capture("family-wall", check, extent)
	archive.history_button.pressed.emit()
	await _settle()
	check.eq(archive.memory.rows.size(), 36, "actual twelve reports expose their report, staff and retirement rows")
	_bounds(check, archive.memory, extent)
	await _capture("records-drawer", check, extent)
	archive.memory.show_page(archive.memory.page_count() - 1)
	await _settle()
	_bounds(check, archive.memory, extent)
	check.ok(archive.memory.row_buttons[0].has_focus(), "paging gives controller an actual record")
	await _capture("records-last-page", check, extent)
	archive.memory.close_button.pressed.emit()
	check.ok(archive.history_button.has_focus(), "drawer returns to its wall entry")
	check.eq(profile.bureau_reports, before, "all native browsing leaves the permanent report untouched")
	archive.free()
	var sim := Sim.new(1701)
	var inherited := EchoArchive.load(profile, &"looper", sim)
	sim.bank.add(inherited)
	sim.start_run()
	var state := RunSnapshot.capture(sim)
	var vending := VendingReceiptUi.new()
	vending.theme = UiTheme.build()
	root.add_child(vending)
	vending.show_take(inherited, sim)
	vending._process(0.32)
	vending.set_paused(true)
	await _settle()
	_bounds(check, vending, extent)
	check.ok(vending._machine.get_global_rect().encloses(vending._portrait.get_global_rect()), "issued body unfolds within the actual machine bay")
	check.ok(vending._panel.get_global_rect().end.y < WorldArena.display_viewport(Vector2(extent)).end.y, "printing remains above the bottom control strip: %s / %s" % [vending._panel.get_global_rect(), WorldArena.display_viewport(Vector2(extent))])
	await _capture("issued-copy", check, extent)
	vending.skip()
	check.eq(RunSnapshot.capture(sim), state, "native printing and skipping cannot add another copy or alter wear/RNG")
	vending.free()
