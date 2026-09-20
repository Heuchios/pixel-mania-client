extends SceneTree
func _initialize():
	call_deferred("check")
func check():
	var script = load("res://Scripts/chat_ui.gd")
	assert(script.can_instantiate())
	var chat = script.new()
	var label = RichTextLabel.new()
	chat.append_chat_run(label, "<name> [color=red]literal", Color.WHITE)
	assert(label.get_parsed_text() == "<name> [color=red]literal")
	label.free()
	chat.free()
	print("CHAT_FORMAT_OK")
	quit()
