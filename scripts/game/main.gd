extends Node

const RECORD_BEAT := 0.6
const VICTORY_BEAT := 0.9

var sim: Sim
var hud: Hud
var shop_ui: ShopUi
var end_ui: EndUi
var audio: GameAudio
var paused: bool = false

var _view: ArenaView
var _phase: Sim.Phase = Sim.Phase.SHOP
var _shop_delay := 0.0
var _end_delay := 0.0


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
	_add_layer(1, hud, theme)
	_add_layer(2, shop_ui, theme)
	_add_layer(3, end_ui, theme)
	shop_ui.start_requested.connect(_on_start_requested)
	end_ui.restart_requested.connect(new_run)
	new_run()


func new_run(seed_value: int = -1) -> void:
	sim = Sim.new(seed_value if seed_value >= 0 else randi())
	_view.bind(sim)
	hud.bind(sim)
	audio.bind(sim)
	hud.visible = true
	shop_ui.visible = false
	end_ui.visible = false
	_set_paused(false)
	_shop_delay = 0.0
	_end_delay = 0.0
	sim.start_run()
	_phase = sim.phase


func toggle_pause() -> void:
	if sim.phase == Sim.Phase.WAVE:
		_set_paused(not paused)


func _physics_process(delta: float) -> void:
	if paused:
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
	if sim.phase == _phase:
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
			end_ui.show_result(sim)
		Sim.Phase.WON:
			# Let the boss death land before the summary covers it.
			hud.visible = true
			_end_delay = VICTORY_BEAT
			_view.play_victory_beat(sim)


func _open_shop() -> void:
	if sim.phase != Sim.Phase.SHOP or shop_ui.visible:
		return
	_shop_delay = 0.0
	hud.visible = false
	shop_ui.open(sim)


func _show_end() -> void:
	_end_delay = 0.0
	if not end_ui.visible:
		end_ui.show_result(sim)


func _set_paused(on: bool) -> void:
	paused = on
	hud.paused = on
