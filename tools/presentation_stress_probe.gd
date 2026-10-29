extends SceneTree
# Actual Main rendering stress/headroom probe. Fixed-fps + vsync-off timings are
# comparative frame-production headroom on this machine, not universal game FPS.
# Usage: godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/presentation_stress_probe.gd

const WARMUP_FRAMES := 120
const MEASURED_FRAMES := 360
const DEADLINE_MSEC := 180000
const LOADOUT: Array[StringName] = [
	&"pistol", &"longbow", &"shotgun", &"twin_fangs", &"flak_crown", &"nova_core",
]
const BALLISTIC_LOADOUT: Array[StringName] = [
	&"smg", &"smg", &"smg", &"flechette", &"stapler", &"paper_plane",
]
const CASES := [
	{"name": "100_standard", "count": 100, "reduced": false},
	{"name": "300_standard", "count": 300, "reduced": false},
	{"name": "300_reduced", "count": 300, "reduced": true},
	{"name": "300_eight_copies", "count": 300, "reduced": false, "echoes": 8},
	{"name": "300_eight_reduced", "count": 300, "reduced": true, "echoes": 8},
	{"name": "35_ballistic_eight_copies", "count": 35, "reduced": false, "echoes": 8, "ballistic": true},
	{"name": "300_dense_eight_copies", "count": 300, "reduced": false, "echoes": 8, "dense": true},
]

