class_name ShopUi
extends Control

signal start_requested

var sim: Sim
var offers_box: VBoxContainer
var reroll_button: Button
var start_button: Button
var echo_panel: EchoPanel

var _title: Label
var _materials: Label
var _warning: Label
var _build_panel: BuildPanel


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.93)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_build_header())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	columns.add_child(_build_left())
	_build_panel = BuildPanel.new()
	columns.add_child(_build_panel)
	echo_panel = EchoPanel.new()
	echo_panel.discard_requested.connect(_on_discard)
	columns.add_child(echo_panel)


func open(s: Sim) -> void:
	sim = s
	visible = true
	refresh()
	_focus_card(0)


func refresh() -> void:
	_title.text = Loc.t("shop.title", [sim.wave])
	_materials.text = "%s  %d" % [Loc.t("hud.materials"), sim.player.materials]
	UiTheme.clear(offers_box)
	for o in sim.shop.offers:
		var card := OfferCard.new()
		offers_box.add_child(card)
		card.setup(o, sim)
		card.pressed.connect(_on_offer.bind(o))
	var cost := sim.shop.reroll_cost(sim.wave)
	reroll_button.text = Loc.t("shop.reroll", [cost])
	reroll_button.disabled = sim.player.materials < cost
	start_button.text = Loc.t("shop.start", [sim.wave + 1])
	start_button.disabled = not sim.can_start_wave()
	var over := sim.bank.overflow(sim.echo_capacity())
	_warning.text = Loc.t("shop.over", [over]) if over > 0 else ""
	_build_panel.refresh(sim)
	echo_panel.refresh(sim)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	_title = UiTheme.label("", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials = UiTheme.label("", 26, UiTheme.COIN, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(_title)
	row.add_child(_materials)
	return row


func _build_left() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(400.0, 0.0)
	column.add_theme_constant_override("separation", 10)
	offers_box = VBoxContainer.new()
	offers_box.add_theme_constant_override("separation", 8)
	column.add_child(offers_box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(150.0, 52.0)
	reroll_button.pressed.connect(_on_reroll)
	buttons.add_child(reroll_button)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0.0, 52.0)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_on_start)
	buttons.add_child(start_button)
	column.add_child(buttons)
	_warning = UiTheme.label("", 16, UiTheme.WARN)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_warning)
	return column


func _on_offer(o: Offer) -> void:
	var index := sim.shop.offers.find(o)
	if sim.shop.buy(sim, o):
		refresh()
		_focus_card(index)


func _on_reroll() -> void:
	if sim.shop.reroll(sim):
		refresh()
		if reroll_button.disabled:
			_focus_card(0)


func _on_discard(take: EchoTake) -> void:
	sim.discard_take(take)
	refresh()
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_start() -> void:
	if sim.can_start_wave():
		visible = false
		start_requested.emit()


func _focus_card(from: int) -> void:
	var cards := offers_box.get_children()
	for i in cards.size():
		var card := cards[(from + i) % cards.size()] as OfferCard
		if not card.disabled:
			card.grab_focus()
			return
	for b: Button in [start_button, reroll_button]:
		if not b.disabled:
			b.grab_focus()
			return
