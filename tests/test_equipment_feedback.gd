extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _shop_sim(materials: int = 500) -> Sim:
	var s := Sim.new(9901)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = materials
	s.shop.offers.clear()
	return s


func _weapon_offer(s: Sim, id: StringName, price: int = 20) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(id)
	offer.price = price
	s.shop.offers.append(offer)
	return offer


func _item_offer(s: Sim, id: StringName, price: int = 12) -> Offer:
	var offer := Offer.new()
	offer.item = Content.item(id)
	offer.price = price
	s.shop.offers.append(offer)
	return offer


func _open(s: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(s)
	return ui


func test_weapon_buy_feedback_waits_for_rebuilt_slot(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"smg")
	var ui := _open(s)
	c.ok(ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon").ok, "weapon bought")
	c.eq(ui.pending_feedback_count(), 2, "slot and materials wait after commit")
	c.eq(ui.build_panel.slot_drop_targets[1].feedback_runs, 0,
			"new slot is not animated before deferred flush")
	ui.flush_feedback()
	c.eq(ui.pending_feedback_count(), 0, "feedback queue consumed")
	c.eq(ui.build_panel.slot_drop_targets[1].feedback_runs, 1,
			"feedback lands on rebuilt slot")
	c.ok(not ui.build_panel.slot_drop_targets[1].last_feedback_reverse,
			"purchase seats forward")
	c.eq(ui.material_feedback_runs, 1, "final materials counter pulses once")
	ui.free()


func test_quick_upgrades_coalesce_on_current_card(c: Check) -> void:
	var s := _shop_sim()
	var ui := _open(s)
	ui._on_upgrade_weapon(0)
	ui._on_upgrade_weapon(0)
	c.eq(ui.pending_feedback_count(), 2, "repeated slot and material events coalesce")
	ui.flush_feedback()
	c.eq(ui.build_panel.slot_drop_targets[0].feedback_runs, 1,
			"only current rebuilt card pulses")
	c.eq(ui.material_feedback_runs, 1, "quick material changes coalesce")
	c.eq(ui.last_feedback.get("action", &""), ShopResult.UPGRADE,
			"latest feedback retains action metadata")
	ui.free()


func test_undo_rewinds_weapon_and_removed_slot_target(c: Check) -> void:
	var s := _shop_sim()
	var offer := _weapon_offer(s, &"smg")
	var ui := _open(s)
	ui.apply_drop(ui.drag_payload_for(offer), &"empty_weapon")
	ui.flush_feedback()
	ui.undo_button.pressed.emit()
	c.eq(ui.pending_feedback_count(), 2, "undo queues slot and material rewind")
	ui.flush_feedback()
	c.eq(ui.build_panel.slot_drop_targets.size(), 1, "bought slot was removed")
	c.ok(ui.build_panel.empty_drop_target != null, "empty mount is rebuilt")
	c.eq(ui.build_panel.empty_drop_target.feedback_runs, 1,
			"removed slot rewinds into empty mount")
	c.ok(ui.build_panel.empty_drop_target.last_feedback_reverse, "undo uses reverse feedback")
	ui.free()


func test_item_install_and_undo_use_current_item_target(c: Check) -> void:
	var s := _shop_sim()
	var offer := _item_offer(s, &"sharp_edge")
	var ui := _open(s)
	ui.apply_drop(ui.drag_payload_for(offer), &"items")
	ui.flush_feedback()
	c.eq(ui.build_panel.items_drop_target.feedback_runs, 1, "item install pulses item target")
	c.ok(not ui.build_panel.items_drop_target.last_feedback_reverse,
			"item install is forward")
	ui.undo_button.pressed.emit()
	ui.flush_feedback()
	c.eq(ui.build_panel.items_drop_target.feedback_runs, 1,
			"rebuilt item target receives one undo pulse")
	c.ok(ui.build_panel.items_drop_target.last_feedback_reverse,
			"item removal uses reverse feedback")
	ui.free()


func test_reduced_effects_and_reset_restore_rest_state(c: Check) -> void:
	var s := _shop_sim()
	var offer := _item_offer(s, &"sharp_edge")
	var ui := _open(s)
	ui.set_reduced_effects(true)
	ui.apply_drop(ui.drag_payload_for(offer), &"items")
	ui.flush_feedback()
	var target := ui.build_panel.items_drop_target
	c.eq(target.feedback_runs, 1, "reduced feedback still confirms action")
	c.eq(target.scale, Vector2.ONE, "reduced feedback does not scale UI")
	c.eq(ui._materials.scale, Vector2.ONE, "reduced material feedback does not scale")
	ui.reset_feedback()
	c.eq(target.scale, Vector2.ONE, "target reset restores scale")
	c.eq(target.modulate, Color.WHITE, "target reset restores colour")
	c.eq(ui._materials.modulate, Color.WHITE, "material reset restores colour")
	ui.free()


func test_feedback_queue_is_bounded_expires_and_never_mutates_sim(c: Check) -> void:
	var s := _shop_sim()
	var ui := _open(s)
	var before := ShopState.capture(s).to_dict()
	for i in 14:
		var info := WeaponChangeInfo.new()
		info.index = i
		info.before_id = &"pistol"
		info.after_id = &"smg"
		info.reason = ShopResult.REPLACE
		info.ok = true
		ui._on_weapon_changed(info)
	c.ok(ui.pending_feedback_count() <= ShopUi.MAX_PENDING_FEEDBACK,
			"feedback metadata is capped")
	c.eq(ShopState.capture(s).to_dict(), before, "presentation events do not mutate sim")
	ui.reset_feedback()
	ui._pending_feedback[&"expired"] = {
		"kind": &"items", "index": -1, "reverse": false,
		"action": ShopResult.BUY,
		"queued_at_msec": Time.get_ticks_msec() - ShopUi.FEEDBACK_EXPIRY_MSEC - 1,
	}
	ui.flush_feedback()
	c.eq(ui.build_panel.items_drop_target.feedback_runs, 0, "expired event is discarded")
	c.eq(ui.pending_feedback_count(), 0, "expired queue is cleared")
	ui.free()


func test_hidden_and_rebound_ui_drop_old_feedback_safely(c: Check) -> void:
	var old_sim := _shop_sim()
	var old_offer := _weapon_offer(old_sim, &"smg")
	var ui := _open(old_sim)
	c.ok(old_sim.shop.apply(ShopResult.BUY, old_sim, old_offer).ok,
			"external action emits feedback metadata")
	c.ok(ui.pending_feedback_count() > 0, "old binding queued feedback")
	var new_sim := _shop_sim()
	ui.open(new_sim)
	c.eq(ui.pending_feedback_count(), 0, "rebind clears old pending metadata")
	var second_old := _item_offer(old_sim, &"sharp_edge")
	c.ok(old_sim.shop.apply(ShopResult.BUY, old_sim, second_old).ok,
			"old shop can still operate independently")
	c.eq(ui.pending_feedback_count(), 0, "disconnected old signals cannot queue UI feedback")
	var new_offer := _item_offer(new_sim, &"sharp_edge")
	c.ok(new_sim.shop.apply(ShopResult.BUY, new_sim, new_offer).ok,
			"current shop event queues")
	ui.visible = false
	ui.refresh()
	ui.flush_feedback()
	c.eq(ui.pending_feedback_count(), 0, "hidden UI drops pending metadata")
	c.eq(ui.material_feedback_runs, 0, "hidden UI runs no visual feedback")
	ui.free()


func test_close_session_clears_old_run_references_and_callbacks(c: Check) -> void:
	var old_sim := _shop_sim()
	var old_offer := _weapon_offer(old_sim, &"smg")
	var take := EchoTake.new()
	take.wave = 1
	take.weapons.append(Content.weapon(&"pistol"))
	old_sim.bank.add(take)
	var ui := _open(old_sim)
	c.ok(ui.echo_panel._sim == old_sim, "echo panel holds current run while open")
	c.ok(old_sim.shop.apply(ShopResult.BUY, old_sim, old_offer).ok,
			"old action queues feedback before close")
	c.ok(ui.pending_feedback_count() > 0, "feedback is pending before close")
	var old_epoch := ui._feedback_epoch
	ui.close_session()
	c.ok(not ui.visible and ui.sim == null, "closed shop hides and clears sim")
	c.ok(ui._connected_shop == null and ui._connected_sim == null,
			"old signal bindings are cleared")
	c.ok(ui._feedback_epoch > old_epoch and ui.pending_feedback_count() == 0,
			"close invalidates deferred feedback")
	c.eq(ui.offers_box.get_child_count(), 0, "offer controls and payload references cleared")
	c.eq(ui.build_panel._box.get_child_count(), 0, "build controls cleared")
	c.ok(ui.echo_panel._sim == null and ui.echo_panel._box.get_child_count() == 0,
			"echo controls and simulation reference cleared")
	c.ok(ui.echo_panel.discard_buttons.is_empty() and ui.echo_panel.last_new_row == null,
			"echo action and arrival references cleared")
	var old_item := _item_offer(old_sim, &"sharp_edge")
	c.ok(old_sim.shop.apply(ShopResult.BUY, old_sim, old_item).ok,
			"old simulation remains independently usable")
	c.eq(ui.pending_feedback_count(), 0, "closed UI ignores old callbacks")
	var new_sim := _shop_sim()
	ui.open(new_sim)
	c.ok(ui.visible and ui.sim == new_sim, "closed UI can bind a fresh run")
	c.ok(ui.build_panel._box.get_child_count() > 0, "fresh run rebuilds build controls")
	c.ok(ui.echo_panel._sim == new_sim, "fresh run rebinds echo panel")
	ui.free()
