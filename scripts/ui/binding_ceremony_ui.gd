class_name BindingCeremonyUi
extends Control

# A receipt of an already committed transaction, never a second apply path.
const DURATION := 0.65
const TRAIT_KEYS := {&"skill": "binding.skill", &"repair": "binding.repair", &"power": "binding.power"}
var active := false
var elapsed := 0.0
var paused := false
var skip_button: Button
var _caption: Label
var _detail: Label
var _before: Array[int] = []
var _after: Array[int] = []
var _reverse := false
var _reduced := false
var _frame := 0
var play_count := 0
var merge_trait: StringName = &""
var value_profile: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	skip_button = Button.new()
	skip_button.focus_mode = Control.FOCUS_NONE
	WorkshopUi.fit_button(skip_button, 12, 23.0)
	skip_button.text = Loc.t("binding.skip")
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	_caption = UiTheme.label("", 13, UiTheme.INK)
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_detail = UiTheme.label("", 12, UiTheme.DIM)
	_detail.clip_text = true
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail)
	visible = false


func present(result: ShopResult, reduced: bool = false) -> bool:
	if result == null or not result.ok or result.before_state == null or result.after_state == null:
		return false
	if result.action not in [ShopResult.ECHO_MERGE, ShopResult.UNDO]:
		return false
	var removed := _difference(result.before_state.echoes, result.after_state.echoes)
	var added := _difference(result.after_state.echoes, result.before_state.echoes)
	var reverse := result.action == ShopResult.UNDO
	var valid_shape := (removed.size() == 1 and added.size() == 2) if reverse else (removed.size() == 2 and added.size() == 1)
	if not valid_shape:
		return false
	var merged: Dictionary = removed[0] if reverse else added[0]
	if not bool(merged.get("merged", false)):
		return false
	_before.clear()
	_after.clear()
	for row: Dictionary in removed:
		_before.append(int(row["uid"]))
	for row: Dictionary in added:
		_after.append(int(row["uid"]))
	merge_trait = StringName(merged.get("merge_trait", &""))
	value_profile = {"merged_condition": float(merged.get("condition", 0.0)),
		"levels": (merged.get("levels", []) as Array).duplicate(),
		"skill": StringName(merged.get("inherited_skill", &"")), "restored_conditions": [], "restored_levels": []}
	if reverse:
		for row: Dictionary in added:
			value_profile["restored_conditions"].append(float(row.get("condition", 0.0)))
			value_profile["restored_levels"].append((row.get("levels", []) as Array).duplicate())
	_reverse = reverse
	_reduced = reduced
	elapsed = 0.0
	_frame = (7 if reverse else 3) if reduced else (4 if reverse else 0)
	play_count += 1
	_caption.text = Loc.t("binding.undo", [_before[0], _after[0], _after[1]]) if reverse \
			else Loc.t("binding.merge", [_before[0], _before[1], _after[0]])
	_caption.tooltip_text = _caption.text
	_caption.accessibility_description = _caption.text
	if reverse:
		_detail.text = Loc.t("binding.result_returned", [value_profile["restored_conditions"][0], value_profile["restored_conditions"][1]])
	elif merge_trait == &"skill":
		_detail.text = Loc.t("binding.result_skill", [Loc.t(str(Loc.SKILL_NAMES.get(value_profile["skill"], "binding.skill")))])
	elif merge_trait == &"repair":
		_detail.text = Loc.t("binding.result_repair", [value_profile["merged_condition"]])
	else:
		var grades := PackedStringArray()
		for level: int in value_profile["levels"]:
			grades.append(str(level + 1))
		_detail.text = Loc.t("binding.result_power", ["/".join(grades), value_profile["merged_condition"]])
	var meaning := Loc.t("binding.returned") if reverse else Loc.t(str(TRAIT_KEYS.get(merge_trait, "binding.skill")))
	_detail.tooltip_text = meaning + " · " + _detail.text
	_detail.accessibility_description = _detail.tooltip_text
	skip_button.text = Loc.t("binding.skip")
	active = true
	visible = true
	queue_redraw()
	return true


static func _difference(rows: Array[Dictionary], against: Array[Dictionary]) -> Array[Dictionary]:
	var ids: Array[int] = []
	for row: Dictionary in against:
		ids.append(int(row["uid"]))
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:
		if not ids.has(int(row["uid"])):
			result.append(row)
	return result


func body_count() -> int:
	return _after.size() if _reduced or elapsed >= DURATION * 0.75 else _before.size()


func step(delta: float) -> void:
	if not active or paused or delta <= 0.0 or not is_finite(delta):
		return
	elapsed += delta
	if elapsed >= DURATION:
		skip()
		return
	if not _reduced:
		_frame = (4 if _reverse else 0) + mini(3, floori(elapsed / DURATION * 4.0))
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func skip() -> void:
	active = false
	visible = false
	queue_redraw()


func reset() -> void:
	skip()
	_before.clear()
	_after.clear()
	elapsed = 0.0
	paused = false
	play_count = 0
	merge_trait = &""
	value_profile.clear()


