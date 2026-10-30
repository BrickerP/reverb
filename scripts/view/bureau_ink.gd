class_name BureauInk
extends RefCounted

const INK := Color("292720")
const PAPER := Color("e5d8b8")
const RED := Color("be5749")
const GREEN := Color("729585")
const DELIVERY_RADIUS := 86.0
const MAX_INSPECTIONS := 3
static var _label_stock: InkStyleBox

const DELIVERY_STATE_KEYS := {&"waiting": "bureau.delivery.waiting", &"carrying": "bureau.delivery.carrying", &"delivered": "bureau.delivery.delivered", &"missed": "bureau.delivery.missed"}


static func snapshot(sim: Sim, display: Rect2 = WorldArena.VIEWPORT) -> Dictionary:
	var result := {"delivery": {}, "inspections": [], "bounds": WorldArena.camera_rect(sim.player.pos, display) if sim != null else display}
	if sim == null:
		return result
	var bureau: Dictionary = sim.expedition.get("bureau", {})
	if bureau.is_empty():
		return result
	var delivery: Dictionary = BureauEvents.profile(sim).get("delivery", {})
	if delivery.get("visible", false):
		result["delivery"] = delivery
		var interaction := Expedition.interaction(sim)
		if not interaction.is_empty():
			var at: Vector2 = interaction.get("pos", sim.player.pos)
			var occupied := Rect2(at + Vector2(-98, -92), Vector2(196, 42))
			var safe: Rect2 = result["bounds"]
			occupied.position = occupied.position.clamp(safe.position + Vector2(8, 8), safe.end - occupied.size - Vector2(8, 8))
			delivery["avoid_label"] = occupied
	for row: Dictionary in bureau.get("confessions", []):
		if row.get("choice") != &"polish" or int(row.get("wave", 0)) != sim.wave or row.get("state") not in [&"active", &"passed"]:
			continue
		if result["inspections"].size() >= MAX_INSPECTIONS:
			break
		var pos: Vector2 = row.get("pos", Vector2.ZERO)
		if pos.is_finite():
			result["inspections"].append({"pos": pos, "passed": row["state"] == &"passed"})
	return result


static func draw(ci: CanvasItem, data: Dictionary, reduced: bool) -> void:
	if ci == null:
		return
	var view: Rect2 = data.get("bounds", WorldArena.VIEWPORT)
	var delivery: Dictionary = data.get("delivery", {})
	if not delivery.is_empty():
		_draw_delivery(ci, delivery, view, reduced)
	for row: Dictionary in data.get("inspections", []):
		var pos: Vector2 = row["pos"]
		if not view.grow(100.0).has_point(pos):
			continue
		BureauArt.draw_facility(ci, &"copier_print" if row["passed"] else &"copier_closed", Rect2(pos + Vector2(-38, -67), Vector2(76, 82)))
		if row["passed"]:
			ci.draw_polyline(PackedVector2Array([pos + Vector2(-8, 13), pos + Vector2(-2, 19), pos + Vector2(10, 5)]), GREEN, 3.0, true)


