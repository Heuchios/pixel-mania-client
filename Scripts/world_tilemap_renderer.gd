extends Node

const FOREGROUND_LAYER_NAME := "ForegroundTileMapLayer"
const FOREGROUND_SHADOW_LAYER_NAME := "ForegroundShadowTileMapLayer"
const FOREGROUND_COLLISION_LAYER_NAME := "ForegroundCollisionTileMapLayer"
const FOREGROUND_FEATURE_LAYER_NAME := "ForegroundFeatureTileMapLayer"
const FOREGROUND_OVER_PLAYER_LAYER_NAME := "ForegroundOverPlayerTileMapLayer"
const VENDING_PREVIEW_LAYER_NAME := "VendingPreviewTileMapLayer"
const WATER_LAYER_NAME := "WaterTileMapLayer"
const BACKGROUND_LAYER_NAME := "BackgroundTileMapLayer"
const BACKGROUND_SHADOW_LAYER_NAME := "BackgroundShadowTileMapLayer"
const FOREGROUND_Z_INDEX := 0
const FOREGROUND_SHADOW_Z_INDEX := -1
const FOREGROUND_FEATURE_Z_INDEX := 25
const FOREGROUND_OVER_PLAYER_Z_INDEX := 4020
const VENDING_PREVIEW_Z_INDEX := 6
const WATER_Z_INDEX := 4050
const BACKGROUND_Z_INDEX := -10
const BACKGROUND_SHADOW_Z_INDEX := -11
const FOREGROUND_SHADOW_OFFSET := Vector2(1.5, 1.5)
const BACKGROUND_SHADOW_OFFSET := Vector2(1.5, 1.5)
const VENDING_PREVIEW_OFFSET := Vector2(-1.0, -2.0)
const FOREGROUND_SHADOW_MODULATE := Color(0.0, 0.0, 0.0, 0.38)
const BACKGROUND_SHADOW_MODULATE := Color(0.0, 0.0, 0.0, 0.38)
const PHYSICS_LAYER_INDEX := 0
const PHYSICS_COLLISION_BITS := 1
const DEFAULT_TILEMAP_LAYER_VISUALS_ENABLED := true
const DEFAULT_CHUNK_STREAMING_ENABLED := true
const DEFAULT_CHUNK_SIZE_CELLS := 16
const DEFAULT_ACTIVE_CHUNK_MARGIN := 0
const DEFAULT_FOCUS_CHUNK_MARGIN := 1
const DEFAULT_DIRTY_CHUNK_REBUILDS_PER_FRAME := 8
const SOURCE_PROFILE_VISUAL := "visual"
const CELL_SOURCE_COORDINATE := "coordinate"
const CELL_SOURCE_NODE_DERIVED := "node_derived"
const CELL_SOURCE_UNKNOWN := "unknown"
const TILEMAP_ENV_DISABLED_VALUES := ["0", "false", "no", "off"]

const LAYER_FOREGROUND := "foreground"
const LAYER_FOREGROUND_SHADOW := "foreground_shadow"
const LAYER_FOREGROUND_COLLISION := "foreground_collision"
const LAYER_FOREGROUND_FEATURE := "foreground_feature"
const LAYER_FOREGROUND_OVER_PLAYER := "foreground_over_player"
const LAYER_VENDING_PREVIEW := "vending_preview"
const LAYER_WATER := "water"
const LAYER_BACKGROUND := "background"
const LAYER_BACKGROUND_SHADOW := "background_shadow"
const LAYER_KEYS := [
	LAYER_BACKGROUND_SHADOW,
	LAYER_BACKGROUND,
	LAYER_FOREGROUND_SHADOW,
	LAYER_FOREGROUND_COLLISION,
	LAYER_FOREGROUND,
	LAYER_FOREGROUND_FEATURE,
	LAYER_FOREGROUND_OVER_PLAYER,
	LAYER_VENDING_PREVIEW,
	LAYER_WATER
]

var world = null
var tile_set: TileSet = null
var collision_tile_set: TileSet = null
var foreground_layer: TileMapLayer = null
var foreground_shadow_layer: TileMapLayer = null
var foreground_collision_layer: TileMapLayer = null
var foreground_feature_layer: TileMapLayer = null
var foreground_over_player_layer: TileMapLayer = null
var vending_preview_layer: TileMapLayer = null
var water_layer: TileMapLayer = null
var background_layer: TileMapLayer = null
var background_shadow_layer: TileMapLayer = null
var texture_source_ids: Dictionary = {}
var configured_visual_tiles: Array[Dictionary] = []
# Index over configured_visual_tiles keyed by "atlas_x,atlas_y,alternative_tile".
# _find_configured_visual_entry_for_atlas_coords used to linear-scan the whole array,
# and it is called several times per tile during a world build. With a ~900 entry
# atlas and 20k tiles that was tens of millions of Vector2i comparisons per join.
var configured_visual_tile_index: Dictionary = {}
var visual_texture_cell_cache: Dictionary = {}
var configured_collision_tiles: Array[Dictionary] = []
var collision_texture_cell_cache: Dictionary = {}
var fallback_collision_cell: Dictionary = {}
var warned_missing_collision_textures: Dictionary = {}
var enabled := true
var chunk_streaming_enabled := DEFAULT_CHUNK_STREAMING_ENABLED
var chunk_size_cells := DEFAULT_CHUNK_SIZE_CELLS
var active_chunk_margin := DEFAULT_ACTIVE_CHUNK_MARGIN
var focus_chunk_margin := DEFAULT_FOCUS_CHUNK_MARGIN
var cached_cells_by_layer: Dictionary = {}
var cached_cell_sources_by_layer: Dictionary = {}
var chunk_cells_by_layer: Dictionary = {}
var applied_cells_by_layer: Dictionary = {}
var applied_cell_sources_by_layer: Dictionary = {}
var applied_chunk_cells_by_layer: Dictionary = {}
var active_chunks: Dictionary = {}
var dirty_chunks: Dictionary = {}
var max_dirty_chunk_rebuilds_per_frame := DEFAULT_DIRTY_CHUNK_REBUILDS_PER_FRAME
var last_stream_rebuild_ms := 0
var last_added_chunks := 0
var last_removed_chunks := 0
var last_dirty_rebuild_ms := 0
var last_dirty_chunks_processed := 0
var last_dirty_cells_rebuilt := 0
var last_reconcile_checked_cells := 0
var last_reconcile_repaired_cells := 0
var last_reconcile_invalid_cells := 0
var temporary_focus_positions: Array[Vector2] = []


func setup(world_ref) -> void:
	world = world_ref
	enabled = _resolve_enabled()
	chunk_streaming_enabled = _resolve_bool_env("PIXELMANIA_TILEMAP_CHUNK_STREAMING", DEFAULT_CHUNK_STREAMING_ENABLED)
	chunk_size_cells = _resolve_int_env("PIXELMANIA_TILEMAP_CHUNK_SIZE", DEFAULT_CHUNK_SIZE_CELLS, 4, 256)
	active_chunk_margin = _resolve_int_env("PIXELMANIA_TILEMAP_CHUNK_MARGIN", DEFAULT_ACTIVE_CHUNK_MARGIN, 0, 16)
	focus_chunk_margin = _resolve_int_env("PIXELMANIA_TILEMAP_FOCUS_CHUNK_MARGIN", DEFAULT_FOCUS_CHUNK_MARGIN, 0, 16)
	max_dirty_chunk_rebuilds_per_frame = _resolve_int_env("PIXELMANIA_TILEMAP_DIRTY_CHUNKS_PER_FRAME", DEFAULT_DIRTY_CHUNK_REBUILDS_PER_FRAME, 1, 64)
	_reset_streaming_state()
	texture_source_ids.clear()

	if not enabled:
		_clear_layers()
		set_physics_process(false)
		return

	collision_tile_set = _get_configured_collision_tile_set()
	if collision_tile_set == null:
		collision_tile_set = TileSet.new()
	collision_tile_set.tile_size = _get_tile_size()
	_ensure_tileset_physics_layer(collision_tile_set)

	tile_set = _get_configured_visual_tile_set()
	if tile_set == null and collision_tile_set != null:
		tile_set = collision_tile_set.duplicate(true) as TileSet
	if tile_set == null:
		tile_set = TileSet.new()
	tile_set.tile_size = _get_tile_size()
	_rebuild_configured_visual_tiles()
	_rebuild_configured_collision_tiles()

	background_shadow_layer = _ensure_layer(BACKGROUND_SHADOW_LAYER_NAME, BACKGROUND_SHADOW_Z_INDEX, BACKGROUND_SHADOW_OFFSET, BACKGROUND_SHADOW_MODULATE)
	background_layer = _ensure_layer(BACKGROUND_LAYER_NAME, BACKGROUND_Z_INDEX)
	foreground_shadow_layer = _ensure_layer(FOREGROUND_SHADOW_LAYER_NAME, FOREGROUND_SHADOW_Z_INDEX, FOREGROUND_SHADOW_OFFSET, FOREGROUND_SHADOW_MODULATE)
	foreground_collision_layer = _ensure_layer(FOREGROUND_COLLISION_LAYER_NAME, FOREGROUND_Z_INDEX, Vector2.ZERO, Color.WHITE, false, true, collision_tile_set)
	foreground_layer = _ensure_layer(FOREGROUND_LAYER_NAME, FOREGROUND_Z_INDEX)
	foreground_feature_layer = _ensure_layer(FOREGROUND_FEATURE_LAYER_NAME, FOREGROUND_FEATURE_Z_INDEX)
	foreground_over_player_layer = _ensure_layer(FOREGROUND_OVER_PLAYER_LAYER_NAME, FOREGROUND_OVER_PLAYER_Z_INDEX)
	vending_preview_layer = _ensure_layer(VENDING_PREVIEW_LAYER_NAME, VENDING_PREVIEW_Z_INDEX, VENDING_PREVIEW_OFFSET)
	water_layer = _ensure_layer(WATER_LAYER_NAME, WATER_Z_INDEX)
	set_physics_process(chunk_streaming_enabled)
	_refresh_active_chunks(true)


