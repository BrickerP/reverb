class_name ShopUi
extends Control

signal start_requested
signal receipt_requested

const MAX_PENDING_FEEDBACK := 8
const FEEDBACK_EXPIRY_MSEC := 800
const ON_DARK := Color("dbceab")
const ERROR_ON_DARK := Color("efb08f")

var sim: Sim
var offers_box: GridContainer
var reroll_button: Button
var undo_button: Button
var start_button: Button
var receipt_button: Button
var crew_button: Button
var debt_button: Button
var confession_button: Button
var confession: ConfessionUi
var binding_ceremony: BindingCeremonyUi
var crew: CrewUi
var echo_panel: EchoPanel
var build_panel: BuildPanel

var _title: Label
var _materials: Label
var _interest: Label
var _prep_status: Label
var _footer: Label
var _warning: Label
var workshop: WorkshopUi
var _workshop_slot := 0
var _workshop_origin := &"weapon"
var _last_focus: Control
var _overlay: Control
var _replacing: Offer
var _replacing_index: int = -1
var _connected_shop: Shop
var _connected_sim: Sim
var _weapon_detail := ""
var _pending_feedback: Dictionary = {}
var _feedback_epoch := 0
var _refresh_generation := 0
var reduced_effects := false
var last_feedback: Dictionary = {}
var material_feedback_runs := 0
var _material_feedback_tween: Tween
var _offers_scroll: ScrollContainer
var _vendor_art: TextureRect
var _vendor_line: Label
var _vendor_tween: Tween
var _vendor_receipt: Control
var vendor_feedback_runs := 0
var last_vendor_reaction: StringName = &"idle"


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.EDGE, 0.98)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(_build_header())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	columns.add_child(_build_left())
	var dossier := VBoxContainer.new()
	dossier.custom_minimum_size = Vector2(0.0, 0.0)
	dossier.size_flags_stretch_ratio = 1.0
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.add_theme_constant_override("separation", 6)
	columns.add_child(dossier)
	build_panel = BuildPanel.new()
	build_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_panel.size_flags_stretch_ratio = 1.0
	build_panel.replace_cancelled.connect(_cancel_replace)
	build_panel.upgrade_requested.connect(_on_upgrade_weapon)
	build_panel.evolve_requested.connect(_on_evolve_weapon)
	build_panel.detail_changed.connect(_on_weapon_detail)
	build_panel.workshop_requested.connect(_open_weapon_workshop)
	dossier.add_child(build_panel)
	echo_panel = EchoPanel.new()
	echo_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	echo_panel.size_flags_stretch_ratio = 1.2
	echo_panel.discard_requested.connect(_on_discard)
	echo_panel.merge_workbench_requested.connect(_open_merge_hosts)
	echo_panel.detail_requested.connect(_open_echo_detail)
	echo_panel.repair_requested.connect(_on_repair_echo)
	dossier.add_child(echo_panel)
	root.add_child(_build_footer())
	workshop = WorkshopUi.new()
	workshop.z_index = 10
	add_child(workshop)
	workshop.closed.connect(_on_workshop_closed)
	crew = CrewUi.new()
	crew.z_index = 11
	add_child(crew)
	crew.action_requested.connect(_on_crew_action)
	crew.undo_requested.connect(_on_crew_undo)
	crew.closed.connect(_on_crew_closed)
	confession = ConfessionUi.new()
	confession.z_index = 12
	add_child(confession)
	confession.chosen.connect(_on_confession_chosen)
	confession.closed.connect(_on_confession_closed)
	binding_ceremony = BindingCeremonyUi.new()
	binding_ceremony.z_index = 9
	add_child(binding_ceremony)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _exit_tree() -> void:
	_disconnect_shop()


func open(s: Sim) -> void:
	_disconnect_shop()
	workshop.reset()
	crew.reset()
	confession.reset()
	binding_ceremony.reset()
	_workshop_origin = &"weapon"
	_last_focus = null
	sim = s
	_connected_shop = sim.shop
	_connected_shop.shop_history_changed.connect(_on_history_changed)
	_connected_shop.shop_action_resolved.connect(_on_shop_action_resolved)
	_connected_sim = sim
	_connected_sim.weapon_changed.connect(_on_weapon_changed)
	material_feedback_runs = 0
	vendor_feedback_runs = 0
	last_vendor_reaction = &"idle"
	_vendor_line.text = Loc.t("shop.vendor_idle")
	_vendor_line.add_theme_color_override("font_color", ON_DARK)
	last_feedback.clear()
	visible = true
	UiTheme.animate_open(self, reduced_effects)
	_replacing = null
	_replacing_index = -1
	refresh(true)
	_fly_take_token()
	# If the bank is over capacity, the discard is the only legal action: put focus there.
	if sim.bank.overflow(sim.echo_capacity()) > 0 and echo_panel.focus_first_discard():
		return
	_focus_card(0)


func close_session() -> void:
	_disconnect_shop()
	visible = false
	if workshop != null:
		workshop.reset()
	if crew != null:
		crew.reset()
	if confession != null:
		confession.reset()
	if binding_ceremony != null:
		binding_ceremony.reset()
	_workshop_origin = &"weapon"
	_last_focus = null
	sim = null
	_replacing = null
	_replacing_index = -1
	_weapon_detail = ""
	if offers_box != null:
		UiTheme.clear(offers_box)
	if build_panel != null:
		build_panel.close_session()
	if echo_panel != null:
		echo_panel.close_session()
	if _overlay != null:
		UiTheme.clear(_overlay)
	if _footer != null:
		_footer.text = Loc.t("shop.keys")
	if receipt_button != null:
		receipt_button.visible = false


func refresh(animate_echo: bool = false) -> void:
	_refresh_generation += 1
	if _replacing != null and (not sim.shop.offers.has(_replacing) or _replacing.sold):
		_replacing = null
		_replacing_index = -1
	_title.text = Loc.t("shop.title", [sim.wave])
	_materials.text = "%s  %d" % [Loc.t("hud.materials"), sim.player.materials]
	_interest.text = Loc.t("shop.economy", [sim.last_wave_earned, sim.last_interest,
			Sim.interest_for(sim.player.materials)])
	var expedition := Expedition.status(sim)
	_prep_status.text = Loc.t(str(expedition.objective))
	var world := Expedition.world_profile(sim)
	_prep_status.text = Loc.t(str(world.production_state_key)) + " · " + _prep_status.text
	if int(expedition.debt) > 0:
		_prep_status.text += " · " + Loc.t("hud.debt", [expedition.debt])
	var next_delivery := BureauEvents.forecast(sim.next_wave_number(), sim.endless)
	if next_delivery:
		_prep_status.text = Loc.t("bureau.delivery.next_short") + " · " + _prep_status.text
	_prep_status.tooltip_text = _prep_status.text + " · " + Loc.t(str(expedition.route))
	if next_delivery:
		_prep_status.tooltip_text += " · " + Loc.t("bureau.delivery.forecast", [BureauEvents.REWARD])
	_prep_status.accessibility_description = _prep_status.tooltip_text
	UiTheme.clear(offers_box)
	for o in sim.shop.offers:
		var card := OfferCard.new()
		offers_box.add_child(card)
		card.reduced_effects = reduced_effects
		card.setup(o, sim, o == _replacing, drag_payload_for, clear_drop_hint)
		card.pressed.connect(_on_offer.bind(o, card))
		card.replacement_requested.connect(_begin_replace)
		card.lock_toggled.connect(_on_lock_offer)
		var show_decision := func() -> void:
			if _footer != null:
				_footer.text = OfferCard.decision(o, sim)
		card.focus_entered.connect(show_decision)
		card.mouse_entered.connect(show_decision)
	var cost := sim.shop.reroll_cost(sim.wave)
	reroll_button.text = Loc.t("workshop.reroll_prices", [cost, sim.shop.next_reroll_cost(sim.wave)])
	var reroll_quote := sim.shop.quote(ShopResult.REROLL, sim)
	reroll_button.disabled = not reroll_quote.ok
	if reroll_button.disabled:
		reroll_button.text += " · " + _drop_reason_text(reroll_quote.reason)
	reroll_button.tooltip_text = _drop_reason_text(reroll_quote.reason) if not reroll_quote.ok else reroll_button.text
	reroll_button.accessibility_description = reroll_button.tooltip_text
	undo_button.text = Loc.t("shop.undo")
	undo_button.disabled = not sim.shop.can_undo()
	crew_button.text = Loc.t("crew.open")
	crew_button.accessibility_name = crew_button.text
	crew_button.tooltip_text = Loc.t("crew.summary")
	debt_button.text = Loc.t("debt.open", [int(expedition.debt)])
	debt_button.tooltip_text = Loc.t("debt.rule")
	debt_button.accessibility_name = debt_button.text
	debt_button.accessibility_description = debt_button.tooltip_text
	confession_button.text = Loc.t("confession.ui.open")
	confession_button.tooltip_text = Loc.t("confession.ui.rule")
	confession_button.accessibility_name = confession_button.text
	confession_button.accessibility_description = confession_button.tooltip_text
	start_button.text = Loc.t("shop.start", [sim.next_wave_number()])
	start_button.tooltip_text = Loc.t("bureau.delivery.forecast", [BureauEvents.REWARD]) if next_delivery else ""
	start_button.accessibility_description = start_button.tooltip_text
	start_button.disabled = not sim.can_start_wave()
	var over := sim.bank.overflow(sim.echo_capacity())
	echo_panel.size_flags_stretch_ratio = 1.0
	build_panel.size_flags_stretch_ratio = 1.0
	var notices: Array[String] = []
	if over > 0:
		notices.append(Loc.t("shop.over", [over]))
	if sim.last_contract_done:
		notices.append(Loc.t("contract.result_success", [sim.last_contract_reward])
				if sim.last_contract_success else Loc.t("contract.result_fail"))
	_warning.text = " · ".join(notices)
	_warning.tooltip_text = _warning.text
	refresh_receipt()
	var replace_with := ""
	var chooser := Callable()
	if _replacing != null:
		replace_with = Loc.weapon_name(_replacing.id())
		chooser = _on_replace_slot
	_footer.text = Loc.t("shop.keys")
	build_panel.refresh(sim, replace_with, chooser, quote_drop, apply_drop, clear_drop_hint)
	echo_panel.refresh(sim, animate_echo and not reduced_effects)
	_rebuild_focus()
	call_deferred("_flush_feedback_deferred", _feedback_epoch, _refresh_generation)


