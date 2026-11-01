extends Node

const RECORD_BEAT := 0.6
const VICTORY_BEAT := 0.9
const PLAYER_DEATH_BEAT := BattleDirector.PLAYER_DEATH_TIME

var sim: Sim
var demo_run := false
var hud: Hud
var shop_ui: ShopUi
var end_ui: EndUi
var feedback_ui: FeedbackUi
var boon_ui: BoonUi
var echo_archive_ui: EchoArchiveUi
var character_select: CharacterSelectUi
var pause_ui: PauseUi
var settings_ui: SettingsUi
var history_ui: HistoryUi
var codex_ui: CodexUi
var settings: Settings
var meta: Meta
var run_log: RunLog
var feedback_log: FeedbackLog
var audio: GameAudio
var paused: bool = false
var character_id: StringName = &"looper"

var _view: ArenaView
var _arena_clip: Control
var _phase: Sim.Phase = Sim.Phase.SHOP
var _shop_delay := 0.0
var _end_delay := 0.0
var _recorded := false
var _unlock_text := ""
var _run_started_msec := 0
var _settings_restore_pause := false
var _daily_run := false
var _run_context: Dictionary = {}
var _latest_saved_run: Dictionary = {}
var echo_wheel: EchoSelectionWheel
var story_ui: StoryArchiveUi
var receipt_ui: StoryReceipt
var context_ui: ContextChoiceUi
var vending_ui: VendingReceiptUi
var _context_kind: StringName = &""
var _replace_dialog: ConfirmationDialog
var _pending_start: Dictionary = {}
var _retire_pressed := false
var _retire_hold := 0.0
var _story_restore_pause := false
static var _resume_after_language := false
const RETIRE_HOLD_TIME := 0.24


