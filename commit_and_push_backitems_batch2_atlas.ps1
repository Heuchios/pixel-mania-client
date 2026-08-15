Param(
    [string]$RepoPath = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

function Fail($msg) {
    Write-Host $msg -ForegroundColor Red
    Write-Host ""
    Write-Host "Press Enter to close..."
    [void][System.Console]::ReadLine()
    exit 1
}

Write-Host "== PixelMania client: commit + push back-item atlas migration batch 2 ==" -ForegroundColor Cyan
Write-Host "Items: carboard_wings, angel_wings, golden_angel_wings (new), void_aura," -ForegroundColor Cyan
Write-Host "       blue_jetpack, green_jetpack (was purple_jetpack), dragon_fire_wings (was flaming_wings)" -ForegroundColor Cyan
Write-Host "Repo path: $RepoPath"

Set-Location -Path $RepoPath

if (-not (Test-Path ".git")) {
    Fail "ERROR: '$RepoPath' does not look like a git repo (no .git folder). Run this script from inside pixel-mania, or pass -RepoPath."
}

$files = @(
    "Data/items/wearable_atlas.json",
    "Scripts/item_database.gd"
)

foreach ($f in $files) {
    if (-not (Test-Path $f)) {
        Fail "ERROR: expected file not found: $f (are you in the right repo?)"
    }
}

Write-Host ""
Write-Host "-- git status before --" -ForegroundColor Yellow
git status --short $files

Write-Host ""
Write-Host "-- FULL DIFF (review carefully before continuing) --" -ForegroundColor Yellow
Write-Host "This migrates 7 back items to the shared back_item.png atlas (rows 4,6,7,8,10,12,14):" -ForegroundColor Yellow
Write-Host "  - carboard_wings   row 4  (icon+3 frames, idle/jump/fall all identical, unchanged)" -ForegroundColor Yellow
Write-Host "  - angel_wings      row 6  (upgraded 2-frame -> 5-frame devil_wings-style animation)" -ForegroundColor Yellow
Write-Host "  - golden_angel_wings row 7 (BRAND NEW item, modeled on angel_wings/devil_wings pattern," -ForegroundColor Yellow
Write-Host "        rarity/trade flags are reasonable defaults -- adjust in item_database.gd if needed)" -ForegroundColor Yellow
Write-Host "  - void_aura        row 8/9  (64x64 frames, jump/idle/fall share one animation, unchanged)" -ForegroundColor Yellow
Write-Host "  - blue_jetpack     row 10/11 (64x64 jp_jump frames; idle now a static pose = frame 1, no anim)" -ForegroundColor Yellow
Write-Host "  - green_jetpack    row 12/13 (RENAMED from purple_jetpack -- item id/display_name changed!" -ForegroundColor Yellow
Write-Host "        any live inventories referencing 'purple_jetpack' will need a data migration)" -ForegroundColor Yellow
Write-Host "  - dragon_fire_wings row 14 (RENAMED from flaming_wings -- item id/display_name changed!" -ForegroundColor Yellow
Write-Host "        any live inventories referencing 'flaming_wings' will need a data migration)" -ForegroundColor Yellow
Write-Host ""
git --no-pager diff -- $files

Write-Host ""
Write-Host "Press Enter to continue and stage/commit these files, or close this window to abort." -ForegroundColor Cyan
[void][System.Console]::ReadLine()

Write-Host ""
Write-Host "-- staging --" -ForegroundColor Yellow
git add -- $files
if ($LASTEXITCODE -ne 0) { Fail "ERROR: git add failed." }

$staged = git diff --cached --name-only -- $files
if (-not $staged) {
    Write-Host ""
    Write-Host "Nothing to commit -- these files already match the last commit." -ForegroundColor Yellow
    Write-Host "Press Enter to close..."
    [void][System.Console]::ReadLine()
    exit 0
}

$commitMessage = @"
Migrate 7 back items to shared back_item.png atlas (batch 2)

- carboard_wings (row 4): icon + 3 flap frames, idle/jump/fall/flap all share the
  same 3-frame cycle, matching the original file-based entry exactly. Item id keeps
  its existing "carboard_wings" spelling (typo predates this migration, not touched).
- angel_wings (row 6): was a 2-frame idle + 2-frame flap scheme using standalone
  files; now uses the full 5-frame devil_wings-style pattern (idle=[1,2,3],
  jump=[2,4,1], fall=[3,5,1], flap=[1,4,2]) sourced from the atlas. back_fx_scene
  sparkle particle FX left untouched.
- golden_angel_wings (row 7): NEW item, added modeled directly on angel_wings /
  devil_wings' 5-frame pattern and FX. rarity/tradeable/vendable/dropable use
  reasonable defaults (legendary, all true) -- review/adjust in item_database.gd
  if different values are wanted.
- void_aura (row 8-9): 64x64 aura frames (icon stays 32x32), idle_frames and
  flap_frames both list the same 4 frames -- jump/fall continue to fall back to
  flap_frames via equipment_manager.gd, identical behavior to before.
- blue_jetpack (row 10-11): 64x64 jp_jump frames. No separate idle art exists in
  the atlas, so idle now falls back to flap_frames[0] (a static pose, no
  animation) same intent as the old idle_sprite-only scheme. flap_frames grew
  from 3 to 4 frames to match the atlas.
- green_jetpack (row 12-13): RENAMED from purple_jetpack (item id + display_name).
  Same 64x64 jp_jump / static-idle pattern as blue_jetpack. NOTE: any live player
  inventories/shops referencing the old "purple_jetpack" id will need a data
  migration -- this change does not migrate existing item instances.
- dragon_fire_wings (row 14): RENAMED from flaming_wings (item id + display_name).
  Upgraded to the full 5-frame devil_wings-style pattern like angel_wings/
  golden_angel_wings. back_fx_scene sparkle FX left untouched. NOTE: same
  live-inventory caveat as green_jetpack applies to the "flaming_wings" id.

All items: sprite_folder/idle_sprite dropped, texture/inventory_icon/frame arrays
now reference wearable_atlas.json keys resolved by AtlasTextureFactory. No
equipment_manager.gd or atlas_texture_factory.gd changes needed. back_item.png
itself is unchanged (already committed by the appreciation_wings migration).
"@

Write-Host ""
Write-Host "-- committing --" -ForegroundColor Yellow
git commit -m $commitMessage
if ($LASTEXITCODE -ne 0) { Fail "ERROR: git commit failed." }

Write-Host ""
Write-Host "-- pushing --" -ForegroundColor Yellow
git push
if ($LASTEXITCODE -ne 0) {
    Fail "ERROR: git push failed. Your commit was created locally but not pushed -- check the error above (auth prompt, network, etc.) and run 'git push' manually."
}

Write-Host ""
Write-Host "Done. Committed and pushed." -ForegroundColor Green
Write-Host "Press Enter to close..."
[void][System.Console]::ReadLine()
