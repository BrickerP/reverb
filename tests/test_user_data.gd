extends RefCounted

const OLD := "user://test_migrate_old"
const NEW := "user://test_migrate_new"


func _cleanup() -> void:
	for dir in [OLD, NEW]:
		var abs := ProjectSettings.globalize_path(dir)
		for file_name in UserData.FILES:
			var path := abs.path_join(file_name)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		if DirAccess.dir_exists_absolute(abs):
			DirAccess.remove_absolute(abs)


func _write(dir: String, file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _read(dir: String, file_name: String) -> String:
	var file := FileAccess.open(dir.path_join(file_name), FileAccess.READ)
	return file.get_as_text() if file != null else ""


func test_migrates_missing_files(c: Check) -> void:
	_cleanup()
	var old := ProjectSettings.globalize_path(OLD)
	var new := ProjectSettings.globalize_path(NEW)
	_write(old, "reverb_save.json", "save")
	_write(old, "runs.jsonl", "run")
	c.eq(UserData.migrate(old, new), 2, "copies two files")
	c.eq(_read(new, "reverb_save.json"), "save", "save copied")
	c.eq(_read(new, "runs.jsonl"), "run", "log copied")
	_cleanup()


func test_never_overwrites_existing(c: Check) -> void:
	_cleanup()
	var old := ProjectSettings.globalize_path(OLD)
	var new := ProjectSettings.globalize_path(NEW)
	_write(old, "settings.json", "old")
	_write(new, "settings.json", "new")
	c.eq(UserData.migrate(old, new), 0, "nothing copied")
	c.eq(_read(new, "settings.json"), "new", "destination wins")
	_cleanup()
