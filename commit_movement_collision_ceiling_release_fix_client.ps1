# Four more fixes to the airborne wall/corner/ceiling "bounce" bug, on top of the
# SOLID_COLLISION_RECOVERY_MIN_CORRECTION / ceiling-normal-dominance fix from before. All found
# from your diagnostic logs and repeated in-game repros. None touch movement speed, jump height,
# or gravity.
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
#   response on a contact that was never a ceiling hit.
#
#   Fix: the loop now also tracks has_any_downward_facing_normal -- true only when a collision's
#   normal.y is actually positive, never for a purely horizontal wall normal. The fallback now
#   requires that instead of "any collision at all."
#
# FIX B -- the corner AABB-recovery pass bouncing you off a corner while holding into it
#   Screenshot repro: jumping up alongside a single-block-wide wall, holding into it, you get
#   bounced back at the corner of a protruding block (bedrock at grid 50,46 -- confirmed bedrock
#   has no special collision shape, so this was a general corner bug).
#
#   get_recovery_push_for_block() had an ambiguous fallback: when the player's rect wasn't cleanly
#   outside the block on any single side even in the PREVIOUS frame -- sustained multi-frame
#   contact, exactly what climbing alongside a wall past a protruding corner looks like -- it
#   guessed a push axis by comparing overlap.size.x vs overlap.size.y and teleported the player
#   out that way, fighting held input into the corner every frame it recurred.
#
#   Fix: that ambiguous fallback now returns no correction at all and leaves it to
#   move_and_slide(). The four UNAMBIGUOUS "just got embedded from one clear direction" cases are
#   unchanged.
#
# FIX C -- the ceiling head-bonk re-firing on every tile while sliding/flying along a ceiling
#   You retested and reported "still happening, corner of blocks." The log showed FOUR separate,
#   individually-legitimate ceiling releases in quick succession as you moved sideways under a run
#   of tiles while holding upward thrust (a wing item) -- contact legitimately broke and
#   re-established tile by tile, and each firing re-ran the full response.
#
#   Fix: a 0.12s refire cooldown on the response's side effects. move_and_slide() still blocks
#   upward motion into the ceiling every frame regardless.
#
# FIX D (the actual remaining cause) -- the ceiling response was injecting velocity, not just removing it
#   You retested again with the same repeated-jump-into-ceiling repro and reported "issue still
#   persists, corner of blocks." Every released=true event was still a genuine, correctly-spaced
#   ceiling hit -- fix C's cooldown was doing its job. But EVERY trace line, going back through all
#   prior logs, showed vel_before_release already at exactly 0.00 -- move_and_slide() had already
#   stopped the upward motion cleanly and correctly on its own, every single time, with no case of
#   the player actually staying stuck. The function was then forcibly setting velocity.y to a
#   synthetic minimum (24-36 px/s, scaled off impact speed) ON TOP of that already-correct 0.00,
#   plus an instant 1px downward position teleport -- injecting motion move_and_slide() never
#   produced. That is exactly the "collision resolution adding velocity instead of only removing
#   it" pattern from your original bug list, and it's what kept reading as a bounce on every single
#   ceiling touch, no matter how infrequently fix C let it re-fire.
#
#   Fix: removed the forced minimum/scaled velocity and the 1px position teleport entirely (in
#   both release_airborne_block_corner_contact() AND the equivalent line in
#   recover_airborne_block_corner_overlap(), which had the identical pattern). velocity.y is now
#   only ever clamped to non-negative -- a no-op safety net, not a push. Gravity alone carries the
#   fall away from the ceiling afterward, same as a normal jump apex. The now-unused constants
#   (CEILING_RELEASE_MIN_FALL_VELOCITY, CEILING_RELEASE_IMPACT_FALL_RATIO,
#   CEILING_RELEASE_MAX_FALL_VELOCITY, CEILING_UNSTICK_NUDGE) were removed. Jump-state cancellation
#   (variable_jump_active/coyote_timer) and the small corner_nudge_x are untouched -- no evidence
#   either of those was part of the bounce.
#
# Parse-checked with a real Godot headless binary (4.4-stable, --check-only) before delivery --
# clean after filtering the standard sandbox-only "preload not found" / "MovementMode not
# declared" noise documented in the gdscript_parse_checking project note.
#
# Files touched:
#   Scripts/player.gd   (all four fixes)

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
fix(movement): stop the ceiling-release response from injecting velocity/position

Fourth and (per every trace log collected) final fix in this chain:
release_airborne_block_corner_contact() and the matching branch in
recover_airborne_block_corner_overlap() were forcing velocity.y to a
synthetic minimum (24-36 px/s, scaled off impact speed) plus an
instant 1px downward position teleport on every genuine ceiling
contact, even though vel_before_release was already exactly 0.00 in
every single traced event -- move_and_slide() had already stopped the
upward motion cleanly on its own, every time, with no observed case of
the player staying stuck. The forced minimum was pure injected motion
move_and_slide() never produced, i.e. collision resolution adding
velocity instead of only removing it.

velocity.y is now only ever clamped to non-negative (a no-op safety
net given move_and_slide already leaves it there) in both functions.
Gravity alone carries the fall away from the ceiling afterward, same
as a normal jump apex. Removed the now-unused
CEILING_RELEASE_MIN_FALL_VELOCITY / CEILING_RELEASE_IMPACT_FALL_RATIO
/ CEILING_RELEASE_MAX_FALL_VELOCITY / CEILING_UNSTICK_NUDGE constants.
Jump-state cancellation and the small corner_nudge_x position nudge
are unchanged.

Builds on top of three earlier fixes in the same file: (1) corner
normals no longer misclassified as ceiling hits, and sub-margin
recovery residue no longer over-corrected; (2) the ceiling-release
fallback no longer fires on plain side-wall touches at a jump's apex;
(3) the corner AABB-recovery pass no longer guesses a push axis and
ejects the player during sustained, ambiguous multi-frame contact,
which was fighting held input into a corner; (4) a 0.12s refire
cooldown so the ceiling response can't restart on every tile while
sliding/flying along a multi-tile ceiling.

Movement speed, jump height, and gravity are unchanged throughout.
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
Write-Host "IMPORTANT: fully STOP the running scene in the Godot editor (the stop button, not just" -ForegroundColor Yellow
Write-Host "editing) and press Play/F5 again before retesting. Godot's live script reload can be" -ForegroundColor Yellow
Write-Host "unreliable for a physics script this size, and the last test's timing suggested the" -ForegroundColor Yellow
Write-Host "previous fix may not have actually been picked up." -ForegroundColor Yellow
Write-Host ""
Write-Host "TEST with --pm-collision-trace --movement-sync-debug again, focusing on:" -ForegroundColor Yellow
Write-Host "  1. Repeated jump straight into that same world_lock door ceiling at grid 50,44 --" -ForegroundColor Yellow
Write-Host "     each bonk should feel like a clean, gentle stop-and-fall, no snap/kick downward." -ForegroundColor Yellow
Write-Host "  2. Fly/glide sideways along the underside of a multi-tile ceiling while holding up." -ForegroundColor Yellow
Write-Host "  3. Jump up alongside the wall past the bedrock corner at 50,46, holding into it." -ForegroundColor Yellow
Write-Host "  4. Jump beside a wall and hold into it through the whole arc, including the apex." -ForegroundColor Yellow
Write-Host "  5. In the log, vel_after_release should now show y very close to 0.00, not 24-36." -ForegroundColor Yellow
