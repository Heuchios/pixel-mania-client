extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")

var world = null
var refresh_queued: bool = false
var preview_texture_metrics: Dictionary = {}
var preview_nodes: Dictionary = {}

const LEGACY_VEND_PREVIEW_LAYER_NAME := "VendingPreviewLayer"
const EXACT_VEND_PREVIEW_LAYER_NAME := "VendingExactPreviewLayer"
const VEND_PREVIEW_MAX_SIZE := Vector2i(10, 10)
const VEND_PREVIEW_CENTER := Vector2(-1.0, -3.0)
const VEND_PREVIEW_Z_INDEX := 6
const VEND_PREVIEW_ALPHA_THRESHOLD := 0.05
const SEED_VEND_PREVIEW_NODE_NAME := "SeedVendPreview"
const SOLD_OUT_VEND_PREVIEW_TEXTURE = {"atlas": "res://image.png", "cell": [6, 1], "cell_size": [32, 32]}


func setup(world_ref):
	world = world_ref
	clear_legacy_preview_layer()
	clear_tilemap_preview_layer()
	clear_exact_preview_layer()


func is_vending_machine_block_type(block_type: String) -> bool:
	return block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold"


func get_vend_state_dictionary(raw_state) -> Dictionary:
	if not (raw_state is Dictionary):
		return {}

	var vend_state: Dictionary = raw_state
	if vend_state.has("state") and vend_state.get("state") is Dictionary:
		vend_state = vend_state.get("state")
	return vend_state


func get_listing_from_state(raw_state) -> Dictionary:
	var vend_state := get_vend_state_dictionary(raw_state)
	if vend_state.is_empty():
		return {}
	var listing = vend_state.get("listing", {})
	if listing is Dictionary:
		return listing

	return {}


func get_preview_listing_from_state(raw_state) -> Dictionary:
	var listing := get_listing_from_state(raw_state)
	if listing.is_empty():
		return {}
	if listing.has("stock") and int(listing.get("stock", 0)) <= 0:
		return {}
	return listing


func is_sold_out_vending_state(raw_state) -> bool:
	var vend_state := get_vend_state_dictionary(raw_state)
	if vend_state.is_empty():
		return false

	var listing := get_listing_from_state(vend_state)
	if not listing.is_empty():
		return listing.has("stock") and int(listing.get("stock", 0)) <= 0

	return int(vend_state.get("pending_wls", 0)) > 0 or str(vend_state.get("status", "")).strip_edges().to_lower() == "sold"


func get_sold_out_vending_preview_texture() -> Texture2D:
	return AtlasTextureFactory.load_texture(SOLD_OUT_VEND_PREVIEW_TEXTURE)


func update_vending_machine_preview(grid_pos: Vector2i):
	if world == null:
		return

	clear_legacy_block_child_preview(grid_pos)

	if not world.blocks.has(grid_pos):
		remove_vending_machine_preview(grid_pos)
		return

	var block_data = world.blocks[grid_pos]
	var block_type = str(block_data.get("type", ""))

	if not is_vending_machine_block_type(block_type):
		remove_vending_machine_preview(grid_pos)
		return

	var raw_vend_state: Variant = world.vending_states.get(grid_pos, {})
	var item_texture: Texture2D = null
	var item_id := ""
	var item_category := ""

	if is_sold_out_vending_state(raw_vend_state):
		item_texture = get_sold_out_vending_preview_texture()
	else:
		var listing: Dictionary = get_preview_listing_from_state(raw_vend_state)
		if listing.is_empty():
			remove_vending_machine_preview(grid_pos)
			return

		item_id = str(listing.get("item_id", ""))
		item_category = str(listing.get("item_category", ""))
		if item_id == "":
			remove_vending_machine_preview(grid_pos)
			return
		item_texture = get_vending_item_texture(item_id, item_category)

	if item_texture == null:
		remove_vending_machine_preview(grid_pos)
		return

	var preview_sprite := get_or_create_exact_preview_sprite(grid_pos)
	if preview_sprite == null:
		remove_vending_machine_preview(grid_pos)
		return

	apply_exact_preview_sprite(preview_sprite, grid_pos, item_texture)
	remove_seed_vending_preview_overlay(preview_sprite)
	preview_nodes[grid_pos] = preview_sprite


