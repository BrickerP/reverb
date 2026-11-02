class_name Combat
extends RefCounted

const PROJECTILE_MARGIN := 80.0
const MAX_ACTIVE_FIELDS := 192
const MAX_PROJECTILES := 1200
const MAX_CHAIN_TARGETS := 8
const FAMILY_DAMAGE_2 := 1.03
const FAMILY_DAMAGE_6 := 1.03
const FAMILY_MASTERY_SIDEARM_HASTE := 0.94
const FAMILY_MASTERY_SCATTER_RANGE := 160.0
const FAMILY_MASTERY_SCATTER_DAMAGE := 1.15
const FAMILY_MASTERY_MARKSMAN_PIERCE := 1
const PIN_PRESS_DAMAGE := 0.8
const CONDUCTION_DAMAGE := 0.55
const CONDUCTION_RADIUS := 145.0


static func nearest_enemy(enemies: Array[EnemyState], from: Vector2, reach: float) -> EnemyState:
	var best: EnemyState = null
	var best_d2 := INF
	for e in enemies:
		if e.dead:
			continue
		var limit := reach + e.radius
		var d2 := from.distance_squared_to(e.pos)
		if d2 <= limit * limit and d2 < best_d2:
			best = e
			best_d2 = d2
	return best


static func family_count(weapons: Array[WeaponDef], family: StringName) -> int:
	var count := 0
	for w in weapons:
		if w.family == family:
			count += 1
	return count


static func family_damage_mult(weapons: Array[WeaponDef], family: StringName) -> float:
	var count := family_count(weapons, family)
	return (FAMILY_DAMAGE_2 if count >= 2 else 1.0) * (FAMILY_DAMAGE_6 if count >= 6 else 1.0)


static func family_cooldown_mult(weapons: Array[WeaponDef], family: StringName) -> float:
	return FAMILY_MASTERY_SIDEARM_HASTE if family == &"sidearm" and family_count(weapons, family) >= 4 else 1.0


static func family_mastery_damage(weapons: Array[WeaponDef], family: StringName, distance: float) -> float:
	return FAMILY_MASTERY_SCATTER_DAMAGE if family == &"scatter" and family_count(weapons, family) >= 4 and distance <= FAMILY_MASTERY_SCATTER_RANGE else 1.0


static func family_mastery_pierce(weapons: Array[WeaponDef], family: StringName) -> int:
	return FAMILY_MASTERY_MARKSMAN_PIERCE if family == &"marksman" and family_count(weapons, family) >= 4 else 0


# These rows describe actual status producers and consumers, including a full
# weapon inventory. They do not report a combo merely because two pieces exist.
static func combo_profile(weapons: Array[WeaponDef]) -> Array[Dictionary]:
	var pin := false
	var press := false
	var ink := false
	var arc := false
	for w in weapons:
		# Paper trees, repair stations and decoys share a family with real weapons
		# but never apply pin, press, ink or arc. Counting them marks a combo ready.
		if w.support_kind in [&"repair_station", &"paper_tree", &"decoy"]:
			continue
		pin = pin or w.pin_duration > 0.0 or (w.family == &"marksman" and family_count(weapons, &"marksman") >= 4)
		press = press or w.family == &"press"
		ink = ink or w.ink_duration > 0.0
		arc = arc or (w.family == &"arcane" and w.attack_style != &"ink")
	return [{"id": &"pin_press", "ready": pin and press,
		"need": &"pin" if not pin else (&"press" if not press else &"trigger")},
		{"id": &"ink_arc", "ready": ink and arc,
		"need": &"ink" if not ink else (&"arc" if not arc else &"trigger")}]