static func _draw_delivery(ci: CanvasItem, p: Dictionary, view: Rect2, reduced: bool) -> void:
	var pickup: Vector2 = p.get("pickup", Vector2.ZERO)
	var lever: Vector2 = p.get("switch", Vector2.ZERO)
	var stamp: Vector2 = p.get("stamp", Vector2.ZERO)
	var inbox: Vector2 = p.get("inbox", Vector2.ZERO)
	var state := StringName(p.get("state", &"waiting"))
	var radius := float(p.get("radius", DELIVERY_RADIUS))
	var warning := bool(p.get("warning", false))
	var active := bool(p.get("active", false))
	var safe := float(p.get("safe_left", 0.0)) > 0.0
	if state in [&"waiting", &"carrying"]:
		var direction := (inbox - pickup).normalized()
		var distance := pickup.distance_to(inbox)
		for step in mini(40, floori(distance / 15.0)):
			var point := pickup + direction * float(step * 15 + 8)
			if point.distance_to(stamp) > radius and view.has_point(point):
				ci.draw_circle(point, 1.4, Color(INK, 0.26))
	if view.grow(110).has_point(stamp):
		# The authoritative model supplies this exact radius and phase. The ink
		# ring remains present in Reduced Effects and while the window is paused.
		var color := GREEN if safe else RED
		if state in [&"waiting", &"carrying"]:
			ci.draw_circle(stamp, radius, Color(color, 0.16 if active else 0.05))
			ci.draw_arc(stamp, radius, 0, TAU, 32 if reduced else 48, Color(color, 0.95 if warning or active else 0.4), 2.5, true)
		if warning:
			ci.draw_arc(stamp, radius - 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(p.get("progress", 0.0)), 0.0, 1.0), 24, RED, 4, true)
		if safe:
			ci.draw_polyline(PackedVector2Array([stamp + Vector2(-12, 0), stamp + Vector2(-3, 8), stamp + Vector2(14, -11)]), GREEN, 3.0, true)
		BureauArt.draw_facility(ci, &"stamp_down" if active else &"stamp_raised", Rect2(stamp + Vector2(-45, -135), Vector2(90, 126)))
		_draw_delivery_label(ci, delivery_label_profile(p, view))
	if view.grow(50).has_point(pickup) and state == &"waiting":
		_envelope(ci, pickup, 1.0)
	if view.grow(65).has_point(inbox):
		BureauArt.draw_facility(ci, &"inbox", Rect2(inbox + Vector2(-39, -49), Vector2(78, 68)))
		if state == &"delivered":
			ci.draw_polyline(PackedVector2Array([inbox + Vector2(-10, -8), inbox + Vector2(-2, 1), inbox + Vector2(14, -18)]), GREEN, 3.0, true)
	if view.grow(50).has_point(lever):
		ci.draw_circle(lever, 19, PAPER)
		ci.draw_arc(lever, 19, 0, TAU, 20, INK, 2.5, true)
		ci.draw_line(lever + Vector2(-8, 6), lever + Vector2(7, -8), INK, 3.0, true)
		ci.draw_circle(lever + Vector2(7, -8), 4.5, GREEN if safe else RED)


static func draw_carried(ci: CanvasItem, sim: Sim) -> void:
	if ci == null or sim == null:
		return
	var p: Dictionary = sim.expedition.get("bureau", {}).get("delivery", {})
	if p.get("state") == &"carrying":
		_envelope(ci, sim.player.pos + Vector2(17, -35), 0.75)


static func _envelope(ci: CanvasItem, at: Vector2, scale: float) -> void:
	var box := Rect2(at - Vector2(15, 10) * scale, Vector2(30, 20) * scale)
	ci.draw_rect(box, PAPER)
	ci.draw_rect(box, INK, false, 2.0, true)
	ci.draw_polyline(PackedVector2Array([box.position, at + Vector2(0, 3) * scale, box.position + Vector2(box.size.x, 0)]), INK, 1.6, true)
	ci.draw_circle(at + Vector2(8, 5) * scale, 2.5 * scale, RED)


static func draw_retirement(ci: CanvasItem, row: Dictionary, progress: float, bounds: Rect2, reduced: bool) -> void:
	if ci == null or row.is_empty():
		return
	var t := clampf(progress, 0.0, 1.0)
	var alpha := 1.0 - clampf((t - 0.7) / 0.3, 0.0, 1.0)
	var box := Rect2(bounds.position + Vector2(12, 12), Vector2(minf(260.0, bounds.size.x - 24.0), 53.0))
	ci.draw_rect(box, Color(PAPER, alpha * 0.94))
	ci.draw_rect(box, Color(INK, alpha), false, 1.5)
	var fold := 0.0 if reduced else minf(1.0, t * 3.0)
	var at := box.position + Vector2(23, 27)
	var paper := PackedVector2Array([at + Vector2(-10, -11), at + Vector2(11, -8 + fold * 4), at + Vector2(4, 12 - fold * 6), at + Vector2(-12, 8)])
	ci.draw_colored_polygon(paper, Color(PAPER, alpha))
	paper.append(paper[0])
	ci.draw_polyline(paper, Color(INK, alpha), 2, true)
	var title := Loc.t("bureau.retirement", [int(row.get("uid", 0))])
	var detail := Loc.t("bureau.retirement_work", [int(row.get("work", 0))])
	ci.draw_string(UiTheme.font(), box.position + Vector2(43, 21), title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 50, 14, Color(INK, alpha))
	ci.draw_string(UiTheme.font(), box.position + Vector2(43, 40), detail, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 50, 12, Color(INK, alpha))


