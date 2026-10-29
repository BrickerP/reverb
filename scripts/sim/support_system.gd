class_name SupportSystem
extends RefCounted

const MAX_UNITS := 12
const CONTACT_INTERVAL := 0.6
const LURE_RANGE := 280.0
const UNIT_RADIUS := 13.0
const COMPANIONS: Array[StringName] = [&"recruited_foreman", &"recruited_collector", &"recruited_paradox"]
const PROFILES := {
	&"hound": {"hp": 24.0, "life": 20.0, "interval": 0.7, "damage": 6.0, "weapon": &"paper_hound"},
	&"turret": {"hp": 32.0, "life": 20.0, "interval": 1.0, "damage": 9.0, "weapon": &"debt_sentry"},
	&"repair_station": {"hp": 28.0, "life": 18.0, "interval": 2.0, "damage": 0.0, "weapon": &"repair_kit"},
	&"paper_tree": {"hp": 22.0, "life": 18.0, "interval": 3.0, "damage": 0.0, "weapon": &"paper_seed"},
	&"decoy": {"hp": 65.0, "life": 12.0, "interval": 1.0, "damage": 0.0, "weapon": &"guard_decoy"},
	&"recruited_foreman": {"hp": 100.0, "life": 600.0, "interval": 1.6, "damage": 16.0, "weapon": &"stamp"},
	&"recruited_collector": {"hp": 80.0, "life": 600.0, "interval": 1.1, "damage": 8.0, "weapon": &"hex_bolt"},
	&"recruited_paradox": {"hp": 65.0, "life": 600.0, "interval": 1.2, "damage": 9.0, "weapon": &"orb"},
}


static func spawn(sim: Sim, kind: StringName, pos: Vector2, actor_token: int = -1) -> bool:
	return _spawn(sim, kind, pos, actor_token, -2, Color.WHITE)


static func _spawn(sim: Sim, kind: StringName, pos: Vector2, actor_token: int,
		owner_source: int, owner_tint: Color) -> bool:
	if not PROFILES.has(kind) or not pos.is_finite() or sim.support_units.size() >= MAX_UNITS \
			or actor_token < -1 or actor_token == 0 or owner_source < -2 or owner_source >= Sim.MAX_ECHO_CAPACITY:
		return false
	var companion := COMPANIONS.has(kind)
	for unit: Dictionary in sim.support_units:
		if float(unit.get("hp", 0.0)) <= 0.0 or float(unit.get("life", 0.0)) <= 0.0:
			continue
		if companion and COMPANIONS.has(StringName(unit.get("kind", &""))):
			return false
		# A new shot cannot refresh a living unit's HP, charges or lifespan.
		if StringName(unit.get("kind", &"")) == kind and int(unit.get("actor_token", -1)) == actor_token:
			return false
	var profile: Dictionary = PROFILES[kind]
	var source := owner_source if owner_source != -2 else -1
	var tint := owner_tint
	if actor_token > 0:
		var resolved := false
		for actor: EchoActor in sim.echoes:
			if actor != null and actor.take != null and actor.take.uid == actor_token and actor.index >= 0 and actor.index < Sim.MAX_ECHO_CAPACITY 					and (owner_source == -2 or owner_source == actor.index):
				source = actor.index
				if owner_source == -2:
					tint = actor.take.tint()
				resolved = true
				break
		if not resolved:
			return false
	elif owner_source >= 0:
		return false
	var uid := maxi(1, sim._next_support_uid)
	sim._next_support_uid = uid + 1
	var unit := {
		"uid": uid, "kind": kind,
		"pos": WorldArena.move_body(pos, Vector2.ZERO, UNIT_RADIUS),
		"hp": float(profile["hp"]), "max_hp": float(profile["hp"]),
		"life": float(profile["life"]), "cooldown": 0.2,
		"actor_token": actor_token, "weapon_id": profile["weapon"],
		"source": source, "source_tint": tint, "damage": float(profile["damage"]),
		"interval": float(profile["interval"]), "contact_left": 0.0,
		"charges": 4 if kind == &"paper_tree" else (6 if kind == &"repair_station" else 0),
		"level": 0, "reach": 430.0,
	}
	sim.support_units.append(unit)
	_event(sim, unit, &"spawn")
	return true


