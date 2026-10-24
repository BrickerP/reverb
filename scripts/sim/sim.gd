class_name Sim
extends RefCounted

signal wave_started(wave: int)
signal wave_ended(wave: int)
signal run_lost
signal run_won
signal enemy_killed(pos: Vector2, color: Color, source: int)
signal enemy_hit(pos: Vector2, amount: float, crit: bool, source: int)
signal player_hurt(amount: float)
signal player_hurt_info(info: PlayerHurtInfo)
signal echo_spawned(actor: EchoActor)
signal echo_recorded(take: EchoTake)
signal shot_fired(source: int)
signal shot_fired_info(info: ShotInfo)
signal damage_event(info: DamageInfo)
signal explosion_info(info: ExplosionInfo)
signal weapon_changed(info: WeaponChangeInfo)
signal material_collected(amount: int)
signal purchased
signal explosion(pos: Vector2, radius: float, color: Color)
signal boss_spawned(enemy: EnemyState)
signal boss_phase_changed(phase: int)
signal boss_shard_spawned(enemy: EnemyState)
signal boss_shard_defeated(enemy: EnemyState, remaining: int)
signal boss_enraged(enemy: EnemyState)
signal boss_defeated
signal echoes_silenced(duration: float)
signal rift_spawned(rift: TemporalRift)
signal rift_activated(rift: TemporalRift)
signal rift_ended(rift: TemporalRift)

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
const BOSS_PHASE2_HP_RATIO := 0.5
const BOSS_PHASE2_SILENCE := 2.0
const BOSS_PHASE2_SPLIT_SHARE := 0.5
const BOSS_PHASE2_SHARD_SPEED := 0.86
const BOSS_ENRAGE_SPEED := 1.30
const BOSS_ENRAGE_DAMAGE := 1.20
const ELITE_HP_MULT := 1.7
const ELITE_SPEED_MULT := 1.08
const ELITE_DAMAGE_MULT := 1.15
const ELITE_RADIUS_MULT := 1.12
const ELITE_DROP_MULT := 2
const ELITE_OVERCLOCK_SPEED := 1.30
const ELITE_OVERCLOCK_DAMAGE := 1.10
const ELITE_BULWARK_ARC := 120.0
const ELITE_BULWARK_REDUCTION := 0.25
const ELITE_VOLATILE_RADIUS := 64.0
const ELITE_VOLATILE_DAMAGE := 6.0
const RIFT_START_WAVE := 12
const RIFT_FIRST_DELAY := 8.0
const RIFT_INTERVAL := 16.0
const RIFT_DAMAGE_BASE := 3.0
const RIFT_DAMAGE_PER_WAVE := 0.15

var run_seed: int = 1
var rng := RandomNumberGenerator.new()
var hazard_rng := RandomNumberGenerator.new()
var phase: Phase = Phase.SHOP
var wave: int = 0
var wave_time: float = 0.0
var wave_duration: float = 0.0
var kills: int = 0
# Compatibility marker for the rift path; anomaly-contract accounting is excluded.
var wave_damage_taken: bool = false
var player := PlayerState.new()
var enemies: Array[EnemyState] = []
var projectiles: Array[Projectile] = []
var pickups: Array[Pickup] = []
var pending: Array[PendingSpawn] = []
var echoes: Array[EchoActor] = []
var rifts: Array[TemporalRift] = []
var boss: EnemyState
var boss_phase: int = 1
var boss_shards: Array[EnemyState] = []
var boss_original_max_hp: float = 0.0
var echo_silenced := 0.0
var live_echo := false
var synergy_damage_per_echo := 0.0
var synergy_haste_per_echo := 0.0
var last_interest := 0
var last_wave_earned := 0
var wave_start_materials := 0
var last_damage_source: StringName = &""
var shot_sequence := 0
var bank := EchoBank.new()
var recorder := EchoRecorder.new()
var grid := SpatialGrid.new()
var shop := Shop.new()