func _draw() -> void:
	if not active:
		return
	UiTheme.paper_panel(UiTheme.CARD).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var top := 26.0
	var illustration := Rect2(Vector2(6, top), Vector2(size.x - 12.0, maxf(0.0, size.y - top - 39.0)))
	BureauArt.draw_binding(self, _frame, illustration)
	_draw_trait(illustration)
	skip_button.position = Vector2(maxf(4.0, size.x - 62.0), 3.0)
	skip_button.size = Vector2(58.0, 23.0)
	_caption.position = Vector2(7.0, size.y - 36.0)
	_caption.size = Vector2(size.x - 14.0, 17.0)
	_detail.position = Vector2(7.0, size.y - 19.0)
	_detail.size = Vector2(size.x - 14.0, 16.0)


func effect_profile() -> Dictionary:
	return {"trait": merge_trait, "values": value_profile.duplicate(true), "reverse": _reverse,
		"progress": 1.0 if _reduced else clampf(elapsed / DURATION, 0.0, 1.0)}


func _draw_trait(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var progress := 1.0 if _reduced else clampf(elapsed / DURATION, 0.0, 1.0)
	var motion := 1.0 - progress if _reverse else progress
	var ink := UiTheme.INK
	var accent := UiTheme.ACCENT
	var center := rect.get_center()
	match merge_trait:
		&"skill":
			# A moving impression transfers the actual inherited retirement mark.
			var left := Vector2(rect.position.x + rect.size.x * 0.22, center.y)
			var right := Vector2(rect.end.x - rect.size.x * 0.22, center.y)
			draw_line(left, right, Color(ink, 0.65), 1.5, true)
			var mark := left.lerp(right, motion)
			draw_circle(mark, 11, UiTheme.PAPER, true, -1, true)
			draw_arc(mark, 11, 0.0, TAU, 18, accent, 2.5, true)
			var skill := StringName(value_profile.get("skill", &""))
			match skill:
				&"pin":
					draw_line(mark + Vector2(-6, -4), mark + Vector2(6, -4), ink, 2, true)
					draw_line(mark + Vector2(6, -4), mark + Vector2(6, 5), ink, 2, true)
				&"cut":
					draw_line(mark + Vector2(-6, 6), mark + Vector2(6, -6), ink, 2, true)
				&"ink": draw_circle(mark, 5, ink, true, -1, true)
				&"return":
					draw_polyline(PackedVector2Array([mark + Vector2(5, -6), mark + Vector2(-4, 0), mark + Vector2(5, 6)]), ink, 2, true)
				&"arc":
					draw_polyline(PackedVector2Array([mark + Vector2(3, -7), mark + Vector2(-3, 0), mark + Vector2(4, 0), mark + Vector2(-2, 7)]), ink, 2, true)
				_: draw_rect(Rect2(mark - Vector2(5, 4), Vector2(10, 8)), ink, false, 2)
		&"repair":
			# Paper patches close the seam; the bar is the real resulting condition.
			for index in 3:
				var y := rect.position.y + rect.size.y * (0.28 + float(index) * 0.22)
				var patch := Rect2(Vector2(center.x - 14, y - 4 - (1.0 - motion) * 12.0), Vector2(28, 8))
				draw_rect(patch, UiTheme.PAPER)
				draw_rect(patch, accent, false, 1.5)
				draw_line(patch.position + Vector2(4, 1), patch.end - Vector2(4, 1), Color(ink, 0.65), 1, true)
			_draw_result_condition(rect, progress)
		&"power":
			# Two clamp jaws converge. Grade pips describe the actual merged build.
			var gap := lerpf(rect.size.x * 0.31, 20.0, motion)
			for side: float in [-1.0, 1.0]:
				var x := center.x + side * gap
				draw_polyline(PackedVector2Array([Vector2(x - side * 7, rect.position.y + 4), Vector2(x, rect.position.y + 4), Vector2(x, rect.end.y - 8), Vector2(x - side * 7, rect.end.y - 8)]), ink, 3.0, true)
			if _reverse and progress >= 0.75:
				for index in value_profile.get("restored_levels", []).size():
					var half := Rect2(rect.position + Vector2(float(index) * rect.size.x * 0.5, 0), Vector2(rect.size.x * 0.5, rect.size.y))
					_draw_grades(half, value_profile["restored_levels"][index])
			else:
				_draw_grades(rect, value_profile.get("levels", []))
			_draw_result_condition(rect, progress)


func _draw_grades(rect: Rect2, levels: Array) -> void:
	var start := rect.get_center().x - float(levels.size()) * 7.0
	for index in mini(Content.MAX_WEAPON_SLOTS, levels.size()):
		for grade in mini(4, int(levels[index]) + 1):
			draw_rect(Rect2(Vector2(start + float(index) * 14.0, rect.end.y - 8 - float(grade) * 4), Vector2(10, 2)), UiTheme.ACCENT)


func _draw_result_condition(rect: Rect2, progress: float) -> void:
	if _reverse and progress >= 0.75:
		for index in value_profile.get("restored_conditions", []).size():
			var half := Rect2(rect.position + Vector2(float(index) * rect.size.x * 0.5, 0), Vector2(rect.size.x * 0.5, rect.size.y))
			_draw_condition(half, float(value_profile["restored_conditions"][index]))
	else:
		_draw_condition(rect, float(value_profile.get("merged_condition", 0.0)))


func _draw_condition(rect: Rect2, condition: float) -> void:
	var bar := Rect2(Vector2(rect.position.x + 10, rect.end.y - 3), Vector2(rect.size.x - 20, 3))
	draw_rect(bar, Color(UiTheme.INK, 0.25))
	bar.size.x *= clampf(condition / 100.0, 0.0, 1.0)
	draw_rect(bar, UiTheme.ACCENT)
