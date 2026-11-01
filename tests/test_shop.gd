extends RefCounted


func _shop_sim(materials: int = 1000) -> Sim:
	var s := Sim.new(3)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = materials
	return s


func _item_offer(s: Sim, id: StringName, price: int) -> Offer:
	var o := Offer.new()
	o.item = Content.item(id)
	o.price = price
	s.shop.offers.append(o)
	return o


func test_debt_repayment_quotes_partial_cost_and_undo_restores_funds_and_debt(c: Check) -> void:
	var sim := _shop_sim(13)
	sim.expedition["debt"] = 40
	sim.expedition["credit_taken"] = 1
	var before := ShopState.capture(sim).to_dict()
	var rng_before := sim.rng.state
	var quote := sim.shop.quote(ShopResult.PAY_DEBT, sim)
	c.ok(quote.ok, "existing funds permit a partial voluntary repayment")
	c.eq(quote.cost, 13, "repayment quote never exceeds funds or outstanding debt")
	c.eq(ShopState.capture(sim).to_dict(), before, "repayment quote never spends or changes history")
	var result := sim.shop.apply(ShopResult.PAY_DEBT, sim)
	c.ok(result.ok, "canonical repayment applies")
	c.eq(result.cost, quote.cost, "charged repayment matches visible quote")
	c.eq(sim.player.materials, 0, "partial repayment spends exactly the quoted funds")
	c.eq(sim.expedition["debt"], 27, "partial repayment reduces actual debt by the same amount")
	c.eq(sim.rng.state, rng_before, "financial choice never changes combat RNG")
	c.ok(sim.shop.undo(sim).ok, "repayment can be undone as one transaction")
	c.eq(ShopState.capture(sim).to_dict(), before, "one undo restores both cash and actual debt")
	sim.player.materials = 100
	c.eq(sim.shop.quote(ShopResult.PAY_DEBT, sim).cost, 40, "full repayment has no extra fee")
	c.ok(sim.shop.apply(ShopResult.PAY_DEBT, sim).ok, "debt can be cleared without Collector or audit")
	c.eq(sim.player.materials, 60, "surplus cash remains available for equipment")
	c.eq(sim.expedition["debt"], 0, "full repayment clears outstanding debt")
	c.eq(sim.expedition["credit_taken"], 1, "repayment does not erase historical borrowing")


func test_debt_repayment_rejects_no_cash_no_debt_and_combat_without_mutation(c: Check) -> void:
	var sim := _shop_sim(0)
	sim.expedition["debt"] = 40
	sim.expedition["credit_taken"] = 1
	var before := RunSnapshot.capture(sim)
	c.eq(sim.shop.quote(ShopResult.PAY_DEBT, sim).reason, &"poor", "zero cash cannot make a zero-value transaction")
	c.ok(not sim.shop.apply(ShopResult.PAY_DEBT, sim).ok, "no-cash repayment refuses apply")
	c.eq(RunSnapshot.capture(sim), before, "failed repayment does not create undo entries or change money")
	sim.player.materials = 50
	sim.expedition["debt"] = 0
	before = RunSnapshot.capture(sim)
	c.eq(sim.shop.quote(ShopResult.PAY_DEBT, sim).reason, &"debt_clear", "cleared account explains why no repayment is due")
	c.ok(not sim.shop.apply(ShopResult.PAY_DEBT, sim).ok, "debt-free players cannot spend on repayment")
	c.eq(RunSnapshot.capture(sim), before, "cleared account never loses funds")
	sim.expedition["debt"] = 40
	sim.phase = Sim.Phase.WAVE
	before = RunSnapshot.capture(sim)
	c.eq(sim.shop.apply(ShopResult.PAY_DEBT, sim).reason, &"invalid", "repayment is a shop action")
	c.eq(RunSnapshot.capture(sim), before, "combat cannot mutate repayment or undo history")


