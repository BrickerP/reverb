extends SceneTree
# Native, bounded Main/Sim evidence. Run without --headless. All scenario setup
# is disclosed in summary.json; game rules, hits and UI actions use production
# code. This is a scripted fixture, not evidence of human/controller usability.
# REVERB_LANG=en|zh REVERB_PROBE_REDUCED=0|1 REVERB_PROBE_SIZE=1280x720
# godot --path . --disable-vsync --script res://tools/core_gameplay_probe.gd

const DEADLINE_MSEC := 180000
const ROLES: Array[StringName] = [&"looper", &"solo", &"mirror", &"conductor", &"mender", &"overloader"]
const RETIRE_WEAPONS: Array[StringName] = [&"stapler", &"stamp", &"shotgun", &"ink_bottle", &"rubber_band", &"hex_bolt"]
const RETIRE_KINDS: Array[StringName] = [&"pin", &"stamp", &"cut", &"ink", &"return", &"arc"]

var _main: Node
var _started := Time.get_ticks_msec()
var _failed: Array[String] = []
var _shots_dir := ""
var _fixture_dir := ""
var _reduced := false
var _finished := false
var _frames := 0
var _summary: Dictionary = {"probe": "core_gameplay", "coverage": [], "fixtures": [],
	"screenshots": {}, "weapons": [], "combos": [], "retirements": [], "enemy_states": {},
	"gait": [], "music": [], "peak": {}, "limits": {"fields": Combat.MAX_ACTIVE_FIELDS,
	"projectiles": Combat.MAX_PROJECTILES, "enemy_zones": EnemyBrain.MAX_ZONES,
	"sparks": ArenaView.MAX_SPARKS, "muzzles": ArenaView.MAX_MUZZLES,
	"hits": ArenaView.MAX_HITS, "explosions": ArenaView.MAX_EXPLOSIONS,
	"hurts": ArenaView.MAX_HURTS, "weapon_changes": ArenaView.MAX_WEAPON_CHANGES,
	"corpses": BattleDirector.MAX_CORPSES, "actor_actions": BattleDirector.MAX_SHOT_ACTORS,
	"music_voices": 2, "sfx_voices": 12},
	"scope": "Native scripted Main/Sim fixture with actual delta, input events, pixels and live streams; no human usability claim"}


func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	_reduced = OS.get_environment("REVERB_PROBE_REDUCED") == "1"
	var language := OS.get_environment("REVERB_LANG")
	Loc.lang = language if language in ["en", "zh"] else "en"
	var dimensions := OS.get_environment("REVERB_PROBE_SIZE")
	if dimensions == "":
		dimensions = "1280x720"
	var parts := dimensions.split("x")
	if parts.size() == 2 and int(parts[0]) >= 640 and int(parts[1]) >= 480:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	var profile := "%s-%s-%s" % [Loc.lang, "reduced" if _reduced else "standard", dimensions]
	_shots_dir = ProjectSettings.globalize_path("res://shots/core-gameplay/" + profile)
	_fixture_dir = "user://core_gameplay_probe/" + profile
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_fixture_dir))
	var isolated_files := {"REVERB_SAVE": "meta.json", "REVERB_SETTINGS": "settings.json",
			"REVERB_RUN_LOG": "runs.jsonl", "REVERB_FEEDBACK_LOG": "feedback.jsonl",
			"REVERB_SUSPEND": "suspend.json"}
	for entry: String in isolated_files:
		var file: String = _fixture_dir.path_join(isolated_files[entry])
		OS.set_environment(entry, file)
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	_summary["profile"] = profile
	_summary["coverage_meaning"] = "Executed scenario IDs; success additionally requires failures to be empty"
	_summary["render_method"] = "manual force_draw each native process frame; render-loop counters are not treated as screen evidence"
	_summary["native_display"] = DisplayServer.get_name()
	_check(DisplayServer.get_name() != "headless", "native display driver is required")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if not _finished and Time.get_ticks_msec() - _started > DEADLINE_MSEC:
		_check(false, "bounded native probe exceeded 180 seconds")
		_finish()
	if not _finished:
		RenderingServer.force_draw()
		_record_peaks()
	return false


