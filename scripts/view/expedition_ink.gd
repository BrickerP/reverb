class_name ExpeditionInk
extends RefCounted

# Presentation reads authoritative units, mission targets and locked warnings.
# No clocks, charges, positions, health or random state are advanced here.
const INK := Color("292720")
const PAPER := Color("e5d8b8")
const FRIEND := Color("729585")
const DANGER := Color("be5749")
const MAX_TARGETS := 24
const MAX_BOSS_WARNINGS := 4
const TARGET_KINDS: Array[StringName] = [&"press", &"conveyor", &"recycler", &"part", &"terminal", &"repair", &"rescue", &"negotiate", &"bureau_pickup", &"bureau_switch", &"bureau_inbox", &"bureau_inspection"]

static var _last_stats := {"supports": 0, "targets": 0, "warnings": 0}


static func snapshot(sim: Sim, clock: float = 0.0, reduced: bool = false,
		display_rect: Rect2 = WorldArena.VIEWPORT, world: Dictionary = {}, feedback: InteractionInk = null) -> Dictionary:
	var result := {"supports": [], "targets": [], "warnings": []}
	if sim == null:
		return result
	var safe := WorldArena.camera_rect(sim.player.pos, display_rect)
	var view := safe.grow(ArenaPainter.CULL_SHAKE_MARGIN)
	var choice := Expedition.interaction(sim)
	var world_state := world if not world.is_empty() else Expedition.world_profile(sim)
	for index in mini(SupportSystem.MAX_UNITS, sim.support_units.size()):
		var profile := support_profile(sim.support_units[index], clock, reduced)
		profile["pose"] = feedback.support_pose(int(profile["uid"]), reduced) if feedback != null else {"scale": Vector2.ONE, "offset": Vector2.ZERO}
		if bool(profile["visible"]) and ArenaPainter.body_in_view(profile["pos"], view):
			result["supports"].append(profile)
	for index in mini(MAX_TARGETS, sim.interactables.size()):
		var profile := target_profile(sim, sim.interactables[index], safe, choice, world_state)
		if bool(profile["visible"]):
			result["targets"].append(profile)
	for enemy: EnemyState in sim.enemies:
		if enemy.def == null or not enemy.def.is_boss:
			continue
		var warning := boss_warning_profile(enemy)
		if bool(warning["visible"]) and (warning["bounds"] as Rect2).intersects(view):
			result["warnings"].append(warning)
			if result["warnings"].size() >= MAX_BOSS_WARNINGS:
				break
	return result


