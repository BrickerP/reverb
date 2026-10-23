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
		"weapon":
			if parts[1].begins_with("family."):
				var family := StringName(parts[1].trim_prefix("family."))
				for w: WeaponDef in Content.weapons().values():
					if w.family == family:
						return true
				return false
			return Content.weapons().has(id)
		"rarity":
			return id in [&"common", &"uncommon", &"rare", &"evolved"]
		"item":
			return Content.items().has(id)
		"stat":
			return Stats.ORDER.has(id)
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
	c.eq(Loc.t("hud.wave", [3, 20]), "第 3 / 20 波", "zh lookup with arguments")
	c.eq(Loc.t("no.such.key"), "no.such.key", "unknown keys come back as the key")
	Loc.lang = "en"
	c.eq(Loc.t("hud.wave", [3, 20]), "Wave 3 / 20", "en lookup with arguments")
	Loc.lang = prev


func test_formatters(c: Check) -> void:
	var prev := Loc.lang
	Loc.lang = "en"
	c.eq(Loc.stat_value(Stats.DAMAGE_PCT, 0.1), "+10%", "percent stat")
	c.eq(Loc.stat_value(Stats.MAX_HP, 8.0), "+8", "flat stat")
	c.eq(Loc.stat_value(Stats.HP_REGEN, 0.5), "+0.5", "fractional stat")
	c.eq(Loc.stat_value(Stats.CRIT_CHANCE, 0.05, false), "5%", "unsigned percent")
	c.eq(Loc.stat_value(Stats.MOVE_SPEED, -10.0), "-10", "negative stat")
	c.eq(Loc.item_desc(Content.item(&"sharp_edge")), "+10% Damage", "item description")
	c.ok(Loc.weapon_line(Content.weapon(&"shotgun")).contains("3.5x5"), "pellets are shown")
	c.ok(Loc.weapon_line(Content.weapon(&"rifle")).contains("Pierce 2"), "pierce count is shown")
	c.ok(Loc.weapon_line(Content.weapon(&"orb")).contains("Pierces all"), "unlimited pierce is worded")
	Loc.lang = prev
