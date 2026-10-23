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


func test_build_panel_can_evolve_a_maxed_weapon(c: Check) -> void:
	var s := _shop_sim(1000)
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	for i in 3:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	s.player.materials = Shop.evolution_cost(s.player.weapons[0])
	var ui := _open_shop(s)
	ui.build_panel._upgrade_buttons[0].pressed.emit()
	c.eq(s.player.weapons[0].id, &"twin_fangs", "build panel evolves the weapon")
	c.eq(s.player.materials, 0, "build panel spends the evolution cost")
	ui.free()


func test_build_panel_can_upgrade_an_equipped_weapon(c: Check) -> void:
	var s := _shop_sim(1000)
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.add_weapon(Content.weapon(&"pistol"))
	var ui := _open_shop(s)
	c.eq(ui.build_panel._upgrade_buttons.size(), 1, "one upgrade button per slot")
	var before := s.player.materials
	var cost := Shop.upgrade_cost(s.player.weapons[0], 0)
	ui.build_panel._upgrade_buttons[0].pressed.emit()
	c.eq(s.player.level_at(0), 1, "panel upgrade raises the slot level")
	c.eq(s.player.materials, before - cost, "panel upgrade spends materials")
	ui.free()


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


func test_poor_cards_stay_pressable_and_flash_materials(c: Check) -> void:
	var s := _shop_sim(0)
	var ui := _open_shop(s)
	var first: OfferCard = null
	for node in ui.offers_box.get_children():
		var card := node as OfferCard
		c.eq(card.blocked_reason, &"poor", "the reason is poor")
		c.ok(not card.disabled, "the card is still pressable so it can explain")
		if first == null:
			first = card
	c.ok(ui.reroll_button.disabled, "reroll disabled")
	c.ok(not ui.start_button.disabled, "start still available")
	var before := s.player.materials
	first.pressed.emit()
	c.eq(s.player.materials, before, "a blocked card buys nothing")
	c.ok(first.modulate.g < 0.9, "the clicked card flashes red")
	c.ok(ui._materials.modulate != Color.WHITE, "the materials counter flashes")
	ui.free()


func test_full_weapon_slots_flash_the_build_section(c: Check) -> void:
	var s := _shop_sim(100)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var bp := BuildPanel.new()
	bp.theme = UiTheme.build()
	_root().add_child(bp)
	bp.refresh(s)
	bp.flash_slots()
	c.ok(bp.weapons_label.modulate != Color.WHITE, "the weapon section flashes")
	bp.free()


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
	c.ok(ui.best_take != null, "the strongest recorded take is shown")
	ui.show_result(s, "Unlocked: Soloist")
	c.ok(ui._unlock.visible, "an unlock message is shown")
	ui.show_result(s)
	c.ok(not ui._unlock.visible, "and hidden without one")
	var restarts := [0]
	ui.restart_requested.connect(func() -> void: restarts[0] += 1)
	ui.restart_button.pressed.emit()
	c.eq(restarts[0], 1, "restart requested")
	var changes := [0]
	ui.character_requested.connect(func() -> void: changes[0] += 1)
	ui.character_button.pressed.emit()
	c.eq(changes[0], 1, "character change requested")
	var retried := [-1]
	ui.seed_retry_requested.connect(func(seed_value: int) -> void: retried[0] = seed_value)
	ui.retry_button.pressed.emit()
	c.eq(retried[0], s.run_seed, "seed retry carries the run seed")
	var logs := [0]
	ui.open_log_requested.connect(func() -> void: logs[0] += 1)
	ui.open_log_button.pressed.emit()
	c.eq(logs[0], 1, "open log folder requested")
	s.phase = Sim.Phase.WON
	ui.show_result(s)
	c.ok(ui.visible, "also shown on a win")
	ui.free()


