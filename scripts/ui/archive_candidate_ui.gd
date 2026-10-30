class_name ArchiveCandidateUi
extends HBoxContainer

var route: ArchiveRoutePreview
var details: Label
var preview: Dictionary = {}
var detail_button: Button
var _source: EchoTake
var _page := 0
var _pages: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 12)
	route = ArchiveRoutePreview.new()
	route.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(route)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	add_child(info)
	details = UiTheme.label("", 15)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(details)
	detail_button = Button.new()
	detail_button.flat = true
	detail_button.visible = false
	detail_button.custom_minimum_size.y = 24.0
	detail_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail_button.add_theme_font_size_override("font_size", 13)
	detail_button.pressed.connect(func() -> void:
		_page = posmod(_page + 1, _pages.size())
		_show_page())
	info.add_child(detail_button)


func setup(take: EchoTake, entry: Dictionary, compact: bool = false) -> void:
	if _source != take:
		_page = 0
	_source = take
	preview = entry
	route.setup(take, Vector2(150.0, 90.0) if compact else Vector2(190.0, 110.0))
	details.add_theme_font_size_override("font_size", 13 if compact else 15)
	_pages.clear()
	_pages.append(summary(take, entry))
	var extra := PackedStringArray()
	for profile: Dictionary in entry.get("utility", []):
		extra.append(utility_summary(profile))
	for action: Dictionary in entry.get("work", []):
		extra.append(Loc.t("archive.work_detail", [Loc.t("archive.work." + String(action.kind)), float(action.time),
			Loc.t("archive.machine", [int(String(action.target_id).trim_prefix("machine_")) + 1]) if action.target_id != &"" else Loc.weapon_name(action.weapon_id)]))
	for i in range(0, extra.size(), 2):
		var text := Loc.t("archive.entry_detail")
		for j in range(i, mini(i + 2, extra.size())):
			text += "\n" + extra[j]
		_pages.append(text)
	_page = mini(_page, _pages.size() - 1)
	detail_button.visible = _pages.size() > 1
	_show_page()


func _show_page() -> void:
	details.text = _pages[_page]
	detail_button.text = Loc.t("archive.detail_page", [_page + 1, _pages.size()])
	accessibility_description = details.text


static func summary(take: EchoTake, entry: Dictionary) -> String:
	if entry.is_empty():
		return Loc.t("archive.unavailable")
	var original := PackedStringArray()
	for i in take.weapons.size():
		original.append(Loc.weapon_name(take.weapons[i].id) + Loc.t("archive.grade", [take.level_at(i) + 1]))
	var entering := PackedStringArray()
	for i in entry.weapons.size():
		var grade := Loc.t("archive.grade", [int(entry.levels[i]) + 1]) if entry.live_loadout else Loc.t("archive.grade_change", [int(entry.levels[i]) + 1, take.level_at(i) + 1])
		entering.append(Loc.weapon_name(entry.weapons[i].id) + grade)
	var text := Loc.t("archive.recorded_short", [take.wave])
	if entry.live_loadout:
		text += " · " + ", ".join(original)
	text += "\n" + Loc.t("archive.entry_gear", [", ".join(entering)])
	if entry.live_loadout:
		text += " · " + Loc.t("archive.live_loadout")
	text += "\n" + Loc.t("archive.entry_values", [float(entry.damage), roundi(entry.condition)])
	var skill: Dictionary = entry.skill
	if bool(skill.get("valid", false)):
		text += " · " + Loc.t("archive.entry_skill", [Loc.t(skill.name_key), float(skill.damage)])
	text += "\n" + Loc.t("archive.entry_route", [float(entry.route_distance), entry.work.size()])
	if not entry.utility.is_empty():
		text += " · " + Loc.t("archive.utility_count", [entry.utility.size()])
	return text


static func utility_summary(profile: Dictionary) -> String:
	var utility := Loc.t("archive.utility_hp", [Loc.weapon_name(profile.weapon_id), float(profile.max_hp), float(profile.life)])
	if float(profile.heal_hp) > 0.0:
		utility += Loc.t("archive.utility_repair", [float(profile.heal_hp), float(profile.repair_condition), int(profile.charges), float(profile.interval)])
	elif float(profile.shield) > 0.0:
		utility += Loc.t("archive.utility_produce", [float(profile.shield), float(profile.energy), int(profile.charges), float(profile.interval)])
	elif float(profile.damage) > 0.0:
		utility += Loc.t("archive.utility_damage", [float(profile.damage), float(profile.interval)])
	return utility
