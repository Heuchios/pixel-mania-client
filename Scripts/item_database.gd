extends Node

# PixelMania Item Database Organization v1
#
# This file controls item/block/seed/tool/equipment data.
# Important content rules:
# - Blocks, doors, signs, and platforms use seed splicing unless their sheet row is red (crafting).
# - Crafting Station should craft tools, stations, equipment, and rare/special items.
# - Furnace should output materials only.
# - Shop should sell stations, special utility items, and selected equipment.
#
# Safe adding workflow:
# 1. Add sprites.
# 2. Add item entry here.
# 3. Add splice/crafting/furnace/shop entry if needed.
# 4. Test with /give and save/load.
#
# Texture fields can be either a normal path string or an atlas spec:
# "texture": {"atlas": "res://Assets/atlases/items.png", "region": [0, 0, 32, 32]}
# Grid atlas specs are also supported:
# "texture": {"atlas": "res://Assets/atlases/items.png", "cell_size": [32, 32], "cell": [2, 1]}
# Or, for row-major sheets:
# "texture": {"atlas": "res://Assets/atlases/items.png", "cell_size": [32, 32], "index": 5, "columns": 8}

const CATEGORY_BLOCK = "block"
const CATEGORY_SEED = "seed"
const CATEGORY_TOOL = "tool"
const CATEGORY_BACK = "back"
const CATEGORY_HAT = "hat"
const CATEGORY_HAIR = "hair"
const CATEGORY_EYEWEAR = "eyewear"
const CATEGORY_BEARD = "beard"
const CATEGORY_SHIRT = "shirt"
const CATEGORY_PANTS = "pants"
const CATEGORY_SHOES = "shoes"
const CATEGORY_RIDE = "ride"
const CATEGORY_MATERIAL = "material"
const CATEGORY_LURE = "lure"
const CATEGORY_FISH = "fish"
const CATEGORY_CURRENCY = "currency"

const TIER_1_SPLICE_BALANCE = {
	"pile_of_sand": {
		"recipe": ["sand_seed", "stone_seed"],
		"grow_time": 24.0,
		"block_drop_chance": 0.85,
		"seed_drop_chance": 0.55,
		"tree_block_range": [4, 7],
		"tree_seed_range": [2, 4]
	},
	"glass": {
		"recipe": ["glass_panel_seed", "stone_seed"],
		"grow_time": 28.0,
		"block_drop_chance": 0.75,
		"seed_drop_chance": 0.45,
		"tree_block_range": [4, 7],
		"tree_seed_range": [2, 4]
	},
	"wood_plank": {
		"recipe": ["wood_seed", "stone_seed"],
		"grow_time": 32.0,
		"block_drop_chance": 0.80,
		"seed_drop_chance": 0.45,
		"tree_block_range": [4, 7],
		"tree_seed_range": [2, 4]
	},
	"hanging_vine": {
		"recipe": ["grass_seed", "leaf_seed"],
		"grow_time": 36.0,
		"block_drop_chance": 0.80,
		"seed_drop_chance": 0.45,
		"tree_block_range": [4, 7],
		"tree_seed_range": [2, 4]
	},
	"rose": {
		"recipe": ["dirt_seed", "leaf_seed"],
		"grow_time": 40.0,
		"block_drop_chance": 0.75,
		"seed_drop_chance": 0.40,
		"tree_block_range": [4, 7],
		"tree_seed_range": [2, 4]
	},
	"sunflower": {
		"recipe": ["sand_seed", "leaf_seed"],
		"grow_time": 40.0,
		"block_drop_chance": 0.75,
		"seed_drop_chance": 0.40,
		"tree_block_range": [4, 7],
		"tree_seed_range": [2, 4]
	},
	"sun_flower": {
		"recipe": ["grass_seed", "sand_seed"],
		"grow_time": 46.0,
		"block_drop_chance": 0.75,
		"seed_drop_chance": 0.38,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"apple": {
		"recipe": ["wood_seed", "glass_seed"],
		"grow_time": 52.0,
		"block_drop_chance": 0.70,
		"seed_drop_chance": 0.35,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"climbing_vine": {
		"recipe": ["wooden_chair_seed", "green_wallpaper_seed"],
		"grow_time": 58.0,
		"block_drop_chance": 0.70,
		"seed_drop_chance": 0.35,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"vines_2": {
		"recipe": ["vines_seed", "leaf_seed"],
		"grow_time": 64.0,
		"block_drop_chance": 0.68,
		"seed_drop_chance": 0.32,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"poppy": {
		"recipe": ["rose_seed", "tulip_seed"],
		"grow_time": 70.0,
		"block_drop_chance": 0.68,
		"seed_drop_chance": 0.30,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"lily": {
		"recipe": ["glass_seed", "grass_seed"],
		"grow_time": 78.0,
		"block_drop_chance": 0.65,
		"seed_drop_chance": 0.28,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"sand_castle": {
		"recipe": ["sand_seed", "wood_plank_seed"],
		"grow_time": 86.0,
		"block_drop_chance": 0.65,
		"seed_drop_chance": 0.25,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"wood_platform": {
		"recipe": ["wooden_block_seed", "vines_2_seed"],
		"grow_time": 95.0,
		"block_drop_chance": 0.65,
		"seed_drop_chance": 0.25,
		"tree_block_range": [3, 6],
		"tree_seed_range": [1, 4]
	},
	"sign": {
		"recipe": ["wooden_block_seed", "mushroom_seed"],
		"grow_time": 105.0,
		"block_drop_chance": 0.62,
		"seed_drop_chance": 0.22,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_entrance": {
		"recipe": ["wooden_door_seed", "wood_platform_seed"],
		"grow_time": 115.0,
		"block_drop_chance": 0.60,
		"seed_drop_chance": 0.20,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_block": {
		"recipe": ["wood_seed", "dirt_seed"],
		"grow_time": 125.0,
		"block_drop_chance": 0.60,
		"seed_drop_chance": 0.20,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_wallpaper": {
		"recipe": ["wooden_block_seed", "cave_background_seed"],
		"grow_time": 135.0,
		"block_drop_chance": 0.58,
		"seed_drop_chance": 0.18,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_fence": {
		"recipe": ["wooden_block_seed", "hay_seed"],
		"grow_time": 150.0,
		"block_drop_chance": 0.55,
		"seed_drop_chance": 0.16,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_ladder": {
		"recipe": ["wooden_block_seed", "wood_platform_seed"],
		"grow_time": 160.0,
		"block_drop_chance": 0.55,
		"seed_drop_chance": 0.16,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_door": {
		"recipe": ["wooden_block_seed", "dirt_seed"],
		"grow_time": 175.0,
		"block_drop_chance": 0.52,
		"seed_drop_chance": 0.14,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"wooden_window": {
		"recipe": ["wooden_block_seed", "glass_panel_seed"],
		"grow_time": 190.0,
		"block_drop_chance": 0.50,
		"seed_drop_chance": 0.12,
		"tree_block_range": [2, 5],
		"tree_seed_range": [0, 4]
	},
	"mushroom": {
		"recipe": ["leaf_seed", "wood_seed"],
		"grow_time": 205.0,
		"block_drop_chance": 0.48,
		"seed_drop_chance": 0.10,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4]
	},
	"stone_brick": {
		"recipe": ["stone_seed", "dirt_seed"],
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"glass_panel": {
		"recipe": ["sand_seed", "lava_seed"],
		"grow_time": 250.0,
		"block_drop_chance": 0.42,
		"seed_drop_chance": 0.07,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4]
	},
	"rainbow_block": {
		"recipe": ["dark_purple_block_seed", "red_block_seed"],
		"grow_time": 300.0,
		"block_drop_chance": 0.35,
		"seed_drop_chance": 0.05,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4]
	},
	"red_brick": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"green_brick": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"green_moss_brick": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"red_brick_wall": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"stone_brick_wall": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"green_brick_wall": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"green_moss_brick_wall": {
		"grow_time": 225.0,
		"block_drop_chance": 0.45,
		"seed_drop_chance": 0.08,
		"tree_block_range": [1, 4],
		"tree_seed_range": [0, 4],
		"break_gem_range": [1, 5]
	},
	"gold_block": {
		"grow_time": 600.0,
		"block_drop_chance": 0.20,
		"seed_drop_chance": 0.04,
		"break_block_range": [0, 3],
		"break_seed_range": [0, 1],
		"tree_block_range": [0, 3],
		"tree_seed_range": [0, 1],
		"break_gem_range": [20, 60]
	},
	"emerald_block": {
		"grow_time": 600.0,
		"block_drop_chance": 0.20,
		"seed_drop_chance": 0.04,
		"break_block_range": [0, 3],
		"break_seed_range": [0, 1],
		"tree_block_range": [0, 3],
		"tree_seed_range": [0, 1],
		"break_gem_range": [20, 60]
	},
	"ruby_block": {
		"grow_time": 600.0,
		"block_drop_chance": 0.20,
		"seed_drop_chance": 0.04,
		"break_block_range": [0, 3],
		"break_seed_range": [0, 1],
		"tree_block_range": [0, 3],
		"tree_seed_range": [0, 1],
		"break_gem_range": [20, 60]
	},
	"diamond_block": {
		"grow_time": 600.0,
		"block_drop_chance": 0.20,
		"seed_drop_chance": 0.04,
		"break_block_range": [0, 3],
		"break_seed_range": [0, 1],
		"tree_block_range": [0, 3],
		"tree_seed_range": [0, 1],
		"break_gem_range": [20, 60]
	},
	"amethyst_block": {
		"grow_time": 600.0,
		"block_drop_chance": 0.20,
		"seed_drop_chance": 0.04,
		"break_block_range": [0, 3],
		"break_seed_range": [0, 1],
		"tree_block_range": [0, 3],
		"tree_seed_range": [0, 1],
		"break_gem_range": [20, 60]
	}
}

const BASIC_ITEMS_PACK_REWARDS = ["messy_brown_hair", "blue_baseball_cap", "green_baseball_cap", "red_baseball_cap", "basic_blue_shirt", "basic_red_shirt", "basic_white_shirt", "basic_black_shirt", "basic_heart_shirt", "basic_gray_shirt", "basic_maroon_shirt", "black_suit", "blue_suit", "basic_black_pants", "basic_light_gray_pants", "basic_navy_pants", "basic_brown_pants", "basic_green_pants", "basic_pink_pants", "basic_brown_shoes", "basic_black_shoes", "basic_red_shoes", "basic_blue_shoes", "basic_yellow_shoes"]

const HAIR_PACK_REWARDS = [
	{"item_id": "black_afro", "weight": 999},
	{"item_id": "blonde_afro", "weight": 999},
	{"item_id": "brown_afro", "weight": 999},
	{"item_id": "pink_afro", "weight": 999},
	{"item_id": "red_afro", "weight": 999},
	{"item_id": "short_black_hair", "weight": 999},
	{"item_id": "short_blonde_hair", "weight": 999},
	{"item_id": "short_bron_hair", "weight": 999},
	{"item_id": "short_pink_hair", "weight": 999},
	{"item_id": "short_red_hair", "weight": 999},
	{"item_id": "long_black_hair", "weight": 999},
	{"item_id": "long_blonde_hair", "weight": 999},
	{"item_id": "long_grey_hair", "weight": 999},
	{"item_id": "long_pink_hair", "weight": 999},
	{"item_id": "long_red_hair", "weight": 999},
	{"item_id": "black_slick_hair", "weight": 999},
	{"item_id": "black_combed_hair", "weight": 999},
	{"item_id": "frosty_hair", "weight": 999},
	{"item_id": "flaming_hair", "weight": 999},
	{"item_id": "old_men_hair", "weight": 999},
	{"item_id": "brown_fringe", "weight": 999},
	{"item_id": "brown_combed_hair", "weight": 999},
	{"item_id": "blonde_hair", "weight": 999},
	{"item_id": "brunette_hair", "weight": 999},
	{"item_id": "crazy_hair", "weight": 999},
	{"item_id": "baby_hair", "weight": 15}
]

const PRESTIGE_COLOURED_BLOCK_PACK_REWARDS = ["ps_blue_block", "ps_green_block", "ps_purple_block", "ps_red_block", "ps_yellow_block"]

const ITEMS = {
"pink_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 90,
	"display_name": "Pink Wall Seed",
	"grows_into": "pink_wallpaper"
},
"blue_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 88,
	"display_name": "Blue Wall Seed",
	"grows_into": "blue_wallpaper"
},
"yellow_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 85,
	"display_name": "Yellow Wall Seed",
	"grows_into": "yellow_wallpaper"
},
"black_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 82,
	"display_name": "Black Wall Seed",
	"grows_into": "black_wallpaper"
},
"purple_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 89,
	"display_name": "Purple Wall Seed",
	"grows_into": "purple_wallpaper"
},
"aqua_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 87,
	"display_name": "Aqua Wall Seed",
	"grows_into": "aqua_wallpaper"
},
"orange_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 84,
	"display_name": "Orange Wall Seed",
	"grows_into": "orange_wallpaper"
},
"grey_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 81,
	"display_name": "Gray Wall Seed",
	"grows_into": "grey_wallpaper"
},
"brown_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 91,
	"display_name": "Brown Wall Seed",
	"grows_into": "brown_wallpaper"
},
"green_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 86,
	"display_name": "Green Wall Seed",
	"grows_into": "green_wallpaper"
},
"red_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 83,
	"display_name": "Red Wall Seed",
	"grows_into": "red_wallpaper"
},
"white_wallpaper_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 80,
	"display_name": "White Wall Seed",
	"grows_into": "white_wallpaper"
},
"shifty_block_seed": {
	"category": "seed",
	"rarity": "rare",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 431,
	"display_name": "RGB Block Seed",
	"grows_into": "shifty_block"
},
"green_brick_wall_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 420,
	"display_name": "Grimstone Wall Seed",
	"grows_into": "green_brick_wall"
},
"green_brick_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 416,
	"display_name": "Grimstone Seed",
	"grows_into": "green_brick"
},
"stone_brick_wall_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 419,
	"display_name": "Stone Brick Wall Seed",
	"grows_into": "stone_brick_wall"
},
"red_brick_wall_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 418,
	"display_name": "Red Brick Wall Seed",
	"grows_into": "red_brick_wall"
},
"red_brick_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 415,
	"display_name": "Red Brick Seed",
	"grows_into": "red_brick"
},
"portcullis_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Portcullis Seed",
	"grows_into": "portcullis"
},
"portcullis": {
	"category": "block",
	"display_name": "Portcullis",
	"seed": "portcullis_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "portcullis",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "portcullis_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "portcullis",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "portcullis_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [17, 4],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [17, 4],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(17, 4),
	"atlas_source_id": 0,
	"source_id": 0,
	"animated": true,
	"tileset_animation": false,
	"animation_frame_seconds": 0.22,
	"animation_atlas_coords": [
		[17, 4],
		[18, 4],
		[19, 4]
	],
	"animation_frames": [
		{
			"atlas": "res://image.png",
			"cell": [17, 4],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [18, 4],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [19, 4],
			"cell_size": [32, 32]
		}
	],
	"authored_drop_rules": true
},
"wagon_wheel_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Wagon Wheel Seed",
	"grows_into": "wagon_wheel"
},
"wagon_wheel": {
	"category": "block",
	"display_name": "Wagon Wheel",
	"seed": "wagon_wheel_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wagon_wheel",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "wagon_wheel_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wagon_wheel",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "wagon_wheel_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [16, 4],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [16, 4],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(16, 4),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"sturdy_box_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Sturdy Box Seed",
	"grows_into": "sturdy_box"
},
"sturdy_box": {
	"category": "block",
	"display_name": "Sturdy Box",
	"seed": "sturdy_box_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "sturdy_box",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "sturdy_box_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "sturdy_box",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "sturdy_box_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [20, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [20, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(20, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dungeon_door_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Dungeon Door Seed",
	"grows_into": "dungeon_door"
},
"dungeon_door": {
	"category": "block",
	"display_name": "Dungeon Door",
	"seed": "dungeon_door_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dungeon_door",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "dungeon_door_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dungeon_door",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "dungeon_door_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [19, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [19, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(19, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"door_block": true,
	"interact_rules": true,
	"authored_drop_rules": true
},
"campfire_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Campfire Seed",
	"grows_into": "campfire"
},
"campfire": {
	"category": "block",
	"display_name": "Campfire",
	"seed": "campfire_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "campfire",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "campfire_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "campfire",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "campfire_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [16, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [16, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(16, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"animated": true,
	"tileset_animation": false,
	"animation_frame_seconds": 0.22,
	"animation_atlas_coords": [
		[16, 3],
		[17, 3],
		[18, 3]
	],
	"animation_frames": [
		{
			"atlas": "res://image.png",
			"cell": [16, 3],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [17, 3],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [18, 3],
			"cell_size": [32, 32]
		}
	],
	"authored_drop_rules": true
},
"lantern_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Lantern Seed",
	"grows_into": "lantern"
},
"lantern": {
	"category": "block",
	"display_name": "Lantern",
	"seed": "lantern_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "lantern",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "lantern_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "lantern",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "lantern_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [18, 2],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [18, 2],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(18, 2),
	"atlas_source_id": 0,
	"source_id": 0,
	"animated": true,
	"tileset_animation": false,
	"animation_frame_seconds": 0.22,
	"animation_atlas_coords": [
		[18, 2],
		[19, 2],
		[20, 2]
	],
	"animation_frames": [
		{
			"atlas": "res://image.png",
			"cell": [18, 2],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [19, 2],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [20, 2],
			"cell_size": [32, 32]
		}
	],
	"authored_drop_rules": true
},
"wooden_box_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Wooden Box Seed",
	"grows_into": "wooden_box"
},
"wooden_box": {
	"category": "block",
	"display_name": "Wooden Box",
	"seed": "wooden_box_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wooden_box",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "wooden_box_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wooden_box",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "wooden_box_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [17, 2],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [17, 2],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(17, 2),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"wooden_barrel_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Wooden Barrel Seed",
	"grows_into": "wooden_barrel"
},
"wooden_barrel": {
	"category": "block",
	"display_name": "Wooden Barrel",
	"seed": "wooden_barrel_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wooden_barrel",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "wooden_barrel_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wooden_barrel",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "wooden_barrel_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [16, 2],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [16, 2],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(16, 2),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"snow_big_rock_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Snow Big Rock Seed",
	"grows_into": "snow_big_rock"
},
"snow_big_rock": {
	"category": "block",
	"display_name": "Snow Big Rock",
	"seed": "snow_big_rock_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "snow_big_rock",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "snow_big_rock_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "snow_big_rock",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "snow_big_rock_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [15, 5],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [15, 5],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(15, 5),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"snow_tiny_rock_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Snow Tiny Rock Seed",
	"grows_into": "snow_tiny_rock"
},
"snow_tiny_rock": {
	"category": "block",
	"display_name": "Snow Tiny Rock",
	"seed": "snow_tiny_rock_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "snow_tiny_rock",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "snow_tiny_rock_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "snow_tiny_rock",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "snow_tiny_rock_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [14, 5],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [14, 5],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(14, 5),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"big_rock_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Big Rock Seed",
	"grows_into": "big_rock"
},
"big_rock": {
	"category": "block",
	"display_name": "Big Rock",
	"seed": "big_rock_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "big_rock",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "big_rock_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "big_rock",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "big_rock_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(3, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"tiny_rock_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Tiny Rock Seed",
	"grows_into": "tiny_rock"
},
"tiny_rock": {
	"category": "block",
	"display_name": "Tiny Rock",
	"seed": "tiny_rock_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "tiny_rock",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "tiny_rock_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "tiny_rock",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "tiny_rock_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(2, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pile_of_sand_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 25,
	"display_name": "Pile of Sand Seed",
	"grows_into": "pile_of_sand"
},
"sand_castle_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 24,
	"display_name": "Sand Castle Seed",
	"grows_into": "sand_castle"
},
"wooden_crappy_sign_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 54,
	"display_name": "Mysterious Sign Seed",
	"grows_into": "wooden_crappy_sign"
},
"vines_2_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 26,
	"display_name": "Big Vines Seed",
	"grows_into": "vines_2"
},
"autumn_leaf_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Leaf Block (Autumn Event) Seed",
	"grows_into": "autumn_leaf"
},
"autumn_leaf": {
	"category": "block",
	"display_name": "Leaf Block (Autumn Event)",
	"seed": "autumn_leaf_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "autumn_leaf",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "autumn_leaf_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "autumn_leaf",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "autumn_leaf_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [5, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [5, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(5, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"spring_leaf_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Leaf Block (Spring Event) Seed",
	"grows_into": "spring_leaf"
},
"spring_leaf": {
	"category": "block",
	"display_name": "Leaf Block (Spring Event)",
	"seed": "spring_leaf_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "spring_leaf",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "spring_leaf_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "spring_leaf",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "spring_leaf_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [4, 3],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [4, 3],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(4, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"obsidian_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Obsidian Seed",
	"grows_into": "obsidian"
},
"obsidian": {
	"category": "block",
	"display_name": "Obsidian",
	"seed": "obsidian_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "obsidian",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "obsidian_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "obsidian",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "obsidian_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 2],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 2],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(2, 2),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"bush_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Bush Seed",
	"grows_into": "bush"
},
"bush": {
	"category": "block",
	"display_name": "Bush",
	"seed": "bush_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "bush",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "bush_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "bush",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "bush_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [6, 4],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [6, 4],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(6, 4),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"ruby_block_seed": {
	"category": "seed",
	"rarity": "epic",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 424,
	"display_name": "Ruby Block Seed",
	"grows_into": "ruby_block"
},
"empty_jar_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Empty Jar Seed",
	"grows_into": "empty_jar"
},
"empty_jar": {
	"category": "block",
	"display_name": "Empty Jar",
	"seed": "empty_jar_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "empty_jar",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "empty_jar_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "empty_jar",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "empty_jar_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 21],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 21],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(1, 21),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"green_moss_brick_wall_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 421,
	"display_name": "Green Moss Wall Seed",
	"grows_into": "green_moss_brick_wall"
},
"green_moss_brick_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 417,
	"display_name": "Green Moss Brick Seed",
	"grows_into": "green_moss_brick"
},
"pearl_clam_open_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Pearl Clam Open Seed",
	"grows_into": "pearl_clam_open"
},
"pearl_clam_open": {
	"category": "block",
	"display_name": "Pearl Clam Open",
	"seed": "pearl_clam_open_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pearl_clam_open",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "pearl_clam_open_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pearl_clam_open",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "pearl_clam_open_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [11, 23],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [11, 23],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(11, 23),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pearl_clam_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Pearl Clam Seed",
	"grows_into": "pearl_clam"
},
"pearl_clam": {
	"category": "block",
	"display_name": "Pearl Clam",
	"seed": "pearl_clam_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pearl_clam",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "pearl_clam_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pearl_clam",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "pearl_clam_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [10, 23],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [10, 23],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(10, 23),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"coral_block_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Coral Seed",
	"grows_into": "coral_block"
},
"coral_block": {
	"category": "block",
	"display_name": "Coral",
	"seed": "coral_block_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "coral_block",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "coral_block_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "coral_block",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "coral_block_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [9, 23],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [9, 23],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(9, 23),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"seaweed_block_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Seaweed Seed",
	"grows_into": "seaweed_block"
},
"seaweed_block": {
	"category": "block",
	"display_name": "Seaweed",
	"seed": "seaweed_block_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "seaweed_block",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "seaweed_block_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "seaweed_block",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "seaweed_block_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [6, 23],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [6, 23],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(6, 23),
	"atlas_source_id": 0,
	"source_id": 0,
	"animated": true,
	"tileset_animation": false,
	"animation_frame_seconds": 0.22,
	"animation_atlas_coords": [
		[6, 23],
		[7, 23],
		[8, 23]
	],
	"animation_frames": [
		{
			"atlas": "res://image.png",
			"cell": [6, 23],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [7, 23],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [8, 23],
			"cell_size": [32, 32]
		}
	],
	"authored_drop_rules": true
},
"hay_bales_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Hay Bales Seed",
	"grows_into": "hay_bales"
},
"hay_bales": {
	"category": "block",
	"display_name": "Hay Bales",
	"seed": "hay_bales_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "hay_bales",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "hay_bales_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "hay_bales",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "hay_bales_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 23],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 23],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(3, 23),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"rusty_copper_block_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Rusty Copper Block Seed",
	"grows_into": "rusty_copper_block"
},
"rusty_copper_block": {
	"category": "block",
	"display_name": "Rusty Copper Block",
	"seed": "rusty_copper_block_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "rusty_copper_block",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "rusty_copper_block_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "rusty_copper_block",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "rusty_copper_block_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [22, 6],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [22, 6],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(22, 6),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"copper_block_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Copper Block Seed",
	"grows_into": "copper_block"
},
"copper_block": {
	"category": "block",
	"display_name": "Copper Block",
	"seed": "copper_block_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "copper_block",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "copper_block_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "copper_block",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "copper_block_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [21, 6],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [21, 6],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(21, 6),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"amethyst_block_seed": {
	"category": "seed",
	"rarity": "epic",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 426,
	"display_name": "Gem Block Seed",
	"grows_into": "amethyst_block"
},
"diamond_block_seed": {
	"category": "seed",
	"rarity": "epic",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 425,
	"display_name": "Diamond Block Seed",
	"grows_into": "diamond_block"
},
"emerald_block_seed": {
	"category": "seed",
	"rarity": "epic",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 423,
	"display_name": "Emerald Block Seed",
	"grows_into": "emerald_block"
},
"gold_block_seed": {
	"category": "seed",
	"rarity": "epic",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 422,
	"display_name": "Golden Block Seed",
	"grows_into": "gold_block"
},
"oil_refinery_seed": {
	"category": "seed",
	"rarity": "legendary",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 416,
	"display_name": "Oil Refinery Seed",
	"grows_into": "oil_refinery"
},
"sashimi_table_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Sashimi Table Seed",
	"grows_into": "sashimi_table"
},
"sashimi_table": {
	"category": "block",
	"display_name": "Sashimi Table",
	"seed": "sashimi_table_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "sashimi_table",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "sashimi_table_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "sashimi_table",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "sashimi_table_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [20, 15],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [20, 15],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(20, 15),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"quest_board_seed": {
	"category": "seed",
	"rarity": "common",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 999,
	"display_name": "Quest Board Seed",
	"grows_into": "quest_board"
},
"quest_board": {
	"category": "block",
	"display_name": "Quest Board",
	"seed": "quest_board_seed",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "quest_board",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "quest_board_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "quest_board",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "quest_board_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"region": [576, 480, 64, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"region": [576, 480, 64, 32]
	},
	"atlas_coords": Vector2i(18, 15),
	"atlas_source_id": 0,
	"source_id": 0,
	"visual_size": [64, 32],
	"visual_offset": [16, 0],
	"authored_drop_rules": true
},
"recycle_bin": {
	"category": "block",
	"display_name": "Recycle Bin",
	"seed": "",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": true,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": []
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": []
	},
	"block_health": 3,
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": true,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [17, 14],
		"cell_size": [32, 32]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [17, 14],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(17, 14),
	"atlas_source_id": 0,
	"source_id": 0,
	"animated": true,
	"tileset_animation": false,
	"animation_frame_seconds": 0.22,
	"animation_atlas_coords": [
		[17, 14],
		[18, 14]
	],
	"animation_frames": [
		{
			"atlas": "res://image.png",
			"cell": [17, 14],
			"cell_size": [32, 32]
		},
		{
			"atlas": "res://image.png",
			"cell": [18, 14],
			"cell_size": [32, 32]
		}
	],
	"server_triggered_animation": true,
	"animation_trigger": "on_recycle",
	"break_return_item_id": "recycle_bin",
	"authored_drop_rules": true
},
"big_spike_seed": {
	"category": "seed",
	"rarity": "rare",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 300,
	"display_name": "Dark Spike Seed",
	"grows_into": "big_spike"
},
"spike_seed": {
	"category": "seed",
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 301,
	"display_name": "Hanging Spike Seed",
	"grows_into": "spike"
},
"saw_blade_seed": {
	"category": "seed",
	"rarity": "rare",
	"texture": "res://Assets/seeds/seed_box.png",
	"seed_box_icon": true,
	"order": 304,
	"display_name": "Spike Seed",
	"grows_into": "saw_blade"
},

	# ============================================================
	# BASIC NATURAL BLOCKS
	# ============================================================
"dirt": {
		"category": "block",
		"display_name": "Dirt",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [0, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 0], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 0),
		"dirt_lower_atlas_variants": [Vector2i(0, 1), Vector2i(1, 1)],
		"dirt_lower_atlas_weights": [95, 5],
		"seed": "dirt_seed",
		"order": 0
	},
"grass": {
		"category": "block",
		"display_name": "Grass",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [0, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 4),
		"animated": true,
		"animation_frames": [
			{"atlas": "res://image.png", "cell": [0, 4], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [1, 4], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [2, 4], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [1, 4], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [0, 4], "cell_size": [32, 32]}
		],
		"animation_atlas_coords": [
			Vector2i(0, 4),
			Vector2i(1, 4),
			Vector2i(2, 4),
			Vector2i(1, 4),
			Vector2i(0, 4)
		],
		"animation_frame_seconds": 0.24,
		"seed": "grass_seed",
		"Collidable": false,
		"no_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "grass", "item_category": "block", "amount": 1, "chance": 0.9},
				{"item_id": "grass_seed", "item_category": "seed", "amount": 1, "chance": 0.8},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 1]},
				{"item_id": "grain", "item_category": "material", "amount": 1, "chance": 0.3}
			]
		},
		"order": 1
	},
"hay": {
		"category": "block",
		"display_name": "Dried Hay",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://image.png",
		"atlas_item_id": 22,
		"atlas_coords": Vector2i(0, 23),
		"animated": true,
		"animation_frames": [
			Vector2i(0, 23),
			Vector2i(1, 23),
			Vector2i(2, 23),
			Vector2i(1, 23),
			Vector2i(0, 23)
		],
		"animation_atlas_coords": [
			Vector2i(0, 23),
			Vector2i(1, 23),
			Vector2i(2, 23),
			Vector2i(1, 23),
			Vector2i(0, 23)
		],
		"animation_frame_seconds": 0.24,
		"tileset_animation": false,
		"seed": "hay_seed",
		"Collidable": false,
		"no_collision": true,
		"collidable": false,
		"authored_drop_rules": true,
		"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"hay","item_category":"block","amount":1},{"item_id":"hay_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]},{"item_id":"wheat","item_category":"material","amount":1,"chance":0.2}]},
		"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"hay","item_category":"block","amount_range":[2,5]},{"item_id":"hay_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]},
		"order": 2
	},
"stone": {
		"category": "block",
		"display_name": "Stone",
		"rarity": "common",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [0, 2], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 2),
		"stone_atlas_variants": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		"stone_atlas_weights": [70, 15, 15],
		"seed": "stone_seed",
		"order": 2
	},
"wood": {
		"category": "block",
		"display_name": "Tree Trunk",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [9, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [9, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(9, 4),
		"vertical_variant_atlas_coords": {
			"top": Vector2i(9, 2),
			"middle": Vector2i(9, 3),
			"bottom": Vector2i(9, 4)
		},
		"seed": "wood_seed",
		"no_collision": true,
		"order": 3
	},
"leaf": {
		"category": "block",
		"display_name": "Leaf",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [8, 2], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [8, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(8, 2),
		"seed": "leaf_seed",
		"order": 4
	},
"bedrock": {
		"category": "block",
		"display_name": "Bedrock",
		"rarity": "common",
		"block_health": 9999,
		"texture": {"atlas": "res://image.png", "cell": [7, 2], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [7, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(7, 2),
		"seed": "",
		"placeable": false,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"unbreakable": true,
		"hidden": true,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"collision_size": Vector2i(32, 32),
		"collision_offset": Vector2.ZERO,
		"order": 999
	},
"lava": {
		"category": "block",
		"display_name": "Lava",
		"rarity": "rare",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [0, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 3], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 3),
		"seed": "lava_seed",
		"lava_rebound": true,
		"lava_radial_knockback_velocity": 470.0,
		"light_fx_scene": "res://Scenes/particles/LavaBlockGlowParticlesFX.tscn",
		"light_fx_offset": Vector2.ZERO,
		"light_fx_show_fixture": false,
		# Only lava with an open face gets a light. A walled-in tile is drawn behind its
		# neighbours, so its glow is invisible while still forcing the renderer to redraw
		# everything in its radius -- and those radii overlap across a pool.
		"light_fx_requires_exposed_face": true,
		"order": 5
	},
"sand": {
		"category": "block",
		"display_name": "Sand",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [11, 5], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [11, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(11, 5),
		"sand_atlas_variants": [Vector2i(11, 5), Vector2i(12, 5), Vector2i(11, 6)],
		"sand_atlas_weights": [75, 15, 15],
		"seed": "sand_seed",
		"order": 6
	},
"glass": {
		"category": "block",
		"display_name": "Glass",
		"rarity": "rare",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_1/basic blocks/glass_block.png",
		"atlas_coords": Vector2i(4, 12),
		"seed": "glass_seed",
		"order": 7
	},
"water": {
		"category": "block",
		"display_name": "Water",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [1, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [1, 3], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(1, 3),
		"water_lower_atlas_coords": Vector2i(5, 3),
		"animated": true,
		"animation_frames": ["res://Assets/blocks/Tier_1/basic blocks/water_0.png", "res://Assets/blocks/Tier_1/basic blocks/water_1.png", "res://Assets/blocks/Tier_1/basic blocks/water_2.png", "res://Assets/blocks/Tier_1/basic blocks/water_3.png"],
		"no_collision": true,
		"order": 8
	},
"water_bucket": {
		"category": "block",
		"display_name": "Water Bucket",
		"rarity": "common",
		"block_health": 1,
		"texture": "res://Assets/blocks/Tier_1/basic blocks/water_bucket.png",
		"inventory_icon": "res://Assets/blocks/Tier_1/basic blocks/water_bucket.png",
		"seed": "",
		"placeable": false,
		"water_bucket": true,
		"order": 9
	},
"electric_wire": {
		"category": "block",
		"display_name": "Electric Wire",
		"rarity": "uncommon",
		"block_health": 1,
		"texture": "res://Assets/blocks/electric/electric_wire.svg",
		"inventory_icon": "res://Assets/blocks/electric/electric_wire.svg",
		"seed": "",
		"placeable": false,
		"no_collision": true,
		"collidable": false,
		"visual_wire": true,
		"electrical_device_type": "wire",
		"signal_mode": "on_off",
		"drop_gems": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"drops_self": true
		},
		"order": 10
	},
"metal_pad": {
		"category": "block",
		"display_name": "Metal Pad",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/electric/metal_pad.png",
		"atlas_coords": Vector2i(8, 17),
		"inventory_icon": "res://Assets/blocks/electric/metal_pad.png",
		"seed": "metal_pad_seed",
		"place_layer": "background",
		"background_block": true,
		"electrical_device_type": "metal_pad",
		"signal_mode": "power_storage",
		"drop_gems": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"drops_self": true
		},
		"order": 10
	},
"generator": {
		"category": "block",
		"display_name": "Transformer",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/electric/generator.png",
		"atlas_coords": Vector2i(0, 17),
		"inventory_icon": "res://Assets/blocks/electric/generator.png",
		"animation_frames": ["res://Assets/blocks/electric/generator_1.png", "res://Assets/blocks/electric/generator_2.png", "res://Assets/blocks/electric/generator_3.png"],
		"animation_frame_seconds": 0.18,
		"seed": "",
		"collidable": true,
		"electrical_device_type": "generator",
		"signal_mode": "power_storage",
		"max_watts": 1000,
		"server_triggered_animation": true,
		"drop_gems": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"drops_self": true
		},
		"order": 11
	},
"electric_pole": {
		"category": "block",
		"display_name": "Electric Pole",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/electric/electric_pole.png",
		"inventory_icon": "res://Assets/blocks/electric/electric_pole.png",
		"seed": "electric_pole_seed",
		"no_collision": true,
		"collidable": false,
		"electrical_device_type": "electric_pole",
		"signal_mode": "power_output",
		"drop_gems": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"drops_self": true
		},
		"order": 12
	},
	"golden_statue": {
		"category": "block",
		"display_name": "Golden Statue",
		"rarity": "legendary",
		"block_health": 4,
		"texture": "res://Assets/items/fish/golden_statue.png",
		"inventory_icon": "res://Assets/items/fish/golden_statue.png",
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"drops_self": true,
		"drop_gems": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"drops_self": true
		},
		"fishing_reward": true,
		"sell_value": 0,
		"order": 12
	},

	# ============================================================
	# WORLD EVENT BLOCKS
	# ============================================================
"snow_dirt": {
		"category": "block",
		"display_name": "Snow Dirt",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [11, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [11, 3], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(11, 3),
		"seed": "",
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"order": 130
	},
"ice_block": {
		"category": "block",
		"display_name": "Ice Block",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [12, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(12, 2),
		"inventory_icon": {"atlas": "res://image.png", "cell": [12, 2], "cell_size": [32, 32]},
		"seed": "ice_block_seed",
		"placeable": true,
		"slippery": true,
		"slippery_speed_multiplier": 1.65,
		"slippery_acceleration": 280.0,
		"slippery_friction": 18.0,
		"drop_gems": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "ice_shard", "item_category": "block", "amount_range": [1, 3]},
				{"item_id": "ice_block_seed", "item_category": "seed", "amount_range": [0, 2]},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 4]},
			]
		},
		"order": 131
	},
