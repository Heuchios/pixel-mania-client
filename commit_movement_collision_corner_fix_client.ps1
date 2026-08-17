# Commits the airborne wall/corner collision "rubber-banding" fix on the CLIENT repo.
#
# WHAT WAS WRONG
#   player.gd's move_and_slide() call already resolves player-vs-block collisions correctly
#   (Godot's CharacterBody2D does proper axis-separated, swept-shape resolution). Immediately
#   after every move_and_slide() call, TWO extra hand-written passes ran on top of it:
#     - release_airborne_block_corner_contact()   (unsticks from a ceiling/overhang)
#     - recover_airborne_block_corner_overlap()   (manual Rect2-vs-Rect2 AABB pushout, up to 4
#                                                    iterations, against every nearby solid block)
#   Both were built to handle a genuine "stuck under an overhang" case, but their trigger
#   conditions were far too broad:
#     - release_airborne_block_corner_contact() treated ANY slide-collision normal with
#       normal.y > 0.35 as "overhead contact" -- including corner normals like (0.6, 0.4) that
#       are actually more wall than ceiling -- and force-set velocity.y to a synthetic value plus
#       nudged position, even though nothing was actually stuck.
#     - recover_airborne_block_corner_overlap() ran its manual AABB pushout on ANY airborne
#       contact with |normal.x| > 0.15 (i.e. almost every ordinary wall touch, not just corners),
#       and treated move_and_slide()'s own expected sub-pixel safe-margin residue (~0.08px, by
#       design) the same as a real multi-pixel stuck-in-geometry case -- reapplying a position
#       push AND zeroing/clamping velocity for corrections as small as a few hundredths of a
#       pixel, every single frame the player brushed a wall or corner while airborne.
#   Net effect: two collision systems fighting every frame near walls/corners/ceilings -- exactly
#   the rubbery/bouncy/sticky/jittery feel reported (jumping beside blocks, corner grazes, holding
#   into a wall while airborne, landing near edges).
#
# THE FIX (player.gd)
#   - New const SOLID_COLLISION_RECOVERY_MIN_CORRECTION = 0.6px. The AABB recovery loop now
#     breaks out (does nothing) once the computed correction is smaller than this -- i.e. it only
#     acts on a real, meaningful overlap, not move_and_slide()'s own expected safe-margin residue.
#     Movement speed/jump/gravity constants are untouched; this only changes when the SECOND,
#     manual recovery pass is allowed to override move_and_slide()'s already-correct result.
#   - release_airborne_block_corner_contact()'s ceiling check now also requires normal.y to be
#     the DOMINANT axis (normal.y > |normal.x|), so a corner/wall-ish normal is no longer
#     misclassified as a ceiling hit and no longer force-edits velocity.y/position for it.
#
# DIAGNOSTICS (world.gd)
#   apply_server_player_position_correction()'s existing --movement-sync-debug print (unchanged
#   gate, no new flag) now also logs predicted vs authoritative position, velocity X/Y, and
#   on_floor state at the moment of every server reconciliation correction, alongside the
#   already-existing correction count/distance/snap fields.
#
# EXISTING DIAGNOSTICS TO USE WHEN TESTING (already built into this codebase, not new):
#   --pm-collision-trace          (or env PIXELMANIA_COLLISION_TRACE=1) on player.gd: prints
#                                  [PM_COLLISION_TRACE] / [PM_COLLISION_RECOVERY] lines with
#                                  collision axis, tile/block, penetration, and whether the
#                                  overhead-release/AABB-recovery paths fired.
#   --movement-sync-debug         on world.gd: prints [MovementSync][Local] lines with every
#                                  server reconciliation correction and (now) velocity/grounded
#                                  state at that moment.
#   Run the client with BOTH flags together while doing the reproduction tests to see collision
#   events and reconciliation events on the same timeline.
#
# Both .gd files were parse-checked with a real Godot headless binary (4.4-stable, --check-only)
# before delivery -- clean after filtering the standard sandbox-only "preload not found" /
# "MovementMode not declared" noise documented in the gdscript_parse_checking project note.
#
# Files touched:
#   Scripts/player.gd   (the fix)
#   Scripts/world.gd    (diagnostics only)

$ErrorActionPreference = "Stop"
Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/player.gd",
    "Scripts/world.gd"
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

git add -- $files commit_movement_collision_corner_fix_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(movement): stop the manual airborne corner/wall recovery pass from fighting move_and_slide()

player.gd ran a second, hand-written AABB collision recovery pass
(recover_airborne_block_corner_overlap / release_airborne_block_corner_contact)
immediately after every move_and_slide() call. move_and_slide() already
resolves player-vs-block collisions correctly; the manual pass was meant
to unstick a player genuinely wedged under an overhang, but its trigger
conditions were broad enough to fire on ordinary wall/corner contact and
on move_and_slide()'s own expected sub-pixel safe-margin residue -- both
of which then got a position push AND a velocity zero/clamp applied on
top of an already-correct result, every frame near a wall or corner.

Adds a minimum-correction-magnitude gate (0.6px) to the AABB recovery
loop so it only acts on real overlap, and tightens the ceiling-contact
classification to require normal.y to actually dominate normal.x, so a
corner-ish normal is no longer treated as a ceiling hit. Movement speed,
jump height, and gravity constants are unchanged.

world.gd: the existing --movement-sync-debug reconciliation print now
also logs predicted/authoritative position, velocity, and on_floor state
per correction (no new flag).
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
Write-Host "TEST (see the 20-case reproduction list in the writeup) -- at minimum:" -ForegroundColor Yellow
Write-Host "  1. Jump beside a wall and hold into it -- should slide down smoothly, no stutter." -ForegroundColor Yellow
Write-Host "  2. Jump toward a block's top-left/top-right corner -- no bounce-back, no snag." -ForegroundColor Yellow
Write-Host "  3. Walk across 20+ adjacent blocks -- grounded state should stay stable, no flicker." -ForegroundColor Yellow
Write-Host "  4. Land near a block edge while holding movement -- horizontal speed should be preserved." -ForegroundColor Yellow
Write-Host "Run with --pm-collision-trace --movement-sync-debug to watch collision + reconciliation" -ForegroundColor Yellow
Write-Host "events live while you do this. No project.godot change, so a plain script reload is enough." -ForegroundColor Yellow
