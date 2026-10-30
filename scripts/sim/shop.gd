class_name Shop
extends RefCounted

signal shop_action_resolved(result: ShopResult)
signal shop_history_changed(can_undo: bool)

const OFFER_COUNT := 6
const CATEGORY_COUNT := 2
const RESALE_RATE := 0.5
const EVOLVE_FAMILY_COUNT := 3
const MAX_UNDO := 32
const ECHO_REPAIR_AMOUNT := 40.0
const ECHO_REPAIR_PER_CONDITION := 0.25

var offers: Array[Offer] = []
var rerolls: int = 0

var _undo_stack: Array[ShopState] = []


static func price_for(base: int, wave: int) -> int:
	return ceili(float(base) * (1.0 + 0.10 * float(maxi(0, wave))))


static func weapon_price_for(w: WeaponDef, level: int, wave: int) -> int:
	return price_for(roundi(float(w.price) * pow(1.65, float(clampi(level, 0, WeaponDef.MAX_LEVEL)))), wave)


static func resale_for(sim: Sim, index: int) -> int:
	if index < 0 or index >= sim.player.weapons.size() or index >= sim.player.weapon_investments.size():
		return 0
	return floori(float(maxi(0, sim.player.weapon_investments[index])) * RESALE_RATE)


# Refitting keeps the current slot; assembling trades another equally upgraded weapon.
static func upgrade_cost(w: WeaponDef, level: int) -> int:
	return maxi(1, roundi(float(w.price) * 2.4 * pow(2.0, float(clampi(level, 0, WeaponDef.MAX_LEVEL)))))


static func combine_cost(w: WeaponDef, level: int) -> int:
	return maxi(1, ceili(float(w.price) * 0.25 * float(clampi(level, 0, WeaponDef.MAX_LEVEL) + 1)))


static func upgrade_block_reason(sim: Sim, index: int) -> StringName:
	if sim.phase != Sim.Phase.SHOP or index < 0 or index >= sim.player.weapons.size():
		return &"invalid"
	if sim.player.level_at(index) >= WeaponDef.MAX_LEVEL:
		return &"maxed"
	if sim.player.materials < upgrade_cost(sim.player.weapons[index], sim.player.level_at(index)):
		return &"poor"
	return &""


static func upgrade_weapon(sim: Sim, index: int) -> bool:
	return sim.shop.apply(ShopResult.UPGRADE, sim, null, index).ok


static func evolution_cost(w: WeaponDef) -> int:
	return maxi(10, roundi(float(w.price) * 1.5))


static func evolution_choices(sim: Sim, index: int) -> Array[StringName]:
	var choices: Array[StringName] = []
	if index < 0 or index >= sim.player.weapons.size():
		return choices
	for id: StringName in sim.player.weapons[index].evolution_options:
		if Content.weapon(id) != null and not choices.has(id):
			choices.append(id)
	return choices


static func evolution_block_reason(sim: Sim, index: int, target: StringName = &"") -> StringName:
	if sim.phase != Sim.Phase.SHOP or index < 0 or index >= sim.player.weapons.size():
		return &"invalid"
	var choices := evolution_choices(sim, index)
	if choices.is_empty():
		return &"none"
	if target == &"":
		return &"choice"
	if not choices.has(target):
		return &"branch"
	if sim.player.level_at(index) < WeaponDef.MAX_LEVEL:
		return &"level"
	if Combat.family_count(sim.player.weapons, sim.player.weapons[index].family) < EVOLVE_FAMILY_COUNT:
		return &"family"
	if sim.player.materials < evolution_cost(sim.player.weapons[index]):
		return &"poor"
	return &""


func quote_evolution(sim: Sim, index: int, target: StringName) -> ShopResult:
	return quote(ShopResult.EVOLVE, sim, null, index, target)


func evolve_choice(sim: Sim, index: int, target: StringName) -> ShopResult:
	return apply(ShopResult.EVOLVE, sim, null, index, target)


func combine_quote(sim: Sim, host: int, donor: int) -> ShopResult:
	return quote(ShopResult.COMBINE, sim, null, host, &"", donor)


