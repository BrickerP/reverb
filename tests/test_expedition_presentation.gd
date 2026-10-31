extends RefCounted


func _boss(id: StringName, pos: Vector2 = Vector2(400, 280)) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(id)
	enemy.uid = 1
	enemy.pos = pos
	enemy.radius = enemy.def.radius
	enemy.hp = enemy.def.hp
	enemy.max_hp = enemy.hp
	enemy.brain_state = &"warn"
	enemy.brain_time = 0.5
	enemy.attack_target = Vector2(600, 350)
	enemy.attack_direction = Vector2.RIGHT
	return enemy


func test_every_support_has_real_art_and_friendly_health_profile(c: Check) -> void:
	var sim := Sim.new(490)
	for kind: StringName in SupportSystem.PROFILES:
		sim.support_units.clear()
		c.ok(SupportSystem.spawn(sim, kind, Vector2(500, 320)), "%s spawns" % kind)
		var unit: Dictionary = sim.support_units[0]
		unit["hp"] = float(unit["max_hp"]) * 0.5
		var p := ExpeditionInk.support_profile(unit, 1.0)
		c.ok(bool(p["visible"]), "%s is visible alive" % kind)
		c.near(float(p["hp_ratio"]), 0.5, 0.0001, "%s health follows simulation" % kind)
		c.ok(PresentationAssets.support_texture(kind) != null, "%s real texture loads" % kind)
		c.ok(PresentationAssets.support_region(kind).has_area(), "%s selects visible pixels" % kind)
		c.eq(p["companion"], SupportSystem.COMPANIONS.has(kind), "%s friendly companion classification" % kind)
		if SupportSystem.COMPANIONS.has(kind):
			var boss_id := StringName(String(kind).trim_prefix("recruited_"))
			c.eq(p["key"], PresentationAssets.enemy_key(Content.enemy(boss_id)), "recruits preserve boss identity")
		unit["hp"] = 0.0
		c.ok(not bool(ExpeditionInk.support_profile(unit)["visible"]), "destroyed unit leaves no living art")
	c.ok(PresentationAssets.support_key(&"hound", true) != PresentationAssets.support_key(&"hound"), "hound bite uses authored action pose")
	c.ok(PresentationAssets.support_key(&"turret", true) != PresentationAssets.support_key(&"turret"), "turret fire uses authored action pose")
	c.ok(PresentationAssets.support_key(&"paper_tree", true) != PresentationAssets.support_key(&"paper_tree"), "tree growth follows consumed charges")
	c.eq(PresentationAssets.support_texture(&"unknown"), null, "unknown support never borrows another body")


func test_boss_warnings_match_locked_hit_primitives(c: Check) -> void:
	var foreman := _boss(&"foreman")
	var p := ExpeditionInk.boss_warning_profile(foreman)
	c.eq(p["kind"], &"press", "foreman shows press primitive")
	c.eq(p["center"], foreman.attack_target, "press remains at locked target")
	c.eq(p["radius"], 112.0, "press radius equals actual hit circle")
	var collector := _boss(&"collector", Vector2(300, 200))
	p = ExpeditionInk.boss_warning_profile(collector)
	c.eq(p["kind"], &"dash", "collector shows charge corridor")
	c.eq(p["radius"], 34.0, "charge warning uses physical ground half-width")
	c.near((p["end"] as Vector2).distance_to(collector.pos), 377.0, 0.001, "warning covers full locked travel")
	collector.brain_state = &"dash"
	collector.brain_time = 0.2
	p = ExpeditionInk.boss_warning_profile(collector)
	c.near(p["reach"], 116.0, 0.001, "active warning shrinks to remaining physical travel")
	var paradox := _boss(&"paradox")
	p = ExpeditionInk.boss_warning_profile(paradox)
	c.eq(p["kind"], &"cross", "paradox shows cross rather than cone")
	c.eq(p["regions"].size(), 2, "cross has two physical rectangles")
	c.eq(p["regions"][0].size, Vector2(410, 68), "horizontal cross uses actual extent and width")
	c.eq(p["regions"][1].size, Vector2(68, 410), "vertical cross uses actual extent and width")
	for boss: EnemyState in [foreman, collector, paradox]:
		boss.brain_state = &"recover"
		c.ok(not bool(ExpeditionInk.boss_warning_profile(boss)["visible"]), "recovery has no stale damage warning")
		boss.brain_state = &"defeated"
		c.ok(not bool(ExpeditionInk.boss_warning_profile(boss)["visible"]), "negotiation never displays an active attack")
		c.eq(ArenaPainter.expedition_boss_art(boss, 1, 0, 0.0)["frame"], 6, "negotiation uses authored alive defeated pose")
	c.ok(not bool(ExpeditionInk.boss_warning_profile(null)["visible"]), "missing boss has no geometry")