func remove_vending_machine_preview(grid_pos: Vector2i) -> void:
	clear_legacy_block_child_preview(grid_pos)
	var renderer = get_tilemap_renderer()
	if renderer != null and renderer.has_method("erase_vending_preview_cell"):
		renderer.erase_vending_preview_cell(grid_pos)
	var preview_sprite = preview_nodes.get(grid_pos, null)
	if preview_sprite != null and is_instance_valid(preview_sprite):
		preview_sprite.queue_free()
	preview_nodes.erase(grid_pos)


func clear_vending_machine_previews() -> void:
	for grid_pos in preview_nodes.keys():
		if grid_pos is Vector2i:
			remove_vending_machine_preview(grid_pos)
	preview_nodes.clear()
	clear_legacy_preview_layer()
	clear_tilemap_preview_layer()
	clear_exact_preview_layer()


func clear_legacy_block_child_preview(grid_pos: Vector2i) -> void:
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return

	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var existing_preview = block_node.get_node_or_null("VendPreviewRoot")
	if existing_preview != null:
		existing_preview.queue_free()


func clear_legacy_preview_layer() -> void:
	if world == null:
		return

	var legacy_layer: Node = world.get_node_or_null(LEGACY_VEND_PREVIEW_LAYER_NAME)
	if legacy_layer != null:
		legacy_layer.queue_free()


func clear_tilemap_preview_layer() -> void:
	var renderer = get_tilemap_renderer()
	if renderer != null and renderer.has_method("clear_vending_preview_cells"):
		renderer.clear_vending_preview_cells()
		return
	if renderer != null and renderer.has_method("erase_vending_preview_cell"):
		for grid_pos in preview_nodes.keys():
			if grid_pos is Vector2i:
				renderer.erase_vending_preview_cell(grid_pos)


func clear_exact_preview_layer() -> void:
	if world == null:
		return

	var layer = world.get_node_or_null(EXACT_VEND_PREVIEW_LAYER_NAME)
	if layer == null:
		return

	for child in layer.get_children():
		child.queue_free()
	preview_nodes.clear()


func get_or_create_exact_preview_sprite(grid_pos: Vector2i) -> Sprite2D:
	var existing = preview_nodes.get(grid_pos, null)
	if existing is Sprite2D and is_instance_valid(existing):
		return existing

	var layer := get_exact_preview_layer()
	if layer == null:
		return null

	var preview_sprite := Sprite2D.new()
	preview_sprite.name = "VendExactPreview_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	preview_sprite.centered = true
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_sprite.z_as_relative = false
	preview_sprite.z_index = VEND_PREVIEW_Z_INDEX
	layer.add_child(preview_sprite)
	preview_nodes[grid_pos] = preview_sprite
	return preview_sprite


func get_exact_preview_layer() -> Node2D:
	if world == null:
		return null

	var layer = world.get_node_or_null(EXACT_VEND_PREVIEW_LAYER_NAME)
	if layer == null:
		layer = Node2D.new()
		layer.name = EXACT_VEND_PREVIEW_LAYER_NAME
		world.add_child(layer)

	if not (layer is Node2D):
		push_warning("VendingPreviewManager: " + EXACT_VEND_PREVIEW_LAYER_NAME + " exists but is not a Node2D.")
		return null

	layer.z_as_relative = false
	layer.z_index = VEND_PREVIEW_Z_INDEX
	return layer


