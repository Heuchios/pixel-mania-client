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

Write-Host "== PixelMania client: commit + push hand-items batch 1 atlas migration ==" -ForegroundColor Cyan
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
Write-Host "This migrates 15 hand items from standalone Assets/items/swords/*.png files to" -ForegroundColor Yellow
Write-Host "the wearable_64x32.png atlas, all as 64x64 frames / 32x32 icons (same pattern" -ForegroundColor Yellow
Write-Host "confirmed for void_saber): stone_pickaxe (row 6, 1 frame), golden_pickaxe (row 8," -ForegroundColor Yellow
Write-Host "1 frame), diamond_pickaxe (row 10, 1 frame), emerald_pickaxe (row 12, 1 frame)," -ForegroundColor Yellow
Write-Host "neptune_pickaxe (row 14, 2 frames -- matches its existing 2-frame animation, not" -ForegroundColor Yellow
Write-Host "the 3 frames initially mentioned; the atlas art itself only has 2 populated" -ForegroundColor Yellow
Write-Host "frames at this row), void_pickaxe (row 16, 3 frames), void_trident (row 19, 1" -ForegroundColor Yellow
Write-Host "frame), blood_battleaxe (row 21, 1 frame), neptune_trident (row 23, 1 frame)," -ForegroundColor Yellow
Write-Host "blue_saber/red_saber/green_saber (rows 37/39/41, 3-frame idle loop each, newly" -ForegroundColor Yellow
Write-Host "added since these previously had no animation), sakura_sword (row 43, 1 frame)," -ForegroundColor Yellow
Write-Host "ant_sword -> RENAMED to angelic_sword / 'Angelic Sword' (row 45, 4-frame idle" -ForegroundColor Yellow
Write-Host "loop, per explicit instruction -- any live inventories referencing the old" -ForegroundColor Yellow
Write-Host "ant_sword id are NOT migrated by this rename), and phoenix_sword (row 47, 4-frame" -ForegroundColor Yellow
Write-Host "idle loop). Single-frame items keep their existing punch_animation and gain no" -ForegroundColor Yellow
Write-Host "new animation block (nothing to loop). sprite_folder/idle_sprite fields were not" -ForegroundColor Yellow
Write-Host "present on any of these entries, so nothing to drop there." -ForegroundColor Yellow
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
Make 15 hand items fully atlas-driven, rename ant_sword to angelic_sword (client)

- Add icon + frame keys for stone_pickaxe, golden_pickaxe, diamond_pickaxe,
  emerald_pickaxe, neptune_pickaxe, void_pickaxe, void_trident, blood_battleaxe,
  neptune_trident, blue_saber, red_saber, green_saber, sakura_sword, angelic_sword
  (renamed from ant_sword), and phoenix_sword to Data/items/wearable_atlas.json as
  explicit-atlas frame dictionaries pointing at Assets/items/wearable_64x32.png, rows
  6/8/10/12/14/16/19/21/23/37/39/41/43/45/47. All icons are 32x32 at column 0; all
  frames are 64x64 at odd columns (1, 3, 5, 7), matching the void_saber precedent.
- item_database.gd: each item's texture/inventory_icon now reference the new atlas
  keys instead of res://Assets/items/swords/*.png files. blue_saber/red_saber/
  green_saber gain a new hand_item_animations["idle"] 3-frame loop (they had no
  animation before). neptune_pickaxe and void_pickaxe keep their existing frame
  counts/order, just re-sourced from the atlas. ant_sword's dict key and display_name
  are renamed to angelic_sword / "Angelic Sword" per explicit instruction -- this does
  NOT migrate any live player inventory that stored the old ant_sword id.
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
