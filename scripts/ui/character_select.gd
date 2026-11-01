class_name CharacterSelectUi
extends Control

signal character_chosen(id: StringName)
signal settings_requested
signal history_requested
signal daily_requested
signal demo_requested
signal codex_requested
signal continue_requested
signal archive_requested(id: StringName)
signal story_requested

# The click area stays still. Only the drawn ink, labels and portraits are offset.
class CastButton extends Button:
	var compact := false
	var previewed := false
	var rise := 0.0
	var paper_color := UiTheme.COIN
	var portrait: TextureRect
	var name_label: Label
	var trait_label: Label
	var status_label: Label
	var tag_style: InkStyleBox
	var shadow_style: InkStyleBox
	var halo_style: InkStyleBox

	func _ready() -> void:
		resized.connect(_place_art)
		focus_entered.connect(_active_changed)
		focus_exited.connect(_active_changed)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		_place_art()
		_active_changed()

	func _active_changed() -> void:
		if status_label != null:
			status_label.visible = disabled or has_focus()
		queue_redraw()

	func _place_art() -> void:
		var width := maxf(size.x, custom_minimum_size.x)
		var offset := 0.0 if compact else rise
		var portrait_size := Vector2(112.0, 124.0) if compact else Vector2(158.0, 184.0)
		if portrait != null:
			portrait.custom_minimum_size = portrait_size
			portrait.position = Vector2((width - portrait_size.x) * 0.5, offset + 2.0)
			portrait.size = portrait_size
		if name_label != null:
			name_label.position = Vector2(16.0, offset + (115.0 if compact else 179.0))
			name_label.size = Vector2(width - 32.0, 32.0 if compact else 38.0)
			name_label.add_theme_font_size_override("font_size", 22 if compact else 24)
		if trait_label != null:
			trait_label.position = Vector2(12.0, offset + (151.0 if compact else 224.0))
			trait_label.size = Vector2(width - 24.0, 22.0 if compact else 28.0)
		if status_label != null:
			status_label.position = Vector2(10.0, offset + (174.0 if compact else 262.0))
			status_label.size = Vector2(width - 20.0, 22.0 if compact else 30.0)
		queue_redraw()

	func _draw() -> void:
		if tag_style == null or size.x <= 0.0:
			return
		var width := size.x
		var offset := 0.0 if compact else rise
		var active := not disabled and previewed
		if active:
			draw_style_box(halo_style, Rect2(width * 0.5 - (73.0 if compact else 99.0), offset + 15.0, 146.0 if compact else 198.0, 105.0 if compact else 157.0))
		draw_style_box(shadow_style, Rect2(width * 0.5 - (54.0 if compact else 74.0), offset + (105.0 if compact else 148.0), 108.0 if compact else 148.0, 22.0 if compact else 30.0))
		tag_style.border_color = paper_color if active else Color(UiTheme.INK, 0.58)
		tag_style.bg_color = UiTheme.CARD if active else UiTheme.PAPER
		var name_y := offset + (112.0 if compact else 176.0)
		draw_style_box(tag_style, Rect2(11.0, name_y, width - 22.0, 36.0 if compact else 44.0))
		if disabled:
			var slash := PackedVector2Array([Vector2(width * 0.5 - (40.0 if compact else 57.0), offset + (38.0 if compact else 54.0)),
				Vector2(width * 0.5 - 2.0, offset + (64.0 if compact else 94.0)), Vector2(width * 0.5 + (42.0 if compact else 60.0), offset + (88.0 if compact else 126.0))])
			draw_polyline(slash, Color(UiTheme.INK, 0.44), 3.0, true)
		if has_focus():
			var baseline := offset + (147.0 if compact else 219.0)
			var ink := PackedVector2Array([Vector2(width * 0.5 - 38.0, baseline), Vector2(width * 0.5 - 8.0, baseline + 3.0), Vector2(width * 0.5 + 42.0, baseline - 1.0)])
			draw_polyline(ink, paper_color, 2.0, true)

