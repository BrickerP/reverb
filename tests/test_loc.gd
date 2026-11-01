extends RefCounted


func _paths() -> Array[String]:
	var out: Array[String] = []
	_collect("res://scripts", out)
	return out


func _collect(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)


func _specs(text: String) -> Array[String]:
	var re := RegEx.create_from_string("%(\\.\\d+)?[sdf]")
	var out: Array[String] = []
	for m in re.search_all(text):
		out.append(m.get_string())
	return out


func _is_content_key(key: String) -> bool:
	var parts := key.split(".", true, 1)
	var id := StringName(parts[1])
	match parts[0]:
		"school", "carrier", "role", "cost", "target":
			var property := "target_mode" if parts[0] == "target" else parts[0]
			for weapon: WeaponDef in Content.weapons().values():
				if String(weapon.get(property)) == String(id):
					return true
			return false
		"ability":
			for character: StringName in Content.characters():
				if parts[1] in [String(character) + ".name", String(character) + ".desc"]:
					return true
			return false
		"order":
			if parts[1] in ["survive.objective", "survive.short"]:
				return true
			for kind: StringName in AnomalyContract.KINDS:
				if parts[1] in [String(kind) + ".name", String(kind) + ".desc", String(kind) + ".objective", String(kind) + ".short"]:
					return true
			return false
		"interaction":
			for kind: String in ["press", "conveyor", "recycler", "part", "terminal", "repair", "rescue", "negotiate"]:
				if parts[1] in [kind, kind + ".desc"]:
					return true
			for kind: StringName in BureauEvents.TARGETS.values():
				if parts[1] in [String(kind), String(kind) + ".desc"]:
					return true
			if parts[1] in [String(BureauConfession.TERMINAL_KIND), String(BureauConfession.TERMINAL_KIND) + ".desc"]:
				return true
			return false
		"confession":
			for choice: StringName in BureauConfession.CHOICES:
				if parts[1] in [String(choice), String(choice) + ".desc"]:
					return true
			return false
		"bureau":
			return parts[1] in ["delivery.waiting", "delivery.carrying", "delivery.delivered", "delivery.missed"]
		"expedition":
			for value: String in ["compliance", "solidarity", "profit"]:
				if parts[1] == "route." + value:
					return true
			for value: StringName in Expedition.EXIT_IDS:
				if parts[1] in ["ending." + value, "outcome." + value]:
					return true
			return false
		"exit":
			for value: StringName in Expedition.EXIT_IDS:
				if parts[1] in [String(value), String(value) + ".desc"]:
					return true
			return false
		"negotiation":
			for value: String in ["sign", "stop_press", "settle_debt", "witness_mediation", "preserve_copy", "retire_copy", "self_witness", "decline"]:
				if parts[1] in [value, value + ".desc"]:
					return true
			return false
		"crew":
			for boss: StringName in Expedition.BOSS_IDS:
				if parts[1] in [String(boss), String(boss) + ".desc"]:
					return true
			for state: String in ["unsigned", "active", "bench", "fallen", "exited"]:
				if parts[1] in ["state." + state, "reason." + state]:
					return true
			return parts[1] in ["action.deploy", "action.aid"]
		"world":
			for act in range(1, 4):
				if parts[1] in ["act.%d" % act, "production.%d" % act]:
					return true
			return parts[1] in ["machine.operating", "machine.fault", "machine.repaired"]
		"work":
			for kind: String in ["press", "conveyor", "signature"]:
				if parts[1] == "kind." + kind:
					return true
			for reason: String in ["performed", "condition", "muted", "sealed", "unavailable", "weapon_missing", "no_target", "repaired", "stopped", "distant"]:
				if parts[1] == "reason." + reason:
					return true
			return false
		"archive":
			return parts[1] in ["work.press", "work.conveyor", "work.signature"]
		"reason":
			return parts[1] in ["debt_clear", "order_unavailable"]
		"workshop":
			if parts[1] in ["reason_debt", "reason_duplicate", "reason_trait", "reason_level"]:
				return true
			for value: String in ["skill", "repair", "power"]:
				if parts[1] in ["trait_" + value, "trait_" + value + "_desc"]:
					return true
			return false
		"shop":
			if parts[1].begins_with("family_mastery_"):
				for weapon: WeaponDef in Content.weapons().values():
					if parts[1] == "family_mastery_" + String(weapon.family):
						return true
			return false
		"weapon":
			if parts[1].begins_with("desc."):
				return Content.weapons().has(StringName(parts[1].trim_prefix("desc.")))
			if parts[1].begins_with("family."):
				var family := StringName(parts[1].trim_prefix("family."))
				for w: WeaponDef in Content.weapons().values():
					if w.family == family:
						return true
				return false
			return Content.weapons().has(id)
		"rarity":
			return id in [&"common", &"uncommon", &"rare", &"evolved"]
		"enemy":
			for e: EnemyDef in Content.enemies():
				if e.id == id:
					return true
			return false
		"item":
			return Content.items().has(id)
		"wave":
			if WaveDirector.phase_profile(0.0, 0.0)["name_key"] == key:
				return true
			for sample: float in [0.0, 25.0, 40.0, 65.0, 75.0, 95.0, 100.0]:
				if WaveDirector.phase_profile(sample, 100.0)["name_key"] == key:
					return true
			return false
		"story":
			for clue in StoryLedger.ALL:
				if parts[1] in [String(clue) + "_name", String(clue) + "_body"]:
					return true
			return false
		"set":
			return parts[1].ends_with("_bonus") and Content.item_sets().has(StringName(parts[1].trim_suffix("_bonus")))
		"stat":
			return id == &"seconds" or Stats.ORDER.has(id)
	return false


