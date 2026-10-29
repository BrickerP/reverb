extends RefCounted


func _sim() -> Sim:
	var sim := Sim.new(193)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 500
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	for _i in 3:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.weapon_investments.assign([14, 20, 27])
	return sim


func test_duplicate_assembly_consumes_exact_donor_preserves_cash_investment_and_undoes(c: Check) -> void:
	for host in [0, 2]:
		var sim := _sim()
		var donor := 1
		var before := ShopState.capture(sim).to_dict()
		var quote := sim.shop.combine_quote(sim, host, donor)
		c.ok(quote.ok and sim.shop.can_combine(sim, host, donor), "same id and level can assemble")
		c.ok(quote.cost < Shop.upgrade_cost(sim.player.weapons[host], 0), "cash refit deliberately costs more material than assembly")
		c.eq(ShopState.capture(sim).to_dict(), before, "assembly quote is pure")
		var paid := sim.player.weapon_investments[host] + sim.player.weapon_investments[donor] + quote.cost
		var result := sim.shop.combine_weapons(sim, host, donor)
		var kept: int = host - 1 if donor < host else host
		c.ok(result.ok, "assembly commits")
		c.eq(result.index, kept, "result identifies the host after donor removal")
		c.eq(sim.player.weapons.size(), 2, "donor is consumed and one slot is freed")
		c.eq(sim.player.level_at(kept), 1, "host gains one grade")
		c.eq(sim.player.weapon_investments[kept], paid, "all real investment follows the surviving weapon")
		c.eq(sim.player.materials, 500 - quote.cost, "assembly charges only its quoted material cost")
		c.eq(Shop.resale_for(sim, kept), floori(float(paid) * 0.5), "sale refunds real paid value rather than nominal refit costs")
		c.ok(sim.shop.undo(sim).ok, "assembly can be undone")
		c.eq(ShopState.capture(sim).to_dict(), before, "both weapons, grades, funds and ledgers restore exactly")


func test_assembly_rejects_self_mismatch_level_cap_and_poor_without_history(c: Check) -> void:
	var sim := _sim()
	c.ok(not sim.shop.can_combine(sim, 0, 0), "a weapon cannot donate to itself")
	sim.player.weapons[1] = Content.weapon(&"smg")
	c.eq(sim.shop.combine_quote(sim, 0, 1).reason, &"duplicate", "different ids cannot assemble")
	sim.player.weapons[1] = Content.weapon(&"pistol")
	sim.player.weapon_levels[1] = 1
	c.eq(sim.shop.combine_quote(sim, 0, 1).reason, &"duplicate", "grades must match")
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	sim.player.weapon_levels[1] = WeaponDef.MAX_LEVEL
	c.eq(sim.shop.combine_quote(sim, 0, 1).reason, &"maxed", "assembly never exceeds grade cap")
	sim.player.weapon_levels[0] = 0
	sim.player.weapon_levels[1] = 0
	sim.player.materials = 0
	var before := ShopState.capture(sim).to_dict()
	c.eq(sim.shop.combine_weapons(sim, 0, 1).reason, &"poor", "assembly requires quoted materials")
	c.eq(ShopState.capture(sim).to_dict(), before, "failed assembly cannot eat donor or grant value")
	c.ok(not sim.shop.can_undo(), "rejected assemblies add no undo history")


func test_refit_ledger_prevents_sale_of_free_levels_for_nominal_cash(c: Check) -> void:
	var sim := _sim()
	sim.player.weapon_investments[0] = 0
	sim.player.weapon_levels[0] = 2
	c.eq(Shop.resale_for(sim, 0), 0, "free gear and fixture grades do not invent spent cash")
	var cost := Shop.upgrade_cost(sim.player.weapons[0], 2)
	c.ok(sim.shop.apply(ShopResult.UPGRADE, sim, null, 0).ok, "expensive deterministic refit remains available")
	c.eq(sim.player.weapon_investments[0], cost, "refit records actual materials charged")
	c.eq(Shop.resale_for(sim, 0), floori(float(cost) * 0.5), "refund depends only on actual investment")


