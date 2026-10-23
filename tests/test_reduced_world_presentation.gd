extends RefCounted


func test_arena_floor_texture_matches_gameplay_rect(c: Check) -> void:
	var texture := ArenaPainter.arena_floor_texture()
	c.ok(texture != null, "arena floor texture imports")
	if texture == null:
		return
	var texture_aspect := texture.get_size().x / texture.get_size().y
	var arena_aspect := Sim.ARENA.size.x / Sim.ARENA.size.y
	c.near(texture_aspect, arena_aspect, 0.001, "floor maps to exact arena aspect without geometry change")


func test_reduced_victory_removes_fullscreen_flash(c: Check) -> void:
	c.ok(ArenaPainter.victory_flash_alpha(0.0, false) > 0.0, "standard victory retains brief flash")
	c.eq(ArenaPainter.victory_flash_alpha(0.0, true), 0.0, "reduced victory has no fullscreen flash")
	c.eq(ArenaPainter.victory_flash_alpha(0.5, true), 0.0, "reduced flash stays disabled")


func test_reduced_victory_and_hurt_suppress_shake_and_particles(c: Check) -> void:
	var sim := Sim.new(83)
	sim.start_run()
	var reduced := ArenaView.new()
	reduced.bind(sim)
	reduced.reduced_effects = true
	reduced.play_victory_beat(sim)
	c.eq(reduced._shake, 0.0, "reduced victory does not add shake")
	c.ok(reduced._sparks.size() <= 11, "reduced victory uses restrained particle count")
	reduced._on_hurt(2.0)
	c.eq(reduced._shake, 0.0, "legacy hurt wrapper respects reduced shake")
	var standard := ArenaView.new()
	standard.bind(sim)
	standard.play_victory_beat(sim)
	c.ok(standard._shake > 0.0, "standard victory retains shake")
	c.ok(standard._sparks.size() > reduced._sparks.size(), "standard victory remains more expressive")
	standard._on_hurt(2.0)
	c.ok(standard._shake > 0.0, "standard legacy hurt retains shake")
	reduced.free()
	standard.free()


func test_reduced_motion_scale_is_restrained_but_nonzero(c: Check) -> void:
	c.ok(ArenaPainter.REDUCED_MOTION_SCALE > 0.0, "reduced actors retain readable life")
	c.ok(ArenaPainter.REDUCED_MOTION_SCALE <= 0.35, "reduced gait is materially restrained")


func test_reduced_projectiles_remove_only_trails(c: Check) -> void:
	c.ok(ArenaPainter.projectile_trails_enabled(false, 1), "standard direct projectiles keep trails")
	c.ok(ArenaPainter.projectile_trails_enabled(false, ArenaPainter.TRAIL_LIMIT),
			"standard batched projectiles keep trails through the trail limit")
	c.ok(not ArenaPainter.projectile_trails_enabled(false, ArenaPainter.TRAIL_LIMIT + 1),
			"existing overload policy still drops trails above its limit")
	c.ok(not ArenaPainter.projectile_trails_enabled(true, 1),
			"reduced direct projectiles remove decorative trails")
	c.ok(not ArenaPainter.projectile_trails_enabled(true, ArenaPainter.TRAIL_LIMIT),
			"reduced batched projectiles remove decorative trails")


func test_midcombat_reduced_toggle_clears_decorative_motion_only(c: Check) -> void:
	var sim := Sim.new(89)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var shot := ShotInfo.new()
	shot.weapon_id = &"pistol"
	shot.origin = sim.player.pos
	shot.direction = Vector2.RIGHT
	view._on_shot_info(shot)
	var damage := DamageInfo.new()
	damage.pos = sim.player.pos + Vector2(20.0, 0.0)
	view._on_damage_info(damage)
	var blast := ExplosionInfo.new()
	blast.pos = sim.player.pos + Vector2(30.0, 0.0)
	blast.radius = 24.0
	view._on_explosion_info(blast)
	var hurt := PlayerHurtInfo.new()
	hurt.pos = sim.player.pos
	hurt.direction = Vector2.LEFT
	view._on_hurt_info(hurt)
	c.ok(view.feedback_counts()["muzzles"] > 0 and view.feedback_counts()["sparks"] > 0,
			"normal combat has decorative transient motion")
	view.position = Vector2(4.0, 3.0)
	view.set_reduced_effects(true)
	c.ok(view.reduced_effects, "canonical setter enables reduced effects")
	c.eq(view._shake, 0.0, "midcombat toggle clears shake trauma")
	c.eq(view.position, Vector2.ZERO, "midcombat toggle clears shake offset")
	c.eq(view.feedback_counts()["muzzles"], 0, "midcombat toggle clears stale muzzle and recoil")
	c.eq(view.feedback_counts()["sparks"], 0, "midcombat toggle clears decorative sparks")
	c.eq(view.recoil_amount(), 0.0, "midcombat toggle returns mounted weapons to rest")
	c.eq(view.feedback_counts()["hits"], 1, "hit readability survives reduced toggle")
	c.eq(view.feedback_counts()["explosions"], 1, "explosion readability survives reduced toggle")
	c.eq(view.feedback_counts()["hurts"], 1, "hurt readability survives reduced toggle")
	view.free()
