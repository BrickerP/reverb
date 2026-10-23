class_name UserData
extends RefCounted

# The app name is also the user:// directory name. Renaming Reverb -> Take Stack would otherwise
# orphan every tester's save, settings and run log, so copy the old files once when the new
# directory is still empty.
const LEGACY_DIR := "Reverb"
const FILES: Array[String] = ["reverb_save.json", "settings.json", "runs.jsonl"]


static func migrate_legacy() -> int:
	# Tests and tools point each file at an isolated path; never touch their real data.
	if OS.get_environment("REVERB_SAVE") != "" or OS.get_environment("REVERB_RUN_LOG") != "" \
			or OS.get_environment("REVERB_SETTINGS") != "":
		return 0
	var current := OS.get_user_data_dir()
	if current.get_file() == LEGACY_DIR:
		return 0
	return migrate(current.get_base_dir().path_join(LEGACY_DIR), current)


# Copies known files that are missing at the destination. Existing destination files win.
static func migrate(old_dir: String, new_dir: String) -> int:
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir):
		return 0
	DirAccess.make_dir_recursive_absolute(new_dir)
	var copied := 0
	for file_name in FILES:
		var from := old_dir.path_join(file_name)
		var to := new_dir.path_join(file_name)
		if FileAccess.file_exists(from) and not FileAccess.file_exists(to):
			if DirAccess.copy_absolute(from, to) == OK:
				copied += 1
	if copied > 0:
		print_verbose("migrated %d file(s) from %s to %s" % [copied, old_dir, new_dir])
	return copied