func _physics_process(_delta: float) -> void:
	if enabled and chunk_streaming_enabled:
		_refresh_active_chunks(false)
		_process_dirty_chunks(false)


func _resolve_enabled() -> bool:
	return _resolve_bool_env("PIXELMANIA_TILEMAP_LAYER_VISUALS", DEFAULT_TILEMAP_LAYER_VISUALS_ENABLED)


func _resolve_bool_env(env_name: String, default_value: bool) -> bool:
	var env_value := OS.get_environment(env_name).strip_edges().to_lower()
	if env_value == "":
		return default_value
	return not TILEMAP_ENV_DISABLED_VALUES.has(env_value)


func _resolve_int_env(env_name: String, default_value: int, min_value: int, max_value: int) -> int:
	var env_value := OS.get_environment(env_name).strip_edges()
	if env_value == "" or not env_value.is_valid_int():
		return default_value
	return clampi(int(env_value), min_value, max_value)


func _get_tile_size() -> Vector2i:
	var block_size := 32
	if world != null:
		var world_block_size = world.get("BLOCK_SIZE")
		if world_block_size is int or world_block_size is float:
			block_size = max(1, int(world_block_size))
	return Vector2i(block_size, block_size)


func _get_configured_collision_tile_set() -> TileSet:
	if world == null:
		return null
	var configured_layer = world.get_node_or_null(FOREGROUND_COLLISION_LAYER_NAME)
	if configured_layer is TileMapLayer:
		return (configured_layer as TileMapLayer).tile_set
	return null


func _get_configured_visual_tile_set() -> TileSet:
	if world == null:
		return null
	var configured_layer = world.get_node_or_null(FOREGROUND_LAYER_NAME)
	if configured_layer is TileMapLayer:
		return (configured_layer as TileMapLayer).tile_set
	return null


func _ensure_tileset_physics_layer(target_tile_set: TileSet) -> void:
	if target_tile_set == null:
		return
	if target_tile_set.get_physics_layers_count() <= PHYSICS_LAYER_INDEX:
		target_tile_set.add_physics_layer()
	target_tile_set.set_physics_layer_collision_layer(PHYSICS_LAYER_INDEX, PHYSICS_COLLISION_BITS)


func _ensure_layer(layer_name: String, layer_z_index: int, position_offset: Vector2 = Vector2.ZERO, layer_modulate: Color = Color.WHITE, layer_visible := true, layer_collision_enabled := false, layer_tile_set: TileSet = null) -> TileMapLayer:
	if world == null:
		return null

	var layer = world.get_node_or_null(layer_name)
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = layer_name
		world.add_child(layer)

	if not (layer is TileMapLayer):
		push_warning("WorldTileMapRenderer: " + layer_name + " exists but is not a TileMapLayer.")
		return null

	layer.tile_set = layer_tile_set if layer_tile_set != null else tile_set
	var tile_size: Vector2i = _get_tile_size()
	layer.position = Vector2(float(-tile_size.x) * 0.5, float(-tile_size.y) * 0.5) + position_offset
	layer.z_as_relative = false
	layer.z_index = layer_z_index
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.modulate = layer_modulate
	layer.visible = enabled and layer_visible
	layer.collision_enabled = enabled and layer_collision_enabled
	return layer


func set_block_atlas_cell(grid_pos: Vector2i, atlas_coords: Vector2i, background := false, texture_shadow := false, cell_source := CELL_SOURCE_COORDINATE, alternative_tile := 0) -> bool:
	if not enabled:
		return false

	var cell_data := _get_configured_visual_cell_for_atlas_coords(atlas_coords, alternative_tile)
	if cell_data.is_empty():
		return false

	var layer_key := LAYER_BACKGROUND if background else LAYER_FOREGROUND
	var stored := _store_cell(
		layer_key,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)
	if not stored:
		return false

	var shadow_layer_key := LAYER_BACKGROUND_SHADOW if background else LAYER_FOREGROUND_SHADOW
	if texture_shadow:
		_store_cell(
			shadow_layer_key,
			grid_pos,
			_get_cell_source_id(cell_data),
			cell_source,
			_get_cell_atlas_coords(cell_data),
			_get_cell_alternative_tile(cell_data)
		)
	else:
		_remove_cell(shadow_layer_key, grid_pos)
	return true


func set_item_atlas_cell(grid_pos: Vector2i, source_id: int, atlas_coords: Vector2i, background := false, texture_shadow := false, cell_source := CELL_SOURCE_COORDINATE, alternative_tile := 0) -> bool:
	if not enabled:
		return false

	var layer_key := LAYER_BACKGROUND if background else LAYER_FOREGROUND
	var stored := _store_cell(
		layer_key,
		grid_pos,
		int(source_id),
		cell_source,
		atlas_coords,
		int(alternative_tile)
	)
	if not stored:
		return false

	var shadow_layer_key := LAYER_BACKGROUND_SHADOW if background else LAYER_FOREGROUND_SHADOW
	if texture_shadow:
		_store_cell(
			shadow_layer_key,
			grid_pos,
			int(source_id),
			cell_source,
			atlas_coords,
			int(alternative_tile)
		)
	else:
		_remove_cell(shadow_layer_key, grid_pos)
	return true


func set_block_cell(grid_pos: Vector2i, texture: Texture2D, background := false, texture_shadow := false, cell_source := CELL_SOURCE_COORDINATE) -> bool:
	if not enabled or texture == null:
		return false

	var cell_data := _get_visual_cell_for_texture(texture)
	if cell_data.is_empty():
		return false

	var layer_key := LAYER_BACKGROUND if background else LAYER_FOREGROUND
	var stored := _store_cell(
		layer_key,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)
	if not stored:
		return false

	var shadow_layer_key := LAYER_BACKGROUND_SHADOW if background else LAYER_FOREGROUND_SHADOW
	if texture_shadow:
		_store_cell(
			shadow_layer_key,
			grid_pos,
			_get_cell_source_id(cell_data),
			cell_source,
			_get_cell_atlas_coords(cell_data),
			_get_cell_alternative_tile(cell_data)
		)
	else:
		_remove_cell(shadow_layer_key, grid_pos)
	return true


func erase_block_cell(grid_pos: Vector2i, background := false) -> void:
	if background:
		_remove_cell(LAYER_BACKGROUND, grid_pos)
		_remove_cell(LAYER_BACKGROUND_SHADOW, grid_pos)
		return

	_remove_cell(LAYER_FOREGROUND, grid_pos)
	_remove_cell(LAYER_FOREGROUND_SHADOW, grid_pos)
	_remove_cell(LAYER_FOREGROUND_COLLISION, grid_pos)
	_remove_cell(LAYER_FOREGROUND_FEATURE, grid_pos)
	_remove_cell(LAYER_FOREGROUND_OVER_PLAYER, grid_pos)
	_remove_cell(LAYER_WATER, grid_pos)


func set_foreground_feature_cell(grid_pos: Vector2i, texture: Texture2D, cell_source := CELL_SOURCE_COORDINATE) -> bool:
	if not enabled or texture == null or foreground_feature_layer == null:
		return false

	var cell_data := _get_visual_cell_for_texture(texture)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_FOREGROUND_FEATURE,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func set_foreground_feature_atlas_cell(grid_pos: Vector2i, atlas_coords: Vector2i, cell_source := CELL_SOURCE_COORDINATE, alternative_tile := 0) -> bool:
	if not enabled or foreground_feature_layer == null:
		return false

	var cell_data := _get_configured_visual_cell_for_atlas_coords(atlas_coords, alternative_tile)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_FOREGROUND_FEATURE,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func erase_foreground_feature_cell(grid_pos: Vector2i) -> void:
	_remove_cell(LAYER_FOREGROUND_FEATURE, grid_pos)


