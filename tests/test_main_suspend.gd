extends RefCounted

const MAIN_SCENE := preload("res://scenes/main.tscn")
var _environment: Dictionary = {}
var _directory := ""


func _main() -> Node:
	_directory = ProjectSettings.globalize_path("user://main_suspend_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	for key in ["REVERB_SUSPEND", "REVERB_SAVE", "REVERB_RUN_LOG", "REVERB_SETTINGS", "REVERB_FEEDBACK_LOG"]:
		_environment[key] = OS.get_environment(key)
		OS.set_environment(key, _directory.path_join(key.to_lower() + ".json"))
	var main := MAIN_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.set_physics_process(false)
	return main


func _dispose(main: Node) -> void:
	main._detach_presentation_session()
	main.free()
	for key: String in _environment:
		OS.set_environment(key, _environment[key])
	_environment.clear()
	for file: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(file))
	DirAccess.remove_absolute(_directory)


func _take(sim: Sim, weapon: StringName, condition: float) -> EchoTake:
	var take := EchoTake.new()
	take.wave = sim.wave
	take.weapons.append(Content.weapon(weapon))
	take.levels.append(1)
	take.stats = sim.player.stats.copy()
	take.condition = condition
	take.samples = PackedVector2Array([Vector2(640.0, 360.0), Vector2(690.0, 370.0)])
	sim.bank.add(take)
	sim.echoes.append(EchoActor.new(take, sim.echoes.size()))
	return take


func _battle(main: Node) -> void:
	main.new_run(140014, &"mender")
	var sim: Sim = main.sim
	_take(sim, &"longbow", 43.25)
	_take(sim, &"ink_bottle", 71.125)
	sim.selected_echo_uid = sim.echoes[1].take.uid
	sim.player.hp = 13.125
	sim.player.materials = 987
	sim.player.stats.add(Stats.ECHO_DURATION, 80.0)
	sim.player.cooldowns[0] = 0.2818281828
	sim.player.iframes = 0.123456789
	sim.retire_cooldown = 0.125
	sim.wave_time = 0.9572021790913173
	sim.recorder.record(sim.player.pos + Vector2(13.0, 7.0), 0.017)
	sim.rng.state = -8547302273828374501
	sim.hazard_rng.state = 7223372036854775806
	sim.supply_claims = 2
	sim.set("_supply_spawned", true)
	var field := AttackField.new()
	field.weapon_id = &"mallet"
	field.style = &"slam"
	field.actor_token = 144
	field.pos = Vector2(1000.0, 800.0)
	field.target = field.pos
	field.windup = 0.42
	field.life = 0.5
	field.damage = 12.0
	field.radius = 42.0
	sim.attack_fields.append(field)
	var zone := EnemyZone.new()
	zone.source_uid = 900
	zone.pos = Vector2(1300.0, 1000.0)
	zone.warning = 0.321
	sim.enemy_zones.append(zone)
	sim.story_progress = {"clues": ["carbon"], "receipt": "carbon", "repairs": 1}
	main._shop_delay = 0.28125
	main._daily_run = true
	main._run_context = {"source": "main_suspend_test", "nested": {"value": 9223372036854775806}}


func _owned_connections(signal_value: Signal, owner: Node) -> int:
	var count := 0
	for connection: Dictionary in signal_value.get_connections():
		if connection.callable.get_object() == owner:
			count += 1
	return count


func _retire_event(controller: bool, pressed: bool) -> InputEvent:
	if controller:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_RIGHT_SHOULDER
		button.pressed = pressed
		return button
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	return key


