class_name EchoArchive
extends RefCounted

const VERSION := 1
const MAX_SAMPLES := 1801
const MAX_STAT_VALUE := 1000.0
const INHERITED_CONDITION := 60.0
const SKILLS: Array[StringName] = [&"", &"pin", &"stamp", &"cut", &"ink", &"return", &"arc"]
const RECORD_KEYS := ["version", "wave", "condition", "samples", "weapons", "levels", "stats", "inherited_skill", "merge_trait", "merged"]


static func eligible(character_id: StringName) -> bool:
	var character := Content.character(character_id)
	return character != null and float(character.overrides.get(Stats.ECHO_SLOTS, Stats.DEFAULTS[Stats.ECHO_SLOTS])) > 0.0


static func has(meta: Meta, character_id: StringName) -> bool:
	return peek(meta, character_id) != null


static func peek(meta: Meta, character_id: StringName) -> EchoTake:
	if meta == null or not eligible(character_id):
		return null
	return decode(meta.echo_archives.get(String(character_id), {}))


static func set_enabled(meta: Meta, enabled: bool) -> bool:
	if meta == null:
		return false
	var previous := meta.inherit_echo
	meta.inherit_echo = enabled
	if meta.save():
		return true
	meta.inherit_echo = previous
	return false


static func store(meta: Meta, character_id: StringName, take: EchoTake) -> bool:
	if meta == null or not eligible(character_id):
		return false
	var entry := encode(take)
	if entry.is_empty():
		return false
	var previous_take := peek(meta, character_id)
	if previous_take != null and (previous_take.power() > take.power() + 0.001 or
			(is_equal_approx(previous_take.power(), take.power()) and previous_take.condition >= take.condition)):
		return false
	var previous := meta.echo_archives.duplicate(true)
	meta.echo_archives[String(character_id)] = entry
	if meta.save():
		return true
	meta.echo_archives = previous
	return false


# The saved route/weapon identities survive, but old stat inflation cannot bypass
# the current expedition's opening power budget or buy another Echo slot.
static func load(meta: Meta, character_id: StringName, sim: Sim) -> EchoTake:
	if meta == null or sim == null or not meta.inherit_echo or sim.daily_modifier != &"" \
			or sim.echo_capacity() <= sim.bank.takes.size():
		return null
	var take := peek(meta, character_id)
	if take == null:
		return null
	var player_power := 0.0
	for i in sim.player.weapons.size():
		player_power += sim.player.weapons[i].level_dps(sim.player.level_at(i))
	player_power *= sim.player.stats.damage_mult() / sim.player.stats.cooldown_mult()
	var stage_multiplier := clampf(0.75 + 0.05 * float(maxi(1, sim.wave) - 1), 0.75, 1.2)
	var target_power := minf(take.power(), maxf(1.0, player_power) * stage_multiplier)
	var nominal := 0.0
	for i in take.weapons.size():
		nominal += take.weapons[i].level_dps(take.level_at(i))
	take.stats = sim.player.stats.copy()
	take.stats.values[Stats.DAMAGE_PCT] = target_power * take.stats.cooldown_mult() / maxf(0.001, nominal) - 1.0
	take.condition = minf(INHERITED_CONDITION, take.condition)
	take.archived = true
	return take


static func encode(take: EchoTake) -> Dictionary:
	if take == null or take.stats == null or take.samples.is_empty() or take.samples.size() > MAX_SAMPLES \
			or take.weapons.size() > Content.MAX_WEAPON_SLOTS:
		return {}
	var points: Array = []
	for point in take.samples:
		points.append([point.x, point.y])
	var weapon_ids: Array[String] = []
	var levels: Array[int] = []
	for i in take.weapons.size():
		if take.weapons[i] == null or Content.weapon(take.weapons[i].id) != take.weapons[i]:
			return {}
		weapon_ids.append(String(take.weapons[i].id))
		levels.append(take.level_at(i))
	var entry := {"version": VERSION, "wave": take.wave, "condition": take.condition,
		"samples": points, "weapons": weapon_ids, "levels": levels,
		"stats": take.stats.values.duplicate(), "inherited_skill": String(take.inherited_skill),
		"merge_trait": String(take.merge_trait), "merged": take.merged}
	return entry if decode(entry) != null else {}


