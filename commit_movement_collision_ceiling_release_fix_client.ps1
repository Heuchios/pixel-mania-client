# Three more fixes to the airborne wall/corner "bounce" bug, on top of the SOLID_COLLISION_RECOVERY_MIN_CORRECTION /
# ceiling-normal-dominance fix from before. All found from your diagnostic logs and two in-game
# repros (bounced back off the corner of a bedrock block at 50,46; then "still happening, corner
# of blocks" with a fresh trace log while flying/gliding along a multi-tile ceiling). None of them
# touch movement speed, jump height, or gravity.
#
# FIX A -- ceiling-release fallback firing on plain wall touches at the jump's apex
#   Your --pm-collision-trace log showed a released=true event with a pure ceiling normal
#   (0.00, 1.00) -- correctly classified even under the earlier fix. Reading the function in full
#   exposed a SECOND, much broader trigger sitting right below the per-normal classification:
#
#       if not should_release_overhead_contact and not (was_moving_up and has_any_slide_collision and absf(velocity.y) <= 0.01):
#           return false
#
#   has_any_slide_collision was TRUE for ANY collision that frame -- including a pure side-wall
#   touch with normal (1, 0), whose normal.y is 0 and is nowhere near a ceiling. Jumping alongside
#   a wall naturally carries vertical velocity through ~0 at the jump's apex; being wall-adjacent
#   at that exact moment was enough to satisfy this fallback and fire the FULL ceiling-release
#   response (forced minimum fall velocity, 1px downward position snap, jump-state cancellation)
#   on a contact that was never a ceiling hit. This fired independently of the earlier fix because
#   it bypasses the per-normal ceiling-vs-corner classification loop entirely.
#
#   Fix: the loop now also tracks has_any_downward_facing_normal -- true only when a collision's
#   normal.y is actually positive, never for a purely horizontal wall normal. The fallback now
#   requires that instead of "any collision at all."
#
# FIX B -- the corner AABB-recovery pass bouncing you off a corner while holding into it
#   Your screenshot: jumping up alongside a single-block-wide wall, holding into it, you get
#   bounced back at the corner of a protruding block (bedrock at grid 50,46 in your example --
#   confirmed bedrock has no special collision shape, it's an ordinary full-tile block, so this
#   is a general corner bug, not something specific to that block type).
#
#   get_recovery_push_for_block() (called every frame from the manual AABB recovery pass) had an
#   ambiguous fallback: when the player's rect wasn't cleanly outside the block on any single side
#   even in the PREVIOUS frame -- i.e. sustained, multi-frame contact, exactly what climbing
#   alongside a wall past a protruding corner looks like -- it guessed a push axis by comparing
#   overlap.size.x vs overlap.size.y and teleported the player out that way. move_and_slide()
#   already resolves this kind of continuous corner contact correctly on its own every frame; the
#   guess-and-eject fallback fought the player's own held input, since pressing back into the same
#   corner immediately re-created the same overlap next frame -- a repeating push/press-back-in
#   cycle, which is exactly "bounced back from the corner."
#
#   Fix: that ambiguous fallback now returns no correction at all and leaves it to
#   move_and_slide(). The four UNAMBIGUOUS cases (player was cleanly above/below/left/right of the
#   block in the previous frame and is now embedded from that one clear direction -- a genuine
#   "just got wedged into solid geometry" event) still get an active recovery push, unchanged.
#
# FIX C -- the ceiling head-bonk re-firing on every tile while sliding/flying along a ceiling
#   You retested and reported "still happening, corner of blocks," with a fresh trace log. Every
#   released=true event in it had a genuinely pure ceiling normal (0.00, 1.00) -- fix A's target
#   case wasn't happening again, so this was a different problem. The log showed FOUR separate
#   release events in quick succession (ids 22-25) as you moved sideways under a run of
#   ForegroundCollisionTileMapLayer tiles, each with a different vel_before_slide (-307, -350,
#   -465 px/s -- consistent with continuously holding upward thrust into the ceiling, e.g. a wing
#   item), each producing its OWN full forced-velocity + 1px position snap + jump-state-cancel
#   response as contact broke and re-established tile by tile. Each individual release was
#   legitimate on its own; firing the full response on every single one of them, several times a
#   second, while you kept pressing up into the ceiling, is what reads as "bouncing off the corner
#   of blocks" while sliding/flying along it.
#
#   Fix: a short (0.12s) refire cooldown specifically on release_airborne_block_corner_contact()'s
#   forced-response side effects. move_and_slide() still blocks upward motion into the ceiling on
#   every single frame regardless of this cooldown -- you can never fly/jump through a ceiling --
#   this only limits how often the EXTRA unstick response (velocity floor, position snap, jump
#   cancel) is allowed to re-apply. One clean bonk instead of a rapid string of them.
#
# Parse-checked with a real Godot headless binary (4.4-stable, --check-only) before delivery --
# clean after filtering the standard sandbox-only "preload not found" / "MovementMode not
# declared" noise documented in the gdscript_parse_checking project note.
#
# Files touched:
#   Scripts/player.gd   (all three fixes)

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/player.gd"
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

