#!/usr/bin/env pwsh
# Commits the fourth "blocks atlas migration" batch in the pixel-mania (client) repo:
# 20 new furniture/decor items plus a position fix for the pre-existing
# red_brick_wall. Does NOT push. Review the diff summary this prints before
# pushing/exporting.

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/item_database.gd",
    "Data/items/atlas_items.json"
)

Write-Host "== git status before staging ==" -ForegroundColor Cyan
git status --short

Write-Host "`n== staged diff stat (after staging) ==" -ForegroundColor Cyan
git add -- $files
git diff --cached --stat

$commitMessage = @"
Add couches/toilet/fridge/fireplace/bathtub/sink/bricks/fan/bed to atlas

New items on image.png (all non-collideable unless noted):

- blue_couch: icon/single (19,21), left (16,21), horizontal_middle/middle
  (17,21), right (18,21). connected_variant_atlas_coords (4-directional
  auto-tiling), matching the pre-existing atlas_items.json registration
  (id 69) exactly. seed field linked to the pre-existing (orphaned)
  blue_couch_seed, rarity corrected to "uncommon" to match the seed.
- green_couch: same shape, icon/single (23,21), left (20,21),
  horizontal_middle/middle (21,21), right (22,21). Linked to
  green_couch_seed (id 70).
- side_table: icon/item (24,21), no seed.
- toilet/toilet_open: icon/closed (24,22), open (25,22).
- refrigerator/refrigerator_open: icon/closed (26,22), open (27,22).
- fireplace/fireplace_on: icon/off (17,23), on is a 3-frame animation
  (18,23)/(19,23)/(20,23) at 0.3s/frame.
- bathtub/bathtub_on: icon/off (21,23), on is a 2-frame animation
  (22,23)/(23,23) at 0.4s/frame.
- sink/sink_on: icon/off (24,23), on (25,23), static (no animation).
- red_brick_platform: icon/item (15,24), platform_collision: true.
- white_brick_block: icon (16,24), left (16,24)/right (17,24) tiles via
  platform_variant_atlas_coords (no middle -- falls back to the base
  atlas_coords for isolated placements). The one SOLID/collidable item in
  this batch.
- white_brick_wall: icon/item (18,24), background_block wallpaper.
- white_brick_platform: icon/single (19,24), left (20,24)/middle
  (21,24)/right (22,24), platform_collision: true.
- fan: icon (23,24), 2-frame animation (23,24)/(24,24) at 0.15s/frame.
- bed: icon/item (25,24).

The five toggle pairs (toilet, refrigerator, fireplace, bathtub, sink) use
punch_toggle_block: true / toggle_active_block / toggle_inactive_block /
toggle_drop_block with block_health: 2 on both variants of each pair --
the same already-shipped generic mechanism the pre-existing tv/tv_active
and death_gate/death_gate_active pairs use. No client-side (block_manager.
gd/world.gd/interaction_manager.gd) code changes were needed: the server
drives the type swap and the client already renders any server-pushed
block-type change through its existing multiplayer sync path. Punching
once toggles the block (no break); punching again starts breaking it.

Also fixes the pre-existing red_brick_wall entry: moved from its old
(17,6) cell to the new (16,23) cell (texture/inventory_icon/atlas_coords),
all other fields (seed, rarity, block_health, drop-related config)
unchanged.

Data/items/atlas_items.json: fixed red_brick_wall's stale atlas_coords
(id 44) to [16, 23] -- ItemAtlasDB.merge_item_database() re-merges this
JSON on top of item_database.gd by item_key on every world load, so
leaving it stale would have silently reverted the position fix above at
runtime. blue_couch (id 69) and green_couch (id 70) already had full,
correct registrations here (connected_variant_atlas_coords included) from
an earlier pass -- no JSON changes were needed for those two. The other 17
new keys in this batch are not registered in this file at all, so there
was no stale-entry risk for them.
"@

Write-Host "`n== creating commit ==" -ForegroundColor Cyan
git commit -m $commitMessage

Write-Host "`n== git log (last commit) ==" -ForegroundColor Cyan
git log -1 --stat

Write-Host "`nDone. This commit was NOT pushed. Review it, then push/export when ready." -ForegroundColor Yellow