func _ready() -> void:
	get_tree().auto_accept_quit = false
	UserData.migrate_legacy()
	Controls.register()
	var sp := OS.get_environment("REVERB_SETTINGS")
	settings = Settings.new(sp if sp != "" else Settings.DEFAULT_PATH)
	if OS.get_environment("REVERB_LANG") == "" and settings.language != "":
		Loc.lang = settings.language
	_apply_audio()
	_apply_display()
	audio = GameAudio.new()
	add_child(audio)
	_apply_audio()
	var theme := UiTheme.build()
	_view = ArenaView.new()
	_view.shake_enabled = settings.shake
	# Keep the crop still while the world shakes inside it. The neutral origin
	# preserves existing simulation/drawing coordinates and view.position semantics.
	_arena_clip = Control.new()
	_arena_clip.name = "BattlefieldClip"
	_arena_clip.position = Sim.VIEWPORT.position
	_arena_clip.size = Sim.VIEWPORT.size
	_arena_clip.clip_contents = true
	_arena_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arena_clip)
	_view.set_cropped(true)
	_arena_clip.add_child(_view)
	get_viewport().size_changed.connect(_resize_battlefield)
	_resize_battlefield()
	hud = Hud.new()
	shop_ui = ShopUi.new()
	end_ui = EndUi.new()
	feedback_ui = FeedbackUi.new()
	boon_ui = BoonUi.new()
	echo_archive_ui = EchoArchiveUi.new()
	character_select = CharacterSelectUi.new()
	pause_ui = PauseUi.new()
	settings_ui = SettingsUi.new()
	history_ui = HistoryUi.new()
	codex_ui = CodexUi.new()
	_add_layer(1, hud, theme)
	_add_layer(2, shop_ui, theme)
	_add_layer(3, end_ui, theme)
	_add_layer(8, feedback_ui, theme)
	_add_layer(9, boon_ui, theme)
	_add_layer(4, character_select, theme)
	_add_layer(4, pause_ui, theme)
	_add_layer(5, settings_ui, theme)
	_add_layer(6, history_ui, theme)
	_add_layer(7, codex_ui, theme)
	_add_layer(12, echo_archive_ui, theme)
	echo_archive_ui.closed.connect(_restore_underlay_focus)
	character_select.archive_requested.connect(open_echo_archive)
	end_ui.archive_requested.connect(_on_archive_echo)
	echo_wheel = EchoSelectionWheel.new()
	story_ui = StoryArchiveUi.new()
	receipt_ui = StoryReceipt.new()
	context_ui = ContextChoiceUi.new()
	vending_ui = VendingReceiptUi.new()
	_add_layer(11, echo_wheel, theme)
	_add_layer(10, story_ui, theme)
	_add_layer(9, receipt_ui, theme)
	_add_layer(13, context_ui, theme)
	_add_layer(2, vending_ui, theme)
	context_ui.chosen.connect(_on_context_chosen)
	context_ui.save_requested.connect(save_and_return)
	context_ui.closed.connect(_on_context_closed)
	receipt_ui.position = Vector2(430.0, 220.0)
	receipt_ui.custom_minimum_size.x = 420.0
	receipt_ui.archive_requested.connect(open_story)
	receipt_ui.dismissed.connect(_on_receipt_closed)
	story_ui.closed.connect(_on_story_closed)
	echo_wheel.cancelled.connect(_cancel_retirement_selection)
	_replace_dialog = ConfirmationDialog.new()
	_replace_dialog.theme = theme
	_replace_dialog.title = Loc.t("select.replace_save_title")
	_replace_dialog.dialog_text = Loc.t("select.replace_save_body")
	_replace_dialog.ok_button_text = Loc.t("select.new_run")
	_replace_dialog.cancel_button_text = Loc.t("shop.cancel")
	_replace_dialog.confirmed.connect(_confirm_new_run)
	add_child(_replace_dialog)
	shop_ui.start_requested.connect(_on_start_requested)
	end_ui.restart_requested.connect(new_run)
	end_ui.character_requested.connect(show_select)
	end_ui.seed_retry_requested.connect(_retry_seed)
	end_ui.open_log_requested.connect(_open_log_folder)
	end_ui.endless_requested.connect(_on_endless_requested)
	end_ui.boss_rush_requested.connect(_on_boss_rush_requested)
	end_ui.feedback_requested.connect(open_feedback)
	feedback_ui.submit_requested.connect(_on_feedback_submit)
	feedback_ui.open_log_requested.connect(_open_log_folder)
	feedback_ui.closed.connect(_on_feedback_closed)
	boon_ui.chosen.connect(_on_boon_chosen)
	boon_ui.reroll_requested.connect(_on_boon_reroll)
	boon_ui.save_requested.connect(save_and_return)
	character_select.character_chosen.connect(choose_character)
	character_select.settings_requested.connect(open_settings)
	character_select.history_requested.connect(open_history)
	character_select.daily_requested.connect(start_daily)
	character_select.demo_requested.connect(start_demo)
	character_select.codex_requested.connect(open_codex)
	pause_ui.resume_requested.connect(_on_resume_requested)
	pause_ui.settings_requested.connect(open_settings)
	pause_ui.history_requested.connect(open_history)
	pause_ui.mute_requested.connect(_on_mute_requested)
	pause_ui.quit_requested.connect(_abandon_run)
	pause_ui.save_requested.connect(save_and_return)
	pause_ui.story_requested.connect(open_story)
	character_select.continue_requested.connect(continue_run)
	character_select.story_requested.connect(open_story)
	shop_ui.receipt_requested.connect(open_receipt)
	history_ui.replay_requested.connect(_on_history_replay)
	settings_ui.volume_changed.connect(_on_volume_changed)
	settings_ui.music_volume_changed.connect(_on_music_volume_changed)
	settings_ui.effects_volume_changed.connect(_on_effects_volume_changed)
	settings_ui.shake_changed.connect(_on_shake_changed)
	settings_ui.reduced_effects_changed.connect(_on_reduced_effects_changed)
	settings_ui.fullscreen_changed.connect(_on_fullscreen_changed)
	settings_ui.language_changed.connect(_on_language_changed)
	settings_ui.closed.connect(_on_settings_closed)
	history_ui.closed.connect(_on_history_closed)
	codex_ui.closed.connect(_on_codex_closed)
	_apply_reduced_effects()
	var save := OS.get_environment("REVERB_SAVE")
	meta = Meta.new(save if save != "" else Meta.DEFAULT_PATH)
	var log_path: String = OS.get_environment("REVERB_RUN_LOG")
	var actual_log_path: String = log_path if log_path != "" else RunLog.DEFAULT_PATH
	run_log = RunLog.new(actual_log_path)
	var feedback_path: String = OS.get_environment("REVERB_FEEDBACK_LOG")
	if feedback_path == "":
		feedback_path = actual_log_path.get_base_dir().path_join(
				FeedbackLog.DEFAULT_PATH.get_file())
	feedback_log = FeedbackLog.new(feedback_path)
	show_select()
	if _resume_after_language:
		_resume_after_language = false
		_resume_language_settings.call_deferred()


