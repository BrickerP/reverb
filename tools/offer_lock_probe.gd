extends SceneTree
# Actual-window offer-lock fixture. Run EN/ZH x normal/reduced with --max-fps 60:
# REVERB_LANG=en REVERB_REDUCED_EFFECTS=0 godot --path . --max-fps 60 \
#   --disable-vsync --script res://tools/offer_lock_probe.gd

const DEADLINE_FRAMES := 1800
const SETTLE_FRAMES := 6

var _main: Node
var _frames := 0
var _failed := false
var _shots_dir := ""
var _reduced := false
var _summary: Dictionary = {"source": "fixture", "checks": {}, "screenshots": {},
	"diagnostics": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://offer_lock_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://offer_lock_probe_runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://offer_lock_probe_feedback.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://offer_lock_probe_settings.json")
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
		_fail("deadline exceeded before offer-lock probe completed")
	return false


func _run() -> void:
	if not (await _enter_shop()): return
	if not (await _input_and_hold_case()): return
	if not (await _sold_hold_case()): return
	if not (await _sell_undo_case()): return
	if not (await _constraint_geometry_case()): return
	if not (await _history_boundaries_case()): return
	if not (await _cleanup_case()): return
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["fixture"] = {"run_source": OS.get_environment("REVERB_RUN_SOURCE"),
		"timing": "real-time --max-fps 60"}
	if not _write_summary(): return
	print("offer lock probe: OK")
	quit()


func _enter_shop() -> bool:
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible: break
		await process_frame
	if not _require(_main.character_select != null, "Main reaches title"): return false
	_main.meta.unlocked[&"looper"] = true
	_main.choose_character(&"looper", 699)
	await _wait_frames(4)
	_main.paused = true
	_main.pause_ui.close()
	_main.sim.phase = Sim.Phase.SHOP
	_main._phase = Sim.Phase.SHOP
	_main._view.visible = false
	_main.hud.visible = false
	_main.shop_ui.set_reduced_effects(_reduced)
	_main.shop_ui.open(_main.sim)
	await _wait_frames(SETTLE_FRAMES)
	_summary["diagnostics"]["enter"] = _diag()
	return _require(_main.shop_ui.visible, "actual ShopUi opens")


func _input_and_hold_case() -> bool:
	_stage_offers([_weapon(&"pistol", 9), _weapon(&"smg", 21),
		_weapon(&"shotgun", 33), _weapon(&"rifle", 47)], 200)
	await _wait_frames(SETTLE_FRAMES)
	var sim: Sim = _main.sim
	var ui: ShopUi = _main.shop_ui
	var original := sim.shop.offers[1]
	var materials := sim.player.materials
	var weapons := sim.player.weapons.size()
	var material_feedback := ui.material_feedback_runs
	var buy_audio: int = int(_main.audio.play_count(&"buy"))
	var apply_audio: int = int(_main.audio.play_count(&"equipment_apply"))
	var lock := _card(1).lock_button
	if not (await _mouse_click(lock)): return false
	if not _require(original.locked and not original.sold and sim.player.materials == materials
			and sim.player.weapons.size() == weapons
			and ui.material_feedback_runs == material_feedback
			and int(_main.audio.play_count(&"buy")) == buy_audio
			and int(_main.audio.play_count(&"equipment_apply")) == apply_audio,
			"physical nested Lock click does not purchase or transact"): return false
	var locked_card := _card(1)
	var drag_from := locked_card.lock_button.get_global_rect().get_center()
	_push_motion(drag_from, Vector2.ZERO, 0)
	_push_button(drag_from, true)
	await _wait_frames(2)
	_push_motion(drag_from + Vector2(90, 60), Vector2(90, 60), MOUSE_BUTTON_MASK_LEFT)
	await _wait_frames(3)
	if not _require(not root.gui_is_dragging(), "drag beginning over Lock never starts equipment drag"):
		return false
	_push_button(drag_from + Vector2(90, 60), false)
	await _wait_frames(SETTLE_FRAMES)
	if not _require(original.locked and not original.sold and sim.player.materials == materials
			and sim.player.weapons.size() == weapons,
			"dragging away from the lock button neither toggles nor purchases"):
		return false
	# Keyboard toggle twice; refreshed nested control owns focus after each toggle.
	if not (await _activate(_card(1).lock_button)): return false
	if not _require(not original.locked and _card(1).lock_button.has_focus(),
			"keyboard unlock preserves nested focus"): return false
	if not (await _activate(_card(1).lock_button)): return false
	if not _require(original.locked and _card(1).lock_button.has_focus(),
			"keyboard lock preserves nested focus"): return false
	if not (await _activate(_card(2).lock_button)): return false
	var moved := sim.shop.offers[2]
	if not _require(not original.locked and moved.locked and sim.shop.locked_offer() == moved,
			"one free hold moves to another offer"): return false
	if not (await _activate(_card(2).lock_button)): return false
	if not _require(sim.shop.locked_offer() == null, "second toggle unlocks the hold"): return false
	# Re-lock nonzero index and preserve exact object/index/price through reroll and next shop.
	if not (await _activate(_card(1).lock_button)): return false
	var held := sim.shop.offers[1]
	var held_price := held.price
	if not (await _activate(ui.reroll_button)): return false
	if not _require(sim.shop.offers[1] == held and held.locked and held.price == held_price,
			"reroll preserves held object, nonzero index and price"): return false
	if not (await _capture("held_reroll")): return false
	sim.shop.roll(sim)
	ui.refresh()
	await _wait_frames(SETTLE_FRAMES)
	if not _require(sim.shop.offers[1] == held and held.locked and held.price == held_price,
			"next shop preserves held object, nonzero index and price"): return false
	_summary["checks"]["hold"] = {"index": 1, "price": held_price,
		"object_preserved": true, "free": true}
	return true


func _sold_hold_case() -> bool:
	var sim: Sim = _main.sim
	var ui: ShopUi = _main.shop_ui
	var held := sim.shop.offers[1]
	var before_count := sim.player.weapons.size()
	if not (await _activate(_card(1))): return false
	if not _require(held.sold and sim.player.weapons.size() == before_count + 1,
			"buying the held card sells it once"): return false
	if not (await _activate(ui.reroll_button)): return false
	if not _require(not sim.shop.offers.has(held) and sim.shop.locked_offer() == null,
			"sold held offer stops surviving rerolls"): return false
	if not (await _capture("sold_hold_removed")): return false
	_summary["checks"]["sold_hold"] = true
	return true


func _sell_undo_case() -> bool:
	_stage_equipment_and_offers()
	await _wait_frames(SETTLE_FRAMES)
	var sim: Sim = _main.sim
	var ui: ShopUi = _main.shop_ui
	var locked := sim.shop.offers[2]
	if not (await _activate(_card(2).lock_button)): return false
	var before := _snapshot()
	var changes: Array[WeaponChangeInfo] = []
	var collect := func(info: WeaponChangeInfo) -> void: changes.append(info)
	sim.weapon_changed.connect(collect)
	if not (await _activate(ui.build_panel._sell_buttons[1])): return false
	if not _require(changes.size() == 1 and changes[0].index == 1
			and changes[0].before_id == &"pistol" and changes[0].after_id == &"",
			"duplicate middle sale reports saved index and ID"): return false
	# Move lock without history, then undo must restore the transaction snapshot.
	if not (await _activate(_card(0).lock_button)): return false
	if not (await _activate(ui.undo_button)): return false
	if not _require(_snapshot() == before and sim.shop.offers[2].locked
			and sim.shop.offers[2].id() == locked.id()
			and changes.size() == 2 and changes[1].index == 1
			and changes[1].after_id == &"pistol",
			"sell undo restores lock snapshot and duplicate sale event index"): return false
	if sim.weapon_changed.is_connected(collect): sim.weapon_changed.disconnect(collect)
	if not (await _capture("sell_undo_lock_restore")): return false
	_summary["checks"]["sell_undo"] = true
	return true


func _constraint_geometry_case() -> bool:
	var sim: Sim = _main.sim
	var ids: Array[StringName] = [&"pistol", &"smg", &"shotgun", &"rifle", &"orb", &"longbow"]
	_set_equipment(ids, [0, 0, 0, 0, 0, 0])
	sim.player.materials = 0
	sim.player.items[&"loud_speaker"] = Content.item(&"loud_speaker").max_stack
	_stage_offers([_weapon(&"twin_fangs", 1), _weapon(&"rail_spike", 999),
		_item(&"loud_speaker", 1), _item(&"spare_deck", 7)], 0)
	await _wait_frames(SETTLE_FRAMES)
	var reasons := [&"full", &"full", &"maxed", &"poor"]
	for i in 4:
		if not _require(_card(i).blocked_reason == reasons[i],
				"fixture exposes full/full/maxed/poor card states"): return false
	if not (await _assert_geometry()): return false
	if not (await _capture("full_constraints")): return false
	_summary["checks"]["geometry"] = true
	return true


func _history_boundaries_case() -> bool:
	_stage_equipment_and_offers()
	await _wait_frames(SETTLE_FRAMES)
	var sim: Sim = _main.sim
	var ui: ShopUi = _main.shop_ui
	if not (await _activate(ui.build_panel._sell_buttons[1])): return false
	if not _require(sim.shop.can_undo(), "sale creates undo history"): return false
	if not (await _activate(ui.reroll_button)): return false
	if not _require(not sim.shop.can_undo(), "reroll clears sale undo history"): return false
	if not (await _activate(ui.build_panel._sell_buttons[0])): return false
	if not (await _activate(ui.start_button)): return false
	if not _require(sim.phase == Sim.Phase.WAVE and not sim.shop.can_undo(),
			"wave start clears sale undo history"): return false
	_summary["checks"]["history"] = true
	return true


func _cleanup_case() -> bool:
	_main.show_select()
	await _wait_frames(3)
	if not _require(_main.character_select.visible and _main.sim == null
			and not _main.shop_ui.visible and _main.shop_ui.sim == null,
			"probe returns to title and releases shop session"): return false
	_main.audio.stop_all()
	_summary["checks"]["cleanup"] = true
	return true


func _stage_equipment_and_offers() -> void:
	_set_equipment([&"pistol", &"pistol", &"smg"], [0, 2, 0])
	_stage_offers([_weapon(&"shotgun", 11), _weapon(&"rifle", 22),
		_weapon(&"orb", 33), _item(&"sharp_edge", 9)], 300)


func _set_equipment(ids: Array[StringName], levels: Array[int]) -> void:
	var sim: Sim = _main.sim
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for i in ids.size():
		sim.player.add_weapon(Content.weapon(ids[i]))
		sim.player.weapon_levels[i] = levels[i]
		sim.player.cooldowns[i] = 0.1 * float(i + 1)


func _stage_offers(offers: Array[Offer], materials: int) -> void:
	var sim: Sim = _main.sim
	sim.phase = Sim.Phase.SHOP
	sim.wave = 5
	sim.player.materials = materials
	sim.shop.offers.clear()
	for offer: Offer in offers: sim.shop.offers.append(offer)
	sim.shop.clear_history()
	_main._phase = Sim.Phase.SHOP
	_main.paused = true
	_main.hud.visible = false
	_main._view.visible = false
	_main.shop_ui.open(sim)
	_main.shop_ui.set_reduced_effects(_reduced)


func _weapon(id: StringName, price: int) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(id)
	offer.price = price
	return offer


func _item(id: StringName, price: int) -> Offer:
	var offer := Offer.new()
	offer.item = Content.item(id)
	offer.price = price
	return offer


func _card(index: int) -> OfferCard:
	return _main.shop_ui.offers_box.get_child(index) as OfferCard


func _snapshot() -> Dictionary:
	var data := ShopState.capture(_main.sim).to_dict()
	data["cooldowns"] = _main.sim.player.cooldowns.duplicate()
	return data


func _assert_geometry() -> bool:
	var viewport := root.get_visible_rect()
	var ui: ShopUi = _main.shop_ui
	for surface: Control in [ui, ui.build_panel, ui.echo_panel, ui.reroll_button,
		ui.undo_button, ui.start_button]:
		if not _require(viewport.encloses(surface.get_global_rect()),
				"full shop surface remains inside viewport"): return false
	for i in 4:
		var card := _card(i)
		for button: Button in [card.lock_button, card.swap_button]:
			if button != null and not _require(card.get_global_rect().encloses(button.get_global_rect())
					and viewport.encloses(button.get_global_rect()),
					"nested lock/replace action fits its card and viewport"): return false
		for label: Node in card.find_children("*", "Label", true, false):
			var text := label as Label
			if text != null and not text.clip_text and text.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var size := text.get_theme_font("font").get_string_size(text.text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, text.get_theme_font_size("font_size"))
				if not _require(size.x <= text.get_global_rect().size.x + 1.0,
						"offer text fits its assigned bounds"): return false
	return true


func _mouse_click(button: Button) -> bool:
	var pos := button.get_global_rect().get_center()
	_push_motion(pos, Vector2.ZERO, 0)
	_push_button(pos, true)
	await process_frame
	_push_button(pos, false)
	await _wait_frames(SETTLE_FRAMES)
	return not _failed


func _activate(button: Button) -> bool:
	if not _require(button != null and button.is_visible_in_tree() and not button.disabled,
			"focused action is available"): return false
	button.grab_focus()
	await _wait_frames(2)
	if not _require(button.has_focus(), "focused action owns focus"): return false
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


func _push_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event, false)


