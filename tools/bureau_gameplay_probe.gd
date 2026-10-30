extends SceneTree
# Clinical Main/input evidence, not a human playthrough. Fixtures shorten travel,
# stage progression and loadouts; actual controls, rules, saves and visuals run.
# REVERB_LANG=en|zh REVERB_PROBE_SIZE=1280x720|960x540 REVERB_PROBE_REDUCED=0|1
# godot --path . --disable-vsync --script res://tools/bureau_gameplay_probe.gd
# Optional --headless-flow diagnostic exercises controls without pixel evidence;
# REVERB_BUREAU_OUTPUT can point outside res:// for final delivery captures.
# --tooltip-only refreshes the two departure surfaces and writes its own summary.

const DEADLINE_MSEC := 240000
const SEED := 170170
const DELIVERY_ROOT := "res://shots/bureau-gameplay"
const FILES := {"REVERB_SAVE": "meta.json", "REVERB_SETTINGS": "settings.json", "REVERB_RUN_LOG": "runs.jsonl", "REVERB_FEEDBACK_LOG": "feedback.jsonl", "REVERB_SUSPEND": "suspend.json"}
var _main: Node
var _out := ""
var _started := Time.get_ticks_msec()
var _frames := 0
var _finished := false
var _headless_flow := false
var _tooltip_only := false
var _last_pixels: Image
var _size := Vector2i(1280, 720)
var _failures: Array[String] = []
var _summary := {"probe": "bureau_rituals_gameplay_0_17", "checks": [], "screenshots": {}, "coverage": [], "fixtures": [], "results": {},
	"disclosure": "Scripted clinical fixtures, not human play or recognition-speed evidence. Canonical Main/Sim methods create stages; scenario positions and damaged Echo/loadout setup are disclosed. Actual Input.parse_input_event press/release drives menus, E/X, Space/RB and movement. Main physics is explicitly advanced at60Hz. Original-resolution screenshots force a draw; full exact JSON Snapshot restoration and rendering-state invariance are checked."}


