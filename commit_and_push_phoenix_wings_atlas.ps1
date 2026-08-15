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

Write-Host "== PixelMania client: commit + push phoenix_wings atlas migration ==" -ForegroundColor Cyan
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
Write-Host "This switches phoenix_wings from standalone Assets/items/back_items/*.png files to" -ForegroundColor Yellow
Write-Host "the shared back_item.png atlas (row 15/16 -- phoenix_wings is a 64x64 sprite, so" -ForegroundColor Yellow
Write-Host "each frame spans both the 32px icon row and the row below it). Upgraded from its" -ForegroundColor Yellow
Write-Host "old 4-frame-idle + 1-frame-flap scheme to idle=[1,2,3], jump=[2,4,5] -- matching" -ForegroundColor Yellow
Write-Host "the 64x64_idle/64x64_jump/64x64_fall animations authored in main.tscn's preview" -ForegroundColor Yellow
Write-Host "SpriteFrames (fall/flap fall back to jump_frames automatically, since fall used the" -ForegroundColor Yellow
Write-Host "same 3 frames as jump and no separate flap animation was authored)." -ForegroundColor Yellow
Write-Host "inventory_icon now points at a dedicated (32x32) icon frame instead of reusing" -ForegroundColor Yellow
Write-Host "frame 1. back_fx_scene sparkle FX and the item's own animation_fps/flap_speed/" -ForegroundColor Yellow
Write-Host "input_flap_time left unchanged." -ForegroundColor Yellow
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
Make phoenix_wings fully atlas-driven (client)

- Add phoenix_wings_icon + phoenix_wings_1..5 to Data/items/wearable_atlas.json as
  explicit-atlas frame dictionaries pointing at Assets/items/back_item.png row 15/16
  (phoenix_wings is a 64x64 sprite, unlike the 64x32 wing rows migrated earlier): icon at
  atlas coord (0,15) -> region [0,480,32,32]; five 64x64 flap frames at atlas coords
  (1,15),(3,15),(5,15),(7,15),(9,15) -> regions [32,480,64,64], [96,480,64,64],
  [160,480,64,64], [224,480,64,64], [288,480,64,64].
- item_database.gd's phoenix_wings entry now references those atlas keys instead of
  res://Assets/items/back_items/phoenix_wings_*.png files. Upgraded from the old
  4-frame idle_frames + single-frame flap_frames (with flap_animation_loop/
  flap_pose_hold_time) to idle=[1,2,3], jump=[2,4,5] -- matching frame-for-frame the
  64x64_idle/64x64_jump/64x64_fall animations authored in main.tscn's BackItemAnimated
  SpriteFrames preview resource (64x64_fall uses the identical 3 frames as 64x64_jump,
  and no separate flap animation was authored, so fall_frames/flap_frames are left
  unset and fall back to jump_frames via equipment_manager.gd's existing fallback
  chain -- reproducing the exact same visual result without redundant duplication).
  flap_animation_loop/flap_pose_hold_time dropped (specific to the old single-frame-hold
  flap scheme). inventory_icon now points at the dedicated icon frame instead of
  reusing frame 1. sprite_folder/idle_sprite dropped. animation_fps/flap_speed/
  input_flap_time and the back_fx_scene sparkle particle FX preserved unchanged from
  the original entry.
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
