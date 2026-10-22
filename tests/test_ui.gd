extends RefCounted

const DT := 1.0 / 60.0


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _quick_wave(s: Sim) -> void:
	s.wave_duration = 0.05
	for i in 5:
		s.step(DT, Vector2.ZERO)


func _shop_sim(materials: int = 1000, waves: int = 1) -> Sim:
	var s := Sim.new(3)
	s.start_run()
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	_quick_wave(s)
	for i in waves - 1:
		s.start_next_wave()
		_quick_wave(s)
	s.player.materials = materials
	return s


func _open_shop(s: Sim) -> ShopUi:
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(s)
	return ui


func test_shop_lists_offers_and_buying_rebuilds_the_cards(c: Check) -> void:
	var s := _shop_sim()
	var ui := _open_shop(s)
	c.ok(ui.visible, "shop is shown")
	c.eq(ui.size, _root().get_visible_rect().size, "shop covers the whole screen")
	c.eq(ui.offers_box.get_child_count(), Shop.OFFER_COUNT, "one card per offer")
	var card := ui.offers_box.get_child(0) as OfferCard
	c.ok(not card.disabled, "affordable card is enabled")
	var offer := card.offer
	var before := s.player.materials
	card.pressed.emit()
	c.ok(offer.sold, "the offer was bought")
	c.eq(s.player.materials, before - offer.price, "materials spent")
	c.eq(ui.offers_box.get_child_count(), Shop.OFFER_COUNT, "cards rebuilt")
	c.ok((ui.offers_box.get_child(0) as OfferCard).disabled, "sold card is disabled")
	ui.free()


func test_poor_player_cannot_press_anything_but_start(c: Check) -> void:
	var s := _shop_sim(0)
	var ui := _open_shop(s)
	for card in ui.offers_box.get_children():
		c.ok((card as OfferCard).disabled, "every card is disabled with no materials")
	c.ok(ui.reroll_button.disabled, "reroll disabled")
	c.ok(not ui.start_button.disabled, "start still available")
	ui.free()


func test_reroll_button_restocks_and_charges(c: Check) -> void:
	var s := _shop_sim(100)
	var ui := _open_shop(s)
	var cost := s.shop.reroll_cost(s.wave)
	ui.reroll_button.pressed.emit()
	c.eq(s.shop.rerolls, 1, "rerolled once")
	c.eq(s.player.materials, 100 - cost, "reroll charged")
	c.eq(ui.offers_box.get_child_count(), Shop.OFFER_COUNT, "cards rebuilt")
	ui.free()


func test_start_waits_for_discards_when_echoes_overflow(c: Check) -> void:
	var s := _shop_sim(50, 3)
	c.eq(s.bank.takes.size(), 3, "three takes recorded")
	c.eq(s.echo_capacity(), 2, "two slots")
	var ui := _open_shop(s)
	c.ok(ui.start_button.disabled, "start blocked while over capacity")
	c.eq(ui.echo_panel.discard_buttons.size(), 3, "a discard button per take")
	var started := [false]
	ui.start_requested.connect(func() -> void: started[0] = true)
	ui.start_button.pressed.emit()
	c.ok(not started[0], "a blocked start does nothing")
	ui.echo_panel.discard_buttons[0].pressed.emit()
	c.eq(s.bank.takes.size(), 2, "one take discarded")
	c.ok(not ui.start_button.disabled, "start unlocked")
	ui.start_button.pressed.emit()
	c.ok(started[0], "start fires")
	c.ok(not ui.visible, "shop hides itself")
	ui.free()


