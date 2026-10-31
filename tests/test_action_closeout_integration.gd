extends RefCounted

const DT := 1.0 / 60.0
const PRESS := &"machine_3"


func _sim(role: StringName = &"looper") -> Sim:
	var sim := Sim.new(20261101)
	Content.character(role).apply(sim)
	sim.start_run()
	sim._plan.clear()
	sim.enemies.clear()
	sim.pending.clear()
	sim.player.pos = Vector2(1240, 680)
	sim.player.stats.values[Stats.MAX_HP] = 200.0
	sim.player.hp = 200.0
	_quiet_weapons(sim)
	return sim


func _quiet_weapons(sim: Sim) -> void:
	for index in sim.player.cooldowns.size():
		sim.player.cooldowns[index] = 1000.0
	for actor: EchoActor in sim.echoes:
		for index in actor.cooldowns.size():
			actor.cooldowns[index] = 1000.0


func _wire(sim: Sim, ink: InteractionInk) -> void:
	sim.world_event.connect(ink.consume_world)
	sim.echo_work_performed.connect(ink.consume_echo_work)
	sim.support_event.connect(ink.consume_support)
	var body_key := PresentationAssets.character_key(sim.character_id)
	sim.echo_retired.connect(func(info: EchoRetirementInfo) -> void:
		ink.consume_retirement(info, body_key))


func _step(sim: Sim, ink: InteractionInk, frames: int, movement: Vector2 = Vector2.ZERO) -> void:
	for _frame in frames:
		sim.step(DT, movement)
		ink.step(DT)


