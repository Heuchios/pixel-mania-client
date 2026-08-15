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

Write-Host "== PixelMania client: commit + push void_saber atlas migration ==" -ForegroundColor Cyan
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
Write-Host "This switches void_saber from standalone Assets/items/swords/*.png files to the" -ForegroundColor Yellow
Write-Host "wearable_64x32.png atlas (row 35 -- the sheet was expanded/reorganized since the" -ForegroundColor Yellow
Write-Host "first pass, which used row 18; that row is now blank) -- the first hand item" -ForegroundColor Yellow
Write-Host "migrated to atlas. Icon at atlas coord (0,35), 32x32; 3 frames at atlas coords" -ForegroundColor Yellow
Write-Host "(1,35),(3,35),(5,35), 64x64 each (hand-item frames on this sheet render at 64x64," -ForegroundColor Yellow
Write-Host "not 64x32 -- confirmed after the sword first rendered cut in half in-game)." -ForegroundColor Yellow
Write-Host "Added as an 'idle' hand_item_animations loop with a 1-2-3-2-1 ping-pong frame" -ForegroundColor Yellow
Write-Host "order at 6 fps (per explicit instruction, not the plain 1-2-3 loop used by other" -ForegroundColor Yellow
Write-Host "hand items); punch_animation stays 'punch_sword' and still drives the actual" -ForegroundColor Yellow
Write-Host "attack swing separately, unchanged." -ForegroundColor Yellow
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
Make void_saber fully atlas-driven (client)

- Add void_saber_icon + void_saber_1..3 to Data/items/wearable_atlas.json as
  explicit-atlas frame dictionaries pointing at Assets/items/wearable_64x32.png (not
  back_item.png -- this is a hand item) row 35: icon at atlas coord (0,35) -> region
  [0,1120,32,32]; three 64x64 frames at atlas coords (1,35),(3,35),(5,35) -> regions
  [32,1120,64,64], [96,1120,64,64], [160,1120,64,64]. (The sheet was expanded/
  reorganized since the item was first wired up at row 18 on the old, smaller sheet --
  row 18 is now blank; this corrects the mapping to the sword's new location. Frame
  height was also corrected from 64x32 to 64x64 -- hand-item frames on this sheet span
  two vertical rows like back_item.png's 64x64 items, confirmed after the sword
  rendered cut in half in-game with the 64x32 regions.)
- item_database.gd's void_saber entry now references those atlas keys for
  texture/inventory_icon instead of res://Assets/items/swords/void_saber*.png files,
  and gains a hand_item_animations["idle"] loop playing frames 1-2-3-2-1 (ping-pong)
  at 6 fps, looping -- per explicit instruction, rather than the plain 1-2-3 loop used
  by every other hand item's idle animation. punch_animation stays "punch_sword"
  (drives the body swing separately, unchanged).
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
