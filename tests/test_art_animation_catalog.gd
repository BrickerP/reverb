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
	c.eq([source.position.x, source.position.y, source.end.x, source.end.y],
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
		var seen: Array[Rect2] = []
		c.ok(count >= 1 and first.has_area(), "every shipped identity has a visible first pose")
		for index in count:
			var frame := PresentationAssets.frame_region(key, index)
			c.eq(frame.size, first.size, "poses keep one stable crop and scale")
			c.ok(Rect2(Vector2.ZERO, texture.get_size()).encloses(frame),
					"source frame remains inside its imported atlas")
			c.ok(not seen.has(frame), "each atlas pose selects distinct source pixels in both dimensions")
			seen.append(frame)
			var pivot := PresentationAssets.frame_pivot(key, index)
			c.ok(pivot.is_finite() and pivot.x >= 0.0 and pivot.y >= 0.0,
					"every pose has a finite measured local anchor")
			c.ok(pivot.x <= frame.size.x and pivot.y <= frame.size.y,
					"pose feet remain inside the shared source crop")


func test_two_row_atlas_preserves_idle_icon_and_measured_feet(c: Check) -> void:
	var key: StringName = &"character_looper_front"
	var texture := PresentationAssets.texture(key)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/presentation/manifest.json"))
	var asset: Dictionary = {}
	for item: Dictionary in manifest["assets"]:
		if item["file"] == "player.png":
			asset = item
	c.eq(int(asset["rows"]), 2, "actor uses a real second atlas row")
	var source_size := Vector2(float(asset["size"][0]), float(asset["size"][1]))
	var factor := texture.get_size() / source_size
	for frame in 8:
		var region := PresentationAssets.frame_region(key, frame)
		var pivot := PresentationAssets.frame_pivot(key, frame)
		var bounds: Array = asset["frame_bounds_ltrb"][frame]
		var expected_y := (float(int(frame / 4)) * source_size.y / 2.0 + float(bounds[3])) * factor.y
		c.near(region.position.y + pivot.y, expected_y, 0.001,
				"runtime anchor matches the actual pose bottom, including the second row")
	var icon := UiTheme.character_icon(&"looper")
	c.eq((icon.texture as AtlasTexture).region, PresentationAssets.idle_region(key),
			"wide attack/death art cannot shrink the character-select identity")
	icon.free()


func test_frame_selection_handles_missing_and_out_of_range_inputs(c: Check) -> void:
	var key: StringName = &"character_looper_front"
	var count := PresentationAssets.frame_count(key)
	c.eq(count, 8, "protagonist includes gait, hurt, action and terminal drawings")
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
