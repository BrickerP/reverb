extends SceneTree

# Fixture. Not a human clear. Places yesterday inside the paradox cross, then
# lets the existing absorb path tear that copy. Records whatever the window shows.

var _cover := "/tmp/reverb-spread/cover.png"


func _initialize() -> void:
	var lang := "zh"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		lang = str(args[0])
	if args.size() > 1:
		_cover = str(args[1])
	OS.set_environment("REVERB_LANG", lang)
	OS.set_environment("REVERB_DEMO", "")
	OS.set_environment("REVERB_SAVE", "/tmp/reverb-spread/save.json")
	OS.set_environment("REVERB_SETTINGS", "/tmp/reverb-spread/settings.json")
	OS.set_environment("REVERB_RUN_LOG", "/tmp/reverb-spread/runs.jsonl")
	OS.set_environment("REVERB_FEEDBACK_LOG", "/tmp/reverb-spread/feedback.jsonl")
	OS.set_environment("REVERB_SUSPEND", "/tmp/reverb-spread/suspend.json")
	Loc.reset_lang()
	call_deferred("_play")


func _play() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.new_run(11, &"looper")
	var sim: Sim = main.sim
	sim._plan.clear()
	sim.pending.clear()
	sim.enemies.clear()
	sim.projectiles.clear()
	var layout := EchoArchive.clip_layout(sim.player.pos)
	sim.player.pos = layout.player
	var take := EchoTake.new()
	take.wave = 0
	take.condition = 80.0
	take.weapons.append(Content.weapon(&"pistol"))
	take.levels.append(0)
	for _i in 8:
		take.samples.append(layout.echo)
	sim.bank.add(take)
	var actor := EchoActor.new(take, 0)
	actor.pos = layout.echo
	sim.echoes.clear()
	sim.echoes.append(actor)
	sim.selected_echo_uid = take.uid
	var boss := EnemyState.new()
	boss.def = Content.enemy(&"paradox")
	boss.uid = 12
	boss.pos = layout.target + Vector2(0.0, -340.0)
	boss.hp = boss.def.hp
	boss.max_hp = boss.hp
	boss.radius = boss.def.radius
	boss.speed = 0.0
	boss.damage = boss.def.damage
	boss.attack_target = layout.target
	boss.brain_state = &"warn"
	boss.brain_time = 1.1
	sim.enemies.append(boss)
	sim.boss = boss
	sim.boss_shards.clear()
	sim.boss_shards.append(boss)
	sim.wave_duration = 30.0
	sim.wave_travel = Sim.FIRST_WAVE_TRAVEL
	# 7 seconds. The warning cross is up for 1.1s, then the copy is spent.
	for frame in 420:
		await process_frame
		if frame == 36:
			var image := root.get_viewport().get_texture().get_image()
			if image != null:
				image.save_png(_cover)
	quit()
