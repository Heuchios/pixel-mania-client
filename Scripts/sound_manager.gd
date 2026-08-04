extends Node

# PixelMania Sound Manager v1
#
# Plays sound effects for punch, block break, block place, jump, water jump, lava/fire hit, entrances, and vending purchases.
#
# TO ADD YOUR SOUNDS:
# Drop audio files into res://Assets/sounds/ and set the paths below.
# Supported formats: .wav, .ogg, .mp3
#
# Example paths:
#   SOUND_PUNCH = "res://Assets/sounds/punch.wav"
#   SOUND_BREAK = "res://Assets/sounds/break.wav"
#   SOUND_PLACE = "res://Assets/sounds/place.wav"
#   SOUND_JUMP  = "res://Assets/sounds/jump.wav"
#   SOUND_WATER_JUMP = "res://Assets/sounds/water_jump.mp3"
#   SOUND_LAVA_FIRE_HIT = "res://Assets/sounds/lava_fire_hit.wav"
#   SOUND_VEND_PURCHASE = "res://Assets/sounds/vend_purchase.wav"
#
# Each sound has its own AudioStreamPlayer so they can overlap freely.

const SOUND_PUNCH = "res://Assets/sounds/punch.wav"
const SOUND_BREAK = "res://Assets/sounds/break.wav"
const SOUND_PLACE = "res://Assets/sounds/place.wav"
const SOUND_JUMP  = "res://Assets/sounds/jump.wav"
const SOUND_WATER_JUMP = "res://Assets/sounds/water_jump.mp3"
const SOUND_LAVA_FIRE_HIT = "res://Assets/sounds/lava_fire_hit.wav"
const SOUND_ENTRANCE = "res://Assets/sounds/entrance.wav"
const SOUND_VEND_PURCHASE = "res://Assets/sounds/vend_purchase.wav"
const SOUND_JOIN_WORLD = "res://Assets/sounds/join_world.wav"

const VOLUME_PUNCH = -6.0   # dB
const VOLUME_BREAK = -6.0
const VOLUME_PLACE = -8.0
const VOLUME_JUMP  = -10.0
const VOLUME_WATER_JUMP = -8.0
const VOLUME_LAVA_FIRE_HIT = -8.0
const VOLUME_ENTRANCE = -8.0
const VOLUME_VEND_PURCHASE = -8.0
const VOLUME_JOIN_WORLD = -8.0
const POSITIONLESS_SOUND_SOURCE := Vector2(INF, INF)
const SOUND_FULL_VOLUME_DISTANCE := 96.0
const SOUND_MAX_DISTANCE := 704.0
const SOUND_FADE_CURVE := 1.35
const SOUND_MIN_PLAY_GAIN := 0.012
const SOUND_SILENT_VOLUME_DB := -80.0

var world = null
var sfx_volume_linear := 1.0

var _player_punch: AudioStreamPlayer = null
var _player_break: AudioStreamPlayer = null
var _player_place: AudioStreamPlayer = null
var _player_jump:  AudioStreamPlayer = null
var _player_water_jump: AudioStreamPlayer = null
var _player_lava_fire_hit: AudioStreamPlayer = null
var _player_entrance: AudioStreamPlayer = null
var _player_vend_purchase: AudioStreamPlayer = null
var _player_join_world: AudioStreamPlayer = null


func setup(world_ref):
	world = world_ref
	_build_players()


func _build_players():
	_player_punch = _make_player("SFX_Punch", SOUND_PUNCH, VOLUME_PUNCH)
	_player_break = _make_player("SFX_Break", SOUND_BREAK, VOLUME_BREAK)
	_player_place = _make_player("SFX_Place", SOUND_PLACE, VOLUME_PLACE)
	_player_jump  = _make_player("SFX_Jump",  SOUND_JUMP,  VOLUME_JUMP)
	_player_water_jump = _make_player("SFX_WaterJump", SOUND_WATER_JUMP, VOLUME_WATER_JUMP)
	_player_lava_fire_hit = _make_player("SFX_LavaFireHit", SOUND_LAVA_FIRE_HIT, VOLUME_LAVA_FIRE_HIT)
	_player_entrance = _make_player("SFX_Entrance", SOUND_ENTRANCE, VOLUME_ENTRANCE)
	_player_vend_purchase = _make_player("SFX_VendPurchase", SOUND_VEND_PURCHASE, VOLUME_VEND_PURCHASE)
	_player_join_world = _make_player("SFX_JoinWorld", SOUND_JOIN_WORLD, VOLUME_JOIN_WORLD)


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