var _plan: Array[SpawnEvent] = []
var _plan_idx: int = 0
var _next_uid: int = 1
var _boss_silence_cd := 0.0
var _boss_minion_cd := 0.0
var _boss_enraged := false
var _rift_cd := 0.0


func _init(seed_value: int = 1) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	hazard_rng.seed = seed_value * 7919 + 17
	player.hp = player.max_hp()
	player.materials = START_MATERIALS
	player.add_weapon(Content.weapon(Content.STARTER_WEAPON))


func start_run() -> void:
	last_interest = 0
	last_wave_earned = 0
	wave_start_materials = player.materials
	last_damage_source = &""
	shot_sequence = 0
	start_wave(1)


static func interest_for(materials: int) -> int:
	return mini(INTEREST_CAP, int(floor(float(maxi(0, materials)) * INTEREST_RATE)))


func echo_capacity() -> int:
	return maxi(0, int(round(player.stats.get_stat(Stats.ECHO_SLOTS))))


func echo_lifespan() -> int:
	return maxi(1, int(round(player.stats.get_stat(Stats.ECHO_LIFESPAN))))


func echo_power() -> float:
	var power := player.stats.get_stat(Stats.ECHO_POWER)
	if Combat.family_count(player.weapons, &"arcane") >= 4:
		power += Combat.FAMILY_MASTERY_ARCANE_ECHO
	return maxf(0.0, power)


# Boss UI reads these instead of assuming a single EnemyState. Phase 1 has one
# shard; phase 2 keeps the same remaining health but splits it across two bodies.
func boss_total_count() -> int:
	return boss_shards.size()


func boss_alive_count() -> int:
	var alive := 0
	for e in boss_shards:
		if not e.dead:
			alive += 1
	return alive


func boss_health_ratio() -> float:
	if boss == null or boss_original_max_hp <= 0.0:
		return 0.0
	var total := 0.0
	for e in boss_shards:
		if not e.dead:
			total += maxf(0.0, e.hp)
	return clampf(total / boss_original_max_hp, 0.0, 1.0)


func boss_origin() -> Vector2:
	for e in boss_shards:
		if not e.dead:
			return e.pos
	if boss != null:
		return boss.pos
	return ARENA.get_center()


func synergy_damage_mult() -> float:
	return 1.0 + synergy_damage_per_echo * float(echoes.size())


func synergy_cooldown_mult() -> float:
	return 1.0 / (1.0 + synergy_haste_per_echo * float(echoes.size()))


func echo_dps(take: EchoTake) -> float:
	var damage := synergy_damage_mult()
	var cooldown := synergy_cooldown_mult()
	if live_echo:
		var total := 0.0
		for i in player.weapons.size():
			total += player.weapons[i].level_dps(player.level_at(i))
		return total * player.stats.damage_mult() / player.stats.cooldown_mult() * echo_power() * damage / cooldown
	return take.power() * echo_power() * damage / cooldown


func can_start_wave() -> bool:
	return phase == Phase.SHOP and bank.overflow(echo_capacity()) == 0


func start_next_wave() -> void:
	if phase == Phase.SHOP:
		start_wave(wave + 1)


