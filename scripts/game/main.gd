extends Node

const RECORD_BEAT := 0.6
const VICTORY_BEAT := 0.9

var sim: Sim
var hud: Hud
var shop_ui: ShopUi
var end_ui: EndUi
var character_select: CharacterSelectUi
var pause_ui: PauseUi
var settings_ui: SettingsUi
var history_ui: HistoryUi
var codex_ui: CodexUi
var settings: Settings
var meta: Meta
var run_log: RunLog
var audio: GameAudio
var paused: bool = false
var character_id: StringName = &"looper"

var _view: ArenaView
var _phase: Sim.Phase = Sim.Phase.SHOP
var _shop_delay := 0.0
var _end_delay := 0.0
var _recorded := false
var _unlock_text := ""
var _run_started_msec := 0
var _settings_restore_pause := false
var _daily_run := false


func _ready() -> void:
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
	var theme := UiTheme.build()
	_view = ArenaView.new()
	_view.shake_enabled = settings.shake
	add_child(_view)
	hud = Hud.new()
	shop_ui = ShopUi.new()
	end_ui = EndUi.new()
	character_select = CharacterSelectUi.new()
	pause_ui = PauseUi.new()
	settings_ui = SettingsUi.new()
	history_ui = HistoryUi.new()
	codex_ui = CodexUi.new()
	_add_layer(1, hud, theme)
	_add_layer(2, shop_ui, theme)
	_add_layer(3, end_ui, theme)
	_add_layer(4, character_select, theme)
	_add_layer(4, pause_ui, theme)
	_add_layer(5, settings_ui, theme)
	_add_layer(6, history_ui, theme)
	_add_layer(7, codex_ui, theme)
	shop_ui.start_requested.connect(_on_start_requested)
	end_ui.restart_requested.connect(new_run)
	end_ui.character_requested.connect(show_select)
	end_ui.seed_retry_requested.connect(_retry_seed)
	end_ui.open_log_requested.connect(_open_log_folder)
	character_select.character_chosen.connect(choose_character)
	character_select.settings_requested.connect(open_settings)
	character_select.history_requested.connect(open_history)
	character_select.daily_requested.connect(start_daily)
	character_select.codex_requested.connect(open_codex)
	pause_ui.resume_requested.connect(func() -> void: _set_paused(false))
	pause_ui.settings_requested.connect(open_settings)
	pause_ui.history_requested.connect(open_history)
	pause_ui.mute_requested.connect(func() -> void: audio.toggle_mute())
	pause_ui.quit_requested.connect(show_select)
	history_ui.replay_requested.connect(_on_history_replay)
	settings_ui.volume_changed.connect(_on_volume_changed)
	settings_ui.shake_changed.connect(_on_shake_changed)
	settings_ui.fullscreen_changed.connect(_on_fullscreen_changed)
	settings_ui.language_changed.connect(_on_language_changed)
	settings_ui.closed.connect(_on_settings_closed)
	history_ui.closed.connect(_on_history_closed)
	var save := OS.get_environment("REVERB_SAVE")
	meta = Meta.new(save if save != "" else Meta.DEFAULT_PATH)
	var log_path := OS.get_environment("REVERB_RUN_LOG")
	run_log = RunLog.new(log_path if log_path != "" else RunLog.DEFAULT_PATH)
	show_select()


func new_run(seed_value: int = -1, char_id: StringName = &"") -> void:
	if char_id != &"":
		character_id = char_id
	_daily_run = false
	sim = Sim.new(seed_value if seed_value >= 0 else randi())
	var def := Content.character(character_id)
	if def != null:
		def.apply(sim)
	_view.bind(sim)
	_view.visible = true
	hud.bind(sim)
	audio.bind(sim)
	hud.visible = true
	shop_ui.visible = false
	end_ui.visible = false
	character_select.visible = false
	_set_paused(false)
	_shop_delay = 0.0
	_end_delay = 0.0
	_recorded = false
	_unlock_text = ""
	_run_started_msec = Time.get_ticks_msec()
	sim.start_run()
	_phase = sim.phase


func choose_character(id: StringName, seed_value: int = -1) -> void:
	if meta != null and not meta.is_unlocked(id):
		return
	character_id = id
	var chosen := seed_value
	if chosen < 0 and character_select != null:
		chosen = character_select.chosen_seed()
	new_run(chosen, id)


