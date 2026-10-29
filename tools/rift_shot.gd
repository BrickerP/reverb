extends SceneTree
# Windowed screenshot of a temporal rift warning and active field.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/rift_shot.gd

var _main: Node
var _frame := 0
var _step := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_rift_shot_suspend.json")
	OS.set_environment("REVERB_SAVE", "user://rift_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://rift_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://rift_shot_settings.json")
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
			if _frame >= 10:
				_setup()
				_frame = 0
				_step = 1
		1:
			if _frame >= 16:
				_save("rifts")
				_main.audio.stop_all()
				quit()
				return true
	return false


func _setup() -> void:
	var sim: Sim = _main.sim
	sim.start_wave(12)
	sim._plan.clear()
	sim._plan_idx = 0
	sim.pending.clear()
	sim.enemies.clear()
	var warning := TemporalRift.new()
	warning.pos = Vector2(500.0, 330.0)
	warning.telegraph = 1.0
	var active := TemporalRift.new()
	active.pos = Vector2(820.0, 420.0)
	active.telegraph = 0.0
	active.active = 2.2
	active.tick = 0.5
	sim.rifts.append(warning)
	sim.rifts.append(active)


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
