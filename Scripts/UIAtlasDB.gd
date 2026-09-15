extends RefCounted
class_name UIAtlasDB

## Name-based lookup over the shared UI atlas sheet (Assets/ui/UI_3.0.png,
## 32x32 grid). Any scene can pull a plain AtlasTexture (get_texture) or a
## ready-to-use StyleBoxTexture (get_stylebox, with 9-slice texture_margins
## for stretchable panels/buttons) by name instead of loading a dedicated
## PNG per element.
##
## Reuses AtlasTextureFactory (res://Scripts/atlas_texture_factory.gd) for
## the actual region-texture construction/caching, the same way
## ItemAtlasDB.gd builds per-item icons from a tile atlas.

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

const UI_ATLAS_TEXTURE_PATH := "res://Assets/ui/UI_3.0.png"
const TILE_SIZE := 32

# region name -> { cell: Vector2i, size_in_atlas: Vector2i (in tiles, default 1x1) }
# Coordinates are (col, row) on the 32px grid, matching the "Atlas Coords" /
# "Size in Atlas" convention used by res://tmp/UI.tres in the TileSet editor.
const REGIONS := {
	# Row 0 (y = 0)
	"outer_panel": {"cell": Vector2i(0, 0)},
	"inner_panel": {"cell": Vector2i(1, 0)},
	"pink_button": {"cell": Vector2i(2, 0)},
	"green_button": {"cell": Vector2i(3, 0)},
	"red_button": {"cell": Vector2i(4, 0)},
	"blue_button": {"cell": Vector2i(5, 0)},
	"scroll_handle": {"pixel_region": Rect2(206, 2, 4, 28)},
	"scroll_bar": {"pixel_region": Rect2(237, 0, 6, 32)},
	"punch_icon_button": {"cell": Vector2i(8, 0)},
	"wrench_icon_button": {"cell": Vector2i(9, 0)},
	"place_highlight": {"cell": Vector2i(10, 0)},
	"interact_highlight": {"cell": Vector2i(11, 0)},
	"close_button": {"cell": Vector2i(12, 0)},   # displays on top of red_button
	"accept_button": {"cell": Vector2i(13, 0)},  # displays on top of green_button

	# Row 1 (y = 32)
	"inv_slot_normal": {"cell": Vector2i(0, 1)},
	"inv_slot_material": {"cell": Vector2i(1, 1)},
	"inv_slot_clothes": {"cell": Vector2i(2, 1)},
	"inv_slot_empty": {"cell": Vector2i(3, 1)},
	"inv_slot_selected_1": {"cell": Vector2i(4, 1)},
	"inv_slot_selected_2": {"cell": Vector2i(5, 1)},
	"inv_slot_selected_3": {"cell": Vector2i(6, 1)},
	"item_equipped_overlay": {"cell": Vector2i(7, 1)},
	"inv_tab_all": {"cell": Vector2i(8, 1)},
	"inv_tab_blocks": {"cell": Vector2i(9, 1)},
	"inv_tab_seeds": {"cell": Vector2i(10, 1)},
	"inv_tab_clothes": {"cell": Vector2i(11, 1)},
	"inv_tab_material": {"cell": Vector2i(12, 1)},
	"inv_tab_tools": {"cell": Vector2i(13, 1)},
	"chat_send_button": {"cell": Vector2i(14, 1)},

	# Row 2 (y = 64)
	"input_field": {"cell": Vector2i(0, 2)},
	"toggle_off": {"cell": Vector2i(1, 2)},
	"toggle_on": {"cell": Vector2i(2, 2)},
	"notification_dot": {"cell": Vector2i(3, 2)},
	"menu_button": {"cell": Vector2i(4, 2)},
	"settings_button": {"cell": Vector2i(5, 2)},
	"inventory_button": {"cell": Vector2i(6, 2)},
	"chat_bubble_1": {"cell": Vector2i(7, 2)},
	"chat_bubble_2": {"cell": Vector2i(8, 2)},
	"chat_bubble_3": {"cell": Vector2i(9, 2)},
	"wrench_bubble_1": {"cell": Vector2i(10, 2)},
	"wrench_bubble_2": {"cell": Vector2i(11, 2)},
	"wrench_bubble_3": {"cell": Vector2i(12, 2)},
	"sleep_bubble_1": {"cell": Vector2i(13, 2)},
	"sleep_bubble_2": {"cell": Vector2i(14, 2)},
	"sleep_bubble_3": {"cell": Vector2i(15, 2)},
	"trash_bubble_1": {"cell": Vector2i(16, 2)},
	"trash_bubble_2": {"cell": Vector2i(17, 2)},
	"trash_bubble_3": {"cell": Vector2i(18, 2)},
	"trade_bubble_1": {"cell": Vector2i(19, 2)},
	"trade_bubble_2": {"cell": Vector2i(20, 2)},
	"trade_bubble_3": {"cell": Vector2i(21, 2)},
	"exit_bubble_1": {"cell": Vector2i(22, 2)},
	"exit_bubble_2": {"cell": Vector2i(23, 2)},
	"exit_bubble_3": {"cell": Vector2i(24, 2)},

	# Row 3 (y = 96)
	"fill_bar_progress": {"cell": Vector2i(0, 3)},
	"fill_bar_background": {"cell": Vector2i(1, 3)},
	"move_left_button": {"cell": Vector2i(4, 3)},
	"move_right_button": {"cell": Vector2i(5, 3)},
	"move_down_button": {"cell": Vector2i(6, 3)},
	"jump_button": {"cell": Vector2i(7, 3)},
	"punch_button": {"cell": Vector2i(8, 3)},
	"code_button": {"cell": Vector2i(9, 3)},
	"gavel_button": {"cell": Vector2i(10, 3)},
	"inventory_drag_handle": {"cell": Vector2i(11, 3), "size_in_atlas": Vector2i(2, 1)},
	"chat_drag_handle": {"cell": Vector2i(13, 3), "size_in_atlas": Vector2i(2, 1)},
	"inv_slot_purchase_overlay": {"cell": Vector2i(15, 3)},

	# Finished standalone icons. The promotional mockups below these rows
	# are reference art, deliberately excluded from the runtime catalogue.
	"gamepad_icon": {"cell": Vector2i(0, 4)},
	"mail_icon": {"cell": Vector2i(1, 4)},
	"help_icon": {"cell": Vector2i(2, 4)},
	"warning_icon": {"cell": Vector2i(3, 4)},
	"left_arrow": {"cell": Vector2i(4, 4)},
	"right_arrow": {"cell": Vector2i(5, 4)},
	"skull_icon": {"cell": Vector2i(6, 4)},
	"gems_icon": {"cell": Vector2i(7, 4)},
}

