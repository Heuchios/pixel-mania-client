extends Node

# PixelMania Item Database Organization v1
#
# This file controls item/block/seed/tool/equipment data.
# Important content rules:
# - Blocks, doors, signs, and platforms should come from seed splicing.
# - Crafting Station should craft tools, stations, equipment, and rare/special items.
# - Furnace should output materials only.
# - Shop should sell stations, special utility items, and selected equipment.
#
# Safe adding workflow:
# 1. Add sprites.
# 2. Add item entry here.
# 3. Add splice/crafting/furnace/shop entry if needed.
# 4. Test with /give and save/load.

const CATEGORY_BLOCK = "block"
const CATEGORY_SEED = "seed"
const CATEGORY_TOOL = "tool"
const CATEGORY_BACK = "back"
const CATEGORY_MATERIAL = "material"
const CATEGORY_LURE = "lure"
const CATEGORY_FISH = "fish"
const CATEGORY_CURRENCY = "currency"

const ITEMS = {

	# ============================================================
	# BASIC NATURAL BLOCKS
	# ============================================================
"dirt": {
		"category": "block",
		"display_name": "Dirt",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/blocks/basic blocks/dirt_block.png",
		"seed": "dirt_seed",
		"order": 0
	},
"grass": {
		"category": "block",
		"display_name": "Grass",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/blocks/basic blocks/grass_block.png",
		"seed": "grass_seed",
		"Collidable": false,
		"no_collision": true,
		"order": 1
	},
"stone": {
		"category": "block",
		"display_name": "Stone",
		"rarity": "common",
		"block_health": 4,
		"texture": "res://Assets/blocks/basic blocks/stone_block.png",
		"seed": "stone_seed",
		"order": 2
	},
"wood": {
		"category": "block",
		"display_name": "Wood",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/basic blocks/wood_block.png",
		"seed": "wood_seed",
		"no_collision": true,
		"order": 3
	},
"leaf": {
		"category": "block",
		"display_name": "Leaf",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/basic blocks/leaf_block.png",
		"seed": "leaf_seed",
		"order": 4
	},
"lava": {
		"category": "block",
		"display_name": "Lava",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/basic blocks/lava_block.png",
		"seed": "lava_seed",
		"order": 5
	},
"sand": {
		"category": "block",
		"display_name": "Sand",
		"rarity": "common",
		"block_health": 3,
		"texture": "res://Assets/blocks/basic blocks/sand_block.png",
		"seed": "sand_seed",
		"order": 6
	},
"glass": {
		"category": "block",
		"display_name": "Glass",
		"rarity": "rare",
		"block_health": 2,
		"texture": "res://Assets/blocks/basic blocks/glass_block.png",
		"seed": "glass_seed",
		"order": 7
	},
"water": {
		"category": "block",
		"display_name": "Water",
		"rarity": "common",
		"block_health": 2,
		"texture": "res://Assets/blocks/basic blocks/water_block.png",
		"animation_frames": [
			"res://Assets/blocks/basic blocks/water_0.png",
			"res://Assets/blocks/basic blocks/water_1.png",
			"res://Assets/blocks/basic blocks/water_2.png",
			"res://Assets/blocks/basic blocks/water_3.png"
		],
		"no_collision": true,
		"order": 8
	},

"cave_background": {
		"category": "block",
		"display_name": "Cave Background",
		"rarity": "common",
		"block_health": 2,
		"texture": "res://Assets/background/cave_background.png",
		"seed": "cave_background_seed",
		"background_block": true,
		"place_layer": "background",
		"no_collision": true,
		"collidable": false,
		"order": 9
	},
"glowing_dirt": {
		"category": "block",
		"display_name": "Glowing Dirt",
		"rarity": "epic",
		"block_health": 4,
		"texture": "res://Assets/blocks/special_blocks/glowing_dirt.png",
		"animation_frames": [
			"res://Assets/blocks/special_blocks/glowing_dirt.png",
			"res://Assets/blocks/special_blocks/glowing_dirt_2.png"
		],
		"seed": "",
		"order": 10
	},
"red_block": {
		"category": "block",
		"display_name": "Red Block",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/colour_blocks/red_block.png",
		"inventory_icon": "res://Assets/inventory_icons/red_block.png",
		"seed": "red_block_seed",
		"order": 11
	},
"blue_block": {
		"category": "block",
		"display_name": "Blue Block",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/colour_blocks/blue_block.png",
		"inventory_icon": "res://Assets/blocks/colour_blocks/blue_block.png",
		"seed": "blue_block_seed",
		"order": 12
	},
"green_block": {
		"category": "block",
		"display_name": "Green Block",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/colour_blocks/green_block.png",
		"inventory_icon": "res://Assets/blocks/colour_blocks/green_block.png",
		"seed": "green_block_seed",
		"order": 13
	},
"purple_block": {
		"category": "block",
		"display_name": "Purple Block",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/blocks/colour_blocks/purple_block.png",
		"inventory_icon": "res://Assets/blocks/colour_blocks/purple_block.png",
		"seed": "purple_block_seed",
		"order": 14
	},
"yellow_block": {
		"category": "block",
		"display_name": "Yellow Block",
		"rarity": "uncommon",
		"block_health": 3,
		"texture": "res://Assets/inventory_icons/yellow_block.png",
		"inventory_icon": "res://Assets/inventory_icons/yellow_block.png",
		"seed": "yellow_block_seed",
		"order": 15
	},
"rose": {
		"category": "block",
		"display_name": "Rose",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/basic blocks/rose.png",
		"inventory_icon": "res://Assets/inventory_icons/rose.png",
		"seed": "rose_seed",
		"no_collision": true,
		"order": 16
	},
"tulip": {
		"category": "block",
		"display_name": "Tulip",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/basic blocks/tulip.png",
		"inventory_icon": "res://Assets/inventory_icons/tulip.png",
		"seed": "tulip_seed",
		"no_collision": true,
		"order": 17
	},
"vines": {
		"category": "block",
		"display_name": "Vines",
		"rarity": "common",
		"block_health": 2,
		"texture": "res://Assets/blocks/basic blocks/vines.png",
		"inventory_icon": "res://Assets/inventory_icons/vines.png",
		"seed": "vines_seed",
		"no_collision": true,
		"order": 18
	},

	# ============================================================
	# SYSTEM / HIDDEN WORLD BLOCKS
	# ============================================================
"world_lock": {
		"category": "block",
		"display_name": "World Lock",
		"rarity": "legendary",
		"block_health": 8,
		"texture": "res://Assets/locks/world_lock.png",
		"interaction_permission": "owner_only",
		"seed": "",
		"shop_price": 3500,
		"order": 18
	},
"entrance_gate": {
		"category": "block",
		"display_name": "Entrance Gate",
		"rarity": "legendary",
		"block_health": 9999,
		"texture": "res://Assets/blocks/entrance_gate/entrance_gate.png",
		"animation_frames": [
			"res://Assets/blocks/entrance_gate/entrance_gate.png",
			"res://Assets/blocks/entrance_gate/entrance_gate_2.png"
		],
		"animation_frame_seconds": 0.2,
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
		"texture": "res://Assets/blocks/crafting_station/blocks/crafting_station.png",
		"visual_size": Vector2i(64, 32),
		"visual_offset": Vector2(16, 0),
		"collision_size": Vector2i(64, 32),
		"collision_offset": Vector2(16, 0),
		"shadow_size": Vector2i(64, 32),
		"shadow_visual_offset": Vector2(16, 0),
		"order": 20
	},
"furnace": {
		"category": "block",
		"display_name": "Furnace",
		"rarity": "rare",
		"block_health": 6,
		"texture": "res://Assets/blocks/crafting_station/blocks/furnace.png",
		"craft_only": true,
		"order": 33
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
		"category": "block",
		"display_name": "Stone Brick",
		"rarity": "uncommon",
		"block_health": 5,
		"texture": "res://Assets/blocks/crafting_station/blocks/stone_brick.png",
		"seed": "stone_brick_seed",
		"craft_only": true,
		"order": 31
	},
"glass_panel": {
		"category": "block",
		"display_name": "Glass Panel",
		"rarity": "rare",
		"block_health": 2,
		"texture": "res://Assets/blocks/crafting_station/blocks/glass_panel.png",
		"seed": "glass_panel_seed",
		"craft_only": false,
		"order": 32
	},
"gem_block": {
		"category": "block",
		"display_name": "Gem Block",
		"rarity": "epic",
		"block_health": 5,
		"texture": "res://Assets/blocks/crafting_station/blocks/gem_block.png",
		"seed": "gem_block_seed",
		"craft_only": true,
		"order": 34
	},
"wood_platform": {
		"category": "block",
		"display_name": "Wood Platform",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/crafting_station/blocks/wood_platform.png",
		"seed": "wood_platform_seed",
		"craft_only": false,
		"order": 36
	},
"wooden_entrance": {
		"category": "block",
		"display_name": "Wooden Entrance",
		"rarity": "rare",
		"block_health": 4,
		"texture": "res://Assets/blocks/Tier_1/wooden_entrance_1.png",
		"inventory_icon": "res://Assets/inventory_icons/wooden_entrance.png",
		"seed": "wooden_entrance_seed",
		"no_collision": true,
		"entrance_frames": [
			"res://Assets/blocks/Tier_1/wooden_entrance_1.png",
			"res://Assets/blocks/Tier_1/wooden_entrance_2.png",
			"res://Assets/blocks/Tier_1/wooden_entrance_3.png"
		],
		"craft_only": false,
		"order": 35
	},
"sign": {
		"category": "block",
		"display_name": "Sign",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_1/sign.png",
		"seed": "sign_seed",
		"splice_only": false,
		"order": 37
	},
"mushroom": {
		"category": "block",
		"display_name": "Mushroom",
		"rarity": "uncommon",
		"block_health": 2,
		"texture": "res://Assets/blocks/Tier_1/mushroom_1.png",
		"inventory_icon": "res://Assets/inventory_icons/mushroom.png",
		"animation_frames": [
			"res://Assets/blocks/Tier_1/mushroom_1.png",
			"res://Assets/blocks/Tier_1/mushroom_2.png"
		],
		"animation_frame_seconds": 0.20,
		"seed": "",
		"collidable": true,
		"springboard": true,
		"springboard_velocity": -420.0,
		"order": 38
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
		"tree_textures": [
			"res://Assets/seed_tree_sprites/dirt_tree_stage0.png",
			"res://Assets/seed_tree_sprites/dirt_tree_stage1.png",
			"res://Assets/seed_tree_sprites/dirt_tree_stage2.png",
			"res://Assets/seed_tree_sprites/dirt_tree_mature.png"
		]
	},
"grass_seed": {
		"category": "seed",
		"display_name": "Grass Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/grass_seed.png",
		"grows_into": "grass",
		"order": 1,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/grass_tree_stage0.png",
			"res://Assets/seed_tree_sprites/grass_tree_stage1.png",
			"res://Assets/seed_tree_sprites/grass_tree_stage2.png",
			"res://Assets/seed_tree_sprites/grass_tree_mature.png"
		]
	},
