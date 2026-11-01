class_name Loc
extends RefCounted


const WEAPON_DESCRIPTIONS := {
	&"guard_decoy": "weapon.desc.guard_decoy",
	&"paper_seed": "weapon.desc.paper_seed",
	&"repair_kit": "weapon.desc.repair_kit",
	&"debt_sentry": "weapon.desc.debt_sentry",
	&"paper_hound": "weapon.desc.paper_hound",
	&"binding_atlas": "weapon.desc.binding_atlas",
	&"folding_guillotine": "weapon.desc.folding_guillotine",
	&"ink_tempest": "weapon.desc.ink_tempest",
	&"surveyor_lance": "weapon.desc.surveyor_lance",
	&"saw_swarm": "weapon.desc.saw_swarm",
	&"binding_writ": "weapon.desc.binding_writ",
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
	if not is_finite(x):
		return "0"
	if is_equal_approx(x, round(x)):
		return "%d" % int(round(x))
	# 0.65 must stay 0.65. One decimal rounds it to 0.7.
	var hundredths := int(round(absf(x) * 100.0))
	if hundredths % 10 == 0:
		return "%.1f" % x
	return "%.2f" % x


static func stat_value(id: StringName, amount: float, signed: bool = true) -> String:
	var shown := amount * 100.0 if Stats.PERCENT.has(id) else amount
	var text := number(shown)
	if signed and shown > 0.0:
		text = "+" + text
	if id == Stats.ECHO_DURATION:
		return t("stat.seconds", [text])
	return text + "%" if Stats.PERCENT.has(id) else text


static func cross_life(hp: float, max_hp: float, stapled: bool = false) -> String:
	var wave := WaveDirector.FINAL_WAVE
	var cross := EnemyBrain.paradox_cross_damage_at(wave)
	var enraged := cross * Sim.BOSS_ENRAGE_DAMAGE
	var tail := t("shop.cross_staple_rule") if stapled else t("shop.cross_enrage", [number(enraged)])
	return t("shop.life", [number(hp), number(max_hp), wave, number(cross), tail])


static func item_scope(stat: StringName) -> String:
	match stat:
		Stats.DAMAGE_PCT:
			return t("item.does.damage_pct")
		Stats.ATTACK_SPEED_PCT:
			return t("item.does.attack_speed_pct")
		Stats.RANGE_PCT:
			return t("item.does.range_pct")
		Stats.MOVE_SPEED:
			return t("item.does.move_speed")
		Stats.CRIT_CHANCE:
			return t("item.does.crit_chance")
		Stats.PICKUP_RANGE:
			return t("item.does.pickup_range")
		Stats.HP_REGEN:
			return t("item.does.hp_regen")
		Stats.MAX_HP:
			return t("item.does.max_hp")
		Stats.ECHO_SLOTS:
			return t("item.does.echo_slots")
		_:
			return stat_name(stat)


static func item_shift(stat: StringName, amount: float, sim: Sim) -> String:
	var before := 0.0
	var after := 0.0
	if stat == Stats.ECHO_SLOTS:
		before = float(sim.echo_capacity())
		after = before + amount
		return t("item.now_next", [number(before), number(after)])
	before = sim.player.stats.get_stat(stat)
	after = before + amount
	if stat == Stats.DAMAGE_PCT or stat == Stats.ATTACK_SPEED_PCT or stat == Stats.RANGE_PCT:
		return t("item.now_next", [number((1.0 + before) * 100.0) + "%", number((1.0 + after) * 100.0) + "%"])
	if Stats.PERCENT.has(stat):
		return t("item.now_next", [stat_value(stat, before, false), stat_value(stat, after, false)])
	return t("item.now_next", [number(before), number(after)])


static func item_desc(it: ItemDef, sim: Sim = null) -> String:
	if it != null and it.id == &"long_play":
		var before := Stats.DEFAULTS[Stats.ECHO_DURATION] if sim == null else sim.echo_duration()
		var after := before + float(it.mods.get(Stats.ECHO_DURATION, 0.0))
		return t("item.long_play_fact", [number(before), number(after)])
	if it != null and it.id == &"loud_speaker":
		var before := Stats.DEFAULTS[Stats.ECHO_POWER] if sim == null else sim.echo_power()
		var after := before + float(it.mods.get(Stats.ECHO_POWER, 0.0))
		return t("item.loud_speaker_fact", [int(round(before * 100.0)), int(round(after * 100.0))])
	var parts := PackedStringArray()
	for stat: StringName in it.mods:
		var amount := float(it.mods[stat])
		var line := "%s %s" % [item_scope(stat), stat_value(stat, amount)]
		if sim != null and stat != Stats.MAX_HP:
			line += " · " + item_shift(stat, amount, sim)
		parts.append(line)
	if it.mods.has(Stats.MAX_HP):
		parts.append(t("item.max_hp_now"))
		if sim != null:
			var added := float(it.mods[Stats.MAX_HP])
			var next_max := sim.player.max_hp() + added
			var next_hp := minf(next_max, sim.player.hp + added)
			parts.append(cross_life(next_hp, next_max, sim.has_evolved_weapon()))
	return "  ".join(parts)


static func weapon_line(w: WeaponDef, level: int = 0) -> String:
	if w.support_kind != &"":
		return support_line(w, level)
	var per_shot := number(w.damage * w.level_mult(level))
	var line := t("weapon.burst_line", [per_shot, w.pellets, w.cooldown, int(w.reach)]) if w.pellets > 1 \
			else t("weapon.line", [per_shot, w.cooldown, int(w.reach)])
	if w.pierce >= 50:
		line += " · " + t("weapon.pierce_all")
	elif w.pierce > 0:
		line += " · " + t("weapon.pierce", [w.pierce])
	return line


static func support_line(w: WeaponDef, level: int = 0) -> String:
	var profile := SupportSystem.weapon_profile(w, level, w.damage)
	if profile.is_empty():
		return weapon_desc(w.id)
	return _support_text(w, profile, false)


static func support_short(w: WeaponDef, level: int = 0) -> String:
	var profile := SupportSystem.weapon_profile(w, level, w.damage)
	if profile.is_empty():
		return weapon_desc(w.id)
	return _support_text(w, profile, true)


static func _support_text(w: WeaponDef, profile: Dictionary, short: bool) -> String:
	var interval := float(profile["interval"])
	var life := float(profile["life"])
	var reach := int(profile["reach"])
	match w.support_kind:
		&"repair_station":
			if short:
				return t("weapon.support_repair_short", [interval, int(profile["charges"]), life])
			return t("weapon.support_repair", [interval, int(profile["charges"]), life, reach])
		&"paper_tree":
			if short:
				return t("weapon.support_tree_short", [interval, int(profile["charges"]), life])
			return t("weapon.support_tree", [interval, int(profile["charges"]), life, reach])
		&"decoy":
			if short:
				return t("weapon.support_decoy_short", [float(profile["hp"]), life])
			return t("weapon.support_decoy", [float(profile["hp"]), life, reach])
		&"turret":
			var damage := float(profile["damage"])
			if short:
				return t("weapon.support_debt_short", [number(damage), number(damage * 1.25)])
			return t("weapon.support_debt", [number(damage), number(damage * 1.25), life, reach])
		_:
			return t("weapon.support_generic", [interval, life, reach])


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
