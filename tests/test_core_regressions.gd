extends RefCounted


func test_existing_progress_unlocks_new_roles_without_another_run(c: Check) -> void:
	var path := "user://test_existing_roles.json"
	for wave in [4, 5, 11, 12, 20]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"best_wave": wave, "wins": 1,
			"unlocked": {"looper": true, "solo": true, "mirror": true, "conductor": true}}))
		file.close()
		var meta := Meta.new(path)
		c.eq(meta.is_unlocked(&"mender"), wave >= Content.character(&"mender").unlock_wave, "loaded progress grants earned Mender")
		c.eq(meta.is_unlocked(&"overloader"), wave >= Content.character(&"overloader").unlock_wave, "loaded progress grants earned Overloader")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_low_power_retirement_gets_the_whole_role_multiplier(c: Check) -> void:
	var sim := Sim.new(901)
	var take := EchoTake.new()
	take.weapons.append(Content.weapon(&"smg"))
	take.levels.append(0)
	sim.player.stats.values[Stats.ECHO_POWER] = 0.001
	var base := EchoSystem.skill_profile(take, sim)
	sim.retirement_mult = 1.5
	var enhanced := EchoSystem.skill_profile(take, sim)
	c.near(float(base.damage), 12.0, 0.0001, "weak copy uses the minimum skill power")
	c.near(float(enhanced.damage), 18.0, 0.0001, "Overloader scales the actual minimum too")


func test_mastery_pin_is_included_in_combo_guidance(c: Check) -> void:
	var weapons: Array[WeaponDef] = []
	for _i in 4:
		weapons.append(Content.weapon(&"rifle"))
	weapons.append(Content.weapon(&"stamp"))
	var profiles := Combat.combo_profile(weapons)
	c.ok(bool(profiles[0].ready), "actual mastery pins satisfy the press combo")


func test_optional_supply_expires_and_is_not_automatically_awarded(c: Check) -> void:
	var sim := Sim.new(902)
	sim.start_run()
	sim.start_wave(3)
	sim._plan.clear()
	sim.wave_time = sim.wave_duration * 0.45
	sim._step_supply()
	c.eq(sim.pickups.size(), 1, "eligible wave spawns a real optional supply")
	var supply := sim.pickups[0]
	c.eq(supply.kind, &"supply", "bonus is distinct from ordinary kill scrap")
	var materials := sim.player.materials
	sim._end_wave()
	c.eq(sim.player.materials, materials + Sim.interest_for(materials), "unclaimed supply is not a wave-end gift")
	sim.start_wave(6)
	sim._plan.clear()
	sim.wave_time = sim.wave_duration * 0.45
	sim._step_supply()
	supply = sim.pickups[0]
	supply.life = 0.01
	sim._update_pickups(0.02)
	c.eq(supply.value, 0, "expired optional reward cannot be claimed")
