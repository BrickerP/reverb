extends SceneTree

const SUITE_DIR := "res://tests/"


func _initialize() -> void:
	# Keep Meta writes out of the player's real save during tests.
	OS.set_environment("REVERB_SAVE", "user://test_save.json")
	var test_save := ProjectSettings.globalize_path("user://test_save.json")
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(test_save)
	# Nodes added to the root during _initialize do not get _ready until the first frame.
	await process_frame
	var check := Check.new()
	var files: Array[String] = []
	for f in DirAccess.get_files_at(SUITE_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	for f in files:
		if filter != "" and not f.contains(filter):
			continue
		var script := load(SUITE_DIR + f) as GDScript
		if script == null:
			check.begin(f)
			check.ok(false, "suite script failed to load")
			continue
		var suite: Object = script.new()
		for m in suite.get_method_list():
			var method_name: String = m["name"]
			if method_name.begins_with("test_"):
				check.begin("%s.%s" % [f.get_basename(), method_name])
				suite.call(method_name, check)
	print("Results: %d passed, %d failed" % [check.passed, check.failed])
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(test_save)
	quit(1 if check.failed > 0 else 0)
