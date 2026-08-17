# Follow-up fix to the airborne wall/corner "bounce" bug -- the first fix (dual collision
# recovery passes fighting move_and_slide()) was correct but NOT the whole story. Your
# --pm-collision-trace / --movement-sync-debug logs from testing that fix pointed at a second,
# separate bug in the SAME area of player.gd.
#
# WHAT THE LOGS SHOWED
#   A [PM_COLLISION_TRACE] line with released=true, a pure ceiling normal (0.00, 1.00), and
#   vel_before_slide=(-110.00, -145.03) -> vel_after_release=(-110.00, 24.00). That specific
#   event was a genuine ceiling hit and was classified correctly even with the first fix.
#   But it exposed the real remaining cause: release_airborne_block_corner_contact() had a
#   SECOND, much broader trigger condition sitting right below the (correctly tightened)
#   per-normal ceiling classification:
#
#       if not should_release_overhead_contact and not (was_moving_up and has_any_slide_collision and absf(velocity.y) <= 0.01):
#           return false
#
#   has_any_slide_collision was TRUE for ANY collision at all that frame -- including a pure
#   side-wall touch with normal (1, 0), whose normal.y is 0 and is nowhere near a ceiling.
#   Jumping alongside a wall naturally carries vertical velocity through ~0 at the jump's
#   apex. Being wall-adjacent at that exact moment was enough to satisfy this fallback and
#   fire the FULL ceiling-release response on a contact that was never a ceiling hit:
#     - velocity.y forced up to a synthetic minimum (24-36 px/s) instead of the near-zero
#       value move_and_slide() had already produced -- an instantaneous velocity injection,
#       not a result of gravity or collision resolution.
#     - the player's position snapped down 1px instantly (CEILING_UNSTICK_NUDGE).
#     - variable_jump_active and coyote_timer were cleared, cancelling jump state.
#     - horizontal velocity could be restored to its pre-collision value even though the
#       wall had legitimately slowed it.
#   This is exactly the bounce/jerk reported when jumping beside a wall, holding into a wall
#   while airborne, or grazing a corner -- and it fired independently of the first fix,
#   because it doesn't go through the per-normal ceiling-vs-corner classification at all.
#
# THE FIX (player.gd, release_airborne_block_corner_contact)
#   The loop now also tracks has_any_downward_facing_normal -- true only when a collision's
#   normal.y is actually positive (however slightly), never for a purely horizontal wall
#   normal. The fallback condition now requires this instead of "any collision at all," so a
#   side-wall touch can never trigger the ceiling-release response, while a genuinely
#   ambiguous near-ceiling contact still can. Nothing about movement speed, jump height,
#   gravity, or genuine ceiling-bonk behavior changed.
#
# Parse-checked with a real Godot headless binary (4.4-stable, --check-only) before delivery --
# clean after filtering the standard sandbox-only "preload not found" / "MovementMode not
# declared" noise documented in the gdscript_parse_checking project note.
#
# Files touched:
#   Scripts/player.gd   (the fix)

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
fix(movement): stop wall touches at jump apex from firing the ceiling-release hack

release_airborne_block_corner_contact() had a fallback trigger that
fired the full ceiling-release response (forced minimum fall velocity,
1px downward position snap, jump-state cancellation) whenever the
player was moving up, had ANY slide collision that frame, and current
velocity.y was near zero -- regardless of whether that collision's
normal had any vertical component at all.

Jumping alongside a wall naturally carries vertical velocity through
~0 at the jump's apex. Being wall-adjacent at that moment satisfied
the fallback on a pure side-wall normal (normal.y ~= 0), injecting a
synthetic downward velocity and position snap into what should have
been an ordinary wall slide -- independent of, and not fixed by, the
earlier tightened per-normal ceiling classification.

The loop now also tracks whether any collision normal actually has a
positive (downward-facing) y component, and the fallback requires
that instead of "any collision at all." A horizontal wall normal can
no longer satisfy it. Movement speed, jump height, gravity, and
genuine ceiling-bonk behavior are unchanged.
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
Write-Host "  1. Jump beside a wall and hold into it through the whole arc, including the apex." -ForegroundColor Yellow
Write-Host "  2. Repeated jump against the same wall -- should feel identical every time." -ForegroundColor Yellow
Write-Host "  3. Jump toward a block corner -- still no snag, no bounce-back." -ForegroundColor Yellow
Write-Host "  4. Watch for released=true lines in the log -- they should now only show a" -ForegroundColor Yellow
Write-Host "     genuinely vertical normal (normal_y clearly dominant), never a side-wall normal." -ForegroundColor Yellow