static func spawn_weapon(sim: Sim, weapon: WeaponDef, pos: Vector2, damage_amount: float,
		source: int, actor_token: int, tint: Color, level: int,
		cadence_mult: float = 1.0, reach_mult: float = 1.0) -> bool:
	if weapon == null or Content.weapon(weapon.id) != weapon or not PROFILES.has(weapon.support_kind) \
			or PROFILES[weapon.support_kind]["weapon"] != weapon.id or source < -1 or source >= Sim.MAX_ECHO_CAPACITY \
			or not is_finite(damage_amount) or damage_amount < 0.0 or not is_finite(cadence_mult) or not is_finite(reach_mult) or cadence_mult <= 0.0 or reach_mult <= 0.0 \
			or not is_finite(tint.r) or not is_finite(tint.g) or not is_finite(tint.b) or not is_finite(tint.a):
		return false
	if not _spawn(sim, weapon.support_kind, pos, actor_token, source, tint):
		return false
	var unit: Dictionary = sim.support_units.back()
	unit["source"] = source
	unit["actor_token"] = actor_token
	unit["source_tint"] = tint
	unit["weapon_id"] = weapon.id
	unit["damage"] = minf(500.0, damage_amount) if weapon.role not in [&"repair", &"production", &"defense"] else 0.0
	unit["interval"] = clampf(float(unit["interval"]) * cadence_mult, 0.15, 5.0)
	unit["reach"] = clampf(weapon.reach * reach_mult, 60.0, 1200.0)
	unit["level"] = clampi(level, 0, WeaponDef.MAX_LEVEL)
	if weapon.support_kind in [&"repair_station", &"paper_tree", &"decoy"]:
		unit["max_hp"] = float(unit["max_hp"]) * weapon.level_mult(level)
		unit["hp"] = unit["max_hp"]
	return true