"stone_seed": {
		"category": "seed",
		"display_name": "Stone Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/stone_seed.png",
		"grows_into": "stone",
		"order": 2,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/stone_tree_stage0.png",
			"res://Assets/seed_tree_sprites/stone_tree_stage1.png",
			"res://Assets/seed_tree_sprites/stone_tree_stage2.png",
			"res://Assets/seed_tree_sprites/stone_tree_mature.png"
		]
	},
"wood_seed": {
		"category": "seed",
		"display_name": "Wood Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/wood_seed.png",
		"grows_into": "wood",
		"order": 3,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/wood_tree_stage0.png",
			"res://Assets/seed_tree_sprites/wood_tree_stage1.png",
			"res://Assets/seed_tree_sprites/wood_tree_stage2.png",
			"res://Assets/seed_tree_sprites/wood_tree_mature.png"
		]
	},
"leaf_seed": {
		"category": "seed",
		"display_name": "Leaf Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/leaf_seed.png",
		"grows_into": "leaf",
		"order": 4,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/leaf_tree_stage0.png",
			"res://Assets/seed_tree_sprites/leaf_tree_stage1.png",
			"res://Assets/seed_tree_sprites/leaf_tree_stage2.png",
			"res://Assets/seed_tree_sprites/leaf_tree_mature.png"
		]
	},
