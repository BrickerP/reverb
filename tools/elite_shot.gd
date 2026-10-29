extends SceneTree
# Windowed screenshot of the three echo-touched elite variants.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/elite_shot.gd

var _main: Node
var _frame := 0
var _step := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_elite_shot_suspend.json")
	OS.set_environment("REVERB_SAVE", "user://elite_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://elite_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://elite_shot_settings.json")
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
				_save("elites")
				_main.audio.stop_all()
				quit()
				return true
	return false


func _setup() -> void:
	var sim: Sim = _main.sim
	sim.start_wave(10)
	sim._plan.clear()
	sim._plan_idx = 0
	sim.pending.clear()
	sim.enemies.clear()
	var placements := [
		[&"overclocked", Vector2(300.0, 300.0)],
		[&"bulwark", Vector2(640.0, 300.0)],
		[&"volatile", Vector2(980.0, 300.0)],
	]
	for entry in placements:
		var ps := PendingSpawn.new()
		ps.def = Content.enemy(&"brute" if entry[0] == &"bulwark" else &"grunt")
		ps.pos = entry[1]
		ps.elite_kind = entry[0]
		sim._materialize(ps)
	for e in sim.enemies:
		e.speed = 0.0
		e.pos = e.pos.clamp(Sim.ARENA.position + Vector2(40.0, 40.0), Sim.ARENA.end - Vector2(40.0, 40.0))


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
