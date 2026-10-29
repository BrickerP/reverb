extends SceneTree
# Actual-window weapon sale fixture. Run the EN/ZH, normal/reduced matrix:
# REVERB_LANG=en REVERB_REDUCED_EFFECTS=0 godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/weapon_sell_probe.gd

const DEADLINE_FRAMES := 1500
const SETTLE_FRAMES := 6

var _main: Node
var _frames := 0
var _failed := false
var _shots_dir := ""
var _reduced := false
var _summary: Dictionary = {"source": "fixture", "checks": {}, "screenshots": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_weapon_sell_probe_suspend.json")
	OS.set_environment("REVERB_SAVE", "user://weapon_sell_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://weapon_sell_probe_runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://weapon_sell_probe_feedback.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://weapon_sell_probe_settings.json")
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	_clear_fixture_files()
	Loc.reset_lang()
	_reduced = OS.get_environment("REVERB_REDUCED_EFFECTS") == "1"
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before weapon sell probe completed")
	return false


func _run() -> void:
	_summary["stage"] = "enter_shop"
	if not (await _enter_shop()):
		return
	_summary["stage"] = "sell_and_undo"
	if not (await _sell_and_undo_case()):
		return
	_summary["stage"] = "last_weapon"
	if not (await _last_weapon_case()):
		return
	_summary["stage"] = "history_boundaries"
	if not (await _history_boundaries_case()):
		return
	_summary["stage"] = "complete"
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["fixture"] = {"run_source": OS.get_environment("REVERB_RUN_SOURCE"),
		"input": "focused ui_accept for sell, undo, reroll and start"}
	if not _write_summary():
		return
	_main.show_select()
	_main.audio.stop_all()
	print("weapon sell probe: %s" % JSON.stringify({"language": Loc.lang,
		"reduced_effects": _reduced, "checks": (_summary["checks"] as Dictionary).size()}))
	print("weapon sell probe: OK")
	quit()


func _enter_shop() -> bool:
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible:
			break
		await process_frame
	if not _require(_main.character_select != null, "Main reaches character selection"):
		return false
	_main.meta.unlocked[&"looper"] = true
	_main.choose_character(&"looper", 220011)
	await _wait_frames(3)
	_main.paused = true
	_main.pause_ui.close()
	_main.sim.phase = Sim.Phase.SHOP
	_main._phase = Sim.Phase.SHOP
	_main._view.visible = false
	_main.hud.visible = false
	_main.shop_ui.set_reduced_effects(_reduced)
	_main.shop_ui.open(_main.sim)
	await _wait_frames(SETTLE_FRAMES)
	return _require(_main.shop_ui.visible, "actual ShopUi is visible")


func _sell_and_undo_case() -> bool:
	_stage_six()
	await _wait_frames(SETTLE_FRAMES)
	var sim: Sim = _main.sim
	var ui: ShopUi = _main.shop_ui
	var initial := _snapshot()
	var family_text := Loc.t("shop.family_mastery_arcane")
	if not _require(_find_label(family_text) != null and _find_label(
			Loc.t("shop.echo_value", [3, 48]), true) != null,
			"four Arcane weapons show mastery and effective 48% core text"):
		return false
	if not (await _assert_full_layout()):
		return false
	if not (await _capture("full_six_before")):
		return false
	var sold_index := 1
	var sold_id := sim.player.weapons[sold_index].id
	var sold_level := sim.player.level_at(sold_index)
	var sold_cooldown := sim.player.cooldowns[sold_index]
	var refund := Shop.resale_total(sim.player.weapons[sold_index], sold_level)
	var quote := sim.shop.quote(ShopResult.SELL, sim, null, sold_index)
	if not _require(quote.ok and quote.cost == -refund
			and ui.build_panel._sell_buttons[sold_index].text == Loc.t("shop.sell", [refund]),
			"sale quote, button and refund use the same resale formula"):
		return false
	var materials_before := sim.player.materials
	var feedback_before := ui.material_feedback_runs
	var sale_audio: int = _main.audio.play_count(&"buy")
	var changes: Array[WeaponChangeInfo] = []
	var collect := func(info: WeaponChangeInfo) -> void: changes.append(info)
	sim.weapon_changed.connect(collect)
	if not (await _activate(ui.build_panel._sell_buttons[sold_index])):
		return false
	if not _require(sim.player.materials == materials_before + refund
			and sim.player.weapons.size() == 5 and sim.player.weapons[sold_index].id == sold_id
			and sim.player.level_at(sold_index) != sold_level
			and not is_equal_approx(sim.player.cooldowns[sold_index], sold_cooldown),
			"middle duplicate sale removes the exact level/cooldown slot"):
		return false
	if not _require(ui.material_feedback_runs == feedback_before + 1
			and _main.audio.play_count(&"buy") == sale_audio + 1,
			"sale pulses materials and plays the existing sale audio exactly once"):
		return false
	if not _require(changes.size() == 1 and changes[0].index == sold_index
			and changes[0].before_id == sold_id and changes[0].after_id == &""
			and changes[0].reason == ShopResult.SELL,
			"middle duplicate sale reports the removed index and ID exactly"):
		return false
	if not _require(Combat.family_count(sim.player.weapons, &"arcane") == 3
			and is_equal_approx(sim.echo_power(), 0.4)
			and _find_label(family_text) == null
			and _find_label(Loc.t("shop.echo_value", [3, 40]), true) != null,
			"sale transitions family 4 to 3 and core echo 48% to 40%"):
		return false
	var focus := root.gui_get_focus_owner()
	if not _require(focus != null and ui.is_ancestor_of(focus) and focus.is_visible_in_tree()
			and focus.focus_mode != Control.FOCUS_NONE,
			"keyboard focus remains valid when the next upgrade is disabled"):
		return false
	if not (await _capture("after_middle_sale")):
		return false
	var after_first := _snapshot()
	var second_index := sim.player.weapons.size() - 1
	if not (await _activate(ui.build_panel._sell_buttons[second_index])):
		return false
	var after_second := _snapshot()
	if not _require(after_second != after_first and sim.player.weapons.size() == 4,
			"two consecutive focused sales create distinct states"):
		return false
	var undo_audio: int = _main.audio.play_count(&"equipment_undo")
	if not (await _activate(ui.undo_button)):
		return false
	if not _require(_snapshot() == after_first, "first focused undo restores the second sale exactly"):
		return false
	if not (await _activate(ui.undo_button)):
		return false
	if not _require(_snapshot() == initial and _main.audio.play_count(&"equipment_undo") == undo_audio + 2,
			"second focused undo restores IDs, levels, cooldowns and materials exactly"):
		return false
	if not _require(changes.size() == 4 and changes[3].index == sold_index
			and changes[3].before_id == &"" and changes[3].after_id == sold_id
			and changes[3].reason == ShopResult.UNDO,
			"final undo reports the restored middle duplicate slot exactly"):
		return false
	if not _require(Combat.family_count(sim.player.weapons, &"arcane") == 4
			and is_equal_approx(sim.echo_power(), 0.48), "undo restores family mastery and 48% core"):
		return false
	if not (await _capture("after_two_undos")):
		return false
	_summary["checks"]["sell_undo"] = {"refund": refund, "sold_id": String(sold_id),
		"sold_level": sold_level, "sold_cooldown": sold_cooldown, "exact_restore": true}
	if sim.weapon_changed.is_connected(collect):
		sim.weapon_changed.disconnect(collect)
	return true


func _last_weapon_case() -> bool:
	_stage([&"pistol"], [0], [0.37])
	await _wait_frames(SETTLE_FRAMES)
	var ui: ShopUi = _main.shop_ui
	var sim: Sim = _main.sim
	var before := _snapshot()
	var button := ui.build_panel._sell_buttons[0]
	if not _require(button.disabled and button.text == Loc.t("shop.sell_last"),
			"last weapon sell action is visibly disabled"):
		return false
	var quote := sim.shop.quote(ShopResult.SELL, sim, null, 0)
	var result := sim.shop.apply(ShopResult.SELL, sim, null, 0)
	if not _require(not quote.ok and quote.reason == &"last" and not result.ok
			and _snapshot() == before, "last weapon sale fails without state change"):
		return false
	if not (await _capture("last_weapon_disabled")):
		return false
	_summary["checks"]["last_weapon"] = true
	return true


func _history_boundaries_case() -> bool:
	_stage([&"pistol", &"smg", &"rifle"], [0, 0, 0], [0.1, 0.2, 0.3])
	await _wait_frames(SETTLE_FRAMES)
	var ui: ShopUi = _main.shop_ui
	var sim: Sim = _main.sim
	if not (await _activate(ui.build_panel._sell_buttons[1])):
		return false
	if not _require(sim.shop.can_undo(), "sale creates undo before reroll"):
		return false
	if not (await _activate(ui.reroll_button)):
		return false
	if not _require(not sim.shop.can_undo() and ui.undo_button.disabled,
			"reroll clears sale undo history"):
		return false
	# Reroll changed offers only; create one more sale then cross the wave boundary.
	if not (await _activate(ui.build_panel._sell_buttons[0])):
		return false
	if not _require(sim.shop.can_undo(), "new sale creates undo before wave start"):
		return false
	if not (await _activate(ui.start_button)):
		return false
	if not _require(sim.phase == Sim.Phase.WAVE and not sim.shop.can_undo(),
			"start wave clears sale undo history"):
		return false
	_summary["checks"]["history_boundaries"] = {"reroll": true, "wave_start": true}
	return true


func _stage_six() -> void:
	_stage([&"nova_core", &"nova_core", &"nova_core", &"nova_core", &"pistol", &"smg"],
			[0, 1, WeaponDef.MAX_LEVEL, 2, 0, 0], [0.11, 0.22, 0.33, 0.44, 0.55, 0.66])


func _stage(ids: Array[StringName], levels: Array[int], cooldowns: Array[float]) -> void:
	var sim: Sim = _main.sim
	sim.phase = Sim.Phase.SHOP
	sim.wave = 5
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for i in ids.size():
		sim.player.add_weapon(Content.weapon(ids[i]))
		sim.player.weapon_levels[i] = levels[i]
		sim.player.cooldowns[i] = cooldowns[i]
	sim.player.materials = 500
	sim.shop.offers.clear()
	sim.shop.rerolls = 0
	sim.shop.clear_history()
	_main._phase = Sim.Phase.SHOP
	_main.paused = true
	_main.hud.visible = false
	_main._view.visible = false
	_main.shop_ui.open(sim)
	_main.shop_ui.set_reduced_effects(_reduced)


func _snapshot() -> Dictionary:
	var data := ShopState.capture(_main.sim).to_dict()
	data["cooldowns"] = _main.sim.player.cooldowns.duplicate()
	return data


func _find_label(text: String, exact: bool = false) -> Label:
	for node: Node in _main.shop_ui.build_panel.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and ((label.text == text) if exact else label.text.contains(text)):
			return label
	return null


func _assert_full_layout() -> bool:
	var ui: ShopUi = _main.shop_ui
	var viewport := root.get_visible_rect()
	for surface: Control in [ui, ui.build_panel, ui.echo_panel, ui.reroll_button,
			ui.undo_button, ui.start_button]:
		if not _require(surface.is_visible_in_tree() and viewport.encloses(surface.get_global_rect()),
				"full-shop surface remains inside actual viewport"):
			return false
	var scroll := ui.build_panel.get_child(0) as ScrollContainer
	for i in ui.build_panel._sell_buttons.size():
		var sell: Button = ui.build_panel._sell_buttons[i]
		var upgrade: Button = ui.build_panel._upgrade_buttons[i]
		for button: Button in [upgrade, sell]:
			scroll.ensure_control_visible(button)
			await _wait_frames(2)
			if not _require(viewport.encloses(button.get_global_rect())
					and ui.build_panel._cards[i].get_global_rect().encloses(button.get_global_rect()),
					"nested weapon action is fully visible inside its card and viewport"):
				return false
	var mastery := _find_label(Loc.t("shop.family_mastery_arcane"))
	if not _require(mastery != null and mastery.autowrap_mode != TextServer.AUTOWRAP_OFF
			and mastery.get_visible_line_count() == mastery.get_line_count(),
			"six-weapon family summary remains fully wrapped and readable"):
		return false
	scroll.ensure_control_visible(mastery)
	await _wait_frames(SETTLE_FRAMES)
	if not _require(viewport.encloses(mastery.get_global_rect()),
			"wrapped family summary is fully visible for capture"):
		return false
	return true


func _activate(button: Button) -> bool:
	if not _require(button != null and button.is_visible_in_tree() and not button.disabled,
			"focused shop action is available"):
		return false
	var scroll := _main.shop_ui.build_panel.get_child(0) as ScrollContainer
	if _main.shop_ui.build_panel.is_ancestor_of(button):
		scroll.ensure_control_visible(button)
		await _wait_frames(2)
	button.grab_focus()
	await _wait_frames(2)
	if not _require(button.has_focus(), "shop action owns keyboard focus"):
		return false
	var down := InputEventAction.new()
	down.action = &"ui_accept"
	down.pressed = true
	root.push_input(down, false)
	await process_frame
	var up := InputEventAction.new()
	up.action = &"ui_accept"
	up.pressed = false
	root.push_input(up, false)
	await _wait_frames(SETTLE_FRAMES)
	return not _failed


func _capture(state: String) -> bool:
	_summary["waiting_for_frame"] = state
	await RenderingServer.frame_post_draw
	_summary.erase("waiting_for_frame")
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty()
			and image.get_width() == 1280 and image.get_height() == 720,
			"%s screenshot is a non-empty 1280x720 frame" % state):
		return false
	var mode := "reduced" if _reduced else "normal"
	var filename := "sell_%s_%s_%s.png" % [Loc.lang, mode, state]
	if not _require(image.save_png(_shots_dir.path_join(filename)) == OK,
			"%s screenshot saves" % state):
		return false
	(_summary["screenshots"] as Dictionary)[state] = filename
	print("wrote shots/%s" % filename)
	return true


func _write_summary() -> bool:
	var mode := "reduced" if _reduced else "normal"
	var filename := "sell_%s_%s_summary.json" % [Loc.lang, mode]
	var file := FileAccess.open(_shots_dir.path_join(filename), FileAccess.WRITE)
	if file == null:
		_fail("failed to open %s" % filename)
		return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	print("wrote shots/%s" % filename)
	return true


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_summary["frames"] = _frames
	_summary["failure"] = message
	printerr("weapon sell probe FAILED: %s" % message)
	if _shots_dir != "":
		var mode := "reduced" if _reduced else "normal"
		var file := FileAccess.open(_shots_dir.path_join(
				"sell_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n")
			file.close()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["weapon_sell_probe_save.json", "weapon_sell_probe_runs.jsonl",
			"weapon_sell_probe_feedback.jsonl", "weapon_sell_probe_settings.json"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