static func step_weapons(sim: Sim, origin: Vector2, stats: Stats, weapons: Array[WeaponDef],
		levels: Array[int], cooldowns: Array[float], power_mult: float, delta: float, source: int,
		tint: Color, extra_damage: float = 1.0, extra_cooldown: float = 1.0,
		actor_token: int = -1) -> void:
	for i in weapons.size():
		cooldowns[i] -= delta
		if cooldowns[i] > 0.0:
			continue
		var w := weapons[i]
		var target := nearest_enemy(sim.enemies, origin, w.reach * stats.range_mult())
		if target == null and w.support_kind == &"":
			cooldowns[i] = 0.0
			continue
		cooldowns[i] += w.cooldown * stats.cooldown_mult() * family_cooldown_mult(weapons, w.family) * extra_cooldown
		var level := levels[i] if i < levels.size() else 0
		var mult := family_damage_mult(weapons, w.family) * extra_damage
		mult *= family_mastery_damage(weapons, w.family, origin.distance_to(target.pos) if target != null else 0.0)
		var force_crit := source < 0 and bool(sim.player.set_bonus_applied.get(&"gunsmith", false)) and (sim.player_shots + 1) % 6 == 0
		var target_pos := target.pos if target != null else origin + Vector2.RIGHT * 44.0
		var executed := fire(sim, origin, target_pos, w, level, mult, stats, power_mult, source, tint,
			family_mastery_pierce(weapons, w.family), force_crit, actor_token,
			family_count(weapons, w.family) >= 4)
		if not executed:
			continue
		if source < 0:
			sim.player_shots += 1
		sim.shot_sequence += 1
		var info := ShotInfo.new()
		info.source = source
		info.actor_token = actor_token
		info.source_tint = tint
		info.weapon_id = w.id
		info.weapon_slot = i
		info.origin = origin
		info.direction = (target_pos - origin).normalized()
		info.target = target_pos
		info.count = maxi(1, w.pellets)
		info.level = level
		info.sequence = sim.shot_sequence
		sim.shot_fired_info.emit(info)


static func fire(sim: Sim, origin: Vector2, target_pos: Vector2, w: WeaponDef, level: int,
		family_mult: float, stats: Stats, power_mult: float, source: int, tint: Color,
		bonus_pierce: int = 0, force_crit: bool = false, actor_token: int = -1,
		mastery: bool = false) -> bool:
	var f := AttackField.new()
	f.weapon_id = w.id
	f.style = w.attack_style
	f.origin = origin
	f.pos = origin
	f.target = target_pos
	f.direction = (target_pos - origin).normalized()
	if f.direction == Vector2.ZERO:
		f.direction = Vector2.RIGHT
	f.damage = w.damage * w.level_mult(level) * family_mult * stats.damage_mult() * power_mult
	f.crit = force_crit or sim.rng.randf() < stats.get_stat(Stats.CRIT_CHANCE)
	if f.crit:
		f.damage *= 2.0
	f.knockback = w.knockback * (1.5 if mastery and w.family == &"scatter" else 1.0)
	f.reach = w.reach * stats.range_mult() * (1.2 if mastery and w.family == &"salvage" else 1.0)
	f.radius = w.mark_radius(level)
	f.width = w.line_width
	f.spread = deg_to_rad(w.spread_deg)
	f.source = source
	f.actor_token = actor_token
	f.source_tint = tint
	f.color = w.color if source < 0 else w.color.lerp(tint, 0.55)
	f.pin_duration = w.pin_duration + (0.4 if mastery and w.family == &"marksman" else 0.0)
	f.ink_duration = w.ink_duration
	f.mastery = mastery
	f.level = level
	f.windup = w.windup
	f.life = maxf(0.05, w.field_duration) * (1.35 if mastery and w.family == &"salvage" else 1.0)
	f.tick_interval = maxf(0.025, w.tick_interval)
	f.orbit_speed = w.orbit_speed
	f.orbit_radius = w.orbit_radius * stats.range_mult()
	var executed := false
	if w.support_kind != &"":
		var placement := origin + f.direction * (36.0 if w.support_kind == &"hound" else 58.0)
		executed = SupportSystem.spawn_weapon(sim, w, placement, f.damage, source, actor_token, tint, level,
			stats.cooldown_mult(), stats.range_mult())
		if executed:
			sim.shot_fired.emit(source)
		return executed
	match w.attack_style:
		&"projectile", &"pin", &"boomerang":
			executed = _projectile_volley(sim, f, w, bonus_pierce) > 0
		&"burst":
			executed = _projectile_volley(sim, f, w, bonus_pierce) > 0
			f.remaining = maxi(1, w.burst_count) - 1 + (1 if mastery and w.family == &"sidearm" else 0)
			f.tick_interval = maxf(0.025, w.burst_interval)
			f.tick_left = f.tick_interval
			f.life = f.tick_interval * float(f.remaining) + 0.1
			f.bonus_pierce = bonus_pierce
			if f.remaining > 0 and executed:
				_add_field(sim, f)
		&"cone":
			executed = true
			f.remaining = 1
			_pulse(sim, f)
			f.style = &"cone_flash"
			f.life = 0.12
			_add_field(sim, f)
		&"chain":
			executed = _chain(sim, f, target_pos, w.chain_count, w.chain_radius) > 0
		&"slam":
			f.pos = origin + f.direction * minf(f.reach, origin.distance_to(target_pos))
			f.remaining = 1
			f.life = 0.16
			executed = _add_field(sim, f)
		&"line", &"ink", &"tape", &"orbit":
			if w.attack_style in [&"ink", &"tape"]:
				f.pos = origin + f.direction * minf(f.reach, origin.distance_to(target_pos))
			f.remaining = maxi(1, int(floor(f.life / f.tick_interval)))
			executed = _add_field(sim, f)
	if executed:
		sim.shot_fired.emit(source)
	return executed


