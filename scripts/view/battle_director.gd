class_name BattleDirector
extends RefCounted

# This owns presentation snapshots only. No EnemyState/Sim reference survives an event.
const MAX_CORPSES := 24
const REDUCED_CORPSES := 8
const MAX_REACTIONS := 96
const MAX_SHOT_ACTORS := 9
const SHOT_TIME := 0.18
const SHOT_INTERVAL := 0.55
const HURT_TIME := 0.10
const HURT_INTERVAL := 0.24
const CONTACT_TIME := 0.24
const REPAIR_TIME := 0.32
const PLAYER_DEATH_TIME := 0.55
const TEAR_TIME := 0.62
const TEAR_TENSION_TIME := 0.16
const TEAR_SNAP_TIME := 0.11

var corpses: Array[Dictionary] = []
var tear: Dictionary = {}
var player_death: Dictionary = {}
var _shots: Dictionary = {}
var _enemy_hurts: Dictionary = {}
var _enemy_contacts: Dictionary = {}
var _repairs: Dictionary = {}
var _player_hurt := 0.0
var _player_hurt_cooldown := 0.0
var _boss_roar := 0.0


func clear() -> void:
	corpses.clear()
	tear.clear()
	player_death.clear()
	_repairs.clear()
	end_actions()


func end_actions() -> void:
	_shots.clear()
	_enemy_hurts.clear()
	_enemy_contacts.clear()
	_player_hurt = 0.0
	_player_hurt_cooldown = 0.0
	_boss_roar = 0.0


func settle(reduced: bool) -> void:
	if not reduced:
		return
	_shots.clear()
	_enemy_contacts.clear()
	_boss_roar = 0.0
	if not tear.is_empty():
		tear["reduced"] = true
	while corpses.size() > REDUCED_CORPSES:
		var discarded := 0
		for index in corpses.size():
			if corpses[index]["enemy_id"] != &"paradox":
				discarded = index
				break
		corpses.remove_at(discarded)


func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_player_hurt = maxf(0.0, _player_hurt - delta)
	_player_hurt_cooldown = maxf(0.0, _player_hurt_cooldown - delta)
	_boss_roar = maxf(0.0, _boss_roar - delta)
	_tick_reactions(_shots, delta)
	_tick_reactions(_enemy_hurts, delta)
	_tick_reactions(_enemy_contacts, delta)
	_tick_reactions(_repairs, delta)
	_tick_terminal(delta)


