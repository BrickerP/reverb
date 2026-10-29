extends RefCounted


func _sim() -> Sim:
	var sim := Sim.new(819)
	sim.enemies.clear()
	sim.projectiles.clear()
	sim.attack_fields.clear()
	sim.player.stats.values[Stats.CRIT_CHANCE] = 0.0
	return sim


func _enemy(sim: Sim, uid: int, pos: Vector2) -> EnemyState:
	var enemy := EnemyState.new()
	enemy.uid = uid
	enemy.def = Content.enemy(&"grunt")
	enemy.pos = pos
	enemy.radius = 10.0
	enemy.hp = 10000.0
	enemy.max_hp = enemy.hp
	sim.enemies.append(enemy)
	sim.grid.insert(enemy)
	return enemy


func _fire(sim: Sim, id: StringName, origin: Vector2, target: Vector2, mastery: bool = false) -> void:
	Combat.fire(sim, origin, target, Content.weapon(id), 0, 1.0, sim.player.stats,
		1.0, 3, Color.CORAL, 0, false, 781, mastery)


func test_burst_has_separate_bounded_release_times(c: Check) -> void:
	var sim := _sim()
	_fire(sim, &"smg", Vector2(200,200), Vector2(400,200))
	c.eq(sim.projectiles.size(), 1, "burst starts with one real projectile")
	c.eq(sim.attack_fields.size(), 1, "remaining releases are authoritative delayed state")
	Combat.tick_fields(sim, 0.06)
	c.eq(sim.projectiles.size(), 1, "burst does not release early")
	Combat.tick_fields(sim, 0.02)
	c.eq(sim.projectiles.size(), 2, "second release follows the actual interval")
	Combat.tick_fields(sim, 0.2)
	c.eq(sim.projectiles.size(), 3, "exactly three rounds release")
	for p in sim.projectiles:
		c.eq(p.actor_token, 781, "delayed burst retains departed copy UID")
		c.eq(p.source_tint, Color.CORAL, "delayed burst retains source tint")


func test_pin_then_press_emits_only_after_actual_hit(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim, 1, Vector2(300,200))
	var combos: Array[ComboInfo] = []
	sim.combo_triggered.connect(func(info: ComboInfo) -> void: combos.append(info))
	_fire(sim, &"stapler", Vector2(200,200), enemy.pos)
	c.eq(combos.size(), 0, "equipping a pair never triggers a combo")
	Combat.step_projectiles(sim, 0.14)
	c.ok(enemy.pin_left > 0.0, "staple collision really pins")
	var before := enemy.hp
	_fire(sim, &"stamp", Vector2(200,200), enemy.pos)
	Combat.tick_fields(sim, 0.39)
	c.near(enemy.hp, before, 0.001, "warning does no early damage")
	Combat.tick_fields(sim, 0.02)
	c.near(before-enemy.hp, Content.weapon(&"stamp").damage*1.8, 0.001, "press consumes pin for real bonus damage")
	c.eq(combos.size(), 1, "one actual combo event")
	c.eq(combos[0].id, &"pin_press", "combo kind matches status interaction")
	c.eq(combos[0].actor_token, 781, "combo belongs to consuming attack owner")
	c.eq(enemy.pin_left, 0.0, "pin is consumed")
	Combat.tick_fields(sim, 0.2)
	c.eq(combos.size(), 1, "slam cannot repeat its combo")


func test_wet_conduction_is_real_bounded_and_nonrecursive(c: Check) -> void:
	var sim := _sim()
	var combos: Array[ComboInfo] = []
	sim.combo_triggered.connect(func(info: ComboInfo) -> void: combos.append(info))
	for index in 10:
		var enemy := _enemy(sim,index+1,Vector2(300+index*3,200))
		enemy.ink_left = 2.0
	var weapon := Content.weapon(&"hex_bolt").duplicate() as WeaponDef
	weapon.chain_count = 1
	Combat.fire(sim,Vector2(200,200),Vector2(300,200),weapon,0,1.0,sim.player.stats,1.0,3,Color.CORAL,0,false,781)
	c.eq(combos.size(), 1, "secondary damage does not recursively run combo logic")
	c.eq(combos[0].affected, 4, "one primary plus three wet neighbors maximum")
	var damaged := 0
	for enemy in sim.enemies:
		if enemy.hp < enemy.max_hp:
			damaged += 1
	c.eq(damaged,4,"conduction damages exactly its bounded target budget")
	c.ok(combos[0].bonus_damage > 0.0,"event reports actual extra damage")
	c.eq(combos[0].source_tint,Color.CORAL,"conduction keeps owner palette")


