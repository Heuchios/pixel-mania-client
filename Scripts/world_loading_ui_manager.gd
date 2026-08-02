extends Node

const WORLD_LOADING_TIMEOUT_MSEC := 6000
const WORLD_LOADING_RETRY_MAX_MSEC := 20000
const WORLD_LOADING_RETRY_GRACE_ATTEMPTS := 1
const WORLD_LOADING_SERVER_RETRY_MAX_ATTEMPTS := 6
# Never fail-open from the loading overlay into an empty staging world. If
# readiness stalls, keep the overlay visible and request a fresh snapshot.
const WORLD_READY_WAIT_TIMEOUT_MSEC := 8000
const WORLD_READY_CHECK_INTERVAL_MSEC := 50
const WORLD_READY_RETRY_INTERVAL_MSEC := 1000
const WORLD_READY_RETRY_MAX_ATTEMPTS := 6
# Do not add cosmetic delay after the authoritative world/player checks pass.
const WORLD_LOADING_MIN_VISIBLE_MSEC := 0
const WORLD_LOADING_READY_HOLD_MSEC := 0
const WORLD_LOADING_DOTS_INTERVAL := 0.32
const WORLD_LOADING_INITIAL_PROGRESS := 8.0
const WORLD_LOADING_PASSIVE_PROGRESS_MAX := 88.0
const WORLD_LOADING_PASSIVE_PROGRESS_PER_SECOND := 7.5
const WORLD_LOADING_PROGRESS_APPROACH_SPEED := 42.0
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

enum LoadingStage {
	IDLE,
	WAITING_FOR_SERVER_SNAPSHOT,
	APPLYING_WORLD,
	WAITING_FOR_SERVER_ACTIVE,
	WAITING_FOR_CLIENT_READY,
	READY,
	FAILED
}

var world = null
var world_loading_scene_instance = null
var world_loading_overlay = null
var world_loading_root: Control = null
var world_loading_title_label: Label = null
var world_loading_label: Label = null
var world_loading_dots_label: Label = null
var world_loading_progress_bar: TextureProgressBar = null
var world_loading_progress_label: Label = null
var world_loading_version_label: Label = null
var world_loading_fade_tween = null
var waiting_for_server_state := false
var loading_started_msec := 0
var next_server_retry_msec := 0
var server_retry_attempt_count := 0
var finish_wait_started_msec := 0
var finish_wait_running := false
var pending_finish_smooth_load := false
var last_world_ready_retry_msec := 0
var world_ready_retry_attempt_count := 0
var loading_dot_timer := 0.0
var loading_dot_count := 0
var loading_progress_value := 0.0
var loading_progress_target := 0.0
var active_loading_world_name: String = ""
var loading_operation_id: int = 0
var loading_stage = LoadingStage.IDLE
var loading_stage_reason: String = ""
var loading_failure_reason: String = ""


func _debug(message: String) -> void:
	if DEBUG_WORLD_LOADING_UI:
		print("[WorldLoadingUI] " + message)


func _get_loading_stage_name(stage_value = -1) -> String:
	var value: int = int(loading_stage) if int(stage_value) < 0 else int(stage_value)
	match value:
		LoadingStage.IDLE:
			return "idle"
		LoadingStage.WAITING_FOR_SERVER_SNAPSHOT:
			return "waiting_for_server_snapshot"
		LoadingStage.APPLYING_WORLD:
			return "applying_world"
		LoadingStage.WAITING_FOR_SERVER_ACTIVE:
			return "waiting_for_server_active"
		LoadingStage.WAITING_FOR_CLIENT_READY:
			return "waiting_for_client_ready"
		LoadingStage.READY:
			return "ready"
		LoadingStage.FAILED:
			return "failed"
		_:
			return "unknown"


func _set_loading_stage(next_stage, reason: String = "") -> void:
	var changed := int(loading_stage) != int(next_stage)
	if not changed and reason == loading_stage_reason:
		return

	loading_stage = next_stage
	loading_stage_reason = reason
	if int(next_stage) == LoadingStage.FAILED:
		loading_failure_reason = reason
	elif changed:
		loading_failure_reason = ""

	var stage_name := _get_loading_stage_name(next_stage)
	_debug("Stage=" + stage_name + (" reason=" + reason if reason != "" else ""))
	_record_world_entry_profile_stage("client_loading_stage", {
		"stage": stage_name,
		"reason": reason
	})


