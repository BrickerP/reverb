extends SceneTree
# Actual-window presentation coverage gallery. It consumes the production asset
# catalog and ArenaPainter paths; labels exist only in this developer fixture.
# Usage: godot --path . --fixed-fps 60 --disable-vsync \
#   --script res://tools/presentation_gallery.gd

const WIDTH := 1280.0
const HEIGHT := 720.0
const DEADLINE_FRAMES := 900
const PAGES: Array[StringName] = [&"weapons", &"items", &"enemies", &"characters"]

var _canvas: GalleryCanvas
var _frames := 0
var _failed := false
var _shots_dir := ""
var _summary: Dictionary = {}


class GalleryCanvas extends Control:
	const GALLERY_SIZE := Vector2(1280.0, 720.0)

	var page: StringName = &"weapons"
	var weapon_ids: Array[StringName] = []
	var item_ids: Array[StringName] = []
	var enemy_ids: Array[StringName] = []
	var character_ids: Array[StringName] = []
	var enemy_sim: Sim
	var character_sims: Dictionary = {}


	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


	func show_page(next: StringName) -> void:
		page = next
		queue_redraw()


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, GALLERY_SIZE), Color(0.025, 0.03, 0.055))
		_draw_header()
		match page:
			&"weapons":
				_draw_weapons()
			&"items":
				_draw_items()
			&"enemies":
				_draw_enemies()
			&"characters":
				_draw_characters()


	func _draw_header() -> void:
		var title := "PRESENTATION COVERAGE · %s" % String(page).to_upper()
		draw_string(UiTheme.font(), Vector2(28.0, 42.0), title,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, UiTheme.INK)
		draw_string(UiTheme.font(), Vector2(28.0, 64.0),
				"Production textures and runtime draw paths · IDs are developer-fixture labels",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, UiTheme.DIM)


	func _draw_weapons() -> void:
		var cell_size := Vector2(300.0, 200.0)
		for i in weapon_ids.size():
			var id := weapon_ids[i]
			var cell := _grid_cell(i, 4, cell_size, Vector2(25.0, 80.0))
			_panel(cell, Content.weapon(id).color)
			_label(id, cell.position + Vector2(12.0, 25.0), 17, UiTheme.INK)
			var key := PresentationAssets.weapon_key(Content.weapon(id))
			_draw_key(key, Rect2(cell.position + Vector2(14.0, 42.0), Vector2(194.0, 130.0)))
			var world_size := ArenaPainter._weapon_size(key)
			var world_rect := Rect2(cell.position + Vector2(244.0, 105.0) - world_size * 0.5,
					world_size)
			_draw_key(key, world_rect)
			_label("world", cell.position + Vector2(228.0, 160.0), 11, UiTheme.DIM)
			_label(String(key), cell.position + Vector2(12.0, 190.0), 10, UiTheme.DIM)


	func _draw_items() -> void:
		var cell_size := Vector2(300.0, 200.0)
		for i in item_ids.size():
			var id := item_ids[i]
			var item := Content.item(id)
			var cell := _grid_cell(i, 4, cell_size, Vector2(25.0, 80.0))
			_panel(cell, item.color)
			_label(id, cell.position + Vector2(12.0, 25.0), 17, UiTheme.INK)
			var key := PresentationAssets.item_key(item)
			_draw_key(key, Rect2(cell.position + Vector2(45.0, 45.0), Vector2(122.0, 122.0)))
			_draw_key(key, Rect2(cell.position + Vector2(232.0, 92.0), Vector2(36.0, 36.0)))
			_label("UI 36", cell.position + Vector2(224.0, 151.0), 11, UiTheme.DIM)
			_label(String(key), cell.position + Vector2(12.0, 190.0), 10, UiTheme.DIM)


	func _draw_enemies() -> void:
		var cell_size := Vector2(300.0, 290.0)
		for i in enemy_ids.size():
			var id := enemy_ids[i]
			var def := Content.enemy(id)
			var cell := _grid_cell(i, 4, cell_size, Vector2(25.0, 80.0))
			_panel(cell, def.color)
			_label(id, cell.position + Vector2(12.0, 25.0), 17, UiTheme.INK)
			var key := PresentationAssets.enemy_key(def)
			_draw_key(key, Rect2(cell.position + Vector2(25.0, 45.0), Vector2(148.0, 160.0)))
			_label("runtime", cell.position + Vector2(205.0, 234.0), 11, UiTheme.DIM)
			_label(String(key), cell.position + Vector2(12.0, 277.0), 10, UiTheme.DIM)
		ArenaPainter.enemies(self, enemy_sim)


	func _draw_characters() -> void:
		var directions: Array[Vector2] = [
			Vector2(1.0, 0.72).normalized(), Vector2(-1.0, 0.72).normalized(),
			Vector2(1.0, -0.72).normalized(), Vector2(-1.0, -0.72).normalized(),
		]
		var direction_names := ["front · right", "front · left", "back · right", "back · left"]
		var cell_size := Vector2(300.0, 145.0)
		for row in character_ids.size():
			var id := character_ids[row]
			var sim := character_sims[id] as Sim
			for column in directions.size():
				var cell := Rect2(Vector2(25.0 + float(column) * 307.0,
						80.0 + float(row) * 157.0), cell_size)
				_panel(cell, Content.character(id).color)
				_label("%s · %s" % [id, direction_names[column]],
						cell.position + Vector2(10.0, 22.0), 13, UiTheme.INK)
				sim.player.pos = cell.position + Vector2(150.0, 104.0)
				sim.player.facing = directions[column]
				ArenaPainter.player(self, sim, id)


	func _grid_cell(index: int, columns: int, size: Vector2, origin: Vector2) -> Rect2:
		var column := index % columns
		var row := floori(float(index) / float(columns))
		return Rect2(origin + Vector2(float(column) * 307.0, float(row) * (size.y + 8.0)), size)


	func _panel(rect: Rect2, accent: Color) -> void:
		draw_rect(rect, Color(0.055, 0.065, 0.085, 0.96))
		draw_rect(rect, Color(accent, 0.48), false, 1.5)


	func _label(text: String, position: Vector2, size: int, color: Color) -> void:
		draw_string(UiTheme.font(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


	func _draw_key(key: StringName, bounds: Rect2) -> void:
		var texture := PresentationAssets.texture(key)
		var source := PresentationAssets.region(key)
		if texture == null or not source.has_area():
			return
		var fitted := ArenaPainter._contained_size(source.size, bounds.size)
		var destination := Rect2(bounds.get_center() - fitted * 0.5, fitted)
		draw_texture_rect_region(texture, destination, source)


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://presentation_gallery_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://presentation_gallery_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://presentation_gallery_settings.json")
	_clear_fixture_files()
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > DEADLINE_FRAMES and not _failed:
		_fail("deadline exceeded before all gallery pages were captured")
	return false


func _run() -> void:
	await process_frame
	if not _validate_catalog():
		return
	_canvas = GalleryCanvas.new()
	_canvas.weapon_ids = _sorted_dictionary_ids(Content.weapons())
	_canvas.item_ids = _sorted_dictionary_ids(Content.items())
	_canvas.enemy_ids = _sorted_enemy_ids()
	_canvas.character_ids = _sorted_dictionary_ids(Content.characters())
	_canvas.enemy_sim = _build_enemy_sim(_canvas.enemy_ids)
	_canvas.character_sims = _build_character_sims(_canvas.character_ids)
	root.add_child(_canvas)
	await _wait_frames(3)
	if not _require(_canvas.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"gallery uses the production linear mipmap texture filter"):
		return
	if not _require(root.get_visible_rect().size == Vector2(WIDTH, HEIGHT),
			"gallery viewport is exactly 1280x720"):
		return
	for page in PAGES:
		_canvas.show_page(page)
		await _wait_frames(3)
		_save(page)
	_write_summary()
	await _wait_frames(8)
	print("presentation gallery: %s" % JSON.stringify(_summary["counts"]))
	print("presentation gallery: OK")
	quit()


func _validate_catalog() -> bool:
	var weapon_ids := _sorted_dictionary_ids(Content.weapons())
	var item_ids := _sorted_dictionary_ids(Content.items())
	var enemy_ids := _sorted_enemy_ids()
	var character_ids := _sorted_dictionary_ids(Content.characters())
	if not _require(weapon_ids.size() == 12, "gallery covers all 12 weapons"):
		return false
	if not _require(item_ids.size() == 11, "gallery covers all 11 items"):
		return false
	if not _require(enemy_ids.size() == 7, "gallery covers all 7 enemies"):
		return false
	if not _require(character_ids.size() == 4, "gallery covers all 4 characters"):
		return false
	var weapon_rows: Array[Dictionary] = []
	var item_rows: Array[Dictionary] = []
	var enemy_rows: Array[Dictionary] = []
	var character_rows: Array[Dictionary] = []
	var weapon_keys: Dictionary = {}
	var item_keys: Dictionary = {}
	var enemy_keys: Dictionary = {}
	var character_keys: Dictionary = {}
	for id in weapon_ids:
		var key := PresentationAssets.weapon_key(Content.weapon(id))
		if not _validate_key(id, key, weapon_keys):
			return false
		weapon_rows.append(_row(id, key))
	for id in item_ids:
		var key := PresentationAssets.item_key(Content.item(id))
		if not _validate_key(id, key, item_keys):
			return false
		item_rows.append(_row(id, key))
	for id in enemy_ids:
		var key := PresentationAssets.enemy_key(Content.enemy(id))
		if not _validate_key(id, key, enemy_keys):
			return false
		enemy_rows.append(_row(id, key))
	for id in character_ids:
		var front := PresentationAssets.character_key(id, false)
		var back := PresentationAssets.character_key(id, true)
		if not _validate_key(StringName("%s_front" % id), front, character_keys):
			return false
		if not _validate_key(StringName("%s_back" % id), back, character_keys):
			return false
		character_rows.append({"id": String(id), "front": String(front), "back": String(back)})
	_summary = {
		"viewport": [int(WIDTH), int(HEIGHT)],
		"texture_filter": "linear_with_mipmaps",
		"counts": {"weapons": weapon_ids.size(), "items": item_ids.size(),
			"enemies": enemy_ids.size(), "characters": character_ids.size(),
			"character_directions": character_ids.size() * 4},
		"weapons": weapon_rows, "items": item_rows, "enemies": enemy_rows,
		"characters": character_rows,
		"production_paths": ["PresentationAssets", "ArenaPainter.player", "ArenaPainter.enemies"],
		"visual_review_flags": [
			"longbow tall world mount size and rotation",
			"silencer tall body and foot anchor",
			"Paradox source art and boss rings remain inside its cell",
			"Mirror and Conductor foot anchors and starting-weapon overlap in four directions",
		],
	}
	var longbow_size: Vector2 = ArenaPainter._weapon_size(
			PresentationAssets.weapon_key(Content.weapon(&"longbow")))
	if not _require(longbow_size.y > longbow_size.x, "longbow keeps a tall world mount"):
		return false
	var silencer_region := PresentationAssets.region(
			PresentationAssets.enemy_key(Content.enemy(&"silencer")))
	if not _require(silencer_region.size.y > silencer_region.size.x,
			"silencer keeps a tall source silhouette"):
		return false
	return true


func _validate_key(id: StringName, key: StringName, seen: Dictionary) -> bool:
	if not _require(not key.is_empty(), "%s has an explicit presentation key" % id):
		return false
	if not _require(not seen.has(key), "%s has a distinct presentation key" % id):
		return false
	seen[key] = id
	var texture := PresentationAssets.texture(key)
	if not _require(texture != null, "%s presentation texture loads" % id):
		return false
	return _require(PresentationAssets.region(key).has_area(),
			"%s presentation region has visible area" % id)


func _row(id: StringName, key: StringName) -> Dictionary:
	var texture := PresentationAssets.texture(key)
	var region := PresentationAssets.region(key)
	return {"id": String(id), "key": String(key),
		"texture_size": [texture.get_width(), texture.get_height()],
		"region": [region.position.x, region.position.y, region.size.x, region.size.y]}


func _sorted_dictionary_ids(source: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in source.keys():
		result.append(StringName(value))
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return result


func _sorted_enemy_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def: EnemyDef in Content.enemies():
		result.append(def.id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return result


func _build_enemy_sim(ids: Array[StringName]) -> Sim:
	var sim := Sim.new(20261023)
	sim.wave_time = 0.7
	sim.player.pos = Vector2(640.0, 360.0)
	sim.enemies.clear()
	for i in ids.size():
		var def := Content.enemy(ids[i])
		var cell := _canvas_cell(i, Vector2(300.0, 290.0))
		var enemy := EnemyState.new()
		enemy.uid = 9000 + i
		enemy.def = def
		enemy.pos = cell.position + Vector2(228.0, 154.0)
		enemy.max_hp = def.hp
		enemy.hp = def.hp * (0.64 if def.radius >= 15.0 else 1.0)
		enemy.speed = def.speed
		enemy.damage = def.damage
		enemy.radius = def.radius
		sim.enemies.append(enemy)
	return sim


func _build_character_sims(ids: Array[StringName]) -> Dictionary:
	var result := {}
	for id in ids:
		var sim := Sim.new(20261023)
		Content.character(id).apply(sim)
		sim.phase = Sim.Phase.WAVE
		sim.wave_time = 0.7
		sim.enemies.clear()
		result[id] = sim
	return result


func _canvas_cell(index: int, size: Vector2) -> Rect2:
	var column := index % 4
	var row := floori(float(index) / 4.0)
	return Rect2(Vector2(25.0 + float(column) * 307.0,
			80.0 + float(row) * (size.y + 8.0)), size)


func _save(page: StringName) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := _shots_dir.path_join("gallery_%s.png" % page)
	var error := image.save_png(path)
	if error != OK:
		_fail("failed to save gallery page %s: %s" % [page, error])
	else:
		print("wrote shots/gallery_%s.png" % page)


func _write_summary() -> void:
	var path := _shots_dir.path_join("gallery_summary.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open gallery summary for writing")
		return
	file.store_string(JSON.stringify(_summary, "  ") + "\n")
	file.close()
	print("wrote shots/gallery_summary.json")


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("presentation gallery FAILED: %s" % message)
	quit(1)


func _clear_fixture_files() -> void:
	for name in [
		"presentation_gallery_save.json",
		"presentation_gallery_runs.jsonl",
		"presentation_gallery_settings.json",
	]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
