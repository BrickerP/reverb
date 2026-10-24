extends RefCounted


func _sim(held_index: int) -> Sim:
	var sim := Sim.new(699)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.wave = 6
	sim.player.materials = 1000
	sim.shop.offers.clear()
	for id: StringName in [&"pistol", &"shotgun", &"rifle", &"orb"]:
		var offer := Offer.new()
		offer.weapon = Content.weapon(id)
		offer.price = 37
		sim.shop.offers.append(offer)
	var held := sim.shop.offers.pop_front() as Offer
	sim.shop.offers.insert(held_index, held)
	sim.shop.toggle_lock(sim, held)
	return sim


func _ids(sim: Sim) -> Array[String]:
	var ids: Array[String] = []
	for offer in sim.shop.offers:
		ids.append(String(offer.id()))
	ids.sort()
	return ids


func test_nonzero_hold_slot_survives_reroll_and_next_shop(c: Check) -> void:
	for index in [1, 2, 3]:
		var sim := _sim(index)
		var held := sim.shop.locked_offer()
		var price := held.price
		c.ok(sim.shop.reroll(sim), "reroll succeeds")
		c.eq(sim.shop.offers.find(held), index, "reroll preserves the exact held card position")
		c.eq(held.price, price, "reroll preserves the held price")
		c.ok(held.locked and not held.sold, "held card remains live and locked")
		c.eq(sim.shop.offers.size(), Shop.OFFER_COUNT, "reroll preserves card count")
		c.eq(_ids(sim).count(String(held.id())), 1, "held card does not duplicate")
		sim.wave += 1
		sim.shop.roll(sim)
		c.eq(sim.shop.offers.find(held), index, "next shop preserves the same object and position")
		c.eq(held.price, price, "next shop keeps the original held price")
		c.ok(held.locked, "next shop preserves the lock")
		c.eq(sim.shop.offers.size(), Shop.OFFER_COUNT, "next shop preserves card count")


func test_hold_position_does_not_change_generated_offers_or_rng(c: Check) -> void:
	var first := _sim(0)
	var last := _sim(3)
	first.shop.reroll(first)
	last.shop.reroll(last)
	c.eq(first.rng.state, last.rng.state, "position preservation consumes no extra randomness")
	c.eq(_ids(first), _ids(last), "the same held item produces the same generated offers")
	c.eq(first.player.materials, last.player.materials, "position does not change refresh cost")
