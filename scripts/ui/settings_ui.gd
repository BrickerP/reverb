class_name SettingsUi
extends Control

signal volume_changed(value: float)
signal shake_changed(on: bool)
signal fullscreen_changed(on: bool)
signal language_changed(code: String)
signal closed

var volume_slider: HSlider
var volume_value: Label
var shake_check: CheckButton
var fullscreen_check: CheckButton
var language_option: OptionButton
var close_button: Button

var _syncing := false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiTheme.box(
			Color(0.03, 0.04, 0.09, 0.98), Color(0.3, 0.5, 0.9, 0.6), 2, 10))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	box.add_child(UiTheme.label(Loc.t("settings.title"), 34, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	volume_row.add_child(UiTheme.label(Loc.t("settings.volume"), 18, UiTheme.DIM))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(260.0, 28.0)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume)
	volume_row.add_child(volume_slider)
	volume_value = UiTheme.label("80%", 16, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	volume_value.custom_minimum_size = Vector2(56.0, 0.0)
	volume_row.add_child(volume_value)
	box.add_child(volume_row)

	shake_check = CheckButton.new()
	shake_check.text = Loc.t("settings.shake")
	shake_check.flat = true
	shake_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shake_check.toggled.connect(_on_shake)
	box.add_child(shake_check)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = Loc.t("settings.fullscreen")
	fullscreen_check.flat = true
	fullscreen_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	language_option.item_selected.connect(_on_language)
	language_row.add_child(language_option)
	box.add_child(language_row)

	close_button = Button.new()
	close_button.text = Loc.t("settings.close")
	close_button.custom_minimum_size = Vector2(160.0, 44.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open(settings: Settings) -> void:
	_syncing = true
	volume_slider.value = settings.volume
	volume_value.text = "%d%%" % int(round(settings.volume * 100.0))
	shake_check.button_pressed = settings.shake
	fullscreen_check.button_pressed = settings.fullscreen
	var index := 0 if settings.language == "" else (1 if settings.language == "en" else 2)
	language_option.select(index)
	_syncing = false
	visible = true
	close_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _on_volume(value: float) -> void:
	volume_value.text = "%d%%" % int(round(value * 100.0))
	if not _syncing:
		volume_changed.emit(value)


func _on_shake(on: bool) -> void:
	if not _syncing:
		shake_changed.emit(on)


func _on_fullscreen(on: bool) -> void:
	if not _syncing:
		fullscreen_changed.emit(on)


func _on_language(index: int) -> void:
	if not _syncing:
		language_changed.emit(str(language_option.get_item_metadata(index)))
