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


func test_machine_hand_and_service_grip_share_real_contact_at_all_legal_reaches(c: Check) -> void:
	var source := Vector2(1000, 700)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	for distance: float in [80.0, 112.0]:
		for direction: Vector2 in directions:
			var target := source + direction * distance
			var event := {"pos": source, "target_pos": target, "target_kind": &"press", "ok": true}
			for reduced: bool in [false, true]:
				var pose := InteractionInk.interaction_pose(event, 0.5, reduced)
				c.eq(pose["pivot"], target, "control pivot remains on the real service point")
				c.ok((pose["hand"] as Vector2).distance_to(pose["grip"]) <= 1.0,
					"paper hand actually grasps the same handle at every80/112px direction")
				c.ok(bool(pose["contact"]), "the working stroke is inside the actual grasp interval")
				c.near(float(pose["working_travel"]), 12.0, 0.001, "successful operation completes its short downward stroke")
				c.ok((pose["hand"] as Vector2).distance_to(source) < 52.0,
					"the long control linkage reaches the body without stretching an arm across the full interaction range")
				for point: StringName in [&"shoulder", &"elbow", &"hand", &"pivot", &"grip"]:
					c.ok((pose[point] as Vector2).is_finite(), "folded interaction geometry is finite")


func test_failed_control_jams_without_a_working_stroke_and_repair_avoids_the_face(c: Check) -> void:
	var source := Vector2(600, 400)
	var event := {"pos": source, "target_pos": source + Vector2(112, 0), "target_kind": &"press", "ok": false}
	for reduced: bool in [false, true]:
		var failed := InteractionInk.interaction_pose(event, 0.5, reduced)
		c.ok(not bool(failed["ok"]), "failed operation keeps the rejection branch")
		c.near(float(failed["working_travel"]), -2.0, 0.001, "failed control only makes a short reverse jam")
		c.ok((failed["hand"] as Vector2).distance_to(failed["grip"]) <= 1.0,
			"blocked hand still contacts its real grip instead of stopping in empty air")
		c.ok((failed["grip"] as Vector2).y <= (failed["resting_grip"] as Vector2).y,
			"failure cannot enter a positive working stroke")
		var repair := InteractionInk.interaction_pose({"pos": source, "target_pos": source,
			"target_kind": &"repair", "ok": true}, 0.5, reduced)
		c.eq(repair["pivot"], source, "coincident service point remains authoritative")
		c.ok((repair["shoulder"] as Vector2).y >= source.y - 6.0, "repair sleeve starts on the coat rather than the face")
		c.ok((repair["grip"] as Vector2).y > source.y, "held repair paper stays beside the low hand")
		c.ok((repair["hand"] as Vector2).distance_to(repair["grip"]) <= 1.0, "repair hand and tool share contact")
	var settled := InteractionInk.interaction_pose(event, 1.0)
	c.eq(settled["working_travel"], 0.0, "normal control returns from its brief jam")
	c.ok(not bool(settled["contact"]), "normal hand releases the handle before receipt expiry")


