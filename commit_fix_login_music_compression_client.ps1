# Commits the THIRD login/lobby music fix on the CLIENT repo (pixel-mania).
#
# Context: after commit_fix_login_music_loop_silence_client.ps1 made the music actually
# audible, the user reported it sounds "alot choppier than original" compared to the source
# login.wav played back in Windows Media Player.
#
# Root cause: Assets/sounds/login.wav.import had compress/mode=2, which is Godot's "Quite OK
# Audio" (QOA) codec -- a fast LOSSY compressor the WAV importer applies by default. QOA is
# fine for short one-shot SFX, but for a ~33s continuously-looping music track its
# compression artifacts (a grainy/choppy quality loss versus the source PCM) are much more
# noticeable, which is exactly the difference the user was hearing versus the original file.
#
# Also tidied up while in there: edit/loop_mode was 0 ("Detect From WAV" in the Import dock's
# enum, which only picks up a loop if the source WAV file has an embedded smpl loop chunk --
# login.wav doesn't, so this silently resolved to no loop at bake time). Set explicitly to 2
# ("Forward" in that same dock enum) so a fresh reimport bakes a real forward loop directly,
# instead of relying only on music_manager.gd's runtime fallback (which stays in place as a
# safety net either way -- see commit_fix_login_music_loop_silence_client.ps1).
#
# The fix: Assets/sounds/login.wav.import
#     compress/mode:   2 (QOA, lossy)        -> 0 (PCM, uncompressed)
#     edit/loop_mode:  0 (Detect From WAV)   -> 2 (Forward)
#
# Files touched:
#   Assets/sounds/login.wav.import
#
# IMPORTANT -- this file was hand-edited (same as the .import staleness issue diagnosed
# earlier in this thread), which does NOT by itself make Godot re-bake the compiled
# .godot/imported/*.sample resource. Before testing, you MUST force a reimport:
#   1. In the Godot editor, select Assets/sounds/login.wav in the FileSystem dock.
#   2. Click the "Import" tab (next to "Scene", top-left dock).
#   3. Confirm "Compress Mode" now shows "Disabled" (uncompressed) and "Loop" shows
#      "Forward" -- if the dock hasn't picked up the file change yet, click elsewhere and
#      back to force a refresh, or just proceed to step 4 regardless.
#   4. Click the "Reimport" button at the bottom of the Import dock.
# Only after that reimport will the compiled resource actually be uncompressed. This does
# NOT touch project.godot or any script, so no full editor restart is needed -- just the
# reimport step above, then Play again.
#
# NOTE: the compiled .godot/imported/*.sample binary is not committed (it's gitignored and
# regenerated locally by each machine's own import step) -- only the .import settings file
# is tracked, which is what this script commits.

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Assets/sounds/login.wav.import"
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

git add -- $files commit_fix_login_music_compression_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(audio): stop lossy-compressing the login music, fix loop detection

Assets/sounds/login.wav.import had compress/mode=2 (QOA), Godot's
default lossy WAV compressor. Fine for short one-shot SFX, but for a
~33s continuously-looping music track its compression artifacts were
clearly audible ("alot choppier than original" vs. the source file).
Switched to compress/mode=0 (uncompressed PCM) to match the source
file's quality exactly.

Also: edit/loop_mode was 0 ("Detect From WAV" in the importer's enum),
which only produces a loop if the source WAV has an embedded smpl loop
chunk -- login.wav doesn't, so this silently baked as no-loop. Set
explicitly to 2 ("Forward") so a fresh import bakes a real loop
directly, on top of music_manager.gd's existing runtime fallback.

Requires a manual reimport in the editor (Assets/sounds/login.wav ->
Import tab -> Reimport) for the compiled resource to pick this up --
hand-editing a .import file's settings does not trigger a rebake by
itself.
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
Write-Host "This is a client-only asset settings change -- no server build or deploy needed." -ForegroundColor Yellow
Write-Host "REMINDER: if you haven't already, reimport login.wav (FileSystem dock -> select" -ForegroundColor Yellow
Write-Host "login.wav -> Import tab -> Reimport) before testing, then Play and listen -- it" -ForegroundColor Yellow
Write-Host "should sound as clean as the original file now, not choppy." -ForegroundColor Yellow
