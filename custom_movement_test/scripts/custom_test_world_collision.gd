extends Node2D
class_name CustomTestWorldCollision

const WORLD_ID := "custom_phase_f_world_collision_v1"
const TILE_SIZE := 32
const WORLD_ORIGIN := Vector2.ZERO
const CHUNK_ORIGIN := Vector2i.ZERO
const SOLID_COLLISION_LAYER := 1

const BLOCK_DEFINITIONS := {
	"air": {
		"display_name": "Air",
		"solid": false,
		"layer": "air",
		"color": Color(0, 0, 0, 0),
	},
	"dirt": {
		"display_name": "Dirt",
		"solid": true,
		"layer": "foreground",
		"color": Color(0.43, 0.27, 0.15, 1.0),
	},
	"grass": {
		"display_name": "Grass",
		"solid": true,
		"layer": "foreground",
		"color": Color(0.18, 0.55, 0.24, 1.0),
	},
	"stone": {
		"display_name": "Stone",
		"solid": true,
		"layer": "foreground",
		"color": Color(0.42, 0.43, 0.46, 1.0),
	},
	"cave_background": {
		"display_name": "Cave Background",
		"solid": false,
		"layer": "background",
		"background_block": true,
		"color": Color(0.16, 0.13, 0.18, 0.72),
	},
	"wood_background": {
		"display_name": "Wood Background",
		"solid": false,
		"layer": "background",
		"background_block": true,
		"color": Color(0.34, 0.20, 0.10, 0.62),
	},
	"flower_decoration": {
		"display_name": "Flower Decoration",
		"solid": false,
		"layer": "decoration",
		"no_collision": true,
		"color": Color(0.96, 0.72, 0.25, 1.0),
	},
}

@export var collision_debug_visible := false

var foreground_tiles: Dictionary = {}
var background_tiles: Dictionary = {}
var decoration_tiles: Dictionary = {}
var solid_tiles: Dictionary = {}
var collision_hash := ""

var collision_root: StaticBody2D = null


func _ready() -> void:
	build_test_world()


func build_test_world() -> void:
	foreground_tiles.clear()
	background_tiles.clear()
	decoration_tiles.clear()
	solid_tiles.clear()
	_clear_collision_root()
	_build_world_data()
	_build_collision_bodies()
	collision_hash = _calculate_collision_hash()
	queue_redraw()


func set_collision_debug_visible(enabled: bool) -> void:
	collision_debug_visible = enabled
	queue_redraw()


func get_world_id() -> String:
	return WORLD_ID


func get_tile_size() -> int:
	return TILE_SIZE


func get_block_count() -> int:
	return foreground_tiles.size() + background_tiles.size() + decoration_tiles.size()


func get_solid_collision_count() -> int:
	return solid_tiles.size()


func get_collision_hash() -> String:
	return collision_hash


func get_world_origin() -> Vector2:
	return WORLD_ORIGIN


func get_chunk_origin() -> Vector2i:
	return CHUNK_ORIGIN


func get_world_debug_summary() -> Dictionary:
	return {
		"world_id": WORLD_ID,
		"tile_size": TILE_SIZE,
		"block_count": get_block_count(),
		"solid_collision_count": get_solid_collision_count(),
		"collision_hash": collision_hash,
		"world_origin": WORLD_ORIGIN,
		"chunk_origin": CHUNK_ORIGIN,
	}


func get_tile_info_at_world(world_position: Vector2) -> Dictionary:
	var grid_pos: Vector2i = world_to_grid(world_position)
	return get_tile_info_at_grid(grid_pos)


func get_tile_info_at_grid(grid_pos: Vector2i) -> Dictionary:
	var block_id := "air"
	var layer := "air"
	if foreground_tiles.has(grid_pos):
		block_id = str(foreground_tiles.get(grid_pos, "air"))
		layer = "foreground"
	elif decoration_tiles.has(grid_pos):
		block_id = str(decoration_tiles.get(grid_pos, "air"))
		layer = "decoration"
	elif background_tiles.has(grid_pos):
		block_id = str(background_tiles.get(grid_pos, "air"))
		layer = "background"

	var definition: Dictionary = BLOCK_DEFINITIONS.get(block_id, BLOCK_DEFINITIONS["air"])
	return {
		"grid_pos": grid_pos,
		"block_id": block_id,
		"block_name": str(definition.get("display_name", block_id)),
		"layer": layer,
		"solid": is_solid_block(block_id, layer),
	}


func world_to_grid(world_position: Vector2) -> Vector2i:
	var half_tile := float(TILE_SIZE) * 0.5
	return Vector2i(
		int(floor((world_position.x - WORLD_ORIGIN.x + half_tile) / float(TILE_SIZE))),
		int(floor((world_position.y - WORLD_ORIGIN.y + half_tile) / float(TILE_SIZE)))
	)


func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return WORLD_ORIGIN + Vector2(float(grid_pos.x * TILE_SIZE), float(grid_pos.y * TILE_SIZE))


