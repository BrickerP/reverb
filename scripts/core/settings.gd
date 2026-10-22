class_name Settings
extends RefCounted

const DEFAULT_PATH := "user://settings.json"

var path: String
var volume: float = 0.8
var shake: bool = true
var fullscreen: bool = false
var language: String = ""


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	_load()


func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	var values: Dictionary = data
	volume = clampf(float(values.get("volume", volume)), 0.0, 1.0)
	shake = bool(values.get("shake", shake))
	fullscreen = bool(values.get("fullscreen", fullscreen))
	var lang := str(values.get("language", language))
	language = lang if lang in ["", "en", "zh"] else ""


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"volume": volume,
		"shake": shake,
		"fullscreen": fullscreen,
		"language": language,
	}, "\t"))
