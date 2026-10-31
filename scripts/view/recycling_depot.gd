class_name RecyclingDepot
extends Node2D

# Edge illustrations sit beneath actors. The five interior machine footprints
# come directly from WorldArena, the same geometry used by bodies and bullets.
const ATLAS_PATH := "res://assets/presentation/environment/depot_landmarks.png"
const ATLAS_SOURCE_SIZE := Vector2(1881.0, 836.0)
const CONVEYOR_SOURCE := Rect2(28.0, 272.0, 721.0, 449.0)
const WORKSTATION_SOURCE := Rect2(774.0, 59.0, 519.0, 673.0)
const NOTICE_SOURCE := Rect2(1332.0, 117.0, 525.0, 629.0)
const EDGE_DEPTH := 136.0
const QUIET_CENTER := Rect2(650.0, 530.0, 1000.0, 320.0)
const INK := Color("37362d")
const PAPER := Color("d1c5a4")
const METAL := Color("6c6a59")
const MARK := Color("745b4b")
const ACCENT := Color("915345")
const DRAW_HZ := 12.0
const SHIFT_SIGN_KEYS := ["world.sign.1", "world.sign.2", "world.sign.3"]

var _visual_time := 0.0
var _reduced_effects := false
var _paused := false
var _draw_tick := -1
var _language := ""
var _world_profile: Dictionary = {}
var _machine_profiles: Array[Dictionary] = []
var _safe_workers: Array[Dictionary] = []
var _retired_count := 0
var _worker_pad: InkStyleBox
var _act_id := 1
static var _atlas: Texture2D


func set_presentation(time: float, reduced: bool, paused: bool) -> void:
	var changed := _reduced_effects != reduced or _language != Loc.lang
	_reduced_effects = reduced
	_paused = paused
	_language = Loc.lang
	if not paused:
		_visual_time = maxf(0.0, time)
	var tick := 0 if reduced else int(floor(_visual_time * DRAW_HZ))
	if changed or tick != _draw_tick:
		_draw_tick = tick
		queue_redraw()


# Called only when authoritative world events or encounter boundaries change.
# Draws reuse this bounded snapshot; no simulation queries or allocations per frame.
func set_world_profile(profile: Dictionary) -> void:
	if profile == _world_profile:
		return
	_world_profile = profile.duplicate(true)
	_retired_count = mini(6, profile.get("bureau", {}).get("retired", []).size())
	_act_id = clampi(int(profile.get("act_id", 1)), 1, 3)
	_machine_profiles.clear()
	_safe_workers.clear()
	for machine: Dictionary in profile.get("machines", []):
		if _machine_profiles.size() >= 5:
			break
		_machine_profiles.append(machine.duplicate(true))
	for worker: Dictionary in profile.get("workers", []):
		if _safe_workers.size() >= 12:
			break
		if worker.get("state") == &"safe":
			_safe_workers.append(worker.duplicate(true))
	queue_redraw()


func world_presentation() -> Dictionary:
	return {"act_id": _act_id, "machines": _machine_profiles.duplicate(true), "safe_workers": _safe_workers.duplicate(true)}


static func landmark_rects() -> Dictionary:
	return {
		&"returns": Rect2(60.0, 92.0, 330.0, 118.0),
		&"notice": Rect2(1116.0, 86.0, 248.0, 60.0),
		&"workstation": Rect2(2328.0, 1138.0, 100.0, 130.0),
		&"scrap_tag": Rect2(2340.0, 1106.0, 88.0, 27.0),
		&"poster": Rect2(48.0, 1150.0, 80.0, 96.0),
		&"chute": Rect2(44.0, 678.0, 60.0, 110.0),
	}


static func motion_profile(time: float, reduced: bool) -> Dictionary:
	var clock := maxf(0.0, time)
	var cycle := fposmod(clock, 5.0)
	# One slow press every five seconds; the lamp is a steady dull dot in Reduced.
	var press := 0.0
	if not reduced and cycle >= 3.7 and cycle < 4.35:
		var t := (cycle - 3.7) / 0.65
		press = sin(t * PI)
	return {
		"roller": 0.0 if reduced else fposmod(clock * 5.0, 10.0),
		"feed": 0.45 if reduced else fposmod(clock * 0.07, 1.0),
		"press": press,
		"lamp": 0.32 if reduced else 0.30 + 0.12 * sin(clock * 1.2),
	}


