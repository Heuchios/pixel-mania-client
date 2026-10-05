extends SceneTree

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

class PhoneScale extends "res://Scripts/ui/mobile_ui_scale.gd":
	func is_mobile() -> bool:
		return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1400, 650)
	var scaling = root.get_node("MobileUIScale")
	scaling.set_script(PhoneScale)
	var chat = load("res://Scenes/ui/chat/ChatScene.tscn").instantiate()
	root.add_child(chat)
	chat.set_process(false)
	chat.add_chat_message("System", "Chat ready!")
	chat.add_chat_message("System", "Rayan entered, TEST [NOPUNCH, NOTALK] (Honors: #2 overall). This world is locked by USO. 1 other here.")
	chat.add_chat_message("UCE", "yooo")
	chat.add_chat_message("Rayan", "yoo man! This longer message checks wrapping and line spacing with the larger text. ".repeat(3))
	for factor in [1.25, 1.5]:
		scaling.ui_scale = factor
		chat.chat_panel_amount = 1.0
		chat.chat_panel_target = 1.0
		chat.update_chat_position()
		await process_frame
		await process_frame
		root.get_node("GlobalFontManager").apply_to_node_tree(chat)
		await process_frame
		for label in chat.chat_messages_root.get_children():
			if not label is RichTextLabel or label.is_queued_for_deletion():
				continue
			var font := label.get_theme_font("normal_font") as FontFile
			assert(font != null and font.multichannel_signed_distance_field)
			assert(label.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
			assert(label.get_theme_font_size("normal_font_size") == 22)
			assert(label.get_theme_color("font_shadow_color").a == 0.0)
			assert(label.size.y >= label.get_content_height(), "Larger chat lines are clipped")
			if "longer message" in label.get_parsed_text():
				assert(label.get_line_count() > 1, "Long messages must wrap inside the drawer")
		assert((chat.chat_input.get_theme_font("font") as FontFile).multichannel_signed_distance_field)
		assert(not (PixelUIStyle.get_game_font() as FontFile).multichannel_signed_distance_field, "Chat must not change the rest of the game's font")
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("D:/Pixelmania/work/chat-clear-%d.png" % int(factor * 100))
	chat.free()
	print("CHAT_READABILITY_PASS")
	quit()
