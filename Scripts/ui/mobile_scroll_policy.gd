extends Node
## Let Godot's native touch scrolling receive drags that start on list cards.
## The ScrollContainer remains the input boundary and owns inertia/cancellation.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):
		return
	get_tree().node_added.connect(_on_node_added)
	call_deferred("configure_tree", get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_configure_by_id", node.get_instance_id())

func _configure_by_id(id: int) -> void:
	var node := instance_from_id(id) as Control
	if is_instance_valid(node) and node.is_inside_tree():
		configure_control(node)

func configure_tree(node: Node) -> void:
	if node is Control:
		configure_control(node)
	for child in node.get_children():
		configure_tree(child)

func configure_control(control: Control) -> void:
	if control is ScrollContainer or control.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	var ancestor: Node = control
	while ancestor != null:
		# Sliders/text editors own their gestures; inventory has its own slot
		# scrolling and long-press handling. Do not add a second drag handler.
		if ancestor is Range or ancestor is LineEdit or ancestor is TextEdit:
			return
		if ancestor is ScrollContainer:
			if not ancestor.get_meta("custom_touch_scroll", false):
				control.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		ancestor = ancestor.get_parent()
