extends SceneTree

const ChatBubbleComponent = preload("res://Scripts/chat_bubble_component.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bubble = ChatBubbleComponent.new()
	root.add_child(bubble)
	await process_frame

	bubble.show_chat_message("This overhead message fits its bubble.")
	await process_frame
	var chat_label := bubble.get_node("Label") as Label
	var chat_font := chat_label.get_theme_font("font")
	var expected_chat_height := ChatBubbleComponent.measure_text_block_height(
		chat_label.text,
		chat_font,
		ChatBubbleComponent.CHAT_BUBBLE_FONT_SIZE
	)
	assert(chat_label.get_theme_font_size("font_size") == 24)
	assert(chat_label.label_settings != null)
	assert(chat_label.label_settings.font_size == 24)
	assert(ChatBubbleComponent.get_widest_line_width(chat_label.text, chat_font, 24) <= chat_label.size.x)
	assert(is_equal_approx(chat_label.size.y, expected_chat_height))
	assert(is_equal_approx(bubble.size.y, chat_label.size.y + ChatBubbleComponent.CHAT_BUBBLE_PAD_Y * 2.0))
	assert(is_equal_approx(bubble.size.x, chat_label.size.x + ChatBubbleComponent.CHAT_BUBBLE_PAD_X * 2.0))

	bubble.show_notification_message("Anti-talk disabled.", Color(1.0, 0.7, 0.1))
	bubble.show_notification_message("Anti-talk enabled.", Color(1.0, 0.7, 0.1))
	await process_frame
	await process_frame
	var notification_stack := bubble.get_node("NotificationStack") as VBoxContainer
	assert(notification_stack.get_child_count() == 2)
	var older_label := notification_stack.get_child(0) as Label
	var newest_label := notification_stack.get_child(1) as Label
	assert(older_label.get_theme_font_size("font_size") == 24)
	assert(newest_label.get_theme_font_size("font_size") == 24)
	assert(older_label.text == "Anti-talk disabled.")
	assert(newest_label.text == "Anti-talk enabled.")
	assert(ChatBubbleComponent.get_widest_line_width(older_label.text, chat_font, 24) <= older_label.size.x)
	assert(ChatBubbleComponent.get_widest_line_width(newest_label.text, chat_font, 24) <= newest_label.size.x)
	assert(newest_label.position.y > older_label.position.y)

	var expected_stack_height := older_label.size.y + newest_label.size.y + ChatBubbleComponent.NOTIFICATION_STACK_GAP
	assert(is_equal_approx(notification_stack.size.y, expected_stack_height))
	assert(is_equal_approx(bubble.size.y, expected_stack_height + ChatBubbleComponent.CHAT_BUBBLE_PAD_Y * 2.0))
	assert(is_equal_approx(bubble.size.x, notification_stack.size.x + ChatBubbleComponent.CHAT_BUBBLE_PAD_X * 2.0))

	bubble.queue_free()
	print("[chat-bubble-layout] success")
	quit(0)