static func production_profile(act: int) -> Dictionary:
	return {"loose_forms": act == 1, "sorted_stacks": act == 2,
		"press_running": act == 2, "shredder_open": act == 3, "sealed_bales": act == 3}


static func notice_text_rect() -> Rect2:
	return Rect2(536.0, 95.0, 208.0, 39.0)


func _draw() -> void:
	var profile := motion_profile(float(maxi(0, _draw_tick)) / DRAW_HZ, _reduced_effects)
	_draw_returns(profile)
	draw_set_transform(Vector2(600.0, 0.0))
	_draw_notice()
	draw_set_transform(Vector2(1200.0, 600.0))
	_draw_workstation(profile)
	draw_set_transform(Vector2(0.0, 300.0))
	_draw_chute()
	draw_set_transform(Vector2(0.0, 600.0))
	_draw_poster()
	draw_set_transform(Vector2.ZERO)
	_draw_machines(profile)
	_draw_safe_workers()
	_draw_cleanup()


func _draw_machines(profile: Dictionary) -> void:
	for index in WorldArena.MACHINES.size():
		var machine: Rect2 = WorldArena.MACHINES[index]
		var outline := PackedVector2Array([
			machine.position + Vector2(-3.0, 3.0),
			Vector2(machine.end.x + 2.0, machine.position.y - 2.0),
			machine.end + Vector2(3.0, -2.0),
			Vector2(machine.position.x - 2.0, machine.end.y + 2.0)])
		draw_colored_polygon(outline, Color(INK, 0.25))
		draw_polyline(_closed(outline), Color(INK, 0.62), 2.0, true)
		var machine_state: Dictionary = _machine_profiles[index] if index < _machine_profiles.size() else {}
		var is_press: bool = machine_state.get("kind", &"press" if index % 2 == 0 else &"conveyor") == &"press"
		var source := WORKSTATION_SOURCE if is_press else CONVEYOR_SOURCE
		var height := machine.size.y + (46.0 if is_press else 24.0)
		var width := minf(machine.size.x + 10.0, height * source.size.x / source.size.y)
		var art := Rect2(Vector2(machine.get_center().x - width * 0.5, machine.end.y - height), Vector2(width, height))
		_draw_region(source, art)
		var tag := Rect2(Vector2(machine.get_center().x - 56.0, machine.end.y - 7.0), Vector2(112.0, 22.0))
		draw_colored_polygon(PackedVector2Array([tag.position + Vector2(0.0, 2.0),
			tag.position + Vector2(tag.size.x - 3.0, 0.0), tag.end,
			Vector2(tag.position.x + 3.0, tag.end.y - 1.0)]), Color(PAPER, 0.92))
		var state := StringName(machine_state.get("status", &"operating"))
		var stopped := bool(machine_state.get("stopped", false))
		var label_key := "world.machine.stopped" if stopped else "world.machine." + String(state)
		_draw_label(Loc.t(label_key), tag.grow(-3.0), 12, INK)
		var lamp := Vector2(art.end.x - 7.0, art.position.y + art.size.y * 0.5)
		draw_circle(lamp, 2.0, Color(ACCENT, 0.25 if stopped else float(profile["lamp"])))
		_draw_machine_state(machine_state, art)
		for stripe in 4:
			var mark := machine.position + Vector2(12.0 + float(stripe) * 12.0, machine.size.y + 5.0)
			draw_line(mark, mark + Vector2(7.0, 5.0), Color(INK, 0.32), 2.0, true)


func _draw_machine_state(machine: Dictionary, art: Rect2) -> void:
	var center := art.get_center()
	if machine.get("stopped", false):
		# A physical lock bar crosses the mechanism, rather than a colour change.
		draw_line(center + Vector2(-22, -9), center + Vector2(22, 9), PAPER, 8, true)
		draw_line(center + Vector2(-22, -9), center + Vector2(22, 9), INK, 3, true)
		draw_rect(Rect2(center + Vector2(-5, -7), Vector2(10, 14)), PAPER)
		draw_rect(Rect2(center + Vector2(-5, -7), Vector2(10, 14)), INK, false, 2)
	elif machine.get("status") == &"fault":
		var crack := PackedVector2Array([center + Vector2(-9, -20), center + Vector2(2, -9), center + Vector2(-5, -1), center + Vector2(9, 14)])
		draw_polyline(crack, PAPER, 7, true)
		draw_polyline(crack, INK, 3, true)
		draw_line(center + Vector2(14, -21), center + Vector2(20, -9), INK, 3, true)
		draw_circle(center + Vector2(22, -4), 2, INK)
	elif machine.get("status") == &"repaired":
		var patch := Rect2(center + Vector2(-18, -14), Vector2(36, 24))
		draw_rect(patch, PAPER)
		draw_rect(patch, INK, false, 2)
		for dx in [-13.0, 13.0]:
			draw_line(center + Vector2(dx, -18), center + Vector2(dx, -10), INK, 2)
			draw_line(center + Vector2(dx, 6), center + Vector2(dx, 14), INK, 2)
		draw_polyline(PackedVector2Array([center + Vector2(-7, -2), center + Vector2(-2, 3), center + Vector2(8, -7)]), INK, 2.5, true)
	else:
		var direction: Vector2 = machine.get("direction", Vector2.RIGHT)
		var normal := Vector2(-direction.y, direction.x)
		for step in 2:
			var anchor := center + direction * float(step * 11 - 5)
			draw_polyline(PackedVector2Array([anchor - direction * 5 - normal * 5, anchor, anchor - direction * 5 + normal * 5]), Color(INK, 0.7), 2, true)


