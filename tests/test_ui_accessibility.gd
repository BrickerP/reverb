extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _take(wave: int = 1) -> EchoTake:
	var take := EchoTake.new()
	take.wave = wave
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.samples = PackedVector2Array([
		Vector2(400.0, 300.0), Vector2(520.0, 340.0), Vector2(640.0, 390.0),
	])
	return take


func _shop_sim() -> Sim:
	var sim := Sim.new(51)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.shop.roll(sim)
	sim.bank.takes.clear()
	sim.bank.add(_take(1))
	sim.bank.add(_take(2))
	return sim


func _neighbor(control: Control, path: NodePath) -> Control:
	return control.get_node(path) as Control


func test_compound_cards_have_accessible_identity(c: Check) -> void:
	var meta := Meta.new("user://test_ui_accessibility_meta.json")
	var select := CharacterSelectUi.new()
	select.theme = UiTheme.build()
	_root().add_child(select)
	select.refresh(meta)
	for card: Button in select._cards:
		c.ok(not card.accessibility_name.is_empty(), "character card has an accessible name")
		c.ok(not card.accessibility_description.is_empty(),
				"character card describes its build and lock state")
		c.near(card.modulate.a, 1.0, 0.001, "locked card text stays readable")
	select.free()
	var sim := _shop_sim()
	var offer := sim.shop.offers[0]
	var card := OfferCard.new()
	card.setup(offer, sim)
	c.ok(not card.accessibility_name.is_empty(), "offer card has an accessible name")
	c.ok(not card.accessibility_description.is_empty(), "offer card describes its result")
	card.free()


func test_drag_preview_offsets_its_child_and_reduced_reject_stays_still(c: Check) -> void:
	var sim := _shop_sim()
	var card := OfferCard.new()
	card.theme = UiTheme.build()
	_root().add_child(card)
	card.setup(sim.shop.offers[0], sim, false, func(_offer: Offer) -> Variant:
		return {"kind": &"test"})
	var preview := card._drag_preview()
	c.ok(preview.has_meta(&"shop_drag_preview"), "drag preview root is discoverable")
	c.eq(preview.mouse_filter, Control.MOUSE_FILTER_IGNORE, "drag preview cannot block its target")
	var panel := preview.get_child(0) as Control
	c.ok(panel != null and panel.position.y + panel.custom_minimum_size.y < 0.0,
			"drag card is offset fully above the pointer")
	preview.free()
	card.scale = Vector2(1.2, 1.2)
	card.reject(true)
	c.eq(card.scale, Vector2.ONE, "reduced blocked feedback has no scale motion")
	card.free()


func test_echo_merge_cancel_and_reduced_paths_return_to_rest(c: Check) -> void:
	var panel := EchoPanel.new()
	panel.theme = UiTheme.build()
	_root().add_child(panel)
	var sim := _shop_sim()
	panel.refresh(sim, true)
	c.ok(panel.find_children("*", "PathPreview", true, false).any(
			func(node: Node) -> bool: return (node as PathPreview).is_animating()),
			"normal mode traces the newest path")
	panel.set_reduced_effects(true)
	for preview in panel.find_children("*", "PathPreview", true, false):
		c.ok(not (preview as PathPreview).is_animating(), "reduced effects finishes path traces")
	panel.merge_button.pressed.emit()
	c.ok(panel.is_merging(), "merge mode starts")
	c.ok(panel.cancel_merge(), "merge mode can be cancelled")
	c.ok(not panel.is_merging(), "merge mode returns to rest")
	c.ok(panel.merge_button.has_focus(), "cancel returns focus to Merge")
	panel.free()


func test_skinned_shop_columns_and_echo_actions_stay_inside_the_viewport(c: Check) -> void:
	var sim := _shop_sim()
	sim.bank.takes[0].merged = true
	sim.bank.takes[0].age = 0
	var ui := ShopUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open(sim)
	var layout_margin := ui.get_child(1) as MarginContainer
	c.ok(layout_margin.get_combined_minimum_size().x <= 1280.0,
			"merged new echo badges do not widen the fixed shop columns")
	RenderingServer.force_draw()
	var viewport := _root().get_visible_rect().grow(0.5)
	c.ok(viewport.encloses(ui.build_panel.get_global_rect()), "skinned build panel stays in view")
	c.ok(viewport.encloses(ui.echo_panel.get_global_rect()), "skinned echo panel stays in view")
	if ui.echo_panel.merge_button != null:
		c.ok(viewport.encloses(ui.echo_panel.merge_button.get_global_rect()),
				"merge action stays in view")
	for discard in ui.echo_panel.discard_buttons:
		c.ok(viewport.encloses(discard.get_global_rect()), "discard action stays in view")
	ui.close_session()
	ui.free()


