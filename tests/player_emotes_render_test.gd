extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var preview: Node = load("res://Scenes/debug/player_emotes_preview.tscn").instantiate()
	viewport.add_child(preview)
	await create_timer(0.45).timeout
	if preview.actors.size() != 4 or not is_instance_valid(preview.menu):
		push_error("Preview failed to assemble avatars and menu")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://previews")
	var result := viewport.get_texture().get_image().save_png("res://previews/player_emotes_preview.png")
	if result == OK: print("[player-emotes-render] Saved assembled avatars and real HUD dropdown")
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
