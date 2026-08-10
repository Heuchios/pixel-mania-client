extends Node

# Autoload (see project.godot [autoload] -> MusicManager). Persistent, seamless
# background-music player for the login/lobby menu loop.
#
# Why this exists: login_screen.gd and lobby_scene.gd each used to call
# MenuLoopSoundHelper.start_menu_loop_sound(self, ...) independently, which parents a new
# AudioStreamPlayer as a CHILD OF THE CALLING SCENE. Every login<->lobby scene change frees
# the old scene (and its player with it) and the next scene's _ready() created a brand new
# player and called play() from 0:00 -- so the music audibly restarted on every transition
# instead of continuing, and login_screen.gd's _exit_tree() explicitly stopped it on top of
# that. Living on an autoload instead means the single AudioStreamPlayer here is never part
# of any scene's tree, so scene changes never touch it -- it just keeps playing.
#
# Usage: call start_login_loop() from both login_screen.gd and lobby_scene.gd's _ready()
# (idempotent -- a no-op if it's already playing, so entering lobby right after login does
# NOT restart the track). Call stop_login_loop() once, right before any scene change that
# actually enters a world (gameplay should be quiet, not the menu loop).

const LOGIN_LOOP_SOUND_PATH := "res://Assets/sounds/login.wav"
const LOGIN_LOOP_SOUND_VOLUME_DB := -12.0
const LOGIN_LOOP_MODE := AudioStreamWAV.LOOP_FORWARD

var _player: AudioStreamPlayer = null


func start_login_loop() -> void:
	_ensure_player()
	if _player == null:
		return
	if _player.playing:
		return
	_player.call_deferred("play")


func stop_login_loop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()


func _ensure_player() -> void:
	if _player != null and is_instance_valid(_player):
		return

	_player = AudioStreamPlayer.new()
	_player.name = "LoginLoopSound"
	add_child(_player)
	_player.volume_db = LOGIN_LOOP_SOUND_VOLUME_DB
	if AudioServer.get_bus_index("Master") != -1:
		_player.bus = "Master"

	var stream = load(LOGIN_LOOP_SOUND_PATH)
	if stream is AudioStreamWAV:
		# The .wav.import already has edit/loop_mode=1 (forward) baked in, so this is
		# belt-and-suspenders -- makes the loop correct even if the import settings ever
		# change, since AudioStreamWAV.loop_* are what the engine actually reads at runtime.
		var wav_stream := stream as AudioStreamWAV
		wav_stream.loop_mode = LOGIN_LOOP_MODE
		wav_stream.loop_begin = 0
		wav_stream.loop_end = -1
	_player.stream = stream

	# Fallback in case the native WAV loop ever doesn't fire (e.g. stream swapped to a
	# non-looping format later) -- same pattern menu_loop_sound_helper.gd used.
	var replay_callable := Callable(_player, "play")
	if not _player.finished.is_connected(replay_callable):
		_player.finished.connect(replay_callable)
