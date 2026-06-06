extends Node

const WORLD_LOADING_TIMEOUT_MSEC := 6000

var world = null
var world_loading_overlay = null
var world_loading_root = null
var world_loading_label = null
var world_loading_fade_tween = null
var waiting_for_server_state := false
var loading_started_msec := 0


func setup(world_ref):
	world = world_ref
	setup_overlay()


func setup_overlay():
	if world_loading_overlay != null and is_instance_valid(world_loading_overlay):
		return

	world_loading_overlay = CanvasLayer.new()
	world_loading_overlay.name = "WorldLoadingOverlay"
	world_loading_overlay.layer = 250

	var parent_node = world.get_parent()
	if parent_node != null:
		parent_node.add_child.call_deferred(world_loading_overlay)
	else:
		world.add_child.call_deferred(world_loading_overlay)

	world_loading_root = Control.new()
	world_loading_root.name = "Root"
	world_loading_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	world_loading_overlay.add_child(world_loading_root)

	var shade = ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.05, 0.08, 0.94)
	world_loading_root.add_child(shade)

	var box = VBoxContainer.new()
	box.name = "Center"
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -280
	box.offset_top = -92
	box.offset_right = 280
	box.offset_bottom = 92
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	world_loading_root.add_child(box)

	var title = Label.new()
	title.name = "Title"
	title.text = "LOADING WORLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	box.add_child(title)

	world_loading_label = Label.new()
	world_loading_label.name = "Message"
	world_loading_label.text = "Loading world..."
	world_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_loading_label.add_theme_font_size_override("font_size", 24)
	world_loading_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1))
	world_loading_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	world_loading_label.add_theme_constant_override("shadow_offset_x", 2)
	world_loading_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(world_loading_label)

	world_loading_overlay.visible = false


func begin_smooth_world_load(world_name: String, wait_for_server_state: bool = true):
	setup_overlay()

	waiting_for_server_state = wait_for_server_state
	loading_started_msec = Time.get_ticks_msec()

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()
		world_loading_fade_tween = null

	if world_loading_root != null:
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	update_message("Loading " + world_name.strip_edges().to_upper() + "...")

	if world_loading_overlay != null:
		world_loading_overlay.visible = true


func update_message(message: String):
	if world_loading_label == null or not is_instance_valid(world_loading_label):
		return

	world_loading_label.text = message


func is_overlay_visible() -> bool:
	return world_loading_overlay != null and is_instance_valid(world_loading_overlay) and bool(world_loading_overlay.visible)


func is_waiting_for_server_state() -> bool:
	return waiting_for_server_state


func finish_smooth_world_load():
	waiting_for_server_state = false

	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		return

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()

	if world_loading_root == null or not is_instance_valid(world_loading_root):
		world_loading_overlay.visible = false
		return

	world_loading_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_loading_fade_tween = create_tween()
	world_loading_fade_tween.tween_property(world_loading_root, "modulate:a", 0.0, 0.12)
	world_loading_fade_tween.tween_callback(Callable(self, "_hide_overlay_after_fade"))


func cancel_smooth_world_load():
	waiting_for_server_state = false

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()
		world_loading_fade_tween = null

	if world_loading_overlay != null and is_instance_valid(world_loading_overlay):
		world_loading_overlay.visible = false

	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP


func update_timeout():
	if not waiting_for_server_state:
		return

	if Time.get_ticks_msec() - loading_started_msec < WORLD_LOADING_TIMEOUT_MSEC:
		return

	waiting_for_server_state = false

	if world.save_manager != null and world.save_manager.has_method("finish_world_entry_after_load"):
		world.save_manager.finish_world_entry_after_load(false, true)
	else:
		finish_smooth_world_load()

	world.show_notification("Server world took too long. Showing current world.")


func _hide_overlay_after_fade():
	if world_loading_overlay != null and is_instance_valid(world_loading_overlay):
		world_loading_overlay.visible = false

	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	world_loading_fade_tween = null