func start_wave(n: int) -> void:
	wave_damage_taken = false
	rifts.clear()
	_rift_cd = RIFT_FIRST_DELAY if n >= RIFT_START_WAVE and n < WaveDirector.FINAL_WAVE else 0.0
	wave = n
	wave_time = 0.0
	wave_duration = WaveDirector.duration_for(n)
	shop.clear_history()
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
	boss_phase = 1
	boss_shards.clear()
	boss_original_max_hp = 0.0
	_boss_enraged = false
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
	_step_rifts(delta)
	Combat.step_weapons(self, player.pos, player.stats, player.weapons, player.weapon_levels,
			player.cooldowns, 1.0, delta, -1, Color.WHITE, synergy_damage_mult(), synergy_cooldown_mult())
	if echo_silenced <= 0.0:
		for actor in echoes:
			if live_echo:
				_fit_echo_cooldowns(actor)
				Combat.step_weapons(self, actor.pos, player.stats, player.weapons, player.weapon_levels,
						actor.cooldowns, echo_power(), delta, actor.index, actor.take.tint(),
						synergy_damage_mult(), synergy_cooldown_mult())
			else:
				Combat.step_weapons(self, actor.pos, actor.take.stats, actor.take.weapons, actor.take.levels,
						actor.cooldowns, echo_power(), delta, actor.index, actor.take.tint(),
						synergy_damage_mult(), synergy_cooldown_mult())
	Combat.step_projectiles(self, delta)
	_update_pickups(delta)
	_compact()
	if player.hp <= 0.0:
		phase = Phase.LOST
		run_lost.emit()
	elif wave == WaveDirector.FINAL_WAVE:
		if boss != null and boss_alive_count() == 0:
			_end_wave()
	elif wave_time >= wave_duration:
		_end_wave()


func _fit_echo_cooldowns(actor: EchoActor) -> void:
	while actor.cooldowns.size() < player.weapons.size():
		actor.cooldowns.append(0.0)
	if actor.cooldowns.size() > player.weapons.size():
		actor.cooldowns.resize(player.weapons.size())


func _boss_step(delta: float) -> void:
	var controller := _alive_boss()
	if controller == null:
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


func _alive_boss() -> EnemyState:
	for e in boss_shards:
		if not e.dead:
			return e
	return null


func damage_enemy(e: EnemyState, amount: float, knock: Vector2, crit: bool, source: int = -1,
		hit_dir: Vector2 = Vector2.ZERO, weapon_id: StringName = &"", effect: StringName = &"hit") -> void:
	var actual := amount
	var reduced := false
	var shield_arc := e.shield_arc_value()
	if shield_arc > 0.0 and hit_dir != Vector2.ZERO:
		var front := (player.pos - e.pos).normalized()
		if (-hit_dir.normalized()).dot(front) >= cos(deg_to_rad(shield_arc * 0.5)):
			actual *= 1.0 - clampf(e.shield_reduction_value(), 0.0, 1.0)
			reduced = true
	e.hp -= actual
	e.flash = 0.09
	e.knock += knock
	enemy_hit.emit(e.pos, actual, crit, source)
	var info := DamageInfo.new()
	info.source = source
	info.weapon_id = weapon_id
	info.target_uid = e.uid
	info.pos = e.pos
	info.amount = actual
	info.crit = crit
	info.reduced = reduced
	info.hit_dir = hit_dir
	info.effect = effect
	damage_event.emit(info)
	if e == boss and boss_phase == 1 and e.hp > 0.0 and e.hp <= e.max_hp * BOSS_PHASE2_HP_RATIO:
		_begin_boss_phase2()
	if e.hp > 0.0 or e.dead:
		return
	e.dead = true
	kills += 1
	var pk := Pickup.new()
	pk.pos = e.pos
	pk.value = e.def.drop * e.drop_mult
	pickups.append(pk)
	enemy_killed.emit(e.pos, e.def.color, source)
	if boss_shards.has(e):
		_handle_boss_shard_death(e)
	if e.death_radius_value() > 0.0:
		_bomber_explode(e)


