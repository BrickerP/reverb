extends RefCounted

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FILE_ENV := ["REVERB_SAVE", "REVERB_SETTINGS", "REVERB_RUN_LOG", "REVERB_FEEDBACK_LOG", "REVERB_SUSPEND"]
var _environment: Dictionary = {}
var _directory := ""
var _language := ""
var _gamepad := false


func _main() -> Node:
	var temporary := OS.get_environment("TMPDIR")
	if temporary == "":
		temporary = "/tmp"
	_directory = temporary.path_join("reverb_closeout_main_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_directory)
	for key: String in FILE_ENV:
		_environment[key] = OS.get_environment(key)
		OS.set_environment(key, _directory.path_join(key.to_lower() + ".json"))
	_language = Loc.lang
	_gamepad = Controls.using_gamepad
	var main := MAIN_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.set_physics_process(false)
	main._on_reduced_effects_changed(true)
	return main


func _dispose(main: Node) -> void:
	main._detach_presentation_session()
	main.free()
	for key: String in _environment:
		OS.set_environment(key, _environment[key])
	_environment.clear()
	Loc.lang = _language
	Controls.using_gamepad = _gamepad
	for file: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(file))
	DirAccess.remove_absolute(_directory)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _pad(code: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	return event


func _archive_action(main: Node) -> Button:
	for button: Button in main.character_select._secondary_actions:
		if button.text == Loc.t("archive.open"):
			return button
	return null


func _take(sim: Sim, weapon: StringName, level: int, damage_bonus: float = 0.0) -> EchoTake:
	var take := EchoTake.new()
	take.wave = maxi(1, sim.wave)
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(40, 0)])
	take.weapons.append(Content.weapon(weapon))
	take.levels.append(level)
	take.stats = sim.player.stats.copy()
	take.stats.add(Stats.DAMAGE_PCT, damage_bonus)
	take.condition = 80.0
	sim.bank.add(take)
	return take


func _lose(main: Node) -> void:
	main.sim.player.iframes = 0.0
	main.sim._hurt_player(main.sim.player.hp + main.sim.player.shield + 10.0,
		&"grunt", &"hit", main.sim.player.pos, Vector2.ZERO)
	main._physics_process(0.01)
	main._physics_process(main.PLAYER_DEATH_BEAT + 0.01)


func _shop_after_recording(main: Node, role: StringName = &"looper") -> void:
	main.new_run(8642, role)
	main.sim.recorder.record(main.sim.player.pos + Vector2(40, 0), 0.1)
	main.sim._end_wave()
	main._sync_phase()
	main._physics_process(main.RECORD_BEAT + 0.01)


func _focus_reaches(start: Control, target: Control) -> bool:
	var current := start
	for _step in 20:
		if current == target:
			return true
		if current.focus_next == NodePath():
			return false
		current = current.get_node_or_null(current.focus_next) as Control
		if current == null:
			return false
	return false


