class_name SettingsUi
extends Control

signal volume_changed(value: float)
signal music_volume_changed(value: float)
signal effects_volume_changed(value: float)
signal shake_changed(on: bool)
signal reduced_effects_changed(on: bool)
signal fullscreen_changed(on: bool)
signal language_changed(code: String)
signal closed

var volume_slider: HSlider
var volume_value: Label
var music_volume_slider: HSlider
var effects_volume_slider: HSlider
var music_volume_value: Label
var effects_volume_value: Label
var shake_check: CheckButton
var reduced_effects_check: CheckButton
var fullscreen_check: CheckButton
var language_option: OptionButton
var error_label: Label
var close_button: Button

var _syncing := false
var _aside: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680.0, 0.0)
	var sheet := UiTheme.surface_panel().duplicate() as InkStyleBox
	sheet.shape = InkStyleBox.Shape.PAPER
	sheet.softness = 64.0
	sheet.variant = 22
	panel.add_theme_stylebox_override("panel", sheet)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("settings.title"), 44, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))

	_aside = UiTheme.label(Loc.t("settings.aside"), 15, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_aside)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	volume_row.add_child(UiTheme.label(Loc.t("settings.volume"), 18, UiTheme.DIM))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(260.0, 28.0)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.accessibility_name = Loc.t("settings.volume")
	volume_slider.value_changed.connect(_on_volume)
	volume_row.add_child(volume_slider)
	volume_value = UiTheme.label("80%", 16, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	volume_value.custom_minimum_size = Vector2(56.0, 0.0)
	volume_row.add_child(volume_value)
	box.add_child(volume_row)
	music_volume_slider = HSlider.new()
	effects_volume_slider = HSlider.new()
	music_volume_value = UiTheme.label("", 16, UiTheme.INK)
	effects_volume_value = UiTheme.label("", 16, UiTheme.INK)
	box.add_child(_audio_row("settings.music_volume", music_volume_slider, music_volume_value))
	box.add_child(_audio_row("settings.effects_volume", effects_volume_slider, effects_volume_value))
	music_volume_slider.value_changed.connect(_on_music_volume)
	effects_volume_slider.value_changed.connect(_on_effects_volume)

	box.add_child(UiTheme.label(Loc.t("settings.motion_group"), 22, UiTheme.INK))
	shake_check = CheckButton.new()
	shake_check.text = Loc.t("settings.shake")
	shake_check.flat = true
	shake_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shake_check.accessibility_name = Loc.t("settings.shake")
	shake_check.toggled.connect(_on_shake)
	box.add_child(shake_check)
	reduced_effects_check = CheckButton.new()
	reduced_effects_check.text = Loc.t("settings.reduced_effects")
	reduced_effects_check.tooltip_text = Loc.t("settings.reduced_hint")
	reduced_effects_check.accessibility_name = Loc.t("settings.reduced_effects")
	reduced_effects_check.accessibility_description = Loc.t("settings.reduced_hint")
	reduced_effects_check.flat = true
	reduced_effects_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reduced_effects_check.toggled.connect(_on_reduced_effects)
	box.add_child(reduced_effects_check)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = Loc.t("settings.fullscreen")
	fullscreen_check.flat = true
	fullscreen_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fullscreen_check.accessibility_name = Loc.t("settings.fullscreen")
	fullscreen_check.toggled.connect(_on_fullscreen)
	box.add_child(fullscreen_check)

	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 12)
	language_row.add_child(UiTheme.label(Loc.t("settings.language"), 18, UiTheme.DIM))
	language_option = OptionButton.new()
	language_option.add_item(Loc.t("settings.auto"))
	language_option.set_item_metadata(0, "")
	language_option.add_item("English")
	language_option.set_item_metadata(1, "en")
	language_option.add_item("中文")
	language_option.set_item_metadata(2, "zh")
	language_option.accessibility_name = Loc.t("settings.language")
	language_option.item_selected.connect(_on_language)
	language_row.add_child(language_option)
	box.add_child(language_row)
	error_label = UiTheme.label("", 13, UiTheme.WARN)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	box.add_child(error_label)

	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(160.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	UiTheme.stamp_button(close_button)
	box.add_child(close_button)


func open(settings: Settings) -> void:
	_aside.text = Loc.t("settings.aside")
	_syncing = true
	volume_slider.value = settings.volume
	volume_value.text = "%d%%" % int(round(settings.volume * 100.0))
	music_volume_slider.value = settings.music_volume
	effects_volume_slider.value = settings.effects_volume
	music_volume_value.text = "%d%%" % int(round(settings.music_volume * 100.0))
	effects_volume_value.text = "%d%%" % int(round(settings.effects_volume * 100.0))
	shake_check.button_pressed = settings.shake
	reduced_effects_check.button_pressed = settings.reduced_effects
	fullscreen_check.button_pressed = settings.fullscreen
	var index := 0 if settings.language == "" else (1 if settings.language == "en" else 2)
	language_option.select(index)
	language_option.disabled = false
	error_label.visible = false
	error_label.text = ""
	_syncing = false
	visible = true
	UiFocus.cycle([volume_slider, music_volume_slider, effects_volume_slider, shake_check, reduced_effects_check, fullscreen_check,
			language_option, close_button])
	volume_slider.grab_focus()
	UiTheme.animate_open(self, settings.reduced_effects)


func close() -> void:
	visible = false
	closed.emit()


func _on_volume(value: float) -> void:
	volume_value.text = "%d%%" % int(round(value * 100.0))
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		volume_changed.emit(value)


func _on_shake(on: bool) -> void:
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		shake_changed.emit(on)


func _on_reduced_effects(on: bool) -> void:
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		reduced_effects_changed.emit(on)


func _on_fullscreen(on: bool) -> void:
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		fullscreen_changed.emit(on)


func _on_language(index: int) -> void:
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		language_changed.emit(str(language_option.get_item_metadata(index)))


func _audio_row(key: String, slider: HSlider, value: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := UiTheme.label(Loc.t(key), 18, UiTheme.DIM)
	label.custom_minimum_size.x = 114.0
	row.add_child(label)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(260.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.accessibility_name = Loc.t(key)
	row.add_child(slider)
	value.custom_minimum_size.x = 56.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _on_music_volume(value: float) -> void:
	music_volume_value.text = "%d%%" % int(round(value * 100.0))
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		music_volume_changed.emit(value)


func _on_effects_volume(value: float) -> void:
	effects_volume_value.text = "%d%%" % int(round(value * 100.0))
	if not _syncing:
		_aside.text = Loc.t("settings.changed")
		effects_volume_changed.emit(value)


func show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()
