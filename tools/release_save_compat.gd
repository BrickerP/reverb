extends SceneTree
# Copy this same probe into each immutable public archive for write, then run
# read in 0.18.2. Wrap commands with tools/checked.sh; never relax decoder checks.
# -- --mode=write|read --output=<absolute directory>

const DT := 1.0 / 60.0
const SOURCE_VERSIONS := ["0.17.0", "0.18.0"]
const READER_VERSION := "0.18.2"
const PAYLOAD_FILE := "compat-payload.json"
const DEADLINE_MSEC := 30000

var _mode := ""
var _output := ""
var _failed := false
var _started := Time.get_ticks_msec()
var _held_sims: Array[Sim] = []
var _sim_references: Array[WeakRef] = []
var _result: Dictionary = {"success": false, "schema": 4, "scenarios": [], "diagnostics": []}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _require(_mode in ["write", "read"] and _output.is_absolute_path(),
			"provide --mode=write|read and an absolute --output directory"):
		return
	if not _require(DirAccess.make_dir_recursive_absolute(_output) == OK, "output directory is writable"):
		return
	# No Main/Meta/Settings object is constructed. These overrides also prevent
	# any helper from touching an existing profile or legacy player-data folder.
	for key: String in ["REVERB_SAVE", "REVERB_SETTINGS", "REVERB_RUN_LOG", "REVERB_FEEDBACK_LOG", "REVERB_SUSPEND"]:
		OS.set_environment(key, _output.path_join(key.to_lower() + ".json"))
	_result["mode"] = _mode
	_result["probe_sha256"] = FileAccess.get_sha256("res://tools/release_save_compat.gd")
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if not _failed and Time.get_ticks_msec() - _started > DEADLINE_MSEC:
		_fail("deadline exceeded")
	return false


func _run() -> void:
	if not _require(RunSnapshot.VERSION == 4, "release compatibility uses the existing Snapshot v4 decoder"):
		return
	var accepted := _write_payload() if _mode == "write" else _read_payload()
	if accepted and not _failed:
		# Release producer/reader locals before checking RefCounted lifetimes.
		_finish.call_deferred()


func _write_payload() -> bool:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var commit := OS.get_environment("REVERB_STRESS_COMMIT").strip_edges()
	if not _require(version in SOURCE_VERSIONS, "writer must actually run public project version 0.17.0 or 0.18.0") \
			or not _require(_commit_valid(commit), "writer needs its full REVERB_STRESS_COMMIT"):
		return false
	if not _require(not FileAccess.file_exists(_output.path_join(PAYLOAD_FILE)), "writer output must be fresh"):
		return false
	var sim := Sim.new(20261031)
	_hold(sim)
	Content.character(&"looper").apply(sim)
	# Existing equipment and extra existing health items keep this deterministic
	# scripted fixture safe. It is not a normal-budget or human campaign claim.
	for _item in 8:
		sim.player.add_item(Content.item(&"iron_heart"))
	sim.player.add_weapon(Content.weapon(&"smg"))
	sim.player.add_weapon(Content.weapon(&"repair_kit"))
	sim.start_run()
	for frame in 2400:
		if sim.phase != Sim.Phase.WAVE:
			break
		sim.step(DT, Vector2.from_angle(float(frame) * 0.015))
	if not _require(sim.phase == Sim.Phase.SHOP and sim.bank.takes.size() == 1,
			"real first encounter finishes and records its actual route/loadout"):
		return false
	var discarded := sim.shop.discard_echo(sim, sim.bank.takes[0])
	if not _require(discarded.ok and sim.shop.can_undo(), "real free discard creates a restorable shop Undo"):
		return false
	var shop := _scenario("shop", sim)
	if shop.is_empty():
		return false
	if not _require(sim.shop.undo(sim).ok and sim.bank.takes.size() == 1,
			"real Undo restores the recorded copy before departure"):
		return false
	sim.start_next_wave()
	for _frame in 120:
		sim.step(DT, Vector2.RIGHT * 0.1)
	if not _require(sim.phase == Sim.Phase.WAVE and sim.echoes.size() == 1
			and not sim.support_units.is_empty(), "second encounter has real Echo playback and finite support"):
		return false
	var wave := _scenario("wave", sim)
	if wave.is_empty():
		return false
	var payload := {"source_version": version, "game_commit": commit, "schema": RunSnapshot.VERSION,
		"probe_sha256": _result["probe_sha256"], "scenarios": [shop, wave],
		"fixture": "real deterministic Sim progression; existing extra health items and starter equipment; no player files"}
	if not _save_json(_output.path_join(PAYLOAD_FILE), payload):
		return false
	_result["source_version"] = version
	_result["game_commit"] = commit
	_result["scenarios"] = ["shop", "wave"]
	_result["payload_sha256"] = FileAccess.get_sha256(_output.path_join(PAYLOAD_FILE))
	return true


