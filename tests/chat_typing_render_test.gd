extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var preview: Node = load("res://Scenes/debug/chat_typing_preview.tscn").instantiate()
	viewport.add_child(preview)
	await process_frame
	preview.chat.chat_input.grab_focus()
	preview.chat.chat_input.text = "Hello!"
	preview.chat.chat_input.text_changed.emit("Hello!")
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var path := "res://previews/chat_typing_preview.png"
	DirAccess.make_dir_recursive_absolute("res://previews")
	var result := viewport.get_texture().get_image().save_png(path)
	if result == OK: print("[chat-typing-render] Saved both facing directions: " + path)
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