# Default 9-slice texture_margins (px) for get_stylebox(), keyed by region
# name. Anything not listed here defaults to no margins (a plain
# stretched/cropped region) - override per-call for anything that needs
# different stretching. Values were measured directly off the sheet's pixel
# borders: the outer/inner panels have a uniform 1px frame, and the
# pink/green/red/blue buttons share one template with a 2px side border, a
# 1px top edge, and a taller 5px bottom bevel.
const DEFAULT_MARGINS := {
	"scroll_handle": {"left": 1, "top": 2, "right": 1, "bottom": 2},
	"scroll_bar": {"left": 2, "top": 3, "right": 2, "bottom": 3},
	"inv_slot_normal": {"left": 2, "top": 2, "right": 2, "bottom": 2},
	"inv_slot_material": {"left": 2, "top": 2, "right": 2, "bottom": 2},
	"inv_slot_clothes": {"left": 2, "top": 2, "right": 2, "bottom": 2},
	"inv_slot_empty": {"left": 2, "top": 2, "right": 2, "bottom": 2},
	"input_field": {"left": 3, "top": 3, "right": 3, "bottom": 3},
	"outer_panel": {"left": 1, "top": 1, "right": 1, "bottom": 1},
	"inner_panel": {"left": 1, "top": 1, "right": 1, "bottom": 1},
	"pink_button": {"left": 2, "top": 1, "right": 2, "bottom": 5},
	"green_button": {"left": 2, "top": 1, "right": 2, "bottom": 5},
	"red_button": {"left": 2, "top": 1, "right": 2, "bottom": 5},
	"blue_button": {"left": 2, "top": 1, "right": 2, "bottom": 5},
}

