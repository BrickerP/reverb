extends RefCounted


func test_weapons_are_sane(c: Check) -> void:
	c.ok(Content.weapon(Content.STARTER_WEAPON) != null, "starter weapon exists")
	c.eq(Content.weapons().size(), 35, "eighteen bases, twelve final forms and five support weapons")
	var families := {}
	for id: StringName in Content.weapons():
		var w := Content.weapon(id)
		c.eq(w.id, id, "%s: registry key matches id" % id)
		c.ok(w.damage > 0.0 and w.cooldown > 0.0 and w.reach > 0.0, "%s: positive combat numbers" % id)
		c.ok(w.projectile_speed > 0.0 and w.projectile_radius > 0.0, "%s: positive projectile numbers" % id)
		c.ok(w.pellets >= 1 and w.pierce >= 0 and w.price > 0, "%s: pellets, pierce, price" % id)
		c.ok(not str(w.family).is_empty(), "%s: weapon family" % id)
		if w.drops and w.support_kind == &"":
			families[w.family] = int(families.get(w.family, 0)) + 1
		c.ok(str(w.rarity) in ["common", "uncommon", "rare", "evolved"], "%s: known rarity" % id)
		if w.drops:
			c.ok(w.drop_weight > 0.0, "%s: drop weight" % id)
		else:
			c.eq(w.drop_weight, 0.0, "%s: evolved form does not drop" % id)
		for option: StringName in w.evolution_options:
			var evolved := Content.weapon(option)
			c.ok(evolved != null, "%s: evolution target exists" % id)
			if evolved != null:
				c.eq(evolved.family, w.family, "%s: evolution keeps family" % id)
				c.ok(not evolved.drops, "%s: evolved form is not a drop" % id)
				c.ok(evolved.evolution_options.is_empty(), "%s: evolution is one step" % id)
		c.ok(w.school in [&"melee", &"ranged", &"magic", &"defense", &"manufacture", &"pet"], "%s: school metadata" % id)
		c.ok(w.carrier in [&"hand", &"field", &"pet", &"placement"], "%s: carrier metadata" % id)
		c.ok(w.target_mode in [&"single", &"aoe"], "%s: target metadata" % id)
		if w.explosion_radius > 0.0:
			c.ok(w.explosion_damage > 0.0, "%s: explosion has damage" % id)
		if w.homing_turn > 0.0:
			c.ok(w.projectile_speed > 0.0, "%s: homing projectile moves" % id)
		c.ok(is_finite(w.dps()) and w.dps() >= 0.0 and w.dps() < 40.0, "%s: dps in a sane band (%s)" % [id, w.dps()])
	for family in [&"sidearm", &"scatter", &"marksman", &"arcane", &"press", &"salvage"]:
		c.eq(int(families.get(family, 0)), 3, "%s: exactly three shop weapons" % family)


func test_items_only_touch_known_stats(c: Check) -> void:
	c.ok(Content.items().size() >= 8, "at least eight items")
	var echo_items := 0
	for id: StringName in Content.items():
		var it := Content.item(id)
		c.eq(it.id, id, "%s: registry key matches id" % id)
		c.ok(not it.mods.is_empty() and it.price > 0, "%s: has mods and a price" % id)
		for stat: StringName in it.mods:
			c.ok(Stats.DEFAULTS.has(stat), "%s: stat %s exists" % [id, stat])
		if it.echo_item:
			echo_items += 1
	c.ok(echo_items >= 3, "echo-specific items exist")


func test_enemy_roster(c: Check) -> void:
	var ids := {}
	var first_wave := 0
	for e in Content.enemies():
		c.ok(not ids.has(e.id), "%s: unique id" % e.id)
		ids[e.id] = true
		c.ok(e.hp > 0.0 and e.speed > 0.0 and e.damage > 0.0 and e.radius > 0.0, "%s: positive stats" % e.id)
		if e.is_boss:
			c.ok(e.cost >= 0.0 and e.weight >= 0.0 and e.drop >= 1 and e.min_wave >= 1, "%s: boss spawn data" % e.id)
		else:
			c.ok(e.cost > 0.0 and e.weight > 0.0 and e.drop >= 1 and e.min_wave >= 1, "%s: spawn data" % e.id)
		c.ok(e.radius <= Sim.MAX_ENEMY_RADIUS, "%s: fits the spatial grid query" % e.id)
		if e.death_radius > 0.0:
			c.ok(e.death_damage > 0.0, "%s: death explosion has damage" % e.id)
		if e.shield_arc > 0.0:
			c.ok(e.shield_reduction > 0.0 and e.shield_reduction < 1.0, "%s: shield reduces damage" % e.id)
		if e.min_wave == 1:
			first_wave += 1
	c.ok(first_wave >= 1, "something can spawn on wave 1")