func test_interactions_share_real_availability_and_hud_safe_labels(c: Check) -> void:
	var sim := Sim.new(490)
	sim.player.pos = Vector2(60, 100)
	var view := WorldArena.camera_rect(sim.player.pos)
	var item := {"id": &"test_machine", "kind": &"recycler", "pos": sim.player.pos,
		"range": 112.0, "cost": 8, "warning": 0.0, "active": 0.0, "cooldown": 0.0,
		"used": false, "direction": Vector2.RIGHT}
	sim.interactables.append(item)
	var p := ExpeditionInk.target_profile(sim, item, view, Expedition.interaction(sim))
	c.ok(bool(p["selected"]) and bool(p["available"]), "near actual selected machine shows interaction")
	c.ok(view.encloses(p["label"]), "edge marker stays inside fixed world viewport and outside HUD")
	sim.player.materials = 0
	p = ExpeditionInk.target_profile(sim, item, view, Expedition.interaction(sim))
	c.ok(not bool(p["available"]), "cost blocks visible availability")
	item["used"] = true
	c.ok(not bool(ExpeditionInk.target_profile(sim, item, view)["visible"]), "completed objectives leave no actionable marker")


func test_presentation_is_read_only_culled_reduced_and_bounded(c: Check) -> void:
	var sim := Sim.new(490)
	sim.start_run()
	sim.enemies.clear()
	SupportSystem.spawn(sim, &"hound", sim.player.pos)
	SupportSystem.spawn(sim, &"turret", sim.player.pos + Vector2(100, 0))
	var boss := _boss(&"paradox", WorldArena.camera_rect(sim.player.pos).position - Vector2(190, 0))
	boss.attack_target = sim.player.pos
	sim.enemies.append(boss)
	var before_units := sim.support_units.duplicate(true)
	var before_targets := sim.interactables.duplicate(true)
	var before_rng := sim.rng.state
	var before_clock := sim.wave_time
	var full := ExpeditionInk.snapshot(sim, 1.0)
	var reduced := ExpeditionInk.snapshot(sim, 1.0, true)
	c.eq(full["warnings"].size(), 1, "offscreen source retains hazard crossing camera")
	c.eq(reduced["warnings"], full["warnings"], "reduced effects preserve all exact hazard information")
	c.eq(reduced["supports"].size(), full["supports"].size(), "reduced effects preserve real support bodies")
	c.eq(sim.support_units, before_units, "render preparation cannot heal, consume or move support")
	c.eq(sim.interactables, before_targets, "render preparation cannot activate or use targets")
	c.eq(sim.rng.state, before_rng, "render preparation leaves RNG unchanged")
	c.eq(sim.wave_time, before_clock, "render preparation leaves simulation time unchanged")
	for index in 50:
		var unit: Dictionary = before_units[0].duplicate(true)
		unit["uid"] = 100 + index
		sim.support_units.append(unit)
		var item := {"id": StringName("test%d" % index), "kind": &"part", "pos": sim.player.pos,
			"used": false, "cost": 0, "cooldown": 0.0}
		sim.interactables.append(item)
	var capped := ExpeditionInk.snapshot(sim, 1.0)
	c.ok(capped["supports"].size() <= SupportSystem.MAX_UNITS, "hostile input cannot exceed support draw budget")
	c.ok(capped["targets"].size() <= ExpeditionInk.MAX_TARGETS, "hostile input cannot exceed marker draw budget")
	ExpeditionInk.draw(null, sim)
	c.eq(ExpeditionInk.draw_stats(), {"supports": 0, "targets": 0, "warnings": 0}, "unbound renderer clears stale stats")


