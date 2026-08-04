extends Control

const UI_STYLE_PATH = "res://Assets/ui/pixelmania/"
const LOBBY_PROFILE_PATH = "user://pixelmania_profile.cfg"
const LOBBY_SCENE = "res://Scenes/ui/lobby/LobbyScene.tscn"
const LOGIN_SCENE = "res://Scenes/ui/login/LoginScene.tscn"

var world = null
var ui_layer_ref = null

var worlds_button = null
var overlay = null
var panel = null
var world_name_input = null
var profile_name_input = null
var profile_status_label = null
var current_profile_label = null
var status_label = null
var main_menu_mode = true
var return_to_lobby_menu_in_progress := false



func get_ui_texture(file_name: String):
	var path = UI_STYLE_PATH + file_name

	if ResourceLoader.exists(path):
		return load(path)

	return null


func add_texture_skin(parent_node, skin_name: String, file_name: String, skin_position: Vector2, skin_size: Vector2):
	if parent_node == null:
		return null

	var texture = get_ui_texture(file_name)

	if texture == null:
		return null

	var skin = parent_node.get_node_or_null(skin_name)

	if skin == null:
		skin = TextureRect.new()
		skin.name = skin_name
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent_node.add_child(skin)

	skin.texture = texture
	skin.position = skin_position
	skin.size = skin_size
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.visible = true

	if parent_node.has_method("move_child"):
		parent_node.move_child(skin, 0)

	return skin


func make_color_rect_transparent(node):
	if node != null and node is ColorRect:
		node.color = Color(1.0, 1.0, 1.0, 0.0)


func style_button(button: Button):
	if button == null:
		return

	var normal = get_ui_texture("button_normal.png")

	if normal != null:
		button.icon = normal
		button.expand_icon = true
		button.text = button.text


func apply_menu_style():
	if panel == null:
		return

	make_color_rect_transparent(panel)
	add_texture_skin(panel, "PanelSkin", "panel_ninepatch.png", Vector2.ZERO, panel.size)

	var top_border = panel.get_node_or_null("TopBorder")
	make_color_rect_transparent(top_border)

	var input_back = panel.get_node_or_null("InputBack")
	if input_back != null:
		make_color_rect_transparent(input_back)
		add_texture_skin(input_back, "InputSkin", "input_box.png", Vector2.ZERO, input_back.size)

	var enter_button = panel.get_node_or_null("EnterWorldButton")
	if enter_button != null and enter_button is Button:
		style_button(enter_button)

	var profile_button = panel.get_node_or_null("ProfileButton")
	if profile_button != null and profile_button is Button:
		style_button(profile_button)

	var profile_input_back = panel.get_node_or_null("ProfileInputBack")
	if profile_input_back != null:
		make_color_rect_transparent(profile_input_back)
		add_texture_skin(profile_input_back, "InputSkin", "input_box.png", Vector2.ZERO, profile_input_back.size)



func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	setup_worlds_button()
	setup_menu()
	close_menu()
	call_deferred("_try_auto_enter_pending_lobby_world")


func _process(_delta):
	update_worlds_button_position()
	update_menu_position()
	update_worlds_button_visibility()


func setup_worlds_button():
	if ui_layer_ref == null:
		return

	worlds_button = ui_layer_ref.get_node_or_null("WorldsButton")
	if worlds_button != null:
		worlds_button.visible = false
		worlds_button.queue_free()
		worlds_button = null


