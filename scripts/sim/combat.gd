class_name Combat
extends RefCounted

const PROJECTILE_MARGIN := 80.0


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


# 2 pieces: +10% damage. 4 pieces: +10% attack speed. 6 pieces: another +15% damage.
static func family_damage_mult(weapons: Array[WeaponDef], family: StringName) -> float:
	var count := family_count(weapons, family)
	var mult := 1.0
	if count >= 2:
		mult *= 1.10
	if count >= 6:
		mult *= 1.15
	return mult


static func family_cooldown_mult(weapons: Array[WeaponDef], family: StringName) -> float:
	return 0.90 if family_count(weapons, family) >= 4 else 1.0


static func step_weapons(sim: Sim, origin: Vector2, stats: Stats, weapons: Array[WeaponDef],
		levels: Array[int], cooldowns: Array[float], power_mult: float, delta: float, source: int,
		tint: Color) -> void:
	for i in weapons.size():
		cooldowns[i] -= delta
		if cooldowns[i] > 0.0:
			continue
		var w := weapons[i]
		var target := nearest_enemy(sim.enemies, origin, w.reach * stats.range_mult())
		if target == null:
			cooldowns[i] = 0.0
			continue
		cooldowns[i] += w.cooldown * stats.cooldown_mult() * family_cooldown_mult(weapons, w.family)
		var level := levels[i] if i >= 0 and i < levels.size() else 0
		fire(sim, origin, target.pos, w, level, family_damage_mult(weapons, w.family), stats,
				power_mult, source, tint)


static func fire(sim: Sim, origin: Vector2, target_pos: Vector2, w: WeaponDef, level: int,
		family_mult: float, stats: Stats, power_mult: float, source: int, tint: Color) -> void:
	var base_dir := (target_pos - origin).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var count := maxi(1, w.pellets)
	var spread := deg_to_rad(w.spread_deg)
	var reach := w.reach * stats.range_mult()
	for k in count:
		var angle := 0.0
		if count > 1:
			angle = spread * (float(k) / float(count - 1) - 0.5) + sim.rng.randf_range(-0.02, 0.02)
		elif spread > 0.0:
			angle = sim.rng.randf_range(-0.5, 0.5) * spread
		var dir := base_dir.rotated(angle)
		var p := Projectile.new()
		p.damage = w.damage * w.level_mult(level) * family_mult * stats.damage_mult() * power_mult
		if sim.rng.randf() < stats.get_stat(Stats.CRIT_CHANCE):
			p.damage *= 2.0
			p.crit = true
		p.pos = origin + dir * 14.0
		p.vel = dir * w.projectile_speed
		p.radius = w.projectile_radius
		p.pierce_left = w.pierce
		p.knockback = w.knockback
		p.life = reach / w.projectile_speed + 0.1
		p.color = w.color if source < 0 else w.color.lerp(tint, 0.55)
		p.source = source
		sim.projectiles.append(p)
	sim.shot_fired.emit(source)


static func step_projectiles(sim: Sim, delta: float) -> void:
	var bounds := Sim.ARENA.grow(PROJECTILE_MARGIN)
	var candidates: Array = []
	for p in sim.projectiles:
		p.pos += p.vel * delta
		p.life -= delta
		if p.life <= 0.0 or not bounds.has_point(p.pos):
			p.dead = true
			continue
		candidates.clear()
		sim.grid.query(p.pos, p.radius + Sim.MAX_ENEMY_RADIUS, candidates)
		for e: EnemyState in candidates:
			if e.dead:
				continue
			var reach := e.radius + p.radius
			if p.pos.distance_squared_to(e.pos) > reach * reach:
				continue
			if p.hit_uids.has(e.uid):
				continue
			sim.damage_enemy(e, p.damage, p.vel.normalized() * p.knockback, p.crit, p.source)
			if p.pierce_left > 0:
				p.pierce_left -= 1
				p.hit_uids.append(e.uid)
			else:
				p.dead = true
				break
