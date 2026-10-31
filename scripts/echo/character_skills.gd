class_name CharacterSkills
extends RefCounted

const ENERGY_COST := 100.0
const COOLDOWN := 6.0
const ENERGY_PER_MATERIAL := 4.0
const HISTORY_SAMPLES := 21
const REWIND_SECONDS := 2.0


static func on_pickup(sim: Sim, value: int) -> void:
	if sim.phase == Sim.Phase.WAVE and value > 0:
		sim.character_energy = minf(ENERGY_COST, sim.character_energy + float(mini(value, 5)) * ENERGY_PER_MATERIAL)


static func step(sim: Sim, delta: float) -> void:
	if sim.phase != Sim.Phase.WAVE or delta <= 0.0 or not is_finite(delta):
		return
	sim.character_cooldown = maxf(0.0, sim.character_cooldown - delta)
	for key: String in ["anchor_left", "ability_flash"]:
		if sim.role_effects.has(key):
			sim.role_effects[key] = maxf(0.0, float(sim.role_effects[key]) - delta)
	if sim.character_id == &"looper":
		var left := float(sim.role_effects.get("rewind_sample_left", 0.0)) - delta
		if left <= 0.0:
			var history: Array = sim.role_effects.get("rewind_history", [])
			var count := 0
			while left <= 0.0 and count < HISTORY_SAMPLES:
				history.append(sim.player.pos)
				if history.size() > HISTORY_SAMPLES:
					history.pop_front()
				left += 0.1
				count += 1
			sim.role_effects["rewind_history"] = history
			left = maxf(0.0, left)
		sim.role_effects["rewind_sample_left"] = left
	if int(sim.role_effects.get("relay_pulses", 0)) > 0:
		sim.role_effects["relay_left"] = float(sim.role_effects.get("relay_left", 0.0)) - delta
		if float(sim.role_effects["relay_left"]) <= 0.0:
			sim.role_effects["relay_left"] = 0.8
			sim.role_effects["relay_pulses"] = int(sim.role_effects["relay_pulses"]) - 1
			_relay(sim)


static func activate(sim: Sim) -> bool:
	var origin := sim.player.pos
	var before := {"pos": origin, "energy": sim.character_energy,
		"cooldown": sim.character_cooldown}
	var anchors: Array[Dictionary] = []
	for actor in sim.echoes:
		anchors.append({"uid": actor.take.uid, "from_pos": actor.pos, "to_pos": actor.pos})
	if sim.phase != Sim.Phase.WAVE or sim.character_cooldown > 0.0 or sim.character_energy < ENERGY_COST:
		_activation_event(sim, before, anchors, false,
			&"phase" if sim.phase != Sim.Phase.WAVE else (&"cooldown" if sim.character_cooldown > 0.0 else &"energy"))
		return false
	var applied := false
	match sim.character_id:
		&"looper": applied = _rewind(sim)
		&"solo": applied = _paper_dash(sim)
		&"mirror": applied = _swap(sim)
		&"conductor": applied = _conduct(sim)
		&"mender": applied = SupportSystem.spawn(sim, &"repair_station", sim.player.pos, -1)
		&"overloader": applied = EchoSystem.overload(sim)
	if not applied:
		_activation_event(sim, before, anchors, false, &"unavailable")
		return false
	sim.character_energy -= ENERGY_COST
	sim.character_cooldown = COOLDOWN
	sim.role_effects["ability_kind"] = sim.character_id
	sim.role_effects["ability_flash"] = 0.65
	_activation_event(sim, before, anchors, true, &"")
	return true


static func _activation_event(sim: Sim, before: Dictionary, anchors: Array[Dictionary],
		accepted: bool, reason: StringName) -> void:
	for row in anchors:
		for actor in sim.echoes:
			if actor.take.uid == int(row["uid"]):
				row["to_pos"] = actor.pos
	sim.world_event.emit({"kind": &"character_skill", "subject": sim.character_id,
		"ability": sim.character_id, "stage": sim.wave, "source": -1, "actor_token": -1,
		"pos": before["pos"], "target_pos": sim.player.pos, "ok": accepted, "reason": reason,
		"before": before, "after": {"pos": sim.player.pos, "energy": sim.character_energy,
			"cooldown": sim.character_cooldown}, "anchors": anchors})


