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
		print("[MusicManager] start_login_loop: _player is null after _ensure_player(), aborting.")
		return
	if _player.playing:
		print("[MusicManager] start_login_loop: already playing, no-op.")
		return
	print("[MusicManager] start_login_loop: stream=%s bus=%s volume_db=%.1f -- calling play()." % [_player.stream, _player.bus, _player.volume_db])
	_player.call_deferred("play")
	call_deferred("_log_playback_state")


func _log_playback_state() -> void:
	# Runs one deferred call after play() -- confirms whether Godot actually started
	# playback, and whether the "Master" bus itself is muted or has its volume pulled down
	# (both would produce exactly "no errors, no sound").
	if _player == null:
		return
	var master_idx := AudioServer.get_bus_index("Master")
	var master_muted := master_idx != -1 and AudioServer.is_bus_mute(master_idx)
	var master_db := AudioServer.get_bus_volume_db(master_idx) if master_idx != -1 else 0.0
	print("[MusicManager] after play(): playing=%s stream_len=%.2fs master_bus_muted=%s master_bus_volume_db=%.1f" % [
		_player.playing,
		_player.stream.get_length() if _player.stream != null else -1.0,
		master_muted,
		master_db,
	])


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
	if stream == null:
		push_warning("[MusicManager] Could not load stream at " + LOGIN_LOOP_SOUND_PATH)
	if stream is AudioStreamWAV:
		var wav_stream := stream as AudioStreamWAV
		print("[MusicManager] baked loop settings (before fixup): loop_mode=%d loop_begin=%d loop_end=%d mix_rate=%d length=%.2fs" % [
			wav_stream.loop_mode, wav_stream.loop_begin, wav_stream.loop_end, wav_stream.mix_rate, wav_stream.get_length()
		])
		# login.wav.import says edit/loop_mode=1 (forward), edit/loop_begin=0,
		# edit/loop_end=-1 ("use full length"), which the WAV importer is supposed to
		# resolve into a real positive sample count when it bakes the compiled
		# .godot/imported/*.sample resource. In practice the currently-baked resource on
		# disk reports loop_mode=0 (disabled) and loop_end=0 -- a stale import cache from
		# before the .import file's loop settings were last edited (Godot only re-bakes a
		# resource when you reimport it through the editor; a hand-edited .import file
		# doesn't trigger that by itself). Re-importing login.wav via the editor's Import
		# dock (select the file -> Import tab -> Reimport) will fix the baked resource
		# directly, but we also fix it defensively here at runtime so playback is correct
		# even if that reimport step is ever missed: if looping is enabled but loop_end
		# isn't meaningfully past loop_begin (a zero/near-zero-length loop region --
		# exactly what caused the earlier "playing=true but silent" bug, whether from a
		# bad runtime override or, as turned out to be the actual case here, a stale
		# import bake), fall back to the real full length computed from the stream itself
		# instead of trusting whatever got baked in.
		if wav_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav_stream.loop_mode = LOGIN_LOOP_MODE
		if wav_stream.loop_end <= wav_stream.loop_begin:
			var computed_loop_end := int(round(wav_stream.get_length() * wav_stream.mix_rate))
			push_warning("[MusicManager] baked loop_end (%d) <= loop_begin (%d) -- stale/broken import data, falling back to computed full-length loop_end=%d" % [
				wav_stream.loop_end, wav_stream.loop_begin, computed_loop_end
			])
			wav_stream.loop_end = computed_loop_end
		print("[MusicManager] loop settings after fixup: loop_mode=%d loop_begin=%d loop_end=%d" % [
			wav_stream.loop_mode, wav_stream.loop_begin, wav_stream.loop_end
		])
	_player.stream = stream

	# Fallback in case the native WAV loop ever doesn't fire (e.g. stream swapped to a
	# non-looping format later) -- same pattern menu_loop_sound_helper.gd used.
	var replay_callable := Callable(_player, "play")
	if not _player.finished.is_connected(replay_callable):
		_player.finished.connect(replay_callable)
