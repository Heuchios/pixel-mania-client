extends SceneTree

const EMOTES = preload("res://Scripts/player_emotes.gd")
const FACES = preload("res://Assets/player/expressions/face_expressions.tres")
var failures := 0

class ChatProbe extends RefCounted:
	var messages: Array[String] = []
	func add_chat_message(_sender: String, message: String) -> void: messages.append(message)

class WorldProbe extends Node:
	var in_world := true
	var blocked := false
	var dead := false
	var player: Node2D
	var player_manager: Node
	var netfox_real_manager: Node
	var ui_layer: Node
	var emotes_ui: Control
	var gameplay_ui_manager: Node
	var chat_ui := ChatProbe.new()
	func is_gameplay_hud_blocked() -> bool: return blocked
	func is_player_dead_or_respawning() -> bool: return dead

class RemoteProbe extends Node:
	var remote_players := {}

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var world := WorldProbe.new()
	root.add_child(world)
	world.player = make_actor()
	world.add_child(world.player)
	world.player_manager = RemoteProbe.new()
	world.add_child(world.player_manager)
	var remote := make_actor()
	world.add_child(remote)
	world.player_manager.remote_players["remote"] = remote
	var manager = load("res://Scripts/gameplay_ui_manager.gd").new()
	world.add_child(manager)
	manager.world = world
	world.gameplay_ui_manager = manager
	var network = root.get_node("NetworkManager")
	network.current_world_name = "TEST"
	network.player_id = "local"
	var packet := {"world": "TEST", "player_id": "remote", "emote": "laugh", "sequence": 1}
	manager.handle_player_emote(packet)
	check(EMOTES.active_face(remote, "idle") == "laugh", "Remote emote routes to the right actor")
	remote.get_node("PlayerEmotes").elapsed = 0.8
	manager.handle_player_emote(packet)
	check(remote.get_node("PlayerEmotes").elapsed == 0.8, "Repeated events do not restart gestures")
	manager.handle_player_emote({"world": "OTHER", "player_id": "remote", "emote": "sad", "sequence": 2})
	check(EMOTES.active_face(remote, "idle") == "laugh", "Other worlds cannot trigger gestures")
	world.player_manager.remote_players["reconnected"] = remote
	manager.handle_player_emote({"world": "TEST", "player_id": "reconnected", "emote": "sad", "sequence": 1})
	check(EMOTES.active_face(remote, "idle") == "sad", "A reconnected sender can restart its sequence on a surviving avatar")
	manager.handle_player_emote({"world": "TEST", "player_id": "local", "emote": "sad", "sequence": 2})
	check(EMOTES.active_face(world.player, "idle") == "", "Local echo does not replay")
	check(not network.send_player_emote("wave"), "Unauthenticated clients cannot send emotes")
	var transport = load("res://tests/fixtures/player_emotes_network_probe.gd").new()
	world.add_child(transport)
	transport.current_world_name = "TEST"
	transport.world_entry_active = true
	check(transport.send_player_emote("wave"), "Authenticated emote sends")
	check(transport.sent.size() == 1 and transport.sent[0].emote == "wave" and transport.sent[0].world == "TEST", "Packet carries the emote and current world")
	check(not transport.send_player_emote("sad"), "Network sender has its own rate limit")
	check(not transport.send_player_emote("invalid"), "Invalid network emote rejected")
	var dance_transport = load("res://tests/fixtures/player_emotes_network_probe.gd").new()
	world.add_child(dance_transport)
	dance_transport.current_world_name = "TEST"
	dance_transport.world_entry_active = true
	check(dance_transport.send_player_emote("dance"), "Dance is accepted by the network sender")
	check(dance_transport.sent[0].emote == "dance", "Dance uses its own wire ID")
	manager.handle_player_emote({"world": "TEST", "player_id": "remote", "emote": "dance", "sequence": 3})
	check(remote.get_meta("player_emote_id") == "dance", "Remote dance starts on the sender's avatar")
	remote.get_node("PlayerEmotes")._process(0.25)
	check(remote.get_node("PlayerVisual/LeftFoot").rotation != 0.0, "Remote dance animates the feet")
	var face_manager = load("res://Scripts/player_animation_manager.gd").new()
	world.add_child(face_manager)
	face_manager.player = world.player
	for id in EMOTES.DURATIONS:
		var face: String = EMOTES.face_for_emote(id)
		check(FACES.has_animation(face), "Atlas has face for " + id)
		check(FACES.get_frame_texture(face, 0).get_size() == Vector2(32, 32), "Aligned canvas for " + id)
		check(EMOTES.play(world.player, id), "Can play " + id)
		check(face_manager.get_face_expression_animation_name("idle") == face, "Face selection for " + id)
		var controller = world.player.get_node("PlayerEmotes")
		controller._process(0.25)
		var changed := false
		for pose in controller.poses:
			changed = changed or pose.node.position != pose.position or pose.node.rotation != pose.rotation
		check(changed, id + " animates the body")
		if id == "wave":
			var near_arm: Node2D = world.player.get_node("PlayerVisual/RightArm")
			var far_arm: Node2D = world.player.get_node("PlayerVisual/LeftArm")
			var held_item: Node2D = world.player.get_node("PlayerVisual/HandItem")
			var hand_tip := near_arm.transform * Vector2(-6, 10)
			check(hand_tip.x > -6.0 and hand_tip.y < 2.0, "Wave raises the near hand forward toward the face")
			check(far_arm.position == Vector2.ZERO and far_arm.rotation == 0.0, "The other arm stays at rest")
			check(is_equal_approx(held_item.rotation, near_arm.rotation), "Held item follows the waving arm")
		if id == "dance":
			for pose in controller.poses:
				check(pose.node.position != pose.position or pose.node.rotation != pose.rotation, "Dance moves " + str(pose.node.name))
			check(world.player.position == Vector2.ZERO, "Dance never moves the authoritative actor")
		controller._process(5.0)
		if id == "dance":
			check(EMOTES.active_face(world.player, "idle") == face, "Dance continues past its former timeout")
			controller._process(3600.0)
			check(EMOTES.active_face(world.player, "idle") == face, "Dance and its face continue after an hour of simulated idle time")
			var before: Vector2 = world.player.get_node("PlayerVisual/RightArm").position
			controller._process(0.2)
			check(not world.player.get_node("PlayerVisual/RightArm").position.is_equal_approx(before), "Long-running dance keeps animating without fading or freezing")
			EMOTES.cancel(world.player)
		else:
			check(EMOTES.active_face(world.player, "idle") == "", id + " expires")
		check(world.player.get_node("PlayerVisual/Head").position == Vector2(1, 0), "Original head pose restored")
		check(world.player.get_node("PlayerVisual/RightArm").z_index == 50, "Original arm draw order preserved")
		check(world.player.get_node("PlayerVisual/RightArm").rotation == 0.0 and world.player.get_node("PlayerVisual/HandItem").rotation == 0.0, "Arm and held item return to rest")
	EMOTES.play(world.player, "wave")
	check(face_manager.get_face_expression_animation_name("jump") == "jump", "Jump takes priority")
	check(EMOTES.active_face(world.player, "idle") == "", "Movement cancels emote")
	EMOTES.play(world.player, "sad")
	world.player.set_meta("face_hurt_until_msec", Time.get_ticks_msec() + 1000)
	world.player.get_node("PlayerEmotes")._process(0.1)
	check(EMOTES.active_face(world.player, "idle") == "", "Damage cancels emote")
	world.player.set_meta("face_hurt_until_msec", 0)
	check(not EMOTES.play(world.player, "invalid"), "Unknown gesture rejected")
	var commands = load("res://Scripts/command_manager.gd").new()
	world.add_child(commands)
	commands.setup(world)
	for command in ["/dance", "/sad", "/wave", "/lol", "  /DANCE  "]:
		manager.last_emote_msec = -1000
		commands.handle_command(command)
		var id: String = EMOTES.COMMANDS[command.strip_edges().substr(1).to_lower()]
		check(world.player.get_meta("player_emote_id") == id, command + " reaches the actual local emote controller")
	check(world.chat_ui.messages.is_empty(), "Emote commands bypass admin permissions and do not enter chat")
	commands.handle_command("/sad")
	check(world.player.get_meta("player_emote_id") == "dance", "Commands share the menu's cooldown")
	check(world.chat_ui.messages.back().contains("Wait a moment"), "Cooldown gives chat feedback")
	commands.handle_command("/dance extra")
	check(world.chat_ui.messages.back() == "Use: /dance", "Commands explain unexpected arguments")
	for unavailable in ["dead", "blocked", "outside"]:
		EMOTES.cancel(world.player)
		manager.last_emote_msec = -1000
		world.dead = unavailable == "dead"
		world.blocked = unavailable == "blocked"
		world.in_world = unavailable != "outside"
		commands.handle_command("/dance")
		check(world.player.get_meta("player_emote_id") == "", "Cannot dance while " + unavailable)
	world.dead = false
	world.blocked = false
	world.in_world = true
	commands.show_player_help()
	check(world.chat_ui.messages.any(func(message: String): return message.contains("/dance") and message.contains("/lol")), "Help lists the emote commands")
	for state in EMOTES.INTERRUPT_STATES:
		EMOTES.play(world.player, "dance")
		world.player.get_node("PlayerEmotes")._process(0.25)
		check(EMOTES.active_face(world.player, state) == "", state + " interrupts dance")
		for part_name in ["LeftArm", "LeftFoot", "RightFoot", "Bottom", "BackSlot"]:
			var part = world.player.get_node("PlayerVisual/" + part_name)
			check(part.position.is_zero_approx() and is_zero_approx(part.rotation), state + " restores " + part_name + " (" + str(part.position) + ", " + str(part.rotation) + ")")
	for actor in [world.player, remote]:
		for timer in ["face_punch_until_msec", "face_hurt_until_msec"]:
			EMOTES.play(actor, "dance")
			var controller = actor.get_node("PlayerEmotes")
			controller._process(60.0)
			actor.set_meta(timer, Time.get_ticks_msec() + 1000)
			controller._process(0.1)
			check(str(actor.get_meta("player_emote_id")) == "", timer + " cancels a long-running dance locally and remotely")
			actor.set_meta(timer, 0)
	EMOTES.play(remote, "dance")
	remote.hide()
	remote.get_node("PlayerEmotes")._process(60.0)
	check(str(remote.get_meta("player_emote_id")) == "dance", "Camera culling does not end an idle remote dance")
	remote.show()
	remote.get_node("PlayerEmotes")._process(0.25)
	check(remote.get_node("PlayerVisual/LeftArm").rotation != 0.0, "Remote dance resumes rendering when visible")
	remote.hide()
	remote.set_meta("animation_state", "walk")
	remote.get_node("PlayerEmotes")._process(0.1)
	check(str(remote.get_meta("player_emote_id")) == "", "Offscreen movement still interrupts a remote dance")
	remote.set_meta("animation_state", "idle")
	remote.show()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	world.ui_layer = viewport
	manager.setup_emotes_ui()
	manager.setup_emotes_ui()
	check(viewport.get_child_count() == 1, "HUD setup is idempotent")
	var menu = world.emotes_ui
	await process_frame
	check(menu.choices.get_child_count() == 5, "Four choices and title")
	check(menu.choices.has_node("Dance"), "Dance is available in the dropdown")
	check(menu.emotes_button.position.y == 268.0, "Emote button is directly below chat")
	var selections: Array[String] = []
	menu.emote_selected.connect(func(id: String): selections.append(id))
	menu.set_emotes_panel_open(true)
	menu.choices.get_node("Wave").pressed.emit()
	check(selections == ["wave"] and not menu.is_panel_open, "Selecting closes the dropdown and emits gesture")
	menu._select("sad")
	check(selections.size() == 1, "Selection cooldown suppresses rapid clicks")
	menu.last_selection_msec = -1000
	manager.last_emote_msec = -1000
	menu.choices.get_node("Dance").pressed.emit()
	check(selections == ["wave", "dance"] and world.player.get_meta("player_emote_id") == "dance", "Dance menu button reaches the same gameplay controller")
	menu.set_emotes_panel_open(true)
	check(menu.is_emotes_ui_at_point(Vector2(20, 20)), "Open popup blocks click-through")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.position = Vector2(20, 20)
	menu._input(click)
	check(not menu.is_panel_open, "Outside click closes")
	menu.set_emotes_panel_open(true)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_ESCAPE
	menu._input(key)
	check(not menu.is_panel_open, "Escape closes")
	viewport.size = Vector2i(854, 480)
	menu.set_emotes_panel_open(true)
	await process_frame
	menu.update_emotes_layout()
	var rect: Rect2 = menu.emotes_panel.get_global_rect()
	check(Rect2(Vector2.ZERO, viewport.size).encloses(rect), "Dropdown stays within a short viewport")
	var mobile_scale = root.get_node("MobileUIScale")
	var old_script = mobile_scale.get_script()
	mobile_scale.set_script(load("res://tests/fixtures/player_emotes_mobile_probe.gd"))
	mobile_scale.ui_scale = 1.5
	menu.update_emotes_layout()
	check(Rect2(Vector2.ZERO, viewport.size).encloses(menu.emotes_button.get_global_rect()), "Large mobile button stays on screen")
	check(Rect2(Vector2.ZERO, viewport.size).encloses(menu.emotes_panel.get_global_rect()), "Large mobile menu stays on screen")
	mobile_scale.set_script(old_script)
	EMOTES.play(world.player, "dance")
	world.blocked = true
	menu._process(0.0)
	check(not menu.visible and str(world.player.get_meta("player_emote_id")) == "dance", "Opening a menu keeps an idle dance running")
	world.blocked = false
	world.in_world = false
	menu._process(0.0)
	check(str(world.player.get_meta("player_emote_id")) == "", "Leaving the world clears an ongoing dance")
	world.in_world = true
	EMOTES.play(world.player, "dance")
	world.dead = true
	menu._process(0.0)
	check(not menu.visible and not menu.is_panel_open, "Death closes and hides the menu")
	check(str(world.player.get_meta("player_emote_id")) == "", "Death cancels an ongoing dance")
	world.free()
	viewport.free()
	if failures == 0: print("[player-emotes] PASS: faces, gestures, interruption, remote routing, dedupe, HUD layout and dropdown input")
	quit(1 if failures else 0)

func make_actor() -> Node2D:
	var actor := Node2D.new()
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	actor.add_child(visual)
	for part_name in ["LeftArm", "RightArm", "HandItem", "Head", "Body", "Bottom", "LeftFoot", "RightFoot", "BackSlot"]:
		var part := Node2D.new()
		part.name = part_name
		if part_name == "Head": part.position = Vector2(1, 0)
		if part_name == "RightArm": part.z_index = 50
		visual.add_child(part)
	return actor
