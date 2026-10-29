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
	&"shopkeeper": {"size": Vector2(2172, 724), "region": Rect2(50, 123, 419, 494), "idle": Rect2(87, 124, 347, 493), "pivots": [Vector2(221.5, 494), Vector2(221.5, 494), Vector2(221.5, 493), Vector2(221.5, 494)]},
	&"recording_cartridge": {"size": Vector2(1536, 1024), "region": Rect2(226, 29, 1116, 967), "idle": Rect2(226, 29, 1116, 967), "pivots": [Vector2(542.0, 967)]},
	&"character_looper_front": {"size": Vector2(1536, 1024), "region": Rect2(33, 88, 319, 360), "idle": Rect2(69, 128, 254, 313), "pivots": [Vector2(159.0, 353), Vector2(159.0, 360), Vector2(159.0, 357), Vector2(159.0, 353), Vector2(159.0, 297), Vector2(159.0, 296), Vector2(159.0, 306), Vector2(159.0, 310)]},
	&"character_looper_back": {"size": Vector2(1536, 1024), "region": Rect2(41, 73, 333, 394), "idle": Rect2(66, 97, 279, 362), "pivots": [Vector2(151.0, 386), Vector2(151.0, 394), Vector2(151.0, 393), Vector2(151.0, 388), Vector2(151.0, 337), Vector2(151.0, 331), Vector2(151.0, 339), Vector2(151.0, 345)]},
	&"character_solo_front": {"size": Vector2(1536, 1024), "region": Rect2(44, 88, 331, 395), "idle": Rect2(64, 129, 263, 344), "pivots": [Vector2(148.0, 385), Vector2(148.0, 395), Vector2(148.0, 395), Vector2(148.0, 386), Vector2(148.0, 325), Vector2(148.0, 324), Vector2(148.0, 328), Vector2(148.0, 330)]},
	&"character_solo_back": {"size": Vector2(1536, 1024), "region": Rect2(67, 90, 278, 326), "idle": Rect2(83, 116, 233, 294), "pivots": [Vector2(125.0, 320), Vector2(125.0, 326), Vector2(125.0, 326), Vector2(125.0, 323), Vector2(125.0, 282), Vector2(125.0, 282), Vector2(125.0, 280), Vector2(125.0, 278)]},
	&"character_mirror_front": {"size": Vector2(1536, 1024), "region": Rect2(2, 81, 377, 410), "idle": Rect2(45, 115, 283, 363), "pivots": [Vector2(190.0, 397), Vector2(190.0, 400), Vector2(190.0, 410), Vector2(190.0, 398), Vector2(190.0, 344), Vector2(190.0, 344), Vector2(190.0, 351), Vector2(190.0, 349)]},
	&"character_mirror_back": {"size": Vector2(1536, 1024), "region": Rect2(19, 71, 357, 401), "idle": Rect2(70, 93, 277, 369), "pivots": [Vector2(173.0, 391), Vector2(173.0, 401), Vector2(173.0, 389), Vector2(173.0, 391), Vector2(173.0, 347), Vector2(173.0, 363), Vector2(173.0, 352), Vector2(173.0, 353)]},
	&"character_conductor_front": {"size": Vector2(1536, 1024), "region": Rect2(36, 124, 309, 294), "idle": Rect2(74, 148, 236, 265), "pivots": [Vector2(156.0, 289), Vector2(156.0, 293), Vector2(156.0, 294), Vector2(156.0, 293), Vector2(156.0, 261), Vector2(156.0, 261), Vector2(156.0, 262), Vector2(156.0, 261)]},
	&"character_conductor_back": {"size": Vector2(1536, 1024), "region": Rect2(51, 145, 299, 304), "idle": Rect2(90, 191, 242, 255), "pivots": [Vector2(141.0, 301), Vector2(141.0, 303), Vector2(141.0, 304), Vector2(141.0, 301), Vector2(141.0, 227), Vector2(141.0, 225), Vector2(141.0, 229), Vector2(141.0, 233)]},
	&"enemy_grunt": {"size": Vector2(1536, 1024), "region": Rect2(19, 127, 354, 324), "idle": Rect2(40, 200, 295, 241), "pivots": [Vector2(173.0, 314), Vector2(173.0, 324), Vector2(173.0, 317), Vector2(173.0, 317), Vector2(173.0, 251), Vector2(173.0, 249), Vector2(173.0, 252), Vector2(173.0, 256)]},
	&"enemy_runner": {"size": Vector2(1536, 1024), "region": Rect2(11, 93, 361, 386), "idle": Rect2(41, 140, 280, 328), "pivots": [Vector2(181.0, 375), Vector2(181.0, 386), Vector2(181.0, 377), Vector2(181.0, 376), Vector2(181.0, 345), Vector2(181.0, 351), Vector2(181.0, 346), Vector2(181.0, 353)]},
	&"enemy_brute": {"size": Vector2(1536, 1024), "region": Rect2(75, 147, 256, 235), "idle": Rect2(75, 178, 230, 200), "pivots": [Vector2(117.0, 231), Vector2(117.0, 233), Vector2(117.0, 233), Vector2(117.0, 235), Vector2(117.0, 216), Vector2(117.0, 212), Vector2(117.0, 213), Vector2(117.0, 214)]},
	&"enemy_silencer": {"size": Vector2(1536, 1024), "region": Rect2(1, 56, 355, 431), "idle": Rect2(59, 100, 261, 385), "pivots": [Vector2(191.0, 429), Vector2(191.0, 431), Vector2(191.0, 431), Vector2(191.0, 431), Vector2(191.0, 374), Vector2(191.0, 368), Vector2(191.0, 367), Vector2(191.0, 375)]},
	&"enemy_bomber": {"size": Vector2(1536, 1024), "region": Rect2(4, 76, 349, 418), "idle": Rect2(56, 163, 266, 327), "pivots": [Vector2(188.0, 414), Vector2(188.0, 413), Vector2(188.0, 415), Vector2(188.0, 418), Vector2(188.0, 320), Vector2(188.0, 321), Vector2(188.0, 323), Vector2(188.0, 334)]},
	&"enemy_warden": {"size": Vector2(1536, 1024), "region": Rect2(5, 84, 379, 412), "idle": Rect2(50, 128, 316, 362), "pivots": [Vector2(187.0, 406), Vector2(187.0, 406), Vector2(187.0, 412), Vector2(187.0, 406), Vector2(187.0, 331), Vector2(187.0, 332), Vector2(187.0, 331), Vector2(187.0, 335)]},
	&"enemy_paradox": {"size": Vector2(1536, 1024), "region": Rect2(2, 75, 354, 410), "idle": Rect2(42, 77, 279, 405), "pivots": [Vector2(190.0, 407), Vector2(190.0, 410), Vector2(190.0, 408), Vector2(190.0, 407), Vector2(190.0, 355), Vector2(190.0, 320), Vector2(190.0, 352), Vector2(190.0, 357)]},
	&"weapon_pistol": {"size": Vector2(1536, 1024), "region": Rect2(191, 50, 1165, 914), "idle": Rect2(191, 50, 1165, 914), "pivots": [Vector2(577.0, 914)]},
	&"weapon_smg": {"size": Vector2(1536, 1024), "region": Rect2(202, 34, 1142, 944), "idle": Rect2(202, 34, 1142, 944), "pivots": [Vector2(566.0, 944)]},
	&"weapon_shotgun": {"size": Vector2(1536, 1024), "region": Rect2(124, 194, 1288, 646), "idle": Rect2(124, 194, 1288, 646), "pivots": [Vector2(644.0, 646)]},
	&"weapon_rifle": {"size": Vector2(1774, 887), "region": Rect2(48, 269, 1685, 374), "idle": Rect2(48, 269, 1685, 374), "pivots": [Vector2(839.0, 374)]},
	&"weapon_orb": {"size": Vector2(1536, 1024), "region": Rect2(292, 140, 974, 723), "idle": Rect2(292, 140, 974, 723), "pivots": [Vector2(476.0, 723)]},
	&"weapon_flechette": {"size": Vector2(1536, 1024), "region": Rect2(198, 192, 1154, 674), "idle": Rect2(198, 192, 1154, 674), "pivots": [Vector2(570.0, 674)]},
	&"weapon_longbow": {"size": Vector2(1536, 1024), "region": Rect2(341, 18, 920, 984), "idle": Rect2(341, 18, 920, 984), "pivots": [Vector2(427.0, 984)]},
	&"weapon_hex_bolt": {"size": Vector2(1536, 1024), "region": Rect2(32, 208, 1478, 608), "idle": Rect2(32, 208, 1478, 608), "pivots": [Vector2(736.0, 608)]},
	&"weapon_twin_fangs": {"size": Vector2(1536, 1024), "region": Rect2(155, 86, 1232, 851), "idle": Rect2(155, 86, 1232, 851), "pivots": [Vector2(613.0, 851)]},
	&"weapon_flak_crown": {"size": Vector2(1536, 1024), "region": Rect2(25, 67, 1493, 805), "idle": Rect2(25, 67, 1493, 805), "pivots": [Vector2(743.0, 805)]},
	&"weapon_rail_spike": {"size": Vector2(2175, 723), "region": Rect2(21, 152, 2136, 410), "idle": Rect2(21, 152, 2136, 410), "pivots": [Vector2(1066.5, 410)]},
	&"weapon_nova_core": {"size": Vector2(1536, 1024), "region": Rect2(277, 64, 980, 897), "idle": Rect2(277, 64, 980, 897), "pivots": [Vector2(491.0, 897)]},
	&"item_iron_heart": {"size": Vector2(1312, 1199), "region": Rect2(86, 125, 1148, 971), "idle": Rect2(86, 125, 1148, 971), "pivots": [Vector2(570.0, 971)]},
	&"item_sneakers": {"size": Vector2(1536, 1024), "region": Rect2(65, 37, 1423, 957), "idle": Rect2(65, 37, 1423, 957), "pivots": [Vector2(703.0, 957)]},
	&"item_sharp_edge": {"size": Vector2(1293, 1216), "region": Rect2(91, 162, 1150, 917), "idle": Rect2(91, 162, 1150, 917), "pivots": [Vector2(555.5, 917)]},
	&"item_quick_trigger": {"size": Vector2(1312, 1199), "region": Rect2(104, 96, 1164, 1019), "idle": Rect2(104, 96, 1164, 1019), "pivots": [Vector2(552.0, 1019)]},
	&"item_long_barrel": {"size": Vector2(1312, 1199), "region": Rect2(13, 228, 1290, 726), "idle": Rect2(13, 228, 1290, 726), "pivots": [Vector2(643.0, 726)]},
	&"item_lucky_coin": {"size": Vector2(1312, 1199), "region": Rect2(146, 92, 1045, 1030), "idle": Rect2(146, 92, 1045, 1030), "pivots": [Vector2(510.0, 1030)]},
	&"item_magnet": {"size": Vector2(1312, 1199), "region": Rect2(133, 80, 1070, 1037), "idle": Rect2(133, 80, 1070, 1037), "pivots": [Vector2(523.0, 1037)]},
	&"item_regen_patch": {"size": Vector2(1312, 1199), "region": Rect2(42, 128, 1243, 954), "idle": Rect2(42, 128, 1243, 954), "pivots": [Vector2(614.0, 954)]},
	&"item_spare_deck": {"size": Vector2(1312, 1199), "region": Rect2(126, 75, 1051, 1035), "idle": Rect2(126, 75, 1051, 1035), "pivots": [Vector2(530.0, 1035)]},
	&"item_long_play": {"size": Vector2(1312, 1199), "region": Rect2(93, 51, 1176, 1104), "idle": Rect2(93, 51, 1176, 1104), "pivots": [Vector2(563.0, 1104)]},
	&"item_loud_speaker": {"size": Vector2(1312, 1199), "region": Rect2(52, 83, 1212, 1033), "idle": Rect2(52, 83, 1212, 1033), "pivots": [Vector2(604.0, 1033)]},
}

