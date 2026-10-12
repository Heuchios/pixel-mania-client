extends Node
## Shared presentation only: logical visibility and transaction callbacks stay immediate.
## Render transforms leave Control layout, hit rectangles and mobile scaling untouched.

const OPEN_SECONDS := 0.28
const CLOSE_SECONDS := 0.18
const SCENE_WINDOWS := {
	"InventoryScene.tscn": "Window",
	"InventoryUpgradeConfirm.tscn": "Window",
	"RecipeBookScene.tscn": "Window",
	"PlayerProfileScene.tscn": "CenterContainer/ProfileWindow",
	"LeaderboardScene.tscn": "CenterContainer/LeaderboardWindow",
	"MenuScene.tscn": "CenterContainer/MenuWindow",
}
const NESTED_WINDOWS := {
	"InventoryPicker": "PickerPanel",
	"FinalConfirmOverlay": "FinalPanel",
}
const PANEL_SCRIPTS := [
	"trade_ui", "vending_ui", "area_lock_ui", "world_lock_scene_ui", "world_lock_ui",
	"donation_box_ui", "bulletin_board_ui", "mailbox_ui", "safe_ui", "display_ui",
	"cctv_ui", "battery_charger_ui", "oil_refinery_ui", "generator_ui", "magnet_machine_ui",
	"crafting_ui", "furnace_ui", "friends_ui", "player_menu_ui", "game_menu_ui",
	"world_menu_ui", "sign_ui", "landfill_ui", "landfill_waiting_room_ui",
	"developer_panel_ui", "daily_rewards_ui", "fishing_journal_ui", "fish_monger_ui",
	"quest_board_ui", "settings_panel", "world_tax_panel", "vending_purchase_confirmation",
	"item_action_popup"
]

var windows: Dictionary = {}
var active: Dictionary = {}
var dismiss_revisions: Dictionary = {}
var pending_configuration: Dictionary = {}

const CLOSE_METHODS := ["cancel_trade_ui", "close_settings", "close_recipe_book", "close_inventory", "close_rewards", "close_journal", "close_fish_monger", "close_vending", "close_safe", "close_display", "close_donation_box", "close_mailbox", "close_bulletin_board", "close_cctv", "close_oil_refinery", "close_battery_charger", "close_generator", "close_crafting", "close_furnace", "close_world_lock", "close_sign", "close_menu", "close_panel", "close_popup", "close"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_node_added)
	RenderingServer.frame_pre_draw.connect(_render)
	_scan.call_deferred(get_tree().root)
	set_process(false)

func _node_added(node: Node) -> void:
	if node is Control:
		if node.get_script() != null or not node.scene_file_path.is_empty() or node.get_parent() is CanvasLayer or str(node.name).ends_with("ConfirmPanel") or str(node.name) in ["EmotesPanel", "DoorEditorPanel", "PasswordDoorPanel", "WithdrawPopup", "VendingLogOverlay"]:
			_schedule_configuration(node)
		var ancestor := node.get_parent()
		while ancestor is Control:
			if ancestor.get_script() != null or ancestor.get_parent() is CanvasLayer or ancestor.get_parent() is Window:
				_schedule_configuration(ancestor)
				break
			ancestor = ancestor.get_parent()

func _schedule_configuration(node: Control) -> void:
	if pending_configuration.is_empty():
		_flush_configuration.call_deferred()
	pending_configuration[node.get_instance_id()] = weakref(node)

func _flush_configuration() -> void:
	var pending := pending_configuration.values()
	pending_configuration.clear()
	for reference in pending:
		_configure(reference)

func _scan(node: Node) -> void:
	if node is Control:
		_configure(weakref(node))
	for child in node.get_children():
		_scan(child)

