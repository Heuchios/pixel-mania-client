extends Node

const WORLD_LOADING_TIMEOUT_MSEC := 6000
const WORLD_LOADING_RETRY_MAX_MSEC := 20000
const WORLD_LOADING_RETRY_GRACE_ATTEMPTS := 1
# Set to 0 so the overlay only fades after the world/player readiness checks pass.
const WORLD_READY_WAIT_TIMEOUT_MSEC := 0
const WORLD_READY_CHECK_INTERVAL_MSEC := 50
# Do not add cosmetic delay after the authoritative world/player checks pass.
const WORLD_LOADING_MIN_VISIBLE_MSEC := 0
const WORLD_LOADING_READY_HOLD_MSEC := 0
const WORLD_LOADING_DOTS_INTERVAL := 0.32
const DEBUG_WORLD_LOADING_UI := true
const WORLD_LOADING_CANVAS_LAYER := 4096

# Exact loading scene path used by world entry.
# Your scene must be saved here:
# res://Scenes/ui/WorldLoadingOverlay/WorldLoadingOverlay.tscn
const WORLD_LOADING_OVERLAY_SCENE_PATH := "res://Scenes/ui/WorldLoadingOverlay/WorldLoadingOverlay.tscn"
const WORLD_LOADING_OVERLAY_SCENE_PATHS := [
	WORLD_LOADING_OVERLAY_SCENE_PATH
]
# Keep these only for compatibility with old helper functions. The manager now
# loads the exact scene path above instead of scanning random folders.
const WORLD_LOADING_OVERLAY_FILE_NAMES := []
const WORLD_LOADING_OVERLAY_SCAN_MAX_DEPTH := 0

var world = null
var world_loading_scene_instance = null
var world_loading_overlay = null
var world_loading_root: Control = null
var world_loading_title_label: Label = null
var world_loading_label: Label = null
var world_loading_dots_label: Label = null
var world_loading_fade_tween = null
var waiting_for_server_state := false
var loading_started_msec := 0
var next_server_retry_msec := 0
var server_retry_attempt_count := 0
var finish_wait_started_msec := 0
var finish_wait_running := false
var pending_finish_smooth_load := false
var loading_dot_timer := 0.0
var loading_dot_count := 0


func _debug(message: String) -> void:
	if DEBUG_WORLD_LOADING_UI:
		print("[WorldLoadingUI] " + message)


func setup(world_ref):
	world = world_ref
	setup_overlay()


func _process(delta: float) -> void:
	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		return
	if not bool(world_loading_overlay.visible):
		return

	loading_dot_timer += delta
	if loading_dot_timer < WORLD_LOADING_DOTS_INTERVAL:
		return
	loading_dot_timer = 0.0
	loading_dot_count = (loading_dot_count % 3) + 1
	_set_loading_dots_text(".".repeat(loading_dot_count))


