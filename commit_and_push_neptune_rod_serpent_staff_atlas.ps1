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

Write-Host '== PixelMania client: merge Neptune Rod to atlas + rename Pulu Pulu to Serpent Staff ==' -ForegroundColor Cyan
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
Write-Host 'Neptune Rod (row 49, y=1568px): re-sourced from res://Assets/items/fishing/*.png' -ForegroundColor Yellow
Write-Host 'files to the wearable_64x32.png atlas -- icon [0,1568,32,32], frames at odd' -ForegroundColor Yellow
Write-Host 'columns 1/3/5/7 as [32,1568,64,64] / [96,1568,64,64] / [160,1568,64,64] /' -ForegroundColor Yellow
Write-Host '[224,1568,64,64]. The existing 7-frame ping-pong idle sequence' -ForegroundColor Yellow
Write-Host '(1-2-3-4-3-2-1) and every fishing-rod-specific field (hand_mode, hand_hold_point,' -ForegroundColor Yellow
Write-Host 'hand_scale, hand_rotation, hand_rotation_left, fishing_line_tip_offset) are UNCHANGED' -ForegroundColor Yellow
Write-Host '-- only the frame source moved from loose files to atlas keys.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Pulu Pulu -> RENAMED to Serpent Staff (row 51, y=1632px): icon [0,1632,32,32],' -ForegroundColor Yellow
Write-Host 'frames [32,1632,64,64] / [96,1632,64,64] / [160,1632,64,64] / [224,1632,64,64].' -ForegroundColor Yellow
Write-Host 'This item previously had no animation at all (a single static texture) -- it now' -ForegroundColor Yellow
Write-Host 'gains a new hand_item_animations idle 4-frame loop, matching how blue/red/green' -ForegroundColor Yellow
Write-Host 'saber gained animations during the earlier hand-items batch. order (44) kept' -ForegroundColor Yellow
Write-Host 'unchanged per the established rename convention. NOTE: this does NOT migrate any' -ForegroundColor Yellow
Write-Host 'live player inventory that already stored the old pulu_pulu id -- that would be a' -ForegroundColor Yellow
Write-Host 'separate data migration.' -ForegroundColor Yellow
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
Merge Neptune Rod to atlas, rename Pulu Pulu to Serpent Staff (client)

- Add neptune_rod_icon + neptune_rod_1..4 atlas frame keys to
  Data/items/wearable_atlas.json (wearable_64x32.png row 49) and re-point
  neptune_rod's texture/inventory_icon/hand_item_animations idle frames at them,
  preserving the existing 7-frame ping-pong sequence (1-2-3-4-3-2-1) and every
  fishing-rod-specific field untouched.
- Add serpent_staff_icon + serpent_staff_1..4 atlas frame keys (wearable_64x32.png
  row 51). Rename the pulu_pulu item entry to serpent_staff (display_name "Serpent
  Staff"), point texture/inventory_icon at the new atlas keys, and add a new
  hand_item_animations idle 4-frame loop at 6 fps (this item had no animation
  before). order (44) kept unchanged.
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
