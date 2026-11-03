extends SceneTree
# Short, audible native evidence of the actual model/view/audio paths. Fixtures
# author positions, routes and durability; they do not emit presentation signals.
# CI: --resolution 1280x720 --fixed-fps 60 --write-movie <output>/experience.avi
# --script res://tools/experience_probe.gd -- --output=<dir> --variant=normal

const DT := 1.0 / 60.0
const DEADLINE_MSEC := 240000
const MAX_MOVIE_FRAMES := 960
const SEED := 20261103

var _main: Node
var _output := ""
var _variant := "normal"
var _canvas := Vector2i(1280, 720)
var _failed := false
var _native_frames := 0
var _started := Time.get_ticks_msec()
var _case := ""
var _frame := -1
var _events: Array[Dictionary] = []
var _counts: Dictionary = {}
var _checks: Array[Dictionary] = []
var _screenshots: Dictionary = {}
var _cases: Array[Dictionary] = []
var _routes: Array[Dictionary] = []
var _audio_before: Dictionary = {}
var _isolated: Array[String] = []
var _route_uids: Array[int] = []
var _retire_uid := 0
var _target: EnemyState
var _worker_id: StringName = &""
var _worker_from := Vector2.ZERO
var _worker_safe := Vector2.ZERO
var _summary: Dictionary = {"success": false, "failed": true, "source": "scripted fixture"}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
		elif argument.begins_with("--variant="):
			_variant = argument.trim_prefix("--variant=")
	if _output.is_empty():
		_output = ProjectSettings.globalize_path("res://shots/experience_" + _variant)
	if not _require(DirAccess.make_dir_recursive_absolute(_output) == OK, "output directory exists"):
		return
	if not _require(_variant in ["normal", "compact", "reduced"], "known native variant"):
		return
	if not _require(DisplayServer.get_name() != "headless", "native rendering is required"):
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
	Loc.lang = "zh" if _variant == "compact" else "en"
	OS.set_environment("REVERB_LANG", Loc.lang)
	root.size = _canvas
	root.content_scale_size = _canvas
	DisplayServer.window_set_size(_canvas)
	# MovieMaker records this real master mix. Unlike paper_action_probe this
	# evidence deliberately leaves the bus audible, including music and ducking.
	AudioServer.set_bus_mute(0, false)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_native_frames += 1
	if not _failed and Time.get_ticks_msec() - _started > DEADLINE_MSEC:
		_fail("native experience evidence deadline exceeded")
	return false