func _build_footer() -> Control:
	var tray := PanelContainer.new()
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 12.0
	clear.content_margin_right = 12.0
	clear.content_margin_top = 2.0
	clear.content_margin_bottom = 2.0
	tray.add_theme_stylebox_override("panel", clear)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tray.add_child(box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_warning = UiTheme.label("", 15, ERROR_ON_DARK)
	_warning.clip_text = true
	_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(_warning)
	receipt_button = Button.new()
	receipt_button.custom_minimum_size = Vector2(0.0, 38.0)
	receipt_button.add_theme_font_size_override("font_size", 14)
	receipt_button.pressed.connect(func() -> void: receipt_requested.emit())
	actions.add_child(receipt_button)
	crew_button = Button.new()
	WorkshopUi.fit_button(crew_button, 15, 34.0)
	crew_button.pressed.connect(_open_crew)
	actions.add_child(crew_button)
	for button: Button in [reroll_button, undo_button]:
		WorkshopUi.fit_button(button, 16, 34.0)
		actions.add_child(button)
	var depart := HBoxContainer.new()
	depart.add_theme_constant_override("separation", 10)
	box.add_child(depart)
	WorkshopUi.fit_button(start_button, 18, 42.0)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depart.add_child(start_button)
	_footer = UiTheme.label(Loc.t("shop.keys"), 14, ON_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.custom_minimum_size = Vector2(0.0, 36.0)
	box.add_child(_footer)
	return tray


func _on_weapon_detail(text: String) -> void:
	if _footer == null:
		return
	_weapon_detail = text.replace("\n", " · ")
	_footer.text = _weapon_detail if text != "" else Loc.t("shop.keys")


func _build_header() -> Control:
	var panel := PanelContainer.new()
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 12.0
	clear.content_margin_right = 12.0
	clear.content_margin_top = 2.0
	clear.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", clear)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	identity.add_child(heading)
	_title = UiTheme.section_label("", 28, UiTheme.PAPER)
	heading.add_child(_title)
	debt_button = Button.new()
	WorkshopUi.fit_button(debt_button, 14, 28.0)
	debt_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	debt_button.pressed.connect(_open_debt_ledger)
	heading.add_child(debt_button)
	confession_button = Button.new()
	WorkshopUi.fit_button(confession_button, 14, 28.0)
	confession_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confession_button.pressed.connect(_open_confession)
	heading.add_child(confession_button)
	_prep_status = UiTheme.label("", 14, ON_DARK)
	_prep_status.clip_text = true
	identity.add_child(_prep_status)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_END
	var paper := UiTheme.paper_panel(UiTheme.PAPER)
	paper.shape = InkStyleBox.Shape.OVAL
	paper.content_margin_left = 22.0
	paper.content_margin_right = 22.0
	paper.content_margin_top = 8.0
	paper.content_margin_bottom = 8.0
	tag.add_theme_stylebox_override("panel", paper)
	_materials = UiTheme.label("", 21, UiTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	tag.add_child(_materials)
	_interest = UiTheme.label("", 13, ON_DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(tag)
	right.add_child(_interest)
	row.add_child(right)
	return panel


func _build_left() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(0.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.15
	column.add_theme_constant_override("separation", 4)
	column.add_child(_build_supplier())
	_offers_scroll = ScrollContainer.new()
	_offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offers_scroll.follow_focus = true
	_offers_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_offers_scroll)
	offers_box = GridContainer.new()
	offers_box.columns = 2
	offers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers_box.add_theme_constant_override("h_separation", 6)
	offers_box.add_theme_constant_override("v_separation", 6)
	_offers_scroll.add_child(offers_box)
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(0.0, 34.0)
	reroll_button.pressed.connect(_on_reroll)
	undo_button = Button.new()
	undo_button.custom_minimum_size = Vector2(0.0, 34.0)
	undo_button.tooltip_text = Loc.t("shop.undo_hint")
	undo_button.pressed.connect(_on_undo)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0.0, 34.0)
	UiTheme.stamp_button(start_button)
	start_button.pressed.connect(_on_start)
	return column


func _build_supplier() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_vendor_art = UiTheme.art_icon(&"shopkeeper", Vector2(42.0, 30.0))
	_vendor_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_vendor_art)
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)

	_vendor_line = UiTheme.label(Loc.t("shop.vendor_idle"), 15, ON_DARK)
	_vendor_line.custom_minimum_size = Vector2(0.0, 0.0)
	_vendor_line.clip_text = true
	_vendor_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_vendor_line)
	return row


func _on_offer(o: Offer, card: OfferCard) -> void:
	if sim == null or not visible:
		return
	if card.consume_drag_click():
		return
	var reason := sim.shop.block_reason(sim, o)
	if reason == &"full" and o.is_weapon():
		if _replacing == o:
			_cancel_replace()
		else:
			_begin_replace(o)
		return
	if reason == &"order_active" and o.is_contract():
		_confirm_order_replace(o)
		return
	if reason != &"":
		card.reject(reduced_effects)
		_flash_block(reason)
		return
	if o.is_contract():
		_confirm_order_purchase(o)
		return
	var index := sim.shop.offers.find(o)
	var result := sim.shop.apply(ShopResult.BUY, sim, o)
	if result.ok:
		if o.is_weapon():
			build_panel.marked_slot = sim.player.weapons.size() - 1
		refresh()
		_focus_card(index)
	else:
		card.reject(reduced_effects)
		_flash_block(result.reason)


func _on_lock_offer(o: Offer) -> void:
	if sim == null or not sim.shop.toggle_lock(sim, o):
		return
	var index := maxi(0, sim.shop.offers.find(o))
	refresh()
	_focus_offer_lock(index)


func _focus_offer_lock(index: int) -> bool:
	if index < 0 or index >= offers_box.get_child_count():
		return false
	var card := offers_box.get_child(index) as OfferCard
	if card == null or card.lock_button == null or card.lock_button.disabled:
		return false
	card.lock_button.grab_focus()
	return true


