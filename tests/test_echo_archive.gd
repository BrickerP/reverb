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
	c.ok(EchoArchive.store(meta, &"looper", take), "eligible chosen take persists atomically")
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


func test_archive_daily_solo_toggle_and_explicit_replacement_boundaries(c: Check) -> void:
	_clean()
	var meta := Meta.new(_path())
	c.ok(not EchoArchive.eligible(&"solo"), "solo is not an Echo archive character")
	c.ok(not EchoArchive.store(meta, &"solo", _take()), "solo cannot acquire inherited copy")
	c.ok(EchoArchive.store(meta, &"mirror", _take()), "mirror has its own archive")
	var weaker := _take()
	weaker.stats = Stats.new()
	c.ok(EchoArchive.store(meta, &"mirror", weaker), "explicit choice may replace a higher raw DPS recording")
	c.eq(EchoArchive.peek(meta, &"mirror").stats.values, weaker.stats.values, "the selected lower DPS original is persisted")
	var sim := Sim.new(18)
	Content.character(&"mirror").apply(sim)
	sim.daily_modifier = DailyAnomaly.FORTUNE
	c.ok(EchoArchive.load(meta, &"mirror", sim) == null, "daily cannot inherit campaign power")
	sim.daily_modifier = &""
	c.ok(EchoArchive.set_enabled(meta, false), "inheritance toggle persists")
	c.ok(not Meta.new(_path()).inherit_echo, "toggle survives reload")
	c.ok(EchoArchive.load(meta, &"mirror", sim) == null, "disabled archive never seeds run")
	c.ok(EchoArchive.peek(meta, &"mirror") != null, "disabling retains chosen archive")
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


func test_archive_utility_entry_uses_one_budget_and_matches_real_support(c: Check) -> void:
	_clean()
	var take := _take()
	take.weapons = [Content.weapon(&"repair_kit"), Content.weapon(&"paper_seed"), Content.weapon(&"guard_decoy")]
	take.levels = [3, 3, 3]
	var before := take.copy()
	var meta := Meta.new(_path())
	c.near(take.power(), 0.0, 0.001, "utility is not assigned fictional DPS")
	c.ok(EchoArchive.store(meta, &"looper", take), "zero DPS repair and defense recording is a valid explicit choice")
	var sim := Sim.new(321)
	Content.character(&"looper").apply(sim)
	var rng_before := sim.rng.state
	var archive_before := meta.echo_archives.duplicate(true)
	var preview := EchoArchive.entry_preview(meta, &"looper", sim)
	var entry := EchoArchive.load(meta, &"looper", sim)
	c.ok(entry != null and not preview.is_empty(), "utility has both entry and preview")
	if entry == null or preview.is_empty():
		_clean()
		return
	c.eq(entry.levels, [0, 0, 0], "all utility grades reset to opening grade")
	c.eq(preview.take.levels, entry.levels, "preview uses the load normalization")
	c.eq(preview.take.stats.values, entry.stats.values, "preview stats exactly match loaded stats")
	c.eq(take.levels, before.levels, "normalization never edits the original grades")
	c.eq(meta.echo_archives, archive_before, "preview never edits permanent archive")
	c.eq(sim.rng.state, rng_before, "preview consumes no simulation randomness")
	c.eq(sim.support_units.size(), 0, "preview never spawns support")
	c.eq(preview.utility.size(), 3, "every real utility has a profile")
	sim.bank.add(entry)
	var actor := EchoActor.new(entry, 0)
	sim.echoes.append(actor)
	for i in entry.weapons.size():
		var weapon := entry.weapons[i]
		c.ok(SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 0.0, 0, entry.uid, entry.tint(), entry.level_at(i), entry.stats.cooldown_mult(), entry.stats.range_mult()), "normalized utility actually spawns")
		if sim.support_units.size() <= i:
			continue
		var actual: Dictionary = sim.support_units[i]
		var expected: Dictionary = preview.utility[i]
		for key in ["max_hp", "life", "interval", "charges", "level", "reach", "damage"]:
			c.eq(actual[key], expected[key], "preview equals actual support %s" % key)
	c.eq(EchoArchive.peek(Meta.new(_path()), &"looper").levels, take.levels, "recorded grade survives persistent reload")
	_clean()


