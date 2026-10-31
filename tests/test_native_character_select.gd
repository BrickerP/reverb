extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _make(extent: Vector2i, all_unlocked: bool = true) -> Dictionary:
	Controls.register()
	var viewport := SubViewport.new()
	viewport.size = extent
	_root().add_child(viewport)
	var ui := CharacterSelectUi.new()
	ui.theme = UiTheme.build()
	viewport.add_child(ui)
	var meta := Meta.new("user://test_native_character_select.json")
	if all_unlocked:
		for id: StringName in Content.characters():
			meta.unlocked[id] = true
	ui.refresh(meta)
	ui.visible = true
	_settle(ui)
	return {"viewport": viewport, "ui": ui, "meta": meta}


func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_sort(child)


func _settle(ui: CharacterSelectUi) -> void:
	for _pass in 4:
		_sort(ui)


func _bounds(c: Check, ui: CharacterSelectUi, extent: Vector2i, label: String) -> void:
	_settle(ui)
	var canvas := Rect2(Vector2.ZERO, Vector2(extent)).grow(0.5)
	for button: BaseButton in ui.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree():
			c.ok(canvas.encloses(button.get_global_rect()), label + " visible button stays inside the native canvas: " + button.name)
	c.ok(canvas.encloses(ui._detail.get_global_rect()), label + " active ability description stays inside the canvas")
	for raw: Button in ui._cards:
		var card := raw as CharacterSelectUi.CastButton
		if card.visible:
			c.ok(canvas.encloses(card.portrait.get_global_rect()), label + " authored portrait stays in view")
			c.eq(card.scale, Vector2.ONE, label + " card has no global shrink")


func test_native_960_pages_all_six_roles_and_keeps_focus_on_visible_page(c: Check) -> void:
	var previous_language := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		var built := _make(Vector2i(960, 540))
		var ui: CharacterSelectUi = built.ui
		c.eq(ui._cards.size(), 6, language + " retains six canonical card objects")
		c.eq(ui._cards.filter(func(card: Button) -> bool: return card.visible).size(), 3, language + " exposes three authored small-screen cards")
		c.ok(ui._pager.visible and ui.page_previous.disabled and not ui.page_next.disabled, language + " page controls expose the remaining roles")
		_bounds(c, ui, Vector2i(960, 540), language + " page one")
		var unlocks: Dictionary = built.meta.unlocked.duplicate()
		ui.page_next.pressed.emit()
		c.eq(ui.page, 1, language + " actual page action reaches page two")
		c.ok(ui._cards[3].has_focus(), language + " changing page focuses its first available role")
		c.ok(ui._detail.text == Loc.character_desc(&"conductor"), language + " focused role shows the opening description")
		_bounds(c, ui, Vector2i(960, 540), language + " page two")
		for index in range(3, 6):
			var card: Button = ui._cards[index]
			for path in [card.focus_neighbor_left, card.focus_neighbor_right]:
				var neighbor := card.get_node_or_null(path) as Control
				c.ok(neighbor != null and neighbor.is_visible_in_tree(), language + " controller horizontal focus stays on the current page")
		ui.focus_default()
		c.ok(ui._cards[3].has_focus(), language + " modal return preserves the current page selection")
		c.eq(built.meta.unlocked, unlocks, language + " paging changes no profile unlocks")
		built.viewport.free()
	Loc.lang = previous_language


func test_native_1280_keeps_full_cast_and_resize_preserves_selected_role(c: Check) -> void:
	var built := _make(Vector2i(1280, 720))
	var ui: CharacterSelectUi = built.ui
	c.eq(ui._cards.filter(func(card: Button) -> bool: return card.visible).size(), 6, "reference canvas keeps all six full cards")
	c.ok(not ui._pager.visible, "reference canvas needs no cast paging")
	_bounds(c, ui, Vector2i(1280, 720), "reference canvas")
	ui._cards[5].grab_focus()
	built.viewport.size = Vector2i(960, 540)
	ui._adapt_layout(true)
	c.eq(ui.page, 1, "shrinking the viewport retains the selected role page")
	c.ok(ui._cards[5].has_focus(), "resize retains the actual focused card")
	built.viewport.size = Vector2i(1280, 720)
	ui._adapt_layout(true)
	c.eq(ui._cards.filter(func(card: Button) -> bool: return card.visible).size(), 6, "growing the viewport restores the whole cast")
	c.eq((ui._cards[5] as CharacterSelectUi.CastButton).portrait.custom_minimum_size, Vector2(158, 184), "full portrait dimensions are restored without scaling the tree")
	_bounds(c, ui, Vector2i(1280, 720), "restored reference canvas")
	built.viewport.free()


func test_locked_second_page_has_a_visible_return_and_never_chooses_a_role(c: Check) -> void:
	var built := _make(Vector2i(960, 540), false)
	var ui: CharacterSelectUi = built.ui
	var selected: Array[StringName] = []
	ui.character_chosen.connect(func(id: StringName) -> void: selected.append(id))
	ui.page_next.pressed.emit()
	c.ok(ui.page_previous.has_focus(), "an entirely locked page focuses the visible return action")
	c.ok(ui._cards.slice(3, 6).all(func(card: Button) -> bool: return card.disabled and card.focus_mode == Control.FOCUS_NONE), "locked cards are not keyboard activation targets")
	_bounds(c, ui, Vector2i(960, 540), "locked page")
	ui.page_previous.pressed.emit()
	c.ok(ui._cards[0].has_focus(), "returning from the locked page restores an available role")
	c.ok(selected.is_empty(), "paging never starts a run")
	built.viewport.free()


# The suite runner is synchronous. The native probe awaits this separately so
# viewport notifications and anchored controls complete their real frame layout.
func probe_native_viewport_resize(c: Check) -> void:
	var previous_language := Loc.lang
	var tree := Engine.get_main_loop() as SceneTree
	for language in ["en", "zh"]:
		Loc.lang = language
		var built := _make(Vector2i(1280, 720))
		var ui: CharacterSelectUi = built.ui
		for _frame in 3:
			await tree.process_frame
		ui._cards[5].grab_focus()
		for extent in [Vector2i(960, 540), Vector2i(1280, 720)]:
			built.viewport.size = extent
			for _frame in 3:
				await tree.process_frame
			c.ok(ui._cards[5].has_focus(), language + " real resize keeps the focused role")
			_bounds(c, ui, extent, language + " awaited viewport resize")
		built.viewport.free()
	Loc.lang = previous_language
