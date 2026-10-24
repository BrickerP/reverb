extends SceneTree
# Actual-window Temporal Rift fixture. Run EN/ZH x normal/reduced at max 60 FPS.

const DEADLINE_FRAMES := 1500
const DT := 1.0 / 60.0

var _main: Node
var _frames := 0
var _failed := false
var _stage := "initialize"
var _shots_dir := ""
var _reduced := false
var _summary: Dictionary = {"source": "fixture", "timeline": [], "screenshots": {},
	"diagnostics": {}, "checks": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://rift_presentation_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://rift_presentation_probe_runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://rift_presentation_probe_feedback.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://rift_presentation_probe_settings.json")
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
	if _frames > DEADLINE_FRAMES and not _failed: _fail("deadline exceeded at %s" % _stage)
	return false


func _run() -> void:
	if not (await _enter_run()): return
	if not (await _timeline_case()): return
	if not (await _exclusion_rebind_multi_case()): return
	if not (await _lethal_case()): return
	if not (await _cleanup_case()): return
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["fixture"] = {"run_source": OS.get_environment("REVERB_RUN_SOURCE"),
		"timing": "bounded manual Sim.step at 60Hz plus actual render frames"}
	if not _write_summary(): return
	print("rift presentation probe: OK")
	quit()


func _enter_run() -> bool:
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible: break
		await process_frame
	if not _require(_main.character_select != null, "Main reaches title"): return false
	_main.meta.unlocked[&"looper"] = true
	_main.choose_character(&"looper", 497)
	await _wait_frames(3)
	_main.paused = true; _main.pause_ui.close(); _main._view.set_paused(false)
	_main.audio.set_paused(false); _main._view.set_reduced_effects(_reduced)
	return _require(_main.sim != null and _main._view.visible and _main.hud.visible,
			"Main arena and HUD are visible")


func _timeline_case() -> bool:
	_stage = "schedule"
	var sim: Sim = _main.sim
	_prepare_wave(sim, 12)
	var signals := {"spawn": 0, "activate": 0, "end": 0, "hurt": 0}
	var hurts: Array[PlayerHurtInfo] = []
	var spawn_audio: int = int(_main.audio.play_count(&"echo"))
	var activation_audio: int = int(_main.audio.play_count(&"silence"))
	var blast_audio: int = int(_main.audio.play_count(&"hurt_blast"))
	var legacy_hurt_audio: int = int(_main.audio.play_count(&"hurt"))
	sim.rift_spawned.connect(func(_r: TemporalRift) -> void: signals["spawn"] += 1)
	sim.rift_activated.connect(func(_r: TemporalRift) -> void: signals["activate"] += 1)
	sim.rift_ended.connect(func(_r: TemporalRift) -> void: signals["end"] += 1)
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void:
		signals["hurt"] += 1; hurts.append(info))
	_step(sim, Sim.RIFT_FIRST_DELAY + 0.01)
	if not _require(sim.rifts.size() == 1 and sim.rifts[0].is_warning()
			and int(signals["spawn"]) == 1
			and int(_main.audio.play_count(&"echo")) == spawn_audio + 1,
			"actual eight-second schedule spawns one warning rift and cue"): return false
	var rift: TemporalRift = sim.rifts[0]
	if not _require(_rift_inside_floor(rift), "rift radius remains within arena floor bounds"): return false
	_add_overlap_fixture(sim, rift.pos)
	if not (await _capture("warning")): return false
	var hp := sim.player.hp
	_step(sim, 1.2)
	if not _require(sim.player.hp == hp and int(signals["hurt"]) == 0,
			"1.2 seconds of warning never hurts"): return false
	_step(sim, 0.31)
	if not _require(rift.is_active() and int(signals["activate"]) == 1,
			"warning activates once after 1.5 seconds"): return false
	if not _require(int(_main.audio.play_count(&"silence")) == activation_audio + 1,
			"activation routes one existing silence cue"): return false
	if not (await _capture("active")): return false

	_stage = "outside_tick"
	sim.player.pos = _farthest_corner(rift.pos)
	_step(sim, TemporalRift.TICK_TIME + 0.01)
	if not _require(sim.player.hp == hp and int(signals["hurt"]) == 0,
			"outside player is safe for a full 0.75-second tick"): return false
	if not _require(int(_main.audio.play_count(&"hurt_blast")) == blast_audio,
			"outside tick emits no rift hurt cue"): return false

	_stage = "inside_tick"
	sim.player.pos = rift.pos
	sim.player.iframes = 0.0
	_step(sim, TemporalRift.TICK_TIME + 0.01)
	_summary["diagnostics"]["inside_tick_observed"] = {
		"hurt_signal_count": signals["hurt"], "hurt_rows": hurts.size(),
		"source": String(hurts[0].source) if not hurts.is_empty() else "missing",
		"effect": String(hurts[0].effect) if not hurts.is_empty() else "missing",
		"last_damage_source": String(sim.last_damage_source), "iframes": sim.player.iframes,
		"hp_before": hp, "hp_after": sim.player.hp,
	}
	if not _require(int(signals["hurt"]) == 1 and hurts.size() == 1
			and hurts[0].source == &"rift" and hurts[0].effect == &"rift"
			and sim.last_damage_source == &"rift" and sim.player.iframes == 0.0,
			"inside tick emits one rich rift hurt without granting invulnerability"): return false
	if not _require(_main._view.event_last_data().get("effect", &"") == &"rift",
			"rich rift effect reaches ArenaView"): return false
	if not _require(int(_main.audio.play_count(&"hurt_blast")) == blast_audio + 1
			and int(_main.audio.play_count(&"hurt")) == legacy_hurt_audio,
			"rich rift hit routes one blast cue without duplicate legacy hurt"): return false
	if not (await _capture("inside_hit")): return false

	_stage = "pause"
	var telegraph_before := rift.telegraph
	var active_before := rift.active
	var tick_before := rift.tick
	_main._view.set_paused(true); _main.audio.set_paused(true)
	await _wait_frames(6)
	if not _require(is_equal_approx(rift.telegraph, telegraph_before)
			and is_equal_approx(rift.active, active_before) and is_equal_approx(rift.tick, tick_before)
			and bool(_main.audio.is_paused()), "pause freezes rift state and audio"): return false
	_main._view.set_paused(false); _main.audio.set_paused(false)

	_stage = "expiry"
	sim.player.pos = _farthest_corner(rift.pos)
	_step(sim, TemporalRift.ACTIVE_TIME + 0.2)
	if not _require(int(signals["end"]) == 1 and sim.rifts.is_empty(),
			"rift expires once and compacts/reset state"): return false
	_summary["checks"]["timeline"] = signals.duplicate()
	return true