func test_interaction_arm_follows_the_live_body_while_the_pivot_stays_on_the_machine(c: Check) -> void:
	var sim := Sim.new(507)
	sim.player.pos = Vector2(600, 400)
	var captured := sim.player.pos
	var machine := captured + Vector2(112, 0)
	var ink := InteractionInk.new()
	ink.consume_world({"kind": &"interaction_result", "actor_token": -1, "pos": captured,
		"target_pos": machine, "target_kind": &"press", "ok": true})
	sim.player.pos += Vector2(28, 12)
	var rng := sim.rng.state
	var shown := ink.profiles(VIEW, false, sim)[0]
	c.eq(shown["pos"], sim.player.pos, "the reaching body does not remain at its old click position")
	var pose := InteractionInk.interaction_pose(shown, 0.5)
	c.ok((pose["shoulder"] as Vector2).distance_to(sim.player.pos) < 14.0, "shoulder follows the current collision body")
	c.eq(pose["pivot"], machine, "moving during interaction cannot drag the machine with the player")
	c.ok((pose["hand"] as Vector2).distance_to(pose["grip"]) <= 1.0, "moving grip and paper hand still share exact contact")
	c.eq(ink.profiles(VIEW)[0]["pos"], captured, "pure fixture retains its detached original source value")
	c.eq(sim.rng.state, rng, "following a live body cannot consume gameplay RNG")
	var take := EchoTake.new()
	take.samples = PackedVector2Array([captured])
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	ink.consume_world({"kind": &"interaction_result", "actor_token": take.uid, "pos": captured,
		"target_pos": machine, "target_kind": &"press", "ok": true})
	actor.pos = captured + Vector2(-20, 30)
	c.eq(ink.profiles(VIEW, false, sim).back()["pos"], actor.pos, "a copy arm follows its UID rather than the original body")


func test_real_echo_machine_work_uses_one_stable_uid_hand_without_replaying_output(c: Check) -> void:
	var sim := Sim.new(508)
	sim.start_run()
	var ink := InteractionInk.new()
	sim.world_event.connect(ink.consume_world)
	sim.echo_work_performed.connect(ink.consume_echo_work)
	var site: Dictionary = {}
	var machine: Dictionary = {}
	for row: Dictionary in sim.interactables:
		if row["id"] == &"machine_1":
			site = row
	for row: Dictionary in sim.expedition["world"]["machines"]:
		if row["id"] == &"machine_1":
			machine = row
	c.ok(not site.is_empty() and not machine.is_empty(), "existing conveyor has an actual UI interaction entry")
	if site.is_empty() or machine.is_empty():
		return
	site["cooldown"] = 0.0
	machine["status"] = &"operating"
	machine["stopped"] = false
	var take := EchoTake.new()
	take.samples = PackedVector2Array([site["pos"], site["pos"]])
	take.work_actions = [{"time": 0.0, "kind": &"conveyor", "target_id": &"machine_1",
		"pos": site["pos"], "weapon_id": &"", "aim": Vector2.ZERO}]
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	sim.echoes.append(actor)
	var direction: Vector2 = site["direction"]
	var money := sim.player.materials
	var recorded := sim.recorder.work_actions.duplicate(true)
	actor.t = 0.016
	EchoWork.step(sim, actor, 0.0, 0.016)
	c.eq(site["direction"], -direction, "real replay operates conveyor exactly once")
	c.eq(take.condition, 96.0, "real replay pays only the normal work condition")
	c.eq(sim.player.materials, money, "presentation spends no extra materials")
	c.eq(sim.recorder.work_actions, recorded, "receipt cannot recursively record an action")
	c.eq(ink.counts()["world"], 1, "machine_operated plus work event cannot duplicate the hand")
	var shown := ink.profiles(VIEW, false, sim)[0]
	c.eq(shown["actor_token"], take.uid, "working hand belongs to stable Echo UID")
	c.eq(shown["target_id"], &"machine_1", "receipt preserves actual machine identity")
	var other_take := EchoTake.new()
	other_take.samples = PackedVector2Array([actor.pos + Vector2(40, 0)])
	sim.bank.add(other_take)
	var other := EchoActor.new(other_take, 1)
	sim.echoes.push_front(other)
	actor.index = 1
	actor.pos += Vector2(10, 5)
	shown = ink.profiles(VIEW, false, sim)[0]
	c.eq(shown["pos"], actor.pos, "array reorder never moves work to another copy")
	var pose := InteractionInk.interaction_pose(shown, 0.5)
	c.ok((pose["hand"] as Vector2).distance_to(pose["grip"]) <= 1.0, "replayed worker grasps the real linkage")
	sim.echoes.erase(actor)
	c.eq(ink.profiles(VIEW, false, sim).size(), 0, "removed worker leaves no detached live arm")
	c.eq(ink.profiles(VIEW).size(), 1, "detached audit receipt remains a bounded value")


