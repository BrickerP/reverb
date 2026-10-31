extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _sim(materials: int = 200) -> Sim:
	var sim := Sim.new(283)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = materials
	sim.shop.offers.clear()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 20
	sim.shop.offers.append(offer)
	return sim


func _open(sim: Sim, reduced: bool = true) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.set_reduced_effects(reduced)
	ui.open(sim)
	return ui


func test_vendor_reacts_to_committed_purchase_not_preview_or_drag(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	var offer := sim.shop.offers[0]
	var card := ui.offers_box.get_child(0) as OfferCard
	var payload: Variant = ui.drag_payload_for(offer)
	var before := ShopState.capture(sim).to_dict()
	card.button_down.emit()
	ui.quote_drop(payload, &"empty_weapon")
	c.eq(ui.vendor_feedback_runs, 0, "pointing and quoting never celebrate a sale")
	c.eq(ShopState.capture(sim).to_dict(), before, "decorative press and quote do not mutate a run")
	card.drag_started()
	card.pressed.emit()
	c.eq(sim.player.weapons.size(), 1, "drag release cannot accidentally purchase")
	c.eq(ui.vendor_feedback_runs, 0, "drag guard also guards the vendor reaction")
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(sim.player.weapons.size(), 2, "deliberate real offer click buys immediately")
	c.eq(ui.last_vendor_reaction, &"buy", "committed purchase selects the vendor's sale reaction")
	c.eq(ui.vendor_feedback_runs, 1, "one transaction produces one vendor reaction")
	c.eq(ui._vendor_line.text, Loc.t("shop.vendor_buy"), "sale joke is visible independently of rules")
	var sold_before := ShopState.capture(sim).to_dict()
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(ShopState.capture(sim).to_dict(), sold_before, "sold stock remains inert")
	c.eq(ui.vendor_feedback_runs, 1, "sold stock cannot repeat the success reaction")
	ui.free()


func test_poor_reaction_keeps_the_material_rule_visible(c: Check) -> void:
	var sim := _sim(0)
	var ui := _open(sim)
	var before := ShopState.capture(sim).to_dict()
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	c.eq(ui.last_vendor_reaction, &"poor", "insufficient funds produces the empty-pocket reaction")
	c.eq(ui._vendor_line.text, Loc.t("shop.vendor_poor"), "merchant has a separate short reaction")
	c.eq(ui._footer.text, Loc.t("shop.drop_poor"), "the literal insufficient-material explanation stays visible")
	c.eq(ShopState.capture(sim).to_dict(), before, "failed purchase never changes the transaction state")
	c.eq(ui.pending_feedback_count(), 0, "failed purchase never queues installation feedback")
	ui.free()


func test_undo_and_reroll_use_their_committed_actions(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim)
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	ui.undo_button.pressed.emit()
	c.eq(sim.player.weapons.size(), 1, "undo restores the previous build immediately")
	c.eq(ui.last_vendor_reaction, &"undo", "undo returns a discarded piece to its owner")
	c.eq(ui._vendor_line.text, Loc.t("shop.vendor_undo"), "undo has its own reaction")
	var reactions := ui.vendor_feedback_runs
	ui.undo_button.pressed.emit()
	c.eq(ui.vendor_feedback_runs, reactions, "empty undo cannot invent a successful return")
	ui.reroll_button.pressed.emit()
	c.eq(ui.last_vendor_reaction, &"reroll", "reroll announces the actual new stock batch")
	c.eq(sim.shop.offers.size(), Shop.OFFER_COUNT, "all actual offers are rebuilt before input resumes")
	ui.free()


func test_receipt_motion_never_changes_interaction_rectangles(c: Check) -> void:
	var sim := _sim()
	var ui := _open(sim, false)
	var card := ui.offers_box.get_child(0) as OfferCard
	var transform: Transform2D = card.get_transform()
	card.button_down.emit()
	c.eq(card.get_transform(), transform, "only decorative merchandise compresses on a press")
	card.button_up.emit()
	card.pressed.emit()
	c.ok(ui._vendor_receipt != null, "real purchase starts a decorative price-tag receipt")
	c.eq(ui._vendor_receipt.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"the swallowed tag cannot intercept another action")
	c.ok(not ui.start_button.disabled, "receipt animation never delays the next-wave action")
	ui.set_reduced_effects(true)
	c.ok(ui._vendor_receipt == null, "reduced effects immediately removes traveling tags")
	c.eq(ui._vendor_art.scale, Vector2.ONE, "reduced effects settles the merchant art")
	c.eq(ui._vendor_line.text, Loc.t("shop.vendor_buy"), "reduced effects preserves the reaction's meaning")
	ui.free()


func test_staple_reaction_requires_a_real_two_copy_merge(c: Check) -> void:
	var sim := _sim()
	for i in 2:
		var take := EchoTake.new()
		take.wave = i + 1
		take.weapons.append(Content.weapon(&"pistol"))
		take.samples = PackedVector2Array([Vector2(200.0, 200.0), Vector2(500.0, 400.0)])
		sim.bank.add(take)
	var ui := _open(sim)
	var first := sim.bank.takes[0]
	c.ok(not sim.shop.merge_echoes(sim, first, first).ok, "same-copy merge is rejected")
	c.eq(ui.vendor_feedback_runs, 0, "invalid merge cannot produce a staple celebration")
	ui.echo_panel.merge_button.pressed.emit()
	c.ok(ui.workshop.choice_buttons.size() > 0, "one sheet lists every host, donor and trait")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(sim.bank.takes.size(), 1, "two real copies are joined into one")
	c.eq(ui.last_vendor_reaction, &"merge", "actual merge produces the staple reaction")
	c.eq(ui._vendor_line.text, Loc.t("shop.vendor_merge"), "the reaction describes two mistakes and one staple")
	var row := ui.echo_panel._takes_box.get_child(0) as Control
	c.eq(row.rotation, 0.0, "the merged copy's buttons stay level")
	c.eq(row.scale, Vector2.ONE, "reduced effects keeps the copy's hit rectangles stationary")
	ui.free()


func test_reduced_rejection_and_material_confirmation_create_no_tweens(c: Check) -> void:
	var ui := _open(_sim(), true)
	var tree := Engine.get_main_loop() as SceneTree
	var before := tree.get_processed_tweens().size()
	var card := ui.offers_box.get_child(0) as OfferCard
	card.reject(true)
	ui.build_panel.empty_drop_target.reject(true)
	ui._pulse_materials(false)
	c.eq(tree.get_processed_tweens().size(), before,
			"reduced feedback creates neither colour nor geometry tweens")
	c.eq(card.price_tag.modulate, Color.WHITE, "reduced rejection lands on a static readable tag")
	c.eq(ui._materials.modulate, Color.WHITE, "reduced confirmation leaves the counter at rest")
	ui.free()


func test_undo_sale_returns_the_actual_weapon_to_the_build(c: Check) -> void:
	var sim := _sim()
	sim.player.add_weapon(Content.weapon(&"rifle"))
	var ui := _open(sim, false)
	ui._open_weapon_workshop(1)
	ui.workshop.choice_buttons[3].pressed.emit()
	c.eq(sim.player.weapons.size(), 1, "the selected weapon is sold")
	ui.undo_button.pressed.emit()
	c.eq(sim.player.weapons.size(), 2, "undo restores the sold weapon")
	c.eq(sim.player.materials, 200, "undo sale charges back the actual refund")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_source"), ui._vendor_art,
			"restored merchandise leaves the vendor")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_target"), ui.build_panel,
			"undo sale returns the object to equipment, not a false cash refund")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_object"), &"weapon_rifle",
			"the returning receipt carries the restored weapon's identity")
	ui.free()


