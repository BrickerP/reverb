class_name RunSnapshot
extends RefCounted

# Saves only this closed family of data objects. A save never supplies a script
# path, invokes a setter outside these classes, or carries signal connections.
const VERSION := 4
const MAX_OBJECTS := 16000
const MAX_VALUES := 1000000
const MAX_DEPTH := 48
const MAX_STRING := 16384
const TYPES := {
	"Sim": preload("res://scripts/sim/sim.gd"),
	"PlayerState": preload("res://scripts/sim/player_state.gd"),
	"Stats": preload("res://scripts/core/stats.gd"),
	"EchoBank": preload("res://scripts/echo/echo_bank.gd"),
	"EchoTake": preload("res://scripts/echo/echo_take.gd"),
	"EchoActor": preload("res://scripts/echo/echo_actor.gd"),
	"EchoRecorder": preload("res://scripts/echo/echo_recorder.gd"),
	"EnemyState": preload("res://scripts/sim/enemy_state.gd"),
	"Projectile": preload("res://scripts/sim/projectile.gd"),
	"Pickup": preload("res://scripts/sim/pickup.gd"),
	"PendingSpawn": preload("res://scripts/sim/pending_spawn.gd"),
	"SpawnEvent": preload("res://scripts/sim/spawn_event.gd"),
	"TemporalRift": preload("res://scripts/sim/temporal_rift.gd"),
	"AttackField": preload("res://scripts/sim/attack_field.gd"),
	"EnemyZone": preload("res://scripts/sim/enemy_zone.gd"),
	"Shop": preload("res://scripts/sim/shop.gd"),
	"ShopState": preload("res://scripts/sim/shop_state.gd"),
	"Offer": preload("res://scripts/sim/offer.gd"),
	"AnomalyContract": preload("res://scripts/sim/anomaly_contract.gd"),
}
const CONTENT_TYPES := {
	"WeaponDef": preload("res://scripts/data/weapon_def.gd"),
	"EnemyDef": preload("res://scripts/data/enemy_def.gd"),
	"ItemDef": preload("res://scripts/data/item_def.gd"),
	"CharacterDef": preload("res://scripts/data/character_def.gd"),
}
static var last_error: String = ""
var _objects: Array = []
var _rows: Array = []
var _ids: Dictionary = {}
var _value_count := 0
var _error := ""


static func capture(sim: Sim) -> Dictionary:
	last_error = ""
	if sim == null:
		last_error = "snapshot.no_run"
		return {}
	var codec := RunSnapshot.new()
	var root: Variant = codec._encode(sim, 0)
	if codec._error != "":
		last_error = codec._error
		return {}
	return {"version": VERSION, "root": root, "objects": codec._rows}


static func restore(data: Dictionary) -> Sim:
	last_error = ""
	var codec := RunSnapshot.new()
	var result := codec._restore(data)
	last_error = codec._error
	return result


# Main's screen/delay envelope uses exactly the same bounded scalar codec.
static func encode_envelope(data: Dictionary) -> Variant:
	var codec := RunSnapshot.new()
	var out: Variant = codec._encode(data, 0) if codec._plain(data, 0) else null
	last_error = codec._error
	if not codec._rows.is_empty():
		last_error = "snapshot.envelope_object"
	return null if last_error != "" else out


static func decode_envelope(data: Variant) -> Dictionary:
	var codec := RunSnapshot.new()
	var out: Variant = codec._decode(data, 0)
	if (typeof(out) != TYPE_DICTIONARY or not codec._plain(out, 0)) and codec._error == "":
		codec._error = "snapshot.envelope_invalid"
	last_error = codec._error
	return {} if last_error != "" else out


func _fail(reason: String) -> Variant:
	if _error == "":
		_error = reason
	return null


func _budget(depth: int) -> bool:
	_value_count += 1
	if depth > MAX_DEPTH or _value_count > MAX_VALUES:
		_fail("snapshot.too_large")
		return false
	return _error == ""


func _encode(value: Variant, depth: int) -> Variant:
	if not _budget(depth):
		return null
	match typeof(value):
		TYPE_NIL, TYPE_BOOL:
			return value
		TYPE_INT:
			return {"i": str(value)}
		TYPE_FLOAT:
			if not is_finite(value):
				return _fail("snapshot.non_finite")
			# Godot's JSON decimal parser can move a double by one ULP even
			# with full_precision. Store its eight bytes, never rounded text.
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, value)
			return {"f": bytes.hex_encode()}
		TYPE_STRING:
			return value if value.length() <= MAX_STRING else _fail("snapshot.string_too_long")
		TYPE_STRING_NAME:
			return {"n": String(value)}
		TYPE_VECTOR2:
			return {"v": [_encode(value.x, depth + 1), _encode(value.y, depth + 1)]}
		TYPE_COLOR:
			return {"c": [_encode(value.r, depth + 1), _encode(value.g, depth + 1),
				_encode(value.b, depth + 1), _encode(value.a, depth + 1)]}
		TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var entries: Array = []
			for entry: Variant in value:
				entries.append(_encode(entry, depth + 1))
			return {"a": entries, "t": typeof(value)}
		TYPE_DICTIONARY:
			var entries: Array = []
			for key: Variant in value:
				if not typeof(key) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]:
					return _fail("snapshot.invalid_key")
				entries.append([_encode(key, depth + 1), _encode(value[key], depth + 1)])
			return {"d": entries}
		TYPE_OBJECT:
			if value is RandomNumberGenerator:
				return {"rng": [str(value.seed), str(value.state)]}
			var kind := _content_kind(value)
			if kind != "":
				if _content(kind, value.id) != value:
					return _fail("snapshot.noncanonical_content")
				return {"content": [kind, String(value.id)]}
			var type_name := _type_name(value)
			if type_name == "":
				return _fail("snapshot.unknown_type")
			var token: int = value.get_instance_id()
			if _ids.has(token):
				return {"ref": _ids[token]}
			if _rows.size() >= MAX_OBJECTS:
				return _fail("snapshot.too_large")
			var index := _rows.size()
			_ids[token] = index
			var row := {"type": type_name, "fields": {}}
			_rows.append(row)
			for info: Dictionary in _fields(value):
				var name: String = info.name
				row.fields[name] = _encode(value.get(name), depth + 1)
			return {"ref": index}
	return _fail("snapshot.unsupported_value")


