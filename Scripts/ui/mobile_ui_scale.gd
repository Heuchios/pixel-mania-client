extends Node
## Scales screen-space UI branches, leaving world canvases and camera zoom alone.
signal scale_changed(value: float)

const SAVE_PATH := "user://pixelmania_settings.cfg"
const MIN_SCALE := 0.75
const MAX_SCALE := 1.25
var ui_scale := 1.0
var _roots: Array[Control] = []
var _states: Dictionary = {}

func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	ui_scale = load_scale()
	get_tree().node_added.connect(_node_added)
	set_process(is_mobile())

static func clean_scale(value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return 1.0
	return snappedf(clampf(float(value), MIN_SCALE, MAX_SCALE), 0.05)

static func load_scale(path: String = SAVE_PATH) -> float:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 1.0
	return clean_scale(config.get_value("interface", "mobile_ui_scale", 1.0))

func set_ui_scale(value: float, path: String = SAVE_PATH) -> void:
	ui_scale = clean_scale(value)
	var config := ConfigFile.new()
	var result := config.load(path)
	if result == OK or result == ERR_FILE_NOT_FOUND:
		config.set_value("interface", "mobile_ui_scale", ui_scale)
		if config.save(path) != OK:
			push_warning("Could not save mobile UI scale.")
	else:
		push_warning("Could not read settings; existing settings were preserved.")
	scale_changed.emit(ui_scale)

func _node_added(node: Node) -> void:
	if node is Control and (node.get_parent() is CanvasLayer or node.get_parent() is Window):
		if not _roots.has(node):
			_roots.append(node)

func _process(_delta: float) -> void:
	for index in range(_roots.size() - 1, -1, -1):
		if not is_instance_valid(_roots[index]) or not (_roots[index].get_parent() is CanvasLayer or _roots[index].get_parent() is Window):
			_roots.remove_at(index)
		else:
			apply_branch(_roots[index], get_viewport().get_visible_rect().size)
	for id in _states.keys():
		if not is_instance_id_valid(id):
			_states.erase(id)

func apply_branch(control: Control, screen: Vector2) -> void:
	if control.name == "OverheadLayer" or control.get_meta("ignore_mobile_ui_scale", false):
		return
	# Full-screen layout roots and backdrops retain their screen coverage. Scale
	# their independent UI branches once, so nested text/icons never double-scale.
	var wrapper := (control.anchor_right - control.anchor_left > 0.99 and control.anchor_bottom - control.anchor_top > 0.99) or control.size.x <= 1.0 or control.size.y <= 1.0 or control.size.is_equal_approx(screen)
	if wrapper:
		for child in control.get_children():
			if child is Control:
				apply_branch(child, screen)
		return
	if not control.is_visible_in_tree():
		return
	var id := control.get_instance_id()
	var state: Dictionary = _states.get(id, {})
	var base_scale: Vector2 = state.get("base_scale", control.scale)
	var base_pivot: Vector2 = state.get("base_pivot", control.pivot_offset)
	# Layout scripts may reapply their authored fit scale on resize or animation.
	if not control.scale.is_equal_approx(state.get("applied_scale", control.scale)):
		base_scale = control.scale
	if not control.pivot_offset.is_equal_approx(state.get("applied_pivot", control.pivot_offset)):
		base_pivot = control.pivot_offset
	var factor := ui_scale
	var visual_size := control.size * base_scale
	if visual_size.x > 0.0 and visual_size.y > 0.0:
		factor = minf(factor, maxf(1.0, minf(screen.x / visual_size.x, screen.y / visual_size.y)))
	var final_scale := base_scale * factor
	var pivot := base_pivot
	if not is_equal_approx(factor, 1.0):
		var base_origin := control.position + base_pivot * (Vector2.ONE - base_scale)
		var center := base_origin + visual_size * 0.5
		var pin := Vector2(clampf(center.x / screen.x, 0.0, 1.0), clampf(center.y / screen.y, 0.0, 1.0))
		var desired_origin := base_origin - (visual_size * factor - visual_size) * pin
		desired_origin = desired_origin.clamp(Vector2.ZERO, (screen - visual_size * factor).max(Vector2.ZERO))
		# A pivot translation preserves authored position and anchor offsets.
		if not is_equal_approx(final_scale.x, 1.0):
			pivot.x = (desired_origin.x - control.position.x) / (1.0 - final_scale.x)
		if not is_equal_approx(final_scale.y, 1.0):
			pivot.y = (desired_origin.y - control.position.y) / (1.0 - final_scale.y)
	if not control.scale.is_equal_approx(final_scale):
		control.scale = final_scale
	if not control.pivot_offset.is_equal_approx(pivot):
		control.pivot_offset = pivot
	_states[id] = {"base_scale": base_scale, "base_pivot": base_pivot, "applied_scale": final_scale, "applied_pivot": pivot}
