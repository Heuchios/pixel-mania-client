# Commits the fishing rod migration on the CLIENT repo (pixel-mania).
# Run this from anywhere; the script cd's into the repo itself.
#
# What this migration does:
#   - Adds 5 new atlas-driven rods: wooden_fishing_rod, bamboo_fishing_rod,
#     fiberglass_fishing_rod, platinum_rod, golden_fishing_rod (icon + 3-frame
#     idle animation + fishing/"casting" frame, all via wearable_atlas.json).
#   - Keeps fishing_rod / platinum_prestige_rod as hidden legacy aliases
#     pointing at bamboo_fishing_rod / golden_fishing_rod respectively.
#   - Removes every other rod tier (refined/pristine bamboo, fiberglass,
#     tungsten) and their crafting-station upgrade recipes.
#   - Leaves neptune_rod untouched.
#
# Files touched:
#   Scripts/item_database.gd
#   Data/items/wearable_atlas.json
#   Scripts/station_recipes.gd
#   Scripts/fishing_manager.gd

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

Write-Host "=== git status (before) ===" -ForegroundColor Cyan
git status

Write-Host ""
Write-Host "=== git diff --stat ===" -ForegroundColor Cyan
git diff --stat -- Scripts/item_database.gd Data/items/wearable_atlas.json Scripts/station_recipes.gd Scripts/fishing_manager.gd

Write-Host ""
Write-Host "=== Full diff for review (scoped to the 4 touched files) ===" -ForegroundColor Cyan
git --no-pager diff -- Scripts/item_database.gd Data/items/wearable_atlas.json Scripts/station_recipes.gd Scripts/fishing_manager.gd

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit these 4 files, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add Scripts/item_database.gd Data/items/wearable_atlas.json Scripts/station_recipes.gd Scripts/fishing_manager.gd

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
Migrate fishing rods to atlas-driven visuals, remove old rod tiers

- Add wooden_fishing_rod, bamboo_fishing_rod, fiberglass_fishing_rod,
  platinum_rod, golden_fishing_rod with icon + 3-frame idle animation
  + fishing animation frame, sourced from wearable_64x32.png atlas.
- Keep fishing_rod and platinum_prestige_rod as hidden legacy aliases
  pointing at bamboo_fishing_rod / golden_fishing_rod.
- Remove refined/pristine bamboo, fiberglass, and tungsten rod tiers.
- Remove their crafting-station upgrade recipes from station_recipes.gd.
- Update fishing_manager.gd's rod-id allowlist and legacy-id normalizer.
- neptune_rod left untouched.
"@

git commit -m $commitMessage

Write-Host ""
Write-Host "=== git log -1 ===" -ForegroundColor Cyan
git log -1

Write-Host ""
Write-Host "Pushing..." -ForegroundColor Cyan
git push

Write-Host ""
Write-Host "Done. Client repo pushed." -ForegroundColor Green
