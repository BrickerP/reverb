extends RefCounted


func _contract(kind: StringName, deposit: int = 6, reward: int = 18, target: int = 0) -> AnomalyContract:
	var c := AnomalyContract.new()
	c.kind = kind
	c.deposit = deposit
	c.reward = reward
	c.target = target
	return c


func _shop_sim(materials: int = 100) -> Sim:
	var s := Sim.new(7)
	s.start_run()
	s.phase = Sim.Phase.SHOP
	s.player.materials = materials
	return s


func test_contract_generation_window(c: Check) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	c.ok(AnomalyContract.make(2, rng) == null, "no contract before wave 3")
	c.ok(AnomalyContract.make(WaveDirector.FINAL_WAVE, rng) == null, "no contract on the boss wave")
	var endless_contract := AnomalyContract.make(WaveDirector.FINAL_WAVE + 1, rng, true)
	c.ok(endless_contract != null, "endless waves keep contracts")
	c.ok(AnomalyContract.make(WaveDirector.FINAL_WAVE + 1, rng, false) == null,
			"non-endless wave 21 has no contract")
	var c10 := AnomalyContract.make(10, rng)
	c.ok(c10 != null and c10.kind in [AnomalyContract.CLEAN, AnomalyContract.CLEAR,
			AnomalyContract.HUNT, AnomalyContract.COLLAPSE],
			"wave 10 can offer all contract kinds")
	var c3 := AnomalyContract.make(3, rng)
	c.ok(c3 != null and c3.kind in [AnomalyContract.CLEAN, AnomalyContract.CLEAR,
			AnomalyContract.COLLAPSE],
			"early waves do not offer the elite hunt")
	for i in 20:
		var no_collapse := AnomalyContract.make(3, rng, false, false)
		c.ok(no_collapse.kind != AnomalyContract.COLLAPSE,
				"contracts can exclude collapse when no echo is available")
	for i in 10:
		c.ok(AnomalyContract.make(3, rng).deposit > 0, "contract has a deposit")
	var s := Sim.new(7)
	s.start_run()
	s.wave = 2
	s.shop.roll(s)
	c.ok(s.shop.contract != null, "the shop after wave 2 offers a wave-3 contract")
	s.wave = 19
	s.shop.roll(s)
	c.ok(s.shop.contract == null, "the shop after wave 19 does not offer a boss-wave contract")


func test_collapse_contract_completes_after_echo_collapse(c: Check) -> void:
	var s := _shop_sim(100)
	var contract := _contract(AnomalyContract.COLLAPSE, 8, 24)
	c.ok(not contract.is_complete(s), "collapse contract starts incomplete")
	s.collapse_used = true
	c.ok(contract.is_complete(s), "collapse contract completes after a collapse")


func test_accept_contract_pays_once_and_blocks_poor(c: Check) -> void:
	var s := _shop_sim(20)
	s.shop.contract = _contract(AnomalyContract.CLEAN)
	c.ok(s.shop.accept_contract(s), "accept succeeds with deposit")
	c.eq(s.player.materials, 14, "deposit is paid")
	c.ok(s.shop.contract.accepted, "contract is marked accepted")
	c.ok(s.active_contract == s.shop.contract, "sim tracks the active contract")
	c.eq(s.contracts_accepted, 1, "accepted contract is counted")
	c.ok(not s.shop.accept_contract(s), "contract cannot be accepted twice")
	c.eq(s.player.materials, 14, "second accept does not charge")
	var poor := _shop_sim(2)
	poor.shop.contract = _contract(AnomalyContract.CLEAR)
	c.ok(not poor.shop.accept_contract(poor), "contract refuses an unaffordable deposit")
	c.eq(poor.player.materials, 2, "failed accept leaves materials")


func test_clean_contract_success_and_failure(c: Check) -> void:
	var s := _shop_sim(100)
	var contract := _contract(AnomalyContract.CLEAN)
	s.active_contract = contract
	s.wave_start_materials = s.player.materials
	var resolved: Array[Dictionary] = []
	s.contract_resolved.connect(func(resolved_contract: AnomalyContract, success: bool, reward: int) -> void:
		resolved.append({"kind": resolved_contract.kind, "success": success, "reward": reward}))
	s._end_wave()
	c.ok(s.last_contract_done, "contract is evaluated at wave end")
	c.ok(s.last_contract_success, "clean contract succeeds without damage")
	c.eq(s.last_contract_reward, contract.reward, "clean contract pays its reward")
	c.eq(s.player.materials, 100 + contract.reward + s.last_interest, "reward lands before interest")
	c.eq(resolved.size(), 1, "contract result signal fires once")
	c.eq(resolved[0]["kind"], AnomalyContract.CLEAN, "signal carries the contract kind")
	c.eq(s.contracts_completed, 1, "completed contract is counted")
	c.ok(s.active_contract == null, "active contract is cleared")

	var failed := _shop_sim(100)
	failed.active_contract = _contract(AnomalyContract.CLEAN)
	failed.wave_start_materials = failed.player.materials
	failed.wave_damage_taken = true
	failed._end_wave()
	c.ok(failed.last_contract_done and not failed.last_contract_success,
			"clean contract fails after damage")
	c.eq(failed.last_contract_reward, 0, "failed contract pays nothing")
	c.eq(failed.contracts_failed, 1, "failed contract is counted")


func test_clear_and_hunt_contracts(c: Check) -> void:
	var clear := _shop_sim(100)
	var clear_contract := _contract(AnomalyContract.CLEAR, 6, 18, 12)
	clear.active_contract = clear_contract
	clear.wave_kills = 12
	clear._end_wave()
	c.ok(clear.last_contract_success, "clear contract checks the kill count")
	c.eq(clear.last_contract_reward, 18, "clear contract pays")
	var hunt := _shop_sim(100)
	hunt.active_contract = _contract(AnomalyContract.HUNT, 8, 24)
	hunt.wave_elite_kills = 1
	hunt._end_wave()
	c.ok(hunt.last_contract_success, "hunt contract checks elite kills")
	c.eq(hunt.last_contract_reward, 24, "hunt contract pays")
