extends SceneTree
# Native Main/ArenaView rendering fixture. Setup is synthetic; all art, geometry,
# state reads, clipping and production drawing calls are real. No human QA claim.
# REVERB_LANG=en|zh REVERB_PROBE_SIZE=1280x720|960x540
# godot --path . --script res://tools/expedition_art_probe.gd

var _main: Node
var _out := ""
var _failures: Array[String] = []
var _summary := {"screenshots": [], "pixels": [], "state_checks": [],
	"fixture": "Frozen 0.16 Main/Sim art gallery. Physical machine sites and natural worker/repair identities retain their canonical positions; extra part/terminal targets are disclosed mixed-order gallery staging, not a campaign result. Five equipment supports use the real allocator; companion deployment has a reciprocal persistent roster. Bosses use the real spawn allocator. One real weapon has a long cooldown. Actual ability activation and rule delta are executed.",
	"negative_control": "HUD draw processing is frozen to isolate arena clipping; only support/target visibility, active-to-bench roster status and boss brain states are temporarily changed. Original arrays, roster and enemy states are restored by UID. Skill controls restore the original role_effects dictionary. Complete RunSnapshot equality, strict JSON restore and both RNGs are checked."}
var _started := Time.get_ticks_msec()


func _initialize() -> void:
	for key in ["REVERB_SAVE", "REVERB_SETTINGS", "REVERB_RUN_LOG", "REVERB_FEEDBACK_LOG", "REVERB_SUSPEND"]:
		OS.set_environment(key, "user://expedition_art_probe_" + key.to_lower() + ".json")
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	var language := OS.get_environment("REVERB_LANG")
	Loc.lang = language if language in ["en", "zh"] else "en"
	var dimensions := OS.get_environment("REVERB_PROBE_SIZE")
	if dimensions == "":
		dimensions = "1280x720"
	var parts := dimensions.split("x")
	DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	_out = ProjectSettings.globalize_path("res://shots/expedition/" + Loc.lang + "-" + dimensions)
	DirAccess.make_dir_recursive_absolute(_out)
	_summary["profile"] = Loc.lang + "-" + dimensions
	if DisplayServer.get_name() == "headless":
		_failures.append("native display required")
		_finish()
		return
	RenderingServer.render_loop_enabled = false
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 60000:
		_failures.append("bounded native probe deadline")
		_finish()
	return false