func apply_exact_preview_sprite(preview_sprite: Sprite2D, grid_pos: Vector2i, item_texture: Texture2D) -> void:
	var block_size := get_block_size()
	var visible_metrics := get_texture_visible_metrics(item_texture)
	var visible_size: Vector2 = visible_metrics.get("size", item_texture.get_size())

	preview_sprite.texture = item_texture
	preview_sprite.offset = visible_metrics.get("offset", Vector2.ZERO)
	preview_sprite.scale = Vector2.ONE * get_preview_scale(visible_size)
	preview_sprite.position = Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size) + VEND_PREVIEW_CENTER
	preview_sprite.visible = true
	preview_sprite.modulate = Color.WHITE


func update_seed_vending_preview_overlay(preview_sprite: Sprite2D, item_id: String, item_category: String) -> void:
	if preview_sprite == null:
		return

	var item_data := get_item_data(item_id)
	var resolved_category := item_category
	if resolved_category == "" and not item_data.is_empty():
		resolved_category = str(item_data.get("category", ""))

	if not is_seed_item(item_id, resolved_category):
		remove_seed_vending_preview_overlay(preview_sprite)
		return

	if world == null or not world.has_method("get_seed_icon_preview_layout"):
		remove_seed_vending_preview_overlay(preview_sprite)
		return

	var layout: Dictionary = world.get_seed_icon_preview_layout(item_id)
	if layout.is_empty():
		remove_seed_vending_preview_overlay(preview_sprite)
		return

	var preview_texture = layout.get("preview_texture", null)
	var box_size: Vector2i = layout.get("box_size", Vector2i.ZERO)
	var preview_size: Vector2i = layout.get("preview_size", Vector2i.ZERO)
	var destination: Vector2i = layout.get("destination", Vector2i.ZERO)
	if preview_texture == null or box_size.x <= 0 or box_size.y <= 0 or preview_size.x <= 0 or preview_size.y <= 0:
		remove_seed_vending_preview_overlay(preview_sprite)
		return

	var overlay = preview_sprite.get_node_or_null(SEED_VEND_PREVIEW_NODE_NAME)
	if overlay == null or not (overlay is Sprite2D):
		if overlay != null:
			preview_sprite.remove_child(overlay)
			overlay.queue_free()
		overlay = Sprite2D.new()
		overlay.name = SEED_VEND_PREVIEW_NODE_NAME
		overlay.centered = true
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		overlay.z_index = 1
		preview_sprite.add_child(overlay)

	var overlay_sprite := overlay as Sprite2D
	overlay_sprite.texture = preview_texture
	overlay_sprite.position = preview_sprite.offset + Vector2(destination) - (Vector2(box_size) * 0.5) + (Vector2(preview_size) * 0.5)
	overlay_sprite.scale = Vector2(
		float(preview_size.x) / max(1.0, float(preview_texture.get_width())),
		float(preview_size.y) / max(1.0, float(preview_texture.get_height()))
	)
	overlay_sprite.visible = true


func remove_seed_vending_preview_overlay(preview_sprite: Sprite2D) -> void:
	if preview_sprite == null:
		return

	var existing = preview_sprite.get_node_or_null(SEED_VEND_PREVIEW_NODE_NAME)
	if existing != null:
		preview_sprite.remove_child(existing)
		existing.queue_free()


func is_seed_item(item_id: String, item_category: String) -> bool:
	return item_category == "seed" or item_id.ends_with("_seed")


func get_block_size() -> float:
	if world == null:
		return 32.0

	var world_block_size = world.get("BLOCK_SIZE")
	if world_block_size is int or world_block_size is float:
		return float(max(1, int(world_block_size)))

	return 32.0