func new_run(seed_value: int = -1, char_id: StringName = &"", ascension_value: int = -1,
		daily_modifier: StringName = &"") -> void:
	SuspendStore.clear()
	_detach_presentation_session()
	feedback_ui.reset()
	boon_ui.close()
	_latest_saved_run.clear()
	if char_id != &"":
		character_id = char_id
	_daily_run = false
	sim = Sim.new(seed_value if seed_value >= 0 else randi())
	if ascension_value >= 0:
		sim.ascension = clampi(ascension_value, 0, 3)
	elif meta != null:
		sim.ascension = meta.ascension
	sim.daily_modifier = daily_modifier
	var def := Content.character(character_id)
	if def != null:
		def.apply(sim)
	var inherited: EchoTake = null
	if demo_run:
		sim.bank.add(EchoArchive.demo_take(Sim.ARENA.get_center()))
	else:
		inherited = EchoArchive.load(meta, character_id, sim)
		if inherited != null:
			sim.bank.add(inherited)
	_view.bind(sim, character_id)
	_view.visible = true
	hud.bind(sim)
	audio.bind(sim)
	_connect_run_events()
	hud.visible = true
	shop_ui.visible = false
	end_ui.visible = false
	character_select.visible = false
	_set_paused(false)
	_shop_delay = 0.0
	_end_delay = 0.0
	_recorded = false
	var source: String = OS.get_environment("REVERB_RUN_SOURCE")
	_run_context = run_log.new_context(source if source != "" else "unknown") if run_log != null else {}
	end_ui.set_feedback_available(false)
	_unlock_text = ""
	_run_started_msec = Time.get_ticks_msec()
	sim.start_run()
	_phase = sim.phase
	if inherited != null:
		vending_ui.show_take(inherited, sim)


func start_demo() -> void:
	demo_run = true
	new_run(-1, &"looper")


func choose_character(id: StringName, seed_value: int = -1) -> void:
	demo_run = false
	if meta != null and not meta.is_unlocked(id):
		return
	character_id = id
	var chosen := seed_value
	if chosen < 0 and character_select != null:
		chosen = character_select.chosen_seed()
	_request_start(chosen, id, -1, &"", false)


func _retry_seed(seed_value: int) -> void:
	var daily := _daily_run and sim != null
	var anomaly := sim.daily_modifier if daily else &""
	new_run(seed_value, character_id, 0 if daily else -1, anomaly)
	_daily_run = daily


func today_seed() -> int:
	var date := Time.get_date_dict_from_system()
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])


func start_daily() -> void:
	var seed_value := today_seed()
	_request_start(seed_value, &"looper", 0, DailyAnomaly.for_seed(seed_value), true)


func _open_log_folder() -> void:
	if run_log == null or DisplayServer.get_name() == "headless":
		return
	OS.shell_open(run_log.folder_path())


func open_feedback() -> void:
	if feedback_ui == null or feedback_ui.visible:
		return
	var run_id: String = str(_latest_saved_run.get("run_id", ""))
	var available: bool = not _latest_saved_run.is_empty() and feedback_log != null
	var duplicate: bool = available and feedback_log.has_feedback(run_id)
	feedback_ui.open_for_run(run_id, available, duplicate)


func _on_feedback_submit(category: StringName, rating: StringName, note: String) -> void:
	if feedback_log == null or _latest_saved_run.is_empty():
		feedback_ui.set_submission_result({"ok": false, "reason": "invalid_run", "record": {}})
		return
	var result: Dictionary = feedback_log.submit(_latest_saved_run, category, rating, note)
	feedback_ui.set_submission_result(result)


func _on_feedback_closed() -> void:
	if end_ui != null and end_ui.visible:
		end_ui.focus_default()


func open_settings() -> void:
	if settings_ui.visible or history_ui.visible:
		return
	_settings_restore_pause = paused
	if sim != null and sim.phase == Sim.Phase.WAVE and not paused:
		_set_paused(true)
	if pause_ui != null:
		pause_ui.close()
	settings_ui.open(settings)


func open_codex() -> void:
	if settings_ui.visible or history_ui.visible:
		return
	codex_ui.open()


func open_history() -> void:
	if history_ui.visible or settings_ui.visible or run_log == null:
		return
	if pause_ui != null:
		pause_ui.close()
	history_ui.open(run_log)


func _on_history_replay(seed_value: int, char_id: StringName, daily_modifier: StringName = &"") -> void:
	history_ui.close()
	if daily_modifier != &"":
		new_run(seed_value, char_id, 0, daily_modifier)
		_daily_run = true
		return
	choose_character(char_id, seed_value)


func _on_settings_closed() -> void:
	if _settings_restore_pause:
		if pause_ui != null:
			pause_ui.open(audio != null and audio.is_muted())
	elif sim != null and sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION]:
		_on_resume_requested()
	else:
		_restore_underlay_focus()
	_settings_restore_pause = false


func _on_history_closed() -> void:
	if paused and sim != null and sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION] and pause_ui != null:
		pause_ui.open(audio != null and audio.is_muted())
	else:
		_restore_underlay_focus()


func _on_codex_closed() -> void:
	_restore_underlay_focus()


func _on_volume_changed(value: float) -> void:
	settings.volume = value
	settings.save()
	_apply_audio()


func _on_shake_changed(on: bool) -> void:
	settings.shake = on
	settings.save()
	_view.shake_enabled = on


