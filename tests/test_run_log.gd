extends RefCounted

const PATH := "user://test_runs.jsonl"


func _cleanup() -> void:
	var abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)


func test_append_writes_one_json_line(c: Check) -> void:
	_cleanup()
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.LOST
	s.wave = 5
	s.kills = 42
	s.player.add_item(Content.item(&"iron_heart"))
	var log := RunLog.new(PATH)
	log.append(s, &"looper", 123.4)
	log.append(s, &"solo", 2.0)
	var file := FileAccess.open(PATH, FileAccess.READ)
	c.ok(file != null, "log file exists")
	var lines := 0
	var first := {}
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() == "":
			continue
		var data: Variant = JSON.parse_string(line)
		c.eq(typeof(data), TYPE_DICTIONARY, "each line is an object")
		if lines == 0:
			first = data
		lines += 1
	c.eq(lines, 2, "two runs")
	c.eq(int(first.get("seed", 0)), 7, "seed")
	c.eq(str(first.get("character", "")), "looper", "character")
	c.eq(str(first.get("version", "")), "0.1.33", "build version")
	c.eq(int(first.get("wave", 0)), 5, "wave")
	c.eq(bool(first.get("won", true)), false, "loss")
	c.eq(int(first.get("kills", 0)), 42, "kills")
	c.near(float(first.get("seconds", 0.0)), 123.4, 0.01, "duration")
	c.ok((first.get("items", {}) as Dictionary).has("iron_heart"), "items recorded")
	var recent := log.recent(1)
	c.eq(recent.size(), 1, "recent respects the limit")
	c.eq(int(recent[0].get("seed", 0)), 7, "recent keeps the last run")
	_cleanup()