func _draw_safe_workers() -> void:
	if _safe_workers.is_empty():
		return
	var first: Vector2 = _safe_workers[0]["pos"]
	_draw_label(Loc.t("world.safe_registry"), Rect2(first + Vector2(-36, -72), Vector2(300, 24)), 17, INK)
	for worker in _safe_workers:
		var pos: Vector2 = worker["pos"]
		if _worker_pad == null:
			_worker_pad = UiTheme.paper_panel(PAPER)
			_worker_pad.shape = InkStyleBox.Shape.TAG
			_worker_pad.variant = 2
			_worker_pad.shadow_size = 0.0
		_worker_pad.draw(get_canvas_item(), Rect2(pos + Vector2(-23, -48), Vector2(46, 72)))
		draw_set_transform(pos, 0.0, Vector2(1.12, 1.12))
		ExpeditionInk.draw_worker(self, Vector2.ZERO, true)
		draw_set_transform(Vector2.ZERO)
		_draw_label(str(worker["stage"]), Rect2(pos + Vector2(-10, 21), Vector2(20, 14)), 11, INK)
		if worker["testimony_used"]:
			# A signed page remains beside its living witness.
			draw_rect(Rect2(pos + Vector2(12, -17), Vector2(10, 13)), PAPER)
			draw_line(pos + Vector2(14, -9), pos + Vector2(20, -13), INK, 1.5, true)


func _draw_returns(profile: Dictionary) -> void:
	# The long quiet belt extends the illustrated feeder without a second sprite.
	var belt := Rect2(218.0, 165.0, 160.0, 23.0)
	var outline := PackedVector2Array([
		belt.position + Vector2(-4.0, 2.0), belt.position + Vector2(154.0, -1.0),
		belt.end + Vector2(2.0, -2.0), belt.end + Vector2(-155.0, 2.0),
	])
	draw_colored_polygon(outline, Color(METAL, 0.72))
	draw_polyline(_closed(outline), Color(INK, 0.7), 2.0, true)
	for i in 15:
		var x := 223.0 + float(i) * 10.0
		draw_line(Vector2(x, 168.0), Vector2(x + 5.0, 184.0), Color(INK, 0.35), 1.0, true)
	var offset := float(profile["roller"])
	for i in 16:
		var x := 222.0 + float(i) * 10.0 + offset
		if x > 374.0:
			continue
		draw_line(Vector2(x, 187.0), Vector2(x + 3.0, 189.0), Color(PAPER, 0.4), 1.0, true)
	var form := Vector2(254.0 + float(profile["feed"]) * 98.0, 173.0)
	if _act_id == 1:
		draw_colored_polygon(PackedVector2Array([
			form + Vector2(-9.0, -4.0), form + Vector2(6.0, -6.0),
			form + Vector2(9.0, 3.0), form + Vector2(-5.0, 5.0),
		]), Color(PAPER, 0.82))
		draw_line(form + Vector2(-3.0, -2.0), form + Vector2(5.0, 0.0), Color(INK, 0.55), 1.0)
	elif _act_id == 2:
		for sheet in 3:
			var stack := Rect2(form + Vector2(-13.0, -8.0 - float(sheet) * 3.0), Vector2(26, 8))
			draw_rect(stack, PAPER)
			draw_rect(stack, Color(INK, 0.7), false, 1.0)
	else:
		# Only output bales remain on the intake belt after the disposal shift.
		for bundle in 2:
			var bale := Rect2(262 + bundle * 48, 165, 28, 21)
			draw_rect(bale, PAPER)
			draw_rect(bale, INK, false, 2)
			draw_line(bale.position + Vector2(14, 0), bale.position + Vector2(14, 21), INK, 2)
	_draw_region(CONVEYOR_SOURCE, Rect2(60.0, 92.0, 190.0, 118.0))
	_draw_label(Loc.t("world.act.%d" % _act_id), Rect2(248.0, 139.0, 125.0, 21.0), 16, MARK)


