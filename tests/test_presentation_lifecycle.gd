extends RefCounted


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _shot() -> ShotInfo:
	var info := ShotInfo.new()
	info.weapon_id = &"pistol"
	info.origin = Vector2(300.0, 300.0)
	info.direction = Vector2.RIGHT
	return info


func test_show_select_detaches_every_presentation_consumer(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(71, &"looper")
	var old_sim: Sim = main.sim
	main.shop_ui.open(old_sim)
	c.ok(main.shop_ui.sim == old_sim and main.shop_ui.echo_panel._sim == old_sim,
			"shop and echo panel start bound to the run")
	var old_ref: WeakRef = weakref(old_sim)
	var audio_before: int = main.audio.play_count(&"weapon_pistol")
	main.show_select()
	c.eq(main.sim, null, "main releases old simulation")
	c.eq(main._view.sim, null, "arena view releases old simulation")
	c.eq(main.hud.sim, null, "HUD releases old simulation")
	c.eq(main.shop_ui.sim, null, "shop releases old simulation")
	c.eq(main.shop_ui.echo_panel._sim, null, "echo panel releases old simulation")
	c.ok(not bool(main.audio.binding_state()["sim_bound"]), "audio releases old simulation")
	c.ok(not bool(main.audio.binding_state()["shop_bound"]), "audio releases old shop")
	c.eq(main._view.feedback_counts()["muzzles"], 0, "view feedback queues clear on detach")
	c.eq(main._view._paths.size(), 0, "view echo paths clear on detach")
	c.eq(main._view._reveal.size(), 0, "view reveals clear on detach")
	c.eq(main._view._sparks.size(), 0, "view sparks clear on detach")
	c.eq(main._view.position, Vector2.ZERO, "view shake position resets on detach")
	for _i in 3:
		main._view._process(1.0 / 60.0)
	var detached_motion: Dictionary = main._view.motion_stats()
	c.eq(detached_motion["visual_time"], 0.0, "detached frames keep visual time at rest")
	c.eq(detached_motion["amount"], 0.0, "detached frames keep gait at rest")
	c.eq(detached_motion["max_recoil"], 0.0, "detached frames keep recoil at rest")
	old_sim.shot_fired_info.emit(_shot())
	c.eq(main._view.feedback_counts()["muzzles"], 0, "old rich signal cannot reach detached view")
	c.eq(main.audio.play_count(&"weapon_pistol"), audio_before,
			"old rich signal cannot reach detached audio")
	old_sim = null
	c.eq(old_ref.get_ref(), null, "old simulation frees after final local reference releases")
	main.free()


func test_new_run_rebinds_once_after_detach(c: Check) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_root().add_child(main)
	main.new_run(72, &"mirror")
	var info := _shot()
	var audio_before: int = main.audio.play_count(&"weapon_pistol")
	main.sim.shot_fired_info.emit(info)
	c.eq(main._view.feedback_counts()["muzzles"], 1, "new run reaches view exactly once")
	c.eq(main.audio.play_count(&"weapon_pistol"), audio_before + 1,
			"new run reaches audio exactly once")
	c.eq(main._view.character_id, &"mirror", "new run restores selected character identity")
	main.free()
