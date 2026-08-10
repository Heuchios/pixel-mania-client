#!/usr/bin/env pwsh
# Commits the second "blocks atlas migration" batch in the pixel-mania (client) repo.
# Does NOT push. Review the diff summary this prints before pushing/exporting.

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/item_database.gd",
    "Scripts/block_manager.gd"
)

Write-Host "== git status before staging ==" -ForegroundColor Cyan
git status --short

Write-Host "`n== staged diff stat (after staging) ==" -ForegroundColor Cyan
git add -- $files
git diff --cached --stat

$commitMessage = @"
Migrate 24 more block/placeable types to the shared blocks atlas (image.png)

- lava/water/snow_dirt/ice_fossil/snow_leaf/snow_stone/wooden_ladder/
  wooden_entrance were already atlas-correct; left untouched.
- grass: atlas_coords (0,4) + animation_atlas_coords 3-frame 1-2-3-2-1 loop
  at (0,4)/(1,4)/(2,4), alongside the existing file-based animation_frames.
- wood (tree trunk): converted to the generic vertical_variant_atlas_coords
  system (top (9,2) / middle (9,3) / bottom (9,4)); removed the old
  hardcoded TREE_TRUNK_*_TEXTURE_PATH branch in block_manager.gd's
  get_stateful_block_texture_path (now dispatches through
  get_stateful_block_atlas_data, matching the climbing_vine precedent).
- sand: added sand_atlas_variants/sand_atlas_weights (75/15/15 at
  (11,5)/(12,5)/(11,6)); added a new hardcoded "sand" branch in
  block_manager.gd's get_stateful_block_atlas_data (salt 41) mirroring
  dirt/stone/cave_background.
- apple (8,3), rose (3,4), lily (4,4), sign (5,5), pile_of_snow (12,3,
  already no_collision), frozen_treasure (12,4), frozen_treasure_2 (13,4):
  added atlas_coords only.
- frozen_grass + hidden frozen_grass_1/2/3: added atlas_coords +
  animation_atlas_coords 3-frame loop at (13,3)/(14,3)/(15,3).
- mushroom: added atlas_coords (7,4, idle) and
  springboard_animation_atlas_frames [(7,4),(8,4)] alongside the existing
  file-based springboard_animation_frames.
- wood_platform: added atlas_coords (0,5, single) and replaced
  platform_variant_textures (file paths) with platform_variant_atlas_coords
  left (1,5) / middle (2,5) / right (3,5).
- New block: wooden_treasure_chest (9,5 closed, placeable) and hidden
  wooden_treasure_chest_open (10,5) reserved for a future open/close
  interaction -- no interaction logic wired yet.
- Renamed (full id rename, with legacy-id compatibility):
  - vines -> hanging_vine (atlas 6,3). normalize_legacy_block_id in
    block_manager.gd now maps old "vines" placements to "hanging_vine".
  - ice_block_2 -> ice_treasure (atlas unchanged, 14,2; display name fixed
    to "Ice Treasure"). get_snow_storm_ice_block_type() now returns the
    new id. normalize_legacy_block_id aliases the old id.
  - tulip -> sunflower (atlas 5,4). The old, unrelated "sun_flower" item
    (own seed/recipe chain) is retired (hidden: true) rather than deleted,
    so nothing already holding/placed as sun_flower breaks.
    normalize_legacy_block_id aliases the old "tulip" id.
  - tulip_seed / vines_seed ids are UNCHANGED; only their grows_into
    targets were repointed to the new ids.
"@

Write-Host "`n== creating commit ==" -ForegroundColor Cyan
git commit -m $commitMessage

Write-Host "`n== git log (last commit) ==" -ForegroundColor Cyan
git log -1 --stat

Write-Host "`nDone. This commit was NOT pushed. Review it, then push/export when ready." -ForegroundColor Yellow
