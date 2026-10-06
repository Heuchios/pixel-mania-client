extends SceneTree

const POPUP = preload("res://Scenes/ui/inventory/ItemActionPopup.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var popup = POPUP.instantiate()
	root.add_child(popup)
	popup.open_popup({"id": "dirt", "category": "block", "display_name": "Dirt", "count": 344,
		"rarity": "common", "spliceable": true, "has_properties": false, "farmable": true,
		"description": "The usual stuff."})
	await create_timer(0.2).timeout
	assert(popup.is_open())
	var window: Control = popup.get_node("Window")
	assert(window.get_node("ItemName").text == "Dirt")
	assert(window.get_node("ItemCount").text == "344 IN INVENTORY")
	assert(window.get_node("SpliceableLabel").text == "Spliceable: Yes")
	assert(window.get_node("PropertiesLabel").text == "Has Properties: No")
	assert(window.get_node("FarmableLabel").text == "Farmable: Yes")
	for removed in ["UseButton", "DropButton", "InfoButton", "TrashButton", "AmountInput", "AmountSlider"]:
		assert(not window.has_node(removed), "Info must be read-only")
	var previous_bottom := 0.0
	for label_name in ["TypeLabel", "RarityLabel", "SpliceableLabel", "PropertiesLabel", "FarmableLabel", "DescriptionLabel"]:
		var control: Control = window.get_node(label_name)
		assert(control.get_rect().position.y >= previous_bottom, "Item facts must not overlap")
		previous_bottom = control.get_rect().end.y
	for viewport_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		popup.open_popup({"id": "test", "category": "material", "type_label": "Material / Consumable", "count": 1,
			"display_name": "An exceptionally long equipment name", "description": "A long description. ".repeat(80)})
		await create_timer(0.2).timeout
		assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(popup._get_scaled_window_global_rect()))
		assert(window.get_node("PropertiesLabel").text == "Has Properties: No")
		assert(window.get_node("FarmableLabel").text == "Farmable: No")
		assert(window.get_node("DescriptionLabel").get_v_scroll_bar().max_value > window.get_node("DescriptionLabel").size.y)
		var touch := InputEventScreenTouch.new()
		touch.position = window.get_node("CloseButton").get_global_rect().get_center()
		touch.pressed = true
		root.push_input(touch)
		await create_timer(0.15).timeout
		assert(not popup.is_open(), "Touch must close Info")
	print("[item-action-popup] read-only facts, scrolling descriptions and phone close passed")
	popup.free()
	quit(0)