func set_foreground_over_player_cell(grid_pos: Vector2i, texture: Texture2D, cell_source := CELL_SOURCE_COORDINATE) -> bool:
	if not enabled or texture == null or foreground_over_player_layer == null:
		return false

	var cell_data := _get_visual_cell_for_texture(texture)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_FOREGROUND_OVER_PLAYER,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func set_foreground_over_player_atlas_cell(grid_pos: Vector2i, atlas_coords: Vector2i, cell_source := CELL_SOURCE_COORDINATE, alternative_tile := 0) -> bool:
	if not enabled or foreground_over_player_layer == null:
		return false

	var cell_data := _get_configured_visual_cell_for_atlas_coords(atlas_coords, alternative_tile)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_FOREGROUND_OVER_PLAYER,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func erase_foreground_over_player_cell(grid_pos: Vector2i) -> void:
	_remove_cell(LAYER_FOREGROUND_OVER_PLAYER, grid_pos)


func set_water_cell(grid_pos: Vector2i, texture: Texture2D, cell_source := CELL_SOURCE_COORDINATE) -> bool:
	if not enabled or texture == null or water_layer == null:
		return false

	var cell_data := _get_visual_cell_for_texture(texture)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_WATER,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func set_water_atlas_cell(grid_pos: Vector2i, atlas_coords: Vector2i, cell_source := CELL_SOURCE_COORDINATE, alternative_tile := 0) -> bool:
	if not enabled or water_layer == null:
		return false

	var cell_data := _get_configured_visual_cell_for_atlas_coords(atlas_coords, alternative_tile)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_WATER,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func erase_water_cell(grid_pos: Vector2i) -> void:
	_remove_cell(LAYER_WATER, grid_pos)


func set_foreground_collision_cell(grid_pos: Vector2i, _texture: Texture2D = null, cell_source := CELL_SOURCE_COORDINATE) -> bool:
	if not enabled or foreground_collision_layer == null:
		return false

	var cell_data := _get_static_full_collision_cell()
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_FOREGROUND_COLLISION,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func erase_foreground_collision_cell(grid_pos: Vector2i) -> void:
	_remove_cell(LAYER_FOREGROUND_COLLISION, grid_pos)


func has_foreground_collision_cell(grid_pos: Vector2i) -> bool:
	var cached_cells: Dictionary = cached_cells_by_layer.get(LAYER_FOREGROUND_COLLISION, {})
	return cached_cells.has(grid_pos)


func has_visual_tile_animation(atlas_coords: Vector2i, alternative_tile := 0) -> bool:
	var entry := _find_configured_visual_entry_for_atlas_coords(atlas_coords, alternative_tile)
	if entry.is_empty():
		return false

	var source = entry.get("source", null)
	if not (source is TileSetAtlasSource):
		return false

	var atlas_source := source as TileSetAtlasSource
	if not atlas_source.has_method("get_tile_animation_frames_count"):
		return false

	return int(atlas_source.call("get_tile_animation_frames_count", atlas_coords)) > 1


func get_foreground_collision_cell_info(grid_pos: Vector2i) -> Dictionary:
	var cached_cells: Dictionary = cached_cells_by_layer.get(LAYER_FOREGROUND_COLLISION, {})
	if not cached_cells.has(grid_pos):
		return {"has_collision": false}
	var cell_data: Variant = cached_cells.get(grid_pos, {})
	return {
		"has_collision": true,
		"source_id": _get_cell_source_id(cell_data),
		"atlas_coords": _get_cell_atlas_coords(cell_data),
		"alternative_tile": _get_cell_alternative_tile(cell_data)
	}


func set_vending_preview_cell(grid_pos: Vector2i, texture: Texture2D, cell_source := CELL_SOURCE_COORDINATE) -> bool:
	if not enabled or texture == null or vending_preview_layer == null:
		return false

	var cell_data := _get_visual_cell_for_texture(texture)
	if cell_data.is_empty():
		return false

	return _store_cell(
		LAYER_VENDING_PREVIEW,
		grid_pos,
		_get_cell_source_id(cell_data),
		cell_source,
		_get_cell_atlas_coords(cell_data),
		_get_cell_alternative_tile(cell_data)
	)


func erase_vending_preview_cell(grid_pos: Vector2i) -> void:
	_remove_cell(LAYER_VENDING_PREVIEW, grid_pos)


func clear_vending_preview_cells() -> void:
	_clear_layer_key(LAYER_VENDING_PREVIEW)


func clear() -> void:
	_clear_layers()
	_reset_streaming_state()


func get_streaming_summary() -> Dictionary:
	var cached_cells := 0
	var active_cells := 0
	var cached_by_layer: Dictionary = {}
	var active_by_layer: Dictionary = {}
	for layer_key in LAYER_KEYS:
		var layer_cached: Dictionary = cached_cells_by_layer.get(layer_key, {})
		var layer_active: Dictionary = applied_cells_by_layer.get(layer_key, {})
		cached_by_layer[layer_key] = layer_cached.size()
		active_by_layer[layer_key] = layer_active.size()
		cached_cells += layer_cached.size()
		active_cells += layer_active.size()

	return {
		"enabled": enabled,
		"streaming_enabled": chunk_streaming_enabled,
		"chunk_size_cells": chunk_size_cells,
		"active_chunk_margin": active_chunk_margin,
		"focus_chunk_margin": focus_chunk_margin,
		"active_chunks": active_chunks.size(),
		"cached_cells": cached_cells,
		"active_cells": active_cells,
		"cached_by_layer": cached_by_layer,
		"active_by_layer": active_by_layer,
		"cached_cell_sources": _summarize_cell_sources(cached_cell_sources_by_layer),
		"active_cell_sources": _summarize_cell_sources(applied_cell_sources_by_layer),
		"last_stream_rebuild_ms": last_stream_rebuild_ms,
		"last_added_chunks": last_added_chunks,
		"last_removed_chunks": last_removed_chunks,
		"dirty_chunks_pending": dirty_chunks.size(),
		"dirty_chunks_per_frame": max_dirty_chunk_rebuilds_per_frame,
		"last_dirty_rebuild_ms": last_dirty_rebuild_ms,
		"last_dirty_chunks_processed": last_dirty_chunks_processed,
		"last_dirty_cells_rebuilt": last_dirty_cells_rebuilt,
		"last_reconcile_checked_cells": last_reconcile_checked_cells,
		"last_reconcile_repaired_cells": last_reconcile_repaired_cells,
		"last_reconcile_invalid_cells": last_reconcile_invalid_cells
	}


func refresh_streaming_now() -> void:
	if not enabled:
		return
	if not chunk_streaming_enabled:
		_apply_all_cached_cells()
		reconcile_active_cells()
		return

	_refresh_active_chunks(true)
	_process_dirty_chunks(true)
	reconcile_active_cells()


func reconcile_active_cells() -> Dictionary:
	var checked_cells := 0
	var repaired_cells := 0
	var invalid_cells := 0

	for layer_key in LAYER_KEYS:
		var desired_chunks: Dictionary = chunk_cells_by_layer.get(layer_key, {})
		var cached_sources: Dictionary = cached_cell_sources_by_layer.get(layer_key, {})
		for chunk_pos in active_chunks.keys():
			var desired_chunk_cells: Dictionary = desired_chunks.get(chunk_pos, {})
			for raw_grid_pos in desired_chunk_cells.keys():
				if not (raw_grid_pos is Vector2i):
					continue
				var grid_pos := raw_grid_pos as Vector2i
				var cell_data: Variant = desired_chunk_cells.get(grid_pos, {})
				checked_cells += 1
				if not _is_cell_data_valid_for_layer(layer_key, cell_data):
					invalid_cells += 1
					continue

				var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
				var applied_sources: Dictionary = applied_cell_sources_by_layer.get(layer_key, {})
				var expected_source := _normalize_cell_source(cached_sources.get(grid_pos, CELL_SOURCE_UNKNOWN))
				var bookkeeping_matches := (
					applied_cells.has(grid_pos)
					and _cell_data_matches(applied_cells.get(grid_pos), cell_data)
					and _normalize_cell_source(applied_sources.get(grid_pos, CELL_SOURCE_UNKNOWN)) == expected_source
				)
				if bookkeeping_matches and _physical_cell_matches(layer_key, grid_pos, cell_data):
					continue
				if _apply_cell(layer_key, grid_pos, cell_data):
					repaired_cells += 1

	last_reconcile_checked_cells = checked_cells
	last_reconcile_repaired_cells = repaired_cells
	last_reconcile_invalid_cells = invalid_cells
	return {
		"checked_cells": checked_cells,
		"repaired_cells": repaired_cells,
		"invalid_cells": invalid_cells
	}


func refresh_streaming_for_world_positions(world_positions: Array) -> void:
	if not enabled:
		return
	if not chunk_streaming_enabled:
		_apply_all_cached_cells()
		return

	var previous_focus_positions := temporary_focus_positions.duplicate()
	temporary_focus_positions.clear()
	for raw_position in world_positions:
		if raw_position is Vector2 and is_finite(raw_position.x) and is_finite(raw_position.y):
			temporary_focus_positions.append(raw_position)

	_refresh_active_chunks(true)
	_process_dirty_chunks(true)
	temporary_focus_positions = previous_focus_positions