func setup_menu():
	if ui_layer_ref == null:
		return

	overlay = ui_layer_ref.get_node_or_null("WorldMenuOverlay")

	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "WorldMenuOverlay"
		ui_layer_ref.add_child(overlay)

	overlay.color = Color(0.07, 0.38, 0.55, 1.0)
	overlay.z_index = 500
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	for child in overlay.get_children():
		child.queue_free()

	# Background sky panel.
	var sky = ColorRect.new()
	sky.name = "Sky"
	sky.position = Vector2.ZERO
	sky.color = Color(0.20, 0.66, 0.88, 1.0)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(sky)

	# Far mountains.
	for i in range(5):
		var mountain = ColorRect.new()
		mountain.name = "Mountain_" + str(i)
		mountain.size = Vector2(360, 220)
		mountain.color = Color(0.24, 0.58, 0.70, 0.72)
		mountain.rotation_degrees = 45
		mountain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(mountain)

	# Ground strip.
	var ground = ColorRect.new()
	ground.name = "Ground"
	ground.color = Color(0.12, 0.36, 0.21, 1.0)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ground)

	panel = ColorRect.new()
	panel.name = "WorldMenuPanel"
	panel.size = Vector2(720, 470)
	panel.color = Color(1.0, 1.0, 1.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var top_border = ColorRect.new()
	top_border.name = "TopBorder"
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(720, 4)
	top_border.color = Color(0.75, 0.95, 1.0, 0.85)
	top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_border)

	var title = Label.new()
	title.name = "Title"
	title.text = "WORLD MENU"
	title.position = Vector2(0, 26)
	title.size = Vector2(720, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Punch. Build. Grow."
	subtitle.position = Vector2(0, 78)
	subtitle.size = Vector2(720, 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(subtitle)

	current_profile_label = Label.new()
	current_profile_label.name = "CurrentProfileLabel"
	current_profile_label.text = "Profile: None"
	current_profile_label.position = Vector2(0, 112)
	current_profile_label.size = Vector2(720, 24)
	current_profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_profile_label.add_theme_font_size_override("font_size", 15)
	current_profile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(current_profile_label)

	profile_status_label = Label.new()
	profile_status_label.name = "ProfileStatusLabel"
	profile_status_label.text = "Sign on or select a registered account first."
	profile_status_label.position = Vector2(0, 140)
	profile_status_label.size = Vector2(720, 22)
	profile_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_status_label.add_theme_font_size_override("font_size", 13)
	profile_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(profile_status_label)

	var profile_input_back = ColorRect.new()
	profile_input_back.name = "ProfileInputBack"
	profile_input_back.position = Vector2(135, 168)
	profile_input_back.size = Vector2(300, 42)
	profile_input_back.color = Color(1.0, 1.0, 1.0, 0.0)
	profile_input_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(profile_input_back)

	profile_name_input = LineEdit.new()
	profile_name_input.name = "ProfileNameInput"
	profile_name_input.placeholder_text = "USERNAME"
	profile_name_input.position = Vector2(148, 174)
	profile_name_input.size = Vector2(274, 30)
	profile_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_input.mouse_filter = Control.MOUSE_FILTER_STOP

	if not profile_name_input.text_submitted.is_connected(_on_profile_name_submitted):
		profile_name_input.text_submitted.connect(_on_profile_name_submitted)

	panel.add_child(profile_name_input)

	var profile_button = Button.new()
	profile_button.name = "ProfileButton"
	profile_button.text = "SWITCH"
	profile_button.position = Vector2(450, 168)
	profile_button.size = Vector2(150, 42)
	profile_button.mouse_filter = Control.MOUSE_FILTER_STOP
	profile_button.pressed.connect(_on_profile_button_pressed)
	panel.add_child(profile_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Enter a world name"
	status_label.position = Vector2(0, 238)
	status_label.size = Vector2(720, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)

	var input_back = ColorRect.new()
	input_back.name = "InputBack"
	input_back.position = Vector2(135, 276)
	input_back.size = Vector2(450, 48)
	input_back.color = Color(1.0, 1.0, 1.0, 0.0)
	input_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(input_back)

	world_name_input = LineEdit.new()
	world_name_input.name = "WorldNameInput"
	world_name_input.placeholder_text = "WORLD NAME"
	world_name_input.position = Vector2(148, 284)
	world_name_input.size = Vector2(424, 32)
	world_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_name_input.mouse_filter = Control.MOUSE_FILTER_STOP

	if not world_name_input.text_submitted.is_connected(_on_world_name_submitted):
		world_name_input.text_submitted.connect(_on_world_name_submitted)

	panel.add_child(world_name_input)

	var enter_button = Button.new()
	enter_button.name = "EnterWorldButton"
	enter_button.text = "ENTER WORLD"
	enter_button.position = Vector2(270, 346)
	enter_button.size = Vector2(180, 46)
	enter_button.mouse_filter = Control.MOUSE_FILTER_STOP
	enter_button.pressed.connect(_on_enter_world_pressed)
	panel.add_child(enter_button)

	var hint = Label.new()
	hint.name = "Hint"
	hint.text = "Accounts are registered from the login screen."
	hint.position = Vector2(0, 414)
	hint.size = Vector2(720, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)

	update_menu_position()


func update_worlds_button_position():
	if worlds_button == null:
		return

	worlds_button.visible = false


func update_worlds_button_visibility():
	if worlds_button == null:
		return

	worlds_button.visible = false


func update_menu_position():
	if overlay == null:
		return

	var screen_size = get_viewport_rect().size
	overlay.position = Vector2.ZERO
	overlay.size = screen_size

	var sky = overlay.get_node_or_null("Sky")
	if sky != null:
		sky.size = screen_size

	var ground = overlay.get_node_or_null("Ground")
	if ground != null:
		ground.position = Vector2(0, screen_size.y - 120)
		ground.size = Vector2(screen_size.x, 120)

	for i in range(5):
		var mountain = overlay.get_node_or_null("Mountain_" + str(i))
		if mountain != null:
			mountain.position = Vector2(120 + i * 360, screen_size.y - 180)

	if panel != null:
		panel.position = Vector2(
			(screen_size.x - panel.size.x) / 2.0,
			(screen_size.y - panel.size.y) / 2.0
		)


func open_main_menu():
	open_menu("", true)
	call_deferred("_try_auto_enter_pending_lobby_world")


func open_menu(world_name: String = "", is_main: bool = false):
	if overlay == null:
		return

	main_menu_mode = is_main
	overlay.visible = true

	if status_label != null:
		if main_menu_mode:
			status_label.text = "You are not in a world"
		else:
			status_label.text = "Choose a world to enter"

	update_profile_status()

	if world_name_input != null:
		if world_name != "":
			world_name_input.text = world_name
		elif world_name_input.text.strip_edges() == "":
			world_name_input.text = "START"

	if has_active_profile():
		if world_name_input != null:
			world_name_input.grab_focus()
			world_name_input.select_all()
	else:
		if profile_name_input != null:
			profile_name_input.grab_focus()
			profile_name_input.select_all()

	update_worlds_button_visibility()




func _try_auto_enter_pending_lobby_world():
	if world == null:
		return
	if MovementMode.is_backend_dev_login_requested():
		return

	var cfg = ConfigFile.new()
	var err = cfg.load(LOBBY_PROFILE_PATH)
	var pending_enabled = false
	var pending_world_name = ""
	var pending_profile_name = ""

	var network = _get_network_manager()
	if network != null and network.has_method("has_pending_join") and network.has_method("consume_pending_join") and bool(network.has_pending_join()):
		var pending_join = network.consume_pending_join()
		pending_enabled = bool(pending_join.get("enabled", false))
		pending_world_name = str(pending_join.get("world_name", "")).strip_edges()
		pending_profile_name = str(pending_join.get("profile_name", "")).strip_edges()
	elif err == OK:
		pending_enabled = bool(cfg.get_value("pending_join", "enabled", false))
		pending_world_name = str(cfg.get_value("pending_join", "world_name", "")).strip_edges()
		pending_profile_name = str(cfg.get_value("pending_join", "profile_name", "")).strip_edges()
	else:
		return

	if not pending_enabled:
		return

	if pending_world_name == "":
		pending_world_name = str(cfg.get_value("profile", "last_world", "")).strip_edges()

	if pending_world_name == "":
		pending_world_name = "START"
	pending_world_name = pending_world_name.strip_edges().to_upper()

	world.current_world_name = pending_world_name
	if network != null and "current_world_name" in network:
		network.set("current_world_name", pending_world_name)

	var session_profile_name = _get_network_session_username()
	if session_profile_name != "":
		pending_profile_name = session_profile_name

	if pending_profile_name == "":
		pending_profile_name = str(cfg.get_value("profile", "username", "")).strip_edges()

	if pending_profile_name != "" and world.has_method("create_or_switch_profile"):
		var result = world.create_or_switch_profile(pending_profile_name)

		if profile_name_input != null:
			profile_name_input.text = pending_profile_name

		set_profile_status(str(result.get("message", "")))
		update_profile_status()

	if world_name_input != null:
		world_name_input.text = pending_world_name

	if err == OK:
		cfg.set_value("pending_join", "enabled", false)
		cfg.set_value("pending_join", "world_name", "")
		cfg.set_value("pending_join", "profile_name", "")
		cfg.save(LOBBY_PROFILE_PATH)

	if not has_active_profile():
		set_profile_status("Could not auto-enter. Sign on first.")
		if world.has_method("cancel_smooth_world_load"):
			world.cancel_smooth_world_load()
		open_menu(pending_world_name, true)
		return

	close_menu()

	if world.has_method("enter_world_by_name"):
		world.enter_world_by_name(pending_world_name)
	else:
		if world.has_method("cancel_smooth_world_load"):
			world.cancel_smooth_world_load()
		open_menu(pending_world_name, true)


func close_menu():
	if overlay != null:
		overlay.visible = false

	if world_name_input != null:
		world_name_input.release_focus()

	if profile_name_input != null:
		profile_name_input.release_focus()

	update_worlds_button_visibility()


func _get_network_manager():
	if is_inside_tree():
		var own_tree = get_tree()
		if own_tree != null and own_tree.root != null:
			var own_network = own_tree.root.get_node_or_null("NetworkManager")
			if own_network != null:
				return own_network

	if world != null and world.has_method("is_inside_tree") and world.is_inside_tree():
		var world_tree = world.get_tree()
		if world_tree != null and world_tree.root != null:
			return world_tree.root.get_node_or_null("NetworkManager")

	return null


func _get_network_session_username() -> String:
	var network = _get_network_manager()
	if network != null and network.has_method("get_active_session_username"):
		return str(network.get_active_session_username()).strip_edges()

	return ""


func close_menu_and_resume():
	if world != null and world.has_method("resume_current_world"):
		world.resume_current_world()


func is_menu_open() -> bool:
	return overlay != null and overlay.visible


func is_world_name_input_focused() -> bool:
	if world_name_input == null:
		return false

	return world_name_input.has_focus()


func return_to_lobby_menu(save_current_world: bool = true):
	if return_to_lobby_menu_in_progress:
		return
	return_to_lobby_menu_in_progress = true
	call_deferred("_run_return_to_lobby_menu", save_current_world)


func _run_return_to_lobby_menu(save_current_world: bool = true) -> void:
	if world != null:
		var is_in_world = true
		if "in_world" in world:
			is_in_world = bool(world.get("in_world"))

		if is_in_world:
			await _wait_for_pending_world_edits_before_lobby()

		if save_current_world and is_in_world and world.has_method("save_world"):
			world.save_world()

	_notify_network_leave_for_lobby()
	_save_current_world_menu_state_for_lobby()
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _wait_for_pending_world_edits_before_lobby() -> void:
	if world == null:
		return
	if "save_manager" in world and world.save_manager != null and world.save_manager.has_method("wait_for_pending_authoritative_block_updates"):
		await world.save_manager.wait_for_pending_authoritative_block_updates("return_to_lobby")
		return
	var block_manager = world.block_manager if "block_manager" in world else null
	if block_manager == null or not block_manager.has_method("wait_for_pending_authoritative_block_updates"):
		return
	await block_manager.wait_for_pending_authoritative_block_updates()


func _on_worlds_button_pressed():
	return_to_lobby_menu(true)

func _notify_network_leave_for_lobby():
	if world == null:
		return

	var is_in_world = true
	if "in_world" in world:
		is_in_world = bool(world.get("in_world"))

	if not is_in_world:
		return

	var current_world_name = ""
	if "current_world_name" in world:
		current_world_name = str(world.get("current_world_name")).strip_edges()

	if current_world_name == "":
		return

	if "save_manager" in world and world.save_manager != null and world.save_manager.has_method("notify_network_leave_world"):
		world.save_manager.notify_network_leave_world(current_world_name)
		return

	var network = _get_network_manager()
	if network != null and network.has_method("send_leave_world"):
		network.send_leave_world(current_world_name)

	if world.has_method("clear_remote_players"):
		world.clear_remote_players()


func _save_current_world_menu_state_for_lobby():
	var cfg = ConfigFile.new()
	cfg.load(LOBBY_PROFILE_PATH)

	var profile_name = get_current_profile_name()
	if profile_name.strip_edges() != "":
		cfg.set_value("profile", "username", profile_name)

	var current_world_name = ""

	if world != null:
		var possible_world_name = world.get("current_world_name")

		if possible_world_name != null:
			current_world_name = str(possible_world_name).strip_edges()

		if current_world_name == "" and world.has_method("get_current_world_name"):
			current_world_name = str(world.get_current_world_name()).strip_edges()

	if current_world_name != "":
		cfg.set_value("profile", "last_world", current_world_name)

	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(LOBBY_PROFILE_PATH)


func _on_world_name_submitted(_text: String):
	enter_world_from_input()


func _on_enter_world_pressed():
	enter_world_from_input()


func enter_world_from_input():
	if world == null or world_name_input == null:
		return

	if not has_active_profile():
		if _should_redirect_netfox_real_launch_to_login():
			_prepare_netfox_real_login_redirect()
			set_profile_status("Sign on first. Opening login...")
			get_tree().change_scene_to_file(LOGIN_SCENE)
			return

		set_profile_status("Sign on or select a registered account before entering a world.")

		if profile_name_input != null:
			profile_name_input.grab_focus()

		return

	var typed_name = world_name_input.text.strip_edges()

	if typed_name == "":
		typed_name = "START"

	if world.has_method("enter_world_by_name"):
		world.enter_world_by_name(typed_name)


func _should_redirect_netfox_real_launch_to_login() -> bool:
	if MovementMode.is_backend_dev_login_requested():
		return false
	return MovementMode.is_netfox_real_launch_requested() and MovementMode.has_method("is_netfox_real_client_launch") and MovementMode.is_netfox_real_client_launch() and MovementMode.get_launch_arg_value("--world", "").strip_edges() != ""


func _prepare_netfox_real_login_redirect() -> void:
	var world_name := MovementMode.get_dev_test_world_name("NETFOX_TEST")
	var profile_name := ""
	if profile_name_input != null:
		profile_name = profile_name_input.text.strip_edges()
	if profile_name == "":
		profile_name = get_current_profile_name()

	var cfg := ConfigFile.new()
	cfg.load(LOBBY_PROFILE_PATH)
	cfg.set_value("profile", "last_world", world_name)
	cfg.set_value("pending_join", "enabled", true)
	cfg.set_value("pending_join", "world_name", world_name)
	cfg.set_value("pending_join", "profile_name", profile_name)
	cfg.save(LOBBY_PROFILE_PATH)


func has_active_profile() -> bool:
	if world == null:
		return false

	if world.has_method("has_active_profile"):
		return world.has_active_profile()

	return false


func get_current_profile_name() -> String:
	var session_profile_name = _get_network_session_username()
	if session_profile_name != "":
		return session_profile_name

	if world == null:
		return ""

	if world.has_method("get_current_profile_name"):
		return world.get_current_profile_name()

	return ""


func update_profile_status():
	var profile_name = get_current_profile_name()

	if current_profile_label != null:
		if profile_name == "":
			current_profile_label.text = "Profile: None"
		else:
			current_profile_label.text = "Profile: " + profile_name

	if profile_status_label != null:
		if profile_name == "":
			profile_status_label.text = "Sign on or select a registered account first."
		else:
			profile_status_label.text = "Ready as " + profile_name + "."


func set_profile_status(message: String):
	if profile_status_label != null:
		profile_status_label.text = message


func _on_profile_name_submitted(_text: String):
	create_or_switch_profile_from_input()


func _on_profile_button_pressed():
	create_or_switch_profile_from_input()


func create_or_switch_profile_from_input():
	if world == null or profile_name_input == null:
		return

	var username = profile_name_input.text.strip_edges()

	if world.has_method("create_or_switch_profile"):
		var result = world.create_or_switch_profile(username)
		set_profile_status(str(result.get("message", "")))

		if bool(result.get("ok", false)):
			update_profile_status()

			if world_name_input != null:
				world_name_input.grab_focus()
				world_name_input.select_all()
	else:
		set_profile_status("Account system not ready.")
