class_name Hud
extends Control

const WIDTH := 1280.0
const BAR_H := 72.0
const SLOT_Y := 688.0
const SLOT_W := 36.0
const SLOT_H := 28.0
const SLOT_GAP := 44.0

var sim: Sim
var paused: bool = false
var debug: bool = false
var reduced_effects: bool = false
var _visual_time := 0.0
var _last_health_ratio := 1.0
var _critical_poke := 0.0
# Resource instances and static strokes are reused, including all six weapon scraps.
var _ink_stocks: Dictionary = {}
var _meter_paths: Dictionary = {}

var _hp_ghost := 1.0
var _prev_cd: Array[float] = []
var _flash: Array[float] = []
var _prev_materials := 0
var _mat_pulse := 0.0
var _hint_time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(s: Sim) -> void:
	if s == null:
		unbind()
		return
	sim = s
	_hp_ghost = clampf(s.player.hp / maxf(1.0, s.player.max_hp()), 0.0, 1.0)
	_last_health_ratio = _hp_ghost
	_critical_poke = 0.0
	_prev_cd.clear()
	_flash.clear()
	for _w in s.player.weapons:
		_prev_cd.append(0.0)
		_flash.append(0.0)
	_prev_materials = s.player.materials
	_mat_pulse = 0.0
	_hint_time = 0.0
	_visual_time = 0.0


func unbind() -> void:
	sim = null
	paused = false
	_hp_ghost = 1.0
	_last_health_ratio = 1.0
	_critical_poke = 0.0
	_prev_cd.clear()
	_flash.clear()
	_prev_materials = 0
	_mat_pulse = 0.0
	_hint_time = 0.0
	_visual_time = 0.0
	queue_redraw()


# 0 = just fired, 1 = ready. Drives the fill in each weapon slot.
func weapon_ready(index: int) -> float:
	if sim == null or index < 0 or index >= sim.player.weapons.size():
		return 0.0
	var w := sim.player.weapons[index]
	var duration := maxf(0.01, w.cooldown * sim.player.stats.cooldown_mult()
			* Combat.family_cooldown_mult(sim.player.weapons, w.family)
			* sim.synergy_cooldown_mult())
	return clampf(1.0 - sim.player.cooldowns[index] / duration, 0.0, 1.0)


func echo_remaining(take: EchoTake) -> int:
	if sim == null:
		return 0
	return maxi(0, sim.echo_lifespan() - take.age)


# First minutes of a run; fades out on its own so it never becomes UI noise.
func hint_alpha() -> float:
	if sim == null or sim.wave != 1 or sim.phase != Sim.Phase.WAVE:
		return 0.0
	return clampf(1.0 - maxf(0.0, _hint_time - 4.0) / 1.5, 0.0, 1.0)


func _process(delta: float) -> void:
	if sim == null or paused:
		return
	_visual_time += delta
	var ratio := clampf(sim.player.hp / maxf(1.0, sim.player.max_hp()), 0.0, 1.0)
	if ratio < 0.3 and ratio < _last_health_ratio and not reduced_effects:
		_critical_poke = 1.0
	_last_health_ratio = ratio
	_critical_poke = maxf(0.0, _critical_poke - delta * 3.0)
	if ratio < _hp_ghost:
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 0.35)
	else:
		_hp_ghost = ratio
	if sim.player.materials > _prev_materials:
		_mat_pulse = 1.0
	_prev_materials = sim.player.materials
	_mat_pulse = maxf(0.0, _mat_pulse - delta * 2.5)
	if sim.wave == 1 and sim.phase == Sim.Phase.WAVE:
		_hint_time += delta
	while _prev_cd.size() < sim.player.weapons.size():
		_prev_cd.append(0.0)
		_flash.append(0.0)
	for i in sim.player.weapons.size():
		var cd := sim.player.cooldowns[i]
		if cd > _prev_cd[i] + 0.001:
			_flash[i] = 1.0
		_prev_cd[i] = cd
		_flash[i] = maxf(0.0, _flash[i] - delta * 8.0)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var regions := layout_regions()
	_stock(&"health_scroll", ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, 2).draw(get_canvas_item(), regions["health"])
	if sim.is_boss_wave():
		_stock(&"wave_tag", ArenaPainter.PAPER, InkStyleBox.Shape.TAG, 5).draw(get_canvas_item(), regions["wave"])
	_draw_health()
	_draw_echo_chips()
	_draw_wave()
	_draw_materials()
	_draw_weapons()
	_draw_gunsmith_charge()
	_draw_controls()
	_draw_onboarding()
	if debug:
		_draw_debug()