func can_combine(sim: Sim, host: int, donor: int) -> bool:
	return combine_quote(sim, host, donor).ok


func combine_weapons(sim: Sim, host: int, donor: int) -> ShopResult:
	return apply(ShopResult.COMBINE, sim, null, host, &"", donor)


static func sell_block_reason(sim: Sim, index: int) -> StringName:
	if sim.phase != Sim.Phase.SHOP or index < 0 or index >= sim.player.weapons.size():
		return &"invalid"
	if sim.player.weapons.size() <= 1:
		return &"last"
	return &""


static func sell_weapon(sim: Sim, index: int) -> bool:
	return sim.shop.apply(ShopResult.SELL, sim, null, index).ok


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


func echo_repair_amount(take: EchoTake) -> float:
	return minf(ECHO_REPAIR_AMOUNT, maxf(0.0, 100.0 - take.condition)) if take != null else 0.0


func echo_repair_cost(take: EchoTake, sim: Sim = null) -> int:
	var amount := echo_repair_amount(take)
	if amount <= 0.0:
		return 0
	var cost := ceili(amount * ECHO_REPAIR_PER_CONDITION)
	if sim != null:
		if bool(sim.player.set_bonus_applied.get(&"echo", false)):
			cost = maxi(1, cost - 2)
		cost = ceili(float(cost) * (1.0 - clampf(sim.repair_discount, 0.0, 1.0)))
	return maxi(1, cost)


func echo_repair_block_reason(sim: Sim, take: EchoTake) -> StringName:
	if sim.phase != Sim.Phase.SHOP or take == null or not sim.bank.takes.has(take):
		return &"invalid"
	if echo_repair_amount(take) <= 0.0:
		return &"full"
	if sim.player.materials < echo_repair_cost(take, sim):
		return &"poor"
	return &""


func echo_repair_quote(sim: Sim, take: EchoTake) -> ShopResult:
	var reason := echo_repair_block_reason(sim, take)
	var cost := echo_repair_cost(take, sim)
	if reason != &"":
		return ShopResult.failure(ShopResult.ECHO_REPAIR, reason, cost)
	return ShopResult.success(ShopResult.ECHO_REPAIR, cost)


func repair_echo(sim: Sim, take: EchoTake) -> ShopResult:
	var quoted := echo_repair_quote(sim, take)
	if not quoted.ok:
		return quoted
	var before := ShopState.capture(sim)
	sim.player.materials -= quoted.cost
	sim.echo_refreshes += 1
	take.condition = minf(100.0, take.condition + echo_repair_amount(take))
	_push_history(before)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.ECHO_REPAIR, quoted.cost, -1, &"", before, after)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func echo_merge_quote(sim: Sim, a: EchoTake, b: EchoTake, merge_trait: StringName = &"skill") -> ShopResult:
	if sim.phase != Sim.Phase.SHOP or a == null or b == null or a == b \
			or not sim.bank.takes.has(a) or not sim.bank.takes.has(b):
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"invalid")
	if _staff_take(sim, a) or _staff_take(sim, b):
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"staff")
	if sim.bank.preview_merge(a, b, merge_trait) == null:
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"trait")
	var cost := 6 if merge_trait == &"skill" else (10 if merge_trait == &"repair" else 14)
	if sim.player.materials < cost:
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"poor", cost)
	return ShopResult.success(ShopResult.ECHO_MERGE, cost)