func is_replacing() -> bool:
	return _replacing != null


func _begin_replace(o: Offer) -> void:
	if sim == null or not visible or o == null or not o.is_weapon() or o.sold \
			or not sim.shop.offers.has(o):
		return
	_replacing = o
	_replacing_index = sim.shop.offers.find(o)
	refresh()
	build_panel.focus_first_slot()


func _cancel_replace() -> void:
	if _replacing == null:
		return
	var at := _replacing_index
	_replacing = null
	_replacing_index = -1
	refresh()
	_focus_card(maxi(0, at))


func _on_replace_slot(index: int) -> void:
	if _replacing == null:
		return
	var offer := _replacing
	var quote := sim.shop.quote(ShopResult.REPLACE, sim, offer, index)
	if not quote.ok:
		_flash_block(quote.reason)
		return
	_workshop_slot = index
	var choices: Array[Dictionary] = [{"text": Loc.t("workshop.confirm_replace", [quote.cost]), "value": index}]
	workshop.show_choices(Loc.t("shop.replace_action"), Loc.t("workshop.replace_preview", [Loc.weapon_name(sim.player.weapons[index].id), Loc.weapon_name(offer.id()), quote.cost]), choices, func(value: Variant) -> void:
		var result := sim.shop.apply(ShopResult.REPLACE, sim, offer, int(value))
		if result.ok:
			_replacing = null
			_replacing_index = -1
			refresh()
			workshop.close()
		else:
			_flash_block(result.reason))


func _on_upgrade_weapon(index: int) -> void:
	if sim == null or not visible:
		return
	var result := sim.shop.apply(ShopResult.UPGRADE, sim, null, index)
	if result.ok:
		refresh()
		if not build_panel.focus_upgrade(index):
			undo_button.grab_focus()
	else:
		_flash_block(result.reason)


func _on_evolve_weapon(index: int) -> void:
	if sim == null or not visible:
		return
	_workshop_origin = &"weapon"
	_workshop_slot = index
	build_panel._select(index)
	var choices: Array[Dictionary] = []
	var blocked := &""
	for target in sim.shop.evolution_choices(sim, index):
		var quote := sim.shop.quote_evolution(sim, index, target)
		blocked = quote.reason
		var final_weapon := Content.weapon(target)
		var weapons := sim.player.weapons.duplicate()
		var levels := sim.player.weapon_levels.duplicate()
		weapons[index] = final_weapon
		levels[index] = WeaponDef.MAX_LEVEL
		var dps := int(round(OfferCard.list_dps(weapons, levels, sim.player.stats)))
		choices.append({"text": "%s · %s · %d · %s" % [Loc.weapon_name(target), Loc.t("role." + String(final_weapon.role)), quote.cost, Loc.t("shop.take_dps", [dps])], "value": target,
			"disabled": not quote.ok, "hint": Loc.weapon_desc(target) + " · " + _drop_reason_text(quote.reason) if not quote.ok else Loc.weapon_desc(target)})
	var weapon := sim.player.weapons[index]
	var body := Loc.t("workshop.evolve_hint") + "\n" + Loc.t("workshop.evolve_tradeoff") + "\n" + Loc.t("shop.level", [sim.player.level_at(index) + 1]) + " / %d · %s %d/%d" % [WeaponDef.MAX_LEVEL + 1, Loc.weapon_family(weapon.family), Combat.family_count(sim.player.weapons, weapon.family), Shop.EVOLVE_FAMILY_COUNT]
	if blocked != &"":
		body += "\n" + _drop_reason_text(blocked)
	workshop.show_choices(Loc.t("workshop.evolve"), body, choices, func(value: Variant) -> void:
		var result := sim.shop.evolve_choice(sim, index, StringName(value))
		if result.ok:
			refresh()
			workshop.close()
		else:
			_flash_block(result.reason))


func _on_sell_weapon(index: int) -> void:
	if sim == null or not visible:
		return
	var result := sim.shop.apply(ShopResult.SELL, sim, null, index)
	if result.ok:
		var next := mini(index, sim.player.weapons.size() - 1)
		_workshop_slot = next
		refresh()
		if not build_panel.focus_upgrade(next):
			undo_button.grab_focus()
	else:
		_flash_block(result.reason)


# Blocked clicks point at the resource that is missing, instead of only reading "can't buy".
func _flash_block(reason: StringName) -> void:
	match reason:
		&"poor":
			_react_vendor(&"poor")
			_footer.text = Loc.t("shop.drop_poor")
			_reject_materials()
		&"full":
			_footer.text = Loc.t("shop.full_reason")
			build_panel.flash_slots(reduced_effects)
		&"maxed":
			_footer.text = Loc.t("shop.maxed")
			build_panel.flash_items(reduced_effects)
		&"last":
			_footer.text = Loc.t("shop.sell_last_reason")
			build_panel.flash_slots(reduced_effects)
		_:
			_footer.text = _drop_reason_text(reason)


func _on_reroll() -> void:
	if sim == null or not visible:
		return
	_replacing = null
	_replacing_index = -1
	var result := sim.shop.apply(ShopResult.REROLL, sim)
	if result.ok:
		refresh()
		if reroll_button.disabled:
			_focus_card(0)
	else:
		_flash_block(result.reason)


func _on_undo() -> void:
	if sim == null:
		return
	_replacing = null
	_replacing_index = -1
	var result := sim.shop.undo(sim)
	if not result.ok:
		_on_history_changed(false)
		return
	refresh()
	if not undo_button.disabled:
		undo_button.grab_focus()
	else:
		_focus_card(0)


func _on_history_changed(can_undo: bool) -> void:
	if undo_button != null:
		undo_button.disabled = not can_undo


func set_reduced_effects(on: bool) -> void:
	reduced_effects = on
	if offers_box != null:
		for child in offers_box.get_children():
			var card := child as OfferCard
			if card != null:
				card.reduced_effects = on
				if on:
					card._release_paper()
	if echo_panel != null:
		echo_panel.set_reduced_effects(on)
	if on and binding_ceremony != null:
		binding_ceremony.skip()
	if on:
		UiTheme.animate_open(self, true)
		reset_feedback()
		if _overlay != null:
			UiTheme.clear(_overlay)


func pending_feedback_count() -> int:
	return _pending_feedback.size()


func flush_feedback() -> void:
	_flush_feedback_deferred(_feedback_epoch, _refresh_generation)


func reset_feedback() -> void:
	_pending_feedback.clear()
	last_feedback.clear()
	_reset_vendor_motion()
	if build_panel != null:
		build_panel.reset_feedback()
	if _material_feedback_tween != null and _material_feedback_tween.is_valid():
		_material_feedback_tween.kill()
	_material_feedback_tween = null
	if _materials != null:
		_materials.scale = Vector2.ONE
		_materials.modulate = Color.WHITE


func _on_weapon_changed(info: WeaponChangeInfo) -> void:
	if info == null or not info.ok:
		return
	var removed := info.before_id != &"" and info.after_id == &""
	var key := StringName("removed_%d" % info.index) if removed \
			else StringName("slot_%d" % info.index)
	_queue_feedback(key, {
		"kind": &"weapon_removed" if removed else &"weapon", "index": info.index,
		"reverse": info.reason == ShopResult.UNDO, "action": info.reason,
		"before_id": info.before_id, "after_id": info.after_id,
	})


