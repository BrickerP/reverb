extends RefCounted


func _take(sim: Sim, weapon: StringName = &"pistol") -> EchoTake:
	var take := EchoTake.new()
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(30, 0)])
	take.weapons.append(Content.weapon(weapon))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	return take


func _sim(count: int = 1) -> Sim:
	var sim := Sim.new(71)
	sim.player.pos = Vector2(300, 220)
	for i in count:
		sim.bank.add(_take(sim))
	sim.start_wave(2)
	sim._plan.clear()
	return sim


func _enemy(sim: Sim, position: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.uid = 990
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = position
	enemy.radius = enemy.def.radius
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	sim.enemies.append(enemy)
	return enemy


func test_active_retirement_consumes_selected_copy_and_has_only_short_cooldown(c: Check) -> void:
	var sim := _sim(2)
	var first := sim.echoes[0].take
	var second := sim.echoes[1].take
	c.ok(sim.select_echo(second.uid), "selection targets the newer copy by stable UID")
	var events: Array[EchoRetirementInfo] = []
	sim.echo_retired.connect(func(info: EchoRetirementInfo) -> void: events.append(info))
	sim.player.hp = 10.0
	c.ok(sim.retire_selected_echo(), "selected retirement succeeds")
	c.eq(sim.bank.takes.size(), 1, "one copy is consumed")
	c.eq(sim.bank.takes[0].uid, first.uid, "the unselected older copy survives")
	c.eq(sim.player.hp, 10.0, "retirement has no universal heal")
	c.eq(events.size(), 1, "one retirement event")
	c.eq(events[0].uid, second.uid, "the event carries the consumed stable identity")
	c.eq(events[0].reason, EchoRetirementInfo.ACTIVE, "active retirement is distinct")
	c.ok(not events[0].exhausted and events[0].damage > 0.0, "active skill has its deterministic profile")
	c.ok(not sim.retire_selected_echo(), "short input debounce prevents repeated retirement")
	EchoSystem.step(sim, EchoSystem.INPUT_COOLDOWN)
	c.ok(sim.retire_selected_echo(), "another copy can retire in the same wave after cooldown")
	c.eq(sim.bank.takes.size(), 0, "both selected copies paid their skill cost")


func test_wear_is_combat_time_and_silence_does_not_protect_copies(c: Check) -> void:
	var sim := _sim()
	var actor := sim.echoes[0]
	actor.pos = Vector2(2200, 1000)
	actor.take.samples = PackedVector2Array([actor.pos])
	sim.echo_silenced = 50.0
	var power := sim.echo_dps(actor.take)
	EchoSystem.step(sim, 30.0)
	c.near(actor.take.condition, 75.0, 0.001, "30 combat seconds spend a quarter of 120 seconds")
	c.near(sim.echo_dps(actor.take), power, 0.001, "wear does not linearly degrade damage")
	c.near(actor.t, 30.0, 0.001, "playback advances even while silenced")
	sim.phase = Sim.Phase.SHOP
	EchoSystem.step(sim, 30.0)
	c.near(actor.take.condition, 75.0, 0.001, "shops spend no condition")
	c.near(actor.t, 30.0, 0.001, "shops stop playback")
	sim.phase = Sim.Phase.WAVE
	sim.wear_rate_mult = 1.5
	EchoSystem.step(sim, 20.0)
	c.near(actor.take.condition, 50.0, 0.001, "role wear multiplier applies to runtime wear")


func test_exhaustion_removes_copy_without_active_skill(c: Check) -> void:
	var sim := _sim()
	var take := sim.echoes[0].take
	take.condition = 0.01
	var enemy := _enemy(sim, sim.echoes[0].pos + Vector2(10, 0))
	var events: Array[EchoRetirementInfo] = []
	sim.echo_retired.connect(func(info: EchoRetirementInfo) -> void: events.append(info))
	EchoSystem.step(sim, 1.0)
	c.eq(sim.echoes.size(), 0, "exhausted deployed actor removed")
	c.eq(sim.bank.takes.size(), 0, "exhausted recording removed")
	c.eq(sim.selected_echo_uid, 0, "empty selection is explicit")
	c.eq(events.size(), 1, "exhaustion emits exactly one event")
	c.ok(events[0].exhausted, "exhaustion reason is explicit")
	c.eq(events[0].damage, 0.0, "waiting to zero never awards the active skill")
	c.eq(enemy.hp, 1000.0, "exhaustion has no hidden explosion")


func test_profiles_cover_six_styles_and_mirror_matches_live_loadout(c: Check) -> void:
	var sim := _sim()
	var fixtures := {&"pistol": &"pin", &"stamp": &"stamp", &"shotgun": &"cut",
		&"ink_bottle": &"ink", &"rubber_band": &"return", &"orb": &"arc"}
	for weapon: StringName in fixtures:
		var take := _take(sim, weapon)
		var profile := EchoSystem.skill_profile(take, sim)
		c.eq(profile["kind"], fixtures[weapon], "recorded style produces the displayed retirement category")
		c.eq(profile["weapon_id"], weapon, "prediction identifies its actual dominant weapon")
	var recorded := _take(sim, &"stamp")
	sim.live_echo = true
	sim.player.weapons = [Content.weapon(&"orb")]
	sim.player.weapon_levels = [2]
	var live := EchoSystem.skill_profile(recorded, sim)
	c.eq(live["kind"], &"arc", "Mirror predicts its live firing style")
	c.eq(live["weapon_id"], &"orb", "Mirror does not display its obsolete recorded weapon")
	var before_damage: float = live["damage"]
	sim.retirement_mult = 1.5
	c.near(EchoSystem.skill_profile(recorded, sim)["damage"], before_damage * 1.5, 0.001,
		"overloader retirement multiplier reaches the real skill profile")


func test_empty_selection_and_invalid_delta_are_safe(c: Check) -> void:
	var sim := _sim(0)
	c.ok(not sim.can_retire_echo() and not sim.retire_selected_echo(), "empty retirement is rejected")
	c.ok(not sim.cycle_echo(1) and not sim.select_echo(42), "selection cannot invent a copy")
	var populated := _sim(2)
	var uid := populated.selected_echo_uid
	c.ok(populated.cycle_echo(-1), "selection wraps backwards")
	c.ok(populated.selected_echo_uid != uid, "cycle changes the selected copy")
	var condition := populated.echoes[0].take.condition
	EchoSystem.step(populated, -1.0)
	EchoSystem.step(populated, INF)
	c.eq(populated.echoes[0].take.condition, condition, "invalid time cannot restore or exhaust condition")


func test_all_six_retirements_execute_real_attributed_attacks(c: Check) -> void:
	for weapon: StringName in [&"pistol", &"stamp", &"shotgun", &"ink_bottle", &"rubber_band", &"orb"]:
		var sim := _sim()
		var actor := sim.echoes[0]
		actor.take.weapons = [Content.weapon(weapon)]
		var uid := actor.take.uid
		var target := _enemy(sim, actor.pos + Vector2(50, 0))
		sim.grid.clear()
		sim.grid.insert(target)
		var hits: Array[DamageInfo] = []
		sim.damage_event.connect(func(info: DamageInfo) -> void: hits.append(info))
		c.ok(sim.retire_selected_echo(), "the chosen weapon style can actually retire")
		Combat.tick_fields(sim, 0.4)
		Combat.step_projectiles(sim, 0.13)
		c.ok(target.hp < 1000.0, "real retirement primitive damages a target in its shown area")
		c.ok(not hits.is_empty(), "real retirement emits attributed damage")
		for hit in hits:
			c.eq(hit.actor_token, uid, "retirement attack keeps consumed copy UID")
			c.eq(hit.weapon_id, weapon, "retirement attack keeps its predicted weapon")
		c.eq(sim.bank.takes.size(), 0, "an executing delayed skill has already consumed its copy")