func _run() -> void:
	await process_frame
	await process_frame
	_main._resize_battlefield()
	await process_frame
	_record_display()
	_main.new_run(1288)
	_main.set_physics_process(false)
	_main._view.set_process(false)
	_main._view.shake_enabled = false
	_main._view._visual_time = 1.3
	_main._view._beat_take = null
	_main._view._paths.clear()
	_main._view.set_reduced_effects(OS.get_environment("REVERB_PROBE_REDUCED") == "1")
	var sim: Sim = _main.sim
	sim.player.pos = Vector2(1240, 680)
	sim.enemies.clear()
	sim.pending.clear()
	sim.pickups.clear()
	sim._plan.clear()
	sim._plan_idx = 0
	sim.support_units.clear()
	sim.player.cooldowns[0] = 1000.0
	var camera := WorldArena.camera_rect(sim.player.pos, WorldArena.display_viewport(root.get_visible_rect().size))
	var support_kinds: Array[StringName] = [&"hound", &"turret", &"repair_station", &"paper_tree", &"decoy"]
	for index in support_kinds.size():
		SupportSystem.spawn(sim, support_kinds[index], camera.position + Vector2(100.0 + float(index) * (camera.size.x - 200.0) / 5.0, camera.size.y * 0.72))
		sim.support_units.back()["hp"] = float(sim.support_units.back()["max_hp"]) * 0.65
		sim.support_units.back()["cooldown"] = 0.9
		if support_kinds[index] == &"paper_tree":
			sim.support_units.back()["charges"] = 2
	_stage_companion(sim, &"foreman", camera.position + Vector2(camera.size.x - 100.0, camera.size.y * 0.72))
	# Preserve actual machine locations and the real endangered worker identity.
	# Only animation clocks and two extra mixed-order gallery props are staged.
	for item: Dictionary in sim.interactables:
		item["cooldown"] = 0.0
		if item["kind"] == &"press":
			item["warning"] = 0.6
		elif item["kind"] == &"conveyor":
			item["active"] = 3.0
	for index in 2:
		Expedition._add_target_at(sim, StringName("gallery_mission_%d" % index), &"part" if index == 0 else &"terminal",
			camera.position + Vector2(camera.size.x * (0.4 + index * 0.3), camera.size.y * 0.22))
	sim.expedition["mission"] = _mission(&"rescue", sim.wave)
	sim.expedition["negotiation"] = {}
	_main._view._update_camera()
	await _capture("support_and_missions", sim)
	var original_pos := sim.player.pos
	sim.player.pos = _target(sim, &"recycler")["pos"]
	_main._view._update_camera()
	Controls.using_gamepad = false
	await _capture("machine_keyboard", sim)
	Controls.using_gamepad = true
	await _capture("machine_controller", sim)
	Controls.using_gamepad = false
	for kind: StringName in [&"press", &"conveyor", &"part", &"terminal", &"repair", &"rescue"]:
		var target := _target(sim, kind)
		if target.is_empty():
			_failures.append("canonical gallery target missing: " + String(kind))
			continue
		sim.player.pos = target["pos"]
		_main._view._update_camera()
		await _capture("target_" + String(kind), sim)
	sim.player.pos = original_pos
	_main._view._update_camera()
	var companion_pos: Vector2 = sim.support_units.back()["pos"]
	for kind: StringName in [&"collector", &"paradox"]:
		_stage_companion(sim, kind, companion_pos)
		await _capture("recruited_" + String(kind), sim)
	for id: StringName in [&"foreman", &"collector", &"paradox"]:
		sim.enemies.clear()
		sim.expedition["negotiation"] = {}
		sim.expedition["mission"] = _mission(&"rescue", sim.wave)
		_remove_negotiation_target(sim)
		sim.boss = null
		sim.boss_shards.clear()
		var spawn := PendingSpawn.new()
		spawn.def = Content.enemy(id)
		spawn.pos = WorldArena.move_body(camera.position + Vector2(camera.size.x * 0.23, camera.size.y * 0.32), Vector2.ZERO, spawn.def.radius)
		sim._materialize(spawn)
		var enemy := sim.boss
		enemy.attack_target = camera.position + Vector2(camera.size.x * 0.63, camera.size.y * 0.35)
		enemy.attack_direction = Vector2.RIGHT
		enemy.brain_state = &"warn"
		enemy.brain_time = 0.55
		await _capture(String(id) + "_warning", sim)
		sim.expedition["mission"] = _mission(&"recruit", sim.wave)
		if not Expedition.try_negotiate(sim, enemy):
			_failures.append("canonical negotiation staging failed: " + String(id))
		await _capture(String(id) + "_negotiation", sim)
		if id == &"paradox":
			sim.expedition["negotiation"] = {}
			sim.expedition["mission"] = _mission(&"rescue", sim.wave)
			_remove_negotiation_target(sim)
			enemy.hp = enemy.max_hp
			enemy.brain_state = &"warn"
			_main._view.set_reduced_effects(true)
			await _capture("paradox_reduced", sim)
	_main._view.set_reduced_effects(OS.get_environment("REVERB_PROBE_REDUCED") == "1")
	await _pixel_control(sim)
	await _skill_captures()
	_finish()


