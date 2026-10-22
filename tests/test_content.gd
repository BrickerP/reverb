extends RefCounted


func test_weapons_are_sane(c: Check) -> void:
	c.ok(Content.weapon(Content.STARTER_WEAPON) != null, "starter weapon exists")
	c.ok(Content.weapons().size() >= 5, "at least five weapons")
	for id: StringName in Content.weapons():
		var w := Content.weapon(id)
		c.eq(w.id, id, "%s: registry key matches id" % id)
		c.ok(w.damage > 0.0 and w.cooldown > 0.0 and w.reach > 0.0, "%s: positive combat numbers" % id)
		c.ok(w.projectile_speed > 0.0 and w.projectile_radius > 0.0, "%s: positive projectile numbers" % id)
		c.ok(w.pellets >= 1 and w.pierce >= 0 and w.price > 0, "%s: pellets, pierce, price" % id)
		c.ok(w.dps() > 5.0 and w.dps() < 40.0, "%s: dps in a sane band (%s)" % [id, w.dps()])


func test_items_only_touch_known_stats(c: Check) -> void:
	c.ok(Content.items().size() >= 8, "at least eight items")
	var echo_items := 0
	for id: StringName in Content.items():
		var it := Content.item(id)
		c.eq(it.id, id, "%s: registry key matches id" % id)
		c.ok(not it.mods.is_empty() and it.price > 0, "%s: has mods and a price" % id)
		for stat: StringName in it.mods:
			c.ok(Stats.DEFAULTS.has(stat), "%s: stat %s exists" % [id, stat])
		if it.echo_item:
			echo_items += 1
	c.ok(echo_items >= 3, "echo-specific items exist")


func test_enemy_roster(c: Check) -> void:
	var ids := {}
	var first_wave := 0
	for e in Content.enemies():
		c.ok(not ids.has(e.id), "%s: unique id" % e.id)
		ids[e.id] = true
		c.ok(e.hp > 0.0 and e.speed > 0.0 and e.damage > 0.0 and e.radius > 0.0, "%s: positive stats" % e.id)
		if e.is_boss:
			c.ok(e.cost >= 0.0 and e.weight >= 0.0 and e.drop >= 1 and e.min_wave >= 1, "%s: boss spawn data" % e.id)
		else:
			c.ok(e.cost > 0.0 and e.weight > 0.0 and e.drop >= 1 and e.min_wave >= 1, "%s: spawn data" % e.id)
		c.ok(e.radius <= Sim.MAX_ENEMY_RADIUS, "%s: fits the spatial grid query" % e.id)
		if e.min_wave == 1:
			first_wave += 1
	c.ok(first_wave >= 1, "something can spawn on wave 1")
