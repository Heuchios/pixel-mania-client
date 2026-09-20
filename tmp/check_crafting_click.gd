extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	root.size = Vector2i(1400, 900)
	var ui := Control.new()
	root.add_child(ui)
	var crafting = load("res://tmp/crafting_click_fixture.gd").new()
	ui.add_child(crafting)
	crafting.setup(null, ui)
	var blocker := Control.new()
	blocker.size = Vector2(2000, 1200)
	ui.add_child(blocker)
	crafting.open_crafting(Vector2i(3, 4))
	await create_timer(0.3).timeout
	var button = crafting.recipe_root.get_child(0).get_node("CraftButton")
	var pos = button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	print("CRAFT_CLICK_REQUESTS=", crafting.requests, " pos=", pos)
	quit(0 if crafting.requests == 1 else 1)
