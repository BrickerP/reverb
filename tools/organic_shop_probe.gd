extends SceneTree
# Windowed fixture through the real ShopUi controls and committed Shop transactions.
# Prices/stock/starting materials are deterministic fixtures, not balance evidence.
# godot --path . --fixed-fps 60 --disable-vsync --write-movie res://shots/organic_shop.avi \
#   --script res://tools/organic_shop_probe.gd

const HOLD_FRAMES := 72
const FEEDBACK_FRAME := 5
const DEADLINE_MSEC := 90000
const FRAME_LIMIT := 1200

var _ui: ShopUi
var _sim: Sim
var _states: Dictionary = {}
var _dir := ""
var _started_msec := 0
var _frames := 0
var _failed := false


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_organic_shop_probe_suspend.json")
	_started_msec = Time.get_ticks_msec()
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	OS.set_environment("REVERB_SAVE", "user://organic_shop_fixture_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://organic_shop_fixture_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://organic_shop_fixture_settings.json")
	OS.set_environment("REVERB_FEEDBACK_LOG", "user://organic_shop_fixture_feedback.jsonl")
	if DisplayServer.get_name() == "headless":
		_fail("organic_shop_probe requires a real rendering window")
		return
	_dir = ProjectSettings.globalize_path("res://shots/organic_shop/" + Loc.lang)
	if DirAccess.make_dir_recursive_absolute(_dir) != OK:
		_fail("cannot create output folder")
		return
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if not _failed and (_frames > FRAME_LIMIT or Time.get_ticks_msec() - _started_msec > DEADLINE_MSEC):
		_fail("shop feedback fixture exceeded deadline (%d frames, %d ms)" % [
				_frames, Time.get_ticks_msec() - _started_msec])
	return false


