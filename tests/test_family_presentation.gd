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


func _refresh(panel: BuildPanel, sim: Sim) -> void:
	panel.refresh(sim)


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
	]
	for data: Dictionary in cases:
		var weapon_id: StringName = data["weapon"]
		var mastery_text := Loc.t(str(data["key"]))
		var sim := _family_sim(weapon_id)
		var panel := BuildPanel.new()
		_root().add_child(panel)
		_refresh(panel, sim)
		c.ok(not _has_label(panel, mastery_text),
				"three %s weapons do not show mastery" % String(weapon_id))
		if weapon_id == &"orb":
			c.ok(_has_label(panel, Loc.t("shop.echo_value", [2, 50]), true),
					"three arcane weapons keep base core echo power")
		var offer := _weapon_offer(sim, weapon_id)
		c.ok(sim.shop.apply(ShopResult.BUY, sim, offer).ok,
				"fourth %s applies through Shop transaction" % String(weapon_id))
		_refresh(panel, sim)
		c.ok(_has_label(panel, mastery_text),
				"four %s weapons show their mastery" % String(weapon_id))
		if weapon_id == &"orb":
			c.ok(_has_label(panel, Loc.t("shop.echo_value", [2, 58]), true),
					"arcane mastery updates core echo power by eight percentage points")
		elif weapon_id == &"shotgun":
			var flat_dps := OfferCard.total_dps(sim.player)
			var near_dps := flat_dps * Combat.family_mastery_damage(
					sim.player.weapons, &"scatter", 100.0)
			var far_dps := flat_dps * Combat.family_mastery_damage(
					sim.player.weapons, &"scatter", 161.0)
			c.ok(near_dps > far_dps and is_equal_approx(far_dps, flat_dps),
					"scatter mastery remains situational instead of a flat DPS bonus")
			c.ok(_has_label(panel, "%d" % int(round(flat_dps)), true),
					"core DPS stays at the unconditional value while summary states the range")
		c.ok(sim.shop.undo(sim).ok, "mastery purchase undo succeeds")
		_refresh(panel, sim)
		c.ok(not _has_label(panel, mastery_text),
				"undo returns %s mastery presentation to three pieces" % String(weapon_id))
		if weapon_id == &"orb":
			c.ok(_has_label(panel, Loc.t("shop.echo_value", [2, 50]), true),
					"arcane undo restores base core echo power")
		panel.free()