func _get_network_manager() -> Node:
	var scene_tree: SceneTree = null
	if is_inside_tree():
		scene_tree = get_tree()
	elif world != null and is_instance_valid(world) and world is Node and (world as Node).is_inside_tree():
		scene_tree = (world as Node).get_tree()

	if scene_tree == null or scene_tree.root == null:
		return null

	var network_manager := scene_tree.root.get_node_or_null("NetworkManager")
	if network_manager is Node:
		return network_manager
	return null


func setup(world_ref):
	world = world_ref
	setup_overlay()


func _process(delta: float) -> void:
	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		return
	if not bool(world_loading_overlay.visible):
		return

	_update_loading_progress(delta)

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
	world_loading_progress_bar = null
	world_loading_progress_label = null
	world_loading_version_label = null

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

		var progress_bar_node = world_loading_root.get_node_or_null("Center/Box/ProgressBar")
		if progress_bar_node == null:
			progress_bar_node = world_loading_root.find_child("ProgressBar", true, false)
		if progress_bar_node is TextureProgressBar:
			world_loading_progress_bar = progress_bar_node

		var progress_label_node = world_loading_root.get_node_or_null("Center/Box/ProgressPercent")
		if progress_label_node == null:
			progress_label_node = world_loading_root.find_child("ProgressPercent", true, false)
		if progress_label_node is Label:
			world_loading_progress_label = progress_label_node

		var version_node = world_loading_root.get_node_or_null("Version")
		if version_node == null:
			version_node = world_loading_root.find_child("Version", true, false)
		if version_node is Label:
			world_loading_version_label = version_node


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
	var created_shade := false
	if shade == null or not (shade is ColorRect):
		if shade != null:
			shade.queue_free()
		shade = ColorRect.new()
		shade.name = "Shade"
		world_loading_root.add_child(shade)
		world_loading_root.move_child(shade, 0)
		created_shade = true
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = 0.0
	shade.offset_top = 0.0
	shade.offset_right = 0.0
	shade.offset_bottom = 0.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if created_shade:
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
	var created_box := false
	if box == null or not (box is VBoxContainer):
		box = VBoxContainer.new()
		box.name = "Box"
		center.add_child(box)
		created_box = true
	if created_box:
		box.custom_minimum_size = Vector2(620, 230)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	if created_box:
		box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title = box.get_node_or_null("Title")
	var created_title := false
	if title == null or not (title is Label):
		title = Label.new()
		title.name = "Title"
		box.add_child(title)
		created_title = true
	world_loading_title_label = title
	title.text = "LOADING WORLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if created_title:
		title.custom_minimum_size = Vector2(620, 70)
		title.add_theme_font_size_override("font_size", 56)
		title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		title.add_theme_constant_override("shadow_offset_x", 4)
		title.add_theme_constant_override("shadow_offset_y", 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	world_loading_label = box.get_node_or_null("Message")
	var created_message := false
	if world_loading_label == null or not (world_loading_label is Label):
		world_loading_label = Label.new()
		world_loading_label.name = "Message"
		box.add_child(world_loading_label)
		created_message = true
	world_loading_label.text = "Loading world..."
	world_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if created_message:
		world_loading_label.add_theme_font_size_override("font_size", 24)
		world_loading_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1))
		world_loading_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		world_loading_label.add_theme_constant_override("shadow_offset_x", 2)
		world_loading_label.add_theme_constant_override("shadow_offset_y", 2)
	world_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	world_loading_dots_label = box.get_node_or_null("Dots")
	var created_dots := false
	if world_loading_dots_label == null or not (world_loading_dots_label is Label):
		world_loading_dots_label = Label.new()
		world_loading_dots_label.name = "Dots"
		box.add_child(world_loading_dots_label)
		created_dots = true
	world_loading_dots_label.text = "..."
	world_loading_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_loading_dots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if created_dots:
		world_loading_dots_label.add_theme_font_size_override("font_size", 28)
		world_loading_dots_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1))
	world_loading_dots_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_cache_overlay_nodes()
	_refresh_loading_version_label()
	_apply_loading_progress_visuals()


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

	var now_msec: int = Time.get_ticks_msec()
	var same_active_operation: bool = (
		active_loading_world_name == clean_world_name
		and (is_overlay_visible() or pending_finish_smooth_load or finish_wait_running)
	)
	if same_active_operation:
		if wait_for_server_state and not pending_finish_smooth_load and not finish_wait_running:
			waiting_for_server_state = true
			if next_server_retry_msec <= 0:
				next_server_retry_msec = now_msec + WORLD_LOADING_TIMEOUT_MSEC
			_set_loading_stage(LoadingStage.WAITING_FOR_SERVER_SNAPSHOT, "reused_operation_waiting")
		_lock_player_for_loading()
		update_title_for_world(clean_world_name)
		hide_world_menu_overlay_while_loading()
		_set_overlay_visible(true)
		raise_loading_overlay_to_front()
		_debug(
			"Reusing active loading operation world=" + clean_world_name
			+ " operation_id=" + str(loading_operation_id)
			+ " wait_for_server=" + str(wait_for_server_state)
		)
		return

	loading_operation_id += 1
	active_loading_world_name = clean_world_name
	waiting_for_server_state = wait_for_server_state
	loading_started_msec = now_msec
	next_server_retry_msec = loading_started_msec + WORLD_LOADING_TIMEOUT_MSEC if wait_for_server_state else 0
	server_retry_attempt_count = 0
	last_world_ready_retry_msec = 0
	world_ready_retry_attempt_count = 0
	finish_wait_started_msec = 0
	finish_wait_running = false
	pending_finish_smooth_load = false
	_set_loading_stage(
		LoadingStage.WAITING_FOR_SERVER_SNAPSHOT if wait_for_server_state else LoadingStage.APPLYING_WORLD,
		"begin_world_load"
	)
	loading_dot_timer = 0.0
	loading_dot_count = 3
	_lock_player_for_loading()

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()
		world_loading_fade_tween = null

	if world_loading_root != null:
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	_set_loading_progress(WORLD_LOADING_INITIAL_PROGRESS, true)
	update_title_for_world(clean_world_name)
	update_message("Loading " + clean_world_name + "...")
	_set_loading_dots_text("...")
	hide_world_menu_overlay_while_loading()
	_set_overlay_visible(true)
	raise_loading_overlay_to_front()
	_debug(
		"Begin loading world " + clean_world_name
		+ " operation_id=" + str(loading_operation_id)
		+ " wait_for_server=" + str(wait_for_server_state)
	)


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
	_advance_loading_progress_for_message(message)


