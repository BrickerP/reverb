class_name PresentationAssets
extends RefCounted

# Every shipped content ID has an explicit key. Known content never silently falls
# back by family; fallbacks below only protect unknown future or null definitions.
const WEAPON_KEYS := {
	&"pistol": &"weapon_pistol", &"smg": &"weapon_smg",
	&"shotgun": &"weapon_shotgun", &"rifle": &"weapon_rifle",
	&"orb": &"weapon_orb", &"flechette": &"weapon_flechette",
	&"longbow": &"weapon_longbow", &"hex_bolt": &"weapon_hex_bolt",
	&"twin_fangs": &"weapon_twin_fangs", &"flak_crown": &"weapon_flak_crown",
	&"rail_spike": &"weapon_rail_spike", &"nova_core": &"weapon_nova_core",
}
const ITEM_KEYS := {
	&"iron_heart": &"item_iron_heart", &"sneakers": &"item_sneakers",
	&"sharp_edge": &"item_sharp_edge", &"quick_trigger": &"item_quick_trigger",
	&"long_barrel": &"item_long_barrel", &"lucky_coin": &"item_lucky_coin",
	&"magnet": &"item_magnet", &"regen_patch": &"item_regen_patch",
	&"spare_deck": &"item_spare_deck", &"long_play": &"item_long_play",
	&"loud_speaker": &"item_loud_speaker",
}
const ENEMY_KEYS := {
	&"grunt": &"enemy_grunt", &"runner": &"enemy_runner",
	&"brute": &"enemy_brute", &"silencer": &"enemy_silencer",
	&"bomber": &"enemy_bomber", &"warden": &"enemy_warden",
	&"paradox": &"enemy_paradox",
}
const CHARACTER_FRONT_KEYS := {
	&"looper": &"character_looper_front", &"solo": &"character_solo_front",
	&"mirror": &"character_mirror_front", &"conductor": &"character_conductor_front",
}
const CHARACTER_BACK_KEYS := {
	&"looper": &"character_looper_back", &"solo": &"character_solo_back",
	&"mirror": &"character_mirror_back", &"conductor": &"character_conductor_back",
}

const PATHS := {
	&"shopkeeper": "res://assets/presentation/surfaces/shopkeeper.png",
	&"recording_cartridge": "res://assets/presentation/surfaces/recording_cartridge.png",
	&"character_looper_front": "res://assets/presentation/player.png",
	&"character_looper_back": "res://assets/presentation/characters/looper_back.png",
	&"character_solo_front": "res://assets/presentation/characters/solo_front.png",
	&"character_solo_back": "res://assets/presentation/characters/solo_back.png",
	&"character_mirror_front": "res://assets/presentation/characters/mirror_front.png",
	&"character_mirror_back": "res://assets/presentation/characters/mirror_back.png",
	&"character_conductor_front": "res://assets/presentation/characters/conductor_front.png",
	&"character_conductor_back": "res://assets/presentation/characters/conductor_back.png",
	&"enemy_grunt": "res://assets/presentation/enemy_grunt.png",
	&"enemy_runner": "res://assets/presentation/enemy_runner.png",
	&"enemy_brute": "res://assets/presentation/enemies/brute.png",
	&"enemy_silencer": "res://assets/presentation/enemies/silencer.png",
	&"enemy_bomber": "res://assets/presentation/enemies/bomber.png",
	&"enemy_warden": "res://assets/presentation/enemies/warden.png",
	&"enemy_paradox": "res://assets/presentation/enemies/paradox.png",
	&"weapon_pistol": "res://assets/presentation/weapon_pistol.png",
	&"weapon_smg": "res://assets/presentation/weapons/smg.png",
	&"weapon_shotgun": "res://assets/presentation/weapon_shotgun.png",
	&"weapon_rifle": "res://assets/presentation/weapons/rifle.png",
	&"weapon_orb": "res://assets/presentation/weapon_orb.png",
	&"weapon_flechette": "res://assets/presentation/weapons/flechette.png",
	&"weapon_longbow": "res://assets/presentation/weapons/longbow.png",
	&"weapon_hex_bolt": "res://assets/presentation/weapons/hex_bolt.png",
	&"weapon_twin_fangs": "res://assets/presentation/weapons/twin_fangs.png",
	&"weapon_flak_crown": "res://assets/presentation/weapons/flak_crown.png",
	&"weapon_rail_spike": "res://assets/presentation/weapons/rail_spike.png",
	&"weapon_nova_core": "res://assets/presentation/weapons/nova_core.png",
	&"item_iron_heart": "res://assets/presentation/items/iron_heart.png",
	&"item_sneakers": "res://assets/presentation/items/sneakers.png",
	&"item_sharp_edge": "res://assets/presentation/items/sharp_edge.png",
	&"item_quick_trigger": "res://assets/presentation/items/quick_trigger.png",
	&"item_long_barrel": "res://assets/presentation/items/long_barrel.png",
	&"item_lucky_coin": "res://assets/presentation/items/lucky_coin.png",
	&"item_magnet": "res://assets/presentation/items/magnet.png",
	&"item_regen_patch": "res://assets/presentation/items/regen_patch.png",
	&"item_spare_deck": "res://assets/presentation/items/spare_deck.png",
	&"item_long_play": "res://assets/presentation/items/long_play.png",
	&"item_loud_speaker": "res://assets/presentation/items/loud_speaker.png",
}