static func damage(sim: Sim, uid: int, amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0:
		return false
	for unit: Dictionary in sim.support_units:
		if int(unit.get("uid", -1)) != uid or float(unit.get("hp", 0.0)) <= 0.0:
			continue
		var actual := minf(float(unit["hp"]), amount)
		unit["hp"] = maxf(0.0, float(unit["hp"]) - amount)
		_event(sim, unit, &"damage", actual)
		if float(unit["hp"]) <= 0.0:
			_event(sim, unit, &"destroy")
		return true
	return false


static func target_position(sim: Sim, from: Vector2, fallback: Vector2) -> Vector2:
	var target := fallback
	var best := minf(from.distance_squared_to(fallback), LURE_RANGE * LURE_RANGE)
	for unit: Dictionary in sim.support_units:
		if float(unit.get("hp", 0.0)) <= 0.0 or float(unit.get("life", 0.0)) <= 0.0:
			continue
		var pos: Vector2 = unit["pos"]
		var d2 := from.distance_squared_to(pos)
		if StringName(unit["kind"]) == &"decoy":
			d2 *= 0.3
		if d2 < best and from.distance_squared_to(pos) <= LURE_RANGE * LURE_RANGE:
			best = d2
			target = pos
	return target


static func step(sim: Sim, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var keep: Array[Dictionary] = []
	for unit: Dictionary in sim.support_units:
		if float(unit.get("hp", 0.0)) <= 0.0:
			continue
		var active_delta := minf(delta, maxf(0.0, float(unit.get("life", 0.0))))
		unit["life"] = maxf(0.0, float(unit["life"]) - delta)
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - active_delta)
		unit["contact_left"] = maxf(0.0, float(unit.get("contact_left", 0.0)) - active_delta)
		if active_delta > 0.0:
			_step_unit(sim, unit, active_delta)
			_contact_damage(sim, unit)
		if float(unit["hp"]) > 0.0 and float(unit["life"]) > 0.0:
			keep.append(unit)
		elif float(unit["hp"]) > 0.0:
			_event(sim, unit, &"expire")
	sim.support_units = keep


static func _step_unit(sim: Sim, unit: Dictionary, delta: float) -> void:
	var kind := StringName(unit["kind"])
	match kind:
		&"hound", &"recruited_collector":
			_mobile(sim, unit, delta, kind == &"hound")
		&"recruited_foreman", &"recruited_paradox":
			_mobile(sim, unit, delta, false)
		&"turret":
			var target := Combat.nearest_enemy(sim.enemies, unit["pos"], float(unit["reach"]))
			if target != null and float(unit["cooldown"]) <= 0.0:
				_turret_shot(sim, unit, target)
		&"repair_station":
			_repair(sim, unit)
		&"paper_tree":
			_produce(sim, unit)


static func _mobile(sim: Sim, unit: Dictionary, delta: float, is_hound: bool) -> void:
	var pos: Vector2 = unit["pos"]
	var kind := StringName(unit["kind"])
	var enemy := Combat.nearest_enemy(sim.enemies, pos, float(unit["reach"]))
	var pickup: Pickup = null
	var pickup_d2 := 260.0 * 260.0
	if is_hound or kind == &"recruited_collector":
		for candidate: Pickup in sim.pickups:
			# Mission parts remain a deliberate player/world interaction.
			if candidate.value <= 0 or candidate.kind not in [&"scrap", &"supply"]:
				continue
			var d2 := pos.distance_squared_to(candidate.pos)
			if d2 < pickup_d2:
				pickup = candidate
				pickup_d2 = d2
	var target := sim.player.pos
	var combat_reach := 34.0 if is_hound else (95.0 if kind == &"recruited_foreman" else 240.0)
	if enemy != null:
		target = enemy.pos
	if pickup != null and (enemy == null or pickup_d2 < pos.distance_squared_to(enemy.pos) * 0.65):
		target = pickup.pos
	elif enemy != null and pos.distance_to(enemy.pos) <= combat_reach:
		target = pos
	var travel := (target - pos).limit_length((220.0 if is_hound else 140.0) * delta)
	unit["pos"] = WorldArena.move_body(pos, travel, UNIT_RADIUS)
	pos = unit["pos"]
	if pickup != null and pos.distance_squared_to(pickup.pos) <= 26.0 * 26.0:
		var value := pickup.value
		if sim.collect_pickup(pickup, false):
			_event(sim, unit, &"retrieve", float(value))
	if enemy == null or enemy.dead or float(unit["cooldown"]) > 0.0 or pos.distance_to(enemy.pos) > combat_reach + enemy.radius:
		return
	var count := 0
	if kind == &"recruited_foreman":
		for other: EnemyState in sim.enemies:
			if not other.dead and pos.distance_squared_to(other.pos) <= pow(100.0 + other.radius, 2.0):
				_hit(sim, unit, other, &"support_slam", 0.0, 0.0)
				count += 1
				if count >= 4:
					break
	elif kind == &"recruited_collector":
		for other: EnemyState in sim.enemies:
			if not other.dead and enemy.pos.distance_squared_to(other.pos) <= pow(110.0 + other.radius, 2.0):
				_hit(sim, unit, other, &"support_chain", 0.0, 0.0)
				count += 1
				if count >= 3:
					break
	elif kind == &"recruited_paradox":
		_hit(sim, unit, enemy, &"support_fold", 0.5, 0.8)
	else:
		_hit(sim, unit, enemy, &"hound_bite", 0.0, 0.0)
	unit["cooldown"] = float(unit["interval"])
	_event(sim, unit, &"attack", float(unit["damage"]))


static func _turret_shot(sim: Sim, unit: Dictionary, enemy: EnemyState) -> void:
	if sim.projectiles.size() >= Combat.MAX_PROJECTILES:
		return
	var pos: Vector2 = unit["pos"]
	var direction := (enemy.pos - pos).normalized()
	var projectile := Projectile.new()
	projectile.pos = pos + direction * 14.0
	projectile.origin = pos
	projectile.vel = direction * 760.0
	projectile.damage = float(unit["damage"]) * (1.25 if int(sim.expedition.get("debt", 0)) > 0 else 1.0)
	projectile.life = float(unit["reach"]) / 760.0
	projectile.color = Content.weapon(StringName(unit["weapon_id"])).color
	projectile.source = int(unit["source"])
	projectile.actor_token = int(unit["actor_token"])
	projectile.source_tint = unit["source_tint"]
	projectile.weapon_id = StringName(unit["weapon_id"])
	projectile.effect = &"turret_bolt"
	sim.projectiles.append(projectile)
	unit["cooldown"] = float(unit["interval"])
	_event(sim, unit, &"attack", projectile.damage)


static func _hit(sim: Sim, unit: Dictionary, enemy: EnemyState, effect: StringName,
		pin: float, ink: float) -> void:
	var pos: Vector2 = unit["pos"]
	if Combat._clear_endpoint(pos, enemy.pos, 1.0).distance_squared_to(enemy.pos) > 1.0:
		return
	Combat._hit(sim, enemy, float(unit["damage"]), (enemy.pos - pos).normalized(), 35.0,
		false, int(unit["source"]), int(unit["actor_token"]), unit["source_tint"],
		StringName(unit["weapon_id"]), effect, pin, ink, false)


static func _repair(sim: Sim, unit: Dictionary) -> void:
	if int(unit["charges"]) <= 0 or float(unit["cooldown"]) > 0.0:
		return
	var pos: Vector2 = unit["pos"]
	var repaired := 0.0
	if pos.distance_squared_to(sim.player.pos) <= 150.0 * 150.0:
		var before := sim.player.hp
		sim.player.hp = minf(sim.player.max_hp(), sim.player.hp + 1.5 * (1.0 + 0.15 * float(unit["level"])))
		repaired += sim.player.hp - before
	for actor: EchoActor in sim.echoes:
		if pos.distance_squared_to(actor.pos) <= 150.0 * 150.0:
			var before := actor.take.condition
			actor.take.condition = minf(100.0, before + 2.0 * (1.0 + 0.15 * float(unit["level"])))
			repaired += actor.take.condition - before
	for ally: Dictionary in sim.support_units:
		if int(ally["uid"]) == int(unit["uid"]) or float(ally["hp"]) <= 0.0:
			continue
		var ally_pos: Vector2 = ally["pos"]
		if pos.distance_squared_to(ally_pos) <= 150.0 * 150.0:
			var before := float(ally["hp"])
			ally["hp"] = minf(float(ally["max_hp"]), before + 2.0 * (1.0 + 0.15 * float(unit["level"])))
			repaired += float(ally["hp"]) - before
	if repaired > 0.0:
		unit["charges"] = int(unit["charges"]) - 1
		unit["cooldown"] = float(unit["interval"])
		_event(sim, unit, &"repair", repaired)


static func _produce(sim: Sim, unit: Dictionary) -> void:
	var pos: Vector2 = unit["pos"]
	if int(unit["charges"]) <= 0 or float(unit["cooldown"]) > 0.0 or pos.distance_squared_to(sim.player.pos) > 180.0 * 180.0:
		return
	# Four deliveries per tree; no cash, no pickups, no end-wave payout path.
	var shield_before := sim.player.shield
	var energy_before := sim.character_energy
	sim.player.shield = minf(maxf(12.0, sim.player.max_shield()), sim.player.shield + 2.0 * (1.0 + 0.15 * float(unit["level"])))
	sim.character_energy = minf(100.0, sim.character_energy + 3.0 * (1.0 + 0.15 * float(unit["level"])))
	var produced := sim.player.shield - shield_before + sim.character_energy - energy_before
	if produced > 0.0:
		unit["charges"] = int(unit["charges"]) - 1
		unit["cooldown"] = float(unit["interval"])
		_event(sim, unit, &"produce", produced)


static func _contact_damage(sim: Sim, unit: Dictionary) -> void:
	if float(unit["contact_left"]) > 0.0 or float(unit["hp"]) <= 0.0:
		return
	var pos: Vector2 = unit["pos"]
	for enemy: EnemyState in sim.enemies:
		if enemy.dead or enemy.stun_left > 0.0:
			continue
		if pos.distance_squared_to(enemy.pos) <= pow(UNIT_RADIUS + enemy.radius, 2.0):
			damage(sim, int(unit["uid"]), enemy.damage)
			unit["contact_left"] = CONTACT_INTERVAL
			return


static func _event(sim: Sim, unit: Dictionary, kind: StringName, amount: float = 0.0) -> void:
	sim.support_event.emit({"kind": kind, "uid": int(unit["uid"]),
		"unit_kind": StringName(unit["kind"]), "pos": unit["pos"],
		"source": int(unit["source"]), "actor_token": int(unit["actor_token"]),
		"weapon_id": StringName(unit["weapon_id"]), "amount": amount})


# Shared by live checkpoints and transaction undo. Validation never repairs or
# mutates a snapshot: malformed authoritative state is rejected as one unit.
static func validate_state(units: Array, next_uid: int) -> bool:
	if units.size() > MAX_UNITS or next_uid < 1:
		return false
	var fields := ["uid", "kind", "pos", "hp", "max_hp", "life", "cooldown", "actor_token",
		"weapon_id", "source", "source_tint", "damage", "interval", "contact_left", "charges", "level", "reach"]
	var seen := {}
	var owners := {}
	var companions := 0
	for value in units:
		if not value is Dictionary:
			return false
		var unit: Dictionary = value
		if unit.size() != fields.size():
			return false
		for field: String in fields:
			if not unit.has(field):
				return false
		for field: String in ["uid", "source", "actor_token", "charges", "level"]:
			if not unit[field] is int:
				return false
		if not unit["kind"] is StringName or not unit["weapon_id"] is StringName \
				or not unit["pos"] is Vector2 or not unit["source_tint"] is Color:
			return false
		var kind: StringName = unit["kind"]
		if not PROFILES.has(kind) or unit["weapon_id"] != PROFILES[kind]["weapon"]:
			return false
		var uid: int = unit["uid"]
		var source: int = unit["source"]
		var token: int = unit["actor_token"]
		var level: int = unit["level"]
		if uid < 1 or uid >= next_uid or seen.has(uid) or source < -1 or source >= Sim.MAX_ECHO_CAPACITY \
				or token < -1 or (source == -1 and token != -1) or (source >= 0 and token < 1) \
				or level < 0 or level > WeaponDef.MAX_LEVEL:
			return false
		seen[uid] = true
		var pos: Vector2 = unit["pos"]
		var tint: Color = unit["source_tint"]
		if not pos.is_finite() or not WorldArena.BOUNDS.has_point(pos) \
				or not is_finite(tint.r) or not is_finite(tint.g) or not is_finite(tint.b) or not is_finite(tint.a):
			return false
		for field: String in ["hp", "max_hp", "life", "cooldown", "damage", "interval", "contact_left", "reach"]:
			if not unit[field] is float or not is_finite(unit[field]) or float(unit[field]) < 0.0:
				return false
		var expected_hp := float(PROFILES[kind]["hp"])
		if kind in [&"repair_station", &"paper_tree", &"decoy"]:
			expected_hp *= Content.weapon(StringName(unit["weapon_id"])).level_mult(level)
		if not is_equal_approx(float(unit["max_hp"]), expected_hp) or float(unit["hp"]) > float(unit["max_hp"]) \
				or float(unit["life"]) > float(PROFILES[kind]["life"]) or float(unit["cooldown"]) > 5.0 \
				or float(unit["damage"]) > 500.0 or float(unit["interval"]) < 0.15 or float(unit["interval"]) > 5.0 \
				or float(unit["contact_left"]) > CONTACT_INTERVAL or float(unit["reach"]) < 60.0 or float(unit["reach"]) > 1200.0:
			return false
		var max_charges := 4 if kind == &"paper_tree" else (6 if kind == &"repair_station" else 0)
		if int(unit["charges"]) < 0 or int(unit["charges"]) > max_charges:
			return false
		if float(unit["hp"]) > 0.0 and float(unit["life"]) > 0.0:
			var owner := "%s:%d" % [kind, token]
			if owners.has(owner):
				return false
			owners[owner] = true
			if COMPANIONS.has(kind):
				companions += 1
				if companions > 1:
					return false
	return true