func _run() -> void:
	await _wait(0.15)
	if _main.character_select == null:
		_check(false, "Main reached character selection")
		_finish()
		return
	_main.settings.reduced_effects = _reduced
	_main._apply_reduced_effects()
	_summary["window_size"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	_summary["logical_viewport"] = str(root.get_visible_rect())
	await _selection_and_codex()
	await _all_weapons()
	await _combos()
	await _battle_suspend()
	await _enemies()
	await _world_and_wheel()
	await _echo_lifecycle()
	await _shop_story_suspend()
	await _pending_boon_suspend()
	await _gait_and_read_only()
	await _audio_and_settings()
	_finish()


func _selection_and_codex() -> void:
	for role in ROLES:
		_main.meta.unlocked[role] = true
	_main.character_select.refresh(_main.meta)
	_fixture("selection", "All six Meta unlocks staged so every real role card can be activated")
	await _wait(0.08)
	_check(_main.character_select._cards.size() == 6, "all six role cards exist")
	_capture("selection_six_roles")
	for index in ROLES.size():
		var card: Button = _main.character_select._cards[index]
		await _activate(card)
		_check(_main.sim != null and _main.character_id == ROLES[index], "real role activation: " + ROLES[index])
		_main.show_select()
		await _wait(0.04)
	_cover("six_roles_actual_ui")
	await _activate(_button(_main.character_select, "select.codex"))
	var codex: CodexUi = _main.codex_ui
	_check(codex.visible and codex._cards.size() == 24, "codex has all 18 shop weapons and six evolutions")
	var card_count := 0
	var actual_ids: Array[StringName] = []
	var card_index := 0
	for index in codex.chapters.size():
		codex.archive_scroll.ensure_control_visible(codex.chapters[index])
		await _wait(0.06)
		_capture("codex_" + String(CodexUi.FAMILIES[index]))
		for weapon: WeaponDef in Content.weapons().values():
			if weapon.family != CodexUi.FAMILIES[index]:
				continue
			var card: Control = codex._cards[card_index]
			codex.archive_scroll.ensure_control_visible(card)
			await _wait(0.04)
			_check(codex.archive_scroll.get_global_rect().grow(1.0).encloses(card.get_global_rect()), "codex scroll actually exposes complete card: " + weapon.id)
			_capture("codex_card_" + weapon.id)
			actual_ids.append(weapon.id)
			card_index += 1
			card_count += 1
	_summary["codex_cards"] = card_count
	_summary["codex_card_ids"] = actual_ids
	await _key(KEY_ESCAPE)
	_cover("codex_24_actual_cards")


func _all_weapons() -> void:
	var styles: Dictionary = {}
	for id: StringName in Content.weapons():
		var sim := _stage("weapon_" + id, &"looper")
		_loadout(sim, [id])
		var enemy := _enemy(sim, &"grunt", Vector2(300.0, 200.0), 10000.0)
		var shots: Array[StringName] = []
		var first_fire := {"wave_time": -1.0}
		# The fixture signal must not keep its own RefCounted simulation alive.
		var sim_ref: WeakRef = weakref(sim)
		sim.shot_fired_info.connect(func(info: ShotInfo) -> void:
			shots.append(info.weapon_id)
			if float(first_fire["wave_time"]) < 0.0:
				var firing_sim: Sim = sim_ref.get_ref()
				if firing_sim != null:
					first_fire["wave_time"] = firing_sim.wave_time)
		var weapon := Content.weapon(id)
		var capture_delay := weapon.windup * 0.5 if weapon.attack_style == &"slam" else 0.06 if weapon.attack_style in [&"cone", &"chain", &"projectile", &"pin", &"line"] else 0.14
		await _wait(capture_delay)
		_capture("weapon_" + id)
		if weapon.attack_style == &"slam":
			_capture("weapon_" + id + "_warning")
			if id == &"stamp":
				await _field_geometry_pixels("weapon_stamp_warning")
			await _wait_until_wave_time(sim, float(first_fire["wave_time"]) + weapon.windup + 0.03)
			_capture("weapon_" + id + "_hit")
		elif id in [&"hole_punch", &"ink_bottle"]:
			await _field_geometry_pixels("weapon_" + id + "_field")
		await _wait(0.60)
		_check(shots.has(id), "production step_weapons fired " + id)
		_check(enemy.hp < enemy.max_hp, "actual damage from " + id)
		styles[weapon.attack_style] = true
		(_summary["weapons"] as Array).append({"id": id, "style": weapon.attack_style,
			"shots": shots.size(), "damage": enemy.max_hp - enemy.hp,
			"fields": sim.attack_fields.size(), "projectiles": sim.projectiles.size(),
			"pin_left": enemy.pin_left, "ink_left": enemy.ink_left,
			"capture_delay": capture_delay, "windup": weapon.windup,
			"first_fire_wave_time": first_fire["wave_time"]})
	_check((_summary["weapons"] as Array).size() == 24, "all 24 weapons executed")
	_check(styles.size() == 11, "all 11 distinct production attack styles executed")
	_check((_summary.get("field_geometry_pixels", {}) as Dictionary).size() == 3,
			"stamp warning, line and ink each have actual native pixel evidence")
	_summary["attack_styles"] = styles.keys()
	_cover("24_weapons_11_real_attack_styles")


func _combos() -> void:
	var sim := _stage("pin_press", &"looper")
	var target := _enemy(sim, &"grunt", Vector2(300.0, 200.0), 10000.0)
	_loadout(sim, [&"stapler"])
	await _wait(0.18)
	_check(target.pin_left > 0.0, "actual projectile collision applied pin")
	_loadout(sim, [&"stamp"])
	await _wait(0.22)
	_capture("combo_pin_press_warning")
	var press_hit_time := sim.wave_time + 0.03
	for field in sim.attack_fields:
		if field.weapon_id == &"stamp" and field.windup > 0.0:
			press_hit_time += field.windup
			break
	await _wait_until_wave_time(sim, press_hit_time)
	_capture("combo_pin_press_hit")
	sim = _stage("ink_arc", &"looper")
	target = _enemy(sim, &"grunt", Vector2(300.0, 200.0), 10000.0)
	for index in 4:
		_enemy(sim, &"grunt", Vector2(320.0 + index * 16.0, 214.0), 10000.0)
	_loadout(sim, [&"ink_bottle"])
	await _wait(0.15)
	_check(target.ink_left > 0.0, "actual ink field applied wet state")
	_loadout(sim, [&"hex_bolt"])
	await _wait(0.14)
	_capture("combo_ink_arc")
	var found: Dictionary = {}
	for info: Dictionary in _summary["combos"]:
		found[info["id"]] = true
	_check(found.has("pin_press") and found.has("ink_arc"), "both real combo events emitted")
	_cover("pin_press_and_ink_arc_real_events")


func _enemies() -> void:
	var sim := _stage("enemy_brains", &"looper")
	var runner := _enemy(sim, &"runner", Vector2(420.0, 200.0), 10000.0)
	var brute := _enemy(sim, &"brute", Vector2(200.0, 310.0), 10000.0)
	var silencer := _enemy(sim, &"silencer", Vector2(385.0, 350.0), 10000.0)
	await _wait(0.12)
	_check(runner.brain_state == &"warn" and brute.brain_state == &"warn" and silencer.brain_state == &"seal", "enemy warnings arise from production brains")
	_capture("enemy_windups")
	var states: Dictionary = {"runner": [], "brute": [], "silencer": []}
	var active_zone_seen := false
	for index in 150:
		for enemy in [runner, brute, silencer]:
			var seen: Array = states[String(enemy.def.id)]
			if not seen.has(enemy.brain_state):
				seen.append(enemy.brain_state)
		for zone in sim.enemy_zones:
			active_zone_seen = active_zone_seen or zone.is_active()
		if index in [35, 48, 70, 115]:
			_capture("enemy_phase_%03d" % index)
		await _wait(0.02)
	_check((states["runner"] as Array).has(&"dash") and (states["runner"] as Array).has(&"recover"), "runner entered real dash and recovery")
	_check((states["brute"] as Array).has(&"slam") and (states["brute"] as Array).has(&"recover"), "brute entered real directional slam and recovery")
	_check((states["silencer"] as Array).has(&"recover") and active_zone_seen, "silencer seal activated and caster recovered")
	_summary["enemy_states"] = states
	_summary["seal_active_seen"] = active_zone_seen
	_cover("enemy_windup_impact_recovery")


func _battle_suspend() -> void:
	var sim := _stage("battle_suspend", &"looper")
	_loadout(sim, [&"smg", &"stamp", &"ink_bottle", &"hole_punch"])
	_enemy(sim, &"runner", Vector2(300.0, 200.0), 10000.0)
	_enemy(sim, &"silencer", Vector2(380.0, 350.0), 10000.0)
	_take(sim, &"rubber_band", Vector2(2200.0, 1100.0), 65.0)
	await _wait(0.10)
	_check(not sim.attack_fields.is_empty() and not sim.enemy_zones.is_empty(), "battle save contains actual active attacks and enemy warning plans")
	_capture("battle_active_before_suspend")
	await _save_continue_exact("battle")
	_cover("battle_active_fields_world_positions_warning_plans_exact_ui_suspend")


func _world_and_wheel() -> void:
	var sim := _stage("world_machine", &"looper")
	sim.player.pos = Vector2(430.0, 390.0)
	_fixture("world_machine", "Player staged west of first machine; real held D must stop on its collision boundary")
	await _hold(KEY_D, 0.65)
	_check(sim.player.pos.x <= 486.01 - PlayerState.RADIUS and WorldArena.body_clear(sim.player.pos, PlayerState.RADIUS), "machine stops real player movement")
	_capture("machine_collision")
	sim = _stage("world_scroll", &"looper")
	sim.player.pos = Vector2(1160.0, 200.0)
	var take := _take(sim, &"stamp", Vector2(2250.0, 1100.0), 72.0)
	_take(sim, &"longbow", Vector2(1900.0, 1120.0), 88.0)
	_take(sim, &"rubber_band", Vector2(2200.0, 1000.0), 64.0)
	sim.select_echo(take.uid)
	await _hold(KEY_D, 1.2)
	var camera: Dictionary = _main._view.camera_profile()
	var world_rect: Rect2 = camera["world_rect"]
	_check(sim.player.pos.x > Sim.VIEWPORT.end.x and world_rect.position.x > Sim.VIEWPORT.position.x, "real movement crosses former arena and scrolls camera")
	_check(Sim.ARENA.encloses(world_rect), "camera stays within large world")
	_check(bool(_main.hud.selected_echo_profile()["offscreen"]), "selected distant copy has real offscreen direction")
	_summary["world_scroll"] = {"player": _v(sim.player.pos), "camera": str(world_rect), "selected": _main.hud.selected_echo_profile()}
	_capture("world_scroll_offscreen_echo")
	var before_count := sim.bank.takes.size()
	await _send_key(KEY_SPACE, true)
	await _wait(0.36)
	_check(_main.echo_wheel.visible and _main.paused, "real held Space opens paused copy wheel")
	_capture("held_selection_wheel")
	await _key(KEY_RIGHT)
	var chosen: int = _main.echo_wheel.selected_uid()
	await _send_key(KEY_SPACE, false)
	await _wait(0.06)
	_check(not _main.echo_wheel.visible and not _main.paused and sim.selected_echo_uid == chosen, "release commits highlight and resumes")
	_check(sim.bank.takes.size() == before_count, "held selection never retires a copy")
	await _send_joy(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _wait(0.36)
	_check(_main.echo_wheel.visible and Controls.retire_label() == "RB", "real RB event opens device-correct wheel")
	_capture("gamepad_selection_wheel")
	await _joy(JOY_BUTTON_B)
	await _send_joy(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _wait(0.05)
	_check(not _main.echo_wheel.visible and sim.bank.takes.size() == before_count, "cancel then shoulder release never retires")
	await _hud_clip_and_snapshot()
	_cover("large_world_camera_machine_offscreen_copy")
	_cover("space_rb_hold_release_cancel_no_retire")


func _echo_lifecycle() -> void:
	var sim := _stage("mender_pickup", &"mender")
	var take := _take(sim, &"tape_spool", Vector2(250.0, 200.0), 55.0)
	sim.select_echo(take.uid)
	var before := take.condition
	await _wait(0.22)
	var after_wear := take.condition
	_check(after_wear < before, "deployed echo condition wears with real combat time")
	var pickup := Pickup.new()
	pickup.pos = sim.player.pos
	pickup.value = 12
	sim.pickups.append(pickup)
	_fixture("mender_pickup", "Damaged selected copy and 12-material pickup staged at player; collection and repair use Sim.step")
	await _wait(0.08)
	_check(take.condition > after_wear and sim.player.materials >= Sim.START_MATERIALS + 12, "Mender real collection repairs selected copy")
	_summary["mender"] = {"before": before, "after_wear": after_wear, "after_pickup": take.condition, "repair_discount": sim.repair_discount}
	_capture("mender_pickup_repair")
	for index in RETIRE_WEAPONS.size():
		sim = _stage("retire_" + RETIRE_KINDS[index], &"overloader")
		_enemy(sim, &"grunt", Vector2(300.0, 200.0), 10000.0)
		take = _take(sim, RETIRE_WEAPONS[index], Vector2(210.0, 200.0), 60.0)
		sim.select_echo(take.uid)
		EchoSystem.selected_actor(sim).cooldowns.fill(10.0)
		_fixture("retirement_isolation", "Recorded firing cooldowns staged at 10s, so observed damage comes from the real short-press retirement skill")
		var profile := EchoSystem.skill_profile(take, sim)
		_check(profile["kind"] == RETIRE_KINDS[index] and sim.retirement_mult > 1.0 and sim.wear_rate_mult > 1.0, "Overloader has actual category and tradeoff: " + RETIRE_KINDS[index])
		await _key(KEY_SPACE)
		_check(sim.bank.find_uid(take.uid) == null, "short Space consumes selected copy: " + RETIRE_KINDS[index])
		await _wait(0.08)
		_capture("retire_" + RETIRE_KINDS[index])
		await _wait(0.28)
		_check(not sim.enemies.is_empty() and sim.enemies[0].hp < sim.enemies[0].max_hp, "retirement category causes real damage: " + RETIRE_KINDS[index])
		await _key(KEY_SPACE)
		_check(sim.bank.takes.is_empty(), "empty second press is inert")
	sim = _stage("exhausted", &"looper")
	take = _take(sim, &"stamp", Vector2(250.0, 200.0), 0.12)
	_fixture("exhausted", "Condition staged at 0.12; natural wear must exhaust without active skill")
	await _wait(0.25)
	_check(sim.bank.find_uid(take.uid) == null and sim.attack_fields.is_empty() and sim.projectiles.is_empty(), "natural exhaustion consumes copy without full skill")
	_capture("echo_exhaustion")
	var kinds: Dictionary = {}
	var exhausted_seen := false
	for event: Dictionary in _summary["retirements"]:
		if bool(event["exhausted"]):
			exhausted_seen = true
		else:
			kinds[event["kind"]] = true
	_check(kinds.size() == 6 and exhausted_seen, "all six real retirement events plus exhaustion observed")
	_cover("wear_mender_overloader_six_retirements_exhaustion")


func _shop_story_suspend() -> void:
	var sim := _stage("shop_transactions", &"mender")
	var take := _take(sim, &"stamp", Vector2(250.0, 220.0), 45.0)
	_loadout(sim, [&"pistol", &"smg", &"rifle", &"orb", &"tape_spool", &"shotgun"])
	sim.player.materials = 999
	sim.wave = 2
	sim.wave_duration = sim.wave_time + 0.05
	_fixture("shop_transactions", "Wave index 2, six equipped slots, 999 materials and damaged copy staged; actual timer ends wave and records new copy/receipt")
	await _wait(0.85)
	_check(sim.phase == Sim.Phase.SHOP and _main.shop_ui.visible, "actual wave end enters shop")
	_check(_main.shop_ui.receipt_button.visible, "real milestone exposes optional receipt")
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"mallet")
	offer.price = 30
	sim.shop.offers[0] = offer
	_fixture("shop_transactions", "First existing offer staged to priced mallet to exercise full-slot replacement deterministically")
	_main.shop_ui.refresh()
	await _wait(0.06)
	_capture("shop_full_slots_and_receipt")
	var card: OfferCard = _main.shop_ui.offers_box.get_child(0)
	await _activate(card)
	_check(_main.shop_ui.is_replacing(), "real full-slot offer opens replacement")
	_capture("shop_replace_targets")
	await _activate(_main.shop_ui.build_panel._slot_buttons[0])
	_check(sim.player.weapons[0].id == &"mallet" and sim.player.weapons.size() == 6, "real slot action replaces weapon")
	_capture("shop_replaced")
	# EchoPanel intentionally presents newest first; the bank keeps arrival order.
	var damaged_index := sim.bank.takes.size() - 1 - sim.bank.takes.find(take)
	var repaired_uid := take.uid
	var before_condition := take.condition
	var before_materials := sim.player.materials
	await _activate(_main.shop_ui.echo_panel.repair_buttons[damaged_index])
	_check(take.condition > before_condition and sim.player.materials < before_materials, "real repair UI spends materials and restores condition")
	await _activate(_main.shop_ui.undo_button)
	var restored_take := sim.bank.find_uid(repaired_uid)
	_check(restored_take != null and restored_take.condition == before_condition and sim.player.materials == before_materials, "repair undo restores exact condition and material quote")
	await _activate(_main.shop_ui.receipt_button)
	_check(_main.receipt_ui.visible, "receipt opens through real shop action")
	_capture("story_receipt")
	await _activate(_main.receipt_ui.archive_button)
	_check(_main.story_ui.visible and _main.story_ui.row_count() > 0, "receipt action opens discovered archive")
	_capture("story_archive")
	await _activate(_main.story_ui.close_button)
	await _save_continue_exact("shop")
	_cover("shop_full_slots_replace_repair_undo_receipt_archive")
	_cover("save_return_continue_actual_ui_exact_snapshot")


func _save_continue_exact(label: String) -> void:
	await _key(KEY_P)
	_check(_main.pause_ui.visible, "actual P opens " + label + " pause")
	var before_snapshot := RunSnapshot.capture(_main.sim)
	_check(not before_snapshot.is_empty(), label + " suspend captures nonempty authoritative state")
	var preflight: bool = RunSnapshot.restore(before_snapshot) != null
	_check(preflight, label + " fixture satisfies strict snapshot validation: " + RunSnapshot.last_error)
	_main.set_physics_process(false)
	await _activate(_main.pause_ui.save_button)
	var saved: bool = _main.sim == null and _main.character_select.visible and _main.character_select.continue_button.visible
	_check(saved, "actual " + label + " Save and Return releases run and offers Continue")
	if not _summary.has("suspend"):
		_summary["suspend"] = {}
	_summary["suspend"][label] = {"fixture_valid": preflight, "save_return_succeeded": saved,
		"full_snapshot_equal": false, "path": SuspendStore.path(), "actual_ui_actions": ["pause_save"]}
	if not saved:
		var diagnostic := {"stage": label, "suspend_error": SuspendStore.last_error,
			"snapshot_error": RunSnapshot.last_error, "pause_error": _main.pause_ui.error_label.text,
			"sim_present": _main.sim != null, "title_visible": _main.character_select.visible}
		_summary["suspend"][label]["failure_diagnostic"] = diagnostic
		printerr("core gameplay suspend diagnostic: " + JSON.stringify(diagnostic))
		_capture(label + "_save_failed")
		_main.set_physics_process(true)
		return
	_capture(label + "_saved_title_continue")
	await _activate(_main.character_select.continue_button)
	var exact: bool = not _main.character_select.visible and _main.sim != null and RunSnapshot.capture(_main.sim) == before_snapshot
	_check(exact, "actual Continue restores complete " + label + " snapshot exactly")
	_main.set_physics_process(true)
	_capture(label + "_continued")
	_summary["suspend"][label]["full_snapshot_equal"] = exact
	_summary["suspend"][label]["actual_ui_actions"] = ["pause_save", "title_continue"]


func _pending_boon_suspend() -> void:
	var sim := _stage("pending_boon_suspend", &"looper")
	sim.endless = true
	sim.start_wave(25)
	sim._plan.clear()
	sim.pending.clear()
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(&"paradox")
	spawn.pos = Vector2(300.0, 200.0)
	sim._materialize(spawn)
	sim.boss.hp = 1.0
	sim.boss.max_hp = 1.0
	_loadout(sim, [&"pistol"])
	_fixture("pending_boon_suspend", "Endless wave 25 and a canonical 1-HP boss staged; actual pistol collision ends the boss wave, rolls boons through the simulation RNG and opens the production BoonUi")
	await _wait(0.5)
	if not _check(sim.phase == Sim.Phase.SHOP and _main.boon_ui.visible and sim.pending_boons.size() == 3,
			"real endless boss kill opens three pending boon choices"):
		return
	_main.boon_ui.save_button.grab_focus()
	_capture("pending_boon_save_button")
	var before_snapshot := RunSnapshot.capture(sim)
	_check(not before_snapshot.is_empty(), "pending boon captures nonempty authoritative state")
	var before_choices: Array[StringName] = sim.pending_boons.duplicate()
	var before_rng: int = sim.rng.state
	var before_hazard_rng: int = sim.hazard_rng.state
	await _activate(_main.boon_ui.save_button)
	var saved: bool = _main.sim == null and _main.character_select.visible and not _main.boon_ui.visible and _main.character_select.continue_button.visible
	_check(saved, "real boon Save and Return closes pending choices and offers Continue")
	if not _summary.has("suspend"):
		_summary["suspend"] = {}
	_summary["suspend"]["pending_boon"] = {"save_return_succeeded": saved,
		"full_snapshot_equal": false, "both_rngs_equal": false, "choices_equal": false,
		"before_choices": before_choices, "actual_ui_actions": ["boon_save"]}
	if not saved:
		_summary["suspend"]["pending_boon"]["failure_diagnostic"] = {
			"suspend_error": SuspendStore.last_error, "boon_error": _main.boon_ui.error_label.text}
		_capture("pending_boon_save_failed")
		return
	_capture("pending_boon_saved_title_continue")
	await _activate(_main.character_select.continue_button)
	var restored: Sim = _main.sim
	var exact := not before_snapshot.is_empty() and restored != null and RunSnapshot.capture(restored) == before_snapshot
	var rng_equal := restored != null and restored.rng.state == before_rng and restored.hazard_rng.state == before_hazard_rng
	var shown_choices: Array[StringName] = []
	for button: Button in _main.boon_ui.choice_buttons:
		shown_choices.append(button.get_meta(&"boon_id"))
	var choices_equal: bool = restored != null and restored.pending_boons == before_choices and shown_choices == before_choices
	_check(exact and rng_equal and choices_equal and _main.boon_ui.visible and not _main.character_select.visible,
			"Continue restores same pending boon screen, full state and both RNGs")
	_summary["suspend"]["pending_boon"]["full_snapshot_equal"] = exact
	_summary["suspend"]["pending_boon"]["both_rngs_equal"] = rng_equal
	_summary["suspend"]["pending_boon"]["choices_equal"] = choices_equal
	_summary["suspend"]["pending_boon"]["shown_choices"] = shown_choices
	_summary["suspend"]["pending_boon"]["actual_ui_actions"] = ["boon_save", "title_continue"]
	_capture("pending_boon_continued_same_choices")
	# Give the restored pending decision an inspectable native/movie interval,
	# then leave it through a real choice before the movement/settings fixtures.
	await _wait(2.0)
	if not _main.boon_ui.choice_buttons.is_empty():
		await _activate(_main.boon_ui.choice_buttons[0])
	_check(not _main.boon_ui.visible and _main.shop_ui.visible and _main.sim.pending_boons.is_empty(),
			"actual boon choice exits modal before gait and settings stages")
	await _wait(2.0)
	_cover("pending_boon_suspend")


func _gait_and_read_only() -> void:
	var sim := _stage("long_session_gait", &"looper")
	sim.wave_time = 1200.0
	sim.wave_duration = 1800.0
	_fixture("long_session_gait", "Simulation time staged at 1200s; subsequent movement is real. This does not claim a 20-minute human session")
	await _wait(0.08)
	for rate in [30, 60, 120, 144]:
		Engine.max_fps = rate
		var before_pos := sim.player.pos
		var before_phase: float = _main._view.motion_stats()["gait_phase"]
		await _hold(KEY_D, 0.36)
		var after_phase: float = _main._view.motion_stats()["gait_phase"]
		var distance := before_pos.distance_to(sim.player.pos)
		var expected := fposmod(before_phase + distance / 160.0 * TAU, TAU)
		_check(absf(angle_difference(after_phase, expected)) < 0.12, "native %d FPS sampling preserves distance gait at long session time" % rate)
		(_summary["gait"] as Array).append({"requested_fps": rate, "distance": distance,
			"before_phase": before_phase, "after_phase": after_phase, "expected": expected,
			"wave_time": sim.wave_time})
		_capture("gait_%d" % rate)
	Engine.max_fps = 60
	await _hud_clip_and_snapshot()
	_cover("native_long_session_gait_30_60_120_144_sampling")


func _audio_and_settings() -> void:
	var sim := _stage("music_battle", &"looper")
	await _wait(0.3)
	_music_record("battle")
	_check(_main.audio.music_state()["mode"] == &"battle" and bool(_main.audio.binding_state()["music_playing"]), "real native battle score plays")
	for index in 18:
		_enemy(sim, &"grunt", sim.player.pos + Vector2(130.0 + float(index % 6) * 22.0, 50.0 + float(index / 6) * 22.0), 10000.0)
	_fixture("music_pressure", "18 stationary real enemies staged near player; GameAudio derives pressure from their actual threat")
	await _wait(3.5)
	_music_record("pressure")
	_check(_main.audio.music_state()["mode"] == &"pressure", "real threat changes arrangement to pressure")
	_enemy(sim, &"paradox", Vector2(400.0, 280.0), 10000.0)
	await _wait(1.6)
	_music_record("boss")
	_check(_main.audio.music_state()["mode"] == &"boss", "real boss presence changes arrangement")
	await _key(KEY_P)
	var cursor: float = _main.audio.music_state()["cursor"]
	await _wait(0.15)
	_check(_main.audio.music_state()["cursor"] == cursor and bool(_main.audio.music_state()["paused"]), "pause holds actual score transport")
	await _activate(_main.pause_ui.settings_button)
	_check(_main.settings_ui.visible, "pause settings opens through actual button")
	_main.settings_ui.music_volume_slider.grab_focus()
	await _key(KEY_HOME)
	_check(is_zero_approx(_main.settings.music_volume) and _main.settings.effects_volume > 0.0, "real keyboard music slider mutes independently")
	_main.settings_ui.effects_volume_slider.grab_focus()
	await _key(KEY_END)
	_check(is_equal_approx(_main.settings.effects_volume, 1.0) and is_zero_approx(_main.settings.music_volume), "real effects slider preserves independent silent music")
	_capture("settings_independent_music_effects")
	await _key(KEY_ESCAPE)
	await _key(KEY_P)
	await _key(KEY_M)
	_check(_main.audio.is_muted(), "real M toggles mute")
	await _key(KEY_M)
	_check(not _main.audio.is_muted(), "real M restores mute state")
	sim.wave_duration = sim.wave_time + 0.05
	await _wait(0.9)
	_music_record("shop")
	_check(_main.audio.music_state()["mode"] == &"shop", "real wave completion changes arrangement to shop")
	_main.show_select()
	await _wait(0.3)
	_music_record("menu")
	_check(_main.audio.music_state()["mode"] == &"menu", "title resets actual score binding")
	_cover("real_music_menu_battle_pressure_boss_shop_pause_mute_sliders")


func _field_geometry_pixels(name: String) -> void:
	var sim: Sim = _main.sim
	var previous_main_paused: bool = _main.paused
	var previous_main_physics := _main.is_physics_processing()
	var previous_view_process: bool = _main._view.is_processing()
	var previous_view_physics: bool = _main._view.is_physics_processing()
	var previous_view_paused: bool = _main._view._paused
	var previous_hud_process: bool = _main.hud.is_processing()
	var previous_hud_paused: bool = _main.hud.paused
	_main.paused = true
	_main.set_physics_process(false)
	_main._view.set_process(false)
	_main._view.set_physics_process(false)
	_main._view.set_paused(true)
	_main.hud.set_process(false)
	_main.hud.paused = true
	var original_fields: Array[AttackField] = sim.attack_fields
	var before := RunSnapshot.capture(sim)
	_check(not before.is_empty() and not original_fields.is_empty(), name + " has nonempty real active fields and snapshot")
	var states := _field_rows(sim)
	_fixture(name, "Pixel negative control only: Main/view/HUD clocks frozen; original attack_fields array temporarily replaced with an empty typed array, then the exact original array restored before any gameplay tick. No attack or field is authored for the comparison")
	_main._view.queue_redraw()
	_main.hud.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var shown := root.get_texture().get_image()
	var hidden_fields: Array[AttackField] = []
	sim.attack_fields = hidden_fields
	_main._view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var hidden := root.get_texture().get_image()
	sim.attack_fields = original_fields
	_main._view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var exact := not before.is_empty() and before == RunSnapshot.capture(sim)
	_check(exact, name + " restores complete simulation snapshot and both RNGs after pixel control")
	var pixels_valid := shown != null and hidden != null and not shown.is_empty() and shown.get_size() == hidden.get_size()
	_check(pixels_valid, name + " compares actual matching native Image sizes")
	if pixels_valid:
		var scale := Vector2(shown.get_size()) / root.get_visible_rect().size
		var world_roi := Rect2i(Vector2i((Sim.VIEWPORT.position * scale).ceil()),
			Vector2i((Sim.VIEWPORT.size * scale).floor())).intersection(Rect2i(Vector2i.ZERO, shown.get_size()))
		var changed := _changed_pixels(shown, hidden, world_roi)
		_check(int(changed["world"]) > 50, name + " draws more than 50 visible attack-field pixels inside the world")
		_check(int(changed["outside"]) == 0, name + " changes no HUD or outside-world pixels")
		_store_capture(name + "_with_fields", shown)
		_store_capture(name + "_fields_hidden_control", hidden)
		_summary["screenshots"][name + "_fields_hidden_control"]["active_fields"] = []
		_summary["screenshots"][name + "_fields_hidden_control"]["field_count"] = 0
		_summary["screenshots"][name + "_fields_hidden_control"]["negative_control"] = true
		if not _summary.has("field_geometry_pixels"):
			_summary["field_geometry_pixels"] = {}
		_summary["field_geometry_pixels"][name] = {"world_changed_pixels": changed["world"],
			"hud_outside_changed_pixels": changed["outside"], "world_roi": str(world_roi),
			"image_size": [shown.get_width(), shown.get_height()], "full_snapshot_restored": exact,
			"active_fields": states, "field_count": states.size(), "clocks_frozen": true}
	_main.paused = previous_main_paused
	_main.set_physics_process(previous_main_physics)
	_main._view.set_paused(previous_view_paused)
	_main._view.set_process(previous_view_process)
	_main._view.set_physics_process(previous_view_physics)
	_main.hud.paused = previous_hud_paused
	_main.hud.set_process(previous_hud_process)
	_cover("actual_field_geometry_pixels_and_restored_snapshot")


func _changed_pixels(first: Image, second: Image, world_roi: Rect2i) -> Dictionary:
	# Compare quantized native pixels, with a two-byte tolerance for tiny edge
	# rounding. The same frozen scene is drawn twice; only real fields differ.
	first.convert(Image.FORMAT_RGBA8)
	second.convert(Image.FORMAT_RGBA8)
	var a := first.get_data()
	var b := second.get_data()
	var inside := 0
	var outside := 0
	for y in first.get_height():
		var row := y * first.get_width() * 4
		for x in first.get_width():
			var offset := row + x * 4
			if absi(int(a[offset]) - int(b[offset])) <= 2 and absi(int(a[offset + 1]) - int(b[offset + 1])) <= 2 \
					and absi(int(a[offset + 2]) - int(b[offset + 2])) <= 2 and absi(int(a[offset + 3]) - int(b[offset + 3])) <= 2:
				continue
			if world_roi.has_point(Vector2i(x, y)):
				inside += 1
			else:
				outside += 1
	return {"world": inside, "outside": outside}


func _field_rows(sim: Sim) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for field in sim.attack_fields:
		rows.append({"weapon_id": field.weapon_id, "style": field.style, "windup": field.windup,
			"age": field.age, "life": field.life, "pos": _v(field.pos), "origin": _v(field.origin),
			"actor_token": field.actor_token, "dead": field.dead})
	return rows


func _hud_clip_and_snapshot() -> void:
	var previous_pause: bool = _main.paused
	_main.paused = true
	var before := RunSnapshot.capture(_main.sim)
	_check(not before.is_empty(), "render read-only proof captures nonempty authoritative state")
	_main._view._process(0.125)
	_main.hud.queue_redraw()
	RenderingServer.force_draw()
	var shown := root.get_texture().get_image()
	_main._view.visible = false
	RenderingServer.force_draw()
	var hidden := root.get_texture().get_image()
	_main._view.visible = true
	RenderingServer.force_draw()
	_check(not before.is_empty() and before == RunSnapshot.capture(_main.sim), "drawing and camera leave full authoritative snapshot and both RNGs unchanged")
	_check(shown != null and hidden != null and not shown.is_empty() and shown.get_size() == hidden.get_size(), "clip check reads actual nonempty Image sizes")
	if shown != null and hidden != null and not shown.is_empty():
		var scale_y := float(shown.get_height()) / root.get_visible_rect().size.y
		var top := clampi(floori(Sim.VIEWPORT.position.y * scale_y), 1, shown.get_height())
		var bottom := clampi(ceili(Sim.VIEWPORT.end.y * scale_y), 0, shown.get_height())
		var top_equal := shown.get_region(Rect2i(0, 0, shown.get_width(), top)).get_data() == hidden.get_region(Rect2i(0, 0, hidden.get_width(), top)).get_data()
		var bottom_equal := true
		if bottom < shown.get_height():
			bottom_equal = shown.get_region(Rect2i(0, bottom, shown.get_width(), shown.get_height() - bottom)).get_data() == hidden.get_region(Rect2i(0, bottom, hidden.get_width(), hidden.get_height() - bottom)).get_data()
		_check(top_equal and bottom_equal, "arena pixels are clipped away from fixed HUD bands")
		_summary["hud_clip"] = {"image_size": [shown.get_width(), shown.get_height()], "top_rows": top,
			"bottom_start": bottom, "top_equal": top_equal, "bottom_equal": bottom_equal,
			"full_snapshot_read_only": not before.is_empty() and before == RunSnapshot.capture(_main.sim)}
	_main.paused = previous_pause
	_cover("full_snapshot_render_rng_read_only_and_hud_pixel_clip")


func _stage(name: String, role: StringName) -> Sim:
	_main.new_run(140140, role, 0)
	var sim: Sim = _main.sim
	sim._plan.clear()
	sim.pending.clear()
	sim.wave_duration = 180.0
	sim.player.pos = Vector2(200.0, 200.0)
	sim.player.stats.values[Stats.MAX_HP] = 10000.0
	sim.player.hp = 10000.0
	sim.player.stats.values[Stats.CRIT_CHANCE] = 0.0
	_loadout(sim, [])
	sim.combo_triggered.connect(func(info: ComboInfo) -> void: (_summary["combos"] as Array).append(info.to_dict()))
	sim.echo_retired.connect(func(info: EchoRetirementInfo) -> void:
		(_summary["retirements"] as Array).append({"uid": info.uid, "kind": info.kind,
			"weapon_id": info.weapon_id, "condition": info.condition, "damage": info.damage,
			"exhausted": info.exhausted, "actor_token": info.actor_token}))
	_fixture(name, "Main.new_run seed 140140; automatic spawn plan removed, 180s wave, player at (200,200), HP 10000, crit 0, empty initial loadout; no renderer-authored combat state")
	return sim


func _loadout(sim: Sim, ids: Array) -> void:
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for id: StringName in ids:
		sim.player.add_weapon(Content.weapon(id))


func _enemy(sim: Sim, id: StringName, position: Vector2, hp: float) -> EnemyState:
	var enemy := EnemyState.new()
	# Fixture enemies use the simulation allocator, just like _materialize. A
	# disconnected counter produces an invalid live save even when IDs are unique.
	enemy.uid = sim._next_uid
	sim._next_uid += 1
	enemy.def = Content.enemy(id)
	enemy.pos = position
	enemy.radius = enemy.def.radius
	enemy.max_hp = hp
	enemy.hp = hp
	enemy.speed = 0.0
	enemy.damage = enemy.def.damage
	sim.enemies.append(enemy)
	sim.grid.insert(enemy)
	_fixture("enemy", "%s uid %d staged at %s with %.0f HP and speed 0; production brain/attack timers run normally" % [id, enemy.uid, position, hp])
	return enemy


func _take(sim: Sim, id: StringName, position: Vector2, condition: float) -> EchoTake:
	var take := EchoTake.new()
	take.wave = maxi(1, sim.wave - 1)
	take.condition = condition
	take.stats = sim.player.stats.copy()
	take.weapons.append(Content.weapon(id))
	take.levels.append(0)
	take.samples = PackedVector2Array([position, position + Vector2(1.0, 0.0)])
	sim.bank.add(take)
	var actor := EchoActor.new(take, sim.echoes.size())
	sim.echoes.append(actor)
	sim.echo_spawned.emit(actor)
	EchoSystem.ensure_selection(sim)
	_fixture("echo", "%s with real stable UID %d, condition %.3f and short recorded route at %s" % [id, take.uid, condition, position])
	return take


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	var pixels := root.get_texture().get_image()
	_store_capture(name, pixels)


func _store_capture(name: String, pixels: Image) -> void:
	if not _check(pixels != null and not pixels.is_empty(), name + " has actual rendered pixels"):
		return
	var path := _shots_dir.path_join(name + ".png")
	_check(pixels.save_png(path) == OK, name + " PNG saved")
	var low := 1.0
	var high := 0.0
	for y in range(0, pixels.get_height(), 16):
		for x in range(0, pixels.get_width(), 16):
			var color := pixels.get_pixel(x, y)
			var value := (color.r + color.g + color.b) / 3.0
			low = minf(low, value)
			high = maxf(high, value)
	_check(high - low > 0.1, name + " contains actual nonblank scene pixels")
	_summary["screenshots"][name] = {"path": path, "image_size": [pixels.get_width(), pixels.get_height()],
		"sampled_luma_range": [low, high], "frame": _frames,
		"wave_time": _main.sim.wave_time if _main.sim != null else -1.0,
		"field_count": _main.sim.attack_fields.size() if _main.sim != null else 0,
		"active_fields": _field_rows(_main.sim) if _main.sim != null else []}
	print("core gameplay probe: " + name)


func _record_peaks() -> void:
	if _main == null or _main.get("audio") == null:
		return
	var counts: Dictionary = _main._view.feedback_counts()
	if _main.sim != null:
		counts["fields"] = _main.sim.attack_fields.size()
		counts["projectiles"] = _main.sim.projectiles.size()
		counts["enemy_zones"] = _main.sim.enemy_zones.size()
	counts["music_voices"] = _main.audio.music_state()["active_voices"]
	counts["sfx_voices"] = _main.audio.binding_state()["active_sfx"]
	for key in counts:
		_summary["peak"][key] = maxi(int(_summary["peak"].get(key, 0)), int(counts[key]))
		if _summary["limits"].has(key):
			_check(int(counts[key]) <= int(_summary["limits"][key]), "actual active count stays within " + key + " cap")


func _music_record(label: String) -> void:
	var streams: Array = []
	for player: AudioStreamPlayer in _main.audio._music_players:
		streams.append({"playing": player.playing, "position": player.get_playback_position(),
			"paused": player.stream_paused})
	(_summary["music"] as Array).append({"label": label, "state": _main.audio.music_state(),
		"binding": _main.audio.binding_state(), "actual_streams": streams})


func _fixture(name: String, setup: String) -> void:
	(_summary["fixtures"] as Array).append({"stage": name, "setup": setup})


func _cover(id: String) -> void:
	if not (_summary["coverage"] as Array).has(id):
		(_summary["coverage"] as Array).append(id)


func _v(value: Vector2) -> Array:
	return [value.x, value.y]


func _button(surface: Control, key: String) -> Button:
	for button: Button in surface.find_children("*", "Button", true, false):
		if button.text == Loc.t(key):
			return button
	return null


func _activate(button: Button) -> void:
	if not _check(button != null and not button.disabled and button.is_visible_in_tree(), "real UI target is present and enabled"):
		return
	button.grab_focus()
	await _key(KEY_ENTER)


func _key(code: Key) -> void:
	await _send_key(code, true)
	await _wait(0.035)
	await _send_key(code, false)
	await _wait(0.04)


func _send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _joy(code: JoyButton) -> void:
	await _send_joy(code, true)
	await _wait(0.035)
	await _send_joy(code, false)
	await _wait(0.04)


func _send_joy(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _hold(code: Key, seconds: float) -> void:
	await _send_key(code, true)
	await _wait(seconds)
	await _send_key(code, false)
	await _wait(0.04)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_until_wave_time(sim: Sim, target: float) -> void:
	while sim == _main.sim and sim.phase == Sim.Phase.WAVE and sim.wave_time + 0.000001 < target:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition and not _failed.has(message):
		_failed.append(message)
		printerr("core gameplay probe: FAILED: " + message)
	return condition


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Engine.max_fps = 0
	Input.action_release(&"move_right")
	Input.action_release(&"retire_echo")
	_summary["failures"] = _failed
	_summary["frames"] = _frames
	_summary["wall_seconds"] = float(Time.get_ticks_msec() - _started) / 1000.0
	_summary["success"] = _failed.is_empty()
	var file := FileAccess.open(_shots_dir.path_join("summary.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_summary, "\t", true, true))
		file.close()
	if _main != null:
		_main.show_select()
		if _main.get("audio") != null:
			_main.audio.stop_all()
		_main.queue_free()
		_main = null
	print("core gameplay probe: %s (%d screenshots, %.2fs)" % ["OK" if _failed.is_empty() else "FAILED", (_summary["screenshots"] as Dictionary).size(), _summary["wall_seconds"]])
	await process_frame
	await process_frame
	quit(0 if _failed.is_empty() else 1)
