extends SceneTree
func _init():
	call_deferred("run")
func run():
	root.size = Vector2i(1440, 1000)
	var ui = load("res://Scenes/ui/player_profile/PlayerProfileScene.tscn").instantiate()
	root.add_child(ui)
	ui.build_menu()
	ui.player_name_label.text = "USO"
	ui.account_label.text = "@USO"
	ui.status_badge_label.text = "ONLINE"
	ui.title_value_label.text = "BUILDER"
	ui.level_label.text = "18"
	ui.worlds_value_label.text = "TEST"
	ui.friends_value_label.text = "12"
	ui.total_xp_value_label.text = "44.4K"
	ui.xp_label.text = "2538 / 6248 XP"
	ui.xp_fill.anchor_right = ui._get_xp_ratio(2538, 6248)
	ui.get_node("%NextLevelLabel").text = "3710 XP TO LEVEL 19"
	ui.player_age_value_label.text = "110 DAYS"
	ui.playtime_label.text = "NOW"
	ui.bio_label.text = "Building worlds, collecting rare items, and exploring PixelMania."
	ui.showcase_badge_label.text = "GOLDEN CROWN"
	ui.showcase_item_label.text = "BATTLE AXE"
	ui.showcase_world_label.text = "DRAGON WINGS"
	ui.update_action_buttons()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/profile-updated.png")
	ui.editing_bio = true
	ui._update_bio_editor_visibility()
	ui.bio_text_edit.text = "A full-length bio can be edited here while keeping Save and Cancel visible."
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/profile-edit.png")
	root.size = Vector2i(800, 600)
	root.content_scale_size = Vector2i(800, 600)
	ui.update_position()
	await create_timer(0.2).timeout
	ui.update_position()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/profile-compact.png")
	ui.free()
	quit()
