extends RefCounted


func _spawn(kind: StringName, def_id: StringName = &"grunt") -> PendingSpawn:
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(def_id)
	spawn.pos = Vector2(320.0, 260.0)
	spawn.delay = Sim.SPAWN_TELEGRAPH * 0.5
	spawn.elite_kind = kind
	return spawn


func _regular_enemies() -> Array[EnemyDef]:
	var regular: Array[EnemyDef] = []
	for def: EnemyDef in Content.enemies():
		if not def.is_boss:
			regular.append(def)
	return regular


func _materialize(spawn: PendingSpawn) -> EnemyState:
	var sim := Sim.new(1)
	sim.start_run()
	sim.wave = 10
	sim._materialize(spawn)
	return sim.enemies[0]


func test_every_regular_enemy_and_elite_kind_keep_art_and_rule_identity(c: Check) -> void:
	var regular := _regular_enemies()
	c.eq(regular.size(), 6, "the complete regular enemy catalog is under elite presentation coverage")
	var combinations := 0
	for def: EnemyDef in regular:
		for kind: StringName in WaveDirector.ELITE_KINDS:
			var spawn := _spawn(kind, def.id)
			var enemy := _materialize(spawn)
			var pending := ArenaPainter.pending_spawn_profile(spawn)
			var active := ArenaPainter.enemy_rule_profile(
					enemy, Vector2(420.0, 260.0), 0.0)
			var art_key := PresentationAssets.enemy_key(enemy.def)
			c.eq(enemy.elite_kind, kind,
					"%s %s materializes with its modifier" % [def.id, kind])
			c.eq(pending["elite_kind"], active["elite_kind"],
					"%s %s identity survives telegraph to enemy" % [def.id, kind])
			c.eq(pending["color"], active["aura_color"],
					"%s %s telegraph and aura share the renderer palette" % [def.id, kind])
			c.near(float(pending["body_radius"]), enemy.radius, 0.001,
					"%s %s telegraphs its materialized radius" % [def.id, kind])
			c.ok(PresentationAssets.texture(art_key) != null,
					"%s %s retains imported enemy art" % [def.id, kind])
			var art_size: Vector2 = active["art_size"]
			c.ok(enemy.radius > def.radius and art_size.x > 0.0 and art_size.y > 0.0,
					"%s %s presents its runtime elite radius" % [def.id, kind])
			combinations += 1
	c.eq(combinations, regular.size() * WaveDirector.ELITE_KINDS.size(),
			"every regular enemy and elite-kind combination is covered")


func test_runtime_rule_geometry_uses_overrides_and_scaled_radius(c: Check) -> void:
	var volatile := _materialize(_spawn(&"volatile"))
	var bulwark := _materialize(_spawn(&"bulwark"))
	var base := EnemyState.new()
	base.def = volatile.def
	base.pos = volatile.pos
	base.radius = base.def.radius
	var target := volatile.pos + Vector2(0.0, -100.0)
	var volatile_profile := ArenaPainter.enemy_rule_profile(volatile, target, 0.25)
	var bulwark_profile := ArenaPainter.enemy_rule_profile(bulwark, target, 0.25)
	var base_profile := ArenaPainter.enemy_rule_profile(base, target, 0.25)
	c.near(float(volatile_profile["death_radius"]), volatile.death_radius_value(), 0.001,
			"death rule uses the runtime radius override")
	c.near(float(bulwark_profile["shield_arc"]), bulwark.shield_arc_value(), 0.001,
			"shield rule uses the runtime arc override")
	c.near(float(bulwark_profile["shield_end"]) - float(bulwark_profile["shield_start"]),
			deg_to_rad(bulwark.shield_arc_value()), 0.001,
			"shield geometry spans the authoritative runtime arc")
	var art_size: Vector2 = volatile_profile["art_size"]
	var base_art_size: Vector2 = base_profile["art_size"]
	c.near(art_size.x / base_art_size.x, volatile.radius / volatile.def.radius, 0.001,
			"elite art width follows the runtime radius scale")
	c.near(float(volatile_profile["aura_radius"]) - float(base_profile["aura_radius"]),
			volatile.radius - volatile.def.radius, 0.001,
			"elite aura follows the same scaled body radius")


func test_non_warden_bulwark_shield_faces_player_in_every_direction(c: Check) -> void:
	for def: EnemyDef in _regular_enemies():
		if def.id == &"warden":
			continue
		var enemy := _materialize(_spawn(&"bulwark", def.id))
		for offset: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var profile := ArenaPainter.enemy_rule_profile(
					enemy, enemy.pos + offset * 100.0, 1.0)
			var shown_direction := Vector2.from_angle(float(profile["shield_center"]))
			c.ok(shown_direction.dot(offset.normalized()) > 0.999,
					"%s bulwark shield faces %s" % [def.id, offset])
			c.near(float(profile["shield_radius"]), enemy.radius + 6.0, 0.001,
					"%s bulwark shield stays outside its scaled body" % def.id)


func test_reduced_elite_rules_are_stable_but_visible(c: Check) -> void:
	var enemy := _materialize(_spawn(&"overclocked"))
	enemy.pos = Vector2.ZERO
	var standard_a := ArenaPainter.enemy_rule_profile(enemy, Vector2.ZERO, 0.0, false)
	var standard_b := ArenaPainter.enemy_rule_profile(
			enemy, Vector2.ZERO, PI / (2.0 * 4.5), false)
	var reduced_a := ArenaPainter.enemy_rule_profile(enemy, Vector2.ZERO, 0.0, true)
	var reduced_b := ArenaPainter.enemy_rule_profile(enemy, Vector2.ZERO, 9.0, true)
	var volatile := _materialize(_spawn(&"volatile"))
	var reduced_death_a := ArenaPainter.enemy_rule_profile(volatile, Vector2.ZERO, 0.0, true)
	var reduced_death_b := ArenaPainter.enemy_rule_profile(volatile, Vector2.ZERO, 9.0, true)
	c.ok(not is_equal_approx(float(standard_a["aura_alpha"]), float(standard_b["aura_alpha"])),
			"standard elite aura retains its pulse")
	c.ok(bool(standard_a["aura_secondary"]), "standard elite keeps its rotating identity ring")
	c.near(float(reduced_a["aura_alpha"]), float(reduced_b["aura_alpha"]), 0.0001,
			"reduced elite aura is stable across time")
	c.ok(not bool(reduced_a["aura_secondary"]), "reduced elite removes the rotating second ring")
	c.ok(float(reduced_a["aura_radius"]) > enemy.radius,
			"reduced elite keeps a visible rule aura outside the body")
	c.near(float(reduced_death_a["death_alpha"]), float(reduced_death_b["death_alpha"]),
			0.0001, "reduced volatile warning is stable across time")
	c.near(float(reduced_death_a["death_radius"]), volatile.death_radius_value(), 0.001,
			"reduced volatile warning retains the runtime rule radius")
