class_name PresentationAssets
extends RefCounted

const PATHS := {
	&"player": "res://assets/presentation/player.png",
	&"enemy_grunt": "res://assets/presentation/enemy_grunt.png",
	&"enemy_runner": "res://assets/presentation/enemy_runner.png",
	&"weapon_pistol": "res://assets/presentation/weapon_pistol.png",
	&"weapon_shotgun": "res://assets/presentation/weapon_shotgun.png",
	&"weapon_orb": "res://assets/presentation/weapon_orb.png",
}
const SOURCE_METADATA := {
	&"player": {
		"size": Vector2(1254.0, 1254.0),
		"region": Rect2(379.0, 247.0, 525.0, 816.0),
	},
	&"enemy_grunt": {
		"size": Vector2(1254.0, 1254.0),
		"region": Rect2(184.0, 273.0, 906.0, 723.0),
	},
	&"enemy_runner": {
		"size": Vector2(1254.0, 1254.0),
		"region": Rect2(289.0, 207.0, 785.0, 840.0),
	},
	&"weapon_pistol": {
		"size": Vector2(1254.0, 1254.0),
		"region": Rect2(145.0, 329.0, 1046.0, 639.0),
	},
	&"weapon_shotgun": {
		"size": Vector2(1254.0, 1254.0),
		"region": Rect2(74.0, 403.0, 1144.0, 476.0),
	},
	&"weapon_orb": {
		"size": Vector2(1254.0, 1254.0),
		"region": Rect2(82.0, 318.0, 1125.0, 604.0),
	},
}

static var _textures: Dictionary = {}
static var _regions: Dictionary = {}


static func texture(key: StringName) -> Texture2D:
	if _textures.has(key):
		return _textures[key] as Texture2D
	var path := String(PATHS.get(key, ""))
	if path.is_empty():
		_textures[key] = null
		return null
	var loaded := load(path) as Texture2D
	_textures[key] = loaded
	return loaded


static func region(key: StringName) -> Rect2:
	if _regions.has(key):
		var cached: Rect2 = _regions[key]
		return cached
	var tex := texture(key)
	if tex == null or not SOURCE_METADATA.has(key):
		_regions[key] = Rect2()
		return _regions[key]
	var metadata: Dictionary = SOURCE_METADATA[key]
	var source_size: Vector2 = metadata.get("size", Vector2.ZERO)
	var source_region: Rect2 = metadata.get("region", Rect2())
	if source_size.x <= 0.0 or source_size.y <= 0.0 or not source_region.has_area():
		_regions[key] = Rect2()
		return _regions[key]
	var scale := tex.get_size() / source_size
	var visible := Rect2(source_region.position * scale, source_region.size * scale)
	_regions[key] = visible
	return visible


static func weapon_key(w: WeaponDef) -> StringName:
	if w == null:
		return &"weapon_pistol"
	match w.family:
		&"scatter":
			return &"weapon_shotgun"
		&"arcane":
			return &"weapon_orb"
		&"sidearm", &"marksman":
			return &"weapon_pistol"
		_:
			return &"weapon_pistol"
