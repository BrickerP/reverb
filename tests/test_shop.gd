extends RefCounted


func _shop_sim(materials: int = 1000) -> Sim:
	var s := Sim.new(3)
	s.start_run()
	s.wave_duration = 0.05
	s.player.stats.add(Stats.MAX_HP, 100000.0)
	s.player.hp = s.player.max_hp()
	for i in 5:
		s.step(1.0 / 60.0, Vector2.ZERO)
	s.player.materials = materials
	return s


func _item_offer(id: StringName, price: int) -> Offer:
	var o := Offer.new()
	o.item = Content.item(id)
	o.price = price
	return o


func test_family_combo_thresholds(c: Check) -> void:
	var weapons: Array[WeaponDef] = []
	var pistol := Content.weapon(&"pistol")
	weapons.append(pistol)
	c.near(Combat.family_damage_mult(weapons, &"sidearm"), 1.0, 0.001, "one piece has no bonus")
	weapons.append(pistol)
	c.near(Combat.family_damage_mult(weapons, &"sidearm"), 1.03, 0.001, "two pieces add damage")
	weapons.append(pistol)
	weapons.append(pistol)
	c.near(Combat.family_cooldown_mult(weapons, &"sidearm"), 0.97, 0.001, "four pieces add speed")
	weapons.append(pistol)
	weapons.append(pistol)
	c.near(Combat.family_damage_mult(weapons, &"sidearm"), 1.0609, 0.001, "six pieces add master damage")


func test_weapon_upgrade_spends_materials_and_caps(c: Check) -> void:
	var s := _shop_sim()
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.add_weapon(Content.weapon(&"pistol"))
	var w := s.player.weapons[0]
	var cost := Shop.upgrade_cost(w, 0)
	s.player.materials = cost
	c.ok(s.shop.upgrade_weapon(s, 0), "first upgrade succeeds")
	c.eq(s.player.level_at(0), 1, "weapon level went up")
	c.eq(s.player.materials, 0, "upgrade spent materials")
	c.ok(not s.shop.upgrade_weapon(s, 0), "cannot upgrade without materials")
	s.player.materials = 10000
	for i in WeaponDef.MAX_LEVEL:
		s.shop.upgrade_weapon(s, 0)
	c.eq(s.player.level_at(0), WeaponDef.MAX_LEVEL, "level capped")
	c.ok(not s.shop.upgrade_weapon(s, 0), "max level refuses further upgrades")


func test_weapon_evolution_requires_level_and_family(c: Check) -> void:
	var s := _shop_sim()
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	for i in 3:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	var cost := Shop.evolution_cost(s.player.weapons[0])
	s.player.materials = cost
	c.eq(Shop.evolution_block_reason(s, 0), &"", "max level + three sidearms qualifies")
	c.ok(s.shop.evolve_weapon(s, 0), "evolution succeeds")
	c.eq(s.player.weapons[0].id, &"twin_fangs", "weapon becomes the evolved form")
	c.eq(s.player.level_at(0), 0, "evolved weapon starts at level 1")
	c.eq(s.player.materials, 0, "evolution spends materials")


func test_weapon_evolution_rejects_low_family_count(c: Check) -> void:
	var s := _shop_sim()
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	for i in 2:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	s.player.materials = 1000
	c.eq(Shop.evolution_block_reason(s, 0), &"family", "two sidearms are not enough")
	c.ok(not s.shop.evolve_weapon(s, 0), "low family count refuses evolution")


func test_roll_is_unique_and_priced_by_wave(c: Check) -> void:
	var s := _shop_sim()
	s.wave = 5
	for r in 20:
		s.shop.roll(s)
		c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "four offers")
		var seen := {}
		for o in s.shop.offers:
			c.ok(not seen.has(o.id()), "offer ids are unique")
			seen[o.id()] = true
			var base: int = o.weapon.price if o.is_weapon() else o.item.price
			c.eq(o.price, int(ceil(float(base) * 1.25)), "price scales with the wave")


func test_buying_an_item_applies_it(c: Check) -> void:
	var s := _shop_sim(100)
	var o := _item_offer(&"iron_heart", 14)
	var max_hp := s.player.max_hp()
	var hp := s.player.hp
	c.ok(s.shop.buy(s, o), "purchase succeeds")
	c.eq(s.player.materials, 86, "materials deducted")
	c.near(s.player.max_hp(), max_hp + 10.0, 0.001, "max hp raised")
	c.near(s.player.hp, hp + 10.0, 0.001, "current hp raised with it")
	c.eq(s.player.item_count(&"iron_heart"), 1, "item recorded")
	c.ok(not s.shop.buy(s, o), "a sold offer cannot be bought twice")
	c.eq(s.player.materials, 86, "no double charge")


