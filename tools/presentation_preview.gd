extends SceneTree
# Deterministic presentation fixture for a 12-16 second --write-movie capture.
# It stages real Main/Sim/UI behavior for visual review only; its durability,
# materials, wave duration and offer lineup are not balance evidence.
# Usage: godot --path . --fixed-fps 60 --disable-vsync \
#   --write-movie res://shots/presentation.avi \
#   --script res://tools/presentation_preview.gd

enum Stage { SELECT, PLAY, SHOP, REPLACE, PURCHASED, FINISH }

const SEED := 20261023
const SELECT_SHOT_FRAME := 45
const SELECT_FRAMES := 60
const WAVE_SECONDS := 8.0
const SHOP_HOLD_FRAMES := 45

var _main: Node
var _stage := Stage.SELECT
var _frame := 0
var _shop_frame := 0
var _offers_staged := false
var _shots_dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SAVE", "user://presentation_preview_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://presentation_preview_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://presentation_preview_settings.json")
	_clear_fixture_files()
	_shots_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _main.character_select == null:
		return false
	_frame += 1
	match _stage:
		Stage.SELECT:
			_select_stage()
		Stage.PLAY:
			_play_stage()
		Stage.SHOP:
			_shop_stage()
		Stage.REPLACE:
			_replace_stage()
		Stage.PURCHASED:
			_purchased_stage()
		Stage.FINISH:
			_release()
			if _frame >= 8:
				quit()
				return true
	return false


func _select_stage() -> void:
	if _frame == SELECT_SHOT_FRAME:
		_save("select")
	if _frame < SELECT_FRAMES:
		return
	_main.choose_character(&"looper", SEED)
	_setup_presentation_fixture()
	_frame = 0
	_stage = Stage.PLAY


func _play_stage() -> void:
	var sim: Sim = _main.sim
	if sim == null:
		return
	_drive(_movement_for(_frame))
	if _frame == 150:
		_save("combat")
	elif _frame == 360:
		_save("echoes")
	if sim.phase == Sim.Phase.SHOP:
		_release()
		_stage_shop_offers(sim)
	if _main.shop_ui.visible:
		_frame = 0
		_shop_frame = 0
		_stage = Stage.SHOP


func _shop_stage() -> void:
	_shop_frame += 1
	if _shop_frame < SHOP_HOLD_FRAMES:
		return
	_save("shop")
	var first := _main.shop_ui.offers_box.get_child(0) as OfferCard
	first.pressed.emit()
	_frame = 0
	_stage = Stage.REPLACE


func _replace_stage() -> void:
	if _frame < SHOP_HOLD_FRAMES:
		return
	_save("replace")
	# Match ui_shots.gd: exercise the real ShopUi replacement callback so the
	# Shop transaction and GameAudio purchase signal are both used.
	_main.shop_ui._on_replace_slot(0)
	_frame = 0
	_stage = Stage.PURCHASED


func _purchased_stage() -> void:
	if _frame < SHOP_HOLD_FRAMES:
		return
	_save("purchased")
	_main.audio.stop_all()
	_frame = 0
	_stage = Stage.FINISH


func _setup_presentation_fixture() -> void:
	var sim: Sim = _main.sim
	# A full six-slot build keeps all three requested weapon families visible and
	# lets the shop demonstrate its real replacement interaction.
	sim.player.weapons.clear()
	sim.player.weapon_levels.clear()
	sim.player.cooldowns.clear()
	for id: StringName in [&"pistol", &"shotgun", &"orb", &"pistol", &"shotgun", &"orb"]:
		sim.player.add_weapon(Content.weapon(id))
	sim.player.stats.add(Stats.MAX_HP, 500.0)
	sim.player.hp = sim.player.max_hp()
	sim.player.materials = 300
	_add_echo_take(sim, 1, 0.0)
	_add_echo_take(sim, 2, PI)
	sim.start_wave(3)
	# Isolate the four staged enemies so the new actor silhouettes stay legible.
	# Combat, movement, targeting, projectiles and wave transitions remain real.
	sim._plan.clear()
	sim._plan_idx = 0
	sim.wave_duration = WAVE_SECONDS
	_spawn_enemy(sim, &"grunt", Vector2(-250.0, -110.0))
	_spawn_enemy(sim, &"grunt", Vector2(270.0, 105.0))
	_spawn_enemy(sim, &"runner", Vector2(-300.0, 120.0))
	_spawn_enemy(sim, &"runner", Vector2(160.0, -205.0))


