extends RefCounted


func _root() -> Window:
	Controls.register()
	return (Engine.get_main_loop() as SceneTree).root


func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func test_paper_controls_keep_text_and_focus_readable(c: Check) -> void:
	var theme := UiTheme.build()
	var normal := theme.get_stylebox("normal", "Button") as InkStyleBox
	c.ok(_contrast(theme.get_color("font_color", "Button"), normal.bg_color) >= 4.5,
			"default button text is readable on paper")
	c.ok(_contrast(theme.get_color("font_focus_color", "Button"), normal.bg_color) >= 4.5,
			"focused paper button cannot inherit white-on-cream text")
	c.ok(_contrast(UiTheme.DIM, UiTheme.CARD) >= 4.5,
			"secondary text stays readable on archive cards")
	for color in [UiTheme.DIM, UiTheme.ACCENT, UiTheme.WARN, UiTheme.COIN, UiTheme.ECHO]:
		c.ok(_contrast(color, UiTheme.PAPER) >= 4.5, "semantic text stays readable on darker paper")
	var focus := theme.get_stylebox("focus", "Button") as InkStyleBox
	c.ok(not focus.draw_center and focus.focus_marks and focus.get_border_width_min() >= 2,
			"focus uses visible hand-drawn brackets without covering content")
	var button := Button.new()
	UiTheme.stamp_button(button)
	var stamp := button.get_theme_stylebox("normal") as InkStyleBox
	c.ok(_contrast(button.get_theme_color("font_color"), stamp.bg_color) >= 4.5,
			"primary stamp text is readable")
	c.ok(_contrast(button.get_theme_color("font_focus_color"), stamp.bg_color) >= 4.5,
			"focused primary stamp keeps its own light text")
	button.free()


func test_bilingual_character_cards_preserve_choice_and_lock_semantics(c: Check) -> void:
	var previous := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		var meta := Meta.new("user://test_paper_ui_meta.json")
		var select := CharacterSelectUi.new()
		select.theme = UiTheme.build()
		_root().add_child(select)
		select.refresh(meta)
		c.eq(select._cards.size(), 6, "%s has all six identities" % language)
		c.ok(select._cards[0].has_focus(), "%s starts at an available character" % language)
		c.ok(select._cards[2].disabled, "%s keeps locked characters unavailable" % language)
		for card in select._cards:
			c.ok(not card.accessibility_name.is_empty(), "%s card has a readable identity" % language)
			c.ok(not card.accessibility_description.is_empty(), "%s card explains its role" % language)
		var chosen: Array[StringName] = []
		select.character_chosen.connect(func(id: StringName) -> void: chosen.append(id))
		select._cards[0].pressed.emit()
		c.eq(chosen, [&"looper"], "%s card still starts the chosen real character" % language)
		select.seed_edit.text = "bad seed"
		c.eq(select.chosen_seed(), -1, "%s malformed batch seed does not silently become zero" % language)
		select.free()
	Loc.lang = previous


func test_archives_scroll_without_losing_the_modal_close_action(c: Check) -> void:
	var codex := CodexUi.new()
	codex.theme = UiTheme.build()
	_root().add_child(codex)
	codex.open()
	c.eq(codex.card_count(), Content.weapons().size(), "scrolling catalog keeps every weapon")
	c.eq(codex.archive_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
			"catalog cannot push cards sideways outside the window")
	c.ok(codex.archive_scroll.follow_focus, "archive scroll follows focused content")
	c.ok(codex.close_button.has_focus(), "catalog keeps an immediate close action")
	codex.close()
	c.ok(not codex.visible, "closing the catalog returns to the previous surface")
	codex.free()
	var history := HistoryUi.new()
	history.theme = UiTheme.build()
	_root().add_child(history)
	c.ok(history.archive_scroll.follow_focus, "long run histories follow controller focus")
	history.free()