func test_evolution_requires_explicit_authored_branch_and_undoes_exactly(c: Check) -> void:
	var sim := _sim()
	sim.player.weapon_levels[0] = WeaponDef.MAX_LEVEL
	var choices := sim.shop.evolution_choices(sim, 0)
	c.eq(choices.size(), 2, "base weapon has two authored final forms")
	c.eq(sim.shop.quote(ShopResult.EVOLVE, sim, null, 0).reason, &"choice", "evolution never silently selects the first branch")
	var before := ShopState.capture(sim).to_dict()
	c.eq(sim.shop.evolve_choice(sim, 0, &"nova_core").reason, &"branch", "another family's final cannot be injected")
	c.eq(ShopState.capture(sim).to_dict(), before, "rejected branch is atomic")
	var result := sim.shop.evolve_choice(sim, 0, choices[1])
	c.ok(result.ok, "explicit second branch commits")
	c.eq(sim.player.weapons[0].id, choices[1], "chosen final becomes equipped")
	c.eq(sim.player.level_at(0), WeaponDef.MAX_LEVEL, "branch transformation preserves the assembled maximum grade")
	c.eq(result.target_id, choices[1], "transaction identifies selected branch")
	c.eq(sim.player.weapon_investments[0], 14 + result.cost, "evolution retains paid family investment")
	c.ok(sim.shop.undo(sim).ok, "evolution reverses")
	c.eq(ShopState.capture(sim).to_dict(), before, "branch, grade and paid investment restore")


func test_six_offer_mix_guarantees_real_equipment_and_two_distinct_orders_at_full_capacity(c: Check) -> void:
	var sim := _sim()
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	for wave in [1, 5, 10, 11]:
		sim.wave = wave
		for _roll in 12:
			sim.shop.roll(sim)
			var kinds := {"weapon": 0, "item": 0, "order": 0}
			var ids: Array[StringName] = []
			var total_price := 0
			for offer in sim.shop.offers:
				var kind := "weapon" if offer.is_weapon() else ("order" if offer.is_contract() else "item")
				kinds[kind] += 1
				c.ok(not ids.has(offer.id()), "all six offer identities differ")
				ids.append(offer.id())
				total_price += offer.price
				if offer.is_weapon():
					c.eq(sim.shop.block_reason(sim, offer), &"full", "full weapon slots still receive replacement offers")
			c.eq(kinds, {"weapon": 2, "item": 2, "order": 2}, "six stock cards contain exactly two of each meaningful category")
			c.ok(total_price > 24 + 6 * wave, "one encounter income cannot buy the entire six-offer shelf")
			c.eq(sim.shop.next_reroll_cost(wave), sim.shop.reroll_cost(wave) + 2, "next refresh cost is explicit without mutating quote")