# Source-pixel bounds were measured offline at alpha >= 20/255. Runtime only
# scales these rectangles to the imported texture size; it never scans PNG pixels.
const SOURCE_METADATA := {
	&"shopkeeper": {"size": Vector2(2172, 724), "region": Rect2(50, 123, 419, 494)},
	&"recording_cartridge": {"size": Vector2(1536, 1024), "region": Rect2(226, 29, 1116, 967)},
	&"character_looper_front": {"size": Vector2(2172, 724), "region": Rect2(68, 110, 424, 521)},
	&"character_looper_back": {"size": Vector2(2172, 724), "region": Rect2(70, 104, 416, 508)},
	&"character_solo_front": {"size": Vector2(2172, 724), "region": Rect2(65, 70, 442, 575)},
	&"character_solo_back": {"size": Vector2(2172, 724), "region": Rect2(63, 71, 433, 549)},
	&"character_mirror_front": {"size": Vector2(2172, 724), "region": Rect2(39, 138, 464, 483)},
	&"character_mirror_back": {"size": Vector2(2172, 724), "region": Rect2(57, 135, 395, 470)},
	&"character_conductor_front": {"size": Vector2(2172, 724), "region": Rect2(24, 120, 485, 496)},
	&"character_conductor_back": {"size": Vector2(2172, 724), "region": Rect2(46, 143, 460, 447)},
	&"enemy_grunt": {"size": Vector2(2172, 724), "region": Rect2(45, 174, 477, 387)},
	&"enemy_runner": {"size": Vector2(2172, 724), "region": Rect2(49, 93, 468, 516)},
	&"enemy_brute": {"size": Vector2(2172, 724), "region": Rect2(27, 135, 492, 424)},
	&"enemy_silencer": {"size": Vector2(2172, 724), "region": Rect2(92, 96, 401, 536)},
	&"enemy_bomber": {"size": Vector2(2172, 724), "region": Rect2(26, 99, 497, 537)},
	&"enemy_warden": {"size": Vector2(2172, 724), "region": Rect2(119, 174, 389, 421)},
	&"enemy_paradox": {"size": Vector2(2172, 724), "region": Rect2(62, 70, 459, 573)},
	&"weapon_pistol": {"size": Vector2(1536, 1024), "region": Rect2(191, 50, 1165, 914)},
	&"weapon_smg": {"size": Vector2(1536, 1024), "region": Rect2(202, 34, 1142, 944)},
	&"weapon_shotgun": {"size": Vector2(1536, 1024), "region": Rect2(124, 194, 1288, 646)},
	&"weapon_rifle": {"size": Vector2(1774, 887), "region": Rect2(48, 269, 1685, 374)},
	&"weapon_orb": {"size": Vector2(1536, 1024), "region": Rect2(292, 140, 974, 723)},
	&"weapon_flechette": {"size": Vector2(1536, 1024), "region": Rect2(198, 192, 1154, 674)},
	&"weapon_longbow": {"size": Vector2(1536, 1024), "region": Rect2(341, 18, 920, 984)},
	&"weapon_hex_bolt": {"size": Vector2(1536, 1024), "region": Rect2(32, 208, 1478, 608)},
	&"weapon_twin_fangs": {"size": Vector2(1536, 1024), "region": Rect2(155, 86, 1232, 851)},
	&"weapon_flak_crown": {"size": Vector2(1536, 1024), "region": Rect2(25, 67, 1493, 805)},
	&"weapon_rail_spike": {"size": Vector2(2175, 723), "region": Rect2(21, 152, 2136, 410)},
	&"weapon_nova_core": {"size": Vector2(1536, 1024), "region": Rect2(277, 64, 980, 897)},
	&"item_iron_heart": {"size": Vector2(1312, 1199), "region": Rect2(86, 125, 1148, 971)},
	&"item_sneakers": {"size": Vector2(1536, 1024), "region": Rect2(65, 37, 1423, 957)},
	&"item_sharp_edge": {"size": Vector2(1293, 1216), "region": Rect2(91, 162, 1150, 917)},
	&"item_quick_trigger": {"size": Vector2(1312, 1199), "region": Rect2(104, 96, 1164, 1019)},
	&"item_long_barrel": {"size": Vector2(1312, 1199), "region": Rect2(13, 228, 1290, 726)},
	&"item_lucky_coin": {"size": Vector2(1312, 1199), "region": Rect2(146, 92, 1045, 1030)},
	&"item_magnet": {"size": Vector2(1312, 1199), "region": Rect2(133, 80, 1070, 1037)},
	&"item_regen_patch": {"size": Vector2(1312, 1199), "region": Rect2(42, 128, 1243, 954)},
	&"item_spare_deck": {"size": Vector2(1312, 1199), "region": Rect2(126, 75, 1051, 1035)},
	&"item_long_play": {"size": Vector2(1312, 1199), "region": Rect2(93, 51, 1176, 1104)},
	&"item_loud_speaker": {"size": Vector2(1312, 1199), "region": Rect2(52, 83, 1212, 1033)},
}

