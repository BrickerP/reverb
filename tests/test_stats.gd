extends RefCounted


func test_defaults_and_add(c: Check) -> void:
	var s := Stats.new()
	c.near(s.get_stat(Stats.MAX_HP), 30.0, 0.001, "default max hp")
	s.add(Stats.MAX_HP, 8.0)
	c.near(s.get_stat(Stats.MAX_HP), 38.0, 0.001, "max hp after add")
	c.eq(s.get_stat(&"does_not_exist"), 0.0, "unknown stat is zero")


func test_copy_is_independent(c: Check) -> void:
	var a := Stats.new()
	var b := a.copy()
	b.add(Stats.DAMAGE_PCT, 0.5)
	c.near(a.get_stat(Stats.DAMAGE_PCT), 0.0, 0.0001, "original unchanged")
	c.near(b.get_stat(Stats.DAMAGE_PCT), 0.5, 0.0001, "copy changed")


func test_multipliers(c: Check) -> void:
	var s := Stats.new()
	s.add(Stats.ATTACK_SPEED_PCT, 1.0)
	c.near(s.cooldown_mult(), 0.5, 0.0001, "double attack speed halves cooldown")
	s.add(Stats.DAMAGE_PCT, -2.0)
	c.near(s.damage_mult(), 0.0, 0.0001, "damage multiplier floors at zero")
	s.add(Stats.ATTACK_SPEED_PCT, -5.0)
	c.near(s.cooldown_mult(), 10.0, 0.0001, "attack speed floor caps cooldown at 10x")
