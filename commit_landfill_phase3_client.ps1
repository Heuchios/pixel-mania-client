#!/usr/bin/env pwsh
# Commits the Landfill seasonal event's client-side UI (Phase 3): the lobby "Join Race" +
# "Leaderboard" buttons, the event-status poll that gates the Join button's visibility, and a
# new code-built leaderboard/claim panel.
#
# IMPORTANT -- READ BEFORE RUNNING:
# This script was authored in a cloud sandbox with NO Godot editor available, so unlike the
# server-side commit scripts in this project, it could NOT run any real syntax/parse check on
# the GDScript below (there is no tsc-equivalent for GDScript in this codebase). Every edit was
# manually cross-referenced line-by-line against this project's real, already-shipped
# NetworkManager/PixelUIStyle APIs (exact function signatures, exact signal names, exact
# constant names) and checked for balanced parens/brackets and consistent tab indentation, but
# that is not a substitute for the editor's own parser.
#
# BEFORE running this script: open the project in the Godot editor and let it re-import /
# re-parse Scripts/network_manager.gd, Scripts/lobby_menu.gd, and the new
# Scripts/landfill_ui.gd. Check the Godot "Errors" panel (bottom dock) for any red parse
# errors. landfill_ui.gd is a brand-new script file, so Godot will auto-generate a matching
# landfill_ui.gd.uid the first time it's opened/parsed -- that's expected and should be staged
# alongside it (this script tries to add it if present, but does not fail if it isn't yet).
#
# What this ships:
#
# Scripts/network_manager.gd:
# - 4 new signals: landfill_status_received(data), landfill_join_result_received(data),
#   landfill_leaderboard_received(data), landfill_claim_result_received(data) -- added next to
#   the existing owned_locked_worlds_received/iap_* signal declarations.
# - 3 new rate-limit constants (MAX_LANDFILL_STATUS_RATE_PER_SECOND = 4,
#   MAX_LANDFILL_LEADERBOARD_RATE_PER_SECOND = 4, MAX_LANDFILL_ACTION_RATE_PER_SECOND = 2 --
#   used for both join and claim, since both are low-frequency/sensitive actions), following the
#   exact naming and _can_send_rate_limited(counter_key, max_per_second) convention already used
#   by every other request_* method in this file.
# - 4 new request methods -- request_landfill_status(), request_landfill_join(request_id),
#   request_landfill_leaderboard(request_id), request_landfill_claim_prize(request_id) -- each
#   byte-for-byte mirroring request_owned_locked_worlds()'s shape (auth check -> rate-limit
#   check -> request_id sanitize/generate via make_auth_request_id() -> attach_session_auth()
#   send). These send the server's real, already-shipped Phase 1 route names exactly:
#   landfill_status_request / landfill_join_request / landfill_leaderboard_request /
#   landfill_claim_prize_request (confirmed against server_phase7_dispatcher.ts's allow-list and
#   server.ts's route table).
# - 4 new dispatch cases in the big `match message_type:` block, next to the existing
#   "owned_locked_worlds_result" case, for the server's real reply types: landfill_status,
#   landfill_join_result, landfill_leaderboard, landfill_claim_result -- each calling a new
#   handle_landfill_*_result(data) function.
# - 4 new handler functions (mirroring handle_owned_locked_worlds_result's field-sanitization
#   style exactly -- _safe_string/_safe_int/_safe_bool/_safe_world_name on every field) that
#   sanitize the server's reply payload and emit the corresponding signal. Field shapes were
#   confirmed directly against server_landfill_event.ts's actual sendJson() calls, not guessed.
#
# Scripts/lobby_menu.gd:
# - 2 new state vars for the Join Race button's event-gated visibility and in-flight request
#   tracking, plus a landfill_ui_panel reference for the new leaderboard panel.
# - _add_right_buttons() gains 2 more icon buttons (Join Race "flag", Leaderboard "trophy"),
#   appended to the existing icon row without touching the 4 existing buttons or their indices.
# - _wire_right_side_buttons() gains i==4 (Join Race -- hidden until the status poll confirms
#   the event window is open) / i==5 (Leaderboard -- always visible, so players can still check
#   standings and claim prizes after the join window closes, matching the confirmed spec that
#   unclaimed prizes are only forfeited at season rollover, not when the join window closes).
# - New _connect_landfill_feed() / _start_landfill_status_timer() (15s poll, mirroring
#   _start_world_population_timer()'s exact Timer.new() pattern) / _request_landfill_status_refresh()
#   / _on_landfill_status_received() -- toggles the Join Race button's visibility from the
#   server's real event_active flag, never a client-side guess about the calendar.
# - New _on_landfill_join_pressed() / _on_landfill_join_result_received() -- on success, hands
#   the server-returned world_name straight to the existing, already-proven _join_world_name()
#   (the one confirmed-correct way to actually enter a world from the lobby); on failure, shows
#   a plain-language reason in the existing status_label.
# - New _on_landfill_leaderboard_pressed() / _get_or_create_landfill_ui_panel() -- lazily
#   instantiates the new landfill_ui.gd panel once and reuses it on subsequent opens.
#
# Scripts/landfill_ui.gd (NEW FILE):
# - A fully code-built (no .tscn) leaderboard + claim panel, structurally mirroring
#   friends_ui.gd's proven overlay/panel/shadow/back/header/rows construction pattern almost
#   line-for-line (same PixelUIStyle calls, same row-building helpers).
# - Deliberately does NOT use friends_ui.gd's handle_friend_message(data) in-world delegation
#   pattern, since that pattern is fed by a world node and silently no-ops outside an active
#   world -- this panel is opened from the lobby, before any world exists. Instead it connects
#   directly to NetworkManager's landfill_leaderboard_received / landfill_claim_result_received
#   signals itself and calls request_landfill_leaderboard()/request_landfill_claim_prize()
#   itself, fully self-contained.
# - Shows season key, the local player's rank + kilograms, a scrollable top-10 rows list
#   (rank/username/kilograms, current player's row highlighted gold), a REFRESH button, and a
#   CLAIM PRIZE button gated client-side on rank 1-10 (the server is still the sole source of
#   truth -- claim_prize_request re-validates rank, inventory space, and already-claimed status
#   server-side exactly as it already did in Phase 1; this is purely a UX convenience so players
#   don't get an avoidable rejection for an obviously-ineligible rank).
#
# Server-side: NOTHING in this commit touches any server file. This is a pure client addition
# against the server's already-shipped, unmodified Phase 1 routes
# (landfill_status_request/landfill_join_request/landfill_leaderboard_request/
# landfill_claim_prize_request) and Phase 2/2.5 join+movement enforcement. No new env flags, so
# there is nothing to add to ecosystem.config.js for this commit.
#
# Still NOT done after this commit (see landfill_seasonal_event_design.md): trash block content
# (no trash block types are registered yet, so there is nothing to actually break for
# Kilograms), the prize catalog (getPrizeForRank returns empty until prizes are registered --
# claim requests will correctly fail with "prize_not_configured" until then), and the
# server_phase11c_trusted_movement.ts entry-pen gap (that module is confirmed inactive in
# production per movement_pipeline.md, so this is low-risk, but flagged again for visibility).

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

