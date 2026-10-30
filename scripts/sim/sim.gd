class_name Sim
extends RefCounted

signal wave_started(wave: int)
signal wave_ended(wave: int)
signal run_lost
signal run_won
signal enemy_killed(info: EnemyDeathInfo)
signal enemy_hit(pos: Vector2, amount: float, crit: bool, source: int)
signal player_hurt(amount: float)
signal player_hurt_info(info: PlayerHurtInfo)
signal echo_spawned(actor: EchoActor)
signal echo_retired(info: EchoRetirementInfo)
signal combo_triggered(info: ComboInfo)
signal shot_fired(source: int)
signal shot_fired_info(info: ShotInfo)
signal damage_event(info: DamageInfo)
signal explosion_info(info: ExplosionInfo)
signal weapon_changed(info: WeaponChangeInfo)
signal material_collected(amount: int)
signal support_event(info: Dictionary)
signal world_event(info: Dictionary)
signal echo_work_performed(info: Dictionary)
signal purchased
signal explosion(pos: Vector2, radius: float, color: Color)
signal boss_spawned(enemy: EnemyState)
signal boss_phase_changed(phase: int)
signal boss_shard_spawned(enemy: EnemyState)
signal boss_shard_defeated(enemy: EnemyState, remaining: int)
signal boss_enraged(enemy: EnemyState)
signal boss_defeated
signal echoes_silenced(info: EchoSilenceInfo)
signal contract_resolved(contract: AnomalyContract, success: bool, reward: int)
signal rift_spawned(rift: TemporalRift)
signal rift_activated(rift: TemporalRift)
signal rift_ended(rift: TemporalRift)

enum Phase { WAVE, SHOP, LOST, WON, RESOLUTION }

const ARENA := WorldArena.BOUNDS
const VIEWPORT := WorldArena.VIEWPORT
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
const ELITE_SPLIT_SHARE := 0.22
const ELITE_SPLIT_DAMAGE := 0.55
const ELITE_SPLIT_SPEED := 0.90
const RIFT_START_WAVE := 6
const RIFT_FIRST_DELAY := 8.0
const RIFT_INTERVAL := 16.0
const RIFT_DAMAGE_BASE := 3.0
const RIFT_DAMAGE_PER_WAVE := 0.15
const BOSS_RUSH_SOLO_SHIELD := 10.0
const FIELD_SHIELD_BURST_RADIUS := 72.0
const FIELD_SHIELD_BURST_DAMAGE := 8.0
const FIELD_SHIELD_BURST_KNOCK := 90.0
const MAX_ECHO_CAPACITY := 8
const MAX_ENEMIES := 96
const BOSS_RESERVED_SLOTS := 2
const MAX_ORDINARY_ENEMIES := MAX_ENEMIES - BOSS_RESERVED_SLOTS
const MAX_PENDING := 24

var run_seed: int = 1
var rng := RandomNumberGenerator.new()
var hazard_rng := RandomNumberGenerator.new()
var endless: bool = false
var boss_rush: bool = false
var ascension: int = 0
var daily_modifier: StringName = &""
var phase: Phase = Phase.SHOP
var wave: int = 0
var wave_time: float = 0.0
var wave_duration: float = 0.0
var kills: int = 0
var wave_kills: int = 0
var wave_elite_kills: int = 0
var wave_damage_taken: bool = false
var active_contract: AnomalyContract
var pending_boons: Array[StringName] = []
var boons_taken: Array[StringName] = []
var boon_rerolls: int = 0
var boss_rush_bonus_boon := false
var echo_refreshes: int = 0
var last_contract_done: bool = false
var last_contract_success: bool = false
var last_contract_reward: int = 0
var contracts_accepted: int = 0
var contracts_completed: int = 0
var contracts_failed: int = 0
var character_id: StringName = &"looper"
var character_energy: float = 100.0
var character_cooldown: float = 0.0
var role_effects: Dictionary = {}
var support_units: Array[Dictionary] = []
var _next_support_uid: int = 1
var interactables: Array[Dictionary] = []
var expedition: Dictionary = {}
var player := PlayerState.new()
var enemies: Array[EnemyState] = []
var projectiles: Array[Projectile] = []
var pickups: Array[Pickup] = []
var pending: Array[PendingSpawn] = []
var echoes: Array[EchoActor] = []
var rifts: Array[TemporalRift] = []
var selected_echo_uid: int = 0
var retire_cooldown: float = 0.0
var retirements: int = 0
var wave_retirements: int = 0
var repair_discount: float = 0.0
var wear_rate_mult: float = 1.0
var retirement_mult: float = 1.0
var pickup_repair: float = 0.0
var story_progress: Dictionary = {}
var attack_fields: Array[AttackField] = []
var enemy_zones: Array[EnemyZone] = []
var boss: EnemyState
var boss_phase: int = 1
var boss_shards: Array[EnemyState] = []
var boss_original_max_hp: float = 0.0
var echo_silenced := 0.0
var live_echo := false
var synergy_damage_per_echo := 0.0
var synergy_haste_per_echo := 0.0
var second_wind_charges := 0
var last_interest := 0
var last_wave_earned := 0
var wave_start_materials := 0
var last_damage_source: StringName = &""
var shot_sequence := 0
var player_shots := 0
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
var _supply_spawned := false
var supply_claims := 0


