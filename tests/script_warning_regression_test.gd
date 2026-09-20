extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	for category in ["integer_division", "standalone_ternary", "unused_parameter", "unused_variable", "shadowed_variable", "shadowed_variable_base_class", "shadowed_global_identifier"]:
		var key: String = "debug/gdscript/warnings/" + category
		assert(ProjectSettings.has_setting(key), key)
		ProjectSettings.set_setting(key, 2)
	for path in ["Scripts/vending_ui.gd", "Scripts/ui/quest_board_ui.gd", "Scripts/ui/fishing_minigame_ui.gd", "Scripts/ui/leaderboard_scene.gd", "Scripts/campfire_light_fx.gd", "Scripts/music_manager.gd", "Scripts/ui/pixel_ui_style.gd", "Scripts/network_manager.gd", "Scripts/electric_circuit_ux.gd", "Scripts/ui/menu_scene.gd", "Scripts/atlas_texture_factory.gd", "Scripts/seed_system.gd", "Scripts/world.gd", "Scripts/world_loading_ui_manager.gd"]:
		var script: GDScript = load("res://" + path)
		assert(script != null and script.reload(true) == OK, path)
	print("STRICT_WARNING_CHECK_OK")
	quit()
