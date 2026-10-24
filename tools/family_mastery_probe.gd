extends SceneTree
# Deterministic actual-window fixture for the four-piece family mastery UI.
# Run the EN/ZH and normal/reduced matrix with isolated local state:
# REVERB_LANG=en REVERB_REDUCED_EFFECTS=0 godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/family_mastery_probe.gd

const DEADLINE_FRAMES := 1200
const SETTLE_FRAMES := 6
const FAMILY_CASES := [
	{"family": &"sidearm", "equipped": &"pistol", "offer": &"smg",
		"mastery": "shop.family_mastery_sidearm"},
	{"family": &"scatter", "equipped": &"shotgun", "offer": &"flechette",
		"mastery": "shop.family_mastery_scatter"},
	{"family": &"marksman", "equipped": &"rifle", "offer": &"longbow",
		"mastery": "shop.family_mastery_marksman"},
	{"family": &"arcane", "equipped": &"orb", "offer": &"orb",
		"mastery": "shop.family_mastery_arcane"},
]

var _ui: ShopUi
var _sim: Sim
var _frames := 0
var _failed := false
var _wrote_summary := false
var _shots_dir := ""
var _reduced := false
var _summary: Dictionary = {
	"source": "fixture", "cases": [], "screenshots": {}, "shop_geometry": {},
}


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://family_mastery_probe_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://family_mastery_probe_runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://family_mastery_probe_feedback.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://family_mastery_probe_settings.json")
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	_clear_fixture_files()
	Loc.reset_lang()
	_reduced = OS.get_environment("REVERB_REDUCED_EFFECTS") == "1"
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_ui = ShopUi.new()
	_ui.theme = UiTheme.build()
	root.add_child(_ui)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before all family cases completed")
	return false


func _run() -> void:
	await _wait_frames(2)
	_ui.set_reduced_effects(_reduced)
	for case: Dictionary in FAMILY_CASES:
		if not (await _run_family(case)):
			return
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["fixture"] = {
		"character": "looper",
		"transition": "three family weapons -> focused ShopUi purchase -> four -> focused undo -> three",
		"run_source": OS.get_environment("REVERB_RUN_SOURCE"),
	}
	_summary["environment"] = {
		"godot": Engine.get_version_info(),
		"display": DisplayServer.get_name(),
		"viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
	}
	if not _write_summary():
		return
	print("family mastery probe: %s" % JSON.stringify({"language": Loc.lang,
		"reduced_effects": _reduced, "families": FAMILY_CASES.size()}))
	print("family mastery probe: OK")
	quit()


