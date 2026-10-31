class_name InteractionInk
extends RefCounted

# Short-lived receipts contain values only. A retired copy or destroyed helper
# can leave a folded drawing without retaining, reviving or mutating its model.
const MAX_MARKS := 32
const MAX_DRAW := 12
const MAX_RETIRED := 4
const MAX_TARGETS := 12
const SKILL_TIME := 0.84
const RESCUE_TIME := 0.9
const SKILL_IDS: Array[StringName] = [&"looper", &"solo", &"mirror", &"conductor", &"mender", &"overloader"]
const PAPER := Color("e5d8b8")
const INK := Color("292720")
const FRIEND := Color("4d6045")
const WARN := Color("a33d32")
const SUPPORT_KINDS: Array[StringName] = [&"spawn", &"attack", &"repair", &"produce", &"retrieve", &"damage", &"destroy", &"expire"]

var _marks: Array[Dictionary] = []


func reset() -> void:
	_marks.clear()


func has_actor_actions() -> bool:
	for mark: Dictionary in _marks:
		if mark["family"] in [&"interaction", &"skill"]:
			return true
	return false


func has_rescues() -> bool:
	for mark: Dictionary in _marks:
		if mark["family"] == &"rescue":
			return true
	return false


func counts() -> Dictionary:
	var result := {"active": _marks.size(), "support": 0, "world": 0, "retirements": 0, "rescues": 0}
	for mark: Dictionary in _marks:
		if mark["family"] == &"support":
			result["support"] += 1
		elif mark["family"] == &"retirement":
			result["retirements"] += 1
		else:
			result["world"] += 1
			if mark["family"] == &"rescue":
				result["rescues"] += 1
	return result


func consume_support(info: Dictionary) -> void:
	var kind := StringName(info.get("kind", &""))
	var unit_kind := StringName(info.get("unit_kind", &""))
	var pos: Vector2 = info.get("pos", Vector2.INF)
	if kind not in SUPPORT_KINDS or not SupportSystem.PROFILES.has(unit_kind) \
			or int(info.get("uid", 0)) <= 0 or not pos.is_finite():
		return
	var mark := {"family": &"support", "kind": kind, "unit_kind": unit_kind,
		"uid": int(info["uid"]), "pos": pos, "actor_token": int(info.get("actor_token", -1)),
		"weapon_id": StringName(info.get("weapon_id", &"")),
		"hp": _number(info.get("hp", 0.0)), "max_hp": _number(info.get("max_hp", 0.0)),
		"life": _number(info.get("life", 0.0)), "charges": maxi(0, int(info.get("charges", 0))),
		"amount": _number(info.get("amount", 0.0)),
		"target_pos": _position(info.get("target_pos", pos), pos),
		"targets": _targets(info.get("targets", []))}
	# Repeated fire replaces its own small pose; terminal receipts survive after
	# the unit leaves the live array, and take precedence over a last damage tick.
	_replace(&"support", int(info["uid"]), kind, kind in [&"destroy", &"expire"])
	_push(mark, 0.66 if kind in [&"destroy", &"expire"] else 0.5)


func consume_world(info: Dictionary) -> void:
	var kind := StringName(info.get("kind", &""))
	var pos: Vector2 = info.get("pos", Vector2.INF)
	if not pos.is_finite():
		return
	var mark := {"kind": kind, "pos": pos,
		"target_pos": _position(info.get("target_pos", pos), pos),
		"from_pos": _position(info.get("from_pos", pos), pos),
		"subject": StringName(info.get("subject", &"")),
		"target_id": StringName(info.get("target_id", info.get("subject", &""))),
		"target_kind": StringName(info.get("target_kind", &"")),
		"target_uid": int(info.get("target_uid", 0)),
		"target_type": StringName(info.get("target_type", &"")),
		"ok": bool(info.get("ok", false)), "reason": StringName(info.get("reason", &"")),
		"contact_allowed": bool(info.get("contact_allowed", true)),
		"actor_token": int(info.get("actor_token", -1)),
		"ability": StringName(info.get("ability", &"")),
		"selected_uid": int(info.get("selected_uid", 0)),
		"anchors": _anchors(info.get("anchors", []))}
	match kind:
		&"interaction_result":
			mark["family"] = &"interaction"
			_replace(&"interaction", int(mark["actor_token"]))
		&"character_skill", &"character_relay":
			if not bool(mark["ok"]) or mark["ability"] not in SKILL_IDS:
				return
			mark["family"] = &"skill"
			_replace(&"skill", int(mark["actor_token"]))
		&"companion_signed":
			# This event is emitted only after the roster/support transaction commits.
			if not bool(mark["ok"]) or int(info.get("target_uid", 0)) <= 0:
				return
			mark["family"] = &"recruit"
		&"worker_saved":
			if mark["subject"] == &"" or not bool(info.get("ok", true)) \
					or not info.get("from_pos") is Vector2 or not info.get("target_pos") is Vector2 \
					or not (info["from_pos"] as Vector2).is_finite() or not (info["target_pos"] as Vector2).is_finite():
				return
			mark["family"] = &"rescue"
		_:
			return
	_push(mark, RESCUE_TIME if mark["family"] == &"rescue" else (SKILL_TIME if mark["family"] == &"skill" else 0.72))


