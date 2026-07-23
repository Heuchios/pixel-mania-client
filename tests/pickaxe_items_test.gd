extends SceneTree

const ITEM_DATABASE_SCRIPT_PATH := "res://Scripts/item_database.gd"
const ITEM_GAMEPLAY_MANAGER_SCRIPT = preload("res://Scripts/item_gameplay_manager.gd")
const PICKAXE_ITEM_IDS := [
	"stone_pickaxe",
	"golden_pickaxe",
	"emerald_pickaxe",
	"diamond_pickaxe",
	"neptune_pickaxe",
	"void_pickaxe",
]


class MockWorld:
	extends Node

	const BLOCK_MAX_HITS := 3

	var equipped_tool := ""
	var item_database: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var item_database_script = load(ITEM_DATABASE_SCRIPT_PATH)
	assert(item_database_script is GDScript)
	var item_database_node = item_database_script.new()

	var world := MockWorld.new()
	for item_id in PICKAXE_ITEM_IDS:
		var pickaxe_data: Dictionary = item_database_node.get_item_data(item_id)
		assert(str(pickaxe_data.get("category", "")) == "tool")
		assert(str(pickaxe_data.get("equipment_slot", "")) == "hand")
		assert(bool(pickaxe_data.get("hand_item", false)))
		assert(bool(pickaxe_data.get("instance_tracked", false)))
		assert(int(pickaxe_data.get("break_hit_reduction", 0)) == (1 if item_id == "void_pickaxe" else 0))

		var texture_path := str(pickaxe_data.get("texture", ""))
		var icon_path := str(pickaxe_data.get("inventory_icon", ""))
		assert(ResourceLoader.exists(texture_path))
		assert(ResourceLoader.exists(icon_path))
		assert(load(texture_path) is Texture2D)
		assert(load(icon_path) is Texture2D)
		world.item_database[item_id] = pickaxe_data

	world.item_database["dirt"] = item_database_node.get_item_data("dirt")
	world.item_database["electric_wire"] = item_database_node.get_item_data("electric_wire")
	world.item_database["world_lock"] = item_database_node.get_item_data("world_lock")
	root.add_child(world)

	var gameplay_manager = ITEM_GAMEPLAY_MANAGER_SCRIPT.new()
	world.add_child(gameplay_manager)
	gameplay_manager.setup(world)
	for item_id in PICKAXE_ITEM_IDS:
		world.equipped_tool = item_id
		assert(gameplay_manager.get_current_break_power("world_lock") == 1)

	world.equipped_tool = "void_pickaxe"
	assert(gameplay_manager.get_required_break_hits("world_lock", 8) == 7)
	assert(gameplay_manager.get_required_break_hits("dirt", 3) == 2)
	assert(gameplay_manager.get_required_break_hits("electric_wire", 1) == 1)

	for item_id in PICKAXE_ITEM_IDS:
		if item_id == "void_pickaxe":
			continue
		world.equipped_tool = item_id
		assert(gameplay_manager.get_required_break_hits("world_lock", 8) == 8)

	world.equipped_tool = ""
	assert(gameplay_manager.get_required_break_hits("world_lock", 8) == 8)

	print("[pickaxe-items] success")
	item_database_node.free()
	world.queue_free()
	await process_frame
	quit(0)