static func decode(value: Variant) -> EchoTake:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var entry: Dictionary = value
	if entry.size() != RECORD_KEYS.size():
		return null
	for key: String in RECORD_KEYS:
		if not entry.has(key):
			return null
	if typeof(entry.inherited_skill) != TYPE_STRING or typeof(entry.merge_trait) != TYPE_STRING or typeof(entry.merged) != TYPE_BOOL:
		return null
	if not _number(entry.get("version")) or float(entry.version) != float(VERSION) or not _number(entry.get("condition")) \
			or float(entry.condition) <= 0.0 or float(entry.condition) > 100.0 \
			or not _number(entry.get("wave")) or float(entry.wave) < 1.0 or float(entry.wave) > 100000.0 \
			or float(int(entry.wave)) != float(entry.wave):
		return null
	for field: String in ["samples", "weapons", "levels"]:
		if typeof(entry.get(field)) != TYPE_ARRAY:
			return null
	if entry.samples.is_empty() or entry.samples.size() > MAX_SAMPLES or entry.weapons.is_empty() \
			or entry.weapons.size() > Content.MAX_WEAPON_SLOTS or entry.levels.size() != entry.weapons.size():
		return null
	if typeof(entry.get("stats")) != TYPE_DICTIONARY or entry.stats.size() != Stats.ORDER.size():
		return null
	var skill := StringName(str(entry.get("inherited_skill", "")))
	var donor_trait := StringName(str(entry.get("merge_trait", "")))
	if not SKILLS.has(skill) or (donor_trait != &"" and not EchoBank.MERGE_TRAITS.has(donor_trait)):
		return null
	var take := EchoTake.new()
	take.wave = int(entry.wave)
	take.condition = float(entry.condition)
	take.inherited_skill = skill
	take.merge_trait = donor_trait
	take.merged = bool(entry.get("merged", false))
	take.archived = true
	for point: Variant in entry.samples:
		if typeof(point) != TYPE_ARRAY or point.size() != 2 or not _number(point[0]) or not _number(point[1]):
			return null
		var position := Vector2(float(point[0]), float(point[1]))
		if not WorldArena.BOUNDS.has_point(position):
			return null
		take.samples.append(position)
	for i in entry.weapons.size():
		if typeof(entry.weapons[i]) not in [TYPE_STRING, TYPE_STRING_NAME] or not _number(entry.levels[i]):
			return null
		var weapon := Content.weapon(StringName(entry.weapons[i]))
		var level := int(entry.levels[i])
		if weapon == null or float(level) != float(entry.levels[i]) or level < 0 or level > WeaponDef.MAX_LEVEL:
			return null
		take.weapons.append(weapon)
		take.levels.append(level)
	for stat: StringName in Stats.ORDER:
		if not entry.stats.has(stat) and not entry.stats.has(String(stat)):
			return null
		var amount: Variant = entry.stats.get(stat, entry.stats.get(String(stat)))
		if not _number(amount) or absf(float(amount)) > MAX_STAT_VALUE:
			return null
		take.stats.values[stat] = float(amount)
	if take.stats.damage_mult() <= 0.0 or take.stats.get_stat(Stats.ATTACK_SPEED_PCT) <= -1.0 \
			or take.stats.get_stat(Stats.RANGE_PCT) <= -1.0 or take.stats.get_stat(Stats.MAX_HP) <= 0.0 \
			or not is_finite(take.power()) or take.power() <= 0.0:
		return null
	for stat: StringName in [Stats.MOVE_SPEED, Stats.PICKUP_RANGE, Stats.HP_REGEN, Stats.SHIELD,
			Stats.CRIT_CHANCE, Stats.ECHO_SLOTS, Stats.ECHO_DURATION, Stats.ECHO_POWER]:
		if take.stats.get_stat(stat) < 0.0:
			return null
	return take


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
