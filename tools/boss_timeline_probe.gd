extends SceneTree
# Actual-window final-boss timeline fixture. Run EN/ZH x normal/reduced at real time:
# REVERB_LANG=en REVERB_REDUCED_EFFECTS=0 godot --path . --max-fps 60 \
#   --disable-vsync --script res://tools/boss_timeline_probe.gd

const DEADLINE_FRAMES := 1800
const DT := 1.0 / 60.0

var _main: Node
var _frames := 0
var _failed := false
var _stage := "initialize"
var _shots_dir := ""
var _reduced := false
var _summary: Dictionary = {"source": "fixture", "timeline": [], "screenshots": {},
	"signals": {}, "diagnostics": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://boss_timeline_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://boss_timeline_probe_runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://boss_timeline_probe_feedback.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://boss_timeline_probe_settings.json")
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	_clear_fixture_files()
	Loc.reset_lang()
	_reduced = OS.get_environment("REVERB_REDUCED_EFFECTS") == "1"
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded at stage %s" % _stage)
	return false


func _run() -> void:
	if not (await _enter_run()): return
	if not (await _phase_timeline()): return
	if not (await _direct_lethal_case()): return
	if not (await _lifecycle_case()): return
	if not _title_geometry(): return
	if not (await _cleanup_case()): return
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["fixture"] = {"run_source": OS.get_environment("REVERB_RUN_SOURCE"),
		"timing": "real-time --max-fps 60", "kill_order": "original then shard"}
	if not _write_summary(): return
	print("boss timeline probe: OK")
	quit()


func _enter_run() -> bool:
	_stage = "enter"
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible: break
		await process_frame
	if not _require(_main.character_select != null, "Main reaches title"): return false
	_main.meta.unlocked[&"looper"] = true
	_main.choose_character(&"looper", 737)
	await _wait_frames(4)
	_main.paused = true
	_main.pause_ui.close()
	_main._view.set_paused(false)
	_main.audio.set_paused(false)
	_main._view.set_reduced_effects(_reduced)
	_main.shop_ui.set_reduced_effects(_reduced)
	_main.end_ui.set_reduced_effects(_reduced)
	return _require(_main.sim != null and _main._view.visible and _main.hud.visible,
			"Main exposes arena and HUD")


func _prepare_boss() -> Dictionary:
	var sim: Sim = _main.sim
	sim.player.stats.values[Stats.MAX_HP] = 100000.0
	sim.player.hp = sim.player.max_hp()
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	sim.start_wave(WaveDirector.FINAL_WAVE)
	# Keep the real final-wave boss SpawnEvent and remove regular budget enemies.
	var boss_plan: Array[SpawnEvent] = []
	for event: SpawnEvent in sim._plan:
		if event.def.is_boss: boss_plan.append(event)
	sim._plan = boss_plan
	sim._plan_idx = 0
	_main._phase = Sim.Phase.WAVE
	_main._view.bind(sim, &"looper")
	_main._view.set_reduced_effects(_reduced)
	_main.hud.bind(sim)
	_main.audio.bind(sim)
	var counts := {"spawn": 0, "phase": 0, "shard": 0, "defeated": 0,
		"enrage": 0, "silence": 0, "won": 0}
	sim.boss_spawned.connect(func(_e: EnemyState) -> void: counts["spawn"] += 1)
	sim.boss_phase_changed.connect(func(_p: int) -> void: counts["phase"] += 1)
	sim.boss_shard_spawned.connect(func(_e: EnemyState) -> void: counts["shard"] += 1)
	sim.boss_shard_defeated.connect(func(_e: EnemyState, _n: int) -> void: counts["defeated"] += 1)
	sim.boss_enraged.connect(func(_e: EnemyState) -> void: counts["enrage"] += 1)
	sim.echoes_silenced.connect(func(_d: float) -> void: counts["silence"] += 1)
	sim.run_won.connect(func() -> void: counts["won"] += 1)
	return counts


func _phase_timeline() -> bool:
	_stage = "spawn"
	var counts := _prepare_boss()
	var sim: Sim = _main.sim
	var boss_audio: int = int(_main.audio.play_count(&"boss"))
	if not (await _advance_until_boss(sim, "timeline")): return false
	if not _require(sim.boss != null and sim.boss_phase == 1 and sim.boss_alive_count() == 1
			and int(counts["spawn"]) == 1
			and int(_main.audio.play_count(&"boss")) == boss_audio + 1,
			"real final-wave SpawnEvent materializes one boss and one cue"): return false
	(sim.boss as EnemyState).speed = 0.0
	(sim.boss as EnemyState).damage = 0.0
	if not (await _capture("spawn")): return false
	_timeline("spawn", sim)

	_stage = "threshold"
	var original: EnemyState = sim.boss
	var original_max := original.max_hp
	original.hp = original_max * 0.51
	var silence_audio: int = int(_main.audio.play_count(&"silence"))
	sim.damage_enemy(original, original_max * 0.02, Vector2.ZERO, false, -1,
			Vector2.RIGHT, &"rifle", &"boss_threshold_fixture")
	if not _require(sim.boss_phase == 2 and sim.boss_total_count() == 2
			and sim.boss_alive_count() == 2 and int(counts["phase"]) == 1
			and int(counts["shard"]) == 1 and int(counts["silence"]) == 1
			and int(_main.audio.play_count(&"silence")) == silence_audio + 1
			and int(_main.audio.play_count(&"boss")) == boss_audio + 2,
			"51%-threshold hit starts phase two once with two bodies and silence"): return false
	for shard: EnemyState in sim.boss_shards:
		shard.speed = 0.0; shard.damage = 0.0
	if not (await _capture("phase_two")): return false
	_timeline("phase_two", sim)

	_stage = "original_death"
	var survivor: EnemyState = sim.boss_shards[1]
	sim.damage_enemy(original, 1000000.0, Vector2.ZERO, false, -1,
			Vector2.RIGHT, &"rifle", &"boss_original_kill_fixture")
	sim.step(DT, Vector2.ZERO)
	if not _require(original.dead and not survivor.dead and sim.phase == Sim.Phase.WAVE
			and sim.boss_alive_count() == 1 and int(counts["defeated"]) == 1
			and int(counts["enrage"]) == 1 and sim.boss_health_ratio() > 0.0
			and int(_main.audio.play_count(&"boss")) == boss_audio + 3,
			"killing original first keeps run active with combined bar survivor pip"): return false
	if not (await _capture("survivor")): return false
	_timeline("survivor", sim)

	_stage = "survivor_silence"
	sim.echo_silenced = 0.0
	sim._boss_silence_cd = 0.001
	silence_audio = int(_main.audio.play_count(&"silence"))
	var silence_count := int(counts["silence"])
	sim._boss_step(0.01)
	await _wait_frames(2)
	if not _require(int(counts["silence"]) == silence_count + 1 and sim.echo_silenced > 0.0
			and sim.boss_origin().distance_to(survivor.pos) < 0.1
			and int(_main.audio.play_count(&"silence")) == silence_audio + 1,
			"surviving body owns the next silence signal, origin and cue"): return false
	if not (await _capture("survivor_silence")): return false

	_stage = "last_death"
	var last_pos := survivor.pos
	var win_audio: int = int(_main.audio.play_count(&"win"))
	sim.damage_enemy(survivor, 1000000.0, Vector2.ZERO, false, -1,
			Vector2.RIGHT, &"rifle", &"boss_last_kill_fixture")
	sim.step(DT, Vector2.ZERO)
	_main._sync_phase()
	await _wait_frames(2)
	if not _require(sim.phase == Sim.Phase.WON and int(counts["defeated"]) == 2
			and int(counts["won"]) == 1 and sim.boss_alive_count() == 0
			and int(_main.audio.play_count(&"win")) == win_audio + 1
			and _main._view._victory_origin.distance_to(last_pos) < 0.1,
			"last body alone triggers one win and victory at its death position"): return false
	if not (await _capture("victory")): return false
	_timeline("victory", sim)
	_summary["signals"]["timeline"] = counts.duplicate()
	return true


func _direct_lethal_case() -> bool:
	_stage = "direct_lethal"
	_main.new_run(738, &"looper")
	_main.paused = true; _main.pause_ui.close(); _main._view.set_paused(false)
	_main._view.set_reduced_effects(_reduced)
	var counts := _prepare_boss()
	var sim: Sim = _main.sim
	var boss_audio: int = int(_main.audio.play_count(&"boss"))
	if not (await _advance_until_boss(sim, "direct_lethal")): return false
	if not _require(sim.boss != null, "direct-lethal fixture spawns boss"): return false
	var max_hp := sim.boss.max_hp
	sim.boss.hp = max_hp * 0.75
	sim.damage_enemy(sim.boss, max_hp, Vector2.ZERO, false, -1)
	sim.step(DT, Vector2.ZERO)
	if not _require(sim.phase == Sim.Phase.WON and sim.boss_phase == 1
			and sim.boss_total_count() == 1 and int(counts["phase"]) == 0
			and int(counts["shard"]) == 0 and int(counts["won"]) == 1
			and int(_main.audio.play_count(&"boss")) == boss_audio + 1,
			"direct lethal hit above 50% skips phase two and wins once"): return false
	if not (await _capture("direct_lethal")): return false
	_summary["signals"]["direct_lethal"] = counts.duplicate()
	return true


func _lifecycle_case() -> bool:
	_stage = "lifecycle"
	var view: ArenaView = _main._view
	var before := float(view.motion_stats().get("visual_time", 0.0))
	view.set_paused(true); _main.audio.set_paused(true); await _wait_frames(3)
	if not _require(bool(view.motion_stats().get("paused", false))
			and is_equal_approx(float(view.motion_stats().get("visual_time", -1.0)), before)
			and bool(_main.audio.is_paused()), "view and audio pause without stale timeline motion"):
		return false
	view.set_paused(false); _main.audio.set_paused(false)
	var replacement := Sim.new(739); Content.character(&"looper").apply(replacement); replacement.start_run()
	view.bind(replacement, &"looper"); _main.hud.bind(replacement); _main.audio.bind(replacement)
	if not _require(view.sim == replacement and _main.hud.sim == replacement
			and int(view.feedback_counts().get("sparks", -1)) == 0,
			"boss signals and feedback reset on presentation rebind"): return false
	view.unbind(); _main.hud.unbind(); _main.audio.bind(null)
	if not _require(view.sim == null and _main.hud.sim == null
			and not bool(_main.audio.binding_state().get("sim_bound", true)),
			"presentation surfaces release boss session bindings"): return false
	_summary["signals"]["lifecycle"] = {"pause": true, "rebind": true, "reset": true}
	return true


func _title_geometry() -> bool:
	var font := UiTheme.font()
	var rows: Array[Dictionary] = []
	var fixture := Sim.new(740)
	fixture.start_run()
	fixture.start_wave(WaveDirector.FINAL_WAVE)
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"paradox")
	spawn.pos = Sim.ARENA.get_center()
	fixture._materialize(spawn)
	var states: Array[Dictionary] = [Hud.boss_presentation_state(fixture)]
	fixture.boss.hp = fixture.boss.max_hp * 0.51
	fixture.damage_enemy(fixture.boss, fixture.boss.max_hp * 0.02,
			Vector2.ZERO, false, -1)
	states.append(Hud.boss_presentation_state(fixture))
	for state: Dictionary in states:
		var key := str(state["title_key"])
		var font_size := int(state["title_size"])
		var text := Loc.t(key)
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if not _require(size.x <= 400.0, "%s title fits HUD's 400px boss title region" % key):
			return false
		rows.append({"key": key, "text": text, "font_size": font_size,
			"width": size.x, "limit": 400, "phase2": state["phase2"]})
	_summary["geometry"] = {"titles": rows, "bar": [460, 44, 360, 8],
		"pips_start": [830, 48]}
	return true