func play_punch(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_punch, VOLUME_PUNCH, source_position)

func play_break(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_break, VOLUME_BREAK, source_position)

func play_place(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_place, VOLUME_PLACE, source_position)

func play_jump(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_jump, VOLUME_JUMP, source_position)

func play_water_jump(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_water_jump, VOLUME_WATER_JUMP, source_position)

func play_lava_fire_hit(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_lava_fire_hit, VOLUME_LAVA_FIRE_HIT, source_position)

func play_entrance(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_entrance, VOLUME_ENTRANCE, source_position)

func play_vend_purchase(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_vend_purchase, VOLUME_VEND_PURCHASE, source_position)

func play_join_world(source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	_play(_player_join_world, VOLUME_JOIN_WORLD, source_position)


func set_sfx_volume(value: float) -> void:
	sfx_volume_linear = clampf(value, 0.0, 1.0)
	_refresh_idle_player_volumes()


func get_sfx_volume() -> float:
	return sfx_volume_linear


func _play(player: AudioStreamPlayer, base_volume_db: float, source_position: Vector2 = POSITIONLESS_SOUND_SOURCE):
	if player == null or player.stream == null:
		return
	var attenuated_volume_db: float = get_attenuated_volume_db(base_volume_db, source_position)
	if attenuated_volume_db <= SOUND_SILENT_VOLUME_DB:
		return
	var final_volume_db := get_scaled_sfx_volume_db(attenuated_volume_db)
	if final_volume_db <= SOUND_SILENT_VOLUME_DB:
		return
	player.volume_db = final_volume_db
	# Stop and restart so rapid repeats don't queue up
	if player.playing:
		player.stop()
	player.play()


func get_attenuated_volume_db(base_volume_db: float, source_position: Vector2 = POSITIONLESS_SOUND_SOURCE) -> float:
	if not is_valid_world_position(source_position):
		return base_volume_db

	var listener_position: Vector2 = get_listener_world_position()
	if not is_valid_world_position(listener_position):
		return base_volume_db

	var distance: float = listener_position.distance_to(source_position)
	if distance <= SOUND_FULL_VOLUME_DISTANCE:
		return base_volume_db
	if distance >= SOUND_MAX_DISTANCE:
		return -80.0

	var fade_t: float = clampf((distance - SOUND_FULL_VOLUME_DISTANCE) / (SOUND_MAX_DISTANCE - SOUND_FULL_VOLUME_DISTANCE), 0.0, 1.0)
	var gain: float = pow(1.0 - fade_t, SOUND_FADE_CURVE)
	if gain <= SOUND_MIN_PLAY_GAIN:
		return SOUND_SILENT_VOLUME_DB
	return base_volume_db + linear_to_db(gain)


func get_scaled_sfx_volume_db(base_volume_db: float) -> float:
	if sfx_volume_linear <= 0.001:
		return SOUND_SILENT_VOLUME_DB

	return base_volume_db + linear_to_db(sfx_volume_linear)


func _refresh_idle_player_volumes() -> void:
	var players_with_base_volume := [
		[_player_punch, VOLUME_PUNCH],
		[_player_break, VOLUME_BREAK],
		[_player_place, VOLUME_PLACE],
		[_player_jump, VOLUME_JUMP],
		[_player_water_jump, VOLUME_WATER_JUMP],
		[_player_lava_fire_hit, VOLUME_LAVA_FIRE_HIT],
		[_player_entrance, VOLUME_ENTRANCE],
		[_player_vend_purchase, VOLUME_VEND_PURCHASE],
		[_player_join_world, VOLUME_JOIN_WORLD],
	]

	for entry in players_with_base_volume:
		var player: AudioStreamPlayer = entry[0] as AudioStreamPlayer
		if player == null:
			continue
		player.volume_db = get_scaled_sfx_volume_db(float(entry[1]))


func get_listener_world_position() -> Vector2:
	if world == null:
		return POSITIONLESS_SOUND_SOURCE
	var player_node = world.get("player")
	if player_node is Node2D and is_instance_valid(player_node):
		return player_node.global_position
	return POSITIONLESS_SOUND_SOURCE


func is_valid_world_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y)
