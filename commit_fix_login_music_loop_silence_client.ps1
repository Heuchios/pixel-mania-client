# Commits the SECOND login/lobby music fix on the CLIENT repo (pixel-mania).
#
# Context: commit_fix_login_music_persistence_client.ps1 (already committed and pushed)
# fixed the music restarting on every login<->lobby scene change by moving playback onto a
# MusicManager autoload. After that shipped, the user reported "i dont hear it playing" --
# the music was still completely silent, even though the login/lobby screens displayed
# properly and other game sounds (SFX) worked fine in the same session.
#
# Root cause (found via diagnostic prints added to music_manager.gd): _ensure_player() was
# setting, directly on the loaded runtime AudioStreamWAV:
#     wav_stream.loop_begin = 0
#     wav_stream.loop_end = -1
# -1 is only a valid "use full length" sentinel in login.wav.import's [params] section
# (edit/loop_end=-1), which the WAV importer resolves into the real positive sample count
# when it bakes the compiled resource at import time. The RUNTIME AudioStreamWAV.loop_end
# property has no such sentinel -- it's a literal sample-frame index. Writing a literal -1
# onto the already-correctly-baked resource collapsed the loop into a near-zero-length
# region at sample 0, which Godot's mixer looped instantly forever. That's why every
# diagnostic signal looked healthy (AudioStreamPlayer.playing stayed true, Master bus wasn't
# muted, volume was 0.0 dB, stream length reported the full 32.95s) while nothing was
# actually audible -- the "loop" was too short to perceive, not stopped or muted.
#
# The fix: stopped overwriting loop_begin/loop_end at runtime. login.wav.import already has
# edit/loop_mode=1, edit/loop_begin=0, edit/loop_end=-1 baked in correctly, so the loaded
# AudioStreamWAV already has the right values -- music_manager.gd now only fixes loop_mode,
# and only if it somehow isn't already set. Also added a diagnostic print of the imported
# loop_mode/loop_begin/loop_end/mix_rate values so this can be confirmed from the Output
# panel after testing (expect a large positive loop_end, not -1, and loop_mode=1).
#
# Files touched:
#   Scripts/music_manager.gd
#
# NOTE: project.godot is NOT touched by this fix (no new/changed autoload), so a plain
# script reload in the Godot editor is enough this time -- no need to close/reopen the
# project.

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/music_manager.gd"
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

git add -- $files commit_fix_login_music_loop_silence_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(audio): stop collapsing the login music loop to near-zero length

music_manager.gd was setting wav_stream.loop_begin = 0 / loop_end = -1
directly on the loaded runtime AudioStreamWAV. -1 is only a valid "use
full length" sentinel in login.wav.import's edit/loop_end *import*
setting, which the WAV importer resolves into the real positive sample
count when it bakes the compiled resource. The runtime
AudioStreamWAV.loop_end property takes a literal sample index with no
such sentinel, so writing -1 there collapsed the loop into a
near-zero-length region at sample 0 -- Godot looped that instantly
forever, so AudioStreamPlayer.playing correctly stayed true (matching
the diagnostic logs) while producing no audible output the entire
time.

Stopped overwriting loop_begin/loop_end at runtime and trust the
already-correct import-baked values instead; only fix loop_mode, and
only if it isn't already set. Added a diagnostic print of the imported
loop settings to confirm from the Output panel.
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
Write-Host "project.godot was NOT changed this time, so a plain script reload (or just" -ForegroundColor Yellow
Write-Host "re-running the scene / restarting Play) is enough -- no need to close/reopen the project." -ForegroundColor Yellow
Write-Host "Test: login screen and lobby should now actually have audible music. Check the Output" -ForegroundColor Yellow
Write-Host "panel for a line like '[MusicManager] imported loop settings: loop_mode=1 loop_begin=0" -ForegroundColor Yellow
Write-Host "loop_end=<big positive number> mix_rate=<...>' -- loop_end should NOT be -1 or 0." -ForegroundColor Yellow
