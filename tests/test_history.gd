extends RefCounted

const PATH := "user://test_history_runs.jsonl"


func _cleanup() -> void:
	var abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)


func test_history_lists_recent_runs(c: Check) -> void:
	_cleanup()
	var log := RunLog.new(PATH)
	var a := Sim.new(1)
	a.start_run()
	a.phase = Sim.Phase.LOST
	a.wave = 4
	a.kills = 40
	log.append(a, &"looper", 60.0)
	var b := Sim.new(2)
	b.start_run()
	b.phase = Sim.Phase.WON
	b.wave = 20
	b.kills = 2000
	log.append(b, &"mirror", 900.0)
	var ui := HistoryUi.new()
	ui.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.open(log)
	c.ok(ui.visible, "history opens")
	c.eq(ui.row_count(), 2, "two rows")
	ui.close()
	c.ok(not ui.visible, "history closes")
	ui.free()
	_cleanup()


func test_history_empty_state(c: Check) -> void:
	_cleanup()
	var ui := HistoryUi.new()
	ui.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.open(RunLog.new(PATH))
	c.eq(ui.row_count(), 0, "no rows")
	c.ok(ui.visible, "empty history still opens")
	ui.free()
	_cleanup()