static func support_profile(unit: Dictionary, clock: float = 0.0, reduced: bool = false) -> Dictionary:
	var kind := StringName(unit.get("kind", &""))
	var pos: Vector2 = unit.get("pos", Vector2.ZERO)
	var hp := float(unit.get("hp", 0.0))
	var maximum := float(unit.get("max_hp", 0.0))
	var life := float(unit.get("life", 0.0))
	var interval := float(unit.get("interval", 1.0))
	var cooldown := float(unit.get("cooldown", 0.0))
	var valid := SupportSystem.PROFILES.has(kind) and pos.is_finite() and is_finite(hp) \
		and is_finite(maximum) and maximum > 0.0 and is_finite(life) and is_finite(cooldown) and is_finite(interval) and interval > 0.0
	var active := valid and cooldown > interval * 0.6
	if kind == &"paper_tree":
		active = int(unit.get("charges", 4)) < 4
	var companion := SupportSystem.COMPANIONS.has(kind)
	var size := Vector2(44, 44)
	match kind:
		&"hound": size = Vector2(47, 40)
		&"turret": size = Vector2(44, 48)
		&"repair_station": size = Vector2(44, 48)
		&"paper_tree": size = Vector2(48, 58)
		&"decoy": size = Vector2(42, 52)
	if companion:
		size = Vector2(70, 66)
	var time := clock if is_finite(clock) else 0.0
	var bob := sin(time * 7.0 + float(int(unit.get("uid", 0)))) * 1.1 if kind == &"hound" and not reduced else 0.0
	var key := PresentationAssets.support_key(kind, active)
	var frame := (2 + int(floor(time * 5.0)) % 2) if companion and active and not reduced else 0
	if kind == &"recruited_paradox" and active:
		frame = 1
	return {"visible": valid and hp > 0.0 and life > 0.0, "uid": int(unit.get("uid", 0)),
		"kind": kind, "key": key, "pos": pos, "foot": pos + Vector2(0, 11.0 + bob),
		"size": size, "active": active, "companion": companion,
		"frame": frame,
		"hp_ratio": clampf(hp / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0,
		"life_ratio": clampf(life / float(SupportSystem.PROFILES[kind]["life"]), 0.0, 1.0) if SupportSystem.PROFILES.has(kind) else 0.0,
		"life_seconds": maxf(0.0, life),
		"charge_capacity": 6 if kind == &"repair_station" else (4 if kind == &"paper_tree" else 0),
		"charges": maxi(0, int(unit.get("charges", 0))), "actor_token": int(unit.get("actor_token", -1))}


static func target_profile(sim: Sim, item: Dictionary, view: Rect2, choice: Dictionary = {}, world: Dictionary = {}) -> Dictionary:
	var kind := StringName(item.get("kind", &""))
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var valid := TARGET_KINDS.has(kind) and pos.is_finite() and not bool(item.get("used", false))
	var cooldown := maxf(0.0, float(item.get("cooldown", 0.0)))
	var warning := maxf(0.0, float(item.get("warning", 0.0)))
	var active := maxf(0.0, float(item.get("active", 0.0)))
	var near := valid and sim.player.pos.distance_to(pos) <= float(item.get("range", Expedition.INTERACTION_RANGE))
	var selected: bool = near and choice.get("id", &"") == item.get("id", &"")
	var danger_radius := 100.0 if kind == &"press" and (warning > 0.0 or active > 0.0) else (105.0 if kind == &"conveyor" and active > 0.0 else 0.0)
	var bounds := Rect2(pos - Vector2.ONE * maxf(38.0, danger_radius), Vector2.ONE * maxf(76.0, danger_radius * 2.0))
	var label := Rect2(pos + Vector2(-98, -92), Vector2(196, 42))
	label.position = label.position.clamp(view.position + Vector2(8, 8), view.end - label.size - Vector2(8, 8))
	var protected_hp := clampf(float(sim.expedition.get("mission", {}).get("protected_hp", 0.0)) / 45.0, 0.0, 1.0)
	if kind == &"rescue":
		for worker: Dictionary in sim.expedition.get("world", world).get("workers", []):
			if worker["id"] == item.get("id"):
				protected_hp = clampf(float(worker["hp"]) / 45.0, 0.0, 1.0)
				valid = valid and worker["state"] == &"danger"
				break
	return {"visible": valid and bounds.intersects(view), "id": item.get("id", &""), "kind": kind,
		"pos": pos, "near": near, "selected": selected, "label": label,
		"cost": maxi(0, int(item.get("cost", 0))), "cooldown": cooldown,
		"available": cooldown <= 0.0 and sim.player.materials >= int(item.get("cost", 0)) and warning <= 0.0,
		"warning": warning, "active": active, "radius": danger_radius,
		"progress": 1.0 - clampf(warning / 1.1, 0.0, 1.0),
		"direction": item.get("direction", Vector2.RIGHT),
		"negotiation": maxf(0.0, float(sim.expedition.get("negotiation", {}).get("remaining", 0.0))),
		"protected_hp": protected_hp}


static func boss_warning_profile(enemy: EnemyState) -> Dictionary:
	var result := {"visible": false, "bounds": Rect2()}
	if enemy == null or enemy.def == null or not enemy.def.is_boss or enemy.dead or not enemy.pos.is_finite():
		return result
	var profile := EnemyBrain.attack_profile(enemy)
	if not bool(profile.get("visible", false)):
		return result
	var kind := StringName(profile["kind"])
	var center: Vector2 = profile["target"] if kind in [&"press", &"cross"] else profile["origin"]
	var direction: Vector2 = profile["direction"]
	var radius := float(profile["radius"])
	var reach := float(profile["reach"])
	if not center.is_finite() or not direction.is_finite() or not is_finite(radius) or not is_finite(reach):
		return result
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var end := WorldArena.move_straight(center, direction * reach, enemy.radius) if kind == &"dash" else center
	var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var regions: Array[Rect2] = []
	var polygon := PackedVector2Array()
	if kind == &"cross":
		regions = [Rect2(center - Vector2(reach, radius), Vector2(reach * 2.0, radius * 2.0)),
			Rect2(center - Vector2(radius, reach), Vector2(radius * 2.0, reach * 2.0))]
		bounds = Rect2(center - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	elif kind == &"dash":
		var normal := Vector2(-direction.y, direction.x) * radius
		polygon = PackedVector2Array([center + normal, end + normal, end - normal, center - normal])
		var low := Vector2(minf(center.x, end.x), minf(center.y, end.y))
		var high := Vector2(maxf(center.x, end.x), maxf(center.y, end.y))
		bounds = Rect2(low, high - low).grow(radius)
	return {"visible": true, "kind": kind, "center": center, "end": end, "direction": direction,
		"radius": radius, "reach": reach, "bounds": bounds, "regions": regions, "polygon": polygon,
		"active": bool(profile["active"]), "progress": clampf(float(profile["progress"]), 0.0, 1.0)}


static func draw(ci: CanvasItem, sim: Sim, clock: float = 0.0, reduced: bool = false, world: Dictionary = {}, feedback: InteractionInk = null) -> void:
	_last_stats = {"supports": 0, "targets": 0, "warnings": 0}
	if ci == null or sim == null:
		return
	var data := snapshot(sim, clock, reduced, WorldArena.display_viewport(ci.get_viewport_rect().size), world, feedback)
	for warning: Dictionary in data["warnings"]:
		_draw_warning(ci, warning, reduced)
		_last_stats["warnings"] += 1
	for target: Dictionary in data["targets"]:
		_draw_target(ci, target, reduced)
		_last_stats["targets"] += 1
	for support: Dictionary in data["supports"]:
		_draw_support(ci, support)
		_last_stats["supports"] += 1


static func draw_stats() -> Dictionary:
	return _last_stats.duplicate(true)


static func _draw_support(ci: CanvasItem, p: Dictionary) -> void:
	var pos: Vector2 = p["pos"]
	var kind: StringName = p["kind"]
	var key: StringName = p["key"]
	var tex := PresentationAssets.support_texture(kind, bool(p["active"]))
	var source := PresentationAssets.support_region(kind, bool(p["active"]), int(p["frame"]))
	if tex == null or not source.has_area():
		return
	var factor := ArenaPainter.art_pixel_scale(key, p["size"])
	var pivot := PresentationAssets.frame_pivot(key, int(p["frame"]))
	var foot: Vector2 = p["foot"]
	var pose: Dictionary = p.get("pose", {"scale": Vector2.ONE, "offset": Vector2.ZERO})
	var scale: Vector2 = pose["scale"]
	var body_foot: Vector2 = foot + (pose["offset"] as Vector2)
	var seal := 18.0 if bool(p["companion"]) else 13.0
	ci.draw_arc(pos, seal, 0.0, TAU, 20, Color(PAPER, 0.9), 3.5, true)
	ci.draw_arc(pos, seal, 0.0, TAU, 20, FRIEND, 1.5, true)
	for visible: Rect2 in PresentationAssets.frame_visible_regions(key, int(p["frame"])):
		var offset := (visible.position - source.position) * factor * scale
		ci.draw_texture_rect_region(tex, Rect2(body_foot - pivot * factor * scale + offset, visible.size * factor * scale), visible)
	var badge := pos + Vector2(seal, 5)
	ci.draw_circle(badge, 5.5, PAPER)
	ci.draw_polyline(PackedVector2Array([badge + Vector2(-3, 0), badge + Vector2(-1, 2), badge + Vector2(3, -3)]), FRIEND, 2.0, true)
	var width := 36.0 if bool(p["companion"]) else 28.0
	var bar := Rect2(foot + Vector2(-width * 0.5, -float((p["size"] as Vector2).y) - 6.0), Vector2(width, 4.0))
	ci.draw_rect(bar.grow(1), PAPER)
	ci.draw_rect(bar, INK)
	ci.draw_rect(Rect2(bar.position, Vector2(width * float(p["hp_ratio"]), 4)), FRIEND)
	# Health is the broad green strip; life is a separate thin ink strip with
	# an hourglass. Discrete staple pips count charges, never remaining seconds.
	var lifetime := Rect2(bar.position + Vector2(0, 7), Vector2(width, 2))
	ci.draw_rect(lifetime.grow(1), PAPER)
	ci.draw_rect(lifetime, Color(INK, 0.2))
	ci.draw_rect(Rect2(lifetime.position, Vector2(width * float(p["life_ratio"]), 2)), INK)
	var hour := lifetime.position + Vector2(-5, 1)
	ci.draw_multiline(PackedVector2Array([hour + Vector2(-2, -3), hour + Vector2(2, 3), hour + Vector2(2, -3), hour + Vector2(-2, 3)]), INK, 1.0, true)
	for charge in int(p["charge_capacity"]):
		var pip := Rect2(bar.position + Vector2(float(charge) * 5.0, -6.0), Vector2(3, 3))
		ci.draw_rect(pip, FRIEND, charge < int(p["charges"]), 1.0)


static func _draw_target(ci: CanvasItem, p: Dictionary, reduced: bool) -> void:
	var pos: Vector2 = p["pos"]
	var kind: StringName = p["kind"]
	if kind == &"negotiate":
		return
	var machine := kind in [&"press", &"conveyor", &"recycler"]
	var color := DANGER if float(p["warning"]) > 0.0 else FRIEND
	if machine and float(p["radius"]) > 0.0:
		var radius := float(p["radius"])
		ci.draw_circle(pos, radius, Color(color, 0.10 if float(p["active"]) > 0.0 else 0.04))
		ci.draw_arc(pos, radius, 0, TAU, 28 if reduced else 40, Color(color, 0.8), 2.0, true)
		if kind == &"conveyor":
			var direction: Vector2 = p["direction"]
			for index in 3:
				var anchor := pos + direction * float(index - 1) * 40.0
				var normal := Vector2(-direction.y, direction.x) * 7.0
				ci.draw_polyline(PackedVector2Array([anchor - direction * 10 + normal, anchor, anchor - direction * 10 - normal]), INK, 2.0, true)
	if kind not in [&"bureau_pickup", &"bureau_switch", &"bureau_inbox", &"bureau_inspection"]:
		if kind in [&"part", &"terminal", &"negotiate"]:
			ArenaPainter._draw_art(ci, &"mission_letter", pos - Vector2(0, 12), Vector2(34, 32), 0.0, Color.WHITE)
		elif kind == &"repair":
			ArenaPainter._draw_art_foot(ci, &"support_repair_station", pos + Vector2(0, 12), Vector2(42, 46), 0, Color.WHITE)
		elif kind == &"rescue":
			draw_worker(ci, pos, false)
			var bar := Rect2(pos + Vector2(-20, -47), Vector2(40, 4))
			ci.draw_rect(bar, INK)
			ci.draw_rect(Rect2(bar.position, Vector2(40.0 * float(p["protected_hp"]), 4)), DANGER)
		else:
			ci.draw_circle(pos, 16, PAPER)
			ci.draw_arc(pos, 16, 0, TAU, 16, INK, 2, true)
			_glyph(ci, kind, pos, color)
	if bool(p["selected"]):
		var label: Rect2 = p["label"]
		ci.draw_rect(label, Color(PAPER, 0.97))
		ci.draw_rect(label, INK, false, 1.5)
		var name := Loc.t("interaction." + String(kind))
		var text := Loc.t("hud.interact", [Controls.interact_label(), name])
		if int(p["cost"]) > 0:
			text = Loc.t("hud.interact_cost", [Controls.interact_label(), name, int(p["cost"])])
		ci.draw_string(UiTheme.font(), label.position + Vector2(7, 18), text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x - 12, 16,
			INK if bool(p["available"]) else Color("806d59"))
		var detail := ""
		if kind == &"negotiate":
			detail = Loc.t("world.negotiate", [ceili(float(p["negotiation"]))])
		elif float(p["cooldown"]) > 0.0:
			detail = Loc.t("world.wait", [ceili(float(p["cooldown"]))])
		elif int(p["cost"]) > 0:
			detail = Loc.t("world.cost", [int(p["cost"])])
		ci.draw_string(UiTheme.font(), label.position + Vector2(7, 35), detail, HORIZONTAL_ALIGNMENT_LEFT, label.size.x - 12, 13, color)


# A living worker has a face, hard hat, coat and two feet. The authored cardboard
# decoy remains reserved for its equipment/support identity.
static func draw_worker(ci: CanvasItem, pos: Vector2, safe: bool) -> void:
	var coat := PackedVector2Array([pos + Vector2(-10, -15), pos + Vector2(9, -15), pos + Vector2(12, 9), pos + Vector2(-12, 9)])
	ci.draw_colored_polygon(coat, PAPER)
	coat.append(coat[0])
	ci.draw_polyline(coat, INK, 2, true)
	ci.draw_circle(pos + Vector2(0, -24), 8, PAPER)
	ci.draw_arc(pos + Vector2(0, -24), 8, 0, TAU, 16, INK, 1.7, true)
	ci.draw_arc(pos + Vector2(0, -28), 9, PI, TAU, 12, INK, 3, true)
	ci.draw_line(pos + Vector2(-12, -28), pos + Vector2(12, -28), INK, 2.5, true)
	for dx in [-3.0, 3.0]:
		ci.draw_circle(pos + Vector2(dx, -24), 1.2, INK)
	ci.draw_line(pos + Vector2(-3, -19), pos + Vector2(3, -19), INK, 1, true)
	ci.draw_line(pos + Vector2(0, -13), pos + Vector2(0, 8), INK, 1.2, true)
	ci.draw_line(pos + Vector2(-6, 10), pos + Vector2(-7, 19), INK, 3, true)
	ci.draw_line(pos + Vector2(6, 10), pos + Vector2(7, 19), INK, 3, true)
	ci.draw_line(pos + Vector2(-11, -9), pos + Vector2(-17, 3 if safe else -17), INK, 2.5, true)
	ci.draw_line(pos + Vector2(11, -9), pos + Vector2(17, 3 if safe else -17), INK, 2.5, true)
	if safe:
		ci.draw_polyline(PackedVector2Array([pos + Vector2(-4, -5), pos + Vector2(0, -1), pos + Vector2(6, -8)]), FRIEND, 2, true)


static func work_profile(info: Dictionary, view: Rect2) -> Dictionary:
	var pos: Vector2 = info.get("pos", Vector2.ZERO)
	var target: Vector2 = info.get("target_pos", pos)
	var kind := StringName(info.get("kind", &""))
	var success := bool(info.get("success", false))
	if not pos.is_finite() or not target.is_finite() or kind not in [&"press", &"conveyor", &"signature"]:
		return {"visible": false}
	var anchor := target if success and kind != &"signature" else pos
	var label := Rect2(anchor + Vector2(-102, -68), Vector2(204, 34))
	label.position = label.position.clamp(view.position + Vector2(8, 8), view.end - label.size - Vector2(8, 8))
	return {"visible": view.grow(24).has_point(anchor), "uid": int(info.get("uid", 0)), "kind": kind,
		"target_id": StringName(info.get("target_id", &"")),
		"name_key": "interaction.bureau_switch" if info.get("target_id", &"") == BureauEvents.SWITCH_ID else "work.kind." + String(kind),
		"pos": anchor, "intent": (target - pos).normalized(), "success": success,
		"reason": StringName(info.get("reason", &"unavailable")), "label": label,
		"alpha": clampf(float(info.get("life", 1.0)) / 0.35, 0.0, 1.0)}


static func draw_work(ci: CanvasItem, marks: Array[Dictionary], view: Rect2, reduced: bool) -> void:
	var count := mini(4 if reduced else 8, marks.size())
	for index in range(marks.size() - count, marks.size()):
		var p := work_profile(marks[index], view)
		if not p["visible"]:
			continue
		var pos: Vector2 = p["pos"]
		var alpha := float(p["alpha"])
		var color := Color(FRIEND if p["success"] else INK, alpha)
		if p["success"]:
			if p["target_id"] == BureauEvents.SWITCH_ID:
				ci.draw_polyline(PackedVector2Array([pos + Vector2(-7, 6), pos + Vector2(7, 6), pos + Vector2(0, 6), pos + Vector2(5, -6)]), color, 2.0, true)
				ci.draw_circle(pos + Vector2(5, -6), 2.5, color)
			elif p["kind"] == &"signature":
				# A short old-aim compass is intent, never a projectile or hit area.
				var direction: Vector2 = p["intent"]
				if direction == Vector2.ZERO:
					direction = Vector2.RIGHT
				var normal := Vector2(-direction.y, direction.x)
				ci.draw_polyline(PackedVector2Array([pos - direction * 7 + normal * 5, pos + direction * 7, pos - direction * 7 - normal * 5]), color, 2, true)
			else:
				_glyph(ci, p["kind"], pos, color)
		else:
			ci.draw_line(pos + Vector2(-6, -6), pos + Vector2(6, 6), color, 2, true)
			ci.draw_line(pos + Vector2(6, -6), pos + Vector2(-6, 6), color, 2, true)
		var label: Rect2 = p["label"]
		ci.draw_rect(label, Color(PAPER, alpha * 0.94))
		var title := Loc.t("work.mark", [p["uid"], Loc.t(p["name_key"])])
		var cause := Loc.t("work.reason." + String(p["reason"]))
		ci.draw_string(UiTheme.font(), label.position + Vector2(6, 14), title, HORIZONTAL_ALIGNMENT_LEFT, label.size.x - 12, 12, color)
		ci.draw_string(UiTheme.font(), label.position + Vector2(6, 28), cause, HORIZONTAL_ALIGNMENT_LEFT, label.size.x - 12, 12, color)


static func _draw_warning(ci: CanvasItem, p: Dictionary, reduced: bool) -> void:
	var active := bool(p["active"])
	var edge := Color(DANGER, 0.95 if active else 0.5 + float(p["progress"]) * 0.35)
	var fill := Color(DANGER, 0.16 if active else 0.055)
	var center: Vector2 = p["center"]
	match p["kind"]:
		&"press":
			ci.draw_circle(center, float(p["radius"]), fill)
			ci.draw_arc(center, float(p["radius"]), 0, TAU, 32 if reduced else 48, edge, 2.5, true)
			_glyph(ci, &"press", center, edge)
		&"cross":
			for rect: Rect2 in p["regions"]:
				ci.draw_rect(rect, fill)
				ci.draw_rect(rect, edge, false, 2)
			_glyph(ci, &"cross", center, edge)
		&"dash":
			var polygon: PackedVector2Array = p["polygon"]
			if center.distance_squared_to(p["end"]) > 0.5:
				ci.draw_colored_polygon(polygon, fill)
				polygon.append(polygon[0])
				ci.draw_polyline(polygon, edge, 2.0, true)
			ci.draw_arc(p["end"], float(p["radius"]), 0, TAU, 20, edge, 1.5, true)
			_glyph(ci, &"dash", center.lerp(p["end"], 0.6), edge, p["direction"])


static func _glyph(ci: CanvasItem, kind: StringName, pos: Vector2, color: Color, direction: Vector2 = Vector2.RIGHT) -> void:
	var points := PackedVector2Array()
	match kind:
		&"press":
			points = PackedVector2Array([Vector2(-9, -9), Vector2(9, -9), Vector2(-9, -9), Vector2(-9, -3), Vector2(9, -9), Vector2(9, -3), Vector2(0, -2), Vector2(0, 9), Vector2(-5, 4), Vector2(0, 9), Vector2(5, 4), Vector2(0, 9)])
		&"dash", &"conveyor":
			points = PackedVector2Array([Vector2(-9, -8), Vector2(-1, 0), Vector2(-1, 0), Vector2(-9, 8), Vector2(0, -8), Vector2(8, 0), Vector2(8, 0), Vector2(0, 8)])
		&"cross":
			points = PackedVector2Array([Vector2(-9, -9), Vector2(9, 9), Vector2(-9, 9), Vector2(9, -9)])
		&"recycler":
			points = PackedVector2Array([Vector2(-9, 3), Vector2(0, -9), Vector2(0, -9), Vector2(9, 3), Vector2(9, 3), Vector2(-9, 3), Vector2(-4, 8), Vector2(4, 8)])
	for index in points.size():
		points[index] = points[index].rotated(direction.angle()) + pos
	if not points.is_empty():
		ci.draw_multiline(points, color, 2.4, true)