func _capture(name: String, sim: Sim) -> void:
	_main.hud.set_process(false)
	var before := _checked_snapshot(sim, name + " before")
	var rng := [sim.rng.state, sim.hazard_rng.state]
	_main._view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var pixels := root.get_texture().get_image()
	if pixels == null or pixels.is_empty():
		_failures.append(name + " missing native pixels")
		return
	pixels.save_png(_out.path_join(name + ".png"))
	_assert_same(sim, before, rng, name + " render")
	var actual: Dictionary = _main._view.camera_profile()
	var display := WorldArena.display_viewport(root.get_visible_rect().size)
	var expected := WorldArena.camera_rect(sim.player.pos, display)
	var matches: bool = actual["world_rect"] == expected and _main._arena_clip.position == display.position and _main._arena_clip.size == display.size
	if not matches:
		_failures.append(name + " camera/clip differs from actual native canvas")
	var labels_inside := true
	var frame := ExpeditionInk.snapshot(sim, 1.3, _main._view.reduced_effects, display)
	for target: Dictionary in frame["targets"]:
		if bool(target["selected"]) and not expected.encloses(target["label"]):
			labels_inside = false
	if not labels_inside:
		_failures.append(name + " selected label leaves actual world camera")
	_summary["screenshots"].append({"name": name, "size": [pixels.get_width(), pixels.get_height()],
		"reduced_effects": _main._view.reduced_effects,
		"supports": ExpeditionInk.draw_stats()["supports"], "targets": ExpeditionInk.draw_stats()["targets"],
		"warnings": ExpeditionInk.draw_stats()["warnings"], "skills": ExpeditionInk.draw_stats()["skills"], "wave_time": sim.wave_time,
		"camera_world_xywh": _rect(actual["world_rect"]), "expected_camera_xywh": _rect(expected),
		"camera_and_clip_match": matches, "selected_labels_inside_camera": labels_inside, "full_snapshot_nonempty": not before.is_empty()})


func _skill_captures() -> void:
	_summary["skill_activations"] = []
	for role: StringName in Content.characters():
		_main.new_run(1288, role)
		_main.set_physics_process(false)
		_main._view.set_process(false)
		_main._view._beat_take = null
		_main._view.shake_enabled = false
		_main._view._visual_time = 1.3
		var sim: Sim = _main.sim
		sim.enemies.clear()
		sim.pending.clear()
		sim._plan.clear()
		sim._plan_idx = 0
		sim.interactables.clear()
		sim.bank.takes.clear()
		sim.echoes.clear()
		sim.selected_echo_uid = 0
		sim.player.cooldowns[0] = 1000.0
		sim.player.pos = Vector2(1240, 680)
		sim.player.facing = Vector2.RIGHT
		if role == &"looper":
			sim.role_effects["rewind_history"] = [Vector2(1190, 660), sim.player.pos]
		if role in [&"mirror", &"conductor", &"overloader"]:
			var take := EchoTake.new()
			take.samples = PackedVector2Array([Vector2(1400, 700), Vector2(1420, 700)])
			take.weapons.append(Content.weapon(&"pistol"))
			take.levels.append(0)
			take.wave = 1
			sim.bank.add(take)
			sim.echoes.append(EchoActor.new(take, 0))
			sim.selected_echo_uid = take.uid
		var activated := sim.activate_character_skill()
		if not activated:
			_failures.append("actual skill activation failed: " + String(role))
		# Advance the real rule clock slightly so authored invulnerability blink
		# permits a readable still; no effect geometry or result is fabricated.
		sim.step(0.02 if role == &"looper" else 0.06, Vector2.ZERO)
		_main._view._update_camera()
		await _capture("skill_" + String(role), sim)
		if int(ExpeditionInk.draw_stats()["skills"]) != 1:
			_failures.append("missing activation pixels: " + String(role))
		_summary["skill_activations"].append({"role": role, "activated": activated,
			"energy": sim.character_energy, "flash": sim.role_effects.get("ability_flash", 0.0)})
		var effects := sim.role_effects
		var baseline := _checked_snapshot(sim, String(role) + " control baseline")
		var rng := [sim.rng.state, sim.hazard_rng.state]
		var shown := root.get_texture().get_image()
		sim.role_effects = effects.duplicate(true)
		sim.role_effects["ability_flash"] = 0.0
		sim.role_effects["anchor_left"] = 0.0
		var control := _checked_snapshot(sim, String(role) + " hidden baseline")
		_main._view.queue_redraw()
		await process_frame
		RenderingServer.force_draw()
		var hidden := root.get_texture().get_image()
		_assert_same(sim, control, rng, String(role) + " hidden render")
		var changed := _changed_pixels(shown, hidden, _actual_roi(shown))
		if int(changed["world"]) < 20 or int(changed["outside"]) != 0:
			_failures.append("skill pixels or HUD clipping failed: " + String(role))
		changed["role"] = role
		_summary["pixels"].append(changed)
		sim.role_effects = effects
		_assert_same(sim, baseline, rng, String(role) + " control restored")


