extends SceneTree
# Windowed screenshots of UI states that the main smoke run never pauses on:
# controls hint, pause panel, echo path reveal, wave-end recording beat, and a take arriving in the shop.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/ui_shots.gd

var _main: Node
var _frame := 0
var _step := 0
var _beat_frames := 0
var _shop_frames := 0
var _dir := ""


func _initialize() -> void:
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main.sim == null:
		return false
	_frame += 1
	match _step:
		0:
			if _frame >= 45:
				_save("start")
				_main.toggle_pause()
				_frame = 0
				_step = 1
		1:
			if _frame >= 12:
				_save("pause")
				_main.toggle_pause()
				_echo_demo()
				_frame = 0
				_step = 2
		2:
			if _frame >= 12:
				_save("reveal")
				_frame = 0
				_step = 3
		3:
			if _frame >= 72:
				_release()
				_save("echoes")
				_main.sim.wave_duration = 0.001
				_frame = 0
				_step = 4
			else:
				_drive_square()
		4:
			if _main.shop_ui.visible:
				_shop_frames += 1
				if _shop_frames == 10:
					_save("shop_arrive")
				elif _shop_frames >= 70:
					_save("shop_settled")
					_blocked_demo()
					_frame = 0
					_step = 5
			elif _main.sim.phase == Sim.Phase.SHOP:
				_beat_frames += 1
				if _beat_frames == 12:
					_save("record_beat")
		5:
			if _frame >= 3:
				_save("shop_blocked")
				quit()
				return true
	return false


func _echo_demo() -> void:
	var sim: Sim = _main.sim
	sim.player.stats.values[Stats.ECHO_SLOTS] = 4.0
	for k in 4:
		var take := EchoTake.new()
		take.wave = k + 1
		take.weapons = sim.player.weapons.duplicate()
		take.stats = sim.player.stats.copy()
		var base := Sim.ARENA.get_center() + Vector2(-180.0 + float(k) * 120.0, 0.0)
		var path := PackedVector2Array()
		for i in 120:
			path.append(base + Vector2.from_angle(float(i) * 0.09) * (70.0 + 18.0 * float(k)))
		take.samples = path
		sim.bank.add(take)
	sim.start_wave(2)


func _blocked_demo() -> void:
	var ui: ShopUi = _main.shop_ui
	_main.sim.player.materials = 0
	_main.sim.shop.roll(_main.sim)
	ui.refresh()
	for node in ui.offers_box.get_children():
		var card := node as OfferCard
		if card.blocked_reason == &"poor":
			card.pressed.emit()
			return


func _drive_square() -> void:
	_release()
	match int(_frame / 18) % 4:
		0:
			Input.action_press(&"move_right")
		1:
			Input.action_press(&"move_down")
		2:
			Input.action_press(&"move_left")
		3:
			Input.action_press(&"move_up")


func _release() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
