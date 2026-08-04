extends SceneTree

const PLAYER_MANAGER_SCRIPT_PATH := "res://Scripts/player_manager.gd"


class MockWorld:
	extends Node2D

	var player: Node2D = null


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
	world.player = local_player

	var camera := Camera2D.new()
	camera.zoom = Vector2(3.0, 3.0)
	camera.enabled = true
	local_player.add_child(camera)

	var remote_player := Node2D.new()
	remote_player.position = Vector2(160.0, 96.0)
	remote_player.z_as_relative = false
	remote_player.z_index = 128
	world.add_child(remote_player)

	var old_ui_layer := CanvasLayer.new()
	root.add_child(old_ui_layer)
	var old_overhead_layer := Control.new()
	old_ui_layer.add_child(old_overhead_layer)
	var remote_label := Label.new()
	remote_label.size = Vector2(300.0, 34.0)
	old_overhead_layer.add_child(remote_label)

	var manager_script = load(PLAYER_MANAGER_SCRIPT_PATH)
	assert(manager_script is GDScript)
	var manager = manager_script.new()
	world.add_child(manager)
	manager.world = world

	await process_frame
	manager.update_remote_name_label_world_transform(remote_label, remote_player)

	assert(remote_label.get_parent() == remote_player)
	assert(not remote_label.z_as_relative)
	assert(remote_player.z_index < remote_label.z_index)
	assert(remote_label.z_index < local_player.z_index)

	manager.normalize_remote_canvas_item_z_mode(remote_player)
	assert(not remote_label.z_as_relative)

	var canvas_transform: Transform2D = manager.get_viewport().get_canvas_transform()
	var rendered_width := remote_label.size.x * remote_label.scale.x * canvas_transform.x.length()
	var rendered_height := remote_label.size.y * remote_label.scale.y * canvas_transform.y.length()
	assert(is_equal_approx(rendered_width, remote_label.size.x))
	assert(is_equal_approx(rendered_height, remote_label.size.y))

	var top_left_screen_value = remote_label.get_meta(manager.REMOTE_NAME_SCREEN_POSITION_META, null)
	assert(top_left_screen_value is Vector2)
	manager.remote_name_labels["remote"] = remote_label
	var chat_anchor: Vector2 = manager._get_remote_chat_anchor_screen_position(remote_player, "remote")
	assert(is_equal_approx(chat_anchor.x, top_left_screen_value.x + remote_label.size.x * 0.5))
	assert(chat_anchor.y < top_left_screen_value.y)

	print("[remote-username-z-order] success")
	quit(0)
