extends SceneTree
# Runs from a tiny external audit project, mounts one exported PCK, then verifies
# logical runtime resources, provenance files, and forbidden development paths.
# Usage: godot --headless --path <empty-audit-project> --script res://audit.gd -- \
#   <pack.pck> <expected.json> <result.json>

var _failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("export_package_audit expects: pack.pck expected.json result.json")
		quit(2)
		return
	var pack_path := String(args[0])
	var expected_path := String(args[1])
	var result_path := String(args[2])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not (parsed is Dictionary):
		printerr("invalid expected-resource JSON")
		quit(2)
		return
	var expected: Dictionary = parsed
	if not ProjectSettings.load_resource_pack(pack_path, true):
		printerr("could not mount exported resource pack: %s" % pack_path)
		quit(2)
		return

	var checked_resources: Array[String] = []
	for value: Variant in expected.get("resources", []):
		var path := String(value)
		checked_resources.append(path)
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			_failures.append("missing or unloadable resource: %s" % path)
	var checked_files: Array[String] = []
	for value: Variant in expected.get("files", []):
		var path := String(value)
		checked_files.append(path)
		if not FileAccess.file_exists(path):
			_failures.append("missing packaged file: %s" % path)

	var inventory: Array[String] = []
	_walk("res://", inventory)
	var forbidden_hits: Array[String] = []
	for path in inventory:
		var relative := path.trim_prefix("res://")
		for value: Variant in expected.get("forbidden_prefixes", []):
			var prefix := String(value)
			if relative == prefix or relative.begins_with(prefix):
				forbidden_hits.append(relative)
				_failures.append("forbidden packaged path: %s" % relative)
				break

	var result := {
		"pack": pack_path,
		"ok": _failures.is_empty(),
		"checked_resource_count": checked_resources.size(),
		"checked_file_count": checked_files.size(),
		"inventory_count": inventory.size(),
		"forbidden_hits": forbidden_hits,
		"failures": _failures,
	}
	var output := FileAccess.open(result_path, FileAccess.WRITE)
	if output == null:
		printerr("could not write audit result: %s" % result_path)
		quit(2)
		return
	output.store_string(JSON.stringify(result, "  ") + "\n")
	output.close()
	print("export pack audit: %s (%d resources, %d provenance files, %d inventory entries)" % [
			"OK" if _failures.is_empty() else "FAILED", checked_resources.size(),
			checked_files.size(), inventory.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _walk(directory: String, output: Array[String]) -> void:
	for file in DirAccess.get_files_at(directory):
		output.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		if child == "." or child == "..":
			continue
		_walk(directory.path_join(child), output)
