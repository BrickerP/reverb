class_name ExitOutcomePortrait
extends Control

# Frozen, read-only illustrations of the actual exit quote or committed result.
# No timers, copied simulation, reward application or invented people live here.
const EXTENT := Vector2(136.0, 56.0)
var result: Dictionary = {}
var _figures: Array[Dictionary] = []


func _init() -> void:
	custom_minimum_size = EXTENT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func setup(profile: Dictionary) -> void:
	result = profile.duplicate(true)
	_figures.clear()
	var kind: StringName = result.get("kind", &"")
	var entries: Array = result.get("people", []) if kind == &"collective" else result.get("copies", [])
	if kind == &"takeover":
		entries = [{"uid": result.get("staff_uid", 0), "character": result.get("character", &"looper"), "condition": result.get("staff_condition", 100.0)}]
	for entry: Dictionary in entries.slice(0, 4):
		var row := entry.duplicate(true)
		if row.get("type", &"") != &"worker":
			var key := PresentationAssets.support_key(StringName("recruited_" + String(row["kind"]))) if row.get("type", &"") == &"companion" \
				else PresentationAssets.character_key(row.get("character", result.get("character", &"looper")))
			row["texture"] = PresentationAssets.texture(key)
			row["region"] = PresentationAssets.idle_region(key)
		_figures.append(row)
	visible = not result.is_empty()
	accessibility_description = describe(result)
	queue_redraw()


func clear() -> void:
	result.clear()
	_figures.clear()
	visible = false
	queue_redraw()


static func profile(sim: Sim, choice: StringName = &"", committed: bool = false) -> Dictionary:
	if sim == null:
		return {}
	var outcome: Dictionary = sim.expedition.get("ending_outcome", {})
	var quote: Dictionary = {}
	if committed:
		if not bool(outcome.get("applied", false)):
			return {}
		choice = StringName(outcome.get("kind", &""))
	else:
		for option: Dictionary in Expedition.exit_options(sim):
			if option["id"] == choice:
				quote = option
		if quote.is_empty():
			return {}
	var world: Dictionary = sim.expedition.get("world", {})
	var result_value := {"kind": choice, "committed": committed, "available": true if committed else bool(quote["available"]),
		"cost": int(outcome.get("cost", 0)) if committed else int(quote["cost"]),
		"debt": int(sim.expedition.get("debt", 0)), "copies": [], "people": [],
		"repaired_copies": int(outcome.get("repaired_copies", 0)) if committed else 0,
		"survivors": int(outcome.get("survivors", 0)) if committed else 0,
		"staff_uid": int(outcome.get("staff_uid", 0)) if committed else 0,
		"staff_condition": 100.0, "character": sim.character_id, "full_hp": sim.player.max_hp()}
	for take: EchoTake in sim.bank.takes:
		if choice == &"released":
			result_value["copies"].append({"uid": take.uid, "condition": take.condition if committed else 100.0, "before": take.condition})
			if not committed and take.condition < 100.0:
				result_value["repaired_copies"] += 1
	if choice == &"collective":
		for worker: Dictionary in world.get("workers", []):
			if worker["state"] == (&"exited" if committed else &"safe"):
				result_value["people"].append({"type": &"worker", "id": worker["id"], "hp": worker["hp"]})
		for row: Dictionary in world.get("roster", []):
			if row["state"] in ([&"exited"] if committed else [&"active", &"bench"]) and float(row["hp"]) > 0.0 and float(row["life"]) > 0.0:
				var hp := float(row["hp"])
				if not committed and row["state"] == &"active":
					hp = 0.0
					for unit: Dictionary in sim.support_units:
						if unit["uid"] == row["uid"] and float(unit["life"]) > 0.0:
							hp = float(unit["hp"])
				if hp > 0.0:
					result_value["people"].append({"type": &"companion", "kind": row["kind"], "hp": hp})
		if not committed:
			result_value["survivors"] = result_value["people"].size()
	if choice == &"takeover":
		if not committed and not sim.bank.takes.is_empty():
			result_value["staff_uid"] = sim.bank.takes.back().uid
		var staff := sim.bank.find_uid(result_value["staff_uid"])
		if staff != null:
			result_value["staff_condition"] = staff.condition
	return result_value


static func describe(value: Dictionary) -> String:
	if value.is_empty():
		return ""
	match value["kind"]:
		&"released":
			return Loc.t("exit.result.released", [value["cost"], value["repaired_copies"], value["debt"]])
		&"collective":
			return Loc.t("exit.result.collective", [value["survivors"], value["full_hp"], value["debt"]])
		&"takeover":
			return Loc.t("exit.result.staff", [value["staff_uid"], value["debt"]]) if int(value["staff_uid"]) > 0 else Loc.t("exit.result.self", [value["debt"]])
	return ""


func _draw() -> void:
	if result.is_empty():
		return
	var kind: StringName = result["kind"]
	var count := _figures.size()
	if count == 0:
		# An empty registry stays visibly empty; a silhouette would invent a person.
		draw_rect(Rect2(38.0, 10.0, 56.0, 34.0), Color(UiTheme.INK, 0.24), false, 1.5)
		draw_line(Vector2(52.0, 27.0), Vector2(80.0, 27.0), UiTheme.DIM, 2.0)
		return
	var stride := minf(34.0, (EXTENT.x - 12.0) / float(count))
	var start := (EXTENT.x - stride * float(count)) * 0.5
	for index in count:
		var row: Dictionary = _figures[index]
		var at := Vector2(start + stride * (index + 0.5), 37.0)
		if row.get("type", &"") == &"worker":
			draw_set_transform(at, 0.0, Vector2.ONE * 0.62)
			ExpeditionInk.draw_worker(self, Vector2.ZERO, true)
			draw_set_transform(Vector2.ZERO)
		else:
			var region: Rect2 = row["region"]
			var texture := row["texture"] as Texture2D
			if texture != null and region.has_area():
				var fit := minf(31.0 / region.size.x, 43.0 / region.size.y)
				var extent := region.size * fit
				draw_texture_rect_region(texture, Rect2(at + Vector2(-extent.x * 0.5, -extent.y + 5.0), extent), region)
		if kind == &"released":
			var meter := Rect2(at + Vector2(-13.0, 7.0), Vector2(26.0, 4.0))
			draw_rect(meter, Color(UiTheme.INK, 0.22))
			draw_rect(Rect2(meter.position, Vector2(meter.size.x * clampf(float(row["condition"]) / 100.0, 0.0, 1.0), meter.size.y)), UiTheme.ACCENT)
		elif kind == &"takeover":
			draw_line(at + Vector2(-12.0, 8.0), at + Vector2(12.0, 8.0), UiTheme.INK, 4.0)
			draw_line(at + Vector2(-9.0, 10.0), at + Vector2(-9.0, 17.0), UiTheme.INK, 2.0)
			draw_line(at + Vector2(9.0, 10.0), at + Vector2(9.0, 17.0), UiTheme.INK, 2.0)