func setup_overlay():
	if world_loading_overlay != null and is_instance_valid(world_loading_overlay):
		_cache_overlay_nodes()
		_ensure_overlay_content()
		return

	var parent_node = world.get_parent() if world != null else null
	if parent_node == null:
		parent_node = world
	if parent_node == null:
		_debug("No parent/world available for loading overlay.")
		return

	# Reuse an existing WorldLoadingOverlay only if it was already placed under the world parent.
	# Otherwise instantiate the exact scene path below.
	var reused_existing_overlay := false
	world_loading_scene_instance = parent_node.get_node_or_null("WorldLoadingOverlay")
	if world_loading_scene_instance != null:
		reused_existing_overlay = true
		_debug("Reusing existing WorldLoadingOverlay node from scene tree")

	if world_loading_scene_instance == null:
		var root_overlay := _find_root_loading_overlay(parent_node)
		if root_overlay != null:
			world_loading_scene_instance = root_overlay
			reused_existing_overlay = true
			_debug("Using existing root WorldLoadingOverlay node")

	# Otherwise instantiate the exact .tscn path.
	if world_loading_scene_instance == null:
		var scene_resource: PackedScene = _load_loading_overlay_scene()
		if scene_resource != null:
			world_loading_scene_instance = scene_resource.instantiate()
			world_loading_scene_instance.name = "WorldLoadingOverlay"
			_attach_overlay_child(parent_node, world_loading_scene_instance)
			_debug("Instantiated WorldLoadingOverlay.tscn")

	# If no scene exists, create a CanvasLayer fallback completely in code.
	if world_loading_scene_instance == null:
		world_loading_scene_instance = CanvasLayer.new()
		world_loading_scene_instance.name = "WorldLoadingOverlay"
		_attach_overlay_child(parent_node, world_loading_scene_instance)
		_debug("Created fallback CanvasLayer overlay")

	world_loading_overlay = _resolve_canvas_layer(world_loading_scene_instance)
	if world_loading_overlay == null:
		world_loading_overlay = CanvasLayer.new()
		world_loading_overlay.name = "CanvasLayer"
		world_loading_scene_instance.add_child(world_loading_overlay)
		_debug("Scene root was not a CanvasLayer; added missing CanvasLayer child")
	var preserve_existing_visibility := reused_existing_overlay and bool(world_loading_overlay.visible)

	if world_loading_overlay is CanvasLayer:
		world_loading_overlay.layer = WORLD_LOADING_CANVAS_LAYER
		world_loading_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	_cache_overlay_nodes()
	_ensure_overlay_content()
	_set_overlay_visible(preserve_existing_visibility)
	if preserve_existing_visibility:
		raise_loading_overlay_to_front()
	_debug("Overlay ready. tree=" + _get_overlay_tree_summary())


func _find_root_loading_overlay(local_parent: Node) -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var root_node := tree.root
	if root_node == null or root_node == local_parent:
		return null

	var root_overlay := root_node.get_node_or_null("WorldLoadingOverlay")
	if root_overlay == null or not is_instance_valid(root_overlay):
		return null
	if not (root_overlay is Node):
		return null

	return root_overlay


func _reparent_loading_overlay(parent_node: Node) -> void:
	if world_loading_scene_instance == null or not is_instance_valid(world_loading_scene_instance):
		return
	if parent_node == null or not is_instance_valid(parent_node):
		return

	var current_parent: Node = world_loading_scene_instance.get_parent()
	if current_parent == parent_node:
		return

	if current_parent != null:
		current_parent.remove_child(world_loading_scene_instance)
	_attach_overlay_child(parent_node, world_loading_scene_instance)


func _attach_overlay_child(parent_node: Node, child_node: Node) -> void:
	if parent_node == null or not is_instance_valid(parent_node):
		return
	if child_node == null or not is_instance_valid(child_node):
		return
	if child_node.get_parent() == parent_node:
		return
	if parent_node.is_node_ready():
		parent_node.add_child(child_node)
	else:
		parent_node.add_child.call_deferred(child_node)


func _load_loading_overlay_scene() -> PackedScene:
	# Load only the exact scene path. This prevents the manager from accidentally
	# using an older WorldLoadingOverlay.tscn saved somewhere else.
	var scene_path: String = WORLD_LOADING_OVERLAY_SCENE_PATH
	if not ResourceLoader.exists(scene_path):
		_debug("Exact loading scene path not found: " + scene_path)
		_debug("Save the scene exactly here: " + WORLD_LOADING_OVERLAY_SCENE_PATH)
		return null

	var scene_resource = load(scene_path)
	if scene_resource is PackedScene:
		_debug("Found exact loading scene: " + scene_path)
		return scene_resource

	_debug("Exact loading scene path exists but is not PackedScene: " + scene_path)
	return null


func _find_loading_overlay_scene_path(root_path: String, depth: int = 0) -> String:
	if depth > WORLD_LOADING_OVERLAY_SCAN_MAX_DEPTH:
		return ""

	var dir := DirAccess.open(root_path)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue

		var full_path := root_path
		if not full_path.ends_with("/"):
			full_path += "/"
		full_path += entry_name

		if dir.current_is_dir():
			var found_path := _find_loading_overlay_scene_path(full_path, depth + 1)
			if found_path != "":
				dir.list_dir_end()
				return found_path
		elif WORLD_LOADING_OVERLAY_FILE_NAMES.has(entry_name):
			dir.list_dir_end()
			return full_path

		entry_name = dir.get_next()

	dir.list_dir_end()
	return ""


