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
	var previous := meta.echo_archives.duplicate(true)
	meta.echo_archives[String(character_id)] = entry
	if meta.save():
		return true
	meta.echo_archives = previous
	return false


# Entry is one pure transform for runtime loading, previews and replacement choices.
# All weapon grades share the opening budget, including non-damage utility.
static func normalize(take: EchoTake, sim: Sim) -> EchoTake:
	if sim == null or take == null or encode(take).is_empty():
		return null
	var entry := take.copy()
	var original_power := take.power()
	entry.levels.clear()
	var nominal := 0.0
	for weapon: WeaponDef in entry.weapons:
		entry.levels.append(0)
		nominal += weapon.level_dps(0)
	var player_power := 0.0
	for i in sim.player.weapons.size():
		player_power += sim.player.weapons[i].level_dps(sim.player.level_at(i))
	player_power *= sim.player.stats.damage_mult() / sim.player.stats.cooldown_mult()
	var target_power := minf(original_power, maxf(1.0, player_power) * 0.75)
	entry.stats = sim.player.stats.copy()
	if nominal > 0.0:
		entry.stats.values[Stats.DAMAGE_PCT] = target_power * entry.stats.cooldown_mult() / nominal - 1.0
	entry.condition = minf(INHERITED_CONDITION, take.condition)
	entry.archived = true
	return entry


static func load(meta: Meta, character_id: StringName, sim: Sim) -> EchoTake:
	if meta == null or sim == null or not meta.inherit_echo or sim.daily_modifier != &"" \
			or not eligible(character_id) or sim.echo_capacity() <= sim.bank.takes.size():
		return null
	return normalize(peek(meta, character_id), sim)


static func entry_preview(meta: Meta, character_id: StringName, sim: Sim) -> Dictionary:
	return preview(peek(meta, character_id), sim)


static func preview(take: EchoTake, sim: Sim) -> Dictionary:
	var entry := normalize(take, sim)
	if entry == null:
		return {}
	# The opening wave has this inherited actor, even though the menu simulation
	# has not spawned it yet. Use the real combat/skill readers on that context so
	# Conductor's own-copy bonus is not lost from its next-run comparison.
	var context := _entry_context(sim, entry)
	var weapons: Array[WeaponDef] = context.player.weapons if context.live_echo else entry.weapons
	var levels: Array[int] = context.player.weapon_levels if context.live_echo else entry.levels
	var stats: Stats = context.player.stats if context.live_echo else entry.stats
	var utilities: Array[Dictionary] = []
	for i in weapons.size():
		var weapon := weapons[i]
		if weapon.support_kind == &"":
			continue
		var level := levels[i] if i < levels.size() else 0
		var amount := weapon.damage * weapon.level_mult(level) * stats.damage_mult() * context.echo_power() \
			* context.synergy_damage_mult() * Combat.family_damage_mult(weapons, weapon.family)
		var profile := SupportSystem.weapon_profile(weapon, level, amount, stats.cooldown_mult(), stats.range_mult())
		if not profile.is_empty():
			profile["weapon_id"] = weapon.id
			utilities.append(profile)
	return {"take": entry, "damage": context.echo_dps(entry), "utility": utilities,
		"condition": entry.condition, "skill": EchoSystem.skill_profile(entry, context),
		"work": entry.work_actions.duplicate(true), "route_distance": route_distance(entry),
		"weapons": weapons.duplicate(), "levels": levels.duplicate(), "live_loadout": sim.live_echo}


static func _entry_context(sim: Sim, entry: EchoTake) -> Sim:
	var context := Sim.new(1)
	# The shared player is read-only here; no RNG, gear or live actor is mutated.
	context.player = sim.player
	context.live_echo = sim.live_echo
	context.daily_modifier = sim.daily_modifier
	context.retirement_mult = sim.retirement_mult
	context.synergy_damage_per_echo = sim.synergy_damage_per_echo
	context.synergy_haste_per_echo = sim.synergy_haste_per_echo
	context.echoes.append(EchoActor.new(entry, 0))
	return context


static func route_distance(take: EchoTake) -> float:
	var distance := 0.0
	for i in range(1, take.samples.size()):
		distance += take.samples[i - 1].distance_to(take.samples[i])
	return distance


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
		"merge_trait": String(take.merge_trait), "merged": take.merged,
		"work_actions": _encode_work(take.work_actions)}
	return entry if decode(entry) != null else {}


static func decode(value: Variant) -> EchoTake:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var entry: Dictionary = value
	if entry.size() < RECORD_KEYS.size() or entry.size() > RECORD_KEYS.size() + 1:
		return null
	for key: Variant in entry:
		if not RECORD_KEYS.has(key) and key != "work_actions":
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
			or not is_finite(take.power()) or take.power() < 0.0:
		return null
	for stat: StringName in [Stats.MOVE_SPEED, Stats.PICKUP_RANGE, Stats.HP_REGEN, Stats.SHIELD,
			Stats.CRIT_CHANCE, Stats.ECHO_SLOTS, Stats.ECHO_DURATION, Stats.ECHO_POWER]:
		if take.stats.get_stat(stat) < 0.0:
			return null
	var work: Variant = _decode_work(entry.get("work_actions", []))
	if work == null or not EchoWork.validate_actions(work, take.duration()):
		return null
	for action: Dictionary in work:
		if action.kind == &"signature" and not take.weapons.has(Content.weapon(action.weapon_id)):
			return null
		take.work_actions.append(action)
	return take


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _encode_work(actions: Array[Dictionary]) -> Array:
	var out: Array = []
	for action: Dictionary in actions:
		# Validate before indexing: caller data is not trusted merely because it is typed.
		if not EchoWork.validate_actions([action], MAX_SAMPLES * EchoTake.SAMPLE_DT):
			return [null]
		var pos: Vector2 = action.pos
		var aim: Vector2 = action.aim
		out.append({"time": action.time, "kind": String(action.kind), "target_id": String(action.target_id),
			"pos": [pos.x, pos.y], "weapon_id": String(action.weapon_id), "aim": [aim.x, aim.y]})
	return out


static func _decode_work(value: Variant) -> Variant:
	if not value is Array or value.size() > 6:
		return null
	var out: Array[Dictionary] = []
	for raw: Variant in value:
		if not raw is Dictionary or raw.size() != 6:
			return null
		for field: String in ["time", "kind", "target_id", "pos", "weapon_id", "aim"]:
			if not raw.has(field):
				return null
		if not _number(raw.time):
			return null
		for field: String in ["kind", "target_id", "weapon_id"]:
			if not raw[field] is String:
				return null
		for field: String in ["pos", "aim"]:
			if not raw[field] is Array or raw[field].size() != 2 or not _number(raw[field][0]) or not _number(raw[field][1]):
				return null
		out.append({"time": float(raw.time), "kind": StringName(raw.kind), "target_id": StringName(raw.target_id),
			"pos": Vector2(float(raw.pos[0]), float(raw.pos[1])), "weapon_id": StringName(raw.weapon_id),
			"aim": Vector2(float(raw.aim[0]), float(raw.aim[1]))})
	return out