func _restore(data: Dictionary) -> Sim:
	if data.size() != 3 or data.get("version") != VERSION or typeof(data.get("objects")) != TYPE_ARRAY:
		_fail("snapshot.version")
		return null
	_rows = data.objects
	if _rows.is_empty() or _rows.size() > MAX_OBJECTS:
		_fail("snapshot.too_large")
		return null
	if not _prevalidate(data.get("root")):
		return null
	for row: Dictionary in _rows:
		_objects.append(_factory(row.type))
	for i in _rows.size():
		var target: Object = _objects[i]
		var saved: Dictionary = _rows[i].fields
		var fields := _fields(target)
		if saved.size() != fields.size():
			_fail("snapshot.schema")
			return null
		for info: Dictionary in fields:
			var name: String = info.name
			if not saved.has(name):
				_fail("snapshot.schema")
				return null
			var value: Variant = _decode(saved[name], 0)
			if _error != "" or not _assign(target, info, value):
				return null
	var root: Variant = _decode(data.get("root"), 0)
	if not root is Sim or not _validate_objects() or not _validate_run(root):
		if _error == "":
			_fail("snapshot.invalid_run")
		return null
	root.grid.clear()
	for enemy: EnemyState in root.enemies:
		if not enemy.dead:
			root.grid.insert(enemy)
	return root


func _decode(value: Variant, depth: int) -> Variant:
	if not _budget(depth):
		return null
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_STRING]:
		return value if typeof(value) != TYPE_STRING or value.length() <= MAX_STRING else _fail("snapshot.string_too_long")
	if typeof(value) != TYPE_DICTIONARY:
		return _fail("snapshot.invalid_value")
	if value.has("i") and value.size() == 1:
		return _integer(value.i)
	if value.has("f") and value.size() == 1:
		if typeof(value.f) != TYPE_STRING or value.f.length() != 16:
			return _fail("snapshot.invalid_value")
		for character: String in value.f:
			if not character in "0123456789abcdef":
				return _fail("snapshot.invalid_value")
		var decoded: float = value.f.hex_decode().decode_double(0)
		return decoded if is_finite(decoded) else _fail("snapshot.non_finite")
	if value.has("n") and value.size() == 1 and typeof(value.n) == TYPE_STRING:
		return StringName(value.n) if value.n.length() <= MAX_STRING else _fail("snapshot.string_too_long")
	if value.has("ref") and value.size() == 1:
		if typeof(value.ref) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.ref)) \
				or float(value.ref) != floor(float(value.ref)) or value.ref < 0 or value.ref >= _objects.size():
			return _fail("snapshot.invalid_reference")
		return _objects[int(value.ref)]
	if value.has("content") and value.size() == 1:
		var pair: Variant = value.content
		if typeof(pair) != TYPE_ARRAY or pair.size() != 2 or typeof(pair[0]) != TYPE_STRING or typeof(pair[1]) != TYPE_STRING:
			return _fail("snapshot.invalid_content")
		var found := _content(pair[0], StringName(pair[1]))
		return found if found != null else _fail("snapshot.invalid_content")
	if value.has("rng") and value.size() == 1:
		if typeof(value.rng) != TYPE_ARRAY or value.rng.size() != 2:
			return _fail("snapshot.invalid_rng")
		var seed_value: Variant = _integer(value.rng[0])
		var state_value: Variant = _integer(value.rng[1])
		if _error != "":
			return null
		var generator := RandomNumberGenerator.new()
		generator.seed = seed_value
		generator.state = state_value
		return generator
	if value.has("v") or value.has("c"):
		var key := "v" if value.has("v") else "c"
		var count := 2 if key == "v" else 4
		if value.size() != 1 or typeof(value[key]) != TYPE_ARRAY or value[key].size() != count:
			return _fail("snapshot.invalid_geometry")
		var parts: Array = []
		for part: Variant in value[key]:
			var decoded: Variant = _decode(part, depth + 1)
			if typeof(decoded) != TYPE_FLOAT:
				return _fail("snapshot.invalid_geometry")
			parts.append(decoded)
		if count == 2:
			var vector := Vector2(parts[0], parts[1])
			return vector if vector.is_finite() else _fail("snapshot.non_finite")
		var color := Color(parts[0], parts[1], parts[2], parts[3])
		return color if is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a) else _fail("snapshot.non_finite")
	if value.has("a") and value.has("t") and value.size() == 2:
		if typeof(value.a) != TYPE_ARRAY or value.a.size() > MAX_VALUES \
				or typeof(value.t) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.t)) \
				or float(value.t) != floor(float(value.t)):
			return _fail("snapshot.invalid_array")
		var entries: Array = []
		for entry: Variant in value.a:
			entries.append(_decode(entry, depth + 1))
		if _error != "":
			return null
		var element_type: int = {TYPE_ARRAY: TYPE_NIL, TYPE_PACKED_VECTOR2_ARRAY: TYPE_VECTOR2,
			TYPE_PACKED_INT32_ARRAY: TYPE_INT, TYPE_PACKED_INT64_ARRAY: TYPE_INT,
			TYPE_PACKED_STRING_ARRAY: TYPE_STRING, TYPE_PACKED_FLOAT32_ARRAY: TYPE_FLOAT,
			TYPE_PACKED_FLOAT64_ARRAY: TYPE_FLOAT}.get(int(value.t), -1)
		if element_type < 0:
			return _fail("snapshot.invalid_array")
		if element_type != TYPE_NIL:
			for entry: Variant in entries:
				if typeof(entry) != element_type:
					return _fail("snapshot.invalid_array")
				if value.t == TYPE_PACKED_INT32_ARRAY and (entry < -2147483648 or entry > 2147483647):
					return _fail("snapshot.invalid_integer")
				if value.t == TYPE_PACKED_FLOAT32_ARRAY and absf(entry) > 3.402823466e38:
					return _fail("snapshot.non_finite")
		match int(value.t):
			TYPE_ARRAY: return entries
			TYPE_PACKED_VECTOR2_ARRAY: return PackedVector2Array(entries)
			TYPE_PACKED_INT32_ARRAY: return PackedInt32Array(entries)
			TYPE_PACKED_INT64_ARRAY: return PackedInt64Array(entries)
			TYPE_PACKED_STRING_ARRAY: return PackedStringArray(entries)
			TYPE_PACKED_FLOAT32_ARRAY: return PackedFloat32Array(entries)
			TYPE_PACKED_FLOAT64_ARRAY: return PackedFloat64Array(entries)
	if value.has("d") and value.size() == 1 and typeof(value.d) == TYPE_ARRAY:
		var out: Dictionary = {}
		for pair: Variant in value.d:
			if typeof(pair) != TYPE_ARRAY or pair.size() != 2:
				return _fail("snapshot.invalid_dictionary")
			var key: Variant = _decode(pair[0], depth + 1)
			if not typeof(key) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT] or out.has(key):
				return _fail("snapshot.invalid_key")
			out[key] = _decode(pair[1], depth + 1)
		return out if _plain(out, 0, "snapshot.field_type") else null
	return _fail("snapshot.invalid_value")


