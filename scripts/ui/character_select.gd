class_name CharacterSelectUi
extends Control

signal character_chosen(id: StringName)
signal settings_requested
signal history_requested
signal daily_requested
signal codex_requested

var _cards_box: HBoxContainer
var _summary: Label
var _cards: Array[Button] = []
var _daily_button: Button
var _ascension_button: Button
var _meta: Meta
var seed_edit: LineEdit


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.97)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("select.title"), 40, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(Loc.t("select.subtitle"), 16, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 20)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_cards_box)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_child(UiTheme.label(Loc.t("select.seed"), 14, UiTheme.DIM))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = Loc.t("select.seed_hint")
	seed_edit.custom_minimum_size = Vector2(160.0, 32.0)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.max_length = 12
	seed_row.add_child(seed_edit)
	_ascension_button = Button.new()
	_ascension_button.custom_minimum_size = Vector2(156.0, 32.0)
	_ascension_button.add_theme_font_size_override("font_size", 12)
	_ascension_button.pressed.connect(_cycle_ascension)
	seed_row.add_child(_ascension_button)
	box.add_child(seed_row)
	_summary = UiTheme.label("", 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_summary)
	box.add_child(UiTheme.label(Loc.t("select.hint"), 13, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var codex_button := Button.new()
	codex_button.text = Loc.t("select.codex")
	codex_button.custom_minimum_size = Vector2(160.0, 36.0)
	codex_button.pressed.connect(func() -> void: codex_requested.emit())
	buttons.add_child(codex_button)
	var settings_button := Button.new()
	settings_button.text = Loc.t("select.settings")
	settings_button.custom_minimum_size = Vector2(160.0, 36.0)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	buttons.add_child(settings_button)
	var history_button := Button.new()
	history_button.text = Loc.t("select.history")
	history_button.custom_minimum_size = Vector2(160.0, 36.0)
	history_button.pressed.connect(func() -> void: history_requested.emit())
	buttons.add_child(history_button)
	var daily_button := Button.new()
	daily_button.text = Loc.t("select.daily")
	daily_button.custom_minimum_size = Vector2(160.0, 36.0)
	daily_button.pressed.connect(func() -> void: daily_requested.emit())
	buttons.add_child(daily_button)
	_daily_button = daily_button
	box.add_child(buttons)


func refresh(meta: Meta, daily_seed: int = 0, daily_best: int = 0) -> void:
	_meta = meta
	UiTheme.clear(_cards_box)
	_cards.clear()
	for def: CharacterDef in Content.characters().values():
		var card := _make_card(def, meta)
		_cards_box.add_child(card)
		_cards.append(card)
	_summary.text = "%s  ·  v%s" % [Loc.t("select.best", [meta.best_wave, meta.wins]),
			str(ProjectSettings.get_setting("application/config/version", ""))]
	_daily_button.text = Loc.t("select.daily_best", [daily_best]) if daily_best > 0 else Loc.t("select.daily")
	_update_ascension_button()
	for card in _cards:
		if not card.disabled:
			card.grab_focus()
			break


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


func _make_card(def: CharacterDef, meta: Meta) -> Button:
	var locked := not meta.is_unlocked(def.id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(245.0, 300.0)
	card.disabled = locked
	card.accessibility_name = Loc.character_name(def.id)
	var normal := UiTheme.box(Color(0.05, 0.06, 0.12), def.color, 2, 8)
	var hover := UiTheme.box(Color(0.08, 0.1, 0.2), def.color.lightened(0.2), 3, 8)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.pressed.connect(_on_card.bind(def.id))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	# Portrait and name share one header row so long localized descriptions retain
	# enough vertical space for their status and unlock line inside the fixed card.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	var portrait := UiTheme.character_icon(def.id, Vector2(60.0, 64.0))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.modulate = Color(1.0, 1.0, 1.0, 0.62 if locked else 1.0)
	header.add_child(portrait)
	var name_label := UiTheme.label(Loc.character_name(def.id), 24, def.color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(name_label)
	box.add_child(header)
	var desc := UiTheme.label(Loc.character_desc(def.id), 15, UiTheme.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.custom_minimum_size = Vector2(200.0, 0.0)
	box.add_child(desc)
	var slots := int(def.overrides.get(Stats.ECHO_SLOTS, Stats.DEFAULTS[Stats.ECHO_SLOTS]))
	var power := float(def.overrides.get(Stats.ECHO_POWER, Stats.DEFAULTS[Stats.ECHO_POWER]))
	if slots <= 0:
		box.add_child(UiTheme.label(Loc.t("select.no_echo"), 16, UiTheme.WARN))
	elif def.live_echo:
		box.add_child(UiTheme.label(Loc.t("select.live_echo"), 16, def.color))
	else:
		var echo_line := UiTheme.label(Loc.t("select.echo_line", [slots, int(round(power * 100.0))]), 16, UiTheme.ECHO)
		echo_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		echo_line.custom_minimum_size = Vector2(200.0, 0.0)
		box.add_child(echo_line)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var status_text := Loc.t("select.ready")
	if locked:
		if def.unlock_wins > 0:
			status_text = Loc.t("select.locked_wins")
		else:
			status_text = Loc.t("select.locked", [def.unlock_wave])
	box.add_child(UiTheme.label(status_text, 14, UiTheme.WARN if locked else UiTheme.COIN))
	card.accessibility_description = "%s · %s" % [Loc.character_desc(def.id), status_text]
	return card


func _on_card(id: StringName) -> void:
	character_chosen.emit(id)