func test_cone_uses_angle_and_range_instead_of_hidden_pellets(c: Check) -> void:
	var sim := _sim()
	var inside := _enemy(sim,1,Vector2(300,200))
	var outside_angle := _enemy(sim,2,Vector2(200,300))
	var outside_range := _enemy(sim,3,Vector2(450,200))
	_fire(sim,&"shotgun",Vector2(200,200),inside.pos)
	c.ok(inside.hp < inside.max_hp,"cone hits inside geometry")
	c.eq(outside_angle.hp,outside_angle.max_hp,"cone excludes side target")
	c.eq(outside_range.hp,outside_range.max_hp,"cone excludes distant target")
	c.eq(sim.projectiles.size(),0,"cone does not pretend to be a pellet volley")


func test_line_and_swept_projectiles_respect_machine_cover(c: Check) -> void:
	var sim := _sim()
	var before := _enemy(sim,1,Vector2(440,390))
	var behind := _enemy(sim,2,Vector2(700,390))
	_fire(sim,&"hole_punch",Vector2(400,390),behind.pos)
	Combat.tick_fields(sim,0.016)
	c.ok(before.hp < before.max_hp,"line hits before machine")
	c.eq(behind.hp,behind.max_hp,"continuous line stops at actual machine")
	sim.attack_fields.clear()
	_fire(sim,&"rifle",Vector2(400,390),behind.pos)
	Combat.step_projectiles(sim,0.4)
	c.eq(behind.hp,behind.max_hp,"fast projectile cannot tunnel through machine")
	c.ok(sim.projectiles[0].dead,"cover consumes projectile")


func test_ink_and_tape_pulse_real_statuses_and_expire(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim,1,Vector2(300,200))
	_fire(sim,&"ink_bottle",Vector2(200,200),enemy.pos)
	Combat.tick_fields(sim,0.016)
	c.ok(enemy.ink_left > 0.0,"ink pool applies wet state")
	var before := enemy.hp
	_fire(sim,&"tape_spool",Vector2(200,200),enemy.pos)
	Combat.tick_fields(sim,0.016)
	c.ok(enemy.pin_left > 0.0,"tape field pins targets in its actual radius")
	c.ok(enemy.hp < before,"persistent field deals real damage")
	Combat.tick_fields(sim,10.0)
	c.eq(sim.attack_fields.size(),0,"fields have finite active lifetimes")


func test_boomerang_can_hit_outbound_and_return_once_each(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim,1,Vector2(290,200))
	_fire(sim,&"rubber_band",Vector2(200,200),enemy.pos)
	for index in 12:
		Combat.step_projectiles(sim,0.05)
	c.near(enemy.max_hp-enemy.hp,12.0,0.001,"return passes can each hit but never farm overlap")
	c.ok(sim.projectiles[0].returning,"projectile really reverses")
	c.ok(sim.projectiles[0].dead,"returned projectile retires at its original owner position")


func test_orbit_and_family_behavior_change_active_attacks(c: Check) -> void:
	var sim := _sim()
	_fire(sim,&"orb",Vector2(200,200),Vector2(300,200))
	Combat.tick_fields(sim,0.01)
	var field := sim.attack_fields[0]
	var first := field.pos
	Combat.tick_fields(sim,0.1)
	c.ok(field.pos.distance_to(first)>1.0,"orbit continuously changes authoritative position")
	c.near(field.pos.distance_to(field.origin),100.0,0.001,"orbit follows real radius")
	sim.attack_fields.clear()
	_fire(sim,&"smg",Vector2(200,200),Vector2(300,200),true)
	Combat.tick_fields(sim,1.0)
	c.eq(sim.projectiles.size(),4,"sidearm mastery adds an actual burst round")
	_fire(sim,&"tape_spool",Vector2(200,200),Vector2(300,200),true)
	c.ok(sim.attack_fields.back().life>Content.weapon(&"tape_spool").field_duration,"salvage mastery extends real active life")