static func _rewind(sim: Sim) -> bool:
	var history: Array = sim.role_effects.get("rewind_history", [])
	var destination := sim.player.pos
	if not history.is_empty():
		destination = history[0]
	elif not sim.recorder.samples.is_empty():
		destination = sim.recorder.samples[0]
	sim.player.pos = WorldArena.move_body(destination, Vector2.ZERO, PlayerState.RADIUS)
	for actor: EchoActor in sim.echoes:
		actor.t = maxf(0.0, actor.t - REWIND_SECONDS)
		actor.pos = actor.take.position_at(actor.t)
		actor.rewinding = actor.take.is_rewinding(actor.t)
		# Consumed key work stays consumed while the route catches back up.
	for i in sim.player.cooldowns.size():
		sim.player.cooldowns[i] = 0.0
	sim.player.iframes = maxf(sim.player.iframes, 0.35)
	sim.role_effects["rewind_history"] = [sim.player.pos]
	return true


static func _paper_dash(sim: Sim) -> bool:
	var start := sim.player.pos
	var direction := sim.player.facing.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var finish := WorldArena.move_body(start, direction * 220.0, PlayerState.RADIUS)
	sim.player.pos = finish
	sim.player.iframes = maxf(sim.player.iframes, 0.8)
	var segment := finish - start
	var length_squared := segment.length_squared()
	var damage := maxf(14.0, _player_power(sim) * 0.7)
	for enemy: EnemyState in sim.enemies.duplicate():
		if enemy.dead:
			continue
		var fraction := clampf((enemy.pos - start).dot(segment) / maxf(1.0, length_squared), 0.0, 1.0)
		var nearest := start + segment * fraction
		if enemy.pos.distance_to(nearest) <= enemy.radius + 30.0:
			sim.damage_enemy(enemy, damage, direction * 160.0, false, -1, direction,
				Content.STARTER_WEAPON, &"dash")
	return true


static func _swap(sim: Sim) -> bool:
	EchoSystem.ensure_selection(sim)
	var actor := EchoSystem.selected_actor(sim)
	if actor == null:
		return false
	var origin := sim.player.pos
	sim.player.pos = WorldArena.move_body(actor.pos, Vector2.ZERO, PlayerState.RADIUS)
	actor.pos = origin
	sim.role_effects["anchor_uid"] = actor.take.uid
	sim.role_effects["anchor_left"] = 2.0
	sim.player.iframes = maxf(sim.player.iframes, 0.3)
	return true


static func _conduct(sim: Sim) -> bool:
	EchoSystem.ensure_selection(sim)
	var actor := EchoSystem.selected_actor(sim)
	if actor == null:
		return false
	sim.role_effects["anchor_uid"] = actor.take.uid
	sim.role_effects["anchor_left"] = 4.0
	sim.role_effects["relay_left"] = 0.0
	sim.role_effects["relay_pulses"] = 3
	return true


static func _relay(sim: Sim) -> void:
	var take := sim.bank.find_uid(int(sim.role_effects.get("anchor_uid", 0)))
	if take == null:
		return
	for actor: EchoActor in sim.echoes:
		if actor.take != take:
			continue
		var profile := EchoSystem.skill_profile(take, sim)
		if not bool(profile.get("valid", false)):
			return
		profile["kind"] = &"arc"
		profile["damage"] = float(profile["damage"]) * 0.3
		profile["radius"] = 150.0
		profile["reach"] = 420.0
		Combat.retirement_skill(sim, actor, profile)
		return


static func _player_power(sim: Sim) -> float:
	var total := 0.0
	for i in sim.player.weapons.size():
		total += sim.player.weapons[i].level_dps(sim.player.level_at(i))
	return total * sim.player.stats.damage_mult() / sim.player.stats.cooldown_mult()
