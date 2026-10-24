extends SceneTree
# Actual-window EN/ZH UI state, focus and geometry regression.
# Run once per language with isolated user data:
# REVERB_LANG=en|zh godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/ui_state_probe.gd

const DEADLINE_FRAMES := 2400

var _main: Node
var _frames := 0
var _failed := false
var _shots_dir := ""
var _summary: Dictionary = {"states": {}, "geometry": {}, "screenshots": {}}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://ui_state_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://ui_state_probe_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://ui_state_probe_settings.json")
	_clear_fixture_files()
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before UI state matrix completed")
	return false


func _run() -> void:
	if not (await _wait_for_select()):
		return
	_summary["language"] = Loc.lang
	_summary["logical_viewport"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	_summary["window_size"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	if not (await _select_and_modal_states()):
		return
	if not (await _pause_states()):
		return
	if not (await _shop_echo_states()):
		return
	if not (await _end_states()):
		return
	_write_summary()
	_main.audio.stop_all()
	await _wait_frames(8)
	print("ui state probe: %s" % JSON.stringify({"language": Loc.lang,
		"states": (_summary["states"] as Dictionary).size()}))
	print("ui state probe: OK")
	quit()


func _select_and_modal_states() -> bool:
	var select: CharacterSelectUi = _main.character_select
	if not _require(select._cards.size() == 4, "character selection contains four cards"):
		return false
	var enabled: int = 0
	for card: Button in select._cards:
		if not card.disabled:
			enabled += 1
	if not _require(enabled == 1 and _any_card_focused(select),
			"fresh profile shows one unlocked character with default focus"):
		return false
	if not (await _capture("select_locked", select)):
		return false

	for id: StringName in _main.meta.unlocked:
		_main.meta.unlocked[id] = true
	select.refresh(_main.meta, _main.today_seed(), 0)
	await _wait_frames(3)
	enabled = 0
	for card: Button in select._cards:
		if not card.disabled:
			enabled += 1
	select.focus_default()
	if not _require(enabled == 4 and _any_card_focused(select),
			"unlocked profile shows four usable character cards"):
		return false
	if not (await _capture("select_unlocked", select)):
		return false

	var codex_opener: Button = _find_button(select, Loc.t("select.codex"))
	if not (await _activate(codex_opener)):
		return false
	if not _require(_main.codex_ui.visible and _main.codex_ui.close_button.has_focus()
			and _main.codex_ui.card_count() == Content.weapons().size(),
			"codex opens with close focus and every weapon"):
		return false
	if not (await _assert_focus_cycle(_main.codex_ui, 1, _main.codex_ui.close_button,
			_main.codex_ui.close_button, _main.codex_ui.close_button, true, "codex")):
		return false
	if not (await _capture("codex", _main.codex_ui)):
		return false
	if not (await _cancel()):
		return false
	if not _require(not _main.codex_ui.visible and select.visible and _any_card_focused(select),
			"closing codex restores character-selection focus"):
		return false

	var settings_opener: Button = _find_button(select, Loc.t("select.settings"))
	if not (await _activate(settings_opener)):
		return false
	var settings_ui: SettingsUi = _main.settings_ui
	if not _require(settings_ui.visible and settings_ui.volume_slider.has_focus()
			and not settings_ui.language_option.disabled
			and not settings_ui.language_lock_hint.visible,
			"title settings opens focused with language enabled"):
		return false
	if not (await _assert_focus_cycle(settings_ui, 6, settings_ui.volume_slider,
			settings_ui.volume_slider, settings_ui.close_button, false, "settings_enabled")):
		return false
	if not (await _activate(settings_ui.reduced_effects_check)):
		return false
	if not _require(_main.settings.reduced_effects
			and settings_ui.reduced_effects_check.button_pressed
			and _main._view.reduced_effects and _main.shop_ui.reduced_effects
			and _main.end_ui.reduced_effects,
			"reduced-effects setting propagates to presentation surfaces"):
		return false
	var reloaded: Settings = Settings.new(_main.settings.path)
	if not _require(reloaded.reduced_effects, "reduced-effects setting persists to isolated settings"):
		return false
	if not (await _capture("settings", settings_ui)):
		return false
	if not (await _cancel()):
		return false
	if not _require(not settings_ui.visible and _any_card_focused(select),
			"closing title settings restores character-selection focus"):
		return false

	var history_opener: Button = _find_button(select, Loc.t("select.history"))
	if not (await _activate(history_opener)):
		return false
	if not _require(_main.history_ui.visible and _main.history_ui.row_count() == 0
			and _main.history_ui._empty.visible and _main.history_ui.close_button.has_focus(),
			"empty history opens with a focused close action"):
		return false
	if not (await _assert_focus_cycle(_main.history_ui, 1, _main.history_ui.close_button,
			_main.history_ui.close_button, _main.history_ui.close_button, true, "history_empty")):
		return false
	if not (await _capture("history_empty", _main.history_ui)):
		return false
	if not (await _cancel()):
		return false
	_seed_history(10)
	if not (await _activate(history_opener)):
		return false
	if not _require(_main.history_ui.row_count() == 8
			and _main.history_ui.replay_buttons.size() == 8
			and _main.history_ui.replay_buttons[0].has_focus(),
			"history caps at eight rows and focuses the first replay"):
		return false
	if not (await _assert_focus_cycle(_main.history_ui, 9, _main.history_ui.replay_buttons[0],
			_main.history_ui.replay_buttons[0], _main.history_ui.close_button, true, "history_full")):
		return false
	if not (await _capture("history_full", _main.history_ui)):
		return false
	if not (await _cancel()):
		return false
	if not _require(_any_card_focused(select), "closing history restores title focus"):
		return false
	_summary["states"]["select_modals"] = true
	return true


func _pause_states() -> bool:
	var looper_card: Button = _character_card(&"looper")
	if not (await _activate(looper_card)):
		return false
	if not _require(_main.sim != null and _main.sim.phase == Sim.Phase.WAVE,
			"focused character starts a real run"):
		return false
	if not (await _action(&"pause")):
		return false
	var pause: PauseUi = _main.pause_ui
	if not _require(_main.paused and pause.visible and pause.resume_button.has_focus(),
			"pause opens with resume focused"):
		return false
	if not (await _assert_focus_cycle(pause, 5, pause.resume_button,
			pause.resume_button, pause.quit_button, true, "pause")):
		return false
	if not (await _capture("pause", pause)):
		return false

	var muted_before: bool = _main.audio.is_muted()
	if not (await _activate(pause.mute_button)):
		return false
	if not _require(_main.audio.is_muted() != muted_before
			and pause.mute_button.accessibility_name == pause.mute_button.text,
			"pause mute action updates audio and accessible label"):
		return false
	if not (await _activate(pause.mute_button)):
		return false
	if not _require(_main.audio.is_muted() == muted_before, "second mute action restores audio state"):
		return false

	if not (await _activate(pause.settings_button)):
		return false
	if not _require(_main.settings_ui.visible and not pause.visible
			and _main.settings_ui.language_option.disabled
			and _main.settings_ui.language_lock_hint.visible,
			"in-run settings guards language changes"):
		return false
	if not (await _assert_focus_cycle(_main.settings_ui, 5, _main.settings_ui.volume_slider,
			_main.settings_ui.volume_slider, _main.settings_ui.close_button, false,
			"settings_language_locked")):
		return false
	if not (await _cancel()):
		return false
	if not _require(pause.visible and pause.resume_button.has_focus(),
			"closing paused settings restores pause focus"):
		return false

	if not (await _activate(pause.history_button)):
		return false
	if not _require(_main.history_ui.visible and not pause.visible
			and _main.history_ui.replay_buttons[0].has_focus(),
			"pause history opens with replay focus"):
		return false
	if not (await _assert_focus_cycle(_main.history_ui, 9, _main.history_ui.replay_buttons[0],
			_main.history_ui.replay_buttons[0], _main.history_ui.close_button, true,
			"history_from_pause")):
		return false
	if not (await _cancel()):
		return false
	if not _require(pause.visible and pause.resume_button.has_focus(),
			"closing paused history restores pause focus"):
		return false
	if not (await _activate(pause.resume_button)):
		return false
	if not _require(not _main.paused and not pause.visible, "focused resume returns to play"):
		return false
	_summary["states"]["pause_nested_modals"] = true
	return true


func _shop_echo_states() -> bool:
	var sim: Sim = _main.sim
	_main.paused = true
	sim.phase = Sim.Phase.SHOP
	sim.bank.takes.clear()
	for i in 3:
		sim.bank.add(_take(i + 1, &"pistol" if i < 2 else &"rifle", float(i)))
	sim.shop.offers.clear()
	var staged_offer: Offer = Offer.new()
	staged_offer.item = Content.item(&"sharp_edge")
	staged_offer.price = 16
	sim.shop.offers.append(staged_offer)
	# Open once with normal effects so the delayed arrival token is scheduled,
	# then enable reduced effects before its two-frame continuation resumes.
	_main.shop_ui.set_reduced_effects(false)
	_main.end_ui.set_reduced_effects(true)
	_main._open_shop()
	_main.shop_ui.set_reduced_effects(true)
	await _wait_frames(6)
	var shop: ShopUi = _main.shop_ui
	var echo: EchoPanel = shop.echo_panel
	if not _require(shop.visible and shop.reduced_effects and echo.reduced_effects,
			"reduced-effects shop and echo panel open"):
		return false
	var shop_viewport: Rect2 = root.get_visible_rect()
	if not _require(shop_viewport.encloses(shop.build_panel.get_global_rect()),
			"shop BuildPanel is fully inside the logical viewport"):
		return false
	if not _require(shop_viewport.encloses(echo.get_global_rect()),
			"shop EchoPanel is fully inside the logical viewport"):
		return false
	if echo.merge_button != null and not _require(
			shop_viewport.encloses(echo.merge_button.get_global_rect()),
			"echo merge button is fully visible"):
		return false
	for button: Button in echo.discard_buttons:
		if not _require(shop_viewport.encloses(button.get_global_rect()),
				"every echo discard/select button is fully visible"):
			return false
	if not _require(shop._overlay.get_child_count() == 0,
			"reduced effects suppresses the flying take token"):
		return false
	var animated_previews: int = 0
	for node: Node in echo.find_children("*", "PathPreview", true, false):
		if (node as PathPreview).is_animating():
			animated_previews += 1
		if not _require(not (node as PathPreview).is_animating(),
				"reduced effects suppresses echo route tracing"):
			return false
	var scaled_targets: int = 0
	for target: ShopDropTarget in shop.build_panel.slot_drop_targets:
		if target.scale != Vector2.ONE:
			scaled_targets += 1
		if not _require(target.scale == Vector2.ONE,
				"reduced effects leaves equipment targets at rest scale"):
			return false
	var offer_card: OfferCard = shop.offers_box.get_child(0) as OfferCard
	var drag_preview_root: Control = offer_card._drag_preview()
	if not _require(drag_preview_root.get_child_count() == 1
			and drag_preview_root.get_child(0) is PanelContainer,
			"drag preview wrapper contains one offset panel"):
		drag_preview_root.free()
		return false
	var preview_panel: PanelContainer = drag_preview_root.get_child(0) as PanelContainer
	var preview_rect: Rect2 = Rect2(preview_panel.position, preview_panel.custom_minimum_size)
	if not _require(drag_preview_root.has_meta(&"shop_drag_preview")
			and drag_preview_root.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and preview_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and not preview_rect.has_point(Vector2.ZERO) and preview_rect.end.y < 0.0,
			"drag preview child panel stays above the pointer and cannot block its target"):
		drag_preview_root.free()
		return false
	drag_preview_root.free()

	if not _require(echo.merge_button != null and not echo.merge_button.disabled,
			"three takes expose merge action"):
		return false
	if not (await _activate(echo.merge_button)):
		return false
	if not _require(echo.is_merging() and echo.discard_buttons[0].has_focus(),
			"merge mode starts with first take focused"):
		return false
	if not (await _cancel()):
		return false
	if not _require(not echo.is_merging() and echo.merge_button.has_focus(),
			"shop cancel exits merge mode and restores merge focus"):
		return false
	if not (await _activate(echo.merge_button)):
		return false
	if not (await _activate(echo.discard_buttons[0])):
		return false
	if not _require(echo.is_merging() and echo._merge_first != null,
			"first take selection keeps merge mode active"):
		return false
	if not (await _activate(echo.discard_buttons[1])):
		return false
	var merged: int = 0
	for take: EchoTake in sim.bank.takes:
		if take.merged:
			merged += 1
	if not _require(sim.bank.takes.size() == 2 and merged == 1 and not echo.is_merging(),
			"second take completes one real merge"):
		return false
	if not (await _capture("shop_echo_merge", shop)):
		return false
	_summary["states"]["reduced_shop_merge"] = true
	_summary["reduced_effects"] = {"take_tokens": shop._overlay.get_child_count(),
		"animated_route_previews": animated_previews, "scaled_targets": scaled_targets,
		"drag_preview_blocks_pointer": false}
	return true


func _end_states() -> bool:
	var sim: Sim = _main.sim
	_main.shop_ui.close_session()
	_main.hud.visible = false
	sim.bank.takes.clear()
	sim.phase = Sim.Phase.LOST
	sim.wave = 4
	sim.kills = 17
	sim.last_damage_source = &"bomber"
	_main.end_ui.set_feedback_available(true)
	_main.end_ui.show_result(sim)
	if not _require(_main.end_ui.visible and _main.end_ui.restart_button.has_focus()
			and _main.end_ui.best_take == null and _main.end_ui._no_echo.visible
			and not _main.end_ui._best_row.visible,
			"loss without echoes shows explicit empty state"):
		return false
	if not (await _assert_focus_cycle(_main.end_ui, 5, _main.end_ui.restart_button,
			_main.end_ui.retry_button, _main.end_ui.character_button, true, "end_loss")):
		return false
	if not (await _capture("end_loss", _main.end_ui)):
		return false

	var weak: EchoTake = _take(2, &"pistol", 0.0)
	var strong: EchoTake = _take(8, &"rifle", 1.0)
	sim.bank.add(weak)
	sim.bank.add(strong)
	sim.phase = Sim.Phase.WON
	sim.wave = WaveDirector.FINAL_WAVE
	var unlock_text: String = Loc.t("end.unlocked", [Loc.character_name(&"conductor")])
	_main.end_ui.show_result(sim, unlock_text)
	if not _require(_main.end_ui.best_take == strong and _main.end_ui._best_row.visible
			and not _main.end_ui._no_echo.visible and _main.end_ui._unlock.visible
			and _main.end_ui._unlock.text == unlock_text
			and not _main.end_ui._best_preview.is_animating()
			and _main.end_ui.restart_button.has_focus(),
			"win shows best echo, unlock and restart focus"):
		return false
	if not (await _assert_focus_cycle(_main.end_ui, 5, _main.end_ui.restart_button,
			_main.end_ui.retry_button, _main.end_ui.character_button, true, "end_win")):
		return false
	if not (await _capture("end_win", _main.end_ui)):
		return false
	_summary["states"]["end_loss_win"] = true
	return true


func _seed_history(count: int) -> void:
	for i in count:
		var sim: Sim = Sim.new(8000 + i)
		Content.character(&"looper").apply(sim)
		sim.wave = i + 1
		sim.kills = i * 3
		sim.phase = Sim.Phase.WON if i % 3 == 0 else Sim.Phase.LOST
		_main.run_log.append(sim, &"looper", 30.0 + float(i))


func _take(wave: int, weapon_id: StringName, phase: float) -> EchoTake:
	var take: EchoTake = EchoTake.new()
	take.wave = wave
	take.weapons.append(Content.weapon(weapon_id))
	take.levels.append(0)
	take.stats = _main.sim.player.stats.copy()
	var center: Vector2 = Sim.ARENA.get_center()
	for i in 80:
		var angle: float = float(i) * 0.08 + phase
		take.samples.append(center + Vector2(cos(angle) * 100.0, sin(angle) * 65.0))
	return take


func _character_card(id: StringName) -> Button:
	var index: int = 0
	for def: CharacterDef in Content.characters().values():
		if def.id == id and index < _main.character_select._cards.size():
			return _main.character_select._cards[index]
		index += 1
	return null


func _find_button(surface: Control, text: String) -> Button:
	for node: Node in surface.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text:
			return button
	return null


func _any_card_focused(select: CharacterSelectUi) -> bool:
	for card: Button in select._cards:
		if card.has_focus():
			return true
	return false


func _assert_focus_cycle(surface: Control, expected_count: int, default_control: Control,
		first_control: Control, last_control: Control, directional: bool, state: String) -> bool:
	var forward_seen: Dictionary = {}
	default_control.grab_focus()
	await _wait_frames(2)
	for _i in expected_count + 2:
		var owner: Control = root.gui_get_focus_owner()
		if not _require(owner != null and surface.is_ancestor_of(owner),
				"%s forward focus never escapes its modal" % state):
			return false
		forward_seen[owner.get_instance_id()] = true
		if not (await _action(&"ui_focus_next")):
			return false
	if not _require(forward_seen.size() == expected_count,
			"%s forward traversal covers each expected control once per cycle" % state):
		return false

	var backward_seen: Dictionary = {}
	default_control.grab_focus()
	await _wait_frames(2)
	for _i in expected_count + 2:
		var owner: Control = root.gui_get_focus_owner()
		if not _require(owner != null and surface.is_ancestor_of(owner),
				"%s backward focus never escapes its modal" % state):
			return false
		backward_seen[owner.get_instance_id()] = true
		if not (await _action(&"ui_focus_prev")):
			return false
	if not _require(backward_seen.size() == expected_count,
			"%s backward traversal covers each expected control once per cycle" % state):
		return false

	if directional:
		first_control.grab_focus()
		await _wait_frames(2)
		if not (await _action(&"ui_up")):
			return false
		if not _require(root.gui_get_focus_owner() == last_control,
				"%s up from first wraps to last" % state):
			return false
		last_control.grab_focus()
		await _wait_frames(2)
		if not (await _action(&"ui_down")):
			return false
		if not _require(root.gui_get_focus_owner() == first_control,
				"%s down from last wraps to first" % state):
			return false

	default_control.grab_focus()
	await _wait_frames(2)
	_summary["geometry"]["%s_focus_cycle" % state] = {
		"expected": expected_count, "forward": forward_seen.size(),
		"backward": backward_seen.size(), "directional": directional}
	return true


func _activate(control: Control) -> bool:
	if not _require(control != null and control.is_visible_in_tree()
			and control.focus_mode != Control.FOCUS_NONE,
			"requested UI action is visible and focusable"):
		return false
	control.grab_focus()
	await _wait_frames(2)
	if not _require(control.has_focus(), "requested UI action owns focus"):
		return false
	var activated: bool = await _action(&"ui_accept")
	return activated


func _cancel() -> bool:
	var cancelled: bool = await _action(&"ui_cancel")
	return cancelled


func _action(action: StringName) -> bool:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event, false)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event, false)
	await _wait_frames(4)
	return not _failed


