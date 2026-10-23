class_name Sim
extends RefCounted

signal wave_started(wave: int)
signal wave_ended(wave: int)
signal run_lost
signal run_won
signal enemy_killed(pos: Vector2, color: Color, source: int)
signal enemy_hit(pos: Vector2, amount: float, crit: bool, source: int)
signal player_hurt(amount: float)
signal echo_spawned(actor: EchoActor)
signal echo_recorded(take: EchoTake)
signal shot_fired(source: int)
signal material_collected(amount: int)
signal purchased
signal explosion(pos: Vector2, radius: float, color: Color)
signal boss_spawned(enemy: EnemyState)
signal boss_defeated
signal echoes_silenced(duration: float)

enum Phase { WAVE, SHOP, LOST, WON }

const ARENA := Rect2(40.0, 80.0, 1200.0, 600.0)
const MAX_ENEMY_RADIUS := 32.0
const SPAWN_TELEGRAPH := 0.8
const IFRAME_TIME := 0.45
const WAVE_END_HEAL := 0.3
const COLLECT_RADIUS := 16.0
const MAGNET_ACCEL := 1800.0
const START_MATERIALS := 20
const INTEREST_RATE := 0.02
const INTEREST_CAP := 5
const BOSS_SILENCE_TIME := 3.0
const BOSS_SILENCE_EVERY := 8.0
const BOSS_MINION_EVERY := 10.0

var run_seed: int = 1
var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.SHOP
var wave: int = 0
var wave_time: float = 0.0
var wave_duration: float = 0.0
var kills: int = 0
var player := PlayerState.new()
var enemies: Array[EnemyState] = []
var projectiles: Array[Projectile] = []
var pickups: Array[Pickup] = []
var pending: Array[PendingSpawn] = []
var echoes: Array[EchoActor] = []
var boss: EnemyState
var echo_silenced := 0.0
var live_echo := false
var last_interest := 0
var last_wave_earned := 0
var wave_start_materials := 0
var bank := EchoBank.new()
var recorder := EchoRecorder.new()
var grid := SpatialGrid.new()
var shop := Shop.new()

var _plan: Array[SpawnEvent] = []
var _plan_idx: int = 0
var _next_uid: int = 1
var _boss_silence_cd := 0.0
var _boss_minion_cd := 0.0


func _init(seed_value: int = 1) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	player.hp = player.max_hp()
	player.materials = START_MATERIALS
	player.add_weapon(Content.weapon(Content.STARTER_WEAPON))


func start_run() -> void:
	last_interest = 0
	last_wave_earned = 0
	wave_start_materials = player.materials
	start_wave(1)


static func interest_for(materials: int) -> int:
	return mini(INTEREST_CAP, int(floor(float(maxi(0, materials)) * INTEREST_RATE)))


func echo_capacity() -> int:
	return maxi(0, int(round(player.stats.get_stat(Stats.ECHO_SLOTS))))


func echo_lifespan() -> int:
	return maxi(1, int(round(player.stats.get_stat(Stats.ECHO_LIFESPAN))))


func echo_power() -> float:
	return maxf(0.0, player.stats.get_stat(Stats.ECHO_POWER))


func echo_dps(take: EchoTake) -> float:
	if live_echo:
		var total := 0.0
		for i in player.weapons.size():
			total += player.weapons[i].level_dps(player.level_at(i))
		return total * player.stats.damage_mult() / player.stats.cooldown_mult() * echo_power()
	return take.power() * echo_power()


func can_start_wave() -> bool:
	return phase == Phase.SHOP and bank.overflow(echo_capacity()) == 0


func start_next_wave() -> void:
	if phase == Phase.SHOP:
		start_wave(wave + 1)


func start_wave(n: int) -> void:
	wave = n
	wave_time = 0.0
	wave_duration = WaveDirector.duration_for(n)
	wave_start_materials = player.materials
	last_wave_earned = 0
	last_interest = 0
	var mult := 0.35 if n == WaveDirector.FINAL_WAVE else 1.0
	_plan = WaveDirector.plan(n, run_seed, mult)
	if n == WaveDirector.FINAL_WAVE:
		var boss_event := SpawnEvent.new()
		boss_event.def = Content.enemy(&"paradox")
		boss_event.time = 1.5
		_plan.append(boss_event)
		_plan.sort_custom(func(a: SpawnEvent, b: SpawnEvent) -> bool: return a.time < b.time)
	_plan_idx = 0
	boss = null
	echo_silenced = 0.0
	_boss_silence_cd = 0.0
	_boss_minion_cd = 0.0
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	pending.clear()
	player.pos = ARENA.get_center()
	player.iframes = 0.0
	for i in player.cooldowns.size():
		player.cooldowns[i] = 0.0
	bank.trim_to(echo_capacity())
	echoes.clear()
	for i in bank.takes.size():
		var actor := EchoActor.new(bank.takes[i], i)
		echoes.append(actor)
		echo_spawned.emit(actor)
	recorder.begin(player.pos)
	phase = Phase.WAVE
	wave_started.emit(n)