func _initialize() -> void:
	Engine.max_fps = 60
	RenderingServer.render_loop_enabled = false
	_tooltip_only = OS.get_cmdline_user_args().has("--tooltip-only")
	var lang := OS.get_environment("REVERB_LANG")
	Loc.lang = lang if lang in ["en", "zh"] else "en"
	var dimensions := OS.get_environment("REVERB_PROBE_SIZE")
	if dimensions == "":
		dimensions = "1280x720"
	var parts := dimensions.split("x")
	if parts.size() == 2:
		_size = Vector2i(int(parts[0]), int(parts[1]))
	root.content_scale_size = _size
	_headless_flow = DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--headless-flow")
	if _headless_flow:
		root.size = _size
	else:
		DisplayServer.window_set_size(_size)
	var profile := "%s-%s-%s" % [Loc.lang, "reduced" if OS.get_environment("REVERB_PROBE_REDUCED") == "1" else "standard", dimensions]
	if _headless_flow:
		profile += "-headless"
	_out = OS.get_environment("REVERB_BUREAU_OUTPUT")
	if _out == "":
		_out = ProjectSettings.globalize_path(DELIVERY_ROOT.path_join(profile))
	DirAccess.make_dir_recursive_absolute(_out)
	var isolated := "user://bureau_gameplay_probe/" + profile
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated))
	for key: String in FILES:
		var path := isolated.path_join(FILES[key])
		OS.set_environment(key, path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("REVERB_RUN_SOURCE", "bureau_gameplay_fixture")
	_summary["profile"] = profile
	_summary["requested_canvas"] = [_size.x, _size.y]
	_summary["native_display"] = DisplayServer.get_name()
	_summary["check_mode"] = "tooltip_only" if _tooltip_only else "full_gameplay"
	_summary["native_pixels_verified"] = DisplayServer.get_name() != "headless"
	if not _check(DisplayServer.get_name() != "headless" or _headless_flow, "native_display_required_or_explicit_diagnostic"):
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
		_check(false, "bounded_native_deadline")
		_finish()
		return false
	if not _headless_flow:
		RenderingServer.force_draw()
	return false


func _run() -> void:
	await _wait(0.15)
	_main.settings.reduced_effects = OS.get_environment("REVERB_PROBE_REDUCED") == "1"
	_main.settings.fullscreen = false
	_main.settings.save()
	_main._apply_reduced_effects()
	_check(root.get_visible_rect().size == Vector2(_size), "actual_native_canvas_matches_requested_pixels")
	for role: StringName in Content.characters():
		_main.meta.unlocked[role] = true
	_main.character_select.refresh(_main.meta)
	if _tooltip_only:
		_shop("tooltip_native_contrast")
		await _ordinary_forecast_surface()
		_cover("actual_native_tooltip_opaque_paper_ink_text_and_contrast")
		_finish()
		return
	await _archive_and_vending()
	await _binding()
	await _truth(false)
	await _truth(true)
	await _polish(false)
	await _polish(true)
	await _delivery_solo()
	await _delivery_echo()
	_finish()


func _battle(id: String, role: StringName = &"looper", stage: int = 1) -> Sim:
	_main.meta.inherit_echo = false
	_main.new_run(SEED, role, 0)
	_main.set_physics_process(false)
	var sim: Sim = _main.sim
	if stage != 1:
		sim.start_wave(stage)
	_clear_plan(sim)
	_main._view.shake_enabled = false
	_fixture(id, "Canonical Main.new_run seed170170, role%s, start_wave(%d); only automatic spawn plan/pending removed with allocator index reset. Shortened stage traversal and any further route positions are explicit fixture setup, not a campaign playthrough" % [role, stage])
	return sim


func _shop(id: String, role: StringName = &"looper") -> Sim:
	var sim := _battle(id, role)
	sim.recorder.record(sim.player.pos + Vector2(80, 0), 0.1)
	sim._end_wave()
	_main._sync_phase()
	_main._physics_process(_main.RECORD_BEAT + 0.01)
	sim.player.materials = 80
	_main.shop_ui.refresh()
	_check(_main.shop_ui.visible and sim.phase == Sim.Phase.SHOP, "actual_recording_to_shop_" + id)
	_check(_main.shop_ui._prep_status.text.begins_with(Loc.t("bureau.delivery.next_short")), "ordinary_shop_announces_the_optional_stamp_before_any_offer_is_opened_" + id)
	var terms := Loc.t("bureau.delivery.forecast", [BureauEvents.REWARD])
	_check(_main.shop_ui.start_button.tooltip_text == terms and _main.shop_ui.start_button.accessibility_description == terms, "departure_describes_the_exact_eight_material_reward_and_no_failure_fee_" + id)
	_fixture(id + "_budget", "80materials staged after real recorder/end_wave/Main recording beat; actual quotes/transactions/Undo remain authoritative")
	return sim


func _take(sim: Sim, weapon: StringName, condition: float, at: Vector2) -> EchoTake:
	var take := EchoTake.new()
	take.wave = maxi(1, sim.wave)
	take.condition = condition
	take.stats = sim.player.stats.copy()
	take.weapons.append(Content.weapon(weapon))
	take.levels.append(0)
	take.samples = PackedVector2Array([at, at + Vector2(30, 0), at + Vector2(60, 0)])
	sim.bank.add(take)
	_fixture("staged_take_%d" % take.uid, "Three-point canonical%s grade0 Echo fixture, condition%.1f; bank allocates its actual stableUID" % [weapon, condition])
	return take


func _archive_and_vending() -> void:
	var sim := _battle("archive_room_retirement")
	var retired := _take(sim, &"pistol", 45.0, sim.player.pos)
	var retained := _take(sim, &"repair_kit", 80.0, sim.player.pos + Vector2(0, 40))
	sim.start_wave(2)
	_clear_plan(sim)
	sim.select_echo(retired.uid)
	await _key(KEY_SPACE)
	_check(sim.bank.find_uid(retired.uid) == null and sim.bank.find_uid(retained.uid) != null, "real_Space_retires_exact_selected_body")
	_check(sim.expedition.bureau.retired.size() == 1 and sim.expedition.bureau.retired[0]["uid"] == retired.uid, "retirement_receipt_comes_from_real_removed_identity")
	await _shot("retirement_actual_receipt")
	sim.player.iframes = 0.0
	sim._hurt_player(sim.player.hp + sim.player.shield + 10.0, &"grunt", &"hit", sim.player.pos, Vector2.ZERO)
	_main._physics_process(0.01)
	_main._physics_process(_main.PLAYER_DEATH_BEAT + 0.01)
	_check(_main.end_ui.visible and _main.meta.bureau_reports.size() == 1, "real_loss_records_one_bounded_bureau_report")
	_check(_main.meta.bureau_reports[0]["retired"].size() == 1, "permanent_report_contains_actual_retirement")
	await _activate(_main.end_ui.archive_button)
	_check(EchoArchive.has(Meta.new(_main.meta.path), &"looper"), "actual_end_archive_button_persists_retained_copy")
	await _activate(_main.end_ui.character_button)
	await _activate(_button(_main.character_select, "archive.open"))
	var archive: EchoArchiveUi = _main.echo_archive_ui
	_check(archive.room.role_frames.size() == 5 and archive._preview.visible, "family_wall_exposes_eligible_role_frames_and_real_archive")
	await _shot("archive_family_wall_real_saved_copy")
	await _activate(archive.room.role_frames[1], true)
	_check(archive.selected != &"looper", "controller_family_frame_changes_selected_role")
	await _activate(archive.room.role_frames[0], true)
	_check(archive.selected == &"looper", "controller_returns_to_the_retained_archive")
	for index in 11:
		_check(_main.meta.stage_bureau_report(sim, "bureau_layout_report_%02d" % index), "bounded_report_fixture_is_schema_valid_%02d" % index)
	_check(_main.meta.bureau_reports.size() == Meta.MAX_BUREAU_REPORTS, "memory_fixture_reaches_actual_twelve_report_bound")
	_fixture("bounded_archive_reports", "Eleven additional fixture report IDs stage the same actual terminal run via Meta.stage_bureau_report solely to stress full twelve-report pagination; they are not eleven human playthroughs")
	await _activate(archive.history_button, true)
	_check(archive.memory.visible and not archive.memory.row_buttons.is_empty(), "actual_history_entry_shows_committed_report")
	if not archive.memory.row_buttons.is_empty():
		await _activate(archive.memory.row_buttons[0], true)
	await _shot("archive_memory_actual_retired_identity")
	for _page in 40:
		if archive.memory.next_button.disabled:
			break
		await _activate(archive.memory.next_button, true)
	_check(archive.memory.page == archive.memory.page_count() - 1 and archive.memory.next_button.disabled, "controller_can_reach_the_final_bounded_report_page")
	await _shot("archive_memory_final_page")
	await _activate(archive.memory.close_button, true)
	_check(archive.history_button.has_focus(), "memory_close_returns_focus_to_its_archive_entry")
	if not _main.meta.inherit_echo:
		await _activate(archive.toggle_button)
	await _activate(archive._close_button)
	_main.character_select.seed_edit.text = str(SEED + 1)
	await _activate(_main.character_select._cards[0])
	sim = _main.sim
	_check(sim.bank.takes.size() == 1 and sim.bank.takes[0].archived, "real_title_start_inherits_exactly_one_archived_body")
	var inherited: EchoTake = sim.bank.takes[0]
	_check(_main.vending_ui.printed_uid == inherited.uid, "vending_identifies_the_actual_loaded_copy")
	_main.vending_ui.set_process(false)
	_main.vending_ui._process(0.32)
	_main.vending_ui.set_paused(true)
	await _shot("vending_actual_inherited_copy")
	var before := RunSnapshot.capture(sim)
	_check(not _main.vending_ui.show_take(inherited, sim), "vending_same_run_uid_cannot_print_a_second_time")
	_main.vending_ui.skip()
	_main.vending_ui.set_paused(false)
	_main.vending_ui.set_process(true)
	_check(RunSnapshot.capture(sim) == before and sim.bank.takes.size() == 1, "vending_skip_and_repeat_leave_full_authoritative_state_unchanged")
	var start: Vector2 = sim.player.pos
	await _move(KEY_D, 0.12)
	_check(sim.player.pos.x > start.x and sim.wave_time > 0.0, "vending_does_not_capture_battle_movement_or_pause_time")
	_cover("family_wall_actual_retirement_history_archive_and_one_copy_vending")


func _ordinary_forecast_surface() -> void:
	# Let the ordinary shop's optional opening tween finish before comparing pixels.
	await _wait(0.25)
	await _shot("ordinary_shop_stamp_forecast")
	var before := _last_pixels
	var status: Label = _main.shop_ui._prep_status
	var prefix_width := status.get_theme_font("font").get_string_size(Loc.t("bureau.delivery.next_short"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, status.get_theme_font_size("font_size")).x
	_check(status.is_visible_in_tree() and prefix_width <= status.size.x, "leading_stamp_announcement_fits_the_native_header_before_any_offer_is_opened")
	await _hover(_main.shop_ui.start_button)
	await _shot("ordinary_shop_departure_delivery_terms")
	if _tooltip_only:
		_tooltip_pixels(before, _last_pixels, _main.shop_ui.start_button.get_global_rect())


func _tooltip_pixels(before: Image, after: Image, button_rect: Rect2) -> void:
	if not _check(before != null and after != null, "tooltip_has_two_actual_native_images"):
		return
	var low := Vector2i(_size.x, _size.y)
	var high := Vector2i.ZERO
	var paper_pixels := 0
	var paper_light := 0.0
	var top := maxi(0, floori(button_rect.position.y) - 120)
	# Limit the comparison to the footer near departure. The merchant's idle
	# animation cannot become a false tooltip positive in this region.
	for y in range(top, _size.y):
		for x in range(floori(float(_size.x) * 0.35), _size.x):
			var old := before.get_pixel(x, y)
			var color := after.get_pixel(x, y)
			var lum := _luminance(color)
			if lum > 0.55 and _luminance(old) < 0.20 and color.r > color.b and color.g > color.b:
				paper_pixels += 1
				paper_light += lum
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	_check(paper_pixels > 1000, "actual_hover_creates_an_opaque_cream_paper_surface")
	var ink_pixels := 0
	var ink_light := 0.0
	if paper_pixels > 0 and high.x - low.x > 24 and high.y - low.y > 16:
		# Exclude the outline. A blank paper panel cannot pass as legible text.
		for y in range(low.y + 8, high.y - 7):
			for x in range(low.x + 8, high.x - 7):
				var lum := _luminance(after.get_pixel(x, y))
				if lum < 0.08:
					ink_pixels += 1
					ink_light += lum
	_check(ink_pixels > 60, "actual_tooltip_contains_interior_dark_ink_glyphs")
	var contrast := (paper_light / float(paper_pixels) + 0.05) / (ink_light / float(ink_pixels) + 0.05) if paper_pixels > 0 and ink_pixels > 0 else 0.0
	_check(contrast >= 4.5, "actual_native_tooltip_paper_and_ink_have_readable_contrast")
	_summary.results["tooltip_pixels"] = {"roi": [floori(float(_size.x) * 0.35), top, _size.x, _size.y],
		"new_paper_pixels": paper_pixels, "ink_glyph_pixels": ink_pixels, "contrast_ratio": contrast,
		"paper_bounds": [low.x, low.y, high.x, high.y], "comparison": "Actual native before/after hover pixels; outline excluded from ink count"}


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _linear(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _binding() -> void:
	for trait_index in EchoBank.MERGE_TRAITS.size():
		await _binding_case(trait_index)


func _binding_case(trait_index: int) -> void:
	var label := String(EchoBank.MERGE_TRAITS[trait_index])
	var sim := _shop("binding_ceremony_" + label)
	if trait_index == 0:
		await _ordinary_forecast_surface()
	var host: EchoTake = sim.bank.takes[0]
	host.condition = 45.0
	var donor := _take(sim, &"ink_bottle", 70.0, sim.player.pos)
	sim.selected_echo_uid = host.uid
	_main.shop_ui.refresh()
	var before := RunSnapshot.capture(sim)
	var ui: ShopUi = _main.shop_ui
	await _activate(ui.echo_panel.merge_button)
	await _activate(ui.workshop.choice_buttons[0])
	await _activate(ui.workshop.choice_buttons[0])
	await _activate(ui.workshop.choice_buttons[trait_index])
	_check(RunSnapshot.capture(sim) == before, "merge_preview_leaves_model_rng_funds_and_identities_unchanged")
	await _shot("binding_merge_terms_" + label)
	await _activate(ui.workshop.choice_buttons[0])
	_check(sim.bank.takes.size() == 1 and sim.bank.takes[0].merged and sim.bank.takes[0].merge_trait == EchoBank.MERGE_TRAITS[trait_index], "real_merge_commits_the_selected_trait_and_one_final_body_" + label)
	var merged: EchoTake = sim.bank.takes[0]
	match EchoBank.MERGE_TRAITS[trait_index]:
		&"skill": _check(merged.retirement_kind() == donor.retirement_kind() and merged.retirement_kind() != host.retirement_kind(), "skill_binding_actually_changes_pin_to_the_donors_ink_skill")
		&"repair": _check(merged.condition == 80.0, "repair_binding_actually_patches45_to80_condition")
		&"power": _check(merged.level_at(0) == 1 and merged.condition == 30.0, "power_binding_actually_raises_grade_and_pays15_condition")
	ui.binding_ceremony.set_process(false)
	var after := RunSnapshot.capture(sim)
	var effect: Dictionary = ui.binding_ceremony.effect_profile()
	_check(effect["trait"] == EchoBank.MERGE_TRAITS[trait_index] and not effect["reverse"] and effect["values"]["merged_condition"] == merged.condition and effect["values"]["levels"] == merged.levels, "trait_overlay_reads_the_actual_final_condition_and_weapon_grades_" + label)
	if label == "skill":
		_check(effect["values"]["skill"] == &"ink", "transfer_seal_uses_the_actual_inherited_ink_mark")
	_check(ui.binding_ceremony._detail.text != "" and ui.binding_ceremony._detail.tooltip_text.begins_with(Loc.t(str(BindingCeremonyUi.TRAIT_KEYS[EchoBank.MERGE_TRAITS[trait_index]]))), "binding_receipt_matches_actual_selected_trait_" + label)
	_check(ui.binding_ceremony.active, "actual_merge_started_the_binding_ceremony")
	ui.binding_ceremony.elapsed = 0.0
	ui.binding_ceremony.step(0.001)
	_check(ui.binding_ceremony._frame == (3 if ui.reduced_effects else 0), "binding_uses_the_actual_preparation_or_reduced_final_pose")
	_check(ui.binding_ceremony._caption.text.contains(str(host.uid)) and ui.binding_ceremony._caption.text.contains(str(donor.uid)), "binding_receipt_names_the_actual_original_identities")
	await _shot("binding_actual_preparation_pose_" + label)
	ui.binding_ceremony.step(BindingCeremonyUi.DURATION * 0.8)
	_check(ui.binding_ceremony.body_count() == 1, "binding_last_pose_has_one_body")
	await _shot("binding_confirmed_one_body_" + label)
	_check(RunSnapshot.capture(sim) == after, "binding_visual_step_cannot_apply_the_transaction_again")
	await _activate(ui.undo_button, true)
	_check(RunSnapshot.capture(sim) == before and sim.bank.find_uid(donor.uid) != null, "actual_main_shop_Undo_restores_exact_two_originals")
	_check(ui.binding_ceremony.active, "actual_Undo_started_the_unstaple_ceremony")
	effect = ui.binding_ceremony.effect_profile()
	var restored_conditions: Array = effect["values"]["restored_conditions"].duplicate()
	restored_conditions.sort()
	_check(effect["reverse"] and restored_conditions == [45.0, 70.0], "unstaple_receipt_preserves_both_actual_original_conditions_" + label)
	ui.binding_ceremony.elapsed = 0.0
	ui.binding_ceremony.step(0.001)
	_check(ui.binding_ceremony._frame == (7 if ui.reduced_effects else 4), "unstaple_uses_the_actual_initial_or_reduced_final_pose")
	await _shot("binding_Undo_tool_engages_" + label)
	ui.binding_ceremony.step(BindingCeremonyUi.DURATION * 0.8)
	_check(ui.binding_ceremony.body_count() == 2, "unstaple_last_pose_has_two_restored_originals")
	await _shot("binding_undo_unstaples_originals_" + label)
	ui.binding_ceremony.skip()
	_check(RunSnapshot.capture(sim) == before, "skipping_unstaple_changes_only_presentation")
	ui.binding_ceremony.set_process(true)
	_check(not ui.start_button.disabled and not ui.reroll_button.disabled, "primary_shop_actions_remain_live_after_both_rituals")
	_cover("actual_merge_" + label + "_preview_one_body_ceremony_exact_undo_and_skip")


func _truth(solo: bool) -> void:
	var role: StringName = &"solo" if solo else &"looper"
	var sim := _shop("confession_truth_" + String(role), role)
	var uid := 0
	if solo:
		sim.player.hp = 10.0
	else:
		var take: EchoTake = sim.bank.takes[0]
		take.condition = 40.0
		uid = take.uid
		sim.selected_echo_uid = uid
	_main.shop_ui.refresh()
	var before := RunSnapshot.capture(sim)
	var permanent_clue_before: bool = _main.meta.story_clues.has(&"confession_truth")
	await _activate(_main.shop_ui.confession_button, true)
	await _shot("confession_truth_terms_" + String(role))
	await _activate(_main.shop_ui.confession.choice_buttons[0], true)
	_check(sim.expedition.bureau.confessions.size() == 1 and not sim.expedition.bureau.confessions[0]["committed"], "truth_is_reversible_pending_departure_" + String(role))
	_check(not StoryLedger.discovered(sim).has(&"confession_truth"), "pending_truth_does_not_farm_a_story_clue_" + String(role))
	_check(sim.player.hp == 16.0 if solo else sim.bank.find_uid(uid).condition == 52.0, "truth_applies_exact_promised_health_or_condition_" + String(role))
	await _shot("confession_truth_signed_" + String(role))
	var signed := RunSnapshot.capture(sim)
	_main.shop_ui.confession.chosen.emit(&"polish")
	_check(RunSnapshot.capture(sim) == signed and _main.shop_ui.confession.error_label.visible, "stale_confession_choice_fails_visibly_without_mutating_the_signed_record_" + String(role))
	await _shot("confession_truth_stale_choice_error_" + String(role))
	_fixture("stale_confession_" + String(role), "A stale already-signed UI intent is deliberately emitted after realinput signature; production Shop rejects it and the live pane shows its error")
	await _activate(_main.shop_ui.confession.return_button)
	_check(_main.shop_ui.confession_button.has_focus(), "confession_close_restores_its_shop_focus_" + String(role))
	await _pending_stock_hold(sim, "truth_" + String(role))
	sim = await _save_resume("pending_truth_" + String(role))
	if sim == null:
		return
	_check(_main.meta.story_clues.has(&"confession_truth") == permanent_clue_before, "saving_pending_truth_does_not_commit_a_permanent_clue_" + String(role))
	await _activate(_main.shop_ui.undo_button)
	_check(RunSnapshot.capture(sim) == before, "truth_Undo_after_continue_restores_the_exact_pending_transaction_" + String(role))
	_check(not _main.shop_ui.reroll_button.disabled, "withdrawing_the_signature_releases_stock_refresh_" + String(role))
	var reroll_quote := sim.shop.quote(ShopResult.REROLL, sim)
	var funds_before_refresh := sim.player.materials
	var rng_before_refresh := sim.rng.state
	await _activate(_main.shop_ui.reroll_button, true)
	_check(sim.player.materials == funds_before_refresh - reroll_quote.cost and sim.shop.rerolls == 1 and sim.rng.state != rng_before_refresh, "real_refresh_after_Undo_spends_one_quoted_price_and_advances_stock_rng_" + String(role))
	await _shot("withdrawn_signature_stock_refresh_" + String(role))
	await _activate(_main.shop_ui.confession_button)
	await _activate(_main.shop_ui.confession.choice_buttons[0])
	await _activate(_main.shop_ui.confession.return_button)
	await _activate(_main.shop_ui.start_button)
	_clear_plan(sim)
	_check(sim.expedition.bureau.confessions[0]["committed"] and StoryLedger.discovered(sim).has(&"confession_truth"), "real_departure_commits_original_testimony_once_" + String(role))
	_cover("truth_actual_UI_repair_or_Solo_health_and_exact_save_Undo_" + String(role))


func _polish(skip_inspection: bool) -> void:
	var label := "skipped" if skip_inspection else "registered"
	var sim := _shop("confession_polish_" + label)
	var funds := sim.player.materials
	await _activate(_main.shop_ui.confession_button)
	await _shot("confession_polish_terms_" + label)
	await _activate(_main.shop_ui.confession.choice_buttons[1])
	_check(sim.player.materials == funds + 12 and sim.expedition.debt == 0, "polish_exact_advance_without_new_debt_" + label)
	_check(_main.shop_ui.confession.choice_buttons[0].disabled and _main.shop_ui.confession.choice_buttons[1].disabled, "one_signature_disables_both_choices_for_the_act_" + label)
	await _activate(_main.shop_ui.confession.return_button)
	await _pending_stock_hold(sim, "polish_" + label)
	sim = await _save_resume("pending_polish_" + label)
	if sim == null:
		return
	await _activate(_main.shop_ui.start_button, true)
	_clear_plan(sim)
	_check(sim.expedition.bureau.confessions[0]["committed"] and sim.expedition.bureau.confessions[0]["state"] == &"active", "polish_departure_creates_announced_inspection_" + label)
	var terminal := _target(sim, BureauConfession.TERMINAL_ID)
	_check(not terminal.is_empty(), "next_encounter_contains_real_inspection_terminal_" + label)
	if skip_inspection:
		var cash := sim.player.materials
		var debt: int = sim.expedition.debt
		sim._end_wave()
		_main._sync_phase()
		_main._physics_process(_main.RECORD_BEAT + 0.01)
		_check(sim.expedition.bureau.confessions[0]["state"] == &"missed" and sim.expedition.debt == debt, "missed_inspection_is_recorded_without_creating_debt")
		_check(sim.player.materials == cash + sim.last_wave_earned + sim.last_interest, "missed_inspection_adds_only_normal_wave_income_without_hidden_tax")
		await _shot("confession_inspection_missed_record")
	else:
		sim.player.pos = BureauConfession.TERMINAL_POS
		sim.player.iframes = 0.0
		var hp := sim.player.hp
		await _joy(JOY_BUTTON_X)
		_check(sim.expedition.bureau.confessions[0]["state"] == &"passed" and sim.enemy_zones.size() == 1, "actual_controller_X_registers_and_creates_a_real_warning")
		_check(sim.player.hp == hp and sim.enemy_zones[0].warning > 0.0, "inspection_warns_before_its_impact")
		await _shot("confession_inspection_actual_warning")
		sim = await _save_resume("active_inspection_warning")
		if sim == null:
			return
		await _advance(1.2)
		_check(sim.player.hp < hp, "standing_in_announced_inspection_causes_actual_damage")
		var expected := RunSnapshot.restore(RunSnapshot.capture(sim))
		sim = await _save_resume("inspection_consumed_impact")
		if sim == null or expected == null:
			return
		for _step in 8:
			_main._physics_process(1.0 / 60.0)
			expected.step(1.0 / 60.0, Vector2.ZERO)
		_check(RunSnapshot.capture(sim) == RunSnapshot.capture(expected), "consumed_inspection_resumes_exactly_without_an_extra_impact")
		await _shot("confession_inspection_registered_aftermath")
		sim._end_wave()
		_main._sync_phase()
		_main._physics_process(_main.RECORD_BEAT + 0.01)
	await _activate(_main.shop_ui.confession_button, true)
	var status_key := "confession.ui.state_missed" if skip_inspection else "confession.ui.state_verified"
	_check(_main.shop_ui.confession._receipt.text.contains(Loc.t(status_key)), "next_shop_receipt_reads_the_actual_inspection_result_" + label)
	await _shot("confession_inspection_" + label + "_receipt")
	await _activate(_main.shop_ui.confession.return_button)
	await _activate(_main.shop_ui.start_button)
	_clear_plan(sim)
	sim.start_wave(5)
	_clear_plan(sim)
	sim._end_wave()
	_main._sync_phase()
	_main._physics_process(_main.RECORD_BEAT + 0.01)
	await _activate(_main.shop_ui.confession_button)
	_check(_main.shop_ui.confession._history.visible and _main.shop_ui.confession._history.text.contains(Loc.t(status_key)), "next_act_keeps_the_actual_prior_inspection_status_" + label)
	await _shot("confession_prior_act_history_" + label)
	await _activate(_main.shop_ui.confession.return_button)
	_fixture("inspection_history_" + label, "After real stage2 settlement and actual departure, canonical start_wave5/end_wave shortens the next-act setup solely to prove the actual previous record remains visible; this is not a completed Boss campaign")
	_fixture("inspection_travel_" + label, "Player repositioned onto the canonical inspection terminal to bound travel. Actual X registration, warning, impact, income and failure rules are production")
	_cover("polish_actual_advance_save_inspection_" + label)


func _delivery_solo() -> void:
	var sim := _battle("solo_stamp_delivery", &"solo", 2)
	var d: Dictionary = sim.expedition.bureau.delivery
	_check(not d.is_empty() and sim.echo_capacity() == 0 and sim.echoes.is_empty(), "Solo_delivery_uses_no_Echo_body")
	sim.player.pos = BureauEvents.STAMP
	sim.player.iframes = 0.0
	var hp := sim.player.hp
	await _advance(0.9)
	_check(sim.player.hp == hp and BureauEvents.profile(sim)["delivery"]["warning"], "stamp_visible_warning_precedes_actual_damage")
	await _shot("delivery_stamp_warning_geometry")
	await _advance(0.23)
	_check(sim.player.hp == hp - 8.0 and int(d["strikes"]) == 1, "stamp_actual_impact_hits_the_warned_player_once")
	await _shot("delivery_stamp_impact")
	sim.player.pos = BureauEvents.PICKUP
	await _key(KEY_E)
	_check(d["state"] == &"carrying", "actual_E_picks_up_the_courier_document")
	sim.player.pos = BureauEvents.SWITCH
	await _joy(JOY_BUTTON_X)
	_check(float(d["safe_left"]) == BureauEvents.SAFE_INTERVAL, "Solo_controller_X_opens_the_manual_safe_interval")
	await _shot("delivery_manual_switch_safe_interval")
	var before := RunSnapshot.capture(sim)
	await _key(KEY_P)
	_main._physics_process(3.0)
	_check(RunSnapshot.capture(sim) == before, "pause_freezes_stamp_clock_and_carried_document")
	await _activate(_main.pause_ui.resume_button)
	sim.player.pos = BureauEvents.PICKUP
	hp = sim.player.hp
	await _move(KEY_D, (BureauEvents.INBOX.x - BureauEvents.PICKUP.x) / sim.player.stats.get_stat(Stats.MOVE_SPEED))
	_check(sim.player.hp == hp and sim.player.pos.distance_to(BureauEvents.INBOX) < 12.0, "Solo_can_walk_the_actual_route_during_manual_safe_time")
	var funds := sim.player.materials
	await _key(KEY_E)
	_check(d["state"] == &"delivered" and d["rewarded"] and sim.player.materials == funds + 8, "actual_inbox_E_pays_one_eight_material_delivery")
	await _key(KEY_E)
	_check(sim.player.materials == funds + 8, "repeated_delivery_input_cannot_duplicate_the_reward")
	await _shot("delivery_Solo_completed_once")
	await _save_resume("delivered_once")
	_fixture("delivery_Solo_positions", "Player staged at stamp centre to prove warned8damage, then at pickup/switch to shorten travel. Actual D walking crosses the395unit corridor at ordinary MOVE_SPEED; E/X interactions, paused clock and once-only reward are real")
	_cover("Solo_stamp_warning_real_impact_manual_timing_pause_carry_and_once_reward")


func _delivery_echo() -> void:
	var sim := _battle("recorded_stamp_switch", &"looper", 2)
	sim.player.pos = BureauEvents.SWITCH
	await _advance(0.2)
	await _key(KEY_E)
	_check(sim.recorder.work_actions.size() == 1 and sim.recorder.work_actions[0]["target_id"] == BureauEvents.SWITCH_ID, "actual_E_records_the_independent_stamp_switch")
	await _advance(0.1)
	sim._end_wave()
	_main._sync_phase()
	_main._physics_process(_main.RECORD_BEAT + 0.01)
	var uid: int = sim.bank.takes.back().uid
	var original_condition := sim.bank.find_uid(uid).condition
	sim.start_wave(6)
	_clear_plan(sim)
	_main._sync_phase()
	sim.player.pos = WorldArena.move_body(BureauEvents.SWITCH + Vector2(180.0, -60.0), Vector2.ZERO, PlayerState.RADIUS)
	var events: Array[Dictionary] = []
	sim.echo_work_performed.connect(func(info: Dictionary) -> void:
		if info.get("target_id", &"") == BureauEvents.SWITCH_ID or info.get("kind", &"") == &"press":
			events.append(info.duplicate(true)))
	await _advance(0.15)
	sim = await _save_resume("Echo_switch_before_work")
	if sim == null:
		return
	events.clear()
	sim.echo_work_performed.connect(func(info: Dictionary) -> void: events.append(info.duplicate(true)))
	await _advance(0.1)
	var successes := 0
	var switch_event: Dictionary = {}
	for info in events:
		if info.get("success", false):
			successes += 1
			switch_event = info
	_check(switch_event.get("target_id", &"") == BureauEvents.SWITCH_ID, "replayed_work_keeps_the_actual_safe_switch_identity")
	var view := WorldArena.camera_rect(sim.player.pos, WorldArena.display_viewport(root.get_visible_rect().size))
	var mark := ExpeditionInk.work_profile(switch_event, view)
	_check(mark.get("visible", false) and mark.get("target_id", &"") == BureauEvents.SWITCH_ID and mark.get("name_key", "") == "interaction.bureau_switch", "live_work_mark_visibly_names_the_safe_lever_instead_of_a_heavy_press")
	_check(successes == 1 and float(sim.expedition.bureau.delivery["safe_left"]) > 0.0, "restored_Echo_executes_the_real_recorded_switch_once")
	_check(sim.bank.find_uid(uid).condition <= original_condition - EchoWork.CONDITION_COST, "successful_switch_replay_pays_real_extra_wear")
	await _shot("delivery_Echo_old_route_opens_safe_interval")
	var expected := RunSnapshot.restore(RunSnapshot.capture(sim))
	sim = await _save_resume("Echo_switch_after_work")
	if sim == null or expected == null:
		return
	for _step in 8:
		_main._physics_process(1.0 / 60.0)
		expected.step(1.0 / 60.0, Vector2.ZERO)
	_check(RunSnapshot.capture(sim) == RunSnapshot.capture(expected), "consumed_switch_cursor_resumes_without_duplicate_work_or_wear")
	sim.select_echo(uid)
	await _key(KEY_SPACE)
	_check(sim.expedition.bureau.retired.size() > 0 and sim.expedition.bureau.retired.back()["work"] >= 1, "retirement_summary_counts_only_work_actually_performed")
	await _shot("retirement_real_work_receipt")
	var rescued: Dictionary = {}
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue" and not item["used"]:
			rescued = item
			break
	if _check(not rescued.is_empty(), "cleanup_scene_has_an_actual_natural_worker"):
		sim.player.pos = rescued["pos"]
		await _key(KEY_E)
		_check(Expedition._worker(sim, rescued["id"])["state"] == &"safe", "cleanup_survivor_is_saved_by_actual_interaction")
	sim.player.pos = Vector2(300.0, 240.0)
	sim._end_wave()
	_main._sync_phase()
	_check(sim.phase == Sim.Phase.SHOP and sim.expedition.bureau.retired.back()["uid"] == uid, "night_cleanup_keeps_the_actual_retired_identity")
	await _shot("night_cleanup_actual_survivor_and_retirement")
	_fixture("cleanup_camera", "Actual E rescued the natural current worker; normal end_wave settled the encounter. Player repositioned at300,240 solely to show the safe registry/edge cleanup, with battle threats already legitimately settled")
	_fixture("recorded_Echo_act_skip", "Actual stage2 E records the switch at.2s and normal end_wave produces the take; canonical start_wave6 skips intervening acts only. Player is staged near the stamp to show the old Echo operating its safe lever. The same recorded route is retained and replayed; no free Echo is inserted for the mechanic")
	_cover("actual_recorded_switch_old_Echo_help_exact_before_after_work_resume_and_retirement")
	_cover("actual_saved_worker_and_retired_copy_night_cleanup")


func _pending_stock_hold(sim: Sim, id: String) -> void:
	var before := RunSnapshot.capture(sim)
	var quote := sim.shop.quote(ShopResult.REROLL, sim)
	_check(not quote.ok and quote.reason == &"pending_confession" and _main.shop_ui.reroll_button.disabled, "pending_signature_blocks_refresh_with_one_authoritative_reason_" + id)
	_check(_main.shop_ui.reroll_button.tooltip_text.contains(Loc.t("reason.pending_confession")), "stock_hold_reason_is_visible_before_an_attempt_" + id)
	await _mouse_click(_main.shop_ui.reroll_button.get_global_rect().get_center())
	_check(RunSnapshot.capture(sim) == before, "real_disabled_refresh_click_preserves_all_state_and_both_rng_" + id)
	_main.shop_ui.reroll_button.pressed.emit()
	_check(RunSnapshot.capture(sim) == before, "stale_refresh_intent_cannot_destroy_the_pending_signature_or_advance_rng_" + id)
	await _shot("pending_confession_holds_stock_" + id)
	_fixture("stale_stock_" + id, "A real mouse click targets the disabled refresh control, then a deliberately stale pressed signal tests the same authoritative quote guard. Both must preserve the complete model including RNG and reversible signature")


func _hover(control: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	Input.parse_input_event(event)
	await process_frame
	await _wait(0.8)


func _mouse_click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await _wait(0.025)


func _target(sim: Sim, id: StringName) -> Dictionary:
	for item: Dictionary in sim.interactables:
		if item["id"] == id:
			return item
	return {}


func _save_resume(id: String) -> Sim:
	var before := RunSnapshot.capture(_main.sim)
	if not _main.paused:
		await _key(KEY_P)
	_check(_main.pause_ui.visible, "actual_pause_menu_for_save_" + id)
	await _activate(_main.pause_ui.save_button)
	if not _check(_main.sim == null and _main.character_select.visible, "save_actually_returns_to_title_" + id):
		return null
	_check(_main.character_select.continue_button.is_visible_in_tree(), "saved_continue_entry_is_available_" + id)
	await _activate(_main.character_select.continue_button, true)
	if not _check(_main.sim != null, "actual_continue_restores_a_new_session_" + id):
		return null
	_check(RunSnapshot.capture(_main.sim) == before, "save_continue_full_exact_snapshot_" + id)
	return _main.sim


func _clear_plan(sim: Sim) -> void:
	sim._plan.clear()
	sim._plan_idx = 0
	sim.pending.clear()


func _advance(seconds: float) -> void:
	for _step in ceili(seconds * 60.0):
		if _main.sim == null or _finished:
			return
		_main._physics_process(1.0 / 60.0)
		await process_frame


func _move(code: Key, seconds: float) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await _advance(seconds)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _activate(button: Button, gamepad: bool = false) -> bool:
	if not _check(button != null and button.is_visible_in_tree() and not button.disabled, "actual_visible_enabled_UI_" + (button.text if button != null else "missing")):
		return false
	button.grab_focus()
	await _settle()
	_check(root.get_visible_rect().grow(1.0).encloses(button.get_global_rect()), "focused_control_inside_native_canvas_" + button.text)
	if gamepad:
		await _joy(JOY_BUTTON_A)
	else:
		await _key(KEY_ENTER)
	return true


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
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


func _button(surface: Control, key: String) -> Button:
	for button: Button in surface.find_children("*", "Button", true, false):
		if button.text == Loc.t(key):
			return button
	return null


func _shot(id: String) -> void:
	if _finished:
		return
	var before := RunSnapshot.capture(_main.sim) if _main.sim != null else {}
	await _settle()
	if not _headless_flow:
		_main._view.queue_redraw()
		_main.hud.queue_redraw()
		RenderingServer.force_draw()
		var pixels := root.get_texture().get_image()
		_last_pixels = pixels
		_check(pixels != null and not pixels.is_empty() and pixels.get_size() == _size, "original_native_pixels_" + id)
		_check(pixels.save_png(_out.path_join(id + ".png")) == OK, "native_capture_saved_" + id)
	var outside := _outside_controls()
	_check(outside.is_empty(), "enabled_primary_controls_inside_native_canvas_" + id)
	if _main.sim != null:
		_check(RunSnapshot.capture(_main.sim) == before, "rendering_preserves_full_snapshot_and_both_rng_" + id)
		var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(before))
		var restored := RunSnapshot.restore(json_roundtrip)
		_check(restored != null and RunSnapshot.capture(restored) == before, "strict_JSON_snapshot_restoration_" + id + "_" + RunSnapshot.last_error)
	_summary.screenshots[id] = {"path": "" if _headless_flow else id + ".png", "frame": _frames, "size": [_size.x, _size.y], "native_pixels": not _headless_flow, "outside_controls": outside}
	print("bureau gameplay: " + id)


func _outside_controls() -> Array[String]:
	var surfaces: Array[Control] = []
	for surface: Control in [_main.character_select, _main.shop_ui, _main.end_ui, _main.echo_archive_ui, _main.pause_ui, _main.context_ui]:
		if surface.visible:
			surfaces.append(surface)
	var outside: Array[String] = []
	for surface in surfaces:
		for button: BaseButton in surface.find_children("*", "BaseButton", true, false):
			if not button.is_visible_in_tree() or button.disabled:
				continue
			var parent := button.get_parent()
			var scrollable := false
			while parent != null and parent != surface:
				scrollable = scrollable or parent is ScrollContainer
				parent = parent.get_parent()
			if not scrollable and not root.get_visible_rect().grow(1.0).encloses(button.get_global_rect()):
				outside.append(str(button.get_path()) + " " + str(button.get_global_rect()))
	return outside


func _fixture(id: String, detail: String) -> void:
	_summary.fixtures.append({"id": id, "setup": detail})


func _cover(id: String) -> void:
	_summary.coverage.append(id)


func _check(condition: bool, id: String) -> bool:
	_summary.checks.append({"id": id, "passed": condition})
	if not condition and not _failures.has(id):
		_failures.append(id)
		printerr("bureau gameplay FAILED: " + id)
	return condition


func _settle() -> void:
	for _frame in 4:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _finish() -> void:
	if _finished:
		return
	_finished = true
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"retire_echo", &"ui_accept"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	_summary["success"] = _failures.is_empty()
	_summary["failures"] = _failures
	_summary["frames"] = _frames
	_summary["wall_seconds"] = float(Time.get_ticks_msec() - _started) / 1000.0
	var file := FileAccess.open(_out.path_join("tooltip-summary.json" if _tooltip_only else "summary.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_summary, "\t", true, true))
		file.close()
	if _main != null:
		_main._detach_presentation_session()
		_main.audio.stop_all()
		_main.queue_free()
		_main = null
	print("bureau gameplay: %s (%d shots, %.2fs)" % ["OK" if _failures.is_empty() else "FAILED", _summary.screenshots.size(), _summary.wall_seconds])
	await process_frame
	await process_frame
	quit(0 if _failures.is_empty() else 1)
