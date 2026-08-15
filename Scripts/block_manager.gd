extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const WorldTileMapRenderer = preload("res://Scripts/world_tilemap_renderer.gd")
const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")
const ColourCycleModulation = preload("res://Scripts/colour_cycle_modulation.gd")

const TILEMAP_ENV_DISABLED_VALUES := ["0", "false", "no", "off"]
const DEFAULT_BACKGROUND_TILEMAP_ONLY_ENABLED := true
const DEFAULT_FOREGROUND_TILEMAP_ONLY_ENABLED := true
const DEFAULT_FOREGROUND_TILEMAP_COLLISION_ENABLED := true
const DEFAULT_FOREGROUND_TILEMAP_COLLISION_REPLACES_NODES_ENABLED := true
const SPRINGBOARD_WATER_SPLASH_DEDUPE_MS := 340
const SPRINGBOARD_WATER_SPLASH_INTENSITY := 0.80
const SPRINGBOARD_WATER_SPLASH_BODY_OFFSET_RATIO := 0.25
const SPRINGBOARD_WATER_SPLASH_SURFACE_OFFSET_RATIO := 0.15
const SPRINGBOARD_WATER_SPLASH_HALF_WIDTH_RATIO := 0.35

var world = null
var background_blocks: Dictionary = {}
var tilemap_renderer = null
var background_tilemap_only_enabled := DEFAULT_BACKGROUND_TILEMAP_ONLY_ENABLED
var foreground_tilemap_only_enabled := DEFAULT_FOREGROUND_TILEMAP_ONLY_ENABLED
var foreground_tilemap_collision_enabled := DEFAULT_FOREGROUND_TILEMAP_COLLISION_ENABLED
var foreground_tilemap_collision_replaces_nodes_enabled := DEFAULT_FOREGROUND_TILEMAP_COLLISION_REPLACES_NODES_ENABLED
var last_server_sign_on_notice_at := 0
var animated_block_visuals: Dictionary = {}
var tilemap_foreground_animated_cells: Dictionary = {}
var animation_loop_particle_last_emit_msec: Dictionary = {}
var tilemap_animation_frame_cache: Dictionary = {}
var oil_refinery_running_frame_cache: Dictionary = {}
var tilemap_springboard_active_cells: Dictionary = {}
var springboard_water_splash_last_emit_msec: Dictionary = {}
var wooden_entrance_active_visuals: Dictionary = {}
var springboard_active_visuals: Dictionary = {}
var server_triggered_animation_tokens: Dictionary = {}
var transformer_power_states: Dictionary = {}
var dice_active_rolls: Dictionary = {}
var anti_punch_active_visuals: Dictionary = {}
var anti_talk_active_visuals: Dictionary = {}
var anti_gravity_active_visuals: Dictionary = {}
var colour_cycle_block_visuals: Dictionary = {}
var springboard_frame_cache: Dictionary = {}
var dice_frame_cache: Dictionary = {}
var wooden_entrance_frame_cache: Dictionary = {}
var display_preview_visuals: Dictionary = {}
var display_preview_glass_visuals: Dictionary = {}
var display_preview_content_rect_cache: Dictionary = {}
var pending_display_transactions: Dictionary = {}
var pending_display_transaction_requests: Dictionary = {}
var display_request_sequence := 0
var tackle_box_timer_label: Label = null
var next_tackle_box_visual_refresh_at_ms := 0
var next_chicken_visual_refresh_at_ms := 0
var next_cow_visual_refresh_at_ms := 0
var next_duck_visual_refresh_at_ms := 0
var pending_tackle_box_harvests: Dictionary = {}
var pending_chicken_interactions: Dictionary = {}
var pending_cow_interactions: Dictionary = {}
var pending_duck_interactions: Dictionary = {}
var pending_dice_rolls: Dictionary = {}
var dice_roll_break_windows: Dictionary = {}
var snow_storm_visuals_active := false
var snow_storm_local_block_overrides: Dictionary = {}
var last_wooden_entrance_grid := Vector2i(-999999, -999999)
var visual_variant_texture_cache: Dictionary = {}
var atlas_variant_texture_cache: Dictionary = {}
# Memoized get_block_tilemap_metadata results for the variant-independent call shape,
# keyed by "block_type|visual_block_type|background". Derived purely from the item
# database, so it stays valid for the lifetime of the loaded item data.
var tilemap_metadata_cache: Dictionary = {}
# Memoized ITEM_ATLAS_DB.get_item() results, keyed by atlas item id.
#
# get_item() ends in `(item as Dictionary).duplicate(true)` (ItemAtlasDB.gd:139) -- a DEEP copy
# of the item dictionary on every call. That is the correct default for callers that mutate the
# result, but get_block_tilemap_metadata() only ever READS it (is_empty / get "atlas_enabled" /
# "atlas_coords" / "source_id" / "alternative_tile"), and the tilemap_metadata_cache above
# cannot absorb it: that cache is deliberately bypassed whenever grid_pos != NO_VARIANT_GRID_POS
# (see can_cache_metadata), which is exactly the shape the world-load path uses. So during a
# world build this deep copy ran per block, several times per block, across all of the
# finalize_world_load_block_variants passes -- O(tiles) allocation churn for data that never
# changes after the atlas DB is loaded.
#
# The atlas database is static once loaded, so one shared read-only copy per id is safe.
# Treat entries as IMMUTABLE: never mutate a dictionary returned from here.
var atlas_item_metadata_cache: Dictionary = {}
# get_block_item_data() is called once per block during a world build -- 692 calls on a ~757
# block world, 62 ms of self time in the profiler -- but a world only contains a few dozen
# distinct block types. Every call re-runs str()/strip_edges()/to_lower() and
# normalize_legacy_block_id(), then on a miss falls through to ITEM_ATLAS_DB, all to arrive at
# the same dictionary. Memoize on the raw argument.
#
# Invalidation: world.item_database is reassigned wholesale in setup_item_database() and also
# gains generated seed entries at runtime, so the cache is dropped whenever its size changes.
# Only non-empty results are stored, so a type that does not resolve yet is retried rather
# than pinned to {} forever.
var block_item_data_cache: Dictionary = {}
var block_item_data_cache_source_size: int = -1
var existing_variant_path_cache: Dictionary = {}
var connected_variant_component_cache: Dictionary = {}
var authoritative_break_request_keys: Dictionary = {}
var authoritative_place_request_times: Dictionary = {}
var authoritative_place_last_request_ms := 0
var last_block_break_input_at_msec := 0
var predicted_authoritative_place_requests: Dictionary = {}
var predicted_authoritative_place_sequence := 0
var place_trace_enabled := false
var place_trace_world_state_enabled := false
var place_trace_lines_left := 0
var place_trace_sequence := 0
var pending_foreground_texture_refresh: Array = []
var pending_anti_control_visual_refresh := false
var water_overlay_draw_order_refresh_pending := true
var block_light_fx_scene_cache: Dictionary = {}
var colour_cycle_block_update_elapsed: float = 0.0
const AUTHORITATIVE_REQUEST_REPEAT_MS := 120
const AUTHORITATIVE_PLACE_GLOBAL_REPEAT_MS := 150
const AUTHORITATIVE_PLACE_PREDICTION_TIMEOUT_MS := 10000
const AUTHORITATIVE_PLACE_RECONCILE_REPEAT_MS := 2500
const BLOCK_BREAK_INPUT_INTERVAL_MSEC := 300
const DEBUG_ACTION_POSITION_FLOW := false
const PLACE_TRACE_ARG := "--pm-place-trace"
const PLACE_TRACE_ENV := "PIXELMANIA_PLACE_TRACE"
const PLACE_TRACE_WORLD_STATE_ARG := "--pm-place-trace-world-state"
const PLACE_TRACE_WORLD_STATE_ENV := "PIXELMANIA_PLACE_TRACE_WORLD_STATE"
const PLACE_TRACE_MAX_LINES_ENV := "PIXELMANIA_PLACE_TRACE_MAX_LINES"
const PLACE_TRACE_DEFAULT_MAX_LINES := 800
const PLACE_TRACE_ENABLED_VALUES := ["1", "true", "yes", "on", "debug"]
const WOODEN_ENTRANCE_FRAME_SECONDS := 0.11
const NORMAL_BLOCK_Z_INDEX := 0
const WATER_OVERLAY_Z_INDEX := 4050
const WATER_VISUAL_Z_INDEX := 0
const FOREGROUND_OVER_PLAYER_Z_INDEX := 4020
const COLOUR_CYCLE_BLOCK_UPDATE_SECONDS := 0.033
const SNOW_STORM_ICE_VARIANT_SALT := 9047
const FOREGROUND_TEXTURE_REFRESH_BATCH_SIZE := 1024
const FOREGROUND_TEXTURE_REFRESH_PROCESS_USEC := 2500
# Final world-load visual pass. Bulk loading skips neighbor refresh per block,
# so one batched pass fixes dirt/water/tree/vine/platform variants before gameplay starts.
const WORLD_LOAD_VARIANT_FINALIZE_BATCH_SIZE := 768
# Batch size used when this finalize pass runs as part of an INITIAL world entry, i.e. with the
# loading overlay covering the screen and the player not yet in control. Same reasoning as
# WORLD_ENTRY_APPLY_DESKTOP_BUDGET_USEC in world_state_sync_manager.gd: at 768 blocks per yield,
# finalizing a full 100x70 world (~7,000 foreground + ~7,000 background entries) costs ~18
# `await get_tree().process_frame` waits, and each of those burns a whole ~16.7ms vsync frame to
# buy a few ms of work. That is ~300ms of the join spent deliberately idle so a loading spinner
# stays smooth. During entry we want time-to-playable instead. The yields are kept (not removed)
# so the overlay can still repaint and so a cancelled/superseded join is not starved.
const WORLD_ENTRY_VARIANT_FINALIZE_BATCH_SIZE := 8192
const MAX_CONNECTED_VARIANT_COMPONENT_CELLS := 8192
const BLOCK_TEXTURE_SHADOW_NAME := "TextureShadow"
const BLOCK_TEXTURE_SHADOW_OFFSET := Vector2(1.5, 1.5)
const BLOCK_TEXTURE_SHADOW_ALPHA := 0.38
const AREA_LOCK_OWNER_MODULATE := Color(0.58, 1.0, 0.58, 1.0)
const AREA_LOCK_ACCESS_MODULATE := Color(1.0, 0.9, 0.38, 1.0)
const AREA_LOCK_NO_ACCESS_MODULATE := Color(1.0, 0.48, 0.48, 1.0)
const BLOCK_LIGHT_FX_NODE_NAME := "BlockLightFX"
const DISPLAY_PREVIEW_LAYER_NAME := "DisplayItemPreviewLayer"
const DISPLAY_PREVIEW_Z_INDEX := NORMAL_BLOCK_Z_INDEX - 1
const DISPLAY_PREVIEW_ITEM_Z_INDEX := 0
const FISH_HANGER_DISPLAY_PREVIEW_ITEM_Z_INDEX := 2
const DISPLAY_PREVIEW_GLASS_Z_INDEX := 1
const DEFAULT_DISPLAY_PREVIEW_MAX_SIZE := 25.0
const DEFAULT_DISPLAY_PREVIEW_ALPHA := 1.0
const DEFAULT_DISPLAY_GLASS_ALPHA := 0.22
const DISPLAY_PREVIEW_INVENTORY_ICON_SIZE := 28.0
const DEFAULT_DISPLAY_GLASS_COLOR := Color(0.72, 0.92, 1.0, 1.0)
const DISPLAY_PREVIEW_ALPHA_THRESHOLD := 0.01
const DISPLAY_TRANSACTION_PENDING_MS := 1800
const MOBILE_PUNCH_AREA_LOOKUP_RADIUS_TILES := 2
const TACKLE_BOX_TIMER_LABEL_WIDTH := 260.0
const TACKLE_BOX_TIMER_LABEL_HEIGHT := 34.0
const TACKLE_BOX_TIMER_WORLD_OFFSET := Vector2(0.0, -35.0)
const TACKLE_BOX_TIMER_FONT_SIZE := 18
const TACKLE_BOX_TIMER_OUTLINE_SIZE := 5
const TACKLE_BOX_VISUAL_REFRESH_INTERVAL_MS := 1000
const TACKLE_BOX_HARVEST_PENDING_MS := 2000
const CHICKEN_PRODUCTION_MS := 43200000
const CHICKEN_HUNGER_MS := 604800000
const CHICKEN_INTERACTION_PENDING_MS := 2000
const COW_PRODUCTION_MS := 43200000
const COW_HUNGER_MS := 604800000
const COW_INTERACTION_PENDING_MS := 2000
const DUCK_PRODUCTION_MS := 43200000
const DUCK_HUNGER_MS := 604800000
const DUCK_INTERACTION_PENDING_MS := 2000
const DICE_ROLL_PENDING_MS := 2000
const DICE_ROLL_BREAK_WINDOW_MS := 2500
const BACKGROUND_CRACK_Z_INDEX := -5
const NO_VARIANT_GRID_POS := Vector2i(-999999, -999999)
const BARN_BLOCK_TYPE := "barn_block"
const BARN_NEIGHBOR_UP := 1
const BARN_NEIGHBOR_RIGHT := 2
const BARN_NEIGHBOR_DOWN := 4
const BARN_NEIGHBOR_LEFT := 8
const BARN_CONNECTED_VARIANT_ATLAS_COORDS: Dictionary = {
	"single": Vector2i(0, 20),
	"top": Vector2i(1, 20),
	"middle": Vector2i(1, 21),
	"top_left_corner": Vector2i(3, 20),
	"top_right_corner": Vector2i(4, 20),
	"horizontal_middle": Vector2i(2, 20),
	"left": Vector2i(0, 21),
	"right": Vector2i(2, 21),
	"bottom_left_corner": Vector2i(3, 21),
	"bottom_right_corner": Vector2i(4, 21),
	"vertical_middle": Vector2i(0, 22),
	"bottom": Vector2i(1, 22),
	"tile_top_left_corner": Vector2i(0, 24),
	"tile_top_middle": Vector2i(1, 24),
	"tile_top_right_corner": Vector2i(2, 24),
	"tile_middle_left": Vector2i(0, 25),
	"tile_middle_middle": Vector2i(1, 25),
	"tile_middle_right": Vector2i(2, 25),
	"tile_bottom_left_corner": Vector2i(0, 26),
	"tile_bottom_middle": Vector2i(1, 26),
	"tile_bottom_right_corner": Vector2i(2, 26)
}
const BARN_NO_ATLAS_COORDS := Vector2i(-999998, -999998)
const BARN_BASIC_MASK_ATLAS_COORDS: Dictionary = {
	0: Vector2i(0, 20),
	1: Vector2i(1, 22),
	2: Vector2i(0, 21),
	3: Vector2i(3, 21),
	4: Vector2i(1, 20),
	5: Vector2i(0, 22),
	6: Vector2i(3, 20),
	8: Vector2i(2, 21),
	9: Vector2i(4, 21),
	10: Vector2i(2, 20),
	12: Vector2i(4, 20)
}
const BARN_DEDICATED_T_JUNCTION_ATLAS_COORDS: Dictionary = {}
const BARN_T_JUNCTION_FALLBACK_ATLAS_COORDS: Dictionary = {
	7: Vector2i(0, 25),
	11: Vector2i(1, 26),
	13: Vector2i(2, 25),
	14: Vector2i(1, 24)
}
const DIRT_TOP_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/dirt_block.png"
const DIRT_LOWER_TEXTURE_PATHS := [
	"res://Assets/blocks/Tier_1/basic blocks/dirt_block_1.png",
	"res://Assets/blocks/Tier_1/basic blocks/dirt_block_2.png"
]
const STONE_TEXTURE_PATHS := [
	"res://Assets/blocks/Tier_1/basic blocks/stone_block.png",
	"res://Assets/blocks/Tier_1/basic blocks/stone_block_2.png",
	"res://Assets/blocks/Tier_1/basic blocks/stone_block_3.png"
]
const WATER_BLOCK_TYPE := "water"
const WATER_BUCKET_ITEM_TYPE := "water_bucket"
const WATER_TOP_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/water_0.png"
const WATER_LOWER_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/water_block_2.png"
const WATER_LOWER_ATLAS_COORDS := Vector2i(5, 3)
const TREE_TRUNK_BOTTOM_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/tree_trunk_bottom.png"
const TREE_TRUNK_MIDDLE_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/tree_trunk_middle.png"
const TREE_TRUNK_TOP_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/tree_trunk_top.png"
const CLIMBING_VINE_BOTTOM_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/climbing_vine_1.png"
const CLIMBING_VINE_MIDDLE_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/climbing_vine_2.png"
const CLIMBING_VINE_TOP_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/climbing_vine_3.png"
const WOOD_PLATFORM_LEFT_END_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform_left_end.png"
const WOOD_PLATFORM_MIDDLE_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform_middle.png"
const WOOD_PLATFORM_RIGHT_END_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform_right_end.png"
const CAVE_BACKGROUND_TEXTURE_PATHS := [
	"res://Assets/background/cave_background.png",
	"res://Assets/background/cave_background_2.png",
	"res://Assets/background/cave_background_3.png"
]
const DEFAULT_BLOCKS_ATLAS_PATH := "res://image.png"

func setup(world_ref):
	world = world_ref
	water_overlay_draw_order_refresh_pending = true
	clear_connected_variant_component_cache()
	configure_place_trace()
	background_tilemap_only_enabled = resolve_background_tilemap_only_enabled()
	foreground_tilemap_only_enabled = resolve_foreground_tilemap_only_enabled()
	foreground_tilemap_collision_enabled = resolve_foreground_tilemap_collision_enabled()
	foreground_tilemap_collision_replaces_nodes_enabled = resolve_foreground_tilemap_collision_replacement_enabled()
	ensure_tilemap_renderer()
	var foreground_collision_backend := "TileMapLayer" if foreground_tilemap_collision_enabled and foreground_tilemap_collision_replaces_nodes_enabled else "BlockNodes"
	print("[BlockManager] Foreground collision backend: ", foreground_collision_backend, " foreground_tilemap_only=", foreground_tilemap_only_enabled)


func resolve_background_tilemap_only_enabled() -> bool:
	return resolve_tilemap_env_enabled("PIXELMANIA_TILEMAP_ONLY_BACKGROUNDS", DEFAULT_BACKGROUND_TILEMAP_ONLY_ENABLED)


func resolve_foreground_tilemap_only_enabled() -> bool:
	return resolve_tilemap_env_enabled("PIXELMANIA_TILEMAP_ONLY_FOREGROUNDS", DEFAULT_FOREGROUND_TILEMAP_ONLY_ENABLED)


func resolve_foreground_tilemap_collision_enabled() -> bool:
	return resolve_tilemap_env_enabled("PIXELMANIA_FOREGROUND_TILEMAP_COLLISION", DEFAULT_FOREGROUND_TILEMAP_COLLISION_ENABLED)


func resolve_foreground_tilemap_collision_replacement_enabled() -> bool:
	return resolve_tilemap_env_enabled("PIXELMANIA_FOREGROUND_TILEMAP_COLLISION_REPLACES_NODES", DEFAULT_FOREGROUND_TILEMAP_COLLISION_REPLACES_NODES_ENABLED)


func resolve_tilemap_env_enabled(env_name: String, default_value: bool) -> bool:
	var env_value := OS.get_environment(env_name).strip_edges().to_lower()
	if env_value == "":
		return default_value
	return not TILEMAP_ENV_DISABLED_VALUES.has(env_value)


func get_tilemap_runtime_config() -> Dictionary:
	var config := {
		"background_tilemap_only_enabled": background_tilemap_only_enabled,
		"foreground_tilemap_only_enabled": foreground_tilemap_only_enabled,
		"foreground_tilemap_collision_enabled": foreground_tilemap_collision_enabled,
		"foreground_tilemap_collision_replaces_nodes_enabled": foreground_tilemap_collision_replaces_nodes_enabled,
		"default_background_tilemap_only_enabled": DEFAULT_BACKGROUND_TILEMAP_ONLY_ENABLED,
		"default_foreground_tilemap_only_enabled": DEFAULT_FOREGROUND_TILEMAP_ONLY_ENABLED,
		"default_foreground_tilemap_collision_enabled": DEFAULT_FOREGROUND_TILEMAP_COLLISION_ENABLED,
		"default_foreground_tilemap_collision_replaces_nodes_enabled": DEFAULT_FOREGROUND_TILEMAP_COLLISION_REPLACES_NODES_ENABLED,
	}
	var renderer = ensure_tilemap_renderer()
	if renderer != null and renderer.has_method("get_streaming_summary"):
		config["streaming"] = renderer.get_streaming_summary()
	return config


func ensure_tilemap_renderer():
	if world == null:
		return null

	if tilemap_renderer != null and is_instance_valid(tilemap_renderer):
		return tilemap_renderer

	tilemap_renderer = world.get_node_or_null("WorldTileMapRenderer")
	if tilemap_renderer == null:
		tilemap_renderer = WorldTileMapRenderer.new()
		tilemap_renderer.name = "WorldTileMapRenderer"
		world.add_child(tilemap_renderer)

	if tilemap_renderer != null and tilemap_renderer.has_method("setup"):
		tilemap_renderer.setup(world)

	return tilemap_renderer


func clear_tilemap_cell(grid_pos: Vector2i, background := false) -> void:
	if not background:
		tilemap_foreground_animated_cells.erase(grid_pos)
		clear_animation_loop_particle_emitters_for_grid(grid_pos)
		tilemap_springboard_active_cells.erase(grid_pos)
		dice_active_rolls.erase(grid_pos)
	var renderer = ensure_tilemap_renderer()
	if renderer != null and renderer.has_method("erase_block_cell"):
		renderer.erase_block_cell(grid_pos, background)


func clear_all_tilemap_cells() -> void:
	var renderer = ensure_tilemap_renderer()
	if renderer != null and renderer.has_method("clear"):
		renderer.clear()
	tilemap_foreground_animated_cells.clear()
	animation_loop_particle_last_emit_msec.clear()
	tilemap_springboard_active_cells.clear()
	server_triggered_animation_tokens.clear()
	clear_connected_variant_component_cache()
	clear_display_preview_visuals()
	clear_colour_cycle_block_visuals()
	var preview_manager = world.get("vending_preview_manager") if world != null else null
	if preview_manager != null and preview_manager.has_method("clear_vending_machine_previews"):
		preview_manager.clear_vending_machine_previews()


func spawn_block_hit_particles(grid_pos: Vector2i, block_type: String, layer: String = "foreground"):
	if world != null and world.has_method("spawn_block_hit_particles"):
		world.spawn_block_hit_particles(grid_pos, block_type, layer)
	spawn_neptune_trident_block_hit_particles(grid_pos, block_type, layer, get_current_block_hit_source_tool())


func spawn_neptune_trident_block_hit_particles(grid_pos: Vector2i, block_type: String, layer: String = "foreground", source_tool: String = ""):
	if source_tool.strip_edges() == "":
		source_tool = get_current_block_hit_source_tool()
	if world != null and world.has_method("spawn_neptune_trident_block_hit_particles"):
		world.spawn_neptune_trident_block_hit_particles(grid_pos, block_type, layer, source_tool)


func spawn_hand_item_swing_particles_at_grid(grid_pos: Vector2i, source_tool: String = "") -> bool:
	if world == null or not world.has_method("spawn_hand_item_swing_particles"):
		return false

	var resolved_tool := source_tool.strip_edges()
	if resolved_tool == "":
		resolved_tool = get_current_block_hit_source_tool()

	return bool(world.spawn_hand_item_swing_particles(get_block_sound_position(grid_pos), resolved_tool))


func get_current_block_hit_source_tool() -> String:
	if world == null:
		return ""
	var equipped = world.get("equipped_tool")
	if equipped != null and ["neptune_trident", "ant_sword", "phoenix_sword", "fire_staff", "wizards_staff"].has(str(equipped).strip_edges().to_lower()):
		return str(equipped).strip_edges()
	if str(world.get("selected_item_category")) == "tool":
		var selected_tool := str(world.get("selected_item_type")).strip_edges()
		if selected_tool != "":
			return selected_tool
	if equipped != null and str(equipped).strip_edges() != "":
		return str(equipped)
	return ""


func is_current_block_hit_punch_action() -> bool:
	if world == null:
		return false
	if str(world.get("selected_item_category")) == "tool" and str(world.get("selected_item_type")).strip_edges().to_lower() == "punch":
		return true
	return get_current_block_hit_source_tool().strip_edges().to_lower() == "punch"


func get_block_sound_position(grid_pos: Vector2i) -> Vector2:
	if world != null and world.has_method("get_block_center_world_position"):
		return world.get_block_center_world_position(grid_pos)
	var block_size := 32.0
	if world != null:
		var world_block_size = world.get("BLOCK_SIZE")
		if world_block_size is int or world_block_size is float:
			block_size = float(world_block_size)
	return Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)


func play_block_hit_sound(grid_pos: Vector2i) -> void:
	if world != null and world.has_method("play_sound_punch"):
		world.play_sound_punch(get_block_sound_position(grid_pos))


func play_block_break_sound(grid_pos: Vector2i) -> void:
	if world != null and world.has_method("play_sound_break"):
		world.play_sound_break(get_block_sound_position(grid_pos))
	elif world != null and world.has_method("play_sound_punch"):
		world.play_sound_punch(get_block_sound_position(grid_pos))


func play_block_action_sound(grid_pos: Vector2i, breaking: bool) -> void:
	if breaking:
		play_block_break_sound(grid_pos)
	else:
		play_block_hit_sound(grid_pos)


func spawn_block_break_particles(grid_pos: Vector2i, block_type: String, layer: String = "foreground"):
	if world != null and world.has_method("spawn_block_break_particles"):
		world.spawn_block_break_particles(grid_pos, block_type, layer)


func spawn_block_place_particles(grid_pos: Vector2i, block_type: String, layer: String = "foreground"):
	if world != null and world.has_method("spawn_block_place_particles"):
		world.spawn_block_place_particles(grid_pos, block_type, layer)


func set_snow_storm_visuals_active(active: bool):
	if snow_storm_visuals_active == active:
		return

	snow_storm_visuals_active = active
	if not snow_storm_visuals_active:
		restore_snow_storm_local_block_overrides()
	refresh_all_foreground_block_textures()


func get_snow_storm_source_block_type(grid_pos: Vector2i, source_types: Dictionary = {}) -> String:
	if source_types.has(grid_pos):
		return str(source_types[grid_pos])

	return get_foreground_block_type_at(grid_pos)


func get_snow_storm_actual_block_type(grid_pos: Vector2i, block_type: String, source_types: Dictionary = {}) -> String:
	if not snow_storm_visuals_active:
		return block_type

	match block_type:
		"water":
			return get_snow_storm_ice_block_type(grid_pos)
		"sand":
			return "snow_bank"
		"stone":
			return "snow_stone"
		"dirt":
			var above_type = get_snow_storm_source_block_type(Vector2i(grid_pos.x, grid_pos.y - 1), source_types)
			if above_type == "snow_block":
				return "snow_dirt"
			if above_type == "snow_dirt":
				return "dirt"
			if above_type != "dirt":
				return "snow_block"
			var above_above_type = get_snow_storm_source_block_type(Vector2i(grid_pos.x, grid_pos.y - 2), source_types)
			if above_type == "dirt":
				if above_above_type == "dirt" or above_above_type == "snow_block" or above_above_type == "snow_dirt":
					return "dirt"
				return "snow_dirt"

	return block_type


func remember_snow_storm_local_block_override(grid_pos: Vector2i, original_type: String, event_type: String):
	if snow_storm_local_block_overrides.has(grid_pos):
		return

	snow_storm_local_block_overrides[grid_pos] = {
		"original_type": original_type,
		"event_type": event_type
	}


func apply_snow_storm_actual_block_type(grid_pos: Vector2i, block_type: String, source_types: Dictionary = {}) -> String:
	var event_type = get_snow_storm_actual_block_type(grid_pos, block_type, source_types)
	if event_type != block_type:
		remember_snow_storm_local_block_override(grid_pos, block_type, event_type)
		return event_type

	return event_type


func apply_snow_storm_local_block_overrides():
	if world == null:
		return

	var source_types: Dictionary = {}
	for grid_pos in world.blocks.keys():
		if not world.blocks.has(grid_pos):
			continue

		source_types[grid_pos] = str(world.blocks[grid_pos].get("type", ""))

	for grid_pos in source_types.keys():
		if not world.blocks.has(grid_pos):
			continue

		var block_type := str(source_types[grid_pos])
		var event_type = apply_snow_storm_actual_block_type(grid_pos, block_type, source_types)
		if event_type == block_type:
			continue

		replace_event_block_without_drop(grid_pos, event_type)


func restore_snow_storm_local_block_overrides():
	if world == null:
		snow_storm_local_block_overrides.clear()
		return

	for grid_pos in snow_storm_local_block_overrides.keys():
		if not world.blocks.has(grid_pos):
			continue

		var override_data = snow_storm_local_block_overrides[grid_pos]
		if not (override_data is Dictionary):
			continue

		var current_type := str(world.blocks[grid_pos].get("type", ""))
		var event_type := str(override_data.get("event_type", ""))
		if current_type != event_type:
			continue

		var original_type := str(override_data.get("original_type", ""))
		if original_type == "":
			continue

		replace_event_block_without_drop(grid_pos, original_type)

	snow_storm_local_block_overrides.clear()


func refresh_all_foreground_block_textures():
	queue_foreground_block_texture_refresh()


func queue_foreground_block_texture_refresh():
	if world == null:
		pending_foreground_texture_refresh.clear()
		return

	pending_foreground_texture_refresh = world.blocks.keys()


func process_pending_foreground_texture_refresh():
	if pending_foreground_texture_refresh.is_empty():
		return
	if world == null:
		pending_foreground_texture_refresh.clear()
		return

	var processed := 0
	var started_usec := Time.get_ticks_usec()
	while processed < FOREGROUND_TEXTURE_REFRESH_BATCH_SIZE and not pending_foreground_texture_refresh.is_empty():
		var grid_pos = pending_foreground_texture_refresh.pop_back()
		if world.blocks.has(grid_pos):
			normalize_block_variant_at(grid_pos, false)
		processed += 1
		if Time.get_ticks_usec() - started_usec >= FOREGROUND_TEXTURE_REFRESH_PROCESS_USEC:
			break


func _process(delta):
	if water_overlay_draw_order_refresh_pending:
		refresh_water_overlay_draw_order()
	update_tilemap_foreground_animations()
	update_wooden_entrance_crossing()
	update_wooden_entrance_animations(delta)
	update_tilemap_springboard_animations(delta)
	update_springboard_animations(delta)
	update_dice_roll_animations(delta)
	update_anti_punch_animations(delta)
	update_anti_talk_animations(delta)
	update_anti_gravity_animations(delta)
	update_tackle_box_timer_hover()
	update_due_tackle_box_visuals()
	update_due_chicken_visuals()
	update_due_cow_visuals()
	update_due_duck_visuals()
	update_colour_cycle_block_visuals_throttled(delta)
	process_pending_foreground_texture_refresh()
	process_pending_anti_control_visual_refresh()
	cleanup_expired_authoritative_place_predictions()

	if not animated_block_visuals.is_empty():
		update_synced_block_animations()


func debug_action_position_flow(message: String, extra_data: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][BlockManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text + " data=" + str(extra_data))


func configure_place_trace() -> void:
	var launch_enabled := false
	if MovementMode != null and MovementMode.has_method("has_launch_arg") and MovementMode.has_launch_arg(PLACE_TRACE_ARG):
		launch_enabled = true
	var env_value := OS.get_environment(PLACE_TRACE_ENV).strip_edges().to_lower()
	var env_enabled := PLACE_TRACE_ENABLED_VALUES.has(env_value)
	place_trace_enabled = launch_enabled or env_enabled
	var world_state_launch_enabled := false
	if MovementMode != null and MovementMode.has_method("has_launch_arg") and MovementMode.has_launch_arg(PLACE_TRACE_WORLD_STATE_ARG):
		world_state_launch_enabled = true
	var world_state_env_value := OS.get_environment(PLACE_TRACE_WORLD_STATE_ENV).strip_edges().to_lower()
	place_trace_world_state_enabled = world_state_launch_enabled or PLACE_TRACE_ENABLED_VALUES.has(world_state_env_value)
	place_trace_lines_left = get_place_trace_max_lines() if place_trace_enabled else 0
	place_trace_sequence = 0
	if place_trace_enabled:
		print("[PM_PLACE_TRACE] enabled max_lines=" + str(place_trace_lines_left) + " flag=" + PLACE_TRACE_ARG + " env=" + PLACE_TRACE_ENV + " world_state=" + str(place_trace_world_state_enabled))


func get_place_trace_max_lines() -> int:
	var env_value := OS.get_environment(PLACE_TRACE_MAX_LINES_ENV).strip_edges()
	if env_value.is_valid_int():
		return clampi(int(env_value), 1, 5000)
	return PLACE_TRACE_DEFAULT_MAX_LINES


func is_place_trace_enabled() -> bool:
	return place_trace_enabled and place_trace_lines_left > 0


func is_place_trace_world_state_payload(data: Dictionary) -> bool:
	if bool(data.get("_from_world_state", false)):
		return true
	if bool(data.get("from_world_state", false)):
		return true
	var payload_value: Variant = data.get("payload", null)
	if payload_value is Dictionary:
		var payload: Dictionary = payload_value
		if bool(payload.get("_from_world_state", false)) or bool(payload.get("from_world_state", false)):
			return true
	return false


func should_trace_authoritative_place_event(_event: String, data: Dictionary) -> bool:
	if place_trace_world_state_enabled:
		return true
	return not is_place_trace_world_state_payload(data)


func sanitize_place_trace_value(value):
	if value is Vector2i:
		var vector_i: Vector2i = value
		return {"x": vector_i.x, "y": vector_i.y}
	if value is Vector2:
		var vector: Vector2 = value
		return {"x": vector.x, "y": vector.y}
	if value is Dictionary:
		var source_dict: Dictionary = value
		var result := {}
		for raw_key in source_dict.keys():
			result[str(raw_key)] = sanitize_place_trace_value(source_dict.get(raw_key))
		return result
	if value is Array:
		var source_array: Array = value
		var result_array: Array = []
		for item in source_array:
			result_array.append(sanitize_place_trace_value(item))
		return result_array
	if value is Object:
		return str(value)
	return value


func get_place_trace_grid_from_data(data: Dictionary) -> Vector2i:
	var grid_value: Variant = data.get("grid_pos", null)
	if grid_value is Vector2i:
		return grid_value
	var target_value: Variant = data.get("target_tile", null)
	if target_value is Vector2i:
		return target_value
	if data.has("x") or data.has("target_x"):
		return Vector2i(
			int(data.get("x", data.get("target_x", 0))),
			int(data.get("y", data.get("target_y", 0)))
		)
	return NO_VARIANT_GRID_POS


func get_place_trace_selected_item() -> Dictionary:
	if world == null:
		return {}
	var selected_type := ""
	var selected_category := ""
	if "selected_item_type" in world:
		selected_type = str(world.get("selected_item_type"))
	if "selected_item_category" in world:
		selected_category = str(world.get("selected_item_category"))
	var count := -1
	if selected_type.strip_edges() != "" and selected_category.strip_edges() != "":
		count = get_place_item_count(selected_type, selected_category)
	return {
		"item_type": selected_type,
		"category": selected_category,
		"count": count
	}


func get_place_trace_fast_hold_state() -> Dictionary:
	var state := {"active": false}
	if world == null:
		return state
	if "fast_block_place_hold_active" in world:
		state["active"] = bool(world.get("fast_block_place_hold_active"))
	if "fast_block_place_hold_touch_index" in world:
		state["touch_index"] = int(world.get("fast_block_place_hold_touch_index"))
	if "fast_block_place_hold_timer" in world:
		state["timer"] = float(world.get("fast_block_place_hold_timer"))
	if "fast_block_place_last_grid" in world:
		state["last_grid"] = world.get("fast_block_place_last_grid")
	if "fast_block_place_last_item_type" in world:
		state["last_item_type"] = str(world.get("fast_block_place_last_item_type"))
	if "fast_block_place_last_item_category" in world:
		state["last_item_category"] = str(world.get("fast_block_place_last_item_category"))
	if "fast_block_place_grid_override_active" in world:
		state["grid_override_active"] = bool(world.get("fast_block_place_grid_override_active"))
	if "fast_block_place_grid_override" in world:
		state["grid_override"] = world.get("fast_block_place_grid_override")
	return state


func get_place_trace_cell_state(layer: String, grid_pos: Vector2i) -> Dictionary:
	var clean_layer := str(layer).strip_edges().to_lower()
	if clean_layer != "background":
		clean_layer = "foreground"
	var state := {
		"layer": clean_layer,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"exists": false
	}
	var block_value: Variant = {}
	if clean_layer == "background":
		if background_blocks.has(grid_pos):
			block_value = background_blocks.get(grid_pos, {})
	else:
		if world != null and world.blocks.has(grid_pos):
			block_value = world.blocks.get(grid_pos, {})
	if not (block_value is Dictionary):
		if str(block_value) != "":
			state["exists"] = true
			state["type"] = str(block_value)
		return state
	var block_data: Dictionary = block_value
	if block_data.is_empty():
		return state
	state["exists"] = true
	state["type"] = str(block_data.get("type", ""))
	state["item_id"] = block_data.get("item_id", 0)
	state["tilemap_only"] = bool(block_data.get("tilemap_only", false))
	state["predicted"] = bool(block_data.get("_predicted_authoritative_place", false))
	state["predicted_request_id"] = str(block_data.get("_predicted_request_id", ""))
	var node_value: Variant = block_data.get("node", null)
	state["node_valid"] = node_value is Node and is_instance_valid(node_value)
	return state


func trace_authoritative_place_event(event: String, data: Dictionary = {}) -> void:
	if not is_place_trace_enabled():
		return
	if not should_trace_authoritative_place_event(event, data):
		return
	place_trace_sequence += 1
	place_trace_lines_left -= 1
	var payload := {
		"seq": place_trace_sequence,
		"event": event,
		"ms": Time.get_ticks_msec(),
		"pending_predictions": predicted_authoritative_place_requests.size(),
		"lines_left": place_trace_lines_left,
		"world": str(world.current_world_name) if world != null else "",
		"selected": get_place_trace_selected_item(),
		"fast_hold": get_place_trace_fast_hold_state()
	}
	if world != null and world.player != null:
		payload["player_pos"] = world.player.global_position
	for raw_key in data.keys():
		payload[str(raw_key)] = data.get(raw_key)
	var trace_grid := get_place_trace_grid_from_data(data)
	if trace_grid != NO_VARIANT_GRID_POS:
		var trace_layer := str(data.get("layer", "foreground"))
		payload["cell"] = get_place_trace_cell_state(trace_layer, trace_grid)
	print("[PM_PLACE_TRACE] " + JSON.stringify(sanitize_place_trace_value(payload)))
	if place_trace_lines_left == 0:
		print("[PM_PLACE_TRACE] line budget exhausted; set " + PLACE_TRACE_MAX_LINES_ENV + " for a longer capture.")


func trace_place_attempt_blocked(reason: String, layer: String, grid_pos: Vector2i, block_type: String, category: String = "", extra_data: Dictionary = {}) -> void:
	var payload := extra_data.duplicate(true)
	payload["reason"] = reason
	payload["layer"] = layer
	payload["grid_pos"] = grid_pos
	payload["block_type"] = block_type
	payload["category"] = category
	trace_authoritative_place_event("place_attempt_blocked", payload)


func is_bulk_world_load_active() -> bool:
	if world == null:
		return false
	return bool(world.get_meta("world_bulk_load_in_progress", false))


func is_applying_network_world_update() -> bool:
	if world == null:
		return false
	if "applying_network_world_update" in world:
		return bool(world.applying_network_world_update)
	return false


func send_network_block_update(action: String, layer: String, grid_pos: Vector2i, block_type: String = "", extra_data: Dictionary = {}) -> bool:
	if is_applying_network_world_update():
		trace_authoritative_place_event("client_block_send_blocked", {
			"reason": "applying_network_world_update",
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"request_id": str(extra_data.get("request_id", ""))
		})
		return false
	if world == null:
		trace_authoritative_place_event("client_block_send_blocked", {
			"reason": "missing_world",
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"request_id": str(extra_data.get("request_id", ""))
		})
		return false
	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		trace_authoritative_place_event("client_block_send_blocked", {
			"reason": "missing_network_manager",
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"request_id": str(extra_data.get("request_id", ""))
		})
		return false
	if network.has_method("send_world_block_update"):
		var clean_extra_data := extra_data.duplicate(true)
		var atlas_item_id := get_atlas_item_id_for_block_type(block_type)
		# Do not send atlas item_id on client block actions. block_type is the
		# stable shared id; atlas ids require server-side atlas_items.json and can
		# make valid blocks fail validation when that file is not deployed.
		if str(action).to_lower() == "break" or str(action).to_lower() == "hit":
			debug_action_position_flow("break block request send", {
				"action": action,
				"layer": layer,
				"x": grid_pos.x,
				"y": grid_pos.y,
				"block_type": block_type,
				"item_id": atlas_item_id
			})
		trace_authoritative_place_event("client_block_send_start", {
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"item_id": atlas_item_id,
			"request_id": str(clean_extra_data.get("request_id", "")),
			"extra_data": clean_extra_data
		})
		var sent = bool(network.send_world_block_update(action, layer, grid_pos, block_type, world.current_world_name, clean_extra_data))
		if str(action).to_lower() == "break" or str(action).to_lower() == "hit":
			debug_action_position_flow("break block request end", {
				"action": action,
				"sent": sent,
				"layer": layer,
				"x": grid_pos.x,
				"y": grid_pos.y,
				"block_type": block_type,
				"item_id": atlas_item_id
		})
		trace_authoritative_place_event("client_block_send_result", {
			"action": action,
			"sent": sent,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"item_id": atlas_item_id,
			"request_id": str(clean_extra_data.get("request_id", ""))
		})
		if sent and str(action).strip_edges().to_lower() == "place" and world.has_method("play_player_place_animation"):
			world.play_player_place_animation()
		return sent
	trace_authoritative_place_event("client_block_send_blocked", {
		"reason": "network_missing_send_method",
		"action": action,
		"layer": layer,
		"grid_pos": grid_pos,
		"block_type": block_type,
		"request_id": str(extra_data.get("request_id", ""))
	})
	return false


func face_grid_for_block_punch(grid_pos: Vector2i) -> bool:
	if world != null and world.has_method("face_grid_position"):
		return bool(world.face_grid_position(grid_pos))

	return false


func face_world_position_for_punch(target_world_position: Vector2) -> bool:
	if world == null or world.player == null or not world.has_method("set_player_facing_direction"):
		return false

	var delta_x: float = target_world_position.x - world.player.global_position.x
	if absf(delta_x) <= 1.0:
		return false

	return bool(world.set_player_facing_direction(-1 if delta_x < 0.0 else 1, false))


func face_pointer_position_for_punch() -> bool:
	if world == null or not world.has_method("get_pointer_global_position"):
		return false

	return face_world_position_for_punch(world.get_pointer_global_position())


func face_current_horizontal_punch_input() -> bool:
	if world == null or not world.has_method("set_player_facing_direction"):
		return false

	var horizontal_input := 0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		horizontal_input -= 1
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		horizontal_input += 1

	if horizontal_input == 0:
		return false

	return bool(world.set_player_facing_direction(-1 if horizontal_input < 0 else 1, false))


func get_network_manager():
	if world == null:
		return null

	return world.get_node_or_null("/root/NetworkManager")


func should_use_server_authoritative_world_actions() -> bool:
	if world == null:
		return false
	if world.has_method("should_use_server_authoritative_world_actions"):
		if not bool(world.should_use_server_authoritative_world_actions()):
			return false
	else:
		return false
	var network = get_network_manager()
	if network == null:
		return false
	if network.has_method("is_server_session_authenticated"):
		return bool(network.is_server_session_authenticated())
	return bool(network.get("server_session_authenticated"))


func get_authoritative_break_key(layer: String, grid_pos: Vector2i) -> String:
	return layer + ":" + str(grid_pos.x) + ":" + str(grid_pos.y)


func get_authoritative_place_key(layer: String, grid_pos: Vector2i, block_type: String) -> String:
	return layer + ":" + str(grid_pos.x) + ":" + str(grid_pos.y) + ":" + block_type


func get_pending_authoritative_block_update_count() -> int:
	return predicted_authoritative_place_requests.size() + authoritative_break_request_keys.size()


func has_pending_authoritative_block_updates() -> bool:
	return get_pending_authoritative_block_update_count() > 0


func wait_for_pending_authoritative_block_updates(timeout_msec: int = 1800) -> bool:
	var tree := get_tree()
	if tree == null:
		return not has_pending_authoritative_block_updates()

	var start_msec := Time.get_ticks_msec()
	var timeout := maxi(0, timeout_msec)
	while has_pending_authoritative_block_updates():
		cleanup_expired_authoritative_place_predictions()
		if Time.get_ticks_msec() - start_msec >= timeout:
			break
		await tree.process_frame

	return not has_pending_authoritative_block_updates()


func has_recent_authoritative_place_request(key: String) -> bool:
	var now = Time.get_ticks_msec()
	var last_sent = int(authoritative_place_request_times.get(key, 0))
	return last_sent > 0 and now - last_sent < AUTHORITATIVE_REQUEST_REPEAT_MS


func has_recent_authoritative_place_send() -> bool:
	var now := Time.get_ticks_msec()
	return authoritative_place_last_request_ms > 0 and now - authoritative_place_last_request_ms < AUTHORITATIVE_PLACE_GLOBAL_REPEAT_MS


func mark_authoritative_place_request(key: String):
	authoritative_place_request_times[key] = Time.get_ticks_msec()


func mark_authoritative_place_send():
	authoritative_place_last_request_ms = Time.get_ticks_msec()


func make_authoritative_place_request_id(layer: String, grid_pos: Vector2i, block_type: String) -> String:
	predicted_authoritative_place_sequence += 1
	var clean_layer := layer.strip_edges().to_lower()
	var clean_block := block_type.strip_edges().to_lower()
	return "place_%s_%s_%d_%d_%d_%d" % [clean_layer, clean_block, grid_pos.x, grid_pos.y, Time.get_ticks_msec(), predicted_authoritative_place_sequence]


func get_request_id_from_block_payload(data: Dictionary) -> String:
	for key in ["request_id", "action_id", "client_action_id"]:
		var value := str(data.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func get_predicted_authoritative_place_request_key(data: Dictionary, allow_cell_fallback: bool = false) -> String:
	var request_id := get_request_id_from_block_payload(data)
	if request_id != "" and predicted_authoritative_place_requests.has(request_id):
		return request_id
	if not allow_cell_fallback:
		return ""

	var layer := str(data.get("layer", "foreground")).strip_edges().to_lower()
	if layer != "background":
		layer = "foreground"
	var grid_pos := Vector2i(
		int(data.get("x", data.get("target_x", 0))),
		int(data.get("y", data.get("target_y", 0)))
	)
	var block_type := str(data.get("block_type", data.get("item_id", ""))).strip_edges().to_lower()

	for raw_request_id in predicted_authoritative_place_requests.keys():
		var pending_value: Variant = predicted_authoritative_place_requests.get(raw_request_id, {})
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value
		if str(pending.get("layer", "foreground")) != layer:
			continue
		var pending_grid: Vector2i = pending.get("grid_pos", world.INVALID_GRID_POS if world != null else Vector2i(-999999, -999999))
		if pending_grid != grid_pos:
			continue
		if block_type != "" and str(pending.get("block_type", "")).strip_edges().to_lower() != block_type:
			continue
		return str(raw_request_id)

	return ""


func get_authoritative_place_prediction_rejection_reason(block_type: String, layer: String) -> String:
	if world == null:
		return "missing_world"
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer != "foreground" and clean_layer != "background":
		return "invalid_layer"

	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return "missing_block_type"
	if clean_type == WATER_BLOCK_TYPE:
		return "water_uses_bucket_flow"

	if is_world_lock_block_type(clean_type) or is_area_lock_block_type(clean_type):
		return "lock_state_must_be_confirmed"

	var item_data := get_block_item_data(clean_type)
	if item_data.is_empty():
		return "missing_item_definition"
	if not bool(item_data.get("placeable", true)):
		return "item_not_placeable"
	if item_data.has("client_place_prediction") and not bool(item_data.get("client_place_prediction", true)):
		return "item_opted_out"

	var declared_layer := str(item_data.get("place_layer", item_data.get("layer", ""))).strip_edges().to_lower()
	if declared_layer == "":
		declared_layer = "background" if bool(item_data.get("background_block", false)) else "foreground"
	if declared_layer != clean_layer:
		return "layer_mismatch"

	return ""


func should_predict_authoritative_place(block_type: String, layer: String) -> bool:
	if world == null:
		return false
	if not should_use_server_authoritative_world_actions():
		return false

	# This predicts only the reversible local visual/collision. The server still
	# validates ownership, uniqueness, inventory, interaction state, and commits
	# PostgreSQL before the authoritative placement is confirmed.
	return get_authoritative_place_prediction_rejection_reason(block_type, layer) == ""


func mark_predicted_authoritative_place_visual(layer: String, grid_pos: Vector2i, request_id: String) -> void:
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer == "background":
		if not background_blocks.has(grid_pos):
			return
		var background_value: Variant = background_blocks.get(grid_pos, {})
		if background_value is Dictionary:
			var background_data: Dictionary = background_value
			background_data["_predicted_authoritative_place"] = true
			background_data["_predicted_request_id"] = request_id
			background_blocks[grid_pos] = background_data
		return

	if world == null or not world.blocks.has(grid_pos):
		return
	var block_value: Variant = world.blocks.get(grid_pos, {})
	if block_value is Dictionary:
		var block_data: Dictionary = block_value
		block_data["_predicted_authoritative_place"] = true
		block_data["_predicted_request_id"] = request_id
		world.blocks[grid_pos] = block_data


func clear_predicted_authoritative_place_visual_marker(layer: String, grid_pos: Vector2i, request_id: String = "") -> void:
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer == "background":
		if not background_blocks.has(grid_pos):
			return
		var background_value: Variant = background_blocks.get(grid_pos, {})
		if background_value is Dictionary:
			var background_data: Dictionary = background_value
			if request_id == "" or str(background_data.get("_predicted_request_id", "")) == request_id:
				background_data.erase("_predicted_authoritative_place")
				background_data.erase("_predicted_request_id")
				background_blocks[grid_pos] = background_data
		return

	if world == null or not world.blocks.has(grid_pos):
		return
	var block_value: Variant = world.blocks.get(grid_pos, {})
	if block_value is Dictionary:
		var block_data: Dictionary = block_value
		if request_id == "" or str(block_data.get("_predicted_request_id", "")) == request_id:
			block_data.erase("_predicted_authoritative_place")
			block_data.erase("_predicted_request_id")
			world.blocks[grid_pos] = block_data


func has_predicted_authoritative_place_visual_marker(layer: String, grid_pos: Vector2i, request_id: String) -> bool:
	var clean_layer := layer.strip_edges().to_lower()
	var block_value: Variant = {}
	if clean_layer == "background":
		block_value = background_blocks.get(grid_pos, {})
	elif world != null:
		block_value = world.blocks.get(grid_pos, {})
	if not (block_value is Dictionary):
		return false
	var block_data: Dictionary = block_value
	return bool(block_data.get("_predicted_authoritative_place", false)) and str(block_data.get("_predicted_request_id", "")) == request_id


func refresh_place_item_ui(item_type: String, category: String) -> void:
	if world == null:
		return
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(item_type, category)
	else:
		world.update_all_ui()


func set_place_item_count(item_type: String, category: String, count: int) -> void:
	if world == null:
		return
	var clean_item := item_type.strip_edges()
	var clean_category := category.strip_edges().to_lower()
	var safe_count := maxi(0, int(count))
	if world.has_method("clamp_item_stack_count"):
		safe_count = int(world.clamp_item_stack_count(clean_item, clean_category, safe_count))
	match clean_category:
		"block":
			world.inventory[clean_item] = safe_count
		"seed":
			world.seed_inventory[clean_item] = safe_count
		"lure":
			world.lure_inventory[clean_item] = safe_count
		"material":
			world.material_inventory[clean_item] = safe_count


func spend_predicted_place_inventory(item_type: String, category: String, amount: int = 1) -> bool:
	var current_count := get_place_item_count(item_type, category)
	if current_count < amount:
		return false
	set_place_item_count(item_type, category, current_count - amount)
	refresh_place_item_ui(item_type, category)
	return true


func restore_predicted_place_inventory(item_type: String, category: String, amount: int = 1) -> void:
	var current_count := get_place_item_count(item_type, category)
	set_place_item_count(item_type, category, current_count + amount)
	refresh_place_item_ui(item_type, category)
	restore_selected_place_item_if_auto_switched(item_type, category)


func get_pending_authoritative_place_reserved_count(item_type: String, category: String) -> int:
	var clean_item := str(item_type).strip_edges().to_lower()
	var clean_category := str(category).strip_edges().to_lower()
	if clean_item == "" or clean_category == "":
		return 0

	var reserved := 0
	for raw_request_id in predicted_authoritative_place_requests.keys():
		var pending_value: Variant = predicted_authoritative_place_requests.get(raw_request_id, {})
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value
		if str(pending.get("block_type", "")).strip_edges().to_lower() != clean_item:
			continue
		if str(pending.get("category", "")).strip_edges().to_lower() != clean_category:
			continue
		reserved += maxi(0, int(pending.get("reserved_amount", pending.get("spent_amount", 0))))
	return reserved


func get_available_place_item_count_for_prediction(item_type: String, category: String) -> int:
	return maxi(0, get_place_item_count(item_type, category) - get_pending_authoritative_place_reserved_count(item_type, category))


func apply_predicted_authoritative_place(request_id: String, layer: String, grid_pos: Vector2i, block_type: String, category: String) -> bool:
	if world == null:
		trace_authoritative_place_event("prediction_skipped", {
			"reason": "missing_world",
			"request_id": request_id,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"category": category
		})
		return false
	var clean_request := request_id.strip_edges()
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer != "background":
		clean_layer = "foreground"
	var clean_block := block_type.strip_edges().to_lower()
	var clean_category := category.strip_edges().to_lower()
	if clean_request == "" or clean_block == "" or clean_category == "":
		trace_authoritative_place_event("prediction_skipped", {
			"reason": "missing_prediction_identity",
			"request_id": clean_request,
			"layer": clean_layer,
			"grid_pos": grid_pos,
			"block_type": clean_block,
			"category": clean_category
		})
		return false
	if predicted_authoritative_place_requests.has(clean_request):
		trace_authoritative_place_event("prediction_skipped", {
			"reason": "duplicate_request_id",
			"request_id": clean_request,
			"layer": clean_layer,
			"grid_pos": grid_pos,
			"block_type": clean_block,
			"category": clean_category
		})
		return false
	if not should_predict_authoritative_place(clean_block, clean_layer):
		var prediction_policy_reason := get_authoritative_place_prediction_rejection_reason(clean_block, clean_layer)
		if prediction_policy_reason == "":
			prediction_policy_reason = "authoritative_session_unavailable"
		trace_authoritative_place_event("prediction_skipped", {
			"reason": "block_type_not_predictable",
			"prediction_policy_reason": prediction_policy_reason,
			"request_id": clean_request,
			"layer": clean_layer,
			"grid_pos": grid_pos,
			"block_type": clean_block,
			"category": clean_category
		})
		return false
	if clean_layer == "background":
		if background_blocks.has(grid_pos):
			trace_authoritative_place_event("prediction_skipped", {
				"reason": "background_cell_occupied",
				"request_id": clean_request,
				"layer": clean_layer,
				"grid_pos": grid_pos,
				"block_type": clean_block,
				"category": clean_category
			})
			return false
	else:
		if world.blocks.has(grid_pos):
			trace_authoritative_place_event("prediction_skipped", {
				"reason": "foreground_cell_occupied",
				"request_id": clean_request,
				"layer": clean_layer,
				"grid_pos": grid_pos,
				"block_type": clean_block,
				"category": clean_category
			})
			return false

	if get_available_place_item_count_for_prediction(clean_block, clean_category) <= 0:
		trace_authoritative_place_event("prediction_skipped", {
			"reason": "no_available_count_after_reservations",
			"request_id": clean_request,
			"layer": clean_layer,
			"grid_pos": grid_pos,
			"block_type": clean_block,
			"category": clean_category,
			"inventory_count": get_place_item_count(clean_block, clean_category),
			"reserved_count": get_pending_authoritative_place_reserved_count(clean_block, clean_category)
		})
		return false

	predicted_authoritative_place_requests[clean_request] = {
		"request_id": clean_request,
		"world": str(world.current_world_name).strip_edges().to_upper(),
		"layer": clean_layer,
		"grid_pos": grid_pos,
		"block_type": clean_block,
		"category": clean_category,
		"reserved_amount": 1,
		"spent_amount": 0,
		"created_at_ms": Time.get_ticks_msec(),
		"last_reconcile_request_ms": 0,
		"reconcile_attempts": 0
	}

	if clean_layer == "background":
		create_background_block(grid_pos, clean_block)
		if not background_blocks.has(grid_pos):
			trace_authoritative_place_event("prediction_failed_after_create", {
				"reason": "background_create_did_not_persist",
				"request_id": clean_request,
				"layer": clean_layer,
				"grid_pos": grid_pos,
				"block_type": clean_block,
				"category": clean_category
			})
			predicted_authoritative_place_requests.erase(clean_request)
			return false
	else:
		create_block(grid_pos, clean_block)
		if not world.blocks.has(grid_pos):
			trace_authoritative_place_event("prediction_failed_after_create", {
				"reason": "foreground_create_did_not_persist",
				"request_id": clean_request,
				"layer": clean_layer,
				"grid_pos": grid_pos,
				"block_type": clean_block,
				"category": clean_category
			})
			predicted_authoritative_place_requests.erase(clean_request)
			return false

	mark_predicted_authoritative_place_visual(clean_layer, grid_pos, clean_request)
	trace_authoritative_place_event("prediction_applied", {
		"request_id": clean_request,
		"layer": clean_layer,
		"grid_pos": grid_pos,
		"block_type": clean_block,
		"category": clean_category,
		"inventory_count": get_place_item_count(clean_block, clean_category),
		"reserved_count": get_pending_authoritative_place_reserved_count(clean_block, clean_category)
	})
	spawn_block_place_particles(grid_pos, clean_block, clean_layer)
	if world.has_method("play_sound_place"):
		world.play_sound_place(get_block_sound_position(grid_pos))
	if clean_layer == "foreground" and world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()
	return true


func confirm_predicted_authoritative_place(data: Dictionary) -> bool:
	var action := str(data.get("action", "")).strip_edges().to_lower()
	if action != "place":
		return false
	var request_key := get_predicted_authoritative_place_request_key(data, false)
	if request_key == "" or not predicted_authoritative_place_requests.has(request_key):
		trace_authoritative_place_event("prediction_confirm_unmatched", {
			"reason": "no_matching_pending_prediction",
			"request_id": get_request_id_from_block_payload(data),
			"action": action,
			"layer": str(data.get("layer", "foreground")),
			"x": int(data.get("x", data.get("target_x", 0))),
			"y": int(data.get("y", data.get("target_y", 0))),
			"block_type": str(data.get("block_type", data.get("item_id", ""))),
			"payload": data
		})
		return false
	var pending_value: Variant = predicted_authoritative_place_requests.get(request_key, {})
	predicted_authoritative_place_requests.erase(request_key)
	if pending_value is Dictionary:
		var pending: Dictionary = pending_value
		var layer := str(pending.get("layer", "foreground"))
		var grid_pos: Vector2i = pending.get("grid_pos", Vector2i.ZERO)
		var block_type := str(pending.get("block_type", ""))
		var age_ms := Time.get_ticks_msec() - int(pending.get("created_at_ms", Time.get_ticks_msec()))
		clear_predicted_authoritative_place_visual_marker(layer, grid_pos, request_key)
		authoritative_place_request_times.erase(get_authoritative_place_key(layer, grid_pos, block_type))
		trace_authoritative_place_event("prediction_confirmed", {
			"request_id": request_key,
			"age_ms": age_ms,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"server_block_type": str(data.get("block_type", "")),
			"payload": data
		})
	return true


func rollback_predicted_authoritative_place(data: Dictionary, allow_cell_fallback: bool = false) -> bool:
	var request_key := get_predicted_authoritative_place_request_key(data, allow_cell_fallback)
	if request_key == "" or not predicted_authoritative_place_requests.has(request_key):
		trace_authoritative_place_event("prediction_rollback_unmatched", {
			"reason": "no_matching_pending_prediction",
			"request_id": get_request_id_from_block_payload(data),
			"action": str(data.get("action", "")),
			"layer": str(data.get("layer", "foreground")),
			"x": int(data.get("x", data.get("target_x", 0))),
			"y": int(data.get("y", data.get("target_y", 0))),
			"block_type": str(data.get("block_type", data.get("item_id", ""))),
			"server_reason": str(data.get("reason", "")),
			"message": str(data.get("message", "")),
			"payload": data
		})
		return false

	var pending_value: Variant = predicted_authoritative_place_requests.get(request_key, {})
	predicted_authoritative_place_requests.erase(request_key)
	if not (pending_value is Dictionary):
		return false

	var pending: Dictionary = pending_value
	var layer := str(pending.get("layer", "foreground"))
	var grid_pos: Vector2i = pending.get("grid_pos", Vector2i.ZERO)
	var block_type := str(pending.get("block_type", ""))
	var category := str(pending.get("category", "block"))
	var spent_amount := maxi(0, int(pending.get("spent_amount", 0)))
	var age_ms := Time.get_ticks_msec() - int(pending.get("created_at_ms", Time.get_ticks_msec()))
	var had_predicted_visual := has_predicted_authoritative_place_visual_marker(layer, grid_pos, request_key)
	var cell_before := get_place_trace_cell_state(layer, grid_pos)

	if had_predicted_visual:
		if layer == "background":
			remove_background_block_without_drop(grid_pos)
		else:
			remove_block_without_drop(grid_pos)
	else:
		clear_predicted_authoritative_place_visual_marker(layer, grid_pos, request_key)

	if spent_amount > 0:
		restore_predicted_place_inventory(block_type, category, spent_amount)
	authoritative_place_request_times.erase(get_authoritative_place_key(layer, grid_pos, block_type))
	if world != null and world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()
	trace_authoritative_place_event("prediction_rolled_back", {
		"request_id": request_key,
		"age_ms": age_ms,
		"layer": layer,
		"grid_pos": grid_pos,
		"block_type": block_type,
		"category": category,
		"spent_amount": spent_amount,
		"had_predicted_visual": had_predicted_visual,
		"cell_before": cell_before,
		"server_reason": str(data.get("reason", "")),
		"message": str(data.get("message", "")),
		"payload": data
	})
	return true


func request_authoritative_place_reconciliation(request_id: String) -> bool:
	var clean_request := request_id.strip_edges()
	if clean_request == "" or not predicted_authoritative_place_requests.has(clean_request):
		return false
	var pending_value: Variant = predicted_authoritative_place_requests.get(clean_request, {})
	if not (pending_value is Dictionary):
		predicted_authoritative_place_requests.erase(clean_request)
		return false
	var pending: Dictionary = pending_value
	var network = get_network_manager()
	if network == null or not network.has_method("send_world_block_reconcile_request"):
		return false
	var grid_pos: Vector2i = pending.get("grid_pos", NO_VARIANT_GRID_POS)
	if grid_pos == NO_VARIANT_GRID_POS:
		predicted_authoritative_place_requests.erase(clean_request)
		return false
	var sent := bool(network.send_world_block_reconcile_request(
		clean_request,
		"place",
		str(pending.get("layer", "foreground")),
		grid_pos,
		str(pending.get("block_type", "")),
		str(pending.get("world", world.current_world_name if world != null else ""))
	))
	var now_ms := Time.get_ticks_msec()
	pending["last_reconcile_request_ms"] = now_ms
	if sent:
		pending["reconcile_attempts"] = int(pending.get("reconcile_attempts", 0)) + 1
		trace_authoritative_place_event("prediction_reconcile_requested", {
			"request_id": clean_request,
			"age_ms": now_ms - int(pending.get("created_at_ms", now_ms)),
			"attempt": int(pending.get("reconcile_attempts", 0)),
			"layer": str(pending.get("layer", "foreground")),
			"grid_pos": grid_pos,
			"block_type": str(pending.get("block_type", ""))
		})
	predicted_authoritative_place_requests[clean_request] = pending
	return sent


func cleanup_expired_authoritative_place_predictions() -> void:
	if predicted_authoritative_place_requests.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	var malformed_requests: Array = []
	var reconcile_requests: Array = []
	for request_id in predicted_authoritative_place_requests.keys():
		var pending_value: Variant = predicted_authoritative_place_requests.get(request_id, {})
		if not (pending_value is Dictionary):
			malformed_requests.append(request_id)
			continue
		var pending: Dictionary = pending_value
		var created_at := int(pending.get("created_at_ms", now_ms))
		if now_ms - created_at > AUTHORITATIVE_PLACE_PREDICTION_TIMEOUT_MS:
			var last_reconcile_request_ms := int(pending.get("last_reconcile_request_ms", 0))
			if last_reconcile_request_ms > 0 and now_ms - last_reconcile_request_ms < AUTHORITATIVE_PLACE_RECONCILE_REPEAT_MS:
				continue
			trace_authoritative_place_event("prediction_reconcile_due", {
				"request_id": str(request_id),
				"age_ms": now_ms - created_at,
				"layer": str(pending.get("layer", "foreground")),
				"grid_pos": pending.get("grid_pos", NO_VARIANT_GRID_POS),
				"block_type": str(pending.get("block_type", "")),
				"category": str(pending.get("category", ""))
			})
			reconcile_requests.append(request_id)

	for request_id in malformed_requests:
		predicted_authoritative_place_requests.erase(request_id)
	for request_id in reconcile_requests:
		request_authoritative_place_reconciliation(str(request_id))


func handle_authoritative_place_reconcile(data: Dictionary) -> String:
	var request_id := get_request_id_from_block_payload(data)
	if request_id == "" or not predicted_authoritative_place_requests.has(request_id):
		return "unmatched"

	var pending_value: Variant = predicted_authoritative_place_requests.get(request_id, {})
	if not (pending_value is Dictionary):
		predicted_authoritative_place_requests.erase(request_id)
		return "unmatched"
	var pending: Dictionary = pending_value
	var pending_layer := str(pending.get("layer", "foreground")).strip_edges().to_lower()
	var pending_grid: Vector2i = pending.get("grid_pos", NO_VARIANT_GRID_POS)
	var pending_block := str(pending.get("block_type", "")).strip_edges().to_lower()
	var pending_world := str(pending.get("world", "")).strip_edges().to_upper()
	var response_world := str(data.get("world", data.get("current_world", ""))).strip_edges().to_upper()
	var response_layer := str(data.get("layer", "foreground")).strip_edges().to_lower()
	var response_grid := Vector2i(
		int(data.get("x", data.get("target_x", 0))),
		int(data.get("y", data.get("target_y", 0)))
	)
	if response_layer != "background":
		response_layer = "foreground"

	if (pending_world != "" and response_world != "" and pending_world != response_world) or response_layer != pending_layer or response_grid != pending_grid:
		trace_authoritative_place_event("prediction_reconcile_mismatch", {
			"request_id": request_id,
			"pending_world": pending_world,
			"response_world": response_world,
			"pending_layer": pending_layer,
			"response_layer": response_layer,
			"pending_grid": pending_grid,
			"response_grid": response_grid
		})
		return "mismatched"

	if bool(data.get("authoritative_pending", false)):
		pending["last_reconcile_request_ms"] = Time.get_ticks_msec()
		predicted_authoritative_place_requests[request_id] = pending
		return "pending"

	var authoritative_present := bool(data.get("authoritative_present", false))
	var authoritative_matches_request := bool(data.get("authoritative_matches_request", false))
	var authoritative_block := str(data.get("authoritative_block_type", "")).strip_edges().to_lower()
	if authoritative_present and authoritative_matches_request and authoritative_block == pending_block:
		confirm_predicted_authoritative_place({
			"action": "place",
			"request_id": request_id,
			"layer": pending_layer,
			"x": pending_grid.x,
			"y": pending_grid.y,
			"block_type": authoritative_block
		})
		return "confirmed"

	rollback_predicted_authoritative_place({
		"action": "place",
		"request_id": request_id,
		"layer": pending_layer,
		"x": pending_grid.x,
		"y": pending_grid.y,
		"block_type": pending_block,
		"reason": str(data.get("reason", "authoritative_reconcile")),
		"message": "Authoritative placement reconciliation did not confirm this request."
	}, false)
	return "rolled_back"


func reconcile_authoritative_place_predictions_after_snapshot(foreground_entries: Array, background_entries: Array) -> void:
	if predicted_authoritative_place_requests.is_empty() or world == null:
		return

	var snapshot_cells := {}
	for raw_entry in foreground_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var entry_grid := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		snapshot_cells["foreground:%d:%d" % [entry_grid.x, entry_grid.y]] = entry
	for raw_entry in background_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var entry_grid := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		snapshot_cells["background:%d:%d" % [entry_grid.x, entry_grid.y]] = entry

	var current_world := str(world.current_world_name).strip_edges().to_upper()
	var requests_to_remove: Array[String] = []
	var requests_to_reconcile: Array[String] = []
	for raw_request_id in predicted_authoritative_place_requests.keys():
		var request_id := str(raw_request_id)
		var pending_value: Variant = predicted_authoritative_place_requests.get(request_id, {})
		if not (pending_value is Dictionary):
			requests_to_remove.append(request_id)
			continue
		var pending: Dictionary = pending_value
		var pending_world := str(pending.get("world", "")).strip_edges().to_upper()
		var layer := str(pending.get("layer", "foreground")).strip_edges().to_lower()
		if layer != "background":
			layer = "foreground"
		var grid_pos: Vector2i = pending.get("grid_pos", NO_VARIANT_GRID_POS)
		var block_type := str(pending.get("block_type", "")).strip_edges().to_lower()
		if grid_pos == NO_VARIANT_GRID_POS or block_type == "" or (pending_world != "" and pending_world != current_world):
			requests_to_remove.append(request_id)
			continue

		var cell_key := "%s:%d:%d" % [layer, grid_pos.x, grid_pos.y]
		var authoritative_entry_value: Variant = snapshot_cells.get(cell_key, null)
		if authoritative_entry_value is Dictionary:
			var authoritative_entry: Dictionary = authoritative_entry_value
			var snapshot_request_id := str(authoritative_entry.get("placement_request_id", "")).strip_edges()
			var snapshot_block := str(authoritative_entry.get("block_type", authoritative_entry.get("type", ""))).strip_edges().to_lower()
			if snapshot_block == "":
				snapshot_block = ITEM_ATLAS_DB.resolve_item_key(authoritative_entry.get("item_id", authoritative_entry.get("id", ""))).strip_edges().to_lower()
			if snapshot_request_id == request_id and snapshot_block == block_type:
				confirm_predicted_authoritative_place({
					"action": "place",
					"request_id": request_id,
					"layer": layer,
					"x": grid_pos.x,
					"y": grid_pos.y,
					"block_type": snapshot_block
				})
				continue
		else:
			if layer == "background":
				create_background_block(grid_pos, block_type)
			else:
				create_block(grid_pos, block_type)
			mark_predicted_authoritative_place_visual(layer, grid_pos, request_id)

		requests_to_reconcile.append(request_id)

	for request_id in requests_to_remove:
		var pending_value: Variant = predicted_authoritative_place_requests.get(request_id, {})
		if pending_value is Dictionary:
			var pending: Dictionary = pending_value
			authoritative_place_request_times.erase(get_authoritative_place_key(
				str(pending.get("layer", "foreground")),
				pending.get("grid_pos", Vector2i.ZERO),
				str(pending.get("block_type", ""))
			))
		predicted_authoritative_place_requests.erase(request_id)
	for request_id in requests_to_reconcile:
		request_authoritative_place_reconciliation(request_id)


func should_server_create_break_drops() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func get_direct_break_inventory_return_item(block_type: String) -> String:
	if world == null or not ("item_database" in world):
		return ""

	var clean_block_type := str(block_type).strip_edges()
	var definition_value: Variant = world.item_database.get(clean_block_type, {})
	if not (definition_value is Dictionary):
		return ""

	var definition: Dictionary = definition_value
	if not bool(definition.get("break_return_to_inventory", false)):
		return ""

	var return_item_id := str(definition.get("break_return_item_id", clean_block_type)).strip_edges()
	if return_item_id == "" or not world.item_database.has(return_item_id):
		return ""
	return return_item_id


func can_receive_direct_break_inventory_return(item_type: String) -> bool:
	if world == null or item_type == "":
		return false
	var current_count: int = maxi(0, int(world.inventory.get(item_type, 0)))
	var stack_limit: int = int(world.get_stack_limit_for_item(item_type, "block"))
	return current_count < stack_limit


func return_broken_block_directly_to_inventory(item_type: String) -> bool:
	if not can_receive_direct_break_inventory_return(item_type):
		return false

	var added_amount := int(world.add_item_to_inventory_stack(world.inventory, item_type, "block", 1))
	if added_amount != 1:
		return false

	if world.has_method("save_player_data"):
		world.save_player_data()
	world.show_notification("Returned " + world.get_item_display_name(item_type, "block") + " to your inventory.")
	return true


func is_world_lock_block_type(block_type: String) -> bool:
	if world != null and world.has_method("is_world_lock_block_type"):
		return bool(world.is_world_lock_block_type(block_type))

	var clean_type := str(block_type).strip_edges().to_lower()
	return clean_type == "world_lock" or clean_type == "super_world_lock"


func is_area_lock_block_type(block_type: String) -> bool:
	if world != null and world.has_method("is_area_lock_block_type"):
		return bool(world.is_area_lock_block_type(block_type))

	var clean_type := str(block_type).strip_edges().to_lower()
	return clean_type == "small_lock" or clean_type == "medium_lock" or clean_type == "big_lock"


func get_area_lock_visual_modulation(block_type: String, grid_pos: Vector2i, background := false) -> Color:
	if background or grid_pos == NO_VARIANT_GRID_POS or not is_area_lock_block_type(block_type):
		return Color.WHITE
	if world == null or world.world_lock_manager == null:
		return AREA_LOCK_NO_ACCESS_MODULATE

	var manager: Node = world.world_lock_manager
	if not manager.has_method("get_area_lock_for_lock_position"):
		return AREA_LOCK_NO_ACCESS_MODULATE

	var area_lock: Dictionary = manager.get_area_lock_for_lock_position(grid_pos)
	if area_lock.is_empty():
		return AREA_LOCK_NO_ACCESS_MODULATE

	var current_player := ""
	if manager.has_method("get_current_player_name"):
		current_player = str(manager.get_current_player_name())

	var role := ""
	if manager.has_method("get_area_lock_player_role"):
		role = str(manager.get_area_lock_player_role(area_lock, current_player)).strip_edges().to_lower()

	if role == "owner":
		return AREA_LOCK_OWNER_MODULATE
	if role == "admin" or role == "builder":
		return AREA_LOCK_ACCESS_MODULATE
	if manager.has_method("can_current_player_manage_area_lock") and bool(manager.can_current_player_manage_area_lock(area_lock)):
		return AREA_LOCK_ACCESS_MODULATE
	if bool(area_lock.get("public_build", false)):
		return AREA_LOCK_ACCESS_MODULATE

	return AREA_LOCK_NO_ACCESS_MODULATE


func apply_area_lock_visual_modulation(visual: Sprite2D, block_type: String, grid_pos: Vector2i, background := false) -> void:
	if visual == null:
		return
	visual.modulate = get_area_lock_visual_modulation(block_type, grid_pos, background)


func is_waiting_for_server_sign_on() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions") and not bool(world.should_use_server_authoritative_world_actions()):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return true

	if network.has_method("can_send_authenticated_payload"):
		return not bool(network.can_send_authenticated_payload())

	if network.has_method("is_server_session_authenticated"):
		return not bool(network.is_server_session_authenticated())

	return true


func show_server_sign_on_notice():
	if world == null:
		return

	var now = Time.get_ticks_msec()
	if now - last_server_sign_on_notice_at < 1500:
		return

	last_server_sign_on_notice_at = now
	world.show_notification("Almost ready. Try again in a moment.")


func get_background_blocks_parent():
	if world == null:
		return null

	if world.has_node("BackgroundBlocks"):
		return world.get_node("BackgroundBlocks")

	return world


func is_background_block_type(block_type: String) -> bool:
	if world == null:
		return false

	if not world.item_database.has(block_type):
		return false

	var item_data = world.item_database[block_type]

	if bool(item_data.get("background_block", false)):
		return true

	if str(item_data.get("place_layer", "")) == "background":
		return true

	return false


func get_stable_variant_index(grid_pos: Vector2i, count: int, salt: int = 0) -> int:
	if count <= 1:
		return 0

	var value = int((grid_pos.x * 73856093) + (grid_pos.y * 19349663) + (salt * 83492791))
	return posmod(value, count)


func get_snow_storm_ice_block_type(grid_pos: Vector2i) -> String:
	var roll = get_stable_variant_index(grid_pos, 100, SNOW_STORM_ICE_VARIANT_SALT)
	if roll < 2:
		return "ice_fossil"
	if roll < 7:
		return "ice_treasure"
	return "ice_block"


func get_weighted_stable_variant_index(grid_pos: Vector2i, weights: Array, salt: int = 0) -> int:
	var total_weight := 0
	for weight in weights:
		total_weight += max(0, int(weight))

	if total_weight <= 0:
		return 0

	var roll = get_stable_variant_index(grid_pos, total_weight, salt)
	var running_total := 0
	for i in range(weights.size()):
		running_total += max(0, int(weights[i]))
		if roll < running_total:
			return i

	return max(0, weights.size() - 1)


func normalize_legacy_block_id(block_type: String) -> String:
	if block_type == "crafting_station_left":
		return "crafting_station"
	if block_type == "crafting_station_right":
		return ""
	if block_type == "wood_block":
		return "wood"
	if block_type == "pillar_top" or block_type == "pillar_middle" or block_type == "pillar_bottom":
		return "pillar"
	if block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold":
		return "vending_machine"
	if block_type == "vines":
		return "hanging_vine"
	if block_type == "ice_block_2":
		return "ice_treasure"
	if block_type == "tulip":
		return "sunflower"
	if block_type == "wooden_background":
		return "wooden_wallpaper"
	if block_type == "wooden_frame":
		return "wooden_window"
	if block_type == "dark_red_block":
		return "maroon_block"
	if block_type == "light_brown_block":
		return "dark_orange_block"
	if block_type == "gem_block":
		return "rainbow_block"
	if block_type == "shift_block":
		return "shifty_block"
	if block_type == "white_bg":
		return "white_wallpaper"
	if block_type == "grey_bg":
		return "grey_wallpaper"
	if block_type == "black_bg":
		return "black_wallpaper"
	if block_type == "red_bg":
		return "red_wallpaper"
	if block_type == "orange_bg":
		return "orange_wallpaper"
	if block_type == "yellow_bg":
		return "yellow_wallpaper"
	if block_type == "green_bg":
		return "green_wallpaper"
	if block_type == "aqua_bg":
		return "aqua_wallpaper"
	if block_type == "blue_bg":
		return "blue_wallpaper"
	if block_type == "purple_bg":
		return "purple_wallpaper"
	if block_type == "pink_bg":
		return "pink_wallpaper"
	if block_type == "brown_bg":
		return "brown_wallpaper"
	return block_type


func get_cached_visual_variant_texture(texture_path: String):
	if texture_path == "":
		return null

	if visual_variant_texture_cache.has(texture_path):
		return visual_variant_texture_cache[texture_path]

	if not ResourceLoader.exists(texture_path):
		visual_variant_texture_cache[texture_path] = null
		return null

	var texture = load(texture_path)
	visual_variant_texture_cache[texture_path] = texture
	return texture


func get_foreground_block_type_at(grid_pos: Vector2i) -> String:
	if world == null or not world.blocks.has(grid_pos):
		return ""

	return normalize_legacy_block_id(str(world.blocks[grid_pos].get("type", "")).strip_edges().to_lower())


func is_lower_water_layer_cell(grid_pos: Vector2i) -> bool:
	if grid_pos == NO_VARIANT_GRID_POS:
		return false
	var above_pos := Vector2i(grid_pos.x, grid_pos.y - 1)
	return get_foreground_block_type_at(above_pos).strip_edges().to_lower() == WATER_BLOCK_TYPE


func get_block_item_data(block_type: String) -> Dictionary:
	# Explicit int: world is untyped here, so .size() is Variant to the parser.
	var source_size: int = world.item_database.size() if world != null else -1
	if source_size != block_item_data_cache_source_size:
		block_item_data_cache.clear()
		block_item_data_cache_source_size = source_size
	var cached_item_data = block_item_data_cache.get(block_type)
	if cached_item_data is Dictionary:
		return cached_item_data

	var clean_type := normalize_legacy_block_id(str(block_type).strip_edges().to_lower())
	if world != null and world.item_database.has(clean_type):
		# Cache the live reference, exactly as the original returned it -- callers that mutate
		# the entry must still be mutating the database row itself.
		var item_data = world.item_database[clean_type]
		if item_data is Dictionary:
			block_item_data_cache[block_type] = item_data
		return item_data

	var atlas_item_id := ITEM_ATLAS_DB.get_item_id_for_key(clean_type)
	if atlas_item_id > 0:
		var atlas_entries := ITEM_ATLAS_DB.get_item_database_entries()
		if atlas_entries.has(clean_type):
			var atlas_item_data = atlas_entries[clean_type]
			if atlas_item_data is Dictionary:
				block_item_data_cache[block_type] = atlas_item_data
			return atlas_item_data

	return {}


func get_atlas_item_id_for_block_type(block_type: String) -> int:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return 0
	var item_data := get_block_item_data(clean_type)
	var explicit_id := int(item_data.get("atlas_item_id", 0))
	if explicit_id > 0:
		return explicit_id
	return ITEM_ATLAS_DB.get_item_id_for_key(clean_type)


# Read-only, memoized accessor for ITEM_ATLAS_DB.get_item(). See atlas_item_metadata_cache.
# NEVER mutate the returned dictionary -- callers share one instance. If a caller needs to
# mutate, it must call ITEM_ATLAS_DB.get_item() directly (which still deep-copies) or
# .duplicate() the result itself.
func _get_cached_atlas_item(atlas_item_id: int) -> Dictionary:
	var cached: Variant = atlas_item_metadata_cache.get(atlas_item_id)
	if cached is Dictionary:
		return cached as Dictionary
	var item := ITEM_ATLAS_DB.get_item(atlas_item_id)
	atlas_item_metadata_cache[atlas_item_id] = item
	return item


func get_block_tilemap_metadata(block_type: String, visual_block_type: String = "", grid_pos: Vector2i = NO_VARIANT_GRID_POS, background := false) -> Dictionary:
	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_visual_type == "":
		clean_visual_type = clean_type

	# When there is no variant grid position, get_stateful_block_atlas_data returns
	# an empty dictionary, so the result depends only on the (static) item database.
	# This is by far the hottest call shape during a world build -- the candidate
	# checks alone run it several times per tile, and each run deep-duplicates an
	# item dictionary via ITEM_ATLAS_DB.get_item. Memoize it per block type pair.
	var metadata_cache_key := ""
	var can_cache_metadata := grid_pos == NO_VARIANT_GRID_POS
	if can_cache_metadata:
		metadata_cache_key = clean_type + "|" + clean_visual_type + "|" + ("1" if background else "0")
		var cached_metadata: Variant = tilemap_metadata_cache.get(metadata_cache_key)
		if cached_metadata is Dictionary:
			# Return a copy: callers treat the result as their own to mutate.
			return (cached_metadata as Dictionary).duplicate()

	var item_data := get_block_item_data(clean_type)
	var visual_data := get_block_item_data(clean_visual_type)
	if visual_data.is_empty():
		visual_data = item_data

	var atlas_item_id := get_atlas_item_id_for_block_type(clean_visual_type)
	if atlas_item_id <= 0 and clean_visual_type != clean_type:
		atlas_item_id = get_atlas_item_id_for_block_type(clean_type)
	var atlas_item := _get_cached_atlas_item(atlas_item_id) if atlas_item_id > 0 else {}
	var atlas_item_visual_enabled := not atlas_item.is_empty() and bool(atlas_item.get("atlas_enabled", true))
	var stateful_atlas_data := get_stateful_block_atlas_data(clean_visual_type, grid_pos, background)
	if stateful_atlas_data.is_empty() and clean_visual_type != clean_type:
		stateful_atlas_data = get_stateful_block_atlas_data(clean_type, grid_pos, background)
	var has_atlas_coords := not stateful_atlas_data.is_empty() or atlas_item_visual_enabled or visual_data.has("atlas_coords") or item_data.has("atlas_coords")
	var atlas_coords := parse_block_vector2i(visual_data.get("atlas_coords", item_data.get("atlas_coords", Vector2i.ZERO)), Vector2i.ZERO)
	var source_id := int(visual_data.get("atlas_source_id", visual_data.get("source_id", item_data.get("atlas_source_id", item_data.get("source_id", 0)))))
	var alternative_tile := int(visual_data.get("alternative_tile", item_data.get("alternative_tile", 0)))
	if atlas_item_visual_enabled:
		atlas_coords = parse_block_vector2i(atlas_item.get("atlas_coords", atlas_coords), atlas_coords)
		source_id = int(atlas_item.get("source_id", source_id))
		alternative_tile = int(atlas_item.get("alternative_tile", alternative_tile))
	if not stateful_atlas_data.is_empty():
		atlas_coords = parse_block_vector2i(stateful_atlas_data.get("atlas_coords", atlas_coords), atlas_coords)
		source_id = int(stateful_atlas_data.get("source_id", source_id))
		alternative_tile = int(stateful_atlas_data.get("alternative_tile", alternative_tile))

	var collision_type := get_block_tilemap_collision_type(clean_type, item_data)
	var solid := bool(item_data.get("solid", collision_type == "full"))
	if collision_type != "full":
		solid = false

	var animated := bool(visual_data.get("animated", false)) or has_tilemap_animation_metadata(visual_data)
	var metadata := {
		"solid": solid,
		"atlas_coords": atlas_coords,
		"source_id": source_id,
		"alternative_tile": alternative_tile,
		"atlas_item_id": atlas_item_id,
		"has_atlas_coords": has_atlas_coords,
		"animated": animated,
		"collision_type": collision_type,
		"block_type": clean_type,
		"visual_block_type": clean_visual_type,
		"background": background,
		"grid_pos": grid_pos
	}
	if can_cache_metadata:
		tilemap_metadata_cache[metadata_cache_key] = metadata.duplicate()
	return metadata


func get_stateful_block_atlas_texture(block_type: String, visual_block_type: String, grid_pos: Vector2i, background := false) -> Texture2D:
	if grid_pos == NO_VARIANT_GRID_POS:
		return null

	var clean_block_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_visual_type == "":
		clean_visual_type = clean_block_type

	var atlas_data := get_stateful_block_atlas_data(clean_visual_type, grid_pos, background)
	if atlas_data.is_empty() and clean_visual_type != clean_block_type:
		atlas_data = get_stateful_block_atlas_data(clean_block_type, grid_pos, background)
	if atlas_data.is_empty():
		return null

	var metadata := get_block_tilemap_metadata(clean_block_type, clean_visual_type, grid_pos, background)
	return get_block_atlas_cell_texture(metadata)


func get_block_atlas_cell_texture(metadata: Dictionary) -> Texture2D:
	if not metadata_has_tilemap_atlas_coords(metadata):
		return null

	var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
	var atlas_item_id := int(metadata.get("atlas_item_id", 0))
	var source_id := int(metadata.get("source_id", 0))
	var source_texture: Texture2D = null
	var region_size := Vector2i(32, 32)
	var margins := Vector2i.ZERO
	var separation := Vector2i.ZERO

	if atlas_item_id > 0:
		var atlas_tile_set: TileSet = null
		if world != null and world.has_method("get_item_atlas_tile_set"):
			atlas_tile_set = world.get_item_atlas_tile_set()
		if atlas_tile_set != null and atlas_tile_set.has_source(source_id):
			var raw_source = atlas_tile_set.get_source(source_id)
			if raw_source is TileSetAtlasSource:
				var atlas_source := raw_source as TileSetAtlasSource
				source_texture = atlas_source.texture
				region_size = atlas_source.texture_region_size
				margins = atlas_source.margins
				separation = atlas_source.separation
				if region_size == Vector2i.ZERO:
					region_size = atlas_tile_set.tile_size

		if source_texture == null:
			var base_icon := ITEM_ATLAS_DB.get_item_icon(atlas_item_id, atlas_tile_set)
			if base_icon != null and base_icon.atlas != null:
				source_texture = base_icon.atlas
				region_size = Vector2i(roundi(base_icon.region.size.x), roundi(base_icon.region.size.y))
				var atlas_item := ITEM_ATLAS_DB.get_item(atlas_item_id)
				var base_coords := parse_block_vector2i(atlas_item.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
				margins = Vector2i(
					roundi(base_icon.region.position.x) - base_coords.x * region_size.x,
					roundi(base_icon.region.position.y) - base_coords.y * region_size.y
				)

	if source_texture == null:
		# Items that carry dynamic atlas_coords (weighted variants, state textures,
		# vertical variants, ...) but aren't registered in the TileSet atlas manifest
		# (atlas_items.json) still resolve straight against the shared blocks atlas
		# image, at the standard 32x32 grid, with no margins/separation.
		source_texture = AtlasTextureFactory.load_texture_path(DEFAULT_BLOCKS_ATLAS_PATH)
		region_size = Vector2i(32, 32)
		margins = Vector2i.ZERO
		separation = Vector2i.ZERO

	if source_texture == null or region_size.x <= 0 or region_size.y <= 0:
		return null

	var cache_key := "%s|%d|%s|%s|%s|%s" % [
		str(source_texture.get_instance_id()),
		source_id,
		str(atlas_coords),
		str(region_size),
		str(margins),
		str(separation)
	]
	if atlas_variant_texture_cache.has(cache_key):
		var cached_texture = atlas_variant_texture_cache.get(cache_key)
		if cached_texture is Texture2D:
			return cached_texture

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = source_texture
	var step := region_size + separation
	atlas_texture.region = Rect2(
		Vector2(
			float(margins.x + atlas_coords.x * step.x),
			float(margins.y + atlas_coords.y * step.y)
		),
		Vector2(float(region_size.x), float(region_size.y))
	)
	atlas_texture.filter_clip = true
	atlas_variant_texture_cache[cache_key] = atlas_texture
	return atlas_texture


func get_block_tilemap_collision_type(block_type: String, item_data: Dictionary = {}) -> String:
	var clean_type := str(block_type).strip_edges().to_lower()
	if is_bedrock_block_type(clean_type):
		return "full"
	if clean_type == "" or item_data.is_empty():
		return "none"

	var explicit_collision_type := str(item_data.get("collision_type", "")).strip_edges().to_lower()
	if explicit_collision_type != "":
		return explicit_collision_type
	if item_data.has("solid"):
		return "full" if bool(item_data.get("solid", false)) else "none"

	if clean_type == "water":
		return "none"
	if is_background_block_type(clean_type):
		return "none"
	if is_non_collideable_block(clean_type):
		return "none"
	if is_platform_collision_block_type(clean_type):
		return "none"
	if block_requires_full_area_clear(clean_type) or block_occupies_collision_area(clean_type):
		return "custom"

	var default_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var collision_size := parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset := parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)

	return "full" if collision_size == default_size and collision_offset == Vector2.ZERO else "custom"


func has_tilemap_animation_metadata(item_data: Dictionary) -> bool:
	if bool(item_data.get("animated", false)) or bool(item_data.get("tileset_animation", false)):
		return true
	var animation_atlas_coords = item_data.get("animation_atlas_coords", [])
	if animation_atlas_coords is Array and animation_atlas_coords.size() > 1:
		return true
	var animation_frames = item_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 1:
		return true
	return item_data.has("running_animation_frames") or has_springboard_animation_metadata(item_data) or item_data.has("toggle_textures") or item_data.has("entrance_frames")


func is_animation_atlas_frame_spec(value) -> bool:
	if value is Vector2i or value is Vector2:
		return true
	if value is Dictionary:
		return value.has("x") and value.has("y")
	if value is Array and value.size() >= 2:
		return true
	if value is String:
		var text := str(value).strip_edges()
		if text.begins_with("res://") or text.begins_with("user://"):
			return false
		var parts := text.split(",", false)
		return parts.size() >= 2 and str(parts[0]).strip_edges().is_valid_int() and str(parts[1]).strip_edges().is_valid_int()
	return false


func parse_animation_atlas_frames(raw_frames) -> Array[Vector2i]:
	var frames: Array[Vector2i] = []
	if not (raw_frames is Array):
		return frames
	for raw_frame in raw_frames:
		if not is_animation_atlas_frame_spec(raw_frame):
			continue
		frames.append(parse_block_vector2i(raw_frame, Vector2i.ZERO))
	return frames


func get_tilemap_animation_atlas_frames(block_type: String, visual_block_type: String) -> Array[Vector2i]:
	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if world == null or clean_type == "" or clean_visual_type == "":
		return []

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	if item_data.is_empty():
		return []

	var frames := parse_animation_atlas_frames(item_data.get("animation_atlas_coords", []))
	if frames.size() > 1:
		return frames
	return parse_animation_atlas_frames(item_data.get("animation_frames", []))


func metadata_has_tilemap_atlas_coords(metadata: Dictionary) -> bool:
	return bool(metadata.get("has_atlas_coords", false))


func metadata_has_visual_tileset_animation(metadata: Dictionary) -> bool:
	if not metadata_has_tilemap_atlas_coords(metadata):
		return false
	var renderer = ensure_tilemap_renderer()
	if renderer == null or not renderer.has_method("has_visual_tile_animation"):
		return false
	var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
	return bool(renderer.has_visual_tile_animation(atlas_coords))


func metadata_should_prefer_texture_visual_cell(metadata: Dictionary, texture: Texture2D) -> bool:
	if texture == null:
		return false

	var block_type := str(metadata.get("block_type", "")).strip_edges().to_lower()
	var visual_block_type := str(metadata.get("visual_block_type", block_type)).strip_edges().to_lower()
	var grid_pos := parse_block_vector2i(metadata.get("grid_pos", NO_VARIANT_GRID_POS), NO_VARIANT_GRID_POS)
	var background := bool(metadata.get("background", false))

	if block_type == "water":
		return true
	if block_type == BARN_BLOCK_TYPE or visual_block_type == BARN_BLOCK_TYPE:
		return false
	if grid_pos == NO_VARIANT_GRID_POS or visual_block_type == "":
		return false
	if get_visual_block_variant(visual_block_type, grid_pos, background) != "":
		return true
	if get_stateful_block_texture_path(visual_block_type, grid_pos, background) != "":
		return true
	if not get_stateful_block_atlas_data(visual_block_type, grid_pos, background).is_empty():
		return false
	if visual_block_type != block_type and not get_stateful_block_atlas_data(block_type, grid_pos, background).is_empty():
		return false
	return false


func sync_renderer_block_visual_cell(renderer, grid_pos: Vector2i, texture: Texture2D, metadata: Dictionary, background := false, texture_shadow := false, cell_source := "coordinate") -> bool:
	if renderer == null:
		return false
	var block_type := str(metadata.get("block_type", "")).strip_edges().to_lower()
	var visual_block_type := str(metadata.get("visual_block_type", block_type)).strip_edges().to_lower()
	var is_barn_visual := block_type == BARN_BLOCK_TYPE or visual_block_type == BARN_BLOCK_TYPE
	if metadata_should_prefer_texture_visual_cell(metadata, texture) and renderer.has_method("set_block_cell"):
		if bool(renderer.set_block_cell(grid_pos, texture, background, texture_shadow, cell_source)):
			return true
	if metadata_has_tilemap_atlas_coords(metadata) and renderer.has_method("set_item_atlas_cell"):
		var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		var source_id := int(metadata.get("source_id", 0))
		var alternative_tile := int(metadata.get("alternative_tile", 0))
		if bool(renderer.set_item_atlas_cell(grid_pos, source_id, atlas_coords, background, texture_shadow, cell_source, alternative_tile)):
			return true
	if metadata_has_tilemap_atlas_coords(metadata) and renderer.has_method("set_block_atlas_cell"):
		var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		if bool(renderer.set_block_atlas_cell(grid_pos, atlas_coords, background, texture_shadow, cell_source)):
			return true
	if texture != null and not is_barn_visual and renderer.has_method("set_block_cell"):
		return bool(renderer.set_block_cell(grid_pos, texture, background, texture_shadow, cell_source))
	return false


func sync_renderer_feature_visual_cell(renderer, grid_pos: Vector2i, texture: Texture2D, metadata: Dictionary, cell_source := "coordinate") -> bool:
	if renderer == null:
		return false
	if metadata_has_tilemap_atlas_coords(metadata) and renderer.has_method("set_foreground_feature_atlas_cell"):
		var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		if bool(renderer.set_foreground_feature_atlas_cell(grid_pos, atlas_coords, cell_source)):
			return true
	if texture != null and renderer.has_method("set_foreground_feature_cell"):
		return bool(renderer.set_foreground_feature_cell(grid_pos, texture, cell_source))
	return false


func sync_renderer_over_player_visual_cell(renderer, grid_pos: Vector2i, texture: Texture2D, metadata: Dictionary, cell_source := "coordinate") -> bool:
	if renderer == null:
		return false
	if metadata_has_tilemap_atlas_coords(metadata) and renderer.has_method("set_foreground_over_player_atlas_cell"):
		var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		if bool(renderer.set_foreground_over_player_atlas_cell(grid_pos, atlas_coords, cell_source)):
			return true
	if texture != null and renderer.has_method("set_foreground_over_player_cell"):
		return bool(renderer.set_foreground_over_player_cell(grid_pos, texture, cell_source))
	return false


func sync_renderer_water_visual_cell(renderer, grid_pos: Vector2i, texture: Texture2D, metadata: Dictionary, cell_source := "coordinate") -> bool:
	if renderer == null:
		return false
	var has_atlas_coords := metadata_has_tilemap_atlas_coords(metadata)
	var atlas_coords := parse_block_vector2i(metadata.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
	var alternative_tile := int(metadata.get("alternative_tile", 0))
	if is_lower_water_layer_cell(grid_pos) and has_atlas_coords and renderer.has_method("set_water_atlas_cell"):
		if bool(renderer.set_water_atlas_cell(grid_pos, atlas_coords, cell_source, alternative_tile)):
			return true
	if has_atlas_coords \
		and renderer.has_method("has_visual_tile_animation") \
		and bool(renderer.has_visual_tile_animation(atlas_coords, alternative_tile)) \
		and renderer.has_method("set_water_atlas_cell"):
		if bool(renderer.set_water_atlas_cell(grid_pos, atlas_coords, cell_source, alternative_tile)):
			return true
	if texture != null and renderer.has_method("set_water_cell"):
		if bool(renderer.set_water_cell(grid_pos, texture, cell_source)):
			return true
	if has_atlas_coords and renderer.has_method("set_water_atlas_cell"):
		return bool(renderer.set_water_atlas_cell(grid_pos, atlas_coords, cell_source, alternative_tile))
	return false


func get_world_lock_access_texture_path(block_type: String, grid_pos: Vector2i) -> String:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return ""

	var clean_type := str(block_type).strip_edges().to_lower()
	if not is_world_lock_block_type(clean_type):
		return ""

	if world.world_lock_manager == null:
		return ""

	var manager = world.world_lock_manager
	if "is_locked" in manager and not bool(manager.is_locked):
		return ""

	if "lock_grid_pos" in manager and manager.lock_grid_pos is Vector2i:
		if manager.lock_grid_pos != grid_pos:
			return ""

	var has_access := false
	if manager.has_method("is_current_player_owner_or_access"):
		has_access = bool(manager.is_current_player_owner_or_access())

	var item_data := get_block_item_data(clean_type)
	if item_data.is_empty():
		return ""

	var texture_key := "world_lock_access_texture" if has_access else "world_lock_no_access_texture"
	return str(item_data.get(texture_key, item_data.get("texture", ""))).strip_edges()


func is_bedrock_block_type(block_type: String) -> bool:
	return block_type.strip_edges().to_lower() == "bedrock"


func is_platform_collision_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("platform_collision", false))


func is_tilemap_platform_collision_block(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false
	if not is_platform_collision_block_type(clean_type):
		return false
	if is_triggered_springboard_animation_block(clean_type):
		return is_tilemap_trigger_collision_block(clean_type)
	if block_requires_full_area_clear(clean_type):
		return false
	if block_occupies_collision_area(clean_type):
		return false
	return true


func is_tilemap_trigger_collision_block(block_type: String) -> bool:
	if world == null:
		return false

	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or not world.item_database.has(clean_type):
		return false
	if not is_triggered_springboard_animation_block(clean_type):
		return false
	if is_background_block_type(clean_type):
		return false
	if is_non_collideable_block(clean_type):
		return false
	if is_platform_collision_block_type(clean_type):
		return false
	if is_world_lock_block_type(clean_type):
		return false
	if is_wooden_entrance_block_type(clean_type):
		return false
	if is_entrance_gate_block_type(clean_type):
		return false
	if is_door_block_type(clean_type):
		return false
	if is_sign_block_type(clean_type):
		return false
	if is_toggle_block_type(clean_type):
		return false
	if block_requires_full_area_clear(clean_type):
		return false
	if block_occupies_collision_area(clean_type):
		return false
	if not springboard_frames_are_tilemap_sized(clean_type):
		return false

	var item_data: Dictionary = world.item_database[clean_type]
	var default_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var collision_size := parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset := parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)

	return collision_size == default_size and collision_offset == Vector2.ZERO


func has_platform_variant_textures(block_type: String) -> bool:
	var variants = get_block_item_data(block_type).get("platform_variant_textures", {})
	return variants is Dictionary and not variants.is_empty()


func has_platform_variant_atlas_coords(block_type: String) -> bool:
	var variants = get_block_item_data(block_type).get("platform_variant_atlas_coords", {})
	return variants is Dictionary and not variants.is_empty()


func has_platform_visual_variants(block_type: String) -> bool:
	return has_platform_variant_textures(block_type) or has_platform_variant_atlas_coords(block_type)


func has_vertical_variant_atlas_coords(block_type: String) -> bool:
	var variants = get_block_item_data(block_type).get("vertical_variant_atlas_coords", {})
	return variants is Dictionary and not variants.is_empty()


func has_connected_variant_atlas_coords(block_type: String) -> bool:
	var variants = get_block_item_data(block_type).get("connected_variant_atlas_coords", {})
	return variants is Dictionary and not variants.is_empty()


func has_connected_variant_textures(block_type: String) -> bool:
	if str(block_type).strip_edges().to_lower() == BARN_BLOCK_TYPE:
		return false
	var variants = get_block_item_data(block_type).get("connected_variant_textures", {})
	return variants is Dictionary and not variants.is_empty()


func has_connected_visual_variants(block_type: String) -> bool:
	return has_connected_variant_textures(block_type) or has_connected_variant_atlas_coords(block_type)


func get_platform_variant_texture_path(block_type: String, variant_key: String) -> String:
	var variants = get_block_item_data(block_type).get("platform_variant_textures", {})
	if not (variants is Dictionary):
		return ""
	return str(variants.get(variant_key, ""))


func get_connected_variant_texture_path(block_type: String, variant_key: String) -> String:
	var variants = get_block_item_data(block_type).get("connected_variant_textures", {})
	if not (variants is Dictionary):
		return ""
	return str(variants.get(variant_key, "")).strip_edges()


func get_platform_variant_atlas_data(block_type: String, variant_key: String) -> Dictionary:
	var variants = get_block_item_data(block_type).get("platform_variant_atlas_coords", {})
	if not (variants is Dictionary) or not variants.has(variant_key):
		return {}

	var item_data := get_block_item_data(block_type)
	var raw_variant = variants.get(variant_key)
	var atlas_coords := Vector2i.ZERO
	var source_id := int(item_data.get("atlas_source_id", item_data.get("source_id", 0)))
	var alternative_tile := int(item_data.get("alternative_tile", 0))
	if raw_variant is Dictionary:
		atlas_coords = parse_block_vector2i(raw_variant.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		source_id = int(raw_variant.get("atlas_source_id", raw_variant.get("source_id", source_id)))
		alternative_tile = int(raw_variant.get("alternative_tile", alternative_tile))
	else:
		atlas_coords = parse_block_vector2i(raw_variant, Vector2i.ZERO)

	return {
		"atlas_coords": atlas_coords,
		"source_id": source_id,
		"alternative_tile": alternative_tile
	}


func get_vertical_variant_atlas_data(block_type: String, variant_key: String) -> Dictionary:
	var variants = get_block_item_data(block_type).get("vertical_variant_atlas_coords", {})
	if not (variants is Dictionary) or not variants.has(variant_key):
		return {}

	var item_data := get_block_item_data(block_type)
	var raw_variant = variants.get(variant_key)
	var atlas_coords := Vector2i.ZERO
	var source_id := int(item_data.get("atlas_source_id", item_data.get("source_id", 0)))
	var alternative_tile := int(item_data.get("alternative_tile", 0))
	if raw_variant is Dictionary:
		atlas_coords = parse_block_vector2i(raw_variant.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		source_id = int(raw_variant.get("atlas_source_id", raw_variant.get("source_id", source_id)))
		alternative_tile = int(raw_variant.get("alternative_tile", alternative_tile))
	else:
		atlas_coords = parse_block_vector2i(raw_variant, Vector2i.ZERO)

	return {
		"atlas_coords": atlas_coords,
		"source_id": source_id,
		"alternative_tile": alternative_tile
	}


func get_connected_variant_atlas_data(block_type: String, variant_key: String) -> Dictionary:
	var variants = get_block_item_data(block_type).get("connected_variant_atlas_coords", {})
	if not (variants is Dictionary) or not variants.has(variant_key):
		return {}

	var item_data := get_block_item_data(block_type)
	var raw_variant = variants.get(variant_key)
	var atlas_coords := Vector2i.ZERO
	var source_id := int(item_data.get("atlas_source_id", item_data.get("source_id", 0)))
	var alternative_tile := int(item_data.get("alternative_tile", 0))
	if raw_variant is Dictionary:
		atlas_coords = parse_block_vector2i(raw_variant.get("atlas_coords", Vector2i.ZERO), Vector2i.ZERO)
		source_id = int(raw_variant.get("atlas_source_id", raw_variant.get("source_id", source_id)))
		alternative_tile = int(raw_variant.get("alternative_tile", alternative_tile))
	else:
		atlas_coords = parse_block_vector2i(raw_variant, Vector2i.ZERO)

	return {
		"atlas_coords": atlas_coords,
		"source_id": source_id,
		"alternative_tile": alternative_tile
	}


func get_connected_variant_key_or_fallback(block_type: String, variant_key: String, fallback_key: String = "") -> String:
	var item_data := get_block_item_data(block_type)
	for variants_key in ["connected_variant_textures", "connected_variant_atlas_coords"]:
		var variants = item_data.get(variants_key, {})
		if not (variants is Dictionary):
			continue
		if variants.has(variant_key):
			return variant_key
		if fallback_key != "" and variants.has(fallback_key):
			return fallback_key
	return variant_key


func clear_connected_variant_component_cache() -> void:
	connected_variant_component_cache.clear()


func get_connected_variant_component_cache_key(block_type: String, grid_pos: Vector2i) -> String:
	return "%s:%d:%d" % [block_type, grid_pos.x, grid_pos.y]


func get_connected_variant_component_data(block_type: String, grid_pos: Vector2i) -> Dictionary:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return {}
	if get_foreground_block_type_at(grid_pos) != clean_type:
		return {}

	var cache_key := get_connected_variant_component_cache_key(clean_type, grid_pos)
	if connected_variant_component_cache.has(cache_key):
		return connected_variant_component_cache[cache_key]

	var stack: Array[Vector2i] = [grid_pos]
	var visited: Dictionary = {}
	var cells: Array[Vector2i] = []
	var min_x := grid_pos.x
	var max_x := grid_pos.x
	var min_y := grid_pos.y
	var max_y := grid_pos.y

	while not stack.is_empty() and cells.size() < MAX_CONNECTED_VARIANT_COMPONENT_CELLS:
		var current: Vector2i = stack.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		if get_foreground_block_type_at(current) != clean_type:
			continue

		cells.append(current)
		min_x = mini(min_x, current.x)
		max_x = maxi(max_x, current.x)
		min_y = mini(min_y, current.y)
		max_y = maxi(max_y, current.y)

		for neighbor in [
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x, current.y - 1),
			Vector2i(current.x, current.y + 1)
		]:
			if not visited.has(neighbor) and get_foreground_block_type_at(neighbor) == clean_type:
				stack.append(neighbor)

	var component_data := {
		"cells": cells,
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"width": max_x - min_x + 1,
		"height": max_y - min_y + 1
	}
	for cell in cells:
		connected_variant_component_cache[get_connected_variant_component_cache_key(clean_type, cell)] = component_data
	return component_data


func is_barn_block_at(grid_pos: Vector2i) -> bool:
	return str(get_foreground_block_type_at(grid_pos)).strip_edges().to_lower() == BARN_BLOCK_TYPE


func get_barn_atlas_item_data() -> Dictionary:
	var atlas_item_id := get_atlas_item_id_for_block_type(BARN_BLOCK_TYPE)
	if atlas_item_id <= 0:
		return {}

	var atlas_item_value: Variant = ITEM_ATLAS_DB.get_item(atlas_item_id)
	if not (atlas_item_value is Dictionary):
		return {}
	var atlas_item: Dictionary = atlas_item_value
	if atlas_item.is_empty():
		return {}
	return atlas_item


func get_barn_atlas_source_id() -> int:
	var atlas_item := get_barn_atlas_item_data()
	if atlas_item.is_empty():
		return 0
	return int(atlas_item.get("source_id", atlas_item.get("atlas_source_id", 0)))


func get_barn_atlas_alternative_tile() -> int:
	var atlas_item := get_barn_atlas_item_data()
	if atlas_item.is_empty():
		return 0
	return int(atlas_item.get("alternative_tile", 0))


func get_barn_neighbor_mask(grid_pos: Vector2i) -> int:
	var mask := 0
	if is_barn_block_at(Vector2i(grid_pos.x, grid_pos.y - 1)):
		mask |= BARN_NEIGHBOR_UP
	if is_barn_block_at(Vector2i(grid_pos.x + 1, grid_pos.y)):
		mask |= BARN_NEIGHBOR_RIGHT
	if is_barn_block_at(Vector2i(grid_pos.x, grid_pos.y + 1)):
		mask |= BARN_NEIGHBOR_DOWN
	if is_barn_block_at(Vector2i(grid_pos.x - 1, grid_pos.y)):
		mask |= BARN_NEIGHBOR_LEFT
	return mask


func get_barn_neighbor_data(grid_pos: Vector2i) -> Dictionary:
	var up := is_barn_block_at(Vector2i(grid_pos.x, grid_pos.y - 1))
	var right := is_barn_block_at(Vector2i(grid_pos.x + 1, grid_pos.y))
	var down := is_barn_block_at(Vector2i(grid_pos.x, grid_pos.y + 1))
	var left := is_barn_block_at(Vector2i(grid_pos.x - 1, grid_pos.y))
	var up_left := is_barn_block_at(Vector2i(grid_pos.x - 1, grid_pos.y - 1))
	var up_right := is_barn_block_at(Vector2i(grid_pos.x + 1, grid_pos.y - 1))
	var down_left := is_barn_block_at(Vector2i(grid_pos.x - 1, grid_pos.y + 1))
	var down_right := is_barn_block_at(Vector2i(grid_pos.x + 1, grid_pos.y + 1))

	return {
		"up": up,
		"right": right,
		"down": down,
		"left": left,
		"up_left": up_left,
		"up_right": up_right,
		"down_left": down_left,
		"down_right": down_right,
		"mask": get_barn_neighbor_mask(grid_pos)
	}


func barn_neighbors_have_all_diagonals(neighbors: Dictionary) -> bool:
	return bool(neighbors.get("up_left", false)) \
		and bool(neighbors.get("up_right", false)) \
		and bool(neighbors.get("down_left", false)) \
		and bool(neighbors.get("down_right", false))


func get_barn_square_style_atlas_coords(mask: int, neighbors: Dictionary) -> Vector2i:
	var up_left := bool(neighbors.get("up_left", false))
	var up_right := bool(neighbors.get("up_right", false))
	var down_left := bool(neighbors.get("down_left", false))
	var down_right := bool(neighbors.get("down_right", false))

	match mask:
		6:
			if down_right:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_top_left_corner"]
		12:
			if down_left:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_top_right_corner"]
		3:
			if up_right:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_bottom_left_corner"]
		9:
			if up_left:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_bottom_right_corner"]
		14:
			if down_left and down_right:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_top_middle"]
		7:
			if up_right and down_right:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_middle_left"]
		13:
			if up_left and down_left:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_middle_right"]
		11:
			if up_left and up_right:
				return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_bottom_middle"]

	return BARN_NO_ATLAS_COORDS


func get_barn_t_junction_atlas_coords(mask: int) -> Vector2i:
	var dedicated_coords: Variant = BARN_DEDICATED_T_JUNCTION_ATLAS_COORDS.get(mask, BARN_NO_ATLAS_COORDS)
	if dedicated_coords is Vector2i and dedicated_coords != BARN_NO_ATLAS_COORDS:
		return dedicated_coords

	var fallback_coords: Variant = BARN_T_JUNCTION_FALLBACK_ATLAS_COORDS.get(mask, BARN_NO_ATLAS_COORDS)
	if fallback_coords is Vector2i and fallback_coords != BARN_NO_ATLAS_COORDS:
		return fallback_coords
	return BARN_CONNECTED_VARIANT_ATLAS_COORDS["middle"]


func get_barn_basic_mask_atlas_coords(mask: int) -> Vector2i:
	var coords: Variant = BARN_BASIC_MASK_ATLAS_COORDS.get(mask, BARN_NO_ATLAS_COORDS)
	if coords is Vector2i and coords != BARN_NO_ATLAS_COORDS:
		return coords
	return BARN_CONNECTED_VARIANT_ATLAS_COORDS["single"]


func get_barn_atlas_coords(grid_pos: Vector2i) -> Vector2i:
	var neighbors := get_barn_neighbor_data(grid_pos)
	var mask := int(neighbors.get("mask", 0))
	if mask == 15:
		if barn_neighbors_have_all_diagonals(neighbors):
			return BARN_CONNECTED_VARIANT_ATLAS_COORDS["tile_middle_middle"]
		return BARN_CONNECTED_VARIANT_ATLAS_COORDS["middle"]

	var square_style_coords := get_barn_square_style_atlas_coords(mask, neighbors)
	if square_style_coords != BARN_NO_ATLAS_COORDS:
		return square_style_coords

	if BARN_T_JUNCTION_FALLBACK_ATLAS_COORDS.has(mask) or BARN_DEDICATED_T_JUNCTION_ATLAS_COORDS.has(mask):
		# Real T artwork is not present in the current barn atlas. The fallback
		# table keeps the missing coordinates centralized for future art.
		return get_barn_t_junction_atlas_coords(mask)

	return get_barn_basic_mask_atlas_coords(mask)


func get_barn_atlas_data(grid_pos: Vector2i) -> Dictionary:
	var atlas_coords := get_barn_atlas_coords(grid_pos)
	var source_id := get_barn_atlas_source_id()
	var alternative_tile := get_barn_atlas_alternative_tile()
	return {
		"atlas_coords": atlas_coords,
		"source_id": source_id,
		"alternative_tile": alternative_tile
	}


func is_connected_variant_component_filled_rectangle(component_data: Dictionary) -> bool:
	var width := int(component_data.get("width", 0))
	var height := int(component_data.get("height", 0))
	if width <= 1 or height <= 1:
		return false

	var cells = component_data.get("cells", [])
	return cells is Array and cells.size() == width * height


func get_bounds_connected_variant_key(block_type: String, grid_pos: Vector2i) -> String:
	var component_data := get_connected_variant_component_data(block_type, grid_pos)
	if component_data.is_empty():
		return ""

	var cells: Array = component_data.get("cells", [])
	if cells.size() <= 1:
		return "single"

	var min_x := int(component_data.get("min_x", grid_pos.x))
	var max_x := int(component_data.get("max_x", grid_pos.x))
	var min_y := int(component_data.get("min_y", grid_pos.y))
	var max_y := int(component_data.get("max_y", grid_pos.y))
	var width := int(component_data.get("width", 1))
	var height := int(component_data.get("height", 1))
	var has_horizontal := width > 1
	var has_vertical := height > 1

	if has_horizontal and not has_vertical:
		if grid_pos.x == min_x:
			return get_connected_variant_key_or_fallback(block_type, "left", "single")
		if grid_pos.x == max_x:
			return get_connected_variant_key_or_fallback(block_type, "right", "single")
		return get_connected_variant_key_or_fallback(block_type, "horizontal_middle", "middle")

	if has_vertical and not has_horizontal:
		if grid_pos.y == min_y:
			return get_connected_variant_key_or_fallback(block_type, "top", "single")
		if grid_pos.y == max_y:
			return get_connected_variant_key_or_fallback(block_type, "bottom", "single")
		return get_connected_variant_key_or_fallback(block_type, "vertical_middle", "middle")

	if is_connected_variant_component_filled_rectangle(component_data):
		if grid_pos.x == min_x and grid_pos.y == min_y:
			return get_connected_variant_key_or_fallback(block_type, "tile_top_left_corner", "top_left_corner")
		if grid_pos.x == max_x and grid_pos.y == min_y:
			return get_connected_variant_key_or_fallback(block_type, "tile_top_right_corner", "top_right_corner")
		if grid_pos.x == min_x and grid_pos.y == max_y:
			return get_connected_variant_key_or_fallback(block_type, "tile_bottom_left_corner", "bottom_left_corner")
		if grid_pos.x == max_x and grid_pos.y == max_y:
			return get_connected_variant_key_or_fallback(block_type, "tile_bottom_right_corner", "bottom_right_corner")
		if grid_pos.y == min_y:
			return get_connected_variant_key_or_fallback(block_type, "tile_top_middle", "horizontal_middle")
		if grid_pos.y == max_y:
			return get_connected_variant_key_or_fallback(block_type, "tile_bottom_middle", "horizontal_middle")
		if grid_pos.x == min_x:
			return get_connected_variant_key_or_fallback(block_type, "tile_middle_left", "vertical_middle")
		if grid_pos.x == max_x:
			return get_connected_variant_key_or_fallback(block_type, "tile_middle_right", "vertical_middle")
		return get_connected_variant_key_or_fallback(block_type, "tile_middle_middle", "middle")

	if grid_pos.x == min_x and grid_pos.y == min_y:
		return get_connected_variant_key_or_fallback(block_type, "top_left_corner", "top")
	if grid_pos.x == max_x and grid_pos.y == min_y:
		return get_connected_variant_key_or_fallback(block_type, "top_right_corner", "top")
	if grid_pos.x == min_x and grid_pos.y == max_y:
		return get_connected_variant_key_or_fallback(block_type, "bottom_left_corner", "bottom")
	if grid_pos.x == max_x and grid_pos.y == max_y:
		return get_connected_variant_key_or_fallback(block_type, "bottom_right_corner", "bottom")
	if grid_pos.y == min_y or grid_pos.y == max_y:
		return get_connected_variant_key_or_fallback(block_type, "horizontal_middle", "middle")
	if grid_pos.x == min_x or grid_pos.x == max_x:
		return get_connected_variant_key_or_fallback(block_type, "vertical_middle", "middle")
	return "middle"


func get_platform_variant_key(block_type: String, grid_pos: Vector2i) -> String:
	var has_left_platform = has_wood_platform_neighbor(Vector2i(grid_pos.x - 1, grid_pos.y), block_type)
	var has_right_platform = has_wood_platform_neighbor(Vector2i(grid_pos.x + 1, grid_pos.y), block_type)

	if has_left_platform and has_right_platform:
		return "middle"
	if has_right_platform:
		return "left"
	if has_left_platform:
		return "right"
	return ""


func get_vertical_variant_key(block_type: String, grid_pos: Vector2i) -> String:
	var has_above = has_vertical_variant_neighbor(Vector2i(grid_pos.x, grid_pos.y - 1), block_type)
	var has_below = has_vertical_variant_neighbor(Vector2i(grid_pos.x, grid_pos.y + 1), block_type)

	if has_above and has_below:
		return "middle"
	if has_below:
		return "top"
	if has_above:
		return "bottom"
	return "single"


func get_connected_variant_key(block_type: String, grid_pos: Vector2i) -> String:
	var bounds_variant_key := get_bounds_connected_variant_key(block_type, grid_pos)
	if bounds_variant_key != "":
		return bounds_variant_key

	var has_above = has_connected_variant_neighbor(Vector2i(grid_pos.x, grid_pos.y - 1), block_type)
	var has_below = has_connected_variant_neighbor(Vector2i(grid_pos.x, grid_pos.y + 1), block_type)
	var has_left = has_connected_variant_neighbor(Vector2i(grid_pos.x - 1, grid_pos.y), block_type)
	var has_right = has_connected_variant_neighbor(Vector2i(grid_pos.x + 1, grid_pos.y), block_type)

	var neighbor_count := 0
	if has_above:
		neighbor_count += 1
	if has_below:
		neighbor_count += 1
	if has_left:
		neighbor_count += 1
	if has_right:
		neighbor_count += 1

	if neighbor_count == 0:
		return "single"
	if has_left and has_right and has_above and has_below:
		return "middle"
	if has_below and has_right and not has_left and not has_above:
		return get_connected_variant_key_or_fallback(block_type, "top_left_corner", "top")
	if has_below and has_left and not has_right and not has_above:
		return get_connected_variant_key_or_fallback(block_type, "top_right_corner", "top")
	if has_above and has_right and not has_left and not has_below:
		return get_connected_variant_key_or_fallback(block_type, "bottom_left_corner", "bottom")
	if has_above and has_left and not has_right and not has_below:
		return get_connected_variant_key_or_fallback(block_type, "bottom_right_corner", "bottom")
	if has_left and has_right:
		return get_connected_variant_key_or_fallback(block_type, "horizontal_middle", "middle")
	if has_above and has_below:
		return get_connected_variant_key_or_fallback(block_type, "vertical_middle", "middle")
	if neighbor_count == 1:
		if has_right:
			return "left"
		if has_left:
			return "right"
		if has_below:
			return "top"
		if has_above:
			return "bottom"

	if has_below and not has_above:
		return "top"
	if has_above and not has_below:
		return "bottom"
	if has_right and not has_left:
		return "left"
	if has_left and not has_right:
		return "right"
	if has_above or has_below or has_left or has_right:
		return "middle"
	return "single"


func is_wood_platform_block_type(block_type: String) -> bool:
	return is_platform_collision_block_type(block_type)


func has_wood_platform_neighbor(grid_pos: Vector2i, platform_type: String = "wood_platform") -> bool:
	var neighbor_type = get_foreground_block_type_at(grid_pos)
	return neighbor_type == platform_type and has_platform_visual_variants(neighbor_type)


func has_vertical_variant_neighbor(grid_pos: Vector2i, block_type: String) -> bool:
	var neighbor_type = get_foreground_block_type_at(grid_pos)
	return neighbor_type == block_type and has_vertical_variant_atlas_coords(neighbor_type)


func has_connected_variant_neighbor(grid_pos: Vector2i, block_type: String) -> bool:
	var neighbor_type = get_foreground_block_type_at(grid_pos)
	return neighbor_type == block_type and has_connected_visual_variants(neighbor_type)


func is_tree_trunk_block_type(block_type: String) -> bool:
	return block_type == "wood"


func has_tree_trunk_neighbor(grid_pos: Vector2i) -> bool:
	return is_tree_trunk_block_type(get_foreground_block_type_at(grid_pos))


func is_climbing_vine_block_type(block_type: String) -> bool:
	return block_type == "climbing_vine"


func has_climbing_vine_neighbor(grid_pos: Vector2i) -> bool:
	return is_climbing_vine_block_type(get_foreground_block_type_at(grid_pos))


func is_wooden_entrance_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("entrance_block", false)) or item_data.has("entrance_frames")


func is_wooden_entrance_tilemap_collision_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("entrance_tilemap_collision", false))


func has_wooden_entrance_pass_tilemap_animation(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return item_data.has("entrance_pass_atlas_coords") or item_data.has("entrance_pass_atlas_frames")


func get_wooden_entrance_idle_texture_path(block_type: String) -> String:
	var item_data = get_block_item_data(block_type)
	var texture_path := str(item_data.get("entrance_idle_texture", item_data.get("texture", ""))).strip_edges()
	if texture_path != "":
		return texture_path

	var frame_paths = item_data.get("entrance_frames", [])
	if frame_paths is Array and not frame_paths.is_empty():
		return str(frame_paths[0]).strip_edges()

	return ""


func get_wooden_entrance_idle_atlas_coords(block_type: String) -> Vector2i:
	var item_data = get_block_item_data(block_type)
	return parse_block_vector2i(item_data.get("entrance_idle_atlas_coords", item_data.get("atlas_coords", Vector2i.ZERO)), Vector2i.ZERO)


func get_wooden_entrance_pass_atlas_coords(block_type: String) -> Vector2i:
	var item_data = get_block_item_data(block_type)
	return parse_block_vector2i(item_data.get("entrance_pass_atlas_coords", Vector2i.ZERO), Vector2i.ZERO)


func get_wooden_entrance_pass_atlas_frames(block_type: String) -> Array[Vector2i]:
	var item_data = get_block_item_data(block_type)
	var raw_frames = item_data.get("entrance_pass_atlas_frames", [])
	var frames: Array[Vector2i] = []
	if not (raw_frames is Array):
		return frames

	for raw_frame in raw_frames:
		frames.append(parse_block_vector2i(raw_frame, Vector2i.ZERO))

	return frames


func get_wooden_entrance_pass_animation_columns(block_type: String) -> int:
	var item_data = get_block_item_data(block_type)
	var atlas_frames := get_wooden_entrance_pass_atlas_frames(block_type)
	if not item_data.has("entrance_pass_animation_columns") and not atlas_frames.is_empty():
		return maxi(1, atlas_frames.size())
	return maxi(1, int(item_data.get("entrance_pass_animation_columns", 1)))


func get_wooden_entrance_pass_animation_duration(block_type: String) -> float:
	var item_data = get_block_item_data(block_type)
	if item_data.has("entrance_pass_animation_seconds"):
		return maxf(0.03, float(item_data.get("entrance_pass_animation_seconds", 0.03)))
	return get_wooden_entrance_frame_seconds(block_type) * float(get_wooden_entrance_pass_animation_columns(block_type))


func is_entrance_gate_block_type(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "entrance_gate":
		return true
	if world != null:
		return clean_type == str(world.ENTRANCE_GATE_TYPE).strip_edges().to_lower()
	return false


func is_wooden_entrance_at(grid_pos: Vector2i) -> bool:
	return is_wooden_entrance_block_type(get_foreground_block_type_at(grid_pos))


func is_door_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("door_block", false))


func is_password_door_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("password_door", false))


func is_auto_enter_door_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("auto_door_enter", false)) or bool(item_data.get("portal_block", false))


func is_door_at(grid_pos: Vector2i) -> bool:
	return is_door_block_type(get_foreground_block_type_at(grid_pos))


func is_player_standing_on_grid(grid_pos: Vector2i) -> bool:
	if world == null or world.player == null:
		return false

	var player_grid = world.get_player_grid_position()
	return player_grid == grid_pos


func try_enter_door_under_player() -> bool:
	if world == null or world.player == null:
		return false

	var player_grid = world.get_player_grid_position()
	if not is_door_at(player_grid):
		return false

	var block_data = world.blocks.get(player_grid, {})
	var has_link = false
	if block_data is Dictionary:
		has_link = str(block_data.get("door_destination", "")).strip_edges() != "" or str(block_data.get("door_target_id", "")).strip_edges() != ""

	if world.has_method("try_enter_door_at"):
		return bool(world.try_enter_door_at(player_grid, false)) or has_link

	return has_link


func is_sign_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("sign_block", false))


func is_toggle_block_type(block_type: String) -> bool:
	var item_data = get_block_item_data(block_type)
	return bool(item_data.get("toggle_block", false))


func get_grid_pos_for_block_node(block) -> Vector2i:
	if block == null or world == null:
		return NO_VARIANT_GRID_POS

	return Vector2i(
		int(round(block.position.x / world.BLOCK_SIZE)),
		int(round(block.position.y / world.BLOCK_SIZE))
	)


func is_wooden_entrance_locked(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	return bool(world.blocks[grid_pos].get("entrance_locked", false))


func can_current_player_pass_wooden_entrance() -> bool:
	if world != null and world.has_method("can_current_player_pass_wooden_entrance"):
		return bool(world.can_current_player_pass_wooden_entrance())

	return true


func should_disable_wooden_entrance_collision(grid_pos: Vector2i) -> bool:
	if not is_wooden_entrance_locked(grid_pos):
		return true

	return can_current_player_pass_wooden_entrance()


func sync_wooden_entrance_tilemap_collision(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_data_value: Variant = world.blocks.get(grid_pos, {})
	if not (block_data_value is Dictionary):
		clear_foreground_tilemap_collision_cell(grid_pos)
		return false

	var block_data: Dictionary = block_data_value
	var block_type := str(block_data.get("type", ""))
	if not is_wooden_entrance_tilemap_collision_block_type(block_type):
		return false

	var block_node_value: Variant = block_data.get("node", null)
	var block_node: Node = null
	if block_node_value is Node and is_instance_valid(block_node_value):
		block_node = block_node_value

	var collision_disabled := should_disable_wooden_entrance_collision(grid_pos)
	if not foreground_tilemap_collision_enabled or collision_disabled:
		clear_foreground_tilemap_collision_cell(grid_pos)
		block_data.erase("tilemap_collision")
		block_data.erase("tilemap_collision_replaces_node")
		block_data.erase("tilemap_collision_kind")
		world.blocks[grid_pos] = block_data
		if block_node != null:
			if block_node.has_meta("tilemap_collision"):
				block_node.remove_meta("tilemap_collision")
			if block_node.has_meta("tilemap_collision_replaces_node"):
				block_node.remove_meta("tilemap_collision_replaces_node")
			set_original_block_collision_disabled(block_node, collision_disabled)
		return false

	var renderer = ensure_tilemap_renderer()
	if renderer == null or not renderer.has_method("set_foreground_collision_cell"):
		clear_foreground_tilemap_collision_cell(grid_pos)
		if block_node != null:
			if block_node.has_meta("tilemap_collision"):
				block_node.remove_meta("tilemap_collision")
			if block_node.has_meta("tilemap_collision_replaces_node"):
				block_node.remove_meta("tilemap_collision_replaces_node")
			set_original_block_collision_disabled(block_node, false)
		return false

	var collision_synced: bool = bool(renderer.set_foreground_collision_cell(grid_pos))
	if not collision_synced:
		clear_foreground_tilemap_collision_cell(grid_pos)
		if block_node != null:
			if block_node.has_meta("tilemap_collision"):
				block_node.remove_meta("tilemap_collision")
			if block_node.has_meta("tilemap_collision_replaces_node"):
				block_node.remove_meta("tilemap_collision_replaces_node")
			set_original_block_collision_disabled(block_node, false)
		return false

	block_data["tilemap_collision"] = true
	block_data["tilemap_collision_kind"] = "full"
	world.blocks[grid_pos] = block_data

	if block_node != null:
		set_original_block_collision_disabled(block_node, true)
		block_node.set_meta("tilemap_collision", true)
		block_node.set_meta("tilemap_collision_replaces_node", true)

	return true


func refresh_wooden_entrance_collision(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_type := str(world.blocks[grid_pos].get("type", ""))
	if is_wooden_entrance_tilemap_collision_block_type(block_type):
		sync_wooden_entrance_tilemap_collision(grid_pos)
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	set_original_block_collision_disabled(block_node, should_disable_wooden_entrance_collision(grid_pos))


func refresh_all_wooden_entrance_collisions():
	if world == null:
		return

	for grid_pos in world.blocks.keys():
		if is_wooden_entrance_at(grid_pos):
			refresh_wooden_entrance_collision(grid_pos)


func get_existing_variant_paths(paths: Array) -> Array:
	var cache_key := ""
	for texture_path in paths:
		cache_key += str(texture_path) + "|"

	if existing_variant_path_cache.has(cache_key):
		return existing_variant_path_cache[cache_key]

	var existing_paths: Array = []
	for texture_path in paths:
		var clean_path = str(texture_path)
		if clean_path != "" and ResourceLoader.exists(clean_path):
			existing_paths.append(clean_path)

	existing_variant_path_cache[cache_key] = existing_paths
	return existing_paths


func uses_lower_dirt_variant_when_above(block_type: String) -> bool:
	return block_type == "dirt" or block_type == "snow_dirt"


func get_visual_block_variant(base_block_id: String, grid_pos: Vector2i, background := false) -> String:
	if grid_pos == NO_VARIANT_GRID_POS:
		return ""

	if background:
		# cave_background's weighted variant selection now lives in
		# get_stateful_block_atlas_data() (atlas-coordinate based, sourced from
		# the shared blocks atlas image) so it can be reached from the
		# background render pass too.
		return ""

	if str(base_block_id).strip_edges().to_lower() == BARN_BLOCK_TYPE:
		return ""

	# Dirt and stone weighted variants now live in get_stateful_block_atlas_data()
	# (atlas-coordinate based). Water still uses the legacy path-based override.
	if base_block_id == "water":
		var above_water_pos = Vector2i(grid_pos.x, grid_pos.y - 1)
		if get_foreground_block_type_at(above_water_pos) == "water":
			return WATER_LOWER_TEXTURE_PATH
		# Top water keeps the normal animated water frames; only lower water gets a static visual override.
		return ""

	# "wood" (tree trunk) top/middle/bottom stacking now lives in the generic
	# vertical_variant_atlas_coords system (see item_database.gd), which is
	# already dispatched from get_stateful_block_atlas_data().

	# climbing_vine's 4-way (top/middle/bottom/single) variant now lives in the
	# generic vertical_variant_atlas_coords system (see item_database.gd), which
	# is already dispatched from get_stateful_block_atlas_data().

	if has_platform_variant_textures(base_block_id):
		var platform_variant_key := get_platform_variant_key(base_block_id, grid_pos)
		if platform_variant_key != "":
			return get_platform_variant_texture_path(base_block_id, platform_variant_key)
		return ""

	if has_connected_variant_textures(base_block_id):
		var connected_variant_key := get_connected_variant_key(base_block_id, grid_pos)
		if connected_variant_key != "":
			return get_connected_variant_texture_path(base_block_id, connected_variant_key)
		return ""

	return ""


func get_stateful_block_texture_path(base_block_id: String, grid_pos: Vector2i, background := false) -> String:
	if background or grid_pos == NO_VARIANT_GRID_POS:
		return ""
	if world == null or not world.item_database.has(base_block_id):
		return ""

	var item_data = world.item_database[base_block_id]
	if is_world_lock_block_type(base_block_id):
		return get_world_lock_access_texture_path(base_block_id, grid_pos)

	if bool(item_data.get("mailbox_block", false)):
		var mailbox_texture_key = "mailbox_full_texture" if get_mailbox_visual_state_frame(grid_pos) == 2 else "mailbox_empty_texture"
		return str(item_data.get(mailbox_texture_key, "")).strip_edges()

	if bool(item_data.get("tackle_box_block", false)):
		var tackle_texture_key = "tackle_box_full_texture" if get_tackle_box_visual_state_frame(grid_pos) == 2 else "tackle_box_empty_texture"
		return str(item_data.get(tackle_texture_key, "")).strip_edges()

	if bool(item_data.get("dice_block", false)):
		return get_dice_face_texture_path(base_block_id, get_dice_face(grid_pos))

	if bool(item_data.get("checkpoint_block", false)):
		var checkpoint_texture_key = "checkpoint_active_texture" if is_checkpoint_active(grid_pos) else "checkpoint_inactive_texture"
		return str(item_data.get(checkpoint_texture_key, item_data.get("texture", ""))).strip_edges()

	if bool(item_data.get("anti_punch_block", false)):
		if is_anti_punch_grid_enabled(grid_pos):
			var frames = item_data.get("anti_punch_enabled_frames", [])
			if frames is Array and not frames.is_empty():
				return str(frames[0]).strip_edges()
		return str(item_data.get("anti_punch_disabled_texture", item_data.get("texture", ""))).strip_edges()

	if bool(item_data.get("anti_talk_block", false)):
		if is_anti_talk_grid_enabled(grid_pos):
			var frames = item_data.get("anti_talk_enabled_frames", [])
			if frames is Array and not frames.is_empty():
				return str(frames[0]).strip_edges()
		return str(item_data.get("anti_talk_disabled_texture", item_data.get("texture", ""))).strip_edges()

	if bool(item_data.get("anti_gravity_block", false)):
		if is_anti_gravity_grid_enabled(grid_pos):
			var frames = item_data.get("anti_gravity_enabled_frames", [])
			if frames is Array and not frames.is_empty():
				return str(frames[0]).strip_edges()
		return str(item_data.get("anti_gravity_disabled_texture", item_data.get("texture", ""))).strip_edges()

	if bool(item_data.get("theme_machine_block", false)):
		var texture_spec = item_data.get("theme_machine_disabled_texture", item_data.get("texture", ""))
		if is_theme_machine_grid_enabled(grid_pos):
			var frames = item_data.get("theme_machine_enabled_frames", [])
			if frames is Array and not frames.is_empty():
				texture_spec = frames[0]
		if texture_spec is String or texture_spec is StringName:
			return str(texture_spec).strip_edges()
		return ""

	return ""


func get_stateful_block_atlas_data(base_block_id: String, grid_pos: Vector2i, background := false) -> Dictionary:
	if grid_pos == NO_VARIANT_GRID_POS:
		return {}
	if world == null:
		return {}

	var clean_base_id := normalize_legacy_block_id(str(base_block_id).strip_edges().to_lower())
	if clean_base_id == "" or not world.item_database.has(clean_base_id):
		return {}

	var item_data = world.item_database[clean_base_id]

	if background:
		# Only cave_background's weighted variant selection runs on the
		# background render pass; everything else below is foreground-only.
		if clean_base_id == "cave_background":
			var cave_atlas_data := get_weighted_atlas_variant_data(item_data, grid_pos, "cave_background_atlas_variants", "cave_background_atlas_weights", 21)
			if not cave_atlas_data.is_empty():
				return cave_atlas_data
		return {}

	if clean_base_id == "dirt":
		var above_pos = Vector2i(grid_pos.x, grid_pos.y - 1)
		if uses_lower_dirt_variant_when_above(get_foreground_block_type_at(above_pos)):
			var dirt_atlas_data := get_weighted_atlas_variant_data(item_data, grid_pos, "dirt_lower_atlas_variants", "dirt_lower_atlas_weights", 11)
			if not dirt_atlas_data.is_empty():
				return dirt_atlas_data

	if clean_base_id == "stone":
		var stone_atlas_data := get_weighted_atlas_variant_data(item_data, grid_pos, "stone_atlas_variants", "stone_atlas_weights", 31)
		if not stone_atlas_data.is_empty():
			return stone_atlas_data

	if clean_base_id == "sand":
		var sand_atlas_data := get_weighted_atlas_variant_data(item_data, grid_pos, "sand_atlas_variants", "sand_atlas_weights", 41)
		if not sand_atlas_data.is_empty():
			return sand_atlas_data

	if is_world_lock_block_type(clean_base_id):
		var world_lock_atlas_data := get_world_lock_access_atlas_coords(clean_base_id, grid_pos)
		if not world_lock_atlas_data.is_empty():
			return world_lock_atlas_data

	if bool(item_data.get("vending_machine_block", false)):
		var vending_atlas_data := get_vending_machine_atlas_data(grid_pos, item_data)
		if not vending_atlas_data.is_empty():
			return vending_atlas_data

	if clean_base_id == WATER_BLOCK_TYPE and is_lower_water_layer_cell(grid_pos):
		return {
			"atlas_coords": parse_block_vector2i(item_data.get("water_lower_atlas_coords", WATER_LOWER_ATLAS_COORDS), WATER_LOWER_ATLAS_COORDS)
		}

	if clean_base_id == BARN_BLOCK_TYPE:
		var barn_atlas_data := get_barn_atlas_data(grid_pos)
		if not barn_atlas_data.is_empty():
			return barn_atlas_data
	if has_platform_variant_atlas_coords(clean_base_id):
		var platform_variant_key := get_platform_variant_key(clean_base_id, grid_pos)
		if platform_variant_key != "":
			var platform_atlas_data := get_platform_variant_atlas_data(clean_base_id, platform_variant_key)
			if not platform_atlas_data.is_empty():
				return platform_atlas_data

	if has_vertical_variant_atlas_coords(clean_base_id):
		var vertical_variant_key := get_vertical_variant_key(clean_base_id, grid_pos)
		if vertical_variant_key != "":
			var vertical_atlas_data := get_vertical_variant_atlas_data(clean_base_id, vertical_variant_key)
			if not vertical_atlas_data.is_empty():
				return vertical_atlas_data

	if has_connected_variant_atlas_coords(clean_base_id):
		var connected_variant_key := get_connected_variant_key(clean_base_id, grid_pos)
		if connected_variant_key != "":
			var connected_atlas_data := get_connected_variant_atlas_data(clean_base_id, connected_variant_key)
			if not connected_atlas_data.is_empty():
				return connected_atlas_data

	if bool(item_data.get("chicken_block", false)):
		var chicken_atlas_key := "chicken_hungry_atlas_coords"
		var chicken_status := get_chicken_status(grid_pos)
		if chicken_status == "ready":
			chicken_atlas_key = "chicken_ready_atlas_coords"
		elif chicken_status == "producing":
			chicken_atlas_key = "chicken_producing_atlas_coords"
		if item_data.has(chicken_atlas_key):
			return {
				"atlas_coords": parse_block_vector2i(item_data.get(chicken_atlas_key), Vector2i.ZERO)
			}

	if bool(item_data.get("cow_block", false)):
		var cow_atlas_key := "cow_hungry_atlas_coords"
		var cow_status := get_cow_status(grid_pos)
		if cow_status == "ready":
			cow_atlas_key = "cow_ready_atlas_coords"
		elif cow_status == "producing":
			cow_atlas_key = "cow_producing_atlas_coords"
		if item_data.has(cow_atlas_key):
			return {
				"atlas_coords": parse_block_vector2i(item_data.get(cow_atlas_key), Vector2i.ZERO)
			}

	if bool(item_data.get("duck_block", false)):
		var duck_atlas_key := "duck_hungry_atlas_coords"
		var duck_status := get_duck_status(grid_pos)
		if duck_status == "ready":
			duck_atlas_key = "duck_ready_atlas_coords"
		elif duck_status == "producing":
			duck_atlas_key = "duck_producing_atlas_coords"
		if item_data.has(duck_atlas_key):
			return {
				"atlas_coords": parse_block_vector2i(item_data.get(duck_atlas_key), Vector2i.ZERO)
			}

	if bool(item_data.get("water_well_block", false)):
		var water_well_atlas_key := "water_well_ready_atlas_coords" if water_well_is_ready(grid_pos) else "water_well_producing_atlas_coords"
		if item_data.has(water_well_atlas_key):
			return {
				"atlas_coords": parse_block_vector2i(item_data.get(water_well_atlas_key), Vector2i.ZERO)
			}

	if bool(item_data.get("atm_machine_block", false)):
		var atm_atlas_key := "atm_machine_ready_atlas_coords" if tackle_box_is_ready(grid_pos) else "atm_machine_producing_atlas_coords"
		if item_data.has(atm_atlas_key):
			return {
				"atlas_coords": parse_block_vector2i(item_data.get(atm_atlas_key), Vector2i.ZERO)
			}

	if bool(item_data.get("checkpoint_block", false)):
		var atlas_key := "checkpoint_active_atlas_coords" if is_checkpoint_active(grid_pos) else "checkpoint_inactive_atlas_coords"
		if item_data.has(atlas_key):
			return {
				"atlas_coords": parse_block_vector2i(item_data.get(atlas_key), Vector2i.ZERO)
			}

	return {}


func get_weighted_atlas_variant_data(item_data: Dictionary, grid_pos: Vector2i, variants_key: String, weights_key: String, salt: int) -> Dictionary:
	var variants = item_data.get(variants_key, [])
	if not (variants is Array) or variants.is_empty():
		return {}

	var weights = item_data.get(weights_key, [])
	var variant_index := 0
	if weights is Array and weights.size() == variants.size():
		variant_index = get_weighted_stable_variant_index(grid_pos, weights, salt)
	else:
		variant_index = get_stable_variant_index(grid_pos, variants.size(), salt)
	variant_index = clampi(variant_index, 0, variants.size() - 1)

	return {
		"atlas_coords": parse_block_vector2i(variants[variant_index], Vector2i.ZERO)
	}


func get_world_lock_access_atlas_coords(block_type: String, grid_pos: Vector2i) -> Dictionary:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return {}

	var clean_type := str(block_type).strip_edges().to_lower()
	if not is_world_lock_block_type(clean_type):
		return {}
	if world.world_lock_manager == null:
		return {}

	var manager = world.world_lock_manager
	if "is_locked" in manager and not bool(manager.is_locked):
		return {}
	if "lock_grid_pos" in manager and manager.lock_grid_pos is Vector2i:
		if manager.lock_grid_pos != grid_pos:
			return {}

	var has_access := false
	if manager.has_method("is_current_player_owner_or_access"):
		has_access = bool(manager.is_current_player_owner_or_access())

	var item_data := get_block_item_data(clean_type)
	if item_data.is_empty():
		return {}

	var atlas_key := "world_lock_access_atlas_coords" if has_access else "world_lock_no_access_atlas_coords"
	if not item_data.has(atlas_key):
		return {}

	return {
		"atlas_coords": parse_block_vector2i(item_data.get(atlas_key), Vector2i.ZERO)
	}


func get_vending_machine_atlas_data(grid_pos: Vector2i, item_data: Dictionary) -> Dictionary:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return {}
	if not ("vending_states" in world):
		return {}

	var raw_state: Variant = world.vending_states.get(grid_pos, {})
	var state := get_wrapped_state_payload(raw_state)
	var listing_value = state.get("listing", {})
	var listing: Dictionary = listing_value if listing_value is Dictionary else {}
	var has_listing := not listing.is_empty()
	var pending := int(state.get("pending_wls", 0))
	var status := str(state.get("status", "")).strip_edges().to_lower()
	var is_sold := pending > 0 or status == "sold"

	# Out-of-stock (stock<=0) does NOT swap this block's own tile -- that would
	# double-stamp the same out-of-stock icon, since it is already drawn as a
	# separate overlay layer by vending_preview_manager.gd (is_sold_out_vending_state()
	# / SOLD_OUT_VEND_PREVIEW_TEXTURE, atlas cell (6,1)). The base tile keeps showing
	# the active listing ("full") until a sale flashes "sold".
	var atlas_key := "vending_empty_atlas_coords"
	if has_listing:
		if is_sold:
			atlas_key = "vending_sold_atlas_coords"
		else:
			atlas_key = "vending_full_atlas_coords"
	elif is_sold:
		atlas_key = "vending_sold_atlas_coords"

	if not item_data.has(atlas_key):
		return {}

	return {
		"atlas_coords": parse_block_vector2i(item_data.get(atlas_key), Vector2i.ZERO)
	}


func get_wrapped_state_payload(state_value) -> Dictionary:
	if not (state_value is Dictionary):
		return {}
	var state: Dictionary = state_value
	if state.has("state") and state.get("state") is Dictionary:
		return state.get("state")
	return state


func mailbox_has_mail(grid_pos: Vector2i) -> bool:
	if world == null or not ("mailbox_states" in world):
		return false
	if not world.mailbox_states.has(grid_pos):
		return false

	var state = get_wrapped_state_payload(world.mailbox_states.get(grid_pos, {}))
	var messages = state.get("messages", [])
	return messages is Array and messages.size() > 0


func get_donation_box_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("donation_box_states" in world):
		return {}
	if not world.donation_box_states.has(grid_pos):
		return {}
	return get_wrapped_state_payload(world.donation_box_states.get(grid_pos, {}))


func donation_box_has_donations(grid_pos: Vector2i) -> bool:
	var state := get_donation_box_state(grid_pos)
	if state.has("has_donations"):
		return bool(state.get("has_donations", false))
	if int(state.get("donation_count", 0)) > 0:
		return true
	var donations = state.get("donations", [])
	return donations is Array and not donations.is_empty()


func get_donation_box_state_texture(block_type: String, grid_pos: Vector2i) -> Texture2D:
	if world == null or not world.item_database.has(block_type):
		return null
	var item_data: Dictionary = world.item_database[block_type]
	var texture_key := "donation_box_full_texture" if donation_box_has_donations(grid_pos) else "donation_box_empty_texture"
	return AtlasTextureFactory.load_texture(item_data.get(texture_key, item_data.get("texture", null)))


func get_mailbox_visual_state_frame(grid_pos: Vector2i) -> int:
	return 2 if mailbox_has_mail(grid_pos) else 1


func clear_mailbox_visual_animation(grid_pos: Vector2i) -> void:
	if grid_pos == NO_VARIANT_GRID_POS:
		return
	tilemap_foreground_animated_cells.erase(grid_pos)
	clear_animation_loop_particle_emitters_for_grid(grid_pos)


func get_tackle_box_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("tackle_box_states" in world):
		return {}
	if not world.tackle_box_states.has(grid_pos):
		return {}

	return get_wrapped_state_payload(world.tackle_box_states.get(grid_pos, {}))


func get_chicken_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("chicken_states" in world):
		return {}
	if not world.chicken_states.has(grid_pos):
		return {}

	return get_wrapped_state_payload(world.chicken_states.get(grid_pos, {}))


func get_chicken_status(grid_pos: Vector2i) -> String:
	var state := get_chicken_state(grid_pos)
	if state.is_empty():
		return "hungry"

	var status := str(state.get("status", "hungry")).strip_edges().to_lower()
	var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
	if next_harvest_at_ms > 0.0:
		var now_ms := Time.get_unix_time_from_system() * 1000.0
		return "ready" if now_ms >= next_harvest_at_ms else "producing"

	if bool(state.get("ready", state.get("can_harvest", false))):
		return "ready"
	if status == "ready" or status == "producing":
		return status
	return "hungry"


func get_cow_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("cow_states" in world):
		return {}
	if not world.cow_states.has(grid_pos):
		return {}

	return get_wrapped_state_payload(world.cow_states.get(grid_pos, {}))


func get_cow_status(grid_pos: Vector2i) -> String:
	var state := get_cow_state(grid_pos)
	if state.is_empty():
		return "hungry"

	var status := str(state.get("status", "hungry")).strip_edges().to_lower()
	var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
	if next_harvest_at_ms > 0.0:
		var now_ms := Time.get_unix_time_from_system() * 1000.0
		return "ready" if now_ms >= next_harvest_at_ms else "producing"

	if bool(state.get("ready", state.get("can_harvest", false))):
		return "ready"
	if status == "ready" or status == "producing":
		return status
	return "hungry"

func get_duck_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("duck_states" in world):
		return {}
	if not world.duck_states.has(grid_pos):
		return {}

	return get_wrapped_state_payload(world.duck_states.get(grid_pos, {}))


func get_duck_status(grid_pos: Vector2i) -> String:
	var state := get_duck_state(grid_pos)
	if state.is_empty():
		return "hungry"

	var status := str(state.get("status", "hungry")).strip_edges().to_lower()
	var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
	if next_harvest_at_ms > 0.0:
		var now_ms := Time.get_unix_time_from_system() * 1000.0
		return "ready" if now_ms >= next_harvest_at_ms else "producing"

	if bool(state.get("ready", state.get("can_harvest", false))):
		return "ready"
	if status == "ready" or status == "producing":
		return status
	return "hungry"


func get_dice_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("dice_states" in world):
		return {}
	if not world.dice_states.has(grid_pos):
		return {}

	return get_wrapped_state_payload(world.dice_states.get(grid_pos, {}))


func get_dice_face(grid_pos: Vector2i) -> int:
	var state := get_dice_state(grid_pos)
	return int(clamp(int(state.get("face", state.get("rolled_number", 1))), 1, 6))


func get_dice_face_texture_path(block_type: String, face: int) -> String:
	if world == null or not world.item_database.has(block_type):
		return ""
	var item_data = world.item_database[block_type]
	var textures = item_data.get("dice_face_textures", [])
	if not (textures is Array) or textures.is_empty():
		return str(item_data.get("texture", "")).strip_edges()

	var index = int(clamp(face, 1, textures.size())) - 1
	return str(textures[index]).strip_edges()


func get_tackle_box_remaining_ms(grid_pos: Vector2i) -> int:
	var state := get_tackle_box_state(grid_pos)
	if state.is_empty():
		return 0

	var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
	if next_harvest_at_ms > 0.0:
		var now_ms := Time.get_unix_time_from_system() * 1000.0
		return int(maxf(0.0, next_harvest_at_ms - now_ms))

	if state.has("remaining_ms"):
		return int(maxf(0.0, float(state.get("remaining_ms", 0.0))))

	return 0


func tackle_box_is_ready(grid_pos: Vector2i) -> bool:
	return get_tackle_box_remaining_ms(grid_pos) <= 0


func get_tackle_box_visual_state_frame(grid_pos: Vector2i) -> int:
	return 2 if tackle_box_is_ready(grid_pos) else 1


func clear_tackle_box_visual_animation(grid_pos: Vector2i) -> void:
	if grid_pos == NO_VARIANT_GRID_POS:
		return
	tilemap_foreground_animated_cells.erase(grid_pos)
	clear_animation_loop_particle_emitters_for_grid(grid_pos)


func water_well_is_ready(grid_pos: Vector2i) -> bool:
	return get_tackle_box_remaining_ms(grid_pos) <= 0


func get_chicken_remaining_ms(grid_pos: Vector2i) -> int:
	var state := get_chicken_state(grid_pos)
	if state.is_empty():
		return 0

	var status := get_chicken_status(grid_pos)
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	if status == "producing":
		var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
		return int(maxf(0.0, next_harvest_at_ms - now_ms))
	if status == "hungry":
		var dies_at_ms := float(state.get("dies_at_ms", state.get("starves_at_ms", 0.0)))
		if dies_at_ms > 0.0:
			return int(maxf(0.0, dies_at_ms - now_ms))

	if state.has("remaining_ms"):
		return int(maxf(0.0, float(state.get("remaining_ms", 0.0))))

	return 0


func get_cow_remaining_ms(grid_pos: Vector2i) -> int:
	var state := get_cow_state(grid_pos)
	if state.is_empty():
		return 0

	var status := get_cow_status(grid_pos)
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	if status == "producing":
		var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
		return int(maxf(0.0, next_harvest_at_ms - now_ms))
	if status == "hungry":
		var dies_at_ms := float(state.get("dies_at_ms", state.get("starves_at_ms", 0.0)))
		if dies_at_ms > 0.0:
			return int(maxf(0.0, dies_at_ms - now_ms))

	if state.has("remaining_ms"):
		return int(maxf(0.0, float(state.get("remaining_ms", 0.0))))

	return 0

func get_duck_remaining_ms(grid_pos: Vector2i) -> int:
	var state := get_duck_state(grid_pos)
	if state.is_empty():
		return 0

	var status := get_duck_status(grid_pos)
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	if status == "producing":
		var next_harvest_at_ms := float(state.get("next_harvest_at_ms", state.get("next_ready_at_ms", 0.0)))
		return int(maxf(0.0, next_harvest_at_ms - now_ms))
	if status == "hungry":
		var dies_at_ms := float(state.get("dies_at_ms", state.get("starves_at_ms", 0.0)))
		if dies_at_ms > 0.0:
			return int(maxf(0.0, dies_at_ms - now_ms))

	if state.has("remaining_ms"):
		return int(maxf(0.0, float(state.get("remaining_ms", 0.0))))

	return 0


func chicken_is_ready(grid_pos: Vector2i) -> bool:
	return get_chicken_status(grid_pos) == "ready"


func chicken_can_feed(grid_pos: Vector2i) -> bool:
	return get_chicken_status(grid_pos) == "hungry"


func cow_is_ready(grid_pos: Vector2i) -> bool:
	return get_cow_status(grid_pos) == "ready"


func cow_can_feed(grid_pos: Vector2i) -> bool:
	return get_cow_status(grid_pos) == "hungry"

func duck_is_ready(grid_pos: Vector2i) -> bool:
	return get_duck_status(grid_pos) == "ready"


func duck_can_feed(grid_pos: Vector2i) -> bool:
	return get_duck_status(grid_pos) == "hungry"


func get_chicken_timer_text(grid_pos: Vector2i) -> String:
	var status := get_chicken_status(grid_pos)
	if status == "ready":
		return "Chicken ready"
	if status == "producing":
		return "Chicken producing " + format_tackle_box_remaining_time(get_chicken_remaining_ms(grid_pos))
	return "Chicken hungry " + format_tackle_box_remaining_time(get_chicken_remaining_ms(grid_pos))


func get_cow_timer_text(grid_pos: Vector2i) -> String:
	var status := get_cow_status(grid_pos)
	if status == "ready":
		return "Cow ready"
	if status == "producing":
		return "Cow producing " + format_tackle_box_remaining_time(get_cow_remaining_ms(grid_pos))
	return "Cow hungry " + format_tackle_box_remaining_time(get_cow_remaining_ms(grid_pos))

func get_duck_timer_text(grid_pos: Vector2i) -> String:
	var status := get_duck_status(grid_pos)
	if status == "ready":
		return "Duck ready"
	if status == "producing":
		return "Duck producing " + format_tackle_box_remaining_time(get_duck_remaining_ms(grid_pos))
	return "Duck hungry " + format_tackle_box_remaining_time(get_duck_remaining_ms(grid_pos))


func get_water_well_timer_text(grid_pos: Vector2i) -> String:
	var remaining_ms := get_tackle_box_remaining_ms(grid_pos)
	return "Ready" if remaining_ms <= 0 else format_tackle_box_remaining_time(remaining_ms)


func get_atm_machine_timer_text(grid_pos: Vector2i) -> String:
	var remaining_ms := get_tackle_box_remaining_ms(grid_pos)
	return "ATM Ready" if remaining_ms <= 0 else "ATM " + format_tackle_box_remaining_time(remaining_ms)


func format_tackle_box_remaining_time(remaining_ms: int) -> String:
	var total_seconds := int(ceil(float(max(0, remaining_ms)) / 1000.0))
	var hours := int(float(total_seconds) / 3600.0)
	var minutes := int(float(total_seconds % 3600) / 60.0)
	var seconds := int(total_seconds % 60)
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func setup_tackle_box_timer_label() -> void:
	if world == null or world.ui_layer == null:
		return

	var old_label = world.ui_layer.get_node_or_null("TackleBoxTimerLabel")
	if old_label != null:
		old_label.queue_free()

	tackle_box_timer_label = Label.new()
	tackle_box_timer_label.name = "TackleBoxTimerLabel"
	tackle_box_timer_label.size = Vector2(TACKLE_BOX_TIMER_LABEL_WIDTH, TACKLE_BOX_TIMER_LABEL_HEIGHT)
	tackle_box_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tackle_box_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tackle_box_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tackle_box_timer_label.z_index = 72
	tackle_box_timer_label.add_theme_font_size_override("font_size", TACKLE_BOX_TIMER_FONT_SIZE)
	tackle_box_timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	tackle_box_timer_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	tackle_box_timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	tackle_box_timer_label.add_theme_constant_override("outline_size", TACKLE_BOX_TIMER_OUTLINE_SIZE)
	tackle_box_timer_label.add_theme_constant_override("shadow_offset_x", 1)
	tackle_box_timer_label.add_theme_constant_override("shadow_offset_y", 1)
	tackle_box_timer_label.visible = false
	world.ui_layer.add_child(tackle_box_timer_label)


func hide_tackle_box_timer_label() -> void:
	if tackle_box_timer_label != null and is_instance_valid(tackle_box_timer_label):
		tackle_box_timer_label.visible = false


func update_tackle_box_timer_hover() -> void:
	if world == null:
		hide_tackle_box_timer_label()
		return
	if tackle_box_timer_label == null or not is_instance_valid(tackle_box_timer_label):
		setup_tackle_box_timer_label()
	if tackle_box_timer_label == null:
		return
	if world.player == null:
		hide_tackle_box_timer_label()
		return

	var player_grid: Vector2i = world.get_player_grid_position()
	if not world.blocks.has(player_grid):
		hide_tackle_box_timer_label()
		return

	var block_data = world.blocks.get(player_grid, {})
	if not (block_data is Dictionary):
		hide_tackle_box_timer_label()
		return

	var block_type := str(block_data.get("type", ""))
	var is_tackle_box := is_tackle_box_block_type(block_type)
	var is_chicken := is_chicken_block_type(block_type)
	var is_cow := is_cow_block_type(block_type)
	var is_duck := is_duck_block_type(block_type)
	var is_water_well := is_water_well_block_type(block_type)
	var is_atm_machine := is_atm_machine_block_type(block_type)
	if not is_tackle_box and not is_chicken and not is_cow and not is_duck and not is_water_well and not is_atm_machine:
		hide_tackle_box_timer_label()
		return

	if is_chicken:
		tackle_box_timer_label.text = get_chicken_timer_text(player_grid)
	elif is_cow:
		tackle_box_timer_label.text = get_cow_timer_text(player_grid)
	elif is_duck:
		tackle_box_timer_label.text = get_duck_timer_text(player_grid)
	elif is_water_well:
		tackle_box_timer_label.text = get_water_well_timer_text(player_grid)
	elif is_atm_machine:
		tackle_box_timer_label.text = get_atm_machine_timer_text(player_grid)
	else:
		var remaining_ms := get_tackle_box_remaining_ms(player_grid)
		tackle_box_timer_label.text = "Tackle Box Ready" if remaining_ms <= 0 else "Tackle Box " + format_tackle_box_remaining_time(remaining_ms)
	tackle_box_timer_label.size = Vector2(TACKLE_BOX_TIMER_LABEL_WIDTH, TACKLE_BOX_TIMER_LABEL_HEIGHT)

	var canvas_transform = world.get_viewport().get_canvas_transform()
	var world_pos = Vector2(
		player_grid.x * world.BLOCK_SIZE,
		player_grid.y * world.BLOCK_SIZE
	) + TACKLE_BOX_TIMER_WORLD_OFFSET
	var screen_pos = canvas_transform * world_pos
	tackle_box_timer_label.position = Vector2(
		screen_pos.x - TACKLE_BOX_TIMER_LABEL_WIDTH / 2.0,
		screen_pos.y - TACKLE_BOX_TIMER_LABEL_HEIGHT / 2.0
	)
	tackle_box_timer_label.visible = true


func update_due_tackle_box_visuals() -> void:
	if world == null or not ("tackle_box_states" in world):
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms < next_tackle_box_visual_refresh_at_ms:
		return
	next_tackle_box_visual_refresh_at_ms = now_ms + TACKLE_BOX_VISUAL_REFRESH_INTERVAL_MS

	for raw_grid_pos in world.tackle_box_states.keys():
		if raw_grid_pos is Vector2i and tackle_box_is_ready(raw_grid_pos):
			update_tackle_box_visual(raw_grid_pos)


func update_due_chicken_visuals() -> void:
	if world == null or not ("chicken_states" in world):
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms < next_chicken_visual_refresh_at_ms:
		return
	next_chicken_visual_refresh_at_ms = now_ms + TACKLE_BOX_VISUAL_REFRESH_INTERVAL_MS

	for raw_grid_pos in world.chicken_states.keys():
		if raw_grid_pos is Vector2i:
			update_chicken_visual(raw_grid_pos, false)


func update_due_cow_visuals() -> void:
	if world == null or not ("cow_states" in world):
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms < next_cow_visual_refresh_at_ms:
		return
	next_cow_visual_refresh_at_ms = now_ms + TACKLE_BOX_VISUAL_REFRESH_INTERVAL_MS

	for raw_grid_pos in world.cow_states.keys():
		if raw_grid_pos is Vector2i:
			update_cow_visual(raw_grid_pos, false)

func update_due_duck_visuals() -> void:
	if world == null or not ("duck_states" in world):
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms < next_duck_visual_refresh_at_ms:
		return
	next_duck_visual_refresh_at_ms = now_ms + TACKLE_BOX_VISUAL_REFRESH_INTERVAL_MS

	for raw_grid_pos in world.duck_states.keys():
		if raw_grid_pos is Vector2i:
			update_duck_visual(raw_grid_pos, false)


func is_mailbox_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("mailbox_block", false))
	return block_type == "mail_box" or block_type == "blue_mail_box"


func is_donation_box_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("donation_box_block", false))
	return block_type.strip_edges().to_lower() == "donation_box"


func is_tackle_box_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("tackle_box_block", false))
	return block_type == "tackle_box"


func is_chicken_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("chicken_block", false))
	return block_type == "chicken"


func is_cow_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("cow_block", false))
	return block_type == "cow"

func is_duck_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("duck_block", false))
	return block_type == "duck"


func is_water_well_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("water_well_block", false))
	return block_type == "water_well"


func is_atm_machine_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("atm_machine_block", false))
	return block_type == "atm_machine"


func is_dice_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("dice_block", false))
	return block_type == "dice_block"


func is_checkpoint_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("checkpoint_block", false))
	return block_type == "checkpoint"

func is_cctv_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("cctv_block", false))
	return block_type == "cctv"


func has_anti_punch_block_in_world() -> bool:
	if world == null or not ("blocks" in world):
		return false
	for block_data_value in world.blocks.values():
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			if is_anti_punch_block_type(str(block_data.get("type", ""))):
				return true
	return false


func has_anti_talk_block_in_world() -> bool:
	if world == null or not ("blocks" in world):
		return false
	for block_data_value in world.blocks.values():
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			if is_anti_talk_block_type(str(block_data.get("type", ""))):
				return true
	return false


func has_anti_gravity_block_in_world() -> bool:
	if world == null or not ("blocks" in world):
		return false
	for block_data_value in world.blocks.values():
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			if is_anti_gravity_block_type(str(block_data.get("type", ""))):
				return true
	return false


func has_snow_repellent_block_in_world() -> bool:
	if world == null or not ("blocks" in world):
		return false
	for block_data_value in world.blocks.values():
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			if is_snow_repellent_block_type(str(block_data.get("type", ""))):
				return true
	return false


func get_current_checkpoint_world_name() -> String:
	if world == null:
		return ""
	return str(world.current_world_name).strip_edges().to_upper()


func is_checkpoint_active(grid_pos: Vector2i) -> bool:
	if world == null or not ("active_checkpoint_grid" in world) or not ("active_checkpoint_world" in world):
		return false
	var active_world := str(world.active_checkpoint_world).strip_edges().to_upper()
	return active_world != "" and active_world == get_current_checkpoint_world_name() and world.active_checkpoint_grid == grid_pos


func is_valid_checkpoint_grid(grid_pos: Vector2i) -> bool:
	if world == null or not world.is_grid_inside_world(grid_pos):
		return false
	if not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	return block_data is Dictionary and is_checkpoint_block_type(str(block_data.get("type", "")))


func get_checkpoint_texture_path(block_type: String, grid_pos: Vector2i) -> String:
	if world == null or not world.item_database.has(block_type):
		return ""
	var item_data = world.item_database[block_type]
	var texture_key := "checkpoint_active_texture" if is_checkpoint_active(grid_pos) else "checkpoint_inactive_texture"
	return str(item_data.get(texture_key, item_data.get("texture", ""))).strip_edges()


func clear_active_checkpoint_if_matches(grid_pos: Vector2i) -> void:
	if world == null or not ("active_checkpoint_grid" in world) or not ("active_checkpoint_world" in world):
		return
	if is_checkpoint_active(grid_pos):
		world.active_checkpoint_grid = world.INVALID_GRID_POS
		world.active_checkpoint_world = ""


func is_tackle_box_harvest_pending(grid_pos: Vector2i) -> bool:
	if not pending_tackle_box_harvests.has(grid_pos):
		return false

	var expires_at_ms := int(pending_tackle_box_harvests.get(grid_pos, 0))
	if Time.get_ticks_msec() < expires_at_ms:
		return true

	pending_tackle_box_harvests.erase(grid_pos)
	return false


func mark_tackle_box_harvest_pending(grid_pos: Vector2i) -> void:
	pending_tackle_box_harvests[grid_pos] = Time.get_ticks_msec() + TACKLE_BOX_HARVEST_PENDING_MS


func clear_tackle_box_harvest_pending(grid_pos: Vector2i) -> void:
	pending_tackle_box_harvests.erase(grid_pos)


func is_chicken_interaction_pending(grid_pos: Vector2i) -> bool:
	if not pending_chicken_interactions.has(grid_pos):
		return false

	var expires_at_ms := int(pending_chicken_interactions.get(grid_pos, 0))
	if Time.get_ticks_msec() < expires_at_ms:
		return true

	pending_chicken_interactions.erase(grid_pos)
	return false


func mark_chicken_interaction_pending(grid_pos: Vector2i) -> void:
	pending_chicken_interactions[grid_pos] = Time.get_ticks_msec() + CHICKEN_INTERACTION_PENDING_MS


func clear_chicken_interaction_pending(grid_pos: Vector2i) -> void:
	pending_chicken_interactions.erase(grid_pos)


func is_cow_interaction_pending(grid_pos: Vector2i) -> bool:
	if not pending_cow_interactions.has(grid_pos):
		return false

	var expires_at_ms := int(pending_cow_interactions.get(grid_pos, 0))
	if Time.get_ticks_msec() < expires_at_ms:
		return true

	pending_cow_interactions.erase(grid_pos)
	return false


func mark_cow_interaction_pending(grid_pos: Vector2i) -> void:
	pending_cow_interactions[grid_pos] = Time.get_ticks_msec() + COW_INTERACTION_PENDING_MS


func clear_cow_interaction_pending(grid_pos: Vector2i) -> void:
	pending_cow_interactions.erase(grid_pos)

func is_duck_interaction_pending(grid_pos: Vector2i) -> bool:
	if not pending_duck_interactions.has(grid_pos):
		return false

	var expires_at_ms := int(pending_duck_interactions.get(grid_pos, 0))
	if Time.get_ticks_msec() < expires_at_ms:
		return true

	pending_duck_interactions.erase(grid_pos)
	return false


func mark_duck_interaction_pending(grid_pos: Vector2i) -> void:
	pending_duck_interactions[grid_pos] = Time.get_ticks_msec() + DUCK_INTERACTION_PENDING_MS


func clear_duck_interaction_pending(grid_pos: Vector2i) -> void:
	pending_duck_interactions.erase(grid_pos)


func is_dice_roll_pending(grid_pos: Vector2i) -> bool:
	if not pending_dice_rolls.has(grid_pos):
		return false

	var expires_at_ms := int(pending_dice_rolls.get(grid_pos, 0))
	if Time.get_ticks_msec() < expires_at_ms:
		return true

	pending_dice_rolls.erase(grid_pos)
	return false


func mark_dice_roll_pending(grid_pos: Vector2i) -> void:
	pending_dice_rolls[grid_pos] = Time.get_ticks_msec() + DICE_ROLL_PENDING_MS
	mark_dice_roll_break_window(grid_pos)


func clear_dice_roll_pending(grid_pos: Vector2i) -> void:
	pending_dice_rolls.erase(grid_pos)


func is_dice_roll_break_window_active(grid_pos: Vector2i) -> bool:
	if not dice_roll_break_windows.has(grid_pos):
		return false

	var expires_at_ms := int(dice_roll_break_windows.get(grid_pos, 0))
	if Time.get_ticks_msec() < expires_at_ms:
		return true

	dice_roll_break_windows.erase(grid_pos)
	return false


func mark_dice_roll_break_window(grid_pos: Vector2i) -> void:
	dice_roll_break_windows[grid_pos] = Time.get_ticks_msec() + DICE_ROLL_BREAK_WINDOW_MS


func clear_dice_roll_break_window(grid_pos: Vector2i) -> void:
	dice_roll_break_windows.erase(grid_pos)


func initialize_tackle_box_cooldown_on_place(grid_pos: Vector2i, block_type: String = "") -> void:
	if world == null or not ("tackle_box_states" in world):
		return
	if not (world.tackle_box_states is Dictionary):
		return

	var clean_type := block_type.strip_edges()
	if clean_type == "" and world.blocks.has(grid_pos):
		var block_data = world.blocks.get(grid_pos, {})
		if block_data is Dictionary:
			clean_type = str(block_data.get("type", ""))
	var is_water_well := is_water_well_block_type(clean_type)
	var is_atm_machine := is_atm_machine_block_type(clean_type)
	if not is_tackle_box_block_type(clean_type) and not is_water_well and not is_atm_machine:
		return
	if world.tackle_box_states.has(grid_pos):
		return

	var cooldown_seconds := 43200.0 if is_atm_machine else (300.0 if is_water_well else 14400.0)
	var cooldown_key := "atm_machine_cooldown_seconds" if is_atm_machine else ("water_well_cooldown_seconds" if is_water_well else "tackle_box_cooldown_seconds")
	if world.item_database.has(clean_type):
		cooldown_seconds = maxf(0.0, float(world.item_database[clean_type].get(cooldown_key, cooldown_seconds)))
	var cooldown_ms := int(round(cooldown_seconds * 1000.0))
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var next_ms := now_ms + float(cooldown_ms)
	world.tackle_box_states[grid_pos] = {
		"state": {
			"next_harvest_at": "",
			"next_harvest_at_ms": next_ms,
			"last_harvested_at": "",
			"last_harvested_at_ms": 0.0,
			"cooldown_ms": cooldown_ms,
			"remaining_ms": cooldown_ms,
			"ready": false,
			"can_harvest": false
		}
	}
	update_tackle_box_visual(grid_pos)


func initialize_chicken_hunger_on_place(grid_pos: Vector2i, block_type: String = "") -> void:
	if world == null or not ("chicken_states" in world):
		return
	if not (world.chicken_states is Dictionary):
		return

	var clean_type := block_type.strip_edges()
	if clean_type == "" and world.blocks.has(grid_pos):
		var block_data = world.blocks.get(grid_pos, {})
		if block_data is Dictionary:
			clean_type = str(block_data.get("type", ""))
	if not is_chicken_block_type(clean_type):
		return
	if world.chicken_states.has(grid_pos):
		return

	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var dies_ms := now_ms + float(CHICKEN_HUNGER_MS)
	world.chicken_states[grid_pos] = {
		"state": {
			"status": "hungry",
			"fed_at": "",
			"fed_at_ms": 0.0,
			"next_harvest_at": "",
			"next_harvest_at_ms": 0.0,
			"last_harvested_at": "",
			"last_harvested_at_ms": 0.0,
			"hungry_since_at": "",
			"hungry_since_at_ms": now_ms,
			"dies_at": "",
			"dies_at_ms": dies_ms,
			"production_ms": CHICKEN_PRODUCTION_MS,
			"hunger_ms": CHICKEN_HUNGER_MS,
			"remaining_ms": CHICKEN_HUNGER_MS,
			"ready": false,
			"can_harvest": false,
			"can_feed": true
		}
	}
	update_chicken_visual(grid_pos)


func initialize_cow_hunger_on_place(grid_pos: Vector2i, block_type: String = "") -> void:
	if world == null or not ("cow_states" in world):
		return
	if not (world.cow_states is Dictionary):
		return

	var clean_type := block_type.strip_edges()
	if clean_type == "" and world.blocks.has(grid_pos):
		var block_data = world.blocks.get(grid_pos, {})
		if block_data is Dictionary:
			clean_type = str(block_data.get("type", ""))
	if not is_cow_block_type(clean_type):
		return
	if world.cow_states.has(grid_pos):
		return

	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var dies_ms := now_ms + float(COW_HUNGER_MS)
	world.cow_states[grid_pos] = {
		"state": {
			"status": "hungry",
			"fed_at": "",
			"fed_at_ms": 0.0,
			"next_harvest_at": "",
			"next_harvest_at_ms": 0.0,
			"last_harvested_at": "",
			"last_harvested_at_ms": 0.0,
			"hungry_since_at": "",
			"hungry_since_at_ms": now_ms,
			"dies_at": "",
			"dies_at_ms": dies_ms,
			"production_ms": COW_PRODUCTION_MS,
			"hunger_ms": COW_HUNGER_MS,
			"remaining_ms": COW_HUNGER_MS,
			"ready": false,
			"can_harvest": false,
			"can_feed": true
		}
	}
	update_cow_visual(grid_pos)

func initialize_duck_hunger_on_place(grid_pos: Vector2i, block_type: String = "") -> void:
	if world == null or not ("duck_states" in world):
		return
	if not (world.duck_states is Dictionary):
		return

	var clean_type := block_type.strip_edges()
	if clean_type == "" and world.blocks.has(grid_pos):
		var block_data = world.blocks.get(grid_pos, {})
		if block_data is Dictionary:
			clean_type = str(block_data.get("type", ""))
	if not is_duck_block_type(clean_type):
		return
	if world.duck_states.has(grid_pos):
		return

	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var dies_ms := now_ms + float(DUCK_HUNGER_MS)
	world.duck_states[grid_pos] = {
		"state": {
			"status": "hungry",
			"fed_at": "",
			"fed_at_ms": 0.0,
			"next_harvest_at": "",
			"next_harvest_at_ms": 0.0,
			"last_harvested_at": "",
			"last_harvested_at_ms": 0.0,
			"hungry_since_at": "",
			"hungry_since_at_ms": now_ms,
			"dies_at": "",
			"dies_at_ms": dies_ms,
			"production_ms": DUCK_PRODUCTION_MS,
			"hunger_ms": DUCK_HUNGER_MS,
			"remaining_ms": DUCK_HUNGER_MS,
			"ready": false,
			"can_harvest": false,
			"can_feed": true
		}
	}
	update_duck_visual(grid_pos)


func is_display_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("display_block", false))
	return block_type == "display_box" or block_type == "display_case"


func is_direct_inventory_display_block_type(block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	return clean_type == "display_box" or clean_type == "display_case"


func is_fish_hanger_block_type(block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "fish_hanger":
		return true
	if world != null and world.item_database.has(clean_type):
		return bool(world.item_database[clean_type].get("fish_hanger_block", false))
	return false


func is_display_transaction_pending(grid_pos: Vector2i) -> bool:
	if not pending_display_transactions.has(grid_pos):
		return false
	var pending_until := int(pending_display_transactions.get(grid_pos, 0))
	if pending_until > Time.get_ticks_msec():
		return true

	pending_display_transactions.erase(grid_pos)
	var request_ids_to_clear: Array = pending_display_transaction_requests.keys()
	for request_id in request_ids_to_clear:
		if pending_display_transaction_requests.get(request_id, null) == grid_pos:
			pending_display_transaction_requests.erase(request_id)
	return false


func mark_display_transaction_pending(grid_pos: Vector2i, request_id: String = "") -> void:
	pending_display_transactions[grid_pos] = Time.get_ticks_msec() + DISPLAY_TRANSACTION_PENDING_MS
	if request_id != "":
		pending_display_transaction_requests[request_id] = grid_pos


func clear_display_transaction_pending(grid_pos: Vector2i) -> void:
	pending_display_transactions.erase(grid_pos)
	var request_ids_to_clear: Array = pending_display_transaction_requests.keys()
	for request_id in request_ids_to_clear:
		if pending_display_transaction_requests.get(request_id, null) == grid_pos:
			pending_display_transaction_requests.erase(request_id)


func clear_display_transaction_pending_for_request_id(request_id: String) -> void:
	var normalized_request_id := str(request_id).strip_edges()
	if normalized_request_id == "":
		return
	if not pending_display_transaction_requests.has(normalized_request_id):
		return
	var grid_pos = pending_display_transaction_requests.get(normalized_request_id, null)
	pending_display_transaction_requests.erase(normalized_request_id)
	if grid_pos is Vector2i:
		pending_display_transactions.erase(grid_pos)


func make_display_request_id(action: String, grid_pos: Vector2i) -> String:
	display_request_sequence += 1
	return "display_%s_%d_%d_%d_%d" % [action, grid_pos.x, grid_pos.y, Time.get_ticks_msec(), display_request_sequence]


func try_display_selected_item_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
	if not is_direct_inventory_display_block_type(block_type):
		return false

	var item_id := str(world.selected_item_type).strip_edges()
	var item_category := str(world.selected_item_category).strip_edges().to_lower()
	if item_id == "" or item_category == "" or item_category == "empty":
		return false
	if item_category == "tool" and (item_id == "punch" or item_id == "wrench"):
		return false
	if world.get_item_count(item_id, item_category) <= 0:
		world.show_notification("You do not have that item.")
		return true
	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away from the display.")
		return true
	if world.has_method("can_current_player_interact_with_block_at") and not world.can_current_player_interact_with_block_at(block_type, grid_pos):
		world.show_notification("Only the world owner can use this display.")
		return true
	if is_display_transaction_pending(grid_pos):
		return true
	if not get_display_slot(grid_pos).is_empty():
		world.show_notification("Punch the display to take its item back first.")
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Connection required.")
		return true
	var request_id := make_display_request_id("deposit", grid_pos)

	mark_display_transaction_pending(grid_pos, request_id)
	var sent := bool(network.send_inventory_transaction_request({
		"action": "display_deposit",
		"request_id": request_id,
		"world": world.current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"item_id": item_id,
		"item_type": item_id,
		"item_category": item_category,
		"amount": 1
	}))
	if not sent:
		pending_display_transaction_requests.erase(request_id)
		pending_display_transactions.erase(grid_pos)
		world.show_notification("Could not display that item yet.")
	return true


func try_withdraw_display_item_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
	if not is_direct_inventory_display_block_type(block_type):
		return false
	if is_display_transaction_pending(grid_pos):
		return true

	var slot := get_display_slot(grid_pos)
	if slot.is_empty():
		return false
	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away from the display.")
		return true
	if world.has_method("can_current_player_interact_with_block_at") and not world.can_current_player_interact_with_block_at(block_type, grid_pos):
		world.show_notification("Only the world owner can use this display.")
		return true
	var item_id := str(slot.get("item_id", slot.get("item_type", ""))).strip_edges()
	var item_category := str(slot.get("item_category", "block")).strip_edges().to_lower()
	if item_id == "":
		return false
	if item_category == "":
		item_category = "block"

	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Connection required.")
		return true
	var request_id := make_display_request_id("withdraw", grid_pos)

	mark_display_transaction_pending(grid_pos, request_id)
	var sent := bool(network.send_inventory_transaction_request({
		"action": "display_withdraw",
		"request_id": request_id,
		"world": world.current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"item_id": item_id,
		"item_type": item_id,
		"item_category": item_category,
		"amount": 1
	}))
	if not sent:
		pending_display_transaction_requests.erase(request_id)
		pending_display_transactions.erase(grid_pos)
		world.show_notification("Could not take that item yet.")
	return true


func try_display_selected_fish_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary) or not is_fish_hanger_block_type(str(block_data.get("type", ""))):
		return false

	if str(world.selected_item_category).strip_edges().to_lower() != "fish":
		return false
	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away from the Fish Hanger.")
		return true
	if world.has_method("can_current_player_interact_with_block_at") and not world.can_current_player_interact_with_block_at("fish_hanger", grid_pos):
		world.show_notification("Only the world owner can use this Fish Hanger.")
		return true
	if is_display_transaction_pending(grid_pos):
		return true
	if not get_display_slot(grid_pos).is_empty():
		world.show_notification("Punch the Fish Hanger to take its fish back first.")
		return true

	var fish_item_id := str(world.selected_item_type).strip_edges()
	if fish_item_id == "" or world.get_item_count(fish_item_id, "fish") <= 0:
		world.show_notification("You do not have that fish.")
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Connection required.")
		return true
	var request_id := make_display_request_id("fish_deposit", grid_pos)

	mark_display_transaction_pending(grid_pos, request_id)
	var sent := bool(network.send_inventory_transaction_request({
		"action": "display_deposit",
		"request_id": request_id,
		"world": world.current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"item_id": fish_item_id,
		"item_type": fish_item_id,
		"item_category": "fish",
		"amount": 1
	}))
	if not sent:
		pending_display_transaction_requests.erase(request_id)
		pending_display_transactions.erase(grid_pos)
		world.show_notification("Could not display that fish yet.")
	return true


func try_withdraw_fish_hanger_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary) or not is_fish_hanger_block_type(str(block_data.get("type", ""))):
		return false

	var slot := get_display_slot(grid_pos)
	if slot.is_empty():
		return false
	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away from the Fish Hanger.")
		return true
	if world.has_method("can_current_player_interact_with_block_at") and not world.can_current_player_interact_with_block_at("fish_hanger", grid_pos):
		world.show_notification("Only the world owner can use this Fish Hanger.")
		return true
	if is_display_transaction_pending(grid_pos):
		return true

	var item_id := str(slot.get("item_id", slot.get("item_type", ""))).strip_edges()
	var item_category := str(slot.get("item_category", "fish")).strip_edges().to_lower()
	if item_id == "":
		return false
	if item_category == "":
		item_category = "fish"

	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Connection required.")
		return true
	var request_id := make_display_request_id("fish_withdraw", grid_pos)

	mark_display_transaction_pending(grid_pos, request_id)
	var sent := bool(network.send_inventory_transaction_request({
		"action": "display_withdraw",
		"request_id": request_id,
		"world": world.current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"item_id": item_id,
		"item_type": item_id,
		"item_category": item_category,
		"amount": 1
	}))
	if not sent:
		pending_display_transaction_requests.erase(request_id)
		pending_display_transactions.erase(grid_pos)
		world.show_notification("Could not take that fish yet.")
	return true


func is_anti_punch_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("anti_punch_block", false))
	return block_type == "anti_punch"


func get_anti_punch_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("anti_punch_states" in world):
		return {}
	if not world.anti_punch_states.has(grid_pos):
		return {}
	return get_wrapped_state_payload(world.anti_punch_states.get(grid_pos, {}))


func is_anti_punch_grid_enabled(grid_pos: Vector2i) -> bool:
	return bool(get_anti_punch_state(grid_pos).get("enabled", false))


func is_anti_punch_enabled() -> bool:
	if world == null or not ("anti_punch_states" in world):
		return false

	for raw_grid_pos in world.anti_punch_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		if not world.blocks.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if not (block_data is Dictionary):
			continue
		if not is_anti_punch_block_type(str(block_data.get("type", ""))):
			continue
		if is_anti_punch_grid_enabled(raw_grid_pos):
			return true

	return false


func get_anti_punch_enabled_frames(block_type: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if world == null or not world.item_database.has(block_type):
		return frames

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("anti_punch_enabled_frames", [])
	if not (frame_paths is Array):
		return frames

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture != null:
			frames.append(texture)

	return frames


func is_anti_talk_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("anti_talk_block", false))
	return block_type == "anti_talk"


func get_anti_talk_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("anti_talk_states" in world):
		return {}
	if not world.anti_talk_states.has(grid_pos):
		return {}
	return get_wrapped_state_payload(world.anti_talk_states.get(grid_pos, {}))


func is_anti_talk_grid_enabled(grid_pos: Vector2i) -> bool:
	return bool(get_anti_talk_state(grid_pos).get("enabled", false))


func is_anti_talk_enabled() -> bool:
	if world == null or not ("anti_talk_states" in world):
		return false

	for raw_grid_pos in world.anti_talk_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		if not world.blocks.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if not (block_data is Dictionary):
			continue
		if not is_anti_talk_block_type(str(block_data.get("type", ""))):
			continue
		if is_anti_talk_grid_enabled(raw_grid_pos):
			return true

	return false


func get_anti_talk_enabled_frames(block_type: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if world == null or not world.item_database.has(block_type):
		return frames

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("anti_talk_enabled_frames", [])
	if not (frame_paths is Array):
		return frames

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture != null:
			frames.append(texture)

	return frames


func is_anti_gravity_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("anti_gravity_block", false))
	return block_type == "anti_gravity"


func is_snow_repellent_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("snow_repellent_block", false))
	return block_type == "snow_repellent"


func is_theme_machine_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("theme_machine_block", false))
	var clean_type := block_type.strip_edges().to_lower()
	return clean_type == "night_theme_machine" or clean_type == "snow_theme_machine" or clean_type == "theme_machine"


func get_theme_machine_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("theme_machine_states" in world):
		return {}
	if not world.theme_machine_states.has(grid_pos):
		return {}
	return get_wrapped_state_payload(world.theme_machine_states.get(grid_pos, {}))


func is_theme_machine_grid_enabled(grid_pos: Vector2i) -> bool:
	return bool(get_theme_machine_state(grid_pos).get("enabled", false))


func get_theme_machine_theme(grid_pos: Vector2i) -> String:
	var theme := str(get_theme_machine_state(grid_pos).get("theme", "night")).strip_edges().to_lower()
	return "night" if theme == "" else theme


func get_theme_machine_theme_label(theme_name: String) -> String:
	var clean_theme := theme_name.strip_edges().to_lower()
	if clean_theme == "snow":
		return "Snow"
	if clean_theme == "night":
		return "Night"
	return clean_theme.capitalize()


func disable_other_theme_machines(active_grid_pos: Vector2i):
	if world == null or not ("theme_machine_states" in world) or not (world.theme_machine_states is Dictionary):
		return

	var disabled_positions: Array[Vector2i] = []
	for raw_grid_pos in world.theme_machine_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		if grid_pos != active_grid_pos:
			disabled_positions.append(grid_pos)

	for grid_pos in disabled_positions:
		world.theme_machine_states.erase(grid_pos)
		update_theme_machine_visual(grid_pos)


func is_theme_machine_enabled() -> bool:
	if world == null or not ("theme_machine_states" in world):
		return false

	for raw_grid_pos in world.theme_machine_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		if not world.blocks.has(grid_pos):
			continue
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue
		if not is_theme_machine_block_type(str(block_data.get("type", ""))):
			continue
		if is_theme_machine_grid_enabled(grid_pos):
			return true

	return false


func refresh_world_background_theme_from_machines():
	if world == null:
		return
	var active_theme := ""
	if "theme_machine_states" in world and world.theme_machine_states is Dictionary:
		for raw_grid_pos in world.theme_machine_states.keys():
			if not (raw_grid_pos is Vector2i):
				continue
			var grid_pos: Vector2i = raw_grid_pos
			if not world.blocks.has(grid_pos):
				continue
			var block_data = world.blocks.get(grid_pos, {})
			if not (block_data is Dictionary):
				continue
			if not is_theme_machine_block_type(str(block_data.get("type", ""))):
				continue
			if is_theme_machine_grid_enabled(grid_pos):
				active_theme = get_theme_machine_theme(grid_pos)
				break
	if world.has_method("apply_world_background_theme"):
		world.apply_world_background_theme(active_theme)


func apply_theme_machine_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false, theme_name: String = "night") -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary) or not is_theme_machine_block_type(str(block_data.get("type", ""))):
		return false

	var clean_theme := theme_name.strip_edges().to_lower()
	if clean_theme == "":
		clean_theme = "night"

	if enabled:
		disable_other_theme_machines(grid_pos)
		world.theme_machine_states[grid_pos] = {"state": {"enabled": true, "theme": clean_theme}}
	else:
		world.theme_machine_states.erase(grid_pos)

	update_theme_machine_visual(grid_pos)
	refresh_world_background_theme_from_machines()

	if notify and world.has_method("show_notification"):
		var theme_label := get_theme_machine_theme_label(clean_theme)
		world.show_notification(theme_label + " theme enabled." if enabled else theme_label + " theme disabled.")

	if send_network:
		var network = get_network_manager()
		if network != null and network.has_method("send_world_interaction_update"):
			network.send_world_interaction_update({
				"action": "theme_machine_state",
				"x": grid_pos.x,
				"y": grid_pos.y,
				"enabled": enabled,
				"theme": clean_theme
			}, world.current_world_name)

	return true


func get_theme_machine_enabled_frames(block_type: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if world == null or not world.item_database.has(block_type):
		return frames

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("theme_machine_enabled_frames", [])
	if not (frame_paths is Array):
		return frames

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			frames.append(texture)

	return frames


func clear_theme_machine_animation(grid_pos: Vector2i):
	tilemap_foreground_animated_cells.erase(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		var visual = block_node.get_node_or_null("Visual")
		if visual is Sprite2D:
			clear_block_animation(block_node, visual)


func update_theme_machine_visual(grid_pos: Vector2i):
	clear_theme_machine_animation(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_theme_machine_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
		if is_theme_machine_grid_enabled(grid_pos):
			start_theme_machine_animation(grid_pos, block_node, block_type)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
		if is_theme_machine_grid_enabled(grid_pos):
			start_tilemap_theme_machine_animation(grid_pos, block_type)


func start_theme_machine_animation(_grid_pos: Vector2i, block_node: Node, block_type: String):
	if block_node == null or not is_instance_valid(block_node):
		return
	var visual = block_node.get_node_or_null("Visual")
	if not (visual is Sprite2D):
		return
	var frames: Array[Texture2D] = get_theme_machine_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	var frame_seconds = max(0.03, float(item_data.get("theme_machine_frame_seconds", 0.45)))
	visual.set_meta("animation_frames", frames)
	visual.set_meta("animation_frame_index", -1)
	animated_block_visuals[visual.get_instance_id()] = {
		"visual": visual,
		"frames": frames,
		"frame_seconds": frame_seconds,
		"block_type": block_type
	}
	apply_synced_block_animation_frame(visual, frames, frame_seconds, true, block_type)


func start_tilemap_theme_machine_animation(grid_pos: Vector2i, block_type: String):
	var frames: Array[Texture2D] = get_theme_machine_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": block_type,
		"frames": frames,
		"frame_seconds": max(0.03, float(item_data.get("theme_machine_frame_seconds", 0.45))),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": false
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func get_anti_gravity_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("anti_gravity_states" in world):
		return {}
	if not world.anti_gravity_states.has(grid_pos):
		return {}
	return get_wrapped_state_payload(world.anti_gravity_states.get(grid_pos, {}))


func is_anti_gravity_grid_enabled(grid_pos: Vector2i) -> bool:
	return bool(get_anti_gravity_state(grid_pos).get("enabled", false))


func is_anti_gravity_enabled() -> bool:
	if world == null or not ("anti_gravity_states" in world):
		return false

	for raw_grid_pos in world.anti_gravity_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		if not world.blocks.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if not (block_data is Dictionary):
			continue
		if not is_anti_gravity_block_type(str(block_data.get("type", ""))):
			continue
		if is_anti_gravity_grid_enabled(raw_grid_pos):
			return true

	return false


func get_anti_gravity_enabled_frames(block_type: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if world == null or not world.item_database.has(block_type):
		return frames

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("anti_gravity_enabled_frames", [])
	if not (frame_paths is Array):
		return frames

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture != null:
			frames.append(texture)

	return frames


func update_cctv_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_cctv_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)


func refresh_all_cctv_visuals():
	if world == null or not ("blocks" in world):
		return

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_cctv_block_type(str(block_data.get("type", ""))):
			update_cctv_visual(raw_grid_pos)


func update_mailbox_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_mailbox_block_type(block_type):
		return
	clear_mailbox_visual_animation(grid_pos)
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif materialize_foreground_block_node(grid_pos):
		var refreshed_data = world.blocks.get(grid_pos, {})
		if refreshed_data is Dictionary:
			var refreshed_node = refreshed_data.get("node", null)
			if refreshed_node != null and is_instance_valid(refreshed_node):
				set_block_texture(refreshed_node, block_type, grid_pos, false)
	clear_mailbox_visual_animation(grid_pos)


func refresh_all_mailbox_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "mailbox_states" in world and world.mailbox_states is Dictionary:
		for raw_grid_pos in world.mailbox_states.keys():
			if raw_grid_pos is Vector2i:
				update_mailbox_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_mailbox_block_type(str(block_data.get("type", ""))):
			update_mailbox_visual(raw_grid_pos)


func update_donation_box_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type := str(block_data.get("type", ""))
	if not is_donation_box_block_type(block_type):
		return
	tilemap_foreground_animated_cells.erase(grid_pos)
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif materialize_foreground_block_node(grid_pos):
		var refreshed_data = world.blocks.get(grid_pos, {})
		if refreshed_data is Dictionary:
			var refreshed_node = refreshed_data.get("node", null)
			if refreshed_node != null and is_instance_valid(refreshed_node):
				set_block_texture(refreshed_node, block_type, grid_pos, false)
	tilemap_foreground_animated_cells.erase(grid_pos)


func refresh_all_donation_box_visuals():
	if world == null or not ("blocks" in world):
		return
	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_donation_box_block_type(str(block_data.get("type", ""))):
			update_donation_box_visual(raw_grid_pos)


func update_vending_machine_visual(grid_pos: Vector2i):
	# The base block tile (empty/full/sold atlas coords from get_vending_machine_atlas_data)
	# is baked into this block's own Sprite2D texture at draw time -- it does not
	# repaint itself just because world.vending_states changed. Without this, players had
	# to leave and rejoin the world to see a vending machine flip between empty/listed/sold,
	# because rejoining is what re-runs set_block_texture() for every block from scratch.
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type := str(block_data.get("type", ""))
	var item_data := get_block_item_data(block_type)
	if not bool(item_data.get("vending_machine_block", false)):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif materialize_foreground_block_node(grid_pos):
		var refreshed_data = world.blocks.get(grid_pos, {})
		if refreshed_data is Dictionary:
			var refreshed_node = refreshed_data.get("node", null)
			if refreshed_node != null and is_instance_valid(refreshed_node):
				set_block_texture(refreshed_node, block_type, grid_pos, false)


func update_tackle_box_visual(grid_pos: Vector2i):
	clear_tackle_box_harvest_pending(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_tackle_box_block_type(block_type) and not is_water_well_block_type(block_type) and not is_atm_machine_block_type(block_type):
		return
	if is_tackle_box_block_type(block_type):
		clear_tackle_box_visual_animation(grid_pos)
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif is_tackle_box_block_type(block_type) and materialize_foreground_block_node(grid_pos):
		var refreshed_data = world.blocks.get(grid_pos, {})
		if refreshed_data is Dictionary:
			var refreshed_node = refreshed_data.get("node", null)
			if refreshed_node != null and is_instance_valid(refreshed_node):
				set_block_texture(refreshed_node, block_type, grid_pos, false)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
	if is_tackle_box_block_type(block_type):
		clear_tackle_box_visual_animation(grid_pos)


func update_chicken_visual(grid_pos: Vector2i, clear_pending := true):
	if clear_pending:
		clear_chicken_interaction_pending(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_chicken_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)


func update_cow_visual(grid_pos: Vector2i, clear_pending := true):
	if clear_pending:
		clear_cow_interaction_pending(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_cow_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)

func update_duck_visual(grid_pos: Vector2i, clear_pending := true):
	if clear_pending:
		clear_duck_interaction_pending(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_duck_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)


func refresh_all_tackle_box_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "tackle_box_states" in world and world.tackle_box_states is Dictionary:
		for raw_grid_pos in world.tackle_box_states.keys():
			if raw_grid_pos is Vector2i:
				update_tackle_box_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary:
			var block_type := str(block_data.get("type", ""))
			if is_tackle_box_block_type(block_type) or is_water_well_block_type(block_type) or is_atm_machine_block_type(block_type):
				update_tackle_box_visual(raw_grid_pos)


func refresh_all_chicken_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "chicken_states" in world and world.chicken_states is Dictionary:
		for raw_grid_pos in world.chicken_states.keys():
			if raw_grid_pos is Vector2i:
				update_chicken_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_chicken_block_type(str(block_data.get("type", ""))):
			update_chicken_visual(raw_grid_pos)


func refresh_all_cow_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "cow_states" in world and world.cow_states is Dictionary:
		for raw_grid_pos in world.cow_states.keys():
			if raw_grid_pos is Vector2i:
				update_cow_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_cow_block_type(str(block_data.get("type", ""))):
			update_cow_visual(raw_grid_pos)

func refresh_all_duck_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "duck_states" in world and world.duck_states is Dictionary:
		for raw_grid_pos in world.duck_states.keys():
			if raw_grid_pos is Vector2i:
				update_duck_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_duck_block_type(str(block_data.get("type", ""))):
			update_duck_visual(raw_grid_pos)


func update_dice_visual(grid_pos: Vector2i):
	clear_dice_roll_pending(grid_pos)
	if dice_active_rolls.has(grid_pos):
		return
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_dice_block_type(block_type):
		return
	var face := get_dice_face(grid_pos)
	var texture = AtlasTextureFactory.load_texture(get_dice_face_texture_path(block_type, face))
	if texture == null:
		return
	apply_dice_texture_frame(grid_pos, block_type, texture)


func reset_dice_visual_on_place(grid_pos: Vector2i, block_type: String = ""):
	var clean_type := str(block_type).strip_edges()
	if clean_type == "" and world != null and world.blocks.has(grid_pos):
		var block_data = world.blocks.get(grid_pos, {})
		if block_data is Dictionary:
			clean_type = str(block_data.get("type", ""))
	if not is_dice_block_type(clean_type):
		return

	clear_dice_roll_pending(grid_pos)
	clear_dice_roll_break_window(grid_pos)
	dice_active_rolls.erase(grid_pos)
	if world != null and "dice_states" in world:
		world.dice_states.erase(grid_pos)
	update_dice_visual(grid_pos)


func refresh_all_dice_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "dice_states" in world and world.dice_states is Dictionary:
		for raw_grid_pos in world.dice_states.keys():
			if raw_grid_pos is Vector2i:
				update_dice_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_dice_block_type(str(block_data.get("type", ""))):
			update_dice_visual(raw_grid_pos)


func update_checkpoint_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_checkpoint_block_type(block_type):
		return
	var metadata := get_block_tilemap_metadata(block_type, block_type, grid_pos, false)
	if metadata_has_tilemap_atlas_coords(metadata):
		var renderer = ensure_tilemap_renderer()
		if renderer != null and sync_renderer_block_visual_cell(renderer, grid_pos, null, metadata, false, should_block_cast_texture_shadow(block_type, false), "checkpoint_state"):
			var block_node = block_data.get("node", null)
			if block_node != null and is_instance_valid(block_node):
				var visual = block_node.get_node_or_null("Visual")
				if visual is Sprite2D:
					(visual as Sprite2D).visible = false
				block_node.set_meta("tilemap_visual", true)
				remove_block_texture_shadow(block_node)
			return
	var texture = AtlasTextureFactory.load_texture(get_checkpoint_texture_path(block_type, grid_pos))
	if texture == null:
		return
	apply_dice_texture_frame(grid_pos, block_type, texture)


func refresh_all_checkpoint_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if is_valid_checkpoint_grid(world.active_checkpoint_grid):
		update_checkpoint_visual(world.active_checkpoint_grid)
		refreshed[world.active_checkpoint_grid] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_checkpoint_block_type(str(block_data.get("type", ""))):
			update_checkpoint_visual(raw_grid_pos)


func apply_checkpoint_activation(grid_pos: Vector2i, notify: bool = false, send_network: bool = false) -> bool:
	if world == null or not is_valid_checkpoint_grid(grid_pos):
		return false

	var previous_grid: Vector2i = world.active_checkpoint_grid
	var previous_world := str(world.active_checkpoint_world).strip_edges().to_upper()
	var current_world := get_current_checkpoint_world_name()
	var already_active := previous_world == current_world and previous_grid == grid_pos
	if already_active:
		return false

	world.active_checkpoint_grid = grid_pos
	world.active_checkpoint_world = str(world.current_world_name)

	if previous_world == current_world and previous_grid != grid_pos:
		update_checkpoint_visual(previous_grid)
	update_checkpoint_visual(grid_pos)

	if notify and world.has_method("show_notification"):
		world.show_notification("Checkpoint saved.")

	if send_network:
		var network = get_network_manager()
		if network != null and network.has_method("send_world_interaction_update"):
			network.send_world_interaction_update({
				"action": "checkpoint_activate",
				"x": grid_pos.x,
				"y": grid_pos.y
			}, world.current_world_name)

	return true


func activate_checkpoint(grid_pos: Vector2i) -> bool:
	return apply_checkpoint_activation(grid_pos, true, true)


func update_anti_punch_visual(grid_pos: Vector2i):
	clear_anti_punch_animation(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_anti_punch_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
		if is_anti_punch_grid_enabled(grid_pos):
			start_anti_punch_animation(grid_pos, block_node, block_type)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
		if is_anti_punch_grid_enabled(grid_pos):
			start_tilemap_anti_punch_animation(grid_pos, block_type)


func refresh_all_anti_punch_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "anti_punch_states" in world and world.anti_punch_states is Dictionary:
		for raw_grid_pos in world.anti_punch_states.keys():
			if raw_grid_pos is Vector2i:
				update_anti_punch_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_anti_punch_block_type(str(block_data.get("type", ""))):
			update_anti_punch_visual(raw_grid_pos)


func apply_anti_punch_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary) or not is_anti_punch_block_type(str(block_data.get("type", ""))):
		return false

	if enabled:
		world.anti_punch_states[grid_pos] = {"state": {"enabled": true}}
	else:
		world.anti_punch_states.erase(grid_pos)

	update_anti_punch_visual(grid_pos)

	if notify and world.has_method("show_notification"):
		world.show_notification("Anti-punch enabled." if enabled else "Anti-punch disabled.")

	if send_network:
		var network = get_network_manager()
		if network != null and network.has_method("send_world_interaction_update"):
			network.send_world_interaction_update({
				"action": "anti_punch_state",
				"x": grid_pos.x,
				"y": grid_pos.y,
				"enabled": enabled
			}, world.current_world_name)

	return true


func toggle_anti_punch_state(grid_pos: Vector2i) -> bool:
	return apply_anti_punch_state(grid_pos, not is_anti_punch_grid_enabled(grid_pos), true, true)


func clear_anti_punch_animation(grid_pos: Vector2i):
	if anti_punch_active_visuals.has(grid_pos):
		anti_punch_active_visuals.erase(grid_pos)
	tilemap_foreground_animated_cells.erase(grid_pos)


func start_anti_punch_animation(grid_pos: Vector2i, block_node: Node, block_type: String):
	if block_node == null or not is_instance_valid(block_node):
		return
	var visual = block_node.get_node_or_null("Visual")
	if not (visual is Sprite2D):
		return
	var frames: Array[Texture2D] = get_anti_punch_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	anti_punch_active_visuals[grid_pos] = {
		"grid_pos": grid_pos,
		"block_type": block_type,
		"visual": visual,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("anti_punch_frame_seconds", 0.18))),
		"elapsed": 0.0,
		"frame_index": -1
	}
	apply_anti_punch_animation_frame(grid_pos, true)


func start_tilemap_anti_punch_animation(grid_pos: Vector2i, block_type: String):
	var frames: Array[Texture2D] = get_anti_punch_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": block_type,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("anti_punch_frame_seconds", 0.18))),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": false
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func update_anti_punch_animations(delta: float):
	ensure_enabled_anti_punch_animation_bound()
	if anti_punch_active_visuals.is_empty():
		return

	for raw_grid_pos in anti_punch_active_visuals.keys():
		if not (raw_grid_pos is Vector2i):
			anti_punch_active_visuals.erase(raw_grid_pos)
			continue
		apply_anti_punch_animation_frame(raw_grid_pos, false, delta)


func ensure_enabled_anti_punch_animation_bound() -> void:
	if world == null or not ("anti_punch_states" in world):
		return
	for raw_grid_pos in world.anti_punch_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		if not is_anti_punch_grid_enabled(grid_pos) or not world.blocks.has(grid_pos):
			continue
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue
		var block_type := str(block_data.get("type", ""))
		if not is_anti_punch_block_type(block_type):
			continue
		var block_node: Node = null
		var node_value: Variant = block_data.get("node", null)
		if node_value is Node:
			block_node = node_value
		refresh_stateful_block_animation_after_texture_refresh(grid_pos, block_type, block_node)


func apply_anti_punch_animation_frame(grid_pos: Vector2i, force_update: bool = false, delta: float = 0.0):
	var entry_value: Variant = anti_punch_active_visuals.get(grid_pos, {})
	if not (entry_value is Dictionary):
		anti_punch_active_visuals.erase(grid_pos)
		return
	var entry: Dictionary = entry_value

	if world == null or not world.blocks.has(grid_pos) or not is_anti_punch_grid_enabled(grid_pos):
		anti_punch_active_visuals.erase(grid_pos)
		return

	var visual_value: Variant = entry.get("visual", null)
	if not (visual_value is Sprite2D) or not is_instance_valid(visual_value):
		anti_punch_active_visuals.erase(grid_pos)
		return
	var visual: Sprite2D = visual_value

	var frames_value: Variant = entry.get("frames", [])
	if not (frames_value is Array) or frames_value.size() <= 1:
		anti_punch_active_visuals.erase(grid_pos)
		return
	var frames: Array = frames_value

	var elapsed: float = float(entry.get("elapsed", 0.0)) + maxf(0.0, delta)
	entry["elapsed"] = elapsed
	var frame_seconds: float = maxf(0.03, float(entry.get("frame_seconds", 0.18)))
	var frame_index: int = int(floor(elapsed / frame_seconds)) % frames.size()
	if not force_update and int(entry.get("frame_index", -1)) == frame_index:
		anti_punch_active_visuals[grid_pos] = entry
		return

	var texture_value: Variant = frames[frame_index]
	if not (texture_value is Texture2D):
		anti_punch_active_visuals.erase(grid_pos)
		return

	entry["frame_index"] = frame_index
	anti_punch_active_visuals[grid_pos] = entry
	visual.texture = texture_value as Texture2D
	sync_block_texture_shadow_to_visual(visual)
	sync_tilemap_visual_animation_frame(visual)


func update_anti_talk_visual(grid_pos: Vector2i):
	clear_anti_talk_animation(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_anti_talk_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
		if is_anti_talk_grid_enabled(grid_pos):
			start_anti_talk_animation(grid_pos, block_node, block_type)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
		if is_anti_talk_grid_enabled(grid_pos):
			start_tilemap_anti_talk_animation(grid_pos, block_type)


func refresh_all_anti_talk_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "anti_talk_states" in world and world.anti_talk_states is Dictionary:
		for raw_grid_pos in world.anti_talk_states.keys():
			if raw_grid_pos is Vector2i:
				update_anti_talk_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_anti_talk_block_type(str(block_data.get("type", ""))):
			update_anti_talk_visual(raw_grid_pos)


func apply_anti_talk_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary) or not is_anti_talk_block_type(str(block_data.get("type", ""))):
		return false

	if enabled:
		world.anti_talk_states[grid_pos] = {"state": {"enabled": true}}
	else:
		world.anti_talk_states.erase(grid_pos)

	update_anti_talk_visual(grid_pos)

	if notify and world.has_method("show_notification"):
		world.show_notification("Anti-talk enabled." if enabled else "Anti-talk disabled.")

	if send_network:
		var network = get_network_manager()
		if network != null and network.has_method("send_world_interaction_update"):
			network.send_world_interaction_update({
				"action": "anti_talk_state",
				"x": grid_pos.x,
				"y": grid_pos.y,
				"enabled": enabled
			}, world.current_world_name)

	return true


func toggle_anti_talk_state(grid_pos: Vector2i) -> bool:
	return apply_anti_talk_state(grid_pos, not is_anti_talk_grid_enabled(grid_pos), true, true)


func clear_anti_talk_animation(grid_pos: Vector2i):
	if anti_talk_active_visuals.has(grid_pos):
		anti_talk_active_visuals.erase(grid_pos)
	tilemap_foreground_animated_cells.erase(grid_pos)


func start_anti_talk_animation(grid_pos: Vector2i, block_node: Node, block_type: String):
	if block_node == null or not is_instance_valid(block_node):
		return
	var visual = block_node.get_node_or_null("Visual")
	if not (visual is Sprite2D):
		return
	var frames: Array[Texture2D] = get_anti_talk_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	anti_talk_active_visuals[grid_pos] = {
		"grid_pos": grid_pos,
		"block_type": block_type,
		"visual": visual,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("anti_talk_frame_seconds", 0.18))),
		"elapsed": 0.0,
		"frame_index": -1
	}
	apply_anti_talk_animation_frame(grid_pos, true)


func start_tilemap_anti_talk_animation(grid_pos: Vector2i, block_type: String):
	var frames: Array[Texture2D] = get_anti_talk_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": block_type,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("anti_talk_frame_seconds", 0.18))),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": false
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func update_anti_talk_animations(delta: float):
	ensure_enabled_anti_talk_animation_bound()
	if anti_talk_active_visuals.is_empty():
		return

	for raw_grid_pos in anti_talk_active_visuals.keys():
		if not (raw_grid_pos is Vector2i):
			anti_talk_active_visuals.erase(raw_grid_pos)
			continue
		apply_anti_talk_animation_frame(raw_grid_pos, false, delta)


func ensure_enabled_anti_talk_animation_bound() -> void:
	if world == null or not ("anti_talk_states" in world):
		return
	for raw_grid_pos in world.anti_talk_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		if not is_anti_talk_grid_enabled(grid_pos) or not world.blocks.has(grid_pos):
			continue
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue
		var block_type := str(block_data.get("type", ""))
		if not is_anti_talk_block_type(block_type):
			continue
		var block_node: Node = null
		var node_value: Variant = block_data.get("node", null)
		if node_value is Node:
			block_node = node_value
		refresh_stateful_block_animation_after_texture_refresh(grid_pos, block_type, block_node)


func apply_anti_talk_animation_frame(grid_pos: Vector2i, force_update: bool = false, delta: float = 0.0):
	var entry_value: Variant = anti_talk_active_visuals.get(grid_pos, {})
	if not (entry_value is Dictionary):
		anti_talk_active_visuals.erase(grid_pos)
		return
	var entry: Dictionary = entry_value

	if world == null or not world.blocks.has(grid_pos) or not is_anti_talk_grid_enabled(grid_pos):
		anti_talk_active_visuals.erase(grid_pos)
		return

	var visual_value: Variant = entry.get("visual", null)
	if not (visual_value is Sprite2D) or not is_instance_valid(visual_value):
		anti_talk_active_visuals.erase(grid_pos)
		return
	var visual: Sprite2D = visual_value

	var frames_value: Variant = entry.get("frames", [])
	if not (frames_value is Array) or frames_value.size() <= 1:
		anti_talk_active_visuals.erase(grid_pos)
		return
	var frames: Array = frames_value

	var elapsed: float = float(entry.get("elapsed", 0.0)) + maxf(0.0, delta)
	entry["elapsed"] = elapsed
	var frame_seconds: float = maxf(0.03, float(entry.get("frame_seconds", 0.18)))
	var frame_index: int = int(floor(elapsed / frame_seconds)) % frames.size()
	if not force_update and int(entry.get("frame_index", -1)) == frame_index:
		anti_talk_active_visuals[grid_pos] = entry
		return

	var texture_value: Variant = frames[frame_index]
	if not (texture_value is Texture2D):
		anti_talk_active_visuals.erase(grid_pos)
		return

	entry["frame_index"] = frame_index
	anti_talk_active_visuals[grid_pos] = entry
	visual.texture = texture_value as Texture2D
	sync_block_texture_shadow_to_visual(visual)
	sync_tilemap_visual_animation_frame(visual)


func update_anti_gravity_visual(grid_pos: Vector2i):
	clear_anti_gravity_animation(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_anti_gravity_block_type(block_type):
		return
	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		set_block_texture(block_node, block_type, grid_pos, false)
		if is_anti_gravity_grid_enabled(grid_pos):
			start_anti_gravity_animation(grid_pos, block_node, block_type)
	elif sync_tilemap_only_foreground_block(grid_pos, block_type):
		world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
		if is_anti_gravity_grid_enabled(grid_pos):
			start_tilemap_anti_gravity_animation(grid_pos, block_type)


func refresh_all_anti_gravity_visuals():
	if world == null or not ("blocks" in world):
		return

	var refreshed: Dictionary = {}
	if "anti_gravity_states" in world and world.anti_gravity_states is Dictionary:
		for raw_grid_pos in world.anti_gravity_states.keys():
			if raw_grid_pos is Vector2i:
				update_anti_gravity_visual(raw_grid_pos)
				refreshed[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i) or refreshed.has(raw_grid_pos):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if block_data is Dictionary and is_anti_gravity_block_type(str(block_data.get("type", ""))):
			update_anti_gravity_visual(raw_grid_pos)


func apply_anti_gravity_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary) or not is_anti_gravity_block_type(str(block_data.get("type", ""))):
		return false

	if enabled:
		world.anti_gravity_states[grid_pos] = {"state": {"enabled": true}}
	else:
		world.anti_gravity_states.erase(grid_pos)

	update_anti_gravity_visual(grid_pos)

	if notify and world.has_method("show_notification"):
		world.show_notification("Anti-gravity enabled." if enabled else "Anti-gravity disabled.")

	if send_network:
		var network = get_network_manager()
		if network != null and network.has_method("send_world_interaction_update"):
			network.send_world_interaction_update({
				"action": "anti_gravity_state",
				"x": grid_pos.x,
				"y": grid_pos.y,
				"enabled": enabled
			}, world.current_world_name)

	return true


func toggle_anti_gravity_state(grid_pos: Vector2i) -> bool:
	return apply_anti_gravity_state(grid_pos, not is_anti_gravity_grid_enabled(grid_pos), true, true)


func clear_anti_gravity_animation(grid_pos: Vector2i):
	if anti_gravity_active_visuals.has(grid_pos):
		anti_gravity_active_visuals.erase(grid_pos)
	tilemap_foreground_animated_cells.erase(grid_pos)


func start_anti_gravity_animation(grid_pos: Vector2i, block_node: Node, block_type: String):
	if block_node == null or not is_instance_valid(block_node):
		return
	var visual = block_node.get_node_or_null("Visual")
	if not (visual is Sprite2D):
		return
	var frames: Array[Texture2D] = get_anti_gravity_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	anti_gravity_active_visuals[grid_pos] = {
		"grid_pos": grid_pos,
		"block_type": block_type,
		"visual": visual,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("anti_gravity_frame_seconds", 0.12))),
		"elapsed": 0.0,
		"frame_index": -1
	}
	apply_anti_gravity_animation_frame(grid_pos, true)


func start_tilemap_anti_gravity_animation(grid_pos: Vector2i, block_type: String):
	var frames: Array[Texture2D] = get_anti_gravity_enabled_frames(block_type)
	if frames.size() <= 1:
		return
	var item_data = get_block_item_data(block_type)
	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": block_type,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("anti_gravity_frame_seconds", 0.12))),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": false
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func update_anti_gravity_animations(delta: float):
	ensure_enabled_anti_gravity_animation_bound()
	if anti_gravity_active_visuals.is_empty():
		return

	for raw_grid_pos in anti_gravity_active_visuals.keys():
		if not (raw_grid_pos is Vector2i):
			anti_gravity_active_visuals.erase(raw_grid_pos)
			continue
		apply_anti_gravity_animation_frame(raw_grid_pos, false, delta)


func ensure_enabled_anti_gravity_animation_bound() -> void:
	if world == null or not ("anti_gravity_states" in world):
		return
	for raw_grid_pos in world.anti_gravity_states.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		if not is_anti_gravity_grid_enabled(grid_pos) or not world.blocks.has(grid_pos):
			continue
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue
		var block_type := str(block_data.get("type", ""))
		if not is_anti_gravity_block_type(block_type):
			continue
		var block_node: Node = null
		var node_value: Variant = block_data.get("node", null)
		if node_value is Node:
			block_node = node_value
		refresh_stateful_block_animation_after_texture_refresh(grid_pos, block_type, block_node)


func apply_anti_gravity_animation_frame(grid_pos: Vector2i, force_update: bool = false, delta: float = 0.0):
	var entry_value: Variant = anti_gravity_active_visuals.get(grid_pos, {})
	if not (entry_value is Dictionary):
		anti_gravity_active_visuals.erase(grid_pos)
		return
	var entry: Dictionary = entry_value

	if world == null or not world.blocks.has(grid_pos) or not is_anti_gravity_grid_enabled(grid_pos):
		anti_gravity_active_visuals.erase(grid_pos)
		return

	var visual_value: Variant = entry.get("visual", null)
	if not (visual_value is Sprite2D) or not is_instance_valid(visual_value):
		anti_gravity_active_visuals.erase(grid_pos)
		return
	var visual: Sprite2D = visual_value

	var frames_value: Variant = entry.get("frames", [])
	if not (frames_value is Array) or frames_value.size() <= 1:
		anti_gravity_active_visuals.erase(grid_pos)
		return
	var frames: Array = frames_value

	var elapsed: float = float(entry.get("elapsed", 0.0)) + maxf(0.0, delta)
	entry["elapsed"] = elapsed
	var frame_seconds: float = maxf(0.03, float(entry.get("frame_seconds", 0.12)))
	var frame_index: int = int(floor(elapsed / frame_seconds)) % frames.size()
	if not force_update and int(entry.get("frame_index", -1)) == frame_index:
		anti_gravity_active_visuals[grid_pos] = entry
		return

	var texture_value: Variant = frames[frame_index]
	if not (texture_value is Texture2D):
		anti_gravity_active_visuals.erase(grid_pos)
		return

	entry["frame_index"] = frame_index
	anti_gravity_active_visuals[grid_pos] = entry
	visual.texture = texture_value as Texture2D
	sync_block_texture_shadow_to_visual(visual)
	sync_tilemap_visual_animation_frame(visual)


func update_display_visual(grid_pos: Vector2i):
	pending_display_transactions.erase(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		remove_display_preview_visual(grid_pos)
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		remove_display_preview_visual(grid_pos)
		return
	var block_type := str(block_data.get("type", ""))
	if not is_display_block_type(block_type):
		remove_display_preview_visual(grid_pos)
		return

	var block_node: Node = block_data.get("node", null) as Node
	if block_node is CanvasItem:
		block_node.visible = true

	if block_node != null and is_instance_valid(block_node):
		var child_preview := block_node.get_node_or_null("DisplayItemPreview")
		if child_preview != null:
			child_preview.queue_free()

	var display_data := get_block_item_data(block_type)
	var preview_offset: Vector2 = parse_block_visual_offset(display_data.get("display_preview_offset", Vector2(0, 0)))
	var preview_position: Vector2 = Vector2(float(grid_pos.x) * float(world.BLOCK_SIZE), float(grid_pos.y) * float(world.BLOCK_SIZE)) + preview_offset
	update_display_glass_overlay(grid_pos, display_data, preview_position)

	var slot = get_display_slot(grid_pos)
	if slot.is_empty():
		remove_display_preview_item_visual(grid_pos)
		return

	var item_id = str(slot.get("item_id", slot.get("item_type", ""))).strip_edges()
	var category = str(slot.get("item_category", "block")).strip_edges()
	var texture = get_display_preview_texture(item_id, category)
	if texture == null:
		remove_display_preview_item_visual(grid_pos)
		return

	var preview := get_or_create_display_preview_visual(grid_pos)
	if preview == null:
		return

	preview.position = preview_position
	preview.texture = texture
	preview.z_index = FISH_HANGER_DISPLAY_PREVIEW_ITEM_Z_INDEX if is_fish_hanger_block_type(block_type) else DISPLAY_PREVIEW_ITEM_Z_INDEX
	var is_direct_inventory_display := is_direct_inventory_display_block_type(block_type)
	var max_size := float(display_data.get("display_preview_max_size", DEFAULT_DISPLAY_PREVIEW_MAX_SIZE))
	if is_direct_inventory_display:
		max_size = float(display_data.get("display_preview_max_size", DISPLAY_PREVIEW_INVENTORY_ICON_SIZE))
		if max_size <= 0.0:
			max_size = DISPLAY_PREVIEW_INVENTORY_ICON_SIZE
	apply_display_preview_fit(preview, texture, max_size, is_direct_inventory_display)
	preview.visible = true
	var preview_alpha := clampf(float(display_data.get("display_preview_alpha", DEFAULT_DISPLAY_PREVIEW_ALPHA)), 0.0, 1.0)
	preview.modulate = Color(1.0, 1.0, 1.0, preview_alpha)
	update_display_glass_overlay(grid_pos, display_data, preview.position)


func apply_display_preview_fit(preview: Sprite2D, texture: Texture2D, max_size: float, inventory_style := false) -> void:
	if preview == null or texture == null:
		return

	var texture_size := Vector2(float(texture.get_width()), float(texture.get_height()))
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		preview.scale = Vector2.ONE
		preview.offset = Vector2.ZERO
		return

	var target_max_size := maxf(max_size, 1.0)
	# Keep display previews for direct displays consistent with inventory slot sizing.
	if inventory_style:
		var inventory_largest_dimension := maxf(texture_size.x, texture_size.y)
		preview.scale = Vector2.ONE * (target_max_size / inventory_largest_dimension if inventory_largest_dimension > 0.0 else 1.0)
		preview.offset = Vector2.ZERO
		return

	# Keep legacy display previews consistent for every texture by basing size on the
	# source dimensions and centering the visible content so transparent padding does not drift.
	var content_rect := get_display_preview_content_rect(texture)
	var largest_dimension := maxf(texture_size.x, texture_size.y)
	preview.scale = Vector2.ONE * (target_max_size / largest_dimension if largest_dimension > 0.0 else 1.0)

	var preview_offset := Vector2.ZERO
	if content_rect.size.x > 0.0 and content_rect.size.y > 0.0:
		var content_center := content_rect.position + content_rect.size * 0.5
		preview_offset = (texture_size * 0.5) - content_center
	preview.offset = preview_offset


func get_display_preview_content_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	var texture_width := int(texture.get_width())
	var texture_height := int(texture.get_height())
	var fallback := Rect2(Vector2.ZERO, Vector2(float(texture_width), float(texture_height)))
	if texture_width <= 0 or texture_height <= 0:
		return fallback

	var cache_key := get_display_preview_texture_cache_key(texture)
	if display_preview_content_rect_cache.has(cache_key):
		var cached_rect = display_preview_content_rect_cache.get(cache_key, fallback)
		if cached_rect is Rect2:
			return cached_rect

	var scan_info := get_display_preview_scan_info(texture, texture_width, texture_height)
	var image = scan_info.get("image", null)
	if image == null or not (image is Image):
		display_preview_content_rect_cache[cache_key] = fallback
		return fallback

	var scan_image := image as Image
	if scan_image.is_compressed() and scan_image.decompress() != OK:
		display_preview_content_rect_cache[cache_key] = fallback
		return fallback

	var scan_origin: Vector2i = scan_info.get("origin", Vector2i.ZERO)
	var scan_size: Vector2i = scan_info.get("size", Vector2i(texture_width, texture_height))
	scan_origin.x = clampi(scan_origin.x, 0, max(0, scan_image.get_width() - 1))
	scan_origin.y = clampi(scan_origin.y, 0, max(0, scan_image.get_height() - 1))
	scan_size.x = clampi(scan_size.x, 0, scan_image.get_width() - scan_origin.x)
	scan_size.y = clampi(scan_size.y, 0, scan_image.get_height() - scan_origin.y)
	if scan_size.x <= 0 or scan_size.y <= 0:
		display_preview_content_rect_cache[cache_key] = fallback
		return fallback

	var min_x := scan_origin.x + scan_size.x
	var min_y := scan_origin.y + scan_size.y
	var max_x := scan_origin.x - 1
	var max_y := scan_origin.y - 1

	for y in range(scan_origin.y, scan_origin.y + scan_size.y):
		for x in range(scan_origin.x, scan_origin.x + scan_size.x):
			if scan_image.get_pixel(x, y).a <= DISPLAY_PREVIEW_ALPHA_THRESHOLD:
				continue

			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		display_preview_content_rect_cache[cache_key] = fallback
		return fallback

	var content_rect := Rect2(
		Vector2(float(min_x - scan_origin.x), float(min_y - scan_origin.y)),
		Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	)
	display_preview_content_rect_cache[cache_key] = content_rect
	return content_rect


func get_display_preview_scan_info(texture: Texture2D, texture_width: int, texture_height: int) -> Dictionary:
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
				scan_size = Vector2i(int(ceil(region.size.x)), int(ceil(region.size.y)))
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


func get_display_preview_texture_cache_key(texture: Texture2D) -> String:
	var cache_key := str(texture.get_instance_id()) + "|" + str(texture.get_width()) + "x" + str(texture.get_height())
	if texture.resource_path != "":
		cache_key += "|" + texture.resource_path
	if texture is AtlasTexture:
		cache_key += "|" + str((texture as AtlasTexture).region)
	return cache_key


func get_display_preview_layer() -> Node2D:
	if world == null:
		return null

	var layer := world.get_node_or_null(DISPLAY_PREVIEW_LAYER_NAME) as Node2D
	if layer == null:
		layer = Node2D.new()
		layer.name = DISPLAY_PREVIEW_LAYER_NAME
		world.add_child(layer)

	layer.z_as_relative = false
	layer.z_index = DISPLAY_PREVIEW_Z_INDEX
	return layer


func get_or_create_display_preview_visual(grid_pos: Vector2i) -> Sprite2D:
	var existing = display_preview_visuals.get(grid_pos, null)
	if existing is Sprite2D and is_instance_valid(existing):
		return existing

	var layer := get_display_preview_layer()
	if layer == null:
		return null

	var preview := Sprite2D.new()
	preview.name = "DisplayItemPreview_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	preview.centered = true
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.z_as_relative = true
	preview.z_index = DISPLAY_PREVIEW_ITEM_Z_INDEX
	layer.add_child(preview)
	display_preview_visuals[grid_pos] = preview
	return preview


func update_display_glass_overlay(grid_pos: Vector2i, display_data: Dictionary, center_position: Vector2) -> void:
	var alpha := clampf(float(display_data.get("display_glass_alpha", DEFAULT_DISPLAY_GLASS_ALPHA)), 0.0, 1.0)
	if alpha <= 0.0:
		remove_display_glass_visual(grid_pos)
		return

	var glass := get_or_create_display_glass_visual(grid_pos)
	if glass == null:
		return

	var block_size := float(world.BLOCK_SIZE) if world != null else 32.0
	var glass_size: Vector2 = parse_block_vector2(display_data.get("display_glass_size", Vector2(block_size, block_size)), Vector2(block_size, block_size))
	glass_size.x = maxf(1.0, glass_size.x)
	glass_size.y = maxf(1.0, glass_size.y)
	var glass_color := DEFAULT_DISPLAY_GLASS_COLOR
	glass.color = Color(glass_color.r, glass_color.g, glass_color.b, alpha)
	glass.size = glass_size
	glass.position = center_position - glass_size * 0.5
	glass.visible = alpha > 0.0


func get_or_create_display_glass_visual(grid_pos: Vector2i) -> ColorRect:
	var existing = display_preview_glass_visuals.get(grid_pos, null)
	if existing is ColorRect and is_instance_valid(existing):
		return existing

	var layer := get_display_preview_layer()
	if layer == null:
		return null

	var glass := ColorRect.new()
	glass.name = "DisplayGlassOverlay_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.z_as_relative = true
	glass.z_index = DISPLAY_PREVIEW_GLASS_Z_INDEX
	layer.add_child(glass)
	display_preview_glass_visuals[grid_pos] = glass
	return glass


func remove_display_glass_visual(grid_pos: Vector2i) -> void:
	var existing = display_preview_glass_visuals.get(grid_pos, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
	display_preview_glass_visuals.erase(grid_pos)


func remove_display_preview_item_visual(grid_pos: Vector2i) -> void:
	var existing = display_preview_visuals.get(grid_pos, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()
	display_preview_visuals.erase(grid_pos)


func remove_display_preview_visual(grid_pos: Vector2i) -> void:
	remove_display_preview_item_visual(grid_pos)
	remove_display_glass_visual(grid_pos)


func clear_display_preview_visuals() -> void:
	pending_display_transactions.clear()
	for grid_pos in display_preview_visuals.keys():
		remove_display_preview_visual(grid_pos)
	display_preview_visuals.clear()
	for grid_pos in display_preview_glass_visuals.keys():
		remove_display_glass_visual(grid_pos)
	display_preview_glass_visuals.clear()


func get_display_slot(grid_pos: Vector2i) -> Dictionary:
	if world == null or not ("display_states" in world):
		return {}
	if not world.display_states.has(grid_pos):
		return {}

	var state = get_wrapped_state_payload(world.display_states.get(grid_pos, {}))
	return normalize_display_slot_payload(state)


func normalize_display_slot_payload(state_value) -> Dictionary:
	if not (state_value is Dictionary):
		return {}

	var state: Dictionary = state_value
	for wrapper_key in ["display_state", "state"]:
		var wrapped = state.get(wrapper_key, null)
		if wrapped is Dictionary:
			var wrapped_slot = normalize_display_slot_payload(wrapped)
			if not wrapped_slot.is_empty():
				return wrapped_slot

	var slot = state.get("slot", state.get("item", state.get("display_item", {})))
	if not (slot is Dictionary):
		return {}

	var item_id := str(slot.get("item_id", slot.get("item_type", slot.get("id", "")))).strip_edges()
	if item_id == "":
		return {}
	var category := str(slot.get("item_category", slot.get("category", "block"))).strip_edges()
	if category == "":
		category = "block"

	var result: Dictionary = slot.duplicate(true)
	result["item_id"] = item_id
	result["item_type"] = item_id
	result["item_category"] = category
	result["amount"] = 1
	return result


func get_display_preview_texture(item_id: String, category: String):
	var clean_item_id := item_id.strip_edges()
	var clean_category := category.strip_edges()
	if clean_item_id == "" or world == null:
		return null
	if clean_category == "":
		clean_category = "block"

	if world.has_method("get_inventory_icon_texture"):
		var icon_texture = world.get_inventory_icon_texture(clean_item_id, clean_category)
		if icon_texture != null:
			return icon_texture

	if clean_category == "block":
		var atlas_icon := get_atlas_item_icon_texture(clean_item_id)
		if atlas_icon != null:
			return atlas_icon

	if world.item_database.has(clean_item_id):
		var item_data = world.item_database[clean_item_id]
		if item_data is Dictionary:
			var icon_texture = AtlasTextureFactory.load_texture(item_data.get("inventory_icon", null))
			if icon_texture != null:
				return icon_texture

	if world.has_method("get_item_texture"):
		var item_texture = world.get_item_texture(clean_item_id, clean_category)
		if item_texture != null:
			return item_texture

	if clean_category == "block" and world.block_textures.has(clean_item_id):
		return world.block_textures[clean_item_id]
	if clean_category == "seed" and world.seed_textures.has(clean_item_id):
		return world.seed_textures[clean_item_id]
	if clean_category == "tool" and world.tool_textures.has(clean_item_id):
		return world.tool_textures[clean_item_id]
	if clean_category == "material" and world.material_textures.has(clean_item_id):
		return world.material_textures[clean_item_id]
	if clean_category == "lure" and world.lure_textures.has(clean_item_id):
		return world.lure_textures[clean_item_id]
	if clean_category == "fish" and world.fish_textures.has(clean_item_id):
		return world.fish_textures[clean_item_id]
	if clean_category == "currency" and world.currency_textures.has(clean_item_id):
		return world.currency_textures[clean_item_id]
	if clean_category == "back" and world.back_textures.has(clean_item_id):
		return world.back_textures[clean_item_id]
	if clean_category == "hat" and world.hat_textures.has(clean_item_id):
		return world.hat_textures[clean_item_id]
	if clean_category == "hair" and world.hair_textures.has(clean_item_id):
		return world.hair_textures[clean_item_id]
	if clean_category == "eyewear" and world.eyewear_textures.has(clean_item_id):
		return world.eyewear_textures[clean_item_id]
	if clean_category == "shirt" and world.shirt_textures.has(clean_item_id):
		return world.shirt_textures[clean_item_id]
	if clean_category == "pants" and world.pants_textures.has(clean_item_id):
		return world.pants_textures[clean_item_id]
	if clean_category == "shoes" and world.shoes_textures.has(clean_item_id):
		return world.shoes_textures[clean_item_id]
	if clean_category == "ride" and world.ride_textures.has(clean_item_id):
		return world.ride_textures[clean_item_id]

	if world.item_database.has(clean_item_id):
		var item_data = world.item_database[clean_item_id]
		if item_data is Dictionary:
			return AtlasTextureFactory.load_texture(item_data.get("texture", null))

	return null


func get_atlas_item_icon_texture(item_id: String) -> Texture2D:
	if world == null or not world.item_database.has(item_id):
		return null

	var item_data = world.item_database[item_id]
	if not (item_data is Dictionary):
		return null

	var atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(item_id)))
	if atlas_item_id <= 0:
		return null

	var atlas_tile_set: TileSet = null
	if world.has_method("get_item_atlas_tile_set"):
		atlas_tile_set = world.get_item_atlas_tile_set()

	return ITEM_ATLAS_DB.get_item_icon(atlas_item_id, atlas_tile_set)


func update_stateful_block_visuals(grid_pos: Vector2i):
	if world == null or grid_pos == NO_VARIANT_GRID_POS or not world.blocks.has(grid_pos):
		return
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if is_display_block_type(block_type):
		update_display_visual(grid_pos)


func queue_anti_control_visual_refresh() -> void:
	pending_anti_control_visual_refresh = true


func process_pending_anti_control_visual_refresh() -> void:
	if not pending_anti_control_visual_refresh:
		return
	pending_anti_control_visual_refresh = false
	_refresh_all_anti_control_visuals_single_pass()


# refresh_all_anti_punch_visuals / _anti_talk_ / _anti_gravity_ each walk the FULL
# world.blocks dictionary. Called back-to-back (which is the only way they are ever called --
# see the single call site above, reached from finalize_world_load_block_variants ->
# queue_anti_control_visual_refresh at the end of every world load) that is three complete
# scans of up to ~7,000 blocks, unbatched and un-awaited, all inside one frame: a guaranteed
# frame spike at the exact moment the player is waiting to be handed control.
#
# This collapses them into ONE pass with identical semantics -- same per-type states-dict
# priority pass, same "skip if already refreshed from the states dict" rule, same
# update_anti_*_visual calls, just one traversal of world.blocks instead of three. The three
# original functions are left intact for the other paths that call them individually.
func _refresh_all_anti_control_visuals_single_pass() -> void:
	if world == null or not ("blocks" in world):
		return

	var refreshed_punch: Dictionary = {}
	var refreshed_talk: Dictionary = {}
	var refreshed_gravity: Dictionary = {}

	if "anti_punch_states" in world and world.anti_punch_states is Dictionary:
		for raw_grid_pos in world.anti_punch_states.keys():
			if raw_grid_pos is Vector2i:
				update_anti_punch_visual(raw_grid_pos)
				refreshed_punch[raw_grid_pos] = true
	if "anti_talk_states" in world and world.anti_talk_states is Dictionary:
		for raw_grid_pos in world.anti_talk_states.keys():
			if raw_grid_pos is Vector2i:
				update_anti_talk_visual(raw_grid_pos)
				refreshed_talk[raw_grid_pos] = true
	if "anti_gravity_states" in world and world.anti_gravity_states is Dictionary:
		for raw_grid_pos in world.anti_gravity_states.keys():
			if raw_grid_pos is Vector2i:
				update_anti_gravity_visual(raw_grid_pos)
				refreshed_gravity[raw_grid_pos] = true

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var block_data = world.blocks.get(raw_grid_pos, {})
		if not (block_data is Dictionary):
			continue
		var block_type := str(block_data.get("type", ""))
		if not refreshed_punch.has(raw_grid_pos) and is_anti_punch_block_type(block_type):
			update_anti_punch_visual(raw_grid_pos)
		if not refreshed_talk.has(raw_grid_pos) and is_anti_talk_block_type(block_type):
			update_anti_talk_visual(raw_grid_pos)
		if not refreshed_gravity.has(raw_grid_pos) and is_anti_gravity_block_type(block_type):
			update_anti_gravity_visual(raw_grid_pos)


func refresh_stateful_block_animation_after_texture_refresh(grid_pos: Vector2i, block_type: String, block_node: Node = null) -> void:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return

	if is_transformer_power_block_type(block_type):
		refresh_transformer_power_visual(grid_pos)
	elif is_oil_refinery_animation_block_type(block_type):
		sync_oil_refinery_visual_at(grid_pos)
	elif is_anti_punch_block_type(block_type):
		refresh_anti_control_animation_after_texture_refresh(grid_pos, block_type, block_node, true)
	elif is_anti_talk_block_type(block_type):
		refresh_anti_control_animation_after_texture_refresh(grid_pos, block_type, block_node, false)
	elif is_anti_gravity_block_type(block_type):
		refresh_anti_gravity_animation_after_texture_refresh(grid_pos, block_type, block_node)
	elif is_theme_machine_block_type(block_type):
		update_theme_machine_visual(grid_pos)


func refresh_anti_control_animation_after_texture_refresh(grid_pos: Vector2i, block_type: String, block_node: Node, punch_control: bool) -> void:
	var enabled: bool = is_anti_punch_grid_enabled(grid_pos) if punch_control else is_anti_talk_grid_enabled(grid_pos)
	if not enabled:
		if punch_control:
			clear_anti_punch_animation(grid_pos)
		else:
			clear_anti_talk_animation(grid_pos)
		return

	if block_node == null or not is_instance_valid(block_node):
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			var node_value: Variant = block_data.get("node", null)
			if node_value is Node:
				block_node = node_value

	if block_node != null and is_instance_valid(block_node):
		var visual_node: Node = block_node.get_node_or_null("Visual")
		if visual_node is Sprite2D:
			(visual_node as Sprite2D).visible = true
			if block_node.has_meta("tilemap_visual"):
				block_node.remove_meta("tilemap_visual")
			clear_tilemap_cell(grid_pos, false)
			if punch_control:
				if not anti_punch_active_visuals.has(grid_pos):
					start_anti_punch_animation(grid_pos, block_node, block_type)
				else:
					var punch_entry_value: Variant = anti_punch_active_visuals.get(grid_pos, {})
					if punch_entry_value is Dictionary:
						var punch_entry: Dictionary = punch_entry_value
						punch_entry["visual"] = visual_node
						punch_entry["block_type"] = block_type
						anti_punch_active_visuals[grid_pos] = punch_entry
					apply_anti_punch_animation_frame(grid_pos, true)
			else:
				if not anti_talk_active_visuals.has(grid_pos):
					start_anti_talk_animation(grid_pos, block_node, block_type)
				else:
					var talk_entry_value: Variant = anti_talk_active_visuals.get(grid_pos, {})
					if talk_entry_value is Dictionary:
						var talk_entry: Dictionary = talk_entry_value
						talk_entry["visual"] = visual_node
						talk_entry["block_type"] = block_type
						anti_talk_active_visuals[grid_pos] = talk_entry
					apply_anti_talk_animation_frame(grid_pos, true)
			return

	if punch_control:
		if not tilemap_foreground_animated_cells.has(grid_pos):
			start_tilemap_anti_punch_animation(grid_pos, block_type)
		else:
			apply_tilemap_foreground_animation_frame(grid_pos, true)
	else:
		if not tilemap_foreground_animated_cells.has(grid_pos):
			start_tilemap_anti_talk_animation(grid_pos, block_type)
		else:
			apply_tilemap_foreground_animation_frame(grid_pos, true)


func refresh_anti_gravity_animation_after_texture_refresh(grid_pos: Vector2i, block_type: String, block_node: Node) -> void:
	if not is_anti_gravity_grid_enabled(grid_pos):
		clear_anti_gravity_animation(grid_pos)
		return

	if block_node == null or not is_instance_valid(block_node):
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			var node_value: Variant = block_data.get("node", null)
			if node_value is Node:
				block_node = node_value

	if block_node != null and is_instance_valid(block_node):
		var visual_node: Node = block_node.get_node_or_null("Visual")
		if visual_node is Sprite2D:
			(visual_node as Sprite2D).visible = true
			if block_node.has_meta("tilemap_visual"):
				block_node.remove_meta("tilemap_visual")
			clear_tilemap_cell(grid_pos, false)
			if not anti_gravity_active_visuals.has(grid_pos):
				start_anti_gravity_animation(grid_pos, block_node, block_type)
			else:
				var entry_value: Variant = anti_gravity_active_visuals.get(grid_pos, {})
				if entry_value is Dictionary:
					var entry: Dictionary = entry_value
					entry["visual"] = visual_node
					entry["block_type"] = block_type
					anti_gravity_active_visuals[grid_pos] = entry
				apply_anti_gravity_animation_frame(grid_pos, true)
			return

	if not tilemap_foreground_animated_cells.has(grid_pos):
		start_tilemap_anti_gravity_animation(grid_pos, block_type)
	else:
		apply_tilemap_foreground_animation_frame(grid_pos, true)


func get_snow_storm_visual_block_type(base_block_id: String, grid_pos: Vector2i, background := false) -> String:
	if background or not snow_storm_visuals_active or grid_pos == NO_VARIANT_GRID_POS:
		return base_block_id

	match base_block_id:
		"dirt":
			var above_type = get_snow_storm_source_block_type(Vector2i(grid_pos.x, grid_pos.y - 1))
			if above_type == "snow_block":
				return "snow_dirt"
			if above_type == "snow_dirt":
				return base_block_id
			if above_type != "dirt":
				return "snow_block"
			var above_above_type = get_snow_storm_source_block_type(Vector2i(grid_pos.x, grid_pos.y - 2))
			if above_above_type == "dirt" or above_above_type == "snow_block" or above_above_type == "snow_dirt":
				return base_block_id
			return "snow_dirt"
		"water":
			return get_snow_storm_ice_block_type(grid_pos)
		"sand":
			return "snow_bank"
		"stone":
			return "snow_stone"
		"grass":
			return "frozen_grass"
		"leaf":
			if get_foreground_block_type_at(Vector2i(grid_pos.x, grid_pos.y - 1)) != "leaf":
				return "snow_leaf"

	return base_block_id


func clear_block_animation(block, visual: Sprite2D = null):
	if block != null and is_instance_valid(block):
		var existing_timer = block.get_node_or_null("BlockAnimationTimer")
		if existing_timer != null:
			if not existing_timer.is_queued_for_deletion():
				existing_timer.queue_free()

	if visual == null and block != null and is_instance_valid(block):
		visual = block.get_node_or_null("Visual")

	if visual == null:
		return

	animated_block_visuals.erase(visual.get_instance_id())
	springboard_active_visuals.erase(visual.get_instance_id())

	if visual.has_meta("animation_frames"):
		visual.remove_meta("animation_frames")
	if visual.has_meta("animation_frame_index"):
		visual.remove_meta("animation_frame_index")
	if visual.has_meta("springboard_animation_frame_index"):
		visual.remove_meta("springboard_animation_frame_index")


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


func parse_block_vector2i(raw_value, fallback := Vector2i.ZERO) -> Vector2i:
	if raw_value is Vector2i:
		return raw_value
	if raw_value is Vector2:
		return Vector2i(int(raw_value.x), int(raw_value.y))
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2i(int(raw_value[0]), int(raw_value[1]))
	if raw_value is Dictionary:
		return Vector2i(int(raw_value.get("x", fallback.x)), int(raw_value.get("y", fallback.y)))
	if raw_value is String:
		var parts := str(raw_value).split(",", false)
		if parts.size() >= 2 and str(parts[0]).strip_edges().is_valid_int() and str(parts[1]).strip_edges().is_valid_int():
			return Vector2i(int(str(parts[0]).strip_edges()), int(str(parts[1]).strip_edges()))

	return fallback


func parse_block_visual_offset(raw_offset) -> Vector2:
	return parse_block_vector2(raw_offset, Vector2.ZERO)


func apply_block_visual_layout(visual: Sprite2D, block_type: String):
	if visual == null:
		return
	if world == null or not world.item_database.has(block_type):
		return

	var item_data = world.item_database[block_type]
	visual.centered = bool(item_data.get("visual_centered", true))
	visual.position = parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO))
	visual.z_index = WATER_VISUAL_Z_INDEX if block_type == "water" else 0
	visual.z_as_relative = true


func get_colour_cycle_block_data(block_type: String) -> Dictionary:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or world == null or not world.item_database.has(clean_type):
		return {}
	var item_data: Variant = world.item_database.get(clean_type, {})
	if item_data is Dictionary and ColourCycleModulation.is_colour_cycle_item(item_data):
		return item_data
	return {}


func is_colour_cycle_block_type(block_type: String) -> bool:
	return not get_colour_cycle_block_data(block_type).is_empty()


func get_colour_cycle_block_modulate(block_type: String, grid_pos: Vector2i) -> Color:
	var item_data := get_colour_cycle_block_data(block_type)
	if item_data.is_empty():
		return Color.WHITE
	return ColourCycleModulation.get_colour_cycle_modulate(item_data, ColourCycleModulation.get_grid_phase_seed(grid_pos))


func register_colour_cycle_block_visual(grid_pos: Vector2i, block_type: String, visual: Sprite2D) -> void:
	if visual == null or grid_pos == NO_VARIANT_GRID_POS:
		return
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or not is_colour_cycle_block_type(clean_type):
		unregister_colour_cycle_block_visual(grid_pos)
		if visual != null:
			visual.self_modulate = Color.WHITE
		return
	colour_cycle_block_visuals[grid_pos] = {
		"block_type": clean_type,
		"visual": visual
	}
	visual.self_modulate = get_colour_cycle_block_modulate(clean_type, grid_pos)


func unregister_colour_cycle_block_visual(grid_pos: Vector2i) -> void:
	var previous: Variant = colour_cycle_block_visuals.get(grid_pos, null)
	if previous is Dictionary:
		var previous_visual: Variant = (previous as Dictionary).get("visual", null)
		if previous_visual is Sprite2D and is_instance_valid(previous_visual):
			(previous_visual as Sprite2D).self_modulate = Color.WHITE
	colour_cycle_block_visuals.erase(grid_pos)


func clear_colour_cycle_block_visuals() -> void:
	for grid_pos in colour_cycle_block_visuals.keys():
		unregister_colour_cycle_block_visual(grid_pos)
	colour_cycle_block_visuals.clear()


func sync_colour_cycle_block_visual(block_type: String, grid_pos: Vector2i, background: bool, visual: Sprite2D) -> void:
	if background or grid_pos == NO_VARIANT_GRID_POS or visual == null or not is_colour_cycle_block_type(block_type):
		if not background and grid_pos != NO_VARIANT_GRID_POS:
			unregister_colour_cycle_block_visual(grid_pos)
		if visual != null:
			visual.self_modulate = Color.WHITE
		return
	register_colour_cycle_block_visual(grid_pos, block_type, visual)
	if world != null and world.blocks.has(grid_pos):
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if block_data_value is Dictionary:
			sync_foreground_tilemap_collision_for_block(grid_pos, block_data_value)


func update_colour_cycle_block_visuals_throttled(delta: float) -> void:
	if colour_cycle_block_visuals.is_empty():
		colour_cycle_block_update_elapsed = 0.0
		return
	colour_cycle_block_update_elapsed += delta
	if colour_cycle_block_update_elapsed < COLOUR_CYCLE_BLOCK_UPDATE_SECONDS:
		return
	colour_cycle_block_update_elapsed = 0.0
	update_colour_cycle_block_visuals()


func update_colour_cycle_block_visuals() -> void:
	if colour_cycle_block_visuals.is_empty():
		return
	if world == null:
		clear_colour_cycle_block_visuals()
		return
	for grid_pos in colour_cycle_block_visuals.keys():
		var entry_value: Variant = colour_cycle_block_visuals.get(grid_pos, {})
		if not (entry_value is Dictionary):
			colour_cycle_block_visuals.erase(grid_pos)
			continue
		var entry: Dictionary = entry_value
		var visual_value: Variant = entry.get("visual", null)
		if not (visual_value is Sprite2D) or not is_instance_valid(visual_value):
			colour_cycle_block_visuals.erase(grid_pos)
			continue
		if not world.blocks.has(grid_pos):
			unregister_colour_cycle_block_visual(grid_pos)
			continue
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if not (block_data_value is Dictionary):
			unregister_colour_cycle_block_visual(grid_pos)
			continue
		var block_type := str((block_data_value as Dictionary).get("type", entry.get("block_type", ""))).strip_edges().to_lower()
		if not is_colour_cycle_block_type(block_type):
			unregister_colour_cycle_block_visual(grid_pos)
			continue
		(visual_value as Sprite2D).self_modulate = get_colour_cycle_block_modulate(block_type, grid_pos)


func is_tilemap_visual_candidate(block_type: String, visual_block_type: String, grid_pos: Vector2i, background := false, visual: Sprite2D = null) -> bool:
	if world == null or grid_pos == NO_VARIANT_GRID_POS or visual == null:
		return false

	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_type == "" or clean_visual_type == "":
		return false

	if clean_visual_type == "water" or clean_type == "water":
		return false
	if not background and (is_colour_cycle_block_type(clean_type) or is_colour_cycle_block_type(clean_visual_type)):
		return false

	# Platform blocks must keep their Sprite2D on the same node that owns their
	# one-way collision. Hiding that sprite in favor of a streamed TileMap cell
	# leaves a collidable but invisible platform whenever the TileMap is cleared
	# or deferred during world entry.
	if not background and is_platform_collision_block_type(clean_type):
		return false

	# Lava keeps a live node for rebound behavior and its light effect. If its
	# Sprite2D is hidden behind a streamed TileMap cell, a world-entry clear can
	# leave the hazard collidable but invisible until a nearby block dirties the
	# chunk. Keep the node-owned visual while collision stays on its normal path.
	if not background and is_hybrid_hazard_tilemap_visual_candidate(clean_type):
		return false

	var keep_interactive_node := not background and is_hybrid_interactive_tilemap_visual_candidate(clean_type)
	var keep_triggered_springboard_node := not background and is_triggered_springboard_animation_block(clean_type)

	if not background:
		# World locks swap access/no-access textures from ownership state and keep
		# a live node for interaction; keep the visual on that node too.
		if is_world_lock_block_type(clean_type):
			return false
		if is_area_lock_block_type(clean_type):
			return false
		if is_mailbox_block_type(clean_type):
			return false
		if is_donation_box_block_type(clean_type):
			return false
		if is_tackle_box_block_type(clean_type):
			return false
		if is_wooden_entrance_block_type(clean_type) and not keep_interactive_node:
			return false
		if is_entrance_gate_block_type(clean_type) and not keep_interactive_node:
			return false
		if (is_door_block_type(clean_type) or is_sign_block_type(clean_type) or is_toggle_block_type(clean_type)) and not keep_interactive_node:
			return false

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	var metadata := get_block_tilemap_metadata(clean_type, clean_visual_type, grid_pos, background)
	var has_visual_atlas := metadata_has_tilemap_atlas_coords(metadata)
	var uses_tileset_animation := metadata_has_visual_tileset_animation(metadata)
	if visual.texture == null and not has_visual_atlas:
		return false

	if not item_data.is_empty():
		var animation_frames = item_data.get("animation_frames", [])
		if animation_frames is Array and animation_frames.size() > 1:
			var can_use_tilemap_animation := (is_entrance_gate_block_type(clean_type) and animation_frames_are_tilemap_sized(clean_visual_type)) \
				or get_tilemap_animation_atlas_frames(clean_type, clean_visual_type).size() > 1 \
				or (keep_interactive_node and get_simple_tilemap_animation_frames(clean_type, clean_visual_type).size() > 1)
			if not can_use_tilemap_animation and not uses_tileset_animation:
				return false
		if item_data.has("toggle_textures") and not is_toggle_block_type(clean_type):
			return false
		if item_data.has("entrance_frames"):
			if not (is_wooden_entrance_block_type(clean_type) and entrance_frames_are_tilemap_sized(clean_visual_type)):
				return false
		if has_springboard_animation_metadata(item_data) and not keep_triggered_springboard_node:
			return false
		if item_data.has("break_effect_frames"):
			return false
		if bool(item_data.get("mailbox_block", false)) and not is_mailbox_block_type(clean_type):
			return false
		if bool(item_data.get("display_block", false)) and not is_display_block_type(clean_type):
			return false
		if bool(item_data.get("lava_rebound", false)) and not keep_interactive_node:
			return false
		if bool(item_data.get("anti_punch_block", false)):
			return false
		if bool(item_data.get("anti_talk_block", false)):
			return false
		if bool(item_data.get("anti_gravity_block", false)):
			return false
		if str(item_data.get("light_fx_scene", "")).strip_edges() != "" and not keep_interactive_node:
			return false
		if item_data.has("visual_centered") and not bool(item_data.get("visual_centered", true)):
			return false
		if item_data.has("visual_offset") and parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO)) != Vector2.ZERO:
			return false
		var expected_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
		if item_data.has("visual_size") and parse_block_vector2(item_data.get("visual_size"), expected_size) != expected_size:
			return false

	if keep_triggered_springboard_node and not springboard_frames_are_tilemap_sized(clean_type):
		return false

	if visual.centered != true:
		return false
	if visual.position != Vector2.ZERO:
		return false
	if visual.scale != Vector2.ONE:
		return false
	if visual.modulate != Color.WHITE:
		return false
	if visual.flip_h or visual.flip_v:
		return false

	if has_visual_atlas:
		return true

	var texture_width := int(round(visual.texture.get_width()))
	var texture_height := int(round(visual.texture.get_height()))
	var block_size := int(world.BLOCK_SIZE)
	return texture_width == block_size and texture_height == block_size


func springboard_frames_are_tilemap_sized(block_type: String) -> bool:
	var atlas_frames := get_springboard_animation_atlas_frames(block_type)
	if atlas_frames.size() > 1:
		return true

	var frames := get_springboard_animation_frames(block_type)
	if frames.is_empty():
		return false
	for frame in frames:
		if not (frame is Texture2D) or not is_tilemap_texture_block_sized(frame):
			return false
	return true


func animation_frames_are_tilemap_sized(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false

	var item_data := get_block_item_data(clean_type)
	if item_data.is_empty():
		return false

	var frame_paths = item_data.get("animation_frames", [])
	if not (frame_paths is Array) or frame_paths.size() <= 1:
		return false
	if parse_animation_atlas_frames(frame_paths).size() > 1:
		return true

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture == null or not is_tilemap_texture_block_sized(texture):
			return false
	return true


func entrance_frames_are_tilemap_sized(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false

	var item_data := get_block_item_data(clean_type)
	if item_data.is_empty():
		return false

	var frame_paths = item_data.get("entrance_frames", [])
	if not (frame_paths is Array) or frame_paths.size() <= 1:
		return false

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture == null or not is_tilemap_texture_block_sized(texture):
			return false
	return true


func is_hybrid_interactive_tilemap_visual_candidate(block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return false

	return is_door_block_type(clean_type) \
		or is_sign_block_type(clean_type) \
		or is_wooden_entrance_block_type(clean_type) \
		or is_entrance_gate_block_type(clean_type) \
		or is_toggle_block_type(clean_type) \
		or is_mailbox_block_type(clean_type) \
		or is_donation_box_block_type(clean_type) \
		or is_tackle_box_block_type(clean_type) \
		or is_chicken_block_type(clean_type) \
		or is_cow_block_type(clean_type) \
		or is_duck_block_type(clean_type) \
		or is_water_well_block_type(clean_type) \
		or is_atm_machine_block_type(clean_type) \
		or is_dice_block_type(clean_type) \
		or is_checkpoint_block_type(clean_type) \
		or is_display_block_type(clean_type) \
		or is_world_lock_block_type(clean_type) \
		or is_hybrid_hazard_tilemap_visual_candidate(clean_type)


func is_hybrid_hazard_tilemap_visual_candidate(block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return false

	var item_data := get_block_item_data(clean_type)
	if item_data.is_empty():
		return false

	return bool(item_data.get("lava_rebound", false))


func get_tilemap_texture_for_block(block_type: String, grid_pos: Vector2i, background := false) -> Texture2D:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return null

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, background)
	var variant_texture_path := get_visual_block_variant(visual_block_type, grid_pos, background)
	var stateful_texture_path := get_stateful_block_texture_path(visual_block_type, grid_pos, background)
	var texture_path := stateful_texture_path if stateful_texture_path != "" else variant_texture_path
	if texture_path != "":
		var texture: Texture2D = get_cached_visual_variant_texture(texture_path)
		if texture != null:
			return texture

	if world.block_textures.has(visual_block_type):
		var texture_value: Variant = world.block_textures[visual_block_type]
		if texture_value is Texture2D:
			return texture_value

	return null


func is_tilemap_only_background_candidate(block_type: String, visual_block_type: String, texture: Texture2D) -> bool:
	if world == null or not background_tilemap_only_enabled:
		return false

	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_type == "" or clean_visual_type == "":
		return false
	var metadata := get_block_tilemap_metadata(clean_type, clean_visual_type, NO_VARIANT_GRID_POS, true)
	var has_visual_atlas := metadata_has_tilemap_atlas_coords(metadata)
	var uses_tileset_animation := metadata_has_visual_tileset_animation(metadata)
	if texture == null and not has_visual_atlas:
		return false

	if not is_background_block_type(clean_type):
		return false
	if not is_non_collideable_block(clean_type):
		return false
	if clean_type == "water" or clean_visual_type == "water":
		return false
	if is_triggered_springboard_animation_block(clean_type):
		return false

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	if item_data.is_empty():
		return false

	if not bool(item_data.get("background_block", false)) and str(item_data.get("place_layer", "")).strip_edges().to_lower() != "background":
		return false

	var animation_frames = item_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 1 and not uses_tileset_animation:
		return false
	if item_data.has("toggle_textures") or item_data.has("entrance_frames") or has_springboard_animation_metadata(item_data):
		return false
	if str(item_data.get("light_fx_scene", "")).strip_edges() != "":
		return false
	if item_data.has("visual_centered") and not bool(item_data.get("visual_centered", true)):
		return false
	if item_data.has("visual_offset") and parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO)) != Vector2.ZERO:
		return false
	var expected_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	if item_data.has("visual_size") and parse_block_vector2(item_data.get("visual_size"), expected_size) != expected_size:
		return false

	if has_visual_atlas:
		return true
	var texture_width := int(round(texture.get_width()))
	var texture_height := int(round(texture.get_height()))
	var block_size := int(world.BLOCK_SIZE)
	return texture_width == block_size and texture_height == block_size


func sync_tilemap_only_background_block(grid_pos: Vector2i, block_type: String) -> bool:
	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, true)
	var texture: Texture2D = get_tilemap_texture_for_block(block_type, grid_pos, true)
	var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, true)
	if not is_tilemap_only_background_candidate(block_type, visual_block_type, texture):
		clear_tilemap_cell(grid_pos, true)
		return false

	var renderer = ensure_tilemap_renderer()
	if renderer == null:
		clear_tilemap_cell(grid_pos, true)
		return false

	return sync_renderer_block_visual_cell(renderer, grid_pos, texture, metadata, true, should_block_cast_texture_shadow(block_type, true))


func create_tilemap_only_background_block(grid_pos: Vector2i, block_type: String) -> bool:
	if not sync_tilemap_only_background_block(grid_pos, block_type):
		return false

	background_blocks[grid_pos] = {
		"node": null,
		"type": block_type,
		"item_id": get_atlas_item_id_for_block_type(block_type),
		"tilemap_only": true
	}
	authoritative_place_request_times.erase(get_authoritative_place_key("background", grid_pos, block_type))
	return true


func is_tilemap_only_foreground_candidate(block_type: String, visual_block_type: String, texture: Texture2D) -> bool:
	if not is_tilemap_only_foreground_visual_candidate(block_type, visual_block_type, texture):
		return false
	if not foreground_tilemap_collision_enabled or not foreground_tilemap_collision_replaces_nodes_enabled:
		return false

	var clean_type := str(block_type).strip_edges().to_lower()
	var metadata := get_block_tilemap_metadata(clean_type, visual_block_type)
	return bool(metadata.get("solid", false)) and str(metadata.get("collision_type", "none")) == "full"


func is_tilemap_only_foreground_visual_candidate(block_type: String, visual_block_type: String, texture: Texture2D) -> bool:
	if world == null or not foreground_tilemap_only_enabled:
		return false

	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_type == "" or clean_visual_type == "":
		return false
	if is_colour_cycle_block_type(clean_type) or is_colour_cycle_block_type(clean_visual_type):
		return false
	var metadata := get_block_tilemap_metadata(clean_type, clean_visual_type, NO_VARIANT_GRID_POS, false)
	var has_visual_atlas := metadata_has_tilemap_atlas_coords(metadata)
	var uses_tileset_animation := metadata_has_visual_tileset_animation(metadata)
	if texture == null and not has_visual_atlas:
		return false
	var is_water := clean_type == "water"
	if clean_visual_type == "water" and not is_water:
		return false
	if is_water:
		if not is_non_collideable_block(clean_type):
			return false
		return has_visual_atlas or is_tilemap_texture_block_sized(texture)
	if is_background_block_type(clean_type):
		return false
	if is_world_lock_block_type(clean_type):
		return false
	if is_area_lock_block_type(clean_type):
		return false
	if is_mailbox_block_type(clean_type):
		return false
	if is_tackle_box_block_type(clean_type):
		return false
	if is_wooden_entrance_block_type(clean_type):
		return false
	if is_entrance_gate_block_type(clean_type):
		return false
	if is_door_block_type(clean_type) and not is_auto_enter_door_block_type(clean_type):
		return false
	if is_toggle_block_type(clean_type):
		return false
	if is_platform_collision_block_type(clean_type):
		return false
	if is_triggered_springboard_animation_block(clean_type):
		if not is_tilemap_trigger_collision_block(clean_type):
			return false
	if block_requires_full_area_clear(clean_type):
		return false
	if block_occupies_collision_area(clean_type):
		return false

	var can_use_collision_tilemap := foreground_tilemap_collision_enabled \
		and foreground_tilemap_collision_replaces_nodes_enabled \
		and bool(get_block_tilemap_metadata(clean_type, clean_visual_type).get("solid", false))
	if not can_use_collision_tilemap and not is_non_collideable_block(clean_type):
		return false
	if is_bedrock_block_type(clean_type):
		return has_visual_atlas or is_tilemap_texture_block_sized(texture)

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	if item_data.is_empty():
		return false

	var animation_frames = item_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 1:
		if not uses_tileset_animation and get_simple_tilemap_animation_frames(clean_type, clean_visual_type).size() <= 1 and get_tilemap_animation_atlas_frames(clean_type, clean_visual_type).size() <= 1:
			return false
	if item_data.has("toggle_textures") or item_data.has("entrance_frames"):
		return false
	if has_springboard_animation_metadata(item_data) and not is_tilemap_trigger_collision_block(clean_type):
		return false
	if str(item_data.get("light_fx_scene", "")).strip_edges() != "":
		return false
	if item_data.has("visual_centered") and not bool(item_data.get("visual_centered", true)):
		return false
	if item_data.has("visual_offset") and parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO)) != Vector2.ZERO:
		return false
	var expected_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	if item_data.has("visual_size") and parse_block_vector2(item_data.get("visual_size"), expected_size) != expected_size:
		return false

	if has_visual_atlas:
		return true
	var texture_width := int(round(texture.get_width()))
	var texture_height := int(round(texture.get_height()))
	var block_size := int(world.BLOCK_SIZE)
	return texture_width == block_size and texture_height == block_size


func sync_tilemap_only_foreground_metadata(grid_pos: Vector2i, block_data: Dictionary, block_type: String) -> Dictionary:
	block_data["node"] = null
	block_data["tilemap_only"] = true
	block_data["item_id"] = get_atlas_item_id_for_block_type(block_type)
	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	var texture: Texture2D = get_tilemap_texture_for_block(block_type, grid_pos, false)
	var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, false)
	block_data["tilemap_metadata"] = metadata
	if is_tilemap_only_foreground_candidate(block_type, visual_block_type, texture):
		block_data["tilemap_collision"] = true
		block_data["tilemap_collision_kind"] = str(metadata.get("collision_type", "full"))
	else:
		block_data.erase("tilemap_collision")
		block_data.erase("tilemap_collision_replaces_node")
		block_data.erase("tilemap_collision_kind")
	return block_data


func sync_tilemap_only_foreground_block(grid_pos: Vector2i, block_type: String) -> bool:
	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	var texture: Texture2D = get_tilemap_texture_for_block(block_type, grid_pos, false)
	if not is_tilemap_only_foreground_visual_candidate(block_type, visual_block_type, texture):
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		return false

	var renderer = ensure_tilemap_renderer()
	if renderer == null:
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		return false

	var clean_type := str(block_type).strip_edges().to_lower()
	var visual_synced := false
	var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, false)
	if should_use_foreground_over_player_tilemap_layer(block_type, false):
		if renderer.has_method("erase_block_cell"):
			renderer.erase_block_cell(grid_pos, false)
		visual_synced = sync_renderer_over_player_visual_cell(renderer, grid_pos, texture, metadata)
	elif clean_type == "water":
		if renderer.has_method("erase_block_cell"):
			renderer.erase_block_cell(grid_pos, false)
		visual_synced = sync_renderer_water_visual_cell(renderer, grid_pos, texture, metadata)
	else:
		if renderer.has_method("erase_water_cell"):
			renderer.erase_water_cell(grid_pos)
		if renderer.has_method("erase_foreground_over_player_cell"):
			renderer.erase_foreground_over_player_cell(grid_pos)
		visual_synced = sync_renderer_block_visual_cell(renderer, grid_pos, texture, metadata, false, should_block_cast_texture_shadow(block_type, false))

	if not visual_synced:
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		return false
	sync_tilemap_foreground_animation_cell(grid_pos, block_type, visual_block_type)

	if not is_tilemap_only_foreground_candidate(block_type, visual_block_type, texture):
		clear_foreground_tilemap_collision_cell(grid_pos)
		return true

	var collision_synced: bool = false
	if bool(metadata.get("solid", false)) and str(metadata.get("collision_type", "none")) == "full":
		collision_synced = renderer.has_method("set_foreground_collision_cell") and bool(renderer.set_foreground_collision_cell(grid_pos))
	else:
		clear_foreground_tilemap_collision_cell(grid_pos)
		return true

	if not collision_synced:
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		return false

	return true


func is_tilemap_water_surface_animation_cell(block_type: String, visual_block_type: String, grid_pos: Vector2i) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_type != "water" or clean_visual_type != "water":
		return false
	return not is_lower_water_layer_cell(grid_pos)


func sync_tilemap_foreground_animation_cell(grid_pos: Vector2i, block_type: String, visual_block_type: String) -> void:
	var clean_type := str(block_type).strip_edges().to_lower()
	if is_mailbox_block_type(clean_type):
		clear_mailbox_visual_animation(grid_pos)
		return
	if is_donation_box_block_type(clean_type):
		tilemap_foreground_animated_cells.erase(grid_pos)
		return
	if is_tackle_box_block_type(clean_type):
		clear_tackle_box_visual_animation(grid_pos)
		return
	if is_oil_refinery_animation_block_type(clean_type):
		sync_oil_refinery_visual_at(grid_pos)
		return
	if is_theme_machine_block_type(clean_type):
		if is_theme_machine_grid_enabled(grid_pos):
			start_tilemap_theme_machine_animation(grid_pos, clean_type)
		else:
			tilemap_foreground_animated_cells.erase(grid_pos)
		return
	if is_server_triggered_animation_block(clean_type):
		if is_transformer_power_block_type(clean_type) and is_transformer_powered_at(grid_pos):
			start_tilemap_transformer_power_animation(grid_pos, clean_type)
		else:
			tilemap_foreground_animated_cells.erase(grid_pos)
		return
	var water_cell := is_tilemap_water_surface_animation_cell(block_type, visual_block_type, grid_pos)
	if clean_type == "water" and not water_cell:
		tilemap_foreground_animated_cells.erase(grid_pos)
		return

	var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, false)
	if metadata_has_visual_tileset_animation(metadata):
		tilemap_foreground_animated_cells.erase(grid_pos)
		return

	var atlas_frames := get_tilemap_animation_atlas_frames("water", "water") if water_cell else get_tilemap_animation_atlas_frames(block_type, visual_block_type)
	var frames := get_simple_tilemap_animation_frames("water", "water") if water_cell else get_simple_tilemap_animation_frames(block_type, visual_block_type)
	if frames.size() <= 1 and atlas_frames.size() <= 1:
		tilemap_foreground_animated_cells.erase(grid_pos)
		return

	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": visual_block_type,
		"frames": frames,
		"atlas_frames": atlas_frames,
		"source_id": int(metadata.get("source_id", 0)),
		"alternative_tile": int(metadata.get("alternative_tile", 0)),
		"frame_seconds": get_tilemap_animation_frame_seconds(block_type, visual_block_type),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": water_cell
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func update_tilemap_foreground_animations() -> void:
	if tilemap_foreground_animated_cells.is_empty():
		return
	if world == null:
		tilemap_foreground_animated_cells.clear()
		return

	for grid_pos in tilemap_foreground_animated_cells.keys():
		if not (grid_pos is Vector2i) or not world.blocks.has(grid_pos):
			tilemap_foreground_animated_cells.erase(grid_pos)
			continue
		apply_tilemap_foreground_animation_frame(grid_pos)


func apply_tilemap_foreground_animation_frame(grid_pos: Vector2i, force_update := false) -> void:
	var entry_value: Variant = tilemap_foreground_animated_cells.get(grid_pos, {})
	if not (entry_value is Dictionary):
		tilemap_foreground_animated_cells.erase(grid_pos)
		return
	var entry: Dictionary = entry_value

	var frames_value: Variant = entry.get("frames", [])
	var atlas_frames_value: Variant = entry.get("atlas_frames", [])
	var has_atlas_frames: bool = atlas_frames_value is Array and atlas_frames_value.size() > 1
	var has_texture_frames: bool = frames_value is Array and frames_value.size() > 1
	if not has_atlas_frames and not has_texture_frames:
		tilemap_foreground_animated_cells.erase(grid_pos)
		return
	var frames: Array = []
	if has_texture_frames:
		frames = frames_value as Array
	var atlas_frames: Array = []
	if has_atlas_frames:
		atlas_frames = atlas_frames_value as Array
	var frame_count: int = atlas_frames.size() if has_atlas_frames else frames.size()

	var frame_seconds: float = maxf(0.08, float(entry.get("frame_seconds", 0.45)))
	var frame_msec: int = maxi(1, int(round(frame_seconds * 1000.0)))
	var frame_index: int = int(floor(float(Time.get_ticks_msec()) / float(frame_msec))) % frame_count
	var previous_index := int(entry.get("frame_index", -1))
	if not force_update and previous_index == frame_index:
		return

	var renderer = ensure_tilemap_renderer()
	if renderer == null:
		return

	var synced := false
	if has_atlas_frames:
		var atlas_coords := parse_block_vector2i(atlas_frames[frame_index], Vector2i.ZERO)
		if bool(entry.get("water_cell", false)):
			synced = renderer.has_method("set_water_atlas_cell") and bool(renderer.set_water_atlas_cell(grid_pos, atlas_coords, "animation_frame", int(entry.get("alternative_tile", 0))))
		elif renderer.has_method("set_item_atlas_cell"):
			synced = bool(renderer.set_item_atlas_cell(
				grid_pos,
				int(entry.get("source_id", 0)),
				atlas_coords,
				false,
				bool(entry.get("texture_shadow", false)),
				"animation_frame",
				int(entry.get("alternative_tile", 0))
			))
		elif renderer.has_method("set_block_atlas_cell"):
			synced = bool(renderer.set_block_atlas_cell(grid_pos, atlas_coords, false, bool(entry.get("texture_shadow", false)), "animation_frame", int(entry.get("alternative_tile", 0))))
	else:
		var texture_value: Variant = frames[frame_index]
		if not (texture_value is Texture2D):
			tilemap_foreground_animated_cells.erase(grid_pos)
			return
		if bool(entry.get("water_cell", false)):
			synced = renderer.has_method("set_water_cell") and bool(renderer.set_water_cell(grid_pos, texture_value as Texture2D))
		else:
			synced = renderer.has_method("set_block_cell") and bool(renderer.set_block_cell(grid_pos, texture_value as Texture2D, false, bool(entry.get("texture_shadow", false))))

	if synced:
		entry["frame_index"] = frame_index
		tilemap_foreground_animated_cells[grid_pos] = entry
		emit_block_animation_loop_particle_at_grid(grid_pos, str(entry.get("block_type", "")), previous_index, frame_index, force_update)


func create_tilemap_only_foreground_block(grid_pos: Vector2i, block_type: String) -> bool:
	if not sync_tilemap_only_foreground_block(grid_pos, block_type):
		return false

	world.blocks[grid_pos] = {
		"node": null,
		"type": block_type,
		"item_id": get_atlas_item_id_for_block_type(block_type),
		"entrance_locked": false,
		"sign_text": "",
		"toggle_on": false,
		"tilemap_only": true
	}
	world.blocks[grid_pos] = sync_tilemap_only_foreground_metadata(grid_pos, world.blocks[grid_pos], block_type)
	authoritative_place_request_times.erase(get_authoritative_place_key("foreground", grid_pos, block_type))
	return true


func get_tilemap_node_backed_breakdown() -> Dictionary:
	var foreground_detail: Dictionary = {}
	var background_detail: Dictionary = {}
	var breakdown := {
		"foreground": {},
		"background": {},
		"foreground_optimization_candidates": 0,
		"foreground_audit_nodes": 0,
		"foreground_feature_nodes": 0,
		"foreground_intentional_nodes": 0,
		"foreground_intentional_tilemap_split_nodes": 0,
		"foreground_intentional_live_visual_nodes": 0,
		"foreground_intentional_logic_only_nodes": 0,
		"foreground_missing_item_types": {},
		"foreground_custom_collision_types": {},
		"foreground_animated_types": {},
		"foreground_node_type_details": {},
		"foreground_optimization_type_details": {},
		"foreground_audit_type_details": {},
		"foreground_intentional_type_details": {},
		"background_optimization_candidates": 0,
		"background_audit_nodes": 0,
		"background_feature_nodes": 0,
		"background_intentional_nodes": 0,
		"background_intentional_tilemap_split_nodes": 0,
		"background_intentional_live_visual_nodes": 0,
		"background_intentional_logic_only_nodes": 0,
		"background_missing_item_types": {},
		"background_custom_collision_types": {},
		"background_animated_types": {},
		"background_node_type_details": {},
		"background_optimization_type_details": {},
		"background_audit_type_details": {},
		"background_intentional_type_details": {}
	}

	if world != null and "blocks" in world and world.blocks is Dictionary:
		foreground_detail = collect_tilemap_node_backed_breakdown(world.blocks, false)
	background_detail = collect_tilemap_node_backed_breakdown(background_blocks, true)
	breakdown["foreground"] = foreground_detail.get("reasons", {})
	breakdown["foreground_optimization_candidates"] = int(foreground_detail.get("optimization_candidates", 0))
	breakdown["foreground_audit_nodes"] = int(foreground_detail.get("audit_nodes", 0))
	breakdown["foreground_feature_nodes"] = int(foreground_detail.get("feature_nodes", 0))
	breakdown["foreground_intentional_nodes"] = int(foreground_detail.get("intentional_nodes", foreground_detail.get("feature_nodes", 0)))
	breakdown["foreground_intentional_tilemap_split_nodes"] = int(foreground_detail.get("intentional_tilemap_split_nodes", 0))
	breakdown["foreground_intentional_live_visual_nodes"] = int(foreground_detail.get("intentional_live_visual_nodes", 0))
	breakdown["foreground_intentional_logic_only_nodes"] = int(foreground_detail.get("intentional_logic_only_nodes", 0))
	breakdown["background"] = background_detail.get("reasons", {})
	breakdown["background_optimization_candidates"] = int(background_detail.get("optimization_candidates", 0))
	breakdown["background_audit_nodes"] = int(background_detail.get("audit_nodes", 0))
	breakdown["background_feature_nodes"] = int(background_detail.get("feature_nodes", 0))
	breakdown["background_intentional_nodes"] = int(background_detail.get("intentional_nodes", background_detail.get("feature_nodes", 0)))
	breakdown["background_intentional_tilemap_split_nodes"] = int(background_detail.get("intentional_tilemap_split_nodes", 0))
	breakdown["background_intentional_live_visual_nodes"] = int(background_detail.get("intentional_live_visual_nodes", 0))
	breakdown["background_intentional_logic_only_nodes"] = int(background_detail.get("intentional_logic_only_nodes", 0))
	breakdown["foreground_missing_item_types"] = foreground_detail.get("missing_item_types", {})
	breakdown["foreground_custom_collision_types"] = foreground_detail.get("custom_collision_types", {})
	breakdown["foreground_animated_types"] = foreground_detail.get("animated_types", {})
	breakdown["foreground_node_type_details"] = foreground_detail.get("types_by_reason", {})
	breakdown["foreground_optimization_type_details"] = foreground_detail.get("optimization_types_by_reason", {})
	breakdown["foreground_audit_type_details"] = foreground_detail.get("audit_types_by_reason", {})
	breakdown["foreground_intentional_type_details"] = foreground_detail.get("intentional_types_by_reason", {})
	breakdown["background_missing_item_types"] = background_detail.get("missing_item_types", {})
	breakdown["background_custom_collision_types"] = background_detail.get("custom_collision_types", {})
	breakdown["background_animated_types"] = background_detail.get("animated_types", {})
	breakdown["background_node_type_details"] = background_detail.get("types_by_reason", {})
	breakdown["background_optimization_type_details"] = background_detail.get("optimization_types_by_reason", {})
	breakdown["background_audit_type_details"] = background_detail.get("audit_types_by_reason", {})
	breakdown["background_intentional_type_details"] = background_detail.get("intentional_types_by_reason", {})
	return breakdown


func collect_tilemap_node_backed_breakdown(blocks: Dictionary, background := false) -> Dictionary:
	var detail := {
		"reasons": {},
		"optimization_candidates": 0,
		"audit_nodes": 0,
		"feature_nodes": 0,
		"intentional_nodes": 0,
		"intentional_tilemap_split_nodes": 0,
		"intentional_live_visual_nodes": 0,
		"intentional_logic_only_nodes": 0,
		"missing_item_types": {},
		"custom_collision_types": {},
		"animated_types": {},
		"types_by_reason": {},
		"optimization_types_by_reason": {},
		"audit_types_by_reason": {},
		"intentional_types_by_reason": {}
	}
	for raw_grid_pos in blocks.keys():
		var block_data_value: Variant = blocks.get(raw_grid_pos, null)
		if not (block_data_value is Dictionary):
			continue

		var block_data: Dictionary = block_data_value
		if bool(block_data.get("tilemap_only", false)):
			continue

		var node_value: Variant = block_data.get("node", null)
		if not (node_value is Node) or not is_instance_valid(node_value):
			continue

		var grid_pos := NO_VARIANT_GRID_POS
		if raw_grid_pos is Vector2i:
			grid_pos = raw_grid_pos
		var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
		var reason := get_background_node_backed_tilemap_reason(grid_pos, block_type) if background else get_foreground_node_backed_tilemap_reason(grid_pos, block_type, node_value as Node)
		increment_tilemap_node_breakdown_reason(detail.get("reasons", {}), reason)
		var bucket := get_tilemap_node_backed_bucket(reason)
		match bucket:
			"optimization":
				detail["optimization_candidates"] = int(detail.get("optimization_candidates", 0)) + 1
			"audit":
				detail["audit_nodes"] = int(detail.get("audit_nodes", 0)) + 1
			_:
				detail["intentional_nodes"] = int(detail.get("intentional_nodes", 0)) + 1
				detail["feature_nodes"] = int(detail.get("feature_nodes", 0)) + 1
				var visual_mode := get_intentional_node_visual_mode(node_value as Node)
				match visual_mode:
					"tilemap_split":
						detail["intentional_tilemap_split_nodes"] = int(detail.get("intentional_tilemap_split_nodes", 0)) + 1
					"live_visual":
						detail["intentional_live_visual_nodes"] = int(detail.get("intentional_live_visual_nodes", 0)) + 1
					_:
						detail["intentional_logic_only_nodes"] = int(detail.get("intentional_logic_only_nodes", 0)) + 1
		track_tilemap_node_backed_type_detail(detail, reason, block_type)
		track_tilemap_node_backed_bucket_type_detail(detail, bucket, reason, block_type)

	return detail


func get_tilemap_node_backed_bucket(reason: String) -> String:
	var clean_reason := get_tilemap_node_backed_detail_reason(reason)

	match clean_reason:
		"eligible leftover", "missing source texture":
			return "optimization"
		"missing type", "missing item data", "missing texture", "non-32 texture", "other":
			return "audit"

	return "intentional"


func get_intentional_node_visual_mode(block_node: Node) -> String:
	if block_node.has_meta("tilemap_visual"):
		return "tilemap_split"

	var visual := block_node.get_node_or_null("Visual")
	if visual is CanvasItem and (visual as CanvasItem).visible:
		return "live_visual"

	return "logic_only"


func increment_tilemap_node_breakdown_reason(counts: Dictionary, reason: String) -> void:
	var clean_reason := reason.strip_edges()
	if clean_reason == "":
		clean_reason = "other"
	counts[clean_reason] = int(counts.get(clean_reason, 0)) + 1


func get_tilemap_node_backed_detail_reason(reason: String) -> String:
	var clean_reason := reason.strip_edges()
	var prefix := "tilemapped kept: "
	if clean_reason.begins_with(prefix):
		clean_reason = clean_reason.substr(prefix.length()).strip_edges()
	if clean_reason == "":
		return "other"
	return clean_reason


func track_tilemap_node_backed_type_detail(detail: Dictionary, reason: String, block_type: String) -> void:
	var clean_reason := get_tilemap_node_backed_detail_reason(reason)
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		clean_type = "missing type"

	var types_by_reason_value: Variant = detail.get("types_by_reason", {})
	var types_by_reason: Dictionary = types_by_reason_value if types_by_reason_value is Dictionary else {}
	var reason_types_value: Variant = types_by_reason.get(clean_reason, {})
	var reason_types: Dictionary = reason_types_value if reason_types_value is Dictionary else {}
	increment_tilemap_node_breakdown_reason(reason_types, clean_type)
	types_by_reason[clean_reason] = reason_types
	detail["types_by_reason"] = types_by_reason

	match clean_reason:
		"missing item data":
			increment_tilemap_node_breakdown_reason(detail.get("missing_item_types", {}), clean_type)
		"custom collision":
			increment_tilemap_node_breakdown_reason(detail.get("custom_collision_types", {}), clean_type)
		"animated":
			increment_tilemap_node_breakdown_reason(detail.get("animated_types", {}), clean_type)


func track_tilemap_node_backed_bucket_type_detail(detail: Dictionary, bucket: String, reason: String, block_type: String) -> void:
	var clean_bucket := bucket.strip_edges().to_lower()
	if clean_bucket != "optimization" and clean_bucket != "audit":
		clean_bucket = "intentional"

	var clean_reason := get_tilemap_node_backed_detail_reason(reason)
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		clean_type = "missing type"

	var field_name := clean_bucket + "_types_by_reason"
	var types_by_reason_value: Variant = detail.get(field_name, {})
	var types_by_reason: Dictionary = types_by_reason_value if types_by_reason_value is Dictionary else {}
	var reason_types_value: Variant = types_by_reason.get(clean_reason, {})
	var reason_types: Dictionary = reason_types_value if reason_types_value is Dictionary else {}
	increment_tilemap_node_breakdown_reason(reason_types, clean_type)
	types_by_reason[clean_reason] = reason_types
	detail[field_name] = types_by_reason


func get_foreground_node_backed_tilemap_reason(grid_pos: Vector2i, block_type: String, block_node: Node) -> String:
	if block_type == "":
		return "missing type"
	if not foreground_tilemap_only_enabled:
		return "fg tilemap off"

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	var texture: Texture2D = get_tilemap_texture_for_block(block_type, grid_pos, false)
	var visual_texture: Texture2D = get_block_node_visual_texture(block_node)
	var reason_texture: Texture2D = texture if texture != null else visual_texture
	if is_tilemap_only_foreground_visual_candidate(block_type, visual_block_type, texture):
		return "eligible leftover"
	if texture == null and visual_texture != null and is_tilemap_only_foreground_visual_candidate(block_type, visual_block_type, visual_texture):
		return "tilemapped kept: missing source texture"
	if block_node != null and block_node.has_meta("tilemap_visual"):
		return "tilemapped kept: " + get_foreground_tilemap_rejection_reason(block_type, visual_block_type, reason_texture)

	return get_foreground_tilemap_rejection_reason(block_type, visual_block_type, reason_texture)


func get_block_node_visual_texture(block_node: Node) -> Texture2D:
	if block_node == null or not is_instance_valid(block_node):
		return null
	var visual := block_node.get_node_or_null("Visual")
	if visual is Sprite2D:
		return (visual as Sprite2D).texture
	return null


func get_background_node_backed_tilemap_reason(grid_pos: Vector2i, block_type: String) -> String:
	if block_type == "":
		return "missing type"
	if not background_tilemap_only_enabled:
		return "bg tilemap off"

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, true)
	var texture: Texture2D = get_tilemap_texture_for_block(block_type, grid_pos, true)
	if is_tilemap_only_background_candidate(block_type, visual_block_type, texture):
		return "eligible leftover"

	return get_background_tilemap_rejection_reason(block_type, visual_block_type, texture)


func get_foreground_tilemap_rejection_reason(block_type: String, visual_block_type: String, texture: Texture2D) -> String:
	var clean_type := block_type.strip_edges().to_lower()
	var clean_visual_type := visual_block_type.strip_edges().to_lower()
	var metadata := get_block_tilemap_metadata(clean_type, clean_visual_type, NO_VARIANT_GRID_POS, false)
	var has_visual_atlas := metadata_has_tilemap_atlas_coords(metadata)
	if clean_type == "water":
		return "water pending" if has_visual_atlas or (texture != null and is_tilemap_texture_block_sized(texture)) else "water"
	if clean_visual_type == "water":
		return "water"
	if is_background_block_type(clean_type):
		return "background item"
	if is_world_lock_block_type(clean_type):
		return "world lock"
	if is_area_lock_block_type(clean_type):
		return "area lock tint"
	if is_wooden_entrance_block_type(clean_type):
		return "entrance"
	if is_entrance_gate_block_type(clean_type):
		return "entrance gate"
	if is_door_block_type(clean_type) and not is_auto_enter_door_block_type(clean_type):
		return "door"
	if is_sign_block_type(clean_type):
		return "sign"
	if is_toggle_block_type(clean_type):
		return "toggle"
	if is_platform_collision_block_type(clean_type):
		return "platform node visual"
	if block_requires_full_area_clear(clean_type):
		return "full-area object"
	if block_occupies_collision_area(clean_type):
		return "collision-area object"
	if texture == null and not has_visual_atlas:
		return "missing texture"
	if is_triggered_springboard_animation_block(clean_type):
		if is_tilemap_trigger_collision_block(clean_type) and (has_visual_atlas or is_tilemap_texture_block_sized(texture)):
			return "trigger logic"
		return "springboard"
	if is_bedrock_block_type(clean_type):
		return "other" if has_visual_atlas or is_tilemap_texture_block_sized(texture) else "non-32 texture"

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	if item_data.is_empty():
		return "missing item data"

	var metadata_reason := get_tilemap_metadata_rejection_reason(item_data, metadata)
	if metadata_reason != "":
		return metadata_reason
	if not is_non_collideable_block(clean_type) \
			and not is_foreground_tilemap_solid_collision_block(clean_type):
		return "custom collision"
	if not has_visual_atlas and not is_tilemap_texture_block_sized(texture):
		return "non-32 texture"
	return "other"


func get_background_tilemap_rejection_reason(block_type: String, visual_block_type: String, texture: Texture2D) -> String:
	var clean_type := block_type.strip_edges().to_lower()
	var clean_visual_type := visual_block_type.strip_edges().to_lower()
	var metadata := get_block_tilemap_metadata(clean_type, clean_visual_type, NO_VARIANT_GRID_POS, true)
	var has_visual_atlas := metadata_has_tilemap_atlas_coords(metadata)
	if not is_background_block_type(clean_type):
		return "not background item"
	if not is_non_collideable_block(clean_type):
		return "has collision"
	if clean_type == "water" or clean_visual_type == "water":
		return "water"
	if is_triggered_springboard_animation_block(clean_type):
		return "springboard"
	if texture == null and not has_visual_atlas:
		return "missing texture"

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	if item_data.is_empty():
		return "missing item data"
	if not bool(item_data.get("background_block", false)) and str(item_data.get("place_layer", "")).strip_edges().to_lower() != "background":
		return "not background layer"

	var metadata_reason := get_tilemap_metadata_rejection_reason(item_data, metadata)
	if metadata_reason != "":
		return metadata_reason
	if not has_visual_atlas and not is_tilemap_texture_block_sized(texture):
		return "non-32 texture"
	return "other"


func get_tilemap_metadata_rejection_reason(item_data: Dictionary, tilemap_metadata: Dictionary = {}) -> String:
	if bool(item_data.get("colour_cycle_block", false)):
		return "colour cycle"
	var animation_frames = item_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 1:
		if metadata_has_visual_tileset_animation(tilemap_metadata):
			return ""
		return "animated"
	if item_data.has("toggle_textures") or item_data.has("entrance_frames") or has_springboard_animation_metadata(item_data):
		return "interactive anim"
	if item_data.has("break_effect_frames") \
		or bool(item_data.get("mailbox_block", false)) \
		or bool(item_data.get("donation_box_block", false)) \
		or bool(item_data.get("display_block", false)) \
		or bool(item_data.get("anti_punch_block", false)) \
		or bool(item_data.get("anti_talk_block", false)) \
		or bool(item_data.get("anti_gravity_block", false)):
		return "interactive state"
	if str(item_data.get("light_fx_scene", "")).strip_edges() != "":
		return "light fx"
	if item_data.has("visual_centered") and not bool(item_data.get("visual_centered", true)):
		return "custom visual"
	if item_data.has("visual_offset") and parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO)) != Vector2.ZERO:
		return "custom visual"
	var expected_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	if item_data.has("visual_size") and parse_block_vector2(item_data.get("visual_size"), expected_size) != expected_size:
		return "custom visual"
	return ""


func is_tilemap_texture_block_sized(texture: Texture2D) -> bool:
	if texture == null or world == null:
		return false
	var texture_width := int(round(texture.get_width()))
	var texture_height := int(round(texture.get_height()))
	var block_size := int(world.BLOCK_SIZE)
	return texture_width == block_size and texture_height == block_size


func is_simple_tilemap_animation_metadata(block_type: String, item_data: Dictionary) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or item_data.is_empty():
		return false
	if is_entrance_gate_block_type(clean_type):
		return false
	if is_world_lock_block_type(clean_type) or is_wooden_entrance_block_type(clean_type):
		return false
	if (is_door_block_type(clean_type) and not is_auto_enter_door_block_type(clean_type)) or is_sign_block_type(clean_type) or is_toggle_block_type(clean_type):
		return false
	if is_platform_collision_block_type(clean_type) or is_triggered_springboard_animation_block(clean_type):
		return false
	if block_requires_full_area_clear(clean_type) or block_occupies_collision_area(clean_type):
		return false
	if item_data.has("toggle_textures") or item_data.has("entrance_frames") or has_springboard_animation_metadata(item_data):
		return false
	if item_data.has("break_effect_frames") \
		or bool(item_data.get("mailbox_block", false)) \
		or bool(item_data.get("display_block", false)) \
		or bool(item_data.get("anti_punch_block", false)) \
		or bool(item_data.get("anti_talk_block", false)) \
		or bool(item_data.get("anti_gravity_block", false)):
		return false
	if str(item_data.get("light_fx_scene", "")).strip_edges() != "":
		return false
	if item_data.has("visual_centered") and not bool(item_data.get("visual_centered", true)):
		return false
	if item_data.has("visual_offset") and parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO)) != Vector2.ZERO:
		return false
	var expected_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	if item_data.has("visual_size") and parse_block_vector2(item_data.get("visual_size"), expected_size) != expected_size:
		return false
	return true


func get_simple_tilemap_animation_frames(block_type: String, visual_block_type: String) -> Array:
	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if world == null or clean_type == "" or clean_visual_type == "":
		return []

	var cache_key := clean_type + "|" + clean_visual_type
	if tilemap_animation_frame_cache.has(cache_key):
		return tilemap_animation_frame_cache.get(cache_key, [])

	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	if item_data.is_empty() or not is_simple_tilemap_animation_metadata(clean_type, item_data):
		tilemap_animation_frame_cache[cache_key] = []
		return []
	if get_tilemap_animation_atlas_frames(clean_type, clean_visual_type).size() > 1:
		tilemap_animation_frame_cache[cache_key] = []
		return []

	var frame_paths = item_data.get("animation_frames", [])
	if not (frame_paths is Array) or frame_paths.size() <= 1:
		tilemap_animation_frame_cache[cache_key] = []
		return []

	var frames: Array[Texture2D] = []
	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture == null or not is_tilemap_texture_block_sized(texture):
			tilemap_animation_frame_cache[cache_key] = []
			return []
		frames.append(texture)

	if frames.size() <= 1:
		tilemap_animation_frame_cache[cache_key] = []
		return []

	tilemap_animation_frame_cache[cache_key] = frames
	return frames


func get_tilemap_animation_frame_seconds(block_type: String, visual_block_type: String) -> float:
	var clean_type := str(block_type).strip_edges().to_lower()
	var clean_visual_type := str(visual_block_type).strip_edges().to_lower()
	if clean_type == "water" and world != null:
		return max(0.03, float(world.WATER_ANIMATION_SPEED))
	var item_data := get_block_item_data(clean_visual_type)
	if item_data.is_empty():
		item_data = get_block_item_data(clean_type)
	return max(0.03, float(item_data.get("animation_frame_seconds", 0.45)))


func materialize_foreground_block_node(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_data_value: Variant = world.blocks.get(grid_pos, {})
	if not (block_data_value is Dictionary):
		return false
	var block_data: Dictionary = block_data_value
	var existing_node_value: Variant = block_data.get("node", null)
	if existing_node_value is Node and is_instance_valid(existing_node_value):
		return true

	var block_type := str(block_data.get("type", ""))
	if block_type == "":
		return false

	clear_foreground_crack_visual_for_data(block_data)
	clear_tilemap_cell(grid_pos, false)
	clear_foreground_tilemap_collision_cell(grid_pos)

	var block = world.block_scene.instantiate()
	block.position = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	world.add_child(block)

	block_data["node"] = block
	block_data["tilemap_only"] = false
	block_data.erase("tilemap_collision")
	block_data.erase("tilemap_collision_replaces_node")
	block_data.erase("tilemap_collision_kind")
	world.blocks[grid_pos] = block_data

	set_block_texture(block, block_type, grid_pos, false)
	configure_block_collision(block, block_type, grid_pos)
	update_block_light_fx(grid_pos)
	return true


func sync_tilemap_visual_for_block(block, grid_pos: Vector2i, block_type: String, visual_block_type: String, background := false, visual: Sprite2D = null) -> bool:
	if block == null or not is_instance_valid(block) or visual == null:
		clear_tilemap_cell(grid_pos, background)
		return false

	var rendered_by_tilemap := false
	if is_tilemap_visual_candidate(block_type, visual_block_type, grid_pos, background, visual):
		var renderer = ensure_tilemap_renderer()
		if renderer != null:
			var tilemap_cell_source := "node_derived"
			var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, background)
			if should_use_foreground_over_player_tilemap_layer(block_type, background):
				if renderer.has_method("erase_block_cell"):
					renderer.erase_block_cell(grid_pos, false)
				rendered_by_tilemap = sync_renderer_over_player_visual_cell(renderer, grid_pos, visual.texture, metadata, tilemap_cell_source)
			elif should_use_foreground_feature_tilemap_layer(block_type, background):
				if renderer.has_method("erase_block_cell"):
					renderer.erase_block_cell(grid_pos, false)
				rendered_by_tilemap = sync_renderer_feature_visual_cell(renderer, grid_pos, visual.texture, metadata, tilemap_cell_source)
			else:
				if not background and renderer.has_method("erase_foreground_feature_cell"):
					renderer.erase_foreground_feature_cell(grid_pos)
				if not background and renderer.has_method("erase_foreground_over_player_cell"):
					renderer.erase_foreground_over_player_cell(grid_pos)
				rendered_by_tilemap = sync_renderer_block_visual_cell(renderer, grid_pos, visual.texture, metadata, background, should_block_cast_texture_shadow(block_type, background), tilemap_cell_source)

	if rendered_by_tilemap:
		visual.visible = false
		block.set_meta("tilemap_visual", true)
		remove_block_texture_shadow(block)
		return true

	clear_tilemap_cell(grid_pos, background)
	if visual != null:
		visual.visible = true
	if block.has_meta("tilemap_visual"):
		block.remove_meta("tilemap_visual")
	sync_block_texture_shadow_to_visual(visual)
	return false


func should_use_foreground_feature_tilemap_layer(block_type: String, background := false) -> bool:
	if background:
		return false
	var clean_type := str(block_type).strip_edges().to_lower()
	return is_entrance_gate_block_type(clean_type)


func should_use_foreground_over_player_tilemap_layer(block_type: String, background := false) -> bool:
	if background:
		return false
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false
	var item_data := get_block_item_data(clean_type)
	return bool(item_data.get("foreground_over_player", false))


func apply_block_draw_order(block, block_type: String, background := false):
	if block == null or not (block is CanvasItem):
		return

	var canvas_item := block as CanvasItem
	var clean_type := block_type.strip_edges().to_lower()
	if not background and clean_type == "water":
		canvas_item.z_as_relative = false
		canvas_item.z_index = WATER_OVERLAY_Z_INDEX
		return

	if should_use_foreground_over_player_tilemap_layer(clean_type, background):
		canvas_item.z_as_relative = false
		canvas_item.z_index = FOREGROUND_OVER_PLAYER_Z_INDEX
		return

	canvas_item.z_as_relative = true
	canvas_item.z_index = NORMAL_BLOCK_Z_INDEX


func refresh_water_overlay_draw_order():
	water_overlay_draw_order_refresh_pending = false
	if world == null or not ("blocks" in world):
		return

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks.get(grid_pos, null)
		if not (block_data is Dictionary):
			continue

		var block_node = block_data.get("node", null)
		if block_node == null or not is_instance_valid(block_node):
			continue

		var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
		var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
		apply_block_draw_order(block_node, visual_block_type, false)

		if block_type == "water":
			remove_block_texture_shadow(block_node)


func remove_block_texture_shadow(block):
	if block == null or not is_instance_valid(block):
		return

	var shadow_node = block.get_node_or_null(BLOCK_TEXTURE_SHADOW_NAME)
	if shadow_node == null:
		return

	block.remove_child(shadow_node)
	shadow_node.queue_free()


func should_block_cast_texture_shadow(block_type: String, _background := false) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return false

	if clean_type == "water":
		return false

	var item_data: Dictionary = get_block_item_data(clean_type)
	if item_data.is_empty():
		return true

	if item_data.has("texture_shadow"):
		return bool(item_data.get("texture_shadow", true))

	return true


func sync_block_texture_shadow_to_visual(visual: Sprite2D):
	if visual == null:
		return

	var block = visual.get_parent()
	if block == null or not is_instance_valid(block):
		return

	var shadow_node = block.get_node_or_null(BLOCK_TEXTURE_SHADOW_NAME)
	if shadow_node == null or not (shadow_node is Sprite2D):
		return

	var shadow_sprite := shadow_node as Sprite2D
	shadow_sprite.texture = visual.texture
	shadow_sprite.centered = visual.centered
	shadow_sprite.offset = visual.offset
	shadow_sprite.flip_h = visual.flip_h
	shadow_sprite.flip_v = visual.flip_v
	shadow_sprite.scale = visual.scale
	shadow_sprite.rotation = visual.rotation
	shadow_sprite.position = visual.position + BLOCK_TEXTURE_SHADOW_OFFSET
	shadow_sprite.z_as_relative = visual.z_as_relative
	shadow_sprite.z_index = visual.z_index - 1
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.modulate = Color(0.0, 0.0, 0.0, BLOCK_TEXTURE_SHADOW_ALPHA)
	shadow_sprite.visible = visual.visible and visual.texture != null


func update_block_texture_shadow(block, block_type: String, visual: Sprite2D, background := false):
	if block == null or not is_instance_valid(block) or visual == null:
		return

	if visual.texture == null or not should_block_cast_texture_shadow(block_type, background):
		remove_block_texture_shadow(block)
		return

	var shadow_node = block.get_node_or_null(BLOCK_TEXTURE_SHADOW_NAME)
	var shadow_sprite: Sprite2D = null

	if shadow_node != null:
		if shadow_node is Sprite2D:
			shadow_sprite = shadow_node as Sprite2D
		else:
			block.remove_child(shadow_node)
			shadow_node.queue_free()

	if shadow_sprite == null:
		shadow_sprite = Sprite2D.new()
		shadow_sprite.name = BLOCK_TEXTURE_SHADOW_NAME
		block.add_child(shadow_sprite)

	sync_block_texture_shadow_to_visual(visual)


func apply_original_collision_layout(block, block_type: String):
	if block == null or world == null:
		return

	var collision = block.get_node_or_null("CollisionShape2D")
	if collision == null:
		return

	var default_size = Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var item_data = world.item_database.get(block_type, {})
	var collision_size = parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset = parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)
	var rect_shape: RectangleShape2D

	if collision.shape is RectangleShape2D:
		rect_shape = collision.shape.duplicate() as RectangleShape2D
	else:
		rect_shape = RectangleShape2D.new()

	rect_shape.size = collision_size
	collision.shape = rect_shape
	collision.position = collision_offset


func normalize_block_variant_at(grid_pos: Vector2i, background := false):
	if background:
		if not background_blocks.has(grid_pos):
			return

		var background_data: Dictionary = background_blocks[grid_pos]
		var background_type := str(background_data.get("type", ""))
		var background_node = background_data.get("node", null)
		if bool(background_data.get("tilemap_only", false)) or background_node == null or not is_instance_valid(background_node):
			if sync_tilemap_only_background_block(grid_pos, background_type):
				background_data["node"] = null
				background_data["tilemap_only"] = true
				background_blocks[grid_pos] = background_data
				return
			return

		set_block_texture(background_node, background_type, grid_pos, true)
		apply_background_block_style(background_node)
		return

	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	var block_node = block_data.get("node", null)
	var block_type := str(block_data.get("type", ""))
	if block_node == null or not is_instance_valid(block_node):
		if bool(block_data.get("tilemap_only", false)):
			if sync_tilemap_only_foreground_block(grid_pos, block_type):
				block_data = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
				world.blocks[grid_pos] = block_data
				return
			materialize_foreground_block_node(grid_pos)
		return

	if is_anti_punch_block_type(block_type) or is_anti_talk_block_type(block_type) or is_anti_gravity_block_type(block_type) or is_theme_machine_block_type(block_type) or is_oil_refinery_animation_block_type(block_type):
		refresh_stateful_block_animation_after_texture_refresh(grid_pos, block_type, block_node)
		return

	set_block_texture(block_node, block_type, grid_pos, false)


func refresh_connected_variant_component_at(grid_pos: Vector2i, refreshed_cells: Dictionary) -> void:
	var block_type := get_foreground_block_type_at(grid_pos)
	if block_type == "" or not has_connected_visual_variants(block_type):
		return

	var component_data := get_connected_variant_component_data(block_type, grid_pos)
	if component_data.is_empty():
		return

	var cells: Array = component_data.get("cells", [])
	for raw_cell in cells:
		if not (raw_cell is Vector2i):
			continue
		if refreshed_cells.has(raw_cell):
			continue
		refreshed_cells[raw_cell] = true
		normalize_block_variant_at(raw_cell, false)


func refresh_connected_variant_components_around(grid_pos: Vector2i) -> void:
	if world == null:
		return

	var refreshed_cells: Dictionary = {}
	for candidate in [
		grid_pos,
		Vector2i(grid_pos.x - 1, grid_pos.y),
		Vector2i(grid_pos.x + 1, grid_pos.y),
		Vector2i(grid_pos.x, grid_pos.y - 1),
		Vector2i(grid_pos.x, grid_pos.y + 1)
	]:
		refresh_connected_variant_component_at(candidate, refreshed_cells)


func refresh_barn_autotile_around(grid_pos: Vector2i) -> void:
	if world == null:
		return

	clear_connected_variant_component_cache()
	var refreshed_cells: Dictionary = {}
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var candidate := Vector2i(grid_pos.x + x_offset, grid_pos.y + y_offset)
			if refreshed_cells.has(candidate):
				continue
			if not is_barn_block_at(candidate):
				continue
			refreshed_cells[candidate] = true
			normalize_block_variant_at(candidate, false)


func has_neighbor_dependent_visual_variant(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false

	if clean_type == "dirt" \
		or clean_type == "water" \
		or clean_type == "wood" \
		or clean_type == "climbing_vine" \
		or clean_type == BARN_BLOCK_TYPE:
		return true

	# Snow-storm leaf caps depend on whether another leaf is directly above.
	if snow_storm_visuals_active and clean_type == "leaf":
		return true

	return has_platform_visual_variants(clean_type) \
		or has_vertical_variant_atlas_coords(clean_type) \
		or has_connected_visual_variants(clean_type)


func refresh_neighbor_dependent_block_variant_at(grid_pos: Vector2i, refreshed_cells: Dictionary) -> void:
	if refreshed_cells.has(grid_pos):
		return

	var block_type := get_foreground_block_type_at(grid_pos)
	if not has_neighbor_dependent_visual_variant(block_type):
		return

	refreshed_cells[grid_pos] = true
	normalize_block_variant_at(grid_pos, false)


func update_vertical_block_variants_around(grid_pos: Vector2i):
	clear_connected_variant_component_cache()
	var refreshed_cells: Dictionary = {}

	# Vertical stacks need local neighbor refreshes after place/break/load:
	# dirt top stays dirt_block, lower dirt alternates stable variants;
	# water top stays water_0, deeper water uses atlas coord (5, 3);
	# tree trunks, climbing vines, and atlas-backed stacks use top/middle/bottom visuals while keeping one saved block ID.
	for y_offset in range(-2, 3):
		refresh_neighbor_dependent_block_variant_at(Vector2i(grid_pos.x, grid_pos.y + y_offset), refreshed_cells)

	# Wood platforms use horizontal visual joins:
	# single = standalone, two = left/right, longer runs = left/middle/right.
	for x_offset in range(-2, 3):
		refresh_neighbor_dependent_block_variant_at(Vector2i(grid_pos.x + x_offset, grid_pos.y), refreshed_cells)

	# Connected atlas variants can depend on both axes, so refresh a small
	# neighborhood around the edited block.
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			refresh_neighbor_dependent_block_variant_at(
				Vector2i(grid_pos.x + x_offset, grid_pos.y + y_offset),
				refreshed_cells
			)
	refresh_connected_variant_components_around(grid_pos)
	refresh_barn_autotile_around(grid_pos)

	# Anti-control visuals are stateful blocks and do not depend on dirt/water/wood
	# neighbor variants. Refreshing every anti-control block after every normal
	# place/break scans the world and can cause placement FPS spikes. Keep full
	# anti-control refreshes for world-load/state-change paths only.


func finalize_world_load_block_variants(batch_size: int = WORLD_LOAD_VARIANT_FINALIZE_BATCH_SIZE) -> void:
	# During bulk world loading we intentionally skip per-block neighbor refreshes to
	# avoid thousands of repeated updates. Run one batched pass after all blocks are
	# present so connected/stacked visuals are correct before the loading overlay hides.
	if world == null:
		return

	# Stop any background variant pass still running from a previous world load before starting
	# this one. Covers the case where the previous join deferred nothing (so it never bumped the
	# generation itself) and the new world happens to have the same name.
	cancel_deferred_variant_finalize()

	clear_connected_variant_component_cache()
	var safe_batch_size: int = maxi(1, batch_size)
	# Initial world entry: the screen is covered by the loading overlay, so trade loading-screen
	# frame rate for time-to-playable. See WORLD_ENTRY_VARIANT_FINALIZE_BATCH_SIZE.
	if batch_size == WORLD_LOAD_VARIANT_FINALIZE_BATCH_SIZE and is_bulk_world_load_active():
		safe_batch_size = WORLD_ENTRY_VARIANT_FINALIZE_BATCH_SIZE
	var processed: int = 0

	var foreground_keys: Array = []
	if "blocks" in world and world.blocks is Dictionary:
		foreground_keys = world.blocks.keys()
	var background_keys: Array = background_blocks.keys()

	# Spawn-prioritized variant finalize.
	#
	# Measured on a real join: this pass cost ~350ms on BOTH a 42KB world and a 135KB world.
	# It is invariant to world CONTENT because it is proportional to the world GRID -- every
	# world is 100x70 and fully generated, so all of them carry ~7,000 foreground blocks, and
	# each one costs ~50us of genuine variant work (dirt picking its lower variant from the
	# block above, stone/sand picking weighted variants from grid position, platform/vertical/
	# connected joins). None of that is redundant, so no cache removes it -- the only way to
	# stop paying it at join time is to do fewer blocks before handing over control.
	#
	# The player can only SEE roughly one screen (~40x23 cells) at the instant they gain
	# control, which is about a tenth of the grid. So finalize the region around the spawn
	# point first, hand over control, and resolve the remainder in the background.
	#
	# What can be seen while the background pass runs: an offscreen block briefly showing its
	# base texture rather than its variant (plain dirt before the "dirt with a block above it"
	# variant applies). Collision, block identity, drops and locks are all unaffected -- those
	# come from the authoritative snapshot and were already applied before this pass runs.
	# normalize_block_variant_at is purely a visual-atlas refresh.
	var prioritize := is_bulk_world_load_active()
	var deferred_foreground: Array = []
	var deferred_background: Array = []
	var priority_center := _get_variant_finalize_priority_center()

	for raw_grid_pos in foreground_keys:
		if not (raw_grid_pos is Vector2i):
			continue
		if prioritize and not _is_within_variant_finalize_priority(raw_grid_pos, priority_center):
			deferred_foreground.append(raw_grid_pos)
			continue

		normalize_block_variant_at(raw_grid_pos, false)
		processed += 1

		if processed >= safe_batch_size:
			processed = 0
			await get_tree().process_frame

	for raw_bg_grid_pos in background_keys:
		if not (raw_bg_grid_pos is Vector2i):
			continue
		if prioritize and not _is_within_variant_finalize_priority(raw_bg_grid_pos, priority_center):
			deferred_background.append(raw_bg_grid_pos)
			continue

		normalize_block_variant_at(raw_bg_grid_pos, true)
		processed += 1

		if processed >= safe_batch_size:
			processed = 0
			await get_tree().process_frame

	await optimize_node_backed_blocks_to_tilemap(safe_batch_size)

	# Hand the offscreen remainder to a background pass. Started AFTER the visible region and
	# the node-backed conversion are complete, so nothing the player can see is waiting on it.
	if deferred_foreground.size() > 0 or deferred_background.size() > 0:
		_start_deferred_variant_finalize(deferred_foreground, deferred_background)
	queue_anti_control_visual_refresh()

	# Recompute the active chunks after the entry spawn/camera changed, then rebuild
	# every active layer from the authoritative cache. A dirty-only flush can miss
	# cached cells and leave their node sprites hidden until a nearby live edit.
	var renderer = ensure_tilemap_renderer()
	if renderer != null and renderer.has_method("refresh_streaming_now"):
		renderer.call("refresh_streaming_now")
	elif renderer != null and renderer.has_method("_process_dirty_chunks"):
		renderer.call("_process_dirty_chunks", true)

	await get_tree().process_frame


# Half-extents (in cells) of the region finalized synchronously before the player gains
# control. A 1280x720 viewport at BLOCK_SIZE 32 shows 40x23 cells, so 30x18 half-extents cover
# the visible screen plus a generous margin on every side -- the player would have to teleport,
# not walk, to reach unfinalized ground before the background pass gets there.
const VARIANT_FINALIZE_PRIORITY_HALF_WIDTH := 30
const VARIANT_FINALIZE_PRIORITY_HALF_HEIGHT := 18
# Blocks per frame in the background pass. Deliberately smaller than the entry batch size: by
# the time this runs the player is in control, so this pass must NOT cause gameplay hitches.
const DEFERRED_VARIANT_FINALIZE_BATCH_SIZE := 256

var deferred_variant_finalize_generation: int = 0


func _get_variant_finalize_priority_center() -> Vector2i:
	# The player has already been placed at the entry spawn by the time this pass runs (see the
	# entrance-gate/door placement in world_state_sync_manager before client_world_objects_applied),
	# so their grid position is the correct centre for "what can be seen right now".
	if world != null and world.has_method("get_player_grid_position"):
		var grid_value = world.get_player_grid_position()
		# get_player_grid_position() returns Vector2i.ZERO when the player node is missing, and
		# (0,0) is the top-left corner of the world -- never a real spawn. Treat it as "unknown"
		# so we centre on the world instead of finalizing an empty corner of the sky.
		if grid_value is Vector2i and (grid_value as Vector2i) != Vector2i.ZERO:
			return grid_value as Vector2i
	# Fall back to the middle of the world rather than (0,0), which would bias the priority box
	# into the top-left corner and leave the actual spawn area unfinalized.
	var width: int = int(world.WORLD_WIDTH) if world != null and "WORLD_WIDTH" in world else 100
	var height: int = int(world.WORLD_HEIGHT) if world != null and "WORLD_HEIGHT" in world else 70
	return Vector2i(int(width / 2.0), int(height / 2.0))


func _is_within_variant_finalize_priority(grid_pos: Vector2i, center: Vector2i) -> bool:
	return (
		absi(grid_pos.x - center.x) <= VARIANT_FINALIZE_PRIORITY_HALF_WIDTH
		and absi(grid_pos.y - center.y) <= VARIANT_FINALIZE_PRIORITY_HALF_HEIGHT
	)


func cancel_deferred_variant_finalize() -> void:
	# Bump the generation so any in-flight background pass stops on its next batch. Called when a
	# new world load begins so a stale pass cannot write variants into the newly loaded world.
	deferred_variant_finalize_generation += 1


# Finishes variant normalization for the offscreen blocks that finalize_world_load_block_variants
# skipped. Runs while the player is already in control, so it yields frequently and aborts
# immediately if the world changes underneath it.
func _start_deferred_variant_finalize(foreground_keys: Array, background_keys: Array) -> void:
	deferred_variant_finalize_generation += 1
	var generation: int = deferred_variant_finalize_generation
	var world_name := ""
	if world != null:
		world_name = str(world.current_world_name).strip_edges().to_upper()
	_run_deferred_variant_finalize(foreground_keys, background_keys, generation, world_name)


func _is_deferred_variant_finalize_current(generation: int, world_name: String) -> bool:
	if generation != deferred_variant_finalize_generation:
		return false
	if world == null or not is_instance_valid(world):
		return false
	if get_tree() == null:
		return false
	return str(world.current_world_name).strip_edges().to_upper() == world_name


func _run_deferred_variant_finalize(
	foreground_keys: Array,
	background_keys: Array,
	generation: int,
	world_name: String
) -> void:
	var processed: int = 0

	for raw_grid_pos in foreground_keys:
		if not _is_deferred_variant_finalize_current(generation, world_name):
			return
		if not (raw_grid_pos is Vector2i):
			continue
		# The block may have been broken or replaced by live gameplay since it was deferred.
		if not world.blocks.has(raw_grid_pos):
			continue
		normalize_block_variant_at(raw_grid_pos, false)
		processed += 1
		if processed >= DEFERRED_VARIANT_FINALIZE_BATCH_SIZE:
			processed = 0
			await get_tree().process_frame

	for raw_bg_grid_pos in background_keys:
		if not _is_deferred_variant_finalize_current(generation, world_name):
			return
		if not (raw_bg_grid_pos is Vector2i):
			continue
		if not background_blocks.has(raw_bg_grid_pos):
			continue
		normalize_block_variant_at(raw_bg_grid_pos, true)
		processed += 1
		if processed >= DEFERRED_VARIANT_FINALIZE_BATCH_SIZE:
			processed = 0
			await get_tree().process_frame

	if not _is_deferred_variant_finalize_current(generation, world_name):
		return
	# Flush whatever the deferred writes marked dirty so the offscreen variants are present in
	# the tilemap before the player streams into those chunks.
	var renderer = ensure_tilemap_renderer()
	if renderer != null and renderer.has_method("_process_dirty_chunks"):
		renderer.call("_process_dirty_chunks", true)


func schedule_world_entry_tilemap_visual_reconciliation() -> void:
	if world == null or get_tree() == null:
		return

	var expected_world_name := str(world.current_world_name).strip_edges().to_upper()
	var expected_apply_generation := 0
	var sync_manager = world.get("world_state_sync_manager")
	if sync_manager != null and "world_state_apply_generation" in sync_manager:
		expected_apply_generation = int(sync_manager.get("world_state_apply_generation"))
	_run_world_entry_tilemap_visual_reconciliation(expected_world_name, expected_apply_generation)


func _run_world_entry_tilemap_visual_reconciliation(expected_world_name: String, expected_apply_generation: int) -> void:
	await get_tree().process_frame
	if not _is_world_entry_tilemap_visual_reconciliation_current(expected_world_name, expected_apply_generation):
		return

	var renderer = ensure_tilemap_renderer()
	if renderer == null:
		return
	if renderer.has_method("refresh_streaming_now"):
		renderer.call("refresh_streaming_now")

	# A second frame catches cells affected by deferred node retirement or by the
	# camera transform becoming current after the entry overlay was removed.
	await get_tree().process_frame
	if not _is_world_entry_tilemap_visual_reconciliation_current(expected_world_name, expected_apply_generation):
		return
	if is_instance_valid(renderer) and renderer.has_method("reconcile_active_cells"):
		renderer.call("reconcile_active_cells")


func _is_world_entry_tilemap_visual_reconciliation_current(expected_world_name: String, expected_apply_generation: int) -> bool:
	if world == null or not bool(world.in_world):
		return false
	if str(world.current_world_name).strip_edges().to_upper() != expected_world_name:
		return false

	var sync_manager = world.get("world_state_sync_manager")
	if sync_manager != null and "world_state_apply_generation" in sync_manager:
		return int(sync_manager.get("world_state_apply_generation")) == expected_apply_generation
	return expected_apply_generation == 0


func _can_convert_node_backed_block_to_tilemap(reason: String) -> bool:
	var clean_reason := reason.strip_edges()
	if clean_reason == "eligible leftover":
		return true
	if clean_reason.begins_with("tilemapped kept:"):
		return true
	return false


func optimize_node_backed_blocks_to_tilemap(batch_size: int = WORLD_LOAD_VARIANT_FINALIZE_BATCH_SIZE) -> void:
	if world == null:
		return

	var safe_batch_size := maxi(1, batch_size)
	var processed := 0

	if "blocks" in world and world.blocks is Dictionary:
		var foreground_keys: Array = world.blocks.keys()
		for raw_grid_pos in foreground_keys:
			if not (raw_grid_pos is Vector2i):
				continue

			var block_data_value: Variant = world.blocks.get(raw_grid_pos, {})
			if not (block_data_value is Dictionary):
				continue
			var block_data: Dictionary = block_data_value
			if bool(block_data.get("tilemap_only", false)):
				continue

			var block_node_value: Variant = block_data.get("node", null)
			if not (block_node_value is Node and is_instance_valid(block_node_value)):
				continue

			var block_type := str(block_data.get("type", ""))
			var reason := get_foreground_node_backed_tilemap_reason(raw_grid_pos, block_type, block_node_value as Node)
			if not _can_convert_node_backed_block_to_tilemap(reason):
				continue

			if not sync_tilemap_only_foreground_block(raw_grid_pos, block_type):
				continue

			var block_node := block_node_value as Node
			clear_foreground_crack_visual_for_data(block_data)
			clear_block_animation(block_node)
			retire_block_node_for_removal(block_node)
			block_node.queue_free()
			block_data["node"] = null
			block_data = sync_tilemap_only_foreground_metadata(raw_grid_pos, block_data, block_type)
			world.blocks[raw_grid_pos] = block_data

			processed += 1
			if processed >= safe_batch_size:
				processed = 0
				await get_tree().process_frame

	if background_blocks is Dictionary:
		var background_keys: Array = background_blocks.keys()
		for raw_bg_grid_pos in background_keys:
			if not (raw_bg_grid_pos is Vector2i):
				continue

			var background_data_value: Variant = background_blocks.get(raw_bg_grid_pos, {})
			if not (background_data_value is Dictionary):
				continue
			var background_data: Dictionary = background_data_value
			if bool(background_data.get("tilemap_only", false)):
				continue

			var background_node_value: Variant = background_data.get("node", null)
			if not (background_node_value is Node and is_instance_valid(background_node_value)):
				continue

			var block_type := str(background_data.get("type", ""))
			var reason := get_background_node_backed_tilemap_reason(raw_bg_grid_pos, block_type)
			if not _can_convert_node_backed_block_to_tilemap(reason):
				continue

			if not sync_tilemap_only_background_block(raw_bg_grid_pos, block_type):
				continue

			var background_node := background_node_value as Node
			clear_background_crack_visual_for_data(background_data)
			clear_block_animation(background_node)
			retire_block_node_for_removal(background_node)
			background_node.queue_free()
			background_data["node"] = null
			background_data["tilemap_only"] = true
			background_blocks[raw_bg_grid_pos] = background_data

			processed += 1
			if processed >= safe_batch_size:
				processed = 0
				await get_tree().process_frame


func create_background_block(grid_pos: Vector2i, block_type: String = "cave_background"):
	if background_blocks.has(grid_pos):
		return

	if create_tilemap_only_background_block(grid_pos, block_type):
		return

	var parent = get_background_blocks_parent()

	if parent == null:
		return

	var block = world.block_scene.instantiate()
	block.position = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	block.z_index = 0
	block.z_as_relative = true
	parent.add_child(block)

	background_blocks[grid_pos] = {
		"node": block,
		"type": block_type,
		"item_id": get_atlas_item_id_for_block_type(block_type)
	}
	authoritative_place_request_times.erase(get_authoritative_place_key("background", grid_pos, block_type))

	set_block_texture(block, block_type, grid_pos, true)
	apply_background_block_style(block)
	configure_block_collision(block, block_type)


func remove_background_block_without_drop(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_data: Dictionary = background_blocks[grid_pos]
	if bool(block_data.get("_predicted_authoritative_place", false)):
		trace_authoritative_place_event("predicted_visual_removed", {
			"reason": "remove_background_block_without_drop",
			"layer": "background",
			"grid_pos": grid_pos,
			"block_type": str(block_data.get("type", "")),
			"request_id": str(block_data.get("_predicted_request_id", "")),
			"cell_before": get_place_trace_cell_state("background", grid_pos)
		})
	var block_node = block_data.get("node", null)
	clear_background_crack_visual_for_data(block_data)
	clear_tilemap_cell(grid_pos, true)

	if block_node != null and is_instance_valid(block_node):
		clear_block_animation(block_node)
		retire_block_node_for_removal(block_node)
		block_node.queue_free()

	background_blocks.erase(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)


func replace_background_block_without_drop(grid_pos: Vector2i, block_type: String = "cave_background"):
	if background_blocks.has(grid_pos):
		remove_background_block_without_drop(grid_pos)

	create_background_block(grid_pos, block_type)


func clear_authoritative_break_state_for_grid(grid_pos: Vector2i, layer: String = "") -> void:
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer == "" or clean_layer == "foreground":
		authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
	if clean_layer == "" or clean_layer == "background":
		authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)
	update_block_crack_visual(grid_pos)
	update_background_block_crack_visual(grid_pos)


func clear_all_authoritative_break_state() -> void:
	var positions := {}
	for grid_pos in world.block_hit_progress.keys():
		positions[grid_pos] = true
	for grid_pos in world.block_hit_timers.keys():
		positions[grid_pos] = true
	authoritative_break_request_keys.clear()
	world.block_hit_progress.clear()
	world.block_hit_timers.clear()
	for grid_pos in positions.keys():
		update_block_crack_visual(grid_pos)
		update_background_block_crack_visual(grid_pos)


func handle_rejected_block_update(data: Dictionary) -> bool:
	var reason := str(data.get("reason", "")).strip_edges().to_lower()
	var message := str(data.get("message", "")).strip_edges().to_lower()
	var request_id := get_request_id_from_block_payload(data)
	trace_authoritative_place_event("server_rejected_block_update", {
		"reason": reason,
		"message": message,
		"request_id": get_request_id_from_block_payload(data),
		"action": str(data.get("action", "")),
		"layer": str(data.get("layer", "foreground")),
		"x": int(data.get("x", data.get("target_x", 0))),
		"y": int(data.get("y", data.get("target_y", 0))),
		"block_type": str(data.get("block_type", data.get("item_id", ""))),
		"payload": data
	})
	var exact_pending_request := get_predicted_authoritative_place_request_key(data, false)
	var is_duplicate_notice := reason.contains("duplicate") or message.contains("duplicate request")
	if is_duplicate_notice:
		if exact_pending_request != "":
			request_authoritative_place_reconciliation(exact_pending_request)
		# A duplicate notice is not proof that the original placement failed.
		return true
	var rolled_back_prediction := false
	if request_id != "" and exact_pending_request != "":
		rolled_back_prediction = rollback_predicted_authoritative_place(data, false)
	if rolled_back_prediction and world != null and world.has_method("end_fast_block_place_hold"):
		world.end_fast_block_place_hold(-1)
	if reason != "break_rate_limited" and reason != "rate_limited" and not message.contains("slow down"):
		return false

	var has_grid := data.has("x") or data.has("target_x")
	if has_grid:
		var grid_pos := Vector2i(
			int(data.get("x", data.get("target_x", 0))),
			int(data.get("y", data.get("target_y", 0)))
		)
		clear_authoritative_break_state_for_grid(grid_pos, str(data.get("layer", "")))
	else:
		clear_all_authoritative_break_state()

	return true


func clear_background_blocks():
	for grid_pos in background_blocks.keys():
		var block_data: Dictionary = background_blocks[grid_pos]
		var block_node = block_data.get("node", null)
		clear_background_crack_visual_for_data(block_data)
		clear_tilemap_cell(grid_pos, true)

		if block_node != null and is_instance_valid(block_node):
			clear_block_animation(block_node)
			retire_block_node_for_removal(block_node)
			block_node.queue_free()

	background_blocks.clear()
	authoritative_break_request_keys.clear()
	authoritative_place_request_times.clear()
	authoritative_place_last_request_ms = 0


func clear_background_crack_visual_for_data(block_data: Dictionary) -> void:
	var overlay_value: Variant = block_data.get("crack_overlay", null)
	if overlay_value is Node and is_instance_valid(overlay_value):
		var stored_overlay: Node = overlay_value
		stored_overlay.queue_free()
	block_data.erase("crack_overlay")

	var block_node_value: Variant = block_data.get("node", null)
	if block_node_value is Node and is_instance_valid(block_node_value):
		var block_node: Node = block_node_value
		var crack_overlay: Node = block_node.get_node_or_null("CrackOverlay")
		if crack_overlay != null:
			crack_overlay.queue_free()


func update_background_block_crack_visual(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_data: Dictionary = background_blocks[grid_pos]
	var block_node_value: Variant = block_data.get("node", null)
	var block_node: Node = null
	if block_node_value is Node and is_instance_valid(block_node_value):
		block_node = block_node_value
	var block_type = str(block_data.get("type", ""))

	var max_hits = get_block_max_hits(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0))
	var stage = get_crack_stage(current_hits, max_hits)

	if stage <= 0:
		clear_background_crack_visual_for_data(block_data)
		background_blocks[grid_pos] = block_data
		return

	if not world.crack_textures.has(stage):
		return

	var crack_overlay: Sprite2D = null
	if block_node != null:
		var node_crack_overlay: Node = block_node.get_node_or_null("CrackOverlay")
		if node_crack_overlay is Sprite2D:
			crack_overlay = node_crack_overlay

		if crack_overlay == null:
			crack_overlay = create_background_node_crack_overlay(block_node)
	else:
		var stored_overlay_value: Variant = block_data.get("crack_overlay", null)
		if stored_overlay_value is Sprite2D and is_instance_valid(stored_overlay_value):
			crack_overlay = stored_overlay_value

		if crack_overlay == null:
			crack_overlay = create_background_tilemap_crack_overlay(grid_pos, block_data)

	if crack_overlay == null:
		return

	var crack_texture_value: Variant = world.crack_textures[stage]
	if crack_texture_value is Texture2D:
		crack_overlay.texture = crack_texture_value
	crack_overlay.visible = true


func create_background_node_crack_overlay(block_node: Node) -> Sprite2D:
	var crack_overlay = Sprite2D.new()
	crack_overlay.name = "CrackOverlay"
	crack_overlay.centered = true
	crack_overlay.position = Vector2.ZERO
	crack_overlay.z_index = 20
	crack_overlay.z_as_relative = true
	block_node.add_child(crack_overlay)
	return crack_overlay


func create_background_tilemap_crack_overlay(grid_pos: Vector2i, block_data: Dictionary) -> Sprite2D:
	var parent = get_background_blocks_parent()
	if parent == null:
		return null

	var crack_overlay = Sprite2D.new()
	crack_overlay.name = "BackgroundCrackOverlay"
	crack_overlay.centered = true
	crack_overlay.position = get_block_sound_position(grid_pos)
	crack_overlay.z_as_relative = false
	crack_overlay.z_index = BACKGROUND_CRACK_Z_INDEX
	crack_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(crack_overlay)
	block_data["crack_overlay"] = crack_overlay
	background_blocks[grid_pos] = block_data
	return crack_overlay


func try_consume_block_break_input_cadence() -> bool:
	var now_msec: int = Time.get_ticks_msec()
	if last_block_break_input_at_msec > 0 and now_msec - last_block_break_input_at_msec < BLOCK_BREAK_INPUT_INTERVAL_MSEC:
		return false

	last_block_break_input_at_msec = now_msec
	return true


func hit_background_block_grid(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_type = str(background_blocks[grid_pos]["type"])

	if world.has_method("can_current_player_break_block_at") and not world.can_current_player_break_block_at(block_type, grid_pos):
		world.show_notification("This world is locked.")
		return

	if world.item_database.has(block_type) and bool(world.item_database[block_type].get("unbreakable", false)):
		world.show_notification(world.get_item_display_name(block_type, "block") + " cannot be broken.")
		return
	if not try_consume_block_break_input_cadence():
		return

	var max_hits = get_block_max_hits(block_type)
	var hit_power = world.get_current_break_power(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0)) + hit_power
	world.block_hit_progress[grid_pos] = current_hits
	world.block_hit_timers[grid_pos] = world.BLOCK_DAMAGE_RESET_DELAY

	if should_use_server_authoritative_world_actions():
		var action = "hit" if current_hits < max_hits else "break"
		var break_key = get_authoritative_break_key("background", grid_pos)
		if action == "break" and authoritative_break_request_keys.has(break_key):
			world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
			return
		if send_network_block_update(action, "background", grid_pos, block_type, {
			"hit_power": hit_power,
			"hit_count": current_hits,
			"max_hits": max_hits,
			"source_tool": get_current_block_hit_source_tool()
		}):
			if action == "break":
				authoritative_break_request_keys[break_key] = true
			spawn_block_hit_particles(grid_pos, block_type, "background")
			update_background_block_crack_visual(grid_pos)
			if action == "break":
				play_block_break_sound(grid_pos)
			if current_hits < max_hits:
				world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
			else:
				world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if current_hits < max_hits:
		send_network_block_update("hit", "background", grid_pos, block_type, {
			"source_tool": get_current_block_hit_source_tool()
		})
		spawn_block_hit_particles(grid_pos, block_type, "background")
		update_background_block_crack_visual(grid_pos)
		world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
		return

	spawn_neptune_trident_block_hit_particles(grid_pos, block_type, "background")
	play_block_break_sound(grid_pos)
	break_background_block_grid(grid_pos)


func break_background_block_grid(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_data: Dictionary = background_blocks[grid_pos]
	var block_type = str(block_data.get("type", ""))
	var block_node_value: Variant = block_data.get("node", null)
	var block_node: Node = null
	if block_node_value is Node and is_instance_valid(block_node_value):
		block_node = block_node_value
	var drop_position := get_block_sound_position(grid_pos)
	if block_node is Node2D:
		var block_node_2d := block_node as Node2D
		drop_position = block_node_2d.global_position

	if should_use_server_authoritative_world_actions() and not is_applying_network_world_update():
		if send_network_block_update("break", "background", grid_pos, block_type, {
			"source_tool": get_current_block_hit_source_tool()
		}):
			authoritative_break_request_keys[get_authoritative_break_key("background", grid_pos)] = true
			world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	clear_background_crack_visual_for_data(block_data)

	spawn_block_break_particles(grid_pos, block_type, "background")
	clear_tilemap_cell(grid_pos, true)
	if block_node != null:
		clear_block_animation(block_node)
		retire_block_node_for_removal(block_node)
		block_node.queue_free()
	background_blocks.erase(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)
	if world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()

	send_network_block_update("break", "background", grid_pos, block_type, {
		"source_tool": get_current_block_hit_source_tool()
	})

	if not should_server_create_break_drops():
		if not world.try_drop_fixed_break_drops(block_type, drop_position):
			world.try_drop_block(block_type, drop_position)
			world.try_drop_seed(block_type, drop_position)


func can_place_background_block_here(grid_pos: Vector2i) -> bool:
	if background_blocks.has(grid_pos):
		trace_place_attempt_blocked("background_cell_occupied", "background", grid_pos, str(world.selected_item_type), str(world.selected_item_category))
		world.show_notification("There is already a background block here.")
		return false

	if world.has_planted_seed(grid_pos):
		trace_place_attempt_blocked("background_blocked_by_seed", "background", grid_pos, str(world.selected_item_type), str(world.selected_item_category))
		world.show_notification("Cannot place behind a planted seed.")
		return false

	return true


func setup_crack_textures():
	world.crack_textures.clear()

	for stage in range(1, 4):
		var path = "res://Assets/effects/block_crack_" + str(stage) + ".png"

		if ResourceLoader.exists(path):
			world.crack_textures[stage] = load(path)


func get_block_max_hits(block_type: String) -> int:
	var base_max_hits := int(world.BLOCK_MAX_HITS)
	if world.item_database.has(block_type):
		base_max_hits = maxi(1, int(world.item_database[block_type].get("block_health", world.BLOCK_MAX_HITS)))

	if world.has_method("get_current_required_break_hits"):
		return int(world.get_current_required_break_hits(block_type, base_max_hits))

	return base_max_hits


func get_crack_stage(current_hits: int, max_hits: int) -> int:
	if current_hits <= 0:
		return 0

	if max_hits <= 1:
		return 0

	var damage_ratio = float(current_hits) / float(max_hits)

	if damage_ratio >= 0.75:
		return 3

	if damage_ratio >= 0.45:
		return 2

	return 1


func clear_foreground_crack_visual_for_data(block_data: Dictionary) -> void:
	var overlay_value: Variant = block_data.get("crack_overlay", null)
	if overlay_value is Node and is_instance_valid(overlay_value):
		var stored_overlay: Node = overlay_value
		stored_overlay.queue_free()
	block_data.erase("crack_overlay")

	var block_node_value: Variant = block_data.get("node", null)
	if block_node_value is Node and is_instance_valid(block_node_value):
		var block_node: Node = block_node_value
		var crack_overlay: Node = block_node.get_node_or_null("CrackOverlay")
		if crack_overlay != null:
			crack_overlay.queue_free()


func create_foreground_node_crack_overlay(block_node: Node) -> Sprite2D:
	var crack_overlay = Sprite2D.new()
	crack_overlay.name = "CrackOverlay"
	crack_overlay.centered = true
	crack_overlay.position = Vector2.ZERO
	crack_overlay.z_index = 20
	crack_overlay.z_as_relative = true
	block_node.add_child(crack_overlay)
	return crack_overlay


func create_foreground_tilemap_crack_overlay(grid_pos: Vector2i, block_data: Dictionary) -> Sprite2D:
	if world == null:
		return null

	var crack_overlay = Sprite2D.new()
	crack_overlay.name = "ForegroundCrackOverlay"
	crack_overlay.centered = true
	crack_overlay.position = get_block_sound_position(grid_pos)
	crack_overlay.z_as_relative = false
	crack_overlay.z_index = 20
	crack_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(crack_overlay)
	block_data["crack_overlay"] = crack_overlay
	world.blocks[grid_pos] = block_data
	return crack_overlay


func update_block_crack_visual(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_data: Dictionary = world.blocks[grid_pos]
	var block_node_value: Variant = block_data.get("node", null)
	var block_node: Node = null
	if block_node_value is Node and is_instance_valid(block_node_value):
		block_node = block_node_value
	var block_type = str(block_data.get("type", ""))

	var max_hits = get_block_max_hits(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0))
	var stage = get_crack_stage(current_hits, max_hits)

	if stage <= 0:
		clear_foreground_crack_visual_for_data(block_data)
		world.blocks[grid_pos] = block_data
		return

	if not world.crack_textures.has(stage):
		return

	var crack_overlay: Sprite2D = null
	if block_node != null:
		var node_crack_overlay: Node = block_node.get_node_or_null("CrackOverlay")
		if node_crack_overlay is Sprite2D:
			crack_overlay = node_crack_overlay

		if crack_overlay == null:
			crack_overlay = create_foreground_node_crack_overlay(block_node)
	else:
		var stored_overlay_value: Variant = block_data.get("crack_overlay", null)
		if stored_overlay_value is Sprite2D and is_instance_valid(stored_overlay_value):
			crack_overlay = stored_overlay_value

		if crack_overlay == null:
			crack_overlay = create_foreground_tilemap_crack_overlay(grid_pos, block_data)

	if crack_overlay == null:
		return

	crack_overlay.texture = world.crack_textures[stage]
	crack_overlay.visible = true


func is_non_collideable_block(block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "crafting_station_left" or clean_type == "crafting_station_right":
		return true
	if not world.item_database.has(clean_type):
		return false

	var item_data = world.item_database[clean_type]

	# New preferred setting:
	# "collidable": false
	if item_data.has("collidable"):
		return not bool(item_data.get("collidable", true))

	# Old/backward-compatible setting:
	# "no_collision": true
	if item_data.has("no_collision"):
		return bool(item_data.get("no_collision", false))

	return false


func does_block_have_placement_collision(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or is_background_block_type(clean_type):
		return false

	# Platform blocks replace the normal collision shape with one-way collision,
	# so they still count as colliding for same-tile placement.
	if is_platform_collision_block_type(clean_type):
		return true

	return not is_non_collideable_block(clean_type)


func block_requires_world_lock(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("requires_world_lock", false))


func world_has_world_lock() -> bool:
	if world == null or world.world_lock_manager == null:
		return false

	return bool(world.world_lock_manager.is_locked)


func block_requires_full_area_clear(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("requires_full_area_clear", false))


func block_occupies_collision_area(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("occupies_collision_area", false))


func is_foreground_tilemap_solid_collision_block(block_type: String) -> bool:
	var metadata := get_block_tilemap_metadata(block_type)
	return bool(metadata.get("solid", false)) and str(metadata.get("collision_type", "none")) == "full"


func is_simple_full_solid_foreground_collision_block(block_type: String) -> bool:
	if world == null:
		return false

	var clean_type := block_type.strip_edges().to_lower()
	if is_bedrock_block_type(clean_type):
		return true
	if clean_type == "" or not world.item_database.has(clean_type):
		return false

	if clean_type == "water":
		return false
	if is_background_block_type(clean_type):
		return false
	if is_non_collideable_block(clean_type):
		return false
	if is_platform_collision_block_type(clean_type):
		return false
	if is_wooden_entrance_block_type(clean_type):
		return false
	if is_entrance_gate_block_type(clean_type):
		return false
	if is_door_block_type(clean_type):
		return false
	if is_sign_block_type(clean_type):
		return false
	if is_toggle_block_type(clean_type):
		return false
	if is_triggered_springboard_animation_block(clean_type):
		return is_tilemap_trigger_collision_block(clean_type)
	if block_requires_full_area_clear(clean_type):
		return false
	if block_occupies_collision_area(clean_type):
		return false

	var item_data: Dictionary = world.item_database[clean_type]
	var animation_frames = item_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 1:
		if get_simple_tilemap_animation_frames(clean_type, clean_type).size() <= 1 and get_tilemap_animation_atlas_frames(clean_type, clean_type).size() <= 1:
			return false
	if item_data.has("toggle_textures") or item_data.has("entrance_frames") or has_springboard_animation_metadata(item_data):
		return false
	if str(item_data.get("light_fx_scene", "")).strip_edges() != "":
		return false

	var default_size := Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var collision_size := parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset := parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)

	return collision_size == default_size and collision_offset == Vector2.ZERO


func is_foreground_tilemap_collision_candidate(grid_pos: Vector2i, block_data: Dictionary) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type := str(block_data.get("type", ""))
	var clean_type := block_type.strip_edges().to_lower()
	# Shift Block keeps a live node for its colour-cycle animation. Keep physics
	# on that same node so world reconstruction cannot split visual and collision
	# ownership between the node and the shared TileMapLayer.
	if is_colour_cycle_block_type(clean_type):
		return false
	# World locks keep their interactive node for access-state visuals and input.
	# Keep collision on that node too so reload-time visual refreshes cannot leave
	# a lock split across node interaction and TileMapLayer physics.
	if is_world_lock_block_type(clean_type):
		return false
	# Area locks keep node collision for their owner/access interaction state.
	if is_area_lock_block_type(clean_type):
		return false
	# Lava keeps a live block node for rebound lookup, light effects, and visuals.
	# Keep its collider on that same node so streamed TileMap collision chunks
	# cannot temporarily remove or replace the hazard's physical boundary.
	if is_hybrid_hazard_tilemap_visual_candidate(clean_type):
		return false

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, false)
	return bool(metadata.get("solid", false)) and str(metadata.get("collision_type", "none")) == "full"


func sync_foreground_tilemap_collision_for_block(grid_pos: Vector2i, block_data: Dictionary) -> bool:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return false

	var block_node_value: Variant = block_data.get("node", null)
	var is_tilemap_only := bool(block_data.get("tilemap_only", false)) and (block_node_value == null or not is_instance_valid(block_node_value))
	var block_node: Node = block_node_value if block_node_value is Node and is_instance_valid(block_node_value) else null
	var block_type := str(block_data.get("type", ""))
	var keep_live_node_collision := is_colour_cycle_block_type(block_type)
	var keep_node_collision_disabled := is_non_collideable_block(block_type) or is_background_block_type(block_type) or is_sign_block_type(block_type)
	if is_wooden_entrance_tilemap_collision_block_type(block_type):
		return sync_wooden_entrance_tilemap_collision(grid_pos)

	if not foreground_tilemap_collision_enabled:
		clear_foreground_tilemap_collision_cell(grid_pos)
		if block_node != null and block_node.has_meta("tilemap_collision"):
			block_node.remove_meta("tilemap_collision")
		if block_node != null and block_node.has_meta("tilemap_collision_replaces_node"):
			block_node.remove_meta("tilemap_collision_replaces_node")
			if keep_node_collision_disabled:
				set_block_node_collision_fully_disabled(block_node, true)
			else:
				set_original_block_collision_disabled(block_node, false)
		elif block_node != null and keep_node_collision_disabled:
			set_block_node_collision_fully_disabled(block_node, true)
		if is_tilemap_only:
			block_data.erase("tilemap_collision")
			block_data.erase("tilemap_collision_kind")
			world.blocks[grid_pos] = block_data
		return false

	if not is_foreground_tilemap_collision_candidate(grid_pos, block_data):
		clear_foreground_tilemap_collision_cell(grid_pos)
		if block_node != null and block_node.has_meta("tilemap_collision"):
			block_node.remove_meta("tilemap_collision")
		var had_replaced_node_collision := block_node != null and block_node.has_meta("tilemap_collision_replaces_node")
		if had_replaced_node_collision:
			block_node.remove_meta("tilemap_collision_replaces_node")
		if block_node != null and (had_replaced_node_collision or keep_live_node_collision):
			if keep_node_collision_disabled:
				set_block_node_collision_fully_disabled(block_node, true)
			else:
				if keep_live_node_collision:
					set_block_node_collision_fully_disabled(block_node, false)
				set_original_block_collision_disabled(block_node, false)
		elif block_node != null and keep_node_collision_disabled:
			set_block_node_collision_fully_disabled(block_node, true)
		block_data.erase("tilemap_collision")
		block_data.erase("tilemap_collision_kind")
		if world.blocks.has(grid_pos):
			world.blocks[grid_pos] = block_data
		return false

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	var metadata := get_block_tilemap_metadata(block_type, visual_block_type, grid_pos, false)
	block_data["tilemap_metadata"] = metadata
	world.blocks[grid_pos] = block_data
	var renderer = ensure_tilemap_renderer()
	if renderer == null:
		clear_foreground_tilemap_collision_cell(grid_pos)
		return false

	var collision_synced: bool = false
	if bool(metadata.get("solid", false)) and str(metadata.get("collision_type", "none")) == "full":
		collision_synced = renderer.has_method("set_foreground_collision_cell") and bool(renderer.set_foreground_collision_cell(grid_pos))

	if not collision_synced:
		clear_foreground_tilemap_collision_cell(grid_pos)
		if block_node != null and block_node.has_meta("tilemap_collision"):
			block_node.remove_meta("tilemap_collision")
		if block_node != null and block_node.has_meta("tilemap_collision_replaces_node"):
			block_node.remove_meta("tilemap_collision_replaces_node")
			if keep_node_collision_disabled:
				set_block_node_collision_fully_disabled(block_node, true)
			else:
				set_original_block_collision_disabled(block_node, false)
		elif block_node != null and keep_node_collision_disabled:
			set_block_node_collision_fully_disabled(block_node, true)
		if is_tilemap_only:
			block_data.erase("tilemap_collision")
			block_data.erase("tilemap_collision_kind")
			world.blocks[grid_pos] = block_data
		return false

	if block_node != null:
		set_original_block_collision_disabled(block_node, foreground_tilemap_collision_replaces_nodes_enabled)
		block_node.set_meta("tilemap_collision", true)
		if foreground_tilemap_collision_replaces_nodes_enabled:
			block_node.set_meta("tilemap_collision_replaces_node", true)
		elif block_node.has_meta("tilemap_collision_replaces_node"):
			block_node.remove_meta("tilemap_collision_replaces_node")
	else:
		block_data["tilemap_collision"] = true
		block_data["tilemap_collision_kind"] = str(metadata.get("collision_type", "full"))
		world.blocks[grid_pos] = block_data
	return true


func clear_foreground_tilemap_collision_cell(grid_pos: Vector2i) -> void:
	var renderer = ensure_tilemap_renderer()
	if renderer != null and renderer.has_method("erase_foreground_collision_cell"):
		renderer.erase_foreground_collision_cell(grid_pos)


func set_foreground_tilemap_collision_enabled(active: bool) -> Dictionary:
	if not active:
		materialize_all_tilemap_only_foreground_blocks()
	foreground_tilemap_collision_enabled = active
	refresh_foreground_tilemap_collision()
	return get_foreground_collision_optimization_summary()


func set_foreground_tilemap_collision_replacement_enabled(active: bool) -> Dictionary:
	if not active:
		materialize_all_tilemap_only_foreground_blocks()
	foreground_tilemap_collision_replaces_nodes_enabled = active
	if active:
		foreground_tilemap_collision_enabled = true
	refresh_foreground_tilemap_collision()
	return get_foreground_collision_optimization_summary()


func is_foreground_tilemap_collision_enabled() -> bool:
	return foreground_tilemap_collision_enabled


func is_foreground_tilemap_collision_replacement_enabled() -> bool:
	return foreground_tilemap_collision_replaces_nodes_enabled


func materialize_all_tilemap_only_foreground_blocks() -> void:
	if world == null or not ("blocks" in world):
		return

	var grid_positions: Array = world.blocks.keys()
	for grid_pos in grid_positions:
		if not world.blocks.has(grid_pos):
			continue
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		if bool(block_data.get("tilemap_only", false)):
			materialize_foreground_block_node(grid_pos)


func refresh_foreground_tilemap_collision() -> void:
	if world == null or not ("blocks" in world):
		return

	for grid_pos in world.blocks.keys():
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		var block_node_value: Variant = block_data.get("node", null)
		if foreground_tilemap_collision_enabled:
			sync_foreground_tilemap_collision_for_block(grid_pos, block_data)
			continue

		clear_foreground_tilemap_collision_cell(grid_pos)
		if block_node_value is Node and is_instance_valid(block_node_value):
			var block_node: Node = block_node_value
			if block_node.has_meta("tilemap_collision"):
				block_node.remove_meta("tilemap_collision")
			if block_node.has_meta("tilemap_collision_replaces_node"):
				block_node.remove_meta("tilemap_collision_replaces_node")
				set_original_block_collision_disabled(block_node, false)
			configure_block_collision(block_node, str(block_data.get("type", "")), grid_pos)


func get_foreground_collision_optimization_summary() -> Dictionary:
	var summary: Dictionary = {
		"enabled": foreground_tilemap_collision_enabled,
		"total": 0,
		"ready": 0,
		"solid": 0,
		"simple_solid": 0,
		"platform": 0,
		"active": 0,
		"kept": 0,
		"replacing_nodes": foreground_tilemap_collision_enabled and foreground_tilemap_collision_replaces_nodes_enabled,
		"replaced_nodes": 0,
		"node_collision_kept": 0,
	}
	if world == null or not ("blocks" in world):
		return summary

	for grid_pos in world.blocks.keys():
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		var block_type := str(block_data.get("type", ""))
		summary["total"] = int(summary["total"]) + 1
		if is_foreground_tilemap_solid_collision_block(block_type):
			summary["solid"] = int(summary["solid"]) + 1
		if is_simple_full_solid_foreground_collision_block(block_type):
			summary["simple_solid"] = int(summary["simple_solid"]) + 1
		if is_tilemap_platform_collision_block(block_type):
			summary["platform"] = int(summary["platform"]) + 1
		if is_foreground_tilemap_collision_candidate(grid_pos, block_data):
			summary["ready"] = int(summary["ready"]) + 1
		var block_node_value: Variant = block_data.get("node", null)
		if bool(block_data.get("tilemap_only", false)) and (block_node_value == null or not is_instance_valid(block_node_value)):
			if bool(block_data.get("tilemap_collision", false)):
				summary["active"] = int(summary["active"]) + 1
				summary["replaced_nodes"] = int(summary["replaced_nodes"]) + 1
			continue
		if block_node_value is Node and is_instance_valid(block_node_value):
			var block_node: Node = block_node_value
			if block_node.has_meta("tilemap_collision"):
				summary["active"] = int(summary["active"]) + 1
				if block_node.has_meta("tilemap_collision_replaces_node"):
					summary["replaced_nodes"] = int(summary["replaced_nodes"]) + 1
				else:
					summary["node_collision_kept"] = int(summary["node_collision_kept"]) + 1

	summary["kept"] = max(0, int(summary["total"]) - int(summary["ready"]))
	return summary


func get_block_collision_rect_for_grid(grid_pos: Vector2i, block_type: String) -> Rect2:
	var default_size = Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var item_data = world.item_database.get(block_type, {})
	var collision_size = parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset = parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)
	var center = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE) + collision_offset
	return Rect2(center - collision_size * 0.5, collision_size)


func get_grid_positions_overlapping_rect(rect: Rect2) -> Array:
	var positions: Array = []
	var block_size = float(world.BLOCK_SIZE)
	var half_block = block_size * 0.5
	var epsilon = 0.01
	var min_x = int(floor((rect.position.x + half_block + epsilon) / block_size))
	var min_y = int(floor((rect.position.y + half_block + epsilon) / block_size))
	var max_x = int(floor((rect.position.x + rect.size.x - epsilon + half_block) / block_size))
	var max_y = int(floor((rect.position.y + rect.size.y - epsilon + half_block) / block_size))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			positions.append(Vector2i(x, y))

	return positions


func get_anchor_grid_for_block_area(grid_pos: Vector2i) -> Vector2i:
	if world == null:
		return Vector2i(999999, 999999)

	if world.blocks.has(grid_pos):
		return grid_pos

	var block_size = float(world.BLOCK_SIZE)
	var tile_center = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	var tile_rect = Rect2(
		tile_center - Vector2(block_size, block_size) * 0.5 + Vector2(0.01, 0.01),
		Vector2(block_size - 0.02, block_size - 0.02)
	)

	for existing_grid_pos in world.blocks.keys():
		var block_type = str(world.blocks[existing_grid_pos].get("type", ""))
		if not block_occupies_collision_area(block_type):
			continue

		var existing_rect = get_block_collision_rect_for_grid(existing_grid_pos, block_type)
		if existing_rect.intersects(tile_rect, false):
			return existing_grid_pos

	return world.INVALID_GRID_POS


func does_rect_overlap_reserved_object(rect: Rect2, ignore_grid_pos: Vector2i = Vector2i(999999, 999999)) -> bool:
	if world == null:
		return false

	for existing_grid_pos in world.blocks.keys():
		if existing_grid_pos == ignore_grid_pos:
			continue

		var block_type = str(world.blocks[existing_grid_pos].get("type", ""))
		if not block_occupies_collision_area(block_type):
			continue

		var existing_rect = get_block_collision_rect_for_grid(existing_grid_pos, block_type)
		if existing_rect.intersects(rect, false):
			return true

	return false


func can_place_full_collision_area(grid_pos: Vector2i, block_type: String) -> bool:
	var collision_rect = get_block_collision_rect_for_grid(grid_pos, block_type)
	var occupied_positions = get_grid_positions_overlapping_rect(collision_rect)
	var has_placement_collision := does_block_have_placement_collision(block_type)

	for check_pos in occupied_positions:
		if not world.is_grid_inside_world(check_pos):
			world.show_notification("Need enough empty space.")
			return false

		if world.blocks.has(check_pos):
			world.show_notification("Need enough empty space.")
			return false

		if world.has_planted_seed(check_pos):
			world.show_notification("Need enough empty space.")
			return false

		if has_placement_collision and world.is_block_inside_player(check_pos):
			world.show_notification("Need enough empty space.")
			return false

	if does_rect_overlap_reserved_object(collision_rect):
		world.show_notification("Need enough empty space.")
		return false

	return true


func remove_block_without_drop(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		remove_display_preview_visual(grid_pos)
		unregister_colour_cycle_block_visual(grid_pos)
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		return

	var block_data: Dictionary = world.blocks[grid_pos]
	var block_type = str(block_data.get("type", ""))
	if bool(block_data.get("_predicted_authoritative_place", false)):
		trace_authoritative_place_event("predicted_visual_removed", {
			"reason": "remove_block_without_drop",
			"layer": "foreground",
			"grid_pos": grid_pos,
			"block_type": block_type,
			"request_id": str(block_data.get("_predicted_request_id", "")),
			"cell_before": get_place_trace_cell_state("foreground", grid_pos)
		})
	var block_node = block_data.get("node", null)
	remove_display_preview_visual(grid_pos)
	clear_foreground_crack_visual_for_data(block_data)
	spawn_block_break_effect(grid_pos, block_type)
	unregister_colour_cycle_block_visual(grid_pos)
	clear_tilemap_cell(grid_pos, false)
	clear_foreground_tilemap_collision_cell(grid_pos)

	if block_node != null and is_instance_valid(block_node):
		clear_block_animation(block_node)
		retire_block_node_for_removal(block_node)
		block_node.queue_free()

	world.blocks.erase(grid_pos)
	server_triggered_animation_tokens.erase(grid_pos)
	if "vending_states" in world:
		world.vending_states.erase(grid_pos)
	if world.has_method("update_vending_machine_preview"):
		world.update_vending_machine_preview(grid_pos)
	if "mailbox_states" in world:
		world.mailbox_states.erase(grid_pos)
	if "donation_box_states" in world:
		world.donation_box_states.erase(grid_pos)
	if "bulletin_board_states" in world:
		world.bulletin_board_states.erase(grid_pos)
	if "display_states" in world:
		world.display_states.erase(grid_pos)
	if "tackle_box_states" in world:
		world.tackle_box_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "chicken_states" in world:
		world.chicken_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "cow_states" in world:
		world.cow_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "duck_states" in world:
		world.duck_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "dice_states" in world:
		world.dice_states.erase(grid_pos)
	if "anti_punch_states" in world:
		world.anti_punch_states.erase(grid_pos)
	if "anti_talk_states" in world:
		world.anti_talk_states.erase(grid_pos)
	if "anti_gravity_states" in world:
		world.anti_gravity_states.erase(grid_pos)
	if "theme_machine_states" in world:
		world.theme_machine_states.erase(grid_pos)
		refresh_world_background_theme_from_machines()
	transformer_power_states.erase(grid_pos)
	clear_active_checkpoint_if_matches(grid_pos)
	clear_tackle_box_harvest_pending(grid_pos)
	clear_chicken_interaction_pending(grid_pos)
	clear_cow_interaction_pending(grid_pos)
	clear_duck_interaction_pending(grid_pos)
	clear_dice_roll_pending(grid_pos)
	clear_dice_roll_break_window(grid_pos)
	dice_active_rolls.erase(grid_pos)
	clear_anti_punch_animation(grid_pos)
	clear_anti_talk_animation(grid_pos)
	clear_anti_gravity_animation(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)
	if not is_bulk_world_load_active():
		update_vertical_block_variants_around(grid_pos)


func replace_block_without_drop(grid_pos: Vector2i, block_type: String):
	block_type = normalize_legacy_block_id(block_type)
	if world.blocks.has(grid_pos):
		var existing_data = world.blocks.get(grid_pos, {})
		if existing_data is Dictionary and str(existing_data.get("type", "")) == block_type:
			return
		remove_block_without_drop(grid_pos)

	create_block(grid_pos, block_type)


func replace_event_block_without_drop(grid_pos: Vector2i, block_type: String):
	if world == null:
		return

	block_type = normalize_legacy_block_id(block_type)
	if block_type == "":
		remove_block_without_drop(grid_pos)
		return

	if not world.blocks.has(grid_pos):
		create_block(grid_pos, block_type)
		return

	var block_data = world.blocks[grid_pos]
	if not (block_data is Dictionary):
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		world.blocks.erase(grid_pos)
		create_block(grid_pos, block_type)
		return

	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		var _previous_invalid_block_type := str(block_data.get("type", ""))
		clear_foreground_crack_visual_for_data(block_data)
		clear_tilemap_cell(grid_pos, false)
		clear_foreground_tilemap_collision_cell(grid_pos)
		world.blocks.erase(grid_pos)
		create_block(grid_pos, block_type)
		return

	var _previous_block_type := str(block_data.get("type", ""))
	block_data["type"] = block_type
	world.blocks[grid_pos] = block_data
	authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
	authoritative_place_request_times.erase(get_authoritative_place_key("foreground", grid_pos, block_type))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)

	set_block_texture(block_node, block_type, grid_pos, false)
	configure_block_collision(block_node, block_type, grid_pos)

	if is_wooden_entrance_block_type(block_type):
		world.update_wooden_entrance_visual(grid_pos)

	if is_sign_block_type(block_type):
		world.update_sign_text_visual(grid_pos)

	if is_toggle_block_type(block_type):
		update_toggle_block_visual(grid_pos)

	if is_anti_punch_block_type(block_type):
		update_anti_punch_visual(grid_pos)

	if is_anti_talk_block_type(block_type):
		update_anti_talk_visual(grid_pos)

	if is_anti_gravity_block_type(block_type):
		update_anti_gravity_visual(grid_pos)

	if block_type == world.ENTRANCE_GATE_TYPE:
		world.update_entrance_gate_visual(grid_pos)

	update_block_light_fx(grid_pos)


func apply_background_block_style(block):
	if block == null:
		return
	var visual = block.get_node_or_null("Visual")
	if visual != null and visual is Sprite2D:
		visual.modulate = Color(1, 1, 1, 1)
		visual.z_index = -1
		sync_block_texture_shadow_to_visual(visual as Sprite2D)


func create_block(grid_pos: Vector2i, block_type: String = "dirt"):
	block_type = normalize_legacy_block_id(block_type)
	block_type = apply_snow_storm_actual_block_type(grid_pos, block_type)
	if block_type == "":
		return

	if world.blocks.has(grid_pos):
		return

	if create_tilemap_only_foreground_block(grid_pos, block_type):
		world.block_hit_progress.erase(grid_pos)
		if not is_bulk_world_load_active():
			update_vertical_block_variants_around(grid_pos)
		return

	var block = world.block_scene.instantiate()
	block.position = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	world.add_child(block)

	world.blocks[grid_pos] = {
		"node": block,
		"type": block_type,
		"item_id": get_atlas_item_id_for_block_type(block_type),
		"entrance_locked": false,
		"sign_text": "",
		"toggle_on": false
	}
	authoritative_place_request_times.erase(get_authoritative_place_key("foreground", grid_pos, block_type))

	set_block_texture(block, block_type, grid_pos, false)
	configure_block_collision(block, block_type, grid_pos)

	if is_wooden_entrance_block_type(block_type):
		world.update_wooden_entrance_visual(grid_pos)

	if is_sign_block_type(block_type):
		world.update_sign_text_visual(grid_pos)

	if is_toggle_block_type(block_type):
		update_toggle_block_visual(grid_pos)

	if is_anti_punch_block_type(block_type):
		update_anti_punch_visual(grid_pos)

	if is_anti_talk_block_type(block_type):
		update_anti_talk_visual(grid_pos)

	if is_anti_gravity_block_type(block_type):
		update_anti_gravity_visual(grid_pos)

	if block_type == world.ENTRANCE_GATE_TYPE:
		world.update_entrance_gate_visual(grid_pos)

	update_block_light_fx(grid_pos)

	world.block_hit_progress.erase(grid_pos)
	if not is_bulk_world_load_active():
		update_vertical_block_variants_around(grid_pos)


func refresh_all_block_collisions():
	if world == null:
		return

	if not "blocks" in world:
		return

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks[grid_pos]

		if not block_data.has("node") or not block_data.has("type"):
			continue

		var block_node = block_data["node"]

		if bool(block_data.get("tilemap_only", false)):
			var block_type := str(block_data["type"])
			if sync_tilemap_only_foreground_block(grid_pos, block_type):
				block_data = sync_tilemap_only_foreground_metadata(grid_pos, block_data, block_type)
				world.blocks[grid_pos] = block_data
		elif block_node != null and is_instance_valid(block_node):
			configure_block_collision(block_node, str(block_data["type"]), grid_pos)

	for grid_pos in background_blocks.keys():
		var block_data = background_blocks[grid_pos]

		if not block_data.has("node") or not block_data.has("type"):
			continue

		var block_node = block_data["node"]

		if block_node != null and is_instance_valid(block_node):
			configure_block_collision(block_node, str(block_data["type"]))


func set_block_texture(block, block_type: String, grid_pos: Vector2i = NO_VARIANT_GRID_POS, background := false):
	if block is CanvasItem:
		block.visible = true

	var visual = block.get_node_or_null("Visual")

	if visual == null:
		return

	var visual_block_type = get_snow_storm_visual_block_type(block_type, grid_pos, background)
	clear_block_animation(block, visual)
	if not background and is_mailbox_block_type(block_type):
		clear_mailbox_visual_animation(grid_pos)
	if not background and is_donation_box_block_type(block_type):
		tilemap_foreground_animated_cells.erase(grid_pos)
	if not background and is_tackle_box_block_type(block_type):
		clear_tackle_box_visual_animation(grid_pos)
	apply_block_draw_order(block, visual_block_type, background)
	apply_block_visual_layout(visual, visual_block_type)

	var variant_texture_path = get_visual_block_variant(visual_block_type, grid_pos, background)
	var stateful_texture_path = get_stateful_block_texture_path(visual_block_type, grid_pos, background)
	if stateful_texture_path != "":
		variant_texture_path = stateful_texture_path
	var using_variant_texture := false
	if variant_texture_path != "":
		var variant_texture = get_cached_visual_variant_texture(variant_texture_path)
		if variant_texture != null:
			visual.texture = variant_texture
			using_variant_texture = true
	if not using_variant_texture:
		var atlas_variant_texture := get_stateful_block_atlas_texture(block_type, visual_block_type, grid_pos, background)
		if atlas_variant_texture != null:
			visual.texture = atlas_variant_texture
			using_variant_texture = true

	if not using_variant_texture and not background and is_donation_box_block_type(visual_block_type):
		var donation_box_texture := get_donation_box_state_texture(visual_block_type, grid_pos)
		if donation_box_texture != null:
			visual.texture = donation_box_texture
			using_variant_texture = true

	if not using_variant_texture and world.block_textures.has(visual_block_type):
		visual.texture = world.block_textures[visual_block_type]
	elif not using_variant_texture and is_triggered_springboard_animation_block(visual_block_type):
		var springboard_frames = get_springboard_animation_frames(visual_block_type)
		if springboard_frames.size() > 0:
			visual.texture = springboard_frames[0]

	if not using_variant_texture and not is_triggered_springboard_animation_block(visual_block_type) and not is_server_triggered_animation_block(visual_block_type):
		setup_block_animation(block, visual_block_type, visual)

	apply_area_lock_visual_modulation(visual, block_type, grid_pos, background)
	sync_colour_cycle_block_visual(block_type, grid_pos, background, visual)
	update_block_texture_shadow(block, block_type, visual, background)
	sync_tilemap_visual_for_block(block, grid_pos, block_type, visual_block_type, background, visual)
	if not background:
		update_stateful_block_visuals(grid_pos)
		var refreshed_block_node: Node = null
		if block is Node:
			refreshed_block_node = block
		refresh_stateful_block_animation_after_texture_refresh(grid_pos, block_type, refreshed_block_node)


func is_triggered_springboard_animation_block(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	var item_data = world.item_database[block_type]
	return (bool(item_data.get("springboard", false)) or bool(item_data.get("pinball_block", false))) and has_springboard_animation_metadata(item_data)


func has_springboard_animation_metadata(item_data: Dictionary) -> bool:
	var texture_frames = item_data.get("springboard_animation_frames", [])
	if texture_frames is Array and texture_frames.size() > 1:
		return true

	var atlas_frames = item_data.get("springboard_animation_atlas_frames", [])
	return atlas_frames is Array and atlas_frames.size() > 1


func is_server_triggered_animation_block(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("server_triggered_animation", false))


func is_transformer_power_block_type(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	return clean_type == "generator" or clean_type == "transformer"


func is_transformer_powered_at(grid_pos: Vector2i) -> bool:
	var state_value: Variant = transformer_power_states.get(grid_pos, {})
	if state_value is Dictionary:
		return int((state_value as Dictionary).get("watts", 0)) > 0
	return int(state_value) > 0


func set_transformer_input_power(grid_pos: Vector2i, watts: int, max_watts: int = 0) -> void:
	var clean_watts: int = maxi(0, watts)
	if clean_watts > 0:
		transformer_power_states[grid_pos] = {
			"watts": clean_watts,
			"max_watts": maxi(1, max_watts)
		}
	else:
		transformer_power_states.erase(grid_pos)
	refresh_transformer_power_visual(grid_pos)


func clear_transformer_power_visuals() -> void:
	var powered_grids: Array = transformer_power_states.keys()
	transformer_power_states.clear()
	for grid_pos in tilemap_foreground_animated_cells.keys():
		var entry_value: Variant = tilemap_foreground_animated_cells.get(grid_pos, {})
		if entry_value is Dictionary and is_transformer_power_block_type(str((entry_value as Dictionary).get("block_type", ""))):
			tilemap_foreground_animated_cells.erase(grid_pos)
	for grid_pos in powered_grids:
		if not (grid_pos is Vector2i) or world == null or not world.blocks.has(grid_pos):
			continue
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
		if is_transformer_power_block_type(block_type):
			stop_transformer_power_animation(grid_pos, block_type, block_data)


func refresh_transformer_power_visual(grid_pos: Vector2i) -> void:
	if world == null or not world.blocks.has(grid_pos):
		transformer_power_states.erase(grid_pos)
		return

	var block_data_value: Variant = world.blocks.get(grid_pos, {})
	if not (block_data_value is Dictionary):
		transformer_power_states.erase(grid_pos)
		return
	var block_data: Dictionary = block_data_value
	var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
	if not is_transformer_power_block_type(block_type):
		transformer_power_states.erase(grid_pos)
		return

	if is_transformer_powered_at(grid_pos):
		start_transformer_power_animation(grid_pos, block_type, block_data)
	else:
		stop_transformer_power_animation(grid_pos, block_type, block_data)


func get_transformer_base_texture(block_type: String) -> Texture2D:
	var clean_type := str(block_type).strip_edges().to_lower()
	if world != null and "block_textures" in world and world.block_textures.has(clean_type):
		var cached_texture: Variant = world.block_textures.get(clean_type, null)
		if cached_texture is Texture2D:
			return cached_texture

	var item_data := get_block_item_data(clean_type)
	var texture_path := str(item_data.get("texture", "")).strip_edges()
	if texture_path == "":
		return null
	return AtlasTextureFactory.load_texture(texture_path)


func start_transformer_power_animation(grid_pos: Vector2i, block_type: String, block_data: Dictionary = {}) -> void:
	var frames := get_server_triggered_animation_frames(block_type)
	if frames.size() <= 1:
		return

	var block_node_value: Variant = block_data.get("node", null)
	if block_node_value is Node and is_instance_valid(block_node_value):
		var block_node: Node = block_node_value
		var visual_node: Node = block_node.get_node_or_null("Visual")
		if visual_node is Sprite2D:
			var visual: Sprite2D = visual_node
			var visual_id := visual.get_instance_id()
			if animated_block_visuals.has(visual_id):
				var existing_animation = animated_block_visuals[visual_id]
				if existing_animation is Dictionary and str(existing_animation.get("block_type", "")) == block_type:
					return
			clear_block_animation(block_node, visual)
			visual.visible = true
			visual.set_meta("animation_frames", frames)
			visual.set_meta("animation_frame_index", -1)
			var frame_seconds: float = maxf(0.03, float(world.item_database[block_type].get("animation_frame_seconds", 0.18)))
			animated_block_visuals[visual.get_instance_id()] = {
				"visual": visual,
				"frames": frames,
				"frame_seconds": frame_seconds,
				"block_type": block_type
			}
			apply_synced_block_animation_frame(visual, frames, frame_seconds, true, block_type)
			return

	start_tilemap_transformer_power_animation(grid_pos, block_type)


func start_tilemap_transformer_power_animation(grid_pos: Vector2i, block_type: String) -> void:
	var frames := get_server_triggered_animation_frames(block_type)
	if frames.size() <= 1:
		tilemap_foreground_animated_cells.erase(grid_pos)
		return

	var item_data := get_block_item_data(block_type)
	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": block_type,
		"frames": frames,
		"frame_seconds": maxf(0.03, float(item_data.get("animation_frame_seconds", 0.18))),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": false
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func stop_transformer_power_animation(grid_pos: Vector2i, block_type: String, block_data: Dictionary = {}) -> void:
	var entry_value: Variant = tilemap_foreground_animated_cells.get(grid_pos, {})
	if entry_value is Dictionary and is_transformer_power_block_type(str((entry_value as Dictionary).get("block_type", ""))):
		tilemap_foreground_animated_cells.erase(grid_pos)

	var block_node_value: Variant = block_data.get("node", null)
	if block_node_value is Node and is_instance_valid(block_node_value):
		var block_node: Node = block_node_value
		var visual_node: Node = block_node.get_node_or_null("Visual")
		if visual_node is Sprite2D:
			var visual: Sprite2D = visual_node
			clear_block_animation(block_node, visual)
			var base_texture := get_transformer_base_texture(block_type)
			if base_texture != null:
				visual.texture = base_texture
			visual.visible = true
			sync_block_texture_shadow_to_visual(visual)
			sync_tilemap_visual_for_block(block_node, grid_pos, block_type, block_type, false, visual)
			return

	sync_tilemap_only_foreground_block(grid_pos, block_type)


func is_oil_refinery_animation_block_type(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false
	if world != null and world.has_method("is_oil_refinery_block_type"):
		if bool(world.is_oil_refinery_block_type(clean_type)):
			return true
	if world != null and world.has_method("is_battery_charger_block_type"):
		if bool(world.is_battery_charger_block_type(clean_type)):
			return true
	var item_data := get_block_item_data(clean_type)
	if not item_data.is_empty():
		return bool(item_data.get("oil_refinery_block", false)) or bool(item_data.get("battery_charger_block", false))
	return clean_type == "oil_refinery" or clean_type == "battery_charger"


func get_oil_refinery_state(grid_pos: Vector2i) -> Dictionary:
	if world == null:
		return {}
	var block_type := ""
	if "blocks" in world and world.blocks.has(grid_pos):
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if block_data_value is Dictionary:
			block_type = str((block_data_value as Dictionary).get("type", "")).strip_edges().to_lower()
	var states_value: Variant = {}
	if block_type != "" and world.has_method("is_battery_charger_block_type") and bool(world.is_battery_charger_block_type(block_type)):
		if not ("battery_charger_states" in world):
			return {}
		states_value = world.battery_charger_states
	else:
		if not ("oil_refinery_states" in world):
			return {}
		states_value = world.oil_refinery_states
	if not (states_value is Dictionary):
		return {}
	var state_value: Variant = (states_value as Dictionary).get(grid_pos, {})
	if state_value is Dictionary:
		return (state_value as Dictionary)
	return {}


func is_oil_refinery_running_at(grid_pos: Vector2i) -> bool:
	var state := get_oil_refinery_state(grid_pos)
	if state.is_empty():
		return false
	var enabled := bool(state.get("enabled", state.get("machine_enabled", true)))
	if not enabled:
		return false
	if bool(state.get("running", state.get("is_running", state.get("processing", false)))):
		return true
	var direct_power := bool(state.get("direct_power", state.get("powered", false)))
	var battery_power := bool(state.get("battery_power", false))
	var stored_hours := float(state.get("stored_hours", state.get("runtime_hours", 0.0)))
	return direct_power or battery_power or stored_hours > 0.0


func get_oil_refinery_idle_texture(block_type: String) -> Texture2D:
	var clean_type := str(block_type).strip_edges().to_lower()
	if world != null and "block_textures" in world and world.block_textures.has(clean_type):
		var cached_texture: Variant = world.block_textures.get(clean_type, null)
		if cached_texture is Texture2D:
			return cached_texture

	var item_data := get_block_item_data(clean_type)
	var texture_spec: Variant = item_data.get("texture", null)
	if texture_spec == null:
		var frame_paths: Variant = item_data.get("animation_frames", [])
		if frame_paths is Array and (frame_paths as Array).size() > 0:
			texture_spec = (frame_paths as Array)[0]
	if texture_spec == null:
		return null
	return AtlasTextureFactory.load_texture(texture_spec)


func get_oil_refinery_running_animation_frames(block_type: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return result
	if oil_refinery_running_frame_cache.has(clean_type):
		return oil_refinery_running_frame_cache[clean_type]
	if world == null or not world.item_database.has(clean_type):
		oil_refinery_running_frame_cache[clean_type] = result
		return result

	var item_data = world.item_database[clean_type]
	var frame_paths: Array = []
	var running_paths: Variant = item_data.get("running_animation_frames", [])
	if running_paths is Array:
		frame_paths = (running_paths as Array).duplicate()
	if frame_paths.size() <= 1:
		var fallback_paths: Variant = item_data.get("animation_frames", [])
		if fallback_paths is Array and (fallback_paths as Array).size() > 1:
			for index in range(1, (fallback_paths as Array).size()):
				frame_paths.append((fallback_paths as Array)[index])
	var loop_frame_numbers: Variant = item_data.get("running_animation_loop_frames", [])
	if loop_frame_numbers is Array and (loop_frame_numbers as Array).size() > 0:
		var loop_frame_paths: Array = []
		for raw_frame_number in loop_frame_numbers:
			var loop_frame_index := int(raw_frame_number) - 1
			if loop_frame_index < 0 or loop_frame_index >= frame_paths.size():
				continue
			loop_frame_paths.append(frame_paths[loop_frame_index])
		if loop_frame_paths.size() > 0:
			frame_paths = loop_frame_paths

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			result.append(texture)

	oil_refinery_running_frame_cache[clean_type] = result
	return result


func get_oil_refinery_running_frame_seconds(block_type: String) -> float:
	var item_data := get_block_item_data(block_type)
	return maxf(0.03, float(item_data.get("running_animation_frame_seconds", item_data.get("animation_frame_seconds", 0.18))))


func sync_oil_refinery_visual_at(grid_pos: Vector2i) -> void:
	if world == null or not world.blocks.has(grid_pos):
		tilemap_foreground_animated_cells.erase(grid_pos)
		return

	var block_data_value: Variant = world.blocks.get(grid_pos, {})
	if not (block_data_value is Dictionary):
		tilemap_foreground_animated_cells.erase(grid_pos)
		return
	var block_data: Dictionary = block_data_value
	var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
	if not is_oil_refinery_animation_block_type(block_type):
		tilemap_foreground_animated_cells.erase(grid_pos)
		return

	if is_oil_refinery_running_at(grid_pos):
		start_oil_refinery_running_animation(grid_pos, block_type, block_data)
	else:
		stop_oil_refinery_running_animation(grid_pos, block_type, block_data)


func sync_battery_charger_visual_at(grid_pos: Vector2i) -> void:
	sync_oil_refinery_visual_at(grid_pos)


func start_oil_refinery_running_animation(grid_pos: Vector2i, block_type: String, block_data: Dictionary = {}) -> void:
	var frames := get_oil_refinery_running_animation_frames(block_type)
	if frames.size() <= 1:
		return

	var block_node_value: Variant = block_data.get("node", null)
	if block_node_value is Node and is_instance_valid(block_node_value):
		var block_node: Node = block_node_value
		var visual_node: Node = block_node.get_node_or_null("Visual")
		if visual_node is Sprite2D:
			var visual: Sprite2D = visual_node
			var visual_id := visual.get_instance_id()
			if animated_block_visuals.has(visual_id):
				var existing_animation = animated_block_visuals[visual_id]
				if existing_animation is Dictionary and str(existing_animation.get("block_type", "")) == block_type:
					return
			clear_block_animation(block_node, visual)
			visual.visible = true
			visual.set_meta("animation_frames", frames)
			visual.set_meta("animation_frame_index", -1)
			var frame_seconds := get_oil_refinery_running_frame_seconds(block_type)
			animated_block_visuals[visual.get_instance_id()] = {
				"visual": visual,
				"frames": frames,
				"frame_seconds": frame_seconds,
				"block_type": block_type
			}
			apply_synced_block_animation_frame(visual, frames, frame_seconds, true, block_type)
			return

	start_tilemap_oil_refinery_running_animation(grid_pos, block_type)


func start_tilemap_oil_refinery_running_animation(grid_pos: Vector2i, block_type: String) -> void:
	var frames := get_oil_refinery_running_animation_frames(block_type)
	if frames.size() <= 1:
		tilemap_foreground_animated_cells.erase(grid_pos)
		return
	var existing_value: Variant = tilemap_foreground_animated_cells.get(grid_pos, {})
	if existing_value is Dictionary:
		var existing: Dictionary = existing_value
		if str(existing.get("block_type", "")) == block_type and is_oil_refinery_animation_block_type(str(existing.get("visual_block_type", block_type))):
			return

	tilemap_foreground_animated_cells[grid_pos] = {
		"block_type": block_type,
		"visual_block_type": block_type,
		"frames": frames,
		"frame_seconds": get_oil_refinery_running_frame_seconds(block_type),
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false),
		"water_cell": false
	}
	apply_tilemap_foreground_animation_frame(grid_pos, true)


func stop_oil_refinery_running_animation(grid_pos: Vector2i, block_type: String, block_data: Dictionary = {}) -> void:
	var entry_value: Variant = tilemap_foreground_animated_cells.get(grid_pos, {})
	if entry_value is Dictionary and is_oil_refinery_animation_block_type(str((entry_value as Dictionary).get("block_type", ""))):
		tilemap_foreground_animated_cells.erase(grid_pos)
	clear_animation_loop_particle_emitters_for_grid(grid_pos)

	var idle_texture := get_oil_refinery_idle_texture(block_type)
	var block_node_value: Variant = block_data.get("node", null)
	if block_node_value is Node and is_instance_valid(block_node_value):
		var block_node: Node = block_node_value
		var visual_node: Node = block_node.get_node_or_null("Visual")
		if visual_node is Sprite2D:
			var visual: Sprite2D = visual_node
			clear_block_animation(block_node, visual)
			if idle_texture != null:
				visual.texture = idle_texture
			visual.visible = true
			sync_block_texture_shadow_to_visual(visual)
			sync_tilemap_visual_for_block(block_node, grid_pos, block_type, block_type, false, visual)
			return

	if idle_texture != null:
		var renderer = ensure_tilemap_renderer()
		if renderer != null and renderer.has_method("set_block_cell"):
			renderer.set_block_cell(grid_pos, idle_texture, false, should_block_cast_texture_shadow(block_type, false))
			return
	sync_tilemap_only_foreground_block(grid_pos, block_type)


func get_springboard_animation_frames(block_type: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return result
	if springboard_frame_cache.has(clean_type):
		return springboard_frame_cache[clean_type]
	if world == null or not world.item_database.has(clean_type):
		springboard_frame_cache[clean_type] = result
		return result

	var item_data = world.item_database[clean_type]
	var frame_paths = item_data.get("springboard_animation_frames", [])
	if not (frame_paths is Array):
		springboard_frame_cache[clean_type] = result
		return result

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			result.append(texture)

	springboard_frame_cache[clean_type] = result
	return result


func get_springboard_animation_atlas_frames(block_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or world == null or not world.item_database.has(clean_type):
		return result

	var item_data = world.item_database[clean_type]
	var raw_frames = item_data.get("springboard_animation_atlas_frames", [])
	if not (raw_frames is Array):
		return result

	for raw_frame in raw_frames:
		result.append(parse_block_vector2i(raw_frame, Vector2i.ZERO))

	return result


func sync_springboard_atlas_visual_cell(grid_pos: Vector2i, block_type: String, atlas_coords: Vector2i) -> bool:
	if world == null or grid_pos == NO_VARIANT_GRID_POS:
		return false

	var renderer = ensure_tilemap_renderer()
	if renderer == null or not renderer.has_method("set_block_atlas_cell"):
		return false

	var synced: bool = bool(renderer.set_block_atlas_cell(grid_pos, atlas_coords, false, should_block_cast_texture_shadow(block_type, false), "springboard_state"))
	if not synced:
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if block_data is Dictionary:
		var block_node = block_data.get("node", null)
		if block_node != null and is_instance_valid(block_node):
			var visual = block_node.get_node_or_null("Visual")
			if visual is Sprite2D:
				(visual as Sprite2D).visible = false
			block_node.set_meta("tilemap_visual", true)
			remove_block_texture_shadow(block_node)
	return true


func play_springboard_block_animation(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	var block_type = str(block_data.get("type", ""))
	if not is_triggered_springboard_animation_block(block_type):
		return

	spawn_springboard_water_splash_if_needed(grid_pos, block_type)

	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		if bool(block_data.get("tilemap_only", false)):
			play_tilemap_springboard_animation(grid_pos, block_type)
		return

	var visual = block_node.get_node_or_null("Visual")
	if visual == null:
		return

	var frames = get_springboard_animation_frames(block_type)
	var atlas_frames := get_springboard_animation_atlas_frames(block_type)
	if frames.size() <= 1 and atlas_frames.size() <= 1:
		return

	var item_data = world.item_database[block_type]
	var frame_seconds = max(0.03, float(item_data.get("springboard_animation_frame_seconds", 0.18)))
	springboard_active_visuals[visual.get_instance_id()] = {
		"grid_pos": grid_pos,
		"block_type": block_type,
		"visual": visual,
		"frames": frames,
		"atlas_frames": atlas_frames,
		"frame_seconds": frame_seconds,
		"elapsed": 0.0,
		"frame_index": -1,
		"tilemap_visual": block_node.has_meta("tilemap_visual")
	}
	apply_springboard_animation_frame(visual, frames, 0, grid_pos, block_type, block_node.has_meta("tilemap_visual"), atlas_frames)


func spawn_springboard_water_splash_if_needed(grid_pos: Vector2i, block_type: String) -> void:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or world == null or not world.item_database.has(clean_type):
		return

	var item_data = world.item_database[clean_type]
	if not bool(item_data.get("springboard_water_splash", false)):
		return
	if not world.has_method("spawn_player_water_splash_particles"):
		return

	var now_msec := Time.get_ticks_msec()
	var splash_key := "%d,%d" % [grid_pos.x, grid_pos.y]
	var last_emit_msec := int(springboard_water_splash_last_emit_msec.get(splash_key, -SPRINGBOARD_WATER_SPLASH_DEDUPE_MS))
	if now_msec - last_emit_msec < SPRINGBOARD_WATER_SPLASH_DEDUPE_MS:
		return

	springboard_water_splash_last_emit_msec[splash_key] = now_msec
	var block_center_position := get_block_sound_position(grid_pos)
	var block_size := 32.0
	var world_block_size = world.get("BLOCK_SIZE")
	if world_block_size is int or world_block_size is float:
		block_size = float(world_block_size)
	var splash_body_position := block_center_position - Vector2(0.0, block_size * SPRINGBOARD_WATER_SPLASH_BODY_OFFSET_RATIO)
	var splash_surface_y := block_center_position.y + block_size * SPRINGBOARD_WATER_SPLASH_SURFACE_OFFSET_RATIO
	var splash_half_extents := Vector2(
		block_size * SPRINGBOARD_WATER_SPLASH_HALF_WIDTH_RATIO,
		block_size * 0.5
	)
	world.spawn_player_water_splash_particles(
		splash_body_position,
		splash_half_extents,
		splash_surface_y,
		SPRINGBOARD_WATER_SPLASH_INTENSITY
	)


func play_tilemap_springboard_animation(grid_pos: Vector2i, block_type: String) -> void:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "" or world == null or not world.item_database.has(clean_type):
		return

	var frames = get_springboard_animation_frames(clean_type)
	var atlas_frames := get_springboard_animation_atlas_frames(clean_type)
	if frames.size() <= 1 and atlas_frames.size() <= 1:
		return

	var item_data = world.item_database[clean_type]
	var frame_seconds = max(0.03, float(item_data.get("springboard_animation_frame_seconds", 0.18)))
	tilemap_springboard_active_cells[grid_pos] = {
		"block_type": clean_type,
		"frames": frames,
		"atlas_frames": atlas_frames,
		"frame_seconds": frame_seconds,
		"elapsed": 0.0,
		"frame_index": -1,
		"texture_shadow": should_block_cast_texture_shadow(block_type, false)
	}
	apply_tilemap_springboard_animation_frame(grid_pos, 0)


func update_tilemap_springboard_animations(delta: float) -> void:
	if tilemap_springboard_active_cells.is_empty():
		return
	if world == null:
		tilemap_springboard_active_cells.clear()
		return

	for grid_pos in tilemap_springboard_active_cells.keys():
		if not (grid_pos is Vector2i) or not world.blocks.has(grid_pos):
			tilemap_springboard_active_cells.erase(grid_pos)
			continue

		var entry_value: Variant = tilemap_springboard_active_cells.get(grid_pos, {})
		if not (entry_value is Dictionary):
			tilemap_springboard_active_cells.erase(grid_pos)
			continue
		var entry: Dictionary = entry_value

		var frames_value = entry.get("frames", [])
		var atlas_frames_value = entry.get("atlas_frames", [])
		var frame_count: int = 0
		if atlas_frames_value is Array and atlas_frames_value.size() > 1:
			frame_count = atlas_frames_value.size()
		elif frames_value is Array and frames_value.size() > 1:
			frame_count = frames_value.size()

		if frame_count <= 1:
			tilemap_springboard_active_cells.erase(grid_pos)
			continue

		var elapsed = float(entry.get("elapsed", 0.0)) + delta
		var frame_seconds = max(0.03, float(entry.get("frame_seconds", 0.18)))
		var frame_index = int(floor(elapsed / frame_seconds))

		if frame_index >= frame_count:
			apply_tilemap_springboard_animation_frame(grid_pos, 0)
			tilemap_springboard_active_cells.erase(grid_pos)
			continue

		entry["elapsed"] = elapsed
		tilemap_springboard_active_cells[grid_pos] = entry
		apply_tilemap_springboard_animation_frame(grid_pos, frame_index)


func apply_tilemap_springboard_animation_frame(grid_pos: Vector2i, frame_index: int) -> void:
	var entry_value: Variant = tilemap_springboard_active_cells.get(grid_pos, {})
	if not (entry_value is Dictionary):
		return
	var entry: Dictionary = entry_value

	var frames_value = entry.get("frames", [])
	var atlas_frames_value = entry.get("atlas_frames", [])
	var has_atlas_frames: bool = atlas_frames_value is Array and not atlas_frames_value.is_empty()
	if not has_atlas_frames and (not (frames_value is Array) or frames_value.size() == 0):
		tilemap_springboard_active_cells.erase(grid_pos)
		return

	var frame_count: int = int(atlas_frames_value.size() if has_atlas_frames else frames_value.size())
	var safe_index: int = int(clamp(frame_index, 0, frame_count - 1))
	if int(entry.get("frame_index", -1)) == safe_index:
		return

	var block_type := str(entry.get("block_type", ""))
	if has_atlas_frames:
		var atlas_coords := parse_block_vector2i(atlas_frames_value[safe_index], Vector2i.ZERO)
		if sync_springboard_atlas_visual_cell(grid_pos, block_type, atlas_coords):
			entry["frame_index"] = safe_index
			tilemap_springboard_active_cells[grid_pos] = entry
		return

	var texture_value: Variant = frames_value[safe_index]
	if not (texture_value is Texture2D):
		tilemap_springboard_active_cells.erase(grid_pos)
		return

	var renderer = ensure_tilemap_renderer()
	if renderer == null or not renderer.has_method("set_block_cell"):
		return

	if renderer.set_block_cell(grid_pos, texture_value as Texture2D, false, should_block_cast_texture_shadow(block_type, false)):
		entry["frame_index"] = safe_index
		tilemap_springboard_active_cells[grid_pos] = entry


func update_springboard_animations(delta):
	for visual_id in springboard_active_visuals.keys():
		var entry = springboard_active_visuals[visual_id]
		var visual = entry.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			springboard_active_visuals.erase(visual_id)
			continue

		var frames = entry.get("frames", [])
		var atlas_frames = entry.get("atlas_frames", [])
		var frame_count: int = 0
		if atlas_frames is Array and atlas_frames.size() > 1:
			frame_count = atlas_frames.size()
		elif frames is Array and frames.size() > 1:
			frame_count = frames.size()

		if frame_count <= 1:
			springboard_active_visuals.erase(visual_id)
			continue

		var elapsed = float(entry.get("elapsed", 0.0)) + delta
		var frame_seconds = max(0.03, float(entry.get("frame_seconds", 0.18)))
		var frame_index = int(floor(elapsed / frame_seconds))
		var grid_pos: Vector2i = entry.get("grid_pos", NO_VARIANT_GRID_POS)
		var block_type := str(entry.get("block_type", ""))
		var use_tilemap_visual := bool(entry.get("tilemap_visual", false))

		if frame_index >= frame_count:
			apply_springboard_animation_frame(visual, frames, 0, grid_pos, block_type, use_tilemap_visual, atlas_frames)
			springboard_active_visuals.erase(visual_id)
			continue

		entry["elapsed"] = elapsed
		springboard_active_visuals[visual_id] = entry
		apply_springboard_animation_frame(visual, frames, frame_index, grid_pos, block_type, use_tilemap_visual, atlas_frames)


func apply_springboard_animation_frame(visual: Sprite2D, frames: Array, frame_index: int, grid_pos: Vector2i = NO_VARIANT_GRID_POS, block_type: String = "", use_tilemap_visual := false, atlas_frames: Array = []):
	if visual == null or (frames.size() == 0 and atlas_frames.size() == 0):
		return

	var has_atlas_frames: bool = use_tilemap_visual and not atlas_frames.is_empty()
	var frame_count: int = int(atlas_frames.size() if has_atlas_frames else frames.size())
	var safe_index: int = int(clamp(frame_index, 0, frame_count - 1))
	if int(visual.get_meta("springboard_animation_frame_index", -1)) == safe_index:
		return

	visual.set_meta("springboard_animation_frame_index", safe_index)
	if has_atlas_frames and grid_pos != NO_VARIANT_GRID_POS:
		sync_springboard_atlas_visual_cell(grid_pos, block_type, parse_block_vector2i(atlas_frames[safe_index], Vector2i.ZERO))
		return

	visual.texture = frames[safe_index]
	sync_block_texture_shadow_to_visual(visual)
	if use_tilemap_visual and grid_pos != NO_VARIANT_GRID_POS:
		var block_node = visual.get_parent()
		if block_node != null and is_instance_valid(block_node) and block_node.has_meta("tilemap_visual"):
			sync_tilemap_visual_for_block(block_node, grid_pos, block_type, block_type, false, visual)


func get_dice_roll_frames(block_type: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return result
	if dice_frame_cache.has(clean_type):
		return dice_frame_cache[clean_type]
	if world == null or not world.item_database.has(clean_type):
		dice_frame_cache[clean_type] = result
		return result

	var item_data = world.item_database[clean_type]
	var frame_paths = item_data.get("dice_face_textures", [])
	if not (frame_paths is Array):
		dice_frame_cache[clean_type] = result
		return result

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			result.append(texture)

	dice_frame_cache[clean_type] = result
	return result


func play_dice_roll_animation(grid_pos: Vector2i, final_face: int = 1, roll_id: String = ""):
	clear_dice_roll_pending(grid_pos)
	mark_dice_roll_break_window(grid_pos)
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	if not (block_data is Dictionary):
		return
	var block_type = str(block_data.get("type", ""))
	if not is_dice_block_type(block_type):
		return

	var frames: Array[Texture2D] = get_dice_roll_frames(block_type)
	if frames.is_empty():
		update_dice_visual(grid_pos)
		return

	var item_data = world.item_database.get(block_type, {})
	var frame_seconds: float = maxf(0.03, float(item_data.get("dice_roll_frame_seconds", 0.06)))
	var duration_seconds: float = maxf(frame_seconds, float(item_data.get("dice_roll_duration_seconds", 0.9)))
	var seed_text: String = roll_id.strip_edges()
	if seed_text == "":
		seed_text = str(Time.get_ticks_msec()) + "|" + str(grid_pos)
	var start_offset: int = abs(int(seed_text.hash())) % frames.size()

	dice_active_rolls[grid_pos] = {
		"block_type": block_type,
		"frames": frames,
		"final_face": clampi(final_face, 1, 6),
		"frame_seconds": frame_seconds,
		"duration": duration_seconds,
		"elapsed": 0.0,
		"frame_index": -1,
		"start_offset": start_offset
	}
	apply_dice_roll_animation_frame(grid_pos, true)


func update_dice_roll_animations(delta: float):
	if dice_active_rolls.is_empty():
		return

	for grid_pos in dice_active_rolls.keys():
		if not (grid_pos is Vector2i) or world == null or not world.blocks.has(grid_pos):
			dice_active_rolls.erase(grid_pos)
			continue

		var entry_value: Variant = dice_active_rolls.get(grid_pos, {})
		if not (entry_value is Dictionary):
			dice_active_rolls.erase(grid_pos)
			continue

		var entry: Dictionary = entry_value
		entry["elapsed"] = float(entry.get("elapsed", 0.0)) + delta
		dice_active_rolls[grid_pos] = entry
		apply_dice_roll_animation_frame(grid_pos)


func apply_dice_roll_animation_frame(grid_pos: Vector2i, force_update: bool = false):
	var entry_value: Variant = dice_active_rolls.get(grid_pos, {})
	if not (entry_value is Dictionary):
		dice_active_rolls.erase(grid_pos)
		return
	var entry: Dictionary = entry_value

	var block_type: String = str(entry.get("block_type", ""))
	var frames_value: Variant = entry.get("frames", [])
	if block_type == "" or not (frames_value is Array) or frames_value.is_empty():
		dice_active_rolls.erase(grid_pos)
		update_dice_visual(grid_pos)
		return
	var frames: Array = frames_value

	var elapsed: float = float(entry.get("elapsed", 0.0))
	var duration: float = maxf(0.03, float(entry.get("duration", 0.9)))
	if elapsed >= duration:
		var final_face: int = clampi(int(entry.get("final_face", 1)), 1, 6)
		var final_index: int = clampi(final_face - 1, 0, frames.size() - 1)
		var final_texture: Variant = frames[final_index]
		if final_texture is Texture2D:
			apply_dice_texture_frame(grid_pos, block_type, final_texture as Texture2D)
		dice_active_rolls.erase(grid_pos)
		return

	var frame_seconds: float = maxf(0.03, float(entry.get("frame_seconds", 0.06)))
	var start_offset: int = int(entry.get("start_offset", 0))
	var frame_index: int = (int(floor(elapsed / frame_seconds)) + start_offset) % frames.size()
	if not force_update and int(entry.get("frame_index", -1)) == frame_index:
		return

	var texture_value: Variant = frames[frame_index]
	if not (texture_value is Texture2D):
		dice_active_rolls.erase(grid_pos)
		update_dice_visual(grid_pos)
		return

	entry["frame_index"] = frame_index
	dice_active_rolls[grid_pos] = entry
	apply_dice_texture_frame(grid_pos, block_type, texture_value as Texture2D)


func apply_dice_texture_frame(grid_pos: Vector2i, block_type: String, texture: Texture2D):
	if texture == null or world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return

	var block_node = block_data.get("node", null)
	if block_node != null and is_instance_valid(block_node):
		var visual = block_node.get_node_or_null("Visual")
		if visual is Sprite2D:
			(visual as Sprite2D).texture = texture
			sync_block_texture_shadow_to_visual(visual as Sprite2D)
			sync_tilemap_visual_for_block(block_node, grid_pos, block_type, block_type, false, visual as Sprite2D)
		return

	var renderer = ensure_tilemap_renderer()
	if renderer != null:
		var metadata := get_block_tilemap_metadata(block_type, block_type, grid_pos, false)
		if sync_renderer_block_visual_cell(renderer, grid_pos, texture, metadata, false, should_block_cast_texture_shadow(block_type, false)):
			return
		if renderer.has_method("set_block_cell"):
			renderer.set_block_cell(grid_pos, texture, false, should_block_cast_texture_shadow(block_type, false))


func setup_block_animation(block, block_type: String, visual: Sprite2D):
	clear_block_animation(block, visual)

	if world == null or not world.item_database.has(block_type):
		return

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("animation_frames", [])
	if not (frame_paths is Array) or frame_paths.size() <= 1:
		return

	var frames: Array[Texture2D] = []
	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			frames.append(texture)

	if frames.size() <= 1:
		return

	visual.set_meta("animation_frames", frames)
	visual.set_meta("animation_frame_index", -1)

	var frame_seconds = max(0.03, float(item_data.get("animation_frame_seconds", 0.45)))
	animated_block_visuals[visual.get_instance_id()] = {
		"visual": visual,
		"frames": frames,
		"frame_seconds": frame_seconds,
		"block_type": block_type
	}
	apply_synced_block_animation_frame(visual, frames, frame_seconds, true, block_type)


func get_server_triggered_animation_frames(block_type: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if world == null or not world.item_database.has(block_type):
		return result

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("animation_frames", [])
	if not (frame_paths is Array):
		return result

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(str(frame_path))
		if texture != null:
			result.append(texture)

	return result


func play_server_triggered_block_animation(grid_pos: Vector2i, block_type: String = ""):
	if world == null or not world.blocks.has(grid_pos):
		return

	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		clean_type = str(world.blocks[grid_pos].get("type", "")).strip_edges().to_lower()
	if not is_server_triggered_animation_block(clean_type):
		return

	var frames := get_server_triggered_animation_frames(clean_type)
	if frames.size() <= 1:
		return

	var token: int = Time.get_ticks_msec()
	server_triggered_animation_tokens[grid_pos] = token
	var frame_seconds: float = maxf(0.03, float(world.item_database[clean_type].get("animation_frame_seconds", 0.18)))
	var block_data = world.blocks.get(grid_pos, {})
	var block_node = block_data.get("node", null) if block_data is Dictionary else null
	var visual: Sprite2D = null
	if block_node is Node and is_instance_valid(block_node):
		visual = block_node.get_node_or_null("Visual")

	for frame in frames:
		if not world.blocks.has(grid_pos):
			return
		if int(server_triggered_animation_tokens.get(grid_pos, -1)) != token:
			return
		if visual != null and is_instance_valid(visual):
			visual.texture = frame
			sync_block_texture_shadow_to_visual(visual)
			sync_tilemap_visual_for_block(block_node, grid_pos, clean_type, clean_type, false, visual)
		else:
			var renderer = ensure_tilemap_renderer()
			if renderer != null and renderer.has_method("set_block_cell"):
				renderer.set_block_cell(grid_pos, frame, false, should_block_cast_texture_shadow(clean_type, false))
		await get_tree().create_timer(frame_seconds).timeout

	if int(server_triggered_animation_tokens.get(grid_pos, -1)) != token:
		return
	server_triggered_animation_tokens.erase(grid_pos)
	if world.blocks.has(grid_pos):
		normalize_block_variant_at(grid_pos, false)


func update_synced_block_animations():
	for visual_id in animated_block_visuals.keys():
		var entry = animated_block_visuals[visual_id]
		var visual = entry.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			animated_block_visuals.erase(visual_id)
			continue

		var frames = entry.get("frames", [])
		if not (frames is Array) or frames.size() <= 1:
			animated_block_visuals.erase(visual_id)
			continue

		apply_synced_block_animation_frame(visual, frames, float(entry.get("frame_seconds", 0.45)), false, str(entry.get("block_type", "")))


func apply_synced_block_animation_frame(visual: Sprite2D, frames: Array, frame_seconds: float, force_update: bool = false, block_type: String = ""):
	if visual == null or frames.size() <= 1:
		return

	var frame_msec = max(1, int(round(max(0.03, frame_seconds) * 1000.0)))
	var synced_index = int(floor(float(Time.get_ticks_msec()) / float(frame_msec))) % frames.size()
	var previous_index := int(visual.get_meta("animation_frame_index", -1))
	if not force_update and previous_index == synced_index:
		return

	visual.set_meta("animation_frame_index", synced_index)
	visual.texture = frames[synced_index]
	sync_block_texture_shadow_to_visual(visual)
	sync_tilemap_visual_animation_frame(visual)
	emit_block_animation_loop_particle(visual, block_type, previous_index, synced_index, force_update)


func emit_block_animation_loop_particle(visual: Sprite2D, block_type: String, previous_index: int, synced_index: int, force_update: bool = false):
	if force_update or previous_index < 0 or previous_index == synced_index:
		return
	if visual == null or world == null:
		return

	var block_node = visual.get_parent()
	if block_node == null or not is_instance_valid(block_node):
		return

	var grid_pos := get_grid_pos_for_block_node(block_node)
	if grid_pos == NO_VARIANT_GRID_POS:
		return

	emit_block_animation_loop_particle_at_grid(grid_pos, block_type, previous_index, synced_index, force_update)


func make_animation_loop_particle_key(grid_pos: Vector2i, particle_type: String) -> String:
	return str(grid_pos.x) + "," + str(grid_pos.y) + "|" + particle_type


func clear_animation_loop_particle_emitters_for_grid(grid_pos: Vector2i) -> void:
	var key_prefix := str(grid_pos.x) + "," + str(grid_pos.y) + "|"
	for particle_key in animation_loop_particle_last_emit_msec.keys():
		if str(particle_key).begins_with(key_prefix):
			animation_loop_particle_last_emit_msec.erase(particle_key)


func emit_block_animation_loop_particle_at_grid(grid_pos: Vector2i, block_type: String, previous_index: int, synced_index: int, force_update: bool = false):
	if force_update or previous_index < 0 or previous_index == synced_index:
		return
	if world == null or not world.item_database.has(block_type):
		return

	var item_data = world.item_database[block_type]
	var particle_type := str(item_data.get("animation_loop_particle", "")).strip_edges().to_lower()
	if particle_type != "oil_refinery_smoke":
		return
	var target_frame_index := clampi(int(item_data.get("animation_loop_particle_frame_index", 1)), 0, 1024)
	if synced_index != target_frame_index:
		return
	var min_interval_msec := maxi(0, int(item_data.get("animation_loop_particle_min_interval_ms", 0)))
	if min_interval_msec > 0:
		var particle_key := make_animation_loop_particle_key(grid_pos, particle_type)
		var now_msec := Time.get_ticks_msec()
		var last_msec := int(animation_loop_particle_last_emit_msec.get(particle_key, -1000000000))
		if now_msec - last_msec < min_interval_msec:
			return
		animation_loop_particle_last_emit_msec[particle_key] = now_msec

	var smoke_offset := parse_block_vector2(item_data.get("animation_loop_particle_offset", Vector2(-9.0, -9.0)), Vector2(-9.0, -9.0))
	var smoke_position := get_block_sound_position(grid_pos) + smoke_offset
	var smoke_count := clampi(int(item_data.get("animation_loop_particle_count", 5)), 1, 12)
	var smoke_texture_path := str(item_data.get("animation_loop_particle_texture", "")).strip_edges()

	if world.has_method("spawn_oil_refinery_smoke_particles"):
		world.spawn_oil_refinery_smoke_particles(smoke_position, smoke_count, smoke_texture_path)


func sync_tilemap_visual_animation_frame(visual: Sprite2D) -> void:
	if visual == null:
		return

	var block_node = visual.get_parent()
	if block_node == null or not is_instance_valid(block_node) or not block_node.has_meta("tilemap_visual"):
		return
	if world == null:
		return

	var grid_pos := get_grid_pos_for_block_node(block_node)
	if grid_pos == NO_VARIANT_GRID_POS or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return

	var block_type := str(block_data.get("type", ""))
	if block_type == "":
		return

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	sync_tilemap_visual_for_block(block_node, grid_pos, block_type, visual_block_type, false, visual)


func get_toggle_block_texture(block_type: String, toggle_on: bool) -> Texture2D:
	var item_data = get_block_item_data(block_type)
	var toggle_textures = item_data.get("toggle_textures", {})
	if not (toggle_textures is Dictionary):
		return null

	var texture_path = str(toggle_textures.get("on" if toggle_on else "off", ""))
	if texture_path == "":
		return null

	return AtlasTextureFactory.load_texture(texture_path)


func update_toggle_block_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_toggle_block_type(block_type):
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual = block_node.get_node_or_null("Visual")
	if visual == null:
		return

	var state_key = str(get_block_item_data(block_type).get("toggle_state_key", "toggle_on"))
	var texture = get_toggle_block_texture(block_type, bool(world.blocks[grid_pos].get(state_key, false)))
	if texture != null:
		visual.texture = texture
		sync_block_texture_shadow_to_visual(visual)
		if visual is Sprite2D:
			sync_tilemap_visual_for_block(block_node, grid_pos, block_type, block_type, false, visual as Sprite2D)

	update_block_light_fx(grid_pos)


func update_block_light_fx(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	if not (block_data is Dictionary):
		return

	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var block_type := str(block_data.get("type", "")).strip_edges()
	var item_data := get_block_item_data(block_type)
	var scene_path := str(item_data.get("light_fx_scene", "")).strip_edges()
	var should_show := scene_path != ""

	if should_show and bool(item_data.get("light_fx_when_on", false)):
		var state_key := str(item_data.get("toggle_state_key", "toggle_on"))
		should_show = bool(block_data.get(state_key, false))

	var existing = block_node.get_node_or_null(BLOCK_LIGHT_FX_NODE_NAME)
	if not should_show:
		if existing != null and is_instance_valid(existing):
			block_node.remove_child(existing)
			existing.queue_free()
		return

	if existing != null and is_instance_valid(existing):
		if existing.has_method("start"):
			existing.start()
		return

	var scene := get_block_light_fx_scene(scene_path)
	if scene == null:
		return

	var effect = scene.instantiate()
	if effect == null:
		return

	effect.name = BLOCK_LIGHT_FX_NODE_NAME
	var effect_offset := parse_block_vector2(item_data.get("light_fx_offset", Vector2.ZERO), Vector2.ZERO)
	if effect is Node2D:
		var effect_node_2d := effect as Node2D
		effect_node_2d.position = effect_offset
	elif effect is Control:
		var effect_control := effect as Control
		effect_control.position = effect_offset
	if effect is CanvasItem:
		var effect_item := effect as CanvasItem
		effect_item.z_as_relative = false

	effect.set("preview_emitting", true)
	effect.set("show_fixture", bool(item_data.get("light_fx_show_fixture", true)))

	block_node.add_child(effect)
	if effect.has_method("start"):
		effect.start()


func get_block_light_fx_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null

	if block_light_fx_scene_cache.has(scene_path):
		var cached = block_light_fx_scene_cache[scene_path]
		if cached is PackedScene:
			return cached

	if not ResourceLoader.exists(scene_path):
		return null

	var loaded_scene = load(scene_path)
	if loaded_scene is PackedScene:
		block_light_fx_scene_cache[scene_path] = loaded_scene
		return loaded_scene

	return null


func get_wooden_entrance_frames(block_type: String = "wooden_entrance") -> Array[Texture2D]:
	if wooden_entrance_frame_cache.has(block_type):
		var cached = wooden_entrance_frame_cache[block_type]
		var cached_frames: Array[Texture2D] = []
		if cached is Array:
			for texture in cached:
				if texture is Texture2D:
					cached_frames.append(texture)
		return cached_frames

	var item_data = {}
	if world != null and world.item_database.has(block_type):
		item_data = world.item_database[block_type]

	var frame_paths = item_data.get("entrance_frames", [
		"res://Assets/blocks/Tier_1/wooden/wooden_entrance_1.png",
		"res://Assets/blocks/Tier_1/wooden/wooden_entrance_2.png",
		"res://Assets/blocks/Tier_1/wooden/wooden_entrance_3.png"
	])

	var frames: Array[Texture2D] = []
	if frame_paths is Array:
		for frame_path in frame_paths:
			var texture = AtlasTextureFactory.load_texture(frame_path)
			if texture != null:
				frames.append(texture)

	wooden_entrance_frame_cache[block_type] = frames
	return frames


func get_wooden_entrance_frame_seconds(block_type: String) -> float:
	var item_data = get_block_item_data(block_type)
	return max(0.03, float(item_data.get("entrance_animation_frame_seconds", WOODEN_ENTRANCE_FRAME_SECONDS)))


func update_wooden_entrance_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual = block_node.get_node_or_null("Visual")
	if not (visual is Sprite2D):
		return
	var visual_sprite := visual as Sprite2D

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	var uses_pass_tilemap_animation := has_wooden_entrance_pass_tilemap_animation(block_type)
	visual_sprite.flip_h = false
	visual_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if uses_pass_tilemap_animation else Color(0.82, 0.88, 1.0, 1.0) if is_wooden_entrance_locked(grid_pos) else Color(1.0, 1.0, 1.0, 1.0)
	if uses_pass_tilemap_animation:
		var idle_atlas_coords := get_wooden_entrance_idle_atlas_coords(block_type)
		if not sync_wooden_entrance_atlas_visual_cell(grid_pos, block_type, idle_atlas_coords):
			sync_block_texture_shadow_to_visual(visual_sprite)
			sync_wooden_entrance_tilemap_visual(grid_pos, visual_sprite)
	else:
		var idle_texture_path := get_wooden_entrance_idle_texture_path(block_type)
		var idle_texture = AtlasTextureFactory.load_texture(idle_texture_path) if idle_texture_path != "" else null
		if idle_texture != null:
			visual_sprite.texture = idle_texture
		else:
			var frames = get_wooden_entrance_frames(block_type)
			if not frames.is_empty():
				visual_sprite.texture = frames[0]
		sync_block_texture_shadow_to_visual(visual_sprite)
		sync_wooden_entrance_tilemap_visual(grid_pos, visual_sprite)


func sync_wooden_entrance_atlas_visual_cell(grid_pos: Vector2i, block_type: String, atlas_coords: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var renderer = ensure_tilemap_renderer()
	if renderer == null:
		return false

	var metadata := get_block_tilemap_metadata(block_type, block_type, grid_pos, false)
	var synced := false
	if renderer.has_method("set_item_atlas_cell"):
		synced = bool(renderer.set_item_atlas_cell(
			grid_pos,
			int(metadata.get("source_id", 0)),
			atlas_coords,
			false,
			should_block_cast_texture_shadow(block_type, false),
			"entrance_state",
			int(metadata.get("alternative_tile", 0))
		))
	elif renderer.has_method("set_block_atlas_cell"):
		synced = bool(renderer.set_block_atlas_cell(grid_pos, atlas_coords, false, should_block_cast_texture_shadow(block_type, false), "entrance_state", int(metadata.get("alternative_tile", 0))))
	if not synced:
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if block_data is Dictionary:
		var block_node = block_data.get("node", null)
		if block_node != null and is_instance_valid(block_node):
			var visual = block_node.get_node_or_null("Visual")
			if visual is Sprite2D:
				(visual as Sprite2D).visible = false
			block_node.set_meta("tilemap_visual", true)
			remove_block_texture_shadow(block_node)
	return true


func sync_wooden_entrance_tilemap_visual(grid_pos: Vector2i, visual: Sprite2D) -> void:
	if world == null or visual == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return

	var block_type := str(block_data.get("type", ""))
	if not is_wooden_entrance_block_type(block_type):
		return

	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual_block_type := get_snow_storm_visual_block_type(block_type, grid_pos, false)
	sync_tilemap_visual_for_block(block_node, grid_pos, block_type, visual_block_type, false, visual)


func get_wooden_entrance_walk_direction(grid_pos: Vector2i, previous_grid_pos: Vector2i) -> int:
	if previous_grid_pos != NO_VARIANT_GRID_POS:
		if previous_grid_pos.x < grid_pos.x:
			return 1
		if previous_grid_pos.x > grid_pos.x:
			return -1

	if world != null and world.player != null and world.player is CharacterBody2D:
		if world.player.velocity.x < -1.0:
			return -1
		if world.player.velocity.x > 1.0:
			return 1

	if world != null and "player_facing_direction" in world:
		return -1 if int(world.player_facing_direction) < 0 else 1

	return 1


func should_emit_wooden_entrance_pass_effect(previous_grid_pos: Vector2i, grid_pos: Vector2i) -> bool:
	if previous_grid_pos == NO_VARIANT_GRID_POS or previous_grid_pos == grid_pos:
		return false

	var delta_x = abs(previous_grid_pos.x - grid_pos.x)
	var delta_y = abs(previous_grid_pos.y - grid_pos.y)
	return delta_x <= 1 and delta_y <= 1


func play_wooden_entrance_pass_sound(grid_pos: Vector2i, walk_direction: int = 1, send_network: bool = false):
	if world == null:
		return

	if world.has_method("play_sound_entrance"):
		world.play_sound_entrance(get_block_sound_position(grid_pos))

	if send_network and world.has_method("send_entrance_pass"):
		world.send_entrance_pass(grid_pos, walk_direction)


func play_wooden_entrance_pass_animation(grid_pos: Vector2i, walk_direction: int = 1):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	var uses_pass_tilemap_animation := has_wooden_entrance_pass_tilemap_animation(block_type)
	var atlas_frames := get_wooden_entrance_pass_atlas_frames(block_type)
	var frames: Array[Texture2D] = []
	if not uses_pass_tilemap_animation:
		frames = get_wooden_entrance_frames(block_type)
	if frames.size() <= 1 and not uses_pass_tilemap_animation and atlas_frames.is_empty():
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual = block_node.get_node_or_null("Visual")
	if not (visual is Sprite2D):
		return
	var visual_sprite := visual as Sprite2D

	var flip_h = walk_direction > 0 and not uses_pass_tilemap_animation
	visual_sprite.flip_h = flip_h
	if uses_pass_tilemap_animation:
		visual_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var first_atlas_frame := atlas_frames[0] if not atlas_frames.is_empty() else get_wooden_entrance_pass_atlas_coords(block_type)
		sync_wooden_entrance_atlas_visual_cell(grid_pos, block_type, first_atlas_frame)
		wooden_entrance_active_visuals[visual_sprite.get_instance_id()] = {
			"grid_pos": grid_pos,
			"visual": visual_sprite,
			"frames": frames,
			"block_type": block_type,
			"atlas_pass_frames": atlas_frames,
			"frame_seconds": get_wooden_entrance_frame_seconds(block_type),
			"duration": get_wooden_entrance_pass_animation_duration(block_type),
			"elapsed": 0.0,
			"frame_index": 0 if not atlas_frames.is_empty() else -1,
			"flip_h": flip_h,
			"tilemap_pass_animation": true
		}
		return

	sync_wooden_entrance_tilemap_visual(grid_pos, visual_sprite)
	wooden_entrance_active_visuals[visual_sprite.get_instance_id()] = {
		"grid_pos": grid_pos,
		"visual": visual_sprite,
		"frames": frames,
		"frame_seconds": get_wooden_entrance_frame_seconds(block_type),
		"elapsed": 0.0,
		"frame_index": -1,
		"flip_h": flip_h
	}


func reset_wooden_entrance_pass_animation(grid_pos: Vector2i):
	for visual_id in wooden_entrance_active_visuals.keys():
		var entry = wooden_entrance_active_visuals[visual_id]
		if entry.get("grid_pos", NO_VARIANT_GRID_POS) == grid_pos:
			wooden_entrance_active_visuals.erase(visual_id)

	update_wooden_entrance_visual(grid_pos)


func update_wooden_entrance_animations(delta: float):
	for visual_id in wooden_entrance_active_visuals.keys():
		var entry = wooden_entrance_active_visuals[visual_id]
		var visual = entry.get("visual", null)
		if visual == null or not is_instance_valid(visual) or not (visual is Sprite2D):
			wooden_entrance_active_visuals.erase(visual_id)
			continue
		var visual_sprite := visual as Sprite2D

		var elapsed = float(entry.get("elapsed", 0.0)) + delta
		var frame_seconds = max(0.03, float(entry.get("frame_seconds", WOODEN_ENTRANCE_FRAME_SECONDS)))
		var grid_pos: Vector2i = entry.get("grid_pos", NO_VARIANT_GRID_POS)
		if bool(entry.get("tilemap_pass_animation", false)):
			var atlas_frames_value = entry.get("atlas_pass_frames", [])
			if atlas_frames_value is Array and not atlas_frames_value.is_empty() and grid_pos != NO_VARIANT_GRID_POS:
				var atlas_frame_index := mini(int(floor(elapsed / frame_seconds)), atlas_frames_value.size() - 1)
				if atlas_frame_index != int(entry.get("frame_index", -1)):
					var entry_block_type := str(entry.get("block_type", ""))
					if entry_block_type == "" and world != null and world.blocks.has(grid_pos):
						entry_block_type = str(world.blocks[grid_pos].get("type", ""))
					var atlas_coords: Vector2i = parse_block_vector2i(atlas_frames_value[atlas_frame_index], Vector2i.ZERO)
					sync_wooden_entrance_atlas_visual_cell(grid_pos, entry_block_type, atlas_coords)
					entry["frame_index"] = atlas_frame_index
			var duration: float = maxf(0.03, float(entry.get("duration", frame_seconds)))
			if elapsed >= duration:
				wooden_entrance_active_visuals.erase(visual_id)
				if grid_pos != NO_VARIANT_GRID_POS:
					update_wooden_entrance_visual(grid_pos)
				continue
			entry["elapsed"] = elapsed
			wooden_entrance_active_visuals[visual_id] = entry
			continue

		var frames = entry.get("frames", [])
		if not (frames is Array) or frames.is_empty():
			wooden_entrance_active_visuals.erase(visual_id)
			continue

		var frame_index = int(floor(elapsed / frame_seconds))
		var should_sync_tilemap := false

		if frame_index >= frames.size():
			frame_index = frames.size() - 1
			elapsed = frame_seconds * float(frames.size())

		var flip_h = bool(entry.get("flip_h", false))
		if visual_sprite.flip_h != flip_h:
			visual_sprite.flip_h = flip_h
			sync_block_texture_shadow_to_visual(visual_sprite)
			should_sync_tilemap = true

		if frame_index != int(entry.get("frame_index", -1)) or visual_sprite.texture != frames[frame_index]:
			visual_sprite.texture = frames[frame_index]
			entry["frame_index"] = frame_index
			sync_block_texture_shadow_to_visual(visual_sprite)
			should_sync_tilemap = true

		if should_sync_tilemap and grid_pos != NO_VARIANT_GRID_POS:
			sync_wooden_entrance_tilemap_visual(grid_pos, visual_sprite)

		entry["elapsed"] = elapsed
		wooden_entrance_active_visuals[visual_id] = entry


func update_wooden_entrance_crossing():
	if world == null or world.player == null:
		if last_wooden_entrance_grid != NO_VARIANT_GRID_POS and is_wooden_entrance_at(last_wooden_entrance_grid):
			reset_wooden_entrance_pass_animation(last_wooden_entrance_grid)
		last_wooden_entrance_grid = NO_VARIANT_GRID_POS
		return

	var grid_pos = world.get_player_grid_position()
	if grid_pos == last_wooden_entrance_grid:
		return

	var previous_grid_pos = last_wooden_entrance_grid
	last_wooden_entrance_grid = grid_pos

	if previous_grid_pos != NO_VARIANT_GRID_POS and is_wooden_entrance_at(previous_grid_pos):
		reset_wooden_entrance_pass_animation(previous_grid_pos)

	if not is_wooden_entrance_at(grid_pos):
		return

	if not should_disable_wooden_entrance_collision(grid_pos):
		return

	var walk_direction = get_wooden_entrance_walk_direction(grid_pos, previous_grid_pos)
	play_wooden_entrance_pass_animation(grid_pos, walk_direction)
	if should_emit_wooden_entrance_pass_effect(previous_grid_pos, grid_pos):
		play_wooden_entrance_pass_sound(grid_pos, walk_direction, true)


func configure_block_collision(block, block_type: String, grid_pos: Vector2i = NO_VARIANT_GRID_POS):
	remove_wood_platform_collision(block)
	set_block_node_collision_fully_disabled(block, false)
	apply_original_collision_layout(block, block_type)
	if grid_pos == NO_VARIANT_GRID_POS:
		grid_pos = get_grid_pos_for_block_node(block)

	if is_platform_collision_block_type(block_type):
		set_original_block_collision_disabled(block, true)
		add_wood_platform_collision(block)
	elif is_wooden_entrance_block_type(block_type):
		set_original_block_collision_disabled(block, should_disable_wooden_entrance_collision(grid_pos))
	elif is_sign_block_type(block_type):
		set_block_node_collision_fully_disabled(block, true)
	elif is_background_block_type(block_type):
		set_block_node_collision_fully_disabled(block, true)
	elif is_non_collideable_block(block_type):
		set_block_node_collision_fully_disabled(block, true)
	else:
		set_original_block_collision_disabled(block, false)

	if world != null and grid_pos != NO_VARIANT_GRID_POS and world.blocks.has(grid_pos):
		var block_data_value: Variant = world.blocks.get(grid_pos, {})
		if block_data_value is Dictionary:
			sync_foreground_tilemap_collision_for_block(grid_pos, block_data_value)


func set_original_block_collision_disabled(node, disabled: bool):
	if node == null:
		return

	for child in node.get_children():
		if child.name.begins_with("WoodPlatform"):
			continue

		if child is CollisionShape2D:
			child.disabled = disabled

		set_original_block_collision_disabled(child, disabled)


func set_block_node_collision_fully_disabled(node, disabled: bool) -> void:
	if node == null:
		return

	if node is PhysicsBody2D:
		var physics_body := node as PhysicsBody2D
		if not physics_body.has_meta("original_collision_layer"):
			physics_body.set_meta("original_collision_layer", physics_body.collision_layer)
		if not physics_body.has_meta("original_collision_mask"):
			physics_body.set_meta("original_collision_mask", physics_body.collision_mask)
		if disabled:
			physics_body.collision_layer = 0
			physics_body.collision_mask = 0
		else:
			physics_body.collision_layer = int(physics_body.get_meta("original_collision_layer", physics_body.collision_layer))
			physics_body.collision_mask = int(physics_body.get_meta("original_collision_mask", physics_body.collision_mask))

	if node is CollisionShape2D:
		var collision_shape := node as CollisionShape2D
		if not collision_shape.has_meta("original_collision_disabled"):
			collision_shape.set_meta("original_collision_disabled", collision_shape.disabled)
		collision_shape.disabled = true if disabled else bool(collision_shape.get_meta("original_collision_disabled", false))

	for child in node.get_children():
		if child.name.begins_with("WoodPlatform"):
			continue
		set_block_node_collision_fully_disabled(child, disabled)


func remove_wood_platform_collision(node):
	if node == null:
		return

	for child in node.get_children():
		if child.name.begins_with("WoodPlatform"):
			child.queue_free()
		else:
			remove_wood_platform_collision(child)


func retire_block_node_for_removal(node) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is CollisionObject2D:
		var collision_object := node as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	for child in node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
		elif child is CollisionObject2D:
			var child_collision_object := child as CollisionObject2D
			child_collision_object.collision_layer = 0
			child_collision_object.collision_mask = 0

		retire_block_node_for_removal(child)


func spawn_block_break_effect(grid_pos: Vector2i, block_type: String) -> void:
	if world == null or not world.item_database.has(block_type):
		return

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("break_effect_frames", [])
	if not (frame_paths is Array) or frame_paths.is_empty():
		return

	var frames: Array[Texture2D] = []
	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			frames.append(texture)

	if frames.is_empty():
		return

	var visual = Sprite2D.new()
	visual.name = "BlockBreakEffect"
	visual.centered = true
	visual.z_as_relative = false
	visual.z_index = 4300
	visual.position = get_block_sound_position(grid_pos)
	visual.texture = frames[0]
	world.add_child(visual)

	animate_block_break_effect(visual, frames, max(0.04, float(item_data.get("break_effect_frame_seconds", 0.16))))


func animate_block_break_effect(visual: Sprite2D, frames: Array[Texture2D], frame_seconds: float) -> void:
	for frame in frames:
		if visual == null or not is_instance_valid(visual):
			return
		visual.texture = frame
		await world.get_tree().create_timer(frame_seconds).timeout

	if visual != null and is_instance_valid(visual):
		visual.queue_free()


func get_block_collision_body(node):
	if node == null:
		return null

	if node is CollisionObject2D:
		return node

	for child in node.get_children():
		var found = get_block_collision_body(child)

		if found != null:
			return found

	return null


func add_wood_platform_collision(block):
	var collision_body = get_block_collision_body(block)

	if collision_body == null:
		return

	var top_shape = RectangleShape2D.new()
	top_shape.size = Vector2(world.BLOCK_SIZE, 6)

	var top_collision = CollisionShape2D.new()
	top_collision.name = "WoodPlatformTopCollision"
	top_collision.shape = top_shape
	top_collision.position = Vector2(0, -13)
	top_collision.one_way_collision = true
	top_collision.one_way_collision_margin = 8.0
	collision_body.add_child(top_collision)


func get_mouse_punch_target_grid() -> Vector2i:
	if world == null:
		return Vector2i(-999999, -999999)

	if world.player == null:
		return world.INVALID_GRID_POS

	var clicked_seed_grid = world.get_clicked_planted_seed_grid()
	if clicked_seed_grid != world.INVALID_GRID_POS:
		if world.can_reach_grid(clicked_seed_grid):
			return clicked_seed_grid
		return world.INVALID_GRID_POS

	var grid_pos = world.get_mouse_grid_position()
	if not world.is_grid_inside_world(grid_pos):
		return world.INVALID_GRID_POS

	if not world.can_reach_grid(grid_pos):
		return world.INVALID_GRID_POS

	var anchor_grid_pos = get_anchor_grid_for_block_area(grid_pos)
	if anchor_grid_pos != world.INVALID_GRID_POS:
		return grid_pos

	if background_blocks.has(grid_pos):
		return grid_pos

	return world.INVALID_GRID_POS


func prepare_mouse_punch_facing() -> bool:
	if world == null:
		return false

	var target_grid_pos = get_mouse_punch_target_grid()
	if target_grid_pos != world.INVALID_GRID_POS:
		return face_grid_for_block_punch(target_grid_pos)

	return face_pointer_position_for_punch()


func is_water_bucket_selected() -> bool:
	if world == null:
		return false
	return str(world.get("selected_item_type")).strip_edges().to_lower() == WATER_BUCKET_ITEM_TYPE and str(world.get("selected_item_category")).strip_edges().to_lower() == "block"


func get_water_bucket_inventory_count() -> int:
	if world == null or not ("inventory" in world):
		return 0
	var count_value: Variant = world.inventory.get(WATER_BUCKET_ITEM_TYPE, 0)
	return maxi(0, int(count_value))


func refresh_water_bucket_inventory_ui() -> void:
	if world == null:
		return
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(WATER_BUCKET_ITEM_TYPE, "block")
	else:
		world.update_all_ui()


func adjust_water_bucket_inventory(delta: int) -> void:
	if world == null or not ("inventory" in world):
		return
	var next_count: int = maxi(0, get_water_bucket_inventory_count() + delta)
	world.inventory[WATER_BUCKET_ITEM_TYPE] = next_count
	refresh_water_bucket_inventory_ui()


func can_place_water_from_bucket_here(grid_pos: Vector2i) -> bool:
	if world.blocks.has(grid_pos):
		world.show_notification("Click existing water to collect it.")
		return false

	if world.has_planted_seed(grid_pos):
		world.show_notification("That spot is occupied.")
		return false

	if does_block_have_placement_collision(WATER_BLOCK_TYPE) and world.is_block_inside_player(grid_pos):
		world.show_notification("Move away before placing water.")
		return false

	var proposed_rect: Rect2 = get_block_collision_rect_for_grid(grid_pos, WATER_BLOCK_TYPE)
	if does_rect_overlap_reserved_object(proposed_rect):
		world.show_notification("Need enough empty space.")
		return false

	return true


func try_use_water_bucket_at_mouse() -> bool:
	if not is_water_bucket_selected():
		return false

	var grid_pos: Vector2i = world.get_mouse_grid_position()
	return try_use_water_bucket_at_grid(grid_pos)


func try_use_water_bucket_at_grid(grid_pos: Vector2i) -> bool:
	if not is_water_bucket_selected():
		return false

	if get_water_bucket_inventory_count() <= 0:
		world.show_notification("You don't have any Water Buckets.")
		return true

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return true

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return true

	var anchor_grid_pos: Vector2i = get_anchor_grid_for_block_area(grid_pos)
	if anchor_grid_pos != world.INVALID_GRID_POS:
		var block_data_value: Variant = world.blocks.get(anchor_grid_pos, {})
		if block_data_value is Dictionary:
			var block_data: Dictionary = block_data_value
			var block_type: String = str(block_data.get("type", ""))
			if block_type == WATER_BLOCK_TYPE:
				if world.has_method("can_current_player_break_block_at") and not world.can_current_player_break_block_at(WATER_BLOCK_TYPE, anchor_grid_pos):
					world.show_notification("This world is locked.")
					return true

				face_grid_for_block_punch(anchor_grid_pos)
				spawn_hand_item_swing_particles_at_grid(anchor_grid_pos, WATER_BUCKET_ITEM_TYPE)

				if should_use_server_authoritative_world_actions():
					var break_key: String = get_authoritative_break_key("foreground", anchor_grid_pos)
					if authoritative_break_request_keys.has(break_key):
						world.show_notification("Collecting water...")
						return true
					if send_network_block_update("break", "foreground", anchor_grid_pos, WATER_BLOCK_TYPE, {
						"source_tool": WATER_BUCKET_ITEM_TYPE,
						"water_bucket_action": "scoop"
					}):
						authoritative_break_request_keys[break_key] = true
						play_block_break_sound(anchor_grid_pos)
						world.show_notification("Collecting water...")
					else:
						world.show_notification("Almost ready. Try again in a moment.")
					return true

				spawn_block_break_particles(anchor_grid_pos, WATER_BLOCK_TYPE, "foreground")
				remove_block_without_drop(anchor_grid_pos)
				send_network_block_update("break", "foreground", anchor_grid_pos, WATER_BLOCK_TYPE, {
					"source_tool": WATER_BUCKET_ITEM_TYPE,
					"water_bucket_action": "scoop"
				})
				adjust_water_bucket_inventory(1)
				play_block_break_sound(anchor_grid_pos)
				world.show_notification("Collected water.")
				return true

		world.show_notification("Use Water Bucket on water or empty space.")
		return true

	if world.has_method("can_current_player_place_block_at") and not world.can_current_player_place_block_at(WATER_BLOCK_TYPE, grid_pos):
		world.show_notification("This world is locked.")
		return true

	if world.has_method("can_current_player_build_at") and not world.can_current_player_build_at(grid_pos):
		world.show_notification("This world is locked.")
		return true

	if not can_place_water_from_bucket_here(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)
	spawn_hand_item_swing_particles_at_grid(grid_pos, WATER_BUCKET_ITEM_TYPE)

	if should_use_server_authoritative_world_actions():
		var place_key: String = get_authoritative_place_key("foreground", grid_pos, WATER_BLOCK_TYPE)
		if has_recent_authoritative_place_request(place_key):
			world.show_notification("Placing water...")
			return true
		if send_network_block_update("place", "foreground", grid_pos, WATER_BLOCK_TYPE, {
			"source_tool": WATER_BUCKET_ITEM_TYPE,
			"water_bucket_action": "pour"
		}):
			mark_authoritative_place_request(place_key)
			world.show_notification("Placing water...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return true

	create_block(grid_pos, WATER_BLOCK_TYPE)
	send_network_block_update("place", "foreground", grid_pos, WATER_BLOCK_TYPE, {
		"source_tool": WATER_BUCKET_ITEM_TYPE,
		"water_bucket_action": "pour"
	})
	spawn_block_place_particles(grid_pos, WATER_BLOCK_TYPE, "foreground")
	adjust_water_bucket_inventory(-1)
	if world.has_method("play_sound_place"):
		world.play_sound_place(get_block_sound_position(grid_pos))
	world.show_notification("Placed water.")
	return true


func break_block_at_mouse():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_shop_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	if is_current_block_hit_punch_action():
		face_pointer_position_for_punch()

	if try_enter_door_under_player():
		return

	if is_water_bucket_selected():
		try_use_water_bucket_at_mouse()
		return

	var clicked_seed_grid = world.get_clicked_planted_seed_grid()

	if clicked_seed_grid != world.INVALID_GRID_POS:
		if not world.can_reach_grid(clicked_seed_grid):
			return

		if world.has_method("can_current_player_build_at") and not world.can_current_player_build_at(clicked_seed_grid):
			world.show_notification("This area is locked.")
			return

		if world.selected_item_category == "seed":
			world.try_splice_seed_tree(clicked_seed_grid)
			return

		face_grid_for_block_punch(clicked_seed_grid)
		spawn_hand_item_swing_particles_at_grid(clicked_seed_grid)
		world.harvest_planted_seed(clicked_seed_grid)
		return

	var grid_pos = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var anchor_grid_pos = get_anchor_grid_for_block_area(grid_pos)

	if anchor_grid_pos != world.INVALID_GRID_POS:
		face_grid_for_block_punch(grid_pos)
		hit_block_grid(anchor_grid_pos, is_current_block_hit_punch_action())
		return

	if background_blocks.has(grid_pos):
		face_grid_for_block_punch(grid_pos)
		hit_background_block_grid(grid_pos)
		return

	if world.has_method("try_break_electrical_tile_at") and bool(world.try_break_electrical_tile_at(grid_pos)):
		face_grid_for_block_punch(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		return

	if world.has_method("request_player_punch_at_screen_position"):
		var pointer_screen_pos: Vector2 = world.get_pointer_screen_position() if world.has_method("get_pointer_screen_position") else world.get_viewport().get_mouse_position()
		if world.request_player_punch_at_screen_position(pointer_screen_pos):
			return

	face_pointer_position_for_punch()
	spawn_hand_item_swing_particles_at_grid(grid_pos)


func update_block_damage_recovery(delta):
	var positions_to_reset = []

	for grid_pos in world.block_hit_timers.keys():
		if not world.blocks.has(grid_pos) and not background_blocks.has(grid_pos):
			positions_to_reset.append(grid_pos)
			continue

		var time_left = float(world.block_hit_timers.get(grid_pos, 0.0)) - delta
		world.block_hit_timers[grid_pos] = time_left

		if time_left <= 0.0:
			positions_to_reset.append(grid_pos)

	for grid_pos in positions_to_reset:
		world.block_hit_timers.erase(grid_pos)
		world.block_hit_progress.erase(grid_pos)
		authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
		authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
		update_block_crack_visual(grid_pos)
		update_background_block_crack_visual(grid_pos)


func hit_block_grid(grid_pos: Vector2i, force_punch_action: bool = false):
	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return

	if not world.blocks.has(grid_pos):
		return

	var block_type = world.blocks[grid_pos]["type"]
	var is_punch_action := force_punch_action or is_current_block_hit_punch_action()

	var is_state_toggle_machine := (
		is_anti_punch_block_type(str(block_type))
		or is_anti_talk_block_type(str(block_type))
		or is_anti_gravity_block_type(str(block_type))
		or is_theme_machine_block_type(str(block_type))
	)
	if is_punch_action and is_state_toggle_machine and world.has_method("try_punch_toggle_machine_at"):
		var toggle_succeeded := bool(world.try_punch_toggle_machine_at(grid_pos))
		spawn_hand_item_swing_particles_at_grid(grid_pos, "punch")
		if not toggle_succeeded:
			if not world.can_reach_grid(grid_pos):
				play_block_hit_sound(grid_pos)
				return
			if world.has_method("can_current_player_break_block_at") and not world.can_current_player_break_block_at(str(block_type), grid_pos):
				play_block_hit_sound(grid_pos)
				return

	if is_punch_action and is_direct_inventory_display_block_type(str(block_type)) and try_withdraw_display_item_at_grid(grid_pos):
		spawn_hand_item_swing_particles_at_grid(grid_pos, "punch")
		return

	if is_punch_action and is_fish_hanger_block_type(str(block_type)) and try_withdraw_fish_hanger_at_grid(grid_pos):
		spawn_hand_item_swing_particles_at_grid(grid_pos, "punch")
		return

	if str(block_type) == WATER_BLOCK_TYPE:
		if is_water_bucket_selected():
			try_use_water_bucket_at_grid(grid_pos)
		else:
			world.show_notification("Use a Water Bucket to collect water.")
		return

	if is_password_door_block_type(str(block_type)) and (force_punch_action or is_current_block_hit_punch_action()):
		if world.has_method("try_enter_door_at") and bool(world.try_enter_door_at(grid_pos, false)):
			return

	if is_dice_block_type(str(block_type)) and (force_punch_action or is_current_block_hit_punch_action()):
		if try_roll_dice_block(grid_pos):
			return

	if is_chicken_block_type(str(block_type)):
		if try_harvest_chicken(grid_pos):
			return

	if is_cow_block_type(str(block_type)):
		if try_harvest_cow(grid_pos):
			return

	if is_duck_block_type(str(block_type)):
		if try_harvest_duck(grid_pos):
			return

	if is_water_well_block_type(str(block_type)):
		if try_harvest_water_well(grid_pos):
			return

	if is_atm_machine_block_type(str(block_type)):
		if try_harvest_atm_machine(grid_pos):
			return

	if is_tackle_box_block_type(str(block_type)):
		if try_harvest_tackle_box(grid_pos):
			return

	if is_door_block_type(str(block_type)) and is_player_standing_on_grid(grid_pos):
		world.show_notification("Step off the door to break it.")
		return

	if world.has_method("can_current_player_break_block_at") and not world.can_current_player_break_block_at(str(block_type), grid_pos):
		if is_world_lock_block_type(str(block_type)):
			if world.world_lock_manager != null and world.world_lock_manager.has_method("has_world_lock_break_blockers") and world.world_lock_manager.has_world_lock_break_blockers():
				world.show_notification("Remove all Safes, vending machines, Fish Mongers, and displays before breaking the World Lock.")
			else:
				world.show_notification("Only the world owner can break the World Lock.")
		elif world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(str(block_type)):
			world.show_notification("Only the area lock owner can break this lock.")
		elif str(block_type) == "fish_monger":
			world.show_notification("Only the world owner or players with access can break the Fish Monger.")
		elif world.world_lock_manager != null and world.world_lock_manager.has_method("is_vending_machine_block") and world.world_lock_manager.is_vending_machine_block(str(block_type)):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can break vending machines.")
			else:
				world.show_notification("Lock this world before breaking vending machines.")
		elif world.world_lock_manager != null and world.world_lock_manager.has_method("is_safe_block") and world.world_lock_manager.is_safe_block(str(block_type)):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can break safes.")
			else:
				world.show_notification("Lock this world before breaking safes.")
		elif world.has_method("is_display_block_type") and world.is_display_block_type(str(block_type)):
			if world.world_lock_manager != null and world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can break displays.")
			else:
				world.show_notification("Lock this world before breaking displays.")
		else:
			world.show_notification("This world is locked.")
		return

	if block_type == "bedrock":
		world.show_notification("Bedrock cannot be broken.")
		return

	if world.is_entrance_gate_block(block_type):
		if world.can_use_entrance_gate():
			world.exit_world_from_entrance_gate()
		return

	if world.item_database.has(block_type) and bool(world.item_database[block_type].get("unbreakable", false)):
		world.show_notification(world.get_item_display_name(block_type, "block") + " cannot be broken.")
		return
	if not try_consume_block_break_input_cadence():
		return

	var max_hits = get_block_max_hits(block_type)
	var hit_power = world.get_current_break_power(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0)) + hit_power
	world.block_hit_progress[grid_pos] = current_hits
	world.block_hit_timers[grid_pos] = world.BLOCK_DAMAGE_RESET_DELAY

	if should_use_server_authoritative_world_actions():
		var action = "hit" if current_hits < max_hits else "break"
		var break_key = get_authoritative_break_key("foreground", grid_pos)
		if action == "break" and authoritative_break_request_keys.has(break_key):
			world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
			return
		if send_network_block_update(action, "foreground", grid_pos, str(block_type), {
			"hit_power": hit_power,
			"hit_count": current_hits,
			"max_hits": max_hits,
			"source_tool": get_current_block_hit_source_tool()
		}):
			if action == "break":
				authoritative_break_request_keys[break_key] = true
			spawn_block_hit_particles(grid_pos, str(block_type), "foreground")
			update_block_crack_visual(grid_pos)
			play_block_action_sound(grid_pos, action == "break")
			if current_hits < max_hits:
				world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
			else:
				world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if current_hits < max_hits:
		send_network_block_update("hit", "foreground", grid_pos, str(block_type), {
			"source_tool": get_current_block_hit_source_tool()
		})
		spawn_block_hit_particles(grid_pos, str(block_type), "foreground")
		update_block_crack_visual(grid_pos)
		world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
		play_block_hit_sound(grid_pos)
		return

	play_block_break_sound(grid_pos)
	spawn_neptune_trident_block_hit_particles(grid_pos, str(block_type), "foreground")
	break_block_grid(grid_pos)


func break_block_grid(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_type = world.blocks[grid_pos]["type"]
	var direct_return_item_id := get_direct_break_inventory_return_item(str(block_type))

	if world.is_crafting_station_block(block_type):
		world.break_crafting_station(grid_pos)
		return

	var block_data: Dictionary = world.blocks[grid_pos]
	var block_node_value: Variant = block_data.get("node", null)
	var block_node: Node = null
	if block_node_value is Node and is_instance_valid(block_node_value):
		block_node = block_node_value
	var drop_position := get_block_sound_position(grid_pos)
	if block_node is Node2D:
		var block_node_2d := block_node as Node2D
		drop_position = block_node_2d.global_position

	if should_use_server_authoritative_world_actions() and not is_applying_network_world_update():
		if send_network_block_update("break", "foreground", grid_pos, str(block_type), {
			"source_tool": get_current_block_hit_source_tool()
		}):
			authoritative_break_request_keys[get_authoritative_break_key("foreground", grid_pos)] = true
			world.show_notification("Breaking " + world.get_item_display_name(str(block_type), "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if direct_return_item_id != "" and not can_receive_direct_break_inventory_return(direct_return_item_id):
		world.show_notification("Your inventory cannot hold that machine.")
		return

	clear_foreground_crack_visual_for_data(block_data)

	spawn_block_break_effect(grid_pos, str(block_type))
	spawn_block_break_particles(grid_pos, str(block_type), "foreground")
	clear_tilemap_cell(grid_pos, false)
	clear_foreground_tilemap_collision_cell(grid_pos)
	remove_display_preview_visual(grid_pos)
	if block_node != null:
		clear_block_animation(block_node)
		retire_block_node_for_removal(block_node)
		block_node.queue_free()
	world.blocks.erase(grid_pos)
	server_triggered_animation_tokens.erase(grid_pos)
	if "mailbox_states" in world:
		world.mailbox_states.erase(grid_pos)
	if "donation_box_states" in world:
		world.donation_box_states.erase(grid_pos)
	if "bulletin_board_states" in world:
		world.bulletin_board_states.erase(grid_pos)
	if "display_states" in world:
		world.display_states.erase(grid_pos)
	if "tackle_box_states" in world:
		world.tackle_box_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "chicken_states" in world:
		world.chicken_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "cow_states" in world:
		world.cow_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "duck_states" in world:
		world.duck_states.erase(grid_pos)
		hide_tackle_box_timer_label()
	if "dice_states" in world:
		world.dice_states.erase(grid_pos)
	if "anti_punch_states" in world:
		world.anti_punch_states.erase(grid_pos)
	if "anti_talk_states" in world:
		world.anti_talk_states.erase(grid_pos)
	if "anti_gravity_states" in world:
		world.anti_gravity_states.erase(grid_pos)
	if "theme_machine_states" in world:
		world.theme_machine_states.erase(grid_pos)
		refresh_world_background_theme_from_machines()
	clear_active_checkpoint_if_matches(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
	clear_dice_roll_pending(grid_pos)
	clear_dice_roll_break_window(grid_pos)
	clear_chicken_interaction_pending(grid_pos)
	clear_cow_interaction_pending(grid_pos)
	clear_duck_interaction_pending(grid_pos)
	dice_active_rolls.erase(grid_pos)
	clear_anti_punch_animation(grid_pos)
	clear_anti_talk_animation(grid_pos)
	clear_anti_gravity_animation(grid_pos)
	clear_theme_machine_animation(grid_pos)
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)
	update_vertical_block_variants_around(grid_pos)

	if is_world_lock_block_type(str(block_type)) and world.has_method("on_world_lock_block_broken"):
		world.on_world_lock_block_broken(grid_pos)
	elif world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(str(block_type)) and world.has_method("on_area_lock_block_broken"):
		world.on_area_lock_block_broken(grid_pos)
	elif world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()

	send_network_block_update("break", "foreground", grid_pos, str(block_type), {
		"source_tool": get_current_block_hit_source_tool()
	})

	if not should_server_create_break_drops():
		if direct_return_item_id != "":
			return_broken_block_directly_to_inventory(direct_return_item_id)
		elif not world.try_drop_fixed_break_drops(str(block_type), drop_position):
			world.try_drop_block(block_type, drop_position)
			world.try_drop_seed(block_type, drop_position)
			world.try_drop_gems(block_type, drop_position)


func try_punch_priority_block_at_player_grid(player_grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(player_grid_pos):
		return false

	var player_tile_data = world.blocks.get(player_grid_pos, {})
	if not (player_tile_data is Dictionary):
		return false

	var block_type := str(player_tile_data.get("type", ""))
	if is_tackle_box_block_type(block_type):
		if try_harvest_tackle_box(player_grid_pos):
			return true
		hit_block_grid(player_grid_pos, true)
		return true
	if is_chicken_block_type(block_type):
		if try_harvest_chicken(player_grid_pos):
			return true
		hit_block_grid(player_grid_pos, true)
		return true
	if is_cow_block_type(block_type):
		if try_harvest_cow(player_grid_pos):
			return true
		hit_block_grid(player_grid_pos, true)
		return true
	if is_duck_block_type(block_type):
		if try_harvest_duck(player_grid_pos):
			return true
		hit_block_grid(player_grid_pos, true)
		return true
	if is_water_well_block_type(block_type):
		if try_harvest_water_well(player_grid_pos):
			return true
		hit_block_grid(player_grid_pos, true)
		return true
	if is_atm_machine_block_type(block_type):
		if try_harvest_atm_machine(player_grid_pos):
			return true
		hit_block_grid(player_grid_pos, true)
		return true

	return false


func has_mobile_facing_foreground_target_at_grid(grid_pos: Vector2i) -> bool:
	if world.blocks.has(grid_pos):
		return true

	var block_size := float(world.BLOCK_SIZE)
	var tile_center := Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)
	var tile_rect := Rect2(
		tile_center - Vector2(block_size, block_size) * 0.5 + Vector2(0.01, 0.01),
		Vector2(block_size - 0.02, block_size - 0.02)
	)
	for offset_y in range(-MOBILE_PUNCH_AREA_LOOKUP_RADIUS_TILES, MOBILE_PUNCH_AREA_LOOKUP_RADIUS_TILES + 1):
		for offset_x in range(-MOBILE_PUNCH_AREA_LOOKUP_RADIUS_TILES, MOBILE_PUNCH_AREA_LOOKUP_RADIUS_TILES + 1):
			var anchor_grid := grid_pos + Vector2i(offset_x, offset_y)
			var block_data = world.blocks.get(anchor_grid, null)
			if not (block_data is Dictionary):
				continue
			var block_type := str(block_data.get("type", ""))
			if not block_occupies_collision_area(block_type):
				continue
			if get_block_collision_rect_for_grid(anchor_grid, block_type).intersects(tile_rect, false):
				return true

	return false


func has_mobile_facing_punch_target_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or not world.is_grid_inside_world(grid_pos):
		return false
	if world.has_planted_seed(grid_pos):
		return true
	if has_mobile_facing_foreground_target_at_grid(grid_pos):
		return true
	if background_blocks.has(grid_pos):
		return true
	if world.has_method("has_visible_electrical_tile_at") and bool(world.has_visible_electrical_tile_at(grid_pos)):
		return true
	return false


func get_mobile_facing_punch_target_grid() -> Vector2i:
	if world == null or world.player == null:
		return world.INVALID_GRID_POS if world != null else Vector2i(999999, 999999)

	var player_grid_pos: Vector2i = world.get_player_grid_position()
	var facing_direction := -1 if int(world.player_facing_direction) < 0 else 1
	var block_size := maxf(1.0, float(world.BLOCK_SIZE))
	var interaction_range := maxf(block_size, float(world.INTERACTION_PIXEL_RANGE))
	# The extra candidate handles a player standing near a tile edge. The existing
	# reach check remains the final authority for every candidate.
	var max_scan_tiles := maxi(1, ceili(interaction_range / block_size) + 1)

	for tile_distance in range(1, max_scan_tiles + 1):
		var candidate := Vector2i(player_grid_pos.x + facing_direction * tile_distance, player_grid_pos.y)
		if not world.is_grid_inside_world(candidate):
			break
		if not world.can_reach_grid(candidate):
			break
		if has_mobile_facing_punch_target_at_grid(candidate):
			return candidate

	return world.INVALID_GRID_POS


func punch_facing_reach_block():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_shop_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	if world.player == null:
		return

	face_current_horizontal_punch_input()

	if try_enter_door_under_player():
		return

	var player_grid_pos: Vector2i = world.get_player_grid_position()
	if try_punch_priority_block_at_player_grid(player_grid_pos):
		return

	var target_grid_pos := get_mobile_facing_punch_target_grid()
	if target_grid_pos != world.INVALID_GRID_POS:
		punch_grid_position(target_grid_pos, true)
		return

	# Preserve the existing empty punch and nearby-player fallback when there is
	# no block target anywhere along the reachable horizontal ray.
	var fallback_facing := -1 if int(world.player_facing_direction) < 0 else 1
	punch_grid_position(Vector2i(player_grid_pos.x + fallback_facing, player_grid_pos.y), true)


func punch_facing_block():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_shop_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	if world.player == null:
		return

	face_current_horizontal_punch_input()

	if try_enter_door_under_player():
		return

	var player_grid_pos: Vector2i = world.get_player_grid_position()
	if try_punch_priority_block_at_player_grid(player_grid_pos):
		return

	var target_grid_pos = Vector2i(
		player_grid_pos.x + world.player_facing_direction,
		player_grid_pos.y
	)

	punch_grid_position(target_grid_pos, true)


func require_current_player_harvest_access_at(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if world.has_method("can_current_player_build_at") and not bool(world.can_current_player_build_at(grid_pos)):
		world.show_notification("This area is locked.")
		return false
	return true


func try_harvest_tackle_box(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_tackle_box_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)

	if is_tackle_box_harvest_pending(grid_pos):
		return false

	var remaining_ms := get_tackle_box_remaining_ms(grid_pos)
	if remaining_ms > 0:
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "tackle_box_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "harvest"
	}, world.current_world_name))
	if sent:
		mark_tackle_box_harvest_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
		world.show_notification("Harvesting Tackle Box...")
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_harvest_water_well(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_water_well_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)

	if is_tackle_box_harvest_pending(grid_pos):
		return false

	var remaining_ms := get_tackle_box_remaining_ms(grid_pos)
	if remaining_ms > 0:
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "tackle_box_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "harvest"
	}, world.current_world_name))
	if sent:
		mark_tackle_box_harvest_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_harvest_atm_machine(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_atm_machine_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)

	if is_tackle_box_harvest_pending(grid_pos):
		return false

	var remaining_ms := get_tackle_box_remaining_ms(grid_pos)
	if remaining_ms > 0:
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "tackle_box_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "harvest"
	}, world.current_world_name))
	if sent:
		mark_tackle_box_harvest_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
		world.show_notification("Harvesting ATM Machine...")
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_feed_chicken_at_grid(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_chicken_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return true

	var selected_item := str(world.selected_item_type).strip_edges().to_lower()
	var selected_category := str(world.selected_item_category).strip_edges().to_lower()
	if selected_item != "grain" or selected_category != "material":
		return false

	face_grid_for_block_punch(grid_pos)

	if is_chicken_interaction_pending(grid_pos):
		return true

	if not chicken_can_feed(grid_pos):
		return true

	if world.has_method("get_item_count") and int(world.get_item_count("grain", "material")) <= 0:
		world.show_notification("You need Grain.")
		return true

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "chicken_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "feed"
	}, world.current_world_name))
	if sent:
		mark_chicken_interaction_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_harvest_chicken(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_chicken_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)

	if is_chicken_interaction_pending(grid_pos):
		return true

	if not chicken_is_ready(grid_pos):
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "chicken_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "harvest"
	}, world.current_world_name))
	if sent:
		mark_chicken_interaction_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_feed_cow_at_grid(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_cow_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return true

	var selected_item := str(world.selected_item_type).strip_edges().to_lower()
	var selected_category := str(world.selected_item_category).strip_edges().to_lower()
	if selected_item != "wheat" or selected_category != "material":
		return false

	face_grid_for_block_punch(grid_pos)

	if is_cow_interaction_pending(grid_pos):
		return true

	if not cow_can_feed(grid_pos):
		return true

	if world.has_method("get_item_count") and int(world.get_item_count("wheat", "material")) <= 0:
		world.show_notification("You need Wheat.")
		return true

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "cow_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "feed"
	}, world.current_world_name))
	if sent:
		mark_cow_interaction_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_harvest_cow(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_cow_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)

	if is_cow_interaction_pending(grid_pos):
		return true

	if not cow_is_ready(grid_pos):
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "cow_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "harvest"
	}, world.current_world_name))
	if sent:
		mark_cow_interaction_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true

func try_feed_duck_at_grid(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_duck_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return true

	var selected_item := str(world.selected_item_type).strip_edges().to_lower()
	var selected_category := str(world.selected_item_category).strip_edges().to_lower()
	if selected_item != "grain" or selected_category != "material":
		return false

	face_grid_for_block_punch(grid_pos)

	if is_duck_interaction_pending(grid_pos):
		return true

	if not duck_can_feed(grid_pos):
		return true

	if world.has_method("get_item_count") and int(world.get_item_count("grain", "material")) <= 0:
		world.show_notification("You need Grain.")
		return true

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "duck_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "feed"
	}, world.current_world_name))
	if sent:
		mark_duck_interaction_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_harvest_duck(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_duck_block_type(block_type):
		return false
	if not require_current_player_harvest_access_at(grid_pos):
		return true

	face_grid_for_block_punch(grid_pos)

	if is_duck_interaction_pending(grid_pos):
		return true

	if not duck_is_ready(grid_pos):
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "duck_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"operation": "harvest"
	}, world.current_world_name))
	if sent:
		mark_duck_interaction_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func try_roll_dice_block(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", ""))
	if not is_dice_block_type(block_type):
		return false

	face_grid_for_block_punch(grid_pos)

	if is_dice_roll_pending(grid_pos) or dice_active_rolls.has(grid_pos) or is_dice_roll_break_window_active(grid_pos):
		return false

	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return true

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return true

	var sent = bool(network.send_world_interaction_update({
		"action": "dice_roll",
		"x": grid_pos.x,
		"y": grid_pos.y
	}, world.current_world_name))
	if sent:
		mark_dice_roll_pending(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		if world.has_method("play_sound_punch"):
			world.play_sound_punch(get_block_sound_position(grid_pos))
		world.show_notification("Rolling Dice...")
	else:
		world.show_notification("Almost ready. Try again in a moment.")
	return true


func punch_grid_position(grid_pos: Vector2i, force_punch_action: bool = false):
	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if world.has_planted_seed(grid_pos):
		if world.has_method("can_current_player_build_at") and not world.can_current_player_build_at(grid_pos):
			world.show_notification("This area is locked.")
			return

		face_grid_for_block_punch(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		world.harvest_planted_seed(grid_pos)
		return

	var anchor_grid_pos = get_anchor_grid_for_block_area(grid_pos)

	if anchor_grid_pos != world.INVALID_GRID_POS:
		face_grid_for_block_punch(grid_pos)
		hit_block_grid(anchor_grid_pos, force_punch_action)
		return

	if background_blocks.has(grid_pos):
		face_grid_for_block_punch(grid_pos)
		hit_background_block_grid(grid_pos)
		return

	if world.has_method("try_break_electrical_tile_at") and bool(world.try_break_electrical_tile_at(grid_pos)):
		face_grid_for_block_punch(grid_pos)
		spawn_hand_item_swing_particles_at_grid(grid_pos)
		return

	if world.has_method("request_player_punch_at_grid"):
		if world.request_player_punch_at_grid(grid_pos):
			return

	face_grid_for_block_punch(grid_pos)
	spawn_hand_item_swing_particles_at_grid(grid_pos)


func punch_at_mouse():
	if world.is_chat_input_focused():
		return

	var old_item_type = world.selected_item_type
	var old_item_category = world.selected_item_category

	world.selected_item_type = "punch"
	world.selected_item_category = "tool"

	break_block_at_mouse()

	world.selected_item_type = old_item_type
	world.selected_item_category = old_item_category

	if world.has_method("refresh_hotbar_live"):
		world.refresh_hotbar_live()
	elif world.has_method("update_hotbar"):
		world.update_hotbar()


func get_place_item_count(item_type: String, category: String) -> int:
	if world == null:
		return 0
	var clean_item := str(item_type).strip_edges()
	var clean_category := str(category).strip_edges().to_lower()
	match clean_category:
		"block":
			return int(world.inventory.get(clean_item, 0))
		"seed":
			return int(world.seed_inventory.get(clean_item, 0))
		"lure":
			return int(world.lure_inventory.get(clean_item, 0))
		"material":
			return int(world.material_inventory.get(clean_item, 0))
	return 0


func select_primary_hotbar_tool_after_place_stack_depleted(item_type: String, category: String) -> bool:
	if world == null:
		return false
	var clean_item := str(item_type).strip_edges()
	var clean_category := str(category).strip_edges().to_lower()
	if clean_item == "" or clean_category == "" or clean_category == "empty":
		return false
	if get_place_item_count(clean_item, clean_category) > 0:
		return false

	# The placed stack is now empty, so stop chain placing and select slot 1.
	if world.has_method("end_fast_block_place_hold"):
		world.end_fast_block_place_hold(-1)
	if world.has_method("select_hotbar_slot"):
		world.select_hotbar_slot(0)
	elif world.has_method("get_primary_hotbar_tool"):
		world.selected_item_type = str(world.get_primary_hotbar_tool())
		world.selected_item_category = "tool"
	else:
		world.selected_item_type = "punch"
		world.selected_item_category = "tool"

	if world.has_method("refresh_hotbar_live"):
		world.refresh_hotbar_live()
	elif world.has_method("update_hotbar"):
		world.update_hotbar()
	return true


func restore_selected_place_item_if_auto_switched(item_type: String, category: String) -> void:
	if world == null:
		return
	var clean_item := str(item_type).strip_edges()
	var clean_category := str(category).strip_edges().to_lower()
	if clean_item == "" or clean_category == "" or clean_category == "empty":
		return
	if get_place_item_count(clean_item, clean_category) <= 0:
		return
	if world.has_meta("manual_hotbar_selection_msec") and Time.get_ticks_msec() - int(world.get_meta("manual_hotbar_selection_msec", 0)) < 500:
		return
	if str(world.selected_item_type) == clean_item and str(world.selected_item_category).strip_edges().to_lower() == clean_category:
		return

	var current_item := str(world.selected_item_type).strip_edges().to_lower()
	var current_category := str(world.selected_item_category).strip_edges().to_lower()
	var primary_tool := "punch"
	if world.has_method("get_primary_hotbar_tool"):
		primary_tool = str(world.get_primary_hotbar_tool()).strip_edges().to_lower()

	var looks_like_hotbar_auto_reset := current_category == "tool" and (current_item == "" or current_item == "punch" or current_item == "wrench" or current_item == primary_tool)
	if not looks_like_hotbar_auto_reset:
		return

	# Only restore the placing item when it still has count left. Empty stacks should
	# intentionally fall back to slot 1.
	world.selected_item_type = clean_item
	world.selected_item_category = clean_category
	if world.has_method("refresh_hotbar_live"):
		world.refresh_hotbar_live()
	elif world.has_method("update_hotbar"):
		world.update_hotbar()


func place_block_at_mouse():
	if is_waiting_for_server_sign_on():
		trace_authoritative_place_event("place_attempt_blocked", {"reason": "waiting_for_server_sign_on"})
		show_server_sign_on_notice()
		return

	if is_water_bucket_selected():
		trace_authoritative_place_event("place_attempt_redirected", {"reason": "water_bucket_selected"})
		try_use_water_bucket_at_mouse()
		return

	var selected_block_type := str(world.selected_item_type)
	var selected_block_category := str(world.selected_item_category)

	if selected_block_type.strip_edges().to_lower() == WATER_BLOCK_TYPE:
		trace_authoritative_place_event("place_attempt_blocked", {
			"reason": "water_requires_bucket",
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		world.show_notification("Use a Water Bucket to place water.")
		return

	if selected_block_type == "crafting_station":
		trace_authoritative_place_event("place_attempt_redirected", {
			"reason": "crafting_station_special_case",
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		world.place_crafting_station_at_mouse()
		return

	if not world.inventory.has(selected_block_type):
		trace_authoritative_place_event("place_attempt_blocked", {
			"reason": "missing_inventory_entry",
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		return

	if int(world.inventory.get(selected_block_type, 0)) <= 0:
		trace_authoritative_place_event("place_attempt_blocked", {
			"reason": "inventory_count_zero",
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		world.show_notification("You don't have any " + world.get_item_display_name(selected_block_type, selected_block_category) + ".")
		return

	if world.item_database.has(selected_block_type) and not bool(world.item_database[selected_block_type].get("placeable", true)):
		trace_authoritative_place_event("place_attempt_blocked", {
			"reason": "item_not_placeable",
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		world.show_notification(world.get_item_display_name(selected_block_type, selected_block_category) + " is used by electrical tools.")
		return

	var grid_pos = world.get_mouse_grid_position()
	trace_authoritative_place_event("place_attempt_start", {
		"layer": "auto",
		"grid_pos": grid_pos,
		"block_type": selected_block_type,
		"category": selected_block_category,
		"inventory_count": int(world.inventory.get(selected_block_type, 0)),
		"server_authoritative": should_use_server_authoritative_world_actions()
	})

	if not world.is_grid_inside_world(grid_pos):
		trace_place_attempt_blocked("outside_world_bounds", "auto", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		trace_place_attempt_blocked("too_far", "auto", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("Too far away.")
		return

	if block_requires_world_lock(selected_block_type) and not world_has_world_lock():
		trace_place_attempt_blocked("requires_world_lock", "foreground", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("You need a World Lock in this world before placing a Fish Monger.")
		return

	if is_world_lock_block_type(selected_block_type) and world.world_lock_manager != null:
		var already_has_lock := bool(world.world_lock_manager.is_locked)
		if world.world_lock_manager.has_method("has_world_lock_block"):
			already_has_lock = already_has_lock or bool(world.world_lock_manager.has_world_lock_block())
		if already_has_lock:
			trace_place_attempt_blocked("world_lock_already_exists", "foreground", grid_pos, selected_block_type, selected_block_category)
			world.show_notification("This world already has a World Lock.")
			return

	if is_anti_punch_block_type(selected_block_type) and has_anti_punch_block_in_world():
		trace_place_attempt_blocked("anti_punch_already_exists", "foreground", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("This world already has an Anti-Punch block.")
		return
	if is_anti_talk_block_type(selected_block_type) and has_anti_talk_block_in_world():
		trace_place_attempt_blocked("anti_talk_already_exists", "foreground", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("This world already has an Anti-Talk block.")
		return
	if is_anti_gravity_block_type(selected_block_type) and has_anti_gravity_block_in_world():
		trace_place_attempt_blocked("anti_gravity_already_exists", "foreground", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("This world already has an Anti-Gravity block.")
		return
	if is_snow_repellent_block_type(selected_block_type) and has_snow_repellent_block_in_world():
		trace_place_attempt_blocked("snow_repellent_already_exists", "foreground", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("This world already has a Snow Repellent block.")
		return

	if world.has_method("can_current_player_place_block_at") and not world.can_current_player_place_block_at(selected_block_type, grid_pos):
		trace_place_attempt_blocked("place_permission_denied", "auto", grid_pos, selected_block_type, selected_block_category)
		if world.world_lock_manager != null and world.world_lock_manager.has_method("is_vending_machine_block") and world.world_lock_manager.is_vending_machine_block(selected_block_type):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can place vending machines.")
			else:
				world.show_notification("Lock this world before placing vending machines.")
		elif world.world_lock_manager != null and world.world_lock_manager.has_method("is_safe_block") and world.world_lock_manager.is_safe_block(selected_block_type):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can place safes.")
			else:
				world.show_notification("Lock this world before placing safes.")
		elif world.has_method("is_display_block_type") and world.is_display_block_type(selected_block_type):
			if world.world_lock_manager != null and world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can place displays.")
			else:
				world.show_notification("Lock this world before placing displays.")
		elif world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(selected_block_type):
			world.show_notification("That area is already protected by another lock.")
		else:
			world.show_notification("This world is locked.")
		return

	if world.has_method("can_current_player_build_at") and not world.can_current_player_build_at(grid_pos):
		trace_place_attempt_blocked("build_permission_denied", "auto", grid_pos, selected_block_type, selected_block_category)
		world.show_notification("This world is locked.")
		return

	if world.has_method("is_electrical_item") and bool(world.is_electrical_item(selected_block_type)):
		trace_authoritative_place_event("place_attempt_redirected", {
			"reason": "electrical_item",
			"layer": "electrical",
			"grid_pos": grid_pos,
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		if world.has_method("try_place_electrical_item_at"):
			world.try_place_electrical_item_at(grid_pos)
		return

	if is_background_block_type(selected_block_type):
		if not can_place_background_block_here(grid_pos):
			trace_place_attempt_blocked("background_validation_failed", "background", grid_pos, selected_block_type, selected_block_category)
			return

		if should_use_server_authoritative_world_actions():
			var background_place_key = get_authoritative_place_key("background", grid_pos, selected_block_type)
			if has_recent_authoritative_place_request(background_place_key):
				trace_place_attempt_blocked("recent_same_cell_request", "background", grid_pos, selected_block_type, selected_block_category, {
					"place_key": background_place_key
				})
				world.show_notification("Placing " + world.get_item_display_name(selected_block_type, selected_block_category) + "...")
				return
			if has_recent_authoritative_place_send():
				trace_place_attempt_blocked("global_place_send_cooldown", "background", grid_pos, selected_block_type, selected_block_category)
				return
			if should_predict_authoritative_place(selected_block_type, "background") and get_available_place_item_count_for_prediction(selected_block_type, selected_block_category) <= 0:
				trace_place_attempt_blocked("no_available_count_after_reservations", "background", grid_pos, selected_block_type, selected_block_category, {
					"inventory_count": get_place_item_count(selected_block_type, selected_block_category),
					"reserved_count": get_pending_authoritative_place_reserved_count(selected_block_type, selected_block_category)
				})
				world.show_notification("Placing " + world.get_item_display_name(selected_block_type, selected_block_category) + "...")
				return
			var background_request_id := make_authoritative_place_request_id("background", grid_pos, selected_block_type)
			var background_prediction_applied := false
			if should_predict_authoritative_place(selected_block_type, "background"):
				background_prediction_applied = apply_predicted_authoritative_place(background_request_id, "background", grid_pos, selected_block_type, selected_block_category)
			if send_network_block_update("place", "background", grid_pos, selected_block_type, {"request_id": background_request_id}):
				trace_authoritative_place_event("authoritative_place_sent", {
					"request_id": background_request_id,
					"layer": "background",
					"grid_pos": grid_pos,
					"block_type": selected_block_type,
					"category": selected_block_category
				})
				mark_authoritative_place_request(background_place_key)
				mark_authoritative_place_send()
				if should_predict_authoritative_place(selected_block_type, "background") and not background_prediction_applied:
					world.show_notification("Placing " + world.get_item_display_name(selected_block_type, selected_block_category) + "...")
			else:
				if background_prediction_applied:
					rollback_predicted_authoritative_place({
						"request_id": background_request_id,
						"reason": "client_send_failed",
						"message": "Placement request was not sent."
					}, false)
				trace_authoritative_place_event("authoritative_place_send_failed", {
					"request_id": background_request_id,
					"layer": "background",
					"grid_pos": grid_pos,
					"block_type": selected_block_type,
					"category": selected_block_category
				})
				world.show_notification("Almost ready. Try again in a moment.")
			return

		create_background_block(grid_pos, selected_block_type)
		trace_authoritative_place_event("legacy_local_place_applied", {
			"layer": "background",
			"grid_pos": grid_pos,
			"block_type": selected_block_type,
			"category": selected_block_category
		})
		send_network_block_update("place", "background", grid_pos, selected_block_type)
		spawn_block_place_particles(grid_pos, selected_block_type, "background")
		if world.has_method("refresh_area_lock_highlight_overlay"):
			world.refresh_area_lock_highlight_overlay()
		world.inventory[selected_block_type] -= 1
		if world.has_method("play_sound_place"):
			world.play_sound_place(get_block_sound_position(grid_pos))
		if world.has_method("refresh_ui_after_item_change"):
			world.refresh_ui_after_item_change(selected_block_type, selected_block_category)
		else:
			world.update_all_ui()
		if not select_primary_hotbar_tool_after_place_stack_depleted(selected_block_type, selected_block_category):
			restore_selected_place_item_if_auto_switched(selected_block_type, selected_block_category)
		return

	if not can_place_block_here(grid_pos):
		trace_place_attempt_blocked("foreground_validation_failed", "foreground", grid_pos, selected_block_type, selected_block_category)
		return

	if should_use_server_authoritative_world_actions():
		var foreground_place_key = get_authoritative_place_key("foreground", grid_pos, selected_block_type)
		if has_recent_authoritative_place_request(foreground_place_key):
			trace_place_attempt_blocked("recent_same_cell_request", "foreground", grid_pos, selected_block_type, selected_block_category, {
				"place_key": foreground_place_key
			})
			world.show_notification("Placing " + world.get_item_display_name(selected_block_type, selected_block_category) + "...")
			return
		if has_recent_authoritative_place_send():
			trace_place_attempt_blocked("global_place_send_cooldown", "foreground", grid_pos, selected_block_type, selected_block_category)
			return
		if should_predict_authoritative_place(selected_block_type, "foreground") and get_available_place_item_count_for_prediction(selected_block_type, selected_block_category) <= 0:
			trace_place_attempt_blocked("no_available_count_after_reservations", "foreground", grid_pos, selected_block_type, selected_block_category, {
				"inventory_count": get_place_item_count(selected_block_type, selected_block_category),
				"reserved_count": get_pending_authoritative_place_reserved_count(selected_block_type, selected_block_category)
			})
			world.show_notification("Placing " + world.get_item_display_name(selected_block_type, selected_block_category) + "...")
			return
		var foreground_request_id := make_authoritative_place_request_id("foreground", grid_pos, selected_block_type)
		var foreground_prediction_applied := false
		if should_predict_authoritative_place(selected_block_type, "foreground"):
			foreground_prediction_applied = apply_predicted_authoritative_place(foreground_request_id, "foreground", grid_pos, selected_block_type, selected_block_category)
		if send_network_block_update("place", "foreground", grid_pos, selected_block_type, {"request_id": foreground_request_id}):
			trace_authoritative_place_event("authoritative_place_sent", {
				"request_id": foreground_request_id,
				"layer": "foreground",
				"grid_pos": grid_pos,
				"block_type": selected_block_type,
				"category": selected_block_category
			})
			mark_authoritative_place_request(foreground_place_key)
			mark_authoritative_place_send()
			if should_predict_authoritative_place(selected_block_type, "foreground") and not foreground_prediction_applied:
				world.show_notification("Placing " + world.get_item_display_name(selected_block_type, selected_block_category) + "...")
		else:
			if foreground_prediction_applied:
				rollback_predicted_authoritative_place({
					"request_id": foreground_request_id,
					"reason": "client_send_failed",
					"message": "Placement request was not sent."
				}, false)
			trace_authoritative_place_event("authoritative_place_send_failed", {
				"request_id": foreground_request_id,
				"layer": "foreground",
				"grid_pos": grid_pos,
				"block_type": selected_block_type,
				"category": selected_block_category
			})
			world.show_notification("Almost ready. Try again in a moment.")
		return

	create_block(grid_pos, selected_block_type)
	trace_authoritative_place_event("legacy_local_place_applied", {
		"layer": "foreground",
		"grid_pos": grid_pos,
		"block_type": selected_block_type,
		"category": selected_block_category
	})
	if is_tackle_box_block_type(selected_block_type):
		initialize_tackle_box_cooldown_on_place(grid_pos, selected_block_type)
	if is_water_well_block_type(selected_block_type):
		initialize_tackle_box_cooldown_on_place(grid_pos, selected_block_type)
	if is_atm_machine_block_type(selected_block_type):
		initialize_tackle_box_cooldown_on_place(grid_pos, selected_block_type)
	if is_chicken_block_type(selected_block_type):
		initialize_chicken_hunger_on_place(grid_pos, selected_block_type)
	if is_cow_block_type(selected_block_type):
		initialize_cow_hunger_on_place(grid_pos, selected_block_type)
	if is_duck_block_type(selected_block_type):
		initialize_duck_hunger_on_place(grid_pos, selected_block_type)
	send_network_block_update("place", "foreground", grid_pos, selected_block_type)
	spawn_block_place_particles(grid_pos, selected_block_type, "foreground")

	if is_world_lock_block_type(selected_block_type) and world.has_method("on_world_lock_block_placed"):
		world.on_world_lock_block_placed(grid_pos, selected_block_type)
	elif world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(selected_block_type) and world.has_method("on_area_lock_block_placed"):
		world.on_area_lock_block_placed(grid_pos, selected_block_type)
	elif world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()

	world.inventory[selected_block_type] -= 1
	if world.has_method("play_sound_place"):
		world.play_sound_place(get_block_sound_position(grid_pos))
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(selected_block_type, selected_block_category)
	else:
		world.update_all_ui()
	if not select_primary_hotbar_tool_after_place_stack_depleted(selected_block_type, selected_block_category):
		restore_selected_place_item_if_auto_switched(selected_block_type, selected_block_category)


func can_place_block_here(grid_pos: Vector2i) -> bool:
	var block_type = str(world.selected_item_type)
	var category := str(world.selected_item_category)

	if world.blocks.has(grid_pos):
		trace_place_attempt_blocked("foreground_cell_occupied", "foreground", grid_pos, block_type, category)
		return false

	if world.has_planted_seed(grid_pos):
		trace_place_attempt_blocked("foreground_blocked_by_seed", "foreground", grid_pos, block_type, category)
		return false

	if does_block_have_placement_collision(block_type) and world.is_block_inside_player(grid_pos):
		trace_place_attempt_blocked("foreground_collision_blocked_by_player_body", "foreground", grid_pos, block_type, category)
		return false

	var proposed_rect = get_block_collision_rect_for_grid(grid_pos, block_type)
	if does_rect_overlap_reserved_object(proposed_rect):
		trace_place_attempt_blocked("foreground_blocked_by_reserved_object", "foreground", grid_pos, block_type, category)
		return false

	if block_requires_full_area_clear(block_type):
		var full_area_clear := can_place_full_collision_area(grid_pos, block_type)
		if not full_area_clear:
			trace_place_attempt_blocked("foreground_full_area_blocked", "foreground", grid_pos, block_type, category)
		return full_area_clear

	return true


func is_lava_block(grid_pos: Vector2i) -> bool:
	if not world.blocks.has(grid_pos):
		return false

	return world.blocks[grid_pos]["type"] == "lava"
