extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _sim() -> Sim:
	var sim := Sim.new(1401)
	sim.start_run()
	for i in 3:
		var take := EchoTake.new()
		take.wave = i + 1
		take.condition = 100.0 - float(i) * 25.0
		take.weapons.append(Content.weapon([&"longbow", &"stamp", &"ink_bottle"][i]))
		take.levels.append(0)
		take.samples = PackedVector2Array([Vector2(200.0 + float(i) * 400.0, 220.0)])
		sim.bank.add(take)
		sim.echoes.append(EchoActor.new(take, i))
	sim.selected_echo_uid = sim.echoes[1].take.uid
	return sim


func test_wheel_highlights_stable_ids_and_never_retires(c: Check) -> void:
	Controls.register()
	var sim := _sim()
	var selected := sim.selected_echo_uid
	var wheel := EchoSelectionWheel.new()
	wheel.theme = UiTheme.build()
	_root().add_child(wheel)
	wheel.open(sim)
	c.eq(wheel.buttons.size(), 3, "every deployed copy has a wheel entry")
	c.eq(wheel.selected_uid(), selected, "wheel starts at the selected stable UID")
	var event := InputEventAction.new()
	event.action = &"ui_right"
	event.pressed = true
	wheel._input(event)
	var choice := wheel.selected_uid()
	c.ok(choice != selected, "keyboard/controller action changes the highlight")
	c.eq(sim.selected_echo_uid, selected, "highlight does not commit simulation selection")
	c.eq(sim.bank.takes.size(), 3, "highlight never consumes a copy")
	c.eq(wheel.close(), choice, "release returns only the highlighted UID")
	c.eq(sim.bank.takes.size(), 3, "closing selection never retires a copy")
	wheel.open(sim)
	wheel.cancel()
	c.eq(wheel.close(), 0, "cancel cannot select or retire on subsequent release")
	wheel.free()


func test_empty_wheel_and_reduced_state_are_actionable(c: Check) -> void:
	var sim := Sim.new(1402)
	sim.start_run()
	var wheel := EchoSelectionWheel.new()
	wheel.reduced_effects = true
	wheel.theme = UiTheme.build()
	_root().add_child(wheel)
	wheel.open(sim)
	c.eq(wheel.selected_uid(), 0, "empty wheel has no phantom UID")
	c.ok(not wheel._detail.text.is_empty(), "empty wheel explains why nothing can be chosen")
	c.eq(wheel.close(), 0, "empty release is inert")
	wheel.free()


func test_selected_hud_matches_live_skill_and_camera(c: Check) -> void:
	var sim := _sim()
	var hud := Hud.new()
	hud.bind(sim)
	var actor := EchoSystem.selected_actor(sim)
	actor.pos = Vector2(2200.0, 1150.0)
	sim.player.pos = Vector2(240.0, 200.0)
	var profile := hud.selected_echo_profile()
	c.eq(profile.uid, actor.take.uid, "HUD predicts the selected stable copy")
	c.eq(profile.kind, &"stamp", "HUD follows the selected recorded weapon")
	c.ok(profile.offscreen, "copy beyond the camera is identified")
	c.ok(profile.offscreen_direction.x > 0.0 and profile.offscreen_direction.y > 0.0,
			"direction uses world camera coordinates")
	c.eq(profile.seconds, ceili(sim.echo_duration() * 0.75), "remaining time follows continuous condition")
	sim.live_echo = true
	sim.player.weapons.assign([Content.weapon(&"rubber_band")])
	sim.player.weapon_levels.assign([0])
	c.eq(hud.selected_echo_profile().kind, &"return", "Mirror preview follows actual live loadout")
	c.eq(sim.bank.takes.size(), 3, "reading prediction cannot consume a copy")
	hud.free()


func test_title_save_errors_and_pause_save_actions(c: Check) -> void:
	var title := CharacterSelectUi.new()
	title.theme = UiTheme.build()
	_root().add_child(title)
	title.refresh(Meta.new("user://test_rebuild_ui_meta.json"))
	c.eq(title._cards.size(), 6, "all six identities appear at title")
	title.set_resume_available(true)
	title.visible = true
	RenderingServer.force_draw()
	c.ok((title.get_child(1) as Control).get_combined_minimum_size().x <= 1280.0, "six identities fit the reference width")
	c.ok((title.get_child(1) as Control).get_combined_minimum_size().y <= 720.0, "continue plus six identities fit the reference height")
	title.focus_default()
	c.ok(title.continue_button.visible and title.continue_button.has_focus(), "continue is visible and focusable")
	title.set_resume_available(false, Loc.t("suspend.corrupt"))
	c.ok(not title.continue_button.visible, "corrupt saves cannot be continued")
	c.ok(title.resume_error.visible and not title.resume_error.text.is_empty(), "invalid save has a visible explanation")
	title.free()
	var pause := PauseUi.new()
	pause.theme = UiTheme.build()
	_root().add_child(pause)
	pause.open()
	var saves: Array[int] = []
	pause.save_requested.connect(func() -> void: saves.append(1))
	pause.save_button.pressed.emit()
	c.eq(saves.size(), 1, "save-and-return has a distinct action")
	pause.show_error(Loc.t("suspend.write_failed"))
	c.ok(pause.error_label.visible and pause.visible, "failed save remains visible in the live pause screen")
	pause.free()


