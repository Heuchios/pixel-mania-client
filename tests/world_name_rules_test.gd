extends SceneTree
const Rules = preload("res://Scripts/world_name_rules.gd")

func _initialize() -> void:
	for path in ["Scripts/ui/lobby_scene.gd", "Scripts/lobby_menu.gd", "Scripts/save_manager.gd", "Scripts/network_manager.gd", "Scripts/command_manager.gd", "Scripts/interaction_manager.gd", "Scripts/background_manager.gd", "Scripts/landfill_race_hud.gd", "Scripts/landfill_waiting_room_ui.gd", "Scripts/world_menu_ui.gd"]:
		var script = load("res://" + path)
		assert(script != null and script.can_instantiate(), "Could not compile " + path)
	for value in ["START", "world123", "123", "A".repeat(32), "LANDFILL123456"]:
		assert(Rules.is_valid(value))
	for value in ["", "MY WORLD", "MY_WORLD", "MY-WORLD", " TEST", "TEST ", "TE!ST", "TEST\n", "é", "Ａ", "A".repeat(33)]:
		assert(not Rules.is_valid(value), "Invalid world name accepted: " + value)
	for value in ["", "START", "WORLD2:door:A1", "door:A1"]:
		assert(Rules.is_valid_door_destination(value))
	for value in ["BAD WORLD:A1", "BAD_WORLD:door:A1", "BAD!", "START :A1"]:
		assert(not Rules.is_valid_door_destination(value))
	assert(Rules.is_event_instance("LANDFILL123456"))
	assert(Rules.is_event_instance("LANDFILL_123456"))
	assert(not Rules.is_event_instance("LANDFILL"))
	assert(not Rules.is_event_instance("LANDFILLHOME"))
	print("WORLD_NAME_RULES_TEST_OK")
	quit()
