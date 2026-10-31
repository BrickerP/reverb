extends RefCounted

const VIEW := Rect2(Vector2.ZERO, Vector2(2400, 1200))


func _support(uid: int = 1, kind: StringName = &"spawn") -> Dictionary:
	return {"kind": kind, "uid": uid, "unit_kind": &"repair_station", "pos": Vector2(520, 360),
		"target_pos": Vector2(550, 360), "hp": 28.0, "max_hp": 28.0, "life": 18.0,
		"charges": 6, "actor_token": -1, "weapon_id": &"repair_kit", "targets": []}


func test_real_support_events_reach_feedback_after_grade_is_applied(c: Check) -> void:
	var sim := Sim.new(502)
	var ink := InteractionInk.new()
	sim.support_event.connect(ink.consume_support)
	var weapon := Content.weapon(&"repair_kit")
	var expected := SupportSystem.weapon_profile(weapon, WeaponDef.MAX_LEVEL)
	c.ok(SupportSystem.spawn_weapon(sim, weapon, sim.player.pos, 0.0, -1, -1,
		Color.WHITE, WeaponDef.MAX_LEVEL), "a real graded station is spawned")
	var p := ink.profiles(VIEW)[0]
	c.eq(p["uid"], sim.support_units[0]["uid"], "presentation keeps the actual support UID")
	c.eq(p["max_hp"], expected["max_hp"], "spawn receipt observes the final grade rather than a base placeholder")
	c.eq(p["charges"], expected["charges"], "spawn receipt carries the actual finite deliveries")
	var scale: Vector2 = ink.support_pose(int(p["uid"]))["scale"]
	c.ok(scale.y < 0.5, "a newly deployed real body unfolds from a compressed sheet")
	c.eq(ink.support_pose(int(p["uid"]), true)["scale"], Vector2.ONE,
		"Reduced keeps a stable full body instead of hiding deployment")
	var unit: Dictionary = sim.support_units[0]
	SupportSystem.damage(sim, int(unit["uid"]), float(unit["hp"]) + 1.0)
	SupportSystem.step(sim, 0.1)
	c.ok(sim.support_units.is_empty(), "destroyed unit really leaves the model")
	var destroyed := ink.profiles(VIEW)
	c.eq(destroyed.size(), 1, "terminal receipt replaces spawn/damage rather than multiplying bodies")
	c.eq(destroyed[0]["kind"], &"destroy", "a short folded value receipt survives model removal")
	ink.step(1.0)
	c.eq(ink.counts()["active"], 0, "the dead support drawing has a finite lifetime")


func test_support_health_lifetime_and_charges_are_separate_authoritative_values(c: Check) -> void:
	var sim := Sim.new(503)
	SupportSystem.spawn(sim, &"repair_station", sim.player.pos)
	var unit: Dictionary = sim.support_units[0]
	unit["hp"] = 14.0
	unit["life"] = 4.5
	unit["charges"] = 2
	var before := RunSnapshot.capture(sim)
	var p := ExpeditionInk.support_profile(unit)
	c.near(float(p["hp_ratio"]), 0.5, 0.0001, "wide health bar follows HP")
	c.near(float(p["life_ratio"]), 0.25, 0.0001, "thin hourglass strip follows remaining lifetime")
	c.eq(p["life_seconds"], 4.5, "remaining seconds do not derive from charges")
	c.eq(p["charges"], 2, "two remaining deliveries are shown as two solid pips")
	c.eq(p["charge_capacity"], 6, "empty delivery pips remain distinguishable from a clock")
	c.eq(RunSnapshot.capture(sim), before, "presentation never ages, heals or spends the support")
	var ink := InteractionInk.new()
	sim.support_event.connect(ink.consume_support)
	unit["life"] = 0.001
	SupportSystem.step(sim, 0.002)
	c.eq(ink.profiles(VIEW)[0]["kind"], &"expire", "natural expiry has its own quiet receipt")
	c.ok(sim.support_units.is_empty(), "the expired receipt cannot keep the unit alive")