var _cards_box: HBoxContainer
var continue_button: Button
var resume_error: Label
var _resume_available := false
var _resume_error := ""
var _summary: Label
var _detail: Label
var _selection_note: Label
var _cards: Array[Button] = []
var _daily_button: Button
var _ascension_button: Button
var _secondary_actions: Array[Button] = []
var _known_unlocks: Dictionary = {}
var _last_focused_character: StringName = &""
var _hovered_character: StringName = &""
var _meta: Meta
var seed_edit: LineEdit
var page := 0
var page_previous: Button
var page_next: Button
var _page_label: Label
var _pager: HBoxContainer
var _stage: MarginContainer
var _box: VBoxContainer
var _logotype: Label
var _department: Label
var _subtitle: Label
var _footer: HFlowContainer
var _last_canvas := Vector2.ZERO
var _compact := false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = UiTheme.PAPER
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = MarginContainer.new()
	_stage.custom_minimum_size = Vector2(1160.0, 0.0)
	for side in ["left", "right", "top", "bottom"]:
		_stage.add_theme_constant_override("margin_" + side, 8)
	center.add_child(_stage)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	_stage.add_child(_box)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(header)
	_logotype = UiTheme.label(Loc.t("select.title"), 44, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_logotype.add_theme_font_override("font", load(UiTheme.TITLE_EN) as Font)
	_logotype.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_logotype)
	_department = UiTheme.label(Loc.t("brand.department"), 17, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(_department)
	_subtitle = UiTheme.label(Loc.t("select.subtitle"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(_subtitle)
	continue_button = Button.new()
	continue_button.text = Loc.t("select.continue")
	continue_button.custom_minimum_size = Vector2(230.0, 36.0)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.visible = _resume_available
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	UiTheme.stamp_button(continue_button)
	header.add_child(continue_button)
	resume_error = UiTheme.label(_resume_error, 14, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	resume_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_error.visible = not _resume_error.is_empty()
	_box.add_child(resume_error)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 6)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(_cards_box)
	_pager = HBoxContainer.new()
	_pager.alignment = BoxContainer.ALIGNMENT_CENTER
	page_previous = Button.new()
	page_previous.text = Loc.t("workshop.previous")
	page_previous.custom_minimum_size = Vector2(100.0, 28.0)
	page_previous.pressed.connect(_change_page.bind(-1))
	_pager.add_child(page_previous)
	_page_label = UiTheme.label("", 14, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_pager.add_child(_page_label)
	page_next = Button.new()
	page_next.text = Loc.t("workshop.next")
	page_next.custom_minimum_size = Vector2(100.0, 28.0)
	page_next.pressed.connect(_change_page.bind(1))
	_pager.add_child(page_next)
	_box.add_child(_pager)
	_selection_note = UiTheme.label("", 22, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_selection_note.clip_text = true
	_selection_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_selection_note.add_theme_font_override("font", UiTheme.title_font())
	_box.add_child(_selection_note)
	_detail = UiTheme.label("", 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(1100.0, 34.0)
	_box.add_child(_detail)
	_footer = HFlowContainer.new()
	_footer.add_theme_constant_override("h_separation", 6)
	_footer.add_theme_constant_override("v_separation", 3)
	_footer.alignment = FlowContainer.ALIGNMENT_CENTER
	var seed_group := HBoxContainer.new()
	seed_group.add_child(UiTheme.label(Loc.t("select.seed"), 13, UiTheme.DIM))
	_footer.add_child(seed_group)
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = Loc.t("select.seed_hint")
	seed_edit.custom_minimum_size = Vector2(124.0, 34.0)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.max_length = 12
	seed_group.add_child(seed_edit)
	_ascension_button = Button.new()
	_ascension_button.custom_minimum_size = Vector2(152.0, 34.0)
	_ascension_button.add_theme_font_size_override("font_size", 12)
	_ascension_button.pressed.connect(_cycle_ascension)
	_footer.add_child(_ascension_button)
	for key in ["select.codex", "select.settings", "select.history", "select.story"]:
		var button := StitchedAction.new()
		button.text = Loc.t(key)
		button.flat = true
		button.custom_minimum_size = Vector2(108.0, 34.0)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_secondary_action.bind(key))
		_footer.add_child(button)
		_secondary_actions.append(button)
	_daily_button = Button.new()
	_daily_button.text = Loc.t("select.daily")
	_daily_button.custom_minimum_size = Vector2(164.0, 38.0)
	_daily_button.pressed.connect(func() -> void: daily_requested.emit())
	UiTheme.stamp_button(_daily_button)
	_footer.add_child(_daily_button)
	_secondary_actions.append(_daily_button)
	var demo_button := Button.new()
	demo_button.text = Loc.t("select.demo")
	demo_button.custom_minimum_size = Vector2(120.0, 38.0)
	demo_button.pressed.connect(func() -> void: demo_requested.emit())
	UiTheme.stamp_button(demo_button)
	_footer.add_child(demo_button)
	_box.add_child(_footer)
	_summary = UiTheme.label("", 13, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(_summary)
	var archive := Button.new()
	archive.text = Loc.t("archive.open")
	archive.custom_minimum_size = Vector2(240.0, 30.0)
	archive.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	archive.pressed.connect(func() -> void: archive_requested.emit(_last_focused_character if _last_focused_character != &"" else &"looper"))
	_secondary_actions.append(archive)
	_footer.add_child(archive)
	_adapt_layout()


func _secondary_action(key: String) -> void:
	match key:
		"select.codex": codex_requested.emit()
		"select.settings": settings_requested.emit()
		"select.history": history_requested.emit()
		"select.story": story_requested.emit()


func refresh(meta: Meta, daily_seed: int = 0, daily_best: int = 0) -> void:
	if _meta != meta:
		_known_unlocks.clear()
		page = 0
		_last_focused_character = &""
	_meta = meta
	var newly_unlocked := PackedStringArray()
	UiTheme.clear(_cards_box)
	_cards.clear()
	var index := 0
	for def: CharacterDef in Content.characters().values():
		var unlocked := meta.is_unlocked(def.id)
		if _known_unlocks.has(def.id) and not bool(_known_unlocks[def.id]) and unlocked:
			newly_unlocked.append(Loc.character_name(def.id))
		_known_unlocks[def.id] = unlocked
		var card := _make_card(def, meta, index)
		_cards_box.add_child(card)
		_cards.append(card)
		index += 1
	var summary := Loc.t("select.best", [meta.best_wave, meta.wins])
	if meta.best_endless > 0:
		summary += "  ·  " + Loc.t("select.endless_best", [meta.best_endless])
	if meta.best_boss_rush > 0:
		summary += "  ·  " + Loc.t("select.boss_rush_best", [meta.best_boss_rush])
	_summary.text = "%s  ·  v%s" % [summary, str(ProjectSettings.get_setting("application/config/version", ""))]
	_daily_button.text = Loc.t("select.daily_best", [daily_best]) if daily_best > 0 else Loc.t("select.daily")
	if meta.daily_streak > 0:
		_daily_button.text += "  ·  " + Loc.t("select.daily_streak", [meta.daily_streak])
	_daily_button.tooltip_text = Loc.t("select.daily_anomaly", [Loc.t(DailyAnomaly.title_key(DailyAnomaly.for_seed(daily_seed)))])
	if _last_focused_character == &"":
		for card in _cards:
			if not card.disabled:
				_last_focused_character = StringName(card.get_meta(&"character_id"))
				break
	_update_ascension_button()
	_adapt_layout(true)
	_rebuild_focus()
	focus_default()
	if not newly_unlocked.is_empty():
		_selection_note.text = Loc.t("select.just_unlocked", [", ".join(newly_unlocked)])


func _rebuild_focus() -> void:
	var controls: Array[Control] = []
	var available: Array[Button] = []
	for card in _cards:
		if card.visible and not card.disabled:
			controls.append(card)
			available.append(card)
	if _pager != null and _pager.visible:
		controls.append(page_previous)
		controls.append(page_next)
	if continue_button.visible:
		controls.append(continue_button)
	controls.append(seed_edit)
	controls.append(_ascension_button)
	controls.append_array(_secondary_actions)
	UiFocus.cycle(controls)
	for i in available.size():
		available[i].focus_neighbor_left = available[i].get_path_to(available[(i - 1 + available.size()) % available.size()])
		available[i].focus_neighbor_right = available[i].get_path_to(available[(i + 1) % available.size()])
		available[i].focus_neighbor_bottom = available[i].get_path_to(seed_edit)


func set_resume_available(available: bool, error: String = "") -> void:
	_resume_available = available
	_resume_error = error
	if continue_button == null:
		return
	continue_button.visible = available
	resume_error.text = error
	resume_error.visible = not error.is_empty()
	_rebuild_focus()


func focus_default() -> void:
	if continue_button != null and continue_button.visible:
		continue_button.grab_focus()
		return
	for card in _cards:
		if card.visible and not card.disabled and StringName(card.get_meta(&"character_id")) == _last_focused_character:
			card.grab_focus()
			return
	for card in _cards:
		if card.visible and not card.disabled:
			card.grab_focus()
			return
	seed_edit.grab_focus()


func chosen_seed() -> int:
	var text := seed_edit.text.strip_edges()
	return int(text) if text.is_valid_int() else -1


func _update_ascension_button() -> void:
	if _ascension_button == null or _meta == null:
		return
	var max_level := _meta.max_ascension()
	if max_level > 0:
		_ascension_button.text = Loc.t("select.ascension", [_meta.ascension])
	else:
		_ascension_button.text = Loc.t("select.ascension_locked")
	_ascension_button.disabled = max_level <= 0
	_ascension_button.tooltip_text = Loc.t("select.ascension_hint")


func _cycle_ascension() -> void:
	if _meta == null:
		return
	var max_level := _meta.max_ascension()
	if max_level <= 0:
		return
	_meta.set_ascension((_meta.ascension + 1) % (max_level + 1))
	_update_ascension_button()



func _make_card(def: CharacterDef, meta: Meta, index: int) -> CastButton:
	var locked := not meta.is_unlocked(def.id)
	var card := CastButton.new()
	card.custom_minimum_size = Vector2(182.0, 314.0)
	card.rise = [8.0, 0.0, 12.0, 3.0, 9.0, 0.0][index % 6]
	card.paper_color = UiTheme.character_color(def.id)
	card.disabled = locked
	card.set_meta(&"character_id", def.id)
	card.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	card.accessibility_name = Loc.character_name(def.id)
	var blank := UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	blank.draw_center = false
	blank.shadow_color = Color(0, 0, 0, 0)
	blank.shadow_size = 0
	blank.shadow_offset = Vector2.ZERO
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, blank)
	card.tag_style = UiTheme.paper_panel()
	card.tag_style.shape = InkStyleBox.Shape.TAG
	card.tag_style.variant = index + 3
	card.tag_style.shadow_size = 0
	card.tag_style.shadow_offset = Vector2.ZERO
	card.shadow_style = UiTheme.box(Color(UiTheme.INK, 0.14), Color(0, 0, 0, 0), 0)
	card.shadow_style.shape = InkStyleBox.Shape.BLOB
	card.shadow_style.variant = index + 13
	card.shadow_style.shadow_size = 0
	card.shadow_style.shadow_offset = Vector2.ZERO
	card.halo_style = UiTheme.box(Color(UiTheme.INK, 0.92), Color(0, 0, 0, 0), 0)
	card.halo_style.shape = InkStyleBox.Shape.BLOB
	card.halo_style.variant = index + 7
	card.halo_style.shadow_size = 0
	card.halo_style.shadow_offset = Vector2.ZERO
	card.pressed.connect(_on_card.bind(def.id))
	card.focus_entered.connect(_show_character.bind(def.id))
	card.mouse_entered.connect(_hover_character.bind(def.id))
	card.mouse_exited.connect(_leave_character.bind(def.id))
	card.gui_input.connect(_pointer_input.bind(def.id))
	card.portrait = UiTheme.character_icon(def.id, Vector2(158.0, 184.0))
	card.portrait.modulate.a = 0.48 if locked else 1.0
	card.add_child(card.portrait)
	card.name_label = UiTheme.label(Loc.character_name(def.id), 24, card.paper_color, HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(card.name_label)
	card.trait_label = UiTheme.label(_opening_line(def), 13, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	card.trait_label.custom_minimum_size = Vector2(160.0, 0.0)
	card.trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(card.trait_label)
	var status := "" if locked else Loc.t("select.ready")
	card.status_label = UiTheme.label(status, 13, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	card.status_label.custom_minimum_size = Vector2(160.0, 0.0)
	card.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(card.status_label)
	card.tooltip_text = _opening_line(def)
	card.accessibility_description = _opening_line(def) if status == "" else "%s · %s" % [_opening_line(def), status]
	return card


func _opening_line(def: CharacterDef) -> String:
	if int(def.overrides.get(Stats.ECHO_SLOTS, Stats.DEFAULTS[Stats.ECHO_SLOTS])) <= 0:
		return Loc.t("select.solo_core")
	if def.live_echo:
		return Loc.t("select.live_echo")
	if def.id == &"mender":
		return Loc.t("select.mender_core")
	if def.id == &"overloader":
		return Loc.t("select.overloader_core")
	if def.id == &"conductor":
		return Loc.t("select.conductor_core")
	return Loc.t("select.starts_with", [Loc.weapon_name(def.starting_weapon)])


func _show_character(id: StringName) -> void:
	_last_focused_character = id
	_preview_character(id)


func _hover_character(id: StringName) -> void:
	_hovered_character = id
	_preview_character(id)


func _pointer_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseMotion:
		_hover_character(id)


func _leave_character(id: StringName) -> void:
	if _hovered_character != id:
		return
	_hovered_character = &""
	var restore := _last_focused_character
	var keyboard := get_viewport().gui_get_focus_owner() as CastButton
	if keyboard != null:
		restore = StringName(keyboard.get_meta(&"character_id"))
	if restore != &"":
		_preview_character(restore)


func _preview_character(id: StringName) -> void:
	for raw in _cards:
		var actor := raw as CastButton
		actor.previewed = actor.get_meta(&"character_id") == id
		actor.queue_redraw()
	_detail.text = Loc.character_desc(id)
	_selection_note.text = Loc.t("select.current_use", [Loc.character_name(id)]) if _meta != null \
		and _meta.is_unlocked(id) else Loc.t("select.awaiting_release", [Loc.character_name(id)])


func _on_card(id: StringName) -> void:
	character_chosen.emit(id)


func _canvas_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() and get_viewport_rect().size.x > 0.0 else Vector2(1280, 720)


func _process(_delta: float) -> void:
	if _canvas_size() != _last_canvas:
		_adapt_layout()


func _adapt_layout(force: bool = false) -> void:
	if _stage == null:
		return
	var canvas := _canvas_size()
	if not force and canvas == _last_canvas:
		return
	var was_compact := _compact
	_last_canvas = canvas
	_compact = canvas.x < 1100.0 or canvas.y < 640.0
	if _compact and not was_compact:
		for index in _cards.size():
			if StringName(_cards[index].get_meta(&"character_id")) == _last_focused_character:
				page = int(index / 3)
	_stage.custom_minimum_size.x = minf(1160.0, canvas.x - 24.0)
	_department.visible = not _compact
	_subtitle.visible = not _compact
	_summary.visible = not _compact
	_logotype.add_theme_font_size_override("font_size", 32 if _compact else 44)
	_selection_note.add_theme_font_size_override("font_size", 18 if _compact else 22)
	_detail.custom_minimum_size = Vector2(_stage.custom_minimum_size.x - 16.0, 42.0 if _compact else 34.0)
	_detail.add_theme_font_size_override("font_size", 14 if _compact else 15)
	for raw in _cards:
		var card := raw as CastButton
		card.compact = _compact
		card.custom_minimum_size = Vector2(214.0, 200.0) if _compact else Vector2(182.0, 314.0)
		card._place_art()
	for button: Button in _footer.find_children("*", "Button", true, false):
		_fit_action(button, _compact)
		if _compact:
			button.custom_minimum_size.x = 120.0 if button in [_ascension_button, _daily_button] else (160.0 if button == _secondary_actions.back() else 80.0)
	for button: Button in [page_previous, page_next, continue_button]:
		_fit_action(button, _compact)
	seed_edit.custom_minimum_size.y = 28.0 if _compact else 34.0
	seed_edit.add_theme_font_size_override("font_size", 14 if _compact else 18)
	_apply_page()
	_hovered_character = &""
	if _last_focused_character != &"":
		_preview_character(_last_focused_character)


func _apply_page() -> void:
	var page_size := 3 if _compact else 6
	page = clampi(page, 0, maxi(0, ceili(float(_cards.size()) / page_size) - 1))
	for index in _cards.size():
		var shown := int(index / page_size) == page
		_cards[index].visible = shown
		_cards[index].focus_mode = Control.FOCUS_ALL if shown and not _cards[index].disabled else Control.FOCUS_NONE
	_pager.visible = _compact
	page_previous.disabled = page <= 0
	page_next.disabled = (page + 1) * page_size >= _cards.size()
	_page_label.text = Loc.t("workshop.page", [page + 1, maxi(1, ceili(float(_cards.size()) / page_size))])
	_rebuild_focus()


func _change_page(delta: int) -> void:
	page += delta
	_apply_page()
	_hovered_character = &""
	for card in _cards:
		if card.visible and not card.disabled:
			card.grab_focus()
			return
	for card in _cards:
		if card.visible:
			_preview_character(StringName(card.get_meta(&"character_id")))
			break
	(page_previous if not page_previous.disabled else page_next).grab_focus()


func _fit_action(button: Button, compact: bool) -> void:
	if not button.has_meta(&"select_wide_size"):
		button.set_meta(&"select_wide_size", button.custom_minimum_size)
		button.set_meta(&"select_wide_font", button.get_theme_font_size("font_size"))
		button.set_meta(&"select_wide_clip", button.clip_text)
		var styles: Dictionary = {}
		for state in ["normal", "hover", "pressed", "disabled"]:
			styles[state] = button.get_theme_stylebox(state)
		button.set_meta(&"select_wide_styles", styles)
		var colors: Dictionary = {}
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			colors[state] = button.get_theme_color(state)
		button.set_meta(&"select_wide_colors", colors)
	if compact:
		button.clip_text = true
		WorkshopUi.fit_button(button, 14, 28.0)
	else:
		button.custom_minimum_size = button.get_meta(&"select_wide_size")
		button.add_theme_font_size_override("font_size", int(button.get_meta(&"select_wide_font")))
		button.clip_text = bool(button.get_meta(&"select_wide_clip"))
		var styles: Dictionary = button.get_meta(&"select_wide_styles")
		for state: String in styles:
			button.add_theme_stylebox_override(state, styles[state])
		var colors: Dictionary = button.get_meta(&"select_wide_colors")
		for state: String in colors:
			button.add_theme_color_override(state, colors[state])