func test_archive_optional_work_uses_current_closed_decoder(c: Check) -> void:
	var take := _take()
	take.work_actions = [{"time": 0.0, "kind": &"press", "target_id": &"machine_0", "pos": take.samples[0], "weapon_id": &"", "aim": Vector2.ZERO}]
	var entry := EchoArchive.encode(take)
	c.ok(not entry.is_empty(), "key work persists with recording")
	var decoded := EchoArchive.decode(entry)
	c.eq(decoded.work_actions, take.work_actions, "key work round trips exact runtime values")
	var old := entry.duplicate(true)
	old.erase("work_actions")
	c.ok(EchoArchive.decode(old) != null, "version 1 record with no optional key work is accepted")
	c.eq(EchoArchive.decode(old).work_actions, [], "absent optional key work is an empty current action list")
	var invalid := entry.duplicate(true)
	invalid.extra = true
	c.ok(EchoArchive.decode(invalid) == null, "unknown archive fields are rejected even with optional work")
	invalid = entry.duplicate(true)
	invalid.work_actions[0].cash = 8
	c.ok(EchoArchive.decode(invalid) == null, "unknown work action field rejected")
	invalid = entry.duplicate(true)
	invalid.work_actions[0].time = 99.0
	c.ok(EchoArchive.decode(invalid) == null, "work outside recorded duration rejected")
	invalid = entry.duplicate(true)
	invalid.work_actions[0].kind = "recycler"
	c.ok(EchoArchive.decode(invalid) == null, "cash-spending work never enters archive")
	var sim := Sim.new(3)
	var normalized := EchoArchive.normalize(take, sim)
	c.eq(normalized.work_actions, take.work_actions, "entry retains all valid key work")
	normalized.work_actions[0].time = 0.01
	c.eq(take.work_actions[0].time, 0.0, "normalized work lists do not alias source")


func test_archive_opening_preview_matches_conductor_and_mirror_runtime(c: Check) -> void:
	_clean()
	var take := _take()
	take.weapons = [Content.weapon(&"paper_hound"), Content.weapon(&"repair_kit"), Content.weapon(&"paper_seed"), Content.weapon(&"guard_decoy")]
	take.levels = [3, 3, 3, 3]
	for id: StringName in [&"conductor", &"mirror"]:
		var meta := Meta.new(_path())
		c.ok(EchoArchive.store(meta, id, take), "character-specific archive stored")
		var sim := Sim.new(334)
		Content.character(id).apply(sim)
		sim.player.stats.values[Stats.CRIT_CHANCE] = 0.0
		var before := RunSnapshot.capture(sim)
		var prediction := EchoArchive.entry_preview(meta, id, sim)
		c.eq(RunSnapshot.capture(sim), before, "entry preview leaves complete source simulation untouched")
		var entry := EchoArchive.load(meta, id, sim)
		sim.bank.add(entry)
		sim.start_run()
		c.eq(sim.echoes.size(), 1, "opening battle really has one inherited actor")
		c.near(prediction.damage, sim.echo_dps(entry), 0.00001, "entry DPS includes actual own-copy character bonuses")
		c.eq(prediction.skill, EchoSystem.skill_profile(prediction.take, sim), "retirement prediction uses actual opening character bonuses")
		if id == &"mirror":
			c.eq(prediction.weapons, sim.player.weapons, "Mirror preview shows live starter rather than stored utility")
			c.eq(prediction.utility.size(), 0, "Mirror does not promise utility absent from its live gear")
			continue
		for i in entry.weapons.size():
			var weapon := entry.weapons[i]
			var mult := sim.synergy_damage_mult() * Combat.family_damage_mult(entry.weapons, weapon.family)
			c.ok(Combat.fire(sim, sim.player.pos, sim.player.pos + Vector2.RIGHT * 60.0, weapon, entry.level_at(i), mult,
				entry.stats, sim.echo_power(), 0, entry.tint(), 0, false, entry.uid), "previewed support actually fires")
			var actual: Dictionary = sim.support_units[i]
			for key in ["max_hp", "life", "damage", "interval", "level", "reach", "charges"]:
				c.eq(prediction.utility[i][key], actual[key], "Conductor family-aware support preview equals actual %s" % key)
	_clean()


func test_archive_replacement_io_failure_preserves_memory_and_disk(c: Check) -> void:
	_clean()
	var meta := Meta.new(_path())
	c.ok(EchoArchive.store(meta, &"looper", _take()), "original record saved")
	var original := meta.echo_archives.duplicate(true)
	var original_bytes := FileAccess.get_file_as_string(_path())
	var blocked := ProjectSettings.globalize_path(_path()) + ".blocked"
	DirAccess.make_dir_absolute(blocked)
	meta.path = blocked
	var replacement := _take()
	replacement.weapons = [Content.weapon(&"guard_decoy")]
	replacement.levels = [0]
	c.ok(not EchoArchive.store(meta, &"looper", replacement), "rename failure is reported")
	c.eq(meta.echo_archives, original, "failed replacement rolls back in-memory archive")
	c.eq(FileAccess.get_file_as_string(_path()), original_bytes, "failed replacement preserves previous file exactly")
	c.ok(not FileAccess.file_exists(blocked + ".tmp"), "failed save removes temporary output")
	meta.path = _path()
	c.ok(EchoArchive.store(meta, &"looper", replacement), "explicit utility replacement succeeds after I/O recovery")
	c.eq(EchoArchive.peek(Meta.new(_path()), &"looper").weapons[0].id, &"guard_decoy", "new lower damage selection persists after recovery")
	DirAccess.remove_absolute(blocked)
	_clean()