"ice_shard": {
		"category": "block",
		"display_name": "Ice Shard",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [15, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(15, 4),
		"inventory_icon": {"atlas": "res://image.png", "cell": [15, 4], "cell_size": [32, 32]},
		"seed": "",
		"placeable": false,
		"tradeable": true,
		"dropable": true,
		"drop_gems": false,
		"order": 132
	},
"ice_treasure": {
		"category": "block",
		"display_name": "Ice Treasure",
		"rarity": "rare",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [14, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(14, 2),
		"inventory_icon": {"atlas": "res://image.png", "cell": [14, 2], "cell_size": [32, 32]},
		"seed": "",
		"placeable": false,
		"slippery": true,
		"slippery_speed_multiplier": 1.65,
		"slippery_acceleration": 280.0,
		"slippery_friction": 18.0,
		"dropable": false,
		"drop_gems": false,
		"order": 132
	},
"ice_fossil": {
		"category": "block",
		"display_name": "Ice Fossil",
		"rarity": "rare",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [13, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(13, 2),
		"inventory_icon": {"atlas": "res://image.png", "cell": [13, 2], "cell_size": [32, 32]},
		"seed": "",
		"placeable": false,
		"slippery": true,
		"slippery_speed_multiplier": 1.65,
		"slippery_acceleration": 280.0,
		"slippery_friction": 18.0,
		"dropable": false,
		"drop_gems": false,
		"order": 133
	},
"frozen_treasure": {
		"category": "block",
		"display_name": "Frozen Treasure",
		"rarity": "rare",
		"block_health": 1,
		"texture": {"atlas": "res://image.png", "cell": [12, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [12, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(12, 4),
		"seed": "",
		"no_collision": true,
		"dropable": false,
		"drop_gems": false,
		"placeable": true,
		"order": 134
	},
"frozen_treasure_2": {
		"category": "block",
		"display_name": "Opened Frozen Treasure",
		"rarity": "rare",
		"block_health": 1,
		"texture": {"atlas": "res://image.png", "cell": [13, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [13, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(13, 4),
		"seed": "",
		"no_collision": true,
		"dropable": false,
		"drop_gems": false,
		"placeable": false,
		"order": 135
	},
"snow_block": {
		"category": "block",
		"display_name": "Snow Block",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [11, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(11, 2),
		"inventory_icon": {"atlas": "res://image.png", "cell": [11, 2], "cell_size": [32, 32]},
		"seed": "",
		"drops_self": true,
		"drop_gems": false,
		"order": 136
	},
"snow_leaf": {
		"category": "block",
		"display_name": "Snow Leaf",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [15, 2], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [15, 2], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(15, 2),
		"seed": "",
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"order": 137
	},
"frozen_grass": {
		"category": "block",
		"display_name": "Frozen Grass",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [13, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [13, 3], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(13, 3),
		"animation_frames": [
			{"atlas": "res://image.png", "cell": [13, 3], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [14, 3], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [15, 3], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [14, 3], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [13, 3], "cell_size": [32, 32]}
		],
		"animation_atlas_coords": [
			Vector2i(13, 3),
			Vector2i(14, 3),
			Vector2i(15, 3),
			Vector2i(14, 3),
			Vector2i(13, 3)
		],
		"animation_frame_seconds": 0.24,
		"seed": "",
		"no_collision": true,
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"order": 138
	},
"frozen_grass_1": {
		"category": "block",
		"display_name": "Frozen Grass",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/events/snow_storm/blocks/frozen_grass_1.png",
		"inventory_icon": "res://Assets/inventory_icons/frozen_grass_1.png",
		"atlas_coords": Vector2i(13, 3),
		"seed": "",
		"no_collision": true,
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"hidden": true,
		"order": 139
	},
"frozen_grass_2": {
		"category": "block",
		"display_name": "Frozen Grass",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/events/snow_storm/blocks/frozen_grass_2.png",
		"inventory_icon": "res://Assets/events/snow_storm/blocks/frozen_grass_2.png",
		"atlas_coords": Vector2i(14, 3),
		"seed": "",
		"no_collision": true,
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"hidden": true,
		"order": 140
	},
"frozen_grass_3": {
		"category": "block",
		"display_name": "Frozen Grass",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/events/snow_storm/blocks/frozen_grass_3.png",
		"inventory_icon": "res://Assets/events/snow_storm/blocks/frozen_grass_3.png",
		"atlas_coords": Vector2i(15, 3),
		"seed": "",
		"no_collision": true,
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"hidden": true,
		"order": 141
	},
"pile_of_snow": {
		"category": "block",
		"display_name": "Pile of Snow",
		"rarity": "common",
		"block_health": 1,
		"texture": {"atlas": "res://image.png", "cell": [12, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [12, 3], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(12, 3),
		"seed": "",
		"no_collision": true,
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"hidden": true,
		"order": 142
	},

"snow_bank": {
		"category": "block",
		"display_name": "Snow Bank",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/events/snow_storm/blocks/snow_bank.png",
		"inventory_icon": "res://Assets/events/snow_storm/blocks/snow_bank.png",
		"seed": "",
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"hidden": true,
		"order": 143
	},
"snow_stone": {
		"category": "block",
		"display_name": "Snow Stone",
		"rarity": "common",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [14, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(14, 4),
		"inventory_icon": {"atlas": "res://image.png", "cell": [14, 4], "cell_size": [32, 32]},
		"seed": "",
		"placeable": false,
		"dropable": false,
		"drop_gems": false,
		"hidden": true,
		"order": 144
	},

"cave_background": {
		"category": "block",
		"display_name": "Cave Background",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [1, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [1, 0], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(1, 0),
		"cave_background_atlas_variants": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"cave_background_atlas_weights": [90, 5, 5],
		"seed": "cave_background_seed",
		"background_block": true,
		"place_layer": "background",
		"no_collision": true,
		"collidable": false,
		"order": 9
	},
"broken_bottle": {
		"category": "block",
		"display_name": "Broken Bottle",
		"rarity": "common",
		"block_health": 1,
		"texture": {"atlas": "res://image.png", "cell": [0, 19], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 19),
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 19], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 950
	},
"broken_jar": {
		"category": "block",
		"display_name": "Broken Jar",
		"rarity": "common",
		"block_health": 1,
		"texture": {"atlas": "res://image.png", "cell": [1, 19], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(1, 19),
		"inventory_icon": {"atlas": "res://image.png", "cell": [1, 19], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 951
	},
"broken_flask": {
		"category": "block",
		"display_name": "Broken Flask",
		"rarity": "common",
		"block_health": 1,
		"texture": {"atlas": "res://image.png", "cell": [2, 19], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(2, 19),
		"inventory_icon": {"atlas": "res://image.png", "cell": [2, 19], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 952
	},
"garbage_box": {
		"category": "block",
		"display_name": "Garbage Box",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [3, 19], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(3, 19),
		"inventory_icon": {"atlas": "res://image.png", "cell": [3, 19], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 953
	},
"broken_vending_machine": {
		"category": "block",
		"display_name": "Broken Vending Machine",
		"rarity": "common",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [4, 19], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(4, 19),
		"inventory_icon": {"atlas": "res://image.png", "cell": [4, 19], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 954
	},
	"broken_tv": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "Landfill TV",
		"seed": "broken_tv_seed",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "broken_tv",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "broken_tv_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				5,
				19
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				5,
				19
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_coords": [
			5,
			19
		],
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "broken_tv",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "broken_tv_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"event": "landfill"
	},
	"tires": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 2,
		"breakable": true,
		"display_name": "Used Tires",
		"seed": "tires_seed",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "tires",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "tires_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				6,
				19
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				6,
				19
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_coords": [
			6,
			19
		],
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "tires",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "tires_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"event": "landfill"
	},
"trash_dirt_top": {
		"category": "block",
		"display_name": "Trash-Strewn Dirt",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [0, 18], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 18),
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 18], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 955
	},
"trash_dirt_below": {
		"category": "block",
		"display_name": "Buried Trash",
		"rarity": "common",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [1, 18], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(1, 18),
		"inventory_icon": {"atlas": "res://image.png", "cell": [1, 18], "cell_size": [32, 32]},
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 956
	},
"trash_wallpaper": {
		"category": "block",
		"display_name": "Grimy Wall",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [2, 18], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(2, 18),
		"inventory_icon": {"atlas": "res://image.png", "cell": [2, 18], "cell_size": [32, 32]},
		"seed": "",
		"background_block": true,
		"place_layer": "background",
		"no_collision": true,
		"collidable": false,
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"order": 957
	},
"white_wallpaper": {
	"atlas_coords": Vector2i(0, 10),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "White Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 10],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 80,
	"place_layer": "background",
	"rarity": "common",
	"seed": "white_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 10],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "white_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "white_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "white_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "white_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"grey_wallpaper": {
	"atlas_coords": Vector2i(0, 11),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Gray Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 11],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 81,
	"place_layer": "background",
	"rarity": "common",
	"seed": "grey_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 11],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "grey_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "grey_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "grey_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "grey_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"black_wallpaper": {
	"atlas_coords": Vector2i(0, 12),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Black Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 12],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 82,
	"place_layer": "background",
	"rarity": "common",
	"seed": "black_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 12],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "black_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "black_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "black_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "black_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"red_wallpaper": {
	"atlas_coords": Vector2i(1, 10),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Red Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 10],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 83,
	"place_layer": "background",
	"rarity": "common",
	"seed": "red_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 10],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "red_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "red_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"orange_wallpaper": {
	"atlas_coords": Vector2i(1, 11),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Orange Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 11],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 84,
	"place_layer": "background",
	"rarity": "common",
	"seed": "orange_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 11],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "orange_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "orange_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "orange_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "orange_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"yellow_wallpaper": {
	"atlas_coords": Vector2i(1, 12),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Yellow Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 12],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 85,
	"place_layer": "background",
	"rarity": "common",
	"seed": "yellow_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 12],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "yellow_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "yellow_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "yellow_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "yellow_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"green_wallpaper": {
	"atlas_coords": Vector2i(2, 10),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Green Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 10],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 86,
	"place_layer": "background",
	"rarity": "common",
	"seed": "green_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 10],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "green_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "green_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"aqua_wallpaper": {
	"atlas_coords": Vector2i(2, 11),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Aqua Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 11],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 87,
	"place_layer": "background",
	"rarity": "common",
	"seed": "aqua_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 11],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "aqua_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "aqua_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "aqua_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "aqua_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"blue_wallpaper": {
	"atlas_coords": Vector2i(2, 12),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Blue Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 12],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 88,
	"place_layer": "background",
	"rarity": "common",
	"seed": "blue_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 12],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "blue_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "blue_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "blue_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "blue_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"purple_wallpaper": {
	"atlas_coords": Vector2i(3, 11),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Purple Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 11],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 89,
	"place_layer": "background",
	"rarity": "common",
	"seed": "purple_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 11],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "purple_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "purple_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "purple_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "purple_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pink_wallpaper": {
	"atlas_coords": Vector2i(3, 12),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Pink Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 12],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 90,
	"place_layer": "background",
	"rarity": "common",
	"seed": "pink_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 12],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pink_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "pink_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pink_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "pink_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"brown_wallpaper": {
	"atlas_coords": Vector2i(3, 10),
	"background_block": true,
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"display_name": "Brown Wall",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 10],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 91,
	"place_layer": "background",
	"rarity": "common",
	"seed": "brown_wallpaper_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 10],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "brown_wallpaper",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "brown_wallpaper_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "brown_wallpaper",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "brown_wallpaper_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"glowing_dirt": {
		"category": "block",
		"display_name": "Glowing Dirt",
		"rarity": "epic",
		"block_health": 4,
		"texture": "res://Assets/blocks/special_blocks/glowing_dirt.png",
		"animation_frames": ["res://Assets/blocks/special_blocks/glowing_dirt.png", "res://Assets/blocks/special_blocks/glowing_dirt_2.png"],
		"seed": "",
		"order": 10
	},
"red_block": {
	"atlas_coords": Vector2i(1, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Red Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 7],
		"cell_size": [32, 32]
	},
	"order": 11,
	"rarity": "uncommon",
	"seed": "red_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "red_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "red_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"blue_block": {
	"atlas_coords": Vector2i(2, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Blue Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 9],
		"cell_size": [32, 32]
	},
	"order": 12,
	"rarity": "uncommon",
	"seed": "blue_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "blue_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "blue_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "blue_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "blue_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"green_block": {
	"atlas_coords": Vector2i(2, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Green Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 7],
		"cell_size": [32, 32]
	},
	"order": 13,
	"rarity": "uncommon",
	"seed": "green_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "green_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "green_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"purple_block": {
	"atlas_coords": Vector2i(3, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Purple Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 8],
		"cell_size": [32, 32]
	},
	"order": 14,
	"rarity": "uncommon",
	"seed": "purple_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "purple_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "purple_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "purple_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "purple_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"yellow_block": {
	"atlas_coords": Vector2i(1, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Yellow Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 9],
		"cell_size": [32, 32]
	},
	"order": 15,
	"rarity": "uncommon",
	"seed": "yellow_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "yellow_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "yellow_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "yellow_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "yellow_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"aqua_block": {
	"atlas_coords": Vector2i(2, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Aqua Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 8],
		"cell_size": [32, 32]
	},
	"order": 100,
	"rarity": "uncommon",
	"seed": "aqua_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "aqua_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "aqua_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "aqua_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "aqua_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"black_block": {
	"atlas_coords": Vector2i(0, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Black Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 9],
		"cell_size": [32, 32]
	},
	"order": 101,
	"rarity": "uncommon",
	"seed": "black_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "black_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "black_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "black_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "black_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"blue_pastel_block": {
	"atlas_coords": Vector2i(8, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Blue Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [8, 9],
		"cell_size": [32, 32]
	},
	"order": 102,
	"rarity": "uncommon",
	"seed": "blue_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [8, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "blue_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "blue_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "blue_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "blue_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"brown_block": {
	"atlas_coords": Vector2i(3, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Brown Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 7],
		"cell_size": [32, 32]
	},
	"order": 103,
	"rarity": "uncommon",
	"seed": "brown_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "brown_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "brown_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "brown_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "brown_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_aqua_block": {
	"atlas_coords": Vector2i(5, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Aqua Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [5, 8],
		"cell_size": [32, 32]
	},
	"order": 104,
	"rarity": "uncommon",
	"seed": "dark_aqua_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [5, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_aqua_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_aqua_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_aqua_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_aqua_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_blue_block": {
	"atlas_coords": Vector2i(5, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Blue Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [5, 9],
		"cell_size": [32, 32]
	},
	"order": 105,
	"rarity": "uncommon",
	"seed": "dark_blue_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [5, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_blue_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_blue_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_blue_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_blue_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_brown_block": {
	"atlas_coords": Vector2i(6, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Brown Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [6, 7],
		"cell_size": [32, 32]
	},
	"order": 106,
	"rarity": "uncommon",
	"seed": "dark_brown_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [6, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_brown_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_brown_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_brown_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_brown_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_green_block": {
	"atlas_coords": Vector2i(5, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Green Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [5, 7],
		"cell_size": [32, 32]
	},
	"order": 107,
	"rarity": "uncommon",
	"seed": "dark_green_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [5, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_green_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_green_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_green_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_green_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_pink_block": {
	"atlas_coords": Vector2i(6, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Pink Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [6, 9],
		"cell_size": [32, 32]
	},
	"order": 108,
	"rarity": "uncommon",
	"seed": "dark_pink_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [6, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_pink_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_pink_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_pink_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_pink_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_purple_block": {
	"atlas_coords": Vector2i(6, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Purple Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [6, 8],
		"cell_size": [32, 32]
	},
	"order": 109,
	"rarity": "uncommon",
	"seed": "dark_purple_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [6, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_purple_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_purple_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_purple_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_purple_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"maroon_block": {
	"atlas_coords": Vector2i(4, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Red Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [4, 7],
		"cell_size": [32, 32]
	},
	"order": 110,
	"rarity": "uncommon",
	"seed": "dark_red_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [4, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "maroon_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_red_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "maroon_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_red_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_yellow_block": {
	"atlas_coords": Vector2i(4, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Yellow Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [4, 9],
		"cell_size": [32, 32]
	},
	"order": 111,
	"rarity": "uncommon",
	"seed": "dark_yellow_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [4, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_yellow_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_yellow_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_yellow_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "dark_yellow_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"green_pastel_block": {
	"atlas_coords": Vector2i(8, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Green Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [8, 7],
		"cell_size": [32, 32]
	},
	"order": 112,
	"rarity": "uncommon",
	"seed": "green_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [8, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "green_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "green_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"grey_block": {
	"atlas_coords": Vector2i(0, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Grey Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 8],
		"cell_size": [32, 32]
	},
	"order": 113,
	"rarity": "uncommon",
	"seed": "grey_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "grey_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "grey_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "grey_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "grey_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"happy_block": {
	"atlas_coords": Vector2i(9, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Bunny Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [9, 8],
		"cell_size": [32, 32]
	},
	"order": 114,
	"rarity": "uncommon",
	"seed": "happy_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [9, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "happy_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "happy_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "happy_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "happy_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"dark_orange_block": {
	"atlas_coords": Vector2i(4, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Dark Orange Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [4, 8],
		"cell_size": [32, 32]
	},
	"order": 115,
	"rarity": "uncommon",
	"seed": "light_brown_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [4, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_orange_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "light_brown_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "dark_orange_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "light_brown_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"orange_block": {
	"atlas_coords": Vector2i(1, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Orange Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 8],
		"cell_size": [32, 32]
	},
	"order": 116,
	"rarity": "uncommon",
	"seed": "orange_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "orange_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "orange_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "orange_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "orange_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"orange_pastel_block": {
	"atlas_coords": Vector2i(8, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Orange Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [8, 8],
		"cell_size": [32, 32]
	},
	"order": 117,
	"rarity": "uncommon",
	"seed": "orange_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [8, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "orange_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "orange_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "orange_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "orange_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pastel_flower_block": {
	"atlas_coords": Vector2i(9, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Lily Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [9, 9],
		"cell_size": [32, 32]
	},
	"order": 118,
	"rarity": "uncommon",
	"seed": "pastel_flower_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [9, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pastel_flower_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "pastel_flower_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pastel_flower_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "pastel_flower_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pink_block": {
	"atlas_coords": Vector2i(3, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Pink Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [3, 9],
		"cell_size": [32, 32]
	},
	"order": 119,
	"rarity": "uncommon",
	"seed": "pink_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [3, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pink_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "pink_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pink_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "pink_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pink_pastel_block": {
	"atlas_coords": Vector2i(7, 9),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Pink Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [7, 9],
		"cell_size": [32, 32]
	},
	"order": 120,
	"rarity": "uncommon",
	"seed": "pink_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [7, 9],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pink_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "pink_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pink_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "pink_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"purple_pastel_block": {
	"atlas_coords": Vector2i(9, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Purple Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [9, 7],
		"cell_size": [32, 32]
	},
	"order": 121,
	"rarity": "uncommon",
	"seed": "purple_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [9, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "purple_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "purple_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "purple_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "purple_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"red_pastel_block": {
	"atlas_coords": Vector2i(7, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Red Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [7, 7],
		"cell_size": [32, 32]
	},
	"order": 122,
	"rarity": "uncommon",
	"seed": "red_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [7, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "red_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "red_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"white_block": {
	"atlas_coords": Vector2i(0, 7),
	"block_health": 3,
	"category": "block",
	"display_name": "White Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 7],
		"cell_size": [32, 32]
	},
	"order": 123,
	"rarity": "uncommon",
	"seed": "white_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 7],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "white_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "white_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "white_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "white_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"yellow_pastel_block": {
	"atlas_coords": Vector2i(7, 8),
	"block_health": 3,
	"category": "block",
	"display_name": "Pastel Yellow Block",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [7, 8],
		"cell_size": [32, 32]
	},
	"order": 124,
	"rarity": "uncommon",
	"seed": "yellow_pastel_block_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [7, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "yellow_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "yellow_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 4]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "yellow_pastel_block",
				"item_category": "block",
				"amount_range": [1, 3]
			},
			{
				"item_id": "yellow_pastel_block_seed",
				"item_category": "seed",
				"amount_range": [0, 2]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"collidable": true,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"ps_blue_block": {
		"category": "block",
		"display_name": "Prestige Blue Block",
		"rarity": "epic",
		"block_health": 3,
		"texture": "res://Assets/blocks/prestige_coloured_blocks/ps_blue_block.png",
		"inventory_icon": "res://Assets/blocks/prestige_coloured_blocks/ps_blue_block.png",
		"seed": "",
		"drops_self": true,
		"drop_gems": false,
		"order": 125
	},
"ps_green_block": {
		"category": "block",
		"display_name": "Prestige Green Block",
		"rarity": "epic",
		"block_health": 3,
		"texture": "res://Assets/blocks/prestige_coloured_blocks/ps_green_block.png",
		"inventory_icon": "res://Assets/blocks/prestige_coloured_blocks/ps_green_block.png",
		"seed": "",
		"drops_self": true,
		"drop_gems": false,
		"order": 126
	},
"ps_purple_block": {
		"category": "block",
		"display_name": "Prestige Purple Block",
		"rarity": "epic",
		"block_health": 3,
		"texture": "res://Assets/blocks/prestige_coloured_blocks/ps_purple_block.png",
		"inventory_icon": "res://Assets/blocks/prestige_coloured_blocks/ps_purple_block.png",
		"seed": "",
		"drops_self": true,
		"drop_gems": false,
		"order": 127
	},
"ps_red_block": {
		"category": "block",
		"display_name": "Prestige Red Block",
		"rarity": "epic",
		"block_health": 3,
		"texture": "res://Assets/blocks/prestige_coloured_blocks/ps_red_block.png",
		"inventory_icon": "res://Assets/blocks/prestige_coloured_blocks/ps_red_block.png",
		"seed": "",
		"drops_self": true,
		"drop_gems": false,
		"order": 128
	},
"ps_yellow_block": {
		"category": "block",
		"display_name": "Prestige Yellow Block",
		"rarity": "epic",
		"block_health": 3,
		"texture": "res://Assets/blocks/prestige_coloured_blocks/ps_yellow_block.png",
		"inventory_icon": "res://Assets/blocks/prestige_coloured_blocks/ps_yellow_block.png",
		"seed": "",
		"drops_self": true,
		"drop_gems": false,
		"order": 129
	},
"rose": {
		"category": "block",
		"display_name": "Rose",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [3, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [3, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(3, 4),
		"seed": "rose_seed",
		"no_collision": true,
		"order": 16
	},
"sunflower": {
		"category": "block",
		"display_name": "Sunflower",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [5, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [5, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(5, 4),
		"seed": "tulip_seed",
		"no_collision": true,
		"order": 17
	},
"hanging_vine": {
	"atlas_coords": Vector2i(6, 3),
	"block_health": 2,
	"category": "block",
	"display_name": "Small Vines",
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [6, 3],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 18,
	"rarity": "common",
	"seed": "vines_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [6, 3],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "hanging_vine",
				"item_category": "block",
				"amount": 1,
				"chance": 0.8
			},
			{
				"item_id": "vines_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "hanging_vine",
				"item_category": "block",
				"amount_range": [4, 7]
			},
			{
				"item_id": "vines_seed",
				"item_category": "seed",
				"amount_range": [2, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"apple": {
		"category": "block",
		"display_name": "Apple",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [8, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [8, 3], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(8, 3),
		"seed": "apple_seed",
		"no_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "apple", "item_category": "block", "amount_range": [1, 4]},
				{"item_id": "apple_seed", "item_category": "seed", "amount_range": [0, 3]},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 3]}
			]
		},
		"order": 19
	},
"climbing_vine": {
		"category": "block",
		"display_name": "Climbing Vine",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [10, 3], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [10, 3], "cell_size": [32, 32]},
		"vertical_variant_atlas_coords": {
			"top": Vector2i(10, 2),
			"middle": Vector2i(10, 3),
			"bottom": Vector2i(10, 4),
			"single": Vector2i(11, 4)
		},
		"seed": "climbing_vine_seed",
		"platform_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "climbing_vine", "item_category": "block", "amount_range": [1, 4]},
				{"item_id": "climbing_vine_seed", "item_category": "seed", "amount_range": [0, 3]},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 3]}
			]
		},
		"order": 20
	},
"sun_flower": {
		"category": "block",
		"display_name": "Sun Flower",
		"rarity": "common",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_1/basic blocks/sun_flower.png",
		"inventory_icon": "res://Assets/blocks/Tier_1/basic blocks/sun_flower.png",
		"seed": "sun_flower_seed",
		"hidden": true,
		"no_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "sun_flower", "item_category": "block", "amount_range": [1, 4]},
				{"item_id": "sun_flower_seed", "item_category": "seed", "amount_range": [0, 3]},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 3]}
			]
		},
		"order": 21
	},
"poppy": {
		"category": "block",
		"display_name": "Poppy",
		"rarity": "common",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_1/basic blocks/poppy.png",
		"inventory_icon": "res://Assets/blocks/Tier_1/basic blocks/poppy.png",
		"seed": "poppy_seed",
		"no_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "poppy", "item_category": "block", "amount_range": [1, 4]},
				{"item_id": "poppy_seed", "item_category": "seed", "amount_range": [0, 3]},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 3]}
			]
		},
		"order": 22
	},
"lily": {
		"category": "block",
		"display_name": "Lily",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [4, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [4, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(4, 4),
		"seed": "lily_seed",
		"no_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "lily", "item_category": "block", "amount_range": [1, 4]},
				{"item_id": "lily_seed", "item_category": "seed", "amount_range": [0, 3]},
				{"item_id": "gem", "item_category": "currency", "amount_range": [0, 3]}
			]
		},
		"order": 23
	},
