extends Node2D

const BLOCK_SIZE = 32
const WORLD_WIDTH = 100
const GROUND_Y = 14
const WORLD_HEIGHT = 70
const PICKUP_RANGE = 28.0
const INTERACTION_PIXEL_RANGE = 128.0
const SAVE_PATH = "user://world_save.json"
const WORLD_SAVE_FOLDER = "user://worlds/"
const PLAYER_SAVE_PATH = "user://pixelmania_player_data.json"
const PLAYER_DATA_VERSION = 1
const PLAYER_MAX_LEVEL = 100
const DEFAULT_WORLD_NAME = "START"
const WORLD_VERSION = 10
const INVALID_GRID_POS = Vector2i(999999, 999999)
const HOTBAR_SLOT_COUNT = 6
const MAX_ITEM_STACK_SIZE = 200
const GEM_CURRENCY_ITEM_ID = "gem"
const GEM_CURRENCY_CAP = 100000000000

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

const HOTBAR_HEIGHT = 104.0
const INVENTORY_DRAWER_WIDTH = 500.0
const INVENTORY_DRAWER_HEIGHT = 360.0
const INVENTORY_OPEN_SPEED = 8.0

const LAVA_DAMAGE_DELAY = 0.6
const RESPAWN_POSITION = Vector2(300, (SURFACE_Y - 2) * BLOCK_SIZE)
const SEED_DROP_CHANCE = 0.25
const SEED_GROW_TIME = 8.0
const MATURE_SEED_EXTRA_DROP_CHANCE = 0.65
const BLOCK_MAX_HITS = 3
const BLOCK_DAMAGE_RESET_DELAY = 3.0
const GEM_DROP_CHANCE = 1.0
const GEM_DROP_MIN = 1
const GEM_DROP_MAX = 3

const WATER_ANIMATION_SPEED = 0.18
const WATER_MIN_POOL_SPACING = 13

const ENTRANCE_GATE_TYPE = "entrance_gate"
const ENTRANCE_GATE_CLEAR_RADIUS = 3

var block_scene = preload("res://Scenes/block.tscn")
var blocks = {}
var vending_states = {}
var safe_states = {}
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
var lava_damage_timer = 0.0
var player_facing_direction = 1
var current_camera_zoom = CAMERA_ZOOM_DEFAULT
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
const NOCLIP_SPEED = 260.0

const BACK_ITEM_JUMP_VELOCITY = -420.0
const LEGENDARY_WINGS_ID = "legendary_wings"

const FISHING_ROD_ID = "fishing_rod"
const FISHING_CAST_TIME = 1.25
const FISHING_CAST_PIXEL_RANGE = BLOCK_SIZE * 6
const LURE_PACK_SIZE = 5
var equipped_tool = ""
var equipped_back_item = ""
var equipped_hair_item = ""
var equipped_shirt_item = ""
var equipped_pants_item = ""
var equipped_shoes_item = ""
var equipped_tool_visual = null
var equipped_tool_sprite = null

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