func _on_reduced_effects_changed(on: bool) -> void:
	settings.reduced_effects = on
	settings.save()
	_apply_reduced_effects()


func _on_fullscreen_changed(on: bool) -> void:
	settings.fullscreen = on
	settings.save()
	_apply_display()


func _on_language_changed(code: String) -> void:
	var active := sim != null and sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION]
	if active and not _save_active():
		settings_ui.open(settings)
		settings_ui.show_error(Loc.t(SuspendStore.last_error))
		return
	settings.language = code
	settings.save()
	if code == "":
		Loc.reset_lang()
	else:
		Loc.lang = code
	_resume_after_language = active
	get_tree().reload_current_scene()


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, settings.volume)))
	if audio != null:
		audio.set_music_volume(settings.music_volume)
		audio.set_effects_volume(settings.effects_volume)


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_window().min_size = Vector2i(960, 540)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_reduced_effects() -> void:
	if settings == null:
		return
	if hud != null:
		hud.set_reduced_effects(settings.reduced_effects)
	if _view != null:
		_view.set_reduced_effects(settings.reduced_effects)
	if shop_ui != null:
		shop_ui.set_reduced_effects(settings.reduced_effects)
	if end_ui != null:
		end_ui.set_reduced_effects(settings.reduced_effects)
	if echo_wheel != null:
		echo_wheel.reduced_effects = settings.reduced_effects
	if vending_ui != null:
		vending_ui.set_reduced_effects(settings.reduced_effects)


func show_select() -> void:
	if character_select == null:
		return
	_detach_presentation_session()
	_phase = Sim.Phase.SHOP
	_set_paused(false)
	_shop_delay = 0.0
	_end_delay = 0.0
	feedback_ui.reset()
	boon_ui.close()
	_run_context.clear()
	_latest_saved_run.clear()
	end_ui.set_feedback_available(false)
	codex_ui.close()
	hud.visible = false
	shop_ui.visible = false
	end_ui.visible = false
	_view.visible = false
	character_select.refresh(meta, today_seed(),
			meta.daily_best if meta.daily_seed == today_seed() else 0)
	character_select.set_resume_available(SuspendStore.exists())
	character_select.visible = true
	character_select.focus_default()


func _detach_presentation_session() -> void:
	_retire_pressed = false
	_retire_hold = 0.0
	_context_kind = &""
	if context_ui != null:
		context_ui.reset()
	if vending_ui != null:
		vending_ui.reset()
	if echo_archive_ui != null:
		echo_archive_ui.close()
	if echo_wheel != null:
		echo_wheel.close()
	if receipt_ui != null:
		receipt_ui.hide()
	if story_ui != null:
		story_ui.hide()
	if sim != null:
		if sim.echo_retired.is_connected(_on_retirement):
			sim.echo_retired.disconnect(_on_retirement)
		if sim.combo_triggered.is_connected(_on_combo):
			sim.combo_triggered.disconnect(_on_combo)
		if sim.wave_ended.is_connected(_on_story_wave):
			sim.wave_ended.disconnect(_on_story_wave)
	if _view != null:
		_view.unbind()
	if hud != null:
		hud.unbind()
	if shop_ui != null:
		shop_ui.close_session()
	if audio != null:
		audio.bind(null)
	sim = null


func toggle_pause() -> void:
	if sim != null and sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION]:
		if paused:
			_on_resume_requested()
		else:
			_set_paused(true)


func _physics_process(delta: float) -> void:
	_update_retirement_hold(delta)
	if paused or sim == null or character_select.visible or settings_ui.visible or history_ui.visible \
			or feedback_ui.visible or boon_ui.visible or story_ui.visible or receipt_ui.visible or echo_archive_ui.visible or context_ui.visible:
		return
	if _pending_context() == &"negotiation":
		_open_pending_context()
		return
	sim.step(delta, Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))
	if _shop_delay > 0.0:
		_shop_delay -= delta
		if _shop_delay <= 0.0:
			if sim.phase == Sim.Phase.RESOLUTION:
				_open_pending_context()
			else:
				_open_shop()
	if _end_delay > 0.0:
		_end_delay -= delta
		if _end_delay <= 0.0:
			_show_end()
	_sync_phase()
	if _pending_context() == &"negotiation":
		_open_pending_context()