func _exclusion_rebind_multi_case() -> bool:
	_stage = "exclusions"
	var replacement := Sim.new(498)
	Content.character(&"looper").apply(replacement); replacement.start_run()
	_main._view.bind(replacement, &"looper"); _main.hud.bind(replacement); _main.audio.bind(replacement)
	_prepare_wave(replacement, 11); _step(replacement, 30.0)
	if not _require(replacement.rifts.is_empty(), "wave 11 excludes rifts after long bounded simulation"): return false
	_prepare_wave(replacement, WaveDirector.FINAL_WAVE); _step(replacement, 30.0)
	if not _require(replacement.rifts.is_empty(), "boss wave 20 excludes rifts"): return false
	var ended := [0]
	replacement.rift_ended.connect(func(_r: TemporalRift) -> void: ended[0] += 1)
	for i in 3:
		var r := TemporalRift.new(); r.pos = Vector2(300 + i * 180, 320); r.telegraph = 0.0
		r.active = 0.01; r.tick = 1.0; replacement.rifts.append(r)
	replacement._step_rifts(0.02)
	if not _require(ended[0] == 3 and replacement.rifts.is_empty(),
			"manual multiple simultaneous expiries are safe and compact once"): return false
	_main._view.unbind(); _main.hud.unbind(); _main.audio.bind(null)
	if not _require(_main._view.sim == null and _main.hud.sim == null
			and not bool(_main.audio.binding_state().get("sim_bound", true)),
			"rift signals and feedback reset on unbind"): return false
	_summary["checks"]["exclusions"] = {"wave11": true, "boss20": true, "multi_end": 3}
	return true


func _lethal_case() -> bool:
	_stage = "lethal"
	_main.new_run(499, &"looper"); _main.paused = true; _main.pause_ui.close()
	_main._view.set_paused(false); _main._view.set_reduced_effects(_reduced)
	var sim: Sim = _main.sim
	_prepare_wave(sim, 12)
	var rift := TemporalRift.new(); rift.pos = sim.player.pos; rift.telegraph = 0.0
	rift.active = 2.0; rift.tick = 0.01; sim.rifts.append(rift)
	var blast_audio: int = int(_main.audio.play_count(&"hurt_blast"))
	sim.player.hp = 1.0; sim.player.iframes = 0.0
	sim.step(0.02, Vector2.ZERO)
	_main._sync_phase(); await _wait_frames(3)
	if not _require(sim.phase == Sim.Phase.LOST and sim.last_damage_source == &"rift"
			and _main.end_ui.visible and (_main.end_ui as EndUi)._stats.text.contains(Loc.t("enemy.rift")),
			"lethal rift opens localized end screen"): return false
	if not _require(int(_main.audio.play_count(&"hurt_blast")) == blast_audio + 1,
			"lethal rift routes one blast cue"): return false
	var saved: Dictionary = _main._latest_saved_run
	if not _require(saved.get("death_cause", "") == "rift" and saved.get("source", "") == "fixture",
			"saved fixture run preserves rift death cause and provenance"): return false
	if not (await _capture("lethal_end")): return false
	_summary["checks"]["lethal"] = true
	return true