func test_save_return_continue_preserves_actual_battle_and_releases_old_sim(c: Check) -> void:
	var main := _main()
	_battle(main)
	main._set_paused(true)
	var before := RunSnapshot.capture(main.sim)
	c.ok(not before.is_empty(), "actual Main battle is snapshot-valid")
	var reference: WeakRef = weakref(main.sim)
	var context: Dictionary = main._run_context.duplicate(true)
	main.pause_ui.save_button.pressed.emit()
	c.ok(SuspendStore.exists(), "actual pause Save and Return button writes a real suspension")
	c.ok(main.character_select.visible and main.sim == null, "successful save returns to the title")
	c.eq(main._view.sim, null, "title releases the arena run")
	c.eq(main.hud.sim, null, "title releases the HUD run")
	c.eq(main.shop_ui.sim, null, "title releases the shop run")
	c.eq(reference.get_ref(), null, "Save and Return releases the old authoritative Sim")
	c.ok(main.character_select.continue_button.visible, "saved run has an actual title Continue action")
	main.character_select.continue_button.pressed.emit()
	c.ok(main.sim != null, "actual title Continue button restores the real saved battle")
	c.eq(RunSnapshot.capture(main.sim), before, "Continue preserves every gameplay field exactly")
	c.eq(main.character_id, &"mender", "saved role restored without reapplying starting stats")
	c.eq(main._run_context, context, "run identity context survives title round trip")
	c.eq(main._shop_delay, 0.28125, "Main's pending presentation delay survives")
	c.ok(main._daily_run and not main.paused, "daily envelope survives and ordinary Continue resumes play")
	c.eq(main.sim.supply_claims, 2, "supply claims survive")
	c.ok(main.sim.get("_supply_spawned"), "already-spawned supply cannot respawn after Continue")
	c.eq(main.sim.attack_fields[0].actor_token, 144, "departed-copy delayed attack preserves ownership")
	var expected := RunSnapshot.restore(before)
	for i in 15:
		main.sim.step(0.016, Vector2.LEFT)
		expected.step(0.016, Vector2.LEFT)
	c.eq(RunSnapshot.capture(main.sim), RunSnapshot.capture(expected), "resumed combat and both RNG streams progress identically")
	_dispose(main)


func test_shop_continue_preserves_offers_locks_repair_duration_and_undo(c: Check) -> void:
	var main := _main()
	_battle(main)
	main.sim.phase = Sim.Phase.SHOP
	main.sim.wave = 7
	main._phase = Sim.Phase.SHOP
	main._shop_delay = 0.0
	main.sim.shop.roll(main.sim)
	main.sim.shop.toggle_lock(main.sim, main.sim.shop.offers[1])
	main.sim.shop.repair_echo(main.sim, main.sim.bank.takes[0])
	main._open_shop()
	var before := RunSnapshot.capture(main.sim)
	var expected := RunSnapshot.restore(before)
	c.ok(main.sim.shop.can_undo(), "real repair creates undo history")
	c.ok(main.save_and_return() and main.continue_run(), "shop uses the same Save and Return and Continue path")
	c.eq(RunSnapshot.capture(main.sim), before, "all shop gameplay, offer identity, locks and history preserve exactly")
	c.ok(main.shop_ui.visible and not main.hud.visible, "Continue restores the shop screen")
	c.near(main.sim.echo_duration(), 200.0, 0.0, "modified echo duration is preserved without character reinitialization")
	c.ok(main.sim.shop.offers[1].locked, "exact offer slot remains locked")
	c.ok(main.sim.shop.can_undo(), "restored repair remains undoable")
	c.eq(main.sim.shop.undo(main.sim).ok, expected.shop.undo(expected).ok, "resumed undo succeeds identically")
	c.eq(RunSnapshot.capture(main.sim), RunSnapshot.capture(expected), "undo restores exact pre-purchase state")
	main.sim.shop.reroll(main.sim)
	expected.shop.reroll(expected)
	c.eq(RunSnapshot.capture(main.sim), RunSnapshot.capture(expected), "next reroll consumes the same RNG and yields the same offers")
	_dispose(main)


