extends SceneTree

func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://leak_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://leak_probe_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://leak_probe_settings.json")
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.new_run(5)
	main.sim.phase = Sim.Phase.LOST
	main.sim.wave = 4
	main._record_run()
	main.free()
	quit()
