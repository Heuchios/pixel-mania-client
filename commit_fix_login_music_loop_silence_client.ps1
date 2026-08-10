# Commits the SECOND login/lobby music fix on the CLIENT repo (pixel-mania).
#
# Context: commit_fix_login_music_persistence_client.ps1 (already committed and pushed)
# fixed the music restarting on every login<->lobby scene change by moving playback onto a
# MusicManager autoload. After that shipped, the user reported "i dont hear it playing" --
# the music was still completely silent, even though the login/lobby screens displayed
# properly and other game sounds (SFX) worked fine in the same session. This turned out to
# be TWO stacked bugs, both diagnosed via print()s added to music_manager.gd:
#
# Bug A: _ensure_player() was setting, directly on the loaded runtime AudioStreamWAV:
#     wav_stream.loop_begin = 0
#     wav_stream.loop_end = -1
# -1 is only a valid "use full length" sentinel in login.wav.import's [params] section
# (edit/loop_end=-1), meant to be resolved into the real positive sample count when the WAV
# importer bakes the compiled resource at import time. The RUNTIME AudioStreamWAV.loop_end
# property has no such sentinel -- it's a literal sample-frame index. Writing a literal -1
# there collapsed the loop into a near-zero-length region at sample 0.
#
# Bug B: after removing that override (expecting the import-baked loop_end to already be
# correct), a new diagnostic print revealed the *actual* baked resource reports
# loop_mode=0 (disabled) and loop_end=0 -- NOT the positive value login.wav.import's
# settings should have produced. The compiled .godot/imported/*.sample resource was stale:
# Godot only re-bakes a resource when it's reimported through the editor, not just because
# the .import file's [params] text changed on disk, so the actual binary the game loads
# still reflected an older loop-disabled bake.
#
# Both bugs produce the same symptom (a zero/near-zero-length loop that Godot's mixer loops
# instantly forever), which is why every diagnostic signal looked healthy the whole time
# (AudioStreamPlayer.playing stayed true, Master bus wasn't muted, volume was 0.0 dB, stream
# length reported the full ~33s) while nothing was actually audible.
#
# The fix: music_manager.gd no longer trusts the baked loop_begin/loop_end at all. It still
# fixes loop_mode if disabled, but now also checks if loop_end <= loop_begin (catches both
# bugs above) and, if so, computes the real full-length sample count directly from the
# stream's own reported length/mix_rate and uses that instead. This makes playback correct
# regardless of whether the compiled resource is ever properly reimported. Diagnostic prints
# of the before/after loop values were kept so this can be confirmed from the Output panel.
#
# Files touched:
#   Scripts/music_manager.gd
#
# NOTE: project.godot is NOT touched by this fix (no new/changed autoload), so a plain
# script reload in the Godot editor is enough this time -- no need to close/reopen the
# project.
#
# OPTIONAL (not required by this fix, but good hygiene): in the Godot editor, select
# Assets/sounds/login.wav in the FileSystem dock, open the "Import" tab, and click
# "Reimport" so the compiled resource's own loop settings match login.wav.import directly.

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

Two stacked bugs made login.wav's loop collapse to near-zero length,
which Godot then looped instantly forever -- AudioStreamPlayer.playing
stayed true and no error was raised, so it looked like normal playback
while producing no audible sound:

1. music_manager.gd was setting wav_stream.loop_begin = 0 / loop_end =
   -1 directly on the loaded runtime AudioStreamWAV. -1 is only a
   valid "use full length" sentinel in login.wav.import's
   edit/loop_end *import* setting; the runtime AudioStreamWAV.loop_end
   property takes a literal sample index with no such sentinel.

2. Even after removing that override, the actual compiled
   .godot/imported/*.sample resource turned out to be stale relative
   to login.wav.import's settings (baked with looping disabled and
   loop_end=0) -- editing a .import file's [params] doesn't by itself
   trigger Godot to re-bake the resource.

Fix: music_manager.gd no longer trusts the baked loop_end. It still
fixes loop_mode if disabled, and now also detects a degenerate loop
region (loop_end <= loop_begin) and computes the real full-length
sample count from the stream's own reported length/mix_rate instead,
so playback is correct regardless of the compiled resource's state.
Diagnostic prints of the before/after loop values were kept for future
verification.
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
Write-Host "panel for a '[MusicManager] loop settings after fixup: ...' line -- loop_end should be a" -ForegroundColor Yellow
Write-Host "large positive number there (roughly length_in_seconds * mix_rate), not 0 or -1. If you" -ForegroundColor Yellow
Write-Host "also see a '[MusicManager] baked loop_end (...) <= loop_begin (...)' warning, that just" -ForegroundColor Yellow
Write-Host "confirms the fallback kicked in because the compiled resource is still stale -- harmless." -ForegroundColor Yellow