func _init(seed_value: int = 1) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	hazard_rng.seed = seed_value * 7919 + 17
	player.hp = player.max_hp()
	player.materials = START_MATERIALS
	player.add_weapon(Content.weapon(Content.STARTER_WEAPON))
	echo_retired.connect(_on_echo_retired)
	shot_fired_info.connect(_record_signature)


func start_run() -> void:
	Expedition.initialize(self)
	support_units.clear()
	interactables.clear()
	_next_support_uid = 1
	character_energy = 100.0
	character_cooldown = 0.0
	role_effects.clear()
	endless = false
	boss_rush = false
	second_wind_charges = 0
	boons_taken.clear()
	boon_rerolls = 0
	boss_rush_bonus_boon = false
	echo_refreshes = 0
	contracts_accepted = 0
	contracts_completed = 0
	contracts_failed = 0
	player_shots = 0
	DailyAnomaly.apply_start(self)
	last_interest = 0
	last_wave_earned = 0
	wave_start_materials = player.materials
	last_damage_source = &""
	shot_sequence = 0
	start_wave(1)


static func interest_for(materials: int) -> int:
	return mini(INTEREST_CAP, int(floor(float(maxi(0, materials)) * INTEREST_RATE)))


func echo_capacity() -> int:
	return mini(MAX_ECHO_CAPACITY, maxi(0, int(round(player.stats.get_stat(Stats.ECHO_SLOTS)))))


func echo_duration() -> float:
	return maxf(10.0, player.stats.get_stat(Stats.ECHO_DURATION))


func material_drop_multiplier() -> float:
	return DailyAnomaly.FORTUNE_DROP_MULT if daily_modifier == DailyAnomaly.FORTUNE else 1.0


func wave_budget_multiplier() -> float:
	return DailyAnomaly.HORDE_BUDGET_MULT if daily_modifier == DailyAnomaly.HORDE else 1.0


func daily_enemy_speed_multiplier() -> float:
	return DailyAnomaly.OVERCLOCK_SPEED if daily_modifier == DailyAnomaly.OVERCLOCK else 1.0


func daily_enemy_damage_multiplier() -> float:
	return DailyAnomaly.OVERCLOCK_DAMAGE if daily_modifier == DailyAnomaly.OVERCLOCK else 1.0


func echo_power() -> float:
	var power := player.stats.get_stat(Stats.ECHO_POWER)
	if daily_modifier == DailyAnomaly.ECHO_SURGE:
		power += DailyAnomaly.ECHO_BONUS
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


# Every fourth encounter concludes an act with a mandatory boss.
func is_boss_wave(n: int = wave) -> bool:
	if not endless:
		return n > 0 and n <= WaveDirector.FINAL_WAVE and n % 4 == 0
	return n > WaveDirector.FINAL_WAVE and n % 4 == 0


func ascension_elite_count() -> int:
	if daily_modifier == DailyAnomaly.TWIN_HUNT:
		return 2
	return 2 if ascension >= 3 else 1


func ascension_rift_wave() -> int:
	if daily_modifier == DailyAnomaly.RIFTFALL or daily_modifier == DailyAnomaly.RIFTSTORM:
		return DailyAnomaly.RIFT_WAVE
	return 5 if ascension >= 2 else RIFT_START_WAVE


func ascension_rift_interval() -> float:
	if daily_modifier == DailyAnomaly.RIFTSTORM:
		return DailyAnomaly.RIFTSTORM_INTERVAL
	if daily_modifier == DailyAnomaly.RIFTFALL:
		return DailyAnomaly.RIFT_INTERVAL
	return 14.0 if ascension >= 2 else RIFT_INTERVAL


func next_wave_number() -> int:
	return wave + (4 if boss_rush else 1)


func start_next_wave() -> void:
	if phase == Phase.SHOP:
		start_wave(next_wave_number())


func begin_endless() -> bool:
	if phase != Phase.WON or endless:
		return false
	endless = true
	boss_rush = false
	wave = WaveDirector.FINAL_WAVE
	phase = Phase.SHOP
	boss_shards.clear()
	rifts.clear()
	shop.roll(self)
	return true


func begin_boss_rush() -> bool:
	if phase != Phase.WON or endless:
		return false
	endless = true
	boss_rush = true
	wave = WaveDirector.FINAL_WAVE
	phase = Phase.SHOP
	boss_shards.clear()
	rifts.clear()
	boss_rush_bonus_boon = echo_capacity() <= 0
	if boss_rush_bonus_boon:
		player.stats.add(Stats.SHIELD, BOSS_RUSH_SOLO_SHIELD)
		player.shield = player.max_shield()
	shop.roll(self)
	boon_rerolls = 0
	pending_boons = Boon.roll(rng, 3, self)
	return true


