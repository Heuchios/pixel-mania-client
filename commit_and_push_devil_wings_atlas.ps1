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

Write-Host "== PixelMania client: commit + push devil_wings atlas migration ==" -ForegroundColor Cyan
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
Write-Host "This switches devil_wings from standalone Assets/items/back_items/*.png files to the" -ForegroundColor Yellow
Write-Host "shared back_item.png atlas (row 1), same pattern as appreciation_wings. Assets/items/" -ForegroundColor Yellow
Write-Host "back_item.png itself is unchanged (already committed by the appreciation_wings batch)." -ForegroundColor Yellow
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
Make devil_wings fully atlas-driven (client)

- Add devil_wings_icon + devil_wings_1..5 to Data/items/wearable_atlas.json as
  explicit-atlas frame dictionaries pointing at Assets/items/back_item.png row 1: icon at
  atlas coord (0,1) -> region [0,32,32,32]; five 64x32 flap frames at atlas coords
  (1,1),(3,1),(5,1),(7,1),(9,1) -> regions [32,32,64,32], [96,32,64,32], [160,32,64,32],
  [224,32,64,32], [288,32,64,32]. Same pattern as appreciation_wings (row 0).
- item_database.gd's devil_wings entry now references those atlas keys instead of
  res://Assets/items/back_items/devil_wings_*.png files: texture/inventory_icon and the
  idle_frames/jump_frames/fall_frames/flap_frames arrays. sprite_folder/idle_sprite
  dropped. Frame ordering unchanged from the old entry (idle=[1,2,3], jump=[2,4,1],
  fall=[3,5,1], flap=[1,4,2] -- note flap differs from jump here, preserved as-is), so
  in-game animation timing is identical -- only the texture source changed.
- No wearable_atlas.json atlas_path/back_item.png asset changes needed here -- that sheet
  was already added and committed by the appreciation_wings migration.
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