func _run_family(case: Dictionary) -> bool:
	var family: StringName = case["family"]
	var equipped: StringName = case["equipped"]
	var offered: StringName = case["offer"]
	var mastery_text := Loc.t(str(case["mastery"]))
	_stage(family, equipped, offered)
	_ui.open(_sim)
	await _wait_frames(SETTLE_FRAMES)
	if not _require(_ui.reduced_effects == _reduced,
			"%s ShopUi applies the requested effects mode" % family):
		return false
	if not _require(_sim.player.weapons.size() == 3, "%s fixture starts at three pieces" % family):
		return false
	if not _require(_find_label(mastery_text) == null,
			"%s mastery is absent at three pieces" % family):
		return false
	if not _require(_ui.offers_box.get_child_count() == 1,
			"%s fixture exposes one deterministic offer" % family):
		return false
	var expected_dps := OfferCard.dps_with_added(_sim.player, Content.weapon(offered))
	var offer_card := _ui.offers_box.get_child(0) as OfferCard
	if not (await _activate(offer_card)):
		return false
	if not _require(_sim.player.weapons.size() == 4,
			"%s focused purchase reaches four pieces" % family):
		return false
	if not _require(Combat.family_count(_sim.player.weapons, family) == 4,
			"%s purchase completes the intended family" % family):
		return false
	var active_label := _find_label(mastery_text)
	if not _require(active_label != null, "%s active mastery label appears" % family):
		return false
	var actual_dps := OfferCard.total_dps(_sim.player)
	if not _require(is_equal_approx(actual_dps, expected_dps),
			"%s mastery preserves the mechanics-owned base DPS treatment" % family):
		return false
	if not _check_mechanic(family, true):
		return false
	if _reduced and not _require(_ui._overlay.get_child_count() == 0,
			"%s reduced-effects purchase leaves no animation overlay" % family):
		return false
	if not _assert_shop_geometry(family):
		return false
	var echo_value := Loc.t("shop.echo_value", [3, int(round(_sim.echo_power() * 100.0))])
	var core_title := _find_label(Loc.t("shop.core"), true)
	var echo_label := _find_label(echo_value, true)
	if not _require(core_title != null and echo_label != null,
			"%s four-piece build exposes core and effective echo power" % family):
		return false
	if family == &"arcane" and not _require(is_equal_approx(_sim.echo_power(), 0.48),
			"four arcane pieces show Looper's effective 48% echo power"):
		return false
	var scroll := _ui.build_panel.get_child(0) as ScrollContainer
	scroll.ensure_control_visible(active_label)
	await _wait_frames(SETTLE_FRAMES)
	var mastery_geometry := _collect_geometry([active_label], family)
	if mastery_geometry.is_empty():
		return false
	if not (await _capture("%s_mastery" % family)):
		return false
	scroll.ensure_control_visible(echo_label)
	await _wait_frames(SETTLE_FRAMES)
	var core_geometry := _collect_geometry([core_title, echo_label], family)
	if core_geometry.is_empty():
		return false
	if not (await _capture("%s_core" % family)):
		return false
	var row := {
		"family": String(family),
		"weapon_count_at_mastery": 4,
		"mastery_text": mastery_text,
		"echo_power_percent": int(round(_sim.echo_power() * 100.0)),
		"base_dps": actual_dps,
		"geometry": {"mastery": mastery_geometry, "core": core_geometry},
	}
	if not (await _activate(_ui.undo_button)):
		return false
	if not _require(_sim.player.weapons.size() == 3
			and Combat.family_count(_sim.player.weapons, family) == 3,
			"%s focused undo returns to three pieces" % family):
		return false
	if not _require(_find_label(mastery_text) == null,
			"%s mastery label disappears after undo" % family):
		return false
	if not _check_mechanic(family, false):
		return false
	if family == &"arcane" and not _require(is_equal_approx(_sim.echo_power(), 0.4),
			"arcane undo restores Looper's 40% base echo power"):
		return false
	row["undo_weapon_count"] = _sim.player.weapons.size()
	row["undo_echo_power_percent"] = int(round(_sim.echo_power() * 100.0))
	(_summary["cases"] as Array).append(row)
	_ui.close_session()
	await _wait_frames(2)
	return true


func _stage(family: StringName, equipped: StringName, offered: StringName) -> void:
	_sim = Sim.new(78145876)
	Content.character(&"looper").apply(_sim)
	_sim.phase = Sim.Phase.SHOP
	_sim.wave = 5
	_sim.player.weapons.clear()
	_sim.player.weapon_levels.clear()
	_sim.player.cooldowns.clear()
	for _i in 3:
		_sim.player.add_weapon(Content.weapon(equipped))
	_sim.player.materials = 1000
	_sim.shop.offers.clear()
	var offer := Offer.new()
	offer.weapon = Content.weapon(offered)
	offer.price = 1
	_sim.shop.offers.append(offer)
	_sim.shop.clear_history()


func _check_mechanic(family: StringName, active: bool) -> bool:
	match family:
		&"sidearm":
			return _require(is_equal_approx(Combat.family_cooldown_mult(
					_sim.player.weapons, family), 0.94 if active else 1.0),
					"sidearm mastery mechanics match its visible state")
		&"scatter":
			return _require(is_equal_approx(Combat.family_mastery_damage(
					_sim.player.weapons, family, 100.0), 1.15 if active else 1.0),
					"scatter mastery mechanics match its visible state")
		&"marksman":
			return _require(Combat.family_mastery_pierce(_sim.player.weapons, family)
					== (1 if active else 0),
					"marksman mastery mechanics match its visible state")
		&"arcane":
			return _require(is_equal_approx(_sim.echo_power(), 0.48 if active else 0.4),
					"arcane mastery mechanics match its visible state")
	return _require(false, "unknown family fixture")


func _find_label(text: String, exact: bool = false) -> Label:
	for node: Node in _ui.build_panel.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and ((label.text == text) if exact else label.text.contains(text)):
			return label
	return null


