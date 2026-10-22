extends RefCounted

const PATH := "user://test_settings_unit.json"


func _cleanup() -> void:
	var abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)


func test_defaults_and_persistence(c: Check) -> void:
	_cleanup()
	var s := Settings.new(PATH)
	c.near(s.volume, 0.8, 0.001, "default volume")
	c.ok(s.shake, "shake on by default")
	c.ok(not s.fullscreen, "windowed by default")
	c.eq(s.language, "", "auto language")
	s.volume = 0.35
	s.shake = false
	s.fullscreen = true
	s.language = "zh"
	s.save()
	var loaded := Settings.new(PATH)
	c.near(loaded.volume, 0.35, 0.001, "volume persists")
	c.ok(not loaded.shake, "shake persists")
	c.ok(loaded.fullscreen, "fullscreen persists")
	c.eq(loaded.language, "zh", "language persists")
	_cleanup()


func test_bad_file_falls_back(c: Check) -> void:
	_cleanup()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("not json")
	f = null
	var s := Settings.new(PATH)
	c.near(s.volume, 0.8, 0.001, "default volume after a broken file")
	_cleanup()


func test_ui_reports_changes(c: Check) -> void:
	var ui := SettingsUi.new()
	ui.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(ui)
	var s := Settings.new(PATH)
	ui.open(s)
	var volumes: Array[float] = []
	var langs: Array[String] = []
	ui.volume_changed.connect(func(v: float) -> void: volumes.append(v))
	ui.language_changed.connect(func(code: String) -> void: langs.append(code))
	ui.volume_slider.value = 0.5
	ui.language_option.item_selected.emit(2)
	c.near(volumes[0], 0.5, 0.001, "volume signal")
	c.eq(langs[0], "zh", "language signal")
	ui.close()
	c.ok(not ui.visible, "close hides")
	ui.free()