func _begin_boss_phase2() -> void:
	if boss == null or boss_phase != 1:
		return
	boss_phase = 2
	var remaining := boss.hp
	var shard_hp := remaining * BOSS_PHASE2_SPLIT_SHARE
	boss.hp = shard_hp
	boss.max_hp = shard_hp
	boss.flash = 0.18
	var shard := EnemyState.new()
	shard.uid = _next_uid
	_next_uid += 1
	shard.def = boss.def
	shard.max_hp = shard_hp
	shard.hp = shard_hp
	shard.speed = boss.speed * BOSS_PHASE2_SHARD_SPEED
	shard.damage = boss.damage
	shard.radius = boss.radius
	shard.flash = 0.18
	var center := ARENA.get_center()
	shard.pos = center * 2.0 - boss.pos
	var pad := shard.radius + 16.0
	shard.pos = shard.pos.clamp(ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))
	if shard.pos.distance_to(player.pos) < 140.0:
		var away := (shard.pos - player.pos).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		shard.pos = (player.pos + away * 180.0).clamp(
				ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))
	boss_shards.append(shard)
	enemies.append(shard)
	echo_silenced = maxf(echo_silenced, BOSS_PHASE2_SILENCE)
	echoes_silenced.emit(echo_silenced)
	boss_phase_changed.emit(2)
	boss_shard_spawned.emit(shard)


func _handle_boss_shard_death(e: EnemyState) -> void:
	var remaining := boss_alive_count()
	boss_shard_defeated.emit(e, remaining)
	if remaining <= 0:
		boss_defeated.emit()
	elif remaining == 1:
		_enrage_boss()


func _enrage_boss() -> void:
	if _boss_enraged:
		return
	var survivor := _alive_boss()
	if survivor == null:
		return
	_boss_enraged = true
	survivor.speed *= BOSS_ENRAGE_SPEED
	survivor.damage *= BOSS_ENRAGE_DAMAGE
	survivor.flash = 0.25
	boss_enraged.emit(survivor)


func _bomber_explode(e: EnemyState) -> void:
	var radius := e.death_radius_value()
	var damage := e.death_damage_value() * WaveDirector.damage_scale(wave)
	explosion.emit(e.pos, radius, e.def.color)
	var info := ExplosionInfo.new()
	info.kind = ExplosionInfo.BOMBER
	info.pos = e.pos
	info.radius = radius
	info.color = e.def.color
	info.effect = &"bomber_explosion"
	explosion_info.emit(info)
	if player.iframes > 0.0:
		return
	if player.pos.distance_to(e.pos) <= radius + PlayerState.RADIUS:
		var was_alive := player.hp > 0.0
		player.hp -= damage
		player.iframes = IFRAME_TIME
		if was_alive:
			last_damage_source = e.def.id
		player_hurt.emit(damage)
		var hurt := PlayerHurtInfo.new()
		hurt.source = e.def.id
		hurt.amount = damage
		hurt.pos = player.pos
		hurt.direction = (player.pos - e.pos).normalized()
		hurt.effect = &"bomber_explosion"
		hurt.lethal = was_alive and player.hp <= 0.0
		player_hurt_info.emit(hurt)


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
		ps.elite_kind = _plan[_plan_idx].elite_kind
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


func _apply_elite(e: EnemyState, kind: StringName) -> void:
	e.elite = true
	e.elite_kind = kind
	e.max_hp *= ELITE_HP_MULT
	e.hp = e.max_hp
	e.speed *= ELITE_SPEED_MULT
	e.damage *= ELITE_DAMAGE_MULT
	e.radius *= ELITE_RADIUS_MULT
	e.drop_mult = ELITE_DROP_MULT
	match kind:
		&"overclocked":
			e.speed *= ELITE_OVERCLOCK_SPEED
			e.damage *= ELITE_OVERCLOCK_DAMAGE
		&"bulwark":
			e.shield_arc_override = ELITE_BULWARK_ARC
			e.shield_reduction_override = ELITE_BULWARK_REDUCTION
		&"volatile":
			e.death_radius_override = ELITE_VOLATILE_RADIUS
			e.death_damage_override = ELITE_VOLATILE_DAMAGE


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
	if ps.elite_kind != &"":
		_apply_elite(e, ps.elite_kind)
	if ps.def.is_boss:
		var pad := e.radius + 16.0
		e.pos = e.pos.clamp(ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))
	enemies.append(e)
	if ps.def.is_boss:
		boss = e
		boss_phase = 1
		boss_original_max_hp = e.max_hp
		boss_shards.clear()
		boss_shards.append(e)
		_boss_enraged = false
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
			var was_alive := player.hp > 0.0
			player.hp -= e.damage
			player.iframes = IFRAME_TIME
			if was_alive:
				last_damage_source = e.def.id
			player_hurt.emit(e.damage)
			var hurt := PlayerHurtInfo.new()
			hurt.source = e.def.id
			hurt.amount = e.damage
			hurt.pos = player.pos
			hurt.direction = (player.pos - e.pos).normalized()
			hurt.effect = &"contact"
			hurt.lethal = was_alive and player.hp <= 0.0
			player_hurt_info.emit(hurt)
			if e.def.silence_time > echo_silenced:
				echo_silenced = e.def.silence_time
				echoes_silenced.emit(e.def.silence_time)
	_separate_boss_shards()


