extends SceneTree
# Native, settled UI evidence. The fixture wallet and stock are not balance evidence.

var _output := ""
var _check := Check.new()
var _shots: Array[Dictionary] = []
var _frames := 0
var _hover_evidence: Array[Dictionary] = []
var _original_pointer := Vector2.ZERO
var _pointer_saved := false


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
		_restore_pointer()
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
			await _exercise_workshop(ui, sim, extent)
			await _inspect_layers(ui, sim, extent)
			ui.focus_default()
			await _settle()
			_check.ok(root.gui_get_focus_owner() != null, "resize begins with an actual focused control")
			var resize_before := RunSnapshot.capture(sim)
			var alternate := Vector2i(960, 540) if extent.x == 1280 else Vector2i(1280, 720)
			root.size = alternate
			root.content_scale_size = alternate
			await _settle()
			_check.eq(ui.inventory_overview(), alternate.x == 1280, "live resize chooses the actual viewport layout")
			_check.eq(ui.build_panel.show_heading, alternate.x == 1280, "live resize rebuilds the matching paper heading")
			_check.ok(root.gui_get_focus_owner() != null, "live resize keeps an actionable keyboard focus")
			_bounds(ui, alternate)
			root.size = extent
			root.content_scale_size = extent
			await _settle()
			_check.eq(RunSnapshot.capture(sim), resize_before, "window resize preserves the complete run and both RNGs")

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
			if ui.inventory_overview():
				ui.build_panel._slot_buttons.back().grab_focus()
				await _action(&"ui_right")
				_check.eq(root.gui_get_focus_owner(), ui.echo_panel.merge_button, "overview navigation reaches the visible bank")
				await _capture(ui, extent, "echoes")
				await _action(&"ui_accept")
			else:
				ui.equipment_button.grab_focus()
				await _action(&"ui_right")
				_check.eq(root.gui_get_focus_owner(), ui.echoes_button, "directional navigation reaches the copy page")
				await _action(&"ui_accept")
				_check.ok(ui.echo_panel.is_visible_in_tree(), "mapped accept opens the copy page")
				await _capture(ui, extent, "echoes")
				ui.echo_panel.merge_button.pressed.emit()
			_check.ok(ui.echo_panel.is_ancestor_of(root.gui_get_focus_owner()), "merge keeps keyboard focus in the active bank")
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
		_restore_pointer()
		quit(1)
		return
	file.store_string(JSON.stringify({"commit": OS.get_environment("REVERB_BUILD_COMMIT"),
		"source": "native fixture", "physical_controller_tested": false,
		"passed": _check.passed, "failed": _check.failed, "screenshots": _shots, "hover_evidence": _hover_evidence}, "  "))
	file.close()
	_restore_pointer()
	print("Weapon UI: %d passed, %d failed" % [_check.passed, _check.failed])
	quit(1 if _check.failed > 0 else 0)


func _move_pointer(point: Vector2) -> void:
	_push_pointer(point)
	await _settle()


func _push_pointer(point: Vector2) -> void:
	if not _pointer_saved:
		_original_pointer = root.get_mouse_position()
		_pointer_saved = true
	# Per-frame hover reads the native pointer, not only a forwarded event's point.
	# Match the existing carbon/perception probes so the OS refresh cannot cancel intent.
	root.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(2, 0)
	root.notify_mouse_entered()
	root.push_input(event, true)