func test_repair_receipts_keep_only_real_targets_and_copy_values(c: Check) -> void:
	var ink := InteractionInk.new()
	var event := _support(7, &"repair")
	event["targets"] = [
		{"uid": 91, "target_type": &"echo", "pos": Vector2(560, 360), "amount": 2.0, "before": 40.0, "after": 42.0},
		{"uid": -1, "target_type": &"player", "pos": Vector2(510, 360), "amount": 0.0, "before": 35.0, "after": 35.0},
	]
	ink.consume_support(event)
	event["targets"][0]["pos"] = Vector2(100, 100)
	event["targets"][0]["after"] = 99.0
	var p := ink.profiles(VIEW)[0]
	c.eq(p["targets"].size(), 1, "full-health bodies do not receive fake repair patches")
	c.eq(p["targets"][0]["uid"], 91, "patch belongs to the repaired Echo's stable UID")
	c.eq(p["targets"][0]["pos"], Vector2(560, 360), "patch keeps the event position after the input mutates")
	c.eq(p["targets"][0]["after"], 42.0, "render receipt cannot follow a live dictionary reference")
	var produced := _support(8, &"produce")
	produced["targets"] = [{"uid": -1, "target_type": &"player", "pos": Vector2(550, 360),
		"amount": 5.0, "before": {"shield": 0.0, "energy": 0.0}, "after": {"shield": 2.0, "energy": 3.0}}]
	ink.consume_support(produced)
	c.eq(ink.profiles(VIEW).back()["targets"][0]["amount"], 5.0,
		"shield/energy production accepts its value event without pretending it is HP")


func test_failed_interaction_does_not_become_a_success_or_change_the_sim(c: Check) -> void:
	var sim := Sim.new(504)
	sim.start_run()
	var ink := InteractionInk.new()
	var before := RunSnapshot.capture(sim)
	ink.consume_world({"kind": &"interaction_result", "pos": sim.player.pos,
		"target_pos": sim.player.pos + Vector2(50, 0), "target_kind": &"press",
		"actor_token": -1, "ok": false, "reason": &"poor"})
	var failed := ink.profiles(VIEW)[0]
	c.ok(not bool(failed["ok"]), "failed lever keeps the blocked/rebound branch")
	c.eq(failed["reason"], &"poor", "the actual failure reason remains attached")
	c.eq(RunSnapshot.capture(sim), before, "drawing intent cannot run the machine or spend materials")
	ink.consume_world({"kind": &"companion_signed", "pos": sim.player.pos, "ok": false, "target_uid": 7})
	c.eq(ink.counts()["world"], 1, "failed negotiations cannot rip or replace a Boss badge")
	ink.consume_world({"kind": &"companion_signed", "pos": sim.player.pos, "ok": true, "target_uid": 7})
	c.eq(ink.profiles(VIEW).back()["family"], &"recruit", "committed recruitment earns the new work badge")


func test_repaired_machine_keeps_patch_when_stopped(c: Check) -> void:
	var art := Rect2(Vector2(400, 250), Vector2(100, 130))
	var machine := {"status": &"repaired", "stopped": true}
	var marks := RecyclingDepot.machine_marks(machine, art)
	var patch: Rect2 = marks["patch"]
	c.ok(patch.has_area(), "completed repair has physical paper even while the machine is locked")
	c.eq(marks["staples"].size(), 4, "repair still has its tightened staples")
	c.eq(marks["lock"].size(), 2, "stopping independently adds a physical lock")
	c.ok(patch.end.y < art.get_center().y - 9.0, "lock cannot cover the repair checkmark")
	c.eq(machine, {"status": &"repaired", "stopped": true}, "machine drawing cannot restart a stopped machine")