func test_family_combo_thresholds(c: Check) -> void:
	var weapons: Array[WeaponDef] = []
	var pistol := Content.weapon(&"pistol")
	weapons.append(pistol)
	c.near(Combat.family_damage_mult(weapons, &"sidearm"), 1.0, 0.001, "one piece has no bonus")
	weapons.append(pistol)
	c.near(Combat.family_damage_mult(weapons, &"sidearm"), 1.03, 0.001, "two pieces add damage")
	weapons.append(pistol)
	weapons.append(pistol)
	c.near(Combat.family_cooldown_mult(weapons, &"sidearm"), 0.94, 0.001, "four sidearms grant gunslinger haste")
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
	c.eq(Shop.evolution_block_reason(s, 0, &"twin_fangs"), &"", "max level + three sidearms qualifies")
	c.ok(s.shop.evolve_choice(s, 0, &"twin_fangs").ok, "evolution succeeds")
	c.eq(s.player.weapons[0].id, &"twin_fangs", "weapon becomes the evolved form")
	c.eq(s.player.level_at(0), WeaponDef.MAX_LEVEL, "evolution retains the assembled grade")
	c.eq(s.player.materials, 0, "evolution spends materials")


func test_weapon_evolution_rejects_low_family_count(c: Check) -> void:
	var s := _shop_sim()
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	for i in 2:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	s.player.materials = 1000
	c.eq(Shop.evolution_block_reason(s, 0, &"twin_fangs"), &"family", "two sidearms are not enough")
	c.ok(not s.shop.evolve_choice(s, 0, &"twin_fangs").ok, "low family count refuses evolution")


func test_roll_is_unique_and_priced_by_wave(c: Check) -> void:
	var s := _shop_sim()
	s.wave = 5
	for r in 20:
		s.shop.roll(s)
		c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "six offers")
		var seen := {}
		for o in s.shop.offers:
			c.ok(not seen.has(o.id()), "offer ids are unique")
			seen[o.id()] = true
			if o.is_contract():
				c.eq(o.price, o.contract.deposit, "work order states its purchase cost")
			else:
				var base: int = o.weapon.price if o.is_weapon() else o.item.price
				c.eq(o.price, Shop.price_for(base, s.wave), "price scales with the stage")


func test_buying_an_item_applies_it(c: Check) -> void:
	var s := _shop_sim(100)
	var o := _item_offer(s, &"iron_heart", 14)
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
	var o := _item_offer(s, &"iron_heart", 14)
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
	s.shop.offers.append(o)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS - 1:
		s.player.add_weapon(Content.weapon(&"pistol"))
	c.ok(s.shop.buy(s, o), "buys into the last free slot")
	c.eq(s.player.weapons.size(), Content.MAX_WEAPON_SLOTS, "six weapons")
	var o2 := Offer.new()
	o2.weapon = Content.weapon(&"rifle")
	o2.price = 10
	s.shop.offers.append(o2)
	c.ok(not s.shop.buy(s, o2), "no seventh weapon")
	var weapon_offers := 0
	for r in 30:
		s.shop.roll(s)
		for offer in s.shop.offers:
			if offer.is_weapon():
				weapon_offers += 1
				c.eq(s.shop.block_reason(s, offer), &"full", "weapon offers request replacement at full capacity")
	c.ok(weapon_offers > 0, "full slots retain weapon offers for replacement")


func test_item_stack_limit(c: Check) -> void:
	var s := _shop_sim()
	var cap := Content.item(&"spare_deck").max_stack
	for i in cap:
		c.ok(s.shop.buy(s, _item_offer(s, &"spare_deck", 1)), "buy #%d" % (i + 1))
	c.ok(not s.shop.buy(s, _item_offer(s, &"spare_deck", 1)), "stack limit reached")
	c.near(s.player.stats.get_stat(Stats.ECHO_SLOTS), 2.0 + float(cap), 0.001, "echo slots raised")
	c.eq(s.echo_capacity(), 2 + cap, "capacity follows the stat")
	for r in 40:
		s.shop.roll(s)
		for offer in s.shop.offers:
			c.ok(offer.is_weapon() or offer.is_contract() or offer.item.id != &"spare_deck", "maxed items are not offered")