var _main: Node
var _frames := 0
var _started_msec := Time.get_ticks_msec()
var _failed := false
var _shots_dir := ""
var _summary: Dictionary = {"cases": [], "screenshots": {}, "pure_view_tick": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_presentation_stress_probe_suspend.json")
	RenderingServer.render_loop_enabled = false
	OS.set_environment("REVERB_SAVE", "user://presentation_stress_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://presentation_stress_probe_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://presentation_stress_probe_settings.json")
	_clear_fixture_files()
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if Time.get_ticks_msec() - _started_msec > DEADLINE_MSEC and not _failed:
		_fail("deadline exceeded before stress probe completed")
	if not _failed:
		RenderingServer.force_draw()
	return false


func _run() -> void:
	if not (await _wait_for_main()):
		return
	if not _check_pure_view_tick():
		return
	if not (await _edge_fixture(false, "edge_standard")):
		return
	if not (await _edge_fixture(true, "edge_reduced")):
		return
	for raw: Dictionary in CASES:
		var result: Dictionary = await _measure_case(
				String(raw["name"]), int(raw["count"]), bool(raw["reduced"]), int(raw.get("echoes", 4)),
				bool(raw.get("ballistic", false)), bool(raw.get("dense", false)))
		if result.is_empty():
			return
		(_summary["cases"] as Array).append(result)
	_release_input()
	_main.audio.stop_all()
	_main.show_select()
	if not _require(_main.sim == null and _main._view.sim == null and _main.hud.sim == null,
			"stress teardown releases the active simulation through the title-screen path"):
		return
	_main.queue_free()
	_main = null
	await _wait_frames(2)
	_summary["teardown"] = {"simulation_released": true, "main_freed": true}
	_write_summary()
	print("presentation stress probe: %s" % JSON.stringify(_summary["cases"]))
	print("presentation stress probe: OK")
	quit()


func _wait_for_main() -> bool:
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible:
			break
		await process_frame
	if not _require(_main.character_select != null, "Main reached character selection"):
		return false
	_main.meta.unlocked[&"looper"] = true
	_main.choose_character(&"looper", 20261023)
	await _wait_frames(3)
	return _require(_main.sim != null and _main._view.visible and _main.hud.visible,
			"Main entered a visible run")


func _check_pure_view_tick() -> bool:
	var sim: Sim = _main.sim
	_main.paused = true
	_main.pause_ui.close()
	_main._view.set_paused(false)
	var rng_state: int = sim.rng.state
	var wave_time: float = sim.wave_time
	var player_pos: Vector2 = sim.player.pos
	var cooldowns: Array[float] = sim.player.cooldowns.duplicate()
	var before_snapshot := RunSnapshot.capture(sim)
	if not _require(not before_snapshot.is_empty(), "pure view fixture has a complete gameplay snapshot"):
		return false
	_main._view._process(0.25)
	var unchanged: bool = (sim.rng.state == rng_state and is_equal_approx(sim.wave_time, wave_time)
			and sim.player.pos == player_pos and sim.player.cooldowns == cooldowns
	)
	if not _require(unchanged, "pure ArenaView tick leaves Sim state and RNG unchanged"):
		return false
	if not _require(RunSnapshot.capture(sim) == before_snapshot,
			"pure ArenaView tick preserves the entire exact gameplay snapshot"):
		return false
	_summary["pure_view_tick"] = {"rng_unchanged": true, "wave_time_unchanged": true,
		"player_position_unchanged": true, "cooldowns_unchanged": true, "full_snapshot_unchanged": true}
	_main.paused = false
	return true


func _edge_fixture(reduced: bool, name: String) -> bool:
	_setup_run(reduced)
	var sim: Sim = _main.sim
	var positions: Array[Vector2] = [
		Vector2(82.0, 118.0), Vector2(340.0, 104.0), Vector2(640.0, 108.0),
		Vector2(950.0, 104.0), Vector2(1192.0, 122.0), Vector2(88.0, 620.0),
		Vector2(1180.0, 614.0),
	]
	var defs: Array[EnemyDef] = Content.enemies()
	for i in defs.size():
		_add_enemy(defs[i], positions[i], 0.0)
	for _i in 18:
		_drive_square(_i)
		await process_frame
	_release_input()
	if not _require(_contains_all_enemy_types(sim), "%s contains all seven enemy types" % name):
		return false
	var captured: bool = await _capture(name)
	return captured


func _measure_case(name: String, count: int, reduced: bool, copies: int = 4,
		ballistic: bool = false, dense: bool = false) -> Dictionary:
	_setup_run(reduced, copies, ballistic)
	# Standard and reduced variants share the exact enemy layout seed so their
	# timing difference measures presentation settings rather than placement.
	if ballistic:
		_fill_ballistic_enemies(count)
	else:
		_fill_enemies(count, 4100 + count, dense)
	var sim: Sim = _main.sim
	if dense:
		var before := RunSnapshot.capture(sim)
		if not _require(not before.is_empty() and RunSnapshot.restore(before) != null,
				"dense fixture has a valid complete snapshot and enemy UID domain"):
			return {}
		_main._view._process(0.25)
		if not _require(RunSnapshot.capture(sim) == before,
				"dense ArenaView tick preserves its complete gameplay snapshot"):
			return {}
	var times: Array[int] = []
	var peak_enemies: int = 0
	var peak_visible_enemies: int = 0
	var min_visible_enemies: int = count
	var peak_echoes: int = 0
	var peak_projectiles: int = 0
	var peak_attack_fields: int = 0
	var peak_enemy_zones: int = 0
	var peak_audio_voices: int = 0
	var peak_mesh: Dictionary = {"projectiles": 0, "groups": 0, "draw_calls": 0, "trails": 0}
	var peak_feedback: Dictionary = {"muzzles": 0, "hits": 0, "explosions": 0, "hurts": 0,
		"recoils": 0, "weapon_changes": 0, "sparks": 0}
	var last_us: int = Time.get_ticks_usec()
	for frame in WARMUP_FRAMES + MEASURED_FRAMES:
		if ballistic or dense:
			_release_input()
		else:
			_drive_square(frame)
		await process_frame
		var now_us: int = Time.get_ticks_usec()
		if frame >= WARMUP_FRAMES:
			times.append(now_us - last_us)
			peak_enemies = maxi(peak_enemies, sim.enemies.size())
			var visible_enemies := _visible_enemy_count(sim)
			peak_visible_enemies = maxi(peak_visible_enemies, visible_enemies)
			min_visible_enemies = mini(min_visible_enemies, visible_enemies)
			peak_echoes = maxi(peak_echoes, sim.echoes.size())
			peak_projectiles = maxi(peak_projectiles, sim.projectiles.size())
			peak_attack_fields = maxi(peak_attack_fields, sim.attack_fields.size())
			peak_enemy_zones = maxi(peak_enemy_zones, sim.enemy_zones.size())
			var mesh_state: Dictionary = WeaponInk.render_stats()
			for key: String in peak_mesh:
				peak_mesh[key] = maxi(int(peak_mesh[key]), int(mesh_state.get(key, 0)))
			var audio_state: Dictionary = _main.audio.binding_state()
			peak_audio_voices = maxi(peak_audio_voices, int(audio_state.get("active_sfx", 0)))
			var feedback: Dictionary = _main._view.feedback_counts()
			for key: String in peak_feedback:
				peak_feedback[key] = maxi(int(peak_feedback[key]), int(feedback.get(key, 0)))
		last_us = now_us
	_release_input()
	if not _require(times.size() == MEASURED_FRAMES,
			"%s records every measured frame" % name):
		return {}
	if not _require(_contains_all_enemy_types(sim), "%s retains all seven enemy types" % name):
		return {}
	if not _require(peak_projectiles <= Combat.MAX_PROJECTILES
			and peak_attack_fields <= Combat.MAX_ACTIVE_FIELDS and peak_enemy_zones <= EnemyBrain.MAX_ZONES,
			"%s actual projectiles, attack fields and enemy zones stay inside gameplay caps" % name):
		return {}
	if ballistic and not _require(peak_projectiles >= 400,
			"%s produces at least 400 real Combat projectiles" % name):
		return {}
	if dense and not _require(peak_visible_enemies >= 280 and peak_echoes == 8,
			"dense case observes at least 280 onscreen enemies with eight live copies"):
		return {}
	if not _require(peak_feedback["muzzles"] <= ArenaView.MAX_MUZZLES
			and peak_feedback["hits"] <= ArenaView.MAX_HITS
			and peak_feedback["explosions"] <= ArenaView.MAX_EXPLOSIONS
			and peak_feedback["hurts"] <= ArenaView.MAX_HURTS
			and peak_feedback["weapon_changes"] <= ArenaView.MAX_WEAPON_CHANGES
			and peak_feedback["sparks"] <= ArenaView.MAX_SPARKS,
			"%s presentation feedback queues stay within caps" % name):
		return {}
	if not _require(peak_audio_voices <= GameAudio.POOL,
			"%s audio voices stay within the fixed pool" % name):
		return {}
	if count == 300 or ballistic:
		if not (await _capture(("ballistic_%s" if ballistic else "dense_%s") % name)):
			return {}
	if dense and not _require(_visible_enemy_count(sim) >= 280,
			"dense screenshot still contains at least 280 onscreen enemy centers"):
		return {}
	var mesh: Dictionary = WeaponInk.render_stats()
	if ballistic and not _require(int(mesh["projectiles"]) == sim.projectiles.size(),
			"ballistic screenshot submits every real live projectile through the mesh renderer"):
		return {}
	times.sort()
	var total_us: int = 0
	for elapsed: int in times:
		total_us += elapsed
	var p99_index: int = clampi(int(floor(0.99 * float(times.size() - 1))), 0, times.size() - 1)
	return {"name": name, "enemy_target": count, "reduced_effects": reduced, "echoes": sim.echoes.size(),
		"frames": times.size(), "warmup_frames": WARMUP_FRAMES,
		"frame_avg_ms": float(total_us) / float(times.size()) / 1000.0,
		"frame_p99_ms": float(times[p99_index]) / 1000.0,
		"frame_max_ms": float(times[times.size() - 1]) / 1000.0,
		"peak_enemies": peak_enemies, "peak_visible_enemies": peak_visible_enemies,
		"min_visible_enemies": min_visible_enemies, "last_visible_enemies": _visible_enemy_count(sim),
		"peak_echoes": peak_echoes, "peak_projectiles": peak_projectiles,
		"peak_attack_fields": peak_attack_fields, "peak_enemy_zones": peak_enemy_zones,
		"last_projectiles": sim.projectiles.size(), "last_mesh": mesh, "peak_mesh": peak_mesh,
		"last_source_wave_time": sim.wave_time,
		"ballistic_fixture": ballistic,
		"dense_fixture": dense, "dense_snapshot_read_only": dense,
		"loadout": _string_names(BALLISTIC_LOADOUT if ballistic else LOADOUT),
		"range_multiplier": sim.player.stats.range_mult(),
		"attack_speed_multiplier": 1.0 / sim.player.stats.cooldown_mult(),
		"target_motion": "120s pin holds stationary far targets" if ballistic else "normal enemy brains",
		"placement": "centered +/-370x200 with machine clearance" if dense else ("far corridor" if ballistic else "full world"),
		"peak_feedback": peak_feedback, "peak_audio_voices": peak_audio_voices}


func _setup_run(reduced: bool, copies: int = 4, ballistic: bool = false) -> void:
	_main.new_run(20261023, &"looper")
	var sim: Sim = _main.sim
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for id in BALLISTIC_LOADOUT if ballistic else LOADOUT:
		sim.player.add_weapon(Content.weapon(id))
	if ballistic:
		sim.player.pos = Vector2(1240.0, 200.0)
		sim.player.stats.values[Stats.RANGE_PCT] = 2.0
		sim.player.stats.values[Stats.ATTACK_SPEED_PCT] = 2.0
	sim.player.stats.values[Stats.ECHO_SLOTS] = float(copies)
	sim.player.stats.values[Stats.ECHO_DURATION] = 600.0
	sim.bank.takes.clear()
	for i in copies:
		var take := _echo_take(i, ballistic)
		sim.bank.add(take)
		take.condition = 15.0 + float(i) * 10.0 if copies == 8 else 100.0
		take.merged = copies == 8 and i % 3 == 0
	sim.start_wave(3)
	if not _require(sim.echoes.size() == copies, "all requested copies exist in the real simulation"):
		return
	if copies == 8:
		var merged := 0
		for i in copies:
			if not _require(is_equal_approx(sim.echoes[i].take.condition, 15.0 + float(i) * 10.0), "eight-copy fixture retains every intended condition"):
				return
			if sim.echoes[i].take.merged:
				merged += 1
		if not _require(merged == 3 and sim.bank.takes.size() == 8 and is_equal_approx(sim.echo_duration(), 600.0),
				"mixed-wear fixture retains merged copies, duration and complete bank"):
			return
	sim.wave_duration = 120.0
	sim._plan.clear()
	sim._plan_idx = 0
	_main._view.set_reduced_effects(reduced)
	_main.shop_ui.set_reduced_effects(reduced)
	_main.end_ui.set_reduced_effects(reduced)
	_main._view.visible = true
	_main.hud.visible = true
	_main.shop_ui.visible = false
	_main.paused = false


func _echo_take(index: int, ballistic: bool = false) -> EchoTake:
	var take: EchoTake = EchoTake.new()
	take.wave = index + 1
	for id in BALLISTIC_LOADOUT if ballistic else LOADOUT:
		take.weapons.append(Content.weapon(id))
		take.levels.append(0)
	take.stats = _main.sim.player.stats.copy()
	var center: Vector2 = Sim.ARENA.get_center()
	for sample in 240:
		if ballistic:
			take.samples.append(Vector2(1240.0, 200.0 + (float(index) - 3.5) * 3.0))
			continue
		var angle: float = float(sample) * 0.045 + float(index) * 0.8
		var radius: float = 70.0 + float(index) * 42.0
		take.samples.append(center + Vector2(cos(angle) * radius, sin(angle * 1.2) * radius * 0.7))
	return take


func _fill_enemies(count: int, seed_value: int, dense: bool = false) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var defs: Array[EnemyDef] = Content.enemies()
	var box: Rect2 = Rect2(Sim.ARENA.get_center() - Vector2(370.0, 200.0), Vector2(740.0, 400.0)) \
		if dense else Sim.ARENA.grow(-42.0)
	for i in count:
		var def: EnemyDef = defs[i] if i < defs.size() else defs[i % (defs.size() - 1)]
		var position: Vector2 = Vector2(rng.randf_range(box.position.x, box.end.x),
				rng.randf_range(box.position.y, box.end.y))
		if dense:
			position = WorldArena.move_body(position, Vector2.ZERO, def.radius)
			if not _require(WorldArena.body_clear(position, def.radius), "dense body clears real world machines"):
				return
		_add_enemy(def, position, def.speed)


func _visible_enemy_count(sim: Sim) -> int:
	var camera := WorldArena.camera_rect(sim.player.pos)
	var count := 0
	for enemy in sim.enemies:
		if not enemy.dead and camera.has_point(enemy.pos):
			count += 1
	return count


func _add_enemy(def: EnemyDef, position: Vector2, speed: float) -> void:
	var sim: Sim = _main.sim
	var enemy: EnemyState = EnemyState.new()
	enemy.uid = sim._next_uid
	sim._next_uid += 1
	enemy.def = def
	enemy.pos = position
	enemy.max_hp = 1.0e9
	enemy.hp = enemy.max_hp
	enemy.speed = speed
	enemy.damage = 0.0
	enemy.radius = def.radius
	sim.enemies.append(enemy)


func _fill_ballistic_enemies(count: int) -> void:
	var defs: Array[EnemyDef] = Content.enemies()
	for index in count:
		var position := Vector2(1980.0 + float(index % 5) * 3.0, 200.0 + float(index % 7 - 3) * 6.0)
		_add_enemy(defs[index % defs.size()], position, 0.0)
		var enemy: EnemyState = _main.sim.enemies[-1]
		# This real pin keeps repeated knockback from walking a stationary target
		# beyond weapon range; projectile creation, flight and collision stay live.
		enemy.pin_left = 120.0


func _contains_all_enemy_types(sim: Sim) -> bool:
	var seen: Dictionary = {}
	for enemy: EnemyState in sim.enemies:
		seen[enemy.def.id] = true
	for def: EnemyDef in Content.enemies():
		if not seen.has(def.id):
			return false
	return seen.size() == Content.enemies().size()


func _drive_square(frame: int) -> void:
	_release_input()
	match int(frame / 45) % 4:
		0:
			Input.action_press(&"move_right")
		1:
			Input.action_press(&"move_down")
		2:
			Input.action_press(&"move_left")
		_:
			Input.action_press(&"move_up")


func _release_input() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _capture(name: String) -> bool:
	if not _require(_main._view.visible and _main.hud.visible
			and _main.sim != null and _main.sim.phase == Sim.Phase.WAVE,
			"%s captures a visible real arena" % name):
		return false
	var sim: Sim = _main.sim
	var main_physics: bool = _main.is_physics_processing()
	var view_process: bool = _main._view.is_processing()
	var view_physics: bool = _main._view.is_physics_processing()
	var hud_process: bool = _main.hud.is_processing()
	_main.set_physics_process(false)
	_main._view.set_process(false)
	_main._view.set_physics_process(false)
	_main.hud.set_process(false)
	# Align the presentation to this frozen simulation without advancing a clock.
	_main._view._process(0.0)
	var source_time := sim.wave_time
	var source_heads := sim.projectiles.size()
	var source_valid_heads := _valid_projectile_count(sim)
	var source_frame := _frames
	var previous_mesh := WeaponInk.render_stats()
	var before := RunSnapshot.capture(sim)
	print("stress capture source: %s" % JSON.stringify({"name": name, "source_wave_time": source_time,
		"probe_frame": source_frame, "live_heads": source_heads, "valid_heads": source_valid_heads,
		"previous_mesh": previous_mesh}))
	_main._view.queue_redraw()
	_main.hud.queue_redraw()
	await process_frame
	# process_frame resumes before node processing and queued CanvasItem redraws.
	# The second signal ensures the requested frozen draw has been submitted.
	await process_frame
	RenderingServer.force_draw()
	var image: Image = root.get_texture().get_image()
	var captured_mesh := WeaponInk.render_stats()
	var epoch := {"source_wave_time": source_time, "captured_wave_time": sim.wave_time,
		"source_probe_frame": source_frame, "captured_probe_frame": _frames,
		"source_live_heads": source_heads, "captured_live_heads": sim.projectiles.size(),
		"source_valid_heads": source_valid_heads, "captured_valid_heads": _valid_projectile_count(sim),
		"previous_mesh": previous_mesh, "captured_mesh": captured_mesh,
		"full_snapshot_unchanged": not before.is_empty() and RunSnapshot.capture(sim) == before}
	_main.set_physics_process(main_physics)
	_main._view.set_process(view_process)
	_main._view.set_physics_process(view_physics)
	_main.hud.set_process(hud_process)
	print("stress capture epoch: %s" % JSON.stringify({"name": name, "epoch": epoch}))
	if not _require(bool(epoch["full_snapshot_unchanged"]) and sim.wave_time == source_time
			and sim.projectiles.size() == source_heads,
			"%s frozen capture preserves its complete simulation epoch" % name):
		return false
	if not _require(image != null and not image.is_empty(), "%s frame readback exists" % name):
		return false
	var content_samples: int = _content_sample_count(image)
	if not _require(content_samples >= 32, "%s screenshot contains visible game content" % name):
		return false
	var path: String = _shots_dir.path_join("stress_%s.png" % name)
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("failed to save %s: %s" % [path, error])
		return false
	(_summary["screenshots"] as Dictionary)[name] = {"path": path,
		"width": image.get_width(), "height": image.get_height(),
		"content_samples": content_samples, "capture_epoch": epoch}
	print("wrote shots/stress_%s.png" % name)
	return true


func _valid_projectile_count(sim: Sim) -> int:
	var count := 0
	for projectile in sim.projectiles:
		if WeaponInk.valid_projectile(projectile):
			count += 1
	return count


func _content_sample_count(image: Image) -> int:
	var count: int = 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var color: Color = image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) >= 0.14:
				count += 1
	return count