func test_end_screen_picks_the_strongest_echo(c: Check) -> void:
	var s := _shop_sim()
	s.bank.takes.clear()
	var weak := EchoTake.new()
	weak.wave = 1
	weak.weapons.append(Content.weapon(&"pistol"))
	var strong := EchoTake.new()
	strong.wave = 2
	strong.weapons.append(Content.weapon(&"rifle"))
	s.bank.add(weak)
	s.bank.add(strong)
	s.phase = Sim.Phase.LOST
	var ui := EndUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.show_result(s)
	c.eq(ui.best_take, strong, "the highest-DPS take wins")
	c.ok(ui._best_row.visible, "the echo row is shown")
	s.bank.takes.clear()
	ui.show_result(s)
	c.eq(ui.best_take, null, "no take survives an early death")
	c.ok(not ui._best_row.visible, "the echo row hides")
	c.ok(ui._no_echo.visible, "the empty state is shown")
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
	s.player.add_weapon(Content.weapon(&"pistol"))
	c.ok(OfferCard.total_dps(s.player) > 2.0 * 16.17, "two sidearms activate the family bonus")


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


func test_full_weapon_slots_can_swap_in_place(c: Check) -> void:
	var s := _shop_sim(1000)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var ui := _open_shop(s)
	var o := Offer.new()
	o.weapon = Content.weapon(&"rifle")
	o.price = 34
	s.shop.offers.clear()
	s.shop.offers.append(o)
	ui.refresh()
	var card := ui.offers_box.get_child(0) as OfferCard
	c.eq(card.blocked_reason, &"full", "the offer reports full slots")
	card.pressed.emit()
	c.ok(ui.is_replacing(), "clicking a full weapon offer enters replace mode")
	c.ok(ui.build_panel.replacing, "the build panel shows slot buttons")
	var old := s.player.weapons[0]
	var resale := Shop.resale_value(old)
	var before := s.player.materials
	ui._on_replace_slot(0)
	c.eq(s.player.weapons[0], o.weapon, "the chosen slot gets the new weapon")
	c.eq(s.player.materials, before - o.price + resale, "the old weapon is traded in")
	c.ok(not ui.is_replacing(), "replace mode closes")
	c.ok(o.sold, "the offer is consumed")
	ui.free()


