extends RefCounted


func test_copy_icon_uses_the_same_offline_bounds_as_world_art(c: Check) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://assets/presentation/surfaces/manifest.json"))
	var expected: Array = []
	for asset: Dictionary in manifest["assets"]:
		if asset["file"] == "recording_cartridge.png":
			expected = asset["bounds_ltrb"]
	var metadata: Dictionary = PresentationAssets.SOURCE_METADATA[&"recording_cartridge"]
	var source: Rect2 = metadata["region"]
	c.eq([int(source.position.x), int(source.position.y), int(source.end.x), int(source.end.y)],
			expected, "copy thumbnail derives its crop from the measured source alpha")
	var icon := UiTheme.cartridge_icon()
	var atlas := icon.texture as AtlasTexture
	c.eq(atlas.region, PresentationAssets.region(&"recording_cartridge"),
			"UI has no second manually maintained crop")
	icon.free()


func test_actor_frames_remain_inside_the_imported_texture(c: Check) -> void:
	for key: StringName in PresentationAssets.PATHS:
		var count := PresentationAssets.frame_count(key)
		var texture := PresentationAssets.texture(key)
		var first := PresentationAssets.region(key)
		c.ok(count >= 1 and first.has_area(), "every shipped identity has a visible first pose")
		for index in count:
			var frame := PresentationAssets.frame_region(key, index)
			c.eq(frame.size, first.size, "poses keep one stable crop and scale")
			c.ok(Rect2(Vector2.ZERO, texture.get_size()).encloses(frame),
					"source frame remains inside its imported atlas")
			if index > 0:
				c.ok(frame.position.x > first.position.x, "animation selects distinct source pixels")


func test_frame_selection_handles_missing_and_out_of_range_inputs(c: Check) -> void:
	var key: StringName = &"character_looper_front"
	var count := PresentationAssets.frame_count(key)
	c.eq(count, 4, "protagonist includes idle, two steps and a hurt drawing")
	c.eq(PresentationAssets.frame_region(key, -9), PresentationAssets.region(key),
			"negative frame cannot sample the preceding atlas cell")
	c.eq(PresentationAssets.frame_region(key, 999), PresentationAssets.frame_region(key, count - 1),
			"late events cannot sample beyond the atlas")
	c.eq(PresentationAssets.frame_count(&"not_a_shipped_identity"), 0, "missing art has no fake animation")
	c.eq(PresentationAssets.frame_region(&"not_a_shipped_identity", 4), Rect2(),
			"missing identity has an empty source region")
	c.eq(PresentationAssets.frame_count(&"weapon_pistol"), 1, "equipment stays independently mountable")
	c.eq(PresentationAssets.frame_region(&"weapon_pistol", 99), PresentationAssets.region(&"weapon_pistol"),
			"a static icon cannot advance into empty pixels")
