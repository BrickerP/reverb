class_name OfferCard
extends Button

const HEIGHT := 100.0

var offer: Offer


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


# Expected single-target DPS of everything already equipped.
static func total_dps(pl: PlayerState) -> float:
	var total := 0.0
	for w in pl.weapons:
		total += weapon_dps(w, pl.stats)
	return total


static func weapon_dps(w: WeaponDef, stats: Stats) -> float:
	var pellets := float(maxi(1, w.pellets))
	var crit := 1.0 + maxf(0.0, stats.get_stat(Stats.CRIT_CHANCE))
	var rate := 1.0 / maxf(0.01, w.cooldown * stats.cooldown_mult())
	return w.damage * pellets * stats.damage_mult() * crit * rate


func setup(o: Offer, sim: Sim) -> void:
	offer = o
	var reason := sim.shop.block_reason(sim, o)
	disabled = reason != &""
	modulate.a = 0.4 if reason == &"sold" else (0.65 if disabled else 1.0)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(_title_row(o, reason))
	if o.is_weapon():
		box.add_child(_dps_row(o.weapon, sim))
		box.add_child(_weapon_meta(o.weapon))
	else:
		var desc := UiTheme.label(_description(o), 15, UiTheme.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)


func _title_row(o: Offer, reason: StringName) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var color := o.weapon.color if o.is_weapon() else o.item.color
	var title := Loc.weapon_name(o.id()) if o.is_weapon() else Loc.item_name(o.id())
	row.add_child(UiTheme.label("■", 18, color))
	row.add_child(UiTheme.label(title, 22))
	if not o.is_weapon() and o.item.echo_item:
		row.add_child(UiTheme.label("[%s]" % Loc.t("shop.tag_echo"), 14, UiTheme.ECHO))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_price_label(o, reason))
	return row


func _dps_row(w: WeaponDef, sim: Sim) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var before := total_dps(sim.player)
	var after := before + weapon_dps(w, sim.player.stats)
	row.add_child(UiTheme.label(Loc.t("shop.dps_arrow", [int(round(before)), int(round(after))]), 16, UiTheme.COIN))
	var gain := UiTheme.label("+%d" % int(round(after - before)), 14, UiTheme.COIN)
	gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(gain)
	return row


func _weapon_meta(w: WeaponDef) -> Label:
	var parts := PackedStringArray()
	parts.append(Loc.t("weapon.range", [int(w.reach)]))
	if w.pierce >= 50:
		parts.append(Loc.t("weapon.pierce_all"))
	elif w.pierce > 0:
		parts.append(Loc.t("weapon.pierce", [w.pierce]))
	var line := UiTheme.label("  ·  ".join(parts), 14, UiTheme.DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


func _price_label(o: Offer, reason: StringName) -> Label:
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	match reason:
		&"sold":
			return UiTheme.label(Loc.t("shop.sold"), 16, UiTheme.DIM, right)
		&"full":
			return UiTheme.label(Loc.t("shop.full"), 15, UiTheme.WARN, right)
		&"maxed":
			return UiTheme.label(Loc.t("shop.maxed"), 15, UiTheme.WARN, right)
	var color := UiTheme.WARN if reason == &"poor" else UiTheme.COIN
	return UiTheme.label(str(o.price), 20, color, right)


func _description(o: Offer) -> String:
	return Loc.weapon_line(o.weapon) if o.is_weapon() else Loc.item_desc(o.item)