git add -- $files commit_movement_collision_ceiling_release_fix_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(movement): stop wall-apex misfires, corner bounce-back, and ceiling rapid-refire

Three more airborne collision bugs found from diagnostic logging and
two in-game repros (bounced off a bedrock corner while holding into a
wall; then repeated bounce along a multi-tile ceiling while flying).

release_airborne_block_corner_contact() had a fallback trigger that
fired the full ceiling-release response (forced minimum fall velocity,
1px downward position snap, jump-state cancellation) whenever the
player was moving up, had ANY slide collision that frame, and current
velocity.y was near zero -- regardless of whether that collision's
normal had any vertical component. Jumping alongside a wall naturally
carries vertical velocity through ~0 at the jump's apex, so being
wall-adjacent at that moment satisfied the fallback on a pure
side-wall normal. The loop now also tracks whether any collision
normal has a positive (downward-facing) y component, and the fallback
requires that instead of "any collision at all."

get_recovery_push_for_block()'s ambiguous branch -- used when the
player's rect wasn't cleanly outside a block on any side even in the
previous frame, i.e. sustained multi-frame contact such as climbing
alongside a wall past a protruding corner -- guessed a push axis by
comparing overlap size and teleported the player out that way every
frame the ambiguous overlap persisted, fighting held input into the
corner and reading as being bounced back off it. That branch now
returns no correction and leaves it to move_and_slide(); the four
unambiguous "just got embedded from one clear direction" cases are
unchanged.

release_airborne_block_corner_contact() could also re-fire its full
forced-response on every individual tile while the player continuously
held upward thrust into a multi-tile ceiling, since contact legitimately
breaks and re-establishes tile by tile. Each firing was individually
correct but several in a row read as bouncing along the ceiling. A new
0.12s refire cooldown limits how often the forced velocity/position-
snap/jump-cancel response re-applies; move_and_slide() still blocks
upward motion into the ceiling every frame regardless, so this cannot
let the player pass through a ceiling.

Movement speed, jump height, gravity, and genuine ceiling-bonk
behavior are unchanged.
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
Write-Host "TEST with --pm-collision-trace --movement-sync-debug again, focusing on:" -ForegroundColor Yellow
Write-Host "  1. Jump up alongside that same wall by the world_lock door, holding into it," -ForegroundColor Yellow
Write-Host "     past the bedrock block corner at 50,46 -- should slide cleanly, no bounce-back." -ForegroundColor Yellow
Write-Host "  2. Fly/glide sideways along the underside of a multi-tile ceiling while holding up --" -ForegroundColor Yellow
Write-Host "     should feel like one clean bonk then a smooth slide, not a series of pops." -ForegroundColor Yellow
Write-Host "  3. Jump beside a wall and hold into it through the whole arc, including the apex." -ForegroundColor Yellow
Write-Host "  4. Repeated jump against the same wall -- should feel identical every time." -ForegroundColor Yellow
Write-Host "  5. Watch for released=true lines -- normal_y should always dominate normal_x, and" -ForegroundColor Yellow
Write-Host "     they should now be spaced out (at least ~0.12s apart) instead of back-to-back." -ForegroundColor Yellow