func _integer(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING or value.length() > 20 or not value.is_valid_int():
		return _fail("snapshot.invalid_integer")
	var integer: int = value.to_int()
	return integer if str(integer) == value else _fail("snapshot.invalid_integer")


func _assign(target: Object, info: Dictionary, value: Variant) -> bool:
	var expected: int = info.type
	if expected != TYPE_NIL and typeof(value) != expected:
		if not (expected == TYPE_OBJECT and value == null):
			_fail("snapshot.field_type")
			return false
	if expected == TYPE_OBJECT and value != null:
		var class_hint := str(info.get("class_name", ""))
		if class_hint == "":
			class_hint = str(info.get("hint_string", ""))
		if TYPES.has(class_hint) and not is_instance_of(value, TYPES[class_hint]):
			_fail("snapshot.field_type")
			return false
		if CONTENT_TYPES.has(class_hint) and not is_instance_of(value, CONTENT_TYPES[class_hint]):
			_fail("snapshot.field_type")
			return false
		if class_hint == "RandomNumberGenerator" and not value is RandomNumberGenerator:
			_fail("snapshot.field_type")
			return false
	if expected == TYPE_ARRAY:
		var typed: Array = target.get(info.name)
		for element: Variant in value:
			if typed.get_typed_builtin() != TYPE_NIL and typeof(element) != typed.get_typed_builtin():
				_fail("snapshot.array_type")
				return false
			if typed.get_typed_script() != null and not is_instance_of(element, typed.get_typed_script()):
				_fail("snapshot.array_type")
				return false
		typed.assign(value)
		target.set(info.name, typed)
	else:
		target.set(info.name, value)
	return true


func _fields(value: Object) -> Array[Dictionary]:
	return _schema_fields(_type_name(value))


func _schema_fields(type_name: String) -> Array[Dictionary]:
	var fields: Array[Dictionary] = []
	for info: Dictionary in TYPES[type_name].get_script_property_list():
		if int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		# grid is rebuilt after load. The other names are live presentation cues;
		# keeping them out of the row leaves Snapshot v4 the same shape 0.17,
		# 0.18 and 0.18.1 already wrote.
		if type_name == "Sim" and info.name in ["grid", "cue_slot",
				"action_notice_key", "action_notice_text", "action_notice_until"]:
			continue
		fields.append(info)
	return fields


func _type_name(value: Object) -> String:
	for name: String in TYPES:
		if value.get_script() == TYPES[name]:
			return name
	return ""


func _factory(name: String) -> Object:
	if name == "EchoActor":
		return EchoActor.new(EchoTake.new(), 0)
	return TYPES[name].new()


func _content_kind(value: Object) -> String:
	if value is WeaponDef: return "weapon"
	if value is EnemyDef: return "enemy"
	if value is ItemDef: return "item"
	if value is CharacterDef: return "character"
	return ""


func _content(kind: String, id: StringName) -> Object:
	match kind:
		"weapon": return Content.weapon(id)
		"enemy": return Content.enemy(id)
		"item": return Content.item(id)
		"character": return Content.character(id)
	return null


func _validate_run(sim: Sim) -> bool:
	if sim.player == null or sim.player.stats == null or sim.bank == null or sim.recorder == null \
			or sim.shop == null or sim.rng == null or sim.hazard_rng == null \
			or sim.phase < Sim.Phase.WAVE or sim.phase > Sim.Phase.RESOLUTION or sim.wave < 0 \
			or sim.player.weapons.size() != sim.player.weapon_levels.size() \
			or sim.player.weapons.size() != sim.player.cooldowns.size() \
			or not _investments_valid(sim.player.weapon_investments, sim.player.weapons.size()) \
			or not _story_valid(sim.story_progress) or Content.character(sim.character_id) == null \
			or not _role_valid(sim.role_effects, sim.character_energy, sim.character_cooldown) \
			or not Expedition.validate_state(sim) or not SupportSystem.validate_state(sim.support_units, sim._next_support_uid):
		return false
	if sim.wave_time < 0.0 or sim.wave_duration < 0.0 or sim.retire_cooldown < 0.0 \
			or sim.echo_silenced < 0.0 or sim.ascension < 0 or sim.ascension > 3 \
			or sim.boss_phase not in [1, 2] or (sim.boss_rush and not sim.endless) \
			or sim.repair_discount < 0.0 or sim.repair_discount > 1.0 or sim.wear_rate_mult < 0.0 \
			or sim.retirement_mult < 0.0 or sim.pickup_repair < 0.0 \
			or (sim.daily_modifier != &"" and not DailyAnomaly.ALL.has(sim.daily_modifier)):
		return false
	if sim.bank.next_uid() < 1 or sim.bank.tint_counter() < 0:
		return false
	for counter: String in ["kills", "wave_kills", "wave_elite_kills", "boon_rerolls", "echo_refreshes",
		"contracts_accepted", "contracts_completed", "contracts_failed", "retirements", "wave_retirements",
		"second_wind_charges", "last_interest", "last_wave_earned", "wave_start_materials", "shot_sequence",
		"player_shots", "selected_echo_uid"]:
		if sim.get(counter) < 0:
			return false
	if sim.phase == Sim.Phase.WAVE:
		if sim.wave < 1 or sim.wave_duration <= 0.0:
			return false
		var selected_found := sim.echoes.is_empty() and sim.selected_echo_uid == 0
		for actor: EchoActor in sim.echoes:
			if actor != null and actor.take != null and actor.take.uid == sim.selected_echo_uid:
				selected_found = true
		if not selected_found:
			return false
	if sim.active_contract != null and (not sim.active_contract.accepted or not AnomalyContract.KINDS.has(sim.active_contract.kind)):
		return false
	var plan: Array = sim.get("_plan")
	if sim.get("_plan_idx") < 0 or sim.get("_plan_idx") > plan.size() or sim.get("_next_uid") < 1:
		return false
	if sim.phase == Sim.Phase.WAVE and sim.boss != null and not sim.boss_shards.has(sim.boss):
		return false
	for id: StringName in sim.pending_boons + sim.boons_taken:
		if not Boon.ALL.has(id):
			return false
	var uids := {}
	for take: EchoTake in sim.bank.takes:
		if take == null or take.stats == null or take.uid <= 0 or uids.has(take.uid) \
				or take.condition < 0.0 or take.condition > 100.0 or sim.bank.tint_counter() <= take.tint_index:
			return false
		uids[take.uid] = true
		if sim.bank.next_uid() <= take.uid:
			return false
	var actor_ids := {}
	for actor: EchoActor in sim.echoes:
		if actor == null or actor.take == null or not sim.bank.takes.has(actor.take):
			return false
		if actor_ids.has(actor.take.uid) or actor.index != actor_ids.size():
			return false
		actor_ids[actor.take.uid] = true
		var weapon_count := sim.player.weapons.size() if sim.live_echo else actor.take.weapons.size()
		if actor.cooldowns.size() != weapon_count:
			return false
	var enemy_uids := {}
	for enemy: EnemyState in sim.enemies:
		if enemy == null or enemy.def == null or enemy.uid <= 0 or enemy_uids.has(enemy.uid) \
				or sim.get("_next_uid") <= enemy.uid:
			return false
		enemy_uids[enemy.uid] = true
	for shard: EnemyState in sim.boss_shards:
		if shard == null or sim.get("_next_uid") <= shard.uid or (not shard.dead and not sim.enemies.has(shard)):
			return false
	for pending_spawn: PendingSpawn in sim.pending:
		if pending_spawn == null or pending_spawn.def == null:
			return false
	for event: SpawnEvent in sim.get("_plan"):
		if event == null or event.def == null:
			return false
	for offer: Offer in sim.shop.offers:
		if offer == null or int(offer.weapon != null) + int(offer.item != null) + int(offer.contract != null) != 1:
			return false
		if offer.contract != null and offer.contract.accepted and (offer.contract != sim.active_contract \
				or not offer.sold or offer.contract.deposit != offer.price):
			return false
	if sim.bank.takes.size() > Sim.MAX_ECHO_CAPACITY + 1 or sim.echoes.size() > Sim.MAX_ECHO_CAPACITY \
			or sim.shop.offers.size() > Shop.OFFER_COUNT \
			or sim.shop.get("_undo_stack").size() > Shop.MAX_UNDO:
		return false
	var pending_act := BureauConfession.pending_act(sim)
	if pending_act > 0:
		var reversible := false
		for state: ShopState in sim.shop.get("_undo_stack"):
			reversible = reversible or sim.shop._before_signature(state, pending_act)
		if not reversible:
			return false
	if sim.selected_echo_uid > 0 and not uids.has(sim.selected_echo_uid):
		return false
	if sim.active_contract != null:
		var mission: Dictionary = sim.expedition.get("mission", {})
		if mission.get("kind", &"") != sim.active_contract.kind or not mission.get("state", &"") in [&"pending", &"active", &"failed"]:
			return false
	return true


func _validate_objects() -> bool:
	for object: Object in _objects:
		if object is Stats and not _stats_valid(object.values):
			return false
		if object is EchoTake:
			if object.stats == null or object.uid <= 0 or object.tint_index < 0 \
					or object.condition < 0.0 or object.condition > 100.0 \
					or object.weapons.is_empty() or object.samples.is_empty() \
					or not _loadout_valid(object.weapons, object.levels, true) \
					or not _echo_metadata_valid(object.inherited_skill, object.merge_trait) \
					or object.samples.size() > EchoArchive.MAX_SAMPLES \
					or not EchoWork.validate_actions(object.work_actions, object.duration()):
				return false
		if object is PlayerState:
			if object.stats == null or not _loadout_valid(object.weapons, object.weapon_levels) \
					or object.weapons.size() != object.cooldowns.size() \
					or not _investments_valid(object.weapon_investments, object.weapons.size()) \
					or object.materials < 0 or object.weapons.size() > Content.MAX_WEAPON_SLOTS \
					or not _items_valid(object.items) or not _sets_valid(object.set_bonus_applied):
				return false
		if object is Offer and (int(object.weapon != null) + int(object.item != null) + int(object.contract != null) != 1 \
				or object.price < 0 or object.weapon_level < 0 or object.weapon_level > WeaponDef.MAX_LEVEL \
				or (object.weapon == null and object.weapon_level != 0)):
			return false
		if object is EnemyState and (object.def == null or object.uid <= 0 or object.max_hp <= 0.0 \
				or object.speed < 0.0 or object.damage < 0.0 or object.radius <= 0.0 \
				or object.brain_time < 0.0 or object.attack_tick < 0.0 or object.pin_left < 0.0 \
				or object.ink_left < 0.0 or object.stun_left < 0.0):
			return false
		if object is EchoActor and (object.take == null or object.index < 0 or object.t < 0.0 \
				or not EchoWork.validate_actor(object)):
			return false
		if object is EchoRecorder and not _recorder_valid(object):
			return false
		if object is AnomalyContract and not _order_data_valid(object.to_dict()):
			return false
		if object is ShopState and not _undo_valid(object):
			return false
		if object is Projectile or object is AttackField:
			if object.weapon_id != &"" and Content.weapon(object.weapon_id) == null:
				return false
	return true


func _recorder_valid(recorder: EchoRecorder) -> bool:
	var accumulator: float = recorder.get("_acc")
	var elapsed: float = recorder.get("_elapsed")
	if not _bounded_number(accumulator, 0.0, EchoTake.SAMPLE_DT) or accumulator >= EchoTake.SAMPLE_DT \
			or not _bounded_number(elapsed, 0.0, float(EchoArchive.MAX_SAMPLES) * EchoTake.SAMPLE_DT) \
			or recorder.samples.size() > EchoArchive.MAX_SAMPLES \
			or not EchoWork.validate_actions(recorder.work_actions, elapsed):
		return false
	if recorder.samples.is_empty():
		return elapsed == 0.0 and accumulator == 0.0 and recorder.work_actions.is_empty()
	return absf(elapsed - (float(recorder.samples.size() - 1) * EchoTake.SAMPLE_DT + accumulator)) < 0.00001


func _stats_valid(values: Dictionary) -> bool:
	if values.size() != Stats.DEFAULTS.size():
		return false
	for key: Variant in values:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or not Stats.DEFAULTS.has(StringName(key)) \
				or typeof(values[key]) not in [TYPE_FLOAT, TYPE_INT]:
			return false
	return true


func _items_valid(values: Dictionary) -> bool:
	for key: Variant in values:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or Content.item(StringName(key)) == null \
				or typeof(values[key]) != TYPE_INT or values[key] < 0:
			return false
	return true


func _sets_valid(values: Dictionary) -> bool:
	for key: Variant in values:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or not Content.item_sets().has(StringName(key)) \
				or typeof(values[key]) != TYPE_BOOL:
			return false
	return true


func _loadout_valid(weapons: Array, levels: Array, missing_levels: bool = false) -> bool:
	if missing_levels and levels.is_empty():
		for weapon: Variant in weapons:
			if not weapon is WeaponDef or Content.weapon(weapon.id) != weapon:
				return false
		return weapons.size() <= Content.MAX_WEAPON_SLOTS
	if weapons.size() != levels.size() or weapons.size() > Content.MAX_WEAPON_SLOTS:
		return false
	for i in weapons.size():
		if not weapons[i] is WeaponDef or Content.weapon(weapons[i].id) != weapons[i] \
				or typeof(levels[i]) != TYPE_INT or levels[i] < 0 or levels[i] > WeaponDef.MAX_LEVEL:
			return false
	return true


func _investments_valid(values: Array, count: int) -> bool:
	if values.size() != count:
		return false
	for value: Variant in values:
		if typeof(value) != TYPE_INT or value < 0 or value > 1000000000:
			return false
	return true


func _echo_metadata_valid(skill: StringName, merge_trait: StringName) -> bool:
	return EchoArchive.SKILLS.has(skill) and (merge_trait == &"" or EchoBank.MERGE_TRAITS.has(merge_trait))


func _bounded_number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _role_valid(effects: Dictionary, energy: float, cooldown: float) -> bool:
	if not _bounded_number(energy, 0.0, 100.0) or not _bounded_number(cooldown, 0.0, CharacterSkills.COOLDOWN):
		return false
	var timers := {"anchor_left": 4.0, "ability_flash": 0.65, "relay_left": 0.8, "rewind_sample_left": 0.1}
	for key: Variant in effects:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return false
		if timers.has(String(key)):
			if not _bounded_number(effects[key], 0.0, timers[String(key)]):
				return false
		elif key == "anchor_uid":
			if typeof(effects[key]) != TYPE_INT or effects[key] <= 0:
				return false
		elif key == "relay_pulses":
			if typeof(effects[key]) != TYPE_INT or effects[key] < 0 or effects[key] > 3:
				return false
		elif key == "ability_kind":
			if typeof(effects[key]) != TYPE_STRING_NAME or Content.character(effects[key]) == null:
				return false
		elif String(key) == "cross_stapled":
			if typeof(effects[key]) != TYPE_BOOL:
				return false
		elif key == "rewind_history":
			if typeof(effects[key]) != TYPE_ARRAY or effects[key].size() > CharacterSkills.HISTORY_SAMPLES:
				return false
			for point: Variant in effects[key]:
				if typeof(point) != TYPE_VECTOR2 or not point.is_finite() or not WorldArena.BOUNDS.has_point(point):
					return false
		else:
			return false
	return true


func _order_data_valid(order: Dictionary) -> bool:
	if not _row_types(order, {"kind": TYPE_STRING, "deposit": TYPE_INT, "reward": TYPE_INT,
		"target": TYPE_INT, "accepted": TYPE_BOOL}):
		return false
	var kind := StringName(order.kind)
	if not AnomalyContract.KINDS.has(kind) or order.deposit < 0 or order.reward < 0 \
			or order.deposit > 1000000000 or order.reward > 1000000000:
		return false
	return order.target == {&"salvage": 3, &"audit": 2, &"repair": 1, &"rescue": 1, &"recruit": 1, &"credit": 8}[kind]


func _undo_valid(state: ShopState) -> bool:
	if state.next_echo_uid < 1 or state.selected_echo_uid < 0 or state.retire_cooldown < 0.0 \
			or state.echo_refreshes < 0 or state.rerolls < 0 or state.wave < 0 or state.phase != Sim.Phase.SHOP \
			or state.materials < 0 or Content.character(state.character_id) == null or not _story_valid(state.story_progress) \
			or state.contracts_accepted < 0 or state.contracts_completed < 0 or state.contracts_failed < 0 \
			or state.weapons.size() > Content.MAX_WEAPON_SLOTS \
			or state.echoes.size() > Sim.MAX_ECHO_CAPACITY + 1 or state.offers.size() > Shop.OFFER_COUNT \
			or state.echo_actors.size() > Sim.MAX_ECHO_CAPACITY \
			or state.weapon_change_index < -1 or state.weapon_change_index >= Content.MAX_WEAPON_SLOTS \
			or state.weapon_combine_host < -1 or state.weapon_combine_host >= Content.MAX_WEAPON_SLOTS:
		return false
	for level: int in state.weapon_levels:
		if level < 0 or level > WeaponDef.MAX_LEVEL:
			return false
	if not _stats_valid(state.stats) or not _items_valid(state.items) or not _sets_valid(state.set_bonus_applied) \
			or state.weapons.size() != state.weapon_levels.size() or state.weapons.size() != state.cooldowns.size() \
			or not _investments_valid(state.weapon_investments, state.weapons.size()) \
			or not _role_valid(state.role_effects, state.character_energy, state.character_cooldown) \
			or not Expedition.validate_plain(state.expedition, state.interactables) \
			or not _undo_bureau_valid(state) \
			or state.expedition["world"]["resolution_pending"] \
			or not SupportSystem.validate_state(state.support_units, state.next_support_uid):
		return false
	for id: StringName in state.weapons:
		if Content.weapon(id) == null:
			return false
	var echo_ids := {}
	for entry: Dictionary in state.echoes:
		if not _row_types(entry, {"samples": TYPE_PACKED_VECTOR2_ARRAY, "weapons": TYPE_PACKED_STRING_ARRAY,
			"levels": TYPE_ARRAY, "stats": TYPE_DICTIONARY, "wave": TYPE_INT, "uid": TYPE_INT,
			"condition": TYPE_FLOAT, "tint": TYPE_INT, "merged": TYPE_BOOL,
			"inherited_skill": TYPE_STRING_NAME, "merge_trait": TYPE_STRING_NAME, "archived": TYPE_BOOL, \
			"work_actions": TYPE_ARRAY}):
			return false
		if entry.uid <= 0 or echo_ids.has(entry.uid) or state.next_echo_uid <= entry.uid \
				or entry.condition < 0.0 or entry.condition > 100.0 or entry.tint < 0 or state.tint_counter <= entry.tint \
				or (not entry.levels.is_empty() and entry.weapons.size() != entry.levels.size()) \
				or entry.weapons.size() > Content.MAX_WEAPON_SLOTS or entry.samples.size() > EchoArchive.MAX_SAMPLES \
				or not _stats_valid(entry.stats) or not _echo_metadata_valid(entry.inherited_skill, entry.merge_trait) \
				or not EchoWork.validate_actions(entry.work_actions, maxf(0.0, float(entry.samples.size() - 1) * EchoTake.SAMPLE_DT)):
			return false
		echo_ids[entry.uid] = entry
		for i in entry.weapons.size():
			if Content.weapon(StringName(entry.weapons[i])) == null:
				return false
			if not entry.levels.is_empty() and (typeof(entry.levels[i]) != TYPE_INT or entry.levels[i] < 0 or entry.levels[i] > WeaponDef.MAX_LEVEL):
				return false
	if state.selected_echo_uid > 0 and not echo_ids.has(state.selected_echo_uid):
		return false
	if not _undo_world_links_valid(state, echo_ids):
		return false
	var actor_ids := {}
	for entry: Dictionary in state.echo_actors:
		if not _row_types(entry, {"uid": TYPE_INT, "index": TYPE_INT, "t": TYPE_FLOAT,
			"pos": TYPE_VECTOR2, "rewinding": TYPE_BOOL, "cooldowns": TYPE_ARRAY, \
			"work_cursor": TYPE_INT, "work_cycle": TYPE_INT}) or not echo_ids.has(entry.uid) \
				or entry.index != actor_ids.size() or entry.t < 0.0 or actor_ids.has(entry.uid) \
				or entry.cooldowns.size() > Content.MAX_WEAPON_SLOTS or entry.work_cursor < 0 or entry.work_cycle < 0:
			return false
		var take_entry: Dictionary = echo_ids[entry.uid]
		var actions: Array[Dictionary] = []
		actions.assign(take_entry.work_actions)
		if not EchoWork.validate_cursor(actions, maxf(0.0, float(take_entry.samples.size() - 1) * EchoTake.SAMPLE_DT),
				entry.t, entry.work_cursor, entry.work_cycle):
			return false
		actor_ids[entry.uid] = true
		for cooldown: Variant in entry.cooldowns:
			if typeof(cooldown) != TYPE_FLOAT:
				return false
	if not state.active_order.is_empty() and (not _order_data_valid(state.active_order) or not state.active_order.accepted):
		return false
	var active_count := 0
	for entry: Dictionary in state.offers:
		if not _row_types(entry, {"kind": TYPE_STRING, "id": TYPE_STRING_NAME, "price": TYPE_INT,
			"sold": TYPE_BOOL, "locked": TYPE_BOOL, "contract": TYPE_DICTIONARY,
			"active": TYPE_BOOL, "weapon_level": TYPE_INT}):
			return false
		if entry.price < 0 or entry.weapon_level < 0 or entry.weapon_level > WeaponDef.MAX_LEVEL:
			return false
		if entry.kind == "order":
			if not _order_data_valid(entry.contract) or entry.id != StringName("order_" + entry.contract.kind) \
					or entry.weapon_level != 0 or entry.active != entry.contract.accepted:
				return false
			if entry.active:
				active_count += 1
				if not entry.sold or state.active_order != entry.contract or entry.price != entry.contract.deposit:
					return false
		elif entry.kind in ["weapon", "item"]:
			if _content(entry.kind, entry.id) == null or not entry.contract.is_empty() or entry.active \
					or (entry.kind == "item" and entry.weapon_level != 0):
				return false
		else:
			return false
	if active_count > 1:
		return false
	if not state.active_order.is_empty():
		var mission: Dictionary = state.expedition.get("mission", {})
		if mission.get("kind", &"") != StringName(state.active_order.kind) or mission.get("state", &"") != &"pending":
			return false
	return true


func _undo_bureau_valid(state: ShopState) -> bool:
	for row: Dictionary in state.expedition["bureau"]["confessions"]:
		if row["state"] == &"active" or int(row["uid"]) >= state.next_echo_uid:
			return false
		if row["committed"]:
			if int(row["wave"]) > state.wave:
				return false
		elif int(row["wave"]) != state.wave + 1:
			return false
	return true


func _undo_world_links_valid(state: ShopState, echo_ids: Dictionary) -> bool:
	for row: Dictionary in state.expedition["bureau"]["retired"]:
		if echo_ids.has(int(row["uid"])) or int(row["uid"]) >= state.next_echo_uid:
			return false
	var world: Dictionary = state.expedition["world"]
	var staff_uid: int = world["staff_uid"]
	if staff_uid > 0 and not echo_ids.has(staff_uid):
		return false
	var active: Dictionary = {}
	for row: Dictionary in world["roster"]:
		if row["state"] == &"active":
			active = row
	for unit: Dictionary in state.support_units:
		if not SupportSystem.COMPANIONS.has(unit["kind"]):
			continue
		if active.is_empty() or int(unit["uid"]) != int(active["uid"]) \
				or unit["kind"] != StringName("recruited_" + String(active["kind"])):
			return false
		active = {}
	return active.is_empty()


func _row_types(row: Dictionary, fields: Dictionary) -> bool:
	if row.size() != fields.size():
		return false
	for name: String in fields:
		if not row.has(name) or typeof(row[name]) != fields[name]:
			return false
	return true


func _plain(value: Variant, depth: int, reason: String = "snapshot.envelope_object") -> bool:
	if depth > MAX_DEPTH or typeof(value) == TYPE_OBJECT:
		_fail(reason)
		return false
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value:
			if not _plain(key, depth + 1, reason) or not _plain(value[key], depth + 1, reason):
				return false
	if typeof(value) == TYPE_ARRAY:
		for entry: Variant in value:
			if not _plain(entry, depth + 1, reason):
				return false
	return true


func _story_valid(progress: Dictionary) -> bool:
	for key: Variant in progress:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return false
		if key == "clues":
			if typeof(progress[key]) != TYPE_ARRAY:
				return false
			for id: Variant in progress[key]:
				if typeof(id) not in [TYPE_STRING, TYPE_STRING_NAME] or not StoryLedger.ALL.has(StringName(id)):
					return false
		elif key == "receipt":
			if typeof(progress[key]) not in [TYPE_STRING, TYPE_STRING_NAME] \
					or (progress[key] != "" and not StoryLedger.ALL.has(StringName(progress[key]))):
				return false
		elif key in ["repairs", "retirements", "exhaustions", "committed_repairs"]:
			if typeof(progress[key]) != TYPE_INT or progress[key] < 0:
				return false
		elif String(key).begins_with("wave_"):
			if typeof(progress[key]) != TYPE_BOOL:
				return false
		else:
			return false
	return true


func _fill_legacy_sim(row: Dictionary) -> void:
	# Saves written before travel was part of v4 omit the key. Missing means the
	# gate had not been recorded, which is the old resume behavior. A present
	# value is the distance already walked.
	if str(row.get("type", "")) != "Sim":
		return
	var fields: Dictionary = row.fields
	if not fields.has("wave_travel"):
		fields["wave_travel"] = _encode(0.0, 0)


# Check the complete row schema and graph before any constructor runs. This
# rejects disconnected payloads and many-Sim allocation bombs at menu load.
func _prevalidate(root: Variant) -> bool:
	if typeof(root) != TYPE_DICTIONARY or root.size() != 1 or not root.has("ref") \
			or typeof(root.ref) not in [TYPE_INT, TYPE_FLOAT] or root.ref != 0:
		_fail("snapshot.invalid_reference")
		return false
	var adjacency: Array[Array] = []
	var sim_count := 0
	for row: Variant in _rows:
		if typeof(row) != TYPE_DICTIONARY or typeof(row.get("type")) != TYPE_STRING \
				or row.size() != 2 or not TYPES.has(row.type) or typeof(row.get("fields")) != TYPE_DICTIONARY:
			_fail("snapshot.unknown_type")
			return false
		if row.type == "Sim":
			sim_count += 1
			if sim_count > 1:
				_fail("snapshot.invalid_run")
				return false
		_fill_legacy_sim(row)
		var schema := _schema_fields(row.type)
		if schema.size() != row.fields.size():
			_fail("snapshot.schema")
			return false
		for info: Dictionary in schema:
			if not row.fields.has(String(info.name)):
				_fail("snapshot.schema")
				return false
		var refs: Array = []
		if not _scan_refs(row.fields, refs, 0):
			return false
		adjacency.append(refs)
	if sim_count != 1 or _rows[0].type != "Sim":
		_fail("snapshot.invalid_run")
		return false
	var seen := {0: true}
	var pending_refs: Array[int] = [0]
	var cursor := 0
	while cursor < pending_refs.size():
		var index: int = pending_refs[cursor]
		cursor += 1
		for referenced: int in adjacency[index]:
			if not seen.has(referenced):
				seen[referenced] = true
				pending_refs.append(referenced)
	if seen.size() != _rows.size():
		_fail("snapshot.invalid_reference")
		return false
	_value_count = 0
	return true


func _scan_refs(value: Variant, refs: Array, depth: int) -> bool:
	if not _budget(depth):
		return false
	if typeof(value) == TYPE_DICTIONARY:
		if value.size() == 1 and value.has("ref"):
			if typeof(value.ref) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.ref)) \
					or float(value.ref) != floor(float(value.ref)) or value.ref < 0 or value.ref >= _rows.size():
				_fail("snapshot.invalid_reference")
				return false
			refs.append(int(value.ref))
			return true
		for key: Variant in value:
			if not _scan_refs(value[key], refs, depth + 1):
				return false
	elif typeof(value) == TYPE_ARRAY:
		for entry: Variant in value:
			if not _scan_refs(entry, refs, depth + 1):
				return false
	elif typeof(value) not in [TYPE_NIL, TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		_fail("snapshot.invalid_value")
		return false
	return true