func start_wave(n: int) -> void:
	wave = n
	wave_time = 0.0
	wave_duration = WaveDirector.duration_for(n)
	wave_kills = 0
	wave_elite_kills = 0
	wave_damage_taken = false
	last_contract_done = false
	last_contract_success = false
	last_contract_reward = 0
	_supply_spawned = false
	wave_retirements = 0
	retire_cooldown = 0.0
	attack_fields.clear()
	enemy_zones.clear()
	rifts.clear()
	_rift_cd = RIFT_FIRST_DELAY if n >= ascension_rift_wave() and not is_boss_wave(n) else 0.0
	shop.clear_history()
	wave_start_materials = player.materials
	last_wave_earned = 0
	last_interest = 0
	var boss_wave := is_boss_wave(n)
	var mult := 0.35 if boss_wave and not endless else (0.55 if boss_wave else 1.0)
	mult *= wave_budget_multiplier()
	_plan = WaveDirector.plan(n, run_seed, mult, endless, ascension_elite_count())
	if boss_wave:
		var boss_event := SpawnEvent.new()
		boss_event.def = Content.enemy(Expedition.boss_id(self))
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
	player.pos = ARENA.get_center() if n == 1 or player.pos == Vector2.ZERO else WorldArena.move_body(player.pos, Vector2.ZERO, PlayerState.RADIUS)
	Expedition.begin_wave(self)
	player.shield = player.max_shield()
	player.iframes = 0.0
	for i in player.cooldowns.size():
		player.cooldowns[i] = 0.0
	var staff_uid := int(expedition.get("world", {}).get("staff_uid", 0))
	var staff := bank.find_uid(staff_uid)
	if staff != null:
		bank.takes.erase(staff)
	bank.trim_to(maxi(0, echo_capacity() - (1 if staff != null else 0)))
	if staff != null:
		bank.takes.append(staff)
	echoes.clear()
	for i in bank.takes.size():
		if bank.takes[i].uid == staff_uid:
			continue
		var actor := EchoActor.new(bank.takes[i], i)
		echoes.append(actor)
		echo_spawned.emit(actor)
	recorder.begin(player.pos)
	phase = Phase.WAVE
	EchoSystem.ensure_selection(self)
	_commit_repair_story()
	wave_started.emit(n)


func step(delta: float, move_dir: Vector2) -> void:
	if phase != Phase.WAVE or Expedition.is_negotiating(self):
		return
	if delta <= 0.0 or not is_finite(delta):
		return
	wave_time += delta
	CharacterSkills.step(self, delta)
	Expedition.step(self, delta)
	echo_silenced = maxf(0.0, echo_silenced - delta)
	_move_player(delta, move_dir)
	recorder.record(player.pos, delta)
	EchoSystem.step(self, delta)
	_spawn_enemies(delta)
	_step_tail_pressure(delta)
	_step_supply()
	_move_enemies(delta)
	_boss_step(delta)
	_step_rifts(delta)
	Combat.step_weapons(self, player.pos, player.stats, player.weapons, player.weapon_levels,
			player.cooldowns, 1.0, delta, -1, Color.WHITE, synergy_damage_mult(), synergy_cooldown_mult())
	if echo_silenced <= 0.0:
		for actor in echoes:
			if EnemyBrain.echo_is_sealed(self, actor.pos):
				continue
			if live_echo:
				_fit_echo_cooldowns(actor)
				Combat.step_weapons(self, actor.pos, player.stats, player.weapons, player.weapon_levels,
						actor.cooldowns, echo_power(), delta, actor.index, actor.take.tint(),
						synergy_damage_mult(), synergy_cooldown_mult(), actor.take.uid)
			else:
				Combat.step_weapons(self, actor.pos, actor.take.stats, actor.take.weapons, actor.take.levels,
						actor.cooldowns, echo_power(), delta, actor.index, actor.take.tint(),
						synergy_damage_mult(), synergy_cooldown_mult(), actor.take.uid)
	Combat.step_projectiles(self, delta)
	Combat.tick_fields(self, delta)
	_update_pickups(delta)
	SupportSystem.step(self, delta)
	Expedition.sync_roster(self)
	_compact()
	if player.hp <= 0.0:
		phase = Phase.LOST
		run_lost.emit()
	elif is_boss_wave():
		if boss != null and boss_alive_count() == 0:
			_end_wave()
	elif boss != null and boss_alive_count() == 0 and expedition.get("mission", {}).get("kind", &"") == &"recruit":
		_end_wave()
	elif wave_time >= wave_duration and not Expedition.is_negotiating(self):
		var mission: Dictionary = expedition.get("mission", {})
		if mission.get("kind", &"") != &"recruit" or boss == null or boss_alive_count() == 0:
			_end_wave()


func _fit_echo_cooldowns(actor: EchoActor) -> void:
	while actor.cooldowns.size() < player.weapons.size():
		actor.cooldowns.append(0.0)
	if actor.cooldowns.size() > player.weapons.size():
		actor.cooldowns.resize(player.weapons.size())


