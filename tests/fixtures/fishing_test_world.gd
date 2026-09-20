extends Node2D
## Local-only fixture. No account, network connection, or saved inventory is used.

const BLOCK_SIZE := 32
const FISHING_CAST_PIXEL_RANGE := 128.0
const INVALID_GRID_POS := Vector2i(-9999, -9999)
var in_world := true
var current_world_name := "FISHING_TEST"
var selected_item_type := "bamboo_fishing_rod"
var selected_item_category := "tool"
var equipped_tool := "bamboo_fishing_rod"
var fishing_active := false
var fishing_timer := 0.0
var fishing_lure_id := ""
var fishing_target_grid := INVALID_GRID_POS
var fishing_manager = null
var input_manager = null
var inventory_manager = null
var fish_monger_manager = null
var player: Node2D
var ui_layer: CanvasLayer
var blocks := {Vector2i(2, 1): {"type": "water"}}
var lure_inventory := {"worm_lure": 20}
var fish_inventory: Dictionary = {}
var fish_items: Array = ["pond_fish", "crystal_fish"]
var material_inventory: Dictionary = {}
var seed_inventory: Dictionary = {}
var item_database := {
	"pond_fish": {"name": "Pond Fish", "rarity": "common", "difficulty": 1, "sell_value": 3},
	"crystal_fish": {"name": "Crystal Fish", "rarity": "rare", "difficulty": 5, "sell_value": 16}
}
var fish_textures: Dictionary = {}
var material_textures: Dictionary = {}
var tool_textures: Dictionary = {}
var lure_textures: Dictionary = {}
var notifications: Array[String] = []
var saves := 0
var use_count := 0
var text_focused := false
var menu_open := false
var authoritative := false
var pointer_active := false
var pointer_position := Vector2.ZERO
var target := Vector2i(2, 1)

func _ready() -> void:
	player = Node2D.new()
	player.position = Vector2(32, 32)
	add_child(player)
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	player.add_child(visual)
	var hand := Node2D.new()
	hand.name = "HandItem"
	visual.add_child(hand)
	var tip := Marker2D.new()
	tip.name = "FishingLineStart"
	tip.position = Vector2(16, -12)
	hand.add_child(tip)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	fish_textures["pond_fish"] = load("res://Assets/items/fish/pond_fish_small.png")
	fish_textures["crystal_fish"] = load("res://Assets/items/fish/crystal_fish.png")

func _input(event: InputEvent) -> void:
	if input_manager != null:
		input_manager.handle_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if input_manager != null:
		input_manager.handle_unhandled_input(event)

func use_selected_item_at_mouse() -> void:
	use_count += 1
	fishing_manager.use_fishing_rod_at_mouse()

func get_mouse_grid_position() -> Vector2i: return target
func get_item_display_name(item: String, _category: String) -> String: return item.capitalize().replace("_", " ")
func get_inventory_icon_texture(item: String, _category: String): return fish_textures.get(item)
func should_use_server_authoritative_world_actions() -> bool: return authoritative
func show_notification(text: String) -> void: notifications.append(text)
func save_player_data() -> void: saves += 1
func update_all_ui() -> void: pass
func flush_multiplayer_position(_a: bool, _b: bool) -> void: pass
func refresh_ui_after_item_change(_a: String, _b: String) -> void: pass
func set_mobile_pointer_screen_position(pos: Vector2) -> void:
	pointer_active = true
	pointer_position = pos
func clear_mobile_pointer_screen_position() -> void: pointer_active = false
func is_gameplay_ui_at_point(_point: Vector2) -> bool: return false
func is_floating_hud_button_at_point(_point: Vector2) -> bool: return false
func is_movement_locked() -> bool: return false
func is_chat_input_focused() -> bool: return text_focused
func is_any_text_input_focused() -> bool: return text_focused
func is_sign_text_focused() -> bool: return false
func is_inventory_open() -> bool: return false
func is_player_menu_open() -> bool: return menu_open
func is_game_menu_open() -> bool: return false
func is_world_menu_open() -> bool: return false
func is_quest_board_open() -> bool: return false
func is_crafting_open() -> bool: return false
func is_furnace_open() -> bool: return false
func is_sign_open() -> bool: return false
func is_shop_open() -> bool: return false
func is_notification_panel_open() -> bool: return false
func is_world_lock_ui_open() -> bool: return false
func is_area_lock_ui_open() -> bool: return false
func is_door_editor_open() -> bool: return false
func is_trade_open() -> bool: return false
func is_vending_open() -> bool: return false
func is_safe_open() -> bool: return false
func is_mailbox_open() -> bool: return false
func is_bulletin_board_open() -> bool: return false
func is_leaderboard_open() -> bool: return false
func is_display_open() -> bool: return false
func is_fish_monger_open() -> bool: return false
func is_cctv_open() -> bool: return false
func is_oil_refinery_open() -> bool: return false
func is_battery_charger_open() -> bool: return false
