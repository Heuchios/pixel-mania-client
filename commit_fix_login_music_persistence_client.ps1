# Commits the persistent login/lobby music fix on the CLIENT repo (pixel-mania).
#
# Request: play Assets/sounds/login.wav starting at the login screen, continuing
# uninterrupted through the lobby menu, looped seamlessly, and stopped once a world is
# actually joined.
#
# What was already correct: login.wav.import already has edit/loop_mode=1 (forward),
# loop_begin=0, loop_end=-1 -- native, sample-accurate, gapless looping was never the
# problem. menu_loop_sound_helper.gd (untouched by this fix, still used as a general-purpose
# helper) also re-applies that same loop config at runtime as a safety net.
#
# The actual bug: login_screen.gd and lobby_scene.gd EACH called
# MenuLoopSoundHelper.start_menu_loop_sound(self, ...) independently, which parents a new
# AudioStreamPlayer as a CHILD OF THE CALLING SCENE. Godot frees a scene's entire node tree
# on every change_scene_to_*() call, so:
#   - login_screen.gd's _exit_tree() explicitly called login_sound_player.stop() on every
#     exit, including the normal login -> lobby handoff.
#   - lobby_scene.gd's _ready() then created a brand-new AudioStreamPlayer and called
#     play() from 0:00.
# Net effect: the track audibly stopped and restarted from the beginning every time the
# player moved from login to lobby (or back), instead of playing continuously.
#
# The fix: a new autoload singleton, MusicManager (Scripts/music_manager.gd, registered in
# project.godot's [autoload] section), owns a single AudioStreamPlayer that is never part of
# any scene's tree -- so scene changes never touch it. login_screen.gd and lobby_scene.gd
# both now call MusicManager.start_login_loop() in _ready() (idempotent: a no-op if it's
# already playing, so the lobby doesn't restart music login already started), and
# MusicManager.stop_login_loop() is called at every point that actually enters a world
# (lobby_scene.gd's normal "join world" path, plus login_screen.gd's direct-to-world netfox
# launch-handoff path that bypasses the lobby) -- with the loop resumed again if that scene
# change fails partway through, since the player is still on the login/lobby screen then.
#
# Files touched:
#   Scripts/music_manager.gd        (new)
#   project.godot                   (new MusicManager autoload entry)
#   Scripts/login_screen.gd
#   Scripts/ui/lobby_scene.gd
#
# IMPORTANT: project.godot changed (new autoload). If the Godot editor is already open,
# close and reopen the project (or otherwise force it to reload project.godot) so it
# registers the new MusicManager autoload -- a plain script reload is not enough for a
# NEW autoload entry to take effect.

$ErrorActionPreference = "Stop"

Set-Location "G:\PixelMania\pixel-mania"

$files = @(
    "Scripts/music_manager.gd",
    "project.godot",
    "Scripts/login_screen.gd",
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
Write-Host "=== New file (music_manager.gd) ===" -ForegroundColor Cyan
Get-Content "Scripts/music_manager.gd"

Write-Host ""
Write-Host "Review the diff above carefully." -ForegroundColor Yellow
Write-Host "Press Enter to continue and commit, or Ctrl+C to abort." -ForegroundColor Yellow
Read-Host

git add -- $files commit_fix_login_music_persistence_client.ps1

Write-Host ""
Write-Host "=== git status (staged) ===" -ForegroundColor Cyan
git status

$commitMessage = @"
fix(audio): make login/lobby music persist across the scene change

login_screen.gd and lobby_scene.gd each created their own AudioStreamPlayer
as a child of their own scene (via MenuLoopSoundHelper), so the track
stopped and restarted from 0:00 every time the player moved between the
login screen and the lobby menu -- login_screen.gd's _exit_tree() even
explicitly stopped it on every exit.

Added a MusicManager autoload (Scripts/music_manager.gd, registered in
project.godot) that owns a single AudioStreamPlayer living outside any
scene's tree, so scene changes never touch it. Both screens now call
MusicManager.start_login_loop() in _ready() (a no-op if already playing),
and MusicManager.stop_login_loop() is called at every point that actually
enters a world, with the loop resumed if that scene change fails.

login.wav's native WAV loop settings (forward, full-length) were already
correct and are unchanged -- this was purely a persistence bug, not a
looping bug.
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
Write-Host "This is a client-only GDScript + project.godot change -- no server build or deploy needed." -ForegroundColor Yellow
Write-Host "IMPORTANT: close and reopen the project in the Godot editor (not just a script reload) so it" -ForegroundColor Yellow
Write-Host "picks up the new MusicManager autoload entry, then test: login screen should have music from" -ForegroundColor Yellow
Write-Host "the first frame, it should carry on with no gap into the lobby, and stop the instant you join a world." -ForegroundColor Yellow