func test_boon_cards_keep_their_action_and_empty_input_cannot_trap_focus(c: Check) -> void:
	var ui := BoonUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open([Boon.DAMAGE, Boon.HASTE, Boon.FORTUNE])
	c.eq(ui.choice_buttons.size(), 3, "all salvage choices are actual controls")
	c.ok(ui.choice_buttons[0].has_focus(), "first salvage card receives controller focus")
	c.eq(ui.save_button.get_theme_color("font_color"), UiTheme.CARD, "save action is light on the dark boon backdrop")
	c.eq(ui.save_button.get_theme_color("font_focus_color"), UiTheme.CARD, "controller focus keeps save action legible")
	c.eq(ui.choice_buttons[0].get_node(ui.choice_buttons[0].focus_neighbor_top),
			ui.save_button, "salvage choices wrap through the Save and Return action")
	c.eq(ui.save_button.get_node(ui.save_button.focus_neighbor_bottom), ui.choice_buttons[0], "save action returns focus to actual choices")
	var saves: Array[bool] = []
	ui.save_requested.connect(func() -> void: saves.append(true))
	ui.save_button.pressed.emit()
	c.eq(saves.size(), 1, "boon save action is reachable without choosing a reward")
	var chosen: Array[int] = []
	ui.chosen.connect(func(index: int) -> void: chosen.append(index))
	ui.choice_buttons[1].pressed.emit()
	c.eq(chosen, [1], "card presentation preserves the selected upgrade index")
	ui.open([])
	c.ok(not ui.visible and ui.choice_buttons.is_empty(), "an empty grant closes rather than traps input")
	ui.free()


func test_reduced_modal_open_is_immediately_opaque_and_input_ready(c: Check) -> void:
	var control := Control.new()
	_root().add_child(control)
	control.modulate.a = 0.0
	UiTheme.animate_open(control, true)
	c.eq(control.modulate, Color.WHITE, "reduced effects skips the fade entirely")
	c.eq(control.scale, Vector2.ONE, "opening does not alter layout scale")
	control.free()


func test_character_stage_has_open_shapes_and_focus_driven_details(c: Check) -> void:
	var meta := Meta.new("user://test_organic_stage_meta.json")
	for id: StringName in Content.characters():
		meta.unlocked[id] = true
	var select := CharacterSelectUi.new()
	select.theme = UiTheme.build()
	_root().add_child(select)
	select.refresh(meta)
	var rises: Array[float] = []
	for card in select._cards:
		var carrier := card.get_theme_stylebox("normal") as InkStyleBox
		c.ok(not carrier.draw_center and carrier.border_color.a == 0.0,
				"character identities are open stage figures, not framed cards")
		c.eq(card.rotation, 0.0, "visual asymmetry never rotates the click rectangle")
		var portrait := card.get("portrait") as TextureRect
		c.ok(portrait.custom_minimum_size.y >= 170.0, "stage figure is larger than a row thumbnail")
		var rise := float(card.get("rise"))
		if not rises.has(rise):
			rises.append(rise)
	c.ok(rises.size() >= 3, "the cast does not share four identical baselines")
	select._cards[2].grab_focus()
	_assert_role_detail(c, select, &"mirror", "focus reveals the chosen role's real tradeoff")
	c.eq(select._selection_note.text, Loc.t("select.current_use", [Loc.character_name(&"mirror")]),
			"the stage responds to the actual selected identity")
	select.seed_edit.grab_focus()
	var previewed := 0
	for card in select._cards:
		if bool(card.get("previewed")):
			previewed += 1
	c.eq(previewed, 1, "editing a batch seed retains one clear role preview")
	select.free()


func test_unlock_note_fires_for_a_new_unlock_only(c: Check) -> void:
	var meta := Meta.new("user://test_organic_unlock_meta.json")
	meta.unlocked[&"solo"] = false
	var select := CharacterSelectUi.new()
	select.theme = UiTheme.build()
	_root().add_child(select)
	select.refresh(meta)
	c.ok(select._cards[1].disabled, "locked cast member stays unavailable")
	meta.unlocked[&"solo"] = true
	select.refresh(meta)
	c.ok(not select._cards[1].disabled, "a real unlock changes the available action")
	c.eq(select._selection_note.text, Loc.t("select.just_unlocked", [Loc.character_name(&"solo")]),
			"the new unlock receives a specific reaction")
	select.refresh(meta)
	c.eq(select._selection_note.text, Loc.t("select.current_use", [Loc.character_name(&"looper")]),
			"ordinary refresh does not replay the unlock reaction")
	select.free()


func test_salvage_choices_vary_visually_and_reject_an_invalid_index(c: Check) -> void:
	var ui := BoonUi.new()
	ui.theme = UiTheme.build()
	_root().add_child(ui)
	ui.open([Boon.DAMAGE, Boon.HASTE, Boon.FORTUNE])
	for choice in ui.choice_buttons:
		var shell := choice.get_theme_stylebox("normal") as InkStyleBox
		c.ok(not shell.draw_center and shell.border_color.a == 0.0, "salvage objects have no full card frame")
	c.ok(ui.choice_buttons[0].custom_minimum_size != ui.choice_buttons[1].custom_minimum_size,
			"salvage is not an equal tile matrix")
	var picked: Array[int] = []
	ui.chosen.connect(func(index: int) -> void: picked.append(index))
	ui._on_chosen(-1)
	ui._on_chosen(3)
	c.ok(picked.is_empty(), "invalid UI selection does not emit a reward")
	ui.choice_buttons[2].pressed.emit()
	c.eq(picked, [2], "an actual choice still emits its original reward index")
	ui.free()


