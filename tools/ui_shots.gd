extends SceneTree
# Windowed screenshots of UI states that the main smoke run never pauses on:
# the first-wave controls hint and the pause panel.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/ui_shots.gd

var _main: Node
var _frame := 0
var _step := 0
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
				_frame = 0
				_step = 2
		2:
			if _frame >= 12:
				quit()
				return true
	return false


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