func is_foreground_collision_stream_ready_for_world_positions(world_positions: Array) -> bool:
	if not enabled or not chunk_streaming_enabled:
		return true

	var desired_collision_chunks: Dictionary = chunk_cells_by_layer.get(LAYER_FOREGROUND_COLLISION, {})
	if desired_collision_chunks.is_empty():
		return true

	var required_chunks := _get_required_chunks_for_world_positions(world_positions)
	if required_chunks.is_empty():
		return false

	var applied_collision_chunks: Dictionary = applied_chunk_cells_by_layer.get(LAYER_FOREGROUND_COLLISION, {})
	for chunk_pos in required_chunks.keys():
		if not desired_collision_chunks.has(chunk_pos):
			continue

		var desired_chunk_cells: Dictionary = desired_collision_chunks.get(chunk_pos, {})
		if desired_chunk_cells.is_empty():
			continue

		if not active_chunks.has(chunk_pos):
			return false

		var applied_chunk_cells: Dictionary = applied_collision_chunks.get(chunk_pos, {})
		if applied_chunk_cells.size() < desired_chunk_cells.size():
			return false

	return true


func _get_required_chunks_for_world_positions(world_positions: Array) -> Dictionary:
	var required_chunks: Dictionary = {}
	var radius: int = int(focus_chunk_margin)
	if radius < 0:
		radius = 0
	elif radius > 1:
		radius = 1

	for raw_position in world_positions:
		if not (raw_position is Vector2):
			continue
		var world_position: Vector2 = raw_position
		if not is_finite(world_position.x) or not is_finite(world_position.y):
			continue

		var focus_chunk := _grid_to_chunk(_world_to_grid(world_position))
		for chunk_x in range(focus_chunk.x - radius, focus_chunk.x + radius + 1):
			for chunk_y in range(focus_chunk.y - radius, focus_chunk.y + radius + 1):
				required_chunks[Vector2i(chunk_x, chunk_y)] = true

	return required_chunks


func _reset_streaming_state() -> void:
	cached_cells_by_layer.clear()
	cached_cell_sources_by_layer.clear()
	chunk_cells_by_layer.clear()
	applied_cells_by_layer.clear()
	applied_cell_sources_by_layer.clear()
	applied_chunk_cells_by_layer.clear()
	for layer_key in LAYER_KEYS:
		cached_cells_by_layer[layer_key] = {}
		cached_cell_sources_by_layer[layer_key] = {}
		chunk_cells_by_layer[layer_key] = {}
		applied_cells_by_layer[layer_key] = {}
		applied_cell_sources_by_layer[layer_key] = {}
		applied_chunk_cells_by_layer[layer_key] = {}
	active_chunks.clear()
	dirty_chunks.clear()
	last_stream_rebuild_ms = 0
	last_added_chunks = 0
	last_removed_chunks = 0
	last_dirty_rebuild_ms = 0
	last_dirty_chunks_processed = 0
	last_dirty_cells_rebuilt = 0
	last_reconcile_checked_cells = 0
	last_reconcile_repaired_cells = 0
	last_reconcile_invalid_cells = 0


func _clear_layers() -> void:
	if foreground_layer != null and is_instance_valid(foreground_layer):
		foreground_layer.clear()
	if foreground_shadow_layer != null and is_instance_valid(foreground_shadow_layer):
		foreground_shadow_layer.clear()
	if foreground_collision_layer != null and is_instance_valid(foreground_collision_layer):
		foreground_collision_layer.clear()
	if foreground_feature_layer != null and is_instance_valid(foreground_feature_layer):
		foreground_feature_layer.clear()
	if foreground_over_player_layer != null and is_instance_valid(foreground_over_player_layer):
		foreground_over_player_layer.clear()
	if vending_preview_layer != null and is_instance_valid(vending_preview_layer):
		vending_preview_layer.clear()
	if water_layer != null and is_instance_valid(water_layer):
		water_layer.clear()
	if background_layer != null and is_instance_valid(background_layer):
		background_layer.clear()
	if background_shadow_layer != null and is_instance_valid(background_shadow_layer):
		background_shadow_layer.clear()


func _make_cell_data(source_id: int, atlas_coords := Vector2i.ZERO, alternative_tile := 0) -> Dictionary:
	return {
		"source_id": source_id,
		"atlas_coords": atlas_coords,
		"alternative_tile": alternative_tile
	}


func _get_cell_source_id(cell_data: Variant) -> int:
	if cell_data is Dictionary:
		return int((cell_data as Dictionary).get("source_id", -1))
	if cell_data is int or cell_data is float:
		return int(cell_data)
	return -1


func _get_cell_atlas_coords(cell_data: Variant) -> Vector2i:
	if cell_data is Dictionary:
		var value: Variant = (cell_data as Dictionary).get("atlas_coords", Vector2i.ZERO)
		if value is Vector2i:
			return value
		if value is Vector2:
			return Vector2i(int(value.x), int(value.y))
	return Vector2i.ZERO


func _get_cell_alternative_tile(cell_data: Variant) -> int:
	if cell_data is Dictionary:
		return int((cell_data as Dictionary).get("alternative_tile", 0))
	return 0


func _cell_data_matches(a: Variant, b: Variant) -> bool:
	return (
		_get_cell_source_id(a) == _get_cell_source_id(b)
		and _get_cell_atlas_coords(a) == _get_cell_atlas_coords(b)
		and _get_cell_alternative_tile(a) == _get_cell_alternative_tile(b)
	)


func _is_bulk_cell_load_active() -> bool:
	if world == null:
		return false
	return bool(world.get_meta("world_bulk_load_in_progress", false))


func _is_cell_data_valid_for_layer(layer_key: String, cell_data: Variant) -> bool:
	var layer := _get_layer_for_key(layer_key)
	if layer == null or layer.tile_set == null:
		return false

	var source_id := _get_cell_source_id(cell_data)
	if source_id < 0 or not layer.tile_set.has_source(source_id):
		return false

	var source = layer.tile_set.get_source(source_id)
	if not (source is TileSetAtlasSource):
		return true

	var atlas_source := source as TileSetAtlasSource
	var atlas_coords := _get_cell_atlas_coords(cell_data)
	if not atlas_source.has_tile(atlas_coords):
		return false

	var alternative_tile := _get_cell_alternative_tile(cell_data)
	if alternative_tile == 0:
		return true
	if atlas_source.has_method("has_alternative_tile"):
		return bool(atlas_source.call("has_alternative_tile", atlas_coords, alternative_tile))
	return _get_collision_alternative_ids(atlas_source, atlas_coords).has(alternative_tile)


func _physical_cell_matches(layer_key: String, grid_pos: Vector2i, cell_data: Variant) -> bool:
	var layer := _get_layer_for_key(layer_key)
	if layer == null:
		return false
	return (
		layer.get_cell_source_id(grid_pos) == _get_cell_source_id(cell_data)
		and layer.get_cell_atlas_coords(grid_pos) == _get_cell_atlas_coords(cell_data)
		and layer.get_cell_alternative_tile(grid_pos) == _get_cell_alternative_tile(cell_data)
	)


func _store_cell(layer_key: String, grid_pos: Vector2i, source_id: int, cell_source := CELL_SOURCE_COORDINATE, atlas_coords := Vector2i.ZERO, alternative_tile := 0) -> bool:
	if chunk_streaming_enabled and active_chunks.is_empty():
		_refresh_active_chunks(true)

	var normalized_cell_source := _normalize_cell_source(cell_source)
	var cached_cells: Dictionary = cached_cells_by_layer.get(layer_key, {})
	var cached_sources: Dictionary = cached_cell_sources_by_layer.get(layer_key, {})
	var had_previous_cell := cached_cells.has(grid_pos)
	var cell_data := _make_cell_data(source_id, atlas_coords, alternative_tile)
	var chunk_pos := _grid_to_chunk(grid_pos)
	if not _is_cell_data_valid_for_layer(layer_key, cell_data):
		return false

	# Placement/variant refresh can touch the same neighbor cells repeatedly. When the
	# requested cell is identical to the cached/applied cell, skip the write only
	# after confirming the actual TileMapLayer still contains that exact cell.
	if had_previous_cell:
		var previous_cell: Variant = cached_cells.get(grid_pos)
		var previous_source := _normalize_cell_source(cached_sources.get(grid_pos, CELL_SOURCE_UNKNOWN))
		if previous_source == normalized_cell_source and _cell_data_matches(previous_cell, cell_data):
			var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
			var applied_sources: Dictionary = applied_cell_sources_by_layer.get(layer_key, {})
			var applied_matches := applied_cells.has(grid_pos) and _cell_data_matches(applied_cells.get(grid_pos), cell_data)
			var applied_source_matches := _normalize_cell_source(applied_sources.get(grid_pos, CELL_SOURCE_UNKNOWN)) == normalized_cell_source
			if chunk_streaming_enabled and not active_chunks.has(chunk_pos):
				return true
			if applied_matches and applied_source_matches and _physical_cell_matches(layer_key, grid_pos, cell_data):
				return true

	cached_cells[grid_pos] = cell_data
	cached_cells_by_layer[layer_key] = cached_cells

	cached_sources[grid_pos] = normalized_cell_source
	cached_cell_sources_by_layer[layer_key] = cached_sources

	var chunks: Dictionary = chunk_cells_by_layer.get(layer_key, {})
	var chunk_cells: Dictionary = chunks.get(chunk_pos, {})
	chunk_cells[grid_pos] = cell_data
	chunks[chunk_pos] = chunk_cells
	chunk_cells_by_layer[layer_key] = chunks

	if not chunk_streaming_enabled:
		return _apply_cell(layer_key, grid_pos, cell_data)
	elif active_chunks.has(chunk_pos):
		# For normal gameplay edits, update the one active cell directly instead of
		# rebuilding the whole chunk. During bulk world-state loads, keep chunk rebuilds
		# batched because hundreds/thousands of cells may be changing together.
		if _is_bulk_cell_load_active():
			_mark_dirty_chunk(chunk_pos)
			return true
		else:
			return _apply_cell(layer_key, grid_pos, cell_data)
	elif had_previous_cell:
		_erase_applied_cell(layer_key, grid_pos)
	return true


