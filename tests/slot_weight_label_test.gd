extends SceneTree

class FishWorld extends Node:
	var fish_inventory := {"bass": 791}

func _init() -> void:
	call_deferred("run")

func verify(slot: Control, frame_name: String) -> void:
	var label: Label = slot.get_node("Count")
	var frame: Control = slot.get_node(frame_name)
	var rect := label.get_rect()
	assert(frame.get_rect().encloses(rect), "Quantity label escaped its slot frame")
	var text_width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	assert(text_width <= label.size.x - 4, "Complete weight must fit without clipping kg")
	assert(label.text.ends_with(" kg"), "Weight unit must be retained")

func run() -> void:
	var inventory = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(inventory)
	var hotbar = load("res://Scenes/ui/hotbar/Hotbar.tscn").instantiate()
	root.add_child(hotbar)
	var world := FishWorld.new()
	var manager = load("res://Scripts/inventory_manager.gd").new()
	manager.world = world
	for amount in [791, 1569, 883, 9990, 20000, 1, 791]:
		world.fish_inventory.bass = amount
		manager.update_scene_hotbar_slot_count(hotbar.get_node("Slot_0"), "bass", "fish")
		inventory.set_inventory_items([{"id":"bass", "category":"fish", "count":amount, "rarity":"uncommon"}])
		await process_frame
		await process_frame
		verify(hotbar.get_node("Slot_0"), "SlotFrame")
		verify(inventory.slot_nodes["fish:bass"], "Frame")
		assert(hotbar.get_node("Slot_0/Count").get_theme_font_size("font_size") == inventory.slot_nodes["fish:bass"].get_node("Count").get_theme_font_size("font_size"), "Hotbar weight must match inventory typography")
	manager.free()
	world.free()
	inventory.free()
	hotbar.free()
	print("[slot-weight-label] PASS: hotbar and inventory, changing weights through 2000.0 kg")
	quit(0)
