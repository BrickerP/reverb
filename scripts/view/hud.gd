class_name Hud
extends Control

const WIDTH := 1280.0
const BAR_H := 72.0
const SLOT_Y := 688.0
const SLOT_W := 30.0
const SLOT_H := 24.0
const SLOT_GAP := 38.0

var sim: Sim
var paused: bool = false
var debug: bool = false

var _hp_ghost := 1.0
var _prev_cd: Array[float] = []
var _flash: Array[float] = []
var _prev_materials := 0
var _mat_pulse := 0.0
var _hint_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(s: Sim) -> void:
	sim = s
	_hp_ghost = clampf(s.player.hp / maxf(1.0, s.player.max_hp()), 0.0, 1.0)
	_prev_cd.clear()
	_flash.clear()
	for _w in s.player.weapons:
		_prev_cd.append(0.0)
		_flash.append(0.0)
	_prev_materials = s.player.materials
	_mat_pulse = 0.0
	_hint_time = 0.0


# 0 = just fired, 1 = ready. Drives the fill in each weapon slot.
func weapon_ready(index: int) -> float:
	if sim == null or index < 0 or index >= sim.player.weapons.size():
		return 0.0
	var w := sim.player.weapons[index]
	var duration := maxf(0.01, w.cooldown * sim.player.stats.cooldown_mult())
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
	if sim == null:
		return
	var ratio := clampf(sim.player.hp / maxf(1.0, sim.player.max_hp()), 0.0, 1.0)
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
	draw_rect(Rect2(0.0, 0.0, WIDTH, BAR_H), Color(0.02, 0.02, 0.05, 0.88))
	draw_line(Vector2(0.0, BAR_H), Vector2(WIDTH, BAR_H), Color(0.25, 0.4, 0.8, 0.35), 2.0)
	_draw_health()
	_draw_echo_chips()
	_draw_wave()
	_draw_materials()
	_draw_weapons()
	_draw_controls()
	_draw_onboarding()
	if debug:
		_draw_debug()


func _draw_health() -> void:
	var pl := sim.player
	var ratio := clampf(pl.hp / maxf(1.0, pl.max_hp()), 0.0, 1.0)
	var low := ratio < 0.3
	var bar := Rect2(40.0, 12.0, 300.0, 22.0)
	draw_rect(bar, Color(0.12, 0.05, 0.08))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp_ghost, bar.size.y)), Color(1.0, 0.35, 0.45, 0.35))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(1.0, 0.3, 0.45))
	if pl.max_hp() >= 40.0:
		var step := bar.size.x * 10.0 / pl.max_hp()
		if step >= 10.0:
			var x := bar.position.x + step
			while x < bar.end.x - 1.0:
				draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.25), 1.0)
				x += step
	var border := Color(1.0, 0.3, 0.4, 0.55)
	if low:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0)
		border = Color(1.0, 0.25, 0.35, 0.5 + 0.5 * pulse)
	draw_rect(bar, border, false, 2.0)
	_text("%s  %d / %d" % [Loc.t("hud.hp"), ceili(pl.hp), int(pl.max_hp())], Vector2(50.0, 29.0), 16)


