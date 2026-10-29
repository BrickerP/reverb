extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _family_sim(weapon_id: StringName) -> Sim:
	var sim := Sim.new(78145876)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 100
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for _i in 3:
		sim.player.add_weapon(Content.weapon(weapon_id))
	sim.shop.offers.clear()
	return sim


func _weapon_offer(sim: Sim, weapon_id: StringName) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(weapon_id)
	offer.price = 1
	sim.shop.offers.append(offer)
	return offer


func _has_label(node: Node, text: String, exact: bool = false) -> bool:
	if node is Label:
		var label_text := (node as Label).text
		if label_text == text or (not exact and label_text.contains(text)):
			return true
	for child: Node in node.get_children():
		if _has_label(child, text, exact):
			return true
	return false


func _open_core(ui: ShopUi) -> void:
	if ui.workshop.visible:
		ui.workshop.cancel_button.pressed.emit()
	ui.build_panel._slot_buttons[0].pressed.emit()
	ui.workshop.choice_buttons[4].pressed.emit()


func _open_families(ui: ShopUi) -> void:
	_open_core(ui)
	ui.workshop.choice_buttons[0].pressed.emit()


func test_hud_readiness_uses_the_cooldown_combat_actually_schedules(c: Check) -> void:
	var sim := Sim.new(78145876)
	sim.start_run()
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for _i in 4:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.synergy_haste_per_echo = 0.05
	var take := EchoTake.new()
	take.samples.append(sim.player.pos)
	sim.echoes.append(EchoActor.new(take, 0))
	var target := EnemyState.new()
	target.uid = 81
	target.def = Content.enemy(&"grunt")
	target.pos = sim.player.pos + Vector2(100.0, 0.0)
	target.hp = 1000.0
	target.max_hp = 1000.0
	target.speed = 0.0
	target.damage = 0.0
	sim.enemies.append(target)
	Combat.step_weapons(sim, sim.player.pos, sim.player.stats, sim.player.weapons,
			sim.player.weapon_levels, sim.player.cooldowns, 1.0, 0.0, -1, Color.WHITE,
			sim.synergy_damage_mult(), sim.synergy_cooldown_mult())
	var weapon: WeaponDef = sim.player.weapons[0]
	var scheduled := weapon.cooldown * sim.player.stats.cooldown_mult() \
			* Combat.family_cooldown_mult(sim.player.weapons, weapon.family) \
			* sim.synergy_cooldown_mult()
	c.near(sim.player.cooldowns[0], scheduled, 0.0001,
			"Combat schedules family and synergy cooldown for the player")
	var hud := Hud.new()
	hud.bind(sim)
	c.near(hud.weapon_ready(0), 0.0, 0.0001,
			"freshly fired authoritative cooldown maps to zero ready")
	sim.player.cooldowns[0] = scheduled * 0.5
	c.near(hud.weapon_ready(0), 0.5, 0.0001,
			"half of the authoritative cooldown maps to half ready")
	hud.free()


func test_shop_transactions_toggle_every_mastery_summary_and_arcane_core(c: Check) -> void:
	var cases: Array[Dictionary] = [
		{"weapon": &"pistol", "key": "shop.family_mastery_sidearm"},
		{"weapon": &"shotgun", "key": "shop.family_mastery_scatter"},
		{"weapon": &"rifle", "key": "shop.family_mastery_marksman"},
		{"weapon": &"orb", "key": "shop.family_mastery_arcane"},
		{"weapon": &"stamp", "key": "shop.family_mastery_press"},
		{"weapon": &"tape_spool", "key": "shop.family_mastery_salvage"},
	]
	for data: Dictionary in cases:
		var weapon_id: StringName = data["weapon"]
		var mastery_text := Loc.t(str(data["key"]))
		var sim := _family_sim(weapon_id)
		var echo_power := sim.echo_power()
		var offer := _weapon_offer(sim, weapon_id)
		var ui := ShopUi.new()
		ui.theme = UiTheme.build()
		_root().add_child(ui)
		ui.open(sim)
		_open_families(ui)
		c.ok(not _has_label(ui.workshop, mastery_text),
				"three %s weapons do not show mastery" % String(weapon_id))
		if weapon_id == &"orb":
			_open_core(ui)
			c.ok(_has_label(ui.workshop, Loc.t("shop.echo_value", [2, 50])),
					"three arcane weapons keep base core echo power")
		ui.workshop.cancel_button.pressed.emit()
		(ui.offers_box.get_child(0) as OfferCard).pressed.emit()
		c.ok(offer.sold, "fourth %s buys through the actual goods card" % String(weapon_id))
		_open_families(ui)
		c.ok(_has_label(ui.workshop, mastery_text),
				"four %s weapons show their mastery" % String(weapon_id))
		if weapon_id == &"orb":
			_open_core(ui)
			c.ok(_has_label(ui.workshop, Loc.t("shop.echo_value", [2, 50])),
					"conduction mastery keeps the actual core echo power unchanged")
			c.near(sim.echo_power(), echo_power, 0.0001,
					"arcane mastery improves wet-target conduction instead of echo damage")
		elif weapon_id == &"shotgun":
			var flat_dps := OfferCard.total_dps(sim.player)
			var near_dps := flat_dps * Combat.family_mastery_damage(
					sim.player.weapons, &"scatter", 100.0)
			var far_dps := flat_dps * Combat.family_mastery_damage(
					sim.player.weapons, &"scatter", 161.0)
			c.ok(near_dps > far_dps and is_equal_approx(far_dps, flat_dps),
					"scatter mastery remains situational instead of a flat DPS bonus")
			_open_core(ui)
			c.ok(_has_label(ui.workshop, Loc.t("shop.take_dps", [int(round(flat_dps))])),
					"core DPS stays at the unconditional value while summary states the range")
		ui.workshop.cancel_button.pressed.emit()
		ui.undo_button.pressed.emit()
		_open_families(ui)
		c.ok(not _has_label(ui.workshop, mastery_text),
				"undo returns %s mastery presentation to three pieces" % String(weapon_id))
		if weapon_id == &"orb":
			_open_core(ui)
			c.ok(_has_label(ui.workshop, Loc.t("shop.echo_value", [2, 50])),
					"arcane undo restores base core echo power")
		ui.free()
