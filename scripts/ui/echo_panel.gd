class_name EchoPanel
extends PanelContainer

signal discard_requested(take: EchoTake)
signal detail_requested(take: EchoTake)
signal repair_requested(take: EchoTake)
signal staple_requested(host: EchoTake, donor: EchoTake, choice: StringName)
signal navigation_changed

var copy_buttons: Array[Button] = []
var merge_button: Button
var trait_buttons: Array[Button] = []
var last_new_row: Control
var last_new_tint: Color = Color.WHITE
var reduced_effects := false

var _box: VBoxContainer
var _takes_box: GridContainer
var _sim: Sim
var _animate_new := false
var _merge_mode := false
var _spent_uid := 0
var _host_uid := 0
var page := 0
var page_size := 8
var page_previous: Button
var page_next: Button
var _identity_buttons: Dictionary = {}
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
	page_size = maxi(1, page_size)
	page = clampi(page, 0, maxi(0, ceili(float(sim.bank.takes.size()) / page_size) - 1))
	if _merge_mode and _host_uid != 0:
		_show_uid(_host_uid)
	_render()
	_animate_new = false


func close_session() -> void:
	_finish_new_row_animation()
	_sim = null
	_animate_new = false
	_merge_mode = false
	_spent_uid = 0
	_host_uid = 0
	trait_buttons.clear()
	copy_buttons.clear()
	_identity_buttons.clear()
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
	for portrait: EchoPortrait in find_children("*", "EchoPortrait", true, false):
		portrait.reduced_effects = on
		portrait.set_process(not on)
		if on:
			portrait.finish_immediately()
		portrait.queue_redraw()


func cancel_merge() -> bool:
	if not _merge_mode:
		return false
	end_staple()
	_render()
	if merge_button != null:
		merge_button.grab_focus()
	return true


func end_staple() -> void:
	_merge_mode = false
	_spent_uid = 0
	_host_uid = 0


func select_take(take: EchoTake) -> void:
	_pick(take)


func trait_button(choice: StringName) -> Button:
	for button in trait_buttons:
		if button.get_meta(&"trait") == choice:
			return button
	return null


func _render() -> void:
	_render_rows()
	navigation_changed.emit()