func _cleanup_case() -> bool:
	_stage = "cleanup"
	_main.show_select(); await _wait_frames(3)
	if not _require(_main.character_select.visible and _main.sim == null
			and _main._view.sim == null and _main.hud.sim == null,
			"probe returns to title and frees boss presentation session"): return false
	_main.audio.stop_all()
	return true


func _timeline(name: String, sim: Sim) -> void:
	(_summary["timeline"] as Array).append({"stage": name, "phase": int(sim.phase),
		"boss_phase": sim.boss_phase, "total": sim.boss_total_count(),
		"alive": sim.boss_alive_count(), "ratio": sim.boss_health_ratio(),
		"origin": [sim.boss_origin().x, sim.boss_origin().y]})


func _advance_until_boss(sim: Sim, case_name: String) -> bool:
	var retained_time := 0.0
	for event: SpawnEvent in sim._plan:
		if event.def.is_boss:
			retained_time = maxf(retained_time, event.time)
	var budget := ceili((retained_time + Sim.SPAWN_TELEGRAPH + 0.5) / DT)
	budget = clampi(budget, 1, 300)
	var advanced := 0
	for _i in budget:
		sim.step(DT, Vector2.ZERO)
		advanced += 1
		await process_frame
		if sim.boss != null:
			break
	_summary["diagnostics"]["%s_spawn_wait" % case_name] = {
		"retained_event_time": retained_time,
		"telegraph": Sim.SPAWN_TELEGRAPH,
		"budget_frames": budget,
		"advanced_frames": advanced,
		"observed_wave_time": sim.wave_time,
		"boss_count": sim.boss_total_count(),
		"boss_audio_count": int(_main.audio.play_count(&"boss")),
	}
	return _require(sim.boss != null,
			"%s boss spawns within event+telegraph budget" % case_name)