func _configure(reference: WeakRef) -> void:
	var root := reference.get_ref() as Control
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	# Explicit metadata is available to new windows without changing this policy.
	if root.has_meta("popup_window_path"):
		register_window(root, root.get_node_or_null(NodePath(root.get_meta("popup_window_path"))) as Control)
		return
	var scene_name := root.scene_file_path.get_file()
	if SCENE_WINDOWS.has(scene_name):
		register_window(root, root.get_node_or_null(SCENE_WINDOWS[scene_name]))
		return
	if NESTED_WINDOWS.has(str(root.name)):
		register_window(root, root.get_node_or_null(NESTED_WINDOWS[str(root.name)]))
		return
	if str(root.name).ends_with("ConfirmPanel") or str(root.name) in ["EmotesPanel", "DoorEditorPanel", "PasswordDoorPanel", "WithdrawPopup", "VendingLogOverlay"]:
		register_window(root, root)
		return
	if _configure_conventional_window(root):
		return
	var script := root.get_script() as Script
	if script == null:
		return
	var script_name := script.resource_path.get_file().get_basename()
	if script_name == "leaderboard_controller":
		var scene = root.get("scene_instance")
		if is_instance_valid(scene):
			register_window(root, scene.get_node_or_null("CenterContainer/LeaderboardWindow"))
		return
	if script_name == "emotes_ui":
		register_window(root, root.get_node_or_null("EmotesPanel"))
		return
	if script_name == "shop_scene_redesign":
		register_window(root, root.get_node("ShopWindow"))
		register_window(root, root.get_node_or_null("CategoryRail"), true)
		register_window(root.get_node("DetailOverlay"), root.get_node("DetailOverlay/DetailCard"))
		register_window(root.get_node("PurchaseRewardOverlay"), root.get_node("PurchaseRewardOverlay/RewardCard"))
		return
	if script_name not in PANEL_SCRIPTS:
		return
	for property in root.get_property_list():
		if property.name in ["panel", "window", "card"]:
			var panel = root.get(property.name)
			if panel is Control:
				register_window(root, panel)
				return
	# Authored scenes can be inspected before their manager's setup() binds fields.
	for path in ["VendingPanel", "TradePanel", "Window", "Panel", "DonationBoxPanel", "CenterContainer/MenuWindow"]:
		var panel := root.get_node_or_null(path) as Control
		if panel != null:
			register_window(root, panel)
			return

func register_window(controller: Control, panel: Control, fade_only: bool = false) -> void:
	if not is_instance_valid(panel):
		return
	var id := panel.get_instance_id()
	if windows.has(id):
		return
	var owner_control := controller if controller == panel or controller.is_ancestor_of(panel) else panel
	var script := controller.get_script() as Script
	var family := script.resource_path.get_file().get_basename() if script != null else controller.scene_file_path.get_file()
	var nested := false
	var ancestor := controller.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.has_meta("window_transition_configured"):
			nested = true
			break
		ancestor = ancestor.get_parent()
	windows[id] = {"panel": weakref(panel), "owner": weakref(owner_control), "controller": weakref(controller), "shown": false,
		"family": family, "exclusive": not nested and not family.is_empty() and family != "landfill_waiting_room_ui",
		"auxiliary": fade_only,
		"fade_only": fade_only or family == "inventory_scene"}
	controller.set_meta("window_transition_configured", true)
	panel.visibility_changed.connect(_visibility_changed.bind(id))
	panel.tree_exiting.connect(_remove.bind(id))
	if panel.is_visible_in_tree():
		_visibility_changed(id)
	# Backdrops fade separately, without scaling the full-screen hit target.
	if not fade_only and owner_control != panel:
		for child in owner_control.get_children():
			if child is ColorRect and child != panel:
				register_window(owner_control, child, true)

func present(panel: Control) -> void:
	# Legacy callers establish visibility/layout; the policy alone owns motion.
	var ancestor: Node = panel
	while ancestor is Control:
		_configure(weakref(ancestor))
		ancestor = ancestor.get_parent()
	for entry in windows.values():
		if entry.controller.get_ref() == panel or entry.panel.get_ref() == panel:
			return
	register_window(panel, panel)

func _claim_window(id: int) -> void:
	var incoming: Dictionary = windows[id]
	if not incoming.exclusive or incoming.auxiliary:
		return
	var controller := incoming.controller.get_ref() as Control
	for other_id in windows.keys():
		if other_id == id:
			continue
		var entry: Dictionary = windows[other_id]
		var other := entry.controller.get_ref() as Control
		var panel := entry.panel.get_ref() as Control
		if not entry.exclusive or entry.auxiliary or not is_instance_valid(other) or not is_instance_valid(panel) or not panel.is_visible_in_tree():
			continue
		if other == controller or other.get_viewport() != controller.get_viewport():
			continue
		if _is_related(incoming, entry):
			continue
		var closed := false
		if other.has_method("set_emotes_panel_open"):
			other.set_emotes_panel_open(false)
			closed = true
		elif other.has_method("close_leaderboard"):
			other.close_leaderboard()
			closed = true
		for method in CLOSE_METHODS:
			if not closed and other.has_method(method):
				other.call(method)
				closed = true
				break
		if not closed and other.has_signal("close_requested"):
			other.emit_signal("close_requested")
		if panel.is_visible_in_tree():
			(entry.owner.get_ref() as Control).hide()