func _deliberate_hover(ui: ShopUi, source: Control) -> void:
	var source_id: int = source.get_instance_id()
	var source_kind: String = String(source.get_meta(&"inspect_kind", &""))
	var initial_rect: Rect2 = source.get_global_rect()
	var generation: int = ui._refresh_generation
	var started: int = Time.get_ticks_usec()
	_push_pointer(source.get_global_rect().get_center())
	await create_timer(ShopUi.HOVER_INTENT * 0.45).timeout
	var early_elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
	var early_visible: bool = ui.inspection.visible
	var pointer: Vector2 = ui.get_global_mouse_position()
	var early_live: bool = is_instance_valid(source) and source.is_inside_tree()
	_check.ok(early_live and source.get_global_rect().has_point(pointer), "native pointer remains inside the intended current control")
	_check.ok(not early_visible, "stable hover has no secondary sheet before the intent window")
	var early_pending_id: int = ui._hover_source.get_instance_id() if is_instance_valid(ui._hover_source) else 0
	# Cross the real threshold without manually advancing ShopUi or changing its timer.
	await create_timer(ShopUi.HOVER_INTENT * 0.75).timeout
	await _settle()
	var live: bool = is_instance_valid(source) and source.is_inside_tree()
	_hover_evidence.append({"language": Loc.lang, "canvas": [root.size.x, root.size.y],
		"kind": source_kind, "source_id": source_id, "early_pending_id": early_pending_id,
		"same_live_source": live and source.get_instance_id() == source_id,
		"refresh_before": generation, "refresh_after": ui._refresh_generation,
		"initial_rect": str(initial_rect), "source_rect": str(source.get_global_rect()) if live else "removed",
		"early_native_pointer": str(pointer), "native_pointer": str(ui.get_global_mouse_position()),
		"intent_seconds": ShopUi.HOVER_INTENT, "early_elapsed": early_elapsed, "early_visible": early_visible,
		"settled_elapsed": float(Time.get_ticks_usec() - started) / 1000000.0,
		"settled_visible": ui.inspection.visible, "pinned": ui.inspection.pinned,
		"pending_left": ui._hover_left, "pointer_enabled": ui.inspection.pointer_enabled,
		"modal_open": ui._opaque_modal_open(), "shop_paused": ui._shop_paused})
	_check.ok(generation == ui._refresh_generation and live,
		"hover intent observes the same live control and layout generation")


func _restore_pointer() -> void:
	if _pointer_saved:
		root.warp_mouse(_original_pointer)
		_pointer_saved = false


func _inspect_layers(ui: ShopUi, sim: Sim, extent: Vector2i) -> void:
	ui.show_equipment_page(0)
	ui.inspection.reset()
	var before := RunSnapshot.capture(sim)
	await _move_pointer(Vector2(10, 10))
	var weapon := ui.build_panel._slot_buttons[0]
	_push_pointer(weapon.get_global_rect().get_center())
	_push_pointer(ui.build_panel._slot_buttons[1].get_global_rect().get_center())
	_push_pointer(Vector2(10, 10))
	await process_frame
	_check.ok(not ui.inspection.visible, "sweeping across stock before intent does not open prose")
	weapon = ui.build_panel._slot_buttons[0]
	await _deliberate_hover(ui, weapon)
	_check.ok(ui.inspection.visible and not ui.inspection.pinned, "stable pointer intent opens secondary weapon inspection")
	if not ui.inspection.visible or ui.inspection.rule_buttons.is_empty():
		return
	await _capture(ui, extent, "weapon-hover")
	await _move_pointer(ui.inspection.rule_buttons[0].get_global_rect().get_center())
	_check.ok(ui.inspection.definition.visible, "hovering an upgrade term opens tertiary detail")
	if ui.inspection.definition.visible:
		await _move_pointer(ui.inspection.definition.get_global_rect().get_center())
		await create_timer(0.3).timeout
		_check.ok(ui.inspection.definition.visible and ui.inspection.visible, "tertiary reading remains open beyond the leave grace while the pointer reads it")
	await _capture(ui, extent, "weapon-rule")
	ui.inspection.reset()
	ui.show_equipment_page(1)
	await _settle()
	var copy := ui.echo_panel.copy_buttons[0]
	await _deliberate_hover(ui, copy)
	_check.ok(ui.inspection.visible, "copy hover supplies wear and skill context")
	if not ui.inspection.visible or ui.inspection.rule_buttons.is_empty():
		return
	await _capture(ui, extent, "echo-hover")
	await _move_pointer(ui.inspection.rule_buttons[0].get_global_rect().get_center())
	_check.ok(ui.inspection.definition.visible, "wear explanation is a tertiary layer")
	await _capture(ui, extent, "echo-rule")
	ui.inspection.reset()
	copy.grab_focus()
	var key := InputEventJoypadButton.new()
	key.button_index = JOY_BUTTON_Y
	key.pressed = true
	root.push_input(key, false)
	await _settle()
	_check.ok(ui.inspection.pinned and ui.inspection.details_button.has_focus(), "controller inspection enters the same pinned sheet")
	await _capture(ui, extent, "pinned-inspection")
	ui.inspection.details_button.pressed.emit()
	await _settle()
	_check.ok(ui.workshop.visible and not ui.inspection.visible, "detail sheet is a deliberate third-layer entry")
	ui.workshop.cancel_button.pressed.emit()
	await _settle()
	_check.ok(ui.inspection.pinned, "closing the detail sheet returns to its pinned second layer")
	ui.inspection.close_inspection()
	_check.eq(root.gui_get_focus_owner(), copy, "closing inspection restores its source")
	_check.eq(RunSnapshot.capture(sim), before, "hover layers and controller inspection preserve the whole run")
	ui.inspection.reset()
	ui.inspection.focus_enabled = false
	ui.show_equipment_page(0)
	await _move_pointer(Vector2(10, 10))