func discard_echo(sim: Sim, take: EchoTake) -> ShopResult:
	if sim.phase != Sim.Phase.SHOP or take == null or not sim.bank.takes.has(take):
		return ShopResult.failure(ShopResult.ECHO_DISCARD, &"invalid")
	if _staff_take(sim, take):
		return ShopResult.failure(ShopResult.ECHO_DISCARD, &"staff")
	var before := ShopState.capture(sim)
	if not sim.bank.discard(take):
		return ShopResult.failure(ShopResult.ECHO_DISCARD, &"invalid")
	_remove_shop_actor(sim, take.uid)
	if sim.selected_echo_uid == take.uid:
		sim.selected_echo_uid = sim.bank.takes[0].uid if not sim.bank.takes.is_empty() else 0
	_push_history(before)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.ECHO_DISCARD, 0, -1, &"", before, after)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func merge_echoes(sim: Sim, a: EchoTake, b: EchoTake, merge_trait: StringName = &"skill") -> ShopResult:
	var quoted := echo_merge_quote(sim, a, b, merge_trait)
	if not quoted.ok:
		return quoted
	var before := ShopState.capture(sim)
	var merged := sim.bank.merge(a, b, merge_trait)
	if merged == null:
		return ShopResult.failure(ShopResult.ECHO_MERGE, &"invalid")
	sim.player.materials -= quoted.cost
	_remove_shop_actor(sim, a.uid)
	_remove_shop_actor(sim, b.uid)
	if sim.selected_echo_uid == a.uid or sim.selected_echo_uid == b.uid:
		sim.selected_echo_uid = merged.uid
	_push_history(before)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.ECHO_MERGE, quoted.cost, -1, &"", before, after)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func _staff_take(sim: Sim, take: EchoTake) -> bool:
	return take != null and take.uid > 0 and take.uid == int(sim.expedition.get("world", {}).get("staff_uid", 0))


func _remove_shop_actor(sim: Sim, uid: int) -> void:
	for actor: EchoActor in sim.echoes.duplicate():
		if actor.take.uid == uid:
			sim.echoes.erase(actor)
	for i in sim.echoes.size():
		sim.echoes[i].index = i


func clear_history() -> void:
	if _undo_stack.is_empty():
		return
	_undo_stack.clear()
	shop_history_changed.emit(false)


func quote(action: StringName, sim: Sim, offer: Offer = null, index: int = -1,
		target: StringName = &"", donor: int = -1) -> ShopResult:
	if sim.phase != Sim.Phase.SHOP:
		return ShopResult.failure(action, &"invalid")
	match action:
		ShopResult.BUY:
			if offer == null or not offers.has(offer):
				return ShopResult.failure(action, &"invalid")
			var reason := block_reason(sim, offer)
			return _quoted(action, reason, offer.price, -1, offer.id())
		ShopResult.REPLACE_ORDER:
			if not _valid_offer(offer) or not offers.has(offer) or not offer.is_contract() or offer.sold \
					or offer.contract.accepted or not AnomalyContract.KINDS.has(offer.contract.kind) \
					or sim.active_contract == null or offer.contract == sim.active_contract:
				return ShopResult.failure(action, &"invalid")
			var cost := offer.price - sim.active_contract.deposit
			var reason := offer.contract.availability_reason(sim)
			if reason != &"":
				return ShopResult.failure(action, reason, cost)
			return _quoted(action, &"poor" if sim.player.materials < cost else &"", cost, -1, offer.id())
		ShopResult.REPLACE:
			if not _valid_offer(offer) or not offer.is_weapon() or offer.sold or not offers.has(offer) \
					or index < 0 or index >= sim.player.weapons.size():
				return ShopResult.failure(action, &"invalid")
			var net := offer.price - resale_for(sim, index)
			return _quoted(action, &"poor" if sim.player.materials < net else &"", net, index, offer.id())
		ShopResult.UPGRADE:
			var cost := upgrade_cost(sim.player.weapons[index], sim.player.level_at(index)) \
					if index >= 0 and index < sim.player.weapons.size() else 0
			return _quoted(action, upgrade_block_reason(sim, index), cost, index)
		ShopResult.COMBINE:
			if index < 0 or donor < 0 or index == donor or index >= sim.player.weapons.size() \
					or donor >= sim.player.weapons.size():
				return ShopResult.failure(action, &"invalid")
			var w := sim.player.weapons[index]
			if w.id != sim.player.weapons[donor].id or sim.player.level_at(index) != sim.player.level_at(donor):
				return ShopResult.failure(action, &"duplicate", 0, index)
			if sim.player.level_at(index) >= WeaponDef.MAX_LEVEL:
				return ShopResult.failure(action, &"maxed", 0, index)
			var cost := combine_cost(w, sim.player.level_at(index))
			var result := _quoted(action, &"poor" if sim.player.materials < cost else &"", cost, index)
			result.donor_index = donor
			return result
		ShopResult.EVOLVE:
			var cost := evolution_cost(sim.player.weapons[index]) \
					if index >= 0 and index < sim.player.weapons.size() else 0
			var result := _quoted(action, evolution_block_reason(sim, index, target), cost, index)
			result.target_id = target
			return result
		ShopResult.SELL:
			return _quoted(action, sell_block_reason(sim, index), -resale_for(sim, index), index)
		ShopResult.DEPLOY_COMPANION:
			for row: Dictionary in Expedition.crew_options(sim):
				if row["id"] != target:
					continue
				var reason := StringName(row["reason_key"]) if not row["available"] else &""
				var cost: int = row["cost"]
				if reason == &"" and sim.player.materials < cost:
					reason = &"poor"
				var result := _quoted(action, reason, cost)
				result.target_id = target
				return result
			return ShopResult.failure(action, &"invalid")
		ShopResult.PAY_DEBT:
			var debt := int(sim.expedition.get("debt", 0))
			if debt <= 0:
				return ShopResult.failure(action, &"debt_clear")
			var cost := mini(sim.player.materials, debt)
			return _quoted(action, &"poor" if cost <= 0 else &"", cost)
		ShopResult.REROLL:
			var cost := reroll_cost(sim.wave)
			return _quoted(action, &"poor" if sim.player.materials < cost else &"", cost)
		_:
			return ShopResult.failure(action, &"invalid")


