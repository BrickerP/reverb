class_name Shop
extends RefCounted

signal shop_action_resolved(result: ShopResult)
signal shop_history_changed(can_undo: bool)

const OFFER_COUNT := 4
const WEAPON_CHANCE := 0.4
const RESALE_RATE := 0.5
const EVOLVE_FAMILY_COUNT := 3
const MAX_UNDO := 32
const ECHO_REFRESH_BASE := 5
const ECHO_REFRESH_PER_AGE := 2

var offers: Array[Offer] = []
var rerolls: int = 0
var contract: AnomalyContract

var _undo_stack: Array[ShopState] = []


static func price_for(base: int, wave: int) -> int:
	return int(ceil(float(base) * (1.0 + 0.05 * float(wave))))


# Half of the base price, independent of the current wave's markup.
static func resale_value(w: WeaponDef) -> int:
	return maxi(1, int(floor(float(w.price) * RESALE_RATE)))


# Sum of the material actually spent to reach this upgrade level.
static func upgrade_investment(w: WeaponDef, level: int) -> int:
	var total := 0
	for l in clampi(level, 0, WeaponDef.MAX_LEVEL):
		total += upgrade_cost(w, l)
	return total


# Replacement returns the base resale plus half of the upgrade investment. This makes a
# mid-build pivot expensive but not a total loss.
static func resale_total(w: WeaponDef, level: int = 0) -> int:
	return resale_value(w) + int(floor(float(upgrade_investment(w, level)) * 0.5))


static func upgrade_cost(w: WeaponDef, level: int) -> int:
	return maxi(1, int(round(float(w.price) * (0.9 + 0.5 * float(clampi(level, 0, WeaponDef.MAX_LEVEL))))))


static func upgrade_block_reason(sim: Sim, index: int) -> StringName:
	if sim.phase != Sim.Phase.SHOP or index < 0 or index >= sim.player.weapons.size():
		return &"invalid"
	if sim.player.level_at(index) >= WeaponDef.MAX_LEVEL:
		return &"maxed"
	if sim.player.materials < upgrade_cost(sim.player.weapons[index], sim.player.level_at(index)):
		return &"poor"
	return &""


static func upgrade_weapon(sim: Sim, index: int) -> bool:
	if upgrade_block_reason(sim, index) != &"":
		return false
	var cost := upgrade_cost(sim.player.weapons[index], sim.player.level_at(index))
	sim.player.materials -= cost
	if not sim.player.upgrade_weapon(index):
		return false
	sim.purchased.emit()
	return true


static func evolution_cost(w: WeaponDef) -> int:
	return maxi(10, int(round(float(w.price) * 1.5)))


static func evolution_block_reason(sim: Sim, index: int) -> StringName:
	if sim.phase != Sim.Phase.SHOP or index < 0 or index >= sim.player.weapons.size():
		return &"invalid"
	var w := sim.player.weapons[index]
	if w.evolves_to == &"":
		return &"none"
	if sim.player.level_at(index) < WeaponDef.MAX_LEVEL:
		return &"level"
	if Combat.family_count(sim.player.weapons, w.family) < EVOLVE_FAMILY_COUNT:
		return &"family"
	if sim.player.materials < evolution_cost(w):
		return &"poor"
	return &""


static func evolve_weapon(sim: Sim, index: int) -> bool:
	if evolution_block_reason(sim, index) != &"":
		return false
	var old := sim.player.weapons[index]
	var evolved := Content.weapon(old.evolves_to)
	if evolved == null:
		return false
	sim.player.materials -= evolution_cost(old)
	sim.player.weapons[index] = evolved
	sim.player.weapon_levels[index] = 0
	sim.player.cooldowns[index] = 0.0
	sim.purchased.emit()
	return true


static func sell_block_reason(sim: Sim, index: int) -> StringName:
	if sim.phase != Sim.Phase.SHOP or index < 0 or index >= sim.player.weapons.size():
		return &"invalid"
	if sim.player.weapons.size() <= 1:
		return &"last"
	return &""


# Liquidate one weapon without needing an offer. Refunds the same base resale plus
# half of the upgrade investment as replacement, but leaves the slot empty.
static func sell_weapon(sim: Sim, index: int) -> bool:
	if sell_block_reason(sim, index) != &"":
		return false
	var w := sim.player.weapons[index]
	var refund := resale_total(w, sim.player.level_at(index))
	sim.player.materials += refund
	sim.player.weapons.remove_at(index)
	if index < sim.player.weapon_levels.size():
		sim.player.weapon_levels.remove_at(index)
	if index < sim.player.cooldowns.size():
		sim.player.cooldowns.remove_at(index)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func locked_offer() -> Offer:
	for o in offers:
		if o.locked and not o.sold:
			return o
	return null