func _write_summary() -> void:
	_summary["source_head"] = _git_head()
	_summary["environment"] = {"os": OS.get_name(), "godot": Engine.get_version_info(),
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"logical_viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]}
	_summary["fixture"] = {"loadout": _string_names(LOADOUT), "echoes": "4 and 8 per case",
		"ballistic_loadout": _string_names(BALLISTIC_LOADOUT), "ballistic_range_multiplier": 3.0,
		"ballistic_attack_speed_multiplier": 3.0, "ballistic_targets": "35 at (1980..1992,182..218), real120s pin",
		"dense_case": "300 enemies within centered +/-370x200, machine-clear, stationary player, normal enemy brains",
		"visible_enemy_scope": "living enemy center points inside the current unshaken camera, without art padding",
		"enemy_types": 7, "enemy_hp": "forced unkillable", "enemy_damage": 0,
		"timing_scope": "fixed-fps vsync-off explicit one-draw-per-tick headroom; not universal FPS"}
	var path: String = _shots_dir.path_join("presentation_stress_summary.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open stress summary")
		return
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	print("wrote shots/presentation_stress_summary.json")


func _git_head() -> String:
	var output: Array = []
	var code: int = OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true)
	if code != 0 or output.is_empty():
		return "unavailable"
	return str(output[0]).strip_edges()


func _string_names(values: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value in values:
		result.append(String(value))
	return result


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("presentation stress probe FAILED: %s" % message)
	_release_input()
	if _main != null and _main.audio != null:
		_main.audio.stop_all()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["presentation_stress_probe_save.json", "presentation_stress_probe_runs.jsonl",
			"presentation_stress_probe_settings.json"]:
		var path: String = ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
