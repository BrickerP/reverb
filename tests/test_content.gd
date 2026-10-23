extends RefCounted


func test_weapons_are_sane(c: Check) -> void:
	c.ok(Content.weapon(Content.STARTER_WEAPON) != null, "starter weapon exists")
	c.ok(Content.weapons().size() >= 5, "at least five weapons")
	var families := {}
	for id: StringName in Content.weapons():
		var w := Content.weapon(id)
		c.eq(w.id, id, "%s: registry key matches id" % id)
		c.ok(w.damage > 0.0 and w.cooldown > 0.0 and w.reach > 0.0, "%s: positive combat numbers" % id)
		c.ok(w.projectile_speed > 0.0 and w.projectile_radius > 0.0, "%s: positive projectile numbers" % id)
		c.ok(w.pellets >= 1 and w.pierce >= 0 and w.price > 0, "%s: pellets, pierce, price" % id)
		c.ok(not str(w.family).is_empty(), "%s: weapon family" % id)
		if w.drops:
			families[w.family] = int(families.get(w.family, 0)) + 1
		c.ok(str(w.rarity) in ["common", "uncommon", "rare", "evolved"], "%s: known rarity" % id)
		if w.drops:
			c.ok(w.drop_weight > 0.0, "%s: drop weight" % id)
		else:
			c.eq(w.drop_weight, 0.0, "%s: evolved form does not drop" % id)
		if w.evolves_to != &"":
			var evolved := Content.weapon(w.evolves_to)
			c.ok(evolved != null, "%s: evolution target exists" % id)
			if evolved != null:
				c.eq(evolved.family, w.family, "%s: evolution keeps family" % id)
				c.ok(not evolved.drops, "%s: evolved form is not a drop" % id)
				c.eq(evolved.evolves_to, &"", "%s: evolution is one step" % id)
		if w.explosion_radius > 0.0:
			c.ok(w.explosion_damage > 0.0, "%s: explosion has damage" % id)
		if w.homing_turn > 0.0:
			c.ok(w.projectile_speed > 0.0, "%s: homing projectile moves" % id)
		c.ok(w.dps() > 5.0 and w.dps() < 40.0, "%s: dps in a sane band (%s)" % [id, w.dps()])
	for family in [&"sidearm", &"scatter", &"marksman", &"arcane"]:
		c.ok(int(families.get(family, 0)) >= 2, "%s: at least two base weapons" % family)


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
		if e.death_radius > 0.0:
			c.ok(e.death_damage > 0.0, "%s: death explosion has damage" % e.id)
		if e.min_wave == 1:
			first_wave += 1
	c.ok(first_wave >= 1, "something can spawn on wave 1")


func test_characters_apply_to_a_run(c: Check) -> void:
	var loop := Content.character(&"looper")
	c.ok(loop != null, "looper exists")
	var a := Sim.new(1)
	loop.apply(a)
	c.eq(a.echo_capacity(), 3, "looper gets a third echo slot")
	c.near(a.echo_power(), 0.4, 0.001, "looper echoes are weaker")
	c.near(a.player.stats.damage_mult(), 1.0, 0.001, "looper keeps full personal damage")
	var solo := Content.character(&"solo")
	c.ok(solo != null, "solo exists")
	var b := Sim.new(1)
	solo.apply(b)
	c.eq(b.echo_capacity(), 0, "solo has no echoes")
	c.near(b.player.max_hp(), 55.0, 0.001, "solo gets extra health")
	c.near(b.player.stats.damage_mult(), 1.6, 0.001, "solo gets personal damage")


func test_mirror_uses_the_current_build(c: Check) -> void:
	var s := Sim.new(1)
	Content.character(&"mirror").apply(s)
	c.ok(s.live_echo, "mirror echoes are live")
	c.eq(s.echo_capacity(), 2, "two slots")
	c.near(s.echo_power(), 0.4, 0.001, "forty percent power")
	var take := EchoTake.new()
	take.weapons.append(Content.weapon(&"pistol"))
	s.player.weapons.clear()
	s.player.add_weapon(Content.weapon(&"rifle"))
	c.near(s.echo_dps(take), Content.weapon(&"rifle").dps() * 0.4, 0.001,
			"live echoes value the current weapon, not the snapshot")


func test_solo_does_not_record_takes(c: Check) -> void:
	var s := Sim.new(1)
	Content.character(&"solo").apply(s)
	s.start_run()
	s.wave_duration = 0.001
	s.step(0.01, Vector2.ZERO)
	c.eq(s.phase, Sim.Phase.SHOP, "wave ended")
	c.eq(s.bank.takes.size(), 0, "no take is recorded without echo slots")
