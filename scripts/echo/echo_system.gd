class_name EchoSystem
extends RefCounted

const INPUT_COOLDOWN := 0.35
const LOW_CONDITION := 25.0


static func step(sim: Sim, delta: float) -> void:
	if sim.phase != Sim.Phase.WAVE or delta <= 0.0 or not is_finite(delta):
		return
	sim.retire_cooldown = maxf(0.0, sim.retire_cooldown - delta)
	var wear := 100.0 * delta / sim.echo_duration() * maxf(0.0, sim.wear_rate_mult)
	for actor: EchoActor in sim.echoes.duplicate():
		if int(sim.role_effects.get("anchor_uid", 0)) != actor.take.uid or float(sim.role_effects.get("anchor_left", 0.0)) <= 0.0:
			actor.step(delta)
		actor.take.condition = maxf(0.0, actor.take.condition - wear)
		if actor.take.condition <= 0.0:
			_remove(sim, actor, true, {})
	ensure_selection(sim)


static func selected_actor(sim: Sim) -> EchoActor:
	for actor in sim.echoes:
		if actor.take.uid == sim.selected_echo_uid and actor.take.condition > 0.0:
			return actor
	return null


static func ensure_selection(sim: Sim) -> void:
	if selected_actor(sim) != null:
		return
	sim.selected_echo_uid = sim.echoes[0].take.uid if not sim.echoes.is_empty() else 0


static func select(sim: Sim, uid: int) -> bool:
	for actor in sim.echoes:
		if actor.take.uid == uid and actor.take.condition > 0.0:
			sim.selected_echo_uid = uid
			return true
	return false


static func cycle(sim: Sim, direction: int) -> bool:
	if sim.echoes.is_empty():
		sim.selected_echo_uid = 0
		return false
	ensure_selection(sim)
	var current := 0
	for i in sim.echoes.size():
		if sim.echoes[i].take.uid == sim.selected_echo_uid:
			current = i
	var step_direction := 1 if direction >= 0 else -1
	return select(sim, sim.echoes[posmod(current + step_direction, sim.echoes.size())].take.uid)


static func can_retire(sim: Sim) -> bool:
	return sim.phase == Sim.Phase.WAVE and sim.retire_cooldown <= 0.0 \
			and selected_actor(sim) != null


# Mirror predictions deliberately use the live loadout, just like its actual fire.
static func skill_profile(take: EchoTake, sim: Sim) -> Dictionary:
	if take == null or sim == null:
		return {"valid": false}
	var weapons: Array[WeaponDef] = sim.player.weapons if sim.live_echo else take.weapons
	var levels: Array[int] = sim.player.weapon_levels if sim.live_echo else take.levels
	var stats: Stats = sim.player.stats if sim.live_echo else take.stats
	if weapons.is_empty():
		return {"valid": false, "uid": take.uid, "condition": take.condition}
	var dominant := 0
	var power := -1.0
	for i in weapons.size():
		var level := levels[i] if i < levels.size() else 0
		var candidate := weapons[i].level_dps(level)
		if candidate > power:
			power = candidate
			dominant = i
	var weapon := weapons[dominant]
	var kind := take.inherited_skill if take.inherited_skill != &"" else kind_for_style(weapon.attack_style)
	var damage := maxf(12.0, power * stats.damage_mult() / stats.cooldown_mult() \
			* sim.echo_power() * 1.8 * sim.synergy_damage_mult()) * sim.retirement_mult
	return {"valid": true, "uid": take.uid, "condition": take.condition,
		"kind": kind, "weapon_id": weapon.id, "damage": damage,
		"radius": 150.0, "reach": clampf(weapon.reach * stats.range_mult(), 180.0, 420.0),
		"direction": Vector2.RIGHT, "tint": take.tint(), "live_loadout": sim.live_echo,
		"name_key": "echo.skill.%s" % kind, "description_key": "echo.skill.%s.desc" % kind}


static func kind_for_style(style: StringName) -> StringName:
	match style:
		&"slam", &"pet", &"guard": return &"stamp"
		&"cone", &"line": return &"cut"
		&"ink", &"tape": return &"ink"
		&"boomerang": return &"return"
		&"chain", &"orbit", &"fabricate": return &"arc"
	return &"pin"


static func retire(sim: Sim) -> bool:
	return _retire(sim, false)


static func overload(sim: Sim) -> bool:
	return _retire(sim, true)


static func _retire(sim: Sim, overloaded: bool) -> bool:
	ensure_selection(sim)
	if not can_retire(sim):
		return false
	var actor := selected_actor(sim)
	var profile := skill_profile(actor.take, sim)
	if not bool(profile.get("valid", false)):
		return false
	if overloaded:
		profile["kind"] = &"stamp"
		profile["name_key"] = "echo.skill.stamp"
		profile["description_key"] = "echo.skill.stamp.desc"
		profile["radius"] = 210.0
		profile["damage"] *= 0.5 + 2.0 * clampf(actor.take.condition / 100.0, 0.0, 1.0)
	var target := Combat.nearest_enemy(sim.enemies, actor.pos, float(profile["reach"]))
	if target != null:
		var direction := (target.pos - actor.pos).normalized()
		profile["direction"] = direction if direction != Vector2.ZERO else Vector2.RIGHT
	if not Combat.retirement_skill(sim, actor, profile):
		return false
	sim.retire_cooldown = INPUT_COOLDOWN
	_remove(sim, actor, false, profile)
	return true


static func _remove(sim: Sim, actor: EchoActor, exhausted: bool, profile: Dictionary) -> void:
	var info := EchoRetirementInfo.new()
	info.reason = EchoRetirementInfo.EXHAUSTED if exhausted else EchoRetirementInfo.ACTIVE
	info.exhausted = exhausted
	info.uid = actor.take.uid
	info.actor_token = actor.take.uid
	info.source = actor.index
	info.wave = actor.take.wave
	info.pos = actor.pos
	info.tint = actor.take.tint()
	info.condition = actor.take.condition
	info.profile = profile.duplicate(true)
	info.kind = StringName(profile.get("kind", &""))
	info.weapon_id = StringName(profile.get("weapon_id", &""))
	info.damage = float(profile.get("damage", 0.0))
	info.radius = float(profile.get("radius", 0.0))
	sim.bank.discard(actor.take)
	sim.echoes.erase(actor)
	for i in sim.echoes.size():
		sim.echoes[i].index = i
	ensure_selection(sim)
	sim.echo_retired.emit(info)
