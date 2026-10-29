extends SceneTree
# Actual-window integration probe for rich combat, motion, audio and equipment
# feedback. Staged/forced cases are identified in feedback_summary.json.
# Usage: godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/feedback_probe.gd

const DEADLINE_FRAMES := 2400
const DT := 1.0 / 60.0
const WEAPON_IDS: Array[StringName] = [
	&"pistol", &"smg", &"shotgun", &"rifle", &"orb", &"flechette",
	&"longbow", &"hex_bolt", &"twin_fangs", &"flak_crown", &"rail_spike", &"nova_core",
]

var _main: Node
var _frames := 0
var _failed := false
var _shots_dir := ""
var _summary: Dictionary = {}
var _shot_events: Array[Dictionary] = []
var _damage_events: Array[Dictionary] = []
var _explosion_events: Array[Dictionary] = []
var _hurt_events: Array[Dictionary] = []
var _weapon_events: Array[Dictionary] = []


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_feedback_probe_suspend.json")
	OS.set_environment("REVERB_SAVE", "user://feedback_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://feedback_probe_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://feedback_probe_settings.json")
	_clear_fixture_files()
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before feedback probe completed")
	return false


func _run() -> void:
	if not (await _enter_run()):
		return
	_bind_spies()
	if not (await _weapon_profile_cases()):
		return
	if not (await _shield_case()):
		return
	if not (await _weapon_explosion_case()):
		return
	if not (await _contact_and_bomber_cases()):
		return
	if not (await _echo_source_case()):
		return
	if not (await _motion_pause_reduced_cases()):
		return
	if not (await _shop_feedback_case()):
		return
	if not (await _cleanup_case()):
		return
	_summary["signal_counts"] = {
		"shots": _shot_events.size(), "damage": _damage_events.size(),
		"explosions": _explosion_events.size(), "hurts": _hurt_events.size(),
		"weapon_changes": _weapon_events.size(),
	}
	_summary["actual_cases"] = [
		"12 weapon volleys through Sim.step", "echo-source volley through Sim.step",
		"contact hurt through Sim enemy movement", "movement idle-move-stop",
		"pause/resume and reduced effects", "focused shop buy and undo",
	]
	_summary["forced_fixture_cases"] = [
		"shield damage uses Sim.damage_enemy", "weapon explosion uses Combat.step_projectiles",
		"bomber kill uses Sim.damage_enemy to trigger its real death explosion",
	]
	_summary["unit_supported_contracts"] = [
		"legacy and rich signals do not double-bind", "feedback queues are bounded and expire",
		"rebind drops old signals", "presentation processing does not mutate simulation state",
	]
	_summary["capture_timing"] = {"weapon_hold_frames": 24,
		"impact_hold_frames": 15, "fixed_fps_reference": 60,
		"movie_capture_requires_user_arg": "--feedback-capture"}
	_write_summary()
	_main.audio.stop_all()
	await _wait_frames(8)
	print("feedback probe: %s" % JSON.stringify(_summary["signal_counts"]))
	print("feedback probe: OK")
	quit()


func _enter_run() -> bool:
	for _i in 180:
		if _main.character_select != null:
			break
		await process_frame
	if not _require(_main.character_select != null, "main reached character selection"):
		return false
	_main.choose_character(&"looper", 20261023)
	# Freeze Main's automatic physics while keeping presentation/audio active;
	# each case advances the real Sim explicitly and deterministically.
	_main.paused = true
	_main.hud.paused = false
	_main.pause_ui.close()
	_main._view.set_paused(false)
	_main.audio.set_paused(false)
	_reset_combat()
	return true


func _bind_spies() -> void:
	var sim: Sim = _main.sim
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: _shot_events.append(info.to_dict()))
	sim.damage_event.connect(func(info: DamageInfo) -> void: _damage_events.append(info.to_dict()))
	sim.explosion_info.connect(func(info: ExplosionInfo) -> void: _explosion_events.append(info.to_dict()))
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: _hurt_events.append(info.to_dict()))
	sim.weapon_changed.connect(func(info: WeaponChangeInfo) -> void: _weapon_events.append(info.to_dict()))


