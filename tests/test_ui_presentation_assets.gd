extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _key(node: Node) -> StringName:
	return StringName(node.get_meta(&"presentation_key", &""))


func test_hand_titles_follow_the_text_and_preserve_bilingual_glyphs(c: Check) -> void:
	var previous := Loc.lang
	for language in ["en", "zh"]:
		Loc.lang = language
		var brand := UiTheme.label("TAKE STACK", 38)
		var brand_font := brand.get_theme_font("font") as FontVariation
		c.ok(brand_font.base_font.resource_path.ends_with("AmaticSC-Bold.ttf"),
				"the English brand stays hand-lettered in both language modes")
		var chinese := UiTheme.label("废件回收局", 38)
		var chinese_font := chinese.get_theme_font("font") as FontVariation
		c.ok(chinese_font.base_font.resource_path.ends_with("ZCOOLKuaiLe-Regular.ttf"),
				"Chinese titles use the rounded hand-drawn face")
		for title in ["TAKE STACK", "废件回收局"]:
			var face := UiTheme.title_font(title)
			for index in title.length():
				c.ok(face.has_char(title.unicode_at(index)), "hand title can draw every required glyph")
		c.ok(UiTheme.font().resource_path.ends_with("NotoSansCJKsc-Regular.otf"),
				"body text retains its readable bundled CJK font")
		brand.free()
		chinese.free()
	Loc.lang = previous


func test_control_marks_use_ink_glyphs_instead_of_stock_white_icons(c: Check) -> void:
	var theme := UiTheme.build()
	for pair in [["arrow", "OptionButton"], ["checked", "CheckBox"], ["unchecked", "CheckBox"],
			["checked", "CheckButton"], ["unchecked", "CheckButton"], ["grabber", "HSlider"]]:
		var icon := theme.get_icon(pair[0], pair[1])
		c.ok(icon is ImageTexture, "native control uses an authored ink glyph")
		var image := icon.get_image()
		c.ok(image.get_width() >= 16 and image.get_height() >= 16, "control mark has a readable footprint")
		c.near(image.get_pixel(0, 0).a, 0.0, 0.01, "control glyph has a transparent outer corner")
	c.eq(theme.get_constant("modulate_arrow", "OptionButton"), 1,
			"dropdown arrow follows dark text rather than disappearing white on paper")
	c.eq(theme.get_color("button_checked_color", "CheckButton"), UiTheme.INK,
			"checked state uses ink instead of the native bright blue switch")
	c.eq(UiTheme._control_icon(&"unknown_control_glyph"), null, "unrecognised marks have no invented fallback")


func test_screen_sheets_have_independent_silhouettes(c: Check) -> void:
	var first := UiTheme.surface_panel()
	first.shape = InkStyleBox.Shape.BLOB
	first.variant = 11
	var second := UiTheme.surface_panel()
	c.eq(second.shape, InkStyleBox.Shape.PAPER, "one modal's blob does not change another modal")
	c.eq(second.variant, 3, "each sheet starts with the authored surface variant")


func test_expanded_option_popup_has_its_own_readable_ink_marks(c: Check) -> void:
	var option := OptionButton.new()
	option.theme = UiTheme.build()
	option.add_item("Automatic", 0)
	option.add_item("English", 1)
	option.add_item("中文", 2)
	_root().add_child(option)
	var popup := option.get_popup()
	c.ok(popup.is_item_radio_checkable(0), "language entries are actual native radio menu items")
	for mark in ["checked", "checked_disabled", "unchecked", "unchecked_disabled",
			"radio_checked", "radio_checked_disabled", "radio_unchecked", "radio_unchecked_disabled",
			"submenu", "submenu_mirrored"]:
		var texture := popup.get_theme_icon(mark, "PopupMenu")
		c.ok(texture is ImageTexture, "expanded menu uses an authored glyph for %s" % mark)
		c.eq(texture.get_rid(), option.theme.get_icon(mark, "PopupMenu").get_rid(),
				"native popup inherits the configured ink texture for %s" % mark)
		var image := texture.get_image()
		var opaque_pixels := 0
		var lightest := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a >= 0.9:
					opaque_pixels += 1
					lightest = maxf(lightest, maxf(pixel.r, maxf(pixel.g, pixel.b)))
		c.ok(opaque_pixels > 0, "%s has visible ink rather than a blank glyph" % mark)
		c.ok(lightest < 0.7, "%s is ink-coloured without relying on option-button modulation" % mark)
	option.select(1)
	c.ok(popup.is_item_checked(1), "opening the menu preserves the selected language")
	option.select(2)
	c.ok(popup.is_item_checked(2) and not popup.is_item_checked(1),
			"changing selection still updates the native radio state")
	option.free()


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


func test_passives_are_available_in_separate_workbench(c: Check) -> void:
	var sim := Sim.new(314)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.add_item(Content.item(&"iron_heart"))
	var ui := ShopUi.new()
	_root().add_child(ui)
	ui.open(sim)
	ui._open_build_passives(0)
	c.ok(ui.workshop.visible, "passives have a separate bounded workbench page")
	var found := false
	for label: Label in ui.workshop.find_children("*", "Label", true, false):
		if label.text.contains(Loc.item_name(&"iron_heart")):
			found = true
	c.ok(found, "passive detail page names the real equipped item")
	ui.free()


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
		var actor := card as CharacterSelectUi.CastButton
		c.ok(actor.portrait != null, "each character card has one portrait")
		c.ok(PresentationAssets.texture(_key(actor.portrait)) != null,
				"character portrait resolves through the catalog")
		c.ok(actor.kit != null and actor.kit.get_child_count() > 0, "the card shows the starting kit")
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