func _unhandled_input(event: InputEvent) -> void:
	Controls.note_event(event)
	if context_ui.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			context_ui.close()
			get_viewport().set_input_as_handled()
		return
	if end_ui.visible and end_ui.replacement_pending:
		return
	if shop_ui.visible and shop_ui.confession != null and shop_ui.confession.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			shop_ui.confession.close()
			get_viewport().set_input_as_handled()
		return
	if echo_archive_ui.visible:
		if event.is_action_pressed(&"ui_cancel"):
			if echo_archive_ui.memory != null and echo_archive_ui.memory.visible:
				echo_archive_ui.memory.close()
			else:
				echo_archive_ui.close()
			get_viewport().set_input_as_handled()
		return
	if echo_wheel.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
			_cancel_retirement_selection()
			get_viewport().set_input_as_handled()
		return
	if story_ui.visible:
		if event.is_action_pressed(&"ui_cancel"):
			story_ui.close()
			get_viewport().set_input_as_handled()
		return
	if receipt_ui.visible:
		if event.is_action_pressed(&"ui_cancel"):
			receipt_ui.hide()
			_on_receipt_closed()
			get_viewport().set_input_as_handled()
		return
	if boon_ui.visible:
		return
	if feedback_ui.visible:
		if event.is_action_pressed(&"ui_cancel"):
			feedback_ui.close()
			get_viewport().set_input_as_handled()
		return
	if codex_ui.visible:
		if event.is_action_pressed(&"ui_cancel"):
			codex_ui.close()
			get_viewport().set_input_as_handled()
		return
	if history_ui.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"history"):
			history_ui.close()
			get_viewport().set_input_as_handled()
		return
	if settings_ui.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"settings"):
			settings_ui.close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"debug"):
		hud.debug = not hud.debug
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"settings"):
		open_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"history") and (character_select.visible or end_ui.visible):
		open_history()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"character_skill") and not event.is_echo() and not paused and sim != null and sim.phase == Sim.Phase.WAVE:
		sim.activate_character_skill()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact") and not event.is_echo() and not paused and sim != null and sim.phase == Sim.Phase.WAVE:
		sim.interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"retire_echo") and not event.is_echo() and not paused and sim != null and sim.phase == Sim.Phase.WAVE:
		_retire_pressed = true
		_retire_hold = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		toggle_pause()
	elif event.is_action_pressed(&"restart") and end_ui.visible:
		new_run()
	elif event.is_action_pressed(&"retry") and end_ui.visible and sim != null:
		_retry_seed(sim.run_seed)
	elif event.is_action_pressed(&"quit_run") and paused:
		save_and_return()
	elif event.is_action_pressed(&"character") and end_ui.visible:
		show_select()
	elif event.is_action_pressed(&"mute"):
		_on_mute_requested()


func _add_layer(index: int, ui: Control, theme: Theme) -> void:
	var layer := CanvasLayer.new()
	layer.layer = index
	add_child(layer)
	ui.theme = theme
	layer.add_child(ui)


func _on_start_requested() -> void:
	sim.start_next_wave()
	_sync_phase()


func _sync_phase() -> void:
	if sim == null or sim.phase == _phase:
		return
	_phase = sim.phase
	_set_paused(false)
	match _phase:
		Sim.Phase.WAVE:
			hud.visible = true
			_persist_story()
		Sim.Phase.SHOP:
			# Hold on the arena for a beat: the wave is being recorded, then the shop opens.
			hud.visible = true
			if sim.pending_boons.size() > 0:
				_shop_delay = 0.0
				_show_boon()
			else:
				_shop_delay = RECORD_BEAT
				_view.play_record_beat(sim)
		Sim.Phase.LOST:
			hud.visible = true
			_record_run()
			# The run is already terminal and recorded; only the summary waits for the paper fall.
			_end_delay = PLAYER_DEATH_BEAT
		Sim.Phase.RESOLUTION:
			hud.visible = true
			shop_ui.visible = false
			_shop_delay = RECORD_BEAT
			_view.play_record_beat(sim)
		Sim.Phase.WON:
			# Let the boss death land before the summary covers it.
			hud.visible = true
			_record_run()
			_end_delay = VICTORY_BEAT
			_view.play_victory_beat(sim)


func _record_run() -> void:
	if _recorded or sim == null or meta == null:
		return
	_recorded = true
	SuspendStore.clear()
	_persist_story()
	meta.stage_bureau_report(sim, str(_run_context.get("run_id", "")))
	if sim.endless:
		meta.record_endless(sim)
		if run_log != null:
			var endless_seconds := float(Time.get_ticks_msec() - _run_started_msec) / 1000.0
			var saved_endless: Dictionary = run_log.append(sim, character_id, endless_seconds, _run_context)
			if not saved_endless.is_empty():
				_latest_saved_run = saved_endless
		end_ui.set_feedback_available(not _latest_saved_run.is_empty())
		return
	var newly := meta.record_run(sim)
	if _daily_run and sim.run_seed == today_seed():
		meta.record_daily(sim, sim.run_seed)
	if run_log != null:
		var seconds := float(Time.get_ticks_msec() - _run_started_msec) / 1000.0
		var saved: Dictionary = run_log.append(sim, character_id, seconds, _run_context)
		if not saved.is_empty():
			_latest_saved_run = saved
	end_ui.set_feedback_available(not _latest_saved_run.is_empty())
	if newly.is_empty():
		return
	var names := PackedStringArray()
	for id in newly:
		names.append(Loc.character_name(id))
	_unlock_text = Loc.t("end.unlocked", [", ".join(names)])


