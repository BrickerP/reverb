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
	&"character_looper_front": {"size": Vector2(1254, 1254), "region": Rect2(379, 247, 525, 816)},
	&"character_looper_back": {"size": Vector2(1254, 1254), "region": Rect2(386, 233, 517, 832)},
	&"character_solo_front": {"size": Vector2(1254, 1254), "region": Rect2(395, 169, 538, 972)},
	&"character_solo_back": {"size": Vector2(1254, 1254), "region": Rect2(385, 152, 506, 1001)},
	&"character_mirror_front": {"size": Vector2(1254, 1254), "region": Rect2(333, 162, 636, 990)},
	&"character_mirror_back": {"size": Vector2(1254, 1254), "region": Rect2(330, 177, 609, 971)},
	&"character_conductor_front": {"size": Vector2(1254, 1254), "region": Rect2(292, 148, 759, 995)},
	&"character_conductor_back": {"size": Vector2(1254, 1254), "region": Rect2(241, 86, 797, 1092)},
	&"enemy_grunt": {"size": Vector2(1254, 1254), "region": Rect2(184, 273, 906, 723)},
	&"enemy_runner": {"size": Vector2(1254, 1254), "region": Rect2(289, 207, 785, 840)},
	&"enemy_brute": {"size": Vector2(1402, 1122), "region": Rect2(77, 111, 1279, 937)},
	&"enemy_silencer": {"size": Vector2(1254, 1254), "region": Rect2(302, 36, 750, 1150)},
	&"enemy_bomber": {"size": Vector2(1254, 1254), "region": Rect2(145, 252, 989, 846)},
	&"enemy_warden": {"size": Vector2(1254, 1254), "region": Rect2(120, 233, 1072, 864)},
	&"enemy_paradox": {"size": Vector2(1254, 1254), "region": Rect2(23, 131, 1224, 1027)},
	&"weapon_pistol": {"size": Vector2(1254, 1254), "region": Rect2(145, 329, 1046, 639)},
	&"weapon_smg": {"size": Vector2(1536, 1024), "region": Rect2(38, 219, 1468, 625)},
	&"weapon_shotgun": {"size": Vector2(1254, 1254), "region": Rect2(74, 403, 1144, 476)},
	&"weapon_rifle": {"size": Vector2(1881, 836), "region": Rect2(22, 176, 1838, 505)},
	&"weapon_orb": {"size": Vector2(1254, 1254), "region": Rect2(82, 318, 1125, 604)},
	&"weapon_flechette": {"size": Vector2(1536, 1024), "region": Rect2(178, 201, 1287, 665)},
	&"weapon_longbow": {"size": Vector2(1536, 1024), "region": Rect2(559, 31, 654, 964)},
	&"weapon_hex_bolt": {"size": Vector2(1536, 1024), "region": Rect2(132, 220, 1321, 631)},
	&"weapon_twin_fangs": {"size": Vector2(1536, 1024), "region": Rect2(119, 149, 1317, 776)},
	&"weapon_flak_crown": {"size": Vector2(1536, 1024), "region": Rect2(16, 117, 1507, 741)},
	&"weapon_rail_spike": {"size": Vector2(1942, 809), "region": Rect2(27, 167, 1888, 482)},
	&"weapon_nova_core": {"size": Vector2(1619, 971), "region": Rect2(49, 125, 1537, 719)},
	&"item_iron_heart": {"size": Vector2(1254, 1254), "region": Rect2(68, 97, 1130, 1054)},
	&"item_sneakers": {"size": Vector2(1254, 1254), "region": Rect2(10, 125, 1236, 1004)},
	&"item_sharp_edge": {"size": Vector2(1254, 1254), "region": Rect2(59, 176, 1171, 895)},
	&"item_quick_trigger": {"size": Vector2(1254, 1254), "region": Rect2(60, 81, 1155, 1052)},
	&"item_long_barrel": {"size": Vector2(1254, 1254), "region": Rect2(11, 202, 1232, 822)},
	&"item_lucky_coin": {"size": Vector2(1254, 1254), "region": Rect2(118, 139, 1027, 970)},
	&"item_magnet": {"size": Vector2(1254, 1254), "region": Rect2(69, 67, 1117, 1134)},
	&"item_regen_patch": {"size": Vector2(1254, 1254), "region": Rect2(152, 116, 955, 1058)},
	&"item_spare_deck": {"size": Vector2(1254, 1254), "region": Rect2(46, 61, 1167, 1144)},
	&"item_long_play": {"size": Vector2(1254, 1254), "region": Rect2(20, 113, 1213, 1021)},
	&"item_loud_speaker": {"size": Vector2(1254, 1254), "region": Rect2(112, 84, 1037, 1104)},
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