func _quoted(action: StringName, reason: StringName, cost: int, index: int = -1,
		offer_id: StringName = &"") -> ShopResult:
	return ShopResult.success(action, cost, index, offer_id) if reason == &"" \
			else ShopResult.failure(action, reason, cost, index, offer_id)


func apply(action: StringName, sim: Sim, offer: Offer = null, index: int = -1,
		target: StringName = &"", donor: int = -1) -> ShopResult:
	var quoted := quote(action, sim, offer, index, target, donor)
	if not quoted.ok:
		return quoted
	if action == ShopResult.REROLL:
		reroll(sim)
		shop_action_resolved.emit(quoted)
		return quoted
	var before := ShopState.capture(sim)
	sim.player.materials -= quoted.cost
	var result_index := index
	match action:
		ShopResult.BUY, ShopResult.REPLACE_ORDER:
			if offer.is_contract():
				_purchase_order(sim, offer)
			elif offer.is_weapon():
				sim.player.add_weapon(offer.weapon)
				sim.player.weapon_levels[-1] = offer.weapon_level
				sim.player.weapon_investments[-1] = offer.price
			else:
				sim.player.add_item(offer.item)
			offer.sold = true
			offer.locked = false
		ShopResult.REPLACE:
			sim.player.weapons[index] = offer.weapon
			sim.player.weapon_levels[index] = offer.weapon_level
			sim.player.weapon_investments[index] = offer.price
			sim.player.cooldowns[index] = 0.0
			offer.sold = true
			offer.locked = false
		ShopResult.UPGRADE:
			sim.player.upgrade_weapon(index)
			sim.player.weapon_investments[index] += quoted.cost
		ShopResult.COMBINE:
			sim.player.weapon_levels[index] += 1
			sim.player.weapon_investments[index] += sim.player.weapon_investments[donor] + quoted.cost
			_remove_weapon(sim, donor)
			result_index = index - 1 if donor < index else index
			before.weapon_combine_host = index
		ShopResult.EVOLVE:
			sim.player.weapons[index] = Content.weapon(target)
			sim.player.weapon_levels[index] = WeaponDef.MAX_LEVEL
			sim.player.weapon_investments[index] += quoted.cost
			sim.player.cooldowns[index] = 0.0
		ShopResult.SELL:
			_remove_weapon(sim, index)
		ShopResult.DEPLOY_COMPANION:
			if not Expedition.assign_companion(sim, target):
				before.restore(sim)
				return ShopResult.failure(action, &"invalid", quoted.cost)
		ShopResult.PAY_DEBT:
			sim.expedition["debt"] = maxi(0, int(sim.expedition["debt"]) - quoted.cost)
	if action != ShopResult.SELL:
		sim.purchased.emit()
	var after := ShopState.capture(sim)
	if before.weapons.size() != after.weapons.size():
		before.weapon_change_index = donor if action == ShopResult.COMBINE else \
				(index if action == ShopResult.SELL else before.weapons.size())
	_push_history(before)
	var result := ShopResult.success(action, quoted.cost, result_index,
			offer.id() if offer != null else &"", before, after)
	result.target_id = target
	result.donor_index = donor
	_emit_weapon_changes(sim, before, after, action, before.weapon_change_index, before.weapon_combine_host)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func _purchase_order(sim: Sim, offer: Offer) -> void:
	var previous := sim.active_contract
	if previous != null:
		previous.accepted = false
		for old_offer in offers:
			if old_offer.contract == previous:
				old_offer.sold = false
	offer.contract.deposit = offer.price
	offer.contract.accepted = true
	sim.active_contract = offer.contract
	sim.contracts_accepted += 1
	Expedition.on_order_purchased(sim, offer.contract)


