extends RefCounted


func _offer(id: StringName, price: int = 10) -> Offer:
	var o := Offer.new()
	o.weapon = Content.weapon(id)
	o.price = price
	return o


func _shop_sim() -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = 100
	s.shop.offers.clear()
	s.shop.offers.append(_offer(&"pistol", 10))
	s.shop.offers.append(_offer(&"smg", 20))
	s.shop.offers.append(_offer(&"shotgun", 30))
	s.shop.offers.append(_offer(&"rifle", 40))
	return s


func test_only_one_offer_stays_locked(c: Check) -> void:
	var s := _shop_sim()
	c.ok(s.shop.toggle_lock(s, s.shop.offers[0]), "first lock succeeds")
	c.ok(s.shop.offers[0].locked, "first offer locked")
	c.ok(s.shop.toggle_lock(s, s.shop.offers[1]), "second lock succeeds")
	c.ok(not s.shop.offers[0].locked, "locking another moves the hold")
	c.ok(s.shop.offers[1].locked, "second offer is the only lock")
	c.ok(s.shop.toggle_lock(s, s.shop.offers[1]), "unlock succeeds")
	c.ok(not s.shop.offers[1].locked, "unlock clears the hold")


func test_lock_survives_reroll_and_the_next_shop(c: Check) -> void:
	var s := _shop_sim()
	var held := s.shop.offers[1]
	c.ok(s.shop.toggle_lock(s, held), "lock held offer")
	var cost := s.shop.reroll_cost(s.wave)
	s.player.materials = cost + 100
	c.ok(s.shop.reroll(s), "reroll succeeds")
	c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "reroll still fills four offers")
	c.ok(s.shop.offers.has(held), "reroll keeps the exact held offer")
	c.ok(held.locked, "held offer stays locked")
	c.ok(s.shop.locked_offer() == held, "the held offer is discoverable")
	s.player.materials = 100
	s.shop.roll(s)
	c.eq(s.shop.offers.size(), Shop.OFFER_COUNT, "the next shop fills four offers")
	c.ok(s.shop.offers.has(held), "the next shop keeps the hold")
	c.ok(held.locked, "the next shop preserves the flag")


func test_sold_offers_cannot_be_locked_and_state_restores(c: Check) -> void:
	var s := _shop_sim()
	s.shop.offers[0].sold = true
	c.ok(not s.shop.toggle_lock(s, s.shop.offers[0]), "sold offer cannot lock")
	c.ok(s.shop.toggle_lock(s, s.shop.offers[1]), "live offer can lock")
	var before := ShopState.capture(s)
	c.ok(s.shop.toggle_lock(s, s.shop.offers[1]), "unlock for restore test")
	c.ok(not s.shop.offers[1].locked, "unlocked before restore")
	before.restore(s)
	c.ok(s.shop.offers[1].locked, "state restore brings the hold back")
	c.ok(s.shop.offers[0].sold, "state restore keeps the sold flag")