func _draw_notice() -> void:
	var sheet := PackedVector2Array([
		Vector2(519.0, 88.0), Vector2(755.0, 86.0), Vector2(762.0, 96.0),
		Vector2(759.0, 137.0), Vector2(750.0, 143.0), Vector2(735.0, 140.0),
		Vector2(727.0, 146.0), Vector2(523.0, 142.0), Vector2(516.0, 132.0),
	])
	draw_colored_polygon(sheet, Color(PAPER, 0.82))
	draw_polyline(_closed(sheet), Color(INK, 0.72), 2.0, true)
	draw_line(Vector2(525.0, 89.0), Vector2(525.0, 97.0), Color(INK, 0.55), 2.0)
	draw_line(Vector2(746.0, 88.0), Vector2(746.0, 96.0), Color(INK, 0.55), 2.0)
	var r := notice_text_rect()
	_draw_label(Loc.t("world.act.%d" % _act_id), Rect2(r.position, Vector2(r.size.x, 17.0)), 18, INK)
	_draw_label(Loc.t(SHIFT_SIGN_KEYS[_act_id - 1]), Rect2(r.position + Vector2(0.0, 17.0), Vector2(r.size.x, 17.0)), 11, MARK)


func _draw_workstation(profile: Dictionary) -> void:
	_draw_region(WORKSTATION_SOURCE, Rect2(1128.0, 538.0, 100.0, 130.0))
	var press := float(profile["press"]) if _act_id == 2 else 0.0
	var arm := Vector2(1173.0, 581.0 + press * 8.0)
	# A short dark rubber shoe makes the press beat visible without shaking the
	# full machine or using a moving silhouette as an apparent new obstacle.
	draw_line(arm + Vector2(-14.0, 0.0), arm + Vector2(16.0, 7.0), Color(INK, 0.65), 5.0, true)
	draw_line(arm + Vector2(-11.0, 4.0), arm + Vector2(15.0, 10.0), Color(ACCENT, 0.6), 3.0, true)
	draw_circle(Vector2(1212.0, 609.0), 2.5, Color(ACCENT, float(profile["lamp"])))
	var tag := PackedVector2Array([
		Vector2(1140.0, 509.0), Vector2(1228.0, 506.0),
		Vector2(1226.0, 530.0), Vector2(1143.0, 533.0),
	])
	draw_colored_polygon(tag, Color(PAPER, 0.82))
	draw_polyline(_closed(tag), Color(INK, 0.65), 1.5, true)
	_draw_label(Loc.t("world.scrap"), Rect2(1146.0, 512.0, 74.0, 14.0), 13, INK)
	if _act_id == 3:
		for index in 3:
			var bale := Rect2(1124 + index * 32, 638, 27, 22)
			draw_rect(bale, PAPER)
			draw_rect(bale, INK, false, 2)
			draw_line(bale.position + Vector2(13, 0), bale.position + Vector2(13, 22), INK, 2)


