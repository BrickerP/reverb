extends SceneTree

# Headless endgame probe. Usage:
# godot --headless --path . --script res://tools/endless_matrix.gd -- \
#   [runs] [first_seed] [target_wave] [boss|endless] [character] [style] [ascension]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 6
	var first := int(args[1]) if args.size() > 1 else 1
	var target := int(args[2]) if args.size() > 2 else 30
	var mode := StringName(args[3]) if args.size() > 3 else &"endless"
	var character := StringName(args[4]) if args.size() > 4 else &""
	var style := StringName(args[5]) if args.size() > 5 else &"balanced"
	var ascension := int(args[6]) if args.size() > 6 else 0
	var boss_rush := mode == &"boss"
	var reached := 0
	var wave_sum := 0
	var kill_sum := 0
	var material_sum := 0
	var peak_material_sum := 0
	for i in runs:
		var r := BotRunner.play(first + i, false, WaveDirector.FINAL_WAVE, character, style,
				ascension, target, boss_rush)
		reached += 1 if r["target_reached"] else 0
		wave_sum += int(r["wave"])
		kill_sum += int(r["kills"])
		material_sum += int(r["materials"])
		peak_material_sum += int(r["max_materials"])
		print("seed %d: %s wave %2d kills %4d | step avg %.2fms worst %.2fms | peak enemies %3d" % [
			r["seed"], "REACHED" if r["target_reached"] else "died",
			r["wave"], r["kills"], r["avg_ms"], r["worst_ms"], r["max_enemies"]])
	print("endgame summary %s[%s] A%d target %d: %d/%d reached, mean wave %.1f, mean kills %.0f" % [
		mode, character if character != &"" else &"all", ascension, target,
		reached, runs, float(wave_sum) / float(runs), float(kill_sum) / float(runs)])
	print("  economy: end materials %.1f, peak %.1f" % [
		float(material_sum) / float(runs), float(peak_material_sum) / float(runs)])
	quit(0)
