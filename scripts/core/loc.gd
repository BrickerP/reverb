class_name Loc
extends RefCounted


const WEAPON_DESCRIPTIONS := {
	&"pistol": "weapon.desc.pistol",
	&"smg": "weapon.desc.smg",
	&"stapler": "weapon.desc.stapler",
	&"shotgun": "weapon.desc.shotgun",
	&"flechette": "weapon.desc.flechette",
	&"paper_saw": "weapon.desc.paper_saw",
	&"rifle": "weapon.desc.rifle",
	&"longbow": "weapon.desc.longbow",
	&"hole_punch": "weapon.desc.hole_punch",
	&"orb": "weapon.desc.orb",
	&"hex_bolt": "weapon.desc.hex_bolt",
	&"ink_bottle": "weapon.desc.ink_bottle",
	&"stamp": "weapon.desc.stamp",
	&"mallet": "weapon.desc.mallet",
	&"cutter": "weapon.desc.cutter",
	&"tape_spool": "weapon.desc.tape_spool",
	&"rubber_band": "weapon.desc.rubber_band",
	&"paper_plane": "weapon.desc.paper_plane",
	&"twin_fangs": "weapon.desc.twin_fangs",
	&"flak_crown": "weapon.desc.flak_crown",
	&"rail_spike": "weapon.desc.rail_spike",
	&"nova_core": "weapon.desc.nova_core",
	&"hydraulic_press": "weapon.desc.hydraulic_press",
	&"redaction_engine": "weapon.desc.redaction_engine",
}

const SKILL_NAMES := {
	&"pin": "echo.skill.pin",
	&"stamp": "echo.skill.stamp",
	&"cut": "echo.skill.cut",
	&"ink": "echo.skill.ink",
	&"return": "echo.skill.return",
	&"arc": "echo.skill.arc",
}

const SKILL_DESCRIPTIONS := {
	&"pin": "echo.skill.pin.desc",
	&"stamp": "echo.skill.stamp.desc",
	&"cut": "echo.skill.cut.desc",
	&"ink": "echo.skill.ink.desc",
	&"return": "echo.skill.return.desc",
	&"arc": "echo.skill.arc.desc",
}

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


static func enemy_name(id: StringName) -> String:
	return t("enemy." + String(id))


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
		&"conductor":
			return t("select.conductor_name")
		&"mender":
			return t("select.mender_name")
		&"overloader":
			return t("select.overloader_name")
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
		&"conductor":
			return t("select.conductor_desc")
		&"mender":
			return t("select.mender_desc")
		&"overloader":
			return t("select.overloader_desc")
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
	if id == Stats.ECHO_DURATION:
		return t("stat.seconds", [text])
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


static func weapon_desc(id: StringName) -> String:
	return t(WEAPON_DESCRIPTIONS.get(id, ""))


static func echo_profile(profile: Dictionary, detailed: bool = false) -> String:
	if not bool(profile.get("valid", false)):
		return t("echo.wheel_empty")
	var kind := StringName(profile.get("kind", &"pin"))
	var title := t(SKILL_NAMES.get(kind, "echo.skill.pin"))
	var text := t("echo.profile", [title, int(round(float(profile.get("damage", 0.0))))])
	if detailed:
		text += "\n" + t(SKILL_DESCRIPTIONS.get(kind, "echo.skill.pin.desc"))
	return text


static func combo_name(id: StringName) -> String:
	return t("combo.pin_press") if id == &"pin_press" else t("combo.ink_arc")


static func combo_line(profile: Dictionary) -> String:
	var text := combo_name(profile["id"]) + ": "
	if profile["ready"]:
		return text + t("combo.ready")
	match StringName(profile["need"]):
		&"pin": return text + t("combo.need.pin")
		&"press": return text + t("combo.need.press")
		&"ink": return text + t("combo.need.ink")
		&"arc": return text + t("combo.need.arc")
	return text + t("combo.ready")
