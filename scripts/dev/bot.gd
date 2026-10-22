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
			if sim.shop.can_buy(sim, o) and _score(o, sim.player.weapons.size()) > best_score:
				best = o
				best_score = _score(o, sim.player.weapons.size())
		if best != null:
			sim.shop.buy(sim, best)
		elif rerolled < reroll_limit and sim.player.materials >= sim.shop.reroll_cost(sim.wave) + reserve:
			sim.shop.reroll(sim)
			rerolled += 1
		else:
			break
	while not sim.can_start_wave():
		sim.discard_take(sim.bank.weakest())


func _score(o: Offer, owned_weapons: int) -> float:
	if o.is_weapon():
		match style:
			&"defensive":
				return (100.0 if owned_weapons < 6 else 40.0) + o.weapon.dps() * 0.8
			&"aggressive":
				return (150.0 if owned_weapons < 6 else 60.0) + o.weapon.dps() * 1.5
			_:
				return (120.0 if owned_weapons < 4 else 45.0) + o.weapon.dps()
	var rank: int = _priority().find(o.item.id)
	return 100.0 - 5.0 * float(rank) if rank >= 0 else 10.0