const ItemDatabase = preload("res://Scripts/item_database.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

var item_database = ItemDatabase.ITEMS.duplicate(true)
var splice_recipes = ItemDatabase.SPLICE_RECIPES

var inventory = {}
var seed_inventory = {}
var tool_inventory = {}
var back_inventory = {}
var hair_inventory = {}
var shirt_inventory = {}
var pants_inventory = {}
var shoes_inventory = {}
var currency_inventory = {}
var material_inventory = {}
var block_textures = {}
var crack_textures = {}
var seed_textures = {}
var seed_tree_textures = {}
var tool_textures = {}
var back_textures = {}
var hair_textures = {}
var shirt_textures = {}
var pants_textures = {}
var shoes_textures = {}
var currency_textures = {}
var material_textures = {}
var block_items = []
var tool_items = []
var back_items = []
var hair_items = []
var shirt_items = []
var pants_items = []
var shoes_items = []
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
var friends_ui = null
var developer_panel_ui = null
var trade_ui = null
var vending_ui = null
var safe_ui = null
var fish_monger_ui = null
var shop_ui = null
var crafting_ui = null
var furnace_ui = null
var sign_ui = null
var world_menu_ui = null
var notification_ui = null
var drop_manager = null
var world_generation_manager = null
var block_manager = null
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
var username_label_manager = null
var background_manager = null
var reach_indicator_manager = null
var sound_manager = null
var world_loading_ui_manager = null
var world_state_sync_manager = null
var applying_network_world_update = false


func is_gem_currency(item_type: String, category: String = "currency") -> bool:
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


func clamp_item_stack_count(item_type: String, category: String, count: int) -> int:
	return int(clamp(count, 0, get_stack_limit_for_item(item_type, category)))


func add_item_to_inventory_stack(target_inventory: Dictionary, item_type: String, category: String, amount: int) -> int:
	var current_count = max(0, int(target_inventory.get(item_type, 0)))
	var safe_amount = max(0, amount)
	var next_count = clamp_item_stack_count(item_type, category, current_count + safe_amount)
	target_inventory[item_type] = next_count
	return next_count - current_count


func spend_item_from_inventory_stack(target_inventory: Dictionary, item_type: String, category: String, amount: int) -> bool:
	var safe_amount = max(0, amount)
	var current_count = max(0, int(target_inventory.get(item_type, 0)))
	if current_count < safe_amount:
		return false
	target_inventory[item_type] = clamp_item_stack_count(item_type, category, current_count - safe_amount)
	return true


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


func load_texture_spec(texture_spec) -> Texture2D:
	return AtlasTextureFactory.load_texture(texture_spec)


func load_item_texture_spec(item_data: Dictionary, texture_key: String = "texture") -> Texture2D:
	if not item_data.has(texture_key):
		return null

	return load_texture_spec(item_data.get(texture_key))


func load_texture_spec_list(texture_specs: Array) -> Array[Texture2D]:
	return AtlasTextureFactory.load_texture_list(texture_specs)


func setup_item_database():
	inventory.clear()
	seed_inventory.clear()
	block_textures.clear()
	seed_textures.clear()
	seed_tree_textures.clear()
	tool_inventory.clear()
	back_inventory.clear()
	hair_inventory.clear()
	shirt_inventory.clear()
	pants_inventory.clear()
	shoes_inventory.clear()
	currency_inventory.clear()
	material_inventory.clear()
	lure_inventory.clear()
	fish_inventory.clear()
	tool_textures.clear()
	back_textures.clear()
	hair_textures.clear()
	shirt_textures.clear()
	pants_textures.clear()
	shoes_textures.clear()
	currency_textures.clear()
	material_textures.clear()
	lure_textures.clear()
	fish_textures.clear()
	tool_items.clear()
	back_items.clear()
	hair_items.clear()
	shirt_items.clear()
	pants_items.clear()
	shoes_items.clear()
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
			"interaction_permission": "owner_only",
			"seed": "",
			"order": 900
		}

	for item_id in item_database.keys():
		var item_data = item_database[item_id]
		var category = str(item_data.get("category", ""))

		if category == "block":
			inventory[item_id] = 0

			if not bool(item_data.get("hidden", false)):
				block_items.append(item_id)

			var block_texture = load_item_texture_spec(item_data)
			if block_texture != null:
				block_textures[item_id] = block_texture

		elif category == "seed":
			seed_inventory[item_id] = 0

			var seed_texture = load_item_texture_spec(item_data)
			if seed_texture != null:
				seed_textures[item_id] = seed_texture

			var grows_into = str(item_data.get("grows_into", ""))
			if grows_into != "":
				var tree_paths = item_data.get("tree_textures", [])
				var loaded_tree_textures = []

				for tree_path in tree_paths:
					var tree_texture = load_texture_spec(tree_path)
					if tree_texture != null:
						loaded_tree_textures.append(tree_texture)

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
					"res://Assets/player/back_item/legendary_wings/legendary_wings_idle.png",
					"res://Assets/player/back_item/legendary_wings/legendary_wings_flap1.png",
					"res://Assets/player/back_item/legendary_wings/legendary_wings_flap2.png"
				]

				for fallback_path in fallback_back_paths:
					if ResourceLoader.exists(fallback_path):
						back_textures[item_id] = load_texture_spec(fallback_path)
						break

		elif category == "hair":
			hair_inventory[item_id] = int(item_data.get("starting_count", 0))
			hair_items.append(item_id)

			var hair_texture = load_item_texture_spec(item_data)
			if hair_texture != null:
				hair_textures[item_id] = hair_texture

		elif category == "shirt":
			shirt_inventory[item_id] = int(item_data.get("starting_count", 0))
			shirt_items.append(item_id)

			var shirt_texture = load_item_texture_spec(item_data)
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
	hair_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	shirt_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	pants_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	shoes_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	material_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	lure_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	fish_items.sort_custom(Callable(self, "sort_item_ids_by_order"))

	var bedrock_texture = load_texture_spec("res://Assets/blocks/basic blocks/bedrock_block.png")
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
	player.z_index = 100

	# Godot can still be setting up child nodes during _ready().
	# Run move_child later so it does not error.
	call_deferred("move_player_to_front")


