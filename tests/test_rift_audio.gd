extends RefCounted


func test_real_rift_warning_activation_and_hurt_route_once(c: Check) -> void:
	var sim := Sim.new(2001)
	sim.start_run()
	sim.start_wave(12)
	sim._plan.clear()
	sim.pending.clear()
	var audio := GameAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	audio.bind(sim)
	audio.bind(sim)
	sim._rift_cd = 0.001
	sim._step_rifts(0.01)
	c.eq(sim.rifts.size(), 1, "scheduled warning exists")
	c.eq(audio.play_count(&"echo"), 1, "warning routes once despite repeated bind")
	var hp := sim.player.hp
	sim._step_rifts(TemporalRift.TELEGRAPH_TIME + 0.01)
	c.eq(audio.play_count(&"silence"), 1, "activation routes once")
	c.eq(sim.player.hp, hp, "warning/activation has no immediate damage")
	sim.player.pos = sim.rifts[0].pos
	sim._step_rifts(TemporalRift.TICK_TIME + 0.01)
	c.eq(audio.play_count(&"hurt_blast"), 1, "rich rift hit uses one environmental hurt cue")
	c.eq(audio.play_count(&"hurt_contact"), 0, "rift is not reported as contact audio")
	c.eq(audio.play_count(&"hurt"), 0, "legacy hurt signal does not duplicate rich audio")
	c.ok(sim.wave_damage_taken, "rift-only compatibility marker is set")
	audio.set_paused(true)
	sim.rift_activated.emit(sim.rifts[0])
	c.eq(audio.play_count(&"silence"), 1, "paused activation stays silent")
	audio.set_paused(false)
	var other := Sim.new(2002)
	audio.bind(other)
	sim.rift_activated.emit(sim.rifts[0])
	c.eq(audio.play_count(&"silence"), 1, "old simulation is disconnected")
	audio.bind(null)
	other.rift_activated.emit(TemporalRift.new())
	c.eq(audio.play_count(&"silence"), 1, "unbind removes activation route")
	audio.free()
