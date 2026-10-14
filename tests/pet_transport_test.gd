extends SceneTree

const PetSystem = preload("res://Scripts/pet_system.gd")
const ItemDatabase = preload("res://Scripts/item_database.gd")
const Gameplay = preload("res://Scripts/item_gameplay_manager.gd")
const InventoryScene = preload("res://Scenes/ui/inventory/InventoryScene.tscn")
const PetTest = preload("res://tests/pets_test.gd")
class TransportWorld extends PetTest.TestWorld:
	var pet_system
	var gameplay
	var notifications: Array[String] = []
	var inventory := {}
	var seed_inventory := {}
	var tool_inventory := {}
	var back_inventory := {}
	var hat_inventory := {}
	var hair_inventory := {}
	var eyewear_inventory := {}
	var beard_inventory := {}
	var body_accessory_inventory := {}
	var shirt_inventory := {}
	var pants_inventory := {}
	var shoes_inventory := {}
	var ride_inventory := {}
	var currency_inventory := {}
	func update_all_ui(): pass
	func get_inventory_slot_count() -> int: return 60
	func show_notification(message): notifications.append(message)
	func is_item_equipable(id: String, category: String) -> bool: return gameplay.is_item_equipable(id,category)
	func toggle_equip_item(id: String, category: String) -> void: gameplay.toggle_equip_item(id,category)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	assert(load("res://Scripts/world.gd").can_instantiate())
	var original = root.get_node("NetworkManager")
	root.remove_child(original)
	original.queue_free()
	var network = load("res://tests/pet_network_capture.gd").new()
	network.name = "NetworkManager"
	network.current_world_name = "TEST"
	root.add_child(network)
	network.set_process(false)
	var world := TransportWorld.new()
	root.add_child(world)
	world.add_child(world.ui_layer)
	world.add_child(world.player)
	world.item_database = ItemDatabase.ITEMS.duplicate(true)
	world.pet_system = PetSystem.new()
	world.pet_system.world = world
	world.add_child(world.pet_system)
	world.pet_system.set_process(false)
	world.gameplay = Gameplay.new()
	world.gameplay.setup(world)
	world.add_child(world.gameplay)
	assert(world.is_item_equipable("frog_pet","pet"))
	world.toggle_equip_item("frog_pet","pet")
	assert(network.packets.back().action == "pet_equip")
	assert(network.packets.back().item_id == "frog_pet")
	assert(network.packets.back().world == "TEST")
	assert(network.packets.back().type == "inventory_transaction_request")
	world.pet_system.apply_result({"action":"pet_equip","ok":true,"equipped_pet_item":"frog_pet"})
	world.pet_system.update_followers()
	assert(world.pet_system.followers.has("local"))
	assert(world.pet_system.followers.local.target == world.player)
	var drops = load("res://Scripts/drop_manager.gd").new()
	drops.world = world
	root.add_child(drops)
	var pickup: Dictionary = drops.get_inventory_target_for_drop("frog_pet","material")
	assert(pickup.category == "pet")
	assert(pickup.inventory == world.pet_inventory)
	world.pet_system.open_station(Vector2i(2,3),"incubator")
	assert(network.packets.back().action == "incubator_get_state")
	for index in range(world.pet_system.selection.item_count):
		if world.pet_system.selection.get_item_metadata(index) == "golden_egg": world.pet_system.selection.select(index)
	world.pet_system.insert.pressed.emit()
	assert(network.packets.back().action == "incubator_insert")
	assert(network.packets.back().item_id == "golden_egg")
	assert(network.packets.back().x == 2 and network.packets.back().y == 3)
	for action in ["incubator_add_chunks","incubator_upgrade","incubator_claim","incubator_remove","sashimi_chop","pet_encounter"]:
		assert(network.send_inventory_transaction_request({"action":action,"item_id":"guppy","amount":750,"x":2,"y":3}))
		assert(network.packets.back().action == action)
	assert(network.packets.filter(func(p): return p.action == "incubator_add_chunks")[0].amount == 750)
	assert(not network.send_inventory_transaction_request({"action":"unknown_pet_action"}))
	# Typed SpinBox text must be applied before the Add button reads its value.
	world.pet_system.apply_state({"x":2,"y":3,"input_item":"frog_pet","chunks":0,"upgrade_cost":250})
	world.pet_system.count.value = 1
	world.pet_system.count.get_line_edit().grab_focus()
	world.pet_system.count.get_line_edit().text = "250"
	world.pet_system._process(0.01)
	assert(world.pet_system.count.get_line_edit().text == "250")
	world.pet_system.chunks.pressed.emit()
	assert(network.packets.back().action == "incubator_add_chunks")
	assert(network.packets.back().amount == 250)
	world.pet_system.apply_state({"x":2,"y":3,"input_item":"frog_pet","chunks":25,"upgrade_cost":250})
	world.pet_system.count.get_line_edit().text = "250"
	world.pet_system.chunks.pressed.emit()
	assert(network.packets.back().amount == 225)
	world.pet_system.apply_state({"x":2,"y":3,"input_item":"frog_pet_lvl2","chunks":0,"upgrade_cost":750})
	world.pet_system.count.get_line_edit().text = "750"
	world.pet_system.chunks.pressed.emit()
	assert(network.packets.back().amount == 750)
	world.material_inventory.fish_chunk = 40
	world.pet_system.refresh_ui()
	world.pet_system.count.get_line_edit().text = "750"
	world.pet_system.chunks.pressed.emit()
	assert(network.packets.back().amount == 40)
	world.pet_system.apply_state({"x":2,"y":3,"input_item":"frog_pet_lvl2","chunks":750,"upgrade_cost":750})
	assert(world.pet_system.chunks.disabled)
	var packet_count: int = network.packets.size()
	world.pet_system.chunks.pressed.emit()
	assert(network.packets.size() == packet_count)
	world.fish_inventory.guppy = 1500
	world.pet_system.open_station(Vector2i(4,3),"sashimi_table")
	world.pet_system.count.get_line_edit().text = "3"
	world.pet_system.chunks.pressed.emit()
	assert(network.packets.back().action == "sashimi_chop" and network.packets.back().amount == 3)
	network.authenticated = false
	assert(not world.pet_system.request("pet_equip",{"item_id":"frog_pet"}))
	assert(not world.notifications.is_empty())
	var inventory: Control = InventoryScene.instantiate()
	root.add_child(inventory)
	await process_frame
	inventory.set_inventory_from_world(world)
	inventory.set_current_tab("gear")
	assert(inventory.visible_slot_keys.has("pet:frog_pet"))
	inventory.set_current_tab("materials")
	assert(not inventory.visible_slot_keys.has("pet:frog_pet"))
	assert(world.item_database.frog_pet.category == "pet")
	print("PET_TRANSPORT_PASS: real sender, inventory equip, egg button, all pet actions, bulk typed chunks, remaining capacity, inventory limits, sashimi quantity, Gear category, unknown-action rejection and visible send failure")
	quit()

