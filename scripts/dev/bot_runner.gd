class_name BotRunner
extends RefCounted

const DT := 1.0 / 60.0


static func play(seed_value: int, no_echo: bool = false, max_wave: int = WaveDirector.FINAL_WAVE,
		character_id: StringName = &"", style: StringName = &"balanced") -> Dictionary:
	var sim := Sim.new(seed_value)
	var bot := Bot.new(style)
	if character_id != &"":
		var def := Content.character(character_id)
		if def != null:
			def.apply(sim)
	if no_echo:
		sim.player.stats.values[Stats.ECHO_SLOTS] = -100.0
	sim.start_run()
	var steps := 0
	var worst_us := 0
	var total_us := 0
	var max_enemies := 0
	var max_projectiles := 0
	var total_earned := 0
	var total_interest := 0
	var max_materials := 0
	while sim.phase == Sim.Phase.WAVE or sim.phase == Sim.Phase.SHOP:
		if sim.phase == Sim.Phase.SHOP:
			total_earned += sim.last_wave_earned
			total_interest += sim.last_interest
			max_materials = maxi(max_materials, sim.player.materials)
			if sim.wave >= max_wave:
				break
			bot.shop(sim)
			sim.start_next_wave()
			continue
		var t0 := Time.get_ticks_usec()
		sim.step(DT, bot.move_dir(sim))
		var us := Time.get_ticks_usec() - t0
		total_us += us
		worst_us = maxi(worst_us, us)
		steps += 1
		max_enemies = maxi(max_enemies, sim.enemies.size())
		max_projectiles = maxi(max_projectiles, sim.projectiles.size())
	return {
		"seed": seed_value,
		"won": sim.phase == Sim.Phase.WON,
		"wave": sim.wave,
		"kills": sim.kills,
		"weapons": sim.player.weapons.size(),
		"steps": steps,
		"avg_ms": float(total_us) / 1000.0 / float(maxi(1, steps)),
		"worst_ms": float(worst_us) / 1000.0,
		"max_enemies": max_enemies,
		"max_projectiles": max_projectiles,
		"earned": total_earned,
		"interest": total_interest,
		"max_materials": max_materials,
		"materials": sim.player.materials,
		"upgrades": bot.upgrades,
		"evolutions": bot.evolutions,
	}