"sand_castle": {
	"atlas_coords": Vector2i(12, 6),
	"block_health": 2,
	"category": "block",
	"display_name": "Sand Castle",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "sand_castle",
				"item_category": "block",
				"amount": 1,
				"chance": 0.65
			},
			{
				"item_id": "sand_castle_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.25
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [12, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 24,
	"rarity": "common",
	"seed": "sand_castle_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [12, 6],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "sand_castle",
				"item_category": "block",
				"amount_range": [3, 6]
			},
			{
				"item_id": "sand_castle_seed",
				"item_category": "seed",
				"amount_range": [1, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"pile_of_sand": {
	"atlas_coords": Vector2i(13, 6),
	"block_health": 2,
	"category": "block",
	"display_name": "Pile of Sand",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pile_of_sand",
				"item_category": "block",
				"amount": 1,
				"chance": 0.85
			},
			{
				"item_id": "pile_of_sand_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.55
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [13, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 25,
	"rarity": "common",
	"seed": "pile_of_sand_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [13, 6],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "pile_of_sand",
				"item_category": "block",
				"amount_range": [4, 7]
			},
			{
				"item_id": "pile_of_sand_seed",
				"item_category": "seed",
				"amount_range": [2, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"vines_2": {
	"block_health": 2,
	"category": "block",
	"display_name": "Big Vines",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "vines_2",
				"item_category": "block",
				"amount": 1,
				"chance": 0.68
			},
			{
				"item_id": "vines_2_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.32
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [7, 3],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 26,
	"rarity": "common",
	"seed": "vines_2_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [7, 3],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "vines_2",
				"item_category": "block",
				"amount_range": [3, 6]
			},
			{
				"item_id": "vines_2_seed",
				"item_category": "seed",
				"amount_range": [1, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"collidable": false,
	"solid": false,
	"collision_type": "none",
	"platform_collision": false,
	"atlas_coords": Vector2i(7, 3),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},

	# ============================================================
	# SYSTEM / HIDDEN WORLD BLOCKS
	# ============================================================
	"small_lock": {
		"category": "block",
		"display_name": "Small Lock",
		"rarity": "rare",
		"block_health": 6,
		"texture": {"atlas": "res://image.png", "cell": [9, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [9, 0], "cell_size": [32, 32]},
		"interaction_permission": "owner_only",
		"seed": "",
		"shop_price": 500,
		"area_lock_tiles": 10,
		"collidable": true,
		"solid": true,
		"collision_type": "custom",
		"collision_size": Vector2i(24, 28),
		"collision_offset": Vector2(0, 2),
		"order": 16
	},
	"medium_lock": {
		"category": "block",
		"display_name": "Medium Lock",
		"rarity": "epic",
		"block_health": 7,
		"texture": {"atlas": "res://image.png", "cell": [10, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [10, 0], "cell_size": [32, 32]},
		"interaction_permission": "owner_only",
		"seed": "",
		"shop_price": 1000,
		"area_lock_tiles": 48,
		"collidable": true,
		"solid": true,
		"collision_type": "custom",
		"collision_size": Vector2i(24, 28),
		"collision_offset": Vector2(0, 2),
		"order": 17
	},
	"big_lock": {
		"category": "block",
		"display_name": "Big Lock",
		"rarity": "epic",
		"block_health": 8,
		"texture": {"atlas": "res://image.png", "cell": [11, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [11, 0], "cell_size": [32, 32]},
		"interaction_permission": "owner_only",
		"seed": "",
		"shop_price": 1500,
		"area_lock_tiles": 80,
		"collidable": true,
		"solid": true,
		"collision_type": "custom",
		"collision_size": Vector2i(24, 28),
		"collision_offset": Vector2(0, 2),
		"order": 18
	},
	"world_lock": {
		"category": "block",
		"display_name": "World Lock",
		"rarity": "legendary",
		"block_health": 8,
		"texture": {"atlas": "res://image.png", "cell": [3, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [3, 0], "cell_size": [32, 32]},
		"world_lock_access_atlas_coords": Vector2i(5, 0),
		"world_lock_no_access_atlas_coords": Vector2i(4, 0),
		"interaction_permission": "owner_only",
		"seed": "",
		"shop_price": 3500,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"collision_size": Vector2i(32, 32),
		"collision_offset": Vector2.ZERO,
		"order": 19
	},
"super_world_lock": {
		"category": "block",
		"display_name": "Super World Lock",
		"rarity": "legendary",
		"block_health": 8,
		"texture": {"atlas": "res://image.png", "cell": [6, 0], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [6, 0], "cell_size": [32, 32]},
		"world_lock_access_atlas_coords": Vector2i(8, 0),
		"world_lock_no_access_atlas_coords": Vector2i(7, 0),
		"interaction_permission": "owner_only",
		"seed": "",
		"max_stack": 400,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"collision_size": Vector2i(32, 32),
		"collision_offset": Vector2.ZERO,
		"order": 20
	},
"entrance_gate": {
		"category": "block",
		"display_name": "Entrance Gate",
		"rarity": "legendary",
		"block_health": 9999,
		"texture": {"atlas": "res://image.png", "cell": [4, 2], "cell_size": [32, 32]},
		"animation_frames": [
			{"atlas": "res://image.png", "cell": [4, 2], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [5, 2], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [6, 2], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [5, 2], "cell_size": [32, 32]},
			{"atlas": "res://image.png", "cell": [4, 2], "cell_size": [32, 32]}
		],
		"animation_frame_seconds": 0.24,
		"no_collision": true,
		"unbreakable": true,
		"hidden": true,
		"order": 999
	},

	# ============================================================
	# STATIONS
	# ============================================================
"crafting_station": {
		"category": "block",
		"display_name": "Crafting Station",
		"rarity": "uncommon",
		"block_health": 5,
		"texture": {"atlas": "res://image.png", "cell": [7, 1], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [7, 1], "cell_size": [32, 32]},
		"visual_size": Vector2i(32, 32),
		"visual_offset": Vector2.ZERO,
		"no_collision": true,
		"collidable": false,
		"collision_size": Vector2i(32, 32),
		"collision_offset": Vector2.ZERO,
		"shadow_size": Vector2i(32, 32),
		"shadow_visual_offset": Vector2.ZERO,
		"order": 20
	},
"crafting_station_left": {
		"category": "block",
		"display_name": "Crafting Station Left",
		"rarity": "uncommon",
		"block_health": 5,
		"texture": {"atlas": "res://image.png", "cell": [7, 1], "cell_size": [32, 32]},
		"visual_size": Vector2i(32, 32),
		"no_collision": true,
		"collidable": false,
		"seed": "",
		"hidden": true,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"placeable": false,
		"legacy_station_part": "left",
		"order": 20
	},
"crafting_station_right": {
		"category": "block",
		"display_name": "Crafting Station Right",
		"rarity": "uncommon",
		"block_health": 5,
		"texture": {"atlas": "res://image.png", "cell": [7, 1], "cell_size": [32, 32]},
		"visual_size": Vector2i(32, 32),
		"no_collision": true,
		"collidable": false,
		"seed": "",
		"hidden": true,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"placeable": false,
		"legacy_station_part": "right",
		"order": 20
	},
	# ============================================================
	# SPLICEABLE WORLD ITEMS
	# ============================================================
"wood_plank": {
		"category": "block",
		"display_name": "Wood Plank",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/crafting_station/blocks/wood_plank.png",
		"seed": "wood_plank_seed",
		"craft_only": false,
		"order": 30
	},
"stone_brick": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(18, 5),
	"atlas_item_id": 41,
	"atlas_source_id": 0,
	"block_health": 5,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": true,
	"display_name": "Stone Brick",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "stone_brick",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "stone_brick_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [18, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 31,
	"place_layer": "foreground",
	"rarity": "uncommon",
	"seed": "stone_brick_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [18, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "stone_brick",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "stone_brick_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"red_brick": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(17, 5),
	"atlas_item_id": 40,
	"atlas_source_id": 0,
	"block_health": 5,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Red Brick",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_brick",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "red_brick_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [17, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 415,
	"place_layer": "foreground",
	"rarity": "uncommon",
	"seed": "red_brick_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [17, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_brick",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "red_brick_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"green_brick": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(19, 5),
	"atlas_item_id": 42,
	"atlas_source_id": 0,
	"block_health": 5,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Grimstone",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_brick",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "green_brick_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [19, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 416,
	"place_layer": "foreground",
	"rarity": "uncommon",
	"seed": "green_brick_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [19, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_brick",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "green_brick_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"green_moss_brick": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(20, 5),
	"atlas_item_id": 43,
	"atlas_source_id": 0,
	"block_health": 5,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Green Moss Brick",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_moss_brick",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "green_moss_brick_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [20, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 417,
	"place_layer": "foreground",
	"rarity": "uncommon",
	"seed": "green_moss_brick_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [20, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_moss_brick",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "green_moss_brick_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"red_brick_wall": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(17, 6),
	"atlas_item_id": 44,
	"atlas_source_id": 0,
	"background_block": true,
	"block_health": 3,
	"category": "block",
	"collidable": false,
	"collision_type": "none",
	"craft_only": false,
	"display_name": "Red Brick Wall",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_brick_wall",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "red_brick_wall_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [17, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 418,
	"place_layer": "background",
	"rarity": "uncommon",
	"seed": "red_brick_wall_seed",
	"solid": false,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [17, 6],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "red_brick_wall",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "red_brick_wall_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"stone_brick_wall": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(18, 6),
	"atlas_item_id": 45,
	"atlas_source_id": 0,
	"background_block": true,
	"block_health": 3,
	"category": "block",
	"collidable": false,
	"collision_type": "none",
	"craft_only": false,
	"display_name": "Stone Brick Wall",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "stone_brick_wall",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "stone_brick_wall_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [18, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 419,
	"place_layer": "background",
	"rarity": "uncommon",
	"seed": "stone_brick_wall_seed",
	"solid": false,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [18, 6],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "stone_brick_wall",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "stone_brick_wall_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"green_brick_wall": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(19, 6),
	"atlas_item_id": 46,
	"atlas_source_id": 0,
	"background_block": true,
	"block_health": 3,
	"category": "block",
	"collidable": false,
	"collision_type": "none",
	"craft_only": false,
	"display_name": "Grimstone Wall",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_brick_wall",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "green_brick_wall_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [19, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 420,
	"place_layer": "background",
	"rarity": "uncommon",
	"seed": "green_brick_wall_seed",
	"solid": false,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [19, 6],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_brick_wall",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "green_brick_wall_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"green_moss_brick_wall": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(20, 6),
	"atlas_item_id": 47,
	"atlas_source_id": 0,
	"background_block": true,
	"block_health": 3,
	"category": "block",
	"collidable": false,
	"collision_type": "none",
	"craft_only": false,
	"display_name": "Green Moss Wall",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_moss_brick_wall",
				"item_category": "block",
				"amount": 1,
				"chance": 0.45
			},
			{
				"item_id": "green_moss_brick_wall_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.08
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 5]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [20, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 421,
	"place_layer": "background",
	"rarity": "uncommon",
	"seed": "green_moss_brick_wall_seed",
	"solid": false,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [20, 6],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "green_moss_brick_wall",
				"item_category": "block",
				"amount_range": [1, 4]
			},
			{
				"item_id": "green_moss_brick_wall_seed",
				"item_category": "seed",
				"amount_range": [0, 4]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"gold_block": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(21, 5),
	"atlas_item_id": 48,
	"atlas_source_id": 0,
	"block_health": 6,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Golden Block",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "gold_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gold_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [20, 60]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [21, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 422,
	"place_layer": "foreground",
	"rarity": "epic",
	"seed": "gold_block_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [21, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "gold_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gold_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"emerald_block": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(22, 5),
	"atlas_item_id": 49,
	"atlas_source_id": 0,
	"block_health": 6,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Emerald Block",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "emerald_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "emerald_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [20, 60]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [22, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 423,
	"place_layer": "foreground",
	"rarity": "epic",
	"seed": "emerald_block_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [22, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "emerald_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "emerald_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"ruby_block": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(23, 5),
	"atlas_item_id": 50,
	"atlas_source_id": 0,
	"block_health": 6,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Ruby Block",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "ruby_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "ruby_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [20, 60]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [23, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 424,
	"place_layer": "foreground",
	"rarity": "epic",
	"seed": "ruby_block_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [23, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "ruby_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "ruby_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"diamond_block": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(24, 5),
	"atlas_item_id": 51,
	"atlas_source_id": 0,
	"block_health": 6,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Diamond Block",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "diamond_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "diamond_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [20, 60]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [24, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 425,
	"place_layer": "foreground",
	"rarity": "epic",
	"seed": "diamond_block_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [24, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "diamond_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "diamond_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"amethyst_block": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(25, 5),
	"atlas_item_id": 52,
	"atlas_source_id": 0,
	"block_health": 6,
	"category": "block",
	"collidable": true,
	"collision_type": "full",
	"craft_only": false,
	"display_name": "Gem Block",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "amethyst_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "amethyst_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [20, 60]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [25, 5],
		"cell_size": [32, 32]
	},
	"no_collision": false,
	"order": 426,
	"place_layer": "foreground",
	"rarity": "epic",
	"seed": "amethyst_block_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [25, 5],
		"cell_size": [32, 32]
	},
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "amethyst_block",
				"item_category": "block",
				"amount_range": [0, 3]
			},
			{
				"item_id": "amethyst_block_seed",
				"item_category": "seed",
				"amount_range": [0, 1]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"background_block": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
"glass_panel": {
		"category": "block",
		"display_name": "Glass Panel",
		"rarity": "rare",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_1/basic blocks/glass_panel.png",
		"atlas_coords": Vector2i(5, 12),
		"seed": "glass_panel_seed",
		"background_block": true,
		"place_layer": "background",
		"no_collision": true,
		"collidable": false,
		"craft_only": false,
		"order": 32
	},
"rainbow_block": {
		"category": "block",
		"display_name": "Rainbow Block",
		"rarity": "epic",
		"block_health": 5,
		"texture": {"atlas": "res://image.png", "cell": [10, 7], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(10, 7),
		"inventory_icon": {"atlas": "res://image.png", "cell": [10, 7], "cell_size": [32, 32]},
		"seed": "gem_block_seed",
		"craft_only": true,
		"order": 34
	},
"wood_platform": {
		"category": "block",
		"display_name": "Wood Platform",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [0, 5], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 5),
		"seed": "wood_platform_seed",
		"platform_collision": true,
		"platform_variant_atlas_coords": {
			"left": Vector2i(1, 5),
			"middle": Vector2i(2, 5),
			"right": Vector2i(3, 5)
		},
		"craft_only": false,
		"order": 36
	},
"wooden_entrance": {
		"category": "block",
		"display_name": "Wooden Entrance",
		"rarity": "rare",
		"block_health": 4,
		"texture": {"atlas": "res://image.png", "cell": [6, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(6, 5),
		"inventory_icon": {"atlas": "res://image.png", "cell": [6, 5], "cell_size": [32, 32]},
		"seed": "wooden_entrance_seed",
		"no_collision": true,
		"entrance_block": true,
		"entrance_tilemap_collision": true,
		"entrance_idle_texture": "res://Assets/blocks/Tier_1/wooden/wooden_entrance_1.png",
		"entrance_idle_atlas_coords": Vector2i(6, 5),
		"entrance_pass_atlas_frames": [
			Vector2i(6, 5),
			Vector2i(7, 5),
			Vector2i(8, 5)
		],
		"entrance_pass_animation_columns": 3,
		"solid": true,
		"collision_type": "full",
		"entrance_frames": ["res://Assets/blocks/Tier_1/wooden/wooden_entrance_1.png", "res://Assets/blocks/Tier_1/wooden/wooden_entrance_2.png", "res://Assets/blocks/Tier_1/wooden/wooden_entrance_3.png"],
		"craft_only": false,
		"order": 35
	},
"sign": {
		"category": "block",
		"display_name": "Sign",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [5, 5], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [5, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(5, 5),
		"seed": "sign_seed",
		"sign_block": true,
		"no_collision": true,
		"collidable": false,
		"splice_only": false,
		"order": 37
	},
	# Walk-through interactable that opens the event leaderboard UI. Any player can use it,
	# including visitors with no build access in the world -- that bypass lives in
	# world_lock_manager.gd (can_current_player_interact_with_block /
	# can_current_player_interact_with_block_at), not here.
	#
	# The collision flags are load-bearing and MUST stay in sync with the server definition in
	# PixelManiaServer/src/server_item_database.ts. The server defaults collision_type to
	# "full", so a server entry that merely omits these is SOLID while the client is not --
	# which does not read as a collision bug in game, it hard-snaps the player back every
	# frame and reads as being physically trapped. scripts/check_item_database_sync.js
	# asserts this parity; see the block_collision_model project note.
	"leaderboard": {
	"atlas_coords": Vector2i(21, 15),
	"block_health": 4,
	"category": "block",
	"collidable": false,
	"collision_type": "none",
	"display_name": "Leaderboard",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": []
	},
	"interact_rules": true,
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [21, 15],
		"cell_size": [32, 32]
	},
	"leaderboard_block": true,
	"no_collision": true,
	"order": 416,
	"rarity": "epic",
	"seed": "",
	"solid": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [21, 15],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": true,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": []
	},
	"place_layer": "foreground",
	"background_block": false,
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"break_return_item_id": "leaderboard",
	"authored_drop_rules": true
},
"wooden_treasure_chest": {
		"category": "block",
		"display_name": "Wooden Treasure Chest",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [9, 5], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [9, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(9, 5),
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "wooden_treasure_chest", "item_category": "block", "amount": 1}
			]
		},
		"craft_only": false,
		"order": 46
	},
"wooden_treasure_chest_open": {
		"category": "block",
		"display_name": "Opened Wooden Treasure Chest",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [10, 5], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [10, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(10, 5),
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"placeable": false,
		"dropable": false,
		"hidden": true,
		"order": 47
	},
"mechanical_entrance": {
		"category": "block",
		"display_name": "Mechanical Entrance",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/Tier_2/steel/mechanical_entrance_1.png",
		"atlas_coords": Vector2i(8, 11),
		"seed": "mechanical_entrance_seed",
		"no_collision": true,
		"entrance_block": true,
		"entrance_tilemap_collision": true,
		"entrance_idle_texture": "res://Assets/blocks/Tier_2/steel/mechanical_entrance_1.png",
		"entrance_idle_atlas_coords": Vector2i(8, 11),
		"entrance_pass_atlas_coords": Vector2i(9, 11),
		"entrance_pass_animation_columns": 3,
		"solid": true,
		"collision_type": "full",
		"entrance_frames": ["res://Assets/blocks/Tier_2/steel/mechanical_entrance_2.png", "res://Assets/blocks/Tier_2/steel/mechanical_entrance_3.png", "res://Assets/blocks/Tier_2/steel/mechanical_entrance_4.png"],
		"entrance_animation_frame_seconds": 0.065,
		"craft_only": false,
		"order": 140
	},
"ceiling_lamp": {
		"category": "block",
		"display_name": "Ceiling Lamp",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_2/steel/ceiling_lamp_off.png",
		"inventory_icon": "res://Assets/blocks/Tier_2/steel/ceiling_lamp_on.png",
		"seed": "ceiling_lamp_seed",
		"no_collision": true,
		"collidable": false,
		"toggle_block": true,
		"toggle_state_key": "toggle_on",
		"toggle_action": "ceiling_lamp_state",
		"toggle_textures": {
			"off": "res://Assets/blocks/Tier_2/steel/ceiling_lamp_off.png",
			"on": "res://Assets/blocks/Tier_2/steel/ceiling_lamp_on.png"
		},
		"light_fx_scene": "res://Scenes/particles/CeilingLightParticlesFX.tscn",
		"light_fx_when_on": true,
		"light_fx_show_fixture": false,
		"interact_rules": true,
		"order": 141
	,
"authored_drop_rules": true
,
"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"ceiling_lamp","item_category":"block","amount":1},{"item_id":"ceiling_lamp_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]}
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"ceiling_lamp","item_category":"block","amount_range":[2,5]},{"item_id":"ceiling_lamp_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
"steel_door": {
		"category": "block",
		"display_name": "Steel Door",
		"rarity": "uncommon",
		"block_health": 4,
		"texture": "res://Assets/blocks/Tier_2/steel/steel_door.png",
		"atlas_coords": Vector2i(7, 10),
		"seed": "steel_door_seed",
		"no_collision": true,
		"collidable": false,
		"door_block": true,
		"interact_rules": true,
		"order": 142
	},
"steel_block": {
		"category": "block",
		"display_name": "Steel Block",
		"rarity": "uncommon",
		"block_health": 5,
		"texture": "res://Assets/blocks/Tier_2/steel/steel_block.png",
		"atlas_coords": Vector2i(4, 10),
		"seed": "steel_block_seed",
		"order": 143
	},
"screen_door": {
		"category": "block",
		"display_name": "Screen Door",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/Tier_2/steel/screen_door.png",
		"atlas_coords": Vector2i(8, 10),
		"seed": "screen_door_seed",
		"no_collision": true,
		"collidable": false,
		"door_block": true,
		"interact_rules": true,
		"order": 144
	},
"steel_background": {
		"category": "block",
		"display_name": "Steel Background",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/Tier_2/steel/steel_background.png",
		"atlas_coords": Vector2i(5, 10),
		"seed": "steel_background_seed",
		"background_block": true,
		"place_layer": "background",
		"no_collision": true,
		"collidable": false,
		"order": 145
	},
"steel_sign": {
		"category": "block",
		"display_name": "Steel Sign",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/Tier_2/steel/steel_sign.png",
		"seed": "steel_sign_seed",
		"sign_block": true,
		"no_collision": true,
		"collidable": false,
		"order": 146
	},
"steel_platform": {
		"category": "block",
		"display_name": "Steel Platform",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [6, 12], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [6, 12], "cell_size": [32, 32]},
		"atlas_item_id": 33,
		"atlas_coords": Vector2i(6, 12),
		"seed": "steel_platform_seed",
		"platform_collision": true,
		"platform_variant_textures": {
			"left": "res://Assets/blocks/Tier_2/steel/steel_platform_left.png",
			"middle": "res://Assets/blocks/Tier_2/steel/steel_platform_middle.png",
			"right": "res://Assets/blocks/Tier_2/steel/steel_platform_right.png"
		},
		"order": 147
	},
"steel_ladder": {
		"category": "block",
		"display_name": "Steel Ladder",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/Tier_2/steel/steel_ladder.png",
		"atlas_coords": Vector2i(7, 11),
		"seed": "steel_ladder_seed",
		"platform_collision": true,
		"order": 148
	},
"mushroom": {
		"category": "block",
		"display_name": "Mushroom",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [7, 4], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [7, 4], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(7, 4),
		"springboard_animation_frames": ["res://Assets/blocks/Tier_1/mushroom_1.png", "res://Assets/blocks/Tier_1/mushroom_2.png"],
		"springboard_animation_atlas_frames": [
			Vector2i(7, 4),
			Vector2i(8, 4)
		],
		"springboard_animation_frame_seconds": 0.22,
		"seed": "mushroom_seed",
		"collidable": true,
		"springboard": true,
		"springboard_velocity": -420.0,
		"order": 38
	},
"wooden_door": {
		"category": "block",
		"display_name": "Wooden Door",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [3, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(3, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [3, 6], "cell_size": [32, 32]},
		"seed": "wooden_door_seed",
		"no_collision": true,
		"collidable": false,
		"door_block": true,
		"interact_rules": true,
		"order": 39
	},
"wooden_block": {
		"category": "block",
		"display_name": "Wooden Block",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [0, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(0, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [0, 6], "cell_size": [32, 32]},
		"seed": "wooden_block_seed",
		"order": 40
	},
"wooden_wallpaper": {
		"category": "block",
		"display_name": "Wooden Wallpaper",
		"rarity": "common",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [1, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(1, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [1, 6], "cell_size": [32, 32]},
		"seed": "wooden_background_seed",
		"background_block": true,
		"place_layer": "background",
		"no_collision": true,
		"collidable": false,
		"order": 41
	},
"wooden_fence": {
		"category": "block",
		"display_name": "Wooden Fence",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [4, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(4, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [4, 6], "cell_size": [32, 32]},
		"seed": "wooden_fence_seed",
		"no_collision": true,
		"collidable": false,
		"foreground_over_player": true,
		"order": 42
	},
"wooden_window": {
		"category": "block",
		"display_name": "Wooden Window",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": {"atlas": "res://image.png", "cell": [2, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(2, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [2, 6], "cell_size": [32, 32]},
		"seed": "wooden_frame_seed",
		"order": 43
	},
"wooden_chair": {
		"category": "block",
		"display_name": "Wooden Chair",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [5, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(5, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [5, 6], "cell_size": [32, 32]},
		"seed": "wooden_chair_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "wooden_chair", "item_category": "block", "amount": 1}
			]
		},
		"order": 44
	},
"wooden_table": {
		"category": "block",
		"display_name": "Wooden Table",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [6, 6], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(6, 6),
		"inventory_icon": {"atlas": "res://image.png", "cell": [6, 6], "cell_size": [32, 32]},
		"seed": "wooden_table_seed",
		"platform_collision": true,
		"platform_variant_atlas_coords": {
			"left": Vector2i(7, 6),
			"middle": Vector2i(8, 6),
			"right": Vector2i(9, 6)
		},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "wooden_table", "item_category": "block", "amount": 1}
			]
		},
		"order": 45
	},
"wooden_crappy_sign": {
	"atlas_coords": Vector2i(10, 6),
	"block_health": 2,
	"category": "block",
	"collidable": false,
	"collision_type": "none",
	"display_name": "Mysterious Sign",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"drops_self": true,
		"fixed_drops": [
			{
				"item_id": "wooden_crappy_sign",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "wooden_crappy_sign_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [10, 6],
		"cell_size": [32, 32]
	},
	"no_collision": true,
	"order": 54,
	"rarity": "uncommon",
	"seed": "wooden_crappy_sign_seed",
	"sign_block": true,
	"solid": false,
	"texture": {
		"atlas": "res://image.png",
		"cell": [10, 6],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "wooden_crappy_sign",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "wooden_crappy_sign_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"platform_collision": false,
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"wooden_ladder": {
		"category": "block",
		"display_name": "Wooden Ladder",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": {"atlas": "res://image.png", "cell": [4, 5], "cell_size": [32, 32]},
		"atlas_coords": Vector2i(4, 5),
		"inventory_icon": {"atlas": "res://image.png", "cell": [4, 5], "cell_size": [32, 32]},
		"seed": "wooden_ladder_seed",
		"platform_collision": true,
		"order": 53
	},

	# ============================================================
	# BASIC SEEDS
	# ============================================================
"dirt_seed": {
		"category": "seed",
		"display_name": "Dirt Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/dirt_seed.png",
		"grows_into": "dirt",
		"order": 0,
		"tree_textures": ["res://Assets/seed_tree_sprites/dirt_tree_stage0.png", "res://Assets/seed_tree_sprites/dirt_tree_stage1.png", "res://Assets/seed_tree_sprites/dirt_tree_stage2.png", "res://Assets/seed_tree_sprites/dirt_tree_mature.png"]
	},
"grass_seed": {
		"category": "seed",
		"display_name": "Grass Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/grass_seed.png",
		"grows_into": "grass",
		"order": 1,
		"tree_textures": ["res://Assets/seed_tree_sprites/grass_tree_stage0.png", "res://Assets/seed_tree_sprites/grass_tree_stage1.png", "res://Assets/seed_tree_sprites/grass_tree_stage2.png", "res://Assets/seed_tree_sprites/grass_tree_mature.png"]
	},
"stone_seed": {
		"category": "seed",
		"display_name": "Stone Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/stone_seed.png",
		"grows_into": "stone",
		"order": 2,
		"tree_textures": ["res://Assets/seed_tree_sprites/stone_tree_stage0.png", "res://Assets/seed_tree_sprites/stone_tree_stage1.png", "res://Assets/seed_tree_sprites/stone_tree_stage2.png", "res://Assets/seed_tree_sprites/stone_tree_mature.png"]
	},
"wood_seed": {
		"category": "seed",
		"display_name": "Tree Trunk Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/wood_seed.png",
		"grows_into": "wood",
		"order": 3,
		"tree_textures": ["res://Assets/seed_tree_sprites/wood_tree_stage0.png", "res://Assets/seed_tree_sprites/wood_tree_stage1.png", "res://Assets/seed_tree_sprites/wood_tree_stage2.png", "res://Assets/seed_tree_sprites/wood_tree_mature.png"]
	},
"leaf_seed": {
		"category": "seed",
		"display_name": "Leaf Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/leaf_seed.png",
		"grows_into": "leaf",
		"order": 4,
		"tree_textures": ["res://Assets/seed_tree_sprites/leaf_tree_stage0.png", "res://Assets/seed_tree_sprites/leaf_tree_stage1.png", "res://Assets/seed_tree_sprites/leaf_tree_stage2.png", "res://Assets/seed_tree_sprites/leaf_tree_mature.png"]
	},
"lava_seed": {
		"category": "seed",
		"display_name": "Lava Seed",
		"rarity": "rare",
		"texture": "res://Assets/seeds/lava_seed.png",
		"grows_into": "lava",
		"order": 5,
		"tree_textures": ["res://Assets/seed_tree_sprites/lava_tree_stage0.png", "res://Assets/seed_tree_sprites/lava_tree_stage1.png", "res://Assets/seed_tree_sprites/lava_tree_stage2.png", "res://Assets/seed_tree_sprites/lava_tree_mature.png"]
	},
"sand_seed": {
		"category": "seed",
		"display_name": "Sand Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/sand_seed.png",
		"grows_into": "sand",
		"order": 6,
		"tree_textures": ["res://Assets/seed_tree_sprites/sand_tree_stage0.png", "res://Assets/seed_tree_sprites/sand_tree_stage1.png", "res://Assets/seed_tree_sprites/sand_tree_stage2.png", "res://Assets/seed_tree_sprites/sand_tree_mature.png"]
	},
"glass_seed": {
		"category": "seed",
		"display_name": "Glass Seed",
		"rarity": "rare",
		"texture": "res://Assets/seeds/glass_seed.png",
		"grows_into": "glass",
		"order": 7,
		"tree_textures": ["res://Assets/seed_tree_sprites/glass_tree_stage0.png", "res://Assets/seed_tree_sprites/glass_tree_stage1.png", "res://Assets/seed_tree_sprites/glass_tree_stage2.png", "res://Assets/seed_tree_sprites/glass_tree_mature.png"]
	},
"ice_block_seed": {
		"category": "seed",
		"display_name": "Ice Block Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "ice_block",
		"order": 8
	},
"cave_background_seed": {
		"category": "seed",
		"display_name": "Cave Background Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/cave_background_seed.png",
		"grows_into": "cave_background",
		"order": 8,
		"tree_textures": ["res://Assets/seed_tree_sprites/cave_tree_stage0.png", "res://Assets/seed_tree_sprites/cave_tree_stage1.png", "res://Assets/seed_tree_sprites/cave_tree_stage2.png", "res://Assets/seed_tree_sprites/cave_tree_mature.png"]
	},
"red_block_seed": {
	"category": "seed",
	"display_name": "Red Block Seed",
	"grows_into": "red_block",
	"order": 9,
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/red_block_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/red_block_tree_stage0.png", "res://Assets/seed_tree_sprites/red_block_tree_stage1.png", "res://Assets/seed_tree_sprites/red_block_tree_stage2.png", "res://Assets/seed_tree_sprites/red_block_tree_mature.png"]
},
"blue_block_seed": {
	"category": "seed",
	"display_name": "Blue Block Seed",
	"grows_into": "blue_block",
	"order": 10,
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/blue_block_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/blue_block_tree_stage0.png", "res://Assets/seed_tree_sprites/blue_block_tree_stage1.png", "res://Assets/seed_tree_sprites/blue_block_tree_stage1.png", "res://Assets/seed_tree_sprites/blue_block_tree_mature.png"]
},
"green_block_seed": {
	"category": "seed",
	"display_name": "Green Block Seed",
	"grows_into": "green_block",
	"order": 11,
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/green_block_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/green_block_tree_stage0.png", "res://Assets/seed_tree_sprites/green_block_tree_stage1.png", "res://Assets/seed_tree_sprites/green_block_tree_stage1.png", "res://Assets/seed_tree_sprites/green_block_tree_mature.png"]
},
"purple_block_seed": {
	"category": "seed",
	"display_name": "Purple Block Seed",
	"grows_into": "purple_block",
	"order": 12,
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/purple_block_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/purple_block_tree_stage0.png", "res://Assets/seed_tree_sprites/purple_block_tree_stage1.png", "res://Assets/seed_tree_sprites/purple_block_tree_stage2.png", "res://Assets/seed_tree_sprites/purple_block_tree_mature.png"]
},
"yellow_block_seed": {
	"category": "seed",
	"display_name": "Yellow Block Seed",
	"grows_into": "yellow_block",
	"order": 13,
	"rarity": "uncommon",
	"texture": "res://Assets/inventory_icons/yellow_block_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/yellow_block_tree_stage0.png", "res://Assets/seed_tree_sprites/yellow_block_tree_stage1.png", "res://Assets/seed_tree_sprites/yellow_block_tree_stage2.png", "res://Assets/seed_tree_sprites/yellow_block_tree_mature.png"]
},
"black_block_seed": {
	"category": "seed",
	"display_name": "Black Block Seed",
	"grows_into": "black_block",
	"order": 14,
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/black_block_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/black_block_tree_stage0.png", "res://Assets/seed_tree_sprites/black_block_tree_stage1.png", "res://Assets/seed_tree_sprites/black_block_tree_stage2.png", "res://Assets/seed_tree_sprites/black_block_tree_mature.png"]
},
"aqua_block_seed": {
	"category": "seed",
	"display_name": "Aqua Block Seed",
	"grows_into": "aqua_block",
	"order": 100,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"blue_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Blue Block Seed",
	"grows_into": "blue_pastel_block",
	"order": 102,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"brown_block_seed": {
	"category": "seed",
	"display_name": "Brown Block Seed",
	"grows_into": "brown_block",
	"order": 103,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_aqua_block_seed": {
	"category": "seed",
	"display_name": "Dark Aqua Block Seed",
	"grows_into": "dark_aqua_block",
	"order": 104,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_blue_block_seed": {
	"category": "seed",
	"display_name": "Dark Blue Block Seed",
	"grows_into": "dark_blue_block",
	"order": 105,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_brown_block_seed": {
	"category": "seed",
	"display_name": "Dark Brown Block Seed",
	"grows_into": "dark_brown_block",
	"order": 106,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_green_block_seed": {
	"category": "seed",
	"display_name": "Dark Green Block Seed",
	"grows_into": "dark_green_block",
	"order": 107,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_pink_block_seed": {
	"category": "seed",
	"display_name": "Dark Pink Block Seed",
	"grows_into": "dark_pink_block",
	"order": 108,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_purple_block_seed": {
	"category": "seed",
	"display_name": "Dark Purple Block Seed",
	"grows_into": "dark_purple_block",
	"order": 109,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_red_block_seed": {
	"category": "seed",
	"display_name": "Dark Red Block Seed",
	"grows_into": "maroon_block",
	"order": 110,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"dark_yellow_block_seed": {
	"category": "seed",
	"display_name": "Dark Yellow Block Seed",
	"grows_into": "dark_yellow_block",
	"order": 111,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"green_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Green Block Seed",
	"grows_into": "green_pastel_block",
	"order": 112,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"grey_block_seed": {
	"category": "seed",
	"display_name": "Grey Block Seed",
	"grows_into": "grey_block",
	"order": 113,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"happy_block_seed": {
	"category": "seed",
	"display_name": "Pastel Bunny Block Seed",
	"grows_into": "happy_block",
	"order": 114,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"light_brown_block_seed": {
	"category": "seed",
	"display_name": "Dark Orange Block Seed",
	"grows_into": "dark_orange_block",
	"order": 115,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"orange_block_seed": {
	"category": "seed",
	"display_name": "Orange Block Seed",
	"grows_into": "orange_block",
	"order": 116,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"orange_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Orange Block Seed",
	"grows_into": "orange_pastel_block",
	"order": 117,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"pastel_flower_block_seed": {
	"category": "seed",
	"display_name": "Pastel Lily Block Seed",
	"grows_into": "pastel_flower_block",
	"order": 118,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"pink_block_seed": {
	"category": "seed",
	"display_name": "Pink Block Seed",
	"grows_into": "pink_block",
	"order": 119,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"pink_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Pink Block Seed",
	"grows_into": "pink_pastel_block",
	"order": 120,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"purple_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Purple Block Seed",
	"grows_into": "purple_pastel_block",
	"order": 121,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"red_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Red Block Seed",
	"grows_into": "red_pastel_block",
	"order": 122,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"white_block_seed": {
	"category": "seed",
	"display_name": "White Block Seed",
	"grows_into": "white_block",
	"order": 123,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"yellow_pastel_block_seed": {
	"category": "seed",
	"display_name": "Pastel Yellow Block Seed",
	"grows_into": "yellow_pastel_block",
	"order": 124,
	"rarity": "uncommon",
	"seed_box_icon": true,
	"texture": "res://Assets/seeds/seed_box.png"
},
"rose_seed": {
		"category": "seed",
		"display_name": "Rose Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/rose_seed.png",
		"inventory_icon": "res://Assets/inventory_icons/rose_seed.png",
		"grows_into": "rose",
		"order": 15,
		"tree_textures": ["res://Assets/seed_tree_sprites/rose_tree_stage0.png", "res://Assets/seed_tree_sprites/rose_tree_stage1.png", "res://Assets/seed_tree_sprites/rose_tree_stage2.png", "res://Assets/seed_tree_sprites/rose_tree_mature.png"]
	},
"tulip_seed": {
		"category": "seed",
		"display_name": "Tulip Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/tulip_seed.png",
		"inventory_icon": "res://Assets/inventory_icons/tulip_seed.png",
		"grows_into": "sunflower",
		"order": 16,
		"tree_textures": ["res://Assets/seed_tree_sprites/tulip_tree_stage0.png", "res://Assets/seed_tree_sprites/tulip_tree_stage1.png", "res://Assets/seed_tree_sprites/tulip_tree_stage2.png", "res://Assets/seed_tree_sprites/tulip_tree_mature.png"]
	},
"vines_seed": {
	"category": "seed",
	"display_name": "Small Vines Seed",
	"grows_into": "hanging_vine",
	"inventory_icon": "res://Assets/inventory_icons/vines_seed.png",
	"order": 17,
	"rarity": "common",
	"texture": "res://Assets/seeds/vines_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/vines_tree_stage0.png", "res://Assets/seed_tree_sprites/vines_tree_stage1.png", "res://Assets/seed_tree_sprites/vines_tree_stage2.png", "res://Assets/seed_tree_sprites/vines_tree_mature.png"]
},
"sugar_cane_seed": {
		"category": "seed",
		"display_name": "Sugarcane Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "sugar_cane",
		"grow_time": 120.0,
		"max_grow_time": 120.0,
		"order": 18
	},
"barn_block_seed": {
		"category": "seed",
		"display_name": "Barn Block Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "barn_block",
		"grow_time": 150.0,
		"max_grow_time": 150.0,
		"order": 19
	},
	"royal_door_seed": {
		"category": "seed",
		"display_name": "House Door Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "royal_door",
		"rarity": "uncommon",
		"grow_time": 175,
		"max_grow_time": 175
	},
	"royal_entrance_seed": {
		"category": "seed",
		"display_name": "House Entrance Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "royal_entrance",
		"rarity": "rare",
		"grow_time": 175,
		"max_grow_time": 175
	},
"lamp_seed": {
		"category": "seed",
		"display_name": "Lamp Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "lamp",
		"grow_time": 150.0,
		"max_grow_time": 150.0,
		"order": 22
	},
	"royal_window_seed": {
		"category": "seed",
		"display_name": "White Window Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "royal_window",
		"rarity": "uncommon",
		"grow_time": 150,
		"max_grow_time": 150
	},
"fish_bowl_seed": {
		"category": "seed",
		"display_name": "Fish Bowl Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "fish_bowl",
		"grow_time": 150.0,
		"max_grow_time": 150.0,
		"order": 24
	},
"tv_seed": {
		"category": "seed",
		"display_name": "TV Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "tv",
		"grow_time": 150.0,
		"max_grow_time": 150.0,
		"order": 25
	},
	"purple_curtains_seed": {
		"category": "seed",
		"display_name": "Purple Curtained Window Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				22,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "purple_curtains",
		"rarity": "uncommon",
		"grow_time": 150,
		"max_grow_time": 150
	},
	"pink_curtains_seed": {
		"category": "seed",
		"display_name": "Pink Curtained Window Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "pink_curtains",
		"rarity": "uncommon",
		"grow_time": 150,
		"max_grow_time": 150
	},
	"blue_couch_seed": {
		"category": "seed",
		"display_name": "Couch Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "blue_couch",
		"rarity": "uncommon",
		"grow_time": 150,
		"max_grow_time": 150
	},
	"green_couch_seed": {
		"category": "seed",
		"display_name": "Potato Couch Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "green_couch",
		"rarity": "uncommon",
		"grow_time": 150,
		"max_grow_time": 150
	},

	# ============================================================
	# SPLICED SEEDS
	# ============================================================
"wood_plank_seed": {
		"category": "seed",
		"display_name": "Wood Plank Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/wood_plank_seed.png",
		"grows_into": "wood_plank",
		"order": 30,
		"tree_textures": ["res://Assets/seed_tree_sprites/wood_plank_tree_stage0.png", "res://Assets/seed_tree_sprites/wood_plank_tree_stage1.png", "res://Assets/seed_tree_sprites/wood_plank_tree_stage2.png", "res://Assets/seed_tree_sprites/wood_plank_tree_mature.png"]
	},
"wood_platform_seed": {
		"category": "seed",
		"display_name": "Wood Platform Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/special/wood_platform_seed.png",
		"grows_into": "wood_platform",
		"order": 31,
		"tree_textures": ["res://Assets/seed_tree_sprites/special/wood_platform_tree_stage0.png", "res://Assets/seed_tree_sprites/special/wood_platform_tree_stage1.png", "res://Assets/seed_tree_sprites/special/wood_platform_tree_stage2.png", "res://Assets/seed_tree_sprites/special/wood_platform_tree_stage3.png"]
	},
"wooden_entrance_seed": {
		"category": "seed",
		"display_name": "Wooden Entrance Seed",
		"rarity": "rare",
		"texture": "res://Assets/inventory_icons/wooden_entrance.png",
		"grows_into": "wooden_entrance",
		"order": 32,
		"tree_textures": ["res://Assets/blocks/Tier_1/wooden/wooden_entrance_1.png", "res://Assets/blocks/Tier_1/wooden/wooden_entrance_2.png", "res://Assets/blocks/Tier_1/wooden/wooden_entrance_3.png"]
	},
"sign_seed": {
		"category": "seed",
		"display_name": "Sign Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/special/sign_seed.png",
		"grows_into": "sign",
		"order": 33,
		"tree_textures": ["res://Assets/seed_tree_sprites/special/sign_tree_stage0.png", "res://Assets/seed_tree_sprites/special/sign_tree_stage1.png", "res://Assets/seed_tree_sprites/special/sign_tree_stage2.png", "res://Assets/seed_tree_sprites/special/sign_tree_stage3.png"]
	},
"stone_brick_seed": {
	"category": "seed",
	"display_name": "Stone Brick Seed",
	"grows_into": "stone_brick",
	"order": 34,
	"rarity": "uncommon",
	"texture": "res://Assets/seeds/special/stone_brick_seed.png",
	"tree_textures": ["res://Assets/seed_tree_sprites/special/stone_brick_tree_stage0.png", "res://Assets/seed_tree_sprites/special/stone_brick_tree_stage1.png", "res://Assets/seed_tree_sprites/special/stone_brick_tree_stage2.png", "res://Assets/seed_tree_sprites/special/stone_brick_tree_stage3.png"]
},
"glass_panel_seed": {
		"category": "seed",
		"display_name": "Glass Panel Seed",
		"rarity": "rare",
		"texture": "res://Assets/seeds/special/glass_panel_seed.png",
		"grows_into": "glass_panel",
		"order": 35,
		"tree_textures": ["res://Assets/seed_tree_sprites/special/glass_panel_tree_stage0.png", "res://Assets/seed_tree_sprites/special/glass_panel_tree_stage1.png", "res://Assets/seed_tree_sprites/special/glass_panel_tree_stage2.png", "res://Assets/seed_tree_sprites/special/glass_panel_tree_stage3.png"]
	},
"gem_block_seed": {
		"category": "seed",
		"display_name": "Gem Block Seed",
		"rarity": "epic",
		"texture": "res://Assets/seeds/special/gem_block_seed.png",
		"grows_into": "rainbow_block",
		"order": 36,
		"tree_textures": ["res://Assets/seed_tree_sprites/special/gem_block_tree_stage0.png", "res://Assets/seed_tree_sprites/special/gem_block_tree_stage1.png", "res://Assets/seed_tree_sprites/special/gem_block_tree_stage2.png", "res://Assets/seed_tree_sprites/special/gem_block_tree_stage3.png"]
	},
"wooden_block_seed": {
		"category": "seed",
		"display_name": "Wooden Block Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "wooden_block",
		"grow_time": 125.0,
		"max_grow_time": 125.0,
		"order": 37
	},
"wooden_background_seed": {
		"category": "seed",
		"display_name": "Wooden Background Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "wooden_wallpaper",
		"grow_time": 135.0,
		"max_grow_time": 135.0,
		"order": 38
	},
"wooden_fence_seed": {
		"category": "seed",
		"display_name": "Wooden Fence Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "wooden_fence",
		"grow_time": 150.0,
		"max_grow_time": 150.0,
		"order": 39
	},
"wooden_ladder_seed": {
		"category": "seed",
		"display_name": "Wooden Ladder Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "wooden_ladder",
		"grow_time": 160.0,
		"max_grow_time": 160.0,
		"order": 40
	},
"wooden_door_seed": {
		"category": "seed",
		"display_name": "Wooden Door Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "wooden_door",
		"grow_time": 175.0,
		"max_grow_time": 175.0,
		"order": 41
	},
"wooden_frame_seed": {
		"category": "seed",
		"display_name": "Wooden Frame Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "wooden_window",
		"grow_time": 190.0,
		"max_grow_time": 190.0,
		"order": 42
	},
"mushroom_seed": {
		"category": "seed",
		"display_name": "Mushroom Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/seed_box.png",
		"seed_box_icon": true,
		"grows_into": "mushroom",
		"grow_time": 205.0,
		"max_grow_time": 205.0,
		"order": 43
	},

	# ============================================================
	# CURRENCY
	# ============================================================
"gem": {
		"category": "currency",
		"display_name": "Gem",
		"rarity": "currency",
		"texture": "res://Assets/currency/gem.png",
		"inventory_property": "currency_inventory",
		"cap": 100000000000,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": true,
		"hidden": true,
		"order": 0
	},

	# ============================================================
	# MATERIALS
	# ============================================================
"refined_stone": {
		"category": "material",
		"display_name": "Refined Stone",
		"rarity": "uncommon",
		"texture": "res://Assets/items/materials/refined_stone.png",
		"order": 100
	},
"refined_glass": {
		"category": "material",
		"display_name": "Refined Glass",
		"rarity": "rare",
		"texture": "res://Assets/items/materials/refined_glass.png",
		"order": 101
	},
"metal_scrap": {
		"category": "material",
		"display_name": "Metal Scrap",
		"rarity": "rare",
		"texture": "res://Assets/items/materials/metal_scrap.png",
		"order": 102
	},
"crude_oil": {
		"category": "material",
		"display_name": "Crude Oil",
		"rarity": "uncommon",
		"texture": "res://Assets/blocks/special_blocks/oil_refinery/crude_oil.png",
		"inventory_icon": "res://Assets/blocks/special_blocks/oil_refinery/crude_oil.png",
		"order": 103
	},
"battery": {
		"category": "material",
		"display_name": "Battery",
		"rarity": "uncommon",
		"texture": "res://Assets/blocks/electric/battery.png",
		"inventory_icon": "res://Assets/blocks/electric/battery.png",
		"order": 104
	},
"grain": {
		"category": "material",
		"display_name": "Grain",
		"rarity": "common",
		"texture": "res://Assets/items/materials/grain.png",
		"inventory_icon": "res://Assets/items/materials/grain.png",
		"order": 105
	},
"egg": {
		"category": "material",
		"display_name": "Egg",
		"rarity": "common",
		"texture": "res://Assets/items/materials/egg.png",
		"inventory_icon": "res://Assets/items/materials/egg.png",
		"order": 106
	},
"golden_egg": {
		"category": "material",
		"display_name": "Golden Egg",
		"rarity": "legendary",
		"texture": "res://Assets/items/materials/golden_egg.png",
		"inventory_icon": "res://Assets/items/materials/golden_egg.png",
		"order": 106
	},
"wheat": {
		"category": "material",
		"display_name": "Wheat",
		"rarity": "common",
		"texture": "res://Assets/items/materials/wheat.png",
		"inventory_icon": "res://Assets/items/materials/wheat.png",
		"order": 107
	},
"milk": {
		"category": "material",
		"display_name": "Milk",
		"rarity": "common",
		"texture": "res://Assets/items/materials/milk.png",
		"inventory_icon": "res://Assets/items/materials/milk.png",
		"order": 108
	},
"seaweed": {
		"category": "material",
		"display_name": "Seaweed",
		"rarity": "common",
		"texture": "res://Assets/items/materials/seaweed.png",
		"inventory_icon": "res://Assets/items/materials/seaweed.png",
		"fishing_material": true,
		"order": 105
	},
"trash_can": {
		"category": "material",
		"display_name": "Trash Can",
		"rarity": "common",
		"texture": "res://Assets/items/materials/trash_can.png",
		"inventory_icon": "res://Assets/items/materials/trash_can.png",
		"fishing_material": true,
		"order": 106
	},
"coral": {
		"category": "material",
		"display_name": "Coral",
		"rarity": "uncommon",
		"texture": "res://Assets/items/materials/coral.png",
		"inventory_icon": "res://Assets/items/materials/coral.png",
		"fishing_material": true,
		"order": 107
	},
"clam": {
		"category": "material",
		"display_name": "Clam",
		"rarity": "uncommon",
		"texture": "res://Assets/items/materials/clam.png",
		"inventory_icon": "res://Assets/items/materials/clam.png",
		"fishing_material": true,
		"order": 108
	},
"compass": {
		"category": "material",
		"display_name": "Compass",
		"rarity": "rare",
		"texture": "res://Assets/items/materials/compass.png",
		"inventory_icon": "res://Assets/items/materials/compass.png",
		"fishing_material": true,
		"order": 109
	},
"pearl": {
		"category": "material",
		"display_name": "Pearl",
		"rarity": "rare",
		"texture": "res://Assets/items/materials/pearl.png",
		"inventory_icon": "res://Assets/items/materials/pearl.png",
		"fishing_material": true,
		"order": 110
	},
"rusty_bicycle": {
		"category": "material",
		"display_name": "Rusty Bicycle",
		"rarity": "rare",
		"texture": "res://Assets/items/materials/rusty_bicycle.png",
		"inventory_icon": "res://Assets/items/materials/rusty_bicycle.png",
		"fishing_material": true,
		"order": 111
	},
"lost_chapter": {
		"category": "material",
		"display_name": "Lost Chapter",
		"rarity": "epic",
		"texture": "res://Assets/items/materials/lost_chapter.png",
		"inventory_icon": "res://Assets/items/materials/lost_chapter.png",
		"fishing_material": true,
		"order": 112
	},
"topaz_necklace": {
		"category": "material",
		"display_name": "Topaz Necklace",
		"rarity": "epic",
		"texture": "res://Assets/items/materials/topaz_necklace.png",
		"inventory_icon": "res://Assets/items/materials/topaz_necklace.png",
		"fishing_material": true,
		"order": 113
	},
"toxic_waste": {
		"category": "material",
		"display_name": "Toxic Waste",
		"rarity": "epic",
		"texture": "res://Assets/items/materials/toxic_waste.png",
		"inventory_icon": "res://Assets/items/materials/toxic_waste.png",
		"fishing_material": true,
		"order": 114
	},
"naval_mines": {
		"category": "material",
		"display_name": "Naval Mines",
		"rarity": "epic",
		"texture": "res://Assets/items/materials/naval_mines.png",
		"inventory_icon": "res://Assets/items/materials/naval_mines.png",
		"fishing_material": true,
		"order": 115
	},
"basic_items_pack": {
		"category": "material",
		"display_name": "Basic Items Pack",
		"rarity": "common",
		"texture": "messy_brown_hair_icon",
		"starting_count": 0,
		"shop_pack": true,
		"pack_rewards": BASIC_ITEMS_PACK_REWARDS,
		"hidden": true,
		"tradeable": false,
		"dropable": false,
		"order": 103
	},
"prestige_coloured_block_pack": {
		"category": "material",
		"display_name": "Prestige Coloured Block Pack",
		"rarity": "epic",
		"texture": "res://Assets/blocks/prestige_coloured_blocks/ps_purple_block.png",
		"inventory_icon": "res://Assets/blocks/prestige_coloured_blocks/ps_purple_block.png",
		"starting_count": 0,
		"shop_pack": true,
		"pack_rewards": PRESTIGE_COLOURED_BLOCK_PACK_REWARDS,
		"hidden": true,
		"tradeable": false,
		"dropable": false,
		"order": 104
	},

	# ============================================================
	# BACK ITEMS / EQUIPMENT
	# ============================================================
"legendary_wings": {
		"category": "back",
		"display_name": "Legendary Wings",
		"rarity": "legendary",
		"texture": "res://Assets/player/back_item/legendary_wings/legendary_wings_idle1.png",
		"starting_count": 0,
		"equipable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"sprite_folder": "res://Assets/player/back_item/legendary_wings/",
		"idle_sprite": "legendary_wings_idle1.png",
		"idle_frames": ["legendary_wings_idle1.png", "legendary_wings_idle2.png"],
		"flap_frames": ["legendary_wings_jump1.png", "legendary_wings_jump2.png", "legendary_wings_jump3.png"],
		"flap_frame_durations": [1.0, 1.0, 1.0],
		"flap_animation": true,
		"flap_animation_loop": false,
		"flap_pose_hold_time": 0.75,
		"scan_flap_frames": false,
		"flap_speed": 0.32,
		"input_flap_time": 0.28,
		"animation_fps": 2.0,

		"jump_type": "infinite",

		"auto_scale_back_sprite": true,
		"back_target_width": 96,
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		# Position is handled by BackSocket in the editor.
		# These pivot offsets adjust the snapping point for this specific wing artwork.
		"back_pivot_offset": [-2, 15],
		"back_pivot_offset_left": [-2, 15],
		"flap_pivot_offset": [0, 5],
		"flap_pivot_offset_left": [0, 5],
		"back_fx_scene": "res://Scenes/particles/WingPearlParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 200
	},
"evilangel_wings": {
		"category": "back",
		"display_name": "Evil Angel Wings",
		"rarity": "legendary",
		"texture": "res://Assets/items/back_items/evilangel_wings.png",
		"inventory_icon": "res://Assets/inventory_icons/evilangel_wings.png",
		"starting_count": 0,
		"equipable": true,
		"tradeable": false,
		"dropable": false,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"sprite_folder": "res://Assets/items/back_items/",
		"idle_sprite": "evilangel_wings.png",
		"idle_frames": ["evilangel_wings.png", "evilangel_wings_2.png"],
		"flap_frames": ["evilangel_wings_jump_1.png", "evilangel_wings_jump_2.png", "evilangel_wings_jump_3.png"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.30,
		"input_flap_time": 0.28,
		"animation_fps": 3.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingDualSparkleParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 201
	},
"angel_wings": {
		"category": "back",
		"display_name": "Angel Wings",
		"rarity": "legendary",
		"texture": "angel_wings_1",
		"inventory_icon": "angel_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["angel_wings_1", "angel_wings_2", "angel_wings_3"],
		"jump_frames": ["angel_wings_2", "angel_wings_4", "angel_wings_1"],
		"fall_frames": ["angel_wings_3", "angel_wings_5", "angel_wings_1"],
		"flap_frames": ["angel_wings_1", "angel_wings_4", "angel_wings_2"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.30,
		"input_flap_time": 0.28,
		"animation_fps": 3.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingSparkleParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 202
	},
"golden_angel_wings": {
		"category": "back",
		"display_name": "Golden Angel Wings",
		"rarity": "legendary",
		"texture": "golden_angel_wings_1",
		"inventory_icon": "golden_angel_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["golden_angel_wings_1", "golden_angel_wings_2", "golden_angel_wings_3"],
		"jump_frames": ["golden_angel_wings_2", "golden_angel_wings_4", "golden_angel_wings_1"],
		"fall_frames": ["golden_angel_wings_3", "golden_angel_wings_5", "golden_angel_wings_1"],
		"flap_frames": ["golden_angel_wings_1", "golden_angel_wings_4", "golden_angel_wings_2"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.30,
		"input_flap_time": 0.28,
		"animation_fps": 3.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingSparkleParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 211
	},
"evil_wings": {
		"category": "back",
		"display_name": "Evil Wings",
		"rarity": "legendary",
		"texture": "res://Assets/items/back_items/evil_wings_1.png",
		"inventory_icon": "res://Assets/items/back_items/evil_wings_1.png",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"sprite_folder": "res://Assets/items/back_items/",
		"idle_sprite": "evil_wings_1.png",
		"idle_frames": ["evil_wings_1.png", "evil_wings_2.png"],
		"flap_frames": ["evil_wings_jump1.png", "evil_wings_jump2.png"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.30,
		"input_flap_time": 0.28,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 203
	},
"devil_wings": {
		"category": "back",
		"display_name": "Devil Wings",
		"rarity": "legendary",
		"texture": "devil_wings_1",
		"inventory_icon": "devil_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["devil_wings_1", "devil_wings_2", "devil_wings_3"],
		"jump_frames": ["devil_wings_2", "devil_wings_4", "devil_wings_1"],
		"fall_frames": ["devil_wings_3", "devil_wings_5", "devil_wings_1"],
		"flap_frames": ["devil_wings_1", "devil_wings_4", "devil_wings_2"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,
		"animation_fps": 6.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
		},
"appreciation_wings": {
		"category": "back",
		"display_name": "Appreciation Wings",
		"rarity": "legendary",
		"texture": "appreciation_wings_1",
		"inventory_icon": "appreciation_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": false,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["appreciation_wings_1", "appreciation_wings_2", "appreciation_wings_3"],
		"jump_frames": ["appreciation_wings_2", "appreciation_wings_4", "appreciation_wings_1"],
		"fall_frames": ["appreciation_wings_3", "appreciation_wings_5", "appreciation_wings_1"],
		"flap_frames": ["appreciation_wings_2", "appreciation_wings_4", "appreciation_wings_1"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,
		"animation_fps": 6.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
	},
	"parrot_wings": {
		"category": "back",
		"display_name": "Parrot Wings",
		"rarity": "legendary",
		"texture": "parrot_wings_1",
		"inventory_icon": "parrot_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["parrot_wings_1", "parrot_wings_2", "parrot_wings_3"],
		"jump_frames": ["parrot_wings_2", "parrot_wings_4", "parrot_wings_1"],
		"fall_frames": ["parrot_wings_2", "parrot_wings_4", "parrot_wings_1"],
		"flap_frames": ["parrot_wings_2", "parrot_wings_4", "parrot_wings_1"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,
		"animation_fps": 6.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
	},
	"dragon_rusty_wings": {
		"category": "back",
		"display_name": "Dragon Rusty Wings",
		"rarity": "legendary",
		"texture": "dragon_rusty_wings_1",
		"inventory_icon": "dragon_rusty_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["dragon_rusty_wings_1", "dragon_rusty_wings_2", "dragon_rusty_wings_3"],
		"jump_frames": ["dragon_rusty_wings_2", "dragon_rusty_wings_4", "dragon_rusty_wings_1"],
		"fall_frames": ["dragon_rusty_wings_3", "dragon_rusty_wings_5", "dragon_rusty_wings_1"],
		"flap_frames": ["dragon_rusty_wings_2", "dragon_rusty_wings_4", "dragon_rusty_wings_1"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,
		"animation_fps": 6.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
	},
	"carboard_wings": {
		"category": "back",
		"display_name": "Carboard Wings",
		"rarity": "legendary",
		"texture": "carboard_wings_1",
		"inventory_icon": "carboard_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["carboard_wings_1", "carboard_wings_2", "carboard_wings_3"],
		"jump_frames": ["carboard_wings_1", "carboard_wings_2", "carboard_wings_3"],
		"fall_frames": ["carboard_wings_1", "carboard_wings_2", "carboard_wings_3"],
		"flap_frames": ["carboard_wings_1", "carboard_wings_2", "carboard_wings_3"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,
		"animation_fps": 6.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
	},
	"spiky_wings": {
		"category": "back",
		"display_name": "Spiky Wings",
		"rarity": "legendary",
		"texture": "spiky_wings_1",
		"inventory_icon": "spiky_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["spiky_wings_1", "spiky_wings_2", "spiky_wings_3"],
		"jump_frames": ["spiky_wings_2", "spiky_wings_4", "spiky_wings_1"],
		"fall_frames": ["spiky_wings_2", "spiky_wings_4", "spiky_wings_1"],
		"flap_frames": ["spiky_wings_2", "spiky_wings_4", "spiky_wings_1"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,
		"animation_fps": 6.0,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
	},
	"void_aura": {
		"category": "back",
		"display_name": "Void Aura",
		"rarity": "legendary",
		"texture": "void_aura_1",
		"inventory_icon": "void_aura_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["void_aura_1", "void_aura_2", "void_aura_3", "void_aura_4"],
		"flap_frames": ["void_aura_1", "void_aura_2", "void_aura_3", "void_aura_4"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"animation_fps": 6.0,
		"flap_speed": 0.1667,
		"input_flap_time": 0.28,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,

		"order": 204
	},
"susanoo_wings": {
		"category": "back",
		"display_name": "Susanoo Wings",
		"rarity": "legendary",
		"texture": "res://Assets/items/back_items/susanoo_idle_1.png",
		"inventory_icon": "res://Assets/items/back_items/susanoo_idle_1.png",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"sprite_folder": "res://Assets/items/back_items/",
		"idle_sprite": "susanoo_idle_1.png",
		"idle_frames": ["susanoo_idle_1.png", "susanoo_idle_2.png"],
		"flap_frames": ["susanoo_jump.png"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"animation_fps": 3.0,
		"flap_speed": 0.30,
		"input_flap_time": 0.28,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingPurpleStardustParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 205
	},
"dragon_fire_wings": {
		"category": "back",
		"display_name": "Dragon Fire Wings",
		"rarity": "legendary",
		"texture": "dragon_fire_wings_1",
		"inventory_icon": "dragon_fire_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["dragon_fire_wings_1", "dragon_fire_wings_2", "dragon_fire_wings_3"],
		"jump_frames": ["dragon_fire_wings_2", "dragon_fire_wings_4", "dragon_fire_wings_1"],
		"fall_frames": ["dragon_fire_wings_3", "dragon_fire_wings_5", "dragon_fire_wings_1"],
		"flap_frames": ["dragon_fire_wings_1", "dragon_fire_wings_4", "dragon_fire_wings_2"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"animation_fps": 3.0,
		"flap_speed": 0.24,
		"input_flap_time": 0.28,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingSparkleParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 206
	},
"lucifer_wings": {
		"category": "back",
		"display_name": "Lucifer Wings",
		"rarity": "legendary",
		"texture": "res://Assets/items/back_items/lucifer_wings_idle_1.png",
		"inventory_icon": "res://Assets/items/back_items/lucifer_wings_icon.png",
		"starting_count": 0,
		"equipable": true,
		"tradeable": false,
		"vendable": false,
		"dropable": false,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"sprite_folder": "res://Assets/items/back_items/",
		"idle_sprite": "lucifer_wings_idle_1.png",
		"idle_frames": ["lucifer_wings_idle_1.png", "lucifer_wings_idle_2.png"],
		"flap_frames": ["lucifer_wings_jump_1.png", "lucifer_wings_jump_2.png", "lucifer_wings_jump_3.png"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"animation_fps": 3.0,
		"flap_speed": 0.24,
		"input_flap_time": 0.28,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingSparkleParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 207
	},
"phoenix_wings": {
		"category": "back",
		"display_name": "Phoenix Wings",
		"rarity": "legendary",
		"texture": "phoenix_wings_1",
		"inventory_icon": "phoenix_wings_icon",
		"starting_count": 0,
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"idle_frames": ["phoenix_wings_1", "phoenix_wings_2", "phoenix_wings_3"],
		"jump_frames": ["phoenix_wings_2", "phoenix_wings_4", "phoenix_wings_1"],
		"fall_frames": ["phoenix_wings_3", "phoenix_wings_5", "phoenix_wings_1"],
		"flap_frames": ["phoenix_wings_1", "phoenix_wings_4", "phoenix_wings_2"],
		"flap_animation": true,
		"scan_flap_frames": false,
		"animation_fps": 6.0,
		"flap_speed": 0.15,
		"input_flap_time": 0.28,

		"jump_type": "double",

		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"back_fx_scene": "res://Scenes/particles/WingSparkleParticlesFX.tscn",
		"back_fx_offset": [0, 8],
		"back_fx_scale": [1.0, 1.0],
		"back_fx_z_index": 72,

		"order": 208
	},
	"green_jetpack": {
		"category": "back",
		"display_name": "Green Jetpack",
		"rarity": "legendary",
		"texture": "green_jetpack_1",
		"inventory_icon": "green_jetpack_icon",
		"starting_count": 0,
		"equipable": true,
		"instance_tracked": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,
		"equipment_slot": "back",
		"back_mode": "default_slot",
		"flap_frames": ["green_jetpack_1", "green_jetpack_2", "green_jetpack_3", "green_jetpack_4"],
		"flap_animation": true,
		"flap_animation_loop": true,
		"flap_pose_hold_time": 0.0,
		"scan_flap_frames": false,
		"flap_speed": 0.14,
		"input_flap_time": 0.28,
		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"order": 209
	},

"blue_jetpack": {
		"category": "back",
		"display_name": "Blue Jetpack",
		"rarity": "legendary",
		"texture": "blue_jetpack_1",
		"inventory_icon": "blue_jetpack_icon",
		"starting_count": 0,
		"equipable": true,
		"instance_tracked": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,
		"equipment_slot": "back",
		"back_mode": "default_slot",
		"flap_frames": ["blue_jetpack_1", "blue_jetpack_2", "blue_jetpack_3", "blue_jetpack_4"],
		"flap_animation": true,
		"flap_animation_loop": true,
		"flap_pose_hold_time": 0.0,
		"scan_flap_frames": false,
		"flap_speed": 0.14,
		"input_flap_time": 0.28,
		"jump_type": "double",
		"auto_scale_back_sprite": false,
		"back_scale": 1.0,
		"idle_sprite_offset": [0, 0],
		"idle_sprite_offset_left": [0, 0],
		"flap_sprite_offset": [0, 0],
		"flap_sprite_offset_left": [0, 0],
		"back_scale_multiplier": 1.0,
		"back_flip_with_facing": false,
		"order": 210
	},

"neptune_crown": {
		"category": "hat",
		"display_name": "Neptune Crown",
		"rarity": "legendary",
		"texture": "neptune_crown",
		"inventory_icon": "neptune_crown_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"tradeable": true,
		"vendable": true,
		"dropable": true,
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 208
	},

"royal_crown": {
		"category": "hat",
		"display_name": "Royal Crown",
		"rarity": "legendary",
		"texture": "royal_crown",
		"inventory_icon": "royal_crown_preview",
		"starting_count": 0,
		"instance_tracked": true,
		"equipment_slot": "hat",
		"equipable": true,
		"tradeable": true,
		"vendable": true,
		"dropable": true,
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 209
	},

"blue_baseball_cap": {
		"category": "hat",
		"display_name": "Blue Baseball Cap",
		"rarity": "common",
		"texture": "blue_baseball_cap",
		"inventory_icon": "blue_baseball_cap_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 209
	},

"green_baseball_cap": {
		"category": "hat",
		"display_name": "Green Baseball Cap",
		"rarity": "common",
		"texture": "green_baseball_cap",
		"inventory_icon": "green_baseball_cap_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 210
	},

"red_baseball_cap": {
		"category": "hat",
		"display_name": "Red Baseball Cap",
		"rarity": "common",
		"texture": "red_baseball_cap",
		"inventory_icon": "red_baseball_cap_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 211
	},

	"straw_hat": {
		"category": "hat",
		"display_name": "Straw Hat",
		"rarity": "common",
		"texture": "straw_hat",
		"inventory_icon": "straw_hat_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 440
	},

	"yellow_cap": {
		"category": "hat",
		"display_name": "Yellow Cap",
		"rarity": "common",
		"texture": "yellow_cap",
		"inventory_icon": "yellow_cap_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 441
	},

	"white_cap": {
		"category": "hat",
		"display_name": "White Cap",
		"rarity": "common",
		"texture": "white_cap",
		"inventory_icon": "white_cap_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 442
	},

	"red_headband": {
		"category": "hat",
		"display_name": "Red Headband",
		"rarity": "common",
		"texture": "red_headband",
		"inventory_icon": "red_headband_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 443
	},

	"chefs_hat": {
		"category": "hat",
		"display_name": "Chef's Hat",
		"rarity": "common",
		"texture": "chefs_hat",
		"inventory_icon": "chefs_hat_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 444
	},

	"cowboy_hat": {
		"category": "hat",
		"display_name": "Cowboy Hat",
		"rarity": "common",
		"texture": "cowboy_hat",
		"inventory_icon": "cowboy_hat_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 445
	},

	"top_hat": {
		"category": "hat",
		"display_name": "Top Hat",
		"rarity": "common",
		"texture": "top_hat",
		"inventory_icon": "top_hat_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 446
	},

	"black_fedora": {
		"category": "hat",
		"display_name": "Black Fedora",
		"rarity": "common",
		"texture": "black_fedora",
		"inventory_icon": "black_fedora_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hat",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 447
	},

"messy_brown_hair": {
		"category": "hair",
		"display_name": "Messy Brown Hair",
		"rarity": "common",
		"texture": "messy_brown_hair",
		"inventory_icon": "messy_brown_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"black_slick_hair": {
		"category": "hair",
		"display_name": "Black Slick Hair",
		"rarity": "common",
		"texture": "black_slick_hair",
		"inventory_icon": "black_slick_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"black_combed_hair": {
		"category": "hair",
		"display_name": "Black Combed Hair",
		"rarity": "common",
		"texture": "black_combed_hair",
		"inventory_icon": "black_combed_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"frosty_hair": {
		"category": "hair",
		"display_name": "Frosty Hair",
		"rarity": "common",
		"texture": "frosty_hair_1",
		"inventory_icon": "frosty_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"animation_fps": 5.0,
		"hair_animations": {
			"idle": {
				"frames": ["frosty_hair_1", "frosty_hair_2", "frosty_hair_3", "frosty_hair_4"],
				"fps": 5.0,
				"loop": true
			}
		},
		"order": 204
	},

	"flaming_hair": {
		"category": "hair",
		"display_name": "Flaming Hair",
		"rarity": "common",
		"texture": "flaming_hair_1",
		"inventory_icon": "flaming_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"animation_fps": 5.0,
		"hair_animations": {
			"idle": {
				"frames": ["flaming_hair_1", "flaming_hair_2", "flaming_hair_3", "flaming_hair_4"],
				"fps": 5.0,
				"loop": true
			}
		},
		"order": 204
	},

	"old_men_hair": {
		"category": "hair",
		"display_name": "Old Men Hair",
		"rarity": "common",
		"texture": "old_men_hair",
		"inventory_icon": "old_men_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"brown_fringe": {
		"category": "hair",
		"display_name": "Brown Fringe",
		"rarity": "common",
		"texture": "brown_fringe",
		"inventory_icon": "brown_fringe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"brown_combed_hair": {
		"category": "hair",
		"display_name": "Brown Combed Hair",
		"rarity": "common",
		"texture": "brown_combed_hair",
		"inventory_icon": "brown_combed_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"blonde_hair": {
		"category": "hair",
		"display_name": "Blonde Hair",
		"rarity": "common",
		"texture": "blonde_hair",
		"inventory_icon": "blonde_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"brunette_hair": {
		"category": "hair",
		"display_name": "Brunette Hair",
		"rarity": "common",
		"texture": "brunette_hair",
		"inventory_icon": "brunette_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"crazy_hair": {
		"category": "hair",
		"display_name": "Crazy Hair",
		"rarity": "common",
		"texture": "crazy_hair",
		"inventory_icon": "crazy_hair_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 204
	},

	"hairpack": {
		"category": "material",
		"display_name": "Hair Pack",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/black_afro.png",
		"inventory_icon": "res://Assets/clothes/hair/black_afro_icon.png",
		"starting_count": 0,
		"shop_pack": true,
		"pack_rewards": HAIR_PACK_REWARDS,
		"hidden": true,
		"tradeable": false,
		"dropable": false,
		"order": 105
	},

	"black_afro": {
		"category": "hair",
		"display_name": "Black Afro",
		"rarity": "common",
		"texture": "black_afro",
		"inventory_icon": "black_afro_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 205
	},

	"blonde_afro": {
		"category": "hair",
		"display_name": "Blonde Afro",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/blonde_afro.png",
		"inventory_icon": "res://Assets/clothes/hair/blonde_afro_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 206
	},

	"brown_afro": {
		"category": "hair",
		"display_name": "Brown Afro",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/brown_afro.png",
		"inventory_icon": "res://Assets/clothes/hair/brown_afro_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 207
	},

	"pink_afro": {
		"category": "hair",
		"display_name": "Pink Afro",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/pink_afro.png",
		"inventory_icon": "res://Assets/clothes/hair/pink_afro_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 208
	},

	"red_afro": {
		"category": "hair",
		"display_name": "Red Afro",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/red_afro.png",
		"inventory_icon": "res://Assets/clothes/hair/red_afro_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 209
	},

	"short_black_hair": {
		"category": "hair",
		"display_name": "Short Black Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/short_black_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/short_black_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 210
	},

	"short_blonde_hair": {
		"category": "hair",
		"display_name": "Short Blonde Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/short_blonde_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/short_blonde_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 211
	},

	"short_bron_hair": {
		"category": "hair",
		"display_name": "Short Brown Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/short_bron_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/short_bron_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 212
	},

	"short_pink_hair": {
		"category": "hair",
		"display_name": "Short Pink Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/short_pink_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/short_pink_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 213
	},

	"short_red_hair": {
		"category": "hair",
		"display_name": "Short Red Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/short_red_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/short_red_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 214
	},

	"long_black_hair": {
		"category": "hair",
		"display_name": "Long Black Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/long_black_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/long_black_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 215
	},

	"long_blonde_hair": {
		"category": "hair",
		"display_name": "Long Blonde Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/long_blonde_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/long_blonde_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 216
	},

	"long_grey_hair": {
		"category": "hair",
		"display_name": "Long Grey Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/long_grey_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/long_grey_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 217
	},

	"long_pink_hair": {
		"category": "hair",
		"display_name": "Long Pink Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/long_pink_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/long_pink_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 218
	},

	"long_red_hair": {
		"category": "hair",
		"display_name": "Long Red Hair",
		"rarity": "common",
		"texture": "res://Assets/clothes/hair/long_red_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/long_red_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 219
	},

	"baby_hair": {
		"category": "hair",
		"display_name": "Baby Hair",
		"rarity": "legendary",
		"texture": "res://Assets/clothes/hair/baby_hair.png",
		"inventory_icon": "res://Assets/clothes/hair/baby_hair_icon.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hair",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"instance_tracked": true,
		"order": 220
	},

	"void_visor": {
		"category": "eyewear",
		"display_name": "Void Visor",
		"rarity": "common",
		"texture": "res://Assets/clothes/eye_ware/void_visor_1.png",
		"inventory_icon": "res://Assets/clothes/eye_ware/void_visor_1.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"animation_fps": 6.0,
		"eyewear_animations": {
			"idle": {
				"frames": ["res://Assets/clothes/eye_ware/void_visor_1.png", "res://Assets/clothes/eye_ware/void_visor_2.png", "res://Assets/clothes/eye_ware/void_visor_3.png", "res://Assets/clothes/eye_ware/void_visor_4.png", "res://Assets/clothes/eye_ware/void_visor_3.png", "res://Assets/clothes/eye_ware/void_visor_2.png", "res://Assets/clothes/eye_ware/void_visor_1.png"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 205
	},

	"electric_goggles": {
		"category": "eyewear",
		"display_name": "Orange Shutters",
		"rarity": "rare",
		"texture": "orange_shutters",
		"inventory_icon": "orange_shutters_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 206
	},

	"sunglasses": {
		"category": "eyewear",
		"display_name": "Sunglasses",
		"rarity": "common",
		"texture": "sunglasses",
		"inventory_icon": "sunglasses_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 448
	},

	"black_beard": {
		"category": "beard",
		"display_name": "Black Beard",
		"rarity": "common",
		"texture": "black_beard",
		"inventory_icon": "black_beard_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "beard",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 449
	},

	"brown_beard": {
		"category": "beard",
		"display_name": "Brown Beard",
		"rarity": "common",
		"texture": "brown_beard",
		"inventory_icon": "brown_beard_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "beard",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 450
	},

	"reading_glasses": {
		"category": "eyewear",
		"display_name": "Reading Glasses",
		"rarity": "common",
		"texture": "reading_glasses",
		"inventory_icon": "reading_glasses_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 451
	},

	"pink_shutters": {
		"category": "eyewear",
		"display_name": "Pink Shutters",
		"rarity": "common",
		"texture": "pink_shutters",
		"inventory_icon": "pink_shutters_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 452
	},

	"yellow_shades": {
		"category": "eyewear",
		"display_name": "Yellow Shades",
		"rarity": "common",
		"texture": "yellow_shades",
		"inventory_icon": "yellow_shades_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 453
	},

	"blue_shades": {
		"category": "eyewear",
		"display_name": "Blue Shades",
		"rarity": "common",
		"texture": "blue_shades",
		"inventory_icon": "blue_shades_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 454
	},

	"pink_shades": {
		"category": "eyewear",
		"display_name": "Pink Shades",
		"rarity": "common",
		"texture": "pink_shades",
		"inventory_icon": "pink_shades_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"order": 455
	},

	"straw": {
		"category": "eyewear",
		"display_name": "Straw",
		"rarity": "common",
		"texture": "straw_1",
		"inventory_icon": "straw_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"animation_fps": 6.0,
		"eyewear_animations": {
			"idle": {
				"frames": ["straw_1", "straw_2", "straw_3", "straw_2", "straw_1"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 456
	},

	"green_teashades": {
		"category": "eyewear",
		"display_name": "Green Teashades",
		"rarity": "common",
		"texture": "green_teashades_1",
		"inventory_icon": "green_teashades_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"animation_fps": 6.0,
		"eyewear_animations": {
			"idle": {
				"frames": ["green_teashades_1", "green_teashades_2", "green_teashades_3", "green_teashades_2", "green_teashades_1"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 457
	},

	"orange_teashades": {
		"category": "eyewear",
		"display_name": "Orange Teashades",
		"rarity": "common",
		"texture": "orange_teashades_1",
		"inventory_icon": "orange_teashades_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "eyewear",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 3,
		"animation_fps": 6.0,
		"eyewear_animations": {
			"idle": {
				"frames": ["orange_teashades_1", "orange_teashades_2", "orange_teashades_3", "orange_teashades_2", "orange_teashades_1"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 458
	},

	"red_scarf": {
		"category": "body_accessory",
		"display_name": "Red Scarf",
		"rarity": "common",
		"texture": "red_scarf",
		"inventory_icon": "red_scarf_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "body_accessory",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 460
	},

	"life_jacket": {
		"category": "body_accessory",
		"display_name": "Life Jacket",
		"rarity": "common",
		"texture": "life_jacket",
		"inventory_icon": "life_jacket_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "body_accessory",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 461
	},

	"chefs_apron": {
		"category": "body_accessory",
		"display_name": "Chefs Apron",
		"rarity": "common",
		"texture": "chefs_apron",
		"inventory_icon": "chefs_apron_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "body_accessory",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 462
	},

	"workshop_apron": {
		"category": "body_accessory",
		"display_name": "Workshop Apron",
		"rarity": "common",
		"texture": "workshop_apron",
		"inventory_icon": "workshop_apron_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "body_accessory",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 463
	},

	"bronze_pendant": {
		"category": "body_accessory",
		"display_name": "Bronze Pendant",
		"rarity": "common",
		"texture": "bronze_pendant",
		"inventory_icon": "bronze_pendant_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "body_accessory",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 464
	},

	"basic_blue_shirt": {
		"category": "shirt",
		"display_name": "Blue Shirt",
		"rarity": "common",
		"texture": "basic_blue_shirt_body",
		"inventory_icon": "basic_blue_shirt_icon",
		"arm_texture": "basic_blue_shirt_arm",
		"left_arm_texture": "basic_blue_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 212
	},

"basic_red_shirt": {
		"category": "shirt",
		"display_name": "Red Shirt",
		"rarity": "common",
		"texture": "basic_red_shirt_body",
		"inventory_icon": "basic_red_shirt_icon",
		"arm_texture": "basic_red_shirt_arm",
		"left_arm_texture": "basic_red_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 213
	},

"basic_white_shirt": {
		"category": "shirt",
		"display_name": "White Shirt",
		"rarity": "common",
		"texture": "basic_white_shirt_body",
		"inventory_icon": "basic_white_shirt_icon",
		"arm_texture": "basic_white_shirt_arm",
		"left_arm_texture": "basic_white_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 214
	},

"basic_black_shirt": {
		"category": "shirt",
		"display_name": "Black Shirt",
		"rarity": "common",
		"texture": "basic_black_shirt_body",
		"inventory_icon": "basic_black_shirt_icon",
		"arm_texture": "basic_black_shirt_arm",
		"left_arm_texture": "basic_black_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 215
	},

"basic_heart_shirt": {
		"category": "shirt",
		"display_name": "Heart Shirt",
		"rarity": "common",
		"texture": "basic_heart_shirt_body",
		"inventory_icon": "basic_heart_shirt_icon",
		"arm_texture": "basic_heart_shirt_arm",
		"left_arm_texture": "basic_heart_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 216
	},

"basic_gray_shirt": {
		"category": "shirt",
		"display_name": "Gray Shirt",
		"rarity": "common",
		"texture": "basic_gray_shirt_body",
		"inventory_icon": "basic_gray_shirt_icon",
		"arm_texture": "basic_gray_shirt_arm",
		"left_arm_texture": "basic_gray_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 217
	},

	"basic_maroon_shirt": {
		"category": "shirt",
		"display_name": "Maroon Shirt",
		"rarity": "common",
		"texture": "basic_maroon_shirt_body",
		"inventory_icon": "basic_maroon_shirt_icon",
		"arm_texture": "basic_maroon_shirt_arm",
		"left_arm_texture": "basic_maroon_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 218
	},

"black_suit": {
		"category": "shirt",
		"display_name": "Black Suit",
		"rarity": "common",
		"texture": "black_suit_body",
		"inventory_icon": "black_suit_icon",
		"arm_texture": "black_suit_arm",
		"left_arm_texture": "black_suit_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 219
	},

"blue_suit": {
		"category": "shirt",
		"display_name": "Blue Suit",
		"rarity": "common",
		"texture": "blue_suit_body",
		"inventory_icon": "blue_suit_icon",
		"arm_texture": "blue_suit_arm",
		"left_arm_texture": "blue_suit_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 220
	},

	"red_stripe_shirt": {
		"category": "shirt",
		"display_name": "Red Stripe Shirt",
		"rarity": "common",
		"texture": "red_stripe_shirt_body",
		"inventory_icon": "red_stripe_shirt_icon",
		"arm_texture": "red_stripe_shirt_arm",
		"left_arm_texture": "red_stripe_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 902
	},

	"red_lumberjack_shirt": {
		"category": "shirt",
		"display_name": "Red Lumberjack Shirt",
		"rarity": "common",
		"texture": "red_lumberjack_shirt_body",
		"inventory_icon": "red_lumberjack_shirt_icon",
		"arm_texture": "red_lumberjack_shirt_arm",
		"left_arm_texture": "red_lumberjack_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 903
	},

	"blue_lumberjack_shirt": {
		"category": "shirt",
		"display_name": "Blue Lumberjack Shirt",
		"rarity": "common",
		"texture": "blue_lumberjack_shirt_body",
		"inventory_icon": "blue_lumberjack_shirt_icon",
		"arm_texture": "blue_lumberjack_shirt_arm",
		"left_arm_texture": "blue_lumberjack_shirt_arm_left",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"right_arm_offset": [-7, -5],
		"left_arm_offset": [6, -5],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"arm_z_index": 1,
		"order": 904
	},

"basic_black_pants": {
		"category": "pants",
		"display_name": "Black Pants",
		"rarity": "common",
		"texture": "basic_black_pants",
		"inventory_icon": "basic_black_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 230
	},

"basic_light_gray_pants": {
		"category": "pants",
		"display_name": "Light Gray Pants",
		"rarity": "common",
		"texture": "basic_light_gray_pants",
		"inventory_icon": "basic_light_gray_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 231
	},

"basic_navy_pants": {
		"category": "pants",
		"display_name": "Navy Pants",
		"rarity": "common",
		"texture": "basic_navy_pants",
		"inventory_icon": "basic_navy_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 232
	},

"basic_brown_pants": {
		"category": "pants",
		"display_name": "Brown Pants",
		"rarity": "common",
		"texture": "basic_brown_pants",
		"inventory_icon": "basic_brown_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 233
	},

"basic_green_pants": {
		"category": "pants",
		"display_name": "Green Pants",
		"rarity": "common",
		"texture": "basic_green_pants",
		"inventory_icon": "basic_green_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 234
	},

"basic_pink_pants": {
		"category": "pants",
		"display_name": "Pink Pants",
		"rarity": "common",
		"texture": "basic_pink_pants",
		"inventory_icon": "basic_pink_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 235
	},

	"black_dress_pants": {
		"category": "pants",
		"display_name": "Black Dress Pants",
		"rarity": "common",
		"texture": "black_dress_pants",
		"inventory_icon": "black_dress_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 236
	},

	"blue_dress_pants": {
		"category": "pants",
		"display_name": "Blue Dress Pants",
		"rarity": "common",
		"texture": "blue_dress_pants",
		"inventory_icon": "blue_dress_pants_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 237
	},

"basic_brown_shoes": {
		"category": "shoes",
		"display_name": "Brown Shoes",
		"rarity": "common",
		"texture": "brown_shoes_icon",
		"inventory_icon": "brown_shoes_icon",
		"left_shoe_texture": "brown_shoes_left",
		"right_shoe_texture": "brown_shoes_right",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 250
	},

"basic_black_shoes": {
		"category": "shoes",
		"display_name": "Black Shoes",
		"rarity": "common",
		"texture": "black_shoes_icon",
		"inventory_icon": "black_shoes_icon",
		"left_shoe_texture": "black_shoes_left",
		"right_shoe_texture": "black_shoes_right",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 251
	},

"basic_red_shoes": {
		"category": "shoes",
		"display_name": "Red Shoes",
		"rarity": "common",
		"texture": "red_shoes_icon",
		"inventory_icon": "red_shoes_icon",
		"left_shoe_texture": "red_shoes_left",
		"right_shoe_texture": "red_shoes_right",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 252
	},

"basic_blue_shoes": {
		"category": "shoes",
		"display_name": "Blue Shoes",
		"rarity": "common",
		"texture": "blue_shoes_icon",
		"inventory_icon": "blue_shoes_icon",
		"left_shoe_texture": "blue_shoes_left",
		"right_shoe_texture": "blue_shoes_right",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 253
	},

"light_blue_shoes": {
		"category": "shoes",
		"display_name": "Light Blue Shoes",
		"rarity": "common",
		"texture": "light_blue_shoes_icon",
		"inventory_icon": "light_blue_shoes_icon",
		"left_shoe_texture": "light_blue_shoes_left",
		"right_shoe_texture": "light_blue_shoes_right",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 254
	},

"basic_yellow_shoes": {
		"category": "shoes",
		"display_name": "Yellow Shoes",
		"rarity": "common",
		"texture": "yellow_shoes_icon",
		"inventory_icon": "yellow_shoes_icon",
		"left_shoe_texture": "yellow_shoes_left",
		"right_shoe_texture": "yellow_shoes_right",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 255
	},

"red_tractor": {
		"category": "ride",
		"display_name": "Red Tractor",
		"rarity": "epic",
		"description": "Automatically harvests ready seed-trees when you drive over them.",
		"texture": "res://Assets/clothes/ride/red_tractor_icon.png",
		"inventory_icon": "res://Assets/clothes/ride/red_tractor_icon.png",
		"ride_texture": "res://Assets/clothes/ride/red_tractor_1.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "ride",
		"ride_visual": true,
		"ride_offset": [0, 0],
		"ride_scale": 1.0,
		"ride_z_index": 0,
		"animation_fps": 8.0,
		"animations": {
			"idle": ["res://Assets/clothes/ride/red_tractor_1.png"],
			"walk": ["res://Assets/clothes/ride/red_tractor_1.png", "res://Assets/clothes/ride/red_tractor_2.png", "res://Assets/clothes/ride/red_tractor_3.png", "res://Assets/clothes/ride/red_tractor_4.png"],
			"jump": ["res://Assets/clothes/ride/red_tractor_1.png"],
			"fall": ["res://Assets/clothes/ride/red_tractor_1.png"]
		},
		"shop_price": 100000,
		"order": 255
	},

"purple_shirt": {
		"category": "shirt",
		"display_name": "Purple Shirt",
		"rarity": "common",
		"texture": "res://Assets/clothes/shirts/purple_shirt.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"order": 210
	},

"purple_pants": {
		"category": "pants",
		"display_name": "Purple Pants",
		"rarity": "common",
		"texture": "res://Assets/clothes/pants/purple_pants.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"order": 211
	},

"void_shirt": {
		"category": "shirt",
		"display_name": "Void Shirt",
		"rarity": "common",
		"texture": "res://Assets/clothes/shirts/void_shirt_body.png",
		"shirt_body_texture": "res://Assets/clothes/shirts/void_shirt_body.png",
		"inventory_icon": "res://Assets/clothes/shirts/void_shirt_icon.png",
		"arm_texture": "res://Assets/clothes/shirts/void_shirt_arm.png",
		"right_arm_texture": "res://Assets/clothes/shirts/void_shirt_arm.png",
		"left_arm_texture": "res://Assets/clothes/shirts/void_shirt_arm_left.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shirt",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 219
	},

"void_pants": {
		"category": "pants",
		"display_name": "Void Pants",
		"rarity": "common",
		"texture": "res://Assets/clothes/pants/void_pants.png",
		"left_pants_texture": "res://Assets/clothes/pants/void_leg_left.png",
		"right_pants_texture": "res://Assets/clothes/pants/void_leg_right.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "pants",
		"slot_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 1,
		"order": 236
	},

"void_shoes": {
		"category": "shoes",
		"display_name": "Void Shoes",
		"rarity": "common",
		"texture": "res://Assets/clothes/shoes/void_shoes.png",
		"inventory_icon": "res://Assets/clothes/shoes/void_shoes.png",
		"left_shoe_texture": "res://Assets/clothes/shoes/void_shoe_left.png",
		"right_shoe_texture": "res://Assets/clothes/shoes/void_shoe_right.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "shoes",
		"left_shoe_offset": [0, 0],
		"right_shoe_offset": [0, 0],
		"slot_scale": 1.0,
		"slot_z_index": 2,
		"order": 254
	},

	# ============================================================

	# ============================================================
	# FISHING ITEMS
	# ============================================================
# ============================================================
# FISHING ITEMS
# ============================================================
"wooden_fishing_rod": {
		"category": "tool",
		"display_name": "Wooden Fishing Rod",
		"rarity": "common",
		"texture": "wooden_fishing_rod_1",
		"inventory_icon": "wooden_fishing_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [24, 45],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [50, 38],
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["wooden_fishing_rod_1", "wooden_fishing_rod_2", "wooden_fishing_rod_3"],
				"fps": 6.0,
				"loop": true
			},
			"casting": {
				"frames": ["wooden_fishing_rod_casting"],
				"fps": 6.0,
				"loop": false
			}
		},
		"order": 39
	},
"bamboo_fishing_rod": {
		"category": "tool",
		"display_name": "Bamboo Fishing Rod",
		"rarity": "uncommon",
		"texture": "bamboo_fishing_rod_1",
		"inventory_icon": "bamboo_fishing_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [24, 45],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [50, 38],
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["bamboo_fishing_rod_1", "bamboo_fishing_rod_2", "bamboo_fishing_rod_3"],
				"fps": 6.0,
				"loop": true
			},
			"casting": {
				"frames": ["bamboo_fishing_rod_casting"],
				"fps": 6.0,
				"loop": false
			}
		},
		"order": 40
	},
"fishing_rod": {
		"category": "tool",
		"display_name": "Bamboo Fishing Rod",
		"rarity": "uncommon",
		"texture": "bamboo_fishing_rod_1",
		"inventory_icon": "bamboo_fishing_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"legacy_item_id": true,
		"canonical_item_id": "bamboo_fishing_rod",
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [24, 45],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [50, 38],
		"order": 43
	},
"fiberglass_fishing_rod": {
		"category": "tool",
		"display_name": "Fiberglass Fishing Rod",
		"rarity": "rare",
		"texture": "fiberglass_fishing_rod_1",
		"inventory_icon": "fiberglass_fishing_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [25, 46],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [53, 42],
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["fiberglass_fishing_rod_1", "fiberglass_fishing_rod_2", "fiberglass_fishing_rod_3"],
				"fps": 6.0,
				"loop": true
			},
			"casting": {
				"frames": ["fiberglass_fishing_rod_casting"],
				"fps": 6.0,
				"loop": false
			}
		},
		"order": 44
	},
"platinum_rod": {
		"category": "tool",
		"display_name": "Platinum Rod",
		"rarity": "epic",
		"texture": "platinum_rod_1",
		"inventory_icon": "platinum_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [26, 47],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [63, 38],
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["platinum_rod_1", "platinum_rod_2", "platinum_rod_3"],
				"fps": 6.0,
				"loop": true
			},
			"casting": {
				"frames": ["platinum_rod_casting"],
				"fps": 6.0,
				"loop": false
			}
		},
		"order": 47
	},
"golden_fishing_rod": {
		"category": "tool",
		"display_name": "Golden Fishing Rod",
		"rarity": "legendary",
		"texture": "golden_fishing_rod_1",
		"inventory_icon": "golden_fishing_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [62, 82],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [103, 68],
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["golden_fishing_rod_1", "golden_fishing_rod_2", "golden_fishing_rod_3"],
				"fps": 6.0,
				"loop": true
			},
			"casting": {
				"frames": ["golden_fishing_rod_casting"],
				"fps": 6.0,
				"loop": false
			}
		},
		"order": 49
	},
"platinum_prestige_rod": {
		"category": "tool",
		"display_name": "Golden Fishing Rod",
		"rarity": "legendary",
		"texture": "golden_fishing_rod_1",
		"inventory_icon": "golden_fishing_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"legacy_item_id": true,
		"canonical_item_id": "golden_fishing_rod",
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [62, 82],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [103, 68],
		"order": 50
	},
"neptune_rod": {
		"category": "tool",
		"display_name": "Neptune Rod",
		"rarity": "legendary",
		"texture": "neptune_rod_1",
		"inventory_icon": "neptune_rod_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"fishing_rod": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [16, 16],
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,
		"fishing_line_tip_offset": [37, 10],
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["neptune_rod_1", "neptune_rod_2", "neptune_rod_3", "neptune_rod_4", "neptune_rod_3", "neptune_rod_2", "neptune_rod_1"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 51
	},
"sakura_sword": {
		"category": "tool",
		"display_name": "Sakura Sword",
		"rarity": "legendary",
		"texture": "sakura_sword_1",
		"inventory_icon": "sakura_sword_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"order": 52
	},
"serpent_staff": {
		"category": "tool",
		"display_name": "Serpent Staff",
		"rarity": "legendary",
		"texture": "serpent_staff_1",
		"inventory_icon": "serpent_staff_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["serpent_staff_1", "serpent_staff_2", "serpent_staff_3", "serpent_staff_4"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 44
	},
"angelic_sword": {
		"category": "tool",
		"display_name": "Angelic Sword",
		"rarity": "legendary",
		"texture": "angelic_sword_1",
		"inventory_icon": "angelic_sword_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["angelic_sword_1", "angelic_sword_2", "angelic_sword_3", "angelic_sword_4"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 53
	},
"phoenix_sword": {
		"category": "tool",
		"display_name": "Phoenix Sword",
		"rarity": "legendary",
		"texture": "phoenix_sword_1",
		"inventory_icon": "phoenix_sword_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["phoenix_sword_1", "phoenix_sword_2", "phoenix_sword_3", "phoenix_sword_4"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 64
	},
"fire_staff": {
		"category": "tool",
		"display_name": "Fire Staff",
		"rarity": "legendary",
		"texture": "fire_staff_1",
		"inventory_icon": "fire_staff_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["fire_staff_1", "fire_staff_2", "fire_staff_3", "fire_staff_4"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 67
	},
"wizards_staff": {
		"category": "tool",
		"display_name": "Wizard's Staff",
		"rarity": "legendary",
		"texture": "wizards_staff_1",
		"inventory_icon": "wizards_staff_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["wizards_staff_1", "wizards_staff_2", "wizards_staff_3", "wizards_staff_4"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 68
	},
"neptune_trident": {
		"category": "tool",
		"display_name": "Neptune Trident",
		"rarity": "legendary",
		"texture": "neptune_trident_1",
		"inventory_icon": "neptune_trident_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"order": 45
	},
"void_trident": {
		"category": "tool",
		"display_name": "Void Trident",
		"rarity": "legendary",
		"texture": "void_trident_1",
		"inventory_icon": "void_trident_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"order": 65
	},
"blood_battleaxe": {
		"category": "tool",
		"display_name": "Blood Battleaxe",
		"rarity": "legendary",
		"texture": "blood_battleaxe_1",
		"inventory_icon": "blood_battleaxe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"order": 66
	},
"blue_saber": {
		"category": "tool",
		"display_name": "Blue Saber",
		"rarity": "legendary",
		"texture": "blue_saber_1",
		"inventory_icon": "blue_saber_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["blue_saber_1", "blue_saber_2", "blue_saber_3"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 54
	},
"green_saber": {
		"category": "tool",
		"display_name": "Green Saber",
		"rarity": "legendary",
		"texture": "green_saber_1",
		"inventory_icon": "green_saber_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["green_saber_1", "green_saber_2", "green_saber_3"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 55
	},
"red_saber": {
		"category": "tool",
		"display_name": "Red Saber",
		"rarity": "legendary",
		"texture": "red_saber_1",
		"inventory_icon": "red_saber_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["red_saber_1", "red_saber_2", "red_saber_3"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 56
	},
"void_saber": {
		"category": "tool",
		"display_name": "Void Saber",
		"rarity": "legendary",
		"texture": "void_saber_1",
		"inventory_icon": "void_saber_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["void_saber_1", "void_saber_2", "void_saber_3", "void_saber_2", "void_saber_1"],
				"fps": 6.0,
				"loop": true
			}
		},
		"order": 57
	},
"stone_pickaxe": {
		"category": "tool",
		"display_name": "Stone Pickaxe",
		"description": "A sturdy stone pickaxe that breaks blocks at normal punch strength.",
		"rarity": "common",
		"texture": "stone_pickaxe_1",
		"inventory_icon": "stone_pickaxe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"instance_tracked": true,
		"order": 58
	},
"golden_pickaxe": {
		"category": "tool",
		"display_name": "Golden Pickaxe",
		"description": "A polished golden pickaxe that breaks blocks at normal punch strength.",
		"rarity": "rare",
		"texture": "golden_pickaxe_1",
		"inventory_icon": "golden_pickaxe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"instance_tracked": true,
		"order": 59
	},
"emerald_pickaxe": {
		"category": "tool",
		"display_name": "Emerald Pickaxe",
		"description": "An emerald pickaxe that breaks blocks at normal punch strength.",
		"rarity": "epic",
		"texture": "emerald_pickaxe_1",
		"inventory_icon": "emerald_pickaxe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"instance_tracked": true,
		"order": 60
	},
"diamond_pickaxe": {
		"category": "tool",
		"display_name": "Diamond Pickaxe",
		"description": "A diamond pickaxe that breaks blocks at normal punch strength.",
		"rarity": "legendary",
		"texture": "diamond_pickaxe_1",
		"inventory_icon": "diamond_pickaxe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"instance_tracked": true,
		"order": 61
	},
"neptune_pickaxe": {
		"category": "tool",
		"display_name": "Neptune Pickaxe",
		"description": "A sea-forged pickaxe that breaks blocks at normal punch strength.",
		"rarity": "legendary",
		"texture": "neptune_pickaxe_1",
		"inventory_icon": "neptune_pickaxe_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["neptune_pickaxe_1", "neptune_pickaxe_2"],
				"fps": 6.0,
				"loop": true
			}
		},
		"instance_tracked": true,
		"order": 62
	},
"void_pickaxe": {
		"category": "tool",
		"display_name": "Void Pickaxe",
		"description": "A void-forged pickaxe that reduces the hits needed to break a block by one.",
		"rarity": "legendary",
		"texture": "void_pickaxe_1",
		"inventory_icon": "void_pickaxe_icon",
		"animation_fps": 6.0,
		"hand_item_animations": {
			"idle": {
				"frames": ["void_pickaxe_1", "void_pickaxe_2", "void_pickaxe_3"],
				"fps": 6.0,
				"loop": true
			}
		},
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"punch_animation": "punch_sword",
		"break_hit_reduction": 1,
		"instance_tracked": true,
		"order": 63
	},
"electric_tool": {
		"category": "tool",
		"display_name": "Electric Tool",
		"rarity": "rare",
		"texture": "electric_tool_1",
		"inventory_icon": "electric_tool_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [32, 32],
		"hand_scale": 1.0,
		"hand_rotation": -10,
		"hand_rotation_left": 10,
		"shop_price": 5000,
		"order": 46
	},
"wire_cutter": {
		"category": "tool",
		"display_name": "Wire Cutter",
		"rarity": "common",
		"texture": "wire_cutter_1",
		"inventory_icon": "wire_cutter_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [32, 32],
		"hand_scale": 1.0,
		"hand_rotation": -10,
		"hand_rotation_left": 10,
		"shop_price": 0,
		"order": 48
	},
"metal_detector": {
		"category": "tool",
		"display_name": "Metal Detector",
		"rarity": "common",
		"texture": "metal_detector_1",
		"inventory_icon": "metal_detector_icon",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [32, 32],
		"hand_scale": 1.0,
		"hand_rotation": -10,
		"hand_rotation_left": 10,
		"shop_price": 0,
		"order": 53
	},
"hook": {
		"category": "lure",
		"display_name": "Basic Hook",
		"rarity": "common",
		"texture": "res://Assets/items/lures/hook.png",
		"order": 299
	},
"worm_lure": {
		"category": "lure",
		"display_name": "Worm Bait",
		"rarity": "common",
		"texture": "res://Assets/items/lures/worm_lure.png",
		"order": 300
	},
"shiny_lure": {
		"category": "lure",
		"display_name": "Shiny Bait",
		"rarity": "uncommon",
		"texture": "res://Assets/items/lures/shiny_lure.png",
		"order": 301
	},
"golden_lure": {
		"category": "lure",
		"display_name": "Golden Bait",
		"rarity": "rare",
		"texture": "res://Assets/items/lures/golden_lure.png",
		"order": 302
	},
"bonito_lure": {
		"category": "lure",
		"display_name": "Bonito Bait",
		"rarity": "epic",
		"texture": "res://Assets/items/lures/Bonito_lure.png",
		"order": 303
	},
"cotton_cordel_lure": {
		"category": "lure",
		"display_name": "Cotton Cordel Bait",
		"rarity": "epic",
		"texture": "res://Assets/items/lures/cotton_cordel_lure.png",
		"order": 304
	},
"void_worm_lure": {
		"category": "lure",
		"display_name": "Void Worm Bait",
		"rarity": "legendary",
		"texture": "res://Assets/items/lures/void_worm_lure.png",
		"order": 305
	},
"magnet_lure": {
		"category": "lure",
		"display_name": "Magnetic Bait",
		"rarity": "uncommon",
		"texture": "res://Assets/items/lures/magnet_lure.png",
		"material_fishing_lure": true,
		"order": 306
	},
"lure_pack": {
		"category": "lure",
		"display_name": "Lure Pack",
		"rarity": "uncommon",
		"texture": "res://Assets/items/lures/lure_pack.png",
		"shop_pack": true,
		"order": 307
	},

	# ============================================================
	# FISH
	# ============================================================
"pond_fish": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Pond Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/pond_fish_large.png",
		"sell_value": 3,
		"order": 400
	},
"pond_fish_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Pond Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/pond_fish_small.png",
		"sell_value": 2,
		"difficulty": 1,
		"fish_family": "pond_fish",
		"fish_size": "small",
		"order": 401
	},
"pond_fish_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Pond Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/pond_fish_med.png",
		"sell_value": 4,
		"difficulty": 1,
		"fish_family": "pond_fish",
		"fish_size": "medium",
		"order": 402
	},
"pond_fish_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Pond Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/pond_fish_large.png",
		"sell_value": 7,
		"difficulty": 2,
		"fish_family": "pond_fish",
		"fish_size": "large",
		"order": 403
	},
"bluegill": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Bluegill",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/bluegill.png",
		"sell_value": 8,
		"difficulty": 2,
		"order": 404
	},
"golden_carp": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Golden Carp",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/golden_carp.png",
		"sell_value": 25,
		"difficulty": 4,
		"order": 405
	},
"crystal_fish": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Crystal Fish",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/crystal_fish.png",
		"sell_value": 75,
		"difficulty": 6,
		"order": 406
	},
"cat_fish_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Cat Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/cat_fish_small.png",
		"sell_value": 4,
		"difficulty": 1,
		"fish_family": "cat_fish",
		"fish_size": "small",
		"order": 407
	},
"cat_fish_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Cat Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/cat_fish_med.png",
		"sell_value": 8,
		"difficulty": 2,
		"fish_family": "cat_fish",
		"fish_size": "medium",
		"order": 408
	},
"cat_fish_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Cat Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/cat_fish_large.png",
		"sell_value": 14,
		"difficulty": 3,
		"fish_family": "cat_fish",
		"fish_size": "large",
		"order": 409
	},
"bone_fish_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Bone Fish",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/bone_fish_small.png",
		"sell_value": 6,
		"difficulty": 2,
		"fish_family": "bone_fish",
		"fish_size": "small",
		"order": 410
	},
"bone_fish_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Bone Fish",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/bone_fish_med.png",
		"sell_value": 12,
		"difficulty": 3,
		"fish_family": "bone_fish",
		"fish_size": "medium",
		"order": 411
	},
"bone_fish_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Bone Fish",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/bone_fish_large.png",
		"sell_value": 20,
		"difficulty": 4,
		"fish_family": "bone_fish",
		"fish_size": "large",
		"order": 412
	},
"barracuda_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Barracuda",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/barracuda_small.png",
		"sell_value": 10,
		"difficulty": 2,
		"fish_family": "barracuda",
		"fish_size": "small",
		"order": 413
	},
"barracuda_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Barracuda",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/barracuda_med.png",
		"sell_value": 18,
		"difficulty": 3,
		"fish_family": "barracuda",
		"fish_size": "medium",
		"order": 414
	},
"barracuda_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Barracuda",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/barracuda_large.png",
		"sell_value": 30,
		"difficulty": 4,
		"fish_family": "barracuda",
		"fish_size": "large",
		"order": 415
	},
"sea_horse_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Sea Horse",
		"rarity": "common",
		"texture": "res://Assets/items/fish/sea_horse_small.png",
		"sell_value": 12,
		"difficulty": 3,
		"fish_family": "sea_horse",
		"fish_size": "small",
		"order": 416
	},
"sea_horse_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Sea Horse",
		"rarity": "common",
		"texture": "res://Assets/items/fish/sea_horse_med.png",
		"sell_value": 22,
		"difficulty": 4,
		"fish_family": "sea_horse",
		"fish_size": "medium",
		"order": 417
	},
"sea_horse_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Sea Horse",
		"rarity": "common",
		"texture": "res://Assets/items/fish/sea_horse_large.png",
		"sell_value": 40,
		"difficulty": 5,
		"fish_family": "sea_horse",
		"fish_size": "large",
		"order": 418
	},
"stingray_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Stingray",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/stingray_small.png",
		"sell_value": 15,
		"difficulty": 3,
		"fish_family": "stingray",
		"fish_size": "small",
		"order": 419
	},
"stingray_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Stingray",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/stingray_med.png",
		"sell_value": 28,
		"difficulty": 4,
		"fish_family": "stingray",
		"fish_size": "medium",
		"order": 420
	},
"stingray_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Stingray",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/stingray_large.png",
		"sell_value": 50,
		"difficulty": 5,
		"fish_family": "stingray",
		"fish_size": "large",
		"order": 421
	},
"shark_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Shark",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/shark_small.png",
		"sell_value": 20,
		"difficulty": 4,
		"fish_family": "shark",
		"fish_size": "small",
		"order": 422
	},
"shark_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Shark",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/shark_med.png",
		"sell_value": 40,
		"difficulty": 5,
		"fish_family": "shark",
		"fish_size": "medium",
		"order": 423
	},
"shark_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Shark",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/shark_large.png",
		"sell_value": 75,
		"difficulty": 6,
		"fish_family": "shark",
		"fish_size": "large",
		"order": 424
	},
"lava_fish_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Lava Fish",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/lava_fish_small.png",
		"sell_value": 30,
		"difficulty": 5,
		"fish_family": "lava_fish",
		"fish_size": "small",
		"order": 425
	},
"lava_fish_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Lava Fish",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/lava_fish_med.png",
		"sell_value": 60,
		"difficulty": 6,
		"fish_family": "lava_fish",
		"fish_size": "medium",
		"order": 426
	},
"lava_fish_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Lava Fish",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/lava_fish_large.png",
		"sell_value": 110,
		"difficulty": 7,
		"fish_family": "lava_fish",
		"fish_size": "large",
		"order": 427
	},
"alien_fish_small": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Small Alien Fish",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/alien_fish_small.png",
		"sell_value": 35,
		"difficulty": 5,
		"fish_family": "alien_fish",
		"fish_size": "small",
		"order": 428
	},
"alien_fish_med": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Medium Alien Fish",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/alien_fish_med.png",
		"sell_value": 70,
		"difficulty": 6,
		"fish_family": "alien_fish",
		"fish_size": "medium",
		"order": 429
	},
"alien_fish_large": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Large Alien Fish",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/alien_fish_large.png",
		"sell_value": 130,
		"difficulty": 7,
		"fish_family": "alien_fish",
		"fish_size": "large",
		"order": 430
	},
"mossy_chest": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Mossy Chest",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/mossy_chest.png",
		"sell_value": 100,
		"difficulty": 5,
		"fishing_treasure": true,
		"order": 431
	},
"atlantic_chest": {
		"category": "block",
		"display_name": "Atlantic Chest",
		"rarity": "epic",
		"block_health": 4,
		"texture": "res://Assets/items/fish/atlantic_chest.png",
		"inventory_icon": "res://Assets/items/fish/atlantic_chest.png",
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"drop_gems": false,
		"fishing_reward": true,
		"fishing_treasure": true,
		"sell_value": 0,
		"difficulty": 6,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"loot_table": [
				{"item_id": "neptune_trident", "item_category": "tool", "weight": 1, "amount": 1},
				{"item_id": "treasure_chest", "item_category": "fish", "weight": 9, "amount": 1},
				{"item_id": "mossy_chest", "item_category": "fish", "weight": 14, "amount": 1},
				{"item_id": "golden_lure", "item_category": "lure", "weight": 10, "amount": 1},
				{"item_id": "void_worm_lure", "item_category": "lure", "weight": 4, "amount": 1},
				{"item_id": "coral", "item_category": "material", "weight": 12, "amount_range": [2, 5]},
				{"item_id": "clam", "item_category": "material", "weight": 12, "amount_range": [2, 5]},
				{"item_id": "seaweed", "item_category": "material", "weight": 14, "amount_range": [3, 8]},
				{"item_id": "trash_can", "item_category": "material", "weight": 10, "amount_range": [2, 5]},
				{"item_id": "rusty_bicycle", "item_category": "material", "weight": 8, "amount_range": [1, 2]},
				{"item_id": "naval_mines", "item_category": "material", "weight": 6, "amount": 1}
			]
		},
		"order": 432
	},