func _pixel_control(sim: Sim) -> void:
	_main.hud.set_process(false)
	var baseline := _checked_snapshot(sim, "world before render")
	var rng := [sim.rng.state, sim.hazard_rng.state]
	_store_snapshot("world_before_render", baseline)
	_main._view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var shown := root.get_texture().get_image()
	_assert_same(sim, baseline, rng, "world shown render")
	_store_snapshot("world_after_render", RunSnapshot.capture(sim))
	var units := sim.support_units
	var items := sim.interactables
	var roster: Array = sim.expedition["world"]["roster"]
	var hidden_roster: Array = roster.duplicate(true)
	for row: Dictionary in hidden_roster:
		if row["state"] == &"active":
			row["state"] = &"bench"
	var brains := {}
	for enemy: EnemyState in sim.enemies:
		brains[enemy.uid] = enemy.brain_state
		enemy.brain_state = &"recover"
	sim.support_units = []
	sim.interactables = []
	sim.expedition["world"]["roster"] = hidden_roster
	var control := _checked_snapshot(sim, "world hidden baseline")
	_main._view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	var hidden := root.get_texture().get_image()
	_assert_same(sim, control, rng, "world hidden render")
	var changed := _changed_pixels(shown, hidden, _actual_roi(shown))
	if int(changed["world"]) < 100:
		_failures.append("new expedition objects must change actual world pixels")
	if int(changed["outside"]) != 0:
		_failures.append("expedition rendering leaked into actual native HUD bands")
	_summary["pixels"].append(changed)
	sim.support_units = units
	sim.interactables = items
	sim.expedition["world"]["roster"] = roster
	for enemy: EnemyState in sim.enemies:
		enemy.brain_state = brains[enemy.uid]
	_assert_same(sim, baseline, rng, "world control restored")
	_store_snapshot("world_after_control", RunSnapshot.capture(sim))


func _stage_companion(sim: Sim, kind: StringName, pos: Vector2) -> void:
	var row := Expedition._roster(sim, kind)
	if row.is_empty():
		var profile: Dictionary = SupportSystem.PROFILES[StringName("recruited_" + String(kind))]
		row = {"kind": kind, "hp": float(profile["hp"]), "max_hp": float(profile["hp"]),
			"life": float(profile["life"]), "state": &"bench", "uid": 0}
		sim.expedition["world"]["roster"].append(row)
	if not Expedition._deploy(sim, kind):
		_failures.append("canonical roster deployment failed: " + String(kind))
		return
	var unit: Dictionary = sim.support_units.back()
	unit["pos"] = WorldArena.move_body(pos, Vector2.ZERO, SupportSystem.UNIT_RADIUS)
	unit["hp"] = float(unit["max_hp"]) * 0.65
	unit["cooldown"] = 0.9
	Expedition.sync_roster(sim)
	sim.expedition["recruited_boss"] = kind
	if not sim.expedition["recruited_bosses"].has(kind):
		sim.expedition["recruited_bosses"].append(kind)


func _target(sim: Sim, kind: StringName) -> Dictionary:
	for item: Dictionary in sim.interactables:
		if item["kind"] == kind and not item["used"]:
			return item
	return {}


func _mission(kind: StringName, wave: int) -> Dictionary:
	return {"kind": kind, "target": int(Expedition.ORDER_TARGETS[kind]), "progress": 0,
		"state": &"active", "wave": wave, "protected_hp": 30.0 if kind == &"rescue" else 0.0}


