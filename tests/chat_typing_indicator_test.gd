extends SceneTree

var failures := 0

class WorldProbe extends Node:
	var in_world := true
	var player: Node2D
	var chat_ui: Control
	var player_animation_manager: Node
	var selected_item_type := ""
	var selected_item_category := ""
	var command := ""
	func is_chat_typing() -> bool: return in_world and chat_ui.is_chat_typing()
	func handle_network_player_position(_data: Dictionary) -> void: pass
	func handle_chat_command(value: String) -> void: command = value
	func get_item_count(_id: String, _category: String) -> int: return 0

func _init() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func edit(field: LineEdit, value: String) -> void:
	field.text = value
	field.text_changed.emit(value)

func run() -> void:
	var world := WorldProbe.new()
	root.add_child(world)
	current_scene = world
	var chat = load("res://Scripts/debug/chat_typing_preview_input.gd").new()
	world.add_child(chat)
	world.chat_ui = chat
	chat.world = world
	for kind in ["chat_input", "quick_chat_input"]:
		var field := LineEdit.new()
		chat.add_child(field)
		chat.set(kind, field)
		chat.wire_chat_input_activity(field)
	await process_frame
	for field: LineEdit in [chat.chat_input, chat.quick_chat_input]:
		field.grab_focus()
		check(not chat.is_chat_typing(), "An empty focused field is not typing")
		edit(field, " ")
		check(not chat.is_chat_typing(), "Whitespace is not a message")
		edit(field, "Hello")
		check(chat.is_chat_typing(), "Editing either chat input starts typing")
		chat.last_chat_edit_msec = Time.get_ticks_msec() - chat.TYPING_IDLE_TIMEOUT_MSEC
		check(not chat.is_chat_typing(), "Pausing stops the dots")
		edit(field, "Hello again")
		check(chat.is_chat_typing(), "Typing resumes after a pause")
		field.release_focus()
		check(not chat.is_chat_typing(), "Leaving the field stops typing")
		field.grab_focus()
		check(not chat.is_chat_typing(), "Refocusing a draft requires a new edit")
		edit(field, "Hello")
		chat.hide()
		check(not chat.is_chat_typing(), "Hidden chat does not emit typing")
		chat.show()
		field.grab_focus()
		edit(field, "")
		check(not chat.is_chat_typing(), "Clearing a draft stops typing")
		edit(field, "/preview")
		chat.send_chat_message()
		check(world.command == "/preview" and field.text == "" and not chat.is_chat_typing(), "Sending uses the normal chat lifecycle and stops typing")

	var actor := Node2D.new()
	world.add_child(actor)
	world.player = actor
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	actor.add_child(visual)
	var head := Node2D.new()
	head.name = "Head"
	head.position = Vector2(1, 0)
	visual.add_child(head)
	var manager = load("res://Scripts/player_animation_manager.gd").new()
	actor.add_child(manager)
	manager.player = actor
	manager.world = world
	chat.chat_input.grab_focus()
	edit(chat.chat_input, "Hello")
	manager.update_face_expression_animation("idle")
	var indicator: AnimatedSprite2D = head.get_node("ChatTypingIndicator")
	check(indicator.visible and indicator.is_playing(), "Actual local chat starts the head indicator")
	await create_timer(0.4).timeout
	check(indicator.frame > 0, "Dot frames advance while composing")
	for i in 3:
		var texture: AtlasTexture = indicator.sprite_frames.get_frame_texture("typing", i)
		check(texture.region == Rect2((7 + i) * 32, 64, 32, 32), "Exact requested atlas frame " + str(i))
	check(indicator.global_position.x > head.global_position.x and indicator.global_position.y < head.global_position.y, "Bubble sits forward and above the face")
	visual.scale.x = -1
	check(indicator.global_position.x < head.global_position.x, "Bubble mirrors to the front when facing left")
	indicator.set_frame_and_progress(1, 0.5)
	manager.update_face_expression_animation("idle")
	check(indicator.frame == 1 and is_equal_approx(indicator.frame_progress, 0.5), "Repeated updates do not restart the dot cycle")
	var network = root.get_node("NetworkManager")
	actor.set_meta("activity_bubble", "shop")
	check(network.get_player_motion_state().activity_bubble == "shop", "Activity presence is included in outgoing motion state")
	actor.set_meta("activity_bubble", "")
	check(network.get_player_motion_state().chat_typing, "Network payload uses actual chat activity")
	chat.release_chat_focus()
	check(not network.get_player_motion_state().chat_typing, "Network payload stops typing on focus loss")
	manager.update_face_expression_animation("idle")
	check(not indicator.visible and not indicator.is_playing(), "Stopped typing hides and resets the animation")
	actor.set_meta("remote_chat_typing", true)
	manager.update_face_expression_animation("idle")
	check(indicator.visible, "Remote typing uses the same head indicator")
	actor.set_meta("remote_last_receive_msec", Time.get_ticks_msec() - 16000)
	manager.update_face_expression_animation("idle")
	check(not indicator.visible, "Stale remote activity expires")
	actor.set_meta("remote_last_receive_msec", Time.get_ticks_msec())
	manager.update_face_expression_animation("dead")
	check(not indicator.visible, "Death suppresses the typing bubble")
	manager.update_face_expression_animation("idle")
	check(indicator.visible, "Live remote typing resumes")
	world.in_world = false
	manager.update_face_expression_animation("idle")
	check(not indicator.visible, "Leaving the world hides typing")
	world.free()
	if failures == 0: print("[chat-typing-indicator] PASS: both chat inputs, send/clear/blur/idle, atlas, mirrored alignment, local/remote lifecycle and network payload")
	quit(1 if failures else 0)
