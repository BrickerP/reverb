extends Node

const RECORD_BEAT := 0.6
const VICTORY_BEAT := 0.9

var sim: Sim
var hud: Hud
var shop_ui: ShopUi
var end_ui: EndUi
var character_select: CharacterSelectUi
var meta: Meta
var audio: GameAudio
var paused: bool = false
var character_id: StringName = &"looper"

var _view: ArenaView
var _phase: Sim.Phase = Sim.Phase.SHOP
var _shop_delay := 0.0
var _end_delay := 0.0
var _recorded := false
var _unlock_text := ""


func _ready() -> void:
	Controls.register()
	audio = GameAudio.new()
	add_child(audio)
	var theme := UiTheme.build()
	_view = ArenaView.new()
	add_child(_view)
	hud = Hud.new()
	shop_ui = ShopUi.new()
	end_ui = EndUi.new()
	character_select = CharacterSelectUi.new()
	_add_layer(1, hud, theme)
	_add_layer(2, shop_ui, theme)
	_add_layer(3, end_ui, theme)
	_add_layer(4, character_select, theme)
	shop_ui.start_requested.connect(_on_start_requested)
	end_ui.restart_requested.connect(new_run)
	end_ui.character_requested.connect(show_select)
	character_select.character_chosen.connect(choose_character)
	var save := OS.get_environment("REVERB_SAVE")
	meta = Meta.new(save if save != "" else Meta.DEFAULT_PATH)
	show_select()


func new_run(seed_value: int = -1, char_id: StringName = &"") -> void:
	if char_id != &"":
		character_id = char_id
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
	sim.start_run()
	_phase = sim.phase


func choose_character(id: StringName) -> void:
	if meta != null and not meta.is_unlocked(id):
		return
	character_id = id
	new_run(-1, id)


func show_select() -> void:
	if character_select == null:
		return
	sim = null
	_phase = Sim.Phase.SHOP
	_set_paused(false)
	_shop_delay = 0.0
	_end_delay = 0.0
	hud.visible = false
	shop_ui.visible = false
	end_ui.visible = false
	_view.visible = false
	character_select.refresh(meta)
	character_select.visible = true


func toggle_pause() -> void:
	if sim != null and sim.phase == Sim.Phase.WAVE:
		_set_paused(not paused)


func _physics_process(delta: float) -> void:
	if paused or sim == null or character_select.visible:
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
	if event.is_action_pressed(&"pause"):
		toggle_pause()
	elif event.is_action_pressed(&"restart") and end_ui.visible:
		new_run()
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