func test_unreachable_echo_failures_keep_reason_without_inventing_control_contact(c: Check) -> void:
	var ink := InteractionInk.new()
	for reason: StringName in [&"distant", &"muted", &"sealed", &"condition", &"unavailable"]:
		ink.consume_echo_work({"uid": 91, "kind": &"press", "target_id": &"machine_0",
			"pos": Vector2(500, 360), "target_pos": Vector2(1500, 360), "success": false, "reason": reason})
		var p := ink.profiles(VIEW)[0]
		c.eq(p["reason"], reason, "actual blocked cause survives in the receipt")
		c.ok(not bool(p["ok"]), "unavailable work cannot become successful")
		c.ok(not bool(InteractionInk.interaction_pose(p, 0.5)["visible"]), "blocked work has no invented remote lever grasp")
		c.ok(not bool(ink.actor_pose(91)["active"]), "blocked replay cannot look like a completed working body stroke")
	ink.consume_echo_work({"uid": 92, "kind": &"signature", "pos": Vector2(500, 360), "success": true})
	c.eq(ink.counts()["world"], 1, "signature rich shot event owns its attack without an extra control arm")


func test_skill_receipts_select_live_echo_uid_and_pause_without_simulation_changes(c: Check) -> void:
	var sim := Sim.new(509)
	sim.start_run()
	var ink := InteractionInk.new()
	var snapshot := RunSnapshot.capture(sim)
	var event := {"kind": &"character_skill", "ability": &"mirror", "actor_token": -1,
		"pos": Vector2(500, 360), "target_pos": Vector2(600, 360), "ok": true, "selected_uid": 82,
		"anchors": [{"uid": 82, "from_pos": Vector2(600, 360), "to_pos": Vector2(500, 360)},
			{"uid": 83, "from_pos": Vector2(700, 360), "to_pos": Vector2(700, 360)}]}
	ink.consume_world(event)
	event["anchors"][0]["uid"] = 999
	event["selected_uid"] = 83
	c.ok(bool(ink.actor_pose(-1)["active"]), "original receives its committed body action")
	c.ok(bool(ink.actor_pose(82)["active"]), "selected UID receives the paired fold")
	c.ok(not bool(ink.actor_pose(83)["active"]), "unselected copy does not borrow the skill")
	ink.step(0.3)
	var pose := ink.actor_pose(82)
	ink.step(0.4, true)
	c.eq(ink.actor_pose(82), pose, "pause freezes paper body sequence")
	c.eq(RunSnapshot.capture(sim), snapshot, "drawing actions cannot move bodies or add invulnerability")
	ink.step(InteractionInk.SKILL_TIME)
	c.ok(not bool(ink.actor_pose(-1)["active"]), "skill choreography always settles")
	ink.consume_world({"kind": &"character_skill", "ability": &"mirror", "pos": Vector2(500, 360), "ok": false})
	c.eq(ink.counts()["active"], 0, "failed missing-Echo activation cannot create a success body pose")