func test_archive_end_action_title_preview_toggle_and_inherited_new_run(c: Check) -> void:
	var main := _main()
	c.ok(main.character_select.visible and main.meta != null, "actual Main ready exposes title and persistent profile")
	main.new_run(3001, &"looper")
	_take(main.sim, &"smg", 0)
	var best := _take(main.sim, &"pistol", 3, 2.0)
	_lose(main)
	c.ok(main.end_ui.visible and main.end_ui.best_take == best, "real loss presents the strongest retained recording")
	c.ok(not main.end_ui.archive_button.disabled, "eligible end screen exposes a usable save action")
	c.ok(_focus_reaches(main.end_ui.restart_button, main.end_ui.archive_button), "keyboard and controller end-screen focus can reach archive action")
	main.end_ui.archive_button.pressed.emit()
	c.ok(EchoArchive.has(Meta.new(main.meta.path), &"looper"), "actual end button writes the real profile")
	c.eq(main.end_ui._archive_note.text, Loc.t("archive.saved"), "archive button gives success feedback")
	main.end_ui.character_button.pressed.emit()
	c.ok(main.character_select.visible and main.sim == null, "actual change-character button returns to title")
	var action := _archive_action(main)
	c.ok(action != null, "archive has a real title button")
	if action == null:
		_dispose(main)
		return
	action.pressed.emit()
	c.ok(main.echo_archive_ui.visible and main.echo_archive_ui._preview.visible, "actual title button opens saved route preview")
	c.ok(main.echo_archive_ui.toggle_button.has_focus(), "modal initially focuses a useful control")
	main.echo_archive_ui.toggle_button.set_pressed_no_signal(false)
	main.echo_archive_ui.toggle_button.pressed.emit()
	c.ok(not Meta.new(main.meta.path).inherit_echo, "actual inheritance toggle persists disabled preference")
	main.echo_archive_ui._close_button.pressed.emit()
	c.ok(not main.echo_archive_ui.visible and main.character_select._cards[0].has_focus(), "closing archive restores title focus")
	main.new_run(3002, &"looper")
	c.ok(main.sim.bank.takes.is_empty(), "disabled inheritance creates no copy in the next real run")
	main.show_select()
	action = _archive_action(main)
	action.pressed.emit()
	main.echo_archive_ui.toggle_button.set_pressed_no_signal(true)
	main.echo_archive_ui.toggle_button.pressed.emit()
	main.echo_archive_ui._close_button.pressed.emit()
	main.new_run(3003, &"looper")
	c.eq(main.sim.bank.takes.size(), 1, "enabled archive seeds exactly one normal-capacity recording")
	if not main.sim.bank.takes.is_empty():
		var inherited: EchoTake = main.sim.bank.takes[0]
		c.ok(inherited.archived and inherited.uid > 0, "live inherited copy receives normal stable identity")
		c.ok(main.sim.bank.takes.size() <= main.sim.echo_capacity(), "inherited copy uses existing slot capacity")
		c.near(inherited.power(), main.sim.player.weapons[0].dps() * 0.75, 0.001, "inherited build is normalized to opening power")
	main.new_run(3004, &"looper", 0, DailyAnomaly.FORTUNE)
	c.ok(main.sim.bank.takes.is_empty(), "actual Daily new run cannot inherit campaign archive")
	_take(main.sim, &"pistol", 1)
	_lose(main)
	c.ok(main.end_ui.archive_button.disabled, "actual Daily result cannot offer archive award")
	main.new_run(3005, &"solo")
	c.ok(main.sim.bank.takes.is_empty() and main.sim.echo_capacity() == 0, "actual Solo new run never receives inherited body")
	_lose(main)
	c.ok(main.end_ui.archive_button.disabled, "actual Solo result has no archive award action")
	_dispose(main)


func test_archive_write_failure_is_visible_atomic_and_retryable_through_end_button(c: Check) -> void:
	var main := _main()
	main.new_run(3010, &"looper")
	_take(main.sim, &"pistol", 3, 2.0)
	_lose(main)
	var writable: String = main.meta.path
	var blocker := _directory.path_join("blocked_parent")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("regular file")
	file.close()
	main.meta.path = blocker.path_join("profile.json")
	main.end_ui.archive_button.pressed.emit()
	c.ok(main.meta.echo_archives.is_empty(), "failed UI archive cannot mutate played profile")
	c.ok(main.end_ui._archive_note.is_visible_in_tree() and main.end_ui._archive_note.text == Loc.t("story.save_failed"), "actual end action displays failed write feedback")
	c.ok(not main.end_ui.archive_button.disabled, "failed save remains retryable")
	main.meta.path = writable
	main.end_ui.archive_button.pressed.emit()
	c.ok(EchoArchive.has(Meta.new(writable), &"looper"), "retry through same UI persists the archive")
	c.ok(main.end_ui.archive_button.disabled, "successful archive cannot be submitted twice")
	_dispose(main)


func test_all_role_actions_and_world_keyboard_controller_inputs_reach_actual_main(c: Check) -> void:
	for role: StringName in Content.characters():
		var main := _main()
		_shop_after_recording(main, role)
		c.ok(main.shop_ui.visible, "%s real wave-to-shop route opens UI" % role)
		main.shop_ui.start_button.pressed.emit()
		c.eq(main.sim.character_id, role, "%s selected role reaches authoritative Sim" % role)
		var event: InputEvent = _pad(JOY_BUTTON_LEFT_SHOULDER) if role in [&"mirror", &"mender", &"overloader"] else _key(KEY_SHIFT)
		c.ok(event.is_action_pressed(&"character_skill"), "%s physical input uses registered action" % role)
		main._unhandled_input(event)
		c.eq(main.sim.character_energy, 0.0, "%s actual Main input spends 100 energy" % role)
		c.eq(main.hud.sim, main.sim, "%s HUD stays bound to the live role" % role)
		c.eq(main.hud.sim.character_energy, 0.0, "%s HUD reads the actual decremented energy" % role)
		c.ok(main.sim.character_cooldown > 0.0, "%s actual input creates bounded cooldown" % role)
		_dispose(main)
	var main := _main()
	main.new_run(3020, &"solo")
	main._unhandled_input(_key(KEY_SHIFT))
	var recycler: Dictionary = main.sim.interactables[2]
	main.sim.player.pos = recycler.pos
	recycler.cooldown = 0.0
	var funds: int = main.sim.player.materials
	c.ok(_key(KEY_E).is_action_pressed(&"interact"), "E uses registered world action")
	main._unhandled_input(_key(KEY_E))
	c.eq(main.sim.player.materials, funds - 8, "E activates actual paid world recycler")
	c.eq(main.sim.character_energy, 30.0, "E produces actual machine energy")
	recycler.cooldown = 0.0
	c.ok(_pad(JOY_BUTTON_X).is_action_pressed(&"interact"), "controller X uses registered world action")
	main._unhandled_input(_pad(JOY_BUTTON_X))
	c.eq(main.sim.character_energy, 60.0, "controller activates the same authoritative machine")
	c.eq(Controls.interact_label(), "X", "HUD hint follows actual controller input")
	_dispose(main)


