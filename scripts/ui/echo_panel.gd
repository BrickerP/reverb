class_name EchoPanel
extends PanelContainer

signal discard_requested(take: EchoTake)

var discard_buttons: Array[Button] = []
var _box: VBoxContainer


class TakeMeter:
	extends Control

	var ratio: float = 0.0
	var tint: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), Color(tint, 0.9))


func _init() -> void:
	custom_minimum_size = Vector2(448.0, 0.0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh(sim: Sim) -> void:
	UiTheme.clear(_box)
	discard_buttons.clear()
	var capacity := sim.echo_capacity()
	var over := sim.bank.overflow(capacity)
	var heading := Loc.t("shop.echoes", [sim.bank.takes.size(), capacity])
	_box.add_child(UiTheme.label(heading, 22, UiTheme.WARN if over > 0 else UiTheme.ECHO))
	if sim.bank.takes.is_empty():
		var hint := UiTheme.label(Loc.t("shop.echo_none"), 16, UiTheme.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(hint)
		return
	var lifespan := sim.echo_lifespan()
	var best := 1.0
	for take: EchoTake in sim.bank.takes:
		best = maxf(best, take.power() * sim.echo_power())
	var newest_first := sim.bank.takes.duplicate()
	newest_first.reverse()
	for take: EchoTake in newest_first:
		_box.add_child(_row(take, sim, lifespan, best))


func focus_first_discard() -> bool:
	if discard_buttons.is_empty():
		return false
	discard_buttons[0].grab_focus()
	return true


func _row(take: EchoTake, sim: Sim, lifespan: int, best: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var strip := ColorRect.new()
	strip.color = Color(take.tint(), 0.9)
	strip.custom_minimum_size = Vector2(4.0, 0.0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(strip)
	var preview := PathPreview.new()
	preview.setup(take)
	row.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(_title_line(take))
	var dps := int(round(take.power() * sim.echo_power()))
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	meta.add_child(_pips(maxi(0, lifespan - take.age), lifespan, take.tint()))
	var dps_label := UiTheme.label(Loc.t("shop.take_dps", [dps]), 14, UiTheme.DIM)
	dps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(dps_label)
	info.add_child(meta)
	var meter := TakeMeter.new()
	meter.tint = take.tint()
	meter.ratio = float(dps) / maxf(1.0, best)
	info.add_child(meter)
	var loadout := UiTheme.label(_loadout(take), 14, UiTheme.DIM)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(loadout)
	row.add_child(info)
	var button := Button.new()
	button.text = Loc.t("shop.discard")
	button.custom_minimum_size = Vector2(84.0, 40.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_discard.bind(take))
	discard_buttons.append(button)
	row.add_child(button)
	return row


func _title_line(take: EchoTake) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(UiTheme.label(Loc.t("shop.take", [take.wave]), 16))
	if take.age == 0:
		line.add_child(UiTheme.label("[%s]" % Loc.t("shop.new"), 13, UiTheme.ACCENT))
	return line


func _pips(remaining: int, total: int, tint: Color) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	for k in maxi(1, total):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(10.0, 6.0)
		pip.color = Color(tint, 0.9) if k < remaining else Color(1, 1, 1, 0.14)
		line.add_child(pip)
	return line


func _loadout(take: EchoTake) -> String:
	var counts: Dictionary = {}
	for w in take.weapons:
		counts[w.id] = int(counts.get(w.id, 0)) + 1
	var parts := PackedStringArray()
	for id: StringName in counts:
		var n: int = counts[id]
		parts.append("%s ×%d" % [Loc.weapon_name(id), n] if n > 1 else Loc.weapon_name(id))
	return ", ".join(parts)


func _on_discard(take: EchoTake) -> void:
	discard_requested.emit(take)
