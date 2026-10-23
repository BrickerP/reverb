extends SceneTree
# Drives the real Main scene through input and UI buttons: a few waves with the dev bot, a forced
# death, the end screen, and a restart. Run with --fixed-fps 60 so game time is not tied to wall time.
# Pass `-- --shots` (windowed run) to also save screenshots into res://shots.

enum Stage { PLAY, DIE, RESTART, AFTER }

const FRAME_CAP := 60 * 60 * 25
const TARGET_WAVE := 4
const SMOKE_SEED := 20261022
const AFTER_FRAMES := 600
const SHOT_DELAY := 60

var _main: Node
var _bot := Bot.new()
var _stage := Stage.PLAY
var _frame := 0
var _after := 0
var _first_sim: Sim
var _shots_dir := ""
var _shots_taken := {}
var _settle := 0
var _view_draws := 0
var _hud_draws := 0
var _purchases := 0
var _discards := 0
var _echo_frames := 0
var _max_wave := 0
var _saw_end := false
var _hooked := false


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://smoke_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://smoke_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://smoke_settings.json")
	if OS.get_cmdline_user_args().has("--shots"):
		_shots_dir = ProjectSettings.globalize_path("res://shots")
		DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _hook_draw_counters() -> void:
	(_find(_main, ArenaView) as ArenaView).draw.connect(func() -> void: _view_draws += 1)
	(_find(_main, Hud) as Hud).draw.connect(func() -> void: _hud_draws += 1)
	_hooked = true


func _physics_process(_delta: float) -> bool:
	var sim: Sim = _main.sim
	if sim == null:
		if _main.character_select != null and _main.character_select.visible:
			_main.choose_character(&"looper")
		return false
	if not _hooked:
		_hook_draw_counters()
		_main.new_run(SMOKE_SEED)
		return false
	_frame += 1
	_max_wave = maxi(_max_wave, sim.wave)
	if _frame > FRAME_CAP:
		return _finish("frame cap reached in stage %d (wave %d)" % [_stage, sim.wave])
	match _stage:
		Stage.PLAY:
			_play(sim)
		Stage.DIE:
			_die(sim)
		Stage.RESTART:
			_restart(sim)
		Stage.AFTER:
			_drive(_bot.move_dir(sim))
			_after += 1
			if _after >= AFTER_FRAMES:
				return _finish("")
	return false


func _play(sim: Sim) -> void:
	match sim.phase:
		Sim.Phase.WAVE:
			_drive(_bot.move_dir(sim))
			_echo_frames += 1 if not sim.echoes.is_empty() else 0
			if sim.wave >= TARGET_WAVE and sim.wave_time > 8.0:
				_shot("wave")
				_stage = Stage.DIE
		Sim.Phase.SHOP:
			_drive(Vector2.ZERO)
			if sim.wave == TARGET_WAVE - 1 and _main.shop_ui.visible and _hold_for_shot("shop"):
				return
			_shop_step()
		_:
			_stage = Stage.RESTART


func _die(sim: Sim) -> void:
	_drive(Vector2.ZERO)
	if sim.phase == Sim.Phase.WAVE:
		sim.player.hp = -sim.player.max_hp()
		sim.player.stats.values[Stats.HP_REGEN] = 0.0
	else:
		_stage = Stage.RESTART


func _restart(sim: Sim) -> void:
	var end_ui: EndUi = _main.end_ui
	if not end_ui.visible:
		return
	_saw_end = true
	if _hold_for_shot("end"):
		return
	_first_sim = sim
	end_ui.restart_button.pressed.emit()
	_stage = Stage.AFTER


func _shop_step() -> void:
	var ui: ShopUi = _main.shop_ui
	if not ui.visible:
		return
	for card: OfferCard in ui.offers_box.get_children():
		if not card.disabled and card.blocked_reason == &"":
			card.pressed.emit()
			_purchases += 1
			return
	if ui.start_button.disabled:
		if not ui.echo_panel.discard_buttons.is_empty():
			ui.echo_panel.discard_buttons[0].pressed.emit()
			_discards += 1
		return
	ui.start_button.pressed.emit()


func _hold_for_shot(name: String) -> bool:
	if _shots_dir == "" or _shots_taken.has(name):
		return false
	_settle += 1
	if _settle < SHOT_DELAY:
		return true
	_settle = 0
	_shot(name)
	return false


func _shot(name: String) -> void:
	if _shots_dir == "" or _shots_taken.has(name):
		return
	_shots_taken[name] = true
	# The viewport texture lags the simulation under --fixed-fps; force a present first.
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [_shots_dir, name])


func _drive(dir: Vector2) -> void:
	_axis(&"move_left", maxf(0.0, -dir.x))
	_axis(&"move_right", maxf(0.0, dir.x))
	_axis(&"move_up", maxf(0.0, -dir.y))
	_axis(&"move_down", maxf(0.0, dir.y))


func _axis(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _find(node: Node, type: Variant) -> Node:
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
		var deeper := _find(child, type)
		if deeper != null:
			return deeper
	return null


func _finish(problem: String) -> bool:
	var failures: Array[String] = []
	if problem != "":
		failures.append(problem)
	var sim: Sim = _main.sim
	if _max_wave < TARGET_WAVE:
		failures.append("never reached wave %d" % TARGET_WAVE)
	if _purchases == 0:
		failures.append("never bought anything through the shop UI")
	if _echo_frames == 0:
		failures.append("no echo was ever active")
	if not _saw_end:
		failures.append("end screen never appeared")
	if _first_sim == null or sim == _first_sim or sim.wave < 1:
		failures.append("restart did not start a fresh run")
	if _view_draws == 0 or _hud_draws == 0:
		failures.append("nothing was drawn (arena %d, hud %d)" % [_view_draws, _hud_draws])
	print("smoke: frames=%d max_wave=%d purchases=%d discards=%d echo_frames=%d draws=%d/%d" % [
			_frame, _max_wave, _purchases, _discards, _echo_frames, _view_draws, _hud_draws])
	for f in failures:
		printerr("SMOKE FAIL: " + f)
	print("smoke: " + ("FAILED" if not failures.is_empty() else "OK"))
	quit(1 if not failures.is_empty() else 0)
	return true
