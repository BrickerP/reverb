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
	var got := [-1, &"", &""]
	ui.replay_requested.connect(func(seed_value: int, char: StringName, daily: StringName) -> void:
		got[0] = seed_value
		got[1] = char
		got[2] = daily)
	ui.replay_buttons[0].pressed.emit()
	c.eq(got[0], 1, "replay carries the seed")
	c.eq(got[1], &"looper", "replay carries the character")
	c.eq(got[2], &"", "normal replay has no daily modifier")
	ui.close()
	c.ok(not ui.visible, "history closes")
	ui.free()
	_cleanup()


func test_history_shows_mode_labels(c: Check) -> void:
	_cleanup()
	var log := RunLog.new(PATH)
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.LOST
	s.endless = true
	s.boss_rush = true
	s.wave = 30
	var saved := log.append(s, &"looper", 1.0)
	c.ok(not saved.is_empty(), "mode fixture is saved")
	var ui := HistoryUi.new()
	ui.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	ui.open(log)
	c.eq(ui.row_count(), 1, "history keeps the recorded run")
	c.eq(ui.record_panels.size(), 1, "one readable record carries the mode and replay action")
	c.ok(ui._grid.find_children("*", "Label", true, false).any(
			func(node: Node) -> bool: return (node as Label).text == Loc.t("history.mode_boss_rush")),
			"boss rush appears in history")
	c.eq(ui.replay_buttons[0].text, Loc.t("history.replay_seed"),
			"endgame replay is labeled as a seed replay")
	c.ok(ui.replay_buttons[0].tooltip_text.contains("Boss Rush"),
			"endgame replay explains that state is not restored")
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
