extends Node

var world = null
var refresh_queued: bool = false
var preview_texture_metrics: Dictionary = {}

const VEND_PREVIEW_CENTER := Vector2(-1, -2)
const VEND_PREVIEW_MAX_DIMENSION := 12.0
const VEND_PREVIEW_ALPHA_THRESHOLD := 0.05


func setup(world_ref):
	world = world_ref


func is_vending_machine_block_type(block_type: String) -> bool:
	return block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold"


func get_listing_from_state(raw_state) -> Dictionary:
	if not (raw_state is Dictionary):
		return {}

	var vend_state: Dictionary = raw_state
	if vend_state.has("state") and vend_state.get("state") is Dictionary:
		vend_state = vend_state.get("state")

	var listing = vend_state.get("listing", {})
	if listing is Dictionary:
		return listing

	return {}


func update_vending_machine_preview(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	var block_type = str(block_data.get("type", ""))
	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var existing_preview = block_node.get_node_or_null("VendPreviewRoot")
	if existing_preview != null:
		existing_preview.queue_free()

	if not is_vending_machine_block_type(block_type):
		return

	var listing = get_listing_from_state(world.vending_states.get(grid_pos, {}))
	if not (listing is Dictionary) or listing.is_empty():
		return

	var item_id = str(listing.get("item_id", ""))
	var item_category = str(listing.get("item_category", ""))
	if item_id == "":
		return

	var item_texture = world.get_item_texture(item_id, item_category)
	if item_texture == null:
		return

	var root = Node2D.new()
	root.name = "VendPreviewRoot"
	root.position = VEND_PREVIEW_CENTER
	root.z_index = 4
	root.z_as_relative = true
	block_node.add_child(root)

	var icon = Sprite2D.new()
	icon.name = "ItemIcon"
	icon.texture = item_texture
	icon.centered = true
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var texture_size: Vector2 = item_texture.get_size()
	var visible_metrics: Dictionary = get_texture_visible_metrics(item_texture)
	var visible_size: Vector2 = visible_metrics.get("size", texture_size)
	icon.offset = visible_metrics.get("offset", Vector2.ZERO)

	var max_dimension: float = max(visible_size.x, visible_size.y)
	if max_dimension > 0.0:
		var icon_scale: float = VEND_PREVIEW_MAX_DIMENSION / max_dimension
		icon.scale = Vector2(icon_scale, icon_scale)
	root.add_child(icon)


func get_texture_visible_metrics(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {"offset": Vector2.ZERO, "size": Vector2.ZERO}

	var cache_key: String = texture.resource_path
	if cache_key == "":
		cache_key = str(texture.get_instance_id())
	if preview_texture_metrics.has(cache_key):
		return preview_texture_metrics[cache_key]

	var texture_size: Vector2 = texture.get_size()
	var fallback_metrics: Dictionary = {
		"offset": Vector2.ZERO,
		"size": texture_size
	}

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		preview_texture_metrics[cache_key] = fallback_metrics
		return fallback_metrics

	var image_width: int = image.get_width()
	var image_height: int = image.get_height()
	var min_x: int = image_width
	var min_y: int = image_height
	var max_x: int = -1
	var max_y: int = -1

	for y: int in range(image_height):
		for x: int in range(image_width):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= VEND_PREVIEW_ALPHA_THRESHOLD:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)

	if max_x < min_x or max_y < min_y:
		preview_texture_metrics[cache_key] = fallback_metrics
		return fallback_metrics

	var visible_center: Vector2 = Vector2(float(min_x + max_x + 1) * 0.5, float(min_y + max_y + 1) * 0.5)
	var texture_center: Vector2 = Vector2(float(image_width), float(image_height)) * 0.5
	var visible_size: Vector2 = Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	var metrics: Dictionary = {
		"offset": texture_center - visible_center,
		"size": visible_size
	}
	preview_texture_metrics[cache_key] = metrics
	return metrics


func refresh_all_vending_machine_previews():
	if world == null:
		return

	var positions := {}

	for grid_pos in world.vending_states.keys():
		if grid_pos is Vector2i:
			positions[grid_pos] = true

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue
		var block_type = str(block_data.get("type", ""))
		if is_vending_machine_block_type(block_type):
			positions[grid_pos] = true

	for grid_pos in positions.keys():
		if grid_pos is Vector2i:
			update_vending_machine_preview(grid_pos)


func queue_refresh_all_vending_machine_previews():
	if refresh_queued:
		return

	refresh_queued = true
	call_deferred("_refresh_all_vending_machine_previews_deferred")


func _refresh_all_vending_machine_previews_deferred():
	refresh_queued = false
	refresh_all_vending_machine_previews()