func _capture(name: String) -> bool:
	_summary["diagnostics"][name] = {"stage": _stage, "frame": _frames,
		"ticks_msec": Time.get_ticks_msec(), "phase": int(_main.sim.phase),
		"boss_phase": _main.sim.boss_phase, "alive": _main.sim.boss_alive_count()}
	_main._view.queue_redraw(); _main.hud.queue_redraw(); await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty()
			and image.get_width() == 1280 and image.get_height() == 720,
			"%s is a non-empty 1280x720 frame" % name): return false
	var mode := "reduced" if _reduced else "normal"
	var filename := "boss_%s_%s_%s.png" % [Loc.lang, mode, name]
	if not _require(image.save_png(_shots_dir.path_join(filename)) == OK, "screenshot saves"): return false
	(_summary["screenshots"] as Dictionary)[name] = filename
	return true


func _write_summary() -> bool:
	var mode := "reduced" if _reduced else "normal"
	var file := FileAccess.open(_shots_dir.path_join("boss_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
	if file == null: _fail("summary open failed"); return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n"); file.close(); return true


func _wait_frames(count: int) -> void:
	for _i in count: await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition: return true
	_fail(message); return false


func _fail(message: String) -> void:
	if _failed: return
	_failed = true; _summary["failure"] = message; _summary["failed_stage"] = _stage
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	printerr("boss timeline probe FAILED: %s" % message)
	if _shots_dir != "":
		var mode := "reduced" if _reduced else "normal"
		var file := FileAccess.open(_shots_dir.path_join(
				"boss_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n")
			file.close()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["boss_timeline_probe_save.json", "boss_timeline_probe_runs.jsonl",
		"boss_timeline_probe_feedback.jsonl", "boss_timeline_probe_settings.json"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