"lava_seed": {
		"category": "seed",
		"display_name": "Lava Seed",
		"rarity": "rare",
		"texture": "res://Assets/seeds/lava_seed.png",
		"grows_into": "lava",
		"order": 5,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/lava_tree_stage0.png",
			"res://Assets/seed_tree_sprites/lava_tree_stage1.png",
			"res://Assets/seed_tree_sprites/lava_tree_stage2.png",
			"res://Assets/seed_tree_sprites/lava_tree_mature.png"
		]
	},
"sand_seed": {
		"category": "seed",
		"display_name": "Sand Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/sand_seed.png",
		"grows_into": "sand",
		"order": 6,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/sand_tree_stage0.png",
			"res://Assets/seed_tree_sprites/sand_tree_stage1.png",
			"res://Assets/seed_tree_sprites/sand_tree_stage2.png",
			"res://Assets/seed_tree_sprites/sand_tree_mature.png"
		]
	},
"glass_seed": {
		"category": "seed",
		"display_name": "Glass Seed",
		"rarity": "rare",
		"texture": "res://Assets/seeds/glass_seed.png",
		"grows_into": "glass",
		"order": 7,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/glass_tree_stage0.png",
			"res://Assets/seed_tree_sprites/glass_tree_stage1.png",
			"res://Assets/seed_tree_sprites/glass_tree_stage2.png",
			"res://Assets/seed_tree_sprites/glass_tree_mature.png"
		]
	},
