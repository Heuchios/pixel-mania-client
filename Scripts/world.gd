extends Node2D

const TouchInputGuard = preload("res://Scripts/touch_input_guard.gd")

const BLOCK_SIZE = 32
const WORLD_WIDTH = 100
const GROUND_Y = 14
const WORLD_HEIGHT = 70
const PICKUP_RANGE = 28.0
const INTERACTION_PIXEL_RANGE = 128.0
const HAND_ITEM_SWING_RANGE_PIXELS = 48.0
# Fast place assist: keeps block placing responsive when holding mouse/touch and
# dragging across tiles. The first placement is still handled by the normal input
# path; this only adds safe follow-up placements on new target cells.
const FAST_BLOCK_PLACE_INITIAL_DELAY := 0.11
const FAST_BLOCK_PLACE_REPEAT_INTERVAL := 0.16
const SAVE_PATH = "user://world_save.json"
const WORLD_SAVE_FOLDER = "user://worlds/"
const PLAYER_SAVE_PATH = "user://pixelmania_player_data.json"
const LOBBY_PROFILE_PATH = "user://pixelmania_profile.cfg"
const PLAYER_DATA_VERSION = 1
const PLAYER_MAX_LEVEL = 100
const DEFAULT_WORLD_NAME = "START"
const WORLD_VERSION = 10
const INVALID_GRID_POS = Vector2i(999999, 999999)
const HOTBAR_SLOT_COUNT = 6
const MAX_ITEM_STACK_SIZE = 400
const GEM_CURRENCY_ITEM_ID = "gem"
const GEM_CURRENCY_CAP = 100000000000
const INVENTORY_MIN_SLOT_COUNT = 20
const INVENTORY_MAX_SLOT_COUNT = 300
const INVENTORY_SLOT_UPGRADE_STEP = 20
const INVENTORY_SLOT_UPGRADE_COSTS = [
	2000,
	4000,
	6000,
	8000,
	10000,
	12000,
	14000,
	16000,
	18000,
	20000,
	24000,
	30000,
	38000,
	48000
]

const BEDROCK_START_Y = WORLD_HEIGHT - 4
const SURFACE_Y = BEDROCK_START_Y - 9
const GRASS_LAYER_Y = SURFACE_Y
const DIRT_LAYER_START_Y = SURFACE_Y + 1
const DIRT_LAYER_END_Y = SURFACE_Y + 8
const STONE_RANDOM_START_Y = DIRT_LAYER_START_Y
const LAVA_RANDOM_START_Y = DIRT_LAYER_START_Y + 5

const SPAWN_GRID_X = 10
const SPAWN_FLAT_RADIUS = 5
const TERRAIN_MIN_SURFACE_Y = BEDROCK_START_Y - 15
const TERRAIN_MAX_SURFACE_Y = BEDROCK_START_Y - 8
const TREE_MIN_SPACING = 7

const WORLD_PIXEL_WIDTH = WORLD_WIDTH * BLOCK_SIZE
const WORLD_PIXEL_HEIGHT = WORLD_HEIGHT * BLOCK_SIZE
const PLAYER_BOUND_MARGIN = BLOCK_SIZE * 0.5
const SERVER_POSITION_CORRECTION_SNAP_DISTANCE := 160.0
const SERVER_POSITION_CORRECTION_DEFAULT_SMOOTH_MS := 80

const CAMERA_ZOOM_MIN = 1.5
const CAMERA_ZOOM_MAX = 7.0
const CAMERA_ZOOM_STEP = 0.12
const CAMERA_ZOOM_DEFAULT = 3.0

# Blocks are drawn from grid positions, so the real visual edge is half a block
# before the first block and half a block after the last block.
const WORLD_VISUAL_LEFT = -BLOCK_SIZE * 0.5
const WORLD_VISUAL_TOP = -BLOCK_SIZE * 0.5
const WORLD_VISUAL_RIGHT = ((WORLD_WIDTH - 1) * BLOCK_SIZE) + (BLOCK_SIZE * 0.5)
const WORLD_VISUAL_BOTTOM = ((WORLD_HEIGHT - 1) * BLOCK_SIZE) + (BLOCK_SIZE * 0.5)
const LOCAL_PLAYER_Z_INDEX = 3900

const HOTBAR_HEIGHT = 104.0
const INVENTORY_DRAWER_WIDTH = 500.0
const INVENTORY_DRAWER_HEIGHT = 360.0
const INVENTORY_OPEN_SPEED = 8.0

const LAVA_DAMAGE_DELAY = 0.6
const RESPAWN_POSITION = Vector2(300, (SURFACE_Y - 2) * BLOCK_SIZE)
const SEED_DROP_CHANCE = 0.25
const SEED_GROW_TIME = 8.0
const MATURE_SEED_EXTRA_DROP_CHANCE = 0.65
const RED_TRACTOR_ITEM_ID = "red_tractor"
const RED_TRACTOR_AUTO_HARVEST_PENDING_MS = 250
const BLOCK_MAX_HITS = 3
const BLOCK_DAMAGE_RESET_DELAY = 3.0
const GEM_DROP_CHANCE = 1.0
const GEM_DROP_MIN = 1
const GEM_DROP_MAX = 3

const WATER_ANIMATION_SPEED = 0.32
const WATER_MIN_POOL_SPACING = 13

const ENTRANCE_GATE_TYPE = "entrance_gate"
const ENTRANCE_GATE_CLEAR_RADIUS = 3
const CITY_THEME_RAIN_FX_SCENE_PATH = "res://Scenes/particles/RainParticlesFX.tscn"
const SNOW_STORM_FX_SCENE_PATH = "res://Scenes/particles/SnowStormFX.tscn"
const SNOW_STORM_WIND_FX_SCENE_PATH = "res://Scenes/particles/WindGustFX.tscn"
const ROTATING_SWORD_SLASH_FX_SCENE_PATH = "res://Scenes/particles/RotatingSwordSlashFX.tscn"
const ANT_SWORD_SLASH_REMOTE_DEDUPE_MSEC := 140

var block_scene = preload("res://Scenes/block.tscn")
var rotating_sword_slash_scene: PackedScene = null
var blocks = {}
var vending_states = {}
var safe_states = {}
var donation_box_states = {}
var mailbox_states = {}
var bulletin_board_states = {}
var display_states = {}
var tackle_box_states = {}
var chicken_states = {}
var cow_states = {}
var duck_states = {}
var dice_states = {}
var oil_refinery_states = {}
var battery_charger_states = {}
var cctv_state = {}
var anti_punch_states = {}
var anti_talk_states = {}
var anti_gravity_states = {}
var theme_machine_states = {}
var active_world_theme := ""
var active_checkpoint_grid: Vector2i = INVALID_GRID_POS
var active_checkpoint_world: String = ""
var terrain_surface_y = {}

var selected_item_type = "punch"
var selected_item_category = "tool"
var primary_hotbar_tool = "punch"

var player_level = 1
var player_xp = 0
var player_xp_needed = 300
var player_total_xp = 0
var player_title = "Explorer"
var player_health = 10
var inventory_slot_count = INVENTORY_MIN_SLOT_COUNT
var lava_damage_timer = 0.0
var player_facing_direction = 1
var current_camera_zoom = CAMERA_ZOOM_DEFAULT
var mobile_pointer_override_active = false
var mobile_pointer_screen_position = Vector2.ZERO
var fast_block_place_hold_active := false
var fast_block_place_hold_touch_index := -1
var fast_block_place_hold_timer := 0.0
var fast_block_place_last_grid: Vector2i = INVALID_GRID_POS
var fast_block_place_last_item_type := ""
var fast_block_place_last_item_category := ""
var fast_block_place_grid_override_active := false
var fast_block_place_grid_override: Vector2i = INVALID_GRID_POS
var water_frames: Array = []
var water_anim_timer = 0.0
var water_anim_index = 0
var current_world_name = DEFAULT_WORLD_NAME
var in_world = false
var noclip_enabled = false
var player_physics_enabled_before_noclip = true
var chat_typing_movement_locked = false
var player_physics_enabled_before_chat_lock = true
var back_item_air_jumps_used = 0
var player_data_loaded_from_file = false
var server_position_correction_tween = null
const NOCLIP_SPEED = 260.0

const BACK_ITEM_JUMP_VELOCITY = -420.0
const LEGENDARY_WINGS_ID = "legendary_wings"

const FISHING_ROD_ID = "bamboo_rod"
const FISHING_CAST_TIME = 1.25
const FISHING_CAST_RANGE_TILES = 4
const FISHING_CAST_PIXEL_RANGE = BLOCK_SIZE * FISHING_CAST_RANGE_TILES
const LURE_PACK_SIZE = 5
var equipped_tool = ""
var equipped_back_item = ""
var equipped_hat_item = ""
var equipped_hair_item = ""
var equipped_eyewear_item = ""
var equipped_shirt_item = ""
var equipped_pants_item = ""
var equipped_shoes_item = ""
var equipped_ride_item = ""
var equipped_tool_visual = null
var equipped_tool_sprite = null
var last_equipment_visual_key: String = ""
var red_tractor_auto_harvest_pending_grids: Dictionary = {}
var seed_harvest_request_sequence := 0
var seed_harvest_pending_rollback: Dictionary = {}
const SEED_HARVEST_REQUEST_PREFIX := "seed_harvest"
const SEED_HARVEST_PENDING_ROLLBACK_MS := 15000

var lure_inventory = {}
var fish_inventory = {}
var lure_textures = {}
var fish_textures = {}
var lure_items = []
var fish_items = []

var fishing_active = false
var fishing_timer = 0.0
var fishing_lure_id = ""
var fishing_target_grid = INVALID_GRID_POS

const ITEM_DATABASE_PATH = "res://Scripts/item_database.gd"
const SEED_BOX_TEXTURE_PATH = "res://Assets/seeds/seed_box.png"
const SEED_ICON_PREVIEW_MAX_SIZE = 10
const SEED_ICON_PREVIEW_TOP = 13
const SEED_ICON_PREVIEW_OFFSET = Vector2i(-4, -2)
const SEED_DROP_ICON_PREVIEW_MAX_SIZE = 10
const SEED_DROP_ICON_PREVIEW_TOP = 14
const SEED_DROP_ICON_PREVIEW_OFFSET = Vector2i(-3, -2)
const BLOCK_TREE_TEMPLATE_PATHS = [
	"res://Assets/seed_tree_sprites/block_tree_stage_0.png",
	"res://Assets/seed_tree_sprites/block_tree_stage_1.png",
	"res://Assets/seed_tree_sprites/block_tree_stage_2.png",
	"res://Assets/seed_tree_sprites/block_tree_mature.png"
]
const BG_TREE_TEMPLATE_PATHS = [
	"res://Assets/seed_tree_sprites/bg_tree_stage0.png",
	"res://Assets/seed_tree_sprites/bg_tree_stage1.png",
	"res://Assets/seed_tree_sprites/bg_tree_stage2.png",
	"res://Assets/seed_tree_sprites/bg_tree_mature.png"
]
const COLOURED_BLOCK_IDS = [
	"red_block",
	"blue_block",
	"green_block",
	"purple_block",
	"yellow_block",
	"aqua_block",
	"black_block",
	"blue_pastel_block",
	"brown_block",
	"dark_aqua_block",
	"dark_blue_block",
	"dark_brown_block",
	"dark_green_block",
	"dark_pink_block",
	"dark_purple_block",
	"dark_red_block",
	"dark_yellow_block",
	"green_pastel_block",
	"grey_block",
	"happy_block",
	"light_brown_block",
	"orange_block",
	"orange_pastel_block",
	"pastel_flower_block",
	"pink_block",
	"pink_pastel_block",
	"purple_pastel_block",
	"red_pastel_block",
	"white_block",
	"yellow_pastel_block"
]
const SEED_TREE_MATURE_STAGE_INDEX = 3
const SEED_TREE_PREVIEW_MAX_SIZE = 8
const SEED_TREE_PREVIEW_MIN_COUNT = 1
const SEED_TREE_PREVIEW_MAX_COUNT = 2
const SEED_TREE_PREVIEW_GAP = 1
const SEED_TREE_MATURE_PREVIEW_POSITIONS = [
	Vector2i(8, 10),
	Vector2i(17, 10)
]
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")

var item_database = {}
var splice_recipes = {}
var tier_1_splice_balance = {}

var inventory = {}
var seed_inventory = {}
var tool_inventory = {}
var back_inventory = {}
var hat_inventory = {}
var hair_inventory = {}
var eyewear_inventory = {}
var shirt_inventory = {}
var pants_inventory = {}
var shoes_inventory = {}
var ride_inventory = {}
var currency_inventory = {}
var material_inventory = {}
var block_textures = {}
var crack_textures = {}
var seed_textures = {}
var seed_tree_textures = {}
var seed_icon_texture_cache = {}
var seed_drop_icon_texture_cache = {}
var generated_seed_tree_texture_blocks = {}
var tool_textures = {}
var back_textures = {}
var hat_textures = {}
var hair_textures = {}
var eyewear_textures = {}
var shirt_textures = {}
var pants_textures = {}
var shoes_textures = {}
var ride_textures = {}
var currency_textures = {}
var material_textures = {}
var block_items = []
var tool_items = []
var back_items = []
var hat_items = []
var hair_items = []
var eyewear_items = []
var shirt_items = []
var pants_items = []
var shoes_items = []
var ride_items = []
var material_items = []

# Hotbar slot 1 toggles between punch and wrench. Slots 2-6 are rotating quick-use items.
var hotbar_items = ["punch", "dirt", "grass", "stone", "wood", "leaf"]
var hotbar_item_categories = ["tool", "block", "block", "block", "block", "block"]

var dropped_items = []
var block_hit_progress = {}
var block_hit_timers = {}
var seed_system = null

var hotbar_root = null
var hotbar_slots = {}
var hotbar_handle = null

var inventory_button = null

var inventory_window = null
var inventory_tab = "blocks"
var inventory_grid_root = null
var inventory_slots = {}
var inventory_tab_buttons = {}

var drag_handle_active = false
var drag_handle_start_y = 0.0
var drag_handle_start_amount = 0.0

var inventory_drawer_amount = 0.0
var inventory_drawer_target = 0.0

var chat_ui = null
var inventory_manager = null
var save_manager = null
var equipment_manager = null
var player_animation_manager = null
var command_manager = null
var player_menu_ui = null
var game_menu_ui = null
var settings_panel_ui = null
var friends_ui = null
var developer_panel_ui = null
var trade_ui = null
var vending_ui = null
var safe_ui = null
var donation_box_ui = null
var mailbox_ui = null
var bulletin_board_ui = null
var display_ui = null
var fish_monger_ui = null
var cctv_ui = null
var oil_refinery_ui = null
var battery_charger_ui = null
var generator_ui = null
var shop_ui = null
var crafting_ui = null
var furnace_ui = null
var sign_ui = null
var world_menu_ui = null
var notification_ui = null
var drop_manager = null
var world_generation_manager = null
var block_manager = null
var item_atlas_refresh_pending := false
var particle_manager = null
var block_shadow_manager = null
var interaction_manager = null
var player_manager = null
var gameplay_ui_manager = null
var fishing_manager = null
var fish_monger_manager = null
var item_gameplay_manager = null
var vending_preview_manager = null
var environment_manager = null
var input_manager = null
var account_manager = null
var world_lock_manager = null
var world_lock_ui = null
var area_lock_ui = null
var area_lock_highlight_overlay = null
var username_label_manager = null
var background_manager = null
var electricity_manager = null
var reach_indicator_manager = null
var sound_manager = null
var world_loading_ui_manager = null
var world_state_sync_manager = null
var netfox_real_manager = null
var custom_authoritative_movement_manager = null
var ui_overhead_layer: Control = null
var ui_hud_layer: Control = null
var ui_panel_layer: Control = null
var ui_modal_layer: Control = null
var ui_system_layer: Control = null
var city_theme_rain_fx = null
var snow_storm_fx = null
var snow_storm_wind_fx = null
var applying_network_world_update = false


func is_gem_currency(item_type: String, _category: String = "currency") -> bool:
	return item_type == GEM_CURRENCY_ITEM_ID


func get_stack_limit_for_item(item_type: String, category: String = "") -> int:
	if is_gem_currency(item_type, category):
		return GEM_CURRENCY_CAP

	var item_data = null
	if item_database.has(item_type):
		item_data = item_database[item_type]

	var configured_stack_limit = MAX_ITEM_STACK_SIZE

	if item_data != null:
		if item_data.has("max_stack"):
			configured_stack_limit = int(item_data.get("max_stack", MAX_ITEM_STACK_SIZE))
		elif is_gem_currency(item_type, category) and item_data.has("cap"):
			configured_stack_limit = int(item_data.get("cap", configured_stack_limit))

		if not bool(item_data.get("stackable", true)):
			return 1

	var final_limit = configured_stack_limit
	if final_limit < 1:
		final_limit = 1
	return int(clamp(final_limit, 1, MAX_ITEM_STACK_SIZE))


func is_fishing_rod_item(item_type: String) -> bool:
	var safe_item_type := str(item_type)
	if safe_item_type == FISHING_ROD_ID:
		return true
	if item_database.has(safe_item_type):
		return bool(item_database[safe_item_type].get("fishing_rod", false))
	return false


func clamp_item_stack_count(item_type: String, category: String, count: int) -> int:
	return int(clamp(count, 0, get_stack_limit_for_item(item_type, category)))


func notify_inventory_item_changed(item_type: String, category: String, source: String = "local") -> void:
	var clean_item_type := str(item_type).strip_edges()
	var clean_category := str(category).strip_edges().to_lower()
	if clean_item_type == "" or clean_category == "":
		return
	if inventory_manager == null:
		return
	if inventory_manager.has_method("notify_inventory_item_changed"):
		inventory_manager.notify_inventory_item_changed(clean_item_type, clean_category, source)
	elif inventory_manager.has_method("refresh_inventory_item_live"):
		inventory_manager.refresh_inventory_item_live(clean_item_type, clean_category)
	elif inventory_manager.has_method("refresh_inventory_window_live"):
		inventory_manager.refresh_inventory_window_live()


func get_equipped_property_for_inventory_category(category: String) -> String:
	match str(category).strip_edges().to_lower():
		"tool":
			return "equipped_tool"
		"back":
			return "equipped_back_item"
		"hat":
			return "equipped_hat_item"
		"hair":
			return "equipped_hair_item"
		"eyewear":
			return "equipped_eyewear_item"
		"shirt":
			return "equipped_shirt_item"
		"pants":
			return "equipped_pants_item"
		"shoes":
			return "equipped_shoes_item"
		"ride":
			return "equipped_ride_item"
		_:
			return ""


func clear_equipped_item_if_inventory_empty(item_type: String, category: String, count: int) -> bool:
	if count > 0:
		return false

	var clean_item_type := str(item_type).strip_edges()
	var clean_category := str(category).strip_edges().to_lower()
	if clean_item_type == "" or clean_category == "":
		return false

	var equipped_property := get_equipped_property_for_inventory_category(clean_category)
	if equipped_property == "":
		return false

	if str(get(equipped_property)).strip_edges() != clean_item_type:
		return false

	set(equipped_property, "")
	if clean_category == "tool" and item_gameplay_manager != null and item_gameplay_manager.has_method("hide_electrical_layer_if_tool_not_equipped"):
		item_gameplay_manager.hide_electrical_layer_if_tool_not_equipped()
	update_equipment_visual()
	update_all_ui()
	if save_manager != null and save_manager.has_method("save_player_data"):
		save_manager.save_player_data(false)
	flush_multiplayer_position(false, true)
	return true


func add_item_to_inventory_stack(target_inventory: Dictionary, item_type: String, category: String, amount: int) -> int:
	var current_count = max(0, int(target_inventory.get(item_type, 0)))
	var safe_amount = max(0, amount)
	var next_count = clamp_item_stack_count(item_type, category, current_count + safe_amount)
	target_inventory[item_type] = next_count
	if next_count != current_count:
		notify_inventory_item_changed(item_type, category)
	return next_count - current_count


func spend_item_from_inventory_stack(target_inventory: Dictionary, item_type: String, category: String, amount: int) -> bool:
	var safe_amount = max(0, amount)
	var current_count = max(0, int(target_inventory.get(item_type, 0)))
	if current_count < safe_amount:
		return false
	var next_count = clamp_item_stack_count(item_type, category, current_count - safe_amount)
	target_inventory[item_type] = next_count
	if next_count != current_count:
		notify_inventory_item_changed(item_type, category)
	return true


func parse_network_inventory_count(value, fallback: int, min_value: int = 0, max_value: int = MAX_ITEM_STACK_SIZE) -> int:
	if value is int:
		return clamp(value, min_value, max_value)
	if value is float:
		if not is_finite(float(value)):
			return fallback
		return clamp(int(value), min_value, max_value)
	if value is String:
		var text = value.strip_edges()
		if text.is_valid_int():
			return clamp(int(text), min_value, max_value)
	return fallback


func resolve_network_inventory_delta_category(item_type: String, category: String) -> String:
	var clean_category = str(category).strip_edges().to_lower()
	if clean_category != "":
		return clean_category
	if item_database.has(item_type):
		return str(item_database[item_type].get("category", "")).strip_edges().to_lower()
	return ""


func apply_network_inventory_delta(delta: Dictionary) -> bool:
	if delta.is_empty():
		return false

	var item_type = str(delta.get("item_id", delta.get("item_type", ""))).strip_edges()
	if item_type == "" or not item_database.has(item_type):
		return false

	var category = resolve_network_inventory_delta_category(item_type, str(delta.get("item_category", delta.get("category", ""))))
	var target_inventory: Dictionary
	match category:
		"block":
			target_inventory = inventory
		"seed":
			target_inventory = seed_inventory
		"tool":
			target_inventory = tool_inventory
		"back":
			target_inventory = back_inventory
		"hat":
			target_inventory = hat_inventory
		"hair":
			target_inventory = hair_inventory
		"eyewear":
			target_inventory = eyewear_inventory
		"shirt":
			target_inventory = shirt_inventory
		"pants":
			target_inventory = pants_inventory
		"shoes":
			target_inventory = shoes_inventory
		"ride":
			target_inventory = ride_inventory
		"currency":
			target_inventory = currency_inventory
		"material":
			target_inventory = material_inventory
		"lure":
			target_inventory = lure_inventory
		"fish":
			target_inventory = fish_inventory
		_:
			return false

	var stack_limit = get_stack_limit_for_item(item_type, category)
	var current_count = parse_network_inventory_count(target_inventory.get(item_type, 0), 0, 0, stack_limit)
	var after_count = parse_network_inventory_count(delta.get("after_count", delta.get("count", null)), -1, 0, stack_limit)
	if after_count < 0:
		var amount_delta = parse_network_inventory_count(delta.get("delta", delta.get("amount", 0)), 0, -stack_limit, stack_limit)
		after_count = clamp(current_count + amount_delta, 0, stack_limit)

	var next_count = clamp_item_stack_count(item_type, category, after_count)
	target_inventory[item_type] = next_count
	if category == "currency" and item_type == GEM_CURRENCY_ITEM_ID:
		normalize_gem_currency_state()
	var equipment_changed := clear_equipped_item_if_inventory_empty(item_type, category, next_count)
	if next_count != current_count:
		notify_inventory_item_changed(item_type, category, "server")
	elif equipment_changed:
		notify_inventory_item_changed(item_type, category, "server")
	return true


func apply_network_progression(progression_data: Dictionary) -> bool:
	if progression_data.is_empty():
		return false

	var changed := false
	if progression_data.has("level_after"):
		var next_level := parse_network_inventory_count(progression_data.get("level_after"), player_level, 1, 100)
		if next_level != player_level:
			player_level = next_level
			changed = true

	if progression_data.has("xp_after"):
		var next_xp := parse_network_inventory_count(progression_data.get("xp_after"), player_xp, 0, 2147483647)
		if next_xp != player_xp:
			player_xp = next_xp
			changed = true

	if progression_data.has("xp_needed"):
		var next_xp_needed := parse_network_inventory_count(progression_data.get("xp_needed"), player_xp_needed, 0, 2147483647)
		if next_xp_needed != player_xp_needed:
			player_xp_needed = next_xp_needed
			changed = true

	if progression_data.has("total_xp_after"):
		var next_total_xp := parse_network_inventory_count(progression_data.get("total_xp_after"), player_total_xp, 0, 2147483647)
		if next_total_xp != player_total_xp:
			player_total_xp = next_total_xp
			changed = true

	if progression_data.has("title"):
		var next_title = str(progression_data.get("title", player_title)).strip_edges()
		if next_title != "" and next_title != player_title:
			player_title = next_title
			changed = true

	if changed:
		update_all_ui()

	return changed


func format_currency_amount(value: int) -> String:
	var digits = str(max(0, value))
	var result = ""
	var group_count = 0

	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1

	return result


func get_currency_display_text(item_type: String = GEM_CURRENCY_ITEM_ID) -> String:
	var category = "currency"
	var count = int(currency_inventory.get(item_type, 0))
	return format_currency_amount(clamp_item_stack_count(item_type, category, count))


func normalize_gem_currency_state():
	if currency_inventory.has(GEM_CURRENCY_ITEM_ID):
		currency_inventory[GEM_CURRENCY_ITEM_ID] = clamp_item_stack_count(GEM_CURRENCY_ITEM_ID, "currency", int(currency_inventory[GEM_CURRENCY_ITEM_ID]))


func normalize_inventory_slot_count(value) -> int:
	var parsed := INVENTORY_MIN_SLOT_COUNT
	if value is int:
		parsed = int(value)
	elif value is float:
		if is_finite(float(value)):
			parsed = int(value)
	elif value is String:
		var text: String = str(value).strip_edges()
		if text.is_valid_int():
			parsed = int(text)
		elif text.is_valid_float():
			parsed = int(float(text))

	var clamped_value: int = clampi(parsed, INVENTORY_MIN_SLOT_COUNT, INVENTORY_MAX_SLOT_COUNT)
	if clamped_value <= INVENTORY_MIN_SLOT_COUNT:
		return INVENTORY_MIN_SLOT_COUNT

	var upgrade_steps: int = int(ceil(float(clamped_value - INVENTORY_MIN_SLOT_COUNT) / float(INVENTORY_SLOT_UPGRADE_STEP)))
	return clampi(INVENTORY_MIN_SLOT_COUNT + upgrade_steps * INVENTORY_SLOT_UPGRADE_STEP, INVENTORY_MIN_SLOT_COUNT, INVENTORY_MAX_SLOT_COUNT)


func apply_inventory_slot_count(value, refresh_ui: bool = true) -> bool:
	var next_count: int = normalize_inventory_slot_count(value)
	var changed: bool = next_count != inventory_slot_count
	inventory_slot_count = next_count
	if changed and refresh_ui and inventory_manager != null:
		if inventory_manager.has_method("mark_inventory_window_structure_dirty"):
			inventory_manager.mark_inventory_window_structure_dirty()
		if inventory_manager.has_method("refresh_inventory_window_live"):
			inventory_manager.refresh_inventory_window_live()
		elif inventory_manager.has_method("update_inventory_window"):
			inventory_manager.update_inventory_window()
	return changed


func get_inventory_slot_count() -> int:
	inventory_slot_count = normalize_inventory_slot_count(inventory_slot_count)
	return inventory_slot_count


func get_inventory_upgrade_cost_for_slot_count(slot_count: int = -1) -> int:
	var current_slots: int = get_inventory_slot_count() if slot_count < 0 else normalize_inventory_slot_count(slot_count)
	var upgrade_index: int = floori(float(current_slots - INVENTORY_MIN_SLOT_COUNT) / float(INVENTORY_SLOT_UPGRADE_STEP))
	if upgrade_index < 0 or upgrade_index >= INVENTORY_SLOT_UPGRADE_COSTS.size():
		return 0
	return int(INVENTORY_SLOT_UPGRADE_COSTS[upgrade_index])


func get_inventory_upgrade_preview() -> Dictionary:
	var current_slots: int = get_inventory_slot_count()
	var next_slots: int = INVENTORY_MAX_SLOT_COUNT if current_slots >= INVENTORY_MAX_SLOT_COUNT else normalize_inventory_slot_count(current_slots + INVENTORY_SLOT_UPGRADE_STEP)
	var cost: int = 0 if current_slots >= INVENTORY_MAX_SLOT_COUNT else get_inventory_upgrade_cost_for_slot_count(current_slots)
	return {
		"inventory_slot_count": current_slots,
		"current_slots": current_slots,
		"next_inventory_slot_count": next_slots,
		"next_slots": next_slots,
		"inventory_upgrade_cost": cost,
		"cost": cost,
		"max_slots": INVENTORY_MAX_SLOT_COUNT,
		"step": INVENTORY_SLOT_UPGRADE_STEP
	}


func request_inventory_slot_upgrade() -> bool:
	if get_inventory_slot_count() >= INVENTORY_MAX_SLOT_COUNT:
		show_notification("Inventory is already fully upgraded.")
		return false
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_inventory_upgrade_purchase_request"):
		show_notification("Connection required for inventory upgrades.")
		return false
	return bool(network.send_inventory_upgrade_purchase_request(get_inventory_upgrade_preview()))


func load_texture_spec(texture_spec) -> Texture2D:
	return AtlasTextureFactory.load_texture(texture_spec)


func load_item_texture_spec(item_data: Dictionary, texture_key: String = "texture") -> Texture2D:
	if not item_data.has(texture_key):
		return null

	return load_texture_spec(item_data.get(texture_key))


func load_texture_spec_list(texture_specs: Array) -> Array[Texture2D]:
	return AtlasTextureFactory.load_texture_list(texture_specs)


func make_coloured_block_drop_rules(block_id: String, seed_id: String, gem_max: int) -> Dictionary:
	return {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{"item_id": block_id, "item_category": "block", "amount_range": [1, 3]},
			{"item_id": seed_id, "item_category": "seed", "amount_range": [0, 2]},
			{"item_id": GEM_CURRENCY_ITEM_ID, "item_category": "currency", "amount_range": [0, gem_max]}
		]
	}


func make_configured_seed_drop_rules(block_id: String, seed_id: String, block_chance: float, seed_chance: float, gem_range: Array = [], block_range: Array = [], seed_range: Array = []) -> Dictionary:
	var fixed_drops := []
	if block_range.size() >= 2:
		fixed_drops.append({"item_id": block_id, "item_category": "block", "amount_range": block_range})
	else:
		fixed_drops.append({"item_id": block_id, "item_category": "block", "amount": 1, "chance": clamp(block_chance, 0.0, 1.0)})
	if seed_range.size() >= 2:
		fixed_drops.append({"item_id": seed_id, "item_category": "seed", "amount_range": seed_range})
	else:
		fixed_drops.append({"item_id": seed_id, "item_category": "seed", "amount": 1, "chance": clamp(seed_chance, 0.0, 1.0)})
	if gem_range.size() >= 2:
		fixed_drops.append({"item_id": GEM_CURRENCY_ITEM_ID, "item_category": "currency", "amount_range": gem_range})
	return {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": fixed_drops
	}


func make_configured_tree_drop_rules(block_id: String, seed_id: String, block_range: Array, seed_range: Array, gem_range: Array = []) -> Dictionary:
	var fixed_drops := [
		{"item_id": block_id, "item_category": "block", "amount_range": block_range},
		{"item_id": seed_id, "item_category": "seed", "amount_range": seed_range}
	]
	if gem_range.size() >= 2:
		fixed_drops.append({"item_id": GEM_CURRENCY_ITEM_ID, "item_category": "currency", "amount_range": gem_range})
	return {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": fixed_drops
	}


func apply_tier_1_splice_balance():
	for block_id in tier_1_splice_balance.keys():
		if not item_database.has(block_id):
			continue
		if not (item_database[block_id] is Dictionary):
			continue

		var block_data: Dictionary = item_database[block_id]
		var raw_balance = tier_1_splice_balance[block_id]
		if not (raw_balance is Dictionary):
			continue
		var balance: Dictionary = raw_balance as Dictionary

		var seed_id := str(block_data.get("seed", "")).strip_edges()
		if seed_id == "":
			seed_id = str(block_id) + "_seed"

		block_data["seed"] = seed_id
		block_data["drop_rules"] = make_configured_seed_drop_rules(
			str(block_id),
			seed_id,
			float(balance.get("block_drop_chance", 1.0)),
			float(balance.get("seed_drop_chance", 1.0)),
			balance.get("break_gem_range", []),
			balance.get("break_block_range", []),
			balance.get("break_seed_range", [])
		)
		block_data["tree_drop_rules"] = make_configured_tree_drop_rules(
			str(block_id),
			seed_id,
			balance.get("tree_block_range", [1, 1]),
			balance.get("tree_seed_range", [0, 0]),
			balance.get("tree_gem_range", [])
		)

		var seed_data: Dictionary = {}
		if item_database.has(seed_id) and item_database[seed_id] is Dictionary:
			seed_data = item_database[seed_id]
		else:
			seed_data = {
				"category": "seed",
				"display_name": str(block_data.get("display_name", str(block_id).capitalize())) + " Seed",
				"rarity": str(block_data.get("rarity", "common")),
				"texture": SEED_BOX_TEXTURE_PATH,
				"seed_box_icon": true,
				"grows_into": str(block_id),
				"order": int(block_data.get("order", 9999))
			}
			item_database[seed_id] = seed_data

		seed_data["grows_into"] = str(block_id)
		seed_data["max_grow_time"] = float(balance.get("grow_time", SEED_GROW_TIME))
		seed_data["grow_time"] = float(balance.get("grow_time", SEED_GROW_TIME))
		seed_data["seed_box_icon"] = true


func apply_coloured_block_seed_and_drop_rules():
	for block_id in COLOURED_BLOCK_IDS:
		if not item_database.has(block_id):
			continue
		if not (item_database[block_id] is Dictionary):
			continue

		var block_data: Dictionary = item_database[block_id]
		var seed_id: String = str(block_data.get("seed", "")).strip_edges()
		if seed_id == "":
			seed_id = str(block_id) + "_seed"

		block_data["seed"] = seed_id
		block_data["drop_rules"] = make_coloured_block_drop_rules(str(block_id), seed_id, 4)
		block_data["tree_drop_rules"] = make_coloured_block_drop_rules(str(block_id), seed_id, 5)


func ensure_seed_item_definitions_from_blocks():
	var generated_seed_items: Dictionary = {}

	for block_id in item_database.keys():
		var block_data = item_database[block_id]
		if not (block_data is Dictionary):
			continue
		if str(block_data.get("category", "")) != "block":
			continue

		var seed_id: String = str(block_data.get("seed", "")).strip_edges()
		if seed_id == "":
			continue

		if not item_database.has(seed_id):
			generated_seed_items[seed_id] = {
				"category": "seed",
				"display_name": str(block_data.get("display_name", str(block_id).capitalize())) + " Seed",
				"rarity": str(block_data.get("rarity", "common")),
				"texture": SEED_BOX_TEXTURE_PATH,
				"seed_box_icon": true,
				"grows_into": str(block_id),
				"order": int(block_data.get("order", 9999))
			}
		elif item_database[seed_id] is Dictionary:
			var existing_seed_data: Dictionary = item_database[seed_id]
			if str(existing_seed_data.get("category", "")) == "seed":
				if str(existing_seed_data.get("grows_into", "")).strip_edges() == "":
					existing_seed_data["grows_into"] = str(block_id)
				if str(existing_seed_data.get("display_name", "")).strip_edges() == "":
					existing_seed_data["display_name"] = str(block_data.get("display_name", str(block_id).capitalize())) + " Seed"

	for seed_id in generated_seed_items.keys():
		item_database[seed_id] = generated_seed_items[seed_id]

	for item_id in item_database.keys():
		var item_data = item_database[item_id]
		if item_data is Dictionary and str(item_data.get("category", "")) == "seed":
			item_data["texture"] = SEED_BOX_TEXTURE_PATH
			item_data["seed_box_icon"] = true
			item_data.erase("inventory_icon")


func get_seed_icon_texture(seed_type: String):
	return get_seed_box_composite_texture(seed_type, seed_icon_texture_cache)


func get_seed_drop_icon_texture(seed_type: String):
	return get_seed_box_texture(seed_type, seed_drop_icon_texture_cache)


func get_seed_box_texture(seed_type: String, cache: Dictionary):
	var clean_seed_type: String = seed_type.strip_edges()
	if clean_seed_type == "":
		return null

	if cache.has(clean_seed_type):
		return cache[clean_seed_type]

	var seed_box_texture: Texture2D = load_texture_spec(SEED_BOX_TEXTURE_PATH)
	if seed_box_texture == null:
		return null

	cache[clean_seed_type] = seed_box_texture
	return seed_box_texture


