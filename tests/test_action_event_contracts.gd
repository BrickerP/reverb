extends RefCounted


class ShieldCascadeSim extends Sim:
	func _shield_break_burst() -> void:
		# A burst can kill a bomber synchronously before the outer hit is done.
		_hurt_player(4.0, &"bomber", &"bomber_explosion", player.pos, Vector2.LEFT)


func _sim() -> Sim:
	var sim := Sim.new(812)
	sim.start_run()
	sim._plan.clear()
	sim.player.pos = Vector2(300.0, 220.0)
	return sim


func _enemy(sim: Sim) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.uid = sim._next_uid
	sim._next_uid += 1
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = sim.player.pos + Vector2(100.0, 0.0)
	enemy.radius = enemy.def.radius
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	sim.enemies.append(enemy)
	return enemy


func _take(sim: Sim) -> EchoTake:
	var take := EchoTake.new()
	take.samples = PackedVector2Array([sim.player.pos + Vector2(70.0, 30.0)])
	take.weapons = [Content.weapon(&"pistol"), Content.weapon(&"pistol")]
	take.levels = [0, 0]
	sim.bank.add(take)
	return take


func _plain(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not _plain(key) or not _plain(value[key]):
				return false
	elif value is Array:
		for entry: Variant in value:
			if not _plain(entry):
				return false
	return true


func test_duplicate_weapons_emit_only_the_actual_player_slot(c: Check) -> void:
	var sim := _sim()
	_enemy(sim)
	sim.player.add_weapon(Content.weapon(&"pistol"))
	sim.player.cooldowns = [0.0, 10.0]
	var shots: Array[ShotInfo] = []
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: shots.append(info))
	Combat.step_weapons(sim, sim.player.pos, sim.player.stats, sim.player.weapons,
		sim.player.weapon_levels, sim.player.cooldowns, 1.0, 0.01, -1, Color.WHITE)
	c.eq(shots.size(), 1, "one duplicate actually fires")
	c.eq(shots[0].weapon_slot, 0, "the first real slot owns that shot")
	sim.player.cooldowns = [10.0, 0.0]
	Combat.step_weapons(sim, sim.player.pos, sim.player.stats, sim.player.weapons,
		sim.player.weapon_levels, sim.player.cooldowns, 1.0, 0.01, -1, Color.WHITE)
	c.eq(shots.size(), 2, "the second slot fires independently")
	c.eq(shots[1].weapon_slot, 1, "duplicate ID never means every matching slot")
	c.eq(shots[0].weapon_slot, 0, "an earlier event retains its value identity")
	c.eq(shots[1].to_dict()["weapon_slot"], 1, "serialized event carries the actual slot")
	var unknown := ShotInfo.new()
	c.eq(unknown.weapon_slot, -1, "unknown synthetic output cannot guess a recoil slot")


func test_echo_shot_keeps_stable_actor_and_exact_duplicate_slot(c: Check) -> void:
	var sim := _sim()
	_enemy(sim)
	var take := _take(sim)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	actor.cooldowns = [10.0, 0.0]
	var shots: Array[ShotInfo] = []
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: shots.append(info))
	Combat.step_weapons(sim, actor.pos, take.stats, take.weapons, take.levels,
		actor.cooldowns, sim.echo_power(), 0.01, actor.index, take.tint(), 1.0, 1.0, take.uid)
	c.eq(shots.size(), 1, "one Echo weapon actually fires")
	c.eq(shots[0].weapon_slot, 1, "Echo duplicate slot is explicit")
	c.eq(shots[0].actor_token, take.uid, "Echo identity survives slot reordering")
	c.eq(shots[0].source, 0, "legacy source remains the deployed actor index")
	actor.index = 3
	c.eq(shots[0].source, 0, "emitted source is a value snapshot")
	c.eq(shots[0].actor_token, take.uid, "stable owner is independent from the changed index")