func test_retirement_keeps_identity_after_removal_and_exhaustion_has_no_skill(c: Check) -> void:
	var ink := InteractionInk.new()
	var info := EchoRetirementInfo.new()
	info.uid = 123
	info.pos = Vector2(600, 400)
	info.weapon_id = &"stamp"
	info.kind = &"stamp"
	info.condition = 37.0
	ink.consume_retirement(info, PresentationAssets.character_key(&"looper"))
	info.uid = 999
	info.condition = 0.0
	var p := ink.profiles(VIEW)[0]
	c.eq(p["uid"], 123, "departed copy's UID remains a value receipt")
	c.eq(p["weapon_id"], &"stamp", "folded receipt retains its real skill weapon")
	c.eq(p["condition"], 37.0, "remaining condition does not reset on exit")
	var quiet := EchoInk.retirement_pose(&"pin", 0.8, true)
	var shapes: Array[Dictionary] = []
	for kind: StringName in [&"pin", &"stamp", &"cut", &"ink", &"return", &"arc"]:
		var pose := EchoInk.retirement_pose(kind, 0.8, false)
		c.ok(not shapes.has(pose), "%s has its own folding action" % kind)
		shapes.append(pose)
		c.eq(EchoInk.retirement_pose(kind, 0.8, true), quiet,
			"exhaustion never borrows %s's active attack fold" % kind)
		c.ok(EchoInk.retirement_lines(kind, Vector2.ZERO, 0.8).size() <= 3,
			"exit pen marks remain bounded")
	ink.reset()
	info.uid = 123
	info.exhausted = true
	info.reason = EchoRetirementInfo.EXHAUSTED
	ink.consume_retirement(info, PresentationAssets.character_key(&"looper"))
	c.ok(bool(ink.profiles(VIEW)[0]["exhausted"]), "natural exhaustion explicitly selects the quiet draw branch")


func test_feedback_pause_reduced_culling_budgets_and_rng(c: Check) -> void:
	var sim := Sim.new(505)
	var ink := InteractionInk.new()
	var rng := sim.rng.state
	var wave_time := sim.wave_time
	for uid in 100:
		ink.consume_support(_support(uid + 1))
	c.eq(ink.counts()["active"], InteractionInk.MAX_MARKS, "input burst cannot grow the receipt queue")
	c.eq(ink.profiles(VIEW).size(), InteractionInk.MAX_DRAW, "draw budget is separate from storage budget")
	var before := ink.profiles(VIEW)
	ink.step(0.2, true)
	c.eq(ink.profiles(VIEW), before, "pause freezes every receipt clock")
	ink.step(NAN)
	ink.step(-1.0)
	c.eq(ink.profiles(VIEW), before, "invalid presentation deltas cannot age receipts")
	var reduced := ink.profiles(VIEW, true)
	c.eq(reduced.size(), before.size(), "Reduced retains the same real result receipts")
	c.eq(reduced[0]["progress"], 1.0, "Reduced shows contact/result instead of decorative travel")
	c.eq(ink.profiles(Rect2(Vector2(10000, 10000), Vector2(50, 50))).size(), 0,
		"off-camera receipts are culled")
	ink.step(0.8)
	c.eq(ink.counts()["active"], 0, "all event classes leave a bounded scene")
	c.eq(sim.rng.state, rng, "feedback has no gameplay RNG access")
	c.eq(sim.wave_time, wave_time, "feedback never changes simulation time")


