class_name VendingReceiptUi
extends Control

const PRINT_TIME := 0.7

var remaining := 0.0
var printed_uid := 0
var reduced_effects := false
var _paused := false
var _last_sim := 0
var _last_uid := 0
var _role: StringName = &"looper"
var _condition := 0
var _panel: Panel
var _machine: BureauFacilityUi
var _portrait: TextureRect
var _title: Label
var _detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.PAPER))
	add_child(_panel)
	_machine = BureauFacilityUi.new()
	_machine.position = Vector2(8, 8)
	_machine.size = Vector2(140, 144)
	_panel.add_child(_machine)
	_title = UiTheme.label("", 18)
	_title.clip_text = true
	_title.position = Vector2(151, 14)
	_title.size = Vector2(183, 27)
	_panel.add_child(_title)
	_detail = UiTheme.label("", 13, UiTheme.DIM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.position = Vector2(151, 45)
	_detail.size = Vector2(183, 104)
	_panel.add_child(_detail)
	_portrait = UiTheme.character_icon(&"looper", Vector2.ZERO)
	_machine.add_child(_portrait)
	visible = false
	get_viewport().size_changed.connect(_layout)


func show_take(take: EchoTake, sim: Sim) -> bool:
	if take == null or sim == null or not take.archived or take.uid <= 0 \
			or not sim.bank.takes.has(take) or sim.daily_modifier != &"" \
			or not EchoArchive.eligible(sim.character_id):
		return false
	if _last_sim == sim.get_instance_id() and _last_uid == take.uid:
		return false
	_last_sim = sim.get_instance_id()
	_last_uid = take.uid
	printed_uid = take.uid
	_role = sim.character_id
	_condition = ceili(take.condition)
	remaining = PRINT_TIME
	_paused = false
	_title.text = Loc.t("vending.title")
	_detail.text = Loc.t("vending.receipt", [printed_uid, _condition])
	var art := UiTheme.character_icon(_role, Vector2(34, 39))
	_portrait.texture = art.texture
	art.free()
	_machine.set_facility(&"vending_open")
	modulate.a = 1.0
	visible = true
	_layout()
	return true


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	_layout_print()


func set_paused(on: bool) -> void:
	_paused = on


func _process(delta: float) -> void:
	if not visible or _paused:
		return
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		skip()
		return
	_layout_print()
	if not reduced_effects:
		modulate.a = minf(1.0, remaining / 0.12)


func _layout() -> void:
	if _panel == null:
		return
	var extent := get_viewport_rect().size
	_panel.size = Vector2(350.0, 164.0)
	var bottom := 88.0 if extent.x < 1100.0 or extent.y < 640.0 else 40.0
	_panel.position = Vector2(maxf(40.0, extent.x - _panel.size.x - 24.0), maxf(90.0, extent.y - bottom - _panel.size.y - 10.0))
	_layout_print()


func _layout_print() -> void:
	if _portrait == null:
		return
	# The actual selected copy unfolds downward inside the empty output bay.
	# The machine artwork contains no baked-in person or additional identity.
	var progress := 1.0 if reduced_effects else clampf((PRINT_TIME - remaining) / 0.32, 0.0, 1.0)
	_portrait.position = Vector2(33.0, 50.0 + 10.0 * progress)
	_portrait.size = Vector2(35.0, 28.0 + 18.0 * progress)
	_portrait.modulate.a = 1.0 if reduced_effects else 0.3 + 0.7 * progress


func skip() -> void:
	remaining = 0.0
	visible = false
	modulate.a = 1.0


func reset() -> void:
	skip()
	printed_uid = 0
	_paused = false