# Convenience frame order for the 3-frame "selected" inventory slot
# animation, which cycles 1-2-3-2-1.
const INV_SLOT_SELECTED_ANIMATION := [
	"inv_slot_selected_1", "inv_slot_selected_2", "inv_slot_selected_3",
	"inv_slot_selected_2", "inv_slot_selected_1",
]

static var _texture_cache: Dictionary = {}
static var _stylebox_cache: Dictionary = {}

# Both inventory and hotbar use the same frame order and rarity treatment.
const SLOT_REGIONS := {
	"slot_normal.png": "inv_slot_normal", "slot_common.png": "inv_slot_normal",
	"slot_uncommon.png": "inv_slot_normal", "slot_rare.png": "inv_slot_normal",
	"slot_epic.png": "inv_slot_normal", "slot_legendary.png": "inv_slot_normal",
	"material_slot.png": "inv_slot_material", "clothes_slot.png": "inv_slot_clothes",
	"empty_slot.png": "inv_slot_empty", "slot_upgrade.png": "inv_slot_empty",
	"slot_selected.png": "inv_slot_selected_1",
}

static func slot_tint(file_name: String) -> Color:
	match file_name:
		"slot_uncommon.png": return Color(0.45, 1.0, 0.55)
		"slot_rare.png": return Color(0.45, 0.7, 1.0)
		"slot_epic.png": return Color(0.85, 0.5, 1.0)
		"slot_legendary.png": return Color(1.0, 0.8, 0.3)
	return Color.WHITE


static func has_region(region_name: String) -> bool:
	return REGIONS.has(region_name)


static func get_region_rect(region_name: String) -> Rect2:
	if not REGIONS.has(region_name):
		push_warning("UIAtlasDB: unknown UI atlas region '%s'" % region_name)
		return Rect2()

	var spec: Dictionary = REGIONS[region_name]
	if spec.has("pixel_region"):
		return spec["pixel_region"]
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var size_in_atlas: Vector2i = spec.get("size_in_atlas", Vector2i.ONE)

	return Rect2(
		float(cell.x * TILE_SIZE),
		float(cell.y * TILE_SIZE),
		float(size_in_atlas.x * TILE_SIZE),
		float(size_in_atlas.y * TILE_SIZE)
	)


## Plain cropped AtlasTexture for a named region (e.g. TextureRect.texture,
## an icon, or a TextureButton state). Cached by name.
static func get_texture(region_name: String) -> Texture2D:
	if _texture_cache.has(region_name):
		return _texture_cache[region_name]

	if not REGIONS.has(region_name):
		push_warning("UIAtlasDB: unknown UI atlas region '%s'" % region_name)
		return null

	var texture: Texture2D = load("res://Assets/ui/atlas/textures/%s.tres" % region_name)
	_texture_cache[region_name] = texture
	return texture


## Ready-to-use StyleBoxTexture for a named region, with region_rect set to
## crop the atlas cell and texture_margin_* set for 9-slice stretching so the
## cell can be stretched to whatever size a given panel/button needs to be.
## Pass margin_overrides (any of "left"/"top"/"right"/"bottom") to override
## DEFAULT_MARGINS for one call; results are cached per (name, margins) pair,
## matching how ShopScene.tscn already shares one StyleBoxTexture resource
## across many controls.
static func get_stylebox(region_name: String, margin_overrides: Dictionary = {}) -> StyleBoxTexture:
	if not REGIONS.has(region_name):
		push_warning("UIAtlasDB: unknown UI atlas region '%s'" % region_name)
		return null

	var margins: Dictionary = (DEFAULT_MARGINS.get(region_name, {}) as Dictionary).duplicate()
	for key in margin_overrides.keys():
		margins[key] = margin_overrides[key]

	var cache_key := "%s|%s" % [region_name, str(margins)]
	if _stylebox_cache.has(cache_key):
		return _stylebox_cache[cache_key]

	var template: StyleBoxTexture = load("res://Assets/ui/atlas/styles/%s.tres" % region_name)
	var style := template.duplicate() as StyleBoxTexture
	style.texture_margin_left = float(margins.get("left", 0))
	style.texture_margin_top = float(margins.get("top", 0))
	style.texture_margin_right = float(margins.get("right", 0))
	style.texture_margin_bottom = float(margins.get("bottom", 0))

	_stylebox_cache[cache_key] = style
	return style
