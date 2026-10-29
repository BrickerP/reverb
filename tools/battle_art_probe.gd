extends SceneTree
# Actual Main/Sim battle-art fixture, about 23 seconds at 60 FPS.
# Durability, loadouts, waves and cooldowns are staged for legibility, not balance.
# Usage: REVERB_LANG=en godot --path . --fixed-fps 60 --disable-vsync \
#   --write-movie res://shots/battle-art.avi --script res://tools/battle_art_probe.gd
# Add -- --reduced, or REVERB_BATTLE_REDUCED=1, for the static/reduced-effects path.

const BASE: Array[StringName] = [&"pistol", &"smg", &"shotgun", &"rifle", &"orb", &"flechette"]
const EVOLVED: Array[StringName] = [&"longbow", &"hex_bolt", &"twin_fangs", &"flak_crown", &"rail_spike", &"nova_core"]
const ENEMIES: Array[StringName] = [&"grunt", &"runner", &"brute", &"bomber", &"warden", &"silencer"]
const ELITES: Array[StringName] = [&"overclocked", &"bulwark", &"volatile", &"splitter"]
const SEED := 20261029

var _main: Node
var _failed := false
var _frame := 0
var _started_ms := Time.get_ticks_msec()
var _dir := ""
var _reduced := false
var _weapons_seen: Dictionary = {}
var _copy_shot_tokens: Dictionary = {}
var _copy_action_tokens: Dictionary = {}
var _deaths_seen: Dictionary = {}
var _contact_uid := -1
var _summary: Dictionary = {"screenshots": {}, "stages": {}, "deaths": [],
	"peak_feedback": {}, "fixture": {"balance_evidence": false,
		"durability": "staged", "waves_and_timers": "staged", "real_simulation_events": true}}