static func _add_field(sim: Sim, field: AttackField) -> bool:
	# Refuse new optional attack state at the cap; never evict another owner's
	# pending slam or increase the bound through a chain reaction.
	if sim.attack_fields.size() < MAX_ACTIVE_FIELDS:
		sim.attack_fields.append(field)
		return true
	return false


static func _projectile_volley(sim: Sim, f: AttackField, w: WeaponDef, bonus_pierce: int = 0) -> int:
	var count := maxi(1, w.pellets)
	var released := 0
	for k in count:
		if sim.projectiles.size() >= MAX_PROJECTILES:
			break
		var angle := 0.0
		if count > 1:
			angle = f.spread * (float(k) / float(count - 1) - 0.5) + sim.rng.randf_range(-0.02, 0.02)
		elif f.spread > 0.0:
			angle = sim.rng.randf_range(-0.5, 0.5) * f.spread
		var dir := f.direction.rotated(angle)
		var p := Projectile.new()
		p.pos = f.origin + dir * 14.0
		p.origin = f.origin
		p.vel = dir * w.projectile_speed
		p.damage = f.damage
		p.radius = w.projectile_radius
		p.pierce_left = w.pierce + bonus_pierce
		p.knockback = f.knockback
		p.explosion_radius = w.explosion_radius
		p.explosion_damage = w.explosion_damage
		p.homing_turn = w.homing_turn
		p.pin_duration = f.pin_duration
		p.ink_duration = f.ink_duration
		p.mastery = f.mastery
		p.return_time = w.return_time * (1.2 if f.mastery and w.family == &"salvage" else 1.0)
		p.life = f.reach / maxf(1.0, w.projectile_speed) + 0.1
		if p.return_time > 0.0:
			p.life = p.return_time * 2.2
		p.color = f.color
		p.crit = f.crit
		p.source = f.source
		p.actor_token = f.actor_token
		p.source_tint = f.source_tint
		p.weapon_id = w.id
		p.grade = f.level
		sim.projectiles.append(p)
		released += 1
	return released