func test_mouse_preview_does_not_steal_focus_or_start_a_run(c: Check) -> void:
	var meta := Meta.new("user://test_organic_mouse_meta.json")
	for id: StringName in Content.characters():
		meta.unlocked[id] = true
	var select := CharacterSelectUi.new()
	select.theme = UiTheme.build()
	_root().add_child(select)
	select.refresh(meta)
	var chosen: Array[StringName] = []
	select.character_chosen.connect(func(id: StringName) -> void: chosen.append(id))
	select._cards[0].grab_focus()
	select._cards[2].mouse_entered.emit()
	_assert_role_detail(c, select, &"mirror", "pointer entry previews the hovered role")
	c.ok(select._cards[0].has_focus(), "hover does not steal the keyboard selection")
	c.ok(chosen.is_empty(), "hover does not emit a start action")
	select._cards[2].mouse_exited.emit()
	_assert_role_detail(c, select, &"looper", "pointer exit restores keyboard role")
	select.seed_edit.grab_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(40.0, 40.0)
	select._cards[1].gui_input.emit(motion)
	_assert_role_detail(c, select, &"solo", "motion within a role updates its preview")
	c.ok(select.seed_edit.has_focus() and chosen.is_empty(), "pointer browsing leaves the batch field and run untouched")
	select._cards[1].mouse_exited.emit()
	_assert_role_detail(c, select, &"looper", "exit from seed/footer browsing restores the recent real role")
	select.free()


func test_secondary_actions_have_idle_stitches_without_changing_their_focus_objects(c: Check) -> void:
	var idle := StitchedAction.marker_points(Vector2(138.0, 40.0))
	var focused := StitchedAction.marker_points(Vector2(138.0, 40.0), true)
	c.ok(idle.size() >= 3 and idle[0] != idle[idle.size() - 1], "idle action carries an open ink mark, not a frame")
	c.ok(focused[0].distance_to(focused[focused.size() - 1]) > idle[0].distance_to(idle[idle.size() - 1]),
			"focus strengthens the same action mark")
	c.ok(StitchedAction.marker_points(Vector2.ZERO).is_empty(), "unlaid-out actions do not emit invalid strokes")
	var select := CharacterSelectUi.new()
	select.theme = UiTheme.build()
	_root().add_child(select)
	select.refresh(Meta.new("user://test_stitched_actions_meta.json"))
	var stitched := 0
	for button in select._secondary_actions:
		if not button is StitchedAction:
			continue
		stitched += 1
		c.ok(button is StitchedAction, "each secondary footer action has a permanent click cue")
		button.grab_focus()
		c.ok(button.has_focus(), "the original action remains the actual focus object")
		c.ok(_contrast(button.get_theme_color("font_focus_color"), UiTheme.PAPER) >= 4.5,
				"paper footer action keeps readable focused text")
		c.eq(button.rotation, 0.0, "ink cues do not rotate the interaction area")
	c.ok(stitched >= 1, "settings stays a stitched footer action")
	select.free()
	var sim := Sim.new(99)
	sim.start_run()
	sim.player.materials = 100
	var boons := BoonUi.new()
	boons.theme = UiTheme.build()
	_root().add_child(boons)
	boons.open([Boon.DAMAGE, Boon.HASTE, Boon.FORTUNE], sim)
	c.ok(boons.reroll_button is StitchedAction, "salvage reroll uses the fourth concrete action cue")
	boons.reroll_button.grab_focus()
	c.ok(boons.reroll_button.has_focus(), "reroll keeps its original button and signal path")
	c.ok(_contrast(boons.reroll_button.get_theme_color("font_focus_color"), UiTheme.INK) >= 4.5,
			"dark-stage reroll keeps light text when focused")
	c.ok(_contrast(boons.reroll_button.get_theme_color("font_hover_pressed_color"), UiTheme.INK) >= 4.5,
			"dark-stage reroll keeps light text when pressed")
	boons.free()


func _assert_role_detail(c: Check, select: CharacterSelectUi, id: StringName, label: String) -> void:
	c.ok(select._detail.text.begins_with(Loc.character_desc(id)), label + " · passive tradeoff")
	c.ok(select._detail.text == Loc.character_desc(id), label + " · opening description without the active ability")
