#!/usr/bin/env pwsh
# Commits the "blocks atlas migration" changes in the pixel-mania (client) repo.
# Does NOT push. Review the diff summary this prints before pushing/exporting.

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/item_database.gd",
    "Scripts/block_manager.gd",
    "Scripts/world.gd",
    "Scripts/world_lock_manager.gd",
    "Scripts/item_gameplay_manager.gd",
    "Scripts/inventory_manager.gd",
    "Scripts/shop_ui.gd",
    "Scripts/vending_preview_manager.gd"
)

Write-Host "== git status before staging ==" -ForegroundColor Cyan
git status --short

Write-Host "`n== staging blocks-atlas-migration files ==" -ForegroundColor Cyan
git add -- $files

Write-Host "`n== staged diff stat ==" -ForegroundColor Cyan
git diff --cached --stat

$commitMessage = @"
Migrate 18 block/placeable types to the shared blocks atlas (image.png)

- dirt/stone/cave_background: weighted atlas-coordinate variants
  (95/5, 70/15/15, 90/5/5) via get_stateful_block_atlas_data()
- world_lock/super_world_lock: icon/access/no_access states moved from
  standalone PNGs to atlas coordinates
- small_lock/medium_lock/big_lock/crafting_station/safe/leaf/snow_block/
  ice_block/ice_fossil/bedrock: texture/inventory_icon moved to atlas cells
- fish_monger: 4-frame 64x64 atlas regions, simple forward loop
- entrance_gate: 3-frame atlas cells, 1-2-3-2-1 ping-pong animation
- climbing_vine: now uses the generic vertical_variant_atlas_coords system
  with a new 4th "single" state (no vine above or below)
- ice_block break drop renamed to new ice_shard item (atlas 15,4)
- vend_empty/vend_pending/vend_sold consolidated into a single
  vending_machine item; visual state (empty/full/sold/out_of_stock) is now
  resolved client-side from the synced vend_state payload instead of the
  server swapping block_type
- block_manager.gd: get_block_atlas_cell_texture() now falls back to
  loading straight from image.png at 32x32 grid when an item has no
  atlas_items.json registration, so new atlas-coordinate items don't need
  TileSet registration
"@

Write-Host "`n== creating commit ==" -ForegroundColor Cyan
git commit -m $commitMessage

Write-Host "`n== git log (last commit) ==" -ForegroundColor Cyan
git log -1 --stat

Write-Host "`nDone. This commit was NOT pushed. Review it, then push/export when ready." -ForegroundColor Yellow
