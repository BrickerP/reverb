extends RefCounted


func test_required_art_loads(c: Check) -> void:
	for key: StringName in PresentationAssets.PATHS:
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
			var normalized := Rect2(visible.position / texture.get_size(), visible.size / texture.get_size())
			var expected := Rect2(source_region.position / source_size, source_region.size / source_size)
			c.near(normalized.position.x, expected.position.x, 0.002,
					"normalized source x stays stable for %s" % key)
			c.near(normalized.position.y, expected.position.y, 0.002,
					"normalized source y stays stable for %s" % key)
			c.near(normalized.size.x, expected.size.x, 0.002,
					"normalized source width stays stable for %s" % key)
			c.near(normalized.size.y, expected.size.y, 0.002,
					"normalized source height stays stable for %s" % key)


func test_every_weapon_id_resolves_to_distinct_imported_art(c: Check) -> void:
	c.eq(PresentationAssets.WEAPON_KEYS.size(), 35, "all base, final and support weapons have art")
	c.eq(PresentationAssets.WEAPON_KEYS.size(), Content.weapons().size(),
			"weapon catalog has no missing or extra IDs")
	var keys: Array[StringName] = []
	var identities: Array[String] = []
	for weapon: WeaponDef in Content.weapons().values():
		c.ok(PresentationAssets.WEAPON_KEYS.has(weapon.id), "%s has explicit weapon art" % weapon.id)
		var key := PresentationAssets.weapon_key(weapon)
		c.eq(key, StringName("weapon_%s" % weapon.id), "%s uses its ID art" % weapon.id)
		c.ok(not keys.has(key), "%s weapon key is unique" % weapon.id)
		keys.append(key)
		var path := String(PresentationAssets.PATHS.get(key, ""))
		var region := PresentationAssets.region(key)
		var identity := "%s:%s" % [path, PresentationAssets.SOURCE_METADATA[key]["region"]]
		c.ok(not path.is_empty() and region.has_area(), "%s has real imported weapon art" % weapon.id)
		c.ok(not identities.has(identity), "%s has a unique file and atlas-region identity" % weapon.id)
		identities.append(identity)
		c.ok(PresentationAssets.texture(key) != null, "%s weapon art imports" % weapon.id)


func test_every_item_id_resolves_to_distinct_imported_art(c: Check) -> void:
	c.eq(PresentationAssets.ITEM_KEYS.size(), Content.items().size(),
			"item catalog has no missing or extra IDs")
	var keys: Array[StringName] = []
	var paths: Array[String] = []
	for item: ItemDef in Content.items().values():
		c.ok(PresentationAssets.ITEM_KEYS.has(item.id), "%s has explicit item art" % item.id)
		var key := PresentationAssets.item_key(item)
		c.eq(key, StringName("item_%s" % item.id), "%s uses its ID art" % item.id)
		c.ok(not keys.has(key), "%s item key is unique" % item.id)
		keys.append(key)
		var path := String(PresentationAssets.PATHS.get(key, ""))
		c.ok(not path.is_empty() and not paths.has(path), "%s item file is unique" % item.id)
		paths.append(path)
		c.ok(PresentationAssets.texture(key) != null, "%s item art imports" % item.id)


func test_every_enemy_id_resolves_to_distinct_imported_art(c: Check) -> void:
	c.eq(PresentationAssets.ENEMY_KEYS.size(), Content.enemies().size(),
			"enemy catalog has no missing or extra IDs")
	var keys: Array[StringName] = []
	var paths: Array[String] = []
	for enemy: EnemyDef in Content.enemies():
		c.ok(PresentationAssets.ENEMY_KEYS.has(enemy.id), "%s has explicit enemy art" % enemy.id)
		var key := PresentationAssets.enemy_key(enemy)
		c.eq(key, StringName("enemy_%s" % enemy.id), "%s uses its ID art" % enemy.id)
		c.ok(not keys.has(key), "%s enemy key is unique" % enemy.id)
		keys.append(key)
		var path := String(PresentationAssets.PATHS.get(key, ""))
		c.ok(not path.is_empty() and not paths.has(path), "%s enemy file is unique" % enemy.id)
		paths.append(path)
		c.ok(PresentationAssets.texture(key) != null, "%s enemy art imports" % enemy.id)


func test_every_character_has_distinct_front_and_back_art(c: Check) -> void:
	c.eq(PresentationAssets.CHARACTER_FRONT_KEYS.size(), Content.characters().size(),
			"character front catalog has no missing or extra IDs")
	c.eq(PresentationAssets.CHARACTER_BACK_KEYS.size(), Content.characters().size(),
			"character back catalog has no missing or extra IDs")
	var paths: Array[String] = []
	for id: StringName in Content.characters():
		for direction in 2:
			var back := direction == 1
			var expected := StringName("character_%s_%s" % [id, "back" if back else "front"])
			var key := PresentationAssets.character_key(id, back)
			c.eq(key, expected, "%s has explicit %s art" % [id, "back" if back else "front"])
			var path := String(PresentationAssets.PATHS.get(key, ""))
			c.ok(not path.is_empty() and not paths.has(path), "%s direction file is unique" % key)
			paths.append(path)
			c.ok(PresentationAssets.texture(key) != null, "%s character art imports" % key)


func test_unknown_definitions_use_documented_safe_fallbacks(c: Check) -> void:
	var weapon := WeaponDef.new()
	weapon.id = &"future_weapon"
	var item := ItemDef.new()
	item.id = &"future_item"
	var enemy := EnemyDef.new()
	enemy.id = &"future_enemy"
	c.eq(PresentationAssets.weapon_key(weapon), &"weapon_pistol", "unknown weapon fallback")
	c.eq(PresentationAssets.item_key(item), &"item_iron_heart", "unknown item fallback")
	c.eq(PresentationAssets.enemy_key(enemy), &"enemy_grunt", "unknown enemy fallback")
	c.eq(PresentationAssets.character_key(&"future_character"), &"character_looper_front",
			"unknown character front fallback")
	c.eq(PresentationAssets.character_key(&"future_character", true), &"character_looper_back",
			"unknown character back fallback")


func test_source_metadata_stays_inside_original_images(c: Check) -> void:
	c.eq(PresentationAssets.SOURCE_METADATA.size(), PresentationAssets.PATHS.size(),
			"every presentation asset has source metadata")
	c.eq(PresentationAssets.PATHS.size(), 78, "catalog includes expedition bosses, arsenal, support poses and mission letter")
	var identities: Array[String] = []
	for key: StringName in PresentationAssets.PATHS:
		c.ok(PresentationAssets.SOURCE_METADATA.has(key), "metadata exists for %s" % key)
		if not PresentationAssets.SOURCE_METADATA.has(key):
			continue
		var metadata: Dictionary = PresentationAssets.SOURCE_METADATA[key]
		var source_size: Vector2 = metadata["size"]
		var source_region: Rect2 = metadata["region"]
		var identity := "%s:%s" % [PresentationAssets.PATHS[key], source_region]
		c.ok(not identities.has(identity), "%s has a distinct static source region" % key)
		identities.append(identity)
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
	BattleDirector.gait_profile(0.75, 1.0, true)
	c.eq(sim.rng.state, rng_state, "presentation leaves simulation RNG untouched")
	c.eq(sim.wave_time, wave_time, "presentation does not advance wave time")
	c.eq(sim.player.pos, player_pos, "presentation does not move the player")
	c.eq(sim.player.facing, facing, "presentation does not change facing")
	view.free()