func _on_shop_action_resolved(result: ShopResult) -> void:
	if result == null or not result.ok:
		return
	# This is the committed transaction signal, never a pointer-down or drag preview.
	if visible and sim != null and sim == _connected_sim:
		if binding_ceremony.present(result, reduced_effects):
			_update_binding_rect()
	if visible and sim != null and sim == _connected_sim:
		match result.action:
			ShopResult.REROLL: _react_vendor(&"reroll", result)
			ShopResult.UNDO: _react_vendor(&"undo", result)
			ShopResult.SELL: _react_vendor(&"sell", result)
			ShopResult.ECHO_MERGE: _react_vendor(&"merge", result)
			ShopResult.ECHO_DISCARD: _react_vendor(&"discard", result)
			ShopResult.ECHO_REPAIR: _react_vendor(&"repair", result)
			ShopResult.BUY, ShopResult.REPLACE, ShopResult.REPLACE_ORDER, ShopResult.COMBINE, ShopResult.UPGRADE, ShopResult.EVOLVE:
				_react_vendor(&"buy", result)
	var reverse := result.action == ShopResult.UNDO
	if result.before_state != null and result.after_state != null:
		if result.before_state.items != result.after_state.items:
			_queue_feedback(&"items", {
				"kind": &"items", "index": -1, "reverse": reverse,
				"action": result.action,
			})
		if result.before_state.materials != result.after_state.materials:
			_queue_feedback(&"materials", {
				"kind": &"materials", "index": -1, "reverse": reverse,
				"action": result.action,
				"refund": result.action == ShopResult.SELL and result.cost < 0,
			})
	elif result.action == ShopResult.REROLL and result.cost != 0:
		_queue_feedback(&"materials", {
			"kind": &"materials", "index": -1, "reverse": false,
			"action": result.action,
		})


