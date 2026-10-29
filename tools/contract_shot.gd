extends SceneTree
# Windowed screenshot of the shop contract strip.
# Usage: godot --path . --fixed-fps 60 --disable-vsync --script res://tools/contract_shot.gd

var _ui: ShopUi
var _sim: Sim
var _frame := 0
var _dir := ""


func _initialize() -> void:
	OS.set_environment("REVERB_SUSPEND", "user://dev_contract_shot_suspend.json")
	OS.set_environment("REVERB_SAVE", "user://contract_shot_save.json")
	OS.set_environment("REVERB_RUN_LOG", "user://contract_shot_runs.jsonl")
	OS.set_environment("REVERB_SETTINGS", "user://contract_shot_settings.json")
	_dir = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	_sim = Sim.new(7)
	_sim.start_run()
	_sim.phase = Sim.Phase.SHOP
	_sim.wave = 10
	_sim.player.materials = 100
	_sim.shop.roll(_sim)
	_sim.shop.contract = AnomalyContract.new()
	_sim.shop.contract.kind = AnomalyContract.HUNT
	_sim.shop.contract.deposit = AnomalyContract.HUNT_DEPOSIT
	_sim.shop.contract.reward = AnomalyContract.HUNT_REWARD
	_ui = ShopUi.new()
	_ui.theme = UiTheme.build()
	root.add_child(_ui)
	_open.call_deferred()


func _open() -> void:
	_ui.open(_sim)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame >= 20:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(_dir.path_join("contract.png"))
		print("wrote shots/contract.png")
		quit()
		return true
	return false
