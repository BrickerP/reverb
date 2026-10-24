extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _boss_sim() -> Sim:
	var sim := Sim.new(737)
	sim.start_run()
	sim.wave = WaveDirector.FINAL_WAVE
	var pending := PendingSpawn.new()
	pending.def = Content.enemy(&"paradox")
	pending.pos = Sim.ARENA.get_center() + Vector2(180.0, 0.0)
	sim._materialize(pending)
	return sim


func _split(sim: Sim) -> void:
	sim.boss.hp = sim.boss.max_hp * Sim.BOSS_PHASE2_HP_RATIO + 1.0
	sim.damage_enemy(sim.boss, 2.0, Vector2.ZERO, false, -1)


func test_original_body_first_death_keeps_combined_hud_and_survivor_identity(c: Check) -> void:
	var sim := _boss_sim()
	_split(sim)
	var original := sim.boss_shards[0]
	var survivor := sim.boss_shards[1]
	var view := ArenaView.new()
	_root().add_child(view)
	view.bind(sim)
	sim.damage_enemy(original, 1000000.0, Vector2.ZERO, false, -1)
	var hud_state := Hud.boss_presentation_state(sim)
	c.eq(hud_state["pips"], [false, true],
			"HUD pips preserve original-dead and survivor-alive identity")
	c.ok(float(hud_state["health_ratio"]) > 0.0 and not bool(hud_state["defeated"]),
			"combined health remains visible and fight is not prematurely defeated")
	c.ok(not view._victory, "first body death never starts the final victory beat")
	var phase_profile := ArenaPainter.boss_phase_profile(sim, false)
	c.eq(phase_profile["survivor"], survivor, "survivor presentation follows the living body")
	c.ok(bool(phase_profile["survivor_visible"]) and not bool(phase_profile["link_visible"]),
			"one survivor replaces the two-body link with an enrage tell")
	view.free()


func test_silence_and_final_victory_follow_the_living_then_last_defeated_body(c: Check) -> void:
	var sim := _boss_sim()
	_split(sim)
	var original := sim.boss_shards[0]
	var survivor := sim.boss_shards[1]
	var view := ArenaView.new()
	_root().add_child(view)
	view.bind(sim)
	sim.damage_enemy(original, 1000000.0, Vector2.ZERO, false, -1)
	view._sparks.clear()
	sim._boss_silence_cd = 0.0
	sim._boss_step(0.01)
	c.ok(not view._sparks.is_empty(), "living boss silence emits an essential arena tell")
	var silence: Spark = view._sparks[view._sparks.size() - 1]
	c.eq(silence.pos, survivor.pos, "silence tell follows the living body")
	c.near(silence.radius, survivor.radius, 0.001, "silence tell uses the living body's radius")
	var final_pos := survivor.pos
	sim.damage_enemy(survivor, 1000000.0, Vector2.ZERO, false, -1)
	c.eq(view._boss_death_origin, final_pos, "last defeated body becomes final beat origin")
	view.play_victory_beat(sim)
	c.eq(view._victory_origin, final_pos, "victory beat uses the last defeated body")
	view.free()


func test_reduced_split_is_stable_and_drops_new_decorative_motion(c: Check) -> void:
	var sim := _boss_sim()
	_split(sim)
	var standard_a := ArenaPainter.boss_phase_profile(sim, false)
	sim.wave_time += 0.2
	var standard_b := ArenaPainter.boss_phase_profile(sim, false)
	var reduced_a := ArenaPainter.boss_phase_profile(sim, true)
	sim.wave_time += 3.0
	var reduced_b := ArenaPainter.boss_phase_profile(sim, true)
	c.ok(not is_equal_approx(float(standard_a["link_alpha"]), float(standard_b["link_alpha"])),
			"standard two-body link retains its pulse")
	c.near(float(reduced_a["link_alpha"]), float(reduced_b["link_alpha"]), 0.0001,
			"reduced two-body link stays stable")
	c.ok(float(reduced_a["link_node_radius"]) == 0.0 and not bool(reduced_a["detail_rotates"]),
			"reduced split removes the pulsing node and rotating detail")
	c.ok(bool(reduced_a["link_visible"]), "reduced split retains the essential two-body link")
	var view := ArenaView.new()
	_root().add_child(view)
	view.set_reduced_effects(true)
	view.bind(sim)
	view._sparks.clear()
	sim.boss_phase_changed.emit(2)
	sim.boss_shard_spawned.emit(sim.boss_shards[1])
	sim.boss_enraged.emit(sim.boss_shards[0])
	c.eq(view._sparks.size(), 0, "reduced split and enrage add no decorative sparks")
	c.eq(view._shake, 0.0, "reduced split and enrage add no shake")
	view.play_victory_beat(sim)
	c.eq(view._sparks.size(), 0, "reduced final beat relies on essential painter geometry")
	view.free()


func test_pause_and_rebind_clear_boss_presentation_state(c: Check) -> void:
	var first := _boss_sim()
	_split(first)
	var view := ArenaView.new()
	_root().add_child(view)
	view.bind(first)
	view._on_boss_shard_defeated(first.boss_shards[0], 1)
	view.set_paused(true)
	var visual_time := view._visual_time
	view._process(0.5)
	c.eq(view._visual_time, visual_time, "paused boss presentation does not advance")
	var second := Sim.new(9)
	second.start_run()
	view.bind(second)
	c.eq(view._boss_death_origin, Vector2.ZERO, "rebind clears prior boss death origin")
	c.eq(view._victory_origin, Vector2.ZERO, "rebind clears prior victory origin")
	c.eq(view._sparks.size(), 0, "rebind clears boss transition sparks")
	c.ok(not view._victory and not view._paused, "rebind restores idle lifecycle state")
	view.unbind()
	c.eq(view._boss_death_origin, Vector2.ZERO, "unbind keeps boss state cleared")
	view.free()


func test_phase_two_title_fits_the_hud_width_in_english(c: Check) -> void:
	var previous := Loc.lang
	Loc.lang = "en"
	var state := Hud.boss_presentation_state(_phase_two_fixture())
	var width := UiTheme.font().get_string_size(Loc.t(str(state["title_key"])),
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, int(state["title_size"])).x
	c.ok(width <= 400.0, "English phase-two title fits the HUD title width")
	Loc.lang = previous


func _phase_two_fixture() -> Sim:
	var sim := _boss_sim()
	_split(sim)
	return sim