func _copy(sim: Sim) -> EchoTake:
	var take := EchoTake.new()
	take.wave = 1
	take.weapons.append(Content.weapon(&"stamp"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	for _frame in 361:
		take.samples.append(sim.player.pos + Vector2(180, 20))
	sim.bank.add(take)
	sim.start_wave(2)
	sim._plan.clear()
	_quiet_weapons(sim)
	return take


func _read_only(c: Check, sim: Sim, ink: InteractionInk, token: int = -1) -> void:
	var before := RunSnapshot.capture(sim)
	var rng := sim.rng.state
	var hazard := sim.hazard_rng.state
	c.ok(not before.is_empty(), "actual fixture has a full serializable snapshot")
	for reduced in [false, true]:
		ink.profiles(WorldArena.BOUNDS, reduced, sim)
		ink.actor_pose(token, reduced)
		ink.step(0.01)
	c.eq(RunSnapshot.capture(sim), before, "presentation sampling and aging leave the full model unchanged")
	c.eq(sim.rng.state, rng, "presentation uses no gameplay RNG")
	c.eq(sim.hazard_rng.state, hazard, "presentation uses no hazard RNG")


func test_recorded_machine_replay_reaches_real_lever_and_removed_echo_leaves_no_arm(c: Check) -> void:
	var sim := _sim()
	var ink := InteractionInk.new()
	_wire(sim, ink)
	for site: Dictionary in sim.interactables:
		if site["id"] == PRESS:
			sim.player.pos = site["pos"] + Vector2(-80, 0)
			break
	sim.recorder.begin(sim.player.pos)
	for _frame in 600:
		if bool(Expedition.interaction(sim).get("available", false)):
			break
		_step(sim, ink, 1)
	c.ok(sim.interact(), "real nearby E commits the recorded press operation")
	_step(sim, ink, 20)
	var take := sim.recorder.finish(sim.wave, sim.player.weapons, sim.player.stats, sim.player.weapon_levels)
	c.eq(take.work_actions.size(), 1, "actual player input records exactly one machine action")
	if take.work_actions.size() != 1:
		return
	c.eq(take.work_actions[0]["target_id"], PRESS, "recorded work names the canonical press")
	sim.bank.add(take)
	sim.start_wave(2)
	sim._plan.clear()
	_quiet_weapons(sim)
	sim.player.pos += Vector2(-160, 0)
	ink.reset()
	var events: Array[Dictionary] = []
	sim.echo_work_performed.connect(func(info: Dictionary) -> void: events.append(info))
	for _frame in 600:
		_step(sim, ink, 1)
		if not events.is_empty():
			break
	c.eq(events.size(), 1, "deployed actor crosses its real recorded operation once")
	if events.is_empty():
		return
	c.ok(events[0]["success"], "recorded readiness delay lets the actual press operation succeed")
	c.eq(events[0]["uid"], take.uid, "work uses stable positive Echo identity")
	_step(sim, ink, 16)
	var marks := ink.profiles(WorldArena.BOUNDS, false, sim)
	var contacts := 0
	for mark: Dictionary in marks:
		if mark["family"] == &"interaction" and int(mark["actor_token"]) == take.uid:
			var pose := InteractionInk.interaction_pose(mark, float(mark["progress"]))
			c.eq(mark["target_id"], PRESS, "visible hand belongs to the actual operated machine")
			c.ok(pose["contact"], "real replay receipt reaches its lever contact beat")
			c.near((pose["hand"] as Vector2).distance_to(pose["grip"]), 0.0, 0.01, "hand closes on the actual lever")
			contacts += 1
	c.eq(contacts, 1, "one real replay produces one arm instead of duplicating world and work signals")
	_read_only(c, sim, ink, take.uid)
	c.ok(sim.select_echo(take.uid) and sim.retire_selected_echo(), "real retirement removes the working Echo")
	c.eq(sim.bank.find_uid(take.uid), null, "retirement removes the recording from the bank")
	for mark: Dictionary in ink.profiles(WorldArena.BOUNDS, false, sim):
		c.ok(mark["family"] != &"interaction" or int(mark["actor_token"]) != take.uid,
			"a removed live actor cannot leave a reaching arm attached to its last position")
	ink.step(2.0)
	c.eq(ink.counts()["active"], 0, "all detached work and folded retirement receipts expire")


func test_all_real_role_inputs_have_finite_read_only_body_sequences(c: Check) -> void:
	for role: StringName in [&"solo", &"looper", &"mirror", &"conductor", &"mender", &"overloader"]:
		var sim := _sim(role)
		var ink := InteractionInk.new()
		_wire(sim, ink)
		var uid := 0
		if role != &"solo":
			uid = _copy(sim).uid
		sim.player.facing = Vector2.RIGHT
		if role == &"looper":
			_step(sim, ink, 60, Vector2.RIGHT * 0.35)
		if role == &"mender":
			sim.player.hp = 140.0
		var origin := sim.player.pos
		c.ok(sim.activate_character_skill(), "%s uses its actual accepted role transaction" % role)
		_step(sim, ink, 14)
		var pose := ink.actor_pose(-1)
		c.ok(pose["active"], "%s has a body action during its actual contact window" % role)
		c.eq(pose["action"], role, "%s body uses its real ability identity" % role)
		c.eq(ink.actor_pose(-1, true)["scale"], Vector2.ONE, "%s Reduced retains a stable body" % role)
		if role in [&"solo", &"looper", &"mirror"]:
			c.ok(sim.player.pos.distance_to(origin) > 25.0, "%s commits a real world displacement" % role)
		_read_only(c, sim, ink)
		if role == &"overloader":
			c.eq(sim.bank.find_uid(uid), null, "overload consumes the real recording")
			c.ok(sim.echoes.is_empty(), "overload leaves no living source actor")
		_step(sim, ink, 180)
		c.ok(not ink.actor_pose(-1)["active"], "%s body settles after its finite sequence and any relay pulses" % role)
		c.ok(not ink.actor_pose(uid)["active"], "%s cannot retain a stale Echo action" % role)


func test_rejected_skill_spends_nothing_and_produces_no_body_action(c: Check) -> void:
	var sim := _sim(&"solo")
	var ink := InteractionInk.new()
	_wire(sim, ink)
	sim.character_energy = 0.0
	var before := RunSnapshot.capture(sim)
	c.ok(not sim.activate_character_skill(), "energy boundary rejects real activation")
	c.eq(RunSnapshot.capture(sim), before, "failed input cannot move, spend or grant protection")
	c.ok(not ink.actor_pose(-1)["active"], "failed input cannot create a successful body pose")
	c.eq(ink.counts()["active"], 0, "failed skill contributes no stale success receipt")
	_read_only(c, sim, ink)


func test_real_rescue_keeps_old_and_safe_endpoints_without_keeping_a_worker_alive(c: Check) -> void:
	var sim := _sim()
	var ink := InteractionInk.new()
	_wire(sim, ink)
	var site: Dictionary = {}
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			site = item
			break
	c.ok(not site.is_empty(), "ambient endangered worker exists without a fabricated mission")
	if site.is_empty():
		return
	var old: Vector2 = site["pos"]
	var id: StringName = site["id"]
	sim.player.pos = old + Vector2(-50, 0)
	c.ok(sim.interact(), "actual nearby E commits the rescue")
	var worker := Expedition._worker(sim, id)
	c.eq(worker["state"], &"safe", "worker really enters the safe registry")
	c.ok((worker["pos"] as Vector2).distance_to(old) > 100.0, "worker physically leaves danger")
	var rescues := 0
	for mark: Dictionary in ink.profiles(WorldArena.BOUNDS, false, sim):
		if mark["family"] != &"rescue":
			continue
		rescues += 1
		var depart := InteractionInk.rescue_pose(mark, 0.2)
		var arrive := InteractionInk.rescue_pose(mark, 0.8)
		c.eq(depart["source"], old, "departure uses the pre-transaction endangered position")
		c.eq(depart["target"], worker["pos"], "arrival uses the committed safe position")
		c.ok(float(depart["departure_alpha"]) > 0.0 and not bool(depart["safe_visible"]),
			"departure contour and safe body do not become two living workers")
		c.ok(is_zero_approx(float(arrive["departure_alpha"])) and bool(arrive["safe_visible"]),
			"safe body appears after the old-location contour has gone")
		c.eq(InteractionInk.rescue_pose(mark, 0.2, true)["departure_alpha"], 0.0,
			"Reduced does not draw a travelling duplicate")
	c.eq(rescues, 1, "committed rescue produces exactly one value receipt")
	_read_only(c, sim, ink)
	# Removal is a controlled boundary fixture: the bounded contour owns copied
	# event coordinates, never an object that can revive the registry entry.
	sim.expedition["world"]["workers"].clear()
	ink.step(InteractionInk.RESCUE_TIME + 0.01)
	for mark: Dictionary in ink.profiles(WorldArena.BOUNDS, false, sim):
		c.ok(mark["family"] != &"rescue", "removed worker has no visual ghost outside its bounded transition")
	c.ok(sim.expedition["world"]["workers"].is_empty(), "presentation cannot reinsert a removed worker")
