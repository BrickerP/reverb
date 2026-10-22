extends SceneTree
# Headless timing probe for Sim.step.
# 1. Bot runs, each played twice. Replays are deterministic, so a step that is slow in both runs comes
#    from the code, while one that is slow in a single run is machine noise. The per-step minimum drops noise.
# 2. Crowd stress (see Crowd): hundreds of unkillable enemies and a piercing loadout on the player and four echoes.
# Usage: godot --headless --path . --script res://tools/perf.gd -- [runs] [first_seed]

const DT := 1.0 / 60.0
const CROWDS: Array[int] = [100, 200, 300]
const WARMUP_STEPS := 420
const MEASURED_STEPS := 600
const SLOWEST_SHOWN := 5
const KINDS: Array[String] = ["mid-wave", "wave end", "death"]

var _hits := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 6
	var first := int(args[1]) if args.size() > 1 else 1
	_bot_runs(runs, first)
	print("crowd stress (%d warm-up + %d measured steps, player + 4 echoes with 6 piercing weapons each)" % [
			WARMUP_STEPS, MEASURED_STEPS])
	for chase in [false, true]:
		for n in CROWDS:
			_crowd(n, chase)
	quit()


func _bot_runs(runs: int, first: int) -> void:
	var raw := PackedInt32Array()
	var denoised := PackedInt32Array()
	var slow: Array[Dictionary] = []
	for i in runs:
		var seed_value := first + i
		var a := _trace(seed_value)
		var b := _trace(seed_value)
		var ua: PackedInt32Array = a["us"]
		var ub: PackedInt32Array = b["us"]
		if ua.size() != ub.size() or a["kills"] != b["kills"]:
			printerr("NON-DETERMINISTIC replay for seed %d (%d vs %d steps)" % [seed_value, ua.size(), ub.size()])
			continue
		var best := PackedInt32Array()
		best.resize(ua.size())
		for k in ua.size():
			best[k] = mini(ua[k], ub[k])
		raw.append_array(ua)
		raw.append_array(ub)
		denoised.append_array(best)
		var picked: Array[int] = []
		for _n in 3:
			var at := -1
			for k in best.size():
				if (at < 0 or best[k] > best[at]) and not picked.has(k):
					at = k
			picked.append(at)
			slow.append({
				"seed": seed_value, "step": at, "us": best[at], "a": ua[at], "b": ub[at],
				"wave": (a["waves"] as PackedInt32Array)[at],
				"enemies": (a["enemies"] as PackedInt32Array)[at],
				"projectiles": (a["projectiles"] as PackedInt32Array)[at],
				"kind": KINDS[(a["ends"] as PackedByteArray)[at]],
			})
	print("bot runs: %d seeds, each replayed twice, %d steps timed" % [runs, raw.size()])
	_report("raw", raw)
	_report("denoised", denoised)
	slow.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["us"] > y["us"])
	print("  slowest denoised steps:")
	for s in slow.slice(0, SLOWEST_SHOWN):
		print("    seed %d wave %2d step %5d: %.2f ms (runs: %.2f / %.2f), %d enemies, %d projectiles, %s" % [
				s["seed"], s["wave"], s["step"], _ms(s["us"]), _ms(s["a"]), _ms(s["b"]),
				s["enemies"], s["projectiles"], s["kind"]])


func _trace(seed_value: int) -> Dictionary:
	var sim := Sim.new(seed_value)
	var bot := Bot.new()
	var us := PackedInt32Array()
	var waves := PackedInt32Array()
	var enemies := PackedInt32Array()
	var projectiles := PackedInt32Array()
	var ends := PackedByteArray()
	sim.start_run()
	while sim.phase == Sim.Phase.WAVE or sim.phase == Sim.Phase.SHOP:
		if sim.phase == Sim.Phase.SHOP:
			bot.shop(sim)
			sim.start_next_wave()
			continue
		var dir := bot.move_dir(sim)
		enemies.append(sim.enemies.size())
		projectiles.append(sim.projectiles.size())
		var t0 := Time.get_ticks_usec()
		sim.step(DT, dir)
		us.append(Time.get_ticks_usec() - t0)
		waves.append(sim.wave)
		ends.append(0 if sim.phase == Sim.Phase.WAVE else (2 if sim.phase == Sim.Phase.LOST else 1))
	return {"us": us, "waves": waves, "enemies": enemies, "projectiles": projectiles, "ends": ends,
			"kills": sim.kills}


func _crowd(count: int, chase: bool) -> void:
	var sim := Crowd.build(count, chase)
	sim.enemy_hit.connect(_on_hit)
	var us := PackedInt32Array()
	var peak_enemies := 0
	var peak_projectiles := 0
	_hits = 0
	for i in WARMUP_STEPS + MEASURED_STEPS:
		if i == WARMUP_STEPS:
			_hits = 0
		var t0 := Time.get_ticks_usec()
		sim.step(DT, Vector2.ZERO)
		if i >= WARMUP_STEPS:
			us.append(Time.get_ticks_usec() - t0)
			peak_enemies = maxi(peak_enemies, sim.enemies.size())
			peak_projectiles = maxi(peak_projectiles, sim.projectiles.size())
	var sorted := us.duplicate()
	sorted.sort()
	var total := 0
	for v in us:
		total += v
	print("  %3d enemies %-9s avg %.2f  p99 %.2f  max %.2f ms | peak %d enemies, %d projectiles, %d hits/step" % [
			count, "chasing" if chase else "standing", _ms(total) / float(us.size()), _pct(sorted, 0.99),
			_ms(sorted[sorted.size() - 1]), peak_enemies, peak_projectiles, roundi(float(_hits) / float(MEASURED_STEPS))])


func _on_hit(_pos: Vector2, _amount: float, _crit: bool, _source: int) -> void:
	_hits += 1


func _report(label: String, values: PackedInt32Array) -> void:
	var sorted := values.duplicate()
	sorted.sort()
	print("  %-9s p50 %.3f  p99 %.3f  p99.9 %.3f  max %.3f ms" % [
			label, _pct(sorted, 0.5), _pct(sorted, 0.99), _pct(sorted, 0.999), _ms(sorted[sorted.size() - 1])])


func _pct(sorted: PackedInt32Array, q: float) -> float:
	return _ms(sorted[mini(sorted.size() - 1, int(q * float(sorted.size())))])


func _ms(us: int) -> float:
	return float(us) / 1000.0
