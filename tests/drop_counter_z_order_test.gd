extends SceneTree

const DROP_MANAGER_SCRIPT_PATH := "res://Scripts/drop_manager.gd"


class MockWorld:
	extends Node2D

	const CAMERA_ZOOM_DEFAULT := 3.0

	var current_camera_zoom := CAMERA_ZOOM_DEFAULT
	var dropped_items: Array = []
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)

	var world := MockWorld.new()
	root.add_child(world)

	var local_player := Node2D.new()
	local_player.z_as_relative = false
	local_player.z_index = 3900
	world.add_child(local_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(3.0, 3.0)
	camera.enabled = true
	local_player.add_child(camera)

	var remote_player := Node2D.new()
	remote_player.z_as_relative = false
	remote_player.z_index = 128
	world.add_child(remote_player)

	var manager_script = load(DROP_MANAGER_SCRIPT_PATH)
	assert(manager_script is GDScript)
	var manager = manager_script.new()
	world.add_child(manager)
	manager.world = world

	var drop_node := Node2D.new()
	drop_node.position = Vector2(160.0, 96.0)
	drop_node.z_as_relative = false
	drop_node.z_index = manager.DROP_WORLD_Z_INDEX
	world.add_child(drop_node)
	var drop_data := {
		"node": drop_node,
		"item_type": "dirt",
		"item_category": "block",
		"amount": 2.0
	}

	manager.create_drop_count_controls(drop_data)
	manager.update_drop_count_label(drop_data)
	var count_label = drop_data.get("count_label_ui", null)
	assert(count_label is Label)
	assert(count_label.get_parent() == drop_node)
	assert(not count_label.z_as_relative)
	assert(drop_node.z_index < count_label.z_index)
	assert(count_label.z_index < remote_player.z_index)
	assert(count_label.z_index < local_player.z_index)

	await process_frame
	manager.update_drop_count_screen_position(drop_data)
	var screen_transform: Transform2D = count_label.get_global_transform_with_canvas()
	var rendered_size := Vector2(
		count_label.size.x * screen_transform.x.length(),
		count_label.size.y * screen_transform.y.length()
	)
	var baseline_rendered_size := rendered_size
	assert(is_equal_approx(baseline_rendered_size.x, manager.DROP_COUNT_LABEL_SIZE.x))
	assert(baseline_rendered_size.y >= manager.DROP_COUNT_LABEL_SIZE.y)

	world.current_camera_zoom = 6.0
	camera.zoom = Vector2(6.0, 6.0)
	await process_frame
	manager.update_drop_count_screen_position(drop_data)
	screen_transform = count_label.get_global_transform_with_canvas()
	rendered_size = Vector2(
		count_label.size.x * screen_transform.x.length(),
		count_label.size.y * screen_transform.y.length()
	)
	assert(rendered_size.is_equal_approx(baseline_rendered_size * 2.0), "6x rendered size: " + str(rendered_size))

	drop_node.modulate.a = 0.5
	manager.update_drop_count_screen_position(drop_data)
	assert(is_equal_approx(count_label.modulate.a, 1.0))

	print("[drop-counter-z-order] success")
	quit(0)