func _render_rows() -> void:
	_finish_new_row_animation()
	UiTheme.clear(_box)
	copy_buttons.clear()
	_identity_buttons.clear()
	merge_button = null
	last_new_row = null
	trait_buttons.clear()
	page_previous = null
	page_next = null
	if _sim == null:
		return
	var sim := _sim
	var capacity := sim.echo_capacity()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var title := UiTheme.section_label(Loc.t("shop.echoes", [sim.bank.takes.size(), capacity]), 16,
		UiTheme.WARN if sim.bank.overflow(capacity) > 0 else UiTheme.ECHO)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_box.add_child(head)
	if sim.bank.takes.size() > page_size:
		page_previous = Button.new()
		page_previous.text = "‹"
		page_previous.accessibility_name = Loc.t("workshop.previous")
		page_previous.disabled = page <= 0
		page_previous.pressed.connect(func() -> void: _change_page(-1))
		head.add_child(page_previous)
		head.add_child(UiTheme.label(Loc.t("workshop.page", [page + 1, ceili(float(sim.bank.takes.size()) / page_size)]), 12))
		page_next = Button.new()
		page_next.text = "›"
		page_next.accessibility_name = Loc.t("workshop.next")
		page_next.disabled = (page + 1) * page_size >= sim.bank.takes.size()
		page_next.pressed.connect(func() -> void: _change_page(1))
		head.add_child(page_next)
	if capacity > 0 and not sim.bank.takes.is_empty():
		merge_button = Button.new()
		merge_button.disabled = not _merge_mode and sim.bank.takes.size() < 2
		merge_button.text = Loc.t("shop.cancel") if _merge_mode else (Loc.t("shop.merge_need") if merge_button.disabled else Loc.t("shop.merge"))
		merge_button.accessibility_description = merge_button.text
		merge_button.pressed.connect(_on_merge_button)
		head.add_child(merge_button)
	if capacity <= 0 or sim.bank.takes.is_empty():
		var hint := UiTheme.label(Loc.t("shop.echo_none_slots") if capacity <= 0 else Loc.t("shop.echo_none"), 14, UiTheme.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(hint)
		return
	_takes_box = GridContainer.new()
	_takes_box.columns = 4
	_takes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_takes_box.add_theme_constant_override("h_separation", 5)
	_takes_box.add_theme_constant_override("v_separation", 5)
	_box.add_child(_takes_box)
	var newest := sim.bank.takes.duplicate()
	newest.reverse()
	last_new_row = null
	last_new_tint = Color.WHITE
	for take: EchoTake in newest.slice(page * page_size, (page + 1) * page_size):
		var is_new: bool = take.wave == sim.wave and take == sim.bank.takes.back()
		var row := _row(take, sim, is_new)
		_takes_box.add_child(row)
		if is_new:
			last_new_row = row
			last_new_tint = take.tint()
	if last_new_row != null and _animate_new:
		_animate_new_row(last_new_row)
	if _merge_mode:
		if _host_uid != 0 and _spent_uid != 0:
			var pairing := UiTheme.label(Loc.t("binding.merge", [_host_uid, _spent_uid, _host_uid]), 13, UiTheme.ECHO)
			_box.add_child(pairing)
			var marks := HBoxContainer.new()
			marks.add_theme_constant_override("separation", 5)
			_box.add_child(marks)
			_add_marks(marks, _take_by_uid(_host_uid))
		else:
			_box.add_child(UiTheme.label(Loc.t("inspection.choose_donor") if _spent_uid == 0 else Loc.t("inspection.choose_host"), 13, UiTheme.ECHO))
	for button: Button in [merge_button, page_previous, page_next]:
		if button != null:
			WorkshopUi.fit_button(button, 13, 27)


func _row(take: EchoTake, sim: Sim, is_new: bool) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := _merge_mode and take.uid in [_host_uid, _spent_uid]
	var ink := UiTheme.WARN if take.uid == _spent_uid else UiTheme.ACCENT
	var style := UiTheme.box(UiTheme.CARD.lerp(take.tint(), 0.09), ink, 3 if selected else (2 if is_new else 0), 16)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	row.add_theme_stylebox_override("panel", style)
	row.set_meta(&"new_copy", is_new)
	var identity := Button.new()
	identity.custom_minimum_size = Vector2(0, 104)
	identity.set_meta(&"echo_uid", take.uid)
	identity.accessibility_name = Loc.t("echo.identity", [take.uid, take.wave])
	identity.accessibility_description = Loc.t("echo.condition", [int(ceil(take.condition)),
		ceili(sim.echo_duration() * take.condition / 100.0 / maxf(0.01, sim.wear_rate_mult))]) 		+ " · " + Loc.echo_profile(EchoSystem.skill_profile(take, sim), true)
	if is_new:
		identity.accessibility_description += " · " + Loc.t("shop.new")
	for state in ["normal", "hover", "pressed", "disabled"]:
		identity.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	identity.pressed.connect(func() -> void:
		if _merge_mode:
			_pick(take))
	row.add_child(identity)
	var portrait := EchoPortrait.new()
	portrait.name = "EchoDoll"
	portrait.setup(take, sim.character_id, reduced_effects, is_new and _animate_new)
	identity.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var number := UiTheme.label("#%d" % take.uid, 12, UiTheme.INK)
	number.position = Vector2(4, 1)
	identity.add_child(number)
	var wear := UiTheme.label("%d%%" % ceili(take.condition), 11,
		UiTheme.WARN if take.condition < 25 else UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	identity.add_child(wear)
	wear.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	wear.offset_left = -36
	wear.offset_right = -4
	wear.offset_top = -19
	wear.offset_bottom = -2
	_identity_buttons[take.uid] = identity
	copy_buttons.append(identity)
	row.set_meta(&"take_identity", portrait)
	row.set_meta(&"take_info", wear)
	return row


func _change_page(delta: int) -> void:
	page = clampi(page + delta, 0, maxi(0, ceili(float(_sim.bank.takes.size()) / page_size) - 1))
	_render()
	focus_first_copy()



func focus_first_copy() -> bool:
	if copy_buttons.is_empty():
		return false
	copy_buttons[0].grab_focus()
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
	_stamped_row = _takes_box.get_child(0).get_meta(&"take_identity") as Control
	if _stamped_row == null:
		return
	_stamped_row.pivot_offset = _stamped_row.size * 0.5
	_stamped_row.scale = Vector2(1.3, 0.65)
	_merge_tween = _stamped_row.create_tween().set_parallel(true)
	_merge_tween.tween_property(_stamped_row, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_merge_button() -> void:
	if merge_button != null and merge_button.disabled:
		return
	if _merge_mode:
		cancel_merge()
		return
	_merge_mode = true
	_spent_uid = 0
	_host_uid = 0
	_render()
	if not _identity_buttons.is_empty():
		(_identity_buttons.values()[0] as Button).grab_focus()


func _pick(take: EchoTake) -> void:
	if not _merge_mode or _sim == null or take == null:
		return
	if _spent_uid == 0 or take.uid == _spent_uid:
		_spent_uid = 0 if take.uid == _spent_uid else take.uid
		_host_uid = _sole_host()
	else:
		_host_uid = take.uid
	if _host_uid != 0:
		_show_uid(_host_uid)
	_render()
	for button: Button in trait_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	focus_take(take.uid)


func _show_uid(uid: int) -> void:
	if _sim == null:
		return
	var newest: Array = _sim.bank.takes.duplicate()
	newest.reverse()
	for index in newest.size():
		var take: EchoTake = newest[index]
		if take.uid == uid:
			page = int(index / maxi(1, page_size))
			return


func _sole_host() -> int:
	if _spent_uid == 0 or _sim == null:
		return 0
	var other := 0
	var count := 0
	for take: EchoTake in _sim.bank.takes:
		if take.uid == _spent_uid:
			continue
		count += 1
		other = take.uid
	return other if count == 1 else 0


func _take_by_uid(uid: int) -> EchoTake:
	if _sim == null:
		return null
	for take: EchoTake in _sim.bank.takes:
		if take.uid == uid:
			return take
	return null


func _add_marks(line: HBoxContainer, host: EchoTake) -> void:
	var donor := _take_by_uid(_spent_uid)
	if donor == null or _sim == null:
		return
	for choice: StringName in [&"skill", &"repair", &"power"]:
		var quote := _sim.shop.echo_merge_quote(_sim, host, donor, choice)
		if quote == null:
			continue
		var button := Button.new()
		var action := Loc.t("echo.staple.skill") if choice == &"skill" \
				else (Loc.t("echo.staple.repair") if choice == &"repair" else Loc.t("echo.staple.power"))
		button.text = "%s\n%s" % [action, Loc.t("shop.price_materials", [quote.cost])]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not quote.ok
		button.set_meta(&"trait", choice)
		button.tooltip_text = Loc.t("workshop.trait_skill_desc") if choice == &"skill" \
				else (Loc.t("workshop.trait_repair_desc") if choice == &"repair" else Loc.t("workshop.trait_power_desc"))
		button.accessibility_name = Loc.t("workshop.trait_skill") if choice == &"skill" \
				else (Loc.t("workshop.trait_repair") if choice == &"repair" else Loc.t("workshop.trait_power"))
		button.accessibility_description = button.tooltip_text
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(108.0, 28.0)
		button.pressed.connect(_commit.bind(choice))
		line.add_child(button)
		trait_buttons.append(button)


func _commit(choice: StringName) -> void:
	var host := _take_by_uid(_host_uid)
	var donor := _take_by_uid(_spent_uid)
	if host == null or donor == null:
		return
	staple_requested.emit(host, donor, choice)


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




func focus_take(uid: int) -> bool:
	var identity := _identity_buttons.get(uid) as Button
	if identity != null:
		identity.grab_focus()
		return true
	return false