# Reference-canvas regions follow the game's existing keep-aspect viewport policy.
# Floating pieces deliberately leave quiet gaps; there is no full-width HUD frame.
func layout_regions() -> Dictionary:
	var boss := sim != null and sim.is_boss_wave()
	var wave_width := 440.0 if boss else 310.0
	return {
		"health": Rect2(23.0, 5.0, 340.0, 65.0),
		"wave": Rect2(640.0 - wave_width * 0.5, 7.0, wave_width, 61.0),
		"materials": Rect2(1084.0, 9.0, 162.0, 59.0),
		"weapons": Rect2(34.0, 683.0, 268.0, 36.0),
	}


func _draw_health() -> void:
	var pl := sim.player
	var ratio := clampf(pl.hp / maxf(1.0, pl.max_hp()), 0.0, 1.0)
	var low := ratio < 0.3
	var bar := Rect2(72.0, 15.0, 265.0, 19.0)
	_meter(bar, _hp_ghost, Color("9b8170"), Color("665248"), &"health", 18.0)
	_meter_fill(_meter_path(&"health", bar), ratio, ArenaPainter.DANGER, 16.0)
	_text("%s  %d / %d" % [Loc.t("hud.hp"), maxi(0, ceili(pl.hp)), int(pl.max_hp())],
			Vector2(83.0, 30.0), 16, ArenaPainter.PAPER)
	# A sleepy paper face is only jolted by an actual low-health hit, not a perpetual wobble.
	var face := Vector2(48.0, 25.0 - (0.0 if reduced_effects else _critical_poke * 2.0))
	_stock(&"scroll_end", ArenaPainter.PAPER, InkStyleBox.Shape.OVAL, 1).draw(
			get_canvas_item(), Rect2(face - Vector2(17.0, 19.0), Vector2(34.0, 38.0)))
	if low:
		for dx: float in [-4.0, 4.0]:
			draw_circle(face + Vector2(dx, -1.0), 3.7, ArenaPainter.INK)
			draw_circle(face + Vector2(dx, -1.0), 2.4, ArenaPainter.PAPER)
			draw_circle(face + Vector2(dx, -0.5), 1.1, ArenaPainter.INK)
		draw_arc(face + Vector2(0.0, 10.0), 4.0, PI + 0.2, TAU - 0.2, 8, ArenaPainter.INK, 1.4)
	else:
		for dx: float in [-4.0, 4.0]:
			draw_arc(face + Vector2(dx, -2.0), 3.0, 0.0, PI, 8, ArenaPainter.INK, 1.6)
		draw_line(face + Vector2(-3.0, 8.0), face + Vector2(3.0, 7.0), ArenaPainter.INK, 1.3)
	# A rolled lip makes the long stock read as a physical scroll rather than a rounded table row.
	draw_arc(Vector2(349.0, 38.0), 7.0, -PI * 0.8, PI * 0.9, 18, Color(ArenaPainter.INK, 0.62), 1.3)
	draw_arc(Vector2(349.0, 38.0), 3.5, 0.0, PI * 1.35, 12, Color(ArenaPainter.INK, 0.4), 1.1)
	if pl.max_shield() > 0.0:
		var shield_ratio := clampf(pl.shield / pl.max_shield(), 0.0, 1.0)
		_meter(Rect2(77.0, 36.0, 257.0, 3.0), shield_ratio,
				Color("748894"), Color(ArenaPainter.INK, 0.18), &"shield", 3.0)


