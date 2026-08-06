extends Node2D

const SHADOW_OFFSET := Vector2(1.5, 1.5)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.38)
const SHADOW_Z_INDEX := -90

var source_visual = null
var shadow_visual = null
var source_instance_id := 0

# Flat source->shadow node pairs, captured once per rebuild.
#
# update_shadow() runs every frame from _process, and the tree it mirrors is the whole player
# visual: hand item, arms, sleeves and every wearable slot. Re-walking it recursively each
# frame paid get_child_count()/get_child() and call overhead at every level for a structure
# that only changes when equipment changes -- and equipment changes already force a rebuild.
# Caching the pairs turns the per-frame cost into one linear pass.
#
# shadow_pair_child_counts stores each source node's child count at capture time, so a
# structural change (a node added or removed without a rebuild) is still detected cheaply and
# falls back to the same full rebuild the recursive version used.
var shadow_pair_sources: Array = []
var shadow_pair_shadows: Array = []
var shadow_pair_child_counts := PackedInt32Array()


func setup(source_node) -> void:
	if source_node == null or not (source_node is Node2D):
		source_visual = null
		source_instance_id = 0
		_clear_shadow_pairs()
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

	# Fast path: walk the cached pairs. Falls back to a rebuild on any structural change,
	# exactly as the recursive sync did when child counts stopped matching. Control flow is
	# deliberately identical to the original -- at most one rebuild per frame, and the shadow
	# stays visible even if the retry does not settle, rather than flickering out.
	if not sync_cached_shadow_pairs():
		rebuild_shadow_visual()
		if shadow_visual != null:
			sync_cached_shadow_pairs()

	apply_shadow_style()
	visible = true


func rebuild_shadow_visual() -> void:
	if shadow_visual != null and is_instance_valid(shadow_visual):
		remove_child(shadow_visual)
		shadow_visual.queue_free()

	shadow_visual = null
	_clear_shadow_pairs()
	if source_visual == null or not is_instance_valid(source_visual):
		return

	var clone = source_visual.duplicate(0)
	if clone == null or not (clone is Node2D):
		return

	shadow_visual = clone
	shadow_visual.name = "ShadowVisual"
	add_child(shadow_visual)
	prepare_shadow_tree(shadow_visual)
	capture_shadow_pairs(source_visual, shadow_visual)
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
		if shadow_visual.modulate != SHADOW_COLOR:
			shadow_visual.modulate = SHADOW_COLOR
		if shadow_visual.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			shadow_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _clear_shadow_pairs() -> void:
	shadow_pair_sources.clear()
	shadow_pair_shadows.clear()
	shadow_pair_child_counts.clear()


## Records every source->shadow node pair once, at rebuild time. All or nothing: if any level
## fails to mirror, the whole cache is dropped so the next sync returns false and rebuilds --
## a partially captured tree would leave that subtree permanently stale instead.
func capture_shadow_pairs(source_node, shadow_node) -> void:
	if not append_shadow_pairs(source_node, shadow_node):
		_clear_shadow_pairs()


func append_shadow_pairs(source_node, shadow_node) -> bool:
	if source_node == null or shadow_node == null:
		return false
	if not is_instance_valid(source_node) or not is_instance_valid(shadow_node):
		return false

	# Explicit type: source_node is an untyped parameter, so get_child_count() is Variant to
	# the parser and := cannot infer int from it.
	var source_child_count: int = source_node.get_child_count()
	if source_child_count != shadow_node.get_child_count():
		return false

	shadow_pair_sources.append(source_node)
	shadow_pair_shadows.append(shadow_node)
	shadow_pair_child_counts.append(source_child_count)

	for child_index in range(source_child_count):
		if not append_shadow_pairs(source_node.get_child(child_index), shadow_node.get_child(child_index)):
			return false

	return true


## Per-frame sync over the cached pairs. Returns false if the cache is stale, in which case the
## caller rebuilds.
func sync_cached_shadow_pairs() -> bool:
	var pair_count: int = shadow_pair_sources.size()
	if pair_count == 0:
		return false

	for pair_index in range(pair_count):
		var source_node = shadow_pair_sources[pair_index]
		var shadow_node = shadow_pair_shadows[pair_index]
		if source_node == null or shadow_node == null:
			return false
		if not is_instance_valid(source_node) or not is_instance_valid(shadow_node):
			return false
		if source_node.get_child_count() != shadow_pair_child_counts[pair_index]:
			return false

		sync_common_canvas_properties(source_node, shadow_node)
		sync_sprite_properties(source_node, shadow_node)
		sync_animated_sprite_properties(source_node, shadow_node)

	return true