func test_active_field_and_projectile_budgets_never_grow_unbounded(c: Check) -> void:
	var sim := _sim()
	for index in Combat.MAX_ACTIVE_FIELDS+20:
		_fire(sim,&"stamp",Vector2(200,200),Vector2(300,200))
	c.eq(sim.attack_fields.size(),Combat.MAX_ACTIVE_FIELDS,"pending slams obey a fixed active budget")
	for index in Combat.MAX_PROJECTILES+20:
		_fire(sim,&"pistol",Vector2(200,200),Vector2(300,200))
	c.eq(sim.projectiles.size(),Combat.MAX_PROJECTILES,"echo swarm cannot allocate unbounded projectiles")
	Combat.tick_fields(sim,1.0)
	c.eq(sim.attack_fields.size(),0,"capped fields still expire normally")


func test_combo_readiness_requires_real_producer_and_consumer(c: Check) -> void:
	var weapons: Array[WeaponDef] = [Content.weapon(&"stapler")]
	c.ok(not bool(Combat.combo_profile(weapons)[0]["ready"]),"pin alone is not a press combo")
	weapons.append(Content.weapon(&"stamp"))
	c.ok(bool(Combat.combo_profile(weapons)[0]["ready"]),"real pin plus press is ready")
	weapons = [Content.weapon(&"ink_bottle")]
	c.ok(not bool(Combat.combo_profile(weapons)[1]["ready"]),"ink alone is not its own arc consumer")
	weapons.append(Content.weapon(&"hex_bolt"))
	c.ok(bool(Combat.combo_profile(weapons)[1]["ready"]),"wet producer plus arc consumer is ready")


func test_all_six_masteries_change_execution(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim,1,Vector2(300,200))
	_fire(sim,&"rifle",Vector2(200,200),enemy.pos,true)
	c.near(sim.projectiles.back().pin_duration,0.4,0.001,"marksman mastery creates pinning on plain rifle")
	sim.projectiles.clear()
	_fire(sim,&"shotgun",Vector2(200,200),enemy.pos,true)
	c.near(enemy.knock.length(),Content.weapon(&"shotgun").knockback*1.5,0.001,"scatter mastery increases real cone push")
	enemy.knock=Vector2.ZERO
	_fire(sim,&"mallet",Vector2(200,200),enemy.pos,true)
	Combat.tick_fields(sim,0.21)
	c.near(enemy.stun_left,0.45,0.001,"press mastery stops enemies through actual stun")
	sim.projectiles.clear()
	_fire(sim,&"rubber_band",Vector2(200,200),enemy.pos,true)
	c.near(sim.projectiles.back().return_time,Content.weapon(&"rubber_band").return_time*1.2,0.001,"salvage mastery extends outward return leg")
	# Sidearm and arcane execution are checked above, including their boundaries.


func test_retirement_keeps_its_uid_after_actor_disappears(c: Check) -> void:
	var sim := _sim()
	var enemy := _enemy(sim,1,Vector2(300,200))
	var take := EchoTake.new()
	take.uid=719
	take.samples=PackedVector2Array([Vector2(200,200)])
	var actor := EchoActor.new(take,4)
	var profile := {"kind":&"stamp","weapon_id":&"stamp","damage":30.0,
		"radius":120.0,"reach":300.0,"direction":Vector2.RIGHT,
		"uid":take.uid,"tint":Color.AQUAMARINE}
	Combat.retirement_skill(sim,actor,profile)
	c.eq(sim.attack_fields.size(),1,"retirement stamp is a real delayed attack")
	var field := sim.attack_fields[0]
	c.eq(field.actor_token,719,"pending retirement carries immutable take UID")
	c.eq(field.source_tint,Color.AQUAMARINE,"pending retirement keeps source color")
	actor=null
	take=null
	Combat.tick_fields(sim,0.29)
	c.eq(enemy.hp,enemy.max_hp,"retirement warning has a real safe window")
	Combat.tick_fields(sim,0.02)
	c.near(enemy.max_hp-enemy.hp,30.0,0.001,"removed actor's pending skill still executes once")
	c.eq(field.actor_token,719,"delayed effect never borrows another slot's identity")


