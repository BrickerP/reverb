class_name ShopState
extends RefCounted

# Exact equipment/shop snapshot for one undo step. It intentionally does not include the
# RNG stream: equipment actions do not reroll, and undo must never reroll.
var materials: int = 0
var hp: float = 0.0
var stats: Dictionary = {}
var weapons: Array[StringName] = []
var weapon_levels: Array[int] = []
var cooldowns: Array[float] = []
var items: Dictionary = {}
var set_bonus_applied: Dictionary = {}
var echoes: Array[Dictionary] = []
var tint_counter: int = 0
var next_echo_uid: int = 1
var selected_echo_uid: int = 0
var retire_cooldown: float = 0.0
var echo_refreshes: int = 0
var echo_actors: Array[Dictionary] = []
var offers: Array[Dictionary] = []
var rerolls: int = 0
var phase: int = 0
var wave: int = 0
# Presentation-event annotation for the action following this snapshot. It is not
# simulation state and is intentionally excluded from restore() and to_dict().
var weapon_change_index: int = -1


static func capture(sim: Sim) -> ShopState:
	var state := ShopState.new()
	state.materials = sim.player.materials
	state.hp = sim.player.hp
	state.stats = sim.player.stats.values.duplicate()
	for w in sim.player.weapons:
		state.weapons.append(w.id)
	state.weapon_levels = sim.player.weapon_levels.duplicate()
	state.cooldowns = sim.player.cooldowns.duplicate()
	state.items = sim.player.items.duplicate()
	state.set_bonus_applied = sim.player.set_bonus_applied.duplicate()
	for take in sim.bank.takes:
		var weapons_out := PackedStringArray()
		for w in take.weapons:
			weapons_out.append(String(w.id))
		state.echoes.append({
			"samples": take.samples.duplicate(),
			"weapons": weapons_out,
			"levels": take.levels.duplicate(),
			"stats": take.stats.values.duplicate(),
			"wave": take.wave,
			"uid": take.uid,
			"condition": take.condition,
			"tint": take.tint_index,
			"merged": take.merged,
		})
	state.tint_counter = sim.bank.tint_counter()
	state.next_echo_uid = sim.bank.next_uid()
	state.selected_echo_uid = sim.selected_echo_uid
	state.retire_cooldown = sim.retire_cooldown
	state.echo_refreshes = sim.echo_refreshes
	for actor in sim.echoes:
		state.echo_actors.append({"uid": actor.take.uid, "index": actor.index,
			"t": actor.t, "pos": actor.pos, "rewinding": actor.rewinding,
			"cooldowns": actor.cooldowns.duplicate()})
	for o in sim.shop.offers:
		state.offers.append({
			"kind": "weapon" if o.is_weapon() else "item",
			"id": o.id(),
			"price": o.price,
			"sold": o.sold,
			"locked": o.locked,
		})
	state.rerolls = sim.shop.rerolls
	state.phase = int(sim.phase)
	state.wave = sim.wave
	return state


func restore(sim: Sim) -> void:
	sim.player.materials = materials
	sim.player.hp = hp
	sim.player.stats.values = stats.duplicate()
	sim.player.weapons.clear()
	sim.player.weapon_levels = weapon_levels.duplicate()
	sim.player.cooldowns = cooldowns.duplicate()
	for id in weapons:
		var w := Content.weapon(id)
		if w != null:
			sim.player.weapons.append(w)
	sim.player.items = items.duplicate()
	sim.player.set_bonus_applied = set_bonus_applied.duplicate()
	sim.bank.takes.clear()
	var max_tint := -1
	for entry: Dictionary in echoes:
		var take := EchoTake.new()
		take.samples = (entry.get("samples", PackedVector2Array()) as PackedVector2Array).duplicate()
		for id: Variant in entry.get("weapons", []):
			take.weapons.append(Content.weapon(StringName(str(id))))
		for level: Variant in entry.get("levels", []):
			take.levels.append(int(level))
		while take.levels.size() < take.weapons.size():
			take.levels.append(0)
		take.stats = Stats.new()
		take.stats.values = (entry.get("stats", {}) as Dictionary).duplicate()
		take.wave = int(entry.get("wave", 0))
		take.uid = int(entry["uid"])
		take.condition = float(entry["condition"])
		take.tint_index = int(entry.get("tint", 0))
		take.merged = bool(entry.get("merged", false))
		max_tint = maxi(max_tint, take.tint_index)
		sim.bank.takes.append(take)
	sim.bank.set_tint_counter(maxi(tint_counter, max_tint + 1))
	sim.bank.set_next_uid(next_echo_uid)
	sim.selected_echo_uid = selected_echo_uid
	sim.retire_cooldown = retire_cooldown
	sim.echo_refreshes = echo_refreshes
	sim.echoes.clear()
	for entry in echo_actors:
		var take := sim.bank.find_uid(int(entry["uid"]))
		if take == null:
			continue
		var actor := EchoActor.new(take, int(entry["index"]))
		actor.t = float(entry["t"])
		actor.pos = entry["pos"]
		actor.rewinding = bool(entry["rewinding"])
		actor.cooldowns.assign(entry["cooldowns"])
		sim.echoes.append(actor)
	sim.shop.offers.clear()
	for entry: Dictionary in offers:
		var o := Offer.new()
		if str(entry.get("kind", "")) == "weapon":
			o.weapon = Content.weapon(StringName(str(entry.get("id", ""))))
		else:
			o.item = Content.item(StringName(str(entry.get("id", ""))))
		o.price = int(entry.get("price", 0))
		o.sold = bool(entry.get("sold", false))
		o.locked = bool(entry.get("locked", false))
		sim.shop.offers.append(o)
	sim.shop.rerolls = rerolls
	sim.phase = phase as Sim.Phase
	sim.wave = wave


func to_dict() -> Dictionary:
	var weapon_ids := PackedStringArray()
	for id in weapons:
		weapon_ids.append(String(id))
	var offer_rows: Array[Dictionary] = []
	for entry: Dictionary in offers:
		offer_rows.append(entry.duplicate())
	return {
		"materials": materials,
		"hp": hp,
		"stats": stats.duplicate(),
		"weapons": weapon_ids,
		"weapon_levels": weapon_levels.duplicate(),
		"cooldowns": cooldowns.duplicate(),
		"items": items.duplicate(),
		"set_bonus_applied": set_bonus_applied.duplicate(),
		"echoes": echoes.duplicate(true),
		"tint_counter": tint_counter,
		"next_echo_uid": next_echo_uid,
		"selected_echo_uid": selected_echo_uid,
		"retire_cooldown": retire_cooldown,
		"echo_refreshes": echo_refreshes,
		"echo_actors": echo_actors.duplicate(true),
		"offers": offer_rows,
		"rerolls": rerolls,
		"phase": phase,
		"wave": wave,
	}