func _remove_cell(layer_key: String, grid_pos: Vector2i) -> void:
	var cached_cells: Dictionary = cached_cells_by_layer.get(layer_key, {})
	var had_cached_cell := cached_cells.has(grid_pos)
	if had_cached_cell:
		cached_cells.erase(grid_pos)
		cached_cells_by_layer[layer_key] = cached_cells

	var cached_sources: Dictionary = cached_cell_sources_by_layer.get(layer_key, {})
	if cached_sources.has(grid_pos):
		cached_sources.erase(grid_pos)
		cached_cell_sources_by_layer[layer_key] = cached_sources

	var chunk_pos := _grid_to_chunk(grid_pos)
	var chunks: Dictionary = chunk_cells_by_layer.get(layer_key, {})
	var had_chunk_cell := false
	if chunks.has(chunk_pos):
		var chunk_cells: Dictionary = chunks.get(chunk_pos, {})
		had_chunk_cell = chunk_cells.has(grid_pos)
		if had_chunk_cell:
			chunk_cells.erase(grid_pos)
		if chunk_cells.is_empty():
			chunks.erase(chunk_pos)
		else:
			chunks[chunk_pos] = chunk_cells
		chunk_cells_by_layer[layer_key] = chunks

	var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
	var had_applied_cell := applied_cells.has(grid_pos)
	if not had_cached_cell and not had_chunk_cell and not had_applied_cell:
		# A deferred/streamed TileMap update can leave a physical cell behind after
		# its bookkeeping entry is gone. Always give the layer one final erase.
		_erase_applied_cell(layer_key, grid_pos)
		return

	if chunk_streaming_enabled and active_chunks.has(chunk_pos):
		# Normal gameplay removals only need one active TileMap cell erased. Avoid
		# marking the whole chunk dirty unless we are doing a bulk world-state load.
		if _is_bulk_cell_load_active():
			_mark_dirty_chunk(chunk_pos)
		else:
			_erase_applied_cell(layer_key, grid_pos)
	else:
		_erase_applied_cell(layer_key, grid_pos)


func _clear_layer_key(layer_key: String) -> void:
	var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
	for grid_pos in applied_cells.keys():
		if grid_pos is Vector2i:
			_erase_applied_cell(layer_key, grid_pos)

	cached_cells_by_layer[layer_key] = {}
	cached_cell_sources_by_layer[layer_key] = {}
	chunk_cells_by_layer[layer_key] = {}
	applied_cells_by_layer[layer_key] = {}
	applied_cell_sources_by_layer[layer_key] = {}
	applied_chunk_cells_by_layer[layer_key] = {}
	var layer := _get_layer_for_key(layer_key)
	if layer != null:
		layer.clear()


func _apply_cell(layer_key: String, grid_pos: Vector2i, cell_data: Variant) -> bool:
	var layer := _get_layer_for_key(layer_key)
	if layer == null:
		return false

	var source_id := _get_cell_source_id(cell_data)
	if source_id < 0 or not _is_cell_data_valid_for_layer(layer_key, cell_data):
		_erase_applied_cell(layer_key, grid_pos)
		return false

	layer.set_cell(grid_pos, source_id, _get_cell_atlas_coords(cell_data), _get_cell_alternative_tile(cell_data))
	# Skip the post-write read-back during bulk world load.
	#
	# _physical_cell_matches re-reads the cell with three more TileMapLayer calls
	# (get_cell_source_id / get_cell_atlas_coords / get_cell_alternative_tile) plus another
	# layer lookup, turning one logical write into ~4 TileMap round trips. Fine for a single
	# runtime placement; during a world build it runs for ~7,000+ foreground and ~7,000+
	# background cells.
	#
	# It is also redundant here: _is_cell_data_valid_for_layer() ran a few lines above and
	# already verified against the real TileSet that the source exists, the atlas source has
	# this tile, and the alternative tile is valid -- exactly the conditions under which
	# set_cell would refuse the write. Runtime writes keep the check, where it costs one cell.
	if not _is_bulk_cell_load_active():
		if not _physical_cell_matches(layer_key, grid_pos, cell_data):
			_erase_applied_cell(layer_key, grid_pos)
			return false

	var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
	applied_cells[grid_pos] = cell_data
	applied_cells_by_layer[layer_key] = applied_cells
	_record_applied_cell_source(layer_key, grid_pos)

	var chunk_pos := _grid_to_chunk(grid_pos)
	var applied_chunks: Dictionary = applied_chunk_cells_by_layer.get(layer_key, {})
	var applied_chunk_cells: Dictionary = applied_chunks.get(chunk_pos, {})
	applied_chunk_cells[grid_pos] = cell_data
	applied_chunks[chunk_pos] = applied_chunk_cells
	applied_chunk_cells_by_layer[layer_key] = applied_chunks
	return true


func _erase_applied_cell(layer_key: String, grid_pos: Vector2i) -> void:
	var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
	var layer := _get_layer_for_key(layer_key)
	if layer != null:
		layer.erase_cell(grid_pos)
	if applied_cells.has(grid_pos):
		applied_cells.erase(grid_pos)
		applied_cells_by_layer[layer_key] = applied_cells
	_erase_applied_cell_source(layer_key, grid_pos)

	var chunk_pos := _grid_to_chunk(grid_pos)
	var applied_chunks: Dictionary = applied_chunk_cells_by_layer.get(layer_key, {})
	if applied_chunks.has(chunk_pos):
		var applied_chunk_cells: Dictionary = applied_chunks.get(chunk_pos, {})
		applied_chunk_cells.erase(grid_pos)
		if applied_chunk_cells.is_empty():
			applied_chunks.erase(chunk_pos)
		else:
			applied_chunks[chunk_pos] = applied_chunk_cells
		applied_chunk_cells_by_layer[layer_key] = applied_chunks


func _normalize_cell_source(cell_source: Variant) -> String:
	var cell_source_text := str(cell_source).strip_edges()
	if cell_source_text == CELL_SOURCE_COORDINATE:
		return CELL_SOURCE_COORDINATE
	if cell_source_text == CELL_SOURCE_NODE_DERIVED:
		return CELL_SOURCE_NODE_DERIVED
	return CELL_SOURCE_UNKNOWN


func _get_cached_cell_source(layer_key: String, grid_pos: Vector2i) -> String:
	var cached_sources: Dictionary = cached_cell_sources_by_layer.get(layer_key, {})
	return _normalize_cell_source(cached_sources.get(grid_pos, CELL_SOURCE_UNKNOWN))


func _record_applied_cell_source(layer_key: String, grid_pos: Vector2i) -> void:
	var applied_sources: Dictionary = applied_cell_sources_by_layer.get(layer_key, {})
	applied_sources[grid_pos] = _get_cached_cell_source(layer_key, grid_pos)
	applied_cell_sources_by_layer[layer_key] = applied_sources


func _erase_applied_cell_source(layer_key: String, grid_pos: Vector2i) -> void:
	var applied_sources: Dictionary = applied_cell_sources_by_layer.get(layer_key, {})
	if applied_sources.has(grid_pos):
		applied_sources.erase(grid_pos)
		applied_cell_sources_by_layer[layer_key] = applied_sources


func _new_cell_source_counts() -> Dictionary:
	var counts: Dictionary = {}
	counts[CELL_SOURCE_COORDINATE] = 0
	counts[CELL_SOURCE_NODE_DERIVED] = 0
	counts[CELL_SOURCE_UNKNOWN] = 0
	return counts


func _summarize_cell_sources(cell_sources_by_layer: Dictionary) -> Dictionary:
	var totals := _new_cell_source_counts()
	var by_layer: Dictionary = {}
	for layer_key in LAYER_KEYS:
		var layer_counts := _new_cell_source_counts()
		var layer_sources_value: Variant = cell_sources_by_layer.get(layer_key, {})
		if layer_sources_value is Dictionary:
			var layer_sources: Dictionary = layer_sources_value
			for cell_source in layer_sources.values():
				var normalized_source := _normalize_cell_source(cell_source)
				layer_counts[normalized_source] = int(layer_counts.get(normalized_source, 0)) + 1
				totals[normalized_source] = int(totals.get(normalized_source, 0)) + 1
		by_layer[layer_key] = layer_counts
	totals["by_layer"] = by_layer
	return totals


