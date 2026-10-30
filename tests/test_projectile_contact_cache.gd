extends RefCounted


func test_cached_sort_preserves_reference_contact_order(c: Check) -> void:
	for direction in [-1.0, 1.0]:
		var sim := Sim.new(83)
		var random := RandomNumberGenerator.new()
		random.seed = 79
		var from := Vector2(700.0, 200.0) if direction < 0.0 else Vector2(300.0, 200.0)
		var to := from + Vector2(direction * 400.0, 0.0)
		for index in 96:
			var enemy := _enemy(index + 1, Vector2(random.randf_range(315.0, 685.0), random.randf_range(185.0, 215.0)))
			enemy.dead = index % 17 == 0
			sim.enemies.append(enemy)
			sim.grid.insert(enemy)
		var projectile := _projectile(from, (to - from) / 0.25)
		projectile.pierce_left = 99
		projectile.hit_uids.append(3)
		var candidates: Array = []
		sim.grid.query(from.lerp(to, 0.5), from.distance_to(to) * 0.5 + projectile.radius + Sim.MAX_ENEMY_RADIUS, candidates)
		# Independent old geometry comparator is the behavioral reference. Preserve
		# approximate ties, misses, dead bodies and pre-hit exclusion in both directions.
		candidates.sort_custom(func(a: EnemyState, b: EnemyState) -> bool:
			var at := Combat._contact_time(from, to, a.pos, a.radius + projectile.radius)
			var bt := Combat._contact_time(from, to, b.pos, b.radius + projectile.radius)
			return a.uid < b.uid if is_equal_approx(at, bt) else at < bt)
		var expected: Array[int] = []
		for enemy: EnemyState in candidates:
			if not enemy.dead and not projectile.hit_uids.has(enemy.uid) and is_finite(Combat._contact_time(from, to, enemy.pos, enemy.radius + projectile.radius)):
				expected.append(enemy.uid)
		var hits: Array[int] = []
		sim.damage_event.connect(func(info: DamageInfo) -> void: hits.append(info.target_uid))
		Combat._advance_projectile(sim, projectile, 0.25)
		c.eq(hits, expected, "cached geometry preserves every ordered hit traveling %s" % direction)
		c.eq(projectile.pos, to, "piercing flight reaches its original destination")


func test_contact_is_rechecked_after_hit_callback_moves_later_target(c: Check) -> void:
	var sim := Sim.new(84)
	var near := _enemy(2, Vector2(420.0, 200.0))
	var far := _enemy(1, Vector2(360.0, 200.0))
	sim.enemies.assign([far, near])
	for enemy in sim.enemies:
		sim.grid.insert(enemy)
	var hits: Array[int] = []
	sim.damage_event.connect(func(info: DamageInfo) -> void:
		hits.append(info.target_uid)
		if info.target_uid == near.uid:
			far.pos.y += 80.0)
	var projectile := _projectile(Vector2(500.0, 200.0), Vector2(-800.0, 0.0))
	projectile.pierce_left = 1
	Combat._advance_projectile(sim, projectile, 0.25)
	c.eq(hits, [2], "later contact uses live geometry after a hit callback")
	c.eq(far.hp, far.max_hp, "sorting cache cannot hit a target moved out of flight")
	c.eq(projectile.pos, Vector2(300.0, 200.0), "remaining piercing flight is retained")


func test_approximate_ties_and_zero_length_contacts_keep_uid_order(c: Check) -> void:
	var sim := Sim.new(85)
	for uid in [3, 1, 2]:
		var enemy := _enemy(uid, Vector2(400.0, 200.0))
		sim.enemies.append(enemy)
		sim.grid.insert(enemy)
	var hits: Array[int] = []
	sim.damage_event.connect(func(info: DamageInfo) -> void: hits.append(info.target_uid))
	var projectile := _projectile(Vector2(400.0, 200.0), Vector2.ZERO)
	projectile.pierce_left = 2
	Combat._advance_projectile(sim, projectile, 0.01)
	c.eq(hits, [1, 2, 3], "stationary overlapping contacts resolve by stable UID")
	c.ok(projectile.dead, "the third contact consumes the final non-piercing hit")


func _enemy(uid: int, position: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	for definition in Content.enemies():
		if definition.shield_arc <= 0.0:
			enemy.def = definition
			break
	enemy.uid = uid
	enemy.pos = position
	enemy.radius = 5.0
	enemy.max_hp = 10000.0
	enemy.hp = enemy.max_hp
	return enemy


func _projectile(position: Vector2, velocity: Vector2) -> Projectile:
	var projectile := Projectile.new()
	projectile.origin = position
	projectile.pos = position
	projectile.vel = velocity
	projectile.damage = 1.0
	projectile.radius = 2.0
	projectile.life = 2.0
	projectile.weapon_id = &"pistol"
	return projectile