func _add_echo_take(sim: Sim, wave: int, phase: float) -> void:
	var take := EchoTake.new()
	take.wave = wave
	for id: StringName in [&"pistol", &"shotgun", &"orb"]:
		take.weapons.append(Content.weapon(id))
		take.levels.append(0)
	take.stats = sim.player.stats.copy()
	var center := Sim.ARENA.get_center()
	for i in 180:
		var t := float(i) * 0.055 + phase
		var radius := 175.0 if wave == 1 else 135.0
		var vertical := 92.0 if wave == 1 else 145.0
		take.samples.append(center + Vector2(cos(t) * radius, sin(t * 1.35) * vertical))
	sim.bank.add(take)


func _spawn_enemy(sim: Sim, id: StringName, offset: Vector2) -> void:
	var spawn := PendingSpawn.new()
	spawn.def = Content.enemy(id)
	spawn.pos = Sim.ARENA.get_center() + offset
	sim._materialize(spawn)
	var enemy := sim.enemies[sim.enemies.size() - 1]
	# Fixture-only durability keeps the staged silhouette readable; movement,
	# contact damage and all combat behavior still come from the real definition.
	enemy.max_hp = 180.0
	enemy.hp = enemy.max_hp


func _stage_shop_offers(sim: Sim) -> void:
	if _offers_staged:
		return
	_offers_staged = true
	sim.player.materials = 300
	sim.shop.offers.clear()
	sim.shop.offers.append(_weapon_offer(&"rifle", sim.wave))
	sim.shop.offers.append(_weapon_offer(&"smg", sim.wave))
	sim.shop.offers.append(_item_offer(&"sharp_edge", sim.wave))
	sim.shop.offers.append(_item_offer(&"long_play", sim.wave))


func _weapon_offer(id: StringName, wave: int) -> Offer:
	var offer := Offer.new()
	offer.weapon = Content.weapon(id)
	offer.price = Shop.price_for(offer.weapon.price, wave)
	return offer


func _item_offer(id: StringName, wave: int) -> Offer:
	var offer := Offer.new()
	offer.item = Content.item(id)
	offer.price = Shop.price_for(offer.item.price, wave)
	return offer


func _movement_for(frame: int) -> Vector2:
	match int(frame / 90) % 4:
		0:
			return Vector2(1.0, -0.35).normalized()
		1:
			return Vector2(0.35, 1.0).normalized()
		2:
			return Vector2(-1.0, 0.35).normalized()
		_:
			return Vector2(-0.35, -1.0).normalized()


func _drive(dir: Vector2) -> void:
	_axis(&"move_left", maxf(0.0, -dir.x))
	_axis(&"move_right", maxf(0.0, dir.x))
	_axis(&"move_up", maxf(0.0, -dir.y))
	_axis(&"move_down", maxf(0.0, dir.y))


func _axis(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release() -> void:
	_drive(Vector2.ZERO)


func _save(name: String) -> void:
	if name in ["shop", "purchased"]:
		_check_shop_layout()
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := _shots_dir.path_join("presentation_%s.png" % name)
	image.save_png(path)
	print("wrote shots/presentation_%s.png" % name)


func _check_shop_layout() -> void:
	var ui: ShopUi = _main.shop_ui
	var scroll := ui.build_panel.get_child(0) as ScrollContainer
	var right := scroll.get_global_rect().end.x
	if scroll.get_v_scroll_bar().is_visible_in_tree():
		right -= scroll.get_v_scroll_bar().size.x
	for card: PanelContainer in ui.build_panel._cards:
		if card.get_global_rect().end.x > right + 0.5:
			push_error("Presentation preview: build card is clipped horizontally")
	var last := ui.offers_box.get_child(ui.offers_box.get_child_count() - 1) as OfferCard
	if last.get_global_rect().end.y > ui.reroll_button.global_position.y:
		push_error("Presentation preview: offer overlaps shop actions")
	print("presentation layout: full build and four offers checked")


func _clear_fixture_files() -> void:
	for name in [
		"presentation_preview_save.json",
		"presentation_preview_runs.jsonl",
		"presentation_preview_settings.json",
	]:
		var path := ProjectSettings.globalize_path("user://" + name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
