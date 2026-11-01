class_name EnemyBrain
extends RefCounted

const RUNNER_WARN := 0.62
const RUNNER_DASH := 0.42
const RUNNER_RECOVER := 1.0
const RUNNER_SPEED := 560.0
const RUNNER_TRIGGER := 330.0
const BRUTE_WARN := 0.8
const BRUTE_SLAM := 0.18
const BRUTE_RECOVER := 1.15
const BRUTE_REACH := 132.0
const BRUTE_HALF_ANGLE := PI * 0.28
const WARDEN_TURN_SPEED := 1.8
const MAX_ZONES := 12
const IMPACT_MULT := 1.6


static func impact_damage(enemy: EnemyState) -> float:
	return enemy.damage * IMPACT_MULT


static func in_cross(body: Vector2, point: Vector2, radius: float) -> bool:
	var offset := body - point
	return (absf(offset.x) <= 34.0 + radius and absf(offset.y) <= 205.0 + radius) \
		or (absf(offset.y) <= 34.0 + radius and absf(offset.x) <= 205.0 + radius)


static func _echo_in_cross(sim: Sim, point: Vector2) -> EchoActor:
	var chosen: EchoActor = null
	var best := INF
	for actor in sim.echoes:
		if actor == null or actor.take == null:
			continue
		if not in_cross(actor.pos, point, PlayerState.RADIUS):
			continue
		var distance := actor.pos.distance_squared_to(sim.player.pos)
		if distance < best:
			best = distance
			chosen = actor
	return chosen


static func paradox_cross_damage() -> float:
	return paradox_cross_damage_at(1)


static func paradox_cross_damage_at(wave: int) -> float:
	return Content.enemy(&"paradox").damage * WaveDirector.damage_scale(wave) * IMPACT_MULT


static func step(sim: Sim, enemy: EnemyState, delta: float) -> void:
	if enemy == null or enemy.dead or enemy.def == null or delta <= 0.0 or not is_finite(delta) or Expedition.is_negotiating(sim):
		return
	enemy.flash = maxf(0.0, enemy.flash - delta)
	enemy.attack_tick = maxf(0.0, enemy.attack_tick - delta)
	var was_stunned := enemy.stun_left > 0.0
	var was_pinned := enemy.pin_left > 0.0
	enemy.pin_left = maxf(0.0, enemy.pin_left - delta)
	enemy.ink_left = maxf(0.0, enemy.ink_left - delta)
	enemy.stun_left = maxf(0.0, enemy.stun_left - delta)
	var knock := enemy.knock * delta
	enemy.knock = enemy.knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if was_stunned or was_pinned:
		enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
		if was_stunned and enemy.brain_state in [&"warn", &"dash", &"slam", &"seal"]:
			_enter(enemy, &"recover", 0.65)
		return
	if knock != Vector2.ZERO:
		enemy.pos = WorldArena.move_body(enemy.pos, knock, enemy.radius)
	match enemy.def.id:
		&"runner": _runner(sim, enemy, delta)
		&"brute": _brute(sim, enemy, delta)
		&"silencer": _silencer(sim, enemy, delta)
		&"warden": _warden(sim, enemy, delta)
		&"foreman", &"collector", &"paradox": _boss(sim, enemy, delta)
		_:
			var target := SupportSystem.target_position(sim, enemy.pos, sim.player.pos)
			var direction := (target - enemy.pos).normalized()
			enemy.attack_direction = direction if direction != Vector2.ZERO else enemy.attack_direction
			_walk(enemy, direction, enemy.speed, delta)
			_contact(sim, enemy)


