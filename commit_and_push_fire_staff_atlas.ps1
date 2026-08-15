Param(
    [string]$RepoPath = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function Fail($msg) {
    Write-Host $msg -ForegroundColor Red
    Write-Host ''
    Write-Host 'Press Enter to close...'
    [void][System.Console]::ReadLine()
    exit 1
}

Write-Host '== PixelMania client: commit + push Fire Staff hand item ==' -ForegroundColor Cyan
Write-Host "Repo path: $RepoPath"

Set-Location -Path $RepoPath

if (-not (Test-Path '.git')) {
    Fail "ERROR: '$RepoPath' does not look like a git repo (no .git folder). Run this script from inside pixel-mania, or pass -RepoPath."
}

$files = @(
    'Data/items/wearable_atlas.json',
    'Scripts/item_database.gd'
)

foreach ($f in $files) {
    if (-not (Test-Path $f)) {
        Fail "ERROR: expected file not found: $f (are you in the right repo?)"
    }
}

Write-Host ''
Write-Host '-- git status before --' -ForegroundColor Yellow
git status --short $files

Write-Host ''
Write-Host '-- FULL DIFF (review carefully before continuing) --' -ForegroundColor Yellow
Write-Host 'Adds a brand-new hand item, Fire Staff, on Assets/items/wearable_64x32.png row 55' -ForegroundColor Yellow
Write-Host '(y=1760px), matching the existing hand-item atlas convention: icon 32x32 at' -ForegroundColor Yellow
Write-Host 'column 0, and a 4-frame idle loop at odd columns 1/3/5/7 (64x64 each). Region' -ForegroundColor Yellow
Write-Host 'math: icon [0,1760,32,32]; frame1 [32,1760,64,64]; frame2 [96,1760,64,64];' -ForegroundColor Yellow
Write-Host 'frame3 [160,1760,64,64]; frame4 [224,1760,64,64].' -ForegroundColor Yellow
Write-Host ''
Write-Host 'item_database.gd: new "fire_staff" entry modeled directly on phoenix_sword (the' -ForegroundColor Yellow
Write-Host 'closest existing sibling -- also a 4-frame idle-only legendary hand weapon):' -ForegroundColor Yellow
Write-Host 'category tool, equipment_slot hand, hand_item true, punch_animation' -ForegroundColor Yellow
Write-Host 'punch_sword, rarity legendary, starting_count 0, animation_fps 6.0, order 67' -ForegroundColor Yellow
Write-Host '(next free slot after blood_battleaxe=66 in the hand-item order cluster).' -ForegroundColor Yellow
git --no-pager diff -- $files

Write-Host ''
Write-Host 'Press Enter to continue and stage/commit these files, or close this window to abort.' -ForegroundColor Cyan
[void][System.Console]::ReadLine()

Write-Host ''
Write-Host '-- staging --' -ForegroundColor Yellow
git add -- $files
if ($LASTEXITCODE -ne 0) { Fail 'ERROR: git add failed.' }

$staged = git diff --cached --name-only -- $files
if (-not $staged) {
    Write-Host ''
    Write-Host 'Nothing to commit -- these files already match the last commit.' -ForegroundColor Yellow
    Write-Host 'Press Enter to close...'
    [void][System.Console]::ReadLine()
    exit 0
}

$commitMessage = @'
Add Fire Staff hand item (client)

- Add fire_staff_icon + fire_staff_1..4 atlas frame keys to Data/items/wearable_atlas.json,
  pointing at Assets/items/wearable_64x32.png row 55: icon [0,1760,32,32], frames at odd
  columns 1/3/5/7 as [32,1760,64,64] / [96,1760,64,64] / [160,1760,64,64] /
  [224,1760,64,64], matching the existing hand-item atlas convention.
- Add a new "fire_staff" entry to Scripts/item_database.gd (category tool, equipment_slot
  hand, hand_item true, rarity legendary, punch_animation punch_sword, order 67), with a
  hand_item_animations["idle"] 4-frame loop at 6 fps, modeled directly on phoenix_sword.
'@

Write-Host ''
Write-Host '-- committing --' -ForegroundColor Yellow
git commit -m $commitMessage
if ($LASTEXITCODE -ne 0) { Fail 'ERROR: git commit failed.' }

Write-Host ''
Write-Host '-- pushing --' -ForegroundColor Yellow
git push
if ($LASTEXITCODE -ne 0) {
    Fail 'ERROR: git push failed. Your commit was created locally but not pushed -- check the error above (auth prompt, network, etc.) and run git push manually.'
}

Write-Host ''
Write-Host 'Done. Committed and pushed.' -ForegroundColor Green
Write-Host 'Press Enter to close...'
[void][System.Console]::ReadLine()
