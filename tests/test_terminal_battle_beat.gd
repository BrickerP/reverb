extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_loss_records_immediately_and_summary_waits_only_for_art(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.meta = Meta.new("user://test_battle_terminal_meta.json")
	main.run_log = RunLog.new("user://test_battle_terminal_runs.jsonl")
	main.choose_character(&"looper", 71)
	var sim: Sim = main.sim
	sim.player.hp = 0.0
	sim.step(0.001, Vector2.ZERO)
	main._sync_phase()
	c.eq(sim.phase, Sim.Phase.LOST, "gameplay loss remains immediate")
	c.ok(main._recorded and not main._latest_saved_run.is_empty(), "run is saved before the visual beat")
	c.ok(not main.end_ui.visible and main._end_delay > 0.0,
			"summary does not cover the newly drawn paper death")
	var hp := sim.player.hp
	main._physics_process(main.PLAYER_DEATH_BEAT + 0.01)
	c.eq(sim.player.hp, hp, "no gameplay damage is added during the terminal visual beat")
	c.ok(main.end_ui.visible, "summary becomes usable after the short art beat")
	main.free()
	_cleanup()


func test_restart_cancels_pending_loss_summary(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.meta = Meta.new("user://test_battle_terminal_meta.json")
	main.run_log = RunLog.new("user://test_battle_terminal_runs.jsonl")
	main.choose_character(&"looper", 72)
	main.sim.player.hp = 0.0
	main.sim.step(0.001, Vector2.ZERO)
	main._sync_phase()
	main.new_run(73)
	main._physics_process(0.5)
	c.ok(not main.end_ui.visible, "a delayed result cannot pop over the new run")
	c.eq(main._end_delay, 0.0, "new session has no previous terminal timer")
	main.free()
	_cleanup()


func _cleanup() -> void:
	for name in ["test_battle_terminal_meta.json", "test_battle_terminal_runs.jsonl"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
