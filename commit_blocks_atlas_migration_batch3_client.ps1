#!/usr/bin/env pwsh
# Commits the third "blocks atlas migration" batch in the pixel-mania (client) repo.
# Does NOT push. Review the diff summary this prints before pushing/exporting.

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/item_database.gd",
    "Scripts/block_manager.gd",
    "Scripts/world.gd",
    "Data/items/atlas_items.json"
)

Write-Host "== git status before staging ==" -ForegroundColor Cyan
git status --short

Write-Host "`n== staged diff stat (after staging) ==" -ForegroundColor Cyan
git add -- $files
git diff --cached --stat

$commitMessage = @"
Migrate wooden furniture, colour blocks, and colour wallpapers to the atlas

Wooden Tier-1 furniture set (image.png row y=6):
- wooden_block (0,6), wooden_fence (4,6, newly given atlas_coords),
  wooden_chair (5,6), wooden_table (6,6 single / 7,6 left / 8,6 middle /
  9,6 right) -- atlas_coords already correct from an earlier pass, added
  proper texture/inventory_icon atlas-dict fields (were still old PNG
  paths, or missing entirely for wooden_chair/wooden_table).
- wooden_door (3,6): had no atlas_coords at all -- added, plus
  texture/inventory_icon.
- wooden_background -> wooden_wallpaper (1,6): full id rename (display
  name "Wooden Background" -> "Wooden Wallpaper"). Legacy-aliased.
- wooden_frame -> wooden_window (2,6): full id rename (Hassan confirmed
  this is what "wooden window" in his list referred to, since wooden_frame
  already occupied that exact cell). Legacy-aliased.
- New block: wooden_crappy_sign (10,6), non-collideable, sign_block: true,
  self-drops -- modeled on the existing "sign" item.
- sand_castle (12,6) and pile_of_sand (13,6, already no_collision): had no
  atlas_coords -- added, plus texture/inventory_icon.

Colour blocks (image.png rows y=7/8/9), all 30 existing items:
- Added texture/inventory_icon atlas-dict fields to every one (all were
  still plain per-item PNG paths); filled in the one missing atlas_coords
  (green_block, 2,7) and gem_block's missing atlas_coords (10,7, as part
  of its rename below).
- Renamed, per Hassan's clarification on the ambiguous/colliding names in
  his list:
  - dark_red_block -> maroon_block (4,7). dark_pink_block (6,9), which
    also seemed to match "maroon" in the list, was explicitly left as-is.
  - light_brown_block -> dark_orange_block (4,8).
  - gem_block -> rainbow_block (10,7) -- also added its previously-missing
    atlas_coords.
  - shift_block -> shifty_block (10,8) -- this one already had a working
    icon via its atlas_item_id (57) legacy lookup, but its texture/
    inventory_icon fields were literally "res://image.png" (the whole
    sheet) as an unused placeholder; fixed those too.
  - pastel_flower_block (9,9) was explicitly left as-is (Hassan chose not
    to rename it to "flower_block").
  All 4 renames got a normalize_legacy_block_id() alias in block_manager.gd
  and a repointed seed grows_into (seed ids themselves are unchanged, e.g.
  dark_red_block_seed still exists, now grows_into maroon_block).
  world.gd's COLOURED_BLOCK_IDS list (drives
  apply_coloured_block_seed_and_drop_rules()) was updated for the two
  renamed keys it references -- missing this would have silently dropped
  seed/drop_rules setup for maroon_block/dark_orange_block after the
  rename, since that function looks items up by the OLD dict key.

Colour wallpapers -- reused the EXISTING colour background item set
(white_bg/red_bg/... at Data/items pattern "_bg"), which already had the
exact atlas_coords Hassan asked for; renamed each to "_wallpaper" rather
than creating new duplicate items:
  white_bg->white_wallpaper (0,10), red_bg->red_wallpaper (1,10),
  green_bg->green_wallpaper (2,10), brown_bg->brown_wallpaper (3,10),
  grey_bg->grey_wallpaper (0,11), orange_bg->orange_wallpaper (1,11),
  aqua_bg->aqua_wallpaper (2,11), purple_bg->purple_wallpaper (3,11),
  black_bg->black_wallpaper (0,12), yellow_bg->yellow_wallpaper (1,12),
  blue_bg->blue_wallpaper (2,12), pink_bg->pink_wallpaper (3,12).
Added texture/inventory_icon atlas-dict fields to all 12 (were plain old
PNG paths) and legacy-aliased every old "_bg" id.

Data/items/atlas_items.json: wooden_background and shift_block are
registered there (ids 5 and 57) and are read via
ItemAtlasDB.merge_item_database() at world load, which re-merges JSON
fields into item_database BY THE JSON's item_key -- renaming only the
.gd dict key would have left a stale "wooden_background"/"shift_block"
ghost entry re-created every load. Updated item_key (and name, and the
self-drop item_id inside shift_block's own drop_rules) for both ids to
the new names so the merge stays in sync. wooden_door/wooden_chair/
wooden_table are also registered there but were NOT renamed, so their
JSON entries are untouched.
"@

Write-Host "`n== creating commit ==" -ForegroundColor Cyan
git commit -m $commitMessage

Write-Host "`n== git log (last commit) ==" -ForegroundColor Cyan
git log -1 --stat

Write-Host "`nDone. This commit was NOT pushed. Review it, then push/export when ready." -ForegroundColor Yellow
