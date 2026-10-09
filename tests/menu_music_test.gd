extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	var music = root.get_node("MusicManager")
	music.stop_login_loop()
	music.start_login_loop()
	music.start_login_loop()
	var player: AudioStreamPlayer = music.get_node("LoginLoopSound")
	var stream := player.stream as AudioStreamWAV
	assert(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS, "Menu music must use lossless PCM")
	assert(stream.stereo and stream.mix_rate == 48000)
	assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(stream.loop_begin == 0 and stream.loop_end >= stream.data.size() / 4 - 1 and stream.loop_end <= stream.data.size() / 4)
	# Compare the imported PCM with the actual source, catching stale lossy cache
	# resources as well as accidentally restored compression settings.
	var source := FileAccess.get_file_as_bytes("res://Assets/sounds/login.wav")
	var offset := 12
	var matched := false
	while offset + 8 <= source.size():
		var chunk_size := source.decode_u32(offset + 4)
		if source.slice(offset, offset + 4).get_string_from_ascii() == "data":
			assert(stream.data == source.slice(offset + 8, offset + 8 + chunk_size), "Imported music must preserve original samples")
			matched = true
			break
		offset += 8 + chunk_size + chunk_size % 2
	assert(matched)
	# Stopping before the deferred start must prevent music leaking into gameplay.
	music.stop_login_loop()
	await process_frame
	assert(not player.playing)
	music.start_login_loop()
	await create_timer(0.1).timeout
	assert(player.playing)
	var position := player.get_playback_position()
	var host := Node.new()
	root.add_child(host)
	var shared = preload("res://Scripts/ui/menu_loop_sound_helper.gd").start_menu_loop_sound(host)
	assert(shared == player and host.get_child_count() == 0, "Legacy lobby must reuse the same player")
	music.start_login_loop()
	await process_frame
	assert(player.get_playback_position() >= position)
	assert(stream.loop_end > 0, "Legacy helper must not corrupt the shared loop bounds")
	music.stop_login_loop()
	host.free()
	print("MENU_MUSIC_PASS: lossless source samples, single player, continuous menu playback and canceled deferred starts")
	quit()
