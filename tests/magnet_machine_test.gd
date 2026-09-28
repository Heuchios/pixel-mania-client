extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")

class WorldFixture extends Node2D:
	const BLOCK_SIZE = 32
	var current_world_name = "MAGNET_TEST"
	var item_database = DB.ITEMS
	var blocks = {Vector2i(2, 3): {"type": "magnet_machine"}}
	var vending_preview_manager
	var ui_layer: CanvasLayer
	func get_inventory_icon_texture(id, _category = ""):
		return Factory.load_texture(item_database.get(id, {}).get("inventory_icon", item_database.get(id, {}).get("texture", "")))
	func get_item_display_name(id, _category):
		return str(item_database.get(id, {}).get("display_name", id))
	func get_item_count(_id, _category):
		return 20
	func show_notification(_text):
		pass

func _initialize():
	call_deferred("run")

func run():
	for script_path in ["world", "world_state_sync_manager", "world_lock_manager", "interaction_manager", "input_manager", "block_manager"]:
		var script = load("res://Scripts/%s.gd" % script_path)
		assert(script != null and script.can_instantiate(), "Machine integration script must compile: " + script_path)
	var world := WorldFixture.new()
	root.add_child(world)
	world.ui_layer = CanvasLayer.new()
	world.add_child(world.ui_layer)
	world.vending_preview_manager = load("res://Scripts/vending_preview_manager.gd").new()
	world.vending_preview_manager.world = world
	world.add_child(world.vending_preview_manager)
	var manager = load("res://Scripts/magnet_machine_manager.gd").new()
	world.add_child(manager)
	manager.setup(world)
	var data = {"world": "MAGNET_TEST", "x": 2, "y": 3, "machine_id": "M", "item_id": "dirt", "item_category": "block", "count": 1234, "building": true, "collecting": true, "can_manage": true}
	manager.apply_state(data)
	var sprite: AnimatedSprite2D = manager.visuals[Vector2i(2, 3)]
	assert(sprite.animation == "on" and sprite.sprite_frames.get_frame_count("on") == 2)
	for index in range(2):
		var frame := sprite.sprite_frames.get_frame_texture("on", index) as AtlasTexture
		assert(frame.region == Rect2((25 + index) * 32, 14 * 32, 32, 32))
		assert(not frame.get_image().is_invisible())
	assert(sprite.get_node("SelectedItem").visible)
	var remote := Factory.load_texture(DB.ITEMS.magnet_machine_remote.inventory_icon) as AtlasTexture
	assert(remote.region == Rect2(6 * 32, 3 * 32, 32, 32))
	assert(not remote.get_image().is_invisible())
	assert(not DB.ITEMS.magnet_machine_remote.get("hidden", false), "Players must be able to select their remote in inventory")
	assert(DB.ITEMS.magnet_machine.break_return_to_inventory)
	var ui = load("res://Scripts/magnet_machine_ui.gd").new()
	world.ui_layer.add_child(ui)
	ui.setup(world, manager)
	ui.apply_state(data, true)
	ui.show()
	await process_frame
	await process_frame
	assert(ui.change.disabled and not ui.remote.disabled)
	assert(ui.stock.text.contains("1234"))
	data.count = 0
	data.building = false
	manager.apply_state(data)
	assert(sprite.animation == "off")
	ui.apply_state(data, true)
	assert(not ui.change.disabled and ui.remote.disabled)
	data.can_manage = false
	ui.apply_state(data, true)
	assert(ui.update.disabled and ui.change.disabled and ui.stock.disabled)
	if "--preview" in OS.get_cmdline_user_args():
		data.can_manage = true
		data.building = true
		data.count = 1234
		ui.apply_state(data, true)
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("D:/Pixelmania/work/magnet-machine-ui.png")
	world.free()
	print("MAGNET_UI_OK: atlas frames, remote, selected-item preview, stock and permissions")
	quit()
