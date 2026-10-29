extends RefCounted
const PATH := "user://test_story_ui_meta.json"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_receipt_is_optional_dismissible_and_keeps_discovery(c: Check) -> void:
	var sim := Sim.new(11)
	sim.start_run()
	sim.wave = 2
	StoryLedger.on_wave(sim)
	var receipt := StoryReceipt.new()
	receipt.theme = UiTheme.build()
	_root().add_child(receipt)
	receipt.display(sim)
	c.ok(receipt.visible, "discovered receipt appears")
	c.eq(receipt.title_label.text, Loc.t("story.carbon_name"), "receipt title localized")
	c.eq(receipt.body_label.text, Loc.t("story.carbon_body"), "receipt contains actual fragment")
	c.ok(not receipt.archive_button.has_focus(), "optional receipt does not steal focus")
	var archive: Array[bool] = []
	receipt.archive_requested.connect(func() -> void: archive.append(true))
	receipt.archive_button.pressed.emit()
	c.eq(archive.size(), 1, "archive action remains available")
	receipt.dismiss_button.pressed.emit()
	c.ok(not receipt.visible, "receipt dismisses without modal")
	c.ok(StoryLedger.discovered(sim).has(&"carbon"), "filing keeps discovery")
	receipt.free()


func test_archive_empty_exit_and_discovered_rows_are_focusable(c: Check) -> void:
	var absolute := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	var meta := Meta.new(PATH)
	var archive := StoryArchiveUi.new()
	archive.theme = UiTheme.build()
	_root().add_child(archive)
	archive.open(meta)
	c.eq(archive.row_count(), 0, "new profile has empty archive")
	c.ok(archive.close_button.has_focus(), "empty archive has controller exit")
	meta.discover_story([&"carbon", &"repair"])
	archive.open(meta)
	c.eq(archive.row_count(), 2, "real discoveries produce two readable sheets")
	c.ok(archive.archive_scroll.follow_focus, "keyboard browsing scrolls into view")
	var rows := archive._rows.get_children()
	c.eq(rows[0].focus_mode, Control.FOCUS_ALL, "clue is focusable")
	c.eq(archive.close_button.get_node(archive.close_button.focus_neighbor_bottom), rows[0], "controller loop reaches first clue")
	archive.close_button.pressed.emit()
	c.ok(not archive.visible, "archive closes")
	archive.free()
	DirAccess.remove_absolute(absolute)
