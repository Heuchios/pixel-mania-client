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

Write-Host "== PixelMania client: commit + push spiky_wings atlas migration ==" -ForegroundColor Cyan
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
Write-Host "This switches spiky_wings from standalone Assets/items/back_items/*.png files to" -ForegroundColor Yellow
Write-Host "the shared back_item.png atlas (row 5), same 4-frame pattern as parrot_wings (row 3)." -ForegroundColor Yellow
Write-Host "Row 5's 5th frame slot (atlas coord 9,5) is blank on the sheet, matching spiky_wings'" -ForegroundColor Yellow
Write-Host "original 4-frame file scheme -- no spiky_wings_5 key was added. back_item.png itself" -ForegroundColor Yellow
Write-Host "is unchanged (already committed by the appreciation_wings batch)." -ForegroundColor Yellow
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
Make spiky_wings fully atlas-driven (client)

- Add spiky_wings_icon + spiky_wings_1..4 to Data/items/wearable_atlas.json as
  explicit-atlas frame dictionaries pointing at Assets/items/back_item.png row 5: icon at
  atlas coord (0,5) -> region [0,160,32,32]; four 64x32 flap frames at atlas coords
  (1,5),(3,5),(5,5),(7,5) -> regions [32,160,64,32], [96,160,64,32], [160,160,64,32],
  [224,160,64,32]. Row 5's 5th frame slot (atlas coord 9,5) is blank on the sheet,
  matching spiky_wings' original 4-frame (not 5-frame) file scheme -- no spiky_wings_5
  key added, same as the parrot_wings (row 3) migration.
- item_database.gd's spiky_wings entry now references those atlas keys instead of
  res://Assets/items/back_items/spiky_wings_*.png files: texture/inventory_icon and the
  idle_frames/jump_frames/fall_frames/flap_frames arrays. sprite_folder/idle_sprite
  dropped. Frame ordering unchanged from the old entry (idle=[1,2,3],
  jump=fall=flap=[2,4,1]), so in-game animation timing is identical -- only the texture
  source changed.
- No new asset changes needed -- back_item.png was already added and committed by the
  appreciation_wings migration.
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