func test_block_reason_explains_why_an_offer_is_unavailable(c: Check) -> void:
	var s := _shop_sim(100)
	var o := _item_offer(s, &"iron_heart", 14)
	c.eq(s.shop.block_reason(s, o), &"", "an affordable offer is open")
	s.player.materials = 5
	c.eq(s.shop.block_reason(s, o), &"poor", "too poor")
	s.player.materials = 100
	c.ok(s.shop.buy(s, o), "buy it")
	c.eq(s.shop.block_reason(s, o), &"sold", "sold")
	var deck := _item_offer(s, &"spare_deck", 1)
	for i in Content.item(&"spare_deck").max_stack:
		s.shop.buy(s, _item_offer(s, &"spare_deck", 1))
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
	s.player.weapon_investments[0] = 14
	var resale := Shop.resale_for(s, 0)
	var before := s.player.materials
	c.ok(s.shop.replace_weapon(s, o, 0), "swap succeeds")
	c.eq(s.player.weapons[0], o.weapon, "new weapon takes the slot")
	c.eq(s.player.materials, before - o.price + resale, "trade-in is deducted from the price")
	c.ok(o.sold, "offer is consumed")


func test_replace_weapon_refunds_half_of_upgrade_investment(c: Check) -> void:
	var s := _shop_sim(0)
	while s.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.weapon_levels[0] = 2
	s.player.weapon_investments[0] = 60
	var o := Offer.new()
	o.weapon = Content.weapon(&"rifle")
	o.price = 20
	s.shop.offers.append(o)
	var total := Shop.resale_for(s, 0)
	c.ok(total > 7, "upgrades add trade-in value")
	c.ok(s.shop.replace_weapon(s, o, 0), "swap succeeds with trade-in value")
	c.eq(s.player.materials, total - o.price, "half of upgrade spend is returned")
	c.eq(s.player.level_at(0), 0, "new weapon starts at level 1")


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


func test_shelf_refresh_does_not_draw_combat_rng(c: Check) -> void:
	var sim := _shop_sim(100)
	sim.shop.roll(sim)
	var first: Array[String] = []
	for offer in sim.shop.offers:
		first.append(String(offer.id()))
	var combat := sim.rng.state
	var hazard := sim.hazard_rng.state
	c.ok(sim.shop.reroll(sim), "refresh spends materials")
	c.eq(sim.rng.state, combat, "refresh leaves the combat RNG")
	c.eq(sim.hazard_rng.state, hazard, "refresh leaves hazard placement")
	var second: Array[String] = []
	for offer in sim.shop.offers:
		second.append(String(offer.id()))
	c.ok(second != first, "a refresh is a different shelf")
	var again := Sim.new(3)
	again.start_run()
	again.phase = Sim.Phase.SHOP
	again.shop.roll(again)
	var replay: Array[String] = []
	for offer in again.shop.offers:
		replay.append(String(offer.id()))
	c.eq(replay, first, "the same seed and wave rebuild the same shelf")


