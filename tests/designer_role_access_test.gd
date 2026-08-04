extends SceneTree

const CommandManager = preload("res://Scripts/command_manager.gd")
const DeveloperPanelUI = preload("res://Scripts/developer_panel_ui.gd")


class TestWorld extends Node:
	var chat_ui = null
	var notifications: Array[String] = []
	var developer_panel_toggle_count := 0

	func show_notification(message: String) -> void:
		notifications.append(message)

	func toggle_developer_panel() -> void:
		developer_panel_toggle_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var network = root.get_node_or_null("NetworkManager")
	assert(network != null)
	network.set_active_session("DesignerTest", "", "designer-test-token", "designer")
	assert(network.is_admin_command_session())
	assert(not network.is_developer_session())
	var player_manager_source := FileAccess.get_file_as_string("res://Scripts/player_manager.gd")
	assert(player_manager_source.contains("if clean_role == \"designer\":"))

	var test_world = TestWorld.new()
	root.add_child(test_world)
	var command_manager = CommandManager.new()
	test_world.add_child(command_manager)
	command_manager.setup(test_world)

	command_manager.handle_command("/ahelp")
	assert(not test_world.notifications.is_empty())
	var help_text: String = str(test_world.notifications.back())
	assert(help_text.begins_with("Designer commands:"))
	assert(not help_text.contains("/dev,"))

	command_manager.handle_command("/dev")
	assert(test_world.developer_panel_toggle_count == 0)
	assert(test_world.notifications.back() == "Developer panel requires admin or developer access.")

	var developer_panel = DeveloperPanelUI.new()
	developer_panel.world = test_world
	developer_panel.visible = false
	assert(not developer_panel.is_developer_allowed())
	developer_panel.open_panel()
	assert(not developer_panel.visible)
	developer_panel.free()

	print("[designer-role-access] success")
	quit(0)