func _scenario(name: String, sim: Sim) -> Dictionary:
	var snapshot := RunSnapshot.capture(sim)
	if not _require(not snapshot.is_empty(), "%s captures a complete version-4 object graph" % name):
		return {}
	var verified := RunSnapshot.restore(snapshot)
	if not _require(verified != null and RunSnapshot.capture(verified) == snapshot,
			"%s is already valid under the original writer's strict decoder" % name):
		return {}
	verified = null
	# Preserve the original bytes as a JSON string. Outer JSON numeric parsing
	# cannot change graph-reference number spellings before digest verification.
	var encoded := JSON.stringify(snapshot, "", true, true)
	return {"name": name, "snapshot_json": encoded, "snapshot_sha256": encoded.sha256_text(),
		"rng_seed": str(sim.rng.seed), "rng_state": str(sim.rng.state),
		"hazard_rng_seed": str(sim.hazard_rng.seed), "hazard_rng_state": str(sim.hazard_rng.state),
		"state": _describe(sim)}


func _describe(sim: Sim) -> Dictionary:
	var weapons: Array[String] = []
	for weapon: WeaponDef in sim.player.weapons:
		weapons.append(String(weapon.id))
	return {"wave": sim.wave, "phase": int(sim.phase), "weapons": weapons,
		"weapon_levels": sim.player.weapon_levels.duplicate(), "echo_bank": sim.bank.takes.size(),
		"live_echoes": sim.echoes.size(), "supports": sim.support_units.size(), "undo_available": sim.shop.can_undo()}


