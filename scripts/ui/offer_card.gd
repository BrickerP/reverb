class_name OfferCard
extends Button

signal replacement_requested(offer: Offer)
signal lock_toggled(offer: Offer)

const HEIGHT := 100.0

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
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	var slots_full := sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS
	var can_swap := slots_full or reason == &"poor" or reason == &"full"
	clip_contents = true
	box.add_child(_title_row(o, reason, selected, slots_full))
	if o.is_weapon():
		box.add_child(_dps_row(o.weapon, sim, o.weapon_level))
	else:
		var desc := UiTheme.label(_visible_blurb(o).replace("\n", " · "), 14, UiTheme.DIM)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.clip_text = true
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		desc.tooltip_text = _description(o)
		box.add_child(desc)
	if reason != &"" and reason != &"sold":
		var why := UiTheme.label(_blocked_text(reason), 13, UiTheme.WARN)
		why.clip_text = true
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(why)
	box.add_child(_actions_row(o, reason, can_swap))
	_sim = null


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


func _title_row(o: Offer, reason: StringName, selected: bool, _can_swap: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	if o.is_weapon():
		_art = UiTheme.weapon_icon(o.weapon, Vector2(34.0, 30.0))
		row.add_child(_art)
	elif o.is_contract():
		_art = UiTheme.art_icon(&"recording_cartridge", Vector2(34.0, 30.0))
		row.add_child(_art)
	else:
		_art = UiTheme.item_icon(o.item, Vector2(34.0, 30.0))
		row.add_child(_art)
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	var title := _offer_name(o)
	var name_label := UiTheme.label(title, 15)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(name_label)
	row.add_child(identity)
	if o.is_weapon():
		var tags := UiTheme.label(Loc.t("shop.level", [o.weapon_level + 1]) + " · " + Loc.weapon_family(o.weapon.family) + " · " + Loc.rarity_name(o.weapon.rarity), 11, UiTheme.DIM)
		tags.clip_text = true
		tags.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		identity.add_child(tags)
	elif o.is_contract():
		var order_tag := UiTheme.label(Loc.t("workshop.order"), 11, UiTheme.ECHO)
		order_tag.clip_text = true
		identity.add_child(order_tag)
	elif o.item.echo_item:
		identity.add_child(UiTheme.label(Loc.t("shop.tag_echo"), 12, UiTheme.ECHO))
	price_tag = PanelContainer.new()
	price_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_tag.custom_minimum_size = Vector2(42.0, 32.0)
	price_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tag := UiTheme.paper_panel(UiTheme.SURFACE if reason == &"sold" else UiTheme.PAPER)
	tag.shape = InkStyleBox.Shape.OVAL
	tag.variant = 2
	tag.content_margin_left = 8.0
	tag.content_margin_right = 8.0
	tag.content_margin_top = 2.0
	tag.content_margin_bottom = 2.0
	price_tag.add_theme_stylebox_override("panel", tag)
	price_tag.add_child(_price_label(o, reason, selected))
	row.add_child(price_tag)
	return row


func _actions_row(o: Offer, reason: StringName, can_swap: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	if o.is_weapon():
		var meta := UiTheme.label(Loc.t("workshop.buy", [o.price]), 13, UiTheme.COIN)
		meta.add_theme_font_size_override("font_size", 12)
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(meta)
	else:
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		row.add_child(UiTheme.label(Loc.t("shop.replace_action") if reason == &"order_active" else Loc.t("workshop.buy", [o.price]), 13, UiTheme.COIN))
	if o.is_weapon() and reason != &"sold" and can_swap:
		swap_button = Button.new()
		swap_button.text = Loc.t("shop.replace_action")
		swap_button.tooltip_text = Loc.t("shop.replace", [Loc.weapon_name(o.id())])
		swap_button.accessibility_description = swap_button.tooltip_text
		swap_button.custom_minimum_size = Vector2(62.0, 28.0)
		swap_button.add_theme_font_size_override("font_size", 12)
		swap_button.mouse_filter = Control.MOUSE_FILTER_STOP
		swap_button.pressed.connect(_on_swap_pressed)
		WorkshopUi.fit_button(swap_button, 12, 24.0)
		row.add_child(swap_button)
	return row


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


func _rarity_color(rarity: StringName) -> Color:
	match rarity:
		&"uncommon":
			return UiTheme.COIN
		&"rare":
			return UiTheme.ECHO
		&"evolved":
			return UiTheme.ACCENT
		_:
			return UiTheme.DIM


func _dps_row(w: WeaponDef, sim: Sim, level: int = 0) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	if w.support_kind != &"":
		var support := UiTheme.label(Loc.support_short(w, level), 13, UiTheme.ECHO)
		support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		support.clip_text = true
		support.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(support)
		return row
	var per_shot := Loc.number(w.damage * w.level_mult(level))
	var slot := Loc.t("shop.keep_swap") if sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS else Loc.t("shop.keep_slot")
	var line := UiTheme.label(Loc.t("shop.offer_shot", [per_shot, w.cooldown, slot]), 14, UiTheme.COIN)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(line)
	return row


func _weapon_meta(w: WeaponDef) -> Label:
	var parts := PackedStringArray()
	parts.append(Loc.t("weapon.range", [int(w.reach)]))
	if w.pierce >= 50:
		parts.append(Loc.t("weapon.pierce_all"))
	elif w.pierce > 0:
		parts.append(Loc.t("weapon.pierce", [w.pierce]))
	if w.explosion_radius > 0.0:
		parts.append(Loc.t("weapon.explosion", [int(w.explosion_radius)]))
	if w.homing_turn > 0.0:
		parts.append(Loc.t("weapon.homing"))
	var line := UiTheme.label("  ·  ".join(parts), 14, UiTheme.DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


func _price_label(o: Offer, reason: StringName, selected: bool) -> Label:
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	if selected and reason == &"full":
		return UiTheme.label("%d  %s" % [o.price, Loc.t("shop.replace_action")], 16, UiTheme.ACCENT, right)
	match reason:
		&"sold":
			return UiTheme.label(Loc.t("shop.sold"), 16, UiTheme.DIM, right)
		&"full":
			return UiTheme.label(str(o.price), 20, UiTheme.COIN, right)
		&"maxed":
			return UiTheme.label(Loc.t("shop.maxed"), 15, UiTheme.WARN, right)
	var color := UiTheme.WARN if reason == &"poor" else UiTheme.COIN
	return UiTheme.label(str(o.price), 20, color, right)


func _visible_blurb(o: Offer) -> String:
	if o.is_contract():
		return Loc.t("order.%s.objective" % o.contract.kind)
	return _description(o)


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


func _blocked_text(reason: StringName) -> String:
	match reason:
		&"full": return Loc.t("shop.full_reason")
		&"maxed": return Loc.t("shop.maxed")
		&"poor": return Loc.t("shop.drop_poor")
		&"debt": return Loc.t("workshop.reason_debt")
		&"order_active": return Loc.t("workshop.replace_order")
		_: return Loc.t("shop.drop_poor")


static func decision(o: Offer, sim: Sim) -> String:
	if o == null or sim == null:
		return ""
	if o.is_contract():
		var got := Loc.t("order.%s.name" % o.contract.kind) + " · " + Loc.t("order.%s.objective" % o.contract.kind)
		if o.contract.kind == AnomalyContract.CREDIT:
			return Loc.t("shop.decision", [Loc.t("shop.keep_run"), Loc.t("order.credit_fact"), got])
		return Loc.t("shop.decision", [Loc.t("shop.keep_run"), Loc.t("order.payoff", [o.contract.deposit, o.contract.reward]), got])
	if o.is_weapon():
		var keep := Loc.t("shop.keep_slot") if sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS else Loc.t("shop.keep_swap")
		return Loc.t("shop.decision", [keep, str(o.price), Loc.weapon_name(o.id()) + " · " + Loc.weapon_line(o.weapon, o.weapon_level)])
	return Loc.t("shop.decision", [Loc.t("shop.keep_run"), str(o.price), Loc.item_desc(o.item, sim)])


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
