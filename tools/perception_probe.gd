extends SceneTree
# Native perception evidence. Journey is an uncut fresh run driven only through
# normal input and real UI controls. Clinic states are disclosed separately.
# --fixed-fps 60 --resolution 1280x720 --write-movie <output>/journey.avi
# --script res://tools/perception_probe.gd -- --mode=journey --output=<dir>

const DT := 1.0 / 60.0
const JOURNEY_FRAMES := 240 * 60
const CLINIC_FRAMES := 90 * 60
const JOURNEY_WALL_DEADLINE_MSEC := 25 * 60 * 1000
const CLINIC_WALL_DEADLINE_MSEC := 6 * 60 * 1000
const SEED := 20261022
const FIRST_BOSS_WAVE := 4

var _main: Node
var _mode := "journey"
var _language := "en"
var _reduced := false
var _compact := false
var _canvas := Vector2i(1280, 720)
var _output := ""
var _frame := 0
var _started := Time.get_ticks_msec()
var _failed := false
var _finished := false
var _bot := Bot.new(&"defensive")
var _bound: Sim
var _run: Sim
var _release_key: Key = KEY_NONE
var _next_ui := 0
var _shop_since := -1
var _shop_wave := -1
var _shop_rerolls := 0
var _workshop_attempts := 0
var _workshop_since := -1
var _previous_pos := Vector2.ZERO
var _initial_pos := Vector2.ZERO
var _overflow_inspection := false
var _original_pointer := Vector2.ZERO
var _pointer_saved := false
var _moving := false
var _boss_spawned := false
var _boss_defeated := false
var _highest_wave := 0
var _first_native_run := -1
var _finish_frame := -1
var _screenshots: Dictionary = {}
var _queued: Array[Dictionary] = []
var _timeline: Array[Dictionary] = []
var _checks: Array[Dictionary] = []
var _inputs: Array[Dictionary] = []
var _event_counts: Dictionary = {}
var _observed: Dictionary = {}
var _cases: Array[Dictionary] = []
var _summary: Dictionary = {"success": false, "failed": true}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
		elif argument.begins_with("--lang="):
			_language = argument.trim_prefix("--lang=")
		elif argument == "--reduced":
			_reduced = true
		elif argument == "--compact":
			_compact = true
	if _output.is_empty():
		_output = ProjectSettings.globalize_path("res://shots/perception_" + _mode)
	if not _require(_mode in ["journey", "clinic"], "known perception evidence mode"):
		return
	if not _require(DisplayServer.get_name() != "headless", "native rendering is required"):
		return
	if not _require(DirAccess.make_dir_recursive_absolute(_output.path_join("userdata")) == OK,
			"isolated output directory exists"):
		return
	for key: String in ["REVERB_SAVE", "REVERB_RUN_LOG", "REVERB_SETTINGS", "REVERB_FEEDBACK_LOG", "REVERB_SUSPEND"]:
		var path := _output.path_join("userdata").path_join(key.to_lower() + ".json")
		OS.set_environment(key, path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	if not _require(_language in ["en", "zh"] and (_mode == "clinic" or (_language == "en" and not _reduced and not _compact)),
			"journey uses one standard English native canvas; clinic supports Chinese/reduced"):
		return
	if _compact:
		_canvas = Vector2i(960, 540)
	OS.set_environment("REVERB_LANG", _language)
	Loc.lang = _language
	root.size = _canvas
	root.content_scale_size = _canvas
	DisplayServer.window_set_size(_canvas)
	AudioServer.set_bus_mute(0, false)
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/perception_cases.json"))
	if not _require(typeof(catalog) == TYPE_DICTIONARY and catalog.get("cases", []).size() == 40,
			"the stable forty-case acceptance catalog loads"):
		return
	for row: Dictionary in catalog["cases"]:
		_cases.append({"id": row["id"], "name": row["name"], "status": "not_exercised",
			"checkpoints": [], "scope": "automation does not establish human understanding"})
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_run_probe.call_deferred()


func _process(_delta: float) -> bool:
	_frame += 1
	if not _failed and not _finished and _mode == "clinic" and _frame > CLINIC_FRAMES:
		_fail("clinic exceeded ninety native seconds")
	var deadline := JOURNEY_WALL_DEADLINE_MSEC if _mode == "journey" else CLINIC_WALL_DEADLINE_MSEC
	if not _failed and not _finished and Time.get_ticks_msec() - _started > deadline:
		_fail("perception native capture exceeded its wall-clock deadline")
	return false


func _run_probe() -> void:
	for _index in 120:
		await process_frame
		if _main.character_select != null and _main.character_select.visible:
			break
	if not _require(_main.character_select != null and _main.character_select.visible,
			"actual Main reached selection"):
		return
	if not _require(_main.meta.familiar_actions.is_empty() and _main.meta.story_clues.is_empty(),
			"fresh evidence starts with no familiar actions or archived clues"):
		return
	_original_pointer = root.get_mouse_position()
	_pointer_saved = true
	if _mode == "journey":
		if not (await _journey()):
			return
	else:
		if not (await _clinic()):
			return
	_finish()


func _journey() -> bool:
	_summary["policy"] = {"fresh_run": true, "native_main_physics": true,
		"preseeded_knowledge": false, "preseeded_gear": false, "invulnerability": false,
		"skip_waves": false, "simulation_time_jumps": false, "manual_sim_step": false,
		"input_driver": "existing defensive Bot.move_dir; actual keyboard events and focused UI buttons",
		"visible_warning_driver": "twelve input directions queried against visible EnemyBrain.attack_profile and pure WorldArena.move_body at0.325/0.65seconds; no model changes",
		"shop_driver": "actual affordable marginal weaponDPS/price and upgrade quotes, with existing Bot item preferences; no grants or extra rolls",
		"seed": SEED, "max_game_seconds": 240.0, "wall_clock_limit_seconds": JOURNEY_WALL_DEADLINE_MSEC / 1000,
		"shop_reading_seconds": "five seconds first shop, three seconds later; automation reading dwell, not comprehension",
		"scope": "uncut automated first-run visibility and event timing through first boss; no human-learning claim"}
	_main.character_select.seed_edit.text = str(SEED)
	_queue_capture("fresh_selection", [], "clean Meta before any game input")
	await _present_queued()
	var first_card: Button
	for card: Button in _main.character_select._cards:
		if card.get_meta(&"character_id", &"") == &"looper" and not card.disabled:
			first_card = card
	if not _require(first_card != null, "fresh default Looper card is available"):
		return false
	_press_button(first_card, "fresh_character")
	for _index in JOURNEY_FRAMES:
		await process_frame
		if _failed:
			return false
		_release_input_key()
		if _main.sim == null:
			if _frame > 180:
				return _require(false, "actual character button starts the first run")
			await RenderingServer.frame_post_draw
			continue
		var sim: Sim = _main.sim
		if _bound == null:
			_run = sim
			_bind_events(sim)
			_first_native_run = _frame
			_initial_pos = sim.player.pos
			if not _require(sim.wave == 1 and sim.bank.takes.is_empty(), "new run starts wave1 without an inherited copy"):
				return false
		if sim.player.pos.distance_to(_initial_pos) > 20.0:
			_queue_capture("first_move", ["01"], "actual displacement after native movement input and onboarding surface")
		if not _require(sim == _run, "journey retains one uninterrupted actual run"):
			return false
		_highest_wave = maxi(_highest_wave, sim.wave)
		if sim.phase == Sim.Phase.LOST:
			_queue_capture("journey_loss", ["37"], "actual automated run lost; no health intervention")
			await _present_queued()
			return _require(false, "fresh run survived through the first boss")
		if _boss_defeated and _main.shop_ui.visible:
			_drive(Vector2.ZERO)
			if _finish_frame < 0:
				_finish_frame = _frame
				_queue_capture("first_boss_shop", ["25"], "real first Boss result settled into the actual shop")
			if _frame - _finish_frame >= 120:
				await _present_queued()
				return _require(_boss_spawned and _highest_wave == FIRST_BOSS_WAVE
					and int(_event_counts.get("shop_action", 0)) > 0, "natural first Boss and real shop transactions were reached")
		else:
			_drive_journey(sim)
		if _frame % 60 == 0:
			_note("native_status", {"wave": sim.wave, "wave_time": sim.wave_time,
				"hp": sim.player.hp, "pos": _point(sim.player.pos), "enemies": sim.enemies.size(),
				"pending": sim.pending.size(), "echoes": sim.echoes.size(), "encounter": sim.encounter_profile()})
		await _present_queued()
	return _require(false, "fresh first-Boss journey completed within240 native seconds")


func _drive_journey(sim: Sim) -> void:
	if _main.context_ui.visible:
		_drive(Vector2.ZERO)
		if _frame >= _next_ui:
			_press_first_enabled(_main.context_ui.choice_buttons, "context_choice")
		return
	if _main.boon_ui.visible:
		_drive(Vector2.ZERO)
		if _frame >= _next_ui:
			_press_first_enabled(_main.boon_ui.choice_buttons, "salvage_choice")
		return
	if _main.receipt_ui.visible:
		_drive(Vector2.ZERO)
		if _frame >= _next_ui:
			_press_button(_main.receipt_ui.dismiss_button, "receipt_close")
		return
	if _main.shop_ui.visible:
		_drive(Vector2.ZERO)
		_drive_shop(sim)
		return
	if _main.paused or sim.phase != Sim.Phase.WAVE:
		_drive(Vector2.ZERO)
		return
	var direction := _journey_direction(sim)
	_moving = direction.length() > 0.1
	_drive(direction)
	if _frame >= _next_ui:
		var choice := Expedition.interaction(sim)
		if not choice.is_empty() and bool(choice.get("available", false)) \
				and choice.get("kind", &"") in [&"repair", &"rescue", &"recycler"]:
			_press_key(KEY_E, "nearby_available_interaction")
		elif CharacterSkills.is_charged(sim) and _journey_skill_needed(sim):
			_press_key(KEY_SHIFT, "real_charged_skill")
		elif sim.can_retire_echo():
			var actor := EchoSystem.selected_actor(sim)
			if actor != null and actor.take.condition < 22.0 and not sim.enemies.is_empty():
				_press_key(KEY_SPACE, "worn_selected_copy_retirement")


func _journey_direction(sim: Sim) -> Vector2:
	var baseline := _bot.move_dir(sim)
	var warnings: Array[Dictionary] = []
	for enemy: EnemyState in sim.enemies:
		if enemy.dead:
			continue
		var attack := EnemyBrain.attack_profile(enemy)
		if bool(attack.get("visible", false)):
			warnings.append(attack)
	for zone: EnemyZone in sim.enemy_zones:
		if zone.active > 0.0:
			warnings.append({"kind": &"press", "target": zone.pos, "radius": zone.radius})
	if warnings.is_empty():
		return baseline
	var candidates := PackedVector2Array([baseline.normalized() if baseline.length_squared() > 0.01 else Vector2.RIGHT])
	for index in 12:
		candidates.append(Vector2.from_angle(TAU * float(index) / 12.0))
	var speed := sim.player.stats.get_stat(Stats.MOVE_SPEED)
	var chosen := baseline
	var best := -INF
	for direction: Vector2 in candidates:
		var future := WorldArena.move_body(sim.player.pos, direction * speed * 0.65, PlayerState.RADIUS)
		var middle := WorldArena.move_body(sim.player.pos, direction * speed * 0.325, PlayerState.RADIUS)
		var score := direction.dot(baseline) * 12.0 + future.distance_to(sim.player.pos) * 0.08
		score -= _warning_cost(future, warnings) + _warning_cost(middle, warnings) * 0.25
		for enemy: EnemyState in sim.enemies:
			if not enemy.dead:
				score -= maxf(0.0, enemy.radius + PlayerState.RADIUS + 65.0 - future.distance_to(enemy.pos)) * 4.0
		if score > best:
			best = score
			chosen = direction
	if _frame % 60 == 0:
		_note("pilot_visible_warning", {"wave": sim.wave, "pos": _point(sim.player.pos),
			"input": _point(chosen), "warning_count": warnings.size(),
			"current_cost": _warning_cost(sim.player.pos, warnings), "chosen_score": best})
	return chosen


func _warning_cost(point: Vector2, warnings: Array[Dictionary]) -> float:
	var total := 0.0
	var padding := PlayerState.RADIUS + 32.0
	for attack: Dictionary in warnings:
		var gap := 0.0
		match StringName(attack["kind"]):
			&"press":
				gap = point.distance_to(attack["target"]) - float(attack["radius"]) - padding
			&"cross":
				var offset := (point - (attack["target"] as Vector2)).abs()
				gap = minf(maxf(offset.x - 34.0 - padding, offset.y - float(attack["reach"]) - padding),
					maxf(offset.y - 34.0 - padding, offset.x - float(attack["reach"]) - padding))
			&"dash":
				var origin: Vector2 = attack["origin"]
				var segment: Vector2 = (attack["direction"] as Vector2) * float(attack["reach"])
				var fraction := clampf((point - origin).dot(segment) / maxf(0.001, segment.length_squared()), 0.0, 1.0)
				gap = point.distance_to(origin + segment * fraction) - float(attack["radius"]) - padding
			&"slam":
				# A conservative circle around the actual sector avoids crossing
				# its locked front while the ordinary body bot is fleeing.
				gap = point.distance_to(attack["origin"]) - float(attack["reach"]) - padding
			_:
				continue
		total += 1000.0 - gap * 12.0 if gap < 0.0 else -minf(64.0, gap)
	return total


func _journey_skill_needed(sim: Sim) -> bool:
	if sim.boss != null and not sim.boss.dead:
		var attack := EnemyBrain.attack_profile(sim.boss)
		if bool(attack.get("visible", false)) and sim.boss.brain_time <= 0.35 \
				and _warning_cost(sim.player.pos, [attack]) > 0.0:
			return true
		return sim.player.hp < sim.player.max_hp() * 0.45 and sim.enemies.size() >= 2
	# Preserve legitimately earned charge for the next mandatory boss when
	# ordinary movement is keeping the preceding encounter safe.
	if sim.is_boss_wave(sim.wave + 1):
		return sim.player.hp < sim.player.max_hp() * 0.45 and sim.enemies.size() >= 3
	return sim.enemies.size() >= 3


func _drive_shop(sim: Sim) -> void:
	var ui: ShopUi = _main.shop_ui
	if _shop_wave != sim.wave:
		_shop_wave = sim.wave
		_shop_since = _frame
		_shop_rerolls = 0
		_workshop_attempts = 0
		_workshop_since = -1
		_note("actual_shop_arrival", _shop_state(sim))
		_queue_capture("shop_%d_arrival" % sim.wave, ["03"] if sim.wave == 1 else [], "actual shop arrival before any buying input")
		if sim.wave == 1:
			for offer: Offer in sim.shop.offers:
				if not _require(not offer.is_contract(), "fresh first shop does not offer complex optional orders"):
					return
	if _frame - _shop_since < (300 if sim.wave == 1 else 180) or _frame < _next_ui:
		return
	if ui.inspection.visible:
		if _overflow_inspection:
			_overflow_inspection = false
			_press_button(ui.inspection.action_buttons[1], "actual_overflow_discard")
		else:
			_press_key(KEY_ESCAPE, "close_inspection")
		return
	if ui.workshop.visible:
		if _workshop_since < 0:
			_workshop_since = _frame
			_queue_capture("shop_%d_nested_read" % sim.wave, ["28"], "native weapon workshop keeps body text and focus visible")
		if _frame - _workshop_since < 90:
			return
		if _workshop_attempts < 3:
			_workshop_attempts += 1
			for button: Button in ui.workshop.choice_buttons:
				if not button.disabled:
					_press_button(button, "actual_workshop_choice")
					return
		_press_button(ui.workshop.cancel_button, "workshop_close")
		return
	_workshop_since = -1
	var best: OfferCard
	var score := -INF
	for card: OfferCard in ui.offers_box.get_children():
		if card.disabled or card.blocked_reason != &"" or card.offer.is_contract():
			continue
		var candidate := _journey_offer_score(card.offer, sim)
		if candidate > score:
			best = card
			score = candidate
	var upgrade := -1
	for index in sim.player.weapons.size():
		var quote := sim.shop.quote(ShopResult.UPGRADE, sim, null, index)
		if not quote.ok:
			continue
		var weapon: WeaponDef = sim.player.weapons[index]
		var old_dps := OfferCard.weapon_dps(weapon, sim.player.stats, sim.player.level_at(index),
			Combat.family_damage_mult(sim.player.weapons, weapon.family), Combat.family_cooldown_mult(sim.player.weapons, weapon.family))
		var new_dps := OfferCard.weapon_dps(weapon, sim.player.stats, sim.player.level_at(index) + 1,
			Combat.family_damage_mult(sim.player.weapons, weapon.family), Combat.family_cooldown_mult(sim.player.weapons, weapon.family))
		var candidate := (new_dps - old_dps) * 12.0 / float(maxi(1, quote.cost))
		if candidate > score:
			upgrade = index
			score = candidate
	if upgrade >= 0:
		ui.show_equipment_page(0)
		if ui.build_panel.focus_upgrade(upgrade):
			_press_button(ui.build_panel.upgrade_button, "actual_efficient_weapon_upgrade")
			return
	if best != null:
		_press_button(best, "actual_offer_purchase")
		return
	if _workshop_attempts < 3:
		ui.show_equipment_page(0)
		for index in sim.player.weapons.size():
			if ui.build_panel.focus_upgrade(index):
				_workshop_attempts += 1
				_press_button(ui.build_panel.upgrade_button, "actual_weapon_upgrade")
				return
	if _shop_rerolls < 1 and sim.player.materials >= sim.shop.reroll_cost(sim.wave) + 40:
		_shop_rerolls += 1
		_press_button(ui.reroll_button, "actual_shop_reroll")
		return
	if ui.start_button.disabled:
		# The real inspection action discards an overflowing old copy. No
		# bank-array edit stands in for the player's action.
		ui.show_equipment_page(1)
		if not ui.echo_panel.copy_buttons.is_empty():
			_overflow_inspection = true
			_press_button(ui.echo_panel.copy_buttons[0], "inspect_overflow_copy")
		return
	_note("actual_shop_departure", _shop_state(sim))
	_press_button(ui.start_button, "actual_next_encounter")


func _journey_offer_score(offer: Offer, sim: Sim) -> float:
	if offer.is_weapon():
		var extra := maxf(0.0, OfferCard.dps_with_added(sim.player, offer.weapon, offer.weapon_level) - OfferCard.total_dps(sim.player))
		return extra * 12.0 / float(maxi(1, offer.price)) + 1.0
	return _bot._score(offer, sim) * 0.4 / float(maxi(1, offer.price))


func _shop_state(sim: Sim) -> Dictionary:
	var weapons: Array[Dictionary] = []
	var offers: Array[Dictionary] = []
	for index in sim.player.weapons.size():
		var weapon: WeaponDef = sim.player.weapons[index]
		var upgrade := sim.shop.quote(ShopResult.UPGRADE, sim, null, index)
		weapons.append({"id": String(weapon.id), "level": sim.player.level_at(index),
			"upgrade_cost": upgrade.cost, "upgrade_reason": String(upgrade.reason), "upgrade_ok": upgrade.ok})
	for offer: Offer in sim.shop.offers:
		offers.append({"id": String(offer.id()), "price": offer.price, "blocked": String(sim.shop.block_reason(sim, offer))})
	return {"wave": sim.wave, "materials": sim.player.materials, "weapons": weapons, "offers": offers}


func _clinic() -> bool:
	_summary["policy"] = {"fresh_run": false, "mode": "disclosed staged clinic",
		"wall_clock_limit_seconds": CLINIC_WALL_DEADLINE_MSEC / 1000,
		"native_seconds_limit": 90, "busy_case_frame_bounds": [180, 600], "first_evolve_reading_frames": 60,
		"native_main_physics": "engine callback disabled; same Main._physics_process(1/60) called once per native frame",
		"key_input_route": "Input.parse_input_event for both press and release; real GUI then Main unhandled input, no direct interaction call",
		"rescue_stance": "initial player placement worker+(50,0), outside the live conveyor push; real out-and-back movement and exact nearest available worker check before E",
		"staging": "high-HP immobile harmless combo target with unchanged automatic stapler/stamp fire until a real repeated quiet combo; energy96 and actual scrap pickup; authored accepted rescue order using Expedition.on_order_purchased and actual wave2 worker with spent finite threat budget; shop800materials/four pistol grades0,0,3,3/two copies; actual donor and confirmation inputs; first evolved result deliberately remains visible for60frames before Undo; ordinary real UI commits and Undo",
		"scope": "timing and native pixels for controlled cases; not a fresh campaign or human-learning proof"}
	if not (await _clinic_busy_ready()):
		return false
	if not (await _clinic_rescue_closure()):
		return false
	if not (await _clinic_shop_actions()):
		return false
	return await _clinic_resume()


func _clinic_start(role: StringName) -> void:
	_drive(Vector2.ZERO)
	_release_input_key()
	_main.new_run(SEED, role, 0)
	_main.set_physics_process(false)
	_main.settings.reduced_effects = _reduced
	_main._apply_reduced_effects()
	_main.paused = false
	_main.audio.set_paused(false)
	_main._view.set_paused(false)
	_bind_events(_main.sim)
	_note("clinic_staged_new_run", {"role": String(role), "language": _language, "reduced": _reduced})


func _clinic_frames(count: int) -> bool:
	for _index in count:
		await process_frame
		if _failed:
			return false
		_release_input_key()
		_main._physics_process(DT)
		await _present_queued()
	return not _failed


func _clinic_busy_ready() -> bool:
	_clinic_start(&"solo")
	var sim: Sim = _main.sim
	var final_arrival: SpawnEvent = sim._plan.back()
	sim._plan.clear()
	sim._plan.append(final_arrival)
	sim._plan_idx = 0
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	sim.player.add_weapon(Content.weapon(&"stapler"))
	sim.player.add_weapon(Content.weapon(&"stamp"))
	sim.character_energy = 96.0
	sim.player.cooldowns[0] = 0.20
	sim.player.cooldowns[1] = 0.58
	var arrival := PendingSpawn.new()
	arrival.def = Content.enemy(&"grunt")
	arrival.pos = sim.player.pos + Vector2(80.0, 0.0)
	if not _require(sim._materialize(arrival), "clinic target uses actual spawn admission"):
		return false
	var target: EnemyState = sim.enemies.back()
	target.max_hp = 50000.0
	target.hp = target.max_hp
	target.speed = 0.0
	target.damage = 0.0
	var saw_pending := false
	var saw_ready := false
	var charged := false
	var repeat_quiet := false
	var first_combo_shots := -1
	var combos_before := int(_event_counts.get("combo", 0))
	var first_frame := _frame
	for index in 600:
		if not (await _clinic_frames(1)):
			return false
		var arena: Dictionary = _main._view.perception_profile()
		var mark: Dictionary = arena["moment"]
		if not charged and mark.get("kind", &"") == &"combo":
			first_combo_shots = int(_event_counts.get("shot", 0))
			var pickup := Pickup.new()
			pickup.pos = sim.player.pos
			pickup.value = 1
			sim.pickups.append(pickup)
			if not _require(sim.collect_pickup(pickup), "actual pickup crosses charge threshold while combo owns attention"):
				return false
			charged = true
			_queue_capture("busy_charge_admitted", ["11", "18"], "real charge crossing while actual combo accent is active")
		if charged and bool(arena["pending_ready"]):
			saw_pending = true
		if charged and mark.get("kind", &"") == &"ready":
			saw_ready = true
			_queue_capture("busy_charge_replayed", ["11"], "deferred ready is replayed after the critical mark releases attention")
		var hud: Dictionary = _main.hud.perception_profile()
		if int(_event_counts.get("combo", 0)) - combos_before >= 2 \
				and float(hud["combo_left"]) <= 0.001 and float(hud["combo_gate"]) > 0.0 \
				and int(_event_counts.get("shot", 0)) > first_combo_shots:
			repeat_quiet = true
			_queue_capture("repeat_combo_is_bounded", ["13"],
				"at least two actual combos with unchanged weapons still firing; HUD is quiet while its repeat gate remains active")
		if index >= 179 and charged and saw_pending and saw_ready and repeat_quiet \
				and _screenshots.has("repeat_combo_is_bounded"):
			break
	if not _require(charged and saw_pending and saw_ready and repeat_quiet
			and int(_event_counts.get("combo", 0)) - combos_before >= 2
			and _screenshots.has("repeat_combo_is_bounded")
			and sim.player.weapons.size() == 2 and sim.player.weapons[0].id == &"stapler"
			and sim.player.weapons[1].id == &"stamp",
			"actual busy charge replays and repeated combos become quiet while the same weapons keep firing"):
		return false
	_note("clinic_busy_ready_proof", {"pending_seen": saw_pending, "replayed_seen": saw_ready,
		"repeat_quiet": repeat_quiet, "combo_events": int(_event_counts.get("combo", 0)) - combos_before,
		"frames": _frame - first_frame, "hud": _main.hud.perception_profile()})
	return true


func _clinic_rescue_closure() -> bool:
	_clinic_start(&"looper")
	var sim: Sim = _main.sim
	var order := AnomalyContract.create(AnomalyContract.RESCUE, 2)
	order.accepted = true
	sim.active_contract = order
	Expedition.on_order_purchased(sim, order)
	sim.start_wave(2)
	sim._plan_idx = sim._plan.size()
	for index in sim.player.cooldowns.size():
		sim.player.cooldowns[index] = 1000.0
	var worker_id: StringName = &""
	for item: Dictionary in sim.interactables:
		if item["kind"] == &"rescue":
			worker_id = item["id"]
			sim.player.pos = item["pos"] + Vector2(50.0, 0.0)
			break
	if not _require(worker_id != &"", "canonical first-act endangered worker exists"):
		return false
	# Walk out and back through real input, satisfying the opening movement
	# requirement without writing wave_travel or assigning completion state.
	_drive(Vector2.RIGHT)
	if not (await _clinic_frames(36)):
		return false
	_drive(Vector2.LEFT)
	if not (await _clinic_frames(36)):
		return false
	_drive(Vector2.ZERO)
	if not _require(sim.phase == Sim.Phase.WAVE and sim.wave_travel >= Sim.FIRST_WAVE_TRAVEL
			and not Expedition.unfinished_work(sim).is_empty(), "spent threat budget retains actual unfinished nearby work"):
		return false
	_queue_capture("last_rescue_still_available", ["24"], "finite enemy budget spent, opening movement complete, actual nearby rescue remains")
	if not (await _clinic_frames(6)):
		return false
	var before_input := _rescue_input_state(sim, worker_id)
	_summary["rescue_clinic"] = {"before_input": before_input}
	_note("clinic_rescue_before_input", before_input)
	if not _require(before_input["nearest_id"] == String(worker_id)
			and before_input["nearest_kind"] == "rescue" and bool(before_input["nearest_available"]),
			"actual nearest interaction is the intended available worker immediately before E"):
		return false
	_press_key(KEY_E, "last_real_rescue_input")
	_note("clinic_rescue_after_press", _rescue_input_state(sim, worker_id))
	var saw_closure := false
	for index in 120:
		if not (await _clinic_frames(1)):
			return false
		if index == 0:
			_note("clinic_rescue_after_native_frame", _rescue_input_state(sim, worker_id))
		var transition: Dictionary = _main.transition_profile()
		if index < 12 and transition["target"] == &"shop" and not _main.shop_ui.visible:
			saw_closure = true
			_queue_capture("rescue_closure_before_shop", ["25"], "real rescue result keeps its finite closure before actual shop entry")
		if _main.shop_ui.visible:
			_queue_capture("last_rescue_actual_shop", ["24", "25"], "actual Main transition opens shop after the last real rescue")
			break
	_summary["rescue_clinic"]["after_wait"] = _rescue_input_state(sim, worker_id)
	_summary["rescue_clinic"]["saw_closure"] = saw_closure
	if not _require(saw_closure and _main.shop_ui.visible and Expedition._worker(sim, worker_id)["state"] == &"safe",
			"last real rescue completes and its readable closure precedes shop"):
		return false
	if not (await _clinic_frames(4)):
		return false
	var ui: ShopUi = _main.shop_ui
	if not _require(not _main.meta.familiar_actions.has(&"first_echo") and sim.bank.takes.size() == 1,
			"this actual first generated copy has not yet been marked familiar"):
		return false
	var take: EchoTake = sim.bank.takes.back()
	var identity := ui.echo_panel._identity_buttons.get(take.uid) as Control
	if not _require(identity != null and identity.is_visible_in_tree() and ui.echo_panel.is_visible_in_tree(),
			"actual first copy is exposed in the visible native panel"):
		return false
	var bounds := identity.get_global_rect()
	if not _require(root.get_visible_rect().encloses(bounds), "first copy's actual native row is inside the requested canvas"):
		return false
	_summary["first_echo_native"] = {"uid": take.uid, "familiar_before": false,
		"identity_visible": true, "panel_visible": true, "inside_viewport": true,
		"row_rect": [_point(bounds.position), _point(bounds.size)],
		"canvas": [_canvas.x, _canvas.y], "native_frame": _frame}
	_queue_capture("first_echo_native_handoff", ["03"],
		"fresh actual generated copy is shown before familiarity is confirmed; original native canvas")
	return await _clinic_frames(1)


func _rescue_input_state(sim: Sim, worker_id: StringName) -> Dictionary:
	var nearest := Expedition.interaction(sim)
	var worker := Expedition._worker(sim, worker_id)
	var focus := root.gui_get_focus_owner()
	return {"worker_id": String(worker_id), "worker_state": String(worker.get("state", &"missing")),
		"worker_pos": _point(worker.get("pos", Vector2.ZERO)), "player_pos": _point(sim.player.pos),
		"phase": int(sim.phase), "wave_time": sim.wave_time, "paused": _main.paused,
		"nearest_id": String(nearest.get("id", &"")), "nearest_kind": String(nearest.get("kind", &"")),
		"nearest_available": bool(nearest.get("available", false)),
		"nearest_gap": Expedition.interact_gap(sim, nearest) if not nearest.is_empty() else -1.0,
		"focus": str(focus.get_path()) if focus != null else "",
		"modals": {"context": _main.context_ui.visible, "boon": _main.boon_ui.visible,
			"receipt": _main.receipt_ui.visible, "story": _main.story_ui.visible,
			"echo_archive": _main.echo_archive_ui.visible, "echo_wheel": _main.echo_wheel.visible,
			"settings": _main.settings_ui.visible, "history": _main.history_ui.visible,
			"feedback": _main.feedback_ui.visible, "codex": _main.codex_ui.visible},
		"shop_visible": _main.shop_ui.visible, "transition": _main.transition_profile()}


func _clinic_shop_actions() -> bool:
	var sim: Sim = _main.sim
	var ui: ShopUi = _main.shop_ui
	# Explicit shop clinic inventory, separate from the unmodified journey.
	sim.player.materials = 800
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.weapon_investments.clear()
	sim.player.cooldowns.clear()
	for index in 4:
		sim.player.add_weapon(Content.weapon(&"pistol"))
		sim.player.weapon_levels[index] = 0 if index < 2 else WeaponDef.MAX_LEVEL
	var donor := EchoTake.new()
	donor.wave = 1
	donor.condition = 60.0
	donor.stats = sim.player.stats.copy()
	donor.weapons.append(Content.weapon(&"stamp"))
	donor.levels.append(0)
	donor.samples = PackedVector2Array([sim.player.pos, sim.player.pos + Vector2(30.0, 0.0)])
	sim.bank.add(donor)
	ui.refresh()
	ui.show_equipment_page(0)
	_note("clinic_shop_staging", {"materials": 800, "weapons": "four pistols at grades0,0,3,3", "donor_uid": donor.uid})
	if not (await _clinic_frames(3)):
		return false
	ui._open_combine_donors(0)
	if not (await _clinic_frames(2)):
		return false
	_press_first_enabled(ui.workshop.choice_buttons, "real_combine_donor_choice")
	if not (await _clinic_frames(2)):
		return false
	if not _require(ui.workshop.visible and sim.player.weapons.size() == 4,
			"donor selection opens the existing confirmation without consuming equipment"):
		return false
	var combine_before := RunSnapshot.capture(sim)
	if not _require(not combine_before.is_empty(), "strict pre-confirmation assembly snapshot exists"):
		return false
	_press_first_enabled(ui.workshop.choice_buttons, "real_combine_confirmation")
	_queue_capture("combine_real_commit", ["32"], "actual donor and confirmation inputs commit the assembly before Undo")
	if not (await _clinic_frames(2)):
		return false
	if not _require(sim.player.weapons.size() == 3, "assembly consumed exactly one actual donor slot"):
		return false
	if not (await _clinic_undo(ui, "combine", 4, combine_before)):
		return false
	ui.workshop.close()
	ui._on_evolve_weapon(2)
	if not (await _clinic_frames(2)):
		return false
	if not _require(not _main.meta.familiar_actions.has(&"evolve"), "this native evolution result is still unfamiliar"):
		return false
	var evolve_before := RunSnapshot.capture(sim)
	if not _require(not evolve_before.is_empty(), "strict pre-commit evolution snapshot exists"):
		return false
	var evolve_input_frame := _frame
	_press_first_enabled(ui.workshop.choice_buttons, "real_evolution_choice")
	_queue_capture("evolve_real_commit", ["33"], "actual target choice commits the quoted final weapon before Undo")
	if not (await _clinic_frames(2)):
		return false
	if not _require(sim.player.weapons[2].id != &"pistol", "evolution changes the actual selected weapon"):
		return false
	if not (await _clinic_frames(60)):
		return false
	if not _require(_main.meta.familiar_actions.has(&"evolve"),
			"leaving the actual first evolved result visible confirms persistent familiarity"):
		return false
	_note("clinic_evolve_visible_completion", {"input_native_frame": evolve_input_frame,
		"settled_native_frame": _frame, "deliberate_dwell_frames": 60, "familiar": true})
	_queue_capture("evolve_visible_settled", ["33"], "actual first evolved result has visibly settled and confirmed familiarity before Undo")
	if not (await _clinic_frames(1)):
		return false
	if not (await _clinic_undo(ui, "evolve", 4, evolve_before)):
		return false
	ui.workshop.close()
	for trait_name: StringName in [&"skill", &"repair", &"power"]:
		ui.show_equipment_page(1)
		if not (await _clinic_frames(2)):
			return false
		_press_button(ui.echo_panel.merge_button, "real_merge_mode")
		if not (await _clinic_frames(2)):
			return false
		var take_button := ui.echo_panel._identity_buttons.get(donor.uid) as Button
		if not _require(take_button != null, "actual donor identity remains in the current panel"):
			return false
		_press_button(take_button, "real_merge_donor")
		if not (await _clinic_frames(2)):
			return false
		var trait_button: Button
		for button: Button in ui.echo_panel.trait_buttons:
			if button.get_meta(&"trait", &"") == trait_name:
				trait_button = button
		if not _require(trait_button != null and not trait_button.disabled, "real quoted binding trait is available"):
			return false
		var merge_before := RunSnapshot.capture(sim)
		if not _require(not merge_before.is_empty(), "strict selected-trait pre-commit snapshot exists"):
			return false
		_press_button(trait_button, "real_merge_trait_" + String(trait_name))
		_queue_capture("merge_" + String(trait_name) + "_commit", ["35"], "actual selected binding trait and source identities before Undo")
		if not (await _clinic_frames(2)):
			return false
		if not _require(sim.bank.takes.size() == 1, "real binding consumes its one donor"):
			return false
		if not (await _clinic_undo(ui, "merge_" + String(trait_name), 4, merge_before)):
			return false
		if not _require(sim.bank.find_uid(donor.uid) != null and sim.bank.takes.size() == 2,
				"Undo restores both exact binding identities"):
			return false
	ui.show_equipment_page(0)
	return await _clinic_hover(ui)


func _clinic_undo(ui: ShopUi, label: String, expected_weapons: int, expected_before: Dictionary) -> bool:
	if ui.workshop.visible:
		ui.workshop.close()
	var before_profile := ui.transaction_profile()
	_press_button(ui.undo_button, "rapid_actual_undo_" + label)
	if not (await _clinic_frames(3)):
		return false
	var actual := RunSnapshot.capture(_main.sim)
	var profile := ui.transaction_profile()
	var snapshot_equal := actual == expected_before
	var diagnostic := {"label": label, "native_frame": _frame,
		"actual_weapon_count": _main.sim.player.weapons.size(), "expected_weapon_count": expected_weapons,
		"before_action": String(before_profile.get("action", &"")), "profile": profile,
		"snapshot_equal": snapshot_equal, "capture_error": RunSnapshot.last_error,
		"expected_objects": expected_before.get("objects", []).size(), "actual_objects": actual.get("objects", []).size()}
	if not _summary.has("undo_clinic"):
		_summary["undo_clinic"] = []
	_summary["undo_clinic"].append(diagnostic)
	_note("clinic_undo_proof", diagnostic)
	if not snapshot_equal:
		for entry: Array in [["expected", expected_before], ["actual", actual]]:
			var filename := "undo_" + label + "_" + str(entry[0]) + ".json"
			var file := FileAccess.open(_output.path_join(filename), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(entry[1], "  ") + "\n")
				file.close()
				diagnostic[str(entry[0]) + "_file"] = filename
	if not _require(_main.sim.player.weapons.size() == expected_weapons and snapshot_equal
			and profile.get("action", &"") == ShopResult.UNDO and profile.get("learn_action", &"") == &"",
			"rapid Undo exactly restores the pre-commit model and presents only its actual reverse result"):
		return false
	_queue_capture(label + "_undo_current_state", ["34"], "real Undo restores the exact model and replaces obsolete feedback with its own reverse result")
	return await _clinic_frames(1)


func _clinic_hover(ui: ShopUi) -> bool:
	if ui.workshop.visible:
		ui.workshop.close()
	if ui.inspection.visible:
		ui.inspection.close_inspection()
	for card: OfferCard in ui.offers_box.get_children():
		_move_pointer(card.get_global_rect().get_center())
		if not (await _clinic_frames(1)):
			return false
	if not _require(not ui.inspection.visible, "fast pointer sweep does not open transient inspection"):
		return false
	_queue_capture("pointer_sweep_keeps_reading", ["27"], "real fast mouse sweep respects hover intent")
	var card: OfferCard = ui.offers_box.get_children()[0]
	_move_pointer(card.get_global_rect().get_center())
	if not (await _clinic_frames(24)):
		return false
	if not _require(ui.inspection.visible, "deliberate dwell opens the real inspection"):
		return false
	_queue_capture("deliberate_inspection", ["27"], "same pointer deliberately remains over one item")
	return await _clinic_frames(2)


func _clinic_resume() -> bool:
	var ui: ShopUi = _main.shop_ui
	if ui.inspection.visible:
		ui.inspection.close_inspection()
	# Learn one ordinary successful result by actually leaving it visible;
	# rapid Undo above cannot stand in for a confirmed familiar action.
	ui.show_equipment_page(0)
	if not _require(ui.build_panel.focus_upgrade(0), "clinic can choose an actual affordable refit"):
		return false
	_press_button(ui.build_panel.upgrade_button, "confirmed_actual_upgrade")
	if not (await _clinic_frames(90)):
		return false
	if not _require(_main.meta.familiar_actions.has(&"upgrade"), "visible successful result persists learned upgrade"):
		return false
	var expected: Dictionary = RunSnapshot.capture(_main.sim)
	var learned: Array = Array(_main.meta.familiar_actions)
	_press_key(KEY_P, "real_pause_for_save")
	if not (await _clinic_frames(3)):
		return false
	if not _require(_main.pause_ui.visible, "real pause exposes save-and-return"):
		return false
	_press_button(_main.pause_ui.save_button, "actual_save_and_return")
	if not (await _clinic_frames(3)):
		return false
	if not _require(_main.sim == null and _main.character_select.visible, "actual save returns to selection"):
		return false
	_press_button(_main.character_select.continue_button, "actual_continue_saved_run")
	if not (await _clinic_frames(4)):
		return false
	if not _require(_main.sim != null and RunSnapshot.capture(_main.sim) == expected
			and Array(_main.meta.familiar_actions) == learned, "Continue preserves exact saved run and earned familiarity"):
		return false
	_queue_capture("familiar_actual_resume", ["40"], "actual save/Continue retains learned actions and exact saved model")
	return await _clinic_frames(3)


func _move_pointer(point: Vector2) -> void:
	root.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.notify_mouse_entered()
	root.push_input(event, true)


func _bind_events(sim: Sim) -> void:
	_bound = sim
	_previous_pos = sim.player.pos
	sim.wave_started.connect(_on_wave)
	sim.wave_ended.connect(_on_wave_ended)
	sim.shot_fired_info.connect(_on_shot)
	sim.damage_event.connect(_on_damage)
	sim.enemy_killed.connect(_on_kill)
	sim.player_hurt_info.connect(_on_hurt)
	sim.echo_spawned.connect(_on_echo)
	sim.echo_retired.connect(_on_retire)
	sim.combo_triggered.connect(_on_combo)
	sim.world_event.connect(_on_world)
	sim.material_collected.connect(_on_pickup)
	sim.boss_spawned.connect(_on_boss)
	sim.boss_phase_changed.connect(_on_boss_phase)
	sim.boss_defeated.connect(_on_boss_defeated)
	sim.shop.shop_action_resolved.connect(_on_shop_action)


func _on_wave(wave: int) -> void:
	_note("wave_started", {"wave": wave})
	_queue_capture("wave_%d_opening" % wave, ["04"] if wave == 2 else [],
		"actual wave_started signal; journey has no wave staging, clinic staging is explicitly disclosed")


func _on_wave_ended(wave: int) -> void:
	_note("wave_ended", {"wave": wave, "wave_time": _bound.wave_time,
		"earned": _bound.last_wave_earned, "remaining_hp": _bound.player.hp})


func _on_shot(info: ShotInfo) -> void:
	_count("shot")
	if info.source < 0 and _moving:
		_queue_capture("moving_autofire", ["07"], "actual player ShotInfo while normal movement input is held")
	_queue_capture("weapon_contact_language", ["08"], "native actual weapon identity; visual recognition requires human review")


func _on_damage(info: DamageInfo) -> void:
	_count("damage")
	_queue_capture("real_enemy_hit", ["09"], "actual damage event and native hit presentation")


func _on_kill(info: EnemyDeathInfo) -> void:
	_count("kill")
	_queue_capture("real_enemy_death", ["09"], "actual removal and native death body")
	_note_first("first_kill", {"enemy_id": String(info.enemy_id), "uid": info.target_uid})


func _on_hurt(info: PlayerHurtInfo) -> void:
	_count("hurt")
	_note_first("first_block" if info.full_block() else "first_hurt", {"amount": info.amount, "effect": String(info.effect)})


func _on_echo(actor: EchoActor) -> void:
	_count("echo")
	_queue_capture("first_live_copy", ["19", "20"], "actual generated copy's future route and persistent condition")
	_note("echo_spawned", {"uid": actor.take.uid, "condition": actor.take.condition, "duration": actor.take.duration()})


func _on_retire(info: EchoRetirementInfo) -> void:
	_count("retire")
	_note("echo_retired", {"uid": info.uid, "reason": String(info.reason), "kind": String(info.kind)})
	_queue_capture("retirement_" + String(info.reason), ["06", "21"], "actual source and reason; not a claim both reasons were observed")


func _on_combo(info: ComboInfo) -> void:
	_count("combo")
	_note("combo", info.to_dict())
	_queue_capture("first_combo", ["13"], "actual combo; repeat timing is checked separately in clinic")


func _on_world(info: Dictionary) -> void:
	var kind := String(info.get("kind", &""))
	if kind == "interaction_result":
		var accepted := bool(info.get("ok", false))
		_note("interaction" if accepted else "interaction_rejected", {
			"target_id": String(info.get("target_id", &"")),
			"target_kind": String(info.get("target_kind", &"")), "reason": String(info.get("reason", &""))})
		if accepted:
			_queue_capture("first_interaction", ["02"], "actual accepted interaction input")
	elif kind == "character_skill":
		_note("character_skill", {"ok": bool(info.get("ok", false)), "ability": String(info.get("ability", &""))})
		_queue_capture("real_skill", ["12"], "actual role activation result")
	elif kind in ["worker_saved", "machine_repaired"]:
		_note(kind, {"subject": String(info.get("subject", &""))})


func _on_pickup(amount: int) -> void:
	_count("pickup")
	_note_first("first_manual_pickup", {"amount": amount, "energy": _bound.character_energy})
	_queue_capture("manual_pickup", ["17"], "actual material collection, distinct from the wave-settlement event timeline")


func _on_boss(enemy: EnemyState) -> void:
	_boss_spawned = true
	_note("first_boss_spawned", {"uid": enemy.uid, "wave": _bound.wave, "time": _bound.wave_time})
	_queue_capture("first_boss_warning", ["14"], "actual first mandatory Boss appears")


func _on_boss_phase(phase: int) -> void:
	_note("boss_phase", {"phase": phase})
	if phase == 2:
		_queue_capture("first_boss_tear", ["15"], "actual first Boss phase change, no damage intervention")


func _on_boss_defeated() -> void:
	_boss_defeated = true
	_note("first_boss_defeated", {"wave": _bound.wave, "time": _bound.wave_time})
	_queue_capture("first_boss_defeat", ["25"], "actual Boss defeat and finite closure")


func _on_shop_action(result: ShopResult) -> void:
	_count("shop_action")
	_note("shop_action", {"ok": result.ok, "action": String(result.action), "reason": String(result.reason), "cost": result.cost})
	if result.ok and result.action in [ShopResult.BUY, ShopResult.UPGRADE]:
		_queue_capture("shop_success_" + String(result.action), ["29"], "actual shop transaction through focused UI input")


func _queue_capture(label: String, ids: Array, reason: String) -> void:
	if _screenshots.has(label):
		return
	for queued: Dictionary in _queued:
		if queued["label"] == label:
			return
	_queued.append({"label": label, "case_ids": ids, "reason": reason})


func _present_queued() -> void:
	var periodic := _mode == "journey" and _frame % 600 == 0
	if _queued.is_empty() and not periodic:
		await RenderingServer.frame_post_draw
		return
	var before: Dictionary = {}
	var rng := 0
	var hazard := 0
	var sim: Sim = _main.sim
	if sim != null:
		before = RunSnapshot.capture(sim)
		if not _require(not before.is_empty(), "strict source snapshot captures: " + RunSnapshot.last_error):
			return
		var restored := RunSnapshot.restore(before)
		var restore_error := RunSnapshot.last_error
		if restored == null:
			_snapshot_failure("restore_null", restore_error, before, {})
			return
		var recaptured := RunSnapshot.capture(restored)
		var recapture_error := RunSnapshot.last_error
		if recaptured.is_empty():
			_snapshot_failure("recapture_empty", recapture_error, before, recaptured)
			return
		if recaptured != before:
			_snapshot_failure("recapture_mismatch", recapture_error, before, recaptured)
			return
		rng = sim.rng.state
		hazard = sim.hazard_rng.state
	await RenderingServer.frame_post_draw
	if sim != null:
		if not _require(RunSnapshot.capture(sim) == before and sim.rng.state == rng and sim.hazard_rng.state == hazard,
				"same native frame's process/draw changes no full model state or RNG"):
			return
		_checks.append({"native_frame": _frame, "periodic": periodic, "strict_roundtrip": true,
			"full_snapshot_unchanged": true, "rng_unchanged": true, "hazard_rng_unchanged": true})
	if _queued.is_empty():
		return
	var image := root.get_texture().get_image()
	if not _require(image != null and image.get_size() == _canvas, "checkpoint pixels match the original requested native canvas"):
		return
	for queued: Dictionary in _queued:
		var label: String = queued["label"]
		var filename := label + ".png"
		if not _require(image.save_png(_output.path_join(filename)) == OK, "native checkpoint saves"):
			return
		var row := {"file": filename, "native_frame": _frame, "seconds": float(_frame) / 60.0,
			"width": image.get_width(), "height": image.get_height(),
			"case_ids": queued["case_ids"], "reason": queued["reason"], "profiles": _profiles()}
		_screenshots[label] = row
		for id: String in queued["case_ids"]:
			for acceptance: Dictionary in _cases:
				if acceptance["id"] == id:
					acceptance["status"] = "native_observed"
					acceptance["checkpoints"].append(label)
	_queued.clear()


func _snapshot_failure(kind: String, error: String, before: Dictionary, recaptured: Dictionary) -> void:
	var labels: Array[String] = []
	for queued: Dictionary in _queued:
		labels.append(queued["label"])
	var row := {"kind": kind, "error": error, "native_frame": _frame, "labels": labels,
		"before_objects": before.get("objects", []).size(), "recaptured_objects": recaptured.get("objects", []).size()}
	var sim: Sim = _main.sim
	var takes: Array[Dictionary] = []
	for take: EchoTake in sim.bank.takes:
		takes.append({"uid": take.uid, "samples": take.samples.size(), "duration": take.duration(),
			"condition": take.condition})
	row["runtime"] = {"wave": sim.wave, "phase": int(sim.phase), "wave_time": sim.wave_time,
		"recorder_elapsed": sim.recorder.get("_elapsed"), "recorder_accumulator": sim.recorder.get("_acc"),
		"recorder_samples": sim.recorder.samples.size(), "tape_max_samples": EchoTake.MAX_SAMPLES,
		"takes": takes}
	for entry: Array in [["before", before], ["recaptured", recaptured]]:
		var filename := "snapshot_failure_" + str(entry[0]) + ".json"
		var file := FileAccess.open(_output.path_join(filename), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(entry[1], "  ") + "\n")
			file.close()
			row[str(entry[0]) + "_file"] = filename
	_summary["snapshot_failure"] = row
	_fail("checkpoint strict restore failure [%s, %s] atframe%d labels=%s" % [kind, error, _frame, str(labels)])


func _profiles() -> Dictionary:
	return {"hud": _main.hud.perception_profile(), "arena": _main._view.perception_profile(),
		"transition": _main.transition_profile(), "audio": _main.audio.feedback_last_data(),
		"audio_state": _main.audio.binding_state(), "familiar_actions": Array(_main.meta.familiar_actions)}


func _press_first_enabled(buttons: Array[Button], reason: String) -> void:
	for button in buttons:
		if not button.disabled and button.is_visible_in_tree():
			_press_button(button, reason)
			return
	_fail("no enabled native button: " + reason)


func _press_button(button: Button, reason: String) -> void:
	if not _require(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,
			"actual visible enabled button: " + reason):
		return
	button.grab_focus()
	_inputs.append({"native_frame": _frame, "reason": reason, "button": str(button.get_path()), "text": button.text})
	_press_key(KEY_ENTER, reason)


func _press_key(code: Key, reason: String) -> void:
	if _release_key != KEY_NONE:
		_release_input_key()
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	_release_key = code
	_next_ui = _frame + 24
	_inputs.append({"native_frame": _frame, "key": int(code), "reason": reason})


func _release_input_key() -> void:
	if _release_key == KEY_NONE:
		return
	var event := InputEventKey.new()
	event.keycode = _release_key
	event.physical_keycode = _release_key
	event.pressed = false
	Input.parse_input_event(event)
	_release_key = KEY_NONE


func _drive(direction: Vector2) -> void:
	for row: Array in [[&"move_left", maxf(0.0, -direction.x)], [&"move_right", maxf(0.0, direction.x)],
		[&"move_up", maxf(0.0, -direction.y)], [&"move_down", maxf(0.0, direction.y)]]:
		if float(row[1]) > 0.0:
			Input.action_press(row[0], float(row[1]))
		else:
			Input.action_release(row[0])


func _note_first(kind: String, fields: Dictionary) -> void:
	if _observed.has(kind):
		return
	_observed[kind] = true
	_note(kind, fields)


func _note(kind: String, fields: Dictionary) -> void:
	var row := {"native_frame": _frame, "seconds": float(_frame) / 60.0, "kind": kind}
	row.merge(fields)
	_timeline.append(row)


func _count(kind: String) -> void:
	_event_counts[kind] = int(_event_counts.get(kind, 0)) + 1


func _point(point: Vector2) -> Array:
	return [point.x, point.y]


func _finish() -> void:
	_finished = true
	_release_input_key()
	_drive(Vector2.ZERO)
	if not _require(not AudioServer.is_bus_mute(0), "real GameAudio master mix remains audible"):
		return
	var commit := OS.get_environment("REVERB_BUILD_COMMIT").strip_edges()
	if commit.is_empty():
		commit = str(ProjectSettings.get_setting("application/config/build_commit", "")).strip_edges()
	if not _require(not commit.is_empty(), "evidence identifies the exact CI source commit"):
		return
	var audio_counts: Dictionary = {}
	for cue: StringName in GameAudio.ALL_NAMES:
		audio_counts[String(cue)] = _main.audio.play_count(cue)
	_summary.merge({"success": true, "failed": false, "commit": commit, "mode": _mode,
		"language": _language, "reduced": _reduced, "compact": _compact, "audio_play_counts": audio_counts,
		"native_frames": _frame, "fps": 60, "canvas": [_canvas.x, _canvas.y], "uncut": true,
		"audio": "real unmuted GameAudio master mix", "case_coverage": _cases,
		"screenshots": _screenshots, "timeline": _timeline, "read_only_checks": _checks,
		"inputs": _inputs, "event_counts": _event_counts, "highest_wave": _highest_wave,
		"first_boss_spawned": _boss_spawned, "first_boss_defeated": _boss_defeated,
		"first_run_native_frame": _first_native_run, "claim": "automated visibility/timing evidence; human understanding is unverified"}, true)
	_main._detach_presentation_session()
	_main.audio.stop_all()
	_main.queue_free()
	_main = null
	_restore_pointer()
	if _write_source():
		print("perception probe: OK (%s, %d native frames, %d PNGs)" % [_mode, _frame, _screenshots.size()])
		quit()


func _write_source() -> bool:
	var file := FileAccess.open(_output.path_join("perception_source.json"), FileAccess.WRITE)
	if file == null:
		printerr("perception probe: could not write source JSON")
		quit(1)
		return false
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	return true


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_summary.merge({"success": false, "failed": true, "failure": message, "mode": _mode,
		"native_frames": _frame, "case_coverage": _cases, "screenshots": _screenshots,
		"timeline": _timeline, "read_only_checks": _checks, "inputs": _inputs,
		"event_counts": _event_counts, "highest_wave": _highest_wave}, true)
	_release_input_key()
	_drive(Vector2.ZERO)
	_restore_pointer()
	printerr("perception probe FAILED: " + message)
	if not _output.is_empty():
		_write_source()
	quit(1)


func _restore_pointer() -> void:
	if _pointer_saved:
		root.warp_mouse(_original_pointer)
		_pointer_saved = false
