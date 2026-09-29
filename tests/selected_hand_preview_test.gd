extends SceneTree

class TestWorld extends Node:
	var player: Node2D
	var selected_item_type := "dirt"
	var selected_item_category := "block"
	var equipped_tool := "pickaxe"
	var player_facing_direction := 1
	var counts := {"dirt": 2, "dirt_seed": 1}
	var icon: Texture2D
	var tool_textures := {}
	var block_textures := {}
	var seed_textures := {}
	var item_database := {"dirt": {"category": "block"}, "dirt_seed": {"category": "seed"}}
	func get_item_count(id, _category):
		return counts.get(id, 0)
	func get_inventory_icon_texture(_id, _category):
		return icon

func _init():
	call_deferred("run")

func run():
	var world := TestWorld.new()
	root.add_child(world)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	world.icon = ImageTexture.create_from_image(img)
	world.tool_textures = {"pickaxe": world.icon, "rod": world.icon}
	var actor := Node2D.new()
	world.add_child(actor)
	world.player = actor
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	actor.add_child(visual)
	var socket := Node2D.new()
	socket.name = "HandItem"
	visual.add_child(socket)
	var tool := AnimatedSprite2D.new()
	socket.add_child(tool)
	var manager = load("res://Scripts/equipment_manager.gd").new()
	world.add_child(manager)
	manager.set_process(false)
	manager.world = world
	manager.player = actor
	manager.hand_item_animated = tool
	manager.wearable_part_nodes["hand_item"] = tool
	manager.update_equipped_tool_visual("pickaxe", 1)
	assert(tool.visible)
	manager.update_selected_hand_preview()
	assert(not tool.visible and manager.selected_hand_preview.visible)
	assert(world.equipped_tool == "pickaxe")
	assert(manager.selected_hand_preview.get_parent() == socket)
	var first_preview = manager.selected_hand_preview
	manager.update_equipped_tool_visual("pickaxe", -1)
	assert(not tool.visible)
	visual.scale.x = -1
	assert(first_preview.global_position.x > 0)
	socket.rotation = -1.1
	assert(is_equal_approx(first_preview.rotation, 0.0))
	world.selected_item_type = "dirt_seed"
	world.selected_item_category = "seed"
	manager.update_selected_hand_preview()
	assert(first_preview == manager.selected_hand_preview)
	assert(is_equal_approx(first_preview.scale.x, 7.0 / 32.0))
	world.equipped_tool = "rod"
	manager.update_equipped_tool_visual("rod", 1)
	assert(not tool.visible)
	world.counts["dirt_seed"] = 0
	manager.update_selected_hand_preview()
	assert(tool.visible and not first_preview.visible)
	assert(manager.wearable_part_item_ids["hand_item"] == "rod")
	world.selected_item_type = "dirt"
	world.selected_item_category = "block"
	manager.update_selected_hand_preview()
	world.selected_item_category = "material"
	manager.update_selected_hand_preview()
	assert(tool.visible and not first_preview.visible)
	world.selected_item_category = "block"
	manager.update_selected_hand_preview()
	world.equipped_tool = ""
	world.selected_item_category = "tool"
	manager.update_selected_hand_preview()
	assert(not tool.visible and not first_preview.visible)
	world.selected_item_category = "block"
	world.player = Node2D.new()
	world.add_child(world.player)
	manager.update_selected_hand_preview()
	assert(not first_preview.visible, "Remote avatars must not inherit local selection")
	actor.set_meta("selected_hand_item", "dirt_seed")
	actor.set_meta("selected_hand_category", "seed")
	actor.set_meta("equipment_slots", {"hand": "pickaxe"})
	actor.set_meta("facing", -1)
	world.counts["dirt_seed"] = 0
	manager.update_selected_hand_preview()
	assert(first_preview.visible and not tool.visible, "Remote selection uses the remote snapshot, not local inventory")
	assert(is_equal_approx(first_preview.scale.x, 7.0 / 32.0))
	actor.set_meta("selected_hand_item", "")
	actor.set_meta("selected_hand_category", "")
	manager.update_selected_hand_preview()
	assert(not first_preview.visible and tool.visible)
	assert(manager.wearable_part_item_ids["hand_item"] == "pickaxe", "Clearing remote preview restores that player's equipped tool")
	assert(world.counts["dirt"] == 2)
	world.free()
	print("SELECTED_HAND_PREVIEW_PASS")
	quit()