# EchoWork already reports the committed operation once. Do not consume the
# machine_operated world event too, or replay input would grow two hands.
func consume_echo_work(info: Dictionary) -> void:
	var kind := StringName(info.get("kind", &""))
	var uid := int(info.get("uid", 0))
	if uid <= 0 or kind not in [&"press", &"conveyor"]:
		return
	consume_world({"kind": &"interaction_result", "actor_token": uid,
		"pos": info.get("pos", Vector2.INF), "target_pos": info.get("target_pos", Vector2.INF),
		"target_kind": &"bureau_switch" if info.get("target_id", &"") == BureauEvents.SWITCH_ID else kind,
		"subject": info.get("target_id", &""), "target_id": info.get("target_id", &""), "ok": bool(info.get("success", false)),
		"reason": info.get("reason", &"unavailable"),
		"contact_allowed": info.get("reason", &"unavailable") not in [&"distant", &"muted", &"sealed", &"condition", &"unavailable"]})


func consume_retirement(info: EchoRetirementInfo, body_key: StringName) -> void:
	if info == null or info.uid <= 0 or not info.pos.is_finite():
		return
	var exhausted := info.exhausted or info.reason == EchoRetirementInfo.EXHAUSTED
	var mark := {"family": &"retirement", "uid": info.uid, "pos": info.pos,
		"kind": info.kind, "weapon_id": info.weapon_id, "condition": clampf(info.condition, 0.0, 100.0),
		"exhausted": exhausted, "body_key": body_key, "tint": info.tint}
	_replace(&"retirement", info.uid)
	_push(mark, 0.62 if exhausted else 0.8)


func step(delta: float, paused: bool = false) -> void:
	if paused or not is_finite(delta) or delta <= 0.0:
		return
	for index in range(_marks.size() - 1, -1, -1):
		_marks[index]["age"] = float(_marks[index]["age"]) + delta
		if float(_marks[index]["age"]) >= float(_marks[index]["duration"]):
			_marks.remove_at(index)


func profiles(view: Rect2, reduced: bool = false, sim: Sim = null) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var retired := 0
	var visible_area := view.grow(76.0)
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Dictionary = _marks[index]
		var p := mark.duplicate(true)
		if sim != null and sim.player.hp <= 0.0 and (p["family"] == &"skill" or (p["family"] == &"interaction" and int(p["actor_token"]) == -1)):
			continue
		if p["family"] == &"interaction":
			var token := int(p.get("actor_token", -1))
			if sim != null and token > 0 and not _has_echo(sim, token):
				continue
			p["pos"] = _target_position({"uid": token, "pos": p["pos"],
				"target_type": &"player" if token == -1 else &"echo"}, sim)
		var pos: Vector2 = p["pos"]
		var target: Vector2 = p.get("target_pos", pos)
		var visible := visible_area.has_point(pos) or visible_area.has_point(target)
		if p["family"] == &"rescue":
			visible = visible or visible_area.has_point(p["from_pos"])
		for anchor: Dictionary in p.get("anchors", []):
			visible = visible or visible_area.has_point(anchor["from_pos"]) or visible_area.has_point(anchor["to_pos"])
		for affected: Dictionary in p.get("targets", []):
			affected["pos"] = _target_position(affected, sim)
			affected["visible"] = visible_area.has_point(affected["pos"])
			visible = visible or bool(affected["visible"])
		if not visible:
			continue
		if mark["family"] == &"retirement":
			if retired >= MAX_RETIRED:
				continue
			retired += 1
		var progress := clampf(float(mark["age"]) / float(mark["duration"]), 0.0, 1.0)
		p["progress"] = 1.0 if reduced else progress
		p["alpha"] = clampf((1.0 - progress) / 0.24, 0.0, 1.0)
		p["reduced"] = reduced
		output.append(p)
		if output.size() >= MAX_DRAW:
			break
	output.reverse()
	return output


func support_pose(uid: int, reduced: bool = false) -> Dictionary:
	var result := {"scale": Vector2.ONE, "offset": Vector2.ZERO}
	if reduced:
		return result
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Dictionary = _marks[index]
		if mark["family"] != &"support" or int(mark["uid"]) != uid:
			continue
		var left := 1.0 - clampf(float(mark["age"]) / 0.32, 0.0, 1.0)
		var impulse := left * left
		match mark["kind"]:
			&"spawn": result["scale"] = Vector2(1.0 + impulse * 0.2, 1.0 - impulse * 0.7)
			&"attack": result["scale"] = Vector2(1.0 + impulse * 0.12, 1.0 - impulse * 0.1)
			&"damage": result["scale"] = Vector2(1.0 - impulse * 0.18, 1.0 + impulse * 0.12)
			&"repair", &"produce": result["offset"] = Vector2(0, -impulse * 3.0)
		return result
	return result