func _exercise_workshop(ui: ShopUi, sim: Sim, extent: Vector2i) -> void:
	var before := RunSnapshot.capture(sim)
	ui._offers_scroll.ensure_control_visible(ui.offers_box.get_child(5))
	await _settle()
	var scroll := ui._offers_scroll.scroll_vertical
	ui.build_panel.upgrade_button.pressed.emit()
	await _settle()
	_check.eq(ui._offers_scroll.scroll_vertical, scroll, "upgrading preserves the reader's stock position")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(ui._offers_scroll.scroll_vertical, scroll, "Undo preserves the reader's stock position")
	_check.eq(RunSnapshot.capture(sim), before, "scroll preservation leaves the transaction and both RNGs exact")
	var item_card := ui.offers_box.get_child(3) as OfferCard
	ui._offers_scroll.ensure_control_visible(item_card)
	await _settle()
	var point := item_card.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		click.global_position = point
		root.push_input(click, false)
		await _settle()
	_check.eq(sim.player.item_count(&"quick_trigger"), 1, "pointer input buys the named item exactly once")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(RunSnapshot.capture(sim), before, "pointer purchase Undo restores the exact run")
	# Trade-in prices are largest on fully upgraded equipment. Exercise that
	# real selection state, including its material refund and confirmation.
	var original_levels := sim.player.weapon_levels.duplicate()
	var original_investments := sim.player.weapon_investments.duplicate()
	for index in sim.player.weapons.size():
		var w := sim.player.weapons[index]
		sim.player.weapon_levels[index] = WeaponDef.MAX_LEVEL
		sim.player.weapon_investments[index] = w.price
		for level in WeaponDef.MAX_LEVEL:
			sim.player.weapon_investments[index] += Shop.upgrade_cost(w, level)
	ui.refresh()
	await _settle()
	var trade_before := RunSnapshot.capture(sim)
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	await _settle()
	_check.ok(ui.is_replacing(), "a full inventory enters an explicit trade-in selection")
	_check.ok(not ui.build_panel.upgrade_button.visible, "trade-in selection cannot accidentally buy an upgrade")
	await _capture(ui, extent, "trade-in-selection")
	ui.build_panel._slot_buttons[1].pressed.emit()
	await _settle()
	await _capture(ui, extent, "replacement-confirmation")
	ui.workshop.choice_buttons[0].pressed.emit()
	await _settle()
	_check.eq(sim.player.weapons[1].id, &"smg", "confirmed replacement installs the chosen offer")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(RunSnapshot.capture(sim), trade_before, "trade-in Undo restores grades, investments, funds and both RNGs")
	sim.player.weapon_levels.assign(original_levels)
	sim.player.weapon_investments.assign(original_investments)
	ui.refresh()
	ui.build_panel._select(0)
	await _settle()
	_check.eq(RunSnapshot.capture(sim), before, "trade-in fixture returns to the original shop")
	ui.build_panel._slot_buttons[ui.build_panel._selected].pressed.emit()
	ui.inspection.details_button.pressed.emit()
	await _settle()
	await _capture(ui, extent, "manage-weapon")
	ui.workshop.choice_buttons[3].pressed.emit()
	await _settle()
	_check.eq(sim.player.weapons.size(), 5, "named sell action removes the selected weapon")
	var after_sale := RunSnapshot.capture(sim)
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	await _settle()
	_check.eq(sim.player.weapons.back().id, &"smg", "clicking an affordable offer installs its actual weapon")
	_check.eq(ui.build_panel._selected, 5, "new merchandise becomes the inspected weapon")
	await _capture(ui, extent, "new-weapon")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(RunSnapshot.capture(sim), after_sale, "weapon purchase Undo restores the exact preceding sale")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(RunSnapshot.capture(sim), before, "sale Undo restores equipment, investments and money")
	ui.build_panel._select(0)
	# The same-level donor and evolution family are deliberate fixture choices.
	sim.player.weapons[1] = Content.weapon(&"pistol")
	ui.refresh()
	await _settle()
	before = RunSnapshot.capture(sim)
	ui.build_panel._slot_buttons[ui.build_panel._selected].pressed.emit()
	ui.inspection.details_button.pressed.emit()
	ui.workshop.choice_buttons[1].pressed.emit()
	await _settle()
	ui.workshop.choice_buttons[0].pressed.emit()
	await _settle()
	await _capture(ui, extent, "combine-confirmation")
	ui.workshop.choice_buttons[0].pressed.emit()
	await _settle()
	_check.eq(sim.player.weapons.size(), 5, "combine consumes exactly the displayed donor")
	_check.eq(sim.player.level_at(0), 1, "combine raises the displayed host grade")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(RunSnapshot.capture(sim), before, "combine Undo restores the exact host and donor")
	# The actual Manage entry offers canonical branches even before their grade
	# gate is met. Keep this disabled, multiline boundary in native 540p coverage.
	ui.build_panel._slot_buttons[0].pressed.emit()
	ui.inspection.details_button.pressed.emit()
	ui.workshop.choice_buttons[2].pressed.emit()
	await _settle()
	_check.ok(ui.workshop.choice_buttons.all(func(button: Button) -> bool: return button.disabled), "ordinary low-grade evolution keeps both actual branches blocked")
	_check.eq(RunSnapshot.capture(sim), before, "reading blocked grade branches leaves the run unchanged")
	await _capture(ui, extent, "evolution-blocked-grade")
	ui.workshop.cancel_button.pressed.emit()
	sim.player.weapons[2] = Content.weapon(&"pistol")
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	var evolution_cash: int = sim.player.materials
	sim.player.materials = 0
	ui.refresh()
	await _settle()
	var poor_before := RunSnapshot.capture(sim)
	ui.build_panel._select(0)
	ui.build_panel.upgrade_button.pressed.emit()
	await _settle()
	_check.ok(ui.workshop.choice_buttons.all(func(button: Button) -> bool: return button.disabled), "maximum-grade evolution still blocks unaffordable branches")
	_check.eq(RunSnapshot.capture(sim), poor_before, "unaffordable branch inspection cannot spend or evolve")
	await _capture(ui, extent, "evolution-blocked-funds")
	ui.workshop.cancel_button.pressed.emit()
	sim.player.materials = evolution_cash
	ui.refresh()
	await _settle()
	before = RunSnapshot.capture(sim)
	ui.build_panel.upgrade_button.pressed.emit()
	await _settle()
	_check.ok(ui.workshop.choice_buttons.all(func(button: Button) -> bool: return not button.disabled), "restored funds expose the actual affordable branches")
	_check.ok(ui.workshop.choice_preview.custom_minimum_size.y >= 150.0 and ui.workshop.choice_preview.custom_minimum_size.y <= 180.0, "affordable evolution restores the dominant result diagram after blocked entries")
	await _capture(ui, extent, "evolution-choice")
	ui.workshop.choice_buttons[0].pressed.emit()
	await _settle()
	_check.eq(sim.player.weapons[0].id, &"twin_fangs", "evolution uses the explicitly chosen branch")
	ui.undo_button.pressed.emit()
	await _settle()
	_check.eq(RunSnapshot.capture(sim), before, "evolution Undo restores the original tool and investment")
	sim.player.weapons[1] = Content.weapon(&"stapler")
	sim.player.weapons[2] = Content.weapon(&"ink_bottle")
	sim.player.weapon_levels[0] = 0
	ui.refresh()
	await _settle()


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
		take.condition = [100.0, 82.0, 60.0, 35.0, 18.0, 45.0, 70.0, 90.0][index]
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
		var purchase := card.find_child("PurchaseAction", true, false) as Control
		_check.ok(card.get_global_rect().grow(1).encloses(purchase.get_global_rect()), "purchase label stays inside its stock card")
		_check.ok(card._art.size.y >= 50, "primary stock is real merchandise art")
		var group := card.find_child("MerchandiseInfo", true, false) as Control
		var name := card.find_child("MerchandiseName", true, false) as Control
		_check.ok(card._art.get_global_rect().end.x <= group.get_global_rect().position.x + 1,
				"merchandise illustration leads a single information column")
		_check.ok(absf(name.global_position.x - card.price_tag.global_position.x) <= 1,
				"name and price action share one aligned reading axis")
		_check.eq(card.find_child("AttackBehavior", true, false), null, "stock prose stays off the primary surface")
		if card.swap_button != null:
			_check.ok(card.get_global_rect().grow(1).encloses(card.swap_button.get_global_rect()), "replace action stays inside its stock card")
	if ui.workshop.visible:
		for button: Button in ui.workshop.choice_buttons + [ui.workshop.cancel_button]:
			_check.ok(viewport.encloses(button.get_global_rect()), "workshop actions fit the native canvas")
			if not button.disabled:
				for line: String in button.text.split("\n"):
					var width := button.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT,
						-1, button.get_theme_font_size("font_size")).x
					_check.ok(width <= button.size.x - 12.0, "workshop action text is not clipped")
	if ui.build_panel.visible:
		var controls := 0
		for button: Button in ui.build_panel.find_children("*", "Button", true, false):
			if button.is_visible_in_tree() and not ui.build_panel._slot_buttons.has(button) and not ui.build_panel.passive_buttons.has(button):
				controls += 1
		_check.ok(controls <= 2, "primary equipment has at most two deliberate action entries")
		_check.ok(ui.build_panel.size.y <= ui.build_panel._box.get_combined_minimum_size().y + 16.0, "weapon paper follows its content height")
		for card: PanelContainer in ui.build_panel._cards:
			var art := card.find_child("WeaponArt", true, false) as TextureRect
			_check.ok(art != null and art.size.y >= 48, "equipped weapon has primary artwork")
		_check.ok(viewport.encloses(ui.build_panel.upgrade_button.get_global_rect()), "upgrade has a visible native hit area")
		_check.eq(ui.build_panel._slot_buttons.size(), Content.MAX_WEAPON_SLOTS, "all six weapon slots remain in view")
		for card: PanelContainer in ui.build_panel._cards:
			for label: Label in card.find_children("*", "Label", true, false):
				_check.ok(card.get_global_rect().grow(1).encloses(label.get_global_rect()), "slot name, level and material refund stay inside their paper")
				_check.eq(label.get_visible_line_count(), label.get_line_count(), "trade-in values have no hidden lines")
	if ui.build_panel.visible and ui.echo_panel.visible:
		_check.ok(ui.build_panel.get_global_rect().end.y <= ui.echo_panel.get_global_rect().position.y + 1.0,
				"overview papers keep distinct vertical space")
	if ui.echo_panel.visible:
		_check.eq(ui.echo_panel.copy_buttons.size(), mini(ui.sim.bank.takes.size(), 8), "legal Echo bank is a visual grid")
		for copy: Button in ui.echo_panel.copy_buttons:
			var doll := copy.find_child("EchoDoll", true, false) as EchoPortrait
			_check.ok(doll != null and doll._texture != null, "Echo is represented by the actual paper doll")
			_check.ok(viewport.encloses(copy.get_global_rect()), "Echo tile stays inside the native canvas")
		for button: Button in ui.echo_panel.trait_buttons:
			_check.ok(viewport.encloses(button.get_global_rect()), "named merge action stays inside the native canvas")
	if ui.inspection.visible:
		_check.ok(viewport.encloses(ui.inspection.sheet.get_global_rect()), "secondary inspection stays on screen")
		_check.ok(ui.inspection.sheet.get_global_rect().end.y <= float(extent.y) - 52, "secondary sheet leaves the departure tray clear")
		if ui.inspection.definition.visible:
			_check.ok(viewport.encloses(ui.inspection.definition.get_global_rect()), "tertiary explanation stays on screen")
			_check.ok(ui.inspection.definition.get_global_rect().end.y <= float(extent.y) - 52, "tertiary rules leave the departure tray clear")


func _capture(ui: ShopUi, extent: Vector2i, state: String) -> void:
	_bounds(ui, extent)
	RenderingServer.force_draw()
	var name := "%s-%dx%d-%s.png" % [Loc.lang, extent.x, extent.y, state]
	var picture := root.get_texture().get_image()
	_check.eq(picture.get_size(), extent, "capture keeps native canvas dimensions")
	_check.eq(picture.save_png(_output.path_join(name)), OK, "native screenshot is written")
	_shots.append({"file": name, "language": Loc.lang, "width": extent.x, "height": extent.y, "state": state})
