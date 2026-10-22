extends SceneTree
# Windowed screenshot of the local run history panel.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/history_shot.gd

var _main: Node
var _frame := 0
var _saved := false
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://history_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://history_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://history_shot_settings.json")
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	var log_path := ProjectSettings.globalize_path("user://history_shot_runs.jsonl")
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var log := RunLog.new("user://history_shot_runs.jsonl")
	var a := Sim.new(20261022)
	a.start_run()
	a.phase = Sim.Phase.LOST
	a.wave = 4
	a.kills = 71
	log.append(a, &"looper", 300.0)
	var b := Sim.new(7)
	b.start_run()
	b.phase = Sim.Phase.WON
	b.wave = 20
	b.kills = 2140
	log.append(b, &"mirror", 940.0)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main.history_ui == null:
		return false
	_frame += 1
	if _frame == 10:
		_main.open_history()
	if _frame >= 20 and not _saved:
		_saved = true
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(_dir.path_join("history.png"))
		print("wrote shots/history.png")
		_main.audio.stop_all()
	if _saved and _frame >= 28:
		quit()
		return true
	return false
