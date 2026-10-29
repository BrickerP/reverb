extends RefCounted


func _enemy(id: StringName = &"grunt", kind: StringName = &"") -> EnemyState:
	var sim := Sim.new(37)
	sim.start_run()
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(id)
	spawn.pos = Vector2(320.0, 260.0)
	spawn.elite_kind = kind
	sim._materialize(spawn)
	return sim.enemies[0]


func test_every_elite_rule_has_a_non_color_identity_and_runtime_geometry(c: Check) -> void:
	var names: Array[StringName] = []
	var marks: Array[PackedVector2Array] = []
	for kind: StringName in WaveDirector.ELITE_KINDS:
		var enemy := _enemy(&"grunt", kind)
		var p := ThreatInk.profile(enemy, enemy.pos + Vector2.RIGHT * 100.0, 1.0)
		c.ok(bool(p["valid"]), "materialized elite has valid marks")
		c.ok(not names.has(p["glyph"]), "each elite remains distinct without its color")
		names.append(p["glyph"])
		var segments: PackedVector2Array = p["glyph_segments"]
		c.ok(not segments.is_empty() and segments.size() % 2 == 0, "badge has drawable line pairs")
		c.ok(not marks.has(segments), "grayscale silhouettes are not color-swapped copies")
		marks.append(segments)
		for point in segments:
			c.ok(point.is_finite() and point.length() <= 9.0, "badge stays bounded above the body")
	for def: EnemyDef in Content.enemies():
		if def.is_boss:
			continue
		for kind: StringName in WaveDirector.ELITE_KINDS:
			var enemy := _enemy(def.id, kind)
			var p := ThreatInk.profile(enemy, enemy.pos + Vector2.DOWN * 100.0, 0.5)
			c.eq(p["elite_kind"], kind, "every regular silhouette keeps its elite rule")
			c.near(float(p["death_radius"]), enemy.death_radius_value(), 0.0001,
					"death outline reads the runtime override")
			c.near(float(p["shield_arc"]), enemy.shield_arc_value(), 0.0001,
					"shield outline reads the runtime override")
			var art: Vector2 = p["art_size"]
			c.ok(art.is_finite() and art.x > 0.0 and art.y > 0.0, "all enemy badges have finite calibration")
			c.ok((p["glyph_anchor"] as Vector2).y < enemy.pos.y - enemy.radius,
					"identity sits above the actor instead of covering its center")


func test_shields_face_the_real_target_and_latent_blast_is_not_a_countdown(c: Check) -> void:
	for id: StringName in [&"warden", &"grunt"]:
		var enemy := _enemy(id, &"bulwark" if id == &"grunt" else &"")
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var p := ThreatInk.profile(enemy, enemy.pos + direction * 100.0, 0.0)
			c.ok(Vector2.from_angle(float(p["shield_center"])).dot(direction) > 0.999,
					"front plate follows the direction used by damage reduction")
			c.near(float(p["shield_end"]) - float(p["shield_start"]),
					deg_to_rad(enemy.shield_arc_value()), 0.0001, "shield angle is exact")
			c.near(float(p["shield_radius"]), enemy.radius + 6.0, 0.0001,
					"front band is registered to the actual enemy center")
	var bomber := _enemy(&"bomber")
	var volatile := _enemy(&"grunt", &"volatile")
	for enemy: EnemyState in [bomber, volatile]:
		var early := ThreatInk.profile(enemy, enemy.pos, 0.0)
		var late := ThreatInk.profile(enemy, enemy.pos, 99.0)
		c.ok(bool(early["latent_blast"]), "explosive enemies advertise a potential death blast")
		c.eq(early["death_radius"], late["death_radius"], "no invented windup changes the dangerous area")
		c.near(float(early["death_radius"]), enemy.death_radius_value(), 0.0001,
				"52/64 or future runtime overrides remain authoritative")


