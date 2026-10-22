extends Node

var sim: Sim
var hud: Hud
var shop_ui: ShopUi
var end_ui: EndUi
var paused: bool = false

var _view: ArenaView
var _phase: Sim.Phase = Sim.Phase.SHOP


func _ready() -> void:
	Controls.register()
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
	hud.visible = true
	shop_ui.visible = false
	end_ui.visible = false
	_set_paused(false)
	sim.start_run()
	_phase = sim.phase


func toggle_pause() -> void:
	if sim.phase == Sim.Phase.WAVE:
		_set_paused(not paused)


func _physics_process(delta: float) -> void:
	if paused:
		return
	sim.step(delta, Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))
	_sync_phase()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle_pause()
	elif event.is_action_pressed(&"restart") and end_ui.visible:
		new_run()


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
	hud.visible = _phase != Sim.Phase.SHOP
	match _phase:
		Sim.Phase.SHOP:
			shop_ui.open(sim)
		Sim.Phase.LOST, Sim.Phase.WON:
			end_ui.show_result(sim)


func _set_paused(on: bool) -> void:
	paused = on
	hud.paused = on