func test_shop_state_roundtrips_echo_traits_role_and_support_state(c: Check) -> void:
	var sim := _sim()
	var take := EchoTake.new()
	take.samples = PackedVector2Array([Vector2(100, 100), Vector2(200, 100)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.inherited_skill = &"cut"
	take.merge_trait = &"skill"
	take.archived = true
	sim.bank.add(take)
	sim.character_id = &"mender"
	sim.character_energy = 71.0
	sim.character_cooldown = 2.4
	sim.role_effects = {"anchor": Vector2(300, 200), "nested": {"value": 2}}
	sim.support_units = [{"uid": 41, "kind": &"hound", "pos": Vector2(160, 180), "hp": 12.0}]
	sim._next_support_uid = 42
	sim.interactables = [{"id": &"recycler", "used": false, "pos": Vector2(500, 200)}]
	sim.player.shield = 6.0
	var before := ShopState.capture(sim)
	c.ok(sim.shop.apply(ShopResult.UPGRADE, sim, null, 0).ok, "transaction captures expanded state")
	sim.role_effects["nested"]["value"] = 99
	sim.support_units.clear()
	sim.character_energy = 0.0
	sim.bank.takes[0].inherited_skill = &""
	sim.player.shield = 0.0
	c.ok(sim.shop.undo(sim).ok, "expanded snapshot restores")
	c.eq(ShopState.capture(sim).to_dict(), before.to_dict(), "Echo traits, archived bit, role state, support IDs and shield restore exactly")


func test_paired_stock_from_stage_five_makes_high_grade_assembly_reachable(c: Check) -> void:
	var sim := _sim()
	sim.wave = 5
	sim.player.weapon_levels.assign([2, 2, 2])
	for _roll in 20:
		sim.shop.roll(sim)
		var paired := sim.shop.offers[0]
		var exploration := sim.shop.offers[1]
		c.eq(paired.id(), &"pistol", "first weapon stock matches the held build")
		c.eq(paired.weapon_level, 2, "stage five pairs the actual held grade")
		c.eq(paired.price, Shop.weapon_price_for(paired.weapon, 2, sim.wave), "paired quality has an actual authored price")
		c.ok(exploration.is_weapon() and exploration.id() != paired.id(), "second weapon quote explores another unique identity")
		c.eq(exploration.weapon_level, 0, "exploration weapon starts at its explicit base grade")
	var offer := sim.shop.offers[0]
	var before := ShopState.capture(sim).to_dict()
	c.ok(sim.shop.apply(ShopResult.BUY, sim, offer).ok, "same-grade donor can actually be purchased")
	c.eq(sim.player.level_at(3), 2, "purchased donor retains advertised grade")
	c.eq(sim.player.weapon_investments[3], offer.price, "quality purchase records only its true cash price")
	c.ok(sim.shop.can_combine(sim, 0, 3), "advertised matching donor reaches the assembly API")
	var fee := sim.shop.combine_quote(sim, 0, 3).cost
	c.ok(sim.shop.combine_weapons(sim, 0, 3).ok, "purchased donor raises the host to the cap")
	c.eq(sim.player.level_at(0), 3, "high-grade acquisition closes the actual assembly progression loop")
	c.eq(sim.player.weapon_investments[0], 14 + offer.price + fee, "combined cash ledger includes actual donor price without nominal refit inflation")
	c.ok(sim.shop.undo(sim).ok and sim.shop.undo(sim).ok, "assembly and purchase reverse separately")
	c.eq(ShopState.capture(sim).to_dict(), before, "quality, price, shelf and original investment restore exactly")


func test_paired_stock_stage_gate_maxed_build_and_locked_quality_are_explicit(c: Check) -> void:
	var sim := _sim()
	sim.wave = 4
	sim.player.weapon_levels.assign([2, 2, 2])
	sim.shop.roll(sim)
	c.eq(sim.shop.offers[0].id(), &"pistol", "early pairing still supports the held family")
	c.eq(sim.shop.offers[0].weapon_level, 0, "early shop only sells its advertised base grade")
	sim.wave = 5
	sim.shop.roll(sim)
	var held := sim.shop.offers[0]
	var price := held.price
	c.ok(sim.shop.toggle_lock(sim, held), "graded quote can be held")
	sim.wave = 8
	sim.shop.roll(sim)
	c.ok(sim.shop.offers[0] == held and held.weapon_level == 2, "holding preserves exact quality and quote identity")
	c.eq(held.price, price, "holding preserves the paid-price opportunity")
	sim.shop.toggle_lock(sim, held)
	sim.player.weapon_levels.assign([3, 3, 3])
	sim.shop.roll(sim)
	c.eq(sim.shop.offers.size(), 6, "a build without eligible assembly hosts still gets a complete store")
	c.eq(sim.shop.offers[0].weapon_level, 0, "completed hosts do not force useless grade-cap duplicates")


func test_offer_validation_rejects_bad_grades_and_mixed_goods_atomically(c: Check) -> void:
	var sim := _sim()
	var offer := Offer.new()
	offer.weapon = Content.weapon(&"pistol")
	offer.price = 20
	sim.shop.offers.append(offer)
	var before := ShopState.capture(sim).to_dict()
	for level in [-1, 4]:
		offer.weapon_level = level
		c.eq(sim.shop.quote(ShopResult.BUY, sim, offer).reason, &"invalid", "out-of-range advertised grade is refused")
		c.eq(sim.shop.quote(ShopResult.REPLACE, sim, offer, 0).reason, &"invalid", "replacement validates grade too")
	offer.weapon_level = 0
	offer.item = Content.item(&"iron_heart")
	c.eq(sim.shop.quote(ShopResult.BUY, sim, offer).reason, &"invalid", "a card cannot represent two goods at once")
	offer.item = null
	offer.price = -1
	c.eq(sim.shop.quote(ShopResult.BUY, sim, offer).reason, &"invalid", "negative goods price cannot mint materials")
	offer.price = 20
	c.eq(ShopState.capture(sim).to_dict(), before, "rejected malformed quotes never mutate authoritative state")
	c.ok(not sim.shop.can_undo(), "malformed offers do not create undo records")


func test_assembly_weapon_events_identify_donor_and_host_in_both_index_orders(c: Check) -> void:
	for pair: Array in [[2, 0], [0, 2]]:
		var sim := _sim()
		var host: int = pair[0]
		var donor: int = pair[1]
		var kept: int = host - 1 if donor < host else host
		var events: Array[WeaponChangeInfo] = []
		sim.weapon_changed.connect(func(info: WeaponChangeInfo) -> void: events.append(info))
		c.ok(sim.shop.combine_weapons(sim, host, donor).ok, "assembly for event attribution")
		c.eq(events.size(), 2, "assembly reports consumed donor and strengthened host separately")
		c.eq(events[0].index, donor, "donor removal identifies the original consumed slot")
		c.eq(events[0].before_id, &"pistol", "donor's previous weapon is explicit")
		c.eq(events[0].after_id, &"", "donor event removes the body")
		c.eq(events[1].index, kept, "upgrade event follows host's resulting slot")
		c.eq(events[1].before_level, 0, "host starts at advertised grade")
		c.eq(events[1].after_level, 1, "host receives exactly one grade")
		c.eq(events[1].reason, ShopResult.COMBINE, "assembly has its real transaction reason")
		c.ok(sim.shop.undo(sim).ok, "undo events for assembly")
		c.eq(events.size(), 4, "undo reports donor restoration and host rollback")
		c.eq(events[2].index, donor, "undo reinserts the original donor slot")
		c.eq(events[2].before_id, &"", "restored donor starts from empty")
		c.eq(events[2].after_id, &"pistol", "restored donor recovers its definition")
		c.eq(events[3].index, host, "undo restores host's original slot")
		c.eq(events[3].before_level, 1, "undo starts from assembled host grade")
		c.eq(events[3].after_level, 0, "undo restores the original host grade")
		c.eq(events[3].reason, ShopResult.UNDO, "undo is not misattributed as another assembly")


func test_graded_full_capacity_replacement_sale_and_assembly_use_only_real_paid_value(c: Check) -> void:
	var sim := _sim()
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.weapon_levels.assign([2, 3, 3, 3, 3, 3])
	sim.player.weapon_investments.assign([14, 20, 27, 24, 30, 32])
	sim.wave = 5
	sim.shop.roll(sim)
	var offer := sim.shop.offers[0]
	var before := ShopState.capture(sim).to_dict()
	c.eq(offer.weapon_level, 2, "full-capacity paired stock matches the only unfinished host")
	c.eq(sim.shop.quote(ShopResult.BUY, sim, offer).reason, &"full", "full build asks for replacement rather than hiding graded stock")
	var quote := sim.shop.quote(ShopResult.REPLACE, sim, offer, 5)
	c.eq(quote.cost, offer.price - 16, "replacement uses half the outgoing real32 investment")
	c.ok(sim.shop.apply(ShopResult.REPLACE, sim, offer, 5).ok, "graded replacement commits")
	c.eq(sim.player.level_at(5), 2, "replacement retains advertised donor grade")
	c.eq(sim.player.weapon_investments[5], offer.price, "replacement resets ledger to actual new purchase price")
	var purchased := ShopState.capture(sim).to_dict()
	c.ok(sim.shop.combine_weapons(sim, 0, 5).ok, "full build can consume its newly replaced matching donor")
	c.eq(sim.player.weapons.size(), 5, "assembly creates the free slot promised to a full build")
	c.ok(sim.shop.undo(sim).ok, "undo restores the purchased donor")
	c.eq(ShopState.capture(sim).to_dict(), purchased, "graded replacement state restores after assembly undo")
	var cash := sim.player.materials
	var refund := floori(float(offer.price) * 0.5)
	c.eq(sim.shop.quote(ShopResult.SELL, sim, null, 5).cost, -refund, "graded sale uses half its actual price")
	c.ok(sim.shop.apply(ShopResult.SELL, sim, null, 5).ok, "graded donor can be liquidated instead of assembled")
	c.eq(sim.player.materials, cash + refund, "sale cannot recover expensive nominal refit investment")
	c.ok(sim.shop.undo(sim).ok and sim.shop.undo(sim).ok, "sale and original replacement both undo")
	c.eq(ShopState.capture(sim).to_dict(), before, "all six original grades, investments and stock restore")
