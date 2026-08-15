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

Write-Host "== PixelMania client: commit + push wearable atlas + beard/eyewear equip system changes ==" -ForegroundColor Cyan
Write-Host "Repo path: $RepoPath"

Set-Location -Path $RepoPath

if (-not (Test-Path ".git")) {
    Fail "ERROR: '$RepoPath' does not look like a git repo (no .git folder). Run this script from inside pixel-mania, or pass -RepoPath."
}

$files = @(
    "Data/items/wearable_atlas.json",
    "Scripts/item_database.gd",
    "Scripts/equipment_manager.gd",
    "Scripts/world.gd",
    "Scripts/save_manager.gd",
    "Scripts/network_manager.gd",
    "Scripts/player_manager.gd",
    "Scripts/inventory_manager.gd",
    "Scripts/player_menu_ui.gd",
    "Scripts/shop_ui.gd",
    "Scripts/developer_panel_ui.gd",
    "Scripts/command_manager.gd",
    "Scripts/item_gameplay_manager.gd",
    "Scripts/trade_ui.gd"
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
Write-Host "This batch touched 14 files, including several large ones (equipment_manager.gd," -ForegroundColor Yellow
Write-Host "world.gd, save_manager.gd, network_manager.gd, player_manager.gd, inventory_manager.gd)" -ForegroundColor Yellow
Write-Host "to add a full 'beard' equipment slot end to end (equip, save/load, multiplayer sync," -ForegroundColor Yellow
Write-Host "shop/inventory UI, dev panel, /give command, trading) alongside the eyewear pattern." -ForegroundColor Yellow
Write-Host "None of this has been tested in the Godot editor. Please scroll through the diff below" -ForegroundColor Yellow
Write-Host "and confirm every removed/changed line (lines starting with '-') is expected -- especially" -ForegroundColor Yellow
Write-Host "in equipment_manager.gd, in case there were unsaved edits there before this ran." -ForegroundColor Yellow
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
Switch baseball caps to atlas, add 8 new hats, add sunglasses + full beard equipment slot

- Switch red_baseball_cap, green_baseball_cap, blue_baseball_cap from standalone
  res:// textures to wearable atlas frames; add straw_hat, yellow_cap, white_cap,
  red_headband, chefs_hat, cowboy_hat, top_hat, black_fedora (hat slot, atlas
  rows 0,1,2,3,4,5,6,8,9,10,11 -- row 7 is the existing royal_crown, untouched).
- Add sunglasses (eyewear slot, atlas row 0 cols 22/23) using the existing
  eyewear rendering path (EyewearAnimated node, already wired end to end).
- Add black_beard (new beard slot, atlas row 1 cols 22/23) and wire up a
  complete beard equipment slot from scratch, mirroring the eyewear slot at
  every layer that eyewear touches:
    - equipment_manager.gd: beard_item_animated node on PlayerVisual/Head/BeardAnimated,
      update_equipped_beard_visual(), reset/clear wiring.
    - world.gd: equipped_beard_item, beard_inventory, beard_textures, beard_items,
      category/equip-property lookups, setup/clear/load loops, update_equipment_visual
      dispatch and visual-key change detection.
    - save_manager.gd: beard added to every save/load/snapshot/restore/dedup-hash path
      that eyewear appears in (~15 sites).
    - network_manager.gd: beard added to the remote equipment_slots sync payload and
      the generic slot-name -> property mapping used for multiplayer sync.
    - player_manager.gd: beard added to remote-player equip dispatch, slot-name
      whitelists, texture resolution, default offsets, and walk-animation bob.
    - inventory_manager.gd: beard added to hotbar-equipable check, texture/count
      lookups, scene signature, spend/auto-unequip, visible-item listing (both
      inventory and equip-check code paths), and category whitelist chains.
    - item_gameplay_manager.gd: equip_beard_item()/get_equipped_beard_text(), added
      to is_item_equipable(), toggle_equip_item() dispatch, texture/count lookups,
      and the local equipment debug snapshot.
    - player_menu_ui.gd, shop_ui.gd, developer_panel_ui.gd, command_manager.gd,
      trade_ui.gd: beard added everywhere eyewear appears (profile equip data,
      shop grant/texture lookup, dev panel inventory browser + equip summary,
      chat /give command, trade window listing).
  This has NOT been tested in the Godot editor -- please verify equip/save/multiplayer
  behavior for black_beard before relying on it.
- Not added to any shop pack in this change.
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