func test_buying_needs_money_and_the_shop_phase(c: Check) -> void:
	var s := _shop_sim(5)
	var o := _item_offer(&"iron_heart", 14)
	c.ok(not s.shop.buy(s, o), "too poor")
	c.eq(s.player.materials, 5, "nothing deducted")
	s.player.materials = 100
	s.start_next_wave()
	c.ok(not s.shop.buy(s, o), "cannot shop during a wave")


func test_weapon_slots_are_capped(c: Check) -> void:
	var s := _shop_sim()
	var o := Offer.new()
	o.weapon = Content.weapon(&"smg")
	o.price = 10
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS - 1:
		s.player.add_weapon(Content.weapon(&"pistol"))
	c.ok(s.shop.buy(s, o), "buys into the last free slot")
	c.eq(s.player.weapons.size(), Content.MAX_WEAPON_SLOTS, "six weapons")
	var o2 := Offer.new()
	o2.weapon = Content.weapon(&"rifle")
	o2.price = 10
	c.ok(not s.shop.buy(s, o2), "no seventh weapon")
	for r in 30:
		s.shop.roll(s)
		for offer in s.shop.offers:
			c.ok(not offer.is_weapon(), "full slots stop weapon offers")


func test_item_stack_limit(c: Check) -> void:
	var s := _shop_sim()
	var cap := Content.item(&"spare_deck").max_stack
	for i in cap:
		c.ok(s.shop.buy(s, _item_offer(&"spare_deck", 1)), "buy #%d" % (i + 1))
	c.ok(not s.shop.buy(s, _item_offer(&"spare_deck", 1)), "stack limit reached")
	c.near(s.player.stats.get_stat(Stats.ECHO_SLOTS), 2.0 + float(cap), 0.001, "echo slots raised")
	c.eq(s.echo_capacity(), 2 + cap, "capacity follows the stat")
	for r in 40:
		s.shop.roll(s)
		for offer in s.shop.offers:
			c.ok(offer.is_weapon() or offer.item.id != &"spare_deck", "maxed items are not offered")


func test_block_reason_explains_why_an_offer_is_unavailable(c: Check) -> void:
	var s := _shop_sim(100)
	var o := _item_offer(&"iron_heart", 14)
	c.eq(s.shop.block_reason(s, o), &"", "an affordable offer is open")
	s.player.materials = 5
	c.eq(s.shop.block_reason(s, o), &"poor", "too poor")
	s.player.materials = 100
	c.ok(s.shop.buy(s, o), "buy it")
	c.eq(s.shop.block_reason(s, o), &"sold", "sold")
	var deck := _item_offer(&"spare_deck", 1)
	for i in Content.item(&"spare_deck").max_stack:
		s.shop.buy(s, _item_offer(&"spare_deck", 1))
	c.eq(s.shop.block_reason(s, deck), &"maxed", "stack limit reached")
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var w := Offer.new()
	w.weapon = Content.weapon(&"smg")
	w.price = 1
	c.eq(s.shop.block_reason(s, w), &"full", "weapon slots full")


func test_reroll_costs_and_restocks(c: Check) -> void:
	var s := _shop_sim(100)
	s.wave = 6
	s.shop.roll(s)
	var first := s.shop.reroll_cost(6)
	c.eq(first, 2 + 3, "base reroll cost grows with the wave")
	var old_ids: Array[StringName] = []
	for o in s.shop.offers:
		old_ids.append(o.id())
	c.ok(s.shop.reroll(s), "reroll works")
	c.eq(s.player.materials, 100 - first, "reroll charged")
	c.eq(s.shop.reroll_cost(6), first + 2, "each reroll costs more")
	c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "restocked")
	s.player.materials = 1
	c.ok(not s.shop.reroll(s), "cannot reroll when poor")
	s.shop.roll(s)
	c.eq(s.shop.reroll_cost(6), first, "a fresh shop resets the reroll cost")


func test_replace_weapon_trades_in_the_old_one(c: Check) -> void:
	var s := _shop_sim(1000)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var o := Offer.new()
	o.weapon = Content.weapon(&"rifle")
	o.price = 34
	s.shop.offers.clear()
	s.shop.offers.append(o)
	var old := s.player.weapons[0]
	var resale := Shop.resale_value(old)
	var before := s.player.materials
	c.ok(s.shop.replace_weapon(s, o, 0), "swap succeeds")
	c.eq(s.player.weapons[0], o.weapon, "new weapon takes the slot")
	c.eq(s.player.materials, before - o.price + resale, "trade-in is deducted from the price")
	c.ok(o.sold, "offer is consumed")


func test_replace_weapon_requires_the_net_cost(c: Check) -> void:
	var s := _shop_sim(0)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	var o := Offer.new()
	o.weapon = Content.weapon(&"rifle")
	o.price = 100
	s.shop.offers.clear()
	s.shop.offers.append(o)
	var before := s.player.materials
	c.ok(not s.shop.replace_weapon(s, o, 0), "cannot afford the net cost")
	c.eq(s.player.materials, before, "materials untouched")
	c.ok(not o.sold, "offer stays")
