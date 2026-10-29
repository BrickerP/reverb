class_name EchoPanel
extends PanelContainer

signal discard_requested(take: EchoTake)
signal merge_requested(a: EchoTake, b: EchoTake)
signal repair_requested(take: EchoTake)

var discard_buttons: Array[Button] = []
var repair_buttons: Array[Button] = []
var merge_button: Button
var last_new_row: Control
var last_new_tint: Color = Color.WHITE
var reduced_effects := false

var _box: VBoxContainer
var _takes_box: VBoxContainer
var _sim: Sim
var _animate_new := false
var _merge_mode := false
var _merge_first: EchoTake
var _new_row_tween: Tween
var _animated_strip: Control
var _animated_info: Control
var _merge_tween: Tween
var _stamped_row: Control


class TakeMeter:
	extends Control

	var ratio: float = 0.0
	var tint: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius := size.y * 0.5
		var a := Vector2(radius, radius)
		var b := Vector2(maxf(radius, size.x - radius), radius)
		draw_line(a, b, Color(UiTheme.EDGE, 0.15), size.y, true)
		draw_circle(a, radius, Color(UiTheme.EDGE, 0.15))
		draw_circle(b, radius, Color(UiTheme.EDGE, 0.15))
		if ratio > 0.0:
			var filled := Vector2(maxf(radius, (size.x - radius) * clampf(ratio, 0.0, 1.0)), radius)
			draw_line(a, filled, Color(tint, 0.9), size.y, true)
			draw_circle(a, radius, Color(tint, 0.9))
			draw_circle(filled, radius, Color(tint, 0.9))