func _get_layer_for_key(layer_key: String) -> TileMapLayer:
	match layer_key:
		LAYER_FOREGROUND:
			return foreground_layer
		LAYER_FOREGROUND_SHADOW:
			return foreground_shadow_layer
		LAYER_FOREGROUND_COLLISION:
			return foreground_collision_layer
		LAYER_FOREGROUND_FEATURE:
			return foreground_feature_layer
		LAYER_FOREGROUND_OVER_PLAYER:
			return foreground_over_player_layer
		LAYER_VENDING_PREVIEW:
			return vending_preview_layer
		LAYER_WATER:
			return water_layer
		LAYER_BACKGROUND:
			return background_layer
		LAYER_BACKGROUND_SHADOW:
			return background_shadow_layer
	return null


func _refresh_active_chunks(force_refresh: bool) -> void:
	if not enabled:
		return
	if not chunk_streaming_enabled:
		if force_refresh:
			_apply_all_cached_cells()
		return

	var new_active_chunks := _compute_active_chunks()
	if not force_refresh and _chunk_sets_equal(active_chunks, new_active_chunks):
		return

	var started_at := Time.get_ticks_msec()
	var old_active_chunks := active_chunks
	active_chunks = new_active_chunks
	last_added_chunks = 0
	last_removed_chunks = 0

	for chunk_pos in old_active_chunks.keys():
		if active_chunks.has(chunk_pos):
			continue
		last_removed_chunks += 1
		_deactivate_chunk(chunk_pos)

	for chunk_pos in active_chunks.keys():
		if old_active_chunks.has(chunk_pos) and not force_refresh:
			continue
		last_added_chunks += 1
		_activate_chunk(chunk_pos)

	last_stream_rebuild_ms = Time.get_ticks_msec() - started_at


func _apply_all_cached_cells() -> void:
	_clear_layers()
	for layer_key in LAYER_KEYS:
		applied_cells_by_layer[layer_key] = {}
		applied_cell_sources_by_layer[layer_key] = {}
		applied_chunk_cells_by_layer[layer_key] = {}
		var cached_cells: Dictionary = cached_cells_by_layer.get(layer_key, {})
		for grid_pos in cached_cells.keys():
			_apply_cell(layer_key, grid_pos, cached_cells[grid_pos])


func _activate_chunk(chunk_pos: Vector2i) -> void:
	_rebuild_chunk(chunk_pos)
	dirty_chunks.erase(chunk_pos)


func _deactivate_chunk(chunk_pos: Vector2i) -> void:
	dirty_chunks.erase(chunk_pos)
	for layer_key in LAYER_KEYS:
		var applied_chunks: Dictionary = applied_chunk_cells_by_layer.get(layer_key, {})
		if not applied_chunks.has(chunk_pos):
			continue
		var applied_chunk_cells: Dictionary = applied_chunks.get(chunk_pos, {})
		for grid_pos in applied_chunk_cells.keys():
			_erase_applied_cell(layer_key, grid_pos)


func _mark_dirty_chunk(chunk_pos: Vector2i) -> void:
	dirty_chunks[chunk_pos] = true


func _process_dirty_chunks(force_all: bool) -> void:
	if dirty_chunks.is_empty():
		last_dirty_rebuild_ms = 0
		last_dirty_chunks_processed = 0
		last_dirty_cells_rebuilt = 0
		return

	var started_at := Time.get_ticks_msec()
	var processed := 0
	var rebuilt_cells := 0
	var dirty_chunk_keys := dirty_chunks.keys()
	for chunk_pos in dirty_chunk_keys:
		if not (chunk_pos is Vector2i):
			dirty_chunks.erase(chunk_pos)
			continue
		if not active_chunks.has(chunk_pos):
			dirty_chunks.erase(chunk_pos)
			continue

		rebuilt_cells += _rebuild_chunk(chunk_pos)
		dirty_chunks.erase(chunk_pos)
		processed += 1
		if not force_all and processed >= max_dirty_chunk_rebuilds_per_frame:
			break

	last_dirty_rebuild_ms = Time.get_ticks_msec() - started_at
	last_dirty_chunks_processed = processed
	last_dirty_cells_rebuilt = rebuilt_cells


func _rebuild_chunk(chunk_pos: Vector2i) -> int:
	var touched_cells := 0
	for layer_key in LAYER_KEYS:
		var layer := _get_layer_for_key(layer_key)
		if layer == null:
			continue

		var applied_cells: Dictionary = applied_cells_by_layer.get(layer_key, {})
		var applied_sources: Dictionary = applied_cell_sources_by_layer.get(layer_key, {})
		var applied_chunks: Dictionary = applied_chunk_cells_by_layer.get(layer_key, {})
		var old_chunk_cells: Dictionary = applied_chunks.get(chunk_pos, {})
		for grid_pos in old_chunk_cells.keys():
			layer.erase_cell(grid_pos)
			applied_cells.erase(grid_pos)
			applied_sources.erase(grid_pos)
			touched_cells += 1
		applied_chunks.erase(chunk_pos)

		var desired_chunks: Dictionary = chunk_cells_by_layer.get(layer_key, {})
		var desired_chunk_cells: Dictionary = desired_chunks.get(chunk_pos, {})
		if not desired_chunk_cells.is_empty():
			var new_chunk_cells: Dictionary = {}
			for grid_pos in desired_chunk_cells.keys():
				var cell_data: Variant = desired_chunk_cells[grid_pos]
				var source_id := _get_cell_source_id(cell_data)
				if source_id < 0 or not _is_cell_data_valid_for_layer(layer_key, cell_data):
					continue
				layer.set_cell(grid_pos, source_id, _get_cell_atlas_coords(cell_data), _get_cell_alternative_tile(cell_data))
				if not _physical_cell_matches(layer_key, grid_pos, cell_data):
					layer.erase_cell(grid_pos)
					continue
				applied_cells[grid_pos] = cell_data
				applied_sources[grid_pos] = _get_cached_cell_source(layer_key, grid_pos)
				new_chunk_cells[grid_pos] = cell_data
			applied_chunks[chunk_pos] = new_chunk_cells
			touched_cells += desired_chunk_cells.size()

		applied_cells_by_layer[layer_key] = applied_cells
		applied_cell_sources_by_layer[layer_key] = applied_sources
		applied_chunk_cells_by_layer[layer_key] = applied_chunks
	return touched_cells


func _compute_active_chunks() -> Dictionary:
	var result: Dictionary = {}
	var bounds := _get_visible_grid_bounds()
	var min_grid := Vector2i(int(bounds.position.x), int(bounds.position.y))
	var max_grid := Vector2i(int(bounds.end.x) - 1, int(bounds.end.y) - 1)
	max_grid.x = max(max_grid.x, min_grid.x)
	max_grid.y = max(max_grid.y, min_grid.y)
	var min_chunk := _grid_to_chunk(min_grid)
	var max_chunk := _grid_to_chunk(max_grid)
	min_chunk -= Vector2i(active_chunk_margin, active_chunk_margin)
	max_chunk += Vector2i(active_chunk_margin, active_chunk_margin)

	for chunk_x in range(min_chunk.x, max_chunk.x + 1):
		for chunk_y in range(min_chunk.y, max_chunk.y + 1):
			result[Vector2i(chunk_x, chunk_y)] = true

	if world != null:
		var player = world.get("player")
		if player is Node2D and is_instance_valid(player):
			_include_active_chunks_around_world_position(result, (player as Node2D).global_position)

		var main_root: Node = world.get_parent()
		var players_root: Node = main_root.get_node_or_null("Players") if main_root != null else null
		if players_root != null:
			for child in players_root.get_children():
				if child is Node2D and is_instance_valid(child):
					_include_active_chunks_around_world_position(result, (child as Node2D).global_position)

	for focus_position in temporary_focus_positions:
		_include_active_chunks_around_world_position(result, focus_position)

	return result


func _include_active_chunks_around_world_position(result: Dictionary, world_position: Vector2) -> void:
	if not is_finite(world_position.x) or not is_finite(world_position.y):
		return

	var focus_grid := _world_to_grid(world_position)
	var focus_chunk := _grid_to_chunk(focus_grid)
	var radius: int = max(0, int(focus_chunk_margin))
	for chunk_x in range(focus_chunk.x - radius, focus_chunk.x + radius + 1):
		for chunk_y in range(focus_chunk.y - radius, focus_chunk.y + radius + 1):
			result[Vector2i(chunk_x, chunk_y)] = true