const ATLAS_LAYOUTS := {
	&"shopkeeper": Vector2i(4, 1),
	&"character_looper_front": Vector2i(4, 2),
	&"character_looper_back": Vector2i(4, 2),
	&"character_solo_front": Vector2i(4, 2),
	&"character_solo_back": Vector2i(4, 2),
	&"character_mirror_front": Vector2i(4, 2),
	&"character_mirror_back": Vector2i(4, 2),
	&"character_conductor_front": Vector2i(4, 2),
	&"character_conductor_back": Vector2i(4, 2),
	&"enemy_grunt": Vector2i(4, 2),
	&"enemy_runner": Vector2i(4, 2),
	&"enemy_brute": Vector2i(4, 2),
	&"enemy_silencer": Vector2i(4, 2),
	&"enemy_bomber": Vector2i(4, 2),
	&"enemy_warden": Vector2i(4, 2),
	&"enemy_paradox": Vector2i(4, 2),
}

static var _textures: Dictionary = {}
static var _regions: Dictionary = {}
static var _idle_regions: Dictionary = {}
static var _frame_regions: Dictionary = {}
static var _frame_pivots: Dictionary = {}


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
	var layout: Vector2i = ATLAS_LAYOUTS.get(key, Vector2i.ONE)
	return layout.x * layout.y


