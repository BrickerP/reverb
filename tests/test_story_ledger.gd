extends RefCounted
const PATH := "user://test_story_meta.json"


func test_milestones_and_choices_recover_distinct_clues_without_rng(c: Check) -> void:
	var sim := Sim.new(55)
	sim.start_run()
	var state: int = sim.rng.state
	var hazard: int = sim.hazard_rng.state
	sim.expedition.clear()
	for wave in [2, 4, 6, 8, 10]:
		sim.wave = wave
		StoryLedger.on_wave(sim)
	c.eq(StoryLedger.discovered(sim).size(), 5, "five wave fragments")
	c.eq(StoryLedger.receipt(sim).id, &"tomorrow", "latest meaningful fragment")
	StoryLedger.on_wave(sim)
	c.eq(StoryLedger.discovered(sim).size(), 5, "repeated milestone idempotent")
	var retirement := EchoRetirementInfo.new()
	StoryLedger.on_retire(sim, retirement)
	c.eq(StoryLedger.receipt(sim).id, &"retire", "active choice has its own response")
	retirement.exhausted = true
	StoryLedger.on_retire(sim, retirement)
	c.eq(StoryLedger.receipt(sim).id, &"exhausted", "waiting for wear has a distinct response")
	StoryLedger.on_repair(sim, 0.0)
	c.ok(not StoryLedger.discovered(sim).has(&"repair"), "failed repair does not create clue")
	StoryLedger.on_repair(sim, 40.0)
	c.eq(StoryLedger.receipt(sim).id, &"repair", "real repair has response")
	c.eq(sim.rng.state, state, "story leaves main RNG alone")
	c.eq(sim.hazard_rng.state, hazard, "story leaves hazard RNG alone")
	StoryLedger.dismiss(sim)
	c.ok(StoryLedger.receipt(sim).is_empty(), "optional receipt dismisses")
	c.eq(StoryLedger.discovered(sim).size(), 8, "dismiss never loses clues")


func test_boss_discovery_and_final_receipt_follow_expedition_decisions(c: Check) -> void:
	var routes: Array[StringName] = [&"compliance", &"solidarity", &"profit"]
	var endings: Array[StringName] = [&"released", &"collective", &"takeover"]
	for i in routes.size():
		var sim := Sim.new(5)
		sim.start_wave(WaveDirector.FINAL_WAVE)
		var boss := EnemyState.new()
		boss.uid = 99
		boss.def = Content.enemy(&"paradox")
		boss.dead = true
		sim.boss = boss
		sim.boss_shards.append(boss)
		sim.expedition["route"] = routes[i]
		sim.expedition["ending"] = endings[i]
		sim.expedition["completed_orders"] = [&"rescue", &"recruit"]
		sim.expedition["recruited_bosses"] = [&"foreman"]
		StoryLedger.on_wave(sim)
		var clues := StoryLedger.discovered(sim)
		c.ok(clues.has(&"signature"), "defeated boss reveals real encounter clue")
		c.ok(clues.has(StringName("route_%s" % routes[i])), "actual expedition route is archived")
		c.ok(clues.has(&"order_rescue") and clues.has(&"order_recruit"), "completed work orders have consequences")
		c.ok(clues.has(&"recruited_foreman"), "actual recruited boss has authored story")
		c.eq(StoryLedger.receipt(sim).id, StringName("ending_%s" % endings[i]), "three endings follow actual expedition outcome")


func test_unfinished_orders_and_unknown_endings_do_not_invent_story(c: Check) -> void:
	var sim := Sim.new(13)
	sim.expedition = {"route": &"unknown", "ending": &"unknown", "failed_orders": [&"recruit"], "recruited_bosses": []}
	StoryLedger.sync_expedition(sim)
	c.ok(StoryLedger.discovered(sim).is_empty(), "failed recruit and unknown outcomes cannot grant discoveries")


