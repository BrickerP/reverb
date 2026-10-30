extends RefCounted


func test_support_preview_matches_deployed_grade_and_limits(c: Check) -> void:
	for id: StringName in [&"paper_hound", &"debt_sentry", &"repair_kit", &"paper_seed", &"guard_decoy"]:
		for level in [0, WeaponDef.MAX_LEVEL]:
			var sim := Sim.new(31)
			var weapon := Content.weapon(id)
			var profile := SupportSystem.weapon_profile(weapon, level, 900.0, 0.01, 100.0)
			c.ok(SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 900.0, -1, -1, Color.WHITE, level, 0.01, 100.0), "canonical support deploys")
			var unit: Dictionary = sim.support_units[0]
			for key: String in ["hp", "max_hp", "life", "interval", "damage", "charges", "level", "reach"]:
				c.eq(profile[key], unit[key], "%s grade%d preview matches actual %s" % [id, level, key])
			c.eq(profile["interval"], 0.15, "cadence floor is actual")
			c.eq(profile["reach"], 1200.0, "reach cap is actual")
			if weapon.support_kind == &"repair_station":
				c.eq(profile["heal_hp"], 1.5 * (1.0 + 0.15 * float(level)), "preview reports real player healing")
				c.eq(profile["repair_condition"], 2.0 * (1.0 + 0.15 * float(level)), "preview reports real condition repair")
			elif weapon.support_kind == &"paper_tree":
				c.eq(profile["shield"], 2.0 * (1.0 + 0.15 * float(level)), "preview reports real shield")
				c.eq(profile["energy"], 3.0 * (1.0 + 0.15 * float(level)), "preview reports real energy")


func test_support_preview_is_pure_and_unsupported_weapon_has_no_profile(c: Check) -> void:
	var sim := Sim.new(32)
	var before := RunSnapshot.capture(sim)
	var profile := SupportSystem.weapon_profile(Content.weapon(&"repair_kit"), 0)
	c.eq(profile["max_hp"], 28.0, "opening station does not retain endgame HP")
	c.eq(profile["heal_hp"], 1.5, "opening station does not retain endgame healing")
	c.eq(profile["charges"], 6, "station deliveries remain bounded")
	c.eq(SupportSystem.weapon_profile(Content.weapon(&"pistol"), 0), {}, "ordinary weapon has no invented support utility")
	c.eq(SupportSystem.weapon_profile(null, 0), {}, "missing weapon has no support profile")
	c.eq(SupportSystem.weapon_profile(Content.weapon(&"repair_kit"), 0, NAN), {}, "invalid damage cannot produce a usable preview")
	c.eq(SupportSystem.weapon_profile(Content.weapon(&"repair_kit"), 0, 0.0, 0.0), {}, "invalid cadence cannot produce a usable preview")
	c.eq(RunSnapshot.capture(sim), before, "preview leaves full simulation and both RNG streams unchanged")