func test_characters_apply_to_a_run(c: Check) -> void:
	var loop := Content.character(&"looper")
	c.ok(loop != null, "looper exists")
	var a := Sim.new(1)
	loop.apply(a)
	c.eq(a.echo_capacity(), 3, "looper gets a third echo slot")
	c.near(a.echo_power(), 0.4, 0.001, "looper echoes are weaker")
	c.near(a.player.stats.damage_mult(), 1.0, 0.001, "looper keeps full personal damage")
	var solo := Content.character(&"solo")
	c.ok(solo != null, "solo exists")
	var b := Sim.new(1)
	solo.apply(b)
	c.eq(b.echo_capacity(), 0, "solo has no echoes")
	c.near(b.player.max_hp(), 55.0, 0.001, "solo gets extra health")
	c.near(b.player.stats.damage_mult(), 1.6, 0.001, "solo gets personal damage")


func test_mirror_uses_the_current_build(c: Check) -> void:
	var s := Sim.new(1)
	Content.character(&"mirror").apply(s)
	c.ok(s.live_echo, "mirror echoes are live")
	c.eq(s.echo_capacity(), 2, "two slots")
	c.near(s.echo_power(), 0.4, 0.001, "forty percent power")
	var take := EchoTake.new()
	take.weapons.append(Content.weapon(&"pistol"))
	s.player.weapons.clear()
	s.player.add_weapon(Content.weapon(&"rifle"))
	c.near(s.echo_dps(take), Content.weapon(&"rifle").dps() * 0.4, 0.001,
			"live echoes value the current weapon, not the snapshot")


func test_characters_start_with_their_direction(c: Check) -> void:
	var expected := {
		&"looper": &"pistol",
		&"solo": &"hex_bolt",
		&"mirror": &"longbow",
		&"conductor": &"pistol",
		&"mender": &"tape_spool",
		&"overloader": &"stamp",
	}
	for id: StringName in expected:
		var s := Sim.new(1)
		Content.character(id).apply(s)
		c.eq(s.player.weapons.size(), 1, "%s: one starter" % id)
		c.eq(s.player.weapons[0].id, expected[id], "%s: starter weapon" % id)


func test_conductor_scales_with_active_echoes(c: Check) -> void:
	var s := Sim.new(1)
	Content.character(&"conductor").apply(s)
	c.eq(s.echo_capacity(), 4, "conductor has four slots")
	c.near(s.echo_power(), 0.22, 0.001, "conductor echoes are weaker")
	c.near(s.synergy_damage_mult(), 1.0, 0.001, "no echoes means no team bonus")
	for i in 2:
		s.echoes.append(EchoActor.new(EchoTake.new(), i))
	c.near(s.synergy_damage_mult(), 1.09, 0.001, "each echo adds team damage")
	c.near(s.synergy_cooldown_mult(), 1.0 / 1.05, 0.001, "each echo adds team haste")


func test_solo_does_not_record_takes(c: Check) -> void:
	var s := Sim.new(1)
	Content.character(&"solo").apply(s)
	s.start_run()
	s.wave_duration = 0.001
	s.step(0.01, Vector2.ZERO)
	c.eq(s.phase, Sim.Phase.SHOP, "wave ended")
	c.eq(s.bank.takes.size(), 0, "no take is recorded without echo slots")


func test_each_attack_style_has_usable_geometry(c: Check) -> void:
	var styles := {}
	var shop_count := 0
	var evolution_count := 0
	for id: StringName in Content.weapons():
		var weapon := Content.weapon(id)
		styles[weapon.attack_style] = true
		if weapon.drops:
			shop_count += 1
		else:
			evolution_count += 1
		match weapon.attack_style:
			&"burst":
				c.ok(weapon.burst_count > 1 and weapon.burst_interval > 0.0,
						"%s: burst has multiple timed shots" % id)
				c.ok(float(weapon.burst_count - 1) * weapon.burst_interval < weapon.cooldown,
						"%s: burst completes before the next volley" % id)
			&"pin":
				c.ok(weapon.pin_duration > 0.0, "%s: pin has a real duration" % id)
			&"cone":
				c.ok(weapon.spread_deg > 0.0 and weapon.spread_deg < 180.0,
						"%s: cone has a bounded forward arc" % id)
			&"slam":
				c.ok(weapon.windup > 0.0 and weapon.field_radius > 0.0,
						"%s: slam has a warning and impact radius" % id)
			&"line":
				c.ok(weapon.line_width > 0.0 and weapon.field_duration > 0.0,
						"%s: continuous line has finite geometry" % id)
			&"ink", &"tape":
				c.ok(weapon.field_radius > 0.0 and weapon.field_duration > 0.0,
						"%s: persistent field has radius and lifetime" % id)
				c.ok(weapon.ink_duration > 0.0 or weapon.pin_duration > 0.0,
						"%s: persistent field applies a status" % id)
			&"boomerang":
				c.ok(weapon.return_time > 0.0, "%s: boomerang returns" % id)
			&"chain":
				c.ok(weapon.chain_count > 1 and weapon.chain_count <= 8 and weapon.chain_radius > 0.0,
						"%s: chain has a finite jump budget" % id)
			&"orbit":
				c.ok(weapon.orbit_radius > 0.0 and absf(weapon.orbit_speed) > 0.0
						and weapon.field_duration > 0.0 and weapon.field_radius > 0.0,
						"%s: orbit has radius, motion and lifetime" % id)
			&"pet", &"turret", &"guard", &"fabricate":
				c.ok(SupportSystem.PROFILES.has(weapon.support_kind), "%s: real support kind" % id)
			&"projectile":
				pass
			_:
				c.ok(false, "%s: unsupported attack style" % id)
		if weapon.attack_style in [&"line", &"ink", &"tape", &"orbit"]:
			c.ok(weapon.tick_interval > 0.0 and weapon.tick_interval <= weapon.field_duration,
					"%s: finite field emits at least one pulse" % id)
	c.eq(shop_count, 23, "shop roster is complete")
	c.eq(evolution_count, 12, "evolution roster is complete")
	c.eq(styles.size(), 15, "all fifteen distinct attack styles ship")


