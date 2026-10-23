class_name Bot
extends RefCounted

const ITEM_PRIORITY: Array[StringName] = [
	&"sharp_edge", &"quick_trigger", &"iron_heart", &"loud_speaker", &"spare_deck",
	&"regen_patch", &"long_barrel", &"lucky_coin", &"long_play", &"sneakers", &"magnet",
]
const ITEM_PRIORITY_DEFENSIVE: Array[StringName] = [
	&"iron_heart", &"regen_patch", &"sneakers", &"magnet", &"sharp_edge", &"quick_trigger",
	&"long_barrel", &"lucky_coin", &"loud_speaker", &"spare_deck", &"long_play",
]
const ITEM_PRIORITY_AGGRESSIVE: Array[StringName] = [
	&"sharp_edge", &"quick_trigger", &"long_barrel", &"lucky_coin", &"loud_speaker",
	&"spare_deck", &"iron_heart", &"regen_patch", &"sneakers", &"long_play", &"magnet",
]
const DANGER_RADIUS := 230.0
const WALL_RADIUS := 120.0

var style: StringName
var upgrades: int = 0
var evolutions: int = 0


func _init(style_value: StringName = &"balanced") -> void:
	style = style_value


func _danger() -> float:
	match style:
		&"defensive":
			return 250.0
		&"aggressive":
			return 175.0
		_:
			return DANGER_RADIUS


func _priority() -> Array[StringName]:
	match style:
		&"defensive":
			return ITEM_PRIORITY_DEFENSIVE
		&"aggressive":
			return ITEM_PRIORITY_AGGRESSIVE
		_:
			return ITEM_PRIORITY


func move_dir(sim: Sim) -> Vector2:
	var p := sim.player.pos
	var dir := Vector2.ZERO
	var threatened := false
	var danger := _danger()
	for e in sim.enemies:
		var off := p - e.pos
		var d := off.length()
		if d < danger and d > 0.01:
			threatened = true
			dir += off / d * pow((danger - d) / danger, 2.0) * 4.0
	var box := Sim.ARENA
	dir += Vector2.RIGHT * clampf((WALL_RADIUS - (p.x - box.position.x)) / WALL_RADIUS, 0.0, 1.0) * 3.0
	dir += Vector2.LEFT * clampf((WALL_RADIUS - (box.end.x - p.x)) / WALL_RADIUS, 0.0, 1.0) * 3.0
	dir += Vector2.DOWN * clampf((WALL_RADIUS - (p.y - box.position.y)) / WALL_RADIUS, 0.0, 1.0) * 3.0
	dir += Vector2.UP * clampf((WALL_RADIUS - (box.end.y - p.y)) / WALL_RADIUS, 0.0, 1.0) * 3.0
	if not threatened:
		var best: Pickup = null
		for pk in sim.pickups:
			if best == null or p.distance_squared_to(pk.pos) < p.distance_squared_to(best.pos):
				best = pk
		if best != null:
			dir += (best.pos - p).normalized() * 0.8
		else:
			dir += (box.get_center() - p).normalized() * 0.3
	return dir.limit_length(1.0)


func shop(sim: Sim) -> void:
	var rerolled := 0
	var reroll_limit := 2
	var reserve := 25.0
	match style:
		&"defensive":
			reroll_limit = 3
			reserve = 40.0
		&"aggressive":
			reroll_limit = 1
			reserve = 10.0
	for _i in 16:
		var best: Offer = null
		var best_score := -1.0
		for o in sim.shop.offers:
			if sim.shop.can_buy(sim, o) and _score(o, sim) > best_score:
				best = o
				best_score = _score(o, sim)
		if best != null:
			sim.shop.buy(sim, best)
		elif rerolled < reroll_limit and sim.player.materials >= sim.shop.reroll_cost(sim.wave) + reserve:
			sim.shop.reroll(sim)
			rerolled += 1
		else:
			break
	_spend_on_weapons(sim)
	while not sim.can_start_wave():
		sim.discard_take(sim.bank.weakest())


