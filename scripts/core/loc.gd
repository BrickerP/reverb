class_name Loc
extends RefCounted

static var lang: String = _detect()


static func _detect() -> String:
	var forced := OS.get_environment("REVERB_LANG")
	var code := forced if forced != "" else OS.get_locale_language()
	return "zh" if code.begins_with("zh") else "en"


static func t(key: String, args: Array = []) -> String:
	var table: Dictionary = LocZh.TABLE if lang == "zh" else LocEn.TABLE
	var text: String = table.get(key, LocEn.TABLE.get(key, key))
	return text % args if not args.is_empty() else text


static func reset_lang() -> void:
	lang = _detect()


static func weapon_name(id: StringName) -> String:
	return t("weapon." + String(id))


static func weapon_family(id: StringName) -> String:
	return t("weapon.family." + String(id))


static func rarity_name(id: StringName) -> String:
	return t("rarity." + String(id))


static func item_name(id: StringName) -> String:
	return t("item." + String(id))


static func character_name(id: StringName) -> String:
	match id:
		&"looper":
			return t("select.looper_name")
		&"solo":
			return t("select.solo_name")
		&"mirror":
			return t("select.mirror_name")
		_:
			return String(id)


static func character_desc(id: StringName) -> String:
	match id:
		&"looper":
			return t("select.looper_desc")
		&"solo":
			return t("select.solo_desc")
		&"mirror":
			return t("select.mirror_desc")
		_:
			return ""


static func stat_name(id: StringName) -> String:
	return t("stat." + String(id))


static func number(x: float) -> String:
	return "%d" % int(round(x)) if is_equal_approx(x, round(x)) else "%.1f" % x


static func stat_value(id: StringName, amount: float, signed: bool = true) -> String:
	var shown := amount * 100.0 if Stats.PERCENT.has(id) else amount
	var text := number(shown)
	if signed and shown > 0.0:
		text = "+" + text
	return text + "%" if Stats.PERCENT.has(id) else text


static func item_desc(it: ItemDef) -> String:
	var parts := PackedStringArray()
	for stat: StringName in it.mods:
		parts.append("%s %s" % [stat_value(stat, float(it.mods[stat])), stat_name(stat)])
	return "  ".join(parts)


static func weapon_line(w: WeaponDef) -> String:
	var dmg := number(w.damage)
	if w.pellets > 1:
		dmg += "x%d" % w.pellets
	var line := t("weapon.line", [dmg, 1.0 / w.cooldown, int(w.reach)])
	if w.pierce >= 50:
		line += " · " + t("weapon.pierce_all")
	elif w.pierce > 0:
		line += " · " + t("weapon.pierce", [w.pierce])
	return line
