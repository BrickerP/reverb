extends RefCounted


func test_all_weapon_identities_have_distinct_drawn_language(c: Check) -> void:
	var glyphs: Array[StringName] = []
	var gestures: Array[StringName] = []
	var impacts: Array[StringName] = []
	for weapon: WeaponDef in Content.weapons().values():
		var p := WeaponInk.profile(weapon.id)
		c.eq(p["weapon_id"], weapon.id, "profile keeps the authoritative weapon identity")
		c.eq(p["style"], weapon.family, "family remains recognisable without merging identities")
		c.ok(float(p["length"]) > 0.0 and float(p["recoil"]) > 0.0, "muzzle and recoil are bounded positive signals")
		c.ok(not glyphs.has(p["glyph"]), "%s has its own projectile silhouette" % weapon.id)
		c.ok(not gestures.has(p["muzzle"]), "%s has its own muzzle gesture" % weapon.id)
		c.ok(not impacts.has(p["impact"]), "%s has its own impact mark" % weapon.id)
		glyphs.append(p["glyph"])
		gestures.append(p["muzzle"])
		impacts.append(p["impact"])
	c.eq(glyphs.size(), 24, "all twenty-four shipped weapons have explicit art language")
	var first := WeaponInk.profile(&"pistol")
	first["recoil"] = 999.0
	c.ok(float(WeaponInk.profile(&"pistol")["recoil"]) < 10.0, "a shot cannot mutate the global identity catalog")
	var unknown := WeaponInk.profile(&"stress_fixture_only")
	c.eq(unknown["weapon_id"], &"stress_fixture_only", "unknown metadata remains honest")
	c.eq(unknown["glyph"], &"ink", "unknown metadata uses a neutral head, not a fake known gun")


func test_projectile_silhouettes_fit_the_real_contact_disc_and_rasterise(c: Check) -> void:
	var ids := WeaponInk.IDS.duplicate()
	ids.append(&"unknown_fixture")
	for id: StringName in ids:
		var points := WeaponInk.glyph_outline(id)
		c.ok(points.size() >= 3, "%s is a complete silhouette" % id)
		for point in points:
			c.ok(point.is_finite() and point.length() <= 1.0, "%s stays inside collision radius" % id)
		c.ok(not Geometry2D.triangulate_polygon(points).is_empty(), "%s has nondegenerate topology" % id)
		var image := Image.new()
		c.eq(image.load_svg_from_string(WeaponInk.glyph_svg(id)), OK, "%s source glyph rasterises in the shipped SVG renderer" % id)
		c.eq(image.get_size(), Vector2i(32, 32), "%s has the fixed tiny runtime texture budget" % id)
		c.ok(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(31, 31).a == 0.0,
				"glyph background stays transparent")


func test_direction_uses_velocity_without_stretching_radius_or_range(c: Check) -> void:
	var center := Vector2(800.0, 420.0)
	for velocity: Vector2 in [Vector2.RIGHT * 200.0, Vector2.DOWN * 50.0, Vector2(-20.0, -30.0), Vector2.ZERO]:
		var transform := WeaponInk.flight_transform(center, velocity, 4.0)
		c.eq(transform.origin, center, "head stays at the simulated position")
		c.near(transform.x.length(), 4.0, 0.00001, "forward basis is actual radius, not weapon reach")
		c.near(transform.y.length(), 4.0, 0.00001, "cross basis is actual radius")
		c.near(transform.x.dot(transform.y), 0.0, 0.00001, "head rotation keeps an orthogonal contact disc")
		var expected := velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
		c.near(transform.x.normalized().distance_to(expected), 0.0, 0.00001, "zero speed has the same RIGHT convention as firing")
	for radius: float in [0.0, -1.0, NAN, INF]:
		var transform := WeaponInk.flight_transform(center, Vector2.RIGHT, radius)
		c.eq(transform.x, Vector2.ZERO, "invalid radii have no drawable geometry")
		c.ok(transform.origin.is_finite(), "invalid geometry cannot send NaN to the GPU")
	var projectile := Projectile.new()
	projectile.dead = true
	c.ok(not WeaponInk.valid_projectile(projectile), "retired projectiles never remain visible")
	projectile.dead = false
	projectile.pos = Vector2(INF, 0.0)
	c.ok(not WeaponInk.valid_projectile(projectile), "nonfinite positions cannot reach a render batch")


func test_density_and_reduced_mode_keep_heads_but_drop_optional_trails(c: Check) -> void:
	c.ok(WeaponInk.trails_enabled(false, 160), "ordinary sparse volleys retain short trails")
	c.ok(not WeaponInk.trails_enabled(false, 161), "dense volleys discard extra line submissions")
	c.ok(not WeaponInk.trails_enabled(true, 1), "reduced effects discard optional motion even at low density")
	var projectile := Projectile.new()
	projectile.color = Color("82935e")
	var regular := WeaponInk.projectile_color(projectile)
	projectile.crit = true
	c.ok(WeaponInk.projectile_color(projectile) != regular, "a critical head stays readable independently of trail mode")
	WeaponInk.draw_projectiles(null, null, true)
	c.eq(WeaponInk.render_stats()["projectiles"], 0, "an unbound view cannot reuse the previous scene's heads")
	c.eq(WeaponInk.render_stats()["draw_calls"], 0, "an unbound view submits no stale batch")


func test_weapon_blast_ownership_does_not_double_draw_other_sources(c: Check) -> void:
	c.ok(WeaponInk.owns_explosion({"kind": ExplosionInfo.WEAPON, "effect": &"explosion"}),
			"ordinary weapon blasts belong to this module")
	c.ok(not WeaponInk.owns_explosion({"kind": ExplosionInfo.BOMBER, "effect": &"explosion"}),
			"enemy death hazards remain in the threat renderer")
	c.ok(not WeaponInk.owns_explosion({"kind": ExplosionInfo.WEAPON, "effect": &"echo_collapse"}),
			"copy consumption retains its own actor performance")
	c.ok(not WeaponInk.owns_explosion({"kind": ExplosionInfo.WEAPON, "effect": &"shield_break"}),
			"survival shield feedback is not mistaken for a known gun")
	WeaponInk.draw_feedback(null, [], [], [], false)
	c.eq(WeaponInk.feedback_stats(), {"muzzles": 0, "hits": 0, "blasts": 0},
			"empty or unbound feedback cannot retain another scene's marks")


func test_feedback_lifetime_rejects_degenerate_or_expired_marks(c: Check) -> void:
	for data: Dictionary in [{}, {"life": 1.0, "max_life": 0.0},
			{"life": -0.1, "max_life": 0.15}, {"life": NAN, "max_life": 0.15},
			{"life": 0.1, "max_life": INF}]:
		c.eq(WeaponInk._life(data), 0.0, "invalid lifetime cannot become an infinite or negative feedback scale")
	c.eq(WeaponInk._life({"life": 2.0, "max_life": 1.0}), 1.0,
			"late or duplicated state never scales a mark beyond its intended silhouette")
