extends SceneTree

const EMOTES = preload("res://Scripts/player_emotes.gd")
const FACES = preload("res://Assets/player/expressions/face_expressions.tres")
var failures := 0

class WorldProbe extends Node:
	var in_world := true
	var blocked := false
	var dead := false
	var player: Node2D
	var player_manager: Node
	var netfox_real_manager: Node
	var ui_layer: Node
	var emotes_ui: Control
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
	var face_manager = load("res://Scripts/player_animation_manager.gd").new()
	world.add_child(face_manager)
	face_manager.player = world.player
	for id in ["wave", "laugh", "sad"]:
		check(FACES.has_animation(id), "Atlas has " + id)
		check(FACES.get_frame_texture(id, 0).get_size() == Vector2(32, 32), "Aligned canvas for " + id)
		check(EMOTES.play(world.player, id), "Can play " + id)
		check(face_manager.get_face_expression_animation_name("idle") == id, "Face selection for " + id)
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
		controller._process(4.0)
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

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	world.ui_layer = viewport
	manager.setup_emotes_ui()
	manager.setup_emotes_ui()
	check(viewport.get_child_count() == 1, "HUD setup is idempotent")
	var menu = world.emotes_ui
	await process_frame
	check(menu.choices.get_child_count() == 4, "Three choices and title")
	check(menu.emotes_button.position.y == 268.0, "Emote button is directly below chat")
	var selections: Array[String] = []
	menu.emote_selected.connect(func(id: String): selections.append(id))
	menu.set_emotes_panel_open(true)
	menu.choices.get_node("Wave").pressed.emit()
	check(selections == ["wave"] and not menu.is_panel_open, "Selecting closes the dropdown and emits gesture")
	menu._select("sad")
	check(selections.size() == 1, "Selection cooldown suppresses rapid clicks")
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
	world.dead = true
	menu._process(0.0)
	check(not menu.visible and not menu.is_panel_open, "Death closes and hides the menu")
	world.free()
	viewport.free()
	if failures == 0: print("[player-emotes] PASS: faces, gestures, interruption, remote routing, dedupe, HUD layout and dropdown input")
	quit(1 if failures else 0)

func make_actor() -> Node2D:
	var actor := Node2D.new()
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	actor.add_child(visual)
	for part_name in ["LeftArm", "RightArm", "HandItem", "Head", "Body"]:
		var part := Node2D.new()
		part.name = part_name
		if part_name == "Head": part.position = Vector2(1, 0)
		if part_name == "RightArm": part.z_index = 50
		visual.add_child(part)
	return actor