func _draw_echo_chips() -> void:
	if sim.echo_capacity() <= 0:
		return
	_text(Loc.t("hud.echo"), Vector2(40.0, 62.0), 14, UiTheme.DIM)
	var lifespan := sim.echo_lifespan()
	var now := Time.get_ticks_msec() / 1000.0
	var muted := sim.echo_silenced > 0.0
	for i in sim.echo_capacity():
		var chip := Rect2(112.0 + float(i) * 28.0, 46.0, 22.0, 16.0)
		if i < sim.echoes.size():
			var take := sim.echoes[i].take
			var remaining := echo_remaining(take)
			var tint := take.tint()
			draw_rect(chip, Color(tint, 0.35 if muted else 0.9))
			var segments := maxi(1, lifespan)
			var seg_w := 20.0 / float(segments)
			for k in segments:
				var filled := k < remaining
				var pip := Rect2(chip.position.x + 1.0 + float(k) * seg_w, chip.position.y + 11.0, seg_w - 1.0, 4.0)
				var pip_col := Color(1, 1, 1, 0.35 if muted else 0.85) if filled else Color(0.02, 0.03, 0.08, 0.55)
				draw_rect(pip, pip_col)
			if remaining <= 1:
				var pulse := 0.5 + 0.5 * sin(now * 8.0)
				draw_rect(chip.grow(1.0), Color(UiTheme.WARN, 0.35 + 0.55 * pulse), false, 1.5)
		else:
			draw_rect(chip, Color(1, 1, 1, 0.28), false, 1.5)
	if muted:
		var width := float(sim.echo_capacity()) * 28.0 - 6.0
		var ratio := clampf(sim.echo_silenced / Sim.BOSS_SILENCE_TIME, 0.0, 1.0)
		draw_rect(Rect2(112.0, 64.0, width, 3.0), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(112.0, 64.0, width * ratio, 3.0), UiTheme.WARN)


func _draw_wave() -> void:
	var boss_wave := sim.wave == WaveDirector.FINAL_WAVE
	if boss_wave:
		if sim.boss != null and sim.boss.dead:
			_text(Loc.t("hud.boss_down"), Vector2(440.0, 34.0), 26, UiTheme.COIN,
					HORIZONTAL_ALIGNMENT_CENTER, 400.0)
		else:
			_text(Loc.t("hud.boss"), Vector2(440.0, 34.0), 26, Color(0.9, 0.8, 1.0),
					HORIZONTAL_ALIGNMENT_CENTER, 400.0)
			var boss_bar := Rect2(460.0, 44.0, 360.0, 8.0)
			draw_rect(boss_bar, Color(1, 1, 1, 0.1))
			var boss_ratio := 0.0
			if sim.boss != null:
				boss_ratio = clampf(sim.boss.hp / maxf(1.0, sim.boss.max_hp), 0.0, 1.0)
			draw_rect(Rect2(boss_bar.position, Vector2(boss_bar.size.x * boss_ratio, boss_bar.size.y)),
					Color(0.8, 0.5, 1.0))
			draw_rect(boss_bar, Color(0.8, 0.5, 1.0, 0.7), false, 1.5)
	else:
		var title := Loc.t("hud.wave", [sim.wave, WaveDirector.FINAL_WAVE])
		_text(title, Vector2(440.0, 34.0), 28, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
		var left := ceili(maxf(0.0, sim.wave_duration - sim.wave_time))
		var urgent := left <= 5
		var bar := Rect2(520.0, 44.0, 240.0, 6.0)
		draw_rect(bar, Color(1, 1, 1, 0.12))
		var ratio := clampf(sim.wave_time / maxf(0.01, sim.wave_duration), 0.0, 1.0)
		var col := UiTheme.WARN if urgent else UiTheme.ACCENT
		if urgent:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)
			col = Color(col, pulse)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)
		_text("%d" % left, Vector2(768.0, 54.0), 16, UiTheme.WARN if urgent else UiTheme.DIM)
	# One pip per wave: the run's position at a glance.
	var count := WaveDirector.FINAL_WAVE
	var pip_w := 8.0
	var gap := 2.0
	var total := float(count) * pip_w + float(count - 1) * gap
	var x := 640.0 - total * 0.5
	var base_y := 60.0 if boss_wave else 56.0
	for i in count:
		var current := i == sim.wave - 1
		var pip := Rect2(x + float(i) * (pip_w + gap), base_y - (1.0 if current else 0.0), pip_w,
				7.0 if current else 5.0)
		if i < sim.wave - 1:
			draw_rect(pip, Color(UiTheme.ACCENT, 0.55))
		elif current:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
			draw_rect(pip, Color(1, 1, 1, pulse))
		else:
			draw_rect(pip, Color(1, 1, 1, 0.12))