func _retry_seed(seed_value: int) -> void:
	new_run(seed_value, character_id)


func today_seed() -> int:
	var date := Time.get_date_dict_from_system()
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])


func start_daily() -> void:
	new_run(today_seed(), &"looper")
	_daily_run = true


func _open_log_folder() -> void:
	if run_log == null or DisplayServer.get_name() == "headless":
		return
	OS.shell_open(run_log.folder_path())


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


func _on_history_replay(seed_value: int, char_id: StringName) -> void:
	history_ui.close()
	choose_character(char_id, seed_value)


func _on_settings_closed() -> void:
	if _settings_restore_pause:
		if pause_ui != null:
			pause_ui.open()
	elif sim != null and sim.phase == Sim.Phase.WAVE:
		_set_paused(false)
	_settings_restore_pause = false


func _on_history_closed() -> void:
	if paused and sim != null and sim.phase == Sim.Phase.WAVE and pause_ui != null:
		pause_ui.open()


func _on_volume_changed(value: float) -> void:
	settings.volume = value
	settings.save()
	_apply_audio()


func _on_shake_changed(on: bool) -> void:
	settings.shake = on
	settings.save()
	_view.shake_enabled = on


func _on_fullscreen_changed(on: bool) -> void:
	settings.fullscreen = on
	settings.save()
	_apply_display()


func _on_language_changed(code: String) -> void:
	settings.language = code
	settings.save()
	if code == "":
		Loc.reset_lang()
	else:
		Loc.lang = code
	get_tree().reload_current_scene()


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, settings.volume)))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func show_select() -> void:
	if character_select == null:
		return
	sim = null
	_phase = Sim.Phase.SHOP
	_set_paused(false)
	_shop_delay = 0.0
	_end_delay = 0.0
	codex_ui.close()
	hud.visible = false
	shop_ui.visible = false
	end_ui.visible = false
	_view.visible = false
	character_select.refresh(meta, today_seed(),
			meta.daily_best if meta.daily_seed == today_seed() else 0)
	character_select.visible = true


func toggle_pause() -> void:
	if sim != null and sim.phase == Sim.Phase.WAVE:
		_set_paused(not paused)


func _physics_process(delta: float) -> void:
	if paused or sim == null or character_select.visible or settings_ui.visible or history_ui.visible:
		return
	sim.step(delta, Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))
	if _shop_delay > 0.0:
		_shop_delay -= delta
		if _shop_delay <= 0.0:
			_open_shop()
	if _end_delay > 0.0:
		_end_delay -= delta
		if _end_delay <= 0.0:
			_show_end()
	_sync_phase()


func _unhandled_input(event: InputEvent) -> void:
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
	elif event.is_action_pressed(&"pause"):
		toggle_pause()
	elif event.is_action_pressed(&"restart") and end_ui.visible:
		new_run()
	elif event.is_action_pressed(&"retry") and end_ui.visible and sim != null:
		_retry_seed(sim.run_seed)
	elif event.is_action_pressed(&"quit_run") and paused:
		show_select()
	elif event.is_action_pressed(&"character") and end_ui.visible:
		show_select()
	elif event.is_action_pressed(&"mute"):
		audio.toggle_mute()


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
		Sim.Phase.SHOP:
			# Hold on the arena for a beat: the wave is being recorded, then the shop opens.
			hud.visible = true
			_shop_delay = RECORD_BEAT
			_view.play_record_beat(sim)
		Sim.Phase.LOST:
			hud.visible = true
			_record_run()
			end_ui.show_result(sim, _unlock_text)
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
	var newly := meta.record_run(sim)
	if _daily_run and sim.run_seed == today_seed():
		meta.record_daily(sim, sim.run_seed)
	if run_log != null:
		var seconds := float(Time.get_ticks_msec() - _run_started_msec) / 1000.0
		run_log.append(sim, character_id, seconds)
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
	shop_ui.open(sim)


func _show_end() -> void:
	_end_delay = 0.0
	if sim != null and not end_ui.visible:
		end_ui.show_result(sim, _unlock_text)


func _set_paused(on: bool) -> void:
	paused = on
	hud.paused = on
	if pause_ui == null:
		return
	if on:
		pause_ui.open()
	else:
		pause_ui.close()
