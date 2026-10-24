extends RefCounted


func _sim(ids: Array) -> Sim:
	var sim := Sim.new(2131)
	sim.start_run()
	sim.phase = Sim.Phase.SHOP
	sim.player.materials = 100
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for i in ids.size():
		sim.player.add_weapon(Content.weapon(ids[i]))
		sim.player.weapon_levels[i] = i
		sim.player.cooldowns[i] = 0.1 + 0.2 * i
	return sim


func test_middle_and_duplicate_sales_report_the_acted_on_slot(c: Check) -> void:
	for case: Dictionary in [
		{"ids": [&"pistol", &"smg", &"rifle"], "index": 1},
		{"ids": [&"pistol", &"pistol", &"rifle"], "index": 0},
		{"ids": [&"pistol", &"pistol", &"pistol"], "index": 1},
	]:
		var sim := _sim(case["ids"])
		var index: int = case["index"]
		var before := ShopState.capture(sim)
		var changes: Array[WeaponChangeInfo] = []
		sim.weapon_changed.connect(func(info: WeaponChangeInfo) -> void: changes.append(info))
		c.ok(sim.shop.apply(ShopResult.SELL, sim, null, index).ok, "sale succeeds")
		c.eq(changes.size(), 1, "sale emits one removal, no shifted-slot replacement")
		if changes.size() != 1:
			continue
		c.eq(changes[0].index, index, "sale retains requested slot")
		c.eq(changes[0].before_id, before.weapons[index], "removed weapon id")
		c.eq(changes[0].before_level, before.weapon_levels[index], "removed weapon level")
		c.eq(changes[0].after_id, &"", "removal has no replacement weapon")
		c.eq(changes[0].after_level, 0, "empty side has no weapon level")
		changes.clear()
		c.ok(sim.shop.undo(sim).ok, "undo succeeds")
		c.eq(changes.size(), 1, "undo emits one insertion")
		if changes.size() != 1:
			continue
		c.eq(changes[0].index, index, "undo retains original slot even for duplicate IDs")
		c.eq(changes[0].before_id, &"", "insertion begins from empty")
		c.eq(changes[0].before_level, 0, "insertion begins without a level")
		c.eq(changes[0].after_id, before.weapons[index], "undo restores original id")
		c.eq(changes[0].after_level, before.weapon_levels[index], "undo restores original level")
		c.eq(ShopState.capture(sim).to_dict(), before.to_dict(), "gameplay state restores exactly")
		c.eq(sim.player.cooldowns, before.cooldowns, "cooldown ordering restores exactly")