func _push_motion(position: Vector2, relative: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, false)


func _capture(state: String) -> bool:
	_summary["diagnostics"][state] = _diag()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty(), "%s frame readback exists" % state): return false
	var mode := "reduced" if _reduced else "normal"
	var filename := "lock_%s_%s_%s.png" % [Loc.lang, mode, state]
	if not _require(image.save_png(_shots_dir.path_join(filename)) == OK, "screenshot saves"): return false
	(_summary["screenshots"] as Dictionary)[state] = filename
	return true


func _diag() -> Dictionary:
	return {"frame": _frames, "ticks_msec": Time.get_ticks_msec(),
		"phase": int(_main.sim.phase) if _main != null and _main.sim != null else -1,
		"shop_visible": _main.shop_ui.visible if _main != null and _main.shop_ui != null else false,
		"focus": root.gui_get_focus_owner().get_class() if root.gui_get_focus_owner() != null else "none"}


func _write_summary() -> bool:
	var mode := "reduced" if _reduced else "normal"
	var file := FileAccess.open(_shots_dir.path_join("lock_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
	if file == null: _fail("summary open failed"); return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n"); file.close(); return true


func _wait_frames(count: int) -> void:
	for _i in count: await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition: return true
	_fail(message); return false


func _fail(message: String) -> void:
	if _failed: return
	_failed = true; _summary["failure"] = message
	printerr("offer lock probe FAILED: %s" % message)
	if _shots_dir != "":
		var mode := "reduced" if _reduced else "normal"
		var file := FileAccess.open(_shots_dir.path_join(
				"lock_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n"); file.close()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["offer_lock_probe_save.json", "offer_lock_probe_runs.jsonl",
		"offer_lock_probe_feedback.jsonl", "offer_lock_probe_settings.json"]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