func test_delayed_burst_keeps_unknown_slot_without_extending_saved_attack_state(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim)
	var shots: Array[ShotInfo] = []
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: shots.append(info))
	var weapon := Content.weapon(&"smg")
	c.ok(Combat.fire(sim, sim.player.pos, enemy.pos, weapon, 0, 1.0,
		sim.player.stats, 1.0, -1, Color.WHITE), "real burst allocates delayed output")
	Combat.tick_fields(sim, weapon.burst_interval + 0.001)
	c.ok(not shots.is_empty(), "a later burst round emits its own real release")
	c.eq(shots[0].weapon_slot, -1, "delayed output does not guess among same-ID guns")


func test_recorded_signature_never_guesses_duplicate_or_mirror_slots(c: Check) -> void:
	var sim := _sim()
	_enemy(sim)
	var take := _take(sim)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	var shots: Array[ShotInfo] = []
	sim.shot_fired_info.connect(func(info: ShotInfo) -> void: shots.append(info))
	var action := {"weapon_id": &"pistol", "aim": Vector2.RIGHT}
	c.ok(sim.replay_signature(actor, action), "real recorded duplicate attack executes")
	c.eq(shots[0].weapon_slot, -1, "old ID-only work cannot identify one of two equal guns")
	take.weapons.remove_at(1)
	take.levels.remove_at(1)
	actor.cooldowns.remove_at(1)
	c.ok(sim.replay_signature(actor, action), "unique recorded attack executes")
	c.eq(shots[1].weapon_slot, 0, "a unique recorded weapon has a provable slot")
	sim.live_echo = true
	c.ok(sim.replay_signature(actor, action), "Mirror retains its existing signature behavior")
	c.eq(shots[2].weapon_slot, -1, "recorded work cannot claim a slot in Mirror's current loadout")


