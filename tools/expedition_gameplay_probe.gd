extends SceneTree
# Native 0.15 Main/input evidence. Scenario setup is synthetic and disclosed in
# summary.json; subsequent UI, transactions, collisions and mission rules are real.
# REVERB_LANG=en|zh REVERB_PROBE_SIZE=1280x720|960x540 REVERB_PROBE_REDUCED=0|1
# godot --path . --disable-vsync --script res://tools/expedition_gameplay_probe.gd

const DEADLINE_MSEC := 180000
const SEED := 150150
const ROLES: Array[StringName] = [&"looper", &"solo", &"mirror", &"conductor", &"mender", &"overloader"]
const FILES := {"REVERB_SAVE": "meta.json", "REVERB_SETTINGS": "settings.json", "REVERB_RUN_LOG": "runs.jsonl", "REVERB_FEEDBACK_LOG": "feedback.jsonl", "REVERB_SUSPEND": "suspend.json"}

var _main: Node
var _out := ""
var _started := Time.get_ticks_msec()
var _frames := 0
var _finished := false
var _size := Vector2i(1280, 720)
var _failures: Array[String] = []
var _shots_by_weapon: Dictionary = {}
var _summary := {"probe": "expedition_gameplay_0_15", "coverage": [], "fixtures": [], "screenshots": {}, "checks": [], "results": {}, "peak_counts": {},
	"coverage_meaning": "Executed scenario IDs; success additionally requires failures to be empty",
	"disclosure": "Scripted clinical fixtures, not a human playthrough or usability test. Canonical Main/Sim methods create stages; disclosed loadouts, budgets, positions and route counters shorten setup. Real Input.parse_input_event press/release drives UI and abilities. Main physics is frozen during decisions and explicitly advanced at 60 Hz during battle. Native force_draw captures real pixels even when occluded. Rendering negative controls are owned by expedition_art_probe."}


