extends SceneTree
# Real native-canvas geometry, controller focus and bounded full-roster cases.
# Run with --headless for deterministic layout, or natively with -- --output=DIR
# to also capture the rendered surfaces at their original pixel dimensions.

var _output := ""
var _results: Array[Dictionary] = []


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
			await _settle()
			check.begin("theme_ui_%s_%d" % [language, extent.x])
			check.eq(root.get_visible_rect().size, Vector2(extent), "native logical canvas is exact; no scaled large-window substitute")
			await _context_cases(check, extent)
			await _shop_cases(check, extent)
	print("Results: %d passed, %d failed" % [check.passed, check.failed])
	if not _output.is_empty():
		var file := FileAccess.open(_output.path_join("theme-ui.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"passed": check.passed, "failed": check.failed, "surfaces": _results}, "\t"))
	quit(1 if check.failed > 0 else 0)


func _settle() -> void:
	for _frame in 4:
		await process_frame


func _capture(name_value: String, surface: Control, c: Check) -> void:
	await _settle()
	var extent := Vector2i(root.get_visible_rect().size)
	_results.append({"name": name_value, "lang": Loc.lang, "extent": [extent.x, extent.y],
		"minimum": [surface.get_combined_minimum_size().x, surface.get_combined_minimum_size().y]})
	if DisplayServer.get_name() != "headless" and not _output.is_empty():
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		c.eq(image.get_size(), extent, "screenshot retains original native pixel dimensions")
		c.eq(image.save_png(_output.path_join("%s-%s-%d.png" % [name_value, Loc.lang, extent.x])), OK, "native capture saves")


func _bounds(control: Control, extent: Vector2i, c: Check) -> void:
	c.ok(Rect2(Vector2.ZERO, Vector2(extent)).grow(1).encloses(control.get_global_rect()), "%s stays inside native canvas" % control.name)


func _context_cases(c: Check, extent: Vector2i) -> void:
	var sim := Sim.new(1617)
	sim.start_wave(12)
	sim.player.materials = 0
	sim.expedition["debt"] = 40
	sim._end_wave()
	var context := ContextChoiceUi.new()
	context.theme = UiTheme.build()
	root.add_child(context)
	context.open_context("context.exit.title", "context.exit.body", Expedition.exit_options(sim), true)
	await _settle()
	_bounds(context.save_button, extent, c)
	_bounds(context.return_button, extent, c)
	c.ok(context._rows.get_combined_minimum_size().x <= float(extent.x - 56), "exit choices cannot widen the sheet")
	c.ok(context.save_button.has_focus() or context.choice_buttons[2].has_focus(), "available exit has controller focus")
	for button: Button in context.choice_buttons:
		if not button.disabled:
			button.grab_focus()
			await _settle()
			_bounds(button, extent, c)
	context.show_error(Loc.t("suspend.write_failed"))
	await _capture("exit-terms-error", context, c)
	_bounds(context._error, extent, c)
	_bounds(context.save_button, extent, c)
	context.reset()
	# Use the actual identity-specific option generators, including blocked terms.
	for kind: StringName in Expedition.BOSS_IDS:
		sim.phase = Sim.Phase.WAVE
		sim.expedition["negotiation"] = {"uid": 123, "kind": kind, "pos": sim.player.pos, "remaining": 8.0, "choice_pending": true}
		context.open_context("context.negotiation.title", "context.negotiation.body", Expedition.negotiation_options(sim), true)
		await _settle()
		c.ok(context.choice_buttons.size() >= 2, "boss identity exposes real choices and decline")
		_bounds(context.save_button, extent, c)
		_bounds(context.return_button, extent, c)
		for button: Button in context.choice_buttons:
			if not button.disabled:
				button.grab_focus()
				await _settle()
				_bounds(button, extent, c)
		await _capture("terms-" + String(kind), context, c)
	context.free()


func _shop_cases(c: Check, extent: Vector2i) -> void:
	var sim := Sim.new(1618)
	sim.start_run()
	sim._end_wave()
	sim.player.materials = 13
	sim.player.hp = 1
	sim.expedition["debt"] = 40
	var world: Dictionary = sim.expedition["world"]
	world["workers"].clear()
	world["witnesses"].clear()
	for stage in 12:
		world["workers"].append({"id": StringName("worker_%d" % [stage + 1]), "stage": stage + 1,
			"pos": WorldArena.safe_worker_position(stage + 1), "hp": 45.0, "state": &"safe", "testimony_used": stage % 2 == 0, "aid_used": stage % 3 == 0})
	for stage in 12:
		world["witnesses"].append(StringName("worker_%d" % [stage + 1]))
	for uid in 8:
		world["witnesses"].append(StringName("copy_%d" % [uid + 1]))
	world["witnesses"].append(&"self")
	world["roster"] = [{"kind": &"foreman", "hp": 17.0, "max_hp": 64.0, "life": 123.0, "state": &"bench", "uid": 101},
		{"kind": &"collector", "hp": 19.0, "max_hp": 52.0, "life": 108.0, "state": &"bench", "uid": 102},
		{"kind": &"paradox", "hp": 0.0, "max_hp": 48.0, "life": 0.0, "state": &"fallen", "uid": 103}]
	var shop := ShopUi.new()
	shop.theme = UiTheme.build()
	root.add_child(shop)
	shop.set_reduced_effects(true)
	shop.open(sim)
	await _settle()
	_bounds(shop.start_button, extent, c)
	_bounds(shop.crew_button, extent, c)
	_bounds(shop.debt_button, extent, c)
	c.ok(not shop.debt_button.get_global_rect().intersects(shop._materials.get_global_rect()), "ledger and money remain separate hit areas")
	c.ok(shop._prep_status.get_global_rect().end.x <= shop._materials.get_global_rect().position.x, "status remains in its header column")
	for card: OfferCard in shop.offers_box.get_children():
		for action: BaseButton in card.find_children("*", "BaseButton", true, false):
			c.ok(card.get_global_rect().grow(1).encloses(action.get_global_rect()), "offer controls remain inside their paper card")
	await _capture("shop-world-ledger-entry", shop, c)
	shop.debt_button.pressed.emit()
	await _settle()
	for button: Button in shop.workshop.choice_buttons:
		_bounds(button, extent, c)
	_bounds(shop.workshop.cancel_button, extent, c)
	c.ok(shop.workshop._content.get_combined_minimum_size().y <= float(extent.y - 48), "full payment explanation fits without hidden controls")
	await _capture("debt-partial-payment", shop, c)
	shop.workshop.close()
	shop.crew_button.pressed.emit()
	await _settle()
	c.eq(shop.crew.witness_labels.size(), 21, "full bounded registry includes twelve people eight copies and self")
	c.eq(shop.crew.action_buttons.size(), 15, "three boss states and twelve workers are real browsable rows")
	_bounds(shop.crew.undo_button, extent, c)
	_bounds(shop.crew.return_button, extent, c)
	c.ok(shop.crew._rows.get_combined_minimum_size().x <= float(extent.x - 56), "full roster remains within horizontal canvas")
	for button: Button in shop.crew.action_buttons:
		if button.disabled:
			continue
		button.grab_focus()
		await _settle()
		_bounds(button, extent, c)
	c.ok(shop.crew.action_buttons[-1].has_focus(), "controller can reach final worker in the full roster")
	await _capture("full-crew-last-focus", shop, c)
	shop.crew.witness_labels[-1].grab_focus()
	await _settle()
	_bounds(shop.crew.witness_labels[-1], extent, c)
	c.ok(shop.crew.witness_labels[-1].has_focus(), "controller can reach the final self-witness record")
	await _capture("witness-registry-last-focus", shop, c)
	shop.crew.close()
	c.ok(shop.crew_button.has_focus(), "closing full roster returns to its shop entry")
	shop.free()