func move_player_to_front():
	if player == null:
		return

	var parent_node = get_parent()

	if parent_node != null:
		parent_node.move_child(player, parent_node.get_child_count() - 1)


func _ready():
	setup_background_manager()
	setup_reach_indicator_manager()
	setup_sound_manager()
	setup_world_loading_ui_manager()
	setup_item_database()
	setup_drop_manager()
	setup_world_generation_manager()
	setup_block_manager()
	setup_block_shadow_manager()
	setup_interaction_manager()
	setup_player_manager()
	setup_gameplay_ui_manager()
	setup_fishing_manager()
	setup_fish_monger_manager()
	setup_item_gameplay_manager()
	setup_vending_preview_manager()
	setup_environment_manager()
	setup_input_manager()
	setup_account_manager()
	setup_world_lock_manager()
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
	setup_fish_monger_ui()
	setup_shop_ui()
	setup_crafting_ui()
	setup_furnace_ui()
	setup_sign_ui()
	setup_world_menu_ui()

	exit_to_main_menu(false)
	update_all_ui()


func _process(delta):
	if not in_world:
		return

	update_smooth_world_load_timeout()
	if is_smooth_world_load_waiting_for_server_state():
		return

	update_chat_typing_movement_lock()
	update_player_facing_direction()
	update_player_animation(delta)
	update_noclip_movement(delta)
	update_equipment_visual()
	update_back_item_animation(delta)
	update_back_item_jump_reset()
	clamp_player_to_world()
	check_lava_damage(delta)
	update_item_drops(delta)
	update_planted_seeds(delta)
	update_block_damage_recovery(delta)
	update_sign_hover_visibility()
	update_water_animation(delta)
	update_fishing(delta)
	update_multiplayer_movement(delta)
	process_multiplayer_remote_visuals(delta)


func _physics_process(_delta):
	pass


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


func _unhandled_input(event):
	if input_manager != null and input_manager.has_method("handle_unhandled_input"):
		input_manager.handle_unhandled_input(event)



func update_back_item_jump_reset():
	if player_manager != null and player_manager.has_method("update_back_item_jump_reset"):
		return player_manager.update_back_item_jump_reset()

	return
func try_back_item_air_jump(event: InputEventKey) -> bool:
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
	if environment_manager != null and environment_manager.has_method("get_entrance_gate_spawn_position"):
		return environment_manager.get_entrance_gate_spawn_position()

	return Vector2.ZERO

func ensure_entrance_gate():
	if environment_manager != null and environment_manager.has_method("ensure_entrance_gate"):
		return environment_manager.ensure_entrance_gate()

	return

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


