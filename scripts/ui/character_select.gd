class_name CharacterSelectUi
extends Control

signal character_chosen(id: StringName)
signal settings_requested
signal history_requested
signal daily_requested
signal codex_requested

# The click area stays still. Only the drawn ink, labels and portraits are offset.
class CastButton extends Button:
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
		if portrait != null:
			portrait.position = Vector2((width - 158.0) * 0.5, rise + 2.0)
			portrait.size = Vector2(158.0, 184.0)
		if name_label != null:
			name_label.position = Vector2(16.0, rise + 179.0)
			name_label.size = Vector2(width - 32.0, 38.0)
		if trait_label != null:
			trait_label.position = Vector2(12.0, rise + 224.0)
			trait_label.size = Vector2(width - 24.0, 28.0)
		if status_label != null:
			status_label.position = Vector2(10.0, rise + 262.0)
			status_label.size = Vector2(width - 20.0, 30.0)
		queue_redraw()

	func _draw() -> void:
		if tag_style == null or size.x <= 0.0:
			return
		var width := size.x
		var active := not disabled and previewed
		if active:
			draw_style_box(halo_style, Rect2(width * 0.5 - 99.0, rise + 15.0, 198.0, 157.0))
		draw_style_box(shadow_style, Rect2(width * 0.5 - 74.0, rise + 148.0, 148.0, 30.0))
		tag_style.border_color = paper_color if active else Color(UiTheme.INK, 0.58)
		tag_style.bg_color = UiTheme.CARD if active else UiTheme.PAPER
		draw_style_box(tag_style, Rect2(11.0, rise + 176.0, width - 22.0, 44.0))
		if disabled:
			var slash := PackedVector2Array([Vector2(width * 0.5 - 57.0, rise + 54.0),
				Vector2(width * 0.5 - 2.0, rise + 94.0), Vector2(width * 0.5 + 60.0, rise + 126.0)])
			draw_polyline(slash, Color(UiTheme.INK, 0.44), 3.0, true)
		if has_focus():
			# A short, hand-drawn underline belongs to the chosen name, not a card grid.
			var ink := PackedVector2Array([Vector2(width * 0.5 - 38.0, rise + 219.0),
				Vector2(width * 0.5 - 8.0, rise + 222.0), Vector2(width * 0.5 + 42.0, rise + 218.0)])
			draw_polyline(ink, paper_color, 2.0, true)

var _cards_box: HBoxContainer
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
	var stage := MarginContainer.new()
	stage.custom_minimum_size = Vector2(1160.0, 0.0)
	for side in ["left", "right", "top", "bottom"]:
		stage.add_theme_constant_override("margin_" + side, 12)
	center.add_child(stage)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	stage.add_child(box)
	var logotype := UiTheme.label(Loc.t("select.title"), 50, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	logotype.add_theme_font_override("font", load(UiTheme.TITLE_EN) as Font)
	box.add_child(logotype)
	box.add_child(UiTheme.label(Loc.t("brand.department"), 17, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("select.subtitle"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 6)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_cards_box)
	_selection_note = UiTheme.label("", 22, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_selection_note.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(_selection_note)
	_detail = UiTheme.label("", 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(1100.0, 34.0)
	box.add_child(_detail)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(UiTheme.label(Loc.t("select.seed"), 13, UiTheme.DIM))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = Loc.t("select.seed_hint")
	seed_edit.custom_minimum_size = Vector2(124.0, 34.0)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.max_length = 12
	footer.add_child(seed_edit)
	_ascension_button = Button.new()
	_ascension_button.custom_minimum_size = Vector2(152.0, 34.0)
	_ascension_button.add_theme_font_size_override("font_size", 12)
	_ascension_button.pressed.connect(_cycle_ascension)
	footer.add_child(_ascension_button)
	for key in ["select.codex", "select.settings", "select.history"]:
		var button := StitchedAction.new()
		button.text = Loc.t(key)
		button.flat = true
		button.custom_minimum_size = Vector2(138.0, 34.0)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_secondary_action.bind(key))
		footer.add_child(button)
		_secondary_actions.append(button)
	_daily_button = Button.new()
	_daily_button.text = Loc.t("select.daily")
	_daily_button.custom_minimum_size = Vector2(164.0, 38.0)
	_daily_button.pressed.connect(func() -> void: daily_requested.emit())
	UiTheme.stamp_button(_daily_button)
	footer.add_child(_daily_button)
	_secondary_actions.append(_daily_button)
	box.add_child(footer)
	_summary = UiTheme.label("", 13, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_summary)


func _secondary_action(key: String) -> void:
	match key:
		"select.codex": codex_requested.emit()
		"select.settings": settings_requested.emit()
		"select.history": history_requested.emit()


func refresh(meta: Meta, daily_seed: int = 0, daily_best: int = 0) -> void:
	if _meta != meta:
		_known_unlocks.clear()
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
	_update_ascension_button()
	_rebuild_focus()
	focus_default()
	if not newly_unlocked.is_empty():
		_selection_note.text = Loc.t("select.just_unlocked", [", ".join(newly_unlocked)])


func _rebuild_focus() -> void:
	var controls: Array[Control] = []
	var available: Array[Button] = []
	for card in _cards:
		if not card.disabled:
			controls.append(card)
			available.append(card)
	controls.append(seed_edit)
	controls.append(_ascension_button)
	controls.append_array(_secondary_actions)
	UiFocus.cycle(controls)
	for i in available.size():
		available[i].focus_neighbor_left = available[i].get_path_to(available[(i - 1 + available.size()) % available.size()])
		available[i].focus_neighbor_right = available[i].get_path_to(available[(i + 1) % available.size()])
		available[i].focus_neighbor_bottom = available[i].get_path_to(seed_edit)


func focus_default() -> void:
	for card in _cards:
		if not card.disabled:
			card.grab_focus()
			return


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
	card.custom_minimum_size = Vector2(274.0, 326.0)
	card.rise = [14.0, 0.0, 24.0, 7.0][index % 4]
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
	card.name_label = UiTheme.label(Loc.character_name(def.id), 29, card.paper_color, HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(card.name_label)
	var slots := int(def.overrides.get(Stats.ECHO_SLOTS, Stats.DEFAULTS[Stats.ECHO_SLOTS]))
	var power := float(def.overrides.get(Stats.ECHO_POWER, Stats.DEFAULTS[Stats.ECHO_POWER]))
	var core: String
	if slots <= 0:
		core = Loc.t("select.solo_core")
	elif def.live_echo:
		core = Loc.t("select.live_echo")
	elif def.id == &"conductor":
		core = Loc.t("select.conductor_core")
	else:
		core = Loc.t("select.echo_line", [slots, int(round(power * 100.0))])
	card.trait_label = UiTheme.label(core, 15, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	card.trait_label.custom_minimum_size = Vector2(250.0, 0.0)
	card.trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(card.trait_label)
	var status := Loc.t("select.ready")
	if locked:
		status = Loc.t("select.locked_wins") if def.unlock_wins > 0 else Loc.t("select.locked", [def.unlock_wave])
	card.status_label = UiTheme.label(status, 13, UiTheme.WARN if locked else UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	card.status_label.custom_minimum_size = Vector2(254.0, 0.0)
	card.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(card.status_label)
	card.tooltip_text = Loc.character_desc(def.id)
	card.accessibility_description = "%s · %s" % [Loc.character_desc(def.id), status]
	return card


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