func _run() -> void:
	for _index in 120:
		if _main.character_select != null and _main.character_select.visible:
			break
		await process_frame
	if not _require(_main.character_select != null and _main.character_select.visible,
			"actual Main reached character selection"):
		return
	root.size = _canvas
	root.content_scale_size = _canvas
	DisplayServer.window_set_size(_canvas)
	if not (await _route_case()):
		return
	if not (await _combo_case()):
		return
	if not (await _rescue_case()):
		return
	if not (await _retirement_case()):
		return
	if not (await _early_clear_case()):
		return
	var commit := OS.get_environment("REVERB_BUILD_COMMIT").strip_edges()
	if commit.is_empty():
		commit = str(ProjectSettings.get_setting("application/config/build_commit", "")).strip_edges()
	if not _require(not commit.is_empty(), "source JSON identifies the CI commit"):
		return
	_summary.merge({"commit": commit, "variant": _variant, "language": Loc.lang,
		"canvas": [_canvas.x, _canvas.y], "cases": _cases, "screenshots": _screenshots,
		"event_timeline": _events, "read_only_checks": _checks, "route_evidence": _routes,
		"isolated_data_paths": _isolated, "environment": {"godot": Engine.get_version_info(),
			"renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name()},
		"capture": {"fps": 60, "speed": 1.0, "audio": "real unmuted GameAudio master mix",
			"simulation": "one Sim.step(1/60) per native frame; Main physics suppressed",
			"visual_clock": "native process plus actual frame_post_draw; no manual force_draw",
			"staging": "authored L-shaped take routes and phase offsets; stationary nonlethal high-HP targets; combo cooldown stagger; skill charge starts at 96 then an actual scrap pickup adds 4; final-cohort case stages the earlier plan as consumed",
			"scope": "presentation fixture, not human input or normal campaign/balance evidence",
			"route_forecast": "forecast compared to 120 actual future Sim steps on a strict restored copy; original state remains unchanged",
			"reduced": _variant == "reduced", "movie": "continuous native CLI MovieMaker including audio"}}, true)
	_main._detach_presentation_session()
	_main.audio.stop_all()
	if not _require(_main.sim == null and _main._view.sim == null and _main.hud.sim == null,
			"teardown disconnects model and presentation"):
		return
	_main.queue_free()
	_main = null
	await process_frame
	await process_frame
	_summary["native_frames"] = _native_frames
	_summary["teardown"] = {"detached": true, "freed": true, "waited_frames": 2}
	if not _require(_native_frames <= MAX_MOVIE_FRAMES, "continuous native movie stays within sixteen seconds"):
		return
	_summary["success"] = true
	_summary["failed"] = false
	if not _write_source():
		return
	print("experience probe: OK (%s, %d frames, %d PNGs, audible audio)" % [
		_variant, _native_frames, _screenshots.size()])
	quit()


func _begin_case(name: String, role: StringName, weapons: Array[StringName]) -> void:
	_case = name
	_frame = -1
	_counts.clear()
	_main.new_run(SEED, role, 0)
	_main.paused = true
	_main.pause_ui.close()
	_main._view.set_paused(false)
	_main.audio.set_paused(false)
	_main.settings.reduced_effects = _variant == "reduced"
	_main.settings.volume = 0.80
	_main.settings.music_volume = 0.45
	_main.settings.effects_volume = 0.85
	_main._apply_audio()
	_main._apply_reduced_effects()
	AudioServer.set_bus_mute(0, false)
	var sim: Sim = _main.sim
	sim.player.pos = Vector2(1240.0, 680.0)
	sim.player.stats.values[Stats.MAX_HP] = 200.0
	sim.player.hp = 200.0
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	for weapon: StringName in weapons:
		sim.player.add_weapon(Content.weapon(weapon))
	_clear_budget(sim)
	sim.shot_fired_info.connect(_on_shot)
	sim.combo_triggered.connect(_on_combo)
	sim.echo_retired.connect(_on_retirement)
	sim.world_event.connect(_on_world)
	sim.material_collected.connect(_on_pickup)
	sim.wave_ended.connect(_on_end)
	_target = null
	_worker_id = &""
	_retire_uid = 0
	_audio_before = _audio_counts()


func _clear_budget(sim: Sim) -> void:
	sim._plan.clear()
	sim._plan_idx = 0
	sim.wave_duration = 60.0
	sim.enemies.clear()
	sim.pending.clear()
	sim.projectiles.clear()
	sim.grid.clear()


func _disable_weapons() -> void:
	var sim: Sim = _main.sim
	for index in sim.player.cooldowns.size():
		sim.player.cooldowns[index] = 1000.0
	for actor: EchoActor in sim.echoes:
		for index in actor.cooldowns.size():
			actor.cooldowns[index] = 1000.0


func _add_target(pos: Vector2, hp: float = 50000.0) -> EnemyState:
	var sim: Sim = _main.sim
	var arrival := PendingSpawn.new()
	arrival.def = Content.enemy(&"grunt")
	arrival.pos = pos
	if not _require(sim._materialize(arrival), "fixture body enters through real spawn admission"):
		return null
	var enemy: EnemyState = sim.enemies.back()
	enemy.max_hp = hp
	enemy.hp = hp
	enemy.speed = 0.0
	enemy.damage = 0.0
	return enemy


func _route_case() -> bool:
	_begin_case("eight_routes", &"conductor", [&"stapler"])
	var sim: Sim = _main.sim
	sim.player.stats.values[Stats.ECHO_SLOTS] = 8.0
	sim.bank.takes.clear()
	_route_uids.clear()
	for index in 8:
		var take := EchoTake.new()
		take.wave = 1
		take.stats = sim.player.stats.copy()
		take.condition = 98.0 - float(index) * 5.0
		take.weapons.append(Content.weapon(&"stamp" if index % 2 else &"stapler"))
		take.levels.append(0)
		var start := Vector2(1040.0 + float(index % 4) * 112.0, 570.0 + float(index / 4) * 152.0)
		# A recorded right-angle route has a real cusp on ping-pong playback.
		for sample in 37:
			var point := start + Vector2(float(mini(sample, 18)) * 6.0,
					float(maxi(0, sample - 18)) * 4.0)
			take.samples.append(point)
		sim.bank.add(take)
		_route_uids.append(take.uid)
	sim.start_wave(2)
	_clear_budget(sim)
	_add_target(sim.player.pos + Vector2(220.0, 80.0))
	if _failed:
		return false
	for index in sim.echoes.size():
		sim.echoes[index].t = float(index) * 0.11
		sim.echoes[index].pos = sim.echoes[index].take.position_at(sim.echoes[index].t)
	_disable_weapons()
	if not _require(sim.echoes.size() == 8 and sim.select_echo(_route_uids[0]), "eight real selected/other copies exist"):
		return false
	var first := _native_frames
	var held := Vector2.ZERO
	for frame in 330:
		_frame = frame
		if frame == 24:
			held = sim.echoes[0].pos
			if not _require(sim.activate_character_skill(), "real conductor activation establishes the hold"):
				return false
		var label := ""
		if frame == 18:
			label = "eight_future_routes"
		elif frame == 204:
			label = "hold_release_inside_two_seconds"
		elif frame == 274:
			label = "hold_released"
		if not (await _native_step(label, not label.is_empty())):
			return false
		if frame == 204 and not _require(sim.echoes[0].pos.is_equal_approx(held),
				"selected copy remains at its actual held position"):
			return false
		if frame == 274 and not _require(float(sim.role_effects.get("anchor_left", 0.0)) <= 0.0
				and not sim.echoes[0].pos.is_equal_approx(held), "copy moves again after the real hold expires"):
			return false
	return _finish_case(first, {"hold": "real conductor 4s; native frames24..263",
		"route_count": sim.echoes.size(), "duration": 1.2, "phase_offsets": "index * 0.11s"})


func _combo_case() -> bool:
	_begin_case("combo_and_charge", &"solo", [&"stapler", &"stamp"])
	var sim: Sim = _main.sim
	_target = _add_target(sim.player.pos + Vector2(80.0, 0.0))
	if _target == null:
		return false
	sim.character_energy = 96.0
	_disable_weapons()
	var first := _native_frames
	for frame in 180:
		_frame = frame
		if frame == 12:
			sim.player.cooldowns[0] = 0.0
		elif frame == 35:
			if not _require(_target.pin_left > 0.0, "real stapler contact pinned the target before the press"):
				return false
			sim.player.cooldowns[1] = 0.0
		elif frame == 82:
			# The fixture starts one material short. The real collection function
			# performs the threshold crossing and emits the pickup event.
			var pickup := Pickup.new()
			pickup.pos = sim.player.pos
			pickup.value = 1
			sim.pickups.append(pickup)
			if not _require(sim.collect_pickup(pickup) and CharacterSkills.is_charged(sim),
					"actual scrap collection charges the skill from96 to100"):
				return false
		elif frame == 124:
			if not _require(sim.activate_character_skill(), "the newly charged real skill activates once"):
				return false
		var label := "pin_status" if frame == 28 else ""
		if frame == 62:
			label = "combo_contact"
		elif frame == 84:
			label = "skill_charged"
		elif frame == 130:
			label = "charged_skill_release"
		if not (await _native_step(label)):
			return false
	if not _require(int(_counts.get("combo", 0)) > 0 and int(_counts.get("pickup", 0)) > 0
			and int(_counts.get("skill", 0)) == 1, "real combo, pickup and skill events all occurred"):
		return false
	return _finish_case(first, {"energy_staging": 96.0, "pickup_value": 1,
		"combo": "real auto-fire stapler then stamp; staged cooldown offsets12/35"})


func _rescue_case() -> bool:
	_begin_case("worker_rescue", &"looper", [&"pistol"])
	var sim: Sim = _main.sim
	_disable_weapons()
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			_worker_id = item["id"]
			_worker_from = item["pos"]
			sim.player.pos = _worker_from + Vector2(-50.0, 0.0)
			break
	if not _require(_worker_id != &"", "natural endangered worker exists"):
		return false
	var first := _native_frames
	for frame in 96:
		_frame = frame
		if frame == 12:
			if not _require(sim.interact(), "actual nearby interaction rescues the worker"):
				return false
			var worker := Expedition._worker(sim, _worker_id)
			_worker_safe = worker.get("pos", Vector2.INF)
			if not _require(worker.get("state", &"") == &"safe" and _worker_safe.is_finite(),
					"worker is registered at its canonical safe position"):
				return false
		elif frame == 50:
			# Registry and danger lane do not fit one camera. Disclose this
			# authored inspection placement instead of pretending player travel.
			sim.player.pos = _worker_safe + Vector2(80.0, -10.0)
		var label := "rescue_contact" if frame == 16 else ("worker_safe" if frame == 58 else "")
		if not (await _native_step(label)):
			return false
	if not _require(int(_counts.get("worker_saved", 0)) == 1, "one actual rescue event"):
		return false
	return _finish_case(first, {"worker": String(_worker_id), "from": _point(_worker_from),
		"safe": _point(_worker_safe), "camera_inspection_at_frame": 50})


func _retirement_case() -> bool:
	_begin_case("active_retirement", &"looper", [&"pistol"])
	var sim: Sim = _main.sim
	var take := EchoTake.new()
	take.wave = 1
	take.condition = 65.0
	take.stats = sim.player.stats.copy()
	take.weapons.append(Content.weapon(&"stamp"))
	take.levels.append(0)
	for _index in 61:
		take.samples.append(sim.player.pos + Vector2(80.0, 20.0))
	sim.bank.add(take)
	_retire_uid = take.uid
	sim.start_wave(2)
	_clear_budget(sim)
	_target = _add_target(sim.player.pos + Vector2(150.0, 20.0))
	if _target == null:
		return false
	_disable_weapons()
	var first := _native_frames
	for frame in 108:
		_frame = frame
		if frame == 18 and not _require(sim.select_echo(_retire_uid) and sim.retire_selected_echo(),
				"actual selected copy is paid for the active retirement"):
			return false
		var label := "selected_before_retirement" if frame == 10 else ""
		if frame == 22:
			label = "retirement_accent"
		elif frame == 48:
			label = "retirement_result"
		if not (await _native_step(label)):
			return false
	if not _require(int(_counts.get("retire", 0)) == 1 and sim.bank.find_uid(_retire_uid) == null,
			"active retirement removed the exact source UID once"):
		return false
	return _finish_case(first, {"uid": _retire_uid, "kind": "stamp", "actual_target_hp": _target.hp})


func _early_clear_case() -> bool:
	_begin_case("finite_assault_close", &"looper", [&"pistol"])
	var sim: Sim = _main.sim
	sim.start_wave(2)
	# This short close-up stages the preceding cohorts as already consumed,
	# retaining the actual final-body death, drops, settlement and shop paths.
	sim._plan_idx = sim._plan.size()
	_target = _add_target(sim.player.pos + Vector2(80.0, 0.0), 8.0)
	if _target == null:
		return false
	var first := _native_frames
	var ended_time := -1.0
	var shop_opened := false
	for frame in 96:
		_frame = frame
		if sim.phase == Sim.Phase.SHOP and ended_time < 0.0:
			ended_time = sim.wave_time
			_main._sync_phase()
			_main.paused = true
			_main._view.set_paused(false)
			_main.audio.set_paused(false)
		if sim.phase == Sim.Phase.SHOP and not shop_opened and _main._shop_delay > 0.0:
			_main._shop_delay = maxf(0.0, _main._shop_delay - DT)
			if _main._shop_delay <= 0.0:
				_main._open_shop()
				shop_opened = true
		var label := "last_threat" if frame == 0 else ("early_shop" if frame == 90 else "")
		if not (await _native_step(label)):
			return false
	if not _require(sim.phase == Sim.Phase.SHOP and ended_time > 0.0 and ended_time < sim.wave_duration
			and int(_counts.get("wave_ended", 0)) == 1 and shop_opened and _main.shop_ui.visible,
			"last real body ends the finite encounter early and the real shop opens once"):
		return false
	return _finish_case(first, {"staging": "previous finite cohorts staged as consumed, one last8HP body",
		"ended_at": ended_time, "survival_deadline": sim.wave_duration, "shop_visible": shop_opened,
		"encounter": sim.encounter_profile().duplicate(true)})


func _native_step(label: String = "", check_routes: bool = false) -> bool:
	if _failed:
		return false
	var sim: Sim = _main.sim
	sim.step(DT, Vector2.ZERO)
	var before: Dictionary = {}
	var rng := sim.rng.state
	var hazard := sim.hazard_rng.state
	if not label.is_empty():
		before = RunSnapshot.capture(sim)
		if not _require(not before.is_empty(), "strict fixture snapshot exists: " + RunSnapshot.last_error):
			return false
		var restored := RunSnapshot.restore(before)
		if not _require(restored != null and RunSnapshot.capture(restored) == before,
				"strict fixture snapshot round-trips before actual draw: " + RunSnapshot.last_error):
			return false
		if check_routes and not _check_routes(before):
			return false
		_main._view._process(0.0)
	_main._view.queue_redraw()
	_main.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if _failed:
		return false
	if not label.is_empty():
		if not _require(sim.rng.state == rng and sim.hazard_rng.state == hazard
				and RunSnapshot.capture(sim) == before, "native process/draw preserves full model and both RNGs"):
			return false
		_checks.append({"case": _case, "case_frame": _frame, "strict_roundtrip": true,
			"full_snapshot_unchanged": true, "rng_unchanged": true, "hazard_rng_unchanged": true})
		if not _save_frame(label):
			return false
	return true


func _check_routes(before: Dictionary) -> bool:
	var sim: Sim = _main.sim
	var clip: Rect2 = _main._view.camera_profile()["world_rect"]
	var all_profiles: Array[Dictionary] = _main._view.future_path_profiles()
	if not _require(all_profiles.size() == sim.echoes.size() and all_profiles.size() == 8,
			"all eight deployed copies expose a real bounded forecast"):
		return false
	var restored := RunSnapshot.restore(before)
	if not _require(restored != null, "future simulation clone restores"):
		return false
	var data: Array[Dictionary] = []
	for actor: EchoActor in sim.echoes:
		var forecast := EchoPathPreview.snapshot(actor, sim, clip, actor.take.uid == sim.selected_echo_uid, _variant == "reduced")
		if not _require(bool(forecast["valid"]) and float(forecast["horizon"]) > 1.99,
				"nonexpiring route forecasts the full two-second horizon"):
			return false
		data.append(forecast)
	var maximum_error := 0.0
	for step in 120:
		restored.step(DT, Vector2.ZERO)
		for forecast: Dictionary in data:
			var uid := int(forecast["uid"])
			var actual := Vector2.INF
			for actor: EchoActor in restored.echoes:
				if actor.take.uid == uid:
					actual = actor.pos
			var expected := _forecast_at(forecast, float(step + 1) * DT)
			var error := actual.distance_to(expected)
			maximum_error = maxf(maximum_error, error)
			if not _require(actual.is_finite() and error < 0.05, "forecast matches actual future simulation through holds, corners and return cusps"):
				return false
	var rows: Array[Dictionary] = []
	for forecast: Dictionary in data:
		var points: Array = []
		for point: Vector2 in forecast["centerline"]:
			points.append(_point(point))
		rows.append({"uid": forecast["uid"], "selected": forecast["selected"],
			"horizon": forecast["horizon"], "centerline": points, "times": Array(forecast["times"]),
			"breaks": Array(forecast["breaks"]), "draw_segment_points": (forecast["segments"] as PackedVector2Array).size()})
	_routes.append({"case_frame": _frame, "count": rows.size(), "clip": [_point(clip.position), _point(clip.size)],
		"profiles": rows, "actual_future_steps": 120, "maximum_position_error": maximum_error,
		"hold_left": float(sim.role_effects.get("anchor_left", 0.0))})
	return _require(RunSnapshot.capture(sim) == before, "route forecasting and cloned future steps leave original state unchanged")


func _forecast_at(forecast: Dictionary, time: float) -> Vector2:
	var points: PackedVector2Array = forecast["centerline"]
	var times: PackedFloat64Array = forecast["times"]
	for index in range(1, times.size()):
		if time <= times[index] + 0.000001:
			var fraction := clampf((time - times[index - 1]) / maxf(0.000001, times[index] - times[index - 1]), 0.0, 1.0)
			return points[index - 1].lerp(points[index], fraction)
	return points[points.size() - 1]


func _finish_case(first: int, staging: Dictionary) -> bool:
	if not _require(not AudioServer.is_bus_mute(0) and not _main.audio.is_paused()
			and bool(_main.audio.binding_state()["sim_bound"]), "live GameAudio remains bound, unpaused and audible"):
		return false
	var audio_after := _audio_counts()
	var audio_delta := 0
	for cue: String in audio_after:
		audio_delta += int(audio_after[cue]) - int(_audio_before.get(cue, 0))
	if not _require(audio_delta > 0, "real case events reached bound GameAudio routes"):
		return false
	_cases.append({"name": _case, "first_native_frame": first, "last_native_frame": _native_frames,
		"frames": _native_frames - first, "staging": staging, "events": _counts.duplicate(true),
		"audio_play_counts_before": _audio_before.duplicate(true), "audio_play_counts_after": audio_after,
		"audio_route_delta": audio_delta,
		"audio": _main.audio.feedback_last_data(), "music": _main.audio.music_state(),
		"moment": _moment_row(), "encounter": _main.sim.encounter_profile().duplicate(true)})
	return true


func _audio_counts() -> Dictionary:
	var counts: Dictionary = {}
	for cue: StringName in GameAudio.ALL_NAMES:
		counts[String(cue)] = _main.audio.play_count(cue)
	return counts


func _save_frame(label: String) -> bool:
	var expected_moment := {"combo_contact": &"combo", "skill_charged": &"ready",
		"charged_skill_release": &"skill", "rescue_contact": &"rescue", "retirement_accent": &"retire"}
	if expected_moment.has(label):
		var actual: Dictionary = _main._view._moment.snapshot()
		if not _require(not actual.is_empty() and actual.get("kind", &"") == expected_moment[label],
				"actual successful event still owns its local native visual accent: " + label):
			return false
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty() and image.get_width() == _canvas.x
			and image.get_height() == _canvas.y, "capture has native requested dimensions"):
		return false
	var filename := _case + "_" + label + ".png"
	if not _require(image.save_png(_output.path_join(filename)) == OK, "native PNG saves without rescaling"):
		return false
	_screenshots[_case + "/" + label] = {"file": filename, "case_frame": _frame,
		"native_frame": _native_frames, "width": image.get_width(), "height": image.get_height(),
		"moment": _moment_row(), "audio": _main.audio.feedback_last_data(),
		"view_feedback": _main._view.feedback_counts().duplicate(true)}
	return true


