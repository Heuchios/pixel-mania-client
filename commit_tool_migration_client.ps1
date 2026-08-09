# Commits the electric_tool / wire_cutter / metal_detector atlas migration
# on the CLIENT repo (pixel-mania).
#
# - electric_tool: moved off its standalone PNGs onto the atlas
#   (electric_tool_icon / electric_tool_1). Same stats, just new visuals.
# - wire_cutter, metal_detector: new hand-equip tool items, modeled on
#   electric_tool's shape (rarity common, shop_price 0 / not sellable yet).
#
# Files touched:
#   Scripts/item_database.gd
#   Data/items/wearable_atlas.json
#
# Uses a glob (commit_tool_*.ps1) when adding itself, so this script
# doesn't get left behind as an untracked file blocking deploy.

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

Write-Host "=== git status (before) ===" -ForegroundColor Cyan
git status

Write-Host ""
Write-Host "=== git diff --stat ===" -ForegroundColor Cyan
git diff --stat -- Scripts/item_database.gd Data/items/wearable_atlas.json

Write-Host ""
Write-Host "=== Full diff for review ===" -ForegroundColor Cyan
git --no-pager diff -- Scripts/item_database.gd Data/items/wearable_atlas.json

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add Scripts/item_database.gd Data/items/wearable_atlas.json commit_tool_*.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
Move electric_tool to atlas, add wire_cutter and metal_detector

- electric_tool: texture/inventory_icon now point at electric_tool_1 /
  electric_tool_icon on wearable_64x32.png instead of standalone PNGs.
  Stats unchanged.
- Add wire_cutter and metal_detector as new hand-equip tool items,
  same shape as electric_tool (rarity common, shop_price 0 - not sellable
  yet, no shop catalog entry).
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