function Fail($msg) {
    Write-Host $msg -ForegroundColor Red
    exit 1
}

Write-Host "== git status before staging ==" -ForegroundColor Cyan
git status --short

Write-Host "`n== REMINDER: this script does NOT verify GDScript syntax. ==" -ForegroundColor Yellow
Write-Host "Open the project in the Godot editor FIRST and check the Errors panel for" -ForegroundColor Yellow
Write-Host "Scripts/network_manager.gd, Scripts/lobby_menu.gd, and Scripts/landfill_ui.gd" -ForegroundColor Yellow
Write-Host "before trusting this commit. Press Ctrl+C now to abort if you have not done that yet." -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

$files = @(
    "Scripts/network_manager.gd",
    "Scripts/lobby_menu.gd",
    "Scripts/landfill_ui.gd"
)

# landfill_ui.gd.uid is auto-generated by the Godot editor the first time it opens/parses the
# new script file. Stage it too if it exists by the time this runs; do not fail if it doesn't
# (e.g. if this is run before ever opening the project in the editor).
if (Test-Path "Scripts/landfill_ui.gd.uid") {
    $files += "Scripts/landfill_ui.gd.uid"
}

Write-Host "`n== staging landfill client UI files ==" -ForegroundColor Cyan
git add -- $files

Write-Host "`n== staged diff stat ==" -ForegroundColor Cyan
git diff --cached --stat

