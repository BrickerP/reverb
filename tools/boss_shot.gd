extends SceneTree
# Windowed screenshots of the final boss and its echo-silence pulse.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/boss_shot.gd

var _main: Node
var _frame := 0
var _step := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://boss_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://boss_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://boss_shot_settings.json")
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
			if _main.sim.boss != null and _frame >= 12:
				_save("boss")
				_main.sim._boss_silence_cd = 0.001
				_frame = 0
				_step = 2
		2:
			if _frame >= 10:
				_save("boss_silenced")
				if _main.sim.boss != null:
					_main.sim.damage_enemy(_main.sim.boss, 1000000.0, Vector2.ZERO, false, -1)
				_frame = 0
				_step = 3
		3:
			if _main.sim.phase == Sim.Phase.WON and _frame >= 18:
				_save("victory")
				_main.audio.stop_all()
				_frame = 0
				_step = 4
		4:
			if _frame >= 8:
				quit()
				return true
	return false


func _setup() -> void:
	var sim: Sim = _main.sim
	var take := EchoTake.new()
	take.wave = 1
	take.weapons = sim.player.weapons.duplicate()
	take.stats = sim.player.stats.copy()
	var path := PackedVector2Array()
	for i in 160:
		path.append(Sim.ARENA.get_center() + Vector2.from_angle(float(i) * 0.05) * (110.0 + 40.0 * sin(float(i) * 0.1)))
	take.samples = path
	sim.bank.add(take)
	sim.start_wave(WaveDirector.FINAL_WAVE)


func _save(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("wrote shots/%s.png" % name)
