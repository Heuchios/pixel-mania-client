# Commits the failed-world-join -> lobby recovery fix on the CLIENT repo (pixel-mania).
#
# BUG: when a world join failed for any reason, the client did not return to the Lobby --
# it showed a grey/blank screen with no way out.
#
# ROOT CAUSE (exact): joining does change_scene_to_packed() from LobbyScene into
# res://Scenes/main.tscn, and the client only learns the join failed AFTER that scene change.
# Both failure handlers in save_manager.gd ended with:
#
#     if world.world_menu_ui != null and world.world_menu_ui.has_method("return_to_lobby_menu"):
#         world.world_menu_ui.call_deferred("return_to_lobby_menu", false)
#     elif world.world_menu_ui != null and world.world_menu_ui.has_method("open_main_menu"):
#         world.world_menu_ui.call_deferred("open_main_menu")
#
# with NO else branch. world.world_menu_ui is null for the entire duration of a join that
# never succeeds: world.gd's _ready() never calls setup_world_menu_ui(), and the only thing
# that builds it lazily is start_optional_world_ui_warmup(), whose sole caller is
# save_manager._finish_world_entry_noncritical_work() -- which only runs AFTER a world entry
# has already succeeded. So on a failed join both branches were silently skipped and nothing
# navigated anywhere, while the lines immediately above had already run:
#     world.in_world = false
#     set_gameplay_world_active(false)   # hides player, every block, background block, drop
#     set_gameplay_ui_visible(false)     # hides every ui_layer child
#     cancel_smooth_world_load()         # hides the loading overlay
# main.tscn has no ColorRect or authored background and its TileMapLayers were still empty
# because world data never arrived, so the viewport fell through to the project's default
# clear colour -- the grey screen -- with the player permanently stranded there.
#
# THE FIX: one authoritative, idempotent recovery function,
# save_manager.return_to_lobby_after_failed_world_entry(reason), which:
#   1. Guards re-entrancy (several failure sources can fire for one bad join).
#   2. Clears the pending-join intent, in memory AND on disk, BEFORE building any UI.
#      This is load-bearing: world_menu_ui.setup() ends with
#      call_deferred("_try_auto_enter_pending_lobby_world"), which would otherwise
#      immediately re-join the world that just failed -- an endless join/fail loop.
#      It also stops NetworkManager.handle_account_auth_ok() silently re-sending the failed
#      join after a later reconnect.
#   3. Builds world_menu_ui on demand (the same lazy pattern world.gd's
#      return_to_lobby_from_landfill_race() already uses) so the NORMAL, re-entrancy-guarded
#      return_to_lobby_menu() path runs -- one exit path, not a second half-complete one.
#   4. Verifies the scene change actually took effect, and forces a direct
#      change_scene_to_file() if it did not. return_to_lobby_menu() discards its own
#      change_scene_to_file error while latching its guard, so a failed scene load would
#      otherwise re-create the original permanent-stuck state.
#   5. Falls back to a direct scene change if world_menu_ui cannot be built at all.
#
# Both failure handlers now route through it, as does world_loading_ui_manager's last-resort
# cleanup path (which previously also navigated nowhere).
#
# ALSO FIXED, found while tracing:
#   - handle_server_world_entry_rejected() never released the entry server-side. It now calls
#     notify_network_leave_world() before clearing in_world, matching what
#     handle_client_world_loading_failed() already did. Without it, a rejected door transition
#     left the server holding presence in the old world and kept this connection's provisional
#     entry open, so every later join_world failed with "A world is already loading."
#   - The failure reason is now handed to the lobby via the profile config and shown there
#     (lobby_scene._show_pending_world_join_failure_message). The old
#     world.show_notification() call rendered into ui_layer children that had just been hidden
#     and were freed in the same frame, so the player got zero rendered frames of it -- the
#     failure looked like an unexplained bounce. Order is now: cleanup -> lobby restored ->
#     reason shown.
#
# DELIBERATELY NOT CHANGED (documented in-code so it is not "fixed" later by mistake):
#   - handle_server_world_entry_rejected() is still gated on waiting_for_server_world_state.
#     Relaxing it so the lobby auto-join path exits faster was tried and reverted: that
#     function's reason handling is a DENYLIST, so making it first responder turns
#     self-healing rejections (world_route_redirect / world_route_unavailable / rate_limited)
#     into hard ejections -- the regression world_loading_ui_manager.gd's
#     TERMINAL_JOIN_WORLD_REJECTION_REASONS comment records as having "broke joining EVERY
#     world". world_loading_ui_manager owns retryability there via an ALLOWLIST and keeps it.
#   - Transient-disconnect handling in network_manager.gd. It intentionally preserves join
#     state across a drop so a reconnect can resume; the loading-UI retry ladder is the
#     backstop and now terminates in a real lobby return.
#
# Files touched:
#   Scripts/save_manager.gd
#   Scripts/world_loading_ui_manager.gd
#   Scripts/ui/lobby_scene.gd
#
# Client-only GDScript. No server build or deploy. project.godot is untouched, so a plain
# script reload is enough -- no need to close and reopen the project.

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/save_manager.gd",
    "Scripts/world_loading_ui_manager.gd",
    "Scripts/ui/lobby_scene.gd"
)