func _separate_boss_shards() -> void:
	if boss_phase != 2 or boss_shards.size() < 2:
		return
	var alive: Array[EnemyState] = []
	for e in boss_shards:
		if not e.dead:
			alive.append(e)
	if alive.size() < 2:
		return
	var a := alive[0]
	var b := alive[1]
	var offset := a.pos - b.pos
	var min_distance := (a.radius + b.radius) * 0.85
	if offset.length() >= min_distance or offset == Vector2.ZERO:
		return
	var push := offset.normalized() * (min_distance - offset.length()) * 0.5
	var pad := a.radius + 16.0
	a.pos = (a.pos + push).clamp(ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))
	b.pos = (b.pos - push).clamp(ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))


func _step_rifts(delta: float) -> void:
	for r in rifts:
		if r.telegraph > 0.0:
			r.telegraph = maxf(0.0, r.telegraph - delta)
			if r.telegraph <= 0.0:
				r.active = TemporalRift.ACTIVE_TIME
				r.tick = TemporalRift.TICK_TIME
				rift_activated.emit(r)
			continue
		if r.active <= 0.0:
			continue
		r.active -= delta
		r.tick -= delta
		if r.tick <= 0.0:
			r.tick += TemporalRift.TICK_TIME
			_damage_rift(r)
		if r.active <= 0.0:
			rift_ended.emit(r)
	var kept: Array[TemporalRift] = []
	for r in rifts:
		if r.telegraph > 0.0 or r.active > 0.0:
			kept.append(r)
	rifts = kept
	if wave >= RIFT_START_WAVE and wave < WaveDirector.FINAL_WAVE:
		_rift_cd -= delta
		if _rift_cd <= 0.0:
			_spawn_rift()
			_rift_cd = RIFT_INTERVAL


func _spawn_rift() -> void:
	var pad := TemporalRift.RADIUS + 20.0
	var offset := Vector2.from_angle(hazard_rng.randf() * TAU) * hazard_rng.randf_range(0.0, 70.0)
	var pos := (player.pos + offset).clamp(
			ARENA.position + Vector2(pad, pad), ARENA.end - Vector2(pad, pad))
	var r := TemporalRift.new()
	r.pos = pos
	r.radius = TemporalRift.RADIUS
	rifts.append(r)
	rift_spawned.emit(r)


func _damage_rift(r: TemporalRift) -> void:
	if player.pos.distance_to(r.pos) > r.radius + PlayerState.RADIUS:
		return
	var damage := RIFT_DAMAGE_BASE + RIFT_DAMAGE_PER_WAVE * float(wave)
	wave_damage_taken = true
	var was_alive := player.hp > 0.0
	player.hp -= damage
	if was_alive:
		last_damage_source = &"rift"
	player_hurt.emit(damage)
	var hurt := PlayerHurtInfo.new()
	hurt.source = &"rift"
	hurt.amount = damage
	hurt.pos = player.pos
	hurt.direction = Vector2.ZERO
	hurt.effect = &"rift"
	hurt.lethal = was_alive and player.hp <= 0.0
	player_hurt_info.emit(hurt)


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
	rifts.clear()
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
