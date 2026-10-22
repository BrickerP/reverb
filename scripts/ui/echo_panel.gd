class_name EchoPanel
extends PanelContainer

signal discard_requested(take: EchoTake)
signal merge_requested(a: EchoTake, b: EchoTake)

var discard_buttons: Array[Button] = []
var merge_button: Button
var last_new_row: Control
var last_new_tint: Color = Color.WHITE

var _box: VBoxContainer
var _sim: Sim
var _animate_new := false
var _merge_mode := false
var _merge_first: EchoTake


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


func refresh(sim: Sim, animate_new: bool = false) -> void:
	_sim = sim
	_animate_new = animate_new
	_merge_mode = false
	_merge_first = null
	_render()
	_animate_new = false


func is_merging() -> bool:
	return _merge_mode


func _render() -> void:
	UiTheme.clear(_box)
	discard_buttons.clear()
	merge_button = null
	if _sim == null:
		return
	var sim := _sim
	var capacity := sim.echo_capacity()
	var over := sim.bank.overflow(capacity)
	var heading := Loc.t("shop.echoes", [sim.bank.takes.size(), capacity])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := UiTheme.label(heading, 22, UiTheme.WARN if over > 0 else UiTheme.ECHO)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if capacity > 0 and not sim.bank.takes.is_empty():
		merge_button = Button.new()
		merge_button.text = Loc.t("shop.cancel") if _merge_mode else Loc.t("shop.merge")
		merge_button.custom_minimum_size = Vector2(72.0, 30.0)
		merge_button.disabled = not _merge_mode and sim.bank.takes.size() < 2
		merge_button.pressed.connect(_on_merge_button)
		head.add_child(merge_button)
	_box.add_child(head)
	if _merge_mode:
		var hint := UiTheme.label(Loc.t("shop.merge_hint"), 14, UiTheme.ACCENT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(hint)
	if capacity <= 0:
		var none := UiTheme.label(Loc.t("shop.echo_none_slots"), 16, UiTheme.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(none)
		return
	if sim.bank.takes.is_empty():
		var hint := UiTheme.label(Loc.t("shop.echo_none"), 16, UiTheme.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(hint)
		return
	var lifespan := sim.echo_lifespan()
	var best := 1.0
	for take: EchoTake in sim.bank.takes:
		best = maxf(best, sim.echo_dps(take))
	var newest_first := sim.bank.takes.duplicate()
	newest_first.reverse()
	var new_row: Control = null
	last_new_row = null
	last_new_tint = Color.WHITE
	for take: EchoTake in newest_first:
		var is_new := _animate_new and take.age == 0
		var row := _row(take, sim, lifespan, best, is_new, take == _merge_first)
		_box.add_child(row)
		if is_new:
			new_row = row
			last_new_row = row
			last_new_tint = take.tint()
	if new_row != null:
		_animate_new_row(new_row)


func focus_first_discard() -> bool:
	if discard_buttons.is_empty():
		return false
	discard_buttons[0].grab_focus()
	return true


func arrival_point() -> Vector2:
	if last_new_row == null or not last_new_row.is_inside_tree():
		return Vector2.ZERO
	var rect := last_new_row.get_global_rect()
	return Vector2(rect.position.x + 2.0, rect.position.y + rect.size.y * 0.5)


func newest_tint() -> Color:
	return last_new_tint


func _row(take: EchoTake, sim: Sim, lifespan: int, best: float, animate: bool, selected: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var strip := ColorRect.new()
	strip.color = Color(UiTheme.ACCENT, 0.95) if selected else Color(take.tint(), 0.9)
	strip.custom_minimum_size = Vector2(6.0 if selected else 4.0, 0.0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(strip)
	var preview := PathPreview.new()
	preview.setup(take, animate)
	row.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(_title_line(take))
	var dps := int(round(sim.echo_dps(take)))
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
	var loadout := UiTheme.label(Loc.t("shop.live_loadout") if sim.live_echo else _loadout(take), 14, UiTheme.DIM)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(loadout)
	row.add_child(info)
	var button := Button.new()
	if _merge_mode:
		button.text = Loc.t("shop.selected") if selected else Loc.t("shop.select")
	else:
		button.text = Loc.t("shop.discard")
	button.custom_minimum_size = Vector2(84.0, 40.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_row.bind(take))
	discard_buttons.append(button)
	row.add_child(button)
	return row


func _on_row(take: EchoTake) -> void:
	if not _merge_mode:
		discard_requested.emit(take)
		return
	if _merge_first == take:
		_merge_first = null
		_render()
		focus_first_discard()
		return
	if _merge_first == null:
		_merge_first = take
		_render()
		focus_first_discard()
		return
	var first := _merge_first
	_merge_mode = false
	_merge_first = null
	merge_requested.emit(first, take)


func _on_merge_button() -> void:
	_merge_mode = not _merge_mode
	_merge_first = null
	_render()
	if _merge_mode:
		focus_first_discard()
	elif merge_button != null:
		merge_button.grab_focus()


func _animate_new_row(row: Control) -> void:
	# Keep the action button at full contrast (it may hold keyboard focus); only the
	# identity strip and the take's text fade in.
	var strip := row.get_child(0) as Control
	var info := row.get_child(2) as Control
	if strip == null or info == null:
		return
	strip.modulate.a = 0.25
	info.modulate.a = 0.35
	var tween := row.create_tween()
	tween.set_parallel(true)
	tween.tween_property(strip, "modulate:a", 1.0, 0.55).set_delay(0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(info, "modulate:a", 1.0, 0.55).set_delay(0.1).set_ease(Tween.EASE_OUT)


func _title_line(take: EchoTake) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(UiTheme.label(Loc.t("shop.take", [take.wave]), 16))
	if take.merged:
		line.add_child(UiTheme.label("[%s]" % Loc.t("shop.merged"), 13, UiTheme.COIN))
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
