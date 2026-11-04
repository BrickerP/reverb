extends RefCounted


func _sim(count: int = 8) -> Sim:
	var sim := Sim.new(2071)
	sim.start_run()
	sim.phase = Sim.Phase.WAVE
	sim.enemies.clear()
	sim.pending.clear()
	sim.projectiles.clear()
	sim.attack_fields.clear()
	sim.bank.takes.clear()
	sim.echoes.clear()
	sim.bank.set_next_uid(101)
	for index in count:
		var take := EchoTake.new()
		take.wave = index + 1
		take.samples = PackedVector2Array([Vector2(300 + index * 40, 300), Vector2(320 + index * 40, 300)])
		take.weapons.append(Content.weapon(&"pistol"))
		take.levels.append(0)
		take.stats = sim.player.stats.copy()
		sim.bank.add(take)
		sim.echoes.append(EchoActor.new(take, index))
	sim.selected_echo_uid = sim.echoes[count - 1].take.uid if count > 0 else 0
	return sim


func _selected_count(sim: Sim) -> int:
	var count := 0
	for actor in sim.echoes:
		if bool(EchoInk.profile(actor, sim)["selected"]):
			count += 1
	return count


func test_selected_body_uses_saved_uid_and_not_the_compacted_slot(c: Check) -> void:
	var sim := _sim()
	var actor := sim.echoes[7]
	var uid := actor.take.uid
	var before := EchoInk.profile(actor, sim)
	c.eq(before["uid"], uid, "body state carries the real persisted identity")
	c.ok(uid > 8 and before["selected"], "selection uses the saved UID rather than an eight-slot index")
	c.eq(_selected_count(sim), 1, "eight deployed copies have exactly one selected body")
	actor.index = 0
	c.ok(EchoInk.profile(actor, sim)["selected"], "compacting or reordering a slot cannot change selected identity")
	c.ok(sim.select_echo(sim.echoes[0].take.uid), "another real UID can become selected")
	c.ok(not EchoInk.profile(actor, sim)["selected"], "old selected body loses its persistent mark immediately")
	c.eq(_selected_count(sim), 1, "new selection never leaves two selected bodies")
	var previous := sim.echoes[0]
	var restored := EchoActor.new(previous.take, 0)
	sim.echoes[0] = restored
	c.ok(EchoInk.profile(restored, sim)["selected"], "a rebuilt actor keeps selection through its saved UID")
	c.ok(not EchoInk.profile(previous, sim)["selected"], "the replaced actor object cannot keep duplicate selection ink")
	sim.selected_echo_uid = 0
	c.eq(_selected_count(sim), 0, "an empty selection cannot accidentally highlight slot zero")


func test_selected_brackets_are_quiet_and_all_persistent_states_coexist(c: Check) -> void:
	var sim := _sim()
	var actor := sim.echoes[7]
	actor.take.condition = 20.0
	actor.take.merged = true
	actor.rewinding = true
	sim.echo_silenced = 2.0
	var bounds := Rect2(420, 220, 42, 56)
	var normal := EchoInk.profile(actor, sim, 0.0, false)
	var quiet := EchoInk.profile(actor, sim, 9000.0, true)
	for key in ["uid", "selected", "condition", "state_priority", "body_tint", "alpha", "paper_scale"]:
		c.eq(normal[key], quiet[key], "sustained state never blinks with render time or reduced mode")
	c.eq(normal["state_priority"], &"muted", "silence remains the leading state when selection and expiry coexist")
	c.ok(normal["selected"] and normal["merged"] and normal["rewinding"] and normal["expiring"],
			"selection cannot hide binding, rewind or low-condition state")
	var geometry := EchoInk.mark_geometry(bounds, normal)
	c.eq(geometry, EchoInk.mark_geometry(bounds, quiet), "eight-copy sustained geometry is identical in reduced effects")
	c.eq(geometry["selection"].size(), 2, "one quiet open bracket is attached to each side of the selected body")
	for line: PackedVector2Array in geometry["selection"]:
		c.ok(line[0] != line[line.size() - 1], "selection remains open ink, never a closed danger or blast radius")
		for point in line:
			c.ok(bounds.has_point(point), "selection stays attached to the actual body crop")
			c.ok(point.y > bounds.position.y + bounds.size.y * 0.39 \
					and point.y < bounds.position.y + bounds.size.y * 0.73,
					"side marks leave the upper binding and lower torn-edge band distinct")
	c.eq(geometry["staples"].size(), 1, "merged state retains its physical upper binding")
	c.ok(not geometry["mute_contour"].is_empty() and not geometry["expiry"].is_empty(),
			"silence and exhaustion warning remain separate sustained marks")
	sim.echo_silenced = 0.0
	c.eq(EchoInk.profile(actor, sim)["state_priority"], &"expiring", "ending silence immediately restores low-condition priority")
	actor.take.condition = EchoSystem.LOW_CONDITION + 0.01
	c.eq(EchoInk.profile(actor, sim)["state_priority"], &"merged", "repairing above the actual threshold removes the torn-edge warning")