func _run() -> void:
	_sim = Sim.new(283)
	_sim.start_run()
	_sim.phase = Sim.Phase.SHOP
	_sim.wave = 3
	_sim.player.materials = 100
	_sim.shop.offers.clear()
	for id: StringName in [&"pistol", &"shotgun"]:
		var offer := Offer.new()
		offer.weapon = Content.weapon(id)
		offer.price = 12 if id == &"pistol" else 20
		_sim.shop.offers.append(offer)
	for id: StringName in [&"long_play", &"lucky_coin"]:
		var offer := Offer.new()
		offer.item = Content.item(id)
		offer.price = 10 if id == &"long_play" else 7
		_sim.shop.offers.append(offer)
	for i in 2:
		var take := EchoTake.new()
		take.wave = i + 1
		take.weapons.append(Content.weapon(&"pistol"))
		take.samples = PackedVector2Array([Vector2(200.0, 200.0), Vector2(500.0, 400.0)])
		_sim.bank.add(take)
	_ui = ShopUi.new()
	_ui.theme = UiTheme.build()
	root.add_child(_ui)
	_ui.open(_sim)
	await _wait(HOLD_FRAMES)
	if not await _capture("idle", _snapshot()):
		return
	var before := _snapshot()
	(_ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	if not await _record_action("bought", before):
		return
	before = _snapshot()
	_ui.undo_button.pressed.emit()
	if not await _record_action("undo", before):
		return
	before = _snapshot()
	_ui.reroll_button.pressed.emit()
	if not await _record_action("reroll", before):
		return
	# Deliberately empty the fixture wallet to exercise the real failed-quote route.
	_sim.player.materials = 0
	_ui.refresh()
	before = _snapshot()
	(_ui.offers_box.get_child(0) as OfferCard).pressed.emit()
	if not await _record_action("poor", before):
		return
	before = _snapshot()
	_ui.echo_panel.merge_button.pressed.emit()
	_ui.echo_panel.discard_buttons[0].pressed.emit()
	_ui.echo_panel.discard_buttons[1].pressed.emit()
	if not await _record_action("merged", before):
		return
	before = _snapshot()
	_ui.set_reduced_effects(true)
	if not await _record_action("reduced", before):
		return
	var out := FileAccess.open(_dir.path_join("summary.json"), FileAccess.WRITE)
	if out == null:
		_fail("cannot save feedback summary")
		return
	out.store_string(JSON.stringify({"source": "fixture", "language": Loc.lang,
			"physical_controller_tested": false, "states": _states}, "  "))
	out.close()
	_ui.close_session()
	_ui.queue_free()
	print("organic shop feedback probe: OK (%s)" % Loc.lang)
	quit()


func _record_action(state: String, before: Dictionary) -> bool:
	await _wait(FEEDBACK_FRAME)
	if not await _capture(state, before):
		return false
	await _wait(HOLD_FRAMES - FEEDBACK_FRAME)
	return not _failed


func _wait(count: int) -> void:
	for _i in count:
		await process_frame


func _snapshot() -> Dictionary:
	return {
		"reaction": String(_ui.last_vendor_reaction), "reactions": _ui.vendor_feedback_runs,
		"materials": _sim.player.materials, "copies": _sim.bank.takes.size(),
		"weapons": _sim.player.weapons.size(), "pose": _pose(),
		"joke": _ui._vendor_line.text, "task": _ui._warning.text,
		"rule": _ui._footer.text, "reduced": _ui.reduced_effects,
		"receipt_visible": is_instance_valid(_ui._vendor_receipt),
	}


func _pose() -> int:
	var texture := _ui._vendor_art.texture as AtlasTexture
	if texture == null:
		return -1
	for index in PresentationAssets.frame_count(&"shopkeeper"):
		if texture.region == PresentationAssets.frame_region(&"shopkeeper", index):
			return index
	return -1


func _capture(state: String, before: Dictionary) -> bool:
	if not _validate_state(state, before):
		return false
	# A background/occluded macOS window may stop emitting frame_post_draw. Force
	# the current real viewport to render instead of waiting on window visibility.
	RenderingServer.force_draw()
	var result := root.get_texture().get_image().save_png(_dir.path_join(state + ".png"))
	if result != OK:
		_fail("cannot capture %s" % state)
		return false
	_states[state] = {"before": before, "after": _snapshot()}
	return not _failed


func _validate_state(state: String, before: Dictionary) -> bool:
	var after := _snapshot()
	var ok := true
	match state:
		"idle":
			ok = _ui.last_vendor_reaction == &"idle" and _pose() == 0
		"bought":
			ok = (int(after["materials"]) == int(before["materials"]) - 12
					and int(after["weapons"]) == int(before["weapons"]) + 1
					and _ui.last_vendor_reaction == &"buy" and _pose() == 3)
		"undo":
			ok = (int(after["materials"]) == int(before["materials"]) + 12
					and int(after["weapons"]) == int(before["weapons"]) - 1
					and _ui.last_vendor_reaction == &"undo")
		"reroll":
			ok = (int(after["materials"]) < int(before["materials"])
					and _sim.shop.offers.size() == Shop.OFFER_COUNT
					and not _sim.shop.can_undo() and _ui.last_vendor_reaction == &"reroll")
		"poor":
			ok = (after["materials"] == before["materials"]
					and after["weapons"] == before["weapons"] and after["copies"] == before["copies"]
					and _ui.last_vendor_reaction == &"poor" and _pose() == 2
					and _ui._footer.text == Loc.t("shop.drop_poor"))
		"merged":
			ok = (int(after["copies"]) == int(before["copies"]) - 1
					and after["materials"] == before["materials"] and _ui.last_vendor_reaction == &"merge")
		"reduced":
			ok = (after["copies"] == before["copies"] and after["weapons"] == before["weapons"]
					and after["materials"] == before["materials"] and _ui.reduced_effects
					and not bool(after["receipt_visible"]) and _pose() == 0)
	if not ok:
		_fail("%s does not match the committed action: %s" % [state, JSON.stringify(after)])
	return ok


func _fail(reason: String) -> void:
	_failed = true
	printerr("FAILED: %s" % reason)
	quit(1)