func _initialize() -> void:
	Engine.max_fps = 60
	RenderingServer.render_loop_enabled = false
	var language := OS.get_environment("REVERB_LANG")
	Loc.lang = language if language in ["en", "zh"] else "en"
	var dimensions := OS.get_environment("REVERB_PROBE_SIZE")
	if dimensions == "":
		dimensions = "1280x720"
	var parts := dimensions.split("x")
	if parts.size() == 2 and int(parts[0]) >= 640 and int(parts[1]) >= 480:
		_size = Vector2i(int(parts[0]), int(parts[1]))
	root.content_scale_size = _size
	DisplayServer.window_set_size(_size)
	var reduced := OS.get_environment("REVERB_PROBE_REDUCED") == "1"
	var profile := "%s-%s-%s" % [Loc.lang, "reduced" if reduced else "standard", dimensions]
	_out = ProjectSettings.globalize_path("res://shots/expedition-gameplay/" + profile)
	var isolated := "user://expedition_gameplay_probe/" + profile
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	for key: String in FILES:
		var path := isolated.path_join(FILES[key])
		OS.set_environment(key, path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("REVERB_RUN_SOURCE", "expedition_gameplay_fixture")
	_summary["profile"] = profile
	_summary["isolated_user_files"] = {}
	for key: String in FILES:
		_summary.isolated_user_files[key] = OS.get_environment(key)
	_summary["requested_canvas"] = [_size.x, _size.y]
	_summary["native_display"] = DisplayServer.get_name()
	if not _check(DisplayServer.get_name() != "headless", "native_display_required"):
		_finish()
		return
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_main.set_physics_process(false)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _finished:
		return false
	if Time.get_ticks_msec() - _started > DEADLINE_MSEC:
		_check(false, "deadline_180_seconds")
		_finish()
		return false
	RenderingServer.force_draw()
	if _main != null and _main.sim != null:
		var sim: Sim = _main.sim
		var counts := {"enemies": sim.enemies.size(), "projectiles": sim.projectiles.size(), "fields": sim.attack_fields.size(), "support": sim.support_units.size(), "echoes": sim.echoes.size()}
		for key: String in counts:
			_summary.peak_counts[key] = maxi(int(_summary.peak_counts.get(key, 0)), counts[key])
	return false


func _run() -> void:
	await _wait(0.2)
	_main.settings.reduced_effects = OS.get_environment("REVERB_PROBE_REDUCED") == "1"
	_main.settings.fullscreen = false
	_main.settings.save()
	_main._apply_reduced_effects()
	_check(root.get_visible_rect().size == Vector2(_size), "native_logical_canvas_matches_pixels")
	for role in ROLES:
		_main.meta.unlocked[role] = true
	_main.character_select.refresh(_main.meta)
	_fixture("title", "All six role unlocks staged in isolated Meta; fixed seed entered in the real title seed field")
	_main.character_select.seed_edit.text = str(SEED)
	if _main.character_select.page_next.is_visible_in_tree():
		await _shot("title_roles_page_1")
		await _activate(_main.character_select.page_next, true)
		_check(_main.character_select.page == 1 and _main.character_select._cards[3].has_focus(), "controller_A_exposes_second_character_page_and_focus")
		await _shot("title_roles_page_2")
		await _activate(_main.character_select.page_previous, true)
	else:
		await _shot("title_six_roles")
	await _activate(_main.character_select._cards[0])
	_check(_main.sim != null and _main.sim.character_id == &"looper", "title_card_starts_actual_main_run")
	await _recording_beat()
	await _equipment()
	await _evolutions()
	await _echo_traits()
	await _credit_and_reroll()
	await _missions()
	await _skills()
	await _save_continue()
	await _endings()
	await _archive()
	_finish()


func _recording_beat() -> void:
	var sim := _battle("recording_archive", &"looper")
	await _move_right(0.5)
	sim._end_wave()
	_main._sync_phase()
	var take: EchoTake = sim.bank.takes.back()
	_check(take.samples.size() >= 10 and _main._view._beat_take == take, "wave_end_uses_actual_recorded_route_for_paper_puppet_archive")
	var before := RunSnapshot.capture(sim)
	var was_processing: bool = _main._view.is_processing()
	_main._view.set_process(false)
	var previous := 0.0
	for progress: float in [0.15, 0.4, 0.7]:
		_main._view._process((progress - previous) * ArenaView.RECORD_BEAT)
		previous = progress
		await _shot("recorded_paper_puppet_p%02d" % roundi(progress * 100.0), false)
		_check(RunSnapshot.capture(sim) == before, "paper_puppet_presentation_keeps_recording_money_and_rng_unchanged_p%02d" % roundi(progress * 100.0))
	_main._view.set_process(was_processing)
	_main._physics_process(_main.RECORD_BEAT + 0.01)
	_fixture("recording_clock_samples", "Held realD recorded a route. Realend_wave/Main play_record_beat launched archiving; only productionView._process presentation clock was sampled at progress.15/.4/.7, with authoritative snapshot fixed. This is the recording puppet, never material pickups or payout animation")
	_cover("actual_recorded_route_paper_puppet_archive_three_progress_frames")


func _equipment() -> void:
	var sim := _prep("graded_equipment", &"looper", 5, [&"pistol", &"pistol", &"shotgun", &"rifle", &"orb", &"stamp"], [1, 1, 0, 0, 0, 0])
	var ui: ShopUi = _main.shop_ui
	_check(ui.offers_box.get_child_count() == 6 and ui.build_panel._slot_buttons.size() == 6, "shop_has_six_goods_and_six_visible_weapon_slots")
	var orders := 0
	for offer in sim.shop.offers:
		orders += 1 if offer.is_contract() else 0
	_check(orders == 2, "shop_contains_two_real_work_orders")
	_preflight("graded_equipment")
	await _shot("shop_full_inventory")
	var before := RunSnapshot.capture(sim)
	await _activate(ui.build_panel._slot_buttons[0])
	await _activate(ui.workshop.choice_buttons[1])
	await _activate(ui.workshop.choice_buttons[0])
	_check(RunSnapshot.capture(sim) == before, "combine_host_donor_preview_is_pure")
	await _shot("combine_host_donor_confirmation")
	await _activate(ui.workshop.choice_buttons[0])
	_check(sim.player.weapons.size() == 5 and sim.player.level_at(0) == 2, "combine_consumes_one_same_grade_body_and_keeps_host")
	await _shot("combine_actual_result")
	await _activate(ui.undo_button)
	_check(RunSnapshot.capture(sim) == before, "combine_undo_restores_full_snapshot_and_paid_ledger")
	var card := ui.offers_box.get_child(0) as OfferCard
	var grade := card.offer.weapon_level
	var replacing := card.offer.weapon
	await _activate(card)
	await _activate(ui.build_panel._slot_buttons[4])
	await _shot("full_inventory_explicit_replacement")
	await _activate(ui.workshop.choice_buttons[0])
	_check(sim.player.weapons[4] == replacing and sim.player.level_at(4) == grade and sim.player.weapons.size() == 6, "full_inventory_replacement_equips_quoted_grade")
	await _activate(ui.undo_button)
	_check(RunSnapshot.capture(sim) == before, "replacement_undo_restores_exact_full_inventory")
	_cover("six_goods_full_inventory_graded_combine_replace_undo")


func _evolutions() -> void:
	for branch in 2:
		var sim := _prep("evolution_branch_%d" % branch, &"looper", 1, [&"pistol", &"pistol", &"pistol"], [WeaponDef.MAX_LEVEL, 0, 0])
		var ui: ShopUi = _main.shop_ui
		var before := RunSnapshot.capture(sim)
		var target := sim.shop.evolution_choices(sim, 0)[branch]
		await _activate(ui.build_panel._upgrade_buttons[0])
		_check(ui.workshop.choice_buttons.size() == 2 and RunSnapshot.capture(sim) == before, "evolution_two_branch_selector_is_pure_%d" % branch)
		await _shot("evolution_selector_%d" % branch)
		await _activate(ui.workshop.choice_buttons[branch])
		_check(sim.player.weapons[0].id == target and sim.player.level_at(0) == WeaponDef.MAX_LEVEL, "evolution_keeps_max_grade_%s" % target)
		await _activate(ui.start_button)
		_clear_plan(sim)
		var enemy := _enemy(sim, &"grunt", sim.player.pos + Vector2(180, 0))
		var hp := enemy.hp
		var count := int(_shots_by_weapon.get(target, 0))
		await _advance(1.0)
		_check(int(_shots_by_weapon.get(target, 0)) > count and enemy.hp < hp, "evolved_branch_fires_real_combat_%s" % target)
		await _shot("evolution_firing_%d" % branch)
		_summary.results["evolution_%d" % branch] = {"weapon": String(target), "grade": sim.player.level_at(0), "shots": int(_shots_by_weapon.get(target, 0)) - count, "target_damage": hp - enemy.hp}
	_cover("two_evolution_branches_actual_selector_and_firing")


func _echo_traits() -> void:
	var traits: Array[StringName] = [&"skill", &"repair", &"power"]
	for index in traits.size():
		var sim := _prep("echo_" + String(traits[index]), &"looper", 1, [&"pistol"], [0])
		sim.bank.takes.clear()
		sim.echoes.clear()
		sim.selected_echo_uid = 0
		var host := _take(sim, &"pistol", 1, 55.0, Vector2(300, 300))
		var donor := _take(sim, &"orb", 0, 80.0, Vector2(1200, 700))
		_main.shop_ui.refresh()
		var ui: ShopUi = _main.shop_ui
		var before := RunSnapshot.capture(sim)
		await _activate(ui.echo_panel.merge_button)
		await _activate(ui.workshop.choice_buttons[0])
		await _activate(ui.workshop.choice_buttons[0])
		await _activate(ui.workshop.choice_buttons[index])
		var preview_equal := RunSnapshot.capture(sim) == before
		_check(preview_equal, "echo_trait_preview_preserves_uid_rng_and_state_" + String(traits[index]))
		await _shot("echo_" + String(traits[index]) + "_preview")
		await _activate(ui.workshop.choice_buttons[0])
		_check(sim.bank.takes.size() == 1 and sim.bank.takes[0].samples == host.samples, "echo_merge_keeps_host_route_and_consumes_donor_" + String(traits[index]))
		var merged: EchoTake = sim.bank.takes[0]
		var benefit := merged.inherited_skill == donor.retirement_kind() if traits[index] == &"skill" else (is_equal_approx(merged.condition, 95.0) if traits[index] == &"repair" else merged.level_at(0) == 2 and is_equal_approx(merged.condition, 40.0))
		_check(benefit, "echo_trait_applies_actual_distinct_benefit_" + String(traits[index]))
		_summary.results["echo_" + String(traits[index])] = {"condition": sim.bank.takes[0].condition, "grade": sim.bank.takes[0].level_at(0), "inherited_skill": String(sim.bank.takes[0].inherited_skill), "bodies": sim.bank.takes.size(), "preview_snapshot_equal": preview_equal, "distinct_benefit": benefit}
		await _shot("echo_" + String(traits[index]) + "_confirmed")
		await _activate(ui.undo_button)
		_check(RunSnapshot.capture(sim) == before, "echo_merge_undo_restores_full_snapshot_" + String(traits[index]))
		await _shot("echo_" + String(traits[index]) + "_undo")
	_cover("three_echo_traits_preview_confirm_undo_without_rng_mutation")


func _credit_and_reroll() -> void:
	var sim := _prep("credit_exchange", &"looper", 1, [&"pistol"], [0])
	_stage_order(sim, &"credit", 4)
	_stage_order(sim, &"salvage", 5)
	var ui: ShopUi = _main.shop_ui
	var before := RunSnapshot.capture(sim)
	var funds := sim.player.materials
	await _activate(ui.offers_box.get_child(4) as OfferCard)
	_check(sim.player.materials == funds + 30 and int(sim.expedition.debt) == 40, "credit_card_pays_actual_advance_and_debt")
	var credit := RunSnapshot.capture(sim)
	await _shot("credit_order_purchased")
	await _activate(ui.offers_box.get_child(5) as OfferCard)
	_check(RunSnapshot.capture(sim) == credit, "order_exchange_requires_explicit_pure_confirmation")
	await _shot("credit_order_replacement_confirmation")
	await _activate(ui.workshop.choice_buttons[0])
	_check(sim.active_contract.kind == &"salvage" and int(sim.expedition.debt) == 40, "order_exchange_preserves_credit_obligation")
	await _activate(ui.undo_button)
	_check(RunSnapshot.capture(sim) == credit, "order_exchange_undo_restores_debt_order_alias_and_funds")
	await _shot("credit_order_replacement_undone")
	await _activate(ui.undo_button)
	_check(RunSnapshot.capture(sim) == before, "credit_buy_undo_restores_pre_advance_ledger")
	var next := sim.shop.next_reroll_cost(sim.wave)
	await _activate(ui.reroll_button)
	_check(sim.shop.reroll_cost(sim.wave) == next and ui.reroll_button.text == Loc.t("workshop.reroll_prices", [next, sim.shop.next_reroll_cost(sim.wave)]), "locale_reroll_shows_actual_current_and_next_prices")
	await _shot("reroll_current_and_next_prices")
	_cover("credit_explicit_order_exchange_undo_and_localized_reroll")


func _missions() -> void:
	for kind: StringName in [&"salvage", &"repair", &"recruit"]:
		var sim := _prep("mission_" + String(kind), &"looper", 3 if kind == &"recruit" else 1, [&"pistol"], [0])
		_stage_order(sim, kind, 4)
		await _activate(_main.shop_ui.offers_box.get_child(4) as OfferCard)
		await _activate(_main.shop_ui.start_button)
		_check(sim.expedition.mission.state == &"active", "purchased_order_starts_real_mission_" + String(kind))
		if kind == &"salvage":
			for item: Dictionary in sim.interactables:
				if item.kind == &"part":
					sim.player.pos = item.pos
					await _key(KEY_E)
					await _advance(0.05)
			_check(Expedition.order_complete(sim, sim.active_contract), "three_actual_E_parts_complete_salvage")
			await _shot("salvage_parts_actual_E_completion")
			sim._end_wave()
			_main._sync_phase()
			_check(sim.last_contract_success and sim.expedition.completed_orders.has(&"salvage"), "salvage_settles_real_reward_and_story_route")
		elif kind == &"repair":
			await _advance(2.1)
			for item: Dictionary in sim.interactables:
				if item.kind == &"repair":
					sim.player.pos = item.pos
			await _shot("repair_target_before_interaction")
			await _joy(JOY_BUTTON_X)
			_check(Expedition.order_complete(sim, sim.active_contract), "actual_controller_X_repairs_generated_target")
			await _shot("repair_target_actual_X_result")
		else:
			await _advance(2.3)
			var boss: EnemyState = sim.boss
			if _check(boss != null and boss.def.id == &"foreman", "mandatory_actual_foreman_spawned"):
				sim.player.pos = boss.pos + Vector2(120, 0)
				boss.hp = 1.0
				_fixture("near_defeat_boss", "Actual scheduled Foreman body reduced to 1 HP only; production autofire must create protected negotiation, then real X must recruit")
				await _advance(0.9)
				_check(not sim.expedition.negotiation.is_empty(), "autofire_lethal_hit_opens_protected_boss_negotiation")
				sim.player.pos = boss.pos
				await _shot("recruit_foreman_negotiation")
				await _joy(JOY_BUTTON_X)
				_check(Expedition.order_complete(sim, sim.active_contract) and sim.support_units.size() == 1 and sim.support_units[0].kind == &"recruited_foreman", "actual_X_negotiation_creates_bounded_companion")
				await _advance(0.2)
				await _shot("recruited_foreman_actual_companion")
		_fixture("mission_positions_" + String(kind), "Player repositioned onto generated mission targets to bound travel time; objectives, interaction range/cost, boss negotiation and support allocation remain production rules")
	_cover("real_E_parts_X_repair_and_boss_negotiation_companion")


func _skills() -> void:
	for index in ROLES.size():
		var role := ROLES[index]
		var sim := _battle("skill_" + String(role), role)
		if sim.echo_capacity() > 0:
			var take := _take(sim, &"pistol", 0, 80.0, sim.player.pos + Vector2(100, 30))
			var actor := EchoActor.new(take, 0)
			sim.echoes.append(actor)
			sim.echo_spawned.emit(actor)
			sim.selected_echo_uid = take.uid
		if role == &"looper":
			await _move_right(0.35)
		var pickup := Pickup.new()
		pickup.pos = sim.player.pos
		pickup.value = 5
		sim.pickups.append(pickup)
		sim.character_energy = 80.0
		var funds := sim.player.materials
		_main._physics_process(1.0 / 60.0)
		_check(sim.character_energy == 100.0 and sim.player.materials == funds + 5, "manual_collision_pickup_charges_energy_" + String(role))
		if index == 0:
			await _shot("manual_pickup_energy_ready")
		var position_before := sim.player.pos
		var bodies_before := sim.bank.takes.size()
		if index % 2 == 0:
			await _key(KEY_SHIFT)
		else:
			await _joy(JOY_BUTTON_LEFT_SHOULDER)
		_check(sim.character_energy == 0.0 and sim.character_cooldown > 0.0, "real_Shift_or_LB_activates_role_" + String(role))
		var spent := RunSnapshot.capture(sim)
		if index % 2 == 0:
			await _key(KEY_SHIFT)
		else:
			await _joy(JOY_BUTTON_LEFT_SHOULDER)
		_check(RunSnapshot.capture(sim) == spent, "cooldown_blocks_repeat_role_input_" + String(role))
		await _advance(0.15)
		var effect := false
		match role:
			&"looper", &"solo", &"mirror": effect = sim.player.pos.distance_to(position_before) > 10.0
			&"conductor": effect = int(sim.role_effects.get("anchor_uid", 0)) > 0 and float(sim.role_effects.get("anchor_left", 0.0)) > 0.0
			&"mender": effect = sim.support_units.size() == 1 and sim.support_units[0].kind == &"repair_station"
			&"overloader": effect = sim.bank.takes.size() == bodies_before - 1 and sim.retire_cooldown > 0.0
		_check(effect, "distinct_live_role_effect_" + String(role))
		_summary.results["skill_" + String(role)] = {"energy": sim.character_energy, "cooldown": sim.character_cooldown, "support_count": sim.support_units.size(), "echo_bodies": sim.bank.takes.size(), "input": "Shift" if index % 2 == 0 else "LB", "distinct_effect": effect}
		await _shot("actual_skill_" + String(role))
	_cover("manual_pickups_and_all_six_real_Shift_LB_skills")


func _save_continue() -> void:
	var sim := _prep("save_continue", &"mender", 1, [&"pistol"], [0])
	_stage_order(sim, &"credit", 4)
	await _activate(_main.shop_ui.offers_box.get_child(4) as OfferCard)
	await _activate(_main.shop_ui.start_button)
	await _key(KEY_SHIFT)
	await _advance(0.1)
	await _key(KEY_P)
	_check(_main.pause_ui.visible and _main.paused, "real_P_opens_pause_before_save")
	var before := RunSnapshot.capture(sim)
	_check(not before.is_empty() and RunSnapshot.restore(before) != null, "save_fixture_passes_strict_snapshot_validation_" + RunSnapshot.last_error)
	await _shot("pause_before_exact_save")
	await _activate(_main.pause_ui.save_button)
	_check(_main.sim == null and _main.character_select.continue_button.visible, "actual_Save_Return_releases_run_and_exposes_Continue")
	await _shot("saved_title_continue")
	await _activate(_main.character_select.continue_button)
	_check(_main.sim != null and RunSnapshot.capture(_main.sim) == before, "actual_Continue_restores_full_snapshot_both_rngs_and_new_state")
	var expected := RunSnapshot.restore(before)
	if expected != null and _main.sim != null:
		expected.step(1.0 / 60.0, Vector2.ZERO)
		_main._physics_process(1.0 / 60.0)
		_check(RunSnapshot.capture(_main.sim) == RunSnapshot.capture(expected), "continued_Main_step_matches_restored_reference_exactly")
	_summary.results["save_continue"] = {"snapshot_sha256": JSON.stringify(before, "", true, true).sha256_text(), "support": sim.support_units.size(), "debt": sim.expedition.debt, "one_step_equal": _main.sim != null and expected != null and RunSnapshot.capture(_main.sim) == RunSnapshot.capture(expected)}
	await _shot("continued_exact_state_and_step")
	_cover("Pause_Save_Return_Title_Continue_full_snapshot_and_one_step_parity")


func _endings() -> void:
	for ending: StringName in [&"released", &"collective", &"indebted"]:
		var sim := _battle("ending_" + String(ending), &"looper", WaveDirector.FINAL_WAVE)
		sim.player.materials = 0
		sim.player.hp = 10.0
		_take(sim, &"pistol", 0, 40.0, sim.player.pos)
		if ending == &"released":
			sim.expedition.audits = 2
			sim.expedition.debt = 40
			sim.expedition.credit_taken = 1
		elif ending == &"collective":
			sim.expedition.solidarity = 3
		else:
			sim.expedition.debt = 40
			sim.expedition.credit_taken = 1
		_fixture("ending_counters_" + String(ending), "Encounter12 terminal route counters staged for this outcome; not a twelve-encounter playthrough. Production end_wave, installment, outcome ledger, Main victory beat and EndUi execute")
		sim._end_wave()
		_main._sync_phase()
		_main._physics_process(_main.VICTORY_BEAT + 0.01)
		_check(_main.end_ui.visible and sim.expedition.ending == ending, "actual_EndUI_shows_route_outcome_" + String(ending))
		var ledger: Dictionary = sim.expedition.ending_outcome.duplicate(true)
		var actual_outcome := int(ledger.get("forgiven_debt", 0)) == 40 and int(sim.expedition.debt) == 0 if ending == &"released" else (is_equal_approx(sim.player.hp, sim.player.max_hp()) and sim.support_units.size() == 1 if ending == &"collective" else int(ledger.get("cash", 0)) == 24 and int(sim.expedition.debt) == 40)
		_check(actual_outcome, "ending_applies_concrete_outcome_" + String(ending))
		_check(not ledger.is_empty() and not Expedition.apply_ending_outcome(sim) and sim.expedition.ending_outcome == ledger, "ending_outcome_is_applied_once_" + String(ending))
		_summary.results["ending_" + String(ending)] = {"ledger": ledger, "debt": sim.expedition.debt, "funds": sim.player.materials, "interest": sim.last_interest, "copies": sim.bank.takes.size(), "support": sim.support_units.size()}
		await _shot("ending_" + String(ending))
	_cover("three_story_endings_real_outcomes_and_idempotence")


func _archive() -> void:
	var sim := _battle("archive", &"looper")
	_take(sim, &"pistol", WeaponDef.MAX_LEVEL, 80.0, sim.player.pos)
	sim.player.iframes = 0.0
	sim._hurt_player(sim.player.hp + sim.player.shield + 10.0, &"grunt", &"hit", sim.player.pos, Vector2.ZERO)
	_main._physics_process(0.01)
	_main._physics_process(_main.PLAYER_DEATH_BEAT + 0.01)
	_check(_main.end_ui.visible and not _main.end_ui.archive_button.disabled, "real_loss_exposes_eligible_archive_action")
	await _shot("end_archive_eligible")
	await _activate(_main.end_ui.archive_button)
	_check(EchoArchive.has(Meta.new(_main.meta.path), &"looper"), "actual_End_archive_action_persists_copy")
	await _activate(_main.end_ui.character_button)
	await _activate(_button(_main.character_select, "archive.open"))
	_check(_main.echo_archive_ui.visible and _main.echo_archive_ui._preview.visible, "actual_Title_archive_button_opens_saved_preview")
	await _shot("title_archive_saved_preview")
	await _activate(_main.echo_archive_ui.toggle_button)
	_check(not _main.meta.inherit_echo, "real_archive_toggle_persists_disabled_preference")
	await _activate(_main.echo_archive_ui._close_button)
	_main.character_select.seed_edit.text = str(SEED + 1)
	await _activate(_main.character_select._cards[0])
	_check(_main.sim.bank.takes.is_empty(), "real_new_run_respects_disabled_inheritance")
	_main.show_select()
	await _activate(_button(_main.character_select, "archive.open"))
	await _activate(_main.echo_archive_ui.toggle_button)
	await _activate(_main.echo_archive_ui._close_button)
	_main.character_select.seed_edit.text = str(SEED + 2)
	await _activate(_main.character_select._cards[0])
	_check(_main.sim.bank.takes.size() == 1 and _main.sim.bank.takes[0].archived and _main.sim.bank.takes[0].uid > 0, "real_title_new_run_inherits_one_normalized_archived_body")
	_preflight("inherited_run")
	await _shot("new_run_actual_inherited_echo")
	_cover("End_archive_Title_preview_toggle_and_actual_new_run_inheritance")


func _battle(id: String, role: StringName, wave: int = 1) -> Sim:
	_main.new_run(SEED, role, 0)
	_main.set_physics_process(false)
	var sim: Sim = _main.sim
	if wave != 1:
		sim.start_wave(wave)
	_clear_plan(sim)
	sim.shot_fired_info.connect(_on_shot)
	_main._view.shake_enabled = false
	_fixture(id, "Canonical Main.new_run seed150150; start_wave(%d), automatic plan/pending removed with index reset to bound fixture; ordinary player stats and canonical allocators retained" % wave)
	return sim


func _prep(id: String, role: StringName, wave: int, ids: Array, levels: Array) -> Sim:
	var sim := _battle(id, role, wave)
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	for index in ids.size():
		sim.player.add_weapon(Content.weapon(ids[index]))
		sim.player.weapon_levels[index] = int(levels[index])
		sim.player.weapon_investments[index] = sim.player.weapons[index].price * (int(levels[index]) + 1)
	sim.recorder.record(sim.player.pos + Vector2(100, 20), 0.1)
	sim._end_wave()
	_main._sync_phase()
	_main._physics_process(_main.RECORD_BEAT + 0.01)
	sim.player.materials = 1200
	_main.shop_ui.refresh()
	_fixture(id + "_loadout", "Canonical weapon IDs/grades/paid-investment array and1200-material budget staged; recorder/end_wave/Main record beat create the actual preparation UI")
	return sim


func _clear_plan(sim: Sim) -> void:
	sim._plan.clear()
	sim._plan_idx = 0
	sim.pending.clear()


func _stage_order(sim: Sim, kind: StringName, index: int) -> void:
	var offer := Offer.new()
	offer.contract = AnomalyContract.create(kind, sim.next_wave_number())
	offer.price = offer.contract.deposit
	sim.shop.offers[index] = offer
	_main.shop_ui.refresh()
	_fixture("goods_order_" + String(kind), "One generated order-card slot replaced with canonical AnomalyContract.create to guarantee this order; all purchase/exchange/mission actions use real UI and production rules")


func _take(sim: Sim, id: StringName, level: int, condition: float, at: Vector2) -> EchoTake:
	var take := EchoTake.new()
	take.wave = maxi(1, sim.wave)
	take.condition = condition
	take.stats = sim.player.stats.copy()
	take.weapons.append(Content.weapon(id))
	take.levels.append(level)
	take.samples = PackedVector2Array([at, at + Vector2(70, 80), at + Vector2(160, 20)])
	sim.bank.add(take)
	_fixture("echo_route_%d" % take.uid, "Synthetic EchoTake: canonicalweapon %s,grade%d,condition%.1f,ordinarycopiedstats andthreeauthoredroutepoints; bank.add allocatesUID. This is not a historical human recording" % [id, level, condition])
	return take


func _enemy(sim: Sim, id: StringName, at: Vector2) -> EnemyState:
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(id)
	spawn.pos = at
	sim._materialize(spawn)
	var enemy: EnemyState = sim.enemies.back()
	enemy.hp = 2000.0
	enemy.max_hp = 2000.0
	enemy.speed = 0.0
	_fixture("combat_target", "Canonical materialized %s target uses allocator UID,2000HP andzero movement to observe actual projectile/field damage without changing attack rules" % id)
	return enemy


func _on_shot(info: ShotInfo) -> void:
	_shots_by_weapon[info.weapon_id] = int(_shots_by_weapon.get(info.weapon_id, 0)) + 1


func _advance(seconds: float) -> void:
	for _index in ceili(seconds * 60.0):
		if _finished or _main.sim == null:
			return
		_main._physics_process(1.0 / 60.0)
		await process_frame


func _move_right(seconds: float) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await _advance(seconds)
	event = InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _activate(button: Button, gamepad: bool = false) -> bool:
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled, "visible_enabled_UI_target_" + (button.text if button != null else "missing")):
		return false
	button.grab_focus()
	await process_frame
	_check(root.get_visible_rect().grow(1.0).encloses(button.get_global_rect()), "UI_target_inside_native_canvas_" + button.text)
	if gamepad:
		await _joy(JOY_BUTTON_A)
	else:
		await _key(KEY_ENTER)
	return true


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await _wait(0.025)