func _remove_negotiation_target(sim: Sim) -> void:
	var keep: Array[Dictionary] = []
	for item: Dictionary in sim.interactables:
		if item["kind"] != &"negotiate":
			keep.append(item)
	sim.interactables = keep


func _record_display() -> void:
	var canvas := root.get_visible_rect().size
	var clip := WorldArena.display_viewport(canvas)
	_summary["display"] = {"window_size": [root.size.x, root.size.y],
		"content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		"actual_canvas": [canvas.x, canvas.y], "display_clip_xywh": _rect(clip),
		"native_canvas_matches_window": canvas == Vector2(root.size)}
	if canvas != Vector2(root.size):
		_failures.append("actual native canvas does not match window")


func _actual_roi(pixels: Image) -> Rect2i:
	var canvas := root.get_visible_rect().size
	var clip := WorldArena.display_viewport(canvas)
	var scale := Vector2(pixels.get_size()) / canvas
	return Rect2i(clip.position * scale, clip.size * scale)


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _checked_snapshot(sim: Sim, label: String) -> Dictionary:
	var snapshot := RunSnapshot.capture(sim)
	var copy := RunSnapshot.restore(JSON.parse_string(JSON.stringify(snapshot))) if not snapshot.is_empty() else null
	var valid := copy != null
	if not valid:
		_failures.append(label + " invalid full snapshot: " + RunSnapshot.last_error)
	_summary["state_checks"].append({"label": label, "nonempty": not snapshot.is_empty(),
		"json_restore_valid": valid, "roundtrip_exact": valid and RunSnapshot.capture(copy) == snapshot})
	if valid and RunSnapshot.capture(copy) != snapshot:
		_failures.append(label + " snapshot JSON roundtrip changed authoritative state")
	return snapshot


func _assert_same(sim: Sim, before: Dictionary, rng: Array, label: String) -> void:
	var after := _checked_snapshot(sim, label)
	var exact := not before.is_empty() and before == after
	var rng_exact := rng == [sim.rng.state, sim.hazard_rng.state]
	if not exact or not rng_exact:
		_failures.append(label + " changed full authoritative state or RNG")
	_summary["state_checks"].append({"label": label + " comparison", "full_snapshot_exact": exact,
		"both_rngs_exact": rng_exact, "rng_state": str(sim.rng.state), "hazard_rng_state": str(sim.hazard_rng.state)})


func _store_snapshot(name: String, snapshot: Dictionary) -> void:
	var file := FileAccess.open(_out.path_join(name + ".snapshot.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(snapshot))


func _changed_pixels(first: Image, second: Image, roi: Rect2i) -> Dictionary:
	first.convert(Image.FORMAT_RGBA8)
	second.convert(Image.FORMAT_RGBA8)
	var a := first.get_data()
	var b := second.get_data()
	var inside := 0
	var outside := 0
	for y in first.get_height():
		for x in first.get_width():
			var offset := (y * first.get_width() + x) * 4
			if absi(int(a[offset]) - int(b[offset])) <= 2 and absi(int(a[offset + 1]) - int(b[offset + 1])) <= 2 \
				and absi(int(a[offset + 2]) - int(b[offset + 2])) <= 2 and absi(int(a[offset + 3]) - int(b[offset + 3])) <= 2:
				continue
			if roi.has_point(Vector2i(x, y)):
				inside += 1
			else:
				outside += 1
	return {"world": inside, "outside": outside}


func _finish() -> void:
	_summary["failures"] = _failures
	var file := FileAccess.open(_out.path_join("summary.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_summary, "\t"))
	_summary["lifecycle"] = {"main_detached": false, "all_snapshot_checks": _summary["state_checks"].size()}
	if _main != null:
		_main._detach_presentation_session()
		_main.free()
		_main = null
		_summary["lifecycle"]["main_detached"] = true
	if file != null:
		file.seek(0)
		file.store_string(JSON.stringify(_summary, "\t"))
	print(JSON.stringify(_summary))
	quit(0 if _failures.is_empty() else 1)
