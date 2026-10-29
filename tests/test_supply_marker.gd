extends RefCounted


func test_ordinary_scrap_keeps_its_infinite_life_and_original_marker(c: Check) -> void:
	var pickup := Pickup.new()
	pickup.pos = Vector2(400.0, 300.0)
	var profile := ArenaPainter.pickup_profile(pickup)
	c.eq(pickup.kind, &"scrap", "ordinary drops keep their scrap kind")
	c.eq(pickup.life, 0.0, "ordinary scrap never expires by default")
	c.ok(bool(profile["visible"]) and not bool(profile["supply"]), "ordinary scrap keeps its own marker")
	c.ok(not bool(profile["timed"]), "infinite scrap does not invent an expiry warning")
	c.eq(profile["rect"], Rect2(397.0, 296.0, 6.0, 8.0), "ordinary scrap keeps its original drawn footprint")


func test_supply_marker_shows_actual_value_and_remaining_lifetime(c: Check) -> void:
	var pickup := Pickup.new()
	pickup.kind = &"supply"
	pickup.pos = Vector2(1200.0, 700.0)
	pickup.value = 21
	pickup.life = Pickup.SUPPLY_LIFETIME
	var full := ArenaPainter.pickup_profile(pickup)
	c.ok(bool(full["supply"]) and bool(full["timed"]), "limited supply has a distinct timed crate")
	c.eq(full["value"], 21, "crate stamp reports its actual collectible reward")
	c.eq(full["size"], Vector2(28.0, 24.0), "supply crate is larger than ordinary scrap")
	c.eq(Rect2(full["rect"]).get_center(), pickup.pos, "crate remains at its authoritative world position")
	c.eq(full["remaining"], Pickup.SUPPLY_LIFETIME, "crate starts with its actual lifetime")
	c.eq(full["life_fraction"], 1.0, "fresh supply has a full expiry bar")
	pickup.life = 2.0
	var urgent := ArenaPainter.pickup_profile(pickup)
	c.eq(urgent["remaining"], 2.0, "countdown follows the simulation timer")
	c.eq(urgent["life_fraction"], 0.25, "expiry bar uses the shipped eight-second window")
	c.eq(pickup.life, 2.0, "reading the marker does not age the supply")
	c.eq(urgent, ArenaPainter.pickup_profile(pickup), "repeated or Reduced drawing has no independent animation clock")


func test_zero_life_is_infinite_and_invalid_expired_markers_are_hidden(c: Check) -> void:
	var pickup := Pickup.new()
	pickup.kind = &"supply"
	var infinite := ArenaPainter.pickup_profile(pickup)
	c.ok(bool(infinite["visible"]) and not bool(infinite["timed"]), "zero lifetime keeps the shared infinite-life meaning")
	pickup.life = -0.1
	c.ok(not bool(ArenaPainter.pickup_profile(pickup)["visible"]), "negative expired supply never draws a stale countdown")
	pickup.life = NAN
	c.ok(not bool(ArenaPainter.pickup_profile(pickup)["visible"]), "nonfinite timers are not drawn")
	c.ok(not bool(ArenaPainter.pickup_profile(null)["visible"]), "missing pickup is safe")
	pickup.life = 20.0
	c.eq(ArenaPainter.pickup_profile(pickup)["life_fraction"], 1.0, "oversized restored lifetime stays within the bar")