func test_skill_body_sequences_are_distinct_finite_and_settle(c: Check) -> void:
	var shapes: Array[Dictionary] = []
	for role: StringName in Content.characters():
		var p := InteractionInk.skill_pose(role, 0.44)
		c.ok(bool(p["active"]), "%s has a finite paper body action" % role)
		c.ok(not shapes.has({"scale": p["scale"], "lean": p["lean"]}), "%s folds its own body rather than repeating a head card" % role)
		shapes.append({"scale": p["scale"], "lean": p["lean"]})
		for progress: float in [0.0, 0.2, 0.5, 0.9, 1.0]:
			var pose := InteractionInk.skill_pose(role, progress)
			c.ok((pose["scale"] as Vector2).is_finite() and float(pose["lean"]) == float(pose["lean"]), "body geometry stays finite")
			c.eq(pose["offset"], Vector2.ZERO, "paper articulation leaves the planted collision foot unchanged")
		var reduced := InteractionInk.skill_pose(role, 0.44, true)
		c.eq(reduced["action"], role, "Reduced retains the committed ability identity")
		c.eq(reduced["stage"], &"contact", "Reduced retains essential contact")
		c.eq(reduced["scale"], Vector2.ONE, "Reduced keeps a steady readable body")
		var settled := InteractionInk.skill_pose(role, 1.0)
		c.ok(not bool(settled["active"]), "finished activation leaves no permanent pose")
		c.eq(settled["scale"], Vector2.ONE, "finite sequence restores the body")
		c.eq(settled["lean"], 0.0, "finite sequence restores the lean")
	c.eq(shapes.size(), 6, "all six real character skills have body feedback")
	for progress: float in [NAN, INF, -1.0]:
		c.ok(not bool(InteractionInk.skill_pose(&"solo", progress)["active"]), "invalid clocks cannot start a pose")


func test_foreman_visible_slices_stay_inside_authored_idle_frame(c: Check) -> void:
	var regions := PresentationAssets.frame_visible_regions(&"enemy_foreman", 0)
	c.eq(regions.size(), 2, "idle Foreman excludes foreign component with two source-only slices")
	var frame := PresentationAssets.frame_region(&"enemy_foreman", 0)
	for rect: Rect2 in regions:
		c.ok(frame.encloses(rect), "every source slice stays inside its own authored frame")
	c.ok(not regions[0].intersects(regions[1]), "source slices never double draw body pixels")
	c.eq(PresentationAssets.frame_visible_regions(&"enemy_foreman", 1), [PresentationAssets.frame_region(&"enemy_foreman", 1)], "windup keeps its full authored pose")


func test_native_compact_label_clamp_uses_actual_camera_without_sim_mutation(c: Check) -> void:
	var sim := Sim.new(891)
	sim.start_run()
	sim.player.pos = Vector2(1240, 680)
	var display := WorldArena.display_viewport(Vector2(960, 540))
	var camera := WorldArena.camera_rect(sim.player.pos, display)
	sim.interactables = [{"id": &"compact_part", "kind": &"part", "pos": sim.player.pos - Vector2(0, 104),
		"range": 112.0, "cost": 0, "warning": 0.0, "active": 0.0, "cooldown": 0.0,
		"used": false, "direction": Vector2.RIGHT}]
	var before := RunSnapshot.capture(sim)
	var frame := ExpeditionInk.snapshot(sim, 0.0, false, display)
	c.eq(frame["targets"].size(), 1, "real nearby mission target is retained at native 960")
	c.ok(camera.encloses(frame["targets"][0]["label"]), "full label remains inside the actual 880x372 camera")
	c.eq(RunSnapshot.capture(sim), before, "viewport-specific rendering does not mutate simulation state")