# This changes only the authored sheet at the real collision position. No body
# is interpolated between simulation endpoints and no pose can grant protection.
func actor_pose(token: int, reduced: bool = false) -> Dictionary:
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Dictionary = _marks[index]
		var progress := clampf(float(mark["age"]) / float(mark["duration"]), 0.0, 1.0)
		if mark["family"] == &"interaction" and int(mark["actor_token"]) == token:
			if not _can_reach(mark):
				continue
			var pose := skill_pose(&"mender", progress, reduced)
			pose["action"] = &"interaction"
			if not bool(mark["ok"]):
				pose["frame"] = 4
			pose["lean"] = 0.0 if reduced else signf(((mark["target_pos"] as Vector2) - (mark["pos"] as Vector2)).x) * sin(progress * PI) * 0.08
			pose["scale"] = Vector2.ONE if reduced else Vector2(1.0 + sin(progress * PI) * 0.04, 1.0 - sin(progress * PI) * 0.07)
			pose["offset"] = Vector2.ZERO
			return pose
		if mark["family"] != &"skill":
			continue
		var affected := token == -1
		if token > 0:
			if mark["ability"] in [&"mirror", &"conductor"]:
				affected = int(mark["selected_uid"]) == token
			elif mark["ability"] == &"looper":
				for anchor: Dictionary in mark["anchors"]:
					affected = affected or int(anchor["uid"]) == token
		if affected:
			var pose := skill_pose(mark["ability"], progress, reduced)
			var delta := (mark["target_pos"] as Vector2) - (mark["pos"] as Vector2)
			if token > 0:
				for anchor: Dictionary in mark["anchors"]:
					if int(anchor["uid"]) == token:
						delta = (anchor["to_pos"] as Vector2) - (anchor["from_pos"] as Vector2)
			if delta.x < 0.0:
				pose["lean"] = -float(pose["lean"])
			return pose
	return {"active": false, "action": &"", "scale": Vector2.ONE,
		"offset": Vector2.ZERO, "lean": 0.0, "frame": -1, "progress": 1.0, "stage": &"settled"}


static func skill_pose(ability: StringName, progress: float, reduced: bool = false) -> Dictionary:
	var valid := ability in SKILL_IDS and is_finite(progress) and progress >= 0.0 and progress < 1.0
	var pose := {"active": valid, "action": ability, "scale": Vector2.ONE,
		"offset": Vector2.ZERO, "lean": 0.0, "frame": -1, "progress": 1.0, "stage": &"settled"}
	if not valid:
		return pose
	var t := clampf(progress, 0.0, 1.0)
	pose["progress"] = t
	pose["stage"] = &"prepare" if t < 0.22 else (&"contact" if t < 0.62 else &"release")
	pose["frame"] = 4 if t < 0.22 else (5 if t < 0.72 else 0)
	if reduced:
		pose["stage"] = &"contact"
		pose["frame"] = 5
		return pose
	# A single preparation/contact/release envelope, never a looping shake.
	var load_weight := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.22, 0.48, t))
	var stroke := smoothstep(0.18, 0.42, t) * (1.0 - smoothstep(0.6, 1.0, t))
	match ability:
		&"looper":
			pose["scale"] = Vector2(1.0 - stroke * 0.42, 1.0 + load_weight * 0.11)
			pose["lean"] = -load_weight * 0.14
		&"solo":
			pose["scale"] = Vector2(1.0 + stroke * 0.22, 1.0 - stroke * 0.38)
			pose["lean"] = stroke * 0.21
		&"mirror":
			pose["scale"] = Vector2(1.0 - stroke * 0.62, 1.0 + stroke * 0.04)
			pose["lean"] = load_weight * 0.12 - stroke * 0.12
		&"conductor":
			pose["scale"] = Vector2(1.0 + stroke * 0.08, 1.0 + load_weight * 0.12 - stroke * 0.06)
			pose["lean"] = -load_weight * 0.13 + stroke * 0.09
		&"mender":
			pose["scale"] = Vector2(1.0 + load_weight * 0.13, 1.0 - load_weight * 0.24 - stroke * 0.08)
		&"overloader":
			pose["scale"] = Vector2(1.0 + stroke * 0.2, 1.0 + load_weight * 0.16 - stroke * 0.28)
			pose["lean"] = load_weight * 0.1
	return pose


func worker_pose(id: StringName, reduced: bool = false) -> Dictionary:
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Dictionary = _marks[index]
		if mark["family"] == &"rescue" and mark["subject"] == id:
			return rescue_pose(mark, float(mark["age"]) / float(mark["duration"]), reduced)
	return {"safe_visible": true, "safe_scale": Vector2.ONE, "departure_alpha": 0.0}