func _weapon_profile_cases() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	var audio: GameAudio = _main.audio
	if not _require(GameAudio.WEAPON_PROFILES.size() == WEAPON_IDS.size(),
			"audio exposes all 12 weapon profiles"):
		return false
	var rows: Array[Dictionary] = []
	for id in WEAPON_IDS:
		_reset_combat()
		view.bind(sim, &"looper")
		_set_player_weapon(id)
		_spawn_enemy(&"grunt", sim.player.pos + Vector2(92.0, 0.0), 100000.0, 0.0, 0.0)
		var profile: Dictionary = GameAudio.weapon_profile(id)
		if not _require(not profile.is_empty(), "%s has an audio profile" % id):
			return false
		var cue: StringName = profile.get("cue", &"")
		if not _require(cue == StringName("weapon_%s" % id) and audio.has_stream(cue),
				"%s maps to a loaded distinct audio cue" % id):
			return false
		var audio_before: int = audio.play_count(cue)
		var shot_before := _shot_events.size()
		sim.step(DT, Vector2.ZERO)
		if not _require(_shot_events.size() == shot_before + 1,
				"%s emits one authoritative volley" % id):
			return false
		var last: Dictionary = view.event_last_data()
		if not _require(last.get("kind", &"") == &"shot" and last.get("weapon_id", &"") == id,
				"%s reaches ArenaView with its weapon ID" % id):
			return false
		if not _require(int(view.feedback_counts().get("muzzles", 0)) == 1
				and view.recoil_amount(-1, id) > 0.0,
				"%s creates one muzzle and mounted recoil" % id):
			return false
		if not _require(audio.play_count(cue) == audio_before + 1,
				"%s rich shot plays its cue once" % id):
			return false
		if not _require(not sim.projectiles.is_empty()
				and (sim.projectiles[0] as Projectile).weapon_id == id,
				"%s creates authoritative Sim projectiles" % id):
			return false
		rows.append({"id": String(id), "cue": String(cue),
			"pellets": int(last.get("count", 0)), "recoil": view.recoil_amount(-1, id)})
		if id == &"rail_spike":
			if not (await _save("shot")):
				return false
		# Keep each distinct weapon profile audible and its first feedback frames
		# visible in Movie Maker captures instead of emitting all 12 in one frame.
		await _wait_frames(24)
	_summary["weapons"] = rows
	return true


func _shield_case() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	view.bind(sim, &"looper")
	_reset_combat()
	var warden := _spawn_enemy(&"warden", sim.player.pos + Vector2(92.0, 0.0), 100.0, 0.0, 0.0)
	var audio_before: int = _main.audio.play_count(&"shield_block")
	var damage_before := _damage_events.size()
	sim.damage_enemy(warden, 10.0, Vector2.ZERO, false, -1, Vector2.RIGHT, &"rifle", &"hit")
	if not _require(_damage_events.size() == damage_before + 1,
			"forced shield case emits one real DamageInfo"):
		return false
	var last: Dictionary = view.event_last_data()
	if not _require(last.get("kind", &"") == &"damage" and bool(last.get("reduced", false)),
			"warden-facing hit remains shield-reduced"):
		return false
	if not _require(_main.audio.play_count(&"shield_block") == audio_before + 1,
			"shield-reduced rich hit plays shield cue once"):
		return false
	_summary["shield"] = {"reduced": true, "weapon_id": "rifle", "entry": "Sim.damage_enemy"}
	if not (await _save("blocked")):
		return false
	await _wait_frames(15)
	return true


func _weapon_explosion_case() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	view.bind(sim, &"looper")
	_reset_combat()
	var primary := _spawn_enemy(&"grunt", sim.player.pos + Vector2(110.0, 0.0), 100.0, 0.0, 0.0)
	_spawn_enemy(&"grunt", sim.player.pos + Vector2(130.0, 12.0), 100.0, 0.0, 0.0)
	sim._move_enemies(0.0)
	var projectile := Projectile.new()
	projectile.pos = primary.pos - Vector2(1.0, 0.0)
	projectile.vel = Vector2.RIGHT * 100.0
	projectile.damage = 10.0
	projectile.radius = 4.0
	projectile.knockback = 40.0
	projectile.explosion_radius = 48.0
	projectile.explosion_damage = 0.5
	projectile.life = 1.0
	projectile.color = Content.weapon(&"flak_crown").color
	projectile.source = -1
	projectile.weapon_id = &"flak_crown"
	sim.projectiles.append(projectile)
	var explosion_before := _explosion_events.size()
	var audio_before: int = _main.audio.play_count(&"weapon_explosion")
	Combat.step_projectiles(sim, 0.01)
	if not _require(_explosion_events.size() == explosion_before + 1,
			"staged projectile collision emits one weapon explosion"):
		return false
	var last: Dictionary = view.event_last_data()
	if not _require(last.get("kind", &"") == &"explosion"
			and last.get("cause", &"") == ExplosionInfo.WEAPON
			and last.get("weapon_id", &"") == &"flak_crown",
			"weapon explosion preserves cause and weapon ID"):
		return false
	if not _require(_main.audio.play_count(&"weapon_explosion") == audio_before + 1,
			"weapon explosion rich event plays once"):
		return false
	_summary["weapon_explosion"] = {"cause": "weapon", "weapon_id": "flak_crown",
		"entry": "Combat.step_projectiles"}
	if not (await _save("explosion")):
		return false
	await _wait_frames(15)
	return true