func _emit_echo_silence(duration: float, enemy: EnemyState, kind: StringName) -> void:
	var info := EchoSilenceInfo.new()
	info.duration = duration
	info.kind = kind
	if enemy != null:
		info.source_uid = enemy.uid
		info.pos = enemy.pos
		if enemy.def != null:
			info.enemy_id = enemy.def.id
	echoes_silenced.emit(info)


func _boss_step(delta: float) -> void:
	var controller := _alive_boss()
	if controller == null or controller.def.id != &"paradox" or Expedition.is_negotiating(self):
		return
	if boss_phase == 1 and boss.hp > 0.0 and boss.hp <= boss.max_hp * BOSS_PHASE2_HP_RATIO:
		_begin_boss_phase2()
	_boss_silence_cd -= delta
	if _boss_silence_cd <= 0.0:
		_boss_silence_cd = BOSS_SILENCE_EVERY
		echo_silenced = BOSS_SILENCE_TIME
		_emit_echo_silence(BOSS_SILENCE_TIME, controller, EchoSilenceInfo.BOSS)
	_boss_minion_cd -= delta
	if _boss_minion_cd <= 0.0:
		_boss_minion_cd = BOSS_MINION_EVERY
		for _i in 2:
			var ps := PendingSpawn.new()
			ps.def = Content.enemy(&"runner")
			ps.pos = WaveDirector.spawn_position(ARENA, player.pos, rng)
			ps.delay = SPAWN_TELEGRAPH
			queue_spawn(ps)


func _alive_boss() -> EnemyState:
	for e in boss_shards:
		if not e.dead:
			return e
	return null


func damage_enemy(e: EnemyState, amount: float, knock: Vector2, crit: bool, source: int = -1,
		hit_dir: Vector2 = Vector2.ZERO, weapon_id: StringName = &"", effect: StringName = &"hit",
		actor_token: int = -1, source_tint: Color = Color.WHITE) -> void:
	if e == null or e.dead or e.brain_state == &"defeated" or not is_finite(amount) or amount <= 0.0:
		return
	var actual := amount
	var reduced := false
	var shield_arc := e.shield_arc_value()
	if shield_arc > 0.0 and hit_dir != Vector2.ZERO:
		var front := e.attack_direction if e.def.id == &"warden" else (player.pos - e.pos).normalized()
		if (-hit_dir.normalized()).dot(front) >= cos(deg_to_rad(shield_arc * 0.5)):
			actual *= 1.0 - clampf(e.shield_reduction_value(), 0.0, 1.0)
			reduced = true
	e.hp -= actual
	e.flash = 0.09
	e.knock += knock if knock.is_finite() else Vector2.ZERO
	enemy_hit.emit(e.pos, actual, crit, source)
	var info := DamageInfo.new()
	info.source = source
	info.actor_token = actor_token
	info.source_tint = source_tint
	info.weapon_id = weapon_id
	info.target_uid = e.uid
	info.pos = e.pos
	info.amount = actual
	info.crit = crit
	info.reduced = reduced
	info.hit_dir = hit_dir
	info.effect = effect
	damage_event.emit(info)
	if e == boss and e.def.id == &"paradox" and boss_phase == 1 and e.hp > 0.0 and e.hp <= e.max_hp * BOSS_PHASE2_HP_RATIO:
		_begin_boss_phase2()
	if e.hp > 0.0 or e.dead:
		return
	if Expedition.try_negotiate(self, e):
		return
	_finalize_enemy_death(e, source, actor_token, source_tint, weapon_id, hit_dir, effect)


func _finalize_enemy_death(e: EnemyState, source: int = -1, actor_token: int = -1,
		source_tint: Color = Color.WHITE, weapon_id: StringName = &"",
		hit_dir: Vector2 = Vector2.ZERO, effect: StringName = &"") -> void:
	if e.dead:
		return
	e.dead = true
	kills += 1
	wave_kills += 1
	if e.elite:
		wave_elite_kills += 1
	var pk := Pickup.new()
	pk.pos = e.pos
	var remaining := maxi(0, WaveDirector.cash_budget(wave) - int(expedition.get("cash_issued", 0)))
	pk.value = mini(remaining, maxi(1, int(round(float(e.def.drop * e.drop_mult) * material_drop_multiplier()))))
	if pk.value > 0:
		expedition["cash_issued"] = int(expedition.get("cash_issued", 0)) + pk.value
		pickups.append(pk)
	var death := EnemyDeathInfo.new()
	death.target_uid = e.uid
	death.enemy_id = e.def.id
	death.pos = e.pos
	death.radius = e.radius
	death.color = e.def.color
	death.elite_kind = e.elite_kind if e.elite else &""
	death.source = source
	death.actor_token = actor_token
	death.source_tint = source_tint
	death.weapon_id = weapon_id
	death.hit_dir = hit_dir
	death.facing = (player.pos - e.pos).normalized()
	death.effect = effect
	death.boss_phase = boss_phase if e.def.is_boss else 0
	death.boss_shard_index = boss_shards.find(e)
	enemy_killed.emit(death)
	if boss_shards.has(e):
		_handle_boss_shard_death(e)
	if e.death_radius_value() > 0.0:
		_bomber_explode(e)
	_split_elite(e)