func test_end_screen_offers_a_restart(c: Check) -> void:
	var s := _shop_sim()
	s.phase = Sim.Phase.LOST
	var ui := EndUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	c.ok(not ui.visible, "hidden until a run ends")
	ui.show_result(s)
	c.ok(ui.visible, "shown")
	c.eq(ui.size, _root().get_visible_rect().size, "end screen covers the whole screen")
	var restarts := [0]
	ui.restart_requested.connect(func() -> void: restarts[0] += 1)
	ui.restart_button.pressed.emit()
	c.eq(restarts[0], 1, "restart requested")
	s.phase = Sim.Phase.WON
	ui.show_result(s)
	c.ok(ui.visible, "also shown on a win")
	ui.free()


func test_hud_weapon_slots_show_cooldown_readiness(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var h := Hud.new()
	h.bind(s)
	c.near(h.weapon_ready(0), 1.0, 0.01, "a fresh weapon reads as ready")
	var w := s.player.weapons[0]
	s.player.cooldowns[0] = w.cooldown * s.player.stats.cooldown_mult()
	c.near(h.weapon_ready(0), 0.0, 0.02, "just fired reads as empty")
	s.player.cooldowns[0] = w.cooldown * s.player.stats.cooldown_mult() * 0.5
	c.near(h.weapon_ready(0), 0.5, 0.02, "the fill tracks the cooldown")
	c.near(h.weapon_ready(99), 0.0, 0.001, "missing slot is empty")
	h.free()


func test_hud_echo_chips_count_remaining_waves(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var h := Hud.new()
	h.bind(s)
	var take := EchoTake.new()
	take.age = 1
	c.eq(h.echo_remaining(take), s.echo_lifespan() - 1, "age eats one wave of life")
	take.age = 99
	c.eq(h.echo_remaining(take), 0, "expired takes never go negative")
	h.free()


func test_hud_first_run_hint_fades(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var h := Hud.new()
	h.bind(s)
	c.near(h.hint_alpha(), 1.0, 0.001, "controls are visible at the start")
	h._hint_time = 4.75
	c.near(h.hint_alpha(), 0.5, 0.05, "the hint fades out")
	h._hint_time = 6.0
	c.near(h.hint_alpha(), 0.0, 0.001, "and is gone")
	h._hint_time = 0.0
	s.wave = 2
	c.near(h.hint_alpha(), 0.0, 0.001, "only the first wave gets the hint")
	h.free()


func test_offer_card_compares_weapon_dps(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var stats := s.player.stats
	c.near(OfferCard.weapon_dps(Content.weapon(&"pistol"), stats), 14.7, 0.05,
			"pistol DPS includes the base crit chance")
	c.near(OfferCard.total_dps(s.player), 14.7, 0.05, "one starting weapon")
	s.player.add_item(Content.item(&"sharp_edge"))
	c.near(OfferCard.weapon_dps(Content.weapon(&"pistol"), stats), 16.17, 0.05,
			"damage items flow into the shown DPS")
	c.ok(OfferCard.weapon_dps(Content.weapon(&"rifle"), stats) > 14.0, "rifle is comparable per shot")


func test_echo_path_reveals_at_wave_start(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var view := ArenaView.new()
	view.bind(s)
	var take := EchoTake.new()
	take.wave = 1
	take.samples = PackedVector2Array([
		Vector2(400.0, 300.0), Vector2(500.0, 320.0), Vector2(600.0, 380.0), Vector2(700.0, 420.0),
	])
	s.bank.add(take)
	s.start_wave(2)
	c.eq(s.echoes.size(), 1, "the take became an echo")
	var actor: EchoActor = s.echoes[0]
	c.ok(view._reveal.has(actor), "the view tracks a reveal for it")
	c.near(float(view._reveal[actor]), 0.0, 0.001, "the route starts hidden")
	view._process(ArenaView.REVEAL_TIME * 0.5)
	c.near(float(view._reveal[actor]), 0.5, 0.05, "the route draws in over time")
	view._process(ArenaView.REVEAL_TIME)
	c.near(float(view._reveal[actor]), 1.0, 0.001, "and stays revealed")
	view.free()


func test_echo_reveals_stagger_for_readability(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	s.player.stats.values[Stats.ECHO_SLOTS] = 3.0
	var view := ArenaView.new()
	view.bind(s)
	for k in 3:
		var take := EchoTake.new()
		take.wave = k + 1
		take.samples = PackedVector2Array([
			Vector2(300.0 + k * 40.0, 300.0), Vector2(360.0 + k * 40.0, 340.0),
			Vector2(420.0 + k * 40.0, 400.0),
		])
		s.bank.add(take)
	s.start_wave(2)
	c.eq(s.echoes.size(), 3, "all three takes replay")
	c.near(float(view._reveal[s.echoes[0]]), -0.24, 0.001, "the oldest route waits its turn")
	c.near(float(view._reveal[s.echoes[2]]), 0.0, 0.001, "the newest route starts at once")
	view.free()


func test_shop_traces_the_new_take_only_on_open(c: Check) -> void:
	var s := _shop_sim(100, 3)
	var ui := _open_shop(s)
	var previews := ui.echo_panel.find_children("*", "PathPreview", true, false)
	c.eq(previews.size(), 3, "one route preview per take")
	var animating := 0
	for node in previews:
		if (node as PathPreview).is_animating():
			animating += 1
	c.eq(animating, 1, "only the new take traces in")
	ui.refresh()
	previews = ui.echo_panel.find_children("*", "PathPreview", true, false)
	animating = 0
	for node in previews:
		if (node as PathPreview).is_animating():
			animating += 1
	c.eq(animating, 0, "buying or rerolling does not replay the arrival")
	ui.free()


func test_echo_kills_use_the_echo_tint(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var take := EchoTake.new()
	take.tint_index = 0
	s.echoes.append(EchoActor.new(take, 0))
	var view := ArenaView.new()
	view.bind(s)
	c.ok(view.kill_color(0, Color.WHITE) != Color.WHITE, "echo kills borrow the echo colour")
	c.eq(view.kill_color(-1, Color.RED), Color.RED, "player kills keep the enemy colour")
	c.eq(view.kill_color(9, Color.RED), Color.RED, "a missing echo falls back safely")
	view.free()


func test_main_runs_the_whole_loop(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(5)
	var s: Sim = main.sim
	c.eq(s.wave, 1, "a run starts on wave 1")
	main.toggle_pause()
	var t0 := s.wave_time
	main._physics_process(DT)
	c.eq(s.wave_time, t0, "pausing freezes the sim")
	main.toggle_pause()
	main._physics_process(DT)
	c.ok(s.wave_time > t0, "resuming advances the sim")
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	s.wave_duration = 0.05
	main._physics_process(DT)
	main._physics_process(DT)
	c.eq(s.phase, Sim.Phase.SHOP, "wave ended")
	c.ok(main.hud.visible, "the HUD holds the arena for the record beat")
	c.ok(not main.shop_ui.visible, "the shop waits for the beat")
	for i in 60:
		main._physics_process(DT)
	c.ok(main.shop_ui.visible, "the shop opens after the beat")
	c.ok(not main.hud.visible, "the HUD gives way to the shop")
	main.toggle_pause()
	c.ok(not main.paused, "cannot pause inside the shop")
	main.shop_ui.start_button.pressed.emit()
	c.eq(s.phase, Sim.Phase.WAVE, "wave two started")
	c.ok(main.hud.visible, "the HUD is back during the wave")
	c.eq(s.wave, 2, "wave counter advanced")
	s.player.hp = 0.0
	main._physics_process(DT)
	c.eq(s.phase, Sim.Phase.LOST, "player died")
	c.ok(main.end_ui.visible, "end screen shown")
	main.end_ui.restart_button.pressed.emit()
	c.ok(main.sim != s, "restart builds a fresh sim")
	c.eq(main.sim.wave, 1, "back on wave 1")
	c.eq(main.sim.phase, Sim.Phase.WAVE, "playing again")
	c.ok(not main.end_ui.visible, "end screen hidden")
	main.free()