static func tick_fields(sim: Sim, delta: float) -> void:
	var keep: Array[AttackField] = []
	# Fields created by a conduction pulse below join the next tick. This is an
	# iteration snapshot so nested effects never execute recursively.
	var pending_fields := sim.attack_fields.duplicate()
	sim.attack_fields.clear()
	for f: AttackField in pending_fields:
		if f.dead:
			continue
		var active_delta := delta
		if f.windup > 0.0:
			var before := f.windup
			f.windup = maxf(0.0, f.windup - delta)
			active_delta = maxf(0.0, delta - before)
			if f.windup > 0.0:
				keep.append(f)
				continue
		f.age += active_delta
		f.life -= active_delta
		f.tick_left -= active_delta
		if f.style == &"burst":
			while f.tick_left <= 0.0 and f.remaining > 0:
				var w := Content.weapon(f.weapon_id)
				if w != null:
					var released := _projectile_volley(sim, f, w, f.bonus_pierce)
					if released > 0:
						_burst_release_event(sim, f, released)
				f.remaining -= 1
				f.tick_left += f.tick_interval
		elif f.style not in [&"chain_flash", &"cone_flash"]:
			while f.tick_left <= 0.0 and f.remaining > 0:
				var current_age := f.age
				f.age = maxf(0.0, current_age + f.tick_left)
				_pulse(sim, f)
				f.age = current_age
				f.remaining -= 1
				f.tick_left += f.tick_interval
		if f.style == &"orbit":
			f.pos = f.origin + f.direction.rotated(f.age * f.orbit_speed) * f.orbit_radius
		if f.life > 0.0:
			keep.append(f)
	for f: AttackField in sim.attack_fields:
		if keep.size() < MAX_ACTIVE_FIELDS:
			keep.append(f)
	sim.attack_fields = keep


static func _pulse(sim: Sim, f: AttackField) -> void:
	var endpoint := f.origin + f.direction * f.reach
	if f.style == &"line":
		endpoint = _clear_endpoint(f.origin, endpoint, maxf(1.0, f.width * 0.5))
	if f.style == &"orbit":
		f.pos = f.origin + f.direction.rotated(f.age * f.orbit_speed) * f.orbit_radius
	for e in sim.enemies:
		if e.dead:
			continue
		var hit := false
		match f.style:
			&"cone":
				var offset := e.pos - f.origin
				hit = offset.length() <= f.reach + e.radius and (offset.length() <= e.radius or absf(f.direction.angle_to(offset)) <= f.spread * 0.5)
				if hit:
					hit = _clear_endpoint(f.origin, e.pos, 1.0).distance_squared_to(e.pos) < 1.0
			&"line":
				hit = _segment_distance_sq(f.origin, endpoint, e.pos) <= pow(e.radius + f.width * 0.5, 2.0)
			&"slam", &"ink", &"tape", &"orbit":
				hit = f.pos.distance_squared_to(e.pos) <= pow(e.radius + f.radius, 2.0)
		if hit:
			_hit(sim, e, f.damage, (e.pos - f.origin).normalized(), f.knockback,
				f.crit, f.source, f.actor_token, f.source_tint, f.weapon_id,
				f.style, f.pin_duration, f.ink_duration, f.mastery)


static func _chain(sim: Sim, f: AttackField, target_pos: Vector2, count: int, reach: float) -> int:
	var cursor := target_pos
	var from := f.origin
	var hit_uids: Array[int] = []
	for index in clampi(count, 1, MAX_CHAIN_TARGETS):
		var best: EnemyState = null
		var best_d2 := INF
		for e in sim.enemies:
			if e.dead or hit_uids.has(e.uid):
				continue
			var d2 := e.pos.distance_squared_to(cursor)
			if d2 < best_d2 and (index == 0 or d2 <= pow(reach + e.radius, 2.0)):
				best = e
				best_d2 = d2
		if best == null:
			break
		if _clear_endpoint(from, best.pos, 1.0).distance_squared_to(best.pos) > 1.0:
			break
		hit_uids.append(best.uid)
		_hit(sim, best, f.damage, (best.pos - from).normalized(), f.knockback,
			f.crit, f.source, f.actor_token, f.source_tint, f.weapon_id,
			&"chain", f.pin_duration, f.ink_duration, f.mastery)
		_chain_mark(sim, f, from, best.pos)
		from = best.pos
		cursor = best.pos
	return hit_uids.size()


static func _burst_release_event(sim: Sim, f: AttackField, count: int) -> void:
	# AttackField v4 has stable owner identity but no saved mount slot. Keep the
	# real release and its material feedback without guessing a duplicate mount.
	sim.shot_sequence += 1
	var info := ShotInfo.new()
	info.source = f.source
	info.actor_token = f.actor_token
	info.source_tint = f.source_tint
	info.weapon_id = f.weapon_id
	info.origin = f.origin
	info.direction = f.direction
	info.target = f.target
	info.count = count
	info.level = f.level
	info.sequence = sim.shot_sequence
	sim.shot_fired_info.emit(info)


