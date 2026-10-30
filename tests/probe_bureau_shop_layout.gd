extends SceneTree

# This supplements the synchronous unit suite with actual settled native-canvas
# rectangles. It is safe headlessly; native screenshots belong to the main probe.
func _initialize() -> void:
	await process_frame
	var c := Check.new()
	var previous_language := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = extent
			root.content_scale_size = extent
			var sim := Sim.new(1718)
			sim.start_run()
			sim._end_wave()
			sim.player.materials = 100
			var ui := ShopUi.new()
			ui.theme = UiTheme.build()
			root.add_child(ui)
			ui.set_reduced_effects(true)
			ui.open(sim)
			await _settle()
			c.begin("bureau_shop_%s_%d" % [language, extent.x])
			for button: Button in [ui.confession_button, ui.debt_button, ui.start_button, ui.reroll_button, ui.undo_button]:
				_bounds(c, button, extent)
			c.ok(not ui.confession_button.get_global_rect().intersects(ui.debt_button.get_global_rect()), "two header entries keep distinct hit areas")
			ui.confession_button.pressed.emit()
			await _settle()
			for button: Button in ui.confession.choice_buttons:
				_bounds(c, button, extent)
			_bounds(c, ui.confession.return_button, extent)
			_bounds(c, ui.confession._receipt, extent)
			c.ok(ui.confession._content.get_combined_minimum_size().y < float(extent.y - 36), "whole copy desk fits the native height")
			ui.confession.show_error(Loc.t("confession.ui.changed"))
			await _settle()
			_bounds(c, ui.confession.error_label, extent)
			_bounds(c, ui.confession.return_button, extent)
			c.ok(ui.confession.return_button.find_valid_focus_neighbor(SIDE_TOP) != null, "decision has a usable focus route")
			ui.confession.choice_buttons[1].pressed.emit()
			await _settle()
			_bounds(c, ui.confession.return_button, extent)
			ui.confession.return_button.pressed.emit()
			c.eq(root.gui_get_focus_owner(), ui.confession_button, "cancel restores the actual fixed entry")
			ui.free()
	Loc.lang = previous_language
	print("Results: %d passed, %d failed" % [c.passed, c.failed])
	quit(1 if c.failed > 0 else 0)


func _settle() -> void:
	for _frame in 4:
		await process_frame


func _bounds(c: Check, control: Control, extent: Vector2i) -> void:
	c.ok(Rect2(Vector2.ZERO, Vector2(extent)).grow(1).encloses(control.get_global_rect()), "%s stays inside native canvas" % control.name)
