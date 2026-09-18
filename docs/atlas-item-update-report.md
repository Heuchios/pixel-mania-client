# Atlas item update

Implemented all 93 entries in `atlas-item-update.tsv`: 27 new blocks and 66 existing blocks updated. Existing item IDs and atlas IDs are retained for renamed items so saved worlds and inventories continue to resolve; their displayed block and seed names use the requested names.

- Spring Leaf uses **(4,3)**, as confirmed, preserving Entrance Gate at (4,2).
- Red Brick Wall now uses **(17,6)**.
- RGB Block is solid and retains the existing color cycling behavior.
- Quest Board has a **64×32** visual starting at (18,15).
- Lantern, Campfire, Seaweed and Portcullis use their three supplied frames.
- Recycle Bin has two frames on the existing server-triggered animation path. It stays idle until triggered; the future recycling action can call `play_server_triggered_block_animation`. Recycling gameplay itself is not configured yet.
- Recycle Bin and Leaderboard return directly to inventory on break, with no block, seed or gem loot.
- Oil Refinery keeps its existing artwork, animation and interaction behavior, and now drops blocks, seeds and gems.
- Existing break and tree-harvest drop amounts/chances were retained wherever the required drops already existed. Missing break drops default to one block, a 20% chance of one seed, and 0–3 gems; new tree harvests use 2–5 blocks, 0–3 seeds and 0–5 gems.
- Seaweed and Coral decorations are separate block entries from the existing fishing materials.

The new content enables 102 of the 149 chart recipes, with 110 recipes total including retained legacy recipes. See `splicing-recipe-report.md` for remaining missing content.

## Validation

- Godot test checks all 93 runtime item names, coordinates, collision/layers, textures, seeds, drop-rule preservation, and animation frames.
- The 93-item client runtime snapshot matches server names, seeds, break drops and tree drops exactly.
- TypeScript item-data build, existing item-data checks, item database/collision parity, and direct inventory-return checks pass.
- Client and server splicing checks cover both ingredient orders and all seed-to-block mappings.

Changes are local; no build was released or deployed.
