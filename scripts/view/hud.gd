class_name Hud
extends Control

const WIDTH := 1280.0
const BAR_H := 72.0

var sim: Sim
var paused: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(s: Sim) -> void:
	sim = s


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(0.0, 0.0, WIDTH, BAR_H), Color(0.02, 0.02, 0.05, 0.85))
	draw_line(Vector2(0.0, BAR_H), Vector2(WIDTH, BAR_H), Color(0.25, 0.4, 0.8, 0.35), 2.0)
	_draw_health()
	_draw_echo_chips()
	_draw_wave()
	_draw_materials()
	_draw_loadout()
	if paused:
		draw_rect(Rect2(0.0, 0.0, WIDTH, 720.0), Color(0.0, 0.0, 0.0, 0.55))
		_text(Loc.t("hud.paused"), Vector2(0.0, 366.0), 30, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, WIDTH)


func _draw_health() -> void:
	var pl := sim.player
	var ratio := clampf(pl.hp / pl.max_hp(), 0.0, 1.0)
	draw_rect(Rect2(40.0, 12.0, 300.0, 22.0), Color(0.12, 0.05, 0.08))
	draw_rect(Rect2(40.0, 12.0, 300.0 * ratio, 22.0), Color(1.0, 0.3, 0.45))
	draw_rect(Rect2(40.0, 12.0, 300.0, 22.0), Color(1, 1, 1, 0.35), false, 2.0)
	_text("%s  %d / %d" % [Loc.t("hud.hp"), ceili(pl.hp), int(pl.max_hp())], Vector2(50.0, 29.0), 16)


func _draw_echo_chips() -> void:
	_text(Loc.t("hud.echo"), Vector2(40.0, 62.0), 14, UiTheme.DIM)
	for i in sim.echo_capacity():
		var chip := Rect2(112.0 + float(i) * 26.0, 48.0, 20.0, 14.0)
		if i < sim.echoes.size() and sim.phase == Sim.Phase.WAVE:
			draw_rect(chip, sim.echoes[i].take.tint())
		else:
			draw_rect(chip, Color(1, 1, 1, 0.3), false, 1.5)


func _draw_wave() -> void:
	var title := Loc.t("hud.wave", [sim.wave, WaveDirector.FINAL_WAVE])
	_text(title, Vector2(440.0, 36.0), 28, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, 400.0)
	var ratio := clampf(sim.wave_time / maxf(0.01, sim.wave_duration), 0.0, 1.0)
	draw_rect(Rect2(540.0, 48.0, 200.0, 6.0), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(540.0, 48.0, 200.0 * ratio, 6.0), UiTheme.ACCENT)
	var left := ceili(maxf(0.0, sim.wave_duration - sim.wave_time))
	_text("%d" % left, Vector2(750.0, 56.0), 16, UiTheme.DIM)


func _draw_materials() -> void:
	var amount := "%d" % sim.player.materials
	var text_width := UiTheme.font().get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
	draw_circle(Vector2(1240.0 - text_width - 16.0, 25.0), 8.0, UiTheme.COIN)
	_text(amount, Vector2(1000.0, 36.0), 28, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT, 240.0)
	_text(Loc.t("hud.materials"), Vector2(1000.0, 62.0), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 240.0)


func _draw_loadout() -> void:
	for i in Content.MAX_WEAPON_SLOTS:
		var slot := Rect2(40.0 + float(i) * 34.0, 692.0, 28.0, 20.0)
		if i < sim.player.weapons.size():
			draw_rect(slot, sim.player.weapons[i].color)
		else:
			draw_rect(slot, Color(1, 1, 1, 0.25), false, 1.5)
	_text(Loc.t("hud.controls"), Vector2(500.0, 708.0), 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 740.0)


func _text(txt: String, pos: Vector2, size: int, color: Color = UiTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(UiTheme.font(), pos, txt, align, width, size, color)