func _set_loading_dots_text(text: String) -> void:
	if world_loading_dots_label == null or not is_instance_valid(world_loading_dots_label):
		_cache_overlay_nodes()
	if world_loading_dots_label == null or not is_instance_valid(world_loading_dots_label):
		return
	world_loading_dots_label.text = text


func _update_loading_progress(delta: float) -> void:
	if loading_started_msec > 0 and loading_progress_target < 100.0:
		var elapsed_seconds: float = maxf(0.0, float(Time.get_ticks_msec() - loading_started_msec) / 1000.0)
		var passive_target: float = minf(
			WORLD_LOADING_PASSIVE_PROGRESS_MAX,
			WORLD_LOADING_INITIAL_PROGRESS + elapsed_seconds * WORLD_LOADING_PASSIVE_PROGRESS_PER_SECOND
		)
		loading_progress_target = maxf(loading_progress_target, passive_target)

	var next_value: float = move_toward(
		loading_progress_value,
		loading_progress_target,
		WORLD_LOADING_PROGRESS_APPROACH_SPEED * delta
	)
	if is_equal_approx(next_value, loading_progress_value):
		return
	loading_progress_value = next_value
	_apply_loading_progress_visuals()


func _advance_loading_progress_for_message(message: String) -> void:
	var lower_message := message.strip_edges().to_lower()
	var stage_target := 42.0
	if "retry" in lower_message or "waiting" in lower_message:
		stage_target = 30.0
	elif "building" in lower_message:
		stage_target = 62.0
	elif "preparing" in lower_message:
		stage_target = 88.0
	elif "entering" in lower_message:
		stage_target = 96.0
	elif "loading" in lower_message:
		stage_target = 38.0
	_set_loading_progress(maxf(loading_progress_target, stage_target), false)


