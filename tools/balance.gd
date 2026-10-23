extends SceneTree

# Headless balance probe: plays full runs with the dev bot and prints a summary.
# Usage: godot --headless --path . --script res://tools/balance.gd -- [runs] [first_seed] [noecho]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 6
	var first := int(args[1]) if args.size() > 1 else 1
	var no_echo := args.size() > 2 and args[2] == "noecho"
	var character := StringName(args[3]) if args.size() > 3 else &""
	var style := StringName(args[4]) if args.size() > 4 else &"balanced"
	var wins := 0
	var wave_sum := 0
	var kill_sum := 0
	var interest_sum := 0
	var earned_sum := 0
	var material_sum := 0
	var peak_material_sum := 0
	var upgrade_sum := 0
	var evolution_sum := 0
	for i in runs:
		var r := BotRunner.play(first + i, no_echo, WaveDirector.FINAL_WAVE, character, style)
		wins += 1 if r["won"] else 0
		wave_sum += int(r["wave"])
		kill_sum += int(r["kills"])
		interest_sum += int(r["interest"])
		earned_sum += int(r["earned"])
		material_sum += int(r["materials"])
		peak_material_sum += int(r["max_materials"])
		upgrade_sum += int(r["upgrades"])
		evolution_sum += int(r["evolutions"])
		print("seed %d: %s wave %2d kills %4d weapons %d | step avg %.2fms worst %.2fms | peak enemies %3d projectiles %3d" % [
			r["seed"], "WON " if r["won"] else "died", r["wave"], r["kills"], r["weapons"],
			r["avg_ms"], r["worst_ms"], r["max_enemies"], r["max_projectiles"]])
	print("bot summary%s%s[%s]: %d/%d wins, mean last wave %.1f, mean kills %.0f" % [
		" (echoes off)" if no_echo else "", " [%s]" % character if character != &"" else "", style,
		wins, runs, float(wave_sum) / float(runs), float(kill_sum) / float(runs)])
	print("  economy: mean earned %.1f, interest %.1f, end materials %.1f, peak %.1f" % [
		float(earned_sum) / float(runs), float(interest_sum) / float(runs),
		float(material_sum) / float(runs), float(peak_material_sum) / float(runs)])
	print("  upgrades: %.1f per run, evolutions: %.2f per run" % [
		float(upgrade_sum) / float(runs), float(evolution_sum) / float(runs)])
	quit(0)