func _draw_echo_chips() -> void:
	if sim.echo_capacity() <= 0:
		return
	_text(Loc.t("hud.echo"), Vector2(39.0, 62.0), 13, UiTheme.DIM)
	var lifespan := maxi(1, sim.echo_lifespan())
	var muted := sim.echo_silenced > 0.0
	for i in sim.echo_capacity():
		var chip := Rect2(112.0 + float(i) * 28.0, 45.0 + float(i % 2), 22.0, 17.0)
		var stock := _stock(StringName("echo_%d" % i), ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, i)
		stock.bg_color = ArenaPainter.PAPER
		stock.border_color = Color(ArenaPainter.INK, 0.45)
		if i < sim.echoes.size():
			var take := sim.echoes[i].take
			var remaining := echo_remaining(take)
			var tint := ArenaPainter.paper_echo_color(take.tint())
			stock.bg_color = ArenaPainter.PAPER.lerp(tint, 0.35 if muted else 0.72)
			stock.border_color = ArenaPainter.DANGER if remaining <= 1 else ArenaPainter.INK
			stock.draw(get_canvas_item(), chip)
			var segments := mini(6, lifespan)
			for k in segments:
				var filled := float(k) / float(segments) < float(remaining) / float(lifespan)
				var point := chip.position + Vector2(3.0 + float(k) * 16.0 / float(maxi(1, segments - 1)), 12.0)
				draw_circle(point, 1.2, ArenaPainter.PAPER if filled else Color(ArenaPainter.INK, 0.45))
			if muted:
				draw_line(chip.position + Vector2(5.0, 3.0), chip.end - Vector2(5.0, 4.0), ArenaPainter.DANGER, 1.6)
		else:
			stock.draw(get_canvas_item(), chip)
	if muted:
		var width := float(sim.echo_capacity()) * 28.0 - 6.0
		var ratio := clampf(sim.echo_silenced / Sim.BOSS_SILENCE_TIME, 0.0, 1.0)
		_meter(Rect2(112.0, 65.0, width, 2.0), ratio,
				UiTheme.WARN, Color(ArenaPainter.INK, 0.12), &"silenced", 2.0)


func wave_title() -> String:
	if sim == null or not sim.endless or not sim.is_boss_wave():
		return ""
	if sim.boss_rush:
		return Loc.t("hud.boss_rush_boss", [sim.wave])
	return Loc.t("hud.endless_boss", [sim.wave])


