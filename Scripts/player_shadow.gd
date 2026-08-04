extends Node2D

const SHADOW_OFFSET := Vector2(1.5, 1.5)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.38)
const SHADOW_Z_INDEX := -90

var source_visual = null
var shadow_visual = null
var source_instance_id := 0


func setup(source_node) -> void:
	if source_node == null or not (source_node is Node2D):
		source_visual = null
		source_instance_id = 0
		visible = false
		set_process(false)
		return

	var next_source_instance_id = int(source_node.get_instance_id())
	var should_rebuild = shadow_visual == null or not is_instance_valid(shadow_visual) or source_instance_id != next_source_instance_id

	name = "PlayerShadow"
	source_visual = source_node
	source_instance_id = next_source_instance_id
	position = SHADOW_OFFSET
	z_as_relative = true
	z_index = SHADOW_Z_INDEX
	visible = true
	set_process(true)

	if should_rebuild:
		rebuild_shadow_visual()
	update_shadow()


func _process(_delta: float) -> void:
	update_shadow()


func update_shadow() -> void:
	if source_visual == null or not is_instance_valid(source_visual):
		visible = false
		return

	if shadow_visual == null or not is_instance_valid(shadow_visual):
		rebuild_shadow_visual()

	if shadow_visual == null:
		visible = false
		return

	if not sync_shadow_tree(source_visual, shadow_visual):
		rebuild_shadow_visual()
		if shadow_visual != null:
			sync_shadow_tree(source_visual, shadow_visual)

	apply_shadow_style()
	visible = true


func rebuild_shadow_visual() -> void:
	if shadow_visual != null and is_instance_valid(shadow_visual):
		remove_child(shadow_visual)
		shadow_visual.queue_free()

	shadow_visual = null
	if source_visual == null or not is_instance_valid(source_visual):
		return

	var clone = source_visual.duplicate(0)
	if clone == null or not (clone is Node2D):
		return

	shadow_visual = clone
	shadow_visual.name = "ShadowVisual"
	add_child(shadow_visual)
	prepare_shadow_tree(shadow_visual)
	apply_shadow_style()


func prepare_shadow_tree(node) -> void:
	if node == null:
		return

	if node is AnimatedSprite2D:
		node.stop()

	for child in node.get_children():
		prepare_shadow_tree(child)


func apply_shadow_style() -> void:
	if shadow_visual == null or not is_instance_valid(shadow_visual):
		return

	if shadow_visual is CanvasItem:
		shadow_visual.modulate = SHADOW_COLOR
		shadow_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sync_shadow_tree(source_node, shadow_node) -> bool:
	if source_node == null or shadow_node == null:
		return false
	if not is_instance_valid(source_node) or not is_instance_valid(shadow_node):
		return false

	sync_common_canvas_properties(source_node, shadow_node)
	sync_sprite_properties(source_node, shadow_node)
	sync_animated_sprite_properties(source_node, shadow_node)

	if source_node.get_child_count() != shadow_node.get_child_count():
		return false

	for child_index in range(source_node.get_child_count()):
		var source_child = source_node.get_child(child_index)
		var shadow_child = shadow_node.get_child(child_index)
		if not sync_shadow_tree(source_child, shadow_child):
			return false

	return true


func sync_common_canvas_properties(source_node, shadow_node) -> void:
	if source_node is Node2D and shadow_node is Node2D:
		shadow_node.position = source_node.position
		shadow_node.rotation = source_node.rotation
		shadow_node.scale = source_node.scale
		shadow_node.skew = source_node.skew

	if source_node is CanvasItem and shadow_node is CanvasItem:
		shadow_node.visible = source_node.visible
		if shadow_node == shadow_visual:
			shadow_node.z_index = 0
			shadow_node.z_as_relative = true
		else:
			shadow_node.z_index = source_node.z_index
			shadow_node.z_as_relative = source_node.z_as_relative


func sync_sprite_properties(source_node, shadow_node) -> void:
	if not (source_node is Sprite2D and shadow_node is Sprite2D):
		return

	shadow_node.texture = source_node.texture
	shadow_node.centered = source_node.centered
	shadow_node.offset = source_node.offset
	shadow_node.flip_h = source_node.flip_h
	shadow_node.flip_v = source_node.flip_v
	shadow_node.hframes = source_node.hframes
	shadow_node.vframes = source_node.vframes
	shadow_node.frame = source_node.frame
	shadow_node.region_enabled = source_node.region_enabled
	shadow_node.region_rect = source_node.region_rect
	shadow_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sync_animated_sprite_properties(source_node, shadow_node) -> void:
	if not (source_node is AnimatedSprite2D and shadow_node is AnimatedSprite2D):
		return

	shadow_node.sprite_frames = source_node.sprite_frames
	shadow_node.animation = source_node.animation
	shadow_node.frame = source_node.frame
	shadow_node.frame_progress = source_node.frame_progress
	shadow_node.speed_scale = source_node.speed_scale
	shadow_node.centered = source_node.centered
	shadow_node.offset = source_node.offset
	shadow_node.flip_h = source_node.flip_h
	shadow_node.flip_v = source_node.flip_v
	shadow_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
