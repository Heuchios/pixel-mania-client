# Commits the leaderboard GUI wiring + new `leaderboard` block on the CLIENT repo.
#
# WHAT THIS ADDS
#   1. A new walk-through interactable block, `leaderboard`, sprite at image.png atlas cell
#      (21, 15). Interacting with it opens the LeaderboardScene GUI.
#   2. Scripts/ui/leaderboard_controller.gd -- a shared controller that instances
#      Scenes/ui/leaderboard/LeaderboardScene.tscn, talks to NetworkManager directly, and owns
#      the leaderboard-refresh + prize-claim lifecycle. ONE controller serves BOTH the in-world
#      block and the lobby trophy button (the lobby has no world node, so the usual in-world
#      delegation pattern would silently no-op there -- landfill_ui.gd documents the same
#      reasoning).
#   3. The lobby's old "Ἴ6 LEADERBOARD" button is REMOVED. The block is the only entry
#      point now. Everything that button was the sole caller of went dead with it and was
#      removed too: _get_or_create_leaderboard_controller(), _get_or_create_landfill_ui_panel(),
#      their vars, and the LandfillUI / LeaderboardController preloads. The "Go Green!" join
#      button is untouched. Scripts/landfill_ui.gd stays on disk -- lobby_menu.gd has its own
#      copies of those helpers and still references it.
#
# ACCESS: the leaderboard is deliberately PUBLIC. world_lock_manager.gd short-circuits it in
# BOTH can_current_player_interact_with_block() and can_current_player_interact_with_block_at().
# The second one matters: the ..._at() variant reuses the BUILD predicate for area locks, so
# without that short-circuit a leaderboard placed inside someone's area lock would be unusable
# to exactly the visitors it exists for.
#
# TABS: the server only serves Landfill data (landfill_leaderboard_request -> entries /
# your_rank / your_kilograms). WEEKLY and GLOBAL stay visible but render a coming-soon state
# rather than an empty table. To make one live later, add its request fn and flip "live" in
# TAB_DEFINITIONS in leaderboard_controller.gd.
#
# KNOWN GAP: the "EVENT ENDS IN" stat shows "--". Neither landfill_leaderboard nor
# landfill_status returns an event end timestamp, so there is nothing honest to count down to.
# Add an ends_at field server-side and the controller can render a real countdown.
#
# COLLISION PARITY: item_database.gd's `leaderboard` sets no_collision/collidable/solid/
# collision_type, and src/server_item_database.ts must match. The server defaults
# collision_type to "full", so a server entry omitting these is SOLID while the client walks
# through -- which does not read as a collision bug in game, it hard-snaps the player every
# frame and reads as being physically trapped. See the block_collision_model project note.
# The matching server change ships in the SERVER repo commit script.
#
# Files touched:
#   Scripts/ui/leaderboard_controller.gd   (new)
#   Scripts/item_database.gd               (leaderboard block definition)
#   Scripts/interaction_manager.gd         (predicate, dispatch, interactable, open-guard)
#   Scripts/world_lock_manager.gd          (public-access bypass, both gates)
#   Scripts/world.gd                       (facade: var, predicate, setup/open/close/is_open)
#   Scripts/gameplay_ui_manager.gd         (UI lifecycle)
#   Scripts/input_manager.gd               (ESC close + input swallow)
#   Scripts/reach_indicator_manager.gd     (cursor/reach highlight)
#   Scripts/ui/lobby_scene.gd              (trophy button + dead code removed)
#
# Every .gd file above was parse-checked with a real Godot headless binary before delivery.
# No project.godot change, so a plain script reload is enough.

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/ui/leaderboard_controller.gd",
    "Scripts/item_database.gd",
    "Scripts/interaction_manager.gd",
    "Scripts/world_lock_manager.gd",
    "Scripts/world.gd",
    "Scripts/gameplay_ui_manager.gd",
    "Scripts/input_manager.gd",
    "Scripts/reach_indicator_manager.gd",
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
Write-Host "=== New file: leaderboard_controller.gd ===" -ForegroundColor Cyan
Get-Content "Scripts/ui/leaderboard_controller.gd"

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add -- $files commit_leaderboard_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
feat(leaderboard): wire LeaderboardScene to a new interactable block

Adds a walk-through `leaderboard` block (image.png atlas cell 21,15)
that opens the LeaderboardScene GUI, plus the controller that drives
it.

Scripts/ui/leaderboard_controller.gd instances the scene, connects to
NetworkManager's landfill_leaderboard_received /
landfill_claim_result_received directly, and owns the refresh and
prize-claim lifecycle. One controller serves both the in-world block
and the lobby trophy button -- the lobby has no world node, so the
usual in-world delegation pattern would silently no-op there.

The lobby's old trophy button is removed -- the block is the only way
in. Everything it was the sole caller of went with it (the controller
and landfill-panel factories, their vars, both preloads). The "Go
Green!" join button is untouched, and landfill_ui.gd stays on disk
since lobby_menu.gd still references it.

The block is deliberately public: world_lock_manager short-circuits it
in both can_current_player_interact_with_block and the ..._at variant.
The second matters because the _at path reuses the BUILD predicate for
area locks, which would otherwise lock out exactly the visitors this
block exists for.

Weekly and Global tabs render a coming-soon state -- the server only
serves Landfill data today. The EVENT ENDS IN stat shows "--" because
no landfill payload carries an end timestamp.

Collision flags (no_collision/collidable/solid/collision_type) must
stay in sync with src/server_item_database.ts or the player is
hard-snapped every frame; the matching server entry ships alongside.
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
Write-Host "IMPORTANT: the SERVER also needs its matching block definition before you place" -ForegroundColor Yellow
Write-Host "this block in a live world -- run commit_leaderboard_server.ps1 in PixelManiaServer" -ForegroundColor Yellow
Write-Host "and deploy, or the server treats the block as SOLID and players get hard-snapped." -ForegroundColor Yellow
Write-Host ""
Write-Host "TEST: place the leaderboard block in a world, walk THROUGH it (it must not block" -ForegroundColor Yellow
Write-Host "you), then interact with it. Your GUI should open with live Landfill rows, your" -ForegroundColor Yellow
Write-Host "rank/points filled in, and Weekly/Global showing coming-soon. ESC should close it." -ForegroundColor Yellow
Write-Host "Also confirm the lobby no longer shows a LEADERBOARD button, and that Go Green! still works." -ForegroundColor Yellow