static func direction_profile(sim: Sim, display: Rect2 = WorldArena.VIEWPORT) -> Dictionary:
	if sim == null:
		return {"visible": false}
	var delivery: Dictionary = sim.expedition.get("bureau", {}).get("delivery", {})
	var state := StringName(delivery.get("state", &""))
	if state not in [&"waiting", &"carrying"]:
		return {"visible": false}
	var target: Vector2 = delivery.get("pickup" if state == &"waiting" else "inbox", sim.player.pos)
	var view := WorldArena.camera_rect(sim.player.pos, display)
	if view.grow(-24.0).has_point(target):
		return {"visible": false}
	var direction := (target - view.get_center()).normalized()
	var half := view.size * 0.5 - Vector2(30, 30)
	var length := minf(half.x / maxf(0.001, absf(direction.x)), half.y / maxf(0.001, absf(direction.y)))
	var point := view.get_center() + direction * length
	var label := Rect2(point + Vector2(-91, -43), Vector2(182, 29))
	label.position = label.position.clamp(view.position + Vector2(8, 8), view.end - label.size - Vector2(8, 8))
	return {"visible": true, "point": point, "direction": direction, "label": label,
		"key": "bureau.direction.pickup" if state == &"waiting" else "bureau.direction.inbox"}


static func draw_direction(ci: CanvasItem, profile: Dictionary) -> void:
	if ci == null or not profile.get("visible", false):
		return
	var point: Vector2 = profile["point"]
	var direction: Vector2 = profile["direction"]
	var normal := Vector2(-direction.y, direction.x)
	ci.draw_circle(point, 12, PAPER)
	ci.draw_polyline(PackedVector2Array([point - direction * 5 + normal * 5, point + direction * 6, point - direction * 5 - normal * 5]), INK, 2.5, true)
	var label: Rect2 = profile["label"]
	ci.draw_rect(label, Color(PAPER, 0.94))
	ci.draw_string(UiTheme.font(), label.position + Vector2(5, 19), Loc.t(profile["key"]), HORIZONTAL_ALIGNMENT_CENTER, label.size.x - 10, 13, INK)


static func delivery_label_profile(p: Dictionary, view: Rect2) -> Dictionary:
	var state := StringName(p.get("state", &""))
	if not DELIVERY_STATE_KEYS.has(state):
		return {"visible": false}
	var stamp: Vector2 = p.get("stamp", Vector2.ZERO)
	var box := Rect2(stamp + Vector2(-118, -190), Vector2(236, 43))
	box.position = box.position.clamp(view.position + Vector2(8, 8), view.end - box.size - Vector2(8, 8))
	var occupied: Rect2 = p.get("avoid_label", Rect2())
	if box.intersects(occupied):
		box.position.x = view.position.x + 8.0
		if box.intersects(occupied):
			box.position.x = view.end.x - box.size.x - 8.0
	var detail_key := ""
	var args: Array = []
	if state == &"delivered" and p.get("rewarded", false):
		detail_key = "bureau.delivery.reward"
		args = [BureauEvents.REWARD]
	elif state in [&"waiting", &"carrying"]:
		if float(p.get("safe_left", 0.0)) > 0.0:
			detail_key = "bureau.delivery.safe"
			args = [float(p["safe_left"])]
		elif bool(p.get("active", false)):
			detail_key = "bureau.delivery.impact"
		elif bool(p.get("warning", false)):
			detail_key = "bureau.delivery.warning"
		else:
			detail_key = "bureau.delivery.recover"
	return {"visible": true, "rect": box, "title_key": DELIVERY_STATE_KEYS[state], "detail_key": detail_key,
		"args": args, "danger": bool(p.get("active", false)) or bool(p.get("warning", false))}


static func _draw_delivery_label(ci: CanvasItem, p: Dictionary) -> void:
	if not p.get("visible", false):
		return
	var box: Rect2 = p["rect"]
	if _label_stock == null:
		_label_stock = UiTheme.paper_panel(PAPER)
		_label_stock.shape = InkStyleBox.Shape.TAG
		_label_stock.variant = 5
		_label_stock.shadow_size = 0.0
	_label_stock.draw(ci.get_canvas_item(), box)
	var title := Loc.t(str(p["title_key"]))
	var detail := Loc.t(str(p["detail_key"]), p["args"]) if p["detail_key"] != "" else ""
	var width := box.size.x - 12
	ci.draw_string(UiTheme.font(), box.position + Vector2(6, 17), title, HORIZONTAL_ALIGNMENT_LEFT, width, _fit_size(title, width, 13), INK)
	if not detail.is_empty():
		ci.draw_string(UiTheme.font(), box.position + Vector2(6, 35), detail, HORIZONTAL_ALIGNMENT_LEFT, width, _fit_size(detail, width, 12), RED if p["danger"] else GREEN)


static func _fit_size(value: String, width: float, preferred: int) -> int:
	var size := preferred
	while size > 10 and UiTheme.font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size