# One free hold slot. Locking another offer moves the hold; the offer survives
# rerolls and the next shop until it is bought, unlocked or replaced.
func toggle_lock(sim: Sim, offer: Offer) -> bool:
	if sim.phase != Sim.Phase.SHOP or offer == null or not offers.has(offer) or offer.sold:
		return false
	if offer.locked:
		offer.locked = false
		return true
	var current := locked_offer()
	if current != null:
		current.locked = false
	offer.locked = true
	return true


func accept_contract(sim: Sim) -> bool:
	if sim.phase != Sim.Phase.SHOP or contract == null or contract.accepted or sim.active_contract != null:
		return false
	if sim.player.materials < contract.deposit:
		return false
	sim.player.materials -= contract.deposit
	contract.accepted = true
	sim.active_contract = contract
	return true


func echo_refresh_cost(take: EchoTake) -> int:
	if take == null:
		return 0
	return ECHO_REFRESH_BASE + ECHO_REFRESH_PER_AGE * maxi(0, take.age)


func echo_refresh_block_reason(sim: Sim, take: EchoTake) -> StringName:
	if sim.phase != Sim.Phase.SHOP or take == null or not sim.bank.takes.has(take):
		return &"invalid"
	if take.age <= 0:
		return &"new"
	if sim.player.materials < echo_refresh_cost(take):
		return &"poor"
	return &""


func refresh_echo(sim: Sim, take: EchoTake) -> ShopResult:
	var reason := echo_refresh_block_reason(sim, take)
	if reason != &"":
		return ShopResult.failure(ShopResult.ECHO_REFRESH, reason,
				echo_refresh_cost(take))
	var before := ShopState.capture(sim)
	var cost := echo_refresh_cost(take)
	sim.player.materials -= cost
	take.age -= 1
	_push_history(before)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.ECHO_REFRESH, cost, -1, &"", before, after)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func discard_echo(sim: Sim, take: EchoTake) -> ShopResult:
	if sim.phase != Sim.Phase.SHOP or take == null or not sim.bank.takes.has(take):
		return ShopResult.failure(ShopResult.ECHO_DISCARD, &"invalid")
	var before := ShopState.capture(sim)
	if not sim.bank.discard(take):
		return ShopResult.failure(ShopResult.ECHO_DISCARD, &"invalid")
	_push_history(before)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.ECHO_DISCARD, 0, -1, &"", before, after)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func merge_echoes(sim: Sim, a: EchoTake, b: EchoTake) -> ShopResult:
	if sim.phase != Sim.Phase.SHOP or a == null or b == null or a == b:
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"invalid")
	var before := ShopState.capture(sim)
	if sim.bank.merge(a, b) == null:
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"invalid")
	_push_history(before)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.ECHO_MERGE, 0, -1, &"", before, after)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func clear_history() -> void:
	if _undo_stack.is_empty():
		return
	_undo_stack.clear()
	shop_history_changed.emit(false)


func quote(action: StringName, sim: Sim, offer: Offer = null, index: int = -1) -> ShopResult:
	match action:
		ShopResult.BUY:
			if sim.phase != Sim.Phase.SHOP or offer == null or not offers.has(offer):
				return ShopResult.failure(action, &"invalid")
			var reason := block_reason(sim, offer)
			if reason != &"":
				return ShopResult.failure(action, reason, offer.price, -1, offer.id())
			return ShopResult.success(action, offer.price, -1, offer.id())
		ShopResult.REPLACE:
			if sim.phase != Sim.Phase.SHOP or offer == null or not offer.is_weapon() or offer.sold:
				return ShopResult.failure(action, &"invalid")
			if not offers.has(offer) or index < 0 or index >= sim.player.weapons.size():
				return ShopResult.failure(action, &"invalid", offer.price, index, offer.id())
			var net := offer.price - resale_total(sim.player.weapons[index],
					sim.player.level_at(index))
			if sim.player.materials + resale_total(sim.player.weapons[index],
					sim.player.level_at(index)) < offer.price:
				return ShopResult.failure(action, &"poor", net, index, offer.id())
			return ShopResult.success(action, net, index, offer.id())
		ShopResult.UPGRADE:
			var upgrade_price := 0
			if index >= 0 and index < sim.player.weapons.size():
				upgrade_price = upgrade_cost(sim.player.weapons[index], sim.player.level_at(index))
			var upgrade_reason := upgrade_block_reason(sim, index)
			if upgrade_reason != &"":
				return ShopResult.failure(action, upgrade_reason, upgrade_price, index)
			return ShopResult.success(action, upgrade_price, index)
		ShopResult.EVOLVE:
			var evolve_price := 0
			if index >= 0 and index < sim.player.weapons.size():
				evolve_price = evolution_cost(sim.player.weapons[index])
			var evolve_reason := evolution_block_reason(sim, index)
			if evolve_reason != &"":
				return ShopResult.failure(action, evolve_reason, evolve_price, index)
			return ShopResult.success(action, evolve_price, index)
		ShopResult.SELL:
			var sell_refund := 0
			if index >= 0 and index < sim.player.weapons.size():
				sell_refund = resale_total(sim.player.weapons[index], sim.player.level_at(index))
			var sell_reason := sell_block_reason(sim, index)
			if sell_reason != &"":
				return ShopResult.failure(action, sell_reason, -sell_refund, index)
			return ShopResult.success(action, -sell_refund, index)
		ShopResult.REROLL:
			if sim.phase != Sim.Phase.SHOP:
				return ShopResult.failure(action, &"invalid")
			var reroll_price := reroll_cost(sim.wave)
			if sim.player.materials < reroll_price:
				return ShopResult.failure(action, &"poor", reroll_price)
			return ShopResult.success(action, reroll_price)
		_:
			return ShopResult.failure(action, &"invalid")


