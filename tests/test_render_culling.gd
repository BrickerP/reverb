extends RefCounted


func _enemy(id: StringName, pos: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.def = Content.enemy(id)
	enemy.uid = 1
	enemy.pos = pos
	enemy.radius = enemy.def.radius
	enemy.max_hp = enemy.def.hp
	enemy.hp = enemy.max_hp
	enemy.attack_direction = Vector2.RIGHT
	return enemy


func _field(style: StringName, pos: Vector2) -> AttackField:
	var field := AttackField.new()
	field.weapon_id = &"mallet"
	field.style = style
	field.pos = pos
	field.origin = pos
	field.direction = Vector2.RIGHT
	field.life = 0.8
	field.radius = 60.0
	return field


func _corpse(pos: Vector2) -> Dictionary:
	var director := BattleDirector.new()
	var info := EnemyDeathInfo.new()
	info.enemy_id = &"runner"
	info.target_uid = 1
	info.pos = pos
	info.radius = 16.0
	info.hit_dir = Vector2.RIGHT
	director.enemy_died(info)
	return director.corpses[0]


func test_render_view_and_body_margins_are_camera_relative(c: Check) -> void:
	var sim := Sim.new(6100)
	sim.start_run()
	var camera := WorldArena.camera_rect(sim.player.pos)
	var view := ArenaPainter.render_view(sim)
	c.eq(view, camera.grow(9.0), "render view reserves the bounded camera shake margin")
	c.ok(ArenaPainter.body_in_view(view.get_center(), view), "onscreen body is retained")
	c.ok(ArenaPainter.body_in_view(Vector2(view.position.x - 99.0, view.get_center().y), view),
		"body art may overlap from outside the camera")
	c.ok(not ArenaPainter.body_in_view(Vector2(view.position.x - 101.0, view.get_center().y), view),
		"a body fully outside the conservative art margin is skipped")
	c.ok(ArenaPainter.body_in_view(Vector2(view.position.x - 130.0, view.get_center().y), view, 40.0),
		"explicit extra geometry can extend the body margin")
	c.ok(not ArenaPainter.body_in_view(Vector2(INF, 0.0), view), "nonfinite body never becomes drawable")
	sim.player.pos = WorldArena.BOUNDS.end - Vector2(20.0, 20.0)
	c.eq(ArenaPainter.render_view(sim), WorldArena.camera_rect(sim.player.pos).grow(9.0),
		"camera-relative culling follows scrolling to a world corner")


func test_offscreen_attack_warnings_and_active_windows_remain_visible(c: Check) -> void:
	var sim := Sim.new(6101)
	sim.start_run()
	var view := ArenaPainter.render_view(sim)
	var pos := Vector2(view.position.x - 120.0, view.get_center().y)
	for id: StringName in [&"runner", &"brute"]:
		var enemy := _enemy(id, pos)
		enemy.brain_state = &"warn"
		enemy.brain_time = EnemyBrain.RUNNER_WARN if id == &"runner" else EnemyBrain.BRUTE_WARN
		c.ok(not ArenaPainter.body_in_view(enemy.pos, view), "offscreen %s body can be skipped" % id)
		c.ok(ThreatInk.attack_bounds(enemy).has_area(), "%s warning has its own attack bounds" % id)
		c.ok(ThreatInk.attack_in_view(enemy, view), "%s warning crossing the camera is retained" % id)
		enemy.brain_state = &"dash" if id == &"runner" else &"slam"
		enemy.brain_time = EnemyBrain.RUNNER_DASH if id == &"runner" else EnemyBrain.BRUTE_SLAM
		c.ok(ThreatInk.attack_in_view(enemy, view), "%s actual damage window remains visible" % id)
		enemy.dead = true
		c.ok(not ThreatInk.attack_in_view(enemy, view), "%s retired source cannot keep an attack warning" % id)
		enemy.dead = false
		enemy.brain_state = &"recover"
		c.ok(not ThreatInk.attack_in_view(enemy, view), "%s recovery cannot leave a false active warning" % id)
		enemy.brain_state = &"warn"
		enemy.pos = view.position - Vector2(600.0, 600.0)
		c.ok(not ThreatInk.attack_in_view(enemy, view), "%s distant attack is fully outside the camera" % id)
	c.ok(not ThreatInk.attack_in_view(null, view), "missing attack source is safe")


func test_large_latent_blast_marks_survive_body_culling(c: Check) -> void:
	var sim := Sim.new(6102)
	sim.start_run()
	var view := ArenaPainter.render_view(sim)
	var bomber := _enemy(&"bomber", Vector2(view.position.x - 180.0, view.get_center().y))
	bomber.death_radius_override = 220.0
	c.ok(not ArenaPainter.body_in_view(bomber.pos, view), "latent blast owner body is offscreen")
	c.ok(ThreatInk.marks_in_view(bomber, view), "large actual death radius keeps its visible warning boundary")
	bomber.death_radius_override = 20.0
	c.ok(not ThreatInk.marks_in_view(bomber, view), "small offscreen latent mark can be skipped")
	bomber.pos = Vector2(NAN, 0.0)
	c.ok(not ThreatInk.marks_in_view(bomber, view), "invalid mark cannot leak nonfinite geometry")
	c.ok(not ThreatInk.marks_in_view(null, view), "missing mark source is safe")


func test_field_bounds_cover_each_real_primitive_beyond_its_owner(c: Check) -> void:
	var sim := Sim.new(6103)
	sim.start_run()
	var view := ArenaPainter.render_view(sim)
	var middle := view.get_center().y
	for style: StringName in [&"slam", &"ink", &"tape"]:
		var circle := _field(style, Vector2(view.position.x - 40.0, middle))
		c.ok(WeaponInk.field_in_view(circle, view), "%s circle overlaps despite an offscreen center" % style)
		c.ok(WeaponInk.field_bounds(circle).grow(0.1).has_point(circle.pos + Vector2(circle.radius, 0.0)),
			"%s bounds cover the actual radius" % style)
		circle.pos -= Vector2(300.0, 0.0)
		circle.origin = circle.pos
		c.ok(not WeaponInk.field_in_view(circle, view), "%s fully distant circle can be skipped" % style)
	var line := _field(&"line", Vector2(view.position.x - 400.0, middle))
	line.reach = 650.0
	line.width = 24.0
	c.ok(WeaponInk.field_in_view(line, view), "continuous line is retained when its owner is outside the camera")
	c.ok(WeaponInk.field_bounds(line).grow(0.1).has_point(line.origin + line.direction * line.reach),
		"line bounds cover its far endpoint")
	var reversed_line := _field(&"line", view.get_center())
	reversed_line.direction = Vector2.LEFT
	reversed_line.reach = 300.0
	reversed_line.width = 30.0
	c.ok(WeaponInk.field_bounds(reversed_line).grow(0.1).has_point(reversed_line.origin + Vector2(-300.0, 15.0)),
		"reversed line preserves both its endpoint and half-width")
	var orbit := _field(&"orbit", Vector2(view.position.x - 200.0, middle))
	orbit.orbit_radius = 220.0
	orbit.radius = 40.0
	orbit.pos = orbit.origin + Vector2(300.0, 0.0)
	c.ok(WeaponInk.field_in_view(orbit, view), "orbit retains both its path and its current satellite")
	var orbit_bounds := WeaponInk.field_bounds(orbit).grow(0.1)
	c.ok(orbit_bounds.has_point(orbit.origin - Vector2(orbit.orbit_radius, 0.0)), "orbit bounds cover its entire path")
	c.ok(orbit_bounds.has_point(orbit.pos + Vector2(orbit.radius, 0.0)), "orbit bounds cover satellite radius beyond its path")
	var cone := _field(&"cone_flash", Vector2(view.position.x - 200.0, middle))
	cone.reach = 260.0
	cone.spread = PI / 3.0
	c.ok(WeaponInk.field_in_view(cone, view), "cone flash can cross into view from an offscreen owner")
	c.ok(WeaponInk.field_bounds(cone).grow(0.1).has_point(cone.origin + cone.direction * cone.reach),
		"cone bounds include its forward arc extremum")
	cone.direction = Vector2(1.0, 1.0).normalized()
	cone.spread = PI * 0.5
	var cone_bounds := WeaponInk.field_bounds(cone).grow(0.1)
	c.ok(cone_bounds.has_point(cone.origin + Vector2.RIGHT * cone.reach), "rotated cone bounds keep the horizontal cardinal extremum")
	c.ok(cone_bounds.has_point(cone.origin + Vector2.DOWN * cone.reach), "rotated cone bounds keep the vertical cardinal extremum")
	var chain := _field(&"chain_flash", Vector2(view.position.x - 100.0, middle))
	chain.pos = view.get_center()
	c.ok(WeaponInk.field_in_view(chain, view), "chain flash keeps a visible segment from an offscreen source")
	c.ok(WeaponInk.field_bounds(chain).grow(0.1).has_point(chain.pos), "chain bounds cover the actual end target")
	for field in [line, orbit, cone, chain]:
		field.dead = true
		c.ok(not WeaponInk.field_in_view(field, view), "retired field submits no stale geometry")
	c.ok(not WeaponInk.field_in_view(null, view), "missing field is safe")
	line.dead = false
	line.origin = Vector2(INF, 0.0)
	c.ok(not WeaponInk.field_in_view(line, view), "nonfinite field origin never reaches drawing")
	var delayed := _field(&"slam", view.get_center())
	delayed.life = 0.0
	delayed.windup = 0.3
	c.ok(WeaponInk.field_in_view(delayed, view), "zero active lifetime does not hide a real delayed warning")


func test_corpse_bounds_cover_finite_terminal_travel(c: Check) -> void:
	var view := Rect2(640.0, 380.0, 1200.0, 600.0)
	var corpse := _corpse(Vector2(view.position.x - 110.0, view.get_center().y))
	c.ok(ArenaPainter.corpse_in_view(corpse, view), "terminal travel may bring an offscreen paper body into view")
	corpse["pos"] = Vector2(view.position.x - 400.0, view.get_center().y)
	c.ok(not ArenaPainter.corpse_in_view(corpse, view), "far corpse outside all finite travel is skipped")
	corpse["pos"] = Vector2(NAN, 0.0)
	c.ok(not ArenaPainter.corpse_in_view(corpse, view), "invalid corpse cannot reach a render transform")


func test_repeated_visibility_queries_do_not_mutate_authoritative_run(c: Check) -> void:
	var sim := Sim.new(6104)
	sim.start_run()
	var view := ArenaPainter.render_view(sim)
	var enemy := _enemy(&"runner", Vector2(view.position.x - 120.0, view.get_center().y))
	enemy.brain_state = &"warn"
	enemy.brain_time = EnemyBrain.RUNNER_WARN
	sim.enemies.append(enemy)
	sim.set("_next_uid", 2)
	var field := _field(&"orbit", sim.player.pos + Vector2(100.0, 0.0))
	field.orbit_radius = 90.0
	field.radius = 18.0
	field.actor_token = -1
	sim.attack_fields.append(field)
	var before := RunSnapshot.capture(sim)
	c.ok(not before.is_empty(), "culling oracle starts from a complete nonempty snapshot")
	var corpse := _corpse(sim.player.pos)
	for index in 100:
		var render_view := ArenaPainter.render_view(sim)
		ArenaPainter.body_in_view(enemy.pos, render_view)
		ArenaPainter.corpse_in_view(corpse, render_view)
		ThreatInk.attack_bounds(enemy)
		ThreatInk.attack_in_view(enemy, render_view)
		ThreatInk.marks_in_view(enemy, render_view)
		WeaponInk.field_bounds(field)
		WeaponInk.field_in_view(field, render_view)
	var after := RunSnapshot.capture(sim)
	c.ok(not after.is_empty(), "culling oracle still has a complete snapshot after queries")
	c.eq(after, before, "renderer culling never changes simulation, RNG, attack timers or saved actors")