func _set_loading_progress(value: float, immediate: bool = false) -> void:
	loading_progress_target = clampf(value, 0.0, 100.0)
	if immediate:
		loading_progress_value = loading_progress_target
		_apply_loading_progress_visuals()


func _apply_loading_progress_visuals() -> void:
	var rounded_progress := clampi(int(round(loading_progress_value)), 0, 100)
	if world_loading_progress_bar != null and is_instance_valid(world_loading_progress_bar):
		world_loading_progress_bar.max_value = 100.0
		world_loading_progress_bar.value = float(rounded_progress)
	if world_loading_progress_label != null and is_instance_valid(world_loading_progress_label):
		world_loading_progress_label.text = str(rounded_progress) + "%"


func _refresh_loading_version_label() -> void:
	if world_loading_version_label == null or not is_instance_valid(world_loading_version_label):
		return
	var client_version := "1.0.4"
	var network_manager := _get_network_manager()
	if network_manager != null and network_manager.has_method("get_client_version"):
		var reported_version := str(network_manager.call("get_client_version")).strip_edges()
		if reported_version != "":
			client_version = reported_version
	world_loading_version_label.text = "Alpha-" + client_version


func is_overlay_visible() -> bool:
	return world_loading_overlay != null and is_instance_valid(world_loading_overlay) and bool(world_loading_overlay.visible)


func is_waiting_for_server_state() -> bool:
	return waiting_for_server_state or int(loading_stage) == LoadingStage.FAILED


func finish_smooth_world_load():
	var operation_id: int = loading_operation_id
	if _has_authoritative_world_entry_pending():
		waiting_for_server_state = true
		if next_server_retry_msec <= 0:
			next_server_retry_msec = Time.get_ticks_msec() + WORLD_LOADING_TIMEOUT_MSEC
		last_world_ready_retry_msec = 0
		world_ready_retry_attempt_count = 0
		pending_finish_smooth_load = false
		finish_wait_running = false
		finish_wait_started_msec = 0
		_set_loading_stage(_get_authoritative_pending_stage(), "finish_deferred_authoritative_pending")
		update_message(_get_authoritative_pending_message())
		var readiness := get_world_ready_debug_text()
		_debug("Finish requested before authoritative entry completed; keeping loading overlay visible. " + readiness)
		_record_world_entry_profile_stage("client_world_finish_deferred_authoritative_pending", {
			"operation_id": operation_id,
			"readiness": readiness
		})
		return

	waiting_for_server_state = false
	next_server_retry_msec = 0
	server_retry_attempt_count = 0
	last_world_ready_retry_msec = 0
	world_ready_retry_attempt_count = 0
	pending_finish_smooth_load = true
	_set_loading_stage(LoadingStage.WAITING_FOR_CLIENT_READY, "finish_requested")

	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		_finalize_loading_operation(operation_id, "Loading completed without an overlay")
		return

	if finish_wait_running:
		return

	finish_wait_running = true
	finish_wait_started_msec = Time.get_ticks_msec()
	call_deferred("_finish_smooth_world_load_when_ready", operation_id)


func _request_world_ready_snapshot_retry(reason: String) -> bool:
	var network_manager: Node = _get_network_manager()
	if network_manager != null and network_manager.has_method("request_current_world_entry_snapshot_restart"):
		var restart_sent := bool(network_manager.call("request_current_world_entry_snapshot_restart", reason))
		if restart_sent:
			return true

	var save_manager_value = _get_save_manager_value()
	if save_manager_value != null and save_manager_value.has_method("retry_server_world_entry"):
		return bool(save_manager_value.retry_server_world_entry(reason))

	return false


func _get_save_manager_value():
	if world == null:
		return null
	if not ("save_manager" in world):
		return null
	return world.get("save_manager")


func _is_save_manager_waiting_for_server_world_state() -> bool:
	var save_manager_value = _get_save_manager_value()
	if save_manager_value == null:
		return false
	if not ("waiting_for_server_world_state" in save_manager_value):
		return false
	return bool(save_manager_value.get("waiting_for_server_world_state"))


