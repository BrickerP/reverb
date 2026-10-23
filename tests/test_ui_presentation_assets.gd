extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _key(node: Node) -> StringName:
	return StringName(node.get_meta(&"presentation_key", &""))


func test_every_content_icon_uses_a_loaded_decorative_texture(c: Check) -> void:
	for weapon: WeaponDef in Content.weapons().values():
		var weapon_icon := UiTheme.weapon_icon(weapon)
		c.eq(_key(weapon_icon), PresentationAssets.weapon_key(weapon),
				"%s weapon icon uses its catalog key" % weapon.id)
		c.ok(weapon_icon.texture != null, "%s weapon icon has a texture" % weapon.id)
		c.eq(weapon_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s weapon icon never intercepts input" % weapon.id)
		weapon_icon.free()
	for item: ItemDef in Content.items().values():
		var item_icon := UiTheme.item_icon(item)
		c.eq(_key(item_icon), PresentationAssets.item_key(item),
				"%s item icon uses its catalog key" % item.id)
		c.ok(item_icon.texture != null, "%s item icon has a texture" % item.id)
		c.eq(item_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s item icon never intercepts input" % item.id)
		item_icon.free()
	for character: CharacterDef in Content.characters().values():
		var portrait := UiTheme.character_icon(character.id)
		c.eq(_key(portrait), PresentationAssets.character_key(character.id),
				"%s portrait uses its catalog key" % character.id)
		c.ok(portrait.texture != null, "%s portrait has a texture" % character.id)
		c.eq(portrait.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s portrait never intercepts input" % character.id)
		portrait.free()


func test_item_offer_and_drag_preview_use_the_same_art(c: Check) -> void:
	var sim := Sim.new(31)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	var offer := Offer.new()
	offer.item = Content.item(&"long_play")
	offer.price = 10
	sim.shop.offers.clear()
	sim.shop.offers.append(offer)
	var card := OfferCard.new()
	card.theme = UiTheme.build()
	_root().add_child(card)
	card.setup(offer, sim, false, func(_offer: Offer) -> Variant:
		return {"kind": &"test"})
	var expected := PresentationAssets.item_key(offer.item)
	var icons := card.find_children("*", "TextureRect", true, false)
	c.ok(not icons.is_empty(), "item offer contains a texture icon")
	c.eq(_key(icons[0]), expected, "item offer uses the item art")
	var preview := card._drag_preview()
	var preview_icons := preview.find_children("*", "TextureRect", true, false)
	c.ok(not preview_icons.is_empty(), "item drag preview contains a texture icon")
	c.eq(_key(preview_icons[0]), expected, "drag preview keeps the item identity")
	c.ok(preview.theme != null, "drag preview carries an explicit theme")
	preview.free()
	card.free()


func test_build_panel_item_chips_keep_icons_inside_the_item_target(c: Check) -> void:
	var sim := Sim.new(32)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	for item: ItemDef in Content.items().values():
		sim.player.items[item.id] = 1
	var panel := BuildPanel.new()
	panel.theme = UiTheme.build()
	_root().add_child(panel)
	panel.refresh(sim)
	var icons := panel._items_row.find_children("*", "TextureRect", true, false)
	c.eq(icons.size(), Content.items().size(), "every equipped item has an icon")
	for icon: TextureRect in icons:
		c.eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"equipped item icons leave the drop target usable")
	c.ok(panel.items_drop_target != null, "the item drop target remains available")
	panel.free()


func test_character_cards_and_codex_show_all_content_art(c: Check) -> void:
	var meta := Meta.new("user://test_ui_presentation_meta.json")
	for id: StringName in Content.characters():
		meta.unlocked[id] = true
	var select := CharacterSelectUi.new()
	select.theme = UiTheme.build()
	_root().add_child(select)
	select.refresh(meta)
	c.eq(select._cards.size(), Content.characters().size(), "one selection card per character")
	for card: Button in select._cards:
		var portraits := card.find_children("*", "TextureRect", true, false)
		c.eq(portraits.size(), 1, "each character card has one portrait")
		if not portraits.is_empty():
			c.ok(PresentationAssets.texture(_key(portraits[0])) != null,
					"character portrait resolves through the catalog")
	select.free()
	var codex := CodexUi.new()
	codex.theme = UiTheme.build()
	_root().add_child(codex)
	c.eq(codex.card_count(), Content.weapons().size(), "codex still shows all weapons")
	for card: PanelContainer in codex._cards:
		var icons := card.find_children("*", "TextureRect", true, false)
		c.eq(icons.size(), 1, "every codex card has one weapon thumbnail")
		if not icons.is_empty():
			c.ok(PresentationAssets.texture(_key(icons[0])) != null,
					"codex thumbnail resolves through the catalog")
	codex.free()