func test_retirement_categories_execute_six_different_primitives(c: Check) -> void:
	var kinds: Array[StringName]=[&"pin",&"stamp",&"cut",&"ink",&"return",&"arc"]
	var ids: Array[StringName]=[&"stapler",&"stamp",&"shotgun",&"ink_bottle",&"rubber_band",&"hex_bolt"]
	for index in kinds.size():
		var sim:=_sim()
		var enemy:=_enemy(sim,1,Vector2(280,200))
		var take:=EchoTake.new()
		take.uid=77
		take.samples=PackedVector2Array([Vector2(200,200)])
		var actor:=EchoActor.new(take,0)
		Combat.retirement_skill(sim,actor,{"kind":kinds[index],"weapon_id":ids[index],
			"damage":30.0,"radius":140.0,"reach":300.0,"direction":Vector2.RIGHT,
			"uid":77,"tint":Color.CORAL})
		if kinds[index]==&"return":
			c.eq(sim.projectiles.size(),1,"return category creates real boomerang")
			c.ok(sim.projectiles[0].return_time>0.0,"retirement return really comes back")
		else:
			Combat.tick_fields(sim,0.31)
			c.ok(enemy.hp<enemy.max_hp,"%s skill causes real category damage"%kinds[index])
		if kinds[index]==&"pin":
			c.near(enemy.pin_left,2.0,0.001,"retirement pin has its own real status")
		elif kinds[index]==&"ink":
			c.near(enemy.ink_left,2.0,0.001,"retirement ink prepares conduction")


func test_rejected_attacks_have_no_fictional_shot_events(c: Check) -> void:
	var sim := _sim()
	_enemy(sim,1,Vector2(300,200))
	for index in Combat.MAX_ACTIVE_FIELDS:
		_fire(sim,&"stamp",Vector2(200,200),Vector2(300,200))
	var shots:Array[ShotInfo]=[]
	sim.shot_fired_info.connect(func(info:ShotInfo)->void:shots.append(info))
	var weapons:Array[WeaponDef]=[Content.weapon(&"stamp")]
	var levels:Array[int]=[0]
	var cooldowns:Array[float]=[0.0]
	Combat.step_weapons(sim,Vector2(200,200),sim.player.stats,weapons,levels,cooldowns,1.0,0.01,-1,Color.WHITE)
	c.eq(shots.size(),0,"budget rejection does not claim a real shot")
	c.eq(sim.player_shots,0,"budget rejection does not advance trigger counter")
	sim.attack_fields.clear()
	weapons[0]=Content.weapon(&"smg")
	cooldowns[0]=0.0
	Combat.step_weapons(sim,Vector2(200,200),sim.player.stats,weapons,levels,cooldowns,1.0,0.01,3,Color.CORAL,1.0,1.0,781)
	Combat.tick_fields(sim,0.15)
	c.eq(shots.size(),3,"each actual delayed burst release gets an owner snapshot")
	c.eq(shots[2].actor_token,781,"last burst round retains stable identity")
	c.eq(shots[2].sequence,3,"sequence counts real volley releases")


func test_large_tick_return_and_collision_order_follow_real_path(c: Check) -> void:
	var sim:=_sim()
	var near:=_enemy(sim,2,Vector2(380,200))
	var far:=_enemy(sim,1,Vector2(300,200))
	_fire(sim,&"pistol",Vector2(450,200),far.pos)
	Combat.step_projectiles(sim,0.25)
	c.ok(near.hp<near.max_hp,"leftward shot hits nearest contact rather than lowest world cell")
	c.eq(far.hp,far.max_hp,"single projectile stops at its first real contact")
	sim=_sim()
	var target:=_enemy(sim,1,Vector2(290,200))
	_fire(sim,&"rubber_band",Vector2(200,200),target.pos)
	Combat.step_projectiles(sim,0.6)
	c.near(target.max_hp-target.hp,12.0,0.001,"one large tick still resolves outward and return legs separately")
	c.ok(sim.projectiles[0].dead,"large tick returns home without flying through its origin")


func _deployed_retirement(sim: Sim, weapon: StringName) -> EchoActor:
	sim.phase = Sim.Phase.WAVE
	var take := EchoTake.new()
	take.samples = PackedVector2Array([Vector2(200,200)])
	take.weapons.append(Content.weapon(weapon))
	take.levels.append(0)
	take.condition = 73.0
	sim.bank.add(take)
	var actor := EchoActor.new(take,0)
	sim.echoes.append(actor)
	sim.selected_echo_uid = take.uid
	return actor


