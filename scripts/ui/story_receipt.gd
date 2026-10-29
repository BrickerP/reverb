class_name StoryReceipt
extends PanelContainer

signal dismissed
signal archive_requested

var title_label: Label
var body_label: Label
var archive_button: Button
var dismiss_button: Button
var _sim: Sim


func _ready() -> void:
	visibility_changed.connect(_release_if_hidden)
	visible = false
	custom_minimum_size = Vector2(370.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := UiTheme.paper_panel(UiTheme.CARD)
	paper.shape = InkStyleBox.Shape.TAG
	paper.variant = 17
	paper.content_margin_left = 18.0
	paper.content_margin_right = 20.0
	paper.content_margin_top = 14.0
	paper.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(UiTheme.label(Loc.t("story.receipt"), 12, UiTheme.DIM))
	title_label = UiTheme.label("", 23, UiTheme.INK)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)
	body_label = UiTheme.label("", 16, UiTheme.INK)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(330.0, 0.0)
	box.add_child(body_label)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	archive_button = Button.new()
	archive_button.text = Loc.t("story.archive")
	archive_button.custom_minimum_size.y = 40.0
	archive_button.pressed.connect(func() -> void: archive_requested.emit())
	actions.add_child(archive_button)
	dismiss_button = Button.new()
	dismiss_button.text = Loc.t("story.close")
	dismiss_button.custom_minimum_size.y = 40.0
	dismiss_button.pressed.connect(dismiss)
	actions.add_child(dismiss_button)
	UiFocus.cycle([archive_button, dismiss_button])


func display(sim: Sim) -> void:
	var receipt := StoryLedger.receipt(sim)
	visible = not receipt.is_empty()
	_sim = sim if visible else null
	if not visible:
		return
	title_label.text = Loc.t(receipt.name_key)
	body_label.text = Loc.t(receipt.body_key)
	accessibility_name = "%s. %s" % [title_label.text, body_label.text]


func dismiss() -> void:
	StoryLedger.dismiss(_sim)
	_sim = null
	visible = false
	dismissed.emit()


func _release_if_hidden() -> void:
	if not visible:
		_sim = null