func _draw_chute() -> void:
	var mouth := PackedVector2Array([
		Vector2(45.0, 388.0), Vector2(95.0, 381.0),
		Vector2(102.0, 452.0), Vector2(47.0, 461.0),
	])
	draw_colored_polygon(mouth, Color(INK, 0.5))
	draw_polyline(_closed(mouth), Color(INK, 0.75), 2.0, true)
	for i in 5:
		var y := 395.0 + float(i) * 12.0
		if _act_id == 3:
			draw_line(Vector2(48.0, y), Vector2(59.0, y - 3.0), Color(METAL, 0.7), 4.0, true)
			draw_line(Vector2(87.0, y - 5.0), Vector2(99.0, y - 8.0), Color(METAL, 0.7), 4.0, true)
		else:
			draw_line(Vector2(50.0, y), Vector2(96.0, y - 6.0), Color(METAL, 0.7), 4.0, true)
	if _act_id == 3:
		for strip in 6:
			var x := 59.0 + float(strip) * 5.0
			draw_line(Vector2(x, 438), Vector2(x + 2, 459 + posmod(strip, 3) * 4), PAPER, 2, true)
	# Resigned wastepaper caught in the return grille. Small and static at the edge.
	var scrap := PackedVector2Array([
		Vector2(61.0, 459.0), Vector2(81.0, 455.0), Vector2(87.0, 466.0),
		Vector2(82.0, 474.0), Vector2(61.0, 477.0), Vector2(55.0, 469.0),
	])
	draw_colored_polygon(scrap, Color(PAPER, 0.75))
	draw_polyline(_closed(scrap), Color(INK, 0.6), 1.5, true)
	draw_line(Vector2(64.0, 465.0), Vector2(69.0, 464.0), Color(INK, 0.65), 1.5)
	draw_line(Vector2(75.0, 463.0), Vector2(80.0, 462.0), Color(INK, 0.65), 1.5)
	draw_line(Vector2(70.0, 470.0), Vector2(76.0, 469.0), Color(INK, 0.55), 1.0)


func _draw_poster() -> void:
	_draw_region(NOTICE_SOURCE, Rect2(48.0, 550.0, 80.0, 96.0))
	# A large prohibition seal reads without needing the tiny flavour copy.
	var seal := Vector2(78.0, 594.0)
	draw_arc(seal, 13.0, 0.0, TAU, 16, Color(ACCENT, 0.68), 2.0, true)
	draw_line(seal + Vector2(-10.0, 9.0), seal + Vector2(10.0, -9.0), Color(ACCENT, 0.7), 3.0, true)
	_draw_label(Loc.t("world.notice_small"), Rect2(56.0, 572.0, 45.0, 12.0), 10, MARK)


func _draw_region(source: Rect2, destination: Rect2) -> void:
	var tex := atlas_texture()
	if tex == null:
		return
	var imported_scale := tex.get_size() / ATLAS_SOURCE_SIZE
	var region := Rect2(source.position * imported_scale, source.size * imported_scale)
	var fit := minf(destination.size.x / source.size.x, destination.size.y / source.size.y)
	var size := source.size * fit
	var target := Rect2(destination.get_center() - size * 0.5, size)
	draw_texture_rect_region(tex, target, region, Color(0.78, 0.78, 0.72, 0.88))


static func atlas_texture() -> Texture2D:
	if _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	return _atlas


func _draw_label(text: String, rect: Rect2, maximum_size: int, color: Color) -> void:
	var font := UiTheme.title_font(text)
	var size := fitted_font_size(text, rect.size.x, maximum_size)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var x := rect.position.x + (rect.size.x - width) * 0.5
	var baseline := rect.position.y + (rect.size.y - font.get_height(size)) * 0.5 + font.get_ascent(size)
	draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, color)


static func fitted_font_size(text: String, width: float, maximum_size: int) -> int:
	var font := UiTheme.title_font(text)
	var size := maximum_size
	while size > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > width:
		size -= 1
	return size


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _draw_cleanup() -> void:
	# The first real survivor takes the night-shift broom. No additional worker,
	# corpse, reward or enemy removal is invented by this quiet edge animation.
	if _safe_workers.is_empty() or _retired_count <= 0:
		return
	var at: Vector2 = _safe_workers[0]["pos"]
	var sweep := 0.0 if _reduced_effects else sin(_visual_time * 1.7) * 4.0
	var head := at + Vector2(24.0 + sweep, 19)
	draw_line(at + Vector2(10, -5), head, INK, 2.8, true)
	draw_line(head + Vector2(-9, 1), head + Vector2(10, 1), MARK, 4.0, true)
	for index in 5:
		draw_line(head + Vector2(-8 + index * 4, 3), head + Vector2(-10 + index * 5, 9), INK, 1.2, true)
	for index in _retired_count:
		var pos := at + Vector2(40 + index * 8, 26 + (index % 2) * 4)
		var scrap := PackedVector2Array([pos + Vector2(-3, -3), pos + Vector2(4, -2), pos + Vector2(2, 4), pos + Vector2(-4, 2)])
		draw_colored_polygon(scrap, PAPER)
		scrap.append(scrap[0])
		draw_polyline(scrap, Color(INK, 0.55), 1.0, true)
	var caption := Rect2(at + Vector2(25, 38), Vector2(162, 22))
	_worker_pad.draw(get_canvas_item(), caption)
	_draw_label(Loc.t("bureau.cleanup"), caption, 12, INK)
