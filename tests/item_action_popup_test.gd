extends SceneTree

const POPUP = preload("res://Scenes/ui/inventory/ItemActionPopup.tscn")
var emitted_amount := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var popup = POPUP.instantiate()
	root.add_child(popup)
	popup.open_popup({"id": "dirt", "category": "block", "display_name": "Dirt",
		"count": 344, "rarity": "common", "spliceable": true, "description": "The usual stuff."})
	await create_timer(0.2).timeout
	assert(popup.is_open(), "First selection must survive the popup's deferred ready events")
	var window: Control = popup.get_node("Window")
	var slider: HSlider = window.get_node("AmountSlider")
	var input: LineEdit = window.get_node("AmountInput")
	assert(popup.get_node("Window/ItemName").text == "Dirt")
	assert(popup.get_node("Window/ItemCount").visible)
	assert(slider.get_theme_icon("grabber").get_width() >= 20)
	assert(not input.get_rect().intersects(window.get_node("DescriptionLabel").get_rect()))
	# Exercise actual pointer input at each end, not just the slider callback.
	await _click(slider.get_global_rect().position + Vector2(2, slider.get_global_rect().size.y / 2))
	assert(popup.amount == 1)
	await _click(slider.get_global_rect().end - Vector2(2, slider.get_global_rect().size.y / 2))
	assert(popup.amount == 344)
	assert(input.text == "344")
	input.text_changed.emit("9999")
	assert(popup.amount == 344)
	input.text_changed.emit("151")
	assert(slider.value == 151)
	popup.drop_requested.connect(func(item: Dictionary): emitted_amount = item.amount)
	await _click(window.get_node("DropButton").get_global_rect().get_center())
	assert(emitted_amount == 151, "The chosen quantity must reach the drop action unchanged")
	await create_timer(0.15).timeout
	for viewport_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		popup.open_popup({"id": "test", "category": "tool", "count": 1,
			"display_name": "An exceptionally long equipment name", "can_drop": false, "can_trash": false})
		await create_timer(0.2).timeout
		var bounds: Rect2 = popup._get_scaled_window_global_rect()
		assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(bounds), "Popup must fit phone viewports")
		assert(not slider.editable and not input.editable)
		assert(window.get_node("DropButton").disabled)
		assert(window.get_node("TrashButton").disabled)
	print("[item-action-popup] pointer quantity, payload, permissions, and phone layout passed")
	popup.queue_free()
	quit(0)


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.position = point
	button.pressed = true
	root.push_input(button)
	await process_frame
	button = button.duplicate()
	button.pressed = false
	root.push_input(button)
	await process_frame