func test_real_rescue_captures_source_and_destination_without_duplicate_rewards(c: Check) -> void:
	var sim := Sim.new(510)
	sim.start_run()
	var ink := InteractionInk.new()
	var events: Array[Dictionary] = []
	sim.world_event.connect(ink.consume_world)
	sim.world_event.connect(func(info: Dictionary) -> void:
		if info.get("kind") == &"worker_saved":
			events.append(info.duplicate(true)))
	var worker: Dictionary = sim.expedition["world"]["workers"][0]
	var source: Vector2 = worker["pos"]
	sim.player.pos = source
	var money := sim.player.materials
	c.ok(sim.interact(), "real nearest-worker input commits rescue")
	c.eq(events.size(), 1, "one rescue emits one departure")
	if events.is_empty():
		return
	var target: Vector2 = worker["pos"]
	c.eq(events[0]["from_pos"], source, "rescue exposes old danger position")
	c.eq(events[0]["target_pos"], target, "rescue exposes committed safe position")
	c.eq(worker["state"], &"safe", "safe simulation commit remains immediate")
	c.eq(sim.player.materials, money, "presentation adds no reward or cost")
	var reward := int(sim.expedition["solidarity"])
	sim.interact()
	c.eq(sim.expedition["solidarity"], reward, "second input cannot reward rescue twice")
	c.eq(events.size(), 1, "used rescue cannot add a second departure")
	var receipt: Dictionary = {}
	for p: Dictionary in ink.profiles(VIEW):
		if p["family"] == &"rescue":
			receipt = p
	c.ok(not receipt.is_empty(), "rescue reaches physical feedback")
	if receipt.is_empty():
		return
	events[0]["from_pos"] = Vector2.ZERO
	c.eq(receipt["from_pos"], source, "rescue receipt keeps immutable source")
	var start := ink.worker_pose(worker["id"])
	c.ok(not bool(start["safe_visible"]), "departure owns the only body presentation before arrival")
	c.ok(bool(ink.worker_pose(worker["id"], true)["safe_visible"]), "Reduced shows real safe body immediately")
	c.eq(ink.worker_pose(worker["id"], true)["departure_alpha"], 0.0, "Reduced omits decorative travelling duplicate")
	ink.step(0.25)
	var departure := ink.worker_pose(worker["id"])
	c.ok((departure["departure_pos"] as Vector2).distance_to(source) <= 42.0, "departure is a short source step, never a body crossing walls")
	ink.step(0.3, true)
	c.eq(ink.worker_pose(worker["id"]), departure, "pause freezes rescue before arrival")
	ink.step(0.4)
	c.ok(bool(ink.worker_pose(worker["id"])["safe_visible"]), "safe actual body settles after departing outline")
	c.eq(ink.worker_pose(worker["id"])["departure_alpha"], 0.0, "source outline expires before the safe body appears")
	ink.step(InteractionInk.RESCUE_TIME)
	c.eq(ink.worker_pose(worker["id"])["safe_scale"], Vector2.ONE, "finished rescue leaves stable persistent survivor")
	for row: Dictionary in sim.expedition["world"]["history"]:
		c.ok(not row.has("from_pos") and not row.has("target_pos"), "presentation endpoints never enter strict persistent history schema")


func test_rejected_rescue_and_reset_leave_no_hidden_safe_body(c: Check) -> void:
	var ink := InteractionInk.new()
	var event := {"kind": &"worker_saved", "subject": &"worker_1", "pos": Vector2(200, 200),
		"from_pos": Vector2(600, 400), "target_pos": Vector2(200, 200), "ok": false}
	ink.consume_world(event)
	c.eq(ink.counts()["active"], 0, "rejected rescue cannot break shackles or hide safe body")
	event["ok"] = true
	event["from_pos"] = Vector2(NAN, 0)
	ink.consume_world(event)
	c.eq(ink.counts()["active"], 0, "invalid rescue source cannot become a false origin")
	event["from_pos"] = Vector2(600, 400)
	ink.consume_world(event)
	c.ok(not bool(ink.worker_pose(&"worker_1")["safe_visible"]), "valid rescue starts finite departure")
	ink.reset()
	c.ok(bool(ink.worker_pose(&"worker_1")["safe_visible"]), "session reset cannot leave another registry body hidden")
	c.eq(ink.counts()["active"], 0, "detached session retains no body actions")