func _resolve_canvas_layer(root_node):
	if root_node == null or not is_instance_valid(root_node):
		return null
	if root_node is CanvasLayer:
		return root_node
	if not (root_node is Node):
		return null

	# Prefer the common names first, but do not require the CanvasLayer to be named
	# exactly "CanvasLayer". Your scene uses LoadingCanvas, so scan by type too.
	for preferred_name in ["LoadingCanvas", "CanvasLayer", "WorldLoadingOverlay"]:
		var named_canvas = root_node.get_node_or_null(preferred_name)
		if named_canvas is CanvasLayer:
			return named_canvas

	return _find_first_canvas_layer_child(root_node)


func _find_first_canvas_layer_child(node: Node):
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is CanvasLayer:
			return child
	for child in node.get_children():
		if child is Node:
			var found = _find_first_canvas_layer_child(child)
			if found is CanvasLayer:
				return found
	return null


func _cache_overlay_nodes() -> void:
	world_loading_root = null
	world_loading_title_label = null
	world_loading_label = null
	world_loading_dots_label = null

	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		return

	var root_node = world_loading_overlay.get_node_or_null("Root")
	if root_node == null:
		root_node = world_loading_overlay.find_child("Root", true, false)
	if root_node is Control:
		world_loading_root = root_node

	if world_loading_root != null:
		var title_node = world_loading_root.get_node_or_null("Center/Box/Title")
		if title_node == null:
			title_node = world_loading_root.find_child("Title", true, false)
		if title_node is Label:
			world_loading_title_label = title_node

		var message_node = world_loading_root.get_node_or_null("Center/Box/Message")
		if message_node == null:
			message_node = world_loading_root.find_child("Message", true, false)
		if message_node is Label:
			world_loading_label = message_node

		var dots_node = world_loading_root.get_node_or_null("Center/Box/Dots")
		if dots_node == null:
			dots_node = world_loading_root.find_child("Dots", true, false)
		if dots_node is Label:
			world_loading_dots_label = dots_node


func _ensure_overlay_content() -> void:
	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		return

	if world_loading_root == null or not is_instance_valid(world_loading_root):
		world_loading_root = Control.new()
		world_loading_root.name = "Root"
		world_loading_overlay.add_child(world_loading_root)

	world_loading_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_loading_root.offset_left = 0.0
	world_loading_root.offset_top = 0.0
	world_loading_root.offset_right = 0.0
	world_loading_root.offset_bottom = 0.0
	world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	world_loading_root.modulate = Color(1, 1, 1, 1)

	var shade = world_loading_root.get_node_or_null("Shade")
	if shade == null or not (shade is ColorRect):
		if shade != null:
			shade.queue_free()
		shade = ColorRect.new()
		shade.name = "Shade"
		world_loading_root.add_child(shade)
		world_loading_root.move_child(shade, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = 0.0
	shade.offset_top = 0.0
	shade.offset_right = 0.0
	shade.offset_bottom = 0.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.05, 0.08, 0.94)

	var center = world_loading_root.get_node_or_null("Center")
	if center == null or not (center is CenterContainer):
		# If your scene had Center as a VBoxContainer from the older code, keep it by renaming it.
		if center != null and center is VBoxContainer:
			center.name = "OldCenterVBox"
		center = CenterContainer.new()
		center.name = "Center"
		world_loading_root.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box = center.get_node_or_null("Box")
	if box == null or not (box is VBoxContainer):
		box = VBoxContainer.new()
		box.name = "Box"
		center.add_child(box)
	box.custom_minimum_size = Vector2(620, 230)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title = box.get_node_or_null("Title")
	if title == null or not (title is Label):
		title = Label.new()
		title.name = "Title"
		box.add_child(title)
	world_loading_title_label = title
	title.text = "LOADING WORLD"
	title.custom_minimum_size = Vector2(620, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	world_loading_label = box.get_node_or_null("Message")
	if world_loading_label == null or not (world_loading_label is Label):
		world_loading_label = Label.new()
		world_loading_label.name = "Message"
		box.add_child(world_loading_label)
	world_loading_label.text = "Loading world..."
	world_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_loading_label.add_theme_font_size_override("font_size", 24)
	world_loading_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1))
	world_loading_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	world_loading_label.add_theme_constant_override("shadow_offset_x", 2)
	world_loading_label.add_theme_constant_override("shadow_offset_y", 2)
	world_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	world_loading_dots_label = box.get_node_or_null("Dots")
	if world_loading_dots_label == null or not (world_loading_dots_label is Label):
		world_loading_dots_label = Label.new()
		world_loading_dots_label.name = "Dots"
		box.add_child(world_loading_dots_label)
	world_loading_dots_label.text = "..."
	world_loading_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_loading_dots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_loading_dots_label.add_theme_font_size_override("font_size", 28)
	world_loading_dots_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1))
	world_loading_dots_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_overlay_visible(is_visible: bool) -> void:
	if world_loading_scene_instance != null and is_instance_valid(world_loading_scene_instance) and world_loading_scene_instance is CanvasItem:
		world_loading_scene_instance.visible = is_visible
	if world_loading_overlay != null and is_instance_valid(world_loading_overlay):
		world_loading_overlay.visible = is_visible
		if world_loading_overlay is CanvasLayer:
			world_loading_overlay.layer = WORLD_LOADING_CANVAS_LAYER
	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.visible = is_visible
		world_loading_root.modulate = Color(1, 1, 1, 1)