class StapleMark:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(24.0, 14.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# A physical staple remains on merged copies after the press has settled.
		draw_line(Vector2(4.0, 11.0), Vector2(4.0, 4.0), UiTheme.EDGE, 3.0, true)
		draw_line(Vector2(4.0, 4.0), Vector2(20.0, 4.0), UiTheme.EDGE, 3.0, true)
		draw_line(Vector2(20.0, 4.0), Vector2(20.0, 11.0), UiTheme.EDGE, 3.0, true)


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 0.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var surface_source := UiTheme.surface_panel()
	if surface_source != null:
		var surface := surface_source.duplicate() as InkStyleBox
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
	repair_buttons.clear()
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
	repair_buttons.clear()
	merge_button = null
	if _sim == null:
		return
	var sim := _sim
	var capacity := sim.echo_capacity()
	var over := sim.bank.overflow(capacity)
	var heading := Loc.t("shop.echoes", [sim.bank.takes.size(), capacity])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := UiTheme.section_label(heading, 21, UiTheme.WARN if over > 0 else UiTheme.ECHO)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if capacity > 0 and not sim.bank.takes.is_empty():
		merge_button = Button.new()
		merge_button.text = Loc.t("shop.cancel") if _merge_mode else Loc.t("shop.merge")
		merge_button.custom_minimum_size = Vector2(80.0, 34.0)
		merge_button.add_theme_font_size_override("font_size", 14)
		UiTheme.stamp_button(merge_button, UiTheme.ECHO)
		merge_button.disabled = not _merge_mode and sim.bank.takes.size() < 2
		merge_button.pressed.connect(_on_merge_button)
		head.add_child(merge_button)
	_box.add_child(head)
	var copies_hint := UiTheme.label(Loc.t("shop.copies_hint"), 13, UiTheme.DIM)
	copies_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(copies_hint)
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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(scroll)
	_takes_box = VBoxContainer.new()
	_takes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_takes_box.add_theme_constant_override("separation", 9)
	scroll.add_child(_takes_box)
	var best := 1.0
	for take: EchoTake in sim.bank.takes:
		best = maxf(best, sim.echo_dps(take))
	var newest_first := sim.bank.takes.duplicate()
	newest_first.reverse()
	var new_row: Control = null
	last_new_row = null
	last_new_tint = Color.WHITE
	for take: EchoTake in newest_first:
		var is_new: bool = take.wave == sim.wave and take == sim.bank.takes.back()
		var row := _row(take, sim, best, is_new, take == _merge_first)
		_takes_box.add_child(row)
		if is_new:
			new_row = row
			last_new_row = row
			last_new_tint = take.tint()
	if new_row != null and _animate_new:
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


func confirm_merge() -> void:
	if reduced_effects or _takes_box == null or _takes_box.get_child_count() == 0:
		return
	_stamped_row = _takes_box.get_child(0).find_child("StapleMark", true, false) as Control
	if _stamped_row == null:
		return
	_stamped_row.pivot_offset = _stamped_row.size * 0.5
	_stamped_row.scale = Vector2(1.3, 0.65)
	_merge_tween = _stamped_row.create_tween().set_parallel(true)
	_merge_tween.tween_property(_stamped_row, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _row(take: EchoTake, sim: Sim, best: float, is_new: bool, selected: bool) -> Control:
	var row := PanelContainer.new()
	var style := UiTheme.box(UiTheme.PAPER if selected else UiTheme.CARD,
			UiTheme.ECHO if selected else Color(UiTheme.EDGE, 0.0), 2 if selected else 0, 20)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shape = InkStyleBox.Shape.PAPER
	style.variant = take.wave % 7
	row.add_theme_stylebox_override("panel", style)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 6)
	row.add_child(sheet)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	sheet.add_child(top)
	var strip := ColorRect.new()
	strip.color = UiTheme.ECHO if selected else take.tint().lerp(UiTheme.INK, 0.4)
	strip.custom_minimum_size = Vector2(4.0, 0.0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(strip)
	var preview := PathPreview.new()
	preview.setup(take, is_new and _animate_new and not reduced_effects)
	var cartridge := UiTheme.cartridge_icon(Vector2(25.0, 18.0))
	cartridge.position = Vector2(47.0, 2.0)
	preview.add_child(cartridge)
	top.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.add_child(_title_line(take))
	var dps := int(round(sim.echo_dps(take)))
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 8)
	meta.add_theme_constant_override("v_separation", 2)
	meta.add_child(UiTheme.label(Loc.t("echo.condition", [int(ceil(take.condition)),
			ceili(sim.echo_duration() * take.condition / 100.0 / maxf(0.01, sim.wear_rate_mult))]), 12, UiTheme.WARN if take.condition <= 25.0 else UiTheme.DIM))
	if take.merged:
		meta.add_child(UiTheme.label("[%s]" % Loc.t("shop.merged"), 12, UiTheme.COIN))
	if is_new:
		meta.add_child(UiTheme.label("[%s]" % Loc.t("shop.new"), 12, UiTheme.ACCENT))
	meta.add_child(UiTheme.label(Loc.t("shop.take_dps", [dps]), 13, UiTheme.DIM))
	info.add_child(meta)
	var meter := TakeMeter.new()
	meter.tint = take.tint().lerp(UiTheme.INK, 0.4)
	meter.ratio = float(dps) / maxf(1.0, best)
	info.add_child(meter)
	top.add_child(info)
	var loadout := UiTheme.label(Loc.t("shop.live_loadout") if sim.live_echo else _loadout(take), 13, UiTheme.DIM)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout.custom_minimum_size = Vector2(180.0, 0.0)
	sheet.add_child(loadout)
	var skill := UiTheme.label(Loc.echo_profile(EchoSystem.skill_profile(take, sim), true), 12, UiTheme.DIM)
	skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(skill)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	sheet.add_child(actions)
	if not _merge_mode:
		var quote := sim.shop.echo_repair_quote(sim, take)
		var repair := Button.new()
		var amount := sim.shop.echo_repair_amount(take)
		var amount_label := "<1" if amount > 0.0 and amount < 1.0 else Loc.number(amount)
		repair.text = Loc.t("shop.repair", [amount_label, quote.cost])
		repair.disabled = not quote.ok
		repair.tooltip_text = Loc.t("shop.repair_full") if take.condition >= 100.0 else Loc.t("shop.repair_result", [int(ceil(minf(100.0, take.condition + sim.shop.echo_repair_amount(take))))])
		if quote.reason == &"poor":
			repair.tooltip_text = Loc.t("shop.drop_poor")
		repair.custom_minimum_size = Vector2(0.0, 30.0)
		repair.add_theme_font_size_override("font_size", 13)
		repair.pressed.connect(_on_repair.bind(take))
		repair_buttons.append(repair)
		actions.add_child(repair)
	elif _merge_first != null and _merge_first != take:
		var quote := sim.shop.echo_merge_quote(sim, _merge_first, take)
		var outcome := UiTheme.label(Loc.t("shop.merge_result", [Loc.number(minf(take.condition, _merge_first.condition)), quote.cost]), 12, UiTheme.DIM)
		outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		actions.add_child(outcome)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	var button := Button.new()
	button.text = (Loc.t("shop.selected") if selected else Loc.t("shop.select")) \
			if _merge_mode else Loc.t("shop.discard")
	button.custom_minimum_size = Vector2(88.0, 30.0)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(_on_row.bind(take))
	discard_buttons.append(button)
	actions.add_child(button)
	row.set_meta(&"take_identity", strip)
	row.set_meta(&"take_info", info)
	return row


func _on_repair(take: EchoTake) -> void:
	repair_requested.emit(take)


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
	var strip := row.get_meta(&"take_identity", null) as Control
	var info := row.get_meta(&"take_info", null) as Control
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
	if _merge_tween != null and _merge_tween.is_valid():
		_merge_tween.kill()
	_merge_tween = null
	if is_instance_valid(_stamped_row):
		_stamped_row.scale = Vector2.ONE
		_stamped_row.rotation = 0.0
	_stamped_row = null
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
	line.add_child(UiTheme.label(Loc.t("echo.identity", [take.uid, take.wave]), 16))
	if take.merged:
		var staple := StapleMark.new()
		staple.name = "StapleMark"
		line.add_child(staple)
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