func _initialize() -> void:
	for pair in [["REVERB_SAVE", "test_battle_art_save.json"],
		["REVERB_RUN_LOG", "test_battle_art_runs.jsonl"],
		["REVERB_SETTINGS", "test_battle_art_settings.json"],
		["REVERB_FEEDBACK_LOG", "test_battle_art_feedback.jsonl"]]:
		var path := "user://" + str(pair[1])
		OS.set_environment(str(pair[0]), path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("REVERB_RUN_SOURCE", "fixture")
	for argument in OS.get_cmdline_user_args():
		if argument != "--reduced":
			_fail("unknown probe argument: " + argument)
			return
	_reduced = OS.get_environment("REVERB_BATTLE_REDUCED") == "1" \
		or OS.get_cmdline_user_args().has("--reduced")
	if DisplayServer.get_name() == "headless":
		_fail("battle_art_probe needs a real rendering window")
		return
	# macOS may skip automatic rendering for an occluded window, even in Movie Maker.
	# One explicit draw per process tick keeps the actual recorded action timeline complete.
	RenderingServer.render_loop_enabled = false
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frame += 1
	if Time.get_ticks_msec() - _started_ms > 120000 and not _failed:
		_fail("wall-clock deadline before battle art completed")
	if _main != null and _main._view != null and _main._view.sim != null:
		var counts: Dictionary = _main._view.feedback_counts()
		for key in counts:
			_summary["peak_feedback"][key] = maxi(int(_summary["peak_feedback"].get(key, 0)), int(counts[key]))
	if not _failed:
		RenderingServer.force_draw()
	return false


func _run() -> void:
	await _wait(8)
	_dir = ProjectSettings.globalize_path("res://shots/battle-art/" + Loc.lang + ("-reduced" if _reduced else "-standard"))
	DirAccess.make_dir_recursive_absolute(_dir)
	_summary["language"] = Loc.lang
	_summary["reduced_effects"] = _reduced
	_summary["pending_actor_sheets"] = _pending_art()
	_main.settings.reduced_effects = _reduced
	_main._apply_reduced_effects()
	await _wait(24)
	if not await _capture("cast"):
		return
	if not await _gallery():
		return
	if not await _second_loadout():
		return
	if not await _copies():
		return
	if not await _boss():
		return
	if not await _player_loss():
		return
	_release()
	_summary["weapon_ids_seen"] = _weapons_seen.keys()
	_summary["copy_shot_tokens"] = _copy_shot_tokens.keys()
	_summary["copy_action_tokens"] = _copy_action_tokens.keys()
	_summary["enemy_ids_killed"] = _deaths_seen.keys()
	_summary["frames"] = _frame
	_summary["complete_art"] = (_summary["pending_actor_sheets"] as Array).is_empty()
	if not _require(_weapons_seen.size() == 12, "all twelve actual weapon emitters fired"):
		return
	if not _require(_deaths_seen.size() == 7, "all seven body identities emitted actual death snapshots"):
		return
	if not _require(_copy_shot_tokens.size() >= 2, "actual copy shots preserve their distinct signed actor identities"):
		return
	if not _reduced and not _require(int(_summary["peak_feedback"].get("actor_actions", 0)) >= 2,
			"real copy shots drive body actions rather than being mistaken for unknown actors"):
		return
	if not _reduced and not _require(_copy_action_tokens.size() >= 2,
			"at least two real copy identities select drawn attack poses"):
		return
	var cap := BattleDirector.REDUCED_CORPSES if _reduced else BattleDirector.MAX_CORPSES
	if not _require(int(_summary["peak_feedback"].get("corpses", 0)) <= cap, "death snapshots remain in their budget"):
		return
	_main.audio.stop_all()
	_main.show_select()
	if not _require(_main.sim == null and _main._view.sim == null, "normal title path detaches the simulation"):
		return
	_main.queue_free()
	_main = null
	await _wait(2)
	_write_summary()
	if not bool(_summary["complete_art"]):
		printerr("battle art probe: INCOMPLETE - pending actor sheets: %s" % str(_summary["pending_actor_sheets"]))
		quit(2)
		return
	print("battle art probe: OK, %s, reduced=%s, %d frames" % [Loc.lang, _reduced, _frame])
	quit()


func _new_fixture(wave: int, loadout: Array[StringName], copy_count: int = 0, keep_plan: bool = false) -> Sim:
	_release()
	_main.new_run(SEED + wave, &"looper")
	var sim: Sim = _main.sim
	sim.shot_fired_info.connect(_shot)
	sim.enemy_killed.connect(_death)
	sim.player_hurt_info.connect(_hurt)
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for id in loadout:
		sim.player.add_weapon(Content.weapon(id))
	sim.player.stats.values[Stats.MAX_HP] = 2000.0
	sim.player.stats.values[Stats.ECHO_SLOTS] = float(maxi(3, copy_count))
	sim.player.stats.values[Stats.ECHO_LIFESPAN] = 10.0
	sim.player.hp = sim.player.max_hp()
	sim.player.materials = 500
	sim.bank.takes.clear()
	for index in copy_count:
		var take := EchoTake.new()
		take.wave = index + 1
		take.stats = sim.player.stats.copy()
		take.merged = index == 3 or index == 6
		take.weapons.append(Content.weapon(&"pistol"))
		take.levels.append(0)
		var center := Vector2(250.0 + float(index % 4) * 250.0, 230.0 + float(index / 4) * 190.0)
		for sample in 60:
			var angle := float(sample) / 59.0 * TAU
			take.samples.append(center + Vector2(cos(angle) * 32.0, sin(angle) * 22.0))
		sim.bank.add(take)
	sim.start_wave(wave)
	for index in sim.bank.takes.size():
		var age := copy_count - index
		if copy_count == 8 and index == 0:
			age = sim.echo_lifespan() - 1
		sim.bank.takes[index].age = age
		sim.bank.takes[index].wave = maxi(1, wave - age)
	sim.player.pos = Vector2(640.0, 510.0)
	sim.wave_duration = 120.0
	if not keep_plan:
		sim._plan.clear()
		sim._plan_idx = 0
	_main._sync_phase()
	return sim


func _spawn(sim: Sim, id: StringName, position: Vector2, elite: StringName = &"") -> EnemyState:
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(id)
	spawn.pos = position
	spawn.elite_kind = elite
	sim._materialize(spawn)
	var enemy := sim.enemies[sim.enemies.size() - 1]
	enemy.max_hp = 2000.0
	enemy.hp = enemy.max_hp
	enemy.speed = 18.0
	enemy.damage = 2.0
	return enemy


func _gallery() -> bool:
	var sim := _new_fixture(12, BASE)
	var bodies: Array[EnemyState] = []
	for index in ENEMIES.size():
		var position := Vector2(260.0 + float(index % 3) * 370.0, 230.0 + float(index / 3) * 130.0)
		bodies.append(_spawn(sim, ENEMIES[index], position, ELITES[index] if index < 4 else &""))
	sim._rift_cd = 0.001
	await _wait(18)
	if not await _capture("six_bodies_rift_warning"):
		return false
	# A real damaging contact, not a fabricated anticipation animation.
	sim.player.iframes = 0.0
	bodies[1].pos = sim.player.pos + Vector2(12.0, 0.0)
	await _wait(4)
	if not _require(_contact_uid == bodies[1].uid, "contact action identifies the body that actually hurt the player"):
		return false
	if not await _capture("contact_impact"):
		return false
	bodies[1].pos = Vector2(620.0, 320.0)
	_drive(Vector2.RIGHT * 0.4)
	await _wait(105)
	_release()
	if not await _capture("base_weapons_rift_active"):
		return false
	for enemy in bodies:
		if not enemy.dead:
			sim.damage_enemy(enemy, 1000000.0, Vector2.ZERO, false, -1, Vector2.RIGHT, &"pistol")
		await _wait(4)
		if not await _capture("death_" + String(enemy.def.id)):
			return false
		if enemy == bodies[0] and not _check_render_purity_and_pause():
			return false
		await _wait(14)
	return true


func _second_loadout() -> bool:
	var sim := _new_fixture(10, EVOLVED)
	for index in 4:
		_spawn(sim, &"brute", Vector2(380.0 + float(index) * 175.0, 350.0))
	_drive(Vector2.LEFT * 0.35)
	await _wait(45)
	if not await _capture("evolved_weapon_language"):
		return false
	await _wait(105)
	_release()
	return true


func _copies() -> bool:
	var pistol: Array[StringName] = [&"pistol"]
	var sim := _new_fixture(19, pistol, 8)
	_spawn(sim, &"brute", Vector2(640.0, 160.0))
	await _wait(45)
	if not _require(sim.echoes.size() == 8, "eight actual copies are active") or not await _capture("eight_copies_aged_and_stapled"):
		return false
	sim.player.iframes = 0.0
	var censor := _spawn(sim, &"silencer", sim.player.pos)
	censor.speed = 0.0
	await _wait(5)
	if not _require(sim.echo_silenced > 0.0, "silence comes from real enemy contact") or not await _capture("eight_copies_silenced"):
		return false
	censor.pos = Vector2(1100.0, 150.0)
	await _wait(140)
	if not await _capture("copies_rewinding"):
		return false
	if not _require(sim.collapse_oldest_echo(), "the real collapse action consumes a copy"):
		return false
	await _wait(4)
	if not _require(sim.bank.takes.size() == 7 and sim.echoes.size() == 7, "collapse removes the real bank and actor entry") or not await _capture("copy_collapse"):
		return false
	await _wait(45)
	return true


func _boss() -> bool:
	var loadout: Array[StringName] = [&"pistol", &"longbow"]
	var sim := _new_fixture(20, loadout, 2, true)
	for index in 240:
		if sim.boss != null:
			break
		await process_frame
	if not _require(sim.boss != null, "real final-wave plan materializes the Original"):
		return false
	await _wait(45)
	if not await _capture("boss_original"):
		return false
	sim._boss_silence_cd = 0.001
	await _wait(5)
	if not _require(sim.echo_silenced > 0.0, "Boss roar is driven by actual silence") or not await _capture("boss_roar"):
		return false
	if not _reduced and not _require(_main._view._director.is_boss_roaring(), "actual Boss silence selects its drawn roar"):
		return false
	await _wait(60)
	sim.boss.hp = sim.boss.max_hp * 0.51
	sim.damage_enemy(sim.boss, sim.boss.max_hp * 0.02, Vector2.ZERO, false, -1, Vector2.RIGHT, &"longbow")
	await _wait(5)
	if not _require(sim.boss_phase == 2 and sim.boss_alive_count() == 2, "two actual harmful halves remain live during tear art") or not await _capture("boss_tear"):
		return false
	if not _reduced and not _require(not _main._view._director.tear.is_empty(), "real split starts the non-blocking tear overlay"):
		return false
	await _wait(90)
	if not await _capture("boss_two_copies"):
		return false
	sim.damage_enemy(sim.boss_shards[0], 1000000.0, Vector2.ZERO, false, -1, Vector2.RIGHT, &"rail_spike")
	await _wait(6)
	if not _require(sim.boss_alive_count() == 1, "one actual half remains after the first death") or not await _capture("boss_half_death"):
		return false
	await _wait(90)
	for shard in sim.boss_shards:
		if not shard.dead:
			sim.damage_enemy(shard, 1000000.0, Vector2.ZERO, false, -1, Vector2.LEFT, &"nova_core")
	await _wait(75)
	return _require(sim.phase == Sim.Phase.WON and _main.end_ui.visible, "actual Boss defeat reaches the real result UI") and await _capture("boss_result")


func _player_loss() -> bool:
	var pistol: Array[StringName] = [&"pistol"]
	var sim := _new_fixture(3, pistol)
	sim.player.hp = 1.0
	sim.player.iframes = 0.0
	var attacker := _spawn(sim, &"runner", sim.player.pos)
	attacker.speed = 0.0
	attacker.damage = 4.0
	await _wait(3)
	if not _require(sim.phase == Sim.Phase.LOST and not _main.end_ui.visible, "real contact loss precedes summary while art falls") or not await _capture("player_crumple"):
		return false
	await _wait(20)
	if not await _capture("player_flattening"):
		return false
	await _wait(45)
	if not _require(_main.end_ui.visible and _main._recorded, "the saved terminal run reaches its real result") or not await _capture("player_loss_result"):
		return false
	await _wait(60)
	return true


func _check_render_purity_and_pause() -> bool:
	var sim: Sim = _main.sim
	var view: ArenaView = _main._view
	var state := [sim.rng.state, sim.hazard_rng.state, sim.wave_time, sim.player.pos, sim.player.hp,
		sim.player.cooldowns.duplicate(), sim.kills, sim.player.materials]
	var old_pause: bool = _main.paused
	_main.paused = true
	view.set_paused(true)
	var before: Array = view._director.corpses.duplicate(true)
	view._process(0.2)
	var pause_frozen := before == view._director.corpses
	if not _require(pause_frozen, "ordinary pause freezes live corpse ages"):
		return false
	view.set_paused(false)
	view._process(0.125)
	RenderingServer.force_draw()
	var after := [sim.rng.state, sim.hazard_rng.state, sim.wave_time, sim.player.pos, sim.player.hp,
		sim.player.cooldowns.duplicate(), sim.kills, sim.player.materials]
	_main.paused = old_pause
	_summary["pure_render"] = {"gameplay_and_both_rngs_unchanged": state == after,
		"ordinary_pause_freezes_corpses": pause_frozen}
	return _require(state == after, "rendering and art clocks do not advance gameplay or either RNG")


func _capture(name: String) -> bool:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if not _require(image != null and not image.is_empty(), "real window has pixels for " + name):
		return false
	var path := _dir.path_join(name + ".png")
	if not _require(image.save_png(path) == OK, "capture is writable"):
		return false
	_summary["screenshots"][name] = path
	var sim: Sim = _main.sim
	if sim != null:
		if not _check_threat_geometry(sim):
			return false
		var copies: Array = []
		for actor in sim.echoes:
			var profile := EchoInk.profile(actor, sim, sim.wave_time, _reduced)
			copies.append({"slot": actor.index, "age": actor.take.age, "merged": actor.take.merged,
				"remaining": profile["remaining"], "muted": profile["muted"], "rewinding": profile["rewinding"],
				"expiring": profile["expiring"], "crease_count": profile["crease_count"], "staples": profile["staple_count"]})
		var hazards: Array = []
		for r in sim.rifts:
			hazards.append({"radius": r.radius, "warning": r.is_warning(), "active": r.is_active(),
				"pos": [r.pos.x, r.pos.y]})
		_summary["stages"][name] = {"phase": sim.phase, "wave": sim.wave, "enemies": sim.enemies.size(),
			"copies": copies, "rifts": hazards, "feedback": _main._view.feedback_counts(),
			"weapon_batches": WeaponInk._last_render.duplicate(true),
			"director": _main._view._director.counts()}
	print("battle art state: " + name)
	return true


func _pending_art() -> Array[String]:
	var result: Array[String] = []
	var anchors: Dictionary = {}
	for key: StringName in PresentationAssets.PATHS:
		if not String(key).begins_with("character_") and not String(key).begins_with("enemy_"):
			continue
		var count := PresentationAssets.frame_count(key)
		if count != 8:
			result.append(String(key))
		var pivots: Array = []
		var texture := PresentationAssets.texture(key)
		var image := texture.get_image() if texture != null else null
		var largest_foot_error := 0.0
		for frame in count:
			var point := PresentationAssets.frame_pivot(key, frame)
			pivots.append([point.x, point.y])
			var region := PresentationAssets.frame_region(key, frame)
			var actual_bottom := _imported_bottom(image, region)
			var error := absf(actual_bottom - region.position.y - point.y)
			largest_foot_error = maxf(largest_foot_error, error)
			if not point.is_finite() or actual_bottom < 0.0 or error > 3.0:
				var issue := String(key) + ":foot_anchor"
				if not result.has(issue):
					result.append(issue)
		anchors[key] = {"frames": count, "idle_size": str(PresentationAssets.idle_region(key).size),
			"measured_foot_pivots": pivots, "imported_alpha_foot_max_error_px": largest_foot_error}
	_summary["actor_atlases"] = anchors
	return result


func _imported_bottom(image: Image, region: Rect2) -> float:
	if image == null or image.is_empty() or not region.has_area():
		return -1.0
	var left := maxi(0, int(floor(region.position.x)))
	var right := mini(image.get_width(), int(ceil(region.end.x)))
	var top := maxi(0, int(floor(region.position.y)))
	var bottom := mini(image.get_height(), int(ceil(region.end.y)))
	for y in range(bottom - 1, top - 1, -1):
		for x in range(left, right):
			if image.get_pixel(x, y).a >= 20.0 / 255.0:
				return float(y + 1)
	return -1.0


func _check_threat_geometry(sim: Sim) -> bool:
	for enemy in sim.enemies:
		if enemy.dead:
			continue
		var profile := ThreatInk.profile(enemy, sim.player.pos, sim.wave_time, _reduced)
		if not _require(is_equal_approx(float(profile["death_radius"]), enemy.death_radius_value()),
				"blast illustration uses the actual body's damaging radius"):
			return false
		if not _require(is_equal_approx(float(profile["shield_arc"]), enemy.shield_arc_value()),
				"shield illustration uses the actual blocking angle"):
			return false
	for rift in sim.rifts:
		var profile := ThreatInk.rift_profile(rift, sim.wave_time, _reduced)
		if not _require(is_equal_approx(float(profile["radius"]), rift.radius)
				and bool(profile["warning"]) == rift.is_warning()
				and bool(profile["active"]) == rift.is_active(),
				"rift drawing matches the actual radius and warning/active state"):
			return false
	var link := ThreatInk.boss_link_profile(sim, sim.wave_time, _reduced)
	return _require(not bool(link["dangerous"]), "Boss binding line never claims a damaging barrier")


func _shot(info: ShotInfo) -> void:
	_weapons_seen[String(info.weapon_id)] = true
	if info.source < 0:
		_require(info.actor_token == -1, "player shot uses the reserved player identity")
		return
	var sim: Sim = _main.sim
	if not _require(info.source < sim.echoes.size(), "a firing copy exists at the actual emission boundary"):
		return
	var take: EchoTake = sim.echoes[info.source].take
	if not _require(info.actor_token != 0 and info.actor_token != -1
			and info.actor_token == take.get_instance_id(), "signed copy token is an exact snapshot of its real Take"):
		return
	if not _require(info.source_tint == take.tint(), "copy color is captured before slot order can change"):
		return
	_copy_shot_tokens[str(info.actor_token)] = true
	if not _reduced:
		var key := PresentationAssets.character_key(_main.character_id)
		var pose: int = _main._view._director.echo_pose(key, info.actor_token, 0.0, false, false)
		if pose == 4 or pose == 5:
			_copy_action_tokens[str(info.actor_token)] = true


func _death(info: EnemyDeathInfo) -> void:
	_deaths_seen[String(info.enemy_id)] = true
	(_summary["deaths"] as Array).append(info.to_dict())


func _hurt(info: PlayerHurtInfo) -> void:
	if info.effect == &"contact":
		_contact_uid = info.source_uid


func _drive(direction: Vector2) -> void:
	for pair in [[&"move_left", -direction.x], [&"move_right", direction.x],
		[&"move_up", -direction.y], [&"move_down", direction.y]]:
		if not InputMap.has_action(pair[0]):
			continue
		if float(pair[1]) > 0.0:
			Input.action_press(pair[0], float(pair[1]))
		else:
			Input.action_release(pair[0])


func _release() -> void:
	_drive(Vector2.ZERO)


func _wait(count: int) -> void:
	for frame in count:
		await process_frame


func _write_summary() -> void:
	var file := FileAccess.open(_dir.path_join("summary.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_summary, "\t"))
		file.close()


func _require(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_release()
	if not _dir.is_empty():
		_summary["failure"] = message
		_write_summary()
	printerr("battle art probe: FAILED: " + message)
	quit(1)
