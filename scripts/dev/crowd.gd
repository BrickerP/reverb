class_name Crowd
extends RefCounted
# Dev-only stress scenario: unkillable enemies, and a heavy piercing loadout on the player and four echoes.


static func build(count: int, chase: bool) -> Sim:
	var sim := Sim.new(7)
	equip(sim)
	sim.start_run()
	fill(sim, count, chase)
	return sim


# Call before a wave starts: the echoes are created from the bank when the wave begins.
static func equip(sim: Sim) -> void:
	var gun := WeaponDef.new()
	gun.id = &"stress"
	gun.damage = 1.0
	gun.cooldown = 0.1
	gun.reach = 480.0
	gun.projectile_speed = 400.0
	gun.projectile_radius = 5.0
	gun.pierce = 99
	gun.knockback = 0.0
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for _w in Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(gun)
	sim.player.stats.values[Stats.MAX_HP] = 1.0e9
	sim.player.hp = 1.0e9
	sim.player.stats.values[Stats.ECHO_SLOTS] = 4.0
	for k in 4:
		var take := EchoTake.new()
		take.wave = k + 1
		take.weapons = sim.player.weapons.duplicate()
		take.levels = sim.player.weapon_levels.duplicate()
		take.stats = sim.player.stats.copy()
		var path := PackedVector2Array()
		for s in 300:
			path.append(Sim.ARENA.get_center() + Vector2.from_angle(float(s) * 0.04 + float(k)) * (60.0 + 50.0 * float(k)))
		take.samples = path
		sim.bank.add(take)


# Call after a wave has started: starting a wave clears the arena.
static func fill(sim: Sim, count: int, chase: bool) -> void:
	sim.wave_duration = 1.0e9
	var def := Content.enemies()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var box := Sim.ARENA.grow(-30.0)
	for i in count:
		var e := EnemyState.new()
		e.uid = 100000 + i
		e.def = def
		e.pos = Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		e.max_hp = 1.0e9
		e.hp = e.max_hp
		e.speed = def.speed if chase else 0.0
		e.damage = 0.0
		e.radius = def.radius
		sim.enemies.append(e)