func _is_related(a: Dictionary, b: Dictionary) -> bool:
	if a.family == b.family:
		return false
	var families: Array = [a.family, b.family]
	# The profile intentionally launches its recipe book above itself.
	if "recipe_book_scene" in families and "player_profile_scene" in families:
		return true
	if "inventory_scene" not in families:
		return false
	var selection_methods := {"trade_ui": "is_trade_item_selecting", "vending_ui": "is_vend_item_selecting", "safe_ui": "is_safe_item_selecting", "donation_box_ui": "is_donation_box_item_selecting", "display_ui": "is_display_item_selecting", "oil_refinery_ui": "is_oil_refinery_battery_selecting"}
	for entry in [a, b]:
		if not selection_methods.has(entry.family):
			continue
		var controller: Control = entry.controller.get_ref()
		for property in controller.get_property_list():
			if property.name == "world":
				var world = controller.get("world")
				if is_instance_valid(world):
					var method: String = selection_methods[entry.family]
					if world.has_method(method) and world.call(method):
						return true
	return false

func _input(event: InputEvent) -> void:
	# A press on a moving, barely visible window cannot submit an action.
	# Escape/back still closes immediately, including during the entrance.
	var point := Vector2.INF
	if event is InputEventMouseButton and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	if point == Vector2.INF:
		return
	for id in active.keys():
		var state: Dictionary = active[id]
		var panel: Control = windows[id].panel.get_ref()
		if state.opening and state.alpha < 0.6 and is_instance_valid(panel) and not panel.get_meta("window_allow_immediate_input", false) and panel.get_global_rect().has_point(point):
			panel.get_viewport().set_input_as_handled()
			return

func _configure_conventional_window(root: Control) -> bool:
	# New UI scenes inherit the policy through the standard window structure;
	# the legacy script/scene lists above are adapters, not an opt-in allowlist.
	if root.is_in_group("ui_window"):
		register_window(root, root)
		return true
	if root.get_script() == null and root.scene_file_path.is_empty() and not root.get_parent() is CanvasLayer:
		return false
	for path in ["Window", "Panel", "CenterContainer/Window", "CenterContainer/Panel"]:
		var panel := root.get_node_or_null(path) as Control
		if panel == null:
			continue
		# A close control distinguishes windows from HUD containers/item cards.
		if panel.find_child("CloseButton", true, false) == null and panel.find_child("CloseTarget", true, false) == null:
			continue
		register_window(root, panel)
		return true
	return false

func dismiss_and_free(panel: Control) -> void:
	# Dynamic dialogs release their logical references immediately; only their
	# hidden render branch survives long enough to play the common exit.
	if not is_instance_valid(panel):
		return
	var id := panel.get_instance_id()
	if not windows.has(id):
		present(panel)
	var revision := int(dismiss_revisions.get(id, 0)) + 1
	dismiss_revisions[id] = revision
	panel.hide()
	# Release the authored name along with the caller's reference. A replacement
	# dialog can use the same path while this hidden instance renders its exit.
	panel.name = "ClosingWindow%d" % id
	var has_exit := active.has(id)
	for window_id in active.keys():
		if windows[window_id].owner.get_ref() == panel or windows[window_id].controller.get_ref() == panel:
			has_exit = true
	if not has_exit:
		dismiss_revisions.erase(id)
		panel.queue_free()
		return
	var reference: WeakRef = weakref(panel)
	get_tree().create_timer(CLOSE_SECONDS + 0.02, true).timeout.connect(func():
		var remaining = reference.get_ref()
		if is_instance_valid(remaining) and not remaining.visible and int(dismiss_revisions.get(id, 0)) == revision:
			remaining.queue_free()
			dismiss_revisions.erase(id)
	)

func _visibility_changed(id: int) -> void:
	if not windows.has(id):
		return
	var panel := windows[id].panel.get_ref() as Control
	var owner_control := windows[id].owner.get_ref() as Control
	if not is_instance_valid(panel) or not is_instance_valid(owner_control):
		return
	var shown := panel.is_visible_in_tree()
	if shown == bool(windows[id].shown):
		return
	windows[id].shown = shown
	if shown:
		dismiss_revisions[id] = int(dismiss_revisions.get(id, 0)) + 1
		for item in [owner_control, windows[id].controller.get_ref()]:
			if is_instance_valid(item) and item.get_instance_id() != id and dismiss_revisions.has(item.get_instance_id()):
				dismiss_revisions[item.get_instance_id()] = int(dismiss_revisions[item.get_instance_id()]) + 1
		_claim_window(id)
	# A scene/ancestor disappearing should not leave a window floating over the next scene.
	var ancestor := owner_control.get_parent() as CanvasItem
	if ancestor != null and not ancestor.is_visible_in_tree():
		_finish(id)
		return
	var previous: Dictionary = active.get(id, {})
	var fade_only: bool = windows[id].fade_only
	active[id] = {"time": 0.0, "opening": shown,
		"from_scale": previous.get("scale", 1.0 if fade_only or not shown else 0.92),
		"from_alpha": previous.get("alpha", 0.0 if shown else 1.0),
		"from_offset": previous.get("offset", 0.0 if fade_only or not shown else 12.0),
		"scale": previous.get("scale", 1.0 if fade_only or not shown else 0.92),
		"alpha": previous.get("alpha", 0.0 if shown else 1.0),
		"offset": previous.get("offset", 0.0 if fade_only or not shown else 12.0),
		"scale_velocity": previous.get("scale_velocity", 0.0), "alpha_velocity": previous.get("alpha_velocity", 0.0), "offset_velocity": previous.get("offset_velocity", 0.0),
		"from_scale_velocity": previous.get("scale_velocity", 0.0), "from_alpha_velocity": previous.get("alpha_velocity", 0.0), "from_offset_velocity": previous.get("offset_velocity", 0.0)}
	set_process(true)