func _contact_and_bomber_cases() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	view.bind(sim, &"looper")
	_reset_combat()
	_spawn_enemy(&"grunt", sim.player.pos, 20.0, 0.0, 3.0)
	var contact_before := _hurt_events.size()
	var contact_audio: int = _main.audio.play_count(&"hurt_contact")
	sim._move_enemies(0.0)
	if not _require(_hurt_events.size() == contact_before + 1,
			"overlapping enemy emits one contact PlayerHurtInfo"):
		return false
	if not _require(view.event_last_data().get("effect", &"") == &"contact"
			and not bool(view.event_last_data().get("has_direction", true))
			and _main.audio.play_count(&"hurt_contact") == contact_audio + 1,
			"zero-overlap contact stays symmetric and reaches audio once"):
		return false
	_summary["contact_hurt"] = {"effect": "contact", "entry": "Sim._move_enemies"}
	if not (await _save("hurt")):
		return false
	await _wait_frames(15)

	view.bind(sim, &"looper")
	_reset_combat()
	var bomber := _spawn_enemy(&"bomber", sim.player.pos + Vector2(8.0, 0.0), 24.0, 0.0, 0.0)
	var blast_before := _explosion_events.size()
	var hurt_before := _hurt_events.size()
	var explosion_audio: int = _main.audio.play_count(&"bomber_explosion")
	var hurt_audio: int = _main.audio.play_count(&"hurt_blast")
	sim.damage_enemy(bomber, 1000.0, Vector2.ZERO, false, -1,
			Vector2.RIGHT, &"rifle", &"forced_fixture_kill")
	if not _require(_explosion_events.size() == blast_before + 1
			and _hurt_events.size() == hurt_before + 1,
			"forced bomber death emits explosion and blast hurt"):
		return false
	if not _require(_main.audio.play_count(&"bomber_explosion") == explosion_audio + 1
			and _main.audio.play_count(&"hurt_blast") == hurt_audio + 1,
			"bomber explosion and blast hurt each play once"):
		return false
	if not _require(view.event_last_data().get("effect", &"") == &"bomber_explosion",
			"blast hurt preserves bomber effect"):
		return false
	_summary["bomber"] = {"cause": "bomber", "hurt_effect": "bomber_explosion",
		"entry": "forced kill through Sim.damage_enemy"}
	if not (await _save("bomber")):
		return false
	await _wait_frames(15)
	return true


