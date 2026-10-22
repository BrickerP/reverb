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


static func weapon_name(id: StringName) -> String:
	return t("weapon." + String(id))


static func item_name(id: StringName) -> String:
	return t("item." + String(id))


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