func hide_world_menu_overlay_while_loading() -> void:
	if world == null:
		return
	if not ("ui_layer" in world):
		return
	var ui_layer = world.get("ui_layer")
	if ui_layer == null or not is_instance_valid(ui_layer) or not (ui_layer is Node):
		return
	var menu_overlay: Node = (ui_layer as Node).get_node_or_null("WorldMenuOverlay")
	if menu_overlay != null and menu_overlay is CanvasItem:
		(menu_overlay as CanvasItem).visible = false


func raise_loading_overlay_to_front() -> void:
	if world_loading_overlay != null and is_instance_valid(world_loading_overlay) and world_loading_overlay is CanvasLayer:
		world_loading_overlay.layer = WORLD_LOADING_CANVAS_LAYER
	if world_loading_scene_instance != null and is_instance_valid(world_loading_scene_instance):
		var parent_node: Node = world_loading_scene_instance.get_parent()
		if parent_node != null:
			parent_node.move_child(world_loading_scene_instance, parent_node.get_child_count() - 1)


func _get_overlay_tree_summary() -> String:
	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		return "missing overlay"
	var root_ok := world_loading_root != null and is_instance_valid(world_loading_root)
	var message_ok := world_loading_label != null and is_instance_valid(world_loading_label)
	var dots_ok := world_loading_dots_label != null and is_instance_valid(world_loading_dots_label)
	return "overlay=" + str(world_loading_overlay.name) + " root=" + str(root_ok) + " message=" + str(message_ok) + " dots=" + str(dots_ok)


func begin_smooth_world_load(world_name: String, wait_for_server_state: bool = true):
	setup_overlay()

	var clean_world_name := world_name.strip_edges().to_upper()
	if clean_world_name == "":
		clean_world_name = "WORLD"

	waiting_for_server_state = wait_for_server_state
	loading_started_msec = Time.get_ticks_msec()
	next_server_retry_msec = loading_started_msec + WORLD_LOADING_TIMEOUT_MSEC if wait_for_server_state else 0
	server_retry_attempt_count = 0
	finish_wait_started_msec = 0
	finish_wait_running = false
	pending_finish_smooth_load = false
	loading_dot_timer = 0.0
	loading_dot_count = 3
	_lock_player_for_loading()

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()
		world_loading_fade_tween = null

	if world_loading_root != null:
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	update_title_for_world(clean_world_name)
	update_message("Loading " + clean_world_name + "...")
	_set_loading_dots_text("...")
	hide_world_menu_overlay_while_loading()
	_set_overlay_visible(true)
	raise_loading_overlay_to_front()
	_debug("Begin loading world " + clean_world_name + " wait_for_server=" + str(wait_for_server_state))


func update_title_for_world(world_name: String) -> void:
	if world_loading_title_label == null or not is_instance_valid(world_loading_title_label):
		_cache_overlay_nodes()
	if world_loading_title_label == null or not is_instance_valid(world_loading_title_label):
		return
	world_loading_title_label.text = _format_loading_title(world_name)