func apply(action: StringName, sim: Sim, offer: Offer = null, index: int = -1) -> ShopResult:
	var quoted := quote(action, sim, offer, index)
	if not quoted.ok:
		return quoted
	if action == ShopResult.REROLL:
		if not reroll(sim):
			return ShopResult.failure(action, &"invalid", quoted.cost)
		var rerolled := ShopResult.success(action, quoted.cost)
		shop_action_resolved.emit(rerolled)
		return rerolled

	var before := ShopState.capture(sim)
	var ok := false
	match action:
		ShopResult.BUY:
			ok = buy(sim, offer)
		ShopResult.REPLACE:
			ok = replace_weapon(sim, offer, index)
		ShopResult.UPGRADE:
			ok = upgrade_weapon(sim, index)
		ShopResult.EVOLVE:
			ok = evolve_weapon(sim, index)
		ShopResult.SELL:
			ok = sell_weapon(sim, index)
	if not ok:
		return ShopResult.failure(action, &"invalid", quoted.cost, index,
				offer.id() if offer != null else &"")
	var after := ShopState.capture(sim)
	if before.weapons.size() != after.weapons.size():
		before.weapon_change_index = index if action == ShopResult.SELL else before.weapons.size()
	_push_history(before)
	var result := ShopResult.success(action, quoted.cost, index,
			offer.id() if offer != null else &"", before, after)
	_emit_weapon_changes(sim, before, after, action, before.weapon_change_index)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func undo(sim: Sim) -> ShopResult:
	if _undo_stack.is_empty():
		return ShopResult.failure(ShopResult.UNDO, &"empty")
	var pre := ShopState.capture(sim)
	var before: ShopState = _undo_stack.pop_back()
	before.restore(sim)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.UNDO, 0, -1, &"", pre, after)
	_emit_weapon_changes(sim, pre, after, ShopResult.UNDO, before.weapon_change_index)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func _emit_weapon_changes(sim: Sim, before: ShopState, after: ShopState, reason: StringName,
		changed_index: int = -1) -> void:
	if absi(before.weapons.size() - after.weapons.size()) == 1 and changed_index >= 0 \
			and changed_index < maxi(before.weapons.size(), after.weapons.size()):
		_emit_size_change(sim, before, after, reason, changed_index)
		return
	var count := maxi(before.weapons.size(), after.weapons.size())
	for i in count:
		_emit_weapon_change(sim, before, after, reason, i)


func _emit_weapon_change(sim: Sim, before: ShopState, after: ShopState, reason: StringName,
		index: int) -> void:
	var before_id: StringName = before.weapons[index] if index < before.weapons.size() else &""
	var after_id: StringName = after.weapons[index] if index < after.weapons.size() else &""
	var before_level: int = before.weapon_levels[index] if index < before.weapon_levels.size() else 0
	var after_level: int = after.weapon_levels[index] if index < after.weapon_levels.size() else 0
	if before_id == after_id and before_level == after_level:
		return
	var info := WeaponChangeInfo.new()
	info.index = index
	info.before_id = before_id
	info.after_id = after_id
	info.before_level = before_level
	info.after_level = after_level
	info.reason = reason
	info.ok = true
	sim.weapon_changed.emit(info)


