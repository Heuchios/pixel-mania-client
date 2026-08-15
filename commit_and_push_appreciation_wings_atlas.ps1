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

Write-Host "== PixelMania client: commit + push appreciation_wings atlas migration ==" -ForegroundColor Cyan
Write-Host "Repo path: $RepoPath"

Set-Location -Path $RepoPath

if (-not (Test-Path ".git")) {
    Fail "ERROR: '$RepoPath' does not look like a git repo (no .git folder). Run this script from inside pixel-mania, or pass -RepoPath."
}

$files = @(
    "Data/items/wearable_atlas.json",
    "Scripts/item_database.gd",
    "Assets/items/back_item.png",
    "Assets/items/back_item.png.import"
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
Write-Host "This switches appreciation_wings from standalone Assets/items/back_items/*.png files" -ForegroundColor Yellow
Write-Host "to the shared wearable atlas (Assets/items/back_item.png, driven entirely through" -ForegroundColor Yellow
Write-Host "Data/items/wearable_atlas.json + item_database.gd atlas frame keys). No equipment_manager.gd" -ForegroundColor Yellow
Write-Host "changes were needed -- back item frame resolution already checks the wearable atlas" -ForegroundColor Yellow
Write-Host "manifest before falling back to sprite_folder paths." -ForegroundColor Yellow
Write-Host ""
git --no-pager diff -- "Data/items/wearable_atlas.json" "Scripts/item_database.gd"
git status --short "Assets/items/back_item.png" "Assets/items/back_item.png.import"

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
Make appreciation_wings fully atlas-driven (client)

- Add appreciation_wings_icon + appreciation_wings_1..5 to Data/items/wearable_atlas.json
  as explicit-atlas frame dictionaries pointing at the new Assets/items/back_item.png sheet
  (row 0): icon at atlas coord (0,0) -> region [0,0,32,32]; five 64x32 flap frames at atlas
  coords (1,0),(3,0),(5,0),(7,0),(9,0) -> regions [32,0,64,32], [96,0,64,32], [160,0,64,32],
  [224,0,64,32], [288,0,64,32]. Each frame carries its own "atlas" key so it resolves against
  back_item.png instead of the manifest's default wearable.png.
- item_database.gd's appreciation_wings entry now references those atlas keys instead of
  res://Assets/items/back_items/appreciation_wings_*.png files: texture/inventory_icon and
  the idle_frames/jump_frames/fall_frames/flap_frames arrays. sprite_folder/idle_sprite were
  dropped (no longer needed -- AtlasTextureFactory resolves the atlas keys directly).
  idle/jump/fall/flap frame ordering is unchanged from the old file-based entry (idle=[1,2,3],
  jump=[2,4,1], fall=[3,5,1], flap=[2,4,1]), so in-game animation timing is identical -- only
  the texture source changed.
- Add Assets/items/back_item.png (+ .import) -- the new shared back-item atlas sheet.
- No equipment_manager.gd changes: _resolve_wearable_frame_texture() and the texture/
  inventory_icon load paths already try AtlasTextureFactory.load_texture() against the
  wearable atlas manifest before falling back to sprite_folder/file paths, so atlas keys
  and res:// paths were already interchangeable in every field this item uses.
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