func get_vending_item_texture(item_id: String, item_category: String) -> Texture2D:
	if world == null or item_id == "":
		return null

	var item_data := get_item_data(item_id)
	var resolved_category := item_category
	if resolved_category == "" and not item_data.is_empty():
		resolved_category = str(item_data.get("category", ""))

	if world.has_method("get_inventory_icon_texture"):
		var inventory_icon = world.get_inventory_icon_texture(item_id, resolved_category)
		if inventory_icon != null:
			return inventory_icon

	var texture := get_atlas_item_icon_texture(item_id, item_data, resolved_category)
	if texture != null:
		return texture

	texture = load_item_data_texture(item_data, "inventory_icon")
	if texture != null:
		return texture

	texture = load_item_data_texture(item_data, "texture")
	if texture != null:
		return texture

	texture = get_category_texture(item_id, resolved_category)
	if texture != null:
		return texture

	texture = load_first_item_animation_frame(item_data)
	if texture != null:
		return texture

	if world.has_method("get_item_texture"):
		return world.get_item_texture(item_id, resolved_category)

	return null


func get_item_data(item_id: String) -> Dictionary:
	if world == null:
		return {}

	var item_database = world.get("item_database")
	if item_database is Dictionary and item_database.has(item_id):
		var item_data = item_database.get(item_id, {})
		if item_data is Dictionary:
			return item_data

	return {}


func load_item_data_texture(item_data: Dictionary, texture_key: String) -> Texture2D:
	if item_data.is_empty() or not item_data.has(texture_key):
		return null

	return AtlasTextureFactory.load_texture(item_data.get(texture_key))


func get_atlas_item_icon_texture(item_id: String, item_data: Dictionary, item_category: String) -> Texture2D:
	if item_category != "block" or item_data.is_empty():
		return null

	var atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(item_id)))
	if atlas_item_id <= 0:
		return null

	var atlas_tile_set: TileSet = null
	if world != null and world.has_method("get_item_atlas_tile_set"):
		atlas_tile_set = world.get_item_atlas_tile_set()

	return ITEM_ATLAS_DB.get_item_icon(atlas_item_id, atlas_tile_set)


func load_first_item_animation_frame(item_data: Dictionary) -> Texture2D:
	if item_data.is_empty():
		return null

	var frames = item_data.get("animation_frames", [])
	if not (frames is Array) or frames.is_empty():
		return null

	return AtlasTextureFactory.load_texture(frames[0])


func get_category_texture(item_id: String, item_category: String) -> Texture2D:
	if world == null:
		return null

	var map_name := get_category_texture_map_name(item_category)
	if map_name == "":
		return null

	var texture_map = world.get(map_name)
	if not (texture_map is Dictionary) or not texture_map.has(item_id):
		return null

	var texture = texture_map.get(item_id, null)
	if texture is Texture2D:
		return texture

	return null


func get_category_texture_map_name(item_category: String) -> String:
	match item_category:
		"block":
			return "block_textures"
		"seed":
			return "seed_textures"
		"tool":
			return "tool_textures"
		"material":
			return "material_textures"
		"lure":
			return "lure_textures"
		"fish":
			return "fish_textures"
		"currency":
			return "currency_textures"
		"back":
			return "back_textures"
		"hat":
			return "hat_textures"
		"hair":
			return "hair_textures"
		"eyewear":
			return "eyewear_textures"
		"shirt":
			return "shirt_textures"
		"pants":
			return "pants_textures"
		"shoes":
			return "shoes_textures"
		"ride":
			return "ride_textures"
		_:
			return ""