func _open_shop() -> void:
	if sim.phase != Sim.Phase.SHOP or shop_ui.visible:
		return
	_shop_delay = 0.0
	hud.visible = false
	shop_ui.demo_closed = demo_run
	shop_ui.open(sim)
	_persist_story()


func _show_boon() -> void:
	shop_ui.visible = false
	hud.visible = true
	boon_ui.open(sim.pending_boons, sim)


func _on_boon_chosen(index: int) -> void:
	if sim == null or not sim.choose_boon(index):
		return
	if not sim.pending_boons.is_empty():
		_show_boon()
		return
	boon_ui.close()
	_shop_delay = 0.0
	_open_shop()


func _on_boon_reroll() -> void:
	if sim == null or not sim.reroll_boons():
		return
	_show_boon()


func _show_end() -> void:
	_end_delay = 0.0
	if hud != null:
		hud.visible = false
	if sim != null and not end_ui.visible:
		end_ui.show_result(sim, _unlock_text, meta)


func _pending_context() -> StringName:
	if sim == null:
		return &""
	if sim.phase == Sim.Phase.RESOLUTION:
		return &"exit"
	if sim.phase == Sim.Phase.WAVE and sim.expedition.get("negotiation", {}).get("choice_pending", false):
		return &"negotiation"
	return &""


func _open_pending_context() -> void:
	var kind := _pending_context()
	if kind == &"":
		return
	_context_kind = kind
	if kind == &"exit":
		_shop_delay = 0.0
	_set_paused(true)
	pause_ui.close()
	var choices := Expedition.exit_options(sim) if kind == &"exit" else Expedition.negotiation_options(sim)
	var title := "context.exit.title" if kind == &"exit" else "context.negotiation.title"
	var body := "context.exit.body" if kind == &"exit" else "context.negotiation.body"
	context_ui.open_context(title, body, choices, true)


func _on_context_chosen(id: StringName) -> void:
	if sim == null or not context_ui.visible or _context_kind != _pending_context():
		return
	# Choosing is synchronous and the sheet still blocks input. Release the audio
	# pause before the authoritative win event, so its cue is not discarded.
	_set_paused(false)
	var accepted := sim.choose_exit(id) if _context_kind == &"exit" else sim.choose_negotiation(id)
	if not accepted:
		_open_pending_context()
		context_ui.show_error(Loc.t("context.changed"))
		return
	context_ui.reset()
	_context_kind = &""
	_persist_story()
	_sync_phase()


func _on_context_closed() -> void:
	_context_kind = &""
	_set_paused(true)


func _on_resume_requested() -> void:
	if _pending_context() != &"":
		_open_pending_context()
	else:
		_set_paused(false)


func _on_endless_requested() -> void:
	if sim == null or not sim.begin_endless():
		return
	_leave_victory_for_endless()


func _on_boss_rush_requested() -> void:
	if sim == null or not sim.begin_boss_rush():
		return
	_leave_victory_for_endless()


func _leave_victory_for_endless() -> void:
	end_ui.visible = false
	if _recorded and run_log != null:
		run_log.remove_last()
	_recorded = false
	_latest_saved_run.clear()
	end_ui.set_feedback_available(false)
	_view.clear_victory()
	_sync_phase()


func _set_paused(on: bool) -> void:
	paused = on
	hud.paused = on
	if _view != null:
		_view.set_paused(on)
	if audio != null:
		audio.set_paused(on)
	if shop_ui != null:
		shop_ui.set_paused(on)
	if vending_ui != null:
		vending_ui.set_paused(on)
	if pause_ui == null:
		return
	if on:
		pause_ui.open(audio != null and audio.is_muted())
	else:
		pause_ui.close()


func _on_mute_requested() -> void:
	if audio == null:
		return
	audio.toggle_mute()
	if pause_ui != null and pause_ui.visible:
		pause_ui.set_muted(audio.is_muted())


func _restore_underlay_focus() -> void:
	if paused and sim != null and sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION] and pause_ui != null:
		pause_ui.open(audio != null and audio.is_muted())
	elif end_ui != null and end_ui.visible:
		end_ui.focus_default()
	elif character_select != null and character_select.visible:
		character_select.focus_default()
	elif shop_ui != null and shop_ui.visible:
		shop_ui.focus_default()