func test_one_support_keeps_distinct_same_tick_results(c: Check) -> void:
	var ink := InteractionInk.new()
	ink.consume_support(_support(17, &"repair"))
	ink.consume_support(_support(17, &"damage"))
	var kinds: Array[StringName] = []
	for p: Dictionary in ink.profiles(VIEW):
		kinds.append(p["kind"])
	c.ok(kinds.has(&"repair") and kinds.has(&"damage"), "taking damage cannot erase a repair that already happened")
	ink.consume_support(_support(17, &"damage"))
	c.eq(ink.counts()["support"], 2, "only repeated same-kind feedback is coalesced")
	ink.consume_support(_support(18, &"retrieve"))
	ink.consume_support(_support(18, &"attack"))
	kinds.clear()
	for p: Dictionary in ink.profiles(VIEW):
		kinds.append(p["kind"])
	c.ok(kinds.has(&"retrieve") and kinds.has(&"attack"), "a helper can visibly collect and attack in the same tick")
	ink.consume_support(_support(17, &"destroy"))
	kinds.clear()
	for p: Dictionary in ink.profiles(VIEW):
		if int(p["uid"]) == 17:
			kinds.append(p["kind"])
	c.ok(kinds.has(&"destroy") and kinds.has(&"repair"), "terminal folding keeps repairs already committed to other bodies")
	c.ok(not kinds.has(&"damage") and not kinds.has(&"spawn") and not kinds.has(&"attack"),
		"terminal folding replaces the dead helper's old body actions")


func test_repair_patches_follow_live_identity_but_keep_detached_exit_receipts(c: Check) -> void:
	var sim := Sim.new(506)
	sim.player.pos = Vector2(500, 360)
	var take := EchoTake.new()
	take.samples = PackedVector2Array([Vector2(550, 360)])
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	SupportSystem.spawn(sim, &"hound", Vector2(580, 360))
	var unit: Dictionary = sim.support_units[0]
	var event := _support(99, &"repair")
	event["targets"] = [
		{"uid": -1, "target_type": &"player", "pos": sim.player.pos, "amount": 1.0},
		{"uid": take.uid, "target_type": &"echo", "pos": actor.pos, "amount": 2.0},
		{"uid": int(unit["uid"]), "target_type": &"support", "pos": unit["pos"], "amount": 2.0},
	]
	var old_echo_pos := actor.pos
	var old_support_pos: Vector2 = unit["pos"]
	var ink := InteractionInk.new()
	ink.consume_support(event)
	sim.player.pos += Vector2(40, 0)
	actor.pos += Vector2(50, 0)
	unit["pos"] += Vector2(60, 0)
	var rng := sim.rng.state
	var p := ink.profiles(VIEW, false, sim)[0]
	c.eq(p["targets"][0]["pos"], sim.player.pos, "HP patch stays on the moving original")
	c.eq(p["targets"][1]["pos"], actor.pos, "condition patch follows the exact Echo UID")
	c.eq(p["targets"][2]["pos"], unit["pos"], "same integer namespace cannot confuse support with Echo")
	c.eq(sim.rng.state, rng, "live target lookup never consumes gameplay RNG")
	sim.echoes.clear()
	sim.support_units.clear()
	p = ink.profiles(VIEW, true, sim)[0]
	c.eq(p["targets"][1]["pos"], old_echo_pos, "removed Echo leaves only its captured result position")
	c.eq(p["targets"][2]["pos"], old_support_pos, "removed helper does not retain a model object")
	c.eq(ink.profiles(VIEW)[0]["targets"][1]["pos"], old_echo_pos,
		"live lookups never overwrite the stored value receipt")


func test_secondary_repair_target_keeps_event_visible_when_source_and_first_target_are_offscreen(c: Check) -> void:
	var ink := InteractionInk.new()
	var event := _support(27, &"repair")
	event["pos"] = Vector2(1000, 800)
	event["target_pos"] = Vector2(1100, 800)
	event["targets"] = [
		{"uid": 8, "target_type": &"echo", "pos": Vector2(1100, 800), "amount": 2.0},
		{"uid": 9, "target_type": &"echo", "pos": Vector2(150, 150), "amount": 2.0},
	]
	ink.consume_support(event)
	var shown := ink.profiles(Rect2(Vector2(100, 100), Vector2(100, 100)))
	c.eq(shown.size(), 1, "a visible secondary repaired body retains the event")
	c.ok(not bool(shown[0]["targets"][0]["visible"]), "offscreen repaired body is not drawn")
	c.ok(bool(shown[0]["targets"][1]["visible"]), "the secondary in-camera patch reaches drawing")
