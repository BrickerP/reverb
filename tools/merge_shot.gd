extends SceneTree
# Windowed screenshots of the echo merge (overdub) flow in the shop.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/merge_shot.gd

var _main: Node
var _frame := 0
var _step := 0
var _shop_frames := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://merge_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://merge_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://merge_shot_settings.json")
	var save := ProjectSettings.globalize_path("user://merge_shot_save.json")
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main.character_select == null:
		return false
	if _main.sim == null:
		if _main.character_select.visible:
			_main.choose_character(&"looper")
		return false
	_frame += 1
	match _step:
		0:
			if _frame >= 8:
				_setup()
				_frame = 0
				_step = 1
		1:
			if _main.shop_ui.visible:
				_shop_frames += 1
				if _shop_frames >= 60:
					_main.shop_ui.echo_panel.merge_button.pressed.emit()
					_frame = 0
					_step = 2
		2:
			if _frame >= 8:
				_save("shop_merge")
				_main.shop_ui.echo_panel.discard_buttons[0].pressed.emit()
				_frame = 0
				_step = 3
		3:
			if _frame >= 8:
				_save("shop_merge_selected")
				_main.shop_ui.echo_panel.discard_buttons[1].pressed.emit()
				_frame = 0
				_step = 4
		4:
			if _frame >= 8:
				_save("shop_merged")
				_main.audio.stop_all()
				_frame = 0
				_step = 5
		5:
			if _frame >= 8:
				quit()
				return true
	return false


func _setup() -> void:
	var sim: Sim = _main.sim
	for k in 3:
		var take := EchoTake.new()
		take.wave = k + 1
		take.weapons = sim.player.weapons.duplicate()
		take.stats = sim.player.stats.copy()
		var base := Sim.ARENA.get_center() + Vector2(-120.0 + float(k) * 120.0, 0.0)
		var path := PackedVector2Array()
		for i in 120:
			path.append(base + Vector2.from_angle(float(i) * 0.09 + float(k)) * (70.0 + 16.0 * float(k)))
		take.samples = path
		sim.bank.add(take)
	sim.start_wave(2)
	sim.wave_duration = 0.001


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
