extends RefCounted


func test_all_scripts_load(c: Check) -> void:
	var paths: Array[String] = []
	_collect("res://scripts", paths)
	c.ok(paths.size() > 10, "found scripts to check")
	for p in paths:
		var s := load(p) as GDScript
		c.ok(s != null and s.can_instantiate(), "loads and compiles: " + p)


func _collect(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
