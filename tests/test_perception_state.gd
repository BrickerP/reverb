extends RefCounted

const DT := 1.0 / 60.0
const MAIN := preload("res://scenes/main.tscn")


func test_familiarity_records_only_known_completed_actions_and_survives_load(c: Check) -> void:
	var path := "user://test_familiar_actions.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var meta := Meta.new(path)
	c.ok(meta.familiar_actions.is_empty(), "old or absent meta starts without invented usage")
	c.ok(not meta.remember_action(&"imagined_action"), "unrecognized interaction is rejected")
	c.ok(meta.remember_action(&"retire"), "a completed supported action is persisted")
	c.ok(meta.remember_action(&"retire"), "repeat completion is idempotent")
	var loaded := Meta.new(path)
	c.eq(loaded.familiar_actions, [&"retire"], "only the completed action survives reload")
	c.eq(loaded.best_wave, 0, "learning a control grants no campaign progress")
	c.eq(loaded.wins, 0, "learning does not invent victory")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_known_discoveries_do_not_create_current_receipts_or_world_outcomes(c: Check) -> void:
	var sim := Sim.new(19)
	var known: Array[StringName] = [&"carbon", &"worker_saved", &"ending_collective"]
	StoryLedger.seed_known(sim, known)
	sim.start_run()
	c.ok(StoryLedger.discovered(sim).has(&"carbon"), "previous discovery remains known")
	c.eq(int(sim.expedition["rescued"]), 0, "past knowledge is not a rescued person now")
	c.eq(StringName(sim.expedition["ending"]), &"", "past ending is not selected in this run")
	StoryLedger.dismiss(sim)
	StoryLedger.seed_known(sim, known)
	c.ok(StoryLedger.receipt(sim).is_empty(), "seeding does not reannounce an old story")
	c.eq(sim.story_progress["clues"].size(), StoryLedger.discovered(sim).size(), "known clues are unique")


func test_busy_ready_retries_while_valid_and_never_after_consumption(c: Check) -> void:
	var sim := Sim.new(3)
	sim.start_run()
	sim.character_energy = 0.0
	var view := ArenaView.new()
	view.bind(sim)
	view._offer_moment(&"hurt", sim.player.pos)
	sim.character_energy = CharacterSkills.ENERGY_COST
	view._process(DT)
	c.ok(bool(view.perception_profile()["pending_ready"]), "a rejected ready accent remains pending")
	c.eq(view._moment.snapshot()["kind"], &"hurt", "damage retains attention first")
	view._process(0.4)
	c.ok(not bool(view.perception_profile()["pending_ready"]), "accepted retry consumes the pending accent")
	c.eq(view._moment.snapshot()["kind"], &"ready", "still-ready state gets one later opportunity")
	sim.character_energy = 0.0
	view._process(DT)
	view._offer_moment(&"hurt", sim.player.pos)
	sim.character_energy = CharacterSkills.ENERGY_COST
	view._process(DT)
	sim.character_energy = 0.0
	view._process(0.5)
	c.ok(not bool(view.perception_profile()["pending_ready"]), "consumed energy cancels stale ready")
	c.ok(view._moment.snapshot().is_empty(), "the obsolete cue is not replayed")
	view.unbind()
	c.near(view.transition_hold(), 0.0, 0.0001, "detach clears closure state")
	view.free()


func test_continuous_same_combo_does_not_renew_a_permanent_label(c: Check) -> void:
	var sim := Sim.new(17)
	sim.start_run()
	var hud := Hud.new()
	hud.bind(sim)
	var info := ComboInfo.new()
	info.id = &"pin_press"
	info.affected = 1
	hud.set_combo_feedback(info)
	var accepted := 0
	for frame in 180:
		hud._process(DT)
		hud.set_combo_feedback(info)
		if float(hud.perception_profile()["combo_left"]) > 0.0:
			accepted += 1
	c.ok(accepted > 30 and accepted < 150, "initial explanation exists and then leaves despite continued hits")
	c.near(float(hud.perception_profile()["combo_left"]), 0.0, 0.0001, "same-type repeat does not keep label alive")
	info.id = &"ink_arc"
	hud.set_combo_feedback(info)
	c.eq(hud.perception_profile()["combo"], &"ink_arc", "a newly encountered relation may be introduced")
	c.ok(float(hud.perception_profile()["combo_left"]) > 1.0, "new relation gets a readable first confirmation")
	hud.free()


func test_discovery_is_sustained_until_use_without_changing_model(c: Check) -> void:
	var sim := Sim.new(8)
	sim.start_run()
	var take := EchoTake.new()
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	take.stats = sim.player.stats.copy()
	take.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(80, 0)])
	sim.bank.add(take)
	sim.start_wave(3)
	var hud := Hud.new()
	hud.bind(sim)
	var before := RunSnapshot.capture(sim)
	c.ok(hud.skill_discovery(), "an unused role control remains findable")
	c.ok(hud.retirement_discovery(), "retirement can be discovered before low wear or the boss")
	for frame in 60:
		hud._process(DT)
	c.ok(hud.retirement_discovery(), "the cue does not expire just from elapsed view time")
	var familiar: Array[StringName] = [&"retire", &"skill_looper"]
	hud.set_familiar_actions(familiar)
	c.ok(not hud.skill_discovery() and not hud.retirement_discovery(), "completed controls retreat from novice emphasis")
	c.eq(RunSnapshot.capture(sim), before, "knowledge presentation never mutates the run")
	hud.free()


func test_last_real_rescue_closes_before_boon_or_shop(c: Check) -> void:
	var directory := ProjectSettings.globalize_path("user://perception_closure_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var environment := {}
	for key: String in ["REVERB_SAVE", "REVERB_SUSPEND", "REVERB_SETTINGS", "REVERB_RUN_LOG", "REVERB_FEEDBACK_LOG"]:
		environment[key] = OS.get_environment(key)
		OS.set_environment(key, directory.path_join(key.to_lower() + ".json"))
	var main := MAIN.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.set_physics_process(false)
	main.new_run(11, &"looper")
	var sim: Sim = main.sim
	sim.start_wave(2)
	sim._plan_idx = sim._plan.size()
	sim.pending.clear()
	sim.enemies.clear()
	var target := {}
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			target = item
			break
	c.ok(not target.is_empty(), "real natural worker exists")
	if not target.is_empty():
		sim.player.pos = target["pos"] + Vector2(-50, 0)
		c.ok(sim.interact(), "actual rescue succeeds before final clear")
		c.ok(main.meta.familiar_actions.has(&"rescue"), "successful world action records its real use")
		c.ok(main._view.transition_hold() >= 0.85, "first result retains a visible closure window")
		sim.pending_boons.append(Boon.DAMAGE)
		main._physics_process(DT)
		c.eq(sim.phase, Sim.Phase.SHOP, "empty finite work reaches the actual post-combat phase")
		c.ok(not main.boon_ui.visible and not main.shop_ui.visible, "new decisions cannot cover the first rescue immediately")
		c.eq(main.transition_profile()["target"], &"boon", "the pending next decision remains explicit")
		c.ok(float(main.transition_profile()["remaining"]) > 0.80, "the saved transition delay includes necessary result closure")
		main._view._process(0.95)
		main._physics_process(0.95)
		c.ok(main.boon_ui.visible, "the real reward choice opens after closure, not an extra tutorial")
	main._detach_presentation_session()
	main.free()
	for key: String in environment:
		OS.set_environment(key, environment[key])
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