static func frame_region(key: StringName, index: int) -> Rect2:
	var first := region(key)
	var count := frame_count(key)
	if count <= 1 or not first.has_area():
		return first
	if not _frame_regions.has(key):
		var tex := texture(key)
		var layout: Vector2i = ATLAS_LAYOUTS.get(key, Vector2i.ONE)
		var frames: Array[Rect2] = []
		for frame in count:
			var column := frame % layout.x
			var row := int(frame / layout.x)
			frames.append(Rect2(first.position + Vector2(float(column) * tex.get_width() / float(layout.x),
					float(row) * tex.get_height() / float(layout.y)), first.size))
		_frame_regions[key] = frames
	var cached: Array = _frame_regions[key]
	return cached[clampi(index, 0, count - 1)]


static func idle_region(key: StringName) -> Rect2:
	if _idle_regions.has(key):
		return _idle_regions[key]
	var tex := texture(key)
	if tex == null or not SOURCE_METADATA.has(key):
		return Rect2()
	var data: Dictionary = SOURCE_METADATA[key]
	var idle: Rect2 = data["idle"]
	var size: Vector2 = data["size"]
	var scale := tex.get_size() / size
	var measured := Rect2(idle.position * scale, idle.size * scale)
	_idle_regions[key] = measured
	return measured


static func frame_pivot(key: StringName, index: int) -> Vector2:
	var count := frame_count(key)
	var tex := texture(key)
	if count == 0 or tex == null:
		return Vector2.ZERO
	if not _frame_pivots.has(key):
		var data: Dictionary = SOURCE_METADATA[key]
		var size: Vector2 = data["size"]
		var scale := tex.get_size() / size
		var measured: Array[Vector2] = []
		for pivot: Vector2 in data["pivots"]:
			measured.append(pivot * scale)
		_frame_pivots[key] = measured
	var cached: Array = _frame_pivots[key]
	return cached[clampi(index, 0, count - 1)]


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