func _echo_source_case() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	view.bind(sim, &"looper")
	_reset_combat()
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	var take := EchoTake.new()
	take.wave = 1
	take.weapons.append(Content.weapon(&"hex_bolt"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	var echo_pos := sim.player.pos - Vector2(80.0, 0.0)
	take.samples = PackedVector2Array([echo_pos, echo_pos, echo_pos])
	sim.bank.takes.clear()
	sim.bank.add(take)
	sim.echoes.append(EchoActor.new(take, 0))
	_spawn_enemy(&"grunt", echo_pos + Vector2(92.0, 0.0), 1000.0, 0.0, 0.0)
	var before := _shot_events.size()
	sim.step(DT, Vector2.ZERO)
	if not _require(_shot_events.size() == before + 1,
			"echo weapon fires through the real Sim loop"):
		return false
	var last: Dictionary = view.event_last_data()
	if not _require(last.get("kind", &"") == &"shot" and int(last.get("source", -1)) == 0,
			"echo volley preserves numeric source index"):
		return false
	_summary["echo_shot"] = {"source": 0, "weapon_id": String(last.get("weapon_id", &"")),
		"entry": "Sim.step"}
	return true


func _motion_pause_reduced_cases() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	view.bind(sim, &"looper")
	_reset_combat()
	await _wait_frames(3)
	if not _require(not bool(view.motion_stats().get("moving", true)), "stationary player is idle"):
		return false
	for _i in 12:
		sim.step(DT, Vector2.RIGHT)
		await process_frame
	if not _require(bool(view.motion_stats().get("moving", false)), "real movement starts gait"):
		return false
	for _i in 24:
		await process_frame
	if not _require(not bool(view.motion_stats().get("moving", true)), "stopped player settles to idle"):
		return false

	_reset_combat()
	_set_player_weapon(&"pistol")
	_spawn_enemy(&"grunt", sim.player.pos + Vector2(92.0, 0.0), 1000.0, 0.0, 0.0)
	sim.step(DT, Vector2.ZERO)
	var visual_before := float(view.motion_stats().get("visual_time", 0.0))
	var recoil_before := view.recoil_amount(-1, &"pistol")
	if not _require(_main.audio._music != null and _main.audio._music.playing,
			"ambient music is actually playing in the real window before pause"):
		return false
	var pause_diagnostic := {
		"before": {"playing": _main.audio._music.playing,
			"stream_paused": _main.audio._music.stream_paused,
			"audio_paused": _main.audio.is_paused(),
			"position": _main.audio._music.get_playback_position()},
	}
	var blocked_before: int = _main.audio.play_count(&"boss")
	var click_before: int = _main.audio.play_count(&"click")
	# Exercise Main's pause transition. Immediately after resume the fixture
	# restores its manual-physics freeze while leaving view/audio unpaused.
	_main.paused = false
	_main._set_paused(true)
	if not _require(_main.paused and _main.audio.is_paused()
			and bool(view.motion_stats().get("paused", false)),
			"Main pause reaches view and audio"):
		return false
	if not _require(_main.audio._music.stream_paused
			and _main.audio._music.has_stream_playback(),
			"ambient stream becomes paused while retaining stream playback"):
		return false
	pause_diagnostic["paused_immediate"] = {"playing": _main.audio._music.playing,
		"stream_paused": _main.audio._music.stream_paused,
		"has_stream_playback": _main.audio._music.has_stream_playback(),
		"audio_paused": _main.audio.is_paused(),
		"position": _main.audio._music.get_playback_position()}
	if not _require(not _main.audio.play(&"boss")
			and _main.audio.play_count(&"boss") == blocked_before,
			"paused audio rejects a combat cue"):
		return false
	if not _require(_main.audio.play(&"click")
			and _main.audio.play_count(&"click") == click_before + 1,
			"paused audio still accepts a UI click cue"):
		return false
	# Audio playback position is updated asynchronously by the mixer. Let the
	# pause transition settle before sampling the 150 ms observation window.
	await create_timer(0.05, true, false, true).timeout
	var paused_position: float = _main.audio._music.get_playback_position()
	await create_timer(0.15, true, false, true).timeout
	var paused_after_wait: float = _main.audio._music.get_playback_position()
	var movie_capture: bool = _is_movie_capture()
	pause_diagnostic["paused_after_150ms"] = {"playing": _main.audio._music.playing,
		"stream_paused": _main.audio._music.stream_paused,
		"has_stream_playback": _main.audio._music.has_stream_playback(),
		"audio_paused": _main.audio.is_paused(), "position": paused_after_wait,
		"position_delta": absf(paused_after_wait - paused_position),
		"position_check": "skipped_movie_maker" if movie_capture else "real_paced"}
	if not movie_capture and not _require(absf(paused_after_wait - paused_position) <= 0.02,
			"ambient playback position stays within 20 ms while paused"):
		return false
	if not _require(float(view.motion_stats().get("visual_time", -1.0)) == visual_before
			and is_equal_approx(view.recoil_amount(-1, &"pistol"), recoil_before),
			"pause freezes visual time and recoil expiry"):
		return false
	_main._set_paused(false)
	if not _require(not _main.audio.is_paused() and not _main.audio._music.stream_paused
			and _main.audio._music.playing,
			"Main resume clears pause state and resumes ambient playback"):
		return false
	var resumed_position: float = _main.audio._music.get_playback_position()
	_main.paused = true
	_main.hud.paused = false
	_main.pause_ui.close()
	await _wait_frames(12)
	var resumed_after_wait: float = _main.audio._music.get_playback_position()
	pause_diagnostic["resumed_after_12_frames"] = {"playing": _main.audio._music.playing,
		"stream_paused": _main.audio._music.stream_paused,
		"audio_paused": _main.audio.is_paused(), "position": resumed_after_wait}
	if not movie_capture and not _require(resumed_after_wait > resumed_position,
			"ambient playback position advances after resume"):
		return false
	if not _require(view.feedback_counts().get("muzzles", -1) == 0,
			"muzzle and recoil expire after resume"):
		return false

	view.reduced_effects = true
	_reset_combat()
	_set_player_weapon(&"shotgun")
	_spawn_enemy(&"grunt", sim.player.pos + Vector2(92.0, 0.0), 1000.0, 0.0, 0.0)
	sim.step(DT, Vector2.ZERO)
	var profile := ArenaPainter.weapon_feedback_profile(&"shotgun")
	var expected: float = float(profile.get("recoil", 0.0)) * 0.5
	if not _require(bool(view.motion_stats().get("reduced", false))
			and is_equal_approx(view.recoil_amount(-1, &"shotgun"), expected),
			"reduced effects halves authoritative mounted recoil"):
		return false
	_summary["motion"] = {"idle": true, "moving": true, "settled": true,
		"pause_froze_expiry": true, "ambient_stream_paused": true,
		"paused_combat_blocked": true, "paused_ui_allowed": true,
		"reduced_recoil": expected}
	_summary["audio_pause_diagnostic"] = pause_diagnostic
	print("feedback audio pause diagnostic: %s" % JSON.stringify(pause_diagnostic))
	view.reduced_effects = false
	return true


func _shop_feedback_case() -> bool:
	var sim: Sim = _main.sim
	_reset_combat()
	sim.phase = Sim.Phase.SHOP
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.materials = 200
	sim.shop.clear_history()
	sim.shop.offers.clear()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"smg")
	offer.price = 24
	sim.shop.offers.append(offer)
	var ui: ShopUi = _main.shop_ui
	ui.open(sim)
	ui.set_reduced_effects(false)
	await _wait_frames(3)
	var old_empty: ShopDropTarget = ui.build_panel.empty_drop_target
	var apply_audio: int = _main.audio.play_count(&"equipment_apply")
	var material_runs: int = ui.material_feedback_runs
	var card := ui.offers_box.get_child(0) as OfferCard
	if not (await _activate(card)):
		return false
	if not _require(sim.player.weapons.size() == 2 and sim.player.weapons[1].id == &"smg",
			"focused offer buys a weapon through Shop.apply"):
		return false
	if not _require(ui.pending_feedback_count() == 0,
			"deferred equipment feedback flushes after the rebuilt UI exists"):
		return false
	if not _require(not is_instance_valid(old_empty) or not old_empty.is_inside_tree(),
			"old empty target is not retained after refresh"):
		return false
	var bought_target: ShopDropTarget = ui.build_panel.slot_drop_targets[1]
	if not _require(bought_target.feedback_runs == 1 and not bought_target.last_feedback_reverse,
			"current bought slot receives one forward seating feedback"):
		return false
	if not _require(ui.material_feedback_runs == material_runs + 1
			and ui.last_feedback.get("kind", &"") == &"materials"
			and ui.last_feedback.get("action", &"") == ShopResult.BUY
			and not bool(ui.last_feedback.get("reverse", true)),
			"current materials counter receives one forward purchase feedback"):
		return false
	if not _require(_main.audio.play_count(&"equipment_apply") == apply_audio + 1,
			"equipment apply audio plays once"):
		return false
	if not (await _save("shop_apply")):
		return false

	var undo_audio: int = _main.audio.play_count(&"equipment_undo")
	if not (await _activate(ui.undo_button)):
		return false
	if not _require(sim.player.weapons.size() == 1 and sim.player.weapons[0].id == &"pistol",
			"focused undo removes the purchased slot"):
		return false
	if not _require(not is_instance_valid(bought_target) or not bought_target.is_inside_tree(),
			"removed slot control is not retained"):
		return false
	var empty_target: ShopDropTarget = ui.build_panel.empty_drop_target
	if not _require(empty_target != null and empty_target.feedback_runs == 1
			and empty_target.last_feedback_reverse,
			"current empty mount receives reverse undo feedback"):
		return false
	if not _require(ui.material_feedback_runs == material_runs + 2
			and ui.last_feedback.get("kind", &"") == &"materials"
			and ui.last_feedback.get("action", &"") == ShopResult.UNDO
			and bool(ui.last_feedback.get("reverse", false)),
			"current materials counter receives one reverse undo feedback"):
		return false
	if not _require(_main.audio.play_count(&"equipment_undo") == undo_audio + 1,
			"equipment undo audio plays once"):
		return false
	if not (await _save("shop_undo")):
		return false
	_summary["shop"] = {"buy_feedback_runs": 1, "undo_feedback_runs": 1,
		"material_feedback_runs": ui.material_feedback_runs, "stale_controls_retained": false}
	return true


func _cleanup_case() -> bool:
	var view: ArenaView = _main._view
	var ui: ShopUi = _main.shop_ui
	_main.show_select()
	await _wait_frames(3)
	if not _require(_main.sim == null and view.sim == null and _main.hud.sim == null,
			"returning to character select releases Main, View and HUD Sim references"):
		return false
	for raw: Variant in view.feedback_counts().values():
		if not _require(int(raw) == 0, "returning to select clears every ArenaView feedback queue"):
			return false
	var motion: Dictionary = view.motion_stats()
	var motion_checks := {
		"moving_rest": not bool(motion.get("moving", true)),
		"amount_zero": is_zero_approx(float(motion.get("amount", -1.0))),
		"speed_zero": is_zero_approx(float(motion.get("speed", -1.0))),
		"visual_time_zero": is_zero_approx(float(motion.get("visual_time", -1.0))),
		"paused_false": not bool(motion.get("paused", true)),
		"recoil_zero": is_zero_approx(float(motion.get("max_recoil", -1.0))),
	}
	print("feedback cleanup motion diagnostic: %s" % JSON.stringify({
		"motion": motion, "checks": motion_checks, "view_visible": view.visible,
		"view_sim_null": view.sim == null,
	}))
	if not _require(not bool(motion.get("moving", true))
			and is_zero_approx(float(motion.get("amount", -1.0)))
			and is_zero_approx(float(motion.get("speed", -1.0)))
			and is_zero_approx(float(motion.get("visual_time", -1.0)))
			and not bool(motion.get("paused", true))
			and is_zero_approx(float(motion.get("max_recoil", -1.0))),
			"ArenaView motion and recoil return to rest"):
		return false
	if not _require(view._paths.is_empty() and view._reveal.is_empty() and view._sparks.is_empty()
			and view.position == Vector2.ZERO and view.character_id == &"looper",
			"ArenaView paths, sparks, transform and identity reset"):
		return false
	var audio_state: Dictionary = _main.audio.binding_state()
	if not _require(not bool(audio_state.get("sim_bound", true))
			and not bool(audio_state.get("shop_bound", true))
			and not bool(audio_state.get("paused", true))
			and int(audio_state.get("active_sfx", -1)) == 0
			and int(audio_state.get("cooldowns", -1)) == 0
			and int(audio_state.get("routed_voices", -1)) == 0,
			"GameAudio releases bindings, SFX, cooldowns and routed voices"):
		return false
	if not _require(bool(audio_state.get("ambient_playing", false))
			and not bool(audio_state.get("ambient_paused", true)),
			"session cleanup preserves unpaused ambient playback"):
		return false
	if not _require(not ui.visible and ui.sim == null and ui.pending_feedback_count() == 0
			and ui._connected_shop == null and ui._connected_sim == null
			and ui._replacing == null and ui._replacing_index == -1,
			"ShopUi releases session bindings, history selection and feedback"):
		return false
	if not _require(ui.offers_box.get_child_count() == 0 and ui._overlay.get_child_count() == 0,
			"ShopUi removes stale offer and overlay controls"):
		return false
	if not _require(ui.build_panel._box.get_child_count() == 0
			and ui.build_panel.slot_drop_targets.is_empty()
			and ui.build_panel.empty_drop_target == null
			and ui.build_panel.items_drop_target == null
			and not ui.build_panel._quote_drop.is_valid()
			and not ui.build_panel._apply_drop.is_valid()
			and not ui.build_panel._clear_drop.is_valid(),
			"BuildPanel releases cards, targets and drop callables"):
		return false
	if not _require(ui.echo_panel._sim == null and not ui.echo_panel._merge_mode
			and ui.echo_panel._merge_first == null and ui.echo_panel.last_new_row == null
			and ui.echo_panel.discard_buttons.is_empty() and ui.echo_panel.merge_button == null
			and ui.echo_panel._box.get_child_count() == 0,
			"EchoPanel releases run, merge and generated control state"):
		return false
	if not _require(_main.character_select.visible, "character selection is visible after cleanup"):
		return false
	_summary["cleanup"] = {"main_sim": null, "view_feedback": 0, "audio_bound": false,
		"shop_pending": 0, "stale_controls": 0, "character_select_visible": true}
	return true


func _reset_combat() -> void:
	var sim: Sim = _main.sim
	sim.phase = Sim.Phase.WAVE
	sim.wave_duration = 60.0
	sim.wave_time = 0.0
	sim._plan.clear()
	sim._plan_idx = 0
	sim.enemies.clear()
	sim.projectiles.clear()
	sim.pickups.clear()
	sim.pending.clear()
	sim.echoes.clear()
	sim.bank.takes.clear()
	sim.grid.clear()
	sim.player.pos = Sim.ARENA.get_center()
	sim.player.facing = Vector2.RIGHT
	sim.player.iframes = 0.0
	sim.player.hp = sim.player.max_hp()


func _set_player_weapon(id: StringName) -> void:
	var player: PlayerState = _main.sim.player
	player.weapons.clear()
	player.weapon_levels.clear()
	player.cooldowns.clear()
	player.add_weapon(Content.weapon(id))


func _spawn_enemy(id: StringName, position: Vector2, hp: float, speed: float,
		damage: float) -> EnemyState:
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(id)
	spawn.pos = position
	_main.sim._materialize(spawn)
	var enemy: EnemyState = _main.sim.enemies[_main.sim.enemies.size() - 1]
	enemy.max_hp = hp
	enemy.hp = hp
	enemy.speed = speed
	enemy.damage = damage
	return enemy


func _activate(button: Button) -> bool:
	if not _require(button != null and button.is_visible_in_tree() and not button.disabled,
			"focused shop action is available"):
		return false
	button.grab_focus()
	await _wait_frames(2)
	if not _require(button.has_focus(), "focused shop action owns focus"):
		return false
	_push_action(&"ui_accept", true)
	await process_frame
	_push_action(&"ui_accept", false)
	await _wait_frames(4)
	return not _failed


func _push_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	root.push_input(event, false)


func _is_movie_capture() -> bool:
	for argument: String in OS.get_cmdline_args():
		if argument == "--write-movie" or argument.begins_with("--write-movie="):
			return true
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--feedback-capture":
			return true
	return false


func _save(name: String) -> bool:
	var shop_capture := name.begins_with("shop_")
	if shop_capture:
		if not _require(_main.shop_ui.visible,
				"%s capture has the actual ShopUi visible" % name):
			return false
	else:
		if not _require(_main._view.visible and _main.hud.visible
				and not _main.shop_ui.visible and _main.sim.phase == Sim.Phase.WAVE,
				"%s capture has the arena and HUD visible" % name):
			return false
	_main._view.queue_redraw()
	_main.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty()
			and image.get_width() == 1280 and image.get_height() == 720,
			"%s capture readback is a non-empty 1280x720 frame" % name):
		return false
	var content_samples := _content_sample_count(image)
	if not _require(content_samples >= 24,
			"%s capture contains visible non-background content" % name):
		return false
	var path := _shots_dir.path_join("feedback_%s.png" % name)
	var error := image.save_png(path)
	if error != OK:
		_fail("failed to save feedback_%s.png: %s" % [name, error])
		return false
	if not _summary.has("screenshots"):
		_summary["screenshots"] = {}
	var screenshots: Dictionary = _summary["screenshots"]
	screenshots[name] = {"width": image.get_width(), "height": image.get_height(),
		"content_samples": content_samples, "shop": shop_capture}
	_summary["screenshots"] = screenshots
	print("wrote shots/feedback_%s.png (%d content samples)" % [name, content_samples])
	return true


func _content_sample_count(image: Image) -> int:
	var count := 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) >= 0.14:
				count += 1
	return count


func _write_summary() -> void:
	var file := FileAccess.open(_shots_dir.path_join("feedback_summary.json"), FileAccess.WRITE)
	if file == null:
		_fail("failed to open feedback summary")
		return
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	print("wrote shots/feedback_summary.json")


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
	printerr("feedback probe FAILED: %s" % message)
	if _main != null and _main.audio != null:
		_main.audio.stop_all()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["feedback_probe_save.json", "feedback_probe_runs.jsonl",
			"feedback_probe_settings.json"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
