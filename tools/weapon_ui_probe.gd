extends SceneTree
# Native, settled UI evidence. The fixture wallet and stock are not balance evidence.

var _output := ""
var _check := Check.new()
var _shots: Array[Dictionary] = []
var _frames := 0


func _initialize() -> void:
	_output = OS.get_environment("REVERB_UI_EVIDENCE_OUTPUT")
	if _output.is_empty():
		_output = ProjectSettings.globalize_path("res://shots/weapon-ui")
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 6000:
		printerr("FAILED: weapon UI evidence exceeded its frame deadline")
		quit(1)
	return false


func _run() -> void:
	for language in ["en", "zh"]:
		Loc.lang = language
		for extent in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = extent
			root.content_scale_size = extent
			var sim := _fixture()
			var ui := ShopUi.new()
			ui.theme = UiTheme.build()
			root.add_child(ui)
			ui.set_reduced_effects(true)
			ui.open(sim)
			await _settle()
			_check.begin("weapon_ui_%s_%d" % [language, extent.x])
			var before := RunSnapshot.capture(sim)
			await _capture(ui, extent, "before-upgrade")
			var cost := Shop.upgrade_cost(sim.player.weapons[0], 0)
			var cash := sim.player.materials
			ui.build_panel.upgrade_button.grab_focus()
			var accept := InputEventAction.new()
			accept.action = &"ui_accept"
			accept.pressed = true
			Input.parse_input_event(accept)
			await _settle()
			accept = InputEventAction.new()
			accept.action = &"ui_accept"
			accept.pressed = false
			Input.parse_input_event(accept)
			await _settle()
			_check.eq(sim.player.level_at(0), 1, "focused ui_accept upgrades the selected weapon")
			_check.eq(sim.player.materials, cash - cost, "native input spends the displayed cost once")
			await _capture(ui, extent, "after-upgrade")
			ui.undo_button.pressed.emit()
			await _settle()
			_check.eq(RunSnapshot.capture(sim), before, "native purchase Undo restores complete snapshot and both RNGs")
			# Every tool must fit the selected sheet, including long translations,
			# field ticks, both ready combos and grade-dependent support effects.
			for weapon: WeaponDef in Content.weapons().values():
				sim.player.weapons[0] = weapon
				ui.refresh()
				_check.begin("layout_%s_%d_%s" % [language, extent.x, weapon.id])
				await _settle()
				_bounds(ui, extent)
			sim.player.weapons[0] = Content.weapon(&"repair_kit")
			ui.refresh()
			await _settle()
			await _capture(ui, extent, "repair-station")
			sim.player.weapons[0] = Content.weapon(&"paper_seed")
			sim.player.materials = 0
			ui.refresh()
			await _settle()
			await _capture(ui, extent, "unaffordable-tree")
			ui.equipment_button.grab_focus()
			await _action(&"ui_right")
			_check.eq(root.gui_get_focus_owner(), ui.echoes_button, "directional navigation reaches the copy page")
			await _action(&"ui_accept")
			_check.ok(ui.echo_panel.is_visible_in_tree(), "mapped accept opens the copy page")
			await _settle()
			await _capture(ui, extent, "echoes")
			ui.echo_panel.merge_button.pressed.emit()
			ui.echo_panel.select_take(sim.bank.takes[1])
			ui.echo_panel.select_take(sim.bank.takes.back())
			_check.eq(ui.echo_panel.trait_buttons.size(), 3, "merge evidence includes all three actual decisions")
			await _settle()
			await _capture(ui, extent, "echo-merge")
			ui.close_session()
			ui.free()
	var file := FileAccess.open(_output.path_join("summary.json"), FileAccess.WRITE)
	if file == null:
		printerr("FAILED: cannot write weapon UI evidence summary")
		quit(1)
		return
	file.store_string(JSON.stringify({"commit": OS.get_environment("REVERB_BUILD_COMMIT"),
		"source": "native fixture", "physical_controller_tested": false,
		"passed": _check.passed, "failed": _check.failed, "screenshots": _shots}, "  "))
	file.close()
	print("Weapon UI: %d passed, %d failed" % [_check.passed, _check.failed])
	quit(1 if _check.failed > 0 else 0)