"treasure_chest": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Treasure Chest",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/treasure_chest.png",
		"sell_value": 300,
		"difficulty": 8,
		"fishing_treasure": true,
		"order": 433
	},
"sea_eater": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Sea Eater",
		"rarity": "legendary",
		"texture": "res://Assets/items/fish/sea_eater.png",
		"sell_value": 250,
		"difficulty": 9,
		"order": 434
	},
"tail_of_trident": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Tail of Trident",
		"rarity": "legendary",
		"texture": "res://Assets/items/fish/Tail_of_trident.png",
		"sell_value": 225,
		"difficulty": 8,
		"order": 435
	},
"mermaid": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Mermaid",
		"rarity": "legendary",
		"texture": "res://Assets/items/fish/mermaid.png",
		"sell_value": 300,
		"difficulty": 9,
		"order": 436
	},
"megalodon": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Megalodon",
		"rarity": "legendary",
		"texture": "res://Assets/items/fish/megalodon.png",
		"sell_value": 450,
		"difficulty": 10,
		"order": 437
	},
"kraken": {
		"category": "fish",
		"is_fish": true,
		"quantity_type": "count",
		"display_name": "Kraken",
		"rarity": "legendary",
		"texture": "res://Assets/items/fish/kraken.png",
		"sell_value": 500,
		"difficulty": 10,
		"order": 438
	},

	# TOOLS / UTILITY ITEMS
	# ============================================================