func _split_elite(e: EnemyState) -> void:
	if e == null or not e.elite or e.elite_kind != &"splitter":
		return
	for i in 2:
		if not can_admit_enemy(false):
			break
		var child := EnemyState.new()
		child.uid = _next_uid
		_next_uid += 1
		child.def = e.def
		child.max_hp = maxf(1.0, e.max_hp * ELITE_SPLIT_SHARE)
		child.hp = child.max_hp
		child.speed = e.speed * ELITE_SPLIT_SPEED
		child.damage = e.damage * ELITE_SPLIT_DAMAGE
		child.radius = e.def.radius
		var offset := Vector2(-24.0 if i == 0 else 24.0, 0.0)
		var pad := child.radius + 8.0
		child.pos = WorldArena.move_body(e.pos, offset, pad)
		enemies.append(child)


func _begin_boss_phase2() -> void:
	if boss == null or boss_phase != 1 or not can_admit_enemy(true):
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
	var pad := shard.radius + 16.0
	var view := WorldArena.camera_rect(player.pos).grow(-pad)
	var best_distance := -1.0
	var best_visible := false
	# Keep the tear's original body fixed. A local ring offers an inward side at
	# every world edge without changing either RNG stream or the attack cadence.
	for index in 32:
		var offset := Vector2.from_angle(float(index) * TAU / 32.0) * 260.0
		var candidate := WorldArena.move_body(boss.pos + offset, Vector2.ZERO, pad)
		var separation := candidate.distance_to(boss.pos)
		var clearance := candidate.distance_to(player.pos)
		if separation < 240.0 or separation > 280.0 or clearance < 140.0:
			continue
		var visible := view.has_point(candidate)
		if best_distance < 0.0 or (visible and not best_visible) \
				or (visible == best_visible and clearance > best_distance):
			shard.pos = candidate
			best_distance = clearance
			best_visible = visible
	if best_distance < 0.0:
		shard.pos = WorldArena.move_body(boss.pos, Vector2(0.0, 260.0), pad)
	boss_shards.append(shard)
	enemies.append(shard)
	echo_silenced = maxf(echo_silenced, BOSS_PHASE2_SILENCE)
	_emit_echo_silence(echo_silenced, boss, EchoSilenceInfo.PHASE)
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


func _shield_break_burst() -> void:
	var center := player.pos
	var targets: Array[EnemyState] = []
	for e in enemies:
		if e.dead:
			continue
		if center.distance_to(e.pos) <= FIELD_SHIELD_BURST_RADIUS + e.radius:
			targets.append(e)
	for e in targets:
		if e.dead:
			continue
		var push := (e.pos - center).normalized() * FIELD_SHIELD_BURST_KNOCK
		damage_enemy(e, FIELD_SHIELD_BURST_DAMAGE, push, false, -1,
				Vector2.ZERO, &"", &"shield_burst")
	explosion.emit(center, FIELD_SHIELD_BURST_RADIUS, Color(0.45, 0.9, 1.0))
	var info := ExplosionInfo.new()
	info.kind = ExplosionInfo.WEAPON
	info.effect = &"shield_burst"
	info.pos = center
	info.radius = FIELD_SHIELD_BURST_RADIUS
	info.color = Color(0.45, 0.9, 1.0)
	explosion_info.emit(info)


func _bomber_explode(e: EnemyState) -> void:
	var radius := e.death_radius_value()
	var damage := e.death_damage_value() * WaveDirector.damage_scale(wave) * (1.0 + 0.10 * float(ascension))
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
		_hurt_player(damage, e.def.id, &"bomber_explosion", player.pos,
				(player.pos - e.pos).normalized())


# All player damage goes through this shield-aware path. The shield absorbs the
# incoming amount first; `PlayerHurtInfo.amount` remains the HP damage actually dealt.
func _hurt_player(amount: float, source: StringName, effect: StringName, pos: Vector2,
		direction: Vector2, grant_iframes: bool = true, source_uid: int = -1) -> void:
	if not is_finite(amount) or amount <= 0.0 or Expedition.is_negotiating(self):
		return
	var had_shield := player.shield > 0.0
	var absorbed := minf(player.shield, amount)
	player.shield -= absorbed
	if had_shield and player.shield <= 0.0 \
			and bool(player.set_bonus_applied.get(&"field", false)):
		_shield_break_burst()
	var dealt := amount - absorbed
	if dealt > 0.0:
		player.hp -= dealt
		if player.hp <= 0.0 and second_wind_charges > 0:
			second_wind_charges -= 1
			player.hp = 1.0
	if grant_iframes:
		player.iframes = IFRAME_TIME
	wave_damage_taken = true
	last_damage_source = source
	player_hurt.emit(dealt)
	var hurt := PlayerHurtInfo.new()
	hurt.source = source
	hurt.source_uid = source_uid
	hurt.amount = dealt
	hurt.absorbed = absorbed
	hurt.pos = pos
	hurt.direction = direction
	hurt.effect = effect
	hurt.lethal = player.hp <= 0.0
	player_hurt_info.emit(hurt)


