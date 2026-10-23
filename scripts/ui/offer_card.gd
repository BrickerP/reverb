class_name OfferCard
extends Button

const HEIGHT := 100.0

var offer: Offer
var blocked_reason: StringName = &""


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


# Expected single-target DPS of everything already equipped.
static func total_dps(pl: PlayerState) -> float:
	var total := 0.0
	for i in pl.weapons.size():
		total += weapon_dps(pl.weapons[i], pl.stats, pl.level_at(i))
	return total


static func weapon_dps(w: WeaponDef, stats: Stats, level: int = 0) -> float:
	var pellets := float(maxi(1, w.pellets))
	var crit := 1.0 + maxf(0.0, stats.get_stat(Stats.CRIT_CHANCE))
	var rate := 1.0 / maxf(0.01, w.cooldown * stats.cooldown_mult())
	return w.damage * w.level_mult(level) * pellets * stats.damage_mult() * crit * rate


func setup(o: Offer, sim: Sim, selected: bool = false) -> void:
	offer = o
	var reason := sim.shop.block_reason(sim, o)
	blocked_reason = reason
	# Sold cards are inert. Every other blocked card stays pressable so it can explain
	# the constraint by flashing the resource it needs.
	disabled = reason == &"sold"
	modulate.a = 0.4 if reason == &"sold" else (1.0 if selected else (0.72 if reason != &"" else 1.0))
	if selected:
		var style := UiTheme.box(Color(0.06, 0.09, 0.18), UiTheme.ACCENT, 2, 6)
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("hover", style)
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
	box.add_child(_title_row(o, reason, selected))
	if o.is_weapon():
		box.add_child(_dps_row(o.weapon, sim))
		box.add_child(_weapon_meta(o.weapon))
	else:
		var desc := UiTheme.label(_description(o), 15, UiTheme.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)


func reject() -> void:
	UiTheme.flash(self)
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)


func _title_row(o: Offer, reason: StringName, selected: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var color := o.weapon.color if o.is_weapon() else o.item.color
	var title := Loc.weapon_name(o.id()) if o.is_weapon() else Loc.item_name(o.id())
	row.add_child(UiTheme.label("■", 18, color))
	row.add_child(UiTheme.label(title, 22))
	if o.is_weapon():
		row.add_child(UiTheme.label("[%s]" % Loc.weapon_family(o.weapon.family), 12, UiTheme.DIM))
	if not o.is_weapon() and o.item.echo_item:
		row.add_child(UiTheme.label("[%s]" % Loc.t("shop.tag_echo"), 14, UiTheme.ECHO))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_price_label(o, reason, selected))
	return row


func _dps_row(w: WeaponDef, sim: Sim) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var before := total_dps(sim.player)
	var added := weapon_dps(w, sim.player.stats)
	if sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS:
		# With full slots this is a replacement, not an addition: show what the new
		# weapon brings, without promising a total that depends on the discarded slot.
		row.add_child(UiTheme.label(Loc.t("shop.dps_add", [int(round(before)), int(round(added))]), 16, UiTheme.COIN))
		return row
	var after := before + added
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


func _price_label(o: Offer, reason: StringName, selected: bool) -> Label:
	var right := HORIZONTAL_ALIGNMENT_RIGHT
	if selected and reason == &"full":
		return UiTheme.label("%d  %s" % [o.price, Loc.t("shop.replace_action")], 16, UiTheme.ACCENT, right)
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