static func rescue_pose(info: Dictionary, progress: float, reduced: bool = false) -> Dictionary:
	var source := _position(info.get("from_pos", Vector2.INF), Vector2.ZERO)
	var target := _position(info.get("target_pos", Vector2.INF), source)
	var t := clampf(progress, 0.0, 1.0) if is_finite(progress) else 1.0
	var departure := minf(1.0, t / 0.62)
	# The contour travels only its first short step. It is empty charcoal, not
	# another living worker drawn through walls or across the whole depot.
	var step := (target - source).limit_length(42.0)
	var settle := smoothstep(0.58, 1.0, t)
	return {"source": source, "target": target, "progress": t,
		"departure_pos": source + step * departure,
		"departure_alpha": 0.0 if reduced else (1.0 - smoothstep(0.2, 0.62, t)) * 0.45,
		"safe_visible": reduced or t >= 0.62,
		"safe_scale": Vector2.ONE if reduced else Vector2(1.0 + (1.0 - settle) * 0.08, 0.78 + settle * 0.22)}


static func _has_echo(sim: Sim, uid: int) -> bool:
	for actor: EchoActor in sim.echoes:
		if actor != null and actor.take != null and actor.take.uid == uid:
			return true
	return false


static func _can_reach(info: Dictionary) -> bool:
	return bool(info.get("contact_allowed", true)) and info.get("target_kind", &"") != &"" and info.get("reason", &"") not in [
		&"distant", &"no_target", &"muted", &"sealed", &"condition", &"phase"]


func draw(ci: CanvasItem, view: Rect2, reduced: bool = false, sim: Sim = null) -> void:
	if ci == null:
		return
	for p: Dictionary in profiles(view, reduced, sim):
		match p["family"]:
			&"support": _draw_support(ci, p)
			&"retirement": _draw_retirement(ci, p)
			&"interaction": _draw_interaction(ci, p)
			&"skill": _draw_skill(ci, p, sim)
			&"recruit": _draw_recruit(ci, p)
			&"rescue": _draw_rescue(ci, p)


func _push(mark: Dictionary, duration: float) -> void:
	mark["age"] = 0.0
	mark["duration"] = duration
	_marks.append(mark)
	while _marks.size() > MAX_MARKS:
		_marks.pop_front()


func _replace(family: StringName, uid: int, kind: StringName = &"", terminal: bool = false) -> void:
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Dictionary = _marks[index]
		var identity := int(mark.get("uid", mark.get("actor_token", 0)))
		if mark["family"] == family and identity == uid:
			var committed_result: bool = mark.get("kind") in [&"repair", &"produce", &"retrieve"]
			if (terminal and not committed_result) or (not terminal and (kind == &"" or mark.get("kind") == kind)):
				_marks.remove_at(index)


static func _number(value: Variant) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0.0
	var number := float(value)
	return number if is_finite(number) else 0.0