const FRAME_COUNTS := {
	&"shopkeeper": 4,
	&"character_looper_front": 4,
	&"character_looper_back": 4,
	&"character_solo_front": 4,
	&"character_solo_back": 4,
	&"character_mirror_front": 4,
	&"character_mirror_back": 4,
	&"character_conductor_front": 4,
	&"character_conductor_back": 4,
	&"enemy_grunt": 4,
	&"enemy_runner": 4,
	&"enemy_brute": 4,
	&"enemy_silencer": 4,
	&"enemy_bomber": 4,
	&"enemy_warden": 4,
	&"enemy_paradox": 4,
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
	var key: StringName = WEAPON_KEYS.get(w.id, &"weapon_pistol")
	return key


static func frame_count(key: StringName) -> int:
	if not PATHS.has(key):
		return 0
	return int(FRAME_COUNTS.get(key, 1))


static func frame_region(key: StringName, index: int) -> Rect2:
	var first := region(key)
	var count := frame_count(key)
	if count <= 1 or not first.has_area():
		return first
	var tex := texture(key)
	var frame := clampi(index, 0, count - 1)
	return Rect2(first.position + Vector2(float(frame) * tex.get_width() / float(count), 0.0), first.size)


static func item_key(item: ItemDef) -> StringName:
	if item == null:
		return &"item_iron_heart"
	var key: StringName = ITEM_KEYS.get(item.id, &"item_iron_heart")
	return key


static func enemy_key(def: EnemyDef) -> StringName:
	if def == null:
		return &"enemy_grunt"
	var key: StringName = ENEMY_KEYS.get(def.id, &"enemy_grunt")
	return key


static func character_key(id: StringName, back: bool = false) -> StringName:
	var keys: Dictionary = CHARACTER_BACK_KEYS if back else CHARACTER_FRONT_KEYS
	var fallback: StringName = &"character_looper_back" if back else &"character_looper_front"
	var key: StringName = keys.get(id, fallback)
	return key