"entrance_mover": {
		"category": "tool",
		"display_name": "Entrance Mover",
		"rarity": "rare",
		"texture": "res://Assets/items/special items/entrance mover/entrance_mover.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 1,
		"effective_blocks": [],
		"equipable": false,
		"consumable": true,
		"order": 4
	},
"lock_mover": {
		"category": "tool",
		"display_name": "Lock Mover",
		"rarity": "epic",
		"texture": "res://Assets/locks/lock_mover.png",
		"inventory_icon": "res://Assets/locks/lock_mover.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 1,
		"effective_blocks": [],
		"equipable": false,
		"consumable": true,
		"shop_price": 17000,
		"order": 5
	},
"door_mover": {
		"category": "tool",
		"display_name": "Door Mover",
		"rarity": "rare",
		"texture": "res://Assets/inventory_icons/door.png",
		"inventory_icon": "res://Assets/inventory_icons/door.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 1,
		"effective_blocks": [],
		"equipable": false,
		"consumable": true,
		"shop_price": 500,
		"order": 6
	},
"world_lock_key": {
		"category": "material",
		"display_name": "World Lock Key",
		"rarity": "legendary",
		"texture": "res://Assets/locks/world_lock_key.png",
		"inventory_icon": "res://Assets/locks/world_lock_key.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 1,
		"effective_blocks": [],
		"equipable": false,
		"consumable": false,
		"tradeable": true,
		"dropable": false,
		"vendable": false,
		"instance_tracked": true,
		"max_stack": 400,
		"world_lock_key": true,
		"order": 6
	},
"wrench": {
		"category": "tool",
		"display_name": "Wrench",
		"rarity": "uncommon",
		"hidden": true,
		"texture": "res://Assets/items/special items/tools/wrench.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 2,
		"effective_blocks": [],
		"equipable": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [9, 24],
		"hand_scale": 0.92,
		"hand_rotation": -28,
		"hand_rotation_left": 28,
		"order": 3
	},

	# ============================================================
	# Shop Items

"vending_machine": {
		"category": "block",
		"display_name": "Vending Machine",
		"rarity": "epic",
		"block_health": 5,
		"break_power": 5,
		"texture": {"atlas": "res://image.png", "cell": [4, 1], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [4, 1], "cell_size": [32, 32]},
		"vending_machine_block": true,
		"vending_empty_atlas_coords": Vector2i(3, 1),
		"vending_full_atlas_coords": Vector2i(4, 1),
		"vending_sold_atlas_coords": Vector2i(5, 1),
		"vending_out_of_stock_atlas_coords": Vector2i(6, 1),
		"placeable": true,
		"tradeable": true,
		"equipable": false,
		"starting_count": 0,
		"shop_pack": true,
		"no_collision": true,
		"interact_rules": true,
		"break_return_to_inventory": true,
		"break_return_item_id": "vending_machine",
		"drop_rules": {"seed_chance": 0, "gem_range": [0, 0]},
	},
"fish_monger": {
		"category": "block",
		"display_name": "Fish Monger",
		"rarity": "epic",
		"block_health": 6,
		"break_power": 5,
		"texture": {"atlas": "res://image.png", "region": [384, 0, 64, 64]},
		"inventory_icon": {"atlas": "res://image.png", "region": [384, 0, 64, 64]},
		"animation_frames": [
			{"atlas": "res://image.png", "region": [384, 0, 64, 64]},
			{"atlas": "res://image.png", "region": [448, 0, 64, 64]},
			{"atlas": "res://image.png", "region": [512, 0, 64, 64]},
			{"atlas": "res://image.png", "region": [576, 0, 64, 64]}
		],
		"animation_frame_seconds": 0.5,
		"visual_size": Vector2i(64, 64),
		"visual_offset": Vector2(16, -16),
		"collidable": false,
		"collision_size": Vector2i(64, 64),
		"collision_offset": Vector2(16, -16),
		"shadow_size": Vector2i(64, 64),
		"shadow_visual_offset": Vector2(16, -16),
		"seed": "",
		"placeable": true,
		"tradeable": true,
		"equipable": false,
		"starting_count": 0,
		"shop_pack": true,
		"interact_rules": true,
		"requires_world_lock": true,
		"requires_full_area_clear": true,
		"occupies_collision_area": true,
		"drop_gems": false,
		"break_return_to_inventory": true,
		"drop_rules": {"seed_chance": 0, "gem_range": [0, 0]},
		"shop_price": 15000,
		"order": 38
	},
