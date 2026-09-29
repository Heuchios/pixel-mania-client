extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1500, 190)
	var background := ColorRect.new()
	background.color = Color("321a3c")
	background.size = Vector2(1500, 190)
	root.add_child(background)
	var chat = load("res://Scripts/chat_ui.gd").new()
	var rows := VBoxContainer.new()
	rows.position = Vector2(24, 50)
	rows.size = Vector2(1452, 120)
	root.add_child(rows)
	chat.chat_messages_root = rows
	chat.using_authored_scene_layout = true
	var metadata := {"type": "chat", "player_id": "system", "world": "SHOP", "world_entry_key": "SHOP:preview"}
	chat.add_chat_message("System", "World Honors for SHOP: Today #1 | Yesterday #309 | Overall #1. Use /honors for rankings.", metadata)
	chat.add_chat_message("System", "Uso entered, SHOP [NOPUNCH, NOGRAVITY]. This world is locked by LOL, 0 others here.", metadata)
	assert(chat.chat_messages.size() == 1)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(rows.get_child_count() == 1)
	root.get_texture().get_image().save_png("D:/Pixelmania/world-entry-color-preview.png")
	chat.free()
	quit()