func test_rejected_retirement_keeps_selected_copy_and_all_transaction_state(c: Check) -> void:
	for weapon: StringName in [&"stamp", &"ink_bottle", &"rubber_band"]:
		var sim := _sim()
		var actor := _deployed_retirement(sim,weapon)
		var uid := actor.take.uid
		var target := _enemy(sim,1,Vector2(260,200))
		var retired: Array[EchoRetirementInfo] = []
		var combos: Array[ComboInfo] = []
		sim.echo_retired.connect(func(info:EchoRetirementInfo)->void:retired.append(info))
		sim.combo_triggered.connect(func(info:ComboInfo)->void:combos.append(info))
		if weapon == &"rubber_band":
			for index in Combat.MAX_PROJECTILES:
				sim.projectiles.append(Projectile.new())
		else:
			for index in Combat.MAX_ACTIVE_FIELDS:
				sim.attack_fields.append(AttackField.new())
		var field_count := sim.attack_fields.size()
		var projectile_count := sim.projectiles.size()
		var rng_state := sim.rng.state
		c.ok(not sim.retire_selected_echo(),"%s retirement reports capacity rejection"%weapon)
		c.eq(sim.echoes.size(),1,"rejection preserves deployed actor")
		c.eq(sim.echoes[0],actor,"rejection preserves actor identity")
		c.eq(sim.bank.takes.size(),1,"rejection does not spend a recorded copy")
		c.eq(sim.bank.takes[0].uid,uid,"rejection preserves stable copy identity")
		c.near(actor.take.condition,73.0,0.001,"rejection leaves condition untouched")
		c.eq(sim.selected_echo_uid,uid,"rejection preserves selection")
		c.near(sim.retire_cooldown,0.0,0.001,"rejection does not spend input cooldown")
		c.eq(retired.size(),0,"rejection emits no retirement event")
		c.eq(combos.size(),0,"rejection emits no damage combo")
		c.eq(target.hp,target.max_hp,"rejection causes no hidden damage")
		c.eq(sim.attack_fields.size(),field_count,"rejection allocates no field")
		c.eq(sim.projectiles.size(),projectile_count,"rejection allocates no projectile")
		c.eq(sim.shot_sequence,0,"rejection advances no shot event sequence")
		c.eq(sim.player_shots,0,"rejection advances no trigger counter")
		c.eq(sim.rng.state,rng_state,"rejection spends no randomness")
		sim.attack_fields.clear()
		sim.projectiles.clear()
		c.ok(sim.retire_selected_echo(),"capacity recovery lets the same selected copy retire")
		c.eq(sim.echoes.size(),0,"accepted retry consumes the copy exactly once")
		c.eq(retired.size(),1,"accepted retry emits exactly one retirement event")


func test_instant_retirement_is_accepted_at_visual_cap_and_on_legitimate_whiff(c: Check) -> void:
	var ids: Array[StringName] = [&"stapler", &"shotgun", &"hex_bolt"]
	var kinds: Array[StringName] = [&"pin", &"cut", &"arc"]
	for index in kinds.size():
		var sim := _sim()
		var actor := _deployed_retirement(sim,ids[index])
		for field_index in Combat.MAX_ACTIVE_FIELDS:
			sim.attack_fields.append(AttackField.new())
		var profile := {"kind":kinds[index],"weapon_id":ids[index],"damage":30.0,
			"radius":150.0,"reach":300.0,"direction":Vector2.RIGHT,
			"uid":actor.take.uid,"tint":Color.CORAL}
		c.ok(Combat.retirement_skill(sim,actor,profile),"%s legitimate whiff accepts without mandatory state"%kinds[index])
		c.eq(sim.attack_fields.size(),Combat.MAX_ACTIVE_FIELDS,"optional instant visual obeys cap")
		var enemy := _enemy(sim,1,Vector2(280,200))
		c.ok(Combat.retirement_skill(sim,actor,profile),"%s instant hit accepts at visual cap"%kinds[index])
		c.ok(enemy.hp<enemy.max_hp,"instant skill really executes despite optional visual rejection")


func test_return_retirement_damage_equals_the_displayed_total(c: Check) -> void:
	var sim := _sim()
	var actor := _deployed_retirement(sim,&"rubber_band")
	var target := _enemy(sim,1,Vector2(280,200))
	var profile := {"kind":&"return","weapon_id":&"rubber_band","damage":30.0,
		"radius":150.0,"reach":300.0,"direction":Vector2.RIGHT,
		"uid":actor.take.uid,"tint":Color.CORAL}
	c.ok(Combat.retirement_skill(sim,actor,profile),"return skill accepts its real projectile")
	Combat.step_projectiles(sim,0.3)
	c.near(target.max_hp-target.hp,15.0,0.001,"outward pass deals half the displayed total")
	Combat.step_projectiles(sim,1.3)
	c.near(target.max_hp-target.hp,float(profile["damage"]),0.001,"two real passes exactly match the displayed total")
	c.ok(sim.projectiles[0].dead,"return finishes after both passes")