static func _chain_mark(sim: Sim, owner: AttackField, from: Vector2, to: Vector2) -> void:
	var mark := AttackField.new()
	mark.style = &"chain_flash"
	mark.weapon_id = owner.weapon_id
	mark.origin = from
	mark.pos = to
	mark.target = to
	mark.direction = (to - from).normalized()
	mark.reach = from.distance_to(to)
	mark.life = 0.12
	mark.remaining = 0
	mark.source = owner.source
	mark.actor_token = owner.actor_token
	mark.source_tint = owner.source_tint
	mark.color = owner.color
	_add_field(sim, mark)


static func _segment_distance_sq(a: Vector2, b: Vector2, point: Vector2) -> float:
	var segment := b - a
	var t := clampf((point - a).dot(segment) / maxf(0.000001, segment.length_squared()), 0.0, 1.0)
	return point.distance_squared_to(a + segment * t)


static func _clear_endpoint(a: Vector2, b: Vector2, radius: float) -> Vector2:
	var steps := maxi(1, int(ceil(a.distance_to(b) / 10.0)))
	var previous := a
	for index in range(1, steps + 1):
		var sample := a.lerp(b, float(index) / float(steps))
		if WorldArena.blocks_projectile(sample, radius):
			return previous
		previous = sample
	return b


static func step_projectiles(sim: Sim, delta: float) -> void:
	for p in sim.projectiles:
		var remaining := minf(maxf(0.0, delta), p.life)
		while remaining > 0.000001 and not p.dead:
			var step := remaining
			if p.return_time > 0.0 and not p.returning:
				var outward_left := p.return_time - p.age
				if outward_left <= 0.000001:
					p.returning = true
					p.hit_uids.clear()
				else:
					step = minf(step, outward_left)
			_advance_projectile(sim, p, step)
			remaining -= step


static func _contact_time(a: Vector2, b: Vector2, point: Vector2, radius: float) -> float:
	var segment := b-a
	var length := segment.length()
	if length <= 0.000001:
		return 0.0 if a.distance_squared_to(point) <= radius*radius else INF
	var offset := point-a
	var projected := offset.dot(segment/length)
	var perpendicular_sq := maxf(0.0,offset.length_squared()-projected*projected)
	if perpendicular_sq > radius*radius:
		return INF
	var along := maxf(0.0,projected-sqrt(radius*radius-perpendicular_sq))
	if projected+sqrt(radius*radius-perpendicular_sq) < 0.0 or along > length:
		return INF
	return along/length


static func _advance_projectile(sim: Sim, p: Projectile, delta: float) -> void:
	p.age += delta
	if p.returning:
		p.vel = (p.origin-p.pos).normalized()*p.vel.length()
	elif p.homing_turn > 0.0:
		var target := nearest_enemy(sim.enemies,p.pos,220.0)
		if target != null:
			var desired := (target.pos-p.pos).normalized()
			p.vel = p.vel.rotated(clampf(p.vel.angle_to(desired),-p.homing_turn*delta,p.homing_turn*delta))
	var previous := p.pos
	var wanted := p.pos+p.vel*delta
	var home := p.returning and _segment_distance_sq(previous,wanted,p.origin) < pow(p.radius+8.0,2.0)
	if home:
		wanted = p.origin
	var destination := _clear_endpoint(previous,wanted,p.radius)
	var blocked := destination.distance_squared_to(wanted)>0.01
	p.life -= delta
	var candidates: Array = []
	var middle := previous.lerp(destination,0.5)
	sim.grid.query(middle,previous.distance_to(destination)*0.5+p.radius+Sim.MAX_ENEMY_RADIUS,candidates)
	# Grid order follows world cells, not flight direction. Resolve the earliest
	# actual circle contact first, including shots traveling left and large ticks.
	# Contact geometry is fixed during sorting. Cache it once per candidate rather
	# than repeating square roots for both operands of every sort comparison.
	# The hit loop still checks live geometry after earlier hit/explosion callbacks.
	var contact_times: Dictionary = {}
	for candidate: EnemyState in candidates:
		contact_times[candidate.uid] = _contact_time(previous, destination, candidate.pos, candidate.radius + p.radius)
	candidates.sort_custom(func(a: EnemyState,b: EnemyState)->bool:
		var at: float = contact_times[a.uid]
		var bt: float = contact_times[b.uid]
		return a.uid < b.uid if is_equal_approx(at,bt) else at < bt)
	for e: EnemyState in candidates:
		if e.dead or p.hit_uids.has(e.uid):
			continue
		var contact := _contact_time(previous,destination,e.pos,e.radius+p.radius)
		if not is_finite(contact):
			continue
		p.pos = previous.lerp(destination,contact)
		_hit(sim,e,p.damage,p.vel.normalized(),p.knockback,p.crit,
			p.source,p.actor_token,p.source_tint,p.weapon_id,p.effect,
			p.pin_duration,p.ink_duration,p.mastery,p.grade)
		if p.explosion_radius>0.0 and p.explosion_damage>0.0:
			_explode(sim,p,e)
		p.hit_uids.append(e.uid)
		if p.return_time<=0.0:
			if p.pierce_left>0:
				p.pierce_left-=1
			else:
				p.dead=true
				break
	if not p.dead:
		p.pos=destination
	if blocked or home or p.life<=0.0 or not Sim.ARENA.grow(PROJECTILE_MARGIN).has_point(p.pos):
		p.dead=true