static func _boss(sim: Sim, enemy: EnemyState, delta: float) -> void:
	if enemy.brain_state == &"defeated":
		return
	if enemy.brain_state == &"warn":
		enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
		if enemy.brain_time <= 0.0:
			if enemy.def.id == &"collector":
				_enter(enemy, &"dash", 0.65)
			else:
				_enter(enemy, &"slam", 0.22)
				_boss_impact(sim, enemy)
		return
	if enemy.brain_state == &"dash":
		var before := enemy.pos
		var travel := minf(delta, enemy.brain_time)
		enemy.pos = WorldArena.move_straight(enemy.pos, enemy.attack_direction * 580.0 * travel, enemy.radius)
		var radius := 34.0 + PlayerState.RADIUS
		if _segment_distance_squared(sim.player.pos, before, enemy.pos) <= radius * radius:
			_hurt(sim, enemy, enemy.damage * 1.4, &"collector_charge", enemy.attack_direction)
		for unit in sim.support_units.duplicate():
			if _segment_distance_squared(unit["pos"], before, enemy.pos) <= pow(34.0 + SupportSystem.UNIT_RADIUS, 2.0):
				SupportSystem.damage(sim, int(unit["uid"]), enemy.damage * travel)
		enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
		if enemy.brain_time <= 0.0:
			_enter(enemy, &"recover", 1.3)
		return
	if enemy.brain_state in [&"slam", &"recover"]:
		enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
		if enemy.brain_time <= 0.0:
			if enemy.brain_state == &"slam":
				_enter(enemy, &"recover", 1.4)
			else:
				_enter(enemy, &"approach", 0.0)
		return
	var target := SupportSystem.target_position(sim, enemy.pos, sim.player.pos)
	var offset := target - enemy.pos
	if offset.length_squared() <= 440.0 * 440.0:
		_lock(enemy, target)
		_enter(enemy, &"warn", 0.95 if enemy.def.id == &"collector" else 1.1)
	else:
		enemy.attack_direction = offset.normalized()
		_walk(enemy, enemy.attack_direction, enemy.speed * 1.15, delta)
	_contact(sim, enemy)


static func _boss_impact(sim: Sim, enemy: EnemyState) -> void:
	var point := enemy.attack_target
	var offset := sim.player.pos - point
	var inside := offset.length() <= 112.0 + PlayerState.RADIUS
	if enemy.def.id == &"paradox":
		inside = in_cross(sim.player.pos, point, PlayerState.RADIUS)
		if inside:
			var copy := _echo_in_cross(sim, point)
			if copy != null:
				EchoSystem.absorb(sim, copy)
				inside = false
	if inside:
		_hurt(sim, enemy, impact_damage(enemy), &"foreman_press" if enemy.def.id == &"foreman" else &"paradox_cross", offset.normalized())
	for unit in sim.support_units.duplicate():
		var support_offset: Vector2 = unit["pos"] - point
		var hit := support_offset.length() <= 112.0 + SupportSystem.UNIT_RADIUS
		if enemy.def.id == &"paradox":
			hit = in_cross(unit["pos"], point, SupportSystem.UNIT_RADIUS)
		if hit:
			SupportSystem.damage(sim, int(unit["uid"]), impact_damage(enemy))


static func _runner(sim: Sim, enemy: EnemyState, delta: float) -> void:
	match enemy.brain_state:
		&"warn":
			var remainder := maxf(0.0, delta - enemy.brain_time)
			enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
			if enemy.brain_time <= 0.0:
				_enter(enemy, &"dash", RUNNER_DASH)
				if remainder > 0.0:
					_runner(sim, enemy, remainder)
		&"dash":
			var travel_time := minf(delta, enemy.brain_time)
			var old := enemy.pos
			enemy.pos = WorldArena.move_straight(enemy.pos, enemy.attack_direction * RUNNER_SPEED * travel_time, enemy.radius)
			var touch := enemy.radius + PlayerState.RADIUS
			if _segment_distance_squared(sim.player.pos, old, enemy.pos) <= touch * touch:
				_hurt(sim, enemy, enemy.damage * 1.25, &"runner_dash", enemy.attack_direction)
			enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
			if enemy.brain_time <= 0.0:
				_enter(enemy, &"recover", RUNNER_RECOVER)
		&"recover":
			enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
			if enemy.brain_time <= 0.0:
				_enter(enemy, &"approach", 0.0)
		_:
			var offset := sim.player.pos - enemy.pos
			if offset.length_squared() <= RUNNER_TRIGGER * RUNNER_TRIGGER:
				_lock(enemy, sim.player.pos)
				_enter(enemy, &"warn", RUNNER_WARN)
			else:
				enemy.attack_direction = offset.normalized()
				_walk(enemy, enemy.attack_direction, enemy.speed * 0.85, delta)