func step_terminal(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		_tick_reactions(_repairs, delta)
		_tick_terminal(delta)


func _tick_terminal(delta: float) -> void:
	var keep := 0
	for corpse in corpses:
		corpse["age"] = float(corpse["age"]) + delta
		if float(corpse["age"]) < float(corpse["duration"]):
			corpses[keep] = corpse
			keep += 1
	corpses.resize(keep)
	if not tear.is_empty():
		tear["age"] = float(tear["age"]) + delta
		if float(tear["age"]) >= TEAR_TIME:
			tear.clear()
	if not player_death.is_empty():
		player_death["age"] = minf(PLAYER_DEATH_TIME, float(player_death["age"]) + delta)


func terminal_active() -> bool:
	return not corpses.is_empty() or not tear.is_empty() or (not player_death.is_empty()
			and float(player_death["age"]) < PLAYER_DEATH_TIME)


func shot(info: ShotInfo) -> bool:
	var token := info.actor_token
	if (token != -1 and not is_copy_token(token)) or (token == -1 and info.source >= 0):
		return false
	var weapon := Content.weapon(info.weapon_id)
	# Light fire belongs to the independently mounted weapon. Only a substantial
	# cone/slam gets a whole-body action, so automatic fire cannot consume the gait.
	if weapon == null or weapon.attack_style not in [&"slam", &"cone"]:
		return false
	if _shots.has(token) and float(_shots[token]["cooldown"]) > 0.0:
		return false
	_insert_reaction(_shots, token, SHOT_TIME, SHOT_INTERVAL, MAX_SHOT_ACTORS)
	return true


func enemy_hit(uid: int, direction: Vector2 = Vector2.ZERO) -> void:
	if uid < 0:
		return
	if _enemy_hurts.has(uid) and float(_enemy_hurts[uid]["cooldown"]) > 0.0:
		return
	_insert_reaction(_enemy_hurts, uid, HURT_TIME, HURT_INTERVAL, MAX_REACTIONS)
	_enemy_hurts[uid]["direction"] = direction.normalized() if direction.is_finite() else Vector2.ZERO


# A hit bends the print around its planted foot. The enemy's model position,
# facing, attack and gait phase are never changed by this small paper reaction.
func enemy_fold(uid: int, reduced: bool = false) -> Dictionary:
	var result := {"scale": Vector2.ONE, "rotation": 0.0, "ink": 0.0}
	if not _enemy_hurts.has(uid):
		return result
	var reaction: Dictionary = _enemy_hurts[uid]
	var strength := clampf(float(reaction["left"]) / HURT_TIME, 0.0, 1.0)
	var direction: Vector2 = reaction.get("direction", Vector2.ZERO)
	var motion := strength * (0.3 if reduced else 1.0)
	result["scale"] = Vector2(1.0 - absf(direction.x) * motion * 0.12,
		1.0 - (0.04 + absf(direction.y) * 0.08) * motion)
	result["rotation"] = direction.x * motion * 0.065
	result["ink"] = strength * 0.22
	return result


func player_hurt(uid: int) -> void:
	if _player_hurt_cooldown <= 0.0:
		_player_hurt = HURT_TIME
		_player_hurt_cooldown = HURT_INTERVAL
	if uid >= 0:
		enemy_contact(uid)


# Contact has already landed, whether HP or a shield received it. The attacker
# starts on impact and recovers; the defender's hurt pose is a separate outcome.
func enemy_contact(uid: int) -> bool:
	if uid < 0:
		return false
	if _enemy_contacts.has(uid) and float(_enemy_contacts[uid]["cooldown"]) > 0.0:
		return false
	_insert_reaction(_enemy_contacts, uid, CONTACT_TIME, CONTACT_TIME + 0.10, MAX_REACTIONS)
	return true


func actor_repaired(token: int) -> void:
	if token != -1 and not is_copy_token(token):
		return
	if _repairs.has(token) and float(_repairs[token]["cooldown"]) > 0.0:
		return
	_insert_reaction(_repairs, token, REPAIR_TIME, REPAIR_TIME, MAX_SHOT_ACTORS)


# The patch lands, the paper briefly compresses and stands straight again.
# Only its extent changes around the authored foot; clocks and gait stay owned
# by ArenaView. Reduced keeps the separately drawn patch without body motion.
func repair_pose(token: int, reduced: bool = false) -> Vector2:
	if reduced or not _repairs.has(token):
		return Vector2.ONE
	var progress := 1.0 - clampf(float(_repairs[token]["left"]) / REPAIR_TIME, 0.0, 1.0)
	var height := lerpf(0.94, 1.035, smoothstep(0.0, 0.3, progress)) if progress < 0.3 \
		else lerpf(1.035, 1.0, smoothstep(0.3, 1.0, progress))
	return Vector2(1.0 + (1.0 - height) * 0.5, height)


func boss_roar() -> void:
	_boss_roar = 0.32


func is_boss_roaring() -> bool:
	return _boss_roar > 0.0


func begin_tear(origin: Vector2) -> void:
	if origin.is_finite():
		tear = {"pos": origin, "age": 0.0, "reduced": false}


# The live shards are never held, hidden or moved by this discarded-paper print.
# Its three beats merely describe the real phase event after it has happened.
func tear_profile(reduced: bool = false) -> Dictionary:
	if tear.is_empty():
		return {}
	var age := clampf(float(tear["age"]), 0.0, TEAR_TIME)
	var progress := age / TEAR_TIME
	var opacity := 1.0 - smoothstep(0.72, 1.0, progress)
	if reduced or bool(tear.get("reduced", false)):
		return {"stage": &"settled", "progress": progress, "stage_progress": progress,
			"frame": 5, "stretch": Vector2.ONE, "spring": 0.0, "rotation": 0.0,
			"whole_alpha": 0.0, "half_alpha": 0.0, "seam_width": 12.0,
			"seam_alpha": opacity * 0.9, "fragment_alpha": 0.0,
			"fragment_travel": 0.0}
	if age < TEAR_TENSION_TIME:
		var p := age / TEAR_TENSION_TIME
		return {"stage": &"tension", "progress": progress, "stage_progress": p,
			"frame": 4, "stretch": Vector2(1.0 + p * 0.16, 1.0 - p * 0.11),
			"spring": 0.0, "rotation": 0.0, "whole_alpha": 0.70,
			"half_alpha": 0.0, "seam_width": 2.0 + p * 2.5,
			"seam_alpha": 0.9, "fragment_alpha": 0.0, "fragment_travel": 0.0}
	if age < TEAR_TENSION_TIME + TEAR_SNAP_TIME:
		var p := (age - TEAR_TENSION_TIME) / TEAR_SNAP_TIME
		return {"stage": &"snap", "progress": progress, "stage_progress": p,
			"frame": 5, "stretch": Vector2(1.16, 0.89), "spring": 18.0 * p,
			"rotation": p * 0.16, "whole_alpha": (1.0 - p) * 0.70,
			"half_alpha": p * 0.6, "seam_width": 4.5 + p * 9.5,
			"seam_alpha": 1.0, "fragment_alpha": 0.85,
			"fragment_travel": p * 12.0}
	var p := (age - TEAR_TENSION_TIME - TEAR_SNAP_TIME) / (TEAR_TIME - TEAR_TENSION_TIME - TEAR_SNAP_TIME)
	# One overshoot then settle, rather than an endlessly oscillating combat object.
	var spring := 18.0 + 23.0 * (1.0 - pow(1.0 - p, 3.0)) + sin(p * PI) * 8.0
	return {"stage": &"release", "progress": progress, "stage_progress": p,
		"frame": 5, "stretch": Vector2.ONE, "spring": spring,
		"rotation": 0.16 * (1.0 - p), "whole_alpha": 0.0,
		"half_alpha": pow(1.0 - p, 2.0) * 0.6, "seam_width": 14.0 - p * 9.0,
		"seam_alpha": pow(1.0 - p, 1.5), "fragment_alpha": (1.0 - p) * 0.85,
		"fragment_travel": 12.0 + p * 26.0}


func lose_player(position: Vector2, facing: Vector2, character: StringName) -> void:
	end_actions()
	player_death = {"pos": position, "facing": facing, "character": character, "age": 0.0}


func enemy_died(info: EnemyDeathInfo, reduced: bool = false) -> void:
	if not info.pos.is_finite() or not is_finite(info.radius) or info.radius <= 0.0:
		return
	var kind := death_kind(info.enemy_id)
	var duration := death_duration(kind)
	var cap := REDUCED_CORPSES if reduced else MAX_CORPSES
	while corpses.size() >= cap:
		var discarded := 0
		for index in corpses.size():
			if corpses[index]["enemy_id"] != &"paradox":
				discarded = index
				break
		corpses.remove_at(discarded)
	corpses.append({"uid": info.target_uid, "enemy_id": info.enemy_id, "pos": info.pos,
		"radius": info.radius, "facing": info.facing, "hit_dir": info.hit_dir,
		"source": info.source, "color": info.color, "actor_token": info.actor_token,
		"source_tint": info.source_tint, "elite_kind": info.elite_kind,
		"boss_phase": info.boss_phase, "shard_index": info.boss_shard_index,
		"kind": kind, "age": 0.0, "duration": duration})
	_enemy_hurts.erase(info.target_uid)
	_enemy_contacts.erase(info.target_uid)


func player_pose(key: StringName, gait_phase: float, moving: bool, reduced: bool) -> int:
	if not player_death.is_empty():
		return _frame(key, 6 if float(player_death["age"]) < PLAYER_DEATH_TIME * 0.38 else 7)
	if _player_hurt > 0.0:
		return _frame(key, 3)
	return _action_or_walk(key, -1, gait_phase, moving, reduced)


func echo_pose(key: StringName, token: int, gait_phase: float, moving: bool, reduced: bool) -> int:
	return _action_or_walk(key, token, gait_phase, moving, reduced)


func enemy_pose(key: StringName, uid: int, gait_phase: float, moving: bool, reduced: bool) -> int:
	if _enemy_hurts.has(uid) and float(_enemy_hurts[uid]["left"]) > 0.0:
		return _frame(key, 3)
	if _enemy_contacts.has(uid) and float(_enemy_contacts[uid]["left"]) > 0.0:
		if reduced:
			return _frame(key, 5)
		return _frame(key, 5 if float(_enemy_contacts[uid]["left"]) > CONTACT_TIME * 0.55 else 4)
	return walk_pose(key, gait_phase, moving, reduced)


func _action_or_walk(key: StringName, token: int, gait_phase: float, moving: bool, reduced: bool) -> int:
	if not reduced and _shots.has(token) and float(_shots[token]["left"]) > 0.0:
		return _frame(key, 5 if float(_shots[token]["left"]) > SHOT_TIME * 0.55 else 4)
	return walk_pose(key, gait_phase, moving, reduced)


static func walk_pose(key: StringName, gait_phase: float, moving: bool, _reduced: bool = false) -> int:
	if not moving:
		return 0
	var sequence: Array[int] = [0, 1, 0, 2]
	var phase := fposmod(maxf(0.0, gait_phase), TAU) if is_finite(gait_phase) else 0.0
	var index := mini(sequence.size() - 1, int(floor(phase / TAU * float(sequence.size()))))
	return _frame(key, sequence[index])


# Phase is accumulated from actual distance by ArenaView: one full left/right
# stride is TAU. Frame, lift and lean sample that same phase, never elapsed time.
static func gait_profile(gait_phase: float, amount: float, moving: bool, reduced: bool = false) -> Dictionary:
	var phase := fposmod(maxf(0.0, gait_phase), TAU) if is_finite(gait_phase) else 0.0
	var weight := clampf(amount, 0.0, 1.0) if is_finite(amount) else 0.0
	if not moving:
		return {"phase": phase, "bob": 0.0, "lean": 0.0, "scale": Vector2.ONE}
	var amplitude := weight * (0.3 if reduced else 1.0)
	var lift := absf(sin(phase)) * amplitude
	return {"phase": phase, "bob": -lift * 0.9, "lean": sin(phase) * amplitude * 0.018,
		"scale": Vector2(1.0 + lift * 0.008, 1.0 - lift * 0.008)}


static func death_kind(id: StringName) -> StringName:
	match id:
		&"runner": return &"spring"
		&"brute": return &"shred"
		&"silencer": return &"spill"
		&"bomber": return &"deflate"
		&"warden": return &"topple"
		&"paradox": return &"original"
	return &"crumple"


static func death_duration(kind: StringName) -> float:
	match kind:
		&"spring": return 0.50
		&"shred": return 0.68
		&"spill": return 0.56
		&"deflate": return 0.36
		&"topple": return 0.62
		&"original": return 0.82
	return 0.48


static func corpse_profile(corpse: Dictionary, reduced: bool = false) -> Dictionary:
	var duration := maxf(0.001, float(corpse["duration"]))
	var progress := clampf(float(corpse["age"]) / duration, 0.0, 1.0)
	var kind: StringName = corpse["kind"]
	var direction: Vector2 = corpse["hit_dir"]
	if direction == Vector2.ZERO or not direction.is_finite():
		direction = Vector2.UP
	direction = direction.normalized()
	var frame := 6 if progress < 0.35 else 7
	if kind == &"original" and int(corpse["boss_phase"]) >= 2:
		frame = 2 + posmod(maxi(0, int(corpse["shard_index"])), 2) if progress < 0.22 else 7
	var scale := Vector2.ONE
	var turn := 0.0
	var travel := 7.0
	match kind:
		&"spring":
			scale = Vector2(1.0 + progress * 0.22, 1.0 - progress * 0.52)
			turn = direction.x * progress * 0.4
			travel = 15.0
		&"shred": scale = Vector2(1.0 + progress * 0.05, 1.0 - progress * 0.30)
		&"spill": scale = Vector2(1.0 + progress * 0.28, 1.0 - progress * 0.66)
		&"deflate": scale = Vector2(1.0 + progress * 0.20, 1.0 - progress * 0.78)
		&"topple":
			turn = (0.8 if direction.x >= 0.0 else -0.8) * progress
			travel = 5.0
		&"original": scale = Vector2(1.0 + progress * 0.10, 1.0 - progress * 0.34)
		_: scale = Vector2(1.0 + progress * 0.12, 1.0 - progress * 0.57)
	if reduced:
		scale = Vector2.ONE
		turn = 0.0
		travel = 0.0
	return {"frame": frame, "progress": progress, "alpha": (1.0 - progress) * 0.9,
		"scale": scale, "rotation": turn, "offset": direction * travel * progress,
		"kind": kind}


func counts() -> Dictionary:
	return {"corpses": corpses.size(), "shots": _shots.size(), "hurt_actors": _enemy_hurts.size(),
		"contacts": _enemy_contacts.size(), "boss_tear": 0 if tear.is_empty() else 1,
		"player_terminal": not player_death.is_empty()}


static func _frame(key: StringName, frame: int) -> int:
	return clampi(frame, 0, maxi(0, PresentationAssets.frame_count(key) - 1))


static func is_copy_token(token: int) -> bool:
	# EchoBank assigns persistent positive UIDs; negative keys belong to the
	# player/enemy presentation lanes and never identify a recorded copy.
	return token > 0


func _insert_reaction(queue: Dictionary, token: int, left: float, cooldown: float, cap: int) -> void:
	if not queue.has(token) and queue.size() >= cap:
		queue.erase(queue.keys()[0])
	queue[token] = {"left": left, "cooldown": cooldown}


func _tick_reactions(queue: Dictionary, delta: float) -> void:
	for token in queue.keys():
		var state: Dictionary = queue[token]
		state["left"] = maxf(0.0, float(state["left"]) - delta)
		state["cooldown"] = maxf(0.0, float(state["cooldown"]) - delta)
		if float(state["cooldown"]) <= 0.0 and float(state["left"]) <= 0.0:
			queue.erase(token)
