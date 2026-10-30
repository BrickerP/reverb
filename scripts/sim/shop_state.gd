class_name ShopState
extends RefCounted

# Exact equipment/shop snapshot for one undo step. It intentionally does not include the
# RNG stream: equipment actions do not reroll, and undo must never reroll.
var materials: int = 0
var hp: float = 0.0
var stats: Dictionary = {}
var weapons: Array[StringName] = []
var weapon_levels: Array[int] = []
var weapon_investments: Array[int] = []
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
var active_order: Dictionary = {}
var contracts_accepted: int = 0
var contracts_completed: int = 0
var contracts_failed: int = 0
var expedition: Dictionary = {}
var story_progress: Dictionary = {}
var character_id: StringName = &""
var character_energy: float = 0.0
var character_cooldown: float = 0.0
var role_effects: Dictionary = {}
var support_units: Array[Dictionary] = []
var next_support_uid: int = 1
var interactables: Array[Dictionary] = []
var shield: float = 0.0
var phase: int = 0
var wave: int = 0
# Presentation-event annotation for the action following this snapshot. It is not
# simulation state and is intentionally excluded from restore() and to_dict().
var weapon_change_index: int = -1
var weapon_combine_host: int = -1


static func capture(sim: Sim) -> ShopState:
	var state := ShopState.new()
	state.materials = sim.player.materials
	state.hp = sim.player.hp
	state.stats = sim.player.stats.values.duplicate()
	for w in sim.player.weapons:
		state.weapons.append(w.id)
	state.weapon_levels = sim.player.weapon_levels.duplicate()
	state.weapon_investments = sim.player.weapon_investments.duplicate()
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
			"inherited_skill": take.inherited_skill,
			"merge_trait": take.merge_trait,
			"archived": take.archived,
			"work_actions": take.work_actions.duplicate(true),
		})
	state.tint_counter = sim.bank.tint_counter()
	state.next_echo_uid = sim.bank.next_uid()
	state.selected_echo_uid = sim.selected_echo_uid
	state.retire_cooldown = sim.retire_cooldown
	state.echo_refreshes = sim.echo_refreshes
	for actor in sim.echoes:
		state.echo_actors.append({"uid": actor.take.uid, "index": actor.index,
			"t": actor.t, "pos": actor.pos, "rewinding": actor.rewinding,
			"cooldowns": actor.cooldowns.duplicate(),
			"work_cursor": actor.work_cursor, "work_cycle": actor.work_cycle})
	for o in sim.shop.offers:
		state.offers.append({
			"kind": "weapon" if o.is_weapon() else ("order" if o.is_contract() else "item"),
			"contract": o.contract.to_dict() if o.is_contract() else {},
			"active": o.is_contract() and o.contract == sim.active_contract,
			"id": o.id(),
			"price": o.price,
			"weapon_level": o.weapon_level,
			"sold": o.sold,
			"locked": o.locked,
		})
	state.rerolls = sim.shop.rerolls
	state.active_order = sim.active_contract.to_dict() if sim.active_contract != null else {}
	state.contracts_accepted = sim.contracts_accepted
	state.contracts_completed = sim.contracts_completed
	state.contracts_failed = sim.contracts_failed
	state.expedition = sim.expedition.duplicate(true)
	state.story_progress = sim.story_progress.duplicate(true)
	state.character_id = sim.character_id
	state.character_energy = sim.character_energy
	state.character_cooldown = sim.character_cooldown
	state.role_effects = sim.role_effects.duplicate(true)
	state.support_units.assign(sim.support_units.duplicate(true))
	state.next_support_uid = sim._next_support_uid
	state.interactables.assign(sim.interactables.duplicate(true))
	state.shield = sim.player.shield
	state.phase = int(sim.phase)
	state.wave = sim.wave
	return state


func restore(sim: Sim) -> void:
	sim.player.materials = materials
	sim.player.hp = hp
	sim.player.stats.values = stats.duplicate()
	sim.player.weapons.clear()
	sim.player.weapon_levels = weapon_levels.duplicate()
	sim.player.weapon_investments = weapon_investments.duplicate()
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
		take.stats = Stats.new()
		take.stats.values = (entry.get("stats", {}) as Dictionary).duplicate()
		take.wave = int(entry.get("wave", 0))
		take.uid = int(entry["uid"])
		take.condition = float(entry["condition"])
		take.tint_index = int(entry.get("tint", 0))
		take.merged = bool(entry.get("merged", false))
		take.inherited_skill = StringName(str(entry.get("inherited_skill", "")))
		take.merge_trait = StringName(str(entry.get("merge_trait", "")))
		take.archived = bool(entry.get("archived", false))
		take.work_actions.assign(entry["work_actions"].duplicate(true))
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
		actor.work_cursor = int(entry["work_cursor"])
		actor.work_cycle = int(entry["work_cycle"])
		sim.echoes.append(actor)
	sim.active_contract = AnomalyContract.from_dict(active_order) if not active_order.is_empty() else null
	sim.shop.offers.clear()
	for entry: Dictionary in offers:
		var o := Offer.new()
		if str(entry.get("kind", "")) == "weapon":
			o.weapon = Content.weapon(StringName(str(entry.get("id", ""))))
		elif str(entry.get("kind", "")) == "order":
			o.contract = AnomalyContract.from_dict(entry.get("contract", {}))
			if bool(entry.get("active", false)):
				sim.active_contract = o.contract
		else:
			o.item = Content.item(StringName(str(entry.get("id", ""))))
		o.price = int(entry.get("price", 0))
		o.weapon_level = int(entry.get("weapon_level", 0))
		o.sold = bool(entry.get("sold", false))
		o.locked = bool(entry.get("locked", false))
		sim.shop.offers.append(o)
	sim.shop.rerolls = rerolls
	sim.contracts_accepted = contracts_accepted
	sim.contracts_completed = contracts_completed
	sim.contracts_failed = contracts_failed
	sim.expedition = expedition.duplicate(true)
	sim.story_progress = story_progress.duplicate(true)
	sim.character_id = character_id
	sim.character_energy = character_energy
	sim.character_cooldown = character_cooldown
	sim.role_effects = role_effects.duplicate(true)
	sim.support_units.assign(support_units.duplicate(true))
	sim._next_support_uid = next_support_uid
	sim.interactables.assign(interactables.duplicate(true))
	sim.player.shield = shield
	sim.phase = phase as Sim.Phase
	sim.wave = wave


func to_dict() -> Dictionary:
	var weapon_ids := PackedStringArray()
	for id in weapons:
		weapon_ids.append(String(id))
	var offer_rows: Array[Dictionary] = []
	for entry: Dictionary in offers:
		offer_rows.append(entry.duplicate(true))
	return {
		"materials": materials,
		"hp": hp,
		"stats": stats.duplicate(),
		"weapons": weapon_ids,
		"weapon_levels": weapon_levels.duplicate(),
		"weapon_investments": weapon_investments.duplicate(),
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
		"active_order": active_order.duplicate(true),
		"contracts_accepted": contracts_accepted,
		"contracts_completed": contracts_completed,
		"contracts_failed": contracts_failed,
		"expedition": expedition.duplicate(true),
		"story_progress": story_progress.duplicate(true),
		"character_id": String(character_id),
		"character_energy": character_energy,
		"character_cooldown": character_cooldown,
		"role_effects": role_effects.duplicate(true),
		"support_units": support_units.duplicate(true),
		"next_support_uid": next_support_uid,
		"interactables": interactables.duplicate(true),
		"shield": shield,
		"phase": phase,
		"wave": wave,
	}
