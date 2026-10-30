class_name EchoWork
extends RefCounted

const MAX_ACTIONS := 6
const MAX_SIGNATURES := 2
const SIGNATURE_INTERVAL := 8.0
const CONDITION_COST := 4.0
const FIELDS := ["time", "kind", "target_id", "pos", "weapon_id", "aim"]
const MACHINE_KINDS := {&"machine_0": &"press", &"machine_1": &"conveyor",
	&"machine_3": &"press", &"machine_4": &"conveyor"}


static func validate_actions(actions: Variant, max_time: float) -> bool:
	if typeof(actions) != TYPE_ARRAY or actions.size() > MAX_ACTIONS \
			or not is_finite(max_time) or max_time < 0.0:
		return false
	var last_time := -1.0
	var last_signature := -SIGNATURE_INTERVAL
	var signature_count := 0
	for action: Variant in actions:
		if typeof(action) != TYPE_DICTIONARY or action.size() != FIELDS.size():
			return false
		for key: Variant in action:
			if typeof(key) != TYPE_STRING or not FIELDS.has(key):
				return false
		if typeof(action.time) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(action.time)) or float(action.time) < last_time \
				or float(action.time) < 0.0 or float(action.time) > max_time \
				or typeof(action.kind) != TYPE_STRING_NAME \
				or typeof(action.target_id) != TYPE_STRING_NAME \
				or typeof(action.weapon_id) != TYPE_STRING_NAME \
				or typeof(action.pos) != TYPE_VECTOR2 or not action.pos.is_finite() \
				or not Sim.ARENA.has_point(action.pos) \
				or typeof(action.aim) != TYPE_VECTOR2 or not action.aim.is_finite():
			return false
		last_time = float(action.time)
		if action.kind == &"signature":
			signature_count += 1
			if signature_count > MAX_SIGNATURES or last_time - last_signature < SIGNATURE_INTERVAL \
					or action.target_id != &"" or Content.weapon(action.weapon_id) == null \
					or action.aim.length_squared() < 0.000001 or action.aim.length_squared() > 1.001:
				return false
			last_signature = last_time
		elif action.kind in [&"press", &"conveyor"]:
			if MACHINE_KINDS.get(action.target_id, &"") != action.kind \
					or action.weapon_id != &"" or action.aim != Vector2.ZERO:
				return false
		else:
			return false
	return true


static func validate_actor(actor: EchoActor) -> bool:
	if actor == null or actor.take == null:
		return false
	return validate_cursor(actor.take.work_actions, actor.take.duration(), actor.t, actor.work_cursor, actor.work_cycle)


static func validate_cursor(actions: Array[Dictionary], duration: float, time: float,
		cursor: int, work_cycle: int) -> bool:
	if not is_finite(time) or time < 0.0 or not is_finite(duration) or duration < 0.0 \
			or cursor < 0 or cursor > actions.size() or work_cycle < 0:
		return false
	if duration <= 0.0:
		return work_cycle == 0 and (cursor == actions.size() or (time == 0.0 and cursor == 0))
	var cycle := int(floor(time / (2.0 * duration)))
	if work_cycle < cycle:
		return false
	var phase := fposmod(time, 2.0 * duration)
	var expected := _cursor_at(actions, phase)
	if work_cycle == cycle and cursor == expected:
		return true
	if time == 0.0 and work_cycle == 0 and cursor == 0:
		return true
	# Looper moves the route clock back, never the consumed work high-water mark.
	# A future cursor is legal only within that actual two-second rewind; it
	# cannot be behind due work or point arbitrarily far into unplayed cycles.
	if work_cycle == cycle and cursor < expected:
		return false
	var consumed_time := float(work_cycle) * 2.0 * duration
	if cursor > 0:
		consumed_time += float(actions[cursor - 1].time)
	return consumed_time <= time + CharacterSkills.REWIND_SECONDS + 0.000000001


# The route clock is already advanced by EchoSystem. Only the first forward
# crossing in each ping-pong cycle can perform work. Consuming failures and
# skipped cycles here prevents a seal, resume or long frame from queuing output.
static func step(sim: Sim, actor: EchoActor, previous_time: float, delta: float) -> void:
	if sim == null or actor == null or actor.take == null or delta <= 0.0 \
			or not is_finite(delta) or not is_finite(previous_time) or previous_time < 0.0:
		return
	var end_time := previous_time + delta
	if not is_finite(end_time):
		return
	var actions := actor.take.work_actions
	var duration := actor.take.duration()
	if duration <= 0.0:
		while actor.work_cursor < actions.size() and actor.work_cursor < MAX_ACTIONS:
			var action: Dictionary = actions[actor.work_cursor]
			actor.work_cursor += 1
			_perform(sim, actor, action)
		return
	var period := 2.0 * duration
	var previous_cycle := int(floor(previous_time / period))
	var cycle := maxi(previous_cycle, actor.work_cycle)
	var end_cycle := int(floor(end_time / period))
	var cursor := actor.work_cursor if actor.work_cycle == cycle else _cursor_before(actions, fposmod(previous_time, period))
	var attempts := 0
	var finished := actions.is_empty()
	while not finished and cycle <= end_cycle and attempts < MAX_ACTIONS:
		while cursor < actions.size() and attempts < MAX_ACTIONS:
			var action: Dictionary = actions[cursor]
			var event_time := float(cycle) * period + float(action.time)
			if event_time > end_time:
				finished = true
				break
			cursor += 1
			if event_time < previous_time:
				continue
			attempts += 1
			_perform(sim, actor, action)
		cycle += 1
		cursor = 0
	# Discard any events beyond this tick's budget, including whole missed cycles.
	if end_cycle > actor.work_cycle:
		actor.work_cycle = end_cycle
		actor.work_cursor = _cursor_at(actions, fposmod(end_time, period))
	elif end_cycle == actor.work_cycle:
		actor.work_cursor = maxi(actor.work_cursor, _cursor_at(actions, fposmod(end_time, period)))


static func _cursor_at(actions: Array[Dictionary], phase: float) -> int:
	var cursor := 0
	while cursor < actions.size() and float(actions[cursor].time) <= phase:
		cursor += 1
	return cursor


static func _cursor_before(actions: Array[Dictionary], phase: float) -> int:
	var cursor := 0
	while cursor < actions.size() and float(actions[cursor].time) < phase:
		cursor += 1
	return cursor


static func _perform(sim: Sim, actor: EchoActor, action: Dictionary) -> void:
	var info := {"uid": actor.take.uid, "kind": action.kind, "pos": actor.pos,
		"target_pos": action.pos, "success": false, "reason": &"unavailable"}
	if actor.take.condition < CONDITION_COST:
		info.reason = &"condition"
	elif sim.echo_silenced > 0.0:
		info.reason = &"muted"
	elif EnemyBrain.echo_is_sealed(sim, actor.pos):
		info.reason = &"sealed"
	else:
		var status: Dictionary
		if action.kind == &"signature":
			status = sim.replay_signature_status(actor, action)
		else:
			status = Expedition.replay_work_status(sim, actor, action)
		info.target_pos = status.get("target_pos", action.pos)
		info.reason = status.get("reason", &"unavailable")
		if info.reason == &"ready":
			info.success = sim.replay_signature(actor, action) if action.kind == &"signature" \
					else Expedition.replay_work(sim, actor, action)
			info.reason = &"performed" if info.success else &"unavailable"
			if info.success:
				actor.take.condition = maxf(0.0, actor.take.condition - CONDITION_COST)
	sim.echo_work_performed.emit(info)