func _emit_size_change(sim: Sim, before: ShopState, after: ShopState, reason: StringName,
		index: int) -> void:
	var inserting := after.weapons.size() > before.weapons.size()
	var occupied := after if inserting else before
	var level := occupied.weapon_levels[index] if index < occupied.weapon_levels.size() else 0
	var info := WeaponChangeInfo.new()
	info.index = index
	info.before_id = &"" if inserting else occupied.weapons[index]
	info.after_id = occupied.weapons[index] if inserting else &""
	info.before_level = 0 if inserting else level
	info.after_level = level if inserting else 0
	info.reason = reason
	info.ok = true
	sim.weapon_changed.emit(info)


func _push_history(state: ShopState) -> void:
	_undo_stack.append(state)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()


func reroll_cost(wave: int) -> int:
	return 2 + int(float(wave) * 0.5) + 2 * rerolls


func roll(sim: Sim) -> void:
	clear_history()
	rerolls = 0
	_fill(sim, locked_offer())
	contract = AnomalyContract.make(sim.wave + 1, sim.rng, sim.endless)


func can_buy(sim: Sim, o: Offer) -> bool:
	return sim.phase == Sim.Phase.SHOP and block_reason(sim, o) == &""


func block_reason(sim: Sim, o: Offer) -> StringName:
	if o.sold:
		return &"sold"
	if o.is_weapon():
		if sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS:
			return &"full"
	elif _maxed(sim, o.item):
		return &"maxed"
	if sim.player.materials < o.price:
		return &"poor"
	return &""


func buy(sim: Sim, o: Offer) -> bool:
	if not can_buy(sim, o):
		return false
	sim.player.materials -= o.price
	if o.is_weapon():
		sim.player.add_weapon(o.weapon)
	else:
		sim.player.add_item(o.item)
	o.sold = true
	sim.purchased.emit()
	return true


# Swap a weapon in place: pay the offer, minus half the old weapon's base price.
func replace_weapon(sim: Sim, o: Offer, index: int) -> bool:
	if sim.phase != Sim.Phase.SHOP or o == null or not o.is_weapon() or o.sold:
		return false
	if not offers.has(o) or index < 0 or index >= sim.player.weapons.size():
		return false
	var old := sim.player.weapons[index]
	var resale := resale_total(old, sim.player.level_at(index))
	if sim.player.materials + resale < o.price:
		return false
	sim.player.materials += resale - o.price
	sim.player.weapons[index] = o.weapon
	sim.player.cooldowns[index] = 0.0
	while sim.player.weapon_levels.size() <= index:
		sim.player.weapon_levels.append(0)
	sim.player.weapon_levels[index] = 0
	o.sold = true
	sim.purchased.emit()
	return true


func reroll(sim: Sim) -> bool:
	var cost := reroll_cost(sim.wave)
	if sim.phase != Sim.Phase.SHOP or sim.player.materials < cost:
		return false
	sim.player.materials -= cost
	rerolls += 1
	_fill(sim, locked_offer())
	clear_history()
	return true


func _fill(sim: Sim, keep: Offer = null) -> void:
	var keep_index := offers.find(keep) if keep != null else -1
	offers.clear()
	if keep != null:
		keep.sold = false
		keep.locked = true
		offers.append(keep)
	var tries := 0
	while offers.size() < OFFER_COUNT and tries < 80:
		tries += 1
		var o := _random_offer(sim)
		if o != null and not _has(o.id()):
			offers.append(o)
	if keep != null and keep_index > 0:
		offers.remove_at(0)
		offers.insert(mini(keep_index, offers.size()), keep)


func _has(id: StringName) -> bool:
	for o in offers:
		if o.id() == id:
			return true
	return false


func _maxed(sim: Sim, it: ItemDef) -> bool:
	return it.max_stack > 0 and sim.player.item_count(it.id) >= it.max_stack


func _random_offer(sim: Sim) -> Offer:
	var o := Offer.new()
	var weapons_open := sim.player.weapons.size() < Content.MAX_WEAPON_SLOTS
	if weapons_open and sim.rng.randf() < WEAPON_CHANCE:
		var wdefs: Array[WeaponDef] = []
		var total := 0.0
		for w: WeaponDef in Content.weapons().values():
			if w.drops and w.drop_weight > 0.0:
				wdefs.append(w)
				total += w.drop_weight
		if not wdefs.is_empty() and total > 0.0:
			var roll := sim.rng.randf() * total
			var picked := wdefs[wdefs.size() - 1]
			for w in wdefs:
				roll -= w.drop_weight
				if roll <= 0.0:
					picked = w
					break
			o.weapon = picked
			o.price = price_for(picked.price, sim.wave)
			return o
	var idefs := Content.items().values()
	var it: ItemDef = idefs[sim.rng.randi_range(0, idefs.size() - 1)]
	if it.echo_item and sim.echo_capacity() <= 0:
		return null
	if _maxed(sim, it):
		return null
	o.item = it
	o.price = price_for(it.price, sim.wave)
	return o