func test_undo_discard_and_merge_return_copies_to_the_copy_archive(c: Check) -> void:
	var sim := _sim()
	for i in 2:
		var take := EchoTake.new()
		take.wave = i + 1
		take.weapons.append(Content.weapon(&"pistol"))
		take.samples = PackedVector2Array([Vector2(200.0, 200.0), Vector2(500.0, 400.0)])
		sim.bank.add(take)
	var ui := _open(sim, false)
	ui.echo_panel.discard_buttons[0].pressed.emit()
	c.eq(sim.bank.takes.size(), 1, "a real copy is discarded")
	ui.undo_button.pressed.emit()
	c.eq(sim.bank.takes.size(), 2, "undo restores the exact copy inventory")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_target"), ui.echo_panel,
			"a discarded copy returns to the archive rather than the material counter")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_object"), &"recording_cartridge",
			"copy returns use the paper-copy graphic")
	ui.echo_panel.merge_button.pressed.emit()
	c.ok(ui.workshop.choice_buttons.size() > 0, "one sheet lists every host, donor and trait")
	ui.workshop.choice_buttons[0].pressed.emit()
	c.eq(sim.bank.takes.size(), 1, "two copies are actually stapled")
	ui.undo_button.pressed.emit()
	c.eq(sim.bank.takes.size(), 2, "undo separates the real copy inventory")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_source"), ui._vendor_art,
			"unstapled copies come back from the vendor")
	c.eq(ui._vendor_receipt.get_meta(&"shop_receipt_target"), ui.echo_panel,
			"unstapled copies return to their own archive")
	ui.free()


func _luminance(color: Color) -> float:
	var channels: Array[float] = []
	for value in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722


func _contrast(a: Color, b: Color) -> float:
	var first := _luminance(a)
	var second := _luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


func test_open_shop_captions_and_errors_stay_readable_on_the_dark_ground(c: Check) -> void:
	var ui := _open(_sim(), true)
	var ground := (ui.get_child(0) as ColorRect).color
	var canvas: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK)
	var backdrop := Color(ground.r * ground.a + canvas.r * (1.0 - ground.a),
			ground.g * ground.a + canvas.g * (1.0 - ground.a),
			ground.b * ground.a + canvas.b * (1.0 - ground.a))
	for label: Label in [ui._title, ui._footer, ui._warning, ui._interest, ui._vendor_line]:
		c.ok(_contrast(label.get_theme_color("font_color"), backdrop) >= 4.5,
				"open-ground shop text meets the 4.5:1 contrast threshold")
	ui._react_vendor(&"poor")
	c.ok(_contrast(ui._vendor_line.get_theme_color("font_color"), backdrop) >= 4.5,
			"the merchant's error reaction stays readable without a full-width paper bar")
	c.ok(_contrast(ui._materials.get_theme_color("font_color"), UiTheme.PAPER) >= 4.5,
			"the short material tag preserves dark-on-paper contrast")
	ui.free()
