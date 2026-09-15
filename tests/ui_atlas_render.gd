extends SceneTree

## Usage: godot --path . --rendering-method gl_compatibility --script
## tests/ui_atlas_render.gd -- --output=D:/.../screenshots
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "user://atlas_ui_review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	# Keep the project's canvas_items/expand configuration. Disabling it
	# made the phone preview a tiny logical canvas, unlike a real export.
	if "--phone" in OS.get_cmdline_user_args():
		root.size = Vector2i(1600, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resolution="):
			var dimensions := arg.trim_prefix("--resolution=").split("x")
			assert(dimensions.size() == 2)
			root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var scenes := ["hotbar/Hotbar", "inventory/InventoryScene", "shop/ShopSceneRedesign", "chat/ChatScene", "settings/SettingsPanel", "menu/MenuScene", "trade/TradeScene", "leaderboard/LeaderboardScene", "login/LoginScene", "lobby/LobbyScene", "recipe_book/RecipeBookScene", "emotes/EmotesScene", "player_profile/PlayerProfileScene", "locks/AreaLockGUI", "locks/WorldLockGUI", "vending/VendingMachineGUI", "battery_charger/BatteryChargerGUI", "generator/GeneratorGUI", "oil_refinery/OilRefineryGUI"]
	for path in scenes:
		var ui: Control = load("res://Scenes/ui/%s.tscn" % path).instantiate()
		if path.begins_with("inventory/"):
			ui.use_preview_items = true
		root.add_child(ui)
		ui.visible = true
		if ui.has_method("open_chat_panel"):
			ui.open_chat_panel()
		if ui.has_method("set_emotes_panel_open"):
			ui.set_emotes_panel_open(true)
		# These dialogs normally reveal their window after a world interaction.
		# Show only the visual child here without sending any interaction request.
		if path.begins_with("battery_charger/") or path.begins_with("oil_refinery/"):
			ui.panel.visible = true
			ui.overlay.visible = true
		if path == "locks/WorldLockGUI":
			ui.window.visible = true
			ui.dimmer.visible = true
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(output.path_join(path.get_file() + ".png"))
		ui.queue_free()
		await process_frame
	print("[ui-atlas-render] Saved to ", output)
	quit()