func step(delta: float, move_dir: Vector2) -> void:
	if phase != Phase.WAVE:
		return
	wave_time += delta
	echo_silenced = maxf(0.0, echo_silenced - delta)
	_move_player(delta, move_dir)
	recorder.record(player.pos, delta)
	for actor in echoes:
		actor.step(delta)
	_spawn_enemies(delta)
	_move_enemies(delta)
	_boss_step(delta)
	Combat.step_weapons(self, player.pos, player.stats, player.weapons, player.weapon_levels,
			player.cooldowns, 1.0, delta, -1, Color.WHITE)
	if echo_silenced <= 0.0:
		for actor in echoes:
			if live_echo:
				_fit_echo_cooldowns(actor)
				Combat.step_weapons(self, actor.pos, player.stats, player.weapons, player.weapon_levels,
						actor.cooldowns, echo_power(), delta, actor.index, actor.take.tint())
			else:
				Combat.step_weapons(self, actor.pos, actor.take.stats, actor.take.weapons, actor.take.levels,
						actor.cooldowns, echo_power(), delta, actor.index, actor.take.tint())
	Combat.step_projectiles(self, delta)
	_update_pickups(delta)
	_compact()
	if player.hp <= 0.0:
		phase = Phase.LOST
		run_lost.emit()
	elif wave == WaveDirector.FINAL_WAVE:
		if boss != null and boss.dead:
			_end_wave()
	elif wave_time >= wave_duration:
		_end_wave()


func _fit_echo_cooldowns(actor: EchoActor) -> void:
	while actor.cooldowns.size() < player.weapons.size():
		actor.cooldowns.append(0.0)
	if actor.cooldowns.size() > player.weapons.size():
		actor.cooldowns.resize(player.weapons.size())


func _boss_step(delta: float) -> void:
	if boss == null or boss.dead:
		return
	_boss_silence_cd -= delta
	if _boss_silence_cd <= 0.0:
		_boss_silence_cd = BOSS_SILENCE_EVERY
		echo_silenced = BOSS_SILENCE_TIME
		echoes_silenced.emit(BOSS_SILENCE_TIME)
	_boss_minion_cd -= delta
	if _boss_minion_cd <= 0.0:
		_boss_minion_cd = BOSS_MINION_EVERY
		for _i in 2:
			var ps := PendingSpawn.new()
			ps.def = Content.enemy(&"runner")
			ps.pos = WaveDirector.spawn_position(ARENA, player.pos, rng)
			ps.delay = SPAWN_TELEGRAPH
			pending.append(ps)


func damage_enemy(e: EnemyState, amount: float, knock: Vector2, crit: bool, source: int = -1) -> void:
	e.hp -= amount
	e.flash = 0.09
	e.knock += knock
	enemy_hit.emit(e.pos, amount, crit, source)
	if e.hp > 0.0 or e.dead:
		return
	e.dead = true
	kills += 1
	var pk := Pickup.new()
	pk.pos = e.pos
	pk.value = e.def.drop
	pickups.append(pk)
	enemy_killed.emit(e.pos, e.def.color, source)
	if e == boss:
		boss_defeated.emit()
	if e.def.death_radius > 0.0:
		_bomber_explode(e)


func _bomber_explode(e: EnemyState) -> void:
	var radius := e.def.death_radius
	var damage := e.def.death_damage * WaveDirector.damage_scale(wave)
	explosion.emit(e.pos, radius, e.def.color)
	if player.iframes > 0.0:
		return
	if player.pos.distance_to(e.pos) <= radius + PlayerState.RADIUS:
		player.hp -= damage
		player.iframes = IFRAME_TIME
		player_hurt.emit(damage)


func discard_take(take: EchoTake) -> void:
	bank.discard(take)


func merge_takes(a: EchoTake, b: EchoTake) -> EchoTake:
	if phase != Phase.SHOP:
		return null
	return bank.merge(a, b)


func _move_player(delta: float, move_dir: Vector2) -> void:
	var dir := move_dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		player.facing = dir.normalized()
	var box := ARENA.grow(-PlayerState.RADIUS)
	player.pos += dir * player.stats.get_stat(Stats.MOVE_SPEED) * delta
	player.pos = player.pos.clamp(box.position, box.end)
	player.iframes = maxf(0.0, player.iframes - delta)
	player.hp = minf(player.max_hp(), player.hp + player.stats.get_stat(Stats.HP_REGEN) * delta)