func get_texture_visible_metrics(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {"offset": Vector2.ZERO, "size": Vector2.ZERO, "rect": Rect2i()}

	var cache_key := get_texture_cache_key(texture)
	if preview_texture_metrics.has(cache_key):
		return preview_texture_metrics[cache_key]

	var texture_size: Vector2 = texture.get_size()
	var scan_info := get_texture_scan_info(texture)
	var scan_origin: Vector2i = scan_info.get("origin", Vector2i.ZERO)
	var scan_size: Vector2i = scan_info.get("size", Vector2i(max(1, int(texture_size.x)), max(1, int(texture_size.y))))
	var fallback_rect := Rect2i(scan_origin, scan_size)
	var fallback_metrics: Dictionary = {
		"offset": Vector2.ZERO,
		"size": texture_size,
		"rect": fallback_rect
	}

	var image = scan_info.get("image", null)
	if image == null or image.is_empty():
		preview_texture_metrics[cache_key] = fallback_metrics
		return fallback_metrics

	var image_width: int = image.get_width()
	var image_height: int = image.get_height()
	var start_x := clampi(scan_origin.x, 0, image_width)
	var start_y := clampi(scan_origin.y, 0, image_height)
	var end_x := clampi(scan_origin.x + scan_size.x, 0, image_width)
	var end_y := clampi(scan_origin.y + scan_size.y, 0, image_height)
	if end_x <= start_x or end_y <= start_y:
		preview_texture_metrics[cache_key] = fallback_metrics
		return fallback_metrics

	var min_x: int = image_width
	var min_y: int = image_height
	var max_x: int = -1
	var max_y: int = -1

	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
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

	var visible_center: Vector2 = Vector2(float(min_x - scan_origin.x + max_x - scan_origin.x + 1) * 0.5, float(min_y - scan_origin.y + max_y - scan_origin.y + 1) * 0.5)
	var texture_center: Vector2 = Vector2(float(scan_size.x), float(scan_size.y)) * 0.5
	var visible_size: Vector2 = Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	var visible_rect := Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))
	var metrics: Dictionary = {
		"offset": texture_center - visible_center,
		"size": visible_size,
		"rect": visible_rect
	}
	preview_texture_metrics[cache_key] = metrics
	return metrics


func get_texture_cache_key(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var cache_key := str(texture.get_instance_id()) + "|" + str(texture.get_width()) + "x" + str(texture.get_height())
	if texture.resource_path != "":
		cache_key += "|" + texture.resource_path
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		cache_key += "|region:" + str(atlas_texture.region)
		cache_key += "|margin:" + str(atlas_texture.margin)
		cache_key += "|filter:" + str(atlas_texture.filter_clip)
		if atlas_texture.atlas != null and atlas_texture.atlas.resource_path != "":
			cache_key += "|atlas:" + atlas_texture.atlas.resource_path
	return cache_key


func get_texture_scan_info(texture: Texture2D) -> Dictionary:
	var texture_width: int = max(1, int(texture.get_width()))
	var texture_height: int = max(1, int(texture.get_height()))
	var image = null
	var scan_origin := Vector2i.ZERO
	var scan_size := Vector2i(texture_width, texture_height)

	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas != null:
			image = atlas_texture.atlas.get_image()
			var region := atlas_texture.region
			if region.size.x > 0.0 and region.size.y > 0.0:
				scan_origin = Vector2i(int(floor(region.position.x)), int(floor(region.position.y)))
				scan_size = Vector2i(max(1, int(ceil(region.size.x))), max(1, int(ceil(region.size.y))))
	else:
		image = texture.get_image()

	if image is Image:
		var scan_image := image as Image
		if int(scan_image.get_width()) == texture_width and int(scan_image.get_height()) == texture_height:
			scan_origin = Vector2i.ZERO
			scan_size = Vector2i(texture_width, texture_height)

	return {
		"image": image,
		"origin": scan_origin,
		"size": scan_size
	}


func get_preview_scale(source_size: Vector2) -> float:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return 1.0

	var scale := minf(
		1.0,
		minf(
			float(VEND_PREVIEW_MAX_SIZE.x) / float(source_size.x),
			float(VEND_PREVIEW_MAX_SIZE.y) / float(source_size.y)
		)
	)
	return scale


func get_tilemap_renderer():
	if world == null:
		return null

	var block_manager = world.get("block_manager")
	if block_manager != null and block_manager.has_method("ensure_tilemap_renderer"):
		return block_manager.ensure_tilemap_renderer()

	return world.get_node_or_null("WorldTileMapRenderer")


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

	for grid_pos in preview_nodes.keys():
		if grid_pos is Vector2i:
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
