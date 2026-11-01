extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _sim_with_takes(count: int) -> Sim:
	var sim := Sim.new(311)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 100
	sim.shop.roll(sim)
	for i in count:
		var take := EchoTake.new()
		take.wave = i + 1
		take.condition = 60.0
		take.weapons.append(Content.weapon(&"pistol"))
		take.samples = PackedVector2Array([Vector2(200.0, 200.0), Vector2(500.0, 400.0)])
		sim.bank.add(take)
	return sim


func test_shop_keeps_primary_actions_outside_scrolling_stock(c: Check) -> void:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(_sim_with_takes(2))
	c.eq(ui.offers_box.get_child_count(), Shop.OFFER_COUNT, "all real quotes remain available")
	c.ok(ui._offers_scroll.follow_focus, "scrolling stock follows keyboard and controller focus")
	for action: Button in [ui.start_button, ui.reroll_button, ui.undo_button]:
		c.ok(not ui._offers_scroll.is_ancestor_of(action), "primary actions stay in a fixed task tray")
	c.ok((ui.get_child(1) as Control).get_combined_minimum_size().x <= 1280.0,
			"paper shop fits the 720p reference width")
	ui.close_session()
	ui.free()


func test_eight_copies_page_without_blocking_nonoverflow(c: Check) -> void:
	var sim := _sim_with_takes(8)
	var before := ShopState.capture(sim).to_dict()
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	c.eq(ui.echo_panel.discard_buttons.size(), ui.echo_panel.page_size, "copy actions are bounded by page size")
	c.eq(ui.echo_panel.find_children("*", "ScrollContainer", true, false).size(), 0, "no nested copy scrolling")
	c.ok(ui.echo_panel.page_next != null and not ui.echo_panel.page_next.disabled, "remaining copies have an explicit page action")
	c.ok(not ui.start_button.disabled, "overflow does not block departure")
	ui.echo_panel.page_next.pressed.emit()
	c.eq(ui.echo_panel.page, 1, "paging changes only the visible bank page")
	c.eq(ShopState.capture(sim).to_dict(), before, "paging never mutates the bank")
	ui.free()


func test_long_lived_copy_still_uses_exact_seconds_and_condition(c: Check) -> void:
	var sim := _sim_with_takes(1)
	sim.player.stats.add(Stats.ECHO_DURATION, 280.0)
	var panel := EchoPanel.new()
	_root().add_child(panel)
	panel.refresh(sim)
	var found := false
	for label: Label in panel.find_children("*", "Label", true, false):
		if label.text.contains(Loc.t("echo.condition", [60, 240])):
			found = true
	c.ok(found, "long playback is an exact condition and seconds label")
	c.eq(panel.discard_buttons.size(), 1, "duration never creates extra meter controls")
	panel.free()


func test_arriving_copy_uses_the_actual_arena_transform(c: Check) -> void:
	var host := Node2D.new()
	_root().add_child(host)
	var arena := ArenaView.new()
	arena.position = Vector2(31.0, 17.0)
	host.add_child(arena)
	var layer := CanvasLayer.new()
	host.add_child(layer)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	layer.add_child(ui)
	var first := ui._arrival_origin()
	arena.position += Vector2(23.0, 19.0)
	c.eq(ui._arrival_origin() - first, Vector2(23.0, 19.0),
			"moving the actual arena moves the arrival source equally")
	host.free()


func test_paper_press_and_staple_respect_reduced_motion(c: Check) -> void:
	var sim := _sim_with_takes(2)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.set_reduced_effects(true)
	ui.open(sim)
	var card := ui.offers_box.get_child(0) as OfferCard
	card._press_paper()
	c.eq(card.scale, Vector2.ONE, "reduced motion keeps paper purchases stationary")
	ui.echo_panel.confirm_merge()
	var row := ui.echo_panel._takes_box.get_child(0) as Control
	c.eq(row.scale, Vector2.ONE, "reduced motion keeps the staple confirmation stationary")
	ui.free()