func test_modal_blocks_new_battle_inputs_and_restores_pause_focus(c: Check) -> void:
	var main := _main()
	main.new_run(3030, &"solo")
	main._unhandled_input(_key(KEY_P))
	c.ok(main.pause_ui.visible and main.paused, "real pause action opens pause UI")
	main.pause_ui.story_button.pressed.emit()
	c.ok(main.story_ui.visible, "actual pause button opens modal archive")
	var before := RunSnapshot.capture(main.sim)
	main._unhandled_input(_key(KEY_SHIFT))
	main._unhandled_input(_key(KEY_E))
	main._physics_process(0.5)
	c.eq(RunSnapshot.capture(main.sim), before, "modal prevents role action, world interaction, combat and energy changes behind it")
	main._unhandled_input(_key(KEY_ESCAPE))
	c.ok(not main.story_ui.visible and main.pause_ui.visible and main.paused, "cancel closes modal back to original paused context")
	c.ok(main.pause_ui.resume_button.has_focus(), "modal cancel restores a usable pause focus")
	main.pause_ui.resume_button.pressed.emit()
	c.ok(not main.paused, "actual resume button releases battle")
	_dispose(main)


func test_main_ui_save_and_continue_retain_new_role_support_order_and_debt_state(c: Check) -> void:
	var main := _main()
	_shop_after_recording(main, &"mender")
	main.sim.player.materials = 500
	main.shop_ui.refresh()
	var credit_card: OfferCard
	for _roll in 12:
		for child: Node in main.shop_ui.offers_box.get_children():
			var card := child as OfferCard
			if card != null and card.offer.is_contract() and card.offer.contract.kind == &"credit":
				credit_card = card
				break
		if credit_card != null:
			break
		main.shop_ui.reroll_button.pressed.emit()
	c.ok(credit_card != null, "actual deterministic shop can expose credit order")
	if credit_card == null:
		_dispose(main)
		return
	credit_card.pressed.emit()
	c.ok(main.sim.active_contract != null and main.sim.expedition.debt == 40, "actual work-order card purchases real credit and obligation")
	main.shop_ui.start_button.pressed.emit()
	main._unhandled_input(_key(KEY_SHIFT))
	c.eq(main.sim.support_units.size(), 1, "actual ability input deploys repair station before save")
	var before := RunSnapshot.capture(main.sim)
	c.ok(RunSnapshot.restore(before) != null, "actual Main new-state battle is snapshot-valid")
	main._unhandled_input(_key(KEY_P))
	main.pause_ui.save_button.pressed.emit()
	c.ok(main.sim == null and main.character_select.continue_button.visible, "actual Save and Return writes state and exposes title Continue")
	main.character_select.continue_button.pressed.emit()
	c.ok(main.sim != null, "actual Continue restores new-state run")
	if main.sim != null:
		c.eq(RunSnapshot.capture(main.sim), before, "actual UI round trip retains every new role/support/order/debt field exactly")
		c.eq(main.hud.sim, main.sim, "Continue reconnects HUD to the restored run")
		var expected := RunSnapshot.restore(before)
		for _frame in 10:
			main._physics_process(0.02)
			expected.step(0.02, Vector2.ZERO)
		c.eq(RunSnapshot.capture(main.sim), RunSnapshot.capture(expected), "actual resumed Main combat continues with exact support, ability, order and RNG behavior")
	_dispose(main)


