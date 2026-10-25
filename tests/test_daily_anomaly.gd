extends RefCounted


func test_daily_anomaly_is_seeded_and_known(c: Check) -> void:
	var first := DailyAnomaly.for_seed(20261025)
	var second := DailyAnomaly.for_seed(20261025)
	c.eq(first, second, "same date picks the same anomaly")
	c.ok(first in DailyAnomaly.ALL, "the picked anomaly is known")
	for id in DailyAnomaly.ALL:
		c.ok(Loc.t(DailyAnomaly.title_key(id)) != "daily." + String(id),
				"daily anomaly has a localized title")


func test_daily_anomalies_apply_to_the_sim(c: Check) -> void:
	var echo := Sim.new(7)
	echo.daily_modifier = DailyAnomaly.ECHO_SURGE
	echo.start_run()
	c.near(echo.echo_power(), 0.50 + DailyAnomaly.ECHO_BONUS, 0.001,
			"echo surge adds echo power")

	var rift := Sim.new(7)
	rift.daily_modifier = DailyAnomaly.RIFTFALL
	rift.start_run()
	c.eq(rift.ascension_rift_wave(), DailyAnomaly.RIFT_WAVE, "riftfall starts earlier")
	c.eq(rift.ascension_rift_interval(), DailyAnomaly.RIFT_INTERVAL,
			"riftfall uses the faster interval")

	var hunt := Sim.new(7)
	hunt.daily_modifier = DailyAnomaly.TWIN_HUNT
	hunt.start_run()
	c.eq(hunt.ascension_elite_count(), 2, "twin hunt plans two elites")

	var fortune := Sim.new(7)
	fortune.daily_modifier = DailyAnomaly.FORTUNE
	fortune.start_run()
	c.near(fortune.material_drop_multiplier(), DailyAnomaly.FORTUNE_DROP_MULT, 0.001,
			"fortune increases material drops")

	var storm := Sim.new(7)
	storm.daily_modifier = DailyAnomaly.RIFTSTORM
	storm.start_run()
	c.eq(storm.ascension_rift_wave(), DailyAnomaly.RIFT_WAVE,
			"riftstorm starts at the early wave")
	c.eq(storm.ascension_rift_interval(), DailyAnomaly.RIFTSTORM_INTERVAL,
			"riftstorm uses the fast interval")

	var glass := Sim.new(7)
	glass.daily_modifier = DailyAnomaly.GLASS_CANNON
	glass.start_run()
	c.near(glass.player.stats.get_stat(Stats.DAMAGE_PCT),
			DailyAnomaly.GLASS_DAMAGE_BONUS, 0.001, "glass adds damage")
	c.near(glass.player.stats.get_stat(Stats.MAX_HP), 30.0 * 0.8, 0.001,
			"glass reduces max HP")
	c.eq(glass.player.hp, glass.player.max_hp(), "glass starts at the reduced max HP")

	var horde := Sim.new(7)
	horde.daily_modifier = DailyAnomaly.HORDE
	horde.start_run()
	c.near(horde.wave_budget_multiplier(), DailyAnomaly.HORDE_BUDGET_MULT, 0.001,
			"horde increases the wave budget")
	horde.start_wave(5)
	var normal_five := Sim.new(7)
	normal_five.start_run()
	normal_five.start_wave(5)
	c.ok(horde._plan.size() > normal_five._plan.size(),
			"the same seed plans more enemies under horde")

	var bloom := Sim.new(7)
	bloom.daily_modifier = DailyAnomaly.ECHO_BLOOM
	bloom.start_run()
	c.eq(bloom.echo_capacity(), 3, "echo bloom adds one slot")

	var normal := Sim.new(7)
	normal.start_run()
	var normal_grunt := _grunt(normal)
	normal.damage_enemy(normal_grunt, 99999.0, Vector2.ZERO, false)
	c.eq(normal.pickups[0].value, normal_grunt.def.drop,
			"normal kills use the base drop")

	var lucky := Sim.new(7)
	lucky.daily_modifier = DailyAnomaly.FORTUNE
	lucky.start_run()
	var lucky_grunt := _grunt(lucky)
	lucky.damage_enemy(lucky_grunt, 99999.0, Vector2.ZERO, false)
	c.eq(lucky.pickups[0].value,
			int(round(float(lucky_grunt.def.drop) * DailyAnomaly.FORTUNE_DROP_MULT)),
			"fortune rounds the multiplied drop")


func test_daily_main_passes_the_date_anomaly(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.start_daily()
	c.eq(main.sim.daily_modifier, DailyAnomaly.for_seed(main.today_seed()),
			"daily starts with today's anomaly")
	c.eq(main.sim.ascension, 0, "daily stays at ascension zero")
	c.ok(main._daily_run, "daily flag is set")
	main.free()


func _grunt(s: Sim) -> EnemyState:
	var ps := PendingSpawn.new()
	ps.def = Content.enemy(&"grunt")
	ps.pos = s.player.pos + Vector2(100.0, 0.0)
	s._materialize(ps)
	return s.enemies[s.enemies.size() - 1]


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