func _draw_wave() -> void:
	var boss_wave := sim.is_boss_wave()
	var field_ink := UiTheme.INK if boss_wave else ArenaPainter.PAPER
	var field_dim := UiTheme.DIM if boss_wave else ArenaPainter.PAPER.darkened(0.08)
	if sim.endless and not boss_wave:
		_title_text(Loc.t("hud.endless", [sim.wave]), Vector2(440.0, 34.0), 31,
				field_ink, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
		var left := ceili(maxf(0.0, sim.wave_duration - sim.wave_time))
		_meter(Rect2(535.0, 46.0, 210.0, 4.0), sim.wave_time / maxf(0.01, sim.wave_duration),
				field_ink, Color(field_ink, 0.2), &"wave", 4.0)
		_text("%d" % left, Vector2(754.0, 52.0), 14, field_dim)
		return
	if boss_wave:
		var phase2 := sim.boss_phase >= 2
		var defeated := sim.boss != null and sim.boss_alive_count() == 0
		if defeated:
			_title_text(Loc.t("hud.boss_down"), Vector2(440.0, 34.0), 30,
					UiTheme.COIN, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
		else:
			var title := Loc.t("hud.boss_phase2") if phase2 else Loc.t("hud.boss")
			if sim.endless:
				title = wave_title() + ("  //  II" if phase2 else "")
			var color := UiTheme.WARN if phase2 else UiTheme.ECHO
			_title_text(title, Vector2(440.0, 34.0), 30, color, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
			_meter(Rect2(463.0, 47.0, 350.0, 6.0), sim.boss_health_ratio(), color,
					Color(ArenaPainter.INK, 0.16), &"boss", 6.0)
			if phase2:
				# Shared thread, two stitched knots: both halves belong to the same original.
				for i in sim.boss_total_count():
					var alive := i < sim.boss_alive_count()
					var point := Vector2(825.0 + float(i) * 12.0, 47.0)
					draw_circle(point, 3.0, color if alive else Color(ArenaPainter.INK, 0.18))
	else:
		_title_text(Loc.t("hud.wave", [sim.wave, WaveDirector.FINAL_WAVE]), Vector2(440.0, 34.0), 32,
				field_ink, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
		var left := ceili(maxf(0.0, sim.wave_duration - sim.wave_time))
		var urgent := left <= 5
		var col := ArenaPainter.DANGER if urgent else field_ink
		_meter(Rect2(535.0, 46.0, 210.0, 4.0), sim.wave_time / maxf(0.01, sim.wave_duration),
				col, Color(field_ink, 0.2), &"wave", 4.0)
		_text("%d" % left, Vector2(754.0, 52.0), 14, field_ink)
	if sim.endless:
		return
	for i in WaveDirector.FINAL_WAVE:
		var point := Vector2(545.0 + float(i) * 10.0, 59.0 + sin(float(i) * 0.8) * 1.1)
		var current := i == sim.wave - 1
		var color := field_ink if current else Color(field_ink, 0.6 if i < sim.wave - 1 else 0.20)
		draw_circle(point, 2.6 if current else 1.7, color)


func _draw_materials() -> void:
	var rect: Rect2 = layout_regions()["materials"]
	var stock := _stock(&"material_sack", ArenaPainter.PAPER, InkStyleBox.Shape.BLOB, 6)
	stock.draw(get_canvas_item(), rect)
	# A short tied neck and sagging ink seam turn the counter into a bag, not another table cell.
	var knot := Vector2(rect.position.x + 43.0, rect.position.y + 5.0)
	for side: float in [-1.0, 1.0]:
		draw_arc(knot + Vector2(side * 7.0, 0.0), 7.0, 0.2, TAU - 0.2, 16, ArenaPainter.INK, 1.4)
	draw_line(Vector2(knot.x - 7.0, rect.position.y + 3.0),
			Vector2(knot.x + 10.0, rect.position.y + 6.0), ArenaPainter.INK, 2.0)
	var face := Vector2(rect.position.x + 28.0, rect.position.y + 29.0)
	var expression := material_expression()
	if expression == &"empty":
		for dx: float in [-4.0, 4.0]:
			draw_line(face + Vector2(dx - 2.5, -2.0), face + Vector2(dx + 2.5, -1.0), ArenaPainter.INK, 1.5)
		draw_arc(face + Vector2(0.0, 10.0), 4.0, PI + 0.2, TAU - 0.2, 8, ArenaPainter.INK, 1.5)
	else:
		draw_circle(face + Vector2(-4.0, -2.0), 1.6, ArenaPainter.INK)
		draw_circle(face + Vector2(4.0, -2.0), 1.6, ArenaPainter.INK)
		if expression == &"collected":
			draw_arc(face + Vector2(0.0, 2.0), 5.0, 0.1, PI - 0.1, 10, ArenaPainter.INK, 1.5)
		else:
			draw_line(face + Vector2(-3.0, 7.0), face + Vector2(3.0, 6.0), ArenaPainter.INK, 1.2)
	_title_text("%d" % sim.player.materials, Vector2(rect.position.x + 50.0, 43.0), 29,
			UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 80.0)
	_text(Loc.t("hud.materials"), Vector2(rect.position.x + 53.0, 58.0), 12,
			UiTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 88.0)


func material_expression() -> StringName:
	if sim == null or sim.player.materials <= 0:
		return &"empty"
	return &"collected" if _mat_pulse > 0.0 and not reduced_effects else &"rest"


func _draw_weapons() -> void:
	for i in Content.MAX_WEAPON_SLOTS:
		var slot := weapon_slot_rect(i)
		var stock := _stock(StringName("weapon_%d" % i), ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, i + 1)
		stock.bg_color = ArenaPainter.PAPER if i < sim.player.weapons.size() else ArenaPainter.PAPER.darkened(0.18)
		stock.border_color = ArenaPainter.INK
		if i < _flash.size() and not reduced_effects:
			stock.border_color = ArenaPainter.INK.lerp(UiTheme.COIN, _flash[i])
		stock.draw(get_canvas_item(), slot)
		if i < sim.player.weapons.size():
			var weapon: WeaponDef = sim.player.weapons[i]
			var ready := weapon_ready(i)
			var key := PresentationAssets.weapon_key(weapon)
			var texture := PresentationAssets.texture(key)
			var source := PresentationAssets.region(key)
			if texture != null and source.has_area():
				var thumb := _weapon_thumbnail_rect(slot, source.size)
				draw_texture_rect_region(texture, thumb, source, Color(1.0, 1.0, 1.0, 0.98))
			if ready < 0.995:
				var radius := minf(slot.size.x, slot.size.y) * 0.38
				draw_arc(slot.get_center(), radius, -PI * 0.5, TAU - PI * 0.5, 20,
						Color(ArenaPainter.INK, 0.18), 2.0)
				if ready > 0.01:
					draw_arc(slot.get_center(), radius, -PI * 0.5, -PI * 0.5 + TAU * ready,
							20, UiTheme.ACCENT, 2.3)


func weapon_slot_rect(index: int) -> Rect2:
	return Rect2(40.0 + float(index) * SLOT_GAP, SLOT_Y + (1.0 if index % 2 == 0 else -1.0), SLOT_W, SLOT_H)


func gunsmith_remaining() -> int:
	if sim == null or not bool(sim.player.set_bonus_applied.get(&"gunsmith", false)):
		return -1
	return 6 - (sim.player_shots % 6)


func _draw_gunsmith_charge() -> void:
	var remaining := gunsmith_remaining()
	if remaining < 0:
		return
	var text := Loc.t("hud.crit_next") if remaining == 1 else Loc.t("hud.crit_charge", [remaining])
	var width := UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x + 32.0
	_stock(&"gunsmith_tag", ArenaPainter.PAPER, InkStyleBox.Shape.TAG, 1).draw(get_canvas_item(),
			Rect2(312.0, 687.0, width, 30.0))
	draw_circle(Vector2(323.0, 702.0), 2.5, UiTheme.WARN if remaining == 1 else UiTheme.COIN)
	_text(text, Vector2(332.0, 705.0), 13, UiTheme.INK)


static func _weapon_thumbnail_rect(slot: Rect2, source_size: Vector2) -> Rect2:
	var area := slot.grow(-3.0)
	var fitted := ArenaPainter._contained_size(source_size, area.size)
	return Rect2(area.get_center() - fitted * 0.5, fitted)


func _draw_controls() -> void:
	var size := 14
	var label_w := UiTheme.font()
	if sim.can_collapse_echo():
		var hint := Loc.t("hud.collapse")
		var profile := collapse_hint_profile(hint)
		var rect: Rect2 = profile["rect"]
		var foreground: Color = profile["foreground"]
		_stock(&"collapse_hint", profile["background"], InkStyleBox.Shape.TAG, 2).draw(get_canvas_item(), rect)
		_keycap("SPACE", Vector2(40.0, 654.0), 12)
		_text(hint, Vector2(40.0 + _keycap_width("SPACE", 12) + 8.0, 670.0), 12, foreground)
	var move_label := Loc.t("hud.move")
	var pause_label := Loc.t("hud.pause")
	var move_w := _keycap_width("WASD", size) + 8.0 + label_w.get_string_size(move_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var pause_w := _keycap_width("P", size) + 8.0 + label_w.get_string_size(pause_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var x := 1240.0 - move_w - 18.0 - pause_w
	_stock(&"controls_tag", ArenaPainter.PAPER, InkStyleBox.Shape.TAG, 4).draw(get_canvas_item(),
			Rect2(x - 9.0, 687.0, move_w + pause_w + 36.0, 31.0))
	_keycap("WASD", Vector2(x, 694.0), size)
	_text(move_label, Vector2(x + _keycap_width("WASD", size) + 8.0, 709.0), size, UiTheme.DIM)
	x += move_w + 18.0
	_keycap("P", Vector2(x, 694.0), size)
	_text(pause_label, Vector2(x + _keycap_width("P", size) + 8.0, 709.0), size, UiTheme.DIM)


# The entire action hint sits on opaque stock, so it stays readable over any arena art.
func collapse_hint_profile(hint: String) -> Dictionary:
	var label_width := UiTheme.font().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	var width := _keycap_width("SPACE", 12) + 8.0 + label_width + 12.0
	return {"rect": Rect2(36.0, 650.0, width + 4.0, 28.0),
		"foreground": ArenaPainter.INK, "background": ArenaPainter.PAPER}


func _draw_onboarding() -> void:
	if paused:
		return
	var alpha := hint_alpha()
	if alpha <= 0.0:
		return
	var panel := Rect2(450.0, 604.0, 380.0, 48.0)
	var stock := _stock(&"onboarding", ArenaPainter.PAPER, InkStyleBox.Shape.TAG, 3)
	stock.bg_color = Color(ArenaPainter.PAPER, alpha)
	stock.border_color = Color(ArenaPainter.INK, alpha)
	stock.draw(get_canvas_item(), panel)
	var size := 16
	var x := panel.position.x + 18.0
	_keycap("WASD", Vector2(x, panel.position.y + 14.0), size, alpha)
	x += _keycap_width("WASD", size) + 8.0
	_text(Loc.t("hud.move"), Vector2(x, panel.position.y + 29.0), size, Color(UiTheme.DIM, alpha))
	x += UiTheme.font().get_string_size(Loc.t("hud.move"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + 22.0
	# A small burst glyph reads as "this happens by itself".
	var c := Vector2(x + 8.0, panel.position.y + 24.0)
	for k in 6:
		var dir := Vector2.from_angle(TAU * float(k) / 6.0)
		draw_line(c + dir * 4.0, c + dir * 9.0, Color(UiTheme.COIN, alpha), 2.0)
	draw_circle(c, 3.0, Color(UiTheme.COIN, alpha))
	_text(Loc.t("hud.auto_fire"), Vector2(x + 24.0, panel.position.y + 29.0), size, Color(UiTheme.INK, alpha))


func _draw_debug() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(1.0, float(fps))
	var lines := PackedStringArray([
		"FPS %d  ·  %.1f ms" % [fps, frame_ms],
		"Wave %d  ·  seed %d" % [sim.wave, sim.run_seed],
		"Enemies %d  ·  shots %d" % [sim.enemies.size(), sim.projectiles.size()],
		"Echoes %d  ·  v%s" % [sim.echoes.size(), str(ProjectSettings.get_setting("application/config/version", ""))],
	])
	var panel := Rect2(16.0, 84.0, 336.0, 22.0 * float(lines.size()) + 16.0)
	_paper_panel(panel)
	for i in lines.size():
		_text(lines[i], Vector2(28.0, 104.0 + float(i) * 22.0), 14, UiTheme.INK)


func _keycap_width(label: String, size: int) -> float:
	return UiTheme.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + 14.0


func _keycap(label: String, pos: Vector2, size: int, alpha: float = 1.0) -> void:
	var w := _keycap_width(label, size)
	var stock := _stock(StringName("key_%s" % label), ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, label.length())
	stock.bg_color = Color(ArenaPainter.PAPER, alpha)
	stock.border_color = Color(ArenaPainter.INK, 0.85 * alpha)
	stock.draw(get_canvas_item(), Rect2(pos, Vector2(w, 22.0)))
	_text(label, pos + Vector2(7.0, 16.0), size, Color(UiTheme.INK, alpha))


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	if on:
		_critical_poke = 0.0
	queue_redraw()


func _paper_panel(rect: Rect2) -> void:
	_stock(&"debug", ArenaPainter.PAPER, InkStyleBox.Shape.PAPER, 7).draw(get_canvas_item(), rect)


func _stock(key: StringName, fill: Color, shape: int = 0, variant: int = 0) -> InkStyleBox:
	if not _ink_stocks.has(key):
		var stock := UiTheme.paper_panel(fill)
		stock.shape = shape
		stock.variant = posmod(variant, 8)
		stock.shadow_offset = Vector2(1.0, 1.0)
		stock.shadow_size = 0.0
		_ink_stocks[key] = stock
	return _ink_stocks[key] as InkStyleBox


# Static hand-ink strokes are cached per meter. Only the short visible prefix changes.
func _meter_path(key: StringName, rect: Rect2) -> PackedVector2Array:
	var cache_key := "%s:%s" % [key, rect]
	if not _meter_paths.has(cache_key):
		var points := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			points.append(rect.position + Vector2(rect.size.x * t,
					rect.size.y * 0.5 + sin(t * TAU * 1.2) * minf(1.2, rect.size.y * 0.18)))
		_meter_paths[cache_key] = points
	return _meter_paths[cache_key]


func _meter(rect: Rect2, ratio: float, fill: Color, background: Color,
		key: StringName, width: float) -> void:
	var points := _meter_path(key, rect)
	draw_polyline(points, Color(ArenaPainter.INK, background.a), width + 2.4, true)
	draw_polyline(points, background, width, true)
	draw_circle(points[0], width * 0.5, background)
	draw_circle(points[points.size() - 1], width * 0.5, background)
	_meter_fill(points, ratio, fill, width)


func _meter_fill(points: PackedVector2Array, ratio: float, color: Color, width: float) -> void:
	var shown := meter_prefix(points, ratio)
	if shown.size() < 2:
		return
	draw_polyline(shown, color, width, true)
	draw_circle(shown[0], width * 0.5, color)
	draw_circle(shown[shown.size() - 1], width * 0.5, color)


static func meter_prefix(points: PackedVector2Array, ratio: float) -> PackedVector2Array:
	if points.size() < 2 or not is_finite(ratio) or ratio <= 0.0:
		return PackedVector2Array()
	if ratio >= 1.0:
		return points
	var progress := float(points.size() - 1) * ratio
	var index := int(floor(progress))
	var shown := points.slice(0, index + 1)
	shown.append(points[index].lerp(points[index + 1], progress - float(index)))
	return shown


func _title_text(txt: String, pos: Vector2, size: int, color: Color = UiTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(UiTheme.title_font(), pos, txt, align, width, size, color)


func _text(txt: String, pos: Vector2, size: int, color: Color = UiTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(UiTheme.font(), pos, txt, align, width, size, color)
