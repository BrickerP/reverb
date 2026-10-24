extends SceneTree
# Windowed screenshot of the win screen's endless continuation button.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/endless_shot.gd

var _ui: EndUi
var _sim: Sim
var _frame := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://endless_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://endless_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://endless_shot_settings.json")
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_sim = Sim.new(7)
	_sim.start_run()
	_sim.phase = Sim.Phase.WON
	_sim.wave = WaveDirector.FINAL_WAVE
	_ui = EndUi.new()
	_ui.theme = UiTheme.build()
	root.add_child(_ui)
	_show.call_deferred()


func _show() -> void:
	_ui.show_result(_sim)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame >= 20:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(_dir.path_join("endless.png"))
		print("wrote shots/endless.png")
		quit()
		return true
	return false