func _connect_run_events() -> void:
	sim.echo_retired.connect(_on_retirement)
	sim.combo_triggered.connect(_on_combo)
	sim.wave_ended.connect(_on_story_wave)


func _on_retirement(info: EchoRetirementInfo) -> void:
	_view.react_retirement(info)
	_persist_story()


func _on_combo(info: ComboInfo) -> void:
	hud.set_combo_feedback(info)


func _on_story_wave(_wave: int) -> void:
	_persist_story()


func _persist_story() -> void:
	if sim != null and meta != null:
		if not meta.discover_story(StoryLedger.discovered(sim)) and meta.last_error != "" and pause_ui.visible:
			pause_ui.show_error(Loc.t("story.save_failed"))


func _on_music_volume_changed(value: float) -> void:
	settings.music_volume = value
	settings.save()
	_apply_audio()


func _on_effects_volume_changed(value: float) -> void:
	settings.effects_volume = value
	settings.save()
	_apply_audio()


func _request_start(seed_value: int, id: StringName, ascension_value: int,
		anomaly: StringName, daily: bool) -> void:
	if SuspendStore.exists():
		_pending_start = {"seed": seed_value, "character": id,
			"ascension": ascension_value, "anomaly": anomaly, "daily": daily}
		_replace_dialog.popup_centered(Vector2i(520, 180))
		return
	new_run(seed_value, id, ascension_value, anomaly)
	_daily_run = daily


func _confirm_new_run() -> void:
	if _pending_start.is_empty():
		return
	var pending := _pending_start.duplicate()
	_pending_start.clear()
	new_run(int(pending.seed), StringName(pending.character), int(pending.ascension), StringName(pending.anomaly))
	_daily_run = bool(pending.daily)


func _save_active() -> bool:
	if sim == null or not sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION]:
		return false
	_persist_story()
	return SuspendStore.save(sim, {
		"main_version": 1, "character_id": character_id, "daily": _daily_run, "paused": paused,
		"shop_delay": _shop_delay, "end_delay": _end_delay, "recorded": _recorded,
		"shop_visible": shop_ui.visible, "settings_restore_pause": _settings_restore_pause,
		"elapsed_msec": maxi(0, Time.get_ticks_msec() - _run_started_msec),
		"run_context": _run_context.duplicate(true), "unlock_text": _unlock_text})


func save_and_return() -> bool:
	if not _save_active():
		_show_save_error(Loc.t(SuspendStore.last_error if SuspendStore.last_error != "" else "suspend.write_failed"))
		return false
	show_select()
	return true


func continue_run(restore_pause: bool = false) -> bool:
	var saved := SuspendStore.load()
	if saved.is_empty():
		character_select.set_resume_available(SuspendStore.exists(), Loc.t(SuspendStore.last_error))
		return false
	if not saved.get("envelope") is Dictionary or not _valid_main_envelope(saved.envelope):
		character_select.set_resume_available(true, Loc.t("suspend.corrupt"))
		return false
	var envelope: Dictionary = saved.envelope
	var id := StringName(str(envelope.get("character_id", "looper")))
	if Content.character(id) == null:
		character_select.set_resume_available(true, Loc.t("suspend.corrupt"))
		return false
	_detach_presentation_session()
	sim = saved.sim as Sim
	character_id = id
	_daily_run = bool(envelope.get("daily", false))
	_recorded = bool(envelope.get("recorded", false))
	_shop_delay = float(envelope.get("shop_delay", 0.0))
	_end_delay = float(envelope.get("end_delay", 0.0))
	_run_started_msec = Time.get_ticks_msec() - int(envelope.get("elapsed_msec", 0))
	_run_context = (envelope.get("run_context", {}) as Dictionary).duplicate(true)
	_unlock_text = str(envelope.get("unlock_text", ""))
	_settings_restore_pause = bool(envelope.get("settings_restore_pause", false))
	_phase = sim.phase
	_view.bind(sim, character_id)
	hud.bind(sim)
	audio.bind(sim)
	_connect_run_events()
	character_select.visible = false
	end_ui.visible = false
	shop_ui.visible = false
	_view.visible = true
	hud.visible = true
	_set_paused(restore_pause and bool(envelope.get("paused", false)))
	if sim.phase == Sim.Phase.SHOP:
		if not sim.pending_boons.is_empty():
			_show_boon()
		elif bool(envelope.get("shop_visible", true)) or _shop_delay <= 0.0:
			_open_shop()
	if _pending_context() != &"":
		_shop_delay = 0.0
		_open_pending_context()
	_persist_story()
	return true


func _resume_language_settings() -> void:
	if continue_run(true):
		context_ui.reset()
		_set_paused(true)
		pause_ui.close()
		settings_ui.open(settings)


func _abandon_run() -> void:
	SuspendStore.clear()
	show_select()


