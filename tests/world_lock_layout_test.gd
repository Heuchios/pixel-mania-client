extends SceneTree

class PreviewManager extends RefCounted:
	func normalize_role(role): return role
	func get_player_access_role(_player): return "BUILDER"
	func get_role_title(role): return role
	func is_current_player_owner(): return true

class PreviewWorld extends RefCounted:
	var world_lock_manager = PreviewManager.new()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var ui = load("res://Scenes/ui/locks/WorldLockGUI.tscn").instantiate()
	root.add_child(ui)
	ui.world = PreviewWorld.new()
	ui.visible = true
	ui.window.visible = true
	ui.empty_access_label.hide()
	for player in ["CHAR", "LUCIFER", "RAYAN", "UCE"]:
		ui.create_member_row(player)
	await create_timer(0.3).timeout
	assert(ui.member_list_root.get_child_count() == 4)
	for panel_name in ["InfoCard", "AccessCard", "ActionsCard"]:
		var panel = ui.window.get_node(panel_name)
		assert(panel.modulate == Color.WHITE)
		assert(panel.texture.get_meta("atlas_region") == "inner_panel")
	assert(ui.add_role_picker.get_popup().get_theme_stylebox("panel").get_meta("atlas_region") == "inner_panel")
	var permissions = load("res://Scripts/world_lock_manager.gd").new()
	for role in ["admin", "builder", "visitor", "none", "invalid"]:
		assert(permissions._can_build_with_role(role) == (role in ["admin", "builder"]))
		assert(permissions._can_toggle_wooden_entrance_with_role(role) == (role == "admin"))
	assert(permissions.normalize_role(" ADMIN ") == "admin")
	assert(permissions.normalize_role("access") == "builder")
	permissions.free()
	assert(ui.slot_limit_input.is_visible_in_tree())
	assert(ui.slot_limit_input.text_submitted.is_connected(ui._on_slot_limit_text_submitted))
	assert(ui.add_button.pressed.is_connected(ui._on_add_access_pressed))
	for control in [ui.add_button, ui.public_button, ui.slot_limit_input, ui.set_slot_limit_button]:
		assert(ui.window.get_global_rect().encloses(control.get_global_rect()))
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/atlas-ui-tools/world-lock-preview.png")
	ui.queue_free()
	await process_frame
	print("[world-lock-layout] passed")
	quit()