func _get_visible_grid_bounds() -> Rect2i:
	var tile_size := _get_tile_size()
	var block_width: float = maxf(1.0, float(tile_size.x))
	var block_height: float = maxf(1.0, float(tile_size.y))
	var world_rect := Rect2(Vector2.ZERO, Vector2(block_width * float(chunk_size_cells), block_height * float(chunk_size_cells)))

	var viewport := get_viewport()
	if viewport != null:
		var visible_rect := viewport.get_visible_rect()
		var inverse_canvas := viewport.get_canvas_transform().affine_inverse()
		var top_left := inverse_canvas * visible_rect.position
		var top_right := inverse_canvas * Vector2(visible_rect.position.x + visible_rect.size.x, visible_rect.position.y)
		var bottom_left := inverse_canvas * Vector2(visible_rect.position.x, visible_rect.position.y + visible_rect.size.y)
		var bottom_right := inverse_canvas * (visible_rect.position + visible_rect.size)
		var min_x := minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x))
		var max_x := maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x))
		var min_y := minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
		var max_y := maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
		world_rect = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

	var min_grid_x := int(floor(world_rect.position.x / block_width))
	var min_grid_y := int(floor(world_rect.position.y / block_height))
	var max_grid_x := int(ceil((world_rect.position.x + world_rect.size.x) / block_width))
	var max_grid_y := int(ceil((world_rect.position.y + world_rect.size.y) / block_height))
	return Rect2i(Vector2i(min_grid_x, min_grid_y), Vector2i(max(1, max_grid_x - min_grid_x), max(1, max_grid_y - min_grid_y)))


func _world_to_grid(world_position: Vector2) -> Vector2i:
	var tile_size := _get_tile_size()
	return Vector2i(
		int(floor(world_position.x / max(1.0, float(tile_size.x)))),
		int(floor(world_position.y / max(1.0, float(tile_size.y))))
	)


func _grid_to_chunk(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(grid_pos.x) / float(chunk_size_cells))),
		int(floor(float(grid_pos.y) / float(chunk_size_cells)))
	)


func _chunk_sets_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in left.keys():
		if not right.has(key):
			return false
	return true


func _configured_visual_tile_key(atlas_coords: Vector2i, alternative_tile: int) -> String:
	return str(atlas_coords.x) + "," + str(atlas_coords.y) + "," + str(alternative_tile)


func _rebuild_configured_visual_tiles() -> void:
	configured_visual_tiles.clear()
	configured_visual_tile_index.clear()
	visual_texture_cell_cache.clear()

	if tile_set == null:
		return

	var source_count := tile_set.get_source_count()
	for source_index in range(source_count):
		var source_id := tile_set.get_source_id(source_index)
		var source = tile_set.get_source(source_id)
		if not (source is TileSetAtlasSource):
			continue

		var atlas_source := source as TileSetAtlasSource
		var source_texture := atlas_source.texture
		var source_image: Image = null
		if source_texture != null:
			source_image = source_texture.get_image()
		var region_size := atlas_source.texture_region_size
		for tile_index in range(atlas_source.get_tiles_count()):
			var atlas_coords := atlas_source.get_tile_id(tile_index)
			var alternative_ids := _get_collision_alternative_ids(atlas_source, atlas_coords)
			for alternative_tile in alternative_ids:
				var configured_entry := {
					"source_id": source_id,
					"atlas_coords": atlas_coords,
					"alternative_tile": int(alternative_tile),
					"source": atlas_source,
					"source_image": source_image,
					"region_size": region_size
				}
				configured_visual_tiles.append(configured_entry)
				# First entry wins, matching the original linear scan which returned
				# the earliest match for a given coords/alternative pair.
				var index_key := _configured_visual_tile_key(atlas_coords, int(alternative_tile))
				if not configured_visual_tile_index.has(index_key):
					configured_visual_tile_index[index_key] = configured_entry


func _get_configured_visual_cell_for_atlas_coords(atlas_coords: Vector2i, alternative_tile := 0) -> Dictionary:
	var entry := _find_configured_visual_entry_for_atlas_coords(atlas_coords, alternative_tile)
	if entry.is_empty():
		return {}
	return _cell_data_from_collision_entry(entry)


func _find_configured_visual_entry_for_atlas_coords(atlas_coords: Vector2i, alternative_tile := 0) -> Dictionary:
	var indexed: Variant = configured_visual_tile_index.get(
		_configured_visual_tile_key(atlas_coords, int(alternative_tile))
	)
	if indexed is Dictionary:
		return indexed as Dictionary
	return {}


func _get_visual_cell_for_texture(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}

	var cache_key := _get_texture_key(texture)
	if visual_texture_cell_cache.has(cache_key):
		var cached_cell: Variant = visual_texture_cell_cache.get(cache_key, {})
		if cached_cell is Dictionary:
			return (cached_cell as Dictionary).duplicate()
		return {}

	var cell_data := _find_configured_visual_cell_for_texture(texture)
	if cell_data.is_empty():
		var source_id := _get_or_create_texture_source_id(texture, SOURCE_PROFILE_VISUAL)
		if source_id >= 0:
			cell_data = _make_cell_data(source_id)

	visual_texture_cell_cache[cache_key] = cell_data.duplicate()
	return cell_data


func _find_configured_visual_cell_for_texture(texture: Texture2D) -> Dictionary:
	var atlas_cell := _find_configured_visual_cell_from_atlas_texture(texture)
	if not atlas_cell.is_empty():
		return atlas_cell
	return _find_configured_visual_cell_by_pixels(texture)


func _find_configured_visual_cell_from_atlas_texture(texture: Texture2D) -> Dictionary:
	if not (texture is AtlasTexture):
		return {}

	var atlas_texture := texture as AtlasTexture
	if atlas_texture.atlas == null:
		return {}

	var atlas_key := _get_texture_key(atlas_texture.atlas)
	var region := atlas_texture.region
	for entry in configured_visual_tiles:
		var source = entry.get("source", null)
		if not (source is TileSetAtlasSource):
			continue
		var atlas_source := source as TileSetAtlasSource
		if atlas_source.texture == null or _get_texture_key(atlas_source.texture) != atlas_key:
			continue

		var region_size: Vector2i = entry.get("region_size", atlas_source.texture_region_size)
		var atlas_coords: Vector2i = entry.get("atlas_coords", Vector2i.ZERO)
		var expected_region := Rect2(
			Vector2(float(atlas_coords.x * region_size.x), float(atlas_coords.y * region_size.y)),
			Vector2(float(region_size.x), float(region_size.y))
		)
		if _rects_nearly_equal(region, expected_region):
			return _cell_data_from_collision_entry(entry)

	return {}


func _find_configured_visual_cell_by_pixels(texture: Texture2D) -> Dictionary:
	var texture_info := _get_texture_image_info(texture)
	if texture_info.is_empty():
		return {}

	var texture_size: Vector2i = texture_info.get("size", Vector2i.ZERO)
	for entry in configured_visual_tiles:
		var source_image = entry.get("source_image", null)
		if not (source_image is Image):
			continue
		var region_size: Vector2i = entry.get("region_size", _get_tile_size())
		if texture_size != region_size:
			continue

		var atlas_coords: Vector2i = entry.get("atlas_coords", Vector2i.ZERO)
		var source_origin := Vector2i(atlas_coords.x * region_size.x, atlas_coords.y * region_size.y)
		if _texture_info_matches_source_region(texture_info, source_image as Image, source_origin, region_size):
			return _cell_data_from_collision_entry(entry)

	return {}


func _rebuild_configured_collision_tiles() -> void:
	configured_collision_tiles.clear()
	collision_texture_cell_cache.clear()
	fallback_collision_cell.clear()
	warned_missing_collision_textures.clear()

	if collision_tile_set == null:
		return

	var source_count := collision_tile_set.get_source_count()
	for source_index in range(source_count):
		var source_id := collision_tile_set.get_source_id(source_index)
		var source = collision_tile_set.get_source(source_id)
		if not (source is TileSetAtlasSource):
			continue

		var atlas_source := source as TileSetAtlasSource
		var source_texture := atlas_source.texture
		var source_image: Image = null
		if source_texture != null:
			source_image = source_texture.get_image()
		var region_size := atlas_source.texture_region_size
		for tile_index in range(atlas_source.get_tiles_count()):
			var atlas_coords := atlas_source.get_tile_id(tile_index)
			var alternative_ids := _get_collision_alternative_ids(atlas_source, atlas_coords)
			for alternative_tile in alternative_ids:
				var tile_data = atlas_source.get_tile_data(atlas_coords, int(alternative_tile))
				if not _tile_data_has_configured_collision(tile_data):
					continue

				var cell_data := _make_cell_data(source_id, atlas_coords, int(alternative_tile))
				var entry := {
					"source_id": source_id,
					"atlas_coords": atlas_coords,
					"alternative_tile": int(alternative_tile),
					"source": atlas_source,
					"source_image": source_image,
					"region_size": region_size
				}
				configured_collision_tiles.append(entry)
				if fallback_collision_cell.is_empty():
					fallback_collision_cell = cell_data


func _get_collision_alternative_ids(atlas_source: TileSetAtlasSource, atlas_coords: Vector2i) -> Array:
	var alternative_ids: Array = []
	if atlas_source.has_method("get_alternative_tiles_count") and atlas_source.has_method("get_alternative_tile_id"):
		var alternative_count := int(atlas_source.call("get_alternative_tiles_count", atlas_coords))
		for alternative_index in range(alternative_count):
			alternative_ids.append(int(atlas_source.call("get_alternative_tile_id", atlas_coords, alternative_index)))
	if alternative_ids.is_empty():
		alternative_ids.append(0)
	return alternative_ids


