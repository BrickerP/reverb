class_name EchoPanel
extends PanelContainer

signal discard_requested(take: EchoTake)
signal merge_requested(a: EchoTake, b: EchoTake)
signal refresh_requested(take: EchoTake)

var discard_buttons: Array[Button] = []
var refresh_buttons: Array[Button] = []
var merge_button: Button
var last_new_row: Control
var last_new_tint: Color = Color.WHITE
var reduced_effects := false

var _box: VBoxContainer
var _sim: Sim
var _animate_new := false
var _merge_mode := false
var _merge_first: EchoTake
var _new_row_tween: Tween
var _animated_strip: Control
var _animated_info: Control


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
	var surface_source := UiTheme.surface_panel()
	if surface_source != null:
		var surface := surface_source.duplicate() as StyleBoxTexture
		surface.region_rect = Rect2(32.0, 32.0, 448.0, 448.0)
		surface.texture_margin_left = 10.0
		surface.texture_margin_right = 10.0
		surface.texture_margin_top = 10.0
		surface.texture_margin_bottom = 10.0
		surface.content_margin_left = 12.0
		surface.content_margin_right = 12.0
		surface.content_margin_top = 8.0
		surface.content_margin_bottom = 8.0
		add_theme_stylebox_override("panel", surface)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh(sim: Sim, animate_new: bool = false) -> void:
	_sim = sim
	_animate_new = animate_new and not reduced_effects
	_merge_mode = false
	_merge_first = null
	_render()
	_animate_new = false


func close_session() -> void:
	_finish_new_row_animation()
	_sim = null
	_animate_new = false
	_merge_mode = false
	_merge_first = null
	discard_buttons.clear()
	refresh_buttons.clear()
	merge_button = null
	last_new_row = null
	last_new_tint = Color.WHITE
	UiTheme.clear(_box)


func is_merging() -> bool:
	return _merge_mode


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	if on:
		_finish_new_row_animation()
		for preview in find_children("*", "PathPreview", true, false):
			(preview as PathPreview).finish_immediately()


func cancel_merge() -> bool:
	if not _merge_mode:
		return false
	_merge_mode = false
	_merge_first = null
	_render()
	if merge_button != null:
		merge_button.grab_focus()
	return true


func _render() -> void:
	_finish_new_row_animation()
	UiTheme.clear(_box)
	discard_buttons.clear()
	refresh_buttons.clear()
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
	preview.setup(take, animate and not reduced_effects)
	var cartridge := UiTheme.cartridge_icon(Vector2(30.0, 20.0))
	cartridge.position = Vector2(76.0, 3.0)
	preview.add_child(cartridge)
	row.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(_title_line(take))
	var dps := int(round(sim.echo_dps(take)))
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 8)
	meta.add_theme_constant_override("v_separation", 2)
	meta.add_child(_pips(maxi(0, lifespan - take.age), lifespan, take.tint()))
	if take.merged:
		meta.add_child(UiTheme.label("[%s]" % Loc.t("shop.merged"), 12, UiTheme.COIN))
	if take.age == 0:
		meta.add_child(UiTheme.label("[%s]" % Loc.t("shop.new"), 12, UiTheme.ACCENT))
	var dps_label := UiTheme.label(Loc.t("shop.take_dps", [dps]), 14, UiTheme.DIM)
	meta.add_child(dps_label)
	if not _merge_mode and take.age > 0:
		var cost := sim.shop.echo_refresh_cost(take)
		var refresh := Button.new()
		refresh.text = Loc.t("shop.refresh", [cost])
		refresh.disabled = sim.player.materials < cost
		refresh.custom_minimum_size = Vector2(0.0, 28.0)
		refresh.add_theme_font_size_override("font_size", 12)
		refresh.pressed.connect(_on_refresh.bind(take))
		refresh_buttons.append(refresh)
		meta.add_child(refresh)
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


func _on_refresh(take: EchoTake) -> void:
	refresh_requested.emit(take)


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
	if _merge_mode:
		cancel_merge()
		return
	_merge_mode = not _merge_mode
	_merge_first = null
	_render()
	if _merge_mode:
		focus_first_discard()
	elif merge_button != null:
		merge_button.grab_focus()


func _animate_new_row(row: Control) -> void:
	if reduced_effects:
		return
	# Keep the action button at full contrast (it may hold keyboard focus); only the
	# identity strip and the take's text fade in.
	var strip := row.get_child(0) as Control
	var info := row.get_child(2) as Control
	if strip == null or info == null:
		return
	strip.modulate.a = 0.25
	info.modulate.a = 0.35
	_animated_strip = strip
	_animated_info = info
	_new_row_tween = row.create_tween().set_parallel(true)
	_new_row_tween.tween_property(strip, "modulate:a", 1.0, 0.55).set_delay(0.1).set_ease(Tween.EASE_OUT)
	_new_row_tween.tween_property(info, "modulate:a", 1.0, 0.55).set_delay(0.1).set_ease(Tween.EASE_OUT)


func _finish_new_row_animation() -> void:
	if _new_row_tween != null and _new_row_tween.is_valid():
		_new_row_tween.kill()
	_new_row_tween = null
	if is_instance_valid(_animated_strip):
		_animated_strip.modulate.a = 1.0
	if is_instance_valid(_animated_info):
		_animated_info.modulate.a = 1.0
	_animated_strip = null
	_animated_info = null


func _title_line(take: EchoTake) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(UiTheme.label(Loc.t("shop.take", [take.wave]), 16))
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
