#!/usr/bin/env pwsh
# Commits the icon/seed-box-preview follow-up fix for the "blocks atlas migration
# batch 2" items in the pixel-mania (client) repo. Does NOT push.

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/item_database.gd"
)

Write-Host "== git status before staging ==" -ForegroundColor Cyan
git status --short

Write-Host "`n== staged diff stat (after staging) ==" -ForegroundColor Cyan
git add -- $files
git diff --cached --stat

$commitMessage = @"
Fix inventory/hotbar icons and seed-box previews for atlas-migration batch 2

World-tile rendering (atlas_coords) was fixed in the prior batch-2 commit,
but icon resolution reads separate fields (texture / inventory_icon, and
animation_frames[0] for seed-box previews) that were left pointing at the
old per-item PNGs, so hotbar icons and the seed-box "grows into" preview
still showed stale art for these items.

Added/updated "texture" and "inventory_icon" atlas-dict fields
({"atlas": "res://image.png", "cell": [x, y], "cell_size": [32, 32]})
matching each item's existing atlas_coords, for: lava, water, snow_dirt,
ice_treasure, snow_leaf, frozen_treasure, frozen_treasure_2, pile_of_snow,
snow_stone, grass, rose, sunflower, hanging_vine, apple, lily,
wood_platform, wooden_entrance, sign, mushroom, wooden_ladder,
wood (tree trunk, bottom-variant icon), sand (primary-variant icon).

grass and frozen_grass also had their "animation_frames" arrays converted
from legacy PNG-path strings to the same atlas-dict entries (matching their
existing animation_atlas_coords), because get_seed_preview_block_texture()
in world.gd checks animation_frames[0] BEFORE the texture field when
building the seed-box "grows into" preview -- leaving that array untouched
would have kept showing old art for grass_seed's preview even after the
texture/inventory_icon fix.

ice_fossil, wooden_treasure_chest, and wooden_treasure_chest_open already
had correct atlas-dict texture/inventory_icon fields from the prior batch
and were left unchanged. wood/lava/water/wooden_entrance also already
resolved correctly via the separate legacy ItemAtlasDB (Data/items/atlas_items.json)
name lookup, which item_gameplay_manager.get_inventory_icon_texture() checks
before the inventory_icon field for category "block" items -- their
Data/items/atlas_items.json entries already point at the new atlas
coordinates, so no data file change was needed there; the texture/
inventory_icon dict fields were still added for consistency and as a
fallback if that lookup is ever disabled for those keys.

No gameplay/collision/animation-atlas fields were touched; this is a
data-only icon-resolution fix.
"@

Write-Host "`n== creating commit ==" -ForegroundColor Cyan
git commit -m $commitMessage

Write-Host "`n== git log (last commit) ==" -ForegroundColor Cyan
git log -1 --stat

Write-Host "`nDone. This commit was NOT pushed. Review it, then push/export when ready." -ForegroundColor Yellow