func _spawn_enemies(delta: float) -> void:
	while _plan_idx < _plan.size() and _plan[_plan_idx].time <= wave_time:
		var ps := PendingSpawn.new()
		ps.def = _plan[_plan_idx].def
		ps.pos = WaveDirector.spawn_position(ARENA, player.pos, rng)
		ps.delay = SPAWN_TELEGRAPH
		pending.append(ps)
		_plan_idx += 1
	var keep: Array[PendingSpawn] = []
	for ps in pending:
		ps.delay -= delta
		if ps.delay > 0.0:
			keep.append(ps)
		else:
			_materialize(ps)
	pending = keep


func _materialize(ps: PendingSpawn) -> void:
	var e := EnemyState.new()
	e.uid = _next_uid
	_next_uid += 1
	e.def = ps.def
	e.pos = ps.pos
	var hp_scale := 1.0 if ps.def.is_boss else WaveDirector.hp_scale(wave)
	e.max_hp = ps.def.hp * hp_scale
	e.hp = e.max_hp
	e.speed = ps.def.speed * WaveDirector.speed_scale(wave)
	e.damage = ps.def.damage * WaveDirector.damage_scale(wave)
	e.radius = ps.def.radius
	if ps.def.is_boss:
		var pad := e.radius + 16.0
		e.pos = e.pos.clamp(ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))
	enemies.append(e)
	if ps.def.is_boss:
		boss = e
		_boss_silence_cd = 5.0
		_boss_minion_cd = 8.0
		boss_spawned.emit(e)


func _move_enemies(delta: float) -> void:
	grid.clear()
	for e in enemies:
		var to_player := player.pos - e.pos
		e.pos += to_player.normalized() * e.speed * delta + e.knock * delta
		e.knock = e.knock.move_toward(Vector2.ZERO, 900.0 * delta)
		e.flash = maxf(0.0, e.flash - delta)
		grid.insert(e)
		var touch := e.radius + PlayerState.RADIUS
		if player.iframes <= 0.0 and to_player.length_squared() <= touch * touch:
			player.hp -= e.damage
			player.iframes = IFRAME_TIME
			player_hurt.emit(e.damage)
			if e.def.silence_time > echo_silenced:
				echo_silenced = e.def.silence_time
				echoes_silenced.emit(e.def.silence_time)


func _update_pickups(delta: float) -> void:
	var pull := player.stats.get_stat(Stats.PICKUP_RANGE)
	for pk in pickups:
		var to_player := player.pos - pk.pos
		var d2 := to_player.length_squared()
		if d2 <= COLLECT_RADIUS * COLLECT_RADIUS:
			player.materials += pk.value
			material_collected.emit(pk.value)
			pk.value = 0
			continue
		if not pk.magnet and d2 <= pull * pull:
			pk.magnet = true
		if pk.magnet:
			pk.speed += MAGNET_ACCEL * delta
			pk.pos += to_player.normalized() * minf(pk.speed * delta, sqrt(d2))


func _compact() -> void:
	var w := 0
	for i in enemies.size():
		if not enemies[i].dead:
			enemies[w] = enemies[i]
			w += 1
	enemies.resize(w)
	w = 0
	for i in projectiles.size():
		if not projectiles[i].dead:
			projectiles[w] = projectiles[i]
			w += 1
	projectiles.resize(w)
	w = 0
	for i in pickups.size():
		if pickups[i].value > 0:
			pickups[w] = pickups[i]
			w += 1
	pickups.resize(w)


func _end_wave() -> void:
	echo_silenced = 0.0
	for pk in pickups:
		player.materials += pk.value
	pickups.clear()
	last_wave_earned = maxi(0, player.materials - wave_start_materials)
	last_interest = interest_for(player.materials)
	player.materials += last_interest
	enemies.clear()
	projectiles.clear()
	pending.clear()
	player.hp = minf(player.max_hp(), player.hp + player.max_hp() * WAVE_END_HEAL)
	bank.age_after_wave(echo_lifespan())
	if echo_capacity() > 0:
		var take := recorder.finish(wave, player.weapons, player.stats, player.weapon_levels)
		bank.add(take)
		echo_recorded.emit(take)
	wave_ended.emit(wave)
	if wave >= WaveDirector.FINAL_WAVE:
		phase = Phase.WON
		run_won.emit()
	else:
		phase = Phase.SHOP
		shop.roll(self)
