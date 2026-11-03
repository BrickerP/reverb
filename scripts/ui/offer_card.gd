class_name OfferCard
extends Button

signal replacement_requested(offer: Offer)
signal lock_toggled(offer: Offer)

const HEIGHT := 124.0

var offer: Offer
var _sim: Sim
var blocked_reason: StringName = &""
var swap_button: Button
var lock_button: Button
var price_tag: PanelContainer
var _art: TextureRect
var _drag_payload := Callable()
var _clear_drag_hint := Callable()
var _suppress_next_pressed := false
var reduced_effects := false
var _press_tween: Tween
var _order_context := ""


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_down.connect(_press_paper)
	button_up.connect(_release_paper)


# Expected single-target DPS of everything already equipped.
static func total_dps(pl: PlayerState) -> float:
	return list_dps(pl.weapons, pl.weapon_levels, pl.stats)


static func list_dps(weapons: Array[WeaponDef], levels: Array[int], stats: Stats) -> float:
	var total := 0.0
	for i in weapons.size():
		var w := weapons[i]
		var level := levels[i] if i >= 0 and i < levels.size() else 0
		total += weapon_dps(w, stats, level, Combat.family_damage_mult(weapons, w.family),
				Combat.family_cooldown_mult(weapons, w.family))
	return total


static func dps_with_added(pl: PlayerState, added: WeaponDef, level: int = 0) -> float:
	var weapons := pl.weapons.duplicate()
	var levels := pl.weapon_levels.duplicate()
	weapons.append(added)
	levels.append(level)
	return list_dps(weapons, levels, pl.stats)


static func weapon_dps(w: WeaponDef, stats: Stats, level: int = 0,
		family_damage: float = 1.0, family_cooldown: float = 1.0) -> float:
	var crit := 1.0 + maxf(0.0, stats.get_stat(Stats.CRIT_CHANCE))
	return w.level_dps(level) * stats.damage_mult() * crit * family_damage / maxf(0.01, stats.cooldown_mult() * family_cooldown)


func setup(o: Offer, sim: Sim, selected: bool = false,
		payload_provider: Callable = Callable(), clear_drag_hint: Callable = Callable()) -> void:
	offer = o
	_sim = sim
	_order_context = ShopUi.forecast_description(sim) if o.is_contract() else ""
	swap_button = null
	lock_button = null
	_drag_payload = payload_provider
	_clear_drag_hint = clear_drag_hint
	var reason := sim.shop.block_reason(sim, o)
	blocked_reason = reason
	var title := _offer_name(o)
	accessibility_name = title
	var state := Loc.t("shop.quote_buy", [o.price])
	match reason:
		&"sold": state = Loc.t("shop.sold")
		&"full": state = Loc.t("shop.full_reason")
		&"maxed": state = Loc.t("shop.maxed")
		&"poor": state = Loc.t("shop.drop_poor")
		&"debt": state = Loc.t("workshop.reason_debt")
		&"order_active": state = Loc.t("workshop.replace_order")
	accessibility_description = "%s · %s" % [_description(o), state]
	tooltip_text = state if reason != &"" else ""
	# Sold cards are inert. Every other blocked card stays pressable so it can explain
	# the constraint by flashing the resource it needs.
	disabled = reason == &"sold"
	# Preserve contrast for unaffordable/full cards: the stamped state explains why.
	modulate.a = 0.64 if reason == &"sold" else 1.0
	var normal := UiTheme.paper_panel(UiTheme.PAPER if selected else UiTheme.CARD)
	normal.shape = InkStyleBox.Shape.PAPER
	normal.variant = absi(String(o.id()).hash()) % 7
	if selected or o.locked:
		normal.border_color = UiTheme.ACCENT
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", UiTheme.paper_panel(UiTheme.PAPER.lightened(0.05)))
	add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.SURFACE, UiTheme.EDGE, 3, 2))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.name = "MerchandiseRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	if o.is_weapon():
		_art = UiTheme.weapon_icon(o.weapon, Vector2(88, 80))
	elif o.is_contract():
		_art = UiTheme.art_icon(&"recording_cartridge", Vector2(88, 80))
	else:
		_art = UiTheme.item_icon(o.item, Vector2(88, 80))
	_art.name = "MerchandiseArt"
	row.add_child(_art)
	var info := VBoxContainer.new()
	info.name = "MerchandiseInfo"
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	info.add_child(_title_row(o))
	price_tag = PanelContainer.new()
	price_tag.name = "PriceAction"
	price_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_tag.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var can_swap := sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS or reason in [&"poor", &"full"]
	price_tag.add_child(_actions_row(o, reason, can_swap))
	info.add_child(price_tag)
	if reason == &"poor" and swap_button == null:
		var shortage := UiTheme.label(Loc.t("shop.need_materials", [maxi(0, o.price - sim.player.materials)]), 12, UiTheme.WARN)
		shortage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(shortage)
	row.minimum_size_changed.connect(_fit_paper.bind(row))
	row.resized.connect(_fit_paper.bind(row))
	_fit_paper.call_deferred(row)
	_sim = null