func test_reduced_marks_keep_identity_without_time_based_motion(c: Check) -> void:
	var enemy := _enemy(&"grunt", &"overclocked")
	var first := ThreatInk.profile(enemy, enemy.pos, 0.0, true)
	var later := ThreatInk.profile(enemy, enemy.pos, 100.0, true)
	for field in ["aura_alpha", "death_alpha", "secondary_start", "glyph_tilt", "glyph_segments"]:
		c.eq(first[field], later[field], "reduced mark remains static: " + field)
	c.ok(not bool(first["aura_secondary"]), "reduced marks omit the orbiting tick")
	c.eq(first["glyph"], &"double_chevron", "reduced mode keeps the non-color warning")
	var other := _enemy(&"grunt", &"overclocked")
	other.uid = enemy.uid + 1
	var other_profile := ThreatInk.profile(other, other.pos, 0.0, true)
	c.ok(first["glyph_tilt"] != other_profile["glyph_tilt"], "small print registration depends on UID, not RNG")


func test_top_edge_badge_moves_beside_the_actor_instead_of_under_the_hud(c: Check) -> void:
	for position: Vector2 in [Sim.ARENA.position + Vector2(12.0, 12.0),
			Vector2(Sim.ARENA.end.x - 12.0, Sim.ARENA.position.y + 12.0)]:
		var enemy := _enemy(&"grunt", &"splitter")
		enemy.pos = position
		var p := ThreatInk.profile(enemy, position + Vector2.DOWN, 0.0)
		var anchor: Vector2 = p["glyph_anchor"]
		c.ok(Sim.ARENA.grow(-ThreatInk.GLYPH_RADIUS).has_point(anchor),
				"edge badge remains inside the visible battle area")
		c.ok(absf(anchor.x - position.x) > enemy.radius,
				"badge beside the head does not cover the actor center")


func test_rift_progress_tracks_the_actual_warning_active_and_end_states(c: Check) -> void:
	var rift := TemporalRift.new()
	rift.pos = Vector2(480.0, 320.0)
	var start := ThreatInk.rift_profile(rift)
	c.ok(bool(start["visible"]) and bool(start["warning"]), "new rift shows its real warning")
	c.eq(start["phase"], &"sewn_seam", "warning is sewn shut instead of an active mouth")
	c.near(float(start["progress"]), 0.0, 0.0001, "warning begins at the 1.5 second boundary")
	rift.telegraph = TemporalRift.TELEGRAPH_TIME * 0.5
	var middle := ThreatInk.rift_profile(rift)
	c.near(float(middle["progress"]), 0.5, 0.0001, "warning follows simulation time")
	rift.telegraph = 0.0
	rift.active = TemporalRift.ACTIVE_TIME
	rift.tick = TemporalRift.TICK_TIME
	var active := ThreatInk.rift_profile(rift, 1.0)
	c.eq(active["phase"], &"open_seam", "actual activation opens the paper seam")
	c.ok(not bool(active["boundary_dashed"]) and bool(active["seam_open"]),
			"active and warning states differ in shape, not only color")
	c.eq(active["radius"], start["radius"], "activation does not alter the real radius")
	c.near(float(active["tick_remaining"]), TemporalRift.TICK_TIME, 0.0001,
			"display reads the real damage-tick timer")
	var reduced_a := ThreatInk.rift_profile(rift, 1.0, true)
	var reduced_b := ThreatInk.rift_profile(rift, 100.0, true)
	c.eq(reduced_a["wobble"], reduced_b["wobble"], "reduced active seam is static")
	rift.active = 0.0
	var ended := ThreatInk.rift_profile(rift)
	c.ok(not bool(ended["visible"]), "expired rift no longer pretends to damage")


