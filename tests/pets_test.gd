extends SceneTree

const PetSystem = preload("res://Scripts/pet_system.gd")
const ItemDatabase = preload("res://Scripts/item_database.gd")
class TestWorld extends Node2D:
	var ui_layer := CanvasLayer.new()
	var item_database: Dictionary = {}
	var material_inventory := {"golden_egg":2,"fish_chunk":1000}
	var pet_inventory := {"frog_pet":1}
	var fish_inventory := {"guppy":500}
	var equipped_pet_item := ""
	var player := CharacterBody2D.new()
	var player_manager = null
	var in_world := true
	var blocks := {Vector2i(2,3):{"type":"incubator"}}
	const BLOCK_SIZE = 32
	func grid_to_world_center(pos: Vector2i) -> Vector2: return Vector2(pos * BLOCK_SIZE)
	func update_all_ui(): pass
	func show_notification(_message): pass
	func get_mouse_grid_position() -> Vector2i: return Vector2i(2,3)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(800,720)
	root.size = Vector2i(800,720)
	var world := TestWorld.new()
	root.add_child(world)
	world.add_child(world.ui_layer)
	world.add_child(world.player)
	world.item_database = ItemDatabase.ITEMS.duplicate(true)
	var pets := PetSystem.new()
	pets.world = world
	world.add_child(pets)
	pets.set_process(false)
	pets.open_station(Vector2i(2,3), "incubator")
	assert(pets.selection.item_count == 2)
	var now := int(Time.get_unix_time_from_system()*1000)
	pets.apply_state({"action":"incubator_state","x":2,"y":3,"input_item":"golden_egg","output_item":"","started_at_ms":now,"ready_at_ms":now+60000,"server_time_ms":now})
	assert(pets.time_left(pets.current) == 60)
	assert(pets.insert.disabled and pets.claim.disabled)
	pets.apply_state({"action":"incubator_state","x":2,"y":3,"input_item":"frog_pet","chunks":250,"upgrade_cost":250,"ready_at_ms":0})
	assert(not pets.upgrade.disabled)
	assert(not pets.remove.disabled)
	pets._process(0.01)
	assert(pets.overlays.size() == 1)
	assert(pets.overlays[Vector2i(2,3)].texture.region.position == Vector2(20*32,16*32))
	world.equipped_pet_item = "frog_pet"
	pets.update_followers()
	assert(pets.followers.size() == 1)
	world.pet_inventory.frog_pet = 0
	pets.update_followers()
	assert(pets.followers.is_empty())
	assert(world.equipped_pet_item == "")
	pets.open_station(Vector2i(4,3),"sashimi_table")
	assert(pets.selection.get_item_text(0).contains("50.0 kg"))
	assert(not pets.upgrade.visible)
	pets.open_station(Vector2i(2,3),"incubator")
	pets.apply_state({"action":"incubator_state","x":2,"y":3,"input_item":"golden_egg","output_item":"frog_pet","ready_at_ms":now-1})
	assert(not pets.claim.disabled)
	pets._process(0.01)
	await process_frame
	if "--render-pets" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/pets-incubator.png")
		pets.open_station(Vector2i(4,3),"sashimi_table")
		pets._process(0.01)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/pets-sashimi.png")
	print("PETS_CLIENT_PASS: slots, timer, upgrades, atlas progress, equipment follower, fish weight and claim panel")
	quit()
