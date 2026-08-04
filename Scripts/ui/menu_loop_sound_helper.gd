extends Node

const DEFAULT_LOGIN_SOUND_PATH := "res://Assets/sounds/login.wav"
const DEFAULT_LOGIN_SOUND_VOLUME_DB := -12.0
const MENU_SOUND_LOOP_MODE := AudioStreamWAV.LOOP_FORWARD

static func start_menu_loop_sound(host_node: Node, stream_path: String = DEFAULT_LOGIN_SOUND_PATH, player_name: String = "LoginLoopSound", volume_db: float = DEFAULT_LOGIN_SOUND_VOLUME_DB) -> AudioStreamPlayer:
	if host_node == null:
		push_warning("MenuLoopSoundHelper: owner is null.")
		return null

	var player := host_node.get_node_or_null(player_name) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = player_name
		host_node.add_child(player)

	player.autoplay = true
	player.volume_db = volume_db
	if AudioServer.get_bus_index("Master") != -1:
		player.bus = "Master"

	if not (player.stream is AudioStream):
		if not ResourceLoader.exists(stream_path):
			push_warning("MenuLoopSoundHelper: audio file not found - " + stream_path)
			return null

		var stream_resource: Resource = load(stream_path)
		if not (stream_resource is AudioStream):
			push_warning("MenuLoopSoundHelper: invalid audio resource - " + stream_path)
			return null

		player.stream = stream_resource

	if not (player.stream is AudioStream):
		push_warning("MenuLoopSoundHelper: audio file not found - " + stream_path)
		return null

	# Keep native WAV looping enabled, then fall back to replay if signal fires.
	if player.stream is AudioStreamWAV:
		var wav_stream := player.stream as AudioStreamWAV
		if wav_stream != null:
			wav_stream.loop_mode = MENU_SOUND_LOOP_MODE
			wav_stream.loop_begin = 0
			wav_stream.loop_end = -1

	var replay_callable := Callable(player, "play")
	if not player.finished.is_connected(replay_callable):
		player.finished.connect(replay_callable)

	if not player.playing:
		player.call_deferred("play")

	return player