func _fixture() -> Sim:
	var sim := Sim.new(8817)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = 4
	sim.player.materials = 500
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	for id: StringName in [&"pistol", &"stapler", &"ink_bottle", &"stamp", &"hex_bolt", &"paper_seed"]:
		sim.player.add_weapon(Content.weapon(id))
	sim.shop.roll(sim)
	sim.shop.offers.clear()
	for id: StringName in [&"smg", &"repair_kit", &"paper_seed", &"quick_trigger"]:
		var offer := Offer.new()
		offer.weapon = Content.weapon(id)
		if offer.weapon == null:
			offer.item = Content.item(id)
		offer.price = 24
		sim.shop.offers.append(offer)
	for kind: StringName in [AnomalyContract.REPAIR, AnomalyContract.RESCUE]:
		var offer := Offer.new()
		offer.contract = AnomalyContract.create(kind, sim.next_wave_number())
		offer.price = offer.contract.deposit
		sim.shop.offers.append(offer)
	sim.player.stats.add(Stats.ECHO_SLOTS, 6.0)
	for index in 8:
		var take := EchoTake.new()
		take.wave = index + 1
		take.condition = 60.0
		take.weapons.append(Content.weapon(&"pistol"))
		take.levels.append(0)
		take.samples = PackedVector2Array([Vector2(200, 200), Vector2(400, 300), Vector2(600, 220)])
		sim.bank.add(take)
	return sim


func _action(name: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = name
		event.pressed = pressed
		Input.parse_input_event(event)
		await _settle()


func _settle() -> void:
	for _index in 5:
		await process_frame


func _bounds(ui: ShopUi, extent: Vector2i) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(extent)).grow(1.0)
	for control: Control in [ui.build_panel, ui.echo_panel, ui.start_button,
			ui.reroll_button, ui.undo_button, ui.equipment_button, ui.echoes_button]:
		if control.is_visible_in_tree():
			_check.ok(viewport.encloses(control.get_global_rect()), "%s %s at %s stays in %s" % [control.name, control.get("text") if control is Button else "panel", control.get_global_rect(), extent])
	for card: OfferCard in ui.offers_box.get_children():
		var purchase := card.find_child("PurchaseAction", true, false) as Label
		_check.ok(card.get_global_rect().grow(1).encloses(purchase.get_global_rect()), "purchase label stays inside its stock card")
		if card.swap_button != null:
			_check.ok(card.get_global_rect().grow(1).encloses(card.swap_button.get_global_rect()), "replace action stays inside its stock card")
	if ui.build_panel.visible:
		for label: Label in [ui.build_panel.detail_title, ui.build_panel.detail_behavior,
				ui.build_panel.detail_stats, ui.build_panel.detail_upgrade, ui.build_panel.detail_combo,
				ui.build_panel.detail_reason]:
			if label.is_visible_in_tree():
				_check.ok(viewport.encloses(label.get_global_rect()), "selected weapon explanation is entirely visible")
				_check.eq(label.get_visible_line_count(), label.get_line_count(), "selected explanation has no hidden lines")
		_check.ok(viewport.encloses(ui.build_panel.upgrade_button.get_global_rect()), "upgrade has a visible native hit area")
		_check.eq(ui.build_panel._slot_buttons.size(), Content.MAX_WEAPON_SLOTS, "all six weapon slots remain in view")
	else:
		for button: Button in ui.echo_panel.trait_buttons:
			_check.ok(viewport.encloses(button.get_global_rect()), "named merge action stays inside the native canvas")


func _capture(ui: ShopUi, extent: Vector2i, state: String) -> void:
	_bounds(ui, extent)
	RenderingServer.force_draw()
	var name := "%s-%dx%d-%s.png" % [Loc.lang, extent.x, extent.y, state]
	var picture := root.get_texture().get_image()
	_check.eq(picture.get_size(), extent, "capture keeps native canvas dimensions")
	_check.eq(picture.save_png(_output.path_join(name)), OK, "native screenshot is written")
	_shots.append({"file": name, "language": Loc.lang, "width": extent.x, "height": extent.y, "state": state})
