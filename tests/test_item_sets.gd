extends RefCounted


func _sim() -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = 1000
	return s


func test_echo_set_applies_once(c: Check) -> void:
	var s := _sim()
	for id in [&"spare_deck", &"long_play", &"loud_speaker"]:
		s.player.add_item(Content.item(id))
	c.ok(bool(s.player.set_bonus_applied.get(&"echo", false)), "echo set is marked")
	c.near(s.player.stats.get_stat(Stats.ECHO_POWER), 0.50 + 0.25 + 0.02, 0.001,
			"echo set adds two percent after the item mods")


func test_gunsmith_and_field_sets(c: Check) -> void:
	var gunsmith := _sim()
	for id in [&"sharp_edge", &"quick_trigger", &"long_barrel"]:
		gunsmith.player.add_item(Content.item(id))
	c.near(gunsmith.player.stats.get_stat(Stats.DAMAGE_PCT), 0.10 + 0.02, 0.001,
			"gunsmith adds damage")
	c.near(gunsmith.player.stats.get_stat(Stats.ATTACK_SPEED_PCT), 0.12 + 0.02, 0.001,
			"gunsmith adds attack speed")
	var damage_before := gunsmith.player.stats.get_stat(Stats.DAMAGE_PCT)
	var haste_before := gunsmith.player.stats.get_stat(Stats.ATTACK_SPEED_PCT)
	gunsmith.player.add_item(Content.item(&"lucky_coin"))
	c.near(gunsmith.player.stats.get_stat(Stats.DAMAGE_PCT), damage_before, 0.001,
			"a fourth set member does not apply damage twice")
	c.near(gunsmith.player.stats.get_stat(Stats.ATTACK_SPEED_PCT), haste_before, 0.001,
			"a fourth set member does not apply haste twice")
	var field := _sim()
	for id in [&"iron_heart", &"regen_patch", &"sneakers"]:
		field.player.add_item(Content.item(id))
	c.near(field.player.stats.get_stat(Stats.SHIELD), 8.0, 0.001,
			"field set grants shield")
	c.near(field.player.stats.get_stat(Stats.HP_REGEN), 0.65, 0.001,
			"field set no longer adds regen")


func test_gunsmith_set_makes_every_sixth_player_shot_crit(c: Check) -> void:
	var s := _sim()
	for id in [&"sharp_edge", &"quick_trigger", &"long_barrel"]:
		s.player.add_item(Content.item(id))
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = s.player.pos + Vector2(60.0, 0.0)
	enemy.hp = 1000.0
	s.enemies.append(enemy)
	s.player_shots = 5
	Combat.step_weapons(s, s.player.pos, s.player.stats, s.player.weapons,
			s.player.weapon_levels, s.player.cooldowns, 1.0, 1.0 / 60.0, -1,
			Color.WHITE)
	c.ok(not s.projectiles.is_empty(), "the player fires")
	c.ok(s.projectiles[0].crit, "the sixth player shot is a forced crit")
	c.eq(s.player_shots, 6, "the player shot counter advances")


func test_field_set_bursts_when_shield_breaks(c: Check) -> void:
	var s := _sim()
	for id in [&"iron_heart", &"regen_patch", &"sneakers"]:
		s.player.add_item(Content.item(id))
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = s.player.pos + Vector2(40.0, 0.0)
	enemy.hp = 100.0
	s.enemies.append(enemy)
	s.player.shield = 8.0
	s._hurt_player(8.0, &"test", &"contact", s.player.pos, Vector2.RIGHT)
	c.eq(s.player.shield, 0.0, "the shield is consumed")
	c.ok(enemy.hp < 100.0, "the shield break damages nearby enemies")
	c.ok(enemy.knock.length() > 0.0, "the shield break knocks enemies back")

	var plain := _sim()
	var plain_enemy := EnemyState.new()
	plain_enemy.def = Content.enemy(&"grunt")
	plain_enemy.pos = plain.player.pos + Vector2(40.0, 0.0)
	plain_enemy.hp = 100.0
	plain.enemies.append(plain_enemy)
	plain.player.shield = 8.0
	plain._hurt_player(8.0, &"test", &"contact", plain.player.pos, Vector2.RIGHT)
	c.eq(plain_enemy.hp, 100.0, "without the set there is no shockwave")


func test_shop_state_restores_set_bonus(c: Check) -> void:
	var s := _sim()
	s.player.add_item(Content.item(&"spare_deck"))
	s.player.add_item(Content.item(&"long_play"))
	var before := ShopState.capture(s)
	s.player.add_item(Content.item(&"loud_speaker"))
	c.ok(bool(s.player.set_bonus_applied.get(&"echo", false)), "third item activates the set")
	before.restore(s)
	c.ok(not bool(s.player.set_bonus_applied.get(&"echo", false)),
			"restore removes the set flag")
	c.ok(s.player.item_count(&"loud_speaker") == 0, "restore removes the third item")
	c.near(s.player.stats.get_stat(Stats.ECHO_POWER), 0.50, 0.001,
			"restore removes the set stat contribution")


func _find_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _find_label(child, needle):
			return true
	return false


func test_workbench_shows_every_completed_set_and_actual_core_stats(c: Check) -> void:
	var cases: Array[Dictionary] = [
		{"id": &"echo", "members": [&"spare_deck", &"long_play", &"loud_speaker"]},
		{"id": &"gunsmith", "members": [&"sharp_edge", &"quick_trigger", &"long_barrel"]},
		{"id": &"field", "members": [&"iron_heart", &"regen_patch", &"sneakers"]},
	]
	for data in cases:
		var s := _sim()
		for id: StringName in data.members:
			s.player.add_item(Content.item(id))
		var ui := ShopUi.new()
		ui.theme = UiTheme.build()
		_root().add_child(ui)
		ui.open(s)
		ui.build_panel._slot_buttons[0].pressed.emit()
		ui.workshop.choice_buttons[5].pressed.emit()
		c.ok(ui.workshop.visible, "actual slot entry opens the passive workbench")
		ui.workshop.choice_buttons[1].pressed.emit()
		c.ok(_find_label(ui.workshop, Loc.t("set.%s_bonus" % data.id)), "%s completed bonus is visible on its passive page" % data.id)
		ui.workshop.cancel_button.pressed.emit()
		ui.build_panel._slot_buttons[0].pressed.emit()
		ui.workshop.choice_buttons[4].pressed.emit()
		if data.id == &"echo":
			c.ok(_find_label(ui.workshop, Loc.t("shop.echo_value", [s.echo_capacity(), int(round(s.echo_power() * 100.0))])), "echo set core uses actual capacity and power")
		elif data.id == &"gunsmith":
			for stat in [Stats.DAMAGE_PCT, Stats.ATTACK_SPEED_PCT]:
				c.ok(_find_label(ui.workshop, Loc.stat_name(stat) + " · " + Loc.stat_value(stat, s.player.stats.get_stat(stat), false)), "gunsmith actual stat remains visible in core")
		else:
			ui.workshop.choice_buttons[1].pressed.emit()
			c.ok(_find_label(ui.workshop, Loc.stat_name(Stats.SHIELD) + " · " + Loc.stat_value(Stats.SHIELD, s.player.stats.get_stat(Stats.SHIELD), false)), "field set actual shield remains visible in core")
		ui.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