"cave_background_seed": {
		"category": "seed",
		"display_name": "Cave Background Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/cave_background_seed.png",
		"grows_into": "cave_background",
		"order": 8,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/cave_tree_stage0.png",
			"res://Assets/seed_tree_sprites/cave_tree_stage1.png",
			"res://Assets/seed_tree_sprites/cave_tree_stage2.png",
			"res://Assets/seed_tree_sprites/cave_tree_mature.png"
		]
	},
"red_block_seed": {
		"category": "seed",
		"display_name": "Red Block Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/red_block_seed.png",
		"grows_into": "red_block",
		"order": 9,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/red_block_tree_stage0.png",
			"res://Assets/seed_tree_sprites/red_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/red_block_tree_stage2.png",
			"res://Assets/seed_tree_sprites/red_block_tree_mature.png"
		]
	},
"blue_block_seed": {
		"category": "seed",
		"display_name": "Blue Block Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/blue_block_seed.png",
		"grows_into": "blue_block",
		"order": 10,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/blue_block_tree_stage0.png",
			"res://Assets/seed_tree_sprites/blue_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/blue_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/blue_block_tree_mature.png"
		]
	},
"green_block_seed": {
		"category": "seed",
		"display_name": "Green Block Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/green_block_seed.png",
		"grows_into": "green_block",
		"order": 11,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/green_block_tree_stage0.png",
			"res://Assets/seed_tree_sprites/green_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/green_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/green_block_tree_mature.png"
		]
	},
"purple_block_seed": {
		"category": "seed",
		"display_name": "Purple Block Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/purple_block_seed.png",
		"grows_into": "purple_block",
		"order": 12,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/purple_block_tree_stage0.png",
			"res://Assets/seed_tree_sprites/purple_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/purple_block_tree_stage2.png",
			"res://Assets/seed_tree_sprites/purple_block_tree_mature.png"
		]
	},
"yellow_block_seed": {
		"category": "seed",
		"display_name": "Yellow Block Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/inventory_icons/yellow_block_seed.png",
		"grows_into": "yellow_block",
		"order": 13,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/yellow_block_tree_stage0.png",
			"res://Assets/seed_tree_sprites/yellow_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/yellow_block_tree_stage2.png",
			"res://Assets/seed_tree_sprites/yellow_block_tree_mature.png"
		]
	},
"rose_seed": {
		"category": "seed",
		"display_name": "Rose Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/rose_seed.png",
		"inventory_icon": "res://Assets/inventory_icons/rose_seed.png",
		"grows_into": "rose",
		"order": 14,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/rose_tree_stage0.png",
			"res://Assets/seed_tree_sprites/rose_tree_stage1.png",
			"res://Assets/seed_tree_sprites/rose_tree_stage2.png",
			"res://Assets/seed_tree_sprites/rose_tree_mature.png"
		]
	},
"tulip_seed": {
		"category": "seed",
		"display_name": "Tulip Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/tulip_seed.png",
		"inventory_icon": "res://Assets/inventory_icons/tulip_seed.png",
		"grows_into": "tulip",
		"order": 15,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/tulip_tree_stage0.png",
			"res://Assets/seed_tree_sprites/tulip_tree_stage1.png",
			"res://Assets/seed_tree_sprites/tulip_tree_stage2.png",
			"res://Assets/seed_tree_sprites/tulip_tree_mature.png"
		]
	},