$commitMessage = @"
Add Landfill seasonal event client UI (lobby Join Race + Leaderboard panel)

Client-only commit -- wires the lobby up to the server's already-shipped, unmodified Phase 1
Landfill routes (landfill_status_request/landfill_join_request/landfill_leaderboard_request/
landfill_claim_prize_request) and Phase 2/2.5 join+movement enforcement. No server files
touched, no new env flags.

Scripts/network_manager.gd:
- 4 new signals (landfill_status_received, landfill_join_result_received,
  landfill_leaderboard_received, landfill_claim_result_received).
- 4 new request_landfill_*() methods, mirroring request_owned_locked_worlds()'s exact shape
  (auth check -> rate limit -> request_id sanitize/generate -> attach_session_auth send), with
  3 new rate-limit constants following this file's existing MAX_*_RATE_PER_SECOND convention.
- 4 new dispatch cases + handler functions in the message-type match block, sanitizing every
  field via the existing _safe_string/_safe_int/_safe_bool/_safe_world_name helpers exactly like
  handle_owned_locked_worlds_result does, with field shapes confirmed against
  server_landfill_event.ts's real sendJson() payloads.

Scripts/lobby_menu.gd:
- 2 new right-side icon buttons: Join Race (hidden until the server's status poll confirms the
  event window is open) and Leaderboard (always visible, so standings/claims stay reachable
  after the join window closes, matching the spec that prizes are only forfeited at season
  rollover).
- New 15s status-poll timer (mirroring _start_world_population_timer()'s Timer.new() pattern),
  join-button press/result handlers (a successful join hands the server's returned world_name to
  the existing, already-proven _join_world_name() -- the confirmed-correct lobby join path), and
  a lazy landfill_ui.gd panel opener for the Leaderboard button.

Scripts/landfill_ui.gd (NEW): a fully code-built (no .tscn) leaderboard + claim panel,
structurally mirroring friends_ui.gd's overlay/panel/header/rows construction pattern. Unlike
friends_ui.gd, connects directly to NetworkManager's landfill_leaderboard_received/
landfill_claim_result_received signals and issues its own requests, rather than relying on
friends_ui.gd's in-world message-delegation pattern -- this panel must work from the lobby,
before any world node exists. Client-side rank 1-10 gating on the CLAIM PRIZE button is a UX
convenience only; the server re-validates rank/inventory-space/already-claimed on every claim
exactly as it already did in Phase 1.

Verified in-sandbox: every new signal name, request method shape, rate-limit-constant
convention, dispatch/handler pattern, and PixelUIStyle call was cross-referenced line-by-line
against this file's own already-shipped code and against server_landfill_event.ts's actual
response payloads (not guessed). Parens/brackets balance-checked and indentation
(tabs-only) checked programmatically. NO Godot editor was available in the cloud sandbox this
was authored in, so this could NOT be parsed/compiled/run there -- open the project in the
Godot editor and check the Errors panel before relying on this commit.

Still NOT done (see landfill_seasonal_event_design.md): trash block content (no trash block
types registered yet), the prize catalog (claims will correctly fail with
"prize_not_configured" until prizes are registered), and the server_phase11c_trusted_movement.ts
entry-pen gap (that pipeline is confirmed inactive in production).
"@

Write-Host "`n== creating commit ==" -ForegroundColor Cyan
git commit -m $commitMessage

Write-Host "`n== git log (last commit) ==" -ForegroundColor Cyan
git log -1 --stat

Write-Host "`nDone. This commit was NOT pushed." -ForegroundColor Yellow
Write-Host "Reminder: open the project in the Godot editor and playtest the lobby before pushing -- this was never run through the editor." -ForegroundColor Yellow
Write-Host "Reminder: LANDFILL_EVENT_ENABLED is still 'false' by default server-side, and no trash blocks/prizes are registered yet." -ForegroundColor Yellow