Write-Host "=== git status (before) ===" -ForegroundColor Cyan
git status

Write-Host ""
Write-Host "=== git diff --stat ===" -ForegroundColor Cyan
git diff --stat -- $files

Write-Host ""
Write-Host "=== Full diff for review ===" -ForegroundColor Cyan
git --no-pager diff -- $files

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add -- $files commit_fix_failed_world_join_recovery_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(world-join): always return to the lobby when a world join fails

A failed world join left the client on a grey screen with no way back.

Joining does change_scene_to_packed() from LobbyScene into main.tscn, and
the client only learns the join failed after that scene change. Both
failure handlers in save_manager.gd ended with a bare
"if world.world_menu_ui != null: ...return_to_lobby_menu..." with no else
branch -- but world_menu_ui is null for the whole duration of a join that
never succeeds. world.gd's _ready() never calls setup_world_menu_ui(),
and the only lazy builder is start_optional_world_ui_warmup(), whose sole
caller runs after a world entry has already completed. So nothing
navigated, while the lines just above had already cleared in_world and
hidden the player, every block and drop, every ui_layer child and the
loading overlay. main.tscn has no background and its tilemaps were still
empty, so the viewport fell through to the default clear colour.

Added save_manager.return_to_lobby_after_failed_world_entry(reason): a
single idempotent recovery that clears the pending-join intent (in memory
and on disk) before building world_menu_ui on demand, routes through the
existing re-entrancy-guarded return_to_lobby_menu(), verifies the scene
change took effect, and falls back to a direct change_scene_to_file.
Clearing the pending join first is required: world_menu_ui.setup() defers
_try_auto_enter_pending_lobby_world(), which would otherwise re-join the
world that just failed, forever. Both failure handlers and
world_loading_ui_manager's last-resort cleanup now route through it.

Also: handle_server_world_entry_rejected() now sends leave_world before
clearing in_world, so a rejected entry no longer leaves the server
holding presence and failing every later join with "A world is already
loading"; and the failure reason is handed to the lobby via the profile
config and shown there, instead of a notification rendered into UI that
was hidden and freed in the same frame.

handle_server_world_entry_rejected()'s waiting_for_server_world_state
guard is intentionally left as-is -- relaxing it makes that denylist the
first responder for join rejections and turns self-healing reasons like
world_route_redirect into hard ejections.
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
Write-Host "Client-only GDScript change -- no server build or deploy needed." -ForegroundColor Yellow
Write-Host "project.godot was NOT changed, so a plain script reload is enough." -ForegroundColor Yellow
Write-Host ""
Write-Host "TEST: join a world that cannot be joined (a nonexistent/locked world, or kill the" -ForegroundColor Yellow
Write-Host "server mid-join). You should land back on the Lobby with the reason in the status" -ForegroundColor Yellow
Write-Host "label above the world input -- never a grey screen. Then join a REAL world to confirm" -ForegroundColor Yellow
Write-Host "success still works, and repeat fail/fail/succeed to confirm no state is left over." -ForegroundColor Yellow
Write-Host "Watch the Output panel for any [WorldEntryRecovery] warnings -- they indicate a" -ForegroundColor Yellow
Write-Host "fallback path was needed and are worth reporting back." -ForegroundColor Yellow
