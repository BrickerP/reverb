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
	for o in sim.shop.offers:
		state.offers.append({
			"kind": "weapon" if o.is_weapon() else "item",
			"id": o.id(),
			"price": o.price,
			"sold": o.sold,
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
	sim.shop.offers.clear()
	for entry: Dictionary in offers:
		var o := Offer.new()
		if str(entry.get("kind", "")) == "weapon":
			o.weapon = Content.weapon(StringName(str(entry.get("id", ""))))
		else:
			o.item = Content.item(StringName(str(entry.get("id", ""))))
		o.price = int(entry.get("price", 0))
		o.sold = bool(entry.get("sold", false))
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
		"items": items.duplicate(),
		"offers": offer_rows,
		"rerolls": rerolls,
		"phase": phase,
		"wave": wave,
	}
