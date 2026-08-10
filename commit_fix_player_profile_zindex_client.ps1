# Commits the player-profile z_index fix on the CLIENT repo (pixel-mania).
#
# Bug: the Player Profile popup (avatar, stats, showcase, Add Friend button) was rendering
# BEHIND the hotbar -- the hotbar's icons overlapped and covered the bottom of the popup
# (showcase slots, Add Friend button), making it unusable there.
#
# Root cause: both the profile popup and the hotbar are parented under the same "UI"
# CanvasLayer (profile -> ModalLayer, hotbar -> HudLayer), so Godot compares z_index
# directly to decide draw order within that layer. The hotbar explicitly sets
# z_index = 176 (HOTBAR_Z_INDEX, inventory_manager.gd). The profile popup never set its own
# z_index at all, so it stayed at the Control default of 0 -- well below the hotbar.
#
# This codebase already has an established convention for this exact situation: other modal
# popups parented to ModalLayer (settings panel, recipe book) explicitly set a z_index above
# 176 right after instantiation. The profile popup was simply missing that line.
#
# Fix (Scripts/gameplay_ui_manager.gd, setup_player_menu_ui()): set
# world.player_menu_ui.z_index = 220 right after naming it and before adding it to the
# scene tree -- matches settings_panel_ui's z_index (220), so profile and settings sit at
# the same tier, both above the hotbar (176) and below the recipe book (240, which already
# has a comment noting it intentionally opens on top of the profile).
#
# Files touched:
#   Scripts/gameplay_ui_manager.gd

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

Write-Host "=== git status (before) ===" -ForegroundColor Cyan
git status

Write-Host ""
Write-Host "=== git diff --stat ===" -ForegroundColor Cyan
git diff --stat -- Scripts/gameplay_ui_manager.gd

Write-Host ""
Write-Host "=== Full diff for review ===" -ForegroundColor Cyan
git --no-pager diff -- Scripts/gameplay_ui_manager.gd

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add Scripts/gameplay_ui_manager.gd commit_fix_player_profile_zindex_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(ui): raise player profile popup above the hotbar (z_index)

The profile popup never set its own z_index, so it defaulted to 0 --
below the hotbar's explicit z_index of 176 (HOTBAR_Z_INDEX in
inventory_manager.gd), even though both are under the same UI
CanvasLayer. The hotbar drew on top of the popup's showcase row and
Add Friend button, making them unusable.

Set world.player_menu_ui.z_index = 220 in setup_player_menu_ui(),
matching the existing convention already used by settings_panel_ui
(220) and recipe_book_ui (240) for modal popups that need to sit
above the hotbar.
"@

git commit -m $commitMessage

Write-Host ""
Write-Host "=== git log -1 ===" -ForegroundColor Cyan
git log -1

Write-Host ""
Write-Host "Pushing..." -ForegroundColor Cyan
git push

Write-Host ""
Write-Host "Done. Client repo pushed." -ForegroundColor Green
Write-Host ""
Write-Host "This is a client-only GDScript change -- no server build or deploy needed." -ForegroundColor Yellow
Write-Host "Reload the script in the Godot editor (or re-export/rebuild the client) to test it." -ForegroundColor Yellow