func _moment_row() -> Dictionary:
	var mark: Dictionary = _main._view._moment.snapshot()
	if mark.is_empty():
		return {}
	return {"kind": String(mark["kind"]), "pos": _point(mark["pos"]),
		"priority": mark["priority"], "progress": mark["progress"]}


func _event(kind: String, fields: Dictionary = {}) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	var row := {"case": _case, "kind": kind, "case_frame": _frame, "native_frame": _native_frames,
		"audio": _main.audio.feedback_last_data(), "moment": _moment_row()}
	row.merge(fields)
	_events.append(row)


func _on_shot(info: ShotInfo) -> void:
	_event("shot", {"weapon": String(info.weapon_id), "source": info.source,
		"actor_token": info.actor_token, "sequence": info.sequence})


func _on_combo(info: ComboInfo) -> void:
	if not _require(info.affected > 0 and info.bonus_damage > 0.0, "real combo has affected bodies and positive bonus"):
		return
	_event("combo", info.to_dict())


func _on_retirement(info: EchoRetirementInfo) -> void:
	if not _require(info.reason == EchoRetirementInfo.ACTIVE and not info.exhausted,
			"native active-retirement fixture did not substitute exhaustion"):
		return
	_event("retire", {"uid": info.uid, "skill": String(info.kind), "reason": String(info.reason), "pos": _point(info.pos)})