func _has_authoritative_world_entry_pending() -> bool:
	if world == null:
		return false
	if bool(world.get("applying_network_world_update")):
		return true
	if bool(world.get_meta("world_entry_in_progress", false)):
		return true
	if bool(world.get_meta("world_bulk_load_in_progress", false)):
		return true
	return _is_save_manager_waiting_for_server_world_state()


func _get_authoritative_pending_stage():
	if world != null and bool(world.get("applying_network_world_update")):
		return LoadingStage.APPLYING_WORLD
	if world != null and bool(world.get_meta("world_bulk_load_in_progress", false)):
		return LoadingStage.APPLYING_WORLD
	return LoadingStage.WAITING_FOR_SERVER_ACTIVE


func _get_authoritative_pending_message() -> String:
	var target_world := str(world.get("current_world_name")).strip_edges().to_upper() if world != null else "WORLD"
	if target_world == "":
		target_world = "WORLD"
	if world != null and bool(world.get("applying_network_world_update")):
		return "Building " + target_world + "..."
	if _is_save_manager_waiting_for_server_world_state():
		return "Confirming " + target_world + " with server..."
	return "Preparing " + target_world + "..."


func _finish_smooth_world_load_when_ready(operation_id: int) -> void:
	if operation_id != loading_operation_id:
		return
	if not pending_finish_smooth_load:
		finish_wait_running = false
		return

	var now_msec := Time.get_ticks_msec()
	var timed_out := WORLD_READY_WAIT_TIMEOUT_MSEC > 0 and finish_wait_started_msec > 0 and now_msec - finish_wait_started_msec >= WORLD_READY_WAIT_TIMEOUT_MSEC
	var world_ready := is_world_ready_for_player()

	if not timed_out and not world_ready:
		_set_loading_stage(LoadingStage.WAITING_FOR_CLIENT_READY, "client_ready_checks")
		update_message("Preparing player...")
		await get_tree().create_timer(float(WORLD_READY_CHECK_INTERVAL_MSEC) / 1000.0).timeout
		if operation_id != loading_operation_id:
			return
		_finish_smooth_world_load_when_ready(operation_id)
		return

	var ready_wait_msec: int = maxi(0, now_msec - finish_wait_started_msec)
	if timed_out and not world_ready:
		var retry_sent := false
		if last_world_ready_retry_msec <= 0 or now_msec - last_world_ready_retry_msec >= WORLD_READY_RETRY_INTERVAL_MSEC:
			last_world_ready_retry_msec = now_msec
			world_ready_retry_attempt_count += 1
			if world_ready_retry_attempt_count > WORLD_READY_RETRY_MAX_ATTEMPTS:
				_fail_loading_operation(
					"client_world_ready_timeout",
					"World loading stalled while preparing the player. Returning to the lobby.",
					{
						"wait_ms": ready_wait_msec,
						"retry_attempt": world_ready_retry_attempt_count,
						"readiness": get_world_ready_debug_text()
					}
				)
				return
			retry_sent = _request_world_ready_snapshot_retry("world_ready_timeout")

		_debug(
			"Ready wait timed out; keeping loading overlay visible."
			+ " retry_attempt=" + str(world_ready_retry_attempt_count)
			+ " retry_sent=" + str(retry_sent)
			+ " " + get_world_ready_debug_text()
		)
		_record_world_entry_profile_stage("client_world_ready_timeout_retry", {
			"wait_ms": ready_wait_msec,
			"retry_attempt": world_ready_retry_attempt_count,
			"retry_sent": retry_sent,
			"readiness": get_world_ready_debug_text(),
		})
		if retry_sent:
			update_message("Retrying world state...")
		else:
			update_message("Preparing world state...")
		finish_wait_started_msec = now_msec
		await get_tree().create_timer(float(WORLD_READY_CHECK_INTERVAL_MSEC) / 1000.0).timeout
		if operation_id != loading_operation_id:
			return
		_finish_smooth_world_load_when_ready(operation_id)
		return
	else:
		_set_loading_stage(LoadingStage.READY, "client_world_ready")
		_record_world_entry_profile_stage("client_world_ready", {"wait_ms": ready_wait_msec})

	var visible_for_msec: int = Time.get_ticks_msec() - loading_started_msec
	if WORLD_LOADING_MIN_VISIBLE_MSEC > 0 and visible_for_msec < WORLD_LOADING_MIN_VISIBLE_MSEC:
		update_message("Entering world...")
		var remaining_msec: int = WORLD_LOADING_MIN_VISIBLE_MSEC - visible_for_msec
		_debug("Keeping loading overlay visible for minimum time. remaining_ms=" + str(remaining_msec))
		await get_tree().create_timer(float(remaining_msec) / 1000.0).timeout
		if operation_id != loading_operation_id:
			return
		if not pending_finish_smooth_load:
			finish_wait_running = false
			return

	if WORLD_LOADING_READY_HOLD_MSEC > 0:
		update_message("Entering world...")
		_debug("Holding loading overlay after ready. hold_ms=" + str(WORLD_LOADING_READY_HOLD_MSEC))
		await get_tree().create_timer(float(WORLD_LOADING_READY_HOLD_MSEC) / 1000.0).timeout
		if operation_id != loading_operation_id:
			return
		if not pending_finish_smooth_load:
			finish_wait_running = false
			return

	pending_finish_smooth_load = false
	finish_wait_running = false
	_set_loading_progress(100.0, true)
	_fade_out_loading_overlay(operation_id)


