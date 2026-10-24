extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _shop_sim() -> Sim:
	var sim := Sim.new(901)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 500
	sim.shop.offers.clear()
	return sim


func _open(sim: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	return ui


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child: Node in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _set_weapons(sim: Sim, ids: Array[StringName]) -> void:
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for id: StringName in ids:
		sim.player.add_weapon(Content.weapon(id))


func test_sell_button_uses_quote_and_last_weapon_has_accessible_reason(c: Check) -> void:
	var sim := _shop_sim()
	_set_weapons(sim, [&"pistol", &"smg"])
	sim.player.weapon_levels[1] = 2
	var ui := _open(sim)
	var quote := sim.shop.quote(ShopResult.SELL, sim, null, 1)
	c.ok(quote.ok and quote.cost < 0, "mechanics exposes the sell refund quote")
	c.eq(ui.build_panel._sell_buttons[1].text, Loc.t("shop.sell", [absi(quote.cost)]),
			"sell label displays the authoritative quote")
	ui.build_panel._sell_buttons[1].pressed.emit()
	var last := ui.build_panel._sell_buttons[0]
	c.ok(last.disabled, "last weapon sell action is disabled")
	c.eq(last.accessibility_description, Loc.t("shop.sell_last_reason"),
			"disabled action explains why one weapon must remain")
	var before := ShopState.capture(sim).to_dict()
	last.pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), before,
			"disabled last-weapon action has no mutation callback")
	ui.free()


func test_sale_refund_focus_and_audio_follow_committed_result_once(c: Check) -> void:
	var sim := _shop_sim()
	_set_weapons(sim, [&"pistol", &"rifle"])
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	var quote := sim.shop.quote(ShopResult.SELL, sim, null, 1)
	var materials_before := sim.player.materials
	var audio := GameAudio.new()
	_root().add_child(audio)
	audio.bind(sim)
	var ui := _open(sim)
	ui.build_panel._sell_buttons[1].pressed.emit()
	c.eq(sim.player.materials, materials_before + absi(quote.cost),
			"committed sale refunds the exact quoted materials")
	c.ok(ui.build_panel._upgrade_buttons[0].disabled,
			"remaining max-level weapon has no upgrade focus target")
	c.ok(ui.undo_button.has_focus(), "sale falls back to focused Undo")
	c.eq(audio.play_count(&"buy"), 1, "sale uses one existing transaction cue")
	c.eq(audio.play_count(&"equipment_apply"), 0, "sale does not duplicate the purchase cue")
	ui.undo_button.pressed.emit()
	c.eq(audio.play_count(&"buy"), 1, "undo does not replay the sale cue")
	c.eq(audio.play_count(&"equipment_undo"), 1, "sale undo plays exactly one undo cue")
	ui.free()
	audio.free()


func test_middle_same_id_sale_and_undo_target_only_real_slot_changes(c: Check) -> void:
	var sim := _shop_sim()
	_set_weapons(sim, [&"pistol", &"pistol", &"pistol", &"pistol"])
	var ui := _open(sim)
	var mastery := Loc.t("shop.family_mastery_sidearm")
	c.ok(_has_label(ui.build_panel, mastery), "four-piece family mastery starts visible")
	ui.build_panel._sell_buttons[1].pressed.emit()
	c.ok(not _has_label(ui.build_panel, mastery), "middle sale updates family four to three")
	c.eq(ui.pending_feedback_count(), 2, "sale queues one removal and one refund cue")
	c.ok(bool(ui._pending_feedback[&"materials"].get("refund", false)),
			"material cue is identified as a refund from the committed result")
	ui.flush_feedback()
	c.eq(ui.build_panel.empty_drop_target.feedback_runs, 1,
			"removed weapon pulses the newly empty mount")
	for target: ShopDropTarget in ui.build_panel.slot_drop_targets:
		c.eq(target.feedback_runs, 0, "shifted same-ID slots never receive a fake sale pulse")
	c.eq(ui.material_feedback_runs, 1, "refund counter pulses once")
	ui.undo_button.pressed.emit()
	c.ok(_has_label(ui.build_panel, mastery), "undo restores family three to four")
	c.eq(ui.pending_feedback_count(), 2, "undo queues one reinsertion and one material rewind")
	ui.flush_feedback()
	c.eq(ui.build_panel.slot_drop_targets[1].feedback_runs, 1,
			"undo reinsertion pulses the restored original slot")
	c.ok(ui.build_panel.slot_drop_targets[1].last_feedback_reverse,
			"restored slot uses reverse feedback")
	for i in ui.build_panel.slot_drop_targets.size():
		if i != 1:
			c.eq(ui.build_panel.slot_drop_targets[i].feedback_runs, 0,
					"undo leaves every unaffected slot still")
	c.eq(ui.material_feedback_runs, 2, "refund rewind pulses materials exactly once")
	ui.free()