func discard_take(take: EchoTake) -> void:
	shop.discard_echo(self, take)


func can_retire_echo() -> bool:
	return EchoSystem.can_retire(self)


func retire_selected_echo() -> bool:
	return EchoSystem.retire(self)


func select_echo(uid: int) -> bool:
	return EchoSystem.select(self, uid)


func cycle_echo(direction: int) -> bool:
	return EchoSystem.cycle(self, direction)


func _on_echo_retired(info: EchoRetirementInfo) -> void:
	if not info.exhausted:
		retirements += 1
		wave_retirements += 1
	StoryLedger.on_retire(self, info)


func _commit_repair_story() -> void:
	var previous := int(story_progress.get("committed_repairs", 0))
	if echo_refreshes > previous:

		for _repair in echo_refreshes - previous:
			StoryLedger.on_repair(self)
	story_progress["committed_repairs"] = echo_refreshes


func _move_player(delta: float, move_dir: Vector2) -> void:
	var dir := move_dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		player.facing = dir.normalized()
	player.pos = WorldArena.move_body(player.pos, dir * player.stats.get_stat(Stats.MOVE_SPEED) * delta, PlayerState.RADIUS)
	player.iframes = maxf(0.0, player.iframes - delta)
	player.hp = minf(player.max_hp(), player.hp + player.stats.get_stat(Stats.HP_REGEN) * delta)


func activate_character_skill() -> bool:
	return CharacterSkills.activate(self)


func interact() -> bool:
	return Expedition.interact(self)


func choose_negotiation(choice: StringName) -> bool:
	return Expedition.choose_negotiation(self, choice)


func choose_exit(choice: StringName) -> bool:
	if not Expedition.choose_exit(self, choice):
		return false
	phase = Phase.WON
	run_won.emit()
	return true


func _record_signature(info: ShotInfo) -> void:
	if info != null and info.source == -1 and info.actor_token < 0 and phase == Phase.WAVE:
		recorder.record_work(&"signature", &"", info.origin, info.weapon_id, info.direction)


func replay_signature_status(actor: EchoActor, action: Dictionary) -> Dictionary:
	var weapon := Content.weapon(action.get("weapon_id", &""))
	if actor == null or actor.take == null or weapon == null or not actor.take.weapons.has(weapon):
		return {"target_pos": actor.pos if actor != null else player.pos, "reason": &"weapon_missing"}
	if weapon.support_kind != &"":
		var aim: Vector2 = action.get("aim", Vector2.RIGHT)
		return {"target_pos": actor.pos + aim.normalized() * 44.0, "reason": &"ready"}
	var target := signature_target(actor, action)
	return {"target_pos": target.pos if target != null else actor.pos, "reason": &"ready" if target != null else &"no_target"}


func signature_target(actor: EchoActor, action: Dictionary) -> EnemyState:
	if actor == null or actor.take == null or phase != Phase.WAVE:
		return null
	var weapon := Content.weapon(action.get("weapon_id", &""))
	if weapon == null or not actor.take.weapons.has(weapon):
		return null
	var aim: Vector2 = action.get("aim", Vector2.RIGHT)
	var target: EnemyState = null
	var best := INF
	var reach := weapon.reach * actor.take.stats.range_mult()
	for enemy in enemies:
		if enemy.dead or enemy.brain_state == &"defeated":
			continue
		var offset := enemy.pos - actor.pos
		if offset.length() > reach + enemy.radius:
			continue
		var score := offset.length() + (1.0 - offset.normalized().dot(aim.normalized())) * reach
		if score < best:
			best = score
			target = enemy
	return target


func replay_signature(actor: EchoActor, action: Dictionary) -> bool:
	if actor == null or actor.take == null or phase != Phase.WAVE:
		return false
	var weapon := Content.weapon(action.get("weapon_id", &""))
	if weapon == null or not actor.take.weapons.has(weapon):
		return false
	var status := replay_signature_status(actor, action)
	if status["reason"] != &"ready":
		return false
	var index := actor.take.weapons.find(weapon)
	var level := actor.take.levels[index] if index < actor.take.levels.size() else 0
	var executed := Combat.fire(self, actor.pos, status["target_pos"], weapon, level, synergy_damage_mult(),
		actor.take.stats, echo_power(), actor.index, actor.take.tint(), 0, false, actor.take.uid)
	if not executed:
		return false
	shot_sequence += 1
	var info := ShotInfo.new()
	info.source = actor.index
	info.actor_token = actor.take.uid
	info.source_tint = actor.take.tint()
	info.weapon_id = weapon.id
	info.origin = actor.pos
	info.target = status["target_pos"]
	info.direction = (info.target - info.origin).normalized()
	info.count = maxi(1, weapon.pellets)
	info.level = level
	info.sequence = shot_sequence
	shot_fired_info.emit(info)
	return true


