extends RefCounted


func test_shop_state_captures_and_restores_exact_state(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.wave = 4
	s.player.materials = 120
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.cooldowns.clear()
	s.player.add_weapon(Content.weapon(&"pistol"))
	s.player.add_weapon(Content.weapon(&"shotgun"))
	s.player.weapon_levels[0] = 2
	s.player.items.clear()
	s.player.add_item(Content.item(&"iron_heart"))
	s.player.hp = 27.0
	s.shop.offers.clear()
	var weapon_offer := Offer.new()
	weapon_offer.weapon = Content.weapon(&"smg")
	weapon_offer.price = 30
	weapon_offer.sold = true
	s.shop.offers.append(weapon_offer)
	var item_offer := Offer.new()
	item_offer.item = Content.item(&"sneakers")
	item_offer.price = 12
	s.shop.offers.append(item_offer)
	s.shop.rerolls = 2

	var state := ShopState.capture(s)
	c.eq(state.to_dict()["weapons"], PackedStringArray(["pistol", "shotgun"]), "weapon ids captured")

	s.player.materials = 0
	s.player.hp = 1.0
	s.player.weapons.clear()
	s.player.weapon_levels.clear()
	s.player.items.clear()
	s.player.stats.add(Stats.MAX_HP, 50.0)
	s.shop.offers.clear()
	s.shop.rerolls = 99
	s.phase = Sim.Phase.WAVE
	s.wave = 9

	state.restore(s)
	c.eq(s.player.materials, 120, "materials restored")
	c.near(s.player.hp, 27.0, 0.001, "hp restored")
	c.eq(s.player.weapon_levels, [2, 0], "weapon levels restored")
	c.eq(s.player.item_count(&"iron_heart"), 1, "items restored")
	c.near(s.player.stats.get_stat(Stats.MAX_HP), 40.0, 0.001, "item stats restored")
	c.eq(s.shop.offers.size(), 2, "offers restored")
	c.ok(s.shop.offers[0].sold, "sold state restored")
	c.eq(s.shop.offers[1].id(), &"sneakers", "item offer restored")
	c.eq(s.shop.rerolls, 2, "rerolls restored")
	c.eq(s.phase, Sim.Phase.SHOP, "phase restored")
	c.eq(s.wave, 4, "wave restored")


func test_shop_state_restores_after_real_shop_actions(c: Check) -> void:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = 100
	s.shop.offers.clear()
	var weapon_offer := Offer.new()
	weapon_offer.weapon = Content.weapon(&"pistol")
	weapon_offer.price = 10
	s.shop.offers.append(weapon_offer)
	var before_buy := ShopState.capture(s)
	c.ok(s.shop.buy(s, weapon_offer), "weapon purchase succeeds")
	c.eq(s.player.weapons.size(), 2, "weapon added")
	c.eq(s.player.materials, 90, "materials spent")
	c.ok(s.shop.offers[0].sold, "offer marked sold")
	before_buy.restore(s)
	c.eq(s.player.weapons.size(), 1, "purchase undone")
	c.eq(s.player.materials, 100, "materials restored")
	c.ok(not s.shop.offers[0].sold, "offer sale restored")

	s.shop.offers.clear()
	var item_offer := Offer.new()
	item_offer.item = Content.item(&"iron_heart")
	item_offer.price = 10
	s.shop.offers.append(item_offer)
	s.player.materials = 100
	var before_item := ShopState.capture(s)
	c.ok(s.shop.buy(s, item_offer), "item purchase succeeds")
	c.near(s.player.max_hp(), 40.0, 0.001, "item changed max hp")
	c.near(s.player.hp, 40.0, 0.001, "item changed current hp")
	before_item.restore(s)
	c.near(s.player.max_hp(), 30.0, 0.001, "item stats undone")
	c.near(s.player.hp, 30.0, 0.001, "hp undone")
	c.eq(s.player.item_count(&"iron_heart"), 0, "item removed")

	s.player.materials = 100
	var before_upgrade := ShopState.capture(s)
	c.ok(s.shop.upgrade_weapon(s, 0), "upgrade succeeds")
	c.eq(s.player.level_at(0), 1, "level increased")
	before_upgrade.restore(s)
	c.eq(s.player.level_at(0), 0, "upgrade level undone")
	c.eq(s.player.materials, 100, "upgrade materials undone")


func test_shop_result_contract(c: Check) -> void:
	var ok := ShopResult.success(ShopResult.UPGRADE, 12, 0, &"pistol")
	c.ok(ok.ok, "success flag")
	c.eq(ok.action, ShopResult.UPGRADE, "action")
	c.eq(ok.cost, 12, "cost")
	c.eq(ok.index, 0, "slot index")
	var bad := ShopResult.failure(ShopResult.BUY, &"poor", 18, -1, &"shotgun")
	c.ok(not bad.ok, "failure flag")
	c.eq(bad.reason, &"poor", "failure reason")
	var data := bad.to_dict()
	c.eq(data["reason"], "poor", "result serializes")


func test_presentation_info_contract(c: Check) -> void:
	var shot := ShotInfo.new()
	shot.source = 2
	shot.weapon_id = &"orb"
	shot.origin = Vector2(10, 20)
	shot.direction = Vector2.RIGHT
	shot.target = Vector2(200, 20)
	shot.count = 2
	shot.level = 3
	shot.sequence = 9
	c.eq(shot.to_dict()["weapon_id"], "orb", "shot weapon id")

	var hit := DamageInfo.new()
	hit.source = 2
	hit.weapon_id = &"orb"
	hit.target_uid = 42
	hit.amount = 5.0
	hit.crit = true
	hit.reduced = true
	hit.hit_dir = Vector2.LEFT
	c.eq(hit.to_dict()["target_uid"], 42, "damage target")

	var blast := ExplosionInfo.new()
	blast.kind = ExplosionInfo.BOMBER
	blast.radius = 52.0
	c.eq(blast.to_dict()["kind"], "bomber", "explosion kind")

	var change := WeaponChangeInfo.new()
	change.index = 1
	change.before_id = &"pistol"
	change.after_id = &"twin_fangs"
	change.before_level = 3
	change.after_level = 0
	change.reason = ShopResult.EVOLVE
	change.ok = true
	c.eq(change.to_dict()["after_id"], "twin_fangs", "weapon change serializes")