func _tile_data_has_configured_collision(tile_data) -> bool:
	if tile_data == null or collision_tile_set == null:
		return false
	if collision_tile_set.get_physics_layers_count() <= PHYSICS_LAYER_INDEX:
		return false
	if tile_data.has_method("get_collision_polygons_count"):
		return int(tile_data.call("get_collision_polygons_count", PHYSICS_LAYER_INDEX)) > 0
	return true


func _get_configured_collision_cell_for_texture(texture: Texture2D, allow_fallback := true) -> Dictionary:
	if texture == null or collision_tile_set == null:
		return {}

	var cache_key := _get_texture_key(texture) + "|fallback=" + str(allow_fallback)
	if collision_texture_cell_cache.has(cache_key):
		var cached_cell: Variant = collision_texture_cell_cache.get(cache_key, {})
		if cached_cell is Dictionary:
			return (cached_cell as Dictionary).duplicate()
		return {}

	var cell_data := _find_configured_collision_cell_for_texture(texture)
	if cell_data.is_empty() and allow_fallback and not fallback_collision_cell.is_empty():
		_warn_missing_collision_texture_once(texture)
		cell_data = fallback_collision_cell.duplicate()

	collision_texture_cell_cache[cache_key] = cell_data.duplicate()
	return cell_data


func _get_static_full_collision_cell() -> Dictionary:
	if fallback_collision_cell.is_empty():
		return {}
	return fallback_collision_cell.duplicate()


func _find_configured_collision_cell_for_texture(texture: Texture2D) -> Dictionary:
	var atlas_cell := _find_configured_collision_cell_from_atlas_texture(texture)
	if not atlas_cell.is_empty():
		return atlas_cell
	return _find_configured_collision_cell_by_pixels(texture)


func _find_configured_collision_cell_from_atlas_texture(texture: Texture2D) -> Dictionary:
	if not (texture is AtlasTexture):
		return {}

	var atlas_texture := texture as AtlasTexture
	if atlas_texture.atlas == null:
		return {}

	var atlas_key := _get_texture_key(atlas_texture.atlas)
	var region := atlas_texture.region
	for entry in configured_collision_tiles:
		var source = entry.get("source", null)
		if not (source is TileSetAtlasSource):
			continue
		var atlas_source := source as TileSetAtlasSource
		if atlas_source.texture == null or _get_texture_key(atlas_source.texture) != atlas_key:
			continue

		var region_size: Vector2i = entry.get("region_size", atlas_source.texture_region_size)
		var atlas_coords: Vector2i = entry.get("atlas_coords", Vector2i.ZERO)
		var expected_region := Rect2(
			Vector2(float(atlas_coords.x * region_size.x), float(atlas_coords.y * region_size.y)),
			Vector2(float(region_size.x), float(region_size.y))
		)
		if _rects_nearly_equal(region, expected_region):
			return _cell_data_from_collision_entry(entry)

	return {}


func _find_configured_collision_cell_by_pixels(texture: Texture2D) -> Dictionary:
	var texture_info := _get_texture_image_info(texture)
	if texture_info.is_empty():
		return {}

	var texture_size: Vector2i = texture_info.get("size", Vector2i.ZERO)
	for entry in configured_collision_tiles:
		var source_image = entry.get("source_image", null)
		if not (source_image is Image):
			continue
		var region_size: Vector2i = entry.get("region_size", _get_tile_size())
		if texture_size != region_size:
			continue

		var atlas_coords: Vector2i = entry.get("atlas_coords", Vector2i.ZERO)
		var source_origin := Vector2i(atlas_coords.x * region_size.x, atlas_coords.y * region_size.y)
		if _texture_info_matches_source_region(texture_info, source_image as Image, source_origin, region_size):
			return _cell_data_from_collision_entry(entry)

	return {}


func _cell_data_from_collision_entry(entry: Dictionary) -> Dictionary:
	return _make_cell_data(
		int(entry.get("source_id", -1)),
		entry.get("atlas_coords", Vector2i.ZERO),
		int(entry.get("alternative_tile", 0))
	)


func _get_texture_image_info(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}

	var image: Image = null
	var origin := Vector2i.ZERO
	var size := _get_texture_region_size(texture)

	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas != null:
			image = atlas_texture.atlas.get_image()
			var region := atlas_texture.region
			origin = Vector2i(int(floor(region.position.x)), int(floor(region.position.y)))
			size = Vector2i(int(round(region.size.x)), int(round(region.size.y)))
	else:
		image = texture.get_image()

	if image == null or size.x <= 0 or size.y <= 0:
		return {}

	return {
		"image": image,
		"origin": origin,
		"size": size
	}


func _texture_info_matches_source_region(texture_info: Dictionary, source_image: Image, source_origin: Vector2i, region_size: Vector2i) -> bool:
	var texture_image = texture_info.get("image", null)
	if not (texture_image is Image):
		return false

	var texture_origin: Vector2i = texture_info.get("origin", Vector2i.ZERO)
	var texture_size: Vector2i = texture_info.get("size", Vector2i.ZERO)
	if texture_size != region_size:
		return false

	var candidate_image := texture_image as Image
	if not _image_region_in_bounds(candidate_image, texture_origin, texture_size):
		return false
	if not _image_region_in_bounds(source_image, source_origin, region_size):
		return false

	for y in range(region_size.y):
		for x in range(region_size.x):
			var left := candidate_image.get_pixel(texture_origin.x + x, texture_origin.y + y)
			var right := source_image.get_pixel(source_origin.x + x, source_origin.y + y)
			if not _colors_nearly_equal(left, right):
				return false
	return true


func _image_region_in_bounds(image: Image, origin: Vector2i, size: Vector2i) -> bool:
	if image == null:
		return false
	if origin.x < 0 or origin.y < 0:
		return false
	if origin.x + size.x > image.get_width():
		return false
	if origin.y + size.y > image.get_height():
		return false
	return true


func _colors_nearly_equal(left: Color, right: Color) -> bool:
	if left.a <= 0.01 and right.a <= 0.01:
		return true
	var tolerance := 0.01
	return absf(left.r - right.r) <= tolerance \
		and absf(left.g - right.g) <= tolerance \
		and absf(left.b - right.b) <= tolerance \
		and absf(left.a - right.a) <= tolerance


func _rects_nearly_equal(left: Rect2, right: Rect2) -> bool:
	var tolerance := 0.01
	return absf(left.position.x - right.position.x) <= tolerance \
		and absf(left.position.y - right.position.y) <= tolerance \
		and absf(left.size.x - right.size.x) <= tolerance \
		and absf(left.size.y - right.size.y) <= tolerance


func _warn_missing_collision_texture_once(texture: Texture2D) -> void:
	var texture_key := _get_texture_key(texture)
	if warned_missing_collision_textures.has(texture_key):
		return
	warned_missing_collision_textures[texture_key] = true
	push_warning("WorldTileMapRenderer: no matching configured collision tile for " + texture_key + "; using the first configured solid TileSet tile.")


func _get_or_create_texture_source_id(texture: Texture2D, source_profile := SOURCE_PROFILE_VISUAL) -> int:
	var source_key := _get_texture_key(texture) + "|" + source_profile
	if texture_source_ids.has(source_key):
		return int(texture_source_ids[source_key])

	var source_texture := texture
	var region_size := _get_texture_region_size(texture)
	if texture is AtlasTexture:
		var texture_info := _get_texture_image_info(texture)
		if texture_info.is_empty():
			return -1
		var source_image = texture_info.get("image", null)
		var source_origin: Vector2i = texture_info.get("origin", Vector2i.ZERO)
		region_size = texture_info.get("size", Vector2i.ZERO)
		if not (source_image is Image) or not _image_region_in_bounds(source_image as Image, source_origin, region_size):
			return -1
		var cropped_image := (source_image as Image).get_region(Rect2i(source_origin, region_size))
		source_texture = ImageTexture.create_from_image(cropped_image)

	if source_texture == null or region_size.x <= 0 or region_size.y <= 0:
		return -1
	if int(source_texture.get_width()) < region_size.x or int(source_texture.get_height()) < region_size.y:
		return -1

	var source := TileSetAtlasSource.new()
	source.texture = source_texture
	source.texture_region_size = region_size
	if not source.has_tile(Vector2i.ZERO):
		source.create_tile(Vector2i.ZERO)

	var source_id := tile_set.add_source(source)
	texture_source_ids[source_key] = source_id
	return source_id


func _get_texture_key(texture: Texture2D) -> String:
	var resource_path := str(texture.resource_path)
	if resource_path != "":
		return resource_path
	return str(texture.get_instance_id())


func _get_texture_region_size(texture: Texture2D) -> Vector2i:
	var width: int = max(1, int(texture.get_width()))
	var height: int = max(1, int(texture.get_height()))
	return Vector2i(width, height)