## Kept for the original recursive contract. Nothing on the per-frame path uses it any more --
## sync_cached_shadow_pairs() does that work -- but it stays as the structural-walk equivalent.
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


# Every assignment below is guarded by an inequality test on purpose. Writing a sprite
# property is not free even when the value is unchanged: setting texture, region_rect,
# sprite_frames or animation re-runs internal setup and calls queue_redraw(). Doing that ~11
# times per node, 60 times a second, was the bulk of this file's cost. Comparing first is
# cheap; assigning is not.
func sync_common_canvas_properties(source_node, shadow_node) -> void:
	if source_node is Node2D and shadow_node is Node2D:
		if shadow_node.position != source_node.position:
			shadow_node.position = source_node.position
		if shadow_node.rotation != source_node.rotation:
			shadow_node.rotation = source_node.rotation
		if shadow_node.scale != source_node.scale:
			shadow_node.scale = source_node.scale
		if shadow_node.skew != source_node.skew:
			shadow_node.skew = source_node.skew

	if source_node is CanvasItem and shadow_node is CanvasItem:
		if shadow_node.visible != source_node.visible:
			shadow_node.visible = source_node.visible
		if shadow_node == shadow_visual:
			if shadow_node.z_index != 0:
				shadow_node.z_index = 0
			if not shadow_node.z_as_relative:
				shadow_node.z_as_relative = true
		else:
			if shadow_node.z_index != source_node.z_index:
				shadow_node.z_index = source_node.z_index
			if shadow_node.z_as_relative != source_node.z_as_relative:
				shadow_node.z_as_relative = source_node.z_as_relative


func sync_sprite_properties(source_node, shadow_node) -> void:
	if not (source_node is Sprite2D and shadow_node is Sprite2D):
		return

	if shadow_node.texture != source_node.texture:
		shadow_node.texture = source_node.texture
	if shadow_node.centered != source_node.centered:
		shadow_node.centered = source_node.centered
	if shadow_node.offset != source_node.offset:
		shadow_node.offset = source_node.offset
	if shadow_node.flip_h != source_node.flip_h:
		shadow_node.flip_h = source_node.flip_h
	if shadow_node.flip_v != source_node.flip_v:
		shadow_node.flip_v = source_node.flip_v
	if shadow_node.hframes != source_node.hframes:
		shadow_node.hframes = source_node.hframes
	if shadow_node.vframes != source_node.vframes:
		shadow_node.vframes = source_node.vframes
	if shadow_node.frame != source_node.frame:
		shadow_node.frame = source_node.frame
	if shadow_node.region_enabled != source_node.region_enabled:
		shadow_node.region_enabled = source_node.region_enabled
	if shadow_node.region_rect != source_node.region_rect:
		shadow_node.region_rect = source_node.region_rect
	if shadow_node.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		shadow_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sync_animated_sprite_properties(source_node, shadow_node) -> void:
	if not (source_node is AnimatedSprite2D and shadow_node is AnimatedSprite2D):
		return

	# sprite_frames and animation are the two most expensive writes in this file -- both reset
	# playback state internally -- and neither changes except on an equipment or animation swap.
	if shadow_node.sprite_frames != source_node.sprite_frames:
		shadow_node.sprite_frames = source_node.sprite_frames
	if shadow_node.animation != source_node.animation:
		shadow_node.animation = source_node.animation
	if shadow_node.frame != source_node.frame:
		shadow_node.frame = source_node.frame
	if shadow_node.frame_progress != source_node.frame_progress:
		shadow_node.frame_progress = source_node.frame_progress
	if shadow_node.speed_scale != source_node.speed_scale:
		shadow_node.speed_scale = source_node.speed_scale
	if shadow_node.centered != source_node.centered:
		shadow_node.centered = source_node.centered
	if shadow_node.offset != source_node.offset:
		shadow_node.offset = source_node.offset
	if shadow_node.flip_h != source_node.flip_h:
		shadow_node.flip_h = source_node.flip_h
	if shadow_node.flip_v != source_node.flip_v:
		shadow_node.flip_v = source_node.flip_v
	if shadow_node.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		shadow_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