static func _hit(sim: Sim, e: EnemyState, damage: float, direction: Vector2, knockback: float,
		crit: bool, source: int, token: int, tint: Color, weapon_id: StringName,
		effect: StringName, pin: float, ink: float, mastery: bool, grade: int = 0) -> void:
	if e.dead:
		return
	var w := Content.weapon(weapon_id)
	var family := w.family if w != null else &""
	var pinned := e.pin_left > 0.0
	var wet := e.ink_left > 0.0
	var press_combo := family == &"press" and pinned
	var arc_combo := family == &"arcane" and wet and effect not in [&"ink", &"tape"]
	e.pin_left = maxf(e.pin_left, pin)
	e.ink_left = maxf(e.ink_left, ink)
	if family == &"press" and mastery:
		e.stun_left = maxf(e.stun_left, 0.45)
	if press_combo:
		e.pin_left = 0.0
		e.stun_left = maxf(e.stun_left, 0.7)
	if arc_combo:
		e.ink_left = 0.0
	var amount := damage * (1.0 + PIN_PRESS_DAMAGE if press_combo else (1.2 if arc_combo else 1.0))
	sim.damage_enemy(e, amount, direction * knockback, crit, source, direction,
		weapon_id, effect, token, tint, grade)
	if press_combo:
		_emit_combo(sim, &"pin_press", e, source, token, tint, weapon_id, 1, damage * PIN_PRESS_DAMAGE)
	if arc_combo:
		# Conduction is a flat, bounded secondary pass. It calls damage_enemy
		# directly, so it cannot trigger another status interaction recursively.
		var affected := 1
		var bonus := damage * 0.2
		var limit := 4 if mastery else 3
		for other in sim.enemies:
			if affected > limit:
				break
			if other == e or other.dead or other.ink_left <= 0.0 or other.pos.distance_to(e.pos) > CONDUCTION_RADIUS + other.radius:
				continue
			if _clear_endpoint(e.pos, other.pos, 1.0).distance_squared_to(other.pos) > 1.0:
				continue
			other.ink_left = 0.0
			var extra := damage * CONDUCTION_DAMAGE
			sim.damage_enemy(other, extra, (other.pos - e.pos).normalized() * knockback * 0.5,
				false, source, (other.pos - e.pos).normalized(), weapon_id, &"conduction", token, tint)
			var owner := AttackField.new()
			owner.weapon_id = weapon_id
			owner.source = source
			owner.actor_token = token
			owner.source_tint = tint
			owner.color = w.color
			_chain_mark(sim, owner, e.pos, other.pos)
			affected += 1
			bonus += extra
		_emit_combo(sim, &"ink_arc", e, source, token, tint, weapon_id, affected, bonus)