func _on_world(info: Dictionary) -> void:
	var kind := String(info.get("kind", &""))
	if kind == "character_skill" and bool(info.get("ok", false)):
		_event("skill", {"ability": String(info["ability"]), "selected_uid": info.get("selected_uid", 0)})
	elif kind in ["worker_saved", "machine_repaired"]:
		_event(kind, {"subject": String(info.get("subject", &"")), "pos": _point(info["pos"])})


func _on_pickup(amount: int) -> void:
	_event("pickup", {"value": amount, "character_energy": _main.sim.character_energy})


func _on_end(wave: int) -> void:
	_event("wave_ended", {"wave": wave, "wave_time": _main.sim.wave_time})


func _point(value: Vector2) -> Array:
	return [value.x, value.y]


func _write_source() -> bool:
	var file := FileAccess.open(_output.path_join("experience_source.json"), FileAccess.WRITE)
	if file == null:
		_fail("cannot write native source JSON")
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
	_summary.merge({"success": false, "failed": true, "failure": message, "variant": _variant,
		"case": _case, "case_frame": _frame, "native_frames": _native_frames,
		"event_timeline": _events, "read_only_checks": _checks, "screenshots": _screenshots,
		"route_evidence": _routes, "cases": _cases}, true)
	printerr("experience probe FAILED: " + message)
	if not _output.is_empty():
		var file := FileAccess.open(_output.path_join("experience_source.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n")
			file.close()
	quit(1)