func setup_block_shadow_manager():
	if block_shadow_manager == null:
		var shadow_script = preload("res://Scripts/block_shadow_manager.gd")
		block_shadow_manager = Node2D.new()
		block_shadow_manager.name = "BlockShadowManager"
		block_shadow_manager.set_script(shadow_script)
		add_child(block_shadow_manager)

	if block_shadow_manager.has_method("setup"):
		block_shadow_manager.setup(self)


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
		var player_script = preload("res://Scripts/player_manager.gd")
		player_manager = Node.new()
		player_manager.name = "PlayerManager"
		player_manager.set_script(player_script)
		add_child(player_manager)

	if player_manager.has_method("setup"):
		player_manager.setup(self)


func setup_gameplay_ui_manager():
	if gameplay_ui_manager == null:
		var ui_script = preload("res://Scripts/gameplay_ui_manager.gd")
		gameplay_ui_manager = Node.new()
		gameplay_ui_manager.name = "GameplayUIManager"
		gameplay_ui_manager.set_script(ui_script)
		add_child(gameplay_ui_manager)

	if gameplay_ui_manager.has_method("setup"):
		gameplay_ui_manager.setup(self)

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


func play_sound_punch():
	if sound_manager != null and sound_manager.has_method("play_punch"):
		sound_manager.play_punch()

func play_sound_place():
	if sound_manager != null and sound_manager.has_method("play_place"):
		sound_manager.play_place()

func play_sound_jump():
	if sound_manager != null and sound_manager.has_method("play_jump"):
		sound_manager.play_jump()


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
	if world_lock_ui == null:
		var lock_ui_script = load("res://Scripts/world_lock_ui.gd")
		if lock_ui_script == null:
			if has_method("show_notification"):
				show_notification("World Lock UI script failed to load.")
			return
		if not (lock_ui_script is Script):
			if has_method("show_notification"):
				show_notification("World Lock UI script is not valid.")
			return

		world_lock_ui = Control.new()
		world_lock_ui.name = "WorldLockUI"
		world_lock_ui.set_script(lock_ui_script)
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

func can_current_player_build() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_build"):
		return world_lock_manager.can_current_player_build()
	return true


