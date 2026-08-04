extends Node

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("apply_to_scene_tree")


func apply_to_scene_tree() -> void:
	var root := get_tree().root
	if root == null:
		return

	apply_to_node_tree(root)


func apply_to_node_tree(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return

	# Apply one centralized typography policy after scene-authored overrides load.
	PixelUIStyle.apply_global_typography_to_node(root)
	for child in root.get_children():
		apply_to_node_tree(child)


func apply_to_node_by_id(node_id: int) -> void:
	var node := instance_from_id(node_id) as Node
	if node == null or not is_instance_valid(node):
		return

	PixelUIStyle.apply_global_typography_to_node(node)


func _on_node_added(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	# SceneTree emits node_added for every child, so styling only this node avoids
	# repeatedly walking the same newly-instanced subtree.
	call_deferred("apply_to_node_by_id", node.get_instance_id())