"safe": {
		"category": "block",
		"display_name": "Safe",
		"rarity": "epic",
		"block_health": 6,
		"break_power": 5,
		"texture": {"atlas": "res://image.png", "cell": [3, 2], "cell_size": [32, 32]},
		"inventory_icon": {"atlas": "res://image.png", "cell": [3, 2], "cell_size": [32, 32]},
		"seed": "",
		"placeable": true,
		"tradeable": true,
		"equipable": false,
		"starting_count": 0,
		"shop_pack": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"interact_rules": true,
	},
"big_spike": {
	"block_health": 4,
	"category": "block",
	"collidable": true,
	"display_name": "Dark Spike",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "big_spike",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 7]
			},
			{
				"item_id": "big_spike_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			}
		]
	},
	"hazard_instant_death": true,
	"instant_death": true,
	"order": 300,
	"rarity": "rare",
	"seed": "big_spike_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [2, 13],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "big_spike",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "big_spike_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [2, 13],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(2, 13),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"spike": {
	"block_health": 3,
	"category": "block",
	"collidable": true,
	"display_name": "Hanging Spike",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "spike",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 7]
			},
			{
				"item_id": "spike_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			}
		]
	},
	"hazard_instant_death": true,
	"instant_death": true,
	"order": 301,
	"rarity": "uncommon",
	"seed": "spike_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [1, 13],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "spike",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "spike_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [1, 13],
		"cell_size": [32, 32]
	},
	"atlas_coords": Vector2i(1, 13),
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"death_gate": {
		"category": "block",
		"display_name": "Death Gate",
		"rarity": "rare",
		"block_health": 4,
		"atlas_coords": Vector2i(12, 13),
		"seed": "",
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"punch_toggle_block": true,
		"toggle_active_block": "death_gate_active",
		"toggle_inactive_block": "death_gate",
		"toggle_drop_block": "death_gate",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "death_gate", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 302
	},
"death_gate_active": {
		"category": "block",
		"display_name": "Death Gate",
		"rarity": "rare",
		"block_health": 4,
		"atlas_coords": Vector2i(13, 13),
		"seed": "",
		"hidden": true,
		"placeable": false,
		"dropable": false,
		"tradeable": false,
		"admin_grantable": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "death_gate_active",
		"toggle_inactive_block": "death_gate",
		"toggle_drop_block": "death_gate",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "death_gate", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 303
	},
