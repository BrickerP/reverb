extends RefCounted


func _sim(shield: float = 0.0) -> Sim:
	var s := Sim.new(7)
	if shield > 0.0:
		s.player.stats.add(Stats.SHIELD, shield)
	s.start_run()
	return s


func test_shield_absorbs_then_hp(c: Check) -> void:
	var s := _sim(8.0)
	c.near(s.player.shield, 8.0, 0.001, "wave start fills shield")
	var hurt: Array[PlayerHurtInfo] = []
	s.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurt.append(info))
	s._hurt_player(5.0, &"grunt", &"contact", s.player.pos, Vector2.RIGHT)
	c.near(s.player.shield, 3.0, 0.001, "shield drains first")
	c.near(s.player.hp, s.player.max_hp(), 0.001, "fully absorbed damage does not touch HP")
	c.eq(hurt.size(), 1, "shield hit emits one hurt event")
	c.near(hurt[0].absorbed, 5.0, 0.001, "event reports absorbed damage")
	c.near(hurt[0].amount, 0.0, 0.001, "event reports zero HP damage")
	s.player.iframes = 0.0
	s._hurt_player(5.0, &"grunt", &"contact", s.player.pos, Vector2.RIGHT)
	c.near(s.player.shield, 0.0, 0.001, "shield can be exhausted")
	c.near(s.player.hp, s.player.max_hp() - 2.0, 0.001, "excess damage reaches HP")
	c.near(hurt[1].absorbed, 3.0, 0.001, "second event reports the remaining shield")
	c.near(hurt[1].amount, 2.0, 0.001, "second event reports HP damage")


func test_shield_refills_next_wave_and_from_field_set(c: Check) -> void:
	var s := _sim(0.0)
	for id in [&"iron_heart", &"regen_patch", &"sneakers"]:
		s.player.add_item(Content.item(id))
	c.near(s.player.max_shield(), 8.0, 0.001, "field set grants a shield pool")
	s.player.shield = 0.0
	s.start_wave(2)
	c.near(s.player.shield, 8.0, 0.001, "shield refills at wave start")
