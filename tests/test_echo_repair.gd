extends RefCounted


func _shop_sim(condition: float = 25.0) -> Sim:
	var sim := Sim.new(7)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	var take := EchoTake.new()
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(20, 0)])
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(1)
	take.stats = sim.player.stats.copy()
	take.condition = condition
	sim.bank.add(take)
	return sim


func test_repair_spends_materials_restores_up_to_forty_and_undoes_exactly(c: Check) -> void:
	var sim := _shop_sim()
	var take := sim.bank.takes[0]
	var before := ShopState.capture(sim)
	var rng_state := sim.rng.state
	var result := sim.shop.repair_echo(sim, take)
	c.ok(result.ok, "repair commits through the shop")
	c.eq(result.action, ShopResult.ECHO_REPAIR, "repair has its actual action type")
	c.eq(result.cost, 10, "forty condition costs ten materials")
	c.eq(take.condition, 65.0, "repair restores forty condition")
	c.eq(sim.player.materials, 10, "repair spends its exact quote")
	c.eq(sim.echo_refreshes, 1, "repair analytics counter increments")
	c.eq(sim.rng.state, rng_state, "repair does not consume the offer RNG")
	c.ok(sim.shop.undo(sim).ok, "repair is reversible")
	c.eq(ShopState.capture(sim).to_dict(), before.to_dict(), "undo restores identity, condition, counters and economy exactly")


func test_repair_only_charges_for_missing_condition_and_has_role_discount(c: Check) -> void:
	var sim := _shop_sim(95.0)
	var take := sim.bank.takes[0]
	c.eq(sim.shop.echo_repair_amount(take), 5.0, "a nearly intact copy needs only five condition")
	c.eq(sim.shop.echo_repair_cost(take, sim), 2, "cost scales with actual missing condition")
	c.ok(sim.shop.repair_echo(sim, take).ok, "partial repair commits")
	c.eq(take.condition, 100.0, "repair never exceeds full condition")
	take.condition = 50.0
	var ordinary := sim.shop.echo_repair_cost(take, sim)
	sim.repair_discount = 0.25
	c.eq(sim.shop.echo_repair_cost(take, sim), 8, "mender saves a quarter with integer rounding")
	c.ok(sim.shop.echo_repair_cost(take, sim) < ordinary, "role discount is meaningful")
	for id: StringName in [&"spare_deck", &"long_play", &"loud_speaker"]:
		sim.player.add_item(Content.item(id))
	c.eq(sim.shop.echo_repair_cost(take, sim), 6, "Echo Rig discount and role discount both apply")


func test_repair_rejects_full_poor_or_nonshop_without_history(c: Check) -> void:
	var sim := _shop_sim(100.0)
	var take := sim.bank.takes[0]
	var full := sim.shop.repair_echo(sim, take)
	c.ok(not full.ok and full.reason == &"full", "full condition cannot be purchased again")
	c.eq(full.cost, 0, "full condition has no repair charge")
	take.condition = 50.0
	sim.player.materials = 0
	var poor := sim.shop.repair_echo(sim, take)
	c.ok(not poor.ok and poor.reason == &"poor", "insufficient materials cannot repair")
	c.eq(take.condition, 50.0, "rejected transaction preserves condition")
	sim.phase = Sim.Phase.WAVE
	var invalid := sim.shop.repair_echo(sim, take)
	c.ok(not invalid.ok and invalid.reason == &"invalid", "repair is shop-only")
	c.ok(not sim.shop.can_undo(), "failed attempts create no undo entries")


func test_shop_state_restores_uid_counter_aliases_and_playback(c: Check) -> void:
	var sim := _shop_sim(55.0)
	var take := sim.bank.takes[0]
	var actor := EchoActor.new(take, 0)
	actor.t = 4.2
	actor.pos = Vector2(456, 345)
	actor.cooldowns = [0.37]
	sim.echoes = [actor]
	sim.selected_echo_uid = take.uid
	sim.retire_cooldown = 0.13
	sim.player.cooldowns = [0.72]
	var before := ShopState.capture(sim)
	c.ok(sim.shop.discard_echo(sim, take).ok, "discard commits")
	c.ok(sim.shop.undo(sim).ok, "discard restores full exact shop state")
	c.eq(ShopState.capture(sim).to_dict(), before.to_dict(), "actor clocks and player cooldowns round trip too")
	c.ok(sim.echoes[0].take == sim.bank.takes[0], "restored actor aliases its canonical bank take")
	var next := EchoTake.new()
	sim.bank.add(next)
	c.eq(next.uid, before.next_echo_uid, "next UID counter resumes exactly")


func test_full_weapon_slots_keep_replacement_offers(c: Check) -> void:
	var sim := _shop_sim()
	while sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS:
		sim.player.add_weapon(Content.weapon(&"pistol"))
	var weapon_offers := 0
	sim.shop.roll(sim)
	for offer: Offer in sim.shop.offers:
		if offer.is_weapon():
			weapon_offers += 1
			c.eq(sim.shop.block_reason(sim, offer), &"full", "full slot offer is retained for replacement")
	c.ok(weapon_offers >= 2, "full builds still guarantee real replacement weapon offers")