func _format_loading_title(world_name: String) -> String:
	var clean_world_name := str(world_name).strip_edges().to_upper()
	if clean_world_name == "" or clean_world_name == "WORLD":
		return "LOADING WORLD"
	return "LOADING WORLD: " + clean_world_name


func update_message(message: String):
	if world_loading_label == null or not is_instance_valid(world_loading_label):
		_cache_overlay_nodes()
	if world_loading_label == null or not is_instance_valid(world_loading_label):
		return
	world_loading_label.text = message


func _set_loading_dots_text(text: String) -> void:
	if world_loading_dots_label == null or not is_instance_valid(world_loading_dots_label):
		_cache_overlay_nodes()
	if world_loading_dots_label == null or not is_instance_valid(world_loading_dots_label):
		return
	world_loading_dots_label.text = text


func is_overlay_visible() -> bool:
	return world_loading_overlay != null and is_instance_valid(world_loading_overlay) and bool(world_loading_overlay.visible)


func is_waiting_for_server_state() -> bool:
	return waiting_for_server_state


func finish_smooth_world_load():
	waiting_for_server_state = false
	next_server_retry_msec = 0
	server_retry_attempt_count = 0
	pending_finish_smooth_load = true

	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		_record_world_entry_profile_stage("client_world_revealed")
		_unlock_player_after_loading()
		_complete_world_entry_profile()
		return

	if finish_wait_running:
		return

	finish_wait_running = true
	finish_wait_started_msec = Time.get_ticks_msec()
	call_deferred("_finish_smooth_world_load_when_ready")


func _finish_smooth_world_load_when_ready() -> void:
	if not pending_finish_smooth_load:
		finish_wait_running = false
		return

	var now_msec := Time.get_ticks_msec()
	var timed_out := WORLD_READY_WAIT_TIMEOUT_MSEC > 0 and finish_wait_started_msec > 0 and now_msec - finish_wait_started_msec >= WORLD_READY_WAIT_TIMEOUT_MSEC

	if not timed_out and not is_world_ready_for_player():
		update_message("Preparing player...")
		await get_tree().create_timer(float(WORLD_READY_CHECK_INTERVAL_MSEC) / 1000.0).timeout
		_finish_smooth_world_load_when_ready()
		return

	if timed_out and not is_world_ready_for_player():
		_debug("Ready wait timed out; hiding loading overlay anyway. " + get_world_ready_debug_text())

	var visible_for_msec: int = Time.get_ticks_msec() - loading_started_msec
	if WORLD_LOADING_MIN_VISIBLE_MSEC > 0 and visible_for_msec < WORLD_LOADING_MIN_VISIBLE_MSEC:
		update_message("Entering world...")
		var remaining_msec: int = WORLD_LOADING_MIN_VISIBLE_MSEC - visible_for_msec
		_debug("Keeping loading overlay visible for minimum time. remaining_ms=" + str(remaining_msec))
		await get_tree().create_timer(float(remaining_msec) / 1000.0).timeout
		if not pending_finish_smooth_load:
			finish_wait_running = false
			return

	if WORLD_LOADING_READY_HOLD_MSEC > 0:
		update_message("Entering world...")
		_debug("Holding loading overlay after ready. hold_ms=" + str(WORLD_LOADING_READY_HOLD_MSEC))
		await get_tree().create_timer(float(WORLD_LOADING_READY_HOLD_MSEC) / 1000.0).timeout
		if not pending_finish_smooth_load:
			finish_wait_running = false
			return

	pending_finish_smooth_load = false
	finish_wait_running = false
	_fade_out_loading_overlay()


func _fade_out_loading_overlay() -> void:
	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		_record_world_entry_profile_stage("client_world_revealed")
		_unlock_player_after_loading()
		_complete_world_entry_profile()
		return

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()

	if world_loading_root == null or not is_instance_valid(world_loading_root):
		_set_overlay_visible(false)
		_record_world_entry_profile_stage("client_world_revealed")
		_unlock_player_after_loading()
		_complete_world_entry_profile()
		return

	world_loading_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_loading_fade_tween = create_tween()
	world_loading_fade_tween.tween_property(world_loading_root, "modulate:a", 0.0, 0.12)
	world_loading_fade_tween.tween_callback(Callable(self, "_hide_overlay_after_fade"))


