class_name Shop
extends RefCounted

const OFFER_COUNT := 4
const WEAPON_CHANCE := 0.4
const RESALE_RATE := 0.5

var offers: Array[Offer] = []
var rerolls: int = 0


static func price_for(base: int, wave: int) -> int:
	return int(ceil(float(base) * (1.0 + 0.05 * float(wave))))


# Half of the base price, independent of the current wave's markup.
static func resale_value(w: WeaponDef) -> int:
	return maxi(1, int(floor(float(w.price) * RESALE_RATE)))


func reroll_cost(wave: int) -> int:
	return 2 + int(float(wave) * 0.5) + 2 * rerolls


func roll(sim: Sim) -> void:
	rerolls = 0
	_fill(sim)


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
	return true


# Swap a weapon in place: pay the offer, minus half the old weapon's base price.
func replace_weapon(sim: Sim, o: Offer, index: int) -> bool:
	if sim.phase != Sim.Phase.SHOP or o == null or not o.is_weapon() or o.sold:
		return false
	if not offers.has(o) or index < 0 or index >= sim.player.weapons.size():
		return false
	var old := sim.player.weapons[index]
	var resale := resale_value(old)
	if sim.player.materials + resale < o.price:
		return false
	sim.player.materials += resale - o.price
	sim.player.weapons[index] = o.weapon
	sim.player.cooldowns[index] = 0.0
	o.sold = true
	return true


func reroll(sim: Sim) -> bool:
	var cost := reroll_cost(sim.wave)
	if sim.phase != Sim.Phase.SHOP or sim.player.materials < cost:
		return false
	sim.player.materials -= cost
	rerolls += 1
	_fill(sim)
	return true


func _fill(sim: Sim) -> void:
	offers.clear()
	var tries := 0
	while offers.size() < OFFER_COUNT and tries < 80:
		tries += 1
		var o := _random_offer(sim)
		if o != null and not _has(o.id()):
			offers.append(o)


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
		var wdefs := Content.weapons().values()
		var w: WeaponDef = wdefs[sim.rng.randi_range(0, wdefs.size() - 1)]
		o.weapon = w
		o.price = price_for(w.price, sim.wave)
		return o
	var idefs := Content.items().values()
	var it: ItemDef = idefs[sim.rng.randi_range(0, idefs.size() - 1)]
	if _maxed(sim, it):
		return null
	o.item = it
	o.price = price_for(it.price, sim.wave)
	return o
