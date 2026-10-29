class_name RecyclingDepot
extends Node2D

# Shallow edge landmarks. They sit underneath actors and never create collision.
const ATLAS_PATH := "res://assets/presentation/environment/depot_landmarks.png"
const ATLAS_SOURCE_SIZE := Vector2(1881.0, 836.0)
const CONVEYOR_SOURCE := Rect2(28.0, 272.0, 721.0, 449.0)
const WORKSTATION_SOURCE := Rect2(774.0, 59.0, 519.0, 673.0)
const NOTICE_SOURCE := Rect2(1332.0, 117.0, 525.0, 629.0)
const EDGE_DEPTH := 136.0
const QUIET_CENTER := Rect2(260.0, 220.0, 860.0, 320.0)
const INK := Color("37362d")
const PAPER := Color("d1c5a4")
const METAL := Color("6c6a59")
const MARK := Color("745b4b")
const ACCENT := Color("915345")
const DRAW_HZ := 12.0

var _visual_time := 0.0
var _reduced_effects := false
var _paused := false
var _draw_tick := -1
var _language := ""
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


static func landmark_rects() -> Dictionary:
	return {
		&"returns": Rect2(60.0, 92.0, 330.0, 118.0),
		&"notice": Rect2(516.0, 86.0, 248.0, 60.0),
		&"workstation": Rect2(1128.0, 538.0, 100.0, 130.0),
		&"scrap_tag": Rect2(1140.0, 506.0, 88.0, 27.0),
		&"poster": Rect2(48.0, 550.0, 80.0, 96.0),
		&"chute": Rect2(44.0, 378.0, 60.0, 110.0),
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


static func notice_text_rect() -> Rect2:
	return Rect2(536.0, 95.0, 208.0, 39.0)


func _draw() -> void:
	var profile := motion_profile(float(maxi(0, _draw_tick)) / DRAW_HZ, _reduced_effects)
	_draw_returns(profile)
	_draw_notice()
	_draw_workstation(profile)
	_draw_chute()
	_draw_poster()


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
	draw_colored_polygon(PackedVector2Array([
		form + Vector2(-9.0, -4.0), form + Vector2(6.0, -6.0),
		form + Vector2(9.0, 3.0), form + Vector2(-5.0, 5.0),
	]), Color(PAPER, 0.82))
	draw_line(form + Vector2(-3.0, -2.0), form + Vector2(5.0, 0.0), Color(INK, 0.55), 1.0)
	_draw_region(CONVEYOR_SOURCE, Rect2(60.0, 92.0, 190.0, 118.0))
	_draw_label(Loc.t("world.returns"), Rect2(248.0, 139.0, 125.0, 21.0), 16, MARK)


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
	_draw_label(Loc.t("world.notice_title"), Rect2(r.position, Vector2(r.size.x, 17.0)), 18, INK)
	_draw_label(Loc.t("world.notice_line"), Rect2(r.position + Vector2(0.0, 17.0), Vector2(r.size.x, 17.0)), 11, MARK)


func _draw_workstation(profile: Dictionary) -> void:
	_draw_region(WORKSTATION_SOURCE, Rect2(1128.0, 538.0, 100.0, 130.0))
	var press := float(profile["press"])
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


func _draw_chute() -> void:
	var mouth := PackedVector2Array([
		Vector2(45.0, 388.0), Vector2(95.0, 381.0),
		Vector2(102.0, 452.0), Vector2(47.0, 461.0),
	])
	draw_colored_polygon(mouth, Color(INK, 0.5))
	draw_polyline(_closed(mouth), Color(INK, 0.75), 2.0, true)
	for i in 5:
		var y := 395.0 + float(i) * 12.0
		draw_line(Vector2(50.0, y), Vector2(96.0, y - 6.0), Color(METAL, 0.7), 4.0, true)
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