func cancel_smooth_world_load():
	waiting_for_server_state = false
	next_server_retry_msec = 0
	server_retry_attempt_count = 0
	pending_finish_smooth_load = false
	finish_wait_running = false
	finish_wait_started_msec = 0

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()
		world_loading_fade_tween = null

	_set_overlay_visible(false)

	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	_unlock_player_after_loading()


func update_timeout():
	if not waiting_for_server_state:
		return

	var now_msec: int = Time.get_ticks_msec()
	if next_server_retry_msec <= 0:
		next_server_retry_msec = now_msec + WORLD_LOADING_TIMEOUT_MSEC
	if now_msec < next_server_retry_msec:
		return

	# A server-backed entry intentionally has no local terrain while it waits for
	# the authoritative snapshot. Never fail open into that empty staging state.
	if world != null and bool(world.get("applying_network_world_update")):
		update_message("Building " + str(world.get("current_world_name")).strip_edges().to_upper() + "...")
		next_server_retry_msec = now_msec + WORLD_LOADING_TIMEOUT_MSEC
		return

	server_retry_attempt_count += 1
	var retry_delay_msec: int = mini(
		WORLD_LOADING_TIMEOUT_MSEC * (server_retry_attempt_count + 1),
		WORLD_LOADING_RETRY_MAX_MSEC
	)
	next_server_retry_msec = now_msec + retry_delay_msec

	var retry_sent := false
	var should_retry: bool = server_retry_attempt_count > WORLD_LOADING_RETRY_GRACE_ATTEMPTS
	if should_retry and world != null and world.save_manager != null and world.save_manager.has_method("retry_server_world_entry"):
		retry_sent = bool(world.save_manager.retry_server_world_entry("loading_timeout"))

	var target_world := str(world.get("current_world_name")).strip_edges().to_upper() if world != null else "WORLD"
	update_message(("Retrying " if retry_sent else "Waiting for ") + target_world + " server data...")
	_debug(
		"Authoritative world wait timed out; kept staging world hidden"
		+ " attempt=" + str(server_retry_attempt_count)
		+ " requested_retry=" + str(retry_sent)
	)


func is_world_ready_for_player() -> bool:
	if world == null:
		return false

	if bool(world.get_meta("world_entry_in_progress", false)):
		return false

	if waiting_for_server_state:
		return false

	if bool(world.get("applying_network_world_update")):
		return false

	if bool(world.get_meta("world_bulk_load_in_progress", false)):
		return false

	var save_manager_value = world.get("save_manager")
	if save_manager_value != null and "waiting_for_server_world_state" in save_manager_value:
		if bool(save_manager_value.get("waiting_for_server_world_state")):
			return false

	var in_world_value = world.get("in_world")
	if in_world_value == null or not bool(in_world_value):
		return false

	var server_blocks_value = world.get("blocks")
	if server_blocks_value is Dictionary:
		var server_blocks: Dictionary = server_blocks_value
		if server_blocks.is_empty():
			return false

	if _is_dedicated_netfox_server_without_local_player():
		return true

	var player_value = world.get("player")
	if player_value == null or not is_instance_valid(player_value):
		return false
	if not (player_value is Node2D):
		return false

	var player_node: Node2D = player_value
	if player_node is CanvasItem and not bool(player_node.visible):
		return false
	if not is_finite(player_node.global_position.x) or not is_finite(player_node.global_position.y):
		return false

	var blocks_value = world.get("blocks")
	if blocks_value is Dictionary:
		var blocks: Dictionary = blocks_value
		if blocks.is_empty():
			return false

	if _is_netfox_local_player_ready(player_node):
		return true

	if player_node is CharacterBody2D and not bool(world.get("noclip_enabled")):
		if not bool(player_node.is_physics_processing()):
			return false

	var camera_node = _get_player_camera_node()
	if camera_node == null or not is_instance_valid(camera_node):
		return false

	return true


func _is_dedicated_netfox_server_without_local_player() -> bool:
	if not _is_netfox_real_mode():
		return false
	if not MovementMode.has_method("is_netfox_real_server_launch"):
		return false
	if not bool(MovementMode.is_netfox_real_server_launch()):
		return false

	var player_value = world.get("player") if world != null else null
	return player_value == null or not is_instance_valid(player_value)


