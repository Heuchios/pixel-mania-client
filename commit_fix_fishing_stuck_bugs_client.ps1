# Commits the fishing fixes on the CLIENT repo (pixel-mania).
#
# Fixes 4 reported fishing bugs, all in Scripts/fishing_manager.gd (client-only,
# no server-side change needed -- confirmed the server's fishing_start/fishing_complete
# handling was already correct):
#
# 1. "Casting with X..." shown but nothing ever happens: the client only enters the
#    actual casting state (fishing_active = true, bobber spawned) once the server's
#    fishing_start ack arrives -- but there was no timeout if that ack was ever lost
#    (a dropped/delayed response, more common on mobile connections). The player was
#    stuck staring at "Casting..." forever with no way to retry. Added an 8-second
#    ack timeout (awaiting_cast_ack / cast_ack_timer) that resets casting and shows
#    "Casting failed. Try again." if the server never responds. Also blocks sending a
#    second fishing_start request while one is already in flight (which the server
#    would otherwise reject as "Finish your current cast first.", compounding the
#    confusion), and this indirectly stops the server-side session from getting stuck
#    open too (see #2/#3 below -- that was the more common way casts got wedged).
#
# 2 & 3. Reeling minigame just sits at 0 forever if the player does nothing (no
#    timeout existed at all -- mg_progress/mg_tension are clamped to >= 0.0, so an
#    idle player never fails OR succeeds): added a 20-second AFK timer
#    (mg_afk_timer / MINIGAME_AFK_TIMEOUT_TIME) inside the minigame. 20 continuous
#    seconds without reeling input now ends the minigame with "The fish swam away
#    while you were away." This also fixes a knock-on server bug: since the client
#    never called fishing_complete when a minigame hung forever, the server's
#    activeFishingSessions entry for that player never got released, so every
#    following cast attempt was silently rejected with "Finish your current cast
#    first." -- which is very likely what bug #1 actually was in most cases.
#
# 4. Occasional cast delay: most likely genuine server round-trip time (each cast
#    commits a Postgres write before acking) rather than a client frame-drop bug --
#    not something to paper over with a client change. The #1 fix at least means a
#    slow response no longer looks indistinguishable from a permanently broken one.
#
# Files touched:
#   Scripts/fishing_manager.gd

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

Write-Host "=== git status (before) ===" -ForegroundColor Cyan
git status

Write-Host ""
Write-Host "=== git diff --stat ===" -ForegroundColor Cyan
git diff --stat -- Scripts/fishing_manager.gd

Write-Host ""
Write-Host "=== Full diff for review ===" -ForegroundColor Cyan
git --no-pager diff -- Scripts/fishing_manager.gd

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add Scripts/fishing_manager.gd commit_fix_fishing_stuck_bugs_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(fishing): add cast-ack timeout and 20s minigame AFK timeout

- Casting could get stuck forever showing "Casting with X..." if the
  server's fishing_start ack was lost -- added an 8s client-side
  timeout that resets casting and lets the player retry.
- The reeling minigame had no timeout at all: an idle player's
  progress/tension just sat clamped at 0, never failing or
  succeeding. Added a 20s AFK timer that ends the minigame ("The fish
  swam away while you were away.") if there is no reeling input.
- The AFK fix also resolves a knock-on server-side bug: a hung
  minigame never sent fishing_complete, so the player's
  activeFishingSessions entry on the server never cleared, silently
  rejecting every subsequent cast with "Finish your current cast
  first." until they reconnected.
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
