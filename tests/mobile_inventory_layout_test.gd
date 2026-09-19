extends SceneTree

const INVENTORY_SCENE = preload("res://Scenes/ui/inventory/InventoryScene.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory = INVENTORY_SCENE.instantiate()
	root.add_child(inventory)
	await process_frame

	var items: Array = []
	for item_index in range(10):
		items.append({
			"id": "layout_item_%d" % item_index,
			"display_name": "Layout Item %d" % item_index,
			"category": "block",
			"count": [1, 2, 23, 344, 999][item_index % 5],
			"rarity": "common"
		})
	inventory.set_inventory_items(items)
	await process_frame

	var window := inventory.get_node("Window") as Control
	var tabs := inventory.get_node("Window/Tabs") as VBoxContainer
	var inventory_scroll := inventory.get_node("Window/InventoryScroll") as ScrollContainer
	var inventory_grid := inventory.get_node("Window/InventoryScroll/InventoryGrid") as GridContainer
	var detail_skin := inventory.get_node("Window/DetailSkin") as Control

	assert(window != null)
	assert(tabs != null)
	assert(inventory_scroll != null)
	assert(inventory_grid != null)
	assert(detail_skin != null)
	assert(inventory_grid.columns == 10)

	var visible_slots: Array[Control] = []
	for child in inventory_grid.get_children():
		if child is Control and child.visible and str(child.name).begins_with("Slot_"):
			visible_slots.append(child as Control)
	assert(visible_slots.size() == 10)
	for slot in visible_slots:
		assert(slot.custom_minimum_size.is_equal_approx(Vector2(96, 96)))
		_assert_count_in_corner(slot)

	var tab_button := tabs.get_node("Tab_all") as Button
	assert(tab_button.custom_minimum_size.is_equal_approx(Vector2(72, 72)))
	inventory.set_current_tab("blocks")
	inventory.set_current_tab("all")
	await process_frame
	for slot in visible_slots:
		_assert_count_in_corner(slot)
	assert(inventory_grid.get_combined_minimum_size().x <= inventory_scroll.size.x)
	assert(tabs.position.x + tabs.size.x <= inventory_scroll.position.x)

	inventory.set_drawer_window_transform(Vector2(700, 180), 1.12)
	await process_frame
	assert(window.scale.is_equal_approx(Vector2(1.12, 1.12)))
	assert(visible_slots[0].custom_minimum_size.is_equal_approx(Vector2(96, 96)))
	assert(tab_button.custom_minimum_size.is_equal_approx(Vector2(72, 72)))

	var font_manager_source := FileAccess.get_file_as_string("res://Scripts/ui/global_font_manager.gd")
	assert(not font_manager_source.contains("_scale_custom_minimum_size"))
	assert(not font_manager_source.contains("_scale_theme_overrides"))

	print("[mobile-inventory-layout] success")
	quit(0)


func _assert_count_in_corner(slot: Control) -> void:
	var frame := slot.get_node("Frame") as Control
	var count := slot.get_node("Count") as Label
	assert(count.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(count.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM)
	assert((frame.get_rect().end - count.get_rect().end).is_equal_approx(Vector2(8, 8)),
		"Stack counts must stay inset from the visible frame, including offset templates")