func _remove_weapon(sim: Sim, index: int) -> void:
	sim.player.weapons.remove_at(index)
	sim.player.weapon_levels.remove_at(index)
	sim.player.weapon_investments.remove_at(index)
	sim.player.cooldowns.remove_at(index)


func undo(sim: Sim) -> ShopResult:
	if sim.phase != Sim.Phase.SHOP:
		return ShopResult.failure(ShopResult.UNDO, &"invalid")
	if _undo_stack.is_empty():
		return ShopResult.failure(ShopResult.UNDO, &"empty")
	var pre := ShopState.capture(sim)
	var before: ShopState = _undo_stack.pop_back()
	before.restore(sim)
	var after := ShopState.capture(sim)
	var result := ShopResult.success(ShopResult.UNDO, 0, -1, &"", pre, after)
	_emit_weapon_changes(sim, pre, after, ShopResult.UNDO, before.weapon_change_index, before.weapon_combine_host)
	shop_action_resolved.emit(result)
	shop_history_changed.emit(can_undo())
	return result


func _emit_weapon_changes(sim: Sim, before: ShopState, after: ShopState, reason: StringName,
		changed_index: int = -1, combine_host: int = -1) -> void:
	if combine_host >= 0:
		_emit_combine_changes(sim, before, after, reason, changed_index, combine_host)
		return
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


func _emit_combine_changes(sim: Sim, before: ShopState, after: ShopState, reason: StringName,
		donor: int, host: int) -> void:
	_emit_size_change(sim, before, after, reason, donor)
	var forward := after.weapons.size() < before.weapons.size()
	var kept := host - 1 if donor < host else host
	var from_index := host if forward else kept
	var to_index := kept if forward else host
	var info := WeaponChangeInfo.new()
	info.index = to_index
	info.before_id = before.weapons[from_index]
	info.after_id = after.weapons[to_index]
	info.before_level = before.weapon_levels[from_index]
	info.after_level = after.weapon_levels[to_index]
	info.reason = reason
	info.ok = true
	sim.weapon_changed.emit(info)


func _push_history(state: ShopState) -> void:
	_undo_stack.append(state)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()


func reroll_cost(wave: int) -> int:
	return 2 + int(float(wave) * 0.5) + 2 * rerolls


func next_reroll_cost(wave: int) -> int:
	return reroll_cost(wave) + 2


func roll(sim: Sim) -> void:
	clear_history()
	rerolls = 0
	_fill(sim, locked_offer())


func can_buy(sim: Sim, offer: Offer) -> bool:
	return quote(ShopResult.BUY, sim, offer).ok


func _valid_offer(offer: Offer) -> bool:
	return offer != null and offer.price >= 0 and offer.id() != &"" and \
			int(offer.weapon != null) + int(offer.item != null) + int(offer.contract != null) == 1 and \
			offer.weapon_level >= 0 and offer.weapon_level <= WeaponDef.MAX_LEVEL and \
			(offer.is_weapon() or offer.weapon_level == 0)