func _step_tail_pressure(delta: float) -> void:
	if wave_time < wave_duration * 0.72 or wave_time >= wave_duration - 0.3 or Expedition.is_negotiating(self):
		return
	expedition["tail_clock"] = maxf(-1.2, float(expedition.get("tail_clock", 0.0)) - delta)
	if float(expedition["tail_clock"]) > 0.0 or enemies.size() + pending.size() >= mini(8, 3 + int(wave / 3)):
		return
	expedition["tail_clock"] = 1.2
	var arrival := PendingSpawn.new()
	arrival.def = Content.enemy(&"runner" if wave >= 3 else &"grunt")
	arrival.pos = WaveDirector.spawn_position(ARENA, player.pos, rng)
	arrival.delay = 0.3
	queue_spawn(arrival)


func _spawn_enemies(delta: float) -> void:
	while _plan_idx < _plan.size() and _plan[_plan_idx].time <= wave_time:
		var ps := PendingSpawn.new()
		ps.def = _plan[_plan_idx].def
		ps.elite_kind = _plan[_plan_idx].elite_kind
		ps.pos = WaveDirector.spawn_position(ARENA, player.pos, rng)
		ps.delay = SPAWN_TELEGRAPH
		if not queue_spawn(ps) and ps.def.is_boss:
			break
		_plan_idx += 1
	var keep: Array[PendingSpawn] = []
	for ps in pending:
		ps.delay = maxf(0.0, ps.delay - delta)
		if ps.delay > 0.0:
			keep.append(ps)
		elif not _materialize(ps) and ps.def.is_boss:
			keep.append(ps)
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
		&"splitter":
			pass


func can_admit_enemy(boss_body: bool, include_pending: bool = false) -> bool:
	var total := enemies.size()
	var ordinary := 0
	for enemy in enemies:
		if enemy.def != null and not enemy.def.is_boss:
			ordinary += 1
	if include_pending:
		total += pending.size()
		for arrival in pending:
			if arrival.def != null and not arrival.def.is_boss:
				ordinary += 1
	return total < MAX_ENEMIES and (boss_body or ordinary < MAX_ORDINARY_ENEMIES)


func queue_spawn(arrival: PendingSpawn) -> bool:
	if arrival == null or arrival.def == null:
		return false
	if arrival.def.is_boss:
		if pending.size() >= MAX_PENDING:
			return false
	elif pending.size() >= MAX_PENDING - 1 or not can_admit_enemy(false, true):
		return false
	pending.append(arrival)
	return true


func _materialize(ps: PendingSpawn) -> bool:
	if ps.def == null:
		return false
	if not can_admit_enemy(ps.def.is_boss):
		# A malformed or externally saturated state cannot erase a mandatory boss.
		# Its original spawn record is retried after a real death frees capacity.
		if ps.def.is_boss and not pending.has(ps):
			queue_spawn(ps)
		return false
	var e := EnemyState.new()
	e.uid = _next_uid
	_next_uid += 1
	e.def = ps.def
	e.pos = WorldArena.move_body(ps.pos, Vector2.ZERO, ps.def.radius)
	var hp_scale := 1.0 if ps.def.is_boss else WaveDirector.hp_scale(wave)
	if ps.def.is_boss and endless and wave > WaveDirector.FINAL_WAVE:
		hp_scale = 1.0 + 0.20 * float(wave - WaveDirector.FINAL_WAVE)
	var ascension_level := 1.0 if ascension >= 1 else 0.0
	e.max_hp = ps.def.hp * hp_scale * (1.0 + 0.10 * ascension_level)
	e.hp = e.max_hp
	e.speed = ps.def.speed * WaveDirector.speed_scale(wave) * (1.0 + 0.05 * ascension_level) \
			* daily_enemy_speed_multiplier()
	e.damage = ps.def.damage * WaveDirector.damage_scale(wave) * (1.0 + 0.10 * ascension_level) \
			* daily_enemy_damage_multiplier()
	e.radius = ps.def.radius
	if ps.elite_kind != &"":
		_apply_elite(e, ps.elite_kind)
	if ps.def.is_boss:
		e.pos = WorldArena.move_body(e.pos, Vector2.ZERO, e.radius + 16.0)
	e.attack_direction = (player.pos - e.pos).normalized()
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
	return true


func _move_enemies(delta: float) -> void:
	EnemyBrain.step_zones(self, delta)
	grid.clear()
	for e in enemies:
		if e.dead:
			continue
		EnemyBrain.step(self, e, delta)
		grid.insert(e)
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
	if wave >= ascension_rift_wave() and not is_boss_wave():
		_rift_cd -= delta
		if _rift_cd <= 0.0:
			_spawn_rift()
			_rift_cd = ascension_rift_interval()


