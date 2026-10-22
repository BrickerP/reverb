extends SceneTree
# Windowed screenshots of the character select, locked and unlocked.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/select_shot.gd

var _main: Node
var _frame := 0
var _step := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://select_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://select_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://select_shot_settings.json")
	var save := ProjectSettings.globalize_path("user://select_shot_save.json")
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	match _step:
		0:
			if _frame >= 20:
				_save("select")
				_main.meta.unlocked[&"solo"] = true
				_main.character_select.refresh(_main.meta)
				_frame = 0
				_step = 1
		1:
			if _frame >= 20:
				_save("select_unlocked")
				_main.audio.stop_all()
				_frame = 0
				_step = 2
		2:
			if _frame >= 8:
				quit()
				return true
	return false


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