func _read_payload() -> bool:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var commit := OS.get_environment("REVERB_STRESS_COMMIT").strip_edges()
	if not _require(version == READER_VERSION, "reader must actually run project version 0.18.2") \
			or not _require(_commit_valid(commit), "reader needs its full REVERB_STRESS_COMMIT"):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_output.path_join(PAYLOAD_FILE)))
	if not _require(parsed is Dictionary, "read the old process's JSON payload"):
		return false
	var payload: Dictionary = parsed
	if not _require(payload.get("source_version") in SOURCE_VERSIONS and payload.get("schema") == 4
			and _commit_valid(str(payload.get("game_commit", "")))
			and payload.get("probe_sha256") == _result["probe_sha256"],
			"old version, schema, full source commit and identical probe provenance match"):
		return false
	var scenarios: Variant = payload.get("scenarios")
	if not _require(scenarios is Array and scenarios.size() == 2, "payload contains exactly SHOP and WAVE"):
		return false
	var names: Array[String] = []
	var details: Array[Dictionary] = []
	for value: Variant in scenarios:
		if not _require(value is Dictionary, "scenario is a value record"):
			return false
		var row: Dictionary = value
		var name := str(row.get("name", ""))
		var encoded := str(row.get("snapshot_json", ""))
		if not _require(name in ["shop", "wave"] and not names.has(name)
				and not encoded.is_empty() and encoded.sha256_text() == row.get("snapshot_sha256"),
				"scenario identity and original snapshot byte digest match"):
			return false
		var original: Variant = JSON.parse_string(encoded)
		if not _require(original is Dictionary, "old snapshot text parses without repair"):
			return false
		var restored := RunSnapshot.restore(original)
		if not _require(restored != null, "%s passes the unmodified current strict decoder: %s" % [name, RunSnapshot.last_error]):
			return false
		_hold(restored)
		var captured := RunSnapshot.capture(restored)
		var captured_text: String = JSON.stringify(captured, "", true, true)
		var graph_equal: bool = captured == original
		# Godot parses JSON numbers as floats. Compare both graphs in the same
		# file domain; do not rewrite the payload or mutate the restored model.
		# Actual game integers/floats remain protected by v4's i/f string tags.
		var captured_json: Variant = JSON.parse_string(captured_text)
		var graph_json_domain_equal: bool = captured_json is Dictionary and captured_json == original
		var canonical_equal: bool = captured_text == encoded
		var canonical_sha_equal: bool = captured_text.sha256_text() == encoded.sha256_text()
		var exact: bool = graph_json_domain_equal and canonical_equal and canonical_sha_equal
		var rng_exact: bool = str(restored.rng.seed) == row.get("rng_seed") and str(restored.rng.state) == row.get("rng_state")
		var hazard_exact: bool = str(restored.hazard_rng.seed) == row.get("hazard_rng_seed") \
			and str(restored.hazard_rng.state) == row.get("hazard_rng_state")
		var state: Dictionary = _describe(restored)
		var state_raw_equal: bool = state == row.get("state")
		var state_json: Variant = JSON.parse_string(JSON.stringify(state, "", true, true))
		var state_equal: bool = state_json is Dictionary and state_json == row.get("state")
		var snapshot_differences: Array[Dictionary] = []
		var state_differences: Array[Dictionary] = []
		_diff(original, captured, "$.snapshot", snapshot_differences)
		_diff(row.get("state"), state, "$.state", state_differences)
		var diagnostic := {"scenario": name, "graph_equal": graph_equal,
			"graph_json_domain_equal": graph_json_domain_equal,
			"comparison_domain": "same parsed JSON file domain; original payload and restored game state are unchanged",
			"canonical_json_bytes_equal": canonical_equal, "canonical_snapshot_sha256_equal": canonical_sha_equal,
			"rng_equal": rng_exact, "hazard_rng_equal": hazard_exact,
			"state_raw_equal": state_raw_equal, "state_equal": state_equal,
			"old_snapshot_sha256": encoded.sha256_text(), "captured_snapshot_sha256": captured_text.sha256_text(),
			"raw_snapshot_differences": snapshot_differences, "raw_state_differences": state_differences,
			"old_snapshot_file": name + "-old-snapshot.json",
			"captured_snapshot_file": name + "-captured-snapshot.json"}
		(_result["diagnostics"] as Array).append(diagnostic)
		print("release save compatibility diagnostics: " + JSON.stringify(diagnostic))
		if not _save_text(_output.path_join(name + "-old-snapshot.json"), encoded) \
				or not _save_text(_output.path_join(name + "-captured-snapshot.json"), captured_text) \
				or not _save_text(_output.path_join(name + "-old-state.json"), JSON.stringify(row.get("state"), "  ", true, true)) \
				or not _save_json(_output.path_join(name + "-captured-state.json"), state):
			return false
		if not _require(exact and rng_exact and hazard_exact and state_equal,
				"%s restores the entire graph, original bytes and both RNGs exactly" % name):
			return false
		var resumed := false
		if name == "shop":
			var copies_before := restored.bank.takes.size()
			resumed = restored.phase == Sim.Phase.SHOP and restored.shop.can_undo() \
				and restored.shop.undo(restored).ok and restored.bank.takes.size() > copies_before
		else:
			var time_before := restored.wave_time
			resumed = restored.phase == Sim.Phase.WAVE and not restored.echoes.is_empty() \
				and not restored.support_units.is_empty()
			if resumed:
				restored.step(DT, Vector2.RIGHT * 0.1)
				resumed = restored.phase == Sim.Phase.WAVE and restored.wave_time > time_before
		if not _require(resumed, "%s continues through an actual current gameplay action after exact verification" % name):
			return false
		names.append(name)
		details.append({"name": name, "snapshot_sha256": row["snapshot_sha256"],
			"full_snapshot_equal": exact, "graph_json_domain_equal": graph_json_domain_equal,
			"canonical_json_bytes_equal": canonical_equal, "canonical_snapshot_sha256_equal": canonical_sha_equal,
			"state_json_domain_equal": state_equal, "rng_preserved": rng_exact, "hazard_rng_preserved": hazard_exact,
			"resumed_action": "undo" if name == "shop" else "step", "resumed": resumed,
			"source_state": row["state"], "after_action": _describe(restored)})
	_result["source_version"] = payload["source_version"]
	_result["reader_version"] = version
	_result["source_game_commit"] = payload["game_commit"]
	_result["reader_game_commit"] = commit
	_result["payload_sha256"] = FileAccess.get_sha256(_output.path_join(PAYLOAD_FILE))
	_result["scenarios"] = names
	_result["details"] = details
	return true


