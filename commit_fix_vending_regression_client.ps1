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

Write-Host "== PixelMania client: fix vending_machine/18-block-type consolidation regression ==" -ForegroundColor Cyan
Write-Host "Repo path: $RepoPath"

Set-Location -Path $RepoPath

if (-not (Test-Path ".git")) {
    Fail "ERROR: '$RepoPath' does not look like a git repo (no .git folder). Run this script from inside pixel-mania, or pass -RepoPath."
}

if (-not (Test-Path "Scripts/item_database.gd")) {
    Fail "ERROR: Scripts/item_database.gd not found (are you in the right repo?)"
}

$files = @("Scripts/item_database.gd")

Write-Host ""
Write-Host "-- git status before --" -ForegroundColor Yellow
git status --short $files

Write-Host ""
Write-Host "-- FULL DIFF (review carefully before continuing) --" -ForegroundColor Yellow
Write-Host "My earlier hand-items-batch-1 commit (0817ed32) was built from a local copy of" -ForegroundColor Yellow
Write-Host "item_database.gd that I had staged BEFORE commit 3412a88f ('Migrate 18" -ForegroundColor Yellow
Write-Host "block/placeable types to the shared blocks atlas') landed. Writing that stale" -ForegroundColor Yellow
Write-Host "copy back overwrote/reverted all 18 of those block-type migrations, including the" -ForegroundColor Yellow
Write-Host "vend_empty/vend_pending/vend_sold -> vending_machine consolidation -- that's why" -ForegroundColor Yellow
Write-Host "check:machine-break-return started failing on deploy." -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow
Write-Host "This commit fixes it by starting fresh from 3412a88f's version of the file (which" -ForegroundColor Yellow
Write-Host "has the full 18-block-type migration intact) and re-applying ONLY the 15" -ForegroundColor Yellow
Write-Host "hand-items-batch-1 field changes on top of it -- stone/golden/diamond/emerald/" -ForegroundColor Yellow
Write-Host "neptune/void pickaxe, void_trident, blood_battleaxe, neptune_trident, blue/red/" -ForegroundColor Yellow
Write-Host "green_saber (incl. their new 3-frame idle animations), sakura_sword, angelic_sword" -ForegroundColor Yellow
Write-Host "(renamed from ant_sword), and phoenix_sword. Nothing about dirt/stone/cave_bg," -ForegroundColor Yellow
Write-Host "world_lock/super_world_lock, the other 6 lock/station/block items, fish_monger," -ForegroundColor Yellow
Write-Host "entrance_gate, climbing_vine, ice_block's ice_shard drop rename, or vending_machine" -ForegroundColor Yellow
Write-Host "should appear in this diff -- if it does, STOP and don't commit." -ForegroundColor Red
git --no-pager diff -- $files
Write-Host ""
Write-Host "Press Enter to continue and stage/commit this file, or close this window to abort." -ForegroundColor Cyan
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
Fix: restore 18-block-type/vending_machine consolidation reverted by hand-items commit

Commit 0817ed32 (hand-items batch 1) was built from a stale local copy of
item_database.gd that predated 3412a88f ("Migrate 18 block/placeable types
to the shared blocks atlas"). Writing that copy back to disk and committing
it silently reverted all 18 block-type migrations from 3412a88f, including
the vend_empty/vend_pending/vend_sold -> vending_machine consolidation,
while I was unaware anything besides the hand-items fields had changed.

This commit rebuilds the file starting from 3412a88f's content and
re-applies only the 15 hand-items-batch-1 field changes (texture/
inventory_icon atlas-key swaps, the neptune_pickaxe/void_pickaxe/
angelic_sword animation frame repoints, and the new blue_saber/red_saber/
green_saber idle animations) on top. Nothing else changed. Verified via a
diff against 3412a88f showing only the 15 hand items, plus brace/bracket/
paren balance checks and byte-for-byte confirmation that every line
introduced by 3412a88f outside those 15 items is untouched.
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
Write-Host "You can now delete the scratch files: item_database_GOOD_BASE.gd," -ForegroundColor Cyan
Write-Host "vending_machine_regression_client.diff -- they were only needed for this fix." -ForegroundColor Cyan
Write-Host "Press Enter to close..."
[void][System.Console]::ReadLine()
