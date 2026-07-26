extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const BackgroundManager = preload("res://Scripts/background_manager.gd")
const BlockManager = preload("res://Scripts/block_manager.gd")
const ItemAtlasDB = preload("res://Scripts/ItemAtlasDB.gd")


class MockWorld:
	extends Node
	var item_database: Dictionary = {}


func _ready() -> void:
	var entries := ItemAtlasDB.get_item_database_entries()
	var mock_world := MockWorld.new()
	mock_world.item_database = entries
	var block_manager := BlockManager.new()
	block_manager.world = mock_world
	var machine_cases := [
		{
			"item_key": "night_theme_machine",
			"display_name": "Night Theme Machine",
			"item_id": 37,
			"theme": "night",
			"cells": [Vector2i(17, 7), Vector2i(18, 7)]
		},
		{
			"item_key": "snow_theme_machine",
			"display_name": "Snow Theme Machine",
			"item_id": 38,
			"theme": "snow",
			"cells": [Vector2i(17, 8), Vector2i(18, 8)]
		},
		{
			"item_key": "city_theme_machine",
			"display_name": "City Theme Machine",
			"item_id": 36,
			"theme": "city",
			"cells": [Vector2i(17, 9), Vector2i(18, 9)]
		}
	]
	for machine_case in machine_cases:
		_verify_machine_definition(entries, block_manager, machine_case)
	_verify_tilemap_rendering(block_manager, machine_cases)
	block_manager.free()
	mock_world.free()

	var city_config: Dictionary = BackgroundManager.THEME_CONFIGS.get("city", {})
	var city_paths: Array = city_config.get("paths", [])
	var city_speeds: Array = city_config.get("speeds", [])
	_expect(city_paths.size() == 5, "City theme must contain five parallax layers.")
	_expect(city_speeds == [0.0, 0.05, 0.12, 0.22, 0.34], "City theme parallax speeds must remain far-to-near.")
	for path_value in city_paths:
		_expect(ResourceLoader.exists(str(path_value)), "Missing city parallax layer: " + str(path_value))

	print("[theme-machine-atlas] success")
	get_tree().quit(0)


func _verify_machine_definition(entries: Dictionary, block_manager: Node, machine_case: Dictionary) -> void:
	var item_key := str(machine_case.get("item_key", ""))
	var display_name := str(machine_case.get("display_name", item_key))
	var expected_item_id := int(machine_case.get("item_id", 0))
	var expected_theme := str(machine_case.get("theme", ""))
	var expected_cells: Array = machine_case.get("cells", [])
	var expected_base_cell: Vector2i = expected_cells[0]

	var item_id := ItemAtlasDB.get_item_id_for_key(item_key)
	_expect(item_id == expected_item_id, "%s must use atlas item id %d." % [display_name, expected_item_id])
	var atlas_item := ItemAtlasDB.get_item(item_id)
	_expect(_as_cell(atlas_item.get("atlas_coords", [])) == expected_base_cell, "%s base atlas cell is incorrect." % display_name)

	_expect(entries.has(item_key), "%s must merge into the client item database." % display_name)
	var definition: Dictionary = entries.get(item_key, {})
	_expect(bool(definition.get("theme_machine_block", false)), "%s must remain a theme machine." % display_name)
	_expect(str(definition.get("theme_machine_theme", "")) == expected_theme, "%s must select the %s theme." % [display_name, expected_theme])
	_expect(is_equal_approx(float(definition.get("theme_machine_frame_seconds", 0.0)), 0.45), "%s must retain the 0.45 second animation timing." % display_name)
	_expect(bool(definition.get("break_return_to_inventory", false)), "%s must return to inventory when broken." % display_name)
	_expect(int(definition.get("atlas_source_id", definition.get("source_id", -1))) == 0, "%s must use atlas source 0." % display_name)
	_expect(int(definition.get("alternative_tile", -1)) == 0, "%s must use alternative tile 0." % display_name)
	_expect(_as_cell(definition.get("atlas_coords", [])) == expected_base_cell, "%s merged atlas coordinates are incorrect." % display_name)
	_expect(_descriptor_cell(definition.get("texture", {})) == expected_base_cell, "%s placed texture descriptor is incorrect." % display_name)
	_expect(_descriptor_cell(definition.get("inventory_icon", {})) == expected_base_cell, "%s inventory icon descriptor is incorrect." % display_name)

	var frame_specs = definition.get("theme_machine_enabled_frames", [])
	_expect(frame_specs is Array and frame_specs.size() == 2, "%s must have two enabled frames." % display_name)
	_expect(_descriptor_cell(frame_specs[0]) == expected_cells[0], "%s first enabled frame cell is incorrect." % display_name)
	_expect(_descriptor_cell(frame_specs[1]) == expected_cells[1], "%s second enabled frame cell is incorrect." % display_name)
	var frame_textures := AtlasTextureFactory.load_texture_list(frame_specs)
	_expect(frame_textures.size() == 2, "Both %s atlas frames must load." % display_name)
	for frame_index in range(frame_textures.size()):
		var frame_texture: Texture2D = frame_textures[frame_index]
		_expect(frame_texture is AtlasTexture, "%s frame %d must be an AtlasTexture." % [display_name, frame_index + 1])
		var expected_cell: Vector2i = expected_cells[frame_index]
		var expected_region := Rect2(expected_cell * 32, Vector2i(32, 32))
		_expect((frame_texture as AtlasTexture).region == expected_region, "%s frame %d must crop atlas cell %s." % [display_name, frame_index + 1, expected_cell])

	var metadata: Dictionary = block_manager.get_block_tilemap_metadata(item_key, item_key)
	_expect(bool(metadata.get("has_atlas_coords", false)), "%s must expose TileMap atlas metadata." % display_name)
	_expect(int(metadata.get("source_id", -1)) == 0, "%s TileMap source must be 0." % display_name)
	_expect(_as_cell(metadata.get("atlas_coords", Vector2i(-1, -1))) == expected_base_cell, "%s TileMap base cell is incorrect." % display_name)
	_expect(str(metadata.get("collision_type", "")) == "none", "%s must remain non-collidable." % display_name)

	var resolved_frames: Array[Texture2D] = block_manager.get_theme_machine_enabled_frames(item_key)
	_expect(resolved_frames.size() == 2, "%s runtime must resolve both atlas frame descriptors." % display_name)