func _fit_paper(box: Container) -> void:
	if not is_instance_valid(box) or is_queued_for_deletion() or box.size.x <= 0.0:
		return
	# These cards are Buttons with child artwork, so the stock grid cannot infer
	# wrapped content height. Keep every visible action inside its paper.
	custom_minimum_size.y = maxf(HEIGHT, box.get_combined_minimum_size().y + 8.0)


func _get_drag_data(at_position: Vector2) -> Variant:
	if disabled or offer == null or not _drag_payload.is_valid():
		return null
	if _nested_action_at(at_position):
		return null
	var data: Variant = _drag_payload.call(offer)
	if data == null:
		return null
	drag_started()
	var preview := _drag_preview()
	set_drag_preview(preview)
	return data


func _nested_action_at(local_position: Vector2) -> bool:
	var global_position := get_global_transform_with_canvas() * local_position
	for action: Button in [swap_button, lock_button]:
		if action != null and action.is_visible_in_tree() \
				and action.get_global_rect().has_point(global_position):
			return true
	return false


func drag_started() -> void:
	_suppress_next_pressed = true


func consume_drag_click() -> bool:
	if not _suppress_next_pressed:
		return false
	_suppress_next_pressed = false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _suppress_next_pressed:
		# BaseButton may emit pressed on release after a drag. Keep the guard through
		# that release, then clear it for the next deliberate click.
		call_deferred("_clear_drag_guard_deferred")
		if _clear_drag_hint.is_valid():
			_clear_drag_hint.call()


func _clear_drag_guard_deferred() -> void:
	_suppress_next_pressed = false


func _drag_preview() -> Control:
	# Viewport positions the preview root at the pointer. Offset a child instead so
	# the physical card never covers the socket and its quote while hovering.
	var preview_root := Control.new()
	preview_root.theme = UiTheme.build()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.custom_minimum_size = Vector2.ONE
	preview_root.set_meta(&"shop_drag_preview", true)
	var preview := PanelContainer.new()
	# Drag previews are reparented below the viewport and cannot rely on the shop's
	# inherited Theme for CJK text or button styling.
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = Vector2(190.0, 58.0)
	preview.position = Vector2(24.0, -70.0)
	preview.add_theme_stylebox_override("panel",
			UiTheme.paper_panel(UiTheme.CARD))
	preview_root.add_child(preview)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	preview.add_child(row)
	if offer.is_weapon():
		row.add_child(UiTheme.weapon_icon(offer.weapon, Vector2(52.0, 36.0)))
		row.add_child(UiTheme.label(Loc.weapon_name(offer.id()), 16))
	else:
		row.add_child(UiTheme.art_icon(&"recording_cartridge", Vector2(36.0, 30.0)) if offer.is_contract() else UiTheme.item_icon(offer.item, Vector2(42.0, 42.0)))
		row.add_child(UiTheme.label(_offer_name(offer), 16))
	return preview_root