func test_replace_mode_can_be_cancelled(c: Check) -> void:
	var s := _shop_sim(1000)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var ui := _open_shop(s)
	var o := Offer.new()
	o.weapon = Content.weapon(&"rifle")
	o.price = 34
	s.shop.offers.clear()
	s.shop.offers.append(o)
	ui.refresh()
	(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	var old := s.player.weapons[0]
	var before := s.player.materials
	ui._cancel_replace()
	c.ok(not ui.is_replacing(), "cancel leaves replace mode")
	c.eq(s.player.weapons[0], old, "weapon untouched")
	c.eq(s.player.materials, before, "materials untouched")
	c.ok(not o.sold, "offer stays available")
	ui.free()


func test_boss_death_holds_the_end_screen(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(5)
	var s: Sim = main.sim
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	s.start_wave(WaveDirector.FINAL_WAVE)
	for i in 200:
		main._physics_process(DT)
	c.ok(s.boss != null, "the boss spawned")
	s.damage_enemy(s.boss, 100000.0, Vector2.ZERO, false, -1)
	main._physics_process(DT)
	c.eq(s.phase, Sim.Phase.WON, "boss death wins")
	c.ok(not main.end_ui.visible, "the end screen waits for the victory beat")
	for i in 70:
		main._physics_process(DT)
	c.ok(main.end_ui.visible, "the end screen arrives after the beat")
	main.free()


func test_shop_merges_two_takes(c: Check) -> void:
	var s := _shop_sim(50, 3)
	var ui := _open_shop(s)
	c.ok(ui.echo_panel.merge_button != null, "merge is offered with multiple takes")
	ui.echo_panel.merge_button.pressed.emit()
	c.ok(ui.echo_panel.is_merging(), "merge mode starts")
	ui.echo_panel.discard_buttons[0].pressed.emit()
	c.ok(ui.echo_panel.discard_buttons[0].text == Loc.t("shop.selected"), "first take is selected")
	ui.echo_panel.discard_buttons[1].pressed.emit()
	c.eq(s.bank.takes.size(), 2, "two takes became one")
	c.ok(not ui.echo_panel.is_merging(), "merge mode closes")
	var merged := 0
	for take: EchoTake in s.bank.takes:
		if take.merged:
			merged += 1
	c.eq(merged, 1, "one merged take")
	c.ok(not ui.start_button.disabled, "the overflow is resolved")
	ui.free()


func test_daily_starts_with_today_seed_and_records_best(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.start_daily()
	c.eq(main.character_id, &"looper", "daily uses the looper")
	c.eq(main.sim.run_seed, main.today_seed(), "daily seed comes from the date")
	c.ok(main._daily_run, "daily run is tagged")
	main.sim.phase = Sim.Phase.WON
	main.sim.wave = 20
	main._record_run()
	c.eq(main.meta.daily_best, 20, "daily best is recorded")
	main.free()


func test_main_settings_open_and_close(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.open_settings()
	c.ok(main.settings_ui.visible, "settings opens from the title screen")
	main.settings_ui.close()
	c.ok(not main.settings_ui.visible, "settings closes")
	main.open_history()
	c.ok(main.history_ui.visible, "history opens from the title screen")
	main.history_ui.close()
	c.ok(not main.history_ui.visible, "history closes")
	main.free()


func test_shake_can_be_disabled(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	var view := ArenaView.new()
	view.bind(s)
	view.shake_enabled = false
	view._on_hurt(1.0)
	c.near(view._shake, 0.0, 0.001, "no shake when disabled")
	view.shake_enabled = true
	view._on_hurt(1.0)
	c.ok(view._shake > 0.0, "shake when enabled")
	view.free()


func test_main_boots_into_character_select(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	c.ok(main.character_select.visible, "boot shows character select")
	c.eq(main.sim, null, "no run starts before a choice")
	main.character_select.seed_edit.text = "12345"
	main.choose_character(&"looper")
	c.ok(not main.character_select.visible, "choice hides the select")
	c.ok(main.sim != null, "the run starts")
	c.eq(main.sim.run_seed, 12345, "the seed field is honored")
	c.eq(main.sim.echo_capacity(), 3, "the chosen character is applied")
	main.end_ui.character_requested.emit()
	c.ok(main.character_select.visible, "the end screen can return to select")
	c.eq(main.sim, null, "the old run is put away")
	main.meta.unlocked[&"solo"] = true
	main.choose_character(&"solo")
	c.eq(main.sim.echo_capacity(), 0, "solo runs without echoes")
	main.free()


func test_f3_toggles_debug_overlay(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(5)
	var event := InputEventAction.new()
	event.action = &"debug"
	event.pressed = true
	main._unhandled_input(event)
	c.ok(main.hud.debug, "F3 shows debug overlay")
	main._unhandled_input(event)
	c.ok(not main.hud.debug, "F3 hides debug overlay")
	main.free()


func test_codex_lists_all_weapons(c: Check) -> void:
	var ui := CodexUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open()
	c.eq(ui.card_count(), Content.weapons().size(), "one card per weapon")
	c.ok(ui.visible, "codex is shown")
	ui.close()
	c.ok(not ui.visible, "codex closes")
	ui.free()


func test_pause_menu_exposes_controller_actions(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(5)
	main.toggle_pause()
	c.ok(main.pause_ui.visible, "pause menu is shown")
	c.ok(main.pause_ui.resume_button.has_focus(), "resume has focus")
	main.pause_ui.settings_button.pressed.emit()
	c.ok(main.settings_ui.visible, "settings opens from pause")
	c.ok(not main.pause_ui.visible, "pause menu yields to settings")
	main.settings_ui.close()
	c.ok(main.pause_ui.visible, "pause menu returns after settings")
	main.pause_ui.history_button.pressed.emit()
	c.ok(main.history_ui.visible, "history opens from pause")
	c.ok(not main.pause_ui.visible, "pause menu yields to history")
	main.history_ui.close()
	c.ok(main.pause_ui.visible, "pause menu returns after history")
	main.pause_ui.resume_button.pressed.emit()
	c.ok(not main.paused, "resume unpauses")
	c.ok(not main.pause_ui.visible, "pause menu hides on resume")
	main.free()


func test_pause_can_quit_to_select(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(5)
	main.toggle_pause()
	var event := InputEventAction.new()
	event.action = &"quit_run"
	event.pressed = true
	main._unhandled_input(event)
	c.ok(main.character_select.visible, "quit returns to character select")
	c.eq(main.sim, null, "the abandoned run is put away")
	main.free()


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