func can_current_player_break_block(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_break_block"):
		return world_lock_manager.can_current_player_break_block(block_type)

	return true

func can_current_player_place_block(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_place_block"):
		return world_lock_manager.can_current_player_place_block(block_type)

	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_build"):
		return world_lock_manager.can_current_player_build()

	return true

func can_current_player_interact_with_block(block_type: String) -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_interact_with_block"):
		return world_lock_manager.can_current_player_interact_with_block(block_type)

	return true

func can_current_player_toggle_wooden_entrance() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_toggle_wooden_entrance"):
		return bool(world_lock_manager.can_current_player_toggle_wooden_entrance())

	return true

func can_current_player_pass_wooden_entrance() -> bool:
	if world_lock_manager != null and world_lock_manager.has_method("can_current_player_pass_wooden_entrance"):
		return bool(world_lock_manager.can_current_player_pass_wooden_entrance())

	return true

func on_world_lock_block_placed(grid_pos: Vector2i):
	if world_lock_manager != null and world_lock_manager.has_method("on_world_lock_block_placed"):
		return world_lock_manager.on_world_lock_block_placed(grid_pos)

	return

func on_world_lock_block_broken(grid_pos: Vector2i):
	if world_lock_manager != null and world_lock_manager.has_method("on_world_lock_block_broken"):
		return world_lock_manager.on_world_lock_block_broken(grid_pos)

	return

func get_world_lock_save_data() -> Dictionary:
	if world_lock_manager != null and world_lock_manager.has_method("get_save_data"):
		return world_lock_manager.get_save_data()

	return {}

func load_world_lock_save_data(data: Dictionary):
	if world_lock_manager != null and world_lock_manager.has_method("load_save_data"):
		return world_lock_manager.load_save_data(data)

	return

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
	if player_animation_manager != null and player_animation_manager.has_method("update_player_animation"):
		player_animation_manager.update_player_animation(delta, player_facing_direction)


func setup_equipment_manager():
	if equipment_manager == null:
		var equipment_script = preload("res://Scripts/equipment_manager.gd")
		equipment_manager = Node.new()
		equipment_manager.name = "EquipmentManager"
		equipment_manager.set_script(equipment_script)
		add_child(equipment_manager)

	if equipment_manager.has_method("setup"):
		equipment_manager.setup(self, player)



func update_back_item_animation(delta: float):
	if equipment_manager != null and equipment_manager.has_method("update_back_item_animation"):
		equipment_manager.update_back_item_animation(delta)


func update_equipment_visual():
	if equipped_tool == null:
		equipped_tool = ""

	if equipped_back_item == null:
		equipped_back_item = ""

	if equipped_hair_item == null:
		equipped_hair_item = ""

	if equipped_shirt_item == null:
		equipped_shirt_item = ""

	if equipped_pants_item == null:
		equipped_pants_item = ""

	if equipped_shoes_item == null:
		equipped_shoes_item = ""

	equipped_tool = str(equipped_tool)
	equipped_back_item = str(equipped_back_item)
	equipped_hair_item = str(equipped_hair_item)
	equipped_shirt_item = str(equipped_shirt_item)
	equipped_pants_item = str(equipped_pants_item)
	equipped_shoes_item = str(equipped_shoes_item)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_tool_visual"):
		equipment_manager.update_equipped_tool_visual(equipped_tool, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_back_visual"):
		equipment_manager.update_equipped_back_visual(equipped_back_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_hair_visual"):
		equipment_manager.update_equipped_hair_visual(equipped_hair_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_shirt_visual"):
		equipment_manager.update_equipped_shirt_visual(equipped_shirt_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_pants_visual"):
		equipment_manager.update_equipped_pants_visual(equipped_pants_item, player_facing_direction)

	if equipment_manager != null and equipment_manager.has_method("update_equipped_shoes_visual"):
		equipment_manager.update_equipped_shoes_visual(equipped_shoes_item, player_facing_direction)


func get_current_break_power(block_type: String = "") -> int:
	if item_gameplay_manager != null and item_gameplay_manager.has_method("get_current_break_power"):
		return item_gameplay_manager.get_current_break_power(block_type)

	return 1

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

func handle_rejected_drop_pickup(drop_id: String, message: String = "") -> bool:
	if drop_manager != null and drop_manager.has_method("handle_rejected_drop_pickup"):
		return bool(drop_manager.handle_rejected_drop_pickup(drop_id, message))
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
func punch_facing_block():
	if block_manager != null and block_manager.has_method("punch_facing_block"):
		block_manager.punch_facing_block()

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
func roll_fish_for_lure(lure_id: String) -> String:
	if fishing_manager != null and fishing_manager.has_method("roll_fish_for_lure"):
		return fishing_manager.roll_fish_for_lure(lure_id)

	return ""
func get_fishing_table_for_lure(lure_id: String) -> Array:
	if fishing_manager != null and fishing_manager.has_method("get_fishing_table_for_lure"):
		return fishing_manager.get_fishing_table_for_lure(lure_id)

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

	if create_planted_seed(grid_pos, selected_item_type, SEED_GROW_TIME):
		seed_inventory[selected_item_type] -= 1
		show_notification("Planted " + get_item_display_name(selected_item_type, selected_item_category) + ".")
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
			get_global_mouse_position()
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

	if seed_system.has_method("try_splice_seed_tree"):
		var did_splice = seed_system.try_splice_seed_tree(
			grid_pos,
			selected_item_type,
			selected_item_category,
			seed_inventory
		)

		if did_splice:
			update_all_ui()

		return did_splice

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

	return bool(network.send_inventory_transaction_request({
		"action": "seed_place",
		"world": current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"seed_type": selected_item_type,
		"grow_time": SEED_GROW_TIME,
		"max_grow_time": SEED_GROW_TIME
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
	if should_use_server_authoritative_world_actions():
		if request_server_seed_harvest(grid_pos):
			show_notification("Harvesting seed-tree...")
		else:
			show_notification("Almost ready. Try again in a moment.")
		return

	if seed_system != null and seed_system.has_method("harvest_planted_seed"):
		seed_system.harvest_planted_seed(grid_pos)


func request_server_seed_harvest(grid_pos: Vector2i) -> bool:
	if not should_use_server_authoritative_world_actions():
		return false

	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	return bool(network.send_inventory_transaction_request({
		"action": "seed_harvest",
		"world": current_world_name,
		"x": grid_pos.x,
		"y": grid_pos.y
	}))


func clear_planted_seeds():
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
	var mouse_pos = get_global_mouse_position()

	var grid_x = int(round(mouse_pos.x / BLOCK_SIZE))
	var grid_y = int(round(mouse_pos.y / BLOCK_SIZE))

	return Vector2i(grid_x, grid_y)


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

func is_vending_machine_block_type(block_type: String) -> bool:
	if vending_preview_manager != null and vending_preview_manager.has_method("is_vending_machine_block_type"):
		return bool(vending_preview_manager.is_vending_machine_block_type(block_type))

	return false

func update_vending_machine_preview(grid_pos: Vector2i):
	if vending_preview_manager != null and vending_preview_manager.has_method("update_vending_machine_preview"):
		vending_preview_manager.update_vending_machine_preview(grid_pos)

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


func update_inventory_window():
	if inventory_manager != null and inventory_manager.has_method("update_inventory_window"):
		inventory_manager.update_inventory_window()


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


func handle_verified_developer_command(command_text: String, request_id: String = "", server_message: String = ""):
	if command_manager != null and command_manager.has_method("execute_verified_developer_command"):
		command_manager.execute_verified_developer_command(command_text, request_id, server_message)
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


func handle_inventory_transaction_result(data: Dictionary):
	var transaction_data: Dictionary = data
	var progression_value = data.get("progression", {})
	if progression_value is Dictionary:
		var progression_data: Dictionary = progression_value
		if int(progression_data.get("levels_gained", 0)) > 0:
			show_level_up_progression(progression_data)
			transaction_data = data.duplicate(true)
			transaction_data["message"] = ""

	var handled := false

	if safe_ui != null and safe_ui.has_method("handle_inventory_transaction_result"):
		handled = bool(safe_ui.handle_inventory_transaction_result(transaction_data))

	if vending_ui != null and vending_ui.has_method("handle_inventory_transaction_result"):
		handled = handled or bool(vending_ui.handle_inventory_transaction_result(transaction_data))

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
		if message.strip_edges() != "":
			show_notification(message)

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
	if has_method("is_fish_monger_open") and is_fish_monger_open():
		return true
	if has_method("is_developer_panel_open") and is_developer_panel_open():
		return true

	return false


func is_movement_blocking_ui_open() -> bool:
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
	if has_method("is_fish_monger_open") and is_fish_monger_open():
		return true
	if has_method("is_developer_panel_open") and is_developer_panel_open():
		return true

	return false


func is_gameplay_hud_blocked() -> bool:
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
	if has_method("is_fish_monger_open") and is_fish_monger_open():
		return true
	if has_method("is_developer_panel_open") and is_developer_panel_open():
		return true

	return false


func is_movement_locked() -> bool:
	if not in_world:
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

func setup_fish_monger_ui():
	if gameplay_ui_manager != null and gameplay_ui_manager.has_method("setup_fish_monger_ui"):
		return gameplay_ui_manager.setup_fish_monger_ui()

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

	return block_type == "wooden_entrance"

func set_wooden_entrance_locked(grid_pos: Vector2i, locked: bool):
	if interaction_manager != null and interaction_manager.has_method("set_wooden_entrance_locked"):
		interaction_manager.set_wooden_entrance_locked(grid_pos, locked)

func toggle_wooden_entrance(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("toggle_wooden_entrance"):
		interaction_manager.toggle_wooden_entrance(grid_pos)

func update_wooden_entrance_visual(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("update_wooden_entrance_visual"):
		interaction_manager.update_wooden_entrance_visual(grid_pos)

func interact_with_grid(grid_pos: Vector2i):
	if interaction_manager != null and interaction_manager.has_method("interact_with_grid"):
		interaction_manager.interact_with_grid(grid_pos)

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




func set_gameplay_world_active(active: bool):
	if save_manager != null and save_manager.has_method("set_gameplay_world_active"):
		return save_manager.set_gameplay_world_active(active)

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
	if save_manager != null and save_manager.has_method("enter_world_by_name"):
		return save_manager.enter_world_by_name(raw_name)

	return



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
	if player_manager != null and player_manager.has_method("update_multiplayer_movement"):
		return player_manager.update_multiplayer_movement(delta)

	return

func flush_multiplayer_position(allow_join: bool = false, bypass_rate_limit: bool = false) -> bool:
	if player_manager != null and player_manager.has_method("flush_multiplayer_position"):
		return bool(player_manager.flush_multiplayer_position(allow_join, bypass_rate_limit))

	return false

func process_multiplayer_remote_visuals(delta: float):
	if player_manager != null and player_manager.has_method("process_multiplayer_remote_visuals"):
		return player_manager.process_multiplayer_remote_visuals(delta)

	return

func handle_network_existing_players(players_data):
	if player_manager != null and player_manager.has_method("handle_network_existing_players"):
		return player_manager.handle_network_existing_players(players_data)

	return

func handle_network_player_position(player_data: Dictionary):
	if player_manager != null and player_manager.has_method("handle_network_player_position"):
		return player_manager.handle_network_player_position(player_data)

	return

func handle_network_player_left(remote_id: String):
	if player_manager != null and player_manager.has_method("handle_network_player_left"):
		return player_manager.handle_network_player_left(remote_id)

	return

func show_remote_chat_bubble(remote_id: String, message: String, remote_name: String = ""):
	if player_manager != null and player_manager.has_method("show_remote_chat_bubble"):
		return player_manager.show_remote_chat_bubble(remote_id, message, remote_name)

	return

func clear_remote_players():
	if player_manager != null and player_manager.has_method("clear_remote_players"):
		return player_manager.clear_remote_players()

	return

func get_remote_player_at_screen_position(screen_pos: Vector2) -> Dictionary:
	if player_manager != null and player_manager.has_method("get_remote_player_at_screen_position"):
		return player_manager.get_remote_player_at_screen_position(screen_pos)

	return {}

func get_remote_player_in_interaction_range() -> Dictionary:
	if player_manager != null and player_manager.has_method("get_remote_player_in_interaction_range"):
		return player_manager.get_remote_player_in_interaction_range()

	return {}

func get_remote_player_profile_by_username(username: String) -> Dictionary:
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

	if save_manager.has_method("apply_network_player_state"):
		save_manager.apply_network_player_state(data)

# --- Multiplayer World State Sync v1 coordinator/apply helpers ---
func apply_network_world_state(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_world_state"):
		world_state_sync_manager.apply_network_world_state(data)


func apply_network_block_update(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_block_update"):
		world_state_sync_manager.apply_network_block_update(data)


func apply_network_world_interaction_update(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_world_interaction_update"):
		world_state_sync_manager.apply_network_world_interaction_update(data)


func apply_network_seed_update(data: Dictionary):
	if world_state_sync_manager != null and world_state_sync_manager.has_method("apply_network_seed_update"):
		world_state_sync_manager.apply_network_seed_update(data)