func _is_netfox_real_mode() -> bool:
	if MovementMode == null:
		return false
	if not MovementMode.has_method("is_netfox_real"):
		return false
	return bool(MovementMode.is_netfox_real())


func _is_netfox_local_player_ready(player_node: Node2D) -> bool:
	if not _is_netfox_real_mode():
		return false
	if MovementMode.has_method("is_netfox_real_server_launch") and bool(MovementMode.is_netfox_real_server_launch()):
		return false
	if world == null:
		return false
	if player_node == null or not is_instance_valid(player_node):
		return false
	if world.get("player") != player_node:
		return false

	var netfox_manager = world.get("netfox_real_manager")
	if netfox_manager != null and netfox_manager.has_method("is_local_player_ready_for_world"):
		return bool(netfox_manager.is_local_player_ready_for_world())

	return true


func get_world_ready_debug_text() -> String:
	if world == null:
		return "world=null"
	var parts: Array[String] = []
	parts.append("netfox=" + str(_is_netfox_real_mode()))
	parts.append("entry=" + str(world.get_meta("world_entry_in_progress", false)))
	parts.append("waiting=" + str(waiting_for_server_state))
	parts.append("bulk=" + str(world.get_meta("world_bulk_load_in_progress", false)))
	parts.append("applying=" + str(world.get("applying_network_world_update")))
	parts.append("in_world=" + str(world.get("in_world")))
	var player_value = world.get("player")
	parts.append("player=" + str(player_value != null and is_instance_valid(player_value)))
	if player_value is Node:
		parts.append("player_physics=" + str((player_value as Node).is_physics_processing()))
	var blocks_value = world.get("blocks")
	parts.append("blocks=" + str(blocks_value.size() if blocks_value is Dictionary else -1))
	parts.append("camera=" + str(_get_player_camera_node() != null))
	return ", ".join(parts)


func _get_player_camera_node():
	if world == null:
		return null

	if world.has_method("get_player_camera"):
		var camera_value = world.get_player_camera()
		if camera_value != null and is_instance_valid(camera_value):
			return camera_value

	var player_value = world.get("player")
	if player_value == null or not is_instance_valid(player_value):
		return null

	if player_value is Node:
		var direct_camera = player_value.get_node_or_null("Camera2D")
		if direct_camera != null and is_instance_valid(direct_camera):
			return direct_camera
		var found_camera = player_value.find_child("Camera2D", true, false)
		if found_camera != null and is_instance_valid(found_camera):
			return found_camera

	return null


func _lock_player_for_loading() -> void:
	if world == null:
		return

	if _is_netfox_real_mode():
		world.set_meta("world_loading_input_blocked", false)
		return

	world.set_meta("world_loading_input_blocked", true)

	var player_value = world.get("player")
	if player_value == null or not is_instance_valid(player_value):
		return

	if player_value is CharacterBody2D:
		player_value.velocity = Vector2.ZERO
		player_value.set_physics_process(false)


func _unlock_player_after_loading() -> void:
	if world == null:
		return

	world.set_meta("world_loading_input_blocked", false)

	var player_value = world.get("player")
	if player_value == null or not is_instance_valid(player_value):
		return

	if player_value is CharacterBody2D and not bool(world.get("noclip_enabled")):
		player_value.velocity = Vector2.ZERO
		player_value.set_physics_process(true)


func _complete_world_entry_profile() -> void:
	var network := get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("complete_world_entry_profile"):
		network.complete_world_entry_profile({
			"loading_visible_ms": maxi(0, Time.get_ticks_msec() - loading_started_msec)
		})


func _record_world_entry_profile_stage(stage: String, extra: Dictionary = {}) -> void:
	var network := get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("record_world_entry_stage"):
		network.record_world_entry_stage(stage, extra)


func _hide_overlay_after_fade():
	_set_overlay_visible(false)

	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	world_loading_fade_tween = null
	_record_world_entry_profile_stage("client_world_revealed")
	_unlock_player_after_loading()
	_complete_world_entry_profile()
	_debug("Loading overlay hidden")