"biohazard_barrel": {
		"category": "block",
		"display_name": "Biohazard Barrel",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/tier_3/biohazard_barrel.png",
		"seed": "biohazard_barrel_seed",
		"collidable": true,
		"break_effect_frames": ["res://Assets/blocks/tier_3/biohazard_barrel_1.png", "res://Assets/blocks/tier_3/biohazard_barrel_2.png"],
		"break_effect_frame_seconds": 0.28,
		"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"biohazard_barrel","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"biohazard_barrel_seed","item_category":"seed","amount":1,"chance":0.2}]},
		"order": 302
	,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"biohazard_barrel","item_category":"block","amount_range":[2,5]},{"item_id":"biohazard_barrel_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
"blue_mail_box": {
		"category": "block",
		"display_name": "Blue Mailbox",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/tier_3/blue_mail_box_empty.png",
		"inventory_icon": "res://Assets/blocks/tier_3/blue_mail_box_full.png",
		"mailbox_empty_texture": "res://Assets/blocks/tier_3/blue_mail_box_empty.png",
		"mailbox_full_texture": "res://Assets/blocks/tier_3/blue_mail_box_full.png",
		"seed": "blue_mail_box_seed",
		"no_collision": true,
		"collidable": false,
		"mailbox_block": true,
		"mailbox_capacity": 20,
		"interact_rules": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "blue_mail_box", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 303
	},
"bulletin_board": {
		"category": "block",
		"display_name": "Bulletin Board",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/tier_3/bulletin_board.png",
		"seed": "",
		"collidable": true,
		"bulletin_board_block": true,
		"bulletin_board_capacity": 30,
		"interact_rules": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "bulletin_board", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 304
	},
"saw_blade": {
	"animation_frame_seconds": 0.045,
	"animation_frames": ["res://Assets/blocks/tier_3/saw_blade.png", "res://Assets/blocks/tier_3/saw_blade_1.png", "res://Assets/blocks/tier_3/saw_blade_2.png", "res://Assets/blocks/tier_3/saw_blade_3.png"],
	"atlas_coords": Vector2i(0, 13),
	"block_health": 3,
	"category": "block",
	"collidable": true,
	"display_name": "Spike",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "saw_blade",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [1, 7]
			},
			{
				"item_id": "saw_blade_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			}
		]
	},
	"hazard_instant_death": true,
	"instant_death": true,
	"order": 304,
	"rarity": "rare",
	"seed": "saw_blade_seed",
	"texture": {
		"atlas": "res://image.png",
		"cell": [0, 13],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "saw_blade",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "saw_blade_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"place_layer": "foreground",
	"background_block": false,
	"no_collision": false,
	"solid": true,
	"collision_type": "full",
	"platform_collision": false,
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [0, 13],
		"cell_size": [32, 32]
	},
	"atlas_source_id": 0,
	"source_id": 0,
	"authored_drop_rules": true
},
"slime": {
		"category": "block",
		"display_name": "Slime",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/tier_3/slime.png",
		"atlas_coords": Vector2i(5, 13),
		"seed": "slime_seed",
		"collidable": true,
		"slow_surface": true,
		"movement_speed_multiplier": 0.55,
		"jump_velocity_multiplier": 0.62,
		"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"slime","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"slime_seed","item_category":"seed","amount":1,"chance":0.2}]},
		"order": 305
	,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"slime","item_category":"block","amount_range":[2,5]},{"item_id":"slime_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
"pinball": {
		"category": "block",
		"display_name": "Pinball",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/tier_3/pinball_1.png",
		"atlas_coords": Vector2i(3, 13),
		"inventory_icon": "res://Assets/blocks/tier_3/pinball_1.png",
		"seed": "",
		"collidable": true,
		"pinball_block": true,
		"pinball_knockback_velocity": 335.0,
		"pinball_vertical_velocity": -335.0,
		"springboard_animation_frames": ["res://Assets/blocks/tier_3/pinball_1.png", "res://Assets/blocks/tier_3/pinball_2.png", "res://Assets/blocks/tier_3/pinball_1.png", "res://Assets/blocks/tier_3/pinball_2.png", "res://Assets/blocks/tier_3/pinball_1.png", "res://Assets/blocks/tier_3/pinball_2.png", "res://Assets/blocks/tier_3/pinball_1.png"],
		"springboard_animation_atlas_frames": [
			Vector2i(3, 13),
			Vector2i(4, 13),
			Vector2i(3, 13),
			Vector2i(4, 13),
			Vector2i(3, 13),
			Vector2i(4, 13),
			Vector2i(3, 13)
		],
		"springboard_animation_frame_seconds": 0.07,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "pinball", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 306
	},
"mail_box": {
		"category": "block",
		"display_name": "Mailbox",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/tier_3/mail_box_empty.png",
		"inventory_icon": "res://Assets/blocks/tier_3/mail_box_full.png",
		"mailbox_empty_texture": "res://Assets/blocks/tier_3/mail_box_empty.png",
		"mailbox_full_texture": "res://Assets/blocks/tier_3/mail_box_full.png",
		"seed": "mail_box_seed",
		"no_collision": true,
		"collidable": false,
		"mailbox_block": true,
		"mailbox_capacity": 20,
		"interact_rules": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "mail_box", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 307
	},
"display_box": {
		"category": "block",
		"display_name": "Display Box",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/tier_3/display_box.png",
		"atlas_coords": Vector2i(0, 14),
		"seed": "",
		"collidable": true,
		"display_block": true,
		"display_preview_max_size": 28.0,
		"display_preview_alpha": 1.0,
		"display_glass_alpha": 0.0,
		"display_glass_size": Vector2(27, 27),
		"display_preview_offset": Vector2(0, 0),
		"interact_rules": true,
		"permissions": {"world_owner_only": true},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "display_box", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
		},
		"order": 308
	},
	"display_case": {
			"category": "block",
			"display_name": "Display Case",
			"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/tier_3/display_case.png",
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"display_block": true,
		"display_preview_max_size": 28.0,
		"display_preview_alpha": 1.0,
		"display_glass_alpha": 0.0,
		"display_glass_size": Vector2(30, 30),
		"display_preview_offset": Vector2(0, 0),
		"interact_rules": true,
		"permissions": {"world_owner_only": true},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [0, 0],
			"fixed_drops": [
				{"item_id": "display_case", "item_category": "block", "amount": 1},
				{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
			]
			},
			"order": 309
		},
	"tackle_box": {
			"category": "block",
			"display_name": "Tackle Box",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/items/fishing/tackle_box_empty.png",
			"inventory_icon": "res://Assets/items/fishing/tackle_box_full.png",
			"tackle_box_empty_texture": "res://Assets/items/fishing/tackle_box_empty.png",
			"tackle_box_full_texture": "res://Assets/items/fishing/tackle_box_full.png",
			"seed": "",
			"shop_price": 9500,
			"no_collision": true,
			"collidable": false,
			"tackle_box_block": true,
			"tackle_box_cooldown_seconds": 14400.0,
			"tackle_box_reward_count": 5,
			"interact_rules": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "tackle_box", "item_category": "block", "amount": 1}
				]
			},
			"order": 310
		},
	"chicken": {
			"category": "block",
			"display_name": "Chicken",
			"rarity": "rare",
			"block_health": 3,
			"texture": "res://image.png",
			"atlas_item_id": 20,
			"atlas_coords": Vector2i(7, 21),
			"chicken_hungry_atlas_coords": Vector2i(9, 21),
			"chicken_producing_atlas_coords": Vector2i(7, 21),
			"chicken_ready_atlas_coords": Vector2i(8, 21),
			"seed": "chicken_seed",
			"no_collision": true,
			"collidable": false,
			"chicken_block": true,
			"chicken_feed_item_id": "grain",
			"chicken_feed_item_category": "material",
			"chicken_production_seconds": 43200.0,
			"chicken_hunger_seconds": 604800.0,
			"chicken_reward_item_id": "egg",
			"chicken_golden_reward_item_id": "golden_egg",
			"chicken_golden_reward_chance": 0.01,
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"chicken","item_category":"block","amount":1},{"item_id":"chicken_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]},
			"order": 311
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"chicken","item_category":"block","amount_range":[2,5]},{"item_id":"chicken_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"cow": {
			"category": "block",
			"display_name": "Cow",
			"rarity": "rare",
			"block_health": 3,
			"texture": "res://image.png",
			"atlas_item_id": 21,
			"atlas_coords": Vector2i(7, 22),
			"cow_hungry_atlas_coords": Vector2i(9, 22),
			"cow_producing_atlas_coords": Vector2i(7, 22),
			"cow_ready_atlas_coords": Vector2i(8, 22),
			"seed": "cow_seed",
			"no_collision": true,
			"collidable": false,
			"cow_block": true,
			"cow_feed_item_id": "wheat",
			"cow_feed_item_category": "material",
			"cow_production_seconds": 43200.0,
			"cow_hunger_seconds": 604800.0,
			"cow_reward_item_id": "milk",
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"cow","item_category":"block","amount":1},{"item_id":"cow_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]},
			"order": 312
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"cow","item_category":"block","amount_range":[2,5]},{"item_id":"cow_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"duck": {
			"category": "block",
			"display_name": "Duck",
			"rarity": "rare",
			"block_health": 3,
			"texture": "res://image.png",
			"atlas_item_id": 31,
			"atlas_coords": Vector2i(10, 21),
			"duck_hungry_atlas_coords": Vector2i(12, 21),
			"duck_producing_atlas_coords": Vector2i(10, 21),
			"duck_ready_atlas_coords": Vector2i(11, 21),
			"seed": "duck_seed",
			"no_collision": true,
			"collidable": false,
			"duck_block": true,
			"duck_feed_item_id": "grain",
			"duck_feed_item_category": "material",
			"duck_production_seconds": 43200.0,
			"duck_hunger_seconds": 604800.0,
			"duck_reward_table": "fishing",
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"duck","item_category":"block","amount":1},{"item_id":"duck_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]},
			"order": 313
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"duck","item_category":"block","amount_range":[2,5]},{"item_id":"duck_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
		"bone": {
			"category": "block",
			"display_name": "Bone",
			"rarity": "common",
			"block_health": 1,
			"texture": "res://image.png",
			"atlas_item_id": 23,
			"atlas_coords": Vector2i(6, 22),
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "bone", "item_category": "block", "amount": 1}
				]
			},
			"order": 313
		},
	"white_fence": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "Farm Fence",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				3,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				3,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_item_id": 24,
		"atlas_coords": [
			3,
			22
		],
		"seed": "white_fence_seed",
		"no_collision": true,
		"collidable": false,
		"foreground_over_player": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_fence",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "white_fence_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"drops_self": true,
		"order": 314,
		"background_block": false,
		"solid": false,
		"collision_type": "none",
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_fence",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "white_fence_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"sugar_cane": {
			"category": "block",
			"display_name": "Sugarcane",
			"rarity": "common",
			"block_health": 2,
			"texture": "res://image.png",
			"atlas_item_id": 25,
			"atlas_coords": Vector2i(4, 22),
			"vertical_variant_atlas_coords": {
				"single": Vector2i(4, 22),
				"top": Vector2i(5, 22),
				"middle": Vector2i(5, 23),
				"bottom": Vector2i(4, 23)
			},
			"seed": "sugar_cane_seed",
			"authored_drop_rules": true,
			"no_collision": true,
			"collidable": false,
			"solid": false,
			"collision_type": "none",
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "sugar_cane", "item_category": "block", "amount_range": [1, 5]},
					{"item_id": "sugar_cane_seed", "item_category": "seed", "amount_range": [0, 3]},
					{"item_id": "gem", "item_category": "currency", "amount_range": [0, 10]}
				]
			},
			"tree_drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "sugar_cane", "item_category": "block", "amount_range": [1, 5]},
					{"item_id": "sugar_cane_seed", "item_category": "seed", "amount_range": [0, 3]},
					{"item_id": "gem", "item_category": "currency", "amount_range": [0, 10]}
				]
			},
			"order": 315
		},
	"street_lamp": {
			"category": "block",
			"display_name": "Street Lamp",
			"rarity": "uncommon",
			"block_health": 3,
			"texture": "res://image.png",
			"inventory_icon": "res://image.png",
			"atlas_item_id": 53,
			"atlas_coords": Vector2i(16, 31),
			"vertical_variant_atlas_coords": {
				"single": Vector2i(16, 31),
				"top": Vector2i(15, 29),
				"middle": Vector2i(15, 30),
				"bottom": Vector2i(15, 31)
			},
			"seed": "street_lamp_seed",
			"no_collision": true,
			"collidable": false,
			"solid": false,
			"collision_type": "none",
			"foreground_over_player": false,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "street_lamp", "item_category": "block", "amount_range": [1, 3]},
					{"item_id": "street_lamp_seed", "item_category": "seed", "amount_range": [0, 2]},
					{"item_id": "gem", "item_category": "currency", "amount_range": [0, 5]}
				]
			},
			"tree_drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "street_lamp", "item_category": "block", "amount_range": [1, 3]},
					{"item_id": "street_lamp_seed", "item_category": "seed", "amount_range": [0, 2]},
					{"item_id": "gem", "item_category": "currency", "amount_range": [0, 5]}
				]
			},
			"order": 427
		},
	"fire_escape": {
			"category": "block",
			"display_name": "Fire Escape",
			"rarity": "uncommon",
			"block_health": 3,
			"texture": "res://image.png",
			"inventory_icon": "res://image.png",
			"atlas_item_id": 54,
			"atlas_coords": Vector2i(16, 29),
			"seed": "fire_escape_seed",
			"platform_collision": true,
			"connected_variant_atlas_coords": {
				"single": Vector2i(16, 29),
				"left": Vector2i(17, 29),
				"horizontal_middle": Vector2i(18, 29),
				"right": Vector2i(19, 29),
				"top": Vector2i(16, 30),
				"vertical_middle": Vector2i(16, 30),
				"bottom": Vector2i(16, 29),
				"top_left_corner": Vector2i(17, 30),
				"top_right_corner": Vector2i(19, 30),
				"bottom_left_corner": Vector2i(17, 29),
				"bottom_right_corner": Vector2i(19, 29),
				"middle": Vector2i(18, 30),
				"tile_top_left_corner": Vector2i(17, 30),
				"tile_top_middle": Vector2i(18, 30),
				"tile_top_right_corner": Vector2i(19, 30),
				"tile_middle_left": Vector2i(17, 30),
				"tile_middle_middle": Vector2i(18, 30),
				"tile_middle_right": Vector2i(19, 30),
				"tile_bottom_left_corner": Vector2i(17, 29),
				"tile_bottom_middle": Vector2i(18, 29),
				"tile_bottom_right_corner": Vector2i(19, 29)
			},
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"fire_escape","item_category":"block","amount":1},{"item_id":"fire_escape_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]},
			"order": 428
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"fire_escape","item_category":"block","amount_range":[2,5]},{"item_id":"fire_escape_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"city_fence": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "Gothic Fence",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				29
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				20,
				29
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_item_id": 55,
		"atlas_coords": [
			20,
			29
		],
		"seed": "city_fence_seed",
		"no_collision": true,
		"collidable": false,
		"foreground_over_player": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "city_fence",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "city_fence_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"drops_self": true,
		"order": 429,
		"background_block": false,
		"solid": false,
		"collision_type": "none",
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "city_fence",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "city_fence_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"fire_hydrant": {
			"category": "block",
			"display_name": "Fire Hydrant",
			"rarity": "uncommon",
			"block_health": 2,
			"texture": "res://image.png",
			"inventory_icon": "res://image.png",
			"atlas_item_id": 56,
			"atlas_coords": Vector2i(17, 31),
			"seed": "fire_hydrant_seed",
			"collidable": true,
			"springboard": true,
			"springboard_velocity": -420.0,
			"springboard_animation_atlas_frames": [
				Vector2i(17, 31),
				Vector2i(18, 31)
			],
			"springboard_animation_frame_seconds": 0.22,
			"springboard_water_splash": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"fire_hydrant","item_category":"block","amount":1},{"item_id":"fire_hydrant_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]},
			"order": 430
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"fire_hydrant","item_category":"block","amount_range":[2,5]},{"item_id":"fire_hydrant_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"shifty_block": {
	"alternative_tile": 0,
	"atlas_coords": Vector2i(10, 8),
	"atlas_item_id": 57,
	"atlas_source_id": 0,
	"block_health": 3,
	"category": "block",
	"collidable": true,
	"collision_offset": [0, 0],
	"collision_size": [32, 32],
	"collision_type": "full",
	"colour_cycle_block": true,
	"colour_cycle_saturation": 0.85,
	"colour_cycle_speed": 0.08,
	"colour_cycle_value": 1,
	"display_name": "RGB Block",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "shifty_block",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "shifty_block_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"inventory_icon": {
		"atlas": "res://image.png",
		"cell": [10, 8],
		"cell_size": [32, 32]
	},
	"order": 431,
	"place_layer": "foreground",
	"rarity": "rare",
	"seed": "shifty_block_seed",
	"solid": true,
	"source_id": 0,
	"texture": {
		"atlas": "res://image.png",
		"cell": [10, 8],
		"cell_size": [32, 32]
	},
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "shifty_block",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "shifty_block_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"background_block": false,
	"no_collision": false,
	"platform_collision": false,
	"authored_drop_rules": true
},
	"barn_block": {"item_id":"barn_block","category":"block","rarity":"common","stack_limit":400,"tradeable":true,"dropable":true,"admin_grantable":true,"hidden":false,"equipment_slot":"","gem_value":0,"sell_value":0,"shop_price":0,"permissions":{},"placeable":true,"place_layer":"foreground","block_health":4,"breakable":true,"display_name":"Barn Block","background_block":false,"no_collision":false,"collidable":true,"solid":true,"collision_type":"full","atlas_item_id":26,"atlas_source_id":0,"atlas_coords":[0,24],"alternative_tile":0,"seed":"barn_block_seed","drop_rules":{"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"barn_block","item_category":"block","amount_range":[0,4]},{"item_id":"barn_block_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]},"tree_drop_rules":{"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"barn_block","item_category":"block","amount_range":[0,4]},{"item_id":"barn_block_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]},"connected_variant_atlas_coords":{"single":[0,24],"tile_1_24":[1,24],"tile_2_24":[2,24],"tile_3_24":[3,24],"tile_4_24":[4,24],"tile_5_24":[5,24],"tile_6_24":[6,24],"tile_7_24":[7,24],"tile_8_24":[8,24],"tile_9_24":[9,24],"tile_0_25":[0,25],"tile_1_25":[1,25],"tile_2_25":[2,25],"tile_3_25":[3,25],"tile_4_25":[4,25],"tile_5_25":[5,25],"tile_6_25":[6,25],"tile_7_25":[7,25],"tile_8_25":[8,25],"tile_9_25":[9,25],"tile_0_26":[0,26],"tile_1_26":[1,26],"tile_2_26":[2,26],"tile_3_26":[3,26],"tile_4_26":[4,26],"tile_5_26":[5,26],"tile_6_26":[6,26],"tile_7_26":[7,26],"tile_8_26":[8,26],"tile_9_26":[9,26],"tile_0_27":[0,27],"tile_1_27":[1,27],"tile_2_27":[2,27],"tile_3_27":[3,27],"tile_4_27":[4,27],"tile_5_27":[5,27],"tile_6_27":[6,27],"tile_7_27":[7,27],"tile_8_27":[8,27],"tile_9_27":[9,27],"tile_0_28":[0,28],"tile_1_28":[1,28],"tile_2_28":[2,28],"tile_3_28":[3,28],"tile_4_28":[4,28],"tile_5_28":[5,28],"tile_6_28":[6,28],"tile_7_28":[7,28]},"texture":{"atlas":"res://image.png","cell":[0,24],"cell_size":[32,32]},"inventory_icon":{"atlas":"res://image.png","cell":[0,24],"cell_size":[32,32]},"order":316,"recipe_tier":4,"atlas_enabled":true},
	"neon_block": {"item_id":"neon_block","category":"block","rarity":"common","stack_limit":400,"tradeable":true,"dropable":true,"admin_grantable":true,"hidden":false,"equipment_slot":"","gem_value":0,"sell_value":0,"shop_price":0,"permissions":{},"placeable":true,"place_layer":"foreground","block_health":4,"breakable":true,"display_name":"Neon Block","background_block":false,"no_collision":false,"collidable":true,"solid":true,"collision_type":"full","atlas_item_id":211,"atlas_source_id":0,"atlas_coords":[0,33],"alternative_tile":0,"seed":"neon_block_seed","drop_rules":{"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"neon_block","item_category":"block","amount_range":[0,4]},{"item_id":"neon_block_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]},"tree_drop_rules":{"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"neon_block","item_category":"block","amount_range":[0,4]},{"item_id":"neon_block_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]},"connected_variant_atlas_coords":{"single":[0,33],"tile_1_24":[1,33],"tile_2_24":[2,33],"tile_3_24":[3,33],"tile_4_24":[4,33],"tile_5_24":[5,33],"tile_6_24":[6,33],"tile_7_24":[7,33],"tile_8_24":[8,33],"tile_9_24":[9,33],"tile_0_25":[0,34],"tile_1_25":[1,34],"tile_2_25":[2,34],"tile_3_25":[3,34],"tile_4_25":[4,34],"tile_5_25":[5,34],"tile_6_25":[6,34],"tile_7_25":[7,34],"tile_8_25":[8,34],"tile_9_25":[9,34],"tile_0_26":[0,35],"tile_1_26":[1,35],"tile_2_26":[2,35],"tile_3_26":[3,35],"tile_4_26":[4,35],"tile_5_26":[5,35],"tile_6_26":[6,35],"tile_7_26":[7,35],"tile_8_26":[8,35],"tile_9_26":[9,35],"tile_0_27":[0,36],"tile_1_27":[1,36],"tile_2_27":[2,36],"tile_3_27":[3,36],"tile_4_27":[4,36],"tile_5_27":[5,36],"tile_6_27":[6,36],"tile_7_27":[7,36],"tile_8_27":[8,36],"tile_9_27":[9,36],"tile_0_28":[0,37],"tile_1_28":[1,37],"tile_2_28":[2,37],"tile_3_28":[3,37],"tile_4_28":[4,37],"tile_5_28":[5,37],"tile_6_28":[6,37],"tile_7_28":[7,37]},"texture":{"atlas":"res://image.png","cell":[0,33],"cell_size":[32,32]},"inventory_icon":{"atlas":"res://image.png","cell":[0,33],"cell_size":[32,32]},"order":316,"recipe_tier":7,"atlas_enabled":true},
	"neon_block_seed": {"category":"seed","display_name":"Neon Block Seed","rarity":"common","texture":"res://Assets/seeds/seed_box.png","seed_box_icon":true,"grows_into":"neon_block","grow_time":150,"max_grow_time":150,"recipe_tier":7},
	"barn_door": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "Barn Door",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				0,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				0,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_item_id": 27,
		"atlas_coords": [
			0,
			21
		],
		"seed": "barn_door_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"door_block": true,
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit or enter door."
		},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "barn_door",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "barn_door_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "barn_door",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "barn_door_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"drops_self": true,
		"order": 317,
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false
	},
	"barn_background": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 2,
		"breakable": true,
		"seed": "barn_background_seed",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "barn_background",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "barn_background_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Barn Wall",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				2,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				2,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_item_id": 28,
		"atlas_coords": [
			2,
			26
		],
		"solid": false,
		"collision_type": "none",
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "barn_background",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "barn_background_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"drops_self": true,
		"order": 318,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false
	},
	"barn_window": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 2,
		"breakable": true,
		"seed": "barn_window_seed",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "barn_window",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "barn_window_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Barn Window",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				0,
				20
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				0,
				20
			],
			"cell_size": [
				32,
				32
			]
		},
		"atlas_item_id": 29,
		"atlas_coords": [
			0,
			20
		],
		"solid": false,
		"collision_type": "none",
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "barn_window",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "barn_window_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"drops_self": true,
		"order": 319,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false
	},
	"water_well": {
			"category": "block",
			"display_name": "Water Well",
			"rarity": "rare",
			"block_health": 3,
			"texture": {"atlas": "res://image.png", "cell": [6, 20], "cell_size": [32, 32]},
			"inventory_icon": {"atlas": "res://image.png", "cell": [6, 20], "cell_size": [32, 32]},
			"atlas_item_id": 30,
			"atlas_coords": Vector2i(6, 20),
			"water_well_producing_atlas_coords": Vector2i(6, 20),
			"water_well_ready_atlas_coords": Vector2i(7, 20),
			"seed": "water_well_seed",
			"no_collision": true,
			"collidable": false,
			"water_well_block": true,
			"water_well_cooldown_seconds": 300.0,
			"water_well_reward_item_id": "water_bucket",
			"water_well_reward_item_category": "block",
			"water_well_reward_amount_range": [1, 15],
			"interact_rules": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "water_well", "item_category": "block", "amount": 1}
				]
			},
			"tree_drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "water_well", "item_category": "block", "amount": 1}
				]
			},
			"order": 320
		},
	"checkpoint": {
			"category": "block",
			"display_name": "Checkpoint",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/checkpoint_1.png",
			"atlas_coords": Vector2i(9, 14),
			"checkpoint_inactive_atlas_coords": Vector2i(9, 14),
			"checkpoint_active_atlas_coords": Vector2i(10, 14),
			"inventory_icon": "res://Assets/blocks/tier_4/checkpoint_1.png",
			"checkpoint_inactive_texture": "res://Assets/blocks/tier_4/checkpoint_1.png",
			"checkpoint_active_texture": "res://Assets/blocks/tier_4/checkpoint_2.png",
			"seed": "checkpoint_seed",
			"no_collision": true,
			"collidable": false,
			"checkpoint_block": true,
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"checkpoint","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"checkpoint_seed","item_category":"seed","amount":1,"chance":0.2}]},
			"order": 399
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"checkpoint","item_category":"block","amount_range":[2,5]},{"item_id":"checkpoint_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"star_checkpoint": {
			"category": "block",
			"display_name": "Star Checkpoint",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/star_checkpoint_1.png",
			"atlas_coords": Vector2i(11, 14),
			"checkpoint_inactive_atlas_coords": Vector2i(11, 14),
			"checkpoint_active_atlas_coords": Vector2i(12, 14),
			"inventory_icon": "res://Assets/blocks/tier_4/star_checkpoint_1.png",
			"checkpoint_inactive_texture": "res://Assets/blocks/tier_4/star_checkpoint_1.png",
			"checkpoint_active_texture": "res://Assets/blocks/tier_4/star_checkpoint_2.png",
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"checkpoint_block": true,
			"interact_rules": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "star_checkpoint", "item_category": "block", "amount": 1},
					{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
				]
			},
			"order": 399
		},
	"dice_block": {
			"category": "block",
			"display_name": "Dice Block",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/dice_1.png",
			"atlas_coords": Vector2i(9, 15),
			"inventory_icon": "res://Assets/blocks/tier_4/dice_6.png",
			"dice_face_textures": ["res://Assets/blocks/tier_4/dice_1.png", "res://Assets/blocks/tier_4/dice_2.png", "res://Assets/blocks/tier_4/dice_3.png", "res://Assets/blocks/tier_4/dice_4.png", "res://Assets/blocks/tier_4/dice_5.png", "res://Assets/blocks/tier_4/dice_6.png"],
			"dice_roll_frame_seconds": 0.08,
			"dice_roll_duration_seconds": 1.05,
			"seed": "dice_block_seed",
			"collidable": true,
			"dice_block": true,
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"dice_block","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"dice_block_seed","item_category":"seed","amount":1,"chance":0.2}]},
			"order": 400
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"dice_block","item_category":"block","amount_range":[2,5]},{"item_id":"dice_block_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"blue_portal": {
			"category": "block",
			"display_name": "Blue Portal",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/blue_portal_1.png",
			"inventory_icon": "res://Assets/blocks/tier_4/blue_portal_1.png",
			"animation_frames": ["res://Assets/blocks/tier_4/blue_portal_1.png", "res://Assets/blocks/tier_4/blue_portal_2.png", "res://Assets/blocks/tier_4/blue_portal_3.png", "res://Assets/blocks/tier_4/blue_portal_4.png"],
			"animation_frame_seconds": 0.12,
			"seed": "blue_portal_seed",
			"no_collision": true,
			"collidable": false,
			"door_block": true,
			"portal_block": true,
			"auto_door_enter": true,
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"blue_portal","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"blue_portal_seed","item_category":"seed","amount":1,"chance":0.2}]},
			"order": 401
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"blue_portal","item_category":"block","amount_range":[2,5]},{"item_id":"blue_portal_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"yellow_portal": {
			"category": "block",
			"display_name": "Yellow Portal",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/yello_portal_1.png",
			"inventory_icon": "res://Assets/blocks/tier_4/yello_portal_1.png",
			"animation_frames": ["res://Assets/blocks/tier_4/yello_portal_1.png", "res://Assets/blocks/tier_4/yello_portal_2.png", "res://Assets/blocks/tier_4/yello_portal_3.png", "res://Assets/blocks/tier_4/yello_portal_4.png"],
			"animation_frame_seconds": 0.12,
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"door_block": true,
			"portal_block": true,
			"auto_door_enter": true,
			"interact_rules": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "yellow_portal", "item_category": "block", "amount": 1},
					{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
				]
			},
			"order": 402
		},
	"bomb": {
			"category": "block",
			"display_name": "Bomb",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/bomb.png",
			"inventory_icon": "res://Assets/blocks/tier_4/bomb.png",
			"seed": "bomb_seed",
			"collidable": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"bomb","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"bomb_seed","item_category":"seed","amount":1,"chance":0.2}]},
			"order": 403
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"bomb","item_category":"block","amount_range":[2,5]},{"item_id":"bomb_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"display_shelf": {
			"category": "block",
			"display_name": "Display Shelf",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/display_shelf.png",
			"atlas_coords": Vector2i(11, 13),
			"inventory_icon": "res://Assets/blocks/tier_4/display_shelf.png",
			"seed": "",
			"collidable": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "display_shelf", "item_category": "block", "amount": 1},
					{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
				]
			},
			"order": 404
		},
	"fish_hanger": {
			"category": "block",
			"display_name": "Fish Hanger",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://image.png",
			"inventory_icon": {"atlas": "res://image.png", "cell": Vector2i(10, 13), "cell_size": Vector2i(32, 32)},
			"atlas_item_id": 34,
			"atlas_source_id": 0,
			"source_id": 0,
			"atlas_coords": Vector2i(10, 13),
			"alternative_tile": 0,
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"display_block": true,
			"fish_hanger_block": true,
			"display_preview_max_size": 18.0,
			"display_preview_alpha": 1.0,
			"display_preview_offset": Vector2(0, 2),
			"display_glass_alpha": 0.0,
			"interact_rules": true,
			"permissions": {"world_owner_only": true},
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "fish_hanger", "item_category": "block", "amount": 1},
					{"item_id": "gem", "item_category": "currency", "amount_range": [1, 7]}
				]
			},
			"order": 405
		},
	"password_door": {
			"category": "block",
			"display_name": "Password Door",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/password_door.png",
			"atlas_coords": Vector2i(8, 15),
			"inventory_icon": "res://Assets/blocks/tier_4/password_door.png",
			"seed": "password_door_seed",
			"no_collision": true,
			"collidable": false,
			"door_block": true,
			"password_door": true,
			"interact_rules": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"password_door","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"password_door_seed","item_category":"seed","amount":1,"chance":0.2}]},
			"order": 406
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"password_door","item_category":"block","amount_range":[2,5]},{"item_id":"password_door_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"star_block": {
			"category": "block",
			"display_name": "Star Block",
			"rarity": "rare",
			"block_health": 4,
			"texture": "res://Assets/blocks/tier_4/star_block.png",
			"atlas_coords": Vector2i(9, 13),
			"inventory_icon": "res://Assets/blocks/tier_4/star_block.png",
			"seed": "star_block_seed",
			"collidable": true,
			"drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"star_block","item_category":"block","amount":1},{"item_id":"gem","item_category":"currency","amount_range":[1,7]},{"item_id":"star_block_seed","item_category":"seed","amount":1,"chance":0.2}]},
			"order": 407
		,
"authored_drop_rules": true
,
"tree_drop_rules": {"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"star_block","item_category":"block","amount_range":[2,5]},{"item_id":"star_block_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}
},
	"anti_punch": {
			"category": "block",
			"display_name": "Anti-Punch",
			"rarity": "epic",
			"block_health": 4,
			"texture": "res://Assets/blocks/special_blocks/anti_punch/anti_punch_disabled.png",
			"atlas_coords": Vector2i(14, 13),
			"inventory_icon": "res://Assets/blocks/special_blocks/anti_punch/anti_punch_disabled.png",
			"anti_punch_disabled_texture": "res://Assets/blocks/special_blocks/anti_punch/anti_punch_disabled.png",
			"anti_punch_enabled_frames": ["res://Assets/blocks/special_blocks/anti_punch/anti_punch_enabled_1.png", "res://Assets/blocks/special_blocks/anti_punch/anti_punch_enabled_2.png"],
			"anti_punch_frame_seconds": 0.18,
			"seed": "",
			"collidable": true,
			"anti_punch_block": true,
			"interact_rules": true,
			"shop_price": 25000,
			"break_return_to_inventory": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0]
			},
			"order": 408
		},
	"anti_talk": {
			"category": "block",
			"display_name": "Anti-Talk",
			"rarity": "epic",
			"block_health": 4,
			"texture": "res://Assets/blocks/special_blocks/anti_talk/anti_talk_disabled.png",
			"atlas_coords": Vector2i(17, 13),
			"inventory_icon": "res://Assets/blocks/special_blocks/anti_talk/anti_talk_disabled.png",
			"anti_talk_disabled_texture": "res://Assets/blocks/special_blocks/anti_talk/anti_talk_disabled.png",
			"anti_talk_enabled_frames": ["res://Assets/blocks/special_blocks/anti_talk/anti_talk_enabled_1.png", "res://Assets/blocks/special_blocks/anti_talk/anti_talk_enabled_2.png"],
			"anti_talk_frame_seconds": 0.18,
			"seed": "",
			"collidable": true,
			"anti_talk_block": true,
			"interact_rules": true,
			"shop_price": 25000,
			"break_return_to_inventory": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0]
			},
			"order": 409
		},
	"anti_gravity": {
			"category": "block",
			"display_name": "Anti-Gravity",
			"rarity": "legendary",
			"block_health": 4,
			"texture": "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity.png",
			"inventory_icon": "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity.png",
			"anti_gravity_disabled_texture": "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity.png",
			"anti_gravity_enabled_frames": ["res://Assets/blocks/special_blocks/anti_gravity/anti_gravity_1.png", "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity_2.png", "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity_3.png", "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity_4.png", "res://Assets/blocks/special_blocks/anti_gravity/anti_gravity_5.png"],
			"anti_gravity_frame_seconds": 0.12,
			"seed": "",
			"collidable": true,
			"anti_gravity_block": true,
			"interact_rules": true,
			"shop_price": 150000,
			"break_return_to_inventory": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0]
			},
			"order": 410
		},
	"snow_repellent": {
			"category": "block",
			"display_name": "Snow Repellent",
			"rarity": "legendary",
			"block_health": 4,
			"texture": "res://Assets/blocks/special_blocks/snow_repellent/snow_repellent.png",
			"inventory_icon": "res://Assets/blocks/special_blocks/snow_repellent/snow_repellent.png",
			"seed": "",
			"collidable": true,
			"snow_repellent_block": true,
			"shop_price": 75000,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "snow_repellent", "item_category": "block", "amount": 1}
				]
			},
			"order": 411
		},
	"night_theme_machine": {
			"category": "block",
			"display_name": "Night Theme Machine",
			"rarity": "legendary",
			"instance_tracked": true,
			"block_health": 4,
			"atlas_item_id": 37,
			"atlas_source_id": 0,
			"source_id": 0,
			"atlas_coords": Vector2i(17, 7),
			"alternative_tile": 0,
			"texture": {"atlas": "res://image.png", "cell": [17, 7], "cell_size": [32, 32]},
			"inventory_icon": {"atlas": "res://image.png", "cell": [17, 7], "cell_size": [32, 32]},
			"theme_machine_enabled_frames": [
				{"atlas": "res://image.png", "cell": [17, 7], "cell_size": [32, 32]},
				{"atlas": "res://image.png", "cell": [18, 7], "cell_size": [32, 32]}
			],
			"theme_machine_frame_seconds": 0.45,
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"theme_machine_block": true,
			"theme_machine_theme": "night",
			"interact_rules": true,
			"shop_price": 125000,
			"break_return_to_inventory": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0]
			},
			"order": 412
		},
	"snow_theme_machine": {
			"category": "block",
			"display_name": "Snow Theme Machine",
			"rarity": "legendary",
			"instance_tracked": true,
			"block_health": 4,
			"atlas_item_id": 38,
			"atlas_source_id": 0,
			"source_id": 0,
			"atlas_coords": Vector2i(17, 8),
			"alternative_tile": 0,
			"texture": {"atlas": "res://image.png", "cell": [17, 8], "cell_size": [32, 32]},
			"inventory_icon": {"atlas": "res://image.png", "cell": [17, 8], "cell_size": [32, 32]},
			"theme_machine_enabled_frames": [
				{"atlas": "res://image.png", "cell": [17, 8], "cell_size": [32, 32]},
				{"atlas": "res://image.png", "cell": [18, 8], "cell_size": [32, 32]}
			],
			"theme_machine_frame_seconds": 0.45,
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"theme_machine_block": true,
			"theme_machine_theme": "snow",
			"interact_rules": true,
			"shop_price": 125000,
			"break_return_to_inventory": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0]
			},
			"order": 413
		},
	"atm_machine": {
			"category": "block",
			"display_name": "ATM Machine",
			"rarity": "epic",
			"instance_tracked": true,
			"block_health": 4,
			"atlas_item_id": 39,
			"atlas_source_id": 0,
			"source_id": 0,
			"atlas_coords": Vector2i(5, 16),
			"alternative_tile": 0,
			"texture": {"atlas": "res://image.png", "cell": [5, 16], "cell_size": [32, 32]},
			"inventory_icon": {"atlas": "res://image.png", "cell": [5, 16], "cell_size": [32, 32]},
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"atm_machine_block": true,
			"atm_machine_cooldown_seconds": 43200.0,
			"atm_machine_reward_item_id": "gem",
			"atm_machine_reward_item_category": "currency",
			"atm_machine_reward_amount_range": [1, 100],
			"atm_machine_ready_atlas_coords": Vector2i(5, 16),
			"atm_machine_producing_atlas_coords": Vector2i(6, 16),
			"interact_rules": true,
			"shop_price": 12500,
			"break_return_to_inventory": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0]
			},
			"order": 414
		},
	"cctv": {
			"category": "block",
			"display_name": "CCTV",
			"rarity": "epic",
			"block_health": 4,
			"texture": "res://Assets/blocks/special_blocks/cctv/cctv_off.png",
			"inventory_icon": "res://Assets/blocks/special_blocks/cctv/cctv_off.png",
			"cctv_1_texture": "res://Assets/blocks/special_blocks/cctv/cctv_off.png",
			"cctv_2_texture": "res://Assets/blocks/special_blocks/cctv/cctv_on.png",
			"animation_frames": ["res://Assets/blocks/special_blocks/cctv/cctv_off.png", "res://Assets/blocks/special_blocks/cctv/cctv_on.png"],
			"animation_frame_seconds": 0.4,
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"cctv_block": true,
			"interact_rules": true,
			"shop_price": 15000,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "cctv", "item_category": "block", "amount": 1}
				]
			},
			"order": 415
		},
	"oil_refinery": {
	"animation_frame_seconds": 0.18,
	"animation_loop_particle": "oil_refinery_smoke",
	"animation_loop_particle_count": 3,
	"animation_loop_particle_frame_index": 0,
	"animation_loop_particle_min_interval_ms": 900,
	"animation_loop_particle_offset": [-9, -13],
	"animation_loop_particle_texture": "res://Assets/blocks/special_blocks/oil_refinery/smoke.png",
	"block_health": 6,
	"category": "block",
	"collidable": false,
	"display_name": "Oil Refinery",
	"drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "oil_refinery",
				"item_category": "block",
				"amount": 1
			},
			{
				"item_id": "oil_refinery_seed",
				"item_category": "seed",
				"amount": 1,
				"chance": 0.2
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 3]
			}
		]
	},
	"interact_rules": true,
	"inventory_icon": "res://Assets/blocks/special_blocks/oil_refinery/oil_refinery.png",
	"no_collision": true,
	"oil_refinery_block": true,
	"order": 416,
	"rarity": "legendary",
	"running_animation_frames": ["res://Assets/blocks/special_blocks/oil_refinery/oil_refinery_1.png", "res://Assets/blocks/special_blocks/oil_refinery/oil_refinery_2.png", "res://Assets/blocks/special_blocks/oil_refinery/oil_refinery_3.png", "res://Assets/blocks/special_blocks/oil_refinery/oil_refinery_4.png"],
	"seed": "oil_refinery_seed",
	"texture": "res://Assets/blocks/special_blocks/oil_refinery/oil_refinery.png",
	"hidden": false,
	"placeable": true,
	"tradeable": true,
	"dropable": true,
	"admin_grantable": true,
	"break_return_to_inventory": false,
	"tree_drop_rules": {
		"seed_chance": 0,
		"gem_range": [0, 0],
		"fixed_drops": [
			{
				"item_id": "oil_refinery",
				"item_category": "block",
				"amount_range": [2, 5]
			},
			{
				"item_id": "oil_refinery_seed",
				"item_category": "seed",
				"amount_range": [0, 3]
			},
			{
				"item_id": "gem",
				"item_category": "currency",
				"amount_range": [0, 5]
			}
		]
	},
	"authored_drop_rules": true
},
	"battery_charger": {
			"category": "block",
			"display_name": "Battery Charger",
			"rarity": "rare",
			"block_health": 4,
			"texture": {"atlas": "res://image.png", "cell": [4, 17], "cell_size": [32, 32]},
			"inventory_icon": {"atlas": "res://image.png", "cell": [4, 17], "cell_size": [32, 32]},
			"running_animation_frames": [
				{"atlas": "res://image.png", "cell": [5, 17], "cell_size": [32, 32]},
				{"atlas": "res://image.png", "cell": [6, 17], "cell_size": [32, 32]}
			],
			"running_animation_loop_frames": [1, 2],
			"running_animation_frame_seconds": 0.22,
			"seed": "",
			"no_collision": true,
			"collidable": false,
			"battery_charger_block": true,
			"interact_rules": true,
			"drop_rules": {
				"seed_chance": 0,
				"gem_range": [0, 0],
				"fixed_drops": [
					{"item_id": "battery_charger", "item_category": "block", "amount": 1}
				]
			},
			"order": 416
		},
	"blue_couch": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_item_id": 69,
		"atlas_coords": [
			19,
			21
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				19,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "blue_couch_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"connected_variant_atlas_coords": {
			"single": [
				19,
				21
			],
			"left": [
				16,
				21
			],
			"middle": [
				17,
				21
			],
			"horizontal_middle": [
				17,
				21
			],
			"right": [
				18,
				21
			]
		},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "blue_couch",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "blue_couch_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "blue_couch",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "blue_couch_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"display_name": "Couch",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false
	},
	"green_couch": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_item_id": 70,
		"atlas_coords": [
			23,
			21
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				23,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "green_couch_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"connected_variant_atlas_coords": {
			"single": [
				23,
				21
			],
			"left": [
				20,
				21
			],
			"middle": [
				21,
				21
			],
			"horizontal_middle": [
				21,
				21
			],
			"right": [
				22,
				21
			]
		},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "green_couch",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "green_couch_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "green_couch",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "green_couch_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"display_name": "Potato Couch",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false
	},
	"side_table": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 2,
		"breakable": true,
		"atlas_coords": [
			24,
			21
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "side_table_seed",
		"no_collision": false,
		"collidable": true,
		"solid": false,
		"collision_type": "platform",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "side_table",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "side_table_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "House Table",
		"background_block": false,
		"platform_collision": true,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "side_table",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "side_table_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"toilet": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			24,
			22
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "toilet_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "toilet_open",
		"toggle_inactive_block": "toilet",
		"toggle_drop_block": "toilet",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "toilet",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "toilet_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Toilet",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "toilet",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "toilet_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": true
	},
	"toilet_open": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			25,
			22
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "toilet_open",
		"toggle_inactive_block": "toilet",
		"toggle_drop_block": "toilet",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "toilet",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "toilet_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Toilet",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					25,
					22
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				25,
				22
			]
		],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "toilet",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "toilet_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": true,
		"animation_frame_seconds": 0.2
	},
	"refrigerator": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			26,
			22
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				26,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "refrigerator_seed",
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"punch_toggle_block": true,
		"toggle_active_block": "refrigerator_open",
		"toggle_inactive_block": "refrigerator",
		"toggle_drop_block": "refrigerator",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "refrigerator",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "refrigerator_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Refrigerator",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "refrigerator",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "refrigerator_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": true
	},
	"refrigerator_open": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			27,
			22
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				27,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				26,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "",
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"punch_toggle_block": true,
		"toggle_active_block": "refrigerator_open",
		"toggle_inactive_block": "refrigerator",
		"toggle_drop_block": "refrigerator",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "refrigerator",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "refrigerator_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Refrigerator",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					27,
					22
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				27,
				22
			]
		],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "refrigerator",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "refrigerator_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": true,
		"animation_frame_seconds": 0.2
	},
	"fireplace": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			17,
			23
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				17,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "fireplace_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "fireplace_on",
		"toggle_inactive_block": "fireplace",
		"toggle_drop_block": "fireplace",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "fireplace",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "fireplace_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Fireplace",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "fireplace",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "fireplace_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": false
	},
	"fireplace_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			18,
			23
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				17,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"animated": true,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					18,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					19,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					20,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					19,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					18,
					23
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				18,
				23
			],
			[
				19,
				23
			],
			[
				20,
				23
			],
			[
				19,
				23
			],
			[
				18,
				23
			]
		],
		"animation_frame_seconds": 0.2,
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "fireplace_on",
		"toggle_inactive_block": "fireplace",
		"toggle_drop_block": "fireplace",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "fireplace",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "fireplace_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Fireplace",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "fireplace",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "fireplace_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": false
	},
	"bathtub": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			21,
			23
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "bathtub_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "bathtub_on",
		"toggle_inactive_block": "bathtub",
		"toggle_drop_block": "bathtub",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "bathtub",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "bathtub_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Bathtub",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "bathtub",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "bathtub_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": false
	},
	"bathtub_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			22,
			23
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				22,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"animated": true,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					22,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					23,
					23
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				22,
				23
			],
			[
				23,
				23
			]
		],
		"animation_frame_seconds": 0.2,
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "bathtub_on",
		"toggle_inactive_block": "bathtub",
		"toggle_drop_block": "bathtub",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "bathtub",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "bathtub_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Bathtub",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "bathtub",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "bathtub_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": false
	},
	"sink": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			24,
			23
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "sink_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "sink_on",
		"toggle_inactive_block": "sink",
		"toggle_drop_block": "sink",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sink",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sink_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Sink",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sink",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sink_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": true
	},
	"sink_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			25,
			23
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"punch_toggle_block": true,
		"toggle_active_block": "sink_on",
		"toggle_inactive_block": "sink",
		"toggle_drop_block": "sink",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sink",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sink_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Sink",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					25,
					23
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				25,
				23
			]
		],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sink",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sink_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"punch_open_only": true,
		"animation_frame_seconds": 0.2
	},
	"red_brick_platform": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 2,
		"breakable": true,
		"atlas_coords": [
			15,
			24
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				15,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "red_brick_platform_seed",
		"platform_collision": true,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "red_brick_platform",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "red_brick_platform_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Building Brick Platform",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": false,
		"collision_type": "platform",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "red_brick_platform",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "red_brick_platform_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"white_brick_block": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"atlas_coords": [
			16,
			24
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				16,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "white_brick_block_seed",
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"platform_variant_atlas_coords": {
			"left": [
				16,
				24
			],
			"right": [
				17,
				24
			]
		},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_brick_block",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "white_brick_block_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Polished Stone Brick",
		"background_block": false,
		"no_collision": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_brick_block",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "white_brick_block_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"artwork_atlas_variants": [
			[
				16,
				24
			],
			[
				17,
				24
			]
		]
	},
	"white_brick_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 2,
		"breakable": true,
		"atlas_coords": [
			18,
			24
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				18,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "white_brick_wall_seed",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_brick_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "white_brick_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Polished Stone Wall",
		"solid": false,
		"collision_type": "none",
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_brick_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "white_brick_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"white_brick_platform": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 2,
		"breakable": true,
		"atlas_coords": [
			19,
			24
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				19,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "white_brick_platform_seed",
		"platform_collision": true,
		"platform_variant_atlas_coords": {
			"single": [
				19,
				24
			],
			"left": [
				20,
				24
			],
			"middle": [
				21,
				24
			],
			"right": [
				22,
				24
			]
		},
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_brick_platform",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "white_brick_platform_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Polished Stone Platform",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": false,
		"collision_type": "platform",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "white_brick_platform",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "white_brick_platform_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"fan": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 2,
		"breakable": true,
		"atlas_coords": [
			23,
			24
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				23,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"animated": true,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					23,
					24
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					24,
					24
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					23,
					24
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					24,
					24
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				23,
				24
			],
			[
				24,
				24
			],
			[
				23,
				24
			],
			[
				24,
				24
			]
		],
		"animation_frame_seconds": 0.18,
		"seed": "fan_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "fan",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "fan_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Fan",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "fan",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "fan_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"server_triggered_animation": true,
		"animation_trigger": "on_punch"
	},
	"bed": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 2,
		"breakable": true,
		"atlas_coords": [
			25,
			24
		],
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				25,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"seed": "bed_seed",
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "bed",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "bed_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"display_name": "Bed",
		"background_block": false,
		"platform_collision": false,
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "bed",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "bed_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		}
	},
	"barn_window_seed": {
		"category": "seed",
		"display_name": "Barn Window Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				0,
				20
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "barn_window",
		"rarity": "uncommon"
	},
	"white_fence_seed": {
		"category": "seed",
		"display_name": "Farm Fence Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				3,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "white_fence",
		"rarity": "uncommon"
	},
	"weathervane": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Weathervane",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 149,
		"atlas_source_id": 0,
		"atlas_coords": [
			6,
			21
		],
		"alternative_tile": 0,
		"seed": "weathervane_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "weathervane",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "weathervane_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "weathervane",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "weathervane_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				6,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				6,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"weathervane_seed": {
		"category": "seed",
		"display_name": "Weathervane Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				6,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "weathervane",
		"rarity": "uncommon"
	},
	"broken_tv_seed": {
		"category": "seed",
		"display_name": "Landfill TV Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				5,
				19
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "broken_tv",
		"rarity": "uncommon"
	},
	"tires_seed": {
		"category": "seed",
		"display_name": "Used Tires Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				6,
				19
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "tires",
		"rarity": "uncommon"
	},
	"barn_background_seed": {
		"category": "seed",
		"display_name": "Barn Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				2,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "barn_background",
		"rarity": "uncommon"
	},
	"barn_door_seed": {
		"category": "seed",
		"display_name": "Barn Door Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				0,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "barn_door",
		"rarity": "uncommon"
	},
	"side_table_seed": {
		"category": "seed",
		"display_name": "House Table Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "side_table",
		"rarity": "uncommon"
	},
	"modern_chair": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Modern Chair",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 153,
		"atlas_source_id": 0,
		"atlas_coords": [
			25,
			21
		],
		"alternative_tile": 0,
		"seed": "modern_chair_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "modern_chair",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "modern_chair_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "modern_chair",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "modern_chair_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				25,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"modern_chair_seed": {
		"category": "seed",
		"display_name": "Modern Chair Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "modern_chair",
		"rarity": "uncommon"
	},
	"dresser": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Dresser",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": false,
		"collision_type": "platform",
		"atlas_item_id": 154,
		"atlas_source_id": 0,
		"atlas_coords": [
			26,
			21
		],
		"alternative_tile": 0,
		"seed": "dresser_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "dresser",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "dresser_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "dresser",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "dresser_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				26,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": true
	},
	"dresser_seed": {
		"category": "seed",
		"display_name": "Dresser Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				21
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "dresser",
		"rarity": "uncommon"
	},
	"royal_door": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "House Door",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 59,
		"atlas_source_id": 0,
		"atlas_coords": [
			16,
			22
		],
		"alternative_tile": 0,
		"seed": "royal_door_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"order": 433,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "royal_door",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "royal_door_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "royal_door",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "royal_door_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				16,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"door_block": true,
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit or enter door."
		},
		"platform_collision": false
	},
	"grand_house_door": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Grand House Door",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 155,
		"atlas_source_id": 0,
		"atlas_coords": [
			17,
			22
		],
		"alternative_tile": 0,
		"seed": "grand_house_door_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "grand_house_door",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "grand_house_door_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "grand_house_door",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "grand_house_door_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				17,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"door_block": true,
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit or enter door."
		},
		"platform_collision": false
	},
	"grand_house_door_seed": {
		"category": "seed",
		"display_name": "Grand House Door Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "grand_house_door",
		"rarity": "uncommon"
	},
	"royal_entrance": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "House Entrance",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"atlas_item_id": 60,
		"atlas_source_id": 0,
		"atlas_coords": [
			18,
			22
		],
		"alternative_tile": 0,
		"seed": "royal_entrance_seed",
		"authored_drop_rules": true,
		"animation_trigger": "on_enter",
		"break_return_to_inventory": false,
		"order": 434,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "royal_entrance",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "royal_entrance_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "royal_entrance",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "royal_entrance_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				18,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"entrance_block": true,
		"entrance_tilemap_collision": true,
		"entrance_idle_atlas_coords": [
			18,
			22
		],
		"entrance_pass_atlas_coords": [
			18,
			22
		],
		"entrance_pass_atlas_frames": [
			[
				18,
				22
			],
			[
				19,
				22
			],
			[
				20,
				22
			]
		],
		"entrance_pass_animation_columns": 3,
		"entrance_animation_frame_seconds": 0.15,
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Lock or unlock entrance."
		},
		"platform_collision": false,
		"entrance_idle_texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"entrance_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					18,
					22
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					19,
					22
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					20,
					22
				],
				"cell_size": [
					32,
					32
				]
			}
		]
	},
	"royal_window": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "White Window",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 63,
		"atlas_source_id": 0,
		"atlas_coords": [
			21,
			22
		],
		"alternative_tile": 0,
		"seed": "royal_window_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"order": 437,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "royal_window",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "royal_window_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "royal_window",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "royal_window_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"purple_curtains": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "Purple Curtained Window",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 67,
		"atlas_source_id": 0,
		"atlas_coords": [
			22,
			22
		],
		"alternative_tile": 0,
		"seed": "purple_curtains_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"order": 441,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "purple_curtains",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "purple_curtains_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "purple_curtains",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "purple_curtains_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				22,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				22,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"pink_curtains": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 3,
		"breakable": true,
		"display_name": "Pink Curtained Window",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 68,
		"atlas_source_id": 0,
		"atlas_coords": [
			23,
			22
		],
		"alternative_tile": 0,
		"seed": "pink_curtains_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"order": 442,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "pink_curtains",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "pink_curtains_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						2
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "pink_curtains",
					"item_category": "block",
					"amount_range": [
						1,
						3
					]
				},
				{
					"item_id": "pink_curtains_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				23,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"toilet_seed": {
		"category": "seed",
		"display_name": "Toilet Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "toilet",
		"rarity": "uncommon"
	},
	"refrigerator_seed": {
		"category": "seed",
		"display_name": "Refrigerator Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				22
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "refrigerator",
		"rarity": "uncommon"
	},
	"building_brick_block": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Building Brick Block",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"atlas_item_id": 158,
		"atlas_source_id": 0,
		"atlas_coords": [
			15,
			23
		],
		"alternative_tile": 0,
		"seed": "building_brick_block_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "building_brick_block",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "building_brick_block_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "building_brick_block",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "building_brick_block_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				15,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"building_brick_block_seed": {
		"category": "seed",
		"display_name": "Building Brick Block Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "building_brick_block",
		"rarity": "uncommon"
	},
	"building_brick_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Building Brick Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 159,
		"atlas_source_id": 0,
		"atlas_coords": [
			16,
			23
		],
		"alternative_tile": 0,
		"seed": "building_brick_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "building_brick_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "building_brick_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "building_brick_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "building_brick_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				16,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"building_brick_wall_seed": {
		"category": "seed",
		"display_name": "Building Brick Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "building_brick_wall",
		"rarity": "uncommon"
	},
	"fireplace_seed": {
		"category": "seed",
		"display_name": "Fireplace Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "fireplace",
		"rarity": "uncommon"
	},
	"bathtub_seed": {
		"category": "seed",
		"display_name": "Bathtub Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "bathtub",
		"rarity": "uncommon"
	},
	"sink_seed": {
		"category": "seed",
		"display_name": "Sink Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "sink",
		"rarity": "uncommon"
	},
	"rubber_duck": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Rubber Duck",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 163,
		"atlas_source_id": 0,
		"atlas_coords": [
			26,
			23
		],
		"alternative_tile": 0,
		"seed": "rubber_duck_seed",
		"authored_drop_rules": true,
		"server_triggered_animation": true,
		"animation_trigger": "on_punch",
		"break_return_to_inventory": false,
		"animated": true,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					26,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					27,
					23
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					26,
					23
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				26,
				23
			],
			[
				27,
				23
			],
			[
				26,
				23
			]
		],
		"animation_frame_seconds": 0.18,
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "rubber_duck",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "rubber_duck_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "rubber_duck",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "rubber_duck_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				26,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"rubber_duck_seed": {
		"category": "seed",
		"display_name": "Rubber Duck Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				23
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "rubber_duck",
		"rarity": "uncommon"
	},
	"red_brick_platform_seed": {
		"category": "seed",
		"display_name": "Building Brick Platform Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "red_brick_platform",
		"rarity": "uncommon"
	},
	"white_brick_block_seed": {
		"category": "seed",
		"display_name": "Polished Stone Brick Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "white_brick_block",
		"rarity": "uncommon"
	},
	"white_brick_wall_seed": {
		"category": "seed",
		"display_name": "Polished Stone Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "white_brick_wall",
		"rarity": "uncommon"
	},
	"white_brick_platform_seed": {
		"category": "seed",
		"display_name": "Polished Stone Platform Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "white_brick_platform",
		"rarity": "uncommon"
	},
	"fan_seed": {
		"category": "seed",
		"display_name": "Fan Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "fan",
		"rarity": "uncommon"
	},
	"bed_seed": {
		"category": "seed",
		"display_name": "Bed Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				24
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "bed",
		"rarity": "uncommon"
	},
	"park_bench": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Park Bench",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 170,
		"atlas_source_id": 0,
		"atlas_coords": [
			18,
			25
		],
		"alternative_tile": 0,
		"seed": "park_bench_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "park_bench",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "park_bench_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "park_bench",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "park_bench_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				18,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"connected_variant_atlas_coords": {
			"single": [
				18,
				25
			],
			"left": [
				15,
				25
			],
			"middle": [
				16,
				25
			],
			"horizontal_middle": [
				16,
				25
			],
			"right": [
				17,
				25
			]
		}
	},
	"park_bench_seed": {
		"category": "seed",
		"display_name": "Park Bench Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "park_bench",
		"rarity": "uncommon"
	},
	"big_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Big Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 171,
		"atlas_source_id": 0,
		"atlas_coords": [
			23,
			25
		],
		"alternative_tile": 0,
		"seed": "big_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "big_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "big_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "big_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "big_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				23,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit sign."
		},
		"platform_collision": false,
		"sign_block": true
	},
	"big_sign_seed": {
		"category": "seed",
		"display_name": "Big Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "big_sign",
		"rarity": "uncommon"
	},
	"right_directional_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Right Directional Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 172,
		"atlas_source_id": 0,
		"atlas_coords": [
			24,
			25
		],
		"alternative_tile": 0,
		"seed": "right_directional_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "right_directional_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "right_directional_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "right_directional_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "right_directional_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit sign."
		},
		"platform_collision": false,
		"sign_block": true
	},
	"right_directional_sign_seed": {
		"category": "seed",
		"display_name": "Right Directional Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "right_directional_sign",
		"rarity": "uncommon"
	},
	"left_directional_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Left Directional Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 173,
		"atlas_source_id": 0,
		"atlas_coords": [
			25,
			25
		],
		"alternative_tile": 0,
		"seed": "left_directional_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "left_directional_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "left_directional_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "left_directional_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "left_directional_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				25,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit sign."
		},
		"platform_collision": false,
		"sign_block": true
	},
	"left_directional_sign_seed": {
		"category": "seed",
		"display_name": "Left Directional Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "left_directional_sign",
		"rarity": "uncommon"
	},
	"digital_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Digital Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 174,
		"atlas_source_id": 0,
		"atlas_coords": [
			26,
			25
		],
		"alternative_tile": 0,
		"seed": "digital_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "digital_sign_on",
		"toggle_inactive_block": "digital_sign",
		"toggle_drop_block": "digital_sign",
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "digital_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "digital_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "digital_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "digital_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				26,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"digital_sign_seed": {
		"category": "seed",
		"display_name": "Digital Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "digital_sign",
		"rarity": "uncommon"
	},
	"star_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Star Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 175,
		"atlas_source_id": 0,
		"atlas_coords": [
			15,
			26
		],
		"alternative_tile": 0,
		"seed": "star_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "star_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "star_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "star_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "star_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				15,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"star_wall_seed": {
		"category": "seed",
		"display_name": "Star Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "star_wall",
		"rarity": "uncommon"
	},
	"blue_stripe_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Blue Stripe Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 176,
		"atlas_source_id": 0,
		"atlas_coords": [
			16,
			26
		],
		"alternative_tile": 0,
		"seed": "blue_stripe_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "blue_stripe_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "blue_stripe_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "blue_stripe_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "blue_stripe_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				16,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"blue_stripe_wall_seed": {
		"category": "seed",
		"display_name": "Blue Stripe Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "blue_stripe_wall",
		"rarity": "uncommon"
	},
	"red_stripe_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Red Stripe Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 177,
		"atlas_source_id": 0,
		"atlas_coords": [
			17,
			26
		],
		"alternative_tile": 0,
		"seed": "red_stripe_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "red_stripe_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "red_stripe_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "red_stripe_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "red_stripe_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				17,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"red_stripe_wall_seed": {
		"category": "seed",
		"display_name": "Red Stripe Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "red_stripe_wall",
		"rarity": "uncommon"
	},
	"aquatic_line_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Aquatic Line Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 178,
		"atlas_source_id": 0,
		"atlas_coords": [
			18,
			26
		],
		"alternative_tile": 0,
		"seed": "aquatic_line_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "aquatic_line_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "aquatic_line_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "aquatic_line_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "aquatic_line_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				18,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"aquatic_line_wall_seed": {
		"category": "seed",
		"display_name": "Aquatic Line Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "aquatic_line_wall",
		"rarity": "uncommon"
	},
	"complementary_line_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Complementary Line Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 179,
		"atlas_source_id": 0,
		"atlas_coords": [
			19,
			26
		],
		"alternative_tile": 0,
		"seed": "complementary_line_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "complementary_line_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "complementary_line_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "complementary_line_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "complementary_line_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				19,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"complementary_line_wall_seed": {
		"category": "seed",
		"display_name": "Complementary Line Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "complementary_line_wall",
		"rarity": "uncommon"
	},
	"checkered_wall": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "background",
		"block_health": 4,
		"breakable": true,
		"display_name": "Checkered Wall",
		"background_block": true,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 180,
		"atlas_source_id": 0,
		"atlas_coords": [
			20,
			26
		],
		"alternative_tile": 0,
		"seed": "checkered_wall_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "checkered_wall",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "checkered_wall_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "checkered_wall",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "checkered_wall_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				20,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"checkered_wall_seed": {
		"category": "seed",
		"display_name": "Checkered Wall Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "checkered_wall",
		"rarity": "uncommon"
	},
	"sale_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Sale Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 181,
		"atlas_source_id": 0,
		"atlas_coords": [
			23,
			26
		],
		"alternative_tile": 0,
		"seed": "sale_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sale_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sale_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sale_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sale_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				23,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit sign."
		},
		"platform_collision": false,
		"sign_block": true
	},
	"sale_sign_seed": {
		"category": "seed",
		"display_name": "Sale Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				23,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "sale_sign",
		"rarity": "uncommon"
	},
	"hazard_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Hazard Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 182,
		"atlas_source_id": 0,
		"atlas_coords": [
			24,
			26
		],
		"alternative_tile": 0,
		"seed": "hazard_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "hazard_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "hazard_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "hazard_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "hazard_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				24,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit sign."
		},
		"platform_collision": false,
		"sign_block": true
	},
	"hazard_sign_seed": {
		"category": "seed",
		"display_name": "Hazard Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				24,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "hazard_sign",
		"rarity": "uncommon"
	},
	"open_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Open Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 183,
		"atlas_source_id": 0,
		"atlas_coords": [
			25,
			26
		],
		"alternative_tile": 0,
		"seed": "open_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "open_sign_on",
		"toggle_inactive_block": "open_sign",
		"toggle_drop_block": "open_sign",
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "open_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "open_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "open_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "open_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				25,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"open_sign_seed": {
		"category": "seed",
		"display_name": "Open Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				25,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "open_sign",
		"rarity": "uncommon"
	},
	"street_sign": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Street Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 184,
		"atlas_source_id": 0,
		"atlas_coords": [
			27,
			26
		],
		"alternative_tile": 0,
		"seed": "street_sign_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "street_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "street_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "street_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "street_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				27,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				27,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Edit sign."
		},
		"platform_collision": false,
		"sign_block": true
	},
	"street_sign_seed": {
		"category": "seed",
		"display_name": "Street Sign Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				27,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "street_sign",
		"rarity": "uncommon"
	},
	"chandelier": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Chandelier",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 185,
		"atlas_source_id": 0,
		"atlas_coords": [
			15,
			27
		],
		"alternative_tile": 0,
		"seed": "chandelier_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "chandelier_on",
		"toggle_inactive_block": "chandelier",
		"toggle_drop_block": "chandelier",
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "chandelier",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "chandelier_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "chandelier",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "chandelier_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				15,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"chandelier_seed": {
		"category": "seed",
		"display_name": "Chandelier Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "chandelier",
		"rarity": "uncommon"
	},
	"wall_clock": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Wall Clock",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 186,
		"atlas_source_id": 0,
		"atlas_coords": [
			17,
			27
		],
		"alternative_tile": 0,
		"seed": "wall_clock_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "wall_clock",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "wall_clock_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "wall_clock",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "wall_clock_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				17,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"wall_clock_seed": {
		"category": "seed",
		"display_name": "Wall Clock Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "wall_clock",
		"rarity": "uncommon"
	},
	"vines_painting": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Vines Painting",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 187,
		"atlas_source_id": 0,
		"atlas_coords": [
			18,
			27
		],
		"alternative_tile": 0,
		"seed": "vines_painting_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "vines_painting",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "vines_painting_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "vines_painting",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "vines_painting_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				18,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"vines_painting_seed": {
		"category": "seed",
		"display_name": "Vines Painting Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "vines_painting",
		"rarity": "uncommon"
	},
	"scratched_banana_painting": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Scratched Banana Painting",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 188,
		"atlas_source_id": 0,
		"atlas_coords": [
			19,
			27
		],
		"alternative_tile": 0,
		"seed": "scratched_banana_painting_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "scratched_banana_painting",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "scratched_banana_painting_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "scratched_banana_painting",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "scratched_banana_painting_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				19,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"scratched_banana_painting_seed": {
		"category": "seed",
		"display_name": "Scratched Banana Painting Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "scratched_banana_painting",
		"rarity": "uncommon"
	},
	"heartbreak_painting": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Heartbreak Painting",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 189,
		"atlas_source_id": 0,
		"atlas_coords": [
			20,
			27
		],
		"alternative_tile": 0,
		"seed": "heartbreak_painting_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "heartbreak_painting",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "heartbreak_painting_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "heartbreak_painting",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "heartbreak_painting_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				20,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"heartbreak_painting_seed": {
		"category": "seed",
		"display_name": "Heartbreak Painting Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "heartbreak_painting",
		"rarity": "uncommon"
	},
	"love_painting": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Love Painting",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 190,
		"atlas_source_id": 0,
		"atlas_coords": [
			21,
			27
		],
		"alternative_tile": 0,
		"seed": "love_painting_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "love_painting",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "love_painting_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "love_painting",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "love_painting_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"love_painting_seed": {
		"category": "seed",
		"display_name": "Love Painting Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "love_painting",
		"rarity": "uncommon"
	},
	"the_starry_night": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "The Starry Night",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 191,
		"atlas_source_id": 0,
		"atlas_coords": [
			22,
			27
		],
		"alternative_tile": 0,
		"seed": "the_starry_night_seed",
		"authored_drop_rules": true,
		"visual_size": [
			64,
			64
		],
		"visual_offset": [
			16,
			-16
		],
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "the_starry_night",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "the_starry_night_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "the_starry_night",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "the_starry_night_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"region": [
				704,
				864,
				64,
				64
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"region": [
				704,
				864,
				64,
				64
			]
		},
		"platform_collision": false
	},
	"the_starry_night_seed": {
		"category": "seed",
		"display_name": "The Starry Night Seed",
		"texture": {
			"atlas": "res://image.png",
			"region": [
				704,
				864,
				64,
				64
			]
		},
		"grows_into": "the_starry_night",
		"rarity": "uncommon"
	},
	"sunflower_painting": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Sunflower Painting",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 192,
		"atlas_source_id": 0,
		"atlas_coords": [
			18,
			28
		],
		"alternative_tile": 0,
		"seed": "sunflower_painting_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sunflower_painting",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sunflower_painting_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sunflower_painting",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sunflower_painting_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				18,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"sunflower_painting_seed": {
		"category": "seed",
		"display_name": "Sunflower Painting Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				18,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "sunflower_painting",
		"rarity": "uncommon"
	},
	"mona_lisa": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Mona Lisa",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 193,
		"atlas_source_id": 0,
		"atlas_coords": [
			19,
			28
		],
		"alternative_tile": 0,
		"seed": "mona_lisa_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "mona_lisa",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "mona_lisa_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "mona_lisa",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "mona_lisa_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				19,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"mona_lisa_seed": {
		"category": "seed",
		"display_name": "Mona Lisa Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "mona_lisa",
		"rarity": "uncommon"
	},
	"american_gothic": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "American Gothic",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 194,
		"atlas_source_id": 0,
		"atlas_coords": [
			20,
			28
		],
		"alternative_tile": 0,
		"seed": "american_gothic_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "american_gothic",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "american_gothic_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "american_gothic",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "american_gothic_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				20,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"american_gothic_seed": {
		"category": "seed",
		"display_name": "American Gothic Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "american_gothic",
		"rarity": "uncommon"
	},
	"the_girl_the_pearl_painting": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "The Girl the Pearl Painting",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 195,
		"atlas_source_id": 0,
		"atlas_coords": [
			21,
			28
		],
		"alternative_tile": 0,
		"seed": "the_girl_the_pearl_painting_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "the_girl_the_pearl_painting",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "the_girl_the_pearl_painting_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "the_girl_the_pearl_painting",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "the_girl_the_pearl_painting_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"the_girl_the_pearl_painting_seed": {
		"category": "seed",
		"display_name": "The Girl the Pearl Painting Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				28
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "the_girl_the_pearl_painting",
		"rarity": "uncommon"
	},
	"city_fence_seed": {
		"category": "seed",
		"display_name": "Gothic Fence Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				29
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "city_fence",
		"rarity": "uncommon"
	},
	"ventilation": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Ventilation",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"atlas_item_id": 196,
		"atlas_source_id": 0,
		"atlas_coords": [
			19,
			31
		],
		"alternative_tile": 0,
		"seed": "ventilation_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "ventilation",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "ventilation_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "ventilation",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "ventilation_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				31
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				19,
				31
			],
			"cell_size": [
				32,
				32
			]
		},
		"entrance_block": true,
		"entrance_tilemap_collision": true,
		"entrance_idle_atlas_coords": [
			19,
			31
		],
		"entrance_pass_atlas_coords": [
			20,
			31
		],
		"entrance_pass_atlas_frames": [
			[
				20,
				31
			],
			[
				21,
				31
			],
			[
				22,
				31
			]
		],
		"entrance_pass_animation_columns": 3,
		"entrance_animation_frame_seconds": 0.15,
		"interact_rules": {
			"can_interact": true,
			"interaction_message": "Lock or unlock entrance."
		},
		"platform_collision": false,
		"entrance_idle_texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				31
			],
			"cell_size": [
				32,
				32
			]
		},
		"entrance_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					20,
					31
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					21,
					31
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					22,
					31
				],
				"cell_size": [
					32,
					32
				]
			}
		]
	},
	"ventilation_seed": {
		"category": "seed",
		"display_name": "Ventilation Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				19,
				31
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "ventilation",
		"rarity": "uncommon"
	},
	"sirene_lamp": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Sirene Lamp",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 197,
		"atlas_source_id": 0,
		"atlas_coords": [
			21,
			30
		],
		"alternative_tile": 0,
		"seed": "sirene_lamp_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "sirene_lamp_on",
		"toggle_inactive_block": "sirene_lamp",
		"toggle_drop_block": "sirene_lamp",
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sirene_lamp",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sirene_lamp_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sirene_lamp",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sirene_lamp_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"sirene_lamp_seed": {
		"category": "seed",
		"display_name": "Sirene Lamp Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				21,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "sirene_lamp",
		"rarity": "uncommon"
	},
	"water_fountain": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Water Fountain",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 198,
		"atlas_source_id": 0,
		"atlas_coords": [
			22,
			30
		],
		"alternative_tile": 0,
		"seed": "water_fountain_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": true,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					22,
					30
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					23,
					30
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				22,
				30
			],
			[
				23,
				30
			]
		],
		"animation_frame_seconds": 0.18,
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "water_fountain",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "water_fountain_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "water_fountain",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "water_fountain_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				22,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				22,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"water_fountain_seed": {
		"category": "seed",
		"display_name": "Water Fountain Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				22,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "water_fountain",
		"rarity": "uncommon"
	},
	"moon": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Moon",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"atlas_item_id": 199,
		"atlas_source_id": 0,
		"atlas_coords": [
			15,
			32
		],
		"alternative_tile": 0,
		"seed": "moon_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "moon",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "moon_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "moon",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "moon_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				15,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"moon_seed": {
		"category": "seed",
		"display_name": "Moon Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				15,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "moon",
		"rarity": "uncommon"
	},
	"earth": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Earth",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"atlas_item_id": 200,
		"atlas_source_id": 0,
		"atlas_coords": [
			16,
			32
		],
		"alternative_tile": 0,
		"seed": "earth_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "earth",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "earth_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "earth",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "earth_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				16,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"earth_seed": {
		"category": "seed",
		"display_name": "Earth Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "earth",
		"rarity": "uncommon"
	},
	"sun": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": true,
		"dropable": true,
		"admin_grantable": true,
		"hidden": false,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": true,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Sun",
		"background_block": false,
		"no_collision": false,
		"collidable": true,
		"solid": true,
		"collision_type": "full",
		"atlas_item_id": 201,
		"atlas_source_id": 0,
		"atlas_coords": [
			17,
			32
		],
		"alternative_tile": 0,
		"seed": "sun_seed",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"animated": false,
		"animation_frames": [],
		"animation_atlas_coords": [],
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sun",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sun_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sun",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sun_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				17,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false
	},
	"sun_seed": {
		"category": "seed",
		"display_name": "Sun Seed",
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				17,
				32
			],
			"cell_size": [
				32,
				32
			]
		},
		"grows_into": "sun",
		"rarity": "uncommon"
	},
	"digital_sign_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Digital Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 207,
		"atlas_source_id": 0,
		"atlas_coords": [
			27,
			25
		],
		"alternative_tile": 0,
		"seed": "",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "digital_sign_on",
		"toggle_inactive_block": "digital_sign",
		"toggle_drop_block": "digital_sign",
		"animated": true,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					27,
					25
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					28,
					25
				],
				"cell_size": [
					32,
					32
				]
			},
			{
				"atlas": "res://image.png",
				"cell": [
					29,
					25
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				27,
				25
			],
			[
				28,
				25
			],
			[
				29,
				25
			]
		],
		"animation_frame_seconds": 0.2,
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "digital_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "digital_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "digital_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "digital_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				27,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				26,
				25
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"open_sign_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Open Sign",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 208,
		"atlas_source_id": 0,
		"atlas_coords": [
			26,
			26
		],
		"alternative_tile": 0,
		"seed": "",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "open_sign_on",
		"toggle_inactive_block": "open_sign",
		"toggle_drop_block": "open_sign",
		"animated": false,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					26,
					26
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				26,
				26
			]
		],
		"animation_frame_seconds": 0.2,
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "open_sign",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "open_sign_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "open_sign",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "open_sign_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				26,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				25,
				26
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"chandelier_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Chandelier",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 209,
		"atlas_source_id": 0,
		"atlas_coords": [
			16,
			27
		],
		"alternative_tile": 0,
		"seed": "",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "chandelier_on",
		"toggle_inactive_block": "chandelier",
		"toggle_drop_block": "chandelier",
		"animated": false,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					16,
					27
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				16,
				27
			]
		],
		"animation_frame_seconds": 0.2,
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "chandelier",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "chandelier_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "chandelier",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "chandelier_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				16,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				15,
				27
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
	"sirene_lamp_on": {
		"category": "block",
		"rarity": "uncommon",
		"stack_limit": 400,
		"tradeable": false,
		"dropable": false,
		"admin_grantable": false,
		"hidden": true,
		"equipment_slot": "",
		"gem_value": 0,
		"sell_value": 0,
		"shop_price": 0,
		"permissions": {},
		"placeable": false,
		"place_layer": "foreground",
		"block_health": 4,
		"breakable": true,
		"display_name": "Sirene Lamp",
		"background_block": false,
		"no_collision": true,
		"collidable": false,
		"solid": false,
		"collision_type": "none",
		"atlas_item_id": 210,
		"atlas_source_id": 0,
		"atlas_coords": [
			20,
			30
		],
		"alternative_tile": 0,
		"seed": "",
		"authored_drop_rules": true,
		"break_return_to_inventory": false,
		"punch_toggle_block": true,
		"toggle_active_block": "sirene_lamp_on",
		"toggle_inactive_block": "sirene_lamp",
		"toggle_drop_block": "sirene_lamp",
		"animated": false,
		"animation_frames": [
			{
				"atlas": "res://image.png",
				"cell": [
					20,
					30
				],
				"cell_size": [
					32,
					32
				]
			}
		],
		"animation_atlas_coords": [
			[
				20,
				30
			]
		],
		"animation_frame_seconds": 0.2,
		"tileset_animation": false,
		"drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sirene_lamp",
					"item_category": "block",
					"amount": 1
				},
				{
					"item_id": "sirene_lamp_seed",
					"item_category": "seed",
					"amount": 1,
					"chance": 0.2
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						3
					]
				}
			]
		},
		"tree_drop_rules": {
			"seed_chance": 0,
			"gem_range": [
				0,
				0
			],
			"fixed_drops": [
				{
					"item_id": "sirene_lamp",
					"item_category": "block",
					"amount_range": [
						2,
						5
					]
				},
				{
					"item_id": "sirene_lamp_seed",
					"item_category": "seed",
					"amount_range": [
						0,
						3
					]
				},
				{
					"item_id": "gem",
					"item_category": "currency",
					"amount_range": [
						0,
						5
					]
				}
			]
		},
		"texture": {
			"atlas": "res://image.png",
			"cell": [
				20,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"inventory_icon": {
			"atlas": "res://image.png",
			"cell": [
				21,
				30
			],
			"cell_size": [
				32,
				32
			]
		},
		"platform_collision": false,
		"punch_open_only": false
	},
"pillar": {"item_id":"pillar","category":"block","rarity":"common","stack_limit":400,"tradeable":true,"dropable":true,"admin_grantable":true,"hidden":false,"equipment_slot":"","gem_value":0,"sell_value":0,"shop_price":0,"permissions":{},"placeable":true,"place_layer":"foreground","block_health":2,"breakable":true,"display_name":"Pillar","background_block":false,"no_collision":false,"collidable":true,"solid":true,"collision_type":"full","atlas_item_id":58,"atlas_source_id":0,"atlas_coords":[15,19],"alternative_tile":0,"seed":"pillar_seed","order":432,"drop_rules":{"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"pillar","item_category":"block","amount":1},{"item_id":"pillar_seed","item_category":"seed","amount":1,"chance":0.2},{"item_id":"gem","item_category":"currency","amount_range":[0,3]}]},"vertical_variant_atlas_coords":{"single":[15,19],"top":[15,20],"middle":[15,21],"bottom":[15,22]},"recipe_tier":6,"authored_drop_rules":true,"tree_drop_rules":{"seed_chance":0,"gem_range":[0,0],"fixed_drops":[{"item_id":"pillar","item_category":"block","amount_range":[2,5]},{"item_id":"pillar_seed","item_category":"seed","amount_range":[0,3]},{"item_id":"gem","item_category":"currency","amount_range":[0,5]}]}},
}

# ============================================================
# SEED SPLICING RECIPES
# Format: "seed_a+seed_b": "output_seed"
# These are used for blocks, doors, signs, platforms, and world items.
# ============================================================
# Authored tiers from the SPLICING sheet. Recipes absent from the sheet stay unranked.
const RECIPE_TIERS = {
"password_door_seed": 11,
"blue_portal_seed": 11,
"dice_block_seed": 10,
"fire_hydrant_seed": 9,
"fire_escape_seed": 9,
"duck_seed": 9,
"bomb_seed": 9,
"cow_seed": 8,
"checkpoint_seed": 8,
"chicken_seed": 7,
"star_block_seed": 7,
"biohazard_barrel_seed": 7,
"pillar_seed": 6,
"ceiling_lamp_seed": 6,
"slime_seed": 5,
  "aqua_block": 5,
  "aqua_block_seed": 5,
  "aqua_wallpaper": 6,
  "aqua_wallpaper_seed": 6,
  "aquatic_line_wall": 5,
  "aquatic_line_wall_seed": 5,
  "barn_background": 5,
  "barn_background_seed": 5,
  "barn_block": 4,
  "barn_block_seed": 4,
  "barn_door": 5,
  "barn_door_seed": 5,
  "barn_window": 5,
  "barn_window_seed": 5,
  "bathtub": 7,
  "bathtub_seed": 7,
  "bed": 6,
  "bed_seed": 6,
  "big_sign": 4,
  "big_sign_seed": 4,
  "big_spike": 6,
  "big_spike_seed": 6,
  "biohazard_barrel": 7,
  "black_block": 3,
  "black_block_seed": 3,
  "black_wallpaper": 4,
  "black_wallpaper_seed": 4,
  "blue_block": 4,
  "blue_block_seed": 4,
  "blue_couch": 7,
  "blue_couch_seed": 7,
  "blue_mail_box": 7,
  "blue_mail_box_seed": 7,
  "blue_pastel_block": 6,
  "blue_pastel_block_seed": 6,
  "blue_portal": 11,
  "blue_stripe_wall": 4,
  "blue_stripe_wall_seed": 4,
  "blue_wallpaper": 5,
  "blue_wallpaper_seed": 5,
  "bomb": 9,
  "brown_block": 3,
  "brown_block_seed": 3,
  "brown_wallpaper": 4,
  "brown_wallpaper_seed": 4,
  "building_brick_block": 4,
  "building_brick_block_seed": 4,
  "building_brick_wall": 5,
  "building_brick_wall_seed": 5,
  "bulletin_board": 8,
  "bush": 2,
  "bush_seed": 2,
  "campfire": 3,
  "campfire_seed": 3,
  "ceiling_lamp": 6,
  "chandelier": 10,
  "chandelier_seed": 10,
  "checkered_wall": 5,
  "checkered_wall_seed": 5,
  "checkpoint": 8,
  "chicken": 7,
  "city_fence": 9,
  "city_fence_seed": 9,
  "climbing_vine": 5,
  "climbing_vine_seed": 5,
  "complementary_line_wall": 5,
  "complementary_line_wall_seed": 5,
  "cow": 8,
  "dark_aqua_block": 6,
  "dark_aqua_block_seed": 6,
  "dark_blue_block": 5,
  "dark_blue_block_seed": 5,
  "dark_green_block": 5,
  "dark_green_block_seed": 5,
  "dark_orange_block": 5,
  "dark_pink_block": 5,
  "dark_pink_block_seed": 5,
  "dark_purple_block": 6,
  "dark_purple_block_seed": 6,
  "dark_red_block_seed": 5,
  "dark_yellow_block": 5,
  "dark_yellow_block_seed": 5,
  "dice_block": 10,
  "digital_sign": 9,
  "digital_sign_seed": 9,
  "donation_box": 7,
  "dresser": 6,
  "dresser_seed": 6,
  "duck": 9,
  "dungeon_door": 6,
  "dungeon_door_seed": 6,
  "earth": 11,
  "earth_seed": 11,
  "electric_pole": 6,
  "electric_pole_seed": 6,
  "empty_jar": 7,
  "empty_jar_seed": 7,
  "fan": 9,
  "fan_seed": 9,
  "fire_escape": 9,
  "fire_hydrant": 9,
  "fireplace": 5,
  "fireplace_seed": 5,
  "fish_bowl": 7,
  "fish_bowl_seed": 7,
  "fish_hanger": 5,
  "gem_block_seed": 6,
  "glass": 3,
  "glass_panel": 2,
  "glass_panel_seed": 2,
  "glass_seed": 3,
  "grand_house_door": 8,
  "grand_house_door_seed": 8,
  "grass": 2,
  "grass_seed": 2,
  "green_block": 3,
  "green_block_seed": 3,
  "green_brick": 4,
  "green_brick_seed": 4,
  "green_brick_wall": 5,
  "green_brick_wall_seed": 5,
  "green_couch": 9,
  "green_couch_seed": 9,
  "green_pastel_block": 5,
  "green_pastel_block_seed": 5,
  "green_wallpaper": 4,
  "green_wallpaper_seed": 4,
  "grey_block": 3,
  "grey_block_seed": 3,
  "grey_wallpaper": 4,
  "grey_wallpaper_seed": 4,
  "happy_block": 6,
  "happy_block_seed": 6,
  "hay": 2,
  "hay_bales": 3,
  "hay_bales_seed": 3,
  "hay_seed": 2,
  "hazard_sign": 8,
  "hazard_sign_seed": 8,
  "heartbreak_painting": 9,
  "heartbreak_painting_seed": 9,
  "lamp": 7,
  "lamp_seed": 7,
  "lantern": 5,
  "lantern_seed": 5,
  "left_directional_sign": 5,
  "left_directional_sign_seed": 5,
  "light_brown_block_seed": 5,
  "love_painting": 9,
  "love_painting_seed": 9,
  "mail_box": 6,
  "mail_box_seed": 6,
  "maroon_block": 5,
  "mechanical_entrance": 7,
  "mechanical_entrance_seed": 7,
  "metal_pad": 7,
  "metal_pad_seed": 7,
  "modern_chair": 6,
  "modern_chair_seed": 6,
  "moon": 11,
  "moon_seed": 11,
  "mushroom": 2,
  "mushroom_seed": 2,
  "oil_refinery": 13,
  "oil_refinery_seed": 13,
  "open_sign": 8,
  "open_sign_seed": 8,
  "orange_block": 4,
  "orange_block_seed": 4,
  "orange_pastel_block": 5,
  "orange_pastel_block_seed": 5,
  "orange_wallpaper": 5,
  "orange_wallpaper_seed": 5,
  "park_bench": 5,
  "park_bench_seed": 5,
  "password_door": 11,
  "pastel_flower_block": 6,
  "pastel_flower_block_seed": 6,
  "pillar": 6,
  "pink_block": 4,
  "pink_block_seed": 4,
  "pink_curtains": 7,
  "pink_curtains_seed": 7,
  "pink_pastel_block": 5,
  "pink_pastel_block_seed": 5,
  "pink_wallpaper": 5,
  "pink_wallpaper_seed": 5,
  "portcullis": 7,
  "portcullis_seed": 7,
  "purple_block": 5,
  "purple_block_seed": 5,
  "purple_curtains": 7,
  "purple_curtains_seed": 7,
  "purple_pastel_block": 6,
  "purple_pastel_block_seed": 6,
  "purple_wallpaper": 6,
  "purple_wallpaper_seed": 6,
  "rainbow_block": 6,
  "recycle_bin": 10,
  "red_block": 3,
  "red_block_seed": 3,
  "red_brick": 2,
  "red_brick_platform": 5,
  "red_brick_platform_seed": 5,
  "red_brick_seed": 2,
  "red_brick_wall": 3,
  "red_brick_wall_seed": 3,
  "red_pastel_block": 5,
  "red_pastel_block_seed": 5,
  "red_stripe_wall": 4,
  "red_stripe_wall_seed": 4,
  "red_wallpaper": 4,
  "red_wallpaper_seed": 4,
  "refrigerator": 9,
  "refrigerator_seed": 9,
  "right_directional_sign": 5,
  "right_directional_sign_seed": 5,
  "royal_door": 5,
  "royal_door_seed": 5,
  "royal_entrance": 7,
  "royal_entrance_seed": 7,
  "royal_window": 5,
  "royal_window_seed": 5,
  "rubber_duck": 8,
  "rubber_duck_seed": 8,
  "sale_sign": 6,
  "sale_sign_seed": 6,
  "sashimi_table": 8,
  "sashimi_table_seed": 8,
  "saw_blade": 6,
  "saw_blade_seed": 6,
  "scratched_banana_painting": 9,
  "scratched_banana_painting_seed": 9,
  "screen_door": 6,
  "screen_door_seed": 6,
  "side_table": 5,
  "side_table_seed": 5,
  "sign": 3,
  "sign_seed": 3,
  "sink": 6,
  "sink_seed": 6,
  "sirene_lamp": 9,
  "sirene_lamp_seed": 9,
  "slime": 5,
  "star_block": 7,
  "star_wall": 5,
  "star_wall_seed": 5,
  "steel_background": 6,
  "steel_background_seed": 6,
  "steel_block": 5,
  "steel_block_seed": 5,
  "steel_door": 6,
  "steel_door_seed": 6,
  "steel_ladder": 6,
  "steel_ladder_seed": 6,
  "steel_platform": 6,
  "steel_platform_seed": 6,
  "steel_sign": 6,
  "steel_sign_seed": 6,
  "stone_brick": 2,
  "stone_brick_seed": 2,
  "stone_brick_wall": 3,
  "stone_brick_wall_seed": 3,
  "street_lamp": 8,
  "street_lamp_seed": 8,
  "street_sign": 7,
  "street_sign_seed": 7,
  "sturdy_box": 6,
  "sturdy_box_seed": 6,
  "sugar_cane": 5,
  "sugar_cane_seed": 5,
  "sun": 11,
  "sun_seed": 11,
  "toilet": 6,
  "toilet_seed": 6,
  "tv": 8,
  "tv_seed": 8,
  "ventilation": 7,
  "ventilation_seed": 7,
  "vines_2": 2,
  "vines_2_seed": 2,
  "vines_painting": 9,
  "vines_painting_seed": 9,
  "wagon_wheel": 6,
  "wagon_wheel_seed": 6,
  "water_fountain": 9,
  "water_fountain_seed": 9,
  "water_well": 7,
  "water_well_seed": 7,
  "weathervane": 6,
  "weathervane_seed": 6,
  "white_block": 3,
  "white_block_seed": 3,
  "white_brick_block": 4,
  "white_brick_block_seed": 4,
  "white_brick_platform": 5,
  "white_brick_platform_seed": 5,
  "white_brick_wall": 5,
  "white_brick_wall_seed": 5,
  "white_fence": 5,
  "white_fence_seed": 5,
  "white_wallpaper": 4,
  "white_wallpaper_seed": 4,
  "wood_platform": 3,
  "wood_platform_seed": 3,
  "wooden_background_seed": 2,
  "wooden_barrel": 5,
  "wooden_barrel_seed": 5,
  "wooden_block": 2,
  "wooden_block_seed": 2,
  "wooden_box": 4,
  "wooden_box_seed": 4,
  "wooden_chair": 4,
  "wooden_chair_seed": 4,
  "wooden_crappy_sign": 3,
  "wooden_crappy_sign_seed": 3,
  "wooden_door": 3,
  "wooden_door_seed": 3,
  "wooden_entrance": 4,
  "wooden_entrance_seed": 4,
  "wooden_fence": 3,
  "wooden_fence_seed": 3,
  "wooden_frame_seed": 3,
  "wooden_ladder": 4,
  "wooden_ladder_seed": 4,
  "wooden_table": 3,
  "wooden_table_seed": 3,
  "wooden_wallpaper": 2,
  "wooden_window": 3,
  "yellow_block": 3,
  "yellow_block_seed": 3,
  "yellow_pastel_block": 5,
  "yellow_pastel_block_seed": 5,
  "yellow_wallpaper": 4,
  "yellow_wallpaper_seed": 4
}

const SPLICE_RECIPES = {
"black_block_seed+ceiling_lamp_seed": "neon_block_seed",
"barn_block_seed+right_directional_sign_seed": "weathervane_seed",
"barn_block_seed+wooden_door_seed": "barn_door_seed",
"barn_block_seed+wooden_fence_seed": "white_fence_seed",
"barn_block_seed+wooden_background_seed": "barn_background_seed",
"barn_block_seed+wooden_frame_seed": "barn_window_seed",
"barn_block_seed+pink_block_seed": "pink_pastel_block_seed",
"barn_block_seed+orange_block_seed": "orange_pastel_block_seed",
"barn_block_seed+yellow_block_seed": "yellow_pastel_block_seed",
"barn_block_seed+green_block_seed": "green_pastel_block_seed",
"barn_block_seed+red_block_seed": "red_pastel_block_seed",
"hay_bales_seed+wooden_block_seed": "barn_block_seed",
"dice_block_seed+royal_door_seed": "password_door_seed",
"blue_block_seed+chandelier_seed": "blue_portal_seed",
"bomb_seed+white_block_seed": "dice_block_seed",
"red_block_seed+rubber_duck_seed": "fire_hydrant_seed",
"steel_platform_seed+street_lamp_seed": "fire_escape_seed",
"rubber_duck_seed+sashimi_table_seed": "duck_seed",
"big_spike_seed+hazard_sign_seed": "bomb_seed",
"chicken_seed+water_well_seed": "cow_seed",
"ceiling_lamp_seed+street_sign_seed": "street_lamp_seed",
"biohazard_barrel_seed+steel_sign_seed": "hazard_sign_seed",
"chicken_seed+slime_seed": "rubber_duck_seed",
"dungeon_door_seed+lamp_seed": "checkpoint_seed",
"building_brick_block_seed+ceiling_lamp_seed": "lamp_seed",
"grass_seed+weathervane_seed": "chicken_seed",
"gem_block_seed+star_wall_seed": "star_block_seed",
"big_spike_seed+wooden_barrel_seed": "biohazard_barrel_seed",
"white_brick_block_seed+wooden_barrel_seed": "pillar_seed",
"campfire_seed+steel_block_seed": "ceiling_lamp_seed",
"campfire_seed+green_brick_seed": "slime_seed",
	"aqua_block_seed+building_brick_wall_seed": "aqua_wallpaper_seed",
	"aqua_block_seed+sale_sign_seed": "street_sign_seed",
	"barn_door_seed+royal_door_seed": "screen_door_seed",
	"barn_door_seed+steel_block_seed": "steel_door_seed",
	"barn_window_seed+white_block_seed": "sink_seed",
	"barn_window_seed+wooden_frame_seed": "royal_window_seed",
	"bed_seed+park_bench_seed": "blue_couch_seed",
	"big_sign_seed+right_directional_sign_seed": "left_directional_sign_seed",
	"big_sign_seed+sign_seed": "right_directional_sign_seed",
	"big_sign_seed+steel_block_seed": "steel_sign_seed",
	"big_sign_seed+white_brick_wall_seed": "dresser_seed",
	"black_block_seed+red_brick_wall_seed": "black_wallpaper_seed",
	"black_block_seed+stone_brick_seed": "green_brick_seed",
	"black_wallpaper_seed+white_wallpaper_seed": "checkered_wall_seed",
	"blue_block_seed+green_brick_seed": "dark_blue_block_seed",
	"blue_block_seed+mail_box_seed": "blue_mail_box_seed",
	"blue_block_seed+red_brick_wall_seed": "blue_stripe_wall_seed",
"blue_block_seed+building_brick_wall_seed": "blue_wallpaper_seed",
	"blue_block_seed+red_pastel_block_seed": "purple_pastel_block_seed",
	"blue_block_seed+red_stripe_wall_seed": "aqua_block_seed",
	"blue_block_seed+side_table_seed": "bed_seed",
	"blue_block_seed+yellow_pastel_block_seed": "blue_pastel_block_seed",
	"blue_block_seed+yellow_wallpaper_seed": "star_wall_seed",
	"blue_couch_seed+dirt_seed": "green_couch_seed",
	"blue_pastel_block_seed+lily_seed": "pastel_flower_block_seed",
	"blue_stripe_wall_seed+red_block_seed": "purple_block_seed",
	"blue_stripe_wall_seed+red_brick_wall_seed": "red_stripe_wall_seed",
	"blue_stripe_wall_seed+red_stripe_wall_seed": "complementary_line_wall_seed",
	"brown_block_seed+red_brick_wall_seed": "brown_wallpaper_seed",
	"brown_block_seed+wooden_block_seed": "wooden_box_seed",
	"building_brick_block_seed+cave_background_seed": "building_brick_wall_seed",
	"building_brick_block_seed+white_brick_block_seed": "steel_block_seed",
	"building_brick_block_seed+wooden_door_seed": "royal_door_seed",
	"building_brick_block_seed+wooden_table_seed": "side_table_seed",
	"building_brick_wall_seed+purple_block_seed": "purple_wallpaper_seed",
	"bush_seed+wooden_block_seed": "wooden_table_seed",
	"cave_background_seed+green_brick_seed": "green_brick_wall_seed",
	"cave_background_seed+red_brick_seed": "red_brick_wall_seed",
	"cave_background_seed+sign_seed": "wooden_crappy_sign_seed",
	"cave_background_seed+stone_brick_seed": "stone_brick_wall_seed",
	"cave_background_seed+wooden_block_seed": "wooden_background_seed",
	"dark_blue_block_seed+dark_red_block_seed": "dark_purple_block_seed",
	"dark_green_block_seed+dark_yellow_block_seed": "dark_aqua_block_seed",
	"dark_purple_block_seed+red_block_seed": "gem_block_seed",
	"dirt_seed+leaf_seed": "grass_seed",
	"dirt_seed+red_brick_seed": "brown_block_seed",
	"dirt_seed+stone_seed": "stone_brick_seed",
	"dirt_seed+wood_seed": "wooden_block_seed",
	"dirt_seed+wooden_block_seed": "wooden_door_seed",
	"dresser_seed+glass_seed": "empty_jar_seed",
	"dungeon_door_seed+royal_door_seed": "royal_entrance_seed",
	"electric_pole_seed+steel_background_seed": "metal_pad_seed",
	"fish_bowl_seed+side_table_seed": "sashimi_table_seed",
	"glass_panel_seed+sink_seed": "fish_bowl_seed",
	"glass_panel_seed+stone_seed": "glass_seed",
	"glass_panel_seed+wooden_block_seed": "wooden_frame_seed",
	"glass_seed+grass_seed": "lily_seed",
	"glass_seed+wood_seed": "apple_seed",
	"grass_seed+lava_seed": "hay_seed",
	"grass_seed+leaf_seed": "bush_seed",
	"grass_seed+red_brick_seed": "green_block_seed",
	"grass_seed+sand_seed": "sun_flower_seed",
	"green_block_seed+green_brick_seed": "dark_green_block_seed",
	"green_block_seed+red_brick_wall_seed": "green_wallpaper_seed",
	"green_brick_seed+hay_seed": "sugar_cane_seed",
	"green_brick_seed+orange_block_seed": "light_brown_block_seed",
	"green_brick_seed+pink_block_seed": "dark_pink_block_seed",
	"green_brick_seed+red_block_seed": "dark_red_block_seed",
	"green_brick_seed+saw_blade_seed": "big_spike_seed",
	"green_brick_seed+yellow_block_seed": "dark_yellow_block_seed",
	"green_wallpaper_seed+wooden_chair_seed": "climbing_vine_seed",
	"grey_block_seed+red_brick_wall_seed": "grey_wallpaper_seed",
	"grey_wallpaper_seed+steel_block_seed": "steel_background_seed",
	"happy_block_seed+royal_window_seed": "pink_curtains_seed",
	"hay_seed+wooden_background_seed": "hay_bales_seed",
	"hay_seed+wooden_block_seed": "wooden_fence_seed",
	"ice_block_seed+tv_seed": "refrigerator_seed",
	"ice_block_seed+yellow_block_seed": "blue_block_seed",
	"lamp_seed+street_lamp_seed": "sirene_lamp_seed",
	"lava_seed+sand_seed": "glass_panel_seed",
	"lava_seed+stone_seed": "red_brick_seed",
	"lava_seed+wooden_block_seed": "campfire_seed",
	"lava_seed+wooden_box_seed": "lantern_seed",
	"leaf_seed+sand_seed": "tulip_seed",
	"leaf_seed+vines_seed": "vines_2_seed",
	"leaf_seed+wood_seed": "mushroom_seed",
	"left_directional_sign_seed+red_wallpaper_seed": "sale_sign_seed",
	"left_directional_sign_seed+steel_block_seed": "saw_blade_seed",
	"lily_seed+red_brick_seed": "white_block_seed",
	"mushroom_seed+wooden_block_seed": "sign_seed",
	"obsidian_seed+red_brick_seed": "black_block_seed",
	"orange_block_seed+red_brick_wall_seed": "orange_wallpaper_seed",
	"park_bench_seed+toilet_seed": "bathtub_seed",
	"pastel_flower_block_seed+royal_window_seed": "purple_curtains_seed",
	"pink_block_seed+red_brick_wall_seed": "pink_wallpaper_seed",
	"red_block_seed+red_brick_wall_seed": "red_wallpaper_seed",
	"red_block_seed+white_block_seed": "pink_block_seed",
	"red_block_seed+yellow_block_seed": "orange_block_seed",
	"red_brick_seed+rose_seed": "red_block_seed",
	"red_brick_seed+stone_brick_seed": "building_brick_block_seed",
	"red_brick_seed+stone_seed": "grey_block_seed",
	"red_brick_seed+tulip_seed": "yellow_block_seed",
	"red_brick_wall_seed+white_block_seed": "white_wallpaper_seed",
	"red_brick_wall_seed+yellow_block_seed": "yellow_wallpaper_seed",
	"red_pastel_block_seed+yellow_pastel_block_seed": "happy_block_seed",
	"rose_seed+tulip_seed": "poppy_seed",
	"royal_door_seed+saw_blade_seed": "portcullis_seed",
	"royal_door_seed+steel_block_seed": "dungeon_door_seed",
	"royal_door_seed+steel_ladder_seed": "ventilation_seed",
	"sale_sign_seed+street_sign_seed": "open_sign_seed",
	"sand_seed+stone_seed": "pile_of_sand_seed",
	"sand_seed+wood_plank_seed": "sand_castle_seed",
	"sign_seed+steel_block_seed": "electric_pole_seed",
	"sign_seed+wooden_crappy_sign_seed": "big_sign_seed",
	"sink_seed+white_brick_block_seed": "water_well_seed",
	"steel_block_seed+wood_platform_seed": "steel_platform_seed",
	"steel_block_seed+wooden_box_seed": "sturdy_box_seed",
	"steel_block_seed+wooden_ladder_seed": "steel_ladder_seed",
	"steel_door_seed+steel_sign_seed": "mechanical_entrance_seed",
	"stone_brick_seed+stone_brick_wall_seed": "white_brick_block_seed",
	"stone_brick_wall_seed+white_brick_block_seed": "white_brick_wall_seed",
	"stone_seed+wood_seed": "wood_plank_seed",
	"street_lamp_seed+water_fountain_seed": "chandelier_seed",
	"street_lamp_seed+white_fence_seed": "city_fence_seed",
	"vines_2_seed+wooden_block_seed": "wood_platform_seed",
	"vines_2_seed+wooden_table_seed": "wooden_chair_seed",
	"white_block_seed+white_brick_wall_seed": "toilet_seed",
	"white_brick_wall_seed+wooden_chair_seed": "modern_chair_seed",
	"white_fence_seed+wooden_box_seed": "wagon_wheel_seed",
	"wood_platform_seed+wooden_block_seed": "wooden_ladder_seed",
	"wood_platform_seed+wooden_door_seed": "wooden_entrance_seed",
	"wooden_block_seed+wooden_box_seed": "wooden_barrel_seed",
	"wooden_chair_seed+wooden_ladder_seed": "park_bench_seed"
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================
func get_item_data(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, { })


func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id)


func get_items_by_category(category: String) -> Array:
	var results = []

	for item_id in ITEMS.keys():
		var data = ITEMS[item_id]

		if data.get("category", "") == category:
			results.append(item_id)

	results.sort_custom(func(a, b):
		return int(ITEMS[a].get("order", 0)) < int(ITEMS[b].get("order", 0))
	)

	return results


func get_block_items() -> Array:
	return get_items_by_category("block")


func get_seed_items() -> Array:
	return get_items_by_category("seed")


func get_tool_items() -> Array:
	return get_items_by_category("tool")


func get_seed_for_block(block_id: String) -> String:
	if not ITEMS.has(block_id):
		return ""

	return ITEMS[block_id].get("seed", "")


func get_block_for_seed(seed_id: String) -> String:
	if not ITEMS.has(seed_id):
		return ""

	return ITEMS[seed_id].get("grows_into", "")


func get_splice_result(seed_a: String, seed_b: String) -> String:
	var key = get_splice_key(seed_a, seed_b)

	if SPLICE_RECIPES.has(key):
		return SPLICE_RECIPES[key]

	return ""


func get_splice_key(seed_a: String, seed_b: String) -> String:
	var pair = [seed_a, seed_b]
	pair.sort()

	return str(pair[0]) + "+" + str(pair[1])