static func _emit_combo(sim: Sim, id: StringName, target: EnemyState, source: int,
		token: int, tint: Color, weapon_id: StringName, affected: int, bonus: float) -> void:
	var info := ComboInfo.new()
	info.id = id
	info.source = source
	info.actor_token = token
	info.source_tint = tint
	info.weapon_id = weapon_id
	info.target_uid = target.uid
	info.pos = target.pos
	info.affected = affected
	info.bonus_damage = bonus
	sim.combo_triggered.emit(info)


static func _explode(sim: Sim, p: Projectile, primary: EnemyState) -> void:
	var candidates: Array = []
	sim.grid.query(p.pos, p.explosion_radius + Sim.MAX_ENEMY_RADIUS, candidates)
	for e: EnemyState in candidates:
		if e.dead or e.uid == primary.uid or p.pos.distance_to(e.pos) > p.explosion_radius + e.radius:
			continue
		_hit(sim, e, p.damage * p.explosion_damage, (e.pos - p.pos).normalized(),
			p.knockback, false, p.source, p.actor_token, p.source_tint, p.weapon_id,
			&"explosion", 0.0, 0.0, p.mastery)
	sim.explosion.emit(p.pos, p.explosion_radius, p.color)
	var info := ExplosionInfo.new()
	info.kind = ExplosionInfo.WEAPON
	info.source = p.source
	info.actor_token = p.actor_token
	info.source_tint = p.source_tint
	info.weapon_id = p.weapon_id
	info.pos = p.pos
	info.radius = p.explosion_radius
	info.color = p.color
	info.effect = &"weapon_explosion"
	sim.explosion_info.emit(info)


static func retirement_skill(sim: Sim, actor: EchoActor, profile: Dictionary) -> bool:
	var kind := StringName(profile["kind"])
	# A copy is the price of an accepted skill. Reject before any hit or event
	# when the required persistent state cannot be allocated.
	if kind in [&"stamp", &"ink"] and sim.attack_fields.size() >= MAX_ACTIVE_FIELDS:
		return false
	if kind == &"return" and sim.projectiles.size() >= MAX_PROJECTILES:
		return false
	var f := AttackField.new()
	f.weapon_id = StringName(profile["weapon_id"])
	f.origin = actor.pos
	f.pos = actor.pos
	f.direction = profile.get("direction", Vector2.RIGHT)
	if f.direction == Vector2.ZERO:
		f.direction = Vector2.RIGHT
	f.damage = float(profile["damage"])
	f.radius = float(profile["radius"])
	f.reach = float(profile["reach"])
	f.source = actor.index
	f.actor_token = int(profile["uid"])
	f.source_tint = profile["tint"]
	f.color = profile["tint"]
	f.knockback = 100.0
	f.life = 0.18
	match kind:
		&"pin":
			f.style = &"line"
			f.width = 30.0
			f.pin_duration = 2.0
			_pulse(sim, f)
			f.remaining = 0
			_add_field(sim, f)
			return true
		&"stamp":
			f.style = &"slam"
			f.windup = 0.3
			return _add_field(sim, f)
		&"cut":
			f.style = &"cone"
			f.spread = PI * 0.85
			_pulse(sim, f)
			f.style = &"cone_flash"
			_add_field(sim, f)
			return true
		&"ink":
			f.style = &"ink"
			f.life = 2.4
			f.tick_interval = 0.4
			f.remaining = 6
			f.damage /= 6.0
			f.ink_duration = 2.0
			return _add_field(sim, f)
		&"return":
			var p := Projectile.new()
			p.pos = actor.pos
			p.origin = actor.pos
			p.vel = f.direction * 400.0
			p.radius = 20.0
			p.damage = f.damage * 0.5
			p.return_time = f.reach / 400.0
			p.life = p.return_time * 2.2
			p.weapon_id = f.weapon_id
			p.source = f.source
			p.actor_token = f.actor_token
			p.source_tint = f.source_tint
			p.color = f.color
			p.knockback = f.knockback
			sim.projectiles.append(p)
			return true
		&"arc":
			var target := nearest_enemy(sim.enemies, actor.pos, f.reach)
			if target != null:
				_chain(sim, f, target.pos, 6, f.radius)
			return true
	return false
