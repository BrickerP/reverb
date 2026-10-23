extends RefCounted


func test_required_art_loads(c: Check) -> void:
	for key: StringName in [
		&"player", &"enemy_grunt", &"enemy_runner", &"weapon_pistol", &"weapon_shotgun", &"weapon_orb",
	]:
		var texture := PresentationAssets.texture(key)
		c.ok(texture != null, "presentation texture %s" % key)
		var visible := PresentationAssets.region(key)
		c.ok(visible.has_area(), "visible art bounds %s" % key)
		if texture != null:
			c.ok(maxi(texture.get_width(), texture.get_height()) <= 512,
					"presentation texture respects import size limit for %s" % key)
			var metadata: Dictionary = PresentationAssets.SOURCE_METADATA[key]
			var source_size: Vector2 = metadata["size"]
			var source_region: Rect2 = metadata["region"]
			var scale := texture.get_size() / source_size
			c.eq(visible, Rect2(source_region.position * scale, source_region.size * scale),
					"source bounds scale to imported texture for %s" % key)
			c.ok(Rect2(Vector2.ZERO, texture.get_size()).encloses(visible),
					"scaled region stays inside imported texture for %s" % key)
			c.near(visible.size.x / visible.size.y, source_region.size.x / source_region.size.y,
					0.001, "scaled region preserves source aspect for %s" % key)


func test_every_weapon_family_resolves_to_imported_art(c: Check) -> void:
	var expected := {
		&"sidearm": &"weapon_pistol",
		&"marksman": &"weapon_pistol",
		&"scatter": &"weapon_shotgun",
		&"arcane": &"weapon_orb",
	}
	for weapon: WeaponDef in Content.weapons().values():
		c.ok(expected.has(weapon.family), "%s has a presented family" % weapon.id)
		if not expected.has(weapon.family):
			continue
		var key := PresentationAssets.weapon_key(weapon)
		c.eq(key, expected[weapon.family], "%s uses its family art" % weapon.id)
		c.ok(PresentationAssets.texture(key) != null, "%s family art imports" % weapon.id)


func test_source_metadata_stays_inside_original_images(c: Check) -> void:
	c.eq(PresentationAssets.SOURCE_METADATA.size(), PresentationAssets.PATHS.size(),
			"every presentation asset has source metadata")
	for key: StringName in PresentationAssets.PATHS:
		c.ok(PresentationAssets.SOURCE_METADATA.has(key), "metadata exists for %s" % key)
		if not PresentationAssets.SOURCE_METADATA.has(key):
			continue
		var metadata: Dictionary = PresentationAssets.SOURCE_METADATA[key]
		var source_size: Vector2 = metadata["size"]
		var source_region: Rect2 = metadata["region"]
		c.ok(source_region.has_area(), "source region has area for %s" % key)
		c.ok(Rect2(Vector2.ZERO, source_size).encloses(source_region),
				"source region stays inside source image for %s" % key)


func test_missing_presentation_key_is_empty_and_cached(c: Check) -> void:
	var key: StringName = &"missing_presentation_asset"
	c.eq(PresentationAssets.texture(key), null, "missing texture is null")
	c.eq(PresentationAssets.region(key), Rect2(), "missing region is empty")
	c.ok(PresentationAssets._textures.has(key), "missing texture result is cached")
	c.ok(PresentationAssets._regions.has(key), "missing region result is cached")


func test_art_contain_preserves_source_aspect(c: Check) -> void:
	c.eq(ArenaPainter._contained_size(Vector2(4.0, 2.0), Vector2(10.0, 10.0)),
			Vector2(10.0, 5.0), "wide art fits by width")
	c.eq(ArenaPainter._contained_size(Vector2(2.0, 4.0), Vector2(10.0, 10.0)),
			Vector2(5.0, 10.0), "tall art fits by height")


func test_six_weapon_slots_surround_the_actor(c: Check) -> void:
	var slots: Array[Vector2] = []
	for i in 6:
		var slot := ArenaPainter._weapon_slot(i, 6)
		c.ok(not slots.has(slot), "weapon slot %d is distinct" % i)
		slots.append(slot)
	var min_x := slots[0].x
	var max_x := slots[0].x
	var min_y := slots[0].y
	var max_y := slots[0].y
	for slot in slots:
		min_x = minf(min_x, slot.x)
		max_x = maxf(max_x, slot.x)
		min_y = minf(min_y, slot.y)
		max_y = maxf(max_y, slot.y)
	c.ok(min_x < 0.0 and max_x > 0.0, "weapon slots span front and back")
	c.ok(min_y < 0.0 and max_y > 0.0, "weapon slots span both sides")


func test_presentation_updates_do_not_advance_simulation(c: Check) -> void:
	var sim := Sim.new(17)
	sim.start_run()
	var view := ArenaView.new()
	view.bind(sim)
	var rng_state := sim.rng.state
	var wave_time := sim.wave_time
	var player_pos := sim.player.pos
	var facing := sim.player.facing
	view._process(0.25)
	ArenaPainter._aim_direction(sim, sim.player.pos, sim.player.facing)
	ArenaPainter._motion_bob(sim.wave_time, sim.player.pos, 6.0, 1.6)
	c.eq(sim.rng.state, rng_state, "presentation leaves simulation RNG untouched")
	c.eq(sim.wave_time, wave_time, "presentation does not advance wave time")
	c.eq(sim.player.pos, player_pos, "presentation does not move the player")
	c.eq(sim.player.facing, facing, "presentation does not change facing")
	view.free()