func test_main_propagates_reduced_effects_and_restores_modal_focus(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main._on_reduced_effects_changed(true)
	c.ok(main.settings.reduced_effects, "main stores reduced effects")
	c.ok(main._view.reduced_effects, "arena receives reduced effects")
	c.ok(main.shop_ui.reduced_effects, "shop receives reduced effects")
	c.ok(main.end_ui.reduced_effects, "end screen receives reduced effects")
	main.open_settings()
	c.ok(main.settings_ui.volume_slider.has_focus(), "settings focuses its first control")
	main.settings_ui.close()
	c.ok(main.character_select._cards[0].has_focus(), "closing settings restores selection focus")
	main.open_codex()
	c.ok(main.codex_ui.close_button.has_focus(), "codex has a default focus")
	main.codex_ui.close()
	c.ok(main.character_select._cards[0].has_focus(), "closing codex restores selection focus")
	main.open_history()
	main.history_ui.close()
	c.ok(main.character_select._cards[0].has_focus(), "closing history restores selection focus")
	main._on_reduced_effects_changed(false)
	main.free()


func test_active_run_locks_language_and_pause_mute_tracks_audio(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(52)
	main.toggle_pause()
	c.ok(main.pause_ui.resume_button.has_focus(), "pause starts on Resume")
	c.eq(main.pause_ui.mute_button.text, Loc.t("pause.mute"), "pause shows the available mute action")
	main.pause_ui.mute_button.pressed.emit()
	c.ok(main.audio.is_muted(), "pause mute action reaches audio")
	c.eq(main.pause_ui.mute_button.text, Loc.t("pause.unmute"), "pause action changes to Unmute")
	main.pause_ui.settings_button.pressed.emit()
	c.ok(main.settings_ui.language_option.disabled, "active run cannot reload language")
	main.settings_ui.close()
	c.ok(main.pause_ui.resume_button.has_focus(), "closing nested settings restores pause focus")
	main.pause_ui.history_button.pressed.emit()
	main.history_ui.close()
	c.ok(main.pause_ui.resume_button.has_focus(), "closing nested history restores pause focus")
	if main.audio.is_muted():
		main.audio.toggle_mute()
	main.free()


func test_modal_focus_cycles_never_escape_to_the_underlay(c: Check) -> void:
	var pause := PauseUi.new()
	pause.theme = UiTheme.build()
	_root().add_child(pause)
	pause.open()
	c.eq(_neighbor(pause.resume_button, pause.resume_button.focus_neighbor_top), pause.quit_button,
			"pause wraps upward from its first action")
	c.eq(_neighbor(pause.quit_button, pause.quit_button.focus_neighbor_bottom), pause.resume_button,
			"pause wraps downward from its last action")
	pause.free()
	var settings := SettingsUi.new()
	settings.theme = UiTheme.build()
	_root().add_child(settings)
	settings.open(Settings.new("user://test_ui_focus_settings.json"), false)
	c.eq(_neighbor(settings.volume_slider, settings.volume_slider.focus_neighbor_top),
			settings.close_button, "settings wraps around its enabled controls")
	c.eq(_neighbor(settings.close_button, settings.close_button.focus_neighbor_bottom),
			settings.volume_slider, "settings never enters the disabled language option")
	settings.free()
	var codex := CodexUi.new()
	codex.theme = UiTheme.build()
	_root().add_child(codex)
	codex.open()
	c.eq(_neighbor(codex.close_button, codex.close_button.focus_neighbor_bottom), codex.close_button,
			"single-control codex traps focus on Close")
	# Geometry is asserted by ui_state_probe after container layout. In this synchronous
	# runner autowrap labels have no assigned width and report a meaningless tall minimum.
	codex.free()


func test_history_rebuilds_its_focus_cycle_for_dynamic_rows(c: Check) -> void:
	var path := "user://test_ui_focus_history.jsonl"
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	var log := RunLog.new(path)
	for seed in [61, 62]:
		var sim := Sim.new(seed)
		sim.start_run()
		sim.phase = Sim.Phase.LOST
		log.append(sim, &"looper", 1.0)
	var history := HistoryUi.new()
	history.theme = UiTheme.build()
	_root().add_child(history)
	history.open(log)
	c.eq(history.replay_buttons.size(), 2, "history exposes one focus action per row")
	c.eq(_neighbor(history.replay_buttons[0], history.replay_buttons[0].focus_neighbor_top),
			history.close_button, "first history row wraps to Close")
	c.eq(_neighbor(history.close_button, history.close_button.focus_neighbor_bottom),
			history.replay_buttons[0], "Close wraps to the newest history action")
	history.free()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_end_screen_focus_and_reduced_preview(c: Check) -> void:
	var sim := _shop_sim()
	sim.phase = Sim.Phase.WON
	var ui := EndUi.new()
	ui.theme = UiTheme.build()
	ui.set_reduced_effects(true)
	_root().add_child(ui)
	ui.show_result(sim, "Unlocked")
	c.ok(ui.restart_button.has_focus(), "end screen starts on Play again")
	c.ok(not ui._best_preview.is_animating(), "reduced end preview is already settled")
	ui.free()