func _verify_tilemap_rendering(block_manager: Node, machine_cases: Array) -> void:
	var main_scene := load("res://Scenes/main.tscn") as PackedScene
	_expect(main_scene != null, "Main scene must load for the TileMap render contract.")
	if main_scene == null:
		return
	var main_instance := main_scene.instantiate()
	var world_node := main_instance.get_node_or_null("World")
	_expect(world_node != null, "Main scene must contain World.")
	if world_node == null:
		main_instance.free()
		return
	var renderer = world_node.get_node_or_null("WorldTileMapRenderer")
	var foreground_layer := world_node.get_node_or_null("ForegroundTileMapLayer") as TileMapLayer
	_expect(renderer != null and foreground_layer != null, "Main scene must contain its foreground TileMap renderer and layer.")
	if renderer == null or foreground_layer == null:
		main_instance.free()
		return

	renderer.setup(world_node)
	renderer.chunk_streaming_enabled = false
	var test_grid_pos := Vector2i(101, 101)
	for machine_case in machine_cases:
		var item_key := str(machine_case.get("item_key", ""))
		var display_name := str(machine_case.get("display_name", item_key))
		var expected_cells: Array = machine_case.get("cells", [])
		var resolved_frames: Array[Texture2D] = block_manager.get_theme_machine_enabled_frames(item_key)
		for frame_index in range(resolved_frames.size()):
			renderer.erase_block_cell(test_grid_pos)
			_expect(renderer.set_block_cell(test_grid_pos, resolved_frames[frame_index]), "%s frame %d must render through WorldTileMapRenderer." % [display_name, frame_index + 1])
			_expect(foreground_layer.get_cell_source_id(test_grid_pos) == 0, "%s frame %d must render from TileMap source 0." % [display_name, frame_index + 1])
			_expect(foreground_layer.get_cell_atlas_coords(test_grid_pos) == expected_cells[frame_index], "%s frame %d rendered the wrong TileMap atlas cell." % [display_name, frame_index + 1])
	renderer.erase_block_cell(test_grid_pos)
	main_instance.free()


func _descriptor_cell(value: Variant) -> Vector2i:
	if not (value is Dictionary):
		return Vector2i(-1, -1)
	return _as_cell((value as Dictionary).get("cell", []))


func _as_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
