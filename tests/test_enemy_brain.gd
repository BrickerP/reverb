extends RefCounted


func _enemy(id: StringName, position: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	for definition in Content.enemies():
		if definition.id == id:
			enemy.def = definition
			break
	enemy.uid = 41
	enemy.pos = position
	enemy.radius = enemy.def.radius
	enemy.speed = enemy.def.speed
	enemy.damage = 10.0
	return enemy


func test_runner_locks_warning_then_dashes_and_recovers(c: Check) -> void:
	var sim := Sim.new(2)
	sim.start_run()
	sim.player.pos = Vector2(1320.0, 650.0)
	var runner := _enemy(&"runner", Vector2(1160.0, 650.0))
	EnemyBrain.step(sim, runner, 0.01)
	c.eq(runner.brain_state, &"warn", "nearby runner warns before moving")
	var origin := runner.pos
	var direction := runner.attack_direction
	var hp := sim.player.hp
	EnemyBrain.step(sim, runner, EnemyBrain.RUNNER_WARN * 0.5)
	c.eq(runner.pos, origin, "runner holds still throughout warning")
	c.eq(sim.player.hp, hp, "warning is a safe window")
	sim.player.pos += Vector2(0.0, 180.0)
	EnemyBrain.step(sim, runner, EnemyBrain.RUNNER_WARN * 0.5 + 0.01)
	c.eq(runner.brain_state, &"dash", "warning releases a real dash")
	c.eq(runner.attack_direction, direction, "runner cannot retarget a locked dash")
	EnemyBrain.step(sim, runner, EnemyBrain.RUNNER_DASH)
	c.eq(runner.brain_state, &"recover", "dash has an explicit recovery")
	c.near(runner.pos.y, origin.y, 0.001, "dodged dash stays on its warned lane")
	c.eq(sim.player.hp, hp, "leaving the lane avoids the dash")


func test_runner_swept_dash_hits_inside_the_warned_lane(c: Check) -> void:
	var sim := Sim.new(6)
	sim.start_run()
	sim.player.pos = Vector2(1320.0, 650.0)
	sim.player.iframes = 0.0
	var runner := _enemy(&"runner", Vector2(1160.0, 650.0))
	var events: Array[PlayerHurtInfo] = []
	sim.player_hurt_info.connect(func(info: PlayerHurtInfo) -> void: events.append(info))
	var hp := sim.player.hp
	EnemyBrain.step(sim, runner, 0.01)
	EnemyBrain.step(sim, runner, EnemyBrain.RUNNER_WARN)
	c.eq(sim.player.hp, hp, "locked warning remains harmless until dash travel")
	EnemyBrain.step(sim, runner, 0.35)
	c.ok(sim.player.hp < hp, "swept dash cannot skip a target between frames")
	c.eq(events.size(), 1, "dash emits one real player damage event")
	if not events.is_empty():
		c.eq(events[0].effect, &"runner_dash", "damage identifies the actual dash mechanic")
		c.eq(events[0].source_uid, runner.uid, "damage identifies its authoritative enemy")


func test_brute_slam_direction_is_safe_behind_and_damaging_in_front(c: Check) -> void:
	var sim := Sim.new(3)
	sim.start_run()
	sim.player.pos = Vector2(1290.0, 680.0)
	var brute := _enemy(&"brute", Vector2(1200.0, 680.0))
	EnemyBrain.step(sim, brute, 0.01)
	c.eq(brute.brain_state, &"warn", "brute warns the directional slam")
	c.ok(EnemyBrain.in_slam(brute, sim.player.pos, PlayerState.RADIUS), "front target is inside warned cone")
	c.ok(not EnemyBrain.in_slam(brute, Vector2(1110.0, 680.0), PlayerState.RADIUS), "rear target is outside warned cone")
	var hp := sim.player.hp
	EnemyBrain.step(sim, brute, EnemyBrain.BRUTE_WARN - 0.01)
	c.eq(sim.player.hp, hp, "slam does no damage during its warning")
	EnemyBrain.step(sim, brute, 0.02)
	c.eq(brute.brain_state, &"slam", "warning ends in the damaging slam")
	c.ok(sim.player.hp < hp, "front cone damage is real")
	EnemyBrain.step(sim, brute, EnemyBrain.BRUTE_SLAM)
	c.eq(brute.brain_state, &"recover", "slam gives a punishable recovery")


func test_silencer_seal_warns_fixed_area_and_expires(c: Check) -> void:
	var sim := Sim.new(4)
	sim.start_run()
	sim.player.pos = Vector2(1300.0, 700.0)
	var silencer := _enemy(&"silencer", Vector2(1000.0, 700.0))
	EnemyBrain.step(sim, silencer, 0.01)
	c.eq(sim.enemy_zones.size(), 1, "ranged silencer creates one persistent seal")
	var zone := sim.enemy_zones[0]
	var fixed := zone.pos
	var hp := sim.player.hp
	c.ok(zone.is_warning(), "seal starts as a harmless warning")
	c.ok(not EnemyBrain.echo_is_sealed(sim, zone.pos), "warning does not suppress echoes")
	EnemyBrain.step_zones(sim, EnemyZone.WARNING_TIME - 0.01)
	c.eq(sim.player.hp, hp, "seal warning causes no damage")
	EnemyBrain.step_zones(sim, 0.02)
	c.ok(zone.is_active(), "seal becomes active after its warning")
	c.ok(sim.player.hp < hp, "active seal deals its stated damage")
	c.ok(EnemyBrain.echo_is_sealed(sim, fixed), "only echoes inside the real seal are suppressed")
	c.ok(not EnemyBrain.echo_is_sealed(sim, fixed + Vector2(150.0, 0.0)), "outside echoes keep firing")
	sim.player.pos += Vector2(0.0, 180.0)
	EnemyBrain.step(sim, silencer, 0.3)
	c.eq(zone.pos, fixed, "cast seal never follows its target")
	EnemyBrain.step_zones(sim, EnemyZone.ACTIVE_TIME + 0.1)
	c.eq(sim.enemy_zones.size(), 0, "spent seals leave no permanent hazard")


func test_warden_turns_with_inertia_and_status_timers_are_authoritative(c: Check) -> void:
	var sim := Sim.new(5)
	sim.start_run()
	sim.player.pos = Vector2(1000.0, 700.0)
	var warden := _enemy(&"warden", Vector2(1200.0, 700.0))
	warden.attack_direction = Vector2.RIGHT
	EnemyBrain.step(sim, warden, 0.1)
	c.ok(absf(warden.attack_direction.angle()) <= EnemyBrain.WARDEN_TURN_SPEED * 0.1 + 0.0001,
		"shield front cannot snap to a target behind it")
	var pos := warden.pos
	warden.pin_left = 0.5
	warden.ink_left = 0.8
	warden.stun_left = 0.2
	EnemyBrain.step(sim, warden, 0.1)
	c.eq(warden.pos, pos, "pin and stun prevent locomotion")
	c.near(warden.pin_left, 0.4, 0.0001, "brain ticks pin timer once")
	c.near(warden.ink_left, 0.7, 0.0001, "brain ticks wet timer once")
	c.near(warden.stun_left, 0.1, 0.0001, "brain ticks stun timer once")
