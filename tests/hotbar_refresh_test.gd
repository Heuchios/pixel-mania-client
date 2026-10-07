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
	var equipped_tool = ""
	var equipped_back_item = ""
# Load the manager after project autoloads (including MobileUIScale) are ready.
const MANAGER_SOURCE := """
extends "res://Scripts/inventory_manager.gd"
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
"""
var failures := 0
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func _init():
	call_deferred("run")
func run():
	create_timer(20).timeout.connect(func(): quit(1))
	var manager_script := GDScript.new()
	manager_script.source_code = MANAGER_SOURCE
	check(manager_script.reload() == OK, "Hotbar manager must compile")
	var manager = manager_script.new()
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
	var equipped = manager.hotbar_slots[1].get_node("Equipped") as TextureRect
	check(not equipped.visible, "Selecting a tool must not mark it as equipped")
	world.equipped_tool = "pickaxe"
	manager.request_inventory_hud_refresh()
	manager.process_queued_inventory_hud_refresh()
	check(equipped.visible, "Equipping must update the hotbar while the bag is closed")
	check(equipped.texture == UIAtlasDB.get_texture("item_equipped_overlay"), "Hotbar must use the inventory equipped artwork")
	check(equipped.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The equipped overlay must not intercept slot taps")
	world.selected_item_type = "dirt"
	world.selected_item_category = "block"
	manager.refresh_hotbar_live()
	check(equipped.visible, "Selecting a block must retain the equipped tool indicator")
	check(not manager.hotbar_slots[2].get_node("Equipped").visible, "Ordinary blocks must not show an equipped indicator")
	world.equipped_tool = "screwdriver"
	manager.refresh_hotbar_live()
	check(not equipped.visible, "Switching equipment must remove the old tool indicator")
	world.equipped_back_item = "angel_wings"
	manager.update_scene_hotbar_slot_equipped(manager.hotbar_slots[1], "angel_wings", "back")
	check(equipped.visible, "Wearables must also show their equipped state")
	world.equipped_back_item = ""
	manager.update_scene_hotbar_slot_equipped(manager.hotbar_slots[1], "angel_wings", "back")
	check(not equipped.visible, "Unequipping must clear the indicator")
	world.selected_item_type = "pickaxe"
	world.selected_item_category = "tool"
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