func test_language_option_save_failure_keeps_live_role_and_settings_context(c: Check) -> void:
	var main := _main()
	_shop_after_recording(main, &"mender")
	main.shop_ui.start_button.pressed.emit()
	main._unhandled_input(_key(KEY_SHIFT))
	main._unhandled_input(_key(KEY_P))
	main.pause_ui.settings_button.pressed.emit()
	var before := RunSnapshot.capture(main.sim)
	var live: Sim = main.sim
	var original_language := Loc.lang
	var blocker := _directory.path_join("blocked_language_parent")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("regular file")
	file.close()
	OS.set_environment("REVERB_SUSPEND", blocker.path_join("run.json"))
	main.settings_ui.language_option.item_selected.emit(2)
	c.eq(main.sim, live, "failed language save cannot replace active role session")
	c.eq(RunSnapshot.capture(main.sim), before, "failed language change preserves exact station, energy, copies and RNG")
	c.ok(main.settings_ui.visible and main.settings_ui.error_label.visible, "language control surfaces real save failure in settings")
	c.eq(Loc.lang, original_language, "failed language transition keeps current language context")
	_dispose(main)


# Explicit async probe for the integration runner: ordinary synchronous suites do
# not await scene replacement. This exercises a real new Main instance instead.
func probe_language_reload_new_context(c: Check) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous := tree.current_scene
	var main := _main()
	_shop_after_recording(main, &"mender")
	main.shop_ui.start_button.pressed.emit()
	main._unhandled_input(_key(KEY_SHIFT))
	main._unhandled_input(_key(KEY_P))
	main.pause_ui.settings_button.pressed.emit()
	var before := RunSnapshot.capture(main.sim)
	var old_id := main.get_instance_id()
	tree.current_scene = main
	main.settings_ui.language_option.item_selected.emit(2)
	for _frame in 6:
		await tree.process_frame
	var restored := tree.current_scene
	c.ok(restored != null and restored.get_instance_id() != old_id, "language control recreates a real Main context")
	if restored != null:
		restored.set_physics_process(false)
		c.eq(Loc.lang, "zh", "new context applies chosen language")
		c.eq(restored.settings.language, "zh", "chosen language persists in real settings")
		c.ok(restored.settings_ui.visible and restored.paused, "new context returns to paused settings")
		c.eq(RunSnapshot.capture(restored.sim), before, "language reload preserves exact new role and support gameplay state")
		c.eq(restored.hud.sim, restored.sim, "new context reconnects HUD to restored gameplay")
		tree.current_scene = previous
		_dispose(restored)


func test_archive_protected_record_credit_and_stale_end_action_feedback(c: Check) -> void:
	var main := _main()
	main.new_run(9950, &"looper")
	_take(main.sim, &"pistol", WeaponDef.MAX_LEVEL, 2.0)
	_lose(main)
	main.end_ui.archive_button.pressed.emit()
	var saved_bytes := FileAccess.get_file_as_bytes(main.meta.path)
	main.new_run(9951, &"looper")
	_take(main.sim, &"pistol", 0)
	_lose(main)
	saved_bytes = FileAccess.get_file_as_bytes(main.meta.path)
	main.end_ui.archive_button.pressed.emit()
	c.eq(main.end_ui._archive_note.text, Loc.t("archive.weaker_kept"), "keeping a stronger record is explained as a choice, not an I/O failure")
	c.eq(FileAccess.get_file_as_bytes(main.meta.path), saved_bytes, "weaker candidate does not replace persistent progress")
	main.new_run(9952, &"looper")
	main.sim.expedition["debt"] = 40
	var unpaid := _take(main.sim, &"pistol", WeaponDef.MAX_LEVEL, 8.0)
	_lose(main)
	saved_bytes = FileAccess.get_file_as_bytes(main.meta.path)
	c.ok(main.end_ui.archive_button.disabled, "unpaid advance cannot be carried into permanent archive")
	main.end_ui.archive_requested.emit(unpaid)
	c.eq(main.end_ui._archive_note.text, Loc.t("archive.debt"), "direct stale activation still explains its real debt blocker")
	c.eq(FileAccess.get_file_as_bytes(main.meta.path), saved_bytes, "unpaid candidate does not change the profile")
	main.new_run(9953, &"looper")
	main.end_ui.archive_requested.emit(unpaid)
	c.eq(FileAccess.get_file_as_bytes(main.meta.path), saved_bytes, "a previous end screen cannot archive into a live new session")
	_dispose(main)
