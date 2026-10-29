extends "res://tools/battle_art_probe.gd"
# Native-size evidence for the recycling depot and the three Batch B priorities.
# Staged durability, ages, positions and loadouts make visual states repeatable;
# real Main, Sim, contact, weapon producers and Boss damage own the actual events.
# REVERB_LANG=en godot --path . --fixed-fps 60 --disable-vsync \
#   --write-movie res://shots/depot-art.avi --script res://tools/depot_art_probe.gd
# Optional -- --reduced; external --resolution is preserved for resize coverage.

const COPY_AGES: Array[int] = [0, 2, 4, 6, 8, 10, 11, 11]
const TEAR_FRAMES: Array[int] = [0, 6, 12, 19, 29, 37]
const CROWD_ENEMIES := 84


func _initialize() -> void:
	for pair in [["REVERB_SAVE", "test_depot_art_save.json"],
		["REVERB_RUN_LOG", "test_depot_art_runs.jsonl"],
		["REVERB_SETTINGS", "test_depot_art_settings.json"],
		["REVERB_FEEDBACK_LOG", "test_depot_art_feedback.jsonl"]]:
		var path := "user://" + str(pair[1])
		OS.set_environment(str(pair[0]), path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	for argument in OS.get_cmdline_user_args():
		if argument != "--reduced":
			_fail("unknown probe argument: " + argument)
			return
	_reduced = OS.get_environment("REVERB_BATTLE_REDUCED") == "1" \
		or OS.get_cmdline_user_args().has("--reduced")
	if DisplayServer.get_name() == "headless":
		_fail("depot_art_probe needs a real rendering window")
		return
	RenderingServer.render_loop_enabled = false
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await _wait(8)
	_dir = ProjectSettings.globalize_path("res://shots/depot-art/" + Loc.lang \
		+ ("-reduced" if _reduced else "-standard"))
	DirAccess.make_dir_recursive_absolute(_dir)
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["fixture"]["copy_ages"] = COPY_AGES
	_summary["fixture"]["merged_flags"] = "staged identity flags; merge rules verified by unit suite"
	_summary["fixture"]["crowd_positions"] = "staged overlap, not balance evidence"
	_summary["environment"] = {"window": _vec(DisplayServer.window_get_size()),
		"logical_viewport": _vec(root.get_visible_rect().size),
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method")}
	_main.settings.reduced_effects = _reduced
	_main._apply_reduced_effects()
	var portrait_before := _portrait_catalog()
	if not await _depot():
		return
	if not await _copy_states():
		return
	if not await _crowded_player():
		return
	if not await _edge_clipping():
		return
	if not await _tear_sequence():
		return
	if not _require(portrait_before == _portrait_catalog(), "render states do not alter portrait/idle calibration"):
		return
	_summary["portrait_pipeline_unchanged"] = true
	_summary["frames"] = _frame
	_summary["source_head"] = _source_head()
	_release()
	_main.audio.stop_all()
	_main.show_select()
	if not _require(_main.sim == null and _main._view.sim == null, "normal title path detaches depot run"):
		return
	_main.queue_free()
	_main = null
	await _wait(2)
	_write_summary()
	print("depot art probe: OK, %s, reduced=%s, %d frames" % [Loc.lang, _reduced, _frame])
	quit()


func _depot() -> bool:
	var empty: Array[StringName] = []
	_new_fixture(3, empty)
	if not _require(_main._arena_clip.clip_contents, "world owns a real fixed child clipping rectangle"):
		return false
	if not _require(_main._arena_clip.position == Sim.ARENA.position
			and _main._arena_clip.size == Sim.ARENA.size, "clip uses the authoritative combat rectangle"):
		return false
	var landmarks := RecyclingDepot.landmark_rects()
	for key: StringName in landmarks:
		var bounds: Rect2 = landmarks[key]
		if not _require(Sim.ARENA.encloses(bounds) and not RecyclingDepot.QUIET_CENTER.intersects(bounds),
				"depot landmarks stay inside the world and outside its reserved quiet center"):
			return false
	_summary["depot_landmark_bounds"] = {}
	for key: StringName in landmarks:
		var bounds: Rect2 = landmarks[key]
		_summary["depot_landmark_bounds"][key] = [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
	_summary["depot_reserved_quiet_center"] = str(RecyclingDepot.QUIET_CENTER)
	await _wait(90)
	if not await _capture("depot_quiet_center"):
		return false
	await _wait(60)
	return true


func _mixed_copy_fixture() -> Sim:
	var pistol: Array[StringName] = [&"pistol"]
	var sim := _new_fixture(19, pistol, 8)
	sim.player.stats.values[Stats.ECHO_LIFESPAN] = 12.0
	for index in sim.echoes.size():
		# EchoBank.add resets age, so stages are set only after real actor creation.
		var take := sim.echoes[index].take
		take.age = COPY_AGES[index]
		take.merged = index == 2 or index == 5 or index == 7
	return sim


func _copy_states() -> bool:
	var sim := _mixed_copy_fixture()
	_spawn(sim, &"brute", Vector2(640.0, 160.0))
	await _wait(90)
	if not _require(sim.echoes.size() == 8 and sim.echo_lifespan() == 12, "eight real copies retain effective lifespan twelve"):
		return false
	var counts := {"fresh": 0, "worn": 0, "expiring": 0, "merged": 0}
	for index in sim.echoes.size():
		var actor := sim.echoes[index]
		var profile := EchoInk.profile(actor, sim, 0.0, _reduced)
		if not _require(actor.take.age == COPY_AGES[index], "mixed copy age survives actual playback"):
			return false
		counts["fresh"] += int(actor.take.age == 0)
		counts["worn"] += int(actor.take.age > 0 and not bool(profile["expiring"]))
		counts["expiring"] += int(bool(profile["expiring"]))
		counts["merged"] += int(actor.take.merged)
		if not _require(not (profile as Dictionary).has("pip_count"), "tiny battlefield life meter is removed"):
			return false
	_summary["copy_state_counts"] = counts
	if not _require(int(counts["fresh"]) == 1 and int(counts["expiring"]) == 2
			and int(counts["merged"]) == 3, "native scene includes fresh, worn, last-wave and bound copies"):
		return false
	if not await _capture("eight_copies_state_hierarchy"):
		return false
	sim.player.iframes = 0.0
	var censor := _spawn(sim, &"silencer", sim.player.pos)
	censor.speed = 0.0
	await _wait(5)
	if not _require(sim.echo_silenced > 0.0, "silence is triggered by real silencer contact"):
		return false
	for actor in sim.echoes:
		var profile := EchoInk.profile(actor, sim, 0.0, _reduced)
		if not _require(bool(profile["muted"]), "actual silence reaches every active copy contour"):
			return false
	if not await _capture("eight_copies_silenced"):
		return false
	censor.pos = Vector2(1140.0, 180.0)
	await _wait(90)
	return true


func _crowded_player() -> bool:
	var sim := _mixed_copy_fixture()
	# This fixture isolates overlap. Combat producers are exercised separately by
	# copy playback and edge clipping; no live shooter may erode the staged crowd.
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for actor in sim.echoes:
		actor.take.weapons.clear()
		actor.take.levels.clear()
		actor.cooldowns.clear()
	var center := Vector2(640.0, 390.0)
	sim.player.pos = center
	for index in sim.echoes.size():
		var actor := sim.echoes[index]
		var offset := Vector2(float(index % 4) * 13.0 - 19.5, float(index / 4) * 18.0 - 9.0)
		actor.take.samples = PackedVector2Array()
		for sample in 120:
			actor.take.samples.append(center + offset)
		actor.pos = center + offset
	for index in CROWD_ENEMIES:
		var angle := float(index) * 2.399963
		var radius := 16.0 + sqrt(float(index)) * 13.5
		var enemy := _spawn(sim, ENEMIES[index % ENEMIES.size()], center + Vector2.from_angle(angle) * radius)
		enemy.speed = 0.0
		enemy.damage = 0.0
	await _wait(45)
	_main.paused = true
	_main._view.set_paused(true)
	var live_enemies := 0
	for enemy in sim.enemies:
		if not enemy.dead:
			live_enemies += 1
	_summary["crowd_fixture"] = {"expected_live_enemies": CROWD_ENEMIES,
		"actual_live_enemies": live_enemies, "expected_copies": 8,
		"actual_copies": sim.echoes.size(), "shooters": 0}
	if not _require(live_enemies == CROWD_ENEMIES and sim.echoes.size() == 8,
			"crowd capture retains all eighty-four living enemies and eight copies"):
		return false
	if not await _capture("crowded_original_copy_enemy"):
		return false
	var image := root.get_texture().get_image()
	var region := Rect2(sim.player.pos - Vector2(42.0, 72.0), Vector2(84.0, 104.0))
	_summary["player_region_luminance"] = _luminance(image, _world_pixel_rect(region))
	_summary["player_region_luminance"]["interpretation"] = "pixel evidence only; no claim of human usability"
	if not _check_render_state_purity():
		return false
	_main.paused = false
	_main._view.set_paused(false)
	await _wait(45)
	return true


func _edge_clipping() -> bool:
	var empty: Array[StringName] = []
	var sim := _new_fixture(12, empty)
	_main.paused = true
	_main._view.set_paused(true)
	_main.hud.visible = false
	var results: Array = []
	for shake: Vector2 in [Vector2(-9.0, -9.0), Vector2(9.0, 9.0)]:
		sim.enemies.clear()
		sim.projectiles.clear()
		_main._view._sparks.clear()
		_main._view._clear_feedback()
		_main._view.position = shake
		await _refresh_world()
		var before := root.get_texture().get_image()
		for side in 4:
			for index in 7:
				var along := 0.12 + float(index) * 0.12
				var point := Vector2.ZERO
				match side:
					0: point = Vector2(lerpf(Sim.ARENA.position.x, Sim.ARENA.end.x, along), Sim.ARENA.position.y + 24.0)
					1: point = Vector2(Sim.ARENA.end.x - 24.0, lerpf(Sim.ARENA.position.y, Sim.ARENA.end.y, along))
					2: point = Vector2(lerpf(Sim.ARENA.position.x, Sim.ARENA.end.x, along), Sim.ARENA.end.y - 24.0)
					3: point = Vector2(Sim.ARENA.position.x + 24.0, lerpf(Sim.ARENA.position.y, Sim.ARENA.end.y, along))
				var ids: Array[StringName] = [&"grunt", &"runner", &"brute", &"bomber", &"warden", &"silencer", &"paradox"]
				var enemy := _spawn(sim, ids[index], point)
				enemy.speed = 0.0
				enemy.damage = 0.0
		for edge in [
			[Vector2(50.0, 380.0), Vector2.LEFT], [Vector2(1230.0, 380.0), Vector2.RIGHT],
			[Vector2(640.0, 90.0), Vector2.UP], [Vector2(640.0, 670.0), Vector2.DOWN]]:
			var point: Vector2 = edge[0]
			var direction: Vector2 = edge[1]
			# Real Combat producer; heads and optional trails use the actual MultiMesh path.
			Combat.fire(sim, point - direction * 14.0, point + direction * 100.0,
				Content.weapon(&"rail_spike"), 0, 1.0, sim.player.stats, 1.0, -1, Color.WHITE)
			var spark: Spark = _main._view._spark(point, ArenaPainter.PAPER, 0.0, 1.0)
			if spark != null:
				spark.ring = true
				spark.radius = 40.0
		await _refresh_world()
		var after := root.get_texture().get_image()
		if not _require(before.get_size() == after.get_size(), "clip comparison uses the same physical raster size"):
			return false
		var fixed_clip := _clip_pixel_rect()
		var diff := _outside_difference(before, after, fixed_clip)
		diff["shake"] = _vec(shake)
		diff["clip_pixel_rect"] = _rect(fixed_clip)
		diff["weapon_batches"] = WeaponInk._last_render.duplicate(true)
		diff["projection"] = _projection_state()
		results.append(diff)
		_summary["clip_pixel_proof"] = results
		if not _require(int(WeaponInk._last_render["projectiles"]) >= 4
				and int(WeaponInk._last_render["draw_calls"]) >= 1, "real edge projectile heads are submitted through MultiMesh"):
			return false
		if int(diff["outside_changed"]) > 0:
			before.save_png(_dir.path_join("clip_failure_before.png"))
			after.save_png(_dir.path_join("clip_failure_after.png"))
		if not _require(int(diff["outside_changed"]) == 0, "bodies, marks, paper sparks and batched projectiles cannot paint outside fixed combat bounds"):
			return false
		if not _require(int(diff["inside_changed"]) > 200, "clip proof actually draws a visible changed combat scene"):
			return false
		var name := "edge_world_only_negative_shake" if shake.x < 0.0 else "edge_world_only_positive_shake"
		if not await _capture(name):
			return false
	_summary["clip_pixel_proof"] = results
	var hud: Hud = _main.hud
	var health: Rect2 = hud.layout_regions()["health"]
	var hud_roi := _viewport_pixel_rect(hud.get_global_transform_with_canvas() * health.grow(-10.0))
	var hud_hidden_pixels := _luminance(root.get_texture().get_image(), hud_roi)
	_main.hud.visible = true
	hud.queue_redraw()
	await _refresh_world()
	if not _require(hud.is_visible_in_tree(), "edge overview restores the actual visible HUD"):
		return false
	var hud_visible_pixels := _luminance(root.get_texture().get_image(), hud_roi)
	var visible_delta := float(hud_visible_pixels["mean"]) - float(hud_hidden_pixels["mean"])
	_summary["edge_hud_pixel_proof"] = {"hidden": hud_hidden_pixels,
		"visible": hud_visible_pixels, "mean_luminance_increase": visible_delta,
		"visible_in_tree": hud.is_visible_in_tree()}
	if not _require(int(hud_visible_pixels["pixels"]) > 300 and float(hud_visible_pixels["mean"]) > 0.3
			and visible_delta > 0.2, "restored health-scroll pixels replace the dark HUD margin before capture"):
		return false
	if not await _capture("all_bodies_four_edges_with_hud"):
		return false
	await _wait(30)
	_main._view.position = Vector2.ZERO
	_main._view.set_paused(false)
	_main.paused = false
	return true


func _tear_sequence() -> bool:
	var empty: Array[StringName] = []
	var sim := _new_fixture(20, empty, 2, true)
	for frame in 240:
		if sim.boss != null:
			break
		await process_frame
	if not _require(sim.boss != null, "final-wave plan creates the real Original"):
		return false
	await _wait(30)
	if not await _capture("boss_original_before_tear"):
		return false
	_main.paused = true
	_main._view.set_paused(true)
	sim.boss.hp = sim.boss.max_hp * 0.51
	sim.damage_enemy(sim.boss, sim.boss.max_hp * 0.02, Vector2.ZERO, false, -1, Vector2.RIGHT, &"rail_spike")
	if not _require(sim.boss_phase == 2 and sim.boss_alive_count() == 2, "real damage creates two harmful Boss halves"):
		return false
	var view: ArenaView = _main._view
	var fixed_state := _gameplay_state()
	view.set_process(false)
	view.set_paused(false)
	var stages: Array = []
	for frame in 38:
		if frame > 0:
			view._process(1.0 / 60.0)
		await _refresh_world()
		if TEAR_FRAMES.has(frame):
			var profile := view._director.tear_profile(_reduced)
			if not _require(not profile.is_empty(), "tear survives until every authored beat is photographed"):
				return false
			stages.append({"frame": frame, "seconds": float(frame) / 60.0,
				"stage": profile["stage"], "spring": profile["spring"],
				"whole_alpha": profile["whole_alpha"], "half_alpha": profile["half_alpha"],
				"shards": _body_snapshots(sim.boss_shards)})
			if not await _capture("boss_tear_%03dms" % roundi(float(frame) / 60.0 * 1000.0)):
				return false
		if not _require(fixed_state == _gameplay_state(), "tear render clock does not move or damage either real half, or consume RNG"):
			return false
		if frame == 12:
			view.set_paused(true)
			var paused_tear := view._director.tear.duplicate(true)
			var paused_clock: float = view._visual_time
			view._process(0.2)
			await _wait(12)
			if not _require(view._director.tear == paused_tear and view._visual_time == paused_clock,
					"ordinary pause freezes the seam snap and environment clock"):
				return false
			view.set_paused(false)
	_summary["boss_tear_timeline"] = stages
	_summary["boss_real_bodies_unchanged_during_render"] = true
	_summary["pause_freezes_tear_and_world_clock"] = true
	if _reduced:
		for stage: Dictionary in stages:
			if not _require(stage["stage"] == &"settled" and float(stage["spring"]) == 0.0,
					"reduced path retains static transition geometry"):
				return false
	else:
		if not _require(stages[0]["stage"] == &"tension" and stages[2]["stage"] == &"snap"
				and stages[3]["stage"] == &"release", "native sequence includes tension, seam break and paper spring"):
			return false
	view.set_process(true)
	view.set_paused(false)
	_main.paused = false
	await _wait(90)
	if not await _capture("boss_two_live_halves"):
		return false
	return true


func _refresh_world() -> void:
	_main._view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()


func _check_render_state_purity() -> bool:
	var before := _gameplay_state()
	var view: ArenaView = _main._view
	var clock: float = view._visual_time
	var corpses := view._director.corpses.duplicate(true)
	var depot: RecyclingDepot = view._backdrop._depot
	var depot_before := [depot._visual_time, depot._draw_tick]
	view._process(0.25)
	RenderingServer.force_draw()
	var same := before == _gameplay_state()
	var depot_frozen := depot_before == [depot._visual_time, depot._draw_tick]
	_summary["render_purity"] = {"both_rngs_and_gameplay_unchanged": same,
		"paused_clock_frozen": clock == view._visual_time,
		"paused_corpses_frozen": corpses == view._director.corpses,
		"paused_depot_frozen": depot_frozen}
	return _require(same and clock == view._visual_time and corpses == view._director.corpses and depot_frozen,
		"paused native draw leaves both RNGs, gameplay and visual clocks unchanged")


func _gameplay_state() -> Array:
	var sim: Sim = _main.sim
	return [sim.rng.state, sim.hazard_rng.state, sim.wave_time, sim.player.pos,
		sim.player.hp, sim.player.cooldowns.duplicate(), sim.kills, sim.player.materials,
		_body_snapshots(sim.enemies)]


func _body_snapshots(bodies: Array[EnemyState]) -> Array:
	var result: Array = []
	for enemy in bodies:
		result.append({"uid": enemy.uid, "pos": _vec(enemy.pos), "hp": enemy.hp,
			"dead": enemy.dead, "radius": enemy.radius})
	return result


func _clip_pixel_rect() -> Rect2i:
	var clip: Control = _main._arena_clip
	var transform := clip.get_global_transform_with_canvas()
	var bounds := transform * Rect2(Vector2.ZERO, clip.size)
	return _viewport_pixel_rect(bounds)


func _world_pixel_rect(bounds: Rect2) -> Rect2i:
	return _viewport_pixel_rect(_main._view.get_global_transform_with_canvas() * bounds)


func _viewport_pixel_rect(bounds: Rect2) -> Rect2i:
	# ViewportTexture.get_size() can report a second scaled size in canvas_items
	# mode (720x405 at a 960x540 window). Pixel checks must use the actual readback,
	# whose image excludes keep-aspect window letterboxing, rather than screen-space
	# get_final_transform() or the texture's declared dimensions.
	var image_size := Vector2(root.get_texture().get_image().get_size())
	var viewport_size := root.get_visible_rect().size
	var scale := image_size / viewport_size
	var start := bounds.position * scale
	var end := bounds.end * scale
	# Native-size bounds are integral. The enclosing pixel rectangle also handles
	# fractional raster coordinates at scaled windows without mistaking the edge pixel.
	var left := Vector2i(floori(start.x), floori(start.y))
	var right := Vector2i(ceili(end.x), ceili(end.y))
	return Rect2i(left, right - left)


func _outside_difference(before: Image, after: Image, bounds: Rect2i) -> Dictionary:
	var outside := 0
	var inside := 0
	var maximum := 0.0
	var changed_min := Vector2i(after.get_width(), after.get_height())
	var changed_max := Vector2i(-1, -1)
	for y in after.get_height():
		for x in after.get_width():
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if delta <= 1.0 / 255.0:
				continue
			if bounds.has_point(Vector2i(x, y)):
				inside += 1
			else:
				outside += 1
				maximum = maxf(maximum, delta)
				changed_min = changed_min.min(Vector2i(x, y))
				changed_max = changed_max.max(Vector2i(x, y))
	return {"outside_changed": outside, "inside_changed": inside,
		"outside_max_channel_delta": maximum, "channel_tolerance": 1.0 / 255.0,
		"outside_bbox": _rect(Rect2i(changed_min, changed_max - changed_min + Vector2i.ONE)) if outside > 0 else [],
		"image_size": [after.get_width(), after.get_height()]}


func _projection_state() -> Dictionary:
	var clip: Control = _main._arena_clip
	return {"image": _vec(root.get_texture().get_image().get_size()),
		"texture_reported_size": _vec(root.get_texture().get_size()),
		"visible_rect": str(root.get_visible_rect()), "window": _vec(DisplayServer.window_get_size()),
		"clip_global_canvas": str(clip.get_global_transform_with_canvas()),
		"clip_viewport_transform": str(clip.get_viewport_transform()),
		"root_stretch": str(root.get_stretch_transform()),
		"root_final": str(root.get_final_transform()),
		"root_canvas": str(root.canvas_transform), "root_global_canvas": str(root.global_canvas_transform)}


func _luminance(image: Image, bounds: Rect2i) -> Dictionary:
	var clipped := bounds.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var low := 1.0
	var high := 0.0
	var total := 0.0
	var total_sq := 0.0
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var color := image.get_pixel(x, y)
			var value := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			low = minf(low, value)
			high = maxf(high, value)
			total += value
			total_sq += value * value
			count += 1
	var mean := total / float(maxi(1, count))
	return {"rect": _rect(clipped), "pixels": count, "min": low, "max": high,
		"mean": mean, "standard_deviation": sqrt(maxf(0.0, total_sq / float(maxi(1, count)) - mean * mean))}


func _portrait_catalog() -> Dictionary:
	var result: Dictionary = {}
	for id: StringName in [&"looper", &"solo", &"mirror", &"conductor"]:
		for back in [false, true]:
			var key := PresentationAssets.character_key(id, back)
			result[key] = [PresentationAssets.frame_count(key), PresentationAssets.idle_region(key)]
	return result


func _source_head() -> String:
	var output: Array = []
	if OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true) == 0 and not output.is_empty():
		return str(output[0]).strip_edges()
	return "unavailable"


func _vec(value: Vector2) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2i) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_release()
	if not _dir.is_empty():
		_summary["failure"] = message
		_write_summary()
	printerr("depot art probe: FAILED: " + message)
	quit(1)
