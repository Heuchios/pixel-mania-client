extends SceneTree

const INVENTORY_SCENE = preload("res://Scenes/ui/inventory/InventoryScene.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory_scene: Control = INVENTORY_SCENE.instantiate() as Control
	root.add_child(inventory_scene)
	await process_frame

	var items: Array = []
	for item_index in range(90):
		var category: String = "block" if item_index < 45 else "material"
		items.append({
			"id": "perf_item_%d" % item_index,
			"display_name": "Performance Item %d" % item_index,
			"category": category,
			"count": item_index + 1,
			"rarity": "common"
		})
	inventory_scene.call("set_inventory_items", items)
	await process_frame

	var initial_slot_ids: Dictionary = {}
	var slot_nodes: Dictionary = inventory_scene.get("slot_nodes") as Dictionary
	assert(slot_nodes.size() == items.size())
	for raw_slot_key in slot_nodes.keys():
		var slot: Button = slot_nodes[raw_slot_key] as Button
		assert(slot != null)
		initial_slot_ids[str(raw_slot_key)] = slot.get_instance_id()

	inventory_scene.call("set_selected_item", "perf_item_0", "block")
	inventory_scene.call("set_selected_item", "perf_item_1", "block")
	var first_frame: CanvasItem = (slot_nodes["block:perf_item_0"] as Node).get_node("SelectedFrame") as CanvasItem
	var second_frame: CanvasItem = (slot_nodes["block:perf_item_1"] as Node).get_node("SelectedFrame") as CanvasItem
	assert(not first_frame.visible)
	assert(second_frame.visible)

	for cycle_index in range(20):
		inventory_scene.call("set_current_tab", "materials")
		inventory_scene.call("set_current_tab", "all")
	await process_frame

	slot_nodes = inventory_scene.get("slot_nodes") as Dictionary
	assert(slot_nodes.size() == items.size())
	for raw_slot_key in slot_nodes.keys():
		var slot: Button = slot_nodes[raw_slot_key] as Button
		assert(slot != null)
		assert(int(initial_slot_ids[str(raw_slot_key)]) == slot.get_instance_id())

	var visible_slot_keys: Dictionary = inventory_scene.get("visible_slot_keys") as Dictionary
	assert(visible_slot_keys.size() == items.size())
	print("[inventory-incremental-refresh] success")
	quit(0)
