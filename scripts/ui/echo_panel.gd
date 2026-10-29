class_name EchoPanel
extends PanelContainer

signal discard_requested(take: EchoTake)
signal merge_workbench_requested
signal detail_requested(take: EchoTake)
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
var page := 0
var page_size := 2
var page_previous: Button
var page_next: Button
var _identity_buttons: Dictionary = {}
var _repair_by_uid: Dictionary = {}
var _new_row_tween: Tween
var _animated_strip: Control
var _animated_info: Control
var _merge_tween: Tween
var _stamped_row: Control


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
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)


func refresh(sim: Sim, animate_new: bool = false) -> void:
	_sim = sim
	_animate_new = animate_new and not reduced_effects
	page_size = 1 if get_viewport_rect().size.y < 620.0 else 2
	page = clampi(page, 0, maxi(0, ceili(float(sim.bank.takes.size()) / page_size) - 1))
	_render()
	_animate_new = false


func close_session() -> void:
	_finish_new_row_animation()
	_sim = null
	_animate_new = false
	_merge_mode = false
	discard_buttons.clear()
	repair_buttons.clear()
	_identity_buttons.clear()
	_repair_by_uid.clear()
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
	_render()
	if merge_button != null:
		merge_button.grab_focus()
	return true


func _render() -> void:
	_finish_new_row_animation()
	UiTheme.clear(_box)
	discard_buttons.clear()
	repair_buttons.clear()
	_identity_buttons.clear()
	_repair_by_uid.clear()
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
	_takes_box = VBoxContainer.new()
	_takes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_takes_box.add_theme_constant_override("separation", 4)
	_box.add_child(_takes_box)
	var newest_first := sim.bank.takes.duplicate()
	newest_first.reverse()
	var new_row: Control = null
	last_new_row = null
	last_new_tint = Color.WHITE
	for take: EchoTake in newest_first.slice(page * page_size, (page + 1) * page_size):
		var is_new: bool = take.wave == sim.wave and take == sim.bank.takes.back()
		var row := _row(take, sim, is_new)
		_takes_box.add_child(row)
		if is_new:
			new_row = row
			last_new_row = row
			last_new_tint = take.tint()
	if new_row != null and _animate_new:
		_animate_new_row(new_row)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 5)
	page_previous = Button.new()
	page_previous.text = "‹"
	page_previous.accessibility_name = Loc.t("workshop.previous")
	page_previous.disabled = page <= 0
	page_previous.pressed.connect(func() -> void: _change_page(-1))
	pages.add_child(page_previous)
	var count := UiTheme.label(Loc.t("workshop.page", [page + 1, maxi(1, ceili(float(sim.bank.takes.size()) / page_size))]), 13, UiTheme.DIM)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pages.add_child(count)
	page_next = Button.new()
	page_next.text = "›"
	page_next.accessibility_name = Loc.t("workshop.next")
	page_next.disabled = (page + 1) * page_size >= sim.bank.takes.size()
	page_next.pressed.connect(func() -> void: _change_page(1))
	pages.add_child(page_next)
	_box.add_child(pages)
	for button: Button in find_children("*", "Button", true, false):
		WorkshopUi.fit_button(button, 14, 27.0)


func _change_page(delta: int) -> void:
	page = clampi(page + delta, 0, maxi(0, ceili(float(_sim.bank.takes.size()) / page_size) - 1))
	_render()
	focus_first_discard()



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


func _row(take: EchoTake, sim: Sim, is_new: bool) -> Control:
	var row := PanelContainer.new()
	var style := UiTheme.box(UiTheme.CARD, Color(UiTheme.EDGE, 0.0), 0, 12)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	row.add_child(line)
	var preview := PathPreview.new()
	preview.custom_minimum_size = Vector2(45.0, 35.0)
	preview.setup(take, is_new and _animate_new and not reduced_effects)
	line.add_child(preview)
	if take.merged:
		var staple := StapleMark.new()
		staple.name = "StapleMark"
		staple.position = Vector2(18.0, 0.0)
		preview.add_child(staple)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var identity := Button.new()
	identity.text = Loc.t("echo.identity", [take.uid, take.wave])
	identity.add_theme_font_size_override("font_size", 14)
	identity.clip_text = true
	identity.pressed.connect(func() -> void: detail_requested.emit(take))
	var identity_line := HBoxContainer.new()
	identity_line.add_theme_constant_override("separation", 3)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_line.add_child(identity)
	if is_new:
		identity_line.add_child(UiTheme.label("[%s]" % Loc.t("shop.new"), 12, UiTheme.ACCENT))
	info.add_child(identity_line)
	_identity_buttons[take.uid] = identity
	var condition := Loc.t("echo.condition", [int(ceil(take.condition)), ceili(sim.echo_duration() * take.condition / 100.0 / maxf(0.01, sim.wear_rate_mult))])
	var label := UiTheme.label(condition + " · " + Loc.t("shop.take_dps", [int(round(sim.echo_dps(take)))]), 12, UiTheme.DIM)
	label.clip_text = true
	info.add_child(label)
	var repair := Button.new()
	var quote := sim.shop.echo_repair_quote(sim, take)
	repair.text = Loc.t("workshop.repair", [quote.cost])
	repair.disabled = not quote.ok
	repair.tooltip_text = Loc.t("shop.repair_full") if take.condition >= 100.0 else (Loc.t("shop.drop_poor") if quote.reason == &"poor" else Loc.t("shop.repair_result", [int(ceil(minf(100.0, take.condition + sim.shop.echo_repair_amount(take))))]))
	repair.accessibility_description = repair.tooltip_text
	repair.add_theme_font_size_override("font_size", 12)
	repair.pressed.connect(_on_repair.bind(take))
	repair_buttons.append(repair)
	_repair_by_uid[take.uid] = repair
	line.add_child(repair)
	var discard := Button.new()
	discard.text = Loc.t("shop.discard")
	discard.add_theme_font_size_override("font_size", 12)
	discard.pressed.connect(_on_row.bind(take))
	discard_buttons.append(discard)
	line.add_child(discard)
	row.set_meta(&"take_identity", preview)
	row.set_meta(&"take_info", info)
	return row


func _on_repair(take: EchoTake) -> void:
	repair_requested.emit(take)


func _on_row(take: EchoTake) -> void:
	if not _merge_mode:
		discard_requested.emit(take)


func _on_merge_button() -> void:
	if _merge_mode:
		cancel_merge()
		return
	_merge_mode = true
	merge_workbench_requested.emit()


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




func _loadout(take: EchoTake) -> String:
	var counts: Dictionary = {}
	for w in take.weapons:
		counts[w.id] = int(counts.get(w.id, 0)) + 1
	var parts := PackedStringArray()
	for id: StringName in counts:
		var n: int = counts[id]
		parts.append("%s ×%d" % [Loc.weapon_name(id), n] if n > 1 else Loc.weapon_name(id))
	return ", ".join(parts)


func focus_take(uid: int) -> bool:
	var repair := _repair_by_uid.get(uid) as Button
	if repair != null and not repair.disabled:
		repair.grab_focus()
		return true
	var identity := _identity_buttons.get(uid) as Button
	if identity != null:
		identity.grab_focus()
		return true
	return false
