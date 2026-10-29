extends SceneTree

# Standalone because reload_current_scene must replace the actual Main scene,
# never the shared unit-test runner. Disabling root processing makes the
# before/after comparison independent of elapsed presentation frames.
# Run with tools/checked.sh --headless --path . --script res://tools/main_language_probe.gd
# so engine lifecycle errors fail verification as well as failed assertions.
var failures: Array[String] = []
var checks := 0
var _paths: Dictionary = {}
var _directory := ""


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	_directory = OS.get_environment("TMPDIR").path_join("take_stack_language_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if not _directory.is_absolute_path():
		_directory = "/tmp".path_join(_directory)
	_check(DirAccess.make_dir_recursive_absolute(_directory) == OK, "probe directory is isolated")
	for key in ["REVERB_SUSPEND", "REVERB_SAVE", "REVERB_RUN_LOG", "REVERB_SETTINGS", "REVERB_FEEDBACK_LOG", "REVERB_LANG"]:
		_paths[key] = OS.get_environment(key)
		OS.set_environment(key, _directory.path_join(key.to_lower() + ".json"))
	OS.set_environment("REVERB_LANG", "en")
	Loc.lang = "en"
	await process_frame
	var main: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main = await _reload_case(main, false, false, "zh")
	main = await _reload_case(main, false, true, "en")
	main = await _reload_case(main, true, false, "zh")
	await _failed_save_case(main)
	if is_instance_valid(current_scene):
		current_scene.free()
	await process_frame
	for key: String in _paths:
		OS.set_environment(key, _paths[key])
	for file: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(file))
	DirAccess.remove_absolute(_directory)
	print(JSON.stringify({"probe": "main_language_reload", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _fixture(main: Variant, shop: bool) -> void:
	main.new_run(9223372036854775806, &"mender", 0)
	var sim: Sim = main.sim
	sim.step(0.017, Vector2.RIGHT)
	sim.step(0.011, Vector2.DOWN)
	sim.player.hp = 11.125
	sim.player.iframes = 0.123456789
	sim.player.materials = 500
	sim.player.cooldowns[0] = 0.2718281828
	sim.rng.state = -8547302273828374501
	sim.hazard_rng.state = 7223372036854775806
	sim.supply_claims = 3
	sim.set("_supply_spawned", true)
	sim.story_progress = {"clues": ["carbon"], "receipt": "carbon", "repairs": 1}
	var take := EchoTake.new()
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(32.0, 16.0)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(1)
	take.stats = sim.player.stats.copy()
	take.condition = 43.75
	sim.bank.add(take)
	sim.echoes.append(EchoActor.new(take, 0))
	sim.echoes[0].step(0.019)
	sim.selected_echo_uid = take.uid
	sim.retire_cooldown = 0.125
	var field := AttackField.new()
	field.weapon_id = &"mallet"
	field.style = &"slam"
	field.actor_token = 144
	field.pos = sim.player.pos + Vector2(80.0, 100.0)
	field.target = field.pos
	field.windup = 0.42
	field.life = 0.5
	field.damage = 12.0
	field.radius = 42.0
	sim.attack_fields.append(field)
	var zone := EnemyZone.new()
	zone.source_uid = 144
	zone.pos = sim.player.pos + Vector2(0.0, 400.0)
	zone.warning = 0.321
	sim.enemy_zones.append(zone)
	var pickup := Pickup.new()
	pickup.pos = sim.player.pos + Vector2(200.0, 100.0)
	pickup.kind = &"supply"
	pickup.life = 3.14159265
	sim.pickups.append(pickup)
	if shop:
		sim.phase = Sim.Phase.SHOP
		sim.wave = 7
		sim.shop.roll(sim)
		sim.shop.toggle_lock(sim, sim.shop.offers[0])
		sim.shop.repair_echo(sim, take)
		main.set("_phase", Sim.Phase.SHOP)
		main.call("_open_shop")
	main.set("_shop_delay", 0.0 if shop else 0.3456789)
	main.set("_end_delay", 0.01234567)
	main.set("_daily_run", true)
	main.set("_recorded", true)
	main.set("_unlock_text", "probe unlock")
	main.set("_run_context", {"source": "language_probe", "run_id": "probe_exact", "number": 9223372036854775806})


func _reload_case(main: Variant, shop: bool, already_paused: bool, language: String) -> Variant:
	_fixture(main, shop)
	main.call("_set_paused", already_paused)
	main.open_settings()
	var expected: Dictionary = RunSnapshot.capture(main.sim)
	var expected_context: Dictionary = main.get("_run_context").duplicate(true)
	var previous_scene: WeakRef = weakref(main)
	var previous_sim: WeakRef = weakref(main.sim)
	var label := "shop" if shop else ("paused battle" if already_paused else "battle")
	_check(not expected.is_empty(), "%s snapshot captures populated run" % label)
	_check(main.settings_ui.visible, "%s settings open before reload" % label)
	_check(main.paused if not shop else not main.paused, "%s opening settings preserves correct pause" % label)
	main.call("_on_language_changed", language)
	main = null
	var restored: Variant = null
	for _frame in 30:
		await process_frame
		if current_scene != null and current_scene != previous_scene.get_ref() \
				and current_scene.get("sim") != null and current_scene.get("settings_ui").visible:
			restored = current_scene
			break
	_check(restored != null, "%s actual scene reload resumes run and settings" % label)
	if restored == null:
		return current_scene
	_check(previous_scene.get_ref() == null, "%s releases prior Main" % label)
	_check(previous_sim.get_ref() == null, "%s releases prior simulation" % label)
	_check(RunSnapshot.capture(restored.sim) == expected, "%s language reload preserves every gameplay field" % label)
	_check(restored.sim.supply_claims == 3 and restored.sim.get("_supply_spawned"), "%s supply counters persist" % label)
	_check(restored.sim.attack_fields.size() == 1 and restored.sim.enemy_zones.size() == 1, "%s active attack and warning persist" % label)
	_check(restored.character_id == &"mender", "%s character preserved without applying stats again" % label)
	_check(restored.settings.language == language and Loc.lang == language, "%s target language applies" % label)
	_check(restored.settings_ui.visible and not restored.pause_ui.visible, "%s settings keep focus after reload" % label)
	_check(restored.get("_settings_restore_pause") == already_paused, "%s original pause restoration persists" % label)
	_check(restored.get("_run_context") == expected_context, "%s run context survives scene recreation" % label)
	_check(restored.get("_end_delay") == 0.01234567 and restored.get("_shop_delay") == (0.0 if shop else 0.3456789), "%s Main delay envelope is exact" % label)
	_check(restored.get("_daily_run") and restored.get("_recorded") and restored.get("_unlock_text") == "probe unlock", "%s Main run envelope persists" % label)
	if shop:
		_check(restored.shop_ui.visible, "shop remains under settings after language reload")
		_check(restored.sim.shop.locked_offer() != null and restored.sim.shop.can_undo(), "shop lock and repair undo survive reload")
		restored.sim.shop.undo(restored.sim)
		var reference := RunSnapshot.restore(expected)
		reference.shop.undo(reference)
		_check(RunSnapshot.capture(restored.sim) == RunSnapshot.capture(reference), "shop undo remains exact after language reload")
	else:
		var reference := RunSnapshot.restore(expected)
		_check(reference != null, "%s reference snapshot validates before progression" % label)
		if reference != null:
			for _step in 60:
				restored.sim.step(0.016, Vector2.LEFT)
				reference.step(0.016, Vector2.LEFT)
			_check(RunSnapshot.capture(restored.sim) == RunSnapshot.capture(reference), "%s subsequent RNG and combat progression remain exact" % label)
	restored.settings_ui.close()
	_check(not restored.settings_ui.visible and restored.paused == already_paused, "%s closing settings restores original pause" % label)
	_check(restored.pause_ui.visible == already_paused, "%s closing settings restores correct menu" % label)
	if shop:
		_check(restored.shop_ui.visible, "closing language settings restores the same shop")
	return restored


func _failed_save_case(main: Variant) -> void:
	_fixture(main, false)
	main.open_settings()
	var before: Dictionary = RunSnapshot.capture(main.sim)
	var previous_language: String = main.settings.language
	var previous_main_id: int = main.get_instance_id()
	var previous_sim_id: int = main.sim.get_instance_id()
	OS.set_environment("REVERB_SUSPEND", _directory.path_join("missing/run.json"))
	main.call("_on_language_changed", "en" if previous_language != "en" else "zh")
	await process_frame
	_check(current_scene.get_instance_id() == previous_main_id, "failed suspend keeps actual Main scene")
	_check(main.sim.get_instance_id() == previous_sim_id and RunSnapshot.capture(main.sim) == before, "failed language suspend preserves exact live simulation")
	_check(main.settings.language == previous_language and Loc.lang == previous_language, "failed language suspend leaves language unchanged")
	_check(main.settings_ui.visible and main.settings_ui.error_label.visible, "failed language suspend reports visible settings error")
	_check(main.paused and not main.pause_ui.visible, "failed language suspend keeps settings pause")
	main.settings_ui.close()
	_check(not main.paused, "closing failed language settings restores unpaused battle")