static func _brute(sim: Sim, enemy: EnemyState, delta: float) -> void:
	match enemy.brain_state:
		&"warn":
			enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
			if enemy.brain_time <= 0.0:
				_enter(enemy, &"slam", BRUTE_SLAM)
				if in_slam(enemy, sim.player.pos, PlayerState.RADIUS):
					_hurt(sim, enemy, enemy.damage * 1.5, &"brute_slam", enemy.attack_direction)
		&"slam":
			if in_slam(enemy, sim.player.pos, PlayerState.RADIUS):
				_hurt(sim, enemy, enemy.damage * 1.5, &"brute_slam", enemy.attack_direction)
			enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
			if enemy.brain_time <= 0.0:
				_enter(enemy, &"recover", BRUTE_RECOVER)
		&"recover":
			enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
			if enemy.brain_time <= 0.0:
				_enter(enemy, &"approach", 0.0)
		_:
			var offset := sim.player.pos - enemy.pos
			if offset.length_squared() <= pow(BRUTE_REACH + 42.0, 2.0):
				_lock(enemy, sim.player.pos)
				_enter(enemy, &"warn", BRUTE_WARN)
			else:
				enemy.attack_direction = offset.normalized()
				_walk(enemy, enemy.attack_direction, enemy.speed, delta)


static func _silencer(sim: Sim, enemy: EnemyState, delta: float) -> void:
	if enemy.brain_state == &"seal":
		enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
		if enemy.brain_time <= 0.0:
			_enter(enemy, &"recover", 0.9)
		return
	if enemy.brain_state == &"recover":
		enemy.brain_time = maxf(0.0, enemy.brain_time - delta)
		if enemy.brain_time <= 0.0:
			_enter(enemy, &"approach", 0.0)
		return
	var offset := sim.player.pos - enemy.pos
	var distance := offset.length()
	if distance <= 410.0 and enemy.attack_tick <= 0.0 and sim.enemy_zones.size() < MAX_ZONES:
		_lock(enemy, sim.player.pos)
		_enter(enemy, &"seal", EnemyZone.WARNING_TIME)
		enemy.attack_tick = 4.8
		var zone := EnemyZone.new()
		zone.source_uid = enemy.uid
		zone.pos = enemy.attack_target
		zone.damage = enemy.damage * 0.65
		sim.enemy_zones.append(zone)
		sim.world_event.emit({"kind": &"seal_stamp", "pos": zone.pos})
		return
	if distance > 350.0:
		_walk(enemy, offset.normalized(), enemy.speed, delta)
	elif distance < 220.0:
		_walk(enemy, -offset.normalized(), enemy.speed * 0.8, delta)
	enemy.attack_direction = offset.normalized() if offset != Vector2.ZERO else enemy.attack_direction


static func _warden(sim: Sim, enemy: EnemyState, delta: float) -> void:
	var desired := (sim.player.pos - enemy.pos).normalized()
	if desired != Vector2.ZERO:
		var turn := clampf(angle_difference(enemy.attack_direction.angle(), desired.angle()),
			-WARDEN_TURN_SPEED * delta, WARDEN_TURN_SPEED * delta)
		enemy.attack_direction = enemy.attack_direction.rotated(turn).normalized()
	_walk(enemy, enemy.attack_direction, enemy.speed, delta)
	_contact(sim, enemy)