func get_seed_icon_preview_layout(seed_type: String) -> Dictionary:
	return get_seed_drop_preview_layout(seed_type)


func get_seed_drop_preview_layout(seed_type: String) -> Dictionary:
	return get_seed_box_preview_layout(
		seed_type,
		SEED_DROP_ICON_PREVIEW_MAX_SIZE,
		SEED_DROP_ICON_PREVIEW_TOP,
		SEED_DROP_ICON_PREVIEW_OFFSET
	)


func get_seed_box_preview_layout(seed_type: String, preview_max_size: int, preview_top: int, preview_offset: Vector2i) -> Dictionary:
	var clean_seed_type: String = seed_type.strip_edges()
	if clean_seed_type == "":
		return {}

	var seed_box_texture: Texture2D = load_texture_spec(SEED_BOX_TEXTURE_PATH)
	if seed_box_texture == null:
		return {}

	var block_type: String = get_seed_preview_block_type(clean_seed_type)
	var block_texture: Texture2D = get_seed_preview_block_texture(block_type)
	if block_texture == null:
		return {}

	var box_size := Vector2i(seed_box_texture.get_width(), seed_box_texture.get_height())
	var preview_size: Vector2i = get_seed_icon_preview_size(
		Vector2i(block_texture.get_width(), block_texture.get_height()),
		preview_max_size
	)
	var destination: Vector2i = Vector2i(
		int(round(float(box_size.x - preview_size.x) * 0.5)),
		preview_top + int(round(float(preview_max_size - preview_size.y) * 0.5))
	) + preview_offset
	destination.x = clampi(destination.x, 0, max(0, box_size.x - preview_size.x))
	destination.y = clampi(destination.y, 0, max(0, box_size.y - preview_size.y))

	return {
		"box_texture": seed_box_texture,
		"box_size": box_size,
		"preview_texture": block_texture,
		"preview_size": preview_size,
		"destination": destination,
		"block_type": block_type
	}


func get_seed_box_composite_texture(seed_type: String, cache: Dictionary) -> Texture2D:
	var clean_seed_type: String = seed_type.strip_edges()
	if clean_seed_type == "":
		return null

	if cache.has(clean_seed_type):
		var cached_texture = cache[clean_seed_type]
		if cached_texture is Texture2D:
			return cached_texture

	var layout := get_seed_drop_preview_layout(clean_seed_type)
	var box_texture: Texture2D = layout.get("box_texture", null)
	if box_texture == null:
		box_texture = load_texture_spec(SEED_BOX_TEXTURE_PATH)
	if box_texture == null:
		return null

	var box_image := get_texture_region_image(box_texture)
	if box_image == null:
		cache[clean_seed_type] = box_texture
		return box_texture

	var preview_texture: Texture2D = layout.get("preview_texture", null)
	var preview_size: Vector2i = layout.get("preview_size", Vector2i.ZERO)
	var destination: Vector2i = layout.get("destination", Vector2i.ZERO)
	if preview_texture != null and preview_size.x > 0 and preview_size.y > 0:
		var preview_image := get_texture_region_image(preview_texture)
		if preview_image != null:
			preview_image.resize(preview_size.x, preview_size.y, Image.INTERPOLATE_NEAREST)
			box_image.blend_rect(
				preview_image,
				Rect2i(Vector2i.ZERO, preview_size),
				destination
			)

	var composite_texture := ImageTexture.create_from_image(box_image)
	cache[clean_seed_type] = composite_texture
	return composite_texture


func get_texture_region_image(texture: Texture2D) -> Image:
	if texture == null:
		return null

	var source_image: Image = null
	var source_origin := Vector2i.ZERO
	var source_size := Vector2i(max(1, int(texture.get_width())), max(1, int(texture.get_height())))
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas != null:
			source_image = atlas_texture.atlas.get_image()
			var region := atlas_texture.region
			if region.size.x > 0.0 and region.size.y > 0.0:
				source_origin = Vector2i(int(floor(region.position.x)), int(floor(region.position.y)))
				source_size = Vector2i(max(1, int(round(region.size.x))), max(1, int(round(region.size.y))))
	else:
		source_image = texture.get_image()

	if source_image == null or source_size.x <= 0 or source_size.y <= 0:
		return null

	var working_image := source_image.duplicate()
	if working_image.is_compressed():
		var decompress_error: int = working_image.decompress()
		if decompress_error != OK:
			return null
	if working_image.get_format() != Image.FORMAT_RGBA8:
		working_image.convert(Image.FORMAT_RGBA8)

	var full_size := Vector2i(working_image.get_width(), working_image.get_height())
	if source_origin == Vector2i.ZERO and source_size == full_size:
		return working_image

	var cropped_image := Image.create(source_size.x, source_size.y, false, Image.FORMAT_RGBA8)
	cropped_image.fill(Color(0, 0, 0, 0))
	cropped_image.blit_rect(
		working_image,
		Rect2i(source_origin, source_size),
		Vector2i.ZERO
	)
	return cropped_image


func get_seed_preview_block_type(seed_type: String) -> String:
	if item_database.has(seed_type) and item_database[seed_type] is Dictionary:
		var seed_data: Dictionary = item_database[seed_type]
		var grows_into: String = str(seed_data.get("grows_into", "")).strip_edges()
		if grows_into != "":
			return grows_into

	if seed_type.ends_with("_seed"):
		return seed_type.substr(0, seed_type.length() - "_seed".length())

	return ""


func get_seed_preview_block_texture(block_type: String) -> Texture2D:
	var clean_block_type: String = block_type.strip_edges()
	if clean_block_type == "":
		return null

	if not item_database.has(clean_block_type) or not (item_database[clean_block_type] is Dictionary):
		if block_textures.has(clean_block_type) and block_textures[clean_block_type] is Texture2D:
			return block_textures[clean_block_type]
		return null

	var block_data: Dictionary = item_database[clean_block_type]
	var block_texture: Texture2D = null
	var animation_frames = block_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 0:
		block_texture = load_texture_spec(animation_frames[0])

	if block_texture == null:
		block_texture = get_block_atlas_icon_texture(clean_block_type, block_data)

	if block_texture == null and block_textures.has(clean_block_type) and block_textures[clean_block_type] is Texture2D:
		return block_textures[clean_block_type]

	if block_texture == null:
		block_texture = load_item_texture_spec(block_data, "texture")

	if block_texture != null:
		block_textures[clean_block_type] = block_texture

	return block_texture


func get_block_atlas_icon_texture(block_type: String, block_data: Dictionary = {}) -> Texture2D:
	var clean_block_type := block_type.strip_edges()
	if clean_block_type == "":
		return null

	var item_data := block_data
	if item_data.is_empty() and item_database.has(clean_block_type) and item_database[clean_block_type] is Dictionary:
		item_data = item_database[clean_block_type]

	var atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(clean_block_type)))
	if atlas_item_id <= 0:
		return null

	return ITEM_ATLAS_DB.get_item_icon(atlas_item_id, get_item_atlas_tile_set())


func get_seed_icon_preview_size(source_size: Vector2i, preview_max_size: int = SEED_ICON_PREVIEW_MAX_SIZE) -> Vector2i:
	if source_size.x <= 0 or source_size.y <= 0:
		return Vector2i(preview_max_size, preview_max_size)

	var fit_scale: float = min(
		float(preview_max_size) / float(source_size.x),
		float(preview_max_size) / float(source_size.y)
	)

	return Vector2i(
		max(1, int(round(float(source_size.x) * fit_scale))),
		max(1, int(round(float(source_size.y) * fit_scale)))
	)


func uses_generated_seed_tree_texture(block_type: String) -> bool:
	return generated_seed_tree_texture_blocks.has(block_type.strip_edges())


func get_seed_growth_tree_textures(block_type: String) -> Array:
	var clean_block_type: String = block_type.strip_edges()
	if clean_block_type == "":
		return []

	var template_paths: Array = BG_TREE_TEMPLATE_PATHS if is_background_seed_growth_block(clean_block_type) else BLOCK_TREE_TEMPLATE_PATHS
	var generated_textures: Array = []

	for stage_index in range(template_paths.size()):
		var template_texture: Texture2D = load_texture_spec(template_paths[stage_index])
		if template_texture == null:
			generated_textures.clear()
			break

		var tree_texture: Texture2D = compose_seed_tree_texture(template_texture, stage_index, clean_block_type)
		if tree_texture == null:
			generated_textures.clear()
			break

		generated_textures.append(tree_texture)

	if generated_textures.size() > 0:
		generated_seed_tree_texture_blocks[clean_block_type] = true

	return generated_textures


func is_background_seed_growth_block(block_type: String) -> bool:
	if not item_database.has(block_type) or not (item_database[block_type] is Dictionary):
		return false

	var item_data: Dictionary = item_database[block_type]
	if bool(item_data.get("background_block", false)):
		return true

	return str(item_data.get("place_layer", "")).strip_edges().to_lower() == "background"


func compose_seed_tree_texture(template_texture: Texture2D, _stage_index: int, _block_type: String = "") -> Texture2D:
	return template_texture


func get_seed_tree_preview_positions(block_type: String, tree_size: Vector2i, preview_size: Vector2i) -> Array:
	var preview_positions: Array = []
	var position_pool: Array = SEED_TREE_MATURE_PREVIEW_POSITIONS.duplicate()
	if position_pool.is_empty():
		return preview_positions

	var rng = RandomNumberGenerator.new()
	var seed_key: String = block_type.strip_edges() + ":" + str(tree_size.x) + "x" + str(tree_size.y)
	var seed_value: int = seed_key.hash()
	if seed_value < 0:
		seed_value = -seed_value
	rng.seed = seed_value

	var preview_count: int = rng.randi_range(SEED_TREE_PREVIEW_MIN_COUNT, SEED_TREE_PREVIEW_MAX_COUNT)
	var max_x: int = max(0, tree_size.x - preview_size.x)
	var max_y: int = max(0, tree_size.y - preview_size.y)

	while preview_positions.size() < preview_count and not position_pool.is_empty():
		if position_pool.is_empty():
			break

		var pool_index: int = rng.randi_range(0, position_pool.size() - 1)
		var destination: Vector2i = position_pool[pool_index]
		position_pool.remove_at(pool_index)

		destination.x = clampi(destination.x, 0, max_x)
		destination.y = clampi(destination.y, 0, max_y)
		if not seed_tree_preview_position_overlaps(destination, preview_size, preview_positions):
			preview_positions.append(destination)

	return preview_positions


func seed_tree_preview_position_overlaps(destination: Vector2i, preview_size: Vector2i, existing_positions: Array) -> bool:
	for existing_destination in existing_positions:
		var existing: Vector2i = existing_destination
		var separated := (
			destination.x + preview_size.x + SEED_TREE_PREVIEW_GAP <= existing.x
			or existing.x + preview_size.x + SEED_TREE_PREVIEW_GAP <= destination.x
			or destination.y + preview_size.y + SEED_TREE_PREVIEW_GAP <= existing.y
			or existing.y + preview_size.y + SEED_TREE_PREVIEW_GAP <= destination.y
		)
		if not separated:
			return true

	return false


func load_seed_tree_texture_fallbacks(tree_paths) -> Array:
	var loaded_tree_textures: Array = []
	if not (tree_paths is Array):
		return loaded_tree_textures

	for tree_path in tree_paths:
		var tree_texture = load_texture_spec(tree_path)
		if tree_texture != null:
			loaded_tree_textures.append(tree_texture)

	return loaded_tree_textures


func normalize_world_lock_collision_metadata() -> void:
	for lock_id in ["world_lock", "super_world_lock"]:
		if not item_database.has(lock_id):
			continue
		var item_data: Dictionary = item_database.get(lock_id, {})
		item_data["collidable"] = true
		item_data["solid"] = true
		item_data["collision_type"] = "full"
		item_data["collision_size"] = Vector2i(32, 32)
		item_data["collision_offset"] = Vector2.ZERO
		item_database[lock_id] = item_data


func setup_item_database():
	inventory.clear()
	seed_inventory.clear()
	block_textures.clear()
	seed_textures.clear()
	seed_tree_textures.clear()
	seed_icon_texture_cache.clear()
	seed_drop_icon_texture_cache.clear()
	generated_seed_tree_texture_blocks.clear()
	tool_inventory.clear()
	back_inventory.clear()
	hat_inventory.clear()
	hair_inventory.clear()
	eyewear_inventory.clear()
	shirt_inventory.clear()
	pants_inventory.clear()
	shoes_inventory.clear()
	ride_inventory.clear()
	currency_inventory.clear()
	material_inventory.clear()
	lure_inventory.clear()
	fish_inventory.clear()
	tool_textures.clear()
	back_textures.clear()
	hat_textures.clear()
	hair_textures.clear()
	eyewear_textures.clear()
	shirt_textures.clear()
	pants_textures.clear()
	shoes_textures.clear()
	ride_textures.clear()
	currency_textures.clear()
	material_textures.clear()
	lure_textures.clear()
	fish_textures.clear()
	tool_items.clear()
	back_items.clear()
	hat_items.clear()
	hair_items.clear()
	eyewear_items.clear()
	shirt_items.clear()
	pants_items.clear()
	shoes_items.clear()
	ride_items.clear()
	material_items.clear()
	lure_items.clear()
	fish_items.clear()
	block_items.clear()

	# World Lock v1 runtime item injection. Later we can move this into item_database.gd permanently.
	if not item_database.has("world_lock"):
		item_database["world_lock"] = {
			"category": "block",
			"display_name": "World Lock",
			"rarity": "legendary",
			"block_health": 8,
			"texture": "res://Assets/locks/world_lock.png",
			"world_lock_access_texture": "res://Assets/locks/world_lock_access.png",
			"world_lock_no_access_texture": "res://Assets/locks/world_lock_no_access.png",
			"interaction_permission": "owner_only",
			"seed": "",
			"collidable": true,
			"solid": true,
			"collision_type": "full",
			"collision_size": Vector2i(32, 32),
			"collision_offset": Vector2.ZERO,
			"order": 900
		}
	if not item_database.has("super_world_lock"):
		item_database["super_world_lock"] = {
			"category": "block",
			"display_name": "Super World Lock",
			"rarity": "legendary",
			"block_health": 8,
			"texture": "res://Assets/locks/super_world_lock.png",
			"world_lock_access_texture": "res://Assets/locks/super_world_lock_access.png",
			"world_lock_no_access_texture": "res://Assets/locks/super_world_lock_no_access.png",
			"interaction_permission": "owner_only",
			"seed": "",
			"max_stack": 400,
			"collidable": true,
			"solid": true,
			"collision_type": "full",
			"collision_size": Vector2i(32, 32),
			"collision_offset": Vector2.ZERO,
			"order": 901
		}
	normalize_world_lock_collision_metadata()

	apply_coloured_block_seed_and_drop_rules()
	apply_tier_1_splice_balance()
	ensure_seed_item_definitions_from_blocks()

	for item_id in item_database.keys():
		var item_data = item_database[item_id]
		var category = str(item_data.get("category", ""))

		if category == "block":
			inventory[item_id] = 0

			if not bool(item_data.get("hidden", false)):
				block_items.append(item_id)

			var block_texture = get_block_atlas_icon_texture(str(item_id), item_data)
			if block_texture == null:
				block_texture = load_item_texture_spec(item_data)
			if block_texture != null:
				block_textures[item_id] = block_texture

		elif category == "seed":
			seed_inventory[item_id] = 0

			var seed_texture = get_seed_drop_icon_texture(item_id)
			if seed_texture != null:
				seed_textures[item_id] = seed_texture

			var grows_into = str(item_data.get("grows_into", ""))
			if grows_into != "":
				var loaded_tree_textures: Array = get_seed_growth_tree_textures(grows_into)
				if loaded_tree_textures.is_empty():
					loaded_tree_textures = load_seed_tree_texture_fallbacks(item_data.get("tree_textures", []))

				if loaded_tree_textures.size() > 0:
					seed_tree_textures[grows_into] = loaded_tree_textures

		elif category == "tool":
			tool_inventory[item_id] = int(item_data.get("starting_count", 0))
			tool_items.append(item_id)

			var tool_texture = load_item_texture_spec(item_data)
			if tool_texture != null:
				tool_textures[item_id] = tool_texture

		elif category == "back":
			back_inventory[item_id] = int(item_data.get("starting_count", 0))
			back_items.append(item_id)

			var back_texture = load_item_texture_spec(item_data)

			if back_texture != null:
				back_textures[item_id] = back_texture
			elif item_id == "legendary_wings":
				var fallback_back_paths = [
					"res://Assets/player/back_item/legendary_wings/legendary_wings_idle1.png",
					"res://Assets/player/back_item/legendary_wings/legendary_wings_idle2.png",
					"res://Assets/player/back_item/legendary_wings/legendary_wings_jump1.png",
					"res://Assets/player/back_item/legendary_wings/legendary_wings_jump2.png",
					"res://Assets/player/back_item/legendary_wings/legendary_wings_jump3.png"
				]

				for fallback_path in fallback_back_paths:
					if ResourceLoader.exists(fallback_path):
						back_textures[item_id] = load_texture_spec(fallback_path)
						break

		elif category == "hat":
			hat_inventory[item_id] = int(item_data.get("starting_count", 0))
			hat_items.append(item_id)

			var hat_texture = load_item_texture_spec(item_data)
			if hat_texture != null:
				hat_textures[item_id] = hat_texture

		elif category == "hair":
			hair_inventory[item_id] = int(item_data.get("starting_count", 0))
			hair_items.append(item_id)

			var hair_texture = load_item_texture_spec(item_data)
			if hair_texture != null:
				hair_textures[item_id] = hair_texture

		elif category == "eyewear":
			eyewear_inventory[item_id] = int(item_data.get("starting_count", 0))
			eyewear_items.append(item_id)

			var eyewear_texture = load_item_texture_spec(item_data)
			if eyewear_texture != null:
				eyewear_textures[item_id] = eyewear_texture

		elif category == "shirt":
			shirt_inventory[item_id] = int(item_data.get("starting_count", 0))
			shirt_items.append(item_id)

			var shirt_texture = load_item_texture_spec(item_data, "shirt_body_texture")
			if shirt_texture == null:
				shirt_texture = load_item_texture_spec(item_data, "body_texture")
			if shirt_texture == null:
				shirt_texture = load_item_texture_spec(item_data)
			if shirt_texture != null:
				shirt_textures[item_id] = shirt_texture

		elif category == "pants":
			pants_inventory[item_id] = int(item_data.get("starting_count", 0))
			pants_items.append(item_id)

			var pants_texture = load_item_texture_spec(item_data)
			if pants_texture != null:
				pants_textures[item_id] = pants_texture

		elif category == "shoes":
			shoes_inventory[item_id] = int(item_data.get("starting_count", 0))
			shoes_items.append(item_id)

			var shoes_texture = load_item_texture_spec(item_data)
			if shoes_texture != null:
				shoes_textures[item_id] = shoes_texture

		elif category == "ride":
			ride_inventory[item_id] = int(item_data.get("starting_count", 0))
			ride_items.append(item_id)

			var ride_texture = load_item_texture_spec(item_data)
			if ride_texture != null:
				ride_textures[item_id] = ride_texture

		elif category == "currency":
			currency_inventory[item_id] = clamp_item_stack_count(item_id, category, int(item_data.get("starting_count", 0)))

			var currency_texture = load_item_texture_spec(item_data)
			if currency_texture != null:
				currency_textures[item_id] = currency_texture

		elif category == "material":
			material_inventory[item_id] = int(item_data.get("starting_count", 0))
			material_items.append(item_id)

			var material_texture = load_item_texture_spec(item_data)
			if material_texture != null:
				material_textures[item_id] = material_texture

		elif category == "lure":
			lure_inventory[item_id] = int(item_data.get("starting_count", 0))
			lure_items.append(item_id)

			var lure_texture = load_item_texture_spec(item_data)
			if lure_texture != null:
				lure_textures[item_id] = lure_texture

		elif category == "fish":
			fish_inventory[item_id] = int(item_data.get("starting_count", 0))
			fish_items.append(item_id)

			var fish_texture = load_item_texture_spec(item_data)
			if fish_texture != null:
				fish_textures[item_id] = fish_texture

	block_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	tool_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	back_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	hat_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	hair_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	eyewear_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	shirt_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	pants_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	shoes_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	ride_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	material_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	lure_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	fish_items.sort_custom(Callable(self, "sort_item_ids_by_order"))

	var bedrock_texture = load_texture_spec("res://Assets/blocks/Tier_1/basic blocks/bedrock_block.png")
	if bedrock_texture != null:
		block_textures["bedrock"] = bedrock_texture


func sort_item_ids_by_order(a: String, b: String) -> bool:
	var order_a = 9999
	var order_b = 9999

	if item_database.has(a):
		order_a = int(item_database[a].get("order", 9999))

	if item_database.has(b):
		order_b = int(item_database[b].get("order", 9999))

	return order_a < order_b


func get_item_data(item_type: String) -> Dictionary:
	if item_database.has(item_type):
		return item_database[item_type]

	return {}


func get_item_drop_texture(item_type: String, item_category: String):
	if drop_manager != null and drop_manager.has_method("get_item_drop_texture"):
		return drop_manager.get_item_drop_texture(item_type, item_category)

	return null


func get_seed_for_block(block_type: String) -> String:
	if item_database.has(block_type):
		return str(item_database[block_type].get("seed", block_type + "_seed"))

	return block_type + "_seed"


@onready var inventory_label = get_node_or_null("../UI/InventoryLabel")
@onready var ui_layer = get_node_or_null("../UI")
@onready var player = get_node_or_null("../Player")


func ensure_player_draw_on_top():
	if player == null:
		return

	# Force the player and anything attached to the player (like tools)
	# to render above world blocks.
	player.z_as_relative = false
	player.z_index = LOCAL_PLAYER_Z_INDEX

	# Godot can still be setting up child nodes during _ready().
	# Run move_child later so it does not error.
	call_deferred("move_player_to_front")


func move_player_to_front():
	if player == null:
		return

	var parent_node = player.get_parent()

	if parent_node != null:
		parent_node.move_child(player, parent_node.get_child_count() - 1)


func _ready():
	if _is_custom_movement_world_export_launch():
		_run_custom_movement_world_export()
		return

	_load_item_database()
	setup_netfox_real_manager()
	setup_background_manager()
	setup_reach_indicator_manager()
	setup_sound_manager()
	setup_world_loading_ui_manager()
	show_pending_join_loading_overlay_early()
	setup_item_database()
	setup_drop_manager()
	setup_world_generation_manager()
	setup_block_manager()
	setup_electricity_manager()
	setup_particle_manager()
	setup_block_shadow_manager()
	setup_interaction_manager()
	setup_player_manager()
	setup_custom_authoritative_movement_manager()
	setup_gameplay_ui_manager()
	setup_ui_layers()
	setup_fishing_manager()
	setup_fish_monger_manager()
	setup_item_gameplay_manager()
	setup_vending_preview_manager()
	setup_environment_manager()
	setup_input_manager()
	setup_mobile_controls()
	setup_account_manager()
	setup_world_lock_manager()
	setup_area_lock_highlight_overlay()
	setup_world_state_sync_manager()
	setup_username_label_manager()
	update_username_label()
	setup_water_animation()
	setup_crack_textures()
	setup_seed_system()

	setup_equipment_manager()
	ensure_player_draw_on_top()
	setup_player_animation_manager()

	setup_inventory_manager()
	setup_save_manager()
	load_player_data()
	setup_command_manager()
	setup_chat_ui()
	setup_notification_ui()
	setup_player_menu_ui()
	setup_game_menu_ui()
	setup_friends_ui()
	setup_developer_panel_ui()
	setup_trade_ui()
	setup_vending_ui()
	setup_safe_ui()
	setup_donation_box_ui()
	setup_mailbox_ui()
	setup_bulletin_board_ui()
	setup_display_ui()
	setup_fish_monger_ui()
	setup_cctv_ui()
	setup_oil_refinery_ui()
	setup_battery_charger_ui()
	setup_generator_ui()
	setup_shop_ui()
	setup_crafting_ui()
	setup_furnace_ui()
	setup_sign_ui()
	setup_world_menu_ui()

	if _is_netfox_real_server_launch():
		_finish_netfox_real_server_startup()
	elif _is_custom_authoritative_server_launch():
		_finish_custom_authoritative_server_startup()
	elif _should_direct_enter_backend_dev_login_world():
		print("[BackendDevLogin] Session ready; entering trusted movement launch world directly.")
		call_deferred("_direct_enter_backend_dev_login_world")
	elif _should_start_backend_dev_login_from_world_scene():
		print("[BackendDevLogin] Trusted movement dev-login launch detected; skipping login/menu UI.")
		call_deferred("_run_backend_dev_login_and_enter_world")
	else:
		exit_to_main_menu(false)
	update_all_ui()


func show_pending_join_loading_overlay_early() -> void:
	var pending_world_name := get_pending_join_world_name_early()
	if pending_world_name == "":
		return
	if world_loading_ui_manager == null:
		return
	if not has_method("begin_smooth_world_load"):
		return

	pending_world_name = pending_world_name.to_upper()
	current_world_name = pending_world_name
	var network := get_node_or_null("/root/NetworkManager")
	if network != null and "current_world_name" in network:
		network.set("current_world_name", pending_world_name)
	begin_smooth_world_load(pending_world_name, true)
	update_smooth_world_load_message("Loading " + pending_world_name + "...")


func get_pending_join_world_name_early() -> String:
	var network := get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("has_pending_join") and bool(network.has_pending_join()):
		var pending_network_world := str(network.get("pending_join_world_name")).strip_edges()
		if pending_network_world != "":
			return pending_network_world

	var cfg := ConfigFile.new()
	if cfg.load(LOBBY_PROFILE_PATH) != OK:
		return ""

	if not bool(cfg.get_value("pending_join", "enabled", false)):
		return ""

	var pending_world_name := str(cfg.get_value("pending_join", "world_name", "")).strip_edges()
	if pending_world_name != "":
		return pending_world_name

	return str(cfg.get_value("profile", "last_world", "")).strip_edges()


func _is_custom_movement_world_export_launch() -> bool:
	return _custom_movement_all_args().has("--custom-export-generated-world")


func _run_custom_movement_world_export() -> void:
	var export_world_name := _safe_custom_export_world_name(_custom_movement_get_arg_value("--world", "TEST"), "TEST")
	current_world_name = export_world_name
	in_world = true

	_load_item_database()
	setup_item_database()
	setup_background_manager()
	setup_environment_manager()
	setup_world_generation_manager()
	setup_block_manager()

	blocks.clear()
	terrain_surface_y.clear()
	if block_manager != null and "background_blocks" in block_manager:
		block_manager.background_blocks.clear()

	generate_world()

	var payload := _build_custom_movement_generated_world_payload(export_world_name)
	var written_paths: Array = []
	for path in _custom_movement_export_paths(export_world_name):
		if _write_custom_movement_world_payload(path, payload):
			written_paths.append(path)

	print("[CustomMovementWorldExport] generated world=%s blocks=%d background=%d paths=%s" % [
		export_world_name,
		int(payload.get("blocks", []).size()),
		int(payload.get("background_blocks", []).size()),
		str(written_paths),
	])
	get_tree().quit()


func _build_custom_movement_generated_world_payload(export_world_name: String) -> Dictionary:
	var foreground_blocks: Array = []
	var foreground_item_map: Dictionary = {}
	for grid_pos in blocks.keys():
		var block_data = blocks[grid_pos]
		if not (block_data is Dictionary):
			continue
		var block_type := str(block_data.get("type", "air"))
		var atlas_item_id := int(block_data.get("item_id", 0))
		if atlas_item_id <= 0 and item_database.has(block_type):
			atlas_item_id = int(item_database[block_type].get("atlas_item_id", 0))
		if atlas_item_id <= 0:
			atlas_item_id = ITEM_ATLAS_DB.get_item_id_for_key(block_type)
		if atlas_item_id > 0:
			foreground_item_map[str(grid_pos.x) + "," + str(grid_pos.y)] = atlas_item_id
		foreground_blocks.append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"type": block_type,
			"item_id": atlas_item_id,
			"entrance_locked": bool(block_data.get("entrance_locked", false)),
			"sign_text": str(block_data.get("sign_text", "")),
			"toggle_on": bool(block_data.get("toggle_on", false)),
			"door_name": str(block_data.get("door_name", block_data.get("name", ""))),
		})

	var background_blocks: Array = []
	var background_item_map: Dictionary = {}
	var background_source: Dictionary = {}
	if block_manager != null and "background_blocks" in block_manager:
		background_source = block_manager.background_blocks
	for grid_pos in background_source.keys():
		var block_data = background_source[grid_pos]
		if not (block_data is Dictionary):
			continue
		var background_type := str(block_data.get("type", "air"))
		var background_item_id := int(block_data.get("item_id", 0))
		if background_item_id <= 0 and item_database.has(background_type):
			background_item_id = int(item_database[background_type].get("atlas_item_id", 0))
		if background_item_id <= 0:
			background_item_id = ITEM_ATLAS_DB.get_item_id_for_key(background_type)
		if background_item_id > 0:
			background_item_map[str(grid_pos.x) + "," + str(grid_pos.y)] = background_item_id
		background_blocks.append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"type": background_type,
			"item_id": background_item_id
		})

	var spawn_position := _get_custom_movement_generated_spawn_position()
	return {
		"world_version": WORLD_VERSION,
		"world_name": export_world_name,
		"world_width": WORLD_WIDTH,
		"world_height": WORLD_HEIGHT,
		"player_x": spawn_position.x,
		"player_y": spawn_position.y,
		"blocks": foreground_blocks,
		"background_blocks": background_blocks,
		"foreground": foreground_item_map,
		"background": background_item_map,
		"item_drops": [],
		"planted_seeds": [],
	}


func _get_custom_movement_generated_spawn_position() -> Vector2:
	var spawn_surface_y := SURFACE_Y
	if terrain_surface_y.has(SPAWN_GRID_X):
		spawn_surface_y = int(terrain_surface_y[SPAWN_GRID_X])
	elif world_generation_manager != null and world_generation_manager.has_method("get_surface_y_at_x"):
		spawn_surface_y = int(world_generation_manager.get_surface_y_at_x(SPAWN_GRID_X))
	return Vector2(float(SPAWN_GRID_X * BLOCK_SIZE), float((spawn_surface_y - 2) * BLOCK_SIZE))


func _write_custom_movement_world_payload(path: String, payload: Dictionary) -> bool:
	var base_dir := path.get_base_dir()
	if base_dir.begins_with("user://"):
		var user_dir := DirAccess.open("user://")
		if user_dir != null:
			user_dir.make_dir_recursive(base_dir.replace("user://", ""))
	elif base_dir.begins_with("res://"):
		var absolute_dir := ProjectSettings.globalize_path(base_dir)
		DirAccess.make_dir_recursive_absolute(absolute_dir)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[CustomMovementWorldExport] Could not write %s" % path)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func _custom_movement_export_paths(export_world_name: String) -> Array:
	var file_stem := _custom_movement_world_file_stem(export_world_name)
	return [
		"user://worlds/%s.json" % file_stem,
		"res://backend/worlds/%s.json" % export_world_name.to_upper(),
	]


func _custom_movement_world_file_stem(world_name: String) -> String:
	var clean := world_name.strip_edges().to_lower()
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	return result if result != "" else "test"


func _safe_custom_export_world_name(raw_world_name: String, default_value: String) -> String:
	var clean := raw_world_name.strip_edges()
	if clean == "":
		clean = default_value
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	return result.to_upper() if result != "" else default_value.to_upper()


func _custom_movement_all_args() -> Array:
	var args: Array = []
	for arg in OS.get_cmdline_args():
		args.append(str(arg))
	for arg in OS.get_cmdline_user_args():
		var clean_arg := str(arg)
		if not args.has(clean_arg):
			args.append(clean_arg)
	return args


func _custom_movement_get_arg_value(flag_name: String, default_value: String) -> String:
	var args := _custom_movement_all_args()
	for i in range(args.size()):
		var arg := str(args[i])
		if arg == flag_name and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with(flag_name + "="):
			return arg.substr(flag_name.length() + 1)
	return default_value


func _load_item_database():
	var item_database_script = load(ITEM_DATABASE_PATH)

	if item_database_script == null:
		push_error("Could not load item database script at %s" % ITEM_DATABASE_PATH)
		item_database = {}
		splice_recipes = {}
		tier_1_splice_balance = {}
		return

	ITEM_ATLAS_DB.reload()
	item_database = item_database_script.ITEMS.duplicate(true)
	item_database = ITEM_ATLAS_DB.merge_item_database(item_database)
	splice_recipes = item_database_script.SPLICE_RECIPES
	tier_1_splice_balance = item_database_script.TIER_1_SPLICE_BALANCE.duplicate(true)


func _refresh_item_atlas_visuals_after_change() -> void:
	if not in_world:
		item_atlas_refresh_pending = false
		return

	ITEM_ATLAS_DB.reload()
	_load_item_database()
	if block_manager != null and block_manager.has_method("finalize_world_load_block_variants"):
		await block_manager.finalize_world_load_block_variants()
	item_atlas_refresh_pending = false


func _process(delta):
	if not in_world:
		return

	update_smooth_world_load_timeout()
	if is_smooth_world_load_waiting_for_server_state():
		return

	if not item_atlas_refresh_pending and ITEM_ATLAS_DB.has_source_changed():
		item_atlas_refresh_pending = true
		call_deferred("_refresh_item_atlas_visuals_after_change")

	update_chat_typing_movement_lock()
	update_player_facing_direction()
	update_player_animation(delta)
	update_noclip_movement(delta)
	update_equipment_visual()
	update_back_item_jump_reset()
	clamp_player_to_world()
	update_checkpoint_contact()
	update_auto_door_entry(get_player_grid_position())
	check_lava_damage(delta)
	update_item_drops(delta)
	update_planted_seeds(delta)
	update_red_tractor_auto_harvest()
	update_block_damage_recovery(delta)
	update_sign_hover_visibility()
	update_water_animation(delta)
	update_fishing(delta)
	update_multiplayer_movement(delta)
	process_multiplayer_remote_visuals(delta)
	update_fast_block_place_hold(delta)


func _physics_process(delta):
	if not in_world:
		return
	if not MovementMode.is_websocket():
		return
	if player_manager == null:
		return

	# Remote player interpolation is configured to update from physics ticks.
	# Without this call, remote roots only receive snapshots but do not advance
	# smoothly every physics frame, which can make other players feel delayed/frozen.
	if player_manager.has_method("update_remote_player_positions_from_physics"):
		player_manager.update_remote_player_positions_from_physics(delta)


func setup_world_loading_overlay():
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("setup_overlay"):
		world_loading_ui_manager.setup_overlay()


func begin_smooth_world_load(world_name: String, wait_for_server_state: bool = true):
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("begin_smooth_world_load"):
		world_loading_ui_manager.begin_smooth_world_load(world_name, wait_for_server_state)


func update_smooth_world_load_message(message: String):
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("update_message"):
		world_loading_ui_manager.update_message(message)


func is_smooth_world_load_visible() -> bool:
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("is_overlay_visible"):
		return bool(world_loading_ui_manager.is_overlay_visible())

	return false


func is_smooth_world_load_waiting_for_server_state() -> bool:
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("is_waiting_for_server_state"):
		return bool(world_loading_ui_manager.is_waiting_for_server_state())

	return false


func finish_smooth_world_load():
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("finish_smooth_world_load"):
		world_loading_ui_manager.finish_smooth_world_load()


func cancel_smooth_world_load():
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("cancel_smooth_world_load"):
		world_loading_ui_manager.cancel_smooth_world_load()


func update_smooth_world_load_timeout():
	if world_loading_ui_manager != null and world_loading_ui_manager.has_method("update_timeout"):
		world_loading_ui_manager.update_timeout()


func trace_fast_block_place_event(event: String, data: Dictionary = {}) -> void:
	if block_manager == null:
		return
	if block_manager.has_method("trace_authoritative_place_event"):
		block_manager.trace_authoritative_place_event("fast_place_" + event, data)



func can_fast_block_place_item(item_type: String, category: String, require_count: bool = true) -> bool:
	var clean_category := str(category).strip_edges().to_lower()
	var clean_item := str(item_type).strip_edges()
	if clean_category != "block":
		return false
	if clean_item == "" or clean_item == "punch":
		return false
	if not inventory.has(clean_item):
		return false
	if require_count and int(inventory.get(clean_item, 0)) <= 0:
		return false
	if item_database.has(clean_item):
		var item_data = item_database[clean_item]
		if item_data is Dictionary:
			if not bool(item_data.get("placeable", true)):
				return false
			# Optional per-item escape hatch for future special blocks.
			if bool(item_data.get("disable_fast_place", false)):
				return false
	return true


