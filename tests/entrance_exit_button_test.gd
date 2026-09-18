extends SceneTree

class TestWorld:
	extends Node2D
	const ENTRANCE_GATE_TYPE = "entrance_gate"
	var in_world := true
	var player := Node2D.new()
	var blocks := {Vector2i.ZERO: {"type": "entrance_gate"}}
	var grid := Vector2i.ZERO
	var blocked := false
	var loading := false
	var exits := 0
	var layer := Control.new()
	func get_ui_overhead_layer(): return layer
	func get_player_grid_position(): return grid
	func is_smooth_world_load_waiting_for_server_state(): return loading
	func is_gameplay_hud_blocked(): return blocked
	func exit_world_from_entrance_gate(): exits += 1

func _initialize():
	call_deferred("run_test")

func run_test():
	var world := TestWorld.new()
	root.add_child(world)
	world.add_child(world.player)
	world.add_child(world.layer)
	var manager = load("res://Scripts/gameplay_ui_manager.gd").new()
	world.add_child(manager)
	manager.setup(world)
	manager.set_process(false)
	manager._process(0.0)
	assert(manager.entrance_exit_button.visible)
	for index in range(3):
		manager.entrance_exit_elapsed = 0.0
		manager._process(index * manager.EXIT_FRAME_SECONDS)
		assert(manager.entrance_exit_button.texture_normal.region == Rect2((22 + index) * 32, 64, 32, 32))
	world.grid = Vector2i.ONE
	manager._on_entrance_exit_pressed()
	assert(world.exits == 0)
	manager._process(0.0)
	assert(not manager.entrance_exit_button.visible)
	world.grid = Vector2i.ZERO
	world.blocked = true
	assert(not manager._can_show_entrance_exit())
	world.blocked = false
	world.loading = true
	assert(not manager._can_show_entrance_exit())
	world.loading = false
	world.in_world = false
	assert(not manager._can_show_entrance_exit())
	world.in_world = true
	manager._on_entrance_exit_pressed()
	manager._on_entrance_exit_pressed()
	assert(world.exits == 1)
	assert(not manager.entrance_exit_button.visible)
	world.free()
	print("Entrance exit button tests passed")
	quit()
