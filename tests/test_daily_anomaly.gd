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


func test_daily_main_passes_the_date_anomaly(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.start_daily()
	c.eq(main.sim.daily_modifier, DailyAnomaly.for_seed(main.today_seed()),
			"daily starts with today's anomaly")
	c.eq(main.sim.ascension, 0, "daily stays at ascension zero")
	c.ok(main._daily_run, "daily flag is set")
	main.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
