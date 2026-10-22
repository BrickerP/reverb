extends SceneTree
# Windowed frame-time probe: drops a Crowd into the real Main scene and times whole frames
# (physics step, scripts, draw submission, GPU back-pressure).
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/frame_probe.gd
# With vsync off each frame is produced as fast as the machine manages, so 1000 / ms is headroom, not fps.

const COUNTS: Array[int] = [0, 100, 200, 300]
const WARMUP_FRAMES := 420
const MEASURED_FRAMES := 600

var _main: Node
var _cases: Array[Vector2i] = []
var _case := -1
var _frame := 0
var _last_us := 0
var _times := PackedInt32Array()
var _peak_enemies := 0
var _peak_projectiles := 0


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://frame_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://frame_probe_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://frame_probe_settings.json")
	if DisplayServer.get_name() == "headless":
		printerr("frame_probe needs a real window: drop --headless")
		quit(1)
		return
	for chase in 2:
		for n in COUNTS:
			if n > 0 or chase == 0:
				_cases.append(Vector2i(n, chase))
	print("frame probe on %s (%s), %d warm-up + %d measured frames per case" % [
			RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method(),
			WARMUP_FRAMES, MEASURED_FRAMES])
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main == null or _main.character_select == null:
		return false
	if _main.sim == null:
		if _main.character_select.visible:
			_main.choose_character(&"looper")
		return false
	var sim: Sim = _main.sim
	var now := Time.get_ticks_usec()
	if _case >= 0:
		_frame += 1
		if _frame > WARMUP_FRAMES:
			_times.append(now - _last_us)
			_peak_enemies = maxi(_peak_enemies, sim.enemies.size())
			_peak_projectiles = maxi(_peak_projectiles, sim.projectiles.size())
	if _case < 0 or _times.size() >= MEASURED_FRAMES:
		if _case >= 0:
			_report(_cases[_case])
		_case += 1
		if _case >= _cases.size():
			quit()
			return true
		_begin(_cases[_case])
	_last_us = Time.get_ticks_usec()
	return false


func _begin(c: Vector2i) -> void:
	_main.new_run(7)
	var sim: Sim = _main.sim
	Crowd.equip(sim)
	sim.start_wave(1)
	Crowd.fill(sim, c.x, c.y == 1)
	_frame = 0
	_times.clear()
	_peak_enemies = 0
	_peak_projectiles = 0


func _report(c: Vector2i) -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0
	for v in _times:
		total += v
	print("  %3d enemies %-9s frame avg %.2f  p99 %.2f  max %.2f ms | peak %d enemies, %d projectiles" % [
			c.x, "chasing" if c.y == 1 else "standing", float(total) / float(_times.size()) / 1000.0,
			float(sorted[int(0.99 * float(sorted.size()))]) / 1000.0, float(sorted[sorted.size() - 1]) / 1000.0,
			_peak_enemies, _peak_projectiles])