func is_fast_block_place_selected_item() -> bool:
	return can_fast_block_place_item(str(selected_item_type), str(selected_item_category), true)


func restore_fast_block_place_selection_if_auto_switched() -> void:
	if not fast_block_place_hold_active:
		return
	var manual_hotbar_selection_msec := int(get_meta("manual_hotbar_selection_msec", 0))
	if manual_hotbar_selection_msec > 0 and Time.get_ticks_msec() - manual_hotbar_selection_msec < 500:
		end_fast_block_place_hold(fast_block_place_hold_touch_index)
		return
	if fast_block_place_last_item_type == "" or fast_block_place_last_item_category == "":
		return
	if str(selected_item_type) == fast_block_place_last_item_type and str(selected_item_category) == fast_block_place_last_item_category:
		return
	# Do not restore a depleted stack. When the held stack hits 0, normal hotbar
	# normalization should switch the player back to slot 1.
	if not can_fast_block_place_item(fast_block_place_last_item_type, fast_block_place_last_item_category, true):
		end_fast_block_place_hold(fast_block_place_hold_touch_index)
		return

	var current_item := str(selected_item_type).strip_edges().to_lower()
	var current_category := str(selected_item_category).strip_edges().to_lower()
	var primary_tool := "punch"
	if has_method("get_primary_hotbar_tool"):
		primary_tool = str(get_primary_hotbar_tool()).strip_edges().to_lower()
	var looks_like_hotbar_auto_reset := current_category == "tool" and (current_item == "" or current_item == "punch" or current_item == "wrench" or current_item == primary_tool)
	if not looks_like_hotbar_auto_reset:
		return

	selected_item_type = fast_block_place_last_item_type
	selected_item_category = fast_block_place_last_item_category
	refresh_hotbar_live()


func should_start_fast_block_place_hold(screen_position: Vector2) -> bool:
	if not in_world:
		return false
	if is_movement_locked():
		return false
	if not is_fast_block_place_selected_item():
		return false
	if is_gameplay_ui_at_point(screen_position):
		return false
	return true


func begin_fast_block_place_hold(screen_position: Vector2, touch_index: int = -1) -> void:
	if not should_start_fast_block_place_hold(screen_position):
		trace_fast_block_place_event("begin_blocked", {
			"screen_position": screen_position,
			"touch_index": touch_index,
			"in_world": in_world,
			"movement_locked": is_movement_locked(),
			"ui_at_point": is_gameplay_ui_at_point(screen_position),
			"selected_item_type": str(selected_item_type),
			"selected_item_category": str(selected_item_category),
			"can_fast_place_selected": is_fast_block_place_selected_item()
		})
		return

	if touch_index >= 0:
		set_mobile_pointer_screen_position(screen_position)

	fast_block_place_hold_active = true
	fast_block_place_hold_touch_index = touch_index
	fast_block_place_hold_timer = FAST_BLOCK_PLACE_INITIAL_DELAY
	fast_block_place_last_grid = get_mouse_grid_position()
	fast_block_place_last_item_type = str(selected_item_type)
	fast_block_place_last_item_category = str(selected_item_category)
	trace_fast_block_place_event("begin", {
		"screen_position": screen_position,
		"touch_index": touch_index,
		"last_grid": fast_block_place_last_grid,
		"item_type": fast_block_place_last_item_type,
		"item_category": fast_block_place_last_item_category,
		"initial_delay": FAST_BLOCK_PLACE_INITIAL_DELAY
	})


func end_fast_block_place_hold(touch_index: int = -1) -> void:
	if touch_index >= 0 and fast_block_place_hold_active and fast_block_place_hold_touch_index != touch_index:
		trace_fast_block_place_event("end_ignored_touch_mismatch", {
			"touch_index": touch_index,
			"active_touch_index": fast_block_place_hold_touch_index,
			"last_grid": fast_block_place_last_grid
		})
		return

	if fast_block_place_hold_active:
		trace_fast_block_place_event("end", {
			"touch_index": touch_index,
			"last_grid": fast_block_place_last_grid,
			"last_item_type": fast_block_place_last_item_type,
			"last_item_category": fast_block_place_last_item_category
		})
	fast_block_place_hold_active = false
	fast_block_place_hold_touch_index = -1
	fast_block_place_hold_timer = 0.0
	fast_block_place_last_grid = INVALID_GRID_POS
	fast_block_place_last_item_type = ""
	fast_block_place_last_item_category = ""

	if touch_index >= 0:
		clear_mobile_pointer_screen_position()


func update_fast_block_place_hold_input(event: InputEvent) -> void:
	if TouchInputGuard.is_emulated_mouse_from_touch(event):
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			begin_fast_block_place_hold(event.position, -1)
		else:
			end_fast_block_place_hold(-1)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			begin_fast_block_place_hold(event.position, event.index)
		elif fast_block_place_hold_active and fast_block_place_hold_touch_index == event.index:
			end_fast_block_place_hold(event.index)
		return

	if event is InputEventScreenDrag:
		if fast_block_place_hold_active and fast_block_place_hold_touch_index == event.index:
			set_mobile_pointer_screen_position(event.position)
			if is_gameplay_ui_at_point(event.position) or not is_fast_block_place_selected_item():
				end_fast_block_place_hold(event.index)


func get_fast_block_place_next_grid(last_grid: Vector2i, target_grid: Vector2i) -> Vector2i:
	if last_grid == INVALID_GRID_POS:
		return target_grid

	var delta_grid: Vector2i = target_grid - last_grid
	if abs(delta_grid.x) <= 1 and abs(delta_grid.y) <= 1:
		return target_grid

	var step_x: int = clampi(delta_grid.x, -1, 1)
	var step_y: int = clampi(delta_grid.y, -1, 1)

	# When the pointer jumps multiple tiles, advance one tile at a time instead
	# of placing only at the far pointer tile. This keeps drag placing from
	# leaving empty gaps when the mouse/finger moves faster than the repeat timer.
	if abs(delta_grid.x) > abs(delta_grid.y):
		step_y = 0
	elif abs(delta_grid.y) > abs(delta_grid.x):
		step_x = 0

	return Vector2i(last_grid.x + step_x, last_grid.y + step_y)


func place_block_at_grid_for_fast_hold(grid_pos: Vector2i) -> void:
	var previous_override_active: bool = fast_block_place_grid_override_active
	var previous_override_grid: Vector2i = fast_block_place_grid_override

	fast_block_place_grid_override_active = true
	fast_block_place_grid_override = grid_pos
	trace_fast_block_place_event("place_at_grid", {
		"grid_pos": grid_pos,
		"selected_item_type": str(selected_item_type),
		"selected_item_category": str(selected_item_category)
	})
	place_block_at_mouse()
	fast_block_place_grid_override_active = previous_override_active
	fast_block_place_grid_override = previous_override_grid


func update_fast_block_place_hold(delta: float) -> void:
	if not fast_block_place_hold_active:
		return
	restore_fast_block_place_selection_if_auto_switched()
	if is_movement_locked() or not is_fast_block_place_selected_item():
		trace_fast_block_place_event("update_stopped", {
			"reason": "movement_locked_or_invalid_item",
			"movement_locked": is_movement_locked(),
			"selected_item_type": str(selected_item_type),
			"selected_item_category": str(selected_item_category),
			"last_grid": fast_block_place_last_grid
		})
		end_fast_block_place_hold(fast_block_place_hold_touch_index)
		return
	if is_gameplay_ui_at_point(get_pointer_screen_position()):
		return

	fast_block_place_hold_timer -= delta
	if fast_block_place_hold_timer > 0.0:
		return

	var target_grid_pos: Vector2i = get_mouse_grid_position()
	var grid_pos: Vector2i = get_fast_block_place_next_grid(fast_block_place_last_grid, target_grid_pos)
	var item_type := str(selected_item_type)
	var item_category := str(selected_item_category)
	if grid_pos == fast_block_place_last_grid and item_type == fast_block_place_last_item_type and item_category == fast_block_place_last_item_category:
		return

	fast_block_place_hold_timer = FAST_BLOCK_PLACE_REPEAT_INTERVAL

	if not is_grid_inside_world(grid_pos):
		trace_fast_block_place_event("tick_blocked", {
			"reason": "outside_world_bounds",
			"grid_pos": grid_pos,
			"target_grid": target_grid_pos,
			"last_grid": fast_block_place_last_grid
		})
		return
	if not can_reach_grid(grid_pos):
		trace_fast_block_place_event("tick_blocked", {
			"reason": "too_far",
			"grid_pos": grid_pos,
			"target_grid": target_grid_pos,
			"last_grid": fast_block_place_last_grid
		})
		return

	fast_block_place_last_grid = grid_pos
	fast_block_place_last_item_type = item_type
	fast_block_place_last_item_category = item_category
	trace_fast_block_place_event("tick_place", {
		"grid_pos": grid_pos,
		"target_grid": target_grid_pos,
		"item_type": item_type,
		"item_category": item_category,
		"repeat_interval": FAST_BLOCK_PLACE_REPEAT_INTERVAL
	})

	place_block_at_grid_for_fast_hold(grid_pos)
	restore_fast_block_place_selection_if_auto_switched()


func _input(event):
	if is_item_action_popup_event(event):
		return
	update_fast_block_place_hold_input(event)
	if input_manager != null and input_manager.has_method("handle_input"):
		input_manager.handle_input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_mobile_back_request()


func handle_mobile_back_request() -> bool:
	if input_manager != null and input_manager.has_method("handle_back_request"):
		return bool(input_manager.handle_back_request())

	if in_world:
		open_game_menu()
		return true
	return false


func _unhandled_input(event):
	if is_item_action_popup_event(event):
		get_viewport().set_input_as_handled()
		return
	if input_manager != null and input_manager.has_method("handle_unhandled_input"):
		input_manager.handle_unhandled_input(event)



func update_back_item_jump_reset():
	if player_manager != null and player_manager.has_method("update_back_item_jump_reset"):
		return player_manager.update_back_item_jump_reset()

	return


func try_back_item_air_jump(event: InputEvent) -> bool:
	if player_manager != null and player_manager.has_method("try_back_item_air_jump"):
		return player_manager.try_back_item_air_jump(event)

	return false
func perform_back_item_air_jump():
	if player_manager != null and player_manager.has_method("perform_back_item_air_jump"):
		return player_manager.perform_back_item_air_jump()

	return
func get_allowed_back_item_air_jumps() -> int:
	if player_manager != null and player_manager.has_method("get_allowed_back_item_air_jumps"):
		return player_manager.get_allowed_back_item_air_jumps()

	return 0
