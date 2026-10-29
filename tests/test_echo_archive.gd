extends RefCounted


func _path() -> String:
	return OS.get_environment("REVERB_SAVE") + ".archive_test"


func _clean() -> void:
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(_path())


func _take() -> EchoTake:
	var take := EchoTake.new()
	take.samples = PackedVector2Array([Vector2(200, 300), Vector2(240, 340)])
	take.weapons = [Content.weapon(&"pistol"), Content.weapon(&"stamp")]
	take.levels = [3, 2]
	take.wave = 8
	take.condition = 90.0
	take.stats.add(Stats.DAMAGE_PCT, 2.0)
	take.inherited_skill = &"arc"
	return take


func test_archive_round_trip_normalizes_to_new_run_and_existing_capacity(c: Check) -> void:
	_clean()
	var meta := Meta.new(_path())
	var take := _take()
	c.ok(EchoArchive.store(meta, &"looper", take), "eligible best take persists atomically")
	var loaded_meta := Meta.new(_path())
	c.ok(EchoArchive.has(loaded_meta, &"looper"), "archive survives process boundary")
	var sim := Sim.new(81)
	Content.character(&"looper").apply(sim)
	var inherited := EchoArchive.load(loaded_meta, &"looper", sim)
	c.ok(inherited != null, "new campaign can inherit archive")
	if inherited != null:
		c.eq(inherited.uid, 0, "loading leaves identity assignment to live bank")
		c.eq(inherited.samples, take.samples, "saved route survives")
		c.eq(inherited.weapons, take.weapons, "canonical saved gear survives")
		c.eq(inherited.inherited_skill, &"arc", "retirement inheritance survives")
		c.near(inherited.power(), sim.player.weapons[0].dps() * 0.75, 0.001, "power fits opening stage budget")
		c.eq(inherited.condition, 60.0, "inherited condition is bounded")
		c.ok(inherited.archived, "inherited identity remains visible")
		c.eq(sim.bank.takes.size(), 0, "load preview never allocates free actors")
		sim.bank.add(inherited)
		c.eq(inherited.uid, 1, "normal bank assigns stable actor identity")
	while sim.bank.takes.size() < sim.echo_capacity():
		sim.bank.add(_take())
	c.ok(EchoArchive.load(loaded_meta, &"looper", sim) == null, "archive cannot bypass existing capacity")
	_clean()


func test_archive_daily_solo_toggle_and_weaker_record_boundaries(c: Check) -> void:
	_clean()
	var meta := Meta.new(_path())
	c.ok(not EchoArchive.eligible(&"solo"), "solo is not an Echo archive character")
	c.ok(not EchoArchive.store(meta, &"solo", _take()), "solo cannot acquire inherited copy")
	c.ok(EchoArchive.store(meta, &"mirror", _take()), "mirror has its own archive")
	var weaker := _take()
	weaker.stats = Stats.new()
	c.ok(not EchoArchive.store(meta, &"mirror", weaker), "weaker result cannot overwrite personal best")
	var sim := Sim.new(18)
	Content.character(&"mirror").apply(sim)
	sim.daily_modifier = DailyAnomaly.FORTUNE
	c.ok(EchoArchive.load(meta, &"mirror", sim) == null, "daily cannot inherit campaign power")
	sim.daily_modifier = &""
	c.ok(EchoArchive.set_enabled(meta, false), "inheritance toggle persists")
	c.ok(not Meta.new(_path()).inherit_echo, "toggle survives reload")
	c.ok(EchoArchive.load(meta, &"mirror", sim) == null, "disabled archive never seeds run")
	c.ok(EchoArchive.peek(meta, &"mirror") != null, "disabling retains archived best")
	_clean()


func test_archive_rejects_malformed_route_stats_and_noncanonical_gear(c: Check) -> void:
	var entry := EchoArchive.encode(_take())
	c.ok(not entry.is_empty(), "valid source serializes")
	var invalid := entry.duplicate(true)
	invalid.samples[0] = [INF, 300.0]
	c.ok(EchoArchive.decode(invalid) == null, "nonfinite route rejected")
	invalid = entry.duplicate(true)
	invalid.samples[0] = [0.0, 0.0]
	c.ok(EchoArchive.decode(invalid) == null, "outside-world route rejected")
	invalid = entry.duplicate(true)
	invalid.weapons[0] = "missing_weapon"
	c.ok(EchoArchive.decode(invalid) == null, "unknown gear rejected")
	invalid = entry.duplicate(true)
	invalid.stats["unexpected_stat"] = 1.0
	c.ok(EchoArchive.decode(invalid) == null, "unknown stat rejected")
	invalid = entry.duplicate(true)
	invalid.condition = 101.0
	c.ok(EchoArchive.decode(invalid) == null, "condition cannot mint extra lifetime")
	invalid = entry.duplicate(true)
	invalid.levels[0] = 99
	c.ok(EchoArchive.decode(invalid) == null, "level limits enforced")
	invalid = entry.duplicate(true)
	invalid.stats[Stats.MAX_HP] = -20.0
	c.ok(EchoArchive.decode(invalid) == null, "canonical physical stats cannot be negative")
	invalid = entry.duplicate(true)
	invalid.version = []
	c.ok(EchoArchive.decode(invalid) == null, "malformed version safely rejected")
	var fake := _take()
	fake.weapons[0] = Content.weapon(&"pistol").duplicate()
	c.ok(EchoArchive.encode(fake).is_empty(), "noncanonical resource rejected before persistence")


func test_archive_failed_write_rolls_back_archive_and_toggle(c: Check) -> void:
	var missing := _path() + ".missing/profile.json"
	var meta := Meta.new(missing)
	meta.best_wave = 7
	c.ok(not EchoArchive.store(meta, &"looper", _take()), "unwritable archive returns failure")
	c.ok(meta.echo_archives.is_empty(), "failed write leaves played profile archive unchanged")
	c.eq(meta.best_wave, 7, "failed archive never changes gameplay record")
	c.ok(not EchoArchive.set_enabled(meta, false), "unwritable toggle returns failure")
	c.ok(meta.inherit_echo, "failed toggle rolls back in-memory preference")