func is_solid_block(block_id: String, layer: String = "foreground") -> bool:
	var clean_id := block_id.strip_edges().to_lower()
	var clean_layer := layer.strip_edges().to_lower()
	if clean_id == "" or clean_id == "air":
		return false
	if clean_layer == "background" or clean_layer == "decoration":
		return false
	if not BLOCK_DEFINITIONS.has(clean_id):
		return false

	var definition: Dictionary = BLOCK_DEFINITIONS[clean_id]
	if bool(definition.get("background_block", false)):
		return false
	if bool(definition.get("no_collision", false)):
		return false
	if definition.has("collidable") and not bool(definition.get("collidable", true)):
		return false
	return bool(definition.get("solid", false))


func _draw() -> void:
	_draw_tile_set(background_tiles, false)
	_draw_tile_set(foreground_tiles, false)
	_draw_tile_set(decoration_tiles, true)
	if collision_debug_visible:
		_draw_collision_overlay()


func _draw_tile_set(tile_set: Dictionary, decoration: bool) -> void:
	var positions: Array = tile_set.keys()
	positions.sort()
	for grid_pos in positions:
		var block_id := str(tile_set.get(grid_pos, "air"))
		var definition: Dictionary = BLOCK_DEFINITIONS.get(block_id, BLOCK_DEFINITIONS["air"])
		var color: Color = definition.get("color", Color.MAGENTA)
		var center: Vector2 = grid_to_world_center(grid_pos)
		if decoration:
			var decoration_size := Vector2(float(TILE_SIZE) * 0.42, float(TILE_SIZE) * 0.42)
			var top_left := center - decoration_size * 0.5 + Vector2(0.0, -8.0)
			draw_rect(Rect2(top_left, decoration_size), color, true)
		else:
			var block_size := Vector2(float(TILE_SIZE), float(TILE_SIZE))
			draw_rect(Rect2(center - block_size * 0.5, block_size), color, true)
			draw_rect(Rect2(center - block_size * 0.5, block_size), Color(0.0, 0.0, 0.0, 0.25), false, 1.0)


func _draw_collision_overlay() -> void:
	var positions: Array = solid_tiles.keys()
	positions.sort()
	for grid_pos in positions:
		var center: Vector2 = grid_to_world_center(grid_pos)
		var block_size := Vector2(float(TILE_SIZE), float(TILE_SIZE))
		var rect := Rect2(center - block_size * 0.5, block_size)
		draw_rect(rect, Color(0.15, 0.95, 1.0, 0.20), true)
		draw_rect(rect, Color(0.25, 1.0, 1.0, 0.85), false, 2.0)


func _build_world_data() -> void:
	for x in range(-2, 35):
		_place_foreground(Vector2i(x, 13), "grass")
		_place_foreground(Vector2i(x, 14), "dirt")
		_place_foreground(Vector2i(x, 15), "dirt")
		_place_foreground(Vector2i(x, 16), "stone")

	for x in range(4, 10):
		for y in range(10, 13):
			_place_background(Vector2i(x, y), "cave_background")

	for x in range(12, 17):
		_place_background(Vector2i(x, 8), "wood_background")
		_place_foreground(Vector2i(x, 9), "stone")

	for y in range(8, 13):
		_place_foreground(Vector2i(20, y), "stone")

	_place_decoration(Vector2i(7, 12), "flower_decoration")
	_place_decoration(Vector2i(18, 12), "flower_decoration")


func _place_foreground(grid_pos: Vector2i, block_id: String) -> void:
	foreground_tiles[grid_pos] = block_id
	if is_solid_block(block_id, "foreground"):
		solid_tiles[grid_pos] = block_id


func _place_background(grid_pos: Vector2i, block_id: String) -> void:
	background_tiles[grid_pos] = block_id


func _place_decoration(grid_pos: Vector2i, block_id: String) -> void:
	decoration_tiles[grid_pos] = block_id


func _build_collision_bodies() -> void:
	collision_root = StaticBody2D.new()
	collision_root.name = "SolidCollision"
	collision_root.collision_layer = SOLID_COLLISION_LAYER
	collision_root.collision_mask = 0
	add_child(collision_root)

	var positions: Array = solid_tiles.keys()
	positions.sort()
	for grid_pos in positions:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(float(TILE_SIZE), float(TILE_SIZE))
		var collision_shape := CollisionShape2D.new()
		collision_shape.name = "Collision_%d_%d" % [grid_pos.x, grid_pos.y]
		collision_shape.position = grid_to_world_center(grid_pos)
		collision_shape.shape = shape
		collision_root.add_child(collision_shape)


func _clear_collision_root() -> void:
	var existing := get_node_or_null("SolidCollision")
	if existing != null:
		existing.queue_free()
	collision_root = null


func _calculate_collision_hash() -> String:
	var signatures: Array[String] = []
	for grid_pos in solid_tiles.keys():
		var block_id := str(solid_tiles.get(grid_pos, "air"))
		signatures.append("%d,%d,%s" % [int(grid_pos.x), int(grid_pos.y), block_id])
	signatures.sort()

	var hash_value := 2166136261
	for signature in signatures:
		for byte_value in signature.to_utf8_buffer():
			hash_value = int((hash_value ^ int(byte_value)) * 16777619) & 0xffffffff
	return "%08x" % hash_value