func _react_vendor(kind: StringName, result: ShopResult = null) -> void:
	if not visible or sim == null or _vendor_line == null:
		return
	_reset_vendor_motion()
	last_vendor_reaction = kind
	vendor_feedback_runs += 1
	_vendor_line.text = _vendor_text(kind)
	_vendor_line.add_theme_color_override("font_color", ERROR_ON_DARK if kind == &"poor" else ON_DARK)
	if reduced_effects:
		return
	# Only decorative art and the non-interactive speech react. Hit rectangles stay put.
	_set_vendor_pose(2 if kind == &"poor" else (3 if kind == &"buy" else 1))
	_vendor_art.pivot_offset = _vendor_art.size * 0.5
	_vendor_art.scale = Vector2(0.90, 0.94) if kind == &"poor" else Vector2(1.06, 0.94)
	_vendor_tween = create_tween()
	_vendor_tween.tween_property(_vendor_art, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vendor_tween.tween_interval(0.35)
	_vendor_tween.tween_callback(_set_vendor_pose.bind(0))
	if result != null and result.ok:
		_fly_receipt(result)


func _vendor_text(kind: StringName) -> String:
	match kind:
		&"buy": return Loc.t("shop.vendor_buy")
		&"poor": return Loc.t("shop.vendor_poor")
		&"reroll": return Loc.t("shop.vendor_reroll")
		&"undo": return Loc.t("shop.vendor_undo")
		&"sell": return Loc.t("shop.vendor_sell")
		&"merge": return Loc.t("shop.vendor_merge")
		&"discard": return Loc.t("shop.vendor_discard")
		&"repair": return Loc.t("shop.vendor_repair")
	return Loc.t("shop.vendor_idle")


func _reset_vendor_motion() -> void:
	if _vendor_tween != null and _vendor_tween.is_valid():
		_vendor_tween.kill()
	_vendor_tween = null
	if is_instance_valid(_vendor_art):
		_vendor_art.scale = Vector2.ONE
		_set_vendor_pose(0)
	if is_instance_valid(_vendor_receipt):
		_vendor_receipt.get_parent().remove_child(_vendor_receipt)
		_vendor_receipt.queue_free()
	_vendor_receipt = null


func _set_vendor_pose(index: int) -> void:
	if _vendor_art == null or not (_vendor_art.texture is AtlasTexture):
		return
	var atlas := _vendor_art.texture as AtlasTexture
	atlas.region = PresentationAssets.frame_region(&"shopkeeper", index)


func _fly_receipt(result: ShopResult) -> void:
	if _overlay == null or _vendor_art == null or not is_inside_tree():
		return
	var delta := -result.cost
	if result.before_state != null and result.after_state != null:
		delta = result.after_state.materials - result.before_state.materials
	var reverse := delta > 0
	var from_control: Control = _vendor_art if reverse else _materials
	var to_control: Control = _materials if reverse else _vendor_art
	var object_key: StringName = &""
	if result.action == ShopResult.UNDO and result.before_state != null and result.after_state != null:
		var before := result.before_state
		var after := result.after_state
		if before.echoes != after.echoes:
			object_key = &"recording_cartridge"
			from_control = _vendor_art
			to_control = echo_panel
		elif before.weapons != after.weapons or before.weapon_levels != after.weapon_levels:
			object_key = _changed_weapon_key(before, after)
			var restoring := after.weapons.size() >= before.weapons.size()
			from_control = _vendor_art if restoring else build_panel
			to_control = build_panel if restoring else _vendor_art
		elif before.items != after.items:
			for id: StringName in after.items.keys() + before.items.keys():
				var old_count := int(before.items.get(id, 0))
				var new_count := int(after.items.get(id, 0))
				if old_count != new_count:
					object_key = PresentationAssets.item_key(Content.item(id))
					from_control = _vendor_art if new_count > old_count else build_panel
					to_control = build_panel if new_count > old_count else _vendor_art
					break
		else:
			from_control = _vendor_art if delta > 0 else _materials
			to_control = _materials if delta > 0 else _vendor_art
	if result.action == ShopResult.ECHO_DISCARD or result.action == ShopResult.ECHO_MERGE:
		from_control = echo_panel
	if result.action != ShopResult.UNDO and not reverse and result.offer_id != &"":
		for child in offers_box.get_children():
			var card := child as OfferCard
			if card != null and card.offer != null and card.offer.id() == result.offer_id:
				from_control = card.price_tag
				break
	var convert := _overlay.get_global_transform().affine_inverse()
	var origin := convert * from_control.get_global_rect().get_center()
	var destination := convert * to_control.get_global_rect().get_center()
	var receipt := PanelContainer.new()
	receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.paper_panel(UiTheme.PAPER)
	style.shape = InkStyleBox.Shape.TAG
	style.variant = 4
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	receipt.add_theme_stylebox_override("panel", style)
	if object_key != &"":
		receipt.add_child(UiTheme.art_icon(object_key, Vector2(34.0, 26.0)))
	elif delta != 0:
		var label := UiTheme.label(("+" if delta > 0 else "−") + str(absi(delta)), 19, UiTheme.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		receipt.add_child(label)
	else:
		receipt.add_child(UiTheme.cartridge_icon(Vector2(30.0, 22.0)))
	receipt.position = origin - Vector2(24.0, 16.0)
	receipt.size = Vector2(48.0, 32.0)
	receipt.pivot_offset = receipt.size * 0.5
	_overlay.add_child(receipt)
	receipt.set_meta(&"shop_receipt_source", from_control)
	receipt.set_meta(&"shop_receipt_target", to_control)
	receipt.set_meta(&"shop_receipt_object", object_key)
	_vendor_receipt = receipt
	var travel := receipt.create_tween().set_parallel(true)
	travel.tween_property(receipt, "position", destination - Vector2(24.0, 16.0), 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(receipt, "scale", Vector2(0.25, 0.25), 0.22)
	travel.tween_property(receipt, "modulate:a", 0.0, 0.18).set_delay(0.04)
	travel.chain().tween_callback(receipt.queue_free)


func _changed_weapon_key(before: ShopState, after: ShopState) -> StringName:
	for index in maxi(before.weapons.size(), after.weapons.size()):
		var old_id := before.weapons[index] if index < before.weapons.size() else &""
		var new_id := after.weapons[index] if index < after.weapons.size() else &""
		var old_level := before.weapon_levels[index] if index < before.weapon_levels.size() else -1
		var new_level := after.weapon_levels[index] if index < after.weapon_levels.size() else -1
		if old_id != new_id or old_level != new_level:
			return PresentationAssets.weapon_key(Content.weapon(new_id if new_id != &"" else old_id))
	return &""


func _queue_feedback(key: StringName, data: Dictionary) -> void:
	data["queued_at_msec"] = Time.get_ticks_msec()
	if not _pending_feedback.has(key) and _pending_feedback.size() >= MAX_PENDING_FEEDBACK:
		_pending_feedback.erase(_pending_feedback.keys()[0])
	_pending_feedback[key] = data


func _flush_feedback_deferred(epoch: int, generation: int) -> void:
	if epoch != _feedback_epoch or generation != _refresh_generation:
		return
	if not is_inside_tree() or not visible or sim == null or sim != _connected_sim:
		_pending_feedback.clear()
		return
	var now := Time.get_ticks_msec()
	var pending: Array = _pending_feedback.values()
	_pending_feedback.clear()
	for raw: Variant in pending:
		var data: Dictionary = raw
		if now - int(data.get("queued_at_msec", now)) > FEEDBACK_EXPIRY_MSEC:
			continue
		last_feedback = data.duplicate()
		match data.get("kind", &""):
			&"weapon":
				build_panel.pulse_weapon_slot(int(data.get("index", -1)),
						bool(data.get("reverse", false)), reduced_effects)
			&"weapon_removed":
				build_panel.pulse_removed_weapon(bool(data.get("reverse", false)), reduced_effects)
			&"items":
				build_panel.pulse_items(bool(data.get("reverse", false)), reduced_effects)
			&"materials":
				_pulse_materials(bool(data.get("reverse", false)))


func _pulse_materials(reverse: bool) -> void:
	if _materials == null:
		return
	if _material_feedback_tween != null and _material_feedback_tween.is_valid():
		_material_feedback_tween.kill()
	material_feedback_runs += 1
	if reduced_effects:
		_materials.scale = Vector2.ONE
		_materials.modulate = Color.WHITE
		return
	_materials.pivot_offset = _materials.size * 0.5
	_materials.modulate = Color(0.88, 0.78, 0.92) if reverse else Color(1.0, 0.86, 0.62)
	_materials.scale = Vector2.ONE if reduced_effects else Vector2(0.96, 0.96)
	_material_feedback_tween = create_tween().set_parallel(true)
	_material_feedback_tween.tween_property(_materials, "modulate", Color.WHITE, 0.2)
	if not reduced_effects:
		_material_feedback_tween.tween_property(_materials, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reject_materials() -> void:
	if _material_feedback_tween != null and _material_feedback_tween.is_valid():
		_material_feedback_tween.kill()
	_material_feedback_tween = null
	_materials.modulate = Color.WHITE
	if reduced_effects:
		return
	_materials.modulate = Color(1.0, 0.74, 0.63)
	_material_feedback_tween = create_tween()
	_material_feedback_tween.tween_property(_materials, "modulate", Color.WHITE, 0.2)


func drag_payload_for(o: Offer) -> Variant:
	if sim == null or not visible or sim.phase != Sim.Phase.SHOP:
		return null
	if o == null or not sim.shop.offers.has(o) or o.sold:
		return null
	return {"kind": &"shop_offer", "shop_ui": self, "offer": o}


func resolve_drag_offer(data: Variant) -> Offer:
	if sim == null or not visible or sim.phase != Sim.Phase.SHOP or not (data is Dictionary):
		return null
	var payload: Dictionary = data
	if payload.get("kind", &"") != &"shop_offer" or payload.get("shop_ui") != self:
		return null
	var candidate := payload.get("offer") as Offer
	if candidate == null or candidate.sold or not sim.shop.offers.has(candidate):
		return null
	return candidate


func quote_drop(data: Variant, target_kind: StringName, index: int = -1) -> ShopResult:
	build_panel.clear_drop_highlights()
	var o := resolve_drag_offer(data)
	if o == null:
		var invalid := ShopResult.failure(&"", &"invalid")
		_show_drop_quote(invalid)
		return invalid
	var result: ShopResult
	match target_kind:
		&"weapon_slot":
			if not o.is_weapon() or index < 0 or index >= sim.player.weapons.size():
				result = ShopResult.failure(ShopResult.REPLACE, &"invalid")
			else:
				result = sim.shop.quote(ShopResult.REPLACE, sim, o, index)
		&"empty_weapon":
			if not o.is_weapon() or sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS:
				result = ShopResult.failure(ShopResult.BUY, &"invalid")
			else:
				result = sim.shop.quote(ShopResult.BUY, sim, o)
		&"items":
			if o.item == null:
				result = ShopResult.failure(ShopResult.BUY, &"invalid")
			else:
				result = sim.shop.quote(ShopResult.BUY, sim, o)
		_:
			result = ShopResult.failure(&"", &"invalid")
	_show_drop_quote(result)
	return result


func clear_drop_hint() -> void:
	if _footer != null:
		_footer.text = _weapon_detail if not _weapon_detail.is_empty() else Loc.t("shop.keys")


func _show_drop_quote(result: ShopResult) -> void:
	if _footer == null or result == null:
		return
	if not result.ok:
		_footer.text = _drop_reason_text(result.reason)
		return
	if result.action == ShopResult.REPLACE:
		if result.cost < 0:
			_footer.text = Loc.t("shop.quote_refund", [absi(result.cost)])
		elif result.cost == 0:
			_footer.text = Loc.t("shop.quote_replace_free")
		else:
			_footer.text = Loc.t("shop.quote_replace", [result.cost])
	else:
		_footer.text = Loc.t("shop.quote_buy", [result.cost])


func _drop_reason_text(reason: StringName) -> String:
	if reason in [&"pending_confession", &"history_full"]:
		return Loc.t("reason.pending_confession" if reason == &"pending_confession" else "reason.history_full")
	match reason:
		&"debt", &"duplicate", &"trait", &"level":
			return Loc.t("workshop.reason_" + String(reason))
		&"family":
			return Loc.t("shop.evolve_need", [Shop.EVOLVE_FAMILY_COUNT])
		&"choice", &"branch":
			return Loc.t("workshop.evolve_hint")
		&"order_active":
			return Loc.t("workshop.replace_order")
		&"poor":
			return Loc.t("shop.drop_poor")
		&"full":
			return Loc.t("shop.full")
		&"maxed":
			return Loc.t("shop.maxed")
		&"sold":
			return Loc.t("shop.sold")
		_:
			return Loc.t("shop.drop_invalid")


func apply_drop(data: Variant, target_kind: StringName, index: int = -1) -> ShopResult:
	var quoted := quote_drop(data, target_kind, index)
	if not quoted.ok:
		_flash_drop_failure(target_kind, index, quoted.reason)
		return quoted
	var o := resolve_drag_offer(data)
	# Re-resolve immediately before applying: undo/reroll reconstructs offers and
	# makes any payload from the previous batch stale.
	if o == null:
		return ShopResult.failure(quoted.action, &"invalid")
	var result := sim.shop.apply(quoted.action, sim, o, index)
	if not result.ok:
		_flash_drop_failure(target_kind, index, result.reason)
		return result
	_replacing = null
	_replacing_index = -1
	refresh()
	return result


func _flash_drop_failure(target_kind: StringName, index: int, reason: StringName) -> void:
	_flash_block(reason)
	if target_kind == &"weapon_slot" and index >= 0 and index < build_panel.slot_drop_targets.size():
		build_panel.slot_drop_targets[index].reject(reduced_effects)
	elif target_kind == &"items" and build_panel.items_drop_target != null:
		build_panel.items_drop_target.reject(reduced_effects)
	elif build_panel.empty_drop_target != null:
		build_panel.empty_drop_target.reject(reduced_effects)


func _disconnect_shop() -> void:
	if _connected_shop != null and _connected_shop.shop_history_changed.is_connected(_on_history_changed):
		_connected_shop.shop_history_changed.disconnect(_on_history_changed)
	if _connected_shop != null and _connected_shop.shop_action_resolved.is_connected(_on_shop_action_resolved):
		_connected_shop.shop_action_resolved.disconnect(_on_shop_action_resolved)
	if _connected_sim != null and _connected_sim.weapon_changed.is_connected(_on_weapon_changed):
		_connected_sim.weapon_changed.disconnect(_on_weapon_changed)
	_connected_shop = null
	_connected_sim = null
	_feedback_epoch += 1
	reset_feedback()


func _on_discard(take: EchoTake) -> void:
	if sim == null or not visible:
		return
	var result := sim.shop.discard_echo(sim, take)
	if not result.ok:
		return
	refresh()
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_repair_echo(take: EchoTake) -> void:
	if sim == null or not visible:
		return
	var result := sim.shop.repair_echo(sim, take)
	if not result.ok:
		return
	refresh()
	if not echo_panel.focus_take(take.uid):
		echo_panel.focus_first_discard()


func _on_merge(a: EchoTake, b: EchoTake, merge_trait: StringName = &"skill") -> void:
	if sim == null or not visible:
		return
	var result := sim.shop.merge_echoes(sim, a, b, merge_trait)
	if not result.ok:
		return
	refresh()
	echo_panel.confirm_merge()
	if sim.can_start_wave():
		start_button.grab_focus()
	else:
		echo_panel.focus_first_discard()


func _on_start() -> void:
	if sim == null or not visible:
		return
	if crew != null and crew.visible:
		return
	if confession != null and confession.visible:
		return
	if workshop != null and workshop.visible:
		return
	if sim.can_start_wave():
		_replacing = null
		_replacing_index = -1
		visible = false
		start_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if confession != null and confession.visible:
		return
	if binding_ceremony != null and binding_ceremony.active and event.is_action_pressed(&"ui_cancel"):
		binding_ceremony.skip()
		accept_event()
		return
	if crew != null and crew.visible:
		return
	if workshop != null and workshop.visible:
		return
	if _replacing != null and event.is_action_pressed(&"ui_cancel"):
		_cancel_replace()
		accept_event()
	elif echo_panel != null and echo_panel.is_merging() and event.is_action_pressed(&"ui_cancel"):
		echo_panel.cancel_merge()
		accept_event()


func _focus_card(from: int) -> void:
	var cards := offers_box.get_children()
	for i in cards.size():
		var card := cards[(from + i) % cards.size()] as OfferCard
		if not card.disabled:
			card.grab_focus()
			return
	for b: Button in [start_button, undo_button, reroll_button]:
		if not b.disabled:
			b.grab_focus()
			return


func focus_default() -> void:
	if confession != null and confession.visible:
		confession.focus_default()
		return
	if crew != null and crew.visible:
		crew.focus_default()
		return
	if workshop != null and workshop.visible:
		workshop.focus_default()
		return
	if sim != null and sim.bank.overflow(sim.echo_capacity()) > 0 \
			and echo_panel.focus_first_discard():
		return
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree():
		if not (_last_focus is BaseButton) or not (_last_focus as BaseButton).disabled:
			_last_focus.grab_focus()
			return
	_focus_card(0)


# A small token flies from the arena centre into the newly recorded take's row: the wave
# is visibly "collected" rather than just appearing in a list.
func _fly_take_token() -> void:
	if reduced_effects or not is_inside_tree() or _overlay == null:
		return
	_fly_take_token_after_layout(_feedback_epoch, 2)


func _fly_take_token_after_layout(session_epoch: int, frames: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or reduced_effects \
			or session_epoch != _feedback_epoch or not visible or sim == null:
		return
	if frames > 0:
		var next_frame := _fly_take_token_after_layout.bind(session_epoch, frames - 1)
		if not get_tree().process_frame.is_connected(next_frame):
			get_tree().process_frame.connect(next_frame, CONNECT_ONE_SHOT)
		return
	var arrival := echo_panel.arrival_point()
	if arrival == Vector2.ZERO:
		return
	var target := _overlay.get_global_transform().affine_inverse() * arrival
	var token := UiTheme.cartridge_icon(Vector2(34.0, 27.0))
	token.size = Vector2(34.0, 27.0)
	token.rotation = -0.14
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.position = _arrival_origin() - token.size * 0.5
	_overlay.add_child(token)
	var tween := token.create_tween()
	tween.tween_property(token, "position", target - token.size * 0.5, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(token, "scale", Vector2(0.6, 0.6), 0.55)
	tween.parallel().tween_property(token, "rotation", 0.0, 0.55)
	tween.chain().tween_property(token, "modulate:a", 0.0, 0.12)
	tween.tween_callback(token.queue_free)


func _arrival_origin() -> Vector2:
	# Shop and ArenaView share their canvas, but not necessarily their transforms.
	# Convert the simulated arena centre through the actual scene transforms.
	var ancestor: Node = get_parent()
	while ancestor != null:
		for child in ancestor.get_children():
			if child is ArenaView:
				return _overlay.get_global_transform_with_canvas().affine_inverse() \
						* ((child as ArenaView).get_global_transform_with_canvas() * Sim.ARENA.get_center())
		ancestor = ancestor.get_parent()
	return _overlay.get_global_transform_with_canvas().affine_inverse() \
			* (get_global_transform_with_canvas() * Sim.VIEWPORT.get_center())


func refresh_receipt() -> void:
	if receipt_button == null:
		return
	var receipt := StoryLedger.receipt(sim)
	receipt_button.visible = not receipt.is_empty()
	if receipt.is_empty():
		return
	var title := Loc.t(receipt.name_key)
	var body := Loc.t(receipt.body_key)
	receipt_button.text = Loc.t("story.read_receipt", [title])
	receipt_button.tooltip_text = body
	receipt_button.accessibility_name = title
	receipt_button.accessibility_description = body


func _rebuild_focus() -> void:
	var active: Array = []
	for node in find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled and not workshop.is_ancestor_of(button) and not crew.is_ancestor_of(button) and not confession.is_ancestor_of(button) and not binding_ceremony.is_ancestor_of(button):
			active.append(button)
			var remember := _remember_focus.bind(button)
			if not button.focus_entered.is_connected(remember):
				button.focus_entered.connect(remember)
	UiFocus.cycle(active)
	for i in active.size():
		var current := active[i] as Control
		current.focus_neighbor_left = current.get_path_to(active[(i - 1 + active.size()) % active.size()])
		current.focus_neighbor_right = current.get_path_to(active[(i + 1) % active.size()])


func _on_workshop_closed() -> void:
	if sim == null:
		return
	if _workshop_origin == &"ledger":
		_rebuild_focus()
		debt_button.grab_focus()
		return
	if _workshop_origin == &"order":
		_rebuild_focus()
		_focus_card(maxi(0, _workshop_slot))
		return
	if echo_panel.is_merging():
		echo_panel.cancel_merge()
	if _replacing != null:
		_replacing = null
		_replacing_index = -1
		refresh()
	_rebuild_focus()
	if _workshop_origin == &"echo" and echo_panel.merge_button != null:
		echo_panel.merge_button.grab_focus()
		return
	if not build_panel.focus_upgrade(_workshop_slot) and not build_panel.focus_slot(_workshop_slot):
		_focus_card(0)


func _open_weapon_workshop(index: int) -> void:
	if sim == null or index < 0 or index >= sim.player.weapons.size():
		return
	_workshop_origin = &"weapon"
	_workshop_slot = index
	var weapon := sim.player.weapons[index]
	var level := sim.player.level_at(index)
	var choices: Array[Dictionary] = []
	var refit := sim.shop.quote(ShopResult.UPGRADE, sim, null, index)
	choices.append({"text": Loc.t("shop.upgrade", [refit.cost]), "value": &"refit", "disabled": not refit.ok})
	var combine_available := false
	var combine_price := 0
	for donor in sim.player.weapons.size():
		var combine_quote := sim.shop.combine_quote(sim, index, donor)
		if combine_quote.ok or combine_quote.reason == &"poor":
			combine_available = true
			combine_price = combine_quote.cost
	var combine_text := Loc.t("workshop.combine") + (" · %d" % combine_price if combine_available else "")
	choices.append({"text": combine_text, "value": &"combine", "disabled": not combine_available, "hint": Loc.t("workshop.reason_duplicate")})
	choices.append({"text": Loc.t("workshop.evolve"), "value": &"evolve", "disabled": sim.shop.evolution_choices(sim, index).is_empty()})
	var sell := sim.shop.quote(ShopResult.SELL, sim, null, index)
	choices.append({"text": Loc.t("shop.sell", [absi(sell.cost)]), "value": &"sell", "disabled": not sell.ok, "hint": Loc.t("shop.sell_last_reason") if not sell.ok else Loc.t("shop.sell_hint")})
	choices.append({"text": Loc.t("shop.core"), "value": &"stats"})
	choices.append({"text": Loc.t("shop.items"), "value": &"passives"})
	workshop.show_choices(Loc.weapon_name(weapon.id), build_panel._detail_text_for(weapon, level), choices, _on_weapon_workshop_action.bind(index))


func _on_weapon_workshop_action(value: Variant, index: int) -> void:
	match StringName(value):
		&"refit":
			_on_upgrade_weapon(index)
			_open_weapon_workshop(index)
		&"combine": _open_combine_donors(index)
		&"evolve": _on_evolve_weapon(index)
		&"sell":
			_on_sell_weapon(index)
			workshop.close()
		&"stats": _open_build_stats(index)
		&"passives": _open_build_passives(index)


func _open_build_stats(index: int, page: int = 0) -> void:
	var lines: Array[String] = [Loc.t("shop.take_dps", [int(round(OfferCard.total_dps(sim.player)))])]
	lines.append(Loc.t("shop.echo_value", [sim.echo_capacity(), int(round(sim.echo_power() * 100.0))]))
	for stat in Stats.ORDER:
		lines.append("%s · %s" % [Loc.stat_name(stat), Loc.stat_value(stat, sim.player.stats.get_stat(stat), false)])
	var choices: Array[Dictionary] = [{"text": Loc.t("shop.family"), "value": &"family"}]
	if page > 0:
		choices.append({"text": Loc.t("workshop.previous"), "value": page - 1})
	if (page + 1) * 7 < lines.size():
		choices.append({"text": Loc.t("workshop.next"), "value": page + 1})
	choices.append({"text": Loc.t("workshop.back_build"), "value": &"back"})
	workshop.show_choices(Loc.t("shop.core") + " · " + Loc.t("workshop.page", [page + 1, ceili(float(lines.size()) / 7.0)]), "\n".join(lines.slice(page * 7, (page + 1) * 7)), choices, func(value: Variant) -> void:
		if value is int:
			_open_build_stats(index, int(value))
		elif StringName(value) == &"family":
			_open_family_stats(index)
		else:
			_open_weapon_workshop(index))


func _open_family_stats(index: int, page: int = 0) -> void:
	var lines: Array[String] = []
	var counts: Dictionary = {}
	for weapon in sim.player.weapons:
		counts[weapon.family] = int(counts.get(weapon.family, 0)) + 1
	for family: StringName in counts:
		var count := int(counts[family])
		var text := "%s ×%d" % [Loc.weapon_family(family), count]
		if count >= 2:
			text += " · " + Loc.t("shop.family_damage")
		if count >= 4:
			text += " · " + Loc.t("shop.family_mastery_" + String(family))
		if count >= 6:
			text += " · " + Loc.t("shop.family_master")
		lines.append(text)
	for profile in Combat.combo_profile(sim.player.weapons):
		lines.append(Loc.combo_line(profile))
	var choices: Array[Dictionary] = [{"text": Loc.t("workshop.back_build"), "value": -1}]
	if page > 0:
		choices.append({"text": Loc.t("workshop.previous"), "value": page - 1})
	if (page + 1) * 6 < lines.size():
		choices.append({"text": Loc.t("workshop.next"), "value": page + 1})
	workshop.show_choices(Loc.t("shop.family"), "\n".join(lines.slice(page * 6, (page + 1) * 6)), choices, func(value: Variant) -> void:
		if int(value) < 0:
			_open_weapon_workshop(index)
		else:
			_open_family_stats(index, int(value)))


func _open_build_passives(index: int) -> void:
	var lines: Array[String] = []
	for id: StringName in sim.player.items:
		lines.append("%s ×%d · %s" % [Loc.item_name(id), sim.player.item_count(id), Loc.item_desc(Content.item(id))])
	for set_id: StringName in Content.item_sets():
		var data: Dictionary = Content.item_sets()[set_id]
		var count := 0
		for member: StringName in data.get("members", []):
			count += sim.player.item_count(member)
		if count <= 0:
			continue
		var required := int(data.get("required", 3))
		var text := "%s · %d/%d" % [Loc.t(str(data.get("name", ""))), mini(count, required), required]
		if count >= required:
			text += " · " + Loc.t("set." + String(set_id) + "_bonus")
		lines.append(text)
	if lines.is_empty():
		lines.append(Loc.t("shop.none"))
	# A passive page is intentionally bounded; further pages replace this sheet.
	_open_passive_page(index, lines, 0)


func _open_passive_page(index: int, lines: Array[String], page: int) -> void:
	var choices: Array[Dictionary] = [{"text": Loc.t("workshop.back_build"), "value": -1}]
	if page > 0:
		choices.append({"text": Loc.t("workshop.previous"), "value": page - 1})
	if (page + 1) * 3 < lines.size():
		choices.append({"text": Loc.t("workshop.next"), "value": page + 1})
	workshop.show_choices(Loc.t("shop.items"), "\n".join(lines.slice(page * 3, (page + 1) * 3)), choices, func(value: Variant) -> void:
		if int(value) < 0:
			_open_weapon_workshop(index)
		else:
			_open_passive_page(index, lines, int(value)))


func _open_combine_donors(host: int) -> void:
	var choices: Array[Dictionary] = []
	for donor in sim.player.weapons.size():
		if donor == host:
			continue
		var quote := sim.shop.combine_quote(sim, host, donor)
		choices.append({"text": Loc.t("workshop.donor_weapon", [donor + 1, Loc.weapon_name(sim.player.weapons[donor].id), sim.player.level_at(donor) + 1, quote.cost]), "value": donor, "disabled": not quote.ok, "hint": _drop_reason_text(quote.reason) if not quote.ok else Loc.t("workshop.combine")})
	workshop.show_choices(Loc.t("workshop.combine"), Loc.t("workshop.combine_hint", [host + 1, Loc.weapon_name(sim.player.weapons[host].id)]), choices, func(value: Variant) -> void:
		var donor := int(value)
		var quote := sim.shop.combine_quote(sim, host, donor)
		var confirms: Array[Dictionary] = [{"text": Loc.t("workshop.confirm_combine", [quote.cost]), "value": donor, "disabled": not quote.ok}]
		workshop.show_choices(Loc.t("workshop.combine"), Loc.t("workshop.combine_result", [host + 1, donor + 1, sim.player.level_at(host) + 2]), confirms, func(selected: Variant) -> void:
			var result := sim.shop.combine_weapons(sim, host, int(selected))
			if result.ok:
				_workshop_slot = result.index
				refresh()
				workshop.close()
			else:
				_flash_block(result.reason)))


func _confirm_order_replace(offer: Offer) -> void:
	_workshop_origin = &"order"
	_workshop_slot = sim.shop.offers.find(offer)
	var quote := sim.shop.quote(ShopResult.REPLACE_ORDER, sim, offer)
	var choices: Array[Dictionary] = [{"text": Loc.t("workshop.confirm_order", [quote.cost]), "value": offer, "disabled": not quote.ok}]
	workshop.show_choices(Loc.t("workshop.replace_order"), Loc.t("workshop.order_replace_hint", [Loc.t("order.%s.name" % sim.active_contract.kind), Loc.t("order.%s.name" % offer.contract.kind), quote.cost]) + "\n" + forecast_description(sim), choices, func(value: Variant) -> void:
		var result := sim.shop.apply(ShopResult.REPLACE_ORDER, sim, value as Offer)
		if result.ok:
			refresh()
			workshop.close()
		else:
			_flash_block(result.reason))


func _confirm_order_purchase(offer: Offer) -> void:
	_workshop_origin = &"order"
	_workshop_slot = sim.shop.offers.find(offer)
	var quote := sim.shop.quote(ShopResult.BUY, sim, offer)
	var choices: Array[Dictionary] = [{"text": Loc.t("workshop.confirm_order", [quote.cost]), "value": offer, "disabled": not quote.ok}]
	var body := Loc.t("order.%s.desc" % offer.contract.kind) + "\n" + forecast_description(sim)
	workshop.show_choices(Loc.t("order.%s.name" % offer.contract.kind), body, choices, func(value: Variant) -> void:
		var result := sim.shop.apply(ShopResult.BUY, sim, value as Offer)
		if result.ok:
			refresh()
			workshop.close()
		else:
			_flash_block(result.reason))


static func forecast_description(s: Sim) -> String:
	var forecast := Expedition.forecast(s, s.next_wave_number())
	var facts := Loc.t("shop.forecast", [forecast["stage"], Loc.t(str(forecast["act_key"]))])
	facts += " · " + Loc.t("shop.forecast_fault" if forecast["repair_available"] else "shop.forecast_repaired")
	facts += " · " + Loc.t("shop.forecast_worker" if forecast["worker_available"] else "shop.forecast_no_worker")
	if BureauEvents.forecast(s.next_wave_number(), s.endless):
		facts += "\n" + Loc.t("bureau.delivery.forecast", [BureauEvents.REWARD])
	return facts + "\n" + Loc.t("shop.order_responsibility")


func _open_debt_ledger() -> void:
	if sim == null or not visible or crew.visible:
		return
	_workshop_origin = &"ledger"
	var debt := maxi(0, int(sim.expedition.get("debt", 0)))
	var quote := sim.shop.quote(ShopResult.PAY_DEBT, sim)
	var body := Loc.t("debt.balance", [debt, sim.player.materials, quote.cost, maxi(0, debt - quote.cost)])
	body += "\n" + Loc.t("debt.rule")
	if not quote.ok:
		body += "\n" + Loc.t("debt.clear" if quote.reason == &"debt_clear" else "shop.drop_poor")
	var choices: Array[Dictionary] = [{"text": Loc.t("debt.confirm", [quote.cost]), "value": &"pay", "disabled": not quote.ok}]
	workshop.show_choices(Loc.t("debt.title"), body, choices, func(_value: Variant) -> void:
		var result := sim.shop.apply(ShopResult.PAY_DEBT, sim)
		refresh()
		_open_debt_ledger()
		if not result.ok:
			_flash_block(result.reason))


func _open_crew() -> void:
	if sim == null or not visible or workshop.visible:
		return
	crew.open_crew(sim)


func _on_crew_action(id: StringName) -> void:
	if sim == null or not crew.visible:
		return
	var result := sim.shop.apply(ShopResult.DEPLOY_COMPANION, sim, null, -1, id)
	if result.ok:
		refresh()
		crew.open_crew(sim)
		if not crew.undo_button.disabled:
			crew.undo_button.grab_focus()
	else:
		crew.open_crew(sim)


func _on_crew_undo() -> void:
	if sim == null or not crew.visible:
		return
	sim.shop.undo(sim)
	refresh()
	crew.open_crew(sim)


func _on_crew_closed() -> void:
	_rebuild_focus()
	crew_button.grab_focus()


func _open_merge_hosts() -> void:
	_workshop_origin = &"echo"
	var choices: Array[Dictionary] = []
	for take: EchoTake in sim.bank.takes:
		choices.append({"text": Loc.t("workshop.echo_choice", [take.uid, take.wave, int(ceil(take.condition))]), "value": take})
	workshop.show_choices(Loc.t("workshop.merge_host"), Loc.t("workshop.merge_host_hint"), choices, func(value: Variant) -> void: _open_merge_donors(value as EchoTake))


func _open_merge_donors(host: EchoTake) -> void:
	var choices: Array[Dictionary] = []
	for take: EchoTake in sim.bank.takes:
		if take != host:
			choices.append({"text": Loc.t("workshop.echo_choice", [take.uid, take.wave, int(ceil(take.condition))]), "value": take})
	workshop.show_choices(Loc.t("workshop.merge_donor"), Loc.t("workshop.merge_donor_hint", [host.uid]), choices, func(value: Variant) -> void: _open_merge_traits(host, value as EchoTake))


func _open_merge_traits(host: EchoTake, donor: EchoTake) -> void:
	var choices: Array[Dictionary] = []
	for merge_trait: StringName in [&"skill", &"repair", &"power"]:
		var quote := sim.shop.echo_merge_quote(sim, host, donor, merge_trait)
		choices.append({"text": Loc.t("workshop.trait_" + String(merge_trait)) + " · %d" % quote.cost, "value": merge_trait, "disabled": not quote.ok,
			"hint": Loc.t("workshop.trait_" + String(merge_trait) + "_desc")})
	workshop.show_choices(Loc.t("workshop.merge_trait"), Loc.t("workshop.merge_body_loss", [host.uid, donor.uid]), choices, func(value: Variant) -> void: _open_merge_preview(host, donor, StringName(value)))


func _open_merge_preview(host: EchoTake, donor: EchoTake, merge_trait: StringName) -> void:
	var result := sim.bank.preview_merge(host, donor, merge_trait)
	var quote := sim.shop.echo_merge_quote(sim, host, donor, merge_trait)
	if result == null:
		return
	var text := Loc.t("shop.decision", [
		Loc.t("echo.identity", [host.uid, host.wave]),
		Loc.t("echo.identity", [donor.uid, donor.wave]) + " · " + str(quote.cost),
		Loc.t("workshop.merge_preview", [host.uid, donor.uid, host.duration(), int(ceil(result.condition)), int(round(sim.echo_dps(host))), int(round(sim.echo_dps(result))), quote.cost])])
	text += "\n" + Loc.t("workshop.trait_" + String(merge_trait) + "_desc")
	text += "\n" + Loc.echo_profile(EchoSystem.skill_profile(result, sim))
	var choices: Array[Dictionary] = [{"text": Loc.t("workshop.confirm_merge", [quote.cost]), "value": merge_trait, "disabled": not quote.ok}]
	workshop.show_choices(Loc.t("workshop.merge_result"), text, choices, func(value: Variant) -> void:
		_on_merge(host, donor, StringName(value))
		workshop.close())
	workshop.add_result_visual(_merge_route_visual(host, donor, result))


func _open_echo_detail(take: EchoTake) -> void:
	_workshop_origin = &"echo"
	var text := echo_panel._loadout(take) + "\n" + Loc.echo_profile(EchoSystem.skill_profile(take, sim), true)
	text += "\n" + Loc.t("echo.condition", [int(ceil(take.condition)), ceili(sim.echo_duration() * take.condition / 100.0 / maxf(0.01, sim.wear_rate_mult))])
	var choices: Array[Dictionary] = [{"text": Loc.t("shop.merge"), "value": &"merge", "disabled": sim.bank.takes.size() < 2}]
	workshop.show_choices(Loc.t("echo.identity", [take.uid, take.wave]), text, choices, func(_value: Variant) -> void: _open_merge_donors(take))


func _merge_route_visual(host: EchoTake, donor: EchoTake, result: EchoTake) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	for take: EchoTake in [host, donor, result]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := UiTheme.label(Loc.t("workshop.merge_result") if take == result else Loc.t("echo.identity", [take.uid, take.wave]), 13, UiTheme.DIM)
		label.clip_text = true
		column.add_child(label)
		var preview := PathPreview.new()
		preview.setup(take, false, Vector2(120.0, 60.0))
		preview.consumed = take == donor
		column.add_child(preview)
		row.add_child(column)
	return row


func _remember_focus(control: Control) -> void:
	_last_focus = control


func _open_confession() -> void:
	if sim == null or not visible or workshop.visible or crew.visible:
		return
	confession.open_confession(sim)


func _on_confession_chosen(id: StringName) -> void:
	if sim == null or not visible or not confession.visible:
		return
	var result := sim.shop.apply(ShopResult.CONFESS, sim, null, -1, id)
	refresh()
	confession.open_confession(sim)
	if not result.ok:
		confession.show_error(Loc.t("confession.ui.changed"))


func _on_confession_closed() -> void:
	_rebuild_focus()
	if confession_button != null and confession_button.is_visible_in_tree():
		confession_button.grab_focus()


func set_paused(on: bool) -> void:
	if binding_ceremony != null:
		binding_ceremony.paused = on


func _process(_delta: float) -> void:
	if binding_ceremony != null and binding_ceremony.active:
		_update_binding_rect()


func _update_binding_rect() -> void:
	if echo_panel == null or binding_ceremony == null:
		return
	var rect := echo_panel.get_global_rect()
	var extent := Vector2(minf(270.0, maxf(0.0, rect.size.x - 12.0)), minf(142.0, maxf(0.0, rect.size.y - 12.0)))
	binding_ceremony.size = extent
	binding_ceremony.position = get_global_transform().affine_inverse() * (rect.get_center() - extent * 0.5)
