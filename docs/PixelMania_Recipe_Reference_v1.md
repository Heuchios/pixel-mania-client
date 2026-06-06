# PixelMania Recipe Reference v1

This file is for testing, balancing, and release notes. It does not need to be loaded by Godot.

## Progression Rules

### Seed Splicing
Use seed splicing for blocks and placeable world items:

- Blocks
- Doors
- Signs
- Platforms
- Decorative world tiles

### Crafting Station
Use Crafting Station for tools, stations, equipment, and rare/special items.

Do not put normal blocks, signs, doors, or platforms here if they are meant to come from seed splicing.

### Furnace
Use Furnace for material conversion only.

Examples:

- block + lava = refined material
- glass + lava = refined glass
- stone + lava + gems = metal scrap

### Shop
Use Shop for purchasable stations and utility/special items.

Current shop logic should avoid selling items that are naturally obtainable from breaking blocks, seed splicing, or furnace recipes.

---

## Current Seed Splices

| Seeds | Output |
|---|---|
| wood_seed + wood_seed | wood_plank_seed |
| grass_seed + wood_seed | wood_platform_seed |
| leaf_seed + wood_seed | wooden_entrance_seed |
| stone_seed + wood_seed | sign_seed |
| lava_seed + stone_seed | stone_brick_seed |
| glass_seed + stone_seed | glass_panel_seed |
| glass_seed + lava_seed | gem_block_seed |

---

## Current Crafting Station Recipes

| Recipe | Output | Cost |
|---|---:|---|
| Pickaxe | pickaxe x1 | wood x10, stone x5 |
| Axe | axe x1 | wood x8, stone x3 |
| Shovel | shovel x1 | wood x6, stone x2 |
| Furnace | furnace x1 | stone x30, lava x3, gem x5 |

Crafting Station does not craft Crafting Station. Crafting Station is purchased from the shop.

---

## Current Furnace Recipes

| Recipe | Output | Cost |
|---|---:|---|
| Refined Stone x5 | refined_stone x5 | stone x15, lava x1 |
| Refined Glass x5 | refined_glass x5 | glass x10, lava x1 |
| Metal Scrap x3 | metal_scrap x3 | stone x25, lava x2, gem x2 |

---

## Template: Add a New Block + Seed

### item_database.gd block entry

```gdscript
"marble_block": {
	"category": "block",
	"display_name": "Marble Block",
	"rarity": "rare",
	"block_health": 4,
	"texture": "res://Assets/blocks/marble_block.png",
	"seed": "marble_seed",
	"order": 50
},
```

### item_database.gd seed entry

```gdscript
"marble_seed": {
	"category": "seed",
	"display_name": "Marble Seed",
	"rarity": "rare",
	"texture": "res://Assets/seeds/marble_seed.png",
	"grows_into": "marble_block",
	"tree_textures": [
		"res://Assets/seed_tree_sprites/marble_tree_stage0.png",
		"res://Assets/seed_tree_sprites/marble_tree_stage1.png",
		"res://Assets/seed_tree_sprites/marble_tree_stage2.png",
		"res://Assets/seed_tree_sprites/marble_tree_mature.png"
	],
	"order": 50
},
```

### Splice entry

```gdscript
"stone_seed+glass_seed": "marble_seed"
```

---

## Template: Add a New Crafting Recipe

Use this only for tools, stations, equipment, or special items.

```gdscript
{
	"id": "basic_wings",
	"name": "Basic Wings",
	"type": "equipment",
	"output": {"item_id": "basic_wings", "category": "back", "amount": 1},
	"cost": [
		{"item_id": "metal_scrap", "category": "material", "amount": 5},
		{"item_id": "gem", "category": "currency", "amount": 50}
	]
}
```

---

## Template: Add a New Furnace Recipe

Use this only for material outputs.

```gdscript
{
	"id": "refined_marble",
	"name": "Refined Marble x5",
	"type": "material",
	"output": {"item_id": "refined_marble", "category": "material", "amount": 5},
	"cost": [
		{"item_id": "marble_block", "category": "block", "amount": 10},
		{"item_id": "lava", "category": "block", "amount": 1}
	]
}
```

---

## Testing Commands

```text
/give wood 100
/give stone 100
/give lava 20
/give glass 50
/give gem 100
/give refined_stone 10
/give refined_glass 10
/give metal_scrap 10
```

After any recipe change, test:

1. Crafting Station opens.
2. Crafting Station recipes show.
3. Furnace opens.
4. Furnace recipes show.
5. Costs subtract correctly.
6. Output appears in the correct inventory tab.
7. No duplicate recipe output exists.