func _spend_on_weapons(sim: Sim) -> void:
	var reserve := 0
	match style:
		&"defensive":
			reserve = 10
		&"balanced":
			reserve = 3
	# Evolve first: it is the biggest jump and resets the weapon to level 1.
	for i in sim.player.weapons.size():
		var w := sim.player.weapons[i]
		if w.evolves_to == &"" or sim.shop.evolution_block_reason(sim, i) != &"":
			continue
		if sim.player.materials >= Shop.evolution_cost(w) + reserve:
			if sim.shop.evolve_weapon(sim, i):
				evolutions += 1
	# Then spend spare materials on the best marginal DPS per material.
	if style == &"family":
		var target := _family_target(sim)
		while target >= 0 and sim.shop.upgrade_block_reason(sim, target) == &"":
			var w := sim.player.weapons[target]
			var level := sim.player.level_at(target)
			var cost := Shop.upgrade_cost(w, level)
			if sim.player.materials < cost + reserve:
				break
			if not sim.shop.upgrade_weapon(sim, target):
				break
			upgrades += 1
		return
	for _step in 20:
		var best := -1
		var best_ratio := 0.0
		for i in sim.player.weapons.size():
			if sim.shop.upgrade_block_reason(sim, i) != &"":
				continue
			var w := sim.player.weapons[i]
			var level := sim.player.level_at(i)
			var cost := Shop.upgrade_cost(w, level)
			if sim.player.materials < cost + reserve:
				continue
			var now := OfferCard.weapon_dps(w, sim.player.stats, level,
					Combat.family_damage_mult(sim.player.weapons, w.family),
					Combat.family_cooldown_mult(sim.player.weapons, w.family))
			var next := OfferCard.weapon_dps(w, sim.player.stats, level + 1,
					Combat.family_damage_mult(sim.player.weapons, w.family),
					Combat.family_cooldown_mult(sim.player.weapons, w.family))
			var ratio := (next - now) / float(maxi(1, cost))
			if ratio > best_ratio:
				best = i
				best_ratio = ratio
		if best < 0:
			break
		if sim.shop.upgrade_weapon(sim, best):
			upgrades += 1


func _score(o: Offer, sim: Sim) -> float:
	var owned_weapons := sim.player.weapons.size()
	if o.is_weapon():
		var score := 0.0
		match style:
			&"defensive":
				score = (100.0 if owned_weapons < 6 else 40.0) + o.weapon.dps() * 0.8
			&"aggressive":
				score = (150.0 if owned_weapons < 6 else 60.0) + o.weapon.dps() * 1.5
			&"family":
				score = (120.0 if owned_weapons < 4 else 45.0) + o.weapon.dps()
				if o.weapon.family == _dominant_family(sim):
					score += 80.0
			_:
				score = (120.0 if owned_weapons < 4 else 45.0) + o.weapon.dps()
		return score
	var rank: int = _priority().find(o.item.id)
	return 100.0 - 5.0 * float(rank) if rank >= 0 else 10.0


func _dominant_family(sim: Sim) -> StringName:
	var counts: Dictionary = {}
	var best: StringName = &""
	var best_count := 0
	for w in sim.player.weapons:
		var n := int(counts.get(w.family, 0)) + 1
		counts[w.family] = n
		if n > best_count:
			best = w.family
			best_count = n
	return best


func _family_target(sim: Sim) -> int:
	var family := _dominant_family(sim)
	var best := -1
	var best_level := -1
	var best_dps := -1.0
	for i in sim.player.weapons.size():
		var w := sim.player.weapons[i]
		if w.family != family:
			continue
		var level := sim.player.level_at(i)
		if level > best_level or (level == best_level and w.dps() > best_dps):
			best = i
			best_level = level
			best_dps = w.dps()
	return best