func test_corrupt_suspend_and_failed_save_preserve_the_live_session(c: Check) -> void:
	var main := _main()
	_battle(main)
	main._set_paused(true)
	var live: Sim = main.sim
	var before := RunSnapshot.capture(live)
	var file := FileAccess.open(SuspendStore.path(), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	c.ok(not main.continue_run(), "corrupt JSON fails visibly")
	c.ok(main.sim == live, "corrupt Continue cannot replace the live Sim")
	c.eq(RunSnapshot.capture(main.sim), before, "corrupt Continue changes no gameplay")
	c.ok(not main.character_select.resume_error.text.is_empty(), "Continue exposes a meaningful save error")
	c.ok(main._save_active(), "Main supplies a complete valid envelope before boundary corruption")
	var valid_envelope: Dictionary = SuspendStore.load().envelope
	for corruption in [{"character_id": &"missing_character"}, {"run_context": 23}]:
		var envelope := valid_envelope.duplicate(true)
		envelope.merge(corruption, true)
		c.ok(SuspendStore.save(live, envelope), "codec can store structurally valid boundary envelope")
		c.ok(not main.continue_run(), "invalid Main envelope is rejected before replacement")
		c.ok(main.sim == live, "invalid envelope keeps the original session object")
		c.eq(RunSnapshot.capture(main.sim), before, "invalid envelope preserves every live field")
	var blocked_parent := _directory.path_join("blocked_parent")
	file = FileAccess.open(blocked_parent, FileAccess.WRITE)
	file.store_string("regular file, not a directory")
	file.close()
	OS.set_environment("REVERB_SUSPEND", blocked_parent.path_join("run.json"))
	c.ok(not main.save_and_return(), "unwritable destination does not report success")
	c.ok(main.sim == live and main.paused and main.pause_ui.visible, "failed save keeps the paused battle open")
	c.ok(main.pause_ui.error_label.visible and not main.pause_ui.error_label.text.is_empty(), "failed save has a visible actionable error")
	c.eq(RunSnapshot.capture(main.sim), before, "failed save cannot modify the run")
	_dispose(main)


func test_new_run_requires_confirmation_and_repeated_continue_has_one_subscription(c: Check) -> void:
	var main := _main()
	_battle(main)
	c.ok(main.save_and_return(), "fixture saves a run through Main")
	var bytes := FileAccess.get_file_as_bytes(SuspendStore.path())
	main.choose_character(&"looper", 881)
	c.ok(main._replace_dialog.visible and main.sim == null, "choosing a new run first opens replacement confirmation")
	c.eq(FileAccess.get_file_as_bytes(SuspendStore.path()), bytes, "confirmation does not erase the suspension")
	main._replace_dialog.hide()
	for i in 3:
		var reference: WeakRef = weakref(main.sim) if main.sim != null else null
		c.ok(main.continue_run(), "repeated Continue %d succeeds" % i)
		if reference != null:
			c.eq(reference.get_ref(), null, "repeated Continue releases replaced Sim %d" % i)
		c.eq(_owned_connections(main.sim.echo_retired, main), 1, "one Main retirement subscription after Continue %d" % i)
		c.eq(_owned_connections(main.sim.combo_triggered, main), 1, "one Main combo subscription after Continue %d" % i)
		c.eq(_owned_connections(main.sim.wave_ended, main), 1, "one Main story subscription after Continue %d" % i)
	main.show_select()
	main.choose_character(&"looper", 882)
	main._replace_dialog.hide()
	main._replace_dialog.confirmed.emit()
	c.ok(main.sim != null and main.sim.run_seed == 882, "explicit confirmation starts the chosen replacement")
	c.ok(not SuspendStore.exists(), "only confirmed new run removes the old suspension")
	_dispose(main)


func test_space_and_controller_hold_pause_select_release_and_cancel_without_retirement(c: Check) -> void:
	var was_gamepad := Controls.using_gamepad
	for controller in [false, true]:
		var main := _main()
		_battle(main)
		main.sim.retire_cooldown = 0.0
		var count: int = main.sim.bank.takes.size()
		var selected: int = main.sim.selected_echo_uid
		main._unhandled_input(_retire_event(controller, true))
		main._update_retirement_hold(main.RETIRE_HOLD_TIME)
		c.ok(main.paused and main.echo_wheel.visible and not main.pause_ui.visible, "hold opens the paused selection wheel")
		var before := RunSnapshot.capture(main.sim)
		main._physics_process(0.5)
		c.eq(RunSnapshot.capture(main.sim), before, "wheel pause stops combat, condition wear and RNG")
		main.echo_wheel._highlight(0)
		var choice: int = main.echo_wheel.selected_uid()
		c.ok(choice != selected, "wheel can highlight a different stable copy")
		main._input(_retire_event(controller, false))
		c.ok(not main.paused and not main.echo_wheel.visible, "release resumes battle")
		c.eq(main.sim.selected_echo_uid, choice, "release commits the highlighted selection")
		c.eq(main.sim.bank.takes.size(), count, "release after hold never retires a copy")
		main._unhandled_input(_retire_event(controller, true))
		main._update_retirement_hold(main.RETIRE_HOLD_TIME + 0.01)
		main.echo_wheel.cancel()
		main._input(_retire_event(controller, false))
		c.ok(not main.paused and not main.echo_wheel.visible, "cancel resumes and closes the wheel")
		c.eq(main.sim.bank.takes.size(), count, "cancel followed by release cannot consume a copy")
		main._unhandled_input(_retire_event(controller, true))
		main._input(_retire_event(controller, false))
		c.eq(main.sim.bank.takes.size(), count - 1, "a separate short tap retires exactly one selected copy")
		c.eq(Controls.retire_label(), "RB" if controller else "SPACE", "actual input device supplies the correct hint")
		_dispose(main)
	Controls.using_gamepad = was_gamepad


func test_story_receipt_archive_and_settings_release_session_and_wire_independent_audio(c: Check) -> void:
	var main := _main()
	_battle(main)
	main.open_story()
	c.ok(main.story_ui.visible and main.paused, "battle archive opens as an optional paused overlay")
	c.ok(main.meta.story_clues.has(&"carbon"), "Main persists this run's discovered clue before opening the archive")
	c.eq(main.story_ui.row_count(), 1, "archive contains exactly this isolated run's discovered clue")
	main.story_ui.close()
	c.ok(not main.paused, "archive close restores the unpaused battle")
	main._set_paused(true)
	main.open_story()
	main.story_ui.close()
	c.ok(main.paused and main.pause_ui.visible, "archive close restores an already paused battle")
	main._set_paused(false)
	main.open_settings()
	main.settings_ui.music_volume_slider.value = 0.0
	c.eq(main.settings.music_volume, 0.0, "Main receives the actual music slider signal")
	c.eq(main.audio.music_state().music_volume, 0.0, "Main applies silent music to the audio engine")
	main.settings_ui.effects_volume_slider.value = 0.35
	c.near(main.settings.effects_volume, 0.35, 0.001, "Main receives the actual effects slider signal")
	c.eq(main.settings.music_volume, 0.0, "effect volume changes preserve silent music")
	c.near(main.audio.music_state().effects_volume, 0.35, 0.001, "effect gain reaches audio independently")
	var persisted := Settings.new(main.settings.path)
	c.eq(persisted.music_volume, 0.0, "independent music control persists")
	c.near(persisted.effects_volume, 0.35, 0.001, "independent effects control persists")
	main.settings_ui.close()
	main.sim.phase = Sim.Phase.SHOP
	main._phase = Sim.Phase.SHOP
	main._shop_delay = 0.0
	main.sim.shop.roll(main.sim)
	main._open_shop()
	main.shop_ui.receipt_button.pressed.emit()
	c.ok(main.receipt_ui.visible and main.receipt_ui._sim == main.sim, "shop receipt is explicitly opened for this run")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	main._unhandled_input(cancel)
	c.ok(not main.receipt_ui.visible, "Escape closes the optional receipt")
	c.eq(main.receipt_ui._sim, null, "Escape releases the receipt's run reference")
	main.sim.story_progress["receipt"] = "carbon"
	main.open_receipt()
	main.receipt_ui.archive_button.pressed.emit()
	c.ok(main.story_ui.visible, "receipt archive button is wired through Main to the archive")
	c.eq(main.receipt_ui._sim, null, "opening archive releases receipt's run reference")
	main.story_ui.close()
	main.open_receipt()
	var reference: WeakRef = weakref(main.sim)
	c.ok(main.save_and_return(), "Save and Return closes story surfaces")
	c.eq(main.receipt_ui._sim, null, "title retains no receipt run reference")
	c.eq(reference.get_ref(), null, "story UI cannot retain the saved run")
	_dispose(main)


func test_pending_boon_can_save_without_choosing_or_rerolling(c: Check) -> void:
	var main := _main()
	main.new_run(919, &"looper")
	main.sim.phase = Sim.Phase.SHOP
	var choices: Array[StringName] = [&"damage", &"haste", &"shield"]
	main.sim.pending_boons = choices
	main._phase = Sim.Phase.SHOP
	main._show_boon()
	var before: Dictionary = RunSnapshot.capture(main.sim)
	main.boon_ui.save_button.pressed.emit()
	c.eq(main.sim, null, "boon screen Save and Return releases the session")
	c.ok(main.continue_run(), "pending boon can continue")
	c.eq(RunSnapshot.capture(main.sim), before, "pending choice, RNG and offers are exact")
	c.ok(main.boon_ui.visible, "continue returns to the same unchosen boon screen")
	_dispose(main)