static func step_zones(sim: Sim, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var keep := 0
	for zone in sim.enemy_zones:
		var active_delta := delta
		if zone.warning > 0.0:
			active_delta = maxf(0.0, delta - zone.warning)
			zone.warning = maxf(0.0, zone.warning - delta)
		if active_delta > 0.0 and zone.active > 0.0:
			zone.active = maxf(0.0, zone.active - active_delta)
			zone.tick = maxf(0.0, zone.tick - active_delta)
			if zone.is_active() and zone.tick <= 0.0:
				if zone.contains(sim.player.pos, PlayerState.RADIUS) and sim.player.iframes <= 0.0:
					sim._hurt_player(zone.damage, &"silencer", &"seal", sim.player.pos,
						(sim.player.pos - zone.pos).normalized(), true, zone.source_uid)
				for unit in sim.support_units.duplicate():
					if zone.contains(unit["pos"], SupportSystem.UNIT_RADIUS):
						SupportSystem.damage(sim, int(unit["uid"]), zone.damage)
				zone.tick = EnemyZone.HIT_INTERVAL
		if zone.active > 0.0:
			sim.enemy_zones[keep] = zone
			keep += 1
	sim.enemy_zones.resize(keep)


static func echo_is_sealed(sim: Sim, position: Vector2) -> bool:
	for zone in sim.enemy_zones:
		if zone.contains(position):
			return true
	return false


static func in_slam(enemy: EnemyState, point: Vector2, radius: float = 0.0) -> bool:
	var offset := point - enemy.pos
	if offset.length_squared() > pow(BRUTE_REACH + radius, 2.0):
		return false
	if offset.length_squared() <= pow(enemy.radius + radius, 2.0):
		return true
	var allowance := asin(clampf(radius / maxf(radius + 0.01, offset.length()), 0.0, 1.0))
	return absf(angle_difference(enemy.attack_direction.angle(), offset.angle())) <= BRUTE_HALF_ANGLE + allowance


static func attack_profile(enemy: EnemyState) -> Dictionary:
	if enemy == null or enemy.def == null:
		return {"visible": false}
	if enemy.def.is_boss:
		var kind: StringName = {&"foreman": &"press", &"collector": &"dash", &"paradox": &"cross"}.get(enemy.def.id, &"press")
		return {"visible": enemy.brain_state in [&"warn", &"dash", &"slam"],
			"warning": enemy.brain_state == &"warn", "active": enemy.brain_state in [&"dash", &"slam"],
			"kind": kind, "origin": enemy.pos, "target": enemy.attack_target,
			"direction": enemy.attack_direction, "radius": 112.0 if kind == &"press" else 34.0,
			"reach": (580.0 * enemy.brain_time if enemy.brain_state == &"dash" else 377.0) if kind == &"dash" else 205.0, "half_angle": BRUTE_HALF_ANGLE,
			"progress": 1.0 - clampf(enemy.brain_time / (0.95 if kind == &"dash" else 1.1), 0.0, 1.0)}
	var warning := enemy.brain_state == &"warn"
	var active := enemy.brain_state in [&"dash", &"slam"]
	var kind := &"dash" if enemy.def.id == &"runner" else &"slam"
	var duration := RUNNER_WARN if kind == &"dash" else BRUTE_WARN
	return {"visible": (warning or active) and enemy.def.id in [&"runner", &"brute"],
		"warning": warning, "active": active, "kind": kind,
		"origin": enemy.pos, "direction": enemy.attack_direction,
		"target": enemy.attack_target, "radius": enemy.radius,
		"reach": RUNNER_SPEED * (enemy.brain_time if active else RUNNER_DASH) if kind == &"dash" else BRUTE_REACH,
		"half_angle": BRUTE_HALF_ANGLE, "progress": 1.0 - clampf(enemy.brain_time / duration, 0.0, 1.0)}


static func _lock(enemy: EnemyState, target: Vector2) -> void:
	enemy.attack_target = target
	var direction := (target - enemy.pos).normalized()
	if direction != Vector2.ZERO:
		enemy.attack_direction = direction


static func _enter(enemy: EnemyState, state: StringName, duration: float) -> void:
	enemy.brain_state = state
	enemy.brain_time = duration


static func _walk(enemy: EnemyState, direction: Vector2, speed: float, delta: float) -> void:
	var travel := direction * speed * delta
	var next := WorldArena.move_body(enemy.pos, travel, enemy.radius)
	if travel.length_squared() > 0.01 and enemy.pos.distance_squared_to(next) < travel.length_squared() * 0.2:
		var side := Vector2(-direction.y, direction.x) * (1.0 if enemy.uid % 2 == 0 else -1.0)
		next = WorldArena.move_body(enemy.pos, side * speed * delta, enemy.radius)
	enemy.pos = next


static func _contact(sim: Sim, enemy: EnemyState) -> void:
	var touch := enemy.radius + PlayerState.RADIUS
	if sim.player.pos.distance_squared_to(enemy.pos) <= touch * touch:
		_hurt(sim, enemy, enemy.damage, &"contact", (sim.player.pos - enemy.pos).normalized())


static func _hurt(sim: Sim, enemy: EnemyState, amount: float, effect: StringName, direction: Vector2) -> void:
	if sim.player.iframes <= 0.0:
		sim._hurt_player(amount, enemy.def.id, effect, sim.player.pos, direction, true, enemy.uid)


static func _segment_distance_squared(point: Vector2, from: Vector2, to: Vector2) -> float:
	var offset := to - from
	var weight := clampf((point - from).dot(offset) / offset.length_squared(), 0.0, 1.0) \
		if offset.length_squared() > 0.0001 else 0.0
	return point.distance_squared_to(from + offset * weight)
