extends Node2D

var world = null

const SHADOW_SKIP_TYPES = [
	"water",
	"lava",
	"glass",
	"glass_panel",
	"wood_platform",
	"wooden_entrance",
	"sign",
	"entrance_gate"
]

const SHADOW_OFFSET = Vector2(5.0, 4.0)
const SHADOW_COLOR = Color(0.0, 0.01, 0.015, 1.0)
const CAST_SHADOW_ALPHA = 0.24


func setup(world_ref):
	world = world_ref
	name = "BlockShadowManager"
	z_index = -1
	z_as_relative = false
	set_process(true)
	queue_redraw()


func _process(_delta):
	if world != null and bool(world.in_world):
		queue_redraw()


func _draw():
	if world == null or not bool(world.in_world):
		return

	if not "blocks" in world:
		return

	var bounds = get_visible_grid_bounds()
	var pulse = get_shadow_pulse()

	for grid_pos in world.blocks.keys():
		if not is_grid_in_bounds(grid_pos, bounds):
			continue

		var block_data = world.blocks[grid_pos]
		var block_type = str(block_data.get("type", ""))

		if not should_cast_shadow(block_type):
			continue

		draw_block_shadow(grid_pos, block_type, pulse)


func get_shadow_pulse() -> float:
	return 1.0


func get_visible_grid_bounds() -> Dictionary:
	var block_size = float(world.BLOCK_SIZE)
	var min_x = 0
	var min_y = 0
	var max_x = int(world.WORLD_WIDTH) - 1
	var max_y = int(world.WORLD_HEIGHT) - 1

	var viewport_size = get_viewport_rect().size
	var camera = null

	if world.has_method("get_player_camera"):
		camera = world.get_player_camera()

	if viewport_size != Vector2.ZERO and camera != null:
		var zoom = camera.zoom
		var half_view = Vector2(
			viewport_size.x * 0.5 / max(0.001, zoom.x),
			viewport_size.y * 0.5 / max(0.001, zoom.y)
		)
		var center = camera.global_position
		var pad = block_size * 4.0

		min_x = clamp(int(floor((center.x - half_view.x - pad) / block_size)), 0, int(world.WORLD_WIDTH) - 1)
		min_y = clamp(int(floor((center.y - half_view.y - pad) / block_size)), 0, int(world.WORLD_HEIGHT) - 1)
		max_x = clamp(int(ceil((center.x + half_view.x + pad) / block_size)), 0, int(world.WORLD_WIDTH) - 1)
		max_y = clamp(int(ceil((center.y + half_view.y + pad) / block_size)), 0, int(world.WORLD_HEIGHT) - 1)

	return {
		"min_x": min_x,
		"min_y": min_y,
		"max_x": max_x,
		"max_y": max_y
	}


func is_grid_in_bounds(grid_pos: Vector2i, bounds: Dictionary) -> bool:
	return (
		grid_pos.x >= int(bounds["min_x"])
		and grid_pos.x <= int(bounds["max_x"])
		and grid_pos.y >= int(bounds["min_y"])
		and grid_pos.y <= int(bounds["max_y"])
	)


func should_cast_shadow(block_type: String) -> bool:
	if block_type == "" or SHADOW_SKIP_TYPES.has(block_type):
		return false

	if world.block_manager != null and world.block_manager.has_method("is_background_block_type"):
		if world.block_manager.is_background_block_type(block_type):
			return false

	if world.item_database.has(block_type):
		var item_data = world.item_database[block_type]
		if str(item_data.get("category", "")) != "block":
			return false
		if bool(item_data.get("hidden", false)):
			return false

	return true


func has_foreground_block(grid_pos: Vector2i) -> bool:
	return world.blocks.has(grid_pos)


func draw_block_shadow(grid_pos: Vector2i, block_type: String, pulse: float):
	var block_size = get_block_shadow_size(block_type)
	var center = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE) + get_block_shadow_visual_offset(block_type)
	var shadow_offset = SHADOW_OFFSET * pulse
	var texture = get_block_texture(block_type)

	if texture != null:
		draw_block_texture_cast_shadow(center, block_size, shadow_offset, texture, pulse)
	else:
		draw_block_rect_cast_shadow(center, block_size, shadow_offset, pulse)


func get_block_texture(block_type: String):
	if world.block_textures.has(block_type):
		return world.block_textures[block_type]

	return null


func parse_block_vector2(raw_value, fallback := Vector2.ZERO) -> Vector2:
	if raw_value is Vector2:
		return raw_value
	if raw_value is Vector2i:
		return Vector2(float(raw_value.x), float(raw_value.y))
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	if raw_value is Dictionary:
		return Vector2(float(raw_value.get("x", fallback.x)), float(raw_value.get("y", fallback.y)))

	return fallback


func get_block_shadow_size(block_type: String) -> Vector2:
	var default_block_size := 32.0
	if world != null:
		default_block_size = float(world.BLOCK_SIZE)

	var default_size = Vector2(default_block_size, default_block_size)

	if world == null or not world.item_database.has(block_type):
		return default_size

	var item_data = world.item_database[block_type]
	return parse_block_vector2(item_data.get("shadow_size", item_data.get("visual_size", default_size)), default_size)


func get_block_shadow_visual_offset(block_type: String) -> Vector2:
	if world == null or not world.item_database.has(block_type):
		return Vector2.ZERO

	var item_data = world.item_database[block_type]
	return parse_block_vector2(item_data.get("shadow_visual_offset", item_data.get("visual_offset", Vector2.ZERO)), Vector2.ZERO)


func draw_block_texture_cast_shadow(center: Vector2, block_size: Vector2, shadow_offset: Vector2, texture, pulse: float):
	var shadow_color = with_shadow_alpha(CAST_SHADOW_ALPHA * pulse)
	var top_left = center - block_size * 0.5
	draw_texture_rect_region(
		texture,
		Rect2(top_left + shadow_offset.round(), block_size),
		Rect2(0.0, 0.0, float(texture.get_width()), float(texture.get_height())),
		shadow_color
	)


func draw_block_rect_cast_shadow(center: Vector2, block_size: Vector2, shadow_offset: Vector2, pulse: float):
	var shadow_color = with_shadow_alpha(CAST_SHADOW_ALPHA * pulse)
	var top_left = center - block_size * 0.5
	draw_rect(Rect2(top_left + shadow_offset.round(), block_size), shadow_color, true)


func with_shadow_alpha(alpha: float) -> Color:
	return Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, clamp(alpha, 0.0, 1.0))
