extends SceneTree
# Windowed screenshot of the settings panel.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/settings_shot.gd

var _main: Node
var _frame := 0
var _saved := false
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://settings_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://settings_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://settings_shot_settings.json")
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main.settings_ui == null:
		return false
	_frame += 1
	if _frame == 10:
		_main.open_settings()
	if _frame >= 20 and not _saved:
		_saved = true
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(_dir.path_join("settings.png"))
		print("wrote shots/settings.png")
		_main.audio.stop_all()
	if _saved and _frame >= 28:
		quit()
		return true
	return false