func _diff(expected: Variant, actual: Variant, location: String, differences: Array[Dictionary]) -> void:
	if differences.size() >= 20:
		return
	if typeof(expected) != typeof(actual):
		_difference(location, expected, actual, differences)
		return
	if expected is Dictionary:
		var expected_map: Dictionary = expected
		var actual_map: Dictionary = actual
		for key: Variant in expected_map:
			if differences.size() >= 20:
				return
			var next: String = location + "." + str(key)
			if not actual_map.has(key):
				_difference(next, expected_map[key], null, differences, "actual key missing")
			else:
				_diff(expected_map[key], actual_map[key], next, differences)
		for key: Variant in actual_map:
			if differences.size() >= 20:
				return
			if not expected_map.has(key):
				_difference(location + "." + str(key), null, actual_map[key], differences, "unexpected actual key")
	elif expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			_difference(location + ".length", expected_array.size(), actual_array.size(), differences)
		for index in mini(expected_array.size(), actual_array.size()):
			if differences.size() >= 20:
				return
			_diff(expected_array[index], actual_array[index], "%s[%d]" % [location, index], differences)
	elif expected != actual:
		_difference(location, expected, actual, differences)


func _difference(location: String, expected: Variant, actual: Variant,
		differences: Array[Dictionary], reason: String = "value or type mismatch") -> void:
	if differences.size() >= 20:
		return
	differences.append({"path": location, "reason": reason,
		"expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual)),
		"expected": _preview(expected), "actual": _preview(actual)})


func _preview(value: Variant) -> String:
	var shown: String = JSON.stringify(value, "", true, true)
	return shown.left(240) + "..." if shown.length() > 240 else shown


func _save_text(filename: String, value: String) -> bool:
	var file: FileAccess = FileAccess.open(filename, FileAccess.WRITE)
	if not _require(file != null, "open isolated exact snapshot text output"):
		return false
	file.store_string(value)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return _require(error == OK, "flush exact snapshot text output")


func _hold(sim: Sim) -> void:
	_held_sims.append(sim)
	_sim_references.append(weakref(sim))


func _commit_valid(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-fA-F]{40}$")
	return pattern.search(value) != null


func _finish() -> void:
	_held_sims.clear()
	await process_frame
	await process_frame
	for reference: WeakRef in _sim_references:
		if not _require(reference.get_ref() == null, "producer/reader Sim reference was released before exit"):
			return
	_result["teardown"] = {"sims_released": true, "native_frames_waited": 2, "deferred_exit": true}
	_result["success"] = true
	var filename := "writer-result.json" if _mode == "write" else "result.json"
	if _save_json(_output.path_join(filename), _result):
		_quit_success.call_deferred()


func _quit_success() -> void:
	print("release save compatibility: OK " + JSON.stringify(_result))
	quit()


func _save_json(filename: String, value: Dictionary) -> bool:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if not _require(file != null, "open isolated compatibility output"):
		return false
	file.store_string(JSON.stringify(value, "  ", true, true) + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	return _require(error == OK, "flush compatibility output")


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_result["success"] = false
	_result["failure"] = message
	printerr("release save compatibility FAILED: " + message)
	if not _output.is_empty() and _output.is_absolute_path():
		var file := FileAccess.open(_output.path_join("result.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_result, "  ", true, true) + "\n")
			file.close()
	quit(1)