func _collect_geometry(labels: Array, family: StringName) -> Dictionary:
	var viewport := root.get_visible_rect()
	var rows: Array[Dictionary] = []
	for value: Variant in labels:
		var label := value as Label
		if not _require(label != null and label.is_visible_in_tree(),
				"%s checked label is visible" % family):
			return {}
		var raw := label.get_global_rect()
		var clipped := _clipped_rect(label)
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var wrapped := label.autowrap_mode != TextServer.AUTOWRAP_OFF
		var text_size := font.get_multiline_string_size(label.text,
				label.horizontal_alignment, raw.size.x if wrapped else -1.0, font_size)
		if not _require(clipped.has_area() and viewport.encloses(clipped),
				"%s label remains inside the actual viewport" % family):
			return {}
		var horizontally_complete := absf(raw.position.x - clipped.position.x) <= 0.5 \
				and absf(raw.size.x - clipped.size.x) <= 0.5
		if not _require(horizontally_complete,
				"%s label control is fully visible across the BuildPanel viewport" % family):
			return {}
		if wrapped:
			if not _require(label.get_visible_line_count() == label.get_line_count()
					and text_size.y <= raw.size.y + 1.0,
					"%s wrapped label renders every line at full height" % family):
				return {}
		elif not _require(text_size.x <= clipped.size.x + 1.0,
				"%s single-line label text fits the BuildPanel viewport" % family):
			return {}
		rows.append({"text": label.text, "rect": _rect(raw), "clipped": _rect(clipped),
			"text_size": [text_size.x, text_size.y], "wrapped": wrapped,
			"line_count": label.get_line_count(),
			"visible_line_count": label.get_visible_line_count()})
	return {"viewport": _rect(viewport), "labels": rows}


func _assert_shop_geometry(family: StringName) -> bool:
	var viewport := root.get_visible_rect()
	var surfaces: Array[Control] = [
		_ui,
		_ui.build_panel,
		_ui.echo_panel,
		_ui._title,
		_ui._materials,
		_ui._interest,
		_ui.reroll_button,
		_ui.undo_button,
		_ui.start_button,
	]
	var measured: Array[Dictionary] = []
	for control: Control in surfaces:
		if not _require(control != null and control.is_visible_in_tree(),
				"%s required ShopUi surface is visible" % family):
			return false
		var rect := control.get_global_rect()
		if not _require(rect.has_area() and viewport.encloses(rect),
				"%s %s remains fully inside the actual viewport" % [family, control.get_class()]):
			return false
		measured.append({"type": control.get_class(), "rect": _rect(rect)})
	(_summary["shop_geometry"] as Dictionary)[String(family)] = {"surfaces": measured}
	return true


func _clipped_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			if parent.clip_contents or parent is ScrollContainer:
				rect = rect.intersection(parent.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _activate(button: Button) -> bool:
	if not _require(button != null and button.is_visible_in_tree() and not button.disabled,
			"focused ShopUi action is available"):
		return false
	button.grab_focus()
	await _wait_frames(2)
	if not _require(button.has_focus(), "focused ShopUi action owns keyboard focus"):
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
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty(), "%s screenshot readback exists" % state):
		return false
	var mode := "reduced" if _reduced else "normal"
	var filename := "family_%s_%s_%s.png" % [Loc.lang, mode, state]
	var path := _shots_dir.path_join(filename)
	if not _require(image.save_png(path) == OK, "%s screenshot saves" % state):
		return false
	(_summary["screenshots"] as Dictionary)[state] = {
		"path": path, "width": image.get_width(), "height": image.get_height()}
	print("wrote shots/%s" % filename)
	return true


func _write_summary() -> bool:
	var mode := "reduced" if _reduced else "normal"
	var filename := "family_%s_%s_summary.json" % [Loc.lang, mode]
	var file := FileAccess.open(_shots_dir.path_join(filename), FileAccess.WRITE)
	if file == null:
		_fail("failed to open %s" % filename)
		return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	_wrote_summary = true
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
	_summary["failure"] = message
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	printerr("family mastery probe FAILED: %s" % message)
	if not _wrote_summary and _shots_dir != "":
		var mode := "reduced" if _reduced else "normal"
		var file := FileAccess.open(_shots_dir.path_join(
				"family_%s_%s_summary.json" % [Loc.lang, mode]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_summary, "  ") + "\n")
			file.close()
	quit(1)


func _clear_fixture_files() -> void:
	for name in [
		"family_mastery_probe_save.json",
		"family_mastery_probe_runs.jsonl",
		"family_mastery_probe_feedback.jsonl",
		"family_mastery_probe_settings.json",
	]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