func _prepare_wave(sim: Sim, wave: int) -> void:
	sim.player.stats.values[Stats.MAX_HP] = 100000.0; sim.player.hp = sim.player.max_hp()
	sim.player.weapons.clear(); sim.player.weapon_levels.clear(); sim.player.cooldowns.clear()
	sim.start_wave(wave); sim._plan.clear(); sim._plan_idx = 0; sim.pending.clear(); sim.enemies.clear()
	_main._view.bind(sim, &"looper"); _main._view.set_reduced_effects(_reduced); _main.hud.bind(sim)
	_main.audio.bind(sim)


func _step(sim: Sim, seconds: float) -> void:
	for _i in int(ceil(seconds / DT)): sim.step(DT, Vector2.ZERO)


func _add_overlap_fixture(sim: Sim, pos: Vector2) -> void:
	# Stay inside the 80px rift ring for draw-order evidence, but outside the
	# enemy/player contact threshold so this actor cannot grant contact iframes.
	var away := (pos - sim.player.pos).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var spawn := PendingSpawn.new(); spawn.def = Content.enemy(&"grunt"); spawn.pos = pos + away * 50.0
	sim._materialize(spawn); sim.enemies[0].speed = 0.0; sim.enemies[0].damage = 0.0
	var pickup := Pickup.new(); pickup.pos = pos + Vector2(-20, 0); pickup.value = 3; sim.pickups.append(pickup)
	_summary["draw_order"] = ["pending", "echo_paths", "pickup_range", "rifts", "pickups",
		"enemies", "echoes", "projectiles", "player", "feedback", "sparks"]


func _rift_inside_floor(rift: TemporalRift) -> bool:
	return Sim.ARENA.grow(-rift.radius).has_point(rift.pos)


func _farthest_corner(pos: Vector2) -> Vector2:
	var best := Sim.ARENA.position + Vector2(20, 20)
	for corner: Vector2 in [Sim.ARENA.position + Vector2(20, 20),
		Vector2(Sim.ARENA.end.x - 20, Sim.ARENA.position.y + 20), Sim.ARENA.end - Vector2(20, 20),
		Vector2(Sim.ARENA.position.x + 20, Sim.ARENA.end.y - 20)]:
		if corner.distance_to(pos) > best.distance_to(pos): best = corner
	return best


func _cleanup_case() -> bool:
	_stage = "cleanup"; _main.show_select(); await _wait_frames(3)
	if not _require(_main.character_select.visible and _main.sim == null
			and _main._view.sim == null and _main.hud.sim == null,
			"probe returns to title and frees rift session"): return false
	_main.audio.stop_all(); _summary["checks"]["cleanup"] = true; return true


func _capture(name: String) -> bool:
	_summary["diagnostics"][name] = {"stage": _stage, "frame": _frames,
		"wave_time": _main.sim.wave_time, "rifts": _main.sim.rifts.size(),
		"phase": int(_main.sim.phase)}
	_main._view.queue_redraw(); _main.hud.queue_redraw(); await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty(), "%s frame readback exists" % name): return false
	var mode := "reduced" if _reduced else "normal"
	var filename := "rift_%s_%s_%s.png" % [Loc.lang, mode, name]
	if not _require(image.save_png(_shots_dir.path_join(filename)) == OK, "screenshot saves"): return false
	(_summary["screenshots"] as Dictionary)[name] = filename; return true


func _write_summary() -> bool:
	var mode := "reduced" if _reduced else "normal"
	var file := FileAccess.open(_shots_dir.path_join("rift_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
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
	_summary["language"] = Loc.lang; _summary["reduced_effects"] = _reduced
	printerr("rift presentation probe FAILED: %s" % message)
	if _shots_dir != "":
		var mode := "reduced" if _reduced else "normal"
		var file := FileAccess.open(_shots_dir.path_join(
				"rift_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n"); file.close()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["rift_presentation_probe_save.json", "rift_presentation_probe_runs.jsonl",
		"rift_presentation_probe_feedback.jsonl", "rift_presentation_probe_settings.json"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