func test_shield_block_and_partial_hp_damage_report_real_before_after(c: Check) -> void:
	var sim := _sim()
	sim.player.hp = 20.0
	sim.player.shield = 6.0
	var hurts: Array[PlayerHurtInfo] = []
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurts.append(info))
	var rng_state := sim.rng.state
	var hazard_state := sim.hazard_rng.state
	sim._hurt_player(4.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
	c.ok(hurts[0].full_block(), "fully shielded impact is a defense reaction")
	c.eq(hurts[0].amount, 0.0, "full shield block has no HP damage")
	c.eq(hurts[0].hp_loss, 0.0, "body loses no actual health")
	c.eq(hurts[0].hp_before, 20.0, "full block snapshots original health")
	c.eq(hurts[0].hp_after, 20.0, "full block snapshots unchanged health")
	c.eq(hurts[0].shield_before, 6.0, "shield starts with six")
	c.eq(hurts[0].shield_after, 2.0, "actual absorption is four")
	sim.player.iframes = 0.0
	sim._hurt_player(5.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
	c.ok(not hurts[1].full_block(), "partial block still has a real body reaction")
	c.eq(hurts[1].absorbed, 2.0, "partial block uses only remaining shield")
	c.eq(hurts[1].amount, 3.0, "only unabsorbed damage reaches HP")
	c.eq(hurts[1].hp_loss, 3.0, "actual HP loss is explicit")
	c.eq(hurts[1].hp_after, 17.0, "partial hit leaves real HP")
	c.eq(hurts[1].shield_after, 0.0, "partial hit breaks the shield")
	c.eq(sim.rng.state, rng_state, "event detail uses no gameplay RNG")
	c.eq(sim.hazard_rng.state, hazard_state, "event detail uses no hazard RNG")
	c.ok(_plain(hurts[1].to_dict()), "hurt export contains values rather than entity aliases")


func test_actual_hp_loss_is_bounded_by_health_and_respects_second_wind(c: Check) -> void:
	var sim := _sim()
	sim.player.hp = 2.0
	sim.second_wind_charges = 1
	var hurts: Array[PlayerHurtInfo] = []
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurts.append(info))
	sim._hurt_player(9.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
	c.eq(sim.player.hp, 1.0, "existing second-wind rule remains authoritative")
	c.eq(hurts[0].amount, 9.0, "original unabsorbed damage contract is preserved")
	c.eq(hurts[0].hp_loss, 1.0, "feedback receives actual health lost after second wind")
	sim.player.iframes = 0.0
	sim._hurt_player(9.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
	c.eq(hurts[1].hp_loss, 1.0, "overkill never fabricates nine points of lost health")
	c.ok(hurts[1].lethal, "real terminal state remains visible")


func test_nested_shield_burst_damage_is_not_reported_twice_as_body_loss(c: Check) -> void:
	var sim := ShieldCascadeSim.new()
	sim.start_run()
	sim.player.hp = 20.0
	sim.player.shield = 6.0
	sim.player.set_bonus_applied[&"field"] = true
	var hurts: Array[PlayerHurtInfo] = []
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: hurts.append(info))
	sim._hurt_player(6.0, &"grunt", &"contact", sim.player.pos, Vector2.RIGHT)
	c.eq(hurts.size(), 2, "nested explosion and original block remain separate real hits")
	c.eq(hurts[0].hp_loss, 4.0, "bomber event owns its actual health loss")
	c.ok(hurts[1].full_block(), "outer hit remains fully blocked")
	c.eq(hurts[1].hp_loss, 0.0, "outer shield event cannot claim the nested loss again")
	c.eq(sim.player.hp, 16.0, "presentation data does not change the cascade damage rule")


func test_world_interaction_reports_success_failure_and_detached_values(c: Check) -> void:
	var sim := _sim()
	var repairs: Array[Dictionary] = []
	sim.world_event.connect(func(info: Dictionary) -> void:
		if info["kind"] == &"interaction_result":
			repairs.append(info))
	for item in sim.interactables:
		if item["kind"] == &"repair":
			sim.player.pos = item["pos"]
			break
	var rng_state := sim.rng.state
	var hazard_state := sim.hazard_rng.state
	c.ok(sim.interact(), "actual nearby repair commits")
	c.ok(repairs[0]["ok"], "only committed repair reports success")
	c.eq(repairs[0]["target_kind"], &"repair", "feedback identifies the real target operation")
	c.eq(repairs[0]["before"]["status"], &"fault", "old machine state is captured before mutation")
	c.eq(repairs[0]["after"]["status"], &"repaired", "new machine state is actual repaired state")
	sim.expedition["world"]["machines"][0]["status"] = &"operating"
	c.eq(repairs[0]["after"]["status"], &"repaired", "later machine mutations cannot rewrite the event")
	for item in sim.interactables:
		if item["kind"] == &"recycler":
			sim.player.pos = item["pos"]
			break
	sim.player.materials = 0
	c.ok(not sim.interact(), "unaffordable recycler does not perform work")
	c.ok(not repairs[1]["ok"], "rejected action is explicit")
	c.eq(repairs[1]["reason"], &"poor", "rejection preserves its real cause")
	c.eq(repairs[1]["before"], repairs[1]["after"], "failed interaction changes no authoritative values")
	c.ok(_plain(repairs[0]) and _plain(repairs[1]), "world events never retain model objects")
	c.eq(sim.rng.state, rng_state, "interaction snapshots do not consume gameplay RNG")
	c.eq(sim.hazard_rng.state, hazard_state, "interaction snapshots do not consume hazard RNG")


func test_role_swap_emits_both_real_endpoints_and_failure_without_spending(c: Check) -> void:
	var sim := _sim()
	sim.character_id = &"mirror"
	var take := _take(sim)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	sim.selected_echo_uid = take.uid
	var start := sim.player.pos
	var destination := actor.pos
	var actions: Array[Dictionary] = []
	sim.world_event.connect(func(info: Dictionary) -> void:
		if info["kind"] == &"character_skill":
			actions.append(info))
	var rng_state := sim.rng.state
	c.ok(sim.activate_character_skill(), "real Mirror ability succeeds")
	c.eq(actions[0]["pos"], start, "body action starts at the actual old position")
	c.eq(actions[0]["target_pos"], destination, "body action ends at the actual new position")
	c.eq(actions[0]["anchors"][0]["uid"], take.uid, "Echo endpoint keeps stable identity")
	c.eq(actions[0]["anchors"][0]["to_pos"], start, "Echo actually moved to the body origin")
	actor.pos = Vector2(200.0, 200.0)
	c.eq(actions[0]["anchors"][0]["to_pos"], start, "later actor motion cannot alter the event")
	sim.character_cooldown = 0.0
	sim.character_energy = 0.0
	c.ok(not sim.activate_character_skill(), "insufficient energy rejects activation")
	c.ok(not actions[1]["ok"], "failure never looks like a successful swap")
	c.eq(actions[1]["reason"], &"energy", "rejection identifies missing energy")
	c.eq(actions[1]["before"], actions[1]["after"], "rejection does not spend energy or move bodies")
	c.ok(_plain(actions[0]), "ability event contains no actor aliases")
	c.eq(sim.rng.state, rng_state, "ability feedback consumes no gameplay RNG")


func test_support_spawn_and_repair_snapshot_real_scaled_bodies(c: Check) -> void:
	var sim := _sim()
	var events: Array[Dictionary] = []
	sim.support_event.connect(func(info: Dictionary) -> void: events.append(info))
	var weapon := Content.weapon(&"repair_kit")
	c.ok(SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 0.0, -1, -1,
		Color.WHITE, 3), "max-grade station really deploys")
	var profile := SupportSystem.weapon_profile(weapon, 3)
	c.eq(events[0]["hp"], profile["hp"], "spawn emits after grade scaling, not before it")
	c.eq(events[0]["max_hp"], profile["max_hp"], "spawn feedback has the true body capacity")
	var unit: Dictionary = sim.support_units.back()
	unit["cooldown"] = 0.0
	sim.player.hp = 20.0
	var take := _take(sim)
	take.condition = 80.0
	var actor := EchoActor.new(take, 0)
	actor.pos = sim.player.pos
	sim.echoes.append(actor)
	var rng_state := sim.rng.state
	SupportSystem._repair(sim, unit)
	var repaired: Dictionary = events.back()
	c.eq(repaired["kind"], &"repair", "actual useful repair emits once")
	c.eq(repaired["targets"].size(), 2, "only the two bodies with real increases are marked")
	c.eq(repaired["targets"][0]["target_type"], &"player", "first patch lands on the actual player")
	c.eq(repaired["targets"][1]["target_type"], &"echo", "second patch lands on the actual Echo")
	c.eq(repaired["targets"][1]["uid"], take.uid, "repair target keeps its stable Echo identity")
	var condition: float = repaired["targets"][1]["after"]
	take.condition = 1.0
	c.eq(repaired["targets"][1]["after"], condition, "repair output is detached from later body mutation")
	c.eq(repaired["charges"], 5, "feedback sees the consumed repair charge")
	c.ok(_plain(repaired), "support event contains only value snapshots")
	c.eq(sim.rng.state, rng_state, "support feedback uses no gameplay RNG")
	sim.expedition["world"]["roster"].append({"kind": &"foreman", "hp": 40.0,
		"max_hp": 100.0, "life": 73.0, "state": &"bench", "uid": 0})
	c.ok(Expedition._deploy(sim, &"foreman"), "a real wounded companion leaves the bench")
	c.eq(events.back()["hp"], 40.0, "companion spawn never invents refreshed health")
	c.eq(events.back()["life"], 73.0, "companion spawn preserves actual remaining service")
