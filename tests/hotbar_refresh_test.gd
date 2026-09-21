extends SceneTree
class FakeWorld extends Node:
	var hotbar_items = ["punch", "pickaxe", "dirt"]
	var hotbar_item_categories = ["tool", "tool", "block"]
	var selected_item_type = "pickaxe"
	var selected_item_category = "tool"
	var item_database = {"pickaxe": {}, "dirt": {}}
	var tool_inventory = {"pickaxe": 1}
	var inventory = {"dirt": 10}
	var block_items = []
	var seed_inventory = {}
	var lure_inventory = {}
class Manager extends "res://Scripts/inventory_manager.gd":
	var rebuilds := 0
	var counts := {}
	func update_hotbar():
		rebuilds += 1
		normalize_hotbar()
	func update_scene_hotbar_slot_frame(_slot, _rarity: String, _selected: bool, _item_type: String = "", _category: String = ""):
		pass
	func update_scene_hotbar_slot_count(_slot: Control, item_type: String, category: String):
		counts[item_type] = get_item_count(item_type, category)
	func get_item_rarity(_item_type: String, _category: String = "") -> String:
		return "common"
	func update_gem_counter():
		pass
var failures := 0
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func _init():
	call_deferred("run")
func run():
	var manager := Manager.new()
	var world := FakeWorld.new()
	manager.world = world
	manager.hotbar_root = Control.new()
	for i in range(3):
		var slot := Control.new()
		slot.set_meta("item_type", world.hotbar_items[i])
		slot.set_meta("category", world.hotbar_item_categories[i])
		manager.hotbar_root.add_child(slot)
		manager.hotbar_slots[i] = slot
	manager.refresh_hotbar_live()
	check(manager.rebuilds == 0, "Owned tools must remain without rebuilding")
	world.inventory.dirt = 4
	manager.refresh_inventory_item_live("dirt", "block")
	check(manager.inventory_hud_refresh_needs_hotbar, "Closed/unbuilt inventory must queue hotbar update")
	manager.inventory_last_hud_refresh_ms = Time.get_ticks_msec()
	manager.process_queued_inventory_hud_refresh()
	check(manager.counts.get("dirt") == 4, "Partial removal must update count without waiting for HUD throttle")
	check(manager.rebuilds == 0, "Count-only updates must not rebuild the hotbar")
	world.tool_inventory.pickaxe = 0
	manager.inventory_window_refresh_suspended = true
	manager.refresh_inventory_item_live("pickaxe", "tool")
	manager.process_queued_inventory_hud_refresh()
	check(not world.hotbar_items.has("pickaxe"), "Last dropped tool must disappear even during suspended inventory refresh")
	check(world.selected_item_type == "punch", "Depleted selected item must fall back to punch")
	check(world.hotbar_items.has("punch"), "Permanent punch must survive zero inventory count")
	world.inventory.dirt = 0
	manager.normalize_hotbar()
	check(not world.hotbar_items.has("dirt"), "Depleted blocks must disappear")
	check(manager.is_reserved_hotbar_tool("wrench", "tool"), "Permanent wrench must be exempt")
	manager.hotbar_root.free()
	manager.free()
	world.free()
	print("HOTBAR_REFRESH: %d failures" % failures)
	quit(1 if failures else 0)