func _spawn_rift() -> void:
	if rifts.size() >= 6:
		return
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
	var damage := RIFT_DAMAGE_BASE + RIFT_DAMAGE_PER_WAVE * float(wave)
	for unit in support_units.duplicate():
		if (unit["pos"] as Vector2).distance_to(r.pos) <= r.radius + SupportSystem.UNIT_RADIUS:
			SupportSystem.damage(self, int(unit["uid"]), damage)
	if player.pos.distance_to(r.pos) > r.radius + PlayerState.RADIUS:
		return
	_hurt_player(damage, &"rift", &"rift", player.pos, Vector2.ZERO, false)


func _update_pickups(delta: float) -> void:
	var pull := player.stats.get_stat(Stats.PICKUP_RANGE)
	for pk in pickups:
		if pk.kind == &"supply":
			pk.life = maxf(0.0, pk.life - delta)
			if pk.life <= 0.0:
				pk.value = 0
				continue
		var to_player := player.pos - pk.pos
		var d2 := to_player.length_squared()
		if d2 <= COLLECT_RADIUS * COLLECT_RADIUS:
			collect_pickup(pk, true)
			continue
		if not pk.magnet and d2 <= pull * pull:
			pk.magnet = true
		if pk.magnet:
			pk.speed += MAGNET_ACCEL * delta
			pk.pos += to_player.normalized() * minf(pk.speed * delta, sqrt(d2))


func collect_pickup(pk: Pickup, manual: bool = true) -> bool:
	if pk == null or pk.value <= 0 or not pickups.has(pk) or pk.kind not in [&"scrap", &"supply"]:
		return false
	if pk.kind == &"supply" and pk.life <= 0.0:
		return false
	player.materials += pk.value
	if pk.kind == &"supply":
		supply_claims += 1
	if manual:
		CharacterSkills.on_pickup(self, pk.value)
		if pickup_repair > 0.0:
			var take := bank.find_uid(selected_echo_uid)
			if take != null:
				take.condition = minf(100.0, take.condition + float(pk.value) * pickup_repair)
	material_collected.emit(pk.value)
	pk.value = 0
	return true


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
	if phase != Phase.WAVE:
		return
	echo_silenced = 0.0
	for pk in pickups:
		if pk.kind == &"scrap":
			player.materials += pk.value
	pickups.clear()
	if active_contract != null:
		var contract := active_contract
		var success := contract.is_complete(self)
		if success:
			contracts_completed += 1
		else:
			contracts_failed += 1
		var reward := contract.reward if success else 0
		last_contract_done = true
		last_contract_success = success
		last_contract_reward = reward
		if reward > 0:
			player.materials += reward
		contract_resolved.emit(contract, success, reward)
		active_contract = null
	Expedition.finish_wave(self, last_contract_success)
	last_wave_earned = maxi(0, player.materials - wave_start_materials)
	last_interest = interest_for(player.materials)
	player.materials += last_interest
	enemies.clear()
	projectiles.clear()
	pending.clear()
	rifts.clear()
	player.hp = minf(player.max_hp(), player.hp + player.max_hp() * WAVE_END_HEAL)
	echoes.clear()
	attack_fields.clear()
	enemy_zones.clear()
	if echo_capacity() > 0:
		var take := recorder.finish(wave, player.weapons, player.stats, player.weapon_levels)
		bank.add(take)
	_commit_repair_story()
	StoryLedger.on_wave(self)
	wave_ended.emit(wave)
	if wave >= WaveDirector.FINAL_WAVE and not endless:
		phase = Phase.RESOLUTION
	else:
		phase = Phase.SHOP
		shop.roll(self)
		if endless and is_boss_wave():
			boon_rerolls = 0
			pending_boons = Boon.roll(rng, 3, self)


func boon_reroll_cost() -> int:
	return 15 + 10 * boon_rerolls


func reroll_boons() -> bool:
	if pending_boons.is_empty():
		return false
	var cost := boon_reroll_cost()
	if player.materials < cost:
		return false
	player.materials -= cost
	boon_rerolls += 1
	pending_boons = Boon.roll(rng, 3, self)
	return true


func choose_boon(index: int) -> bool:
	if pending_boons.is_empty() or index < 0 or index >= pending_boons.size():
		return false
	if not Boon.apply(self, pending_boons[index]):
		return false
	boons_taken.append(pending_boons[index])
	if boss_rush_bonus_boon:
		boss_rush_bonus_boon = false
		pending_boons = Boon.roll(rng, 3, self)
	else:
		pending_boons.clear()
	return true




func _step_supply() -> void:
	if _supply_spawned or wave % 3 != 0 or is_boss_wave() or wave_time < wave_duration * 0.45:
		return
	_supply_spawned = true
	for offset: Vector2 in [Vector2(330.0, 150.0), Vector2(-330.0, -150.0), Vector2(0.0, 250.0), Vector2(0.0, -250.0)]:
		var pos := WorldArena.move_body(player.pos, offset, 22.0)
		if pos.distance_to(player.pos) < 100.0 or not WorldArena.body_clear(pos, 22.0):
			continue
		var supply := Pickup.new()
		supply.pos = pos
		supply.value = 15 + wave
		supply.kind = &"supply"
		supply.life = Pickup.SUPPLY_LIFETIME
		pickups.append(supply)
		return
