extends RefCounted


func test_all_world_identity_keys_load(c: Check) -> void:
	for enemy: EnemyDef in Content.enemies():
		var enemy_key := PresentationAssets.enemy_key(enemy)
		c.eq(enemy_key, StringName("enemy_%s" % enemy.id), "%s keeps its enemy identity" % enemy.id)
		c.ok(PresentationAssets.texture(enemy_key) != null, "%s enemy art loads" % enemy.id)
		c.ok(PresentationAssets.region(enemy_key).has_area(), "%s enemy bounds load" % enemy.id)
	for weapon: WeaponDef in Content.weapons().values():
		var weapon_key := PresentationAssets.weapon_key(weapon)
		c.eq(weapon_key, StringName("weapon_%s" % weapon.id), "%s keeps its weapon identity" % weapon.id)
		c.ok(PresentationAssets.texture(weapon_key) != null, "%s weapon art loads" % weapon.id)
		c.ok(PresentationAssets.region(weapon_key).has_area(), "%s weapon bounds load" % weapon.id)
	for id: StringName in [&"looper", &"solo", &"mirror", &"conductor"]:
		for back in [false, true]:
			var key := PresentationAssets.character_key(id, back)
			var suffix := "back" if back else "front"
			c.eq(key, StringName("character_%s_%s" % [id, suffix]), "%s %s identity" % [id, suffix])
			c.ok(PresentationAssets.texture(key) != null, "%s %s art loads" % [id, suffix])
			c.ok(PresentationAssets.region(key).has_area(), "%s %s bounds load" % [id, suffix])


func test_art_fits_bounds_and_keeps_feet_anchored(c: Check) -> void:
	var bounds := Vector2(44.0, 52.0)
	var fitted := ArenaPainter._contained_size(Vector2(500.0, 1000.0), bounds)
	c.ok(fitted.x <= bounds.x and fitted.y <= bounds.y, "contained character stays inside bounds")
	c.near(fitted.x / fitted.y, 0.5, 0.001, "contained character keeps source aspect")
	var foot := Vector2(320.0, 240.0)
	var center := ArenaPainter._foot_center(foot, fitted)
	c.near(center.y + fitted.y * 0.5, foot.y, 0.001, "actual fitted height keeps feet fixed")
	c.near(center.x, foot.x, 0.001, "foot anchor stays horizontally centered")


func test_direction_selects_character_side(c: Check) -> void:
	c.ok(ArenaPainter._uses_back_art(Vector2.UP), "moving up selects back art")
	c.ok(not ArenaPainter._uses_back_art(Vector2.DOWN), "moving down selects front art")
	c.ok(ArenaPainter._horizontal_flip(Vector2.LEFT), "moving left flips the authored pose")
	c.ok(not ArenaPainter._horizontal_flip(Vector2.RIGHT), "moving right keeps the authored pose")
	c.eq(PresentationAssets.character_key(&"mirror", ArenaPainter._uses_back_art(Vector2.UP)),
			&"character_mirror_back", "direction resolves the mirror back identity")


func test_warden_authored_forward_tracks_gameplay_facing(c: Check) -> void:
	var authored := Vector2.from_angle(ArenaPainter.WARDEN_AUTHORED_FORWARD)
	for facing: Vector2 in [
		Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
		Vector2(1.0, 1.0).normalized(), Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(), Vector2(1.0, -1.0).normalized(),
	]:
		var transformed := authored.rotated(ArenaPainter._warden_rotation(facing))
		c.near(transformed.distance_to(facing), 0.0, 0.001,
				"warden authored front aligns with gameplay facing %s" % facing)


func test_special_shapes_have_calibrated_boxes(c: Check) -> void:
	var longbow := ArenaPainter._weapon_size(&"weapon_longbow")
	c.ok(longbow.y > longbow.x, "longbow keeps a tall mounted shape")
	c.ok(ArenaPainter._enemy_bounds(&"silencer").y >= 50.0,
			"silencer reserves height for a readable shredder body")
	c.ok(ArenaPainter._character_bounds(&"mirror").y > ArenaPainter.PLAYER_ART_SIZE.y,
			"misprinted mirror keeps its distinct paper silhouette")
	c.ok(ArenaPainter._character_bounds(&"conductor").x > ArenaPainter.PLAYER_ART_SIZE.x,
			"conductor paper-feed equipment receives extra width")
	var slot := Rect2(0.0, 0.0, Hud.SLOT_W, Hud.SLOT_H)
	var thumb := Hud._weapon_thumbnail_rect(slot, Vector2(654.0, 964.0))
	c.ok(slot.encloses(thumb), "tall HUD weapon thumbnail stays within its slot")
	c.ok(thumb.size.y > thumb.size.x, "HUD preserves the longbow silhouette")


func test_world_presentation_does_not_mutate_simulation(c: Check) -> void:
	var sim := Sim.new(29)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim, &"mirror")
	var rng_state := sim.rng.state
	var wave_time := sim.wave_time
	var player_pos := sim.player.pos
	var player_facing := sim.player.facing
	view._process(0.2)
	ArenaPainter._aim_direction(sim, sim.player.pos, sim.player.facing)
	ArenaPainter._contained_size(Vector2(500.0, 1000.0), ArenaPainter._character_bounds(&"mirror"))
	c.eq(view.character_id, &"mirror", "view retains presentation-only character identity")
	c.eq(sim.rng.state, rng_state, "world presentation leaves simulation RNG unchanged")
	c.eq(sim.wave_time, wave_time, "world presentation does not advance simulation")
	c.eq(sim.player.pos, player_pos, "world presentation does not move player")
	c.eq(sim.player.facing, player_facing, "world presentation does not change facing")
	view.free()
