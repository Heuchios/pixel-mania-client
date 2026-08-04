@tool
extends Control

@export_group("Editor Control Mode")
@export var use_root_layout_controls := false:
	set(value):
		use_root_layout_controls = value
		_request_layout_update()

@export_group("Main Panels")
@export var profile_panel_position := Vector2(48, 200):
	set(value):
		profile_panel_position = value
		_request_layout_update()
@export var profile_panel_size := Vector2(500, 340):
	set(value):
		profile_panel_size = value
		_request_layout_update()
@export var worlds_panel_position := Vector2(606, 194):
	set(value):
		worlds_panel_position = value
		_request_layout_update()
@export var worlds_panel_size := Vector2(786, 626):
	set(value):
		worlds_panel_size = value
		_request_layout_update()
@export var join_panel_position := Vector2(1286, 860):
	set(value):
		join_panel_position = value
		_request_layout_update()
@export var join_panel_size := Vector2(604, 150):
	set(value):
		join_panel_size = value
		_request_layout_update()

@export_group("Top Buttons")
@export var top_buttons_position := Vector2(768, 24):
	set(value):
		top_buttons_position = value
		_request_layout_update()
@export var top_button_size := Vector2(86, 86):
	set(value):
		top_button_size = value
		_request_layout_update()
@export var top_button_gap := 12.0:
	set(value):
		top_button_gap = value
		_request_layout_update()

@export_group("Right Buttons")
@export var right_buttons_position := Vector2(1766, 152):
	set(value):
		right_buttons_position = value
		_request_layout_update()
@export var right_button_size := Vector2(124, 104):
	set(value):
		right_button_size = value
		_request_layout_update()
@export var right_button_gap := 22.0:
	set(value):
		right_button_gap = value
		_request_layout_update()

@export_group("World Rows")
@export var start_row_position := Vector2(20, 108):
	set(value):
		start_row_position = value
		_request_layout_update()
@export var start_row_size := Vector2(744, 72):
	set(value):
		start_row_size = value
		_request_layout_update()
@export var world_rows_position := Vector2(20, 190):
	set(value):
		world_rows_position = value
		_request_layout_update()
@export var world_row_size := Vector2(744, 62):
	set(value):
		world_row_size = value
		_request_layout_update()
@export var world_row_gap := 16.0:
	set(value):
		world_row_gap = value
		_request_layout_update()

@export_group("Join Panel Controls")
@export var active_worlds_tab_position := Vector2(12, 12):
	set(value):
		active_worlds_tab_position = value
		_request_layout_update()
@export var active_worlds_tab_size := Vector2(478, 36):
	set(value):
		active_worlds_tab_size = value
		_request_layout_update()
@export var world_input_position := Vector2(18, 80):
	set(value):
		world_input_position = value
		_request_layout_update()
@export var world_input_size := Vector2(316, 42):
	set(value):
		world_input_size = value
		_request_layout_update()
@export var join_button_position := Vector2(389, 12):
	set(value):
		join_button_position = value
		_request_layout_update()
@export var join_button_size := Vector2(192, 128):
	set(value):
		join_button_size = value
		_request_layout_update()

var _layout_update_queued := false


func _ready() -> void:
	if use_root_layout_controls:
		_apply_layout()


func _request_layout_update() -> void:
	if not use_root_layout_controls:
		return
	if not is_inside_tree():
		return
	if _layout_update_queued:
		return

	_layout_update_queued = true
	call_deferred("_apply_layout")


func _apply_layout() -> void:
	_layout_update_queued = false

	_set_rect("ProfilePanel", profile_panel_position, profile_panel_size)
	_set_rect("WorldsPanel", worlds_panel_position, worlds_panel_size)
	_set_rect("JoinPanel", join_panel_position, join_panel_size)

	_set_rect("WorldsPanel/WorldStart", start_row_position, start_row_size)
	_set_rect("WorldsPanel/WorldRows", world_rows_position, _get_world_rows_size())
	_layout_world_rows()

	_layout_button_strip(
		"TopButtons",
		["ProfileButton", "SettingsButton", "AvatarButton", "MenuButton", "FriendsButton"],
		top_buttons_position,
		top_button_size,
		top_button_gap
	)
	_layout_button_strip(
		"RightButtons",
		["CrownButton", "StarButton", "LockButton", "OrbitButton"],
		right_buttons_position,
		right_button_size,
		right_button_gap,
		true
	)

	_set_rect("JoinPanel/ActiveWorldsTab", active_worlds_tab_position, active_worlds_tab_size)
	_set_rect("JoinPanel/WorldInput", world_input_position, world_input_size)
	_set_rect("JoinPanel/JoinButton", join_button_position, join_button_size)


func _layout_world_rows() -> void:
	var row_names := ["WorldTest", "WorldFarm", "WorldBuild"]
	for i in range(row_names.size()):
		var top := float(i) * (world_row_size.y + world_row_gap)
		_set_rect("WorldsPanel/WorldRows/" + row_names[i], Vector2(0, top), world_row_size)


func _layout_button_strip(parent_path: String, child_names: Array[String], parent_position: Vector2, button_size: Vector2, gap: float, vertical := false) -> void:
	var parent := get_node_or_null(parent_path) as Control
	if parent == null:
		return

	var count := child_names.size()
	var parent_size := Vector2.ZERO
	if vertical:
		parent_size = Vector2(button_size.x, float(count) * button_size.y + float(maxi(0, count - 1)) * gap)
	else:
		parent_size = Vector2(float(count) * button_size.x + float(maxi(0, count - 1)) * gap, button_size.y)
	_set_control_rect(parent, parent_position, parent_size)

	for i in range(count):
		var child := parent.get_node_or_null(child_names[i]) as Control
		if child == null:
			continue

		var offset := Vector2(0, float(i) * (button_size.y + gap)) if vertical else Vector2(float(i) * (button_size.x + gap), 0)
		_set_control_rect(child, offset, button_size)


func _set_rect(path: String, position_value: Vector2, size_value: Vector2) -> void:
	var control := get_node_or_null(path) as Control
	if control == null:
		return

	_set_control_rect(control, position_value, size_value)


func _set_control_rect(control: Control, position_value: Vector2, size_value: Vector2) -> void:
	control.position = position_value
	control.size = size_value


func _get_world_rows_size() -> Vector2:
	var row_count := 3.0
	return Vector2(world_row_size.x, row_count * world_row_size.y + 2.0 * world_row_gap)