func test_dps_counts_bursts_fields_and_return_hits(c: Check) -> void:
	var weapon := WeaponDef.new()
	weapon.damage = 10.0
	weapon.cooldown = 2.0
	weapon.pellets = 2
	weapon.attack_style = &"burst"
	weapon.burst_count = 3
	c.near(weapon.dps(), 30.0, 0.001, "burst estimate includes each shot")
	weapon.attack_style = &"cone"
	c.near(weapon.dps(), 5.0, 0.001, "cone estimate counts one hit per target")
	weapon.attack_style = &"line"
	weapon.field_duration = 1.0
	weapon.tick_interval = 0.25
	c.near(weapon.dps(), 20.0, 0.001, "line estimate counts bounded pulses")
	weapon.attack_style = &"boomerang"
	c.near(weapon.dps(), 20.0, 0.001, "each returning pellet can hit each direction")
	weapon.cooldown = 0.0
	weapon.tick_interval = 0.0
	weapon.attack_style = &"line"
	c.ok(is_finite(weapon.dps()), "malformed preview timing cannot divide by zero")


func test_new_roles_apply_and_reset_their_rules(c: Check) -> void:
	c.eq(Content.characters().size(), 6, "all six characters exist")
	var sim := Sim.new(1)
	var mender := Content.character(&"mender")
	mender.apply(sim)
	c.eq(mender.unlock_wave, 3, "mender unlocks at encounter three")
	c.near(sim.repair_discount, 0.25, 0.001, "mender repair discount is applied")
	c.near(sim.pickup_repair, 0.6, 0.001, "mender pickup repair is applied")
	var overloader := Content.character(&"overloader")
	overloader.apply(sim)
	c.eq(overloader.unlock_wave, 7, "overloader unlocks at encounter seven")
	c.near(sim.wear_rate_mult, 1.35, 0.001, "overloader wears faster")
	c.near(sim.retirement_mult, 1.5, 0.001, "overloader retirement is stronger")
	c.near(sim.pickup_repair, 0.0, 0.001, "changing roles clears pickup repair")
	Content.character(&"looper").apply(sim)
	c.near(sim.repair_discount, 0.0, 0.001, "ordinary role clears repair discount")
	c.near(sim.wear_rate_mult, 1.0, 0.001, "ordinary role restores normal wear")
	c.near(sim.retirement_mult, 1.0, 0.001, "ordinary role restores normal retirement")


func test_long_play_adds_seconds(c: Check) -> void:
	c.eq(Content.item(&"long_play").mods, {Stats.ECHO_DURATION: 40.0},
			"Long Play extends playback by forty combat seconds")


func test_two_final_forms_per_family_change_delivery(c: Check) -> void:
	var final_ids := {}
	var bases := 0
	for weapon: WeaponDef in Content.weapons().values():
		if weapon.support_kind != &"" or not weapon.drops:
			continue
		bases += 1
		c.eq(weapon.evolution_options.size(), 2, "%s offers two intentional final forms" % weapon.id)
		var a := Content.weapon(weapon.evolution_options[0])
		var b := Content.weapon(weapon.evolution_options[1])
		c.ok(a.attack_style != b.attack_style, "%s choices change attack geometry" % weapon.id)
		for evolved: WeaponDef in [a, b]:
			final_ids[evolved.id] = true
			c.ok(evolved.dps() >= 9.0 and evolved.dps() <= 24.0, "%s has bounded single-target output" % evolved.id)
	c.eq(bases, 18, "all original base weapons retained")
	c.eq(final_ids.size(), 12, "six families have twelve unique final forms")


func test_every_role_unlock_is_reachable_in_campaign(c: Check) -> void:
	for character: CharacterDef in Content.characters().values():
		c.ok(character.unlock_wave <= 12, "%s unlock fits campaign" % character.id)
	c.eq(Content.character(&"solo").unlock_wave, 4, "Solo at first boss")
	c.eq(Content.character(&"conductor").unlock_wave, 8, "Binder at second boss")
	c.eq(Content.character(&"mirror").unlock_wins, 1, "Mirror needs one campaign win")
	for boss_id: StringName in [&"foreman", &"collector", &"paradox"]:
		var boss := Content.enemy(boss_id)
		c.ok(boss != null and boss.is_boss, "%s is a canonical boss" % boss_id)