func test_final_cross_is_the_scaled_wave_twelve_hit(c: Check) -> void:
	var cross := EnemyBrain.paradox_cross_damage_at(WaveDirector.FINAL_WAVE)
	c.near(cross, Content.enemy(&"paradox").damage * WaveDirector.damage_scale(WaveDirector.FINAL_WAVE) * EnemyBrain.IMPACT_MULT,
			0.001, "wave 12 cross includes the damage scale")
	c.ok(cross > EnemyBrain.paradox_cross_damage(), "the final cross is harder than the unscaled hit")
	var hp := 35.0
	c.ok(hp - cross > 0.0 and hp - cross * 2.0 <= 0.0, "35 HP survives one final cross and dies to the second")
	var line := Loc.cross_life(hp, hp)
	c.eq(line, Loc.t("shop.life", [Loc.number(hp), Loc.number(hp), WaveDirector.FINAL_WAVE, Loc.number(cross),
			Loc.t("shop.cross_one", [Loc.number(hp - cross)])]), "35 HP is told the second cross kills")
	var sim := _shop_sim()
	sim.player.hp = sim.player.max_hp()
	var added := float(Content.item(&"iron_heart").mods[Stats.MAX_HP])
	var next_max := sim.player.max_hp() + added
	var next_hp := minf(next_max, sim.player.hp + added)
	c.ok(Loc.item_desc(Content.item(&"iron_heart"), sim).contains(Loc.cross_life(next_hp, next_max)),
			"a heart states the final cross after the purchase")


func test_evolved_weapon_staples_one_lethal_cross(c: Check) -> void:
	var cross := EnemyBrain.paradox_cross_damage_at(WaveDirector.FINAL_WAVE)
	var bare := _shop_sim()
	bare.player.stats.values[Stats.MAX_HP] = 35.0
	bare.player.hp = 35.0
	bare._hurt_player(cross, &"paradox", &"paradox_cross", bare.player.pos, Vector2.RIGHT)
	bare.player.iframes = 0.0
	bare._hurt_player(cross, &"paradox", &"paradox_cross", bare.player.pos, Vector2.RIGHT)
	c.ok(bare.player.hp <= 0.0, "35 HP dies to the second final cross")
	var armed := _shop_sim()
	armed.player.stats.values[Stats.MAX_HP] = 35.0
	armed.player.hp = 35.0
	armed.player.add_weapon(Content.weapon(&"twin_fangs"))
	armed._hurt_player(cross, &"paradox", &"paradox_cross", armed.player.pos, Vector2.RIGHT)
	c.near(armed.player.hp, 35.0 - cross, 0.001, "the first cross is not stapled")
	c.ok(not armed.cross_stapled, "a survivable cross does not spend the staple")
	armed.player.iframes = 0.0
	armed._hurt_player(cross, &"paradox", &"paradox_cross", armed.player.pos, Vector2.RIGHT)
	c.near(armed.player.hp, 1.0, 0.001, "the lethal cross stops at 1 HP")
	c.ok(armed.cross_stapled, "the staple is spent")
	var marked := RunSnapshot.capture(armed)
	armed.cross_stapled = false
	c.eq(RunSnapshot.capture(armed), marked, "the staple is not a saved field")
	armed.cross_stapled = true
	armed.player.iframes = 0.0
	armed._hurt_player(cross, &"paradox", &"paradox_cross", armed.player.pos, Vector2.RIGHT)
	c.ok(armed.player.hp <= 0.0, "a later cross is not stapled again")
	var other := _shop_sim()
	other.player.add_weapon(Content.weapon(&"twin_fangs"))
	other.player.hp = 5.0
	other._hurt_player(30.0, &"grunt", &"contact", other.player.pos, Vector2.RIGHT)
	c.ok(other.player.hp <= 0.0, "the staple ignores hits that are not the cross")
	c.ok(not other.cross_stapled, "a non-cross death does not spend the staple")
	var line := Loc.cross_life(35.0, 35.0, true)
	c.eq(line, Loc.t("shop.life", [Loc.number(35.0), Loc.number(35.0), WaveDirector.FINAL_WAVE, Loc.number(cross),
			Loc.t("shop.cross_stapled", [Loc.number(35.0 - cross)])]), "owning an evolution changes the shop sentence")
	armed.phase = Sim.Phase.SHOP
	armed.cross_stapled = true
	armed.start_next_wave()
	c.ok(not armed.cross_stapled, "the next wave has its own staple")