func test_real_skill_shift_does_not_count_as_a_stride_and_unbind_disconnects_receipts(c: Check) -> void:
	var sim := Sim.new(511)
	sim.start_run()
	sim.player.pos = Vector2(600, 400)
	var view := ArenaView.new()
	view.bind(sim)
	view._actor_motion[-1] = {"phase": 1.25, "moving": true, "amount": 0.7}
	sim.role_effects["rewind_history"] = [Vector2(550, 400)]
	c.ok(sim.activate_character_skill(), "real short Looper shift commits")
	c.eq(view._actor_positions[-1], sim.player.pos, "short discontinuity updates the motion sample")
	c.eq(view._actor_motion[-1]["phase"], 1.25, "skill does not advance or reset the distance gait phase")
	c.ok(not bool(view._actor_motion[-1]["moving"]), "shift is not interpreted as one frame of walking")
	c.ok(bool(view._interaction_ink.actor_pose(-1)["active"]), "world event reaches actual bound view body choreography")
	view.set_paused(true)
	var before := view._interaction_ink.profiles(VIEW)
	view._process(0.4)
	c.eq(view._interaction_ink.profiles(VIEW), before, "bound paused view freezes all action receipts")
	view.unbind()
	c.eq(view._interaction_ink.counts()["active"], 0, "unbind clears body and rescue sessions")
	sim.world_event.emit({"kind": &"character_skill", "ability": &"solo", "actor_token": -1,
		"pos": sim.player.pos, "target_pos": sim.player.pos, "ok": true})
	sim.echo_work_performed.emit({"uid": 77, "kind": &"press", "target_id": &"machine_0",
		"pos": sim.player.pos, "target_pos": sim.player.pos, "success": true, "reason": &"performed"})
	c.eq(view._interaction_ink.counts()["active"], 0, "old simulator cannot send actions into a detached view")
	view.free()


func test_rejected_anchor_skill_keeps_new_selection_instead_of_previous_anchor(c: Check) -> void:
	for role: StringName in [&"mirror", &"conductor"]:
		for reason: StringName in [&"energy", &"cooldown", &"phase"]:
			var sim := Sim.new(512)
			Content.character(role).apply(sim)
			sim.start_run()
			var ink := InteractionInk.new()
			var events: Array[Dictionary] = []
			sim.world_event.connect(ink.consume_world)
			sim.world_event.connect(func(info: Dictionary) -> void:
				if info.get("kind") == &"character_skill":
					events.append(info.duplicate(true)))
			for index in 2:
				var take := EchoTake.new()
				take.samples = PackedVector2Array([Vector2(600 + index * 120, 400), Vector2(610 + index * 120, 400)])
				take.weapons.append(Content.weapon(&"pistol"))
				take.levels.append(0)
				sim.bank.add(take)
				sim.echoes.append(EchoActor.new(take, index))
			var first_uid := sim.echoes[0].take.uid
			var next_uid := sim.echoes[1].take.uid
			sim.selected_echo_uid = first_uid
			c.ok(sim.activate_character_skill(), "%s first activation anchors actual A" % role)
			c.eq(events.back()["selected_uid"], first_uid, "successful event names committed A")
			c.eq(sim.role_effects["anchor_uid"], first_uid, "previous anchor remains A during failure fixture")
			ink.reset()
			sim.selected_echo_uid = next_uid
			sim.character_energy = 0.0 if reason == &"energy" else CharacterSkills.ENERGY_COST
			sim.character_cooldown = 1.0 if reason == &"cooldown" else 0.0
			if reason == &"phase":
				sim.phase = Sim.Phase.SHOP
			var before := RunSnapshot.capture(sim)
			c.ok(not sim.activate_character_skill(), "%s rejects actual %s boundary" % [role, reason])
			c.eq(events.size(), 2, "one failed input produces one result event")
			c.eq(events.back()["selected_uid"], next_uid, "failed input names newly selected B, never stale anchor A")
			c.eq(events.back()["reason"], reason, "failure retains actual rejection reason")
			c.ok(not bool(events.back()["ok"]), "new selection cannot turn rejected input into success")
			c.eq(RunSnapshot.capture(sim), before, "rejection spends and moves nothing")
			c.eq(ink.counts()["active"], 0, "rejected result cannot add a success appearance")
			c.ok(not bool(ink.actor_pose(next_uid)["active"]), "selected B cannot borrow A's previous pose")
