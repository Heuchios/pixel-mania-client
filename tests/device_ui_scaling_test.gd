extends SceneTree

class DesktopInventory extends "res://Scripts/inventory_manager.gd":
	func is_mobile_touch_platform() -> bool:
		return false

class AndroidInventory extends "res://Scripts/inventory_manager.gd":
	func is_mobile_touch_platform() -> bool:
		return true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var desktop := DesktopInventory.new()
	var android := AndroidInventory.new()
	var controls = load("res://Scripts/mobile_controls.gd").new()
	root.add_child(controls)
	var button := Panel.new()
	controls.add_child(button)
	controls.action_buttons["jump"] = button
	for logical_size in [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(2520, 1080), Vector2(1920, 1440)]:
		assert(is_equal_approx(desktop.get_mobile_hud_scale(logical_size), android.get_mobile_hud_scale(logical_size)))
		assert(is_equal_approx(desktop.get_hotbar_visual_height(logical_size), android.get_hotbar_visual_height(logical_size)))
		assert(is_equal_approx(desktop.get_hotbar_base_visual_width(), android.get_hotbar_base_visual_width()))
		var safe := Rect2(Vector2(100, 24), logical_size - Vector2(160, 80))
		controls.has_custom_layout = false
		controls._apply_layout_rect("jump", logical_size - Vector2(104, 96), Vector2(104, 96), 10.0, safe)
		assert(safe.encloses(button.get_rect()), "Default touch control must fit inside safe area")
		controls._apply_layout_rect("jump", Vector2.ZERO, Vector2(104, 96), 10.0, safe, Vector2(0, -200))
		assert(safe.encloses(button.get_rect()), "Drawer offset must respect safe area")
		controls.has_custom_layout = true
		controls.control_layout = {"jump": {"center": Vector2.ONE, "scale": 1.25}}
		controls._apply_layout_rect("jump", Vector2.ZERO, Vector2(104, 96), 10.0, safe)
		assert(safe.encloses(button.get_rect()), "Saved touch control must fit inside safe area")
		print("[device-ui-scaling] passed ", logical_size)
	controls.free()
	desktop.free()
	android.free()
	# Exercise real physical window sizes with the exported stretch policy.
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	for physical_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 720), Vector2i(2400, 1080), Vector2i(1024, 768)]:
		root.size = physical_size
		await process_frame
		await process_frame
		var canvas_size := root.get_visible_rect().size
		assert(canvas_size.x >= 1919 and canvas_size.y >= 1079)
		for scene_path in ["settings/SettingsPanel", "recipe_book/RecipeBookScene", "inventory/InventoryScene"]:
			var ui = load("res://Scenes/ui/%s.tscn" % scene_path).instantiate()
			root.add_child(ui)
			await process_frame
			await process_frame
			for frame in range(8):
				await process_frame
			var panel := ui.get_node("Window") as Control
			print("[device-ui-scaling] ", scene_path, " canvas=", canvas_size, " root=", ui.size, " panel=", panel.get_global_rect())
			assert(Rect2(Vector2.ZERO, canvas_size).grow(1).encloses(panel.get_global_rect()), "%s outside canvas at %s" % [scene_path, physical_size])
			ui.free()
		print("[device-ui-scaling] physical ", physical_size, " canvas ", canvas_size, " dialogs fit")
	quit(0)
