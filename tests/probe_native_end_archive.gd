extends SceneTree
# Run directly: native container layout needs actual process frames.
# godot --headless --path . --script tests/probe_native_end_archive.gd


func _initialize() -> void:
	await process_frame
	var check := Check.new()
	check.begin("native_end_report_geometry")
	await _end_report(check)
	check.begin("native_archive_chosen_copy_and_replacement")
	await _selection(check)
	check.begin("native_archive_geometry")
	await _archive(check)
	print("Results: %d passed, %d failed" % [check.passed, check.failed])
	await process_frame
	await process_frame
	quit(1 if check.failed > 0 else 0)


func _root() -> Window:
	return root


func _settle() -> void:
	for _frame in 4:
		await process_frame


func _viewport(extent: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = extent
	_root().add_child(viewport)
	return viewport


func _bounds(c: Check, surface: Control, extent: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(extent)).grow(1.0)
	for label: Label in surface.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			c.ok(bounds.encloses(label.get_global_rect()), "%s text stays inside native %s" % [label.name, extent])
	for button: BaseButton in surface.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree():
			c.ok(bounds.encloses(button.get_global_rect()), "%s stays inside native %s" % [button.name, extent])


func _take(sim: Sim) -> EchoTake:
	var take := EchoTake.new()
	take.wave = 1
	take.samples = PackedVector2Array([Vector2(200, 200), Vector2(1200, 800), Vector2(2200, 500)])
	for id: StringName in [&"pistol", &"smg", &"rifle", &"shotgun"]:
		take.weapons.append(Content.weapon(id))
		take.levels.append(0)
	take.stats = sim.player.stats.copy()
	take.condition = 80.0
	sim.bank.add(take)
	return take


func _end_report(c: Check) -> void:
	var language := Loc.lang
	for lang in ["en", "zh"]:
		Loc.lang = lang
		for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
			var viewport := _viewport(extent)
			var sim := Sim.new(611)
			sim.start_run()
			sim.start_wave(WaveDirector.FINAL_WAVE)
			_take(sim)
			sim.player.materials = 0
			sim.expedition.debt = 40
			sim.expedition.credit_taken = 1
			sim._end_wave()
			c.ok(sim.choose_exit(&"takeover"), "explicit stay ending resolves final battle")
			var ui := EndUi.new()
			ui.theme = UiTheme.build()
			viewport.add_child(ui)
			ui.set_reduced_effects(true)
			ui.show_result(sim, Loc.t("end.unlocked", [", ".join([Loc.character_name(&"solo"), Loc.character_name(&"mirror"), Loc.character_name(&"conductor")])]))
			await _settle()
			c.ok(ui._afterword.text.contains(Loc.t("expedition.ending.takeover")), "real ending remains visible")
			c.ok(ui.archive_button.is_visible_in_tree(), "archive action remains visible even when debt blocks it")
			c.ok(ui.archive_button.disabled, "debt restriction survives responsive layout")
			c.ok(ui._panel.get_combined_minimum_size().y <= float(extent.y), "complete end report fits native canvas height")
			_bounds(c, ui, extent)
			if extent.x == 1280:
				viewport.size = Vector2i(960, 540)
				await _settle()
				_bounds(c, ui, viewport.size)
				c.ok(ui.archive_button.visible and ui.archive_button.disabled, "resize preserves archive restriction and visibility")
				viewport.size = extent
				await _settle()
				_bounds(c, ui, extent)
			viewport.free()
	Loc.lang = language


func _archive(c: Check) -> void:
	var language := Loc.lang
	for lang in ["en", "zh"]:
		Loc.lang = lang
		for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
			var path := "user://native_archive_%d_%s_%d.json" % [OS.get_process_id(), lang, extent.x]
			var sim := Sim.new(612)
			sim.start_run()
			var meta := Meta.new(path)
			c.ok(EchoArchive.store(meta, &"looper", _take(sim)), "canonical archive fixture persists")
			var viewport := _viewport(extent)
			var ui := EchoArchiveUi.new()
			ui.theme = UiTheme.build()
			viewport.add_child(ui)
			ui.open(meta)
			await _settle()
			c.ok(ui._preview._points.size() >= 2, "saved route has visible drawable segments")
			c.ok(ui._preview.custom_minimum_size.y >= 80.0, "route preview retains an authored readable area")
			c.ok(ui._paper.get_combined_minimum_size().y <= float(extent.y), "complete archive fits native canvas height")
			_bounds(c, ui, extent)
			if extent.x == 1280:
				var archive_before := meta.echo_archives.duplicate(true)
				viewport.size = Vector2i(960, 540)
				await _settle()
				_bounds(c, ui, viewport.size)
				c.eq(meta.echo_archives, archive_before, "responsive route preview never mutates the stored archive")
				viewport.size = extent
				await _settle()
				_bounds(c, ui, extent)
			viewport.free()
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Loc.lang = language


func _selection(c: Check) -> void:
	var language := Loc.lang
	for lang in ["en", "zh"]:
		Loc.lang = lang
		for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
			var path := "user://native_archive_select_%d_%s_%d.json" % [OS.get_process_id(), lang, extent.x]
			var meta := Meta.new(path)
			var sim := Sim.new(915)
			sim.start_run()
			var original := _take(sim)
			original.levels = [3, 3, 3, 3]
			c.ok(EchoArchive.store(meta, &"looper", original), "existing archive saved")
			var chosen := EchoTake.new()
			chosen.wave = 3
			chosen.samples = PackedVector2Array([Vector2(800, 600), Vector2(802, 601)])
			chosen.inherited_skill = &"arc"
			chosen.condition = 48.0
			for id: StringName in [&"guard_decoy", &"repair_kit", &"paper_seed", &"paper_hound", &"debt_sentry", &"pistol"]:
				chosen.weapons.append(Content.weapon(id))
				chosen.levels.append(3)
			chosen.work_actions = [{"time": 0.0, "kind": &"press", "target_id": &"machine_0", "pos": chosen.samples[0], "weapon_id": &"", "aim": Vector2.ZERO}]
			# Ensure raw DPS is deliberately lower while utility/route/skill remain valuable.
			chosen.stats.values[Stats.DAMAGE_PCT] = -0.8
			sim.bank.add(chosen)
			sim.phase = Sim.Phase.LOST
			var viewport := _viewport(extent)
			var ui := EndUi.new()
			ui.theme = UiTheme.build()
			viewport.add_child(ui)
			ui.set_reduced_effects(true)
			ui.show_result(sim, "", meta)
			await _settle()
			c.eq(ui.candidate_count(), 2, "all retained takes are candidates")
			c.eq(ui.candidate_take, original, "first retained recording is initial selection without rank")
			ui.next_button.pressed.emit()
			c.eq(ui.candidate_take, chosen, "next candidate can have lower raw DPS")
			c.ok(chosen.power() < original.power(), "fixture really selects lower raw damage")
			c.ok(not ui.archive_button.disabled, "valid lower DPS candidate can be archived")
			c.ok(ui._candidate_ui.details.text.contains(Loc.t("archive.grade_change", [1, 4])), "actual entry grade and original grade both visible")
			c.eq(ui._candidate_ui.preview.condition, 48.0, "preview shows actual lower inherited condition")
			c.eq(ui._candidate_ui.preview.work.size(), 1, "candidate preview retains key work")
			c.ok(ui._candidate_ui.route.view.size.x < WorldArena.BOUNDS.size.x, "short route uses a local scale")
			c.ok(ui._candidate_ui.route._points[0].distance_to(ui._candidate_ui.route._points[-1]) < 4.0, "short route is not stretched into false world coverage")
			var before := meta.echo_archives.duplicate(true)
			var emitted: Array[EchoTake] = []
			ui.archive_requested.connect(func(take: EchoTake) -> void: emitted.append(take))
			ui.archive_button.pressed.emit()
			await _settle()
			c.ok(ui.replacement_pending, "existing archive requires explicit confirmation")
			c.eq(emitted.size(), 0, "opening confirmation emits no archive write")
			c.eq(meta.echo_archives, before, "preview and confirmation preserve permanent state")
			c.ok(not ui.select_candidate(0), "candidate cannot change beneath confirmation")
			for row: ArchiveCandidateUi in ui._confirmation_rows:
				c.ok(not row.preview.is_empty(), "both archives show normalized values")
			c.ok(ui._confirmation_panel.get_combined_minimum_size().y <= float(extent.y), "replacement comparison fits native canvas")
			_bounds(c, ui, extent)
			c.eq(ui.confirm_button.focus_next, ui.confirm_button.get_path_to(ui._confirmation_rows[0].detail_button) if ui._confirmation_rows[0].detail_button.visible else ui.confirm_button.get_path_to(ui._confirmation_rows[1].detail_button), "confirmation traversal loops through visible detail controls")
			ui.cancel_button.pressed.emit()
			c.ok(not ui.replacement_pending, "cancel preserves selection and exits confirmation")
			c.eq(emitted.size(), 0, "cancel never writes")
			ui.archive_button.pressed.emit()
			ui.confirm_button.pressed.emit()
			c.eq(emitted, [chosen], "explicit confirmation emits exactly chosen lower DPS take")
			c.ok(EchoArchive.store(meta, &"looper", emitted[0]), "chosen lower DPS record saves")
			ui.set_archive_result(true)
			c.ok(ui.archive_button.disabled, "saved selection is clearly acknowledged")
			ui.previous_button.pressed.emit()
			c.ok(not ui.archive_button.disabled, "another retained selection remains available after saving")
			ui.next_button.pressed.emit()
			var page_button := ui._candidate_ui.detail_button
			c.ok(page_button.visible, "utility and work expose a focused detail pager")
			for page in ui._candidate_ui._pages.size():
				page_button.pressed.emit()
				await _settle()
				c.ok(ui._panel.get_combined_minimum_size().y <= float(extent.y), "six-weapon detail page fits native height")
				_bounds(c, ui, extent)
			if extent.x == 1280:
				viewport.size = Vector2i(960, 540)
				await _settle()
				c.eq(ui.candidate_take, chosen, "resize preserves intentional selection")
				_bounds(c, ui, viewport.size)
			viewport.free()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Loc.lang = language
