extends SceneTree
# Native, constant-speed evidence from a scripted fixture, not a human playthrough.
# Run in CI with --fixed-fps 60 --write-movie <output>/paper_action.avi:
# --script res://tools/paper_action_probe.gd -- --output=<dir> --variant=normal

const DT := 1.0 / 60.0
const CASE_FRAMES := 96
const DEADLINE_MSEC := 180000
const WEAPONS: Array[Dictionary] = [
	{"name": "pin", "weapon": &"stapler"},
	{"name": "stamp", "weapon": &"stamp"},
	{"name": "cut", "weapon": &"cutter"},
	{"name": "ink", "weapon": &"ink_bottle"},
	{"name": "return", "weapon": &"paper_saw"},
	{"name": "arc", "weapon": &"hex_bolt"},
]

var _main: Node
var _output := ""
var _variant := "normal"
var _canvas := Vector2i(1280, 720)
var _failed := false
var _started := Time.get_ticks_msec()
var _native_frames := 0
var _case_frame := -1
var _first_action := -1
var _first_contact := -1
var _second_slot := -1
var _case_events: Dictionary = {}
var _proofs: Dictionary = {}
var _peaks: Dictionary = {}
var _samples: Dictionary = {}
var _shot_rows: Array[Dictionary] = []
var _support_uid := 0
var _retire_uid := 0
var _repair_pad := Vector2.INF
var _repair_body := Vector2.INF
var _current_mode := ""
var _gait_rows: Array[Dictionary] = []
var _isolated: Array[String] = []
var _summary: Dictionary = {"source": "scripted fixture", "cases": [], "screenshots": {},
	"read_only_checks": [], "success": false}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
		elif argument.begins_with("--variant="):
			_variant = argument.trim_prefix("--variant=")
	if _output.is_empty():
		_output = ProjectSettings.globalize_path("res://shots/paper_action_" + _variant)
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("cannot create output directory")
		return
	if not _require(_variant in ["normal", "compact", "reduced"], "known probe variant"):
		return
	if not _require(DisplayServer.get_name() != "headless", "probe requires a native rendered window"):
		return
	if _variant == "compact":
		_canvas = Vector2i(960, 540)
	var data_dir := _output.path_join("userdata")
	if not _require(DirAccess.make_dir_recursive_absolute(data_dir) == OK, "isolated data directory exists"):
		return
	for key: String in ["REVERB_SAVE", "REVERB_RUN_LOG", "REVERB_SETTINGS", "REVERB_FEEDBACK_LOG", "REVERB_SUSPEND"]:
		var path := data_dir.path_join(key.to_lower() + ".json")
		OS.set_environment(key, path)
		_isolated.append(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	OS.set_environment("REVERB_LANG", "zh" if _variant == "compact" else "en")
	root.size = _canvas
	root.content_scale_size = _canvas
	DisplayServer.window_set_size(_canvas)
	# Counters still observe the real GameAudio routes; the recorded movie is silent.
	AudioServer.set_bus_mute(0, true)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_native_frames += 1
	if not _failed and Time.get_ticks_msec() - _started > DEADLINE_MSEC:
		_fail("deadline exceeded before native action evidence completed")
	return false


func _run() -> void:
	for _index in 180:
		if _main.character_select != null and _main.character_select.visible:
			break
		await process_frame
	if not _require(_main.character_select != null, "real Main reached character selection"):
		return
	root.size = _canvas
	root.content_scale_size = _canvas
	DisplayServer.window_set_size(_canvas)
	for row: Dictionary in WEAPONS:
		_begin_case(row["weapon"])
		_add_target(_main.sim.player.pos + Vector2(100.0, 0.0))
		var result: Dictionary = await _run_case(String(row["name"]), "weapon", CASE_FRAMES)
		if result.is_empty():
			return
		result["weapon_id"] = String(row["weapon"])
		result["retirement_kind"] = String(EchoSystem.kind_for_style(Content.weapon(row["weapon"]).attack_style))
		if not _require(int(_case_events.get("shot", 0)) > 0 and int(_case_events.get("damage", 0)) > 0
				and bool(_proofs.get("shot_view", false)) and bool(_proofs.get("damage_view", false)),
				"%s real Combat attack and contact reached Main's ArenaView" % row["name"]):
			return
		(_summary["cases"] as Array).append(result)
	_begin_case(&"pistol")
	_add_stationary_copy(&"pistol", 60.0)
	_disable_weapons()
	_main.sim.player.hp = 140.0
	var repairs: Dictionary = await _run_case("repair", "repair", CASE_FRAMES)
	if repairs.is_empty() or not _require(int(_case_events.get("support.repair", 0)) > 0
			and int(_case_events.get("support.damage", 0)) > 0 and bool(_proofs.get("support_view", false))
			and int(_case_events.get("world.machine_repaired", 0)) > 0,
			"real finite station damage and useful repairs reached the bound view"):
		return
	(_summary["cases"] as Array).append(repairs)
	_begin_case(&"pistol")
	_disable_weapons()
	for item: Dictionary in _main.sim.interactables:
		if item["id"] == &"machine_0":
			_main.sim.player.pos = item["pos"] + Vector2(0.0, 80.0)
			_add_target(item["pos"] + Vector2(75.0, 0.0))
			break
	var machine: Dictionary = await _run_case("machine", "machine", 120)
	if machine.is_empty() or not _require(int(_case_events.get("world.interaction_result", 0)) > 0
			and bool(_proofs.get("world_view", false)) and int(_case_events.get("damage", 0)) > 0,
			"real machine switch, warning and impact reached view and model"):
		return
	(_summary["cases"] as Array).append(machine)
	_begin_case(&"pistol")
	_add_stationary_copy(&"stamp", 70.0)
	_disable_weapons()
	_add_target(_main.sim.player.pos + Vector2(125.0, 30.0))
	var retirement: Dictionary = await _run_case("retirement", "retirement", CASE_FRAMES)
	if retirement.is_empty() or not _require(int(_case_events.get("retirement", 0)) == 1
			and _main.sim.bank.find_uid(_retire_uid) == null and int(_case_events.get("damage", 0)) > 0
			and bool(_proofs.get("retirement_view", false)),
			"real selected copy paid for one retirement skill and left the bank"):
		return
	(_summary["cases"] as Array).append(retirement)
	_begin_case(&"pistol")
	_disable_weapons()
	var shield: Dictionary = await _run_case("shield", "shield", CASE_FRAMES)
	if shield.is_empty() or not _require(bool(_proofs.get("full_block", false)) and bool(_proofs.get("partial_hurt", false)),
			"complete shield block and partial HP damage produce different real feedback"):
		return
	(_summary["cases"] as Array).append(shield)
	_begin_case(&"pistol")
	_main.sim.player.add_weapon(Content.weapon(&"pistol"))
	_main.sim.player.cooldowns = [0.0, 0.35]
	_add_target(_main.sim.player.pos + Vector2(100.0, 0.0))
	var duplicates: Dictionary = await _run_case("duplicate_slots", "duplicates", CASE_FRAMES)
	if duplicates.is_empty() or not _require(bool(_proofs.get("first_slot_only", false))
			and _second_slot >= 0, "same-ID guns really fired staggered slots without shared recoil"):
		return
	duplicates["shot_slots"] = _shot_rows.duplicate(true)
	(_summary["cases"] as Array).append(duplicates)
	_begin_case(&"smg")
	_add_target(_main.sim.player.pos + Vector2(170.0, 0.0))
	var gait: Dictionary = await _run_case("gait", "gait", 165)
	if gait.is_empty() or not _require(_gait_rows.size() == 4
			and bool(_gait_rows[0]["moving"]) and bool(_gait_rows[1]["moving"])
			and float(_gait_rows[0]["x"]) > float(_gait_rows[1]["x"])
			and not bool(_gait_rows[2]["moving"]) and not bool(_gait_rows[3]["moving"])
			and is_equal_approx(float(_gait_rows[2]["gait_phase"]), float(_gait_rows[3]["gait_phase"]))
			and bool(_proofs.get("gait_shot_in_motion", false)),
			"real displacement drives both walking directions, shots preserve gait and stopped feet settle"):
		return
	gait["movement_samples"] = _gait_rows.duplicate(true)
	gait["movement_recipe"] = [{"first_frame": 0, "last_frame": 59, "direction": [0.35, 0.0]},
		{"first_frame": 60, "last_frame": 119, "direction": [-0.35, 0.0]},
		{"first_frame": 120, "last_frame": 164, "direction": [0.0, 0.0]}]
	(_summary["cases"] as Array).append(gait)
	_summary["success"] = true
	var commit := OS.get_environment("REVERB_BUILD_COMMIT").strip_edges()
	if commit.is_empty():
		commit = str(ProjectSettings.get_setting("application/config/build_commit", "")).strip_edges()
	if not _require(not commit.is_empty(), "source evidence names the actual CI commit"):
		return
	_summary["commit"] = commit
	_summary["variant"] = _variant
	_summary["language"] = Loc.lang
	_summary["canvas"] = [_canvas.x, _canvas.y]
	_summary["isolated_data_paths"] = _isolated.duplicate()
	_summary["environment"] = {"godot": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "native_frames": _native_frames}
	_summary["capture"] = {"fps": 60, "speed": 1.0, "audio": "master muted; real route counters checked",
		"simulation": "one real Sim.step(1/60) per native rendered frame; Main physics suppressed",
		"visual_clock": "normal native engine clock, including each screenshot frame",
		"staging": "authored positions, stationary high-HP targets, isolated scripted fixture",
		"scope": "presentation evidence; not human playtesting, balance or a normal campaign completion",
		"movie": "continuous CLI --write-movie recording; no skipped or slowed simulation steps"}
	if not _write_summary():
		return
	_main.audio.stop_all()
	_main.queue_free()
	_main = null
	print("paper action probe: OK (%s, %d cases)" % [_variant, (_summary["cases"] as Array).size()])
	quit()


func _begin_case(weapon_id: StringName) -> void:
	_main.new_run(20261031, &"looper", 0)
	_main.paused = true
	_main.pause_ui.close()
	_main._view.set_paused(false)
	_main.audio.set_paused(false)
	_main.settings.reduced_effects = _variant == "reduced"
	_main._apply_reduced_effects()
	var sim: Sim = _main.sim
	sim.player.pos = Vector2(1240.0, 680.0)
	sim.player.stats.values[Stats.MAX_HP] = 200.0
	sim.player.hp = 200.0
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	sim.player.add_weapon(Content.weapon(weapon_id))
	sim.wave_duration = 60.0
	sim._plan.clear()
	sim._plan_idx = 0
	sim.enemies.clear()
	sim.pending.clear()
	sim.projectiles.clear()
	sim.grid.clear()
	_case_frame = -1
	_first_action = -1
	_first_contact = -1
	_second_slot = -1
	_support_uid = 0
	_retire_uid = 0
	_repair_pad = Vector2.INF
	_repair_body = Vector2.INF
	_current_mode = ""
	_gait_rows.clear()
	_case_events.clear()
	_proofs.clear()
	_peaks.clear()
	_samples.clear()
	_shot_rows.clear()
	sim.shot_fired_info.connect(_on_shot)
	sim.damage_event.connect(_on_damage)
	sim.player_hurt_info.connect(_on_hurt)
	sim.echo_retired.connect(_on_retirement)
	sim.world_event.connect(_on_world)
	sim.support_event.connect(_on_support)


func _disable_weapons() -> void:
	var sim: Sim = _main.sim
	for index in sim.player.cooldowns.size():
		sim.player.cooldowns[index] = 1000.0
	for actor: EchoActor in sim.echoes:
		for index in actor.cooldowns.size():
			actor.cooldowns[index] = 1000.0


func _add_stationary_copy(weapon_id: StringName, condition: float) -> void:
	var sim: Sim = _main.sim
	var take := EchoTake.new()
	take.wave = 1
	take.condition = condition
	take.weapons.append(Content.weapon(weapon_id))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	for _index in 361:
		take.samples.append(sim.player.pos + Vector2(65.0, 20.0))
	sim.bank.add(take)
	_retire_uid = take.uid
	# The real wave-start path creates/deploys the Echo and notifies the bound view.
	sim.start_wave(2)
	sim._plan.clear()
	sim._plan_idx = 0
	sim.wave_duration = 60.0


func _add_target(pos: Vector2) -> void:
	var sim: Sim = _main.sim
	var arrival := PendingSpawn.new()
	arrival.def = Content.enemy(&"grunt")
	arrival.pos = pos
	if not _require(sim._materialize(arrival), "scripted target materialized through real Sim admission"):
		return
	var enemy: EnemyState = sim.enemies.back()
	enemy.max_hp = 50000.0
	enemy.hp = enemy.max_hp
	enemy.speed = 0.0
	enemy.damage = 0.0


func _run_case(name: String, mode: String, frames: int) -> Dictionary:
	if _failed:
		return {}
	var sim: Sim = _main.sim
	_current_mode = mode
	var audio_before := _audio_total()
	var movie_start := _native_frames
	var first_rng := str(sim.rng.state)
	var first_hazard := str(sim.hazard_rng.state)
	for frame in frames:
		if _failed:
			return {}
		_case_frame = frame
		if not _trigger(mode, frame):
			return {}
		var movement := Vector2.ZERO
		if mode == "gait":
			movement = Vector2.RIGHT * 0.35 if frame < 60 else (Vector2.LEFT * 0.35 if frame < 120 else Vector2.ZERO)
		sim.step(DT, movement)
		var read_only_before: Dictionary = {}
		var rng_before := sim.rng.state
		var hazard_before := sim.hazard_rng.state
		if frame == 30:
			read_only_before = RunSnapshot.capture(sim)
			if not _require(not read_only_before.is_empty(), "%s snapshot captures actual fixture state" % name):
				return {}
			var restored := RunSnapshot.restore(read_only_before)
			if not _require(restored != null and RunSnapshot.capture(restored) == read_only_before,
					"%s fixture is valid under the strict saved-state schema" % name):
				return {}
			# Zero extra presentation time: normal _process + actual draw still run
			# below, and the continuous movie never pauses to manufacture a pose.
			_main._view._process(0.0)
		_main._view.queue_redraw()
		_main.hud.queue_redraw()
		_update_peaks()
		await process_frame
		await RenderingServer.frame_post_draw
		if _failed:
			return {}
		if mode == "repair" and frame == 48:
			var camera: Rect2 = _main._view.camera_profile()["world_rect"]
			_proofs["repaired_machine_visible"] = camera.has_point(_repair_pad) and camera.has_point(_repair_body)
			if not _require(bool(_proofs["repaired_machine_visible"]),
					"camera follows the real repair action and contains the machine body and service pad"):
				return {}
		if frame == 30:
			if not _require(sim.rng.state == rng_before and sim.hazard_rng.state == hazard_before
					and RunSnapshot.capture(sim) == read_only_before,
					"%s normal view process/draw leaves the full model and both RNGs unchanged" % name):
				return {}
			(_summary["read_only_checks"] as Array).append({"case": name, "frame": frame,
				"manual_view_delta": 0.0, "native_process_and_draw": true,
				"strict_snapshot_roundtrip": true, "full_snapshot_unchanged": true,
				"rng_unchanged": true, "hazard_rng_unchanged": true})
		if not _sample_frame(name, mode, frame, frames):
			return {}
	if not _require(_samples.size() >= 4, "%s saved at least four real rendered phases" % name):
		return {}
	var audio_delta := _audio_total() - audio_before
	if not _require(audio_delta > 0, "%s real model events reached bound GameAudio" % name):
		return {}
	return {"name": name, "mode": mode, "frames": frames, "seconds": frames * DT,
		"normal_speed": true, "movie_start_frame": movie_start, "movie_end_frame": _native_frames,
		"events": _case_events.duplicate(true), "view_proofs": _proofs.duplicate(true),
		"feedback_peaks": _peaks.duplicate(true), "audio_route_delta": audio_delta,
		"screenshots": _samples.duplicate(true), "rng_before": first_rng, "rng_after": str(sim.rng.state),
		"hazard_rng_before": first_hazard, "hazard_rng_after": str(sim.hazard_rng.state)}


func _trigger(mode: String, frame: int) -> bool:
	var sim: Sim = _main.sim
	if mode == "repair":
		if frame == 8:
			if not _require(SupportSystem.spawn_weapon(sim, Content.weapon(&"repair_kit"),
					sim.player.pos + Vector2(30.0, -30.0), 0.0, -1, -1, Color.WHITE, 1),
					"fixture deploys a real finite repair station"):
				return false
			_support_uid = int(sim.support_units.back()["uid"])
		elif frame == 18:
			if not _require(SupportSystem.damage(sim, _support_uid, 5.0), "real support body receives damage"):
				return false
		elif frame == 48:
			# An actual faulty machine is stopped by the same E interaction used in game.
			for item: Dictionary in sim.interactables:
				if item["kind"] == &"repair":
					sim.player.pos = item["pos"]
					if not _require(sim.interact(), "real repair interaction stops the faulty machine"):
						return false
					_repair_pad = item["pos"]
					var machine_id := StringName(String(item["id"]).trim_prefix("repair_"))
					var machines: Array = sim.expedition["world"]["machines"]
					for index in machines.size():
						if machines[index]["id"] == machine_id:
							_repair_body = WorldArena.MACHINES[index].get_center()
							if not _require(machines[index]["status"] == &"repaired" and machines[index]["stopped"],
									"repair's canonical machine is actually repaired and stopped"):
								return false
					break
	elif mode == "machine" and frame == 8:
		if not _require(sim.interact(), "real machine interaction accepted its actual switch"):
			return false
		var started := false
		for item: Dictionary in sim.interactables:
			if item["id"] == &"machine_0":
				started = float(item["warning"]) > 0.0
		for machine: Dictionary in sim.expedition["world"]["machines"]:
			if machine["id"] == &"machine_0":
				started = started and not bool(machine["stopped"])
		_proofs["machine_started"] = started
		if not _require(started, "one actual E starts the press warning and leaves the machine operating"):
			return false
	elif mode == "retirement" and frame == 12:
		if not _require(sim.select_echo(_retire_uid) and sim.retire_selected_echo(), "real selected copy retires once"):
			return false
	elif mode == "shield":
		if frame == 10:
			sim.player.shield = 6.0
			sim._hurt_player(4.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
			_proofs["full_block"] = _main._view.event_last_data().get("kind", &"") == &"block" \
				and sim.player.hp == 200.0 and sim.player.shield == 2.0
		elif frame == 48:
			sim.player.iframes = 0.0
			sim._hurt_player(5.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
			_proofs["partial_hurt"] = _main._view.event_last_data().get("kind", &"") == &"hurt" \
				and sim.player.hp == 197.0 and sim.player.shield == 0.0
	return not _failed


func _sample_frame(name: String, mode: String, frame: int, _frames: int) -> bool:
	var labels: Array[String] = []
	if mode == "shield":
		var shield_frames := {10: "full_block", 14: "block_followthrough", 48: "partial_hp", 56: "hurt_followthrough"}
		if shield_frames.has(frame):
			labels.append(shield_frames[frame])
	elif mode == "gait":
		var gait_frames := {50: "walk_right", 110: "walk_left", 150: "settled", 164: "settled_end"}
		if gait_frames.has(frame):
			labels.append(gait_frames[frame])
			var motion: Dictionary = _main._view.motion_stats()
			var pos: Vector2 = _main.sim.player.pos
			_gait_rows.append({"frame": frame, "x": pos.x, "y": pos.y,
				"moving": bool(motion["moving"]), "gait_phase": float(motion["gait_phase"]),
				"motion_amount": float(motion["amount"]), "shots": int(_case_events.get("shot", 0))})
	else:
		if _first_action >= 0:
			if frame == _first_action:
				labels.append("release")
			if frame == _first_action + 4:
				labels.append("motion")
		if _first_contact >= 0 and frame == maxi(_first_action + 1, _first_contact):
			labels.append("contact")
		if _first_contact >= 0 and frame == maxi(_first_action + 32, _first_contact + 12):
			labels.append("result")
		if mode == "repair" and frame == 48:
			labels.append("machine_stopped")
		if mode == "duplicates" and frame == _second_slot and _second_slot >= 0:
			labels.append("second_slot")
	for label: String in labels:
		if not _samples.has(label) and not _save_frame(name, label, frame):
			return false
	return true


func _save_frame(name: String, label: String, frame: int) -> bool:
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty() and image.get_width() == _canvas.x
			and image.get_height() == _canvas.y, "%s/%s has native requested dimensions" % [name, label]):
		return false
	var filename := "%s_%s.png" % [name, label]
	if not _require(image.save_png(_output.path_join(filename)) == OK, "native frame saves without scaling"):
		return false
	var row := {"file": filename, "case_frame": frame, "native_frame": _native_frames,
		"width": image.get_width(), "height": image.get_height()}
	_samples[label] = row
	_summary["screenshots"][name + "/" + label] = row.duplicate(true)
	return true


func _on_shot(info: ShotInfo) -> void:
	_count("shot")
	if _case_frame >= 0 and _first_action < 0:
		_first_action = _case_frame
	var view: ArenaView = _main._view
	if _current_mode == "gait" and bool(view.motion_stats()["moving"]):
		_proofs["gait_shot_in_motion"] = true
	_proofs["shot_view"] = bool(_proofs.get("shot_view", false)) or int(view.feedback_counts()["muzzles"]) > 0
	_shot_rows.append({"frame": _case_frame, "slot": info.weapon_slot,
		"actor_token": info.actor_token, "weapon_id": String(info.weapon_id)})
	if info.source == -1 and info.weapon_id == &"pistol":
		if info.weapon_slot == 0 and _shot_rows.size() == 1:
			_proofs["first_slot_only"] = view.recoil_amount(-1, &"pistol", 0) > 0.0 \
				and view.recoil_amount(-1, &"pistol", 1) == 0.0
		if info.weapon_slot == 1 and _second_slot < 0:
			_second_slot = _case_frame


func _on_damage(_info: DamageInfo) -> void:
	_count("damage")
	if _case_frame >= 0 and _first_contact < 0:
		_first_contact = _case_frame
	_proofs["damage_view"] = bool(_proofs.get("damage_view", false)) \
		or int(_main._view.feedback_counts()["hits"]) > 0


func _on_hurt(_info: PlayerHurtInfo) -> void:
	_count("hurt")
	if _case_frame >= 0 and _first_action < 0:
		_first_action = _case_frame


func _on_retirement(_info: EchoRetirementInfo) -> void:
	_count("retirement")
	if _case_frame >= 0 and _first_action < 0:
		_first_action = _case_frame
	_proofs["retirement_view"] = int(_main._view.feedback_counts()["interactions"]) > 0


func _on_world(info: Dictionary) -> void:
	var kind := String(info.get("kind", &""))
	_count("world." + kind)
	if kind == "interaction_result" and bool(info.get("ok", false)):
		if _case_frame >= 0 and _first_action < 0:
			_first_action = _case_frame
		_proofs["world_view"] = bool(_proofs.get("world_view", false)) \
			or int(_main._view.feedback_counts()["interactions"]) > 0


func _on_support(info: Dictionary) -> void:
	var kind := String(info.get("kind", &""))
	_count("support." + kind)
	if _case_frame >= 0 and _first_action < 0:
		_first_action = _case_frame
	if kind == "repair" and _case_frame >= 0 and _first_contact < 0:
		_first_contact = _case_frame
	_proofs["support_view"] = bool(_proofs.get("support_view", false)) \
		or int(_main._view.feedback_counts()["interactions"]) > 0


func _count(kind: String) -> void:
	_case_events[kind] = int(_case_events.get(kind, 0)) + 1


func _update_peaks() -> void:
	var values: Dictionary = _main._view.feedback_counts()
	for key: String in values:
		_peaks[key] = maxi(int(_peaks.get(key, 0)), int(values[key]))


func _audio_total() -> int:
	var count := 0
	for cue: StringName in GameAudio.ALL_NAMES:
		count += _main.audio.play_count(cue)
	return count


func _write_summary() -> bool:
	var file := FileAccess.open(_output.path_join("paper_action_source.json"), FileAccess.WRITE)
	if file == null:
		_fail("cannot write source JSON")
		return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	return true


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_summary["success"] = false
	_summary["failure"] = message
	_summary["variant"] = _variant
	printerr("paper action probe FAILED: " + message)
	if not _output.is_empty():
		var file := FileAccess.open(_output.path_join("paper_action_source.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n")
			file.close()
	quit(1)