func _joy(code: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await _wait(0.025)


func _shot(id: String, hold: bool = true) -> void:
	if _finished or _main == null:
		return
	if hold:
		await _wait(0.16)
	else:
		await process_frame
	_main._view.queue_redraw()
	_main.hud.queue_redraw()
	RenderingServer.force_draw()
	var pixels := root.get_texture().get_image()
	if not _check(pixels != null and not pixels.is_empty(), "native_pixels_" + id):
		return
	var path := _out.path_join(id + ".png")
	_check(pixels.save_png(path) == OK, "write_png_" + id)
	_check(pixels.get_size() == _size, "native_pixel_extent_" + id)
	var outside := _outside_controls()
	_check(outside.is_empty(), "visible_controls_inside_native_canvas_" + id)
	var state := {"outside_controls": outside, "record_progress": _main._view._beat_time / ArenaView.RECORD_BEAT if _main._view._beat_take != null else -1.0, "path": path, "size": [pixels.get_width(), pixels.get_height()], "frame": _frames, "title": _main.character_select.visible, "shop": _main.shop_ui.visible, "workbench": _main.shop_ui.workshop.visible, "end": _main.end_ui.visible, "archive": _main.echo_archive_ui.visible}
	if _main.sim != null:
		var snapshot := RunSnapshot.capture(_main.sim)
		state["snapshot_valid"] = not snapshot.is_empty() and RunSnapshot.restore(snapshot) != null
		_check(state.snapshot_valid, "coherent_capture_" + id + "_" + RunSnapshot.last_error)
		state["wave"] = _main.sim.wave
		state["phase"] = _main.sim.phase
		state["character"] = String(_main.sim.character_id)
		state["materials"] = _main.sim.player.materials
	_summary.screenshots[id] = state
	print("expedition gameplay: " + id)
	if hold:
		await _wait(0.25)


func _outside_controls() -> Array[String]:
	var surface: Control = null
	if _main.echo_archive_ui.visible:
		surface = _main.echo_archive_ui
	elif _main.pause_ui.visible:
		surface = _main.pause_ui
	elif _main.end_ui.visible:
		surface = _main.end_ui
	elif _main.shop_ui.visible:
		surface = _main.shop_ui.workshop if _main.shop_ui.workshop.visible else _main.shop_ui
	elif _main.character_select.visible:
		surface = _main.character_select
	var outside: Array[String] = []
	if surface == null:
		return outside
	for button: BaseButton in surface.find_children("*", "BaseButton", true, false):
		if not button.is_visible_in_tree():
			continue
		var parent := button.get_parent()
		var scrollable := false
		while parent != surface and parent != null:
			scrollable = scrollable or parent is ScrollContainer
			parent = parent.get_parent()
		if not scrollable and not root.get_visible_rect().grow(1.0).encloses(button.get_global_rect()):
			outside.append(str(button.get_path()) + " " + str(button.get_global_rect()))
	return outside


func _button(surface: Control, key: String) -> Button:
	for button: Button in surface.find_children("*", "Button", true, false):
		if button.text == Loc.t(key):
			return button
	return null


func _preflight(id: String) -> void:
	var snapshot := RunSnapshot.capture(_main.sim)
	_check(not snapshot.is_empty() and RunSnapshot.restore(snapshot) != null, "coherent_snapshot_" + id + "_" + RunSnapshot.last_error)


func _fixture(id: String, setup: String) -> void:
	_summary.fixtures.append({"id": id, "setup": setup})


func _cover(id: String) -> void:
	_summary.coverage.append(id)


func _check(condition: bool, id: String) -> bool:
	_summary.checks.append({"id": id, "passed": condition})
	if not condition and not _failures.has(id):
		_failures.append(id)
		printerr("expedition gameplay FAILED: " + id)
	return condition


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _finish() -> void:
	if _finished:
		return
	_finished = true
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"character_skill", &"interact", &"ui_accept"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	_summary["failures"] = _failures
	_summary["success"] = _failures.is_empty()
	_summary["frames"] = _frames
	_summary["wall_seconds"] = float(Time.get_ticks_msec() - _started) / 1000.0
	var file := FileAccess.open(_out.path_join("summary.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_summary, "\t", true, true))
		file.close()
	if _main != null:
		_main.set_physics_process(false)
		_main._detach_presentation_session()
		_main.audio.stop_all()
		_main.queue_free()
		_main = null
	print("expedition gameplay: %s (%d shots, %.2fs)" % ["OK" if _failures.is_empty() else "FAILED", _summary.screenshots.size(), _summary.wall_seconds])
	await process_frame
	await process_frame
	quit(0 if _failures.is_empty() else 1)
