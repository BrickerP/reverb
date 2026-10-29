extends SceneTree
# Run directly: native container layout needs actual process frames.
# godot --headless --path . --script tests/probe_native_end_archive.gd


func _initialize() -> void:
	await process_frame
	var check := Check.new()
	check.begin("native_end_report_geometry")
	await _end_report(check)
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
			var ui := EndUi.new()
			ui.theme = UiTheme.build()
			viewport.add_child(ui)
			ui.set_reduced_effects(true)
			ui.show_result(sim, Loc.t("end.unlocked", [", ".join([Loc.character_name(&"solo"), Loc.character_name(&"mirror"), Loc.character_name(&"conductor")])]))
			await _settle()
			c.ok(ui._afterword.text.contains(Loc.t("expedition.ending.indebted")), "real ending remains visible")
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