func _draw_materials() -> void:
	var amount := "%d" % sim.player.materials
	var text_width := UiTheme.font().get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
	var coin := Vector2(1240.0 - text_width - 16.0, 25.0)
	if _mat_pulse > 0.0:
		draw_arc(coin, 8.0 + 14.0 * (1.0 - _mat_pulse), 0.0, TAU, 20, Color(UiTheme.COIN, _mat_pulse * 0.6), 2.0)
	draw_circle(coin, 8.0, UiTheme.COIN)
	_text(amount, Vector2(1000.0, 36.0), 28, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT, 240.0)
	_text(Loc.t("hud.materials"), Vector2(1000.0, 62.0), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 240.0)


func _draw_weapons() -> void:
	for i in Content.MAX_WEAPON_SLOTS:
		var slot := Rect2(40.0 + float(i) * SLOT_GAP, SLOT_Y, SLOT_W, SLOT_H)
		if i < sim.player.weapons.size():
			var w := sim.player.weapons[i]
			var ready := weapon_ready(i)
			draw_rect(slot, Color(w.color, 0.2))
			var fill_h := slot.size.y * ready
			draw_rect(Rect2(slot.position.x, slot.end.y - fill_h, slot.size.x, fill_h), Color(w.color, 0.95))
			draw_rect(slot, Color(1, 1, 1, 0.25), false, 1.0)
			if i < _flash.size() and _flash[i] > 0.0:
				draw_rect(slot.grow(1.0), Color(1, 1, 1, _flash[i] * 0.9), false, 2.0)
		else:
			draw_rect(slot, Color(1, 1, 1, 0.22), false, 1.5)


func _draw_controls() -> void:
	var size := 14
	var label_w := UiTheme.font()
	var move_label := Loc.t("hud.move")
	var pause_label := Loc.t("hud.pause")
	var move_w := _keycap_width("WASD", size) + 8.0 + label_w.get_string_size(move_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var pause_w := _keycap_width("P", size) + 8.0 + label_w.get_string_size(pause_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var x := 1240.0 - move_w - 18.0 - pause_w
	_keycap("WASD", Vector2(x, 694.0), size)
	_text(move_label, Vector2(x + _keycap_width("WASD", size) + 8.0, 709.0), size, UiTheme.DIM)
	x += move_w + 18.0
	_keycap("P", Vector2(x, 694.0), size)
	_text(pause_label, Vector2(x + _keycap_width("P", size) + 8.0, 709.0), size, UiTheme.DIM)


func _draw_onboarding() -> void:
	if paused:
		return
	var alpha := hint_alpha()
	if alpha <= 0.0:
		return
	var panel := Rect2(450.0, 604.0, 380.0, 48.0)
	draw_rect(panel, Color(0.02, 0.03, 0.08, 0.72 * alpha))
	draw_rect(panel, Color(UiTheme.ACCENT, 0.35 * alpha), false, 1.0)
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
	draw_rect(panel, Color(0.01, 0.02, 0.05, 0.84))
	draw_rect(panel, Color(0.35, 0.55, 0.95, 0.45), false, 1.0)
	for i in lines.size():
		_text(lines[i], Vector2(28.0, 104.0 + float(i) * 22.0), 14, UiTheme.INK)


func _keycap_width(label: String, size: int) -> float:
	return UiTheme.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + 14.0


func _keycap(label: String, pos: Vector2, size: int, alpha: float = 1.0) -> void:
	var w := _keycap_width(label, size)
	var rect := Rect2(pos, Vector2(w, 22.0))
	draw_rect(rect, Color(0.08, 0.1, 0.2, 0.95 * alpha))
	draw_rect(rect, Color(0.4, 0.55, 0.9, 0.6 * alpha), false, 1.0)
	_text(label, pos + Vector2(7.0, 16.0), size, Color(UiTheme.INK, alpha))


func _text(txt: String, pos: Vector2, size: int, color: Color = UiTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(UiTheme.font(), pos, txt, align, width, size, color)