func open_story() -> void:
	_story_restore_pause = paused
	if sim != null:
		_set_paused(true)
		pause_ui.close()
	if receipt_ui != null:
		receipt_ui.hide()
	_persist_story()
	story_ui.open(meta)


func _on_story_closed() -> void:
	if sim != null:
		_set_paused(_story_restore_pause)
	_restore_underlay_focus()


func open_receipt() -> void:
	if sim == null or sim.phase != Sim.Phase.SHOP:
		return
	receipt_ui.display(sim)
	if receipt_ui.visible:
		receipt_ui.archive_button.grab_focus()


func _on_receipt_closed() -> void:
	shop_ui.refresh_receipt()
	_restore_underlay_focus()


func _input(event: InputEvent) -> void:
	Controls.note_event(event)
	if event.is_action_released(&"retire_echo") and _retire_pressed:
		var held := _retire_hold
		_retire_pressed = false
		_retire_hold = 0.0
		if echo_wheel.visible:
			var selected := echo_wheel.close()
			if sim != null and selected > 0:
				sim.select_echo(selected)
			_set_paused(false)
		elif held < RETIRE_HOLD_TIME and sim != null and not paused:
			sim.retire_selected_echo()
		get_viewport().set_input_as_handled()


func _update_retirement_hold(delta: float) -> void:
	if not _retire_pressed or echo_wheel.visible or sim == null:
		return
	_retire_hold += delta
	if _retire_hold >= RETIRE_HOLD_TIME and not paused and sim.phase == Sim.Phase.WAVE:
		_set_paused(true)
		pause_ui.close()
		echo_wheel.open(sim)


func _cancel_retirement_selection() -> void:
	_retire_pressed = false
	_retire_hold = 0.0
	if echo_wheel.visible:
		echo_wheel.close()
	_set_paused(false)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if sim != null and sim.phase in [Sim.Phase.WAVE, Sim.Phase.SHOP, Sim.Phase.RESOLUTION]:
		if not _save_active():
			if not context_ui.visible:
				_set_paused(true)
			_show_save_error(Loc.t(SuspendStore.last_error))
			return
	get_tree().quit()


func _show_save_error(message: String) -> void:
	if context_ui.visible:
		context_ui.show_error(message)
	elif boon_ui.visible:
		boon_ui.show_error(message)
	elif settings_ui.visible:
		settings_ui.show_error(message)
	else:
		story_ui.hide()
		receipt_ui.hide()
		pause_ui.show_error(message)


func _valid_main_envelope(value: Dictionary) -> bool:
	var required := {"main_version": TYPE_INT, "daily": TYPE_BOOL, "paused": TYPE_BOOL,
		"recorded": TYPE_BOOL, "shop_visible": TYPE_BOOL, "settings_restore_pause": TYPE_BOOL,
		"elapsed_msec": TYPE_INT, "run_context": TYPE_DICTIONARY, "unlock_text": TYPE_STRING}
	for key: String in required:
		if not value.has(key) or typeof(value[key]) != int(required[key]):
			return false
	if int(value.main_version) != 1 or int(value.elapsed_msec) < 0:
		return false
	if not value.has("character_id") or not typeof(value.character_id) in [TYPE_STRING, TYPE_STRING_NAME]:
		return false
	for key: String in ["shop_delay", "end_delay"]:
		if not value.has(key) or not typeof(value[key]) in [TYPE_FLOAT, TYPE_INT]:
			return false
		if not is_finite(float(value[key])) or float(value[key]) < 0.0 or float(value[key]) > 20.0:
			return false
	return true


func open_echo_archive(id: StringName = &"looper") -> void:
	if echo_archive_ui == null or meta == null:
		return
	echo_archive_ui.open(meta, id)


func _on_archive_echo(take: EchoTake) -> void:
	if sim == null or _daily_run or sim.daily_modifier != &"" or take == null or not EchoArchive.eligible(character_id) or sim.phase not in [Sim.Phase.LOST, Sim.Phase.WON] or not sim.bank.takes.has(take):
		return
	if int(sim.expedition.get("debt", 0)) > 0:
		end_ui.set_archive_result(false, "archive.debt")
		return
	var saved := EchoArchive.store(meta, character_id, take)
	end_ui.set_archive_result(saved, meta.last_error)


func _resize_battlefield() -> void:
	if _arena_clip == null or _view == null:
		return
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		var desired := Vector2i(mini(1280, maxi(640, window.size.x)), mini(720, maxi(480, window.size.y)))
		if window.content_scale_size != desired:
			window.content_scale_size = desired
	var viewport_size := get_viewport().get_visible_rect().size
	var rect := WorldArena.display_viewport(viewport_size)
	_arena_clip.position = rect.position
	_arena_clip.size = rect.size
	_view.set_display_rect(rect)
