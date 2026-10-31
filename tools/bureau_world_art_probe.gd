extends SceneTree
# Disclosed clinical art fixtures. Actual switches, deliveries, confession,
# rescue and retirement rules execute; travel and encounter planning are shortened.
var _view: ArenaView
var _clip: Control
var _hud: Hud
var _sim: Sim
var _out := ""
var _results: Array[Dictionary] = []
var _failures: Array[String] = []
var _extent := Vector2i(1280, 720)


func _initialize() -> void:
	RenderingServer.render_loop_enabled = false
	Controls.register()
	_out = OS.get_environment("REVERB_WORLD_ART_OUTPUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("res://shots/bureau-world-art")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	RenderingServer.force_draw()
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("native display required")
		_finish()
		return
	for language in ["en", "zh"]:
		Loc.lang = language
		_extent = Vector2i(1280, 720) if language == "en" else Vector2i(960, 540)
		root.size = _extent
		root.content_scale_size = _extent
		DisplayServer.window_set_size(_extent)
		for _frame in 4:
			await process_frame
		_make_surfaces(language == "zh")
		_sim = _battle(2)
		_bind()
		await _capture("delivery-goal-offscreen")
		_sim.player.pos = BureauEvents.STAMP + Vector2(0, 120)
		_bind()
		await _capture("delivery-warning")
		_advance(1.15)
		await _capture("delivery-impact")
		_advance(0.7)
		await _capture("delivery-recover")
		_sim.player.pos = BureauEvents.SWITCH
		_check(_sim.interact(), "real switch works")
		_bind()
		await _capture("delivery-safe")
		_sim.player.pos = BureauEvents.PICKUP
		_check(_sim.interact(), "real pickup works")
		_bind()
		await _capture("delivery-carrying")
		_sim.player.pos = BureauEvents.INBOX
		_check(_sim.interact(), "real delivery works")
		_bind()
		await _capture("delivery-delivered")
		_sim = _battle(2)
		_sim.player.pos = BureauEvents.STAMP + Vector2(0, 120)
		_sim._end_wave()
		_bind()
		await _capture("delivery-missed")
		_sim = _battle(1)
		_sim._end_wave()
		_check(_sim.shop.apply(ShopResult.CONFESS, _sim, null, -1, &"polish").ok, "real confession applies")
		_sim.start_next_wave()
		_clear_plan()
		_sim.player.pos = BureauConfession.TERMINAL_POS
		_bind()
		await _capture("inspection-ready")
		_check(_sim.interact(), "real inspection registers")
		_bind()
		await _capture("inspection-registered")
		_sim = _battle(1)
		for item: Dictionary in _sim.interactables:
			if item["kind"] == &"rescue":
				_sim.player.pos = item["pos"]
				_check(_sim.interact(), "real rescue saves cleanup worker")
				break
		_sim.recorder.record(_sim.player.pos + Vector2(20, 0), 0.1)
		_sim._end_wave()
		_sim.start_next_wave()
		_clear_plan()
		_check(_sim.retire_selected_echo(), "real retirement leaves record")
		_sim.player.pos = _sim.expedition["world"]["workers"][0]["pos"] + Vector2(260, -20)
		_sim._end_wave()
		_bind()
		_view.play_record_beat(_sim)
		await _capture("night-cleanup-retirement")
		_view.unbind()
		_hud.unbind()
		_clip.free()
		_hud.get_parent().free()
	_finish()


func _make_surfaces(reduced: bool) -> void:
	_clip = Control.new()
	root.add_child(_clip)
	var area := WorldArena.display_viewport(Vector2(_extent))
	_clip.position = area.position
	_clip.size = area.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = ArenaView.new()
	_view.set_cropped(true)
	_clip.add_child(_view)
	_view.set_display_rect(area)
	_view.set_reduced_effects(reduced)
	_view.shake_enabled = false
	var layer := CanvasLayer.new()
	layer.layer = 1
	root.add_child(layer)
	_hud = Hud.new()
	_hud.theme = UiTheme.build()
	layer.add_child(_hud)
	_hud.set_reduced_effects(reduced)


func _battle(stage: int) -> Sim:
	var sim := Sim.new(170017)
	sim.start_run()
	if stage != 1:
		sim.start_wave(stage)
	_sim = sim
	_clear_plan()
	return sim


func _clear_plan() -> void:
	_sim._plan.clear()
	_sim._plan_idx = 0
	_sim.pending.clear()
	_sim.enemies.clear()
	_sim.player.iframes = 0.0
	for index in _sim.player.cooldowns.size():
		_sim.player.cooldowns[index] = 1000.0


func _bind() -> void:
	_view.bind(_sim)
	_hud.bind(_sim)
	_view.set_paused(true)
	_hud.paused = true
	_view.queue_redraw()
	_hud.queue_redraw()


func _advance(seconds: float) -> void:
	for _frame in ceili(seconds * 60):
		_sim.step(1.0 / 60.0, Vector2.ZERO)
	_view._refresh_world_presentation()


func _capture(name_value: String) -> void:
	_view.queue_redraw()
	_hud.queue_redraw()
	var before := RunSnapshot.capture(_sim)
	_check(RunSnapshot.restore(before) != null, name_value + " valid snapshot: " + RunSnapshot.last_error)
	for _frame in 4:
		await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	_check(image.get_size() == _extent, name_value + " original native pixels")
	var file_name := "%s-%s-%d.png" % [name_value, Loc.lang, _extent.x]
	_check(image.save_png(_out.path_join(file_name)) == OK, name_value + " saved")
	_check(RunSnapshot.capture(_sim) == before, name_value + " render leaves full state and RNG unchanged")
	_results.append({"name": name_value, "language": Loc.lang, "canvas": [_extent.x, _extent.y], "file": file_name,
		"delivery": _json_delivery(), "safe_workers": _sim.expedition["rescued"],
		"retired": _sim.expedition["bureau"]["retired"].duplicate(true)})
	print("bureau world art: ", file_name)


func _json_delivery() -> Dictionary:
	var delivery: Dictionary = BureauEvents.profile(_sim)["delivery"].duplicate(true)
	for key in ["pickup", "switch", "stamp", "inbox"]:
		if delivery.has(key):
			var point: Vector2 = delivery[key]
			delivery[key] = [point.x, point.y]
	return delivery


func _check(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)
		printerr("FAILED: ", description)


func _finish() -> void:
	var file := FileAccess.open(_out.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": _failures, "captures": _results, "disclosure": "Native clinical art fixtures, not a human playthrough. Enemy plans removed and travel repositioned; canonical interactions, state, hazards and rendering run unchanged."}, "\t"))
	print("bureau world art: ", _results.size(), " captures; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
