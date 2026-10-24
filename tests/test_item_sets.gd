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
	var max_hp := field.player.max_hp()
	for id in [&"iron_heart", &"regen_patch", &"sneakers"]:
		field.player.add_item(Content.item(id))
	c.near(field.player.max_hp(), max_hp + 10.0 + 3.0, 0.001,
			"field set adds max health after the iron heart")
	c.near(field.player.stats.get_stat(Stats.HP_REGEN), 0.65 + 0.10, 0.001,
			"field set adds regen")


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


func test_build_panel_shows_completed_set(c: Check) -> void:
	var s := _sim()
	for id in [&"spare_deck", &"long_play", &"loud_speaker"]:
		s.player.add_item(Content.item(id))
	var panel := BuildPanel.new()
	_root().add_child(panel)
	panel.refresh(s)
	c.ok(_find_label(panel, Loc.t("set.echo_bonus")), "completed set bonus is visible")
	panel.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