func _wait_for_select() -> bool:
	for _i in 180:
		if _main.character_select != null and _main.character_select.visible:
			return true
		await process_frame
	_fail("main never reached character selection")
	return false


func _capture(name: String, surface: Control) -> bool:
	if not _assert_surface_geometry(surface, name):
		return false
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not _require(image != null and not image.is_empty(), "%s screenshot readback exists" % name):
		return false
	var content_samples: int = _content_sample_count(image)
	if not _require(content_samples >= 24, "%s screenshot is not a blank background" % name):
		return false
	var path: String = _shots_dir.path_join("ui_%s_%s.png" % [Loc.lang, name])
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("failed to save %s: %s" % [path, error])
		return false
	_summary["screenshots"][name] = {"path": path, "width": image.get_width(),
		"height": image.get_height(), "content_samples": content_samples}
	print("wrote shots/ui_%s_%s.png" % [Loc.lang, name])
	return true


func _assert_surface_geometry(surface: Control, state: String) -> bool:
	if not _require(surface != null and surface.is_visible_in_tree(), "%s surface is visible" % state):
		return false
	var viewport: Rect2 = root.get_visible_rect()
	if not _require(viewport.intersects(surface.get_global_rect()),
			"%s surface intersects the logical viewport" % state):
		return false
	var focus_owner: Control = root.gui_get_focus_owner()
	if not _require(focus_owner != null and surface.is_ancestor_of(focus_owner),
			"%s focus remains inside its modal" % state):
		return false
	var focus_rect: Rect2 = _clipped_rect(focus_owner)
	if not _require(focus_rect.has_area() and viewport.intersects(focus_rect),
			"%s focused control is visible after clipping" % state):
		return false
	var focusable_visible: int = 0
	for node: Node in surface.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		var raw_rect: Rect2 = control.get_global_rect()
		var clipped_rect: Rect2 = _clipped_rect(control)
		if clipped_rect.has_area() and not _require(viewport.encloses(clipped_rect),
				"%s fully encloses visible %s '%s' rect=%s clipped=%s" % [
					state, control.get_class(), control.name, raw_rect, clipped_rect]):
			return false
		if control is PanelContainer or control is ScrollContainer:
			var horizontal_inside: bool = (raw_rect.position.x >= viewport.position.x - 0.5
					and raw_rect.end.x <= viewport.end.x + 0.5)
			if not _require(horizontal_inside,
					"%s structural %s '%s' keeps raw horizontal bounds %s inside %s" % [
						state, control.get_class(), control.name, raw_rect, viewport]):
				return false
			if not _inside_scroll(control) and raw_rect.has_area() and not _require(
					viewport.encloses(raw_rect),
					"%s structural %s '%s' raw rect %s is fully visible" % [
						state, control.get_class(), control.name, raw_rect]):
				return false
		if control.focus_mode != Control.FOCUS_NONE and clipped_rect.has_area():
			focusable_visible += 1
	if not _require(focusable_visible > 0, "%s exposes visible focusable controls" % state):
		return false
	_summary["geometry"][state] = {"focus_owner": focus_owner.get_class(),
		"focusable_visible": focusable_visible, "viewport": [viewport.size.x, viewport.size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]}
	return true


func _clipped_rect(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent_control: Control = ancestor as Control
			if parent_control.clip_contents or parent_control is ScrollContainer:
				rect = rect.intersection(parent_control.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _inside_scroll(control: Control) -> bool:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return true
		ancestor = ancestor.get_parent()
	return false


func _content_sample_count(image: Image) -> int:
	var count: int = 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var color: Color = image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) >= 0.14:
				count += 1
	return count


func _write_summary() -> void:
	var path: String = _shots_dir.path_join("ui_%s_summary.json" % Loc.lang)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open UI summary")
		return
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	print("wrote shots/ui_%s_summary.json" % Loc.lang)


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
	printerr("ui state probe FAILED: %s" % message)
	if _main != null and _main.audio != null:
		_main.audio.stop_all()
	quit(1)


func _clear_fixture_files() -> void:
	for name in ["ui_state_probe_save.json", "ui_state_probe_runs.jsonl",
			"ui_state_probe_settings.json"]:
		var path: String = ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