func _curve(start: float, target: float, velocity: float, duration: float, t: float) -> Vector2:
	# Hermite easing keeps both position and speed continuous on a reversal.
	var distance := target - start
	var tangent := velocity * duration
	var value := start + distance * (3.0 * t * t - 2.0 * t * t * t) + tangent * (t * t * t - 2.0 * t * t + t)
	var speed := (distance * (6.0 * t - 6.0 * t * t) + tangent * (3.0 * t * t - 4.0 * t + 1.0)) / duration
	return Vector2(value, speed)

func _process(delta: float) -> void:
	for id in active.keys():
		var state: Dictionary = active[id]
		var panel: Control = windows[id].panel.get_ref()
		if state.opening and panel.get_meta("window_layout_pending", false):
			continue
		state.time += delta
		var duration: float = OPEN_SECONDS if state.opening else CLOSE_SECONDS
		var t := clampf(state.time / duration, 0.0, 1.0)
		if t >= 1.0:
			_finish(id)
			continue
		var fade_only: bool = windows[id].fade_only
		for channel in ["scale", "alpha", "offset"]:
			var target := 1.0 if channel != "offset" else 0.0
			if not state.opening:
				target = {"scale": 1.0 if fade_only else 0.95, "alpha": 0.0, "offset": 0.0 if fade_only else 8.0}[channel]
			var curve := _curve(state["from_" + channel], target, state["from_" + channel + "_velocity"], duration, t)
			state[channel] = curve.x
			state[channel + "_velocity"] = curve.y

func _render() -> void:
	for id in active.keys():
		var panel := windows[id].panel.get_ref() as Control
		var owner_control := windows[id].owner.get_ref() as Control
		if not is_instance_valid(panel) or not is_instance_valid(owner_control):
			continue
		var state: Dictionary = active[id]
		var factor: float = state.scale
		var local_effect := Transform2D(Vector2(factor, 0), Vector2(0, factor), panel.size * 0.5 * (1.0 - factor) + Vector2(0, state.offset))
		RenderingServer.canvas_item_set_transform(panel.get_canvas_item(), panel.get_transform() * local_effect)
		var tint := panel.modulate
		tint.a *= clampf(state.alpha, 0.0, 1.0)
		RenderingServer.canvas_item_set_modulate(panel.get_canvas_item(), tint)
		if not state.opening:
			var ancestor := owner_control.get_parent() as CanvasItem
			if ancestor != null and not ancestor.is_visible_in_tree():
				_finish(id)
				continue
			# Keep only the render branch alive for the exit. Controls stay hidden to
			# input/game logic, so purchases/cancels cannot be submitted twice.
			var branch: CanvasItem = panel
			while branch != null:
				RenderingServer.canvas_item_set_visible(branch.get_canvas_item(), true)
				if branch == owner_control:
					break
				branch = branch.get_parent() as CanvasItem
			_render_children(panel, true)

func _render_children(node: Node, showing: bool) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			continue
		if child is CanvasItem:
			var child_shown: bool = showing and child.visible
			RenderingServer.canvas_item_set_visible(child.get_canvas_item(), child_shown)
			_render_children(child, child_shown)
		else:
			_render_children(child, showing)

func _finish(id: int) -> void:
	if not windows.has(id):
		return
	var panel := windows[id].panel.get_ref() as Control
	var owner_control := windows[id].owner.get_ref() as Control
	if is_instance_valid(panel):
		RenderingServer.canvas_item_set_transform(panel.get_canvas_item(), panel.get_transform())
		RenderingServer.canvas_item_set_modulate(panel.get_canvas_item(), panel.modulate)
		var branch: CanvasItem = panel
		while branch != null:
			RenderingServer.canvas_item_set_visible(branch.get_canvas_item(), branch.is_visible_in_tree())
			if branch == owner_control:
				break
			branch = branch.get_parent() as CanvasItem
		_render_children(panel, panel.is_visible_in_tree())
	active.erase(id)
	set_process(not active.is_empty())

func _remove(id: int) -> void:
	_finish(id)
	windows.erase(id)
	dismiss_revisions.erase(id)

func _exit_tree() -> void:
	for id in active.keys():
		_finish(id)