func test_archive_persists_only_known_clues_in_existing_meta_file(c: Check) -> void:
	var absolute := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	var meta := Meta.new(PATH)
	c.ok(StoryLedger.archive(meta).is_empty(), "fresh archive empty")
	c.ok(meta.discover_story([&"carbon", &"repair", &"invalid"]), "valid discoveries saved")
	c.ok(not meta.discover_story([&"carbon"]), "duplicates do not rewrite progress")
	var loaded := Meta.new(PATH)
	c.eq(loaded.story_clues, [&"carbon", &"repair"], "only known unique IDs persist")
	var rows := StoryLedger.archive(loaded)
	c.eq(rows.size(), 2, "archive lists found clues")
	c.eq(rows[0].name_key, "story.carbon_name", "localized title key exposed")
	c.eq(rows[1].body_key, "story.repair_body", "localized clue body exposed")
	DirAccess.remove_absolute(absolute)


func test_real_wave_and_repair_commit_triggers_respect_shop_undo(c: Check) -> void:
	var sim := Sim.new(17)
	sim.start_run()
	sim.start_wave(2)
	sim.wave_duration = 0.01
	sim.step(0.02, Vector2.ZERO)
	c.eq(sim.phase, Sim.Phase.SHOP, "actual survival finishes wave")
	c.ok(StoryLedger.discovered(sim).has(&"carbon"), "actual wave end discovers fragment")
	sim.player.materials = 500
	var take := sim.bank.takes[0]
	take.condition = 20.0
	c.ok(sim.shop.repair_echo(sim, take).ok, "repair transaction applies")
	c.ok(sim.shop.undo(sim).ok, "repair can be undone")
	sim.start_next_wave()
	c.ok(not StoryLedger.discovered(sim).has(&"repair"), "undone maintenance is not a committed choice")
	sim.wave_duration = 0.01
	sim.step(0.02, Vector2.ZERO)
	take = sim.bank.takes[0]
	take.condition = 20.0
	c.ok(sim.shop.repair_echo(sim, take).ok, "next maintenance applies")
	c.ok(sim.shop.repair_echo(sim, take).ok, "second maintenance in same shop applies")
	sim.start_next_wave()
	c.ok(StoryLedger.discovered(sim).has(&"repair"), "leaving shop commits actual repair choice")
	c.eq(sim.story_progress.get("repairs"), 2, "two committed transactions count as two choices")


func test_resumed_sim_retirement_event_is_connected_once(c: Check) -> void:
	var sim := Sim.new(29)
	sim.start_run()
	for i in 2:
		var take := EchoTake.new()
		take.samples = PackedVector2Array([sim.player.pos])
		take.weapons.append(Content.weapon(&"pistol"))
		take.levels.append(0)
		sim.bank.add(take)
	sim.start_wave(2)
	c.ok(sim.retire_selected_echo(), "first real retirement applies")
	c.eq(sim.story_progress.get("retirements"), 1, "actual retirement discovers choice once")
	var restored := RunSnapshot.restore(RunSnapshot.capture(sim))
	c.ok(restored != null, "active retirement state resumes")
	if restored == null:
		return
	restored.retire_cooldown = 0.0
	c.ok(restored.retire_selected_echo(), "resumed retirement applies")
	c.eq(restored.story_progress.get("retirements"), 2, "constructor reconnects real story event exactly once")
	c.eq(restored.retirements, 2, "retirement gameplay counter also connected exactly once")


func test_profile_write_failure_reports_and_can_retry_without_losing_clues(c: Check) -> void:
	var meta := Meta.new("user://missing_story_profile_folder/profile.json")
	c.ok(not meta.discover_story([&"carbon"]), "failed archive write never claims discovery persisted")
	c.eq(meta.last_error, "story.save_failed", "archive write error exposed")
	c.ok(meta.story_clues.is_empty(), "unwritten discovery can be retried")
	meta.path = PATH
	c.ok(meta.discover_story([&"carbon"]), "retry at writable profile succeeds")
	c.ok(Meta.new(PATH).story_clues.has(&"carbon"), "retried clue is durable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