func test_repair_quotes_and_full_slots_keep_their_actions(c: Check) -> void:
	var sim := _sim()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 999
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.shop.roll(sim)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	c.eq(ui.echo_panel.repair_buttons.size(), 3, "every bank copy exposes repair state")
	c.ok(ui.echo_panel.repair_buttons.back().disabled, "full condition is visibly disabled")
	var weapon_offer := Offer.new()
	weapon_offer.weapon = Content.weapon(&"stamp")
	weapon_offer.price = 30
	sim.shop.offers[0] = weapon_offer
	ui.refresh()
	ui._begin_replace(weapon_offer)
	c.ok(ui.build_panel.replacing, "full inventory still enters replacement")
	c.eq(ui.build_panel._slot_buttons.size(), Content.MAX_WEAPON_SLOTS, "all six replacement targets remain usable")
	ui.free()


func test_combo_prerequisites_describe_real_statuses(c: Check) -> void:
	var weapons: Array[WeaponDef] = [Content.weapon(&"pistol")]
	var profile := Combat.combo_profile(weapons)
	c.eq(profile[0].need, &"pin", "a generic bullet is not a pin source")
	weapons.append(Content.weapon(&"longbow"))
	c.eq(Combat.combo_profile(weapons)[0].need, &"press", "pin alone still needs its consumer")
	weapons.append(Content.weapon(&"stamp"))
	c.ok(Combat.combo_profile(weapons)[0].ready, "pin and press describe a real trigger-ready pair")
	for language in ["en", "zh"]:
		var old := Loc.lang
		Loc.lang = language
		for row in Combat.combo_profile(weapons):
			c.ok(not Loc.combo_line(row).contains("combo."), "combo advice is localized")
		Loc.lang = old


func test_music_and_effect_volume_controls_are_independent(c: Check) -> void:
	var settings := Settings.new("user://test_rebuild_ui_settings.json")
	settings.music_volume = 0.35
	settings.effects_volume = 0.8
	var ui := SettingsUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	var music: Array[float] = []
	var effects: Array[float] = []
	ui.music_volume_changed.connect(func(value: float) -> void: music.append(value))
	ui.effects_volume_changed.connect(func(value: float) -> void: effects.append(value))
	ui.open(settings)
	c.ok(music.is_empty() and effects.is_empty(), "opening settings does not invent edits")
	ui.music_volume_slider.value = 0.0
	c.eq(music, [0.0], "music can be independently silenced")
	c.near(ui.effects_volume_slider.value, 0.8, 0.001, "music edit preserves effects")
	ui.effects_volume_slider.value = 1.0
	c.eq(effects, [1.0], "effects expose their full range")
	c.near(ui.music_volume_slider.value, 0.0, 0.001, "effects edit preserves silent music")
	ui.free()


func test_large_copy_bank_pages_without_hiding_selection(c: Check) -> void:
	var sim := _sim()
	for i in 7:
		var take := EchoTake.new()
		take.weapons.append(Content.weapon(&"pistol"))
		take.levels.append(0)
		take.samples = PackedVector2Array([Vector2(200.0, 220.0)])
		sim.bank.add(take)
		sim.echoes.append(EchoActor.new(take, i + 3))
	var wheel := EchoSelectionWheel.new()
	wheel.theme = UiTheme.build()
	_root().add_child(wheel)
	wheel.open(sim)
	c.eq(wheel.buttons.size(), 10, "every copy keeps its stable selection entry")
	wheel._change_page(1)
	c.ok(wheel.selected_uid() > 8, "next page selects a real late-bank UID")
	var shown := 0
	for button in wheel.buttons:
		if button.visible:
			shown += 1
	c.eq(shown, 2, "last page shows its exact entries without overlapping wheel targets")
	c.eq(sim.bank.takes.size(), 10, "paging does not consume a copy")
	wheel.free()


func test_receipts_stay_optional_and_wave_phases_match_authority(c: Check) -> void:
	var sim := _sim()
	sim.phase = Sim.Phase.SHOP
	sim.shop.roll(sim)
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	c.ok(not ui.receipt_button.visible, "empty story state adds no shop interruption")
	sim.story_progress["receipt"] = "carbon"
	ui.refresh_receipt()
	c.ok(ui.receipt_button.visible, "a real receipt offers an optional action")
	c.ok(not ui.receipt_button.tooltip_text.is_empty(), "receipt teaser exposes the actual body")
	var opened: Array[int] = []
	ui.receipt_requested.connect(func() -> void: opened.append(1))
	ui.receipt_button.pressed.emit()
	c.eq(opened, [1], "reading is requested by an explicit action")
	c.eq(StoryLedger.receipt(sim).id, &"carbon", "teaser never dismisses the clue")
	ui.free()
	var hud := Hud.new()
	hud.bind(sim)
	sim.wave_time = sim.wave_duration * 0.3
	c.eq(hud.wave_phase_profile().id, &"first_breather", "HUD reads the authoritative breather window")
	sim.wave_time = sim.wave_duration
	c.eq(hud.wave_phase_profile().id, &"complete", "exact phase boundary is shown without a renderer clock")
	hud.free()


func test_reduced_effects_keeps_arrival_status_without_animation(c: Check) -> void:
	var sim := _sim()
	sim.phase = Sim.Phase.SHOP
	sim.wave = sim.bank.takes.back().wave
	var panel := EchoPanel.new()
	panel.set_reduced_effects(true)
	_root().add_child(panel)
	panel.refresh(sim, true)
	var new_badges := 0
	for label: Label in panel.find_children("*", "Label", true, false):
		if label.text == "[%s]" % Loc.t("shop.new"):
			new_badges += 1
	c.eq(new_badges, 1, "reduced mode keeps the real arriving copy badge")
	c.eq(panel._new_row_tween, null, "arrival status does not require a motion tween")
	panel.free()