func test_tables_have_identical_keys(c: Check) -> void:
	c.ok(LocEn.TABLE.size() > 30, "english table is populated")
	for key: String in LocEn.TABLE:
		c.ok(LocZh.TABLE.has(key), "zh has " + key)
	for key: String in LocZh.TABLE:
		c.ok(LocEn.TABLE.has(key), "en has " + key)


func test_tables_use_the_same_format_arguments(c: Check) -> void:
	for key: String in LocEn.TABLE:
		c.eq(_specs(LocZh.TABLE.get(key, "")), _specs(LocEn.TABLE[key]), "format arguments match for " + key)


func test_every_content_id_has_a_name(c: Check) -> void:
	var keys: Array[String] = []
	for id: StringName in Content.weapons():
		keys.append("weapon." + String(id))
		keys.append("weapon.family." + String(Content.weapon(id).family))
	for id: StringName in Content.items():
		keys.append("item." + String(id))
	for id in Stats.ORDER:
		keys.append("stat." + String(id))
	for rarity in ["common", "uncommon", "rare", "evolved"]:
		keys.append("rarity." + rarity)
	for e: EnemyDef in Content.enemies():
		keys.append("enemy." + String(e.id))
	for key in keys:
		c.ok(LocEn.TABLE.has(key) and LocZh.TABLE.has(key), "named in both languages: " + key)


func test_keys_used_in_code_are_defined_and_defined_keys_are_used(c: Check) -> void:
	var literal := RegEx.create_from_string("\\bt\\(\\s*\"([a-z_.]+)\"\\s*[,)]")
	var all_source := ""
	var found := 0
	for p in _paths():
		if p.contains("/loc_"):
			continue
		var src := FileAccess.get_file_as_string(p)
		all_source += src
		for m in literal.search_all(src):
			found += 1
			var key := m.get_string(1)
			c.ok(LocEn.TABLE.has(key) and LocZh.TABLE.has(key), "%s uses undefined key %s" % [p.get_file(), key])
	c.ok(found > 20, "scanned the literal keys")
	for key: String in LocEn.TABLE:
		c.ok(_is_content_key(key) or all_source.contains("\"%s\"" % key), "key is used: " + key)


func test_ui_font_can_draw_every_zh_character(c: Check) -> void:
	var font := UiTheme.font()
	c.ok(font is FontFile, "bundled CJK font is used")
	var missing := PackedStringArray()
	for text: String in LocZh.TABLE.values():
		for ch in text:
			var code := ch.unicode_at(0)
			if code > 127 and not font.has_char(code) and not missing.has(ch):
				missing.append(ch)
	c.eq(" ".join(missing), "", "zh characters the bundled font lacks")


func test_lookup_falls_back_to_english_then_the_key(c: Check) -> void:
	var prev := Loc.lang
	Loc.lang = "zh"
	c.eq(Loc.t("hud.act", [1, 3]), "第1幕 · 第3场", "zh lookup with arguments")
	c.eq(Loc.t("no.such.key"), "no.such.key", "unknown keys come back as the key")
	Loc.lang = "en"
	c.eq(Loc.t("hud.act", [1, 3]), "ACT 1 · Encounter 3", "en lookup with arguments")
	Loc.lang = prev


func test_formatters(c: Check) -> void:
	var prev := Loc.lang
	Loc.lang = "en"
	c.eq(Loc.stat_value(Stats.DAMAGE_PCT, 0.1), "+10%", "percent stat")
	c.eq(Loc.stat_value(Stats.MAX_HP, 8.0), "+8", "flat stat")
	c.eq(Loc.stat_value(Stats.HP_REGEN, 0.5), "+0.5", "fractional stat")
	c.eq(Loc.stat_value(Stats.CRIT_CHANCE, 0.05, false), "5%", "unsigned percent")
	c.eq(Loc.stat_value(Stats.MOVE_SPEED, -10.0), "-10", "negative stat")
	c.eq(Loc.item_desc(Content.item(&"sharp_edge")), "all-weapon damage +10%", "item description")
	var sim := Sim.new(11)
	sim.start_run()
	var edged := Loc.item_desc(Content.item(&"sharp_edge"), sim)
	c.ok(edged.contains("100%") and edged.contains("110%"), "damage item states the resulting multiplier")
	var shoes := Loc.item_desc(Content.item(&"sneakers"), sim)
	c.ok(shoes.contains("260") and shoes.contains("288"), "sneakers state the resulting move speed")
	c.ok(not Loc.weapon_desc(&"shotgun").is_empty(), "actual cone behavior is described")
	c.ok(Loc.weapon_line(Content.weapon(&"rifle")).contains("Pierce 2"), "pierce count is shown")
	c.ok(Loc.weapon_desc(&"orb").contains("orbits"), "orbit behavior is worded")
	Loc.lang = prev
