extends SceneTree

var failures := 0

class WorldFixture extends Node:
	var item_database: Dictionary = {}
	var inventory := {}
	var seed_inventory := {}
	var tool_inventory := {}
	var back_inventory := {}
	var hat_inventory := {}
	var hair_inventory := {}
	var eyewear_inventory := {}
	var beard_inventory := {}
	var shirt_inventory := {}
	var pants_inventory := {}
	var shoes_inventory := {}
	var ride_inventory := {}
	var body_accessory_inventory := {}
	var material_inventory := {}
	var lure_inventory := {}
	var fish_inventory := {}
	var currency_inventory := {}
	var equipped_beard_item := ""
	var block_items := []
	var equipped_tool := ""
	var equipped_back_item := ""
	var equipped_hat_item := ""
	var equipped_hair_item := ""
	var equipped_eyewear_item := ""
	var equipped_shirt_item := ""
	var equipped_pants_item := ""
	var equipped_shoes_item := ""
	var equipped_ride_item := ""
	var equipped_body_accessory_item := ""
	var gameplay: Node
	var saves := 0
	var sends := 0
	var visual_updates := 0
	var notices: Array = []
	func get_item_count(id: String, category: String) -> int:
		return gameplay.get_item_count(id, category)
	func is_item_equipable(id: String, category: String) -> bool:
		return gameplay.is_item_equipable(id, category)
	func get_inventory_slot_count() -> int:
		return 32
	func update_equipment_visual() -> void:
		visual_updates += 1
	func update_all_ui() -> void:
		pass
	func save_player_data() -> void:
		saves += 1
	func flush_multiplayer_position(_force := false, _appearance := true) -> void:
		sends += 1
	func show_notification(message: String) -> void:
		notices.append(message)
	func spend_item_from_inventory_stack(target: Dictionary, id: String, _category: String, count: int) -> int:
		target[id] = int(target[id]) - count
		return count

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := WorldFixture.new()
	var database = load("res://Scripts/item_database.gd").new()
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/wearable_expansion_20261012.json"))
	var gameplay = load("res://Scripts/item_gameplay_manager.gd").new()
	gameplay.world = world
	world.gameplay = gameplay
	var inventory = load("res://tests/fixtures/mask_inventory_probe.gd").new()
	inventory.world = world
	var drops = load("res://Scripts/drop_manager.gd").new()
	drops.world = world
	var ui = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(ui)
	for c in cases:
		if c.slot != "beard":
			continue
		world.item_database[c.id] = database.get_item_data(c.id)
		world.beard_inventory[c.id] = 1
		check(gameplay.get_item_count(c.id, "beard") == 1 and inventory.get_item_count(c.id, "beard") == 1, c.id + " inventory count")
		check(inventory._is_equipable_hotbar_category("beard"), "mask hotbar action")
		var pickup: Dictionary = drops.get_inventory_target_for_drop(c.id, "hat")
		check(pickup.get("category") == "beard" and is_same(pickup.get("inventory"), world.beard_inventory), c.id + " pickup uses catalog category")
		var signature: String = inventory.get_inventory_scene_signature()
		gameplay.toggle_equip_item(c.id, "beard")
		check(world.equipped_beard_item == c.id and world.saves > 0 and world.saves == world.sends, c.id + " equip persists and broadcasts")
		ui.set_inventory_from_world(world)
		var payload: Dictionary = ui._build_world_inventory_item(world, c.id, "beard", world.item_database)
		check(payload.get("display_category") == "Mask" and payload.get("equipable") == true and payload.get("equipped") == true, c.id + " mask inventory label, equipped state and action")
		ui.set_selected_item(c.id, "beard")
		check(ui.detail_category.text == "MASK", c.id + " rendered category label")
		gameplay.toggle_equip_item(c.id, "beard")
		check(world.equipped_beard_item == "", c.id + " unequip")
		gameplay.toggle_equip_item(c.id, "beard")
		check(inventory.remove_inventory_item(c.id, "beard", 1), c.id + " removal")
		check(world.equipped_beard_item == "" and world.beard_inventory[c.id] == 0, c.id + " remove last item clears visual")
		check(inventory.get_inventory_scene_signature() != signature, c.id + " mask count refresh")
		gameplay.toggle_equip_item(c.id, "beard")
		check(world.equipped_beard_item == "", c.id + " cannot equip unowned mask")
	check(inventory.changes == 14, "all fourteen mask removal paths")
	ui.free()
	drops.free()
	inventory.free()
	gameplay.free()
	world.free()
	database.free()
	print("MASK_INVENTORY: 14 masks, ownership, equip/unequip, save/broadcast, UI category, pickup routing, last-item removal; failures=", failures)
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("MASK_INVENTORY_FAIL: ", label)
