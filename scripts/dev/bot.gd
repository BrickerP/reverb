class_name Bot
extends RefCounted

const ITEM_PRIORITY: Array[StringName] = [
	&"sharp_edge", &"quick_trigger", &"iron_heart", &"loud_speaker", &"spare_deck",
	&"regen_patch", &"long_barrel", &"lucky_coin", &"long_play", &"sneakers", &"magnet",
]
const DANGER_RADIUS := 230.0
const WALL_RADIUS := 120.0


func move_dir(sim: Sim) -> Vector2:
	var p := sim.player.pos
	var dir := Vector2.ZERO
	var threatened := false
	for e in sim.enemies:
		var off := p - e.pos
		var d := off.length()
		if d < DANGER_RADIUS and d > 0.01:
			threatened = true
			dir += off / d * pow((DANGER_RADIUS - d) / DANGER_RADIUS, 2.0) * 4.0
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
	for _i in 16:
		var best: Offer = null
		var best_score := -1.0
		for o in sim.shop.offers:
			if sim.shop.can_buy(sim, o) and _score(o, sim.player.weapons.size()) > best_score:
				best = o
				best_score = _score(o, sim.player.weapons.size())
		if best != null:
			sim.shop.buy(sim, best)
		elif rerolled < 2 and sim.player.materials >= sim.shop.reroll_cost(sim.wave) + 25:
			sim.shop.reroll(sim)
			rerolled += 1
		else:
			break
	while not sim.can_start_wave():
		sim.discard_take(sim.bank.weakest())


func _score(o: Offer, owned_weapons: int) -> float:
	if o.is_weapon():
		return (120.0 if owned_weapons < 4 else 45.0) + o.weapon.dps()
	var rank := ITEM_PRIORITY.find(o.item.id)
	return 100.0 - 5.0 * float(rank) if rank >= 0 else 10.0