func test_active_and_natural_retirement_reassign_mark_without_reusing_identity(c: Check) -> void:
	var sim := _sim()
	var active := sim.echoes[7]
	var events: Array[EchoRetirementInfo] = []
	sim.echo_retired.connect(func(info: EchoRetirementInfo) -> void: events.append(info))
	c.ok(sim.retire_selected_echo(), "the actual selected copy can retire actively")
	c.eq(events.size(), 1, "one consumed UID emits one retirement receipt")
	c.eq(events[0].reason, EchoRetirementInfo.ACTIVE, "active retirement retains its true reason")
	c.eq(events[0].uid, active.take.uid, "active receipt retains the consumed persisted UID")
	c.ok(not EchoInk.profile(active, sim)["selected"], "a removed body's retained reference cannot keep selection ink")
	c.eq(_selected_count(sim), 1, "a surviving real UID receives the mark in the same retirement call")
	var natural := EchoSystem.selected_actor(sim)
	var natural_uid := natural.take.uid
	natural.take.condition = 0.01
	EchoSystem.step(sim, 0.1)
	c.eq(events.size(), 2, "natural exhaustion has one independent receipt")
	c.eq(events[1].reason, EchoRetirementInfo.EXHAUSTED, "quiet exhaustion is not relabeled as an active skill")
	c.eq(events[1].uid, natural_uid, "exhaustion receipt retains its consumed UID")
	c.eq(events[1].damage, 0.0, "exhaustion cannot acquire the active retirement's damage")
	c.ok(not EchoInk.profile(natural, sim)["selected"], "exhausted reference cannot keep a selected marker")
	c.eq(_selected_count(sim), 1, "the next surviving UID is selected after natural exhaustion")
	for actor in sim.echoes:
		var data := EchoInk.profile(actor, sim)
		c.eq(data["selected"], actor.take.uid == sim.selected_echo_uid,
				"reindexed actors follow the model's current saved selection")


func test_selection_never_invents_null_detached_or_exhausted_bodies(c: Check) -> void:
	var sim := _sim(1)
	var actor := sim.echoes[0]
	c.ok(not EchoInk.profile(null, sim)["selected"], "null actor cannot own selection")
	c.ok(not EchoInk.profile(actor, null)["selected"], "missing model cannot own selection")
	var missing := EchoActor.new(EchoTake.new(), 0)
	missing.take = null
	c.ok(not EchoInk.profile(missing, sim)["selected"], "missing take cannot own selection")
	sim.echoes.clear()
	c.ok(not EchoInk.profile(actor, sim)["selected"], "a detached actor cannot impersonate the current selected UID")
	sim.echoes.append(actor)
	actor.take.condition = 0.0
	var empty := EchoInk.profile(actor, sim)
	c.ok(not empty["selected"] and not empty["visible"], "zero condition cannot retain live selection")
	c.ok(EchoInk.mark_geometry(Rect2(0, 0, 42, 56), empty)["selection"].is_empty(),
			"an exhausted body cannot leave selected brackets floating alone")
	actor.take.condition = NAN
	c.ok(not EchoInk.profile(actor, sim)["valid"], "non-finite condition cannot submit state ink")
	c.ok(is_nan(actor.take.condition), "presentation cannot repair authoritative condition")


func test_eight_copy_wheel_keeps_uid_after_retirement_and_has_no_reading_timeout(c: Check) -> void:
	Controls.register()
	var sim := _sim()
	var wheel := EchoSelectionWheel.new()
	wheel.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(wheel)
	for reduced in [false, true]:
		wheel.reduced_effects = reduced
		wheel.open(sim)
		var uid := sim.selected_echo_uid
		var count := sim.bank.takes.size()
		c.eq(wheel.buttons.size(), 8, "all eight deployed UIDs have separate wheel targets")
		for _read in 40:
			wheel._highlight(wheel._selected)
		c.ok(wheel.visible, "reading a selected entry cannot time out or dismiss the wheel")
		c.eq(wheel.selected_uid(), uid, "reading preserves the selected persisted UID")
		c.eq(sim.bank.takes.size(), count, "reading cannot consume or wear a copy")
		c.eq(wheel.close(), uid, "release returns the selected UID without retiring it")
		wheel.open(sim)
		wheel._highlight(0)
		wheel.cancel()
		c.eq(wheel.close(), 0, "cancel followed by release never commits a highlighted UID")
		c.eq(sim.selected_echo_uid, uid, "cancel keeps the model's original selection")
	c.ok(sim.retire_selected_echo(), "selected UID can leave after the wheel has closed")
	wheel.open(sim)
	c.eq(wheel.buttons.size(), 7, "reopening the wheel removes the consumed entry")
	c.eq(wheel.selected_uid(), sim.selected_echo_uid, "reopened wheel uses the newly selected UID after reindexing")
	wheel.free()