func reject(reduced: bool = false) -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_reset_visual_pose()
	if reduced or price_tag == null:
		return
	price_tag.pivot_offset = price_tag.size * 0.5
	price_tag.scale = Vector2(0.88, 0.90)
	price_tag.modulate = Color(1.0, 0.74, 0.63)
	_press_tween = create_tween().set_parallel(true)
	_press_tween.tween_property(price_tag, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(price_tag, "modulate", Color.WHITE, 0.2)


func _title_row(o: Offer) -> Control:
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_theme_constant_override("separation", 1)
	var name_label := UiTheme.label(_offer_name(o), 16)
	name_label.name = "MerchandiseName"
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(name_label)
	if o.is_weapon():
		var grade := UiTheme.label(Loc.t("shop.level", [o.weapon_level + 1]), 12, UiTheme.DIM)
		grade.name = "GradeMark"
		identity.add_child(grade)
	if not o.is_weapon() and not o.is_contract() and o.item.echo_item:
		identity.add_child(UiTheme.label(Loc.t("shop.tag_echo"), 12, UiTheme.ECHO))
	return identity


func _actions_row(o: Offer, reason: StringName, can_swap: bool) -> Control:
	var swap := o.is_weapon() and reason != &"sold" and can_swap
	var action_text := Loc.t("shop.review_materials" if o.is_contract() else "shop.buy_materials", [o.price])
	if reason == &"sold":
		action_text = Loc.t("shop.sold")
	elif swap or (o.is_contract() and reason == &"order_active"):
		action_text = Loc.t("shop.replace_materials", [o.price])
	if swap:
		swap_button = Button.new()
		swap_button.name = "PurchaseAction"
		swap_button.text = action_text
		swap_button.tooltip_text = Loc.t("shop.replace", [Loc.weapon_name(o.id())])
		swap_button.accessibility_description = swap_button.tooltip_text
		swap_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		swap_button.custom_minimum_size = Vector2(0, 28)
		swap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swap_button.mouse_filter = Control.MOUSE_FILTER_STOP
		swap_button.pressed.connect(_on_swap_pressed)
		WorkshopUi.fit_button(swap_button, 13, 28)
		return swap_button
	var action := UiTheme.label(action_text, 13, UiTheme.WARN if reason == &"poor" else UiTheme.ACCENT)
	action.name = "PurchaseAction"
	action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return action


func _press_paper() -> void:
	if disabled or reduced_effects or _art == null:
		return
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_reset_visual_pose()
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2(1.04, 0.96)


func _release_paper() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	scale = Vector2.ONE
	if reduced_effects:
		_reset_visual_pose()
		return
	_press_tween = create_tween().set_parallel(true)
	if _art != null:
		_press_tween.tween_property(_art, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if price_tag != null:
		_press_tween.tween_property(price_tag, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_visual_pose() -> void:
	# Preserve the interaction rectangle; only the merchandise and loose tag can move.
	scale = Vector2.ONE
	if _art != null:
		_art.scale = Vector2.ONE
	if price_tag != null:
		price_tag.scale = Vector2.ONE
		price_tag.modulate = Color.WHITE


func _on_swap_pressed() -> void:
	if offer == null or offer.sold or swap_button == null or swap_button.disabled:
		return
	# A nested focusable action must never bubble into the parent purchase button.
	_suppress_next_pressed = true
	replacement_requested.emit(offer)
	call_deferred("_clear_drag_guard_deferred")


func _on_lock_pressed() -> void:
	if offer == null or offer.sold or lock_button == null:
		return
	# Same nested-action guard as replace: locking is not a purchase.
	_suppress_next_pressed = true
	lock_toggled.emit(offer)
	call_deferred("_clear_drag_guard_deferred")


func _next_encounter(o: Offer) -> String:
	if _sim == null or o.contract == null:
		return ""
	var forecast := Expedition.forecast(_sim, _sim.next_wave_number())
	match o.contract.kind:
		AnomalyContract.REPAIR:
			return Loc.t("order.repair.next_yes" if forecast["repair_available"] else "order.repair.next_no")
		AnomalyContract.RESCUE:
			return Loc.t("order.rescue.next_yes" if forecast["worker_available"] else "order.rescue.next_no")
		AnomalyContract.SALVAGE:
			return Loc.t("order.salvage.next")
		AnomalyContract.AUDIT:
			return Loc.t("order.audit.next")
		AnomalyContract.RECRUIT:
			return Loc.t("order.recruit.next")
		_:
			return Loc.t("order.credit.next")


func _description(o: Offer) -> String:
	if o.is_contract():
		var payoff := Loc.t("order.credit_fact") if o.contract.kind == AnomalyContract.CREDIT \
				else Loc.t("order.payoff", [o.contract.deposit, o.contract.reward])
		if o.contract.kind == AnomalyContract.REPAIR:
			payoff += " · " + Loc.t("order.repair.stay")
		var body := Loc.t("order.%s.desc" % o.contract.kind)
		var next := _next_encounter(o)
		if next != "":
			body += "\n" + next
		if not _order_context.is_empty():
			body += "\n" + _order_context
		return payoff + "\n" + body
	return Loc.weapon_desc(o.weapon.id) + "\n" + Loc.weapon_line(o.weapon, o.weapon_level) if o.is_weapon() else Loc.item_desc(o.item, _sim)


func _offer_name(o: Offer) -> String:
	if o.is_contract():
		return Loc.t("order.%s.name" % o.contract.kind)
	return Loc.weapon_name(o.id()) if o.is_weapon() else Loc.item_name(o.id())
