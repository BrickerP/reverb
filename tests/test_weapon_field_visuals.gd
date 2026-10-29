extends RefCounted


func _press(id: StringName, windup: float) -> AttackField:
	var field := AttackField.new()
	field.weapon_id = id
	field.style = &"slam"
	field.pos = Vector2(640.0, 420.0)
	field.origin = Vector2(560.0, 420.0)
	field.radius = 42.0
	field.windup = windup
	return field


func test_press_warning_projects_the_real_weapon_above_its_contact_area(c: Check) -> void:
	for id: StringName in [&"stamp", &"mallet", &"hydraulic_press"]:
		var field := _press(id, 0.3)
		var projection := WeaponInk.press_projection(field)
		var center: Vector2 = projection["center"]
		c.near(center.x, field.pos.x, 0.001, "%s remains aligned with the actual slam target" % id)
		c.ok(center.y < field.pos.y, "%s has a readable raised weapon instead of only a circle" % id)
		c.ok(float(projection["width"]) >= 28.0 and float(projection["height"]) >= 28.0,
				"%s weapon art remains recognisable at native resolution" % id)
		c.ok(float(projection["drop"]) > 0.0, "%s projects a real downward press gesture" % id)


func test_reduced_press_keeps_the_static_weapon_without_falling_motion(c: Check) -> void:
	var field := _press(&"stamp", 0.3)
	var early := WeaponInk.press_projection(field, true)
	field.windup = 0.03
	var late := WeaponInk.press_projection(field, true)
	c.eq(early["center"], late["center"], "reduced press keeps a static cue throughout the warning")
	c.eq(early["drop"], late["drop"], "reduced effects remove the falling offset animation")
	c.ok(float(early["height"]) > 0.0, "reduced effects retain the weapon identity")


func test_heavy_impacts_have_a_native_readable_baseline(c: Check) -> void:
	var light := WeaponInk.hit_mark_size(WeaponInk.profile(&"pistol")["impact"], 1.0, false)
	for id: StringName in [&"stamp", &"mallet", &"hydraulic_press"]:
		var glyph: StringName = WeaponInk.profile(id)["impact"]
		for reduced: bool in [false, true]:
			var heavy := WeaponInk.hit_mark_size(glyph, 1.0, reduced)
			c.ok(heavy >= 14.0, "%s impact has a visible paper/ink impression in either effect mode" % id)
			c.ok(heavy > light, "%s reads as a heavy press rather than a tiny projectile hit" % id)
			c.ok(WeaponInk.hit_mark_size(glyph, 0.1, reduced) <= heavy,
					"%s feedback shrinks rather than growing after contact" % id)


func test_press_culling_includes_raised_art_without_changing_attack_geometry(c: Check) -> void:
	var field := _press(&"hydraulic_press", 0.3)
	var target := field.pos
	var radius := field.radius
	var projection := WeaponInk.press_projection(field)
	var center: Vector2 = projection["center"]
	var half_size := Vector2(float(projection["width"]), float(projection["height"])) * 0.5
	var bounds := WeaponInk.field_bounds(field)
	c.ok(bounds.encloses(Rect2(center - half_size, half_size * 2.0)),
			"visual bounds retain the complete raised weapon")
	var art_only_view := Rect2(center - Vector2(2.0, half_size.y), Vector2(4.0, 3.0))
	c.ok(WeaponInk.field_in_view(field, art_only_view), "an icon entering the camera is not culled with its offscreen target")
	c.eq(field.pos, target, "projection and culling leave the authoritative target untouched")
	c.eq(field.radius, radius, "decorative weapon art cannot enlarge the damage radius")
