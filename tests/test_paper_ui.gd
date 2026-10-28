extends RefCounted


func _root() -> Window:
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
	var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	c.ok(_contrast(theme.get_color("font_color", "Button"), normal.bg_color) >= 4.5,
			"default button text is readable on paper")
	c.ok(_contrast(theme.get_color("font_focus_color", "Button"), normal.bg_color) >= 4.5,
			"focused paper button cannot inherit white-on-cream text")
	c.ok(_contrast(UiTheme.DIM, UiTheme.CARD) >= 4.5,
			"secondary text stays readable on archive cards")
	for color in [UiTheme.DIM, UiTheme.ACCENT, UiTheme.WARN, UiTheme.COIN, UiTheme.ECHO]:
		c.ok(_contrast(color, UiTheme.PAPER) >= 4.5, "semantic text stays readable on darker paper")
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	c.ok(not focus.draw_center and focus.get_border_width_min() >= 3,
			"focus remains a visible outline without covering content")
	var button := Button.new()
	UiTheme.stamp_button(button)
	var stamp := button.get_theme_stylebox("normal") as StyleBoxFlat
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
		c.eq(select._cards.size(), 4, "%s has all four identities" % language)
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
	c.eq(ui.choice_buttons[0].get_node(ui.choice_buttons[0].focus_neighbor_top),
			ui.choice_buttons[2], "salvage choices wrap inside the modal")
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