func _fade_out_loading_overlay(operation_id: int) -> void:
	if operation_id != loading_operation_id:
		return
	if world_loading_overlay == null or not is_instance_valid(world_loading_overlay):
		_finalize_loading_operation(operation_id, "Loading completed without an overlay")
		return

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()

	if world_loading_root == null or not is_instance_valid(world_loading_root):
		_finalize_loading_operation(operation_id, "Loading overlay hidden without a root")
		return

	world_loading_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_loading_fade_tween = create_tween()
	world_loading_fade_tween.tween_property(world_loading_root, "modulate:a", 0.0, 0.12)
	world_loading_fade_tween.tween_callback(Callable(self, "_hide_overlay_after_fade").bind(operation_id))


func cancel_smooth_world_load():
	loading_operation_id += 1
	active_loading_world_name = ""
	waiting_for_server_state = false
	next_server_retry_msec = 0
	server_retry_attempt_count = 0
	last_world_ready_retry_msec = 0
	world_ready_retry_attempt_count = 0
	pending_finish_smooth_load = false
	finish_wait_running = false
	finish_wait_started_msec = 0
	_set_loading_stage(LoadingStage.IDLE, "cancelled")

	if world_loading_fade_tween != null:
		world_loading_fade_tween.kill()
		world_loading_fade_tween = null

	_set_overlay_visible(false)

	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	_unlock_player_after_loading()
	loading_started_msec = 0


func update_timeout():
	if not waiting_for_server_state:
		return
	if int(loading_stage) == LoadingStage.FAILED:
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
	var target_world := str(world.get("current_world_name")).strip_edges().to_upper() if world != null else "WORLD"
	if target_world == "":
		target_world = "WORLD"
	if server_retry_attempt_count > WORLD_LOADING_SERVER_RETRY_MAX_ATTEMPTS:
		_fail_loading_operation(
			"server_world_state_timeout",
			"Could not load " + target_world + " from the server. Returning to the lobby.",
			{
				"retry_attempt": server_retry_attempt_count,
				"readiness": get_world_ready_debug_text()
			}
		)
		return

	var retry_delay_msec: int = mini(
		WORLD_LOADING_TIMEOUT_MSEC * (server_retry_attempt_count + 1),
		WORLD_LOADING_RETRY_MAX_MSEC
	)
	next_server_retry_msec = now_msec + retry_delay_msec

	var retry_sent := false
	var should_retry: bool = server_retry_attempt_count > WORLD_LOADING_RETRY_GRACE_ATTEMPTS
	if should_retry:
		retry_sent = _request_world_ready_snapshot_retry("loading_timeout")

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

	if _is_save_manager_waiting_for_server_world_state():
		return false

	var in_world_value = world.get("in_world")
	if in_world_value == null or not bool(in_world_value):
		return false

	# Empty authoritative worlds are valid. Completion is represented by the
	# entry/apply flags above, not by the number of foreground blocks.

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

	if _is_netfox_local_player_ready(player_node):
		return true

	if player_node is CharacterBody2D and not bool(world.get("noclip_enabled")):
		var loading_paused_player_physics := bool(world.get_meta("world_loading_input_blocked", false))
		if not bool(player_node.is_physics_processing()) and not loading_paused_player_physics:
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
	parts.append("stage=" + _get_loading_stage_name())
	parts.append("netfox=" + str(_is_netfox_real_mode()))
	parts.append("entry=" + str(world.get_meta("world_entry_in_progress", false)))
	parts.append("waiting=" + str(waiting_for_server_state))
	parts.append("save_waiting=" + str(_is_save_manager_waiting_for_server_world_state()))
	parts.append("bulk=" + str(world.get_meta("world_bulk_load_in_progress", false)))
	parts.append("bulk_reason=" + str(world.get_meta("world_bulk_load_reason", "")))
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
	var network := _get_network_manager()
	if network != null and network.has_method("complete_world_entry_profile"):
		network.complete_world_entry_profile({
			"loading_visible_ms": maxi(0, Time.get_ticks_msec() - loading_started_msec)
		})