func select_item(item_type: String, category: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("select_item"):
		return item_gameplay_manager.select_item(item_type, category)

	return

func get_selected_item_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_selected_item_text"):
		return item_gameplay_manager.get_selected_item_text()

	return ""

func update_all_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_all_ui"):
		return gameplay_ui_manager.update_all_ui()

	return

func is_inventory_open() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_open"):
		return inventory_manager.is_inventory_open()

	return false


func is_inventory_search_focused() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_search_focused"):
		return inventory_manager.is_inventory_search_focused()

	return false


func is_inventory_ui_at_point(point: Vector2) -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_ui_at_point"):
		return bool(inventory_manager.is_inventory_ui_at_point(point))

	return false


func is_inventory_control_at_point(point: Vector2) -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_control_at_point"):
		return bool(inventory_manager.is_inventory_control_at_point(point))

	return false


func is_item_action_popup_at_point(point: Vector2) -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_item_action_popup_at_point"):
		return bool(inventory_manager.is_item_action_popup_at_point(point))

	return false


func is_item_action_popup_event(event: InputEvent) -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_item_action_popup_event"):
		return bool(inventory_manager.is_item_action_popup_event(event))

	return false


func is_floating_hud_button_at_point(point: Vector2) -> bool:
	var button_sources: Array = [
		{"node": inventory_manager, "property": "inventory_button"},
		{"node": notification_ui, "property": "notification_button"},
		{"node": game_menu_ui, "property": "menu_button"},
		{"node": developer_panel_ui, "property": "dev_button"},
		{"node": shop_ui, "property": "shop_button"}
	]

	for source in button_sources:
		var ui_node = source.get("node", null)
		if ui_node == null or not is_instance_valid(ui_node):
			continue
		var control = ui_node.get(str(source.get("property", "")))
		if control_contains_screen_point(control, point):
			return true

	return false


func is_mobile_gameplay_control_at_point(point: Vector2) -> bool:
	var hud_layer = get_ui_hud_layer()
	var controls = hud_layer.get_node_or_null("MobileControls") if hud_layer != null else null
	if controls == null and ui_layer != null and hud_layer != ui_layer:
		controls = ui_layer.get_node_or_null("MobileControls")
	if controls == null or not controls.has_method("is_gameplay_control_at_point"):
		return false
	return bool(controls.is_gameplay_control_at_point(point))


func activate_floating_hud_button_at_point(point: Vector2) -> bool:
	if is_panel_ui_at_point(point):
		return false

	var button_actions: Array = [
		{"node": developer_panel_ui, "property": "dev_button", "action": "toggle_developer_panel"},
		{"node": game_menu_ui, "property": "menu_button", "action": "toggle_game_menu"},
		{"node": notification_ui, "property": "notification_button", "action": "toggle_notification_panel"},
		{"node": shop_ui, "property": "shop_button", "action": "toggle_shop"},
		{"node": inventory_manager, "property": "inventory_button", "action": "toggle_inventory_window"}
	]

	for source in button_actions:
		var ui_node = source.get("node", null)
		if ui_node == null or not is_instance_valid(ui_node):
			continue
		var control = ui_node.get(str(source.get("property", "")))
		if not control_contains_screen_point(control, point):
			continue
		var action = str(source.get("action", ""))
		if has_method(action):
			call(action)
			return true

	return false


func is_panel_ui_at_point(point: Vector2) -> bool:
	var ui_nodes: Array = [
		notification_ui,
		player_menu_ui,
		game_menu_ui,
		friends_ui,
		developer_panel_ui,
		trade_ui,
		vending_ui,
		safe_ui,
		donation_box_ui,
		mailbox_ui,
		bulletin_board_ui,
		display_ui,
		fish_monger_ui,
		cctv_ui,
		oil_refinery_ui,
		battery_charger_ui,
		shop_ui,
		crafting_ui,
		furnace_ui,
		sign_ui,
		world_menu_ui,
		world_lock_ui,
		area_lock_ui
	]
	var hit_property_names: Array = [
		"panel",
		"shop_panel",
		"notification_panel",
		"purchase_reward_popup",
		"confirm_panel",
		"pin_gate_panel",
		"picker_panel",
		"final_panel",
		"withdraw_popup",
		"locked_worlds_panel",
		"action_panel",
		"preview_panel"
	]

	for ui_node in ui_nodes:
		if is_gameplay_ui_node_at_point(ui_node, point, hit_property_names):
			return true

	return false


func control_contains_screen_point(control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control) or not (control is Control):
		return false
	if not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.has_point(point)


func is_gameplay_ui_node_at_point(ui_node, point: Vector2, hit_property_names: Array) -> bool:
	if ui_node == null or not is_instance_valid(ui_node):
		return false
	if ui_node is CanvasItem and not ui_node.is_visible_in_tree():
		return false

	for property_name in hit_property_names:
		var control = ui_node.get(str(property_name))
		if control_contains_screen_point(control, point):
			return true

	return false


func is_gameplay_ui_at_point(point: Vector2) -> bool:
	if is_item_action_popup_at_point(point):
		return true

	if is_mobile_gameplay_control_at_point(point):
		return true

	if is_floating_hud_button_at_point(point):
		return true

	if is_inventory_ui_at_point(point):
		return true

	if chat_ui != null and chat_ui.has_method("is_chat_ui_at_point") and bool(chat_ui.is_chat_ui_at_point(point)):
		return true

	return is_panel_ui_at_point(point)


func handle_inventory_wheel(event: InputEvent) -> bool:
	if inventory_manager != null and inventory_manager.has_method("handle_inventory_wheel"):
		return bool(inventory_manager.handle_inventory_wheel(event))

	return false


func setup_crack_textures():
	if block_manager != null and block_manager.has_method("setup_crack_textures"):
		block_manager.setup_crack_textures()

func get_block_max_hits(block_type: String) -> int:
	if block_manager != null and block_manager.has_method("get_block_max_hits"):
		return block_manager.get_block_max_hits(block_type)

	if item_database.has(block_type):
		return max(1, int(item_database[block_type].get("block_health", BLOCK_MAX_HITS)))

	return BLOCK_MAX_HITS

func get_crack_stage(current_hits: int, max_hits: int) -> int:
	if block_manager != null and block_manager.has_method("get_crack_stage"):
		return block_manager.get_crack_stage(current_hits, max_hits)

	return 0

func update_block_crack_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_block_crack_visual"):
		block_manager.update_block_crack_visual(grid_pos)

func is_entrance_gate_block(block_type: String) -> bool:
	if environment_manager != null and environment_manager.has_method("is_entrance_gate_block"):
		return environment_manager.is_entrance_gate_block(block_type)

	return false

func get_entrance_gate_center_x() -> int:
	if environment_manager != null and environment_manager.has_method("get_entrance_gate_center_x"):
		return environment_manager.get_entrance_gate_center_x()

	return int(floor(float(WORLD_WIDTH) * 0.5))

func find_entrance_gate_grid() -> Vector2i:
	if environment_manager != null and environment_manager.has_method("find_entrance_gate_grid"):
		return environment_manager.find_entrance_gate_grid()

	return INVALID_GRID_POS

func get_entrance_gate_grid_position() -> Vector2i:
	if environment_manager != null and environment_manager.has_method("get_entrance_gate_grid_position"):
		return environment_manager.get_entrance_gate_grid_position()

	return INVALID_GRID_POS

func get_entrance_gate_near_grid(grid_pos: Vector2i) -> Vector2i:
	if environment_manager != null and environment_manager.has_method("get_entrance_gate_near_grid"):
		return environment_manager.get_entrance_gate_near_grid(grid_pos)

	return INVALID_GRID_POS

func use_entrance_mover_at_mouse():
	if environment_manager != null and environment_manager.has_method("use_entrance_mover_at_mouse"):
		return environment_manager.use_entrance_mover_at_mouse()

	return

func use_lock_mover_at_mouse():
	if world_lock_manager != null and world_lock_manager.has_method("use_lock_mover_at_mouse"):
		return world_lock_manager.use_lock_mover_at_mouse()

	return

func use_door_mover_at_mouse():
	if interaction_manager != null and interaction_manager.has_method("use_door_mover_at_mouse"):
		return interaction_manager.use_door_mover_at_mouse()

	return

func move_entrance_gate_to(new_gate_pos: Vector2i) -> bool:
	if environment_manager != null and environment_manager.has_method("move_entrance_gate_to"):
		return environment_manager.move_entrance_gate_to(new_gate_pos)

	return false

func can_place_entrance_gate_at(gate_pos: Vector2i) -> bool:
	if environment_manager != null and environment_manager.has_method("can_place_entrance_gate_at"):
		return environment_manager.can_place_entrance_gate_at(gate_pos)

	return false

func remove_old_entrance_gate_bedrock(gate_pos: Vector2i):
	if environment_manager != null and environment_manager.has_method("remove_old_entrance_gate_bedrock"):
		return environment_manager.remove_old_entrance_gate_bedrock(gate_pos)

	return

func is_player_standing_on_entrance_gate() -> bool:
	if environment_manager != null and environment_manager.has_method("is_player_standing_on_entrance_gate"):
		return environment_manager.is_player_standing_on_entrance_gate()

	return false

func can_use_entrance_gate() -> bool:
	if environment_manager != null and environment_manager.has_method("can_use_entrance_gate"):
		return environment_manager.can_use_entrance_gate()

	return false

func ensure_entrance_gate_bedrock(gate_pos: Vector2i):
	if environment_manager != null and environment_manager.has_method("ensure_entrance_gate_bedrock"):
		return environment_manager.ensure_entrance_gate_bedrock(gate_pos)

	return

func get_entrance_gate_spawn_position() -> Vector2:
	# World-entry spawn must be resolved from the live block dictionary, not from
	# any cached entrance coordinate. This fixes spawning at an old entrance gate
	# location after the entrance has been moved.
	var live_spawn := get_live_entrance_gate_spawn_position(false)
	if is_finite(live_spawn.x) and is_finite(live_spawn.y):
		return live_spawn

	# Never synthesize a gate from terrain/default coordinates while authoritative
	# world data is still being rebuilt. That fallback can belong to the old or an
	# incomplete world and was one source of seemingly random join positions.
	if is_entrance_gate_spawn_resolution_deferred():
		return Vector2(INF, INF)

	if environment_manager != null and environment_manager.has_method("ensure_entrance_gate"):
		environment_manager.ensure_entrance_gate()

	return get_live_entrance_gate_spawn_position(false)


func is_entrance_gate_spawn_resolution_deferred() -> bool:
	if applying_network_world_update:
		return true
	if bool(get_meta("world_entry_in_progress", false)):
		return true
	if bool(get_meta("world_bulk_load_in_progress", false)):
		return true
	if save_manager != null and "waiting_for_server_world_state" in save_manager:
		return bool(save_manager.waiting_for_server_world_state)
	return false


func is_entrance_gate_block_type_direct(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == "":
		return false

	if clean_type == str(ENTRANCE_GATE_TYPE).strip_edges().to_lower():
		return true

	if clean_type == "entrance_gate":
		return true

	if item_database.has(clean_type):
		var item_data = item_database[clean_type]
		if item_data is Dictionary:
			if bool(item_data.get("entrance_gate_block", false)):
				return true
			if bool(item_data.get("entrance_gate", false)):
				return true

	return false


func find_live_entrance_gate_grid_from_blocks() -> Vector2i:
	# Scan the current loaded foreground blocks every time a world-entry spawn is
	# needed. Do not trust cached entrance positions here.
	var found_grid: Vector2i = INVALID_GRID_POS
	var best_score: float = INF
	var center_x: int = int(get_entrance_gate_center_x())

	for raw_grid_pos in blocks.keys():
		if not (raw_grid_pos is Vector2i):
			continue

		var grid_pos: Vector2i = raw_grid_pos
		var block_data = blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue

		var block_type := str(block_data.get("type", ""))
		if not is_entrance_gate_block_type_direct(block_type):
			continue

		# If a duplicated old entrance somehow exists, prefer the one closest to the
		# configured entrance center, then the lower one. Normal worlds should only
		# have one entrance gate, so this only acts as a safety fallback.
		var score: float = absf(float(grid_pos.x - center_x)) * 1000.0 + float(grid_pos.y)
		if found_grid == INVALID_GRID_POS or score < best_score:
			found_grid = grid_pos
			best_score = score

	return found_grid


func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return Vector2(float(grid_pos.x * BLOCK_SIZE), float(grid_pos.y * BLOCK_SIZE))


func get_entrance_gate_spawn_offset_from_environment(_live_gate_grid: Vector2i) -> Vector2:
	if environment_manager == null:
		return Vector2.ZERO

	if not environment_manager.has_method("get_entrance_gate_spawn_position"):
		return Vector2.ZERO

	var environment_spawn = environment_manager.get_entrance_gate_spawn_position()
	if not (environment_spawn is Vector2):
		return Vector2.ZERO

	var environment_gate_grid := INVALID_GRID_POS
	if environment_manager.has_method("get_entrance_gate_grid_position"):
		var env_grid_value = environment_manager.get_entrance_gate_grid_position()
		if env_grid_value is Vector2i:
			environment_gate_grid = env_grid_value

	if environment_gate_grid == INVALID_GRID_POS:
		return Vector2.ZERO

	var offset: Vector2 = environment_spawn - grid_to_world_center(environment_gate_grid)
	# Keep only normal spawn offsets. A huge offset means the environment manager
	# was using a stale cached gate, so ignore it.
	if abs(offset.x) > float(BLOCK_SIZE * 3) or abs(offset.y) > float(BLOCK_SIZE * 3):
		return Vector2.ZERO

	return offset


func get_live_entrance_gate_spawn_position(allow_repair: bool = true) -> Vector2:
	var live_gate_grid := find_live_entrance_gate_grid_from_blocks()

	if live_gate_grid == INVALID_GRID_POS and allow_repair and not is_entrance_gate_spawn_resolution_deferred():
		# Only create/repair the entrance if the live world truly has no entrance.
		# Calling ensure first can preserve stale cached coordinates in some flows.
		if environment_manager != null and environment_manager.has_method("ensure_entrance_gate"):
			environment_manager.ensure_entrance_gate()
		live_gate_grid = find_live_entrance_gate_grid_from_blocks()

	if live_gate_grid == INVALID_GRID_POS:
		return Vector2(INF, INF)

	var spawn_position := grid_to_world_center(live_gate_grid)
	spawn_position.x = clamp(spawn_position.x, 0.0, float((WORLD_WIDTH - 1) * BLOCK_SIZE))
	spawn_position.y = clamp(spawn_position.y, 0.0, float((WORLD_HEIGHT - 1) * BLOCK_SIZE))
	return spawn_position


func force_place_player_at_current_entrance_gate(sync_to_server: bool = true) -> bool:
	if player == null:
		return false

	# A missing live gate during a world rebuild is not a valid fallback spawn.
	# Keep the player hidden/in place until the authoritative gate exists.
	var spawn_pos := get_entrance_gate_spawn_position()
	if (not is_finite(spawn_pos.x) or not is_finite(spawn_pos.y)) and not is_entrance_gate_spawn_resolution_deferred():
		if has_method("ensure_entrance_gate"):
			ensure_entrance_gate()
		spawn_pos = get_entrance_gate_spawn_position()

	if not is_finite(spawn_pos.x) or not is_finite(spawn_pos.y):
		return false

	player.global_position = spawn_pos
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
		player.set_physics_process(true)
		if player.has_method("reset_instant_hazard_after_respawn"):
			player.reset_instant_hazard_after_respawn()

	var camera = get_player_camera()
	if camera != null and camera.has_method("reset_smoothing"):
		camera.reset_smoothing()

	if sync_to_server:
		flush_world_entry_spawn_position_to_server()

	return true


func flush_world_entry_spawn_position_to_server() -> bool:
	if not MovementMode.is_websocket():
		return false
	if player == null or not in_world:
		return false

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_position"):
		return false

	var facing := -1 if int(player_facing_direction) < 0 else 1
	return bool(network.send_player_position(player.global_position, facing, current_world_name, false, true, "world_join"))

func ensure_entrance_gate():
	if environment_manager != null and environment_manager.has_method("ensure_entrance_gate"):
		return environment_manager.ensure_entrance_gate()

	return

func ensure_generated_entrance_gate():
	if environment_manager != null and environment_manager.has_method("ensure_generated_entrance_gate"):
		return environment_manager.ensure_generated_entrance_gate()

	return ensure_entrance_gate()

func update_entrance_gate_visual(grid_pos: Vector2i):
	if environment_manager != null and environment_manager.has_method("update_entrance_gate_visual"):
		return environment_manager.update_entrance_gate_visual(grid_pos)

	return

func exit_world_from_entrance_gate():
	if environment_manager != null and environment_manager.has_method("exit_world_from_entrance_gate"):
		return environment_manager.exit_world_from_entrance_gate()

	return

func setup_water_animation():
	if environment_manager != null and environment_manager.has_method("setup_water_animation"):
		return environment_manager.setup_water_animation()

	return

func update_water_animation(delta):
	if environment_manager != null and environment_manager.has_method("update_water_animation"):
		return environment_manager.update_water_animation(delta)

	return

func is_non_collideable_block(block_type: String) -> bool:
	if block_manager != null and block_manager.has_method("is_non_collideable_block"):
		return block_manager.is_non_collideable_block(block_type)

	if item_database.has(block_type):
		return bool(item_database[block_type].get("no_collision", false))

	return false

func remove_block_without_drop(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("remove_block_without_drop"):
		block_manager.remove_block_without_drop(grid_pos)

func replace_block_without_drop(grid_pos: Vector2i, block_type: String):
	if block_manager != null and block_manager.has_method("replace_block_without_drop"):
		block_manager.replace_block_without_drop(grid_pos, block_type)

func generate_world():
	if world_generation_manager != null and world_generation_manager.has_method("generate_world"):
		world_generation_manager.generate_world()


func generate_terrain_surface():
	if world_generation_manager != null and world_generation_manager.has_method("generate_terrain_surface"):
		world_generation_manager.generate_terrain_surface()


func get_surface_y_at_x(x: int) -> int:
	if world_generation_manager != null and world_generation_manager.has_method("get_surface_y_at_x"):
		return world_generation_manager.get_surface_y_at_x(x)

	var safe_x = clamp(x, 0, WORLD_WIDTH - 1)

	if terrain_surface_y.has(safe_x):
		return int(terrain_surface_y[safe_x])

	for y in range(0, WORLD_HEIGHT):
		var grid_pos = Vector2i(safe_x, y)

		if blocks.has(grid_pos):
			return y

	return SURFACE_Y


func is_spawn_safe_column(x: int) -> bool:
	if world_generation_manager != null and world_generation_manager.has_method("is_spawn_safe_column"):
		return world_generation_manager.is_spawn_safe_column(x)

	return abs(x - SPAWN_GRID_X) <= SPAWN_FLAT_RADIUS


func get_generated_block_type(x: int, y: int, surface_y: int = SURFACE_Y) -> String:
	if world_generation_manager != null and world_generation_manager.has_method("get_generated_block_type"):
		return world_generation_manager.get_generated_block_type(x, y, surface_y)

	return "dirt"


func generate_natural_ponds():
	if world_generation_manager != null and world_generation_manager.has_method("generate_natural_ponds"):
		world_generation_manager.generate_natural_ponds()


func can_generate_natural_pond(center_x: int, width: int) -> bool:
	if world_generation_manager != null and world_generation_manager.has_method("can_generate_natural_pond"):
		return world_generation_manager.can_generate_natural_pond(center_x, width)

	return false


func create_natural_pond(center_x: int, width: int):
	if world_generation_manager != null and world_generation_manager.has_method("create_natural_pond"):
		world_generation_manager.create_natural_pond(center_x, width)


func generate_trees():
	if world_generation_manager != null and world_generation_manager.has_method("generate_trees"):
		world_generation_manager.generate_trees()


func create_tree(x: int):
	if world_generation_manager != null and world_generation_manager.has_method("create_tree"):
		world_generation_manager.create_tree(x)

func create_block(grid_pos: Vector2i, block_type: String = "dirt"):
	if block_manager != null and block_manager.has_method("create_block"):
		block_manager.create_block(grid_pos, block_type)

func set_block_texture(block, block_type: String):
	if block_manager != null and block_manager.has_method("set_block_texture"):
		block_manager.set_block_texture(block, block_type)

func configure_block_collision(block, block_type: String):
	if block_manager != null and block_manager.has_method("configure_block_collision"):
		block_manager.configure_block_collision(block, block_type)

func set_original_block_collision_disabled(node, disabled: bool):
	if block_manager != null and block_manager.has_method("set_original_block_collision_disabled"):
		block_manager.set_original_block_collision_disabled(node, disabled)

func remove_wood_platform_collision(node):
	if block_manager != null and block_manager.has_method("remove_wood_platform_collision"):
		block_manager.remove_wood_platform_collision(node)

func get_block_collision_body(node):
	if block_manager != null and block_manager.has_method("get_block_collision_body"):
		return block_manager.get_block_collision_body(node)

	return null

func add_wood_platform_collision(block):
	if block_manager != null and block_manager.has_method("add_wood_platform_collision"):
		block_manager.add_wood_platform_collision(block)

func play_springboard_block_animation(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("play_springboard_block_animation"):
		block_manager.play_springboard_block_animation(grid_pos)

func play_dice_roll_animation(grid_pos: Vector2i, final_face: int = 1, roll_id: String = ""):
	if block_manager != null and block_manager.has_method("play_dice_roll_animation"):
		block_manager.play_dice_roll_animation(grid_pos, final_face, roll_id)

func play_entrance_pass_animation(grid_pos: Vector2i, walk_direction: int = 1):
	if block_manager != null and block_manager.has_method("play_wooden_entrance_pass_animation"):
		block_manager.play_wooden_entrance_pass_animation(grid_pos, walk_direction)

func send_springboard_block_animation(grid_pos: Vector2i) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_springboard_animation"):
		return bool(network.send_springboard_animation(grid_pos, current_world_name))

	return false

func send_entrance_pass(grid_pos: Vector2i, walk_direction: int = 1) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_entrance_pass"):
		return bool(network.send_entrance_pass(grid_pos, walk_direction, current_world_name))

	return false

func break_block_at_mouse():
	if block_manager != null and block_manager.has_method("break_block_at_mouse"):
		block_manager.break_block_at_mouse()

func play_player_punch_animation():
	if player_manager != null and player_manager.has_method("play_player_punch_animation"):
		player_manager.play_player_punch_animation()

func update_block_damage_recovery(delta):
	if block_manager != null and block_manager.has_method("update_block_damage_recovery"):
		block_manager.update_block_damage_recovery(delta)

func hit_block_grid(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("hit_block_grid"):
		block_manager.hit_block_grid(grid_pos)

func break_block_grid(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("break_block_grid"):
		block_manager.break_block_grid(grid_pos)

func setup_drop_manager():
	if drop_manager == null:
		var drop_script = preload("res://Scripts/drop_manager.gd")
		drop_manager = Node.new()
		drop_manager.name = "DropManager"
		drop_manager.set_script(drop_script)
		add_child(drop_manager)

	if drop_manager.has_method("setup"):
		drop_manager.setup(self)


func setup_world_generation_manager():
	if world_generation_manager == null:
		var generation_script = preload("res://Scripts/world_generation_manager.gd")
		world_generation_manager = Node.new()
		world_generation_manager.name = "WorldGenerationManager"
		world_generation_manager.set_script(generation_script)
		add_child(world_generation_manager)

	if world_generation_manager.has_method("setup"):
		world_generation_manager.setup(self)


func setup_block_manager():
	if block_manager == null:
		var block_script = preload("res://Scripts/block_manager.gd")
		block_manager = Node.new()
		block_manager.name = "BlockManager"
		block_manager.set_script(block_script)
		add_child(block_manager)

	if block_manager.has_method("setup"):
		block_manager.setup(self)


func setup_electricity_manager():
	if electricity_manager == null:
		var electricity_script = preload("res://Scripts/electricity_manager.gd")
		electricity_manager = Node2D.new()
		electricity_manager.name = "ElectricityManager"
		electricity_manager.set_script(electricity_script)
		add_child(electricity_manager)

	if electricity_manager.has_method("setup"):
		electricity_manager.setup(self)


func setup_particle_manager():
	if particle_manager == null:
		var particle_script = preload("res://Scripts/particle_manager.gd")
		particle_manager = Node2D.new()
		particle_manager.name = "ParticleManager"
		particle_manager.set_script(particle_script)
		add_child(particle_manager)

	if particle_manager.has_method("setup"):
		particle_manager.setup(self)


func setup_block_shadow_manager():
	if block_shadow_manager != null and is_instance_valid(block_shadow_manager):
		block_shadow_manager.queue_free()
	block_shadow_manager = null


func setup_interaction_manager():
	if interaction_manager == null:
		var interaction_script = preload("res://Scripts/interaction_manager.gd")
		interaction_manager = Node.new()
		interaction_manager.name = "InteractionManager"
		interaction_manager.set_script(interaction_script)
		add_child(interaction_manager)

	if interaction_manager.has_method("setup"):
		interaction_manager.setup(self)


func setup_player_manager():
	if player_manager == null:
		var script_paths = [
			"res://Scripts/player_manager.gd",
			"res://scripts/player_manager.gd"
		]
		var player_script: Script = null
		for script_path in script_paths:
			if ResourceLoader.exists(script_path):
				player_script = load(script_path)
				if player_script != null:
					break
		if player_script == null:
			push_error("[PlayerManager] Unable to load player_manager script. Check resource path and filesystem case on this machine.")
			return
		player_manager = Node.new()
		player_manager.name = "PlayerManager"
		player_manager.set_script(player_script)
		add_child(player_manager)

	if player_manager.has_method("setup"):
		player_manager.setup(self)


func setup_netfox_real_manager():
	if not MovementMode.is_netfox_real():
		return

	if netfox_real_manager == null:
		var manager_script = preload("res://Scripts/networking/netfox_real_manager.gd")
		netfox_real_manager = Node.new()
		netfox_real_manager.name = "NetfoxRealManager"
		netfox_real_manager.set_script(manager_script)
		add_child(netfox_real_manager)

	if netfox_real_manager.has_method("setup"):
		netfox_real_manager.setup(self)


func setup_custom_authoritative_movement_manager():
	if not MovementMode.is_custom_authoritative():
		return

	if custom_authoritative_movement_manager == null:
		var manager_script = preload("res://Scripts/networking/custom_authoritative_movement_manager.gd")
		custom_authoritative_movement_manager = Node.new()
		custom_authoritative_movement_manager.name = "CustomAuthoritativeMovementManager"
		custom_authoritative_movement_manager.set_script(manager_script)
		add_child(custom_authoritative_movement_manager)

	if custom_authoritative_movement_manager.has_method("setup"):
		custom_authoritative_movement_manager.setup(self)


func _is_netfox_real_server_launch() -> bool:
	if MovementMode.has_method("is_netfox_real_server_launch"):
		return bool(MovementMode.is_netfox_real_server_launch())
	return MovementMode.is_netfox_real() and MovementMode.has_launch_arg("--server") and not MovementMode.has_launch_arg("--client")


func _is_custom_authoritative_server_launch() -> bool:
	if MovementMode.has_method("is_custom_movement_server_launch"):
		return bool(MovementMode.is_custom_movement_server_launch())
	return MovementMode.is_custom_authoritative() and MovementMode.has_launch_arg("--server") and not MovementMode.has_launch_arg("--client")


func _is_trusted_movement_backend_dev_client_launch() -> bool:
	if MovementMode.is_custom_authoritative() and MovementMode.has_method("is_custom_movement_client_launch"):
		return bool(MovementMode.is_custom_movement_client_launch())
	if MovementMode.is_netfox_real() and MovementMode.has_method("is_netfox_real_client_launch"):
		return bool(MovementMode.is_netfox_real_client_launch())
	var trusted_mode := MovementMode.is_netfox_real() or MovementMode.is_custom_authoritative()
	return trusted_mode and MovementMode.has_launch_arg("--client") and not MovementMode.has_launch_arg("--server")


func _get_backend_dev_login_default_world_name() -> String:
	if MovementMode.is_custom_authoritative():
		return "TEST"
	return "NETFOX_TEST"


func _get_backend_dev_login_default_profile_name() -> String:
	if MovementMode.is_custom_authoritative():
		return "uso"
	return "DevNetfox"


func _should_start_backend_dev_login_from_world_scene() -> bool:
	if not _is_trusted_movement_backend_dev_client_launch():
		return false
	if not MovementMode.is_backend_dev_login_requested():
		return false
	if not MovementMode.is_backend_dev_login_allowed():
		MovementMode.report_backend_dev_login_rejected()
		return false

	var network := get_node_or_null("/root/NetworkManager")
	if network != null:
		if network.has_method("is_server_session_authenticated") and bool(network.is_server_session_authenticated()):
			return false
		if network.has_method("has_active_session") and bool(network.has_active_session()):
			return false

	return true


func _should_direct_enter_backend_dev_login_world() -> bool:
	if not _is_trusted_movement_backend_dev_client_launch():
		return false
	if not MovementMode.is_backend_dev_login_requested():
		return false
	if MovementMode.get_launch_arg_value("--world", "").strip_edges() == "":
		return false

	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	if network.has_method("is_server_session_authenticated") and bool(network.is_server_session_authenticated()):
		return true
	if network.has_method("has_active_session") and bool(network.has_active_session()):
		return true

	return false


func _run_backend_dev_login_and_enter_world() -> void:
	if not MovementMode.is_backend_dev_login_allowed():
		MovementMode.report_backend_dev_login_rejected()
		return

	var world_name := MovementMode.get_dev_test_world_name(_get_backend_dev_login_default_world_name())
	var profile_name := MovementMode.get_dev_profile_name(_get_backend_dev_login_default_profile_name())
	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		push_warning("[BackendDevLogin] NetworkManager is not available.")
		return

	var connected_ok := await _wait_for_backend_dev_login_connection(12.0)
	if not connected_ok:
		push_warning("[BackendDevLogin] Could not connect to backend for dev login.")
		return

	if not network.has_method("send_backend_dev_login"):
		push_warning("[BackendDevLogin] Backend dev login is not available.")
		return

	if network.has_method("set_pending_join"):
		network.set_pending_join(world_name, profile_name)
	network.set("current_world_name", world_name)

	var existing_session := _get_backend_dev_login_session_result(network, profile_name, world_name)
	if bool(existing_session.get("ok", false)):
		var existing_username := str(existing_session.get("username", profile_name)).strip_edges()
		print("[BackendDevLogin] Authenticated %s for %s in %s mode." % [existing_username, world_name, MovementMode.get_mode_name()])
		_direct_enter_backend_dev_login_world()
		return

	var request_id := str(network.send_backend_dev_login(profile_name, world_name))
	if request_id == "":
		push_warning("[BackendDevLogin] Could not start backend dev login.")
		return

	var result := await _wait_for_backend_dev_login_response(request_id, profile_name, world_name, 10.0)
	if not bool(result.get("ok", false)):
		push_warning("[BackendDevLogin] " + str(result.get("message", "Backend dev login failed.")))
		return

	var server_username := str(result.get("username", profile_name)).strip_edges()
	var server_email := str(result.get("email", "%s@dev.local.invalid" % server_username.to_lower())).strip_edges()
	if server_username == "":
		server_username = profile_name
	if account_manager != null and account_manager.has_method("cache_server_account"):
		account_manager.cache_server_account(server_username, server_email)
	if network.has_method("set_pending_join"):
		network.set_pending_join(world_name, server_username)
	network.set("current_world_name", world_name)
	print("[BackendDevLogin] Authenticated %s for %s in %s mode." % [server_username, world_name, MovementMode.get_mode_name()])
	_direct_enter_backend_dev_login_world()


func _wait_for_backend_dev_login_connection(timeout_seconds: float) -> bool:
	var network := get_node_or_null("/root/NetworkManager")
	var deadline := Time.get_ticks_msec() + int(maxf(0.1, timeout_seconds) * 1000.0)
	while is_inside_tree() and Time.get_ticks_msec() <= deadline:
		if network != null and network.has_method("is_connected_to_server") and bool(network.is_connected_to_server()):
			return true
		await get_tree().process_frame
	return network != null and network.has_method("is_connected_to_server") and bool(network.is_connected_to_server())


func _wait_for_backend_dev_login_response(request_id: String, expected_username: String, expected_world: String, timeout_seconds: float) -> Dictionary:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_signal("server_auth_finished"):
		return {"ok": false, "message": "Backend auth signal is not available."}

	var existing_session := _get_backend_dev_login_session_result(network, expected_username, expected_world)
	if bool(existing_session.get("ok", false)):
		return existing_session

	var response_state: Dictionary = {
		"matched_response": {},
		"received": false,
	}
	var auth_finished_handler := func(data):
		if bool(response_state.get("received", false)):
			return
		if data is Dictionary:
			var response_request_id := str(data.get("request_id", "")).strip_edges()
			var response_username := str(data.get("username", data.get("account_username", ""))).strip_edges()
			var response_action := str(data.get("action", "")).strip_edges().to_lower()
			var exact_request := response_request_id == request_id
			var matching_dev_auth := (
				response_action == "dev_backend_login"
				and bool(data.get("ok", false))
				and response_username.to_lower() == expected_username.strip_edges().to_lower()
			)
			if exact_request or matching_dev_auth:
				response_state["matched_response"] = data
				response_state["received"] = true

	network.server_auth_finished.connect(auth_finished_handler)
	var deadline := Time.get_ticks_msec() + int(maxf(0.1, timeout_seconds) * 1000.0)
	while is_inside_tree() and Time.get_ticks_msec() <= deadline:
		if bool(response_state.get("received", false)):
			if network.server_auth_finished.is_connected(auth_finished_handler):
				network.server_auth_finished.disconnect(auth_finished_handler)
			var matched_response_value = response_state.get("matched_response", {})
			return matched_response_value if matched_response_value is Dictionary else {}
		var session_result := _get_backend_dev_login_session_result(network, expected_username, expected_world)
		if bool(session_result.get("ok", false)):
			if network.server_auth_finished.is_connected(auth_finished_handler):
				network.server_auth_finished.disconnect(auth_finished_handler)
			return session_result
		await get_tree().process_frame

	if network.server_auth_finished.is_connected(auth_finished_handler):
		network.server_auth_finished.disconnect(auth_finished_handler)
	var final_session_result := _get_backend_dev_login_session_result(network, expected_username, expected_world)
	if bool(final_session_result.get("ok", false)):
		return final_session_result
	return {"ok": false, "message": "Backend dev login timed out."}


func _get_backend_dev_login_session_result(network: Node, expected_username: String, expected_world: String) -> Dictionary:
	if network == null:
		return {}

	var authenticated := false
	if network.has_method("is_server_session_authenticated"):
		authenticated = bool(network.is_server_session_authenticated())
	elif network.has_method("has_active_session"):
		authenticated = bool(network.has_active_session())

	if not authenticated:
		return {}

	var session_username := ""
	if network.has_method("get_active_session_username"):
		session_username = str(network.get_active_session_username()).strip_edges()
	else:
		session_username = str(network.get("session_username")).strip_edges()

	var expected_clean := expected_username.strip_edges()
	if expected_clean != "" and session_username.to_lower() != expected_clean.to_lower():
		return {}

	var session_world := str(network.get("current_world_name")).strip_edges()
	var expected_world_clean := expected_world.strip_edges()
	if session_world == "" and expected_world_clean != "":
		session_world = expected_world_clean

	return {
		"ok": true,
		"action": "dev_backend_login",
		"username": session_username if session_username != "" else expected_clean,
		"email": "%s@dev.local.invalid" % (session_username if session_username != "" else expected_clean).to_lower(),
		"world": expected_world_clean if expected_world_clean != "" else session_world,
		"request_id": "session_ready"
	}


func _direct_enter_backend_dev_login_world() -> void:
	var world_name := MovementMode.get_dev_test_world_name(_get_backend_dev_login_default_world_name())
	var profile_name := MovementMode.get_dev_profile_name(_get_backend_dev_login_default_profile_name())
	var network := get_node_or_null("/root/NetworkManager")
	if network != null:
		if network.has_method("get_active_session_username"):
			var session_name := str(network.get_active_session_username()).strip_edges()
			if session_name != "":
				profile_name = session_name
		if network.has_method("has_pending_join") and network.has_method("consume_pending_join") and bool(network.has_pending_join()):
			network.consume_pending_join()
		network.set("current_world_name", world_name)

	if profile_name.strip_edges() != "":
		create_or_switch_profile(profile_name)

	var cfg := ConfigFile.new()
	cfg.load("user://pixelmania_profile.cfg")
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.set_value("profile", "last_world", world_name)
	cfg.save("user://pixelmania_profile.cfg")

	if world_menu_ui != null and world_menu_ui.has_method("close_menu"):
		world_menu_ui.close_menu()

	print("[BackendDevLogin] Client dev login complete; entering world %s in %s mode." % [world_name, MovementMode.get_mode_name()])
	enter_world_by_name(world_name)
	call_deferred("_load_backend_dev_world_state_after_entry", world_name)


func _load_backend_dev_world_state_after_entry(world_name: String) -> void:
	if not MovementMode.is_netfox_real_client_launch() and not _is_trusted_movement_backend_dev_client_launch():
		return
	if not MovementMode.is_backend_dev_login_active():
		return

	await get_tree().process_frame

	var clean_world := str(world_name).strip_edges()
	if clean_world == "":
		clean_world = MovementMode.get_dev_test_world_name(_get_backend_dev_login_default_world_name())
	clean_world = clean_world.to_upper()

	var backend_base := _get_backend_dev_world_state_api_base()
	if backend_base == "":
		push_warning("[BackendDevWorldState] Could not resolve backend API base for dev world-state load.")
		return

	var request := HTTPRequest.new()
	request.name = "BackendDevWorldStateRequest"
	request.timeout = 30.0 if MovementMode.is_custom_authoritative() else 12.0
	add_child(request)

	var dev_world_state_path := "/dev/custom-movement/world-state" if MovementMode.is_custom_authoritative() else "/dev/netfox/world-state"
	var url := "%s%s?world=%s" % [backend_base, dev_world_state_path, clean_world.uri_encode()]
	print("[BackendDevWorldState] Client loading %s from %s..." % [clean_world, url])
	var error := request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		push_warning("[BackendDevWorldState] Could not start dev world-state request. error=%s" % str(error))
		return

	var response = await request.request_completed
	request.queue_free()

	var response_code := 0
	var body := PackedByteArray()
	if response is Array and response.size() >= 4:
		response_code = int(response[1])
		body = response[3]

	var body_text := body.get_string_from_utf8()
	if response_code != 200:
		push_warning("[BackendDevWorldState] Dev world-state request failed. status=%d body=%s" % [
			response_code,
			body_text.substr(0, min(240, body_text.length()))
		])
		return

	var parsed = JSON.parse_string(body_text)
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		push_warning("[BackendDevWorldState] Dev world-state response was rejected or invalid.")
		return

	var payload = parsed.get("world_state", {})
	if not (payload is Dictionary):
		push_warning("[BackendDevWorldState] Dev world-state payload was missing.")
		return

	if not payload.has("foreground") and payload.has("blocks"):
		payload["foreground"] = payload.get("blocks", [])
	if not payload.has("background") and payload.has("background_blocks"):
		payload["background"] = payload.get("background_blocks", [])
	payload["world"] = clean_world
	payload["world_name"] = clean_world
	payload["world_id"] = clean_world
	payload["respawn_player"] = false
	payload["force_player_position"] = false
	payload["world_state_reason"] = "custom_authoritative_client_backend_dev_world_load" if MovementMode.is_custom_authoritative() else "phase7_client_backend_dev_world_load"

	print("[BackendDevWorldState] Client world load success world=%s mode=%s blocks=%d collision_blocks=%d." % [
		clean_world,
		MovementMode.get_mode_name(),
		int(parsed.get("block_count", 0)),
		int(parsed.get("collision_block_count", 0))
	])
	apply_network_world_state(payload)


func _get_backend_dev_world_state_api_base() -> String:
	var network := get_node_or_null("/root/NetworkManager")
	if network != null:
		var active_base := str(network.get("active_api_base")).strip_edges()
		if active_base != "":
			return active_base.trim_suffix("/")

	var launch_base := MovementMode.get_launch_arg_value("--pixelmania-api-base", "").strip_edges()
	if launch_base != "":
		return launch_base.trim_suffix("/")

	return ""


func _finish_netfox_real_server_startup() -> void:
	print("[NetfoxReal] Server mode detected; skipping login UI.")
	if world_menu_ui != null and world_menu_ui.has_method("close_menu"):
		world_menu_ui.close_menu()
	if _should_bootstrap_netfox_real_local_server_world():
		var world_name := MovementMode.get_dev_test_world_name(DEFAULT_WORLD_NAME)
		_bootstrap_netfox_real_local_server_world(world_name)


func _should_bootstrap_netfox_real_local_server_world() -> bool:
	if not _is_netfox_real_server_launch():
		return false
	if MovementMode.get_launch_arg_value("--netfox-server-token", "").strip_edges() != "":
		return false
	if OS.get_environment("PIXELMANIA_NETFOX_SERVER_TOKEN").strip_edges() != "":
		return false
	if OS.get_environment("NETFOX_SERVER_WORLD_STATE_TOKEN").strip_edges() != "":
		return false
	return true


func _bootstrap_netfox_real_local_server_world(world_name: String) -> void:
	var clean_world_name := sanitize_world_name(world_name).to_upper()
	if clean_world_name == "":
		clean_world_name = DEFAULT_WORLD_NAME

	print("[NetfoxReal] Local server bootstrap loading world=%s for spawn/collision testing." % clean_world_name)
	current_world_name = clean_world_name
	in_world = true
	set_meta("world_entry_in_progress", true)
	set_meta("world_bulk_load_in_progress", true)
	set_meta("world_bulk_load_reason", "netfox_local_server_bootstrap")

	if save_manager != null:
		if "waiting_for_server_world_state" in save_manager:
			save_manager.waiting_for_server_world_state = false
		if save_manager.has_method("load_world"):
			save_manager.load_world()
	else:
		clear_world()
		generate_world()
		ensure_entrance_gate()

	set_meta("world_entry_in_progress", false)
	set_meta("world_bulk_load_in_progress", false)
	set_meta("world_bulk_load_reason", "")
	if has_method("setup_world_camera_limits"):
		setup_world_camera_limits()
	print("[NetfoxReal] Local server world ready world=%s blocks=%d." % [clean_world_name, blocks.size()])
	if netfox_real_manager != null and netfox_real_manager.has_method("notify_server_world_ready_from_local_bootstrap"):
		netfox_real_manager.notify_server_world_ready_from_local_bootstrap(clean_world_name)
	if netfox_real_manager != null and netfox_real_manager.has_method("_process_pending_spawn_requests"):
		netfox_real_manager.call("_process_pending_spawn_requests")


func _finish_custom_authoritative_server_startup() -> void:
	var world_name := MovementMode.get_dev_test_world_name("TEST")
	current_world_name = world_name
	in_world = true
	print("[PhaseI] Custom authoritative server mode detected; using actual main scene world=%s." % world_name)
	if world_menu_ui != null and world_menu_ui.has_method("close_menu"):
		world_menu_ui.close_menu()


func setup_gameplay_ui_manager():
	if gameplay_ui_manager == null:
		var ui_script = preload("res://Scripts/gameplay_ui_manager.gd")
		gameplay_ui_manager = Node.new()
		gameplay_ui_manager.name = "GameplayUIManager"
		gameplay_ui_manager.set_script(ui_script)
		add_child(gameplay_ui_manager)

	if gameplay_ui_manager.has_method("setup"):
		gameplay_ui_manager.setup(self)


func setup_ui_layers():
	if ui_layer == null:
		return

	ui_overhead_layer = ensure_ui_child_layer("OverheadLayer")
	ui_hud_layer = ensure_ui_child_layer("HudLayer")
	ui_panel_layer = ensure_ui_child_layer("PanelLayer")
	ui_modal_layer = ensure_ui_child_layer("ModalLayer")
	ui_system_layer = ensure_ui_child_layer("SystemLayer")


func ensure_ui_child_layer(layer_name: String) -> Control:
	if ui_layer == null:
		return null

	var layer = ui_layer.get_node_or_null(layer_name)
	if layer != null and not (layer is Control):
		ui_layer.remove_child(layer)
		layer.queue_free()
		layer = null

	if layer == null:
		layer = Control.new()
		layer.name = layer_name
		ui_layer.add_child(layer)

	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_as_relative = false
	layer.z_index = 0
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.offset_left = 0.0
	layer.offset_top = 0.0
	layer.offset_right = 0.0
	layer.offset_bottom = 0.0
	return layer as Control


func get_ui_overhead_layer() -> Node:
	if ui_overhead_layer == null or not is_instance_valid(ui_overhead_layer):
		setup_ui_layers()
	return ui_overhead_layer if ui_overhead_layer != null else ui_layer


func get_ui_hud_layer() -> Node:
	if ui_hud_layer == null or not is_instance_valid(ui_hud_layer):
		setup_ui_layers()
	return ui_hud_layer if ui_hud_layer != null else ui_layer


func get_ui_panel_layer() -> Node:
	if ui_panel_layer == null or not is_instance_valid(ui_panel_layer):
		setup_ui_layers()
	return ui_panel_layer if ui_panel_layer != null else ui_layer


func get_ui_modal_layer() -> Node:
	if ui_modal_layer == null or not is_instance_valid(ui_modal_layer):
		setup_ui_layers()
	return ui_modal_layer if ui_modal_layer != null else ui_layer


func get_ui_system_layer() -> Node:
	if ui_system_layer == null or not is_instance_valid(ui_system_layer):
		setup_ui_layers()
	return ui_system_layer if ui_system_layer != null else ui_layer


func setup_fishing_manager():
	if fishing_manager == null:
		var fishing_script = preload("res://Scripts/fishing_manager.gd")
		fishing_manager = Node.new()
		fishing_manager.name = "FishingManager"
		fishing_manager.set_script(fishing_script)
		add_child(fishing_manager)

	if fishing_manager.has_method("setup"):
		fishing_manager.setup(self)


func setup_fish_monger_manager():
	if fish_monger_manager == null:
		var fish_monger_script = preload("res://Scripts/fish_monger_manager.gd")
		fish_monger_manager = Node.new()
		fish_monger_manager.name = "FishMongerManager"
		fish_monger_manager.set_script(fish_monger_script)
		add_child(fish_monger_manager)

	if fish_monger_manager.has_method("setup"):
		fish_monger_manager.setup(self)


func setup_item_gameplay_manager():
	if item_gameplay_manager == null:
		var item_script = preload("res://Scripts/item_gameplay_manager.gd")
		item_gameplay_manager = Node.new()
		item_gameplay_manager.name = "ItemGameplayManager"
		item_gameplay_manager.set_script(item_script)
		add_child(item_gameplay_manager)

	if item_gameplay_manager.has_method("setup"):
		item_gameplay_manager.setup(self)

func setup_vending_preview_manager():
	if vending_preview_manager == null:
		var preview_script = preload("res://Scripts/vending_preview_manager.gd")
		vending_preview_manager = Node.new()
		vending_preview_manager.name = "VendingPreviewManager"
		vending_preview_manager.set_script(preview_script)
		add_child(vending_preview_manager)

	if vending_preview_manager.has_method("setup"):
		vending_preview_manager.setup(self)

func setup_environment_manager():
	if environment_manager == null:
		var environment_script = preload("res://Scripts/environment_manager.gd")
		environment_manager = Node.new()
		environment_manager.name = "EnvironmentManager"
		environment_manager.set_script(environment_script)
		add_child(environment_manager)

	if environment_manager.has_method("setup"):
		environment_manager.setup(self)

func setup_input_manager():
	if input_manager == null:
		var input_script = preload("res://Scripts/input_manager.gd")
		input_manager = Node.new()
		input_manager.name = "InputManager"
		input_manager.set_script(input_script)
		add_child(input_manager)

	if input_manager.has_method("setup"):
		input_manager.setup(self)

func setup_mobile_controls():
	if ui_layer == null:
		return

	var hud_layer = get_ui_hud_layer()
	var controls = hud_layer.get_node_or_null("MobileControls")
	if controls == null and hud_layer != ui_layer:
		controls = ui_layer.get_node_or_null("MobileControls")

	if controls == null:
		var controls_script = preload("res://Scripts/mobile_controls.gd")
		controls = Control.new()
		controls.name = "MobileControls"
		controls.set_script(controls_script)
		hud_layer.add_child(controls)
	elif controls.get_parent() != hud_layer:
		var old_parent = controls.get_parent()
		if old_parent != null:
			old_parent.remove_child(controls)
		hud_layer.add_child(controls)

	if controls.has_method("setup"):
		controls.setup(self)

func setup_account_manager():
	if account_manager == null:
		var account_script = preload("res://Scripts/account_manager.gd")
		account_manager = Node.new()
		account_manager.name = "AccountManager"
		account_manager.set_script(account_script)
		add_child(account_manager)

	if account_manager.has_method("setup"):
		account_manager.setup(self)


func setup_background_manager():
	if background_manager == null:
		var bg_script = preload("res://Scripts/background_manager.gd")
		background_manager = Node.new()
		background_manager.name = "BackgroundManager"
		background_manager.set_script(bg_script)
		add_child(background_manager)
	if background_manager.has_method("setup"):
		background_manager.setup(self)

func apply_world_background_theme(theme_name: String):
	var clean_theme := theme_name.strip_edges().to_lower()
	active_world_theme = clean_theme
	if background_manager != null and background_manager.has_method("set_theme"):
		background_manager.set_theme(clean_theme)
	set_city_theme_rain_active(clean_theme == "city")


func set_city_theme_rain_active(active: bool):
	if active:
		if city_theme_rain_fx == null or not is_instance_valid(city_theme_rain_fx):
			if not ResourceLoader.exists(CITY_THEME_RAIN_FX_SCENE_PATH):
				return

			var rain_scene := load(CITY_THEME_RAIN_FX_SCENE_PATH) as PackedScene
			if rain_scene == null:
				return

			city_theme_rain_fx = rain_scene.instantiate()
			add_child(city_theme_rain_fx)

		if city_theme_rain_fx.has_method("start"):
			city_theme_rain_fx.start()
		else:
			city_theme_rain_fx.visible = true
		return

	if city_theme_rain_fx != null and is_instance_valid(city_theme_rain_fx):
		if city_theme_rain_fx.has_method("stop"):
			city_theme_rain_fx.stop()
		else:
			city_theme_rain_fx.visible = false


func reset_world_background_theme():
	apply_world_background_theme("")


func setup_sound_manager():
	if sound_manager == null:
		var snd_script = preload("res://Scripts/sound_manager.gd")
		sound_manager = Node.new()
		sound_manager.name = "SoundManager"
		sound_manager.set_script(snd_script)
		add_child(sound_manager)
	if sound_manager.has_method("setup"):
		sound_manager.setup(self)


func setup_world_loading_ui_manager():
	if world_loading_ui_manager == null:
		var loading_script = preload("res://Scripts/world_loading_ui_manager.gd")
		world_loading_ui_manager = Node.new()
		world_loading_ui_manager.name = "WorldLoadingUIManager"
		world_loading_ui_manager.set_script(loading_script)
		add_child(world_loading_ui_manager)

	if world_loading_ui_manager.has_method("setup"):
		world_loading_ui_manager.setup(self)


func setup_world_state_sync_manager():
	if world_state_sync_manager == null:
		var state_sync_script = preload("res://Scripts/world_state_sync_manager.gd")
		world_state_sync_manager = Node.new()
		world_state_sync_manager.name = "WorldStateSyncManager"
		world_state_sync_manager.set_script(state_sync_script)
		add_child(world_state_sync_manager)

	if world_state_sync_manager.has_method("setup"):
		world_state_sync_manager.setup(self)


func play_sound_punch(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_punch"):
		sound_manager.play_punch(source_position)

func play_sound_break(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_break"):
		sound_manager.play_break(source_position)

func play_sound_place(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_place"):
		sound_manager.play_place(source_position)

func play_sound_jump(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_jump"):
		sound_manager.play_jump(source_position)

func play_sound_water_jump(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_water_jump"):
		sound_manager.play_water_jump(source_position)

func play_sound_lava_fire_hit(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_lava_fire_hit"):
		sound_manager.play_lava_fire_hit(source_position)

func play_sound_entrance(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_entrance"):
		sound_manager.play_entrance(source_position)

func play_sound_vend_purchase(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_vend_purchase"):
		sound_manager.play_vend_purchase(source_position)


func play_sound_join_world(source_position: Vector2 = Vector2(INF, INF)):
	if sound_manager != null and sound_manager.has_method("play_join_world"):
		sound_manager.play_join_world(source_position)


func set_sfx_volume(value: float) -> void:
	if sound_manager != null and sound_manager.has_method("set_sfx_volume"):
		sound_manager.set_sfx_volume(value)


func get_sfx_volume() -> float:
	if sound_manager != null and sound_manager.has_method("get_sfx_volume"):
		return float(sound_manager.get_sfx_volume())

	return 1.0


func spawn_block_hit_particles(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground"):
	if particle_manager != null and particle_manager.has_method("spawn_block_hit"):
		particle_manager.spawn_block_hit(grid_pos, block_type, layer)


func spawn_blue_hit_particles(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground", mirror_direction: bool = false):
	if particle_manager != null and particle_manager.has_method("spawn_blue_hit_block"):
		particle_manager.spawn_blue_hit_block(grid_pos, block_type, layer, mirror_direction)


func spawn_thunder_particles(start_world_position: Vector2, end_world_position: Vector2, mirror_direction: bool = false):
	if particle_manager != null and particle_manager.has_method("spawn_thunder_arc"):
		particle_manager.spawn_thunder_arc(start_world_position, end_world_position, mirror_direction)


func spawn_water_surge_beam_particles(start_world_position: Vector2, end_world_position: Vector2, mirror_direction: bool = false):
	if particle_manager != null and particle_manager.has_method("spawn_water_surge_beam"):
		particle_manager.spawn_water_surge_beam(start_world_position, end_world_position, mirror_direction)


func spawn_fishing_reward_confetti_particles(world_position: Vector2, rarity: String):
	if particle_manager != null and particle_manager.has_method("spawn_fishing_reward_confetti"):
		particle_manager.spawn_fishing_reward_confetti(world_position, rarity)


func spawn_fishing_reward_confetti_ui_particles(canvas_position: Vector2, rarity: String) -> bool:
	if ui_layer == null:
		return false
	if particle_manager == null or not particle_manager.has_method("spawn_fishing_reward_confetti_on_canvas"):
		return false

	particle_manager.spawn_fishing_reward_confetti_on_canvas(ui_layer, canvas_position, rarity)
	return true


func handle_network_fishing_reward_fx(data: Dictionary):
	var payload_world := str(data.get("world", data.get("current_world", ""))).strip_edges()
	if payload_world != "" and payload_world != current_world_name:
		return

	var rarity := str(data.get("rarity", "")).strip_edges().to_lower()
	if rarity != "epic" and rarity != "legendary":
		return

	if _is_local_fishing_reward_fx(data):
		var ui_position := _get_local_fishing_reward_confetti_ui_position()
		if is_finite(ui_position.x) and is_finite(ui_position.y):
			if spawn_fishing_reward_confetti_ui_particles(ui_position, rarity):
				return

	var effect_position := Vector2(
		get_network_float(data.get("x"), 0.0),
		get_network_float(data.get("y"), 0.0)
	) + Vector2(0.0, -38.0)
	spawn_fishing_reward_confetti_particles(effect_position, rarity)


func _is_local_fishing_reward_fx(data: Dictionary) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	var payload_player_id := str(data.get("player_id", data.get("source_player_id", ""))).strip_edges()
	var local_player_id := str(network.get("player_id")).strip_edges()
	return payload_player_id != "" and local_player_id != "" and payload_player_id == local_player_id


func _get_local_fishing_reward_confetti_ui_position() -> Vector2:
	if fishing_manager != null and fishing_manager.has_method("get_fishing_reward_confetti_ui_position"):
		return fishing_manager.get_fishing_reward_confetti_ui_position()

	return Vector2(INF, INF)


func spawn_neptune_trident_block_hit_particles(grid_pos: Vector2i, _block_type: String = "", _layer: String = "foreground", source_tool: String = ""):
	if is_ant_sword_source_tool(source_tool):
		spawn_ant_sword_slash_particles(get_block_center_world_position(grid_pos))
		return

	if not is_neptune_trident_source_tool(source_tool):
		return

	var target_position := get_block_center_world_position(grid_pos)
	spawn_water_surge_beam_particles(get_local_weapon_edge_world_position(target_position), target_position, player_facing_direction < 0)


func spawn_hand_item_swing_particles(target_world_position: Vector2 = Vector2(INF, INF), source_tool: String = "") -> bool:
	if is_ant_sword_source_tool(source_tool):
		return spawn_ant_sword_slash_particles(target_world_position)

	if is_neptune_trident_source_tool(source_tool):
		return spawn_neptune_trident_swing_particles(target_world_position)

	return false


func spawn_neptune_trident_swing_particles(target_world_position: Vector2 = Vector2(INF, INF)) -> bool:
	if player == null:
		return false

	var target_position: Vector2 = target_world_position
	if not is_finite(target_position.x) or not is_finite(target_position.y):
		target_position = get_local_hand_item_swing_target_position()

	var start_position: Vector2 = get_local_weapon_edge_world_position(target_position)
	if start_position.distance_squared_to(target_position) < 16.0:
		var direction: Vector2 = (target_position - player.global_position).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT * (1.0 if player_facing_direction >= 0 else -1.0)
		target_position = start_position + direction * HAND_ITEM_SWING_RANGE_PIXELS

	spawn_water_surge_beam_particles(start_position, target_position, player_facing_direction < 0)
	return true


func spawn_ant_sword_slash_particles(target_world_position: Vector2 = Vector2(INF, INF)) -> bool:
	if player == null:
		return false

	var target_position: Vector2 = target_world_position
	if not is_finite(target_position.x) or not is_finite(target_position.y):
		target_position = get_local_hand_item_swing_target_position()

	var start_position := get_local_weapon_edge_world_position(target_position)
	if start_position.distance_squared_to(target_position) < 16.0:
		var direction: Vector2 = (target_position - player.global_position).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT * (1.0 if player_facing_direction >= 0 else -1.0)
		target_position = start_position + direction * HAND_ITEM_SWING_RANGE_PIXELS

	return spawn_rotating_sword_slash_at(start_position, target_position, player_facing_direction)


func spawn_ant_sword_actor_swing_particles(actor: Node2D, facing_direction: int = 1) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false

	var safe_facing: int = -1 if facing_direction < 0 else 1
	var target_position := actor.global_position + Vector2(float(safe_facing) * HAND_ITEM_SWING_RANGE_PIXELS, -4.0)
	var start_position := get_actor_weapon_edge_world_position(actor, safe_facing, target_position)
	if start_position.distance_squared_to(target_position) < 16.0:
		target_position = start_position + Vector2(float(safe_facing) * HAND_ITEM_SWING_RANGE_PIXELS, -4.0)

	return spawn_rotating_sword_slash_at(start_position, target_position, safe_facing)


func spawn_neptune_trident_network_hit_particles(grid_pos: Vector2i, _block_type: String = "", _layer: String = "foreground", source_tool: String = "", source_data: Dictionary = {}):
	if is_ant_sword_source_tool(source_tool, false):
		var ant_target_position := get_block_center_world_position(grid_pos)
		var ant_actor_facing := get_network_actor_facing(source_data)
		var ant_actor = get_network_actor_node(source_data)
		var now_msec := Time.get_ticks_msec()
		if ant_actor != null and is_instance_valid(ant_actor):
			var recent_msec := now_msec - int(ant_actor.get_meta("last_ant_sword_slash_fx_msec", 0))
			if recent_msec >= 0 and recent_msec < ANT_SWORD_SLASH_REMOTE_DEDUPE_MSEC:
				return

		var spawned := spawn_rotating_sword_slash_at(
			get_network_actor_weapon_edge_world_position(source_data, ant_target_position),
			ant_target_position,
			ant_actor_facing
		)
		if spawned and ant_actor != null and is_instance_valid(ant_actor):
			ant_actor.set_meta("last_ant_sword_slash_fx_msec", now_msec)
		return

	if not is_neptune_trident_source_tool(source_tool, false):
		return

	var target_position := get_block_center_world_position(grid_pos)
	var actor_facing := get_network_actor_facing(source_data)
	spawn_water_surge_beam_particles(get_network_actor_weapon_edge_world_position(source_data, target_position), target_position, actor_facing < 0)


func get_rotating_sword_slash_scene() -> PackedScene:
	if rotating_sword_slash_scene != null:
		if rotating_sword_slash_scene.resource_path == ROTATING_SWORD_SLASH_FX_SCENE_PATH:
			return rotating_sword_slash_scene
		rotating_sword_slash_scene = null
	if not ResourceLoader.exists(ROTATING_SWORD_SLASH_FX_SCENE_PATH):
		return null

	var loaded_scene = load(ROTATING_SWORD_SLASH_FX_SCENE_PATH)
	if loaded_scene is PackedScene:
		rotating_sword_slash_scene = loaded_scene
	return rotating_sword_slash_scene


func spawn_rotating_sword_slash_at(start_position: Vector2, target_position: Vector2, facing_direction: int) -> bool:
	if not is_finite(start_position.x) or not is_finite(start_position.y):
		return false
	if not is_finite(target_position.x) or not is_finite(target_position.y):
		return false

	var slash_scene := get_rotating_sword_slash_scene()
	if slash_scene == null:
		return false

	var effect = slash_scene.instantiate()
	if not (effect is Node2D):
		if effect != null:
			effect.queue_free()
		return false

	var slash_node := effect as Node2D
	slash_node.set("preview_emitting", false)
	slash_node.set("auto_restart_preview", false)
	slash_node.set("auto_free_on_one_shot", true)
	add_child(slash_node)
	slash_node.global_position = start_position

	var slash_direction := target_position - start_position
	if slash_direction.length_squared() < 0.01:
		slash_direction = Vector2.RIGHT * (1.0 if facing_direction >= 0 else -1.0)
	slash_node.rotation = slash_direction.angle()

	if slash_node.has_method("play_once"):
		slash_node.play_once(facing_direction)
	elif slash_node.has_method("restart"):
		slash_node.restart()

	return true


func get_block_center_world_position(grid_pos: Vector2i) -> Vector2:
	return Vector2(float(grid_pos.x * BLOCK_SIZE), float(grid_pos.y * BLOCK_SIZE))


func get_local_weapon_edge_world_position(target_position: Vector2) -> Vector2:
	return get_actor_weapon_edge_world_position(player, player_facing_direction, target_position)


func get_local_hand_item_swing_target_position() -> Vector2:
	if player == null:
		return Vector2.ZERO

	var facing := 1.0 if player_facing_direction >= 0 else -1.0
	return player.global_position + Vector2(facing * HAND_ITEM_SWING_RANGE_PIXELS, -4.0)


func get_network_actor_weapon_edge_world_position(source_data: Dictionary, target_position: Vector2) -> Vector2:
	var actor = get_network_actor_node(source_data)
	var actor_facing := get_network_actor_facing(source_data, actor)
	if actor != null and is_instance_valid(actor):
		return get_actor_weapon_edge_world_position(actor, actor_facing, target_position)

	var fallback_position := get_network_actor_position_from_data(source_data)
	if fallback_position != Vector2(INF, INF):
		return get_weapon_edge_from_position(fallback_position, actor_facing, target_position)

	return target_position + Vector2(float(-BLOCK_SIZE), -6.0)


func get_actor_weapon_edge_world_position(actor, facing_direction: int, target_position: Vector2) -> Vector2:
	if actor == null or not is_instance_valid(actor):
		return target_position + Vector2(float(-BLOCK_SIZE), -6.0)

	var actor_position: Vector2 = actor.global_position
	var marker_position := get_actor_weapon_marker_world_position(actor)
	if marker_position != Vector2(INF, INF):
		var marker_delta := marker_position - actor_position
		var target_direction := (target_position - actor_position).normalized()
		if target_direction.length_squared() < 0.01:
			target_direction = Vector2.RIGHT * (1.0 if facing_direction >= 0 else -1.0)
		if marker_delta.length() > 3.0 and marker_delta.dot(target_direction) > -8.0:
			return marker_position

	var sprite_tip_position := get_actor_hand_item_tip_world_position(actor, target_position)
	if sprite_tip_position != Vector2(INF, INF):
		return sprite_tip_position

	return get_weapon_edge_from_position(actor_position, facing_direction, target_position)


func get_weapon_edge_from_position(actor_position: Vector2, facing_direction: int, target_position: Vector2) -> Vector2:
	var direction := (target_position - actor_position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT * (1.0 if facing_direction >= 0 else -1.0)

	return actor_position + direction * 25.0 + Vector2(0.0, -5.0)


func get_actor_weapon_marker_world_position(actor) -> Vector2:
	if actor == null or not is_instance_valid(actor):
		return Vector2(INF, INF)

	for marker_path in [
		"PlayerVisual/HandItem/ThunderStart",
		"PlayerVisual/HandItem/FishingLineStart",
		"PlayerVisual/HandItem/HandItemAnimated/ThunderStart",
	]:
		var marker = actor.get_node_or_null(marker_path)
		if marker != null and marker is Node2D:
			return marker.global_position

	return Vector2(INF, INF)


func get_actor_hand_item_tip_world_position(actor, target_position: Vector2) -> Vector2:
	if actor == null or not is_instance_valid(actor):
		return Vector2(INF, INF)

	var hand_sprite = actor.get_node_or_null("PlayerVisual/HandItem/HandItemAnimated")
	if hand_sprite == null or not (hand_sprite is AnimatedSprite2D):
		return Vector2(INF, INF)
	if not hand_sprite.visible:
		return Vector2(INF, INF)

	var texture := get_animated_sprite_current_texture(hand_sprite)
	var tip_distance := 24.0
	if texture != null:
		tip_distance = maxf(12.0, float(texture.get_width()) * 0.5)

	var left_tip: Vector2 = hand_sprite.to_global(Vector2(-tip_distance, 0.0))
	var right_tip: Vector2 = hand_sprite.to_global(Vector2(tip_distance, 0.0))
	if left_tip.distance_squared_to(target_position) < right_tip.distance_squared_to(target_position):
		return left_tip
	return right_tip


func get_animated_sprite_current_texture(sprite: AnimatedSprite2D) -> Texture2D:
	if sprite == null or sprite.sprite_frames == null:
		return null

	var animation_name: StringName = sprite.animation
	if not sprite.sprite_frames.has_animation(animation_name):
		return null

	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return null

	var frame_index: int = clampi(sprite.frame, 0, frame_count - 1)
	return sprite.sprite_frames.get_frame_texture(animation_name, frame_index)


func get_network_actor_node(source_data: Dictionary):
	if player_manager == null:
		return null

	var remote_players = player_manager.get("remote_players")
	if not (remote_players is Dictionary):
		return null

	var remote_id := str(source_data.get("player_id", source_data.get("source_player_id", ""))).strip_edges()
	if remote_id != "" and remote_players.has(remote_id):
		var direct_remote_player = remote_players.get(remote_id)
		if direct_remote_player != null and is_instance_valid(direct_remote_player):
			return direct_remote_player

	var actor_name := str(source_data.get("username", source_data.get("account_username", source_data.get("name", "")))).strip_edges().to_lower()
	if actor_name == "":
		return null

	for candidate_id in remote_players.keys():
		var candidate_player = remote_players[candidate_id]
		if candidate_player == null or not is_instance_valid(candidate_player):
			continue
		var remote_name := str(candidate_player.get_meta("remote_name", "")).strip_edges().to_lower()
		var remote_identity := str(candidate_player.get_meta("remote_identity", "")).strip_edges().to_lower()
		if remote_name == actor_name or remote_identity == actor_name:
			return candidate_player

	return null


func get_network_actor_facing(source_data: Dictionary, actor = null) -> int:
	if source_data.has("actor_facing"):
		return -1 if int(source_data.get("actor_facing", 1)) < 0 else 1
	if source_data.has("facing"):
		return -1 if int(source_data.get("facing", 1)) < 0 else 1
	if actor != null and is_instance_valid(actor):
		return -1 if int(actor.get_meta("facing", 1)) < 0 else 1
	return 1


func get_network_actor_position_from_data(source_data: Dictionary) -> Vector2:
	if not source_data.has("actor_x") or not source_data.has("actor_y"):
		return Vector2(INF, INF)

	var actor_x := get_network_float(source_data.get("actor_x"), INF)
	var actor_y := get_network_float(source_data.get("actor_y"), INF)
	if not is_finite(actor_x) or not is_finite(actor_y):
		return Vector2(INF, INF)

	return Vector2(actor_x, actor_y)


func get_network_float(value, fallback: float = 0.0) -> float:
	if value is int or value is float:
		var numeric_value := float(value)
		if is_finite(numeric_value):
			return numeric_value
	if value is String:
		var text: String = value.strip_edges()
		if text != "":
			var parsed_value: float = text.to_float()
			if is_finite(parsed_value):
				return parsed_value
	return fallback


func is_neptune_trident_source_tool(source_tool: String = "", allow_equipped_fallback: bool = true) -> bool:
	var clean_tool := str(source_tool).strip_edges().to_lower()
	if clean_tool == "neptune_trident":
		return true

	if allow_equipped_fallback:
		var clean_equipped := str(equipped_tool).strip_edges().to_lower()
		if clean_equipped == "neptune_trident":
			return true

	if clean_tool == "" and selected_item_category == "tool":
		clean_tool = str(selected_item_type).strip_edges().to_lower()

	return clean_tool == "neptune_trident"


func is_ant_sword_source_tool(source_tool: String = "", allow_equipped_fallback: bool = true) -> bool:
	var clean_tool := str(source_tool).strip_edges().to_lower()
	if clean_tool == "ant_sword":
		return true

	if allow_equipped_fallback:
		var clean_equipped := str(equipped_tool).strip_edges().to_lower()
		if clean_equipped == "ant_sword":
			return true

	if clean_tool == "" and selected_item_category == "tool":
		clean_tool = str(selected_item_type).strip_edges().to_lower()

	return clean_tool == "ant_sword"


func spawn_block_break_particles(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground"):
	if particle_manager != null and particle_manager.has_method("spawn_block_break"):
		particle_manager.spawn_block_break(grid_pos, block_type, layer)


func spawn_block_place_particles(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground"):
	if particle_manager != null and particle_manager.has_method("spawn_block_place"):
		particle_manager.spawn_block_place(grid_pos, block_type, layer)


func spawn_tree_growth_particles(grid_pos: Vector2i, block_type: String = "", stage: int = 0):
	if particle_manager != null and particle_manager.has_method("spawn_tree_growth"):
		particle_manager.spawn_tree_growth(grid_pos, block_type, stage)


func spawn_tree_break_particles(grid_pos: Vector2i, block_type: String = ""):
	if particle_manager != null and particle_manager.has_method("spawn_tree_break"):
		particle_manager.spawn_tree_break(grid_pos, block_type)


func spawn_water_splash_particles(world_position: Vector2, intensity: float = 1.0):
	if particle_manager != null and particle_manager.has_method("spawn_water_splash"):
		particle_manager.spawn_water_splash(world_position, intensity)


func spawn_underwater_bubbles_particles(world_position: Vector2, count: int = 1):
	if particle_manager != null and particle_manager.has_method("spawn_underwater_bubbles"):
		particle_manager.spawn_underwater_bubbles(world_position, count)


func spawn_player_fire_particles(world_position: Vector2, body_half_extents: Vector2 = Vector2(10.0, 16.0), intensity: float = 1.0):
	if particle_manager != null and particle_manager.has_method("spawn_player_fire"):
		particle_manager.spawn_player_fire(world_position, body_half_extents, intensity)


func spawn_player_water_splash_particles(world_position: Vector2, body_half_extents: Vector2 = Vector2(10.0, 16.0), water_surface_y: float = INF, intensity: float = 1.0):
	if particle_manager != null and particle_manager.has_method("spawn_player_water_splash"):
		particle_manager.spawn_player_water_splash(world_position, body_half_extents, water_surface_y, intensity)


func spawn_oil_refinery_smoke_particles(world_position: Vector2, count: int = 5, texture_path: String = ""):
	if particle_manager != null and particle_manager.has_method("spawn_oil_refinery_smoke"):
		particle_manager.spawn_oil_refinery_smoke(world_position, count, texture_path)


func setup_reach_indicator_manager():
	if reach_indicator_manager == null:
		var ri_script = preload("res://Scripts/reach_indicator_manager.gd")
		reach_indicator_manager = Node2D.new()
		reach_indicator_manager.name = "ReachIndicatorManager"
		reach_indicator_manager.set_script(ri_script)
		add_child(reach_indicator_manager)
	if reach_indicator_manager.has_method("setup"):
		reach_indicator_manager.setup(self)


func setup_username_label_manager():
	if username_label_manager == null:
		var ul_script = preload("res://Scripts/username_label_manager.gd")
		username_label_manager = Node.new()
		username_label_manager.name = "UsernameLabelManager"
		username_label_manager.set_script(ul_script)
		add_child(username_label_manager)
	if username_label_manager.has_method("setup"):
		username_label_manager.setup(self)


func update_username_label():
	if username_label_manager != null and username_label_manager.has_method("update_text"):
		username_label_manager.update_text()


func setup_world_lock_manager():
	if world_lock_manager == null:
		var lock_script = load("res://Scripts/world_lock_manager.gd")
		if lock_script == null:
			if has_method("show_notification"):
				show_notification("World Lock manager script failed to load.")
			return
		if not (lock_script is Script):
			if has_method("show_notification"):
				show_notification("World Lock manager script is not valid.")
			return
		world_lock_manager = Node.new()
		world_lock_manager.name = "WorldLockManager"
		world_lock_manager.set_script(lock_script)
		add_child(world_lock_manager)
	if world_lock_manager.has_method("setup"):
		world_lock_manager.setup(self)


func setup_world_lock_ui():
	if ui_layer == null:
		return
	if world_lock_ui == null:
		world_lock_ui = ui_layer.get_node_or_null("WorldLockUI")
	if world_lock_ui != null and (world_lock_ui.scene_file_path != "res://Scenes/ui/locks/WorldLockGUI.tscn" or world_lock_ui.get_node_or_null("Window") == null):
		ui_layer.remove_child(world_lock_ui)
		world_lock_ui.queue_free()
		world_lock_ui = null
	if world_lock_ui == null:
		var world_lock_scene = preload("res://Scenes/ui/locks/WorldLockGUI.tscn")
		world_lock_ui = world_lock_scene.instantiate()
		world_lock_ui.name = "WorldLockUI"
		ui_layer.add_child(world_lock_ui)
	if world_lock_ui.has_method("setup"):
		world_lock_ui.setup(self, ui_layer)


func open_world_lock_ui(grid_pos: Vector2i):
	if world_lock_ui == null:
		setup_world_lock_ui()
	if world_lock_ui != null and world_lock_ui.has_method("open_world_lock"):
		world_lock_ui.open_world_lock(grid_pos)


func close_world_lock_ui():
	if world_lock_ui != null and world_lock_ui.has_method("close_world_lock"):
		world_lock_ui.close_world_lock()


func is_world_lock_ui_open() -> bool:
	if world_lock_ui != null and world_lock_ui.has_method("is_world_lock_open"):
		return world_lock_ui.is_world_lock_open()
	return false


func setup_area_lock_ui():
	if ui_layer == null:
		return
	if area_lock_ui == null:
		area_lock_ui = ui_layer.get_node_or_null("AreaLockGUI")
	if area_lock_ui == null:
		var area_lock_scene = load("res://Scenes/ui/locks/AreaLockGUI.tscn")
		if area_lock_scene == null:
			if has_method("show_notification"):
				show_notification("Area Lock UI scene failed to load.")
			return
		area_lock_ui = area_lock_scene.instantiate()
		area_lock_ui.name = "AreaLockGUI"
		ui_layer.add_child(area_lock_ui)
	if area_lock_ui.has_method("setup"):
		area_lock_ui.setup(self, world_lock_manager)


func setup_area_lock_highlight_overlay():
	if area_lock_highlight_overlay == null:
		area_lock_highlight_overlay = get_node_or_null("AreaLockHighlightOverlay")
	if area_lock_highlight_overlay == null:
		var overlay_script = load("res://Scripts/area_lock_highlight_overlay.gd")
		if overlay_script == null:
			if has_method("show_notification"):
				show_notification("Area Lock highlight script failed to load.")
			return
		area_lock_highlight_overlay = Node2D.new()
		area_lock_highlight_overlay.name = "AreaLockHighlightOverlay"
		area_lock_highlight_overlay.set_script(overlay_script)
		add_child(area_lock_highlight_overlay)
	if area_lock_highlight_overlay.has_method("setup"):
		area_lock_highlight_overlay.setup(self, world_lock_manager)


func refresh_area_lock_highlight_overlay():
	if area_lock_highlight_overlay == null:
		setup_area_lock_highlight_overlay()
	if area_lock_highlight_overlay != null and area_lock_highlight_overlay.has_method("refresh"):
		area_lock_highlight_overlay.refresh()


func open_area_lock_ui(grid_pos: Vector2i):
	if area_lock_ui == null:
		setup_area_lock_ui()
	if area_lock_ui != null and area_lock_ui.has_method("open_area_lock"):
		area_lock_ui.open_area_lock(grid_pos)


func close_area_lock_ui():
	if area_lock_ui != null and area_lock_ui.has_method("close"):
		area_lock_ui.close()


func is_area_lock_ui_open() -> bool:
	if area_lock_ui != null and area_lock_ui.has_method("is_open"):
		return bool(area_lock_ui.is_open())
	return false


func handle_area_lock_player_lookup_result(request_id: String, data: Dictionary, context: Dictionary = {}) -> bool:
	if area_lock_ui != null and area_lock_ui.has_method("handle_player_state_lookup_result"):
		return bool(area_lock_ui.handle_player_state_lookup_result(request_id, data, context))
	return false


func can_current_player_build() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_build"):
		return world_lock_manager.can_current_player_build()
	return true


func can_current_player_build_at(grid_pos: Vector2i) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_build_at"):
		return bool(world_lock_manager.can_current_player_build_at(grid_pos))

	return can_current_player_build()


func can_current_player_configure_door() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_configure_door"):
		return bool(world_lock_manager.can_current_player_configure_door())

	return can_current_player_build()


func can_current_player_toggle_door_lock() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_toggle_door_lock"):
		return bool(world_lock_manager.can_current_player_toggle_door_lock())

	return can_current_player_toggle_wooden_entrance()


func can_current_player_pass_door() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_pass_door"):
		return bool(world_lock_manager.can_current_player_pass_door())

	return can_current_player_pass_wooden_entrance()


func can_current_player_break_block(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_break_block"):
		return world_lock_manager.can_current_player_break_block(block_type)

	return true


func can_current_player_break_block_at(block_type: String, grid_pos: Vector2i) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_break_block_at"):
		return bool(world_lock_manager.can_current_player_break_block_at(block_type, grid_pos))

	return can_current_player_break_block(block_type)


func can_current_player_place_block(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_place_block"):
		return world_lock_manager.can_current_player_place_block(block_type)

	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_build"):
		return world_lock_manager.can_current_player_build()

	return true


func can_current_player_place_block_at(block_type: String, grid_pos: Vector2i) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_place_block_at"):
		return bool(world_lock_manager.can_current_player_place_block_at(block_type, grid_pos))

	return can_current_player_place_block(block_type)


func can_current_player_interact_with_block(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_interact_with_block"):
		return world_lock_manager.can_current_player_interact_with_block(block_type)

	return true


func can_current_player_interact_with_block_at(block_type: String, grid_pos: Vector2i) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_interact_with_block_at"):
		return bool(world_lock_manager.can_current_player_interact_with_block_at(block_type, grid_pos))

	return can_current_player_interact_with_block(block_type)


func can_current_player_toggle_wooden_entrance() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_toggle_wooden_entrance"):
		return bool(world_lock_manager.can_current_player_toggle_wooden_entrance())

	return true

func can_current_player_toggle_anti_punch() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_toggle_anti_punch"):
		return bool(world_lock_manager.can_current_player_toggle_anti_punch())

	return can_current_player_toggle_wooden_entrance()

func can_current_player_toggle_anti_talk() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_toggle_anti_talk"):
		return bool(world_lock_manager.can_current_player_toggle_anti_talk())

	return can_current_player_toggle_wooden_entrance()

func can_current_player_toggle_anti_gravity() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_toggle_anti_gravity"):
		return bool(world_lock_manager.can_current_player_toggle_anti_gravity())

	return can_current_player_toggle_wooden_entrance()

func can_current_player_view_cctv() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_view_cctv"):
		return bool(world_lock_manager.can_current_player_view_cctv())

	return can_current_player_toggle_wooden_entrance()

func can_current_player_manage_bulletin_board() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_manage_bulletin_board"):
		return bool(world_lock_manager.can_current_player_manage_bulletin_board())

	return false

func can_current_player_use_oil_refinery() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_use_oil_refinery"):
		return bool(world_lock_manager.can_current_player_use_oil_refinery())

	return can_current_player_toggle_wooden_entrance()

func can_current_player_use_battery_charger() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_use_battery_charger"):
		return bool(world_lock_manager.can_current_player_use_battery_charger())
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_use_oil_refinery"):
		return bool(world_lock_manager.can_current_player_use_oil_refinery())

	return can_current_player_toggle_wooden_entrance()

func can_current_player_use_theme_machine_at(grid_pos: Vector2i) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_use_theme_machine_at"):
		return bool(world_lock_manager.can_current_player_use_theme_machine_at(grid_pos))

	return can_current_player_build_at(grid_pos)

func can_current_player_bypass_anti_talk() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_bypass_anti_talk"):
		return bool(world_lock_manager.can_current_player_bypass_anti_talk())

	return false

func can_current_player_pass_wooden_entrance() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_pass_wooden_entrance"):
		return bool(world_lock_manager.can_current_player_pass_wooden_entrance())

	return true

func on_world_lock_block_placed(grid_pos: Vector2i, block_type: String = "world_lock"):
	if world_lock_manager != null and world_lock_manager.has_method("on_world_lock_block_placed"):
		return world_lock_manager.on_world_lock_block_placed(grid_pos, block_type)

	return

func on_world_lock_block_broken(grid_pos: Vector2i):
	if world_lock_manager != null and world_lock_manager.has_method("on_world_lock_block_broken"):
		return world_lock_manager.on_world_lock_block_broken(grid_pos)

	return


func on_area_lock_block_placed(grid_pos: Vector2i, block_type: String = "small_lock"):
	if world_lock_manager != null and world_lock_manager.has_method("on_area_lock_block_placed"):
		return world_lock_manager.on_area_lock_block_placed(grid_pos, block_type)

	return


func on_area_lock_block_broken(grid_pos: Vector2i):
	if world_lock_manager != null and world_lock_manager.has_method("on_area_lock_block_broken"):
		return world_lock_manager.on_area_lock_block_broken(grid_pos)

	return


func get_world_lock_save_data() -> Dictionary:
	if world_lock_manager != null and world_lock_manager.has_method("get_save_data"):
		return world_lock_manager.get_save_data()

	return {}


func get_area_locks_save_data() -> Array:
	if world_lock_manager != null and world_lock_manager.has_method("get_area_locks_save_data"):
		return world_lock_manager.get_area_locks_save_data()

	return []


func load_world_lock_save_data(data: Dictionary):
	if world_lock_manager != null and world_lock_manager.has_method("load_save_data"):
		return world_lock_manager.load_save_data(data)

	return


func load_area_locks_save_data(data):
	if world_lock_manager != null and world_lock_manager.has_method("load_area_locks_save_data"):
		return world_lock_manager.load_area_locks_save_data(data)

	return


func is_world_lock_block_type(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("is_world_lock_block_type"):
		return bool(world_lock_manager.is_world_lock_block_type(block_type))

	var clean_type := str(block_type).strip_edges().to_lower()
	return clean_type == "world_lock" or clean_type == "super_world_lock"


func is_area_lock_block_type(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("is_area_lock_block_type"):
		return bool(world_lock_manager.is_area_lock_block_type(block_type))

	var clean_type := str(block_type).strip_edges().to_lower()
	return clean_type == "small_lock" or clean_type == "medium_lock" or clean_type == "big_lock"


func get_world_lock_block_type() -> String:
	if world_lock_manager != null and world_lock_manager.has_method("get_lock_block_type"):
		return str(world_lock_manager.get_lock_block_type())

	return "world_lock"


func is_super_world_lock_active() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("is_super_world_lock_active"):
		return bool(world_lock_manager.is_super_world_lock_active())

	return false


func get_world_lock_info_text() -> String:
	if world_lock_manager != null and world_lock_manager.has_method("get_info_text"):
		return world_lock_manager.get_info_text()

	return "World is not locked."


func get_world_lock_access_state_for_player(player_name: String) -> String:
	if not in_world:
		return "none"

	if world_lock_manager != null and world_lock_manager.has_method("get_player_access_state"):
		return world_lock_manager.get_player_access_state(player_name)

	return "none"


func get_world_lock_access_role_for_player(player_name: String) -> String:
	if not in_world:
		return "none"

	if world_lock_manager != null and world_lock_manager.has_method("get_player_access_role_for_player"):
		return world_lock_manager.get_player_access_role_for_player(player_name)

	if world_lock_manager != null and world_lock_manager.has_method("get_player_access_role"):
		return world_lock_manager.get_player_access_role(player_name)

	return "none"


func get_local_player_world_lock_access_state() -> String:
	var username = get_current_profile_name()
	if username == "":
		return "none"

	return get_world_lock_access_state_for_player(username)


func get_local_player_world_lock_access_role() -> String:
	var username = get_current_profile_name()
	if username == "":
		return "none"

	return get_world_lock_access_role_for_player(username)

func has_active_profile() -> bool:
	if account_manager != null and account_manager.has_method("has_active_profile"):
		return account_manager.has_active_profile()

	return false

func get_current_profile_name() -> String:
	if account_manager != null and account_manager.has_method("get_current_profile_name"):
		return account_manager.get_current_profile_name()

	return ""

func create_or_switch_profile(username: String) -> Dictionary:
	if account_manager != null and account_manager.has_method("create_or_switch_profile"):
		var result = account_manager.create_or_switch_profile(username)
		update_username_label()
		return result

	return {"ok": false, "message": "Account system not ready."}

func setup_player_animation_manager():
	if MovementMode.is_netfox_real():
		return

	if player == null:
		return

	if player_animation_manager == null:
		var animation_script = preload("res://Scripts/player_animation_manager.gd")
		player_animation_manager = Node.new()
		player_animation_manager.name = "PlayerAnimationManager"
		player_animation_manager.set_script(animation_script)
		add_child(player_animation_manager)

	if player_animation_manager.has_method("setup"):
		player_animation_manager.setup(self, player)


func update_player_animation(delta: float):
	if MovementMode.is_netfox_real():
		return

	if player_animation_manager != null and player_animation_manager.has_method("update_player_animation"):
		player_animation_manager.update_player_animation(delta, player_facing_direction)


func setup_equipment_manager():
	if MovementMode.is_netfox_real():
		if equipment_manager != null and equipment_manager.has_method("clear_player_references"):
			equipment_manager.clear_player_references()
		return

	if equipment_manager == null:
		var equipment_script = preload("res://Scripts/equipment_manager.gd")
		equipment_manager = Node.new()
		equipment_manager.name = "EquipmentManager"
		equipment_manager.set_script(equipment_script)
		add_child(equipment_manager)

	if equipment_manager.has_method("setup"):
		last_equipment_visual_key = ""
		equipment_manager.setup(self, player)



func update_back_item_animation(delta: float):
	if MovementMode.is_netfox_real():
		return

	if equipment_manager != null and equipment_manager.has_method("update_back_item_animation"):
		equipment_manager.update_back_item_animation(delta)


func update_equipment_visual():
	if MovementMode.is_netfox_real():
		if player != null:
			var netfox_facing = player.get("facing_dir")
			if netfox_facing != null:
				player_facing_direction = -1 if int(netfox_facing) < 0 else 1
		return

	if equipped_tool == null:
		equipped_tool = ""

	if equipped_back_item == null:
		equipped_back_item = ""

	if equipped_hat_item == null:
		equipped_hat_item = ""

	if equipped_hair_item == null:
		equipped_hair_item = ""

	if equipped_eyewear_item == null:
		equipped_eyewear_item = ""

	if equipped_shirt_item == null:
		equipped_shirt_item = ""

	if equipped_pants_item == null:
		equipped_pants_item = ""

	if equipped_shoes_item == null:
		equipped_shoes_item = ""

	if equipped_ride_item == null:
		equipped_ride_item = ""

	equipped_tool = str(equipped_tool)
	equipped_back_item = str(equipped_back_item)
	equipped_hat_item = str(equipped_hat_item)
	equipped_hair_item = str(equipped_hair_item)
	equipped_eyewear_item = str(equipped_eyewear_item)
	equipped_shirt_item = str(equipped_shirt_item)
	equipped_pants_item = str(equipped_pants_item)
	equipped_shoes_item = str(equipped_shoes_item)
	equipped_ride_item = str(equipped_ride_item)

	if equipment_manager == null:
		return

	var equipment_visual_key: String = str(player_facing_direction) + "|" + equipped_tool + "|" + equipped_back_item + "|" + equipped_hat_item + "|" + equipped_hair_item + "|" + equipped_eyewear_item + "|" + equipped_shirt_item + "|" + equipped_pants_item + "|" + equipped_shoes_item + "|" + equipped_ride_item
	if equipment_visual_key == last_equipment_visual_key:
		return
	last_equipment_visual_key = equipment_visual_key

	if equipment_manager != null and equipment_manager.has_method("update_equipped_tool_visual"):
		equipment_manager.update_equipped_tool_visual(equipped_tool, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_back_visual"):
		equipment_manager.update_equipped_back_visual(equipped_back_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_hat_visual"):
		equipment_manager.update_equipped_hat_visual(equipped_hat_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_hair_visual"):
		equipment_manager.update_equipped_hair_visual(equipped_hair_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_eyewear_visual"):
		equipment_manager.update_equipped_eyewear_visual(equipped_eyewear_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_shirt_visual"):
		equipment_manager.update_equipped_shirt_visual(equipped_shirt_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_pants_visual"):
		equipment_manager.update_equipped_pants_visual(equipped_pants_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_shoes_visual"):
		equipment_manager.update_equipped_shoes_visual(equipped_shoes_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_ride_visual"):
		equipment_manager.update_equipped_ride_visual(equipped_ride_item, player_facing_direction)


func get_current_break_power(block_type: String = "") -> int:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_current_break_power"):
		return item_gameplay_manager.get_current_break_power(block_type)

	return 1


func get_current_required_break_hits(block_type: String, base_max_hits: int) -> int:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_required_break_hits"):
		return item_gameplay_manager.get_required_break_hits(block_type, base_max_hits)

	return maxi(1, base_max_hits)


func is_item_equipable(item_type: String, category: String) -> bool:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("is_item_equipable"):
		return item_gameplay_manager.is_item_equipable(item_type, category)

	return false

func toggle_equip_item(item_type: String, category: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("toggle_equip_item"):
		return item_gameplay_manager.toggle_equip_item(item_type, category)

	return

func equip_back_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_back_item"):
		return item_gameplay_manager.equip_back_item(item_type)

	return

func get_equipped_back_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_back_text"):
		return item_gameplay_manager.get_equipped_back_text()

	return "None"

func equip_hat_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_hat_item"):
		return item_gameplay_manager.equip_hat_item(item_type)

	return

func get_equipped_hat_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_hat_text"):
		return item_gameplay_manager.get_equipped_hat_text()

	return "None"

func equip_hair_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_hair_item"):
		return item_gameplay_manager.equip_hair_item(item_type)

	return

func get_equipped_hair_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_hair_text"):
		return item_gameplay_manager.get_equipped_hair_text()

	return "None"

func equip_shirt_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_shirt_item"):
		return item_gameplay_manager.equip_shirt_item(item_type)

	return

func get_equipped_shirt_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_shirt_text"):
		return item_gameplay_manager.get_equipped_shirt_text()

	return "None"

func equip_pants_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_pants_item"):
		return item_gameplay_manager.equip_pants_item(item_type)

	return

func get_equipped_pants_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_pants_text"):
		return item_gameplay_manager.get_equipped_pants_text()

	return "None"


func equip_shoes_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_shoes_item"):
		return item_gameplay_manager.equip_shoes_item(item_type)

	return


func get_equipped_shoes_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_shoes_text"):
		return item_gameplay_manager.get_equipped_shoes_text()

	return "None"


func equip_ride_item(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_ride_item"):
		return item_gameplay_manager.equip_ride_item(item_type)

	return


func get_equipped_ride_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_ride_text"):
		return item_gameplay_manager.get_equipped_ride_text()

	return "None"


func equip_tool(item_type: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("equip_tool"):
		return item_gameplay_manager.equip_tool(item_type)

	return

func unequip_tool():
	if item_gameplay_manager != null and item_gameplay_manager.has_method("unequip_tool"):
		return item_gameplay_manager.unequip_tool()

	return

func get_equipped_tool_text() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_equipped_tool_text"):
		return item_gameplay_manager.get_equipped_tool_text()

	return "None"


func get_gem_drop_range_for_rarity(rarity: String) -> Vector2i:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_gem_drop_range_for_rarity"):
		return item_gameplay_manager.get_gem_drop_range_for_rarity(rarity)

	return Vector2i(0, 3)

func get_block_rarity(block_type: String) -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_block_rarity"):
		return item_gameplay_manager.get_block_rarity(block_type)

	return "common"

func try_drop_gems(block_type: String, drop_position: Vector2):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("try_drop_gems"):
		return item_gameplay_manager.try_drop_gems(block_type, drop_position)

	return

func try_drop_seed(block_type: String, drop_position: Vector2):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("try_drop_seed"):
		return item_gameplay_manager.try_drop_seed(block_type, drop_position)

	return

func try_drop_block(block_type: String, drop_position: Vector2):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("try_drop_block"):
		return item_gameplay_manager.try_drop_block(block_type, drop_position)

	spawn_item_drop(block_type, drop_position, false)

func try_drop_fixed_break_drops(block_type: String, drop_position: Vector2) -> bool:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("try_drop_fixed_break_drops"):
		return bool(item_gameplay_manager.try_drop_fixed_break_drops(block_type, drop_position))

	return false

func spawn_item_drop(item_type: String, drop_position: Vector2, is_seed: bool):
	if drop_manager != null and drop_manager.has_method("spawn_item_drop"):
		drop_manager.spawn_item_drop(item_type, drop_position, is_seed)
		return

	var final_position = drop_position + Vector2(randf_range(-6, 6), 0)
	create_item_drop(item_type, final_position, is_seed)

func create_item_drop(
	item_type: String,
	item_position: Vector2,
	is_seed: bool,
	item_category: String = "",
	pickup_delay: float = 0.0,
	amount: float = 1.0,
	drop_id: String = "",
	sync_to_server: bool = true
):
	if drop_manager != null and drop_manager.has_method("create_item_drop"):
		drop_manager.create_item_drop(item_type, item_position, is_seed, item_category, pickup_delay, amount, drop_id, sync_to_server)

func get_drop_stack_grid(item_position: Vector2) -> Vector2i:
	if drop_manager != null and drop_manager.has_method("get_drop_stack_grid"):
		return drop_manager.get_drop_stack_grid(item_position)

	return Vector2i(int(round(item_position.x / BLOCK_SIZE)), int(round(item_position.y / BLOCK_SIZE)))

func get_drop_visual_position(stack_grid: Vector2i, stack_index: int) -> Vector2:
	if drop_manager != null and drop_manager.has_method("get_drop_visual_position"):
		return drop_manager.get_drop_visual_position(stack_grid, stack_index)

	return Vector2(stack_grid.x * BLOCK_SIZE, stack_grid.y * BLOCK_SIZE)

func get_existing_drop_stack(item_type: String, item_category: String, stack_grid: Vector2i):
	if drop_manager != null and drop_manager.has_method("get_existing_drop_stack"):
		return drop_manager.get_existing_drop_stack(item_type, item_category, stack_grid)

	return null

func get_drop_stack_count_on_tile(stack_grid: Vector2i) -> int:
	if drop_manager != null and drop_manager.has_method("get_drop_stack_count_on_tile"):
		return drop_manager.get_drop_stack_count_on_tile(stack_grid)

	return 0

func update_drop_count_label(drop_data):
	if drop_manager != null and drop_manager.has_method("update_drop_count_label"):
		drop_manager.update_drop_count_label(drop_data)

func is_drop_stack_covered(drop_data) -> bool:
	if drop_manager != null and drop_manager.has_method("is_drop_stack_covered"):
		return drop_manager.is_drop_stack_covered(drop_data)

	return false

func update_item_drops(delta):
	if drop_manager != null and drop_manager.has_method("update_drops"):
		drop_manager.update_drops(delta)


func should_use_server_authoritative_world_actions() -> bool:
	var clean_world_name = str(current_world_name).strip_edges()
	if clean_world_name == "":
		return false

	return true


func collect_drop(drop_data) -> bool:
	if drop_manager != null and drop_manager.has_method("collect_drop"):
		return bool(drop_manager.collect_drop(drop_data))
	return false

func apply_network_item_drop_create(data: Dictionary):
	if drop_manager != null and drop_manager.has_method("apply_network_item_drop_create"):
		drop_manager.apply_network_item_drop_create(data)

func apply_network_item_drop_update(data: Dictionary):
	if drop_manager != null and drop_manager.has_method("apply_network_item_drop_update"):
		drop_manager.apply_network_item_drop_update(data)

func apply_network_item_drop_remove(data: Dictionary):
	if drop_manager != null and drop_manager.has_method("apply_network_item_drop_remove"):
		drop_manager.apply_network_item_drop_remove(data)


func cancel_pending_pickup_for_drop(drop_id: String):
	if drop_manager != null and drop_manager.has_method("cancel_pending_pickup_for_drop"):
		drop_manager.cancel_pending_pickup_for_drop(drop_id)

func handle_rejected_drop_pickup(drop_id: String, message: String = "", details: Dictionary = {}) -> bool:
	if drop_manager != null and drop_manager.has_method("handle_rejected_drop_pickup"):
		return bool(drop_manager.handle_rejected_drop_pickup(drop_id, message, details))
	return false

func get_front_drop_grid_position() -> Vector2i:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_front_drop_grid_position"):
		return item_gameplay_manager.get_front_drop_grid_position()

	return get_player_grid_position()

func get_front_drop_world_position() -> Vector2:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_front_drop_world_position"):
		return item_gameplay_manager.get_front_drop_world_position()

	return Vector2.ZERO

func drop_inventory_item_to_world(item_type: String, category: String) -> bool:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("drop_inventory_item_to_world"):
		return bool(item_gameplay_manager.drop_inventory_item_to_world(item_type, category))

	return false

func drop_inventory_item_stack_to_world(item_type: String, category: String, amount: float) -> bool:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("drop_inventory_item_stack_to_world"):
		return bool(item_gameplay_manager.drop_inventory_item_stack_to_world(item_type, category, amount))

	return false

func update_chat_typing_movement_lock():
	if player_manager != null and player_manager.has_method("update_chat_typing_movement_lock"):
		return player_manager.update_chat_typing_movement_lock()

	return
func toggle_noclip():
	if player_manager != null and player_manager.has_method("toggle_noclip"):
		return player_manager.toggle_noclip()

	return
func set_noclip_enabled(enabled: bool):
	if player_manager != null and player_manager.has_method("set_noclip_enabled"):
		return player_manager.set_noclip_enabled(enabled)

	return
func is_noclip_enabled() -> bool:
	if player_manager != null and player_manager.has_method("is_noclip_enabled"):
		return player_manager.is_noclip_enabled()

	return false
func set_player_collision_enabled(enabled: bool):
	if player_manager != null and player_manager.has_method("set_player_collision_enabled"):
		return player_manager.set_player_collision_enabled(enabled)

	return
func update_noclip_movement(delta):
	if player_manager != null and player_manager.has_method("update_noclip_movement"):
		return player_manager.update_noclip_movement(delta)

	return
func update_player_facing_direction():
	if player_manager != null and player_manager.has_method("update_player_facing_direction"):
		return player_manager.update_player_facing_direction()

	return

func set_player_facing_direction(facing_direction: int, sync_now: bool = false) -> bool:
	if player_manager != null and player_manager.has_method("set_player_facing_direction"):
		return bool(player_manager.set_player_facing_direction(facing_direction, sync_now))

	return false

func face_grid_position(grid_pos: Vector2i, sync_now: bool = false) -> bool:
	if player_manager != null and player_manager.has_method("face_grid_position"):
		return bool(player_manager.face_grid_position(grid_pos, sync_now))

	return false

func punch_facing_block():
	if block_manager != null and block_manager.has_method("punch_facing_block"):
		block_manager.punch_facing_block()


func punch_facing_reach_block():
	if block_manager != null and block_manager.has_method("punch_facing_reach_block"):
		block_manager.punch_facing_reach_block()


func prepare_mouse_punch_facing() -> bool:
	if block_manager != null and block_manager.has_method("prepare_mouse_punch_facing"):
		return bool(block_manager.prepare_mouse_punch_facing())

	return false

func punch_grid_position(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("punch_grid_position"):
		block_manager.punch_grid_position(grid_pos)

func punch_at_mouse():
	if block_manager != null and block_manager.has_method("punch_at_mouse"):
		block_manager.punch_at_mouse()

func use_fishing_rod_at_mouse(preferred_lure_id: String = ""):
	if fishing_manager != null and fishing_manager.has_method("use_fishing_rod_at_mouse"):
		return fishing_manager.use_fishing_rod_at_mouse(preferred_lure_id)

	return
func use_selected_lure_at_mouse():
	if fishing_manager != null and fishing_manager.has_method("use_selected_lure_at_mouse"):
		return fishing_manager.use_selected_lure_at_mouse()

	return
func can_reach_fishing_grid(grid_pos: Vector2i) -> bool:
	if fishing_manager != null and fishing_manager.has_method("can_reach_fishing_grid"):
		return fishing_manager.can_reach_fishing_grid(grid_pos)

	return false
func update_fishing(delta: float):
	if fishing_manager != null and fishing_manager.has_method("update_fishing"):
		return fishing_manager.update_fishing(delta)

	return
func finish_fishing():
	if fishing_manager != null and fishing_manager.has_method("finish_fishing"):
		return fishing_manager.finish_fishing()

	return
func is_fishable_water(grid_pos: Vector2i) -> bool:
	if fishing_manager != null and fishing_manager.has_method("is_fishable_water"):
		return fishing_manager.is_fishable_water(grid_pos)

	return false
func get_best_available_lure() -> String:
	if fishing_manager != null and fishing_manager.has_method("get_best_available_lure"):
		return fishing_manager.get_best_available_lure()

	return ""
func roll_fish_for_lure(lure_id: String, rod_id: String = "") -> String:
	if fishing_manager != null and fishing_manager.has_method("roll_fish_for_lure"):
		return fishing_manager.roll_fish_for_lure(lure_id, rod_id)

	return ""
func get_fishing_table_for_lure(lure_id: String, rod_id: String = "") -> Array:
	if fishing_manager != null and fishing_manager.has_method("get_fishing_table_for_lure"):
		return fishing_manager.get_fishing_table_for_lure(lure_id, rod_id)

	return []
func open_lure_pack(amount: int = 1):
	if fishing_manager != null and fishing_manager.has_method("open_lure_pack"):
		return fishing_manager.open_lure_pack(amount)

	return
func roll_lure_from_pack() -> String:
	if fishing_manager != null and fishing_manager.has_method("roll_lure_from_pack"):
		return fishing_manager.roll_lure_from_pack()

	return "worm_lure"
func use_selected_item_at_mouse():
	if interaction_manager != null and interaction_manager.has_method("use_selected_item_at_mouse"):
		interaction_manager.use_selected_item_at_mouse()

func place_selected_item_at_mouse():
	if interaction_manager != null and interaction_manager.has_method("place_selected_item_at_mouse"):
		interaction_manager.place_selected_item_at_mouse()

func place_block_at_mouse():
	if block_manager != null and block_manager.has_method("place_block_at_mouse"):
		block_manager.place_block_at_mouse()


func get_seed_growth_time(seed_type: String) -> float:
	var clean_seed_type := seed_type.strip_edges()
	if item_database.has(clean_seed_type) and item_database[clean_seed_type] is Dictionary:
		var seed_data: Dictionary = item_database[clean_seed_type]
		return max(1.0, float(seed_data.get("max_grow_time", seed_data.get("grow_time", SEED_GROW_TIME))))

	return SEED_GROW_TIME


func plant_seed_at_mouse():
	if not seed_inventory.has(selected_item_type):
		return

	if seed_inventory[selected_item_type] <= 0:
		show_notification("You don't have any " + get_item_display_name(selected_item_type, selected_item_category) + ".")
		return

	var clicked_seed_grid = get_clicked_planted_seed_grid()

	if clicked_seed_grid != INVALID_GRID_POS:
		if not can_reach_grid(clicked_seed_grid):
			return

		if has_method("can_current_player_build") and not can_current_player_build():
			show_notification("This world is locked.")
			return

		try_splice_seed_tree(clicked_seed_grid)
		return

	var grid_pos = get_mouse_grid_position()

	if not can_reach_grid(grid_pos):
		return

	if has_method("can_current_player_build") and not can_current_player_build():
		show_notification("This world is locked.")
		return

	if not can_plant_seed_here(grid_pos):
		return

	if should_use_server_authoritative_world_actions():
		if request_server_seed_place(grid_pos):
			show_notification("Planting " + get_item_display_name(selected_item_type, selected_item_category) + "...")
		else:
			show_notification("Almost ready. Try again in a moment.")
		return

	var seed_grow_time := get_seed_growth_time(selected_item_type)
	if create_planted_seed(grid_pos, selected_item_type, seed_grow_time, seed_grow_time):
		seed_inventory[selected_item_type] -= 1
		show_notification("Planted " + get_item_display_name(selected_item_type, selected_item_category) + ".")
		if has_method("refresh_ui_after_item_change"):
			refresh_ui_after_item_change(selected_item_type, selected_item_category)
		else:
			update_all_ui()




func setup_seed_system():
	if seed_system == null:
		var seed_script = preload("res://Scripts/seed_system.gd")
		seed_system = Node.new()
		seed_system.name = "SeedSystem"
		seed_system.set_script(seed_script)
		add_child(seed_system)

	if seed_system.has_method("setup"):
		seed_system.setup(
			self,
			item_database,
			splice_recipes,
			seed_textures,
			seed_tree_textures,
			block_textures,
			BLOCK_SIZE,
			INVALID_GRID_POS,
			SEED_GROW_TIME,
			MATURE_SEED_EXTRA_DROP_CHANCE
		)


func get_clicked_planted_seed_grid() -> Vector2i:
	if seed_system == null:
		return INVALID_GRID_POS

	if seed_system.has_method("get_clicked_planted_seed_grid"):
		return seed_system.get_clicked_planted_seed_grid(
			get_mouse_grid_position(),
			get_pointer_global_position()
		)

	return INVALID_GRID_POS


func try_splice_seed_tree(grid_pos: Vector2i) -> bool:
	if seed_system == null:
		return false

	if should_use_server_authoritative_world_actions():
		if selected_item_category != "seed":
			show_notification("Select a seed from the Seeds tab first.")
		elif request_server_seed_splice(grid_pos):
			show_notification("Splicing " + get_item_display_name(selected_item_type, selected_item_category) + "...")
		else:
			show_notification("Almost ready. Try again in a moment.")
		return true

	if not seed_system.has_method("try_splice_seed_tree"):
		return false

	if seed_system.try_splice_seed_tree(
		grid_pos,
		selected_item_type,
		selected_item_category,
		seed_inventory
	):
		if has_method("refresh_ui_after_item_change"):
			refresh_ui_after_item_change(selected_item_type, selected_item_category)
		else:
			update_all_ui()

		return true

	return false


func request_server_seed_splice(grid_pos: Vector2i) -> bool:
	if not should_use_server_authoritative_world_actions():
		return false

	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	if selected_item_category != "seed":
		return false

	return bool(network.send_inventory_transaction_request({
		"action": "seed_splice",
		"world": current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"seed_type": selected_item_type
	}))


func request_server_seed_place(grid_pos: Vector2i) -> bool:
	if not should_use_server_authoritative_world_actions():
		return false

	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	if selected_item_category != "seed":
		return false

	var seed_grow_time := get_seed_growth_time(selected_item_type)
	return bool(network.send_inventory_transaction_request({
		"action": "seed_place",
		"world": current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"seed_type": selected_item_type,
		"grow_time": seed_grow_time,
		"max_grow_time": seed_grow_time
	}))


func can_place_block_here(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("can_place_block_here"):
		return block_manager.can_place_block_here(grid_pos)

	return false

func get_anchor_grid_for_block_area(grid_pos: Vector2i) -> Vector2i:
	if block_manager != null and block_manager.has_method("get_anchor_grid_for_block_area"):
		return block_manager.get_anchor_grid_for_block_area(grid_pos)

	if blocks.has(grid_pos):
		return grid_pos

	return INVALID_GRID_POS

func can_plant_seed_here(grid_pos: Vector2i) -> bool:
	if blocks.has(grid_pos):
		return false

	if has_planted_seed(grid_pos):
		return false

	if is_block_inside_player(grid_pos):
		return false

	return true


func has_planted_seed(grid_pos: Vector2i) -> bool:
	if seed_system == null:
		return false

	if seed_system.has_method("has_seed_at"):
		return seed_system.has_seed_at(grid_pos)

	return false


func create_planted_seed(grid_pos: Vector2i, seed_type: String, grow_time: float, max_grow_time: float = SEED_GROW_TIME) -> bool:
	if seed_system == null:
		return false

	if seed_system.has_method("create_planted_seed"):
		var created = seed_system.create_planted_seed(grid_pos, seed_type, grow_time, max_grow_time)
		if created and not applying_network_world_update and not should_use_server_authoritative_world_actions():
			var network = get_node_or_null("/root/NetworkManager")
			if network != null and network.has_method("send_world_seed_update"):
				network.send_world_seed_update("place", grid_pos, seed_type, grow_time, max_grow_time, current_world_name)
		return created

	return false


func update_planted_seeds(delta):
	if seed_system != null and seed_system.has_method("update_seed_system"):
		seed_system.update_seed_system(delta)


func update_seed_tree_visual(grid_pos: Vector2i):
	if seed_system != null and seed_system.has_method("update_seed_tree_visual"):
		seed_system.update_seed_tree_visual(grid_pos)


func harvest_planted_seed(grid_pos: Vector2i):
	if not should_use_server_authoritative_world_actions():
		if seed_system != null and seed_system.has_method("harvest_planted_seed"):
			seed_system.harvest_planted_seed(grid_pos)
		return

	var predict_local_removal := can_harvest_seed_tree_now(grid_pos)
	if not request_server_seed_harvest(grid_pos):
		show_notification("Almost ready. Try again in a moment.")
		return

	if predict_local_removal and not apply_local_seed_harvest_feedback(grid_pos):
		return



func can_harvest_seed_tree_now(grid_pos: Vector2i) -> bool:
	if not has_planted_seed(grid_pos):
		return false

	if seed_system == null:
		return true

	if seed_system.has_method("is_seed_ready_to_harvest"):
		return bool(seed_system.is_seed_ready_to_harvest(grid_pos))

	return true


func apply_local_seed_harvest_feedback(grid_pos: Vector2i) -> bool:
	if not has_planted_seed(grid_pos):
		return false

	if seed_system != null and seed_system.has_method("harvest_planted_seed"):
		seed_system.harvest_planted_seed(grid_pos)
		return true

	return false


func _generate_seed_harvest_request_id() -> String:
	seed_harvest_request_sequence += 1
	return SEED_HARVEST_REQUEST_PREFIX + "_" + str(Time.get_ticks_msec()) + "_" + str(seed_harvest_request_sequence)


func _capture_seed_harvest_snapshot(grid_pos: Vector2i) -> Dictionary:
	if seed_system == null:
		return {}

	if not has_planted_seed(grid_pos):
		return {}

	if not seed_system.has_method("has_seed_at"):
		return {}

	var planted_seeds_data = seed_system.get("planted_seeds")
	if planted_seeds_data == null or not (planted_seeds_data is Dictionary):
		return {}

	if not planted_seeds_data.has(grid_pos):
		return {}

	var seed_data = planted_seeds_data.get(grid_pos, {})
	if not (seed_data is Dictionary):
		return {}

	return {
		"x": grid_pos.x,
		"y": grid_pos.y,
		"seed_type": str(seed_data.get("seed_type", "")),
		"grow_time": float(seed_data.get("grow_time", 0.0)),
		"max_grow_time": float(seed_data.get("max_grow_time", seed_data.get("grow_time", 0.0))),
		"mature": bool(seed_data.get("mature", false)),
		"mutated": bool(seed_data.get("mutated", false)),
		"expires_at_ms": Time.get_ticks_msec() + SEED_HARVEST_PENDING_ROLLBACK_MS
	}


func _register_seed_harvest_rollback(request_id: String, grid_pos: Vector2i) -> bool:
	if request_id.strip_edges() == "":
		return false

	var snapshot = _capture_seed_harvest_snapshot(grid_pos)
	if snapshot.is_empty():
		return false

	seed_harvest_pending_rollback[request_id] = snapshot
	return true


func _cleanup_expired_seed_harvest_rollbacks() -> void:
	var now_ms = Time.get_ticks_msec()
	for request_id in seed_harvest_pending_rollback.keys().duplicate():
		var snapshot = seed_harvest_pending_rollback.get(request_id, {})
		if not (snapshot is Dictionary):
			seed_harvest_pending_rollback.erase(request_id)
			continue

		if int(snapshot.get("expires_at_ms", 0)) <= now_ms:
			seed_harvest_pending_rollback.erase(request_id)


func _consume_seed_harvest_rollback(request_id: String) -> Dictionary:
	_cleanup_expired_seed_harvest_rollbacks()
	if request_id == "":
		return {}

	if not seed_harvest_pending_rollback.has(request_id):
		return {}

	var snapshot = seed_harvest_pending_rollback[request_id]
	seed_harvest_pending_rollback.erase(request_id)
	return snapshot


func _clear_seed_harvest_rollback_request(request_id: String) -> bool:
	if request_id == "":
		return false

	if not seed_harvest_pending_rollback.has(request_id):
		return false

	seed_harvest_pending_rollback.erase(request_id)
	return true


func _restore_seed_harvest_from_snapshot(snapshot: Dictionary) -> bool:
	if not (snapshot is Dictionary) or snapshot.is_empty():
		return false

	if seed_system == null or not seed_system.has_method("create_planted_seed"):
		return false

	var grid_pos = Vector2i(int(snapshot.get("x", 0)), int(snapshot.get("y", 0)))
	if has_planted_seed(grid_pos):
		return true

	var restored = seed_system.create_planted_seed(
		grid_pos,
		str(snapshot.get("seed_type", "")),
		float(snapshot.get("grow_time", 0.0)),
		float(snapshot.get("max_grow_time", 0.0))
	)
	if not restored:
		return false

	if bool(snapshot.get("mature", false)) and seed_system.has_method("set_seed_mature"):
		seed_system.set_seed_mature(grid_pos, true)
	if bool(snapshot.get("mutated", false)) and seed_system.has_method("set_seed_mutated"):
		seed_system.set_seed_mutated(grid_pos, true)
	return true


func _restore_seed_harvest_request(request_id: String) -> bool:
	var snapshot = _consume_seed_harvest_rollback(request_id)
	return _restore_seed_harvest_from_snapshot(snapshot)


func _clear_seed_harvest_rollbacks() -> void:
	seed_harvest_pending_rollback.clear()


func update_red_tractor_auto_harvest():
	if str(equipped_ride_item).strip_edges().to_lower() != RED_TRACTOR_ITEM_ID:
		red_tractor_auto_harvest_pending_grids.clear()
		return

	if player == null or seed_system == null:
		return

	clear_expired_red_tractor_auto_harvest_requests()

	if not seed_system.has_method("get_ready_seed_grid_overlapping_player"):
		return

	var seed_grid: Vector2i = seed_system.get_ready_seed_grid_overlapping_player(
		get_player_grid_position(),
		player.global_position
	)
	if seed_grid == INVALID_GRID_POS:
		return

	if is_red_tractor_auto_harvest_pending(seed_grid):
		return

	if not can_reach_grid(seed_grid):
		return

	if has_method("can_current_player_build_at") and not can_current_player_build_at(seed_grid):
		return

	if should_use_server_authoritative_world_actions():
		if request_server_seed_harvest(seed_grid):
			apply_local_seed_harvest_feedback(seed_grid)
			mark_red_tractor_auto_harvest_pending(seed_grid)
		return



func clear_expired_red_tractor_auto_harvest_requests():
	var now_ms = Time.get_ticks_msec()
	for grid_pos in red_tractor_auto_harvest_pending_grids.keys().duplicate():
		if not has_planted_seed(grid_pos):
			red_tractor_auto_harvest_pending_grids.erase(grid_pos)
			continue

		var expires_at_ms = int(red_tractor_auto_harvest_pending_grids.get(grid_pos, 0))
		if expires_at_ms <= now_ms:
			red_tractor_auto_harvest_pending_grids.erase(grid_pos)


func is_red_tractor_auto_harvest_pending(grid_pos: Vector2i) -> bool:
	if not red_tractor_auto_harvest_pending_grids.has(grid_pos):
		return false

	var expires_at_ms = int(red_tractor_auto_harvest_pending_grids.get(grid_pos, 0))
	if expires_at_ms > Time.get_ticks_msec() and has_planted_seed(grid_pos):
		return true

	red_tractor_auto_harvest_pending_grids.erase(grid_pos)
	return false


func mark_red_tractor_auto_harvest_pending(grid_pos: Vector2i):
	red_tractor_auto_harvest_pending_grids[grid_pos] = Time.get_ticks_msec() + RED_TRACTOR_AUTO_HARVEST_PENDING_MS


func request_server_seed_harvest(grid_pos: Vector2i) -> bool:
	if not should_use_server_authoritative_world_actions():
		return false

	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	var request_id = _generate_seed_harvest_request_id()
	if not _register_seed_harvest_rollback(request_id, grid_pos):
		return false

	var sent = bool(network.send_inventory_transaction_request({
		"action": "seed_harvest",
		"world": current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"request_id": request_id
	}))
	if not sent:
		_clear_seed_harvest_rollback_request(request_id)

	return sent


func clear_planted_seeds():
	_clear_seed_harvest_rollbacks()
	if seed_system != null and seed_system.has_method("clear"):
		seed_system.clear()


func seed_to_block_type(seed_type: String) -> String:
	if item_database.has(seed_type):
		return str(item_database[seed_type].get("grows_into", seed_type.replace("_seed", "")))

	return seed_type.replace("_seed", "")


func is_block_inside_player(grid_pos: Vector2i) -> bool:
	if player == null:
		return false

	var player_grid_pos = get_player_grid_position()

	return grid_pos == player_grid_pos


func get_mouse_grid_position() -> Vector2i:
	if fast_block_place_grid_override_active:
		return fast_block_place_grid_override

	var mouse_pos = get_pointer_global_position()

	var grid_x = int(round(mouse_pos.x / BLOCK_SIZE))
	var grid_y = int(round(mouse_pos.y / BLOCK_SIZE))

	return Vector2i(grid_x, grid_y)


func set_mobile_pointer_screen_position(screen_position: Vector2):
	mobile_pointer_override_active = true
	mobile_pointer_screen_position = screen_position


func clear_mobile_pointer_screen_position():
	mobile_pointer_override_active = false


func get_pointer_screen_position() -> Vector2:
	if mobile_pointer_override_active:
		return mobile_pointer_screen_position

	return get_viewport().get_mouse_position()


func get_pointer_global_position() -> Vector2:
	if mobile_pointer_override_active:
		return get_viewport().get_canvas_transform().affine_inverse() * mobile_pointer_screen_position

	return get_global_mouse_position()


func get_player_grid_position() -> Vector2i:
	if player == null:
		return Vector2i.ZERO

	var grid_x = int(round(player.global_position.x / BLOCK_SIZE))
	var grid_y = int(round(player.global_position.y / BLOCK_SIZE))

	return Vector2i(grid_x, grid_y)


func is_grid_inside_world(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < WORLD_WIDTH and grid_pos.y >= 0 and grid_pos.y < WORLD_HEIGHT


func can_reach_grid(grid_pos: Vector2i) -> bool:
	if player == null:
		return false

	var block_center = Vector2(
		grid_pos.x * BLOCK_SIZE,
		grid_pos.y * BLOCK_SIZE
	)

	var distance = player.global_position.distance_to(block_center)

	return distance <= INTERACTION_PIXEL_RANGE



func setup_world_camera_limits():
	if player_manager != null and player_manager.has_method("setup_world_camera_limits"):
		return player_manager.setup_world_camera_limits()

	return
func get_player_camera():
	if player_manager != null and player_manager.has_method("get_player_camera"):
		return player_manager.get_player_camera()

	return null
func apply_camera_zoom():
	if player_manager != null and player_manager.has_method("apply_camera_zoom"):
		return player_manager.apply_camera_zoom()

	return
func zoom_camera(amount: float):
	if player_manager != null and player_manager.has_method("zoom_camera"):
		return player_manager.zoom_camera(amount)

	return
func reset_camera_zoom():
	if player_manager != null and player_manager.has_method("reset_camera_zoom"):
		return player_manager.reset_camera_zoom()

	return
func set_default_camera_zoom_silent():
	if player_manager != null and player_manager.has_method("set_default_camera_zoom_silent"):
		return player_manager.set_default_camera_zoom_silent()

	return
func can_use_camera_zoom(ignore_chat_text_focus: bool = false) -> bool:
	if player_manager != null and player_manager.has_method("can_use_camera_zoom"):
		return player_manager.can_use_camera_zoom(ignore_chat_text_focus)

	return false
func clamp_player_to_world():
	if player_manager != null and player_manager.has_method("clamp_player_to_world"):
		return player_manager.clamp_player_to_world()

	return
func check_lava_damage(delta):
	if player_manager != null and player_manager.has_method("check_lava_damage"):
		return player_manager.check_lava_damage(delta)

	return
func update_checkpoint_contact():
	if player_manager != null and player_manager.has_method("update_checkpoint_contact"):
		return player_manager.update_checkpoint_contact()

	return
func is_lava_block(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("is_lava_block"):
		return block_manager.is_lava_block(grid_pos)

	if not blocks.has(grid_pos):
		return false

	return blocks[grid_pos]["type"] == "lava"

func damage_player(amount: int):
	if player_manager != null and player_manager.has_method("damage_player"):
		return player_manager.damage_player(amount)

	return
func respawn_player():
	if player_manager != null and player_manager.has_method("respawn_player"):
		return player_manager.respawn_player()

	return

func place_player_at_entrance_immediate():
	if player_manager != null and player_manager.has_method("place_player_at_entrance_immediate"):
		return player_manager.place_player_at_entrance_immediate()

	return

func is_player_dead_or_respawning() -> bool:
	if int(player_health) <= 0:
		return true

	if player_manager != null:
		var respawn_running = player_manager.get("respawn_sequence_running")
		if respawn_running is bool and respawn_running:
			return true

	return false

func setup_inventory_manager():
	if ui_layer == null:
		return

	inventory_manager = ui_layer.get_node_or_null("InventoryManager")

	if inventory_manager == null:
		var inventory_script = preload("res://Scripts/inventory_manager.gd")
		inventory_manager = Control.new()
		inventory_manager.name = "InventoryManager"
		inventory_manager.set_script(inventory_script)
		ui_layer.add_child(inventory_manager)

	if inventory_manager.has_method("setup"):
		inventory_manager.setup(self, ui_layer)


func select_hotbar_slot(slot_index: int):
	if inventory_manager != null and inventory_manager.has_method("select_hotbar_slot"):
		inventory_manager.select_hotbar_slot(slot_index)


func assign_item_to_quick_hotbar(item_type: String, category: String):
	if inventory_manager != null and inventory_manager.has_method("assign_item_to_quick_hotbar"):
		inventory_manager.assign_item_to_quick_hotbar(item_type, category)


func normalize_hotbar():
	if inventory_manager != null and inventory_manager.has_method("normalize_hotbar"):
		inventory_manager.normalize_hotbar()


func get_item_texture(item_type: String, category: String):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_item_texture"):
		return item_gameplay_manager.get_item_texture(item_type, category)

	return null


func get_inventory_icon_texture(item_type: String, category: String = ""):
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_inventory_icon_texture"):
		return item_gameplay_manager.get_inventory_icon_texture(item_type, category)

	return null


func get_item_atlas_tile_set() -> TileSet:
	var renderer = get_node_or_null("WorldTileMapRenderer")
	if renderer != null and "tile_set" in renderer:
		var renderer_tile_set = renderer.get("tile_set")
		if renderer_tile_set is TileSet:
			return renderer_tile_set

	var foreground_layer = get_node_or_null("ForegroundTileMapLayer")
	if foreground_layer is TileMapLayer:
		return (foreground_layer as TileMapLayer).tile_set

	var background_layer = get_node_or_null("BackgroundTileMapLayer")
	if background_layer is TileMapLayer:
		return (background_layer as TileMapLayer).tile_set

	return null


func get_drop_pickup_vacuum_world_target_position(item_type: String, category: String, fallback_world_position: Vector2) -> Vector2:
	if inventory_manager != null and inventory_manager.has_method("get_pickup_target_world_position"):
		return inventory_manager.get_pickup_target_world_position(item_type, category, fallback_world_position)

	return fallback_world_position


func play_drop_pickup_target_feedback(item_type: String, category: String) -> void:
	if inventory_manager != null and inventory_manager.has_method("play_pickup_target_feedback"):
		inventory_manager.play_pickup_target_feedback(item_type, category)


func is_vending_machine_block_type(block_type: String) -> bool:
	if vending_preview_manager != null and vending_preview_manager.has_method("is_vending_machine_block_type"):
		return bool(vending_preview_manager.is_vending_machine_block_type(block_type))

	return false

func update_vending_machine_preview(grid_pos: Vector2i):
	if vending_preview_manager != null and vending_preview_manager.has_method("update_vending_machine_preview"):
		vending_preview_manager.update_vending_machine_preview(grid_pos)

func is_mailbox_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("mailbox_block", false))
	return block_type == "mail_box" or block_type == "blue_mail_box"

func is_donation_box_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("donation_box_block", false))
	return block_type.strip_edges().to_lower() == "donation_box"

func is_bulletin_board_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("bulletin_board_block", false))
	return block_type == "bulletin_board"

func is_tackle_box_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("tackle_box_block", false))
	return block_type == "tackle_box"

func is_chicken_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("chicken_block", false))
	return block_type == "chicken"

func is_cow_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("cow_block", false))
	return block_type == "cow"

func is_duck_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("duck_block", false))
	return block_type == "duck"

func is_water_well_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("water_well_block", false))
	return block_type == "water_well"

func is_atm_machine_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("atm_machine_block", false))
	return block_type == "atm_machine"

func is_dice_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("dice_block", false))
	return block_type == "dice_block"

func is_checkpoint_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("checkpoint_block", false))
	return block_type == "checkpoint"

func is_anti_punch_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("anti_punch_block", false))
	return block_type == "anti_punch"

func is_anti_talk_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("anti_talk_block", false))
	return block_type == "anti_talk"

func is_anti_gravity_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("anti_gravity_block", false))
	return block_type == "anti_gravity"

func is_snow_repellent_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("snow_repellent_block", false))
	return block_type == "snow_repellent"

func is_theme_machine_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("theme_machine_block", false))
	var clean_type := block_type.strip_edges().to_lower()
	return clean_type == "night_theme_machine" or clean_type == "snow_theme_machine" or clean_type == "theme_machine"

func is_cctv_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("cctv_block", false))
	return block_type == "cctv"

func is_oil_refinery_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("oil_refinery_block", false))
	return block_type == "oil_refinery"

func refresh_oil_refinery_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("sync_oil_refinery_visual_at"):
		block_manager.sync_oil_refinery_visual_at(grid_pos)

func is_battery_charger_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("battery_charger_block", false))
	return block_type == "battery_charger"

func refresh_battery_charger_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("sync_battery_charger_visual_at"):
		block_manager.sync_battery_charger_visual_at(grid_pos)

func is_display_block_type(block_type: String) -> bool:
	if item_database.has(block_type):
		return bool(item_database[block_type].get("display_block", false))
	return block_type == "display_box" or block_type == "display_case"

func is_fish_hanger_block_type(block_type: String) -> bool:
	if block_manager != null and block_manager.has_method("is_fish_hanger_block_type"):
		return bool(block_manager.is_fish_hanger_block_type(block_type))
	return block_type.strip_edges().to_lower() == "fish_hanger"

func try_display_selected_item_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_display_selected_item_at_grid"):
		return bool(block_manager.try_display_selected_item_at_grid(grid_pos))
	return false

func try_withdraw_display_item_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_withdraw_display_item_at_grid"):
		return bool(block_manager.try_withdraw_display_item_at_grid(grid_pos))
	return false

func try_display_selected_fish_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_display_selected_fish_at_grid"):
		return bool(block_manager.try_display_selected_fish_at_grid(grid_pos))
	return false

func try_withdraw_fish_hanger_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_withdraw_fish_hanger_at_grid"):
		return bool(block_manager.try_withdraw_fish_hanger_at_grid(grid_pos))
	return false

func update_mailbox_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_mailbox_visual"):
		block_manager.update_mailbox_visual(grid_pos)

func refresh_all_mailbox_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_mailbox_visuals"):
		block_manager.refresh_all_mailbox_visuals()

func update_donation_box_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_donation_box_visual"):
		block_manager.update_donation_box_visual(grid_pos)

func refresh_all_donation_box_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_donation_box_visuals"):
		block_manager.refresh_all_donation_box_visuals()

func update_tackle_box_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_tackle_box_visual"):
		block_manager.update_tackle_box_visual(grid_pos)

func refresh_all_tackle_box_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_tackle_box_visuals"):
		block_manager.refresh_all_tackle_box_visuals()

func update_chicken_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_chicken_visual"):
		block_manager.update_chicken_visual(grid_pos)

func refresh_all_chicken_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_chicken_visuals"):
		block_manager.refresh_all_chicken_visuals()

func try_feed_chicken_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_feed_chicken_at_grid"):
		return bool(block_manager.try_feed_chicken_at_grid(grid_pos))
	return false

func update_cow_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_cow_visual"):
		block_manager.update_cow_visual(grid_pos)

func refresh_all_cow_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_cow_visuals"):
		block_manager.refresh_all_cow_visuals()

func try_feed_cow_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_feed_cow_at_grid"):
		return bool(block_manager.try_feed_cow_at_grid(grid_pos))
	return false

func update_duck_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_duck_visual"):
		block_manager.update_duck_visual(grid_pos)

func refresh_all_duck_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_duck_visuals"):
		block_manager.refresh_all_duck_visuals()

func try_feed_duck_at(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("try_feed_duck_at_grid"):
		return bool(block_manager.try_feed_duck_at_grid(grid_pos))
	return false

func update_dice_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_dice_visual"):
		block_manager.update_dice_visual(grid_pos)

func refresh_all_dice_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_dice_visuals"):
		block_manager.refresh_all_dice_visuals()

func update_checkpoint_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_checkpoint_visual"):
		block_manager.update_checkpoint_visual(grid_pos)

func refresh_all_checkpoint_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_checkpoint_visuals"):
		block_manager.refresh_all_checkpoint_visuals()

func apply_checkpoint_activation(grid_pos: Vector2i, notify: bool = false, send_network: bool = false) -> bool:
	if block_manager != null and block_manager.has_method("apply_checkpoint_activation"):
		return bool(block_manager.apply_checkpoint_activation(grid_pos, notify, send_network))
	return false

func activate_checkpoint(grid_pos: Vector2i) -> bool:
	if block_manager != null and block_manager.has_method("activate_checkpoint"):
		return bool(block_manager.activate_checkpoint(grid_pos))
	return false

func update_anti_punch_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_anti_punch_visual"):
		block_manager.update_anti_punch_visual(grid_pos)

func refresh_all_anti_punch_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_anti_punch_visuals"):
		block_manager.refresh_all_anti_punch_visuals()

func apply_anti_punch_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false) -> bool:
	if block_manager != null and block_manager.has_method("apply_anti_punch_state"):
		return bool(block_manager.apply_anti_punch_state(grid_pos, enabled, notify, send_network))
	return false

func is_anti_punch_enabled() -> bool:
	if block_manager != null and block_manager.has_method("is_anti_punch_enabled"):
		return bool(block_manager.is_anti_punch_enabled())
	return false

func update_anti_talk_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_anti_talk_visual"):
		block_manager.update_anti_talk_visual(grid_pos)

func refresh_all_anti_talk_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_anti_talk_visuals"):
		block_manager.refresh_all_anti_talk_visuals()

func update_anti_gravity_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_anti_gravity_visual"):
		block_manager.update_anti_gravity_visual(grid_pos)

func refresh_all_anti_gravity_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_anti_gravity_visuals"):
		block_manager.refresh_all_anti_gravity_visuals()

func apply_anti_gravity_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false) -> bool:
	if block_manager != null and block_manager.has_method("apply_anti_gravity_state"):
		return bool(block_manager.apply_anti_gravity_state(grid_pos, enabled, notify, send_network))
	return false

func is_anti_gravity_enabled() -> bool:
	if block_manager != null and block_manager.has_method("is_anti_gravity_enabled"):
		return bool(block_manager.is_anti_gravity_enabled())
	return false

func apply_theme_machine_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false, theme_name: String = "night") -> bool:
	if block_manager != null and block_manager.has_method("apply_theme_machine_state"):
		return bool(block_manager.apply_theme_machine_state(grid_pos, enabled, notify, send_network, theme_name))
	return false

func is_theme_machine_enabled() -> bool:
	if block_manager != null and block_manager.has_method("is_theme_machine_enabled"):
		return bool(block_manager.is_theme_machine_enabled())
	return false

func refresh_world_background_theme_from_machines():
	if block_manager != null and block_manager.has_method("refresh_world_background_theme_from_machines"):
		block_manager.refresh_world_background_theme_from_machines()

func update_cctv_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_cctv_visual"):
		block_manager.update_cctv_visual(grid_pos)

func refresh_all_cctv_visuals():
	if block_manager != null and block_manager.has_method("refresh_all_cctv_visuals"):
		block_manager.refresh_all_cctv_visuals()

func apply_anti_talk_state(grid_pos: Vector2i, enabled: bool, notify: bool = false, send_network: bool = false) -> bool:
	if block_manager != null and block_manager.has_method("apply_anti_talk_state"):
		return bool(block_manager.apply_anti_talk_state(grid_pos, enabled, notify, send_network))
	return false

func is_anti_talk_enabled() -> bool:
	if block_manager != null and block_manager.has_method("is_anti_talk_enabled"):
		return bool(block_manager.is_anti_talk_enabled())
	return false

func update_display_visual(grid_pos: Vector2i):
	if block_manager != null and block_manager.has_method("update_display_visual"):
		block_manager.update_display_visual(grid_pos)

func refresh_all_vending_machine_previews():
	if vending_preview_manager != null and vending_preview_manager.has_method("refresh_all_vending_machine_previews"):
		vending_preview_manager.refresh_all_vending_machine_previews()

func queue_refresh_all_vending_machine_previews():
	if vending_preview_manager != null and vending_preview_manager.has_method("queue_refresh_all_vending_machine_previews"):
		vending_preview_manager.queue_refresh_all_vending_machine_previews()

func get_item_count(item_type: String, category: String) -> int:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_item_count"):
		return item_gameplay_manager.get_item_count(item_type, category)

	return 0

func get_item_display_name(item_type: String, category: String) -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_item_display_name"):
		return item_gameplay_manager.get_item_display_name(item_type, category)

	return item_type.capitalize()

func setup_hotbar():
	if inventory_manager != null and inventory_manager.has_method("setup_hotbar"):
		inventory_manager.setup_hotbar()


func update_hotbar():
	if inventory_manager != null and inventory_manager.has_method("update_hotbar"):
		inventory_manager.update_hotbar()


func refresh_hotbar_live():
	if inventory_manager != null and inventory_manager.has_method("refresh_hotbar_live"):
		inventory_manager.refresh_hotbar_live()
	elif inventory_manager != null and inventory_manager.has_method("update_hotbar"):
		inventory_manager.update_hotbar()


func update_inventory_window():
	if inventory_manager != null and inventory_manager.has_method("update_inventory_window"):
		inventory_manager.update_inventory_window()


func refresh_inventory_window_live():
	if inventory_manager != null and inventory_manager.has_method("refresh_inventory_window_live"):
		inventory_manager.refresh_inventory_window_live()
	elif inventory_manager != null and inventory_manager.has_method("update_inventory_window"):
		inventory_manager.update_inventory_window()


func refresh_inventory_item_live(item_type: String, category: String):
	if inventory_manager != null and inventory_manager.has_method("refresh_inventory_item_live"):
		inventory_manager.refresh_inventory_item_live(item_type, category)
	elif inventory_manager != null and inventory_manager.has_method("refresh_inventory_window_live"):
		inventory_manager.refresh_inventory_window_live()
	elif inventory_manager != null and inventory_manager.has_method("update_inventory_window"):
		inventory_manager.update_inventory_window()


func refresh_ui_after_item_change(item_type: String, category: String):
	if inventory_manager != null:
		if inventory_manager.has_method("notify_inventory_item_changed"):
			inventory_manager.notify_inventory_item_changed(item_type, category)
		elif inventory_manager.has_method("refresh_inventory_item_live"):
			inventory_manager.refresh_inventory_item_live(item_type, category)
		elif inventory_manager.has_method("refresh_inventory_window_live"):
			inventory_manager.refresh_inventory_window_live()
		elif inventory_manager.has_method("update_inventory_window"):
			inventory_manager.update_inventory_window()
		if is_gem_currency(item_type, category) and inventory_manager.has_method("update_gem_counter"):
			inventory_manager.update_gem_counter()
		return
	update_all_ui()


func refresh_ui_for_inventory_transaction_deltas(transaction_data: Dictionary) -> bool:
	var raw_delta = null
	if transaction_data.has("inventory_delta"):
		raw_delta = transaction_data["inventory_delta"]
	elif transaction_data.has("inventory_deltas"):
		raw_delta = transaction_data["inventory_deltas"]
	else:
		return false

	var delta_entries: Array = []
	if raw_delta is Dictionary:
		delta_entries = [raw_delta]
	elif raw_delta is Array:
		delta_entries = raw_delta
	else:
		return false

	var did_refresh = false
	var refreshed_entries: Dictionary = {}
	for raw_entry in delta_entries:
		if not (raw_entry is Dictionary):
			continue

		var delta: Dictionary = raw_entry
		var item_type = str(delta.get("item_id", delta.get("item_type", ""))).strip_edges()
		if item_type == "":
			continue

		var category = resolve_network_inventory_delta_category(
			item_type,
			str(delta.get("item_category", delta.get("category", "")))
		)
		if category == "":
			continue
		var refresh_key = category + "|" + item_type
		if refreshed_entries.has(refresh_key):
			continue
		refreshed_entries[refresh_key] = true

		if has_method("refresh_ui_after_item_change"):
			refresh_ui_after_item_change(item_type, category)
		else:
			update_all_ui()
			return true

		did_refresh = true

	return did_refresh


func open_inventory_window():
	if inventory_manager != null and inventory_manager.has_method("open_inventory_window"):
		inventory_manager.open_inventory_window()


func close_inventory_window():
	if inventory_manager != null and inventory_manager.has_method("close_inventory_window"):
		inventory_manager.close_inventory_window()


func toggle_inventory_window():
	if inventory_manager != null and inventory_manager.has_method("toggle_inventory_window"):
		inventory_manager.toggle_inventory_window()


func begin_trade_item_select(slot_index: int):
	if inventory_manager != null and inventory_manager.has_method("begin_trade_item_select"):
		inventory_manager.begin_trade_item_select(slot_index)


func end_trade_item_select(close_drawer: bool = false):
	if inventory_manager != null and inventory_manager.has_method("end_trade_item_select"):
		inventory_manager.end_trade_item_select(close_drawer)


func is_trade_item_selecting() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_trade_item_selecting"):
		return bool(inventory_manager.is_trade_item_selecting())

	return false


func add_inventory_item_to_trade(slot_index: int, item_type: String, category: String, amount: int):
	if trade_ui != null and trade_ui.has_method("add_inventory_item_to_trade"):
		return bool(trade_ui.add_inventory_item_to_trade(slot_index, item_type, category, amount))

	return false


func begin_vend_item_select():
	if inventory_manager != null and inventory_manager.has_method("begin_vend_item_select"):
		inventory_manager.begin_vend_item_select()


func end_vend_item_select(close_drawer: bool = false):
	if inventory_manager != null and inventory_manager.has_method("end_vend_item_select"):
		inventory_manager.end_vend_item_select(close_drawer)


func is_vend_item_selecting() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_vend_item_selecting"):
		return bool(inventory_manager.is_vend_item_selecting())

	return false


func add_inventory_item_to_vend(item_type: String, category: String, amount: int):
	if vending_ui != null and vending_ui.has_method("add_inventory_item_to_vend"):
		return bool(vending_ui.add_inventory_item_to_vend(item_type, category, amount))

	return false


func begin_safe_item_select():
	if inventory_manager != null and inventory_manager.has_method("begin_safe_item_select"):
		inventory_manager.begin_safe_item_select()


func end_safe_item_select(close_drawer: bool = false):
	if inventory_manager != null and inventory_manager.has_method("end_safe_item_select"):
		inventory_manager.end_safe_item_select(close_drawer)


func is_safe_item_selecting() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_safe_item_selecting"):
		return bool(inventory_manager.is_safe_item_selecting())

	return false


func add_inventory_item_to_safe(item_type: String, category: String, amount: int):
	if safe_ui != null and safe_ui.has_method("add_inventory_item_to_safe"):
		return bool(safe_ui.add_inventory_item_to_safe(item_type, category, amount))

	return false


func begin_donation_box_item_select():
	if inventory_manager != null and inventory_manager.has_method("begin_donation_box_item_select"):
		inventory_manager.begin_donation_box_item_select()


func end_donation_box_item_select(close_drawer: bool = false):
	if inventory_manager != null and inventory_manager.has_method("end_donation_box_item_select"):
		inventory_manager.end_donation_box_item_select(close_drawer)


func is_donation_box_item_selecting() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_donation_box_item_selecting"):
		return bool(inventory_manager.is_donation_box_item_selecting())

	return false


func add_inventory_item_to_donation_box(item_type: String, category: String, amount: int):
	if donation_box_ui != null and donation_box_ui.has_method("add_inventory_item_to_donation_box"):
		return bool(donation_box_ui.add_inventory_item_to_donation_box(item_type, category, amount))

	return false


func begin_display_item_select():
	if inventory_manager != null and inventory_manager.has_method("begin_display_item_select"):
		inventory_manager.begin_display_item_select()


func end_display_item_select(close_drawer: bool = false):
	if inventory_manager != null and inventory_manager.has_method("end_display_item_select"):
		inventory_manager.end_display_item_select(close_drawer)


func is_display_item_selecting() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_display_item_selecting"):
		return bool(inventory_manager.is_display_item_selecting())

	return false


func add_inventory_item_to_display(item_type: String, category: String, amount: int):
	if display_ui != null and display_ui.has_method("add_inventory_item_to_display"):
		return bool(display_ui.add_inventory_item_to_display(item_type, category, amount))

	return false


func begin_oil_refinery_battery_select():
	if inventory_manager != null and inventory_manager.has_method("begin_oil_refinery_battery_select"):
		inventory_manager.begin_oil_refinery_battery_select()


func end_oil_refinery_battery_select(close_drawer: bool = false):
	if inventory_manager != null and inventory_manager.has_method("end_oil_refinery_battery_select"):
		inventory_manager.end_oil_refinery_battery_select(close_drawer)


func is_oil_refinery_battery_selecting() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_oil_refinery_battery_selecting"):
		return bool(inventory_manager.is_oil_refinery_battery_selecting())

	return false


func add_inventory_item_to_oil_refinery(item_type: String, category: String, amount: int):
	if oil_refinery_ui != null and oil_refinery_ui.has_method("add_inventory_item_to_oil_refinery"):
		return bool(oil_refinery_ui.add_inventory_item_to_oil_refinery(item_type, category, amount))

	return false


func setup_command_manager():
	if command_manager == null:
		var command_script = preload("res://Scripts/command_manager.gd")
		command_manager = Node.new()
		command_manager.name = "CommandManager"
		command_manager.set_script(command_script)
		add_child(command_manager)

	if command_manager.has_method("setup"):
		command_manager.setup(self)


func handle_chat_command(command_text: String):
	if command_manager != null and command_manager.has_method("handle_command"):
		command_manager.handle_command(command_text)
	else:
		show_notification("Command system not ready.")


func handle_verified_developer_command(command_text: String, request_id: String = "", server_message: String = "", server_data: Dictionary = {}):
	if command_manager != null and command_manager.has_method("execute_verified_developer_command"):
		command_manager.execute_verified_developer_command(command_text, request_id, server_message, server_data)
	else:
		show_notification("Command system not ready.")


func handle_denied_developer_command(command_text: String, request_id: String = "", server_message: String = ""):
	if command_manager != null and command_manager.has_method("handle_denied_developer_command"):
		command_manager.handle_denied_developer_command(command_text, request_id, server_message)
	else:
		show_notification(server_message if server_message.strip_edges() != "" else "Server denied developer command.")


func handle_network_item_grant(data: Dictionary):
	if command_manager != null and command_manager.has_method("apply_network_item_grant"):
		command_manager.apply_network_item_grant(data)
	else:
		show_notification("Item grant system not ready.")


func apply_server_player_pull(data: Dictionary):
	if not MovementMode.is_websocket():
		return

	if player == null:
		return

	var pull_world: String = str(data.get("world", current_world_name)).strip_edges().to_upper()
	if pull_world != "" and pull_world != str(current_world_name).strip_edges().to_upper():
		return

	var target_position: Vector2 = player.global_position
	var raw_x: Variant = data.get("x", target_position.x)
	var raw_y: Variant = data.get("y", target_position.y)

	if raw_x is int or raw_x is float:
		target_position.x = float(raw_x)
	elif raw_x is String and str(raw_x).is_valid_float():
		target_position.x = float(raw_x)

	if raw_y is int or raw_y is float:
		target_position.y = float(raw_y)
	elif raw_y is String and str(raw_y).is_valid_float():
		target_position.y = float(raw_y)

	target_position.x = clamp(target_position.x, 0.0, float((WORLD_WIDTH - 1) * BLOCK_SIZE))
	target_position.y = clamp(target_position.y, 0.0, float((WORLD_HEIGHT - 1) * BLOCK_SIZE))
	player.global_position = target_position

	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
		player.set_physics_process(true)

	if player_manager != null and player_manager.has_method("reset_multiplayer_sync_state"):
		player_manager.reset_multiplayer_sync_state()

	var camera: Node = get_player_camera()
	if camera != null and camera.has_method("reset_smoothing"):
		camera.reset_smoothing()

	flush_multiplayer_position(false, true)

	var message: String = str(data.get("message", "")).strip_edges()
	if message != "":
		show_notification(message)


func apply_server_player_position_correction(data: Dictionary):
	if not MovementMode.is_websocket():
		return

	if player == null:
		return

	var correction_world: String = str(data.get("server_world", data.get("world", current_world_name))).strip_edges().to_upper()
	if correction_world != "" and correction_world != str(current_world_name).strip_edges().to_upper():
		return

	var target_position: Vector2 = player.global_position
	var raw_x: Variant = data.get("server_x", data.get("x", target_position.x))
	var raw_y: Variant = data.get("server_y", data.get("y", target_position.y))

	if raw_x is int or raw_x is float:
		target_position.x = float(raw_x)
	elif raw_x is String and str(raw_x).is_valid_float():
		target_position.x = float(raw_x)

	if raw_y is int or raw_y is float:
		target_position.y = float(raw_y)
	elif raw_y is String and str(raw_y).is_valid_float():
		target_position.y = float(raw_y)

	target_position.x = clamp(target_position.x, 0.0, float((WORLD_WIDTH - 1) * BLOCK_SIZE))
	target_position.y = clamp(target_position.y, 0.0, float((WORLD_HEIGHT - 1) * BLOCK_SIZE))
	var correction_distance: float = player.global_position.distance_to(target_position)
	var correction_smoothing_ms := int(data.get("correction_smoothing_ms", SERVER_POSITION_CORRECTION_DEFAULT_SMOOTH_MS))
	var should_snap := bool(data.get("correction_snap", false)) \
		or correction_smoothing_ms <= 0 \
		or correction_distance >= SERVER_POSITION_CORRECTION_SNAP_DISTANCE

	if server_position_correction_tween != null and server_position_correction_tween.is_valid():
		server_position_correction_tween.kill()
		server_position_correction_tween = null

	if should_snap:
		player.global_position = target_position
	else:
		var duration := clampf(float(correction_smoothing_ms) / 1000.0, 0.016, 0.18)
		server_position_correction_tween = create_tween()
		server_position_correction_tween.set_trans(Tween.TRANS_SINE)
		server_position_correction_tween.set_ease(Tween.EASE_OUT)
		server_position_correction_tween.tween_property(player, "global_position", target_position, duration)

	if data.has("server_facing"):
		set_player_facing_direction(int(data.get("server_facing", player_facing_direction)), false)

	if player is CharacterBody2D:
		var server_velocity := Vector2.ZERO
		if data.has("server_velocity_x") or data.has("server_velocity_y"):
			server_velocity = Vector2(float(data.get("server_velocity_x", 0.0)), float(data.get("server_velocity_y", 0.0)))
		player.velocity = Vector2.ZERO if should_snap else server_velocity
		player.set_physics_process(true)

	if player_manager != null and player_manager.has_method("reset_multiplayer_sync_state"):
		player_manager.reset_multiplayer_sync_state()

	var camera: Node = get_player_camera()
	if should_snap and camera != null and camera.has_method("reset_smoothing"):
		camera.reset_smoothing()


func handle_network_door_enter_ok(data: Dictionary):
	if save_manager != null and save_manager.has_method("handle_network_door_enter_ok"):
		save_manager.handle_network_door_enter_ok(data)
		return

	apply_server_door_spawn(data)


func apply_server_door_spawn(data: Dictionary):
	if player == null:
		return

	var target_world: String = str(data.get("world", current_world_name)).strip_edges().to_upper()
	if target_world != "" and target_world != str(current_world_name).strip_edges().to_upper():
		return

	var target_position: Vector2 = player.global_position
	var raw_x: Variant = data.get("x", data.get("portal_spawn_x", target_position.x))
	var raw_y: Variant = data.get("y", data.get("portal_spawn_y", target_position.y))

	if raw_x is int or raw_x is float:
		target_position.x = float(raw_x)
	elif raw_x is String and str(raw_x).is_valid_float():
		target_position.x = float(raw_x)

	if raw_y is int or raw_y is float:
		target_position.y = float(raw_y)
	elif raw_y is String and str(raw_y).is_valid_float():
		target_position.y = float(raw_y)

	target_position.x = clamp(target_position.x, 0.0, float((WORLD_WIDTH - 1) * BLOCK_SIZE))
	target_position.y = clamp(target_position.y, 0.0, float((WORLD_HEIGHT - 1) * BLOCK_SIZE))
	player.global_position = target_position

	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
		player.set_physics_process(true)

	if has_method("set_door_enter_cooldown"):
		set_door_enter_cooldown()

	if player_manager != null and player_manager.has_method("reset_multiplayer_sync_state"):
		player_manager.reset_multiplayer_sync_state()

	var camera: Node = get_player_camera()
	if camera != null and camera.has_method("reset_smoothing"):
		camera.reset_smoothing()

	flush_multiplayer_position(false, true)

	var message: String = str(data.get("message", "")).strip_edges()
	if message != "":
		show_notification(message)


func handle_inventory_transaction_result(data: Dictionary):
	var transaction_data: Dictionary = data
	var progression_value = data.get("progression", {})
	if progression_value is Dictionary:
		var progression_data: Dictionary = progression_value
		if int(progression_data.get("levels_gained", 0)) > 0:
			show_level_up_progression(progression_data)
			transaction_data = data.duplicate(true)
			transaction_data["message"] = ""

	var action = str(transaction_data.get("action", "")).strip_edges().to_lower()
	var transaction_ok = bool(transaction_data.get("ok", false))
	if action == "inventory_slot_upgrade" and transaction_ok:
		apply_inventory_slot_count(transaction_data.get("inventory_slot_count", inventory_slot_count))
	if action == "seed_harvest":
		var request_id = str(transaction_data.get("request_id", "")).strip_edges()
		if transaction_ok and bool(transaction_data.get("seed_removed", true)):
			_clear_seed_harvest_rollback_request(request_id)
		else:
			_restore_seed_harvest_request(request_id)

	var handled := false

	if display_ui != null and display_ui.has_method("handle_inventory_transaction_result"):
		handled = bool(display_ui.handle_inventory_transaction_result(transaction_data))

	if safe_ui != null and safe_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(safe_ui.handle_inventory_transaction_result(transaction_data))

	if donation_box_ui != null and donation_box_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(donation_box_ui.handle_inventory_transaction_result(transaction_data))

	if mailbox_ui != null and mailbox_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(mailbox_ui.handle_inventory_transaction_result(transaction_data))

	if vending_ui != null and vending_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(vending_ui.handle_inventory_transaction_result(transaction_data))

	if world_lock_ui != null and world_lock_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(world_lock_ui.handle_inventory_transaction_result(transaction_data))

	if shop_ui != null and shop_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(shop_ui.handle_inventory_transaction_result(transaction_data))

	if not handled and fish_monger_manager != null and fish_monger_manager.has_method("handle_inventory_transaction_result"):
		handled = bool(fish_monger_manager.handle_inventory_transaction_result(transaction_data))

	if not handled and crafting_ui != null and crafting_ui.has_method("handle_inventory_transaction_result"):
		handled = bool(crafting_ui.handle_inventory_transaction_result(transaction_data))

	if not handled and furnace_ui != null and furnace_ui.has_method("handle_inventory_transaction_result"):
		handled = bool(furnace_ui.handle_inventory_transaction_result(transaction_data))

	if not handled and fishing_manager != null and fishing_manager.has_method("handle_inventory_transaction_result"):
		handled = bool(fishing_manager.handle_inventory_transaction_result(transaction_data))

	if not handled:
		var message = str(transaction_data.get("message", "Inventory transaction finished."))
		if message.strip_edges() == "":
			message = get_progression_result_message(transaction_data.get("progression", {}))
		var action_for_message := str(action).strip_edges().to_lower()
		var source_type_for_message := str(transaction_data.get("source_type", "")).strip_edges().to_lower()
		var is_pickup_transaction := action_for_message == "drop_pickup" or action_for_message == "world_item_drop_pickup" or action_for_message == "world_drop_pickup" or source_type_for_message == "item_pickup"
		var is_seed_harvest_transaction := action_for_message == "seed_harvest" or source_type_for_message == "seed_harvest" or source_type_for_message == "tackle_box_harvest" or source_type_for_message == "chicken_feed" or source_type_for_message == "chicken_harvest" or source_type_for_message == "cow_feed" or source_type_for_message == "cow_harvest" or source_type_for_message == "duck_feed" or source_type_for_message == "duck_harvest" or source_type_for_message == "seed_place"
		if message.strip_edges() != "" and not is_pickup_transaction and not is_seed_harvest_transaction:
			show_notification(message)

	var refreshed_inventory_delta := refresh_ui_for_inventory_transaction_deltas(transaction_data)
	if not refreshed_inventory_delta:
		var player_data_payload = transaction_data.get("player_data", {})
		if player_data_payload is Dictionary and not player_data_payload.is_empty():
			update_all_ui()


func get_progression_result_message(progression_data) -> String:
	if not (progression_data is Dictionary):
		return ""

	var xp_gained := int(progression_data.get("xp_gained", 0))
	if xp_gained <= 0:
		return ""

	var levels_gained := int(progression_data.get("levels_gained", 0))
	var level_after := int(progression_data.get("level_after", player_level))
	var title := str(progression_data.get("title", player_title)).strip_edges()
	if levels_gained > 0:
		if title == "":
			return "Level " + str(level_after) + " reached!"
		return "Level " + str(level_after) + " reached: " + title + "!"

	var xp_after := int(progression_data.get("xp_after", player_xp))
	var xp_needed := int(progression_data.get("xp_needed", player_xp_needed))
	if xp_needed <= 0:
		return "+" + str(xp_gained) + " XP"
	return "+" + str(xp_gained) + " XP (" + str(xp_after) + "/" + str(xp_needed) + ")"


func show_level_up_progression(progression_data: Dictionary):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("show_level_up"):
		return gameplay_ui_manager.show_level_up(progression_data)

	var level_after := int(progression_data.get("level_after", player_level))
	var title := str(progression_data.get("title", player_title)).strip_edges()
	if title == "":
		show_notification("Level " + str(level_after) + " reached!")
	else:
		show_notification("Level " + str(level_after) + " reached: " + title + "!")



func restore_chat_ui_after_world_enter():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("restore_chat_ui_after_world_enter"):
		return gameplay_ui_manager.restore_chat_ui_after_world_enter()

	return

func setup_chat_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_chat_ui"):
		return gameplay_ui_manager.setup_chat_ui()

	return

func open_chat_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_chat_panel"):
		return gameplay_ui_manager.open_chat_panel()

	return

func close_chat_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_chat_panel"):
		return gameplay_ui_manager.close_chat_panel()

	return

func toggle_chat_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_chat_panel"):
		return gameplay_ui_manager.toggle_chat_panel()

	return

func send_chat_message():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("send_chat_message"):
		return gameplay_ui_manager.send_chat_message()

	return

func focus_chat_input():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("focus_chat_input"):
		return gameplay_ui_manager.focus_chat_input()

	return

func release_chat_focus():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("release_chat_focus"):
		return gameplay_ui_manager.release_chat_focus()

	return

func is_chat_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_chat_open"):
		return gameplay_ui_manager.is_chat_open()

	return false

func is_sign_text_focused() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_sign_text_focused"):
		return gameplay_ui_manager.is_sign_text_focused()

	return false

func is_any_text_input_focused() -> bool:
	var focus_owner = get_viewport().gui_get_focus_owner()

	if focus_owner == null:
		return false

	if focus_owner is LineEdit:
		return true

	if focus_owner is TextEdit:
		return true

	return false


func is_chat_input_focused() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_chat_input_focused"):
		return gameplay_ui_manager.is_chat_input_focused()

	return false


func is_major_ui_open() -> bool:
	if is_wooden_entrance_confirm_open():
		return true
	if is_theme_machine_confirm_open():
		return true
	if is_door_editor_open():
		return true
	if is_password_door_entry_open():
		return true
	if is_inventory_open():
		return true
	if is_chat_open():
		return true
	if is_shop_open():
		return true
	if is_notification_panel_open():
		return true
	if is_crafting_open():
		return true
	if is_furnace_open():
		return true
	if is_sign_open():
		return true
	if is_world_lock_ui_open():
		return true
	if is_area_lock_ui_open():
		return true
	if is_player_menu_open():
		return true
	if is_game_menu_open():
		return true
	if has_method("is_settings_panel_open") and is_settings_panel_open():
		return true
	if has_method("is_friends_panel_open") and is_friends_panel_open():
		return true
	if is_world_menu_open():
		return true
	if has_method("is_trade_open") and is_trade_open():
		return true
	if has_method("is_vending_open") and is_vending_open():
		return true
	if has_method("is_safe_open") and is_safe_open():
		return true
	if has_method("is_donation_box_open") and is_donation_box_open():
		return true
	if has_method("is_mailbox_open") and is_mailbox_open():
		return true
	if has_method("is_bulletin_board_open") and is_bulletin_board_open():
		return true
	if has_method("is_display_open") and is_display_open():
		return true
	if has_method("is_fish_monger_open") and is_fish_monger_open():
		return true
	if has_method("is_cctv_open") and is_cctv_open():
		return true
	if has_method("is_oil_refinery_open") and is_oil_refinery_open():
		return true
	if has_method("is_battery_charger_open") and is_battery_charger_open():
		return true
	if has_method("is_developer_panel_open") and is_developer_panel_open():
		return true

	return false


func is_movement_blocking_ui_open() -> bool:
	if is_wooden_entrance_confirm_open():
		return true
	if is_theme_machine_confirm_open():
		return true
	if is_door_editor_open():
		return true
	if is_password_door_entry_open():
		return true
	if is_shop_open():
		return true
	if is_notification_panel_open():
		return true
	if is_crafting_open():
		return true
	if is_furnace_open():
		return true
	if is_sign_open():
		return true
	if is_world_lock_ui_open():
		return true
	if is_area_lock_ui_open():
		return true
	if is_player_menu_open():
		return true
	if is_game_menu_open():
		return true
	if has_method("is_settings_panel_open") and is_settings_panel_open():
		return true
	if has_method("is_friends_panel_open") and is_friends_panel_open():
		return true
	if is_world_menu_open():
		return true
	if has_method("is_trade_open") and is_trade_open():
		return true
	if has_method("is_vending_open") and is_vending_open():
		return true
	if has_method("is_safe_open") and is_safe_open():
		return true
	if has_method("is_donation_box_open") and is_donation_box_open():
		return true
	if has_method("is_mailbox_open") and is_mailbox_open():
		return true
	if has_method("is_bulletin_board_open") and is_bulletin_board_open():
		return true
	if has_method("is_display_open") and is_display_open():
		return true
	if has_method("is_fish_monger_open") and is_fish_monger_open():
		return true
	if has_method("is_cctv_open") and is_cctv_open():
		return true
	if has_method("is_oil_refinery_open") and is_oil_refinery_open():
		return true
	if has_method("is_battery_charger_open") and is_battery_charger_open():
		return true
	if has_method("is_developer_panel_open") and is_developer_panel_open():
		return true

	return false


func is_gameplay_hud_blocked() -> bool:
	if is_wooden_entrance_confirm_open():
		return true
	if is_theme_machine_confirm_open():
		return true
	if is_door_editor_open():
		return true
	if is_password_door_entry_open():
		return true
	if is_shop_open():
		return true
	if is_notification_panel_open():
		return true
	if is_crafting_open():
		return true
	if is_furnace_open():
		return true
	if is_sign_open():
		return true
	if is_world_lock_ui_open():
		return true
	if is_area_lock_ui_open():
		return true
	if is_player_menu_open():
		return true
	if is_game_menu_open():
		return true
	if has_method("is_friends_panel_open") and is_friends_panel_open():
		return true
	if is_world_menu_open():
		return true
	if has_method("is_trade_open") and is_trade_open():
		return true
	if has_method("is_vending_open") and is_vending_open():
		return true
	if has_method("is_safe_open") and is_safe_open():
		return true
	if has_method("is_donation_box_open") and is_donation_box_open():
		return true
	if has_method("is_mailbox_open") and is_mailbox_open():
		return true
	if has_method("is_bulletin_board_open") and is_bulletin_board_open():
		return true
	if has_method("is_display_open") and is_display_open():
		return true
	if has_method("is_fish_monger_open") and is_fish_monger_open():
		return true
	if has_method("is_cctv_open") and is_cctv_open():
		return true
	if has_method("is_oil_refinery_open") and is_oil_refinery_open():
		return true
	if has_method("is_battery_charger_open") and is_battery_charger_open():
		return true
	if has_method("is_developer_panel_open") and is_developer_panel_open():
		return true

	return false


func is_movement_locked() -> bool:
	if not in_world:
		return true
	if is_player_dead_or_respawning():
		return true
	if is_movement_blocking_ui_open():
		return true
	if is_chat_input_focused():
		return true
	if is_any_text_input_focused():
		return true
	if is_sign_text_focused():
		return true
	if is_inventory_search_focused():
		return true
	if fishing_active:
		return true
	if fishing_manager != null and fishing_manager.has_method("is_fishing_active") and bool(fishing_manager.is_fishing_active()):
		return true

	return false

func setup_notification_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_notification_ui"):
		return gameplay_ui_manager.setup_notification_ui()

	return

func show_notification(message: String):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("show_notification"):
		return gameplay_ui_manager.show_notification(message)

	return


func open_notification_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_notification_panel"):
		return gameplay_ui_manager.open_notification_panel()

	return


func close_notification_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_notification_panel"):
		return gameplay_ui_manager.close_notification_panel()

	return


func toggle_notification_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_notification_panel"):
		return gameplay_ui_manager.toggle_notification_panel()

	return


func is_notification_panel_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_notification_panel_open"):
		return gameplay_ui_manager.is_notification_panel_open()

	return false


func setup_player_menu_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_player_menu_ui"):
		return gameplay_ui_manager.setup_player_menu_ui()

	return


func setup_game_menu_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_game_menu_ui"):
		return gameplay_ui_manager.setup_game_menu_ui()

	return


func setup_settings_panel_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_settings_panel_ui"):
		return gameplay_ui_manager.setup_settings_panel_ui()

	return


func setup_friends_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_friends_ui"):
		return gameplay_ui_manager.setup_friends_ui()

	return


func setup_developer_panel_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_developer_panel_ui"):
		return gameplay_ui_manager.setup_developer_panel_ui()

	return


func setup_trade_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_trade_ui"):
		return gameplay_ui_manager.setup_trade_ui()

	return

func setup_vending_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_vending_ui"):
		return gameplay_ui_manager.setup_vending_ui()

	return

func setup_safe_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_safe_ui"):
		return gameplay_ui_manager.setup_safe_ui()

	return

func setup_donation_box_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_donation_box_ui"):
		return gameplay_ui_manager.setup_donation_box_ui()

	return

func setup_mailbox_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_mailbox_ui"):
		return gameplay_ui_manager.setup_mailbox_ui()

	return

func setup_bulletin_board_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_bulletin_board_ui"):
		return gameplay_ui_manager.setup_bulletin_board_ui()

	return

func setup_display_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_display_ui"):
		return gameplay_ui_manager.setup_display_ui()

	return

func setup_fish_monger_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_fish_monger_ui"):
		return gameplay_ui_manager.setup_fish_monger_ui()

	return

func setup_cctv_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_cctv_ui"):
		return gameplay_ui_manager.setup_cctv_ui()

	return

func setup_oil_refinery_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_oil_refinery_ui"):
		return gameplay_ui_manager.setup_oil_refinery_ui()

	return

func setup_battery_charger_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_battery_charger_ui"):
		return gameplay_ui_manager.setup_battery_charger_ui()

	return


func setup_generator_ui():
	var parent_node: Node = self
	if ui_modal_layer != null:
		parent_node = ui_modal_layer
	if generator_ui == null:
		generator_ui = parent_node.get_node_or_null("GeneratorUI")

	if generator_ui != null and generator_ui.get_node_or_null("Window") == null:
		var existing_parent = generator_ui.get_parent()
		if existing_parent != null:
			existing_parent.remove_child(generator_ui)
		generator_ui.queue_free()
		generator_ui = null

	if generator_ui == null:
		var generator_scene = preload("res://Scenes/ui/generator/GeneratorGUI.tscn")
		generator_ui = generator_scene.instantiate()
		generator_ui.name = "GeneratorUI"
		parent_node.add_child(generator_ui)

	if generator_ui.has_method("setup"):
		generator_ui.setup(self)

	return

func toggle_player_menu():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_player_menu"):
		return gameplay_ui_manager.toggle_player_menu()

	return

func open_player_menu():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_player_menu"):
		return gameplay_ui_manager.open_player_menu()

	return

func close_player_menu():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_player_menu"):
		return gameplay_ui_manager.close_player_menu()

	return

func is_player_menu_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_player_menu_open"):
		return gameplay_ui_manager.is_player_menu_open()

	return false


func toggle_game_menu():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_game_menu"):
		return gameplay_ui_manager.toggle_game_menu()

	return


func open_game_menu():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_game_menu"):
		return gameplay_ui_manager.open_game_menu()

	return


func close_game_menu():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_game_menu"):
		return gameplay_ui_manager.close_game_menu()

	return


func is_game_menu_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_game_menu_open"):
		return gameplay_ui_manager.is_game_menu_open()

	return false


func open_settings_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_settings_panel"):
		return gameplay_ui_manager.open_settings_panel()

	return


func close_settings_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_settings_panel"):
		return gameplay_ui_manager.close_settings_panel()

	return


func is_settings_panel_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_settings_panel_open"):
		return gameplay_ui_manager.is_settings_panel_open()

	return false


func open_friends_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_friends_panel"):
		return gameplay_ui_manager.open_friends_panel()

	return


func close_friends_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_friends_panel"):
		return gameplay_ui_manager.close_friends_panel()

	return


func toggle_friends_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_friends_panel"):
		return gameplay_ui_manager.toggle_friends_panel()

	return


func is_friends_panel_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_friends_panel_open"):
		return gameplay_ui_manager.is_friends_panel_open()

	return false


func toggle_developer_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_developer_panel"):
		return gameplay_ui_manager.toggle_developer_panel()

	return


func open_developer_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_developer_panel"):
		return gameplay_ui_manager.open_developer_panel()

	return


func close_developer_panel():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_developer_panel"):
		return gameplay_ui_manager.close_developer_panel()

	return


func is_developer_panel_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_developer_panel_open"):
		return gameplay_ui_manager.is_developer_panel_open()

	return false

func handle_trade_message(data: Dictionary):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("handle_trade_message"):
		return gameplay_ui_manager.handle_trade_message(data)

	return

func close_trade_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_trade_ui"):
		return gameplay_ui_manager.close_trade_ui()

	return

func open_vending_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_vending_ui"):
		return gameplay_ui_manager.open_vending_ui(grid_pos)

	return

func close_vending_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_vending_ui"):
		return gameplay_ui_manager.close_vending_ui()

	return

func is_vending_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_vending_open"):
		return gameplay_ui_manager.is_vending_open()

	return false

func open_safe_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_safe_ui"):
		return gameplay_ui_manager.open_safe_ui(grid_pos)

	return

func close_safe_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_safe_ui"):
		return gameplay_ui_manager.close_safe_ui()

	return

func is_safe_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_safe_open"):
		return gameplay_ui_manager.is_safe_open()

	return false

func open_donation_box_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_donation_box_ui"):
		return gameplay_ui_manager.open_donation_box_ui(grid_pos)

	return

func close_donation_box_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_donation_box_ui"):
		return gameplay_ui_manager.close_donation_box_ui()

	return

func is_donation_box_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_donation_box_open"):
		return gameplay_ui_manager.is_donation_box_open()

	return false

func open_mailbox_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_mailbox_ui"):
		return gameplay_ui_manager.open_mailbox_ui(grid_pos)

	return

func close_mailbox_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_mailbox_ui"):
		return gameplay_ui_manager.close_mailbox_ui()

	return

func is_mailbox_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_mailbox_open"):
		return gameplay_ui_manager.is_mailbox_open()

	return false

func open_bulletin_board_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_bulletin_board_ui"):
		return gameplay_ui_manager.open_bulletin_board_ui(grid_pos)

	return

func close_bulletin_board_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_bulletin_board_ui"):
		return gameplay_ui_manager.close_bulletin_board_ui()

	return

func is_bulletin_board_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_bulletin_board_open"):
		return gameplay_ui_manager.is_bulletin_board_open()

	return false

func open_display_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_display_ui"):
		return gameplay_ui_manager.open_display_ui(grid_pos)

	return

func close_display_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_display_ui"):
		return gameplay_ui_manager.close_display_ui()

	return

func is_display_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_display_open"):
		return gameplay_ui_manager.is_display_open()

	return false

func open_fish_monger_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_fish_monger_ui"):
		return gameplay_ui_manager.open_fish_monger_ui(grid_pos)

	return

func close_fish_monger_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_fish_monger_ui"):
		return gameplay_ui_manager.close_fish_monger_ui()

	return

func is_fish_monger_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_fish_monger_open"):
		return gameplay_ui_manager.is_fish_monger_open()

	return false

func open_cctv_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_cctv_ui"):
		return gameplay_ui_manager.open_cctv_ui(grid_pos)

	return

func close_cctv_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_cctv_ui"):
		return gameplay_ui_manager.close_cctv_ui()

	return

func is_cctv_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_cctv_open"):
		return gameplay_ui_manager.is_cctv_open()

	return false

func open_oil_refinery_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_oil_refinery_ui"):
		return gameplay_ui_manager.open_oil_refinery_ui(grid_pos)

	return

func close_oil_refinery_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_oil_refinery_ui"):
		return gameplay_ui_manager.close_oil_refinery_ui()

	return

func is_oil_refinery_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_oil_refinery_open"):
		return gameplay_ui_manager.is_oil_refinery_open()

	return false


func open_battery_charger_ui(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_battery_charger_ui"):
		return gameplay_ui_manager.open_battery_charger_ui(grid_pos)

	return

func close_battery_charger_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_battery_charger_ui"):
		return gameplay_ui_manager.close_battery_charger_ui()

	return

func is_battery_charger_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_battery_charger_open"):
		return gameplay_ui_manager.is_battery_charger_open()

	return false


func open_generator_ui(grid_pos: Vector2i):
	if electricity_manager != null and electricity_manager.has_method("request_open_generator"):
		return electricity_manager.request_open_generator(grid_pos)

	return false


func close_generator_ui():
	if generator_ui != null and generator_ui.has_method("close_generator"):
		return generator_ui.close_generator()

	return


func begin_generator_link_mode(generator_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("begin_generator_link_mode"):
		return bool(electricity_manager.begin_generator_link_mode(generator_grid))

	return false


func begin_generator_output_link_mode(generator_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("begin_generator_output_link_mode"):
		return bool(electricity_manager.begin_generator_output_link_mode(generator_grid))

	return false


func has_pending_generator_link() -> bool:
	if electricity_manager != null and electricity_manager.has_method("has_pending_generator_link"):
		return bool(electricity_manager.has_pending_generator_link())

	return false


func begin_oil_refinery_link_mode(refinery_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("begin_oil_refinery_link_mode"):
		return bool(electricity_manager.begin_oil_refinery_link_mode(refinery_grid))

	return false


func has_pending_oil_refinery_link() -> bool:
	if electricity_manager != null and electricity_manager.has_method("has_pending_oil_refinery_link"):
		return bool(electricity_manager.has_pending_oil_refinery_link())

	return false


func begin_battery_charger_link_mode(charger_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("begin_battery_charger_link_mode"):
		return bool(electricity_manager.begin_battery_charger_link_mode(charger_grid))

	return false


func has_pending_battery_charger_link() -> bool:
	if electricity_manager != null and electricity_manager.has_method("has_pending_battery_charger_link"):
		return bool(electricity_manager.has_pending_battery_charger_link())

	return false


func has_pending_electric_tool_link() -> bool:
	if electricity_manager != null and electricity_manager.has_method("has_pending_electric_tool_link"):
		return bool(electricity_manager.has_pending_electric_tool_link())

	return false


func try_link_generator_pad_at(pad_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("try_link_generator_pad_at"):
		return bool(electricity_manager.try_link_generator_pad_at(pad_grid))

	return false


func try_electric_tool_link_at(grid_pos: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("try_electric_tool_link_at"):
		return bool(electricity_manager.try_electric_tool_link_at(grid_pos))

	return false


func try_link_oil_refinery_pole_at(pole_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("try_link_oil_refinery_pole_at"):
		return bool(electricity_manager.try_link_oil_refinery_pole_at(pole_grid))

	return false


func try_link_battery_charger_pole_at(pole_grid: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("try_link_battery_charger_pole_at"):
		return bool(electricity_manager.try_link_battery_charger_pole_at(pole_grid))

	return false


func is_generator_open() -> bool:
	if generator_ui != null:
		return bool(generator_ui.visible)

	return false


func cancel_trade_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("cancel_trade_ui"):
		return gameplay_ui_manager.cancel_trade_ui()

	return

func is_trade_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_trade_open"):
		return gameplay_ui_manager.is_trade_open()

	return false

func get_primary_hotbar_tool() -> String:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_primary_hotbar_tool"):
		return item_gameplay_manager.get_primary_hotbar_tool()

	return "punch"

func toggle_primary_hotbar_tool():
	if item_gameplay_manager != null and item_gameplay_manager.has_method("toggle_primary_hotbar_tool"):
		return item_gameplay_manager.toggle_primary_hotbar_tool()

	return

func is_crafting_station_block(block_type: String) -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_crafting_station_block"):
		return interaction_manager.is_crafting_station_block(block_type)

	return block_type == "crafting_station"

func get_crafting_station_left_pos(grid_pos: Vector2i) -> Vector2i:
	if interaction_manager != null and interaction_manager.has_method("get_crafting_station_left_pos"):
		return interaction_manager.get_crafting_station_left_pos(grid_pos)

	return grid_pos

func place_crafting_station_at_mouse():
	if interaction_manager != null and interaction_manager.has_method("place_crafting_station_at_mouse"):
		interaction_manager.place_crafting_station_at_mouse()

func break_crafting_station(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("break_crafting_station"):
		interaction_manager.break_crafting_station(grid_pos)

func interact_with_mouse():
	if interaction_manager != null and interaction_manager.has_method("interact_with_mouse"):
		interaction_manager.interact_with_mouse()

func interact_with_facing_tile():
	if interaction_manager != null and interaction_manager.has_method("interact_with_facing_tile"):
		interaction_manager.interact_with_facing_tile()

func is_wooden_entrance_block(block_type: String) -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_wooden_entrance_block"):
		return interaction_manager.is_wooden_entrance_block(block_type)

	if item_database.has(block_type):
		var item_data = item_database[block_type]
		return bool(item_data.get("entrance_block", false)) or item_data.has("entrance_frames")

	return block_type == "wooden_entrance"


func is_door_block(block_type: String) -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_door_block"):
		return interaction_manager.is_door_block(block_type)

	if item_database.has(block_type):
		var item_data = item_database[block_type]
		return bool(item_data.get("door_block", false))

	var clean = block_type.strip_edges().to_lower()
	return clean == "door" or clean.ends_with("_door")


func set_wooden_entrance_locked(grid_pos: Vector2i, locked: bool):
	if interaction_manager != null and interaction_manager.has_method("set_wooden_entrance_locked"):
		interaction_manager.set_wooden_entrance_locked(grid_pos, locked)

func toggle_wooden_entrance(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("toggle_wooden_entrance"):
		interaction_manager.toggle_wooden_entrance(grid_pos)

func is_wooden_entrance_confirm_open() -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_wooden_entrance_confirm_open"):
		return bool(interaction_manager.is_wooden_entrance_confirm_open())

	return false

func is_theme_machine_confirm_open() -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_theme_machine_confirm_open"):
		return bool(interaction_manager.is_theme_machine_confirm_open())

	return false

func is_door_editor_open() -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_door_editor_open"):
		return bool(interaction_manager.is_door_editor_open())

	return false

func is_password_door_entry_open() -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_password_door_entry_open"):
		return bool(interaction_manager.is_password_door_entry_open())

	return false

func close_wooden_entrance_confirm():
	if interaction_manager != null and interaction_manager.has_method("close_wooden_entrance_confirm"):
		interaction_manager.close_wooden_entrance_confirm()

func close_theme_machine_confirm():
	if interaction_manager != null and interaction_manager.has_method("close_theme_machine_confirm"):
		interaction_manager.close_theme_machine_confirm()

func close_door_editor():
	if interaction_manager != null and interaction_manager.has_method("close_door_editor"):
		interaction_manager.close_door_editor()

func close_password_door_entry():
	if interaction_manager != null and interaction_manager.has_method("close_password_door_entry"):
		interaction_manager.close_password_door_entry()

func update_wooden_entrance_visual(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("update_wooden_entrance_visual"):
		interaction_manager.update_wooden_entrance_visual(grid_pos)

func interact_with_grid(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("interact_with_grid"):
		interaction_manager.interact_with_grid(grid_pos)


func try_punch_toggle_machine_at(grid_pos: Vector2i) -> bool:
	if interaction_manager != null and interaction_manager.has_method("try_punch_toggle_machine_at"):
		return bool(interaction_manager.try_punch_toggle_machine_at(grid_pos))

	return false


func is_interactable_block(block_type: String) -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_interactable_block"):
		return bool(interaction_manager.is_interactable_block(block_type))

	return false

func apply_door_state_to_block(
	grid_pos: Vector2i,
	door_id: String,
	destination: String,
	locked: bool,
	target_world: String = "",
	target_door_id: String = "",
	password: String = "",
	password_configured: bool = false,
	password_changed: bool = false,
	door_name: String = ""
):
	if interaction_manager != null and interaction_manager.has_method("apply_door_state_to_block"):
		interaction_manager.apply_door_state_to_block(
			grid_pos,
			door_id,
			destination,
			locked,
			target_world,
			target_door_id,
			password,
			password_configured,
			password_changed,
			door_name
		)

func try_enter_door_at(grid_pos: Vector2i, force: bool = false, password: String = "") -> bool:
	if interaction_manager != null and interaction_manager.has_method("try_enter_door_at"):
		return bool(interaction_manager.try_enter_door_at(grid_pos, force, password))

	return false

func update_auto_door_entry(player_grid: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("update_auto_door_entry"):
		interaction_manager.update_auto_door_entry(player_grid)

func set_door_enter_cooldown(duration_msec: int = 1400):
	if interaction_manager != null and interaction_manager.has_method("set_door_enter_cooldown"):
		interaction_manager.set_door_enter_cooldown(duration_msec)

func setup_crafting_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_crafting_ui"):
		return gameplay_ui_manager.setup_crafting_ui()

	return

func open_crafting_station(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_crafting_station"):
		return gameplay_ui_manager.open_crafting_station(grid_pos)

	return

func close_crafting():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_crafting"):
		return gameplay_ui_manager.close_crafting()

	return

func is_crafting_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_crafting_open"):
		return gameplay_ui_manager.is_crafting_open()

	return false

func update_crafting_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_crafting_ui"):
		return gameplay_ui_manager.update_crafting_ui()

	return

func is_furnace_block(block_type: String) -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_furnace_block"):
		return interaction_manager.is_furnace_block(block_type)

	return block_type == "furnace"

func update_sign_text_visual(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_sign_text_visual"):
		return gameplay_ui_manager.update_sign_text_visual(grid_pos)

	return

func update_sign_hover_visibility():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_sign_hover_visibility"):
		return gameplay_ui_manager.update_sign_hover_visibility()

	return

func refresh_all_sign_text_visuals():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("refresh_all_sign_text_visuals"):
		return gameplay_ui_manager.refresh_all_sign_text_visuals()

	return

func is_sign_block(block_type: String) -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_sign_block"):
		return gameplay_ui_manager.is_sign_block(block_type)

	if item_database.has(block_type):
		return bool(item_database[block_type].get("sign_block", false))

	return block_type == "sign"

func is_toggle_block(block_type: String) -> bool:
	if interaction_manager != null and interaction_manager.has_method("is_toggle_block"):
		return interaction_manager.is_toggle_block(block_type)

	if item_database.has(block_type):
		return bool(item_database[block_type].get("toggle_block", false))

	return false

func setup_sign_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_sign_ui"):
		return gameplay_ui_manager.setup_sign_ui()

	return

func open_sign_editor(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_sign_editor"):
		return gameplay_ui_manager.open_sign_editor(grid_pos)

	return

func set_sign_text(grid_pos: Vector2i, text: String):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("set_sign_text"):
		return gameplay_ui_manager.set_sign_text(grid_pos, text)

	return

func close_sign():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_sign"):
		return gameplay_ui_manager.close_sign()

	return

func is_sign_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_sign_open"):
		return gameplay_ui_manager.is_sign_open()

	return false

func setup_furnace_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_furnace_ui"):
		return gameplay_ui_manager.setup_furnace_ui()

	return

func open_furnace_station(grid_pos: Vector2i):
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_furnace_station"):
		return gameplay_ui_manager.open_furnace_station(grid_pos)

	return

func close_furnace():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_furnace"):
		return gameplay_ui_manager.close_furnace()

	return

func is_furnace_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_furnace_open"):
		return gameplay_ui_manager.is_furnace_open()

	return false

func update_furnace_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_furnace_ui"):
		return gameplay_ui_manager.update_furnace_ui()

	return

func setup_shop_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_shop_ui"):
		return gameplay_ui_manager.setup_shop_ui()

	return

func update_shop_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_shop_ui"):
		return gameplay_ui_manager.update_shop_ui()

	return

func open_shop():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("open_shop"):
		return gameplay_ui_manager.open_shop()

	return

func close_shop():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("close_shop"):
		return gameplay_ui_manager.close_shop()

	return

func toggle_shop():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("toggle_shop"):
		return gameplay_ui_manager.toggle_shop()

	return

func is_shop_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_shop_open"):
		return gameplay_ui_manager.is_shop_open()

	return false

func setup_world_menu_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_world_menu_ui"):
		return gameplay_ui_manager.setup_world_menu_ui()

	return

func sanitize_world_name(raw_name: String) -> String:
	if save_manager != null and save_manager.has_method("sanitize_world_name"):
		return save_manager.sanitize_world_name(raw_name)

	return ""



func is_player_in_world() -> bool:
	if save_manager != null and save_manager.has_method("is_player_in_world"):
		return save_manager.is_player_in_world()

	return false



func get_current_world_display_name() -> String:
	if save_manager != null and save_manager.has_method("get_current_world_display_name"):
		return save_manager.get_current_world_display_name()

	return "NOT IN WORLD"



func ensure_world_save_folder():
	if save_manager != null and save_manager.has_method("ensure_world_save_folder"):
		return save_manager.ensure_world_save_folder()

	return



func get_current_save_path() -> String:
	if save_manager != null and save_manager.has_method("get_current_save_path"):
		return save_manager.get_current_save_path()

	return ""




func set_gameplay_world_active(active: bool, sync_world_nodes: bool = true):
	if save_manager != null and save_manager.has_method("set_gameplay_world_active"):
		return save_manager.set_gameplay_world_active(active, sync_world_nodes)

	return



func is_popup_ui_node_name(node_name: String) -> bool:
	if save_manager != null and save_manager.has_method("is_popup_ui_node_name"):
		return save_manager.is_popup_ui_node_name(node_name)

	return false



func set_gameplay_ui_visible(active: bool):
	if save_manager != null and save_manager.has_method("set_gameplay_ui_visible"):
		return save_manager.set_gameplay_ui_visible(active)

	return



func close_all_gameplay_popups():
	if save_manager != null and save_manager.has_method("close_all_gameplay_popups"):
		return save_manager.close_all_gameplay_popups()

	return




func exit_to_main_menu(save_current_world: bool = true):
	if save_manager != null and save_manager.has_method("exit_to_main_menu"):
		return save_manager.exit_to_main_menu(save_current_world)

	return



func exit_to_world_menu():
	if save_manager != null and save_manager.has_method("exit_to_world_menu"):
		return save_manager.exit_to_world_menu()

	return



func resume_current_world():
	if save_manager != null and save_manager.has_method("resume_current_world"):
		return save_manager.resume_current_world()

	return



func enter_world_by_name(raw_name: String):
	# SaveManager.enter_world_by_name() is async because it waits for the
	# loading overlay to draw before heavy world loading starts.
	# Keep this public World.gd wrapper synchronous so existing UI buttons/scripts
	# can still call world.enter_world_by_name("WORLD") without using await.
	if save_manager != null and save_manager.has_method("enter_world_by_name"):
		call_deferred("_run_enter_world_by_name_async", raw_name)
		return

	return


func _run_enter_world_by_name_async(raw_name: String) -> void:
	if save_manager == null:
		return
	if not save_manager.has_method("enter_world_by_name"):
		return

	await save_manager.enter_world_by_name(raw_name)



func is_world_menu_open() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_world_menu_open"):
		return gameplay_ui_manager.is_world_menu_open()

	return false

func is_world_name_input_focused() -> bool:
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("is_world_name_input_focused"):
		return gameplay_ui_manager.is_world_name_input_focused()

	return false

func setup_save_manager():
	if save_manager == null:
		var save_script = preload("res://Scripts/save_manager.gd")
		save_manager = Node.new()
		save_manager.name = "SaveManager"
		save_manager.set_script(save_script)
		add_child(save_manager)

	if save_manager.has_method("setup"):
		save_manager.setup(self, 1.0)


func update_inventory_label():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("update_inventory_label"):
		return gameplay_ui_manager.update_inventory_label()

	return

func save_player_data():
	if save_manager != null and save_manager.has_method("save_player_data"):
		return save_manager.save_player_data()

	return



func apply_network_player_state(data: Dictionary):
	if save_manager != null and save_manager.has_method("apply_network_player_state"):
		return save_manager.apply_network_player_state(data)

	return



func request_network_player_state():
	if save_manager != null and save_manager.has_method("request_network_player_state"):
		return save_manager.request_network_player_state()

	return



func load_player_data():
	if save_manager != null and save_manager.has_method("load_player_data"):
		return save_manager.load_player_data()

	return



func load_player_data_from_current_or_legacy(world_data: Dictionary):
	if save_manager != null and save_manager.has_method("load_player_data_from_current_or_legacy"):
		return save_manager.load_player_data_from_current_or_legacy(world_data)

	return



func load_legacy_player_data_from_world_name(world_name: String) -> Dictionary:
	if save_manager != null and save_manager.has_method("load_legacy_player_data_from_world_name"):
		return save_manager.load_legacy_player_data_from_world_name(world_name)

	return {}



func has_useful_player_data(data: Dictionary) -> bool:
	if save_manager != null and save_manager.has_method("has_useful_player_data"):
		return save_manager.has_useful_player_data(data)

	return false



func apply_player_data(data: Dictionary):
	if save_manager != null and save_manager.has_method("apply_player_data"):
		return save_manager.apply_player_data(data)

	return



func apply_saved_inventory_counts(target_inventory: Dictionary, saved_inventory, preserve_default_if_missing: bool):
	if save_manager != null and save_manager.has_method("apply_saved_inventory_counts"):
		return save_manager.apply_saved_inventory_counts(target_inventory, saved_inventory, preserve_default_if_missing)

	return



func get_world_save_path_for_name(world_name: String) -> String:
	if save_manager != null and save_manager.has_method("get_world_save_path_for_name"):
		return save_manager.get_world_save_path_for_name(world_name)

	return ""




func save_world():
	if save_manager != null and save_manager.has_method("save_world"):
		return save_manager.save_world()

	return



func load_world():
	if save_manager != null and save_manager.has_method("load_world"):
		return save_manager.load_world()

	return



func clear_world():
	_clear_seed_harvest_rollbacks()
	if save_manager != null and save_manager.has_method("clear_world"):
		return save_manager.clear_world()

	return



func clear_dropped_items():
	if save_manager != null and save_manager.has_method("clear_dropped_items"):
		return save_manager.clear_dropped_items()

	return


func reset_current_world():
	if save_manager != null and save_manager.has_method("reset_current_world"):
		return save_manager.reset_current_world()

	return false


# --- Multiplayer Movement Sync v1 coordinator wrappers ---
func update_multiplayer_movement(delta: float):
	if not MovementMode.is_websocket():
		return

	if player_manager != null and player_manager.has_method("update_multiplayer_movement"):
		return player_manager.update_multiplayer_movement(delta)

	return

func flush_multiplayer_position(allow_join: bool = false, bypass_rate_limit: bool = false) -> bool:
	if not MovementMode.is_websocket():
		return false

	if player_manager != null and player_manager.has_method("flush_multiplayer_position"):
		return bool(player_manager.flush_multiplayer_position(allow_join, bypass_rate_limit))

	return false

func process_multiplayer_remote_visuals(delta: float):
	if not MovementMode.is_websocket():
		return

	if player_manager != null and player_manager.has_method("process_multiplayer_remote_visuals"):
		return player_manager.process_multiplayer_remote_visuals(delta)

	return

func handle_network_existing_players(players_data):
	if not MovementMode.is_websocket():
		return

	if player_manager != null and player_manager.has_method("handle_network_existing_players"):
		return player_manager.handle_network_existing_players(players_data)

	return

func handle_network_player_position(player_data: Dictionary):
	if not MovementMode.is_websocket():
		return

	if player_manager != null and player_manager.has_method("handle_network_player_position"):
		return player_manager.handle_network_player_position(player_data)

	return

func handle_network_player_punch_knockback(data: Dictionary):
	if not MovementMode.is_websocket():
		return

	if player_manager != null and player_manager.has_method("handle_network_player_punch_knockback"):
		return player_manager.handle_network_player_punch_knockback(data)

	return

func handle_network_player_left(remote_id: String):
	if MovementMode.is_netfox_real():
		clear_remote_players()
		if netfox_real_manager != null and netfox_real_manager.has_method("audit_player_nodes"):
			netfox_real_manager.audit_player_nodes("websocket-player-left-ignored")
		return

	if player_manager != null and player_manager.has_method("handle_network_player_left"):
		return player_manager.handle_network_player_left(remote_id)

	return

func show_remote_chat_bubble(remote_id: String, message: String, remote_name: String = ""):
	if MovementMode.is_netfox_real():
		if netfox_real_manager != null and netfox_real_manager.has_method("show_remote_chat_bubble"):
			return netfox_real_manager.show_remote_chat_bubble(remote_id, message, remote_name)
		return

	if player_manager != null and player_manager.has_method("show_remote_chat_bubble"):
		return player_manager.show_remote_chat_bubble(remote_id, message, remote_name)

	return

func clear_remote_players():
	if player_manager != null and player_manager.has_method("clear_remote_players"):
		return player_manager.clear_remote_players()

	return

func get_remote_player_at_screen_position(screen_pos: Vector2) -> Dictionary:
	if MovementMode.is_netfox_real() and netfox_real_manager != null and netfox_real_manager.has_method("get_remote_player_at_screen_position"):
		return netfox_real_manager.get_remote_player_at_screen_position(screen_pos)
	if player_manager != null and player_manager.has_method("get_remote_player_at_screen_position"):
		return player_manager.get_remote_player_at_screen_position(screen_pos)

	return {}

func get_remote_player_in_interaction_range() -> Dictionary:
	if MovementMode.is_netfox_real() and netfox_real_manager != null and netfox_real_manager.has_method("get_remote_player_in_interaction_range"):
		return netfox_real_manager.get_remote_player_in_interaction_range()
	if player_manager != null and player_manager.has_method("get_remote_player_in_interaction_range"):
		return player_manager.get_remote_player_in_interaction_range()

	return {}

func request_player_punch_at_grid(grid_pos: Vector2i) -> bool:
	if MovementMode.is_netfox_real() and netfox_real_manager != null and netfox_real_manager.has_method("request_player_punch_at_grid"):
		return bool(netfox_real_manager.request_player_punch_at_grid(grid_pos))
	if player_manager != null and player_manager.has_method("request_player_punch_at_grid"):
		return bool(player_manager.request_player_punch_at_grid(grid_pos))

	return false

func request_player_punch_at_screen_position(screen_pos: Vector2) -> bool:
	if MovementMode.is_netfox_real() and netfox_real_manager != null and netfox_real_manager.has_method("request_player_punch_at_screen_position"):
		return bool(netfox_real_manager.request_player_punch_at_screen_position(screen_pos))
	if player_manager != null and player_manager.has_method("request_player_punch_at_screen_position"):
		return bool(player_manager.request_player_punch_at_screen_position(screen_pos))

	return false

func get_remote_player_profile_by_username(username: String) -> Dictionary:
	if MovementMode.is_netfox_real() and netfox_real_manager != null and netfox_real_manager.has_method("get_remote_player_profile_by_username"):
		return netfox_real_manager.get_remote_player_profile_by_username(username)
	if player_manager != null and player_manager.has_method("get_remote_player_profile_by_username"):
		return player_manager.get_remote_player_profile_by_username(username)

	return {}

func open_remote_player_profile(player_data: Dictionary):
	if player_menu_ui != null and player_menu_ui.has_method("open_remote_profile"):
		player_menu_ui.open_remote_profile(player_data)
		return

	open_player_menu()

func request_trade_with_player(player_data: Dictionary):
	var target_id = str(player_data.get("player_id", "")).strip_edges()
	var target_username = str(player_data.get("username", player_data.get("name", ""))).strip_edges()
	if target_id == "" and target_username == "":
		show_notification("Could not find that player.")
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_trade_request"):
		if network.send_trade_request(target_id, target_username):
			show_notification("Trade invite sent.")
			return

	show_notification("Connection required for trading.")


func request_friend_with_player(player_data: Dictionary):
	var target_username: String = str(player_data.get("username", player_data.get("name", ""))).strip_edges()
	if target_username == "":
		show_notification("Could not find that player.")
		return

	var current_username: String = get_current_profile_name().strip_edges()
	if current_username != "" and target_username.to_lower() == current_username.to_lower():
		show_notification("You cannot add yourself.")
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_friend_request"):
		if network.send_friend_request(target_username):
			if friends_ui != null and friends_ui.has_method("request_friend_state"):
				friends_ui.request_friend_state()
			return

	show_notification("Connection required for friends.")


func accept_friend_request_from(username: String):
	var clean_username: String = username.strip_edges()
	if clean_username == "":
		show_notification("Friend request not found.")
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_friend_response"):
		if network.send_friend_response(clean_username, true):
			return

	show_notification("Connection required for friends.")


func decline_friend_request_from(username: String):
	var clean_username: String = username.strip_edges()
	if clean_username == "":
		show_notification("Friend request not found.")
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_friend_response"):
		if network.send_friend_response(clean_username, false):
			return

	show_notification("Connection required for friends.")


func get_friend_status_for_username(username: String) -> String:
	if friends_ui != null and friends_ui.has_method("get_friend_status_for_username"):
		return str(friends_ui.get_friend_status_for_username(username))

	return "none"


func handle_friend_message(data: Dictionary):
	if friends_ui != null and friends_ui.has_method("handle_friend_message"):
		friends_ui.handle_friend_message(data)

	if player_menu_ui != null and player_menu_ui.has_method("handle_friend_message"):
		player_menu_ui.handle_friend_message(data)

	var message_type: String = str(data.get("type", "")).strip_edges().to_lower()
	var message: String = str(data.get("message", "")).strip_edges()
	match message_type:
		"friend_request_received":
			var from_username: String = str(data.get("from_username", data.get("requester_username", ""))).strip_edges()
			if notification_ui != null and notification_ui.has_method("add_friend_request_notification") and from_username != "":
				notification_ui.add_friend_request_notification(from_username)
			elif message != "":
				show_notification(message)
		"friend_request_sent", "friend_request_accepted", "friend_request_declined", "friend_response_result":
			if message != "":
				show_notification(message)
			if message_type == "friend_response_result":
				var requester_username: String = str(data.get("from_username", data.get("friend_username", ""))).strip_edges()
				if notification_ui != null and notification_ui.has_method("mark_friend_request_notification_resolved") and requester_username != "":
					notification_ui.mark_friend_request_notification_resolved(requester_username, bool(data.get("accepted", false)))
		"friend_error":
			show_notification(message if message != "" else "Friends are not available right now.")


func has_pending_trade_from_player(player_data: Dictionary) -> bool:
	var username = str(player_data.get("username", player_data.get("name", ""))).strip_edges()
	return has_pending_trade_from_username(username)

func has_pending_trade_from_username(username: String) -> bool:
	if trade_ui != null and trade_ui.has_method("has_pending_request_from"):
		return bool(trade_ui.has_pending_request_from(username))

	return false

func accept_trade_from_player(player_data: Dictionary):
	var username = str(player_data.get("username", player_data.get("name", ""))).strip_edges()
	accept_trade_from_username(username)

func accept_trade_from_username(username: String):
	var clean_username = username.strip_edges()
	if clean_username == "":
		show_notification("Use: /trade player_name")
		return

	if trade_ui != null and trade_ui.has_method("accept_pending_request_from") and bool(trade_ui.accept_pending_request_from(clean_username)):
		show_notification("Accepted trade request from " + clean_username + ".")
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_trade_response_from_player"):
		if network.send_trade_response_from_player(clean_username, true):
			show_notification("Accepting trade request from " + clean_username + "...")
			return

	show_notification("No pending trade request from " + clean_username + ".")


func handle_player_state_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	if save_manager == null or data == null:
		return

	var purpose = str(request_context.get("purpose", ""))

	if purpose == "world_lock_access_check":
		if world_lock_ui != null and world_lock_ui.has_method("handle_player_state_lookup_result"):
			world_lock_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "area_lock_access_check":
		if area_lock_ui != null and area_lock_ui.has_method("handle_player_state_lookup_result"):
			area_lock_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "remote_player_profile":
		if player_menu_ui != null and player_menu_ui.has_method("handle_player_state_lookup_result"):
			player_menu_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "admin_inventory_lookup":
		if developer_panel_ui != null and developer_panel_ui.has_method("handle_player_state_lookup_result"):
			developer_panel_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "admin_item_instance_lookup":
		if developer_panel_ui != null and developer_panel_ui.has_method("handle_player_state_lookup_result"):
			developer_panel_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "admin_item_instance_history_lookup":
		if developer_panel_ui != null and developer_panel_ui.has_method("handle_player_state_lookup_result"):
			developer_panel_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "admin_transaction_ledger_lookup":
		if developer_panel_ui != null and developer_panel_ui.has_method("handle_player_state_lookup_result"):
			developer_panel_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if purpose == "admin_monitoring_dashboard":
		if developer_panel_ui != null and developer_panel_ui.has_method("handle_player_state_lookup_result"):
			developer_panel_ui.handle_player_state_lookup_result(request_id, data, request_context)
		return

	if save_manager.has_method("apply_network_player_state"):
		save_manager.apply_network_player_state(data)


func get_world_event_type_from_payload(data: Dictionary) -> String:
	for key in ["active_event_type", "event_type", "event_name"]:
		var event_type := str(data.get(key, "")).strip_edges().to_lower()
		if event_type != "":
			return event_type

	var active_event = data.get("active_event", {})
	if active_event is Dictionary:
		return str(active_event.get("event_type", active_event.get("type", ""))).strip_edges().to_lower()

	return ""


func get_world_event_remaining_ms_from_payload(data: Dictionary) -> int:
	if data.has("event_remaining_ms"):
		return int(data.get("event_remaining_ms", 0))
	if data.has("remaining_ms"):
		return int(data.get("remaining_ms", 0))

	var active_event = data.get("active_event", {})
	if active_event is Dictionary:
		if active_event.has("remaining_ms"):
			return int(active_event.get("remaining_ms", 0))

	return -1


func set_snow_storm_visuals_active(active: bool):
	if block_manager != null and block_manager.has_method("set_snow_storm_visuals_active"):
		block_manager.set_snow_storm_visuals_active(active)
	set_snow_storm_particles_active(active)


func set_snow_storm_particles_active(active: bool):
	if active:
		if snow_storm_fx == null or not is_instance_valid(snow_storm_fx):
			if not ResourceLoader.exists(SNOW_STORM_FX_SCENE_PATH):
				return

			var snow_scene = load(SNOW_STORM_FX_SCENE_PATH)
			if snow_scene == null:
				return

			snow_storm_fx = snow_scene.instantiate()
			add_child(snow_storm_fx)

		if snow_storm_fx.has_method("start"):
			snow_storm_fx.start()
		else:
			snow_storm_fx.visible = true

		if snow_storm_wind_fx == null or not is_instance_valid(snow_storm_wind_fx):
			if ResourceLoader.exists(SNOW_STORM_WIND_FX_SCENE_PATH):
				var wind_scene = load(SNOW_STORM_WIND_FX_SCENE_PATH)
				if wind_scene != null:
					snow_storm_wind_fx = wind_scene.instantiate()
					add_child(snow_storm_wind_fx)

		if snow_storm_wind_fx != null and is_instance_valid(snow_storm_wind_fx):
			if snow_storm_wind_fx.has_method("start"):
				snow_storm_wind_fx.start()
			else:
				snow_storm_wind_fx.visible = true
		return

	if snow_storm_fx != null and is_instance_valid(snow_storm_fx):
		if snow_storm_fx.has_method("stop"):
			snow_storm_fx.stop()
		else:
			snow_storm_fx.visible = false

	if snow_storm_wind_fx != null and is_instance_valid(snow_storm_wind_fx):
		if snow_storm_wind_fx.has_method("stop"):
			snow_storm_wind_fx.stop()
		else:
			snow_storm_wind_fx.visible = false


func apply_world_event_state_from_network(data: Dictionary):
	var event_type := get_world_event_type_from_payload(data)
	var remaining_ms := get_world_event_remaining_ms_from_payload(data)
	set_snow_storm_visuals_active(event_type == "snow_storm" and remaining_ms != 0)


func handle_world_event_started(data: Dictionary):
	if get_world_event_type_from_payload(data) == "snow_storm":
		set_snow_storm_visuals_active(true)


func handle_world_event_ended(data: Dictionary):
	if get_world_event_type_from_payload(data) == "snow_storm":
		set_snow_storm_visuals_active(false)


# --- Multiplayer World State Sync v1 coordinator/apply helpers ---
func apply_network_world_state(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_world_state"):
		world_state_sync_manager.apply_network_world_state(data)


func apply_network_block_update(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_block_update"):
		world_state_sync_manager.apply_network_block_update(data)


func apply_network_block_reconcile(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_block_reconcile"):
		world_state_sync_manager.apply_network_block_reconcile(data)


func apply_network_world_interaction_update(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_world_interaction_update"):
		world_state_sync_manager.apply_network_world_interaction_update(data)


func apply_network_seed_update(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_seed_update"):
		world_state_sync_manager.apply_network_seed_update(data)


func apply_network_electrical_layer_update(data: Dictionary):
	if electricity_manager != null and electricity_manager.has_method("apply_electrical_layer_update"):
		electricity_manager.apply_electrical_layer_update(data)


func apply_network_wire_visibility_refresh(data: Dictionary):
	if electricity_manager != null and electricity_manager.has_method("apply_visibility_payload"):
		electricity_manager.apply_visibility_payload(data)


func apply_network_generator_data_update(data: Dictionary):
	if electricity_manager != null and electricity_manager.has_method("handle_generator_data_update"):
		electricity_manager.handle_generator_data_update(data)
	elif generator_ui != null and generator_ui.has_method("open_generator"):
		generator_ui.open_generator(data)


func apply_network_generator_generation_pulse(data: Dictionary):
	if electricity_manager != null and electricity_manager.has_method("handle_generator_generation_pulse"):
		electricity_manager.handle_generator_generation_pulse(data)
	elif generator_ui != null and generator_ui.has_method("show_generation_pulse"):
		generator_ui.show_generation_pulse(data)


func is_electrical_item(item_id: String) -> bool:
	if electricity_manager != null and electricity_manager.has_method("is_electrical_item"):
		return bool(electricity_manager.is_electrical_item(item_id))

	return false


func try_place_electrical_item_at(grid_pos: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("try_place_selected_electrical_at"):
		return bool(electricity_manager.try_place_selected_electrical_at(grid_pos))

	return false


func try_break_electrical_tile_at(grid_pos: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("try_break_electrical_at"):
		return bool(electricity_manager.try_break_electrical_at(grid_pos))

	return false


func has_visible_electrical_tile_at(grid_pos: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("has_visible_electrical_tile_at"):
		return bool(electricity_manager.has_visible_electrical_tile_at(grid_pos))

	return false


func is_visible_generator_at(grid_pos: Vector2i) -> bool:
	if electricity_manager != null and electricity_manager.has_method("is_visible_generator_at"):
		return bool(electricity_manager.is_visible_generator_at(grid_pos))

	return false


func get_electrical_save_data() -> Array:
	if electricity_manager != null and electricity_manager.has_method("get_save_data"):
		return electricity_manager.get_save_data()

	return []


func load_electrical_save_data(entries) -> void:
	if electricity_manager != null and electricity_manager.has_method("load_save_data"):
		electricity_manager.load_save_data(entries)


func clear_electrical_layer() -> void:
	if electricity_manager != null and electricity_manager.has_method("clear_all"):
		electricity_manager.clear_all()
