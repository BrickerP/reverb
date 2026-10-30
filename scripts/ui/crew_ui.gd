class_name CrewUi
extends Control

signal action_requested(id: StringName)
signal undo_requested
signal closed

class WorkerPortrait extends Control:
	func _draw() -> void:
		ExpeditionInk.draw_worker(self, Vector2(22.0, 37.0), true)

var action_buttons: Array[Button] = []
var witness_labels: Array[Label] = []
var undo_button: Button
var return_button: Button
var _title: Label
var _body: Label
var _rows: VBoxContainer
var _last_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.97)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiTheme.surface_panel())
	margin.add_child(paper)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	paper.add_child(content)
	_title = UiTheme.section_label("", 30)
	content.add_child(_title)
	_body = UiTheme.label("", 14, UiTheme.DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	undo_button = Button.new()
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WorkshopUi.fit_button(undo_button, 15, 36.0)
	undo_button.pressed.connect(func() -> void: undo_requested.emit())
	actions.add_child(undo_button)
	return_button = Button.new()
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WorkshopUi.fit_button(return_button, 15, 36.0)
	return_button.pressed.connect(close)
	actions.add_child(return_button)
	visible = false


func open_crew(sim: Sim) -> void:
	_title.text = Loc.t("crew.title")
	_title.add_theme_font_override("font", UiTheme.title_font(_title.text))
	_body.text = Loc.t("crew.summary")
	UiTheme.clear(_rows)
	action_buttons.clear()
	witness_labels.clear()
	_last_focus = null
	var world := Expedition.world_profile(sim)
	var options := Expedition.crew_options(sim)
	_rows.add_child(UiTheme.section_label(Loc.t("crew.bosses"), 21))
	for kind: StringName in Expedition.BOSS_IDS:
		var roster: Dictionary = {}
		for candidate: Dictionary in world["roster"]:
			if candidate["kind"] == kind:
				roster = candidate
		var option := _option(options, kind)
		var state := str(roster.get("state", &"unsigned"))
		var detail := Loc.t("crew.state." + state)
		if not roster.is_empty():
			detail += " · " + Loc.t("crew.condition", [ceili(float(roster["hp"])), ceili(float(roster["max_hp"])), ceili(float(roster["life"]))])
		var portrait := UiTheme.art_icon(StringName("enemy_" + String(kind)), Vector2(54.0, 54.0))
		_add_row(sim, portrait, Loc.enemy_name(kind), detail, option, &"deploy")
	_rows.add_child(UiTheme.section_label(Loc.t("crew.people"), 21))
	var safe := 0
	for worker: Dictionary in world["workers"]:
		if worker["state"] not in [&"safe", &"exited"]:
			continue
		safe += 1
		var title := Loc.t("crew.worker_number", [int(worker["stage"])])
		var detail := Loc.t("crew.worker_exited" if worker["state"] == &"exited" else "crew.worker_safe")
		detail += " · " + Loc.t("crew.aid_used" if worker["aid_used"] else "crew.aid_ready")
		var portrait := WorkerPortrait.new()
		portrait.custom_minimum_size = Vector2(44.0, 54.0)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var option := _option(options, StringName("aid_" + String(worker["id"])))
		_add_row(sim, portrait, title, detail, option, &"aid")
	if safe == 0:
		var empty := UiTheme.label(Loc.t("crew.people_empty"), 14, UiTheme.DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(empty)
	_add_witnesses(sim, world)
	# The latest actual departure stays visible even after another ally deploys.
	for index in range(world["history"].size() - 1, -1, -1):
		var event: Dictionary = world["history"][index]
		if event["kind"] == &"companion_departed":
			var departure := UiTheme.label(Loc.t("crew.departure", [Loc.enemy_name(event["subject"]), event["stage"]]), 14, UiTheme.DIM)
			departure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_rows.add_child(departure)
			break
	undo_button.text = Loc.t("shop.undo")
	undo_button.tooltip_text = Loc.t("crew.undo_hint")
	undo_button.accessibility_description = undo_button.tooltip_text
	undo_button.disabled = not sim.shop.can_undo()
	return_button.text = Loc.t("crew.return")
	visible = true
	var controls: Array = []
	for button in action_buttons:
		if not button.disabled:
			controls.append(button)
	for label: Label in witness_labels:
		controls.append(label)
	if not undo_button.disabled:
		controls.append(undo_button)
	controls.append(return_button)
	UiFocus.cycle(controls)
	focus_default()


func _add_witnesses(sim: Sim, world: Dictionary) -> void:
	_rows.add_child(UiTheme.section_label(Loc.t("crew.witnesses"), 21))
	var count := 0
	for id: StringName in world.get("witnesses", []):
		if count >= 21:
			break
		var title := ""
		var detail := ""
		if id == &"self":
			title = Loc.t("crew.witness_self")
			detail = Loc.t("crew.witness_self_status")
		elif String(id).begins_with("worker_"):
			for worker: Dictionary in world["workers"]:
				if worker["id"] == id:
					title = Loc.t("crew.worker_number", [int(worker["stage"])])
					detail = Loc.t("crew.testimony_used" if worker["testimony_used"] else "crew.testimony_ready")
					break
		elif String(id).begins_with("copy_"):
			var uid := int(String(id).trim_prefix("copy_"))
			title = Loc.t("crew.witness_copy", [uid])
			detail = Loc.t("crew.witness_copy_retained")
			for take: EchoTake in sim.bank.takes:
				if take.uid == uid:
					detail = Loc.t("crew.witness_copy_condition", [ceili(take.condition)])
					break
		if title.is_empty():
			continue
		var label := UiTheme.label(title + " · " + detail, 14, UiTheme.DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.set_meta(&"witness_id", id)
		label.focus_mode = Control.FOCUS_ALL
		label.accessibility_name = label.text
		label.focus_entered.connect(func() -> void:
			_last_focus = label
			label.add_theme_color_override("font_color", UiTheme.ACCENT))
		label.focus_exited.connect(func() -> void: label.add_theme_color_override("font_color", UiTheme.DIM))
		_rows.add_child(label)
		witness_labels.append(label)
		count += 1
	if count == 0:
		var empty := UiTheme.label(Loc.t("crew.witnesses_empty"), 14, UiTheme.DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(empty)


func _add_row(sim: Sim, portrait: Control, title: String, detail: String, option: Dictionary, action: StringName) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.paper_panel(UiTheme.CARD))
	_rows.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	words.add_child(UiTheme.label(title, 17))
	var description := UiTheme.label(detail, 14, UiTheme.DIM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(description)
	if option.is_empty():
		return
	var id := StringName(option["id"])
	var quote := sim.shop.quote(ShopResult.DEPLOY_COMPANION, sim, null, -1, id)
	var reason := Loc.t(str(option["reason_key"])) if not str(option["reason_key"]).is_empty() else ""
	if not reason.is_empty():
		var blocked := UiTheme.label(reason, 13, UiTheme.DIM)
		blocked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(blocked)
	var button := Button.new()
	button.text = Loc.t("crew.action." + String(action))
	WorkshopUi.fit_button(button, 14, 34.0)
	button.disabled = not quote.ok
	button.set_meta(&"crew_id", id)
	button.accessibility_name = title + " · " + button.text
	button.accessibility_description = detail + " · " + Loc.t(str(option["description_key"])) + " · " + reason
	button.tooltip_text = button.accessibility_description
	button.pressed.connect(func() -> void: action_requested.emit(id))
	button.focus_entered.connect(func() -> void: _last_focus = button)
	row.add_child(button)
	action_buttons.append(button)


static func _option(options: Array[Dictionary], id: StringName) -> Dictionary:
	for option in options:
		if option["id"] == id:
			return option
	return {}


func focus_default() -> void:
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() and (not _last_focus is BaseButton or not (_last_focus as BaseButton).disabled):
		_last_focus.grab_focus()
		return
	for button in action_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	if not witness_labels.is_empty():
		witness_labels[0].grab_focus()
	elif not undo_button.disabled:
		undo_button.grab_focus()
	else:
		return_button.grab_focus()


func reset() -> void:
	visible = false
	_last_focus = null


func close() -> void:
	reset()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		accept_event()