"vines_seed": {
		"category": "seed",
		"display_name": "Vines Seed",
		"rarity": "common",
		"texture": "res://Assets/seeds/vines_seed.png",
		"inventory_icon": "res://Assets/inventory_icons/vines_seed.png",
		"grows_into": "vines",
		"order": 16,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/vines_tree_stage0.png",
			"res://Assets/seed_tree_sprites/vines_tree_stage1.png",
			"res://Assets/seed_tree_sprites/vines_tree_stage2.png",
			"res://Assets/seed_tree_sprites/vines_tree_mature.png"
		]
	},
		
	# ============================================================
	# SPLICED SEEDS
	# ============================================================
"wood_plank_seed": {
		"category": "seed",
		"display_name": "Wood Plank Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/special/wood_plank_seed.png",
		"grows_into": "wood_plank",
		"order": 30,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/special/wood_plank_tree_stage0.png",
			"res://Assets/seed_tree_sprites/special/wood_plank_tree_stage1.png",
			"res://Assets/seed_tree_sprites/special/wood_plank_tree_stage2.png",
			"res://Assets/seed_tree_sprites/special/wood_plank_tree_stage3.png"
		]
	},
"wood_platform_seed": {
		"category": "seed",
		"display_name": "Wood Platform Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/special/wood_platform_seed.png",
		"grows_into": "wood_platform",
		"order": 31,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/special/wood_platform_tree_stage0.png",
			"res://Assets/seed_tree_sprites/special/wood_platform_tree_stage1.png",
			"res://Assets/seed_tree_sprites/special/wood_platform_tree_stage2.png",
			"res://Assets/seed_tree_sprites/special/wood_platform_tree_stage3.png"
		]
	},
"wooden_entrance_seed": {
		"category": "seed",
		"display_name": "Wooden Entrance Seed",
		"rarity": "rare",
		"texture": "res://Assets/inventory_icons/wooden_entrance.png",
		"grows_into": "wooden_entrance",
		"order": 32,
		"tree_textures": [
			"res://Assets/blocks/Tier_1/wooden_entrance_1.png",
			"res://Assets/blocks/Tier_1/wooden_entrance_2.png",
			"res://Assets/blocks/Tier_1/wooden_entrance_3.png"
		]
	},
"sign_seed": {
		"category": "seed",
		"display_name": "Sign Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/special/sign_seed.png",
		"grows_into": "sign",
		"order": 33,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/special/sign_tree_stage0.png",
			"res://Assets/seed_tree_sprites/special/sign_tree_stage1.png",
			"res://Assets/seed_tree_sprites/special/sign_tree_stage2.png",
			"res://Assets/seed_tree_sprites/special/sign_tree_stage3.png"
		]
	},
"stone_brick_seed": {
		"category": "seed",
		"display_name": "Stone Brick Seed",
		"rarity": "uncommon",
		"texture": "res://Assets/seeds/special/stone_brick_seed.png",
		"grows_into": "stone_brick",
		"order": 34,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/special/stone_brick_tree_stage0.png",
			"res://Assets/seed_tree_sprites/special/stone_brick_tree_stage1.png",
			"res://Assets/seed_tree_sprites/special/stone_brick_tree_stage2.png",
			"res://Assets/seed_tree_sprites/special/stone_brick_tree_stage3.png"
		]
	},
"glass_panel_seed": {
		"category": "seed",
		"display_name": "Glass Panel Seed",
		"rarity": "rare",
		"texture": "res://Assets/seeds/special/glass_panel_seed.png",
		"grows_into": "glass_panel",
		"order": 35,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/special/glass_panel_tree_stage0.png",
			"res://Assets/seed_tree_sprites/special/glass_panel_tree_stage1.png",
			"res://Assets/seed_tree_sprites/special/glass_panel_tree_stage2.png",
			"res://Assets/seed_tree_sprites/special/glass_panel_tree_stage3.png"
		]
	},