static func _position(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 and (value as Vector2).is_finite() else fallback


static func _targets(values: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not values is Array:
		return output
	for raw: Variant in values:
		if not raw is Dictionary or output.size() >= MAX_TARGETS:
			continue
		var pos: Vector2 = raw.get("pos", Vector2.INF)
		var amount := _number(raw.get("amount", 0.0))
		if not pos.is_finite() or amount <= 0.0:
			continue
		output.append({"uid": int(raw.get("uid", 0)), "target_type": StringName(raw.get("target_type", &"")),
			"pos": pos, "amount": amount, "before": _number(raw.get("before", 0.0)), "after": _number(raw.get("after", 0.0))})
	return output


static func _target_position(target: Dictionary, sim: Sim) -> Vector2:
	var captured: Vector2 = target["pos"]
	if sim == null:
		return captured
	var uid := int(target["uid"])
	match target["target_type"]:
		&"player":
			if uid == -1 and sim.player.pos.is_finite():
				return sim.player.pos
		&"echo":
			for actor: EchoActor in sim.echoes:
				if actor != null and actor.take != null and actor.take.uid == uid and actor.pos.is_finite():
					return actor.pos
		&"support":
			for unit: Dictionary in sim.support_units:
				if int(unit["uid"]) == uid and (unit["pos"] as Vector2).is_finite():
					return unit["pos"]
	# Removal does not erase a committed result. Keep its captured position for
	# the short terminal receipt, never an object or a new lookup identity.
	return captured


static func _anchors(values: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not values is Array:
		return output
	for raw: Variant in values:
		if not raw is Dictionary or output.size() >= Sim.MAX_ECHO_CAPACITY:
			continue
		var origin: Vector2 = raw.get("from_pos", Vector2.INF)
		var target: Vector2 = raw.get("to_pos", Vector2.INF)
		if not origin.is_finite() or not target.is_finite() or int(raw.get("uid", 0)) <= 0:
			continue
		output.append({"uid": int(raw["uid"]), "from_pos": origin, "to_pos": target})
	return output


static func _draw_support(ci: CanvasItem, p: Dictionary) -> void:
	var pos: Vector2 = p["pos"]
	var progress := float(p["progress"])
	var alpha := float(p["alpha"])
	var ink := Color(INK, alpha)
	match p["kind"]:
		&"destroy", &"expire":
			var kind: StringName = p["unit_kind"]
			var key := PresentationAssets.support_key(kind)
			var quiet: bool = p["kind"] == &"expire"
			var scale := Vector2(1.0 + progress * 0.12, maxf(0.08, 1.0 - progress * 0.88))
			var extent := Vector2(70, 66) if SupportSystem.COMPANIONS.has(kind) else Vector2(44, 48)
			_draw_paper(ci, key, pos + Vector2(0, 11), extent, scale, alpha * (0.55 if quiet else 0.85))
			if not quiet:
				for side: float in [-1.0, 1.0]:
					ci.draw_line(pos + Vector2(side * 7, -12), pos + Vector2(side * (12 + progress * 6), -6), ink, 1.5, true)
		&"repair":
			for target: Dictionary in p["targets"]:
				if bool(target.get("visible", true)):
					_patch(ci, target["pos"] + Vector2(-8, -5), progress, alpha, true)
		&"produce", &"retrieve":
			var to: Vector2 = p["target_pos"]
			var origin: Vector2 = to if p["kind"] == &"retrieve" else pos
			var destination: Vector2 = pos if p["kind"] == &"retrieve" else to
			var at := origin.lerp(destination, 1.0 if bool(p["reduced"]) else 1.0 - pow(1.0 - progress, 3.0))
			var sheet := Rect2(at + Vector2(-5, -16), Vector2(10, 12))
			ci.draw_rect(sheet, Color(PAPER, alpha))
			ci.draw_rect(sheet, Color(FRIEND, alpha), false, 1.5)
			ci.draw_line(sheet.position + Vector2(3, 4), sheet.end - Vector2(2, 3), ink, 1.0, true)
		&"attack":
			var direction := ((p["target_pos"] as Vector2) - pos).normalized()
			if direction != Vector2.ZERO:
				var normal := Vector2(-direction.y, direction.x)
				var at := pos + direction * 19 + Vector2(0, -7)
				ci.draw_multiline(PackedVector2Array([at - direction * 4 + normal * 4, at, at, at - direction * 4 - normal * 4]), ink, 1.6, true)
		&"damage":
			ci.draw_polyline(PackedVector2Array([pos + Vector2(-8, -24), pos + Vector2(0, -18), pos + Vector2(-3, -12), pos + Vector2(7, -7)]), ink, 1.8, true)


static func _draw_interaction(ci: CanvasItem, p: Dictionary) -> void:
	var progress := float(p["progress"])
	var alpha := float(p["alpha"])
	var pose := interaction_pose(p, progress, bool(p["reduced"]))
	if not bool(pose["visible"]):
		return
	var origin: Vector2 = pose["source"]
	var shoulder: Vector2 = (pose["shoulder"] as Vector2) - origin
	var elbow: Vector2 = (pose["elbow"] as Vector2) - origin
	var hand: Vector2 = (pose["hand"] as Vector2) - origin
	var grip: Vector2 = (pose["grip"] as Vector2) - origin
	var pivot: Vector2 = (pose["pivot"] as Vector2) - origin
	ci.draw_set_transform(origin)
	if p["target_kind"] in [&"press", &"conveyor", &"recycler", &"bureau_switch"]:
		# A narrow folded control rod belongs to the real service pad. Its end is
		# the same grip held by the paper hand, even at the legal112px reach.
		var rod_direction := (grip - pivot).normalized()
		var rod_normal := Vector2(-rod_direction.y, rod_direction.x)
		var hinge := pivot.lerp(grip, 0.52) + rod_normal * 3.0
		var rod := PackedVector2Array([pivot, hinge, grip])
		ci.draw_polyline(rod, Color(PAPER, alpha), 7.0, true)
		ci.draw_polyline(rod, Color(INK, alpha), 2.4, true)
		ci.draw_line(hinge - rod_normal * 4, hinge + rod_normal * 4, Color(INK, alpha), 1.2, true)
		ci.draw_circle(pivot, 4.0, Color(PAPER, alpha), true, -1, true)
		ci.draw_arc(pivot, 4.0, 0, TAU, 12, Color(INK, alpha), 1.8, true)
		ci.draw_line(grip - rod_normal * 5, grip + rod_normal * 5, Color(INK, alpha), 3.2, true)
	# A small coat-paper strip gives the arm a silhouette, rather than a long
	# explanatory arrow. Local vertices keep tiny folds safe at world offsets.
	var reach := (hand - shoulder).normalized()
	var normal := Vector2(-reach.y, reach.x) * 2.5
	var sleeve := PackedVector2Array([shoulder + normal, elbow + normal, hand + normal * 0.65,
		hand - normal * 0.65, elbow - normal, shoulder - normal])
	ci.draw_colored_polygon(sleeve, Color(PAPER, alpha))
	sleeve.append(sleeve[0])
	ci.draw_polyline(sleeve, Color(INK, alpha), 1.6, true)
	ci.draw_line(elbow - normal, elbow + normal, Color(INK, alpha), 1.0, true)
	ci.draw_circle(hand, 3.6, Color(PAPER, alpha), true, -1, true)
	ci.draw_arc(hand, 3.6, 0, TAU, 12, Color(INK, alpha), 1.5, true)
	ci.draw_line(hand + Vector2(0, -2), hand + Vector2(3, 0), Color(INK, alpha), 1.2, true)
	if not bool(pose["ok"]):
		var at := grip + Vector2(6, -5)
		ci.draw_multiline(PackedVector2Array([at + Vector2(-3, -3), at + Vector2(3, 3), at + Vector2(-3, 3), at + Vector2(3, -3)]), Color(WARN, alpha), 1.5, true)
	ci.draw_set_transform(Vector2.ZERO)
	if p["target_kind"] == &"repair" and bool(pose["ok"]):
		# Coincident repair pads hold the patch beside the reaching hand. The
		# persistent repaired-machine patch is drawn by RecyclingDepot itself.
		_patch(ci, pose["grip"] + Vector2(5, 5), progress, alpha, true)


static func interaction_pose(info: Dictionary, progress: float, reduced: bool = false) -> Dictionary:
	var source: Vector2 = info.get("pos", Vector2.INF)
	var target: Vector2 = info.get("target_pos", Vector2.INF)
	if not _can_reach(info) or not source.is_finite() or not target.is_finite() or not is_finite(progress):
		return {"visible": false}
	var t := clampf(progress, 0.0, 1.0)
	var direction := (target - source).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var shoulder := source + Vector2(9.0 if absf(direction.x) < 0.15 else direction.x * 9.0, -6.0)
	var resting_grip := shoulder + direction * 24.0 + Vector2(0, 5)
	if source.distance_squared_to(target) < 28.0 * 28.0:
		resting_grip = target + Vector2(20, 10)
	var grasp := minf(1.0, t / 0.18)
	if t > 0.82:
		grasp = maxf(0.0, (1.0 - t) / 0.18)
	var pressure := smoothstep(0.16, 0.43, t) * (1.0 - smoothstep(0.57, 0.82, t))
	if reduced:
		grasp = 1.0
		pressure = 1.0
	var accepted := bool(info.get("ok", false))
	var travel := pressure * (12.0 if accepted else -2.0)
	var grip := resting_grip + Vector2(0, travel)
	var rest_hand := shoulder + direction * 8.0 + Vector2(0, 5)
	var hand := rest_hand.lerp(grip, grasp)
	var reach := (hand - shoulder).normalized()
	var elbow := shoulder.lerp(hand, 0.5) + Vector2(-reach.y, reach.x) * 5.0
	return {"visible": true, "source": source, "target": target, "shoulder": shoulder, "elbow": elbow,
		"hand": hand, "pivot": target, "grip": grip, "resting_grip": resting_grip,
		"contact": grasp >= 0.999, "working_travel": travel, "ok": accepted}


static func _patch(ci: CanvasItem, pos: Vector2, progress: float, alpha: float, recipient: bool = false) -> void:
	# Living recipients keep their face/eyes free. The small patch lands on a
	# coat/shoulder and compresses locally; a machine keeps its larger old patch.
	var width := 16.0 if recipient else 18.0
	var height := 10.0 if recipient else 12.0
	var contact := minf(1.0, progress * 4.0) if recipient else progress
	var fall := pow(1.0 - contact, 2.0) * (4.0 if recipient else 12.0)
	var pressure := sin(minf(1.0, progress / 0.45) * PI) if recipient else 0.0
	var patch := Rect2(pos + Vector2(-width * 0.5, -height * 0.5 - fall), Vector2(width, height * (1.0 - pressure * 0.18)))
	ci.draw_rect(patch, Color(PAPER, alpha))
	ci.draw_rect(patch, Color(FRIEND, alpha), false, 1.5)
	for side: float in [-1.0, 1.0]:
		var x: float = pos.x + side * (width * 0.28 + (1.0 - progress) * 2.0)
		var top := patch.position.y
		ci.draw_polyline(PackedVector2Array([Vector2(x, top - 3), Vector2(x, top + 2), Vector2(x + side * 2, top + 2)]), Color(INK, alpha), 1.8, true)
	ci.draw_line(pos + Vector2(-3, -1 - fall), pos + Vector2(4, -1 - fall), Color(INK, alpha), 1.2, true)
	if pressure > 0.0:
		ci.draw_line(patch.position + Vector2(2, -2 - pressure * 2), Vector2(patch.end.x - 2, patch.position.y - 2 - pressure * 2), Color(INK, alpha), 2.0, true)


static func _draw_retirement(ci: CanvasItem, p: Dictionary) -> void:
	var pos: Vector2 = p["pos"]
	var quiet := bool(p["exhausted"])
	var progress := float(p["progress"])
	var alpha := float(p["alpha"]) * (0.55 if quiet else 0.85)
	var shape := EchoInk.retirement_pose(StringName(p["kind"]), progress, quiet)
	var offset: Vector2 = shape["offset"]
	_draw_paper(ci, p["body_key"], pos + Vector2(0, 13) + offset, Vector2(40, 52), shape["scale"], alpha, EchoInk.identity_color(p["tint"]))
	if not quiet:
		for line: PackedVector2Array in EchoInk.retirement_lines(StringName(p["kind"]), pos, progress):
			ci.draw_polyline(line, Color(INK, alpha), 1.8, true)
	var label := Rect2(pos + Vector2(-21, 17), Vector2(42, 12))
	ci.draw_rect(label, Color(PAPER, alpha))
	ci.draw_string(UiTheme.font(), label.position + Vector2(2, 9), "%d/%d" % [p["uid"], ceili(float(p["condition"]))], HORIZONTAL_ALIGNMENT_LEFT, 38, 9, Color(INK, alpha))
	var weapon := Content.weapon(p["weapon_id"])
	if weapon != null:
		_draw_paper(ci, PresentationAssets.weapon_key(weapon), pos + Vector2(23, 18), Vector2(15, 13), Vector2.ONE, alpha)


static func _draw_paper(ci: CanvasItem, key: StringName, foot: Vector2, extent: Vector2, scale: Vector2, alpha: float, tint: Color = Color.WHITE) -> void:
	var texture := PresentationAssets.texture(key)
	var source := PresentationAssets.frame_region(key, 0)
	if texture == null or not source.has_area():
		return
	var factor := minf(extent.x / source.size.x, extent.y / source.size.y)
	var pivot := PresentationAssets.frame_pivot(key, 0)
	for region: Rect2 in PresentationAssets.frame_visible_regions(key, 0):
		var destination := Rect2(foot + (region.position - source.position - pivot) * factor * scale, region.size * factor * scale)
		ci.draw_texture_rect_region(texture, destination, region, Color(tint, alpha))


static func _draw_skill(ci: CanvasItem, p: Dictionary, sim: Sim) -> void:
	var ability: StringName = p["ability"]
	var progress := float(p["progress"])
	var alpha := float(p["alpha"])
	var reduced := bool(p["reduced"])
	var body: Vector2 = sim.player.pos if sim != null else p["target_pos"]
	if ability in [&"looper", &"solo", &"mirror"]:
		var pairs: Array[Dictionary] = [{"from_pos": p["pos"], "to_pos": p["target_pos"]}]
		pairs.append_array(p["anchors"])
		for index in mini(Sim.MAX_ECHO_CAPACITY + 1, pairs.size()):
			var pair: Dictionary = pairs[index]
			var origin: Vector2 = pair["from_pos"]
			var target: Vector2 = pair["to_pos"]
			if origin.distance_squared_to(target) < 1.0:
				continue
			if not reduced and progress < 0.62:
				var at := origin.lerp(target, smoothstep(0.0, 0.62, progress) * 0.35)
				var scale := skill_pose(ability, minf(progress, 0.99))["scale"] as Vector2
				_draw_departure(ci, at, scale, Color(INK, alpha * (1.0 - progress / 0.62) * 0.38))
			for stitch in (2 if reduced else 3):
				var at := origin.lerp(target, 0.25 + float(stitch) * 0.25)
				ci.draw_line(at + Vector2(-2, -2), at + Vector2(2, 2), Color(FRIEND, alpha * 0.5), 1.4, true)
	elif ability == &"conductor":
		var stroke := 1.0 if reduced else smoothstep(0.18, 0.55, progress)
		var shoulder := body + Vector2(10, -8)
		var hand := shoulder + Vector2(15, -19 + stroke * 28)
		ci.draw_line(shoulder, hand, Color(PAPER, alpha), 6.0, true)
		ci.draw_line(shoulder, hand, Color(INK, alpha), 1.8, true)
		ci.draw_line(hand, hand + Vector2(12, -11), Color(INK, alpha), 2.3, true)
		for anchor: Dictionary in p["anchors"]:
			if int(anchor["uid"]) != int(p["selected_uid"]) or (sim != null and not _has_echo(sim, int(anchor["uid"]))):
				continue
			var target := _target_position({"uid": anchor["uid"], "target_type": &"echo", "pos": anchor["to_pos"]}, sim)
			for stitch in 3:
				var at := body.lerp(target, 0.25 + float(stitch) * 0.25)
				ci.draw_line(at - Vector2(2, 3), at + Vector2(2, 3), Color(FRIEND, alpha * 0.55), 1.4, true)
	elif ability == &"mender":
		var hand := body + Vector2(17, 8)
		ci.draw_line(body + Vector2(9, -7), hand, Color(INK, alpha), 2.4, true)
		_patch(ci, hand + Vector2(3, 3), progress, alpha, true)
	elif ability == &"overloader":
		var close := 1.0 if reduced else smoothstep(0.15, 0.48, progress)
		for side: float in [-1.0, 1.0]:
			var hand := body + Vector2(side * (22 - close * 13), 5)
			ci.draw_line(body + Vector2(side * 9, -7), hand, Color(INK, alpha), 2.5, true)
			ci.draw_line(hand + Vector2(-3, 0), hand + Vector2(3, 0), Color(WARN, alpha), 3.0, true)


static func _draw_departure(ci: CanvasItem, at: Vector2, scale: Vector2, ink: Color) -> void:
	var outline := PackedVector2Array([Vector2(-9, -31), Vector2(7, -31), Vector2(11, 7), Vector2(-10, 7), Vector2(-9, -31)])
	for index in outline.size():
		outline[index] = outline[index] * scale + at
	ci.draw_polyline(outline, ink, 1.3, true)
	ci.draw_line(at + Vector2(-5, 8), at + Vector2(-7, 17), ink, 1.2, true)
	ci.draw_line(at + Vector2(5, 8), at + Vector2(7, 14), ink, 1.2, true)


static func _draw_recruit(ci: CanvasItem, p: Dictionary) -> void:
	var pos: Vector2 = p["from_pos"] + Vector2(0, -43)
	var progress := float(p["progress"])
	var alpha := float(p["alpha"])
	# The tear reaches contact during the first 0.3s, before the recording beat
	# can yield to the shop. The committed replacement is readable immediately.
	var tear := minf(1.0, progress * 2.5)
	for side: float in [-1.0, 1.0]:
		var old := Rect2(pos + Vector2(side * tear * 9 - 7, -11 + tear * 8), Vector2(7, 12))
		ci.draw_rect(old, Color(PAPER, alpha * (1.0 - tear)))
		ci.draw_rect(old, Color(WARN, alpha * (1.0 - tear)), false, 1.2)
	var badge := Rect2((p["target_pos"] as Vector2) + Vector2(-17, -38), Vector2(34, 17))
	var edge := PackedVector2Array([badge.position + Vector2(0, 2), badge.position + Vector2(29, 0), badge.end,
		badge.position + Vector2(2, 17)])
	ci.draw_colored_polygon(edge, Color(PAPER, alpha))
	edge.append(edge[0])
	ci.draw_polyline(edge, Color(FRIEND, alpha), 1.6, true)
	var staple := badge.position + Vector2(17, 1)
	ci.draw_polyline(PackedVector2Array([staple + Vector2(-3, 2), staple + Vector2(-3, -2), staple + Vector2(3, -2), staple + Vector2(3, 2)]), Color(INK, alpha), 1.2, true)
	ci.draw_string(UiTheme.font(), badge.position + Vector2(3, 12), Loc.t("feedback.temporary"), HORIZONTAL_ALIGNMENT_CENTER, 28, 10, Color(FRIEND, alpha))


static func _draw_rescue(ci: CanvasItem, p: Dictionary) -> void:
	var pose := rescue_pose(p, float(p["progress"]), bool(p["reduced"]))
	var at: Vector2 = pose["source"]
	var progress := float(p["progress"])
	var alpha := float(p["alpha"]) * (1.0 if bool(p["reduced"]) else 1.0 - smoothstep(0.5, 1.0, progress))
	# Shackles break where the worker was held; the safe registry owns the only
	# filled living body. This departing empty contour cannot receive damage.
	for side: float in [-1.0, 1.0]:
		var wrist := at + Vector2(side * 15, -12)
		var spread := 3.0 if bool(p["reduced"]) else smoothstep(0.0, 0.3, progress) * 8.0
		ci.draw_arc(wrist + Vector2(side * spread, spread), 4, 0.4, TAU - 0.6, 10, Color(INK, alpha), 1.8, true)
		ci.draw_line(wrist + Vector2(side * spread, spread), wrist + Vector2(side * (spread + 5), spread + 6), Color(FRIEND, alpha), 1.6, true)
	if float(pose["departure_alpha"]) > 0.0:
		_draw_departure(ci, pose["departure_pos"], Vector2.ONE, Color(INK, float(pose["departure_alpha"])))
	var target: Vector2 = pose["target"]
	for stitch in (2 if bool(p["reduced"]) else 4):
		var point := at.lerp(target, float(stitch + 1) / 5.0)
		ci.draw_line(point - Vector2(2, 1), point + Vector2(2, 1), Color(FRIEND, alpha * 0.5), 1.4, true)
