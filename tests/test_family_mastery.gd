extends RefCounted


func _weapons(id: StringName, count: int) -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	for i in count:
		out.append(Content.weapon(id))
	return out


func test_four_piece_families_get_distinct_masteries(c: Check) -> void:
	var sidearm := _weapons(&"pistol", 4)
	c.near(Combat.family_cooldown_mult(sidearm, &"sidearm"), 0.94, 0.001,
			"gunslinger grants sidearm haste")
	var scatter := _weapons(&"shotgun", 4)
	c.near(Combat.family_cooldown_mult(scatter, &"scatter"), 1.0, 0.001,
			"the old generic speed is gone for scatter")
	c.near(Combat.family_mastery_damage(scatter, &"scatter", 100.0), 1.15, 0.001,
			"point blank adds damage inside the range")
	c.near(Combat.family_mastery_damage(scatter, &"scatter", 161.0), 1.0, 0.001,
			"point blank stops outside the range")
	var marksman := _weapons(&"rifle", 4)
	c.eq(Combat.family_mastery_pierce(marksman, &"marksman"), 1, "overpenetration adds a pierce")
	c.eq(Combat.family_mastery_pierce(scatter, &"scatter"), 0, "other families do not pierce")
	var arcane := _weapons(&"orb", 4)
	c.near(Combat.family_mastery_damage(arcane, &"arcane", 10.0), 1.0, 0.001,
			"arcane changes conduction rather than generic damage")


func test_marksman_mastery_reaches_the_projectile(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.cooldowns.clear()
	for i in 4:
		s.player.add_weapon(Content.weapon(&"rifle"))
	var target := EnemyState.new()
	target.uid = 99
	target.def = Content.enemy(&"grunt")
	target.pos = s.player.pos + Vector2(200.0, 0.0)
	target.hp = 1000.0
	target.max_hp = 1000.0
	target.speed = 0.0
	target.damage = 0.0
	s.enemies.append(target)
	Combat.step_weapons(s, s.player.pos, s.player.stats, s.player.weapons,
			s.player.weapon_levels, s.player.cooldowns, 1.0, 0.016, -1, Color.WHITE)
	c.eq(s.projectiles.size(), 4, "four rifles fire")
	var rifle := Content.weapon(&"rifle")
	c.eq(s.projectiles[0].pierce_left, rifle.pierce + 1, "the mastery pierce is applied to the shot")


func test_arcane_mastery_extends_real_wet_conduction(c: Check) -> void:
	var s := Sim.new(3)
	var source := Vector2(200.0, 200.0)
	s.player.stats.values[Stats.CRIT_CHANCE] = 0.0
	for index in 6:
		var e := EnemyState.new()
		e.uid = index + 1
		e.def = Content.enemy(&"grunt")
		e.pos = Vector2(300.0 + float(index) * 4.0, 200.0)
		e.hp = 1000.0
		e.max_hp = e.hp
		e.ink_left = 2.0
		s.enemies.append(e)
	var combos: Array[ComboInfo] = []
	s.combo_triggered.connect(func(info: ComboInfo) -> void: combos.append(info))
	var w := Content.weapon(&"hex_bolt").duplicate() as WeaponDef
	w.chain_count = 1
	Combat.fire(s, source, Vector2(300.0,200.0), w, 0, 1.0,
		s.player.stats, 1.0, -1, Color.WHITE, 0, false, -1, true)
	c.eq(combos.size(), 1, "one actual conduction interaction")
	c.eq(combos[0].affected, 5, "arcane mastery reaches a fourth wet neighbor")


func _find_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _find_label(child, needle):
			return true
	return false


func test_build_panel_explains_the_active_mastery(c: Check) -> void:
	var s := Sim.new(3)
	s.start_run()
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.cooldowns.clear()
	for i in 4:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.phase = Sim.Phase.SHOP
	var ui := ShopUi.new()
	_root().add_child(ui)
	ui.open(s)
	ui.build_panel._slot_buttons[0].pressed.emit()
	ui.workshop.choice_buttons[4].pressed.emit()
	ui.workshop.choice_buttons[0].pressed.emit()
	c.ok(_find_label(ui.workshop, Loc.t("shop.family_mastery_sidearm")),
			"the workbench shows the active family rule")
	ui.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
