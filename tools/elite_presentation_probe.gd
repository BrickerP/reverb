extends SceneTree
# Actual-window elite presentation fixture. Run once per effects mode:
# REVERB_REDUCED_EFFECTS=0|1 godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/elite_presentation_probe.gd

const DEADLINE_FRAMES := 1800
const DT := 1.0 / 60.0
const ELITE_KINDS: Array[StringName] = [&"overclocked", &"bulwark", &"volatile"]
const POSITIONS: Array[Vector2] = [
	Vector2(235.0, 220.0), Vector2(640.0, 220.0), Vector2(1045.0, 220.0),
	Vector2(235.0, 500.0), Vector2(640.0, 500.0), Vector2(1045.0, 500.0),
]

var _main: Node
var _frames := 0
var _failed := false
var _shots_dir := ""
var _reduced := false
var _summary: Dictionary = {
	"source": "fixture", "groups": [], "events": {}, "screenshots": {}, "lifecycle": {},
}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://elite_presentation_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://elite_presentation_probe_runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://elite_presentation_probe_feedback.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://elite_presentation_probe_settings.json")
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	_clear_fixture_files()
	_reduced = OS.get_environment("REVERB_REDUCED_EFFECTS") == "1"
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before elite presentation probe completed")
	return false


func _run() -> void:
	if not (await _enter_run()):
		return
	var bulwark: EnemyState
	var volatile: EnemyState
	for kind: StringName in ELITE_KINDS:
		var group: Dictionary = await _elite_group(kind)
		if group.is_empty():
			return
		(_summary["groups"] as Array).append(group)
		if kind == &"bulwark":
			bulwark = _enemy_by_id(&"grunt")
			if not (await _bulwark_events(bulwark)):
				return
		elif kind == &"volatile":
			volatile = _enemy_by_id(&"grunt")
			if not (await _volatile_event(volatile)):
				return
	if not (await _lifecycle_case()):
		return
	_summary["reduced_effects"] = _reduced
	_summary["fixture"] = {"regular_enemy_ids": _regular_ids(), "elite_kinds": ELITE_KINDS,
		"combinations": 18, "run_source": OS.get_environment("REVERB_RUN_SOURCE")}
	_summary["environment"] = {"godot": Engine.get_version_info(),
		"display": DisplayServer.get_name(),
		"viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]}
	if not _write_summary():
		return
	_main.audio.stop_all()
	print("elite presentation probe: %s" % JSON.stringify({"reduced_effects": _reduced,
		"groups": ELITE_KINDS.size(), "combinations": 18}))
	print("elite presentation probe: OK")
	quit()


func _enter_run() -> bool:
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible:
			break
		await process_frame
	if not _require(_main.character_select != null, "Main reaches character selection"):
		return false
	_main.meta.unlocked[&"looper"] = true
	_main.choose_character(&"looper", 145321)
	await _wait_frames(4)
	if not _require(_main.sim != null and _main._view.visible and _main.hud.visible,
			"fixture enters a visible arena with HUD"):
		return false
	# Stop Main's physics loop while the probe advances only the authoritative
	# spawn/damage methods under test. ArenaView remains live for actual frames.
	_main.paused = true
	_main.pause_ui.close()
	_main._view.set_paused(false)
	_main.audio.set_paused(false)
	_main._view.set_reduced_effects(_reduced)
	_main.shop_ui.set_reduced_effects(_reduced)
	_main.end_ui.set_reduced_effects(_reduced)
	_reset_arena()
	return true


func _elite_group(kind: StringName) -> Dictionary:
	_reset_arena()
	var sim: Sim = _main.sim
	var defs := _regular_defs()
	if not _require(defs.size() == 6, "%s group contains all six regular enemy IDs" % kind):
		return {}
	for i in defs.size():
		var pending := PendingSpawn.new()
		pending.def = defs[i]
		pending.pos = POSITIONS[i]
		pending.delay = 0.32
		pending.elite_kind = kind
		sim.pending.append(pending)
	if not _require(sim.pending.size() == 6 and _pending_kinds_are(kind),
			"%s stages six colored elite telegraphs" % kind):
		return {}
	if not (await _capture("%s_pending" % kind)):
		return {}
	for _frame in 22:
		sim._spawn_enemies(DT)
		await process_frame
	if not _require(sim.pending.is_empty() and sim.enemies.size() == 6,
			"%s telegraphs materialize through Sim runtime timing" % kind):
		return {}
	var combinations: Array[Dictionary] = []
	for enemy: EnemyState in sim.enemies:
		enemy.speed = 0.0
		enemy.damage = 0.0
		if not _require(enemy.elite and enemy.elite_kind == kind and not enemy.def.is_boss,
				"%s materialized enemy preserves elite kind and excludes boss" % kind):
			return {}
		combinations.append({"enemy_id": String(enemy.def.id), "elite_kind": String(kind),
			"position": [enemy.pos.x, enemy.pos.y], "radius": enemy.radius})
	if not _require(_elite_distinctions_readable(),
			"elite colors remain distinct in %s mode" % ("reduced" if _reduced else "normal")):
		return {}
	if not (await _capture("%s_materialized" % kind)):
		return {}
	return {"elite_kind": String(kind), "pending_count": 6, "materialized_count": 6,
		"combinations": combinations}


func _bulwark_events(enemy: EnemyState) -> bool:
	if not _require(enemy != null and enemy.def.id != &"warden" and enemy.elite_kind == &"bulwark",
			"shield event uses a non-Warden bulwark elite"):
		return false
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	enemy.max_hp = 1000.0
	enemy.hp = 1000.0
	sim.player.pos = enemy.pos + Vector2(-120.0, 0.0)
	sim.player.hp = sim.player.max_hp()
	var events: Array[DamageInfo] = []
	var collect := func(info: DamageInfo) -> void:
		if info.target_uid == enemy.uid:
			events.append(info)
	sim.damage_event.connect(collect)
	var shield_audio: int = _main.audio.play_count(&"shield_block")
	var hit_audio: int = _main.audio.play_count(&"hit")
	var hp_before := enemy.hp
	sim.damage_enemy(enemy, 100.0, Vector2.ZERO, false, -1,
			Vector2.RIGHT, &"rifle", &"elite_probe_front")
	if not _require(events.size() == 1 and events[0].reduced,
			"bulwark front hit emits one rich reduced DamageInfo"):
		return false
	if not _require(is_equal_approx(hp_before - enemy.hp,
			100.0 * (1.0 - Sim.ELITE_BULWARK_REDUCTION)),
			"bulwark front hit applies runtime shield reduction"):
		return false
	if not _require(_main.audio.play_count(&"shield_block") == shield_audio + 1
			and bool(view.event_last_data().get("reduced", false)),
			"front rich hit reaches ArenaView and shield audio once"):
		return false
	if not (await _capture("bulwark_front_hit")):
		return false
	await _wait_frames(5)
	hp_before = enemy.hp
	sim.damage_enemy(enemy, 100.0, Vector2.ZERO, false, -1,
			Vector2.LEFT, &"rifle", &"elite_probe_back")
	if not _require(events.size() == 2 and not events[1].reduced
			and is_equal_approx(hp_before - enemy.hp, 100.0),
			"bulwark back hit emits one unreduced rich DamageInfo"):
		return false
	if not _require(_main.audio.play_count(&"hit") == hit_audio + 1
			and not bool(view.event_last_data().get("reduced", true)),
			"back rich hit reaches ArenaView and normal hit audio once"):
		return false
	if not _feedback_within_bounds():
		return false
	if not (await _capture("bulwark_back_hit")):
		return false
	if sim.damage_event.is_connected(collect):
		sim.damage_event.disconnect(collect)
	_summary["events"]["bulwark"] = {"enemy_id": String(enemy.def.id),
		"front_reduced": true, "back_reduced": false,
		"shield_audio_delta": 1, "normal_hit_audio_delta": 1}
	return true


func _volatile_event(enemy: EnemyState) -> bool:
	if not _require(enemy != null and enemy.def.id != &"bomber" and enemy.elite_kind == &"volatile",
			"volatile event uses a runtime elite rather than a built-in bomber"):
		return false
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	var blasts: Array[ExplosionInfo] = []
	var collect := func(info: ExplosionInfo) -> void: blasts.append(info)
	sim.explosion_info.connect(collect)
	# Keep the player safely outside the 64px blast; this case verifies presentation,
	# not player lethality.
	sim.player.pos = Vector2(640.0, 640.0)
	sim.player.iframes = 0.0
	var hp_before := sim.player.hp
	var audio_before: int = _main.audio.play_count(&"bomber_explosion")
	var explosion_before := int(view.feedback_counts().get("explosions", 0))
	enemy.hp = 1.0
	sim.damage_enemy(enemy, 10.0, Vector2.ZERO, false, -1,
			Vector2.RIGHT, &"rifle", &"elite_probe_kill")
	if not _require(blasts.size() == 1 and blasts[0].kind == ExplosionInfo.BOMBER
			and is_equal_approx(blasts[0].radius, 64.0),
			"volatile death emits one existing BOMBER explosion at radius 64"):
		return false
	if not _require(_main.audio.play_count(&"bomber_explosion") == audio_before + 1,
			"volatile BOMBER event plays existing explosion audio once"):
		return false
	if not _require(int(view.feedback_counts().get("explosions", 0)) == explosion_before + 1
			and view.event_last_data().get("cause", &"") == ExplosionInfo.BOMBER,
			"volatile BOMBER event reaches ArenaView VFX once"):
		return false
	if not _require(is_equal_approx(sim.player.hp, hp_before) and sim.player.hp > 0.0,
			"volatile fixture causes no accidental player death or damage"):
		return false
	if not _feedback_within_bounds():
		return false
	if not (await _capture("volatile_explosion")):
		return false
	if sim.explosion_info.is_connected(collect):
		sim.explosion_info.disconnect(collect)
	_summary["events"]["volatile"] = {"enemy_id": String(enemy.def.id),
		"kind": "bomber", "radius": blasts[0].radius, "audio_delta": 1,
		"player_damage": 0}
	return true


func _lifecycle_case() -> bool:
	var view: ArenaView = _main._view
	var audio: GameAudio = _main.audio
	var before := float(view.motion_stats().get("visual_time", 0.0))
	view.set_paused(true)
	audio.set_paused(true)
	await _wait_frames(4)
	if not _require(bool(view.motion_stats().get("paused", false))
			and is_equal_approx(float(view.motion_stats().get("visual_time", -1.0)), before)
			and audio.is_paused(), "ArenaView and GameAudio pause together"):
		return false
	view.set_paused(false)
	audio.set_paused(false)
	var replacement := Sim.new(145322)
	Content.character(&"looper").apply(replacement)
	replacement.start_run()
	view.bind(replacement, &"looper")
	_main.hud.bind(replacement)
	audio.bind(replacement)
	if not _require(view.sim == replacement and _main.hud.sim == replacement
			and bool(audio.binding_state().get("sim_bound", false))
			and _feedback_total() == 0, "presentation surfaces rebind cleanly to a new Sim"):
		return false
	view.unbind()
	_main.hud.unbind()
	audio.bind(null)
	var audio_state := audio.binding_state()
	if not _require(view.sim == null and _main.hud.sim == null and _feedback_total() == 0
			and not bool(audio_state.get("sim_bound", true))
			and not bool(audio_state.get("shop_bound", true))
			and not bool(audio_state.get("paused", true))
			and int(audio_state.get("cooldowns", -1)) == 0,
			"ArenaView, HUD and GameAudio reset session state"):
		return false
	_summary["lifecycle"] = {"pause": true, "rebind": true, "reset": true}
	return true


func _reset_arena() -> void:
	var sim: Sim = _main.sim
	sim.phase = Sim.Phase.WAVE
	sim.wave = 10
	sim.wave_duration = 120.0
	sim.wave_time = 1.0
	sim._plan.clear()
	sim._plan_idx = 0
	sim.enemies.clear()
	sim.projectiles.clear()
	sim.pickups.clear()
	sim.pending.clear()
	sim.echoes.clear()
	sim.bank.takes.clear()
	sim.grid.clear()
	sim.player.pos = Vector2(640.0, 620.0)
	sim.player.iframes = 0.0
	sim.player.stats.values[Stats.MAX_HP] = 100000.0
	sim.player.hp = sim.player.max_hp()
	_main._view.bind(sim, &"looper")
	_main._view.set_reduced_effects(_reduced)
	_main.hud.bind(sim)
	_main.audio.bind(sim)


func _regular_defs() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for enemy: EnemyDef in Content.enemies():
		if not enemy.is_boss:
			out.append(enemy)
	return out


func _regular_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for enemy: EnemyDef in _regular_defs():
		out.append(String(enemy.id))
	return out


func _pending_kinds_are(kind: StringName) -> bool:
	for pending: PendingSpawn in _main.sim.pending:
		if pending.elite_kind != kind:
			return false
	return true


func _enemy_by_id(id: StringName) -> EnemyState:
	for enemy: EnemyState in _main.sim.enemies:
		if enemy.def.id == id:
			return enemy
	return null


func _elite_distinctions_readable() -> bool:
	var colors := [ArenaPainter._elite_color(&"overclocked"),
		ArenaPainter._elite_color(&"bulwark"), ArenaPainter._elite_color(&"volatile")]
	return colors[0] != colors[1] and colors[0] != colors[2] and colors[1] != colors[2]


func _feedback_total() -> int:
	var total := 0
	for value: Variant in _main._view.feedback_counts().values():
		total += int(value)
	return total


func _feedback_within_bounds() -> bool:
	var counts: Dictionary = _main._view.feedback_counts()
	return _require(int(counts.get("muzzles", 0)) <= ArenaView.MAX_MUZZLES
			and int(counts.get("hits", 0)) <= ArenaView.MAX_HITS
			and int(counts.get("explosions", 0)) <= ArenaView.MAX_EXPLOSIONS
			and int(counts.get("hurts", 0)) <= ArenaView.MAX_HURTS
			and int(counts.get("weapon_changes", 0)) <= ArenaView.MAX_WEAPON_CHANGES
			and int(counts.get("sparks", 0)) <= ArenaView.MAX_SPARKS,
			"ArenaView feedback queues remain within fixed bounds")


func _capture(state: String) -> bool:
	if not _require(_main._view.visible and _main.hud.visible and _main.sim != null,
			"%s capture has a bound arena and HUD" % state):
		return false
	_main._view.queue_redraw()
	_main.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty()
			and image.get_width() == 1280 and image.get_height() == 720,
			"%s screenshot is a non-empty 1280x720 frame" % state):
		return false
	var mode := "reduced" if _reduced else "normal"
	var filename := "elite_%s_%s.png" % [mode, state]
	var path := _shots_dir.path_join(filename)
	if not _require(image.save_png(path) == OK, "%s screenshot saves" % state):
		return false
	(_summary["screenshots"] as Dictionary)[state] = {"path": path,
		"width": image.get_width(), "height": image.get_height()}
	print("wrote shots/%s" % filename)
	return true


func _write_summary() -> bool:
	var mode := "reduced" if _reduced else "normal"
	var filename := "elite_%s_summary.json" % mode
	var file := FileAccess.open(_shots_dir.path_join(filename), FileAccess.WRITE)
	if file == null:
		_fail("failed to open %s" % filename)
		return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	print("wrote shots/%s" % filename)
	return true


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
	_summary["failure"] = message
	_summary["reduced_effects"] = _reduced
	printerr("elite presentation probe FAILED: %s" % message)
	if _shots_dir != "":
		var mode := "reduced" if _reduced else "normal"
		var file := FileAccess.open(_shots_dir.path_join("elite_%s_summary.json" % mode),
				FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n")
			file.close()
	quit(1)


func _clear_fixture_files() -> void:
	for name in [
		"elite_presentation_probe_save.json",
		"elite_presentation_probe_runs.jsonl",
		"elite_presentation_probe_feedback.jsonl",
		"elite_presentation_probe_settings.json",
	]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
