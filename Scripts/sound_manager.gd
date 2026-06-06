extends Node

# PixelMania Sound Manager v1
#
# Plays sound effects for punch, block place, and jump.
#
# TO ADD YOUR SOUNDS:
# Drop audio files into res://Assets/sounds/ and set the paths below.
# Supported formats: .wav, .ogg, .mp3
#
# Example paths:
#   SOUND_PUNCH = "res://Assets/sounds/punch.wav"
#   SOUND_PLACE = "res://Assets/sounds/place.wav"
#   SOUND_JUMP  = "res://Assets/sounds/jump.wav"
#
# Each sound has its own AudioStreamPlayer so they can overlap freely.

const SOUND_PUNCH = "res://Assets/sounds/punch.wav"
const SOUND_PLACE = "res://Assets/sounds/place.wav"
const SOUND_JUMP  = "res://Assets/sounds/jump.wav"

const VOLUME_PUNCH = -6.0   # dB
const VOLUME_PLACE = -8.0
const VOLUME_JUMP  = -10.0

var world = null

var _player_punch: AudioStreamPlayer = null
var _player_place: AudioStreamPlayer = null
var _player_jump:  AudioStreamPlayer = null


func setup(world_ref):
	world = world_ref
	_build_players()


func _build_players():
	_player_punch = _make_player("SFX_Punch", SOUND_PUNCH, VOLUME_PUNCH)
	_player_place = _make_player("SFX_Place", SOUND_PLACE, VOLUME_PLACE)
	_player_jump  = _make_player("SFX_Jump",  SOUND_JUMP,  VOLUME_JUMP)


func _make_player(node_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = volume_db
	p.bus = "Master"

	if ResourceLoader.exists(path):
		p.stream = load(path)
	else:
		push_warning("SoundManager: audio file not found — " + path)

	add_child(p)
	return p


# ── Public API ────────────────────────────────────────────────

func play_punch():
	_play(_player_punch)

func play_place():
	_play(_player_place)

func play_jump():
	_play(_player_jump)


func _play(player: AudioStreamPlayer):
	if player == null or player.stream == null:
		return
	# Stop and restart so rapid repeats don't queue up
	if player.playing:
		player.stop()
	player.play()