"gem_block_seed": {
		"category": "seed",
		"display_name": "Gem Block Seed",
		"rarity": "epic",
		"texture": "res://Assets/seeds/special/gem_block_seed.png",
		"grows_into": "gem_block",
		"order": 36,
		"tree_textures": [
			"res://Assets/seed_tree_sprites/special/gem_block_tree_stage0.png",
			"res://Assets/seed_tree_sprites/special/gem_block_tree_stage1.png",
			"res://Assets/seed_tree_sprites/special/gem_block_tree_stage2.png",
			"res://Assets/seed_tree_sprites/special/gem_block_tree_stage3.png"
		]
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

	# ============================================================
	# BACK ITEMS / EQUIPMENT
	# ============================================================
"legendary_wings": {
		"category": "back",
		"display_name": "Legendary Wings",
		"rarity": "legendary",
		"texture": "res://Assets/player/back_item/legendary_wings/legendary_wings_idle.png",
		"starting_count": 0,
		"equipable": true,

		"equipment_slot": "back",
		"back_mode": "default_slot",
		"sprite_folder": "res://Assets/player/back_item/legendary_wings/",
		"idle_sprite": "legendary_wings_idle.png",
		"flap_frames": ["legendary_wings_flap1.png", "legendary_wings_flap2.png"],
		"flap_animation": true,
		"scan_flap_frames": true,
		"flap_speed": 0.30,
		"input_flap_time": 0.28,

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

		"order": 200
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

	# ============================================================

	# ============================================================
	# FISHING ITEMS
	# ============================================================
"fishing_rod": {
		"category": "tool",
		"display_name": "Fishing Rod",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fishing/fishing_rod.png",
		"starting_count": 0,
		"equipable": true,

		# Hand Item Auto Anchor v1:
		# 64x32 sprite = left 32px is held, right 32px overhangs outward.
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [16, 16],

		# Fishing rod uses the same default 64x32 hand anchor,
		# with a small visual tune so it looks better in hand.
		"hand_scale": 1.15,
		"hand_rotation": -8,
		"hand_rotation_left": 8,

		"order": 40
	},
"sakura_sword": {
		"category": "tool",
		"display_name": "Sakura Sword",
		"rarity": "legendary",
		"texture": "res://Assets/items/swords/sakura_sword.png",
		"inventory_icon": "res://Assets/inventory_icons/sakura_sword.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"order": 41
	},
"pulu_pulu": {
		"category": "tool",
		"display_name": "Pulu Pulu",
		"rarity": "legendary",
		"texture": "res://Assets/items/swords/pulu_pulu.png",
		"starting_count": 0,
		"equipable": true,
		"equipment_slot": "hand",
		"hand_item": true,
		"order": 42
	},
"worm_lure": {
		"category": "lure",
		"display_name": "Worm Lure",
		"rarity": "common",
		"texture": "res://Assets/items/lures/worm_lure.png",
		"order": 300
	},
"shiny_lure": {
		"category": "lure",
		"display_name": "Shiny Lure",
		"rarity": "uncommon",
		"texture": "res://Assets/items/lures/shiny_lure.png",
		"order": 301
	},
"golden_lure": {
		"category": "lure",
		"display_name": "Golden Lure",
		"rarity": "rare",
		"texture": "res://Assets/items/lures/golden_lure.png",
		"order": 302
	},
"lure_pack": {
		"category": "lure",
		"display_name": "Lure Pack",
		"rarity": "uncommon",
		"texture": "res://Assets/items/lures/lure_pack.png",
		"shop_pack": true,
		"order": 303
	},

	# ============================================================
	# FISH
	# ============================================================
"pond_fish": {
		"category": "fish",
		"display_name": "Pond Fish",
		"rarity": "common",
		"texture": "res://Assets/items/fish/pond_fish.png",
		"sell_value": 3,
		"order": 400
	},
"bluegill": {
		"category": "fish",
		"display_name": "Bluegill",
		"rarity": "uncommon",
		"texture": "res://Assets/items/fish/bluegill.png",
		"sell_value": 8,
		"order": 401
	},
"golden_carp": {
		"category": "fish",
		"display_name": "Golden Carp",
		"rarity": "rare",
		"texture": "res://Assets/items/fish/golden_carp.png",
		"sell_value": 25,
		"order": 402
	},
"crystal_fish": {
		"category": "fish",
		"display_name": "Crystal Fish",
		"rarity": "epic",
		"texture": "res://Assets/items/fish/crystal_fish.png",
		"sell_value": 75,
		"order": 403
	},

	# TOOLS / UTILITY ITEMS
	# ============================================================
"pickaxe": {
		"category": "tool",
		"display_name": "Pickaxe",
		"rarity": "rare",
		"texture": "res://Assets/items/special items/tools/pickaxe.png",
		"starting_count": 1,
		"break_power": 1,
		"effective_break_power": 3,
		"effective_blocks": ["stone", "glass", "lava"],
		"equipable": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [15, 27],
		"hand_sprite_offset": [8, -3],
		"hand_sprite_offset_left": [-8, -3],
		"hand_scale": 1.0,
		"hand_rotation": -72,
		"hand_rotation_left": 72,
		"order": 0
	},
"axe": {
		"category": "tool",
		"display_name": "Axe",
		"rarity": "uncommon",
		"texture": "res://Assets/items/special items/tools/axe.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 3,
		"effective_blocks": ["wood", "leaf"],
		"equipable": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [12, 24],
		"hand_scale": 0.95,
		"hand_rotation": -18,
		"hand_rotation_left": 18,
		"order": 1
	},
"shovel": {
		"category": "tool",
		"display_name": "Shovel",
		"rarity": "uncommon",
		"texture": "res://Assets/items/special items/tools/shovel.png",
		"starting_count": 0,
		"break_power": 1,
		"effective_break_power": 3,
		"effective_blocks": ["dirt", "grass", "sand", "cave_background"],
		"equipable": true,
		"hand_item": true,
		"hand_mode": "auto_anchor",
		"hand_hold_point": [16, 25],
		"hand_scale": 1.0,
		"hand_rotation": -16,
		"hand_rotation_left": 16,
		"order": 2
	},
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
	
"vend_empty": {
		"category": "block",
		"display_name": "Vending Machine",
		"rarity": "epic",
		"block_health": 5,
		"break_power": 5,
		"texture": "res://Assets/items/special items/vend/vend_empty.png",
		"placeable": true,
		"tradeable": true,
		"equipable": false,
		"starting_count": 0,
		"shop_pack": true,
		"no_collision": true,
		"interact_rules": true,
	},
"vend_pending": {
		"category": "block",
		"display_name": "Vending Machine",
		"rarity": "epic",
		"block_health": 5,
		"break_power": 5,
		"texture": "res://Assets/items/special items/vend/vend_pending.png",
		"placeable": false,
		"tradeable": false,
		"equipable": false,
		"starting_count": 0,
		"hidden": true,
		"no_collision": true,
		"interact_rules": true,
	},
"vend_sold": {
		"category": "block",
		"display_name": "Vending Machine",
		"rarity": "epic",
		"block_health": 5,
		"break_power": 5,
		"texture": "res://Assets/items/special items/vend/vend_sold.png",
		"placeable": false,
		"tradeable": false,
		"equipable": false,
		"starting_count": 0,
		"hidden": true,
		"no_collision": true,
		"interact_rules": true,
	},
"fish_monger": {
		"category": "block",
		"display_name": "Fish Monger",
		"rarity": "epic",
		"block_health": 6,
		"break_power": 5,
		"texture": "res://Assets/items/special items/fish_monger/fish_monger.png",
		"inventory_icon": "res://Assets/inventory_icons/fish_monger.png",
		"animation_frames": [
			"res://Assets/items/special items/fish_monger/fish_monger.png",
			"res://Assets/items/special items/fish_monger/fish_monger_1.png",
			"res://Assets/items/special items/fish_monger/fish_monger_2.png"
		],
		"animation_frame_seconds": 0.5,
		"visual_size": Vector2i(64, 64),
		"visual_offset": Vector2(16, -16),
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
		"shop_price": 15000,
		"order": 38
	},
"safe": {
		"category": "block",
		"display_name": "Safe",
		"rarity": "epic",
		"block_health": 6,
		"break_power": 5,
		"texture": "res://Assets/items/special items/safe/safe.png",
		"seed": "",
		"placeable": true,
		"tradeable": true,
		"equipable": false,
		"starting_count": 0,
		"shop_pack": true,
		"interact_rules": true,
	}
}

# ============================================================
# SEED SPLICING RECIPES
# Format: "seed_a+seed_b": "output_seed"
# These are used for blocks, doors, signs, platforms, and world items.
# ============================================================
const SPLICE_RECIPES = {
	"wood_seed+wood_seed": "wood_plank_seed",
	"grass_seed+wood_seed": "wood_platform_seed",
	"leaf_seed+wood_seed": "wooden_entrance_seed",
	"stone_seed+cave_background_seed": "sign_seed",
	"lava_seed+stone_seed": "glass_panel_seed",
	"glass_seed+lava_seed": "gem_block_seed",
	"dirt_seed+stone_seed": "grass_seed",
	"dirt_seed+lava_seed": "wood_seed",
	"sand_seed+lava_seed": "glass_seed",
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================
func get_item_data(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


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