func block_reason(sim: Sim, offer: Offer) -> StringName:
	if not _valid_offer(offer):
		return &"invalid"
	if offer.sold:
		return &"sold"
	if offer.is_weapon():
		if sim.player.weapons.size() >= Content.MAX_WEAPON_SLOTS:
			return &"full"
	elif offer.is_contract():
		if not AnomalyContract.KINDS.has(offer.contract.kind) or offer.contract.accepted:
			return &"invalid"
		if sim.active_contract != null:
			return &"order_active"
		var reason := offer.contract.availability_reason(sim)
		if reason != &"":
			return reason
	elif _maxed(sim, offer.item):
		return &"maxed"
	if sim.player.materials < offer.price:
		return &"poor"
	return &""


func buy(sim: Sim, offer: Offer) -> bool:
	return apply(ShopResult.BUY, sim, offer).ok


func replace_weapon(sim: Sim, offer: Offer, index: int) -> bool:
	return apply(ShopResult.REPLACE, sim, offer, index).ok


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
	var weapons := 1 if keep != null and keep.is_weapon() else 0
	var orders := 1 if keep != null and keep.is_contract() else 0
	var passives := 1 if keep != null and not keep.is_weapon() and not keep.is_contract() else 0
	while weapons < CATEGORY_COUNT:
		var offer := _weapon_offer(sim, weapons == 0)
		if offer == null:
			break
		offers.append(offer)
		weapons += 1
	while passives < CATEGORY_COUNT:
		var offer := _item_offer(sim)
		if offer == null:
			break
		offers.append(offer)
		passives += 1
	var order_ids := Expedition.offer_ids(sim)
	while orders < CATEGORY_COUNT:
		var choices: Array[StringName] = []
		for id: StringName in order_ids:
			if AnomalyContract.KINDS.has(id) and not _has(StringName("order_" + String(id))):
				choices.append(id)
		if choices.is_empty():
			break
		var offer := Offer.new()
		offer.contract = AnomalyContract.create(choices[sim.rng.randi_range(0, choices.size() - 1)], sim.wave + 1)
		offer.price = offer.contract.deposit
		offers.append(offer)
		orders += 1
	if keep != null and keep_index > 0:
		offers.remove_at(0)
		offers.insert(mini(keep_index, offers.size()), keep)


func _has(id: StringName) -> bool:
	for offer in offers:
		if offer.id() == id:
			return true
	return false


func _maxed(sim: Sim, item: ItemDef) -> bool:
	return item != null and item.max_stack > 0 and sim.player.item_count(item.id) >= item.max_stack


func _weapon_offer(sim: Sim, paired: bool = false) -> Offer:
	var pool: Array[Dictionary] = []
	if paired:
		for index in sim.player.weapons.size():
			var w := sim.player.weapons[index]
			if w.drops and w.drop_weight > 0.0 and sim.player.level_at(index) < WeaponDef.MAX_LEVEL and not _has(w.id):
				pool.append({"weapon": w, "level": sim.player.level_at(index) if sim.wave >= 5 else 0})
	if pool.is_empty():
		for w: WeaponDef in Content.weapons().values():
			if w.drops and w.drop_weight > 0.0 and not _has(w.id):
				pool.append({"weapon": w, "level": 0})
	if pool.is_empty():
		return null
	var total := 0.0
	for entry in pool:
		total += (entry["weapon"] as WeaponDef).drop_weight
	var roll_value := sim.rng.randf() * total
	var picked: Dictionary = pool.back()
	for entry in pool:
		roll_value -= (entry["weapon"] as WeaponDef).drop_weight
		if roll_value <= 0.0:
			picked = entry
			break
	var offer := Offer.new()
	offer.weapon = picked["weapon"]
	offer.weapon_level = int(picked["level"])
	offer.price = weapon_price_for(offer.weapon, offer.weapon_level, sim.wave)
	return offer


func _item_offer(sim: Sim) -> Offer:
	var pool: Array[ItemDef] = []
	for item: ItemDef in Content.items().values():
		if not _has(item.id) and not _maxed(sim, item) and (not item.echo_item or sim.echo_capacity() > 0):
			pool.append(item)
	if pool.is_empty():
		return null
	var offer := Offer.new()
	offer.item = pool[sim.rng.randi_range(0, pool.size() - 1)]
	offer.price = price_for(offer.item.price, sim.wave)
	return offer