func _record_world_entry_profile_stage(stage: String, extra: Dictionary = {}) -> void:
	var network := _get_network_manager()
	if network != null and network.has_method("record_world_entry_stage"):
		network.record_world_entry_stage(stage, extra)


func _fail_loading_operation(reason: String, message: String, extra: Dictionary = {}) -> void:
	_set_loading_stage(LoadingStage.FAILED, reason)
	waiting_for_server_state = false
	next_server_retry_msec = 0
	server_retry_attempt_count = 0
	last_world_ready_retry_msec = 0
	world_ready_retry_attempt_count = 0
	pending_finish_smooth_load = false
	finish_wait_running = false
	finish_wait_started_msec = 0
	update_message(message)
	_set_loading_dots_text("")

	var details := extra.duplicate(false)
	details["reason"] = reason
	details["message"] = message
	details["readiness"] = get_world_ready_debug_text()
	_record_world_entry_profile_stage("client_world_loading_failed", details)
	_debug("World loading failed; reason=" + reason + " " + get_world_ready_debug_text())
	call_deferred("_cleanup_failed_world_entry", reason, message)


func _cleanup_failed_world_entry(reason: String, message: String) -> void:
	var handled := false
	var save_manager_value = _get_save_manager_value()
	if save_manager_value != null and save_manager_value.has_method("handle_client_world_loading_failed"):
		handled = bool(save_manager_value.handle_client_world_loading_failed(reason, message))

	if handled:
		return

	var network := _get_network_manager()
	if network != null and network.has_method("cancel_active_join_request"):
		network.cancel_active_join_request()

	if world != null:
		world.set_meta("world_entry_in_progress", false)
		world.set_meta("world_entry_force_entrance_spawn", false)
		world.set_meta("world_bulk_load_in_progress", false)
		world.set_meta("world_bulk_load_reason", "")
		if "in_world" in world:
			world.set("in_world", false)
	cancel_smooth_world_load()


func _finalize_loading_operation(operation_id: int, debug_message: String) -> void:
	if operation_id != loading_operation_id:
		return

	_set_overlay_visible(false)

	if world_loading_root != null and is_instance_valid(world_loading_root):
		world_loading_root.modulate = Color(1, 1, 1, 1)
		world_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP

	world_loading_fade_tween = null
	_record_world_entry_profile_stage("client_world_revealed")
	_unlock_player_after_loading()
	_complete_world_entry_profile()
	waiting_for_server_state = false
	next_server_retry_msec = 0
	server_retry_attempt_count = 0
	last_world_ready_retry_msec = 0
	world_ready_retry_attempt_count = 0
	pending_finish_smooth_load = false
	finish_wait_running = false
	finish_wait_started_msec = 0
	active_loading_world_name = ""
	loading_started_msec = 0
	_set_loading_stage(LoadingStage.IDLE, "finalized")
	_debug(debug_message)


func _hide_overlay_after_fade(operation_id: int) -> void:
	_finalize_loading_operation(operation_id, "Loading overlay hidden")