func test_invalid_geometry_never_becomes_a_renderer_command(c: Check) -> void:
	var enemy := _enemy()
	enemy.radius = 0.0
	c.ok(not bool(ThreatInk.profile(enemy, Vector2.ZERO, 0.0)["valid"]), "zero-radius enemy is not drawn")
	enemy.radius = INF
	c.ok(not bool(ThreatInk.profile(enemy, Vector2.ZERO, 0.0)["valid"]), "infinite enemy radius is rejected")
	c.ok(not bool(ThreatInk.profile(null, Vector2.ZERO, 0.0)["valid"]), "missing enemy is safe")
	c.ok(ThreatInk.glyph_segments(&"volatile", 0.0).is_empty(), "zero badge size submits no lines")
	c.ok(ThreatInk.glyph_segments(&"volatile", NAN).is_empty(), "NaN badge size submits no lines")
	var rift := TemporalRift.new()
	for radius: float in [0.0, -1.0, INF, NAN]:
		rift.radius = radius
		c.ok(not bool(ThreatInk.rift_profile(rift)["visible"]), "invalid rift radius is invisible")
	rift.radius = 0.5
	c.ok(bool(ThreatInk.rift_profile(rift)["visible"]), "finite subpixel geometry stays represented")
	rift.pos = Vector2(INF, 0.0)
	c.ok(not bool(ThreatInk.rift_profile(rift)["visible"]), "nonfinite rift origin is rejected")
	for radius: float in [0.5, 52.0, 64.0, 80.0]:
		var boundary := ThreatInk.dashed_boundary_points(radius)
		c.ok(boundary.size() >= 2 and boundary.size() % 2 == 0, "potential boundary is a bounded line batch")
		for point in boundary:
			c.near(point.length(), radius, 0.0001, "every boundary endpoint lies on the real rule radius")
	c.ok(ThreatInk.dashed_boundary_points(NAN).is_empty(), "invalid boundary cannot populate the cache")


func test_boss_binding_uses_live_positions_without_becoming_a_damage_line(c: Check) -> void:
	var sim := Sim.new(48)
	sim.start_run()
	sim.boss_phase = 2
	var left := _enemy(&"paradox")
	var right := _enemy(&"paradox")
	left.pos = Vector2(220.0, 240.0)
	right.pos = Vector2(980.0, 480.0)
	sim.boss_shards.assign([left, right])
	var p := ThreatInk.boss_link_profile(sim, 0.0)
	c.ok(bool(p["visible"]) and not bool(p["dangerous"]), "dashed binding is a shared-identity cue")
	c.eq(p["ends"], PackedVector2Array([left.pos, right.pos]), "line follows the real collidable halves")
	c.eq(p["center"], (left.pos + right.pos) * 0.5, "staple remains between both live halves")
	var reduced_a := ThreatInk.boss_link_profile(sim, 0.0, true)
	var reduced_b := ThreatInk.boss_link_profile(sim, 10.0, true)
	c.eq(reduced_a["alpha"], reduced_b["alpha"], "reduced binding does not pulse")
	right.dead = true
	c.ok(not bool(ThreatInk.boss_link_profile(sim)["visible"]), "binding ends when one half dies")


func test_profiles_and_null_draw_guards_leave_simulation_and_rng_unchanged(c: Check) -> void:
	var sim := Sim.new(91)
	sim.start_run()
	var enemy := _enemy(&"warden", &"bulwark")
	var position := enemy.pos
	var hp := enemy.hp
	var radius := enemy.radius
	var state := sim.rng.state
	var time := sim.wave_time
	for i in 16:
		ThreatInk.profile(enemy, sim.player.pos, float(i) * 0.25)
		ThreatInk.draw_enemy_marks(null, enemy, sim.player.pos, float(i))
		ThreatInk.draw_rifts(null, sim)
		ThreatInk.draw_boss_link(null, sim, float(i))
	c.eq(enemy.pos, position, "presentation does not move an enemy")
	c.eq(enemy.hp, hp, "presentation does not alter health")
	c.eq(enemy.radius, radius, "presentation does not alter collision radius")
	c.eq(sim.rng.state, state, "presentation consumes no simulation entropy")
	c.eq(sim.wave_time, time, "presentation advances no simulation clock")
